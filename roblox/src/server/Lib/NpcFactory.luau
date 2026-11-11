-- Builds NPC rigs with procedural anime-style outfits (no uploaded assets):
-- spiky hair, glowing eyes, horns, crowns, shoulder armour, capes, weapons,
-- glowing cracks and auras, plus an overhead name / level / HP bar.

local Players = game:GetService("Players")

local NpcFactory = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local C = Color3.fromRGB

-- Skin = head/hands colour; Torso / Arms / Legs = clothing colours.
NpcFactory.Outfits = {
	Dummy = { Skin = C(196, 160, 110), Material = Enum.Material.Wood, Hair = { Color = C(230, 200, 90), Style = "Straw" }, Target = true },
	-- Training-ground students in martial-arts gis.
	Trainee1 = { Skin = C(255, 214, 180), Torso = C(245, 245, 245), Arms = C(245, 245, 245), Legs = C(40, 40, 50), Hair = { Color = C(30, 30, 40), Style = "Spiky" }, Eyes = C(60, 160, 255), Headband = C(220, 40, 50), Belt = C(30, 30, 30), Target = true },
	Trainee2 = { Skin = C(232, 186, 150), Torso = C(255, 140, 40), Arms = C(255, 140, 40), Legs = C(30, 50, 120), Hair = { Color = C(255, 220, 90), Style = "Spiky" }, Eyes = C(80, 200, 255), Headband = C(30, 60, 160), Belt = C(30, 60, 160), Target = true },
	Trainee3 = { Skin = C(190, 140, 105), Torso = C(40, 70, 160), Arms = C(40, 70, 160), Legs = C(20, 20, 30), Hair = { Color = C(230, 60, 80), Style = "Spiky" }, Eyes = C(255, 90, 120), Scarf = C(230, 60, 80), Belt = C(240, 240, 240), Target = true },
	Trainee4 = { Skin = C(130, 90, 65), Torso = C(25, 25, 30), Arms = C(25, 25, 30), Legs = C(25, 25, 30), Hair = { Color = C(240, 240, 250), Style = "Spiky" }, Eyes = C(170, 110, 255), Headband = C(150, 80, 255), Belt = C(150, 80, 255), Target = true },
	Sprite = { Skin = C(200, 230, 255), Torso = C(120, 80, 220), Legs = C(80, 50, 160), Hair = { Color = C(255, 120, 200), Style = "Spiky", Neon = true }, Eyes = C(255, 255, 255), Belt = C(255, 120, 200) },
	Imp = { Skin = C(120, 35, 30), Torso = C(55, 20, 20), Legs = C(35, 15, 15), Hair = { Color = C(255, 140, 40), Style = "Spiky", Neon = true }, Eyes = C(255, 230, 90), Horns = C(40, 20, 20), Belt = C(255, 120, 40) },
	Brute = { Skin = C(90, 70, 65), Torso = C(45, 40, 40), Legs = C(30, 28, 28), Eyes = C(255, 120, 40), Pads = { Color = C(70, 60, 60), Material = Enum.Material.Basalt }, Cracks = C(255, 110, 30), Belt = C(255, 110, 30) },
	Tyrant = {
		Skin = C(40, 25, 25), Eyes = C(255, 200, 60), Crown = C(255, 120, 30), Pads = { Color = C(60, 40, 35), Material = Enum.Material.Basalt },
		Cape = { Color = C(150, 30, 20) }, Cracks = C(255, 110, 30), Aura = { Texture = FIRE, Color = C(255, 120, 40) }, Weapon = "Greatsword", WeaponColor = C(255, 110, 30),
	},
	Stalker = { Skin = C(70, 150, 160), Torso = C(20, 70, 90), Legs = C(15, 45, 60), Hair = { Color = C(80, 220, 230), Style = "Crest" }, Eyes = C(150, 255, 255), Belt = C(80, 220, 230) },
	Sentinel = { Skin = C(200, 215, 230), Torso = C(30, 90, 140), Legs = C(220, 225, 235), Pads = { Color = C(40, 120, 170), Material = Enum.Material.Metal }, Eyes = C(120, 230, 255), Weapon = "Trident", WeaponColor = C(80, 220, 255), Belt = C(40, 120, 170) },
	Leviathan = {
		Skin = C(20, 60, 90), Eyes = C(150, 255, 255), Crown = C(80, 220, 255), Pads = { Color = C(20, 90, 140), Material = Enum.Material.Metal },
		Cape = { Color = C(20, 90, 140) }, Aura = { Texture = SMOKE, Color = C(90, 210, 255) }, Weapon = "Trident", WeaponColor = C(80, 220, 255),
	},
	Acolyte = { Skin = C(240, 215, 190), Torso = C(235, 235, 240), Arms = C(235, 235, 240), Legs = C(60, 60, 80), Hood = C(225, 225, 235), Eyes = C(255, 230, 80), Belt = C(255, 230, 80) },
	Ronin = { Skin = C(225, 190, 160), Torso = C(50, 60, 85), Arms = C(50, 60, 85), Legs = C(30, 35, 50), Hat = C(200, 170, 110), Scarf = C(140, 255, 190), Eyes = C(140, 255, 190), Weapon = "Katana", WeaponColor = C(140, 255, 190) },
	Shogun = {
		Skin = C(30, 30, 40), Eyes = C(255, 230, 80), Crown = C(255, 220, 70), Pads = { Color = C(150, 30, 30), Material = Enum.Material.Metal },
		Cape = { Color = C(120, 20, 25) }, Aura = { Texture = SPARK, Color = C(255, 230, 80) }, Weapon = "Katana", WeaponColor = C(255, 230, 80),
	},
	Wraith = { Skin = C(60, 50, 80), Torso = C(20, 15, 30), Arms = C(20, 15, 30), Legs = C(15, 10, 25), Hood = C(30, 20, 45), Eyes = C(190, 110, 255), Cape = { Color = C(60, 30, 100), Material = Enum.Material.ForceField } },
	Horror = { Skin = C(35, 20, 55), Eyes = C(220, 140, 255), Spikes = C(170, 80, 255), Pads = { Color = C(50, 30, 75), Material = Enum.Material.Slate }, Cracks = C(170, 80, 255) },
	Sovereign = {
		Skin = C(240, 230, 200), Eyes = C(255, 255, 255), Crown = C(255, 215, 90), Pads = { Color = C(230, 190, 90), Material = Enum.Material.Metal },
		Cape = { Color = C(250, 245, 230) }, Aura = { Texture = SPARK, Color = C(255, 230, 150) }, Weapon = "Greatsword", WeaponColor = C(255, 230, 150),
	},
	Warden = {
		Skin = C(40, 30, 60), Eyes = C(190, 110, 255), Horns = C(25, 15, 35), Pads = { Color = C(50, 35, 75), Material = Enum.Material.Slate },
		Cape = { Color = C(70, 30, 110) }, Cracks = C(170, 80, 255), Aura = { Texture = SMOKE, Color = C(160, 80, 255) },
	},
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function piece(model: Model, attachTo: BasePart, className: string, size: Vector3, offset: CFrame, props)
	local p = Instance.new(className) :: BasePart
	p.Size = size
	p.CFrame = attachTo.CFrame * offset
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		(p :: any)[k] = v
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = p
	weld.Part1 = attachTo
	weld.Parent = p
	local folder = model:FindFirstChild("Outfit")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Outfit"
		folder.Parent = model
	end
	p.Parent = folder
	return p
end

local function hair(model: Model, head: BasePart, cfg)
	local s = head.Size
	if cfg.Style == "Crest" then
		for i = -2, 2 do
			piece(model, head, "WedgePart", Vector3.new(s.X * 0.12, s.Y * (0.7 - math.abs(i) * 0.1), s.Z * 0.7),
				CFrame.new(i * s.X * 0.06, s.Y * 0.7, s.Z * 0.05), { Color = cfg.Color, Material = Enum.Material.SmoothPlastic })
		end
		return
	end
	local count = if cfg.Style == "Straw" then 10 else 9
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local tilt = if cfg.Style == "Straw" then 0.9 else 0.55
		local length = s.Y * (if cfg.Style == "Straw" then 0.5 else 0.75) * (0.8 + (i % 3) * 0.15)
		local offset = CFrame.new(math.cos(angle) * s.X * 0.28, s.Y * 0.42, math.sin(angle) * s.Z * 0.28)
			* CFrame.Angles(0, -angle, 0)
			* CFrame.Angles(0, 0, -tilt)
			* CFrame.new(0, length * 0.4, 0)
		piece(model, head, "CornerWedgePart", Vector3.new(s.X * 0.32, length, s.Z * 0.32), offset, {
			Color = cfg.Color,
			Material = if cfg.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		})
	end
	-- Fringe over the forehead.
	piece(model, head, "WedgePart", Vector3.new(s.X * 0.9, s.Y * 0.3, s.Z * 0.25),
		CFrame.new(0, s.Y * 0.32, -s.Z * 0.42) * CFrame.Angles(0, math.pi, 0), {
			Color = cfg.Color,
			Material = if cfg.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		})
end

local function eyes(model: Model, head: BasePart, color: Color3)
	local s = head.Size
	for _, side in { -1, 1 } do
		local eye = piece(model, head, "Part", Vector3.new(s.X * 0.2, s.Y * 0.08, 0.05),
			CFrame.new(side * s.X * 0.18, s.Y * 0.05, -s.Z * 0.5 - 0.02) * CFrame.Angles(0, 0, math.rad(side * -12)),
			{ Color = color, Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 4
		light.Brightness = 1
		light.Parent = eye
	end
end

local function horns(model: Model, head: BasePart, color: Color3)
	local s = head.Size
	for _, side in { -1, 1 } do
		piece(model, head, "CornerWedgePart", Vector3.new(s.X * 0.2, s.Y * 0.8, s.Z * 0.2),
			CFrame.new(side * s.X * 0.38, s.Y * 0.65, 0) * CFrame.Angles(0, 0, math.rad(side * -25)),
			{ Color = color, Material = Enum.Material.Slate })
	end
end

local function crown(model: Model, head: BasePart, color: Color3)
	local s = head.Size
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2
		piece(model, head, "CornerWedgePart", Vector3.new(s.X * 0.18, s.Y * (0.45 + (i % 2) * 0.3), s.Z * 0.18),
			CFrame.new(math.cos(angle) * s.X * 0.4, s.Y * 0.62, math.sin(angle) * s.Z * 0.4) * CFrame.Angles(0, -angle, 0),
			{ Color = color, Material = Enum.Material.Neon })
	end
end

local function weapon(model: Model, hand: BasePart, kind: string, color: Color3)
	local s = hand.Size.Y
	local metal = { Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal }
	if kind == "Katana" or kind == "Greatsword" then
		local length = s * (if kind == "Greatsword" then 9 else 7)
		local width = s * (if kind == "Greatsword" then 0.9 else 0.35)
		piece(model, hand, "Part", Vector3.new(s * 0.25, s * 1.2, s * 0.25), CFrame.new(0, -s * 0.3, 0), { Color = Color3.fromRGB(30, 25, 30) })
		piece(model, hand, "Part", Vector3.new(width * 1.6, s * 0.2, s * 0.5), CFrame.new(0, -s * 0.95, 0), { Color = color, Material = Enum.Material.Neon })
		piece(model, hand, "Part", Vector3.new(width, length, s * 0.12), CFrame.new(0, -s * 1 - length / 2, 0), metal)
		piece(model, hand, "Part", Vector3.new(width * 0.25, length * 0.95, s * 0.14), CFrame.new(width * 0.4, -s * 1 - length / 2, 0), { Color = color, Material = Enum.Material.Neon })
	elseif kind == "Trident" then
		local length = s * 10
		piece(model, hand, "Part", Vector3.new(s * 0.2, length, s * 0.2), CFrame.new(0, length * 0.15, 0), { Color = Color3.fromRGB(40, 60, 80), Material = Enum.Material.Metal })
		for i = -1, 1 do
			piece(model, hand, "WedgePart", Vector3.new(s * 0.15, s * 1.6, s * 0.4), CFrame.new(i * s * 0.45, length * 0.65 + s * 0.6, 0), { Color = color, Material = Enum.Material.Neon })
		end
	end
end

local function aura(part: BasePart, cfg)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = cfg.Texture
	emitter.Color = ColorSequence.new(cfg.Color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Acceleration = Vector3.new(0, 8, 0)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Parent = attachment
	local light = Instance.new("PointLight")
	light.Color = cfg.Color
	light.Range = 18
	light.Brightness = 2
	light.Parent = part
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function NpcFactory.Rig(name: string, scale: number, outfitId: string): Model
	local cfg = NpcFactory.Outfits[outfitId] or NpcFactory.Outfits.Dummy
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = scale
	description.WidthScale = scale
	description.DepthScale = scale
	description.HeadScale = scale
	description.HeadColor = cfg.Skin
	description.TorsoColor = cfg.Torso or cfg.Skin
	description.LeftArmColor = cfg.Arms or cfg.Skin
	description.RightArmColor = cfg.Arms or cfg.Skin
	description.LeftLegColor = cfg.Legs or cfg.Skin
	description.RightLegColor = cfg.Legs or cfg.Skin
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	if cfg.Material then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.Material = cfg.Material
			end
		end
	end
	NpcFactory.Dress(model, cfg)
	return model
end

function NpcFactory.Dress(model: Model, cfg)
	local head = model:FindFirstChild("Head") :: BasePart
	local upper = model:FindFirstChild("UpperTorso") :: BasePart
	local lower = model:FindFirstChild("LowerTorso") :: BasePart
	if not (head and upper and lower) then
		return
	end
	-- Remove the default face decal for a cleaner anime look with glowing eyes.
	if cfg.Eyes then
		local face = head:FindFirstChild("face")
		if face then
			face:Destroy()
		end
		eyes(model, head, cfg.Eyes)
	end
	if cfg.Hair then
		hair(model, head, cfg.Hair)
	end
	if cfg.Horns then
		horns(model, head, cfg.Horns)
	end
	if cfg.Crown then
		crown(model, head, cfg.Crown)
	end
	if cfg.Hood then
		local s = head.Size
		piece(model, head, "Part", Vector3.new(s.X * 1.2, s.Y * 0.55, s.Z * 1.2), CFrame.new(0, s.Y * 0.32, s.Z * 0.05), { Color = cfg.Hood, Material = Enum.Material.Fabric })
		piece(model, head, "Part", Vector3.new(s.X * 1.2, s.Y * 1.1, s.Z * 0.2), CFrame.new(0, 0, s.Z * 0.6), { Color = cfg.Hood, Material = Enum.Material.Fabric })
	end
	if cfg.Hat then
		local s = head.Size
		local hat = piece(model, head, "Part", Vector3.new(s.Y * 0.25, s.X * 2.6, s.X * 2.6), CFrame.new(0, s.Y * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), { Color = cfg.Hat, Material = Enum.Material.Fabric })
		hat.Shape = Enum.PartType.Cylinder
		piece(model, head, "CornerWedgePart", Vector3.new(s.X * 0.7, s.Y * 0.35, s.Z * 0.7), CFrame.new(0, s.Y * 0.8, 0), { Color = cfg.Hat, Material = Enum.Material.Fabric })
	end
	if cfg.Headband then
		local s = head.Size
		piece(model, head, "Part", Vector3.new(s.X * 1.06, s.Y * 0.16, s.Z * 1.06), CFrame.new(0, s.Y * 0.22, 0), { Color = cfg.Headband, Material = Enum.Material.Fabric })
		for _, side in { -1, 1 } do
			piece(model, head, "Part", Vector3.new(0.08, s.Y * 0.14, s.Z * 0.7),
				CFrame.new(side * s.X * 0.15, s.Y * 0.1, s.Z * 0.75) * CFrame.Angles(math.rad(-25), math.rad(side * 15), 0),
				{ Color = cfg.Headband, Material = Enum.Material.Fabric })
		end
	end
	if cfg.Scarf then
		local s = upper.Size
		piece(model, upper, "Part", Vector3.new(s.X * 0.8, s.Y * 0.18, s.Z * 1.25), CFrame.new(0, s.Y * 0.45, 0), { Color = cfg.Scarf, Material = Enum.Material.Fabric })
		piece(model, upper, "Part", Vector3.new(s.X * 0.25, s.Y * 1.1, 0.1), CFrame.new(s.X * 0.2, -s.Y * 0.1, s.Z * 0.62) * CFrame.Angles(math.rad(-12), 0, 0), { Color = cfg.Scarf, Material = Enum.Material.Fabric })
	end
	if cfg.Pads then
		for _, side in { "Left", "Right" } do
			local arm = model:FindFirstChild(side .. "UpperArm") :: BasePart?
			if arm then
				local s = arm.Size
				local sign = if side == "Left" then -1 else 1
				piece(model, arm, "Part", Vector3.new(s.X * 1.7, s.Y * 0.32, s.Z * 1.6), CFrame.new(sign * s.X * 0.2, s.Y * 0.4, 0) * CFrame.Angles(0, 0, math.rad(sign * -15)),
					{ Color = cfg.Pads.Color, Material = cfg.Pads.Material or Enum.Material.Metal })
			end
		end
	end
	if cfg.Belt then
		local s = lower.Size
		piece(model, lower, "Part", Vector3.new(s.X * 1.08, s.Y * 0.25, s.Z * 1.12), CFrame.new(0, s.Y * 0.2, 0), { Color = cfg.Belt, Material = Enum.Material.Neon })
	end
	if cfg.Cracks then
		local s = upper.Size
		for i = 1, 4 do
			piece(model, upper, "Part", Vector3.new(s.X * 0.06, s.Y * 0.45, 0.06),
				CFrame.new((i - 2.5) * s.X * 0.2, (i % 2) * s.Y * 0.1, -s.Z * 0.51) * CFrame.Angles(0, 0, math.rad(25 * (i % 2 == 0 and 1 or -1))),
				{ Color = cfg.Cracks, Material = Enum.Material.Neon })
		end
	end
	if cfg.Spikes then
		local s = upper.Size
		for i = 1, 5 do
			piece(model, upper, "CornerWedgePart", Vector3.new(s.X * 0.18, s.Y * (0.6 + (i % 2) * 0.4), s.Z * 0.3),
				CFrame.new((i - 3) * s.X * 0.2, s.Y * 0.3, s.Z * 0.55) * CFrame.Angles(math.rad(-30), 0, 0),
				{ Color = cfg.Spikes, Material = Enum.Material.Glass, Transparency = 0.15 })
		end
	end
	if cfg.Cape then
		local s = upper.Size
		piece(model, upper, "Part", Vector3.new(s.X * 1.15, s.Y * 2.3, 0.1), CFrame.new(0, -s.Y * 0.55, s.Z * 0.58) * CFrame.Angles(math.rad(8), 0, 0),
			{ Color = cfg.Cape.Color, Material = cfg.Cape.Material or Enum.Material.Fabric })
	end
	if cfg.Target then
		local s = upper.Size
		for i, color in { Color3.fromRGB(220, 50, 50), Color3.fromRGB(245, 245, 245), Color3.fromRGB(220, 50, 50) } do
			local ring = piece(model, upper, "Part", Vector3.new(0.05, s.X * (0.8 - i * 0.2), s.X * (0.8 - i * 0.2)),
				CFrame.new(0, 0, -s.Z * 0.5 - i * 0.01) * CFrame.Angles(0, math.rad(90), 0), { Color = color })
			ring.Shape = Enum.PartType.Cylinder
		end
	end
	if cfg.Weapon then
		local hand = model:FindFirstChild("RightHand") :: BasePart?
		if hand then
			weapon(model, hand, cfg.Weapon, cfg.WeaponColor or Color3.new(1, 1, 1))
		end
	end
	if cfg.Aura then
		aura(upper, cfg.Aura)
	end
end

-- Overhead name, level and live HP bar.
function NpcFactory.Overhead(model: Model, name: string, level: number?, color: Color3, isBoss: boolean?)
	local head = model:FindFirstChild("Head") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local gui = Instance.new("BillboardGui")
	gui.Name = "NpcOverhead"
	gui.Size = UDim2.fromOffset(if isBoss then 260 else 180, if isBoss then 64 else 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y * 1.6 + 1.2, 0)
	gui.MaxDistance = if isBoss then 220 else 90
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.55, 0)
	label.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = if level then ("%s  %d ур."):format(name, level) else name
	label.Parent = gui

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromScale(0.05, 0.62)
	bar.Size = UDim2.fromScale(0.9, 0.28)
	bar.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = if isBoss then Color3.fromRGB(255, 70, 90) else Color3.fromRGB(120, 230, 110)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bar
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new(0, 0.3)
	gradient.Rotation = 90
	gradient.Parent = fill

	local function update()
		fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
	end
	humanoid.HealthChanged:Connect(update)
	update()
	gui.Parent = head
end

return NpcFactory
