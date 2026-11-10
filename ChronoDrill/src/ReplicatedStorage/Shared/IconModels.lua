-- IconModels: маленькие 3D-модели для иконок интерфейса (рендерятся во ViewportFrame).
-- Каждая иконка смотрит в камеру по -Z, центр модели примерно в (0, 0, 0).
local MK = require(script.Parent.ModelKit)

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local Icons = {}
local GOLD = { 255, 200, 50 }
local GOLD_D = { 220, 150, 20 }
local GOLD_L = { 255, 236, 140 }
local WHITE = { 255, 255, 255 }
local INK = { 40, 32, 56 }

local function model(name)
	local m = Instance.new("Model")
	m.Name = name
	local root = MK.Part(m, V3(0.2, 0.2, 0.2), CF(0, 0, 0), WHITE, { Name = "Root", Transparency = 1 })
	m.PrimaryPart = root
	return m
end

local B = {}

function B.Coin(m)
	local tilt = ANG(rad(90), 0, 0) * ANG(0, 0, rad(-18))
	MK.Cylinder(m, 0.55, 3.2, CF(0, 0, 0.1) * ANG(0, rad(90), 0) * ANG(rad(18), 0, 0), GOLD_D, { Material = "Metal" })
	MK.Cylinder(m, 0.58, 3.0, CF(0, 0, 0) * ANG(0, rad(90), 0) * ANG(rad(18), 0, 0), GOLD, { Material = "Metal" })
	MK.Cylinder(m, 0.62, 2.2, CF(0, 0, -0.02) * ANG(0, rad(90), 0) * ANG(rad(18), 0, 0), GOLD_L, { Material = "Metal" })
	-- звезда-тиснение
	local face = CF(0, 0, -0.34)
	for i = 0, 1 do
		MK.Part(m, V3(0.32, 1.3, 0.12), face * ANG(0, 0, rad(i * 90)), GOLD_D, { Material = "Metal" })
	end
	for i = 0, 1 do
		MK.Part(m, V3(0.28, 1.0, 0.12), face * ANG(0, 0, rad(45 + i * 90)), GOLD_D, { Material = "Metal" })
	end
	MK.Ellipsoid(m, V3(0.5, 0.35, 0.1), CF(-0.7, 0.85, -0.36), WHITE, { Transparency = 0.25 })
end

function B.Shard(m)
	-- огранённый кристалл: шестигранная призма + пирамидки сверху и снизу
	local col = { 176, 110, 255 }
	local dark = { 128, 70, 220 }
	for i = 0, 2 do
		local r = ANG(0, rad(i * 60), 0)
		MK.Part(m, V3(1.5, 1.4, 0.86), CF(0, 0, 0) * r, (i == 1) and dark or col)
		local top = CF(0, 1.25, 0) * r
		MK.Wedge(m, V3(1.5, 1.1, 0.43), top * CF(0, 0, -0.215), col)
		MK.Wedge(m, V3(1.5, 1.1, 0.43), top * CF(0, 0, 0.215) * ANG(0, rad(180), 0), dark)
		local bot = CF(0, -1.1, 0) * r * ANG(rad(180), 0, 0)
		MK.Wedge(m, V3(1.5, 0.8, 0.43), bot * CF(0, 0, -0.215), dark)
		MK.Wedge(m, V3(1.5, 0.8, 0.43), bot * CF(0, 0, 0.215) * ANG(0, rad(180), 0), col)
	end
	MK.Part(m, V3(0.2, 1.1, 0.1), CF(-0.3, 0.1, -0.76), { 235, 215, 255 }, { Material = "Neon" })
	MK.Ellipsoid(m, V3(0.35, 0.35, 0.35), CF(0.75, 1.5, -0.4), { 245, 235, 255 }, { Material = "Neon" })
end

function B.Backpack(m)
	local body = { 230, 140, 60 }
	MK.Part(m, V3(2.2, 2.4, 1.2), CF(0, -0.1, 0), body)
	MK.Part(m, V3(2.3, 0.9, 1.3), CF(0, 0.75, -0.02), { 196, 108, 44 })
	MK.Part(m, V3(1.5, 0.9, 0.35), CF(0, -0.55, -0.7), { 255, 200, 60 })
	MK.Part(m, V3(0.4, 0.3, 0.12), CF(0, 0.45, -0.68), { 220, 220, 230 }, { Material = "Metal" })
	MK.Cylinder(m, 0.9, 0.22, CF(0, 1.35, 0.1) * ANG(0, 0, 0), { 150, 86, 40 })
	for _, x in ipairs({ -1.25, 1.25 }) do
		MK.Cylinder(m, 1.3, 0.6, CF(x, -0.3, 0) * ANG(0, 0, rad(90)), { 255, 200, 60 })
	end
