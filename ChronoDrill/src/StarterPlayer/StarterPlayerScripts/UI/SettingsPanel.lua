-- SettingsPanel: окно «Настройки» (графика, музыка, звуки) и выбор графики при первом входе.
local UI = require(script.Parent.UIKit)
local Icons2D = require(script.Parent.Icons2D)

local SettingsPanel = {}

local QUALITY = {
	{ Id = "Low", Name = "НИЗКАЯ", Color = UI.Colors.Green, Glyph = "Bolt", Desc = "Без теней и эффектов, меньше декора. Для слабых телефонов." },
	{ Id = "Medium", Name = "СРЕДНЯЯ", Color = UI.Colors.Blue, Glyph = "Star", Desc = "Тени, свечение и облака. Хороший баланс." },
	{ Id = "High", Name = "ВЫСОКАЯ", Color = UI.Colors.Purple, Glyph = "Crown", Desc = "Всё на максимум: густая трава, цветы, светлячки, лучи солнца, частицы." },
}
SettingsPanel.Quality = QUALITY

local VOLUMES = { 0, 0.25, 0.5, 0.75, 1 }

local function qualityCard(parent, q, size, pos, onPick)
	local b = UI.Button({ Parent = parent, Color = q.Color, Size = size, Position = pos, Radius = 20 })
	local ic = Icons2D.New(b.Face, q.Glyph, math.floor(size.Y.Offset * 0.36), { ZIndex = 4 })
	ic.AnchorPoint = Vector2.new(0.5, 0)
	ic.Position = UDim2.new(0.5, 0, 0, 12)
	UI.Text(b.Face, q.Name, { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, math.floor(size.Y.Offset * 0.36) + 16), MaxText = 28, ZIndex = 5, StrokeThickness = 3 })
	UI.Text(b.Face, q.Desc, { Size = UDim2.new(1, -20, 0, 60), Position = UDim2.new(0, 10, 1, -70), MaxText = 15, ZIndex = 5, TextWrapped = true, StrokeThickness = 1.5 })
	local mark = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0, 8), Visible = false, ZIndex = 6, Parent = b.Face })
	UI.Corner(mark, UDim.new(1, 0))
	UI.Stroke(mark, 2.5, UI.Ink, true)
	local ck = Icons2D.New(mark, "Check", 22, { Color = UI.Colors.Green, Shadow = false, ZIndex = 7 })
	ck.AnchorPoint = Vector2.new(0.5, 0.5)
	ck.Position = UDim2.fromScale(0.5, 0.5)
	b.Activated:Connect(function()
		onPick(q.Id)
	end)
	return b, mark
end

function SettingsPanel.Build(screen, ctx)
	local S = ctx.Settings
	local win = UI.Window(screen, { Name = "Settings", Title = "НАСТРОЙКИ", Color = Color3.fromRGB(110, 118, 150), Icon = "Gear", Size = UDim2.fromOffset(760, 480) })
	local c = win.Content
	UI.Text(c, "ГРАФИКА", { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 22 })
	local marks = {}
	for i, q in ipairs(QUALITY) do
		local _, mark = qualityCard(c, q, UDim2.fromOffset(226, 210), UDim2.fromOffset((i - 1) * 241, 32), function(id)
			S.Set("Quality", id)
			ctx.Sound.Play("Unlock")
		end)
		marks[q.Id] = mark
	end
	-- громкость
	local function volumeRow(y, label, glyph, key)
		local holder, face = UI.Plate(c, UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, y), UI.Colors.Panel, 16)
		local ic = Icons2D.New(face, glyph, 44, { ZIndex = 3, Color = UI.Colors.Purple })
		ic.Position = UDim2.fromOffset(12, 13)
		UI.Text(face, label, { Size = UDim2.fromOffset(170, 30), Position = UDim2.fromOffset(66, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 22 })
		local btns = {}
		for k, v in ipairs(VOLUMES) do
			local b = UI.Button({ Parent = face, Text = v == 0 and "ВЫКЛ" or (math.floor(v * 100) .. "%"), Color = UI.Colors.Gray, Size = UDim2.fromOffset(82, 44), Position = UDim2.new(0, 240 + (k - 1) * 88, 0, 13), TextSize = 17, Radius = 12 })
			b.Activated:Connect(function()
				S.Set(key, v)
			end)
			btns[k] = b
		end
		return function(cur)
			for k, v in ipairs(VOLUMES) do
				btns[k].SetColor(math.abs((cur or 0) - v) < 0.01 and UI.Colors.Green or UI.Colors.Gray)
			end
		end
	end
	local setMusic = volumeRow(258, "Музыка", "Note", "Music")
	local setSfx = volumeRow(338, "Звуки", "Bolt", "Sfx")
	local function render()
		local cur = S.Get()
		for id, m in pairs(marks) do
			m.Visible = cur.Quality == id
		end
		setMusic(cur.Music)
		setSfx(cur.Sfx)
	end
	S.Changed:Connect(render)
	win.Opened:Connect(render)
	render()
	return win
end

-- Полноэкранный выбор графики при первом входе. onDone вызывается после выбора.
function SettingsPanel.Chooser(screen, ctx, onDone)
	local S = ctx.Settings
	local overlay = UI.new("Frame", { Name = "GraphicsChooser", BackgroundColor3 = Color3.fromRGB(16, 12, 34), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = screen })
	local box = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 400), ZIndex = 51, Parent = overlay })
	local sc = Instance.new("UIScale")
	sc.Parent = box
	UI.Text(box, "ВЫБЕРИ КАЧЕСТВО ГРАФИКИ", { Size = UDim2.new(1, 0, 0, 50), MaxText = 40, ZIndex = 52, StrokeThickness = 3.5 })
	UI.Text(box, "Поменять можно в любой момент: меню → Настройки", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 50), MaxText = 20, ZIndex = 52, TextColor3 = Color3.fromRGB(200, 200, 230) })
	local done = false
	for i, q in ipairs(QUALITY) do
		local b = qualityCard(box, q, UDim2.fromOffset(236, 260), UDim2.fromOffset((i - 1) * 262, 96), function(id)
			if done then
				return
			end
			done = true
			S.Set("Quality", id)
			ctx.Sound.Play("Unlock")
			overlay:Destroy()
			if onDone then
				onDone(id)
			end
		end)
		b.Holder.ZIndex = 52
		if q.Id == "High" then
			local tag = UI.new("Frame", { BackgroundColor3 = UI.Colors.Yellow, Size = UDim2.fromOffset(150, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 60, Parent = b.Holder })
			UI.Corner(tag, UDim.new(1, 0))
			UI.Stroke(tag, 2.5, UI.Ink, true)
			UI.Text(tag, "СОВЕТУЕМ", { Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), MaxText = 18, ZIndex = 61 })
		end
	end
	sc.Scale = 0.7
	game:GetService("TweenService"):Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return overlay
end

return SettingsPanel
