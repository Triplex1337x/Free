-- Fighting styles ("Arts"). All names and concepts are original.
--
-- Ability kinds:
--   Melee      box hitbox in front of the caster  (Range, Width)
--   Dash       flash-step forward, hits everything on the path (Distance)
--   AoE        sphere around the caster, optionally pushed forward (Radius, Offset)
--   Projectile travelling orb, optional explosion (Speed, MaxDistance, Size, Explode)
--
-- Element drives the visual effect set (Fire, Water, Wind, Earth, Lightning,
-- Void, Light).
--
-- Shared fields: Damage (per hit), Hits (multi-hit count), HitInterval,
-- Stun, Knockback (negative = pull toward the caster/centre), Windup,
-- Cooldown (not used for the ultimate, which costs a full Awakening bar),
-- Unblockable, GuardBreak.

local Styles = {}

Styles.Order = { "Ember", "Tide", "Gale", "Bastion", "Storm", "Hollow", "Dawn" }

Styles.List = {
	Ember = {
		Name = "Ember Fist",
		Element = "Fire",
		Rarity = "Common",
		Color = Color3.fromRGB(255, 112, 40),
		Description = "Hot-blooded brawler. Fast close-range bursts of flame.",
		Abilities = {
			Q = { Name = "Flare Jab", Kind = "Melee", Cooldown = 4, Damage = 11, Range = 9, Width = 6, Stun = 0.6, Knockback = 25, Windup = 0.12 },
			E = { Name = "Blaze Step", Kind = "Dash", Cooldown = 7, Damage = 10, Distance = 28, Stun = 0.5, Knockback = 15, Windup = 0.08 },
			R = { Name = "Cinder Burst", Kind = "AoE", Cooldown = 12, Damage = 18, Radius = 13, Stun = 0.8, Knockback = 45, Windup = 0.35 },
		},
		Ultimate = { Name = "Phoenix Rising", Kind = "AoE", Damage = 14, Hits = 3, HitInterval = 0.2, Radius = 22, Stun = 1.4, Knockback = 80, Windup = 0.7, Unblockable = true },
	},

	Tide = {
		Name = "Tide Blade",
		Element = "Water",
		Rarity = "Common",
		Color = Color3.fromRGB(60, 170, 255),
		Description = "Flowing swordplay. Controls space with water.",
		Abilities = {
			Q = { Name = "Water Bullet", Kind = "Projectile", Cooldown = 4, Damage = 10, Speed = 110, MaxDistance = 90, Size = 2.5, Stun = 0.5, Knockback = 20, Windup = 0.1 },
			E = { Name = "Riptide Slash", Kind = "Melee", Cooldown = 7, Damage = 14, Range = 11, Width = 10, Stun = 0.7, Knockback = 30, Windup = 0.18 },
			R = { Name = "Whirlpool", Kind = "AoE", Cooldown = 13, Damage = 6, Hits = 3, HitInterval = 0.25, Radius = 15, Stun = 0.9, Knockback = -30, Windup = 0.3 },
		},
		Ultimate = { Name = "Leviathan Lance", Kind = "Projectile", Damage = 40, Speed = 140, MaxDistance = 140, Size = 6, Explode = 16, Stun = 1.5, Knockback = 90, Windup = 0.6, Unblockable = true },
	},

	Gale = {
		Name = "Gale Step",
		Element = "Wind",
		Rarity = "Rare",
		Color = Color3.fromRGB(140, 255, 190),
		Description = "Untouchable speed. Hit, vanish, hit again.",
		Abilities = {
			Q = { Name = "Zephyr Cut", Kind = "Dash", Cooldown = 5, Damage = 12, Distance = 34, Stun = 0.5, Knockback = 10, Windup = 0.05 },
			E = { Name = "Wind Blade", Kind = "Projectile", Cooldown = 6, Damage = 13, Speed = 170, MaxDistance = 110, Size = 3, Stun = 0.5, Knockback = 25, Windup = 0.1 },
			R = { Name = "Cyclone", Kind = "AoE", Cooldown = 12, Damage = 7, Hits = 4, HitInterval = 0.18, Radius = 14, Stun = 1, Knockback = -35, Windup = 0.25 },
		},
		Ultimate = { Name = "Thousand Gusts", Kind = "Dash", Damage = 9, Hits = 5, HitInterval = 0.1, Distance = 50, Stun = 1.6, Knockback = 70, Windup = 0.4, Unblockable = true },
	},

	Bastion = {
		Name = "Iron Bastion",
		Element = "Earth",
		Rarity = "Rare",
		Color = Color3.fromRGB(190, 140, 90),
		Description = "Earth-shaping tank. Slow, heavy, crushing.",
		Abilities = {
			Q = { Name = "Rock Crusher", Kind = "Melee", Cooldown = 5, Damage = 16, Range = 9, Width = 7, Stun = 0.9, Knockback = 40, Windup = 0.25, GuardBreak = true },
			E = { Name = "Quake Stomp", Kind = "AoE", Cooldown = 9, Damage = 15, Radius = 12, Stun = 1.1, Knockback = 20, Windup = 0.3 },
			R = { Name = "Boulder Toss", Kind = "Projectile", Cooldown = 12, Damage = 22, Speed = 75, MaxDistance = 100, Size = 5, Explode = 9, Stun = 1, Knockback = 55, Windup = 0.4 },
		},
		Ultimate = { Name = "Titan's Wrath", Kind = "AoE", Damage = 48, Radius = 24, Stun = 2, Knockback = 100, Windup = 0.9, Unblockable = true },
	},

	Storm = {
		Name = "Storm Lance",
		Element = "Lightning",
		Rarity = "Epic",
		Color = Color3.fromRGB(255, 230, 70),
		Description = "Lightning duelist. Long range, instant punishes.",
		Abilities = {
			Q = { Name = "Arc Bolt", Kind = "Projectile", Cooldown = 4, Damage = 12, Speed = 220, MaxDistance = 130, Size = 2, Stun = 0.6, Knockback = 15, Windup = 0.08 },
			E = { Name = "Thunder Flash", Kind = "Dash", Cooldown = 6, Damage = 15, Distance = 40, Stun = 0.7, Knockback = 25, Windup = 0.05 },
			R = { Name = "Static Field", Kind = "AoE", Cooldown = 12, Damage = 6, Hits = 4, HitInterval = 0.2, Radius = 15, Stun = 1.2, Knockback = 10, Windup = 0.25 },
		},
		Ultimate = { Name = "Heaven's Verdict", Kind = "AoE", Damage = 55, Radius = 20, Offset = 18, Stun = 1.8, Knockback = 90, Windup = 0.8, Unblockable = true },
	},

	Hollow = {
		Name = "Hollow Hand",
		Element = "Void",
		Rarity = "Legendary",
		Color = Color3.fromRGB(150, 70, 255),
		Description = "Void manipulator. Pulls enemies in and erases them.",
		Abilities = {
			Q = { Name = "Null Grasp", Kind = "Melee", Cooldown = 5, Damage = 14, Range = 15, Width = 7, Stun = 0.9, Knockback = -40, Windup = 0.15 },
			E = { Name = "Phase Shift", Kind = "Dash", Cooldown = 6, Damage = 16, Distance = 45, Stun = 0.6, Knockback = 20, Windup = 0.05 },
			R = { Name = "Abyss Orb", Kind = "Projectile", Cooldown = 12, Damage = 26, Speed = 90, MaxDistance = 120, Size = 4, Explode = 14, Stun = 1.2, Knockback = -45, Windup = 0.3 },
		},
		Ultimate = { Name = "Event Horizon", Kind = "AoE", Damage = 12, Hits = 5, HitInterval = 0.2, Radius = 26, Stun = 2, Knockback = -50, Windup = 0.7, Unblockable = true },
	},

	Dawn = {
		Name = "Dawn Sovereign",
		Element = "Light",
		Rarity = "Mythic",
		Color = Color3.fromRGB(255, 245, 200),
		Description = "Wields a captured sunrise. The rarest Art in the Rift.",
		Abilities = {
			Q = { Name = "Sunspear", Kind = "Projectile", Cooldown = 4, Damage = 16, Speed = 230, MaxDistance = 150, Size = 2.5, Stun = 0.7, Knockback = 30, Windup = 0.08 },
			E = { Name = "Daybreak Rush", Kind = "Dash", Cooldown = 6, Damage = 10, Hits = 2, HitInterval = 0.12, Distance = 42, Stun = 0.8, Knockback = 35, Windup = 0.05 },
			R = { Name = "Corona", Kind = "AoE", Cooldown = 11, Damage = 26, Radius = 16, Stun = 1.2, Knockback = 60, Windup = 0.35, GuardBreak = true },
		},
		Ultimate = { Name = "Zenith", Kind = "AoE", Damage = 70, Radius = 30, Stun = 2.2, Knockback = 120, Windup = 1, Unblockable = true },
	},
}

function Styles.Get(id: string)
	return Styles.List[id]
end

function Styles.GetAbility(id: string, key: string)
	local style = Styles.List[id]
	if not style then
		return nil
	end
	if key == "G" then
		return style.Ultimate
	end
	return style.Abilities[key]
end

return Styles
