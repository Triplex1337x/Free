-- Server-authoritative combat: M1 combos, block / parry / guard break,
-- data-driven abilities, ultimates, stun, knockback, kill credit, respawn.
-- The client only sends intent ("M1", "Ability Q") plus an aim direction;
-- every cooldown, hitbox and damage number is decided here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Styles = require(Shared.Config.Styles)
local Remotes = require(Shared.Remotes)

local M1 = GameConfig.M1
local Block = GameConfig.Block

local CombatService = {}

local playerState = {} :: { [Player]: any }
local blockStart = {} :: { [Model]: number }
local stunUntil = {} :: { [Model]: number }
local damageLog = {} :: { [Model]: { [Player]: number } }
local lastCombat = {} :: { [Player]: number }
local pendingXp = {} :: { [Player]: number }

local projectileFolder = Instance.new("Folder")
projectileFolder.Name = "Projectiles"
projectileFolder.Parent = workspace

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude

local ABILITY_KEYS = { Q = true, E = true, R = true, G = true }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function getState(player: Player)
	local s = playerState[player]
	if not s then
		s = {
			LastM1 = 0,
			Combo = 0,
			ComboLockUntil = 0,
			BusyUntil = 0,
			Cooldowns = {},
			Tokens = GameConfig.Combat.ActionsPerSecond,
			TokenTime = os.clock(),
			RespawnToken = 0,
		}
		playerState[player] = s
	end
	return s
end

local function consumeToken(s): boolean
	local t = os.clock()
	local rate = GameConfig.Combat.ActionsPerSecond
	s.Tokens = math.min(rate, s.Tokens + (t - s.TokenTime) * rate)
	s.TokenTime = t
	if s.Tokens < 1 then
		return false
	end
	s.Tokens -= 1
	return true
end

