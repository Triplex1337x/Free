-- PetBuilder: процедурная сборка chibi-питомцев в стиле популярных симуляторов.
-- Каждый питомец = архетип (силуэт) + набор деталей из PetLooks.
-- Модель смотрит в -Z, ноги на y = 0, Root (pivot) в (0, 1, 0).
local Configs = script.Parent.Parent:WaitForChild("Configs")
local PetLooks = require(Configs.PetLooks)
local PetsData = require(Configs.PetsData)
local MK = require(script.Parent.ModelKit)

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local PetBuilder = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(26, 22, 36)
local IVORY = Color3.fromRGB(250, 242, 222)
local PINK = Color3.fromRGB(255, 150, 170)
local GOLD = Color3.fromRGB(255, 205, 60)

-- Размер по редкости: мифики и эксклюзивы примерно в 2 раза больше обычных, «Огромные» — в 3 раза
local RARITY_SCALE = { Common = 1, Uncommon = 1.05, Rare = 1.1, Epic = 1.16, Legendary = 1.3, Mythic = 2.2, Secret = 2, Huge = 3 }

---------------------------------------------------------------------------------------------
-- Контекст сборки
---------------------------------------------------------------------------------------------
local ctx

local function colorOf(key)
	if typeof(key) == "Color3" then
		return key, "Fixed"
	elseif type(key) == "table" then
		return MK.C(key), "Fixed"
	elseif key == "C" then
		return ctx.C, "C"
	elseif key == "Cd" then
		return ctx.Cd, "Cd"
	elseif key == "C2" then
		return ctx.C2, "C2"
	elseif key == "C3" then
		return ctx.C3, "C3"
	end
	return ctx.C, "C"
end

local function matFor(paint, opts)
	if opts and opts.Material then
		return opts.Material
	end
	if paint == "C" or paint == "Cd" then
		return ctx.mat
	elseif paint == "C2" then
		return ctx.mat2
	end
	return "SmoothPlastic"
end

local function finish(p, paint, opts)
	p:SetAttribute("Paint", paint)
	p.Material = MK.Mat(matFor(paint, opts))
	if p.Material == Enum.Material.Glass and not (opts and opts.Transparency) then
		p.Transparency = 0.2
	end
	if opts then
		if opts.Transparency then
			p.Transparency = opts.Transparency
		end
		if opts.NoShadow then
			p.CastShadow = false
		end
	end
	if p.Size.Magnitude < 0.8 then
		p.CastShadow = false
	end
	return p
end

-- Эллипсоид
local function E(size, cf, color, opts)
	if typeof(cf) == "Vector3" then
		cf = CF(cf)
	end
	local c, paint = colorOf(color)
	local p = MK.Ellipsoid(ctx.model, size, cf, c)
	return finish(p, paint, opts)
end

-- Блок
local function B(size, cf, color, opts)
	if typeof(cf) == "Vector3" then
		cf = CF(cf)
	end
	local c, paint = colorOf(color)
	local p = MK.Part(ctx.model, size, cf, c)
	return finish(p, paint, opts)
end

-- Цилиндр между точками
local function Cyl(a, b, d, color, opts)
	local c, paint = colorOf(color)
	local p = MK.CylinderBetween(ctx.model, a, b, d, c)
	return finish(p, paint, opts)
end

-- Равнобедренный треугольник в плоскости XY фрейма cf (вершина вверх).
local function Tri(cf, w, h, t, color, opts)
	local c, paint = colorOf(color)
	local a = MK.Wedge(ctx.model, V3(t, h, w / 2), cf * CF(-w / 4, 0, 0) * ANG(0, rad(90), 0), c)
	local b = MK.Wedge(ctx.model, V3(t, h, w / 2), cf * CF(w / 4, 0, 0) * ANG(0, rad(-90), 0), c)
	finish(a, paint, opts)
	finish(b, paint, opts)
	return a, b
end

-- Конус из трёх цилиндров, от base в направлении dir.
local function Cone(base, dir, len, d, color, opts)
	dir = dir.Unit
	local p1 = base
	local steps = { { 0.45, 1 }, { 0.32, 0.7 }, { 0.23, 0.42 } }
	local last
	for _, s in ipairs(steps) do
		local p2 = p1 + dir * len * s[1]
		last = Cyl(p1, p2, d * s[2], color, opts)
		p1 = p2 - dir * len * 0.03
	end
	E(V3(d * 0.3, d * 0.3, d * 0.3), p1 + dir * len * 0.02, color, opts)
	return last
end

-- Скруглённый куб (как у питомцев популярных симуляторов): 3 перекрещенных блока,
-- 12 цилиндров по рёбрам и 8 сфер в углах. r — радиус скругления.
local function RoundBox(size, cf, color, r, opts)
	r = math.min(r, size.X / 2.2, size.Y / 2.2, size.Z / 2.2)
	local x, y, z = size.X / 2 - r, size.Y / 2 - r, size.Z / 2 - r
	local d = r * 2
	B(V3(size.X, size.Y - d, size.Z - d), cf, color, opts)
	B(V3(size.X - d, size.Y, size.Z - d), cf, color, opts)
	B(V3(size.X - d, size.Y - d, size.Z), cf, color, opts)
	local c, paint = colorOf(color)
	local function cyl(len, lcf)
		local p = MK.Cylinder(ctx.model, len, d, cf * lcf, c)
		finish(p, paint, opts)
	end
	for _, sy in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			cyl(size.X - d, CF(0, sy * y, sz * z))
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			cyl(size.Y - d, CF(sx * x, 0, sz * z) * ANG(0, 0, rad(90)))
		end
		for _, sy in ipairs({ -1, 1 }) do
			cyl(size.Z - d, CF(sx * x, sy * y, 0) * ANG(0, rad(90), 0))
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				E(V3(d, d, d), cf * CF(sx * x, sy * y, sz * z), color, opts)
			end
		end
	end
end

-- Z передней поверхности эллипсоида головы в точке (x, y)
local function surfZ(a, x, y)
	local hx, hy, hz = a.hs.X, a.hs.Y, a.hs.Z
	if a.flat then
		return a.hc.Z - hz
	end
	local k = 1 - (x / hx) ^ 2 - (y / hy) ^ 2
	if k < 0.05 then
		k = 0.05
	end
	return a.hc.Z - hz * math.sqrt(k)
end

-- Точка на лице: смещения относительно центра головы
local function faceAt(a, x, y, out)
	return V3(a.hc.X + x, a.hc.Y + y, surfZ(a, x, y) - (out or 0))
end

---------------------------------------------------------------------------------------------
-- Архетипы
---------------------------------------------------------------------------------------------
local ARCH = {}

ARCH.quad = function(look)
	-- chibi-пропорции: крупная голова, маленькое туловище, круглые лапки
	local long = look.Long and 0.55 or 0
	E(V3(1.55, 1.25, 1.75 + long), V3(0, 0.95, 0.45 + long / 2), "C")
	E(V3(1.0, 0.8, 0.5), V3(0, 0.92, -0.3), "C2")
	local hc = V3(0, 1.95, -0.55)
	local hs = V3(2.15, 1.95, 1.85)
	E(hs, hc, "C")
	if not (ctx.has.snout or ctx.has.trunk or ctx.has.stripe_head or ctx.has.nose_big) then
		E(V3(1.05, 0.66, 0.55), hc + V3(0, -0.42, -0.72), "C2")
	end
	local front = { V3(-0.5, 0.26, -0.1), V3(0.5, 0.26, -0.1) }
	for _, p in ipairs(front) do
		E(V3(0.56, 0.52, 0.66), p, "Cd")
		E(V3(0.4, 0.14, 0.24), p + V3(0, -0.14, -0.28), "C2")
	end
	E(V3(0.56, 0.52, 0.66), V3(-0.5, 0.26, 1.05 + long), "Cd")
	E(V3(0.56, 0.52, 0.66), V3(0.5, 0.26, 1.05 + long), "Cd")
	return {
		hc = hc, hs = hs / 2, eyeY = 0.1,
		back = V3(0, 1.55, 0.5 + long / 2), tail = V3(0, 1.05, 1.3 + long),
		side = 0.78, wingY = 1.5, front = front, top = hc + V3(0, 0.97, 0),
		bodyC = V3(0, 0.95, 0.45 + long / 2), bodyS = V3(0.78, 0.62, 0.88 + long / 2),
	}
end

ARCH.blob = function(look)
	local hc = V3(0, 1.05, 0)
	local hs = V3(2.3, 2.1, 2.2)
	E(hs, hc, "C")
	E(V3(0.62, 0.3, 0.75), V3(-0.55, 0.12, -0.35), "Cd")
	E(V3(0.62, 0.3, 0.75), V3(0.55, 0.12, -0.35), "Cd")
	return {
		hc = hc, hs = hs / 2, eyeY = 0.18,
		back = V3(0, 2.05, 0.25), tail = V3(0, 0.75, 1.05),
		side = 1.15, wingY = 1.2, front = { V3(-0.55, 0.12, -0.6), V3(0.55, 0.12, -0.6) },
		top = hc + V3(0, 1.05, 0), bodyC = hc, bodyS = hs / 2,
	}
end

ARCH.bird = function(look)
	local hc = V3(0, 1.2, 0.05)
	local hs = V3(1.9, 2.05, 1.85)
	E(hs, hc, "C")
	E(V3(1.35, 1.45, 1.0), V3(0, 1.0, -0.42), "C2")
	local feet = Color3.fromRGB(255, 170, 60)
	E(V3(0.36, 0.16, 0.52), V3(-0.35, 0.08, -0.2), feet)
	E(V3(0.36, 0.16, 0.52), V3(0.35, 0.08, -0.2), feet)
	if not (ctx.has.wings_feather or ctx.has.wings_bat or ctx.has.wings_crystal or ctx.has.flippers) then
		E(V3(0.35, 1.05, 1.15), CF(-0.98, 1.15, 0.2) * ANG(0, 0, rad(-12)), "Cd")
		E(V3(0.35, 1.05, 1.15), CF(0.98, 1.15, 0.2) * ANG(0, 0, rad(12)), "Cd")
	end
	return {
		hc = hc, hs = hs / 2, eyeY = 0.35,
		back = V3(0, 2.15, 0.25), tail = V3(0, 0.85, 0.95),
		side = 0.95, wingY = 1.25, front = {}, top = hc + V3(0, 1.0, 0),
		bodyC = hc, bodyS = hs / 2,
	}
end

ARCH.bat = function(look)
	local hc = V3(0, 1.55, 0)
	local hs = V3(1.6, 1.5, 1.45)
	E(hs, hc, "C")
	E(V3(1.0, 0.9, 0.6), V3(0, 1.35, -0.45), "C2")
	ctx.has.wings_bat = true
	return {
		hc = hc, hs = hs / 2, eyeY = 0.16,
		back = V3(0, 2.25, 0.2), tail = V3(0, 1.2, 0.7),
		side = 0.8, wingY = 1.6, front = {}, top = hc + V3(0, 0.75, 0),
		bodyC = hc, bodyS = hs / 2,
	}
end

ARCH.bug = function(look)
	E(V3(1.9, 1.05, 2.3), V3(0, 0.85, 0.3), "C")
	if not ctx.has.segments then
		B(V3(0.07, 0.1, 2.0), CF(0, 1.36, 0.32), INK, { Transparency = 0.3 })
	end
	local hc = V3(0, 0.88, -0.95)
	local hs = V3(1.3, 1.0, 1.0)
	E(hs, hc, "C3")
	for _, z in ipairs({ -0.3, 0.3, 0.9 }) do
		for _, s in ipairs({ -1, 1 }) do
			Cyl(V3(s * 0.7, 0.6, z), V3(s * 1.2, 0.04, z - 0.1), 0.17, "Cd")
		end
	end
	return {
		hc = hc, hs = hs / 2, eyeY = 0.05,
		back = V3(0, 1.38, 0.3), tail = V3(0, 0.8, 1.45),
		side = 0.95, wingY = 1.2, front = {}, top = hc + V3(0, 0.5, 0),
		bodyC = V3(0, 0.85, 0.3), bodyS = V3(0.95, 0.52, 1.15),
	}
end

