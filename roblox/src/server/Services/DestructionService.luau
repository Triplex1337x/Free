-- Destructible props (crates, barrels, rock piles, stone columns). Abilities,
-- explosions and M1 finishers damage them; when broken they shatter into
-- physics fragments everyone sees, then respawn after a while.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Remotes = require(Shared.Remotes)

local DestructionService = {}

local RESPAWN = 30
local FRAGMENT_LIFETIME = 6
local rng = Random.new(77)

local folder = Instance.new("Folder")
folder.Name = "Destructibles"

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { folder }

local KINDS = {
	Crate = { Size = Vector3.new(4, 4, 4), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(160, 110, 60), Health = 25, Pieces = 9 },
	Barrel = { Size = Vector3.new(4, 3.4, 3.4), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 70, 40), Health = 20, Pieces = 7, Cylinder = true, Upright = true },
	Rocks = { Size = Vector3.new(7, 4, 6), Material = Enum.Material.Rock, Color = Color3.fromRGB(110, 100, 110), Health = 60, Pieces = 12 },
	Column = { Size = Vector3.new(14, 3.2, 3.2), Material = Enum.Material.Marble, Color = Color3.fromRGB(225, 220, 230), Health = 80, Pieces = 12, Cylinder = true, Upright = true },
}

local function makeProp(kind: string, cf: CFrame)
	local cfg = KINDS[kind]
	local p = Instance.new("Part")
	p.Name = kind
	p.Anchored = true
	p.Size = cfg.Size
	p.Material = cfg.Material
	p.Color = cfg.Color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if cfg.Cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	local height = if cfg.Upright then cfg.Size.X else cfg.Size.Y
	p.CFrame = cf * CFrame.new(0, height / 2, 0) * (if cfg.Upright or cfg.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
	p:SetAttribute("Kind", kind)
	p:SetAttribute("Health", cfg.Health)
	p:SetAttribute("Home", p.CFrame)
	p.Parent = folder
	return p
end

function DestructionService:Shatter(prop: BasePart, from: Vector3, power: number)
	local cfg = KINDS[prop:GetAttribute("Kind")]
	if not cfg or prop:GetAttribute("Broken") then
		return
	end
	prop:SetAttribute("Broken", true)
	local center = prop.Position
	for _ = 1, cfg.Pieces do
		local s = prop.Size.Magnitude / 6
		local piece = Instance.new("Part")
		piece.Name = "Fragment"
		piece.Size = Vector3.new(rng:NextNumber(0.4, 1) * s, rng:NextNumber(0.3, 0.8) * s, rng:NextNumber(0.4, 1) * s)
		piece.CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 1), rng:NextNumber(-1, 1)) * s)
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		piece.Material = cfg.Material
		piece.Color = cfg.Color
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = false
		piece.Parent = workspace
		local away = (piece.Position - from)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis
		piece.AssemblyLinearVelocity = away * math.clamp(power * 0.4, 8, 24) + Vector3.new(0, rng:NextNumber(8, 18), 0)
		piece.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4))
		piece.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.1) -- heavy, grippy, little bounce
		Debris:AddItem(piece, FRAGMENT_LIFETIME)
	end
	Remotes.Fx:FireAllClients("Shatter", { Pos = center, Color = cfg.Color })
	prop.Transparency = 1
	prop.CanCollide = false
	prop.CanQuery = false
	task.delay(RESPAWN, function()
		if prop.Parent then
			prop.CFrame = prop:GetAttribute("Home")
			prop.Transparency = 0
			prop.CanCollide = true
			prop.CanQuery = true
			prop:SetAttribute("Health", cfg.Health)
			prop:SetAttribute("Broken", nil)
		end
	end)
end

-- Damages every prop within radius of pos.
function DestructionService:Hit(pos: Vector3, radius: number, damage: number)
	for _, prop in workspace:GetPartBoundsInRadius(pos, radius, overlap) do
		if not prop:GetAttribute("Broken") then
			local hp = (prop:GetAttribute("Health") or 0) - damage
			prop:SetAttribute("Health", hp)
			if hp <= 0 then
				self:Shatter(prop, pos, damage * 2)
			end
		end
	end
end

local function scatter(center: Vector3, count: number, minR: number, maxR: number, avoid: (Vector3) -> boolean)
	local kinds = { "Crate", "Crate", "Barrel", "Rocks", "Column" }
	local placed = 0
	for _ = 1, count * 4 do
		if placed >= count then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minR, maxR)
		local pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not avoid(pos - center) then
			local kind = kinds[rng:NextInteger(1, #kinds)]
			-- Crates come in little stacks.
			makeProp(kind, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
			if kind == "Crate" and rng:NextNumber() < 0.5 then
				makeProp("Crate", CFrame.new(pos + Vector3.new(4.2, 0, 0)))
				makeProp("Crate", CFrame.new(pos + Vector3.new(2, 4, 0)) * CFrame.Angles(0, 0.4, 0))
			end
			placed += 1
		end
	end
end

function DestructionService:Init(services)
	self.Services = services
	-- Hub: around the arena, away from spawns / dummies / centre ring.
	if services.MapService:GetFolder():GetAttribute("Generated") then
		scatter(Vector3.zero, 18, 45, 150, function(rel)
			return Zones.IsHubSafe(rel) or rel.Magnitude < 40
		end)
	end
	-- Islands.
	for _, id in Zones.Order do
		local zone = Zones.Get(id)
		if zone.Origin then
			scatter(zone.Origin, 30, 40, 340, function(rel)
				if rel.Z > 290 or (rel.Z < -225 and math.abs(rel.X) < 80) then
					return true
				end
				for _, offset in Zones.Sky.IslandOffsets do
					if (rel - offset).Magnitude < 60 then
						return true
					end
				end
				return false
			end)
		end
	end
	folder.Parent = workspace
end

return DestructionService