local function aliveHumanoid(model: Instance?): Humanoid?
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function characterFromPart(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-3 or flat.Magnitude ~= flat.Magnitude then
		return fallback
	end
	return flat.Unit
end

local function fx(kind: string, payload)
	Remotes.Fx:FireAllClients(kind, payload)
end

function CombatService:Exclusions(attacker: Model?)
	local list = { projectileFolder, self.MapFolder }
	if attacker then
		table.insert(list, attacker)
	end
	return list
end

function CombatService:Collect(parts, attacker: Model?)
	local seen, list = {}, {}
	for _, part in parts do
		local model = characterFromPart(part)
		if model and model ~= attacker and not seen[model] and aliveHumanoid(model) then
			seen[model] = true
			table.insert(list, model)
		end
	end
	return list
end

function CombatService:QueryBox(cf: CFrame, size: Vector3, attacker: Model?)
	overlap.FilterDescendantsInstances = self:Exclusions(attacker)
	return self:Collect(workspace:GetPartBoundsInBox(cf, size, overlap), attacker)
end

function CombatService:QueryRadius(pos: Vector3, radius: number, attacker: Model?)
	overlap.FilterDescendantsInstances = self:Exclusions(attacker)
	return self:Collect(workspace:GetPartBoundsInRadius(pos, radius, overlap), attacker)
end

---------------------------------------------------------------------------
-- State: stun, block, movement
---------------------------------------------------------------------------

function CombatService:IsStunned(model: Model): boolean
	local t = stunUntil[model]
	return t ~= nil and os.clock() < t
end

function CombatService:UpdateMovement(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local baseSpeed = model:GetAttribute("BaseSpeed") or GameConfig.BaseWalkSpeed
	local baseJump = model:GetAttribute("BaseJump") or 7.2
	if self:IsStunned(model) then
		humanoid.WalkSpeed = math.min(baseSpeed, GameConfig.Stun.WalkSpeed)
		humanoid.JumpHeight = 0
	elseif model:GetAttribute("Blocking") then
		humanoid.WalkSpeed = math.min(baseSpeed, Block.WalkSpeed)
		humanoid.JumpHeight = 0
	else
		humanoid.WalkSpeed = baseSpeed
		humanoid.JumpHeight = baseJump
	end
end

function CombatService:Stun(model: Model, duration: number)
	if not duration or duration <= 0 or not model.Parent then
		return
	end
	local untilTime = os.clock() + duration
	if (stunUntil[model] or 0) < untilTime then
		stunUntil[model] = untilTime
	end
	model:SetAttribute("Stunned", true)
	self:UpdateMovement(model)
	task.delay(duration, function()
		local t = stunUntil[model]
		if t and os.clock() >= t - 0.01 then
			stunUntil[model] = nil
			if model.Parent then
				model:SetAttribute("Stunned", nil)
				self:UpdateMovement(model)
			end
		end
	end)
end

function CombatService:SetBlocking(model: Model, on: boolean)
	local highlight = model:FindFirstChild("BlockHighlight")
	if on then
		blockStart[model] = os.clock()
		model:SetAttribute("Blocking", true)
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "BlockHighlight"
			highlight.FillColor = Color3.fromRGB(120, 210, 255)
			highlight.OutlineColor = Color3.fromRGB(200, 240, 255)
			highlight.FillTransparency = 0.8
			highlight.OutlineTransparency = 0.2
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = model
		end
	else
		blockStart[model] = nil
		model:SetAttribute("Blocking", nil)
		if highlight then
			highlight:Destroy()
		end
	end
	self:UpdateMovement(model)
end

function CombatService:AddAwakening(player: Player, amount: number)
	local max = GameConfig.Awakening.Max
	local current = player:GetAttribute("Awakening") or 0
	player:SetAttribute("Awakening", math.min(max, current + amount))
end

function CombatService:InCombat(player: Player): boolean
	local t = lastCombat[player]
	return t ~= nil and os.clock() - t < GameConfig.Combat.InCombatDuration
end

function CombatService:ApplyKnockback(model: Model, velocity: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local owner = Players:GetPlayerFromCharacter(model)
	if owner then
		-- The client owns its character's physics, so it applies the push.
		Remotes.Knockback:FireClient(owner, velocity)
	else
		root.AssemblyLinearVelocity = velocity
	end
end

---------------------------------------------------------------------------
-- Damage
---------------------------------------------------------------------------

-- opts: Stun, Knockback, Origin, Unblockable, GuardBreak, Color
function CombatService:Damage(attackerPlayer: Player?, attacker: Model?, target: Model, amount: number, opts)
	opts = opts or {}
	local humanoid = aliveHumanoid(target)
	if not humanoid or target == attacker or target:FindFirstChildOfClass("ForceField") then
		return false
	end
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return false
	end

	local damage = amount * self.Services.ProgressionService:GetDamageMultiplier(attackerPlayer)
	local blocked = false

	if target:GetAttribute("Blocking") and not opts.Unblockable then
		local from = opts.Origin or (attackerRoot and attackerRoot.Position) or targetRoot.Position
		local offset = (from - targetRoot.Position) * Vector3.new(1, 0, 1)
		local facing = offset.Magnitude < 0.5 or targetRoot.CFrame.LookVector:Dot(offset.Unit) > Block.FacingDot
		if facing then
			if opts.GuardBreak then
				self:SetBlocking(target, false)
				self:Stun(target, Block.GuardBreakStun)
				fx("GuardBreak", { Pos = targetRoot.Position })
			elseif attacker and os.clock() - (blockStart[target] or 0) <= Block.PerfectWindow then
				-- Perfect block: no damage, attacker is stunned.
				self:Stun(attacker, Block.PerfectStun)
				fx("Hit", { Pos = targetRoot.Position, Parried = true })
				return false
			else
				blocked = true
				damage *= 1 - Block.DamageReduction
			end
		end
	end

	damage = math.max(1, math.floor(damage + 0.5))
	humanoid:TakeDamage(damage)

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if attackerPlayer then
		target:SetAttribute("LastAttackerId", attackerPlayer.UserId)
		target:SetAttribute("LastAttackTime", os.clock())
		local log = damageLog[target]
		if not log then
			log = {}
			damageLog[target] = log
		end
		log[attackerPlayer] = (log[attackerPlayer] or 0) + damage
		lastCombat[attackerPlayer] = os.clock()
		self:AddAwakening(attackerPlayer, damage * GameConfig.Awakening.PerDamageDealt)
		pendingXp[attackerPlayer] = (pendingXp[attackerPlayer] or 0) + damage * GameConfig.Rewards.XpPerDamage
	end
	if targetPlayer then
		lastCombat[targetPlayer] = os.clock()
		self:AddAwakening(targetPlayer, damage * GameConfig.Awakening.PerDamageTaken)
	end

	if not blocked then
		self:Stun(target, opts.Stun or 0)
		local kb = opts.Knockback or 0
		if kb ~= 0 then
			local origin = opts.Origin or (attackerRoot and attackerRoot.Position) or targetRoot.Position
			local offset = (targetRoot.Position - origin) * Vector3.new(1, 0, 1)
			local fallback = attackerRoot and attackerRoot.CFrame.LookVector or Vector3.zAxis
			local dir = flatUnit(offset, flatUnit(fallback, Vector3.zAxis))
			local velocity
			if kb > 0 then
				velocity = dir * kb + Vector3.new(0, kb * 0.35, 0)
			else
				-- Pull: never faster than needed to reach the origin.
				local speed = math.min(-kb, offset.Magnitude * 3)
				velocity = -dir * speed + Vector3.new(0, 6, 0)
			end
			self:ApplyKnockback(target, velocity)
		end
	end

	fx("Hit", { Pos = targetRoot.Position, Damage = damage, Blocked = blocked, Color = opts.Color })
	return true
end

-- Damages whatever `query()` returns, `hits` times.
function CombatService:MultiHit(player: Player, character: Model, ability, color: Color3, query, originFn)
	local hits = ability.Hits or 1
	for i = 1, hits do
		if not aliveHumanoid(character) then
			return
		end
		local last = i == hits
		local kb = ability.Knockback or 0
		if not last then
			kb = if kb < 0 then kb * 0.5 else 4
		end
		for _, target in query() do
			self:Damage(player, character, target, ability.Damage, {
				Stun = ability.Stun,
				Knockback = kb,
				Origin = originFn and originFn() or nil,
				Unblockable = ability.Unblockable,
				GuardBreak = ability.GuardBreak and last,
				Color = color,
			})
		end
		if not last then
			task.wait(ability.HitInterval or 0.15)
		end
	end
end

---------------------------------------------------------------------------
-- Ability kinds
---------------------------------------------------------------------------

local Kinds = {}

function Kinds.Melee(self, player, character, root, ability, aim, color)
	task.wait(ability.Windup or 0)
	if not aliveHumanoid(character) then
		return
	end
	local range, width = ability.Range or 8, ability.Width or 6
	fx("Melee", { CFrame = CFrame.lookAt(root.Position, root.Position + aim), Range = range, Width = width, Color = color })
	self:MultiHit(player, character, ability, color, function()
		local cf = CFrame.lookAt(root.Position, root.Position + aim) * CFrame.new(0, 0, -range / 2)
		return self:QueryBox(cf, Vector3.new(width, 7, range), character)
	end)
end

function Kinds.Dash(self, player, character, root, ability, aim, color)
	task.wait(ability.Windup or 0)
	if not aliveHumanoid(character) then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.MapFolder }

	local origin = root.Position
	local distance = ability.Distance or 30
	local result = workspace:Raycast(origin, aim * distance, params)
	if result then
		distance = math.max(0, (result.Position - origin).Magnitude - 3)
	end
	local dest = origin + aim * distance
	local mid = origin:Lerp(dest, 0.5)
	local targets = self:QueryBox(CFrame.lookAt(mid, mid + aim), Vector3.new(7, 7, distance + 4), character)

	root.CFrame = CFrame.lookAt(dest, dest + aim)
	fx("Dash", { From = origin, To = dest, Color = color })

	self:MultiHit(player, character, ability, color, function()
		local alive = {}
		for _, target in targets do
			if aliveHumanoid(target) then
				table.insert(alive, target)
			end
		end
		return alive
	end, function()
		return root.Position - aim * 2
	end)
end

function Kinds.AoE(self, player, character, root, ability, aim, color)
	task.wait(ability.Windup or 0)
	if not aliveHumanoid(character) then
		return
	end
	local center = root.Position + aim * (ability.Offset or 0)
	local radius = ability.Radius or 12
	fx("Burst", { Pos = center, Radius = radius, Color = color, Hits = ability.Hits or 1, Interval = ability.HitInterval or 0.15 })
	self:MultiHit(player, character, ability, color, function()
		return self:QueryRadius(center, radius, character)
	end, function()
		return center
	end)
end

function Kinds.Projectile(self, player, character, root, ability, aim, color)
	task.wait(ability.Windup or 0)
	if not aliveHumanoid(character) then
		return
	end
	local size = ability.Size or 2.5
	local speed = ability.Speed or 120
	local maxDistance = ability.MaxDistance or 100
	local pos = root.Position + aim * 3

	local ball = Instance.new("Part")
	ball.Name = "Projectile"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * size
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Position = pos
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 4
	light.Brightness = 3
	light.Parent = ball
	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, size * 0.3, 0)
	attachment0.Parent = ball
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, -size * 0.3, 0)
	attachment1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.Parent = ball
	ball.Parent = projectileFolder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, projectileFolder }

	local traveled = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local step = speed * dt
		local result = workspace:Spherecast(pos, size / 2, aim * step, params)
		if not result and traveled + step < maxDistance then
			pos += aim * step
			traveled += step
			ball.Position = pos
			return
		end

		connection:Disconnect()
		ball:Destroy()
		local hitPos = if result then result.Position else pos + aim * step
		local targets
		if ability.Explode then
			targets = self:QueryRadius(hitPos, ability.Explode, character)
		else
			local model = result and characterFromPart(result.Instance)
			targets = if model and aliveHumanoid(model) then { model } else {}
		end
		fx("Burst", { Pos = hitPos, Radius = ability.Explode or size * 2, Color = color, Hits = 1 })
		local knockOrigin = if ability.Explode then hitPos else hitPos - aim * 6
		task.spawn(self.MultiHit, self, player, character, ability, color, function()
			return targets
		end, function()
			return knockOrigin
		end)
	end)
