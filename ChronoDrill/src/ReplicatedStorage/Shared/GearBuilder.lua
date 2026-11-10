-- GearBuilder: процедурные модели буров, рюкзаков и яиц.
-- Бур: рукоять в начале координат (ось Y), сверло смотрит в -Z.
-- Сверло собрано отдельно (BitRoot + Weld "BitWeld"), клиент вращает его во время бурения.
local MK = require(script.Parent.ModelKit)

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local GearBuilder = {}

local function weldTo(part0, part1, name)
	local w = Instance.new("Weld")
	w.Name = name or "Weld"
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = part0.CFrame:Inverse() * part1.CFrame
	w.Parent = part1
	return w
end

---------------------------------------------------------------------------------------------
-- Бур
---------------------------------------------------------------------------------------------
function GearBuilder.Drill(def)
	local look = def.Look
	local tier = look.Tier or 1
	local body = MK.C(look.Body)
	local accent = MK.C(look.Accent)
	local bitC = MK.C(look.Bit)
	local model = Instance.new("Model")
	model.Name = def.Id

	local grip = MK.Cylinder(model, 1.15, 0.5, CF(0, 0, 0) * ANG(0, 0, rad(90)), accent, { Name = "Grip" })
	model.PrimaryPart = grip
	for i = -1, 1 do
		MK.Cylinder(model, 0.08, 0.56, CF(0, i * 0.3, 0) * ANG(0, 0, rad(90)), MK.Shade(accent, -0.3))
	end
	MK.Part(model, V3(0.35, 0.45, 0.3), CF(0, 0.45, -0.38), MK.Shade(accent, -0.25))

	local bodyLen = 1.6 + tier * 0.03
	local bodyCf = CF(0, 0.85, -0.55)
	MK.Part(model, V3(1.0, 0.95, bodyLen), bodyCf, body)
	MK.Part(model, V3(1.06, 0.22, bodyLen * 0.9), bodyCf * CF(0, 0.12, 0), accent)
	MK.Cylinder(model, 0.55, 1.15, bodyCf * CF(0, 0, bodyLen / 2 + 0.15) * ANG(0, rad(90), 0), MK.Shade(body, -0.2))
	MK.Cylinder(model, 0.12, 0.6, bodyCf * CF(0, 0, bodyLen / 2 + 0.45) * ANG(0, rad(90), 0), accent)
	for k = -1, 1 do
		MK.Part(model, V3(1.04, 0.06, 0.08), bodyCf * CF(0, -0.25, bodyLen / 2 - 0.2 - k * 0.15 - 0.15), MK.Shade(body, -0.35))
	end
	if tier >= 5 then
		for _, s in ipairs({ -1, 1 }) do
			MK.Part(model, V3(0.2, 0.55, bodyLen * 0.6), bodyCf * CF(s * 0.58, 0.05, 0.1), accent)
		end
	end
	if tier >= 9 then
		MK.Part(model, V3(0.5, 0.35, 0.8), bodyCf * CF(0, 0.6, 0.2), MK.Shade(body, 0.15))
		MK.Wedge(model, V3(0.5, 0.35, 0.4), bodyCf * CF(0, 0.6, -0.4) * ANG(0, rad(180), 0), MK.Shade(body, 0.15))
	end
	if look.Glow then
		local g = MK.C(look.Glow)
		MK.Part(model, V3(1.08, 0.1, 0.1), bodyCf * CF(0, -0.05, -bodyLen / 2 + 0.25), g, { Material = "Neon" })
		MK.Part(model, V3(0.1, 0.1, bodyLen * 0.7), bodyCf * CF(0, 0.49, 0), g, { Material = "Neon" })
		if tier >= 13 then
			MK.Light(model.PrimaryPart, g, 6, 0.8)
		end
	end

	-- Сверло
	local bitZ = -0.55 - bodyLen / 2
	local bitRoot = MK.Part(model, V3(0.2, 0.2, 0.2), CF(0, 0.85, bitZ), bitC, { Name = "BitRoot", Transparency = 1 })
	MK.Cylinder(model, 0.3, 0.95, CF(0, 0.85, bitZ - 0.05) * ANG(0, rad(90), 0), MK.Shade(body, -0.3))
	local bitLen = 1.7 + math.min(tier, 20) * 0.04
	local steps = { { 0.82, 0.32 }, { 0.64, 0.28 }, { 0.48, 0.24 }, { 0.32, 0.16 } }
	local z = bitZ - 0.2
	local bitParts = {}
	for i, s in ipairs(steps) do
		local len = bitLen * s[2]
		local p = MK.Cylinder(model, len, s[1], CF(0, 0.85, z - len / 2) * ANG(0, rad(90), 0), (i % 2 == 0) and MK.Shade(bitC, -0.18) or bitC, { Material = "Metal" })
		table.insert(bitParts, p)
		z = z - len
	end
	local tip = MK.Ellipsoid(model, V3(0.18, 0.18, 0.3), CF(0, 0.85, z), bitC, { Material = "Metal" })
	table.insert(bitParts, tip)
	-- спиральные канавки
	for k = 0, 2 do
		local ang = k * math.pi * 2 / 3
		local fl = MK.Part(model, V3(0.12, 0.06, bitLen * 0.8), CF(0, 0.85, bitZ - 0.2 - bitLen * 0.4) * ANG(0, 0, ang) * CF(0, 0.32, 0) * ANG(rad(-12), 0, 0), MK.Shade(bitC, -0.45), { Material = "Metal" })
		table.insert(bitParts, fl)
	end
	for _, p in ipairs(bitParts) do
		p.Name = "Bit"
		local w = Instance.new("WeldConstraint")
		w.Part0 = bitRoot
		w.Part1 = p
		w.Parent = p
		p.Anchored = false
		p.Massless = true
	end

	-- всё, кроме сверла, приварено к рукояти
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and d ~= grip and d.Name ~= "Bit" and d ~= bitRoot then
			local w = Instance.new("WeldConstraint")
			w.Part0 = grip
			w.Part1 = d
			w.Parent = d
			d.Anchored = false
			d.Massless = true
		end
	end
	local bitWeld = weldTo(grip, bitRoot, "BitWeld")
	bitRoot.Anchored = false
	bitRoot.Massless = true
	grip.Anchored = false
	grip.Massless = true
	model:SetAttribute("Tier", tier)
	return model
