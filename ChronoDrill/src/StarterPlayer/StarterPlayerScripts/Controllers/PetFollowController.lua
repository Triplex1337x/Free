-- PetFollowController: питомцы всех игроков (рендер на клиенте).
-- ТЗ 9.3: покачивание по синусоиде ±0.5 stud, крен на поворотах ±8°, AlignPosition (Responsiveness 25).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetBuilder = require(Shared:WaitForChild("PetBuilder"))
local MK = require(Shared:WaitForChild("ModelKit"))

local Pets = {}
local assets
local folder
local entries = {} -- [player] = { key = "...", pets = { {model, root, ap, ao, fly, ground, phase} } }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- tier: 0..5 (★, ★★, ★★★, Золотой, Радужный); true = старый «золотой»
local function clonePet(id, tier)
	if tier == true then
		tier = 4
	end
	tier = tonumber(tier) or 0
	local src = assets:FindFirstChild(id)
	local model
	if src then
		model = src:Clone()
	else
		model = PetBuilder.Build(id)
	end
	PetBuilder.ApplyTier(model, tier)
	return model
end

-- звёзды над питомцем в мире
local function addStars(model, tier)
	if (tier < 1 or tier > 3) and tier ~= 6 or not model.PrimaryPart then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Stars"
	bb.Size = UDim2.fromOffset(60, 22)
	bb.StudsOffsetWorldSpace = Vector3.new(0, (model:GetExtentsSize().Y / 2) + 0.9, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Parent = model.PrimaryPart
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = tier == 6 and "✦ ШАЙНИ ✦" or string.rep("★", tier)
	t.TextColor3 = tier == 6 and Color3.fromRGB(150, 240, 255) or Color3.fromRGB(255, 214, 60)
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
end

local function makePhysical(model)
	local root = model.PrimaryPart
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = p ~= root
			p.Anchored = false
			if p ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	root.Anchored = false
	local att = Instance.new("Attachment")
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.Responsiveness = 25
	ap.MaxForce = 1e6
	ap.MaxVelocity = 120
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.Responsiveness = 18
	ao.MaxTorque = 1e6
	ao.Parent = root
	return root, ap, ao
end

local function clearEntry(player)
	local e = entries[player]
	if e then
		for _, p in ipairs(e.pets) do
			p.model:Destroy()
		end
		entries[player] = nil
	end
end

local function rebuild(player)
	clearEntry(player)
	local key = player:GetAttribute("PetsEquipped") or ""
	local e = { key = key, pets = {} }
	entries[player] = e
	if key == "" then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for item in string.gmatch(key, "[^,]+") do
		local id, g = string.match(item, "([^:]+):(%d)")
		if id then
			local tier = tonumber(g) or 0
			local model = clonePet(id, tier)
			addStars(model, tier)
			local proot, ap, ao = makePhysical(model)
			local start = root and (root.CFrame * CFrame.new(0, 1, 4)) or CFrame.new(0, 50, 0)
			model:PivotTo(start)
			model.Parent = folder
			ap.Position = start.Position
			ao.CFrame = start
			table.insert(e.pets, {
				model = model,
				root = proot,
				ap = ap,
				ao = ao,
				fly = model:GetAttribute("Fly") == true,
				ground = model:GetAttribute("Scale") or 1,
				phase = math.random() * 6,
				lastPos = start.Position,
			})
		end
	end
end

local function watch(player)
	player:GetAttributeChangedSignal("PetsEquipped"):Connect(function()
		rebuild(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		rebuild(player)
	end)
	rebuild(player)
end

-- раскладка вокруг игрока: дуга позади
-- k — масштаб питомца: крупные (мифики x2, «Огромные» x3) идут дальше от игрока, чтобы не заслонять его
local function slotOffset(i, n, k)
	k = math.max(1, k or 1)
	local extra = (k - 1) * 2.2
	if n == 1 then
		return Vector3.new(2.6 + extra * 0.6, 0, 3.5 + extra)
	end
	local spread = math.rad(150)
	local a = -spread / 2 + spread * (i - 1) / (n - 1)
	local r = 4.4 + extra
	return Vector3.new(math.sin(a) * r, 0, math.cos(a) * r * 0.85 + 1)
end

local function update(dt)
	local t = os.clock()
	local localChar = Players.LocalPlayer.Character
	local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
	for player, e in pairs(entries) do
		if e.broken then
			-- модель питомца уничтожилась (упала за карту) — пересобираем
			e.broken = false
			task.defer(rebuild, player)
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local far = (not root) or (localRoot and (root.Position - localRoot.Position).Magnitude > 220)
		for i, p in ipairs(e.pets) do
			if far or not p.model.Parent then
				if p.model.Parent and far then
					p.model.Parent = nil
				end
			else
				if not p.model.Parent then
					p.model.Parent = folder
				end
				local off = slotOffset(i, #e.pets, p.ground)
				local base = root.CFrame * CFrame.new(off)
				local pos = base.Position
				local groundY
				rayParams.FilterDescendantsInstances = { folder, char }
				local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
				if hit then
					groundY = hit.Position.Y
				else
					groundY = root.Position.Y - 3
				end
				local bob = math.sin(t * 3 + p.phase) * 0.5
				local y
				if p.fly then
					y = math.max(groundY + p.ground + 2.2, root.Position.Y + 0.5) + bob
				else
					y = groundY + p.ground + math.abs(math.sin(t * 6 + p.phase)) * 0.35 * math.min(1, root.AssemblyLinearVelocity.Magnitude / 8) + bob * 0.1
				end
				local target = Vector3.new(pos.X, y, pos.Z)
				p.ap.Position = target
				-- после телепорта (ребёрс, другой остров, база) питомец не «летит» через полкарты
				-- и не теряется под островом: просто переносим его к игроку
				if not p.root.Parent or (p.root.Position - target).Magnitude > 45 or p.root.Position.Y < -400 then
					if p.root.Parent then
						p.model:PivotTo(CFrame.new(target))
						p.root.AssemblyLinearVelocity = Vector3.zero
						p.lastPos = target
					else
						e.broken = true
					end
				end
				-- поворот по направлению движения, крен ±8°
				local vel = (p.root.Position - p.lastPos) / math.max(dt, 1 / 240)
				p.lastPos = p.root.Position
				local flatVel = Vector3.new(vel.X, 0, vel.Z)
				local look
				if flatVel.Magnitude > 1.5 then
					look = flatVel.Unit
				else
					look = root.CFrame.LookVector
				end
				local right = look:Cross(Vector3.yAxis)
				local lateral = flatVel:Dot(right)
				local roll = math.clamp(-lateral * 0.02, -math.rad(8), math.rad(8))
				p.ao.CFrame = CFrame.lookAt(target, target + look) * CFrame.Angles(0, 0, roll)
			end
		end
	end
end

function Pets.Init()
	assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = workspace
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(watch, p)
	end
	Players.PlayerRemoving:Connect(clearEntry)
	RunService.Heartbeat:Connect(update)
end

-- Модель питомца для UI (ViewportFrame)
function Pets.DisplayModel(id, tier)
	local model = clonePet(id, tier)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	return model
end

return Pets
