-- Icons2D: однотонные векторные иконки в стиле популярных симуляторов.
-- Белый силуэт + толстая тёмная обводка + "наклеечная" тень снизу.
-- Иконка собирается из фреймов (круги, капсулы, ромбы, кольца) в три слоя:
--   1) тень  2) обводка (те же фигуры с внешним UIStroke)  3) заливка  4) тёмные детали.
-- Перекрытие слоёв даёт единый контур вокруг всей фигуры, без линий внутри.
local TweenService = game:GetService("TweenService")

local Icons2D = {}

local INK = Color3.fromRGB(28, 22, 44)
local WHITE = Color3.fromRGB(255, 255, 255)

---------------------------------------------------------------------------------------------
-- Описание иконок в единичных координатах (0..1, y вниз).
--   C(x, y, d)                 круг диаметра d
--   R(x, y, w, h, rot, round)  прямоугольник, round — доля скругления от короткой стороны (0..0.5)
--   P(x1, y1, x2, y2, th)      капсула-линия толщиной th
--   D(x, y, s, rot)            ромб (повёрнутый квадрат со стороной s)
--   O(x, y, d, w)              кольцо: внешний диаметр d, толщина w
--   S(x, y, w, h, th)          кольцо-стадион (овал из капсулы)
-- Поле d — детали тёмным цветом поверх заливки.
---------------------------------------------------------------------------------------------
local function C(x, y, d) return { "C", x, y, d } end
local function R(x, y, w, h, rot, round) return { "R", x, y, w, h, rot or 0, round or 0.14 } end
local function P(x1, y1, x2, y2, th) return { "P", x1, y1, x2, y2, th or 0.1 } end
local function D(x, y, s, rot) return { "D", x, y, s, rot or 0 } end
local function O(x, y, d, w) return { "O", x, y, d, w } end
local function S(x, y, w, h, th) return { "S", x, y, w, h, th } end

local Defs = {}

Defs.Coin = { C(0.5, 0.5, 0.86), d = { O(0.5, 0.5, 0.62, 0.055), R(0.5, 0.5, 0.1, 0.3, 0, 0.5) } }

Defs.Shard = {
	D(0.5, 0.58, 0.56), R(0.5, 0.29, 0.6, 0.22, 0, 0.3),
	d = { P(0.25, 0.4, 0.75, 0.4, 0.05), P(0.4, 0.42, 0.5, 0.86, 0.05), P(0.6, 0.42, 0.5, 0.86, 0.05) },
}
Defs.Paw = {
	R(0.5, 0.66, 0.5, 0.42, 0, 0.48), C(0.2, 0.42, 0.2), C(0.38, 0.22, 0.21), C(0.62, 0.22, 0.21), C(0.8, 0.42, 0.2),
}
Defs.Chest = {
	R(0.5, 0.64, 0.86, 0.46, 0, 0.14), R(0.5, 0.36, 0.86, 0.3, 0, 0.42),
	d = { P(0.12, 0.5, 0.88, 0.5, 0.06), R(0.5, 0.52, 0.16, 0.2, 0, 0.3) },
}
Defs.ShopBag = {
	O(0.5, 0.3, 0.42, 0.09), R(0.5, 0.62, 0.74, 0.62, 0, 0.16),
	d = { D(0.5, 0.62, 0.17), P(0.3, 0.42, 0.7, 0.42, 0.05) },
}
Defs.Stats = {
	R(0.22, 0.68, 0.18, 0.36, 0, 0.32), R(0.5, 0.56, 0.18, 0.6, 0, 0.32), R(0.78, 0.44, 0.18, 0.84, 0, 0.32),
}
Defs.Gift = {
	C(0.37, 0.19, 0.24), C(0.63, 0.19, 0.24), R(0.5, 0.67, 0.72, 0.5, 0, 0.12), R(0.5, 0.38, 0.86, 0.2, 0, 0.25),
	d = { P(0.5, 0.3, 0.5, 0.88, 0.07), P(0.17, 0.48, 0.83, 0.48, 0.045) },
}
Defs.Wheel = {
	O(0.5, 0.54, 0.84, 0.11), P(0.5, 0.18, 0.5, 0.9, 0.08), P(0.14, 0.54, 0.86, 0.54, 0.08),
	P(0.25, 0.29, 0.75, 0.79, 0.08), P(0.75, 0.29, 0.25, 0.79, 0.08), C(0.5, 0.54, 0.22), D(0.5, 0.1, 0.17),
}
Defs.Sprout = {
	R(0.5, 0.8, 0.5, 0.28, 0, 0.22), P(0.5, 0.66, 0.5, 0.38, 0.08),
	R(0.34, 0.33, 0.4, 0.2, 22, 0.5), R(0.68, 0.27, 0.42, 0.21, -24, 0.5),
	d = { P(0.27, 0.72, 0.73, 0.72, 0.05) },
}