end

---------------------------------------------------------------------------
-- Input handlers
---------------------------------------------------------------------------

function CombatService:CanAct(player: Player, s)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not aliveHumanoid(character) then
		return nil
	end
	if self:IsStunned(character) or character:GetAttribute("Blocking") or os.clock() < s.BusyUntil then
		return nil
	end
	return character, root
end

function CombatService:GetStyle(player: Player)
	local profile = self.Services.DataService:Get(player)
	return Styles.Get(profile and profile.Data.EquippedStyle or GameConfig.StarterStyle)
end

local function readAim(raw, root: BasePart): Vector3
	local fallback = flatUnit(root.CFrame.LookVector, Vector3.zAxis)
	if typeof(raw) ~= "Vector3" then
		return fallback
	end
	return flatUnit(raw, fallback)
end

function CombatService:HandleM1(player: Player, rawAim)
	local s = getState(player)
	local character, root = self:CanAct(player, s)
	if not character then
		return
	end
	local t = os.clock()
	if t - s.LastM1 < M1.HitCooldown or t < s.ComboLockUntil then
		return
	end
	if t - s.LastM1 > M1.ComboWindow then
		s.Combo = 0
	end
	s.Combo += 1
	s.LastM1 = t
	s.BusyUntil = t + 0.2

	local combo = s.Combo
	local finisher = combo >= M1.ComboLength
	if finisher then
		s.Combo = 0
		s.ComboLockUntil = t + M1.ComboLockout
	end

	local aim = readAim(rawAim, root)
	local style = self:GetStyle(player)
	local facing = CFrame.lookAt(root.Position, root.Position + aim)
	fx("Swing", { Character = character, CFrame = facing, Color = style.Color, Combo = combo, Finisher = finisher })

	local hitbox = facing * CFrame.new(0, 0, -M1.Range / 2)
	for _, target in self:QueryBox(hitbox, Vector3.new(M1.Width, 7, M1.Range), character) do
		self:Damage(player, character, target, if finisher then M1.FinisherDamage else M1.Damage, {
			Stun = if finisher then M1.FinisherStun else M1.HitStun,
			Knockback = if finisher then M1.FinisherKnockback else 3,
			GuardBreak = finisher,
			Color = style.Color,
		})
	end
