-- MiningManager: шахты всех биомов, удары, руда, семена, самородки, глубина и шлюзы.
--
-- Оптимизация (отличие от ТЗ 1.1): вместо 40 000 якорных деталей на биом мы держим
-- в мире только "открытые" блоки — верхний слой и стенки уже вырытых ям. Скрытые блоки
-- создаются в момент, когда рядом сломали соседний. Для игрока шахта выглядит сплошной
-- 40x40x25, а деталей в мире в 10-20 раз меньше — это и даёт 60 FPS на телефонах.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local BiomesData = require(Configs.BiomesData)
local SeedsData = require(Configs.SeedsData)
local PetsData = require(Configs.PetsData)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local MK = require(ReplicatedStorage.Shared.ModelKit)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local WorldBuilder = require(script.Parent.WorldBuilder)
local QuestService = require(script.Parent.QuestService)

local V3 = Vector3.new
local CF = CFrame.new

local GRID = Balance.GridSize
local LAYERS = Balance.Layers
local BS = Balance.BlockSize
local HALF = GRID * BS / 2
local DEPTH = LAYERS * BS

local Mining = {}
local state = {}   -- [biome] = { [cellIndex] = part | false }
local info = {}    -- [part] = данные блока
local pool = {}
local lastHit = {}
local fullWarn = {}
local nuggets = {}
local rng = Random.new()
local nuggetFolder

local function idx(x, y, z)
	return x + (z - 1) * GRID + (y - 1) * GRID * GRID
end

local function cellPos(b, x, y, z)
	local O = WorldBuilder.Origin(b)
	return O + V3(-HALF + (x - 0.5) * BS, -BS / 2 - (y - 1) * BS, -HALF + (z - 0.5) * BS)
end

local function goldRush()
	return os.time() < (workspace:GetAttribute("GoldRushUntil") or 0)
end

local kindCache = {}
local function kindsFor(biome, y)
	local key = biome.Id * 100 + y
	local list = kindCache[key]
	if not list then
		list = {}
		for _, k in ipairs(biome.Kinds) do
			if y >= k.Layers[1] and y <= k.Layers[2] then
				table.insert(list, k)
			end
		end
		if #list == 0 then
			list = biome.Kinds
		end
		kindCache[key] = list
	end
	return list
end

local function getPart()
	local p = table.remove(pool)
	if p then
		return p
	end
	p = Instance.new("Part")
	p.Anchored = true
	p.Size = V3(BS, BS, BS)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = "Block"
	CollectionService:AddTag(p, "MineBlock")
	return p
end

local function addVeinCrystals(part, color)
	local c = MK.C(color)
	-- кристаллы торчат из граней блока: {точка на грани, нормаль грани}
	local spots = {
		{ V3(0.9, 2, -0.7), V3(0.25, 1, -0.2) },
		{ V3(-1.0, 2, 0.8), V3(-0.3, 1, 0.25) },
		{ V3(2, 0.4, 0.6), V3(1, 0.3, 0.1) },
		{ V3(-2, -0.5, -0.4), V3(-1, 0.2, -0.2) },
		{ V3(0.3, 0.8, 2), V3(0.1, 0.3, 1) },
		{ V3(-0.5, -0.2, -2), V3(-0.2, 0.25, -1) },
	}
	for i, s in ipairs(spots) do
		local cr = Instance.new("Part")
		cr.Name = "Vein"
		cr.Anchored = true
		cr.CanCollide = false
		cr.CanQuery = false
		cr.CanTouch = false
		cr.CastShadow = false
		cr.Material = Enum.Material.Neon
		cr.Transparency = 0.12
		cr.Color = c
		local h = (i % 2 == 0) and 1.5 or 1.05
		cr.Size = V3(0.55, h, 0.55)
		local pos = part.Position + s[1]
		local dir = s[2].Unit
		cr.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0) * CF(0, h * 0.25, 0) * CFrame.Angles(0, math.rad(45), 0)
		cr.Parent = part
	end
end

