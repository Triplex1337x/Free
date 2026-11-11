-- Builds a default arena + lighting at runtime so the game is playable from an
-- empty place. If you build your own map, put it in a Workspace folder named
-- "Arena" (with optional "DummySpawns" and "BossSpawn" parts) and this service
-- will use it instead of generating one.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Textures = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Textures"))

local MapService = {}

local ARENA_RADIUS = 130
local FLOOR_COLOR = Color3.fromRGB(46, 44, 64)
local ACCENT = Color3.fromRGB(255, 80, 150)
local ACCENT_2 = Color3.fromRGB(90, 200, 255)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

local function buildLighting()
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 100, 150)
	Lighting.GlobalShadows = true

	local function ensure(className, name)
		local inst = Lighting:FindFirstChild(name) or Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end

	local atmosphere = ensure("Atmosphere", "RiftAtmosphere")
	atmosphere.Density = 0.32
	atmosphere.Color = Color3.fromRGB(255, 190, 220)
	atmosphere.Decay = Color3.fromRGB(120, 80, 160)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6

	local bloom = ensure("BloomEffect", "RiftBloom")
	bloom.Intensity = 0.9
	bloom.Size = 30
	bloom.Threshold = 1.4

	local cc = ensure("ColorCorrectionEffect", "RiftColor")
	cc.Saturation = 0.18
	cc.Contrast = 0.08
	cc.TintColor = Color3.fromRGB(255, 244, 250)

	local rays = ensure("SunRaysEffect", "RiftSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.8

	local dof = ensure("DepthOfFieldEffect", "RiftDepth")
	dof.FarIntensity = 0.18
	dof.FocusDistance = 70
	dof.InFocusRadius = 90
	dof.NearIntensity = 0

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 215, 235)
	clouds.Parent = workspace.Terrain
end

local portalSlots: { CFrame } = {}
local hubSpawns: { CFrame } = {}

