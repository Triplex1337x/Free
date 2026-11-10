-- EggsData: 10 яиц и шансы питомцев.
-- Pets = { {Id, Русское имя, шанс %, (не используется), "Mythic" — мифик}, ... }
-- В каждом ярусе 3 яйца, в каждом яйце есть очень редкий мифик (0.03–0.1%).
-- Сила питомца считается в PetsData: зависит от номера яйца и редкости.
local function rgb(r, g, b) return { r, g, b } end

local Eggs = {
	{
		Id = "Dirt", Name = "Земляное яйцо", Biome = 1, Price = 700, Slot = 1,
		Look = { Base = rgb(150, 104, 66), Accent = rgb(110, 196, 84), Band = rgb(96, 66, 44), Pattern = "spots" },
		Pets = {
			{ "Worm", "Червяк", 44.9, 1.1 },
			{ "Mouse", "Мышь", 30.0, 1.2 },
			{ "Mole", "Крот", 15.0, 1.4 },
			{ "Hedgehog", "Ёж", 8.0, 1.8 },
			{ "Armadillo", "Броненосец", 2.0, 2.5 },
			{ "CelestialUnicorn", "Небесный Единорог", 0.1, 0, "Mythic" },
		},
	},
	{
		Id = "Stone", Name = "Каменное яйцо", Biome = 1, Price = 8000, Slot = 2,
		Look = { Base = rgb(150, 154, 166), Accent = rgb(96, 100, 114), Band = rgb(255, 196, 60), Pattern = "cracks" },
		Pets = {
			{ "Scarab", "Земляной жук", 37.92, 1.6 },
			{ "StoneCrab", "Каменный краб", 30.0, 2.0 },
			{ "CaveBat", "Летучая мышь", 18.0, 2.6 },
			{ "Badger", "Барсук", 9.0, 3.4 },
			{ "IronPup", "Железный щенок", 4.0, 4.5 },
			{ "MicroGolem", "Микро-Голем", 1.0, 6.5 },
			{ "ObsidianWyvern", "Обсидиановый Виверн", 0.08, 0, "Mythic" },
		},
	},
	{
		Id = "Fluffy", Name = "Пушистое яйцо", Biome = 1, Price = 40000, Slot = 3,
		Look = { Base = rgb(255, 236, 244), Accent = rgb(255, 150, 190), Band = rgb(255, 200, 90), Pattern = "spots" },
		Pets = {
			{ "Bunny", "Зайка", 34.0, 0 },
			{ "Kitty", "Котёнок", 27.0, 0 },
			{ "Puppy", "Щенок", 20.0, 0 },
			{ "RedPanda", "Красная панда", 11.0, 0 },
			{ "Fox", "Лисёнок", 6.0, 0 },
			{ "Panda", "Панда", 1.9, 0 },
			{ "DemonCat", "Кот-Демон", 0.1, 0, "Mythic" },
		},
	},
	{
		Id = "Fossil", Name = "Окаменелое яйцо", Biome = 2, Price = 200000, Slot = 1,
		Look = { Base = rgb(232, 210, 168), Accent = rgb(176, 140, 96), Band = rgb(246, 238, 216), Pattern = "bones" },
		Pets = {
			{ "Anomalo", "Аномалокарис", 39.92, 6.0 },
			{ "Trilobite", "Трилобит", 28.0, 7.5 },
			{ "BabyRaptor", "Раптор", 18.0, 9.5 },
			{ "Ptero", "Птеродактиль", 10.0, 13.0 },
			{ "Stego", "Стегозавр", 3.5, 18.0 },
			{ "SaberPup", "Саблезубик", 0.5, 28.0 },
			{ "AncientPhoenix", "Древний Феникс", 0.08, 0, "Mythic" },
		},
	},
	{
		Id = "Amber", Name = "Янтарное яйцо", Biome = 2, Price = 2500000, Slot = 2,
		Look = { Base = rgb(255, 160, 36), Accent = rgb(255, 214, 120), Band = rgb(140, 70, 20), Pattern = "glass" },
		Pets = {
			{ "AmberFly", "Янтарная муха", 34.94, 15.0 },
			{ "Monitor", "Варан", 27.0, 20.0 },
			{ "Mammoth", "Мамонтёнок", 19.0, 28.0 },
			{ "Ankylo", "Анкилозавр", 12.0, 40.0 },
			{ "Brachio", "Брахиозавр", 5.0, 60.0 },
			{ "Rex", "Тираннозавр", 1.8, 95.0 },
			{ "PrimeDrake", "Дракон недр", 0.2, 160.0 },
			{ "AmberSeraph", "Янтарный Серафим", 0.06, 0, "Mythic" },
		},
	},
	{
		Id = "Safari", Name = "Яйцо саванны", Biome = 2, Price = 12000000, Slot = 3,
		Look = { Base = rgb(236, 196, 110), Accent = rgb(120, 170, 70), Band = rgb(150, 96, 50), Pattern = "spots" },
		Pets = {
			{ "LionCub", "Львёнок", 33.04, 0 },
			{ "Zebra", "Зебра", 26.0, 0 },
			{ "Hippo", "Бегемотик", 19.0, 0 },
			{ "Giraffe", "Жирафик", 12.0, 0 },
			{ "Rhino", "Носорог", 7.0, 0 },
			{ "Elephant", "Слонёнок", 2.9, 0 },
			{ "SunLion", "Король Солнца", 0.06, 0, "Mythic" },
		},
	},
	{
		Id = "Snow", Name = "Снежное яйцо", Biome = 3, Price = 25000000, Slot = 1,
		Look = { Base = rgb(246, 250, 255), Accent = rgb(140, 200, 255), Band = rgb(90, 160, 240), Pattern = "spots" },
		Pets = {
			{ "FrostPenguin", "Пингвин", 35.94, 80.0 },
			{ "SnowHare", "Снежный заяц", 28.0, 110.0 },
			{ "IceWolf", "Полярный волк", 18.0, 150.0 },
			{ "Walrus", "Морж-бурильщик", 11.0, 210.0 },
			{ "BlizzardOwl", "Сова бури", 5.5, 300.0 },
			{ "FrostStag", "Ледяной олень", 1.5, 450.0 },
			{ "FrostGriffin", "Ледяной Грифон", 0.06, 0, "Mythic" },
		},
	},
	{
		Id = "Glacier", Name = "Морозное яйцо", Biome = 3, Price = 300000000, Slot = 2,
		Look = { Base = rgb(130, 214, 255), Accent = rgb(230, 248, 255), Band = rgb(60, 120, 220), Pattern = "glass" },
		Pets = {
			{ "CryoFox", "Крио-лис", 31.95, 220.0 },
			{ "FrostWisp", "Висп льда", 25.0, 310.0 },
			{ "CaveYeti", "Пещерный йети", 18.0, 440.0 },
			{ "Narwhal", "Кристальный нарвал", 14.0, 620.0 },
			{ "SapphireBear", "Сапфир-медведь", 7.0, 900.0 },
			{ "FrostLeviathan", "Левиафан", 3.2, 1400.0 },
			{ "StormMonarch", "Монарх", 0.8, 2200.0 },
			{ "BlizzardLord", "Повелитель Метелей", 0.05, 0, "Mythic" },
		},
	},
	{
		Id = "Aurora", Name = "Яйцо Северного сияния", Biome = 3, Price = 1200000000, Slot = 3,
		Look = { Base = rgb(40, 60, 120), Accent = rgb(90, 255, 200), Band = rgb(200, 120, 255), Pattern = "stars", Neon = true },
		Pets = {
			{ "ArcticFox", "Песец", 33.05, 0 },
			{ "SnowOwl", "Полярная сова", 26.0, 0 },
			{ "Seal", "Тюлень", 19.0, 0 },
			{ "Reindeer", "Северный олень", 12.0, 0 },
			{ "PolarBear", "Белый медведь", 7.0, 0 },
			{ "AuroraWolf", "Волк сияния", 2.9, 0 },
			{ "AuroraStag", "Олень Авроры", 0.05, 0, "Mythic" },
		},
	},
	{
		Id = "Cinder", Name = "Яйцо углей", Biome = 4, Price = 3e9, Slot = 1,
		Look = { Base = rgb(60, 52, 58), Accent = rgb(255, 110, 30), Band = rgb(255, 150, 40), Pattern = "cracks", Neon = true },
		Pets = {
			{ "LavaSalamander", "Саламандра", 34.95, 1200.0 },
			{ "MagmaSlime", "Магма-слизень", 27.0, 1600.0 },
			{ "BasaltCrab", "Базальт-краб", 19.0, 2200.0 },
			{ "ObsidianHound", "Обсидиан-пёс", 12.0, 3200.0 },
			{ "HellBat", "Адская мышь", 5.5, 4800.0 },
			{ "LavaRay", "Лавовый скат", 1.5, 7500.0 },
			{ "HellHound", "Адская Гончая", 0.05, 0, "Mythic" },
		},
	},
	{
		Id = "Inferno", Name = "Яйцо Инферно", Biome = 4, Price = 3.5e10, Slot = 2,
		Look = { Base = rgb(230, 60, 30), Accent = rgb(255, 200, 60), Band = rgb(90, 20, 20), Pattern = "flames", Neon = true },
		Pets = {
			{ "MiniEfreet", "Ифрит", 29.96, 3500.0 },
			{ "SulfurScorpion", "Скорпион", 24.0, 5000.0 },
			{ "InfernoTiger", "Огненный тигр", 18.0, 7200.0 },
			{ "MoltenColossus", "Колосс", 14.0, 10500.0 },
			{ "SolarPhoenix", "Феникс", 8.0, 16000.0 },
			{ "NetherWyrm", "Змей недр", 4.5, 25000.0 },
			{ "CoreElemental", "Элементаль", 1.3, 42000.0 },
			{ "MagmaDeity", "Божество магмы", 0.2, 75000.0 },
			{ "SolarDemon", "Солнечный Демон", 0.04, 0, "Mythic" },
		},
	},
	{
		Id = "Dragon", Name = "Драконье яйцо", Biome = 4, Price = 1.5e11, Slot = 3,
		Look = { Base = rgb(150, 30, 40), Accent = rgb(255, 180, 40), Band = rgb(40, 20, 30), Pattern = "flames", Neon = true },
		Pets = {
			{ "EmberPup", "Угольный щенок", 32.06, 0 },
			{ "DrakeHatchling", "Дракончик", 25.0, 0 },
			{ "LavaTurtle", "Лавовая черепаха", 19.0, 0 },
			{ "FireFox", "Огненный лис", 13.0, 0 },
			{ "MagmaDragon", "Магма-дракон", 8.0, 0 },
			{ "ChaosDragon", "Дракон Хаоса", 2.9, 0 },
			{ "DragonEmperor", "Император Драконов", 0.04, 0, "Mythic" },
		},
	},
	{
		Id = "Singularity", Name = "Яйцо Сингулярности", Biome = 5, Price = 4e11, Slot = 1,
		Look = { Base = rgb(70, 40, 140), Accent = rgb(110, 240, 255), Band = rgb(180, 110, 255), Pattern = "stars", Neon = true },
		Pets = {
			{ "VoidWisp", "Дух пустоты", 32.96, 35000.0 },
			{ "RiftBug", "Жук разлома", 25.0, 52000.0 },
			{ "EtherRay", "Эфирный скат", 18.0, 78000.0 },
			{ "ChronoHound", "Хроно-гончая", 13.0, 115000.0 },
			{ "AbyssPhantom", "Призрак", 7.0, 180000.0 },
			{ "QuantumTitan", "Квант-титан", 3.3, 290000.0 },
			{ "VoidEye", "Око Бездны", 0.7, 480000.0 },
			{ "StarDevourer", "Пожиратель Звёзд", 0.04, 0, "Mythic" },
		},
	},
	{
		Id = "Apocalypse", Name = "Яйцо Конца Времён", Biome = 5, Price = 5e12, Slot = 2,
		Look = { Base = rgb(24, 20, 40), Accent = rgb(255, 210, 90), Band = rgb(255, 190, 60), Pattern = "stars", Neon = true },
		Pets = {
			{ "StarShardling", "Осколок", 29.97, 120000.0 },
			{ "GravitonWorm", "Червь гравити", 22.0, 185000.0 },
			{ "NebulaFox", "Небула-лис", 17.0, 280000.0 },
			{ "ChronosSentinel", "Страж", 14.0, 420000.0 },
			{ "SupernovaBehemoth", "Бегемот", 9.0, 650000.0 },
			{ "CosmicOuroboros", "Уроборос", 5.0, 1050000.0 },
			{ "VoidArbiter", "Арбитр", 2.4, 1800000.0 },
			{ "EventHorizonDrake", "Дрейк горизонта", 0.5, 3200000.0 },
			{ "PrimordialChronos", "Хронос", 0.1, 6000000.0 },
			{ "TimeLord", "Владыка Времени", 0.03, 0, "Mythic" },
		},
	},
	{
		Id = "Cosmos", Name = "Космическое яйцо", Biome = 5, Price = 2e13, Slot = 3,
		Look = { Base = rgb(30, 20, 70), Accent = rgb(255, 120, 220), Band = rgb(110, 240, 255), Pattern = "stars", Neon = true },
		Pets = {
			{ "StarBunny", "Звёздный зайка", 32.07, 0 },
			{ "CometCat", "Кот-комета", 25.0, 0 },
			{ "NebulaPup", "Небула-щенок", 19.0, 0 },
			{ "GalaxyOwl", "Галакти-сова", 13.0, 0 },
			{ "MoonDragon", "Лунный дракон", 8.0, 0 },
			{ "CosmicFox", "Космо-лис", 2.9, 0 },
			{ "CosmicAngel", "Космический Ангел", 0.03, 0, "Mythic" },
		},
	},
}

local byId = {}
for _, egg in ipairs(Eggs) do
	byId[egg.Id] = egg
end

return {
	List = Eggs,
	ById = byId,
}