local function spawnCell(b, x, y, z)
	if x < 1 or x > GRID or z < 1 or z > GRID or y < 1 or y > LAYERS then
		return
	end
	local st = state[b]
	local i = idx(x, y, z)
	if st[i] ~= nil then
		return
	end
	local biome = BiomesData[b]
	local kind = Util.WeightedPick(kindsFor(biome, y), function(k)
		return k.W
	end, rng)
	local t = (y - 1) / (LAYERS - 1)
	-- прочность растёт экспоненциально с глубиной, цена единицы руды — линейно
	local hp = biome.HP[1] * math.pow(biome.HP[2] / biome.HP[1], t) * (kind.Hp or 1) * (0.9 + rng:NextNumber() * 0.2)
	local price = Util.Lerp(biome.Ore[1], biome.Ore[2], t) * (kind.Val or 1)
	hp = math.max(1, math.floor(hp))
	local veinChance = Balance.VeinChance * (goldRush() and Balance.GoldRushMult or 1)
	local vein = rng:NextNumber() < veinChance
	if vein then
		hp = hp * Balance.VeinHpMult
		price = price * Balance.VeinCoinMult
	end

	local part = getPart()
	part.CFrame = CF(cellPos(b, x, y, z))
	part.Size = V3(BS, BS, BS)
	local base = MK.C(kind.Color)
	local j = (rng:NextNumber() - 0.5) * 0.09
	if j > 0 then
		base = base:Lerp(Color3.new(1, 1, 1), j)
	else
		base = base:Lerp(Color3.new(0, 0, 0), -j)
	end
	-- шахматная сетка: соседние блоки чуть отличаются по тону, шахту легко "читать"
	if (x + z + y) % 2 == 0 then
		base = base:Lerp(Color3.new(0, 0, 0), 0.07)
	else
		base = base:Lerp(Color3.new(1, 1, 1), 0.03)
	end
	if vein then
		base = base:Lerp(Color3.new(0, 0, 0), 0.25)
	end
	part.Color = base
	-- блоки шахты — с родными текстурами (земля, камень, руда): так копать приятнее
	part.Material = MK.MatRaw(kind.Material or "SmoothPlastic")
	part.Transparency = kind.Transparency or 0
	part.Reflectance = 0
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
	part.CastShadow = true
	part:SetAttribute("Home", part.Position)
	part:SetAttribute("MaxHealth", hp)
	part:SetAttribute("CurrentHealth", hp)
	part:SetAttribute("Biome", b)
	part:SetAttribute("Kind", kind.Name)
	part:SetAttribute("Vein", vein)
	if vein then
		addVeinCrystals(part, biome.VeinColor)
	end
	part.Parent = WorldBuilder.MinesFolder(b)
	st[i] = part
	info[part] = { b = b, x = x, y = y, z = z, i = i, hp = hp, max = hp, price = price, vein = vein, kind = kind }
end

local function releasePart(part)
	for _, c in ipairs(part:GetChildren()) do
		if c:IsA("BasePart") then
			c:Destroy()
		end
	end
	part.Parent = nil
	table.insert(pool, part)
end

local function breakBlock(part, inf, player)
	local b = inf.b
	state[b][inf.i] = false
	info[part] = nil
	local pos = part.Position
	local color = part.Color
	releasePart(part)
	spawnCell(b, inf.x + 1, inf.y, inf.z)
	spawnCell(b, inf.x - 1, inf.y, inf.z)
	spawnCell(b, inf.x, inf.y, inf.z + 1)
	spawnCell(b, inf.x, inf.y, inf.z - 1)
	spawnCell(b, inf.x, inf.y + 1, inf.z)
	-- запас на слой ниже: когда бур проходит блок под ногами, следующий уже есть у клиента
	-- (раньше при быстром бурении новый блок не успевал прийти и игрок проваливался)
	spawnCell(b, inf.x, inf.y + 2, inf.z)
	spawnCell(b, inf.x, inf.y - 1, inf.z)
	Net.Get("BlockBroken"):FireAllClients(b, pos, color, inf.vein, player and player.UserId or 0, inf.kind.Material == "Glass")
end

---------------------------------------------------------------------------------------------
-- Самородки (бонус, который собирает магнит)
---------------------------------------------------------------------------------------------
local function spawnNugget(player, pos, value, color)
	local p = Instance.new("Part")
	p.Name = "Nugget"
	p.Shape = Enum.PartType.Block
	p.Size = V3(1.1, 1.1, 1.1)
	p.CFrame = CF(pos) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 214, 70)
	p:SetAttribute("Owner", player.UserId)
	MK.Sparkles(p, { 255, 230, 120 }, 6, 0.4)
	CollectionService:AddTag(p, "Nugget")
	p.Parent = nuggetFolder
	nuggets[p] = { owner = player, value = value, born = os.clock() }
