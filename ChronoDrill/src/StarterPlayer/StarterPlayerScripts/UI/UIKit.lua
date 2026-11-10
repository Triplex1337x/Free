-- UIKit: мультяшный векторный UI (ТЗ 9.2).
-- Толстые тёмные рамки (UIStroke 3px), объёмные плашки с тенью вниз, FredokaOne,
-- hover: Scale 1.05 за 0.1 с (Quad), click: 0.95 + щелчок.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Ink = Color3.fromRGB(28, 22, 44)
UI.Colors = {
	Panel = Color3.fromRGB(250, 247, 255),
	Panel2 = Color3.fromRGB(234, 229, 250),
	Panel3 = Color3.fromRGB(214, 207, 238),
	Green = Color3.fromRGB(88, 214, 96),
	Blue = Color3.fromRGB(70, 160, 255),
	Yellow = Color3.fromRGB(255, 198, 48),
	Red = Color3.fromRGB(255, 86, 86),
	Purple = Color3.fromRGB(164, 96, 255),
	Orange = Color3.fromRGB(255, 146, 46),
	Teal = Color3.fromRGB(50, 210, 196),
	Pink = Color3.fromRGB(255, 110, 170),
	Gray = Color3.fromRGB(150, 148, 170),
	Dark = Color3.fromRGB(52, 46, 74),
	White = Color3.fromRGB(255, 255, 255),
}

local clickSound

function UI.SetClickSound(fn)
	clickSound = fn
end

function UI.new(class, props, children)
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if inst:IsA("GuiObject") and (not props or props.BorderSizePixel == nil) then
		inst.BorderSizePixel = 0
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(inst, r)
	local c = Instance.new("UICorner")
	if type(r) == "number" then
		c.CornerRadius = UDim.new(0, r)
	else
		c.CornerRadius = r or UDim.new(0, 12)
	end
	c.Parent = inst
	return c
end

function UI.Stroke(inst, thickness, color, border)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or UI.Ink
	s.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = inst
	return s
end

-- Градиент. Серые стопы (белый→серый) «затеняют» цвет фона (UIGradient умножается на него);
-- цветные стопы — это и есть цвета, поэтому фон делаем белым, чтобы цвет не «темнел» от умножения.
local function sat(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	return mx > 0 and (mx - mn) / mx or 0
end
function UI.Gradient(inst, top, bottom, rot)
	top = top or Color3.new(1, 1, 1)
	bottom = bottom or Color3.fromRGB(205, 205, 215)
	if (sat(top) > 0.12 or sat(bottom) > 0.12) and inst:IsA("GuiObject") then
		inst.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top or Color3.new(1, 1, 1), bottom or Color3.fromRGB(205, 205, 215))
	g.Rotation = rot or 90
	g.Parent = inst
	return g
end

function UI.Padding(inst, px)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = inst
	return p
end

function UI.List(inst, padding, dir, halign, valign)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 6)
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if halign then
		l.HorizontalAlignment = halign
	end
	if valign then
		l.VerticalAlignment = valign
	end
	l.Parent = inst
	return l
end

function UI.Darker(c, f)
	return c:Lerp(Color3.new(0, 0, 0), f or 0.28)
end

function UI.Lighter(c, f)
	return c:Lerp(Color3.new(1, 1, 1), f or 0.3)
end

-- «Леденцовый» градиент: светлый верх -> чистый цвет -> чуть темнее низ. Цвет задаётся самим градиентом,
-- поэтому фон объекта должен быть белым (UIGradient умножается на фон).
function UI.CandySeq(c)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, UI.Lighter(c, 0.3)),
		ColorSequenceKeypoint.new(0.5, c),
		ColorSequenceKeypoint.new(1, UI.Darker(c, 0.12)),
	})
end
function UI.Candy(inst, c, rot)
	if inst:IsA("GuiObject") then
		inst.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	local g = Instance.new("UIGradient")
	g.Color = UI.CandySeq(c)
	g.Rotation = rot or 90
	g.Parent = inst
	return g
end

