-- Panels: окна интерфейса — питомцы, сумка, магазин, инкубатор, ребёрс, миры,
-- диалог Drill-Bot 3000 и окно яйца с шансами.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs:WaitForChild("Balance"))
local PetsData = require(Configs:WaitForChild("PetsData"))
local EggsData = require(Configs:WaitForChild("EggsData"))
local SeedsData = require(Configs:WaitForChild("SeedsData"))
local BoostsData = require(Configs:WaitForChild("BoostsData"))
local DrillsData = require(Configs:WaitForChild("DrillsData"))
local BackpacksData = require(Configs:WaitForChild("BackpacksData"))
local BiomesData = require(Configs:WaitForChild("BiomesData"))
local RebirthData = require(Configs:WaitForChild("RebirthData"))
local QuestsData = require(Configs:WaitForChild("QuestsData"))
local GamepassesData = require(Configs:WaitForChild("GamepassesData"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local Stats = require(Shared:WaitForChild("Stats"))

local UI = require(script.Parent.UIKit)
local Icons2D = require(script.Parent.Icons2D)
local EggOpening = require(script.Parent.EggOpening)

local GOLD = Color3.fromRGB(255, 208, 64)
-- Цветной кружок с белой однотонной иконкой
local function glyphBadge(parent, glyph, size, color, pos)
	local b = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), Parent = parent })
	UI.Corner(b, UDim.new(1, 0))
	UI.Stroke(b, 3, UI.Edge(color), true)
	UI.Gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
	local ic = Icons2D.New(b, glyph, math.floor(size * 0.7), { ZIndex = 3, Ink = UI.Edge(color) })
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.47)
	return b, ic
end

local Panels = {}
local player = Players.LocalPlayer

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function rarityColor(r)
	local def = PetsData.Rarity[r]
	return def and c3(def.Color) or UI.Colors.Gray
end

local function clear(frame, keepLayouts)
	for _, c in ipairs(frame:GetChildren()) do
		if not (keepLayouts and (c:IsA("UIListLayout") or c:IsA("UIGridLayout") or c:IsA("UIPadding"))) then
			c:Destroy()
		end
	end
end

local function invoke(ctx, remote, ...)
	local ok, res = pcall(function(...)
		return Net.Get(remote):InvokeServer(...)
	end, ...)
	if not ok then
		ctx.Toast("Ошибка соединения, попробуй ещё раз", "error")
		return nil
	end
	if res and not res.ok and res.msg and res.msg ~= "" then
		ctx.Toast(res.msg, "warn")
		ctx.Sound.Play("Error")
	end
	return res
end

local function card(parent, size, color, order)
	local holder, face = UI.Plate(parent, size, nil, color, 14)
	holder.LayoutOrder = order or 0
	UI.Gradient(face, Color3.new(1, 1, 1), Color3.fromRGB(215, 212, 230))
	return holder, face
end

local function fmtMult(bonus)
	return "x" .. string.format(bonus < 9 and "%.2f" or "%.1f", 1 + bonus)
end

local TIER_COLORS = {
	nil,
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(255, 120, 220),
	Color3.fromRGB(150, 240, 255),
}

local function tierName(t)
	local d = Balance.PetTiers[(t or 0) + 1]
	return d and d.Name or ""
end

-- значок улучшения на карточке: звёзды или плашка ЗОЛ/РАД
local function tierBadge(parent, t, pos, size)
	t = t or 0
	if t <= 0 then
		return
	end
	local d = Balance.PetTiers[t + 1]
	local f = UI.new("Frame", { BackgroundColor3 = t >= 5 and Color3.fromRGB(190, 90, 255) or (t == 4 and Color3.fromRGB(230, 160, 30) or Color3.fromRGB(40, 32, 70)), BackgroundTransparency = 0.05, Size = UDim2.fromOffset((t == 6 and 64) or size or 52, 20), Position = pos, ZIndex = 6, Parent = parent })
	UI.Corner(f, UDim.new(1, 0))
	UI.Stroke(f, 2, UI.Ink, true)
	if t == 6 then
		UI.Gradient(f, Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 120, 220), 0)
	elseif t >= 5 then
		UI.Gradient(f, Color3.fromRGB(255, 120, 120), Color3.fromRGB(110, 180, 255), 0)
	end
	local l = UI.Text(f, t <= 3 and d.Short or d.Short, { Size = UDim2.new(1, -4, 1, -2), Position = UDim2.fromOffset(2, 1), MaxText = 16, ZIndex = 7, TextColor3 = t <= 3 and Color3.fromRGB(255, 220, 80) or Color3.new(1, 1, 1), StrokeThickness = 1.5 })
	return f, l
end

local function statLine(parent, glyph, color, pos, size, z)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = size, Position = pos, ZIndex = z or 3, Parent = parent })
	local ic = Icons2D.New(row, glyph, math.floor(size.Y.Offset), { Color = color, Shadow = false, ZIndex = (z or 3) + 1 })
	ic.Position = UDim2.fromOffset(0, 0)
	local t = UI.Text(row, "", { Size = UDim2.new(1, -size.Y.Offset - 2, 1, 0), Position = UDim2.fromOffset(size.Y.Offset + 2, 0), TextXAlignment = Enum.TextXAlignment.Left, MaxText = math.floor(size.Y.Offset), ZIndex = (z or 3) + 1, StrokeThickness = 2 })
	return t, row
end

---------------------------------------------------------------------------------------------
-- Питомцы
---------------------------------------------------------------------------------------------
local DMG_COLOR = Color3.fromRGB(255, 150, 90)
local SELL_COLOR = Color3.fromRGB(255, 214, 70)

-- цветная «таблетка» со значком и текстом (как счётчики HUD)
local function pill(parent, glyph, color, size, pos, order)
	local f = UI.new("Frame", { BackgroundColor3 = color, Size = size, Position = pos or UDim2.new(), LayoutOrder = order or 0, Parent = parent })
	UI.Corner(f, UDim.new(1, 0))
	UI.Stroke(f, 3, UI.Edge(color), true)
	UI.Gradient(f, UI.Lighter(color, 0.25), UI.Darker(color, 0.12))
	local h = size.Y.Offset
	local ic = Icons2D.New(f, glyph, math.floor(h * 0.78), { Ink = UI.Edge(color), ZIndex = 4 })
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, 4, 0.5, -1)
	local t = UI.Text(f, "", { Size = UDim2.new(1, -(h + 12), 1, -10), Position = UDim2.fromOffset(h + 4, 5), TextXAlignment = Enum.TextXAlignment.Left, MaxText = math.floor(h * 0.55), ZIndex = 4 })
	local st = t:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = UI.Edge(color)
	end
	return t, f
end

-- карточка питомца: градиент цвета редкости, модель, тёмная полоска со статами снизу
local function petCard(parent, size, col, order, mode)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = size, LayoutOrder = order or 0, Parent = parent })
	local shadow = UI.new("Frame", { BackgroundColor3 = UI.Darker(col, 0.45), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 4), Parent = holder })
	UI.Corner(shadow, 18)
	local face = UI.new("Frame", { BackgroundColor3 = col, Size = UDim2.fromScale(1, 1), Parent = holder })
	UI.Corner(face, 18)
	local stroke = UI.Stroke(face, 3, UI.Edge(col), true)
	if mode == "rainbow" then
		UI.Gradient(face, Color3.fromRGB(255, 170, 210), Color3.fromRGB(150, 200, 255), 35)
	elseif mode == "shiny" then
		UI.Gradient(face, Color3.fromRGB(190, 250, 255), Color3.fromRGB(255, 190, 240), 35)
	else
		UI.Gradient(face, UI.Lighter(col, 0.6), col)
	end
	local shine = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Size = UDim2.new(1, -16, 0, 10), Position = UDim2.fromOffset(8, 4), ZIndex = 2, Parent = face })
	UI.Corner(shine, UDim.new(1, 0))
	local strip = UI.new("Frame", { BackgroundColor3 = UI.Darker(col, 0.55), BackgroundTransparency = 0.1, Size = UDim2.new(1, -10, 0, 46), Position = UDim2.new(0, 5, 1, -51), ZIndex = 3, Parent = face })
	UI.Corner(strip, 12)
	return holder, face, strip, stroke
end

local function chipText(parent, text, color, size, pos, z)
	local f = UI.new("Frame", { BackgroundColor3 = color, BackgroundTransparency = 0.15, Size = size, Position = pos, ZIndex = z or 6, Parent = parent })
	UI.Corner(f, UDim.new(1, 0))
	local l = UI.Text(f, text, { Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), MaxText = size.Y.Offset - 4, ZIndex = (z or 6) + 1, StrokeThickness = 1.5 })
	return f, l
end

