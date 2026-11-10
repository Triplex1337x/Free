-- TutorialGuide: короткое обучение для новичков.
-- Карточка с подсказкой под верхней плашкой + анимированные стрелки:
--   • в интерфейсе — стрелка у нужной кнопки (рюкзак, «На базу», «Задания», «Питомцы»);
--   • в мире — большая стрелка над целью (шахта, продажа, магазин, яйцо) и светящийся луч от игрока.
-- Прогресс хранится на сервере (data.TutorialStep), поэтому после перезахода обучение продолжается с того же шага.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local Configs = ReplicatedStorage:WaitForChild("Configs")
local DrillsData = require(Configs:WaitForChild("DrillsData"))
local EggsData = require(Configs:WaitForChild("EggsData"))

local UI = require(script.Parent.UIKit)
local Icons2D = require(script.Parent.Icons2D)

local TutorialGuide = {}
local player = Players.LocalPlayer
local DONE = 99
local YELLOW = Color3.fromRGB(255, 214, 64)

local function priceOf(list, id)
	for _, it in ipairs(list) do
		if it.Id == id then
			return it.Price or 0
		end
	end
	return 0
end

function TutorialGuide.Build(hud, ctx, panels)
	local screen = hud.Screen
	local touch = UI.IsTouch()
	local CS = ctx.ClientState
		local eggPrice = priceOf(EggsData.List, "Dirt")

	local function stats(d)
		return d.Stats or {}
	end
	local function rootPart()
		local ch = player.Character
		return ch and ch:FindFirstChild("HumanoidRootPart")
	end
	local function worldPoint(name)
		local w = workspace:FindFirstChild("World")
		return w and w:GetAttribute(name)
	end

	-------------------------------------------------------------------------------- шаги
	local steps = {
		{
			Text = touch and "Подойди к шахте и зажми палец на блоке, чтобы бурить" or "Подойди к шахте и зажми ЛКМ на блоке, чтобы бурить",
			World = "TutShaft", Label = "БУРИ ЗДЕСЬ",
			Done = function(d)
				return (stats(d).BlocksBroken or 0) >= 8
			end,
		},
		{
			Text = "Рюкзак наполняется уроном, который ты наносишь блокам. Заполни его до конца!",
			Ui = function()
				return hud.Backpack
			end, Side = "right",
			Done = function(d)
				local cap = d.Derived and d.Derived.Capacity or 30
				return (d.Ore and d.Ore.Count or 0) >= math.min(cap, 180) or (stats(d).Sells or 0) >= 1
			end,
		},
		{
			Text = touch and "Рюкзак полон! Нажми «БАЗА» — телепорт мгновенный" or "Рюкзак полон! Нажми «НА БАЗУ» (или T) — телепорт мгновенный",
			Ui = function()
				return hud.Teleport and hud.Teleport.Holder
			end, Side = "left",
			Done = function(d)
				if (stats(d).Sells or 0) >= 1 then
					return true
				end
				local r, hub = rootPart(), worldPoint("TutHub")
				return r ~= nil and hub ~= nil and r.Position.Y > -3 and (r.Position - hub).Magnitude < 40
			end,
		},
		{
			Text = "Встань на светящийся круг Репликатора — руда продастся сама",
			World = "TutSell", Label = "ПРОДАЖА",
			Done = function(d)
				return (stats(d).Sells or 0) >= 1
			end,
		},
		{
			Text = "Открой «Задания»: за них дают монеты и бусты. Готовое — забирай!",
			Ui = function()
				return hud.MenuButtons.Quests and hud.MenuButtons.Quests.Holder
			end, Side = "left",
			Done = function()
				return panels.Quests and panels.Quests.IsOpen
			end,
		},
		{
			Text = "Открой Земляное яйцо — из него выпадет питомец, он усиливает бур",
			World = "TutEgg", Label = "ЯЙЦА",
			Extra = function(d)
				if (d.Coins or 0) < eggPrice then
					return "Нужно " .. Util.Format(eggPrice) .. " монет"
				end
			end,
			Done = function(d)
				return (stats(d).EggsOpened or 0) >= 1
			end,
		},
		{
			Text = "Открой «Питомцы» — лучшие питомцы экипируются и бурят вместе с тобой",
			Ui = function()
				return hud.MenuButtons.Pets and hud.MenuButtons.Pets.Holder
			end, Side = "left",
			Done = function()
				return panels.Pets and panels.Pets.IsOpen
			end,
		},
		{
			Text = "Зайди в дом «БУРЫ» — магазин откроется сам. Буры покупаются строго по порядку",
			World = "TutDrillShop", Label = "МАГАЗИН БУРОВ",
			Done = function(d)
				return (panels.Shop and panels.Shop.IsOpen) or Util.Count(d.OwnedDrills or {}) >= 2
			end,
		},
	}

	-------------------------------------------------------------------------------- карточка
	local W = touch and 430 or 500
	local card = UI.new("Frame", { Name = "TutorialCard", BackgroundColor3 = Color3.fromRGB(32, 26, 58), BackgroundTransparency = 0.06, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(W, 92), Visible = false, ZIndex = 20, Parent = screen })
	UI.Corner(card, 20)
	UI.Stroke(card, 3, UI.Ink, true)
	UI.Gradient(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 196, 220))
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local badge = UI.new("Frame", { BackgroundColor3 = UI.Colors.Orange, Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(14, 14), ZIndex = 21, Parent = card })
	UI.Corner(badge, UDim.new(1, 0))
	UI.Stroke(badge, 3, UI.Ink, true)
	UI.Gradient(badge, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
	local bIcon = Icons2D.New(badge, "Quest", 44, { ZIndex = 22 })
	bIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	bIcon.Position = UDim2.fromScale(0.5, 0.48)
	local stepLabel = UI.Text(card, "", { Size = UDim2.new(1, -210, 0, 20), Position = UDim2.fromOffset(90, 10), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = YELLOW, MaxText = 16, ZIndex = 21, StrokeThickness = 2 })
	local body = UI.Text(card, "", { Size = UDim2.new(1, -104, 0, 54), Position = UDim2.fromOffset(90, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, MaxText = 19, ZIndex = 21, StrokeThickness = 2 })
	local skip = UI.Button({ Parent = card, Text = "Пропустить", Color = UI.Colors.Gray, Size = UDim2.fromOffset(110, 28), Position = UDim2.new(1, -120, 0, 8), TextSize = 14, Radius = 10 })
	skip.Holder.ZIndex = 22
	local okBtn = UI.Button({ Parent = card, Text = "ОК", Color = UI.Colors.Green, Size = UDim2.fromOffset(110, 28), Position = UDim2.new(1, -120, 0, 8), TextSize = 16, Radius = 10, Glyph = "Check" })
	okBtn.Holder.ZIndex = 22
	okBtn.Holder.Visible = false

	-------------------------------------------------------------------------------- стрелка в интерфейсе
	local uiArrow = UI.new("Frame", { Name = "TutorialArrow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(70, 70), Visible = false, ZIndex = 30, Parent = screen })
	local arrowGlyph = Icons2D.New(uiArrow, "Arrow", 70, { Color = YELLOW, ZIndex = 31 })
	arrowGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowGlyph.Position = UDim2.fromScale(0.5, 0.5)
	local ring = UI.new("Frame", { Name = "TutorialRing", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 29, Parent = screen })
	UI.Corner(ring, 22)
	local ringStroke = UI.Stroke(ring, 4, YELLOW, true)

	-------------------------------------------------------------------------------- стрелка в мире
	local anchor = Instance.new("Part")
	anchor.Name = "TutorialAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(0, -500, 0)
	anchor.Parent = workspace
	local att1 = Instance.new("Attachment")
	att1.Parent = anchor
	local bb = Instance.new("BillboardGui")
	bb.Name = "TutorialMarker"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(150, 150)
	bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.MaxDistance = 2000
	bb.Enabled = false
	bb.Adornee = anchor
	bb.Parent = screen.Parent and screen.Parent.Parent or player:WaitForChild("PlayerGui")
	local markLabel = UI.Text(bb, "", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 0), TextColor3 = YELLOW, MaxText = 26, StrokeThickness = 3 })
	local distLabel = UI.Text(bb, "", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 28), MaxText = 18, StrokeThickness = 2 })
	local wGlyph = Icons2D.New(bb, "Arrow", 84, { Color = YELLOW })
	wGlyph.AnchorPoint = Vector2.new(0.5, 0)
	wGlyph.Position = UDim2.new(0.5, 0, 0, 54)
	local beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Attachment1 = att1
	beam.Color = ColorSequence.new(YELLOW, Color3.fromRGB(255, 160, 40))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(1, 0.2) })
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 0.35
	beam.Width1 = 0.9
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = anchor
	local att0

	-------------------------------------------------------------------------------- логика
	local current = 0
	local finished = false
	local finalShown = false

	local function save(step)
		pcall(function()
			Net.Get("Tutorial"):FireServer(step)
		end)
	end

	local function hideArrows()
		uiArrow.Visible = false
		ring.Visible = false
		bb.Enabled = false
		beam.Enabled = false
	end

	local function finish(silent)
		finished = true
		hideArrows()
		card.Visible = false
		save(DONE)
		anchor.CFrame = CFrame.new(0, -500, 0)
		if not silent then
			ctx.Sound.Play("Unlock")
		end
		if ctx.AfterTutorial then
			task.delay(1, ctx.AfterTutorial)
		end
	end

	local function showStep(i)
		current = i
		local s = steps[i]
		stepLabel.Text = "ОБУЧЕНИЕ · ШАГ " .. i .. " / " .. #steps
		body.Text = s.Text
		card.Visible = true
		cardScale.Scale = 0.85
		TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		Icons2D.Bounce(bIcon, 1.25)
		if s.World then
			local p = worldPoint(s.World)
			if p then
				anchor.CFrame = CFrame.new(p)
			end
			markLabel.Text = s.Label or ""
		end
	end

	local function showFinal()
		finalShown = true
		current = #steps + 1
		hideArrows()
		stepLabel.Text = "ОБУЧЕНИЕ ПРОЙДЕНО!"
		body.Text = "Копи на буры и рюкзаки. Шлюз в новый ярус откроется на дне шахты, когда купишь Карьерный бур!"
		skip.Holder.Visible = false
		okBtn.Holder.Visible = true
		card.Visible = true
		UI.Pop(card)
		ctx.Sound.Play("Unlock")
		save(#steps)
		task.delay(10, function()
			if not finished then
				finish(true)
			end
		end)
	end

	skip.Activated:Connect(function()
		finish(true)
	end)
	okBtn.Activated:Connect(function()
		finish(true)
	end)

	local function evaluate()
		local d = CS.Data
		if finished or finalShown or not d then
			return
		end
		local i = current
		local advanced = false
		while i <= #steps and steps[i].Done(d) do
			i = i + 1
			advanced = true
		end
		if advanced then
			save(i - 1)
			ctx.Sound.Play("Coins", 0.05)
		end
		if i > #steps then
			showFinal()
		elseif i ~= current or not card.Visible then
			showStep(i)
		end
		local extra = steps[current] and steps[current].Extra and steps[current].Extra(d)
		if steps[current] then
			body.Text = steps[current].Text .. (extra and ("\n" .. extra) or "")
		end
	end

	-- позиционирование стрелок каждый кадр
	local function toLocal(v)
		local sc = screen:FindFirstChildOfClass("UIScale")
		local s = sc and sc.Scale or 1
		return (v - screen.AbsolutePosition) / s
	end
	local ROT = { above = 0, below = 180, left = -90, right = 90 }
	local DIR = { above = Vector2.new(0, -1), below = Vector2.new(0, 1), left = Vector2.new(-1, 0), right = Vector2.new(1, 0) }
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		if finished or finalShown or current < 1 or current > #steps then
			return
		end
		clock = clock + dt
		local s = steps[current]
		local bob = math.abs(math.sin(clock * 4)) * 12
		if s.Ui then
			bb.Enabled = false
			beam.Enabled = false
			local target = s.Ui()
			if target and target.Parent and target.AbsoluteSize.X > 1 then
				local tl = toLocal(target.AbsolutePosition)
				local sc = screen:FindFirstChildOfClass("UIScale")
				local size = target.AbsoluteSize / (sc and sc.Scale or 1)
				local center = tl + size / 2
				local dir = DIR[s.Side] or DIR.above
				local off = (dir.X ~= 0) and (size.X / 2 + 44) or (size.Y / 2 + 44)
				local pos = center + dir * (off + bob)
				uiArrow.Position = UDim2.fromOffset(pos.X, pos.Y)
				uiArrow.Rotation = ROT[s.Side] or 0
				uiArrow.Visible = true
				ring.Position = UDim2.fromOffset(center.X, center.Y)
				local grow = 10 + math.abs(math.sin(clock * 4)) * 6
				ring.Size = UDim2.fromOffset(size.X + grow, size.Y + grow)
				ringStroke.Transparency = 0.15 + math.abs(math.sin(clock * 4)) * 0.4
				ring.Visible = true
			else
				uiArrow.Visible = false
				ring.Visible = false
			end
		elseif s.World then
			uiArrow.Visible = false
			ring.Visible = false
			local r = rootPart()
			bb.Enabled = true
			bb.StudsOffset = Vector3.new(0, 7 + bob * 0.12, 0)
			if r then
				if not att0 or att0.Parent ~= r then
					att0 = Instance.new("Attachment")
					att0.Name = "TutorialAtt"
					att0.Position = Vector3.new(0, -1.5, 0)
					att0.Parent = r
					beam.Attachment0 = att0
				end
				local dist = (r.Position - anchor.Position).Magnitude
				distLabel.Text = math.floor(dist) .. " м"
				-- рядом с целью луч не нужен
				beam.Enabled = dist > 14
			else
				beam.Enabled = false
			end
		end
	end)

	task.spawn(function()
		CS.Wait()
		local d = CS.Data
		local saved = d and d.TutorialStep or 0
		if saved >= DONE then
			finished = true
			return
		end
		if saved >= #steps then
			finish(true)
			return
		end
		current = saved + 1
		-- сначала игрок выбирает качество графики
		while ctx.GraphicsChosen == false do
			task.wait(0.25)
		end
		task.wait(1.2)
		evaluate()
		CS.Changed:Connect(evaluate)
		while not finished and not finalShown do
			task.wait(0.5)
			evaluate()
		end
	end)

	TutorialGuide.IsActive = function()
		return not finished
	end
	return TutorialGuide
end

return TutorialGuide
