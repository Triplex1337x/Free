-- Stats: все производные характеристики игрока. Используется и сервером, и клиентом,
-- чтобы цифры в интерфейсе всегда совпадали с серверными расчётами.
local Configs = script.Parent.Parent:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local PetsData = require(Configs.PetsData)
local DrillsData = require(Configs.DrillsData)
local BackpacksData = require(Configs.BackpacksData)
local BiomesData = require(Configs.BiomesData)
local RebirthData = require(Configs.RebirthData)
local BoostsData = require(Configs.BoostsData)
local GamepassesData = require(Configs.GamepassesData)

local Stats = {}
Stats.INFINITE = 1e18 -- вместимость «бесконечного» рюкзака (геймпасс)
local FX = GamepassesData.Effects

-- геймпассы
function Stats.HasPass(data, key)
	return data ~= nil and data.Passes ~= nil and data.Passes[key] == true
end

-- серверные события (админ-панель): множители лежат в атрибутах workspace
-- Event_Coins / Event_Damage / Event_Luck и время окончания Event_<Kind>_Until (os.time)
function Stats.EventMult(kind)
	local ok, v, t = pcall(function()
		return workspace:GetAttribute("Event_" .. kind), workspace:GetAttribute("Event_" .. kind .. "_Until")
	end)
	if ok and type(v) == "number" and type(t) == "number" and os.time() < t then
		return v
	end
	return 1
end

local perkById = {}
for _, p in ipairs(RebirthData.Perks) do
	perkById[p.Id] = p
end
Stats.PerkById = perkById

function Stats.PerkLevel(data, id)
	return (data.Perks and data.Perks[id]) or 0
end

-- Сила питомца с учётом улучшения (★) и уровня
function Stats.PetTier(pet)
	return Balance.PetTiers[(pet.T or 0) + 1] or Balance.PetTiers[1]
end

function Stats.PetLevelMult(pet)
	return 1 + Balance.PetLevelBonus * ((pet.L or 1) - 1)
end

function Stats.PetPower(pet)
	local def = PetsData.ById[pet.Id]
	if not def then
		return 0
	end
	return (pet.B or def.P or 0) * Stats.PetTier(pet).Mult * Stats.PetLevelMult(pet)
end

-- бонусы одного питомца: к урону и к продаже (доли: 0.25 = +25%)
function Stats.PetBonus(pet)
	local def = PetsData.ById[pet.Id]
	if not def then
		return 0, 0
	end
	local p = Stats.PetPower(pet)
	return p * (def.DmgF or 1), p * (def.SellF or 1)
end

-- для сортировки и коротких подписей
function Stats.PetMult(pet)
	local d, s = Stats.PetBonus(pet)
	return 1 + (d + s) / 2
end

function Stats.PetXpNeed(level)
	return math.floor(Balance.PetXpBase * math.pow(level, Balance.PetXpExp))
end

function Stats.EquippedPets(data)
	local list = {}
	for uid, pet in pairs(data.Pets or {}) do
		if pet.E then
			table.insert(list, { Uid = uid, Pet = pet })
		end
	end
	table.sort(list, function(a, b)
		local ma, mb = Stats.PetMult(a.Pet), Stats.PetMult(b.Pet)
		if ma ~= mb then
			return ma > mb
		end
		return a.Uid < b.Uid
	end)
	return list
end

-- Множитель урона от питомцев: 1 + сумма бонусов экипированных
function Stats.PetSum(data)
	local sum = 1
	for _, e in ipairs(Stats.EquippedPets(data)) do
		local d = Stats.PetBonus(e.Pet)
		sum = sum + d
	end
	return sum
end

-- Множитель продажи от питомцев
function Stats.PetCoinFactor(data)
	local sum = 1
	for _, e in ipairs(Stats.EquippedPets(data)) do
		local _, sb = Stats.PetBonus(e.Pet)
		sum = sum + sb
	end
	return sum
end

