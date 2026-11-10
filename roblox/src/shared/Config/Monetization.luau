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
			Description = "x2 Shards from fights, +25% roll luck, VIP chat & name tag.",
			Price = 299,
			Order = 1,
		},
		DoubleXP = {
			Id = 0,
			Name = "x2 XP",
			Description = "Level up twice as fast. Forever.",
			Price = 199,
			Order = 2,
		},
		Luck = {
			Id = 0,
			Name = "Lucky Spirit",
			Description = "x2 chance for Epic, Legendary and Mythic Arts.",
			Price = 349,
			Order = 3,
		},
		QuickRoll = {
			Id = 0,
			Name = "Quick Roll",
			Description = "Unlocks x10 rolls in one click.",
			Price = 149,
			Order = 4,
		},
	},

	Products = {
		Spins10 = {
			Id = 0,
			Name = "10 Spins",
			Description = "10 Spirit Rolls.",
			Price = 99,
			Grant = { Spins = 10 },
			PaidRandom = true,
			Order = 1,
		},
		Spins55 = {
			Id = 0,
			Name = "55 Spins",
			Description = "50 Spirit Rolls + 5 bonus.",
			Price = 449,
			Grant = { Spins = 55 },
			PaidRandom = true,
			Order = 2,
		},
		Shards5k = {
			Id = 0,
			Name = "5,000 Shards",
			Description = "Shards can be spent on rolls when you are out of spins.",
			Price = 129,
			Grant = { Shards = 5000 },
			PaidRandom = true,
			Order = 3,
		},
		ServerLuck = {
			Id = 0,
			Name = "Server Luck x2",
			Description = "x2 luck for EVERYONE in the server for 15 minutes. Stacks time.",
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
