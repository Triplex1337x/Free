-- MusicController: фоновая музыка с плавными переходами.
-- Треки берутся из ReplicatedStorage.CustomSounds (объекты Sound с именами Music_Hub, Music_Mine, Music_Deep...)
-- или из SoundsData.Music (rbxassetid://...). Пока музыку не загрузили — просто тишина.
-- Громкость — в Настройках.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local SoundsData = require(Configs:WaitForChild("SoundsData"))
local Balance = require(Configs:WaitForChild("Balance"))

local Settings = require(script.Parent.SettingsController)

local Music = {}
local current, currentName = nil, nil
local group

local function soundId(name)
	local custom = ReplicatedStorage:FindFirstChild("CustomSounds")
	local s = custom and custom:FindFirstChild(name)
	if s and s:IsA("Sound") and s.SoundId ~= "" then
		return s.SoundId
	end
	local def = SoundsData.Music and SoundsData.Music[name]
	return def and def.Id ~= "" and def.Id or nil
end

local function play(name)
	if name == currentName then
		return
	end
	currentName = name
	local old = current
	current = nil
	if old then
		local tw = TweenService:Create(old, TweenInfo.new(2), { Volume = 0 })
		tw:Play()
		tw.Completed:Connect(function()
			old:Destroy()
		end)
	end
	local id = soundId(name)
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = group
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2.5), { Volume = 0.5 }):Play()
	current = s
end

function Music.Init()
	group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Parent = SoundService
	local function vol()
		group.Volume = Settings.Get().Music or 0.5
	end
	vol()
	Settings.Changed:Connect(vol)
	local player = Players.LocalPlayer
	task.spawn(function()
		while true do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local b = math.clamp(math.floor(root.Position.X / Balance.BiomeSpacing + 0.5) + 1, 1, 5)
				local deep = root.Position.Y < -6
				local name
				if deep then
					name = b >= 4 and "Music_Deep" or "Music_Mine"
				else
					name = (b >= 4) and "Music_Deep" or "Music_Hub"
				end
				if not soundId(name) then
					name = "Music_Hub"
				end
				play(name)
			end
			task.wait(1)
		end
	end)
end

return Music
