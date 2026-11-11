-- Builds the four PvE zones (themed floating islands far from the hub),
-- the portals between them, and handles travel / respawn per zone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)

local ZoneService = {}

local RADIUS = 230
local TRAVEL_COOLDOWN = 3

local rng = Random.new(2024)
local lastTravel = {} :: { [Player]: number }
local zoneData = {} :: { [string]: any }

local SIGN_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local SAFE_COLOR = Color3.fromRGB(80, 235, 130)
local PVP_COLOR = Color3.fromRGB(255, 60, 70)

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "ClassName" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	return p
end

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

-- Random point on the island, away from the spawn plaza (+Z) and boss arena (-Z).
local function randomSpot(origin: Vector3, minR: number, maxR: number): Vector3
	for _ = 1, 30 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minR, maxR)
		local p = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		if p.Z < 140 and not (p.Z < -110 and math.abs(p.X) < 55) then
			return origin + p
		end
	end
	return origin + Vector3.new(0, 0, 60)
end

---------------------------------------------------------------------------
-- Shared island structure
---------------------------------------------------------------------------

local THEMES = {
	Ember = { Floor = Enum.Material.Basalt, FloorColor = Color3.fromRGB(48, 36, 36), Rock = Color3.fromRGB(60, 40, 38), Accent = Color3.fromRGB(255, 110, 40) },
	Tidal = { Floor = Enum.Material.Sand, FloorColor = Color3.fromRGB(226, 210, 170), Rock = Color3.fromRGB(150, 140, 120), Accent = Color3.fromRGB(70, 200, 255) },
	Storm = { Floor = Enum.Material.Snow, FloorColor = Color3.fromRGB(235, 240, 250), Rock = Color3.fromRGB(110, 115, 130), Accent = Color3.fromRGB(255, 230, 80) },
	Void = { Floor = Enum.Material.Slate, FloorColor = Color3.fromRGB(26, 20, 36), Rock = Color3.fromRGB(35, 25, 50), Accent = Color3.fromRGB(170, 80, 255) },
}

