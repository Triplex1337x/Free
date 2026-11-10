-- Keyboard / mouse / gamepad input. Touch buttons in the HUD call the same
-- functions. The server validates everything; this only sends intent.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local InputController = {}

local KEYS = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.G] = "G",
	[Enum.KeyCode.ButtonX] = "Q",
	[Enum.KeyCode.ButtonY] = "E",
	[Enum.KeyCode.ButtonB] = "R",
	[Enum.KeyCode.DPadUp] = "G",
}
local BLOCK_KEYS = {
	[Enum.KeyCode.F] = true,
	[Enum.KeyCode.ButtonL2] = true,
}

local blocking = false
local holdingAttack = false

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Aim toward the mouse on PC, camera direction on touch / gamepad.
function InputController.GetAim(): Vector3
	local camera = workspace.CurrentCamera
	local hrp = root()
	if hrp and UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local offset = mouse.Hit.Position - hrp.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 1 then
			return flat.Unit
		end
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

local function face(aim: Vector3)
	local hrp = root()
	if hrp then
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + aim)
	end
end

function InputController.M1()
	local aim = InputController.GetAim()
	face(aim)
	Remotes.Action:FireServer("M1", aim)
end

function InputController.Ability(key: string)
	local aim = InputController.GetAim()
	face(aim)
	Remotes.Action:FireServer("Ability", { Key = key, Aim = aim })
end

function InputController.SetBlock(on: boolean)
	if on == blocking then
		return
	end
	blocking = on
	Remotes.Action:FireServer(if on then "BlockStart" else "BlockEnd")
end

function InputController.SetHoldingAttack(on: boolean)
	if on and not holdingAttack then
		holdingAttack = true
		task.spawn(function()
			while holdingAttack do
				InputController.M1()
				task.wait(0.34)
			end
		end)
	elseif not on then
		holdingAttack = false
	end
end

function InputController:Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			InputController.SetHoldingAttack(true)
		elseif KEYS[input.KeyCode] then
			InputController.Ability(KEYS[input.KeyCode])
		elseif BLOCK_KEYS[input.KeyCode] then
			InputController.SetBlock(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			InputController.SetHoldingAttack(false)
		elseif BLOCK_KEYS[input.KeyCode] then
			InputController.SetBlock(false)
		end
	end)

	player.CharacterAdded:Connect(function()
		blocking = false
		holdingAttack = false
	end)
end

return InputController
