-- BackpacksData: рюкзаки. Вместимость — в единицах руды: рюкзак наполняется
-- на столько, сколько урона ты нанёс блокам (блок на 40 HP = 40 руды).
-- Покупать можно только по порядку.
local function c(r, g, b) return { r, g, b } end

local Packs = {
	{ Id = "Canvas", Name = "Холщовая сумка", Biome = 1, Capacity = 180, Price = 0, Look = { Body = c(196, 170, 120), Accent = c(130, 100, 70), Tier = 1 } },
	{ Id = "Basket", Name = "Плетёная корзина", Biome = 1, Capacity = 250, Price = 430, Look = { Body = c(173, 133, 90), Accent = c(110, 78, 53), Tier = 2 } },
	{ Id = "Leather", Name = "Кожаный рюкзак", Biome = 1, Capacity = 360, Price = 1000, Look = { Body = c(150, 96, 60), Accent = c(90, 56, 36), Tier = 3 } },
	{ Id = "Hiker", Name = "Походный рюкзак", Biome = 1, Capacity = 500, Price = 2500, Look = { Body = c(202, 138, 50), Accent = c(75, 58, 53), Tier = 4 } },
	{ Id = "Miner", Name = "Рюкзак шахтёра", Biome = 1, Capacity = 710, Price = 5900, Look = { Body = c(255, 180, 40), Accent = c(60, 60, 70), Tier = 5 } },
	{ Id = "Crate", Name = "Ящик-ранец", Biome = 1, Capacity = 1000, Price = 14000, Look = { Body = c(176, 120, 70), Accent = c(220, 220, 228), Tier = 6 } },

	{ Id = "Bonepack", Name = "Костяной ранец", Biome = 2, Capacity = 1900, Price = 21000, Look = { Body = c(246, 236, 214), Accent = c(150, 110, 80), Tier = 7 } },
	{ Id = "Sandbag", Name = "Песчаный мешок", Biome = 2, Capacity = 2700, Price = 73000, Look = { Body = c(250, 198, 127), Accent = c(130, 85, 50), Tier = 8 } },
	{ Id = "Amberpack", Name = "Янтарная капсула", Biome = 2, Capacity = 3800, Price = 180000, Look = { Body = c(255, 160, 40), Accent = c(110, 60, 20), Glow = true, Tier = 9 } },
	{ Id = "Archeo", Name = "Рюкзак археолога", Biome = 2, Capacity = 5400, Price = 410000, Look = { Body = c(182, 155, 60), Accent = c(165, 130, 85), Glow = true, Tier = 10 } },
	{ Id = "Dig", Name = "Экспедиционный рюкзак", Biome = 2, Capacity = 7700, Price = 970000, Look = { Body = c(110, 150, 80), Accent = c(220, 200, 150), Tier = 11 } },
	{ Id = "Fossilpack", Name = "Палео-контейнер", Biome = 2, Capacity = 11000, Price = 2100000, Look = { Body = c(220, 90, 50), Accent = c(250, 230, 200), Tier = 12 } },

	{ Id = "Frostpack", Name = "Морозный ранец", Biome = 3, Capacity = 20000, Price = 3200000, Look = { Body = c(200, 230, 255), Accent = c(80, 140, 220), Tier = 13 } },
	{ Id = "Snowbag", Name = "Снежный мешок", Biome = 3, Capacity = 29000, Price = 11000000, Look = { Body = c(145, 200, 247), Accent = c(155, 193, 237), Tier = 14 } },
	{ Id = "Cryopack", Name = "Крио-капсула", Biome = 3, Capacity = 41000, Price = 27000000, Look = { Body = c(90, 170, 240), Accent = c(230, 246, 255), Glow = true, Tier = 15 } },
	{ Id = "Thermo", Name = "Термо-ранец", Biome = 3, Capacity = 59000, Price = 63000000, Look = { Body = c(65, 120, 190), Accent = c(170, 243, 255), Glow = true, Tier = 16 } },
	{ Id = "Glacierpack", Name = "Ледниковый контейнер", Biome = 3, Capacity = 84000, Price = 14e7, Look = { Body = c(40, 70, 140), Accent = c(110, 240, 255), Glow = true, Tier = 17 } },
	{ Id = "Polar", Name = "Полярный модуль", Biome = 3, Capacity = 120000, Price = 35e7, Look = { Body = c(240, 250, 255), Accent = c(60, 120, 230), Glow = true, Tier = 18 } },

	{ Id = "Ashpack", Name = "Пепельный ранец", Biome = 4, Capacity = 210000, Price = 49e7, Look = { Body = c(80, 72, 80), Accent = c(255, 110, 40), Glow = true, Tier = 19 } },
	{ Id = "Coalbox", Name = "Угольный ящик", Biome = 4, Capacity = 300000, Price = 16e8, Look = { Body = c(140, 61, 55), Accent = c(255, 145, 50), Glow = true, Tier = 20 } },
	{ Id = "Lavapack", Name = "Лавовый бак", Biome = 4, Capacity = 420000, Price = 39e8, Look = { Body = c(200, 50, 30), Accent = c(255, 180, 60), Glow = true, Tier = 21 } },
	{ Id = "Magmacap", Name = "Магма-капсула", Biome = 4, Capacity = 600000, Price = 92e8, Look = { Body = c(120, 37, 43), Accent = c(217, 135, 157), Glow = true, Tier = 22 } },
	{ Id = "Obsidpack", Name = "Обсидиановый сейф", Biome = 4, Capacity = 850000, Price = 22e9, Look = { Body = c(40, 24, 56), Accent = c(180, 90, 255), Glow = true, Tier = 23 } },
	{ Id = "Corepack", Name = "Ядро-хранилище", Biome = 4, Capacity = 1200000, Price = 47e9, Look = { Body = c(255, 170, 40), Accent = c(60, 20, 20), Glow = true, Tier = 24 } },

	{ Id = "Voidpack", Name = "Пустотный карман", Biome = 5, Capacity = 2200000, Price = 74e9, Look = { Body = c(60, 40, 120), Accent = c(110, 240, 255), Glow = true, Tier = 25 } },
	{ Id = "Starbag", Name = "Звёздный мешок", Biome = 5, Capacity = 3100000, Price = 25e10, Look = { Body = c(140, 55, 160), Accent = c(70, 130, 152), Glow = true, Tier = 26 } },
	{ Id = "Riftpack", Name = "Карман Разлома", Biome = 5, Capacity = 4500000, Price = 61e10, Look = { Body = c(220, 70, 200), Accent = c(30, 20, 50), Glow = true, Tier = 27 } },
	{ Id = "Chronosafe", Name = "Хроно-сейф", Biome = 5, Capacity = 6400000, Price = 15e11, Look = { Body = c(225, 155, 227), Accent = c(60, 70, 152), Glow = true, Tier = 28 } },
	{ Id = "Tesseract", Name = "Тессеракт", Biome = 5, Capacity = 9100000, Price = 32e11, Look = { Body = c(230, 240, 255), Accent = c(90, 120, 255), Glow = true, Tier = 29 } },
	{ Id = "Singularity", Name = "Карманная сингулярность", Biome = 5, Capacity = 13000000, Price = 69e11, Look = { Body = c(20, 16, 40), Accent = c(255, 214, 90), Glow = true, Tier = 30 } },
}

local byId = {}
for i, p in ipairs(Packs) do
	p.Index = i
	byId[p.Id] = p
end

return { List = Packs, ById = byId, Starter = "Canvas" }
