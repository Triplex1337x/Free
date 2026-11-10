-- QuestsData: сюжетные квесты Drill-Bot 3000 (ТЗ 7.2 А) и шаблоны динамических (ТЗ 7.2 Б).
-- Stat — ключ счётчика в data.Stats (или "SessionEggs" — счётчик за текущую сессию).
-- Trips — монеты в «рейсах» (1 рейс = полный первый рюкзак открытого яруса), считаются при получении.
local Story = {
	{ Title = "Первые шаги", Text = "Разбей 50 блоков земли", Stat = "Biome1Blocks", Target = 50,
		Reward = { Trips = 1.5, Boosts = { CoinElixir = 1 } } },
	{ Title = "Первое яйцо", Text = "Открой любое яйцо в Зоне 1", Stat = "EggsBiome1", Target = 1,
		Reward = { Trips = 2, Boosts = { DrillOvercharge = 1 } } },
	{ Title = "Бурильщик", Text = "Достигни глубины 250 метров", Stat = "MaxDepth", Target = 250,
		Reward = { Trips = 3, Boosts = { BioFertilizer = 1 } } },
	{ Title = "Звёздный питомец", Text = "Улучши питомца до ★ (5 одинаковых)", Stat = "GoldenCrafted", Target = 1,
		Reward = { Trips = 4, Boosts = { LuckyCharm = 1 } } },
	{ Title = "Археология", Text = "Добудь 300 янтарных блоков", Stat = "AmberBlocks", Target = 300,
		Reward = { Trips = 5, Boosts = { CoinElixir = 2 } } },
	{ Title = "Селекционер", Text = "Посади семя в инкубатор", Stat = "SeedsPlanted", Target = 1,
		Reward = { Boosts = { BioFertilizer = 2, LuckyCharm = 1 } } },
	{ Title = "Вечная мерзлота", Text = "Разбей 1 000 ледяных блоков", Stat = "IceBlocks", Target = 1000,
		Reward = { Trips = 6, Boosts = { DrillOvercharge = 2 } } },
	{ Title = "Открытие глубин", Text = "Открой 10 яиц за сессию", Stat = "SessionEggs", Target = 10,
		Reward = { Boosts = { LuckyCharm = 2, BioFertilizer = 3 } } },
	{ Title = "Ледяной шлюз", Text = "Достигни глубины 4 500 метров", Stat = "MaxDepth", Target = 4500,
		Reward = { Trips = 8, Boosts = { CoinElixir = 3 } } },
	{ Title = "Пекло", Text = "Нанеси 1 000 000 000 суммарного урона", Stat = "TotalDamage", Target = 1000000000,
		Reward = { Trips = 10, Boosts = { DrillOvercharge = 3 } } },
	{ Title = "Реликтовый мастер", Text = "Вырасти семя Магмы или Бездны", Stat = "RareSeedsGrown", Target = 1,
		Reward = { Boosts = { BioFertilizer = 5, LuckyCharm = 3 } } },
	{ Title = "Абсолют", Text = "Достигни дна — 15 000 метров", Stat = "MaxDepth", Target = 15000,
		Reward = { Trips = 20, PetSlot = 1, Boosts = { CoinElixir = 3, DrillOvercharge = 3, LuckyCharm = 3, BioFertilizer = 3 } } },
}

