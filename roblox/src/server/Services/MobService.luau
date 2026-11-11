-- Zone mobs and bosses: spawning, a lightweight shared AI loop (wander,
-- aggro, chase, melee combos, element abilities, leash), loot and respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Styles = require(Shared.Config.Styles)
local Prog = require(Shared.Config.Progression)
local Remotes = require(Shared.Remotes)
local NpcFactory = require(script.Parent.Parent.Lib.NpcFactory)

local MobService = {}

local M = Zones.Mob
local TICK = 0.2

local npcFolder: Folder
local mobs = {} :: { [Model]: any }
local rng = Random.new()

-- Element -> the style whose skills mobs of that element borrow.
local styleByElement = {}
for _, id in Styles.Order do
	local style = Styles.Get(id)
	styleByElement[style.Element] = styleByElement[style.Element] or style
end

local function fx(kind, payload)
	Remotes.Fx:FireAllClients(kind, payload)
end

local function statsFor(level: number, boss: boolean)
	local health = M.HealthBase + level * M.HealthPerLevel
	local damage = M.DamageBase + level * M.DamagePerLevel
	local shards = M.ShardsBase + level * M.ShardsPerLevel
	local xp = M.XpBase + level * M.XpPerLevel
	if boss then
		health *= M.BossHealthMult
		damage *= M.BossDamageMult
		shards *= M.BossRewardMult
		xp *= M.BossRewardMult
	end
	return math.floor(health), damage, math.floor(shards), math.floor(xp)
end

function MobService:Init(services)
	self.Services = services
	npcFolder = workspace:FindFirstChild("NPCs") or Instance.new("Folder")
	npcFolder.Name = "NPCs"
	npcFolder.Parent = workspace
end

function MobService:Spawn(zoneId: string, def, home: CFrame, isBoss: boolean)
	local Combat = self.Services.CombatService
	local health, damage, shards, xp = statsFor(def.Level, isBoss)
	local style = styleByElement[def.Element] or Styles.Get("Ember")

	local model = NpcFactory.Rig(def.Name, def.Scale or 1, def.Outfit)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local speed = if isBoss then 15 else 13 + rng:NextNumber(-1, 2)
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = speed
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("BaseSpeed", speed)
	model:SetAttribute("Element", style.Element)
	model:SetAttribute("StyleColor", style.Color)
	model:SetAttribute("IsBoss", isBoss)
	model:SetAttribute("Zone", zoneId)
	model:PivotTo(home + Vector3.new(0, 3 * (def.Scale or 1), 0))
	model.Parent = npcFolder
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			pcall(p.SetNetworkOwner, p, nil)
		end
	end
	NpcFactory.Overhead(model, def.Name, def.Level, if isBoss then Color3.fromRGB(255, 90, 110) else style.Color, isBoss)

	local mob = {
		Model = model,
		Humanoid = humanoid,
		Root = model:FindFirstChild("HumanoidRootPart"),
		Def = def,
		Zone = zoneId,
		Home = home,
		Boss = isBoss,
		Damage = damage,
		Style = style,
		Target = nil,
		NextAttack = 0,
		NextAbility = os.clock() + rng:NextNumber(2, 5),
		NextUltimate = os.clock() + 12,
		NextWander = 0,
		Combo = 0,
		Busy = 0,
	}
	mobs[model] = mob

	if isBoss then
		Remotes.Announce:FireAllClients(("%s (Lv.%d) has appeared in %s!"):format(def.Name, def.Level, Zones.Get(zoneId).Name))
	end

	humanoid.Died:Connect(function()
		mobs[model] = nil
		self:OnDeath(mob, shards, xp)
		task.delay(if isBoss then 5 else 3, function()
			Combat:CleanupModel(model)
			model:Destroy()
		end)
		task.delay(if isBoss then (def.Respawn or 180) else M.Respawn, function()
			self:Spawn(zoneId, def, home, isBoss)
		end)
	end)
	return model
