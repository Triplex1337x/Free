-- Client side of the living world: spinning Rift Crystals (hidden once
-- collected), jump pads, idle-animated friendly NPCs, NPC shop prompts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Vfx = require(script.Parent.Parent.Vfx)
local Animator = require(script.Parent.Parent.Animation.Animator)
local Hud = require(script.Parent.HudController)

local player = Players.LocalPlayer

local WorldController = {}

local crystals = {} :: { BasePart }
local pads = {} :: { BasePart }
local skyPads = {} :: { BasePart }
local lastLaunch = 0

local function collectSkyPads(root: Instance?)
	if not root then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "SkyPad" then
			table.insert(skyPads, d)
		end
	end
end

-- Sky platforms are one-way: you jump up through them from below and land
-- on top. Before, jumping into a platform from underneath could wedge the
-- character inside it. Collision is toggled locally, which is what drives
-- your own character's physics.
local function updateSkyPads(root: BasePart, humanoid: Humanoid)
	local feet = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	for _, pad in skyPads do
		local offset = root.Position - pad.Position
		local radius = pad.Size.Y / 2 + 4
		if math.abs(offset.X) < radius and math.abs(offset.Z) < radius then
			local top = pad.Position.Y + pad.Size.X / 2
			pad.CanCollide = feet >= top - 0.9
		elseif not pad.CanCollide then
			pad.CanCollide = true
		end
	end
end

local function scan(world: Instance)
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("CrystalId") then
			table.insert(crystals, d)
		elseif d:IsA("BasePart") and d:GetAttribute("JumpPad") then
			table.insert(pads, d)
		elseif d:IsA("Model") and d.Parent and d.Parent.Name == "Friendlies" then
			Animator.EnableLocomotion(d)
		end
	end
end

local function refreshCrystals()
	local collected = State.Data and State.Data.Collected or {}
	for _, c in crystals do
		local got = collected[c:GetAttribute("CrystalId")] == true
		c.LocalTransparencyModifier = if got then 1 else 0
		local prompt = c:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not got
		end
		local glow = c:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Enabled = not got
		end
	end
end

function WorldController:Start()
	local world = workspace:WaitForChild("World", 30)
	if world then
		scan(world)
	end
	collectSkyPads(workspace:FindFirstChild("Zones"))
	collectSkyPads(workspace:FindFirstChild("Arena"))
	State.Observe(refreshCrystals)

	Remotes.OpenUI.OnClientEvent:Connect(function(what)
		if what == "PotionShop" and Hud.OpenPotionShop then
			Hud.OpenPotionShop()
		end
	end)

	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		-- Crystals bob and spin.
		for i, c in crystals do
			local base = c:GetAttribute("BaseCF")
			if not base then
				c:SetAttribute("BaseCF", c.CFrame)
				base = c.CFrame
			end
			c.CFrame = CFrame.new(base.Position + Vector3.new(0, math.sin(t * 2 + i) * 0.6, 0)) * CFrame.Angles(0.6, t * 1.5 + i, 0.4)
		end
		-- Jump pads: standing on one launches you up toward the sky isles.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			updateSkyPads(root, humanoid)
		end
		if root and os.clock() - lastLaunch > 1 then
			for _, pad in pads do
				local offset = root.Position - pad.Position
				if math.abs(offset.Y) < 4.5 and Vector3.new(offset.X, 0, offset.Z).Magnitude < pad.Size.Y / 2 then
					lastLaunch = os.clock()
					local height = pad:GetAttribute("JumpPad") or 30
					local v = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * workspace.Gravity * height), v.Z)
					Vfx.Ring(CFrame.new(pad.Position), 1, 6, pad.Color, 0.4, 0.4, 20)
					Vfx.Emit(pad.Position, "Glitter", 14, pad.Color)
					break
				end
			end
		end
	end)
end

return WorldController