function Stats.BoostActive(data, id)
	return data.ActiveBoosts and (data.ActiveBoosts[id] or 0) > 0
end

function Stats.Drill(data)
	return DrillsData.ById[data.Drill] or DrillsData.ById[DrillsData.Starter]
end

function Stats.Backpack(data)
	return BackpacksData.ById[data.Backpack] or BackpacksData.ById[BackpacksData.Starter]
end

-- Урон = урон бура x множитель урона питомцев x бусты
function Stats.Damage(data)
	local dmg = Stats.Drill(data).Damage * Stats.PetSum(data)
	if Stats.BoostActive(data, "DrillOvercharge") then
		dmg = dmg * BoostsData.ById.DrillOvercharge.Mult
	end
	return dmg * Stats.PassDamageMult(data) * Stats.EventMult("Damage")
end

function Stats.PassDamageMult(data)
	local m = 1
	if Stats.HasPass(data, "Damage2x") then
		m = m * FX.Damage2x
	end
	if Stats.HasPass(data, "VIP") then
		m = m * FX.VIPDamage
	end
	return m
end

function Stats.PassCoinMult(data)
	local m = 1
	if Stats.HasPass(data, "Coins2x") then
		m = m * FX.Coins2x
	end
	if Stats.HasPass(data, "VIP") then
		m = m * FX.VIPCoins
	end
	return m
end

-- множитель редких питомцев: Талисман удачи (буст) x2.5, геймпасс «Удача» x2, событие удачи
function Stats.LuckMult(data)
	local m = 1
	if Stats.BoostActive(data, "LuckyCharm") then
		m = m * 2.5
	end
	if Stats.HasPass(data, "Lucky") then
		m = m * FX.LuckyMult
	end
	return m * Stats.EventMult("Luck")
end

function Stats.HitInterval(data)
	local lvl = Stats.PerkLevel(data, "DrillSpeed")
	return Balance.HitInterval / (1 + perkById.DrillSpeed.PerLevel * lvl)
end

function Stats.Capacity(data)
	local lvl = Stats.PerkLevel(data, "Capacity")
	if Stats.HasPass(data, "InfiniteBackpack") then
		return Stats.INFINITE
	end
	local cap = Stats.Backpack(data).Capacity * (1 + perkById.Capacity.PerLevel * lvl)
	if Stats.HasPass(data, "BigBackpack") then
		cap = cap * FX.BigBackpack
	end
	return math.floor(cap)
end

function Stats.RebirthMult(data)
	return 1 + RebirthData.SellBonusPerRebirth * (data.Rebirths or 0)
end

-- Монеты = цена руды x множитель продажи питомцев x ребёрс x буст
function Stats.SellMult(data, sellBiome)
	local biome = BiomesData[sellBiome] or BiomesData[1]
	local m = biome.SellMult * Stats.PetCoinFactor(data) * Stats.RebirthMult(data)
	if Stats.BoostActive(data, "CoinElixir") then
		m = m * BoostsData.ById.CoinElixir.Mult
	end
	return m * Stats.PassCoinMult(data) * Stats.EventMult("Coins")
end

function Stats.PetSlots(data)
	local slots = Balance.BasePetSlots + (data.PetSlotBonus or 0) + Stats.PerkLevel(data, "PetSlot")
	slots = math.min(slots, Balance.MaxPetSlots)
	if Stats.HasPass(data, "PetSlots") then
		slots = slots + FX.PetSlots
	end
	if Stats.HasPass(data, "VIP") then
		slots = slots + FX.VIPSlots
	end
	return math.min(slots, Balance.MaxPetSlotsWithPasses or 8)
end

function Stats.IncubatorSlots(data, hasPass)
	local n = 1
	if (data.Rebirths or 0) >= RebirthData.IncubatorSlotAt then
		n = n + 1
	end
	if hasPass or Stats.HasPass(data, "Incubator") then
		n = n + 1
	end
	return n
end

