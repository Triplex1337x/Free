-- Makes locations worth exploring: themed trees and ruins, treasure chests,
-- hidden Rift Crystals (collectibles), jump pads up to the sky isles,
-- friendly NPCs (sensei, potion merchant, portal keeper) and world events
-- (Golden Mob, Rift Chest).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Potions = require(Shared.Config.Potions)
local Remotes = require(Shared.Remotes)
local NpcFactory = require(script.Parent.Parent.Lib.NpcFactory)

local WorldService = {}

local ISLAND_RADIUS = 380
local CHEST_RESPAWN_MIN = 45 -- seconds until an opened ground chest reappears elsewhere
local CHEST_RESPAWN_MAX = 90
local CHEST_RESPAWN_SKY = 180
local CRYSTALS_PER_ZONE = 8
local SIGN_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

local rng = Random.new(4242)
local world: Folder
local crystalsByZone = {} :: { [string]: { string } }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

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

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

local function zoneLevel(zoneId: string): number
	local zone = Zones.Get(zoneId)
	return if zone.Mobs and zone.Mobs[1] then zone.Mobs[1].Level else 3
end

-- Free spot on an island / the hub, away from plazas, arenas and sky isles.
local function spot(zoneId: string, minR: number, maxR: number): Vector3
	local zone = Zones.Get(zoneId)
	local origin = zone.Origin or Vector3.zero
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minR, maxR)
		local rel = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = true
		if zone.Origin then
			ok = rel.Z < 290 and not (rel.Z < -225 and math.abs(rel.X) < 80)
			for _, offset in Zones.Sky.IslandOffsets do
				ok = ok and (rel - offset).Magnitude > 62
			end
		else
			ok = not Zones.IsHubSafe(rel) and rel.Magnitude > 75
			for _, center in zone.SkyCenters or {} do
				ok = ok and (rel - center).Magnitude > 62
			end
		end
		if ok then
			return origin + rel
		end
	end
	return origin + Vector3.new(0, 0, 100)
end

local function bubble(parent: BasePart, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = frame
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -16, 1, -8)
	text.Position = UDim2.fromOffset(8, 4)
	text.FontFace = SIGN_FONT
	text.TextScaled = true
	text.TextWrapped = true
	text.TextColor3 = Color3.fromRGB(20, 15, 30)
	text.Parent = frame
	gui.Parent = parent
	return text
end

---------------------------------------------------------------------------
-- Decor: trees and ruins
---------------------------------------------------------------------------

local TREE_STYLE = {
	Hub = { Trunk = Color3.fromRGB(90, 60, 50), Leaves = { Color3.fromRGB(255, 170, 205), Color3.fromRGB(255, 200, 225) }, Material = Enum.Material.Grass },
	Ember = { Trunk = Color3.fromRGB(35, 25, 25), Leaves = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 70, 30) }, Material = Enum.Material.Neon, Sparse = true },
	Tidal = { Trunk = Color3.fromRGB(140, 110, 80), Leaves = { Color3.fromRGB(60, 200, 170), Color3.fromRGB(90, 230, 190) }, Material = Enum.Material.Grass },
	Storm = { Trunk = Color3.fromRGB(70, 60, 55), Leaves = { Color3.fromRGB(230, 240, 255), Color3.fromRGB(150, 190, 170) }, Material = Enum.Material.Snow, Pine = true },
	Void = { Trunk = Color3.fromRGB(30, 20, 45), Leaves = { Color3.fromRGB(170, 80, 255), Color3.fromRGB(110, 60, 220) }, Material = Enum.Material.Neon, Crystal = true },
}

