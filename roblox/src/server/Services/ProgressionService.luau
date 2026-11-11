-- Levels, XP, stat points, Art mastery, Shards, leaderstats, overhead name
-- tags and the daily login streak.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Styles = require(Shared.Config.Styles)
local Gacha = require(Shared.Gacha)
local MonetizationConfig = require(Shared.Config.Monetization)
local Prog = require(Shared.Config.Progression)
local Remotes = require(Shared.Remotes)

local ProgressionService = {}

function ProgressionService:Init(services)
	self.Services = services

	services.DataService:OnLoaded(function(player, profile)
		self:RecountStatPoints(profile.Data)
		self:CreateLeaderstats(player, profile)
		self:CheckDaily(player, profile)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			character:WaitForChild("Head", 5)
			self:ApplyCharacterStats(player, character)
			self:RefreshOverhead(player)
		end)
	end)

	services.DataService.OnSynced = function(player)
		self:UpdateLeaderstats(player)
	end
end

local function data(self, player: Player)
	local profile = self.Services.DataService:Get(player)
	return profile and profile.Data
end

function ProgressionService:CreateLeaderstats(player: Player, profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = profile.Data.Level
	level.Parent = stats
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = profile.Data.Kills
	kills.Parent = stats
	stats.Parent = player
end

function ProgressionService:UpdateLeaderstats(player: Player)
	local d = data(self, player)
	local stats = player:FindFirstChild("leaderstats")
	if not d or not stats then
		return
	end
	stats.Level.Value = d.Level
	stats.Kills.Value = d.Kills
end

function ProgressionService:GetLevel(player: Player): number
	local d = data(self, player)
	return d and d.Level or 1
end

-- Stat points = earned from levels minus spent. Recomputed on load so the
-- numbers can never drift (and old saves get their points retroactively).
function ProgressionService:RecountStatPoints(d)
	local spent = 0
	for _, stat in Prog.Stats do
		d.Stats[stat.Id] = math.max(0, math.floor(d.Stats[stat.Id] or 0))
		spent += d.Stats[stat.Id]
	end
	local earned = (d.Level - 1) * Prog.PointsPerLevel
	if spent > earned then
		for _, stat in Prog.Stats do
			d.Stats[stat.Id] = 0
		end
		spent = 0
	end
	d.StatPoints = earned - spent
end

function ProgressionService:GetStat(player: Player, id: string): number
	local d = data(self, player)
	return d and d.Stats[id] or 0
end

function ProgressionService:GetMaxHealth(player: Player): number
	return GameConfig.Level.BaseHealth
		+ (self:GetLevel(player) - 1) * GameConfig.Level.HealthPerLevel
		+ self:GetStat(player, "Vitality") * Prog.VitalityHealth
end

function ProgressionService:GetMasteryLevel(player: Player, styleId: string?): number
	local d = data(self, player)
	if not d then
		return 1
	end
	return (Prog.GetMastery(d, styleId or d.EquippedStyle))
end

function ProgressionService:GetDamageMultiplier(player: Player?): number
	if not player then
		return 1
	end
	local d = data(self, player)
	if not d then
		return 1
	end
	return 1
		+ (d.Level - 1) * GameConfig.Level.DamagePerLevel
		+ (d.Stats.Strength or 0) * Prog.StrengthDamage
		+ (self:GetMasteryLevel(player) - 1) * Prog.Mastery.DamagePerLevel
end

function ProgressionService:GetCooldownMultiplier(player: Player): number
	local reduction = math.min(Prog.AgilityCooldownCap, self:GetStat(player, "Agility") * Prog.AgilityCooldown)
	return 1 - reduction
end

function ProgressionService:GetAwakeningMultiplier(player: Player): number
	return 1 + self:GetStat(player, "Spirit") * Prog.SpiritAwakening
end

function ProgressionService:GetSpeedBonus(player: Player): number
	return math.min(Prog.AgilitySpeedCap, self:GetStat(player, "Agility") * Prog.AgilitySpeed)
end

function ProgressionService:AllocateStat(player: Player, statId, amount)
	local d = data(self, player)
	if not d or type(statId) ~= "string" or d.Stats[statId] == nil then
		return { Ok = false, Error = "Unknown stat." }
	end
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, 1000)
	amount = math.min(amount, d.StatPoints)
	if amount <= 0 then
		return { Ok = false, Error = "No stat points left. Level up to earn more!" }
	end
	d.Stats[statId] += amount
	d.StatPoints -= amount
	self:ApplyCharacterStats(player)
	self.Services.DataService:Sync(player)
	return { Ok = true }
