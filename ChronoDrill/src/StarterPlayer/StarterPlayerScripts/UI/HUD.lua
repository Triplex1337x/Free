-- HUD 2.0 — раскладка как в популярных симуляторах:
--   слева      — сетка цветных кнопок меню с белыми иконками (питомцы, предметы, магазин, задания...)
--   слева по центру — столбик: рюкзак, монеты, осколки, характеристики
--   сверху     — ярус + глубина + таймер вайпа в одной плашке
--   слева внизу— активные бафы (иконка + таймер, подсказка при наведении)
--   снизу      — рюкзак, справа внизу — «На базу»
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs:WaitForChild("Balance"))
local BiomesData = require(Configs:WaitForChild("BiomesData"))
local BoostsData = require(Configs:WaitForChild("BoostsData"))
local RewardsData = require(Configs:WaitForChild("RewardsData"))
local GamepassesData = require(Configs:WaitForChild("GamepassesData"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local UI = require(script.Parent.UIKit)
local Icons2D = require(script.Parent.Icons2D)

local HUD = {}
local player = Players.LocalPlayer

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local GOLD = Color3.fromRGB(255, 208, 64)
local PILL = Color3.fromRGB(36, 30, 56)

-- Счётчик: тёмная капсула + цветной круглый значок с белой иконкой слева
-- Счётчик в стиле симуляторов: яркая голубая капсула с глянцем, круглый значок слева
local PILL_BLUE = Color3.fromRGB(34, 156, 255)
local PILL_EDGE = Color3.fromRGB(14, 66, 150)
local function counter(parent, w, h, pos, glyph, badgeColor, glyphColor, pillColor)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), Position = pos, Parent = parent })
	local pc = pillColor or PILL_BLUE
	local pill = UI.new("Frame", { Name = "Pill", BackgroundColor3 = pc, Size = UDim2.new(1, -h * 0.45, 1, -8), Position = UDim2.new(0, h * 0.45, 0, 4), Parent = holder })
	UI.Corner(pill, UDim.new(1, 0))
	UI.Stroke(pill, 3.5, UI.Darker(pc, 0.55), true)
	UI.Gradient(pill, UI.Lighter(pc, 0.25), UI.Darker(pc, 0.15))
	local shine = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Size = UDim2.new(1, -h * 0.9, 0.3, 0), Position = UDim2.new(0, h * 0.6, 0, 3), Parent = pill })
	UI.Corner(shine, UDim.new(1, 0))
	local badge = UI.new("Frame", { Name = "Badge", BackgroundColor3 = badgeColor, Size = UDim2.fromOffset(h, h), ZIndex = 3, Parent = holder })
	UI.Corner(badge, UDim.new(1, 0))
	UI.Stroke(badge, 3, UI.Ink, true)
	UI.Gradient(badge, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
	local ic = Icons2D.New(badge, glyph, math.floor(h * 0.74), { Color = glyphColor, ZIndex = 4 })
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.47)
	local label = UI.Text(pill, "0", { Size = UDim2.new(1, -(h * 0.75), 1, -8), Position = UDim2.fromOffset(h * 0.62, 4), TextXAlignment = Enum.TextXAlignment.Left, MaxText = math.floor(h * 0.6), ZIndex = 3 })
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local obj = { Holder = holder, Label = label, Icon = ic, Last = nil }
	function obj.Set(text)
		if obj.Last ~= text then
			if obj.Last ~= nil then
				scale.Scale = 1.07
				TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
			obj.Last = text
			label.Text = text
		end
	end
	return obj
end