end

function B.Chest(m)
	local wood = { 176, 110, 60 }
	MK.Part(m, V3(2.8, 1.6, 1.8), CF(0, -0.5, 0), wood)
	MK.Cylinder(m, 2.8, 1.8, CF(0, 0.3, 0), { 196, 128, 70 })
	for _, x in ipairs({ -1.0, 1.0 }) do
		MK.Part(m, V3(0.3, 1.65, 1.85), CF(x, -0.5, 0), GOLD, { Material = "Metal" })
		MK.Cylinder(m, 0.32, 1.88, CF(x, 0.3, 0), GOLD, { Material = "Metal" })
	end
	MK.Part(m, V3(0.55, 0.65, 0.2), CF(0, -0.1, -0.95), GOLD, { Material = "Metal" })
	MK.Part(m, V3(0.15, 0.25, 0.1), CF(0, -0.15, -1.06), INK)
	MK.Part(m, V3(0.8, 0.8, 0.8), CF(0.4, 1.05, -0.2) * ANG(rad(45), rad(45), 0), { 120, 230, 255 }, { Material = "Neon" })
end

function B.Paw(m)
	local c = { 255, 150, 90 }
	local pad = { 255, 205, 170 }
	MK.Ellipsoid(m, V3(2.0, 1.7, 0.8), CF(0, -0.45, 0), c)
	MK.Ellipsoid(m, V3(1.3, 1.0, 0.4), CF(0, -0.5, -0.32), pad)
	for i, p in ipairs({ { -1.05, 0.55 }, { -0.38, 1.05 }, { 0.38, 1.05 }, { 1.05, 0.55 } }) do
		MK.Ellipsoid(m, V3(0.75, 0.85, 0.6), CF(p[1], p[2], 0), c)
		MK.Ellipsoid(m, V3(0.45, 0.5, 0.3), CF(p[1], p[2], -0.22), pad)
	end
end

function B.ShopBag(m)
	local red = { 255, 86, 86 }
	MK.Part(m, V3(2.4, 2.4, 1.2), CF(0, -0.3, 0), red)
	MK.Part(m, V3(2.45, 0.35, 1.25), CF(0, 0.75, 0), { 220, 60, 60 })
	for _, x in ipairs({ -0.6, 0.6 }) do
		MK.CylinderBetween(m, V3(x, 0.9, -0.3), V3(x * 0.6, 1.7, -0.3), 0.18, { 120, 40, 40 })
	end
	MK.CylinderBetween(m, V3(-0.36, 1.7, -0.3), V3(0.36, 1.7, -0.3), 0.18, { 120, 40, 40 })
	-- значок монеты на пакете
	MK.Cylinder(m, 0.2, 1.1, CF(0, -0.35, -0.62) * ANG(0, rad(90), 0), GOLD, { Material = "Metal" })
	MK.Cylinder(m, 0.22, 0.7, CF(0, -0.35, -0.64) * ANG(0, rad(90), 0), GOLD_L, { Material = "Metal" })
end

function B.Stats(m)
	MK.Part(m, V3(3.2, 0.35, 1.2), CF(0, -1.4, 0), { 70, 66, 90 })
	local bars = { { -1.0, 1.2, { 88, 214, 96 } }, { 0, 2.0, { 255, 198, 48 } }, { 1.0, 2.8, { 70, 160, 255 } } }
	for _, b in ipairs(bars) do
		MK.Part(m, V3(0.75, b[2], 0.9), CF(b[1], -1.2 + b[2] / 2, 0), b[3])
		MK.Part(m, V3(0.8, 0.15, 0.95), CF(b[1], -1.2 + b[2], 0), WHITE, { Transparency = 0.4 })
	end
	MK.CylinderBetween(m, V3(-1.3, 0.2, -0.6), V3(1.1, 1.8, -0.6), 0.22, { 255, 86, 86 })
	MK.Wedge(m, V3(0.2, 0.55, 0.55), CF(1.25, 1.95, -0.6) * ANG(rad(-56), rad(90), 0), { 255, 86, 86 })
end