ARCH.crab = function(look)
	E(V3(2.4, 1.15, 1.7), V3(0, 0.95, 0), "C")
	E(V3(1.6, 0.5, 1.1), V3(0, 0.62, -0.1), "C2")
	for _, s in ipairs({ -1, 1 }) do
		Cyl(V3(s * 1.0, 0.95, -0.35), V3(s * 1.4, 1.0, -0.7), 0.3, "Cd")
		E(V3(0.9, 0.75, 1.05), V3(s * 1.5, 1.05, -0.95), "C")
		E(V3(0.4, 0.35, 0.6), V3(s * 1.3, 1.25, -1.45), "C")
		for i, z in ipairs({ -0.2, 0.2, 0.55 }) do
			Cyl(V3(s * 1.0, 0.75, z), V3(s * 1.55, 0.04, z + 0.15), 0.15, "Cd")
		end
		Cyl(V3(s * 0.4, 1.3, -0.55), V3(s * 0.45, 1.85, -0.6), 0.14, "Cd")
		E(V3(0.5, 0.5, 0.5), V3(s * 0.45, 1.95, -0.6), WHITE)
		E(V3(0.3, 0.32, 0.2), V3(s * 0.45, 1.95, -0.82), INK)
		E(V3(0.1, 0.1, 0.06), V3(s * 0.45 + 0.07, 2.04, -0.92), WHITE)
	end
	return {
		hc = V3(0, 1.0, -0.2), hs = V3(1.0, 0.5, 0.75), noEyes = true,
		back = V3(0, 1.5, 0), tail = V3(0, 0.9, 0.85),
		side = 1.2, wingY = 1.2, front = {}, top = V3(0, 1.55, 0),
		bodyC = V3(0, 0.95, 0), bodyS = V3(1.2, 0.58, 0.85),
	}
end

ARCH.fish = function(look)
	local size = look.Narrow and V3(1.3, 1.15, 3.0) or V3(1.6, 1.1, 2.6)
	local bc = V3(0, 1.2, 0)
	E(size, bc, "C")
	E(V3(size.X * 0.7, size.Y * 0.5, size.Z * 0.75), bc + V3(0, -0.25, 0), "C2")
	if look.Wide then
		E(V3(3.8, 0.22, 1.9), CF(0, 1.1, 0.15), "C2")
	else
		E(V3(0.75, 0.14, 0.85), CF(-0.85, 1.05, 0.15) * ANG(0, rad(-25), rad(-20)), "Cd")
		E(V3(0.75, 0.14, 0.85), CF(0.85, 1.05, 0.15) * ANG(0, rad(25), rad(20)), "Cd")
	end
	if not (ctx.has.tail_fluke or ctx.has.tail_whip) then
		E(V3(0.18, 1.0, 0.75), CF(0, 1.3, size.Z / 2 + 0.2) * ANG(rad(-20), 0, 0), "Cd")
	end
	return {
		hc = bc, hs = size / 2, eyeY = 0.18,
		back = bc + V3(0, size.Y / 2, 0), tail = bc + V3(0, 0, size.Z / 2),
		side = size.X / 2, wingY = 1.2, front = {}, top = bc + V3(0, size.Y / 2, -0.4),
		bodyC = bc, bodyS = size / 2,
	}
end

ARCH.dino = function(look)
	E(V3(1.75, 1.5, 2.3), V3(0, 1.1, 0.3), "C")
	E(V3(1.2, 1.0, 1.45), V3(0, 0.95, -0.1), "C2")
	local hc, hs
	if ctx.has.long_neck then
		hc = V3(0, 3.05, -1.45)
		hs = V3(1.25, 1.1, 1.3)
		Cyl(V3(0, 1.6, -0.55), V3(0, 2.75, -1.3), 0.75, "C")
		E(V3(0.8, 0.8, 1.0), V3(0, 2.2, -0.9), "C")
	elseif ctx.has.big_head then
		hc = V3(0, 2.1, -1.1)
		hs = V3(1.8, 1.6, 1.9)
	else
		hc = V3(0, 2.0, -1.0)
		hs = V3(1.75, 1.55, 1.7)
	end
	E(hs, hc, "C")
	E(V3(hs.X * 0.68, hs.Y * 0.55, hs.Z * 0.55), hc + V3(0, -0.22, -hs.Z * 0.45), "C")
	if look.Biped then
		E(V3(0.65, 0.85, 0.75), V3(-0.55, 0.42, 0.55), "Cd")
		E(V3(0.65, 0.85, 0.75), V3(0.55, 0.42, 0.55), "Cd")
	else
		for _, p in ipairs({ V3(-0.55, 0.35, -0.35), V3(0.55, 0.35, -0.35), V3(-0.55, 0.35, 0.95), V3(0.55, 0.35, 0.95) }) do
			E(V3(0.55, 0.7, 0.6), p, "Cd")
		end
	end
	E(V3(0.75, 0.7, 1.6), CF(0, 1.0, 1.75) * ANG(rad(8), 0, 0), "C")
	E(V3(0.42, 0.42, 0.95), CF(0, 0.85, 2.5) * ANG(rad(12), 0, 0), "C")
	return {
		hc = hc, hs = hs / 2, eyeY = 0.12,
		back = V3(0, 1.82, 0.3), tail = V3(0, 0.85, 2.9),
		side = 0.88, wingY = 1.7, front = { V3(-0.55, 0.35, -0.35), V3(0.55, 0.35, -0.35) },
		top = hc + V3(0, hs.Y / 2, 0), bodyC = V3(0, 1.1, 0.3), bodyS = V3(0.88, 0.75, 1.15),
	}
end

ARCH.dragon = ARCH.dino

ARCH.golem = function(look)
	-- округлый "плюшевый" голем: всё из эллипсоидов
	E(V3(2.0, 1.75, 1.6), V3(0, 1.45, 0), "C")
	E(V3(1.2, 0.9, 0.4), V3(0, 1.45, -0.68), "C2")
	local hc = V3(0, 2.7, -0.08)
	local hs = V3(1.8, 1.55, 1.55)
	E(hs, hc, "C")
	for _, s in ipairs({ -1, 1 }) do
		E(V3(0.8, 1.25, 0.85), CF(s * 1.25, 1.45, -0.05) * ANG(0, 0, rad(s * -10)), "Cd")
		E(V3(0.95, 0.8, 0.95), V3(s * 1.4, 0.72, -0.12), "C3")
		E(V3(0.78, 0.7, 0.85), V3(s * 0.5, 0.35, 0), "Cd")
	end
	return {
		hc = hc, hs = hs / 2, eyeY = 0.06,
		back = V3(0, 2.25, 0.35), tail = V3(0, 1.2, 0.75),
		side = 1.0, wingY = 2.0, front = { V3(-1.4, 0.4, -0.5), V3(1.4, 0.4, -0.5) },
		top = hc + V3(0, 0.75, 0), shoulders = { V3(-1.05, 2.15, 0), V3(1.05, 2.15, 0) },
		bodyC = V3(0, 1.45, 0), bodyS = V3(1.0, 0.85, 0.8),
	}
end

ARCH.orb = function(look)
	local hc = V3(0, 1.75, 0)
	local hs = V3(1.95, 1.95, 1.95)
	E(hs, hc, "C")
	if look.M ~= "Neon" then
		E(hs * 0.82, hc + V3(0, -0.15, -0.12), "C2", { Transparency = 0.6 })
	end
	return {
		hc = hc, hs = hs / 2, eyeY = 0.1,
		back = hc + V3(0, 0.95, 0), tail = hc + V3(0, 0, 0.95),
		side = 1, wingY = 1.75, front = {}, top = hc + V3(0, 0.98, 0),
		bodyC = hc, bodyS = hs / 2,
	}
end

ARCH.serpent = function(look)
	local fly = look.Fly ~= false
	local dy = fly and 0 or -0.58
	local hc = V3(0, 1.55 + dy, -1.15)
	local hs = V3(1.55, 1.35, 1.45)
	E(hs, hc, "C")
	local segs = {
		{ V3(0, 1.25 + dy, -0.25), 1.25 },
		{ V3(0, 1.5 + dy, 0.6), 1.1 },
		{ V3(0, 1.25 + dy, 1.35), 0.95 },
		{ V3(0, 1.45 + dy, 2.0), 0.8 },
		{ V3(0, 1.25 + dy, 2.55), 0.62 },
	}
	for i, s in ipairs(segs) do
		local col = (i % 2 == 0) and "C2" or "C"
		if not fly then
			col = (i % 2 == 0) and "Cd" or "C"
		end
		E(V3(s[2], s[2], s[2] * 1.05), s[1], col)
	end
	return {
		hc = hc, hs = hs / 2, eyeY = 0.12,
		back = V3(0, 2.0 + dy, -0.25), tail = segs[5][1],
		side = 0.7, wingY = 1.6 + dy, front = {}, top = hc + V3(0, 0.68, 0),
		segs = segs, bodyC = segs[2][1], bodyS = V3(0.6, 0.6, 1.2),
	}
end

ARCH.wisp = function(look)
	local hc = V3(0, 1.65, 0)
	local hs = V3(1.85, 1.8, 1.8)
	E(hs, hc, "C", { Transparency = look.M == "Neon" and 0 or 0.3 })
	E(V3(0.95, 0.95, 0.95), hc + V3(0, -0.05, 0.1), "C2", { Material = "Neon", Transparency = 0.15 })
	E(V3(0.9, 1.3, 0.9), CF(hc + V3(0, -0.85, 0.55)) * ANG(rad(-50), 0, 0), "C", { Transparency = look.M == "Neon" and 0 or 0.3 })
	MK.Light(ctx.root, ctx.C2, 8, 1.2)
	return {
		hc = hc, hs = hs / 2, eyeY = 0.12,
		back = hc + V3(0, 0.9, 0.1), tail = hc + V3(0, -0.6, 0.9),
		side = 0.92, wingY = 1.6, front = {}, top = hc + V3(0, 0.9, 0),
		bodyC = hc, bodyS = hs / 2,
	}
end

-- Кубический питомец в стиле Pet Simulator: скруглённый куб-голова-тело и маленькие лапки.
-- kind — исходный архетип (quad/blob/bird/bat/golem): от него зависят пропорции и лапы.
ARCH.cube = function(look, kind)
	kind = kind or "quad"
	local size = V3(2.3, 2.15, 2.15)
	local footH = 0.42
	if kind == "blob" then
		size = V3(2.5, 1.95, 2.35)
		footH = 0.05
	elseif kind == "golem" then
		size = V3(2.6, 2.4, 2.3)
	elseif kind == "bird" or kind == "bat" then
		size = V3(2.2, 2.1, 2.0)
		footH = 0.32
	end
	if look.Long then
		size = size + V3(0, 0, 0.5)
	end
	if look.Box then
		size = V3(look.Box[1], look.Box[2], look.Box[3])
	end
	local hc = V3(0, footH + size.Y / 2, 0)
	local r = kind == "blob" and 0.75 or 0.42
	RoundBox(size, CF(hc), "C", r)
	-- светлая «мордочка»/животик на передней грани
	if not (ctx.has.snout or ctx.has.trunk or ctx.has.stripe_head or ctx.has.nose_big or ctx.has.eye_single) then
		E(V3(size.X * 0.48, size.Y * 0.3, 0.16), hc + V3(0, -size.Y * 0.24, -size.Z / 2 - 0.01), "C2")
	end
	local front = {}
	if kind == "bird" then
		local feet = Color3.fromRGB(255, 170, 60)
		for _, sx in ipairs({ -1, 1 }) do
			E(V3(0.42, 0.22, 0.6), V3(sx * 0.42, 0.12, -0.2), feet)
		end
		if not (ctx.has.wings_feather or ctx.has.wings_bat or ctx.has.wings_crystal) then
			for _, sx in ipairs({ -1, 1 }) do
				E(V3(0.3, 1.1, 1.2), CF(sx * (size.X / 2 + 0.08), hc.Y - 0.1, 0.1) * ANG(0, 0, rad(sx * -10)), "Cd")
			end
		end
	elseif kind == "golem" then
		for _, sx in ipairs({ -1, 1 }) do
			RoundBox(V3(0.75, 1.35, 0.8), CF(sx * (size.X / 2 + 0.35), hc.Y - 0.2, -0.1) * ANG(0, 0, rad(sx * 8)), "Cd", 0.3)
			RoundBox(V3(0.75, 0.6, 0.85), CF(sx * 0.62, 0.3, 0), "C3", 0.25)
		end
	elseif kind ~= "blob" then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local p = V3(sx * (size.X / 2 - 0.45), footH * 0.55, sz * (size.Z / 2 - 0.45))
				E(V3(0.6, footH * 1.4 + 0.15, 0.62), p, "Cd")
				if sz < 0 then
					table.insert(front, p)
				end
			end
		end
	end
	return {
		hc = hc, hs = size / 2, flat = true, eyeY = 0.1,
		back = hc + V3(0, size.Y / 2, 0.35), tail = hc + V3(0, -size.Y * 0.2, size.Z / 2),
		side = size.X / 2, wingY = hc.Y + 0.2, front = front, top = hc + V3(0, size.Y / 2, 0),
		bodyC = hc, bodyS = size / 2,
	}
