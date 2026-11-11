-- Daily quests (3 per player per day, auto-claimed) and per-session
-- playtime gifts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local QuestService = {}

local session = {} :: { [Player]: { Start: number, Claimed: { [number]: boolean } } }

local function data(self, player: Player)
	local profile = self.Services.DataService:Get(player)
	return profile and profile.Data
end

function QuestService:Init(services)
	self.Services = services
	services.DataService:OnLoaded(function(player, profile)
		self:EnsureToday(profile.Data, player.UserId)
		session[player] = { Start = os.clock(), Claimed = {} }
		self:UpdateGiftAttributes(player)
	end)
end

function QuestService:EnsureToday(d, userId: number)
	local today = Economy.DayNumber()
	if d.Quests.Day == today and #d.Quests.List > 0 then
		return false
	end
	d.Quests.Day = today
	d.Quests.Bonus = false
	d.Quests.List = {}
	for _, id in Economy.PickQuests(userId, today) do
		table.insert(d.Quests.List, { Id = id, Progress = 0, Done = false })
	end
	return true
end

function QuestService:Grant(player: Player, reward, scaleShards: boolean)
	local d = data(self, player)
	if not d then
		return
	end
	local shards = reward.Shards or 0
	if scaleShards and shards > 0 then
		shards = math.floor(shards * (1 + d.Level / Economy.QuestShardLevelScale))
	end
	self.Services.ProgressionService:Grant(player, { Shards = if shards > 0 then shards else nil, Spins = reward.Spins })
end

function QuestService:Progress(player: Player, kind: string, amount: number)
	local d = data(self, player)
	if not d or amount <= 0 then
		return
	end
	if self:EnsureToday(d, player.UserId) then
		self.Services.DataService:Sync(player)
	end
	local changed = false
	for _, entry in d.Quests.List do
		local quest = Economy.GetQuest(entry.Id)
		if quest and quest.Kind == kind and not entry.Done then
			entry.Progress = math.min(quest.Goal, entry.Progress + amount)
			changed = true
			if entry.Progress >= quest.Goal then
				entry.Done = true
				self:Grant(player, quest.Reward, true)
				Remotes.Notify:FireClient(player, ("QUEST COMPLETE: %s  •  %s"):format(quest.Text:format(quest.Goal), Economy.DescribeReward(quest.Reward, d.Level)), "level")
			end
		end
	end
	if not changed then
		return
	end
	local allDone = true
	for _, entry in d.Quests.List do
		allDone = allDone and entry.Done
	end
	if allDone and not d.Quests.Bonus then
		d.Quests.Bonus = true
		self:Grant(player, Economy.AllQuestsBonus, false)
		Remotes.Notify:FireClient(player, "ALL DAILY QUESTS DONE!  Bonus: " .. Economy.DescribeReward(Economy.AllQuestsBonus), "level")
	end
	self.Services.DataService:Sync(player)
end

function QuestService:UpdateGiftAttributes(player: Player)
	local s = session[player]
	if not s then
		return
	end
	local elapsed = os.clock() - s.Start
	for i, gift in Economy.PlaytimeGifts do
		if not s.Claimed[i] then
			local remaining = gift.Minutes * 60 - elapsed
			player:SetAttribute("NextGiftAt", workspace:GetServerTimeNow() + math.max(0, remaining))
			player:SetAttribute("NextGiftText", Economy.DescribeReward(gift.Reward))
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
	while true do
		task.wait(10)
		for player, s in session do
			if player.Parent then
				local minutes = (os.clock() - s.Start) / 60
				for i, gift in Economy.PlaytimeGifts do
					if not s.Claimed[i] and minutes >= gift.Minutes then
						s.Claimed[i] = true
						self:Grant(player, gift.Reward, false)
						Remotes.Notify:FireClient(player, ("PLAYTIME GIFT (%d min): %s"):format(gift.Minutes, Economy.DescribeReward(gift.Reward)), "success")
						self:UpdateGiftAttributes(player)
					end
				end
				-- New day while online: refresh quests.
				local d = data(self, player)
				if d and self:EnsureToday(d, player.UserId) then
					self.Services.DataService:Sync(player)
				end
			end
		end
	end
end

return QuestService