end

function ProgressionService:ResetStats(player: Player)
	local d = data(self, player)
	if not d then
		return { Ok = false, Error = "Data is still loading." }
	end
	if d.Shards < Prog.ResetCostShards then
		return { Ok = false, Error = ("Resetting stats costs %d Shards."):format(Prog.ResetCostShards) }
	end
	d.Shards -= Prog.ResetCostShards
	for _, stat in Prog.Stats do
		d.Stats[stat.Id] = 0
	end
	self:RecountStatPoints(d)
	self:ApplyCharacterStats(player)
	self.Services.DataService:Sync(player)
	return { Ok = true }
end

-- Adds mastery XP to the equipped Art and announces newly unlocked skills.
function ProgressionService:AddMasteryXp(player: Player, amount: number)
	local d = data(self, player)
	if not d or amount <= 0 then
		return
	end
	local styleId = d.EquippedStyle
	local entry = d.Mastery[styleId]
	if not entry then
		entry = { Level = 1, Xp = 0 }
		d.Mastery[styleId] = entry
	end
	if entry.Level >= Prog.Mastery.MaxLevel then
		return
	end
	entry.Xp += math.floor(amount + 0.5)
	self.Services.QuestService:Progress(player, "Mastery", amount)
	local style = Styles.Get(styleId)
	while entry.Level < Prog.Mastery.MaxLevel and entry.Xp >= Prog.MasteryXpFor(entry.Level) do
		entry.Xp -= Prog.MasteryXpFor(entry.Level)
		entry.Level += 1
		local unlocked = nil
		for key, need in Prog.Mastery.Unlocks do
			if need == entry.Level then
				unlocked = Styles.GetAbility(styleId, key)
			end
		end
		if unlocked then
			Remotes.Notify:FireClient(player, ("%s Mastery %d — NEW SKILL: %s!"):format(style.Name, entry.Level, unlocked.Name), "level")
		else
			Remotes.Notify:FireClient(player, ("%s Mastery %d (+%d%% damage)"):format(style.Name, entry.Level, (entry.Level - 1)), "success")
		end
	end
	if entry.Level >= Prog.Mastery.MaxLevel then
		entry.Xp = 0
		Remotes.Notify:FireClient(player, style.Name .. " MASTERED!", "level")
	end
	self.Services.DataService:Sync(player)
end

function ProgressionService:ApplyCharacterStats(player: Player, character: Model?)
	character = character or player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local maxHealth = self:GetMaxHealth(player)
	local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth * math.clamp(ratio, 0, 1)
	character:SetAttribute("BaseSpeed", GameConfig.BaseWalkSpeed + self:GetSpeedBonus(player))
	self.Services.CombatService:UpdateMovement(character)
end

function ProgressionService:AddXp(player: Player, amount: number)
	local d = data(self, player)
	if not d or amount <= 0 then
		return
	end
	if self.Services.MonetizationService:HasPass(player, "DoubleXP") then
		amount *= 2
	end
	d.Xp += math.floor(amount + 0.5)

	local leveled = false
	while d.Level < GameConfig.Level.Max and d.Xp >= GameConfig.XpForLevel(d.Level) do
		d.Xp -= GameConfig.XpForLevel(d.Level)
		d.Level += 1
		d.StatPoints += Prog.PointsPerLevel
		leveled = true
	end
	if d.Level >= GameConfig.Level.Max then
		d.Xp = 0
	end

	if leveled then
		self:ApplyCharacterStats(player)
		self:RefreshOverhead(player)
		Remotes.Notify:FireClient(player, ("LEVEL UP! Lv. %d  •  +%d stat points"):format(d.Level, Prog.PointsPerLevel), "level")
		Remotes.Fx:FireAllClients("LevelUp", { Character = player.Character })
	end
	self.Services.DataService:Sync(player)
