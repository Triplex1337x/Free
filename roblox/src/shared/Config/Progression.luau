-- Character progression: stat points from levels and per-Art mastery that
-- unlocks skills one by one.

local Progression = {}

Progression.PointsPerLevel = 3
Progression.ResetCostShards = 2500

Progression.Stats = {
	{ Id = "Strength", Name = "Strength", Short = "STR", Description = "+2% damage per point", Color = Color3.fromRGB(255, 90, 90) },
	{ Id = "Vitality", Name = "Vitality", Short = "VIT", Description = "+5 max HP per point", Color = Color3.fromRGB(90, 230, 140) },
	{ Id = "Agility", Name = "Agility", Short = "AGI", Description = "-0.5% cooldowns, +0.04 run speed per point", Color = Color3.fromRGB(90, 200, 255) },
	{ Id = "Spirit", Name = "Spirit", Short = "SPI", Description = "+2% Awakening gain per point", Color = Color3.fromRGB(190, 110, 255) },
}

Progression.StrengthDamage = 0.02
Progression.VitalityHealth = 5
Progression.AgilityCooldown = 0.005
Progression.AgilityCooldownCap = 0.4
Progression.AgilitySpeed = 0.04
Progression.AgilitySpeedCap = 6
Progression.SpiritAwakening = 0.02

-- Mastery: using an Art levels it up and unlocks its skills.
Progression.Mastery = {
	MaxLevel = 20,
	Unlocks = { Q = 1, E = 3, R = 6, G = 10 },
	DamagePerLevel = 0.01, -- +1% damage with that Art per mastery level
	XpPerDamage = 1,
	XpPerKill = 40,
}

function Progression.MasteryXpFor(level: number): number
	return math.floor(60 * level ^ 1.35)
end

function Progression.GetMastery(data, styleId: string): (number, number)
	local entry = data and data.Mastery and data.Mastery[styleId]
	if entry then
		return entry.Level or 1, entry.Xp or 0
	end
	return 1, 0
end

function Progression.IsUnlocked(data, styleId: string, key: string): boolean
	local level = Progression.GetMastery(data, styleId)
	return level >= (Progression.Mastery.Unlocks[key] or 1)
end

return Progression