local function buildPets(screen, ctx)
	local win = UI.Window(screen, { Name = "Pets", Title = "ПИТОМЦЫ", Color = UI.Colors.Orange, Size = UDim2.fromOffset(860, 540) })
	local c = win.Content
	-- верхняя строка: показатели слева, кнопки справа
	local topBar = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -258, 0, 48), Parent = c })
	UI.List(topBar, 10, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	local infoSlots = pill(topBar, "Paw", UI.Colors.Orange, UDim2.fromOffset(104, 42), nil, 1)
	local infoStore, storeF = pill(topBar, "Chest", UI.Colors.Purple, UDim2.fromOffset(128, 42), nil, 2)
	local buyStore = UI.Button({ Parent = topBar, Glyph = "Plus", Color = UI.Colors.Green, Size = UDim2.fromOffset(42, 42), LayoutOrder = 3, Radius = 21 })
	local infoDmg = pill(topBar, "Pickaxe", Color3.fromRGB(255, 96, 86), UDim2.fromOffset(112, 42), nil, 4)
	local infoSell = pill(topBar, "Coin", Color3.fromRGB(255, 176, 30), UDim2.fromOffset(112, 42), nil, 5)
	local btnBar = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(258, 48), Parent = c })
	UI.List(btnBar, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local best = UI.Button({ Parent = btnBar, Text = "Лучшие", Color = UI.Colors.Green, Size = UDim2.fromOffset(104, 42), LayoutOrder = 1, TextSize = 18, Radius = 21, Glyph = "Star" })
	local none = UI.Button({ Parent = btnBar, Text = "Снять", Color = UI.Colors.Orange, Size = UDim2.fromOffset(92, 42), LayoutOrder = 2, TextSize = 18, Radius = 21, Glyph = "Close" })
	local multi = UI.Button({ Parent = btnBar, Glyph = "Check", Color = UI.Colors.Red, Size = UDim2.fromOffset(46, 42), LayoutOrder = 3, Radius = 21 })
	-- докупить +10 мест: первый клик показывает цену, второй (в течение 4 с) — покупает
	local confirmUntil = 0
	buyStore.Activated:Connect(function()
		local data = ctx.ClientState.Data
		local cost = data and Stats.PetStorageCost(data)
		if not cost then
			ctx.Toast("Куплено максимум мест за монеты. Ещё +100 — геймпасс в «Донате»", "info")
			return
		end
		if os.clock() > confirmUntil then
			confirmUntil = os.clock() + 4
			ctx.Toast("+" .. Balance.PetStorageStep .. " мест за " .. Util.Format(cost) .. " монет — нажми «+» ещё раз", "info")
			return
		end
		confirmUntil = 0
		invoke(ctx, "BuyPetStorage")
	end)
	best.Activated:Connect(function()
		invoke(ctx, "PetAction", "EquipBest")
	end)
	none.Activated:Connect(function()
		invoke(ctx, "PetAction", "UnequipAll")
	end)

	-- сетка питомцев на светлой подложке
	local well = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 244, 232), BackgroundTransparency = 0.15, Size = UDim2.new(1, -286, 1, -60), Position = UDim2.fromOffset(0, 58), Parent = c })
	UI.Corner(well, 18)
	UI.Stroke(well, 3, Color3.fromRGB(240, 200, 160), true)
	local scroll = UI.Scroll(well, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(112, 146)
	grid.CellPadding = UDim2.fromOffset(10, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	UI.Padding(scroll, 8)
	-- мультиудаление: режим выбора, нижняя панель и подтверждение
	local selectMode, selectedKeys, cardRefs, stacksByKey = false, {}, {}, {}
	local selBar = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 40, 70), BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 54), ZIndex = 20, Visible = false, Parent = well })
	UI.Corner(selBar, 18)
	local selText = UI.Text(selBar, "", { Size = UDim2.new(1, -300, 1, -12), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 19, ZIndex = 21 })
	local delSel = UI.Button({ Parent = selBar, Text = "Удалить", Glyph = "Close", Color = UI.Colors.Red, Size = UDim2.fromOffset(140, 42), Position = UDim2.new(1, -290, 0, 5), TextSize = 19, Radius = 21 })
	delSel.Holder.ZIndex = 22
	local cancelSel = UI.Button({ Parent = selBar, Text = "Отмена", Color = UI.Colors.Gray, Size = UDim2.fromOffset(130, 42), Position = UDim2.new(1, -140, 0, 5), TextSize = 19, Radius = 21 })
	cancelSel.Holder.ZIndex = 22
	local confirm = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 14, 34), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false, Parent = c })
	UI.Corner(confirm, 20)
	local _, cbox = UI.Plate(confirm, UDim2.fromOffset(420, 190), UDim2.new(0.5, -210, 0.5, -95), Color3.new(1, 1, 1), 22)
	cbox.Parent.ZIndex = 41
	local cText = UI.Text(cbox, "", { Size = UDim2.new(1, -30, 0, 80), Position = UDim2.fromOffset(15, 14), MaxText = 22, TextWrapped = true, TextColor3 = Color3.fromRGB(70, 56, 90), Stroke = false, ZIndex = 42 })
	local yes = UI.Button({ Parent = cbox, Text = "Да, удалить", Color = UI.Colors.Red, Size = UDim2.fromOffset(180, 50), Position = UDim2.new(0.5, -190, 1, -66), TextSize = 20, Radius = 24 })
	local no = UI.Button({ Parent = cbox, Text = "Нет", Color = UI.Colors.Gray, Size = UDim2.fromOffset(170, 50), Position = UDim2.new(0.5, 10, 1, -66), TextSize = 20, Radius = 24 })

	local function selectedCount()
		local n = 0
		for key in pairs(selectedKeys) do
			local st = stacksByKey[key]
			if st then
				n = n + (st.count - st.equipped)
			end
		end
		return n
	end
	local function paintSelection()
		for key, ref in pairs(cardRefs) do
			local on = selectMode and selectedKeys[key] == true
			ref.mark.Visible = on
			if on then
				ref.stroke.Color = UI.Colors.Red
				ref.stroke.Thickness = 4
			else
				ref.stroke.Color = ref.baseColor
				ref.stroke.Thickness = ref.baseThick
			end
		end
		selBar.Visible = selectMode
		selText.Text = "Выбрано: " .. selectedCount() .. " (надетые не удаляются)"
	end
	local function setSelectMode(on)
		selectMode = on
		selectedKeys = {}
		multi.SetColor(on and UI.Colors.Gray or UI.Colors.Red)
		paintSelection()
	end
	multi.Activated:Connect(function()
		setSelectMode(not selectMode)
		if selectMode then
			ctx.Toast("Нажимай на питомцев, которых хочешь удалить", "info")
		end
	end)
	cancelSel.Activated:Connect(function()
		setSelectMode(false)
	end)
	delSel.Activated:Connect(function()
		local n = selectedCount()
		if n == 0 then
			ctx.Toast("Ничего не выбрано", "warn")
			return
		end
		cText.Text = "Удалить " .. n .. " питомцев?\nЭто нельзя отменить."
		confirm.Visible = true
		UI.Pop(cbox.Parent, 0.7)
	end)
	no.Activated:Connect(function()
		confirm.Visible = false
	end)
	yes.Activated:Connect(function()
		confirm.Visible = false
		local keys = {}
		for key in pairs(selectedKeys) do
			table.insert(keys, key)
		end
		local res = invoke(ctx, "PetAction", "DeleteMany", keys)
		if res and res.ok then
			ctx.Sound.Play("Coins")
			setSelectMode(false)
		end
	end)

	local empty = UI.Text(well, "Пока нет питомцев — открой яйцо на базе!", { Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 0.5, -15), MaxText = 22, TextColor3 = Color3.fromRGB(200, 140, 90), Visible = false })

	-- панель деталей
	local _, detail = UI.Plate(c, UDim2.new(0, 274, 1, -60), UDim2.new(1, -274, 0, 58), Color3.new(1, 1, 1), 20)
	local hero = UI.new("Frame", { BackgroundColor3 = UI.Colors.Orange, Size = UDim2.new(1, -12, 0, 118), Position = UDim2.fromOffset(6, 6), Parent = detail })
	UI.Corner(hero, 16)
	local heroGrad = UI.Gradient(hero, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local heroStroke = UI.Stroke(hero, 3, UI.Edge(UI.Colors.Orange), true)
	local dvpHolder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, -8), Position = UDim2.fromOffset(5, 4), Parent = hero })
	local dName = UI.Text(detail, "Выбери питомца", { Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 128), MaxText = 24, TextColor3 = Color3.fromRGB(70, 56, 90), StrokeThickness = 0, Stroke = false })
	local dRarityF, dRarity = chipText(detail, "", UI.Colors.Gray, UDim2.fromOffset(200, 22), UDim2.new(0.5, -100, 0, 157), 3)
	local dStats = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 184), Parent = detail })
	UI.List(dStats, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	local dDmg, dDmgRow = pill(dStats, "Pickaxe", Color3.fromRGB(255, 96, 86), UDim2.fromOffset(124, 32), nil, 1)
	local dSell, dSellRow = pill(dStats, "Coin", Color3.fromRGB(255, 176, 30), UDim2.fromOffset(124, 32), nil, 2)
	local dLevel = UI.Text(detail, "", { Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 220), MaxText = 15, TextColor3 = Color3.fromRGB(90, 150, 220), Stroke = false })
	local xpBar = UI.Bar(detail, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 240), UI.Colors.Teal, Color3.fromRGB(70, 66, 100))
	local dAura = UI.Text(detail, "", { Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 262), TextColor3 = Color3.fromRGB(110, 100, 140), MaxText = 13, TextWrapped = true, Stroke = false })
	local equipBtn = UI.Button({ Parent = detail, Text = "Надеть", Color = UI.Colors.Green, Size = UDim2.new(1, -24, 0, 38), Position = UDim2.new(0, 12, 1, -134), TextSize = 20, Radius = 19 })
	local upBtn = UI.Button({ Parent = detail, Text = "Улучшить", Color = UI.Colors.Yellow, Size = UDim2.new(1, -24, 0, 38), Position = UDim2.new(0, 12, 1, -91), TextSize = 19, Glyph = "Star", Radius = 19 })
	local delBtn = UI.Button({ Parent = detail, Text = "Удалить", Color = UI.Colors.Red, Size = UDim2.new(1, -24, 0, 38), Position = UDim2.new(0, 12, 1, -48), TextSize = 19, Radius = 19 })

	local selected = nil
	local signature = ""

	-- стаки: одинаковый Id + улучшение + уровень. Эксклюзивы (своя сила B) — отдельными карточками.
	local function buildStacks(data)
		local map, list = {}, {}
		local sameTier = {} -- [Id:T] = сколько всего (для улучшения)
		for uid, p in pairs(data.Pets or {}) do
			local key = p.B and uid or (p.Id .. ":" .. tostring(p.T or 0) .. ":" .. tostring(p.L or 1))
			local s = map[key]
			if not s then
				local db, sb = Stats.PetBonus(p)
				s = { key = key, id = p.Id, tier = p.T or 0, level = p.L or 1, uid = p.B and uid or nil, count = 0, equipped = 0, dmg = db, sell = sb, power = Stats.PetMult(p), pet = p }
				map[key] = s
				table.insert(list, s)
			end
			s.count = s.count + 1
			if p.E then
				s.equipped = s.equipped + 1
				s.pet = p
			end
			if not p.B then
				local tk = p.Id .. ":" .. tostring(p.T or 0)
				sameTier[tk] = (sameTier[tk] or 0) + 1
			end
		end
		table.sort(list, function(a, b)
			if (a.equipped > 0) ~= (b.equipped > 0) then
				return a.equipped > 0
			end
			if a.power ~= b.power then
				return a.power > b.power
			end
			return a.key < b.key
		end)
		return list, map, sameTier
	end

	local function cardColor(s)
		local def = PetsData.ById[s.id]
		if s.tier == 6 then
			return Color3.fromRGB(90, 210, 255)
		elseif s.tier >= 4 then
			return Color3.fromRGB(255, 196, 50)
		end
		return rarityColor(def and def.Rarity)
	end

	local shownKey = nil
	local tierCount = {}
	local function showDetail()
		local key = selected and (selected.id .. ":" .. selected.tier) or nil
		if key ~= shownKey then
			shownKey = key
			clear(dvpHolder)
			if selected then
				UI.Viewport(dvpHolder, ctx.PetModel(selected.id, selected.tier))
				tierBadge(dvpHolder, selected.tier, UDim2.fromOffset(4, 4), 60)
			end
		end
		if not selected then
			dName.Text = "Выбери питомца"
			dRarityF.Visible = false
			dDmgRow.Visible = false
			dSellRow.Visible = false
			dLevel.Text = ""
			xpBar.Frame.Visible = false
			dAura.Text = "Нажми на карточку слева, чтобы увидеть подробности"
			equipBtn.Holder.Visible = false
			upBtn.Holder.Visible = false
			delBtn.Holder.Visible = false
			hero.BackgroundColor3 = Color3.new(1, 1, 1)
			heroGrad.Color = ColorSequence.new(UI.Lighter(UI.Colors.Orange, 0.6), UI.Colors.Orange)
			return
		end
		local def = PetsData.ById[selected.id]
		local col = cardColor(selected)
		hero.BackgroundColor3 = Color3.new(1, 1, 1)
		heroStroke.Color = UI.Edge(col)
		if selected.tier == 6 then
			heroGrad.Color = ColorSequence.new(Color3.fromRGB(190, 250, 255), Color3.fromRGB(255, 190, 240))
		elseif selected.tier == 5 then
			heroGrad.Color = ColorSequence.new(Color3.fromRGB(255, 170, 210), Color3.fromRGB(150, 200, 255))
		else
			heroGrad.Color = ColorSequence.new(UI.Lighter(col, 0.6), col)
		end
		local tn = tierName(selected.tier)
		dName.Text = (def and def.Name or selected.id) .. (tn ~= "" and (" " .. tn) or "")
		local r = def and PetsData.Rarity[def.Rarity]
		dRarityF.Visible = true
		dRarityF.BackgroundColor3 = rarityColor(def and def.Rarity)
		dRarity.Text = (r and r.Name or "") .. (def and def.Chance > 0 and (" · " .. def.Chance .. "%") or "") .. (selected.count > 1 and (" · " .. selected.count .. " шт") or "")
		dDmgRow.Visible = true
		dSellRow.Visible = true
		dDmg.Text = fmtMult(selected.dmg)
		dSell.Text = fmtMult(selected.sell)
		local p = selected.pet
		local lvl = p.L or 1
		xpBar.Frame.Visible = true
		if lvl >= Balance.PetMaxLevel then
			dLevel.Text = "Уровень " .. lvl .. " (макс.)"
			xpBar.Set(1, "МАКС")
		else
			local need = Stats.PetXpNeed(lvl)
			dLevel.Text = "Уровень " .. lvl .. " · +" .. math.floor(Balance.PetLevelBonus * 100) .. "% силы за уровень"
			xpBar.Set((p.X or 0) / need, Util.Format(math.floor(p.X or 0)) .. " / " .. Util.Format(need))
		end
		dAura.Text = (def and def.Aura) and ("Аура: " .. def.Aura.Text) or ((def and def.Special) and def.Special or "Опыт идёт, пока питомец надет и ты ломаешь блоки")
		equipBtn.Holder.Visible = true
		delBtn.Holder.Visible = true
		local canEquip = selected.equipped < selected.count
		equipBtn.SetText(canEquip and "Надеть" or "Снять")
		equipBtn.SetColor(canEquip and UI.Colors.Green or UI.Colors.Orange)
		local nextTier = Balance.PetTiers[selected.tier + 2]
		if nextTier and (nextTier.NoCraft or selected.tier == 6) then
			nextTier = nil
		end
		upBtn.Holder.Visible = nextTier ~= nil and not selected.uid
		if nextTier then
			local have = tierCount[selected.id .. ":" .. selected.tier] or 0
			upBtn.SetText(nextTier.Name .. "  " .. math.min(have, nextTier.Cost) .. "/" .. nextTier.Cost)
			upBtn.SetEnabled(have >= nextTier.Cost)
		end
		delBtn.SetText(selected.uid and "Удалить" or "Удалить лишних")
	end

	equipBtn.Activated:Connect(function()
		if not selected then
			return
		end
		local canEquip = selected.equipped < selected.count
		if selected.uid then
			invoke(ctx, "PetAction", canEquip and "Equip" or "Unequip", selected.uid)
		else
			invoke(ctx, "PetAction", canEquip and "EquipStack" or "UnequipStack", selected.key)
		end
	end)
	upBtn.Activated:Connect(function()
		if not selected or selected.uid then
			return
		end
		local nextTier = Balance.PetTiers[selected.tier + 2]
		if nextTier and (tierCount[selected.id .. ":" .. selected.tier] or 0) >= nextTier.Cost then
			local res = invoke(ctx, "PetAction", "Upgrade", selected.id, selected.tier)
			if res and res.ok then
				ctx.Sound.Play("Upgrade")
				-- выделяем нового улучшенного питомца
				selected = { key = res.uid, id = selected.id, tier = res.tier, pending = true }
			end
		end
	end)
	delBtn.Activated:Connect(function()
		if not selected then
			return
		end
		if selected.uid then
			invoke(ctx, "PetAction", "Delete", selected.uid)
		else
			invoke(ctx, "PetAction", "DeleteStack", selected.key)
		end
	end)

	local function rebuild()
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		local list, map, sameTier = buildStacks(data)
		tierCount = sameTier
		stacksByKey = map
		local d = data.Derived or {}
		infoSlots.Text = #Stats.EquippedPets(data) .. "/" .. (d.PetSlots or 3)
		local cnt, cap = Stats.PetCount(data), Stats.PetStorage(data)
		infoStore.Text = cnt .. "/" .. cap
		infoStore.TextColor3 = cnt >= cap and Color3.fromRGB(255, 200, 200) or Color3.new(1, 1, 1)
		infoDmg.Text = "x" .. string.format("%.2f", Stats.PetSum(data))
		infoSell.Text = "x" .. string.format("%.2f", Stats.PetCoinFactor(data))
		empty.Visible = #list == 0
		local sig = {}
		for _, s in ipairs(list) do
			table.insert(sig, s.key .. "=" .. s.count .. "/" .. s.equipped)
		end
		local newSig = table.concat(sig, ";")
		if selected then
			if selected.pending then
				-- после улучшения ищем стак нового питомца
				local p = data.Pets and data.Pets[selected.key]
				if p then
					selected = map[p.Id .. ":" .. tostring(p.T or 0) .. ":" .. tostring(p.L or 1)]
				else
					selected = nil
				end
			else
				selected = map[selected.key]
			end
		end
		if newSig ~= signature then
			signature = newSig
			clear(scroll, true)
			cardRefs = {}
			for i, s in ipairs(list) do
				local col = cardColor(s)
				local holder, face, strip, stroke = petCard(scroll, UDim2.fromOffset(112, 146), col, i, (s.tier == 5 and "rainbow") or (s.tier == 6 and "shiny") or nil)
				UI.Viewport(face, ctx.PetModel(s.id, s.tier), UDim2.new(1, -8, 0, 84), UDim2.fromOffset(4, 8))
				local l1 = statLine(strip, "Pickaxe", DMG_COLOR, UDim2.fromOffset(6, 3), UDim2.new(1, -10, 0, 19), 4)
				l1.Text = fmtMult(s.dmg)
				local l2 = statLine(strip, "Coin", SELL_COLOR, UDim2.fromOffset(6, 24), UDim2.new(1, -10, 0, 19), 4)
				l2.Text = fmtMult(s.sell)
				chipText(face, "Ур." .. s.level, UI.Darker(col, 0.5), UDim2.fromOffset(44, 20), UDim2.fromOffset(6, 6), 6)
				if s.count > 1 then
					chipText(face, "x" .. s.count, Color3.fromRGB(40, 34, 60), UDim2.fromOffset(38, 20), UDim2.new(1, -44, 0, 70), 6)
				end
				tierBadge(face, s.tier, UDim2.fromOffset(6, 70), 52)
				if s.equipped > 0 then
					stroke.Color = Color3.fromRGB(60, 220, 90)
					stroke.Thickness = 4
					local chk = UI.new("Frame", { BackgroundColor3 = UI.Colors.Green, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -30, 0, 4), ZIndex = 6, Parent = face })
					UI.Corner(chk, UDim.new(1, 0))
					UI.Stroke(chk, 2.5, UI.Edge(UI.Colors.Green), true)
					local ck = Icons2D.New(chk, "Check", 19, { Shadow = false, ZIndex = 7, Ink = UI.Edge(UI.Colors.Green) })
					ck.AnchorPoint = Vector2.new(0.5, 0.5)
					ck.Position = UDim2.fromScale(0.5, 0.5)
					-- в стаке надето несколько одинаковых — показываем сколько (иначе «3/3», а галочек две)
					if s.equipped > 1 then
						chipText(face, "x" .. s.equipped, UI.Colors.Green, UDim2.fromOffset(34, 20), UDim2.new(1, -66, 0, 7), 6)
					end
				end
				local mark = UI.new("Frame", { BackgroundColor3 = UI.Colors.Red, BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 7, Visible = false, Parent = face })
				UI.Corner(mark, 18)
				local mx = Icons2D.New(mark, "Close", 44, { ZIndex = 8 })
				mx.AnchorPoint = Vector2.new(0.5, 0.5)
				mx.Position = UDim2.fromScale(0.5, 0.4)
				cardRefs[s.key] = { mark = mark, stroke = stroke, baseColor = stroke.Color, baseThick = stroke.Thickness }
				local btn = UI.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = face })
				UI.Bounce(btn, holder)
				btn.Activated:Connect(function()
					if selectMode then
						if s.count - s.equipped <= 0 then
							ctx.Toast("Этот питомец надет — сними его, чтобы удалить", "warn")
							return
						end
						selectedKeys[s.key] = (not selectedKeys[s.key]) or nil
						paintSelection()
						return
					end
					selected = s
					showDetail()
				end)
			end
		end
		for key in pairs(selectedKeys) do
			if not map[key] then
				selectedKeys[key] = nil
			end
		end
		paintSelection()
		showDetail()
	end
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			rebuild()
		end
	end)
	win.Opened:Connect(function()
		signature = ""
		shownKey = nil
		setSelectMode(false)
		confirm.Visible = false
		rebuild()
	end)
	return win
