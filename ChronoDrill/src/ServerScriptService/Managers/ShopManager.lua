-- ShopManager: продажа руды в репликаторе (ТЗ 2.5), покупка буров/рюкзаков,
-- надевание моделей бура (в правую руку) и рюкзака (на спину).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local DrillsData = require(Configs.DrillsData)
local BackpacksData = require(Configs.BackpacksData)
local BiomesData = require(Configs.BiomesData)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local WorldBuilder = require(script.Parent.WorldBuilder)
local QuestService = require(script.Parent.QuestService)

local Shop = {}
local sellDebounce = {}

---------------------------------------------------------------------------------------------
-- Экипировка на персонаже
---------------------------------------------------------------------------------------------
local function prepGear(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.Anchored = false
		end
	end
end

function Shop.AttachGear(player)
	local data = DataManager.Get(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local assets = ReplicatedStorage:WaitForChild("Assets")
	for _, name in ipairs({ "EquippedDrill", "EquippedPack" }) do
		local old = char:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local back = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local drillSrc = assets.Drills:FindFirstChild(data.Drill)
	if hand and drillSrc then
		local d = drillSrc:Clone()
		d.Name = "EquippedDrill"
		prepGear(d)
		local grip = d.PrimaryPart
		local yOff = (hand.Name == "Right Arm") and -1.0 or -0.4
		d:PivotTo(hand.CFrame * CFrame.new(0, yOff, 0) * CFrame.Angles(math.rad(-90), 0, 0))
		local w = Instance.new("Weld")
		w.Name = "DrillGrip"
		w.Part0 = hand
		w.Part1 = grip
		w.C0 = CFrame.new(0, yOff, 0) * CFrame.Angles(math.rad(-90), 0, 0)
		w.Parent = grip
		d.Parent = char
		d:SetAttribute("DrillId", data.Drill)
	end
	local packSrc = assets.Backpacks:FindFirstChild(data.Backpack)
	if back and packSrc then
		local p = packSrc:Clone()
		p.Name = "EquippedPack"
		prepGear(p)
		local zOff = (back.Name == "Torso") and 0.55 or 0.5
		local c0 = CFrame.new(0, 0.1, zOff)
		p:PivotTo(back.CFrame * c0)
		local w = Instance.new("Weld")
		w.Name = "PackWeld"
		w.Part0 = back
		w.Part1 = p.PrimaryPart
		w.C0 = c0
		w.Parent = p.PrimaryPart
		p.Parent = char
	end
	player:SetAttribute("Drill", data.Drill)
end

---------------------------------------------------------------------------------------------
-- Продажа
---------------------------------------------------------------------------------------------
function Shop.Sell(player, forcedBiome)
	local data = DataManager.Get(player)
	if not data then
		return { ok = false }
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return { ok = false }
	end
	-- продаём в репликаторе того биома, где стоит игрок (автопродажа — по курсу текущего яруса)
	local sellBiome = forcedBiome
	if not sellBiome then
		for b, pts in pairs(WorldBuilder.Points) do
			if pts.Sell and (root.Position - pts.Sell).Magnitude < 30 then
				sellBiome = b
			end
		end
	end
	if not sellBiome then
		return { ok = false, msg = "Подойди к Репликатору продажи на базе" }
	end
	if data.Ore.Count <= 0 and data.Ore.Value <= 0 then
		return { ok = false, msg = "Рюкзак пуст" }
	end
	local wasFull = data.Ore.Count >= Stats.Capacity(data)
	local coins = math.floor(data.Ore.Value * Stats.SellMult(data, sellBiome))
	local sold = data.Ore.Count
	data.Ore.Count = 0
	data.Ore.Value = 0
	data.Coins = data.Coins + coins
	data.TotalCoins = data.TotalCoins + coins
	data.Stats.Sells = data.Stats.Sells + 1
	if wasFull then
		QuestService.Track(player, "SellFull", 1)
	end
	QuestService.Track(player, "SellCount", 1)
	QuestService.Track(player, "EarnCoins", coins)
	Notifier.Coins(player, coins, "sell")
	Notifier.Toast(player, "Продано " .. Util.Format(sold) .. " руды за " .. Util.Format(coins) .. " монет (x" .. string.format("%.2f", Stats.SellMult(data, sellBiome)) .. ")", "good", "Coins")
	StateSync.MarkDirty(player)
	return { ok = true, coins = coins }
end

---------------------------------------------------------------------------------------------
-- Покупки
---------------------------------------------------------------------------------------------
local function buy(player, kind, id)
	local data = DataManager.Get(player)
	if not data then
		return { ok = false }
	end
	local item, owned, field
	if kind == "Drill" then
		item = DrillsData.ById[id]
		owned = data.OwnedDrills
		field = "Drill"
	elseif kind == "Backpack" then
		item = BackpacksData.ById[id]
		owned = data.OwnedBackpacks
		field = "Backpack"
	end
	if not item then
		return { ok = false }
	end
	-- купить/надеть можно только в зоне у домика магазина
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local near = false
	for _, pts in pairs(WorldBuilder.Points) do
		local z = pts.ShopZones and pts.ShopZones[kind]
		if z and root and (root.Position - z.Position).Magnitude < 22 then
			near = true
		end
	end
	if not near then
		return { ok = false, msg = "Зайди в зону покупки у домика магазина" }
	end
	if owned[id] then
		data[field] = id
	else
		if item.Biome > data.UnlockedBiome then
			return { ok = false, msg = "Откроется в биоме «" .. BiomesData[item.Biome].Name .. "»" }
		end
		local st, need = Stats.ShopState(data, kind, item)
		if st == "locked" then
			return { ok = false, msg = "Сначала купи «" .. need.Name .. "»" }
		end
		if data.Coins < item.Price then
			return { ok = false, msg = "Не хватает " .. Util.Format(item.Price - data.Coins) .. " монет" }
		end
		data.Coins = data.Coins - item.Price
		owned[id] = true
		data[field] = id
		Notifier.Toast(player, "Куплено: " .. item.Name .. "!", "good", "Unlock")
	end
	Shop.AttachGear(player)
	StateSync.MarkDirty(player)
	return { ok = true }
end

function Shop.Init()
	Net.Get("SellBackpack").OnServerInvoke = function(player)
		return Shop.Sell(player)
	end
	Net.Get("BuyItem").OnServerInvoke = function(player, kind, id)
		return buy(player, kind, id)
	end
	Net.Get("EquipItem").OnServerInvoke = function(player, kind, id)
		return buy(player, kind, id)
	end
	-- зоны продажи: кто стоит в светящемся круге — продаёт руду автоматически
	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local data = DataManager.Get(player)
				if root and data and data.Ore.Count > 0 then
					for _, pts in pairs(WorldBuilder.Points) do
						local z = pts.Sell
						if z then
							local d = root.Position - z
							if Vector3.new(d.X, 0, d.Z).Magnitude <= 9.2 and math.abs(d.Y) < 10 then
								if not sellDebounce[player] or os.clock() - sellDebounce[player] > 1.2 then
									sellDebounce[player] = os.clock()
									Shop.Sell(player)
								end
								break
							end
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		sellDebounce[p] = nil
	end)
end

return Shop
