-- RewardsManager: ежедневные награды (серия 7 дней) и колесо удачи раз в 24 часа.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local RewardsData = require(Configs.RewardsData)
local SeedsData = require(Configs.SeedsData)
local BoostsData = require(Configs.BoostsData)
local PetsData = require(Configs.PetsData)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local PetManager = require(script.Parent.PetManager)

local Rewards = {}
local rng = Random.new()
local busy = {}

-- Превращает запись награды в конкретные предметы и выдаёт их. Возвращает список для UI.
local function grant(player, data, entry, out, silent)
	out = out or {}
	local biome = math.clamp(data.UnlockedBiome or 1, 1, 5)
	if entry.Kind == "Bundle" then
		for _, it in ipairs(entry.Items) do
			grant(player, data, it, out, silent)
		end
	elseif entry.Kind == "Coins" then
		local amount = RewardsData.CoinScale(biome) * entry.Amount
		data.Coins = data.Coins + amount
		data.TotalCoins = data.TotalCoins + amount
		if not silent then
			Notifier.Coins(player, amount, "reward")
		end
		table.insert(out, { Kind = "Coins", Amount = amount, Text = Util.Format(amount) .. " монет" })
	elseif entry.Kind == "Boost" then
		data.Boosts[entry.Id] = (data.Boosts[entry.Id] or 0) + entry.Amount
		table.insert(out, { Kind = "Boost", Id = entry.Id, Amount = entry.Amount, Text = entry.Amount .. "x " .. BoostsData.ById[entry.Id].Name })
	elseif entry.Kind == "Seed" then
		local seed = SeedsData.ByBiome[biome] or SeedsData.List[1]
		data.Seeds[seed.Id] = (data.Seeds[seed.Id] or 0) + (entry.Amount or 1)
		table.insert(out, { Kind = "Seed", Id = seed.Id, Amount = entry.Amount or 1, Text = (entry.Amount or 1) .. "x " .. seed.Name })
	elseif entry.Kind == "Pet" then
		local mult = RewardsData.SpecialMult(entry.Id, biome)
		local uid = PetManager.AddPet(data, entry.Id, mult)
		local def = PetsData.ById[entry.Id]
		table.insert(out, { Kind = "Pet", Id = entry.Id, Uid = uid, M = mult, Text = (def and def.Name or entry.Id) .. " x" .. Util.Format(1 + mult) })
		Notifier.ToastAll(player.DisplayName .. " получил эксклюзив: " .. (def and def.Name or entry.Id) .. "!", "unlock")
	end
	return out
end

local function texts(items)
	local t = {}
	for _, it in ipairs(items) do
		table.insert(t, it.Text)
	end
	return table.concat(t, ", ")
end

function Rewards.DailyState(data)
	local now = os.time()
	local d = data.Daily
	local streak = d.Streak or 0
	if d.Last > 0 and now - d.Last > RewardsData.DailyStreakReset then
		streak = 0
	end
	local ready = d.Last == 0 or now - d.Last >= RewardsData.DailyCooldown
	return ready, (streak % #RewardsData.Daily) + 1, streak
end

local function claimDaily(player)
	local data = DataManager.Get(player)
	if not data then
		return { ok = false }
	end
	local ready, day, streak = Rewards.DailyState(data)
	if not ready then
		return { ok = false, msg = "Следующая награда через " .. Util.Time(RewardsData.DailyCooldown - (os.time() - data.Daily.Last)) }
	end
	local items = grant(player, data, RewardsData.Daily[day])
	data.Daily.Streak = streak + 1
	data.Daily.Last = os.time()
	data.Stats.DailyClaims = (data.Stats.DailyClaims or 0) + 1
	PetManager.RefreshAttribute(player)
	StateSync.MarkDirty(player)
	Notifier.Toast(player, "День " .. day .. ": " .. texts(items), "good", "Unlock")
	return { ok = true, day = day, items = items }
end

local function spinWheel(player)
	local data = DataManager.Get(player)
	if not data then
		return { ok = false }
	end
	if busy[player] then
		return { ok = false, msg = "" }
	end
	local left = RewardsData.WheelCooldown - (os.time() - (data.WheelLast or 0))
	if (data.WheelLast or 0) > 0 and left > 0 then
		return { ok = false, msg = "Колесо снова доступно через " .. Util.Time(left) }
	end
	busy[player] = true
	local total = 0
	for _, seg in ipairs(RewardsData.Wheel) do
		total = total + seg.Weight
	end
	local roll = rng:NextNumber() * total
	local index = #RewardsData.Wheel
	local acc = 0
	for i, seg in ipairs(RewardsData.Wheel) do
		acc = acc + seg.Weight
		if roll <= acc then
			index = i
			break
		end
	end
	data.WheelLast = os.time()
	data.Stats.WheelSpins = (data.Stats.WheelSpins or 0) + 1
	local items = grant(player, data, RewardsData.Wheel[index], nil, true)
	PetManager.RefreshAttribute(player)
	-- синхронизацию придерживаем, чтобы монеты не «прилетели» раньше, чем остановится колесо
	task.delay(4.8, function()
		busy[player] = nil
		if player.Parent then
			StateSync.MarkDirty(player)
			Notifier.Toast(player, "Колесо удачи: " .. texts(items), "good", "Unlock")
		end
	end)
	return { ok = true, index = index, items = items }
end

function Rewards.Init()
	Net.Get("ClaimDaily").OnServerInvoke = claimDaily
	Net.Get("SpinWheel").OnServerInvoke = spinWheel
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
end

return Rewards
