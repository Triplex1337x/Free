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
local Prog = require(Shared.Config.Progression)
local Zones = require(Shared.Config.Zones)
local Gacha = require(Shared.Gacha)

local M1 = GameConfig.M1
local Block = GameConfig.Block

local CombatService = {}

local playerState = {} :: { [Player]: any }
local blockStart = {} :: { [Model]: number }
local stunUntil = {} :: { [Model]: number }
local damageLog = {} :: { [Model]: { [Player]: number } }
local lastCombat = {} :: { [Player]: number }
local pendingXp = {} :: { [Player]: number }
local pendingMastery = {} :: { [Player]: number }
local lockNotified = {} :: { [Player]: number }
local pvpRewardAt = {} :: { [string]: number } -- "killer:victim" -> last rewarded time
local armorUntil = {} :: { [Model]: number } -- hyper armor: no stun / knockback
local invulnUntil = {} :: { [Model]: number } -- ultimates: no damage at all
local counterUntil = {} :: { [Model]: number } -- counter stance window
local lastPvp = {} :: { [Player]: number }
local PVP_REWARD_COOLDOWN = 300

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
			AbilityBusyUntil = 0,
			CounterReadyAt = 0,
			Queued = nil,
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
	for _, extra in self.ExtraExclusions or {} do
		table.insert(list, extra)
	end
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
	local baseJump = model:GetAttribute("BaseJump") or GameConfig.JumpHeight
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

local function timed(map, model: Model): boolean
	local t = map[model]
	return t ~= nil and os.clock() < t
end

function CombatService:HasArmor(model: Model): boolean
	return timed(armorUntil, model) or timed(invulnUntil, model)
end

-- Marks a model as hyper-armoured (and optionally invulnerable) for a while.
function CombatService:SetArmor(model: Model, duration: number, invulnerable: boolean?)
	local untilTime = os.clock() + duration
	armorUntil[model] = math.max(armorUntil[model] or 0, untilTime)
	model:SetAttribute("HyperArmor", true)
	if invulnerable then
		invulnUntil[model] = math.max(invulnUntil[model] or 0, untilTime)
		model:SetAttribute("Invulnerable", true)
	end
	task.delay(duration, function()
		if model.Parent and not timed(armorUntil, model) then
			model:SetAttribute("HyperArmor", nil)
		end
		if model.Parent and not timed(invulnUntil, model) then
			model:SetAttribute("Invulnerable", nil)
		end
	end)
end

function CombatService:Stun(model: Model, duration: number)
	if not duration or duration <= 0 or not model.Parent or self:HasArmor(model) then
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

-- PvP is opt-in: both players need PvP switched on in Settings and to be at
-- least GameConfig.Pvp.MinLevel. No safe zones to run into mid-fight: PvP
-- can't be switched off for a while after the last PvP hit.
function CombatService:CanPvp(player: Player): boolean
	return player:GetAttribute("Pvp") == true
		and self.Services.ProgressionService:GetLevel(player) >= GameConfig.Pvp.MinLevel
end

function CombatService:SetPvp(player: Player, on: boolean)
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return { Ok = false, Error = "Данные ещё загружаются." }
	end
	if on and self.Services.ProgressionService:GetLevel(player) < GameConfig.Pvp.MinLevel then
		return { Ok = false, Error = ("PvP открывается с %d уровня."):format(GameConfig.Pvp.MinLevel) }
	end
	local since = os.clock() - (lastPvp[player] or -math.huge)
	if not on and since < GameConfig.Pvp.LockSeconds then
		return { Ok = false, Error = ("Нельзя выключить PvP во время боя: подожди %d сек."):format(math.ceil(GameConfig.Pvp.LockSeconds - since)) }
	end
	profile.Data.Settings.Pvp = on
	player:SetAttribute("Pvp", on)
	self.Services.ProgressionService:RefreshOverhead(player)
	return { Ok = true }
end

function CombatService:InCombat(player: Player): boolean
	local t = lastCombat[player]
	return t ~= nil and os.clock() - t < GameConfig.Combat.InCombatDuration
