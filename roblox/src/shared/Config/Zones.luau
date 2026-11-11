-- World zones. The hub is the PvP arena; every other zone is a themed PvE
-- island far from the hub with its own mobs, boss, lighting and level gate.

local Zones = {}

Zones.Order = { "Hub", "Ember", "Tidal", "Storm", "Void" }

Zones.List = {
	Hub = {
		Name = "Арена Разлома",
		Subtitle = "PvP-арена • Тренировка • Небесный остров",
		MinLevel = 1,
		Pvp = true,
		Color = Color3.fromRGB(255, 80, 150),
		Boss = { Id = "RiftWarden", Name = "Страж Разлома", Level = 12, Element = "Void", Outfit = "Warden", Scale = 1.9, Respawn = 180, Leash = 45 },
		SkyMobs = { { Id = "RiftSprite", Name = "Дух Разлома", Level = 4, Count = 9, Element = "Light", Outfit = "Sprite", Scale = 0.8, Leash = 20 } },
		SkyCenters = { Vector3.new(-120, 0, 40), Vector3.new(118, 0, -10) },
	},

	Ember = {
		Name = "Пепельные Пустоши",
		Subtitle = "Ур. 1+ • Вулканические земли",
		MinLevel = 1,
		Origin = Vector3.new(2400, 0, 0),
		Theme = "Ember",
		Color = Color3.fromRGB(255, 120, 50),
		Lighting = {
			ClockTime = 18.4,
			AtmosphereColor = Color3.fromRGB(255, 150, 110),
			AtmosphereDecay = Color3.fromRGB(120, 40, 30),
			Density = 0.3,
			Haze = 1.3,
			Tint = Color3.fromRGB(255, 225, 205),
			Saturation = 0.25,
		},
		Mobs = {
			{ Id = "CinderImp", Name = "Пепельный бес", Level = 3, Count = 7, Element = "Fire", Outfit = "Imp", Scale = 0.85 },
			{ Id = "AshBrute", Name = "Пепельный громила", Level = 9, Count = 4, Element = "Fire", Outfit = "Brute", Scale = 1.3 },
		},
		SkyMobs = { { Id = "InfernoImp", Name = "Элитный адский бес", Level = 14, Count = 9, Element = "Fire", Outfit = "Imp", Scale = 1, Elite = true, Leash = 20 } },
		Boss = { Id = "MagmaTyrant", Name = "Магмовый Тиран", Level = 15, Element = "Fire", Outfit = "Tyrant", Scale = 2.2, Respawn = 180 },
	},

	Tidal = {
		Name = "Храм Прилива",
		Subtitle = "Ур. 15+ • Затонувший храм",
		MinLevel = 15,
		Origin = Vector3.new(-2400, 0, 0),
		Theme = "Tidal",
		Color = Color3.fromRGB(60, 190, 255),
		Lighting = {
			ClockTime = 9.5,
			AtmosphereColor = Color3.fromRGB(170, 230, 255),
			AtmosphereDecay = Color3.fromRGB(40, 110, 160),
			Density = 0.24,
			Haze = 0.7,
			Tint = Color3.fromRGB(225, 245, 255),
			Saturation = 0.2,
		},
		Mobs = {
			{ Id = "ReefStalker", Name = "Рифовый охотник", Level = 18, Count = 7, Element = "Water", Outfit = "Stalker", Scale = 1 },
			{ Id = "TideSentinel", Name = "Страж прилива", Level = 26, Count = 4, Element = "Water", Outfit = "Sentinel", Scale = 1.35 },
		},
		SkyMobs = { { Id = "EliteSentinel", Name = "Элитный страж прилива", Level = 32, Count = 9, Element = "Water", Outfit = "Sentinel", Scale = 1.2, Elite = true, Leash = 20 } },
		Boss = { Id = "LeviathanKnight", Name = "Рыцарь Левиафана", Level = 35, Element = "Water", Outfit = "Leviathan", Scale = 2.3, Respawn = 180 },
	},

	Storm = {
		Name = "Грозовые Пики",
		Subtitle = "Ур. 40+ • Горы грома",
		MinLevel = 40,
		Origin = Vector3.new(0, 0, 2400),
		Theme = "Storm",
		Color = Color3.fromRGB(255, 230, 80),
		Lighting = {
			ClockTime = 15.5,
			AtmosphereColor = Color3.fromRGB(210, 215, 235),
			AtmosphereDecay = Color3.fromRGB(80, 90, 130),
			Density = 0.34,
			Haze = 1.6,
			Tint = Color3.fromRGB(235, 240, 255),
			Saturation = 0.05,
		},
		Mobs = {
			{ Id = "StormAcolyte", Name = "Послушник бури", Level = 45, Count = 7, Element = "Lightning", Outfit = "Acolyte", Scale = 1 },
			{ Id = "GaleRonin", Name = "Ронин урагана", Level = 58, Count = 4, Element = "Wind", Outfit = "Ronin", Scale = 1.15 },
		},
		SkyMobs = { { Id = "EliteRonin", Name = "Элитный ронин урагана", Level = 66, Count = 9, Element = "Wind", Outfit = "Ronin", Scale = 1.15, Elite = true, Leash = 20 } },
		Boss = { Id = "ThunderShogun", Name = "Громовой Сёгун", Level = 72, Element = "Lightning", Outfit = "Shogun", Scale = 2.3, Respawn = 180 },
	},

	Void = {
		Name = "Бездна Пустоты",
		Subtitle = "Ур. 80+ • За гранью Разлома",
		MinLevel = 80,
		Origin = Vector3.new(0, 0, -2400),
		Theme = "Void",
		Color = Color3.fromRGB(160, 80, 255),
		Lighting = {
			ClockTime = 0.5,
			AtmosphereColor = Color3.fromRGB(120, 70, 200),
			AtmosphereDecay = Color3.fromRGB(30, 10, 60),
			Density = 0.34,
			Haze = 1.4,
			Tint = Color3.fromRGB(230, 215, 255),
			Saturation = 0.3,
		},
		Mobs = {
			{ Id = "HollowWraith", Name = "Призрак пустоты", Level = 85, Count = 7, Element = "Void", Outfit = "Wraith", Scale = 1.05 },
			{ Id = "RiftHorror", Name = "Ужас Разлома", Level = 100, Count = 4, Element = "Void", Outfit = "Horror", Scale = 1.45 },
		},
		SkyMobs = { { Id = "EliteHorror", Name = "Элитный ужас Разлома", Level = 115, Count = 9, Element = "Void", Outfit = "Horror", Scale = 1.4, Elite = true, Leash = 20 } },
		Boss = { Id = "RiftSovereign", Name = "Владыка Разлома", Level = 130, Element = "Light", Outfit = "Sovereign", Scale = 2.5, Respawn = 180 },
	},
}