-- Мягкий глянец: белая полоса сверху, которая плавно растворяется книзу
function UI.Gloss(parent, size, pos, alpha, z)
	local f = UI.new("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Size = size,
		Position = pos,
		ZIndex = z or parent.ZIndex,
		Parent = parent,
	})
	UI.Corner(f, UDim.new(1, 0))
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, alpha or 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end

-- Текст с обводкой
function UI.Text(parent, text, props)
	local l = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = UI.Font,
		Text = text or "",
		TextColor3 = UI.Colors.White,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	if props then
		for k, v in pairs(props) do
			if k ~= "Stroke" and k ~= "MaxText" and k ~= "StrokeThickness" then
				l[k] = v
			end
		end
	end
	local sc = Instance.new("UITextSizeConstraint")
	sc.MaxTextSize = (props and props.MaxText) or 40
	sc.Parent = l
	if not props or props.Stroke ~= false then
		local s = UI.Stroke(l, (props and props.StrokeThickness) or 2.5, UI.Ink)
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end
	return l
end

-- Hover / click поведение для любого GuiButton
function UI.Bounce(button, scaleTarget, face)
	local scale = Instance.new("UIScale")
	scale.Parent = scaleTarget or button
	local hover = false
	local pressed = false
	local function go(s, t)
		TweenService:Create(scale, TweenInfo.new(t or 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = s }):Play()
	end
	button.MouseEnter:Connect(function()
		hover = true
		if not pressed then
			go(1.05)
		end
	end)
	button.MouseLeave:Connect(function()
		hover = false
		pressed = false
		go(1)
		if face then
			face.Position = UDim2.new(0, 0, 0, 0)
		end
	end)
	button.MouseButton1Down:Connect(function()
		pressed = true
		go(0.95, 0.06)
		if face then
			face.Position = UDim2.new(0, 0, 0, 3)
		end
	end)
	button.MouseButton1Up:Connect(function()
		pressed = false
		go(hover and 1.05 or 1)
		if face then
			face.Position = UDim2.new(0, 0, 0, 0)
		end
	end)
	button.Activated:Connect(function()
		if clickSound then
			clickSound()
		end
	end)
	return scale
end

-- Объёмная кнопка в стиле HUD: насыщенный градиент, обводка темнее своего цвета, блик и «ступенька» снизу
-- opts: Text, Color, Size, Position, AnchorPoint, Parent, TextSize, Glyph, GlyphColor, Icon, LayoutOrder, Radius
local function edge(c)
	return UI.Darker(c, 0.5)
end
UI.Edge = edge

function UI.Button(opts)
	local color = opts.Color or UI.Colors.Green
	local radius = opts.Radius or 14
	local holder = UI.new("Frame", {
		Name = opts.Name or "Button",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(160, 52),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.new(),
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = opts.Parent,
	})
	local shadow = UI.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = UI.Darker(color, 0.35),
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 4),
		Parent = holder,
	})
	UI.Corner(shadow, radius)
	local shadowStroke = UI.Stroke(shadow, 3, edge(color), true)
	local faceHolder = UI.new("Frame", {
		Name = "FaceHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	local face = UI.new("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Parent = faceHolder,
	})
	UI.Corner(face, radius)
	local faceStroke = UI.Stroke(face, 3, edge(color), true)
	local faceGrad = UI.Candy(face, color)
	-- мягкий глянец сверху
	UI.Gloss(face, UDim2.new(1, -12, 0.42, 0), UDim2.new(0, 6, 0, 3), 0.38)
	local label
	local iconFrame
	if opts.Glyph then
		local h = (opts.Size and opts.Size.Y.Offset) or 52
		local gs = math.floor(h * (opts.Text and 0.66 or 0.72))
		iconFrame = require(script.Parent.Icons2D).New(face, opts.Glyph, gs, { Color = opts.GlyphColor, Ink = edge(color) })
		if opts.Text then
			iconFrame.AnchorPoint = Vector2.new(0, 0.5)
			iconFrame.Position = UDim2.new(0, 8, 0.5, -2)
		else
			iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			iconFrame.Position = UDim2.new(0.5, 0, 0.5, -2)
		end
	elseif opts.Icon then
		iconFrame = opts.Icon(face)
		iconFrame.AnchorPoint = Vector2.new(0, 0.5)
		iconFrame.Position = UDim2.new(0, 8, 0.5, 0)
	end
	local labelStroke
	if opts.Text then
		local iw = iconFrame and (iconFrame.Size.X.Offset + 8) or 0
		label = UI.Text(face, opts.Text, {
			Size = UDim2.new(1, iconFrame and -(iw + 10) or -12, 1, -10),
			Position = UDim2.new(0, iconFrame and (iw + 4) or 6, 0, 5),
			MaxText = opts.TextSize or 26,
			TextXAlignment = opts.TextXAlignment or Enum.TextXAlignment.Center,
		})
		labelStroke = label:FindFirstChildOfClass("UIStroke")
		if labelStroke then
			labelStroke.Color = edge(color)
		end
	end
	UI.Bounce(face, holder, faceHolder)
	local obj = { Holder = holder, Face = face, Label = label, Shadow = shadow, Activated = face.Activated, Color = color, Glyph = iconFrame }
	local function paint(c)
		faceGrad.Color = UI.CandySeq(c)
		shadow.BackgroundColor3 = UI.Darker(c, 0.35)
		faceStroke.Color = edge(c)
		shadowStroke.Color = edge(c)
		if labelStroke then
			labelStroke.Color = edge(c)
		end
	end
	function obj.SetText(t)
		if label then
			label.Text = t
		end
	end
	function obj.SetColor(c)
		obj.Color = c
		paint(c)
	end
	function obj.SetEnabled(on)
		obj.Enabled = on
		face.Active = on
		face.AutoButtonColor = false
		-- серые кнопки действительно не нажимаются
		pcall(function()
			face.Interactable = on
		end)
		paint(on and obj.Color or UI.Colors.Gray)
	end
	return obj