function B.Gift(m)
	local box = { 255, 90, 120 }
	MK.Part(m, V3(2.4, 2.0, 2.4), CF(0, -0.5, 0), box)
	MK.Part(m, V3(2.6, 0.6, 2.6), CF(0, 0.65, 0), { 255, 120, 150 })
	MK.Part(m, V3(0.5, 2.7, 2.65), CF(0, -0.2, 0), GOLD)
	MK.Part(m, V3(2.65, 2.7, 0.5), CF(0, -0.2, 0), GOLD)
	for _, s in ipairs({ -1, 1 }) do
		MK.Ellipsoid(m, V3(1.0, 0.7, 0.45), CF(s * 0.5, 1.25, 0) * ANG(0, 0, rad(s * -30)), GOLD)
	end
	MK.Ellipsoid(m, V3(0.45, 0.45, 0.45), CF(0, 1.15, 0), GOLD_D)
end

function B.Wheel(m)
	local seg = { { 255, 198, 48 }, { 255, 86, 86 }, { 88, 214, 96 }, { 70, 160, 255 }, { 164, 96, 255 }, { 255, 146, 46 }, { 50, 210, 196 }, { 255, 110, 170 } }
	MK.Cylinder(m, 0.45, 3.3, CF(0, 0, 0.12) * ANG(0, rad(90), 0), GOLD, { Material = "Metal" })
	for i, c in ipairs(seg) do
		local a = (i - 1) * 45
		MK.Part(m, V3(1.0, 1.45, 0.3), CF(0, 0, -0.05) * ANG(0, 0, rad(a)) * CF(0, 0.75, 0), c)
	end
	MK.Cylinder(m, 0.5, 0.7, CF(0, 0, -0.1) * ANG(0, rad(90), 0), WHITE)
	MK.Wedge(m, V3(0.25, 0.7, 0.6), CF(0, 1.85, -0.25) * ANG(rad(180), 0, 0) * ANG(0, rad(90), 0), { 255, 86, 86 })
	for i = 0, 7 do
		MK.Ellipsoid(m, V3(0.22, 0.22, 0.22), CF(0, 0, -0.15) * ANG(0, 0, rad(i * 45 + 22.5)) * CF(0, 1.55, 0), { 255, 250, 210 }, { Material = "Neon" })
	end
end

function B.Capsule(m)
	MK.Disc(m, 0.5, 2.2, V3(0, -1.35, 0), { 200, 206, 220 })
	MK.Disc(m, 2.2, 1.8, V3(0, -0.1, 0), { 210, 245, 255 }, { Material = "Glass", Transparency = 0.6 })
	MK.Disc(m, 0.3, 1.86, V3(0, -0.85, 0), { 110, 255, 140 }, { Material = "Neon" })
	MK.Disc(m, 1.5, 1.5, V3(0, -0.4, 0), { 110, 255, 140 }, { Material = "Neon", Transparency = 0.2 })
	MK.Ellipsoid(m, V3(0.7, 0.9, 0.7), CF(0, -0.2, -0.2), { 120, 210, 80 })
	MK.Ellipsoid(m, V3(0.5, 0.15, 0.3), CF(0.25, 0.35, -0.2) * ANG(0, 0, rad(25)), { 80, 180, 60 })
	MK.Ellipsoid(m, V3(2.2, 0.9, 2.2), CF(0, 1.1, 0), { 200, 206, 220 })
end

function B.Hourglass(m)
	MK.Disc(m, 0.35, 2.4, V3(0, 1.5, 0), GOLD, { Material = "Metal" })
	MK.Disc(m, 0.35, 2.4, V3(0, -1.5, 0), GOLD, { Material = "Metal" })
	for _, x in ipairs({ -1.0, 1.0 }) do
		MK.Disc(m, 3.0, 0.22, V3(x, 0, -0.3), GOLD_D, { Material = "Metal" })
	end
	MK.Ellipsoid(m, V3(1.6, 1.5, 1.6), CF(0, 0.65, 0), { 200, 240, 255 }, { Material = "Glass", Transparency = 0.45 })
	MK.Ellipsoid(m, V3(1.6, 1.5, 1.6), CF(0, -0.65, 0), { 200, 240, 255 }, { Material = "Glass", Transparency = 0.45 })
	MK.Ellipsoid(m, V3(1.1, 0.7, 1.1), CF(0, -0.95, 0), { 255, 110, 200 }, { Material = "Neon" })
	MK.Ellipsoid(m, V3(0.7, 0.4, 0.7), CF(0, 0.45, 0), { 255, 110, 200 }, { Material = "Neon" })
	MK.Disc(m, 0.9, 0.12, V3(0, -0.1, 0), { 255, 140, 220 }, { Material = "Neon" })
end