end

---------------------------------------------------------------------------------------------
-- Сумка: семена и бусты
---------------------------------------------------------------------------------------------
local function buildBag(screen, ctx)
	local win = UI.Window(screen, { Name = "Bag", Title = "ПРЕДМЕТЫ", Color = UI.Colors.Purple, Size = UDim2.fromOffset(760, 460) })
	local c = win.Content
	local body = UI.Scroll(c, UDim2.new(1, 0, 1, -60), UDim2.fromOffset(0, 58))
	UI.List(body, 12)
	UI.Padding(body, 6)
	local current = 1
	local tabs
	local lastSig = ""
	local function signature(data)
		local t = { tostring(current) }
		for _, sd in ipairs(SeedsData.List) do
			t[#t + 1] = tostring(data.Seeds and data.Seeds[sd.Id] or 0)
		end
		for _, bd in ipairs(BoostsData.List) do
			t[#t + 1] = tostring(data.Boosts and data.Boosts[bd.Id] or 0) .. (ctx.ClientState.BoostLeft(bd.Id) > 0 and "a" or "")
		end
		return table.concat(t, ",")
	end
	local function render()
		clear(body, true)
		local data = ctx.ClientState.Data
		if data then
			lastSig = signature(data)
		end
		if not data then
			return
		end
		if current == 1 then
			local any = false
			for i, s in ipairs(SeedsData.List) do
				local n = data.Seeds and data.Seeds[s.Id] or 0
				local holder, face = card(body, UDim2.new(1, -12, 0, 76), UI.Colors.Panel, i)
				glyphBadge(face, "Sprout", 60, c3(s.Color), UDim2.fromOffset(10, 8))
				UI.Text(face, s.Name .. "  x" .. n, { Size = UDim2.new(0.55, 0, 0, 30), Position = UDim2.fromOffset(80, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 24 })
				UI.Text(face, BiomesData[s.Biome].Short .. " · шанс " .. (s.Chance * 100) .. "% · созревает " .. Util.Time(s.Duration), { Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(80, 42), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 17 })
				local b = UI.Button({ Parent = face, Text = "Посадить", Color = UI.Colors.Green, Size = UDim2.fromOffset(150, 46), Position = UDim2.new(1, -164, 0.5, -23), TextSize = 22 })
				b.SetEnabled(n > 0)
				b.Activated:Connect(function()
					if n > 0 then
						ctx.OpenPanel("Incubator")
					end
				end)
				if n > 0 then
					any = true
				end
			end
		else
			for i, bd in ipairs(BoostsData.List) do
				local n = data.Boosts and data.Boosts[bd.Id] or 0
				local holder, face = card(body, UDim2.new(1, -12, 0, 76), UI.Colors.Panel, i)
				glyphBadge(face, bd.Id, 60, c3(bd.Color), UDim2.fromOffset(10, 8))
				UI.Text(face, bd.Name .. "  x" .. n, { Size = UDim2.new(0.55, 0, 0, 30), Position = UDim2.fromOffset(80, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 24 })
				local left = ctx.ClientState.BoostLeft(bd.Id)
				local desc = bd.Desc .. (left > 0 and ("  · активен " .. Util.Time(left)) or "")
				UI.Text(face, desc, { Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(80, 42), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 17 })
				local b = UI.Button({ Parent = face, Text = "Использовать", Color = c3(bd.Color), Size = UDim2.fromOffset(170, 46), Position = UDim2.new(1, -184, 0.5, -23), TextSize = 20 })
				b.SetEnabled(n > 0)
				b.Activated:Connect(function()
					if n > 0 then
						invoke(ctx, "UseBoost", bd.Id)
					end
				end)
			end
		end
	end
	tabs = UI.Tabs(c, { "Семена", "Бусты" }, { UI.Colors.Green, UI.Colors.Orange }, function(i)
		current = i
		render()
	end)
	win.Opened:Connect(function()
		tabs.Select(current)
	end)
	-- перерисовываем только при реальных изменениях (раньше кнопки пересоздавались при каждой синхронизации)
	ctx.ClientState.Changed:Connect(function(data)
		if win.IsOpen and signature(data) ~= lastSig then
			render()
		end
	end)
	return win
end

---------------------------------------------------------------------------------------------
-- Магазин
---------------------------------------------------------------------------------------------
local function buildShop(screen, ctx)
	local win = UI.Window(screen, { Name = "Shop", Title = "МАГАЗИН", Color = UI.Colors.Red, Size = UDim2.fromOffset(780, 480) })
	-- открывается только в зоне покупки у домика магазина; вкладка зависит от домика
	local c = win.Content
	local body = UI.Scroll(c, UDim2.new(1, 0, 1, -60), UDim2.fromOffset(0, 58))
	UI.List(body, 10)
	UI.Padding(body, 6)
	local current = 1
	local tabs
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local function render()
		clear(body, true)
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		local list = current == 1 and DrillsData.List or BackpacksData.List
		local owned = current == 1 and data.OwnedDrills or data.OwnedBackpacks
		local equipped = current == 1 and data.Drill or data.Backpack
		local kind = current == 1 and "Drill" or "Backpack"
		local shown = 0
		for i, item in ipairs(list) do
			if item.Biome <= (data.UnlockedBiome or 1) + 1 then
				shown = shown + 1
				local biome = BiomesData[item.Biome]
				local holder, face = card(body, UDim2.new(1, -12, 0, 84), UI.Colors.Panel, i)
				local stripe = UI.new("Frame", { BackgroundColor3 = c3(biome.Theme.UI), Size = UDim2.new(0, 10, 1, -12), Position = UDim2.fromOffset(6, 6), Parent = face })
				UI.Corner(stripe, 5)
				local src = (current == 1 and assets.Drills or assets.Backpacks):FindFirstChild(item.Id)
				if src then
					local m = src:Clone()
					for _, p in ipairs(m:GetDescendants()) do
						if p:IsA("BasePart") then
							p.Anchored = true
						end
					end
					if current == 1 then
						m:PivotTo(CFrame.Angles(0, math.rad(90), 0))
					end
					UI.Viewport(face, m, UDim2.fromOffset(84, 76), UDim2.fromOffset(22, 4))
				end
				UI.Text(face, item.Name, { Size = UDim2.new(0.45, 0, 0, 30), Position = UDim2.fromOffset(116, 10), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 24 })
				local stat = current == 1 and ("Урон: " .. Util.Format(item.Damage)) or ("Вместимость: " .. Util.Format(item.Capacity))
				UI.Text(face, stat .. "  ·  " .. biome.Short, { Size = UDim2.new(0.45, 0, 0, 24), Position = UDim2.fromOffset(116, 44), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 19 })
				local b = UI.Button({ Parent = face, Text = "", Color = UI.Colors.Green, Size = UDim2.fromOffset(190, 52), Position = UDim2.new(1, -204, 0.5, -26), TextSize = 22 })
				if equipped == item.Id then
					b.SetText("Надето")
					b.SetColor(UI.Colors.Blue)
				elseif owned and owned[item.Id] then
					b.SetText("Надеть")
					b.SetColor(UI.Colors.Teal)
				elseif item.Biome > (data.UnlockedBiome or 1) then
					b.SetText("Закрыто")
					b.SetEnabled(false)
				elseif Stats.ShopState(data, kind, item) == "locked" then
					-- покупка строго по порядку
					b.SetText("Сначала предыдущий")
					b.SetColor(UI.Colors.Gray)
					b.SetEnabled(false)
				else
					b.SetText(Util.Format(item.Price))
					local ic = Icons2D.New(b.Face, "Coin", 36, { Color = GOLD, ZIndex = 4 })
					ic.AnchorPoint = Vector2.new(0, 0.5)
					ic.Position = UDim2.new(0, 8, 0.5, -2)
					b.SetEnabled((data.Coins or 0) >= item.Price)
				end
				b.Activated:Connect(function()
					if equipped ~= item.Id then
						local res = invoke(ctx, "BuyItem", kind, item.Id)
						if res and res.ok then
							ctx.Sound.Play("Unlock")
						end
					end
				end)
			end
		end
	end
	local tabBar
	tabs, tabBar = UI.Tabs(c, { "Буры", "Рюкзаки" }, { UI.Colors.Red, UI.Colors.Blue }, function(i)
		current = i
		render()
	end)
	-- у каждого домика свой магазин: вкладки не нужны
	tabBar.Visible = false
	body.Position = UDim2.fromOffset(0, 0)
	body.Size = UDim2.new(1, 0, 1, 0)
	win.Opened:Connect(function()
		tabs.Select(current)
	end)
	local lastSig = ""
	ctx.ClientState.Changed:Connect(function(data)
		if win.IsOpen then
			local sig = tostring(data.Coins) .. data.Drill .. data.Backpack .. tostring(data.UnlockedBiome)
			if sig ~= lastSig then
				lastSig = sig
				render()
			end
		end
	end)
	function win.SelectTab(i)
		current = i
		if win.IsOpen and tabs then
			tabs.Select(i)
		end
		win.Title.Text = i == 1 and "МАГАЗИН БУРОВ" or "МАГАЗИН РЮКЗАКОВ"
	end
	return win
end

---------------------------------------------------------------------------------------------
-- Инкубатор
---------------------------------------------------------------------------------------------
local function buildIncubator(screen, ctx)
	local win = UI.Window(screen, { Name = "Incubator", Title = "БИО-КАМЕРА", Color = UI.Colors.Green, Size = UDim2.fromOffset(900, 548) })
	local c = win.Content
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 296), Parent = c })
	UI.List(row, 16, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	-- семена: что из них вырастает (видно всегда), при выборе слота — нажми, чтобы посадить
	local pickTitle = UI.Text(c, "СЕМЕНА И ЧТО ИЗ НИХ ВЫРАСТАЕТ", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 302), MaxText = 20, TextColor3 = Color3.fromRGB(60, 140, 70), Stroke = false })
	local picker = UI.Scroll(c, UDim2.new(1, 0, 1, -330), UDim2.fromOffset(0, 330))
	local pgrid = Instance.new("UIGridLayout")
	pgrid.CellSize = UDim2.fromOffset(204, 92)
	pgrid.CellPadding = UDim2.fromOffset(10, 10)
	pgrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pgrid.SortOrder = Enum.SortOrder.LayoutOrder
	pgrid.Parent = picker
	local choosing = nil
	local slotUi = {}

	for i = 1, 3 do
		local holder, face = card(row, UDim2.fromOffset(230, 290), UI.Colors.Panel2, i)
		local title = UI.Text(face, "Слот " .. i, { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 8), TextColor3 = UI.Ink, Stroke = false, MaxText = 24 })
		local pod = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(210, 245, 255), BackgroundTransparency = 0.2, Size = UDim2.fromOffset(120, 140), Position = UDim2.new(0.5, -60, 0, 44), Parent = face })
		UI.Corner(pod, 40)
		UI.Stroke(pod, 3, UI.Ink, true)
		local liquid = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(110, 255, 140), Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.5), Parent = pod })
		UI.Corner(liquid, 40)
		local seedHolder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, -35, 0.5, -35), Parent = pod })
		local status = UI.Text(face, "", { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 190), TextColor3 = UI.Ink, Stroke = false, MaxText = 20 })
		local bar = UI.Bar(face, UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 196), UI.Colors.Green)
		local main = UI.Button({ Parent = face, Text = "Посадить", Color = UI.Colors.Green, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0, 12, 1, -54), TextSize = 22 })
		local fert = UI.Button({ Parent = face, Text = "Удобрить", Color = UI.Colors.Purple, Size = UDim2.new(1, -24, 0, 36), Position = UDim2.new(0, 12, 1, -100), TextSize = 18 })
		slotUi[i] = { title = title, status = status, bar = bar, main = main, fert = fert, seedHolder = seedHolder, liquid = liquid, lastSeed = "" }
		main.Activated:Connect(function()
			local s = slotUi[i]
			if s.mode == "empty" then
				choosing = i
				if win.Render then
					win.Render()
				end
			elseif s.mode == "ready" then
				local res = invoke(ctx, "Incubator", "Claim", i)
				if res and res.ok and res.pet then
					ctx.ShowHatch(res.pet)
				end
			elseif s.mode == "pass" then
				win.Hide()
				ctx.OpenPanel("Donate")
			end
		end)
		fert.Activated:Connect(function()
			invoke(ctx, "Incubator", "Fertilize", i)
		end)
	end

	local pickerSig = ""
	local function renderPicker(data)
		local sig = tostring(choosing)
		for _, sd in ipairs(SeedsData.List) do
			sig = sig .. "," .. tostring(data.Seeds and data.Seeds[sd.Id] or 0)
		end
		if sig == pickerSig then
			return -- не пересоздаём карточки каждую секунду, иначе клик мог "проваливаться"
		end
		pickerSig = sig
		clear(picker, true)
		pickTitle.Text = choosing and ("ВЫБЕРИ СЕМЯ ДЛЯ СЛОТА " .. choosing) or "СЕМЕНА И ЧТО ИЗ НИХ ВЫРАСТАЕТ"
		for i, sd in ipairs(SeedsData.List) do
			local n = data.Seeds and data.Seeds[sd.Id] or 0
			local col = c3(sd.Color)
			local holder, face = UI.Plate(picker, UDim2.fromOffset(204, 92), nil, Color3.new(1, 1, 1), 16)
			holder.LayoutOrder = i
			local st = face:FindFirstChildOfClass("UIStroke")
			if st and choosing and n > 0 then
				st.Color = UI.Colors.Green
				st.Thickness = 4
			end
			local badge = UI.new("Frame", { BackgroundColor3 = col, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(8, 8), Parent = face })
			UI.Corner(badge, UDim.new(1, 0))
			UI.Stroke(badge, 2.5, UI.Edge(col), true)
			local ic = Icons2D.New(badge, "Sprout", 38, { Ink = UI.Edge(col), ZIndex = 4 })
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.fromScale(0.5, 0.48)
			chipText(face, "x" .. n, n > 0 and UI.Colors.Green or UI.Colors.Gray, UDim2.fromOffset(46, 20), UDim2.fromOffset(10, 64), 4)
			UI.Text(face, sd.Name, { Size = UDim2.new(1, -74, 0, 20), Position = UDim2.fromOffset(68, 6), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, TextColor3 = Color3.fromRGB(70, 56, 90), Stroke = false })
			local db, sb = Stats.PetBonus({ Id = sd.Pet })
			UI.Text(face, "→ " .. sd.PetName .. " · x" .. string.format("%.1f", 1 + db) .. " / x" .. string.format("%.1f", 1 + sb), { Size = UDim2.new(1, -74, 0, 20), Position = UDim2.fromOffset(68, 28), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, TextColor3 = col:Lerp(Color3.new(0, 0, 0), 0.35), Stroke = false })
			UI.Text(face, (sd.Aura and sd.Aura.Text or "") .. " · " .. Util.Time(sd.Duration), { Size = UDim2.new(1, -74, 0, 34), Position = UDim2.fromOffset(68, 50), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MaxText = 12, TextWrapped = true, TextColor3 = Color3.fromRGB(120, 112, 150), Stroke = false })
			local btn = UI.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = face })
			btn.Activated:Connect(function()
				if not choosing then
					ctx.Toast(sd.Name .. " → " .. sd.PetName .. ". Нажми «Посадить» у свободного слота.", "info")
					return
				end
				if n <= 0 then
					ctx.Toast("Нет такого семени. Семена выпадают при бурении (чаще из Хроно-Жил).", "warn")
					return
				end
				local slot = choosing
				choosing = nil
				invoke(ctx, "Incubator", "Plant", slot, sd.Id)
			end)
		end
	end

	local function render()
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		local d = data.Derived or {}
		local maxSlots = d.IncubatorSlots or 1
		local now = ctx.ClientState.ServerNow()
		for i = 1, 3 do
			local s = slotUi[i]
			local slot = data.Incubator and data.Incubator[tostring(i)]
			s.fert.Holder.Visible = false
			s.bar.Frame.Visible = false
			s.main.Holder.Visible = true
			local seedId = slot and slot.Seed or ""
			if seedId ~= s.lastSeed then
				s.lastSeed = seedId
				clear(s.seedHolder)
				if slot and slot.Seed then
					local sd = SeedsData.ById[slot.Seed]
					Icons2D.New(s.seedHolder, "Sprout", 70, { Color = c3(sd.Color) })
				end
			end
			if i > maxSlots then
				local hasPassSlot = (i == 3)
				s.mode = hasPassSlot and "pass" or "locked"
				s.status.Text = (i == 2) and ("Откроется за " .. RebirthData.IncubatorSlotAt .. "-й ребёрс") or "Геймпасс"
				s.main.SetText(i == 3 and "Донат" or "Закрыто")
				s.main.SetEnabled(i == 3)
				s.liquid.Size = UDim2.fromScale(1, 0.1)
				s.liquid.Position = UDim2.fromScale(0, 0.9)
			elseif not slot or not slot.Seed then
				s.mode = "empty"
				s.status.Text = (choosing == i) and "Выбери семя ниже" or "Пусто"
				s.main.SetText("Посадить")
				s.main.SetColor(UI.Colors.Green)
				s.main.SetEnabled(true)
				s.liquid.Size = UDim2.fromScale(1, 0.25)
				s.liquid.Position = UDim2.fromScale(0, 0.75)
			else
				local sd = SeedsData.ById[slot.Seed]
				local total = slot.Duration - (slot.Cut or 0)
				local left = math.max(0, total - (now - slot.Planted))
				local frac = (total > 0) and (1 - left / total) or 1
				s.liquid.Size = UDim2.fromScale(1, 0.25 + 0.75 * frac)
				s.liquid.Position = UDim2.fromScale(0, 0.75 - 0.75 * frac)
				if left <= 0 then
					s.mode = "ready"
					s.status.Text = sd.PetName .. " готов!"
					s.main.SetText("ЗАБРАТЬ!")
					s.main.SetColor(UI.Colors.Yellow)
					s.main.SetEnabled(true)
				else
					s.mode = "growing"
					s.status.Text = ""
					s.bar.Frame.Visible = true
					s.bar.Set(frac, Util.Time(left), true)
					s.main.Holder.Visible = false
					s.fert.Holder.Visible = true
					local fn = data.Boosts and data.Boosts.BioFertilizer or 0
					s.fert.SetText("Удобрить (" .. fn .. ")")
					s.fert.SetEnabled(fn > 0)
				end
			end
		end
		renderPicker(data)
	end
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
	win.Opened:Connect(function()
		choosing = nil
		pickerSig = ""
		render()
	end)
	task.spawn(function()
		while true do
			if win.IsOpen then
				render()
			end
			task.wait(1)
		end
	end)
	win.Render = render
	return win
