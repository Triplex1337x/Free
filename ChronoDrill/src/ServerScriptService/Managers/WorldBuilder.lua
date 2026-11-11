-- WorldBuilder: процедурно строит 5 летающих островов-биомов:
-- шахта 160x160 со стенами и 10 дроп-подами, база с продажей, магазинами, яйцами,
-- инкубатором, Хроно-Древом, порталами и NPC Drill-Bot 3000, плюс декор под тему биома.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local BiomesData = require(Configs.BiomesData)
local EggsData = require(Configs.EggsData)
local DrillsData = require(Configs.DrillsData)
local BackpacksData = require(Configs.BackpacksData)
local MK = require(ReplicatedStorage.Shared.ModelKit)
local GearBuilder = require(ReplicatedStorage.Shared.GearBuilder)
local NPCBuilder = require(ReplicatedStorage.Shared.NPCBuilder)
local Util = require(ReplicatedStorage.Shared.Util)

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local WorldBuilder = {}
WorldBuilder.Points = {}

local HALF = Balance.GridSize * Balance.BlockSize / 2 -- 80
local WALL = Balance.WallThickness                    -- 8
local DEPTH = Balance.Layers * Balance.BlockSize      -- 100

local rng = Random.new(1337)
local worldFolder, minesFolder

function WorldBuilder.Origin(b)
	return V3((b - 1) * Balance.BiomeSpacing, 0, 0)
end

local function solid(p, collide)
	p.CanCollide = collide ~= false
	p.CanQuery = true
	p.CanTouch = true
	return p
end

local function prompt(parent, actionText, objectText, action, extra)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = objectText or ""
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.HoldDuration = 0
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Style = Enum.ProximityPromptStyle.Default
	pp:SetAttribute("Action", action)
	if extra then
		for k, v in pairs(extra) do
			pp:SetAttribute(k, v)
		end
	end
	pp.Parent = parent
	return pp
end

local function faceCenter(pos, center)
	return CFrame.lookAt(pos, V3(center.X, pos.Y, center.Z))
end

---------------------------------------------------------------------------------------------
-- Декор
---------------------------------------------------------------------------------------------
local Decor = {}

-- шатёр из двух клиньев (основа конусов-ёлок)
local function tentParts(parent, cf, w, h, d, color)
	MK.Wedge(parent, V3(w, h, d / 2), cf * CF(0, 0, -d / 4), color)
	MK.Wedge(parent, V3(w, h, d / 2), cf * CF(0, 0, d / 4) * ANG(0, math.pi, 0), color)
end

