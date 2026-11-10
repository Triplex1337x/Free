-- PetManager: открытие яиц (гача), экипировка, улучшение (★ → ★★ → ★★★ → Золотой → Радужный), удаление.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local Balance = require(Configs.Balance)
local EggsData = require(Configs.EggsData)
local PetsData = require(Configs.PetsData)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)
local WorldBuilder = require(script.Parent.WorldBuilder)
local QuestService = require(script.Parent.QuestService)

local PetManager = {}
PetManager.SHINY = 6 -- индекс улучшения «Шайни» в Balance.PetTiers (T = 6)
local rng = Random.new()
local openDebounce = {}

function PetManager.RefreshAttribute(player)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	local parts = {}
	for _, e in ipairs(Stats.EquippedPets(data)) do
		table.insert(parts, e.Pet.Id .. ":" .. tostring(e.Pet.T or 0))
	end
	player:SetAttribute("PetsEquipped", table.concat(parts, ","))
	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = Stats.WalkSpeed(data)
		end
	end
end

-- power — своя сила для эксклюзивов и петов из семян (иначе берётся из PetsData)
function PetManager.AddPet(data, id, power, tier)
	local uid = "p" .. data.NextPetUid
	data.NextPetUid = data.NextPetUid + 1
	data.Pets[uid] = { Id = id, E = false, B = power, T = tier or 0, L = 1, X = 0 }
	-- индекс: питомец считается открытым, как только появился у игрока
	data.Index = data.Index or {}
	data.Index[id] = true
	return uid
end

-- ключ стака: одинаковые питомцы одного улучшения и уровня складываются в одну карточку
local function stackKey(p)
	return p.Id .. ":" .. tostring(p.T or 0) .. ":" .. tostring(p.L or 1)
end
PetManager.StackKey = stackKey

local function equippedCount(data)
	local n = 0
	for _, p in pairs(data.Pets) do
		if p.E then
			n = n + 1
		end
	end
	return n
end

local function roll(egg, luck)
	local function weight(entry)
		local w = entry[3]
		if luck > 1 and entry[3] <= Balance.LuckyRareThreshold then
			w = w * luck
		end
		return w
	end
	local entry = Util.WeightedPick(egg.Pets, weight, rng)
	return entry[1]
end

local function openEgg(player, eggId, count)
	local data = DataManager.Get(player)
	local egg = EggsData.ById[eggId]
	if not data or not egg then
		return { ok = false, msg = "Неизвестное яйцо" }
	end
	if count == 8 then
		if not Stats.HasPass(DataManager.Get(player), "HatchX8") then
			return { ok = false, msg = "Открытие x8 — геймпасс в магазине «Донат»" }
		end
	elseif count ~= 3 then
		count = 1
	end
	if openDebounce[player] and os.clock() - openDebounce[player] < 0.8 then
		return { ok = false, msg = "" }
	end
	if egg.Biome > data.UnlockedBiome then
		return { ok = false, msg = "Это яйцо находится в закрытом биоме" }
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pts = WorldBuilder.Points[egg.Biome]
	local standPos = pts and pts.Eggs and pts.Eggs[eggId]
	if not root or not standPos or (root.Position - standPos).Magnitude > 30 then
		return { ok = false, msg = "Подойди к яйцу на базе" }
	end
	local price = egg.Price * count
	if data.Coins < price then
		return { ok = false, msg = "Не хватает монет: нужно " .. Util.Format(price) }
	end
	-- если все питомцы яйца стоят на автоудалении — место в инвентаре не нужно
	local allDeleted = true
	for _, e in ipairs(egg.Pets) do
		if not (data.AutoDelete and data.AutoDelete[e[1]]) then
			allDeleted = false
		end
	end
	if not allDeleted and Stats.PetCount(data) + count > Stats.PetStorage(data) then
		return { ok = false, msg = "Инвентарь питомцев полон (" .. Stats.PetCount(data) .. "/" .. Stats.PetStorage(data) .. "). Удали лишних, улучши их или докупи места в окне «Питомцы»." }
	end
	openDebounce[player] = os.clock()
	data.Coins = data.Coins - price
	local luck = Stats.LuckMult(data)
	local results = {}
	for i = 1, count do
		local id = roll(egg, luck)
		local shiny = rng:NextNumber() < (Balance.ShinyChance or 0) * math.min(luck, 4)
		-- автоудаление (выбирается в окне яйца); шайни никогда не удаляются
		if not shiny and data.AutoDelete and data.AutoDelete[id] then
			data.Index = data.Index or {}
			data.Index[id] = true
			data.Stats.AutoDeleted = (data.Stats.AutoDeleted or 0) + 1
			table.insert(results, { Id = id, Deleted = true, T = 0 })
		else
			local uid = PetManager.AddPet(data, id, nil, shiny and PetManager.SHINY or 0)
			table.insert(results, { Id = id, Uid = uid, T = shiny and PetManager.SHINY or 0 })
		end
		local def = PetsData.ById[id]
		if shiny then
			data.Stats.Shinies = (data.Stats.Shinies or 0) + 1
			Notifier.ToastAll("✦ " .. player.DisplayName .. " выбил ШАЙНИ " .. (def and def.Name or id) .. "! ✦", "unlock")
		elseif def and def.Rarity == "Huge" then
			Notifier.ToastAll("★ " .. player.DisplayName .. " выбил ОГРОМНОГО питомца: " .. def.Name .. " (1 из " .. Util.Format(math.floor(100 / math.max(def.Chance, 1e-6) + 0.5)) .. ")! ★", "unlock")
		elseif def and (def.Rarity == "Legendary" or def.Rarity == "Mythic") then
			Notifier.ToastAll(player.DisplayName .. " выбил " .. def.Name .. " (" .. string.format("%.1f", def.Chance) .. "%)!", "unlock")
		end
	end
	data.Stats.EggsOpened = data.Stats.EggsOpened + count
	if egg.Biome == 1 then
		data.Stats.EggsBiome1 = data.Stats.EggsBiome1 + count
	end
	local session = DataManager.GetSession(player)
	session.Eggs = session.Eggs + count
	QuestService.Track(player, "OpenEggs", count)
	-- автоэкипировка, если есть свободные слоты
	local slots = Stats.PetSlots(data)
	for _, r in ipairs(results) do
		if r.Uid and equippedCount(data) < slots then
			data.Pets[r.Uid].E = true
		end
	end
	PetManager.RefreshAttribute(player)
	StateSync.MarkDirty(player)
	return { ok = true, pets = results, egg = eggId }
