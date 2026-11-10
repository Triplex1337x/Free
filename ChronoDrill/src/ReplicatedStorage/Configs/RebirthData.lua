-- RebirthData: перерождения и Хроно-Древо (ТЗ 8).
return {
	RequiredBiome = 4,              -- нужно открыть Магму (4 500 м)
	BaseCoins = 2e10,               -- 20 млрд для 1-го ребёрса
	CoinScale = 3,                  -- каждый следующий ребёрс дороже в 3 раза
	SellBonusPerRebirth = 0.25,     -- +25% к продаже за каждый ребёрс (аддитивно)
	BaseShards = 2,                 -- осколков за ребёрс
	ShardsPerExtraBiome = 2,        -- бонус, если открыта Бездна
	IncubatorSlotAt = 5,            -- 2-й слот инкубатора за 5-й ребёрс

	Perks = {
		{ Id = "DrillSpeed", Name = "Скорость бурения", Desc = "+5% к частоте ударов", PerLevel = 0.05, Costs = { 1, 1, 2, 2, 3, 3 }, Color = { 255, 120, 70 } },
		{ Id = "Capacity", Name = "Вместимость рюкзака", Desc = "+10% к вместимости", PerLevel = 0.10, Costs = { 1, 2, 2, 3, 3 }, Color = { 255, 196, 46 } },
		{ Id = "WalkSpeed", Name = "Скорость бега", Desc = "+4% к скорости бега", PerLevel = 0.04, Costs = { 1, 1, 2, 2, 3 }, Color = { 90, 200, 255 } },
		{ Id = "Magnet", Name = "Магнит руды", Desc = "Радиус сбора самородков 8 → 16", Radius = { 8, 10, 12, 14, 16 }, Costs = { 1, 2, 2, 3, 3 }, Color = { 170, 110, 255 } },
		{ Id = "PetSlot", Name = "Слот питомца", Desc = "+1 слот экипировки", PerLevel = 1, Costs = { 8 }, Color = { 90, 220, 110 } },
	},
}