Defs.Hourglass = {
	R(0.5, 0.12, 0.72, 0.12, 0, 0.5), R(0.5, 0.88, 0.72, 0.12, 0, 0.5),
	P(0.31, 0.18, 0.69, 0.82, 0.17), P(0.69, 0.18, 0.31, 0.82, 0.17),
	d = { C(0.5, 0.71, 0.12) },
}
Defs.Globe = {
	C(0.5, 0.5, 0.86),
	d = { S(0.5, 0.5, 0.36, 0.8, 0.05), P(0.13, 0.5, 0.87, 0.5, 0.05), P(0.2, 0.3, 0.8, 0.3, 0.045), P(0.2, 0.7, 0.8, 0.7, 0.045) },
}
Defs.Quest = {
	R(0.5, 0.56, 0.7, 0.8, 0, 0.14), R(0.5, 0.16, 0.36, 0.15, 0, 0.45),
	d = {
		P(0.27, 0.42, 0.33, 0.48, 0.05), P(0.33, 0.48, 0.42, 0.36, 0.05), P(0.5, 0.42, 0.72, 0.42, 0.06),
		P(0.27, 0.62, 0.33, 0.68, 0.05), P(0.33, 0.68, 0.42, 0.56, 0.05), P(0.5, 0.62, 0.72, 0.62, 0.06),
		P(0.3, 0.8, 0.68, 0.8, 0.06),
	},
}
Defs.Pickaxe = {
	P(0.22, 0.86, 0.64, 0.34, 0.12), P(0.38, 0.14, 0.7, 0.28, 0.13), P(0.7, 0.28, 0.88, 0.58, 0.13),
}
Defs.Home = {
	D(0.5, 0.42, 0.5), R(0.5, 0.67, 0.6, 0.46, 0, 0.1),
	d = { R(0.5, 0.78, 0.16, 0.26, 0, 0.35) },
}
Defs.Clock = {
	C(0.5, 0.5, 0.86),
	d = { P(0.5, 0.5, 0.5, 0.24, 0.07), P(0.5, 0.5, 0.7, 0.6, 0.07), C(0.5, 0.5, 0.11) },
}
Defs.Star = {
	R(0.5, 0.5, 0.6, 0.6, 0, 0.03), R(0.5, 0.5, 0.6, 0.6, 45, 0.03),
	d = { D(0.5, 0.5, 0.2) },
}

Defs.Lock = {
	O(0.5, 0.36, 0.46, 0.1), R(0.5, 0.66, 0.68, 0.5, 0, 0.16),
	d = { C(0.5, 0.61, 0.13), R(0.5, 0.72, 0.07, 0.16, 0, 0.5) },
}
Defs.Bolt = { P(0.66, 0.08, 0.36, 0.52, 0.21), P(0.3, 0.5, 0.7, 0.5, 0.2), P(0.64, 0.48, 0.34, 0.92, 0.21) }