end

local function updateNuggets()
	for p, n in pairs(nuggets) do
		local remove = false
		if not n.owner.Parent or os.clock() - n.born > Balance.NuggetLifetime then
			remove = true
		else
			local char = n.owner.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local data = DataManager.Get(n.owner)
			if root and data then
				local r = Stats.PickupRadius(data)
				if (root.Position - p.Position).Magnitude <= r then
					data.Ore.Value = data.Ore.Value + n.value
					data.Stats.Nuggets = (data.Stats.Nuggets or 0) + 1
					QuestService.Track(n.owner, "Nuggets", 1)
					Notifier.Toast(n.owner, "Хроно-самородок! +" .. Util.Format(n.value) .. " к стоимости рюкзака", "good", "OrePickup")
					StateSync.MarkDirty(n.owner)
					remove = true
				end
			end
		end
		if remove then
			nuggets[p] = nil
			p:Destroy()
		end
	end
end

---------------------------------------------------------------------------------------------
-- Урон
---------------------------------------------------------------------------------------------
local gateWarn = {}
function Mining.UnlockNext(player, data, fromBiome)
	if fromBiome == data.UnlockedBiome and fromBiome < #BiomesData then
		if not Stats.CanOpenGate(data, fromBiome) then
			local now = os.clock()
			if not gateWarn[player] or now - gateWarn[player] > 8 then
				gateWarn[player] = now
				local top = Stats.GateDrill(fromBiome)
				Notifier.Toast(player, "Шлюз закрыт! Он откроется, когда у тебя будет «" .. top.Name .. "» — купи все буры яруса.", "warn", "Error")
			end
			return
		end
		data.UnlockedBiome = fromBiome + 1
		local nb = BiomesData[fromBiome + 1]
		Notifier.Alert(player, "Unlock", { Biome = fromBiome + 1, Name = nb.Name })
		Notifier.Toast(player, "Шлюз открыт: " .. nb.Name .. "! Портал на базе активен.", "unlock", "Unlock")
		StateSync.MarkDirty(player)
	end
end

-- опыт экипированным питомцам за сломанный блок
local function petXp(player, data, b, amount)
	local gain = Balance.PetXpPerBlock * (1 + 0.25 * (b - 1)) * amount
	for _, e in ipairs(Stats.EquippedPets(data)) do
		local p = e.Pet
		p.L = p.L or 1
		if p.L < Balance.PetMaxLevel then
			p.X = (p.X or 0) + gain
			local need = Stats.PetXpNeed(p.L)
			local up = false
			while p.X >= need and p.L < Balance.PetMaxLevel do
				p.X = p.X - need
				p.L = p.L + 1
				need = Stats.PetXpNeed(p.L)
				up = true
			end
			if p.L >= Balance.PetMaxLevel then
				p.X = 0
			end
			if up then
				local def = PetsData.ById[p.Id]
				Notifier.Toast(player, (def and def.Name or p.Id) .. " получил " .. p.L .. " уровень!", "good", "LevelUp")
			end
		end
	end
end

