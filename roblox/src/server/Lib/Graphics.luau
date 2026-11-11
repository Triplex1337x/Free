-- Visual quality helpers: Future lighting, terrain ground (grass with
-- decoration blades, lava, sand, snow, glacier, real water with waves and
-- reflections) and a polish pass that makes glossy materials reflective.
--
-- Note: Lighting.Technology can't be changed from a script. The generated
-- place file already has it set to Future; if you sync with Rojo into your own
-- place, set Lighting -> Technology = Future in Studio by hand.

local Lighting = game:GetService("Lighting")

local Graphics = {}

local terrain = workspace.Terrain

-- Terrain material colours are global per material, so each zone uses its
-- own material set (Grass hub, Basalt ember, Sand tidal, Snow storm, Slate void).
local MATERIAL_COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(98, 168, 74),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(120, 176, 70),
	[Enum.Material.Cobblestone] = Color3.fromRGB(150, 142, 160),
	[Enum.Material.Pavement] = Color3.fromRGB(128, 122, 138),
	[Enum.Material.Rock] = Color3.fromRGB(104, 98, 116),
	[Enum.Material.Sand] = Color3.fromRGB(230, 212, 168),
	[Enum.Material.Basalt] = Color3.fromRGB(52, 40, 40),
	[Enum.Material.CrackedLava] = Color3.fromRGB(240, 96, 32),
	[Enum.Material.Snow] = Color3.fromRGB(238, 244, 255),
	[Enum.Material.Glacier] = Color3.fromRGB(150, 210, 255),
	[Enum.Material.Slate] = Color3.fromRGB(38, 28, 54),
	[Enum.Material.Mud] = Color3.fromRGB(80, 66, 56),
}

function Graphics.SetupLighting()
	-- Not scriptable in live games; harmless if it errors.
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.15
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	pcall(function()
		Lighting.ShadowSoftness = 0.25
	end)
	Lighting.Ambient = Color3.fromRGB(40, 36, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 118, 150)

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.Name = "RiftSky"
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 4000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	terrain.WaterColor = Color3.fromRGB(40, 150, 200)
	terrain.WaterReflectance = 1
	terrain.WaterTransparency = 0.55
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 12
	pcall(function()
		(terrain :: any).Decoration = true -- animated grass blades
	end)
	for material, color in MATERIAL_COLORS do
		pcall(terrain.SetMaterialColor, terrain, material, color)
	end
end

-- A flat terrain disc whose top surface sits at `top.Y`.
function Graphics.Disc(top: Vector3, radius: number, depth: number, material: Enum.Material)
	terrain:FillCylinder(CFrame.new(top - Vector3.new(0, depth / 2, 0)), depth, radius, material)
end

function Graphics.Ball(center: Vector3, radius: number, material: Enum.Material)
	terrain:FillBall(center, radius, material)
end

function Graphics.Block(cf: CFrame, size: Vector3, material: Enum.Material)
	terrain:FillBlock(cf, size, material)
end

-- Glossy materials get real sky/environment reflections under Future lighting.
local REFLECT = {
	[Enum.Material.Marble] = 0.12,
	[Enum.Material.Glass] = 0.3,
	[Enum.Material.Ice] = 0.3,
	[Enum.Material.Foil] = 0.35,
	[Enum.Material.Metal] = 0.2,
	[Enum.Material.DiamondPlate] = 0.15,
	[Enum.Material.SmoothPlastic] = 0.06,
	[Enum.Material.Granite] = 0.05,
}

function Graphics.Polish(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Reflectance == 0 and d.Transparency < 1 then
			local r = REFLECT[d.Material]
			if r then
				d.Reflectance = r
			end
		end
	end
end

return Graphics
