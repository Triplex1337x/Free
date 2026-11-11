-- Core gameplay tuning. Everything balance-related lives here so it can be
-- changed without touching service code.

local Game = {}

Game.Name = "Rift Battlegrounds"

Game.StarterStyle = "Ember"
Game.StarterSpins = 5
Game.RespawnTime = 3
Game.BaseWalkSpeed = 16
Game.AutosaveInterval = 120

Game.Level = {
	Max = 250,
	HealthPerLevel = 1, -- +1 max HP per level (stats add more, see Config/Progression)
	DamagePerLevel = 0, -- damage now comes from Strength points and Art mastery
	BaseHealth = 100,
}

function Game.XpForLevel(level: number): number
	return math.floor(40 * level ^ 1.4)
end

Game.M1 = {
	Damage = 4,
	FinisherDamage = 9,
	Range = 7,
	Width = 5,
	HitCooldown = 0.32, -- min time between swings
	ComboWindow = 1.1, -- combo resets if you wait longer than this
	ComboLength = 4,
	ComboLockout = 1.1, -- pause after the finisher
	HitStun = 0.45,
	FinisherStun = 0.9,
	FinisherKnockback = 55,
	LockBonus = 5, -- extra reach for the M1 soft lock (auto-face + step-in)
}

-- Abilities pressed up to this early (cooldown / previous skill ending) are
-- buffered and fire the instant they're ready.
Game.InputBuffer = 0.45

-- Extra invulnerability after an ultimate finishes (on top of its duration).
Game.UltimateInvulnerability = 0.6

-- PvP is a setting (Settings panel), available from MinLevel. It can't be
-- switched off for LockSeconds after the last PvP hit.
Game.Pvp = {
	MinLevel = 10,
	LockSeconds = 30,
}

-- Counter: RMB + LMB (PC), C, gamepad L1, or the mobile button.
Game.Counter = {
	Window = 0.5,
	Cooldown = 6,
	Stun = 1.4,
	Damage = 14,
	Knockback = 45,
}

Game.Block = {
	DamageReduction = 0.75,
	PerfectWindow = 0.2, -- block within this window before a hit to parry it
	PerfectStun = 1.3, -- attacker is stunned this long after being parried
	GuardBreakStun = 1.2,
	WalkSpeed = 7,
	FacingDot = 0.15, -- block only covers attacks from the front
}

Game.Stun = {
	WalkSpeed = 3,
}

Game.Awakening = {
	Max = 100,
	PerDamageDealt = 0.55,
	PerDamageTaken = 0.25,
}

Game.Combat = {
	TagDuration = 10, -- seconds a hit counts for kill credit
	InCombatDuration = 6, -- blocks equipping styles mid-fight
	ActionsPerSecond = 15, -- server-side rate limit per player
}

Game.Rewards = {
	PlayerKillShards = 30,
	PlayerKillXp = 80,
	DummyKillShards = 6,
	DummyKillXp = 18,
	BossShards = 600,
	BossXp = 1200,
	BossContributionShare = 0.05, -- min share of boss damage needed for loot
	XpPerDamage = 0.4,
}

-- Login streak rewards, index = streak day (loops after the last day).
Game.DailyRewards = {
	{ Shards = 150 },
	{ Shards = 250 },
	{ Spins = 2 },
	{ Shards = 400 },
	{ Spins = 3 },
	{ Shards = 600 },
	{ Spins = 6, Shards = 1000 },
}
Game.DailyCooldownHours = 20
Game.DailyStreakResetHours = 48

-- Combat sounds. Defaults are sounds bundled with the Roblox client; put an
-- uploaded sound id (number) here to replace any of them.
Game.Sounds = {
	Swing = "rbxasset://sounds/swordslash.wav",
	Heavy = "rbxasset://sounds/swordlunge.wav",
	Hit = "rbxasset://sounds/swordlunge.wav",
	Cast = "rbxasset://sounds/unsheath.wav",
}

-- Optional uploaded animation asset ids. 0 = use the built-in procedural
-- animations (client/Animation/Clips). Paste an id to override a move.
Game.Animations = {
	M1 = { 0, 0, 0, 0 },
	Q = 0,
	E = 0,
	R = 0,
	G = 0,
	Block = 0,
}

return Game
