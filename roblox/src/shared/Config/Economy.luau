-- Economy: story quest chain, daily / weekly / monthly quests and playtime
-- gifts. See the "Экономика" section of the README for target rates.
--
-- Quest kinds:
--   Dummy, MobKill (optional Zone), BossKill (optional Zone), PvpKill, Damage, Roll,
--   Mastery (XP), Ultimate, Potion, Playtime (minutes)  -> progress adds up
--   Level, MasteryLevel                                 -> progress = highest value reached
-- Rewards: { Shards, Spins, Potions = { [potionId] = count } }.
-- Shard rewards scale with level: Shards * (1 + Level / ShardLevelScale).

local Economy = {}

Economy.ShardLevelScale = 25
Economy.SetKinds = { Level = true, MasteryLevel = true }

local function q(id, kind, goal, text, reward, zone)
	return { Id = id, Kind = kind, Goal = goal, Text = text, Reward = reward, Zone = zone }
end

Economy.Periods = {
	Daily = {
		Count = 3,
		Bonus = { Spins = 3, Potions = { XpPotion = 1 } },
		Pool = {
			q("D_Mobs", "MobKill", 80, "Победи %d мобов", { Shards = 500 }),
			q("D_Damage", "Damage", 25000, "Нанеси %d урона", { Shards = 450 }),
			q("D_Boss", "BossKill", 2, "Помоги победить %d боссов", { Spins = 2 }),
			q("D_Duels", "PvpKill", 5, "Выиграй %d дуэлей в PvP-зонах", { Shards = 400, Spins = 1 }),
			q("D_Rolls", "Roll", 10, "Сделай %d роллов", { Shards = 400 }),
			q("D_Mastery", "Mastery", 4000, "Набери %d опыта мастерства", { Shards = 500 }),
			q("D_Ults", "Ultimate", 6, "Примени ульту %d раз", { Spins = 1, Potions = { SpiritPotion = 1 } }),
			q("D_Play", "Playtime", 45, "Играй %d минут", { Shards = 350, Potions = { GalePotion = 1 } }),
		},
	},
	Weekly = {
		Count = 4,
		Bonus = { Spins = 10, Potions = { LuckPotion = 2, XpPotion = 2 } },
		Pool = {
			q("W_Mobs", "MobKill", 700, "Победи %d мобов", { Shards = 3000, Potions = { ShardPotion = 1 } }),
			q("W_Damage", "Damage", 300000, "Нанеси %d урона", { Shards = 3000 }),
			q("W_Boss", "BossKill", 20, "Помоги победить %d боссов", { Spins = 6 }),
			q("W_Duels", "PvpKill", 35, "Выиграй %d дуэлей в PvP-зонах", { Shards = 2500, Potions = { RagePotion = 2 } }),
			q("W_Rolls", "Roll", 60, "Сделай %d роллов", { Shards = 2000, Potions = { LuckPotion = 1 } }),
			q("W_Mastery", "Mastery", 40000, "Набери %d опыта мастерства", { Shards = 3000, Potions = { MasteryPotion = 2 } }),
			q("W_Ults", "Ultimate", 50, "Примени ульту %d раз", { Spins = 4 }),
			q("W_Play", "Playtime", 420, "Играй %d минут", { Spins = 5, Potions = { XpPotion = 1 } }),
			q("W_Potions", "Potion", 12, "Выпей %d зелий", { Shards = 2000, Spins = 2 }),
		},
	},
	Monthly = {
		Count = 5,
		Bonus = { Spins = 40, Potions = { LuckPotion = 5, XpPotion = 5, ShardPotion = 5 } },
		Pool = {
			q("M_Mobs", "MobKill", 4000, "Победи %d мобов", { Shards = 15000, Spins = 5 }),
			q("M_Damage", "Damage", 2500000, "Нанеси %d урона", { Shards = 15000 }),
			q("M_Boss", "BossKill", 100, "Помоги победить %d боссов", { Spins = 20 }),
			q("M_Duels", "PvpKill", 200, "Выиграй %d дуэлей в PvP-зонах", { Shards = 12000, Spins = 8 }),
			q("M_Rolls", "Roll", 300, "Сделай %d роллов", { Shards = 10000, Potions = { LuckPotion = 3 } }),
			q("M_Mastery", "Mastery", 200000, "Набери %d опыта мастерства", { Shards = 15000, Potions = { MasteryPotion = 4 } }),
			q("M_Ults", "Ultimate", 250, "Примени ульту %d раз", { Spins = 15 }),
			q("M_Play", "Playtime", 1800, "Играй %d минут", { Spins = 15, Potions = { XpPotion = 3 } }),
			q("M_Void", "MobKill", 600, "Победи %d мобов в Бездне Пустоты", { Spins = 20 }, "Void"),
		},
	},
}
Economy.PeriodOrder = { "Daily", "Weekly", "Monthly" }

