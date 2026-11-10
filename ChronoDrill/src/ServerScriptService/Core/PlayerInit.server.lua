-- PlayerInit: точка входа сервера. Собирает ассеты и мир, запускает все сервисы,
-- загружает профили игроков и готовит персонажей.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterPlayer = game:GetService("StarterPlayer")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent
local Managers = script.Parent.Parent:WaitForChild("Managers")

Net.Init()

-- Коллизии: игроки проходят друг сквозь друга (ТЗ 1.3)
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
end)
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
-- осколки блоков (клиентские) не толкают игроков и друг друга
pcall(function()
	PhysicsService:RegisterCollisionGroup("Debris")
end)
PhysicsService:CollisionGroupSetCollidable("Debris", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)

StarterPlayer.CharacterWalkSpeed = Balance.BaseWalkSpeed
StarterPlayer.CharacterJumpPower = 50
StarterPlayer.CameraMaxZoomDistance = 80
Players.RespawnTime = 2

local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local MineReset = require(Core.MineResetService)

local AssetForge = require(Managers.AssetForge)
local WorldBuilder = require(Managers.WorldBuilder)
local QuestService = require(Managers.QuestService)
local Mining = require(Managers.MiningManager)
local Travel = require(Managers.TravelManager)
local PetManager = require(Managers.PetManager)
local Incubator = require(Managers.IncubatorManager)
local Shop = require(Managers.ShopManager)
local Boosts = require(Managers.BoostManager)
local Rebirth = require(Managers.RebirthManager)
local Admin = require(Managers.AdminCommands)
local RewardsManager = require(Managers.RewardsManager)
local Leaderboards = require(Managers.LeaderboardService)
local Passes = require(Managers.PassManager)

local assets = AssetForge.Build()
local points = WorldBuilder.Build(assets)

DataManager.Init()
StateSync.Init()
Travel.Init()
Mining.Init(Travel)
QuestService.Init()
local npcList = {}
for _, pts in pairs(points) do
	table.insert(npcList, pts.NPC)
end
QuestService.SetNpcPositions(npcList)
PetManager.Init()
Incubator.Init()
Shop.Init()
Boosts.Init()
Rebirth.Init()
RewardsManager.Init()
Leaderboards.Init()
Passes.Init()
Admin.Init(Mining, Travel, Passes)

-- настройки игрока (графика и громкость) — только проверенные значения
local QUALITIES = { Low = true, Medium = true, High = true }
Net.Get("SaveSettings").OnServerEvent:Connect(function(player, key, value)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	data.Settings = data.Settings or {}
	if key == "Quality" and QUALITIES[value] then
		data.Settings.Quality = value
	elseif (key == "Music" or key == "Sfx") and type(value) == "number" and value == value then
		data.Settings[key] = math.clamp(value, 0, 1)
	else
		return
	end
	StateSync.MarkDirty(player)
end)
MineReset.Start(Mining, Travel, DataManager)
workspace:SetAttribute("WorldReady", true)

---------------------------------------------------------------------------------------------
-- Персонаж
---------------------------------------------------------------------------------------------
local function setGroup(inst)
	if inst:IsA("BasePart") then
		inst.CollisionGroup = "Players"
	end
end

local function onCharacter(player, char)
	for _, d in ipairs(char:GetDescendants()) do
		setGroup(d)
	end
	char.DescendantAdded:Connect(setGroup)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then
		return
	end
	local data = DataManager.Get(player)
	while not data and player.Parent do
		task.wait(0.2)
		data = DataManager.Get(player)
	end
	if not data then
		return
	end
	hum.WalkSpeed = Stats.WalkSpeed(data)
	hum.BreakJointsOnDeath = false
	task.wait()
	Travel.ToHub(player)
	Shop.AttachGear(player)
	PetManager.RefreshAttribute(player)
end

local function onPlayer(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local coins = Instance.new("StringValue")
	coins.Name = "Монеты"
	coins.Value = "0"
	coins.Parent = ls
	local eggs = Instance.new("StringValue")
	eggs.Name = "Яйца"
	eggs.Value = "0"
	eggs.Parent = ls
	local reb = Instance.new("IntValue")
	reb.Name = "Перерождения"
	reb.Parent = ls

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)

	local data = DataManager.Load(player)
	if not data then
		return
	end
	StateSync.SendNow(player)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	task.delay(2, function()
		if player.Parent then
			Notifier.Toast(player, "Добро пожаловать в Chrono-Drill! Зажми ЛКМ по блоку, чтобы бурить.", "info")
			if Admin.Allowed(player) then
				Notifier.Toast(player, "Ты админ: панель разработчика — F2 или кнопка со щитом. В чате: !coins 1m", "info")
			end
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

Players.PlayerRemoving:Connect(function(player)
	DataManager.Release(player)
end)

-- покупка геймпассов — в Managers/PassManager.lua