end

---------------------------------------------------------------------------------------------
-- Рюкзак (крепится к спине; центр модели = точка крепления)
---------------------------------------------------------------------------------------------
function GearBuilder.Backpack(def)
	local look = def.Look
	local tier = look.Tier or 1
	local body = MK.C(look.Body)
	local accent = MK.C(look.Accent)
	local model = Instance.new("Model")
	model.Name = def.Id
	local s = 1 + math.min(tier, 20) * 0.025
	local root = MK.Part(model, V3(0.4, 0.4, 0.4), CF(0, 0, 0), body, { Name = "Root", Transparency = 1 })
	model.PrimaryPart = root
	MK.Part(model, V3(1.6 * s, 1.75 * s, 0.85 * s), CF(0, 0, 0.45 * s), body)
	MK.Part(model, V3(1.66 * s, 0.7 * s, 0.92 * s), CF(0, 0.6 * s, 0.45 * s), MK.Shade(body, -0.15))
	MK.Part(model, V3(1.1 * s, 0.6 * s, 0.25 * s), CF(0, -0.35 * s, 0.95 * s), accent)
	MK.Part(model, V3(0.3 * s, 0.22 * s, 0.1), CF(0, 0.35 * s, 0.92 * s), MK.Shade(accent, 0.3), { Material = "Metal" })
	for _, x in ipairs({ -0.5, 0.5 }) do
		MK.Part(model, V3(0.22 * s, 1.85 * s, 0.12), CF(x * s, 0, 0.0), MK.Shade(accent, -0.2))
	end
	if tier >= 4 then
		for _, x in ipairs({ -0.86, 0.86 }) do
			MK.Cylinder(model, 0.9 * s, 0.5 * s, CF(x * s, -0.2 * s, 0.45 * s) * ANG(0, 0, rad(90)), accent)
		end
	end
	if look.Glow then
		local core = MK.Part(model, V3(0.9 * s, 0.9 * s, 0.1), CF(0, -0.05 * s, 0.9 * s), accent, { Material = "Neon", Transparency = 0.1 })
		core.Name = "Core"
	end
	MK.WeldAll(model, root)
	return model