end

---------------------------------------------------------------------------------------------
-- Ребёрс и Хроно-Древо
---------------------------------------------------------------------------------------------
local function buildRebirth(screen, ctx)
	local win = UI.Window(screen, { Name = "Rebirth", Title = "ХРОНО-ДРЕВО", Color = UI.Colors.Pink, Size = UDim2.fromOffset(820, 500) })
	local c = win.Content
	local _, left = card(c, UDim2.new(0, 330, 1, -6), UI.Colors.Panel2, 0)
	local reqText = UI.Text(left, "", { Size = UDim2.new(1, -24, 0, 210), Position = UDim2.fromOffset(12, 12), TextColor3 = UI.Ink, Stroke = false, MaxText = 20, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, RichText = true })
	local keepText = UI.Text(left, "Сбрасываются: монеты, бур, рюкзак, открытые ярусы.\nОстаются: питомцы, семена, инкубатор, бусты, сюжет.", { Size = UDim2.new(1, -24, 0, 80), Position = UDim2.fromOffset(12, 228), TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	local go = UI.Button({ Parent = left, Text = "ПЕРЕРОДИТЬСЯ", Color = UI.Colors.Pink, Size = UDim2.new(1, -24, 0, 64), Position = UDim2.new(0, 12, 1, -78), TextSize = 28 })
	go.Activated:Connect(function()
		local res = invoke(ctx, "Rebirth")
		if res and res.ok then
			win.Hide()
		end
	end)

	local right = UI.Scroll(c, UDim2.new(1, -350, 1, -6), UDim2.fromOffset(350, 0))
	UI.List(right, 10)
	UI.Padding(right, 6)
	local perkUi = {}
	for i, perk in ipairs(RebirthData.Perks) do
		local holder, face = card(right, UDim2.new(1, -12, 0, 78), UI.Colors.Panel, i)
		local dot = UI.new("Frame", { BackgroundColor3 = c3(perk.Color), Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(12, 16), Parent = face })
		UI.Corner(dot, 12)
		UI.Stroke(dot, 3, UI.Ink, true)
		local lvlText = UI.Text(dot, "0", { MaxText = 24 })
		UI.Text(face, perk.Name, { Size = UDim2.new(1, -220, 0, 26), Position = UDim2.fromOffset(70, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 22 })
		UI.Text(face, perk.Desc, { Size = UDim2.new(1, -220, 0, 20), Position = UDim2.fromOffset(70, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 16 })
		local pips = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -220, 0, 12), Position = UDim2.fromOffset(70, 58), Parent = face })
		UI.List(pips, 4, Enum.FillDirection.Horizontal)
		local pipFrames = {}
		for k = 1, #perk.Costs do
			local p = UI.new("Frame", { BackgroundColor3 = UI.Colors.Panel3, Size = UDim2.fromOffset(22, 10), LayoutOrder = k, Parent = pips })
			UI.Corner(p, 4)
			UI.Stroke(p, 2, UI.Ink, true)
			pipFrames[k] = p
		end
		local b = UI.Button({ Parent = face, Text = "", Color = UI.Colors.Purple, Size = UDim2.fromOffset(130, 50), Position = UDim2.new(1, -142, 0.5, -25), TextSize = 22 })
		b.Activated:Connect(function()
			invoke(ctx, "BuyPerk", perk.Id)
		end)
		perkUi[perk.Id] = { lvl = lvlText, pips = pipFrames, btn = b, color = c3(perk.Color) }
	end

	local function render()
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		local d = data.Derived or {}
		local okBiome = (data.UnlockedBiome or 1) >= RebirthData.RequiredBiome
		local okCoins = (data.Coins or 0) >= (d.RebirthCost or 0)
		local function mark(ok)
			return ok and '<font color="#3cb44b">✔</font>' or '<font color="#e05050">✘</font>'
		end
		reqText.Text = "<b>Перерождение #" .. ((data.Rebirths or 0) + 1) .. "</b>\n\n" ..
			mark(okBiome) .. " Открыть Магму (4 500 м)\n" ..
			mark(okCoins) .. " " .. Util.Format(d.RebirthCost or 0) .. " монет\n\n" ..
			"<b>Награда:</b>\n+" .. (d.RebirthShards or 2) .. " Хроно-Осколков\n" ..
			"Продажа x" .. string.format("%.2f", d.RebirthMult or 1) .. " → x" .. string.format("%.2f", (d.RebirthMult or 1) + RebirthData.SellBonusPerRebirth) ..
			"\n\nОсколков: <b>" .. (data.Shards or 0) .. "</b>"
		go.SetEnabled(okBiome and okCoins)
		for _, perk in ipairs(RebirthData.Perks) do
			local u = perkUi[perk.Id]
			local lvl = data.Perks and data.Perks[perk.Id] or 0
			u.lvl.Text = tostring(lvl)
			for k, p in ipairs(u.pips) do
				p.BackgroundColor3 = (k <= lvl) and u.color or UI.Colors.Panel3
			end
			if lvl >= #perk.Costs then
				u.btn.SetText("МАКС")
				u.btn.SetEnabled(false)
			else
				local cost = perk.Costs[lvl + 1]
				u.btn.SetText("+1 за " .. cost)
				u.btn.SetEnabled((data.Shards or 0) >= cost)
			end
		end
	end
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
	win.Opened:Connect(render)
	return win
end

---------------------------------------------------------------------------------------------
-- Миры
---------------------------------------------------------------------------------------------
local WORLD_GLYPHS = { "Pickaxe", "Bone", "Snowflake", "Flame", "Saturn" }
local function buildWorlds(screen, ctx)
	local win = UI.Window(screen, { Name = "Worlds", Title = "ЯРУСЫ ШАХТЫ", Color = UI.Colors.Blue, Size = UDim2.fromOffset(900, 460) })
	local c = win.Content
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = c })
	UI.List(row, 12, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local cards = {}
	for b, biome in ipairs(BiomesData) do
		local color = c3(biome.Theme.UI)
		local holder, face = UI.Plate(row, UDim2.fromOffset(162, 362), nil, Color3.new(1, 1, 1), 20)
		holder.LayoutOrder = b
		-- цветная «витрина» с эмблемой
		local top = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.new(1, -12, 0, 150), Position = UDim2.fromOffset(6, 6), Parent = face })
		UI.Corner(top, 16)
		UI.Gradient(top, UI.Lighter(color, 0.35), UI.Darker(color, 0.12))
		UI.Stroke(top, 3, UI.Edge(color), true)
		-- лучи за эмблемой
		local rays = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(130, 130), Parent = top })
		for k = 0, 3 do
			local r = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 22, 1, 0), Rotation = k * 45, Parent = rays })
			UI.Corner(r, UDim.new(1, 0))
		end
		local emblem = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(92, 92), ZIndex = 3, Parent = top })
		UI.Corner(emblem, UDim.new(1, 0))
		UI.Stroke(emblem, 4, UI.Edge(color), true)
		UI.Gradient(emblem, Color3.new(1, 1, 1), UI.Lighter(color, 0.65))
		local ic = Icons2D.New(emblem, WORLD_GLYPHS[b] or "Globe", 64, { Color = color, Ink = UI.Edge(color), ZIndex = 4 })
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.48)
		local num = UI.new("Frame", { BackgroundColor3 = UI.Edge(color), Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(6, 6), ZIndex = 4, Parent = top })
		UI.Corner(num, UDim.new(1, 0))
		UI.Text(num, tostring(b), { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), MaxText = 24, ZIndex = 5 })
		local nameL = UI.Text(top, string.upper(biome.Short), { Size = UDim2.new(1, -12, 0, 28), Position = UDim2.new(0, 6, 1, -32), MaxText = 22, ZIndex = 4, StrokeThickness = 3 })
		local ns = nameL:FindFirstChildOfClass("UIStroke")
		if ns then
			ns.Color = UI.Edge(color)
		end
		-- информация
		UI.Text(face, biome.Name, { Size = UDim2.new(1, -14, 0, 20), Position = UDim2.fromOffset(7, 162), TextColor3 = Color3.fromRGB(80, 70, 104), Stroke = false, MaxText = 15, TextWrapped = true })
		local _, depthChip = chipText(face, Util.Commas(biome.MinDepth) .. "–" .. Util.Commas(biome.MaxDepth) .. " м", Color3.fromRGB(110, 104, 150), UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 186), 3)
		local sellChip = pill(face, "Coin", Color3.fromRGB(255, 176, 30), UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 216))
		sellChip.Text = "Продажа x" .. biome.SellMult
		local pod = UI.Button({ Parent = face, Text = "В шахту", Color = UI.Colors.Green, Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 1, -102), TextSize = 20, Radius = 21, Glyph = "Pickaxe" })
		local hub = UI.Button({ Parent = face, Text = "На базу", Color = UI.Colors.Teal, Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 1, -52), TextSize = 20, Radius = 21, Glyph = "Home" })
		pod.Activated:Connect(function()
			local res = invoke(ctx, "Travel", b, "Pod")
			if res and res.ok then
				win.Hide()
			end
		end)
		hub.Activated:Connect(function()
			local res = invoke(ctx, "Travel", b, "Hub")
			if res and res.ok then
				win.Hide()
			end
		end)
		local lock = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 36, 64), BackgroundTransparency = 0.38, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = face, Visible = false })
		UI.Corner(lock, 20)
		local lb = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 86, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -30, 0, 34), Size = UDim2.fromOffset(52, 52), ZIndex = 9, Parent = lock })
		UI.Corner(lb, UDim.new(1, 0))
		UI.Stroke(lb, 3, Color3.fromRGB(30, 26, 48), true)
		local li = Icons2D.New(lb, "Lock", 36, { ZIndex = 10 })
		li.AnchorPoint = Vector2.new(0.5, 0.5)
		li.Position = UDim2.fromScale(0.5, 0.48)
		local need = b > 1 and Stats.GateDrill(b - 1) or nil
		local note = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 26, 50), BackgroundTransparency = 0.1, Size = UDim2.new(1, -12, 0, 76), Position = UDim2.new(0, 6, 0.48, 0), ZIndex = 9, Parent = lock })
		UI.Corner(note, 14)
		UI.Text(note, "Сломай блок на дне\nпрошлого яруса" .. (need and ("\n(бур «" .. need.Name .. "»)") or ""), { Size = UDim2.new(1, -10, 1, -8), Position = UDim2.fromOffset(5, 4), ZIndex = 10, MaxText = 15, TextWrapped = true })
		cards[b] = { lock = lock }
	end
	local function render()
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		for b, cc in ipairs(cards) do
			cc.lock.Visible = b > (data.UnlockedBiome or 1)
		end
	end
	win.Opened:Connect(render)
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
	return win
