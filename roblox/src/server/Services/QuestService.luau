-- Quests: a story chain (one active, the next unlocks on completion, then
-- endless bounties), daily / weekly / monthly quest sets with completion
-- bonuses, and per-session playtime gifts. Everything is auto-claimed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Potions = require(Shared.Config.Potions)
local Prog = require(Shared.Config.Progression)
local Remotes = require(Shared.Remotes)

local QuestService = {}

local session = {} :: { [Player]: { Start: number, Claimed: { [number]: boolean } } }

local potionNames = {}
for id, potion in Potions.List do
	potionNames[id] = potion.Name
end

local function data(self, player: Player)
	local profile = self.Services.DataService:Get(player)
	return profile and profile.Data
end

-- Current value for "reach X" style quests.
local function currentValue(d, kind: string): number
	if kind == "Level" then
		return d.Level
	elseif kind == "MasteryLevel" then
		local best = 1
		for styleId in d.OwnedStyles do
			best = math.max(best, (Prog.GetMastery(d, styleId)))
		end
		return best
	end
	return 0
end

function QuestService:Init(services)
	self.Services = services
	services.DataService:OnLoaded(function(player, profile)
		self:EnsurePeriods(profile.Data, player.UserId)
		session[player] = { Start = os.clock(), Claimed = {} }
		self:UpdateGiftAttributes(player)
		task.defer(function()
			self:CheckChain(player)
		end)
	end)
end

function QuestService:EnsurePeriods(d, userId: number): boolean
	local changed = false
	for _, kind in Economy.PeriodOrder do
		local entry = d.Quests[kind]
		local period = Economy.PeriodNumber(kind)
		if entry.Period ~= period or #entry.List == 0 then
			entry.Period = period
			entry.Bonus = false
			entry.List = {}
			for _, id in Economy.Pick(kind, userId, period) do
				table.insert(entry.List, { Id = id, Progress = 0, Done = false })
			end
			changed = true
		end
	end
	return changed
end

function QuestService:Grant(player: Player, reward)
	local d = data(self, player)
	if not d then
		return
	end
	local shards = if reward.Shards then Economy.ScaledShards(reward.Shards, d.Level) else nil
	self.Services.ProgressionService:Grant(player, { Shards = shards, Spins = reward.Spins })
	for id, count in reward.Potions or {} do
		self.Services.InventoryService:AddPotion(player, id, count)
	end
end

local function matches(quest, kind: string, zone: string?): boolean
	return quest.Kind == kind and (quest.Zone == nil or quest.Zone == zone)
end

local function advance(entry, quest, kind: string, amount: number)
	if Economy.SetKinds[kind] then
		entry.Progress = math.max(entry.Progress, math.min(quest.Goal, amount))
	else
		entry.Progress = math.min(quest.Goal, entry.Progress + amount)
	end
	return entry.Progress >= quest.Goal
end

-- Completes as many chain steps as are already satisfied.
function QuestService:CheckChain(player: Player)
	local d = data(self, player)
	if not d then
		return
	end
	local chain = d.Quests.Chain
	for _ = 1, 25 do
		local quest = Economy.ChainQuest(chain.Step)
		if Economy.SetKinds[quest.Kind] then
			chain.Progress = math.max(chain.Progress, math.min(quest.Goal, currentValue(d, quest.Kind)))
		end
		if chain.Progress < quest.Goal then
			break
		end
		self:Grant(player, quest.Reward)
		Remotes.Notify:FireClient(player, ("STORY COMPLETE: %s  •  %s"):format(quest.Text:format(quest.Goal), Economy.DescribeReward(quest.Reward, d.Level, potionNames)), "level")
		chain.Step += 1
		chain.Progress = 0
	end
	self.Services.DataService:Sync(player)
end

function QuestService:Progress(player: Player, kind: string, amount: number, zone: string?)
	local d = data(self, player)
	if not d or amount <= 0 then
		return
	end
	self:EnsurePeriods(d, player.UserId)
	local changed = false

	-- Story chain.
	local chain = d.Quests.Chain
	local chainQuest = Economy.ChainQuest(chain.Step)
	if matches(chainQuest, kind, zone) then
		changed = true
		if advance(chain, chainQuest, kind, amount) then
			self:CheckChain(player)
		end
	end

	-- Daily / weekly / monthly.
	for _, periodKind in Economy.PeriodOrder do
		local set = d.Quests[periodKind]
		for _, entry in set.List do
			local quest = Economy.GetQuest(entry.Id)
			if quest and not entry.Done and matches(quest, kind, zone) then
				changed = true
				if advance(entry, quest, kind, amount) then
					entry.Done = true
					self:Grant(player, quest.Reward)
					Remotes.Notify:FireClient(player, ("%s QUEST DONE: %s  •  %s"):format(string.upper(periodKind), quest.Text:format(quest.Goal), Economy.DescribeReward(quest.Reward, d.Level, potionNames)), "level")
				end
			end
		end
		if not set.Bonus and #set.List > 0 then
			local all = true
			for _, entry in set.List do
				all = all and entry.Done
			end
			if all then
				set.Bonus = true
				local bonus = Economy.Periods[periodKind].Bonus
				self:Grant(player, bonus)
				Remotes.Notify:FireClient(player, ("ALL %s QUESTS DONE!  Bonus: %s"):format(string.upper(periodKind), Economy.DescribeReward(bonus, d.Level, potionNames)), "level")
			end
		end
	end

	if changed then
		self.Services.DataService:Sync(player)
	end
end

function QuestService:UpdateGiftAttributes(player: Player)
	local s = session[player]
	if not s then
		return
	end
	local elapsed = os.clock() - s.Start
	for i, gift in Economy.PlaytimeGifts do
		if not s.Claimed[i] then
			player:SetAttribute("NextGiftAt", workspace:GetServerTimeNow() + math.max(0, gift.Minutes * 60 - elapsed))
			player:SetAttribute("NextGiftText", Economy.DescribeReward(gift.Reward, nil, potionNames))
			return
		end
	end
	player:SetAttribute("NextGiftAt", nil)
	player:SetAttribute("NextGiftText", nil)
end

function QuestService:Start()
	Players.PlayerRemoving:Connect(function(player)
		session[player] = nil
	end)
	local lastMinute = os.clock()
	while true do
		task.wait(10)
		local minuteTick = os.clock() - lastMinute >= 60
		if minuteTick then
			lastMinute = os.clock()
		end
		for player, s in session do
			if player.Parent then
				local minutes = (os.clock() - s.Start) / 60
				for i, gift in Economy.PlaytimeGifts do
					if not s.Claimed[i] and minutes >= gift.Minutes then
						s.Claimed[i] = true
						self:Grant(player, gift.Reward)
						Remotes.Notify:FireClient(player, ("PLAYTIME GIFT (%d min): %s"):format(gift.Minutes, Economy.DescribeReward(gift.Reward, nil, potionNames)), "success")
						self:UpdateGiftAttributes(player)
					end
				end
				if minuteTick then
					self:Progress(player, "Playtime", 1)
				end
				-- Period rollover while online.
				local d = data(self, player)
				if d and self:EnsurePeriods(d, player.UserId) then
					self.Services.DataService:Sync(player)
				end
			end
		end
	end
end

return QuestService
