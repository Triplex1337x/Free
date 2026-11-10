-- Balance: все общие числа геймплея в одном месте.
-- Меняйте значения здесь — остальной код их подхватит.
return {
	-- Сетка шахты (ТЗ 1.1)
	GridSize = 40,          -- 40 x 40 блоков на слой
	Layers = 32,            -- глубина шахты в блоках (128 studs)
	BlockSize = 4,          -- 4 x 4 x 4 studs
	WallThickness = 8,      -- неразрушимая стена
	BiomeSpacing = 2400,    -- расстояние между ярусами по оси X (острова не видно друг с друга)

	-- Бурение (ТЗ 2)
	HitInterval = 0.25,     -- 4 удара в секунду на стартовой скорости
	MineReach = 18,         -- максимальная дистанция от персонажа до блока
	CritChance = 0.05,
	CritMult = 3,
	AntiStealTime = 1.5,    -- тег владельца блока (ТЗ 1.3)

	-- Хроно-Жилы (ТЗ 2.3)
	VeinChance = 0.02,
	VeinHpMult = 2,
	VeinCoinMult = 4,
	VeinSeedMult = 3,       -- "повышенный шанс" семян из жил

	-- Хроно-самородки: бонус, который подбирает магнит (ТЗ 8.4)
	NuggetChance = 0.10,
	NuggetValueMult = 1.5,  -- доля стоимости блока
	NuggetLifetime = 25,
	BasePickupRadius = 5,

	-- Вайп (ТЗ 6)
	ResetInterval = 1200,
	ResetWarn1 = 30,
	ResetWarn2 = 10,
	GoldRushDuration = 180,
	GoldRushMult = 2,
	ResetBatchSize = 1000,

	-- Питомцы (ТЗ 4)
	BasePetSlots = 3,
	MaxPetSlots = 5,
	-- Инвентарь питомцев: базовые места + докупка за монеты (+10 мест за раз) + геймпасс +100
	BasePetStorage = 50,
	PetStorageStep = 10,
	PetStorageMaxBuys = 35, -- до 400 мест за монеты (+100 геймпассом = максимум 500)
	PetStorageBaseCost = 2500,
	PetStorageCostGrow = 2.3,
	PetStorageMax = 500,
	-- Сила питомцев по яйцам: самый слабый пет яйца №e = EggBase * EggGrow^(e-1),
	-- самый редкий обычный — в EggSpan раз сильнее, мифик — ещё в MythicMult раз.
	EggBase = 0.05,
	EggGrow = 1.23,
	EggSpan = 6,
	MythicMult = 2.2,
	HugeMult = 1.8, -- «Огромный» питомец сильнее мифика своего яйца в 1.8 раза
	LuckyRareThreshold = 5, -- Lucky Charm усиливает петов с шансом <= 5%
	-- Питомец даёт два бонуса: к урону и к продаже. Бонусы экипированных складываются:
	-- три пета по x1.20 = x1.60 (а не x3.6, как раньше).
	-- Улучшения (крафт одинаковых): Cost — сколько питомцев этого уровня нужно.
	PetTiers = {
		{ Name = "", Short = "", Mult = 1 },
		{ Name = "★", Short = "★", Mult = 1.5, Cost = 5 },
		{ Name = "★★", Short = "★★", Mult = 2.2, Cost = 4 },
		{ Name = "★★★", Short = "★★★", Mult = 3.2, Cost = 4 },
		{ Name = "Золотой", Short = "ЗОЛ", Mult = 5, Cost = 3 },
		{ Name = "Радужный", Short = "РАД", Mult = 8, Cost = 3 },
		-- шайни: только выпадает из яйца (крафтом не получить), чуть сильнее золотого
		{ Name = "Шайни", Short = "ШАЙНИ", Mult = 5.6, NoCraft = true },
	},
	ShinyChance = 0.004, -- 1 из 250 питомцев из яйца — шайни (удача увеличивает, максимум x4)
	-- Уровни: опыт копится у экипированных питомцев за каждый сломанный блок.
	PetMaxLevel = 30,
	PetLevelBonus = 0.04,   -- +4% к силе за уровень (30 ур. = x2.16)
	PetXpBase = 15,         -- опыт до следующего уровня = Base * L^Exp
	PetXpExp = 1.7,
	PetXpPerBlock = 1,      -- за блок (+25% за каждый следующий ярус)

	-- Логистика
	TeleportCastTime = 0,   -- телепорт на базу мгновенный
	BaseWalkSpeed = 18,

	-- Квесты
	DynamicQuestCooldown = 60,

	-- Сохранение
	AutoSaveInterval = 120,
	DataStoreName = "ChronoDrill_PlayerData_v2", -- v2: новая экономика 1.4, старые сейвы не подходят

	-- Геймпасс на 3-й слот инкубатора (ТЗ 5.2). 0 = не настроен.
	IncubatorGamepassId = 0,

	-- Графика: гладкий мир из деталей (true) вместо текстурного ландшафта Terrain (false)
	SmoothWorld = true,
	MaxPetSlotsWithPasses = 8, -- потолок слотов питомцев с геймпассами
}