end

---------------------------------------------------------------------------------------------
-- Диалог Drill-Bot 3000
---------------------------------------------------------------------------------------------
local LINES = {
	"Бип-буп! Шахта сама себя не выкопает.",
	"Мои сенсоры чуют Хроно-Жилы глубже. Копай!",
	"Каждые 20 минут шахта восстанавливается. Не забудь вылезти!",
	"Питомцы из семян сильнее магазинных. Проверь инкубатор!",
	"Полный рюкзак — на базу! Репликатор платит лучше в глубоких ярусах.",
}
local function rewardText(r)
	local parts = {}
	if r.Coins then
		table.insert(parts, Util.Format(r.Coins) .. " монет")
	end
	if r.Boosts then
		for id, n in pairs(r.Boosts) do
			table.insert(parts, n .. "x " .. BoostsData.ById[id].Name)
		end
	end
	if r.PetSlot then
		table.insert(parts, "+1 слот питомца")
	end
	return table.concat(parts, ", ")
end

local function buildNpc(screen, ctx)
	local win = UI.Window(screen, { Name = "Npc", Title = "DRILL-BOT 3000", Color = UI.Colors.Yellow, Size = UDim2.fromOffset(760, 400) })
	local c = win.Content
	local _, portrait = card(c, UDim2.fromOffset(220, 300), UI.Colors.Panel2, 0)
	local npcModel = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("NPC"):WaitForChild("DrillBot3000")
	local m = npcModel:Clone()
	UI.Viewport(portrait, m, UDim2.new(1, -10, 1, -10), UDim2.fromOffset(5, 5))
	local _, bubble = card(c, UDim2.new(1, -240, 0, 300), UI.Colors.Panel, 1)
	bubble.Parent.Position = UDim2.fromOffset(240, 0)
	local speech = UI.Text(bubble, "", { Size = UDim2.new(1, -28, 0, 70), Position = UDim2.fromOffset(14, 12), TextColor3 = UI.Ink, Stroke = false, MaxText = 22, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local qTitle = UI.Text(bubble, "", { Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 90), TextColor3 = UI.Colors.Orange, Stroke = false, MaxText = 24, TextXAlignment = Enum.TextXAlignment.Left })
	local qText = UI.Text(bubble, "", { Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(14, 122), TextColor3 = UI.Ink, Stroke = false, MaxText = 20, TextXAlignment = Enum.TextXAlignment.Left })
	local qBar = UI.Bar(bubble, UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 156), UI.Colors.Yellow)
	local qReward = UI.Text(bubble, "", { Size = UDim2.new(1, -28, 0, 24), Position = UDim2.fromOffset(14, 192), TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 18, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
	local claim = UI.Button({ Parent = bubble, Text = "ЗАБРАТЬ НАГРАДУ", Color = UI.Colors.Green, Size = UDim2.fromOffset(280, 52), Position = UDim2.new(1, -294, 1, -64), TextSize = 22 })
	claim.Activated:Connect(function()
		local res = invoke(ctx, "ClaimQuest", "Story")
		if res and res.ok then
			ctx.Sound.Play("Unlock")
		end
	end)
	local function render()
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		local q = QuestsData.Story[data.StoryIndex or 1]
		if not q then
			speech.Text = "Ты прошёл все мои задания! Легенда шахты. Теперь — новые рекорды и ребёрсы!"
			qTitle.Text = ""
			qText.Text = ""
			qBar.Frame.Visible = false
			qReward.Text = ""
			claim.Holder.Visible = false
			return
		end
		local cur
		if q.Stat == "SessionEggs" then
			cur = data.Derived and data.Derived.SessionEggs or 0
		else
			cur = data.Stats and data.Stats[q.Stat] or 0
		end
		cur = math.min(cur, q.Target)
		local done = cur >= q.Target
		speech.Text = done and "Бип! Задание выполнено. Держи награду, бурильщик!" or LINES[((data.StoryIndex or 1) % #LINES) + 1]
		qTitle.Text = "Квест " .. (data.StoryIndex or 1) .. "/" .. #QuestsData.Story .. ": " .. q.Title
		qText.Text = q.Text
		qBar.Frame.Visible = true
		qBar.Set(cur / q.Target, Util.Format(cur) .. " / " .. Util.Format(q.Target))
		qReward.Text = "Награда: " .. rewardText(q.Reward)
		claim.Holder.Visible = done
	end
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
	win.Opened:Connect(render)
	return win
end

---------------------------------------------------------------------------------------------
-- Окно яйца: шансы и открытие
---------------------------------------------------------------------------------------------
local function buildEgg(screen, ctx)
	local win = UI.Window(screen, { Name = "Egg", Title = "ЯЙЦО", Color = UI.Colors.Teal, Size = UDim2.fromOffset(900, 540) })
	local c = win.Content
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	---------------------------------------------------------------- витрина яйца слева
	local _, show = UI.Plate(c, UDim2.new(0, 250, 1, 0), UDim2.new(), Color3.new(1, 1, 1), 20)
	local hero = UI.new("Frame", { BackgroundColor3 = UI.Colors.Teal, Size = UDim2.new(1, -12, 0, 200), Position = UDim2.fromOffset(6, 6), Parent = show })
	UI.Corner(hero, 16)
	local heroGrad = UI.Gradient(hero, Color3.fromRGB(160, 240, 230), UI.Colors.Teal)
	local heroStroke = UI.Stroke(hero, 3, UI.Edge(UI.Colors.Teal), true)
	for k = 0, 3 do
		local r = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 26, 0, 250), Rotation = k * 45, Parent = hero })
		UI.Corner(r, UDim.new(1, 0))
	end
	local eggHolder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), Parent = hero })
	local eggName = UI.Text(show, "", { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 212), MaxText = 24, TextColor3 = Color3.fromRGB(70, 56, 90), Stroke = false })
	local pricePill = pill(show, "Coin", Color3.fromRGB(255, 176, 30), UDim2.new(1, -24, 0, 40), UDim2.fromOffset(12, 248))
	local luckPill, luckF = pill(show, "Clover", UI.Colors.Green, UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 296))
	local hint = UI.Text(show, "Нажми на питомца справа, чтобы удалять его сразу при выпадении", { Size = UDim2.new(1, -20, 0, 56), Position = UDim2.new(0, 10, 1, -64), MaxText = 14, TextWrapped = true, TextColor3 = Color3.fromRGB(130, 120, 160), Stroke = false })
	local _ = hint

	---------------------------------------------------------------- питомцы справа
	local well = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(232, 250, 248), BackgroundTransparency = 0.1, Size = UDim2.new(1, -262, 1, -76), Position = UDim2.fromOffset(262, 0), Parent = c })
	UI.Corner(well, 18)
	UI.Stroke(well, 3, Color3.fromRGB(170, 226, 220), true)
	local grid = UI.Scroll(well, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4))
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(108, 148)
	gl.CellPadding = UDim2.fromOffset(8, 10)
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	UI.Padding(grid, 6)

	---------------------------------------------------------------- кнопки
	local bottom = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -262, 0, 64), Position = UDim2.new(0, 262, 1, -66), Parent = c })
	UI.List(bottom, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local one = UI.Button({ Parent = bottom, Text = "x1", Color = UI.Colors.Green, Size = UDim2.fromOffset(138, 56), LayoutOrder = 1, TextSize = 22, Glyph = "Coin", GlyphColor = GOLD, Radius = 22 })
	local three = UI.Button({ Parent = bottom, Text = "x3", Color = UI.Colors.Purple, Size = UDim2.fromOffset(138, 56), LayoutOrder = 2, TextSize = 22, Glyph = "Coin", GlyphColor = GOLD, Radius = 22 })
	local eight = UI.Button({ Parent = bottom, Text = "x8", Color = Color3.fromRGB(40, 200, 110), Size = UDim2.fromOffset(146, 56), LayoutOrder = 3, TextSize = 22, Glyph = "Egg", Radius = 22 })
	local autoB = UI.Button({ Parent = bottom, Text = "Авто", Color = Color3.fromRGB(40, 190, 210), Size = UDim2.fromOffset(140, 56), LayoutOrder = 4, TextSize = 22, Glyph = "Bolt", Radius = 22 })

	-- плашка «идёт автооткрытие» поверх экрана (окно яйца в это время закрыто)
	local autoBar = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(360, 56), Visible = false, ZIndex = 30, Parent = screen })
	local stopB = UI.Button({ Parent = autoBar, Text = "АВТО · СТОП", Color = UI.Colors.Red, Size = UDim2.fromScale(1, 1), TextSize = 22, Glyph = "Close", Radius = 26 })

	local currentEgg
	local busy = false
	local auto = { on = false }
	local cards = {}

	local function canAfford(n)
		local coins = ctx.ClientState.Data and ctx.ClientState.Data.Coins or 0
		return currentEgg and coins >= currentEgg.Price * n
	end
	local function hasPass(key)
		return Stats.HasPass(ctx.ClientState.Data, key)
	end

	local function open(n, fast)
		if busy or not currentEgg then
			return false
		end
		busy = true
		local res = invoke(ctx, "OpenEgg", currentEgg.Id, n)
		busy = false
		if res and res.ok then
			win.Hide()
			ctx.PlayEgg(currentEgg.Id, res.pets, { Fast = fast })
			return true
		end
		return false
	end

	local function stopAuto()
		auto.on = false
		autoBar.Visible = false
	end
	local function startAuto()
		if not currentEgg then
			return
		end
		auto.on = true
		autoBar.Visible = true
		stopB.SetText("АВТО: " .. currentEgg.Name .. " · СТОП")
		win.Hide()
		task.spawn(function()
			while auto.on do
				if not EggOpening.IsBusy() then
					local n = (hasPass("HatchX8") and canAfford(8)) and 8 or (canAfford(3) and 3 or 1)
					if not open(n, true) then
						stopAuto()
						break
					end
				end
				task.wait(0.25)
			end
		end)
	end
	stopB.Activated:Connect(stopAuto)

	one.Activated:Connect(function()
		open(1)
	end)
	three.Activated:Connect(function()
		open(3)
	end)
	eight.Activated:Connect(function()
		if hasPass("HatchX8") then
			open(8)
		else
			win.Hide()
			ctx.OpenPanel("Donate")
		end
	end)
	autoB.Activated:Connect(function()
		if not hasPass("AutoHatch") then
			win.Hide()
			ctx.OpenPanel("Donate")
			return
		end
		if auto.on then
			stopAuto()
		else
			startAuto()
		end
	end)

	local function setDeleteLook(card, on)
		card.del.Visible = on
		card.stroke.Color = on and UI.Colors.Red or UI.Edge(card.col)
		card.stroke.Thickness = on and 4 or 3
	end

	local function refreshButtons()
		if not currentEgg then
			return
		end
		local egg = currentEgg
		one.SetText(Util.Format(egg.Price))
		three.SetText("x3 " .. Util.Format(egg.Price * 3))
		one.SetEnabled(canAfford(1))
		three.SetEnabled(canAfford(3))
		if hasPass("HatchX8") then
			eight.SetText("x8 " .. Util.Format(egg.Price * 8))
			eight.SetEnabled(canAfford(8))
		else
			eight.SetEnabled(true)
			eight.SetText("x8 · R$")
		end
		autoB.SetText(hasPass("AutoHatch") and (auto.on and "Стоп" or "Авто") or "Авто · R$")
	end

	function win.ShowEgg(eggId)
		local egg = EggsData.ById[eggId]
		if not egg then
			return
		end
		currentEgg = egg
		local data = ctx.ClientState.Data or {}
		win.Title.Text = string.upper(egg.Name)
		eggName.Text = egg.Name
		pricePill.Text = Util.Format(egg.Price)
		-- витрина: модель яйца
		clear(eggHolder)
		local src = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Eggs") and ReplicatedStorage.Assets.Eggs:FindFirstChild(eggId)
		if src then
			UI.Viewport(eggHolder, src:Clone())
		end
		local biome = BiomesData[egg.Biome]
		local hc = biome and c3(biome.Theme.UI) or UI.Colors.Teal
		heroGrad.Color = ColorSequence.new(UI.Lighter(hc, 0.45), hc)
		heroStroke.Color = UI.Edge(hc)
		-- шансы с учётом удачи
		clear(grid, true)
		cards = {}
		local luck = Stats.LuckMult(data)
		local lucky = luck > 1
		local total = 0
		for _, e in ipairs(egg.Pets) do
			local w = e[3]
			if lucky and e[3] <= Balance.LuckyRareThreshold then
				w = w * luck
			end
			total = total + w
		end
		luckF.Visible = lucky
		luckPill.Text = "Удача x" .. string.format(luck < 10 and "%.1f" or "%.0f", luck)
		local index = data.Index or {}
		local autoDel = data.AutoDelete or {}
		for i, e in ipairs(egg.Pets) do
			local def = PetsData.ById[e[1]]
			local col = rarityColor(def.Rarity)
			local holder, face, strip, stroke = petCard(grid, UDim2.fromOffset(108, 148), col, i, def.Rarity == "Mythic" and "rainbow" or nil)
			local model = ctx.PetModel(e[1], false)
			if not index[e[1]] then
				EggOpening.Silhouette(model)
			end
			UI.Viewport(face, model, UDim2.new(1, -8, 0, 84), UDim2.fromOffset(4, 8))
			local w = e[3]
			if lucky and e[3] <= Balance.LuckyRareThreshold then
				w = w * luck
			end
			local pct = w / total * 100
			local pctL = UI.Text(strip, (pct >= 1 and string.format("%.1f", pct) or (pct >= 0.01 and string.format("%.2f", pct) or string.format("%.3f", pct))) .. "%", { Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 2), MaxText = 20, ZIndex = 4 })
			local _ = pctL
			local db, sb = Stats.PetBonus({ Id = e[1] })
			local l1 = statLine(strip, "Pickaxe", DMG_COLOR, UDim2.fromOffset(4, 25), UDim2.new(0.5, -4, 0, 17), 4)
			l1.Text = string.format("%.2f", 1 + db)
			local l2 = statLine(strip, "Coin", SELL_COLOR, UDim2.new(0.5, 0, 0, 25), UDim2.new(0.5, -4, 0, 17), 4)
			l2.Text = string.format("%.2f", 1 + sb)
			chipText(face, def.Rarity == "Mythic" and "МИФ" or (PetsData.Rarity[def.Rarity] and PetsData.Rarity[def.Rarity].Name or ""), UI.Darker(col, 0.45), UDim2.fromOffset(72, 18), UDim2.fromOffset(6, 6), 6)
			-- метка автоудаления
			local del = UI.new("Frame", { BackgroundColor3 = UI.Colors.Red, BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 7, Visible = false, Parent = face })
			UI.Corner(del, 18)
			local dx = Icons2D.New(del, "Close", 46, { ZIndex = 8 })
			dx.AnchorPoint = Vector2.new(0.5, 0.5)
			dx.Position = UDim2.fromScale(0.5, 0.36)
			UI.Text(del, "УДАЛЯТЬ", { Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0, 4, 0.6, 0), MaxText = 18, ZIndex = 8 })
			local card = { del = del, stroke = stroke, col = col, id = e[1] }
			cards[e[1]] = card
			setDeleteLook(card, autoDel[e[1]] == true)
			local btn = UI.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = face })
			UI.Bounce(btn, holder)
			btn.Activated:Connect(function()
				local on = not card.del.Visible
				setDeleteLook(card, on)
				local res = invoke(ctx, "PetAction", "AutoDelete", e[1], on)
				if not (res and res.ok) then
					setDeleteLook(card, not on)
				else
					ctx.Toast(on and ("«" .. def.Name .. "» будет удаляться сразу (шайни — никогда)") or ("«" .. def.Name .. "» снова попадает в инвентарь"), on and "warn" or "good")
				end
			end)
		end
		refreshButtons()
		win.Open()
	end
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			refreshButtons()
		end
	end)
	win.StopAuto = stopAuto
	return win