local function onBroken(player, data, inf, part)
	local b = inf.b
	local s = data.Stats
	-- глубина считается по слою блока, который игрок сломал сам
	local bd = BiomesData[b]
	local depth = bd.MinDepth + (bd.MaxDepth - bd.MinDepth) * (inf.y / LAYERS)
	if depth > (data.RunMaxDepth or 0) then
		data.RunMaxDepth = depth
	end
	if depth > (s.MaxDepth or 0) then
		s.MaxDepth = math.floor(depth)
	end
	QuestService.Track(player, "Depth", depth, b)
	s.BlocksBroken = s.BlocksBroken + 1
	if b == 1 then
		s.Biome1Blocks = s.Biome1Blocks + 1
	elseif b == 3 then
		s.IceBlocks = s.IceBlocks + 1
	end
	if inf.kind.Tag == "Amber" then
		s.AmberBlocks = s.AmberBlocks + 1
	end
	QuestService.Track(player, "MineBlocks", 1, b)
	if inf.kind.Ore then
		QuestService.Track(player, "MineOre", 1, b)
	end
	if inf.vein then
		s.VeinsBroken = (s.VeinsBroken or 0) + 1
		QuestService.Track(player, "MineVeins", 1, b)
	end
	petXp(player, data, b, inf.vein and 5 or 1)

	local seed = SeedsData.ByBiome[b]
	if seed then
		local chance = seed.Chance
		if inf.vein then
			chance = chance * Balance.VeinSeedMult
		end
		if goldRush() then
			chance = chance * Balance.GoldRushMult
		end
		if Stats.BoostActive(data, "LuckyCharm") then
			chance = chance * 2.5
		end
		if rng:NextNumber() < chance then
			data.Seeds[seed.Id] = (data.Seeds[seed.Id] or 0) + 1
			Notifier.Toast(player, "Найдено Хроно-Семя: " .. seed.Name .. "!", "seed", "Seed")
		end
	end
	if rng:NextNumber() < Balance.NuggetChance then
		spawnNugget(player, part.Position, inf.max * inf.price * Balance.NuggetValueMult * 0.1)
	end
	if inf.y == LAYERS then
		Mining.UnlockNext(player, data, b)
	end
	StateSync.MarkDirty(player)
	breakBlock(part, inf, player)
end

local function applyDamage(player, data, part, dmg)
	local inf = info[part]
	if not inf then
		return false
	end
	-- рюкзак наполняется нанесённым уроном (но не больше оставшейся прочности блока)
	local dealt = math.min(dmg, math.max(0, inf.hp))
	local room = math.max(0, Stats.Capacity(data) - data.Ore.Count)
	local take = math.min(dealt, room)
	if take > 0 then
		data.Ore.Count = data.Ore.Count + take
		data.Ore.Value = data.Ore.Value + take * inf.price
		StateSync.MarkDirty(player)
	end
	inf.hp = inf.hp - dmg
	data.Stats.TotalDamage = data.Stats.TotalDamage + dealt
	QuestService.Track(player, "DealDamage", dealt)
	if inf.hp <= 0 then
		onBroken(player, data, inf, part)
		return true
	end
	part:SetAttribute("CurrentHealth", inf.hp)
	return false
end

