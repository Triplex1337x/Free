-- DataManager: загрузка и сохранение профилей игроков.
-- Аналог ProfileService на встроенном DataStoreService: сессионная блокировка,
-- автосейв, сохранение при выходе и при закрытии сервера, миграция новых полей.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local DrillsData = require(Configs.DrillsData)
local BackpacksData = require(Configs.BackpacksData)
local Util = require(ReplicatedStorage.Shared.Util)

local DataManager = {}
DataManager.Profiles = {}
DataManager.Session = {} -- данные, которые не сохраняются (счётчики за сессию)

local LOCK_TIMEOUT = 600
local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(Balance.DataStoreName)
end)
if not storeOk then
	store = nil
end

local loadedEvent = Instance.new("BindableEvent")
DataManager.Loaded = loadedEvent.Event

function DataManager.Template()
	return {
		Version = 1,
		Coins = 0,
		TotalCoins = 0,
		Shards = 0,
		Rebirths = 0,
		Drill = DrillsData.Starter,
		OwnedDrills = { [DrillsData.Starter] = true },
		Backpack = BackpacksData.Starter,
		OwnedBackpacks = { [BackpacksData.Starter] = true },
		Ore = { Count = 0, Value = 0 },
		UnlockedBiome = 1,
		CurrentBiome = 1,
		RunMaxDepth = 0,
		Pets = {},
		NextPetUid = 1,
		PetSlotBonus = 0,
		AutoDelete = {}, -- [Id питомца] = true — удалять сразу при выпадении из яйца
		PetStorageLevel = 0, -- сколько раз докуплено +10 мест в инвентаре питомцев
		Seeds = {},
		Incubator = {},
		Boosts = { CoinElixir = 0, DrillOvercharge = 0, LuckyCharm = 0, BioFertilizer = 0 },
		Passes = {}, -- [Key] = true — купленные/выданные геймпасы
		ActiveBoosts = { CoinElixir = 0, DrillOvercharge = 0, LuckyCharm = 0 },
		Perks = { DrillSpeed = 0, Capacity = 0, WalkSpeed = 0, Magnet = 0, PetSlot = 0 },
		StoryIndex = 1,
		Daily = { Streak = 0, Last = 0 },
		WheelLast = 0,
		Dynamic = {},
		QuestHistory = {},
		Weekly = { Week = 0, Quests = {}, BonusClaimed = false },
		TutorialStep = 0,
		Settings = { Quality = "", Music = 0.5, Sfx = 0.75 },
		Index = {},
		Stats = {
			BlocksBroken = 0, Biome1Blocks = 0, AmberBlocks = 0, IceBlocks = 0,
			EggsOpened = 0, EggsBiome1 = 0, MaxDepth = 0, TotalDamage = 0,
			SeedsPlanted = 0, SeedsGrown = 0, RareSeedsGrown = 0, GoldenCrafted = 0,
			Crits = 0, Sells = 0, PlayTime = 0, DailyClaims = 0, WheelSpins = 0,
			QuestsDone = 0, WeeklyDone = 0, Nuggets = 0, VeinsBroken = 0,
		},
		Tutorial = true,
	}
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function cleanForSave(data)
	local copy = Util.DeepCopy(data)
	return copy
end

function DataManager.Get(player)
	return DataManager.Profiles[player]
end

function DataManager.GetSession(player)
	local s = DataManager.Session[player]
	if not s then
		s = { Eggs = 0, LastSellFull = false }
		DataManager.Session[player] = s
	end
	return s
end

local function tryLoad(player)
	if not store then
		return nil, "nostore"
	end
	local key = keyFor(player)
	local result
	for attempt = 1, 6 do
		local locked = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				old = old or {}
				local lock = old._Lock
				if lock and lock.Job ~= game.JobId and (os.time() - (lock.Time or 0)) < LOCK_TIMEOUT and attempt < 6 then
					locked = true
					return nil
				end
				old._Lock = { Job = game.JobId, Time = os.time() }
				result = old
				return old
			end)
		end)
		if ok and not locked then
			return result
		end
		if not ok then
			warn("[DataManager] ошибка загрузки:", err)
		end
		if not player.Parent then
			return nil, "left"
		end
		task.wait(locked and 4 or 2)
	end
	return nil, "failed"
end

function DataManager.Load(player)
	local raw, err = tryLoad(player)
	if not player.Parent then
		return
	end
	local data
	if raw then
		raw._Lock = nil
		data = Util.Reconcile(raw, DataManager.Template())
	else
		data = DataManager.Template()
		if err == "nostore" then
			warn("[DataManager] DataStore недоступен (в Studio включите Game Settings → Security → Enable Studio Access to API Services). Прогресс не сохранится.")
		elseif err == "failed" then
			warn("[DataManager] не удалось загрузить данные, прогресс этой сессии не будет сохранён", player.Name)
		end
		data._NoSave = (err ~= nil)
	end
	data.Ore = data.Ore or { Count = 0, Value = 0 }
	DataManager.Profiles[player] = data
	DataManager.GetSession(player)
	loadedEvent:Fire(player, data)
	return data
end

function DataManager.Save(player, release)
	local data = DataManager.Profiles[player]
	if not data or data._NoSave or not store then
		return
	end
	local copy = cleanForSave(data)
	copy._NoSave = nil
	local key = keyFor(player)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				if old and old._Lock and old._Lock.Job ~= game.JobId then
					-- кто-то другой захватил профиль — не перезаписываем
					return nil
				end
				if release then
					copy._Lock = nil
				else
					copy._Lock = { Job = game.JobId, Time = os.time() }
				end
				return copy
			end)
		end)
		if ok then
			return true
		end
		warn("[DataManager] ошибка сохранения:", err)
		task.wait(1)
	end
	return false
end

function DataManager.Release(player)
	DataManager.Save(player, true)
	DataManager.Profiles[player] = nil
	DataManager.Session[player] = nil
end

function DataManager.Init()
	task.spawn(function()
		while true do
			task.wait(Balance.AutoSaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				if DataManager.Profiles[player] then
					task.spawn(DataManager.Save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if DataManager.Profiles[player] then
				pending = pending + 1
				task.spawn(function()
					DataManager.Save(player, true)
					pending = pending - 1
				end)
			end
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.2)
		end
	end)
end

return DataManager