end

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Индекс питомцев: все питомцы по яйцам, неоткрытые — чёрные силуэты
---------------------------------------------------------------------------------------------
local function buildIndex(screen, ctx)
	local win = UI.Window(screen, { Name = "Index", Title = "ИНДЕКС ПИТОМЦЕВ", Color = UI.Colors.Purple, Icon = "Paw", Size = UDim2.fromOffset(840, 540) })
	local c = win.Content
	local _, topFace = UI.Plate(c, UDim2.new(1, 0, 0, 44), nil, UI.Colors.Dark, 999)
	local countL = UI.Text(topFace, "", { Size = UDim2.fromOffset(240, 32), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22 })
	local bar = UI.Bar(topFace, UDim2.new(1, -280, 0, 22), UDim2.fromOffset(266, 11), UI.Colors.Purple)
	local scroll = UI.Scroll(c, UDim2.new(1, 0, 1, -54), UDim2.fromOffset(0, 54))
	UI.List(scroll, 10)
	UI.Padding(scroll, 6)
	local lastCount = -1
	local CELL, GAP, COLS = 100, 8, 7
	local function render()
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		local index = data.Index or {}
		local total, open = 0, 0
		for _, egg in ipairs(EggsData.List) do
			for _, e in ipairs(egg.Pets) do
				total = total + 1
				if index[e[1]] then
					open = open + 1
				end
			end
		end
		countL.Text = "Открыто " .. open .. " / " .. total
		bar.Set(open / math.max(1, total), math.floor(open / math.max(1, total) * 100) .. "%")
		if open == lastCount then
			return
		end
		lastCount = open
		clear(scroll, true)
		for ei, egg in ipairs(EggsData.List) do
			local n = #egg.Pets
			local rows = math.ceil(n / COLS)
			local sec = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 30 + rows * (CELL + 22 + GAP)), LayoutOrder = ei, Parent = scroll })
			local biome = BiomesData[egg.Biome]
			UI.Text(sec, egg.Name .. "  ·  " .. biome.Short, { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 20 })
			for i, e in ipairs(egg.Pets) do
				local def = PetsData.ById[e[1]]
				local known = index[e[1]] == true
				local col = rarityColor(def.Rarity)
				local x = ((i - 1) % COLS) * (CELL + GAP)
				local y = 30 + math.floor((i - 1) / COLS) * (CELL + 22 + GAP)
				local _, face = UI.Plate(sec, UDim2.fromOffset(CELL, CELL + 22), UDim2.fromOffset(x, y), UI.Lighter(col, 0.35), 14)
				if def.Rarity == "Mythic" then
					UI.Gradient(face, Color3.fromRGB(255, 140, 200), Color3.fromRGB(140, 190, 255), 35)
				end
				local model = ctx.PetModel(e[1], false)
				if not known then
					EggOpening.Silhouette(model)
				end
				UI.Viewport(face, model, UDim2.new(1, -8, 0, CELL - 14), UDim2.fromOffset(4, 2))
				UI.Text(face, known and def.Name or "???", { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 1, -34), MaxText = 14 })
				local pct = e[3] < 1 and string.format("%.2f", e[3]) or string.format("%.1f", e[3])
				UI.Text(face, pct .. "%", { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -17), MaxText = 13, TextColor3 = Color3.fromRGB(255, 240, 170) })
			end
		end
	end
	win.Opened:Connect(function()
		lastCount = -1
		render()
	end)
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
	return win