end

local function equipBest(data)
	for _, p in pairs(data.Pets) do
		p.E = false
	end
	local list = {}
	for uid, p in pairs(data.Pets) do
		table.insert(list, { uid = uid, m = Stats.PetMult(p) })
	end
	table.sort(list, function(a, b)
		return a.m > b.m
	end)
	for i = 1, math.min(#list, Stats.PetSlots(data)) do
		data.Pets[list[i].uid].E = true
	end
end

local function petAction(player, action, arg, arg2)
	local data = DataManager.Get(player)
	if not data then
		return { ok = false }
	end
	if action == "Equip" then
		local p = data.Pets[arg]
		if not p then
			return { ok = false }
		end
		if not p.E and equippedCount(data) >= Stats.PetSlots(data) then
			return { ok = false, msg = "Все слоты заняты (" .. Stats.PetSlots(data) .. ")" }
		end
		p.E = true
	elseif action == "EquipStack" then
		-- экипировать одного питомца из стака (ключ Id:T:L)
		if equippedCount(data) >= Stats.PetSlots(data) then
			return { ok = false, msg = "Все слоты заняты (" .. Stats.PetSlots(data) .. ")" }
		end
		for _, p in pairs(data.Pets) do
			if stackKey(p) == arg and not p.E and not p.B then
				p.E = true
				break
			end
		end
	elseif action == "Unequip" then
		local p = data.Pets[arg]
		if p then
			p.E = false
		end
	elseif action == "UnequipStack" then
		for _, p in pairs(data.Pets) do
			if stackKey(p) == arg and p.E and not p.B then
				p.E = false
				break
			end
		end
	elseif action == "UnequipAll" then
		for _, p in pairs(data.Pets) do
			p.E = false
		end
	elseif action == "AutoDelete" then
		-- arg = Id питомца, arg2 = true/false
		if type(arg) ~= "string" or not PetsData.ById[arg] then
			return { ok = false }
		end
		data.AutoDelete = data.AutoDelete or {}
		data.AutoDelete[arg] = arg2 and true or nil
	elseif action == "DeleteMany" then
		-- arg = список ключей стаков (Id:T:L) и uid эксклюзивов; надетые не удаляются
		if type(arg) ~= "table" then
			return { ok = false }
		end
		local keys = {}
		for i, k in ipairs(arg) do
			if type(k) == "string" and i <= 600 then
				keys[k] = true
			end
		end
		local n = 0
		for uid, p in pairs(data.Pets) do
			if not p.E and ((not p.B and keys[stackKey(p)]) or keys[uid]) then
				data.Pets[uid] = nil
				n = n + 1
			end
		end
		if n == 0 then
			return { ok = false, msg = "Нечего удалять (надетые питомцы не удаляются)" }
		end
		Notifier.Toast(player, "Удалено питомцев: " .. n, "good")
		PetManager.RefreshAttribute(player)
		StateSync.MarkDirty(player)
		return { ok = true, deleted = n }
	elseif action == "EquipBest" then
		equipBest(data)
	elseif action == "Delete" then
		local p = data.Pets[arg]
		if not p then
			return { ok = false }
		end
		data.Pets[arg] = nil
	elseif action == "DeleteStack" then
		local n = 0
		for uid, p in pairs(data.Pets) do
			if stackKey(p) == arg and not p.E and not p.B then
				data.Pets[uid] = nil
				n = n + 1
			end
		end
		if n == 0 then
			return { ok = false, msg = "Нельзя удалить экипированных питомцев" }
		end
	elseif action == "Upgrade" then
		-- arg = Id, arg2 = текущее улучшение (0..4)
		local tier = math.floor(tonumber(arg2) or 0)
		local nextTier = Balance.PetTiers[tier + 2]
		if not nextTier or nextTier.NoCraft or tier == PetManager.SHINY then
			return { ok = false, msg = "Это максимальное улучшение" }
		end
		local need = nextTier.Cost
		local cands = {}
		for uid, p in pairs(data.Pets) do
			if p.Id == arg and (p.T or 0) == tier and not p.B then
				table.insert(cands, { uid = uid, p = p })
			end
		end
		if #cands < need then
			return { ok = false, msg = "Нужно " .. need .. " одинаковых питомцев" }
		end
		-- берём самых прокачанных: новый питомец получает их лучший уровень
		table.sort(cands, function(a, b)
			if (a.p.L or 1) ~= (b.p.L or 1) then
				return (a.p.L or 1) > (b.p.L or 1)
			end
			return (a.p.X or 0) > (b.p.X or 0)
		end)
		local wasEquipped, level, xp = false, 1, 0
		for i = 1, need do
			local c = cands[i]
			if c.p.E then
				wasEquipped = true
			end
			if (c.p.L or 1) > level then
				level, xp = c.p.L or 1, c.p.X or 0
			end
			data.Pets[c.uid] = nil
		end
		local uid = PetManager.AddPet(data, arg, nil, tier + 1)
		data.Pets[uid].L = level
		data.Pets[uid].X = xp
		data.Pets[uid].E = wasEquipped
		data.Stats.GoldenCrafted = (data.Stats.GoldenCrafted or 0) + 1
		local def = PetsData.ById[arg]
		Notifier.Toast(player, (def and def.Name or arg) .. " улучшен: " .. nextTier.Name .. "!", "good", "Upgrade")
		PetManager.RefreshAttribute(player)
		StateSync.MarkDirty(player)
		return { ok = true, uid = uid, tier = tier + 1 }
	else
		return { ok = false }
	end
	PetManager.RefreshAttribute(player)
	StateSync.MarkDirty(player)
	return { ok = true }
end

function PetManager.Init()
	Net.Get("OpenEgg").OnServerInvoke = function(player, eggId, count)
		if type(eggId) ~= "string" then
			return { ok = false }
		end
		return openEgg(player, eggId, count)
	end
	Net.Get("PetAction").OnServerInvoke = function(player, action, arg, arg2)
		if type(action) ~= "string" then
			return { ok = false }
		end
		return petAction(player, action, arg, arg2)
	end
	Net.Get("BuyPetStorage").OnServerInvoke = function(player)
		local data = DataManager.Get(player)
		if not data then
			return { ok = false }
		end
		local cost = Stats.PetStorageCost(data)
		if not cost then
			return { ok = false, msg = "Куплено максимум мест за монеты. Ещё +100 — геймпасс в «Донате»" }
		end
		if data.Coins < cost then
			return { ok = false, msg = "Не хватает монет: нужно " .. Util.Format(cost) }
		end
		data.Coins = data.Coins - cost
		data.PetStorageLevel = (data.PetStorageLevel or 0) + 1
		Notifier.Toast(player, "Инвентарь питомцев: " .. Stats.PetStorage(data) .. " мест", "good", "Upgrade")
		StateSync.MarkDirty(player)
		return { ok = true, storage = Stats.PetStorage(data) }
	end
	Players.PlayerRemoving:Connect(function(p)
		openDebounce[p] = nil
	end)
end

return PetManager
