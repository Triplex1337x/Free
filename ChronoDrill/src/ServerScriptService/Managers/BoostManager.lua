-- BoostManager: инвентарь бустов (ТЗ 7.1). Время активных бустов тикает, пока игрок онлайн.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local BoostsData = require(Configs.BoostsData)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local Incubator = require(script.Parent.IncubatorManager)
local PetManager = require(script.Parent.PetManager)
local QuestService = require(script.Parent.QuestService)

local BoostManager = {}

local function use(player, id, slot)
	local data = DataManager.Get(player)
	local def = BoostsData.ById[id]
	if not data or not def then
		return { ok = false }
	end
	if (data.Boosts[id] or 0) <= 0 then
		return { ok = false, msg = "Нет такого буста" }
	end
	if def.Instant then
		local res = Incubator.Fertilize(player, data, type(slot) == "number" and slot or nil)
		if res and res.ok then
			QuestService.Track(player, "UseBoosts", 1)
		end
		return res
	end
	data.Boosts[id] = data.Boosts[id] - 1
	data.ActiveBoosts[id] = (data.ActiveBoosts[id] or 0) + def.Duration
	Notifier.Toast(player, def.Name .. " активирован!", "good", "Unlock")
	QuestService.Track(player, "UseBoosts", 1)
	PetManager.RefreshAttribute(player)
	StateSync.MarkDirty(player)
	return { ok = true }
end

function BoostManager.Init()
	Net.Get("UseBoost").OnServerInvoke = function(player, id, slot)
		return use(player, id, slot)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataManager.Get(player)
				if data then
					for id, t in pairs(data.ActiveBoosts) do
						if t > 0 then
							data.ActiveBoosts[id] = t - 1
							if t - 1 <= 0 then
								data.ActiveBoosts[id] = 0
								local def = BoostsData.ById[id]
								Notifier.Toast(player, (def and def.Name or id) .. " закончился", "info")
								StateSync.MarkDirty(player)
							end
						end
					end
					data.Stats.PlayTime = data.Stats.PlayTime + 1
				end
			end
		end
	end)
end

return BoostManager