Defs.Clover = {
	C(0.33, 0.33, 0.36), C(0.67, 0.33, 0.36), C(0.33, 0.63, 0.36), C(0.67, 0.63, 0.36), P(0.55, 0.62, 0.74, 0.92, 0.09),
}
Defs.Drop = { D(0.5, 0.38, 0.36), C(0.5, 0.62, 0.6), d = { P(0.36, 0.6, 0.4, 0.72, 0.05) } }
Defs.Flask = {
	C(0.5, 0.65, 0.62), R(0.5, 0.28, 0.24, 0.32, 0, 0.15), R(0.5, 0.12, 0.34, 0.11, 0, 0.4),
	d = { P(0.27, 0.62, 0.73, 0.62, 0.05) },
}
Defs.Backpack = {
	O(0.5, 0.22, 0.32, 0.08), R(0.5, 0.6, 0.7, 0.68, 0, 0.22),
	d = { P(0.2, 0.44, 0.8, 0.44, 0.05), S(0.5, 0.71, 0.42, 0.22, 0.05) },
}
Defs.Egg = {
	R(0.5, 0.54, 0.64, 0.84, 0, 0.5),
	d = { P(0.2, 0.56, 0.35, 0.47, 0.05), P(0.35, 0.47, 0.5, 0.56, 0.05), P(0.5, 0.56, 0.65, 0.47, 0.05), P(0.65, 0.47, 0.8, 0.56, 0.05) },
}
Defs.Close = { P(0.24, 0.24, 0.76, 0.76, 0.19), P(0.76, 0.24, 0.24, 0.76, 0.19) }
Defs.Check = { P(0.18, 0.54, 0.42, 0.78, 0.17), P(0.42, 0.78, 0.84, 0.26, 0.17) }
Defs.Plus = { P(0.5, 0.18, 0.5, 0.82, 0.18), P(0.18, 0.5, 0.82, 0.5, 0.18) }
Defs.Sword = { P(0.3, 0.7, 0.8, 0.2, 0.13), P(0.18, 0.56, 0.44, 0.82, 0.1), P(0.16, 0.84, 0.28, 0.72, 0.1) }
Defs.Crown = {
	D(0.2, 0.5, 0.28), D(0.5, 0.42, 0.3), D(0.8, 0.5, 0.28), R(0.5, 0.68, 0.78, 0.36, 0, 0.18),
	C(0.2, 0.27, 0.13), C(0.5, 0.17, 0.14), C(0.8, 0.27, 0.13),
	d = { P(0.18, 0.74, 0.82, 0.74, 0.05), D(0.5, 0.62, 0.12) },
}

Defs.Rocket = {
	R(0.5, 0.46, 0.34, 0.66, 0, 0.5), D(0.32, 0.72, 0.2), D(0.68, 0.72, 0.2), R(0.5, 0.84, 0.16, 0.14, 0, 0.4),
	d = { C(0.5, 0.42, 0.14) },
}

-- шестерёнка (настройки)
Defs.Gear = {
	C(0.5, 0.5, 0.64), R(0.830, 0.500, 0.2, 0.22, 90, 0.25), R(0.733, 0.733, 0.2, 0.22, 135, 0.25), R(0.500, 0.830, 0.2, 0.22, 180, 0.25), R(0.267, 0.733, 0.2, 0.22, 225, 0.25), R(0.170, 0.500, 0.2, 0.22, 270, 0.25), R(0.267, 0.267, 0.2, 0.22, 315, 0.25), R(0.500, 0.170, 0.2, 0.22, 360, 0.25), R(0.733, 0.267, 0.2, 0.22, 405, 0.25),
	d = { C(0.5, 0.5, 0.24) },
}

-- нота (музыка)
Defs.Note = {
	C(0.34, 0.74, 0.28), C(0.72, 0.66, 0.28), R(0.45, 0.46, 0.1, 0.56, 0, 0.3), R(0.83, 0.38, 0.1, 0.56, 0, 0.3), R(0.64, 0.2, 0.48, 0.14, -12, 0.3),
}

-- стрелка вниз (поворачивается целиком)
Defs.Arrow = { P(0.5, 0.14, 0.5, 0.74, 0.2), P(0.2, 0.5, 0.5, 0.8, 0.2), P(0.8, 0.5, 0.5, 0.8, 0.2) }