local function buildIsland(folder: Folder, origin: Vector3, theme)
	local cylinder = CFrame.Angles(0, 0, math.rad(90))
	part({ Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, RADIUS * 2, RADIUS * 2), CFrame = CFrame.new(origin + Vector3.new(0, -3, 0)) * cylinder, Material = theme.Floor, Color = theme.FloorColor, Parent = folder })

	-- Rocky underside so the island looks like it floats.
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2
		local r = RADIUS * rng:NextNumber(0.55, 0.9)
		local h = rng:NextNumber(40, 110)
		part({
			Name = "Underside",
			Size = Vector3.new(rng:NextNumber(50, 90), h, rng:NextNumber(50, 90)),
			CFrame = CFrame.new(origin + Vector3.new(math.cos(angle) * r, -h / 2 - 4, math.sin(angle) * r)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
			Material = Enum.Material.Rock,
			Color = theme.Rock,
			CanCollide = false,
			CastShadow = false,
			Parent = folder,
		})
	end

	-- Boundary walls with a glowing rim.
	local segments = 40
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local pos = origin + Vector3.new(math.cos(angle) * RADIUS, 0, math.sin(angle) * RADIUS)
		local look = CFrame.lookAt(pos, origin)
		local width = 2 * math.pi * RADIUS / segments + 2
		part({ Name = "Wall", Size = Vector3.new(width, 120, 2), CFrame = look + Vector3.new(0, 60, 0), Transparency = 1, Parent = folder })
		part({ Name = "Rim", Size = Vector3.new(width, 1.2, 3), CFrame = look + Vector3.new(0, 0.6, 0), Material = Enum.Material.Neon, Color = theme.Accent, CanCollide = false, Parent = folder })
	end

	-- Spawn plaza.
	part({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 46, 46), CFrame = CFrame.new(origin + Vector3.new(0, 0.2, 190)) * cylinder, Material = Enum.Material.Marble, Color = Color3.fromRGB(220, 215, 225), Parent = folder })
	part({ Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 48, 48), CFrame = CFrame.new(origin + Vector3.new(0, 0.18, 190)) * cylinder, Material = Enum.Material.Neon, Color = theme.Accent, CanCollide = false, Parent = folder })

	-- Boss arena circle.
	part({ Name = "BossArena", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 90, 90), CFrame = CFrame.new(origin + Vector3.new(0, 0.1, -150)) * cylinder, Material = Enum.Material.Neon, Color = theme.Accent, Transparency = 0.6, CanCollide = false, Parent = folder })
	part({ Name = "BossArenaInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 84, 84), CFrame = CFrame.new(origin + Vector3.new(0, 0.12, -150)) * cylinder, Material = theme.Floor, Color = theme.FloorColor, CanCollide = false, Parent = folder })
end

---------------------------------------------------------------------------
-- Theme decor
---------------------------------------------------------------------------

local Decor = {}

function Decor.Ember(folder: Folder, origin: Vector3)
	local lava = Color3.fromRGB(255, 110, 30)
	for _ = 1, 9 do
		local pos = randomSpot(origin, 30, 200)
		local r = rng:NextNumber(10, 22)
		local pool = part({ Name = "LavaPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, r * 2, r * 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = lava, CanCollide = false, Parent = folder })
		light(pool, lava, r * 2.5, 2)
		emitter(pool, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), lava), LightEmission = 1, Rate = 6, Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(4, 9), Acceleration = Vector3.new(0, 5, 0), Size = NumberSequence.new(0.4, 0), SpreadAngle = Vector2.new(20, 20) })
	end
	for _ = 1, 26 do
		local pos = randomSpot(origin, 25, 215)
		local h = rng:NextNumber(12, 45)
		part({ Name = "Spire", ClassName = "WedgePart", Size = Vector3.new(rng:NextNumber(6, 12), h, rng:NextNumber(8, 16)), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Material = Enum.Material.Basalt, Color = Color3.fromRGB(40, 30, 30), Parent = folder })
	end
	-- Volcano on the horizon.
	local volcano = origin + Vector3.new(0, 0, -380)
	for i = 0, 5 do
		local r = 160 - i * 26
		part({ Name = "Volcano", Shape = Enum.PartType.Cylinder, Size = Vector3.new(30, r * 2, r * 2), CFrame = CFrame.new(volcano + Vector3.new(0, i * 30, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Basalt, Color = Color3.fromRGB(45, 32, 30), CanCollide = false, Parent = folder })
	end
	local crater = part({ Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 50, 50), CFrame = CFrame.new(volcano + Vector3.new(0, 166, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = lava, CanCollide = false, Parent = folder })
	light(crater, lava, 60, 3)
	emitter(crater, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(70, 50, 50)), Rate = 8, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(10, 16), Size = NumberSequence.new(20, 60), Transparency = NumberSequence.new(0.4, 1), SpreadAngle = Vector2.new(20, 20) })
end

function Decor.Tidal(folder: Folder, origin: Vector3)
	local water = Color3.fromRGB(60, 170, 230)
	for _ = 1, 10 do
		local pos = randomSpot(origin, 30, 200)
		local r = rng:NextNumber(12, 26)
		part({ Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, r * 2, r * 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Glass, Color = water, Transparency = 0.35, Reflectance = 0.2, CanCollide = false, Parent = folder })
	end
	-- Shrine colonnade with teal roofs.
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2
		local pos = origin + Vector3.new(math.cos(angle) * 120, 0, math.sin(angle) * 120)
		part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(30, 5, 5), CFrame = CFrame.new(pos + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = Color3.fromRGB(240, 240, 235), Parent = folder })
		part({ Name = "Roof", ClassName = "WedgePart", Size = Vector3.new(10, 4, 10), CFrame = CFrame.new(pos + Vector3.new(0, 32, 0)) * CFrame.Angles(0, -angle, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(40, 150, 150), Parent = folder })
	end
	for _ = 1, 30 do
		local pos = randomSpot(origin, 20, 215)
		local c = part({ Name = "Coral", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(2, 5), Position = pos + Vector3.new(0, 1, 0), Material = Enum.Material.Neon, Color = if rng:NextNumber() > 0.5 then Color3.fromRGB(255, 120, 170) else Color3.fromRGB(255, 170, 90), CanCollide = false, Parent = folder })
		if rng:NextNumber() > 0.7 then
			light(c, c.Color, 12, 1)
		end
	end
	-- Waterfall cliffs on the horizon.
	for i = -2, 2 do
		local base = origin + Vector3.new(i * 90, 0, -360)
		part({ Name = "Cliff", Size = Vector3.new(80, 220, 60), CFrame = CFrame.new(base + Vector3.new(0, 90, 0)), Material = Enum.Material.Rock, Color = Color3.fromRGB(90, 110, 110), CanCollide = false, Parent = folder })
		part({ Name = "Waterfall", Size = Vector3.new(24, 200, 2), CFrame = CFrame.new(base + Vector3.new(0, 90, 31)), Material = Enum.Material.Glass, Color = Color3.fromRGB(180, 230, 255), Transparency = 0.3, CanCollide = false, Parent = folder })
	end
end

function Decor.Storm(folder: Folder, origin: Vector3)
	local bolt = Color3.fromRGB(255, 230, 80)
	for _ = 1, 30 do
		local pos = randomSpot(origin, 25, 215)
		local h = rng:NextNumber(8, 28)
		part({ Name = "IceCrystal", Size = Vector3.new(rng:NextNumber(3, 7), h, rng:NextNumber(3, 7)), CFrame = CFrame.new(pos + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Material = Enum.Material.Glass, Color = Color3.fromRGB(170, 220, 255), Transparency = 0.25, Parent = folder })
	end
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local pos = origin + Vector3.new(math.cos(angle) * 150, 0, math.sin(angle) * 150)
		part({ Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(50, 10, 10), CFrame = CFrame.new(pos + Vector3.new(0, 25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 75, 90), Parent = folder })
		local rod = part({ Name = "Rod", Size = Vector3.new(1, 14, 1), CFrame = CFrame.new(pos + Vector3.new(0, 57, 0)), Material = Enum.Material.Neon, Color = bolt, Parent = folder })
		light(rod, bolt, 30, 3)
		emitter(rod, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(bolt), LightEmission = 1, Rate = 10, Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(8, 16), Size = NumberSequence.new(0.8, 0), SpreadAngle = Vector2.new(180, 180) })
	end
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2
		local dist = rng:NextNumber(340, 420)
		local h = rng:NextNumber(150, 260)
		local pos = origin + Vector3.new(math.cos(angle) * dist, h / 2 - 30, math.sin(angle) * dist)
		part({ Name = "Mountain", Size = Vector3.new(120, h, 100), CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Material = Enum.Material.Rock, Color = Color3.fromRGB(85, 90, 105), CanCollide = false, CastShadow = false, Parent = folder })
		part({ Name = "Snow", Size = Vector3.new(70, 30, 60), CFrame = CFrame.new(pos + Vector3.new(0, h / 2 - 10, 0)), Material = Enum.Material.Snow, Color = Color3.fromRGB(245, 248, 255), CanCollide = false, CastShadow = false, Parent = folder })
	end
	local sky = part({ Name = "Snowfall", Size = Vector3.new(RADIUS * 2, 1, RADIUS * 2), CFrame = CFrame.new(origin + Vector3.new(0, 80, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = folder })
	emitter(sky, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.new(1, 1, 1)), Rate = 60, Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(5, 8), EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(0.35), Acceleration = Vector3.new(3, 0, 1), SpreadAngle = Vector2.new(20, 20) })
end

function Decor.Void(folder: Folder, origin: Vector3)
	local void = Color3.fromRGB(170, 80, 255)
	for _ = 1, 22 do
		local pos = randomSpot(origin, 20, 215)
		local length = rng:NextNumber(10, 30)
		part({ Name = "Crack", Size = Vector3.new(0.6, 0.15, length), CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Material = Enum.Material.Neon, Color = void, CanCollide = false, Parent = folder })
	end
	for _ = 1, 16 do
		local pos = randomSpot(origin, 30, 210)
		local h = rng:NextNumber(18, 40)
		local obelisk = part({ Name = "Obelisk", Size = Vector3.new(5, h, 5), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.15, 0.15)), Material = Enum.Material.Slate, Color = Color3.fromRGB(15, 10, 22), Parent = folder })
		part({ Name = "ObeliskEdge", Size = Vector3.new(5.3, 1, 5.3), CFrame = obelisk.CFrame * CFrame.new(0, h / 2 - 2, 0), Material = Enum.Material.Neon, Color = void, CanCollide = false, Parent = folder })
	end
	for _ = 1, 30 do
		local pos = origin + Vector3.new(rng:NextNumber(-260, 260), rng:NextNumber(30, 120), rng:NextNumber(-260, 260))
		part({ Name = "Shard", ClassName = "CornerWedgePart", Size = Vector3.new(rng:NextNumber(4, 12), rng:NextNumber(10, 30), rng:NextNumber(4, 12)), CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)), Material = Enum.Material.Glass, Color = void, Transparency = 0.2, CanCollide = false, CastShadow = false, Parent = folder })
	end
	-- The Rift itself: a giant glowing ring in the sky.
	local center = origin + Vector3.new(0, 160, -330)
	for i = 1, 48 do
		local angle = (i / 48) * math.pi * 2
		part({ Name = "Rift", Size = Vector3.new(6, 6, 2 * math.pi * 110 / 48 + 2), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, angle) * CFrame.new(110, 0, 0) * CFrame.Angles(math.rad(90), 0, 0), Material = Enum.Material.Neon, Color = void, CanCollide = false, Parent = folder })
	end
	local core = part({ Name = "RiftCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 150, Position = center, Material = Enum.Material.ForceField, Color = void, CanCollide = false, CastShadow = false, Parent = folder })
	light(core, void, 120, 4)
end

---------------------------------------------------------------------------
-- Area markers and sky platforms
---------------------------------------------------------------------------

local function sign(parent: Instance, pos: Vector3, title: string, sub: string?, color: Color3, size: number?)
	local anchor = part({ Name = "Sign", Size = Vector3.one * 0.5, Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, Parent = parent })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size or 300, if sub then 70 else 44)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, if sub then 0.6 else 1)
	t.FontFace = SIGN_FONT
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Text = title
	t.Parent = gui
	if sub then
		local u = Instance.new("TextLabel")
		u.BackgroundTransparency = 1
		u.Position = UDim2.fromScale(0, 0.6)
		u.Size = UDim2.fromScale(1, 0.4)
		u.FontFace = SIGN_FONT
		u.TextScaled = true
		u.TextColor3 = Color3.new(1, 1, 1)
		u.TextStrokeTransparency = 0.2
		u.Text = sub
		u.Parent = gui
	end
