-- IncubatorManager: Био-камера (ТЗ 5.2). Время считается по os.time(), поэтому
-- семена растут и в оффлайне: isReady = (os.time() - Planted) >= Duration - Cut.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local SeedsData = require(Configs.SeedsData)
local PetsData = require(Configs.PetsData)
local BoostsData = require(Configs.BoostsData)
local Balance = require(Configs.Balance)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local QuestService = require(script.Parent.QuestService)
local PetManager = require(script.Parent.PetManager)

local Incubator = {}
local rng = Random.new()

function Incubator.Remaining(slot)
	if not slot or not slot.Seed then
		return nil
	end
	return math.max(0, (slot.Duration - (slot.Cut or 0)) - (os.time() - slot.Planted))
end

function Incubator.Fertilize(player, data, slotIndex)
	if (data.Boosts.BioFertilizer or 0) <= 0 then
		return { ok = false, msg = "Нет Био-удобрения" }
	end
	local key, slot
	if slotIndex then
		key = tostring(slotIndex)
		slot = data.Incubator[key]
	else
		for i = 1, 3 do
			local s = data.Incubator[tostring(i)]
			if s and s.Seed and Incubator.Remaining(s) > 0 then
				key, slot = tostring(i), s
				break
			end
		end
	end
	if not slot or not slot.Seed or Incubator.Remaining(slot) <= 0 then
		return { ok = false, msg = "Нет растущих семян" }
	end
	data.Boosts.BioFertilizer = data.Boosts.BioFertilizer - 1
	slot.Cut = (slot.Cut or 0) + BoostsData.ById.BioFertilizer.Cut
	Notifier.Toast(player, "Био-удобрение: -15 минут к росту!", "good", "Seed")
	StateSync.MarkDirty(player)
	return { ok = true }
end

local function action(player, act, slotIndex, arg)
	local data = DataManager.Get(player)
	if not data or type(slotIndex) ~= "number" then
		return { ok = false }
	end
	slotIndex = math.floor(slotIndex)
	local maxSlots = Stats.IncubatorSlots(data, StateSync.HasPass(player))
	if slotIndex < 1 or slotIndex > 3 then
		return { ok = false }
	end
	local key = tostring(slotIndex)
	local slot = data.Incubator[key]

	if act == "Plant" then
		if slotIndex > maxSlots then
			return { ok = false, msg = "Слот закрыт" }
		end
		if slot and slot.Seed then
			return { ok = false, msg = "Слот занят" }
		end
		local seed = SeedsData.ById[arg]
		if not seed or (data.Seeds[arg] or 0) <= 0 then
			return { ok = false, msg = "Нет такого семени" }
		end
		data.Seeds[arg] = data.Seeds[arg] - 1
		if data.Seeds[arg] <= 0 then
			data.Seeds[arg] = nil
		end
		data.Incubator[key] = { Seed = arg, Planted = os.time(), Duration = seed.Duration, Cut = 0 }
		data.Stats.SeedsPlanted = data.Stats.SeedsPlanted + 1
		Notifier.Toast(player, seed.Name .. " посажено! Созреет через " .. math.floor(seed.Duration / 60) .. " мин.", "good", "Seed")
	elseif act == "Claim" then
		if not slot or not slot.Seed then
			return { ok = false }
		end
		if Incubator.Remaining(slot) > 0 then
			return { ok = false, msg = "Ещё не созрело" }
		end
		if Stats.PetCount(data) >= Stats.PetStorage(data) then
			return { ok = false, msg = "Инвентарь питомцев полон" }
		end
		local seed = SeedsData.ById[slot.Seed]
		local def = PetsData.ById[seed.Pet]
		local mult = math.floor(def.P * (1 + rng:NextNumber() * 0.2) * 1000 + 0.5) / 1000
		local uid = PetManager.AddPet(data, seed.Pet, mult)
		data.Incubator[key] = nil
		data.Stats.SeedsGrown = data.Stats.SeedsGrown + 1
		if seed.Biome >= 4 then
			data.Stats.RareSeedsGrown = data.Stats.RareSeedsGrown + 1
		end
		QuestService.Track(player, "GrowSeed", 1)
		PetManager.RefreshAttribute(player)
		StateSync.MarkDirty(player)
		return { ok = true, pet = { Id = seed.Pet, Uid = uid, M = mult } }
	elseif act == "Fertilize" then
		return Incubator.Fertilize(player, data, slotIndex)
	else
		return { ok = false }
	end
	StateSync.MarkDirty(player)
	return { ok = true }
end

function Incubator.Init()
	Net.Get("Incubator").OnServerInvoke = function(player, act, slotIndex, arg)
		return action(player, act, slotIndex, arg)
	end
end

return Incubator
