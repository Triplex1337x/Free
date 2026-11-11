-- Visual effect primitives: neon parts, ParticleEmitters, trails, beams,
-- decals, lights and post effects. Uses the custom textures from
-- Config/Textures when uploaded, Roblox built-in textures otherwise.
-- Everything is client-side, so it costs no network traffic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Vfx = {}
Vfx.ShakeEnabled = true
Vfx.DamageNumbers = true

local folder = Instance.new("Folder")
folder.Name = "ClientFx"
folder.Parent = workspace
Vfx.Folder = folder

local Textures = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Textures"))

local TEX = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

local rng = Random.new()

local function camera()
	return workspace.CurrentCamera
end

function Vfx.Tween(inst: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

function Vfx.Part(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = folder
	return p
end

function Vfx.Fade(part: BasePart, time: number, goal, style: Enum.EasingStyle?)
	goal = goal or {}
	goal.Transparency = 1
	Vfx.Tween(part, time, goal, style)
	Debris:AddItem(part, time + 0.05)
end

function Vfx.Ball(pos: Vector3, fromSize: number, toSize: number, color: Color3, time: number, transparency: number?, material: Enum.Material?)
	local ball = Vfx.Part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * fromSize,
		Position = pos,
		Color = color,
		Transparency = transparency or 0.2,
		Material = material or Enum.Material.Neon,
	})
	Vfx.Fade(ball, time, { Size = Vector3.one * toSize })
	return ball
end

function Vfx.Light(pos: Vector3, color: Color3, range: number, brightness: number, time: number)
	local holder = Vfx.Part({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = holder
	Vfx.Tween(light, time, { Brightness = 0 })
	Debris:AddItem(holder, time + 0.05)
end

---------------------------------------------------------------------------
-- Particles
---------------------------------------------------------------------------

local PRESETS = {
	Sparks = {
		Texture = TEX.Spark,
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0, 0.2),
		Lifetime = NumberRange.new(0.18, 0.4),
		Speed = NumberRange.new(28, 55),
		Drag = 7,
		SpreadAngle = Vector2.new(180, 180),
	},
	Embers = {
		Texture = TEX.Spark,
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1.3),
		Speed = NumberRange.new(6, 16),
		Acceleration = Vector3.new(0, 9, 0),
		Drag = 2,
		SpreadAngle = Vector2.new(180, 180),
	},
	Flame = {
		Texture = TEX.Fire,
		LightEmission = 0.9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.3, 0.65),
		Speed = NumberRange.new(10, 22),
		Acceleration = Vector3.new(0, 14, 0),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
		SpreadAngle = Vector2.new(180, 180),
	},
	Smoke = {
		Texture = TEX.Smoke,
		LightEmission = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(5, 12),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		SpreadAngle = Vector2.new(180, 30),
	},
	Mist = {
		Texture = TEX.Smoke,
		LightEmission = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(8, 18),
		Drag = 5,
		SpreadAngle = Vector2.new(180, 180),
	},
	Glitter = {
		Texture = TEX.Spark,
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.1), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(4, 14),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		SpreadAngle = Vector2.new(180, 180),
	},
}

-- Presets that only make sense with our custom textures.
local OPTIONAL = { Flash = true, Impact = true, Splash = true, Swirl = true, Sunburst = true }
PRESETS.Flash = {
	LightEmission = 1,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 2) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.12, 0.16),
	Speed = NumberRange.new(0, 0),
	Rotation = NumberRange.new(0, 45),
}
PRESETS.Impact = {
	LightEmission = 1,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.14, 0.2),
	Speed = NumberRange.new(0, 0),
	Rotation = NumberRange.new(0, 360),
}
PRESETS.Splash = {
	LightEmission = 0.6,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.3, 0.4),
	Speed = NumberRange.new(0, 0),
}
PRESETS.Swirl = {
	LightEmission = 0.8,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.3, 0.45),
	Speed = NumberRange.new(0, 0),
	Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-540, -360),
}
PRESETS.Sunburst = {
	LightEmission = 1,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 11) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.2, 0.3),
	Speed = NumberRange.new(0, 0),
	Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-60, 60),
}

