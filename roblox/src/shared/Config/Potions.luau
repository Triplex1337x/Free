-- Potions: consumable timed buffs. Using a potion that is already active
-- extends its timer (up to MaxStackMinutes). Shard prices are a deliberate
-- economy sink; potions also drop from quests, bosses and (rarely) mobs.

local Potions = {}

Potions.Order = { "XpPotion", "ShardPotion", "LuckPotion", "RagePotion", "IronPotion", "GalePotion", "MasteryPotion", "SpiritPotion" }

Potions.List = {
	XpPotion = {
		Name = "Настой мудреца", Glyph = "XP", Color = Color3.fromRGB(255, 200, 60),
		Description = "x2 опыт за всё", Minutes = 15, Effect = "Xp", Value = 2, Price = 900,
	},
	ShardPotion = {
		Name = "Золотое варево", Glyph = "◆", Color = Color3.fromRGB(70, 200, 255),
		Description = "x1.5 осколков в боях", Minutes = 15, Effect = "Shards", Value = 1.5, Price = 1200,
	},
	LuckPotion = {
		Name = "Нектар удачи", Glyph = "★", Color = Color3.fromRGB(120, 255, 140),
		Description = "x1.5 удача в роллах", Minutes = 10, Effect = "Luck", Value = 1.5, Price = 1500,
	},
	RagePotion = {
		Name = "Эликсир берсерка", Glyph = "炎", Color = Color3.fromRGB(255, 70, 70),
		Description = "+20% наносимого урона", Minutes = 10, Effect = "Damage", Value = 0.2, Price = 1000,
	},
	IronPotion = {
		Name = "Тоник железной кожи", Glyph = "盾", Color = Color3.fromRGB(170, 180, 200),
		Description = "-20% получаемого урона", Minutes = 10, Effect = "Defense", Value = 0.2, Price = 1000,
	},
	GalePotion = {
		Name = "Настой ветра", Glyph = "風", Color = Color3.fromRGB(140, 255, 220),
		Description = "+4 к скорости бега", Minutes = 10, Effect = "Speed", Value = 4, Price = 600,
	},
	MasteryPotion = {
		Name = "Чай сэнсэя", Glyph = "技", Color = Color3.fromRGB(255, 130, 200),
		Description = "x2 опыт мастерства", Minutes = 15, Effect = "Mastery", Value = 2, Price = 1100,
	},
	SpiritPotion = {
		Name = "Тоник пробуждения", Glyph = "覚", Color = Color3.fromRGB(180, 110, 255),
		Description = "+50% к набору пробуждения", Minutes = 10, Effect = "Awakening", Value = 0.5, Price = 900,
	},
}

Potions.MaxStackMinutes = 120
Potions.MobDropChance = 0.02 -- per winner, non-boss mobs
Potions.BossDropChance = 0.35 -- per winner, bosses

function Potions.Get(id: string)
	return Potions.List[id]
end

return Potions