end

-- Glowing ring on the ground marking an area border.
local function ring(parent: Instance, center: Vector3, radius: number, color: Color3)
	local n = math.max(16, math.floor(radius))
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		part({
			Name = "AreaRing",
			Size = Vector3.new(0.8, 0.3, 2 * math.pi * radius / n + 0.3),
			CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0),
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
		})
	end
end

function ZoneService:MarkIslandAreas(folder: Folder, origin: Vector3)
	local areas = Zones.Areas.Island
	local safe = origin + areas.Safe.Offset
	local pvp = origin + areas.Pvp.Offset
	ring(folder, safe, areas.Safe.Radius, SAFE_COLOR)
	ring(folder, pvp, areas.Pvp.Radius, PVP_COLOR)
	sign(folder, safe + Vector3.new(0, 14, -areas.Safe.Radius + 4), "БЕЗОПАСНАЯ ЗОНА", "Здесь никто не может тебя атаковать", SAFE_COLOR)
	sign(folder, pvp + Vector3.new(0, 22, areas.Pvp.Radius - 4), "PVP-ЗОНА", "Босс и бои между игроками", PVP_COLOR)
end

function ZoneService:MarkHubAreas(folder: Instance)
	ring(folder, Vector3.zero, Zones.Areas.HubPvpRadius, PVP_COLOR)
	sign(folder, Vector3.new(0, 24, Zones.Areas.HubPvpRadius - 6), "PVP-ЗОНА", "Дуэли и Страж Разлома", PVP_COLOR)
	sign(folder, Vector3.new(0, 24, -Zones.Areas.HubPvpRadius + 6), "PVP-ЗОНА", nil, PVP_COLOR, 220)
	local cfg = Zones.HubSafe
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + math.pi / 6
		ring(folder, Vector3.new(math.cos(a) * 110, 0, math.sin(a) * 110), cfg.SpawnRadius, SAFE_COLOR)
	end
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		ring(folder, Vector3.new(math.cos(a) * 118, 0, math.sin(a) * 118), cfg.PortalRadius, SAFE_COLOR)
	end
	local c, h = cfg.TrainingCenter, cfg.TrainingHalfSize
	for _, edge in { { Vector3.new(0, 0, -h.Y), h.X * 2, 0 }, { Vector3.new(0, 0, h.Y), h.X * 2, 0 }, { Vector3.new(-h.X, 0, 0), h.Y * 2, 90 }, { Vector3.new(h.X, 0, 0), h.Y * 2, 90 } } do
		part({ Name = "AreaRing", Size = Vector3.new(edge[2], 0.3, 0.8), CFrame = CFrame.new(c + edge[1] + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(edge[3]), 0), Material = Enum.Material.Neon, Color = SAFE_COLOR, CanCollide = false, CanQuery = false, Parent = folder })
	end
	sign(folder, c + Vector3.new(0, 12, h.Y), "ТРЕНИРОВОЧНАЯ ПЛОЩАДКА", "Безопасная зона", SAFE_COLOR)
