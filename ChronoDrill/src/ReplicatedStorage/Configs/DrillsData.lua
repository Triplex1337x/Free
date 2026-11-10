-- DrillsData: буры. Последний бур каждого яруса — "топовый бур зоны": без него шлюз в следующий ярус не откроется.
-- Покупать можно только по порядку: следующий бур доступен, когда куплены все предыдущие.
-- Look: Body/Accent/Bit — цвета модели, Glow — неоновая подсветка (опционально), Tier — сложность модели.
local function c(r, g, b) return { r, g, b } end

local Drills = {
	{ Id = "Wooden", Name = "Деревянный бур", Biome = 1, Damage = 3, Price = 0, Look = { Body = c(176, 122, 74), Accent = c(122, 84, 52), Bit = c(170, 170, 178), Tier = 1 } },
	{ Id = "StoneD", Name = "Каменный бур", Biome = 1, Damage = 4.3, Price = 620, Look = { Body = c(195, 125, 76), Accent = c(121, 78, 48), Bit = c(183, 183, 191), Tier = 2 } },
	{ Id = "Copper", Name = "Медный бур", Biome = 1, Damage = 6.3, Price = 1500, Look = { Body = c(214, 128, 78), Accent = c(120, 72, 44), Bit = c(196, 196, 204), Tier = 3 } },
	{ Id = "Steel", Name = "Стальной бур", Biome = 1, Damage = 9.1, Price = 3700, Look = { Body = c(182, 142, 124), Accent = c(90, 68, 60), Bit = c(208, 209, 217), Tier = 4 } },
	{ Id = "Iron", Name = "Железный бур", Biome = 1, Damage = 13.1, Price = 8700, Look = { Body = c(150, 156, 170), Accent = c(60, 64, 76), Bit = c(220, 222, 230), Tier = 5 } },
	{ Id = "Quarry", Name = "Карьерный бур", Biome = 1, Damage = 19, Price = 20000, Look = { Body = c(255, 196, 46), Accent = c(40, 40, 48), Bit = c(220, 224, 232), Tier = 6 } },

	{ Id = "Bone", Name = "Костяной бур", Biome = 2, Damage = 35, Price = 36000, Look = { Body = c(246, 236, 214), Accent = c(150, 120, 90), Bit = c(230, 220, 196), Tier = 7 } },
	{ Id = "Fang", Name = "Бур-клык", Biome = 2, Damage = 51, Price = 110000, Look = { Body = c(250, 198, 127), Accent = c(130, 90, 55), Bit = c(242, 220, 168), Tier = 8 } },
	{ Id = "AmberD", Name = "Янтарный бур", Biome = 2, Damage = 73, Price = 260000, Look = { Body = c(255, 160, 40), Accent = c(110, 60, 20), Bit = c(255, 220, 140), Glow = c(255, 170, 60), Tier = 9 } },
	{ Id = "Raptor", Name = "Ящеро-бур", Biome = 2, Damage = 110, Price = 610000, Look = { Body = c(182, 165, 65), Accent = c(80, 60, 30), Bit = c(242, 225, 180), Glow = c(255, 170, 60), Tier = 10 } },
	{ Id = "Ripper", Name = "Палео-потрошитель", Biome = 2, Damage = 150, Price = 1500000, Look = { Body = c(110, 170, 90), Accent = c(50, 60, 40), Bit = c(230, 230, 220), Tier = 11 } },
	{ Id = "Paleo", Name = "Палео-бур", Biome = 2, Damage = 220, Price = 3200000, Look = { Body = c(220, 90, 50), Accent = c(250, 230, 200), Bit = c(255, 210, 120), Glow = c(255, 140, 40), Tier = 12 } },

	{ Id = "Frost", Name = "Морозный бур", Biome = 3, Damage = 410, Price = 5800000, Look = { Body = c(200, 230, 255), Accent = c(80, 140, 220), Bit = c(170, 230, 255), Tier = 13 } },
	{ Id = "Snowy", Name = "Снежный бур", Biome = 3, Damage = 590, Price = 17000000, Look = { Body = c(145, 200, 247), Accent = c(155, 193, 237), Bit = c(160, 230, 255), Tier = 14 } },
	{ Id = "GlacierD", Name = "Ледниковый бур", Biome = 3, Damage = 860, Price = 41000000, Look = { Body = c(90, 170, 240), Accent = c(230, 246, 255), Bit = c(150, 230, 255), Glow = c(120, 230, 255), Tier = 15 } },
	{ Id = "Blizzard", Name = "Бур Вьюги", Biome = 3, Damage = 1200, Price = 10e7, Look = { Body = c(65, 120, 190), Accent = c(170, 243, 255), Bit = c(175, 237, 255), Glow = c(115, 235, 255), Tier = 16 } },
	{ Id = "Cryo", Name = "Крио-бур", Biome = 3, Damage = 1800, Price = 23e7, Look = { Body = c(40, 70, 140), Accent = c(110, 240, 255), Bit = c(200, 245, 255), Glow = c(110, 240, 255), Tier = 17 } },
	{ Id = "Icebreaker", Name = "Ледокол", Biome = 3, Damage = 2600, Price = 54e7, Look = { Body = c(240, 250, 255), Accent = c(60, 120, 230), Bit = c(120, 220, 255), Glow = c(160, 240, 255), Tier = 18 } },

	{ Id = "Basalt", Name = "Базальтовый бур", Biome = 4, Damage = 4800, Price = 92e7, Look = { Body = c(70, 64, 72), Accent = c(255, 110, 40), Bit = c(120, 110, 120), Glow = c(255, 110, 40), Tier = 19 } },
	{ Id = "Ash", Name = "Пепельный бур", Biome = 4, Damage = 7000, Price = 26e8, Look = { Body = c(135, 57, 51), Accent = c(147, 70, 35), Bit = c(187, 140, 90), Glow = c(255, 125, 35), Tier = 20 } },
	{ Id = "MagmaD", Name = "Магма-бур", Biome = 4, Damage = 10000, Price = 65e8, Look = { Body = c(200, 50, 30), Accent = c(40, 30, 30), Bit = c(255, 170, 60), Glow = c(255, 140, 30), Tier = 21 } },
	{ Id = "Lava", Name = "Лавовый бур", Biome = 4, Damage = 15000, Price = 15e9, Look = { Body = c(120, 37, 43), Accent = c(110, 60, 142), Bit = c(172, 115, 90), Glow = c(227, 125, 142), Tier = 22 } },
	{ Id = "Obsidian", Name = "Обсидиановый бур", Biome = 4, Damage = 21000, Price = 36e9, Look = { Body = c(40, 24, 56), Accent = c(180, 90, 255), Bit = c(90, 60, 120), Glow = c(200, 110, 255), Tier = 23 } },
	{ Id = "Volcano", Name = "Сердце вулкана", Biome = 4, Damage = 31000, Price = 77e9, Look = { Body = c(255, 170, 40), Accent = c(60, 20, 20), Bit = c(255, 90, 30), Glow = c(255, 120, 20), Tier = 24 } },

	{ Id = "VoidD", Name = "Пустотный бур", Biome = 5, Damage = 56000, Price = 16e10, Look = { Body = c(60, 40, 120), Accent = c(110, 240, 255), Bit = c(170, 120, 255), Glow = c(110, 240, 255), Tier = 25 } },
	{ Id = "StarD", Name = "Звёздный бур", Biome = 5, Damage = 81000, Price = 43e10, Look = { Body = c(140, 55, 160), Accent = c(70, 130, 152), Bit = c(212, 150, 252), Glow = c(182, 165, 237), Tier = 26 } },
	{ Id = "Rift", Name = "Бур Разлома", Biome = 5, Damage = 120000, Price = 11e11, Look = { Body = c(220, 70, 200), Accent = c(30, 20, 50), Bit = c(255, 180, 250), Glow = c(255, 90, 220), Tier = 27 } },
	{ Id = "Horizon", Name = "Бур Горизонта", Biome = 5, Damage = 170000, Price = 25e11, Look = { Body = c(225, 155, 227), Accent = c(60, 70, 152), Bit = c(172, 210, 252), Glow = c(172, 165, 237), Tier = 28 } },
	{ Id = "Quantum", Name = "Квантовый бур", Biome = 5, Damage = 250000, Price = 54e11, Look = { Body = c(230, 240, 255), Accent = c(90, 120, 255), Bit = c(90, 240, 255), Glow = c(90, 240, 255), Tier = 29 } },
	{ Id = "ChronoBreaker", Name = "Хроно-Разрушитель", Biome = 5, Damage = 360000, Price = 12e12, Look = { Body = c(255, 214, 90), Accent = c(40, 30, 80), Bit = c(120, 255, 240), Glow = c(120, 255, 240), Tier = 30 } },
}

local byId = {}
for i, d in ipairs(Drills) do
	d.Index = i
	byId[d.Id] = d
end

local topOf = {}
for _, d in ipairs(Drills) do
	topOf[d.Biome] = d
end

return { List = Drills, ById = byId, Starter = "Wooden", TopOf = topOf }
