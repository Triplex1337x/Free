-- HUD 3.0 — «стеклянный» интерфейс:
--   слева по центру — рюкзак, монеты, осколки и характеристики на тёмных полупрозрачных капсулах
--   справа         — меню: стеклянные плитки с цветными иконками, подпись под иконкой, акцентная полоска
--   сверху         — ярус (своя иконка и цвет), глубина с полосой прогресса, таймер вайпа отдельной капсулой
--   слева внизу    — активные бафы, справа внизу — большая кнопка «На базу»
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
local PILL = Color3.fromRGB(24, 20, 52)
local SOFT = Color3.fromRGB(196, 190, 236) -- второстепенный текст на стекле
local BIOME_GLYPHS = { "Pickaxe", "Bone", "Snowflake", "Flame", "Saturn" }

local function txt(parent, text, size, props)
	props = props or {}
	props.MaxText = size
	if props.StrokeThickness == nil then
		props.StrokeThickness = 1.6
	end
	local l = UI.Text(parent, text, props)
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = Color3.fromRGB(14, 10, 32)
		st.Transparency = 0.15
	end
	return l
end

-- Счётчик валюты: стеклянная капсула, большая цветная иконка «выходит» за левый край, крупное число
local function counter(parent, w, h, pos, glyph, accent, plusFn, vecColor)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), Position = pos, Parent = parent })
	local pill = UI.new("Frame", { Name = "Pill", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.new(0, 16, 0, 4), Parent = holder })
	UI.Glass(pill, UDim.new(1, 0))
	-- цветная подсветка слева, под иконкой
	local glow = UI.new("Frame", { BackgroundColor3 = accent, BackgroundTransparency = 0.25, Size = UDim2.new(0.55, 0, 1, 0), Parent = pill })
	UI.Corner(glow, UDim.new(1, 0))
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow
	local ic = Icons2D.New(holder, glyph, h + 4, { ZIndex = 4, Color = vecColor })
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, -4, 0.5, 0)
	local label = txt(pill, "0", math.floor(h * 0.6), { Size = UDim2.new(1, -(h + (plusFn and 40 or 12)), 1, -8), Position = UDim2.fromOffset(h - 6, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	if plusFn then
		local plus = UI.Button({ Parent = pill, Glyph = "Plus", Color = UI.Colors.Green, Size = UDim2.fromOffset(h - 14, h - 14), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, -2), Radius = 99 })
		plus.Activated:Connect(plusFn)
	end
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local obj = { Holder = holder, Label = label, Icon = ic, Last = nil }
	function obj.Set(text)
		if obj.Last ~= text then
			if obj.Last ~= nil then
				scale.Scale = 1.06
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

	---------------------------------------------------------------- меню справа
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
		{ "Settings", "Настройки", Color3.fromRGB(150, 156, 186), "Gear" },
		{ "Donate", "Донат", Color3.fromRGB(40, 200, 110), "Diamond" },
	}
	local BTN = touch and 62 or 70
	local cols = touch and 4 or 2
	local gap = touch and 8 or 10
	local rows = math.ceil(#menuDefs / cols)
	local menuW = cols * BTN + (cols - 1) * gap
	local menuH = rows * BTN + (rows - 1) * gap
	local menu = UI.new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromOffset(menuW, menuH), Parent = screen })
	local TOP_Y = touch and UDim2.new(1, -14, 0, 12) or UDim2.new(1, -18, 0.5, -math.floor(menuH / 2) - 14)
	menu.AnchorPoint = Vector2.new(1, 0)
	menu.Position = TOP_Y
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(BTN, BTN)
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = menu
	hud.MenuButtons = {}
	for i, d in ipairs(menuDefs) do
		local accent = d[3]
		local holder = UI.new("Frame", { Name = d[1], BackgroundTransparency = 1, LayoutOrder = i, Parent = menu })
		local face = UI.new("TextButton", { Name = "Face", AutoButtonColor = false, Text = "", Size = UDim2.fromScale(1, 1), Parent = holder })
		local rim = UI.Glass(face, 18, 0.16)
		-- цветное «свечение» снизу плитки и акцентная полоска
		local glow = UI.new("Frame", { BackgroundColor3 = accent, Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.new(0, 0, 0.38, 0), ZIndex = 1, Parent = face })
		UI.Corner(glow, 18)
		local gg = Instance.new("UIGradient")
		gg.Rotation = 90
		gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.45) })
		gg.Parent = glow
		local bar = UI.new("Frame", { BackgroundColor3 = accent, Size = UDim2.new(0.42, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), ZIndex = 2, Parent = face })
		UI.Corner(bar, UDim.new(1, 0))
		local ic = Icons2D.New(face, d[4], math.floor(BTN * 0.56), { ZIndex = 4 })
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, math.floor(BTN * 0.06))
		local label = txt(face, d[2], math.floor(BTN * 0.19), { Size = UDim2.new(1, -4, 0, math.floor(BTN * 0.24)), Position = UDim2.new(0, 2, 1, -math.floor(BTN * 0.33)), ZIndex = 5 })
		local badge = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 72, 96), Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -15, 0, -7), Visible = false, ZIndex = 8, Parent = holder })
		UI.Corner(badge, UDim.new(1, 0))
		UI.Stroke(badge, 2.5, Color3.new(1, 1, 1), true)
		txt(badge, "!", 16, { ZIndex = 9, StrokeThickness = 0 })
		local badgeScale = Instance.new("UIScale")
		badgeScale.Parent = badge
		local hs = UI.Bounce(face, holder)
		face.MouseEnter:Connect(function()
			Icons2D.Wiggle(ic)
			rim.Color = accent
			rim.Transparency = 0
		end)
		face.MouseLeave:Connect(function()
			rim.Color = Color3.new(1, 1, 1)
			rim.Transparency = 0.78
		end)
		local b = { Holder = holder, Face = face, Activated = face.Activated, Badge = badge, BadgeScale = badgeScale, Label = label, DefaultText = d[2], Icon = ic, Scale = hs }
		face.Activated:Connect(function()
			Icons2D.Bounce(ic, 1.2)
			ctx.OpenPanel(d[1])
		end)
		hud.MenuButtons[d[1]] = b
	end

	-- кнопка панели разработчика (видна только админам; на ПК ещё и клавиша F2)
	local adminBtn = UI.Button({ Parent = screen, Glyph = "Shield", Color = Color3.fromRGB(255, 84, 110), Size = UDim2.fromOffset(50, 50), Radius = 25 })
	adminBtn.Holder.AnchorPoint = Vector2.new(1, 0)
	adminBtn.Holder.Position = touch and UDim2.new(1, -(menuW + 26), 0, 12) or UDim2.new(1, -18, 0, 16)
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
	passList.CellSize = UDim2.fromOffset(40, 40)
	passList.CellPadding = UDim2.fromOffset(6, 6)
	passList.SortOrder = Enum.SortOrder.LayoutOrder
	passList.Parent = passRow
	if touch then
		passRow.AnchorPoint = Vector2.new(1, 0)
		passRow.Position = UDim2.new(1, -14, 0, menuH + 22)
		passList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	else
		passRow.Position = UDim2.fromOffset(18, 16)
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
		passRow.Size = UDim2.fromOffset(math.min(#owned, perRow) * 46, math.ceil(#owned / perRow) * 46)
		for i, def in ipairs(owned) do
			local col = c3(def.Color)
			local f = UI.new("Frame", { Size = UDim2.fromOffset(40, 40), LayoutOrder = i, Parent = passRow })
			local st = UI.Glass(f, UDim.new(1, 0), 0.2)
			st.Color = col
			st.Transparency = 0.1
			local ic = Icons2D.New(f, def.Glyph, 30, { ZIndex = 4 })
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.fromScale(0.5, 0.5)
			hoverTip({ Frame = f }, f, def.Name, function()
				return def.Desc
			end, touch and "left" or "below")
		end
	end

	---------------------------------------------------------------- слева: рюкзак, валюты, характеристики
	local COLW = 268
	local right = UI.new("Frame", { Name = "Currencies", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, touch and 0 or 0.5), Position = touch and UDim2.fromOffset(14, 8) or UDim2.new(0, 18, 0.5, -8), Size = UDim2.fromOffset(COLW, 236), Parent = screen })
	local coins = counter(right, COLW, 58, UDim2.fromOffset(0, 66), "Coin", Color3.fromRGB(255, 186, 30), function()
		ctx.OpenPanel("Donate")
	end, GOLD)
	local shards = counter(right, COLW - 44, 50, UDim2.fromOffset(0, 128), "Shard", Color3.fromRGB(190, 90, 255), nil, Color3.fromRGB(214, 150, 255))
	-- характеристики: три стеклянных чипа
	local statRow = UI.new("Frame", { Name = "StatRow", BackgroundTransparency = 1, Size = UDim2.fromOffset(COLW, 36), Position = UDim2.fromOffset(16, 186), Parent = right })
	UI.List(statRow, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left)
	local function chip(order, glyph, vecColor)
		local f = UI.new("Frame", { Size = UDim2.fromOffset(80, 34), LayoutOrder = order, Parent = statRow })
		UI.Glass(f, UDim.new(1, 0), 0.22)
		local ic = Icons2D.New(f, glyph, 28, { ZIndex = 3, Color = vecColor })
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, 2, 0.5, 0)
		local l = txt(f, "", 16, { Size = UDim2.new(1, -36, 1, -8), Position = UDim2.fromOffset(32, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
		return { Frame = f, Label = l }
	end
	local damage = chip(1, "Pickaxe", Color3.fromRGB(255, 160, 90))
	local petMult = chip(2, "Paw", Color3.fromRGB(140, 235, 140))
	local sellMult = chip(3, "Coin", GOLD)
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
	local top = UI.new("Frame", { Name = "TopInfo", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(470, 54), Parent = screen })
	if touch then
		top.Size = UDim2.fromOffset(400, 54)
	end
	local topPill = UI.new("Frame", { Size = UDim2.new(1, -128, 0, 46), Position = UDim2.fromOffset(18, 4), Parent = top })
	UI.Glass(topPill, UDim.new(1, 0), 0.16)
	local biomeBadge = UI.new("Frame", { BackgroundColor3 = UI.Colors.Green, Size = UDim2.fromOffset(54, 54), ZIndex = 3, Parent = top })
	UI.Corner(biomeBadge, UDim.new(1, 0))
	local biomeStroke = UI.Stroke(biomeBadge, 3, Color3.new(1, 1, 1), true)
	biomeStroke.Transparency = 0.2
	local biomeGrad = UI.Candy(biomeBadge, UI.Colors.Green)
	local biomeIconHolder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = biomeBadge })
	local biomeIcon
	local shownBiome = nil
	local paintedBiome = nil
	local function setBiomeIcon(b)
		if shownBiome == b then
			return
		end
		shownBiome = b
		if biomeIcon then
			biomeIcon:Destroy()
		end
		biomeIcon = Icons2D.New(biomeIconHolder, BIOME_GLYPHS[b] or "Globe", 38, { ZIndex = 4 })
		biomeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		biomeIcon.Position = UDim2.fromScale(0.5, 0.5)
	end
	setBiomeIcon(1)
	local biomeName = txt(topPill, "Карьер", 19, { Size = UDim2.new(0.5, -40, 0, 22), Position = UDim2.fromOffset(42, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local depthText = txt(topPill, "", 15, { Size = UDim2.new(0.5, -10, 0, 22), Position = UDim2.new(0.5, -6, 0, 5), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = SOFT, ZIndex = 3 })
	local depthTrack = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 8, 24), BackgroundTransparency = 0.2, Size = UDim2.new(1, -60, 0, 8), Position = UDim2.fromOffset(42, 30), ZIndex = 2, Parent = topPill })
	UI.Corner(depthTrack, UDim.new(1, 0))
	local depthFill = UI.new("Frame", { BackgroundColor3 = UI.Colors.Green, Size = UDim2.fromScale(0, 1), ZIndex = 3, Parent = depthTrack })
	UI.Corner(depthFill, UDim.new(1, 0))
	UI.Gradient(depthFill, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210))
	-- таймер вайпа — отдельная капсула справа
	local timerPill = UI.new("Frame", { Size = UDim2.fromOffset(112, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Parent = top })
	UI.Glass(timerPill, UDim.new(1, 0), 0.16)
	local clock = Icons2D.New(timerPill, "Clock", 38, { ZIndex = 3 })
	clock.AnchorPoint = Vector2.new(0, 0.5)
	clock.Position = UDim2.new(0, 2, 0.5, 0)
	local timerText = txt(timerPill, "20:00", 21, { Size = UDim2.new(1, -48, 1, -12), Position = UDim2.fromOffset(42, 6), ZIndex = 3, TextXAlignment = Enum.TextXAlignment.Left })
	hoverTip(timerPill, timerPill, "Вайп шахты", function()
		return "Каждые 20 минут шахта восстанавливается. После — Золотая лихорадка."
	end, "below")

	---------------------------------------------------------------- бафы
	local buffRow = UI.new("Frame", { Name = "Buffs", BackgroundTransparency = 1, Size = UDim2.fromOffset(360, 80), Parent = screen })
	local buffList = UI.List(buffRow, 10, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Bottom)
	if touch then
		buffRow.AnchorPoint = Vector2.new(0, 0)
		buffRow.Position = UDim2.fromOffset(14, 262)
		buffList.VerticalAlignment = Enum.VerticalAlignment.Top
	else
		buffRow.AnchorPoint = Vector2.new(0, 1)
		buffRow.Position = UDim2.new(0, 18, 1, -18)
	end
	local buffChips = {}
	local function buffChip(id, title, desc, glyph, color, order)
		local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(62, 80), LayoutOrder = order, Visible = false, Parent = buffRow })
		local box = UI.new("Frame", { Size = UDim2.fromOffset(62, 62), Parent = holder })
		local st = UI.Glass(box, 18, 0.16)
		st.Color = color
		st.Transparency = 0.15
		local glow = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), Parent = box })
		UI.Corner(glow, 18)
		local gg = Instance.new("UIGradient")
		gg.Rotation = 90
		gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.5) })
		gg.Parent = glow
		local ic = Icons2D.New(box, glyph, 44, { ZIndex = 3 })
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.44)
		-- полоса оставшегося времени по низу значка
		local barBg = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(8, 6, 20), BackgroundTransparency = 0.25, Size = UDim2.new(1, -14, 0, 6), Position = UDim2.new(0, 7, 1, -11), ZIndex = 4, Parent = box })
		UI.Corner(barBg, 3)
		local bar = UI.new("Frame", { BackgroundColor3 = UI.Lighter(color, 0.2), Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = barBg })
		UI.Corner(bar, 3)
		local timer = txt(holder, "0:00", 16, { Size = UDim2.new(1, 20, 0, 18), Position = UDim2.new(0, -10, 1, -17), ZIndex = 6 })
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
	local packHolder = UI.new("Frame", { Name = "Backpack", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(COLW, 58), Parent = right })
	local packPill = UI.new("Frame", { Size = UDim2.new(1, -16, 0, 46), Position = UDim2.fromOffset(16, 12), Parent = packHolder })
	UI.Glass(packPill, UDim.new(1, 0), 0.16)
	local packTrack = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(8, 6, 22), BackgroundTransparency = 0.25, Size = UDim2.new(1, -58, 0, 26), Position = UDim2.fromOffset(46, 10), ZIndex = 2, Parent = packPill })
	UI.Corner(packTrack, UDim.new(1, 0))
	local packFill = UI.new("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), ZIndex = 3, Parent = packTrack })
	UI.Corner(packFill, UDim.new(1, 0))
	local packGrad = UI.Candy(packFill, UI.Colors.Yellow)
	UI.Gloss(packFill, UDim2.new(1, -8, 0.45, 0), UDim2.fromOffset(4, 2), 0.5, 4)
	local packText = txt(packTrack, "0 / 0", 18, { Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), ZIndex = 5 })
	local packIcon = Icons2D.New(packHolder, "Backpack", 58, { ZIndex = 4, Color = Color3.fromRGB(255, 170, 70) })
	packIcon.AnchorPoint = Vector2.new(0, 0.5)
	packIcon.Position = UDim2.new(0, -4, 0, 35)
	local packScale = Instance.new("UIScale")
	packScale.Parent = packHolder
	local packInfo = txt(packHolder, "", 14, { Size = UDim2.new(1, -66, 0, 16), Position = UDim2.fromOffset(62, -6), TextColor3 = Color3.fromRGB(255, 226, 130), TextXAlignment = Enum.TextXAlignment.Left })
	local packBar = { Frame = packTrack, Fill = packFill }
	local packLast = -1
	function packBar.Set(frac, text)
		packText.Text = text
		frac = math.clamp(frac, 0, 1)
		if frac ~= packLast then
			packLast = frac
			TweenService:Create(packFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(frac < 0.001 and 0 or math.max(frac, 0.08), 1) }):Play()
		end
	end
	local packColor
	local function setPackColor(c)
		if packColor ~= c then
			packColor = c
			packGrad.Color = UI.CandySeq(c)
		end
	end

	---------------------------------------------------------------- «На базу»
	local TPS = touch and 78 or 88
	local tp = UI.Button({ Parent = screen, Name = "Teleport", Color = UI.Colors.Teal, Size = UDim2.fromOffset(TPS, TPS), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -24), Radius = 26 })
	if touch then
		tp.Holder.AnchorPoint = Vector2.new(0.5, 1)
		tp.Holder.Position = UDim2.new(0.5, 0, 1, -12)
	end
	local homeIcon = Icons2D.New(tp.Face, "Home", math.floor(TPS * 0.62), { ZIndex = 4 })
	homeIcon.AnchorPoint = Vector2.new(0.5, 0)
	homeIcon.Position = UDim2.new(0.5, 0, 0, math.floor(TPS * 0.04))
	local tpLabel = UI.Text(tp.Face, touch and "БАЗА" or "НА БАЗУ", { Size = UDim2.new(1, -8, 0, math.floor(TPS * 0.24)), Position = UDim2.new(0, 4, 1, -math.floor(TPS * 0.3)), MaxText = 17, ZIndex = 5, StrokeThickness = 2 })
	local tls = tpLabel:FindFirstChildOfClass("UIStroke")
	if tls then
		tls.Color = UI.Edge(UI.Colors.Teal)
	end
	local key = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, -9, 0, -9), ZIndex = 8, Visible = not touch, Parent = tp.Holder })
	UI.Corner(key, 8)
	UI.Stroke(key, 2.5, UI.Edge(UI.Colors.Teal), true)
	UI.Text(key, "T", { ZIndex = 9, MaxText = 17, TextColor3 = UI.Edge(UI.Colors.Teal), Stroke = false })
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
	local toastArea = UI.new("Frame", { Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.fromOffset(520, 260), Parent = screen })
	UI.List(toastArea, 6, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
	local TOAST_COLORS = { info = UI.Colors.Blue, good = UI.Colors.Green, warn = UI.Colors.Orange, error = UI.Colors.Red, seed = UI.Colors.Teal, unlock = UI.Colors.Purple }
	local TOAST_ICONS = { info = "Quest", good = "Check", warn = "Clock", error = "Close", seed = "Sprout", unlock = "Star" }
	local toastOrder = 0
	function hud.Toast(text, kind)
		kind = kind or "info"
		toastOrder = toastOrder + 1
		local col = TOAST_COLORS[kind] or UI.Colors.Blue
		local holder = UI.new("Frame", { Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = toastOrder, Parent = toastArea })
		local st = UI.Glass(holder, UDim.new(1, 0), 0.1)
		st.Color = col
		st.Transparency = 0.25
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 5)
		pad.PaddingRight = UDim.new(0, 18)
		pad.Parent = holder
		UI.List(holder, 10, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
		local dot = UI.new("Frame", { BackgroundColor3 = col, Size = UDim2.fromOffset(32, 32), LayoutOrder = 1, Parent = holder })
		UI.Corner(dot, UDim.new(1, 0))
		UI.Candy(dot, col)
		local glyph = TOAST_ICONS[kind] or "Star"
		local ic = Icons2D.New(dot, glyph, Icons2D.HasImage(glyph) and 30 or 22, { ZIndex = 3, Shadow = false })
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		local l = txt(holder, text, 18, { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextScaled = false, TextSize = 18, LayoutOrder = 2 })
		l.Size = UDim2.fromOffset(0, 26)
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
	local banner = UI.new("Frame", { Name = "Banner", BackgroundColor3 = UI.Colors.Yellow, Size = UDim2.fromOffset(640, 66), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176), Visible = false, Parent = screen })
	UI.Corner(banner, UDim.new(1, 0))
	local bannerStroke = UI.Stroke(banner, 3, Color3.new(1, 1, 1), true)
	bannerStroke.Transparency = 0.1
	local bannerGrad = UI.Candy(banner, UI.Colors.Yellow)
	UI.Gloss(banner, UDim2.new(1, -40, 0.45, 0), UDim2.fromOffset(20, 3), 0.45)
	local bannerLabel = UI.Text(banner, "", { Size = UDim2.new(1, -36, 1, -16), Position = UDim2.fromOffset(18, 8), MaxText = 30, StrokeThickness = 2.5 })
	local bannerToken = 0
	function hud.Banner(text, color, duration, pulse)
		bannerToken = bannerToken + 1
		local my = bannerToken
		banner.Visible = true
		bannerGrad.Color = UI.CandySeq(color)
		local bs = bannerLabel:FindFirstChildOfClass("UIStroke")
		if bs then
			bs.Color = UI.Edge(color)
		end
		bannerLabel.Text = text
		UI.Pop(banner, 0.5)
		if pulse then
			task.spawn(function()
				local s = banner:FindFirstChildOfClass("UIScale")
				while bannerToken == my and banner.Visible and s do
					TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Sine), { Scale = 1.04 }):Play()
					task.wait(0.25)
					TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
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
		-- «+сумма» с монеткой всплывает справа от счётчика и тает
		local base = right.Position + (touch and UDim2.fromOffset(60, 238) or UDim2.fromOffset(COLW + 8, 60))
		local f = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 40), Position = base, Parent = screen })
		local ic = Icons2D.New(f, "Coin", 34, { ZIndex = 3, Color = GOLD })
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, 0, 0.5, 0)
		local l = txt(f, "+" .. Util.Format(amount), 28, { Size = UDim2.new(1, -38, 1, 0), Position = UDim2.fromOffset(38, 0), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, StrokeThickness = 2.4 })
		UI.Pop(f, 0.4)
		TweenService:Create(f, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = base - UDim2.fromOffset(0, 46) }):Play()
		task.delay(0.6, function()
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			local ls = l:FindFirstChildOfClass("UIStroke")
			if ls then
				TweenService:Create(ls, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
			local img = ic:FindFirstChild("Image")
			if img then
				TweenService:Create(img, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
			else
				ic.Visible = false
			end
		end)
		task.delay(1.2, function()
			f:Destroy()
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
		packInfo.Text = full and "РЮКЗАК ПОЛОН — ПРОДАЙ!" or (cnt > 0 and ("РЮКЗАК · ≈ " .. Util.Format(worth)) or "РЮКЗАК")
		packInfo.TextColor3 = full and Color3.fromRGB(255, 120, 110) or Color3.fromRGB(255, 226, 130)
		setPackColor(full and UI.Colors.Red or (infinite and Color3.fromRGB(255, 90, 160) or UI.Colors.Yellow))
		if cnt > lastCount then
			packScale.Scale = 1.04
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
		if paintedBiome ~= b then
			paintedBiome = b
			biomeGrad.Color = UI.CandySeq(uic)
			setBiomeIcon(b)
		end
		biomeName.Text = biome.Short
		depthText.Text = Util.Commas(dm) .. " / " .. Util.Commas(biome.MaxDepth) .. " м"
	end)

	hud.Screen = screen
	hud.Coins = coins
	hud.Teleport = tp
	hud.Backpack = packHolder
	hud.TopInfo = top
	return hud
end

return HUD