end

function CombatService:HandleAbility(player: Player, payload)
	if type(payload) ~= "table" or not ABILITY_KEYS[payload.Key] then
		return
	end
	local key = payload.Key
	local s = getState(player)
	local character, root = self:CanAct(player, s)
	if not character then
		return
	end
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return
	end
	local style = Styles.Get(profile.Data.EquippedStyle)
	local ability = Styles.GetAbility(profile.Data.EquippedStyle, key)
	if not style or not ability then
		return
	end

	local t = os.clock()
	if key == "G" then
		if (player:GetAttribute("Awakening") or 0) < GameConfig.Awakening.Max then
			return
		end
		player:SetAttribute("Awakening", 0)
	else
		if t < (s.Cooldowns[key] or 0) then
			return
		end
		s.Cooldowns[key] = t + ability.Cooldown
		Remotes.Cooldown:FireClient(player, key, ability.Cooldown)
	end

	local aim = readAim(payload.Aim, root)
	local windup = ability.Windup or 0
	s.BusyUntil = t + windup + 0.15 + ((ability.Hits or 1) - 1) * (ability.HitInterval or 0.15)

	fx("Cast", { Character = character, Key = key, Name = ability.Name, Color = style.Color, Windup = windup })
	if key == "G" then
		fx("Ultimate", { Character = character, Name = ability.Name, Color = style.Color, Caster = player.DisplayName })
	end

	local run = Kinds[ability.Kind]
	if run then
		task.spawn(run, self, player, character, root, ability, aim, style.Color)
	end