end

-- Плашка с тенью (без нажатия): обводка — темнее своего цвета
function UI.Plate(parent, size, pos, color, radius)
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new(), Parent = parent })
	local shadow = UI.new("Frame", { BackgroundColor3 = UI.Darker(color, 0.4), BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 4), Parent = holder })
	UI.Corner(shadow, radius or 14)
	local face = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1), Parent = holder })
	UI.Corner(face, radius or 14)
	UI.Stroke(face, 3, edge(color), true)
	return holder, face
end

-- Полоса прогресса
function UI.Bar(parent, size, pos, color, bg)
	local frame = UI.new("Frame", {
		BackgroundColor3 = bg or UI.Colors.Dark,
		Size = size,
		Position = pos or UDim2.new(),
		Parent = parent,
		ClipsDescendants = false,
	})
	UI.Corner(frame, UDim.new(1, 0))
	UI.Stroke(frame, 3, UI.Darker(bg or UI.Colors.Dark, 0.4), true)
	local fill = UI.new("Frame", {
		BackgroundColor3 = color or UI.Colors.Green,
		Size = UDim2.fromScale(0, 1),
		Parent = frame,
	})
	UI.Corner(fill, UDim.new(1, 0))
	UI.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210))
	local shine = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		Size = UDim2.new(1, -8, 0.3, 0),
		Position = UDim2.new(0, 4, 0, 3),
		Parent = fill,
	})
	UI.Corner(shine, UDim.new(1, 0))
	local label = UI.Text(frame, "", { ZIndex = 3, Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), MaxText = 22 })
	local obj = { Frame = frame, Fill = fill, Label = label }
	local last = -1
	function obj.Set(frac, text, instant)
		frac = math.clamp(frac or 0, 0, 1)
		if text then
			label.Text = text
		end
		if frac ~= last then
			last = frac
			local target = UDim2.fromScale(frac < 0.001 and 0 or math.max(frac, 0.06), 1)
			if instant then
				fill.Size = target
			else
				TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = target }):Play()
			end
		end
	end
	return obj
end

-- Окно-панель в стиле HUD: белое тело с лёгким оттенком цвета окна, сочная шапка-градиент,
-- значок в белом кружке слева и круглый красный крестик, вынесенный за угол.
local WINDOW_ICONS = {
	Pets = "Paw", Bag = "Chest", Shop = "ShopBag", Incubator = "Sprout", Rebirth = "Hourglass", Worlds = "Globe",
	Npc = "Quest", Egg = "Egg", Daily = "Gift", Wheel = "Wheel", Stats = "Stats", Quests = "Quest", Donate = "Diamond",
}
UI.HeaderHeight = 62