function HUD.Build(screen, ctx)
	local ClientState = ctx.ClientState
	local Sound = ctx.Sound
	local hud = {}
	local touch = UI.IsTouch()

	---------------------------------------------------------------- подсказка
	local tip = UI.new("Frame", { Name = "Tooltip", BackgroundColor3 = PILL, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(250, 66), Visible = false, ZIndex = 50, Parent = screen })
	UI.Corner(tip, 14)
	UI.Stroke(tip, 3, UI.Ink, true)
	local tipTitle = UI.Text(tip, "", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 5), MaxText = 20, ZIndex = 51, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
	local tipText = UI.Text(tip, "", { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 31), MaxText = 15, ZIndex = 51, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Stroke = false, TextColor3 = Color3.fromRGB(225, 220, 240) })
	local tipOwner
	local function localPos(obj)
		local s = screen:FindFirstChildOfClass("UIScale")
		local k = s and s.Scale or 1
		local p = obj.AbsolutePosition - screen.AbsolutePosition
		return p.X / k, p.Y / k, obj.AbsoluteSize.X / k, obj.AbsoluteSize.Y / k
	end
	local function showTip(owner, anchor, title, text, side)
		tipOwner = owner
		tipTitle.Text = title
		tipText.Text = text
		local s = screen:FindFirstChildOfClass("UIScale")
		local k = s and s.Scale or 1
		local W, H = screen.AbsoluteSize.X / k, screen.AbsoluteSize.Y / k
		local x, y, w, h = localPos(anchor)
		local tx, ty
		if side == "left" then
			tx, ty = x - 258, y
		elseif side == "right" then
			tx, ty = x + w + 8, y
		else
			tx, ty = x, y - 74
		end
		tip.Position = UDim2.fromOffset(math.clamp(tx, 6, math.max(6, W - 256)), math.clamp(ty, 6, math.max(6, H - 72)))
		tip.Visible = true
		UI.Pop(tip, 0.85)
	end
	local function hideTip(owner)
		if tipOwner == owner then
			tip.Visible = false
			tipOwner = nil
		end
	end
	local function hoverTip(owner, anchor, title, textFn, side)
		local hit = UI.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = anchor })
		hit.MouseEnter:Connect(function()
			showTip(owner, anchor, title, textFn(), side)
		end)
		hit.MouseLeave:Connect(function()
			hideTip(owner)
		end)
		hit.Activated:Connect(function()
			if tipOwner == owner then
				hideTip(owner)
			else
				showTip(owner, anchor, title, textFn(), side)
			end
		end)
		return hit
	end

	---------------------------------------------------------------- меню слева
	local menuDefs = {
		{ "Pets", "Питомцы", UI.Colors.Orange, "Paw" },
		{ "Bag", "Предметы", UI.Colors.Purple, "Chest" },
		{ "Index", "Индекс", Color3.fromRGB(150, 110, 255), "Star" },
		{ "Quests", "Задания", UI.Colors.Blue, "Quest" },
		{ "Daily", "Награды", UI.Colors.Pink, "Gift" },
		{ "Wheel", "Колесо", UI.Colors.Yellow, "Wheel" },
		{ "Incubator", "Семена", UI.Colors.Green, "Sprout" },
		{ "Rebirth", "Ребёрс", UI.Colors.Teal, "Hourglass" },
		{ "Stats", "Статы", Color3.fromRGB(120, 110, 255), "Stats" },
		{ "Worlds", "Миры", Color3.fromRGB(60, 190, 255), "Globe" },
		{ "Settings", "Настройки", Color3.fromRGB(130, 136, 160), "Gear" },
		{ "Donate", "Донат", Color3.fromRGB(40, 200, 110), "Diamond" },
	}
	local BTN = touch and 62 or 72
	local cols = touch and 4 or 2
	local gap = touch and 8 or 12
	local rows = math.ceil(#menuDefs / cols)
	local menuW = cols * BTN + (cols - 1) * gap
	local menuH = rows * BTN + (rows - 1) * gap
	local menu = UI.new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(menuW, menuH), Parent = screen })
	-- меню справа; верхний край на одном уровне с блоком валют слева
	local TOP_Y = touch and UDim2.new(1, -14, 0, 12) or UDim2.new(1, -16, 0.5, -math.floor(menuH / 2) - 10)
	menu.AnchorPoint = Vector2.new(1, 0)
	menu.Position = TOP_Y
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(BTN, BTN)
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = menu
	hud.MenuButtons = {}
	for i, d in ipairs(menuDefs) do
		local b = UI.Button({ Parent = menu, Color = d[3], Size = UDim2.fromOffset(BTN, BTN), LayoutOrder = i, Radius = 18 })
		local ic = Icons2D.New(b.Face, d[4], math.floor(BTN * 0.62), { ZIndex = 4 })
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, math.floor(BTN * 0.07))
		local label = UI.Text(b.Face, d[2], { Size = UDim2.new(1, -6, 0, math.floor(BTN * 0.27)), Position = UDim2.new(0, 3, 1, -math.floor(BTN * 0.3)), MaxText = math.floor(BTN * 0.22), ZIndex = 5, StrokeThickness = 2 })
		local badge = UI.new("Frame", { BackgroundColor3 = UI.Colors.Red, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -16, 0, -8), Visible = false, ZIndex = 8, Parent = b.Holder })
		UI.Corner(badge, UDim.new(1, 0))
		UI.Stroke(badge, 2.5, UI.Ink, true)
		UI.Text(badge, "!", { ZIndex = 9, MaxText = 18 })
		local badgeScale = Instance.new("UIScale")
		badgeScale.Parent = badge
		b.Badge = badge
		b.BadgeScale = badgeScale
		b.Label = label
		b.DefaultText = d[2]
		b.Icon = ic
		b.Activated:Connect(function()
			Icons2D.Bounce(ic, 1.2)
			ctx.OpenPanel(d[1])
		end)
		b.Face.MouseEnter:Connect(function()
			Icons2D.Wiggle(ic)
		end)
		hud.MenuButtons[d[1]] = b
	end

	-- кнопка панели разработчика (видна только админам; на ПК ещё и клавиша F2)
	local adminBtn = UI.Button({ Parent = screen, Glyph = "Shield", Color = Color3.fromRGB(255, 84, 110), Size = UDim2.fromOffset(54, 54), Radius = 27 })
	adminBtn.Holder.AnchorPoint = Vector2.new(1, 0)
	adminBtn.Holder.Position = touch and UDim2.new(1, -(menuW + 26), 0, 12) or UDim2.new(1, -16, 0, 16)
	adminBtn.Holder.Visible = player:GetAttribute("IsAdmin") == true
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		adminBtn.Holder.Visible = player:GetAttribute("IsAdmin") == true
	end)
	adminBtn.Activated:Connect(function()
		ctx.OpenPanel("Admin")
	end)
	hud.AdminButton = adminBtn

	-- купленные геймпассы: ряд значков в углу (наведи — подсказка)
	local passRow = UI.new("Frame", { Name = "OwnedPasses", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Parent = screen })
	local passList = Instance.new("UIGridLayout")
	passList.CellSize = UDim2.fromOffset(38, 38)
	passList.CellPadding = UDim2.fromOffset(6, 6)
	passList.SortOrder = Enum.SortOrder.LayoutOrder
	passList.Parent = passRow
	if touch then
		passRow.AnchorPoint = Vector2.new(1, 0)
		passRow.Position = UDim2.new(1, -14, 0, menuH + 22)
		passList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	else
		passRow.Position = UDim2.fromOffset(16, 16)
	end
	local passKey = nil
	function hud.RefreshPasses(data)
		local owned = {}
		for _, def in ipairs(GamepassesData.List) do
			if data.Passes and data.Passes[def.Key] then
				table.insert(owned, def)
			end
		end
		local keyParts = {}
		for _, d in ipairs(owned) do
			table.insert(keyParts, d.Key)
		end
		local k = table.concat(keyParts, ",")
		if k == passKey then
			return
		end
		passKey = k
		for _, ch in ipairs(passRow:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		local perRow = 6
		passRow.Size = UDim2.fromOffset(math.min(#owned, perRow) * 44, math.ceil(#owned / perRow) * 44)
		for i, def in ipairs(owned) do
			local col = c3(def.Color)
			local f = UI.new("Frame", { BackgroundColor3 = col, Size = UDim2.fromOffset(38, 38), LayoutOrder = i, Parent = passRow })
			UI.Corner(f, UDim.new(1, 0))
			UI.Stroke(f, 2.5, UI.Edge(col), true)
			UI.Gradient(f, UI.Lighter(col, 0.3), UI.Darker(col, 0.1))
			local ic = Icons2D.New(f, def.Glyph, 28, { Ink = UI.Edge(col), ZIndex = 4 })
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.fromScale(0.5, 0.48)
			hoverTip({ Frame = f }, f, def.Name, function()
				return def.Desc
			end, touch and "left" or "below")
		end
	end

	---------------------------------------------------------------- справа: валюты и характеристики
	-- столбик слева по центру: рюкзак, монеты, осколки, характеристики
	local right = UI.new("Frame", { Name = "Currencies", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, touch and 0 or 0.5), Position = touch and UDim2.fromOffset(14, 8) or UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(300, 246), Parent = screen })
	local coins = counter(right, 300, 62, UDim2.fromOffset(0, 70), "Coin", Color3.fromRGB(255, 196, 40), GOLD)
	coins.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
	local shards = counter(right, 240, 52, UDim2.fromOffset(0, 140), "Shard", Color3.fromRGB(210, 90, 255), nil, Color3.fromRGB(196, 92, 255))
	-- карточка характеристик
	local statRow = UI.new("Frame", { Name = "StatRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 46), Position = UDim2.fromOffset(0, 200), Parent = right })
	UI.List(statRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left)
	local function chip(order, glyph, color)
		local f = UI.new("Frame", { BackgroundColor3 = PILL, BackgroundTransparency = 0.12, Size = UDim2.fromOffset(94, 40), LayoutOrder = order, Parent = statRow })
		UI.Corner(f, 12)
		UI.Stroke(f, 3, UI.Ink, true)
		local ic = Icons2D.New(f, glyph, 30, { Color = color, ZIndex = 3 })
		ic.Position = UDim2.fromOffset(3, 3)
		local l = UI.Text(f, "", { Size = UDim2.new(1, -38, 1, -10), Position = UDim2.fromOffset(34, 5), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, ZIndex = 3 })
		return { Frame = f, Label = l }
	end
	local damage = chip(1, "Pickaxe", Color3.fromRGB(255, 160, 90))
	local petMult = chip(2, "Paw", Color3.fromRGB(140, 235, 140))
	local sellMult = chip(3, "Coin", Color3.fromRGB(255, 214, 70))
	local function derived()
		return (ClientState.Data and ClientState.Data.Derived) or {}
	end
	hoverTip(coins, coins.Holder, "Монеты", function()
		return "Всего заработано: " .. Util.Format(ClientState.Data and ClientState.Data.TotalCoins or 0)
	end, "right")
	hoverTip(shards, shards.Holder, "Хроно-Осколки", function()
		return "Награда за ребёрс. Тратится в Хроно-Древе."
	end, "right")
	hoverTip(damage, damage.Frame, "Урон за удар", function()
		return "Бур x питомцы x бусты. Ударов в секунду: " .. string.format("%.1f", 1 / (derived().HitInterval or 0.25))
	end, "right")
	hoverTip(petMult, petMult.Frame, "Урон от питомцев", function()
		return "Бонусы надетых питомцев к урону складываются"
	end, "right")
	hoverTip(sellMult, sellMult.Frame, "Множитель продажи", function()
		return "Питомцы x" .. string.format("%.2f", derived().CoinFactor or 1) .. " · ребёрсы x" .. string.format("%.2f", derived().RebirthMult or 1)
	end, "right")

	---------------------------------------------------------------- сверху: ярус, глубина, вайп
	local top = UI.new("Frame", { Name = "TopInfo", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(440, 50), Parent = screen })
	if touch then
		top.Position = UDim2.new(0.5, 0, 0, 10)
		top.Size = UDim2.fromOffset(400, 50)
	end
	local topPill = UI.new("Frame", { BackgroundColor3 = PILL, BackgroundTransparency = 0.12, Size = UDim2.new(1, -24, 1, -10), Position = UDim2.fromOffset(24, 5), Parent = top })
	UI.Corner(topPill, UDim.new(1, 0))
	UI.Stroke(topPill, 3, UI.Ink, true)
	local biomeBadge = UI.new("Frame", { BackgroundColor3 = UI.Colors.Green, Size = UDim2.fromOffset(50, 50), ZIndex = 3, Parent = top })
	UI.Corner(biomeBadge, UDim.new(1, 0))
	UI.Stroke(biomeBadge, 3, UI.Ink, true)
	UI.Gradient(biomeBadge, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
	local biomeIcon = Icons2D.New(biomeBadge, "Globe", 36, { ZIndex = 4 })
	biomeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	biomeIcon.Position = UDim2.fromScale(0.5, 0.48)
	local depthTrack = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 14, 30), Size = UDim2.new(1, -164, 0, 24), Position = UDim2.fromOffset(34, 8), ZIndex = 2, Parent = topPill })
	UI.Corner(depthTrack, UDim.new(1, 0))
	local depthFill = UI.new("Frame", { BackgroundColor3 = UI.Colors.Green, Size = UDim2.fromScale(0, 1), ZIndex = 2, Parent = depthTrack })
	UI.Corner(depthFill, UDim.new(1, 0))
	UI.Gradient(depthFill, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200))
	local depthText = UI.Text(depthTrack, "", { Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), MaxText = 17, ZIndex = 3 })
	local sep = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Size = UDim2.new(0, 2, 1, -14), Position = UDim2.new(1, -124, 0, 7), Parent = topPill })
	local clock = Icons2D.New(topPill, "Clock", 30, { ZIndex = 3, Shadow = false })
	clock.Position = UDim2.new(1, -116, 0, 5)
	local timerText = UI.Text(topPill, "20:00", { Size = UDim2.fromOffset(78, 26), Position = UDim2.new(1, -84, 0, 7), MaxText = 22, ZIndex = 3, TextXAlignment = Enum.TextXAlignment.Left })
	local topHit = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(130, 40), Position = UDim2.new(1, -130, 0, 0), Parent = topPill })
	hoverTip(topHit, topHit, "Вайп шахты", function()
		return "Каждые 20 минут шахта восстанавливается. После — Золотая лихорадка."
	end, "below")

	---------------------------------------------------------------- бафы
	local buffRow = UI.new("Frame", { Name = "Buffs", BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 76), Parent = screen })
	local buffList = UI.List(buffRow, 10, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Bottom)
	if touch then
		-- на телефоне слева внизу джойстик: бафы справа под валютой
		buffRow.AnchorPoint = Vector2.new(0, 0)
		buffRow.Position = UDim2.fromOffset(14, 262)
		buffList.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		buffRow.AnchorPoint = Vector2.new(0, 1)
		buffRow.Position = UDim2.new(0, 16, 1, -18)
	end
	local buffChips = {}
	local function buffChip(id, title, desc, glyph, color, order)
		local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 76), LayoutOrder = order, Visible = false, Parent = buffRow })
		local box = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(60, 60), Parent = holder })
		UI.Corner(box, 16)
		UI.Stroke(box, 3, UI.Ink, true)
		UI.Gradient(box, Color3.new(1, 1, 1), Color3.fromRGB(195, 195, 210))
		local ic = Icons2D.New(box, glyph, 42, { ZIndex = 3 })
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.46)
		-- полоса оставшегося времени по низу значка
		local barBg = UI.new("Frame", { BackgroundColor3 = UI.Ink, BackgroundTransparency = 0.3, Size = UDim2.new(1, -12, 0, 6), Position = UDim2.new(0, 6, 1, -10), ZIndex = 4, Parent = box })
		UI.Corner(barBg, 3)
		local bar = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = barBg })
		UI.Corner(bar, 3)
		local timer = UI.Text(holder, "0:00", { Size = UDim2.new(1, 16, 0, 20), Position = UDim2.new(0, -8, 1, -20), MaxText = 17, ZIndex = 6 })
		local obj = { Holder = holder, Timer = timer, Bar = bar, Icon = ic }
		hoverTip(obj, box, title, function()
			return desc
		end, touch and "right" or "above")
		buffChips[id] = obj
		return obj
	end
	for i, b in ipairs(BoostsData.List) do
		if not b.Instant then
			buffChip(b.Id, b.Name, b.Desc, b.Id, c3(b.Color), i)
		end
	end
	buffChip("GoldRush", "Золотая лихорадка", "x2 шанс Хроно-Жил и семян после вайпа шахты", "Star", UI.Colors.Yellow, 10)
	-- серверные события (запускает разработчик): x монеты / урон / удача для всех
	buffChip("Event_Coins", "Событие: монеты", "Вся руда продаётся дороже для всех на сервере", "Coin", Color3.fromRGB(255, 176, 30), 11)
	buffChip("Event_Damage", "Событие: урон", "Буры всех игроков бьют сильнее", "Pickaxe", Color3.fromRGB(255, 90, 80), 12)
	buffChip("Event_Luck", "Событие: удача", "Повышен шанс редких питомцев", "Clover", Color3.fromRGB(70, 205, 100), 13)

	---------------------------------------------------------------- рюкзак
	local packHolder = UI.new("Frame", { Name = "Backpack", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(300, 56), Parent = right })
	local packBar = UI.Bar(packHolder, UDim2.new(1, -30, 0, 38), UDim2.fromOffset(30, 10), UI.Colors.Yellow, PILL_EDGE)
	packBar.Label.Size = UDim2.new(1, -40, 1, -6)
	packBar.Label.Position = UDim2.fromOffset(34, 3)
	local packBadge = UI.new("Frame", { BackgroundColor3 = UI.Colors.Orange, Size = UDim2.fromOffset(56, 56), ZIndex = 3, Parent = packHolder })
	UI.Corner(packBadge, UDim.new(1, 0))
	UI.Stroke(packBadge, 3, UI.Ink, true)
	UI.Gradient(packBadge, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
	local packIcon = Icons2D.New(packBadge, "Backpack", 40, { ZIndex = 4 })
	packIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	packIcon.Position = UDim2.fromScale(0.5, 0.47)
	local packScale = Instance.new("UIScale")
	packScale.Parent = packHolder
	local packInfo = UI.Text(packHolder, "", { Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(60, -10), TextColor3 = Color3.fromRGB(255, 230, 140), MaxText = 17, TextXAlignment = Enum.TextXAlignment.Left })

	---------------------------------------------------------------- «На базу»
	local TPS = touch and 78 or 92
	local tp = UI.Button({ Parent = screen, Name = "Teleport", Color = UI.Colors.Teal, Size = UDim2.fromOffset(TPS, TPS), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -22), Radius = 22 })
	if touch then
		tp.Holder.AnchorPoint = Vector2.new(0.5, 1)
		tp.Holder.Position = UDim2.new(0.5, 0, 1, -12)
	end
	local homeIcon = Icons2D.New(tp.Face, "Home", math.floor(TPS * 0.6), { ZIndex = 4 })
	homeIcon.AnchorPoint = Vector2.new(0.5, 0)
	homeIcon.Position = UDim2.new(0.5, 0, 0, math.floor(TPS * 0.07))
	UI.Text(tp.Face, touch and "БАЗА" or "НА БАЗУ", { Size = UDim2.new(1, -6, 0, math.floor(TPS * 0.27)), Position = UDim2.new(0, 3, 1, -math.floor(TPS * 0.3)), MaxText = 20, ZIndex = 5 })
	local key = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, -8, 0, -8), ZIndex = 8, Visible = not touch, Parent = tp.Holder })
	UI.Corner(key, 6)
	UI.Stroke(key, 2.5, UI.Ink, true)
	UI.Text(key, "T", { ZIndex = 9, MaxText = 16, TextColor3 = UI.Ink, Stroke = false })
	-- телепорт на базу — мгновенный (небольшая защита от спама)
	local lastTp = 0
	local function startCast()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or os.clock() - lastTp < 1.2 then
			return
		end
		lastTp = os.clock()
		Icons2D.Bounce(homeIcon, 1.25)
		Net.Get("TeleportBase"):FireServer("now")
	end
	tp.Activated:Connect(startCast)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.ButtonY) then
			startCast()
		end
	end)

	---------------------------------------------------------------- тосты
	local toastArea = UI.new("Frame", { Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(520, 260), Parent = screen })
	UI.List(toastArea, 6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
	local TOAST_COLORS = { info = UI.Colors.Blue, good = UI.Colors.Green, warn = UI.Colors.Orange, error = UI.Colors.Red, seed = UI.Colors.Teal, unlock = UI.Colors.Purple }
	local TOAST_ICONS = { info = "Quest", good = "Check", warn = "Clock", error = "Close", seed = "Sprout", unlock = "Star" }
	local toastOrder = 0
	function hud.Toast(text, kind)
		kind = kind or "info"
		toastOrder = toastOrder + 1
		local holder = UI.new("Frame", { BackgroundColor3 = PILL, BackgroundTransparency = 0.08, Size = UDim2.fromOffset(500, 40), LayoutOrder = toastOrder, Parent = toastArea })
		UI.Corner(holder, UDim.new(1, 0))
		UI.Stroke(holder, 3, UI.Ink, true)
		local dot = UI.new("Frame", { BackgroundColor3 = TOAST_COLORS[kind] or UI.Colors.Blue, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(3, 3), Parent = holder })
		UI.Corner(dot, UDim.new(1, 0))
		local ic = Icons2D.New(dot, TOAST_ICONS[kind] or "Star", 24, { ZIndex = 3, Shadow = false })
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		UI.Text(holder, text, { Size = UDim2.new(1, -56, 1, -10), Position = UDim2.fromOffset(44, 5), MaxText = 19, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Pop(holder, 0.6)
		local frames = {}
		for _, c in ipairs(toastArea:GetChildren()) do
			if c:IsA("Frame") then
				table.insert(frames, c)
			end
		end
		if #frames > 4 then
			table.sort(frames, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			frames[1]:Destroy()
		end
		task.delay(3.6, function()
			if holder.Parent then
				local s = holder:FindFirstChildOfClass("UIScale")
				if s then
					local tw = TweenService:Create(s, TweenInfo.new(0.18), { Scale = 0 })
					tw:Play()
					tw.Completed:Wait()
				end
				holder:Destroy()
			end
		end)
	end

	---------------------------------------------------------------- баннеры
	local banner = UI.new("Frame", { Name = "Banner", BackgroundColor3 = UI.Colors.Yellow, Size = UDim2.fromOffset(620, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170), Visible = false, Parent = screen })
	UI.Corner(banner, 20)
	UI.Stroke(banner, 4, UI.Ink, true)
	UI.Gradient(banner, Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 218))
	local bannerLabel = UI.Text(banner, "", { Size = UDim2.new(1, -28, 1, -14), Position = UDim2.fromOffset(14, 7), MaxText = 32, StrokeThickness = 3 })
	local bannerToken = 0
	function hud.Banner(text, color, duration, pulse)
		bannerToken = bannerToken + 1
		local my = bannerToken
		banner.Visible = true
		banner.BackgroundColor3 = color
		bannerLabel.Text = text
		UI.Pop(banner, 0.5)
		if pulse then
			task.spawn(function()
				while bannerToken == my and banner.Visible do
					TweenService:Create(banner, TweenInfo.new(0.25), { BackgroundColor3 = UI.Lighter(color, 0.35) }):Play()
					task.wait(0.25)
					TweenService:Create(banner, TweenInfo.new(0.25), { BackgroundColor3 = color }):Play()
					task.wait(0.25)
				end
			end)
		end
		task.delay(duration or 3, function()
			if bannerToken == my then
				banner.Visible = false
			end
		end)
	end

	---------------------------------------------------------------- всплывающие монеты
	function hud.CoinPop(amount)
		-- цифра всплывает справа от счётчика монет и улетает вверх
		local base = right.Position
		local l = UI.Text(screen, "+" .. Util.Format(amount), { Size = UDim2.fromOffset(220, 40), Position = base + UDim2.fromOffset(310, -46), TextColor3 = GOLD, MaxText = 32, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Pop(l, 0.4)
		TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = base + UDim2.fromOffset(310, -88), TextTransparency = 1 }):Play()
		TweenService:Create(l:FindFirstChildOfClass("UIStroke"), TweenInfo.new(1.1), { Transparency = 1 }):Play()
		task.delay(1.2, function()
			l:Destroy()
		end)
		Icons2D.Bounce(coins.Icon, 1.3)
	end

	---------------------------------------------------------------- обновление
	local shownCoins = 0
	local lastCount = 0
	function hud.Refresh(data)
		local d = data.Derived or {}
		hud.RefreshPasses(data)
		shards.Set(Util.Format(data.Shards or 0))
		damage.Label.Text = Util.Format(d.Damage or 0)
		petMult.Label.Text = "x" .. string.format((d.PetSum or 1) < 10 and "%.2f" or "%.1f", d.PetSum or 1)
		sellMult.Label.Text = "x" .. string.format((d.SellMult or 1) < 10 and "%.2f" or "%.1f", d.SellMult or 1)
		local cap = d.Capacity or 30
		local cnt = data.Ore and data.Ore.Count or 0
		local worth = (data.Ore and data.Ore.Value or 0) * (d.SellMult or 1)
		local infinite = cap >= 1e17
		if infinite then
			packBar.Set(1, Util.Format(cnt) .. " / ∞")
		else
			packBar.Set(cnt / cap, Util.Format(cnt) .. " / " .. Util.Format(cap))
		end
		local full = (not infinite) and cnt >= cap
		packInfo.Text = full and "РЮКЗАК ПОЛОН" or (cnt > 0 and ("Стоимость: ~" .. Util.Format(worth)) or "")
		packInfo.TextColor3 = full and Color3.fromRGB(255, 120, 110) or Color3.fromRGB(255, 230, 140)
		packBar.Fill.BackgroundColor3 = full and UI.Colors.Red or (infinite and Color3.fromRGB(255, 90, 160) or UI.Colors.Yellow)
		if cnt > lastCount then
			packScale.Scale = 1.05
			TweenService:Create(packScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastCount = cnt
	end

	local function setMenuTimer(name, left)
		local b = hud.MenuButtons[name]
		if left > 0 then
			b.Label.Text = Util.Time(left)
			b.Badge.Visible = false
		else
			b.Label.Text = b.DefaultText
			b.Badge.Visible = true
		end
	end

	-- бейдж «!» у Заданий, если что-то можно забрать
	function hud.SetBadge(name, on)
		local b = hud.MenuButtons[name]
		if b then
			b.Badge.Visible = on
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		local data = ClientState.Data
		if not data then
			return
		end
		local now = ClientState.ServerNow()
		local target = data.Coins or 0
		shownCoins = shownCoins + (target - shownCoins) * math.min(1, dt * 10)
		if math.abs(target - shownCoins) < 1 then
			shownCoins = target
		end
		coins.Label.Text = Util.Format(shownCoins)
		-- бафы
		for id, chipObj in pairs(buffChips) do
			local left, total
			if id == "GoldRush" then
				left = (workspace:GetAttribute("GoldRushUntil") or 0) - now
				total = Balance.GoldRushDuration
			elseif string.sub(id, 1, 6) == "Event_" then
				left = (workspace:GetAttribute(id .. "_Until") or 0) - now
				total = math.max(left, 15 * 60)
			else
				left = ClientState.BoostLeft(id)
				total = math.max(BoostsData.ById[id].Duration, left)
			end
			local on = left > 0
			if chipObj.Holder.Visible ~= on then
				chipObj.Holder.Visible = on
				if on then
					UI.Pop(chipObj.Holder, 0.4)
				end
			end
			if on then
				local em = string.sub(id, 1, 6) == "Event_" and workspace:GetAttribute(id)
				chipObj.Timer.Text = (em and ("x" .. tostring(em) .. " ") or "") .. Util.Time(left)
				chipObj.Bar.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
				chipObj.Timer.TextColor3 = (left < 30) and Color3.fromRGB(255, 120, 110) or Color3.new(1, 1, 1)
			end
		end
		-- таймеры награды и колеса
		local daily = data.Daily or { Last = 0 }
		setMenuTimer("Daily", (daily.Last or 0) > 0 and (RewardsData.DailyCooldown - (now - daily.Last)) or 0)
		setMenuTimer("Wheel", (data.WheelLast or 0) > 0 and (RewardsData.WheelCooldown - (now - data.WheelLast)) or 0)
		local pulse = 1 + math.abs(math.sin(os.clock() * 4)) * 0.18
		for _, b in pairs(hud.MenuButtons) do
			if b.Badge.Visible then
				b.BadgeScale.Scale = pulse
			end
		end
		-- вайп
		local resetAt = workspace:GetAttribute("MineResetAt")
		if resetAt then
			local left = resetAt - now
			timerText.Text = Util.Time(left)
			timerText.TextColor3 = (left <= 30) and ((left <= 10) and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 180, 70)) or Color3.new(1, 1, 1)
		end
		-- ярус и глубина
		local b = player:GetAttribute("Biome") or data.CurrentBiome or 1
		local biome = BiomesData[b] or BiomesData[1]
		local dm = player:GetAttribute("Depth") or biome.MinDepth
		local frac = math.clamp((dm - biome.MinDepth) / (biome.MaxDepth - biome.MinDepth), 0, 1)
		depthFill.Size = UDim2.fromScale(frac, 1)
		depthFill.Visible = frac > 0.02
		local uic = c3(biome.Theme.UI)
		depthFill.BackgroundColor3 = uic
		biomeBadge.BackgroundColor3 = uic
		depthText.Text = biome.Short .. "  ·  " .. Util.Commas(dm) .. " / " .. Util.Commas(biome.MaxDepth) .. " м"
	end)

	hud.Screen = screen
	hud.Coins = coins
	hud.Teleport = tp
	hud.Backpack = packHolder
	hud.TopInfo = top
	return hud
end

return HUD