end

---------------------------------------------------------------------------------------------
-- Донат: геймпассы
---------------------------------------------------------------------------------------------
local function buildDonate(screen, ctx)
	local GREEN = Color3.fromRGB(40, 200, 110)
	local win = UI.Window(screen, { Name = "Donate", Title = "ДОНАТ · ГЕЙМПАССЫ", Color = GREEN, Icon = "Diamond", Size = UDim2.fromOffset(900, 540) })
	local c = win.Content
	local scroll = UI.Scroll(c, UDim2.new(1, 0, 1, 0))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(204, 216)
	grid.CellPadding = UDim2.fromOffset(12, 14)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	UI.Padding(scroll, 6)
	local items = {}
	for i, def in ipairs(GamepassesData.List) do
		local col = c3(def.Color)
		local holder, face = UI.Plate(scroll, UDim2.fromOffset(204, 216), nil, Color3.new(1, 1, 1), 20)
		holder.LayoutOrder = i
		local top = UI.new("Frame", { BackgroundColor3 = col, Size = UDim2.new(1, -12, 0, 96), Position = UDim2.fromOffset(6, 6), Parent = face })
		UI.Corner(top, 16)
		UI.Gradient(top, UI.Lighter(col, 0.35), UI.Darker(col, 0.1))
		UI.Stroke(top, 3, UI.Edge(col), true)
		for k = 0, 3 do
			local r = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.84, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 18, 0, 150), Rotation = k * 45, Parent = top })
			UI.Corner(r, UDim.new(1, 0))
		end
		if def.Exclusive then
			local rib = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 200, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -10), Size = UDim2.fromOffset(150, 26), ZIndex = 6, Parent = face })
			UI.Corner(rib, UDim.new(1, 0))
			UI.Stroke(rib, 2.5, Color3.fromRGB(150, 90, 10), true)
			UI.Text(rib, "ЭКСКЛЮЗИВ", { Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), MaxText = 18, ZIndex = 7 })
		end
		local ic = Icons2D.New(top, def.Glyph, 70, { Color = Color3.new(1, 1, 1), Ink = UI.Edge(col), ZIndex = 4 })
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		local nm = UI.Text(face, def.Name, { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 106), MaxText = 22, StrokeThickness = 3 })
		local ns = nm:FindFirstChildOfClass("UIStroke")
		if ns then
			ns.Color = UI.Edge(col)
		end
		nm.TextColor3 = col
		UI.Text(face, def.Desc, { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 132), MaxText = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(110, 100, 140), Stroke = false })
		local buy = UI.Button({ Parent = face, Text = tostring(def.Price) .. " R$", Glyph = "Diamond", Color = GREEN, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 1, -48), TextSize = 21, Radius = 20 })
		buy.Activated:Connect(function()
			local data = ctx.ClientState.Data
			if Stats.HasPass(data, def.Key) then
				return
			end
			local id = GamepassesData.IdOf(def.Key)
			if id == 0 then
				ctx.Toast("Геймпасс ещё не настроен: впиши его ID в Configs/GamepassesData", "warn")
				return
			end
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, id)
			end)
		end)
		items[def.Key] = { buy = buy, price = def.Price }
	end
	local function render()
		local data = ctx.ClientState.Data
		for key, it in pairs(items) do
			local owned = Stats.HasPass(data, key)
			it.buy.SetText(owned and "Куплено" or (tostring(it.price) .. " R$"))
			it.buy.SetColor(owned and Color3.fromRGB(150, 146, 176) or GREEN)
			if it.buy.Glyph then
				it.buy.Glyph.Visible = not owned
			end
		end
	end
	win.Opened:Connect(render)
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
	return win
end

function Panels.Build(screen, ctx)
	local p = {}
	p.Index = buildIndex(screen, ctx)
	p.Pets = buildPets(screen, ctx)
	p.Bag = buildBag(screen, ctx)
	p.Shop = buildShop(screen, ctx)
	p.Incubator = buildIncubator(screen, ctx)
	p.Rebirth = buildRebirth(screen, ctx)
	p.Worlds = buildWorlds(screen, ctx)
	p.Npc = buildNpc(screen, ctx)
	p.Egg = buildEgg(screen, ctx)
	p.Donate = buildDonate(screen, ctx)
	require(script.Parent.RewardPanels).Build(screen, ctx, p)
	p.Quests = require(script.Parent.QuestPanel).Build(screen, ctx)
	return p
end

return Panels