function B.Planet(m)
	MK.Ellipsoid(m, V3(2.6, 2.6, 2.6), CF(0, 0, 0), { 80, 170, 255 })
	MK.Ellipsoid(m, V3(1.2, 0.9, 0.6), CF(-0.5, 0.45, -1.0) * ANG(0, rad(20), 0), { 110, 220, 110 })
	MK.Ellipsoid(m, V3(0.9, 0.7, 0.5), CF(0.6, -0.5, -1.05) * ANG(0, rad(-25), 0), { 110, 220, 110 })
	local ringCf = CF(0, 0, 0) * ANG(rad(-72), 0, rad(18))
	for i = 0, 19 do
		local a = i * math.pi * 2 / 20
		MK.Ellipsoid(m, V3(0.42, 0.14, 0.42), ringCf * CF(math.cos(a) * 2.0, 0, math.sin(a) * 2.0), { 255, 210, 120 })
	end
	MK.Ellipsoid(m, V3(0.6, 0.4, 0.2), CF(-0.6, 0.85, -1.05), WHITE, { Transparency = 0.35 })
end

function B.Scroll(m)
	MK.Part(m, V3(2.2, 2.6, 0.15), CF(0, 0, 0), { 255, 240, 200 })
	MK.Cylinder(m, 2.6, 0.5, CF(0, 1.35, 0), { 230, 200, 150 })
	MK.Cylinder(m, 2.6, 0.5, CF(0, -1.35, 0), { 230, 200, 150 })
	for i = 0, 2 do
		MK.Part(m, V3(1.4, 0.14, 0.05), CF(0, 0.6 - i * 0.5, -0.1), { 150, 110, 80 })
	end
	MK.Ellipsoid(m, V3(0.6, 0.6, 0.2), CF(0.55, -0.85, -0.12), { 230, 60, 70 })
end

local function potion(m, liquid)
	MK.Ellipsoid(m, V3(2.2, 2.0, 2.2), CF(0, -0.55, 0), { 220, 245, 255 }, { Material = "Glass", Transparency = 0.55 })
	MK.Ellipsoid(m, V3(1.95, 1.55, 1.95), CF(0, -0.7, 0), liquid, { Material = "Neon", Transparency = 0.05 })
	-- цветная этикетка — цвет зелья видно даже без прозрачности
	MK.Ellipsoid(m, V3(2.26, 0.55, 2.26), CF(0, -0.45, 0), liquid)
	MK.Disc(m, 0.9, 0.8, V3(0, 0.75, 0), { 220, 245, 255 }, { Material = "Glass", Transparency = 0.3 })
	MK.Disc(m, 0.55, 0.9, V3(0, 1.35, 0), { 170, 120, 80 })
	MK.Ellipsoid(m, V3(0.45, 0.3, 0.2), CF(-0.55, -0.05, -1.05), WHITE, { Transparency = 0.2 })
end

function B.CoinElixir(m)
	potion(m, { 255, 196, 46 })
	MK.Cylinder(m, 0.15, 0.6, CF(0, -0.7, -1.02) * ANG(0, rad(90), 0), GOLD_D, { Material = "Metal" })
end

function B.DrillOvercharge(m)
	potion(m, { 255, 80, 70 })
	MK.Part(m, V3(0.28, 0.75, 0.15), CF(0.1, -0.45, -1.05) * ANG(0, 0, rad(25)), { 255, 240, 120 }, { Material = "Neon" })
	MK.Part(m, V3(0.28, 0.75, 0.15), CF(-0.1, -0.95, -1.05) * ANG(0, 0, rad(25)), { 255, 240, 120 }, { Material = "Neon" })
end

function B.LuckyCharm(m)
	local g = { 90, 220, 110 }
	for i = 0, 3 do
		local a = rad(i * 90 + 45)
		MK.Ellipsoid(m, V3(1.4, 1.4, 0.4), CF(math.cos(a) * 0.72, math.sin(a) * 0.72 + 0.2, 0) * ANG(0, 0, a), g)
		MK.Ellipsoid(m, V3(0.5, 0.5, 0.2), CF(math.cos(a) * 0.8, math.sin(a) * 0.8 + 0.2, -0.18), { 160, 250, 170 })
	end
	MK.CylinderBetween(m, V3(0, 0.1, 0), V3(0.5, -1.5, 0), 0.25, { 60, 160, 70 })
	MK.Ellipsoid(m, V3(0.4, 0.4, 0.4), CF(0, 0.2, -0.15), { 255, 240, 120 }, { Material = "Neon" })
end

function B.BioFertilizer(m)
	potion(m, { 170, 110, 255 })
	MK.Ellipsoid(m, V3(0.45, 0.25, 0.2), CF(0.2, -0.6, -1.05) * ANG(0, 0, rad(30)), { 140, 240, 120 })