-- бриллиант (донат)
Defs.Diamond = {
	R(0.5, 0.32, 0.74, 0.2, 0, 0.3), D(0.5, 0.5, 0.5),
	d = { P(0.22, 0.4, 0.78, 0.4, 0.045), P(0.4, 0.42, 0.5, 0.74, 0.04), P(0.6, 0.42, 0.5, 0.74, 0.04) },
}
-- кость (Окаменелости)
Defs.Bone = {
	P(0.3, 0.7, 0.7, 0.3, 0.2), C(0.2, 0.68, 0.2), C(0.32, 0.8, 0.2), C(0.68, 0.2, 0.2), C(0.8, 0.32, 0.2),
}
-- снежинка (Ледник)
Defs.Snowflake = {
	P(0.5, 0.1, 0.5, 0.9, 0.12), P(0.15, 0.3, 0.85, 0.7, 0.12), P(0.15, 0.7, 0.85, 0.3, 0.12),
	D(0.5, 0.5, 0.2),
	d = { C(0.5, 0.5, 0.08) },
}
-- пламя (Магма): круглое основание и два сходящихся языка
Defs.Flame = {
	C(0.5, 0.66, 0.54), P(0.3, 0.6, 0.5, 0.12, 0.2), P(0.7, 0.6, 0.5, 0.12, 0.2),
	P(0.22, 0.62, 0.17, 0.36, 0.11), P(0.78, 0.62, 0.83, 0.36, 0.11),
	d = { C(0.5, 0.72, 0.2) },
}
-- планета с кольцом (Бездна)
Defs.Saturn = {
	C(0.5, 0.5, 0.58), P(0.08, 0.66, 0.92, 0.34, 0.1),
	d = { C(0.38, 0.4, 0.12), C(0.62, 0.62, 0.08) },
}
-- молния-щит (админ)
Defs.Shield = {
	R(0.5, 0.42, 0.66, 0.5, 0, 0.3), D(0.5, 0.62, 0.48),
	d = { P(0.5, 0.26, 0.5, 0.74, 0.06), P(0.3, 0.44, 0.7, 0.44, 0.06) },
}
-- человечек (игроки)
Defs.Person = {
	C(0.5, 0.3, 0.34), R(0.5, 0.76, 0.66, 0.4, 0, 0.5),
}
-- флаг (события)
Defs.Flag = {
	R(0.26, 0.54, 0.1, 0.8, 0, 0.4), R(0.56, 0.34, 0.54, 0.38, 0, 0.18),
	d = { R(0.46, 0.26, 0.12, 0.12, 0, 0.2), R(0.7, 0.42, 0.12, 0.12, 0, 0.2) },
}

Icons2D.Defs = Defs

-- Старые имена (3D-иконок) -> новые
local ALIAS = {
	Drill = "Pickaxe", Planet = "Globe", Scroll = "Quest", Capsule = "Sprout", Seed = "Sprout",
	Gem = "Shard", CoinElixir = "Flask", DrillOvercharge = "Bolt", LuckyCharm = "Clover", BioFertilizer = "Drop",
	Pets = "Paw", Bag = "Chest", Shop = "ShopBag", Daily = "Gift", Rebirth = "Hourglass", Worlds = "Globe",
	Incubator = "Sprout", Quests = "Quest",
}
Icons2D.Alias = ALIAS