end

-- Мифик: крупный кубический или сферический (Body = "orb") питомец + эффекты (см. mythicFx)
ARCH.mythic = function(look)
	local m = look.Mythic or {}
	if m.Body == "orb" then
		return ARCH.orb(look)
	end
	return ARCH.cube(look, m.Kind or "quad")
end

---------------------------------------------------------------------------------------------
-- Глаза
---------------------------------------------------------------------------------------------
-- Глаза в стиле аниме: белок, цветная радужка с переходом, зрачок и два блика.
local IRIS = {
	Color3.fromRGB(255, 176, 40), Color3.fromRGB(90, 200, 90), Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(170, 100, 255), Color3.fromRGB(255, 110, 150), Color3.fromRGB(60, 210, 200),
}
local function buildEyes(look, a)
	if a.noEyes or ctx.has.eye_single then
		return
	end
	local w = a.hs.X * 2
	local style = look.E
	local size = math.clamp(w * 0.3, 0.32, 0.72)
	if style == "small" then
		size = size * 0.75
	elseif style == "big" then
		size = size * 1.18
	end
	local ex = w * 0.22
	local ey = (a.eyeY or 0.1) * a.hs.Y * 2
	-- у «Огромных» всегда живые аниме-глаза с цветной радужкой (так милее), у мификов — светящиеся
	local glow = (style == "glow" or (look.Mythic ~= nil)) and not look.Huge and not look.CuteEyes
	local iris = look.Iris and MK.C(look.Iris) or (look.EyeColor and MK.C(look.EyeColor)) or IRIS[(ctx.hash % #IRIS) + 1]
	for _, sx in ipairs({ -1, 1 }) do
		local pos = faceAt(a, sx * ex, ey, 0.02)
		local n
		if a.flat then
			n = V3(0, 0, -1)
		else
			n = ((pos - a.hc) * V3(0.35, 0.2, 1)).Unit
		end
		local f = CF(pos, pos + n)
		local h = size * 1.28
		if glow then
			local ec = look.EyeColor and MK.C(look.EyeColor) or iris
			E(V3(size * 1.08, h * 1.05, 0.12), f, INK)
			E(V3(size * 0.9, h * 0.88, 0.14), f * CF(0, 0, -0.02), ec, { Material = "Neon" })
			E(V3(size * 0.36, h * 0.5, 0.12), f * CF(0, -h * 0.02, -0.05), Color3.new(1, 1, 1), { Material = "Neon" })
		else
			-- тёмная обводка + белок
			E(V3(size * 1.06, h * 1.04, 0.1), f, INK)
			E(V3(size * 0.92, h * 0.9, 0.12), f * CF(0, 0, -0.015), WHITE)
			-- радужка: тёмный низ и светлый верх (переход)
			E(V3(size * 0.78, h * 0.78, 0.12), f * CF(0, -h * 0.04, -0.035), iris:Lerp(INK, 0.35))
			E(V3(size * 0.62, h * 0.5, 0.12), f * CF(0, h * 0.06, -0.045), iris:Lerp(WHITE, 0.15))
			-- зрачок
			E(V3(size * 0.38, h * 0.46, 0.12), f * CF(0, -h * 0.02, -0.06), INK)
			-- блики
			E(V3(size * 0.32, size * 0.32, 0.1), f * CF(-sx * size * 0.16, h * 0.2, -0.08), WHITE)
			E(V3(size * 0.15, size * 0.15, 0.1), f * CF(sx * size * 0.17, -h * 0.2, -0.08), WHITE)
		end
	end
	local beaked = ctx.has.beak or ctx.has.beak_long or ctx.has.snout or ctx.has.trunk
	-- румянец
	for _, sx in ipairs({ -1, 1 }) do
		local pos = faceAt(a, sx * w * 0.37, ey - size * 0.9, -0.02)
		E(V3(size * 0.7, size * 0.34, 0.08), pos, PINK, { Transparency = ctx.has.cheeks and 0.05 or 0.35 })
	end
	if not beaked then
		-- ротик «ω»
		local my = ey - size * 1.0
		for _, sx in ipairs({ -1, 1 }) do
			local pos = faceAt(a, sx * size * 0.15, my, 0.02)
			B(V3(size * 0.32, size * 0.08, 0.06), CF(pos) * ANG(0, 0, rad(sx * -28)), Color3.fromRGB(70, 34, 44))
		end
	end
	a.eyeSize = size
	a.eyeYabs = ey
end

---------------------------------------------------------------------------------------------
-- Детали
---------------------------------------------------------------------------------------------
local X = {}

local function ears(a, k, pointy)
	for _, s in ipairs({ -1, 1 }) do
		local base = a.hc + V3(s * a.hs.X * 0.62, a.hs.Y * 0.78, 0.08)
		if pointy then
			local cf = CF(base + V3(0, 0.3 * k, 0)) * ANG(0, 0, rad(s * -14))
			Tri(cf, 0.62 * k, 0.8 * k, 0.22, "C")
			Tri(cf * CF(0, -0.06 * k, -0.08), 0.36 * k, 0.5 * k, 0.12, "C2")
		else
			E(V3(0.62 * k, 0.62 * k, 0.26), CF(base + V3(0, 0.12 * k, 0)) * ANG(0, 0, rad(s * -18)), "C")
			E(V3(0.38 * k, 0.38 * k, 0.12), CF(base + V3(0, 0.12 * k, -0.11)) * ANG(0, 0, rad(s * -18)), "C2")
		end
	end
end

X.ears_round = function(look, a) ears(a, 1, false) end
X.ears_round_big = function(look, a) ears(a, 1.45, false) end
X.ears_pointy = function(look, a) ears(a, 1, true) end
X.ears_pointy_big = function(look, a) ears(a, 1.4, true) end

X.ears_long = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local cf = CF(a.hc + V3(s * 0.38, a.hs.Y + 0.55, 0.12)) * ANG(rad(-8), 0, rad(s * -10))
		E(V3(0.46, 1.5, 0.32), cf, "C")
		E(V3(0.26, 1.1, 0.12), cf * CF(0, 0, -0.12), PINK)
	end
end

X.ear_tufts = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		Tri(CF(a.hc + V3(s * a.hs.X * 0.62, a.hs.Y * 0.95, 0)) * ANG(0, 0, rad(s * -22)), 0.4, 0.6, 0.18, "Cd")
	end
end

X.tail_thin = function(look, a)
	local p1 = a.tail
	local p2 = p1 + V3(0, 0.35, 0.65)
	local p3 = p2 + V3(0, 0.45, 0.25)
	Cyl(p1, p2, 0.2, "C")
	Cyl(p2, p3, 0.16, "C")
	E(V3(0.26, 0.26, 0.26), p3, ctx.has.flame_tail and "C2" or "C", ctx.has.flame_tail and { Material = "Neon" } or nil)
end

X.tail_long = function(look, a)
	E(V3(0.62, 0.5, 1.3), CF(a.tail + V3(0, -0.15, 0.45)) * ANG(rad(10), 0, 0), "C")
	E(V3(0.42, 0.36, 1.1), CF(a.tail + V3(0, -0.35, 1.3)) * ANG(rad(8), 0, 0), "C")
	E(V3(0.26, 0.24, 0.7), a.tail + V3(0, -0.45, 1.95), "C")
end

X.tail_fluffy = function(look, a)
	local cf = CF(a.tail + V3(0, 0.45, 0.6)) * ANG(rad(40), 0, 0)
	E(V3(0.85, 0.85, 1.55), cf, "C")
	E(V3(0.6, 0.6, 0.65), cf * CF(0, 0, 0.62), "C2")
end

X.tails_multi = function(look, a)
	-- три пушистых хвоста веером (кицунэ)
	for i, ang in ipairs({ -38, 0, 38 }) do
		local cf = CF(a.tail) * ANG(0, rad(ang), 0) * ANG(rad(40), 0, 0) * CF(0, 0.15, 0.75)
		E(V3(0.8, 0.8, 1.6), cf, "C")
		E(V3(0.62, 0.62, 0.7), cf * CF(0, 0, 0.7), "C2", { Material = "Neon", Transparency = 0.1 })
	end
end

X.bell = function(look, a)
	local gold = Color3.fromRGB(255, 205, 60)
	local y = a.hc.Y - a.hs.Y * 0.95
	E(V3(a.hs.X * 1.5, 0.22, a.hs.Z * 1.4), V3(0, y + 0.05, a.hc.Z + 0.1), Color3.fromRGB(230, 50, 70))
	E(V3(0.5, 0.5, 0.5), V3(0, y - 0.15, a.hc.Z - a.hs.Z * 0.62), gold, { Material = "Metal" })
end

X.tail_puff = function(look, a)
	E(V3(0.75, 0.75, 0.75), a.tail + V3(0, 0.15, 0.05), ctx.has.tail_puff and "C2" or "C")
end

X.tail_spikes = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		Tri(CF(a.tail + V3(s * 0.22, 0.35, -0.1)) * ANG(0, 0, rad(s * -35)), 0.3, 0.7, 0.15, IVORY)
	end
end

X.club_tail = function(look, a)
	E(V3(0.9, 0.7, 0.9), a.tail + V3(0, 0.05, 0.2), "C3")
	for _, s in ipairs({ -1, 1 }) do
		Tri(CF(a.tail + V3(s * 0.48, 0.05, 0.2)) * ANG(0, 0, rad(s * -90)), 0.3, 0.45, 0.15, IVORY)
	end
end

X.tail_feathers = function(look, a)
	for i, ang in ipairs({ -28, 0, 28 }) do
		local col = (i == 2) and "C2" or "C"
		E(V3(0.42, 0.14, 1.3), CF(a.tail) * ANG(rad(-20), rad(ang), 0) * CF(0, 0, 0.6), col)
	end
end

X.tail_fluke = function(look, a)
	E(V3(1.5, 0.16, 0.65), CF(a.tail + V3(0, 0.1, 0.25)), "Cd")
end

X.tail_whip = function(look, a)
	Cyl(a.tail, a.tail + V3(0, 0.1, 1.6), 0.16, "Cd")
	E(V3(0.3, 0.3, 0.3), a.tail + V3(0, 0.1, 1.6), "C2", { Material = "Neon" })
end

X.flame_tail = function() end

X.whiskers = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 0.9
	for _, s in ipairs({ -1, 1 }) do
		local o = faceAt(a, s * a.hs.X * 0.35, y, 0.02)
		for _, dy in ipairs({ -0.08, 0.08 }) do
			Cyl(o, o + V3(s * 0.65, dy * 2, 0.08), 0.05, INK, { NoShadow = true })
		end
	end
end

local function nose(a, size, color)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 0.75
	local p = faceAt(a, 0, y, 0.05)
	E(V3(size, size * 0.75, size * 0.6), p, color)
end
X.nose = function(look, a) nose(a, 0.26, Color3.fromRGB(60, 40, 50)) end
X.nose_big = function(look, a) nose(a, 0.55, PINK) end

X.snout = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 1.25
	local p = faceAt(a, 0, y, -0.12)
	E(V3(0.95, 0.62, 0.75), p, "C2")
	E(V3(0.3, 0.22, 0.2), p + V3(0, 0.12, -0.35), INK)
end

X.tongue = function(look, a)
	local p = faceAt(a, 0, -(a.hs.Y * 0.35), 0.1)
	E(V3(0.22, 0.08, 0.7), p + V3(0, 0, -0.25), PINK)
end

X.claws = function(look, a)
	for _, f in ipairs(a.front or {}) do
		for i = -1, 1 do
			E(V3(0.1, 0.12, 0.22), f + V3(i * 0.14, -0.22, -0.3), IVORY)
		end
	end
end

X.spikes_back = function(look, a)
	-- пирамидки CornerWedge: видны с любого ракурса и стоят всего 1 деталь
	local bc, bs = a.bodyC, a.bodyS
	local rows = { { -0.55, 0.88 }, { 0, 1 }, { 0.55, 0.88 } }
	for _, r in ipairs(rows) do
		for k = -2, 2 do
			local z = bc.Z + k * bs.Z * 0.36
			local x = r[1] * bs.X
			local y = bc.Y + bs.Y * r[2] * math.sqrt(math.max(0.2, 1 - (k * 0.36) ^ 2)) - 0.08
			local tilt = ANG(rad(-32), rad(45), rad(-r[1] * 45))
			local c, paint = colorOf("C3")
			local sp = MK.Corner(ctx.model, V3(0.42, 0.72, 0.42), CF(x, y + 0.22, z) * tilt, c)
			finish(sp, paint)
		end
	end
end

X.plates_back = function(look, a)
	local bc, bs = a.bodyC, a.bodyS
	for k = -2, 2 do
		local z = bc.Z + k * bs.Z * 0.38
		local h = 0.75 - math.abs(k) * 0.12
		Tri(CF(0, bc.Y + bs.Y + h * 0.35, z) * ANG(0, rad(90), 0), 0.7, h, 0.14, "C2")
	end
end

X.shell = function(look, a)
	local bc, bs = a.bodyC, a.bodyS
	-- панцирь крупнее тела, с тёмными поясами
	E(V3(bs.X * 2.45, bs.Y * 2.0, bs.Z * 2.35), bc + V3(0, bs.Y * 0.45, 0.05), "C3")
	for k = -1, 1 do
		E(V3(bs.X * 2.5, bs.Y * 1.7, 0.2), bc + V3(0, bs.Y * 0.62, k * bs.Z * 0.55 + 0.05), MK.Shade(ctx.C3, -0.3))
	end
end

local function crystal(pos, h, tilt, color)
	color = color or "C2"
	local cf = CF(pos) * tilt * ANG(0, rad(45), 0)
	B(V3(0.32, h, 0.32), cf * CF(0, h / 2, 0), color, { Material = "Glass", Transparency = 0.1 })
	Tri(cf * CF(0, h + 0.12, 0), 0.32, 0.24, 0.3, color, { Material = "Glass", Transparency = 0.1 })
end

X.crystals = function(look, a)
	local pts = a.shoulders or { a.back + V3(-0.35, -0.05, 0.1), a.back + V3(0.35, -0.05, -0.1) }
	for i, p in ipairs(pts) do
		local s = (i == 1) and -1 or 1
		crystal(p, 0.75, ANG(rad(-10), 0, rad(s * -25)))
		crystal(p + V3(s * 0.25, -0.05, 0.25), 0.5, ANG(rad(15), 0, rad(s * -45)))
	end
	crystal(a.back + V3(0, -0.05, 0.3), 0.9, ANG(rad(-15), 0, 0))
end

X.moss = function(look, a)
	local green = Color3.fromRGB(110, 190, 80)
	E(V3(1.0, 0.25, 0.8), a.top + V3(0.1, 0.02, 0.05), green)
	E(V3(0.6, 0.22, 0.5), a.back + V3(-0.4, 0, 0.2), green)
end

X.horns = function(look, a)
	local c = (ctx.has.glow and "C2") or IVORY
	for _, s in ipairs({ -1, 1 }) do
		local base = a.hc + V3(s * a.hs.X * 0.5, a.hs.Y * 0.8, 0.15)
		Cone(base, V3(s * 0.45, 1, 0.35), 0.95, 0.32, c, (c == "C2") and { Material = "Neon" } or nil)
	end
end

X.horns_small = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		Cone(a.hc + V3(s * a.hs.X * 0.5, a.hs.Y * 0.82, 0.05), V3(s * 0.3, 1, 0), 0.5, 0.24, IVORY)
	end
end

X.horn_single = function(look, a)
	Cone(faceAt(a, 0, a.hs.Y * 0.45, -0.1), V3(0, 1, -0.6), 0.9, 0.3, "C3", { Material = "Metal" })
end

X.horn_single_long = function(look, a)
	Cone(faceAt(a, 0, a.hs.Y * 0.1, -0.15), V3(0, 0.12, -1), 2.1, 0.28, IVORY)
end

X.antlers = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local b0 = a.hc + V3(s * a.hs.X * 0.45, a.hs.Y * 0.85, 0.1)
		local b1 = b0 + V3(s * 0.35, 0.7, 0.1)
		local b2 = b1 + V3(s * 0.4, 0.55, 0.15)
		local opts = { Material = "Glass", Transparency = 0.05 }
		Cyl(b0, b1, 0.16, "C2", opts)
		Cyl(b1, b2, 0.13, "C2", opts)
		Cyl(b1, b1 + V3(s * -0.1, 0.5, -0.25), 0.11, "C2", opts)
		Cyl(b2, b2 + V3(s * 0.05, 0.35, -0.2), 0.1, "C2", opts)
		Cyl(b2, b2 + V3(s * 0.35, 0.15, 0.05), 0.1, "C2", opts)
	end
end

X.tusks = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 1.4
	for _, s in ipairs({ -1, 1 }) do
		local p = faceAt(a, s * a.hs.X * 0.35, y, 0)
		Cone(p, V3(s * 0.25, 0.35, -1), 0.95, 0.22, IVORY)
	end
end

X.tusks_down = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 1.5
	for _, s in ipairs({ -1, 1 }) do
		local p = faceAt(a, s * a.hs.X * 0.22, y, -0.02)
		Cone(p, V3(0, -1, -0.25), 0.75, 0.2, IVORY)
	end
end

X.trunk = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 1.0
	local p = faceAt(a, 0, y, 0)
	E(V3(0.5, 0.55, 0.55), p + V3(0, -0.1, -0.15), "C")
	E(V3(0.42, 0.5, 0.45), p + V3(0, -0.5, -0.3), "C")
	E(V3(0.36, 0.4, 0.4), p + V3(0, -0.85, -0.38), "C")
end

X.fangs = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 1.3
	for _, s in ipairs({ -1, 1 }) do
		local p = faceAt(a, s * 0.14, y, 0.02)
		Tri(CF(p) * ANG(0, 0, rad(180)), 0.14, 0.22, 0.08, WHITE)
	end
end

X.teeth = function(look, a)
	local y = -a.hs.Y * 0.25
	for i = -2, 2 do
		local p = faceAt(a, i * 0.17, y, 0.02)
		Tri(CF(p) * ANG(0, 0, rad(180)), 0.14, 0.18, 0.08, WHITE)
	end
end

local function wing(s, root, len, h, color, opts, spread)
	local cf = CF(root) * ANG(rad(-10), rad(s * -15), rad(s * (spread or 25))) * CF(s * len / 2, 0, 0.1)
	return E(V3(len, h, 0.14), cf, color, opts)
end

X.wings_bat = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local root = V3(s * a.side * 0.8, a.wingY + 0.2, a.bodyC.Z + 0.15)
		wing(s, root, 2.0, 1.1, "C2", nil, 22)
		local tip = root + V3(s * 1.8, 0.85, 0.1)
		Cyl(root, tip, 0.14, "Cd")
		for k = 1, 2 do
			Cyl(root + V3(s * 0.6 * k, 0.25 * k, 0.05), root + V3(s * (0.75 + 0.55 * k), -0.35, 0.1), 0.08, "Cd")
		end
	end
end

X.wings_feather = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local root = V3(s * a.side * 0.8, a.wingY + 0.25, a.bodyC.Z + 0.2)
		wing(s, root, 1.9, 0.9, "C", nil, 30)
		wing(s, root + V3(0, -0.2, 0.08), 1.6, 0.75, "C2", nil, 15)
		wing(s, root + V3(0, -0.35, 0.16), 1.25, 0.6, "Cd", nil, 2)
	end
end

X.wings_crystal = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local root = V3(s * a.side * 0.6, a.wingY + 0.3, a.bodyC.Z + 0.1)
		local opts = { Material = "Glass", Transparency = 0.35 }
		wing(s, root, 1.7, 0.95, "C2", opts, 35)
		wing(s, root + V3(0, -0.15, 0.25), 1.3, 0.7, "C2", opts, 5)
	end
end

X.flippers = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		E(V3(0.3, 1.0, 0.6), CF(s * (a.side + 0.05), a.wingY - 0.2, a.bodyC.Z) * ANG(0, 0, rad(s * 25)), "C")
	end
end

X.crest_small = function(look, a)
	for k = 0, 2 do
		Tri(CF(a.top + V3(0, 0.1, k * 0.3 - 0.2)) * ANG(rad(-20), rad(90), 0), 0.35, 0.4 - k * 0.07, 0.1, "C3")
	end
end

X.crest_long = function(look, a)
	Tri(CF(a.top + V3(0, 0.2, 0.55)) * ANG(rad(-55), rad(90), 0), 0.5, 1.3, 0.14, "C2")
end

X.beak = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 0.95
	local p = faceAt(a, 0, y, -0.05)
	Cone(p, V3(0, -0.15, -1), 0.5, 0.42, Color3.fromRGB(255, 170, 50))
end

X.beak_long = function(look, a)
	local y = (a.eyeYabs or 0) - (a.eyeSize or 0.3) * 0.9
	local p = faceAt(a, 0, y, -0.05)
	Cone(p, V3(0, -0.1, -1), 1.3, 0.42, Color3.fromRGB(255, 190, 90))
end

X.belly = function() end

X.scarf = function(look, a)
	local red = Color3.fromRGB(230, 60, 70)
	local y = a.hc.Y - a.hs.Y * 0.15
	E(V3(a.hs.X * 2.05, 0.36, a.hs.Z * 2.0), V3(0, y, a.hc.Z), red)
	E(V3(0.36, 0.7, 0.18), CF(0.35, y - 0.35, a.hc.Z + a.hs.Z * 0.95) * ANG(0, 0, rad(10)), red)
end

X.helmet = function(look, a)
	local yellow = Color3.fromRGB(255, 200, 40)
	E(V3(a.hs.X * 1.6, a.hs.Y * 1.0, a.hs.Z * 1.6), a.top + V3(0, -0.1, 0), yellow)
	E(V3(a.hs.X * 1.9, 0.12, a.hs.Z * 1.9), a.top + V3(0, -0.35, -0.05), yellow)
	E(V3(0.36, 0.36, 0.2), faceAt(a, 0, a.hs.Y * 0.75, 0.02) + V3(0, 0.05, -0.1), Color3.fromRGB(255, 250, 200), { Material = "Neon" })
end

X.fur_top = function(look, a)
	for i = -1, 1 do
		E(V3(0.45, 0.55, 0.45), CF(a.top + V3(i * 0.2, 0.05, i * 0.05)) * ANG(rad(-15), 0, rad(i * -20)), "C2")
	end
end

local SPOT_PTS = { { 0.4, 0.75, -0.2 }, { -0.5, 0.6, 0.3 }, { 0.15, 0.9, 0.55 }, { -0.25, 0.85, -0.45 }, { 0.6, 0.4, 0.45 } }
local function spots(a, glow)
	local bc, bs = a.bodyC, a.bodyS
	for _, p in ipairs(SPOT_PTS) do
		local pos = bc + V3(p[1] * bs.X, p[2] * bs.Y, p[3] * bs.Z)
		local n = (pos - bc)
		local cf = CF(pos, pos + n)
		E(V3(0.4, 0.32, 0.14), cf, glow and "C2" or "C3", glow and { Material = "Neon" } or nil)
	end
end
X.spots = function(look, a) spots(a, false) end
X.spots_glow = function(look, a) spots(a, true) end

X.stripes = function(look, a)
	local bc, bs = a.bodyC, a.bodyS
	for k = -1, 1 do
		E(V3(bs.X * 1.7, 0.18, 0.28), CF(bc + V3(0, bs.Y * 0.82, k * bs.Z * 0.45)) * ANG(0, 0, 0), "C3")
	end
	E(V3(0.6, 0.14, 0.24), a.top + V3(0, 0.02, 0.1), "C3")
end

X.stripe_head = function(look, a)
	E(V3(0.36, a.hs.Y * 2.05, a.hs.Z * 2.05), a.hc + V3(0, 0.03, -0.02), "C2")
end

X.frills = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		Tri(CF(a.hc + V3(s * a.hs.X * 0.95, 0, 0.1)) * ANG(0, rad(s * 70), rad(s * -60)), 0.7, 0.6, 0.1, "C2")
	end
end

X.cracks_glow = function(look, a)
	local bc, bs = a.bodyC, a.bodyS
	local lines = { { 0.5, 0.55, -0.3, 30 }, { -0.55, 0.45, 0.2, -40 }, { 0.1, 0.92, 0.3, 80 }, { -0.2, 0.6, -0.7, 10 } }
	for _, l in ipairs(lines) do
		local pos = bc + V3(l[1] * bs.X, l[2] * bs.Y, l[3] * bs.Z)
		local cf = CF(pos, pos + (pos - bc)) * ANG(0, 0, rad(l[4]))
		B(V3(0.1, 0.6, 0.1), cf, "C2", { Material = "Neon" })
	end
end

X.shoulder_lava = function(look, a)
	for _, p in ipairs(a.shoulders or {}) do
		E(V3(0.7, 0.45, 0.7), p + V3(0, 0.1, 0), "C2", { Material = "Neon" })
	end
end

X.drips = function(look, a)
	for i, x in ipairs({ -0.6, 0.1, 0.65 }) do
		E(V3(0.3, 0.45, 0.3), a.hc + V3(x, -a.hs.Y * 0.75, -a.hs.Z * 0.6), "C", { Transparency = 0.15 })
	end
end

X.inner_core = function(look, a)
	E(V3(0.9, 0.9, 0.9), a.bodyC + V3(0, -0.15, 0.2), "C2", { Material = "Neon" })
end

X.flame = function(look, a)
	local base = a.top
	local cols = { "C2", Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 255, 240) }
	local sizes = { 0.75, 0.5, 0.28 }
	for i = 1, 3 do
		E(V3(sizes[i], sizes[i] * 1.5, sizes[i]), CF(base + V3(0, 0.15 + (i - 1) * 0.32, 0.18 * i)) * ANG(rad(-20 * i), 0, 0), cols[i], { Material = "Neon", Transparency = 0.05 })
	end
end

X.arms_small = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		E(V3(0.42, 0.42, 0.75), CF(a.bodyC + V3(s * (a.side + 0.05), -0.15, -0.2)) * ANG(rad(25), 0, rad(s * 20)), "C")
	end
end

X.hood = function(look, a)
	E(V3(a.hs.X * 2.2, a.hs.Y * 1.6, a.hs.Z * 1.8), a.hc + V3(0, a.hs.Y * 0.35, a.hs.Z * 0.35), "Cd")
	Tri(CF(a.top + V3(0, 0.35, 0.45)) * ANG(rad(-35), rad(90), 0), 0.6, 0.8, 0.2, "Cd")
end

X.crown = function(look, a)
	local gold = Color3.fromRGB(255, 210, 60)
	local base = a.top + V3(0, 0.05, 0)
	E(V3(1.0, 0.18, 1.0), base, gold, { Material = "Metal" })
	for i = 0, 4 do
		local ang = i * math.pi * 2 / 5
		local p = base + V3(math.cos(ang) * 0.42, 0.22, math.sin(ang) * 0.42)
		Tri(CF(p, base + V3(0, 0.22, 0)) * ANG(0, rad(180), 0), 0.24, 0.4, 0.08, gold, { Material = "Metal" })
	end
	E(V3(0.2, 0.2, 0.2), base + V3(0, 0.15, -0.48), Color3.fromRGB(255, 60, 120), { Material = "Neon" })
end

local function ring(center, radius, n, size, color, tilt, opts)
	for i = 0, n - 1 do
		local ang = i * math.pi * 2 / n
		local off = V3(math.cos(ang) * radius, 0, math.sin(ang) * radius)
		local p = (CF(center) * tilt):PointToWorldSpace(off)
		E(V3(size, size * 0.8, size), p, color, opts)
	end
end

X.halo = function(look, a)
	ring(a.top + V3(0, 0.6, 0.1), 0.62, 12, 0.24, Color3.fromRGB(255, 236, 140), ANG(rad(-12), 0, 0), { Material = "Neon" })
end

X.rings = function(look, a)
	ring(a.bodyC, math.max(a.bodyS.X, a.bodyS.Z) + 0.5, 16, 0.22, "C2", ANG(rad(18), 0, rad(-14)), { Material = "Neon" })
end
X.ring_self = X.rings

X.shards = function(look, a)
	for i = 0, 2 do
		local ang = i * math.pi * 2 / 3
		local p = a.hc + V3(math.cos(ang) * 1.35, -0.2 + i * 0.3, math.sin(ang) * 1.35)
		crystal(p, 0.55, ANG(rad(20), ang, rad(15)), "C2")
	end
end

X.eye_single = function(look, a)
	local p = faceAt(a, 0, a.hs.Y * 0.05, 0.05)
	E(V3(1.25, 1.25, 0.5), p, WHITE)
	E(V3(0.8, 0.8, 0.35), p + V3(0, 0, -0.12), "C2", { Material = "Neon" })
	E(V3(0.36, 0.55, 0.25), p + V3(0, 0, -0.22), INK)
	E(V3(0.16, 0.16, 0.1), p + V3(0.18, 0.2, -0.3), WHITE)
end

X.tentacles = function(look, a)
	for i = 0, 3 do
		local ang = i * math.pi / 2 + math.pi / 4
		local p0 = a.hc + V3(math.cos(ang) * 0.5, -a.hs.Y * 0.8, math.sin(ang) * 0.5)
		local p1 = p0 + V3(math.cos(ang) * 0.25, -0.5, math.sin(ang) * 0.25)
		local p2 = p1 + V3(math.cos(ang) * -0.15, -0.4, math.sin(ang) * -0.15)
		Cyl(p0, p1, 0.2, "C")
		Cyl(p1, p2, 0.14, "C2")
	end
end

X.star_points = function(look, a)
	for i = 0, 4 do
		local ang = rad(90 + i * 72)
		local dir = V3(math.cos(ang), math.sin(ang), 0)
		local p = a.hc + dir * (a.hs.X * 0.95)
		local cf = CF(p) * ANG(0, 0, ang - rad(90))
		Tri(cf * CF(0, 0.35, 0), 0.65, 0.75, 0.5, "C", { Material = "Neon" })
	end
end

X.stars = function(look, a)
	local bc, bs = a.bodyC, a.bodyS
	for i, p in ipairs(SPOT_PTS) do
		local pos = bc + V3(p[1] * bs.X * 1.02, p[2] * bs.Y * 1.02, p[3] * bs.Z * 1.02)
		E(V3(0.16, 0.16, 0.16), pos, Color3.fromRGB(255, 255, 230), { Material = "Neon" })
	end
end

X.sparkle = function(look, a)
	MK.Sparkles(ctx.root, ctx.C2, 5, 0.3)
end

X.glow = function(look, a)
	MK.Light(ctx.root, ctx.C2, 9, 1.4)
end

X.leaf = function(look, a)
	local green = Color3.fromRGB(100, 200, 70)
	Cyl(a.top, a.top + V3(0, 0.35, 0.05), 0.1, Color3.fromRGB(90, 140, 60))
	E(V3(0.7, 0.12, 0.42), CF(a.top + V3(0.3, 0.42, 0)) * ANG(0, 0, rad(25)), green)
	E(V3(0.55, 0.12, 0.34), CF(a.top + V3(-0.22, 0.36, 0.05)) * ANG(0, rad(30), rad(-30)), green)
end

X.flowers = function(look, a)
	local cols = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 255, 255) }
	for i, x in ipairs({ -0.55, 0.6 }) do
		local p = a.hc + V3(x, a.hs.Y * 0.7, 0.2)
		for k = 0, 4 do
			local ang = k * math.pi * 2 / 5
			E(V3(0.16, 0.08, 0.16), p + V3(math.cos(ang) * 0.12, 0.05, math.sin(ang) * 0.12), cols[i])
		end
		E(V3(0.1, 0.1, 0.1), p + V3(0, 0.08, 0), Color3.fromRGB(255, 220, 60))
	end