end

-- Knockback is a short, controlled LinearVelocity push (Roblox's physics
-- constraint for this), not an impulse that sends bodies spinning.
function CombatService:ApplyKnockback(model: Model, velocity: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or model:GetAttribute("NoKnockback") or root.Anchored or self:HasArmor(model) then
		return
	end
	local cfg = GameConfig.Knockback
	local owner = Players:GetPlayerFromCharacter(model)
	velocity *= cfg.Scale * (if owner then 1 else cfg.NpcScale)
	if velocity.Magnitude > cfg.MaxSpeed then
		velocity = velocity.Unit * cfg.MaxSpeed
	end
	if owner then
		-- The client owns its character's physics, so it applies the push.
		Remotes.Knockback:FireClient(owner, velocity, cfg.Duration)
		return
	end
	local old = root:FindFirstChild("KnockbackPush")
	if old then
		old:Destroy()
	end
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if not attachment then
		return
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "KnockbackPush"
	push.Attachment0 = attachment
	push.MaxForce = 1e6
	push.VectorVelocity = velocity
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.Parent = root
	task.delay(cfg.Duration, function()
		push:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Damage
---------------------------------------------------------------------------

-- opts: Stun, Knockback, Origin, Unblockable, GuardBreak, Color
function CombatService:Damage(attackerPlayer: Player?, attacker: Model?, target: Model, amount: number, opts)
	opts = opts or {}
	local humanoid = aliveHumanoid(target)
	if not humanoid or target == attacker or target:FindFirstChildOfClass("ForceField") or target:GetAttribute("God") then
		return false
	end
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return false
	end

	local victim = Players:GetPlayerFromCharacter(target)
	if not attackerPlayer and not victim then
		return false -- NPCs never hurt each other
	end
	if attackerPlayer and victim and not (self:CanPvp(attackerPlayer) and self:CanPvp(victim)) then
		return false -- both players need PvP switched on
	end
	if timed(invulnUntil, target) then
		fx("Hit", { Pos = targetRoot.Position, Damage = 0, Blocked = true, Immune = true, Target = target, Attacker = attacker })
		return false
	end
	if attackerPlayer and victim then
		lastPvp[attackerPlayer] = os.clock()
		lastPvp[victim] = os.clock()
	end

	-- Counter stance: cancel the hit, appear behind the attacker and punish.
	if timed(counterUntil, target) and attacker and attackerRoot and (attackerRoot.Position - targetRoot.Position).Magnitude < 18 then
		counterUntil[target] = nil
		target:SetAttribute("Countering", nil)
		local behind = attackerRoot.CFrame * CFrame.new(0, 0, 3.5)
		targetRoot.CFrame = CFrame.lookAt(behind.Position, attackerRoot.Position)
		fx("Counter", { Pos = attackerRoot.Position, Character = target, Target = attacker })
		self:Stun(attacker, GameConfig.Counter.Stun)
		task.defer(function()
			self:Damage(victim, target, attacker, GameConfig.Counter.Damage, {
				Stun = GameConfig.Counter.Stun,
				Knockback = GameConfig.Counter.Knockback,
				Unblockable = true,
				Color = target:GetAttribute("StyleColor"),
			})
		end)
		return false
	end

	local damage = amount * self.Services.ProgressionService:GetDamageMultiplier(attackerPlayer)
	local blocked = false
	local crit = false
	local attackerStyle = attackerPlayer and self:GetStyle(attackerPlayer)
	local passive = attackerStyle and attackerStyle.Passive and attackerStyle.Passive.Id
	if attackerStyle then
		-- Rarer Arts always hit harder (Config/Gacha Power).
		damage *= Gacha.GetRarity(attackerStyle.Rarity).Power or 1
		if passive == "Execute" and humanoid.Health / humanoid.MaxHealth < 0.35 then
			damage *= 1.4
		elseif passive == "Radiance" and not opts.NoPassive and math.random() < 0.2 then
			damage *= 2
			crit = true
		end
	end

	if target:GetAttribute("Blocking") and not opts.Unblockable then
		local from = opts.Origin or (attackerRoot and attackerRoot.Position) or targetRoot.Position
		local offset = (from - targetRoot.Position) * Vector3.new(1, 0, 1)
		local facing = offset.Magnitude < 0.5 or targetRoot.CFrame.LookVector:Dot(offset.Unit) > Block.FacingDot
		if facing then
			if opts.GuardBreak then
				self:SetBlocking(target, false)
				self:Stun(target, Block.GuardBreakStun)
				fx("GuardBreak", { Pos = targetRoot.Position, Target = target })
			elseif attacker and os.clock() - (blockStart[target] or 0) <= Block.PerfectWindow then
				-- Perfect block: no damage, attacker is stunned.
				self:Stun(attacker, Block.PerfectStun)
				fx("Hit", { Pos = targetRoot.Position, Parried = true, Target = target, Attacker = attacker })
				return false
			else
				blocked = true
				damage *= 1 - Block.DamageReduction
			end
		end
	end

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer then
		damage *= 1 - self.Services.InventoryService:Bonus(targetPlayer, "Defense")
		local targetStyle = self:GetStyle(targetPlayer)
		if targetStyle and targetStyle.Passive and targetStyle.Passive.Id == "Stoneskin" then
			damage *= 0.8
		end
	end
	damage = math.max(1, math.floor(damage + 0.5))
	humanoid:TakeDamage(damage)
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
		local spirit = self.Services.ProgressionService:GetAwakeningMultiplier(attackerPlayer)
		local npcFactor = if targetPlayer then 1 else GameConfig.Awakening.NpcFactor
		self:AddAwakening(attackerPlayer, damage * GameConfig.Awakening.PerDamageDealt * spirit * npcFactor)
		pendingXp[attackerPlayer] = (pendingXp[attackerPlayer] or 0) + damage * GameConfig.Rewards.XpPerDamage
		pendingMastery[attackerPlayer] = (pendingMastery[attackerPlayer] or 0) + damage * Prog.Mastery.XpPerDamage
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

	fx("Hit", { Pos = targetRoot.Position, Damage = damage, Blocked = blocked, Crit = crit, Color = opts.Color, Target = target, Attacker = attacker })

	-- Style passives that trigger on hit.
	if passive and not opts.NoPassive then
		self:ApplyPassive(attackerPlayer :: Player, attacker, target, humanoid, damage, passive, opts)
	end
	return true
end

function CombatService:ApplyPassive(player: Player, attacker: Model?, target: Model, humanoid: Humanoid, damage: number, passive: string, opts)
	local attackerHumanoid = attacker and attacker:FindFirstChildOfClass("Humanoid")
	if passive == "Lifesteal" and attackerHumanoid then
		attackerHumanoid.Health = math.min(attackerHumanoid.MaxHealth, attackerHumanoid.Health + damage * 0.12)
	elseif passive == "Radiance" and opts.IsAbility and attackerHumanoid then
		attackerHumanoid.Health = math.min(attackerHumanoid.MaxHealth, attackerHumanoid.Health + attackerHumanoid.MaxHealth * 0.03)
	elseif passive == "Burn" then
		-- 25% extra damage over 2 seconds (4 ticks); refreshes, doesn't stack.
		local token = (target:GetAttribute("BurnToken") or 0) + 1
		target:SetAttribute("BurnToken", token)
		target:SetAttribute("Burning", true)
		local tick = math.max(1, math.floor(damage * 0.25 / 4 + 0.5))
		task.spawn(function()
			for _ = 1, 4 do
				task.wait(0.5)
				if target:GetAttribute("BurnToken") ~= token or humanoid.Health <= 0 then
					return
				end
				humanoid:TakeDamage(tick)
			end
			if target:GetAttribute("BurnToken") == token then
				target:SetAttribute("Burning", nil)
			end
		end)
	elseif passive == "Chain" and opts.IsAbility and not opts.NoChain then
		local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local count = 0
		for _, other in self:QueryRadius(root.Position, 14, attacker) do
			if other ~= target and count < 2 then
				count += 1
				local otherRoot = other:FindFirstChild("HumanoidRootPart")
				if otherRoot then
					fx("Chain", { From = root.Position, To = otherRoot.Position, Color = opts.Color })
				end
				self:Damage(player, attacker, other, damage * 0.4, { Stun = 0.3, NoChain = true, NoPassive = true, Color = opts.Color })
			end
		end
	end
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
				IsAbility = true,
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

-- Nearest valid enemy in front of `origin` (cone given by minDot) within range.
function CombatService:FindTarget(player: Player?, character: Model, origin: Vector3, aim: Vector3, range: number, minDot: number, npcOnly: boolean?): (Model?, BasePart?)
	local best, bestRoot, bestScore = nil, nil, math.huge
	local function consider(model: Model)
		if model == character or not aliveHumanoid(model) then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local offset = (root.Position - origin) * Vector3.new(1, 0, 1)
		local dist = offset.Magnitude
		if dist > range then
			return
		end
		local dot = if dist > 0.1 then aim:Dot(offset.Unit) else 1
		if dot < minDot then
			return
		end
		local score = dist * (1.5 - dot) -- prefer close and centred
		if score < bestScore then
			best, bestRoot, bestScore = model, root, score
		end
	end
	if player then
		local npcs = workspace:FindFirstChild("NPCs")
		if npcs then
			for _, model in npcs:GetChildren() do
				consider(model)
			end
		end
		if not npcOnly and self:CanPvp(player) then
			for _, other in Players:GetPlayers() do
				if other ~= player and other.Character and self:CanPvp(other) then
					consider(other.Character)
				end
			end
		end
	end
	return best, bestRoot
end

local Kinds = {}

function Kinds.Melee(self, player, character, root, ability, aim, color)
	task.wait(ability.Windup or 0)
	if not aliveHumanoid(character) then
		return
	end
	local range, width = ability.Range or 8, ability.Width or 6
	fx("Melee", { Character = character, CFrame = CFrame.lookAt(root.Position, root.Position + aim), Range = range, Width = width, Color = color })
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
	params.FilterDescendantsInstances = { self.MapFolder, table.unpack(self.ExtraExclusions or {}) }

	local origin = root.Position
	local distance = ability.Distance or 30
	local lock = ability._Target and ability._Target:FindFirstChild("HumanoidRootPart")
	if lock then
		-- Homing dash: stop right in front of the target.
		local offset = (lock.Position - origin) * Vector3.new(1, 0, 1)
		if offset.Magnitude > 1 then
			aim = offset.Unit
			distance = math.min(distance + 8, math.max(2, offset.Magnitude - 2.5))
		end
	end
	local result = workspace:Raycast(origin, aim * distance, params)
	if result then
		distance = math.max(0, (result.Position - origin).Magnitude - 3)
	end
	local dest = origin + aim * distance
	local mid = origin:Lerp(dest, 0.5)
	local targets = self:QueryBox(CFrame.lookAt(mid, mid + aim), Vector3.new(7, 7, distance + 4), character)

	root.CFrame = CFrame.lookAt(dest, dest + aim)
	fx("Dash", { Character = character, From = origin, To = dest, Color = color })
	self.Services.DestructionService:Hit(mid, math.max(5, distance / 2), ability.Damage)

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
	local lock = ability._Target and ability._Target:FindFirstChild("HumanoidRootPart")
	if lock and ability.Offset and (lock.Position - root.Position).Magnitude < ability.Offset + (ability.Radius or 12) then
		center = lock.Position
	end
	local radius = ability.Radius or 12
	self.Services.DestructionService:Hit(center, radius, ability.Damage * (ability.Hits or 1))
	fx("Burst", { Character = character, Pos = center, Radius = radius, Color = color, Hits = ability.Hits or 1, Interval = ability.HitInterval or 0.15 })
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
	ball:SetAttribute("Element", character:GetAttribute("Element"))
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
	local lockRoot = ability._Target and ability._Target:FindFirstChild("HumanoidRootPart")
	connection = RunService.Heartbeat:Connect(function(dt)
		if lockRoot and lockRoot.Parent then
			-- Homing: steer toward the target (flat), limited turn rate.
			local want = (lockRoot.Position - pos) * Vector3.new(1, 0, 1)
			if want.Magnitude > 1 then
				aim = aim:Lerp(want.Unit, math.min(1, dt * 7))
				aim = Vector3.new(aim.X, 0, aim.Z).Unit
			end
		end
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
			self.Services.DestructionService:Hit(hitPos, ability.Explode, ability.Damage)
		else
			local model = result and characterFromPart(result.Instance)
			targets = if model and aliveHumanoid(model) then { model } else {}
		end
		fx("Burst", { Character = character, Pos = hitPos, Radius = ability.Explode or size * 2, Color = color, Hits = 1, Small = not ability.Explode })
		local knockOrigin = if ability.Explode then hitPos else hitPos - aim * 6
		task.spawn(self.MultiHit, self, player, character, ability, color, function()
			return targets
		end, function()
			return knockOrigin
		end)
	end)
end

-- Counter stance (RMB+LMB / C / mobile button): a short window where the next
-- close hit is negated and answered.
function CombatService:HandleCounter(player: Player)
	local s = getState(player)
	local character = player.Character
	if not character or not aliveHumanoid(character) or self:IsStunned(character) then
		return
	end
	local t = os.clock()
	if t < s.CounterReadyAt or t < s.AbilityBusyUntil then
		return
	end
	if character:GetAttribute("Blocking") then
		self:SetBlocking(character, false)
	end
	s.CounterReadyAt = t + GameConfig.Counter.Cooldown
	s.BusyUntil = t + GameConfig.Counter.Window
	counterUntil[character] = t + GameConfig.Counter.Window
	character:SetAttribute("Countering", true)
	task.delay(GameConfig.Counter.Window, function()
		if character.Parent and not timed(counterUntil, character) then
			character:SetAttribute("Countering", nil)
		end
	end)
	Remotes.Cooldown:FireClient(player, "C", GameConfig.Counter.Cooldown)
	fx("CounterStance", { Character = character })
end

-- Lets NPCs (player = nil) use the same ability kinds players do.
function CombatService:CastAbility(player: Player?, character: Model, ability, aim: Vector3, color: Color3)
	local root = character:FindFirstChild("HumanoidRootPart")
	local run = Kinds[ability.Kind]
	if root and run then
		task.spawn(run, self, player, character, root, ability, aim, color)
	end
end

---------------------------------------------------------------------------
-- Input handlers
---------------------------------------------------------------------------

-- M1 swings only block other M1s; abilities block everything. So a skill
-- pressed mid-combo goes off immediately instead of being eaten.
function CombatService:CanAct(player: Player, s, isAbility: boolean?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not aliveHumanoid(character) then
		return nil
	end
	if self:IsStunned(character) or character:GetAttribute("Blocking") or os.clock() < s.AbilityBusyUntil then
		return nil
	end
	if not isAbility and os.clock() < s.BusyUntil then
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

	-- Distance-based soft lock: any enemy within reach in front of you (or
	-- right next to you) gets hit and you turn to face it.
	-- Auto-attack (setting, on by default) only ever locks onto bots/mobs —
	-- in fights between players you aim yourself.
	local locked = nil
	if player:GetAttribute("AutoLock") ~= false then
		locked = self:FindTarget(player, character, root.Position, aim, M1.Range + M1.LockBonus, 0.1, true)
			or self:FindTarget(player, character, root.Position, aim, 5, -1, true)
	end
	if locked then
		local lockRoot = locked:FindFirstChild("HumanoidRootPart") :: BasePart
		local offset = (lockRoot.Position - root.Position) * Vector3.new(1, 0, 1)
		if offset.Magnitude > 0.5 then
			aim = offset.Unit
			root.CFrame = CFrame.lookAt(root.Position, root.Position + aim)
			if offset.Magnitude > M1.Range then
				-- Small step-in so the punch connects.
				root.CFrame += aim * math.min(3, offset.Magnitude - M1.Range + 1)
			end
		end
	end
	local facing = CFrame.lookAt(root.Position, root.Position + aim)
	fx("Swing", { Character = character, CFrame = facing, Color = style.Color, Combo = combo, Finisher = finisher })

	local opts = {
		Stun = if finisher then M1.FinisherStun else M1.HitStun,
		Knockback = if finisher then M1.FinisherKnockback else 3,
		GuardBreak = finisher,
		Color = style.Color,
	}
	local damage = if finisher then M1.FinisherDamage else M1.Damage
	local hit = {}
	if locked then
		hit[locked] = true
		self:Damage(player, character, locked, damage, opts)
	end
	local hitbox = facing * CFrame.new(0, 0, -M1.Range / 2)
	for _, target in self:QueryBox(hitbox, Vector3.new(M1.Width, 7, M1.Range), character) do
		if not hit[target] then
			self:Damage(player, character, target, damage, opts)
		end
	end
	if finisher then
		self.Services.DestructionService:Hit((facing * CFrame.new(0, 0, -M1.Range)).Position, 5, M1.FinisherDamage * 2)
	end
end

function CombatService:HandleAbility(player: Player, payload)
	if type(payload) ~= "table" or not ABILITY_KEYS[payload.Key] then
		return
	end
	local key = payload.Key
	local s = getState(player)
	local now = os.clock()
	local character0 = player.Character
	-- Input buffer: pressed slightly early (still busy or cooldown about to
	-- end)? Remember it and fire the moment it becomes possible.
	if character0 and not self:IsStunned(character0) and not character0:GetAttribute("Blocking") then
		local wait = math.max(s.AbilityBusyUntil - now, (s.Cooldowns[key] or 0) - now)
		if wait > 0 and wait <= GameConfig.InputBuffer and not payload._Buffered then
			s.Queued = payload
			payload._Buffered = true
			task.delay(wait + 0.02, function()
				if s.Queued == payload then
					s.Queued = nil
					self:HandleAbility(player, payload)
				end
			end)
			return
		end
	end
	local character, root = self:CanAct(player, s, true)
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
	if not Prog.IsUnlocked(profile.Data, profile.Data.EquippedStyle, key) then
		if t - (lockNotified[player] or 0) > 1.5 then
			lockNotified[player] = t
			Remotes.Notify:FireClient(
				player,
				("%s откроется на %d мастерства стиля «%s». Сражайся этим стилем!"):format(ability.Name, Prog.Mastery.Unlocks[key], style.Name),
				"info"
			)
		end
		return
	end
	if key == "G" then
		if (player:GetAttribute("Awakening") or 0) < GameConfig.Awakening.Max then
			return
		end
		player:SetAttribute("Awakening", 0)
		self.Services.QuestService:Progress(player, "Ultimate", 1)
	else
		if t < (s.Cooldowns[key] or 0) then
			return
		end
		local cooldown = ability.Cooldown * self.Services.ProgressionService:GetCooldownMultiplier(player)
		s.Cooldowns[key] = t + cooldown
		Remotes.Cooldown:FireClient(player, key, cooldown)
	end

	local aim = readAim(payload.Aim, root)
	local windup = ability.Windup or 0
	local busy = windup + 0.15 + ((ability.Hits or 1) - 1) * (ability.HitInterval or 0.15)
	s.AbilityBusyUntil = t + busy
	s.BusyUntil = t + busy

	-- Per-cast copy so homing can attach a target.
	ability = table.clone(ability)
	if ability.Homing then
		local range = (ability.MaxDistance or ability.Distance or ability.Range or ability.Offset or 30) + 10
		local target, targetRoot = self:FindTarget(player, character, root.Position, aim, range, -0.2)
		if target and targetRoot then
			ability._Target = target
			local offset = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			if offset.Magnitude > 0.5 then
				aim = offset.Unit
			end
		end
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + aim)
	if key == "G" then
		self:SetArmor(character, busy + GameConfig.UltimateInvulnerability, true)
	elseif ability.HyperArmor or (style.Passive and style.Passive.Id == "Stoneskin") then
		self:SetArmor(character, busy + 0.2, false)
	end

	fx("Cast", { Character = character, Key = key, Kind = ability.Kind, Name = ability.Name, Color = style.Color, Windup = windup })
	if key == "G" then
		fx("Ultimate", { Character = character, Name = ability.Name, Color = style.Color, Caster = player.DisplayName, Windup = windup, Duration = busy })
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
	armorUntil[model] = nil
	invulnUntil[model] = nil
	counterUntil[model] = nil
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
		-- Anti-farm: the same killer/victim pair only pays out once per 5 minutes.
		local pairKey = killer.UserId .. ":" .. player.UserId
		local rewarded = os.clock() - (pvpRewardAt[pairKey] or -math.huge) >= PVP_REWARD_COOLDOWN
		if killerProfile and not rewarded then
			killerProfile.Data.Kills += 1
			DataService:Sync(killer)
			Remotes.Notify:FireClient(killer, "Ты победил " .. player.DisplayName .. " (без награды — этот соперник был недавно)", "kill")
		elseif killerProfile then
			pvpRewardAt[pairKey] = os.clock()
			killerProfile.Data.Kills += 1
			Progression:AddShards(killer, Rewards.PlayerKillShards, true)
			Progression:AddXp(killer, Rewards.PlayerKillXp)
			Progression:AddMasteryXp(killer, Prog.Mastery.XpPerKill)
			self.Services.QuestService:Progress(killer, "PvpKill", 1)
			Remotes.Notify:FireClient(killer, "Ты победил " .. player.DisplayName, "kill")
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

-- Clients read these to pick animations and the element's visual effects.
function CombatService:ApplyStyleAttributes(player: Player)
	local character = player.Character
	local style = self:GetStyle(player)
	if character and style then
		character:SetAttribute("Element", style.Element)
		character:SetAttribute("StyleColor", style.Color)
	end
end

function CombatService:OnCharacterAdded(player: Player, character: Model)
	local s = getState(player)
	s.BusyUntil = 0
	s.Combo = 0
	player:SetAttribute("Awakening", player:GetAttribute("Awakening") or 0)

	self:ApplyStyleAttributes(player)
	character:SetAttribute("God", player:GetAttribute("God"))
	local profile = self.Services.DataService:Get(player)
	if profile and player:GetAttribute("Pvp") == nil then
		player:SetAttribute("Pvp", profile.Data.Settings.Pvp == true)
		player:SetAttribute("AutoLock", profile.Data.Settings.AutoLock ~= false)
	end
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
		elseif action == "Counter" then
			self:HandleCounter(player)
		elseif action == "AirJump" then
			-- Purely visual: other players see the air-jump burst.
			local character = player.Character
			if character and type(payload) == "number" then
				fx("AirJump", { Character = character, Count = math.clamp(payload, 1, 2) })
			end
		end
	end)

	Remotes.SetPvp.OnServerInvoke = function(player, on)
		return self:SetPvp(player, on == true)
	end
	Remotes.SetSetting.OnServerInvoke = function(player, name, value)
		local profile = self.Services.DataService:Get(player)
		if not profile or name ~= "AutoLock" or type(value) ~= "boolean" then
			return { Ok = false }
		end
		profile.Data.Settings.AutoLock = value
		player:SetAttribute("AutoLock", value)
		return { Ok = true }
	end

	Players.PlayerRemoving:Connect(function(player)
		playerState[player] = nil
		lastPvp[player] = nil
		lastCombat[player] = nil
		pendingXp[player] = nil
		pendingMastery[player] = nil
		lockNotified[player] = nil
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
		for player, amount in pendingMastery do
			pendingMastery[player] = nil
			if player.Parent then
				self.Services.ProgressionService:AddMasteryXp(player, amount)
				self.Services.QuestService:Progress(player, "Damage", amount / Prog.Mastery.XpPerDamage)
			end
		end
	end
end

return CombatService
