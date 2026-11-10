-- Levels, XP, Shards, leaderstats, overhead name tags and daily login streak.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local Styles = require(Shared.Config.Styles)
local Gacha = require(Shared.Gacha)
local MonetizationConfig = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)

local ProgressionService = {}

function ProgressionService:Init(services)
	self.Services = services

	services.DataService:OnLoaded(function(player, profile)
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

function ProgressionService:GetMaxHealth(player: Player): number
	return GameConfig.Level.BaseHealth + (self:GetLevel(player) - 1) * GameConfig.Level.HealthPerLevel
end

function ProgressionService:GetDamageMultiplier(player: Player?): number
	if not player then
		return 1
	end
	return 1 + (self:GetLevel(player) - 1) * GameConfig.Level.DamagePerLevel
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
		leveled = true
	end
	if d.Level >= GameConfig.Level.Max then
		d.Xp = 0
	end

	if leveled then
		self:ApplyCharacterStats(player)
		self:RefreshOverhead(player)
		Remotes.Notify:FireClient(player, ("Level up! You are now Lv. %d"):format(d.Level), "level")
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

return ProgressionService