end

-- `earned` = from gameplay (VIP multiplier applies), not from purchases/codes.
function ProgressionService:AddShards(player: Player, amount: number, earned: boolean?)
	local d = data(self, player)
	if not d then
		return
	end
	if earned and self.Services.MonetizationService:HasPass(player, "VIP") then
		amount *= MonetizationConfig.VipShardMultiplier
	end
	d.Shards += math.floor(amount)
	self.Services.DataService:Sync(player)
end

function ProgressionService:Grant(player: Player, reward)
	local d = data(self, player)
	if not d then
		return
	end
	if reward.Shards then
		d.Shards += reward.Shards
	end
	if reward.Spins then
		d.Spins += reward.Spins
	end
	self.Services.DataService:Sync(player)
end

function ProgressionService:DescribeReward(reward): string
	local parts = {}
	if reward.Spins then
		table.insert(parts, reward.Spins .. " Spins")
	end
	if reward.Shards then
		table.insert(parts, reward.Shards .. " Shards")
	end
	return table.concat(parts, " + ")
end

function ProgressionService:CheckDaily(player: Player, profile)
	local d = profile.Data
	local elapsed = os.time() - d.LastDaily
	if elapsed < GameConfig.DailyCooldownHours * 3600 then
		return
	end
	if elapsed > GameConfig.DailyStreakResetHours * 3600 then
		d.DailyStreak = 1
	else
		d.DailyStreak += 1
	end
	d.LastDaily = os.time()
	local rewards = GameConfig.DailyRewards
	local reward = rewards[(d.DailyStreak - 1) % #rewards + 1]
	self:Grant(player, reward)
	task.delay(4, function()
		if player.Parent then
			Remotes.Notify:FireClient(
				player,
				("Daily reward — day %d: %s"):format(d.DailyStreak, self:DescribeReward(reward)),
				"success"
			)
		end
	end)
end

function ProgressionService:RefreshOverhead(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local d = data(self, player)
	if not head or not d then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local gui = head:FindFirstChild("Overhead")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Overhead"
		gui.Size = UDim2.fromOffset(220, 56)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 90
		gui.AlwaysOnTop = false

		local name = Instance.new("TextLabel")
		name.Name = "NameLabel"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0.55, 0)
		name.Font = Enum.Font.GothamBlack
		name.TextScaled = true
		name.TextStrokeTransparency = 0.4
		name.Parent = gui

		local sub = Instance.new("TextLabel")
		sub.Name = "SubLabel"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.55)
		sub.Size = UDim2.new(1, 0, 0.45, 0)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextStrokeTransparency = 0.5
		sub.Parent = gui

		gui.Parent = head
	end

	local vip = self.Services.MonetizationService:HasPass(player, "VIP")
	local style = Styles.Get(d.EquippedStyle)
	local rarity = Gacha.GetRarity(style.Rarity)

	gui.NameLabel.Text = (vip and "[VIP] " or "") .. player.DisplayName
	gui.NameLabel.TextColor3 = vip and Color3.fromRGB(255, 215, 60) or Color3.new(1, 1, 1)
	gui.SubLabel.Text = ("Lv. %d • %s"):format(d.Level, style.Name)
	gui.SubLabel.TextColor3 = rarity.Color
end

function ProgressionService:Start()
	Remotes.AllocateStat.OnServerInvoke = function(player, statId, amount)
		return self:AllocateStat(player, statId, amount)
	end
	Remotes.ResetStats.OnServerInvoke = function(player)
		return self:ResetStats(player)
	end
end

return ProgressionService