end

X.extra_heads = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local base = a.back + V3(s * 0.4, -0.2, 0.2)
		local hp = base + V3(s * 0.9, 0.8, -0.5)
		Cyl(base, hp, 0.42, "C")
		E(V3(0.9, 0.8, 0.95), hp, "C")
		for _, e in ipairs({ -1, 1 }) do
			E(V3(0.16, 0.18, 0.1), hp + V3(e * 0.2, 0.1, -0.44), MK.C(look.EyeColor or { 255, 230, 100 }), { Material = "Neon" })
		end
	end
end

X.clock_face = function(look, a)
	local p = a.bodyC + V3(0, 0.1, -a.bodyS.Z - 0.05)
	MK.Cylinder(ctx.model, 0.1, 0.9, CF(p) * ANG(0, rad(90), 0), ctx.C2):SetAttribute("Paint", "Fixed")
	B(V3(0.06, 0.32, 0.04), CF(p + V3(0, 0.14, -0.07)), WHITE, { Material = "Neon" })
	B(V3(0.22, 0.06, 0.04), CF(p + V3(0.1, 0, -0.07)), WHITE, { Material = "Neon" })
end

X.bolts = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		E(V3(0.12, 0.26, 0.26), a.bodyC + V3(s * (a.bodyS.X + 0.02), 0.1, 0), "C3", { Material = "Metal" })
	end
