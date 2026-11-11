-- World zones. The hub is the PvP arena; every other zone is a themed PvE
-- island far from the hub with its own mobs, boss, lighting and level gate.

local Zones = {}

Zones.Order = { "Hub", "Ember", "Tidal", "Storm", "Void" }

Zones.List = {
	Hub = {
		Name = "Rift Arena",
		Subtitle = "PvP arena • Training grounds",
		MinLevel = 1,
		Pvp = true,
		Color = Color3.fromRGB(255, 80, 150),
		Boss = { Id = "RiftWarden", Name = "Rift Warden", Level = 12, Element = "Void", Outfit = "Warden", Scale = 1.9, Respawn = 180, Leash = 45 },
	},

	Ember = {
		Name = "Ember Wastes",
		Subtitle = "Lv. 1+ • Volcanic badlands",
		MinLevel = 1,
		Origin = Vector3.new(2400, 0, 0),
		Theme = "Ember",
		Color = Color3.fromRGB(255, 120, 50),
		Lighting = {
			ClockTime = 18.4,
			AtmosphereColor = Color3.fromRGB(255, 150, 110),
			AtmosphereDecay = Color3.fromRGB(120, 40, 30),
			Density = 0.42,
			Haze = 2.4,
			Tint = Color3.fromRGB(255, 225, 205),
			Saturation = 0.25,
		},
		Mobs = {
			{ Id = "CinderImp", Name = "Cinder Imp", Level = 3, Count = 7, Element = "Fire", Outfit = "Imp", Scale = 0.85 },
			{ Id = "AshBrute", Name = "Ash Brute", Level = 9, Count = 4, Element = "Fire", Outfit = "Brute", Scale = 1.3 },
		},
		Boss = { Id = "MagmaTyrant", Name = "Magma Tyrant", Level = 15, Element = "Fire", Outfit = "Tyrant", Scale = 2.2, Respawn = 150 },
	},

	Tidal = {
		Name = "Tidal Shrine",
		Subtitle = "Lv. 15+ • Drowned temple",
		MinLevel = 15,
		Origin = Vector3.new(-2400, 0, 0),
		Theme = "Tidal",
		Color = Color3.fromRGB(60, 190, 255),
		Lighting = {
			ClockTime = 9.5,
			AtmosphereColor = Color3.fromRGB(170, 230, 255),
			AtmosphereDecay = Color3.fromRGB(40, 110, 160),
			Density = 0.36,
			Haze = 1.8,
			Tint = Color3.fromRGB(225, 245, 255),
			Saturation = 0.2,
		},
		Mobs = {
			{ Id = "ReefStalker", Name = "Reef Stalker", Level = 18, Count = 7, Element = "Water", Outfit = "Stalker", Scale = 1 },
			{ Id = "TideSentinel", Name = "Tide Sentinel", Level = 26, Count = 4, Element = "Water", Outfit = "Sentinel", Scale = 1.35 },
		},
		Boss = { Id = "LeviathanKnight", Name = "Leviathan Knight", Level = 35, Element = "Water", Outfit = "Leviathan", Scale = 2.3, Respawn = 180 },
	},

	Storm = {
		Name = "Storm Peaks",
		Subtitle = "Lv. 40+ • Thunder mountains",
		MinLevel = 40,
		Origin = Vector3.new(0, 0, 2400),
		Theme = "Storm",
		Color = Color3.fromRGB(255, 230, 80),
		Lighting = {
			ClockTime = 15.5,
			AtmosphereColor = Color3.fromRGB(210, 215, 235),
			AtmosphereDecay = Color3.fromRGB(80, 90, 130),
			Density = 0.45,
			Haze = 2.6,
			Tint = Color3.fromRGB(235, 240, 255),
			Saturation = 0.05,
		},
		Mobs = {
			{ Id = "StormAcolyte", Name = "Storm Acolyte", Level = 45, Count = 7, Element = "Lightning", Outfit = "Acolyte", Scale = 1 },
			{ Id = "GaleRonin", Name = "Gale Ronin", Level = 58, Count = 4, Element = "Wind", Outfit = "Ronin", Scale = 1.15 },
		},
		Boss = { Id = "ThunderShogun", Name = "Thunder Shogun", Level = 72, Element = "Lightning", Outfit = "Shogun", Scale = 2.3, Respawn = 210 },
	},

	Void = {
		Name = "Void Abyss",
		Subtitle = "Lv. 80+ • Beyond the Rift",
		MinLevel = 80,
		Origin = Vector3.new(0, 0, -2400),
		Theme = "Void",
		Color = Color3.fromRGB(160, 80, 255),
		Lighting = {
			ClockTime = 0.5,
			AtmosphereColor = Color3.fromRGB(120, 70, 200),
			AtmosphereDecay = Color3.fromRGB(30, 10, 60),
			Density = 0.5,
			Haze = 2.8,
			Tint = Color3.fromRGB(230, 215, 255),
			Saturation = 0.3,
		},
		Mobs = {
			{ Id = "HollowWraith", Name = "Hollow Wraith", Level = 85, Count = 7, Element = "Void", Outfit = "Wraith", Scale = 1.05 },
			{ Id = "RiftHorror", Name = "Rift Horror", Level = 100, Count = 4, Element = "Void", Outfit = "Horror", Scale = 1.45 },
		},
		Boss = { Id = "RiftSovereign", Name = "Rift Sovereign", Level = 130, Element = "Light", Outfit = "Sovereign", Scale = 2.5, Respawn = 240 },
	},
}