-- Story chain: one active at a time, the next unlocks when it's done.
Economy.Chain = {
	q("S1", "Dummy", 5, "Победи %d манекенов на тренировочной площадке", { Shards = 150 }),
	q("S2", "Level", 3, "Достигни %d уровня", { Spins = 1 }),
	q("S3", "MobKill", 15, "Победи %d мобов в Пепельных Пустошах", { Shards = 300, Potions = { XpPotion = 1 } }, "Ember"),
	q("S4", "MasteryLevel", 3, "Подними любой стиль до %d мастерства (открывает E)", { Shards = 300 }),
	q("S5", "Roll", 3, "Сделай %d роллов", { Spins = 2 }),
	q("S6", "Level", 8, "Достигни %d уровня", { Shards = 500, Potions = { RagePotion = 1 } }),
	q("S7", "BossKill", 1, "Победи Магмового Тирана", { Spins = 3 }, "Ember"),
	q("S8", "MasteryLevel", 6, "Подними любой стиль до %d мастерства (открывает R)", { Shards = 800, Potions = { MasteryPotion = 1 } }),
	q("S9", "PvpKill", 1, "Выиграй дуэль в PvP-зоне", { Shards = 500 }),
	q("S10", "Level", 15, "Достигни %d уровня (открывает Храм Прилива)", { Spins = 3, Potions = { ShardPotion = 1 } }),
	q("S11", "MobKill", 40, "Победи %d мобов в Храме Прилива", { Shards = 1500 }, "Tidal"),
	q("S12", "MasteryLevel", 10, "Подними любой стиль до %d мастерства (открывает ульту)", { Spins = 5 }),
	q("S13", "BossKill", 1, "Победи Рыцаря Левиафана", { Shards = 2500, Potions = { LuckPotion = 1 } }, "Tidal"),
	q("S14", "Level", 30, "Достигни %d уровня", { Spins = 5 }),
	q("S15", "Level", 40, "Достигни %d уровня (открывает Грозовые Пики)", { Shards = 4000, Potions = { XpPotion = 2 } }),
	q("S16", "MobKill", 60, "Победи %d мобов на Грозовых Пиках", { Shards = 5000 }, "Storm"),
	q("S17", "BossKill", 1, "Победи Громового Сёгуна", { Spins = 8 }, "Storm"),
	q("S18", "Level", 80, "Достигни %d уровня (открывает Бездну Пустоты)", { Shards = 10000, Potions = { LuckPotion = 2 } }),
	q("S19", "MobKill", 100, "Победи %d мобов в Бездне Пустоты", { Spins = 10 }, "Void"),
	q("S20", "BossKill", 1, "Победи Владыку Разлома", { Spins = 20, Potions = { LuckPotion = 3, ShardPotion = 3 } }, "Void"),
}

-- After the story: endless bounties that grow with each one completed.
function Economy.Bounty(n: number)
	local goal = 40 + n * 10
	return q("B" .. n, "MobKill", goal, "ОХОТА №" .. n .. ": победи %d мобов", { Shards = 800 + n * 150, Spins = 1 + n // 3 })
end

function Economy.ChainQuest(step: number)
	return Economy.Chain[step] or Economy.Bounty(step - #Economy.Chain)
end

-- Playtime gifts per session.
Economy.PlaytimeGifts = {
	{ Minutes = 5, Reward = { Shards = 150 } },
	{ Minutes = 15, Reward = { Spins = 1 } },
	{ Minutes = 30, Reward = { Shards = 400, Potions = { GalePotion = 1 } } },
	{ Minutes = 45, Reward = { Spins = 2 } },
	{ Minutes = 60, Reward = { Shards = 800, Spins = 2, Potions = { XpPotion = 1 } } },
}

---------------------------------------------------------------------------
-- Periods
---------------------------------------------------------------------------

function Economy.PeriodNumber(kind: string): number
	local now = os.time()
	if kind == "Daily" then
		return now // 86400
	elseif kind == "Weekly" then
		return (now // 86400 + 3) // 7 -- weeks start on Monday (UTC)
	end
	local t = os.date("!*t", now)
	return t.year * 12 + t.month
end

-- Seconds until the period resets (UTC).
function Economy.SecondsLeft(kind: string): number
	local now = os.time()
	if kind == "Daily" then
		return 86400 - now % 86400
	elseif kind == "Weekly" then
		local day = (now // 86400 + 3) % 7
		return (7 - day) * 86400 - now % 86400
	end
	local t = os.date("!*t", now)
	local leap = (t.year % 4 == 0 and t.year % 100 ~= 0) or t.year % 400 == 0
	local days = ({ 31, if leap then 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[t.month]
	return (days - t.day) * 86400 + (86400 - now % 86400)
end

function Economy.Pick(kind: string, userId: number, period: number): { string }
	local cfg = Economy.Periods[kind]
	local rng = Random.new(period * 7919 + userId % 100003 + #kind * 131)
	local pool = table.clone(cfg.Pool)
	local picked = {}
	while #picked < cfg.Count and #pool > 0 do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(picked, q.Id)
	end
	return picked
end

local byId = {}
for _, cfg in Economy.Periods do
	for _, quest in cfg.Pool do
		byId[quest.Id] = quest
	end
end

function Economy.GetQuest(id: string)
	return byId[id]
end

function Economy.ScaledShards(shards: number, level: number?): number
	return math.floor(shards * (1 + (level or 1) / Economy.ShardLevelScale))
end

function Economy.DescribeReward(reward, level: number?, potionNames: { [string]: string }?): string
	local parts = {}
	if reward.Shards then
		table.insert(parts, ("%d ◆"):format(Economy.ScaledShards(reward.Shards, level)))
	end
	if reward.Spins then
		table.insert(parts, ("%d ✦"):format(reward.Spins))
	end
	for id, count in reward.Potions or {} do
		local name = potionNames and potionNames[id] or id
		table.insert(parts, ("%d× %s"):format(count, name))
	end
	return table.concat(parts, " + ")
end

return Economy