---------------------------------------------------------------------------------------------
-- Построение
---------------------------------------------------------------------------------------------
local function corner(f, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

local function stroke(f, th, color)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Thickness = th
	s.Color = color
	s.Parent = f
end

local function frame(layer, cx, cy, w, h, rot)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(math.max(1, w), math.max(1, h))
	f.Rotation = rot or 0
	f.Parent = layer
	return f
end

-- mode: "fill" | "outline" | "detail"
local function draw(layer, sh, Spx, mode, color, t, dy)
	dy = dy or 0
	local k = sh[1]
	local grow = (mode == "outline") and t or 0
	if k == "C" then
		local d = sh[4] * Spx
		local f = frame(layer, sh[2] * Spx, sh[3] * Spx + dy, d, d)
		f.BackgroundColor3 = color
		corner(f, d)
		if grow > 0 then
			stroke(f, grow, color)
		end
	elseif k == "R" then
		local w, h = sh[4] * Spx, sh[5] * Spx
		local f = frame(layer, sh[2] * Spx, sh[3] * Spx + dy, w, h, sh[6])
		f.BackgroundColor3 = color
		corner(f, math.min(w, h) * sh[7])
		if grow > 0 then
			stroke(f, grow, color)
		end
	elseif k == "P" then
		local x1, y1, x2, y2, th = sh[2] * Spx, sh[3] * Spx, sh[4] * Spx, sh[5] * Spx, sh[6] * Spx
		local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) + th
		local f = frame(layer, (x1 + x2) / 2, (y1 + y2) / 2 + dy, len, th, math.deg(math.atan2(y2 - y1, x2 - x1)))
		f.BackgroundColor3 = color
		corner(f, th)
		if grow > 0 then
			stroke(f, grow, color)
		end
	elseif k == "D" then
		local s = sh[4] * Spx
		local f = frame(layer, sh[2] * Spx, sh[3] * Spx + dy, s, s, 45 + sh[5])
		f.BackgroundColor3 = color
		corner(f, s * 0.14)
		if grow > 0 then
			stroke(f, grow, color)
		end
	elseif k == "O" or k == "S" then
		local w, h, th
		if k == "O" then
			w, h, th = sh[4] * Spx, sh[4] * Spx, sh[5] * Spx
		else
			w, h, th = sh[4] * Spx, sh[5] * Spx, sh[6] * Spx
		end
		local iw, ih = w - 2 * th - 2 * grow, h - 2 * th - 2 * grow
		local f = frame(layer, sh[2] * Spx, sh[3] * Spx + dy, iw, ih)
		f.BackgroundTransparency = 1
		corner(f, math.min(iw, ih))
		stroke(f, th + 2 * grow, color)
	end
end

-- Icons2D.New(parent, name, size, opts) -> Frame
-- opts: Color (цвет заливки, по умолчанию белый), Ink (обводка), Shadow (true), ZIndex
function Icons2D.New(parent, name, size, opts)
	opts = opts or {}
	name = ALIAS[name] or name
	local def = Defs[name] or Defs.Star
	local Spx = size or 48
	local fill = opts.Color or WHITE
	local ink = opts.Ink or INK
	local t = math.max(1.5, Spx * 0.06)
	local holder = Instance.new("Frame")
	holder.Name = "Icon_" .. name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromOffset(Spx, Spx)
	holder.ZIndex = opts.ZIndex or 3
	local function layer(n, z)
		local l = Instance.new("Frame")
		l.Name = n
		l.BackgroundTransparency = 1
		l.BorderSizePixel = 0
		l.Size = UDim2.fromScale(1, 1)
		l.ZIndex = z
		l.Parent = holder
		return l
	end
	if opts.Shadow ~= false then
		local sl = layer("Shadow", 1)
		for _, sh in ipairs(def) do
			draw(sl, sh, Spx, "outline", ink, t, Spx * 0.055)
		end
	end
	local ol = layer("Outline", 2)
	for _, sh in ipairs(def) do
		draw(ol, sh, Spx, "outline", ink, t)
	end
	local fl = layer("Fill", 3)
	for _, sh in ipairs(def) do
		draw(fl, sh, Spx, "fill", fill, t)
	end
	if def.d then
		local dl = layer("Detail", 4)
		for _, sh in ipairs(def.d) do
			draw(dl, sh, Spx, "detail", opts.DetailColor or ink, t)
		end
	end
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	holder.Parent = parent
	return holder
end

-- Перекрасить заливку иконки (например, серый для закрытого)
function Icons2D.SetColor(holder, color)
	local fl = holder:FindFirstChild("Fill")
	if not fl then
		return
	end
	for _, f in ipairs(fl:GetChildren()) do
		if f:IsA("Frame") then
			if f.BackgroundTransparency < 1 then
				f.BackgroundColor3 = color
			end
			local s = f:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = color
			end
		end
	end
end

function Icons2D.Bounce(holder, amount)
	local s = holder:FindFirstChildOfClass("UIScale")
	if not s then
		return
	end
	s.Scale = amount or 1.25
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Icons2D.Wiggle(holder)
	holder.Rotation = 0
	local tw = TweenService:Create(holder, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Rotation = 10 })
	tw:Play()
	tw.Completed:Connect(function()
		holder.Rotation = 0
	end)
end

return Icons2D