local function tree(parent: Instance, pos: Vector3, style)
	local h = rng:NextNumber(14, 24)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, 0), Material = Enum.Material.Wood, Color = style.Trunk, Parent = parent })
	if style.Pine then
		for i = 0, 2 do
			part({ Name = "Leaves", ClassName = "WedgePart", Size = Vector3.new(14 - i * 3.5, 6, 14 - i * 3.5), CFrame = CFrame.new(pos + Vector3.new(0, h * 0.5 + i * 4.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Material = style.Material, Color = style.Leaves[1 + i % 2], CanCollide = false, Parent = parent })
		end
		return
	end
	if style.Crystal then
		for i = 1, 4 do
			local c = part({ Name = "Leaves", Size = Vector3.new(2.5, rng:NextNumber(6, 11), 2.5), CFrame = CFrame.new(pos + Vector3.new(0, h, 0)) * CFrame.Angles(rng:NextNumber(-0.7, 0.7), i * 1.6, rng:NextNumber(-0.7, 0.7)), Material = Enum.Material.Neon, Color = style.Leaves[1 + i % 2], CanCollide = false, Parent = parent })
			if i == 1 then
				light(c, style.Leaves[1], 18, 1.5)
			end
		end
		return
	end
	local blobs = if style.Sparse then 3 else 5
	local lastBlob = nil
	for i = 1, blobs do
		local size = rng:NextNumber(7, 11)
		local blob = part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = pos + Vector3.new(rng:NextNumber(-4, 4), h + rng:NextNumber(-1, 3), rng:NextNumber(-4, 4)),
			Material = style.Material,
			Color = style.Leaves[1 + i % 2],
			CanCollide = false,
			Parent = parent,
		})
		if style.Material == Enum.Material.Neon and i == 1 then
			light(blob, style.Leaves[1], 16, 1)
		end
		lastBlob = blob
	end
	if style == TREE_STYLE.Hub then
		local petals = Instance.new("ParticleEmitter")
		petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		petals.Color = ColorSequence.new(style.Leaves[1])
		petals.Size = NumberSequence.new(0.35)
		petals.Rate = 3
		petals.Lifetime = NumberRange.new(4, 6)
		petals.Speed = NumberRange.new(1, 2)
		petals.Acceleration = Vector3.new(0.5, -2, 0.3)
		petals.Parent = lastBlob
	end
end