-- Swap in the uploaded textures (Config/Textures) where available.
do
	local streak = Textures.Get("SparkStreak")
	if streak then
		PRESETS.Sparks.Texture = streak
		PRESETS.Sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		PRESETS.Sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	end
	local flame = Textures.Get("Flame")
	if flame then
		local p = PRESETS.Flame
		p.Texture = flame
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(0.4, 3.2), NumberSequenceKeypoint.new(1, 0.8) })
		p.Rotation = NumberRange.new(-15, 15)
		p.RotSpeed = NumberRange.new(-20, 20)
	end
	local embers = Textures.Get("EmberCluster")
	if embers then
		PRESETS.Embers.Texture = embers
		PRESETS.Embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	end
	local smoke = Textures.Get("SmokePuff")
	if smoke then
		PRESETS.Smoke.Texture = smoke
		PRESETS.Mist.Texture = smoke
	end
	local star = Textures.Get("FlashStar")
	if star then
		PRESETS.Glitter.Texture = star
		PRESETS.Flash.Texture = star
	end
	PRESETS.Impact.Texture = Textures.Get("ImpactBurst")
	PRESETS.Splash.Texture = Textures.Get("WaterSplash")
	PRESETS.Swirl.Texture = Textures.Get("WindSwirl")
	PRESETS.Sunburst.Texture = Textures.Get("Sunburst")
end

Vfx.Presets = PRESETS

local function configure(emitter: ParticleEmitter, preset, color: Color3?)
	for k, v in preset do
		(emitter :: any)[k] = v
	end
	if color then
		emitter.Color = ColorSequence.new(color)
	end
end

function Vfx.Emit(pos: Vector3, presetName: string, count: number, color: Color3?)
	local preset = PRESETS[presetName]
	if not preset or (OPTIONAL[presetName] and not preset.Texture) then
		return
	end
	local holder = Vfx.Part({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local emitter = Instance.new("ParticleEmitter")
	configure(emitter, preset, color)
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(holder, preset.Lifetime.Max + 0.2)
end

-- Continuous emitter parented to `parent`. Returns the emitter.
function Vfx.Attach(parent: Instance, presetName: string, rate: number, color: Color3?)
	local emitter = Instance.new("ParticleEmitter")
	configure(emitter, PRESETS[presetName], color)
	emitter.Rate = rate
	emitter.LockedToPart = false
	emitter.Parent = parent
	return emitter
end

---------------------------------------------------------------------------
-- Shapes
---------------------------------------------------------------------------

-- Expanding ring made of segments (reads as a clean shockwave).
function Vfx.Ring(cf: CFrame, fromRadius: number, toRadius: number, color: Color3, time: number, thickness: number?, segments: number?)
	local n = segments or 28
	thickness = thickness or 0.6
	local parts = {}
	for i = 1, n do
		parts[i] = Vfx.Part({ Size = Vector3.new(thickness, thickness * 0.5, 1), Color = color, Transparency = 0.05 })
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - start) / time)
		local eased = 1 - (1 - alpha) ^ 3
		local radius = fromRadius + (toRadius - fromRadius) * eased
		local length = 2 * math.pi * radius / n + 0.1
		for i, p in parts do
			local angle = (i / n) * math.pi * 2
			p.Size = Vector3.new(thickness * (1 - alpha * 0.6), thickness * 0.5, length)
			p.CFrame = cf * CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0, 0)
			p.Transparency = alpha
		end
		if alpha >= 1 then
			connection:Disconnect()
			for _, p in parts do
				p:Destroy()
			end
		end
	end)
end

