-- RewardsData: ежедневные награды (7 дней) и колесо удачи (раз в 24 часа).
-- Монеты масштабируются под открытый ярус: 1 "рейс" = первый рюкзак яруса, полный руды.
local BiomesData = require(script.Parent.BiomesData)
local EggsData = require(script.Parent.EggsData)
local BackpacksData = require(script.Parent.BackpacksData)
local Balance = require(script.Parent.Balance)

local Rewards = {}

Rewards.DailyCooldown = 24 * 60 * 60   -- ежедневная награда — раз в 24 часа
Rewards.DailyStreakReset = 48 * 60 * 60 -- если пропустить больше 48 часов, серия начинается заново
Rewards.WheelCooldown = 24 * 60 * 60

-- Эксклюзивные питомцы (в PetsData попадают с редкостью "Хроно")
Rewards.SpecialPets = {
	ChronoKitsune = {
		Name = "Хроно-Кицунэ",
		Source = "Награда за 7-й день",
		RefIndex = 4, RefMult = 1.3, -- сила 4-го пета премиум-яйца открытого яруса x1.3
		Aura = { Kind = "Both", Value = 0.15, Text = "15% урона по соседу и +10% скорости" },
	},
	StarGriffin = {
		Name = "Звёздный Грифон",
		Source = "Все недельные задания",
		RefIndex = 6, RefMult = 1.25,
		Aura = { Kind = "Both", Value = 0.2, Text = "20% урона по соседу и +10% скорости" },
	},
	FortuneCat = {
		Name = "Кот Фортуны",
		Source = "Джекпот колеса удачи",
		RefIndex = 5, RefMult = 1.15, DmgF = 0.5, SellF = 1.5,
		Aura = { Kind = "Speed", Value = 0.08, Text = "+8% к скорости бега" },
	},
}

-- премиум-яйцо яруса
local function premiumEgg(biome)
	for i, egg in ipairs(EggsData.List) do
		if egg.Biome == biome and egg.Slot == 2 then
			return egg, i
		end
	end
	return EggsData.List[2], 2
end

-- сила эксклюзивного пета (P), зависит от открытого яруса на момент получения
function Rewards.SpecialMult(petId, biome)
	local sp = Rewards.SpecialPets[petId]
	local egg, e = premiumEgg(math.clamp(biome or 1, 1, #BiomesData))
	local n = #egg.Pets - 1 -- без мифика
	local idx = math.min(sp.RefIndex, n)
	local p = Balance.EggBase * Balance.EggGrow ^ (e - 1) * Balance.EggSpan ^ ((idx - 1) / math.max(1, n - 1))
	return math.floor(p * sp.RefMult * 1000 + 0.5) / 1000
end

-- «Рейс»: стоимость первого рюкзака яруса, набитого рудой середины шахты
function Rewards.CoinScale(biome)
	local b = BiomesData[math.clamp(biome or 1, 1, #BiomesData)]
	local cap = 180
	for _, p in ipairs(BackpacksData.List) do
		if p.Biome == b.Id then
			cap = p.Capacity
			break
		end
	end
	return math.floor(cap * (b.Ore[1] + b.Ore[2]) / 2 * 1.1 * (b.SellMult or 1))
end

-- Kind: Coins (Amount = сколько "рейсов"), Boost (Id, Amount), Seed (Amount), Pet (Id), Bundle (Items)
Rewards.Daily = {
	{ Kind = "Coins", Amount = 1, Color = { 255, 198, 48 } },
	{ Kind = "Boost", Id = "CoinElixir", Amount = 1, Color = { 255, 196, 46 } },
	{ Kind = "Bundle", Items = { { Kind = "Coins", Amount = 2 }, { Kind = "Boost", Id = "DrillOvercharge", Amount = 1 } }, Color = { 255, 120, 80 } },
	{ Kind = "Boost", Id = "LuckyCharm", Amount = 2, Color = { 90, 220, 110 } },
	{ Kind = "Bundle", Items = { { Kind = "Seed", Amount = 1 }, { Kind = "Boost", Id = "BioFertilizer", Amount = 2 } }, Color = { 170, 110, 255 } },
	{ Kind = "Bundle", Items = { { Kind = "Coins", Amount = 4 }, { Kind = "Boost", Id = "CoinElixir", Amount = 1 }, { Kind = "Boost", Id = "DrillOvercharge", Amount = 1 }, { Kind = "Boost", Id = "LuckyCharm", Amount = 1 } }, Color = { 70, 160, 255 } },
	{ Kind = "Pet", Id = "ChronoKitsune", Color = { 255, 110, 170 } },
}

-- Сегменты колеса (по часовой стрелке от верхней точки)
Rewards.Wheel = {
	{ Kind = "Coins", Amount = 1, Weight = 22, Color = { 255, 198, 48 } },
	{ Kind = "Boost", Id = "CoinElixir", Amount = 1, Weight = 15, Color = { 255, 146, 46 } },
	{ Kind = "Boost", Id = "DrillOvercharge", Amount = 1, Weight = 15, Color = { 255, 86, 86 } },
	{ Kind = "Coins", Amount = 5, Weight = 9, Color = { 255, 230, 120 } },
	{ Kind = "Boost", Id = "LuckyCharm", Amount = 2, Weight = 12, Color = { 88, 214, 96 } },
	{ Kind = "Seed", Amount = 1, Weight = 9, Color = { 50, 210, 196 } },
	{ Kind = "Boost", Id = "BioFertilizer", Amount = 3, Weight = 14, Color = { 164, 96, 255 } },
	{ Kind = "Pet", Id = "FortuneCat", Weight = 4, Color = { 255, 110, 170 } },
}

return Rewards