function Decor.Tree(parent, pos, T, style, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = parent
	local trunkH = ((style == "pine" or style == "snowpine") and 3.2 or 5.5) * s
	local trunk = solid(MK.Part(m, V3(1.3 * s, trunkH + 1, 1.3 * s), CF(pos + V3(0, trunkH / 2, 0)) * ANG(0, rng:NextNumber() * 3, 0), T.Trunk, { Material = "Wood" }))
	if style == "pine" or style == "snowpine" then
		-- ёлка: ярусы-конусы из перекрещенных шатров
		local rot = rng:NextNumber() * math.pi
		for i = 0, 2 do
			local w = (8.4 - i * 2.2) * s
			local h = (5.2 - i * 0.8) * s
			local y = trunkH + i * 3.2 * s
			local col = (i % 2 == 0) and T.Leaves or T.Leaves2
			if style == "snowpine" then
				col = (i % 2 == 0) and { 64, 124, 104 } or { 80, 140, 118 }
			end
			local cf = CF(pos + V3(0, y + h / 2, 0)) * ANG(0, rot + i * 0.4, 0)
			tentParts(m, cf, w, h, w, col)
			tentParts(m, cf * ANG(0, math.pi / 2, 0), w * 0.94, h, w * 0.94, col)
			if style == "snowpine" then
				local cap = cf * CF(0, h * 0.28, 0)
				tentParts(m, cap, w * 0.48, h * 0.46, w * 0.48, { 244, 250, 255 })
				tentParts(m, cap * ANG(0, math.pi / 2, 0), w * 0.45, h * 0.46, w * 0.45, { 244, 250, 255 })
			end
		end
	elseif style == "dead" then
		local top = pos + V3(0, trunkH, 0)
		for i = 1, 3 do
			local d = V3(math.cos(i * 2.1), 0.8, math.sin(i * 2.1)).Unit
			MK.CylinderBetween(m, top - V3(0, 1, 0), top + d * 3.5 * s, 0.5 * s, T.Trunk)
			MK.Ellipsoid(m, V3(1.2, 1.2, 1.2) * s, CF(top + d * 3.5 * s), T.Leaves, { Material = "Neon" })
		end
	elseif style == "crystal" then
		for i = 1, 5 do
			local ang = i * 72 + rng:NextInteger(0, 30)
			local tilt = ANG(0, rad(ang), rad(20 + rng:NextInteger(0, 20)))
			local h = (3 + rng:NextNumber() * 3) * s
			local cf = CF(pos + V3(0, trunkH, 0)) * tilt * CF(0, h / 2, 0) * ANG(0, rad(45), 0)
			MK.Part(m, V3(1.2 * s, h, 1.2 * s), cf, (i % 2 == 0) and T.Leaves or T.Leaves2, { Material = "Glass", Transparency = 0.15 })
		end
		MK.Light(m:FindFirstChildWhichIsA("BasePart"), T.Leaves, 14, 1.2)
	else
		-- современная «пушистая» крона: гладкие шары двух оттенков, верхние светлее (как подсвечены солнцем)
		local c = pos + V3(0, trunkH + 2.6 * s, 0)
		local g1, g2 = MK.C(T.Leaves), MK.C(T.Leaves2)
		local blobs = { { 0, 0, 0, 7.6 }, { 2.8, -1.0, 1.3, 5.4 }, { -2.8, -0.9, -1.1, 5.6 }, { 0.4, 2.6, -0.3, 5.0 }, { -1.0, -0.8, 2.8, 4.6 }, { 1.4, 1.4, -2.2, 4.2 } }
		for i, bl in ipairs(blobs) do
			local col = (i % 2 == 0) and g2 or g1
			if bl[2] > 1 then
				col = col:Lerp(Color3.new(1, 1, 0.8), 0.18)
			elseif bl[2] < -0.5 then
				col = col:Lerp(Color3.new(0, 0, 0), 0.08)
			end
			local size = bl[4] * s
			MK.Ellipsoid(m, V3(size, size * 0.9, size), CF(c + V3(bl[1], bl[2], bl[3]) * s), col)
		end
		-- ветки у ствола
		for k = 1, 2 do
			local a = k * 2.6 + rng:NextNumber()
			MK.CylinderBetween(m, pos + V3(0, trunkH * 0.55, 0), pos + V3(math.cos(a) * 2.2 * s, trunkH * 0.9, math.sin(a) * 2.2 * s), 0.45 * s, T.Trunk, { Material = "Wood" })
		end
		if rng:NextNumber() < 0.35 then
			for k = 1, 3 do
				local a = k * 2.1
				MK.Ellipsoid(m, V3(0.8, 0.8, 0.8) * s, CF(c + V3(math.cos(a) * 3.4, -0.6 + k * 0.5, math.sin(a) * 3.4) * s), { 240, 70, 80 })
			end
		end
	end
	return m
end

function Decor.Rock(parent, pos, T, s, color)
	-- округлые валуны с текстурой камня
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Rock"
	m.Parent = parent
	local col = MK.C(color or T.Rock)
	-- гранёные камни
	solid(MK.Facet(m, V3(4.2, 3.2, 3.8) * s, pos + V3(0, 1.0 * s, 0), col, rng, { Material = "Slate" }))
	MK.Facet(m, V3(2.6, 2, 2.4) * s, pos + V3(2.2 * s, 0.5 * s, 1 * s), MK.Shade(col, -0.12), rng, { Material = "Slate" })
	MK.Facet(m, V3(1.7, 1.3, 1.6) * s, pos + V3(-2.2 * s, 0.35 * s, -0.8 * s), MK.Shade(col, 0.1), rng, { Material = "Slate" })
	return m
end

function Decor.Crystal(parent, pos, color, s, light)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Crystal"
	m.Parent = parent
	for i = 1, 4 do
		local h = (2.5 + rng:NextNumber() * 3) * s
		local tilt = ANG(rad(rng:NextInteger(-25, 25)), rad(rng:NextInteger(0, 360)), rad(rng:NextInteger(-25, 25)))
		local base = pos + V3(rng:NextNumber() * 2 - 1, 0, rng:NextNumber() * 2 - 1) * s
		local cf = CF(base) * tilt
		MK.Part(m, V3(0.9 * s, h, 0.9 * s), cf * CF(0, h / 2, 0) * ANG(0, rad(45), 0), color, { Material = "Glass", Transparency = 0.1 })
		MK.Part(m, V3(0.64 * s, 0.64 * s, 0.64 * s), cf * CF(0, h, 0) * ANG(rad(45), rad(45), 0), MK.Shade(color, 0.3), { Material = "Neon" })
	end
	if light then
		MK.Light(m:FindFirstChildWhichIsA("BasePart"), color, 14, 1.1)
	end
	return m
end

function Decor.Lamp(parent, pos, T, h)
	h = h or 7
	local m = Instance.new("Model")
	m.Name = "Lamp"
	m.Parent = parent
	solid(MK.Cylinder(m, h, 0.5, CF(pos + V3(0, h / 2, 0)) * ANG(0, 0, rad(90)), { 50, 46, 56 }))
	MK.Part(m, V3(1.6, 0.3, 1.6), CF(pos + V3(0, 0.15, 0)), { 50, 46, 56 })
	local lamp = MK.Part(m, V3(1.1, 1.3, 1.1), CF(pos + V3(0, h + 0.5, 0)), T.Lamp, { Material = "Neon" })
	MK.Wedge(m, V3(1.6, 0.6, 0.8), CF(pos + V3(0, h + 1.45, -0.4)) * ANG(0, rad(180), 0), { 50, 46, 56 })
	MK.Wedge(m, V3(1.6, 0.6, 0.8), CF(pos + V3(0, h + 1.45, 0.4)), { 50, 46, 56 })
	MK.Light(lamp, T.Lamp, 18, 1.3)
	return m
end

function Decor.Fence(parent, a, b, T)
	local m = Instance.new("Model")
	m.Name = "Fence"
	m.Parent = parent
	local dir = (b - a)
	local n = math.max(1, math.floor(dir.Magnitude / 6))
	for i = 0, n do
		local p = a + dir * (i / n)
		MK.Part(m, V3(0.7, 3, 0.7), CF(p + V3(0, 1.5, 0)), T.Trunk)
		MK.Part(m, V3(0.9, 0.3, 0.9), CF(p + V3(0, 3.1, 0)), MK.Shade(T.Trunk, 0.2))
	end
	for _, y in ipairs({ 1.1, 2.3 }) do
		solid(MK.Beam(m, a + V3(0, y, 0), b + V3(0, y, 0), 0.35, MK.Shade(T.Trunk, 0.15)))
	end
	return m
end

function Decor.Crate(parent, pos, T, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Crate"
	m.Parent = parent
	local ang = rng:NextInteger(0, 90)
	local cf = CF(pos + V3(0, 1.5 * s, 0)) * ANG(0, rad(ang), 0)
	solid(MK.Part(m, V3(3, 3, 3) * s, cf, { 196, 140, 84 }))
	for _, f in ipairs({ { 0, 0, -1.52 }, { 0, 0, 1.52 }, { 1.52, 0, 0 }, { -1.52, 0, 0 } }) do
		local o = V3(f[1], f[2], f[3]) * s
		local size = (f[1] ~= 0) and V3(0.1, 2.7, 0.5) or V3(0.5, 2.7, 0.1)
		MK.Part(m, size * V3(1, s, 1), cf * CF(o) * ANG(0, 0, rad(45)), { 150, 100, 56 })
	end
	return m
end

function Decor.Flowers(parent, pos, colors)
	for i = 1, 5 do
		local p = pos + V3(rng:NextNumber() * 4 - 2, 0, rng:NextNumber() * 4 - 2)
		MK.Cylinder(parent, 0.8, 0.12, CF(p + V3(0, 0.4, 0)) * ANG(0, 0, rad(90)), { 80, 150, 60 })
		local c = colors[rng:NextInteger(1, #colors)]
		MK.Ellipsoid(parent, V3(0.7, 0.35, 0.7), CF(p + V3(0, 0.85, 0)), c)
		MK.Ellipsoid(parent, V3(0.25, 0.25, 0.25), CF(p + V3(0, 0.98, 0)), { 255, 220, 70 })
	end
end

function Decor.Bones(parent, pos, T, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Ribcage"
	m.Parent = parent
	local bone = { 246, 238, 216 }
	MK.Beam(m, pos + V3(0, 1, -7 * s), pos + V3(0, 2.5, 7 * s), 1.2 * s, bone)
	for i = -3, 3 do
		local z = i * 2 * s
		for _, side in ipairs({ -1, 1 }) do
			local p0 = pos + V3(0, 2.5, z)
			local p1 = pos + V3(side * 3.5 * s, 6 * s, z)
			local p2 = pos + V3(side * 5 * s, 0.5, z)
			MK.CylinderBetween(m, p0, p1, 0.7 * s, bone)
			MK.CylinderBetween(m, p1, p2, 0.65 * s, bone)
		end
	end
	return m
end

function Decor.LavaPool(parent, pos, s)
	s = s or 1
	MK.Disc(parent, 0.2, 10 * s, pos + V3(0, 0.05, 0), { 255, 110, 20 }, { Material = "Neon" })
	MK.Disc(parent, 0.3, 12 * s, pos + V3(0, 0.0, 0), { 40, 30, 34 })
	local glow = MK.Disc(parent, 0.1, 7 * s, pos + V3(0, 0.12, 0), { 255, 200, 60 }, { Material = "Neon" })
	MK.Light(glow, { 255, 120, 30 }, 16, 1.5)
end

function Decor.Snowman(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Snowman"
	m.Parent = parent
	solid(MK.Ellipsoid(m, V3(4, 3.6, 4), CF(pos + V3(0, 1.8, 0)), { 250, 252, 255 }))
	MK.Ellipsoid(m, V3(3, 2.8, 3), CF(pos + V3(0, 4.6, 0)), { 250, 252, 255 })
	MK.Ellipsoid(m, V3(2.2, 2.1, 2.2), CF(pos + V3(0, 6.8, 0)), { 250, 252, 255 })
	MK.Part(m, V3(2.4, 0.2, 2.4), CF(pos + V3(0, 7.8, 0)), { 40, 40, 50 })
	MK.Part(m, V3(1.6, 1.2, 1.6), CF(pos + V3(0, 8.5, 0)), { 40, 40, 50 })
	MK.CylinderBetween(m, pos + V3(0, 6.8, -1), pos + V3(0, 6.7, -2), 0.3, { 255, 140, 40 })
	for _, x in ipairs({ -0.4, 0.4 }) do
		MK.Ellipsoid(m, V3(0.25, 0.3, 0.2), CF(pos + V3(x, 7.2, -1.0)), { 30, 30, 40 })
	end
	MK.Ellipsoid(m, V3(3.2, 0.6, 3.2), CF(pos + V3(0, 5.8, 0)), { 230, 60, 70 })
	return m
end

function Decor.FloatingShard(parent, pos, color, s)
	local p = MK.Part(parent, V3(2, 5, 2) * s, CF(pos) * ANG(rad(15), rad(45), rad(10)), color, { Material = "Glass", Transparency = 0.1 })
	CollectionService:AddTag(p, "Float")
	MK.Part(parent, V3(1, 1, 1) * s, CF(pos + V3(0, 3 * s, 0)) * ANG(rad(45), rad(45), 0), MK.Shade(color, 0.3), { Material = "Neon" })
	return p
end

function Decor.MineCart(parent, pos, angleY, T)
	local m = Instance.new("Model")
	m.Name = "MineCart"
	m.Parent = parent
	local cf = CF(pos) * ANG(0, rad(angleY), 0)
	for i = -4, 4 do
		MK.Part(m, V3(5, 0.3, 0.8), cf * CF(0, 0.15, i * 2), T.Trunk)
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		MK.Part(m, V3(0.35, 0.35, 18), cf * CF(x, 0.45, 0), { 120, 120, 130 }, { Material = "Metal" })
	end
	solid(MK.Part(m, V3(3.8, 2.2, 4.6), cf * CF(0, 2.0, 0), { 120, 90, 70 }))
	MK.Part(m, V3(4.0, 0.4, 4.8), cf * CF(0, 3.2, 0), { 90, 90, 100 }, { Material = "Metal" })
	for _, x in ipairs({ -1.9, 1.9 }) do
		for _, z in ipairs({ -1.5, 1.5 }) do
			MK.Cylinder(m, 0.4, 1.2, cf * CF(x, 0.9, z), { 50, 50, 56 })
		end
	end
	for i = 1, 5 do
		MK.Part(m, V3(1, 1, 1), cf * CF(rng:NextNumber() * 2 - 1, 3.4 + rng:NextNumber() * 0.4, rng:NextNumber() * 2.4 - 1.2) * ANG(rng:NextNumber(), rng:NextNumber(), 0), T.Crystal, { Material = "Neon" })
	end
	return m
end

---------------------------------------------------------------------------------------------
-- Остров: земля, шахта, стены
---------------------------------------------------------------------------------------------
local function buildIsland(b, folder, O, biome)
	local T = biome.Theme
	local island = Instance.new("Folder")
	island.Name = "Island"
	island.Parent = folder

	-- Плиты земли вокруг шахты и база. Верх земли = Y 0.
	local plates = {
		{ -110, 110, -200, -88 }, -- база (север)
		{ -110, 110, 88, 112 },   -- юг
		{ 88, 110, -88, 88 },     -- восток
		{ -110, -88, -88, 88 },   -- запад
	}
	for _, r in ipairs(plates) do
		local sx, sz = r[2] - r[1], r[4] - r[3]
		local c = O + V3((r[1] + r[2]) / 2, 0, (r[3] + r[4]) / 2)
		local top = solid(MK.Part(island, V3(sx, 2, sz), CF(c + V3(0, -1, 0)), T.Ground, { Name = "Ground" }))
		top.CastShadow = false
		solid(MK.Part(island, V3(sx, 12, sz), CF(c + V3(0, -8, 0)), T.Cliff))
		-- скошенный край — имитация bevel по периметру острова
		MK.Part(island, V3(sx + 0.6, 0.6, sz + 0.6), CF(c + V3(0, -2.2, 0)), T.GroundDark)
	end
	-- Стены шахты (неразрушимые, 8 studs)
	local wallH = DEPTH + 8
	local wallY = -wallH / 2
	local walls = {
		{ V3(2 * HALF + 2 * WALL, wallH, WALL), V3(0, wallY, -(HALF + WALL / 2)) },
		{ V3(2 * HALF + 2 * WALL, wallH, WALL), V3(0, wallY, HALF + WALL / 2) },
		{ V3(WALL, wallH, 2 * HALF), V3(HALF + WALL / 2, wallY, 0) },
		{ V3(WALL, wallH, 2 * HALF), V3(-(HALF + WALL / 2), wallY, 0) },
	}
	for _, w in ipairs(walls) do
		local p = solid(MK.Part(island, w[1], CF(O + w[2]), T.Wall, { Name = "Bedrock" }))
		p:SetAttribute("Bedrock", true)
	end
	local floor = solid(MK.Part(island, V3(2 * HALF + 2 * WALL, 8, 2 * HALF + 2 * WALL), CF(O + V3(0, -DEPTH - 4, 0)), MK.Shade(T.Wall, -0.2), { Name = "BedrockFloor" }))
	floor:SetAttribute("Bedrock", true)
	-- светящаяся кромка по верху стен
	for _, e in ipairs({ { V3(2 * HALF, 0.3, 0.6), V3(0, 0.15, -HALF - 0.3) }, { V3(2 * HALF, 0.3, 0.6), V3(0, 0.15, HALF + 0.3) }, { V3(0.6, 0.3, 2 * HALF), V3(HALF + 0.3, 0.15, 0) }, { V3(0.6, 0.3, 2 * HALF), V3(-HALF - 0.3, 0.15, 0) } }) do
		MK.Part(island, e[1], CF(O + e[2]), T.Trim)
	end
	-- внешние грани, страты и горные кромки строит WorldScenery (расширенный остров)
	local outerBox = { { V3(220, DEPTH - 4, 22), V3(0, -12 - (DEPTH - 4) / 2 + 2, 100) }, { V3(22, DEPTH - 4, 176), V3(99, -12 - (DEPTH - 4) / 2 + 2, 0) }, { V3(22, DEPTH - 4, 176), V3(-99, -12 - (DEPTH - 4) / 2 + 2, 0) } }
	for _, r in ipairs(outerBox) do
		MK.Part(island, r[1], CF(O + r[2]), T.CliffDark)
	end

	-- Фонари на стенах внутри шахты
	for _, y in ipairs({ -28, -58, -88, -118 }) do
		for _, f in ipairs({ { V3(0, 0, -1), V3(0, 0, -HALF) }, { V3(0, 0, 1), V3(0, 0, HALF) }, { V3(1, 0, 0), V3(HALF, 0, 0) }, { V3(-1, 0, 0), V3(-HALF, 0, 0) } }) do
			for _, t in ipairs({ -40, 40 }) do
				local along = (f[1].X ~= 0) and V3(0, 0, t) or V3(t, 0, 0)
				local pos = O + f[2] + along + V3(0, y, 0) - f[1] * 0.4
				local bracket = MK.Part(island, V3(1.2, 0.4, 1.2), CF(pos), { 50, 46, 56 })
				local lamp = MK.Part(island, V3(0.9, 1.2, 0.9), CF(pos - f[1] * 0.5 + V3(0, -0.8, 0)), T.Lamp, { Material = "Neon" })
				MK.Light(lamp, T.Lamp, 22, 1.4)
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Дроп-поды (10 мостиков)
---------------------------------------------------------------------------------------------
local function buildPods(b, folder, O, biome)
	local T = biome.Theme
	local pods = {}
	local defs = {
		{ V3(-50, 0, HALF + 2), V3(0, 0, -1) }, { V3(0, 0, HALF + 2), V3(0, 0, -1) }, { V3(50, 0, HALF + 2), V3(0, 0, -1) },
		{ V3(HALF + 2, 0, -45), V3(-1, 0, 0) }, { V3(HALF + 2, 0, 5), V3(-1, 0, 0) }, { V3(HALF + 2, 0, 50), V3(-1, 0, 0) },
		{ V3(-HALF - 2, 0, -45), V3(1, 0, 0) }, { V3(-HALF - 2, 0, 5), V3(1, 0, 0) }, { V3(-HALF - 2, 0, 50), V3(1, 0, 0) },
		{ V3(52, 0, -HALF - 2), V3(0, 0, 1) },
	}
	local podFolder = Instance.new("Folder")
	podFolder.Name = "DropPods"
	podFolder.Parent = folder
	for i, d in ipairs(defs) do
		local pos = O + d[1]
		local inward = d[2]
		local m = Instance.new("Model")
		m.Name = "Pod" .. i
		m.Parent = podFolder
		local center = pos + inward * 2 + V3(0, 0.5, 0)
		solid(MK.Disc(m, 1, 12, center, { 70, 70, 84 }))
		MK.Disc(m, 0.2, 9.5, center + V3(0, 0.55, 0), T.Accent, { Material = "Neon" })
		MK.Disc(m, 0.25, 8.6, center + V3(0, 0.6, 0), { 60, 60, 74 })
		MK.Disc(m, 0.8, 12.6, center + V3(0, -0.3, 0), T.Trim)
		-- арка
		local side = V3(inward.Z, 0, -inward.X)
		for _, s in ipairs({ -1, 1 }) do
			local post = pos - inward * 3 + side * s * 5
			MK.Part(m, V3(1, 8, 1), CF(post + V3(0, 4, 0)), { 60, 60, 74 })
			MK.Part(m, V3(1.3, 0.6, 1.3), CF(post + V3(0, 8.2, 0)), T.Accent, { Material = "Neon" })
		end
		local beam = MK.Part(m, V3(11, 1.6, 0.6), CFrame.lookAt(pos - inward * 3 + V3(0, 8.6, 0), pos - inward * 3 + V3(0, 8.6, 0) + inward), T.Accent)
		MK.Sign(beam, Enum.NormalId.Front, "ПОД " .. i, Color3.new(1, 1, 1))
		MK.Sign(beam, Enum.NormalId.Back, "ПОД " .. i, Color3.new(1, 1, 1))
		local spawnCf = CFrame.lookAt(center + V3(0, 3.5, 0), center + V3(0, 3.5, 0) + inward)
		table.insert(pods, spawnCf)
	end
	return pods
end

---------------------------------------------------------------------------------------------
-- Станции базы
---------------------------------------------------------------------------------------------
-- Продажа: «Золотой обменник» — круглый киоск с гигантской вращающейся монетой и кучами золота.
-- Перед ним светящаяся ЗОНА ПРОДАЖИ: зашёл в круг — руда продаётся сама (без кнопок).
local function buildSell(folder, pos, center, biome)
	local T = biome.Theme
	local m = Instance.new("Model")
	m.Name = "SellStation"
	m.Parent = folder
	local cf = faceCenter(pos, center)
	local gold, goldD = { 255, 200, 50 }, { 220, 150, 30 }
	local body = MK.C(T.UI)
	-- основание киоска (позади зоны)
	local kc = cf * CF(0, 0, 6)
	solid(MK.Disc(m, 1.2, 17, (kc * CF(0, 0.6, 0)).Position, { 236, 228, 214 }))
	MK.Disc(m, 0.5, 17.6, (kc * CF(0, 1.1, 0)).Position, gold)
	local kiosk = solid(MK.Disc(m, 7, 10, (kc * CF(0, 4.6, 0)).Position, body))
	-- белые полосы на корпусе
	for k = 0, 7 do
		local a = k * math.pi / 4
		MK.Part(m, V3(0.5, 7, 1.2), kc * CF(math.cos(a) * 5, 4.6, math.sin(a) * 5) * ANG(0, -a, 0), { 255, 255, 255 })
	end
	MK.Disc(m, 0.8, 11, (kc * CF(0, 8.4, 0)).Position, gold)
	-- окошко-прилавок
	local win = MK.Part(m, V3(5, 2.6, 0.4), kc * CF(0, 4.8, -4.85), { 30, 26, 46 })
	local _, label = MK.Sign(win, Enum.NormalId.Front, "x" .. tostring(biome.SellMult or 1), gold)
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	MK.Part(m, V3(6, 0.5, 1.6), kc * CF(0, 3.3, -5.3), gold)
	-- купол и вращающаяся монета
	MK.Ellipsoid(m, V3(10, 5, 10), kc * CF(0, 8.8, 0), MK.Shade(body, 0.15))
	local coin = Instance.new("Model")
	coin.Name = "BigCoin"
	coin.Parent = m
	local coinBase = CF((kc * CF(0, 16, 0)).Position) * ANG(rad(90), 0, 0)
	local face = MK.Cylinder(coin, 1.4, 8.5, coinBase, gold, { Material = "SmoothPlastic" })
	MK.Cylinder(coin, 1.6, 6.4, coinBase, goldD, { Material = "SmoothPlastic" })
	MK.Cylinder(coin, 1.8, 3.4, coinBase, { 255, 236, 140 }, { Material = "Neon" })
	coin.PrimaryPart = face
	coin:SetAttribute("Base", coinBase)
	coin:SetAttribute("SpinSpeed", 1.4)
	CollectionService:AddTag(coin, "Spin")
	MK.Light(face, gold, 22, 1.5)
	local sp = MK.Sparkles(face, gold, 6, 0.5)
	sp.Name = "CoinSparkle"
	-- кучи монет и сундуки
	for i, off in ipairs({ { -8, 0, 4 }, { 8, 0, 3 }, { -6, 0, 9 }, { 7, 0, 9 } }) do
		local p0 = kc * CF(off[1], 0, off[3])
		for k = 0, 3 do
			MK.Cylinder(m, 0.5, 2.4 - k * 0.35, p0 * CF(0, 0.35 + k * 0.5, 0) * ANG(0, 0, rad(90)), (k % 2 == 0) and gold or goldD)
		end
		if i <= 2 then
			local chest = p0 * CF(0, 0, -2.6) * ANG(0, rad(i * 25), 0)
			solid(MK.Part(m, V3(3, 2, 2.2), chest * CF(0, 1, 0), { 150, 96, 56 }, { Material = "Wood" }))
			MK.Part(m, V3(3.1, 0.4, 2.3), chest * CF(0, 1.7, 0), gold)
			MK.Ellipsoid(m, V3(2.6, 1.2, 1.9), chest * CF(0, 2.2, 0), gold)
		end
	end
	-- большие буквы
	MK.Text3D(m, "ПРОДАЖА", kc * CF(0, 23, 0) * ANG(rad(-6), 0, 0), 5.5, { 255, 210, 50 }, { 210, 110, 20 }, { Outline = { 255, 255, 255 }, Gradient = { { 255, 240, 120 }, { 255, 170, 30 } } })
	-- ЗОНА ПРОДАЖИ: свой круглый подиум, чтобы свечение не сливалось с землёй ни на одном ярусе
	local zpos = (cf * CF(0, 0, -6)).Position
	solid(MK.Disc(m, 0.9, 21, zpos + V3(0, 0.45, 0), { 236, 228, 214 }, { Material = "Marble" }))
	MK.Disc(m, 0.5, 21.6, zpos + V3(0, 0.25, 0), goldD)
	local ring = MK.Disc(m, 0.12, 19.4, zpos + V3(0, 0.96, 0), { 255, 255, 255 }, { Material = "Neon" })
	ring.CanCollide = false
	ring.CastShadow = false
	local pad = MK.Disc(m, 0.12, 17.4, zpos + V3(0, 0.99, 0), gold, { Material = "Neon", Transparency = 0.25, Name = "SellPad" })
	pad.CanCollide = false
	pad.CanTouch = false
	pad.CastShadow = false
	CollectionService:AddTag(pad, "Pulse")
	MK.Light(pad, gold, 18, 1.2)
	-- монетки по кругу
	for k = 0, 7 do
		local a0 = k * math.pi / 4
		MK.Cylinder(m, 0.25, 1.6, CF(zpos + V3(math.cos(a0) * 10.1, 0.95, math.sin(a0) * 10.1)) * ANG(0, 0, rad(90)), gold)
	end
	pad:SetAttribute("Radius", 9)
	return m, pad, zpos
end

-- Магазин — настоящий домик: фахверковые стены, двускатная крыша, окна со светом, фонари.
-- Перед дверью — светящаяся зона покупки: окно магазина открывается, только когда игрок
-- в неё зашёл (клиент проверяет тег ShopZone), и закрывается, когда вышел.
local function buildShop(folder, pos, center, biome, title, kind, color, display)
	local T = biome.Theme
	local m = Instance.new("Model")
	m.Name = kind == "Drill" and "DrillShop" or "PackShop"
	m.Parent = folder
	local cf = faceCenter(pos, center)
	local W, D, H, Hr = 20, 16, 10, 6
	local hc = cf * CF(0, 0, 6) -- центр дома (дом стоит позади точки, зона — перед ним)
	local zf = -D / 2           -- передняя стена (локальная Z)
	local plaster = MK.C(color):Lerp(Color3.new(1, 0.97, 0.92), 0.72)
	local timber = { 104, 72, 52 }
	local roofCol = color
	local stone = { 132, 128, 140 }
	local function P(size, lcf, col, props)
		return MK.Part(m, size, hc * lcf, col, props)
	end
	local function S(size, lcf, col, props)
		return solid(P(size, lcf, col, props))
	end
	-- фундамент и крыльцо
	S(V3(W + 2, 1.4, D + 2), CF(0, 0.7, 0), stone, { Material = "Cobblestone" })
	S(V3(8, 0.8, 3), CF(0, 0.4, zf - 2), MK.Shade(stone, 0.08), { Material = "Cobblestone" })
	-- стены
	S(V3(W, H, 1), CF(0, 1.4 + H / 2, D / 2), plaster, { Material = "Plaster" })
	for _, sx in ipairs({ -1, 1 }) do
		S(V3(1, H, D), CF(sx * W / 2, 1.4 + H / 2, 0), plaster, { Material = "Plaster" })
	end
	-- передняя стена с дверным проёмом 6 x 7.5
	local dw, dh = 6, 7.5
	for _, sx in ipairs({ -1, 1 }) do
		S(V3((W - dw) / 2, H, 1), CF(sx * (dw / 2 + (W - dw) / 4), 1.4 + H / 2, zf), plaster, { Material = "Plaster" })
	end
	S(V3(dw, H - dh, 1), CF(0, 1.4 + dh + (H - dh) / 2, zf), plaster, { Material = "Plaster" })
	-- тёмный интерьер за проёмом и тёплый свет
	local inside = P(V3(W - 2, 0.3, D - 2), CF(0, 1.55, 0), { 120, 86, 60 }, { Material = "WoodPlanks" })
	MK.Light(inside, { 255, 200, 130 }, 18, 1.2)
	-- прилавок внутри
	S(V3(10, 3.2, 2.4), CF(0, 3, 3), MK.Shade(color, -0.2), { Material = "Wood" })
	-- фахверк: стойки и балки
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			P(V3(1.3, H, 1.3), CF(sx * W / 2, 1.4 + H / 2, sz * D / 2), timber, { Material = "Wood" })
		end
		P(V3(0.8, H, 0.4), CF(sx * (dw / 2 + 0.4), 1.4 + H / 2, zf - 0.6), timber, { Material = "Wood" })
		P(V3(1.2, H, 0.4), CF(sx * (W / 2 - 0.2), 1.4 + H / 2, zf - 0.6), timber, { Material = "Wood" })
	end
	P(V3(W + 1, 0.8, 0.5), CF(0, 1.4 + H, zf - 0.6), timber, { Material = "Wood" })
	P(V3(W + 1, 0.6, 0.5), CF(0, 1.4 + 0.3, zf - 0.6), timber, { Material = "Wood" })
	P(V3(dw + 1.6, 0.7, 0.5), CF(0, 1.4 + dh + 0.35, zf - 0.6), timber, { Material = "Wood" })
	-- диагональные раскосы
	for _, sx in ipairs({ -1, 1 }) do
		local x0 = sx * (dw / 2 + 0.8)
		local x1 = sx * (W / 2 - 0.8)
		local a = (hc * CF(x0, 1.9, zf - 0.6)).Position
		local bpos = (hc * CF(x1, 1.4 + H - 0.5, zf - 0.6)).Position
		MK.Beam(m, a, bpos, 0.45, timber, { Material = "Wood" })
	end
	-- окна (светятся тёплым)
	local function window(wcf, wdt)
		MK.Part(m, V3(wdt + 0.8, 3.8, 0.4), wcf, timber, { Material = "Wood" })
		local glass = MK.Part(m, V3(wdt, 3, 0.2), wcf * CF(0, 0, -0.15), { 255, 214, 140 }, { Material = "Neon", Transparency = 0.15 })
		MK.Part(m, V3(0.25, 3, 0.3), wcf * CF(0, 0, -0.25), timber)
		MK.Part(m, V3(wdt, 0.25, 0.3), wcf * CF(0, 0, -0.25), timber)
		-- ящик с цветами
		MK.Part(m, V3(wdt + 1, 0.8, 1.2), wcf * CF(0, -2.3, -0.6), { 150, 96, 60 }, { Material = "Wood" })
		for k = -1, 1 do
			MK.Ellipsoid(m, V3(1.2, 0.9, 1), wcf * CF(k * (wdt / 3), -1.7, -0.7), { 96, 176, 70 }, { Material = "Grass" })
			MK.Ellipsoid(m, V3(0.45, 0.45, 0.45), wcf * CF(k * (wdt / 3) + 0.2, -1.4, -1.1), k == 0 and { 255, 120, 160 } or { 255, 214, 80 })
		end
		return glass
	end
	for _, sx in ipairs({ -1, 1 }) do
		window(hc * CF(sx * (dw / 2 + (W - dw) / 4), 1.4 + 5.6, zf - 0.55), 3.2)
		window(hc * CF(sx * (W / 2 + 0.55), 1.4 + 5.6, 0) * ANG(0, sx * rad(90), 0) * ANG(0, rad(180), 0), 3.6)
	end
	-- двускатная крыша (конёк вдоль глубины дома) + ряды черепицы
	for _, sx in ipairs({ -1, 1 }) do
		local half = MK.Wedge(m, V3(D + 3, Hr, W / 2 + 1.4), hc * CF(sx * (W / 4 + 0.7), 1.4 + H + Hr / 2, 0) * ANG(0, -sx * rad(90), 0), MK.Shade(roofCol, -0.35), { Material = "SmoothPlastic" })
		solid(half)
		local run, rise = W / 2 + 1.4, Hr
		local len = math.sqrt(run * run + rise * rise)
		local ang = math.atan2(rise, run)
		local ROWS = 7
		for r = 0, ROWS - 1 do
			local t = (r + 0.5) / ROWS
			local x = sx * (run * (1 - t))
			local y = 1.4 + H + rise * t
			local col = (r % 2 == 0) and MK.C(roofCol) or MK.Shade(roofCol, -0.12)
			MK.Part(m, V3(len / ROWS * 1.25, 0.55, D + 3.4), hc * CF(x, y + 0.32, 0) * ANG(0, 0, sx * -ang) * CF(0, 0, 0) * ANG(0, 0, sx * rad(-4)), col, { Material = "SmoothPlastic" })
		end
		-- фронтоны
		for _, sz in ipairs({ -1, 1 }) do
			MK.Wedge(m, V3(1, Hr, W / 2), hc * CF(sx * W / 4, 1.4 + H + Hr / 2, sz * (D / 2)) * ANG(0, -sx * rad(90), 0), plaster, { Material = "Plaster" })
		end
	end
	P(V3(1.2, 1.2, D + 3.4), CF(0, 1.4 + H + Hr + 0.1, 0), MK.Shade(roofCol, -0.3), { Material = "Wood" })
	-- круглое окошко во фронтоне
	MK.Disc(m, 0.4, 2.6, (hc * CF(0, 1.4 + H + 2.2, zf - 0.6)).Position, { 255, 214, 140 }, { Material = "Neon" }).CFrame = hc * CF(0, 1.4 + H + 2.2, zf - 0.6) * ANG(0, rad(90), 0)
	-- труба
	S(V3(2.2, 5, 2.2), CF(W / 4 + 1, 1.4 + H + Hr - 0.5, D / 4), { 160, 90, 70 }, { Material = "Brick" })
	-- навес над дверью
	MK.Wedge(m, V3(dw + 3, 1.4, 3), hc * CF(0, 1.4 + dh + 1.5, zf - 1.9), color, { Material = "Fabric" })
	-- вывеска и большие объёмные буквы над крышей
	local sign = P(V3(12, 2.8, 0.6), CF(0, 1.4 + H + 0.2, zf - 1.1), { 44, 36, 56 }, { Material = "Wood" })
	MK.Sign(sign, Enum.NormalId.Front, title, Color3.fromRGB(255, 236, 170))
	P(V3(12.8, 3.4, 0.4), CF(0, 1.4 + H + 0.2, zf - 0.85), color, { Material = "Wood" })
	MK.Text3D(m, title, hc * CF(0, 1.4 + H + Hr + 4.5, zf + 2) * ANG(rad(-8), 0, 0), 5.5, MK.Shade(color, 0.25), MK.Shade(color, -0.45), { Outline = { 255, 255, 255 } })
	-- фонари у двери
	for _, sx in ipairs({ -1, 1 }) do
		local lp = hc * CF(sx * (dw / 2 + 2.2), 0, zf - 3.4)
		solid(MK.Part(m, V3(0.6, 6.5, 0.6), lp * CF(0, 1.4 + 3.25, 0), { 50, 44, 60 }, { Material = "Metal" }))
		local lamp = MK.Part(m, V3(1.3, 1.5, 1.3), lp * CF(0, 1.4 + 7.1, 0), { 255, 216, 140 }, { Material = "Neon" })
		MK.Part(m, V3(1.8, 0.4, 1.8), lp * CF(0, 1.4 + 8, 0), { 50, 44, 60 }, { Material = "Metal" })
		MK.Light(lamp, { 255, 200, 120 }, 16, 1.3)
	end

	-- ЗОНА ПОКУПКИ
	local zcf = cf * CF(0, 0, -10)
	local ZW, ZD = 14, 11
	-- подиум под зоной (чтобы свечение не сливалось с землёй)
	solid(MK.Part(m, V3(ZW + 1.6, 0.6, ZD + 1.6), zcf * CF(0, 0.3, 0), { 236, 228, 214 }, { Material = "Marble" }))
	local pad = MK.Part(m, V3(ZW, 0.1, ZD), zcf * CF(0, 0.64, 0), color, { Material = "Neon", Transparency = 0.35 })
	pad.CanCollide = false
	pad.CastShadow = false
	CollectionService:AddTag(pad, "Pulse")
	for _, e in ipairs({ { V3(ZW + 0.6, 0.2, 0.6), CF(0, 0.66, -ZD / 2) }, { V3(ZW + 0.6, 0.2, 0.6), CF(0, 0.66, ZD / 2) }, { V3(0.6, 0.2, ZD), CF(-ZW / 2, 0.66, 0) }, { V3(0.6, 0.2, ZD), CF(ZW / 2, 0.66, 0) } }) do
		local edge = MK.Part(m, e[1], zcf * e[2], { 255, 255, 255 }, { Material = "Neon" })
		edge.CanCollide = false
		edge.CastShadow = false
	end
	local zone = MK.Part(m, V3(ZW, 10, ZD), zcf * CF(0, 5, 0), { 255, 255, 255 }, { Transparency = 1 })
	zone.Name = "ShopZone"
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	zone:SetAttribute("Kind", kind)
	CollectionService:AddTag(zone, "ShopZone")
	-- витрина: товар крутится над зоной
	if display then
		local d = display:Clone()
		d.Parent = m
		for _, p in ipairs(d:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
		local disp = (zcf * CF(0, 7.5, 0)).Position
		d:PivotTo(CF(disp) * ANG(rad(90), 0, 0))
		d:ScaleTo(1.6)
		CollectionService:AddTag(d, "SpinDisplay")
		d:SetAttribute("Base", CF(disp))
		local ring = MK.Disc(m, 0.3, 6, (zcf * CF(0, 0.45, 0)).Position, { 255, 255, 255 }, { Material = "Neon", Transparency = 0.3 })
		ring.CanCollide = false
	end
	return m, zone, zcf.Position
end

local function buildEggStand(folder, pos, center, biome, egg)
	local T = biome.Theme
	local m = Instance.new("Model")
	m.Name = "Egg_" .. egg.Id
	m.Parent = folder
	local premium = egg.Slot == 2
	local accent = premium and { 255, 200, 60 } or T.Accent
	local cf = faceCenter(pos, center)
	solid(MK.Disc(m, 1, 13, pos + V3(0, 0.5, 0), { 70, 66, 90 }))
	MK.Disc(m, 0.25, 11.6, pos + V3(0, 1.05, 0), accent, { Material = "Neon" })
	local ped = solid(MK.Disc(m, 3, 7.5, pos + V3(0, 2.6, 0), MK.Shade(T.Trim, -0.1)))
	MK.Disc(m, 0.6, 8.4, pos + V3(0, 4.3, 0), accent)
	for k = 0, 5 do
		local ang = k * math.pi / 3 + math.pi / 6
		local p = pos + V3(math.cos(ang) * 5.6, 0, math.sin(ang) * 5.6)
		MK.Part(m, V3(0.8, 3.5, 0.8), CF(p + V3(0, 2.4, 0)), { 70, 68, 86 })
		MK.Ellipsoid(m, V3(1.1, 1.1, 1.1), CF(p + V3(0, 4.5, 0)), accent, { Material = "Neon" })
	end
	local eggModel = GearBuilder.Egg(egg, 1.35)
	eggModel.Parent = m
	local eggCf = CF(pos + V3(0, 8.0, 0))
	eggModel:PivotTo(eggCf)
	CollectionService:AddTag(eggModel, "EggDisplay")
	eggModel:SetAttribute("Base", eggCf)
	-- табличка на подставке: название и цена (не летает над яйцом)
	local board = MK.Part(m, V3(9, 3.4, 0.5), cf * CF(0, 2.1, -6.9) * ANG(rad(-12), 0, 0), { 40, 34, 56 })
	solid(board)
	MK.Part(m, V3(9.6, 3.9, 0.35), cf * CF(0, 2.1, -6.7) * ANG(rad(-12), 0, 0), accent)
	for _, sx in ipairs({ -1, 1 }) do
		MK.Part(m, V3(0.5, 2.4, 0.5), cf * CF(sx * 3.8, 0.8, -6.6), { 60, 54, 76 })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(360, 136)
	gui.LightInfluence = 0.1
	gui.MaxDistance = 110
	gui.Parent = board
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -20, 0.5, -6)
	name.Position = UDim2.fromOffset(10, 6)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Text = egg.Name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = gui
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(20, 16, 30)
	st.Parent = name
	local pricePill = Instance.new("Frame")
	pricePill.Size = UDim2.new(0.8, 0, 0.42, 0)
	pricePill.Position = UDim2.new(0.1, 0, 0.53, 0)
	pricePill.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
	pricePill.Parent = gui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(1, 0)
	pc.Parent = pricePill
	local price = name:Clone()
	price.Size = UDim2.new(1, -16, 1, -8)
	price.Position = UDim2.fromOffset(8, 4)
	price.Text = Util.Format(egg.Price) .. " монет"
	price.Parent = pricePill
	prompt(ped, "Открыть яйцо", egg.Name, "Egg", { EggId = egg.Id })
	return m, pos
end

local function buildIncubator(folder, pos, center, biome)
	local T = biome.Theme
	local m = Instance.new("Model")
	m.Name = "BioChamber"
	m.Parent = folder
	local green = { 110, 255, 140 }
	-- возвышенность: ступенчатый холм-подиум, на который ведут пологие ступени (0.8 студа)
	local tiers = 6
	for i = 0, tiers - 1 do
		local d = 30 - i * 3
		local col = (i % 2 == 0) and MK.Shade(T.Rock or { 150, 150, 160 }, 0.1) or MK.Shade(T.Rock or { 150, 150, 160 }, -0.05)
		solid(MK.Disc(m, 0.8, d, pos + V3(0, 0.4 + i * 0.8, 0), col, { Material = (i % 2 == 0) and "Slate" or "Cobblestone" }))
	end
	MK.Disc(m, 0.2, 30 - (tiers - 1) * 3 + 0.4, pos + V3(0, tiers * 0.8 - 0.25, 0), MK.Shade(T.Leaves or { 120, 200, 90 }, 0.05))
	local lift = tiers * 0.8
	-- столб света, видно издалека
	local beam = MK.Disc(m, 60, 3.4, pos + V3(0, lift + 30, 0), green, { Material = "Neon", Transparency = 0.82 })
	beam.CastShadow = false
	CollectionService:AddTag(beam, "Pulse")
	-- кольцо-ореол над куполом
	local halo = Instance.new("Model")
	halo.Name = "Halo"
	halo.Parent = m
	local hc = CF(pos + V3(0, lift + 17, 0)) * ANG(rad(90), 0, 0)
	local hp = MK.Part(halo, V3(0.2, 0.2, 0.2), hc, green, { Transparency = 1 })
	for k = 0, 9 do
		local a0 = k * math.pi / 5
		MK.Part(halo, V3(2.2, 0.5, 0.5), hc * CF(math.cos(a0) * 5, math.sin(a0) * 5, 0) * ANG(0, 0, a0 + math.pi / 2), green, { Material = "Neon" }).CastShadow = false
	end
	halo.PrimaryPart = hp
	halo:SetAttribute("Base", hc)
	halo:SetAttribute("SpinSpeed", 0.8)
	CollectionService:AddTag(halo, "Spin")
	MK.Text3D(m, "ИНКУБАТОР", faceCenter(pos + V3(0, lift + 21.5, 0), center), 3.6, green, { 30, 120, 60 }, { Outline = { 255, 255, 255 } })
	pos = pos + V3(0, lift, 0)
	solid(MK.Disc(m, 1.4, 12, pos + V3(0, 0.7, 0), { 60, 64, 76 }))
	MK.Disc(m, 0.25, 10.6, pos + V3(0, 1.45, 0), green, { Material = "Neon" })
	local base = solid(MK.Disc(m, 1.6, 7.5, pos + V3(0, 2.2, 0), { 200, 206, 220 }))
	MK.Disc(m, 7, 6.2, pos + V3(0, 6.5, 0), { 210, 245, 255 }, { Material = "Glass", Transparency = 0.6 })
	local liquid = MK.Disc(m, 5.5, 5.2, pos + V3(0, 5.8, 0), green, { Material = "Neon", Transparency = 0.55 })
	MK.Light(liquid, green, 16, 1.4)
	CollectionService:AddTag(liquid, "Pulse")
	MK.Disc(m, 1.4, 7.5, pos + V3(0, 10.6, 0), { 200, 206, 220 })
	MK.Ellipsoid(m, V3(5, 2.4, 5), CF(pos + V3(0, 11.4, 0)), { 200, 206, 220 })
	MK.Ellipsoid(m, V3(1, 1, 1), CF(pos + V3(0, 12.8, 0)), green, { Material = "Neon" })
	-- семечко внутри
	local seed = MK.Ellipsoid(m, V3(1.6, 2, 1.6), CF(pos + V3(0, 6, 0)), { 140, 220, 90 })
	CollectionService:AddTag(seed, "Float")
	-- трубы
	for _, s in ipairs({ -1, 1 }) do
		local a = pos + V3(s * 4.2, 1.5, 1.5)
		local bpt = pos + V3(s * 4.2, 9.5, 1.5)
		MK.CylinderBetween(m, a, bpt, 0.8, { 150, 156, 170 })
		MK.CylinderBetween(m, bpt, pos + V3(s * 2.8, 10.4, 0.8), 0.8, { 150, 156, 170 })
	end
	prompt(base, "Инкубатор", "Био-камера", "Incubator")
	return m
end

local function buildTree(folder, pos, center, biome)
	local T = biome.Theme
	local m = Instance.new("Model")
	m.Name = "ChronoTree"
	m.Parent = folder
	local purple = { 170, 110, 255 }
	local cyan = { 100, 240, 255 }
	solid(MK.Disc(m, 1.2, 16, pos + V3(0, 0.6, 0), { 60, 50, 80 }))
	MK.Disc(m, 0.25, 14.4, pos + V3(0, 1.25, 0), purple, { Material = "Neon" })
	local trunk = { 110, 80, 120 }
	local pts = { pos + V3(0, 1, 0), pos + V3(1, 6, 0.5), pos + V3(-0.5, 11, -0.4), pos + V3(0.3, 15, 0.2) }
	for i = 1, #pts - 1 do
		solid(MK.CylinderBetween(m, pts[i], pts[i + 1], 2.6 - i * 0.4, trunk))
	end
	for i = 1, 5 do
		local d = V3(math.cos(i * 1.26), 0.55, math.sin(i * 1.26)).Unit
		local s0 = pos + V3(0, 9 + (i % 2) * 2, 0)
		MK.CylinderBetween(m, s0, s0 + d * 6, 0.9, trunk)
		local leafPos = s0 + d * 6.5 + V3(0, 1, 0)
		local leaf = MK.Part(m, V3(4, 4, 4), CF(leafPos) * ANG(rad(45), rad(i * 30), rad(45)), (i % 2 == 0) and cyan or purple, { Material = "Glass", Transparency = 0.25 })
		MK.Part(m, V3(1.6, 1.6, 1.6), CF(leafPos) * ANG(rad(45), rad(i * 30), rad(45)), { 255, 255, 255 }, { Material = "Neon" })
	end
	local crown = MK.Part(m, V3(6, 6, 6), CF(pos + V3(0, 17, 0)) * ANG(rad(45), 0, rad(45)), purple, { Material = "Glass", Transparency = 0.2 })
	MK.Light(crown, purple, 22, 1.6)
	-- кольцо-циферблат
	for k = 0, 11 do
		local ang = k * math.pi / 6
		local p = pos + V3(math.cos(ang) * 7, 12, math.sin(ang) * 7)
		local tick = MK.Part(m, V3(0.6, (k % 3 == 0) and 1.6 or 0.9, 0.3), CF(p, pos + V3(0, 12, 0)), cyan, { Material = "Neon" })
		CollectionService:AddTag(tick, "Orbit")
		tick:SetAttribute("Center", pos + V3(0, 12, 0))
	end
	local sign = MK.Part(m, V3(9, 2, 0.4), faceCenter(pos + V3(0, 3.5, 7.5), center), { 40, 34, 50 })
	MK.Sign(sign, Enum.NormalId.Front, "ХРОНО-ДРЕВО", Color3.fromRGB(210, 170, 255))
	prompt(trunk and m:FindFirstChildWhichIsA("BasePart"), "Перерождение", "Хроно-Древо", "Rebirth")
	return m
end

-- Каменная арка из гранёных блоков (как в популярных симуляторах): две колонны и полукруглый свод.
-- cf — центр основания арки, лицом в -Z. w — ширина проёма, h — высота колонн до начала свода.
local function stoneArch(m, cf, w, h, color, seed)
	local r = Random.new(seed or 7)
	local base = MK.C(color)
	local function block(c, size)
		local shade = (r:NextNumber() - 0.5) * 0.18
		local col = shade >= 0 and base:Lerp(Color3.new(1, 1, 1), shade) or base:Lerp(Color3.new(0, 0, 0), -shade)
		local p = MK.Part(m, size, c * ANG(rad(r:NextNumber(-6, 6)), rad(r:NextNumber(-8, 8)), rad(r:NextNumber(-5, 5))), col, { Material = "Slate" })
		p.CanCollide = true
		return p
	end
	local bw = 3.6
	-- колонны: блоки со смещением, нижний шире
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (w / 2 + bw / 2)
		block(cf * CF(x, 1.2, 0), V3(bw + 1.4, 2.4, bw + 1.2))
		local y = 2.4
		while y < h do
			local bh = r:NextNumber(2.4, 3.2)
			block(cf * CF(x + sx * r:NextNumber(-0.3, 0.3), y + bh / 2, 0), V3(bw + r:NextNumber(-0.2, 0.5), bh, bw))
			y = y + bh
		end
	end
	-- свод
	local R = w / 2 + bw / 2
	local n = 7
	for i = 0, n - 1 do
		local a0 = math.pi * (i + 0.5) / n
		local px, py = math.cos(a0) * R, h + math.sin(a0) * R
		block(cf * CF(px, py, 0) * ANG(0, 0, a0 - math.pi / 2), V3(math.pi * R / n + 0.6, bw, bw + 0.3))
	end
	return R
end

-- Портал: каменная арка и закрученная светящаяся «воронка» внутри
local function buildPortal(folder, pos, center, biome, target, label)
	local tb = BiomesData[target]
	local col = tb and tb.Theme.Accent or { 200, 200, 200 }
	local m = Instance.new("Model")
	m.Name = "Portal_" .. target
	m.Parent = folder
	local cf = faceCenter(pos, center)
	local W, H = 10, 9
	-- ступени-подиум
	solid(MK.Part(m, V3(20, 0.8, 9), cf * CF(0, 0.4, 0), { 120, 124, 140 }, { Material = "Cobblestone" }))
	solid(MK.Part(m, V3(17, 0.8, 7), cf * CF(0, 1.2, 0), { 140, 144, 160 }, { Material = "Slate" }))
	local stone = (target >= 4) and { 90, 84, 104 } or (target == 3 and { 150, 176, 210 } or { 112, 126, 158 })
	local R = stoneArch(m, cf * CF(0, 1.6, 0), W, H, stone, target * 13)
	-- воронка: слои овалов от тёмного края к светлому центру
	local mid = cf * CF(0, 1.6 + H * 0.55 + R * 0.25, 0)
	local ow, oh = W + 1.2, H + R * 0.95
	local disc = MK.Ellipsoid(m, V3(ow, oh, 0.5), mid, col, { Material = "Neon", Transparency = 0.15, Name = "PortalDisc" })
	disc.CanTouch = true
	disc.CastShadow = false
	MK.Ellipsoid(m, V3(ow * 0.72, oh * 0.74, 0.6), mid, MK.Shade(col, 0.35), { Material = "Neon", Transparency = 0.1 }).CastShadow = false
	MK.Ellipsoid(m, V3(ow * 0.4, oh * 0.42, 0.7), mid, MK.Shade(col, 0.7), { Material = "Neon", Transparency = 0.05 }).CastShadow = false
	-- вращающаяся спираль
	local swirl = Instance.new("Model")
	swirl.Name = "Swirl"
	swirl.Parent = m
	local hub0 = MK.Part(swirl, V3(0.2, 0.2, 0.2), mid * CF(0, 0, -0.45), col, { Transparency = 1 })
	for k = 0, 11 do
		local a0 = k * math.pi / 6
		local rr = 0.9 + k * 0.42
		local seg = MK.Part(swirl, V3(rr * 0.9, 0.35, 0.1), mid * CF(math.cos(a0) * rr * 0.55, math.sin(a0) * rr * 0.75, -0.45) * ANG(0, 0, a0 + math.pi / 2), MK.Shade(col, 0.85), { Material = "Neon", Transparency = 0.35 })
		seg.CastShadow = false
	end
	swirl.PrimaryPart = hub0
	swirl:SetAttribute("Base", mid * CF(0, 0, -0.45))
	swirl:SetAttribute("SpinSpeed", -1.6)
	CollectionService:AddTag(swirl, "Spin")
	CollectionService:AddTag(disc, "Pulse")
	MK.Light(disc, col, 26, 2)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(MK.Shade(col, 0.5))
	e.LightEmission = 1
	e.Rate = 10
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Front
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = disc
	-- название цели крупными буквами над аркой
	local text = string.gsub(label, "^← ", "")
	text = string.gsub(text, " →$", "")
	local arrow = string.find(label, "←", 1, true) and "← " or ""
	local arrowR = string.find(label, "→", 1, true) and " →" or ""
	MK.Text3D(m, arrow .. text .. arrowR, cf * CF(0, 1.6 + H + R + 3.6, 0), 3.4, col, MK.Shade(col, -0.5), { Outline = { 255, 255, 255 }, MaxDistance = 220 })
	local bb, lbl = MK.Billboard(disc, "", Color3.fromRGB(255, 220, 120), UDim2.fromOffset(300, 44), V3(0, -oh / 2 - 0.5, 0))
	bb.MaxDistance = 60
	lbl.Name = "LockLabel"
	m:SetAttribute("Target", target)
	return m, disc
end

---------------------------------------------------------------------------------------------
-- Декор по теме биома
---------------------------------------------------------------------------------------------
-- мягкие пятна другого оттенка на земле и пологие холмики — земля не выглядит «плоской заливкой»
local function groundPatches(deco, O, T)
	local light = MK.Shade(T.Ground, 0.08)
	local dark = MK.Shade(T.Ground, -0.06)
	local placed, tries = 0, 0
	while placed < 26 and tries < 300 do
		tries = tries + 1
		local x, z = rng:NextInteger(-104, 104), rng:NextInteger(-196, 108)
		if not (math.abs(x) < 94 and math.abs(z) < 94) then
			placed = placed + 1
			local d = rng:NextNumber() * 14 + 10
			local p = MK.Disc(deco, 0.16, d, O + V3(x, 0.02, z), (placed % 2 == 0) and light or dark)
			p.CastShadow = false
			p.Name = "Grass"
		end
	end
	-- пологие холмики у краёв базы
	for _, h in ipairs({ { -102, -186, 22, 4.5 }, { 102, -112, 18, 3.6 }, { -104, 40, 20, 4 }, { 104, 70, 24, 4.4 }, { -60, 106, 22, 3.8 }, { 40, 108, 18, 3.4 } }) do
		local mound = MK.Ellipsoid(deco, V3(h[3], h[4] * 2, h[3] * 0.8), CF(O + V3(h[1], -h[4] * 0.35, h[2])), MK.Shade(T.Ground, 0.04))
		mound.Name = "Hill"
		mound.CanCollide = false
	end
end

local function scatterDecor(b, folder, O, biome)
	local T = biome.Theme
	local deco = Instance.new("Folder")
	deco.Name = "Decor"
	deco.Parent = folder
	groundPatches(deco, O, T)
	-- точки вдоль краёв базы и колец (свободные от станций)
	local spots = {
		V3(-95, 0, -105), V3(-95, 0, -130), V3(-98, 0, -160), V3(-95, 0, -192), V3(-70, 0, -195),
		V3(104, 0, -205), V3(96, 0, -190), V3(98, 0, -100),
		V3(-100, 0, -10), V3(-100, 0, 30), V3(-100, 0, 75), V3(100, 0, -20), V3(100, 0, 30), V3(100, 0, 78),
		V3(-75, 0, 103), V3(-25, 0, 105), V3(25, 0, 103), V3(75, 0, 105), V3(103, 0, 103), V3(-103, 0, 103),
		V3(-100, 0, -50), V3(101, 0, -55), V3(-50, 0, 100), V3(50, 0, 102), V3(-86, 0, -196), V3(-60, 0, -212),
		V3(100, 0, -170), V3(-101, 0, -145), V3(-80, 0, 96), V3(80, 0, 95),
	}
	for i, s in ipairs(spots) do
		local p = O + s
		local r = rng:NextNumber()
		if b == 1 then
			if r < 0.55 then
				Decor.Tree(deco, p, T, (r < 0.25) and "pine" or "round", 0.9 + rng:NextNumber() * 0.4)
			elseif r < 0.8 then
				Decor.Rock(deco, p, T, 0.8 + rng:NextNumber() * 0.5)
			else
				Decor.Flowers(deco, p, { { 255, 120, 170 }, { 255, 255, 255 }, { 255, 200, 60 }, { 170, 120, 255 } })
			end
		elseif b == 2 then
			if r < 0.3 then
				Decor.Tree(deco, p, T, "round", 0.8)
			elseif r < 0.6 then
				Decor.Crystal(deco, p, T.Crystal, 1.1, i % 3 == 0)
			else
				Decor.Rock(deco, p, T, 1)
			end
		elseif b == 3 then
			if r < 0.5 then
				Decor.Tree(deco, p, T, "snowpine", 1)
			elseif r < 0.75 then
				Decor.Crystal(deco, p, T.Crystal, 1.2, i % 3 == 0)
			else
				Decor.Rock(deco, p, T, 1)
			end
		elseif b == 4 then
			if r < 0.35 then
				Decor.Tree(deco, p, T, "dead", 1)
			elseif r < 0.65 then
				Decor.Crystal(deco, p, { 255, 100, 40 }, 1, i % 3 == 0)
			else
				Decor.Rock(deco, p, T, 1.1)
			end
		else
			if r < 0.45 then
				Decor.Tree(deco, p, T, "crystal", 1)
			elseif r < 0.75 then
				Decor.Crystal(deco, p, T.Crystal, 1.2, i % 2 == 0)
			else
				Decor.Rock(deco, p, T, 1)
			end
		end
	end
	-- мелкий декор россыпью: трава, камешки, кусты, кристаллы (без коллизий, без теней)
	local avoid = {
		V3(0, 0, -100), V3(-38, 0, -108), V3(-62, 0, -142), V3(-62, 0, -174), V3(24, 0, -182), V3(50, 0, -182),
		V3(40, 0, -108), V3(-24, 0, -184), V3(84, 0, -126), V3(84, 0, -160), V3(0, 0, -140),
		V3(-40, 0, -100), V3(-18, 0, -198), V3(0, 0, -198), V3(18, 0, -198), V3(58, 0, -190),
	}
	local placed = 0
	local tries = 0
	while placed < 34 and tries < 600 do
		tries = tries + 1
		local p = V3(rng:NextInteger(-106, 106), 0, rng:NextInteger(-196, 108))
		local inShaft = math.abs(p.X) < 92 and math.abs(p.Z) < 92
		local ok = not inShaft
		for _, a in ipairs(avoid) do
			if ok and (V3(p.X, 0, p.Z) - a).Magnitude < 15 then
				ok = false
			end
		end
		if ok then
			placed = placed + 1
			local wp = O + p
			local r = rng:NextNumber()
			local function small(part)
				part.CastShadow = false
				return part
			end
			if r < 0.12 then
				-- редкий пучок травы / снега / пепла
				local col = (b == 3) and { 236, 246, 255 } or MK.Shade(T.Ground, -0.15)
				for k = 0, 2 do
					small(MK.Wedge(deco, V3(0.3, 1.2 + rng:NextNumber() * 0.8, 0.5), CF(wp + V3(k * 0.35 - 0.35, 0.6, rng:NextNumber() * 0.4)) * ANG(0, rad(rng:NextInteger(0, 360)), 0), col))
				end
			elseif r < 0.65 then
				small(MK.Part(deco, V3(1.2, 0.7, 1.0) * (0.6 + rng:NextNumber()), CF(wp + V3(0, 0.25, 0)) * ANG(rad(rng:NextInteger(-20, 20)), rad(rng:NextInteger(0, 90)), 0), T.Rock))
			elseif r < 0.85 then
				if b <= 2 then
					small(MK.Ellipsoid(deco, V3(3, 2, 3) * (0.7 + rng:NextNumber() * 0.5), CF(wp + V3(0, 0.6, 0)), (rng:NextNumber() < 0.5) and T.Leaves or T.Leaves2))
				elseif b == 3 then
					small(MK.Ellipsoid(deco, V3(4, 1.6, 3.4), CF(wp + V3(0, 0.3, 0)), { 244, 250, 255 }))
				else
					small(MK.Part(deco, V3(0.6, 1.6, 0.6), CF(wp + V3(0, 0.6, 0)) * ANG(rad(15), rad(45), 0), T.Crystal, { Material = "Neon" }))
				end
			else
				if b == 1 then
					Decor.Flowers(deco, wp, { { 255, 120, 170 }, { 255, 255, 255 }, { 255, 200, 60 }, { 170, 120, 255 } })
				else
					small(MK.Part(deco, V3(0.5, 1.2, 0.5), CF(wp + V3(0, 0.5, 0)) * ANG(rad(-10), rad(45), rad(10)), T.Crystal, { Material = "Glass", Transparency = 0.1 }))
				end
			end
		end
	end

	-- фонари вдоль дорожки
	for _, s in ipairs({ V3(-14, 0, -112), V3(14, 0, -112), V3(-24, 0, -160), V3(24, 0, -160), V3(-55, 0, -110), V3(62, 0, -140) }) do
		Decor.Lamp(deco, O + s, T, 8)
	end
	-- ящики и вагонетка у шахты
	Decor.Crate(deco, O + V3(-20, 0, -96), T, 1)
	Decor.Crate(deco, O + V3(-23, 0, -98), T, 0.7)
	Decor.Crate(deco, O + V3(66, 0, -98), T, 0.9)
	Decor.MineCart(deco, O + V3(-70, 0, -98), 90, T)
	-- забор по южному краю
	Decor.Fence(deco, O + V3(-108, 0, 110), O + V3(108, 0, 110), T)
	-- тематические акценты
	if b == 1 then
		Decor.Flowers(deco, O + V3(-30, 0, -125), { { 255, 120, 170 }, { 255, 255, 255 } })
		Decor.Flowers(deco, O + V3(30, 0, -135), { { 255, 200, 60 }, { 170, 120, 255 } })
	elseif b == 2 then
		Decor.Bones(deco, O + V3(-85, 0, -175), T, 1)
		Decor.Bones(deco, O + V3(0, 0, 100), T, 0.8)
	elseif b == 3 then
		Decor.Snowman(deco, O + V3(-30, 0, -122))
		Decor.Snowman(deco, O + V3(88, 0, -115))
	elseif b == 4 then
		Decor.LavaPool(deco, O + V3(-85, 0, -180), 1.2)
		Decor.LavaPool(deco, O + V3(88, 0, -186), 0.9)
		Decor.LavaPool(deco, O + V3(-100, 0, 55), 0.8)
	else
		for i = 1, 6 do
			Decor.FloatingShard(deco, O + V3(rng:NextInteger(-100, 100), 22 + rng:NextInteger(0, 18), rng:NextInteger(-190, -100)), (i % 2 == 0) and T.Crystal or T.Trim, 1 + rng:NextNumber())
		end
	end
	-- парящие мини-острова на фоне
	for i = 1, 4 do
		local side = (i % 2 == 0) and 1 or -1
		local p = O + V3(side * rng:NextInteger(230, 290), rng:NextInteger(-10, 40), rng:NextInteger(-260, 120))
		local s = 0.6 + rng:NextNumber() * 0.8
		MK.Part(deco, V3(26, 4, 22) * s, CF(p), T.Ground)
		MK.Part(deco, V3(22, 10, 18) * s, CF(p + V3(0, -7 * s, 0)), T.Cliff)
		MK.Part(deco, V3(12, 10, 10) * s, CF(p + V3(0, -15 * s, 0)), T.CliffDark)
		if b <= 3 then
			Decor.Tree(deco, p + V3(0, 2 * s, 0), T, (b == 3) and "snowpine" or "round", s)
		else
			Decor.Crystal(deco, p + V3(0, 2 * s, 0), T.Crystal, s * 1.4, false)
		end
	end
end

---------------------------------------------------------------------------------------------
-- База
---------------------------------------------------------------------------------------------
local function buildHub(b, folder, O, biome, assets)
	local T = biome.Theme
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = folder
	local center = O + V3(0, 0, -145)
	local pts = { Hub = CF(O + V3(0, 3.5, -138)) * ANG(0, 0, 0) }

	-- центральная площадь и дорожки
	local plaza = MK.Disc(hub, 0.3, 30, O + V3(0, 0.12, -140), T.Path, { Material = "Cobblestone" })
	plaza.CastShadow = false
	plaza.Name = "Path"
	local plaza2 = MK.Disc(hub, 0.32, 22, O + V3(0, 0.14, -140), MK.Shade(T.Path, -0.08), { Material = "Marble" })
	plaza2.CastShadow = false
	plaza2.Name = "Path"
	MK.Disc(hub, 0.36, 6, O + V3(0, 0.18, -140), T.Accent, { Material = "Neon" })
	for _, seg in ipairs({ { V3(0, 0.1, -125), V3(0, 0.1, -92) }, { V3(-14, 0.1, -140), V3(-52, 0.1, -140) }, { V3(14, 0.1, -140), V3(66, 0.1, -140) }, { V3(0, 0.1, -155), V3(0, 0.1, -190) } }) do
		local a, bb = O + seg[1], O + seg[2]
		local p = MK.Part(hub, V3(7, 0.24, (bb - a).Magnitude), CFrame.lookAt((a + bb) / 2, bb), T.Path, { Material = "Cobblestone" })
		p.CastShadow = false
		p.Name = "Path"
	end

	-- NPC Drill-Bot 3000
	local npc = NPCBuilder.DrillBot()
	npc.Parent = hub
	local npcPos = O + V3(-16, 0, -104)
	npc:PivotTo(CFrame.lookAt(npcPos + V3(0, 3, 0), V3(npcPos.X, 3, center.Z)) * ANG(0, 0, 0))
	for _, p in ipairs(npc:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	solid(npc:FindFirstChild("Body"))
	CollectionService:AddTag(npc, "DrillBot")
	local npcBB = MK.Billboard(npc.PrimaryPart, "Drill-Bot 3000", Color3.fromRGB(255, 220, 90), UDim2.fromOffset(260, 46), V3(0, 6.5, 0))
	npcBB.Name = "NameTag"
	prompt(npc:FindFirstChild("Body"), "Поговорить", "Drill-Bot 3000", "NPC")
	pts.NPC = npcPos

	-- продажа
	local _, sellPad, sellPos = buildSell(hub, O + V3(-40, 0, -106), center, biome)
	pts.SellPad = sellPad
	pts.Sell = sellPos

	-- магазины
	local starterDrill
	for _, d in ipairs(DrillsData.List) do
		if d.Biome == b then
			starterDrill = d
		end
	end
	local starterPack
	for _, p in ipairs(BackpacksData.List) do
		if p.Biome == b then
			starterPack = p
		end
	end
	local _, dzone, dpos = buildShop(hub, O + V3(-62, 0, -138), center, biome, "БУРЫ", "Drill", { 220, 76, 66 }, assets.Drills:FindFirstChild(starterDrill.Id))
	local _, pzone, ppos = buildShop(hub, O + V3(-62, 0, -176), center, biome, "РЮКЗАКИ", "Backpack", { 66, 140, 230 }, assets.Backpacks:FindFirstChild(starterPack.Id))
	pts.Shop = dpos
	pts.PackShop = ppos
	pts.ShopZones = { Drill = dzone, Backpack = pzone }

	-- яйца
	pts.Eggs = {}
	local eggSpots = { V3(34, 0, -184), V3(58, 0, -191), V3(82, 0, -184) }
	-- 4-е яйцо (Сказочное) стоит отдельно на лужайке рядом с Хроно-Древом, на своём пьедестале
	local SPECIAL_SPOT = V3(-14, 0, -186)
	local wide = false
	-- площадка питомцев: мощёный полукруг и большие объёмные буквы
	local paveCol = MK.Shade(T.Path, -0.05)
	-- сцена с яйцами: три пологие ступени (по 0.8 студа), яйца стоят наверху
	local STAGE = 2.4
	for i = 0, 2 do
		local st = MK.Part(hub, V3((wide and 86 or 70) - i * 4, 0.8, 36 - i * 4), CF(O + V3(58, 0.4 + i * 0.8, -188)), (i % 2 == 0) and MK.Shade(paveCol, -0.12) or MK.Shade(paveCol, -0.04), { Material = "Cobblestone" })
		st.CanCollide = true
		st.Name = i == 2 and "PetPlaza" or "PetStage"
	end
	for _, sx in ipairs({ -1, 1 }) do
		local post = O + V3(58 + sx * (wide and 38 or 30), STAGE, -200)
		solid(MK.Part(hub, V3(2, 16, 2), CF(post + V3(0, 8, 0)), { 120, 84, 60 }, { Material = "Wood" }))
	end
	MK.Text3D(hub, "ПИТОМЦЫ", CFrame.lookAt(O + V3(58, 19, -202), O + V3(58, 19, -120)), 8, { 214, 120, 255 }, { 120, 50, 170 }, { Outline = { 255, 255, 255 }, Gradient = { { 240, 170, 255 }, { 180, 90, 255 } } })
	for _, egg in ipairs(EggsData.List) do
		if egg.Biome == b then
			local spot = eggSpots[egg.Slot] and (O + eggSpots[egg.Slot] + V3(0, STAGE, 0)) or (O + SPECIAL_SPOT)
			local _, p = buildEggStand(hub, spot, center, biome, egg)
			pts.Eggs[egg.Id] = p
		end
	end

	-- инкубатор и древо
	buildIncubator(hub, O + V3(40, 0, -108), center, biome)
	pts.Incubator = O + V3(40, 0, -108)
	buildTree(hub, O + V3(-42, 0, -198), center, biome)
	pts.Tree = O + V3(-42, 0, -198)

	-- порталы
	pts.Portals = {}
	if b > 1 then
		local _, disc = buildPortal(hub, O + V3(84, 0, -126), center, biome, b - 1, "← " .. BiomesData[b - 1].Short)
		pts.Portals[b - 1] = disc
	end
	if b < #BiomesData then
		local _, disc = buildPortal(hub, O + V3(84, 0, -160), center, biome, b + 1, BiomesData[b + 1].Short .. " →")
		pts.Portals[b + 1] = disc
	end

	-- ворота над входом в шахту: каменная арка с объёмным названием яруса
	local gate = Instance.new("Model")
	gate.Name = "BiomeGate"
	gate.Parent = hub
	local gcf = CFrame.lookAt(O + V3(0, 0, -91), O + V3(0, 0, -140))
	local stoneCol = MK.Shade(T.Rock or { 140, 140, 150 }, 0.05)
	local R = stoneArch(gate, gcf, 18, 7, stoneCol, b * 31)
	MK.Text3D(gate, biome.Short, gcf * CF(0, 7 + R + 4.4, 0), 6, T.UI, MK.Shade(T.UI, -0.5), { Outline = { 255, 255, 255 }, MaxDistance = 320 })
	local plate = MK.Part(gate, V3(11, 1.8, 0.4), gcf * CF(0, 7 + R - 0.4, -2.1), { 40, 34, 50 })
	MK.Sign(plate, Enum.NormalId.Front, Util.Commas(biome.MinDepth) .. " – " .. Util.Commas(biome.MaxDepth) .. " м", Color3.fromRGB(255, 230, 140))
	for _, sx in ipairs({ -1, 1 }) do
		local lamp = MK.Ellipsoid(gate, V3(1.6, 1.6, 1.6), gcf * CF(sx * (9 + 1.8), 7 + 1.2, -2.4), T.Accent, { Material = "Neon" })
		MK.Light(lamp, T.Accent, 14, 1.2)
	end

	return pts
end

---------------------------------------------------------------------------------------------
-- Освещение
---------------------------------------------------------------------------------------------
function WorldBuilder.SetupLighting()
	-- чистая яркая картинка: без размытия глубины резкости и густой дымки
	-- насыщенная «мягкая» картинка как в Pet Simulator: светлые тени, мягкие края
	-- современный свет: Future (мягкие реалистичные тени, свет фонарей и неона на поверхностях),
	-- воздушная перспектива (дальние горы тают в дымке), мягкое свечение
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(116, 110, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(176, 172, 196)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.22
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 35
	Lighting.ExposureCompensation = 0.15
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	local function ensure(class, name)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(class)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end
	local atm = ensure("Atmosphere", "Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(199, 226, 255)
	atm.Decay = Color3.fromRGB(140, 170, 210)
	atm.Glare = 0.3
	atm.Haze = 1.1
	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.6
	local cc = ensure("ColorCorrectionEffect", "Grade")
	cc.Saturation = 0.32
	cc.Contrast = 0.08
	cc.Brightness = 0.03
	local rays = ensure("SunRaysEffect", "SunRays")
	rays.Intensity = 0.07
	rays.Spread = 0.5
	local dof = Lighting:FindFirstChild("DOF")
	if dof then
		dof:Destroy()
	end
	local sky = ensure("Sky", "Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	-- настоящие объёмные облака Roblox в небе
	pcall(function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain and not terrain:FindFirstChildOfClass("Clouds") then
			local clouds = Instance.new("Clouds")
			clouds.Cover = 0.55
			clouds.Density = 0.6
			clouds.Color = Color3.fromRGB(255, 255, 255)
			clouds.Parent = terrain
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Точка входа
---------------------------------------------------------------------------------------------
function WorldBuilder.Build(assets)
	worldFolder = workspace:FindFirstChild("World") or Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = workspace
	minesFolder = workspace:FindFirstChild("Mines") or Instance.new("Folder")
	minesFolder.Name = "Mines"
	minesFolder.Parent = workspace

	WorldBuilder.SetupLighting()

	for b, biome in ipairs(BiomesData) do
		local O = WorldBuilder.Origin(b)
		local folder = Instance.new("Folder")
		folder.Name = "Biome" .. b
		folder.Parent = worldFolder
		folder:SetAttribute("Biome", b)
		buildIsland(b, folder, O, biome)
		local pods = buildPods(b, folder, O, biome)
		local pts = buildHub(b, folder, O, biome, assets)
		scatterDecor(b, folder, O, biome)
		require(script.Parent.WorldScenery).Build(b, folder, O, biome, Decor)
		pts.Pods = pods
		pts.Origin = O
		WorldBuilder.Points[b] = pts
		local mf = Instance.new("Folder")
		mf.Name = "Biome" .. b
		mf.Parent = minesFolder
		task.wait()
	end

	-- точки для обучения новичков (клиент рисует к ним стрелки)
	local p1 = WorldBuilder.Points[1]
	local function pos(v)
		if typeof(v) == "Instance" then
			return v.Position
		elseif typeof(v) == "CFrame" then
			return v.Position
		end
		return v
	end
	worldFolder:SetAttribute("TutShaft", WorldBuilder.Origin(1) + V3(0, 1, 0))
	worldFolder:SetAttribute("TutHub", pos(p1.Hub))
	worldFolder:SetAttribute("TutSell", pos(p1.SellPad) or p1.Sell)
	worldFolder:SetAttribute("TutDrillShop", p1.Shop)
	local egg = p1.Eggs and p1.Eggs.Dirt
	if egg then
		worldFolder:SetAttribute("TutEgg", pos(egg))
	end

	-- точка спавна (персонажа всё равно переносит PlayerInit)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = V3(8, 1, 8)
	spawn.CFrame = CF(WorldBuilder.Origin(1) + V3(0, -0.4, -140))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = worldFolder

	return WorldBuilder.Points
end

function WorldBuilder.MinesFolder(b)
	return minesFolder:FindFirstChild("Biome" .. b)
end

return WorldBuilder
