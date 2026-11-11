-- Potions: consumable timed buffs. Using a potion that is already active
-- extends its timer (up to MaxStackMinutes). Shard prices are a deliberate
-- economy sink; potions also drop from quests, bosses and (rarely) mobs.

local Potions = {}

Potions.Order = { "XpPotion", "ShardPotion", "LuckPotion", "RagePotion", "IronPotion", "GalePotion", "MasteryPotion", "SpiritPotion" }

Potions.List = {
	XpPotion = {
		Name = "Scholar's Draught", Glyph = "XP", Color = Color3.fromRGB(255, 200, 60),
		Description = "x2 XP from everything", Minutes = 15, Effect = "Xp", Value = 2, Price = 900,
	},
	ShardPotion = {
		Name = "Gilded Brew", Glyph = "◆", Color = Color3.fromRGB(70, 200, 255),
		Description = "x1.5 Shards from fights", Minutes = 15, Effect = "Shards", Value = 1.5, Price = 1200,
	},
	LuckPotion = {
		Name = "Fortune Nectar", Glyph = "★", Color = Color3.fromRGB(120, 255, 140),
		Description = "x1.5 Spirit Roll luck", Minutes = 10, Effect = "Luck", Value = 1.5, Price = 1500,
	},
	RagePotion = {
		Name = "Berserker Elixir", Glyph = "炎", Color = Color3.fromRGB(255, 70, 70),
		Description = "+20% damage dealt", Minutes = 10, Effect = "Damage", Value = 0.2, Price = 1000,
	},
	IronPotion = {
		Name = "Iron Skin Tonic", Glyph = "盾", Color = Color3.fromRGB(170, 180, 200),
		Description = "-20% damage taken", Minutes = 10, Effect = "Defense", Value = 0.2, Price = 1000,
	},
	GalePotion = {
		Name = "Gale Draught", Glyph = "風", Color = Color3.fromRGB(140, 255, 220),
		Description = "+4 run speed", Minutes = 10, Effect = "Speed", Value = 4, Price = 600,
	},
	MasteryPotion = {
		Name = "Sensei's Tea", Glyph = "技", Color = Color3.fromRGB(255, 130, 200),
		Description = "x2 Art mastery XP", Minutes = 15, Effect = "Mastery", Value = 2, Price = 1100,
	},
	SpiritPotion = {
		Name = "Awakening Tonic", Glyph = "覚", Color = Color3.fromRGB(180, 110, 255),
		Description = "+50% Awakening gain", Minutes = 10, Effect = "Awakening", Value = 0.5, Price = 900,
	},
}

Potions.MaxStackMinutes = 120
Potions.MobDropChance = 0.02 -- per winner, non-boss mobs
Potions.BossDropChance = 0.35 -- per winner, bosses

function Potions.Get(id: string)
	return Potions.List[id]
end

return Potions
