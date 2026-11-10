-- Builds a default arena + lighting at runtime so the game is playable from an
-- empty place. If you build your own map, put it in a Workspace folder named
-- "Arena" (with optional "DummySpawns" and "BossSpawn" parts) and this service
-- will use it instead of generating one.

local Lighting = game:GetService("Lighting")

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
	for i = 1, 6 do
		local x = -30 + (i - 1) * 12
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
		folder.Parent = workspace
		buildLighting()
	end
	self.Folder = folder
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
