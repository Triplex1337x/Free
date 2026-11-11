-- Admin panel (visible only to admins; every command is checked on the server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Potions = require(Shared.Config.Potions)
local Zones = require(Shared.Config.Zones)

local UI = require(script.Parent.Parent.UI)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local AdminController = {}

local built = false

function AdminController:Build()
	if built then
		return
	end
	built = true
	local panel = Hud:CreatePanel("Админ-панель", Vector2.new(940, 620))
	local content = panel.Content

	-- Target + amount inputs.
	local function input(placeholder: string, text: string, position: UDim2, width: number)
		return UI.new("TextBox", {
			PlaceholderText = placeholder,
			Text = text,
			ClearTextOnFocus = false,
			Font = Theme.FontHeavy,
			TextScaled = true,
			TextColor3 = Theme.Text,
			PlaceholderColor3 = Theme.SubText,
			BackgroundColor3 = Theme.Background,
			Position = position,
			Size = UDim2.fromOffset(width, 44),
			Parent = content,
		}, { UI.corner(8), UI.stroke(Theme.Accent2, 2), UI.padding(8), UI.new("UITextSizeConstraint", { MaxTextSize = 20 }) })
	end
	UI.label({ Text = "ИГРОК:", Font = Theme.FontHeavy, MaxTextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(90, 44), Position = UDim2.fromOffset(0, 6), Parent = content })
	local targetBox = input("ник или «я»", "я", UDim2.fromOffset(90, 6), 220)
	UI.label({ Text = "ЧИСЛО:", Font = Theme.FontHeavy, MaxTextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(90, 44), Position = UDim2.fromOffset(330, 6), Parent = content })
	local amountBox = input("100", "1000", UDim2.fromOffset(420, 6), 160)
	local status = UI.label({ Text = "", TextColor3 = Theme.Good, Font = Theme.FontHeavy, MaxTextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -600, 0, 44), Position = UDim2.fromOffset(600, 6), TextWrapped = true, Parent = content })

	local function run(command: string, extra: string?)
		local ok, result = pcall(Remotes.Admin.InvokeServer, Remotes.Admin, command, targetBox.Text, amountBox.Text, extra)
		if ok and type(result) == "table" then
			status.Text = result.Message
			status.TextColor3 = if result.Ok then Theme.Good else Theme.Bad
		else
			status.Text = "Ошибка вызова"
			status.TextColor3 = Theme.Bad
		end
	end

	local scroll = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = content,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local order = 0
	local function section(title: string, color: Color3, buttons)
		order += 1
		UI.label({ Text = title, Font = Theme.FontHeavy, TextColor3 = color, MaxTextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = scroll })
		order += 1
		local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll }, {
			UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, b in buttons do
			UI.button({ Text = b[1], Color = b[3] or color, LayoutOrder = i, MaxTextSize = 16, Parent = grid, OnClick = function()
				run(b[2], b[4])
			end })
		end
	end

	section("РЕСУРСЫ (число = сколько)", Theme.Accent2, {
		{ "+ SHARDS", "Shards" },
		{ "+ SPINS", "Spins" },
		{ "+ ОПЫТ", "Xp" },
		{ "УРОВЕНЬ = ЧИСЛО", "SetLevel" },
	})
	section("ПРОГРЕСС", Theme.Gold, {
		{ "ВСЕ СТИЛИ", "AllArts" },
		{ "МАКС. МАСТЕРСТВО", "MaxMastery" },
		{ "СБРОС СТАТОВ", "ResetStats" },
		{ "СЛЕД. ГЛАВА ИСТОРИИ", "StoryNext" },
		{ "НОВЫЕ КВЕСТЫ", "ResetQuests" },
	})
	local potionButtons = { { "ВСЕ ЗЕЛЬЯ ×ЧИСЛО", "Potion", Theme.Accent, "all" } }
	for _, id in Potions.Order do
		local potion = Potions.Get(id)
		table.insert(potionButtons, { potion.Name, "Potion", potion.Color, id })
	end
	table.insert(potionButtons, { "СНЯТЬ БАФФЫ", "ClearBuffs", Theme.Bad })
	section("ЗЕЛЬЯ (число = сколько штук)", Theme.Accent, potionButtons)
	local worldButtons = {}
	for _, id in Zones.Order do
		local zone = Zones.Get(id)
		table.insert(worldButtons, { "→ " .. zone.Name, "Teleport", zone.Color, id })
	end
	table.insert(worldButtons, { "ПРИЗВАТЬ БОССА", "Boss", Theme.Bad })
	table.insert(worldButtons, { "УДАЧА СЕРВЕРА (мин)", "ServerLuck", Theme.Gold })
	table.insert(worldButtons, { "ЛЕЧЕНИЕ + УЛЬТА", "Heal", Theme.Good })
	table.insert(worldButtons, { "БЕССМЕРТИЕ ВКЛ/ВЫКЛ", "God", Color3.fromRGB(200, 200, 220) })
	section("МИР", Color3.fromRGB(150, 110, 255), worldButtons)

	-- Wipe needs two clicks.
	order += 1
	local armed = false
	local wipe = UI.button({ Text = "СБРОСИТЬ ПРОГРЕСС ИГРОКА", Color = Theme.Bad, Size = UDim2.fromOffset(300, 44), LayoutOrder = order, MaxTextSize = 16, Parent = scroll })
	wipe.Activated:Connect(function()
		if not armed then
			armed = true
			wipe.Text = "ТОЧНО? НАЖМИ ЕЩЁ РАЗ"
			task.delay(3, function()
				armed = false
				wipe.Text = "СБРОСИТЬ ПРОГРЕСС ИГРОКА"
			end)
			return
		end
		armed = false
		wipe.Text = "СБРОСИТЬ ПРОГРЕСС ИГРОКА"
		run("Wipe")
	end)

	Hud:AddMenuButton("Admin", Theme.Bad, 10, panel.Toggle)
end

function AdminController:Start()
	if player:GetAttribute("IsAdmin") then
		self:Build()
	end
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		if player:GetAttribute("IsAdmin") then
			self:Build()
		end
	end)
end

return AdminController
