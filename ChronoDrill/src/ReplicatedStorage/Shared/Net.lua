-- Net: создание и получение RemoteEvent/RemoteFunction в ReplicatedStorage.Remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"MineBlock",      -- c->s: удар по блоку
	"HitResult",      -- s->c: результат удара (урон, крит)
	"BlockBroken",    -- s->c: блок сломан (для VFX)
	"SystemAlert",    -- s->c: баннеры вайпа, уведомления
	"DataSync",       -- s->c: снимок данных игрока
	"TeleportBase",   -- c->s: каст телепорта на базу
	"Notify",         -- s->c: тосты
	"CoinsGained",    -- s->c: всплывающие монеты
	"Tutorial",       -- c->s: шаг обучения новичка
	"SaveSettings",   -- c->s: настройки (графика, громкость)
}

local FUNCTIONS = {
	"SellBackpack", "OpenEgg", "UseBoost",
	"BuyItem", "EquipItem", "PetAction",
	"Incubator", "ClaimQuest", "Rebirth", "BuyPerk", "Travel", "RequestSync",
	"ClaimDaily", "SpinWheel", "AdminCommand", "BuyPetStorage",
}

local Net = {}
local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(EVENTS) do
			if not folder:FindFirstChild(name) then
				local r = Instance.new("RemoteEvent")
				r.Name = name
				r.Parent = folder
			end
		end
		for _, name in ipairs(FUNCTIONS) do
			if not folder:FindFirstChild(name) then
				local r = Instance.new("RemoteFunction")
				r.Name = name
				r.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder
end

function Net.Init()
	getFolder()
end

function Net.Get(name)
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name)
	end
	return f:WaitForChild(name)
end

return Net
