-- Economy: daily quests and playtime gifts. See the "Экономика" section of
-- the README for the full source / sink balance and target rates.

local Economy = {}

-- Three quests are picked per player per day from this pool. Shard rewards
-- scale with level so quests stay worth doing (Shards * (1 + Level / 25)).
Economy.QuestPool = {
	{ Id = "Mobs", Kind = "MobKill", Goal = 30, Text = "Defeat %d mobs", Reward = { Shards = 350 } },
	{ Id = "MobsBig", Kind = "MobKill", Goal = 80, Text = "Defeat %d mobs", Reward = { Shards = 700, Spins = 1 } },
	{ Id = "Damage", Kind = "Damage", Goal = 8000, Text = "Deal %d damage", Reward = { Shards = 400 } },
	{ Id = "Boss", Kind = "BossKill", Goal = 1, Text = "Help defeat %d boss", Reward = { Spins = 2 } },
	{ Id = "Bosses", Kind = "BossKill", Goal = 3, Text = "Help defeat %d bosses", Reward = { Shards = 500, Spins = 3 } },
	{ Id = "Duels", Kind = "PvpKill", Goal = 3, Text = "Win %d duels in the Rift Arena", Reward = { Shards = 300, Spins = 1 } },
	{ Id = "Rolls", Kind = "Roll", Goal = 5, Text = "Do %d Spirit Rolls", Reward = { Shards = 300 } },
	{ Id = "Mastery", Kind = "Mastery", Goal = 1500, Text = "Earn %d Art mastery XP", Reward = { Shards = 450 } },
	{ Id = "Ultimates", Kind = "Ultimate", Goal = 3, Text = "Unleash %d ultimates", Reward = { Spins = 1 } },
}
Economy.QuestsPerDay = 3
Economy.AllQuestsBonus = { Spins = 3 }
Economy.QuestShardLevelScale = 25

-- Playtime gifts per session (minutes online -> reward). Encourages longer
-- sessions in a 12-player server without being farmable by idling forever.
Economy.PlaytimeGifts = {
	{ Minutes = 5, Reward = { Shards = 150 } },
	{ Minutes = 15, Reward = { Spins = 1 } },
	{ Minutes = 30, Reward = { Shards = 400 } },
	{ Minutes = 45, Reward = { Spins = 2 } },
	{ Minutes = 60, Reward = { Shards = 800, Spins = 2 } },
}

function Economy.DayNumber(): number
	return math.floor(os.time() / 86400)
end

-- Deterministic daily pick per player (same 3 quests all day, new set tomorrow).
function Economy.PickQuests(userId: number, day: number)
	local rng = Random.new(day * 7919 + userId % 100003)
	local pool = table.clone(Economy.QuestPool)
	local picked = {}
	local usedKinds = {}
	while #picked < Economy.QuestsPerDay and #pool > 0 do
		local i = rng:NextInteger(1, #pool)
		local q = table.remove(pool, i)
		if not usedKinds[q.Kind] then
			usedKinds[q.Kind] = true
			table.insert(picked, q.Id)
		end
	end
	return picked
end

function Economy.GetQuest(id: string)
	for _, q in Economy.QuestPool do
		if q.Id == id then
			return q
		end
	end
	return nil
end

function Economy.DescribeReward(reward, level: number?): string
	local parts = {}
	if reward.Shards then
		local shards = math.floor(reward.Shards * (1 + (level or 1) / Economy.QuestShardLevelScale))
		table.insert(parts, ("%d Shards"):format(shards))
	end
	if reward.Spins then
		table.insert(parts, ("%d Spin%s"):format(reward.Spins, if reward.Spins > 1 then "s" else ""))
	end
	return table.concat(parts, " + ")
end

return Economy
