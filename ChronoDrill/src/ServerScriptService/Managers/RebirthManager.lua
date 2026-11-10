-- RebirthManager: перерождения и перки Хроно-Древа (ТЗ 8).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local RebirthData = require(Configs.RebirthData)
local DrillsData = require(Configs.DrillsData)
local BackpacksData = require(Configs.BackpacksData)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local Shop = require(script.Parent.ShopManager)
local Travel = require(script.Parent.TravelManager)
local PetManager = require(script.Parent.PetManager)

local Rebirth = {}

local function doRebirth(player)
	local data = DataManager.Get(player)
	if not data then
		return { ok = false }
	end
	if not Stats.CanRebirth(data) then
		return { ok = false, msg = "Нужно: открыть Магму (4 500 м) и " .. Util.Format(Stats.RebirthCost(data)) .. " монет" }
	end
	local shards = Stats.RebirthShards(data)
	-- сброс (ТЗ 8.2)
	data.Coins = 0
	data.Drill = DrillsData.Starter
	data.OwnedDrills = { [DrillsData.Starter] = true }
	data.Backpack = BackpacksData.Starter
	data.OwnedBackpacks = { [BackpacksData.Starter] = true }
	data.Ore = { Count = 0, Value = 0 }
	data.UnlockedBiome = 1
	data.CurrentBiome = 1
	data.RunMaxDepth = 0
	-- награда (ТЗ 8.4); питомцы, семена, инкубатор, бусты и сюжет сохраняются (ТЗ 8.3)
	data.Rebirths = data.Rebirths + 1
	data.Shards = data.Shards + shards
	Notifier.Alert(player, "Rebirth", { Rebirths = data.Rebirths, Shards = shards })
	Notifier.Toast(player, "Перерождение #" .. data.Rebirths .. "! +" .. shards .. " Хроно-Осколков, продажа x" .. string.format("%.2f", Stats.RebirthMult(data)), "unlock", "Unlock")
	if data.Rebirths == RebirthData.IncubatorSlotAt then
		Notifier.Toast(player, "Открыт 2-й слот инкубатора!", "good")
	end
	Shop.AttachGear(player)
	PetManager.RefreshAttribute(player)
	Travel.ToHub(player)
	StateSync.MarkDirty(player)
	return { ok = true }
end

local function buyPerk(player, id)
	local data = DataManager.Get(player)
	local perk = Stats.PerkById[id]
	if not data or not perk then
		return { ok = false }
	end
	local lvl = data.Perks[id] or 0
	if lvl >= #perk.Costs then
		return { ok = false, msg = "Максимальный уровень" }
	end
	local cost = perk.Costs[lvl + 1]
	if data.Shards < cost then
		return { ok = false, msg = "Нужно " .. cost .. " Хроно-Осколков" }
	end
	data.Shards = data.Shards - cost
	data.Perks[id] = lvl + 1
	Notifier.Toast(player, perk.Name .. ": уровень " .. (lvl + 1), "good", "Unlock")
	PetManager.RefreshAttribute(player)
	StateSync.MarkDirty(player)
	return { ok = true }
end

function Rebirth.Init()
	Net.Get("Rebirth").OnServerInvoke = function(player)
		return doRebirth(player)
	end
	Net.Get("BuyPerk").OnServerInvoke = function(player, id)
		return buyPerk(player, id)
	end
end

return Rebirth