local function ruin(parent: Instance, pos: Vector3, color: Color3, material: Enum.Material)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	-- Steps
	for i = 0, 2 do
		part({ Name = "RuinStep", Size = Vector3.new(22 - i * 4, 1.2, 16 - i * 3), CFrame = base * CFrame.new(0, 0.6 + i * 1.2, 0), Material = material, Color = color, Parent = parent })
	end
	-- Broken columns + an arch
	for _, x in { -8, 8 } do
		local h = rng:NextNumber(8, 16)
		part({ Name = "RuinColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.6, 2.6), CFrame = base * CFrame.new(x, 3.6 + h / 2, -4) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Parent = parent })
	end
	part({ Name = "RuinArch", Size = Vector3.new(20, 2, 3), CFrame = base * CFrame.new(0, 19, 4) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), Material = Enum.Material.Marble, Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Parent = parent })
	for _, x in { -8, 8 } do
		part({ Name = "RuinPillar", Size = Vector3.new(3, 15, 3), CFrame = base * CFrame.new(x, 3.6 + 7.5, 4), Material = Enum.Material.Marble, Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Parent = parent })
	end
end

---------------------------------------------------------------------------
-- Chests and crystals
---------------------------------------------------------------------------

function WorldService:Reward(player: Player, shards: number, spins: number?, potionChance: number?)
	local Progression = self.Services.ProgressionService
	Progression:Grant(player, { Shards = shards, Spins = spins })
	if potionChance and rng:NextNumber() < potionChance then
		self.Services.InventoryService:AddPotion(player, Potions.Order[rng:NextInteger(1, #Potions.Order)], 1)
	end
end

-- Chests are shared world loot: whoever opens one gets the reward, the chest
-- vanishes for everyone and a new one appears somewhere random a bit later.
-- They have no collision so they never get in the way of a fight.
function WorldService:MakeChest(parent: Instance, cf: CFrame, zoneId: string, rich: boolean, nextSpot: () -> CFrame)
	local gold = Color3.fromRGB(255, 205, 70)
	local model = Instance.new("Model")
	model.Name = if rich then "SkyChest" else "Chest"
	local base = part({ Name = "Chest", Size = Vector3.new(5, 3, 3.4), CFrame = cf * CFrame.new(0, 1.5, 0), Material = Enum.Material.WoodPlanks, Color = if rich then Color3.fromRGB(150, 60, 200) else Color3.fromRGB(150, 95, 50), CanCollide = false, Parent = model })
	part({ Name = "ChestLid", Size = Vector3.new(5.2, 1.2, 3.6), CFrame = cf * CFrame.new(0, 3.6, 0), Material = Enum.Material.WoodPlanks, Color = base.Color:Lerp(Color3.new(0, 0, 0), 0.15), CanCollide = false, Parent = model })
	for _, x in { -2.2, 0, 2.2 } do
		part({ Name = "ChestTrim", Size = Vector3.new(0.4, 4.4, 3.8), CFrame = cf * CFrame.new(x, 2.2, 0), Material = Enum.Material.Neon, Color = gold, CanCollide = false, CanQuery = false, Parent = model })
	end
	light(base, gold, 14, 1.5)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(gold)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Rate = 6
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.Lifetime = NumberRange.new(1, 1.5)
	sparkle.Parent = base
	model.PrimaryPart = base
	model.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Открыть"
	prompt.ObjectText = if rich then "Небесный сундук" else "Сундук"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	local opened = false
	prompt.Triggered:Connect(function(player)
		if opened or not self.Services.DataService:Get(player) then
			return
		end
		opened = true
		prompt.Enabled = false
		local level = zoneLevel(zoneId)
		local shards = math.floor((60 + level * 10) * (if rich then 3 else 1))
		self:Reward(player, shards, if rich then 1 else nil, if rich then 0.6 else 0.2)
		Remotes.Notify:FireClient(player, ("%s: +%d ◆%s"):format(prompt.ObjectText, shards, if rich then " +1 ✦" else ""), "success")
		Remotes.Fx:FireAllClients("Potion", { Character = player.Character, Color = gold })
		model:Destroy()
		task.delay(if rich then CHEST_RESPAWN_SKY else rng:NextNumber(CHEST_RESPAWN_MIN, CHEST_RESPAWN_MAX), function()
			if parent.Parent then
				self:MakeChest(parent, nextSpot(), zoneId, rich, nextSpot)
			end
		end)
	end)
end

function WorldService:MakeCrystal(parent: Instance, pos: Vector3, id: string, zoneId: string)
	local color = Zones.Get(zoneId).Color
	local crystal = part({ Name = "RiftCrystal", Size = Vector3.new(2, 4, 2), CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0.6, 0.6, 0.4), Material = Enum.Material.Neon, Color = color, CanCollide = false, Parent = parent })
	crystal:SetAttribute("CrystalId", id)
	light(crystal, color, 16, 2)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Собрать"
	prompt.ObjectText = "Кристалл Разлома"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = crystal
	prompt.Triggered:Connect(function(player)
		local profile = self.Services.DataService:Get(player)
		if not profile or profile.Data.Collected[id] then
			return
		end
		local d = profile.Data
		d.Collected[id] = true
		self:Reward(player, 200 + zoneLevel(zoneId) * 5, 1, nil)
		local found = 0
		for _, cid in crystalsByZone[zoneId] do
			if d.Collected[cid] then
				found += 1
			end
		end
		local zone = Zones.Get(zoneId)
		if found >= #crystalsByZone[zoneId] then
			self:Reward(player, 2000, 5, nil)
			self.Services.InventoryService:AddPotion(player, "LuckPotion", 2, true)
			Remotes.Notify:FireClient(player, ("ВСЕ КРИСТАЛЛЫ (%s) СОБРАНЫ! +2000 ◆ +5 ✦ +2 зелья удачи"):format(zone.Name), "level")
		else
			Remotes.Notify:FireClient(player, ("Кристалл Разлома %d/%d (%s): +1 ✦"):format(found, #crystalsByZone[zoneId], zone.Name), "success")
		end
		Remotes.Fx:FireAllClients("Potion", { Character = player.Character, Color = color })
		self.Services.DataService:Sync(player)
	end)
end

---------------------------------------------------------------------------
-- Friendly NPCs
---------------------------------------------------------------------------

local TIPS = {
	"Сначала потренируйся на манекенах!",
	"Нажми F прямо перед ударом врага — это парирование.",
	"ПКМ + ЛКМ или C — контратака: исчезни и ударь в спину!",
	"Качай стиль, чтобы открыть E, R и ульту G.",
	"С 10 уровня — двойной прыжок, с 15 — тройной.",
	"На вершинах небесных островов — элитки и богатые сундуки.",
	"Ищи скрытые Кристаллы Разлома — за все дадут приз!",
	"Зелья усиливают тебя на 10–15 минут. Загляни к торговцу.",
}

function WorldService:MakeNpc(parent: Instance, name: string, outfit: string, cf: CFrame, lines: { string }, action: string?, actionText: string?)
	local model = NpcFactory.Rig(name, 1, outfit)
	model:PivotTo(cf + Vector3.new(0, 3, 0))
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = 1e6 -- not math.huge: inf/inf would break the HP bar
	humanoid.Health = 1e6
	model.Parent = parent
	NpcFactory.Overhead(model, name, nil, Color3.fromRGB(120, 255, 170), false)
	local head = model:FindFirstChild("Head") :: BasePart
	local text = bubble(head, head.Size.Y * 1.6 + 3.6)
	task.spawn(function()
		local i = rng:NextInteger(1, #lines)
		while model.Parent do
			text.Text = lines[i]
			i = i % #lines + 1
			task.wait(7)
		end
	end)
	if action then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText or "Говорить"
		prompt.ObjectText = name
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(player)
			if action == "Tip" then
				Remotes.Notify:FireClient(player, "Сэнсэй: " .. TIPS[rng:NextInteger(1, #TIPS)], "info")
			else
				Remotes.OpenUI:FireClient(player, action)
			end
		end)
	end
	return model
end

---------------------------------------------------------------------------
-- World events
---------------------------------------------------------------------------

function WorldService:RiftChestEvent(zoneId: string)
	local zone = Zones.Get(zoneId)
	local origin = zone.Origin or Vector3.zero
	local pos = if zone.Origin then origin + Vector3.new(0, 0, 60) else Vector3.new(0, 0, -20)
	local folder = Instance.new("Folder")
	folder.Name = "RiftChestEvent"
	folder.Parent = world
	local opened = {}
	local gold = Color3.fromRGB(255, 205, 70)
	local chest = part({ Name = "RiftChest", Size = Vector3.new(9, 6, 6), CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)), Material = Enum.Material.Neon, Color = gold, Parent = folder })
	light(chest, gold, 40, 3)
	local beam = part({ Name = "RiftChestBeam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(200, 4, 4), CFrame = CFrame.new(pos + Vector3.new(0, 100, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = gold, Transparency = 0.4, CanCollide = false, Parent = folder })
	beam.CanQuery = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Открыть"
	prompt.ObjectText = "Сундук Разлома"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest
	prompt.Triggered:Connect(function(player)
		if opened[player] then
			return
		end
		opened[player] = true
		local level = zoneLevel(zoneId)
		self:Reward(player, 400 + level * 20, 3, 1)
		Remotes.Notify:FireClient(player, ("СУНДУК РАЗЛОМА: +%d ◆ +3 ✦ + зелье"):format(400 + level * 20), "level")
	end)
	Remotes.Announce:FireAllClients(("СОБЫТИЕ: Сундук Разлома появился в локации «%s» на 2 минуты! Ищи золотой луч."):format(zone.Name))
	task.delay(120, function()
		folder:Destroy()
	end)
end

function WorldService:GoldenMobEvent(zoneId: string)
	local zone = Zones.Get(zoneId)
	local base = (zone.Mobs and zone.Mobs[#zone.Mobs]) or (zone.SkyMobs and zone.SkyMobs[1])
	local spawns = self.Services.ZoneService:GetMobSpawns(zoneId)
	if not base or #spawns == 0 then
		return false
	end
	local def = table.clone(base)
	def.Id = "Golden_" .. base.Id
	def.Name = "Золотой " .. base.Name
	def.Level = base.Level + 3
	def.Elite = true
	def.Golden = true
	def.Special = true
	def.RewardMult = 8
	self.Services.MobService:Spawn(zoneId, def, spawns[rng:NextInteger(1, #spawns)], false)
	Remotes.Announce:FireAllClients(("СОБЫТИЕ: %s появился в локации «%s»! Награда ×8."):format(def.Name, zone.Name))
	return true
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

function WorldService:BuildZone(zoneId: string)
	local zone = Zones.Get(zoneId)
	local folder = Instance.new("Folder")
	folder.Name = zoneId
	folder.Parent = world
	local origin = zone.Origin or Vector3.zero
	local isHub = zone.Origin == nil
	local style = TREE_STYLE[if isHub then "Hub" else zone.Theme]
	local maxR = if isHub then 175 else ISLAND_RADIUS - 25

	for _ = 1, if isHub then 14 else 26 do
		tree(folder, spot(zoneId, if isHub then 80 else 40, maxR), style)
	end
	if not isHub then
		local ruinColor = ({ Ember = Color3.fromRGB(90, 70, 65), Tidal = Color3.fromRGB(200, 205, 210), Storm = Color3.fromRGB(150, 155, 170), Void = Color3.fromRGB(60, 45, 80) })[zone.Theme]
		for _ = 1, 5 do
			ruin(folder, spot(zoneId, 60, maxR - 20), ruinColor, Enum.Material.Cobblestone)
		end
	end

	-- Chests on the ground + a rich one on top of every sky isle.
	local function groundSpot(): CFrame
		return CFrame.new(spot(zoneId, 50, maxR)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	end
	for _ = 1, if isHub then 4 else 8 do
		self:MakeChest(folder, groundSpot(), zoneId, false, groundSpot)
	end
	local skyCenters = {}
	if isHub then
		for _, c in zone.SkyCenters or {} do
			table.insert(skyCenters, c)
		end
	else
		for _, o in Zones.Sky.IslandOffsets do
			table.insert(skyCenters, origin + o)
		end
	end
	-- Sky chests reappear on a random sky isle top.
	local function skySpot(): CFrame
		local c = skyCenters[rng:NextInteger(1, #skyCenters)]
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(4, Zones.Sky.TopRadius - 8)
		return CFrame.new(c + Vector3.new(math.cos(a) * r, Zones.Sky.TopHeight, math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	end
	for _, center in skyCenters do
		local top = center + Vector3.new(6, Zones.Sky.TopHeight, 6)
		self:MakeChest(folder, CFrame.new(top), zoneId, true, skySpot)
		-- Jump pad at the foot of each sky area (launches to tier 2).
		local padPos = center + Vector3.new(-40, 0.2, 22)
		local pad = part({ Name = "JumpPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 8, 8), CFrame = CFrame.new(padPos) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 255, 200), CanCollide = false, Parent = folder })
		pad:SetAttribute("JumpPad", Zones.Sky.Tier2Height + 6)
		light(pad, pad.Color, 14, 2)
		local arrow = part({ Name = "JumpPadArrow", ClassName = "WedgePart", Size = Vector3.new(0.2, 2.5, 3), CFrame = CFrame.new(padPos + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(-90), 0, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 255, 200), CanCollide = false, Parent = folder })
		arrow.CanQuery = false
	end

	-- Hidden Rift Crystals: some on the ground, some on the sky isles.
	crystalsByZone[zoneId] = {}
	for i = 1, CRYSTALS_PER_ZONE do
		local pos
		if i <= #skyCenters then
			local c = skyCenters[i]
			pos = c + Vector3.new(-14, Zones.Sky.TopHeight, -10)
		else
			pos = spot(zoneId, 60, maxR)
		end
		local id = zoneId .. "_K" .. i
		table.insert(crystalsByZone[zoneId], id)
		self:MakeCrystal(folder, pos, id, zoneId)
	end

	-- Friendly NPCs at the spawn plaza.
	local plaza = if isHub then CFrame.lookAt(Vector3.new(0, 0, 150), Vector3.zero) else CFrame.lookAt(origin + Vector3.new(0, 0, 316), origin)
	local npcs = Instance.new("Folder")
	npcs.Name = "Friendlies"
	npcs.Parent = folder
	self:MakeNpc(npcs, "Сэнсэй", "Trainee4", plaza * CFrame.new(-14, 0, 0), TIPS, "Tip", "Совет")
	self:MakeNpc(npcs, "Торговец зельями", "Trainee2", plaza * CFrame.new(14, 0, 0), {
		"Свежие зелья! Опыт, удача, ярость!",
		"Заходи, путник, у меня лучшие настойки!",
		"Зелье удачи — перед роллом самое то.",
	}, "PotionShop", "Магазин зелий")
	if isHub then
		self:MakeNpc(npcs, "Хранитель порталов", "Trainee3", CFrame.lookAt(Vector3.new(110, 0, 110), Vector3.zero), {
			"Порталы ведут в другие миры. Подойди и нажми T.",
			"Пепельные Пустоши — для новичков. Дальше — только сильнейшим.",
			"Храм Прилива открывается с 15 уровня.",
		})
	end
end

function WorldService:Init(services)
	self.Services = services
	world = Instance.new("Folder")
	world.Name = "World"
	for _, id in Zones.Order do
		if id ~= "Hub" or services.MapService:GetFolder():GetAttribute("Generated") then
			self:BuildZone(id)
		end
	end
	world.Parent = workspace
	services.CombatService.ExtraExclusions = services.CombatService.ExtraExclusions or {}
	table.insert(services.CombatService.ExtraExclusions, world)
end

function WorldService:Start()
	-- Tutorial reward (once per account).
	Remotes.TutorialDone.OnServerInvoke = function(player)
		local profile = self.Services.DataService:Get(player)
		if not profile or profile.Data.TutorialDone then
			return false
		end
		profile.Data.TutorialDone = true
		self.Services.ProgressionService:Grant(player, { Shards = 300, Spins = 3 })
		self.Services.InventoryService:AddPotion(player, "XpPotion", 1, true)
		Remotes.Notify:FireClient(player, "ОБУЧЕНИЕ ПРОЙДЕНО! +300 ◆ +3 ✦ + Настой мудреца", "level")
		return true
	end

	-- World events every 4-6 minutes in a zone that has players.
	while true do
		task.wait(rng:NextNumber(240, 360))
		local candidates = {}
		local counts = {}
		for _, p in Players:GetPlayers() do
			local z = p:GetAttribute("Zone") or "Hub"
			counts[z] = (counts[z] or 0) + 1
		end
		for z in counts do
			table.insert(candidates, z)
		end
		if #candidates > 0 then
			local zoneId = candidates[rng:NextInteger(1, #candidates)]
			if zoneId == "Hub" or rng:NextNumber() < 0.5 then
				self:RiftChestEvent(zoneId)
			elseif not self:GoldenMobEvent(zoneId) then
				self:RiftChestEvent(zoneId)
			end
		end
	end
end

return WorldService
