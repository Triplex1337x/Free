-- ModelKit: строительные блоки для процедурных low-poly моделей.
-- Всё собирается из примитивов Roblox (Part, WedgePart, CornerWedgePart, SpecialMesh Sphere),
-- поэтому игре не нужны загруженные меши и текстуры.
local ModelKit = {}

local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.Glass,
	Neon = Enum.Material.Neon,
	Metal = Enum.Material.Metal,
	Ice = Enum.Material.Ice,
	Wood = Enum.Material.Wood,
	Slate = Enum.Material.Slate,
	Plastic = Enum.Material.Plastic,
	Rock = Enum.Material.Rock,
	Sand = Enum.Material.Sand,
	Grass = Enum.Material.Grass,
	Fabric = Enum.Material.Fabric,
	ForceField = Enum.Material.ForceField,
	Basalt = Enum.Material.Basalt,
	Snow = Enum.Material.Snow,
	Cobblestone = Enum.Material.Cobblestone,
	WoodPlanks = Enum.Material.WoodPlanks,
	Ground = Enum.Material.Ground,
	Mud = Enum.Material.Mud,
	Pebble = Enum.Material.Pebble,
	Sandstone = Enum.Material.Sandstone,
	Limestone = Enum.Material.Limestone,
	Glacier = Enum.Material.Glacier,
	Asphalt = Enum.Material.Asphalt,
	CrackedLava = Enum.Material.CrackedLava,
	Granite = Enum.Material.Granite,
	LeafyGrass = Enum.Material.LeafyGrass,
	Salt = Enum.Material.Salt,
	Marble = Enum.Material.Marble,
	Plaster = Enum.Material.Plaster,
	Brick = Enum.Material.Brick,
	Concrete = Enum.Material.Concrete,
	DiamondPlate = Enum.Material.DiamondPlate,
	CorrodedMetal = Enum.Material.CorrodedMetal,
	Foil = Enum.Material.Foil,
}
ModelKit.Materials = MATERIALS

-- «Мягкий» стиль (как в Pet Simulator): земля, трава и листва — гладкие, без «шумных» текстур.
-- Красивые текстуры оставлены точечно: дерево, булыжник, кирпич, мрамор, сланец (скалы и камни),
-- ткань, металл. Выключить фильтр полностью — ModelKit.Soft = false.
ModelKit.Soft = true
local KEEP = {
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Brick] = true,
	[Enum.Material.Marble] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Granite] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.Plaster] = true,
	[Enum.Material.Ice] = true,
}

-- материал как есть, без мягкого фильтра (блоки шахты — с родными текстурами)
function ModelKit.MatRaw(name)
	if typeof(name) == "EnumItem" then
		return name
	end
	return MATERIALS[name or "SmoothPlastic"] or Enum.Material.SmoothPlastic
end
function ModelKit.Mat(name)
	local m
	if typeof(name) == "EnumItem" then
		m = name
	else
		m = MATERIALS[name or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	end
	if ModelKit.Soft and not KEEP[m] then
		return Enum.Material.SmoothPlastic
	end
	return m
end

function ModelKit.C(t)
	if typeof(t) == "Color3" then
		return t
	end
	return Color3.fromRGB(t[1], t[2], t[3])
end

function ModelKit.Shade(color, f)
	-- f > 0 светлее, f < 0 темнее
	color = ModelKit.C(color)
	if f >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), f)
	end
	return color:Lerp(Color3.new(0, 0, 0), -f)
end

local function base(p, parent, props)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
	if props then
		for k, v in pairs(props) do
			if k == "Color" then
				p.Color = ModelKit.C(v)
			elseif k == "Material" then
				p.Material = ModelKit.Mat(v)
			else
				p[k] = v
			end
		end
	end
	p.Parent = parent
	return p
end

function ModelKit.Part(parent, size, cf, color, props)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = ModelKit.C(color or { 200, 200, 200 })
	return base(p, parent, props)
end

function ModelKit.Wedge(parent, size, cf, color, props)
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cf
	p.Color = ModelKit.C(color or { 200, 200, 200 })
	return base(p, parent, props)
end

function ModelKit.Corner(parent, size, cf, color, props)
	local p = Instance.new("CornerWedgePart")
	p.Size = size
	p.CFrame = cf
	p.Color = ModelKit.C(color or { 200, 200, 200 })
	return base(p, parent, props)
end

