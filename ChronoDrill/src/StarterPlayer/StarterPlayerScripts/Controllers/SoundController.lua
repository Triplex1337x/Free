-- SoundController: проигрывание звуков из SoundsData с вариацией высоты.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundsData = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("SoundsData"))

local SoundController = {}
local cache = {}
local group

-- свои звуки: ReplicatedStorage.CustomSounds.<Имя> (Sound) перекрывает SoundsData
local function customId(name)
	local folder = ReplicatedStorage:FindFirstChild("CustomSounds")
	local c = folder and folder:FindFirstChild(name)
	if c and c:IsA("Sound") and c.SoundId ~= "" then
		return c.SoundId
	end
	return nil
end

local function get(name)
	local s = cache[name]
	if s then
		return s
	end
	local def = SoundsData[name]
	local id = customId(name) or (def and def.Id)
	if not def or not id or id == "" then
		return nil
	end
	s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s:SetAttribute("Custom", customId(name) ~= nil)
	s.Volume = def.Volume or 0.5
	s.SoundGroup = group
	s.Parent = SoundService
	cache[name] = s
	return s
end

function SoundController.Play(name, pitchVar, volumeMul)
	local def = SoundsData[name]
	local base = get(name)
	if not base or not def then
		return
	end
	local s = base:Clone()
	local custom = base:GetAttribute("Custom") == true
	local pitch = custom and 1 or (def.Pitch or 1)
	if pitchVar then
		pitch = pitch * (1 + (math.random() * 2 - 1) * pitchVar)
	end
	s.PlaybackSpeed = pitch
	s.Volume = (custom and (def.CustomVolume or 0.6) or (def.Volume or 0.5)) * (volumeMul or 1)
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

function SoundController.Init()
	group = Instance.new("SoundGroup")
	group.Name = "SFX"
	group.Volume = 0.8
	group.Parent = SoundService
	local Settings = require(script.Parent.SettingsController)
	local function vol()
		group.Volume = Settings.Get().Sfx or 0.75
	end
	vol()
	Settings.Changed:Connect(vol)
	for name, def in pairs(SoundsData) do
		local s = (name ~= "Music") and get(name)
		if s then
			-- прелоад
			task.spawn(function()
				pcall(function()
					game:GetService("ContentProvider"):PreloadAsync({ s })
				end)
			end)
		end
	end
end

return SoundController
