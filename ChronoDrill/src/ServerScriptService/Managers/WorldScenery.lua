-- WorldScenery: делает острова живыми — расширенная кромка острова с горными хребтами,
-- леса, облака, водопады, пруды, вышки, ветряная мельница, бочки, вулкан, иглу, кольца бездны...
-- Всё в low-poly стиле из примитивов. Папка "Scenery" на клиенте скрывается для неактивных
-- ярусов (LightingController), поэтому на телефонах рисуется только текущий остров.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MK = require(ReplicatedStorage.Shared.ModelKit)
local Balance = require(ReplicatedStorage:WaitForChild("Configs").Balance)
local MINE_DEPTH = Balance.Layers * Balance.BlockSize

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local Scenery = {}
local rng = Random.new(4242)

-- Границы расширенного острова (шахта ±88, база z до -200)
local RIM = { X = 170, N = -265, S = 165 }
local ISLAND_X, ISLAND_N, ISLAND_S = 110, -200, 112

local function solid(p)
	p.CanCollide = true
	p.CanQuery = true
	return p
end

local function mix(a, b, t)
	return MK.C(a):Lerp(MK.C(b), t)
end

---------------------------------------------------------------------------------------------
-- Примитивы рельефа
---------------------------------------------------------------------------------------------
-- Двускатный "шатёр" из двух клиньев. cf — центр основания по высоте (центр шатра).
local function tent(parent, cf, w, h, d, color, props)
	local a = MK.Wedge(parent, V3(w, h, d / 2), cf * CF(0, 0, -d / 4), color, props)
	local b = MK.Wedge(parent, V3(w, h, d / 2), cf * CF(0, 0, d / 4) * ANG(0, math.pi, 0), color, props)
	return a, b
end

-- Пик = два перекрещенных шатра (похоже на пирамиду с гранями)
local function peak(parent, basePos, w, h, rotY, color, props)
	local cf = CF(basePos + V3(0, h / 2, 0)) * ANG(0, rotY, 0)
	local a, b = tent(parent, cf, w, h, w, color, props)
	local c, d = tent(parent, cf * ANG(0, math.pi / 2, 0), w * 0.92, h, w * 0.92, color, props)
	for _, p in ipairs({ a, b, c, d }) do
		solid(p)
	end
	return cf
end

-- Гранёная low-poly скала (как в популярных симуляторах): глыбы-блоки под разными углами,
-- сверху «шапки» травы/снега, на шапках — гранёные деревья.
local FACET = {
	grass = { rock = { { 204, 148, 100 }, { 184, 128, 86 }, { 218, 164, 114 } }, cap = { { 124, 214, 84 }, { 152, 228, 98 } }, tree = "round" },
	mesa = { rock = { { 222, 168, 108 }, { 198, 140, 88 }, { 236, 190, 128 } }, cap = { { 240, 214, 150 }, { 226, 196, 132 } } },
	snow = { rock = { { 120, 136, 168 }, { 100, 116, 150 }, { 140, 156, 186 } }, cap = { { 246, 250, 255 }, { 226, 238, 252 } }, tree = "snowpine" },
	ash = { rock = { { 76, 66, 74 }, { 58, 50, 58 }, { 92, 80, 88 } }, cap = { { 110, 96, 100 }, { 96, 84, 90 } }, glow = { 255, 110, 40 } },
	crystal = { rock = { { 82, 60, 140 }, { 64, 46, 116 }, { 100, 76, 160 } }, cap = { { 130, 100, 210 }, { 150, 120, 230 } }, glow = { 110, 240, 255 } },
}