end

X.feelers = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local p0 = faceAt(a, s * 0.3, -a.hs.Y * 0.2, 0)
		local p1 = p0 + V3(s * 0.2, -0.3, -0.5)
		local p2 = p1 + V3(s * -0.05, 0.25, -0.35)
		Cyl(p0, p1, 0.16, "C2")
		Cyl(p1, p2, 0.12, "C2")
	end
end

X.segments = function(look, a)
	local bc, bs = a.bodyC, a.bodyS
	for k = -2, 2 do
		E(V3(bs.X * 2.05, bs.Y * 0.6, 0.16), bc + V3(0, bs.Y * 0.55, k * bs.Z * 0.38), "Cd")
	end
end

X.pincers = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local p0 = a.hc + V3(s * a.hs.X * 0.8, -0.05, -0.1)
		local p1 = p0 + V3(s * 0.45, 0.05, -0.6)
		Cyl(p0, p1, 0.22, "C")
		E(V3(0.55, 0.42, 0.75), p1 + V3(0, 0, -0.3), "C")
		Tri(CF(p1 + V3(s * -0.1, 0.05, -0.7)) * ANG(rad(-90), 0, 0), 0.22, 0.35, 0.12, "C2")
	end
end

X.stinger = function(look, a)
	local p0 = a.tail
	local p1 = p0 + V3(0, 0.75, 0.45)
	local p2 = p1 + V3(0, 0.75, -0.1)
	local p3 = p2 + V3(0, 0.35, -0.55)
	Cyl(p0, p1, 0.36, "C")
	Cyl(p1, p2, 0.3, "C")
	Cyl(p2, p3, 0.26, "C")
	Cone(p3, V3(0, -0.35, -1), 0.5, 0.3, "C2", { Material = "Neon" })
end

X.antennae = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		local p0 = a.hc + V3(s * a.hs.X * 0.35, a.hs.Y * 0.8, -0.05)
		local p1 = p0 + V3(s * 0.3, 0.6, -0.25)
		Cyl(p0, p1, 0.08, INK)
		E(V3(0.2, 0.2, 0.2), p1, "C2")
	end
end

X.tiny_arms = function(look, a)
	for _, s in ipairs({ -1, 1 }) do
		E(V3(0.22, 0.22, 0.5), CF(s * 0.5, 1.35, -0.75) * ANG(rad(40), 0, 0), "C")
	end
end

X.long_neck = function() end
X.big_head = function() end

X.fins = function(look, a)
	for i, s in ipairs(a.segs or {}) do
		if i <= 3 then
			Tri(CF(s[1] + V3(0, s[2] * 0.5, 0)) * ANG(rad(-30), rad(90), 0), 0.5, 0.45, 0.1, "C2", { Material = "Glass", Transparency = 0.1 })
		end
	end
end