-- Динамические задания: 3 слота, у каждого свой пул типов.
-- Новое задание никогда не повторяет два предыдущих типа в этом слоте.
--   Base   — диапазон цели; PerBiome — прибавка за каждый ярус
--   Hits   — цель = число ударов x текущий урон; Trips — цель = N полных рюкзаков в монетах
--   DepthFrac — цель = глубина внутри текущего яруса (доля от его высоты)
--   Reward — сколько «рейсов» монет (1 рейс = ~40 блоков текущего яруса) + случайный буст
local Dynamic = {
	[1] = { -- ДОБЫЧА
		{ Type = "MineBlocks", Text = "Сломай блоки в ярусе «{b}» ×{n}", Base = { 60, 140 }, PerBiome = 25 },
		{ Type = "MineOre", Text = "Добудь рудные блоки ×{n}", Base = { 14, 32 }, PerBiome = 4 },
		{ Type = "MineVeins", Text = "Разбей Хроно-Жилы ×{n}", Base = { 1, 3 }, PerBiome = 0 },
		{ Type = "Depth", Text = "Спустись на глубину {n} м", DepthFrac = { 0.25, 0.6 } },
		{ Type = "DealDamage", Text = "Нанеси {n} урона", Hits = { 150, 320 } },
		{ Type = "Nuggets", Text = "Собери Хроно-самородки ×{n}", Base = { 3, 7 }, PerBiome = 0 },
	},
	[2] = { -- КОЛЛЕКЦИЯ
		{ Type = "OpenEggs", Text = "Открой яйца ×{n}", Base = { 2, 6 }, PerBiome = 1 },
		{ Type = "UseBoosts", Text = "Используй бусты ×{n}", Base = { 1, 2 }, PerBiome = 0, NeedsBoost = true },
		{ Type = "GrowSeed", Text = "Вырасти питомца из семени ×{n}", Base = { 1, 1 }, PerBiome = 0, NeedsSeed = true },
		{ Type = "EarnCoins", Text = "Заработай {n} монет продажей", Trips = { 2, 4 } },
		{ Type = "SellCount", Text = "Продай руду на Репликаторе ×{n}", Base = { 3, 6 }, PerBiome = 0 },
	},
	[3] = { -- МАСТЕРСТВО
		{ Type = "Crits", Text = "Нанеси критические удары ×{n}", Base = { 12, 30 }, PerBiome = 3 },
		{ Type = "SellFull", Text = "Продай полный рюкзак ×{n}", Base = { 1, 3 }, PerBiome = 0 },
		{ Type = "PlayMinutes", Text = "Проведи в игре {n} мин.", Base = { 5, 12 }, PerBiome = 0 },
		{ Type = "Hits", Text = "Сделай удары буром ×{n}", Base = { 150, 300 }, PerBiome = 20 },
		{ Type = "MineBlocks", Text = "Сломай блоки в ярусе «{b}» ×{n}", Base = { 150, 260 }, PerBiome = 30 },
		{ Type = "OpenEggs", Text = "Открой яйца ×{n}", Base = { 4, 8 }, PerBiome = 1 },
	},
}

-- Недельные задания: каждую неделю (понедельник 03:00 МСК) выбираются 4 разных.
-- В тексте {n} — цель, {b} — ярус. Монеты за недельное считаются в момент получения (по открытому ярусу).
local Weekly = {
	{ Type = "MineBlocks", Text = "Сломай блоки в любой шахте ×{n}", Base = { 1500, 2500 }, AnyBiome = true },
	{ Type = "MineOre", Text = "Добудь рудные блоки ×{n}", Base = { 300, 500 } },
	{ Type = "MineVeins", Text = "Разбей Хроно-Жилы ×{n}", Base = { 25, 40 } },
	{ Type = "OpenEggs", Text = "Открой яйца ×{n}", Base = { 30, 50 } },
	{ Type = "EarnCoins", Text = "Заработай {n} монет продажей", Trips = { 20, 30 } },
	{ Type = "Crits", Text = "Нанеси критические удары ×{n}", Base = { 250, 400 } },
	{ Type = "SellFull", Text = "Продай полный рюкзак ×{n}", Base = { 15, 25 } },
	{ Type = "UseBoosts", Text = "Используй бусты ×{n}", Base = { 6, 10 } },
	{ Type = "PlayMinutes", Text = "Проведи в игре {n} мин.", Base = { 90, 150 } },
	{ Type = "Nuggets", Text = "Собери Хроно-самородки ×{n}", Base = { 60, 100 } },
	{ Type = "DealDamage", Text = "Нанеси {n} урона", Hits = { 5000, 8000 } },
}

local WeeklyBonus = {
	Text = "Выполни все недельные задания",
	Reward = { Pet = "StarGriffin", Boosts = { LuckyCharm = 3, CoinElixir = 2 } },
}

return { Story = Story, Dynamic = Dynamic, Weekly = Weekly, WeeklyBonus = WeeklyBonus }
