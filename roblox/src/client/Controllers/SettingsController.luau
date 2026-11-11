-- Settings: PvP switch (server-validated), camera shake, damage numbers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local GameConfig = require(Shared.Config.Game)

local UI = require(script.Parent.Parent.UI)
local Vfx = require(script.Parent.Parent.Vfx)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local SettingsController = {}

function SettingsController:Init()
	local panel = Hud:CreatePanel("Настройки", Vector2.new(640, 460))
	local list = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromScale(1, 1), Parent = panel.Content }, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local function row(order: number, title: string, description: string, getter: () -> boolean, setter: (boolean) -> ())
		local frame = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -8, 0, 86), LayoutOrder = order, Parent = list }, {
			UI.corner(10),
			UI.new("UIGradient", { Color = ColorSequence.new(Theme.PanelLight, Theme.Background) }),
			UI.stroke(Theme.Ink, 3),
		})
		UI.label({ Text = title, Font = Theme.FontHeavy, MaxTextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 0, 30), Position = UDim2.fromOffset(14, 8), Parent = frame })
		UI.label({ Text = description, MaxTextSize = 15, Outline = false, TextColor3 = Theme.SubText, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 0, 40), Position = UDim2.fromOffset(14, 38), Parent = frame })
		local toggle = UI.button({ Text = "", Color = Theme.Good, Size = UDim2.fromOffset(130, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), MaxTextSize = 20, Parent = frame })
		local function refresh()
			local on = getter()
			toggle.Text = if on then "ВКЛ" else "ВЫКЛ"
			local gradient = toggle:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Color = if on then ColorSequence.new(Theme.Good, Color3.fromRGB(30, 140, 70)) else ColorSequence.new(Theme.SubText, Color3.fromRGB(70, 60, 90))
			end
		end
		toggle.Activated:Connect(function()
			setter(not getter())
			refresh()
		end)
		refresh()
		return refresh
	end

	local refreshPvp = row(1, "⚔ PVP", ("Сражайся с другими игроками, у которых тоже включено PvP. Доступно с %d уровня. Выключить нельзя %d сек. после боя."):format(GameConfig.Pvp.MinLevel, GameConfig.Pvp.LockSeconds), function()
		return player:GetAttribute("Pvp") == true
	end, function(on)
		local ok, result = pcall(Remotes.SetPvp.InvokeServer, Remotes.SetPvp, on)
		if ok and type(result) == "table" then
			if result.Ok then
				Hud:Toast(if on then "PvP ВКЛЮЧЕНО — тебя могут атаковать игроки!" else "PvP выключено", if on then "error" else "success")
			else
				Hud:Toast(result.Error, "error")
			end
		end
	end)
	player:GetAttributeChangedSignal("Pvp"):Connect(refreshPvp)

	row(2, "📳 ТРЯСКА КАМЕРЫ", "Встряска экрана от ударов и взрывов.", function()
		return Vfx.ShakeEnabled
	end, function(on)
		Vfx.ShakeEnabled = on
	end)

	row(3, "🔢 ЦИФРЫ УРОНА", "Всплывающие числа урона над целями.", function()
		return Vfx.DamageNumbers
	end, function(on)
		Vfx.DamageNumbers = on
	end)

	Hud:AddMenuButton("Settings", Color3.fromRGB(140, 140, 170), 9, panel.Toggle)
end

return SettingsController
