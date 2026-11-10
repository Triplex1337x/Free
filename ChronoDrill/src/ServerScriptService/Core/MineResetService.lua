-- MineResetService: 20-минутный цикл вайпа шахт (ТЗ 6).
-- Время следующего вайпа лежит в атрибуте workspace.MineResetAt (unix), клиент рисует таймер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)

local Notifier = require(script.Parent.Notifier)

local MineReset = {}

function MineReset.Start(Mining, Travel, DataManager)
	local function schedule()
		workspace:SetAttribute("MineResetAt", os.time() + Balance.ResetInterval)
	end

	local function startGoldRush()
		workspace:SetAttribute("GoldRushUntil", os.time() + Balance.GoldRushDuration)
		Notifier.AlertAll("GoldRush", { Duration = Balance.GoldRushDuration })
	end

	local function evacuate()
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root.Position.Y < 0 then
				local data = DataManager.Get(player)
				local b = data and data.CurrentBiome or 1
				Travel.ToPod(player, b)
			end
		end
	end

	task.spawn(function()
		-- первая генерация шахт при старте сервера
		workspace:SetAttribute("GoldRushUntil", os.time() + Balance.GoldRushDuration)
		Mining.ResetAll()
		schedule()
		while true do
			local warned1, warned2, evacuated = false, false, false
			while true do
				local left = (workspace:GetAttribute("MineResetAt") or 0) - os.time()
				if left <= Balance.ResetWarn1 and not warned1 then
					warned1 = true
					Notifier.AlertAll("ResetWarn", { Seconds = Balance.ResetWarn1, Level = 1 })
				end
				if left <= Balance.ResetWarn2 and not warned2 then
					warned2 = true
					Notifier.AlertAll("ResetWarn", { Seconds = Balance.ResetWarn2, Level = 2 })
				end
				if left <= 1 and not evacuated then
					evacuated = true
					evacuate()
				end
				if left <= 0 then
					break
				end
				task.wait(0.25)
			end
			Notifier.AlertAll("Reset", {})
			startGoldRush()
			Mining.ResetAll()
			schedule()
		end
	end)
end

return MineReset
