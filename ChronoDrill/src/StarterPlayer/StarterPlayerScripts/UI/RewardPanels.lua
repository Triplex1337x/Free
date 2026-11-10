-- RewardPanels: ежедневные награды (7 дней), колесо удачи и статистика игрока.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local RewardsData = require(Configs:WaitForChild("RewardsData"))
local Balance = require(Configs:WaitForChild("Balance"))
local BoostsData = require(Configs:WaitForChild("BoostsData"))
local SeedsData = require(Configs:WaitForChild("SeedsData"))
local PetsData = require(Configs:WaitForChild("PetsData"))
local QuestsData = require(Configs:WaitForChild("QuestsData"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))
local Stats = require(Shared:WaitForChild("Stats"))

local UI = require(script.Parent.UIKit)
local Icons3D = require(script.Parent.Icons3D)
local Icons2D = require(script.Parent.Icons2D)
local GOLD = Color3.fromRGB(255, 208, 64)

local RewardPanels = {}
local player = Players.LocalPlayer

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
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

local function biomeOf(ctx)
	local d = ctx.ClientState.Data
	return math.clamp(d and d.UnlockedBiome or 1, 1, 5)
end

-- Текст и иконка награды (для карточек и сегментов колеса)
local function describe(entry, biome, short)
	if entry.Kind == "Coins" then
		return Util.Format(RewardsData.CoinScale(biome) * entry.Amount), "Coin"
	elseif entry.Kind == "Boost" then
		local b = BoostsData.ById[entry.Id]
		return (short and "" or (b.Name .. " ")) .. "x" .. entry.Amount, entry.Id
	elseif entry.Kind == "Seed" then
		local seed = SeedsData.ByBiome[biome] or SeedsData.List[1]
		return short and "Семя" or seed.Name, "Seed"
	elseif entry.Kind == "Pet" then
		local def = PetsData.ById[entry.Id]
		return (def and def.Name or entry.Id), "Pet"
	elseif entry.Kind == "Bundle" then
		local parts = {}
		for _, it in ipairs(entry.Items) do
			local t = describe(it, biome, true)
			table.insert(parts, t)
		end
		return table.concat(parts, " + "), "Gift"
	end
	return "?", "Star"
end

local function rewardIcon(ctx, parent, entry, size)
	local _, icon = describe(entry, 1)
	if icon == "Pet" then
		return Icons3D.New(parent, ctx.PetModel(entry.Id, false), { Size = size, View = Vector3.new(0.6, 0.35, -1) })
	end
	local f = Icons2D.New(parent, icon, math.floor(size * 0.8), { Color = (icon == "Coin") and GOLD or nil, ZIndex = 5 })
	return { Viewport = f, Bounce = function()
		Icons2D.Bounce(f, 1.3)
	end }
end