end

---------------------------------------------------------------------------------------------
-- Яйцо: две половинки (Top/Bottom) + узоры. Pivot в центре яйца.
---------------------------------------------------------------------------------------------
function GearBuilder.Egg(def, scale)
	scale = scale or 1
	local look = def.Look
	local base = MK.C(look.Base)
	local accent = MK.C(look.Accent)
	local band = MK.C(look.Band)
	local glass = look.Pattern == "glass"
	local mat = glass and "Glass" or "SmoothPlastic"
	local trans = glass and 0.15 or 0

	local model = Instance.new("Model")
	model.Name = def.Id
	local root = MK.Part(model, V3(0.5, 0.5, 0.5), CF(0, 0, 0), base, { Name = "Root", Transparency = 1 })
	model.PrimaryPart = root

	local top = Instance.new("Model")
	top.Name = "Top"
	top.Parent = model
	local bottom = Instance.new("Model")
	bottom.Name = "Bottom"
	bottom.Parent = model

	local tPart = MK.Ellipsoid(top, V3(3.6, 3.4, 3.6), CF(0, 0.75, 0), base, { Material = mat, Transparency = trans })
	local bPart = MK.Ellipsoid(bottom, V3(4.0, 3.6, 4.0), CF(0, -0.35, 0), base, { Material = mat, Transparency = trans })
	top.PrimaryPart = tPart
	bottom.PrimaryPart = bPart
	-- зубчатый шов
	for i = 0, 11 do
		local ang = i * math.pi * 2 / 12
		local p = V3(math.cos(ang) * 1.86, 0.28, math.sin(ang) * 1.86)
		local cf = CF(p, V3(0, 0.28, 0)) * ANG(0, rad(180), 0)
		local w = MK.Wedge(bottom, V3(0.12, 0.42, 0.9), cf * ANG(0, rad(90), 0), band)
		w.Name = "Zig"
	end
	MK.Cylinder(bottom, 0.32, 4.02, CF(0, 0.05, 0) * ANG(0, 0, rad(90)), band, look.Neon and { Material = "Neon" } or nil)

	-- точки на поверхности скорлупы (две половинки — два эллипсоида)
	local TOP_C, TOP_R = V3(0, 0.75, 0), V3(1.8, 1.7, 1.8)
	local BOT_C, BOT_R = V3(0, -0.35, 0), V3(2.0, 1.8, 2.0)
	local function surf(dir)
		dir = dir.Unit
		local function onE(c, r)
			local t = 1 / math.sqrt((dir.X / r.X) ^ 2 + (dir.Y / r.Y) ^ 2 + (dir.Z / r.Z) ^ 2)
			local p = c + dir * t
			local rel = p - c
			local n = V3(rel.X / (r.X * r.X), rel.Y / (r.Y * r.Y), rel.Z / (r.Z * r.Z)).Unit
			return p, n
		end
		local p, n = onE(TOP_C, TOP_R)
		if p.Y > 0.35 then
			return p, n, top
		end
		p, n = onE(BOT_C, BOT_R)
		return p, n, bottom
	end
	-- равномерно распределённые направления (спираль Фибоначчи), больше спереди (-Z)
	local dirs = {}
	local count = 20
	for i = 0, count - 1 do
		local y = 1 - (i + 0.5) / count * 1.9
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * 2.39996
		table.insert(dirs, V3(math.cos(a) * r, y, math.sin(a) * r - 0.25))
	end
	local accentOpts = { Material = look.Neon and "Neon" or "SmoothPlastic" }
	local pat = look.Pattern
	if pat == "spots" or pat == "glass" then
		for i, d in ipairs(dirs) do
			if math.abs(d.Y) < 0.88 and i % 2 == 1 or i % 5 == 0 then
				local p, n, half = surf(d)
				local s = 0.75 + (i % 3) * 0.22
				MK.Ellipsoid(half, V3(s, s * 0.8, 0.22), CF(p, p + n), accent, accentOpts)
			end
		end
		if glass then
			local core = MK.Ellipsoid(bottom, V3(2.2, 2.2, 2.2), CF(0, 0.1, 0), accent, { Material = "Neon", Transparency = 0.35 })
			core.CastShadow = false
		end
	elseif pat == "cracks" then
		for i, d in ipairs(dirs) do
			if i % 2 == 0 then
				local p, n, half = surf(d)
				local cf = CF(p, p + n)
				for k = -1, 1 do
					local seg = cf * CF(k * 0.22, k * 0.28, 0) * ANG(0, 0, rad(35 * ((k % 2 == 0) and 1 or -1)))
					MK.Part(half, V3(0.13, 0.5, 0.14), seg, accent, accentOpts)
				end
			end
		end
	elseif pat == "flames" then
		for i = 0, 9 do
			local a = i * math.pi * 2 / 10
			local d = V3(math.cos(a), -0.05 + (i % 2) * 0.18, math.sin(a))
			local p, n, half = surf(d)
			local h = (i % 2 == 0) and 1.3 or 0.9
			local cf = CF(p, p + n) * CF(0, h * 0.3, 0)
			local w1 = MK.Wedge(bottom, V3(0.12, h, 0.35), cf * CF(-0.17, 0, 0) * ANG(0, rad(90), 0), accent, accentOpts)
			local w2 = MK.Wedge(bottom, V3(0.12, h, 0.35), cf * CF(0.17, 0, 0) * ANG(0, rad(-90), 0), accent, accentOpts)
		end
		for i, d in ipairs(dirs) do
			if d.Y > 0.3 and i % 3 == 0 then
				local p, n, half = surf(d)
				MK.Ellipsoid(half, V3(0.5, 0.5, 0.18), CF(p, p + n), MK.Shade(accent, 0.3), accentOpts)
			end
		end
	elseif pat == "bones" then
		for i, d in ipairs(dirs) do
			if i % 3 == 1 then
				local p, n, half = surf(d)
				local cf = CF(p, p + n) * ANG(0, 0, rad(i * 40))
				MK.Part(half, V3(0.22, 0.95, 0.18), cf, accent)
				MK.Ellipsoid(half, V3(0.4, 0.3, 0.26), cf * CF(0, 0.5, 0), accent)
				MK.Ellipsoid(half, V3(0.4, 0.3, 0.26), cf * CF(0, -0.5, 0), accent)
			end
		end
	elseif pat == "stars" then
		for i, d in ipairs(dirs) do
			local p, n, half = surf(d)
			local s = (i % 3 == 0) and 0.42 or 0.24
			MK.Ellipsoid(half, V3(s, s, s), CF(p), accent, { Material = "Neon" })
		end
		local p, n, half = surf(V3(0.2, 0.55, -1))
		local cf = CF(p, p + n)
		MK.Part(half, V3(0.7, 0.18, 0.12), cf, accent, { Material = "Neon" })
		MK.Part(half, V3(0.18, 0.7, 0.12), cf, accent, { Material = "Neon" })
	end
	if look.Neon then
		MK.Light(root, accent, 10, 1.2)
	end
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

return GearBuilder