-- Anime slash crescent. `cf` faces the slash direction; roll it for
-- diagonal cuts. The arc sweeps on, then thins out.
function Vfx.Crescent(cf: CFrame, radius: number, color: Color3, arc: number?, thickness: number?, time: number?)
	arc = math.rad(arc or 140)
	thickness = thickness or 1
	time = time or 0.28
	local n = 16
	local parts = {}
	for i = 1, n do
		local a = -arc / 2 + arc * (i - 1) / (n - 1)
		local taper = math.sin(math.pi * (i - 0.5) / n)
		local segLength = arc * radius / n + 0.15
		local p = Vfx.Part({
			Size = Vector3.new(thickness * taper + 0.05, 0.15, segLength),
			CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius) * CFrame.Angles(0, math.pi / 2, 0),
			Color = color,
			Transparency = 1,
		})
		parts[i] = p
		task.delay((i / n) * 0.06, function()
			p.Transparency = 0
			Vfx.Fade(p, time, { Size = Vector3.new(0.05, 0.05, segLength) })
		end)
	end
	-- White hot core for contrast.
	local core = Vfx.Part({
		Size = Vector3.new(thickness * 0.35, 0.1, arc * radius * 0.7),
		CFrame = cf * CFrame.new(0, 0, -radius) * CFrame.Angles(0, math.pi / 2, 0),
		Color = Color3.new(1, 1, 1),
		Transparency = 0.2,
	})
	Vfx.Fade(core, time * 0.6)
	return parts
end

-- Jagged lightning bolt between two points.
function Vfx.Lightning(from: Vector3, to: Vector3, color: Color3, width: number?, jitter: number?, time: number?)
	width = width or 0.4
	time = time or 0.25
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local n = math.clamp(math.floor(length / 3), 4, 14)
	jitter = jitter or math.min(3, length * 0.12)
	local axis = CFrame.lookAt(from, to)
	local points = { from }
	for i = 1, n - 1 do
		local offset = axis.RightVector * rng:NextNumber(-jitter, jitter) + axis.UpVector * rng:NextNumber(-jitter, jitter)
		table.insert(points, from + delta * (i / n) + offset)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = Vfx.Part({
			Size = Vector3.new(width, width, (b - a).Magnitude + width),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = color,
			Transparency = 0,
		})
		task.delay(time * 0.35, function()
			seg.Transparency = 0.6
			task.wait(0.03)
			seg.Transparency = 0
			Vfx.Fade(seg, time * 0.6, { Size = Vector3.new(width * 0.2, width * 0.2, seg.Size.Z) })
		end)
	end
	Vfx.Light((from + to) / 2, color, 20, 4, time)

	local strip = Textures.Get("LightningStrip")
	if strip then
		local holder = Vfx.Part({ Transparency = 1, Size = Vector3.one * 0.2, Position = from })
		local a0 = Instance.new("Attachment")
		a0.WorldPosition = from
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.WorldPosition = to
		a1.Parent = holder
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Texture = strip
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = 1
		beam.Width0, beam.Width1 = width * 6, width * 6
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(color)
		beam.Parent = holder
		Vfx.Tween(beam, time, { Width0 = 0, Width1 = 0 })
		Debris:AddItem(holder, time + 0.05)
	end
end

-- Flat textured decal on the ground (cracks, shockwave rings).
function Vfx.GroundDecal(pos: Vector3, textureName: string, size: number, color: Color3, hold: number, fade: number, grow: number?)
	local texture = Textures.Get(textureName)
	if not texture then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("Arena") or workspace.Terrain, workspace:FindFirstChild("Zones") or workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), params)
	local y = if hit then hit.Position.Y + 0.06 else pos.Y - 2.9
	local plate = Vfx.Part({
		Size = Vector3.new(size, 0.05, size),
		CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Transparency = 1,
	})
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = texture
	decal.Color3 = color
	decal.Parent = plate
	if grow then
		Vfx.Tween(plate, 0.25, { Size = Vector3.new(size * grow, 0.05, size * grow) }, Enum.EasingStyle.Expo)
	end
	task.delay(hold, function()
		Vfx.Tween(decal, fade, { Transparency = 1 })
	end)
	Debris:AddItem(plate, hold + fade + 0.05)
	return true
end