-- Фон за открытым окном: мир мягко размывается и чуть темнеет, интерфейс остаётся чётким.
-- Окна считаются по множеству, поэтому два окна подряд не «мигают» размытием.
UI.BackdropEnabled = true
local openWindows = {}
local backdropBlur, backdropGrade
local function backdropTarget()
	for w in pairs(openWindows) do
		if w.Root and w.Root.Parent then
			return true
		end
		openWindows[w] = nil
	end
	return false
end
function UI.SetBackdrop(win, open)
	openWindows[win] = open or nil
	local on = UI.BackdropEnabled and backdropTarget()
	if not backdropBlur or not backdropBlur.Parent then
		backdropBlur = Instance.new("BlurEffect")
		backdropBlur.Name = "UIBackdropBlur"
		backdropBlur.Size = 0
		backdropBlur.Parent = Lighting
	end
	if not backdropGrade or not backdropGrade.Parent then
		backdropGrade = Instance.new("ColorCorrectionEffect")
		backdropGrade.Name = "UIBackdropGrade"
		backdropGrade.Parent = Lighting
	end
	local info = TweenInfo.new(on and 0.25 or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(backdropBlur, info, { Size = on and 14 or 0 }):Play()
	TweenService:Create(backdropGrade, info, { Brightness = on and -0.06 or 0, Saturation = on and -0.12 or 0 }):Play()
end
function UI.Window(screen, opts)
	local base = opts.Size or UDim2.fromOffset(720, 480)
	local HEAD = UI.HeaderHeight
	local size = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset + 28)
	local color = opts.Color or UI.Colors.Blue
	local dark = edge(color)
	local root = UI.new("Frame", {
		Name = opts.Name or "Window",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local shadow = UI.new("Frame", { Name = "Shadow", BackgroundColor3 = UI.Darker(color, 0.7), BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 10), Parent = root })
	UI.Corner(shadow, 28)
	local body = UI.new("Frame", { Name = "Body", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = root })
	UI.Corner(body, 28)
	UI.Stroke(body, 4.5, dark, true)
	UI.Gradient(body, Color3.fromRGB(255, 255, 255), UI.Lighter(color, 0.84))
	-- мягкие диагональные полосы оттенка окна
	local pattern = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -HEAD - 6), Position = UDim2.fromOffset(4, HEAD), ClipsDescendants = true, Parent = body })
	for k = 0, 16 do
		UI.new("Frame", { BackgroundColor3 = UI.Lighter(color, 0.6), BackgroundTransparency = 0.82, Size = UDim2.new(0, 26, 3, 0), Position = UDim2.new(0, k * 78 - 120, -1, 0), Rotation = 30, Parent = pattern })
	end
	-- шапка
	local header = UI.new("Frame", { Name = "Header", BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, HEAD), ZIndex = 2, Parent = body })
	UI.Corner(header, 26)
	local headTop, headBottom = UI.Lighter(color, 0.28), UI.Darker(color, 0.1)
	UI.Gradient(header, headTop, headBottom)
	header.BackgroundColor3 = Color3.new(1, 1, 1) -- цвет целиком в градиенте (даже у почти серых окон)
	-- квадратный низ шапки (под скруглением) в тех же цветах градиента
	local patch = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -26), ZIndex = 2, Parent = header })
	local pg = Instance.new("UIGradient")
	pg.Rotation = 90
	pg.Color = ColorSequence.new(headTop:Lerp(headBottom, (HEAD - 26) / HEAD), headBottom)
	pg.Parent = patch
	UI.new("Frame", { Name = "HeaderLine", BackgroundColor3 = dark, Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -2), ZIndex = 4, Parent = header })
	UI.Gloss(header, UDim2.new(1, -48, 0, 22), UDim2.fromOffset(24, 4), 0.4, 3)
	-- значок в белом кружке
	local badge = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(12, 5), ZIndex = 5, Parent = header })
	UI.Corner(badge, UDim.new(1, 0))
	UI.Stroke(badge, 3, dark, true)
	UI.Gradient(badge, Color3.new(1, 1, 1), UI.Lighter(color, 0.7))
	local iconName = opts.Icon or WINDOW_ICONS[opts.Name or ""] or "Star"
	local glyph = require(script.Parent.Icons2D).New(badge, iconName, 38, { ZIndex = 6, Color = color, Ink = dark })
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.47)
	local title = UI.Text(header, opts.Title or "", { Size = UDim2.new(1, -170, 0, 42), Position = UDim2.fromOffset(76, 9), MaxText = 36, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, StrokeThickness = 3.5 })
	local ts = title:FindFirstChildOfClass("UIStroke")
	if ts then
		ts.Color = dark
	end
	-- круглый крестик за углом
	local close = UI.Button({ Parent = root, Glyph = "Close", Color = UI.Colors.Red, Size = UDim2.fromOffset(54, 54), Position = UDim2.new(1, -40, 0, -14), Radius = 27 })
	close.Holder.ZIndex = 12
	local content = UI.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, -36, 1, -(HEAD + 30)), Position = UDim2.fromOffset(18, HEAD + 14), ZIndex = 2, Parent = body })
	local win = { Root = root, Content = content, Title = title, Close = close, IsOpen = false, Color = color }
	local openedEvent = Instance.new("BindableEvent")
	win.Opened = openedEvent.Event
	function win.Open()
		if win.IsOpen then
			return
		end
		win.IsOpen = true
		root.Visible = true
		scale.Scale = 0.78
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		UI.SetBackdrop(win, true)
		openedEvent:Fire()
	end
	function win.Hide()
		if not win.IsOpen then
			return
		end
		win.IsOpen = false
		UI.SetBackdrop(win, false)
		local tw = TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.7 })
		tw:Play()
		tw.Completed:Connect(function()
			if not win.IsOpen then
				root.Visible = false
			end
		end)
	end
	function win.Toggle()
		if win.IsOpen then
			win.Hide()
		else
			win.Open()
		end
	end
	close.Activated:Connect(win.Hide)
	return win
