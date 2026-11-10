-- AdminPanel: удобная панель разработчика (F2). Видна только админам (атрибут IsAdmin от сервера).
-- Слева выбираешь игрока на сервере (или «Все»), справа — вкладки: ресурсы, питомцы,
-- телепорт, геймпассы, события и консоль. Каждая кнопка отправляет на сервер обычную
-- админ-команду (те же команды можно писать в чат: !coins 1m).
-- F3 — старая текстовая консоль.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local PetsData = require(Configs:WaitForChild("PetsData"))
local EggsData = require(Configs:WaitForChild("EggsData"))
local BiomesData = require(Configs:WaitForChild("BiomesData"))
local Balance = require(Configs:WaitForChild("Balance"))
local GamepassesData = require(Configs:WaitForChild("GamepassesData"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local UI = require(script.Parent.UIKit)
local Icons2D = require(script.Parent.Icons2D)

local AdminPanel = {}
local player = Players.LocalPlayer

local ACCENT = Color3.fromRGB(255, 84, 110)
local INK2 = Color3.fromRGB(70, 60, 96)

local function label(parent, text, pos, size, color, maxText)
	return UI.Text(parent, text, { Size = size or UDim2.new(1, 0, 0, 22), Position = pos or UDim2.new(), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or INK2, Stroke = false, MaxText = maxText or 18 })
end

local function box(parent, placeholder, size, pos, text)
	local b = UI.new("TextBox", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = size,
		Position = pos or UDim2.new(),
		Font = UI.Font,
		TextSize = 18,
		TextColor3 = INK2,
		PlaceholderText = placeholder,
		PlaceholderColor3 = Color3.fromRGB(170, 166, 196),
		ClearTextOnFocus = false,
		Text = text or "",
		Parent = parent,
	})
	UI.Corner(b, 12)
	UI.Stroke(b, 2.5, Color3.fromRGB(196, 190, 222), true)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	return b
end

-- строка «заголовок + кнопки»
local function row(parent, title, order)
	local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 46), LayoutOrder = order, Parent = parent })
	label(r, title, UDim2.fromOffset(0, 12), UDim2.fromOffset(130, 22), INK2, 17)
	local btns = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -136, 1, 0), Position = UDim2.fromOffset(136, 0), Parent = r })
	UI.List(btns, 6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	return btns
end

function AdminPanel.Build(screen, ctx)
	local win = UI.Window(screen, { Name = "Admin", Title = "ПАНЕЛЬ РАЗРАБОТЧИКА", Color = ACCENT, Icon = "Shield", Size = UDim2.fromOffset(940, 560) })
	local c = win.Content
	local target = nil -- nil = я; "all" = все; иначе Player

	---------------------------------------------------------------- отправка команд
	local function send(line, quiet)
		local suffix = ""
		if target == "all" then
			suffix = " @all"
		elseif typeof(target) == "Instance" and target ~= player then
			suffix = " @" .. target.Name
		end
		local ok, res = pcall(function()
			return Net.Get("AdminCommand"):InvokeServer(line .. suffix)
		end)
		local text = (ok and res and res.text) or "Ошибка соединения"
		if not quiet then
			ctx.Toast(string.sub(text, 1, 160), (ok and res and res.ok) and "good" or "warn")
		end
		if AdminPanel.Log then
			AdminPanel.Log("> " .. line .. suffix, Color3.fromRGB(110, 240, 160))
			AdminPanel.Log(text, (ok and res and res.ok) and Color3.fromRGB(230, 230, 245) or Color3.fromRGB(255, 150, 130))
		end
		return ok and res and res.ok, text
	end
	local function btn(parent, text, color, w, fn, order)
		local b = UI.Button({ Parent = parent, Text = text, Color = color or UI.Colors.Blue, Size = UDim2.fromOffset(w or 96, 38), TextSize = 17, Radius = 19, LayoutOrder = order or 0 })
		b.Activated:Connect(fn)
		return b
	end

	---------------------------------------------------------------- игроки (слева)
	local _, left = UI.Plate(c, UDim2.new(0, 200, 1, 0), UDim2.new(), Color3.fromRGB(250, 246, 255), 18)
	local ph = UI.new("Frame", { BackgroundColor3 = ACCENT, Size = UDim2.new(1, -12, 0, 38), Position = UDim2.fromOffset(6, 6), Parent = left })
	UI.Corner(ph, 12)
	UI.Gradient(ph, UI.Lighter(ACCENT, 0.25), UI.Darker(ACCENT, 0.1))
	local pi = Icons2D.New(ph, "Person", 30, { Ink = UI.Edge(ACCENT), ZIndex = 4 })
	pi.Position = UDim2.fromOffset(6, 4)
	UI.Text(ph, "ИГРОК", { Size = UDim2.new(1, -50, 1, -10), Position = UDim2.fromOffset(42, 5), MaxText = 20, TextXAlignment = Enum.TextXAlignment.Left })
	local plist = UI.Scroll(left, UDim2.new(1, -12, 1, -56), UDim2.fromOffset(6, 50))
	UI.List(plist, 6)
	UI.Padding(plist, 4)
	local current = UI.Text(c, "", { Size = UDim2.new(1, -220, 0, 20), Position = UDim2.new(0, 214, 1, -20), TextXAlignment = Enum.TextXAlignment.Right, MaxText = 15, TextColor3 = Color3.fromRGB(150, 140, 180), Stroke = false })

	local playerButtons = {}
	local function targetName()
		if target == "all" then
			return "ВСЕ ИГРОКИ"
		elseif typeof(target) == "Instance" then
			return target.Name
		end
		return player.Name .. " (я)"
	end
	local function paintPlayers()
		for key, b in pairs(playerButtons) do
			local on = (key == "all" and target == "all") or (key == "me" and target == nil) or (typeof(key) == "Instance" and key == target)
			b.SetColor(on and UI.Colors.Green or Color3.fromRGB(150, 144, 184))
		end
		current.Text = "Цель: " .. targetName()
	end
	local function refreshPlayers()
		for _, ch in ipairs(plist:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		playerButtons = {}
		local me = UI.Button({ Parent = plist, Text = "Я сам", Color = UI.Colors.Green, Size = UDim2.new(1, -8, 0, 38), TextSize = 17, Radius = 19, LayoutOrder = 0 })
		me.Activated:Connect(function()
			target = nil
			paintPlayers()
		end)
		playerButtons.me = me
		local all = UI.Button({ Parent = plist, Text = "Все на сервере", Color = UI.Colors.Purple, Size = UDim2.new(1, -8, 0, 38), TextSize = 16, Radius = 19, LayoutOrder = 1 })
		all.Activated:Connect(function()
			target = "all"
			paintPlayers()
		end)
		playerButtons.all = all
		for i, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local b = UI.Button({ Parent = plist, Text = p.DisplayName, Color = UI.Colors.Blue, Size = UDim2.new(1, -8, 0, 38), TextSize = 16, Radius = 19, LayoutOrder = 1 + i })
				b.Activated:Connect(function()
					target = p
					paintPlayers()
				end)
				playerButtons[p] = b
			end
		end
		if typeof(target) == "Instance" and not target.Parent then
			target = nil
		end
		paintPlayers()
	end
	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end)

	---------------------------------------------------------------- вкладки (справа)
	local right = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -214, 1, -24), Position = UDim2.fromOffset(214, 0), Parent = c })
	local tabBar = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = right })
	UI.List(tabBar, 6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	local pagesHolder = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(252, 250, 255), Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52), Parent = right })
	UI.Corner(pagesHolder, 18)
	UI.Stroke(pagesHolder, 3, Color3.fromRGB(214, 206, 236), true)
	local TABS = {
		{ "Ресурсы", "Coin", UI.Colors.Yellow },
		{ "Питомцы", "Paw", UI.Colors.Orange },
		{ "Телепорт", "Globe", UI.Colors.Blue },
		{ "Пассы", "Diamond", UI.Colors.Purple },
		{ "События", "Flag", UI.Colors.Pink },
		{ "Консоль", "Quest", UI.Colors.Teal },
	}
	local pages, tabButtons = {}, {}
	local function select(i)
		for k, p in ipairs(pages) do
			p.Visible = k == i
			tabButtons[k].SetColor(k == i and TABS[k][3] or Color3.fromRGB(176, 172, 200))
		end
	end
	for i, t in ipairs(TABS) do
		local b = UI.Button({ Parent = tabBar, Text = t[1], Glyph = t[2], Color = Color3.fromRGB(176, 172, 200), Size = UDim2.fromOffset(112, 40), TextSize = 15, Radius = 20, LayoutOrder = i })
		b.Activated:Connect(function()
			select(i)
		end)
		tabButtons[i] = b
		local page = UI.Scroll(pagesHolder, UDim2.new(1, -16, 1, -16), UDim2.fromOffset(8, 8))
		page.Visible = false
		UI.List(page, 6)
		UI.Padding(page, 6)
		pages[i] = page
	end

	---------------------------------------------------------------- 1. Ресурсы
	do
		local p = pages[1]
		local r = row(p, "Монеты", 1)
		for i, v in ipairs({ { "+1K", "1k" }, { "+1M", "1m" }, { "+1B", "1b" }, { "+1T", "1t" }, { "+1Qa", "1q" } }) do
			btn(r, v[1], UI.Colors.Yellow, 70, function()
				send("coins " .. v[2])
			end, i)
		end
		btn(r, "Обнулить", UI.Colors.Red, 100, function()
			send("setcoins 0")
		end, 9)
		r = row(p, "Перерождения", 2)
		for i, v in ipairs({ 1, 5, 10, 50 }) do
			btn(r, "+" .. v, UI.Colors.Teal, 70, function()
				send("addrebirths " .. v)
			end, i)
		end
		btn(r, "Обнулить", UI.Colors.Red, 100, function()
			send("rebirths 0")
		end, 9)
		r = row(p, "Осколки", 3)
		for i, v in ipairs({ 10, 100, 1000 }) do
			btn(r, "+" .. v, UI.Colors.Purple, 80, function()
				send("shards " .. v)
			end, i)
		end
		r = row(p, "Предметы", 4)
		btn(r, "Бусты +5", UI.Colors.Orange, 110, function()
			send("boosts 5")
		end, 1)
		btn(r, "Семена +3", UI.Colors.Green, 110, function()
			send("seeds 3")
		end, 2)
		btn(r, "Открыть всё", UI.Colors.Blue, 130, function()
			send("max")
		end, 3)
		r = row(p, "Прогресс", 5)
		btn(r, "Задания ✓", UI.Colors.Blue, 110, function()
			send("quests")
		end, 1)
		btn(r, "Новые задания", UI.Colors.Teal, 140, function()
			send("newquests")
		end, 2)
		btn(r, "Награда+Колесо", UI.Colors.Pink, 150, function()
			send("daily", true)
			send("wheel")
		end, 3)
		r = row(p, "Своё число", 6)
		local amount = box(r, "например 2.5b", UDim2.fromOffset(150, 38))
		amount.LayoutOrder = 0
		btn(r, "Монеты", UI.Colors.Yellow, 90, function()
			send("coins " .. amount.Text)
		end, 1)
		btn(r, "Ребёрсы", UI.Colors.Teal, 90, function()
			send("rebirths " .. amount.Text)
		end, 2)
		btn(r, "Осколки", UI.Colors.Purple, 90, function()
			send("shards " .. amount.Text)
		end, 3)
		r = row(p, "Опасно", 7)
		btn(r, "Сбросить профиль", UI.Colors.Red, 170, function()
			send("wipe")
		end, 1)
		btn(r, "Инфо", UI.Colors.Gray, 90, function()
			send("info")
		end, 2)
	end

	---------------------------------------------------------------- 2. Питомцы
	do
		local p = pages[2]
		local tier, chosen = 0, nil
		local top = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 1, Parent = p })
		UI.List(top, 6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
		local search = box(top, "поиск питомца…", UDim2.fromOffset(200, 38))
		search.LayoutOrder = 1
		local lvl = box(top, "ур. 1", UDim2.fromOffset(70, 38), nil, "1")
		lvl.LayoutOrder = 2
		local cnt = box(top, "кол-во", UDim2.fromOffset(70, 38), nil, "1")
		cnt.LayoutOrder = 3
		local give = btn(top, "Выдать", UI.Colors.Green, 110, function()
			if not chosen then
				ctx.Toast("Выбери питомца в списке", "warn")
				return
			end
			send("pet " .. chosen .. " " .. tier .. " " .. (tonumber(lvl.Text) or 1) .. " " .. (tonumber(cnt.Text) or 1))
		end, 4)
		local tiers = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = p })
		UI.List(tiers, 5, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
		local tierBtns = {}
		for t = 0, #Balance.PetTiers - 1 do
			local d = Balance.PetTiers[t + 1]
			local b = UI.Button({ Parent = tiers, Text = t == 0 and "Обычный" or d.Short, Color = UI.Colors.Gray, Size = UDim2.fromOffset(t == 0 and 96 or 72, 34), TextSize = 15, Radius = 17, LayoutOrder = t })
			b.Activated:Connect(function()
				tier = t
				for k, bb in pairs(tierBtns) do
					bb.SetColor(k == tier and UI.Colors.Yellow or UI.Colors.Gray)
				end
			end)
			tierBtns[t] = b
		end
		tierBtns[0].SetColor(UI.Colors.Yellow)
		local extra = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 3, Parent = p })
		UI.List(extra, 6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
		btn(extra, "Надетым ур. 30", UI.Colors.Teal, 150, function()
			send("petlevel " .. Balance.PetMaxLevel)
		end, 1)
		btn(extra, "Удалить всех", UI.Colors.Red, 130, function()
			send("clearpets")
		end, 2)
		local chosenL = label(extra, "Не выбран", nil, UDim2.fromOffset(220, 30), ACCENT, 16)
		chosenL.LayoutOrder = 3
		local gridF = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = p })
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(126, 40)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = gridF
		-- список питомцев: по яйцам, затем особые
		local ordered, seen = {}, {}
		for _, egg in ipairs(EggsData.List) do
			for _, e in ipairs(egg.Pets) do
				if not seen[e[1]] and PetsData.ById[e[1]] then
					seen[e[1]] = true
					table.insert(ordered, e[1])
				end
			end
		end
		local rest = {}
		for id in pairs(PetsData.ById) do
			if not seen[id] then
				table.insert(rest, id)
			end
		end
		table.sort(rest)
		for _, id in ipairs(rest) do
			table.insert(ordered, id)
		end
		local cells = {}
		for i, id in ipairs(ordered) do
			local def = PetsData.ById[id]
			local r = PetsData.Rarity[def.Rarity]
			local col = r and Color3.fromRGB(r.Color[1], r.Color[2], r.Color[3]) or UI.Colors.Gray
			local b = UI.Button({ Parent = gridF, Text = def.Name, Color = col, Size = UDim2.fromOffset(126, 40), TextSize = 14, Radius = 12, LayoutOrder = i })
			b.Activated:Connect(function()
				chosen = id
				chosenL.Text = "Выбран: " .. def.Name
			end)
			cells[id] = { b = b, name = string.lower(def.Name .. " " .. id) }
		end
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = string.lower(search.Text)
			for _, cell in pairs(cells) do
				cell.b.Holder.Visible = q == "" or string.find(cell.name, q, 1, true) ~= nil
			end
		end)
		local _ = give
	end

	---------------------------------------------------------------- 3. Телепорт
	do
		local p = pages[3]
		for b, biome in ipairs(BiomesData) do
			local r = row(p, b .. ". " .. biome.Short, b)
			local col = Color3.fromRGB(biome.Theme.UI[1], biome.Theme.UI[2], biome.Theme.UI[3])
			btn(r, "База", col, 110, function()
				send("tp hub " .. b)
			end, 1)
			btn(r, "Шахта", UI.Darker(col, 0.15), 110, function()
				send("tp mine " .. b)
			end, 2)
			btn(r, "Открыть ярус", UI.Colors.Green, 140, function()
				send("unlock " .. math.max(b, 1))
			end, 3)
		end
		local r = row(p, "Игрок", 10)
		btn(r, "К игроку", UI.Colors.Purple, 130, function()
			send("goto")
		end, 1)
		btn(r, "Призвать к себе", UI.Colors.Pink, 160, function()
			send("bring")
		end, 2)
		r = row(p, "Скорость", 11)
		for i, v in ipairs({ { "Обычная", 0 }, { "x2", 32 }, { "x4", 64 } }) do
			btn(r, v[1], UI.Colors.Teal, 100, function()
				send("speed " .. v[2])
			end, i)
		end
	end

	---------------------------------------------------------------- 4. Геймпассы
	do
		local p = pages[4]
		local r = row(p, "Все пассы", 0)
		btn(r, "Выдать все", UI.Colors.Green, 130, function()
			send("pass all on")
		end, 1)
		btn(r, "Снять все", UI.Colors.Red, 130, function()
			send("pass all off")
		end, 2)
		for i, def in ipairs(GamepassesData.List) do
			local col = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
			local rr = UI.new("Frame", { BackgroundColor3 = UI.Lighter(col, 0.8), Size = UDim2.new(1, -8, 0, 50), LayoutOrder = i, Parent = p })
			UI.Corner(rr, 14)
			UI.Stroke(rr, 2.5, UI.Lighter(col, 0.3), true)
			local ic = Icons2D.New(rr, def.Glyph, 38, { Color = col, Ink = UI.Edge(col), ZIndex = 4 })
			ic.Position = UDim2.fromOffset(8, 5)
			label(rr, def.Name, UDim2.fromOffset(54, 4), UDim2.fromOffset(240, 22), INK2, 18)
			label(rr, def.Desc, UDim2.fromOffset(54, 26), UDim2.new(1, -300, 0, 18), Color3.fromRGB(130, 120, 160), 13)
			local on = UI.Button({ Parent = rr, Text = "Выдать", Color = UI.Colors.Green, Size = UDim2.fromOffset(100, 36), Position = UDim2.new(1, -214, 0, 6), TextSize = 16, Radius = 18 })
			on.Activated:Connect(function()
				send("pass " .. def.Key .. " on")
			end)
			local off = UI.Button({ Parent = rr, Text = "Снять", Color = UI.Colors.Red, Size = UDim2.fromOffset(100, 36), Position = UDim2.new(1, -108, 0, 6), TextSize = 16, Radius = 18 })
			off.Activated:Connect(function()
				send("pass " .. def.Key .. " off")
			end)
		end
	end

	---------------------------------------------------------------- 5. События
	do
		local p = pages[5]
		local minutes = 15
		local r = row(p, "Длительность", 0)
		local durBtns = {}
		for i, m in ipairs({ 5, 15, 30, 60 }) do
			local b = btn(r, m .. " мин", UI.Colors.Gray, 90, function()
				minutes = m
				for k, bb in pairs(durBtns) do
					bb.SetColor(k == m and UI.Colors.Blue or UI.Colors.Gray)
				end
			end, i)
			durBtns[m] = b
		end
		durBtns[15].SetColor(UI.Colors.Blue)
		local kinds = { { "coins", "Монеты", UI.Colors.Yellow }, { "damage", "Урон", UI.Colors.Red }, { "luck", "Удача", UI.Colors.Green } }
		for i, k in ipairs(kinds) do
			r = row(p, k[2], i)
			for j, m in ipairs({ 2, 3, 5, 10 }) do
				btn(r, "x" .. m, k[3], 80, function()
					send("event " .. k[1] .. " " .. m .. " " .. minutes)
				end, j)
			end
		end
		r = row(p, "Шахта", 5)
		btn(r, "Золотая лихорадка", UI.Colors.Yellow, 180, function()
			send("goldrush")
		end, 1)
		btn(r, "Вайп шахт", UI.Colors.Orange, 120, function()
			send("resetmine")
		end, 2)
		btn(r, "Стоп событиям", UI.Colors.Red, 150, function()
			send("event stop")
		end, 3)
		r = row(p, "Время суток", 6)
		for i, v in ipairs({ { "Утро", 9 }, { "День", 14 }, { "Закат", 18.3 }, { "Ночь", 23 } }) do
			btn(r, v[1], UI.Colors.Blue, 86, function()
				send("time " .. v[2])
			end, i)
		end
		r = row(p, "Объявление", 7)
		local msg = box(r, "текст для всех игроков", UDim2.fromOffset(330, 38))
		msg.LayoutOrder = 0
		btn(r, "Отправить", UI.Colors.Pink, 120, function()
			if msg.Text ~= "" then
				send("announce " .. msg.Text)
				msg.Text = ""
			end
		end, 1)
	end

	---------------------------------------------------------------- 6. Консоль
	do
		local p = pages[6]
		p.AutomaticCanvasSize = Enum.AutomaticSize.None
		local r = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 1, Parent = p })
		local input = box(r, "команда, например: coins 1m   (help — список)", UDim2.new(1, -120, 0, 38), UDim2.fromOffset(0, 3))
		local go = UI.Button({ Parent = r, Text = "Выполнить", Color = UI.Colors.Teal, Size = UDim2.fromOffset(110, 38), Position = UDim2.new(1, -110, 0, 3), TextSize = 16, Radius = 19 })
		local logF = UI.new("ScrollingFrame", { BackgroundColor3 = Color3.fromRGB(26, 22, 40), Size = UDim2.new(1, -8, 0, 300), LayoutOrder = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = p })
		UI.Corner(logF, 12)
		UI.List(logF, 2)
		UI.Padding(logF, 8)
		local n = 0
		function AdminPanel.Log(text, color)
			for piece in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
				n = n + 1
				UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Code, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or Color3.new(1, 1, 1), Text = piece, LayoutOrder = n, Parent = logF })
			end
			task.defer(function()
				logF.CanvasPosition = Vector2.new(0, 1e6)
			end)
		end
		local function run()
			local t = string.gsub(input.Text, "^%s+", "")
			if t ~= "" then
				send(t, true)
				input.Text = ""
			end
		end
		go.Activated:Connect(run)
		input.FocusLost:Connect(function(enter)
			if enter then
				run()
			end
		end)
		AdminPanel.Log("Команды: help. Цель выбирается слева (или @ник в конце команды).", Color3.fromRGB(160, 160, 200))
	end

	select(1)
	refreshPlayers()

	local function toggle()
		if not player:GetAttribute("IsAdmin") then
			return
		end
		if not win.IsOpen then
			refreshPlayers()
		end
		ctx.OpenPanel("Admin")
	end
	AdminPanel.Toggle = toggle
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F2 then
			toggle()
		end
	end)
	return win
end

return AdminPanel
