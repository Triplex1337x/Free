-- AdminCommands: консоль разработчика. Доступ — в Studio, владельцу плейса, админам группы (ранг 254+)
-- и тем, чей UserId вписан в EXTRA_ADMINS. Открывается клавишей F2 (или кнопкой «Консоль» у админа).
-- Те же команды работают и в чате: !coins 1e9  (или /coins 1e9)
--
-- Цель команды: по умолчанию ты сам. Чтобы применить к другому игроку, добавь @ник в конце:
--   coins 1e6 @Player2      ·  всем на сервере: coins 1e6 @all
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local SeedsData = require(Configs.SeedsData)
local BoostsData = require(Configs.BoostsData)
local DrillsData = require(Configs.DrillsData)
local BackpacksData = require(Configs.BackpacksData)
local PetsData = require(Configs.PetsData)
local BiomesData = require(Configs.BiomesData)
local Balance = require(Configs.Balance)
local Util = require(ReplicatedStorage.Shared.Util)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)

local EXTRA_ADMINS = {
	-- [12345678] = true,
}

local GamepassesData = require(Configs.GamepassesData)

local Admin = {}
local Mining, Travel, Passes

local function allowed(player)
	if RunService:IsStudio() or EXTRA_ADMINS[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= 254
end
Admin.Allowed = allowed

local function num(s, default)
	if s == nil then
		return default
	end
	s = string.lower(s)
	local mult = 1
	local last = string.sub(s, -1)
	local suffix = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, q = 1e15 }
	if suffix[last] then
		mult = suffix[last]
		s = string.sub(s, 1, -2)
	end
	local n = tonumber(s)
	return n and n * mult or default
end

local function findPet(name)
	if not name then
		return nil
	end
	if PetsData.ById[name] then
		return name
	end
	local low = string.lower(name)
	for id, def in pairs(PetsData.ById) do
		if string.lower(id) == low or string.lower(def.Name) == low then
			return id
		end
	end
	for id, def in pairs(PetsData.ById) do
		if string.find(string.lower(id), low, 1, true) or string.find(string.lower(def.Name), low, 1, true) then
			return id
		end
	end
	return nil
end

local function refresh(player)
	local PetManager = require(script.Parent.PetManager)
	local Shop = require(script.Parent.ShopManager)
	pcall(Shop.AttachGear, player)
	pcall(PetManager.RefreshAttribute, player)
	StateSync.MarkDirty(player)
end

-- команды: { args, описание, функция(player, data, args) -> текст }
local COMMANDS = {}
local ORDER = {}
local function cmd(name, usage, desc, fn)
	COMMANDS[name] = { Usage = usage, Desc = desc, Fn = fn }
	table.insert(ORDER, name)
end

cmd("help", "", "список команд", function()
	local lines = {}
	for _, n in ipairs(ORDER) do
		local c = COMMANDS[n]
		table.insert(lines, n .. (c.Usage ~= "" and (" " .. c.Usage) or "") .. " — " .. c.Desc)
	end
	return table.concat(lines, "\n")
end)

cmd("coins", "<n>", "добавить монет (можно 5k, 2m, 3b, 1t)", function(_, data, a)
	local n = num(a[1], 1e6)
	data.Coins = data.Coins + n
	data.TotalCoins = data.TotalCoins + math.max(0, n)
	return "Монеты: " .. Util.Format(data.Coins)
end)

cmd("setcoins", "<n>", "установить монеты", function(_, data, a)
	data.Coins = math.max(0, num(a[1], 0))
	return "Монеты: " .. Util.Format(data.Coins)
end)