function Scenery.FacetMountain(parent, pos, s, style, T, Decor)
	local st = FACET[style] or FACET.grass
	local m = Instance.new("Model")
	m.Name = "Mountain"
	m.Parent = parent
	local function chunk(size, p, colIdx, capIt)
		local col = st.rock[colIdx] or st.rock[1]
		local cf = CF(p) * ANG(rad(rng:NextNumber(-14, 14)), rng:NextNumber() * math.pi * 2, rad(rng:NextNumber(-14, 14)))
		local part = solid(MK.Part(m, size, cf, col, { Material = "Slate" }))
		if capIt then
			local cap = MK.Part(m, V3(size.X * 1.04, 2.4 * s, size.Z * 1.04), cf * CF(0, size.Y / 2 + 0.6 * s, 0), st.cap[rng:NextInteger(1, #st.cap)], { Material = "SmoothPlastic" })
			solid(cap)
			-- ступенька шапки чуть меньше и выше — гранёный край
			MK.Part(m, V3(size.X * 0.7, 1.6 * s, size.Z * 0.7), cf * CF(size.X * 0.08, size.Y / 2 + 2.2 * s, -size.Z * 0.06) * ANG(0, rad(20), 0), st.cap[1], { Material = "SmoothPlastic" })
			return part, cf * CF(0, size.Y / 2 + 1.8 * s, 0)
		end
		return part
	end
	-- основание: 3-4 широкие глыбы
	for k = 1, 4 do
		local a = k * 1.7 + rng:NextNumber()
		local w = (19 + rng:NextNumber() * 8) * s
		local h = (18 + rng:NextNumber() * 10) * s
		chunk(V3(w, h, w * (0.8 + rng:NextNumber() * 0.3)), pos + V3(math.cos(a) * 7 * s, h * 0.32, math.sin(a) * 6 * s), k % 3 + 1, k <= 2)
	end
	-- середина и верх
	local tops = {}
	for k = 1, 2 do
		local a = k * 3.1 + rng:NextNumber()
		local w = (17 + rng:NextNumber() * 6) * s
		local h = (16 + rng:NextNumber() * 6) * s
		local _, top = chunk(V3(w, h, w * 0.9), pos + V3(math.cos(a) * 4 * s, 18 * s + h * 0.25, math.sin(a) * 4 * s), (k + 1) % 3 + 1, true)
		table.insert(tops, top)
	end
	local w = (11 + rng:NextNumber() * 4) * s
	local _, peakTop = chunk(V3(w, 14 * s, w), pos + V3(rng:NextNumber(-2, 2) * s, 34 * s, rng:NextNumber(-2, 2) * s), 3, true)
	table.insert(tops, peakTop)
	-- деревья на шапках
	if st.tree and Decor then
		for i, t in ipairs(tops) do
			if i <= 2 and rng:NextNumber() < 0.8 then
				Decor.Tree(m, t.Position, T, st.tree, 0.75 + rng:NextNumber() * 0.3)
			end
		end
	end
	-- светящиеся жилы/кристаллы
	if st.glow then
		for k = 1, 4 do
			local a = k * 1.57 + rng:NextNumber()
			local h = (6 + rng:NextNumber() * 8) * s
			local p0 = pos + V3(math.cos(a) * 16 * s, 10 * s + rng:NextNumber() * 14 * s, math.sin(a) * 14 * s)
			MK.Part(m, V3(2.2 * s, h, 2.2 * s), CF(p0) * ANG(rad(rng:NextInteger(-30, 30)), a, rad(rng:NextInteger(-30, 30))) * ANG(0, rad(45), 0), st.glow, { Material = "Neon" })
		end
	end
	return m
end

-- Горы по стилям ярусов (старые, «шатровые»)
function Scenery.Mountain(parent, pos, s, style, T)
	local m = Instance.new("Model")
	m.Name = "Mountain"
	m.Parent = parent
	local rot = rng:NextNumber() * math.pi
	local rock = MK.C(T.Rock)
	if style == "grass" then
		rock = MK.C({ 176, 184, 194 }):Lerp(MK.C(T.Leaves), 0.1)
	end
	local rockD = MK.Shade(rock, -0.18)
	local rockL = MK.Shade(rock, 0.1)
	local skirt = MK.C(T.GroundDark)
	if style == "mesa" then
		-- столовая гора: слоёные плато песчаника
		local layers = { { 46, 12, MK.C(T.Cliff) }, { 38, 12, MK.C(T.Rock) }, { 31, 11, MK.Shade(MK.C(T.Cliff), 0.12) }, { 24, 9, MK.C(T.Accent):Lerp(MK.C(T.Rock), 0.7) } }
		local y = 0
		for i, l in ipairs(layers) do
			local w = l[1] * s * (0.9 + rng:NextNumber() * 0.2)
			local h = l[2] * s
			solid(MK.Part(m, V3(w, h, w * 0.86), CF(pos + V3(rng:NextNumber() * 3 - 1.5, y + h / 2, rng:NextNumber() * 3 - 1.5)) * ANG(0, rot + i * 0.15, 0), l[3]))
			y = y + h
		end
		MK.Part(m, V3(18 * s, 1, 15 * s), CF(pos + V3(0, y + 0.5, 0)) * ANG(0, rot, 0), T.Ground)
		return m
	end
	-- основание: валуны-плиты
	for k = 1, 3 do
		local w = (30 + rng:NextNumber() * 14) * s
		local h = (12 + rng:NextNumber() * 8) * s
		local off = V3(rng:NextNumber() * 16 - 8, 0, rng:NextNumber() * 16 - 8) * s
		local col = (style == "grass") and skirt:Lerp(rock, 0.25 * k) or rockD:Lerp(rock, k / 3)
		solid(MK.Part(m, V3(w, h, w * (0.8 + rng:NextNumber() * 0.3)), CF(pos + off + V3(0, h / 2 - 2, 0)) * ANG(rad(rng:NextInteger(-6, 6)), rot + k * 0.9, rad(rng:NextInteger(-6, 6))), col))
	end
	local H = (24 + rng:NextNumber() * 14) * s
	local W = (40 + rng:NextNumber() * 14) * s
	local baseY = 8 * s
	local mat = nil
	local peakColor = rock
	if style == "snow" then
		peakColor = MK.C({ 150, 175, 205 })
	elseif style == "volcano" then
		peakColor = MK.C({ 52, 44, 52 })
	elseif style == "crystal" then
		peakColor = MK.C(T.Cliff)
	end
	peak(m, pos + V3(0, baseY, 0), W, H, rot, peakColor, mat)
	-- второй, меньший пик сбоку — хребет выглядит естественнее
	local side = V3(math.cos(rot), 0, math.sin(rot)) * W * 0.45
	local H2 = H * (0.55 + rng:NextNumber() * 0.2)
	peak(m, pos + side + V3(0, baseY * 0.6, 0), W * 0.7, H2, rot + 0.6, MK.Shade(peakColor, -0.08))
	local apex = pos + V3(0, baseY + H, 0)
	if style == "grass" or style == "snow" then
		-- снежная шапка: те же грани, чуть крупнее, чтобы не было мерцания
		local c = (style == "snow") and 0.55 or 0.42
		local capH = H * c * 1.04
		local cf = CF(apex + V3(0, 0.35 - capH / 2, 0)) * ANG(0, rot, 0)
		tent(m, cf, W * c * 1.08, capH, W * c * 1.08, { 250, 252, 255 })
		tent(m, cf * ANG(0, math.pi / 2, 0), W * c * 1.0, capH, W * c * 1.0, { 250, 252, 255 })
	elseif style == "volcano" then
		-- кратер с лавой, потоки по склонам, дым
		local capH = H * 0.24
		local cf = CF(apex + V3(0, 0.35 - capH / 2, 0)) * ANG(0, rot, 0)
		tent(m, cf, W * 0.25, capH, W * 0.25, { 255, 120, 30 }, { Material = "Neon" })
		tent(m, cf * ANG(0, math.pi / 2, 0), W * 0.23, capH, W * 0.23, { 255, 160, 40 }, { Material = "Neon" })
		local glow = MK.Part(m, V3(2, 2, 2), CF(apex + V3(0, 2, 0)), { 255, 140, 40 }, { Transparency = 1 })
		MK.Light(glow, { 255, 120, 40 }, 40, 2)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(80, 70, 76))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6 * s), NumberSequenceKeypoint.new(1, 18 * s) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(5, 8)
		smoke.Speed = NumberRange.new(4, 8)
		smoke.Rate = 3
		smoke.SpreadAngle = Vector2.new(15, 15)
		smoke.Parent = glow
		local rcf = CF(pos + V3(0, baseY + H / 2, 0)) * ANG(0, rot, 0)
		for k = 0, 2 do
			local face = rcf * ANG(0, k * 2.1, 0)
			local top = face:PointToWorldSpace(V3(0, H / 2 - capH * 0.8, -W * 0.06))
			local bottom = face:PointToWorldSpace(V3((rng:NextNumber() - 0.5) * W * 0.2, -H / 2 + 1, -W * 0.48))
			local n = face:VectorToWorldSpace(V3(0, 1 / (H / 2), -1 / (W / 4)).Unit)
			MK.Beam(m, top + n * 0.4, bottom + n * 0.4, 1.6 * s, { 255, 110, 30 }, { Material = "Neon" })
		end
	elseif style == "crystal" then
		for k = 1, 5 do
			local a = rot + k * 1.25
			local p0 = pos + V3(math.cos(a) * W * 0.32, baseY + H * (0.2 + rng:NextNumber() * 0.4), math.sin(a) * W * 0.32)
			local h = (10 + rng:NextNumber() * 14) * s
			MK.Part(m, V3(3 * s, h, 3 * s), CF(p0) * ANG(rad(rng:NextInteger(-25, 25)), a, rad(rng:NextInteger(-25, 25))) * CF(0, h / 2, 0) * ANG(0, rad(45), 0), (k % 2 == 0) and T.Crystal or T.Trim, { Material = "Neon" })
		end
		local cf = CF(apex + V3(0, 0.3 - H * 0.15, 0)) * ANG(0, rot, 0)
		tent(m, cf, W * 0.3, H * 0.31, W * 0.3, T.Crystal, { Material = "Neon" })
	end
	return m
end

function Scenery.Cloud(parent, pos, s, color, transparency)
	local m = Instance.new("Model")
	m.Name = "Cloud"
	local parts = { { 0, 0, 0, 14, 8, 10 }, { 8, -1, 1, 10, 6, 8 }, { -8, -1, -1, 11, 6, 8 }, { 3, 3, 0, 9, 6, 7 }, { -4, 2.5, 2, 8, 5, 6 } }
	local root
	for i, p in ipairs(parts) do
		local e = MK.Ellipsoid(m, V3(p[4], p[5], p[6]) * s, CF(pos + V3(p[1], p[2], p[3]) * s), color, { Transparency = transparency or 0.05 })
		e.CastShadow = false
		if i == 1 then
			root = e
		end
	end
	m.PrimaryPart = root
	m.Parent = parent
	m:SetAttribute("Base", root.CFrame)
	CollectionService:AddTag(m, "Cloud")
	return m
end

function Scenery.Barrel(parent, pos, T)
	local m = Instance.new("Model")
	m.Name = "Barrel"
	m.Parent = parent
	solid(MK.Disc(m, 3.2, 2.4, pos + V3(0, 1.6, 0), { 150, 96, 56 }))
	for _, y in ipairs({ 0.5, 1.6, 2.7 }) do
		MK.Disc(m, 0.3, 2.55, pos + V3(0, y, 0), { 70, 66, 76 }, { Material = "Metal" })
	end
	return m
end

function Scenery.Tower(parent, pos, T, h)
	-- деревянная вышка шахтёров с фонарём
	local m = Instance.new("Model")
	m.Name = "MineTower"
	m.Parent = parent
	h = h or 16
	local wood = MK.C(T.Trunk)
	for _, o in ipairs({ V3(-3, 0, -3), V3(3, 0, -3), V3(-3, 0, 3), V3(3, 0, 3) }) do
		solid(MK.Part(m, V3(1, h, 1), CF(pos + o + V3(0, h / 2, 0)), wood))
	end
	for _, y in ipairs({ h * 0.33, h * 0.66 }) do
		MK.Beam(m, pos + V3(-3, y - 3, -3), pos + V3(3, y + 1, 3), 0.5, MK.Shade(wood, 0.15))
		MK.Beam(m, pos + V3(3, y - 3, -3), pos + V3(-3, y + 1, 3), 0.5, MK.Shade(wood, 0.15))
	end
	solid(MK.Part(m, V3(8.5, 0.8, 8.5), CF(pos + V3(0, h, 0)), MK.Shade(wood, 0.1)))
	for _, o in ipairs({ V3(0, 0, -4), V3(0, 0, 4) }) do
		MK.Part(m, V3(8.5, 1.4, 0.4), CF(pos + o + V3(0, h + 1.1, 0)), wood)
	end
	tent(m, CF(pos + V3(0, h + 5, 0)), 9.5, 3.5, 9.5, T.Accent)
	for _, o in ipairs({ V3(-3.6, 0, -3.6), V3(3.6, 0, 3.6), V3(-3.6, 0, 3.6), V3(3.6, 0, -3.6) }) do
		MK.Part(m, V3(0.5, 3.4, 0.5), CF(pos + o + V3(0, h + 1.7, 0)), wood)
	end
	local lamp = MK.Part(m, V3(1.2, 1.6, 1.2), CF(pos + V3(0, h + 2, 0)), T.Lamp, { Material = "Neon" })
	MK.Light(lamp, T.Lamp, 26, 1.4)
	return m
end

function Scenery.Windmill(parent, pos, T)
	local m = Instance.new("Model")
	m.Name = "Windmill"
	m.Parent = parent
	for i = 0, 3 do
		local w = 10 - i * 1.6
		solid(MK.Part(m, V3(w, 6, w), CF(pos + V3(0, 3 + i * 6, 0)) * ANG(0, rad(i * 6), 0), (i % 2 == 0) and { 246, 236, 214 } or { 230, 214, 186 }))
	end
	tent(m, CF(pos + V3(0, 27.5, 0)), 6.5, 4, 6.5, { 200, 80, 60 })
	MK.Part(m, V3(2.4, 3.6, 0.3), CF(pos + V3(0, 2, -5.2)), T.Trunk)
	local hub = MK.Cylinder(m, 1.6, 2.2, CF(pos + V3(0, 22, -4.4)) * ANG(0, rad(90), 0), { 90, 70, 60 })
	hub.Name = "Hub"
	local blades = Instance.new("Model")
	blades.Name = "Blades"
	blades.Parent = m
	local center = pos + V3(0, 22, -5.4)
	local root = MK.Part(blades, V3(1, 1, 1), CF(center), { 90, 70, 60 })
	for k = 0, 3 do
		local cf = CF(center) * ANG(0, 0, rad(k * 90))
		MK.Part(blades, V3(0.6, 11, 0.4), cf * CF(0, 6, 0), T.Trunk)
		MK.Part(blades, V3(3.2, 9, 0.2), cf * CF(1.8, 6.5, 0.1), { 250, 246, 236 })
	end
	blades.PrimaryPart = root
	blades:SetAttribute("Base", root.CFrame)
	blades:SetAttribute("SpinSpeed", 0.8)
	CollectionService:AddTag(blades, "Spin")
	return m
end

function Scenery.Cactus(parent, pos, s)
	local m = Instance.new("Model")
	m.Name = "Cactus"
	m.Parent = parent
	local g = { 96, 170, 80 }
	local h = (6 + rng:NextNumber() * 4) * s
	local trunk = MK.Part(m, V3(1.8 * s, h, 1.8 * s), CF(pos + V3(0, h / 2, 0)), g)
	solid(trunk)
	MK.Ellipsoid(m, V3(1.8, 1.4, 1.8) * s, CF(pos + V3(0, h, 0)), g)
	for _, sd in ipairs({ -1, 1 }) do
		local y = h * (0.4 + rng:NextNumber() * 0.2)
		MK.Part(m, V3(2.2 * s, 1.2 * s, 1.2 * s), CF(pos + V3(sd * 1.6 * s, y, 0)), g)
		local ah = (2 + rng:NextNumber() * 2) * s
		MK.Part(m, V3(1.2 * s, ah, 1.2 * s), CF(pos + V3(sd * 2.6 * s, y + ah / 2, 0)), g)
		MK.Ellipsoid(m, V3(1.2, 1, 1.2) * s, CF(pos + V3(sd * 2.6 * s, y + ah, 0)), g)
	end
	MK.Ellipsoid(m, V3(0.9, 0.9, 0.9) * s, CF(pos + V3(0, h + 0.6 * s, 0)), { 255, 120, 170 })
	return m
end

function Scenery.Palm(parent, pos, s)
	local m = Instance.new("Model")
	m.Name = "Palm"
	m.Parent = parent
	local trunk = { 170, 120, 76 }
	local p = pos
	for i = 1, 5 do
		local np = p + V3(0.5 * s, 2.2 * s, 0.2 * s)
		solid(MK.CylinderBetween(m, p, np, (1.3 - i * 0.12) * s, (i % 2 == 0) and trunk or MK.Shade(trunk, -0.12)))
		p = np
	end
	for k = 0, 5 do
		local a = k * math.pi / 3
		local dir = V3(math.cos(a), -0.35, math.sin(a))
		MK.Part(m, V3(1.6 * s, 0.3 * s, 7 * s), CFrame.lookAt(p + dir * 3 * s, p + dir * 7 * s), (k % 2 == 0) and { 90, 180, 70 } or { 120, 200, 80 })
	end
	MK.Ellipsoid(m, V3(1, 1, 1) * s, CF(p + V3(0.6, -0.6, 0) * s), { 120, 80, 50 })
	MK.Ellipsoid(m, V3(1, 1, 1) * s, CF(p + V3(-0.4, -0.7, 0.6) * s), { 120, 80, 50 })
	return m
end

function Scenery.Igloo(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Igloo"
	m.Parent = parent
	solid(MK.Ellipsoid(m, V3(14, 12, 14), CF(pos), { 245, 250, 255 }))
	MK.Ellipsoid(m, V3(5.5, 6, 6), CF(pos + V3(0, -1.2, -6.2)), { 235, 244, 255 })
	MK.Ellipsoid(m, V3(3.6, 4, 1), CF(pos + V3(0, -1.8, -9)), { 60, 80, 110 })
	for i = 1, 3 do
		MK.Part(m, V3(13.6, 0.2, 13.6) * (1 - i * 0.18), CF(pos + V3(0, i * 1.6, 0)), { 210, 226, 246 }, { Transparency = 0.2 })
	end
	return m
end

function Scenery.Iceberg(parent, pos, s)
	local m = Instance.new("Model")
	m.Name = "Iceberg"
	m.Parent = parent
	for k = 1, 3 do
		local h = (6 + rng:NextNumber() * 8) * s
		MK.Part(m, V3((5 + rng:NextNumber() * 4) * s, h, (5 + rng:NextNumber() * 4) * s), CF(pos + V3(rng:NextNumber() * 6 - 3, h / 2 - 1, rng:NextNumber() * 6 - 3) * s) * ANG(rad(rng:NextInteger(-10, 10)), rad(rng:NextInteger(0, 90)), rad(rng:NextInteger(-10, 10))), { 170, 225, 255 }, { Material = "Glass", Transparency = 0.15 })
	end
	return m
end

function Scenery.Ring(parent, pos, radius, color, tilt)
	local m = Instance.new("Model")
	m.Name = "VoidRing"
	m.Parent = parent
	local n = 18
	local cf = CF(pos) * (tilt or ANG(0, 0, 0))
	for i = 0, n - 1 do
		local a = i * math.pi * 2 / n
		local p = cf:PointToWorldSpace(V3(math.cos(a) * radius, math.sin(a) * radius, 0))
		local p2 = cf:PointToWorldSpace(V3(math.cos(a + math.pi * 2 / n) * radius, math.sin(a + math.pi * 2 / n) * radius, 0))
		MK.Beam(m, p, p2, 1.4, color, { Material = "Neon" })
	end
	return m
end

-- Водопад с края острова: русло по земле + струя по обрыву + брызги
function Scenery.Waterfall(parent, from, to, edgeDir, color, neon, noRiver)
	local m = Instance.new("Model")
	m.Name = "Waterfall"
	m.Parent = parent
	local props = neon and { Material = "Neon", Transparency = 0.1 } or { Material = "Glass", Transparency = 0.35 }
	if not noRiver then
		local river = MK.Beam(m, from + V3(0, 0.15, 0), to + V3(0, 0.15, 0), 7, color, props)
		river.Size = V3(10, 0.4, river.Size.Z)
		MK.Beam(m, from + V3(0, -0.1, 0), to + V3(0, -0.1, 0), 12, MK.Shade(MK.C(color), -0.45)).Size = V3(13, 0.4, (to - from).Magnitude)
	end
	local top = to + edgeDir * 0.8 + V3(0, noRiver and -1.5 or 0, 0)
	local fall = MK.Part(m, V3(10, 105, 1.6), CFrame.lookAt(top + V3(0, -52, 0), top + V3(0, -52, 0) + edgeDir), color, props)
	fall.CastShadow = false
	CollectionService:AddTag(fall, "Pulse")
	local lip = MK.Part(m, V3(11, 1.2, 3), CFrame.lookAt(top + V3(0, 0, 0), top + edgeDir), MK.Shade(MK.C(color), 0.35), props)
	lip.CastShadow = false
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(MK.Shade(MK.C(color), 0.6))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(2, 5)
	mist.Rate = 10
	mist.SpreadAngle = Vector2.new(40, 40)
	local anchor = MK.Part(m, V3(1, 1, 1), CF(top + V3(0, -100, 0)), color, { Transparency = 1 })
	mist.Parent = anchor
	return m
end

---------------------------------------------------------------------------------------------
-- Кромка острова: расширение земли, обрывы со стратами, подбрюшье
---------------------------------------------------------------------------------------------
local function buildRims(b, root, O, biome)
	local T = biome.Theme
	local strips = {
		{ -RIM.X, RIM.X, RIM.N, ISLAND_N },           -- север за базой
		{ -RIM.X, RIM.X, ISLAND_S, RIM.S },           -- юг
		{ ISLAND_X, RIM.X, ISLAND_N, ISLAND_S },      -- восток
		{ -RIM.X, -ISLAND_X, ISLAND_N, ISLAND_S },    -- запад
	}
	for _, r in ipairs(strips) do
		local sx, sz = r[2] - r[1], r[4] - r[3]
		local c = O + V3((r[1] + r[2]) / 2, 0, (r[3] + r[4]) / 2)
		local top = solid(MK.Part(root, V3(sx, 2, sz), CF(c + V3(0, -1, 0)), T.Ground, { Name = "Ground" }))
		top.CastShadow = false
		solid(MK.Part(root, V3(sx, 12, sz), CF(c + V3(0, -8, 0)), T.Cliff))
	end
	-- сплошной обрыв под всей площадью острова до глубины шахты
	local w, d = 2 * RIM.X, RIM.S - RIM.N
	local cz = (RIM.S + RIM.N) / 2
	-- (шахта ±96 остаётся пустой — обрыв собирается из четырёх блоков вокруг неё)
	local function fillBlock(x1, x2, z1, z2)
		local h = MINE_DEPTH - 6
		local c = O + V3((x1 + x2) / 2, -14 - h / 2, (z1 + z2) / 2)
		MK.Part(root, V3(x2 - x1 - 0.4, h, z2 - z1 - 0.4), CF(c), T.CliffDark)
	end
	fillBlock(-RIM.X, RIM.X, RIM.N, -96)
	fillBlock(-RIM.X, RIM.X, 96, RIM.S)
	fillBlock(96, RIM.X, -96, 96)
	fillBlock(-RIM.X, -96, -96, 96)
	-- страты по четырём внешним граням
	local bandCols = {}
	for _, k in ipairs(biome.Kinds) do
		table.insert(bandCols, k.Color)
	end
	for i = 0, math.floor((MINE_DEPTH - 4) / 16) - 1 do
		local h = 16
		local yc = -14 - i * h - h / 2 + 2
		local col = bandCols[(i % #bandCols) + 1]
		local inset = i * 0.6
		local sl = { Material = "Slate" }
		MK.Part(root, V3(w + 1 - inset * 2, h, 1), CF(O + V3(0, yc, RIM.S + 0.5 - inset)), col, sl)
		MK.Part(root, V3(w + 1 - inset * 2, h, 1), CF(O + V3(0, yc, RIM.N - 0.5 + inset)), col, sl)
		MK.Part(root, V3(1, h, d + 1 - inset * 2), CF(O + V3(RIM.X + 0.5 - inset, yc, cz)), col, sl)
		MK.Part(root, V3(1, h, d + 1 - inset * 2), CF(O + V3(-RIM.X - 0.5 + inset, yc, cz)), col, sl)
	end
	-- травяная кромка-бортик по краю (только без ландшафта)
	if not Scenery.HasTerrain then
	-- скруглённый «травяной валик» по краю острова (мягкий современный край вместо острого угла)
	for _, e in ipairs({
		{ w + 2, CF(O + V3(0, 0, RIM.S)) },
		{ w + 2, CF(O + V3(0, 0, RIM.N)) },
		{ d + 2, CF(O + V3(RIM.X, 0, cz)) * ANG(0, rad(90), 0) },
		{ d + 2, CF(O + V3(-RIM.X, 0, cz)) * ANG(0, rad(90), 0) },
	}) do
		MK.Cylinder(root, e[1], 2.6, e[2] * CF(0, -0.75, 0), T.Ground)
		MK.Cylinder(root, e[1] + 0.4, 3.2, e[2] * CF(0, -1.9, 0), T.GroundDark)
	end
	end
	-- ступенчатое подбрюшье, сужающееся вниз
	local steps = { { 1.0, -118 }, { 0.78, -134 }, { 0.55, -150 }, { 0.32, -166 }, { 0.14, -180 } }
	for i, st in ipairs(steps) do
		local col = (i % 2 == 0) and T.Cliff or T.CliffDark
		MK.Part(root, V3(w * st[1] * 0.92, 18, d * st[1] * 0.9), CF(O + V3(0, st[2] - (MINE_DEPTH - 100), cz)) * ANG(0, rad(i * 4), 0), col, { Material = "Slate" })
	end
	for i = 1, 14 do
		local p = O + V3(rng:NextInteger(-150, 150), rng:NextInteger(-170, -110) - (MINE_DEPTH - 100), rng:NextInteger(-240, 140))
		MK.Part(root, V3(10, 18, 10) * (0.6 + rng:NextNumber()), CF(p) * ANG(rad(rng:NextInteger(0, 40)), rad(rng:NextInteger(0, 90)), rad(rng:NextInteger(0, 40))), T.CliffDark)
	end
end

---------------------------------------------------------------------------------------------
-- Горные хребты
---------------------------------------------------------------------------------------------
local STYLE = { "grass", "mesa", "snow", "volcano", "crystal" }

---------------------------------------------------------------------------------------------
-- Ландшафт Roblox (Terrain): земля с травой, округлые горы, холмы, тропинки, вода
---------------------------------------------------------------------------------------------
local M = Enum.Material
local TERRAIN = {
	-- ground, path, hill, base, rock, cap
	[1] = { M.Grass, M.Ground, M.Grass, M.LeafyGrass, M.Rock, M.Snow },
	[2] = { M.Sand, M.Limestone, M.Sand, M.Sandstone, M.Sandstone, M.Limestone },
	[3] = { M.Snow, M.Ice, M.Snow, M.Snow, M.Glacier, M.Snow },
	[4] = { M.Basalt, M.Asphalt, M.Basalt, M.Basalt, M.Basalt, M.CrackedLava },
	[5] = { M.Salt, M.Pavement, M.Salt, M.Salt, M.Slate, M.Slate },
}
local terrainReady = false
local terrainResult = false
local function terrain()
	return workspace:FindFirstChildOfClass("Terrain")
end

function Scenery.SetupTerrain()
	-- результат запоминаем: раньше со 2-го яруса снова возвращалось «ландшафт есть», и землю
	-- 2–5 ярусов заливало Terrain поверх деталей — зона продажи и дорожки оказывались под ним
	if terrainReady then
		return terrainResult
	end
	terrainReady = true
	terrainResult = false
	local t = terrain()
	if Balance.SmoothWorld then
		-- мягкий стиль: только гладкие детали, без текстур ландшафта
		if t then
			pcall(function()
				t.Decoration = false
			end)
		end
		return false
	end
	if not t then
		return false
	end
	local colors = {
		[M.Grass] = { 108, 194, 74 }, [M.LeafyGrass] = { 92, 176, 66 }, [M.Ground] = { 156, 120, 82 },
		[M.Rock] = { 156, 160, 172 }, [M.Snow] = { 240, 246, 255 }, [M.Sand] = { 236, 208, 150 },
		[M.Sandstone] = { 210, 152, 100 }, [M.Limestone] = { 240, 226, 194 }, [M.Ice] = { 170, 220, 255 },
		[M.Glacier] = { 150, 196, 240 }, [M.Basalt] = { 62, 56, 66 }, [M.CrackedLava] = { 255, 110, 40 },
		[M.Asphalt] = { 96, 86, 92 }, [M.Salt] = { 78, 58, 132 }, [M.Slate] = { 60, 44, 110 },
		[M.Pavement] = { 120, 100, 180 },
	}
	for mat, c in pairs(colors) do
		pcall(function()
			t:SetMaterialColor(mat, MK.C(c))
		end)
	end
	pcall(function()
		t.WaterColor = Color3.fromRGB(64, 168, 235)
		t.WaterTransparency = 0.35
		t.WaterReflectance = 0.25
		t.WaterWaveSize = 0.12
		t.WaterWaveSpeed = 8
	end)
	pcall(function()
		t.Decoration = false -- без «ковра» анимированной травы: чище и мягче картинка
	end)
	terrainResult = true
	return true
end

local function fillBlock(cf, size, mat)
	local t = terrain()
	if t then
		t:FillBlock(cf, size, mat)
	end
end
local function fillBall(pos, r, mat)
	local t = terrain()
	if t then
		t:FillBall(pos, r, mat)
	end
end
local function fillCyl(cf, h, r, mat)
	local t = terrain()
	if t then
		t:FillCylinder(cf, h, r, mat)
	end
end

local function terrainGround(b, folder, O)
	local mats = TERRAIN[b]
	local function rect(x1, x2, z1, z2)
		fillBlock(CF(O + V3((x1 + x2) / 2, -6.5, (z1 + z2) / 2)), V3(x2 - x1, 13, z2 - z1), mats[1])
	end
	rect(-RIM.X - 1, RIM.X + 1, RIM.N - 1, -88)
	rect(-RIM.X - 1, RIM.X + 1, 88, RIM.S + 1)
	rect(88, RIM.X + 1, -88, 88)
	rect(-RIM.X - 1, -88, -88, 88)
	-- тропинки базы из другого материала (трава на них не растёт)
	fillCyl(CF(O + V3(0, -2, -140)), 4, 15, mats[2])
	for _, seg in ipairs({ { V3(0, 0, -125), V3(0, 0, -92) }, { V3(-14, 0, -140), V3(-52, 0, -140) }, { V3(14, 0, -140), V3(66, 0, -140) }, { V3(0, 0, -155), V3(0, 0, -190) }, { V3(-38, 0, -122), V3(-38, 0, -108) }, { V3(40, 0, -122), V3(40, 0, -108) } }) do
		local a, c = O + seg[1], O + seg[2]
		local mid = (a + c) / 2 + V3(0, -2, 0)
		fillBlock(CFrame.lookAt(mid, mid + (c - a)), V3(8, 4, (c - a).Magnitude + 4), mats[2])
	end
	-- старые плиты-земля и дорожки прячем: рисует ландшафт, плиты остаются для коллизий
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Ground" then
				d.Transparency = 1
			elseif d.Name == "Path" then
				d.Transparency = 1
				d.CanCollide = false
			end
		end
	end
end

-- Округлая гора из шаров ландшафта
function Scenery.TerrainMountain(parent, pos, s, style, T, b)
	local mats = TERRAIN[b]
	local base, rock, cap = mats[4], mats[5], mats[6]
	if style == "mesa" then
		local rot = rng:NextNumber() * math.pi
		local y = 0
		local layers = { { 46, 13, M.Sandstone }, { 38, 12, M.Limestone }, { 31, 11, M.Sandstone }, { 24, 10, M.Limestone } }
		for i, l in ipairs(layers) do
			local w = l[1] * s * (0.9 + rng:NextNumber() * 0.2)
			local h = l[2] * s
			fillBlock(CF(pos + V3(0, y + h / 2 - 2, 0)) * ANG(0, rot + i * 0.2, 0), V3(w, h, w * 0.86), l[3])
			y = y + h
		end
		return
	end
	for k = 1, 3 do
		local a = k * 2.1 + rng:NextNumber()
		fillBall(pos + V3(math.cos(a) * 10 * s, -2 * s, math.sin(a) * 8 * s), (17 + rng:NextNumber() * 7) * s, base)
	end
	for k = 1, 2 do
		local a = k * 3.1 + rng:NextNumber()
		fillBall(pos + V3(math.cos(a) * 5 * s, 13 * s, math.sin(a) * 5 * s), (12 + rng:NextNumber() * 4) * s, rock)
	end
	local topY = 25 * s
	if style == "volcano" then
		fillBall(pos + V3(0, topY, 0), 10 * s, rock)
		fillBall(pos + V3(0, topY + 9 * s, 0), 6 * s, M.Air)
		fillBall(pos + V3(0, topY + 4 * s, 0), 4.5 * s, M.CrackedLava)
		local lava = MK.Disc(parent, 0.6, 8 * s, pos + V3(0, topY + 7 * s, 0), { 255, 120, 30 }, { Material = "Neon" })
		lava.CastShadow = false
		MK.Light(lava, { 255, 120, 40 }, 40, 2)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(80, 70, 76))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5 * s), NumberSequenceKeypoint.new(1, 16 * s) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(5, 8)
		smoke.Speed = NumberRange.new(4, 8)
		smoke.Rate = 3
		smoke.SpreadAngle = Vector2.new(15, 15)
		smoke.Parent = lava
		return
	end
	local capMat = (style == "ash") and rock or cap
	fillBall(pos + V3(0, topY, 0), 9.5 * s, capMat)
	fillBall(pos + V3(0, topY + 8 * s, 0), 5.5 * s, capMat)
	if style == "crystal" then
		for k = 1, 6 do
			local a = k * 1.05
			local p0 = pos + V3(math.cos(a) * 13 * s, 8 * s + rng:NextNumber() * 14 * s, math.sin(a) * 13 * s)
			local h = (9 + rng:NextNumber() * 12) * s
			MK.Part(parent, V3(2.6 * s, h, 2.6 * s), CF(p0) * ANG(rad(rng:NextInteger(-30, 30)), a, rad(rng:NextInteger(-30, 30))) * CF(0, h / 2, 0) * ANG(0, rad(45), 0), (k % 2 == 0) and T.Crystal or T.Trim, { Material = "Neon" })
		end
	end
end

function Scenery.TerrainHill(pos, s, b)
	fillBall(pos + V3(0, -10 * s, 0), 18 * s, TERRAIN[b][3])
end

function Scenery.TerrainPond(center, radius, liquid)
	fillCyl(CF(center + V3(0, -3, 0)), 6.5, radius, M.Air)
	fillCyl(CF(center + V3(0, -3.2, 0)), 4.6, radius, liquid or M.Water)
	fillCyl(CF(center + V3(0, -6, 0)), 2, radius + 1, M.Mud)
end

function Scenery.TerrainRiver(a, c, width, liquid)
	local mid = (a + c) / 2
	local cf = CFrame.lookAt(mid, mid + (c - a))
	fillBlock(cf * CF(0, -3, 0), V3(width, 6.5, (c - a).Magnitude), M.Air)
	fillBlock(cf * CF(0, -3.2, 0), V3(width, 4.6, (c - a).Magnitude), liquid or M.Water)
end

function Scenery.Hill(parent, pos, s, T, b)
	-- мягкий холм из сплюснутых эллипсоидов цвета земли
	local m = Instance.new("Model")
	m.Name = "Hill"
	m.Parent = parent
	local g = MK.C(T.Ground)
	local blobs = { { 0, 0, 0, 34, 14, 28 }, { 12, -2, 6, 24, 10, 20 }, { -13, -2, -4, 22, 9, 20 } }
	for i, bl in ipairs(blobs) do
		local e = MK.Ellipsoid(m, V3(bl[4], bl[5], bl[6]) * s, CF(pos + V3(bl[1], bl[2] + 1, bl[3]) * s) * ANG(0, rng:NextNumber() * 3, 0), (i == 1) and g or MK.Shade(g, -0.06))
		solid(e)
		e.CastShadow = true
	end
	return m
end

local function buildMountains(b, root, O, biome, Decor)
	local T = biome.Theme
	local style = STYLE[b]
	local spots = {}
	-- север: хребет за базой
	for i = 0, 5 do
		table.insert(spots, { V3(-140 + i * 56 + rng:NextInteger(-8, 8), 0, -250 + rng:NextInteger(-5, 5)), 1.2 + rng:NextNumber() * 0.4 })
	end
	-- восток и запад
	for _, z in ipairs({ -175, -105, 70 }) do
		table.insert(spots, { V3(144 + rng:NextInteger(-5, 5), 0, z + rng:NextInteger(-8, 8)), 0.85 + rng:NextNumber() * 0.3 })
		table.insert(spots, { V3(-144 + rng:NextInteger(-5, 5), 0, z + rng:NextInteger(-8, 8)), 0.85 + rng:NextNumber() * 0.3 })
	end
	local skip = { [1] = V3(-142, 0, -22), [3] = V3(142, 0, 30), [4] = V3(142, 0, 30), [5] = V3(-142, 0, -22) }
	for _, sp in ipairs(spots) do
		local gap = skip[b]
		if not (gap and (sp[1] - gap).Magnitude < 34) then
			local st = style
			if b == 4 then
				-- вулканы через один, остальные — пепельные скалы
				st = (rng:NextNumber() < 0.3) and "volcano" or "ash"
			end
			if st == "volcano" and Scenery.HasTerrain then
				Scenery.TerrainMountain(root, O + sp[1], sp[2], st, T, b)
			elseif st == "volcano" then
				Scenery.Mountain(root, O + sp[1], sp[2], st, T)
			else
				Scenery.FacetMountain(root, O + sp[1], sp[2], st, T, Decor)
			end
		end
	end
	-- холмы между горами и на юге (вид на шахту остаётся открытым)
	local hills = {
		V3(-112, 0, -232), V3(112, 0, -232), V3(150, 0, -30), V3(-150, 0, 30),
		V3(-120, 0, 140), V3(-40, 0, 146), V3(40, 0, 144), V3(120, 0, 140),
	}
	for i, h in ipairs(hills) do
		local gap = skip[b]
		if not (gap and (h - gap).Magnitude < 30) then
			local sc = 0.8 + rng:NextNumber() * 0.5
			if Scenery.HasTerrain then
				Scenery.TerrainHill(O + h, sc, b)
			else
				Scenery.Hill(root, O + h, sc, T, b)
			end
			if b ~= 2 and b ~= 4 then
				local treeStyle = ({ "round", "round", "snowpine", "dead", "crystal" })[b]
				for k = 1, 2 do
					local dx, dz = rng:NextInteger(-7, 7), rng:NextInteger(-5, 5)
					local hy = math.sqrt(math.max(0, (18 * sc) ^ 2 - dx * dx - dz * dz)) - 10 * sc
					Decor.Tree(root, O + h + V3(dx, hy - 0.6, dz), T, treeStyle, 0.8)
				end
			elseif b == 2 then
				Scenery.Cactus(root, O + h + V3(0, 7.5 * sc, 0), 1)
			end
		end
	end
	-- главный вулкан магмы
	if b == 4 then
		if Scenery.HasTerrain then
			Scenery.TerrainMountain(root, O + V3(0, 0, -250), 1.9, "volcano", T, b)
		else
			Scenery.Mountain(root, O + V3(0, 0, -252), 2.0, "volcano", T)
		end
	end
end

---------------------------------------------------------------------------------------------
-- Леса, реквизит и тематические детали
---------------------------------------------------------------------------------------------
local function inBusyZone(p)
	-- шахта и подходы, база
	if math.abs(p.X) < 100 and p.Z > -96 and p.Z < 112 then
		return true
	end
	-- база + таблицы лидеров (z ≈ -201) — за ними ничего не сажаем, чтобы не перекрывать
	if math.abs(p.X) < 108 and p.Z > -232 and p.Z < -88 then
		return true
	end
	return false
end

local function buildProps(b, root, O, biome, Decor)
	local T = biome.Theme
	-- лесополосы перед горами по кромке
	local treeStyle = ({ "round", "round", "snowpine", "dead", "crystal" })[b]
	local placed, tries = 0, 0
	while placed < 24 and tries < 400 do
		tries = tries + 1
		local p
		local r = rng:NextNumber()
		if r < 0.4 then
			p = V3(rng:NextInteger(-165, 165), 0, rng:NextInteger(-214, -202))
		elseif r < 0.7 then
			p = V3((rng:NextNumber() < 0.5 and -1 or 1) * rng:NextInteger(113, 124), 0, rng:NextInteger(-195, 105))
		else
			p = V3(rng:NextInteger(-165, 165), 0, rng:NextInteger(115, 126))
		end
		if not inBusyZone(p) then
			placed = placed + 1
			local wp = O + p
			if b == 2 then
				if rng:NextNumber() < 0.5 then
					Scenery.Cactus(root, wp, 0.9 + rng:NextNumber() * 0.5)
				else
					Scenery.Palm(root, wp, 0.9 + rng:NextNumber() * 0.4)
				end
			else
				local st = treeStyle
				if b == 1 and rng:NextNumber() < 0.4 then
					st = "pine"
				end
				Decor.Tree(root, wp, T, st, 0.9 + rng:NextNumber() * 0.6)
			end
		end
	end
	-- валуны и кусты
	for i = 1, 28 do
		local p = V3(rng:NextInteger(-166, 166), 0, rng:NextInteger(-260, 160))
		local onRim = math.abs(p.X) > 112 or p.Z < -202 or p.Z > 114
		if onRim then
			if rng:NextNumber() < 0.55 then
				Decor.Rock(root, O + p, T, 0.7 + rng:NextNumber() * 0.9)
			else
				Decor.Crystal(root, O + p, T.Crystal, 0.9 + rng:NextNumber() * 0.6, i % 4 == 0)
			end
		end
	end
	-- вышки на углах шахты и бочки/ящики у подов
	for _, c in ipairs({ V3(-100, 0, 100), V3(100, 0, 100) }) do
		Scenery.Tower(root, O + c, T, 15)
	end
	for _, p in ipairs({ V3(-30, 0, 98), V3(30, 0, 99), V3(97, 0, -60), V3(-97, 0, 70), V3(96, 0, 20) }) do
		Scenery.Barrel(root, O + p, T)
		Scenery.Barrel(root, O + p + V3(2.6, 0, 0.8), T)
		Decor.Crate(root, O + p + V3(-3, 0, 2), T, 0.8)
	end
	-- облака
	local cloudColor = ({ { 255, 255, 255 }, { 255, 246, 230 }, { 240, 248, 255 }, { 90, 80, 86 }, { 170, 130, 255 } })[b]
	local cloudT = ({ 0.05, 0.05, 0.05, 0.25, 0.45 })[b]
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2 + rng:NextNumber() * 0.3
		local rr = 230 + rng:NextInteger(0, 90)
		local p = O + V3(math.cos(a) * rr, 45 + rng:NextInteger(0, 60), -50 + math.sin(a) * rr * 1.1)
		Scenery.Cloud(root, p, 1.2 + rng:NextNumber() * 1.3, cloudColor, cloudT)
	end
	-- тематика ярусов
	if b == 1 then
		Scenery.Windmill(root, O + V3(-140, 0, -140), T)
		if Scenery.HasTerrain then
			Scenery.TerrainPond(O + V3(-122, 0, -22), 12)
			Scenery.TerrainRiver(O + V3(-122, 0, -22), O + V3(-RIM.X - 2, 0, -22), 8)
			Scenery.Waterfall(root, O + V3(-122, 0, -22), O + V3(-RIM.X, 0, -22), V3(-1, 0, 0), { 90, 175, 255 }, false, true)
		else
			Scenery.Waterfall(root, O + V3(-122, 0, -22), O + V3(-RIM.X, 0, -22), V3(-1, 0, 0), { 90, 175, 255 })
			MK.Disc(root, 0.5, 22, O + V3(-122, 0.1, -22), { 90, 175, 255 }, { Material = "Glass", Transparency = 0.3 })
			MK.Disc(root, 0.4, 25, O + V3(-122, 0.02, -22), { 120, 96, 70 })
		end
		for i = 1, 5 do
			local a = i * 1.25
			Decor.Rock(root, O + V3(-122 + math.cos(a) * 13, 0, -22 + math.sin(a) * 13), T, 0.45)
		end
		for _, p in ipairs({ V3(-150, 0, 60), V3(150, 0, -100), V3(140, 0, 128), V3(-60, 0, 135) }) do
			Decor.Flowers(root, O + p, { { 255, 120, 170 }, { 255, 255, 255 }, { 255, 200, 60 }, { 170, 120, 255 } })
		end
	elseif b == 2 then
		Decor.Bones(root, O + V3(140, 0, -120), T, 1.3)
		-- оазис
		if Scenery.HasTerrain then
			Scenery.TerrainPond(O + V3(-140, 0, 40), 13)
		else
			MK.Disc(root, 0.5, 26, O + V3(-140, 0.1, 40), { 70, 200, 220 }, { Material = "Glass", Transparency = 0.25 })
			MK.Disc(root, 0.4, 30, O + V3(-140, 0.02, 40), { 236, 210, 150 })
		end
		for i = 1, 4 do
			Scenery.Palm(root, O + V3(-140 + math.cos(i * 1.6) * 17, 0, 40 + math.sin(i * 1.6) * 17), 1.2)
		end
		for i = 1, 4 do
			Decor.Crystal(root, O + V3(rng:NextInteger(-160, 160), 0, rng:NextInteger(-250, -215)), T.Crystal, 2.2, true)
		end
	elseif b == 3 then
		Scenery.Igloo(root, O + V3(-140, 0, -150))
		Scenery.Igloo(root, O + V3(140, 0, 70))
		if Scenery.HasTerrain then
			Scenery.TerrainRiver(O + V3(118, 0, 30), O + V3(RIM.X + 2, 0, 30), 8, M.Ice)
			Scenery.TerrainPond(O + V3(-100, 0, 60), 9, M.Ice)
		end
		Scenery.Waterfall(root, O + V3(124, 0, 30), O + V3(RIM.X, 0, 30), V3(1, 0, 0), { 170, 230, 255 }, false, Scenery.HasTerrain)
		for i = 1, 6 do
			local side = (i % 2 == 0) and 1 or -1
			Scenery.Iceberg(root, O + V3(side * rng:NextInteger(200, 260), rng:NextInteger(-30, 10), rng:NextInteger(-220, 120)), 1.6 + rng:NextNumber())
		end
	elseif b == 4 then
		Scenery.Waterfall(root, O + V3(124, 0, 30), O + V3(RIM.X, 0, 30), V3(1, 0, 0), { 255, 110, 30 }, true)
		for i = 1, 10 do
			local p = V3(rng:NextInteger(-165, 165), 0, rng:NextInteger(-205, 160))
			if not inBusyZone(p) then
				local h = 6 + rng:NextNumber() * 8
				MK.Part(root, V3(2.4, h, 2.4), CF(O + p + V3(0, h / 2 - 0.5, 0)) * ANG(rad(rng:NextInteger(-15, 15)), rad(45), rad(rng:NextInteger(-15, 15))), { 40, 22, 56 }, { Material = "Glass", Transparency = 0.05 })
			end
		end
		for _, p in ipairs({ V3(-140, 0, 40), V3(130, 0, -160), V3(-60, 0, 138) }) do
			Decor.LavaPool(root, O + p, 1.1)
		end
	elseif b == 5 then
		Scenery.Waterfall(root, O + V3(-122, 0, -22), O + V3(-RIM.X, 0, -22), V3(-1, 0, 0), { 150, 100, 255 }, true)
		Scenery.Ring(root, O + V3(0, 60, -150), 26, { 110, 240, 255 }, ANG(rad(-15), 0, 0))
		Scenery.Ring(root, O + V3(-150, 40, 40), 14, { 200, 120, 255 }, ANG(0, rad(70), 0))
		Scenery.Ring(root, O + V3(150, 50, -60), 18, { 110, 240, 255 }, ANG(rad(20), rad(-60), 0))
		for i = 1, 4 do
			local p = V3(rng:NextInteger(-165, 165), 0, rng:NextInteger(-205, 160))
			if not inBusyZone(p) then
				-- светящиеся грибы (немного)
				local h = 2 + rng:NextNumber() * 3
				MK.Cylinder(root, h, 0.7, CF(O + p + V3(0, h / 2, 0)) * ANG(0, 0, rad(90)), { 230, 220, 255 })
				local cap = MK.Ellipsoid(root, V3(3.4, 1.6, 3.4), CF(O + p + V3(0, h, 0)), (i % 2 == 0) and { 110, 240, 255 } or { 220, 110, 255 }, { Material = "Neon" })
				if i % 3 == 0 then
					MK.Light(cap, { 150, 200, 255 }, 12, 1)
				end
			end
		end
	end
end

function Scenery.Build(b, folder, O, biome, Decor)
	Scenery.HasTerrain = Scenery.SetupTerrain()
	local root = Instance.new("Folder")
	root.Name = "Scenery"
	root.Parent = folder
	buildRims(b, folder:FindFirstChild("Island") or root, O, biome)
	if Scenery.HasTerrain then
		terrainGround(b, folder, O)
	end
	buildMountains(b, root, O, biome, Decor)
	buildProps(b, root, O, biome, Decor)
end

return Scenery
