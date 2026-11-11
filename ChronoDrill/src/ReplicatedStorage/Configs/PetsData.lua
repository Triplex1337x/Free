-- PetsData: единый реестр всех питомцев, собирается из EggsData и SeedsData.
local EggsData = require(script.Parent.EggsData)
local SeedsData = require(script.Parent.SeedsData)
local RewardsData = require(script.Parent.RewardsData)

local Rarities = {
	{ Key = "Common", Name = "Обычный", Color = { 190, 196, 206 }, Min = 25 },
	{ Key = "Uncommon", Name = "Необычный", Color = { 96, 214, 104 }, Min = 12 },
	{ Key = "Rare", Name = "Редкий", Color = { 70, 160, 255 }, Min = 5 },
	{ Key = "Epic", Name = "Эпический", Color = { 180, 96, 255 }, Min = 1.5 },
	{ Key = "Legendary", Name = "Легендарный", Color = { 255, 190, 40 }, Min = 0 },
	{ Key = "Mythic", Name = "Мифический", Color = { 255, 70, 120 }, Min = math.huge },
	{ Key = "Secret", Name = "Хроно", Color = { 90, 240, 255 }, Min = -1 },
	{ Key = "Huge", Name = "Огромный", Color = { 255, 96, 220 }, Min = -2 },
}
local RarityIndex = {}
for i, r in ipairs(Rarities) do
	r.Index = i
	RarityIndex[r.Key] = r
end

local function rarityFor(chance, flag)
	if flag == "Mythic" then
		return RarityIndex.Mythic
	end
	if flag == "Huge" then
		return RarityIndex.Huge
	end
	for _, r in ipairs(Rarities) do
		if chance >= r.Min then
			return r
		end
	end
	return Rarities[#Rarities - 1]
end

-- Сила питомца (P): бонус к урону/продаже до улучшений и уровней.
-- Яйцо №e (1..15): самый слабый пет = EggBase * EggGrow^(e-1), самый редкий обычный — в EggSpan раз сильнее,
-- мифик — ещё в MythicMult раз (Balance).
-- Фокус: нечётные по редкости — «урон» (урон 100%, продажа 50%), чётные — «продажа»,
-- самый редкий в яйце — оба бонуса по 100%.
local Balance = require(script.Parent.Balance)
local EGG_BASE, EGG_GROW, EGG_SPAN = Balance.EggBase, Balance.EggGrow, Balance.EggSpan
local function round2(x)
	return math.floor(x * 1000 + 0.5) / 1000
end

local Pets = {}
for e, egg in ipairs(EggsData.List) do
	local n = 0
	for _, entry in ipairs(egg.Pets) do
		if entry[5] ~= "Mythic" and entry[5] ~= "Huge" then
			n = n + 1
		end
	end
	local pmin = EGG_BASE * EGG_GROW ^ ((egg.PowerIndex or e) - 1)
	egg.Index = e
	for order, entry in ipairs(egg.Pets) do
		local id = entry[1]
		local mythic = entry[5] == "Mythic"
		local huge = entry[5] == "Huge"
		local rarity = rarityFor(entry[3], entry[5])
		local p = pmin * EGG_SPAN ^ ((math.min(order, n) - 1) / math.max(1, n - 1))
		if mythic then
			p = pmin * EGG_SPAN * Balance.MythicMult
		elseif huge then
			p = pmin * EGG_SPAN * Balance.MythicMult * (Balance.HugeMult or 1.8)
		end
		local df, sf
		if order >= n then
			df, sf = 1, 1
		elseif order % 2 == 1 then
			df, sf = 1, 0.5
		else
			df, sf = 0.5, 1
		end
		Pets[id] = {
			Id = id,
			Name = entry[2],
			Chance = entry[3],
			P = round2(p),
			DmgF = df,
			SellF = sf,
			Egg = egg.Id,
			Biome = egg.Biome,
			Order = order,
			Rarity = rarity.Key,
		}
	end
end

-- сила самого редкого пета яйца №e
local function EggTopPower(e)
	return EGG_BASE * EGG_GROW ^ (e - 1) * EGG_SPAN
end

for _, seed in ipairs(SeedsData.List) do
	Pets[seed.Pet] = {
		Id = seed.Pet,
		Name = seed.PetName,
		Chance = 0,
		P = round2(EGG_BASE * EGG_GROW ^ (seed.Biome * 3 - 2) * EGG_SPAN * seed.PowerMult),
		DmgF = 1,
		SellF = 1,
		Seed = seed.Id,
		Biome = seed.Biome,
		Order = 99,
		Rarity = "Secret",
		Aura = seed.Aura,
	}
end

for id, sp in pairs(RewardsData.SpecialPets) do
	Pets[id] = {
		Id = id,
		Name = sp.Name,
		Chance = 0,
		P = RewardsData.SpecialMult(id, 1),
		DmgF = sp.DmgF or 1,
		SellF = sp.SellF or 1,
		Special = sp.Source,
		Biome = 1,
		Order = 98,
		Rarity = sp.Rarity or "Secret",
		Aura = sp.Aura,
	}
end

return {
	ById = Pets,
	EggTopPower = EggTopPower,
	Rarities = Rarities,
	Rarity = RarityIndex,
	Get = function(id)
		return Pets[id]
	end,
}
