-- Spirit Roll: spins / shards -> random Art, with luck, pity and duplicate
-- refunds. Also handles equipping owned Arts.

local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Gacha)
local Styles = require(Shared.Config.Styles)
local Gacha = require(Shared.Gacha)
local Remotes = require(Shared.Remotes)

local GachaService = {}

local GLOBAL_TOPIC = "RiftGlobalPulls"
local EQUIP_COOLDOWN = 2

local rng = Random.new()
local lastRoll = {} :: { [Player]: number }
local lastEquip = {} :: { [Player]: number }

local function fail(message: string)
	return { Ok = false, Error = message }
end

function GachaService:Init(services)
	self.Services = services
end

function GachaService:Roll(player: Player, count: number)
	count = if count == 10 then 10 else 1
	local Monetization = self.Services.MonetizationService

	if count == 10 and not Monetization:HasPass(player, "QuickRoll") then
		return fail("x10 rolls need the Quick Roll pass.")
	end
	local t = os.clock()
	if t - (lastRoll[player] or 0) < Config.MinRollInterval then
		return fail("Slow down!")
	end
	lastRoll[player] = t

	local profile = self.Services.DataService:Get(player)
	if not profile then
		return fail("Data is still loading.")
	end
	local data = profile.Data

	local affordable = data.Spins + math.floor(data.Shards / Config.RollCostShards)
	if affordable < count then
		return fail(("Not enough spins. Each roll costs 1 Spin or %d Shards."):format(Config.RollCostShards))
	end
	for _ = 1, count do
		if data.Spins > 0 then
			data.Spins -= 1
		else
			data.Shards -= Config.RollCostShards
		end
	end

	local luck = Monetization:GetLuck(player)
	local results = {}
	for _ = 1, count do
		data.TotalRolls += 1
		data.RollsSincePity += 1
		local minIndex = if data.RollsSincePity >= Config.PityRolls then Config.PityMinIndex else 1
		local rarityIndex = Gacha.RollRarity(rng, luck, minIndex)
		if rarityIndex >= Config.PityMinIndex then
			data.RollsSincePity = 0
		end

		local rarity = Config.Rarities[rarityIndex]
		local styleId = Gacha.RollStyle(rng, rarityIndex)
		local isNew = not data.OwnedStyles[styleId]
		local refund = 0
		if isNew then
			data.OwnedStyles[styleId] = true
		else
			refund = rarity.DupeShards
			data.Shards += refund
		end
		table.insert(results, { Style = styleId, Rarity = rarity.Id, New = isNew, Refund = refund })

		if rarityIndex >= Config.AnnounceFromIndex then
			Monetization:Announce(("%s pulled %s %s!"):format(player.DisplayName, rarity.Id:upper(), Styles.Get(styleId).Name))
		end
		if rarityIndex >= Config.GlobalAnnounceFromIndex then
			task.spawn(pcall, MessagingService.PublishAsync, MessagingService, GLOBAL_TOPIC, {
				Name = player.DisplayName,
				Style = styleId,
				JobId = game.JobId,
			})
		end
	end

	self.Services.DataService:Sync(player)
	return { Ok = true, Results = results, Luck = luck }
end

function GachaService:Equip(player: Player, styleId)
	if type(styleId) ~= "string" or not Styles.Get(styleId) then
		return fail("Unknown Art.")
	end
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return fail("Data is still loading.")
	end
	if not profile.Data.OwnedStyles[styleId] then
		return fail("You don't own this Art.")
	end
	if profile.Data.EquippedStyle == styleId then
		return { Ok = true }
	end
	if self.Services.CombatService:InCombat(player) then
		return fail("Can't switch Arts mid-fight.")
	end
	local t = os.clock()
	if t - (lastEquip[player] or 0) < EQUIP_COOLDOWN then
		return fail("Wait a moment before switching again.")
	end
	lastEquip[player] = t

	profile.Data.EquippedStyle = styleId
	player:SetAttribute("Awakening", 0) -- no swapping to a stronger ult with a full bar
	self.Services.DataService:Sync(player)
	self.Services.ProgressionService:RefreshOverhead(player)
	self.Services.CombatService:ApplyStyleAttributes(player)
	return { Ok = true }
end

function GachaService:Start()
	Remotes.Roll.OnServerInvoke = function(player, count)
		return self:Roll(player, count)
	end
	Remotes.Equip.OnServerInvoke = function(player, styleId)
		return self:Equip(player, styleId)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
		lastEquip[player] = nil
	end)

	-- Cross-server hype: everyone hears about Mythic pulls.
	pcall(function()
		MessagingService:SubscribeAsync(GLOBAL_TOPIC, function(message)
			local d = message.Data
			if type(d) ~= "table" or d.JobId == game.JobId then
				return
			end
			local style = Styles.Get(d.Style)
			if style and type(d.Name) == "string" then
				self.Services.MonetizationService:Announce(("[GLOBAL] %s pulled MYTHIC %s!"):format(d.Name, style.Name))
			end
		end)
	end)
end

return GachaService