local function buildDecor(folder: Folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	local rng = Random.new(1337)
	local cylinder = CFrame.Angles(0, 0, math.rad(90))
	local GATE_RED = Color3.fromRGB(200, 45, 50)
	local DARK = Color3.fromRGB(28, 24, 36)
	local STONE = Color3.fromRGB(120, 115, 130)

	-- Shrine-style gates at the four entrances.
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local base = CFrame.new(math.cos(angle) * 118, 0, math.sin(angle) * 118) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		table.insert(portalSlots, base)
		for _, x in { -11, 11 } do
			part({ Name = "GatePost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(30, 2.6, 2.6), CFrame = base * CFrame.new(x, 15, 0) * cylinder, Material = Enum.Material.SmoothPlastic, Color = GATE_RED, Parent = decor })
			part({ Name = "GateFoot", Size = Vector3.new(3.6, 2, 3.6), CFrame = base * CFrame.new(x, 1, 0), Material = Enum.Material.Slate, Color = DARK, Parent = decor })
		end
		part({ Name = "GateTop", Size = Vector3.new(32, 2, 3.4), CFrame = base * CFrame.new(0, 30.5, 0), Material = Enum.Material.SmoothPlastic, Color = DARK, Parent = decor })
		part({ Name = "GateTopCurve", Size = Vector3.new(36, 1, 4), CFrame = base * CFrame.new(0, 32, 0), Material = Enum.Material.SmoothPlastic, Color = GATE_RED, Parent = decor })
		part({ Name = "GateBeam", Size = Vector3.new(26, 1.4, 1.8), CFrame = base * CFrame.new(0, 25, 0), Material = Enum.Material.SmoothPlastic, Color = GATE_RED, Parent = decor })
		part({ Name = "GatePlaque", Size = Vector3.new(4, 4, 0.6), CFrame = base * CFrame.new(0, 27.8, 0), Material = Enum.Material.Neon, Color = ACCENT, Parent = decor })
	end

	-- Stone lanterns around the duel ring.
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 48, 0, math.sin(angle) * 48)
		local look = CFrame.new(pos) * CFrame.Angles(0, -angle, 0)
		part({ Name = "LanternBase", Size = Vector3.new(3, 1, 3), CFrame = look * CFrame.new(0, 0.5, 0), Material = Enum.Material.Cobblestone, Color = STONE, Parent = decor })
		part({ Name = "LanternPole", Size = Vector3.new(1.2, 4, 1.2), CFrame = look * CFrame.new(0, 3, 0), Material = Enum.Material.Cobblestone, Color = STONE, Parent = decor })
		local lamp = part({ Name = "LanternLight", Size = Vector3.new(2.2, 2, 2.2), CFrame = look * CFrame.new(0, 6, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 190, 120), Parent = decor })
		part({ Name = "LanternRoof", Size = Vector3.new(3.6, 0.8, 3.6), CFrame = look * CFrame.new(0, 7.4, 0), Material = Enum.Material.Cobblestone, Color = STONE, Parent = decor })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 110)
		light.Range = 18
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = lamp
	end

	-- Floor details: radial glowing lines.
	for i = 0, 3 do
		part({ Name = "FloorLine", Size = Vector3.new(0.6, 0.12, ARENA_RADIUS * 2 - 20), CFrame = CFrame.new(0, 0.02, 0) * CFrame.Angles(0, i * math.pi / 4, 0), Material = Enum.Material.Neon, Color = ACCENT_2, Transparency = 0.55, CanCollide = false, Parent = decor })
	end

	-- Floating islands with crystals.
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dist = rng:NextNumber(150, 210)
		local pos = Vector3.new(math.cos(angle) * dist, rng:NextNumber(40, 85), math.sin(angle) * dist)
		local size = rng:NextNumber(14, 26)
		local rot = CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2))
		part({ Name = "IslandTop", Size = Vector3.new(size, size * 0.3, size * 0.9), CFrame = CFrame.new(pos) * rot, Material = Enum.Material.Grass, Color = Color3.fromRGB(110, 170, 120), CanCollide = false, Parent = decor })
		part({ Name = "IslandRock", Size = Vector3.new(size * 0.7, size * 0.6, size * 0.6), CFrame = CFrame.new(pos - Vector3.new(0, size * 0.4, 0)) * rot * CFrame.Angles(0.3, 0.5, 0.2), Material = Enum.Material.Rock, Color = Color3.fromRGB(80, 70, 95), CanCollide = false, Parent = decor })
		local crystal = part({ Name = "Crystal", Size = Vector3.new(2, size * 0.45, 2), CFrame = CFrame.new(pos + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(0.2, rng:NextNumber(0, 6.28), 0.15), Material = Enum.Material.Neon, Color = if i % 2 == 0 then ACCENT else ACCENT_2, CanCollide = false, Parent = decor })
		local glow = Instance.new("PointLight")
		glow.Color = crystal.Color
		glow.Range = 30
		glow.Brightness = 2
		glow.Parent = crystal
	end

	-- Distant mountains for a silhouette on the horizon.
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		local dist = rng:NextNumber(300, 380)
		local height = rng:NextNumber(90, 190)
		local width = rng:NextNumber(80, 140)
		part({
			Name = "Mountain",
			Size = Vector3.new(width, height, width * 0.8),
			CFrame = CFrame.new(math.cos(angle) * dist, height / 2 - 20, math.sin(angle) * dist) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.15, 0.15)),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(70, 55, 95),
			CanCollide = false,
			CastShadow = false,
			Parent = decor,
		})
		part({
			Name = "SnowCap",
			Size = Vector3.new(width * 0.45, height * 0.15, width * 0.4),
			CFrame = CFrame.new(math.cos(angle) * dist, height - 24, math.sin(angle) * dist),
			Material = Enum.Material.Snow,
			Color = Color3.fromRGB(240, 230, 255),
			CanCollide = false,
			CastShadow = false,
			Parent = decor,
		})
	end

	-- Drifting petals over the arena.
	local sky = part({ Name = "PetalEmitter", Size = Vector3.new(ARENA_RADIUS * 2, 1, ARENA_RADIUS * 2), CFrame = CFrame.new(0, 70, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = decor })
	local petals = Instance.new("ParticleEmitter")
	petals.Texture = Textures.Get("Petal") or "rbxasset://textures/particles/sparkles_main.dds"
	petals.Color = ColorSequence.new(Color3.fromRGB(255, 170, 200), Color3.fromRGB(255, 225, 240))
	petals.LightEmission = 0.3
	petals.Size = NumberSequence.new(0.5, 0.35)
	petals.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.9, 0.2), NumberSequenceKeypoint.new(1, 1) })
	petals.Lifetime = NumberRange.new(12, 16)
	petals.Rate = 35
	petals.Speed = NumberRange.new(2, 4)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.SpreadAngle = Vector2.new(30, 30)
	petals.Acceleration = Vector3.new(1.5, -1, 0.8)
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.Parent = sky
end