---------------------------------------------------------------------------------------------
-- Публичный API
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Мифики: огромные крылья, рога, пламя, ауры, нимбы, светящиеся грани
---------------------------------------------------------------------------------------------
local function mc(t, fallback)
	if t == nil then
		return fallback
	end
	return MK.C(t)
end

-- одно «перо»/лопасть крыла: плоский эллипсоид от точки root под углами
local function blade(root, s, len, h, yaw, roll, color, opts)
	local cf = CF(root) * ANG(0, rad(s * yaw), rad(s * roll)) * CF(s * len / 2, 0, 0)
	return E(V3(len, h, 0.16), cf, color, opts)
end

local WINGS = {}
-- крылья демона: перепонки-треугольники с неоновыми кромками
WINGS.demon = function(a, m, s, root)
	local dark, edge = mc(m.C1, ctx.C3), mc(m.Glow, ctx.C2)
	-- перепонка
	local mem = CF(root) * ANG(rad(-8), rad(s * -18), rad(s * 18)) * CF(s * 1.9, 0.35, 0.05)
	E(V3(3.8, 2.4, 0.14), mem, dark)
	E(V3(3.2, 1.7, 0.16), mem * CF(s * 0.1, -0.05, -0.02), dark:Lerp(edge, 0.25))
	-- «кости» крыла с неоном
	for k = 0, 2 do
		local tip = (mem * CF(s * (1.9 - k * 0.2), 1.2 - k * 1.05, 0)).Position
		Cyl(root, tip, 0.18 - k * 0.03, edge, { Material = "Neon" })
	end
	local top = (mem * CF(s * 1.9, 1.2, 0)).Position
	Cone(top, V3(s * 0.5, 1, 0.1), 0.9, 0.32, edge, { Material = "Neon" })
end
-- ангельские крылья: слои белых/золотых перьев
WINGS.angel = function(a, m, s, root)
	local c1, c2 = mc(m.C1, WHITE), mc(m.C2, GOLD)
	for layer = 0, 2 do
		for k = 0, 4 do
			local len = 2.9 - layer * 0.7 - k * 0.18
			local col = (layer == 1) and c2 or c1
			blade(root + V3(0, -layer * 0.25, layer * 0.12), s, len, 0.62, -15, 62 - k * 16 - layer * 4, col, layer == 1 and { Material = "Neon", Transparency = 0.15 } or nil)
		end
	end
end
-- крылья бабочки: две большие лопасти с узорами
WINGS.butterfly = function(a, m, s, root)
	local c1, c2, c3 = mc(m.C1, ctx.C), mc(m.C2, ctx.C2), mc(m.Glow, GOLD)
	local up = CF(root) * ANG(rad(-8), rad(s * -20), rad(s * 32)) * CF(s * 1.7, 0.3, 0)
	E(V3(3.4, 2.6, 0.14), up, c1)
	E(V3(2.6, 1.9, 0.16), up * CF(s * 0.15, 0.05, -0.02), c2)
	E(V3(0.9, 0.9, 0.18), up * CF(s * 0.6, 0.3, -0.04), c3, { Material = "Neon" })
	E(V3(0.5, 0.5, 0.2), up * CF(s * -0.3, -0.45, -0.05), c3, { Material = "Neon" })
	local low = CF(root) * ANG(rad(-8), rad(s * -20), rad(s * -22)) * CF(s * 1.3, -0.3, 0.05)
	E(V3(2.5, 1.7, 0.14), low, c1)
	E(V3(1.8, 1.1, 0.16), low * CF(s * 0.1, 0, -0.02), c3, { Material = "Neon", Transparency = 0.2 })
end
-- кристальные крылья
WINGS.crystal = function(a, m, s, root)
	local c1 = mc(m.Glow, ctx.C2)
	for k = 0, 4 do
		local len = 1.6 + k * 0.5
		local cf = CF(root) * ANG(rad(-10), rad(s * -15), rad(s * (70 - k * 22))) * CF(s * len / 2, 0, 0) * ANG(rad(45), 0, 0)
		B(V3(len, 0.42, 0.42), cf, c1, { Material = "Glass", Transparency = 0.25 })
		B(V3(len * 0.6, 0.18, 0.18), cf, c1, { Material = "Neon" })
	end
end
-- огненные крылья
WINGS.flame = function(a, m, s, root)
	local c1, c2 = mc(m.C1, Color3.fromRGB(255, 90, 30)), mc(m.Glow, Color3.fromRGB(255, 220, 80))
	for k = 0, 4 do
		local len = 3.2 - k * 0.35
		blade(root, s, len, 0.7, -15, 66 - k * 20, (k % 2 == 0) and c1 or c2, { Material = "Neon", Transparency = 0.1 })
	end
end

-- королевские крылья: три слоя перьев — длинные светлые, золотые и короткие с неоновым кантом
WINGS.royal = function(a, m, s, root)
	local c1, c2, c3 = mc(m.C1, WHITE), mc(m.C2, GOLD), mc(m.Glow, ctx.C2)
	for k = 0, 5 do
		blade(root, s, 3.5 - k * 0.32, 0.74, -14, 80 - k * 17, c1)
	end
	for k = 0, 4 do
		blade(root + V3(0, -0.08, -0.1), s, 2.6 - k * 0.26, 0.62, -14, 72 - k * 18, c2, { Material = "Metal" })
	end
	for k = 0, 3 do
		blade(root + V3(0, -0.14, -0.2), s, 1.6 - k * 0.16, 0.5, -14, 66 - k * 21, c3, { Material = "Neon", Transparency = 0.1 })
	end
	E(V3(0.75, 0.75, 0.55), root, c2, { Material = "Metal" })
end
local RAINBOW7 = {
	Color3.fromRGB(255, 92, 120), Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 228, 90), Color3.fromRGB(110, 226, 120),
	Color3.fromRGB(90, 196, 255), Color3.fromRGB(140, 120, 255), Color3.fromRGB(226, 120, 255),
}
-- радужные крылья: веер из перьев всех цветов и тонкие светящиеся «жилки»
WINGS.rainbow = function(a, m, s, root)
	for k = 0, 6 do
		local col = RAINBOW7[k + 1]
		blade(root, s, 3.4 - k * 0.2, 0.7, -14, 84 - k * 15, col)
		blade(root + V3(0, 0, -0.06), s, 2.3 - k * 0.12, 0.2, -14, 84 - k * 15, col:Lerp(WHITE, 0.45), { Material = "Neon", Transparency = 0.15 })
	end
	E(V3(0.7, 0.7, 0.5), root, WHITE)
end
-- крылья феникса: огненный веер в три слоя (красный -> оранжевый -> жёлтый), кончики светятся
WINGS.phoenix = function(a, m, s, root)
	local cols = { Color3.fromRGB(230, 50, 30), Color3.fromRGB(255, 130, 30), Color3.fromRGB(255, 220, 80) }
	for layer = 0, 2 do
		for k = 0, 5 - layer do
			local len = 3.1 - layer * 0.7 - k * 0.2
			blade(root + V3(0, -layer * 0.12, -layer * 0.1), s, len, 0.68 - layer * 0.08, -12, 82 - k * 17 - layer * 3, cols[layer + 1], layer == 2 and { Material = "Neon", Transparency = 0.05 } or nil)
		end
	end
	for k = 0, 3 do
		local cf = CF(root) * ANG(0, rad(s * -12), rad(s * (82 - k * 17))) * CF(s * (2.95 - k * 0.2), 0, 0)
		E(V3(0.5, 0.36, 0.2), cf, Color3.fromRGB(255, 240, 150), { Material = "Neon" })
	end
end
-- галактические крылья: тёмная перепонка, звёзды и светящаяся кромка
WINGS.galaxy = function(a, m, s, root)
	local dark, edge = mc(m.C1, Color3.fromRGB(30, 24, 80)), mc(m.Glow, Color3.fromRGB(120, 220, 255))
	local mem = CF(root) * ANG(rad(-8), rad(s * -18), rad(s * 24)) * CF(s * 2.0, 0.4, 0.05)
	E(V3(4.0, 2.6, 0.14), mem, dark)
	E(V3(3.3, 1.9, 0.16), mem * CF(s * 0.1, -0.05, -0.02), dark:Lerp(Color3.fromRGB(150, 80, 220), 0.45))
	for k = 0, 2 do
		local tip = (mem * CF(s * (2.0 - k * 0.25), 1.3 - k * 1.1, 0)).Position
		Cyl(root, tip, 0.16 - k * 0.03, edge, { Material = "Neon" })
	end
	for i = 1, 7 do
		local x, y = ((ctx.hash * i) % 7) / 7 - 0.5, ((ctx.hash * i * 3) % 5) / 5 - 0.5
		E(V3(0.16, 0.16, 0.2), mem * CF(s * x * 2.6, y * 1.6, -0.06), (i % 3 == 0) and edge or WHITE, { Material = "Neon" })
	end
end

-- лепестковые крылья: веер из розовых и белых лепестков с золотыми прожилками
WINGS.petal = function(a, m, s, root)
	local c1, c2, c3 = mc(m.C1, Color3.fromRGB(255, 160, 200)), mc(m.C2, WHITE), mc(m.Glow, GOLD)
	for k = 0, 5 do
		local cf = CF(root) * ANG(0, rad(s * -14), rad(s * (82 - k * 17))) * CF(s * (1.5 - k * 0.05), 0, 0)
		E(V3(3.0 - k * 0.18, 1.15 - k * 0.05, 0.14), cf, (k % 2 == 0) and c1 or c2)
		E(V3(2.2 - k * 0.15, 0.16, 0.16), cf * CF(0, 0, -0.04), c3, { Material = "Neon", Transparency = 0.25 })
	end
	for k = 0, 3 do
		local cf = CF(root + V3(0, -0.15, -0.1)) * ANG(0, rad(s * -14), rad(s * (70 - k * 22))) * CF(s * 1.0, 0, 0)
		E(V3(1.9, 0.8, 0.16), cf, c1:Lerp(WHITE, 0.4))
	end
	E(V3(0.6, 0.6, 0.45), root, c3, { Material = "Metal" })
end

local HORNS = {}
-- изогнутые рога из цепочки цилиндров
HORNS.curved = function(a, m, s)
	local col = mc(m.HornColor, Color3.fromRGB(40, 34, 48))
	local glow = mc(m.Glow, ctx.C2)
	local p = a.top + V3(s * a.hs.X * 0.55, -0.15, 0.1)
	local dir = V3(s * 0.6, 1, 0.25).Unit
	local d = 0.62
	for k = 1, 4 do
		local q = p + dir * 0.55
		Cyl(p, q, d, k < 4 and col or glow, k == 4 and { Material = "Neon" } or nil)
		p = q
		dir = (dir + V3(s * 0.25, -0.15, 0.25)).Unit
		d = d * 0.78
	end
end
HORNS.straight = function(a, m, s)
	Cone(a.top + V3(s * a.hs.X * 0.5, -0.1, 0), V3(s * 0.35, 1, 0.1), 1.6, 0.45, mc(m.HornColor, GOLD), { Material = "Metal" })
end
HORNS.unicorn = function(a, m, s)
	if s < 0 then
		Cone(a.top + V3(0, -0.1, -a.hs.Z * 0.45), V3(0, 1, -0.35), 1.9, 0.5, mc(m.HornColor, GOLD), { Material = "Neon" })
	end
end

