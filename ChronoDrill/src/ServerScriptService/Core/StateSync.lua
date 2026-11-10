-- StateSync: отправляет клиенту снимок его данных + производные характеристики.
-- Изменения помечаются Dirty и пачкой улетают не чаще 6 раз в секунду.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Stats = require(ReplicatedStorage.Shared.Stats)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local DataManager = require(script.Parent.DataManager)

local StateSync = {}
local dirty = {}
local passCache = {}

function StateSync.SetPass(player, value)
	passCache[player] = value
	StateSync.MarkDirty(player)
end

function StateSync.HasPass(player)
	return passCache[player] == true
end

function StateSync.MarkDirty(player)
	dirty[player] = true
end

local function leaderstats(player, data)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local coins = ls:FindFirstChild("Монеты")
	if coins then
		coins.Value = Util.Format(data.Coins)
	end
	local eggs = ls:FindFirstChild("Яйца")
	if eggs then
		eggs.Value = Util.Format(data.Stats and data.Stats.EggsOpened or 0)
	end
	local reb = ls:FindFirstChild("Перерождения")
	if reb then
		reb.Value = data.Rebirths
	end
end

function StateSync.Snapshot(player)
	local data = DataManager.Get(player)
	if not data then
		return nil
	end
	local session = DataManager.GetSession(player)
	local snap = {}
	for k, v in pairs(data) do
		if string.sub(k, 1, 1) ~= "_" then
			snap[k] = v
		end
	end
	local hasPass = StateSync.HasPass(player)
	snap.Derived = {
		Damage = Stats.Damage(data),
		PetSum = Stats.PetSum(data),
		Capacity = Stats.Capacity(data),
		SellMult = Stats.SellMult(data, data.CurrentBiome),
		CoinFactor = Stats.PetCoinFactor(data),
		RebirthMult = Stats.RebirthMult(data),
		PetSlots = Stats.PetSlots(data),
		IncubatorSlots = Stats.IncubatorSlots(data, hasPass),
		HitInterval = Stats.HitInterval(data),
		WalkSpeed = Stats.WalkSpeed(data),
		PickupRadius = Stats.PickupRadius(data),
		RebirthCost = Stats.RebirthCost(data),
		RebirthShards = Stats.RebirthShards(data),
		CanRebirth = Stats.CanRebirth(data),
		HasIncubatorPass = hasPass,
		SessionEggs = session.Eggs,
		ServerTime = os.time(),
		NoSave = data._NoSave == true,
	}
	return snap
end

function StateSync.SendNow(player)
	local snap = StateSync.Snapshot(player)
	if snap then
		Net.Get("DataSync"):FireClient(player, snap)
		local data = DataManager.Get(player)
		leaderstats(player, data)
	end
	dirty[player] = nil
end

function StateSync.Init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.25 then
			return
		end
		acc = 0
		for player in pairs(dirty) do
			if player.Parent then
				StateSync.SendNow(player)
			else
				dirty[player] = nil
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		passCache[player] = nil
	end)
	Net.Get("RequestSync").OnServerInvoke = function(player)
		return StateSync.Snapshot(player)
	end
end

return StateSync
