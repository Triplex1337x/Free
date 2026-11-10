-- Promo code redemption.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Codes = require(Shared.Config.Codes)
local Remotes = require(Shared.Remotes)

local CodesService = {}

local lastAttempt = {} :: { [Player]: number }

function CodesService:Init(services)
	self.Services = services
end

function CodesService:Redeem(player: Player, raw)
	if type(raw) ~= "string" or #raw > 40 then
		return { Ok = false, Message = "Invalid code." }
	end
	local t = os.clock()
	if t - (lastAttempt[player] or 0) < 1 then
		return { Ok = false, Message = "Slow down!" }
	end
	lastAttempt[player] = t

	local code = raw:gsub("%s+", ""):upper()
	local reward = Codes[code]
	if not reward then
		return { Ok = false, Message = "That code doesn't exist." }
	end
	if reward.Expires and os.time() > reward.Expires then
		return { Ok = false, Message = "That code has expired." }
	end
	local profile = self.Services.DataService:Get(player)
	if not profile then
		return { Ok = false, Message = "Data is still loading." }
	end
	if profile.Data.RedeemedCodes[code] then
		return { Ok = false, Message = "You already used this code." }
	end

	profile.Data.RedeemedCodes[code] = os.time()
	local Progression = self.Services.ProgressionService
	Progression:Grant(player, reward)
	return { Ok = true, Message = "Redeemed: " .. Progression:DescribeReward(reward) }
end

function CodesService:Start()
	Remotes.RedeemCode.OnServerInvoke = function(player, code)
		return self:Redeem(player, code)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAttempt[player] = nil
	end)
end

return CodesService