local function mythicFx(look, a)
	local m = look.Mythic
	local glow = mc(m.Glow, ctx.C2)
	-- светящиеся «швы» по рёбрам куба
	if a.flat and m.Trim ~= false then
		local h = a.hs
		for _, sx in ipairs({ -1, 1 }) do
			B(V3(0.14, h.Y * 1.5, 0.14), CF(a.hc + V3(sx * (h.X + 0.02), 0, -(h.Z + 0.02))), glow, { Material = "Neon" })
		end
		B(V3(h.X * 1.5, 0.14, 0.14), CF(a.hc + V3(0, h.Y + 0.02, -(h.Z + 0.02))), glow, { Material = "Neon" })
	end
	-- самоцвет на лбу
	if m.Gem ~= false then
		local g = faceAt(a, 0, a.hs.Y * 0.62, 0.05)
		B(V3(0.38, 0.38, 0.2), CF(g) * ANG(0, 0, rad(45)), glow, { Material = "Neon" })
	end
	-- крылья
	local wf = WINGS[m.Wings or ""]
	if wf then
		for _, s in ipairs({ -1, 1 }) do
			wf(a, m, s, V3(s * a.side * 0.75, a.wingY + 0.45, a.bodyC.Z + a.bodyS.Z * 0.6))
		end
	end
	-- рога
	local hf = HORNS[m.Horns or ""]
	if hf then
		for _, s in ipairs({ -1, 1 }) do
			hf(a, m, s)
		end
	end
	-- нимб
	if m.Halo then
		ring(a.top + V3(0, 0.9, 0.15), 0.85, 16, 0.26, mc(m.HaloColor, Color3.fromRGB(255, 236, 140)), ANG(rad(-14), 0, 0), { Material = "Neon" })
	end
	-- корона
	if m.Crown then
		X.crown(look, a)
	end
	-- парящие кристаллы-спутники
	if m.Orbit then
		for i = 0, 3 do
			local ang = i * math.pi / 2 + 0.4
			local p = a.hc + V3(math.cos(ang) * (a.hs.X + 1.1), 0.3 + (i % 2) * 0.7, math.sin(ang) * (a.hs.Z + 1.1))
			B(V3(0.42, 0.7, 0.42), CF(p) * ANG(rad(20), ang, rad(15)) * ANG(0, rad(45), 0), glow, { Material = "Neon" })
		end
	end
	-- хвост-пламя
	if m.FlameTail then
		local t = a.tail
		for k = 0, 2 do
			E(V3(0.7 - k * 0.15, 0.9 - k * 0.2, 0.7 - k * 0.15), t + V3(0, 0.3 + k * 0.45, 0.35 + k * 0.25), (k % 2 == 0) and glow or ctx.C2, { Material = "Neon", Transparency = 0.1 })
		end
	end
	-- пламя, свет и частицы (всё встроенное в Roblox)
	if m.Fire then
		local f = Instance.new("Fire")
		f.Color = mc(m.Fire, Color3.fromRGB(255, 120, 30))
		f.SecondaryColor = mc(m.Fire2, Color3.fromRGB(255, 220, 80))
		f.Size = 4
		f.Heat = 6
		f.Parent = ctx.root
	end
	MK.Light(ctx.root, glow, 12, 2)
	local e = MK.Sparkles(ctx.root, { 255, 255, 255 }, 12, 0.45)
	e.Color = ColorSequence.new(glow, ctx.C2)
	e.Name = "MythicAura"
	if m.Smoke then
		local sm = Instance.new("ParticleEmitter")
		sm.Texture = "rbxasset://textures/particles/smoke_main.dds"
		sm.Color = ColorSequence.new(mc(m.Smoke, Color3.fromRGB(60, 40, 80)))
		sm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		sm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		sm.Lifetime = NumberRange.new(1, 1.8)
		sm.Speed = NumberRange.new(0.5, 1.5)
		sm.Rate = 6
		sm.SpreadAngle = Vector2.new(180, 180)
		sm.LightEmission = 0.3
		sm.Parent = ctx.root
	end
end

---------------------------------------------------------------------------------------------
-- «Огромные» питомцы: аура-пьедестал, облако, бант, мантия, радужная грива и хвост,
-- ледяная корона, самоцвет на груди, звёзды-спутники. Всё из примитивов Roblox.
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Сказочные детали (Сказочное яйцо)
---------------------------------------------------------------------------------------------
local FLOWER_COLS = { Color3.fromRGB(255, 130, 180), WHITE, Color3.fromRGB(255, 214, 90), Color3.fromRGB(190, 150, 255) }
local function flower(pos, size, col, up)
	local cf = CF(pos) * (up or ANG(0, 0, 0))
	for k = 0, 4 do
		local ang = k * math.pi * 2 / 5
		E(V3(size * 0.62, size * 0.22, size * 0.62), cf * CF(math.cos(ang) * size * 0.42, 0, math.sin(ang) * size * 0.42), col)
	end
	E(V3(size * 0.42, size * 0.3, size * 0.42), cf * CF(0, size * 0.08, 0), Color3.fromRGB(255, 214, 80))
end

-- шляпка мухомора: большая красная шляпка с белыми пятнами на коротком «пеньке»
X.mushroom_hat = function(look, a)
	local cap = mc(look.HatColor, Color3.fromRGB(235, 60, 60))
	local top = a.top + V3(0, -0.05, 0.05)
	E(V3(0.9, 0.5, 0.9), top + V3(0, 0.15, 0), IVORY)
	E(V3(a.hs.X * 2.35, 1.0, a.hs.Z * 2.3), top + V3(0, 0.55, 0), cap)
	E(V3(a.hs.X * 2.1, 0.3, a.hs.Z * 2.05), top + V3(0, 0.22, 0), MK.Shade(cap, -0.25))
	-- белые пятна прямо на поверхности шляпки (эллипсоид: полуоси rx, 0.5, rz)
	local rx, rz = a.hs.X * 1.175, a.hs.Z * 1.15
	local spots = { { -0.55, -0.35, 0.46 }, { 0.6, -0.2, 0.4 }, { 0.05, 0.1, 0.48 }, { -0.2, -0.85, 0.36 }, { 0.7, 0.5, 0.34 }, { -0.75, 0.45, 0.32 }, { 0.3, -0.75, 0.3 } }
	for _, sp in ipairs(spots) do
		local k = 1 - (sp[1] / rx) ^ 2 - (sp[2] / rz) ^ 2
		if k > 0.05 then
			local y = 0.55 + 0.5 * math.sqrt(k)
			E(V3(sp[3], sp[3] * 0.4, sp[3]), top + V3(sp[1], y - 0.04, sp[2]), WHITE)
		end
	end
end

