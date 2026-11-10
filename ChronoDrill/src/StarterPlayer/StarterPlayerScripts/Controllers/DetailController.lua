-- DetailController: качество графики (Низкая / Средняя / Высокая) на клиенте.
--  • свет: тени, свечение, лучи солнца, облака, травинки Terrain;
--  • слой мелких деталей вокруг острова (только у себя на клиенте): трава, цветы, грибы,
--    камушки, кристаллы, кости, ледышки — по теме яруса;
--  • живая атмосфера: пыльца/снег/искры вокруг камеры, светлячки, бабочки, падающие листья.
-- Слой строится для текущего яруса и пересобирается при переходе на другой.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs:WaitForChild("Balance"))
local BiomesData = require(Configs:WaitForChild("BiomesData"))

local Settings = require(script.Parent.SettingsController)

local Detail = {}
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local quality = nil
local biome = 0
local layer = nil       -- Folder со статичными деталями
local critters = {}     -- бабочки / светлячки / листья
local ambient = nil     -- частицы вокруг камеры

-- Сколько деталей на остров
local COUNTS = { Low = 0, Medium = 55, High = 130 } -- немного деталей, без «ковра» из травы
local CRITTERS = { Low = 0, Medium = 4, High = 10 }

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(parent, size, cf, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function ball(parent, size, cf, color, props)
	local p = part(parent, size, cf, color, props)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

local function wedge(parent, size, cf, color, props)
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------------------------
-- Наборы деталей по ярусам
---------------------------------------------------------------------------------------------
local rng = Random.new()

local function grassTuft(f, pos, col, s)
	local base = col
	for k = 1, 3 do
		local a = rng:NextNumber() * math.pi * 2
		local h = (1.2 + rng:NextNumber() * 1.3) * s
		local shade = base:Lerp(Color3.new(1, 1, 0.7), rng:NextNumber() * 0.25)
		wedge(f, V3(0.18, h, 0.7 * s), CF(pos + V3(math.cos(a) * 0.25, h / 2, math.sin(a) * 0.25)) * ANG(0, a, rng:NextNumber() * 0.3), shade)
	end
end

local function flower(f, pos, petal, s)
	local h = (0.8 + rng:NextNumber() * 0.8) * s
	part(f, V3(0.12, h, 0.12), CF(pos + V3(0, h / 2, 0)), Color3.fromRGB(80, 160, 70))
	local top = pos + V3(0, h, 0)
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		ball(f, V3(0.42, 0.14, 0.42) * s, CF(top + V3(math.cos(a) * 0.22 * s, 0, math.sin(a) * 0.22 * s)), petal)
	end
	ball(f, V3(0.26, 0.2, 0.26) * s, CF(top + V3(0, 0.05, 0)), Color3.fromRGB(255, 220, 70), { Material = Enum.Material.Neon })
end

local function mushroom(f, pos, cap, s)
	local h = (0.6 + rng:NextNumber() * 0.5) * s
	part(f, V3(0.25, h, 0.25) * 1, CF(pos + V3(0, h / 2, 0)), Color3.fromRGB(245, 236, 220))
	ball(f, V3(0.9, 0.5, 0.9) * s, CF(pos + V3(0, h, 0)), cap)
	ball(f, V3(0.18, 0.1, 0.18) * s, CF(pos + V3(0.18 * s, h + 0.2 * s, 0.05)), Color3.new(1, 1, 1))
end

local function pebble(f, pos, col, s)
	ball(f, V3(0.7 + rng:NextNumber() * 0.6, 0.35 + rng:NextNumber() * 0.25, 0.6 + rng:NextNumber() * 0.5) * s, CF(pos + V3(0, 0.12 * s, 0)) * ANG(0, rng:NextNumber() * 3, 0), col, { Material = Enum.Material.Slate })
end

local function crystal(f, pos, col, s, neon)
	for k = 1, 3 do
		local h = (0.8 + rng:NextNumber() * 1.2) * s
		local a = rng:NextNumber() * math.pi * 2
		part(f, V3(0.3, h, 0.3) * 1, CF(pos + V3(math.cos(a) * 0.25, h / 2 - 0.1, math.sin(a) * 0.25)) * ANG(math.cos(a) * 0.35, a, math.sin(a) * 0.35) * ANG(0, math.rad(45), 0), col, { Material = neon and Enum.Material.Neon or Enum.Material.Glass, Transparency = neon and 0.1 or 0.25 })
	end
end

local function bone(f, pos, s)
	local cf = CF(pos + V3(0, 0.15, 0)) * ANG(0, rng:NextNumber() * 3, 0)
	part(f, V3(1.4, 0.22, 0.22) * s, cf, Color3.fromRGB(246, 238, 216))
	for _, x in ipairs({ -0.7, 0.7 }) do
		ball(f, V3(0.35, 0.35, 0.5) * s, cf * CF(x * s, 0, 0), Color3.fromRGB(246, 238, 216))
	end
end

local THEMES = {
	-- {функция, вес}
	[1] = function(f, pos, T)
		local r = rng:NextNumber()
		if r < 0.25 then
			grassTuft(f, pos, c3(T.Leaves2):Lerp(c3(T.Ground), 0.3), 1)
		elseif r < 0.85 then
			local petals = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 130, 255), Color3.fromRGB(255, 200, 70), Color3.fromRGB(110, 190, 255) }
			flower(f, pos, petals[rng:NextInteger(1, #petals)], 1.35)
		else
			pebble(f, pos, c3(T.Rock), 1)
		end
	end,
	[2] = function(f, pos, T)
		local r = rng:NextNumber()
		if r < 0.45 then
			grassTuft(f, pos, Color3.fromRGB(196, 176, 96), 0.9)
		elseif r < 0.65 then
			pebble(f, pos, c3(T.Rock), 1.1)
		elseif r < 0.8 then
			bone(f, pos, 1)
		elseif r < 0.92 then
			flower(f, pos, Color3.fromRGB(255, 150, 60), 0.8)
		else
			crystal(f, pos, Color3.fromRGB(255, 170, 40), 0.7, false)
		end
	end,
	[3] = function(f, pos, T)
		local r = rng:NextNumber()
		if r < 0.45 then
			crystal(f, pos, Color3.fromRGB(170, 225, 255), 0.8, false)
		elseif r < 0.75 then
			ball(f, V3(1.4, 0.5, 1.2), CF(pos + V3(0, 0.1, 0)), Color3.fromRGB(250, 252, 255), { Material = Enum.Material.Snow })
		elseif r < 0.9 then
			grassTuft(f, pos, Color3.fromRGB(150, 190, 170), 0.8)
		else
			pebble(f, pos, Color3.fromRGB(150, 170, 200), 1)
		end
	end,
	[4] = function(f, pos, T)
		local r = rng:NextNumber()
		if r < 0.45 then
			pebble(f, pos, Color3.fromRGB(60, 52, 60), 1.2)
		elseif r < 0.7 then
			crystal(f, pos, Color3.fromRGB(255, 110, 40), 0.7, true)
		else
			crystal(f, pos, Color3.fromRGB(40, 24, 60), 0.9, false)
		end
	end,
	[5] = function(f, pos, T)
		local r = rng:NextNumber()
		if r < 0.45 then
			crystal(f, pos, Color3.fromRGB(110, 240, 255), 0.8, true)
		elseif r < 0.7 then
			crystal(f, pos, Color3.fromRGB(200, 120, 255), 0.8, true)
		else
			pebble(f, pos, Color3.fromRGB(56, 40, 96), 1)
		end
	end,
}

-- что можно «засеять»: Terrain и детали-земля, но не дорожки, постройки и шахта
local GROUND_MATS = {
	[Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true, [Enum.Material.Sand] = true,
	[Enum.Material.Snow] = true, [Enum.Material.Glacier] = true, [Enum.Material.Basalt] = true, [Enum.Material.Mud] = true,
	[Enum.Material.Rock] = true, [Enum.Material.Slate] = true, [Enum.Material.Sandstone] = true, [Enum.Material.Asphalt] = true,
	[Enum.Material.CrackedLava] = true, [Enum.Material.Limestone] = true, [Enum.Material.Pebble] = true, [Enum.Material.Salt] = true,
}

local function buildLayer(b)
	if layer then
		layer:Destroy()
		layer = nil
	end
	local count = COUNTS[quality] or 0
	if count <= 0 then
		return
	end
	local bd = BiomesData[b]
	local T = bd.Theme
	local O = V3((b - 1) * Balance.BiomeSpacing, 0, 0)
	layer = Instance.new("Folder")
	layer.Name = "DetailLayer"
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excl = { layer }
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	if char then
		table.insert(excl, char)
	end
	local cp = workspace:FindFirstChild("ClientPets")
	if cp then
		table.insert(excl, cp)
	end
	params.FilterDescendantsInstances = excl
	local theme = THEMES[b] or THEMES[1]
	local placed, tries = 0, 0
	while placed < count and tries < count * 4 do
		tries = tries + 1
		-- остров: x ±165, z от -260 до 160; шахта ±90 пропускается. Половина деталей — вокруг базы.
		local x, z
		if rng:NextNumber() < 0.5 then
			local a, r = rng:NextNumber() * math.pi * 2, math.sqrt(rng:NextNumber()) * 105
			x, z = math.cos(a) * r, -150 + math.sin(a) * r * 0.8
		else
			x = rng:NextNumber(-165, 165)
			z = rng:NextNumber(-260, 160)
		end
		local onPath = (math.abs(x) < 6 and z > -196 and z < -86) or (math.abs(z + 140) < 6 and x > -58 and x < 72) or (x * x + (z + 140) ^ 2 < 34 * 34)
		if not (math.abs(x) < 92 and math.abs(z) < 92) and not onPath then
			local origin = O + V3(x, 120, z)
			local hit = workspace:Raycast(origin, V3(0, -220, 0), params)
			if hit and hit.Normal.Y > 0.75 then
				local inst = hit.Instance
				local ok = false
				if inst:IsA("Terrain") then
					ok = GROUND_MATS[hit.Material] == true
				elseif inst.Name == "Ground" or inst.Name == "Grass" or inst.Name == "Hill" then
					ok = true
				end
				if ok then
					theme(layer, hit.Position, T)
					placed = placed + 1
				end
			end
		end
	end
	layer.Parent = workspace
end

---------------------------------------------------------------------------------------------
-- Живая атмосфера
---------------------------------------------------------------------------------------------
local function clearCritters()
	for _, c in ipairs(critters) do
		if c.model then
			c.model:Destroy()
		end
	end
	critters = {}
end

local function butterfly(pos, col)
	local m = Instance.new("Model")
	m.Name = "Butterfly"
	local body = part(m, V3(0.12, 0.12, 0.5), CF(pos), Color3.fromRGB(40, 30, 40))
	local l = part(m, V3(0.6, 0.05, 0.5), CF(pos + V3(-0.32, 0, 0)), col, { Material = Enum.Material.Neon, Transparency = 0.1 })
	local r = part(m, V3(0.6, 0.05, 0.5), CF(pos + V3(0.32, 0, 0)), col, { Material = Enum.Material.Neon, Transparency = 0.1 })
	m.PrimaryPart = body
	m.Parent = workspace
	return { model = m, body = body, l = l, r = r, center = pos, phase = rng:NextNumber() * 10, radius = 4 + rng:NextNumber() * 8, kind = "fly" }
end

local function firefly(pos, col)
	local m = Instance.new("Model")
	m.Name = "Firefly"
	local p = ball(m, V3(0.35, 0.35, 0.35), CF(pos), col, { Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = col
	light.Range = 6
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = p
	m.PrimaryPart = p
	m.Parent = workspace
	return { model = m, body = p, center = pos, phase = rng:NextNumber() * 10, radius = 3 + rng:NextNumber() * 6, kind = "glow" }
end

local function spawnCritters(b)
	clearCritters()
	local n = CRITTERS[quality] or 0
	if n <= 0 then
		return
	end
	local O = V3((b - 1) * Balance.BiomeSpacing, 0, 0)
	local spots = {}
	for i = 1, n do
		local x = rng:NextNumber(-150, 150)
		local z = rng:NextNumber(-240, 140)
		if math.abs(x) < 95 and math.abs(z) < 95 then
			z = z < 0 and -120 - rng:NextNumber() * 80 or 110
		end
		table.insert(spots, O + V3(x, 4 + rng:NextNumber() * 4, z))
	end
	for i, pos in ipairs(spots) do
		if b == 1 or b == 2 then
			local cols = { Color3.fromRGB(255, 170, 60), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 240, 120) }
			table.insert(critters, butterfly(pos, cols[(i % #cols) + 1]))
		elseif b == 3 then
			table.insert(critters, firefly(pos, Color3.fromRGB(180, 230, 255)))
		elseif b == 4 then
			table.insert(critters, firefly(pos, Color3.fromRGB(255, 140, 50)))
		else
			table.insert(critters, firefly(pos, i % 2 == 0 and Color3.fromRGB(110, 240, 255) or Color3.fromRGB(200, 130, 255)))
		end
	end
end

-- частицы вокруг камеры: пыльца, песок, снег, пепел, звёздная пыль
local AMBIENT = {
	{ Color = Color3.fromRGB(255, 250, 200), Speed = 0.4, Rate = 14, Size = 0.18, Light = 0.6, Accel = V3(0.3, 0.05, 0) },
	{ Color = Color3.fromRGB(255, 220, 160), Speed = 1.5, Rate = 18, Size = 0.14, Light = 0.2, Accel = V3(2, 0, 0.5) },
	{ Color = Color3.fromRGB(255, 255, 255), Speed = 1, Rate = 40, Size = 0.25, Light = 0.3, Accel = V3(0.4, -2.5, 0.2) },
	{ Color = Color3.fromRGB(255, 130, 50), Speed = 1.5, Rate = 22, Size = 0.16, Light = 1, Accel = V3(0, 2, 0) },
	{ Color = Color3.fromRGB(150, 220, 255), Speed = 0.5, Rate = 20, Size = 0.2, Light = 1, Accel = V3(0, 0.6, 0) },
}

local function setupAmbient(b)
	if ambient then
		ambient:Destroy()
		ambient = nil
	end
	if quality == "Low" then
		return
	end
	local a = AMBIENT[b] or AMBIENT[1]
	local p = part(workspace, V3(60, 1, 60), CF(0, -1000, 0), Color3.new(1, 1, 1), { Transparency = 1 })
	p.Name = "AmbientFX"
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(a.Color)
	e.LightEmission = a.Light
	e.Rate = a.Rate * (quality == "High" and 1 or 0.4)
	e.Lifetime = NumberRange.new(5, 9)
	e.Speed = NumberRange.new(a.Speed * 0.5, a.Speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = a.Accel
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, a.Size), NumberSequenceKeypoint.new(0.8, a.Size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.15)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
	ambient = p
end

---------------------------------------------------------------------------------------------
-- Свет и эффекты по качеству
---------------------------------------------------------------------------------------------
local function applyLighting()
	local hi, lo = quality == "High", quality == "Low"
	Lighting.GlobalShadows = not lo
	Lighting.ShadowSoftness = hi and 0.22 or 0.35 -- мягкие тени
	-- лёгкое размытие дальнего плана (только «Высокая»): картинка выглядит как в современных играх
	local dof = Lighting:FindFirstChild("SoftFocus")
	if hi then
		if not dof then
			dof = Instance.new("DepthOfFieldEffect")
			dof.Name = "SoftFocus"
			dof.Parent = Lighting
		end
		dof.Enabled = true
		dof.FarIntensity = 0.16
		dof.NearIntensity = 0
		dof.FocusDistance = 45
		dof.InFocusRadius = 70
	elseif dof then
		dof.Enabled = false
	end
	Lighting.EnvironmentSpecularScale = lo and 0.3 or 1
	Lighting.EnvironmentDiffuseScale = lo and 0.5 or 1
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = not lo
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Enabled = not lo
		rays.Intensity = hi and 0.09 or 0.04
		rays.Spread = hi and 0.75 or 0.5
	end
	local cc = Lighting:FindFirstChild("Grade")
	if cc then
		cc.Enabled = not lo
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(function()
			terrain.Decoration = false
		end)
		local clouds = terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Enabled = not lo
		end
		pcall(function()
			terrain.WaterWaveSize = hi and 0.15 or 0.05
			terrain.WaterReflectance = lo and 0.2 or 1
		end)
	end
	-- частицы мира (дым вулканов, искры жил и т.д.) на низкой — реже
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local base = d:GetAttribute("BaseRate")
			if not base then
				base = d.Rate
				d:SetAttribute("BaseRate", base)
			end
			d.Rate = lo and base * 0.3 or base
		elseif d:IsA("PointLight") and d:GetAttribute("Detail") ~= false then
			d.Shadows = hi and d.Range >= 14
		end
	end
end

local function rebuild()
	if biome < 1 then
		return
	end
	buildLayer(biome)
	spawnCritters(biome)
	setupAmbient(biome)
end

function Detail.SetQuality(q)
	if q == quality then
		return
	end
	quality = q
	applyLighting()
	rebuild()
end

function Detail.Quality()
	return quality
end

-- для превью/тестов: собрать слой деталей конкретного яруса
function Detail.BuildFor(b, q)
	quality = q or quality or "High"
	biome = b
	buildLayer(b)
	return layer
end

function Detail.Init()
	local player = Players.LocalPlayer
	quality = Settings.Quality()
	applyLighting()
	Settings.Changed:Connect(function()
		Detail.SetQuality(Settings.Quality())
	end)
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local b = math.clamp(math.floor(root.Position.X / Balance.BiomeSpacing + 0.5) + 1, 1, #BiomesData)
		if b ~= biome then
			biome = b
			task.defer(rebuild)
		end
	end)
	-- анимация живности и частиц у камеры
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local cam = workspace.CurrentCamera
		if ambient and cam then
			ambient.CFrame = CF(cam.CFrame.Position + V3(0, 4, 0))
		end
		for _, c in ipairs(critters) do
			if c.model.Parent then
				local a = t * 0.35 + c.phase
				local pos = c.center + V3(math.cos(a) * c.radius, math.sin(t * 1.3 + c.phase) * 1.2, math.sin(a * 1.3) * c.radius)
				local look = c.center + V3(math.cos(a + 0.1) * c.radius, 0, math.sin((a + 0.1) * 1.3) * c.radius)
				local cf = CFrame.lookAt(pos, V3(look.X, pos.Y, look.Z))
				if c.kind == "fly" then
					local flap = math.sin(t * 18 + c.phase) * 0.9
					c.body.CFrame = cf
					c.l.CFrame = cf * CF(-0.05, 0, 0) * ANG(0, 0, flap) * CF(-0.3, 0, 0)
					c.r.CFrame = cf * CF(0.05, 0, 0) * ANG(0, 0, -flap) * CF(0.3, 0, 0)
				else
					c.body.CFrame = cf
					c.body.Transparency = 0.1 + (math.sin(t * 3 + c.phase) * 0.5 + 0.5) * 0.6
				end
			end
		end
	end)
end

return Detail