local function buildArena(folder: Folder)
	-- Clear the default template so it doesn't overlap the arena.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local cylinder = CFrame.Angles(0, 0, math.rad(90))

	part({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, ARENA_RADIUS * 2, ARENA_RADIUS * 2),
		CFrame = CFrame.new(0, -2, 0) * cylinder,
		Material = Enum.Material.Slate,
		Color = FLOOR_COLOR,
		Parent = folder,
	})
	part({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 70, 70),
		CFrame = CFrame.new(0, 0.05, 0) * cylinder,
		Material = Enum.Material.Neon,
		Color = ACCENT,
		CanCollide = false,
		Parent = folder,
	})
	part({
		Name = "RingInner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 64, 64),
		CFrame = CFrame.new(0, 0.06, 0) * cylinder,
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(36, 34, 52),
		CanCollide = false,
		Parent = folder,
	})

	-- Pillars with glowing caps (cover to break line of sight).
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 85, 0, math.sin(angle) * 85)
		part({
			Name = "Pillar",
			Size = Vector3.new(10, 34, 10),
			CFrame = CFrame.new(pos + Vector3.new(0, 17, 0)) * CFrame.Angles(0, angle, 0),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(70, 66, 92),
			Parent = folder,
		})
		part({
			Name = "PillarCap",
			Size = Vector3.new(11, 1.5, 11),
			CFrame = CFrame.new(pos + Vector3.new(0, 34.5, 0)) * CFrame.Angles(0, angle, 0),
			Material = Enum.Material.Neon,
			Color = if i % 2 == 0 then ACCENT else ACCENT_2,
			Parent = folder,
		})
	end

	-- Invisible boundary wall + a glowing rim.
	local segments = 32
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * ARENA_RADIUS, 0, math.sin(angle) * ARENA_RADIUS)
		local look = CFrame.lookAt(pos, Vector3.zero)
		local width = 2 * math.pi * ARENA_RADIUS / segments + 2
		part({
			Name = "Wall",
			Size = Vector3.new(width, 80, 2),
			CFrame = look + Vector3.new(0, 40, 0),
			Transparency = 1,
			Parent = folder,
		})
		part({
			Name = "Rim",
			Size = Vector3.new(width, 1, 3),
			CFrame = look + Vector3.new(0, 0.5, 0),
			Material = Enum.Material.Neon,
			Color = ACCENT_2,
			CanCollide = false,
			Parent = folder,
		})
	end

	-- Spawns around the edge, facing the centre.
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + math.pi / 6
		local pos = Vector3.new(math.cos(angle) * 110, 0.5, math.sin(angle) * 110)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(10, 1, 10)
		spawn.CFrame = CFrame.lookAt(pos, Vector3.new(0, 0.5, 0))
		table.insert(hubSpawns, spawn.CFrame)
		spawn.Material = Enum.Material.Neon
		spawn.Color = ACCENT
		spawn.Transparency = 0.4
		spawn.Duration = 3 -- spawn protection ForceField
		spawn.Neutral = true
		spawn.Parent = folder
	end

	-- Training grounds marker positions.
	local dummySpawns = Instance.new("Folder")
	dummySpawns.Name = "DummySpawns"
	dummySpawns.Parent = folder
	for i = 1, 10 do
		local x = -45 + (i - 1) * 10
		part({
			Name = "DummySpawn",
			Size = Vector3.new(4, 0.2, 4),
			CFrame = CFrame.new(x, 0.1, -55),
			Material = Enum.Material.Neon,
			Color = ACCENT_2,
			CanCollide = false,
			Transparency = 0.5,
			Parent = dummySpawns,
		})
	end

	part({
		Name = "BossSpawn",
		Size = Vector3.new(8, 0.2, 8),
		CFrame = CFrame.new(0, 0.1, 40),
		Material = Enum.Material.Neon,
		Color = ACCENT,
		CanCollide = false,
		Transparency = 0.5,
		Parent = folder,
	})
end

function MapService:Init()
	local folder = workspace:FindFirstChild("Arena")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Arena"
		buildArena(folder)
		buildDecor(folder)
		folder:SetAttribute("Generated", true) -- hub safe zones only apply to the generated layout
		folder.Parent = workspace
		buildLighting()
	end
	self.Folder = folder
end

-- Gate frames where zone portals go (falls back to a ring for custom maps).
function MapService:GetPortalSlots(): { CFrame }
	if #portalSlots > 0 then
		return portalSlots
	end
	local slots = {}
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		table.insert(slots, CFrame.lookAt(Vector3.new(math.cos(angle) * 90, 0, math.sin(angle) * 90), Vector3.zero))
	end
	return slots
end

function MapService:GetHubSpawn(): CFrame
	if #hubSpawns > 0 then
		return hubSpawns[math.random(1, #hubSpawns)]
	end
	for _, d in self.Folder:GetDescendants() do
		if d:IsA("SpawnLocation") then
			return d.CFrame
		end
	end
	return CFrame.new(0, 5, 0)
end

function MapService:GetFolder(): Folder
	return self.Folder
end

function MapService:GetDummySpawns(): { CFrame }
	local list = {}
	local spawns = self.Folder:FindFirstChild("DummySpawns")
	if spawns then
		for _, p in spawns:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(list, p.CFrame + Vector3.new(0, 3, 0))
			end
		end
	end
	return list
end

function MapService:GetBossSpawn(): CFrame?
	local p = self.Folder:FindFirstChild("BossSpawn")
	return p and p.CFrame + Vector3.new(0, 6, 0)
end

return MapService
