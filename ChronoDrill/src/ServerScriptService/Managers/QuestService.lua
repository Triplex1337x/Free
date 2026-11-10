-- QuestService: сюжетные квесты Drill-Bot 3000, 3 динамических слота (всегда разные) и 4 недельных задания.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local QuestsData = require(Configs.QuestsData)
local BoostsData = require(Configs.BoostsData)
local BiomesData = require(Configs.BiomesData)
local RewardsData = require(Configs.RewardsData)
local Util = require(ReplicatedStorage.Shared.Util)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)

local QuestService = {}
local rng = Random.new()
local npcPositions = {}

function QuestService.SetNpcPositions(list)
	npcPositions = list
end

---------------------------------------------------------------------------------------------
-- Награды
---------------------------------------------------------------------------------------------
function QuestService.GiveReward(player, data, reward)
	local parts = {}
	if reward.Trips and not reward.Coins then
		reward = table.clone(reward)
		reward.Coins = QuestService.WeeklyCoins(data, reward.Trips)
	end
	if reward.Coins and reward.Coins > 0 then
		data.Coins = data.Coins + reward.Coins
		data.TotalCoins = data.TotalCoins + reward.Coins
		table.insert(parts, Util.Format(reward.Coins) .. " монет")
		Notifier.Coins(player, reward.Coins, "quest")
	end
	if reward.Boosts then
		for id, n in pairs(reward.Boosts) do
			data.Boosts[id] = (data.Boosts[id] or 0) + n
			local bd = BoostsData.ById[id]
			table.insert(parts, n .. "x " .. (bd and bd.Name or id))
		end
	end
	if reward.Shards and reward.Shards > 0 then
		data.Shards = (data.Shards or 0) + reward.Shards
		table.insert(parts, reward.Shards .. " Хроно-осколок")
	end
	if reward.PetSlot then
		data.PetSlotBonus = (data.PetSlotBonus or 0) + reward.PetSlot
		table.insert(parts, "+1 слот питомца")
	end
	StateSync.MarkDirty(player)
	return table.concat(parts, ", ")
end

---------------------------------------------------------------------------------------------
-- Сюжетные
---------------------------------------------------------------------------------------------
function QuestService.StoryProgress(player, data)
	local q = QuestsData.Story[data.StoryIndex]
	if not q then
		return nil
	end
	local cur
	if q.Stat == "SessionEggs" then
		cur = DataManager.GetSession(player).Eggs
	else
		cur = data.Stats[q.Stat] or 0
	end
	return q, math.min(cur, q.Target), q.Target
end

