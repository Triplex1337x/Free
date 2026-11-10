-- Odds math shared by server (rolling) and client (odds display).

local Config = require(script.Parent.Config.Gacha)
local Styles = require(script.Parent.Config.Styles)

local Gacha = {}

local byRarity: { [string]: { string } } = {}
for _, id in Styles.Order do
	local rarity = Styles.List[id].Rarity
	byRarity[rarity] = byRarity[rarity] or {}
	table.insert(byRarity[rarity], id)
end
for _, rarity in Config.Rarities do
	assert(byRarity[rarity.Id] and #byRarity[rarity.Id] > 0, "No styles for rarity " .. rarity.Id)
end

function Gacha.StylesByRarity()
	return byRarity
end

function Gacha.RarityIndex(id: string): number
	for i, rarity in Config.Rarities do
		if rarity.Id == id then
			return i
		end
	end
	return 1
end

function Gacha.GetRarity(id: string)
	return Config.Rarities[Gacha.RarityIndex(id)]
end

local function weights(luck: number, minIndex: number)
	local list, total = {}, 0
	for i, rarity in Config.Rarities do
		local w = 0
		if i >= minIndex then
			w = rarity.Weight
			if i >= Config.LuckAffectsFromIndex then
				w *= luck
			end
		end
		list[i] = w
		total += w
	end
	return list, total
end

-- Probability (0..1) of each rarity for the given luck multiplier.
function Gacha.GetRarityOdds(luck: number): { number }
	local list, total = weights(luck, 1)
	local odds = {}
	for i, w in list do
		odds[i] = w / total
	end
	return odds
end

-- Probability (0..1) of each individual style.
function Gacha.GetStyleOdds(luck: number): { [string]: number }
	local rarityOdds = Gacha.GetRarityOdds(luck)
	local odds = {}
	for i, rarity in Config.Rarities do
		local pool = byRarity[rarity.Id]
		for _, id in pool do
			odds[id] = rarityOdds[i] / #pool
		end
	end
	return odds
end

function Gacha.RollRarity(rng: Random, luck: number, minIndex: number?): number
	local list, total = weights(luck, minIndex or 1)
	local pick = rng:NextNumber() * total
	for i, w in list do
		if pick < w then
			return i
		end
		pick -= w
	end
	return #list
end

function Gacha.RollStyle(rng: Random, rarityIndex: number): string
	local pool = byRarity[Config.Rarities[rarityIndex].Id]
	return pool[rng:NextInteger(1, #pool)]
end

return Gacha
