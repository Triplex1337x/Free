-- SeedsData: Хроно-Семена (ТЗ 5). Chance = шанс за сломанный блок.
-- Питомец из семени: сила = PowerMult x самый редкий пет премиум-яйца яруса
-- (плюс случайно 0..+20%), даёт оба бонуса и уникальную ауру.
-- Янтарная почка для 2-го биома — добавлена, чтобы в каждом ярусе было своё семя.
local function rgb(r, g, b) return { r, g, b } end

local Seeds = {
	{
		Id = "Sprout", Name = "Земляной росток", Biome = 1, Chance = 0.001, Duration = 5 * 60,
		Pet = "SproutSprite", PetName = "Ростик", PowerMult = 0.9,
		Aura = { Kind = "Speed", Value = 0.10, Text = "+10% к скорости бега" },
		Color = rgb(110, 210, 80),
	},
	{
		Id = "AmberBud", Name = "Янтарная почка", Biome = 2, Chance = 0.0008, Duration = 10 * 60,
		Pet = "AmberTreant", PetName = "Янтарный энт", PowerMult = 0.9,
		Aura = { Kind = "Splash", Value = 0.2, Text = "20% урона по соседнему блоку" },
		Color = rgb(255, 160, 40),
	},
	{
		Id = "CryoSeed", Name = "Крио-кокон", Biome = 3, Chance = 0.0005, Duration = 20 * 60,
		Pet = "GlacierMoth", PetName = "Ледяной мотылёк", PowerMult = 0.95,
		Aura = { Kind = "Speed", Value = 0.15, Text = "+15% к скорости бега" },
		Color = rgb(140, 220, 255),
	},
	{
		Id = "MagmaSpore", Name = "Лавовое ядро", Biome = 4, Chance = 0.0002, Duration = 60 * 60,
		Pet = "MagmaHydra", PetName = "Магма-гидра", PowerMult = 1,
		Aura = { Kind = "Splash", Value = 0.3, Text = "30% урона по соседнему блоку" },
		Color = rgb(255, 100, 30),
	},
	{
		Id = "VoidCore", Name = "Ядро Сингулярности", Biome = 5, Chance = 0.00005, Duration = 4 * 60 * 60,
		Pet = "ChronoSeraph", PetName = "Хроно-серафим", PowerMult = 1.1,
		Aura = { Kind = "Both", Value = 0.35, Text = "35% урона по соседу и +10% скорости" },
		Color = rgb(150, 110, 255),
	},
}

local byId, byBiome, byPet = {}, {}, {}
for _, s in ipairs(Seeds) do
	byId[s.Id] = s
	byBiome[s.Biome] = s
	byPet[s.Pet] = s
end

return { List = Seeds, ById = byId, ByBiome = byBiome, ByPet = byPet }