local function dailyState(ctx)
	local d = ctx.ClientState.Data
	local daily = d and d.Daily or { Streak = 0, Last = 0 }
	local now = ctx.ClientState.ServerNow()
	local streak = daily.Streak or 0
	if (daily.Last or 0) > 0 and now - daily.Last > RewardsData.DailyStreakReset then
		streak = 0
	end
	local left = 0
	if (daily.Last or 0) > 0 then
		left = math.max(0, RewardsData.DailyCooldown - (now - daily.Last))
	end
	local day = (streak % #RewardsData.Daily) + 1
	return left <= 0, day, streak, left
end
RewardPanels.DailyState = dailyState

---------------------------------------------------------------------------------------------
-- Ежедневные награды
---------------------------------------------------------------------------------------------
local function buildDaily(screen, ctx)
	local win = UI.Window(screen, { Name = "Daily", Title = "ЕЖЕДНЕВНЫЕ НАГРАДЫ", Color = UI.Colors.Pink, Size = UDim2.fromOffset(900, 440) })
	local c = win.Content
	local info = UI.Text(c, "", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 4), TextColor3 = UI.Ink, Stroke = false, MaxText = 20 })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 250), Position = UDim2.fromOffset(0, 38), Parent = c })
	UI.List(row, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local cards = {}
	for i, entry in ipairs(RewardsData.Daily) do
		local big = i == #RewardsData.Daily
		local w = big and 176 or 104
		local holder, face = UI.Plate(row, UDim2.fromOffset(w, big and 244 or 214), nil, big and UI.Colors.Yellow or UI.Colors.Panel2, 16)
		holder.LayoutOrder = i
		UI.Gradient(face, Color3.new(1, 1, 1), Color3.fromRGB(210, 205, 230))
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		local title = UI.Text(face, "ДЕНЬ " .. i, { Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 6), MaxText = 22 })
		local icon = rewardIcon(ctx, face, entry, big and 140 or 84)
		icon.Viewport.AnchorPoint = Vector2.new(0.5, 0)
		icon.Viewport.Position = UDim2.new(0.5, 0, 0, 32)
		local text = UI.Text(face, "", { Size = UDim2.new(1, -10, 0, big and 46 or 52), Position = UDim2.new(0, 5, 1, big and -60 or -66), MaxText = big and 22 or 16, TextWrapped = true })
		local check = UI.new("Frame", { BackgroundColor3 = UI.Colors.Green, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(54, 54), Visible = false, ZIndex = 8, Parent = face })
		UI.Corner(check, UDim.new(1, 0))
		UI.Stroke(check, 3, UI.Ink, true)
		UI.Text(check, "✓", { ZIndex = 9, MaxText = 36 })
		local dim = UI.new("Frame", { BackgroundColor3 = UI.Ink, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = face })
		UI.Corner(dim, 16)
		cards[i] = { holder = holder, face = face, text = text, check = check, dim = dim, scale = scale, entry = entry, icon = icon, big = big }
	end
	local claim = UI.Button({ Parent = c, Text = "ЗАБРАТЬ", Color = UI.Colors.Green, Size = UDim2.fromOffset(300, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -66), TextSize = 28 })

	local function render()
		local ready, day, streak, left = dailyState(ctx)
		local biome = biomeOf(ctx)
		info.Text = "Серия: " .. streak .. " дн. · Пропустишь больше 48 часов — серия начнётся заново"
		for i, cd in ipairs(cards) do
			local txt = describe(cd.entry, biome)
			if cd.entry.Kind == "Pet" then
				txt = txt .. "\nx" .. string.format("%.2f", 1 + RewardsData.SpecialMult(cd.entry.Id, biome))
			end
			cd.text.Text = txt
			local claimed = i < day
			cd.check.Visible = claimed
			cd.dim.BackgroundTransparency = claimed and 0.55 or 1
			local stroke = cd.face:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = (i == day and ready) and Color3.fromRGB(255, 255, 255) or UI.Ink
				stroke.Thickness = (i == day and ready) and 5 or 3
			end
		end
		if ready then
			claim.SetText("ЗАБРАТЬ ДЕНЬ " .. day)
			claim.SetEnabled(true)
			claim.SetColor(UI.Colors.Green)
		else
			claim.SetText("Через " .. Util.Time(left))
			claim.SetEnabled(false)
		end
	end
	claim.Activated:Connect(function()
		local ready = dailyState(ctx)
		if not ready then
			return
		end
		local res = invoke(ctx, "ClaimDaily")
		if res and res.ok then
			ctx.Sound.Play("Unlock")
			local cd = cards[res.day]
			if cd then
				cd.scale.Scale = 1.25
				TweenService:Create(cd.scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				cd.icon.Bounce()
			end
			for _, it in ipairs(res.items or {}) do
				if it.Kind == "Pet" then
					ctx.ShowHatch({ Id = it.Id, M = it.M })
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			if win.IsOpen then
				render()
				local ready, day = dailyState(ctx)
				for i, cd in ipairs(cards) do
					if i == day and ready then
						cd.scale.Scale = 1 + math.abs(math.sin(os.clock() * 3)) * 0.05
					end
				end
				task.wait(0.05)
			else
				task.wait(0.5)
			end
		end
	end)
	win.Opened:Connect(render)
	return win
end

---------------------------------------------------------------------------------------------
-- Колесо удачи
---------------------------------------------------------------------------------------------
local function buildWheel(screen, ctx)
	local win = UI.Window(screen, { Name = "Wheel", Title = "КОЛЕСО УДАЧИ", Color = UI.Colors.Yellow, Size = UDim2.fromOffset(820, 520) })
	local c = win.Content
	local R = 190
	local segs = RewardsData.Wheel
	local n = #segs
	local segAngle = 360 / n

	local area = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(2 * R + 40, 2 * R + 40), Position = UDim2.fromOffset(0, 0), Parent = c })
	-- тень и обод
	local shadow = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 30, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(2 * R + 24, 2 * R + 24), Parent = area })
	UI.Corner(shadow, UDim.new(1, 0))
	local rim = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 200, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2 * R + 24, 2 * R + 24), Parent = area })
	UI.Corner(rim, UDim.new(1, 0))
	UI.Stroke(rim, 4, UI.Ink, true)
	UI.Gradient(rim, Color3.fromRGB(255, 240, 170), Color3.fromRGB(230, 150, 30))
	-- лампочки по ободу
	local bulbs = {}
	for i = 0, 15 do
		local a = math.rad(i * 22.5)
		local b = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 255, 220), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(a) * (R + 6), 0.5, -math.cos(a) * (R + 6)), Size = UDim2.fromOffset(12, 12), ZIndex = 3, Parent = area })
		UI.Corner(b, UDim.new(1, 0))
		UI.Stroke(b, 2, UI.Ink, true)
		bulbs[i + 1] = b
	end
	-- само колесо (вращаемый контейнер)
	local wheel = UI.new("Frame", { Name = "Wheel", Rotation = 0, BackgroundColor3 = Color3.fromRGB(50, 44, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2 * R, 2 * R), ZIndex = 2, Parent = area })
	UI.Corner(wheel, UDim.new(1, 0))
	-- секторы из тонких «спиц»: Roblox не умеет рисовать клинья, поэтому собираем их из лучей
	local spokesPer = 15
	local step = segAngle / spokesPer
	local width = math.ceil(2 * math.pi * R / (n * spokesPer) * 1.7)
	for i, seg in ipairs(segs) do
		local col = c3(seg.Color)
		for k = 0, spokesPer - 1 do
			local a = (i - 1) * segAngle + (k + 0.5) * step
			local holder = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, 2 * R - 4), Rotation = a, ZIndex = 2, Parent = wheel })
			local shade = (k % 2 == 0) and col or col:Lerp(Color3.new(0, 0, 0), 0.04)
			UI.new("Frame", { BackgroundColor3 = shade, Size = UDim2.fromScale(1, 0.5), ZIndex = 2, Parent = holder })
		end
		-- разделитель
		local div = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 2 * R), Rotation = (i - 1) * segAngle, ZIndex = 3, Parent = wheel })
		UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.15, Size = UDim2.fromScale(1, 0.5), ZIndex = 3, Parent = div })
	end
	-- подписи секторов: отдельный НЕвращаемый слой (ViewportFrame не любит поворот родителя),
	-- иконки едут по кругу вслед за колесом и всегда стоят ровно
	local labels = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2 * R, 2 * R), ZIndex = 4, Parent = area })
	for i, seg in ipairs(segs) do
		local lab = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(100, 92), ZIndex = 4, Parent = labels })
		local ic = rewardIcon(ctx, lab, seg, 62)
		ic.Viewport.AnchorPoint = Vector2.new(0.5, 0)
		ic.Viewport.Position = UDim2.new(0.5, 0, 0, 0)
		ic.Viewport.ZIndex = 5
		local txt = UI.Text(lab, "", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 62), MaxText = 19, ZIndex = 6 })
		seg._label = txt
		seg._frame = lab
	end
	local function layoutLabels(rot)
		for i, seg in ipairs(segs) do
			local a = math.rad((i - 0.5) * segAngle + rot)
			seg._frame.Position = UDim2.new(0.5, math.sin(a) * R * 0.6, 0.5, -math.cos(a) * R * 0.6)
		end
	end
	layoutLabels(0)
	-- центр
	local hub = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 255, 255), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(74, 74), ZIndex = 8, Parent = area })
	UI.Corner(hub, UDim.new(1, 0))
	UI.Stroke(hub, 4, UI.Ink, true)
	UI.Gradient(hub, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 215))
	local star = Icons2D.New(hub, "Star", 52, { Color = GOLD, ZIndex = 9 })
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.47)
	-- указатель сверху
	local pointer = UI.new("Frame", { BackgroundColor3 = UI.Colors.Red, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -R - 10), Size = UDim2.fromOffset(34, 34), Rotation = 45, ZIndex = 9, Parent = area })
	UI.Corner(pointer, 6)
	UI.Stroke(pointer, 3, UI.Ink, true)
	UI.new("Frame", { BackgroundColor3 = UI.Colors.Red, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -R - 26), Size = UDim2.fromOffset(40, 18), ZIndex = 10, Parent = area })

	-- правая колонка
	local side = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -(2 * R + 60), 1, 0), Position = UDim2.fromOffset(2 * R + 60, 0), Parent = c })
	UI.Text(side, "Крути раз в 24 часа!", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 10), TextColor3 = UI.Ink, Stroke = false, MaxText = 28 })
	UI.Text(side, "Награды растут вместе с открытым ярусом. Джекпот — эксклюзивный Кот Фортуны.", { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 48), TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 18, TextWrapped = true })
	local catHolder, catFace = UI.Plate(side, UDim2.fromOffset(220, 170), UDim2.fromOffset(20, 118), UI.Colors.Pink, 16)
	UI.Gradient(catFace, Color3.new(1, 1, 1), Color3.fromRGB(210, 200, 230))
	local cat = Icons3D.New(catFace, ctx.PetModel("FortuneCat", false), { Size = 150, View = Vector3.new(0.6, 0.35, -1) })
	cat.Viewport.AnchorPoint = Vector2.new(0.5, 0)
	cat.Viewport.Position = UDim2.new(0.5, 0, 0, 4)
	local catText = UI.Text(catFace, "", { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.new(0, 5, 1, -26), MaxText = 18 })
	local spin = UI.Button({ Parent = side, Text = "КРУТИТЬ!", Color = UI.Colors.Green, Size = UDim2.fromOffset(260, 66), Position = UDim2.fromOffset(0, 312), TextSize = 30 })
	local timerText = UI.Text(side, "", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 388), TextColor3 = UI.Ink, Stroke = false, MaxText = 20 })

	local spinning = false
	local function wheelLeft()
		local d = ctx.ClientState.Data
		local last = d and d.WheelLast or 0
		if last <= 0 then
			return 0
		end
		return math.max(0, RewardsData.WheelCooldown - (ctx.ClientState.ServerNow() - last))
	end
	local function render()
		local biome = biomeOf(ctx)
		for _, seg in ipairs(segs) do
			local t = describe(seg, biome, true)
			if seg.Kind == "Pet" then
				t = "ДЖЕКПОТ"
			end
			seg._label.Text = t
		end
		catText.Text = "Кот Фортуны x" .. string.format("%.2f", 1 + RewardsData.SpecialMult("FortuneCat", biome))
		if spinning then
			return
		end
		local left = wheelLeft()
		if left > 0 then
			spin.SetText(Util.Time(left))
			spin.SetEnabled(false)
			timerText.Text = "Следующая попытка через " .. Util.Time(left)
		else
			spin.SetText("КРУТИТЬ!")
			spin.SetEnabled(true)
			spin.SetColor(UI.Colors.Green)
			timerText.Text = "Колесо готово!"
		end
	end

	local function showPrize(items)
		local texts = {}
		for _, it in ipairs(items or {}) do
			table.insert(texts, it.Text)
			if it.Kind == "Pet" then
				ctx.ShowHatch({ Id = it.Id, M = it.M })
			end
		end
		ctx.Toast("Выигрыш: " .. table.concat(texts, ", "), "good")
		ctx.Sound.Play("Reveal")
	end

	spin.Activated:Connect(function()
		if spinning or wheelLeft() > 0 then
			return
		end
		local res = invoke(ctx, "SpinWheel")
		if not (res and res.ok) then
			return
		end
		spinning = true
		spin.SetEnabled(false)
		spin.SetText("Крутится...")
		local current = wheel.Rotation % 360
		local mid = (res.index - 0.5) * segAngle
		local jitter = (math.random() - 0.5) * segAngle * 0.6
		local target = -mid + jitter
		local delta = (target - current) % 360
		local final = wheel.Rotation + 360 * 6 + delta
		local value = Instance.new("NumberValue")
		value.Value = wheel.Rotation
		local lastTick = math.floor(wheel.Rotation / segAngle)
		value.Changed:Connect(function(v)
			wheel.Rotation = v
			layoutLabels(v)
			local tickIdx = math.floor(v / segAngle)
			if tickIdx ~= lastTick then
				lastTick = tickIdx
				ctx.Sound.Play("Click", 0.1, 0.6)
			end
		end)
		local tw = TweenService:Create(value, TweenInfo.new(4.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = final })
		tw:Play()
		tw.Completed:Connect(function()
			value:Destroy()
			spinning = false
			showPrize(res.items)
			render()
		end)
	end)

	task.spawn(function()
		local t = 0
		while true do
			if win.IsOpen then
				t = t + 1
				for i, b in ipairs(bulbs) do
					local on = ((i + t) % 2 == 0)
					if spinning then
						on = ((i + t) % 3 == 0)
					end
					b.BackgroundColor3 = on and Color3.fromRGB(255, 255, 210) or Color3.fromRGB(200, 120, 40)
				end
				render()
				task.wait(spinning and 0.08 or 0.4)
			else
				task.wait(0.5)
			end
		end
	end)
	win.Opened:Connect(render)
	return win