end

-- Tiered floating platforms: ground -> tier 1 (double jump) -> tier 2 ->
-- top isle (triple jump). Returns spawn points for the elites on top.
function ZoneService:BuildSky(parent: Instance, center: Vector3, accent: Color3, floorMaterial: Enum.Material, floorColor: Color3): { CFrame }
	local sky = Zones.Sky
	local cylinder = CFrame.Angles(0, 0, math.rad(90))
	local function pad(pos: Vector3, radius: number)
		part({ Name = "SkyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, radius * 2, radius * 2), CFrame = CFrame.new(pos + Vector3.new(0, -1, 0)) * cylinder, Material = floorMaterial, Color = floorColor, Parent = parent })
		part({ Name = "SkyPadRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, radius * 2 + 1, radius * 2 + 1), CFrame = CFrame.new(pos + Vector3.new(0, -1.6, 0)) * cylinder, Material = Enum.Material.Neon, Color = accent, CanCollide = false, Parent = parent })
	end
	for i = 0, 2 do
		local a = math.rad(i * 120)
		pad(center + Vector3.new(math.cos(a) * 46, sky.Tier1Height, math.sin(a) * 46), 8)
		local b = math.rad(60 + i * 120)
		pad(center + Vector3.new(math.cos(b) * 33, sky.Tier2Height, math.sin(b) * 33), 7)
	end
	local top = center + Vector3.new(0, sky.TopHeight, 0)
	pad(top, sky.TopRadius)
	-- Rocky underside + crystals so it reads as a floating isle.
	part({ Name = "SkyRock", ClassName = "WedgePart", Size = Vector3.new(sky.TopRadius * 1.4, 14, sky.TopRadius * 1.4), CFrame = CFrame.new(top + Vector3.new(0, -9, 0)) * CFrame.Angles(math.pi, 0, 0), Material = Enum.Material.Rock, Color = Color3.fromRGB(70, 60, 80), CanCollide = false, Parent = parent })
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		local crystal = part({ Name = "SkyCrystal", Size = Vector3.new(2, 8, 2), CFrame = CFrame.new(top + Vector3.new(math.cos(a) * (sky.TopRadius - 3), 4, math.sin(a) * (sky.TopRadius - 3))) * CFrame.Angles(0.2, a, 0.15), Material = Enum.Material.Neon, Color = accent, CanCollide = false, Parent = parent })
		light(crystal, accent, 16, 1.5)
	end
	sign(parent, top + Vector3.new(0, 12, 0), "НЕБЕСНЫЙ ОСТРОВ", "Элитные мобы • нужен тройной прыжок (15 ур.)", accent)
	sign(parent, center + Vector3.new(math.cos(0) * 46, 6, 0), "↑ ПРЫЖКИ ВВЕРХ ↑", "Двойной — с 10 ур., тройной — с 15 ур.", accent)

	local spawns = {}
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, sky.TopRadius - 8)
		table.insert(spawns, CFrame.new(top + Vector3.new(math.cos(a) * r, 4, math.sin(a) * r)))
	end
	return spawns
end

function ZoneService:GetSkySpawns(zoneId: string): { CFrame }
	local z = zoneData[zoneId]
	return z and z.SkySpawns or {}
end

---------------------------------------------------------------------------
-- Portals
---------------------------------------------------------------------------

function ZoneService:CreatePortal(parent: Instance, base: CFrame, targetId: string)
	local target = Zones.Get(targetId)
	local disc = part({
		Name = "Portal_" .. targetId,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 20, 20),
		CFrame = base * CFrame.new(0, 13, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Material = Enum.Material.ForceField,
		Color = target.Color,
		CanCollide = false,
		Parent = parent,
	})
	local inner = part({ Name = "PortalCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 17, 17), CFrame = disc.CFrame, Material = Enum.Material.Neon, Color = target.Color, Transparency = 0.55, CanCollide = false, Parent = parent })
	light(inner, target.Color, 30, 3)
	emitter(inner, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(target.Color, Color3.new(1, 1, 1)), LightEmission = 1, Rate = 25, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 4), Size = NumberSequence.new(0.8, 0), SpreadAngle = Vector2.new(180, 180) })

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.6)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = target.Color
	title.TextStrokeTransparency = 0
	title.Text = string.upper(target.Name)
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.TextStrokeTransparency = 0.2
	sub.Text = target.Subtitle
	sub.Parent = gui
	gui.Parent = inner

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Travel"
	prompt.ObjectText = target.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = inner
	prompt.Triggered:Connect(function(player)
		local result = self:Travel(player, targetId)
		if not result.Ok then
			Remotes.Notify:FireClient(player, result.Error, "error")
		end
	end)
end

---------------------------------------------------------------------------
-- Travel & spawning
---------------------------------------------------------------------------

function ZoneService:GetSpawn(zoneId: string): CFrame?
	local z = zoneData[zoneId]
	return z and z.Spawn
end

function ZoneService:GetMobSpawns(zoneId: string): { CFrame }
	local z = zoneData[zoneId]
	return z and z.MobSpawns or {}
end

function ZoneService:GetBossSpawn(zoneId: string): CFrame?
	if zoneId == "Hub" then
		return self.Services.MapService:GetBossSpawn()
	end
	local z = zoneData[zoneId]
	return z and z.BossSpawn
end

function ZoneService:Travel(player: Player, zoneId)
	local zone = type(zoneId) == "string" and Zones.Get(zoneId)
	if not zone then
		return { Ok = false, Error = "Unknown destination." }
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return { Ok = false, Error = "You can't travel right now." }
	end
	if (player:GetAttribute("Zone") or "Hub") == zoneId then
		return { Ok = false, Error = "You are already there." }
	end
	if self.Services.ProgressionService:GetLevel(player) < zone.MinLevel then
		return { Ok = false, Error = ("%s requires Lv. %d."):format(zone.Name, zone.MinLevel) }
	end
	if self.Services.CombatService:InCombat(player) then
		return { Ok = false, Error = "Can't travel mid-fight!" }
	end
	local t = os.clock()
	if t - (lastTravel[player] or 0) < TRAVEL_COOLDOWN then
		return { Ok = false, Error = "Portal is recharging..." }
	end
	lastTravel[player] = t

	player:SetAttribute("Zone", zoneId)
	local spawn = if zoneId == "Hub" then self.Services.MapService:GetHubSpawn() else zoneData[zoneId].Spawn
	character:PivotTo(spawn + Vector3.new(0, 4, 0))
	Remotes.Fx:FireAllClients("Teleport", { Character = character, Color = zone.Color })
	return { Ok = true }
end

function ZoneService:Init(services)
	self.Services = services
	local world = Instance.new("Folder")
	world.Name = "Zones"

	for _, id in Zones.Order do
		local zone = Zones.Get(id)
		if zone.Origin then
			local folder = Instance.new("Folder")
			folder.Name = id
			folder.Parent = world
			local theme = THEMES[zone.Theme]
			buildIsland(folder, zone.Origin, theme)
			Decor[zone.Theme](folder, zone.Origin)

			local spawns = {}
			for _ = 1, 18 do
				table.insert(spawns, CFrame.new(randomSpot(zone.Origin, 40, 175) + Vector3.new(0, 4, 0)))
			end
			zoneData[id] = {
				Spawn = CFrame.lookAt(zone.Origin + Vector3.new(0, 1, 190), zone.Origin + Vector3.new(0, 1, 0)),
				MobSpawns = spawns,
				BossSpawn = CFrame.new(zone.Origin + Vector3.new(0, 6, -150)),
				SkySpawns = self:BuildSky(folder, zone.Origin + Zones.Sky.IslandOffset, theme.Accent, theme.Floor, theme.FloorColor),
			}
			self:MarkIslandAreas(folder, zone.Origin)
			-- Return portal behind the plaza.
			self:CreatePortal(folder, CFrame.lookAt(zone.Origin + Vector3.new(0, 0, 215), zone.Origin), "Hub")
		end
	end
	world.Parent = workspace

	-- Portals from the hub to every zone.
	local slots = services.MapService:GetPortalSlots()
	local i = 0
	for _, id in Zones.Order do
		if id ~= "Hub" then
			i += 1
			if slots[i] then
				self:CreatePortal(services.MapService:GetFolder(), slots[i], id)
			end
		end
	end

	-- Hub: sky platforms (if the generated arena is used) and area markers.
	local hubFolder = services.MapService:GetFolder()
	if hubFolder:GetAttribute("Generated") then
		local hub = Zones.Get("Hub")
		local skyFolder = Instance.new("Folder")
		skyFolder.Name = "HubSky"
		skyFolder.Parent = hubFolder
		zoneData.Hub = { SkySpawns = self:BuildSky(skyFolder, hub.SkyCenter, Color3.fromRGB(90, 200, 255), Enum.Material.Marble, Color3.fromRGB(70, 66, 92)) }
		self:MarkHubAreas(hubFolder)
	end

	-- Combat queries ignore all zone geometry (like the hub map).
	services.CombatService.ExtraExclusions = { world }

	services.DataService:OnLoaded(function(player)
		player:SetAttribute("Zone", "Hub")
		player.CharacterAdded:Connect(function(character)
			local zoneId = player:GetAttribute("Zone") or "Hub"
			if zoneId ~= "Hub" and zoneData[zoneId] then
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if root then
					task.wait()
					character:PivotTo(zoneData[zoneId].Spawn + Vector3.new(0, 4, 0))
				end
			end
		end)
	end)
end

function ZoneService:Start()
	Remotes.Travel.OnServerInvoke = function(player, zoneId)
		return self:Travel(player, zoneId)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return ZoneService
