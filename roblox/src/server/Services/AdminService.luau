-- Admin commands (server-validated). The client panel only sends requests.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared.Config.Admin)
local Styles = require(Shared.Config.Styles)
local Potions = require(Shared.Config.Potions)
local Zones = require(Shared.Config.Zones)
local Prog = require(Shared.Config.Progression)
local GameConfig = require(Shared.Config.Game)
local Remotes = require(Shared.Remotes)

local AdminService = {}

local function isAdmin(player: Player): boolean
	if AdminConfig.AllowInStudio and RunService:IsStudio() then
		return true
	end
	if table.find(AdminConfig.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= AdminConfig.GroupRank
end

local function findTarget(caller: Player, name): Player?
	if type(name) ~= "string" or name == "" or name == "me" or name == "я" then
		return caller
	end
	name = name:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			return p
		end
	end
	return nil
end

function AdminService:Init(services)
	self.Services = services
	services.DataService:OnLoaded(function(player)
		task.spawn(function()
			player:SetAttribute("IsAdmin", isAdmin(player))
		end)
	end)
end

local Commands = {}

function Commands.Shards(self, target, d, amount)
	d.Shards = math.max(0, d.Shards + amount)
	return ("Shards: %d"):format(d.Shards)
end

function Commands.Spins(self, target, d, amount)
	d.Spins = math.max(0, d.Spins + amount)
	return ("Spins: %d"):format(d.Spins)
end

function Commands.SetLevel(self, target, d, amount)
	d.Level = math.clamp(math.floor(amount), 1, GameConfig.Level.Max)
	d.Xp = 0
	self.Services.ProgressionService:RecountStatPoints(d)
	self.Services.ProgressionService:ApplyCharacterStats(target)
	self.Services.ProgressionService:RefreshOverhead(target)
	self.Services.QuestService:Progress(target, "Level", d.Level)
	return ("Уровень: %d"):format(d.Level)
end

function Commands.Xp(self, target, d, amount)
	self.Services.ProgressionService:AddXp(target, math.max(0, amount))
	return "Опыт выдан"
end

function Commands.AllArts(self, target, d)
	for _, id in Styles.Order do
		d.OwnedStyles[id] = true
	end
	return "Все стили открыты"
end

function Commands.MaxMastery(self, target, d)
	for _, id in Styles.Order do
		d.Mastery[id] = { Level = Prog.Mastery.MaxLevel, Xp = 0 }
	end
	self.Services.QuestService:Progress(target, "MasteryLevel", Prog.Mastery.MaxLevel)
	return "Мастерство всех стилей: макс."
end

function Commands.Potion(self, target, d, amount, extra)
	if extra == "all" then
		for _, id in Potions.Order do
			self.Services.InventoryService:AddPotion(target, id, math.max(1, amount), true)
		end
		return "Выданы все зелья"
	end
	if not Potions.Get(extra) then
		return "Неизвестное зелье"
	end
	self.Services.InventoryService:AddPotion(target, extra, math.max(1, amount), true)
	return "Зелье выдано"
end

function Commands.ClearBuffs(self, target, d)
	table.clear(d.Buffs)
	self.Services.ProgressionService:ApplyCharacterStats(target)
	return "Баффы сняты"
end

function Commands.Teleport(self, target, d, _, zoneId)
	if not Zones.Get(zoneId) then
		return "Неизвестная локация"
	end
	local character = target.Character
	if not character then
		return "Нет персонажа"
	end
	target:SetAttribute("Zone", zoneId)
	local spawn = if zoneId == "Hub" then self.Services.MapService:GetHubSpawn() else self.Services.ZoneService:GetSpawn(zoneId)
	character:PivotTo(spawn + Vector3.new(0, 4, 0))
	return "Телепорт: " .. zoneId
end

function Commands.Heal(self, target, d)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	target:SetAttribute("Awakening", GameConfig.Awakening.Max)
	return "Здоровье и пробуждение восстановлены"
end

function Commands.God(self, target, d)
	local on = not target:GetAttribute("God")
	target:SetAttribute("God", on)
	if target.Character then
		target.Character:SetAttribute("God", on)
	end
	return if on then "Бессмертие ВКЛ" else "Бессмертие ВЫКЛ"
end

function Commands.Boss(self, target, d)
	local zoneId = target:GetAttribute("Zone") or "Hub"
	local ok = self.Services.MobService:SpawnBossNow(zoneId)
	return if ok then "Босс призван" else "В этой локации нет босса"
end

function Commands.ServerLuck(self, target, d, amount)
	local now = workspace:GetServerTimeNow()
	local base = math.max(workspace:GetAttribute("ServerLuckUntil") or 0, now)
	workspace:SetAttribute("ServerLuckUntil", base + math.max(1, amount) * 60)
	return ("Удача сервера x2 +%d мин"):format(math.max(1, amount))
end

function Commands.StoryNext(self, target, d)
	d.Quests.Chain.Step += 1
	d.Quests.Chain.Progress = 0
	self.Services.QuestService:CheckChain(target)
	return ("История: глава %d"):format(d.Quests.Chain.Step)
end

function Commands.ResetQuests(self, target, d)
	for _, kind in { "Daily", "Weekly", "Monthly" } do
		d.Quests[kind].Period = 0
	end
	self.Services.QuestService:EnsurePeriods(d, target.UserId)
	return "Квесты обновлены"
end

function Commands.ResetStats(self, target, d)
	for _, stat in Prog.Stats do
		d.Stats[stat.Id] = 0
	end
	self.Services.ProgressionService:RecountStatPoints(d)
	self.Services.ProgressionService:ApplyCharacterStats(target)
	return "Статы сброшены бесплатно"
end

function Commands.Wipe(self, target, d)
	d.Shards, d.Spins, d.Level, d.Xp = 0, GameConfig.StarterSpins, 1, 0
	d.OwnedStyles = { [GameConfig.StarterStyle] = true }
	d.EquippedStyle = GameConfig.StarterStyle
	d.Mastery, d.Inventory, d.Buffs = {}, {}, {}
	d.Stats = { Strength = 0, Vitality = 0, Agility = 0, Spirit = 0 }
	d.Quests.Chain = { Step = 1, Progress = 0 }
	self.Services.ProgressionService:RecountStatPoints(d)
	self.Services.ProgressionService:ApplyCharacterStats(target)
	self.Services.CombatService:ApplyStyleAttributes(target)
	return "Прогресс игрока сброшен"
end

function AdminService:Run(caller: Player, command, targetName, amount, extra)
	if not isAdmin(caller) then
		return { Ok = false, Message = "Нет доступа." }
	end
	local handler = type(command) == "string" and Commands[command]
	if not handler then
		return { Ok = false, Message = "Неизвестная команда." }
	end
	local target = findTarget(caller, targetName)
	if not target then
		return { Ok = false, Message = "Игрок не найден." }
	end
	local profile = self.Services.DataService:Get(target)
	if not profile then
		return { Ok = false, Message = "Данные игрока ещё загружаются." }
	end
	amount = math.clamp(math.floor(tonumber(amount) or 0), -1e9, 1e9)
	local ok, result = pcall(handler, self, target, profile.Data, amount, extra)
	if not ok then
		warn("[Admin] " .. tostring(result))
		return { Ok = false, Message = "Ошибка: " .. tostring(result) }
	end
	self.Services.DataService:Sync(target)
	print(("[Admin] %s -> %s: %s %s %s"):format(caller.Name, target.Name, command, tostring(amount), tostring(extra)))
	return { Ok = true, Message = ("%s (%s)"):format(result, target.DisplayName) }
end

function AdminService:Start()
	Remotes.Admin.OnServerInvoke = function(player, command, targetName, amount, extra)
		return self:Run(player, command, targetName, amount, extra)
	end
end

return AdminService
