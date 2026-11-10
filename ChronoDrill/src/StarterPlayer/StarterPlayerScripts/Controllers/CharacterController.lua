-- CharacterController: процедурная анимация бурильщика для всех персонажей.
-- Рука с буром поднимается вперёд, при бурении — дрожь отдачи и быстрое вращение сверла.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CharacterController = {}
local MiningController
local state = {} -- [character] = { shoulder, orig, r6, raise, spin, bitWeld, bitBase }

local function setup(char)
	local st = { raise = 0, spin = 0 }
	local upper = char:FindFirstChild("RightUpperArm")
	if upper then
		st.shoulder = upper:FindFirstChild("RightShoulder")
	else
		local torso = char:FindFirstChild("Torso")
		st.shoulder = torso and torso:FindFirstChild("Right Shoulder")
		st.r6 = true
	end
	if st.shoulder then
		st.orig = st.shoulder.C0
	end
	state[char] = st
	return st
end

local function findBit(char, st)
	local drill = char:FindFirstChild("EquippedDrill")
	if drill ~= st.drill then
		st.drill = drill
		st.bitWeld = nil
		if drill then
			local bitRoot = drill:FindFirstChild("BitRoot", true)
			local w = bitRoot and bitRoot:FindFirstChild("BitWeld")
			if w then
				st.bitWeld = w
				st.bitBase = w.C0
			end
		end
	end
end

local function update(dt)
	local t = os.clock()
	local localPlayer = Players.LocalPlayer
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char.Parent then
			local st = state[char] or setup(char)
			if st.shoulder and not st.shoulder.Parent then
				st = setup(char)
			end
			findBit(char, st)
			local mining
			if player == localPlayer then
				mining = MiningController and MiningController.Mining
			else
				mining = player:GetAttribute("Mining") == true
			end
			local hasDrill = st.drill ~= nil
			local target = 0
			if hasDrill then
				target = mining and 1 or 0.32
			end
			st.raise = st.raise + (target - st.raise) * math.min(1, dt * 12)
			if st.shoulder and st.orig then
				local shake = mining and math.sin(t * 55) * math.rad(2.5) or 0
				local ang = math.rad(88) * st.raise + shake
				if st.r6 then
					st.shoulder.C0 = st.orig * CFrame.Angles(0, 0, ang)
				else
					st.shoulder.C0 = st.orig * CFrame.Angles(ang, 0, 0)
				end
			end
			if st.bitWeld and st.bitBase then
				local speed = mining and 32 or 2.5
				st.spin = (st.spin + dt * speed) % (math.pi * 2)
				st.bitWeld.C0 = st.bitBase * CFrame.Angles(0, 0, st.spin)
			end
		end
	end
	for char in pairs(state) do
		if not char.Parent then
			state[char] = nil
		end
	end
end

function CharacterController.Init(miningController)
	MiningController = miningController
	RunService.Stepped:Connect(function(_, dt)
		update(dt)
	end)
end

return CharacterController