-- Эллипсоид: Part + SpecialMesh Sphere растягивается под размер детали.
function ModelKit.Ellipsoid(parent, size, cf, color, props)
	local p = ModelKit.Part(parent, size, cf, color, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Цилиндр, ось вдоль X детали.
function ModelKit.Cylinder(parent, length, diameter, cf, color, props)
	local p = ModelKit.Part(parent, Vector3.new(length, diameter, diameter), cf, color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Цилиндр между двумя точками.
function ModelKit.CylinderBetween(parent, a, b, diameter, color, props)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	return ModelKit.Cylinder(parent, len, diameter, cf, color, props)
end

-- Вертикальный цилиндр (ось Y) с центром в pos.
function ModelKit.Disc(parent, height, diameter, pos, color, props)
	return ModelKit.Cylinder(parent, height, diameter, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, props)
end

-- Блок между двумя точками (балка).
function ModelKit.Beam(parent, a, b, thickness, color, props)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	return ModelKit.Part(parent, Vector3.new(thickness, thickness, len), CFrame.lookAt(mid, b), color, props)
end

-- Сваривает все BasePart модели с root и снимает якорь.
function ModelKit.WeldAll(model, root, keepAnchored)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
			d.Anchored = false
			d.Massless = true
		end
	end
	root.Anchored = keepAnchored and true or false
end

-- Текстовая табличка на грани детали.
function ModelKit.Sign(part, face, text, textColor, strokeColor, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, math.floor(400 * part.Size.Y / math.max(part.Size.X, 0.1)))
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.LightInfluence = 0.2
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor and ModelKit.C(textColor) or Color3.new(1, 1, 1)
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = strokeColor and ModelKit.C(strokeColor) or Color3.fromRGB(30, 24, 40)
	stroke.Parent = label
	return gui, label
end

-- Плавающая надпись над объектом.
function ModelKit.Billboard(adornee, text, color, size, offset)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.fromOffset(220, 60)
	bb.StudsOffset = offset or Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	bb.Adornee = adornee
	bb.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color and ModelKit.C(color) or Color3.new(1, 1, 1)
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(30, 24, 40)
	stroke.Parent = label
	return bb, label
end

function ModelKit.Light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = ModelKit.C(color)
	l.Range = range or 12
	l.Brightness = brightness or 1
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Стандартный эмиттер искр (встроенная текстура Roblox).
function ModelKit.Sparkles(parent, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(ModelKit.C(color))
	e.LightEmission = 0.8
	e.Rate = rate or 4
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	local s = size or 0.35
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, s), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1)
	e.Parent = parent
	return e
end

-- Объёмная надпись (как большие буквы над зонами в симуляторах): несколько слоёв SurfaceGui
-- со сдвигом назад — передний слой яркий с обводкой, задние темнее, получается «экструзия».
-- cf — центр надписи, лицом в -Z. height — высота букв в studs.
function ModelKit.Text3D(parent, text, cf, height, color, sideColor, opts)
	opts = opts or {}
	local n = utf8 and utf8.len(text) or #text
	local w = height * 0.68 * n + height * 0.4
	local layers = opts.Layers or 7
	local depth = opts.Depth or height * 0.32
	local model = Instance.new("Model")
	model.Name = "Text3D"
	model.Parent = parent
	local front = ModelKit.C(color)
	local side = sideColor and ModelKit.C(sideColor) or ModelKit.Shade(front, -0.45)
	for i = layers, 0, -1 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(w, height, 0.05)
		p.CFrame = cf * CFrame.new(0, 0, depth * i / layers)
		p.Parent = model
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = i == 0 and 0.15 or 0.6
		gui.AlwaysOnTop = false
		gui.MaxDistance = opts.MaxDistance or 400
		gui.Parent = p
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = (i == 0) and front or side:Lerp(Color3.new(0, 0, 0), i / layers * 0.35)
		l.Parent = gui
		local st = Instance.new("UIStroke")
		st.Thickness = (i == 0) and 6 or 5
		st.Color = (i == 0) and ModelKit.C(opts.Outline or { 255, 255, 255 }) or side:Lerp(Color3.new(0, 0, 0), 0.4)
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = l
		if i == 0 and opts.Gradient then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(ModelKit.C(opts.Gradient[1]), ModelKit.C(opts.Gradient[2]))
			g.Rotation = 90
			g.Parent = l
		end
		-- сзади тоже читается (зеркальная надпись не нужна — делаем вторую сторону)
		if i == layers and opts.TwoSided then
			local back = gui:Clone()
			back.Face = Enum.NormalId.Back
			back.Parent = p
		end
	end
	return model
end

-- Гранёная «low-poly» глыба: блок, повёрнутый под случайными углами (грани дают разную тень)
function ModelKit.Facet(parent, size, pos, color, rng, props)
	rng = rng or Random.new()
	local cf = CFrame.new(pos) * CFrame.Angles(math.rad(rng:NextNumber(-28, 28)), rng:NextNumber() * math.pi * 2, math.rad(rng:NextNumber(-28, 28)))
	return ModelKit.Part(parent, size, cf, color, props)
end

return ModelKit