-- Mob stat formulas (bosses multiply these).
Zones.Mob = {
	-- Tuned so a regular mob dies in ~4-6 s and a boss in ~1 min solo for a
	-- player at the zone's level (player damage grows ~6% per level via STR).
	HealthBase = 85,
	HealthPerLevel = 13,
	DamageBase = 5,
	DamagePerLevel = 0.6,
	ShardsBase = 5,
	ShardsPerLevel = 0.5,
	XpBase = 12,
	XpPerLevel = 4,
	Respawn = 8,
	AggroRange = 45, -- only used once a mob is already fighting you
	-- Mobs are neutral: they only start a fight if you hit them or walk right
	-- up to them, and no more than MaxAttackers mobs gang up on one player.
	ProximityAggro = 12,
	AggroMemory = 10, -- seconds a mob stays angry after you last hit it
	MaxAttackers = 2,
	LeashRange = 110,
	AttackRange = 6,
	AttackCooldown = 1.3,
	AbilityCooldown = 7,
	BossHealthMult = 8.5, -- bosses keep ~the same HP after the mob HP bumps
	BossDamageMult = 2.2,
	BossRewardMult = 25,
	BossContributionShare = 0.05,

	-- Built for 12-player servers:
	LootShare = 0.2, -- anyone with >= 20% of a mob's damage gets the full reward (no kill stealing)
	PopulationBase = 0.5, -- mobs alive = Count * (Base + PerPlayer * players in zone), capped at Max
	PopulationPerPlayer = 0.25,
	PopulationMax = 2,
	BossHealthPerPlayer = 0.35, -- +35% boss HP per extra player in the zone
	BossRespawn = 180, -- every boss returns 3 minutes after it dies
	-- Out-of-combat regen: only after RegenDelay seconds without being hit,
	-- and slowly. Leashing back home never heals.
	RegenDelay = 8,
	RegenPerSecond = 0.02,
	-- Rewards fall off when you out-level a mob (no farming newbie mobs):
	-- -15% per level beyond 5 levels above the mob, down to 10%.
	LevelGapFree = 5,
	LevelGapPenalty = 0.15,
	LevelGapMin = 0.1,
	-- Fighting mobs above your level pays a bit more (+3% per level, max +30%).
	LevelGapBonus = 0.03,
	LevelGapBonusMax = 0.3,
	EliteHealthMult = 2,
	EliteRewardMult = 2.5,
}

