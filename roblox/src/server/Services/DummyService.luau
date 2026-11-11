-- Training dummies in the hub (the hub boss now lives in MobService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Prog = require(Shared.Config.Progression)
local NpcFactory = require(script.Parent.Parent.Lib.NpcFactory)

local DummyService = {}

local DUMMY_HEALTH = 160
local DUMMY_RESPAWN = 5

function DummyService:Init(services)
	self.Services = services
end

function DummyService:SpawnDummy(cf: CFrame)
	local Combat = self.Services.CombatService
	local Progression = self.Services.ProgressionService
	local Rewards = GameConfig.Rewards

	local outfits = { "Trainee1", "Trainee2", "Trainee3", "Trainee4" }
	local model = NpcFactory.Rig("Training Dummy", 1, outfits[math.random(1, #outfits)])
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = DUMMY_HEALTH
	humanoid.Health = DUMMY_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("BaseSpeed", 0)
	model:SetAttribute("BaseJump", 0)
	model:SetAttribute("Zone", "Hub")
	model:SetAttribute("NoKnockback", true)
	-- Face the arena centre so players see the front, and stay planted.
	local pos = cf.Position
	model:PivotTo(CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)))
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	model.Parent = workspace:FindFirstChild("NPCs")
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			pcall(p.SetNetworkOwner, p, nil)
		end
	end
	NpcFactory.Overhead(model, "Training Dummy", nil, Color3.fromRGB(240, 220, 160), false)

	-- Dummies slowly heal so you can practise combos on them.
	task.spawn(function()
		while humanoid.Parent and humanoid.Health > 0 do
			task.wait(1)
			if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 4)
			end
		end
	end)

	humanoid.Died:Connect(function()
		local killer = Combat:GetKiller(model)
		if killer then
			Progression:AddShards(killer, Rewards.DummyKillShards, true)
			Progression:AddXp(killer, Rewards.DummyKillXp)
			Progression:AddMasteryXp(killer, Prog.Mastery.XpPerKill * 0.5)
			self.Services.QuestService:Progress(killer, "Dummy", 1)
		end
		task.delay(DUMMY_RESPAWN, function()
			Combat:CleanupModel(model)
			model:Destroy()
			self:SpawnDummy(cf)
		end)
	end)
end

function DummyService:Start()
	for _, cf in self.Services.MapService:GetDummySpawns() do
		task.spawn(self.SpawnDummy, self, cf)
	end
end

return DummyService