-- Spinning energy orb sprite used for charge-ups. Returns a cleanup function.
function Vfx.ChargeOrb(target: BasePart, color: Color3, duration: number)
	local texture = Textures.Get("EnergyOrb")
	if not texture then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 10)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = target
	gui.Parent = folder
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = texture
	image.ImageColor3 = color
	image.ImageTransparency = 0.6
	image.Parent = gui
	Vfx.Tween(gui, duration, { Size = UDim2.fromScale(3, 3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Vfx.Tween(image, duration, { ImageTransparency = 0, Rotation = 540 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(gui, duration + 0.05)
	return gui
end

-- Rock / droplet chunks with simple ballistic motion and a ground bounce.
function Vfx.Debris(pos: Vector3, count: number, color: Color3, options)
	options = options or {}
	local material = options.Material or Enum.Material.Slate
	local size = options.Size or 1.2
	local speed = options.Speed or 45
	local life = options.Life or 1.6
	local shape = options.Shape or Enum.PartType.Block

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local arena = workspace:FindFirstChild("Arena")
	params.FilterDescendantsInstances = { workspace.Terrain, arena or workspace.Terrain, workspace:FindFirstChild("Zones") or workspace.Terrain }
	local ground = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -50, 0), params)
	local groundY = if ground then ground.Position.Y else pos.Y - 3

	local chunks = {}
	for _ = 1, count do
		local s = size * rng:NextNumber(0.5, 1.3)
		local p = Vfx.Part({
			Shape = shape,
			Size = Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.7, 1.2)),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
			Color = color,
			Material = material,
			Transparency = options.Transparency or 0,
		})
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)).Unit
		table.insert(chunks, {
			Part = p,
			Velocity = dir * speed * rng:NextNumber(0.5, 1),
			Spin = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3)),
			Resting = false,
		})
	end

	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		for _, c in chunks do
			if not c.Resting then
				c.Velocity += Vector3.new(0, -140 * dt, 0)
				local nextPos = c.Part.Position + c.Velocity * dt
				local half = c.Part.Size.Y / 2
				if nextPos.Y - half <= groundY then
					nextPos = Vector3.new(nextPos.X, groundY + half, nextPos.Z)
					if math.abs(c.Velocity.Y) > 18 then
						c.Velocity = Vector3.new(c.Velocity.X * 0.5, -c.Velocity.Y * 0.35, c.Velocity.Z * 0.5)
					else
						c.Resting = true
					end
				end
				c.Part.CFrame = (c.Part.CFrame - c.Part.Position) * c.Spin + nextPos
			end
		end
		if os.clock() - start > life then
			connection:Disconnect()
			for _, c in chunks do
				Vfx.Fade(c.Part, 0.4, { Size = c.Part.Size * 0.3 })
			end
		end
	end)
end

-- Vertical beam of light / energy.
function Vfx.Pillar(pos: Vector3, color: Color3, radius: number, height: number, time: number)
	local cf = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local beam = Vfx.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 0.4, radius * 0.4), CFrame = cf, Color = color, Transparency = 0.1 })
	Vfx.Tween(beam, time * 0.25, { Size = Vector3.new(height, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	task.delay(time * 0.25, function()
		Vfx.Fade(beam, time * 0.75, { Size = Vector3.new(height * 1.2, 0.1, 0.1) })
	end)
	local core = Vfx.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 0.6, radius * 0.6), CFrame = cf, Color = Color3.new(1, 1, 1), Transparency = 0.1 })
	Vfx.Fade(core, time * 0.6, { Size = Vector3.new(height, 0.1, 0.1) })
end

-- Sunburst rays radiating from a point.
function Vfx.Rays(pos: Vector3, color: Color3, count: number, length: number, time: number)
	for i = 1, count do
		local dir = CFrame.Angles(rng:NextNumber(-0.6, 0.9), (i / count) * math.pi * 2, 0)
		local cf = CFrame.new(pos) * dir
		local ray = Vfx.Part({ Size = Vector3.new(0.4, 0.4, 1), CFrame = cf * CFrame.new(0, 0, -0.5), Color = color, Transparency = 0 })
		Vfx.Tween(ray, time * 0.3, { Size = Vector3.new(0.6, 0.6, length), CFrame = cf * CFrame.new(0, 0, -length / 2) }, Enum.EasingStyle.Expo)
		task.delay(time * 0.3, function()
			Vfx.Fade(ray, time * 0.7, { Size = Vector3.new(0.05, 0.05, length * 1.1) })
		end)
	end
end