-- Mob stat formulas (bosses multiply these).
Zones.Mob = {
	HealthBase = 80,
	HealthPerLevel = 22,
	DamageBase = 5,
	DamagePerLevel = 0.6,
	ShardsBase = 5,
	ShardsPerLevel = 0.5,
	XpBase = 12,
	XpPerLevel = 4,
	Respawn = 8,
	AggroRange = 45,
	LeashRange = 110,
	AttackRange = 6,
	AttackCooldown = 1.3,
	AbilityCooldown = 7,
	BossHealthMult = 18,
	BossDamageMult = 2.2,
	BossRewardMult = 25,
	BossContributionShare = 0.05,

	-- Built for 12-player servers:
	LootShare = 0.2, -- anyone with >= 20% of a mob's damage gets the full reward (no kill stealing)
	PopulationBase = 0.5, -- mobs alive = Count * (Base + PerPlayer * players in zone), capped at Max
	PopulationPerPlayer = 0.25,
	PopulationMax = 2,
	BossHealthPerPlayer = 0.35, -- +35% boss HP per extra player in the zone
}

-- Hub safety (matches the generated arena layout in MapService).
Zones.HubSafe = {
	NewbieLevel = 5, -- players below this level can't fight or be fought in PvP
	SpawnRadius = 18,
	PortalRadius = 16,
	TrainingCenter = Vector3.new(0, 0, -55),
	TrainingHalfSize = Vector2.new(58, 14),
}

-- True if a hub position is inside a no-PvP area: spawns, portals, training grounds.
function Zones.IsHubSafe(pos: Vector3): boolean
	local cfg = Zones.HubSafe
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + math.pi / 6
		if (flat - Vector3.new(math.cos(a) * 110, 0, math.sin(a) * 110)).Magnitude < cfg.SpawnRadius then
			return true
		end
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		if (flat - Vector3.new(math.cos(a) * 118, 0, math.sin(a) * 118)).Magnitude < cfg.PortalRadius then
			return true
		end
	end
	local d = flat - cfg.TrainingCenter
	return math.abs(d.X) < cfg.TrainingHalfSize.X and math.abs(d.Z) < cfg.TrainingHalfSize.Y
end

function Zones.Get(id: string)
	return Zones.List[id]
end

return Zones