end

function B.Seed(m)
	MK.Ellipsoid(m, V3(1.8, 2.4, 1.8), CF(0, -0.3, 0) * ANG(0, 0, rad(12)), { 150, 210, 90 })
	MK.Ellipsoid(m, V3(1.2, 0.5, 0.6), CF(0.6, 1.25, 0) * ANG(0, 0, rad(-25)), { 90, 190, 70 })
	MK.Ellipsoid(m, V3(0.5, 0.35, 0.2), CF(-0.4, 0.2, -0.85), WHITE, { Transparency = 0.3 })
end

function B.Drill(m)
	MK.Part(m, V3(1.4, 1.2, 1.8), CF(-0.4, 0.3, 0) * ANG(0, rad(90), 0), { 255, 196, 46 })
	MK.Part(m, V3(1.45, 0.3, 1.6), CF(-0.4, 0.5, 0) * ANG(0, rad(90), 0), { 40, 40, 48 })
	MK.Cylinder(m, 1.0, 0.55, CF(-0.7, -0.75, 0), { 60, 60, 70 })
	local x = 0.6
	for i, d in ipairs({ 1.0, 0.75, 0.5, 0.28 }) do
		MK.Cylinder(m, 0.45, d, CF(x + 0.22, 0.3, 0), (i % 2 == 0) and { 190, 194, 206 } or { 225, 228, 236 }, { Material = "Metal" })
		x = x + 0.42
	end
end

function B.Home(m)
	MK.Part(m, V3(2.4, 1.8, 2.0), CF(0, -0.6, 0), { 255, 245, 230 })
	MK.Wedge(m, V3(2.8, 1.3, 1.2), CF(0, 0.95, -0.6) * ANG(0, rad(180), 0), { 255, 100, 90 })
	MK.Wedge(m, V3(2.8, 1.3, 1.2), CF(0, 0.95, 0.6), { 255, 100, 90 })
	MK.Part(m, V3(0.7, 1.1, 0.1), CF(0, -0.95, -1.02), { 150, 100, 60 })
	MK.Part(m, V3(0.55, 0.5, 0.1), CF(0.75, -0.4, -1.02), { 120, 220, 255 }, { Material = "Neon" })
end

function B.Clock(m)
	MK.Cylinder(m, 0.5, 3.0, CF(0, 0, 0.1) * ANG(0, rad(90), 0), { 70, 160, 255 })
	MK.Cylinder(m, 0.55, 2.5, CF(0, 0, 0) * ANG(0, rad(90), 0), WHITE)
	MK.Part(m, V3(0.18, 0.9, 0.1), CF(0, 0.4, -0.3), INK)
	MK.Part(m, V3(0.7, 0.18, 0.1), CF(0.3, 0, -0.3), INK)
	MK.Ellipsoid(m, V3(0.25, 0.25, 0.1), CF(0, 0, -0.33), { 255, 86, 86 })
end

function B.Star(m)
	for i = 0, 4 do
		local a = rad(90 + i * 72)
		MK.Wedge(m, V3(0.5, 1.3, 0.55), CF(math.cos(a) * 0.65, math.sin(a) * 0.65, 0) * ANG(0, 0, a - rad(90)) * ANG(0, rad(90), 0), GOLD)
		MK.Wedge(m, V3(0.5, 1.3, 0.55), CF(math.cos(a) * 0.65, math.sin(a) * 0.65, 0) * ANG(0, 0, a - rad(90)) * ANG(0, rad(-90), 0), GOLD_D)
	end
	MK.Ellipsoid(m, V3(1.2, 1.2, 0.8), CF(0, 0, 0), GOLD)
end

function B.Lock(m)
	MK.Part(m, V3(2.0, 1.6, 0.9), CF(0, -0.5, 0), GOLD, { Material = "Metal" })
	MK.Cylinder(m, 0.3, 1.5, CF(0, 0.6, 0) * ANG(0, rad(90), 0), { 200, 200, 210 }, { Material = "Metal" })
	MK.Part(m, V3(0.25, 0.5, 0.1), CF(0, -0.5, -0.46), INK)
end

function B.Gem(m)
	B.Shard(m)
end

local cache = {}
function Icons.Build(name)
	local fn = B[name] or B.Star
	local m = model(name)
	fn(m)
	return m
end

function Icons.Get(name)
	if not cache[name] then
		cache[name] = Icons.Build(name)
	end
	return cache[name]:Clone()
end

Icons.Names = {}
for k in pairs(B) do
	table.insert(Icons.Names, k)
end
table.sort(Icons.Names)

return Icons
