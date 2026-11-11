-- Game passes and developer products.
--
-- 1. Create each pass / product on the Creator Dashboard
--    (Creations -> your experience -> Monetization).
-- 2. Paste the id into `Id` below. Items with Id = 0 are hidden in the shop.
-- 3. The real price is set on the dashboard; `Price` is only a fallback label
--    shown if the price can't be fetched.
--
-- `PaidRandom = true` marks items that (directly or indirectly) buy random
-- rewards. They are hidden for players whose region restricts paid random
-- items (PolicyService), as Roblox rules require. Odds are always visible in
-- the Spirit Roll menu.

return {
	GamePasses = {
		VIP = {
			Id = 0,
			Name = "VIP",
			Description = "x2 осколки в боях, +25% удачи в роллах, VIP-тег в чате и над головой.",
			Price = 299,
			Order = 1,
		},
		DoubleXP = {
			Id = 0,
			Name = "x2 ОПЫТ",
			Description = "Качайся вдвое быстрее. Навсегда.",
			Price = 199,
			Order = 2,
		},
		Luck = {
			Id = 0,
			Name = "Дух удачи",
			Description = "x2 шанс на эпические, легендарные и мифические стили.",
			Price = 349,
			Order = 3,
		},
		QuickRoll = {
			Id = 0,
			Name = "Быстрый ролл",
			Description = "Открывает ролл x10 в один клик.",
			Price = 149,
			Order = 4,
		},
	},

	Products = {
		Spins10 = {
			Id = 0,
			Name = "10 спинов",
			Description = "10 роллов.",
			Price = 99,
			Grant = { Spins = 10 },
			PaidRandom = true,
			Order = 1,
		},
		Spins55 = {
			Id = 0,
			Name = "55 спинов",
			Description = "50 роллов + 5 в подарок.",
			Price = 449,
			Grant = { Spins = 55 },
			PaidRandom = true,
			Order = 2,
		},
		Shards3k = {
			Id = 0,
			Name = "3 000 осколков",
			Description = "Это 10 роллов — или сброс статов и не только. По цене как 10 спинов.",
			Price = 99,
			Grant = { Shards = 3000 },
			PaidRandom = true,
			Order = 3,
		},
		ServerLuck = {
			Id = 0,
			Name = "Удача сервера x2",
			Description = "x2 удача ДЛЯ ВСЕХ на сервере на 15 минут. Время суммируется.",
			Price = 199,
			Grant = { ServerLuckMinutes = 15 },
			Order = 4,
		},
	},

	VipShardMultiplier = 2,
	VipLuckMultiplier = 1.25,
	LuckPassMultiplier = 2,
	ServerLuckMultiplier = 2,
}