-- Ауры питомцев из семян
function Stats.Auras(data)
	local speed, splash = 0, 0
	for _, e in ipairs(Stats.EquippedPets(data)) do
		local def = PetsData.ById[e.Pet.Id]
		if def and def.Aura then
			local a = def.Aura
			if a.Kind == "Speed" then
				speed = speed + a.Value
			elseif a.Kind == "Splash" then
				splash = splash + a.Value
			elseif a.Kind == "Both" then
				splash = splash + a.Value
				speed = speed + 0.1
			end
		end
	end
	return speed, math.min(splash, 0.6)
end

function Stats.WalkSpeed(data)
	local lvl = Stats.PerkLevel(data, "WalkSpeed")
	local auraSpeed = Stats.Auras(data)
	local pass = Stats.HasPass(data, "Speed") and FX.Speed or 1
	return Balance.BaseWalkSpeed * (1 + perkById.WalkSpeed.PerLevel * lvl) * (1 + auraSpeed) * pass
end

function Stats.PickupRadius(data)
	local lvl = Stats.PerkLevel(data, "Magnet")
	if lvl <= 0 then
		return Balance.BasePickupRadius
	end
	return perkById.Magnet.Radius[math.min(lvl, #perkById.Magnet.Radius)]
end

function Stats.RebirthCost(data)
	return RebirthData.BaseCoins * math.pow(RebirthData.CoinScale, data.Rebirths or 0)
end

function Stats.RebirthShards(data)
	local shards = RebirthData.BaseShards
	if (data.UnlockedBiome or 1) >= 5 then
		shards = shards + RebirthData.ShardsPerExtraBiome
	end
	return shards
end

function Stats.CanRebirth(data)
	return (data.UnlockedBiome or 1) >= RebirthData.RequiredBiome and (data.Coins or 0) >= Stats.RebirthCost(data)
end

-- Глубина в метрах по номеру биома и координате Y (верх шахты = 0, низ = -100).
function Stats.DepthAt(biomeId, y)
	local biome = BiomesData[biomeId]
	if not biome then
		return 0
	end
	local total = Balance.Layers * Balance.BlockSize
	local t = math.clamp(-y / total, 0, 1)
	return biome.MinDepth + (biome.MaxDepth - biome.MinDepth) * t
end

-- Шлюз в следующий ярус открывается только с топовым буром этого яруса
function Stats.GateDrill(biome)
	return DrillsData.TopOf[biome]
end

function Stats.CanOpenGate(data, biome)
	local top = DrillsData.TopOf[biome]
	return top == nil or (data.OwnedDrills and data.OwnedDrills[top.Id]) == true
end

-- Покупка по порядку: предмет доступен, только если куплены все предыдущие.
-- Возвращает "owned" | "next" | "locked" и предмет, который нужно купить раньше.
function Stats.ShopState(data, kind, item)
	local list = kind == "Drill" and DrillsData.List or BackpacksData.List
	local owned = (kind == "Drill" and data.OwnedDrills or data.OwnedBackpacks) or {}
	if owned[item.Id] then
		return "owned"
	end
	for i = 1, item.Index - 1 do
		if not owned[list[i].Id] then
			return "locked", list[i]
		end
	end
	return "next"
end

-- вместимость инвентаря питомцев
function Stats.PetStorage(data)
	local n = Balance.BasePetStorage + Balance.PetStorageStep * (data.PetStorageLevel or 0)
	if Stats.HasPass(data, "Storage100") then
		n = n + 100
	end
	return math.min(n, Balance.PetStorageMax or 500)
end

-- цена следующих +10 мест (nil — больше докупать нельзя)
function Stats.PetStorageCost(data)
	local lvl = data.PetStorageLevel or 0
	if lvl >= Balance.PetStorageMaxBuys then
		return nil
	end
	return Balance.PetStorageBaseCost * math.pow(Balance.PetStorageCostGrow, lvl)
end

function Stats.PetCount(data)
	local n = 0
	for _ in pairs(data.Pets or {}) do
		n = n + 1
	end
	return n
end

return Stats