end

---------------------------------------------------------------------------------------------
-- Статистика
---------------------------------------------------------------------------------------------
local function buildStats(screen, ctx)
	local win = UI.Window(screen, { Name = "Stats", Title = "СТАТИСТИКА", Color = Color3.fromRGB(120, 110, 255), Size = UDim2.fromOffset(860, 520) })
	local c = win.Content
	-- шапка игрока
	local _, head = UI.Plate(c, UDim2.new(1, 0, 0, 86), UDim2.fromOffset(0, 0), UI.Colors.Panel2, 16)
	local avatar = UI.new("ImageLabel", { BackgroundColor3 = UI.Colors.Blue, Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(8, 8), Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150", Parent = head })
	UI.Corner(avatar, UDim.new(1, 0))
	UI.Stroke(avatar, 3, UI.Ink, true)
	UI.Text(head, player.DisplayName, { Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.fromOffset(92, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 30 })
	local sub = UI.Text(head, "", { Size = UDim2.new(1, -100, 0, 26), Position = UDim2.fromOffset(92, 46), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 20 })

	local scroll = UI.Scroll(c, UDim2.new(1, 0, 1, -98), UDim2.fromOffset(0, 96))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(258, 76)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	UI.Padding(scroll, 6)

	local function bestPet(data)
		local best, bm = nil, 0
		for _, p in pairs(data.Pets or {}) do
			local m = Stats.PetMult(p)
			if m > bm then
				best, bm = p, m
			end
		end
		if not best then
			return "—"
		end
		local def = PetsData.ById[best.Id]
		local tier = Balance.PetTiers[(best.T or 0) + 1]
		return (def and def.Name or best.Id) .. ((tier and tier.Name ~= "") and (" " .. tier.Name) or "") .. " · ур." .. (best.L or 1)
	end

	local defs = {
		{ "Всего монет заработано", "Coin", function(d) return Util.Format(d.TotalCoins or 0) end },
		{ "Блоков сломано", "Drill", function(d) return Util.Commas(d.Stats.BlocksBroken or 0) end },
		{ "Рекорд глубины", "Planet", function(d) return Util.Commas(d.Stats.MaxDepth or 0) .. " м" end },
		{ "Суммарный урон", "Star", function(d) return Util.Format(d.Stats.TotalDamage or 0) end },
		{ "Критических ударов", "DrillOvercharge", function(d) return Util.Commas(d.Stats.Crits or 0) end },
		{ "Рюкзаков продано", "Backpack", function(d) return Util.Commas(d.Stats.Sells or 0) end },
		{ "Яиц открыто", "Gift", function(d) return Util.Commas(d.Stats.EggsOpened or 0) end },
		{ "Питомцев сейчас", "Paw", function(d) return tostring(Stats.PetCount(d)) end },
		{ "Лучший питомец", "Paw", bestPet },
		{ "Улучшений питомцев", "Star", function(d) return Util.Commas(d.Stats.GoldenCrafted or 0) end },
		{ "Семян выращено", "Seed", function(d) return Util.Commas(d.Stats.SeedsGrown or 0) end },
		{ "Перерождений", "Hourglass", function(d) return tostring(d.Rebirths or 0) end },
		{ "Хроно-Осколков", "Shard", function(d) return tostring(d.Shards or 0) end },
		{ "Сюжетных квестов", "Scroll", function(d) return math.min((d.StoryIndex or 1) - 1, #QuestsData.Story) .. " / " .. #QuestsData.Story end },
		{ "Ежедневных наград", "Gift", function(d) return tostring(d.Stats.DailyClaims or 0) end },
		{ "Вращений колеса", "Wheel", function(d) return tostring(d.Stats.WheelSpins or 0) end },
		{ "Время в игре", "Clock", function(d) return Util.Time(d.Stats.PlayTime or 0) end },
		{ "Открыто ярусов", "Planet", function(d) return (d.UnlockedBiome or 1) .. " / 5" end },
	}
	local values = {}
	for i, def in ipairs(defs) do
		local holder, face = UI.Plate(scroll, UDim2.fromOffset(258, 76), nil, UI.Colors.Panel, 14)
		holder.LayoutOrder = i
		UI.Gradient(face, Color3.new(1, 1, 1), Color3.fromRGB(220, 216, 236))
		local badgeColors = { UI.Colors.Orange, UI.Colors.Purple, UI.Colors.Red, UI.Colors.Blue, UI.Colors.Pink, UI.Colors.Green, UI.Colors.Teal, UI.Colors.Yellow }
		local bg = UI.new("Frame", { BackgroundColor3 = badgeColors[(i - 1) % #badgeColors + 1], Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 10), Parent = face })
		UI.Corner(bg, 14)
		UI.Stroke(bg, 3, UI.Ink, true)
		UI.Gradient(bg, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
		local ic = Icons2D.New(bg, def[2], 40, { ZIndex = 3 })
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.47)
		UI.Text(face, def[1], { Size = UDim2.new(1, -86, 0, 22), Position = UDim2.fromOffset(76, 10), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 16 })
		values[i] = UI.Text(face, "", { Size = UDim2.new(1, -86, 0, 32), Position = UDim2.fromOffset(76, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 26 })
	end
	local function render()
		local d = ctx.ClientState.Data
		if not d or not d.Stats then
			return
		end
		sub.Text = "Ребёрсов: " .. (d.Rebirths or 0) .. "  ·  Монет: " .. Util.Format(d.Coins or 0) .. "  ·  Урон: " .. Util.Format(d.Derived and d.Derived.Damage or 0)
		for i, def in ipairs(defs) do
			values[i].Text = def[3](d)
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

function RewardPanels.Build(screen, ctx, panels)
	panels.Daily = buildDaily(screen, ctx)
	panels.Wheel = buildWheel(screen, ctx)
	panels.Stats = buildStats(screen, ctx)
	return panels
end

return RewardPanels