-- Sphere that collapses inward, then a dark core flashes.
function Vfx.Implode(pos: Vector3, radius: number, color: Color3, time: number)
	local shell = Vfx.Part({ Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 2, Position = pos, Color = color, Transparency = 0.6, Material = Enum.Material.ForceField })
	Vfx.Tween(shell, time, { Size = Vector3.one * 0.5, Transparency = 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(shell, time)
	task.delay(time, function()
		Vfx.Ball(pos, 1, radius * 0.8, Color3.fromRGB(10, 0, 20), 0.35, 0, Enum.Material.SmoothPlastic)
		Vfx.Ball(pos, 1, radius * 1.4, color, 0.4, 0.3)
	end)
end

-- Ghost copies of a character along a path (dash afterimages).
function Vfx.Afterimages(character: Model, from: Vector3, to: Vector3, color: Color3, count: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local dir = to - from
	if dir.Magnitude < 1 then
		return
	end
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(dir.X, 0, dir.Z))
	local offsets = {}
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 1 then
			table.insert(offsets, { Size = part.Size, Offset = root.CFrame:ToObjectSpace(part.CFrame) })
		end
	end
	for i = 1, count do
		local pos = from:Lerp(to, (i - 1) / math.max(1, count - 1))
		local base = CFrame.new(pos) * facing
		task.delay(i * 0.02, function()
			for _, o in offsets do
				local ghost = Vfx.Part({ Size = o.Size, CFrame = base * o.Offset, Color = color, Transparency = 0.45, Material = Enum.Material.ForceField })
				Vfx.Fade(ghost, 0.35 + i * 0.03)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Character attachments
---------------------------------------------------------------------------

local trails = setmetatable({}, { __mode = "k" })

local function makeTrail(part: BasePart, color: Color3)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.35, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.35, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.MinLength = 0
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.Enabled = false
	trail.Parent = part
	return trail
end

-- Briefly lights up glowing trails on the fists and feet.
function Vfx.LimbTrails(character: Model, color: Color3, duration: number)
	local set = trails[character]
	if not set then
		set = {}
		for _, name in { "RightHand", "LeftHand", "RightFoot", "LeftFoot" } do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				table.insert(set, makeTrail(part, color))
			end
		end
		trails[character] = set
	end
	for _, trail in set do
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		trail.Enabled = true
	end
	set.Token = (set.Token or 0) + 1
	local token = set.Token
	task.delay(duration, function()
		if set.Token == token then
			for _, trail in set do
				trail.Enabled = false
			end
		end
	end)
end

-- Awakening aura. Returns a cleanup function.
function Vfx.Aura(character: Model, color: Color3, element: string?)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
	if not torso then
		return function() end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "RiftAura"
	attachment.Parent = torso

	local items = { attachment }
	local main = Vfx.Attach(attachment, if element == "Fire" then "Flame" elseif element == "Earth" then "Smoke" else "Mist", 22, color)
	main.LockedToPart = true
	main.Speed = NumberRange.new(3, 7)
	main.Acceleration = Vector3.new(0, 10, 0)
	main.SpreadAngle = Vector2.new(25, 25)
	local sparks = Vfx.Attach(attachment, "Embers", 14, color)
	sparks.Acceleration = Vector3.new(0, 12, 0)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 2
	light.Parent = torso
	table.insert(items, light)

	local highlight = Instance.new("Highlight")
	highlight.Name = "RiftAuraGlow"
	highlight.FillTransparency = 1
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	table.insert(items, highlight)

	local pulse = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		highlight.OutlineTransparency = 0.25 + math.sin(t * 6) * 0.25
		light.Brightness = 2 + math.sin(t * 6) * 0.8
	end)

	return function()
		pulse:Disconnect()
		for _, item in items do
			item:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Sounds
---------------------------------------------------------------------------

-- Plays a sound at a position (3D) or globally. `id` is an rbxasset:// path
-- or an uploaded asset id number.
function Vfx.Sound(id, pos: Vector3?, volume: number?, speed: number?)
	if not id or id == 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = if type(id) == "number" then "rbxassetid://" .. id else id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = speed or 1
	sound.RollOffMaxDistance = 120
	local holder = nil
	if pos then
		holder = Vfx.Part({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
		sound.Parent = holder
	else
		sound.Parent = workspace.CurrentCamera
	end
	sound:Play()
	Debris:AddItem(holder or sound, 3)
end

---------------------------------------------------------------------------
-- Screen effects
---------------------------------------------------------------------------

local shakeUntil, shakeStrength = 0, 0

function Vfx.Shake(strength: number, duration: number, origin: Vector3?)
	if not Vfx.ShakeEnabled then
		return
	end
	if origin then
		local d = (camera().CFrame.Position - origin).Magnitude
		strength *= math.clamp(1 - d / 140, 0, 1)
	end
	if strength <= 0 then
		return
	end
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

RunService:BindToRenderStep("RiftCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
	if os.clock() < shakeUntil then
		local s = shakeStrength
		camera().CFrame *= CFrame.new((rng:NextNumber() - 0.5) * s, (rng:NextNumber() - 0.5) * s, 0)
			* CFrame.Angles(0, 0, (rng:NextNumber() - 0.5) * s * 0.02)
	else
		shakeStrength = 0
	end
end)

function Vfx.Flash(color: Color3, brightness: number, time: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = color
	cc.Brightness = brightness
	cc.Parent = Lighting
	Vfx.Tween(cc, time, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	Debris:AddItem(cc, time + 0.05)
end

-- Classic anime impact frame: two hard black-and-white frames.
function Vfx.ImpactFrame()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -1
	cc.Contrast = 3
	cc.Brightness = 0.25
	cc.Parent = Lighting
	task.delay(0.05, function()
		cc.Brightness = -0.35
		cc.Contrast = 4
		task.wait(0.05)
		cc:Destroy()
	end)
end

local fovToken = 0
function Vfx.FovPunch(amount: number, time: number)
	local cam = camera()
	fovToken += 1
	local token = fovToken
	local base = 70
	Vfx.Tween(cam, time * 0.25, { FieldOfView = base + amount }, Enum.EasingStyle.Quad)
	task.delay(time * 0.25, function()
		if token == fovToken then
			Vfx.Tween(cam, time * 0.75, { FieldOfView = base }, Enum.EasingStyle.Sine)
		end
	end)
end

local function screenGui(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("RiftScreenFx")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "RiftScreenFx"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 5
		gui.Parent = playerGui
	end
	return gui
end

-- Radial speed lines around the screen edge.
function Vfx.SpeedLines(duration: number, color: Color3?)
	local gui = screenGui()
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	for i = 1, 36 do
		local angle = (i / 36) * 360 + rng:NextNumber(-4, 4)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = color or Color3.new(1, 1, 1)
		line.BackgroundTransparency = rng:NextNumber(0.1, 0.5)
		line.Size = UDim2.new(rng:NextNumber(0.25, 0.45), 0, 0, rng:NextInteger(2, 5))
		line.Rotation = angle
		local rad = math.rad(angle)
		local dist = rng:NextNumber(0.62, 0.8)
		line.Position = UDim2.fromScale(0.5 + math.cos(rad) * dist, 0.5 + math.sin(rad) * dist)
		line.Parent = holder
		Vfx.Tween(line, duration, {
			Position = UDim2.fromScale(0.5 + math.cos(rad) * (dist + 0.2), 0.5 + math.sin(rad) * (dist + 0.2)),
			BackgroundTransparency = 1,
		})
	end
	Debris:AddItem(holder, duration + 0.05)
end

-- Cinematic letterbox bars.
function Vfx.Letterbox(duration: number)
	local gui = screenGui()
	local bars = {}
	for i, anchor in { 0, 1 } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, anchor)
		bar.Position = UDim2.fromScale(0, anchor)
		bar.Size = UDim2.fromScale(1, 0)
		bar.Parent = gui
		bars[i] = bar
		Vfx.Tween(bar, 0.2, { Size = UDim2.fromScale(1, 0.11) })
	end
	task.delay(duration, function()
		for _, bar in bars do
			Vfx.Tween(bar, 0.3, { Size = UDim2.fromScale(1, 0) })
			Debris:AddItem(bar, 0.35)
		end
	end)
end

return Vfx
