-- LightingController: своя атмосфера и цветокоррекция на каждом ярусе (ТЗ 9.1),
-- плавное затемнение по мере спуска в шахту.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local BiomesData = require(Configs:WaitForChild("BiomesData"))
local Balance = require(Configs:WaitForChild("Balance"))

local LightingController = {}
LightingController.Biome = 1
local current = 0
local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function applyBiome(b, instant)
	local biome = BiomesData[b]
	if not biome then
		return
	end
	local info = TweenInfo.new(instant and 0 or 1.6, Enum.EasingStyle.Sine)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		local a = biome.Atmosphere
		TweenService:Create(atm, info, { Density = a.Density, Offset = a.Offset, Color = c3(a.Color), Decay = c3(a.Decay), Glare = a.Glare, Haze = a.Haze }):Play()
	end
	local cc = Lighting:FindFirstChild("Grade")
	if cc then
		local g = biome.Grade
		TweenService:Create(cc, info, { TintColor = c3(g.Tint), Saturation = g.Saturation, Contrast = g.Contrast, Brightness = g.Brightness }):Play()
	end
	TweenService:Create(Lighting, info, { ClockTime = biome.ClockTime }):Play()
	if b >= 4 then
		TweenService:Create(Lighting, info, { OutdoorAmbient = Color3.fromRGB(150, 126, 160) }):Play()
	else
		TweenService:Create(Lighting, info, { OutdoorAmbient = Color3.fromRGB(178, 174, 196) }):Play()
	end
	local bloom = Lighting:FindFirstChild("Bloom")
	if bloom then
		TweenService:Create(bloom, info, { Intensity = (b >= 4) and 0.7 or 0.35 }):Play()
	end
end

-- Декор и пейзаж неактивных ярусов убираем только у себя на клиенте:
-- на экране всегда один остров, это сильно разгружает телефоны.
local hidden = {}
local holder = Instance.new("Folder")
holder.Name = "CulledScenery"
function LightingController.Cull(active)
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	for b = 1, #BiomesData do
		local f = world:FindFirstChild("Biome" .. b)
		if f then
			for _, name in ipairs({ "Decor", "Scenery" }) do
				local key = b .. name
				local keep = math.abs(b - active) == 0
				if keep and hidden[key] then
					hidden[key].Parent = f
					hidden[key] = nil
				elseif not keep and not hidden[key] then
					local d = f:FindFirstChild(name)
					if d then
						d.Parent = holder
						hidden[key] = d
					end
				end
			end
		end
	end
end

function LightingController.Init()
	local player = Players.LocalPlayer
	local depthFactor = 0
	RunService.Heartbeat:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local pos = root.Position
		local b = math.clamp(math.floor(pos.X / Balance.BiomeSpacing + 0.5) + 1, 1, #BiomesData)
		if b ~= current then
			applyBiome(b, current == 0)
			current = b
			LightingController.Biome = b
			LightingController.Cull(b)
		end
		local target = math.clamp(-pos.Y / (Balance.Layers * Balance.BlockSize), 0, 1)
		depthFactor = depthFactor + (target - depthFactor) * math.min(1, dt * 3)
		Lighting.ExposureCompensation = 0.1 - depthFactor * 0.55
	end)
end

return LightingController
