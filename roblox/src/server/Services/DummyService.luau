-- PvE: respawning training dummies and a periodic world boss whose loot is
-- shared by everyone who contributed damage (encourages teaming up).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Remotes = require(Shared.Remotes)

local DummyService = {}

local DUMMY_HEALTH = 160
local DUMMY_RESPAWN = 5

local BOSS = {
	Name = "Rift Warden",
	Health = 2500,
	Speed = 13,
	AggroRange = 70,
	AttackRange = 10,
	AttackCooldown = 2.2,
	AttackWindup = 0.55,
	Damage = 16,
	SlamRadius = 13,
	Respawn = 180,
	Color = Color3.fromRGB(150, 60, 220),
}

local npcFolder = Instance.new("Folder")
npcFolder.Name = "NPCs"
npcFolder.Parent = workspace

local function makeRig(name: string, scale: number, bodyColor: Color3): Model
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = scale
	description.WidthScale = scale
	description.DepthScale = scale
	description.HeadScale = scale
	for _, prop in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do
		description[prop] = bodyColor
	end
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	return model
end

local function freeNetworkOwner(model: Model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			pcall(p.SetNetworkOwner, p, nil)
		end
	end
end

function DummyService:Init(services)
	self.Services = services
end

function DummyService:SpawnDummy(cf: CFrame)
	local Combat = self.Services.CombatService
	local Progression = self.Services.ProgressionService
	local Rewards = GameConfig.Rewards

	local model = makeRig("Training Dummy", 1, Color3.fromRGB(205, 190, 160))
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = DUMMY_HEALTH
	humanoid.Health = DUMMY_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("BaseSpeed", 0)
	model:SetAttribute("BaseJump", 0)
	model:PivotTo(cf)
	model.Parent = npcFolder
	freeNetworkOwner(model)

	humanoid.Died:Connect(function()
		local killer = Combat:GetKiller(model)
		if killer then
			Progression:AddShards(killer, Rewards.DummyKillShards, true)
			Progression:AddXp(killer, Rewards.DummyKillXp)
		end
		task.delay(DUMMY_RESPAWN, function()
			Combat:CleanupModel(model)
			model:Destroy()
			self:SpawnDummy(cf)
		end)
	end)
end

function DummyService:SpawnBoss(cf: CFrame)
	local Combat = self.Services.CombatService
	local Progression = self.Services.ProgressionService
	local Rewards = GameConfig.Rewards

	local model = makeRig(BOSS.Name, 1.9, Color3.fromRGB(40, 30, 60))
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = BOSS.Health
	humanoid.Health = BOSS.Health
	humanoid.WalkSpeed = BOSS.Speed
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("BaseSpeed", BOSS.Speed)
	model:SetAttribute("IsBoss", true)

	local glow = Instance.new("Highlight")
	glow.FillColor = BOSS.Color
	glow.FillTransparency = 0.7
	glow.OutlineColor = BOSS.Color
	glow.Parent = model

	model:PivotTo(cf)
	model.Parent = npcFolder
	freeNetworkOwner(model)
	Remotes.Announce:FireAllClients(BOSS.Name .. " has emerged from the Rift! Defeat it together for big rewards.")

	local alive = true
	humanoid.Died:Connect(function()
		alive = false
		local winners = Combat:GetContributors(model, GameConfig.Rewards.BossContributionShare)
		for _, player in winners do
			Progression:AddShards(player, Rewards.BossShards, true)
			Progression:AddXp(player, Rewards.BossXp)
			Remotes.Notify:FireClient(player, BOSS.Name .. " defeated! +" .. Rewards.BossShards .. " Shards", "success")
		end
		Remotes.Announce:FireAllClients(("%s was defeated by %d fighter(s)!"):format(BOSS.Name, #winners))
		task.delay(6, function()
			Combat:CleanupModel(model)
			model:Destroy()
		end)
		task.delay(BOSS.Respawn, function()
			self:SpawnBoss(cf)
		end)
	end)

	-- Simple AI: chase the nearest player, telegraph, then slam.
	task.spawn(function()
		local root = model:WaitForChild("HumanoidRootPart") :: BasePart
		local lastAttack = 0
		while alive and model.Parent do
			task.wait(0.25)
			if Combat:IsStunned(model) then
				continue
			end
			local target, best = nil, BOSS.AggroRange
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				if hrp and hum and hum.Health > 0 then
					local d = (hrp.Position - root.Position).Magnitude
					if d < best then
						target, best = hrp, d
					end
				end
			end
			if not target then
				if (root.Position - cf.Position).Magnitude > 8 then
					humanoid:MoveTo(cf.Position)
				end
				continue
			end
			humanoid:MoveTo(target.Position)
			if best <= BOSS.AttackRange and os.clock() - lastAttack >= BOSS.AttackCooldown then
				lastAttack = os.clock()
				Remotes.Fx:FireAllClients("Cast", { Character = model, Key = "R", Color = BOSS.Color, Windup = BOSS.AttackWindup })
				humanoid.WalkSpeed = 2
				task.wait(BOSS.AttackWindup)
				if not alive then
					break
				end
				Remotes.Fx:FireAllClients("Burst", { Pos = root.Position, Radius = BOSS.SlamRadius, Color = BOSS.Color, Hits = 1 })
				for _, victim in Combat:QueryRadius(root.Position, BOSS.SlamRadius, model) do
					if Players:GetPlayerFromCharacter(victim) then
						Combat:Damage(nil, model, victim, BOSS.Damage, { Stun = 0.6, Knockback = 60, Color = BOSS.Color })
					end
				end
				Combat:UpdateMovement(model)
			end
		end
	end)
end

function DummyService:Start()
	local Map = self.Services.MapService
	for _, cf in Map:GetDummySpawns() do
		self:SpawnDummy(cf)
	end
	local bossSpawn = Map:GetBossSpawn()
	if bossSpawn then
		task.delay(20, function()
			self:SpawnBoss(bossSpawn)
		end)
	end
end

return DummyService
