-- Potion inventory and timed buffs. Buff expiry is real time (os.time), so a
-- 15-minute potion lasts 15 minutes even across server hops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Potions = require(Shared.Config.Potions)
local Remotes = require(Shared.Remotes)

local InventoryService = {}

local lastUse = {} :: { [Player]: number }

local function data(self, player: Player)
	local profile = self.Services.DataService:Get(player)
	return profile and profile.Data
end

function InventoryService:Init(services)
	self.Services = services
end

function InventoryService:AddPotion(player: Player, id: string, count: number, silent: boolean?)
	local d = data(self, player)
	local potion = Potions.Get(id)
	if not d or not potion or count <= 0 then
		return
	end
	d.Inventory[id] = (d.Inventory[id] or 0) + count
	if not silent then
		Remotes.Notify:FireClient(player, ("+%d %s"):format(count, potion.Name), "success")
	end
	self.Services.DataService:Sync(player)
end

-- Active buff value for an effect, or nil.
function InventoryService:GetBuff(player: Player, effect: string): number?
	local d = data(self, player)
	if not d then
		return nil
	end
	local now = os.time()
	local best = nil
	for id, expires in d.Buffs do
		local potion = Potions.Get(id)
		if potion and potion.Effect == effect and expires > now then
			best = math.max(best or 0, potion.Value)
		end
	end
	return best
end

function InventoryService:Mult(player: Player, effect: string): number
	return self:GetBuff(player, effect) or 1
end

function InventoryService:Bonus(player: Player, effect: string): number
	return self:GetBuff(player, effect) or 0
end

function InventoryService:UsePotion(player: Player, id)
	local d = data(self, player)
	local potion = type(id) == "string" and Potions.Get(id)
	if not d or not potion then
		return { Ok = false, Error = "Неизвестное зелье." }
	end
	if (d.Inventory[id] or 0) <= 0 then
		return { Ok = false, Error = "У тебя нет этого зелья." }
	end
	local t = os.clock()
	if t - (lastUse[player] or 0) < 0.5 then
		return { Ok = false, Error = "Не так быстро!" }
	end
	lastUse[player] = t

	d.Inventory[id] -= 1
	if d.Inventory[id] <= 0 then
		d.Inventory[id] = nil
	end
	local now = os.time()
	local start = math.max(now, d.Buffs[id] or 0)
	d.Buffs[id] = math.min(now + Potions.MaxStackMinutes * 60, start + potion.Minutes * 60)

	if potion.Effect == "Speed" then
		self.Services.ProgressionService:ApplyCharacterStats(player)
	end
	Remotes.Fx:FireAllClients("Potion", { Character = player.Character, Color = potion.Color })
	self.Services.QuestService:Progress(player, "Potion", 1)
	self.Services.DataService:Sync(player)
	return { Ok = true }
end

function InventoryService:BuyPotion(player: Player, id, amount)
	local d = data(self, player)
	local potion = type(id) == "string" and Potions.Get(id)
	if not d or not potion then
		return { Ok = false, Error = "Неизвестное зелье." }
	end
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, 10)
	local cost = potion.Price * amount
	if d.Shards < cost then
		return { Ok = false, Error = ("Не хватает осколков (нужно %d ◆)."):format(cost) }
	end
	d.Shards -= cost
	self:AddPotion(player, id, amount, true)
	return { Ok = true }
end

-- Remaining seconds of each active buff, for the client.
function InventoryService:Snapshot(d)
	local now = os.time()
	local left = {}
	for id, expires in d.Buffs do
		if expires > now then
			left[id] = expires - now
		end
	end
	return left
end

function InventoryService:Start()
	Remotes.UsePotion.OnServerInvoke = function(player, id)
		return self:UsePotion(player, id)
	end
	Remotes.BuyPotion.OnServerInvoke = function(player, id, amount)
		return self:BuyPotion(player, id, amount)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)

	-- Expire buffs and refresh anything they affected.
	while true do
		task.wait(5)
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local d = data(self, player)
			if d then
				local expired, speedEnded = false, false
				for id, expires in d.Buffs do
					if expires <= now then
						d.Buffs[id] = nil
						expired = true
						local potion = Potions.Get(id)
						if potion and potion.Effect == "Speed" then
							speedEnded = true
						end
						if potion then
							Remotes.Notify:FireClient(player, "Закончилось действие: " .. potion.Name, "info")
						end
					end
				end
				if speedEnded then
					self.Services.ProgressionService:ApplyCharacterStats(player)
				end
				if expired then
					self.Services.DataService:Sync(player)
				end
			end
		end
	end
end

return InventoryService
