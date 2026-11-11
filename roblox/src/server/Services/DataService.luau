-- Player data: loading with a session lock (prevents item duplication when a
-- player hops servers quickly), autosave, save on leave and on shutdown.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Remotes = require(Shared.Remotes)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }

local STORE_NAME = "RiftPlayerData_v1"
local LOCK_TIMEOUT = 30 * 60
local MAX_LOAD_ATTEMPTS = 6
local MAX_RECEIPTS = 100

local TEMPLATE = {
	Shards = 0,
	Spins = GameConfig.StarterSpins,
	Level = 1,
	Xp = 0,
	Kills = 0,
	Deaths = 0,
	EquippedStyle = GameConfig.StarterStyle,
	OwnedStyles = { [GameConfig.StarterStyle] = true },
	Stats = { Strength = 0, Vitality = 0, Agility = 0, Spirit = 0 },
	StatPoints = 0,
	Mastery = {},
	Quests = {
		Daily = { Period = 0, List = {}, Bonus = false },
		Weekly = { Period = 0, List = {}, Bonus = false },
		Monthly = { Period = 0, List = {}, Bonus = false },
		Chain = { Step = 1, Progress = 0 },
	},
	Inventory = {},
	Buffs = {},
	Settings = { Pvp = false },
	RollsSincePity = 0,
	TotalRolls = 0,
	RedeemedCodes = {},
	ProcessedReceipts = {},
	ReceiptOrder = {},
	LastDaily = 0,
	DailyStreak = 0,
	FirstJoin = 0,
}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local loadedCallbacks = {}
local studioFallback = false

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
end

local function keyFor(userId: number): string
	return "u_" .. userId
end

-- Returns data, savable. Returns nil if the store is unreachable.
local function loadData(userId: number)
	if studioFallback or (not store and RunService:IsStudio()) then
		return deepCopy(TEMPLATE), false
	end
	if not store then
		return nil, false
	end

	for attempt = 1, MAX_LOAD_ATTEMPTS do
		local result, locked = nil, false
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(userId), function(old)
				old = old or {}
				local lock = old.Lock
				local foreignLock = lock and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_TIMEOUT
				-- On the final attempt we take over the lock: the other server
				-- most likely crashed without releasing it.
				if foreignLock and attempt < MAX_LOAD_ATTEMPTS then
					locked = true
					return nil
				end
				locked = false
				old.Lock = { JobId = game.JobId, Time = os.time() }
				result = old.Data
				return old
			end)
		end)

		if ok and not locked then
			local data = result or deepCopy(TEMPLATE)
			reconcile(data, TEMPLATE)
			return data, true
		end

		if not ok then
			warn(("[Data] Load attempt %d for %d failed: %s"):format(attempt, userId, tostring(err)))
			if RunService:IsStudio() then
				warn("[Data] Studio has no DataStore access (Game Settings -> Security). Using temporary data.")
				studioFallback = true
				return deepCopy(TEMPLATE), false
			end
		end
		task.wait(attempt * 2)
	end
	return nil, false
end

local function saveData(userId: number, data, release: boolean): boolean
	if not store then
		return false
	end
	local wrote = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = old or {}
			-- Another server took the session over: never overwrite its data.
			if old.Lock and old.Lock.JobId ~= game.JobId then
				wrote = false
				return nil
			end
			old.Data = data
			old.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			wrote = true
			return old
		end)
	end)
	if not ok then
		warn(("[Data] Save for %d failed: %s"):format(userId, tostring(err)))
	end
	return ok and wrote
end

function DataService:OnLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in self.Profiles do
		task.spawn(callback, player, profile)
	end
end

function DataService:Get(player: Player)
	return self.Profiles[player]
end

function DataService:WaitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 15)
	while not self.Profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return self.Profiles[player]
end

function DataService:SaveNow(player: Player): boolean
	local profile = self.Profiles[player]
	if not profile then
		return false
	end
	if not profile.Savable then
		return true -- Studio test session, nothing to persist
	end
	return saveData(player.UserId, profile.Data, false)
end

-- Records a processed purchase so it is never granted twice.
function DataService:MarkReceipt(profile, purchaseId: string)
	local data = profile.Data
	data.ProcessedReceipts[purchaseId] = os.time()
	table.insert(data.ReceiptOrder, purchaseId)
	while #data.ReceiptOrder > MAX_RECEIPTS do
		local oldest = table.remove(data.ReceiptOrder, 1)
		data.ProcessedReceipts[oldest] = nil
	end
end

function DataService:BuildSnapshot(player: Player)
	local profile = self.Profiles[player]
	if not profile then
		return nil
	end
	local d = profile.Data
	return {
		Shards = d.Shards,
		Spins = d.Spins,
		Level = d.Level,
		Xp = d.Xp,
		XpNeeded = GameConfig.XpForLevel(d.Level),
		Kills = d.Kills,
		Deaths = d.Deaths,
		EquippedStyle = d.EquippedStyle,
		OwnedStyles = d.OwnedStyles,
		RollsSincePity = d.RollsSincePity,
		TotalRolls = d.TotalRolls,
		DailyStreak = d.DailyStreak,
		Stats = d.Stats,
		StatPoints = d.StatPoints,
		Mastery = d.Mastery,
		Quests = d.Quests,
		Inventory = d.Inventory,
		Settings = d.Settings,
		BuffsLeft = (function()
			local now, left = os.time(), {}
			for id, expires in d.Buffs do
				if expires > now then
					left[id] = expires - now
				end
			end
			return left
		end)(),
	}
end

function DataService:Sync(player: Player)
	local snapshot = self:BuildSnapshot(player)
	if snapshot then
		Remotes.DataSync:FireClient(player, snapshot)
	end
	if self.OnSynced then
		self.OnSynced(player)
	end
end

local function onPlayerAdded(player: Player)
	local data, savable = loadData(player.UserId)
	if not player.Parent then
		if data and savable then
			saveData(player.UserId, data, true)
		end
		return
	end
	if not data then
		player:Kick("Не удалось загрузить данные. Перезайди через минуту — ничего не потеряно.")
		return
	end
	if data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end

	local profile = { Data = data, Savable = savable }
	DataService.Profiles[player] = profile

	for _, callback in loadedCallbacks do
		local ok, err = pcall(callback, player, profile)
		if not ok then
			warn("[Data] OnLoaded callback error: " .. tostring(err))
		end
	end
	DataService:Sync(player)
	player:LoadCharacter()
end

local function onPlayerRemoving(player: Player)
	local profile = DataService.Profiles[player]
	if not profile then
		return
	end
	if profile.Savable then
		saveData(player.UserId, profile.Data, true)
	end
	DataService.Profiles[player] = nil
end

function DataService:Start()
	Remotes.GetData.OnServerInvoke = function(player)
		return self:BuildSnapshot(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local pending = 0
		for player, profile in self.Profiles do
			if profile.Savable then
				pending += 1
				task.spawn(function()
					saveData(player.UserId, profile.Data, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	while true do
		task.wait(GameConfig.AutosaveInterval)
		for player, profile in self.Profiles do
			if profile.Savable then
				task.spawn(saveData, player.UserId, profile.Data, false)
			end
		end
	end
end

return DataService
