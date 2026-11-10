-- TravelManager: телепорт на базу (3 сек каста), перелёты между биомами, порталы,
-- выбор наименее загруженного дроп-пода (ТЗ 1.2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local BiomesData = require(Configs.BiomesData)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local WorldBuilder = require(script.Parent.WorldBuilder)

local Travel = {}
local casts = {}
local recentPod = {} -- [biome][podIndex] = os.clock() последнего назначения
local portalDebounce = {}

local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char
end

local function moveTo(player, cf)
	local root, char = rootOf(player)
	if not root then
		return
	end
	char:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	Net.Get("SystemAlert"):FireClient(player, "Teleported", {})
end

function Travel.ToHub(player)
	local data = DataManager.Get(player)
	local b = data and data.CurrentBiome or 1
	local pts = WorldBuilder.Points[b]
	if not pts then
		return
	end
	local off = Vector3.new(math.random(-6, 6), 0, math.random(-4, 4))
	moveTo(player, pts.Hub + off)
end

function Travel.ToPod(player, b)
	local pts = WorldBuilder.Points[b]
	if not pts then
		return
	end
	recentPod[b] = recentPod[b] or {}
	local best, bestScore = 1, math.huge
	for i, cf in ipairs(pts.Pods) do
		local score = 0
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local r = rootOf(other)
				if r and (r.Position - cf.Position).Magnitude < 16 then
					score = score + 1
				end
			end
		end
		if recentPod[b][i] and os.clock() - recentPod[b][i] < 4 then
			score = score + 0.5
		end
		score = score + i * 0.001
		if score < bestScore then
			best, bestScore = i, score
		end
	end
	recentPod[b][best] = os.clock()
	moveTo(player, pts.Pods[best])
end

function Travel.GoToBiome(player, b, toPod)
	local data = DataManager.Get(player)
	if not data or b < 1 or b > #BiomesData or b > data.UnlockedBiome then
		return false
	end
	data.CurrentBiome = b
	StateSync.MarkDirty(player)
	if toPod then
		Travel.ToPod(player, b)
	else
		Travel.ToHub(player)
	end
	return true
end

function Travel.Init()
	Net.Get("Travel").OnServerInvoke = function(player, b, where)
		if type(b) ~= "number" then
			return { ok = false }
		end
		local data = DataManager.Get(player)
		if not data then
			return { ok = false }
		end
		if b > data.UnlockedBiome then
			return { ok = false, msg = "Сначала доберись до дна предыдущего яруса" }
		end
		Travel.GoToBiome(player, b, where ~= "Hub")
		return { ok = true }
	end

	-- Телепорт на базу: мгновенный, не чаще раза в секунду
	Net.Get("TeleportBase").OnServerEvent:Connect(function(player, phase)
		local root = rootOf(player)
		if not root then
			return
		end
		if phase == "now" then
			local last = casts[player]
			if last and last.now and os.clock() - last.now < 1 then
				return
			end
			casts[player] = { now = os.clock() }
			Travel.ToHub(player)
		elseif phase == "start" then
			casts[player] = { t = os.clock(), pos = root.Position }
		elseif phase == "cancel" then
			casts[player] = nil
		elseif phase == "finish" then
			local c = casts[player]
			casts[player] = nil
			if not c then
				return
			end
			if os.clock() - c.t < Balance.TeleportCastTime - 0.35 then
				return
			end
			if (root.Position - c.pos).Magnitude > 4 then
				Notifier.Toast(player, "Телепорт прерван — нельзя двигаться во время каста", "warn", "Error")
				return
			end
			Travel.ToHub(player)
		end
	end)

	-- Порталы между биомами
	for b, pts in pairs(WorldBuilder.Points) do
		for target, disc in pairs(pts.Portals or {}) do
			disc.Touched:Connect(function(hit)
				local char = hit.Parent
				local player = char and Players:GetPlayerFromCharacter(char)
				if not player then
					return
				end
				if portalDebounce[player] and os.clock() - portalDebounce[player] < 2 then
					return
				end
				portalDebounce[player] = os.clock()
				local data = DataManager.Get(player)
				if not data then
					return
				end
				if target > data.UnlockedBiome then
					Notifier.Toast(player, "Шлюз закрыт: доберись до дна яруса «" .. BiomesData[target - 1].Name .. "»", "warn", "Error")
					return
				end
				Travel.GoToBiome(player, target, false)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(p)
		casts[p] = nil
		portalDebounce[p] = nil
	end)
end

return Travel