-- Floating platforms reachable with double (Lv 10) / triple (Lv 15) jumps.
-- Heights are relative to the ground; elites live on the top isle.
Zones.Sky = {
	Tier1Height = 16, -- needs a double jump from the ground
	Tier2Height = 31, -- double jump from tier 1
	TopHeight = 56, -- triple jump from tier 2
	TopRadius = 26,
	-- Several sky areas per island (relative to the island centre).
	IslandOffsets = { Vector3.new(200, 0, 60), Vector3.new(-210, 0, -20), Vector3.new(30, 0, -140) },
}

Zones.Jumps = {
	{ Level = 10, Extra = 1 }, -- double jump
	{ Level = 15, Extra = 2 }, -- triple jump
}
Zones.AirJumpHeight = 11

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
		if (flat - Vector3.new(math.cos(a) * 165, 0, math.sin(a) * 165)).Magnitude < cfg.SpawnRadius then
			return true
		end
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		if (flat - Vector3.new(math.cos(a) * 176, 0, math.sin(a) * 176)).Magnitude < cfg.PortalRadius then
			return true
		end
	end
	local d = flat - cfg.TrainingCenter
	return math.abs(d.X) < cfg.TrainingHalfSize.X and math.abs(d.Z) < cfg.TrainingHalfSize.Y
end

-- Areas inside every location:
--   Safe  — around the spawn: no PvP, mobs won't attack you
--   Pvp   — around the boss arena: fight the boss AND other players
--   Pve   — everything else: farm mobs, no PvP
Zones.Areas = {
	Island = {
		Safe = { Offset = Vector3.new(0, 0, 330), Radius = 36 },
		Pvp = { Offset = Vector3.new(0, 0, -280), Radius = 52 },
	},
	HubPvpRadius = 70, -- centre of the Rift Arena (duel ring + Rift Warden)
}

function Zones.AreaAt(zoneId: string, pos: Vector3): string
	local zone = Zones.List[zoneId]
	if not zone then
		return "Pve"
	end
	local flat = Vector3.new(pos.X, 0, pos.Z)
	if zone.Origin then
		local rel = flat - Vector3.new(zone.Origin.X, 0, zone.Origin.Z)
		local areas = Zones.Areas.Island
		if (rel - areas.Safe.Offset).Magnitude < areas.Safe.Radius then
			return "Safe"
		elseif (rel - areas.Pvp.Offset).Magnitude < areas.Pvp.Radius then
			return "Pvp"
		end
		return "Pve"
	end
	if Zones.IsHubSafe(pos) then
		return "Safe"
	elseif flat.Magnitude < Zones.Areas.HubPvpRadius then
		return "Pvp"
	end
	return "Pve"
end

-- Reward multiplier for a player of `playerLevel` beating a mob of `mobLevel`.
function Zones.RewardFactor(playerLevel: number, mobLevel: number): number
	local m = Zones.Mob
	local gap = playerLevel - mobLevel
	if gap > m.LevelGapFree then
		return math.max(m.LevelGapMin, 1 - (gap - m.LevelGapFree) * m.LevelGapPenalty)
	elseif gap < 0 then
		return 1 + math.min(m.LevelGapBonusMax, -gap * m.LevelGapBonus)
	end
	return 1
end

function Zones.Get(id: string)
	return Zones.List[id]
end

return Zones