local function _nearNpc(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, p in ipairs(npcPositions) do
		if (root.Position - p).Magnitude < 22 then
			return true
		end
	end
	return false
end

local function claimStory(player, data)
	local q, cur, target = QuestService.StoryProgress(player, data)
	if not q then
		return { ok = false, msg = "Все сюжетные квесты выполнены!" }
	end
	if cur < target then
		return { ok = false, msg = "Квест ещё не выполнен" }
	end
	data.StoryIndex = data.StoryIndex + 1
	local text = QuestService.GiveReward(player, data, q.Reward)
	Notifier.Toast(player, "Квест «" .. q.Title .. "» выполнен! Награда: " .. text, "good", "Unlock")
	return { ok = true }
end

---------------------------------------------------------------------------------------------
-- Генерация целей (общая для динамических и недельных)
---------------------------------------------------------------------------------------------
local REWARD_BOOSTS = {
	[1] = { "DrillOvercharge", "LuckyCharm", "CoinElixir" },
	[2] = { "LuckyCharm", "BioFertilizer", "CoinElixir" },
	[3] = { "CoinElixir", "DrillOvercharge", "LuckyCharm" },
}

-- красивое число: 1234 -> 1200, 56789 -> 57000
local function nice(n)
	if n < 100 then
		return math.max(1, math.floor(n + 0.5))
	end
	local p = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(math.floor(n / p + 0.5) * p + 0.5)
end

-- монет за полный рюкзак в ярусе b (без бустов)
local function backpackCoins(data, b)
	local bd = BiomesData[b]
	local per = (bd.Ore[1] + bd.Ore[2]) / 2 * 1.1
	return Stats.Capacity(data) * per * bd.SellMult * Stats.PetCoinFactor(data) * Stats.RebirthMult(data)
end

local function baseDamage(data)
	return Stats.Drill(data).Damage * Stats.PetSum(data)
end

local function rollTarget(t, data, b, scale)
	scale = scale or 1
	if t.Hits then
		return nice(rng:NextInteger(t.Hits[1], t.Hits[2]) * baseDamage(data))
	elseif t.Trips then
		return nice(rng:NextNumber(t.Trips[1], t.Trips[2]) * backpackCoins(data, b))
	elseif t.DepthFrac then
		local bd = BiomesData[b]
		local f = rng:NextNumber(t.DepthFrac[1], t.DepthFrac[2])
		return nice(bd.MinDepth + (bd.MaxDepth - bd.MinDepth) * f)
	end
	local n = rng:NextInteger(t.Base[1], t.Base[2]) + (t.PerBiome or 0) * (b - 1)
	return math.max(1, math.floor(n * scale + 0.5))
end

local function questText(t, target, b)
	local name = BiomesData[b].Short or BiomesData[b].Name
	local text = string.gsub(t.Text, "{n}", (string.gsub(Util.Format(target), "%%", "%%%%")))
	text = string.gsub(text, "{b}", (string.gsub(name, "%%", "%%%%")))
	return text
end

-- монеты за недельное задание: по открытому ярусу на момент получения
function QuestService.WeeklyCoins(data, trips)
	return math.floor(RewardsData.CoinScale(math.max(1, data.UnlockedBiome or 1)) * trips * Stats.RebirthMult(data))
end

---------------------------------------------------------------------------------------------
-- Динамические
---------------------------------------------------------------------------------------------
local function available(t, data)
	if t.NeedsSeed and Util.Count(data.Seeds) == 0 then
		return false
	end
	if t.NeedsBoost then
		local n = 0
		for id, c in pairs(data.Boosts) do
			if id ~= "BioFertilizer" then
				n = n + c
			end
		end
		if n == 0 then
			return false
		end
	end
	return true
end

local function generate(player, data, slot)
	local key = tostring(slot)
	local pool = QuestsData.Dynamic[slot]
	data.QuestHistory = data.QuestHistory or {}
	local hist = data.QuestHistory[key] or {}
	-- типы, которые были у ДРУГИХ слотов сейчас, тоже не берём — на экране всегда 3 разных задания
	local busy = {}
	for s = 1, 3 do
		local q = data.Dynamic[tostring(s)]
		if s ~= slot and q and q.Type then
			busy[q.Type] = true
		end
	end
	local options = {}
	for _, t in ipairs(pool) do
		if available(t, data) and not busy[t.Type] and not table.find(hist, t.Type) then
			table.insert(options, t)
		end
	end
	if #options == 0 then
		for _, t in ipairs(pool) do
			if available(t, data) and not busy[t.Type] and t.Type ~= hist[#hist] then
				table.insert(options, t)
			end
		end
	end
	if #options == 0 then
		options = { pool[1] }
	end
	local t = options[rng:NextInteger(1, #options)]
	table.insert(hist, t.Type)
	while #hist > 2 do
		table.remove(hist, 1)
	end
	data.QuestHistory[key] = hist

	local b = data.CurrentBiome or 1
	local target = rollTarget(t, data, b)
	local boosts = REWARD_BOOSTS[slot]
	local boostId = boosts[rng:NextInteger(1, #boosts)]
	local reward = {
		Coins = math.floor(RewardsData.CoinScale(b) * rng:NextNumber(0.6, 1.4) * Stats.RebirthMult(data)),
		Boosts = { [boostId] = 1 },
	}
	data.Dynamic[key] = {
		Type = t.Type,
		Text = questText(t, target, b),
		Target = target,
		Progress = 0,
		Biome = b,
		Max = t.Type == "Depth" or nil,
		Reward = reward,
	}
end

---------------------------------------------------------------------------------------------
-- Недельные: 4 разных задания, обновляются в понедельник 00:00 UTC (03:00 МСК)
---------------------------------------------------------------------------------------------
local WEEK = 7 * 24 * 3600
local function weekIndex(t)
	-- 1 января 1970 — четверг, сдвиг на 3 дня даёт начало недели в понедельник
	return math.floor((t + 3 * 24 * 3600) / WEEK)
end

function QuestService.WeekEnds(t)
	t = t or os.time()
	return (weekIndex(t) + 1) * WEEK - 3 * 24 * 3600
end

local function generateWeekly(player, data)
	local wk = weekIndex(os.time())
	local b = math.max(1, data.UnlockedBiome or 1)
	local pool = {}
	for _, t in ipairs(QuestsData.Weekly) do
		table.insert(pool, t)
	end
	-- не повторяем прошлую неделю, если есть из чего выбрать
	local last = {}
	for _, q in ipairs((data.Weekly and data.Weekly.Quests) or {}) do
		last[q.Type] = true
	end
	local fresh = {}
	for _, t in ipairs(pool) do
		if not last[t.Type] then
			table.insert(fresh, t)
		end
	end
	if #fresh >= 4 then
		pool = fresh
	end
	local quests = {}
	local scale = 1 + 0.25 * (b - 1)
	for i = 1, 4 do
		local t = table.remove(pool, rng:NextInteger(1, #pool))
		local target = rollTarget(t, data, b, scale)
		local boosts = REWARD_BOOSTS[((i - 1) % 3) + 1]
		quests[i] = {
			Type = t.Type,
			Text = questText(t, target, b),
			Target = target,
			Progress = 0,
			Reward = {
				Trips = math.floor(rng:NextNumber(6, 9) * 10 + 0.5) / 10,
				Boosts = { [boosts[rng:NextInteger(1, #boosts)]] = 2 },
				Shards = i == 4 and 1 or nil,
			},
		}
	end
	data.Weekly = { Week = wk, Quests = quests, BonusClaimed = false, Ends = QuestService.WeekEnds() }
	StateSync.MarkDirty(player)
end

function QuestService.Track(player, qtype, amount, biome)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	local changed = false
	local function bump(q, isWeekly)
		if not q or q.Type ~= qtype or q.Claimed or (q.Progress or 0) >= q.Target then
			return
		end
		if qtype == "MineBlocks" and not isWeekly and biome ~= nil and biome ~= q.Biome then
			return
		end
		if qtype == "Depth" then
			if isWeekly or (biome ~= nil and biome ~= q.Biome) then
				return
			end
			if amount > q.Progress then
				q.Progress = math.min(q.Target, math.floor(amount))
				changed = true
			end
			return
		end
		q.Progress = math.min(q.Target, q.Progress + amount)
		changed = true
	end
	for slot = 1, 3 do
		bump(data.Dynamic[tostring(slot)], false)
	end
	if data.Weekly and data.Weekly.Quests then
		for _, q in ipairs(data.Weekly.Quests) do
			bump(q, true)
		end
	end
	if changed then
		StateSync.MarkDirty(player)
	end
end

local function claimDynamic(player, data, slot)
	local key = tostring(slot)
	local q = data.Dynamic[key]
	if not q or not q.Target or q.Progress < q.Target then
		return { ok = false, msg = "Задание ещё не выполнено" }
	end
	local text = QuestService.GiveReward(player, data, q.Reward)
	data.Stats.QuestsDone = (data.Stats.QuestsDone or 0) + 1
	-- новое задание выдаётся сразу, без таймера ожидания
	data.Dynamic[key] = { LastType = q.Type }
	generate(player, data, slot)
	StateSync.MarkDirty(player)
	Notifier.Toast(player, "Задание выполнено! " .. text, "good", "Coins")
	return { ok = true }
end

local function claimWeekly(player, data, i)
	local w = data.Weekly
	local q = w and w.Quests and w.Quests[i]
	if not q or q.Claimed or q.Progress < q.Target then
		return { ok = false, msg = "Задание ещё не выполнено" }
	end
	q.Claimed = true
	local reward = { Boosts = q.Reward.Boosts, Shards = q.Reward.Shards, Coins = q.Reward.Coins }
	if q.Reward.Trips then
		reward.Coins = QuestService.WeeklyCoins(data, q.Reward.Trips)
	end
	local text = QuestService.GiveReward(player, data, reward)
	data.Stats.WeeklyDone = (data.Stats.WeeklyDone or 0) + 1
	Notifier.Toast(player, "Недельное задание выполнено! " .. text, "good", "Unlock")
	return { ok = true }
end

local function claimWeeklyBonus(player, data)
	local w = data.Weekly
	if not w or w.BonusClaimed or not w.Quests or #w.Quests == 0 then
		return { ok = false, msg = "Бонус недоступен" }
	end
	for _, q in ipairs(w.Quests) do
		if not q.Claimed then
			return { ok = false, msg = "Сначала заверши все недельные задания" }
		end
	end
	w.BonusClaimed = true
	local reward = QuestsData.WeeklyBonus.Reward
	local text = QuestService.GiveReward(player, data, { Boosts = reward.Boosts })
	local PetManager = require(script.Parent.PetManager)
	local petId = reward.Pet
	local mult = RewardsData.SpecialMult(petId, data.UnlockedBiome or 1)
	PetManager.AddPet(data, petId, mult)
	local name = RewardsData.SpecialPets[petId].Name
	Notifier.Toast(player, "Недельный бонус: " .. name .. " x" .. Util.Format(1 + mult) .. "! " .. text, "unlock", "Unlock")
	Notifier.ToastAll(player.DisplayName .. " получил эксклюзив: " .. name .. "!", "unlock")
	return { ok = true, pet = petId }
end

local function refresh(player, data)
	local now = os.time()
	-- опытным игрокам (сейвы до 1.3) обучение не показываем
	if (data.TutorialStep or 0) == 0 and (data.Stats.BlocksBroken or 0) > 200 then
		data.TutorialStep = 99
		StateSync.MarkDirty(player)
	end
	for slot = 1, 3 do
		local key = tostring(slot)
		local q = data.Dynamic[key]
		if q == nil or q.Cooldown or not q.Type then
			generate(player, data, slot)
			StateSync.MarkDirty(player)
		end
	end
	if not data.Weekly or data.Weekly.Week ~= weekIndex(now) or not data.Weekly.Quests or #data.Weekly.Quests == 0 then
		generateWeekly(player, data)
	end
end

function QuestService.Init()
	Net.Get("ClaimQuest").OnServerInvoke = function(player, kind, slot)
		local data = DataManager.Get(player)
		if not data then
			return { ok = false }
		end
		local res
		if kind == "Story" then
			res = claimStory(player, data)
		elseif kind == "Dynamic" and type(slot) == "number" and slot >= 1 and slot <= 3 then
			res = claimDynamic(player, data, slot)
		elseif kind == "Weekly" and type(slot) == "number" and slot >= 1 and slot <= 4 then
			res = claimWeekly(player, data, math.floor(slot))
		elseif kind == "WeeklyBonus" then
			res = claimWeeklyBonus(player, data)
		else
			res = { ok = false }
		end
		StateSync.MarkDirty(player)
		return res
	end
	-- обучение новичка: клиент сообщает пройденный шаг, сервер только запоминает максимум
	Net.Get("Tutorial").OnServerEvent:Connect(function(player, step)
		local data = DataManager.Get(player)
		if data and type(step) == "number" and step == step then
			data.TutorialStep = math.clamp(math.max(data.TutorialStep or 0, math.floor(step)), 0, 99)
			StateSync.MarkDirty(player)
		end
	end)
	task.spawn(function()
		local minute = 0
		while true do
			minute = minute + 1
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataManager.Get(player)
				if data then
					refresh(player, data)
				end
			end
			if minute >= 60 then
				minute = 0
				for _, player in ipairs(Players:GetPlayers()) do
					QuestService.Track(player, "PlayMinutes", 1)
				end
			end
			task.wait(1)
		end
	end)
end

return QuestService