end

function MobService:OnDeath(mob, shards: number, xp: number)
	local Combat = self.Services.CombatService
	local Progression = self.Services.ProgressionService
	local winners
	if mob.Boss then
		winners = Combat:GetContributors(mob.Model, M.BossContributionShare)
	else
		local killer = Combat:GetKiller(mob.Model)
		winners = if killer then { killer } else {}
	end
	for _, player in winners do
		Progression:AddShards(player, shards, true)
		Progression:AddXp(player, xp)
		Progression:AddMasteryXp(player, if mob.Boss then Prog.Mastery.XpPerKill * 10 else Prog.Mastery.XpPerKill)
		if mob.Boss then
			Remotes.Notify:FireClient(player, ("%s defeated! +%d Shards  +%d XP"):format(mob.Def.Name, shards, xp), "level")
		end
	end
	if mob.Boss then
		Remotes.Announce:FireAllClients(("%s was defeated by %d fighter(s)!"):format(mob.Def.Name, #winners))
	end
end

---------------------------------------------------------------------------
-- AI
---------------------------------------------------------------------------

local function findTarget(mob)
	local best, bestDist = nil, M.AggroRange * (if mob.Boss then 1.5 else 1)
	for _, player in Players:GetPlayers() do
		if (player:GetAttribute("Zone") or "Hub") == mob.Zone then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and not character:FindFirstChildOfClass("ForceField") then
				local d = (root.Position - mob.Root.Position).Magnitude
				if d < bestDist then
					best, bestDist = character, d
				end
			end
		end
	end
	return best, bestDist
end

function MobService:Melee(mob, targetRoot: BasePart)
	local Combat = self.Services.CombatService
	local root = mob.Root
	mob.Combo = mob.Combo % 4 + 1
	local finisher = mob.Combo == 4
	local aim = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	if aim.Magnitude < 0.1 then
		return
	end
	aim = aim.Unit
	local facing = CFrame.lookAt(root.Position, root.Position + aim)
	root.CFrame = facing
	fx("Swing", { Character = mob.Model, CFrame = facing, Color = mob.Style.Color, Combo = mob.Combo, Finisher = finisher })
	task.delay(0.12, function()
		if mob.Humanoid.Health <= 0 then
			return
		end
		local reach = M.AttackRange * (mob.Def.Scale or 1) + 2
		local box = CFrame.lookAt(root.Position, root.Position + aim) * CFrame.new(0, 0, -reach / 2)
		for _, victim in Combat:QueryBox(box, Vector3.new(6 * (mob.Def.Scale or 1), 8, reach), mob.Model) do
			Combat:Damage(nil, mob.Model, victim, mob.Damage * (if finisher then 1.8 else 1), {
				Stun = if finisher then 0.8 else 0.35,
				Knockback = if finisher then 50 else 4,
				GuardBreak = finisher and mob.Boss,
				Color = mob.Style.Color,
			})
		end
	end)
end

function MobService:UseAbility(mob, targetRoot: BasePart, ultimate: boolean)
	local Combat = self.Services.CombatService
	local keys = if mob.Boss then { "Q", "E", "R" } else { "Q", "R" }
	local base = if ultimate then mob.Style.Ultimate else mob.Style.Abilities[keys[rng:NextInteger(1, #keys)]]
	-- Copy and rescale the player skill for this mob's damage level.
	local ability = table.clone(base)
	ability.Damage = mob.Damage * (if ultimate then 2.5 else 1.4) / (ability.Hits or 1)
	ability.Windup = math.max(ability.Windup or 0, if ultimate then 1.1 else 0.45) -- readable telegraph
	local aim = (targetRoot.Position - mob.Root.Position) * Vector3.new(1, 0, 1)
	aim = if aim.Magnitude > 0.1 then aim.Unit else mob.Root.CFrame.LookVector
	mob.Root.CFrame = CFrame.lookAt(mob.Root.Position, mob.Root.Position + aim)
	fx("Cast", { Character = mob.Model, Key = if ultimate then "G" else "R", Kind = ability.Kind, Color = mob.Style.Color, Windup = ability.Windup })
	if ultimate then
		fx("Ultimate", { Character = mob.Model, Name = ability.Name, Color = mob.Style.Color, Caster = mob.Def.Name, Windup = ability.Windup })
	end
	mob.Busy = os.clock() + ability.Windup + 0.4
	mob.Humanoid.WalkSpeed = 2
	Combat:CastAbility(nil, mob.Model, ability, aim, mob.Style.Color)
	task.delay(ability.Windup + 0.3, function()
		if mob.Humanoid.Health > 0 then
			Combat:UpdateMovement(mob.Model)
		end
	end)
end

function MobService:Think(mob, now: number)
	local Combat = self.Services.CombatService
	local root = mob.Root
	if not root or now < mob.Busy or Combat:IsStunned(mob.Model) then
		return
	end

	-- Leash: too far from home -> run back and heal.
	local fromHome = (root.Position - mob.Home.Position) * Vector3.new(1, 0, 1)
	if fromHome.Magnitude > M.LeashRange then
		mob.Target = nil
		mob.Humanoid:MoveTo(mob.Home.Position)
		mob.Humanoid.Health = math.min(mob.Humanoid.MaxHealth, mob.Humanoid.Health + mob.Humanoid.MaxHealth * 0.1)
		return
	end

	local target, dist = findTarget(mob)
	mob.Target = target
	if not target then
		if now > mob.NextWander then
			mob.NextWander = now + rng:NextNumber(3, 7)
			local offset = Vector3.new(rng:NextNumber(-18, 18), 0, rng:NextNumber(-18, 18))
			mob.Humanoid:MoveTo(mob.Home.Position + offset)
		end
		return
	end

	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart
	local reach = M.AttackRange * (mob.Def.Scale or 1)
	local lowHealth = mob.Humanoid.Health < mob.Humanoid.MaxHealth * 0.5

	if mob.Boss and lowHealth and now > mob.NextUltimate and dist < 40 then
		mob.NextUltimate = now + 16
		self:UseAbility(mob, targetRoot, true)
	elseif now > mob.NextAbility and dist < 32 then
		mob.NextAbility = now + M.AbilityCooldown * (if mob.Boss then 0.6 else 1) + rng:NextNumber(0, 3)
		self:UseAbility(mob, targetRoot, false)
	elseif dist <= reach + 1 then
		mob.Humanoid:MoveTo(root.Position)
		if now > mob.NextAttack then
			mob.NextAttack = now + M.AttackCooldown * (if mob.Boss then 0.75 else 1)
			self:Melee(mob, targetRoot)
		end
	else
		mob.Humanoid:MoveTo(targetRoot.Position)
	end
end

function MobService:Start()
	local ZoneService = self.Services.ZoneService
	for _, zoneId in Zones.Order do
		local zone = Zones.Get(zoneId)
		local spawns = ZoneService:GetMobSpawns(zoneId)
		local i = 0
		for _, def in zone.Mobs or {} do
			for _ = 1, def.Count do
				i += 1
				local home = spawns[(i - 1) % math.max(1, #spawns) + 1]
				if home then
					task.spawn(self.Spawn, self, zoneId, def, home, false)
				end
			end
		end
		if zone.Boss then
			local bossSpawn = ZoneService:GetBossSpawn(zoneId)
			if bossSpawn then
				task.delay(if zoneId == "Hub" then 20 else 3, function()
					self:Spawn(zoneId, zone.Boss, bossSpawn, true)
				end)
			end
		end
	end

	while true do
		task.wait(TICK)
		local now = os.clock()
		for _, mob in mobs do
			local ok, err = pcall(self.Think, self, mob, now)
			if not ok then
				warn("[Mob] " .. tostring(err))
			end
		end
	end
end

return MobService
