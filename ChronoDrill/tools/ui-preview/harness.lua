-- shared setup for scenarios
local RS = game:GetService("ReplicatedStorage")
R.mountTree(RS, SRC_ROOT .. "/ReplicatedStorage")
local lp = game:GetService("Players").LocalPlayer
local PS = lp:FindFirstChild("PlayerScripts")
R.mountTree(PS, SRC_ROOT .. "/StarterPlayer/StarterPlayerScripts")
H = {}
H.PS = PS
H.lp = lp
H.UIF = PS:FindFirstChild("UI")
H.CF = PS:FindFirstChild("Controllers")
if ICON_ID then
	local cfg = require(RS.Configs.IconAtlas)
	cfg.Id = ICON_ID
end
H.ClientState = require(H.CF.ClientState)
H.Data = {
	Coins = 1234567, TotalCoins = 9e7, Shards = 12, CurrentBiome = 1, Passes = { VIP = true, Lucky = true },
	Ore = { Count = 85, Value = 4200 },
	Derived = { Damage = 3450, PetSum = 1.6, SellMult = 2, Capacity = 180, CoinFactor = 1.6, RebirthMult = 1, HitInterval = 0.25 },
	Daily = { Last = 0 }, WheelLast = 0, ActiveBoosts = { CoinElixir = 300, LuckyCharm = 90 },
	Pets = {}, Inventory = {}, Stats = {},
}
H.ClientState.Data = H.Data
H.ClientState.ReceivedAt = 0
function H.screen(name, order)
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.DisplayOrder = order or 1
	g.Parent = lp.PlayerGui
	return g
end
function H.out()
	OUTPUT = R.serialize(lp.PlayerGui)
end

-- realistic profile for windows
function H.profile()
	local SSS = game:GetService("ServerScriptService")
	if not SSS:FindFirstChild("Core") then R.mountTree(SSS, SRC_ROOT .. "/ServerScriptService") end
	local DM = require(SSS.Core.DataManager)
	local Stats = require(RS.Shared.Stats)
	local PetsData = require(RS.Configs.PetsData)
	local d = DM.Template()
	d.Coins = 1234567
	d.TotalCoins = 9e7
	d.Shards = 12
	local list = {}
	for id, p in pairs(PetsData.ById) do if not p.Special then table.insert(list, p) end end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	local n = 0
	for i, p in ipairs(list) do
		if i % 7 == 1 and n < 14 then
			n = n + 1
			local uid = "p" .. n
			d.Pets[uid] = { Id = p.Id, E = n <= 3, B = p.P or 1.2, T = (n % 5 == 0) and 2 or (n % 4 == 0 and 1 or 0), L = (n * 3) % 20 + 1, X = 0 }
			d.Index[p.Id] = true
		end
	end
	d.NextPetUid = n + 1
	d.Passes = { VIP = true }
	d.Ore = { Count = 85, Value = 4200 }
	d.Derived = {
		Damage = Stats.Damage(d), PetSum = Stats.PetSum(d), Capacity = Stats.Capacity(d), SellMult = Stats.SellMult(d, 1),
		CoinFactor = Stats.PetCoinFactor(d), RebirthMult = Stats.RebirthMult(d), PetSlots = Stats.PetSlots(d), IncubatorSlots = 2,
		HitInterval = Stats.HitInterval(d), RebirthCost = Stats.RebirthCost(d), RebirthShards = Stats.RebirthShards(d), CanRebirth = false,
		SessionEggs = 0, ServerTime = os.time(),
	}
	H.ClientState.Data = d
	H.Data = d
	return d
end
function H.ctx()
	local ctx = {}
	ctx.ClientState = H.ClientState
	ctx.Sound = { Play = function() end }
	ctx.Settings = require(H.CF.SettingsController)
	ctx.PlayerGui = H.lp.PlayerGui
	ctx.PetModel = function() local m = Instance.new("Model") return m end
	ctx.Toast = function() end
	ctx.PlayEgg = function() end
	ctx.ShowHatch = function() end
	ctx.RegisterScale = function() end
	return ctx
end