end

-- Вкладки: сегментированная «таблетка» — выбранная вкладка цветная, остальные светлые
function UI.Tabs(parent, names, colors, onSelect)
	local w = #names * 154 + 8
	local bar = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(232, 230, 244), Size = UDim2.fromOffset(w, 48), Parent = parent })
	UI.Corner(bar, UDim.new(1, 0))
	UI.Stroke(bar, 3, Color3.fromRGB(190, 186, 214), true)
	local inner = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 2), Parent = bar })
	UI.List(inner, 4, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	local buttons = {}
	local tabs = { Buttons = buttons, Current = nil }
	local idle = Color3.fromRGB(176, 172, 200)
	function tabs.Select(i)
		tabs.Current = i
		for k, b in ipairs(buttons) do
			b.SetColor(k == i and (colors[k] or UI.Colors.Blue) or idle)
		end
		onSelect(i)
	end
	for i, n in ipairs(names) do
		local b = UI.Button({ Parent = inner, Text = n, Color = idle, Size = UDim2.fromOffset(150, 36), LayoutOrder = i, TextSize = 21, Radius = 18 })
		b.Activated:Connect(function()
			tabs.Select(i)
		end)
		buttons[i] = b
	end
	return tabs, bar
end

-- Скролл-контейнер
function UI.Scroll(parent, size, pos)
	local s = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = size,
		Position = pos or UDim2.new(),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UI.Ink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	return s
end

-- Модель в ViewportFrame с автокадрированием
function UI.Viewport(parent, model, size, pos, spin)
	local vp = UI.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = size or UDim2.fromScale(1, 1),
		Position = pos or UDim2.new(),
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = parent,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	if model then
		model.Parent = vp
		local cf, sz = model:GetBoundingBox()
		local radius = math.max(sz.X, sz.Y, sz.Z) * 0.62
		local dist = radius / math.tan(math.rad(15)) * 1.05
		local dir = Vector3.new(0.35, 0.28, -1).Unit
		cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	end
	return vp, cam
end

function UI.Pop(inst, from)
	local scale = inst:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", inst)
	scale.Scale = from or 0.5
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function UI.IsTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return UI