-- венок из цветов по краю макушки
X.flower_crown = function(look, a)
	local n = 7
	local leaf = Color3.fromRGB(110, 200, 90)
	for i = 0, n - 1 do
		local ang = i / n * math.pi * 2 + 0.2
		local p = a.top + V3(math.cos(ang) * a.hs.X * 0.82, 0.08, math.sin(ang) * a.hs.Z * 0.82)
		E(V3(0.36, 0.14, 0.24), CF(p + V3(0, -0.05, 0)) * ANG(0, -ang, 0) * CF(0.18, 0, 0), leaf)
		flower(p, 0.5, FLOWER_COLS[i % #FLOWER_COLS + 1], ANG(rad(math.sin(ang) * 18), 0, rad(-math.cos(ang) * 18)))
	end
end

-- крылья феи: две пары полупрозрачных крыльев-бабочки с неоновой кромкой
X.fairy_wings = function(look, a)
	local c = mc(look.WingColor, ctx.C2)
	local edge = mc(look.WingEdge, Color3.fromRGB(255, 240, 255))
	for _, sd in ipairs({ -1, 1 }) do
		local root = V3(sd * a.side * 0.55, a.wingY + 0.3, a.bodyC.Z + a.bodyS.Z * 0.75)
		local up = CF(root) * ANG(rad(-10), rad(sd * -25), rad(sd * 38)) * CF(sd * 1.05, 0.15, 0)
		E(V3(2.1, 1.4, 0.1), up, edge, { Material = "Neon", Transparency = 0.35 })
		E(V3(1.95, 1.25, 0.12), up * CF(0, 0, -0.02), c, { Material = "Glass", Transparency = 0.25 })
		E(V3(0.5, 0.5, 0.14), up * CF(sd * 0.35, 0.15, -0.04), WHITE, { Material = "Neon", Transparency = 0.2 })
		local low = CF(root) * ANG(rad(-10), rad(sd * -25), rad(sd * -18)) * CF(sd * 0.8, -0.1, 0.05)
		E(V3(1.4, 0.95, 0.1), low, edge, { Material = "Neon", Transparency = 0.35 })
		E(V3(1.28, 0.84, 0.12), low * CF(0, 0, -0.02), c:Lerp(WHITE, 0.3), { Material = "Glass", Transparency = 0.25 })
	end
end

-- рога из хрусталя
X.crystal_antlers = function(look, a)
	local col = mc(look.AntlerColor, Color3.fromRGB(170, 230, 255))
	for _, sd in ipairs({ -1, 1 }) do
		local base = a.top + V3(sd * a.hs.X * 0.45, -0.05, 0.1)
		crystal(base, 1.1, ANG(rad(-8), 0, rad(sd * -22)), col)
		crystal(base + V3(sd * 0.32, 0.25, 0.05), 0.65, ANG(rad(-5), 0, rad(sd * -55)), col)
		crystal(base + V3(sd * 0.05, 0.35, -0.1), 0.5, ANG(rad(-35), 0, rad(sd * -10)), col)
	end
end

-- панцирь-купол на спине с узором, сверху мох, цветы и грибок
X.shell_flowers = function(look, a)
	local moss = Color3.fromRGB(110, 190, 90)
	local sh = a.top + V3(0, -0.15, 0.45)
	E(V3(a.hs.X * 2.25, 1.3, a.hs.Z * 1.9), sh, "C3")
	E(V3(a.hs.X * 2.35, 0.3, a.hs.Z * 2.0), sh + V3(0, -0.4, 0), MK.Shade(ctx.C3, -0.2))
	for i = 0, 5 do
		local ang = i / 6 * math.pi * 2
		E(V3(0.5, 0.18, 0.5), sh + V3(math.cos(ang) * 0.75, 0.42, math.sin(ang) * 0.6), MK.Shade(ctx.C3, 0.25))
	end
	local b = sh + V3(0, 0.55, 0)
	E(V3(1.4, 0.3, 1.2), b, moss)
	flower(b + V3(-0.35, 0.18, -0.15), 0.62, FLOWER_COLS[1])
	flower(b + V3(0.4, 0.15, 0.2), 0.52, FLOWER_COLS[2])
	flower(b + V3(0.05, 0.22, 0.45), 0.44, FLOWER_COLS[3])
	E(V3(0.22, 0.4, 0.22), b + V3(0.55, 0.25, -0.35), Color3.fromRGB(240, 240, 230))
	E(V3(0.5, 0.25, 0.5), b + V3(0.55, 0.48, -0.35), Color3.fromRGB(235, 70, 70))
end

-- длинные светящиеся щупальца медузы (6 штук, волной)
X.jelly_tentacles = function(look, a)
	for i = 0, 5 do
		local ang = i / 6 * math.pi * 2 + 0.3
		local p = a.hc + V3(math.cos(ang) * 0.6, -a.hs.Y * 0.75, math.sin(ang) * 0.6)
		for k = 0, 3 do
			local q = p + V3(math.sin(k + i) * 0.12, -0.38, math.cos(k + i) * 0.12)
			Cyl(p, q, 0.2 - k * 0.035, (k % 2 == 0) and "C" or "C2", (k % 2 == 1) and { Material = "Neon", Transparency = 0.1 } or { Transparency = 0.15 })
			p = q
		end
	end
	-- бахрома по краю «купола»
	for i = 0, 13 do
		local ang = i / 14 * math.pi * 2
		E(V3(0.4, 0.28, 0.4), a.hc + V3(math.cos(ang) * a.hs.X * 0.92, -a.hs.Y * 0.62, math.sin(ang) * a.hs.Z * 0.92), "C2", { Transparency = 0.2 })
	end
end

local function star4(pos, size, color, tilt)
	local cf = CF(pos) * (tilt or ANG(0, 0, 0))
	B(V3(size, size * 0.22, size * 0.22), cf, color, { Material = "Neon" })
	B(V3(size * 0.22, size, size * 0.22), cf, color, { Material = "Neon" })
	E(V3(size * 0.45, size * 0.45, size * 0.3), cf, WHITE, { Material = "Neon" })
end

local function hugeFx(look, a)
	local h = look.Huge
	local m = look.Mythic or {}
	local glow = mc(h.Aura, mc(m.Glow, ctx.C2))
	local zc = a.bodyC.Z
	local R = math.max(a.bodyS.X, a.bodyS.Z) * 1.45
	-- облако под лапами
	if h.Cloud then
		for i = 0, 7 do
			local ang = i / 8 * math.pi * 2
			E(V3(1.25, 0.75, 1.25), V3(math.cos(ang) * R * 0.75, 0.2, zc + math.sin(ang) * R * 0.75), WHITE)
		end
		E(V3(R * 1.6, 0.6, R * 1.6), V3(0, 0.18, zc), Color3.fromRGB(240, 246, 255))
	end
	-- аура-пьедестал: кольцо светящихся бусин и мягкий диск
	local n = 30
	for i = 0, n - 1 do
		local ang = i / n * math.pi * 2
		local col = h.Rainbow and RAINBOW7[i % #RAINBOW7 + 1] or glow
		E(V3(0.36, 0.12, 0.36), V3(math.cos(ang) * R, 0.06, zc + math.sin(ang) * R), col, { Material = "Neon", NoShadow = true })
	end
	local disc = MK.Disc(ctx.model, 0.05, R * 2, V3(0, 0.03, zc), glow)
	finish(disc, "Fixed", { Material = "Neon", Transparency = 0.8, NoShadow = true })
	-- цветочная поляна на пьедестале
	if h.Bloom then
		for i = 0, 9 do
			local ang = i / 10 * math.pi * 2 + 0.15
			flower(V3(math.cos(ang) * R * 0.82, 0.12, zc + math.sin(ang) * R * 0.82), 0.7, FLOWER_COLS[i % #FLOWER_COLS + 1])
		end
	end
	-- звёзды-спутники
	if h.Stars then
		for i = 0, 3 do
			local ang = i / 4 * math.pi * 2 + 0.6
			local p = a.bodyC + V3(math.cos(ang) * (R + 0.2), 0.6 + (i % 2) * 0.9, math.sin(ang) * (R + 0.2))
			star4(p, 0.45, (i % 2 == 0) and glow or Color3.fromRGB(255, 226, 120), ANG(0, ang, rad(20)))
		end
	end
	-- бант на макушке
	if h.Bow then
		local bc = mc(h.Bow, Color3.fromRGB(255, 120, 180))
		local base = a.top + V3(a.hs.X * 0.45, 0.1, -0.2)
		for _, sx in ipairs({ -1, 1 }) do
			E(V3(0.75, 0.55, 0.3), CF(base + V3(sx * 0.42, 0.05, 0)) * ANG(0, 0, rad(sx * -20)), bc)
			E(V3(0.3, 0.25, 0.32), CF(base + V3(sx * 0.42, 0.05, -0.02)), bc:Lerp(INK, 0.25))
		end
		E(V3(0.32, 0.32, 0.34), base, bc:Lerp(WHITE, 0.2))
	end
	-- королевская мантия за спиной и золотой воротник
	if h.Cape then
		local cc = mc(h.Cape, Color3.fromRGB(120, 40, 160))
		local back = a.bodyC + V3(0, -0.05, a.bodyS.Z + 0.12)
		E(V3(a.bodyS.X * 2.15, a.bodyS.Y * 1.9, 0.22), CF(back) * ANG(rad(10), 0, 0), cc)
		E(V3(a.bodyS.X * 2.0, a.bodyS.Y * 1.7, 0.24), CF(back + V3(0, 0, 0.03)) * ANG(rad(10), 0, 0), cc:Lerp(INK, 0.3))
		for i = 0, 8 do
			local t = i / 8 - 0.5
			E(V3(0.3, 0.3, 0.3), a.bodyC + V3(t * a.bodyS.X * 2.0, a.bodyS.Y * 0.95, a.bodyS.Z * 0.75 - math.abs(t) * 0.4), (i % 2 == 0) and GOLD or WHITE, { Material = (i % 2 == 0) and "Metal" or "SmoothPlastic" })
		end
	end
	-- радужная грива по макушке и затылку
	if h.Mane then
		for i = 0, 6 do
			local col = RAINBOW7[i + 1]
			E(V3(0.62, 0.8, 0.5), a.top + V3(0, 0.12 - i * 0.07, -0.55 + i * 0.32), col)
		end
	end
	-- пушистый радужный хвост
	if h.RainbowTail then
		local t0 = a.tail
		for i = 0, 6 do
			local col = RAINBOW7[i + 1]
			E(V3(0.95 - i * 0.07, 0.9 - i * 0.06, 0.8 - i * 0.05), t0 + V3(0, 0.22 * i + 0.1, 0.35 + 0.26 * i), col)
		end
	end
	-- фонтанчик кита: столбик капель и брызги
	if h.Spout then
		local sc = mc(h.Spout, Color3.fromRGB(140, 220, 255))
		local base = a.top + V3(0, 0, 0.1)
		for i = 0, 2 do
			E(V3(0.4 - i * 0.06, 0.55, 0.4 - i * 0.06), base + V3(0, 0.3 + i * 0.45, 0), sc, { Material = "Glass", Transparency = 0.15 })
		end
		for i = 0, 5 do
			local ang = i / 6 * math.pi * 2
			E(V3(0.3, 0.38, 0.3), base + V3(math.cos(ang) * 0.6, 1.35 - (i % 2) * 0.15, math.sin(ang) * 0.6), (i % 2 == 0) and sc or WHITE, { Material = (i % 2 == 0) and "Glass" or "Neon", Transparency = 0.1 })
		end
	end
	-- ледяная корона
	if h.IceCrown then
		for i = 0, 5 do
			local ang = i / 6 * math.pi * 2
			local p = a.top + V3(math.cos(ang) * a.hs.X * 0.55, -0.05, math.sin(ang) * a.hs.Z * 0.55)
			crystal(p, (i % 2 == 0) and 1.0 or 0.65, ANG(rad(math.cos(ang) * -12), 0, rad(math.sin(ang) * 12)), mc(h.CrownColor, Color3.fromRGB(170, 230, 255)))
		end
	end
	-- самоцвет на груди в золотой оправе
	if h.Gem then
		local g = a.hc + V3(0, -a.hs.Y * 0.62, -a.hs.Z - 0.08)
		B(V3(0.62, 0.62, 0.16), CF(g) * ANG(0, 0, rad(45)), GOLD, { Material = "Metal" })
		B(V3(0.42, 0.42, 0.22), CF(g + V3(0, 0, -0.04)) * ANG(0, 0, rad(45)), mc(h.Gem, glow), { Material = "Neon" })
	end
	MK.Light(ctx.root, glow, 18, 3)
	local e = MK.Sparkles(ctx.root, { 255, 255, 255 }, 18, 0.6)
	e.Color = ColorSequence.new(glow, WHITE)
	e.Name = "HugeAura"
end

function PetBuilder.Build(id)
	local look = PetLooks[id]
	local def = PetsData.ById[id]
	if not look or not def then
		warn("[PetBuilder] нет описания питомца", id)
		look = look or { A = "blob", C = { 200, 200, 200 } }
	end
	local model = Instance.new("Model")
	model.Name = id
	local root = MK.Part(model, V3(1, 1, 1), CF(0, 1, 0), { 255, 255, 255 }, { Transparency = 1, Name = "Root" })
	root.CastShadow = false
	model.PrimaryPart = root

	local C = MK.C(look.C or { 200, 200, 200 })
	local C2 = MK.C(look.C2 or { 255, 255, 255 })
	ctx = {
		model = model,
		root = root,
		C = C,
		Cd = MK.Shade(C, -0.18),
		C2 = C2,
		C3 = look.C3 and MK.C(look.C3) or MK.Shade(C, -0.38),
		mat = look.M or "SmoothPlastic",
		mat2 = look.M2 or look.M or "SmoothPlastic",
		has = {},
		hash = 0,
	}
	for i = 1, #id do
		ctx.hash = (ctx.hash * 31 + string.byte(id, i)) % 1000003
	end
	for _, x in ipairs(look.X or {}) do
		ctx.has[x] = true
	end

	-- зверушки — кубические «как в симуляторах», остальные архетипы остаются своими
	local CUBE = { quad = true, blob = true, bird = true, bat = true, golem = true }
	local a
	if look.Mythic then
		a = ARCH.mythic(look)
	elseif CUBE[look.A] and not look.Classic then
		a = ARCH.cube(look, look.A)
	else
		a = (ARCH[look.A] or ARCH.blob)(look)
	end
	buildEyes(look, a)
	for _, x in ipairs(look.X or {}) do
		local fn = X[x]
		if fn then
			fn(look, a)
		end
	end
	if look.A == "bat" and not table.find(look.X or {}, "wings_bat") then
		X.wings_bat(look, a)
	end
	if look.Mythic then
		mythicFx(look, a)
	end
	if look.Huge then
		hugeFx(look, a)
	end

	local fly = look.Fly
	if fly == nil then
		fly = (look.A == "bird" or look.A == "bat" or look.A == "orb" or look.A == "wisp" or look.A == "fish" or look.A == "dragon" or look.A == "serpent")
	end
	local rarity = def and def.Rarity or "Common"
	local scale = (RARITY_SCALE[rarity] or 1) * (look.S or 1)
	if rarity == "Legendary" or rarity == "Secret" then
		if not ctx.has.sparkle then
			MK.Sparkles(root, ctx.C2, 3, 0.28)
		end
	end
	model:SetAttribute("Fly", fly)
	model:SetAttribute("Scale", scale)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("Huge", look.Huge ~= nil)
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	ctx = nil
	return model
end

-- Перекраска в золотой вариант (крафт 5 одинаковых петов).
function PetBuilder.ApplyGolden(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local paint = p:GetAttribute("Paint")
			if paint == "C" then
				p.Color = GOLD
			elseif paint == "Cd" then
				p.Color = Color3.fromRGB(226, 168, 36)
			elseif paint == "C3" then
				p.Color = Color3.fromRGB(190, 126, 26)
			elseif paint == "C2" then
				p.Color = Color3.fromRGB(255, 240, 170)
			end
			if (paint == "C" or paint == "Cd" or paint == "C3") and p.Material ~= Enum.Material.Glass and p.Material ~= Enum.Material.Neon then
				p.Material = Enum.Material.Metal
				p.Reflectance = 0.05
			end
		end
	end
	local root = model.PrimaryPart
	if root and not root:FindFirstChild("GoldSparkle") then
		local e = MK.Sparkles(root, { 255, 220, 90 }, 4, 0.3)
		e.Name = "GoldSparkle"
	end
	model:SetAttribute("Golden", true)
end

-- Радужный вариант (5-е улучшение): основные части перекрашиваются в радугу,
-- клиент (WorldFxController) плавно гоняет оттенок по тегу "Rainbow".
function PetBuilder.ApplyRainbow(model)
	PetBuilder.ApplyGolden(model)
	local i = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local paint = p:GetAttribute("Paint")
			if paint == "C" or paint == "Cd" or paint == "C3" then
				i = i + 1
				p:SetAttribute("Hue", (i * 0.13) % 1)
				p.Color = Color3.fromHSV((i * 0.13) % 1, 0.65, 1)
				if p.Material == Enum.Material.Metal then
					p.Material = Enum.Material.SmoothPlastic
					p.Reflectance = 0.1
				end
			end
		end
	end
	local root = model.PrimaryPart
	if root and root:FindFirstChild("GoldSparkle") then
		root.GoldSparkle.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 160, 255)),
		})
	end
	model:SetAttribute("Rainbow", true)
	game:GetService("CollectionService"):AddTag(model, "Rainbow")
end

-- Звёзды над питомцем (улучшения ★..★★★) и подпись для Золотого/Радужного
-- Шайни: те же цвета, но светлее и с глянцем, переливающимися искрами и мягким сиянием
function PetBuilder.ApplyShiny(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Material ~= Enum.Material.Neon and p.Transparency < 0.5 then
			local c = p.Color
			-- не трогаем тёмные зрачки и обводки глаз
			if (c.R + c.G + c.B) / 3 > 0.18 then
				p.Color = c:Lerp(Color3.new(1, 1, 1), 0.18)
				p.Reflectance = 0.18
			end
		end
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if root then
		local e = Instance.new("ParticleEmitter")
		e.Name = "ShinySparkle"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 240, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 230)),
		})
		e.LightEmission = 1
		e.Rate = 7
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(0.4, 1.2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = root
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(200, 240, 255)
		l.Range = 8
		l.Brightness = 0.8
		l.Parent = root
	end
	model:SetAttribute("Shiny", true)
end

function PetBuilder.ApplyTier(model, tier)
	tier = tier or 0
	if tier == 6 then
		PetBuilder.ApplyShiny(model)
	elseif tier >= 5 then
		PetBuilder.ApplyRainbow(model)
	elseif tier >= 4 then
		PetBuilder.ApplyGolden(model)
	end
	model:SetAttribute("Tier", tier)
end

return PetBuilder