end

function CombatService:HandleBlock(player: Player, on: boolean)
	local character = player.Character
	if not character or not aliveHumanoid(character) then
		return
	end
	if on then
		local s = getState(player)
		if self:IsStunned(character) or os.clock() < s.BusyUntil or character:GetAttribute("Blocking") then
			return
		end
		self:SetBlocking(character, true)
	elseif character:GetAttribute("Blocking") then
		self:SetBlocking(character, false)
	end
end

---------------------------------------------------------------------------
-- Kill credit, death, respawn
---------------------------------------------------------------------------

function CombatService:GetKiller(model: Model): Player?
	local id = model:GetAttribute("LastAttackerId")
	local t = model:GetAttribute("LastAttackTime")
	if id and t and os.clock() - t <= GameConfig.Combat.TagDuration then
		return Players:GetPlayerByUserId(id)
	end
	return nil
end

-- Players who dealt at least `minShare` of all player damage to `model`.
function CombatService:GetContributors(model: Model, minShare: number): { Player }
	local log = damageLog[model]
	if not log then
		return {}
	end
	local total = 0
	for _, dmg in log do
		total += dmg
	end
	local list = {}
	for player, dmg in log do
		if player.Parent and dmg / total >= minShare then
			table.insert(list, player)
		end
	end
	return list
end

function CombatService:CleanupModel(model: Model)
	blockStart[model] = nil
	stunUntil[model] = nil
	damageLog[model] = nil
end

function CombatService:OnPlayerDied(player: Player, character: Model)
	local DataService = self.Services.DataService
	local Progression = self.Services.ProgressionService
	local Rewards = GameConfig.Rewards

	player:SetAttribute("Awakening", 0)
	local victimProfile = DataService:Get(player)
	if victimProfile then
		victimProfile.Data.Deaths += 1
		DataService:Sync(player)
	end

	local killer = self:GetKiller(character)
	if killer and killer ~= player then
		local killerProfile = DataService:Get(killer)
		if killerProfile then
			killerProfile.Data.Kills += 1
			Progression:AddShards(killer, Rewards.PlayerKillShards, true)
			Progression:AddXp(killer, Rewards.PlayerKillXp)
			Remotes.Notify:FireClient(killer, "You defeated " .. player.DisplayName, "kill")
		end
		fx("KillFeed", { Killer = killer.DisplayName, Victim = player.DisplayName })
	end

	local s = getState(player)
	s.RespawnToken += 1
	local token = s.RespawnToken
	task.delay(GameConfig.RespawnTime, function()
		if player.Parent and s.RespawnToken == token then
			player:LoadCharacter()
		end
	end)
end

function CombatService:OnCharacterAdded(player: Player, character: Model)
	local s = getState(player)
	s.BusyUntil = 0
	s.Combo = 0
	player:SetAttribute("Awakening", player:GetAttribute("Awakening") or 0)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Connect(function()
		self:OnPlayerDied(player, character)
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:CleanupModel(character)
		end
	end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function CombatService:Init(services)
	self.Services = services
	self.MapFolder = services.MapService:GetFolder()

	services.DataService:OnLoaded(function(player)
		player.CharacterAdded:Connect(function(character)
			self:OnCharacterAdded(player, character)
		end)
	end)
end

function CombatService:Start()
	Remotes.Action.OnServerEvent:Connect(function(player, action, payload)
		if type(action) ~= "string" then
			return
		end
		local s = getState(player)
		if not consumeToken(s) then
			return
		end
		if action == "M1" then
			self:HandleM1(player, payload)
		elseif action == "Ability" then
			self:HandleAbility(player, payload)
		elseif action == "BlockStart" then
			self:HandleBlock(player, true)
		elseif action == "BlockEnd" then
			self:HandleBlock(player, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerState[player] = nil
		lastCombat[player] = nil
		pendingXp[player] = nil
		for _, log in damageLog do
			log[player] = nil
		end
	end)

	-- Damage XP is batched so we don't sync data on every single hit.
	while true do
		task.wait(1)
		for player, amount in pendingXp do
			pendingXp[player] = nil
			if player.Parent then
				self.Services.ProgressionService:AddXp(player, amount)
			end
		end
	end
end

return CombatService
