-- Fighting styles ("Arts"). All names and concepts are original.
--
-- Ability kinds:
--   Melee      box hitbox in front of the caster  (Range, Width)
--   Dash       flash-step forward, hits everything on the path (Distance)
--   AoE        sphere around the caster, optionally pushed forward (Radius, Offset)
--   Projectile travelling orb, optional explosion (Speed, MaxDistance, Size, Explode)
--
-- Passive = the style's signature trait (see CombatService). Rarity also sets
-- a power multiplier (Config/Gacha: Power) so rarer Arts always hit harder.
--
-- Element drives the visual effect set (Fire, Water, Wind, Earth, Lightning,
-- Void, Light).
--
-- Shared fields: Damage (per hit), Hits (multi-hit count), HitInterval,
-- Stun, Knockback (negative = pull toward the caster/centre), Windup,
-- Cooldown (not used for the ultimate, which costs a full Awakening bar),
-- Unblockable, GuardBreak, Homing (locks onto the nearest enemy: projectiles
-- steer, dashes stop in front of the target, offset AoEs land on it),
-- HyperArmor (caster can't be stunned or knocked back while casting).
-- Ultimates always give hyper armor + invulnerability while they play out.

local Styles = {}

Styles.Order = { "Ember", "Tide", "Gale", "Bastion", "Storm", "Hollow", "Dawn" }

Styles.List = {
	Ember = {
		Name = "Пламенный Кулак",
		Element = "Fire",
		Passive = { Id = "Burn", Name = "Поджог", Description = "Удары поджигают цель: +25% урона за 2 сек." },
		Rarity = "Common",
		Color = Color3.fromRGB(255, 112, 40),
		Description = "Горячий боец ближнего боя. Быстрые вспышки пламени.",
		Abilities = {
			Q = { Name = "Огненный джеб", Kind = "Melee", Cooldown = 4, Damage = 11, Range = 9, Width = 6, Stun = 0.6, Knockback = 25, Windup = 0.12 },
			E = { Name = "Шаг пламени", Kind = "Dash", Homing = true, Cooldown = 7, Damage = 10, Distance = 28, Stun = 0.5, Knockback = 15, Windup = 0.08 },
			R = { Name = "Взрыв пепла", Kind = "AoE", HyperArmor = true, Cooldown = 12, Damage = 18, Radius = 13, Stun = 0.8, Knockback = 45, Windup = 0.35 },
		},
		Ultimate = { Name = "Восход Феникса", Kind = "AoE", Damage = 14, Hits = 3, HitInterval = 0.2, Radius = 22, Stun = 1.4, Knockback = 80, Windup = 0.7, Unblockable = true },
	},

	Tide = {
		Name = "Клинок Прилива",
		Element = "Water",
		Passive = { Id = "Lifesteal", Name = "Прилив жизни", Description = "Восстанавливаешь 12% от нанесённого урона." },
		Rarity = "Common",
		Color = Color3.fromRGB(60, 170, 255),
		Description = "Текучее фехтование. Контроль пространства водой.",
		Abilities = {
			Q = { Name = "Водяная пуля", Kind = "Projectile", Homing = true, Cooldown = 4, Damage = 10, Speed = 110, MaxDistance = 90, Size = 2.5, Stun = 0.5, Knockback = 20, Windup = 0.1 },
			E = { Name = "Разрез отлива", Kind = "Melee", Homing = true, Cooldown = 7, Damage = 14, Range = 11, Width = 10, Stun = 0.7, Knockback = 30, Windup = 0.18 },
			R = { Name = "Водоворот", Kind = "AoE", Cooldown = 13, Damage = 6, Hits = 3, HitInterval = 0.25, Radius = 15, Stun = 0.9, Knockback = -30, Windup = 0.3 },
		},
		Ultimate = { Name = "Копьё Левиафана", Kind = "Projectile", Damage = 40, Speed = 140, MaxDistance = 140, Size = 6, Explode = 16, Stun = 1.5, Knockback = 90, Windup = 0.6, Unblockable = true },
	},

	Gale = {
		Name = "Шаг Урагана",
		Element = "Wind",
		Passive = { Id = "Swift", Name = "Попутный ветер", Description = "+4 к скорости и -15% перезарядки скиллов." },
		Rarity = "Rare",
		Color = Color3.fromRGB(140, 255, 190),
		Description = "Неуловимая скорость. Удар, исчезновение, снова удар.",
		Abilities = {
			Q = { Name = "Рассечение зефира", Kind = "Dash", Homing = true, Cooldown = 5, Damage = 12, Distance = 34, Stun = 0.5, Knockback = 10, Windup = 0.05 },
			E = { Name = "Клинок ветра", Kind = "Projectile", Cooldown = 6, Damage = 13, Speed = 170, MaxDistance = 110, Size = 3, Stun = 0.5, Knockback = 25, Windup = 0.1 },
			R = { Name = "Циклон", Kind = "AoE", Cooldown = 12, Damage = 7, Hits = 4, HitInterval = 0.18, Radius = 14, Stun = 1, Knockback = -35, Windup = 0.25 },
		},
		Ultimate = { Name = "Тысяча порывов", Kind = "Dash", Homing = true, Damage = 9, Hits = 5, HitInterval = 0.1, Distance = 50, Stun = 1.6, Knockback = 70, Windup = 0.4, Unblockable = true },
	},

	Bastion = {
		Name = "Железный Бастион",
		Element = "Earth",
		Passive = { Id = "Stoneskin", Name = "Каменная кожа", Description = "-20% получаемого урона, все скиллы с гиперармором." },
		Rarity = "Rare",
		Color = Color3.fromRGB(190, 140, 90),
		Description = "Танк, повелевающий землёй. Медленный, тяжёлый, сокрушающий.",
		Abilities = {
			Q = { Name = "Камнедробитель", Kind = "Melee", HyperArmor = true, Homing = true, Cooldown = 5, Damage = 16, Range = 9, Width = 7, Stun = 0.9, Knockback = 40, Windup = 0.25, GuardBreak = true },
			E = { Name = "Топот землетрясения", Kind = "AoE", HyperArmor = true, Cooldown = 9, Damage = 15, Radius = 12, Stun = 1.1, Knockback = 20, Windup = 0.3 },
			R = { Name = "Бросок валуна", Kind = "Projectile", HyperArmor = true, Cooldown = 12, Damage = 22, Speed = 75, MaxDistance = 100, Size = 5, Explode = 9, Stun = 1, Knockback = 55, Windup = 0.4 },
		},
		Ultimate = { Name = "Гнев Титана", Kind = "AoE", Damage = 48, Radius = 24, Stun = 2, Knockback = 100, Windup = 0.9, Unblockable = true },
	},

	Storm = {
		Name = "Копьё Бури",
		Element = "Lightning",
		Passive = { Id = "Chain", Name = "Цепная молния", Description = "Скиллы бьют ещё 2 врагов рядом на 40% урона." },
		Rarity = "Epic",
		Color = Color3.fromRGB(255, 230, 70),
		Description = "Дуэлянт молний. Дальний бой и мгновенные наказания.",
		Abilities = {
			Q = { Name = "Дуговой разряд", Kind = "Projectile", Homing = true, Cooldown = 4, Damage = 12, Speed = 220, MaxDistance = 130, Size = 2, Stun = 0.6, Knockback = 15, Windup = 0.08 },
			E = { Name = "Громовая вспышка", Kind = "Dash", Homing = true, GuardBreak = true, Cooldown = 6, Damage = 15, Distance = 40, Stun = 0.7, Knockback = 25, Windup = 0.05 },
			R = { Name = "Статическое поле", Kind = "AoE", Cooldown = 12, Damage = 6, Hits = 4, HitInterval = 0.2, Radius = 15, Stun = 1.2, Knockback = 10, Windup = 0.25 },
		},
		Ultimate = { Name = "Приговор Небес", Kind = "AoE", Homing = true, Damage = 55, Radius = 20, Offset = 18, Stun = 1.8, Knockback = 90, Windup = 0.8, Unblockable = true },
	},

	Hollow = {
		Name = "Длань Пустоты",
		Element = "Void",
		Passive = { Id = "Execute", Name = "Казнь", Description = "+40% урона по целям ниже 35% здоровья." },
		Rarity = "Legendary",
		Color = Color3.fromRGB(150, 70, 255),
		Description = "Повелитель пустоты. Притягивает врагов и стирает их.",
		Abilities = {
			Q = { Name = "Хватка Пустоты", Kind = "Melee", Homing = true, GuardBreak = true, Cooldown = 5, Damage = 14, Range = 15, Width = 7, Stun = 0.9, Knockback = -40, Windup = 0.15 },
			E = { Name = "Фазовый сдвиг", Kind = "Dash", Cooldown = 6, Damage = 16, Distance = 45, Stun = 0.6, Knockback = 20, Windup = 0.05 },
			R = { Name = "Сфера Бездны", Kind = "Projectile", Homing = true, Cooldown = 12, Damage = 26, Speed = 90, MaxDistance = 120, Size = 4, Explode = 14, Stun = 1.2, Knockback = -45, Windup = 0.3 },
		},
		Ultimate = { Name = "Горизонт событий", Kind = "AoE", Damage = 12, Hits = 5, HitInterval = 0.2, Radius = 26, Stun = 2, Knockback = -50, Windup = 0.7, Unblockable = true },
	},

	Dawn = {
		Name = "Владыка Рассвета",
		Element = "Light",
		Passive = { Id = "Radiance", Name = "Сияние", Description = "20% шанс крита x2 и 3% лечения за попадание скиллом." },
		Rarity = "Mythic",
		Color = Color3.fromRGB(255, 245, 200),
		Description = "Повелевает пойманным рассветом. Самый редкий стиль Разлома.",
		Abilities = {
			Q = { Name = "Солнечное копьё", Kind = "Projectile", Cooldown = 4, Damage = 16, Speed = 230, MaxDistance = 150, Size = 2.5, Stun = 0.7, Knockback = 30, Windup = 0.08 },
			E = { Name = "Рывок рассвета", Kind = "Dash", Homing = true, HyperArmor = true, Cooldown = 6, Damage = 10, Hits = 2, HitInterval = 0.12, Distance = 42, Stun = 0.8, Knockback = 35, Windup = 0.05 },
			R = { Name = "Корона", Kind = "AoE", Cooldown = 11, Damage = 26, Radius = 16, Stun = 1.2, Knockback = 60, Windup = 0.35, GuardBreak = true },
		},
		Ultimate = { Name = "Зенит", Kind = "AoE", Damage = 70, Radius = 30, Stun = 2.2, Knockback = 120, Windup = 1, Unblockable = true },
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