local function randomNeighbor(inf)
	local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0, 1, 0 } }
	local start = rng:NextInteger(1, #dirs)
	for k = 0, #dirs - 1 do
		local d = dirs[((start + k - 1) % #dirs) + 1]
		local x, y, z = inf.x + d[1], inf.y + d[2], inf.z + d[3]
		if x >= 1 and x <= GRID and z >= 1 and z <= GRID and y >= 1 and y <= LAYERS then
			local p = state[inf.b][idx(x, y, z)]
			if p then
				return p
			end
		end
	end
	return nil
end

local function onMine(player, part)
	if typeof(part) ~= "Instance" then
		return
	end
	local inf = info[part]
	if not inf then
		return
	end
	local data = DataManager.Get(player)
	if not data then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	if (root.Position - part.Position).Magnitude > Balance.MineReach + 8 then
		return
	end
	if inf.b > data.UnlockedBiome then
		return
	end
	local now = os.clock()
	local interval = Stats.HitInterval(data)
	if lastHit[player] and now - lastHit[player] < interval * 0.7 then
		return
	end
	lastHit[player] = now
	player:SetAttribute("Mining", true)
	local hitResult = Net.Get("HitResult")

	if data.Ore.Count >= Stats.Capacity(data) then
		if not fullWarn[player] or now - fullWarn[player] > 4 then
			fullWarn[player] = now
			Notifier.Toast(player, "Рюкзак полон! Жми «На базу» и продай руду.", "warn", "Error")
		end
		hitResult:FireClient(player, part, 0, false, "full")
		return
	end
	if inf.owner and inf.owner ~= player.UserId and now < inf.ownerUntil then
		hitResult:FireClient(player, part, 0, false, "owned")
		return
	end
	inf.owner = player.UserId
	inf.ownerUntil = now + Balance.AntiStealTime

	local dmg = Stats.Damage(data)
	QuestService.Track(player, "Hits", 1)
	local crit = rng:NextNumber() < Balance.CritChance
	if crit then
		dmg = dmg * Balance.CritMult
		data.Stats.Crits = data.Stats.Crits + 1
		QuestService.Track(player, "Crits", 1)
	end
	local _, splash = Stats.Auras(data)
	local neighbor = nil
	if splash > 0 then
		neighbor = randomNeighbor(inf)
	end
	applyDamage(player, data, part, dmg)
	hitResult:FireClient(player, part, dmg, crit)
	if neighbor and info[neighbor] then
		local ninf = info[neighbor]
		if not ninf.owner or ninf.owner == player.UserId or now >= ninf.ownerUntil then
			if data.Ore.Count < Stats.Capacity(data) then
				applyDamage(player, data, neighbor, dmg * splash)
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Генерация / сброс
---------------------------------------------------------------------------------------------
function Mining.ResetBiome(b)
	local st = state[b] or {}
	local folder = WorldBuilder.MinesFolder(b)
	local count = 0
	for _, part in ipairs(folder:GetChildren()) do
		info[part] = nil
		releasePart(part)
		count = count + 1
		if count % Balance.ResetBatchSize == 0 then
			task.wait()
		end
	end
	state[b] = {}
	count = 0
	for z = 1, GRID do
		for x = 1, GRID do
			spawnCell(b, x, 1, z)
			count = count + 1
			if count % Balance.ResetBatchSize == 0 then
				task.wait()
			end
		end
	end
end

function Mining.ResetAll()
	for b = 1, #BiomesData do
		Mining.ResetBiome(b)
	end
end

function Mining.BiomeAt(pos)
	local b = math.floor(pos.X / Balance.BiomeSpacing + 0.5) + 1
	if b < 1 or b > #BiomesData then
		return nil
	end
	local O = WorldBuilder.Origin(b)
	if math.abs(pos.X - O.X) > 260 then
		return nil
	end
	return b
end

function Mining.InShaft(b, pos)
	local O = WorldBuilder.Origin(b)
	return math.abs(pos.X - O.X) < HALF and math.abs(pos.Z - O.Z) < HALF
end

---------------------------------------------------------------------------------------------
-- Глубина, шлюзы, защита от выпадения
---------------------------------------------------------------------------------------------
local Travel -- задаётся в Init (избегаем циклического require)

local function depthTick()
	local nowClock = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Mining") and (not lastHit[player] or nowClock - lastHit[player] > 0.6) then
			player:SetAttribute("Mining", false)
		end
		local data = DataManager.Get(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if data and root then
			local pos = root.Position
			local b = Mining.BiomeAt(pos)
			if not b then
				if pos.Y < -(DEPTH + 50) and Travel then
					Travel.ToHub(player)
				end
			else
				if b > data.UnlockedBiome and Travel then
					Travel.ToHub(player)
				elseif Mining.InShaft(b, pos) and pos.Y < 0 then
					-- только отображение: рекорды глубины и шлюз засчитываются за САМОСТОЯТЕЛЬНО
					-- сломанные блоки (onBroken), иначе новичок мог спрыгнуть в чужую яму и пройти ярус
					local depth = Stats.DepthAt(b, pos.Y - 3)
					player:SetAttribute("Depth", depth)
					player:SetAttribute("Biome", b)
				else
					player:SetAttribute("Depth", BiomesData[b].MinDepth)
					player:SetAttribute("Biome", b)
					if pos.Y < -(DEPTH + 40) and Travel then
						Travel.ToHub(player)
					end
				end
			end
		end
	end
end

function Mining.Init(travelModule)
	Travel = travelModule
	nuggetFolder = Instance.new("Folder")
	nuggetFolder.Name = "Nuggets"
	nuggetFolder.Parent = workspace
	for b = 1, #BiomesData do
		state[b] = {}
	end
	Net.Get("MineBlock").OnServerEvent:Connect(onMine)
	Players.PlayerRemoving:Connect(function(p)
		lastHit[p] = nil
		fullWarn[p] = nil
		gateWarn[p] = nil
	end)
	local acc, acc2 = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		acc2 = acc2 + dt
		if acc >= 0.5 then
			acc = 0
			depthTick()
		end
		if acc2 >= 0.15 then
			acc2 = 0
			updateNuggets()
		end
	end)
end

return Mining
