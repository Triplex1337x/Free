-- Double jump (Lv 10) and triple jump (Lv 15): press jump again in the air.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Input = require(script.Parent.InputController)

local player = Players.LocalPlayer

local JumpController = {}

local used = 0
local lastJump = 0
local leftGround = 0

local function extraJumps(): number
	local level = State.Data and State.Data.Level or 1
	local extra = 0
	for _, cfg in Zones.Jumps do
		if level >= cfg.Level then
			extra = math.max(extra, cfg.Extra)
		end
	end
	return extra
end

local function bind(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	used = 0
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Swimming then
			used = 0
		elseif new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
			if leftGround == 0 or used == 0 then
				leftGround = os.clock()
			end
		end
	end)
end

function JumpController:Start()
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)

	UserInputService.JumpRequest:Connect(function()
		if not Input.Enabled then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or humanoid.Health <= 0 or character:GetAttribute("Stunned") then
			return
		end
		local stateNow = humanoid:GetState()
		if stateNow ~= Enum.HumanoidStateType.Freefall and stateNow ~= Enum.HumanoidStateType.Jumping then
			return
		end
		local now = os.clock()
		-- Ignore the press that started the ground jump and hold-to-repeat spam.
		if now - lastJump < 0.25 or now - leftGround < 0.12 then
			return
		end
		if used >= extraJumps() then
			return
		end
		used += 1
		lastJump = now
		local v = root.AssemblyLinearVelocity
		local up = math.sqrt(2 * workspace.Gravity * Zones.AirJumpHeight)
		root.AssemblyLinearVelocity = Vector3.new(v.X, up, v.Z)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		Remotes.Action:FireServer("AirJump", used)
	end)
end

return JumpController
