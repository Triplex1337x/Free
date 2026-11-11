-- Game passes, developer products (ProcessReceipt), server luck and
-- regional policy checks for paid random items.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Monetization)
local Remotes = require(Shared.Remotes)

local MonetizationService = {}
MonetizationService.OwnedPasses = {} :: { [Player]: { [string]: boolean } }

local productsById = {}
for key, product in Config.Products do
	if product.Id ~= 0 then
		productsById[product.Id] = { Key = key, Product = product }
	end
end
local passesById = {}
for key, pass in Config.GamePasses do
	if pass.Id ~= 0 then
		passesById[pass.Id] = key
	end
end

local function now()
	return workspace:GetServerTimeNow()
end

function MonetizationService:Init(services)
	self.Services = services
	workspace:SetAttribute("ServerLuckUntil", 0)

	services.DataService:OnLoaded(function(player)
		self.OwnedPasses[player] = {}
		task.spawn(function()
			self:LoadPolicy(player)
			self:LoadPasses(player)
		end)
	end)
end

function MonetizationService:LoadPolicy(player: Player)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	-- If the check fails, assume restricted: safer for compliance.
	local restricted = not ok or info.ArePaidRandomItemsRestricted
	player:SetAttribute("PaidRandomRestricted", restricted)
end

function MonetizationService:LoadPasses(player: Player)
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				self:SetPass(player, key)
			end
		end
	end
end

function MonetizationService:SetPass(player: Player, key: string)
	local owned = self.OwnedPasses[player]
	if not owned or owned[key] then
		return
	end
	owned[key] = true
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		self.Services.ProgressionService:RefreshOverhead(player)
	end
end

function MonetizationService:HasPass(player: Player, key: string): boolean
	local owned = self.OwnedPasses[player]
	return owned ~= nil and owned[key] == true
end

function MonetizationService:IsServerLuckActive(): boolean
	return (workspace:GetAttribute("ServerLuckUntil") or 0) > now()
end

function MonetizationService:GetLuck(player: Player): number
	local luck = 1
	if self:HasPass(player, "VIP") then
		luck *= Config.VipLuckMultiplier
	end
	if self:HasPass(player, "Luck") then
		luck *= Config.LuckPassMultiplier
	end
	if self:IsServerLuckActive() then
		luck *= Config.ServerLuckMultiplier
	end
	luck *= self.Services.InventoryService:Mult(player, "Luck")
	return luck
end

function MonetizationService:Announce(text: string)
	Remotes.Announce:FireAllClients(text)
end

local function grant(self, player: Player, product)
	local data = self.Services.DataService:Get(player).Data
	local g = product.Grant
	if g.Spins then
		data.Spins += g.Spins
	end
	if g.Shards then
		data.Shards += g.Shards
	end
	if g.ServerLuckMinutes then
		local base = math.max(workspace:GetAttribute("ServerLuckUntil") or 0, now())
		workspace:SetAttribute("ServerLuckUntil", base + g.ServerLuckMinutes * 60)
		self:Announce(("%s включил удачу сервера x%d для всех! (+%d мин)"):format(
			player.DisplayName,
			Config.ServerLuckMultiplier,
			g.ServerLuckMinutes
		))
	end
end

local function processReceipt(self, info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local DataService = self.Services.DataService
	local profile = DataService:WaitForProfile(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if profile.Data.ProcessedReceipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local entry = productsById[info.ProductId]
	if not entry then
		warn("[Shop] Unknown product id " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(grant, self, player, entry.Product)
	if not ok then
		warn("[Shop] Grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	DataService:MarkReceipt(profile, info.PurchaseId)
	DataService:Sync(player)

	-- Only confirm once the grant is persisted. If the save fails, the receipt
	-- is already marked in memory, so a retry in this session won't double-grant.
	if not DataService:SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Remotes.Notify:FireClient(player, "Покупка завершена: " .. entry.Product.Name, "success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onBuy(self, player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	local kind, key = payload.Type, payload.Key
	if kind == "Pass" then
		local pass = Config.GamePasses[key]
		if not pass or pass.Id == 0 then
			Remotes.Notify:FireClient(player, "Этот пропуск пока недоступен.", "error")
			return
		end
		if self:HasPass(player, key) then
			Remotes.Notify:FireClient(player, "У тебя уже есть: " .. pass.Name, "info")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	elseif kind == "Product" then
		local product = Config.Products[key]
		if not product or product.Id == 0 then
			Remotes.Notify:FireClient(player, "Этот товар пока недоступен.", "error")
			return
		end
		if product.PaidRandom and player:GetAttribute("PaidRandomRestricted") ~= false then
			Remotes.Notify:FireClient(player, "Этот товар недоступен в твоём регионе.", "error")
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end
end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = function(info)
		return processReceipt(self, info)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passesById[passId]
		if purchased and key then
			self:SetPass(player, key)
			Remotes.Notify:FireClient(player, "Открыто: " .. Config.GamePasses[key].Name .. "!", "success")
			self.Services.DataService:Sync(player)
		end
	end)

	Remotes.Action.OnServerEvent:Connect(function(player, action, payload)
		if action == "Buy" then
			onBuy(self, player, payload)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.OwnedPasses[player] = nil
	end)
end

return MonetizationService