cmd("unlock", "<1-5>", "открыть ярусы до N", function(_, data, a)
	data.UnlockedBiome = math.clamp(math.floor(num(a[1], 5)), 1, #BiomesData)
	return "Открыто ярусов: " .. data.UnlockedBiome
end)

cmd("drill", "<номер|max>", "выдать буры до номера (и надеть)", function(_, data, a)
	local n = a[1] == "max" and #DrillsData.List or math.clamp(math.floor(num(a[1], 1)), 1, #DrillsData.List)
	for i = 1, n do
		data.OwnedDrills[DrillsData.List[i].Id] = true
	end
	data.Drill = DrillsData.List[n].Id
	return "Бур: " .. DrillsData.List[n].Name .. " (урон " .. Util.Format(DrillsData.List[n].Damage) .. ")"
end)

cmd("pack", "<номер|max>", "выдать рюкзаки до номера (и надеть)", function(_, data, a)
	local n = a[1] == "max" and #BackpacksData.List or math.clamp(math.floor(num(a[1], 1)), 1, #BackpacksData.List)
	for i = 1, n do
		data.OwnedBackpacks[BackpacksData.List[i].Id] = true
	end
	data.Backpack = BackpacksData.List[n].Id
	return "Рюкзак: " .. BackpacksData.List[n].Name .. " (" .. Util.Format(BackpacksData.List[n].Capacity) .. ")"
end)

cmd("pet", "<id|имя> [улучш. 0-5] [уровень] [кол-во]", "выдать питомца", function(_, data, a)
	local id = findPet(a[1])
	if not id then
		return "Питомец не найден. Пример: pet Worm 2 10"
	end
	local PetManager = require(script.Parent.PetManager)
	local tier = math.clamp(math.floor(num(a[2], 0)), 0, #Balance.PetTiers - 1)
	local level = math.clamp(math.floor(num(a[3], 1)), 1, Balance.PetMaxLevel)
	local count = math.clamp(math.floor(num(a[4], 1)), 1, 50)
	local def = PetsData.ById[id]
	local power = nil
	if def.Special or def.Seed then
		power = def.P
	end
	for _ = 1, count do
		local uid = PetManager.AddPet(data, id, power, tier)
		data.Pets[uid].L = level
	end
	return "Выдано: " .. def.Name .. " x" .. count .. " (улучш. " .. tier .. ", ур. " .. level .. ")"
end)

cmd("pets", "", "список Id питомцев", function()
	local ids = {}
	for id in pairs(PetsData.ById) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return table.concat(ids, ", ")
end)

cmd("clearpets", "", "удалить всех питомцев", function(_, data)
	data.Pets = {}
	return "Питомцы удалены"
end)

cmd("petlevel", "<уровень>", "уровень всем надетым питомцам", function(_, data, a)
	local lvl = math.clamp(math.floor(num(a[1], Balance.PetMaxLevel)), 1, Balance.PetMaxLevel)
	local n = 0
	for _, p in pairs(data.Pets) do
		if p.E then
			p.L = lvl
			p.X = 0
			n = n + 1
		end
	end
	return "Уровень " .. lvl .. " у " .. n .. " питомцев"
end)

cmd("boosts", "[n]", "по N каждого буста", function(_, data, a)
	local n = math.floor(num(a[1], 5))
	for _, b in ipairs(BoostsData.List) do
		data.Boosts[b.Id] = (data.Boosts[b.Id] or 0) + n
	end
	return "Бусты +" .. n
end)

cmd("seeds", "[n]", "по N каждого семени", function(_, data, a)
	local n = math.floor(num(a[1], 3))
	for _, s in ipairs(SeedsData.List) do
		data.Seeds[s.Id] = (data.Seeds[s.Id] or 0) + n
	end
	return "Семена +" .. n
end)

cmd("shards", "<n>", "Хроно-Осколки", function(_, data, a)
	data.Shards = (data.Shards or 0) + math.floor(num(a[1], 10))
	return "Осколки: " .. data.Shards
end)

cmd("rebirths", "<n>", "установить число ребёрсов", function(_, data, a)
	data.Rebirths = math.max(0, math.floor(num(a[1], 1)))
	return "Ребёрсы: " .. data.Rebirths
end)

cmd("quests", "", "выполнить текущие задания (динамические и недельные)", function(_, data)
	for _, q in pairs(data.Dynamic or {}) do
		if q.Target then
			q.Progress = q.Target
		end
	end
	for _, q in ipairs((data.Weekly and data.Weekly.Quests) or {}) do
		q.Progress = q.Target
	end
	return "Задания выполнены — забери награды в окне «Задания»"
end)

cmd("newquests", "", "выдать новые динамические и недельные задания", function(_, data)
	data.Dynamic = {}
	data.Weekly = { Week = -1, Quests = {}, BonusClaimed = false }
	return "Новые задания появятся через секунду"
end)

cmd("story", "<номер>", "перейти к сюжетному квесту", function(_, data, a)
	data.StoryIndex = math.max(1, math.floor(num(a[1], 1)))
	return "Сюжет: " .. data.StoryIndex
end)

cmd("daily", "", "ежедневная награда снова доступна", function(_, data)
	data.Daily.Last = 0
	return "Ежедневная награда готова"
end)

cmd("wheel", "", "колесо снова доступно", function(_, data)
	data.WheelLast = 0
	return "Колесо готово"
end)

cmd("tutorial", "", "пройти обучение заново", function(_, data)
	data.TutorialStep = 0
	data.Stats.BlocksBroken = 0
	return "Обучение сброшено — перезайди"
end)

cmd("resetmine", "", "вайп шахт через 12 секунд", function()
	workspace:SetAttribute("MineResetAt", os.time() + 12)
	return "Вайп через 12 с"
end)

cmd("goldrush", "[сек]", "включить Золотую лихорадку", function(_, _, a)
	local sec = math.floor(num(a[1], Balance.GoldRushDuration))
	workspace:SetAttribute("GoldRushUntil", os.time() + sec)
	Notifier.AlertAll("GoldRush", {})
	return "Золотая лихорадка на " .. sec .. " с"
end)

cmd("tp", "<hub|mine> [ярус]", "телепорт", function(player, data, a)
	local b = math.clamp(math.floor(num(a[2], data.CurrentBiome or 1)), 1, #BiomesData)
	if b > data.UnlockedBiome then
		data.UnlockedBiome = b
	end
	if a[1] == "mine" then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local O = Vector3.new((b - 1) * Balance.BiomeSpacing, 0, 0)
			data.CurrentBiome = b
			root.CFrame = CFrame.new(O + Vector3.new(0, 6, 0))
		end
		return "Шахта яруса " .. b
	end
	if Travel then
		Travel.GoToBiome(player, b, false)
	end
	return "База яруса " .. b
end)

local function rootOf(p)
	local ch = p and p.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

cmd("goto", "@ник", "телепорт к игроку", function(target, data, _, caller)
	local a, b = rootOf(caller), rootOf(target)
	if not a or not b or caller == target then
		return "Выбери другого игрока"
	end
	local cd = DataManager.Get(caller)
	if cd then
		cd.CurrentBiome = data.CurrentBiome
		cd.UnlockedBiome = math.max(cd.UnlockedBiome or 1, data.CurrentBiome or 1)
		StateSync.MarkDirty(caller)
	end
	a.CFrame = b.CFrame * CFrame.new(0, 0, 5)
	return "Ты у игрока " .. target.Name
end)

cmd("bring", "@ник", "призвать игрока к себе", function(target, data, _, caller)
	local a, b = rootOf(caller), rootOf(target)
	if not a or not b or caller == target then
		return "Выбери другого игрока"
	end
	local cd = DataManager.Get(caller)
	if cd then
		data.CurrentBiome = cd.CurrentBiome
		data.UnlockedBiome = math.max(data.UnlockedBiome or 1, cd.CurrentBiome or 1)
	end
	b.CFrame = a.CFrame * CFrame.new(0, 0, -5)
	return target.Name .. " призван"
end)

cmd("speed", "<n>", "скорость бега (0 = обычная)", function(player, data, a)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local n = num(a[1], 0)
	if hum then
		hum.WalkSpeed = n > 0 and n or Stats.WalkSpeed(data)
	end
	return "Скорость: " .. (hum and hum.WalkSpeed or 0)
end)

cmd("time", "<0-24>", "время суток на сервере", function(_, _, a)
	game:GetService("Lighting").ClockTime = num(a[1], 14)
	return "Время: " .. game:GetService("Lighting").ClockTime
end)

cmd("announce", "<текст>", "сообщение всем игрокам", function(_, _, a)
	local text = table.concat(a, " ")
	Notifier.ToastAll(text, "unlock")
	return "Отправлено"
end)

cmd("info", "", "сводка по профилю", function(player, data)
	return string.format("%s · монеты %s · ярус %d/%d · бур %s · рюкзак %s · урон %s · петы %d · ребёрсы %d",
		player.Name, Util.Format(data.Coins), data.CurrentBiome or 1, data.UnlockedBiome or 1, data.Drill, data.Backpack,
		Util.Format(Stats.Damage(data)), Stats.PetCount(data), data.Rebirths or 0)
end)

cmd("players", "", "игроки на сервере", function()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(t, p.Name .. " (" .. p.UserId .. ")")
	end
	return table.concat(t, ", ")
end)

cmd("max", "", "всё открыть: ярусы, топ бур и рюкзак", function(_, data)
	data.UnlockedBiome = #BiomesData
	for _, d in ipairs(DrillsData.List) do
		data.OwnedDrills[d.Id] = true
	end
	for _, p in ipairs(BackpacksData.List) do
		data.OwnedBackpacks[p.Id] = true
	end
	data.Drill = DrillsData.List[#DrillsData.List].Id
	data.Backpack = BackpacksData.List[#BackpacksData.List].Id
	return "Открыто всё"
end)

cmd("addrebirths", "<n>", "добавить ребёрсы", function(_, data, a)
	data.Rebirths = math.max(0, (data.Rebirths or 0) + math.floor(num(a[1], 1)))
	return "Ребёрсы: " .. data.Rebirths
end)

cmd("pass", "<ключ|all> [on|off]", "выдать/снять геймпасс (ключи: passes)", function(player, data, a)
	local key = a[1] or ""
	local on = string.lower(a[2] or "on") ~= "off"
	local keys = {}
	if string.lower(key) == "all" then
		for _, d in ipairs(GamepassesData.List) do
			table.insert(keys, d.Key)
		end
	else
		for _, d in ipairs(GamepassesData.List) do
			if string.lower(d.Key) == string.lower(key) then
				table.insert(keys, d.Key)
			end
		end
	end
	if #keys == 0 then
		return "Нет такого геймпасса. Ключи: passes"
	end
	for _, k in ipairs(keys) do
		if Passes then
			Passes.Set(player, k, on, #keys > 1)
		else
			data.Passes = data.Passes or {}
			data.Passes[k] = on or nil
		end
	end
	return (on and "Выдано: " or "Снято: ") .. table.concat(keys, ", ")
end)

cmd("passes", "", "список геймпассов", function(_, data)
	local t = {}
	for _, d in ipairs(GamepassesData.List) do
		table.insert(t, d.Key .. (Stats.HasPass(data, d.Key) and " ✓" or ""))
	end
	return table.concat(t, ", ")
end)

local EVENT_NAMES = { coins = "Coins", damage = "Damage", luck = "Luck" }
local EVENT_TITLES = { Coins = "x%s МОНЕТЫ", Damage = "x%s УРОН", Luck = "x%s УДАЧА" }
cmd("event", "<coins|damage|luck|stop> [множ.] [минуты]", "серверное событие для всех", function(_, _, a)
	local kind = string.lower(a[1] or "")
	if kind == "stop" then
		for _, k in pairs(EVENT_NAMES) do
			workspace:SetAttribute("Event_" .. k, nil)
			workspace:SetAttribute("Event_" .. k .. "_Until", nil)
		end
		Notifier.ToastAll("События завершены", "info")
		return "Все события остановлены"
	end
	local k = EVENT_NAMES[kind]
	if not k then
		return "Пример: event coins 2 15"
	end
	local mult = math.clamp(num(a[2], 2), 1, 100)
	local minutes = math.clamp(num(a[3], 15), 0.1, 24 * 60)
	workspace:SetAttribute("Event_" .. k, mult)
	workspace:SetAttribute("Event_" .. k .. "_Until", os.time() + math.floor(minutes * 60))
	local title = string.format(EVENT_TITLES[k], tostring(mult))
	Notifier.ToastAll("СОБЫТИЕ: " .. title .. " на " .. tostring(minutes) .. " мин!", "unlock")
	for _, p in ipairs(Players:GetPlayers()) do
		StateSync.MarkDirty(p)
	end
	return "Событие " .. title .. " на " .. minutes .. " мин"
end)

cmd("wipe", "", "сбросить профиль", function(_, data)
	local fresh = DataManager.Template()
	for k in pairs(data) do
		if string.sub(k, 1, 1) ~= "_" then
			data[k] = nil
		end
	end
	for k, v in pairs(fresh) do
		data[k] = v
	end
	return "Профиль сброшен"
end)

-- выполнить строку команды; возвращает ok, текст
function Admin.Run(player, line)
	if not allowed(player) then
		return false, "Нет доступа"
	end
	line = tostring(line or "")
	line = string.gsub(line, "^%s*/?", "")
	local args = {}
	for w in string.gmatch(line, "%S+") do
		table.insert(args, w)
	end
	local name = string.lower(table.remove(args, 1) or "")
	local c = COMMANDS[name]
	if not c then
		return false, "Неизвестная команда «" .. name .. "». Напиши help"
	end
	-- цель: @ник в конце (@all — все игроки на сервере)
	local target = player
	if #args > 0 and string.lower(args[#args]) == "@all" then
		table.remove(args)
		local n, last = 0, ""
		for _, p in ipairs(Players:GetPlayers()) do
			local data = DataManager.Get(p)
			if data then
				local ok, res = pcall(c.Fn, p, data, table.clone(args), player)
				if ok then
					n = n + 1
					last = tostring(res or "")
					refresh(p)
				end
			end
		end
		return true, "[все: " .. n .. "] " .. last
	end
	if #args > 0 and string.sub(args[#args], 1, 1) == "@" then
		local nick = string.lower(string.sub(table.remove(args), 2))
		target = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if string.lower(p.Name) == nick or string.lower(p.DisplayName) == nick or string.find(string.lower(p.Name), nick, 1, true) then
				target = p
				break
			end
		end
		if not target then
			return false, "Игрок не найден"
		end
	end
	local data = DataManager.Get(target)
	if not data then
		return false, "Профиль ещё не загружен"
	end
	local ok, res = pcall(c.Fn, target, data, args, player)
	if not ok then
		return false, "Ошибка: " .. tostring(res)
	end
	refresh(target)
	if target ~= player then
		res = "[" .. target.Name .. "] " .. tostring(res)
	end
	return true, tostring(res or "ок")
end

function Admin.Commands()
	local list = {}
	for _, n in ipairs(ORDER) do
		table.insert(list, { Name = n, Usage = COMMANDS[n].Usage, Desc = COMMANDS[n].Desc })
	end
	return list
end

function Admin.Init(mining, travel, passes)
	Mining = mining
	Travel = travel
	Passes = passes
	Net.Get("AdminCommand").OnServerInvoke = function(player, line)
		if line == "__list" then
			if not allowed(player) then
				return { ok = false }
			end
			return { ok = true, commands = Admin.Commands() }
		end
		local ok, text = Admin.Run(player, line)
		return { ok = ok, text = text }
	end
	local function hook(player)
		if allowed(player) then
			player:SetAttribute("IsAdmin", true)
		end
		player.Chatted:Connect(function(msg)
			local first = string.sub(msg, 1, 1)
			if (first == "/" or first == "!") and allowed(player) then
				msg = string.sub(msg, 2)
				local ok, text = Admin.Run(player, msg)
				Notifier.Toast(player, (ok and "Админ: " or "Админ ✕ ") .. string.sub(text, 1, 140), ok and "info" or "warn")
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
end

return Admin
