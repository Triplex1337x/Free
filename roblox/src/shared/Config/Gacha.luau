-- Spirit Roll settings. Odds shown in the Roll menu are computed from this
-- exact table (see Shared/Gacha), so what players see is what the server uses.

return {
	Rarities = {
		{ Id = "Common", Weight = 56, Color = Color3.fromRGB(200, 200, 210), DupeShards = 40 },
		{ Id = "Rare", Weight = 28, Color = Color3.fromRGB(80, 160, 255), DupeShards = 120 },
		{ Id = "Epic", Weight = 12, Color = Color3.fromRGB(190, 90, 255), DupeShards = 400 },
		{ Id = "Legendary", Weight = 3.6, Color = Color3.fromRGB(255, 190, 40), DupeShards = 1500 },
		{ Id = "Mythic", Weight = 0.4, Color = Color3.fromRGB(255, 70, 110), DupeShards = 5000 },
	},

	LuckAffectsFromIndex = 3, -- luck multiplies weights of Epic and above
	PityRolls = 150, -- guaranteed Legendary+ after this many rolls without one
	PityMinIndex = 4,
	AnnounceFromIndex = 4, -- server-wide announcement for Legendary+
	GlobalAnnounceFromIndex = 5, -- cross-server announcement for Mythic
	RollCostShards = 300, -- used when the player is out of spins
	MinRollInterval = 0.35,
}
