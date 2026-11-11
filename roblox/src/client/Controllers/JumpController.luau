-- Double jump (Lv 10) and triple jump (Lv 15): press jump again in the air.
--
-- Airborne detection uses Humanoid.FloorMaterial (Air = not standing on
-- anything), which is far more reliable than StateChanged: state events can
-- arrive late or flicker between Freefall/Running on slopes and edges, which
-- used to reset the counter mid-air or eat presses. We also no longer call
-- ChangeState(Jumping) — that added Roblox's own jump impulse on top of ours,
-- giving random heights.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
local lastAirJump = 0
local airborneSince = nil :: number?
local groundedSince = os.clock()

local MIN_AIR_TIME = 0.14 -- press that started the ground jump is ignored
local DEBOUNCE = 0.28 -- one air jump per press, even when holding the button

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

local function humanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isAirborne(humanoid: Humanoid): boolean
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return false
	end
	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.Climbing
		and state ~= Enum.HumanoidStateType.Seated
		and state ~= Enum.HumanoidStateType.Dead
end

function JumpController:Start()
	player.CharacterAdded:Connect(function()
		used = 0
		airborneSince = nil
	end)

	-- Track ground contact every frame. Landing needs a short stable contact
	-- (0.05s) so brushing a wall or a ledge corner doesn't refill jumps.
	RunService.Heartbeat:Connect(function()
		local humanoid = humanoidAndRoot()
		if not humanoid then
			return
		end
		local now = os.clock()
		if isAirborne(humanoid) then
			airborneSince = airborneSince or now
			groundedSince = now
		else
			airborneSince = nil
			if now - groundedSince > 0.05 then
				used = 0
			end
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		if not Input.Enabled then
			return
		end
		local humanoid, root = humanoidAndRoot()
		local character = player.Character
		if not humanoid or not root or not character or humanoid.Health <= 0 or character:GetAttribute("Stunned") then
			return
		end
		local now = os.clock()
		if not airborneSince or now - airborneSince < MIN_AIR_TIME or now - lastAirJump < DEBOUNCE then
			return
		end
		if used >= extraJumps() then
			return
		end
		used += 1
		lastAirJump = now
		local v = root.AssemblyLinearVelocity
		local up = math.sqrt(2 * workspace.Gravity * Zones.AirJumpHeight)
		-- Keep horizontal momentum, replace (not add to) vertical speed so
		-- every air jump has the same height whether rising or falling.
		root.AssemblyLinearVelocity = Vector3.new(v.X, up, v.Z)
		Remotes.Action:FireServer("AirJump", used)
	end)
end

return JumpController
