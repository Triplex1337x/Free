-- PassManager: геймпассы доната. Проверка владения при входе, покупка из меню «Донат»,
-- выдача/снятие админом (F2 → Геймпассы), VIP-тег над головой.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamepassesData = require(ReplicatedStorage.Configs.GamepassesData)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Net = require(ReplicatedStorage.Shared.Net)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local StateSync = require(Core.StateSync)
local Notifier = require(Core.Notifier)

local Passes = {}

local function vipTag(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("VipTag")
	local data = DataManager.Get(player)
	local on = data and Stats.HasPass(data, "VIP")
	if not on then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "VipTag"
	bb.Size = UDim2.fromOffset(90, 30)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 90
	bb.Adornee = head
	local f = Instance.new("TextLabel")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	f.Font = Enum.Font.FredokaOne
	f.TextScaled = true
	f.Text = "VIP"
	f.TextColor3 = Color3.new(1, 1, 1)
	f.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(120, 70, 10)
	s.Parent = f
	bb.Parent = head
end

local function refresh(player)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	StateSync.SetPass(player, Stats.HasPass(data, "Incubator"))
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Stats.WalkSpeed(data)
	end
	vipTag(player)
	StateSync.MarkDirty(player)
end

-- выдать / забрать геймпасс (админ или покупка)
function Passes.Set(player, key, on, silent)
	local data = DataManager.Get(player)
	local def = GamepassesData.ByKey[key]
	if not data or not def then
		return false
	end
	data.Passes = data.Passes or {}
	data.Passes[key] = on and true or nil
	refresh(player)
	if not silent then
		if on then
			Notifier.Toast(player, "Геймпасс «" .. def.Name .. "» активирован!", "unlock", "Unlock")
		else
			Notifier.Toast(player, "Геймпасс «" .. def.Name .. "» снят", "warn")
		end
	end
	return true
end

local function checkOwnership(player)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	data.Passes = data.Passes or {}
	for _, def in ipairs(GamepassesData.List) do
		local id = GamepassesData.IdOf(def.Key)
		if id ~= 0 and not data.Passes[def.Key] then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				data.Passes[def.Key] = true
			end
		end
	end
	refresh(player)
end

function Passes.Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			vipTag(player)
		end)
		task.spawn(function()
			for _ = 1, 60 do
				if DataManager.Get(player) or not player.Parent then
					break
				end
				task.wait(0.25)
			end
			checkOwnership(player)
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(checkOwnership, p)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, def in ipairs(GamepassesData.List) do
			if GamepassesData.IdOf(def.Key) == passId then
				Passes.Set(player, def.Key, true)
				Notifier.ToastAll(player.DisplayName .. " купил геймпасс «" .. def.Name .. "»!", "unlock")
			end
		end
	end)
end

return Passes
