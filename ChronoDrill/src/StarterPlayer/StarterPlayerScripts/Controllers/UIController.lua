-- UIController: собирает все экраны (HUD, InventoryGui, EggOpeningGui, QuestTracker),
-- масштабирует их под экран (ПК / телефон / консоль) и связывает с сервером.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UI = require(UIFolder:WaitForChild("UIKit"))
local HUD = require(UIFolder:WaitForChild("HUD"))
local QuestPanel = require(UIFolder:WaitForChild("QuestPanel"))
local Panels = require(UIFolder:WaitForChild("Panels"))
local EggOpening = require(UIFolder:WaitForChild("EggOpening"))
local TutorialGuide = require(UIFolder:WaitForChild("TutorialGuide"))
local SettingsPanel = require(UIFolder:WaitForChild("SettingsPanel"))
local AdminConsole = require(UIFolder:WaitForChild("AdminConsole"))
local AdminPanel = require(UIFolder:WaitForChild("AdminPanel"))
local CollectionService = game:GetService("CollectionService")

local ClientState = require(script.Parent.ClientState)
local Sound = require(script.Parent.SoundController)
local Settings = require(script.Parent.SettingsController)

local UIController = {}
local player = Players.LocalPlayer

-- Адаптивный масштаб: весь интерфейс свёрстан в "эталонных" координатах (1280x720 для HUD,
-- 1000x620 для окон). Масштаб = min(ширина/эталон, высота/эталон) по РЕАЛЬНОЙ области
-- ScreenGui (без верхней панели Roblox и вырезов экрана), поэтому на любом устройстве
-- всё помещается целиком и ничего не уезжает за край.
local scales = {}
local function computeScale(entry)
	local size = entry.gui and entry.gui.AbsoluteSize or Vector2.zero
	if size.X < 50 or size.Y < 50 then
		local cam = workspace.CurrentCamera
		size = cam and cam.ViewportSize or Vector2.new(1280, 720)
	end
	return math.clamp(math.min(size.X / entry.w, size.Y / entry.h), 0.3, 1.6)
end
local function updateScales()
	for _, e in ipairs(scales) do
		e.sc.Scale = computeScale(e)
	end
end

local function registerScale(sc, gui, w, h)
	table.insert(scales, { sc = sc, gui = gui, w = w or 1280, h = h or 720 })
	if gui then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScales)
	end
	updateScales()
end

local function screen(name, order, refW, refH)
	local g = UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 1,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- не залезать под вырез/скругления экрана на телефонах
	pcall(function()
		g.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	-- контейнер масштабируется целиком, оставаясь на весь экран
	local holder = UI.new("Frame", { Name = "Scaled", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = g })
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	registerScale(sc, g, refW, refH)
	return g, holder, sc
end

function UIController.Init(PetFollow)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	UI.SetClickSound(function()
		Sound.Play("Click", 0.05)
	end)

	pcall(function()
		player:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end)
	-- на сенсорных экранах эталон меньше => элементы крупнее и удобнее для пальцев
	local touchUi = UI.IsTouch()
	local refW, refH = 1280, 720
	if touchUi then
		refW, refH = 1150, 650
	end
	local hudGui, hudRoot, hudScale = screen("HUD", 1, refW, refH)
	local invGui, invRoot = screen("InventoryGui", 5, 1000, 620)

	-- UIScale уменьшает и размер контейнера, поэтому компенсируем его
	local function fixHolder(holder, sc)
		local function f()
			holder.Size = UDim2.fromScale(1 / sc.Scale, 1 / sc.Scale)
		end
		sc:GetPropertyChangedSignal("Scale"):Connect(f)
		f()
	end
	for _, g in ipairs({ hudGui, invGui }) do
		local h = g:FindFirstChild("Scaled")
		fixHolder(h, h:FindFirstChildOfClass("UIScale"))
	end

	local ctx = {}
	ctx.ClientState = ClientState
	ctx.Sound = Sound
	ctx.Settings = Settings
	ctx.PlayerGui = player.PlayerGui
	ctx.PetModel = function(id, golden)
		return PetFollow.DisplayModel(id, golden)
	end
	ctx.RegisterScale = registerScale

	local hud = HUD.Build(hudRoot, ctx)
	ctx.Toast = hud.Toast
	local panels
	ctx.OpenPanel = function(name)
		if not panels then
			return
		end
		for k, w in pairs(panels) do
			if k ~= name and w.IsOpen then
				w.Hide()
			end
		end
		local w = panels[name]
		if w then
			w.Toggle()
		end
	end
	ctx.PlayEgg = function(eggId, pets, opts)
		EggOpening.Play(eggId, pets, opts)
	end
	ctx.ShowHatch = function(pet)
		EggOpening.Hatch(pet)
	end
	panels = Panels.Build(invRoot, ctx)
	panels.Settings = SettingsPanel.Build(invRoot, ctx)
	EggOpening.Build(ctx)
	AdminConsole.Build(hudRoot, ctx)
	panels.Admin = AdminPanel.Build(invRoot, ctx)
	-- выбор графики при первом входе (обучение ждёт, пока игрок выберет)
	ctx.GraphicsChosen = false
	task.spawn(function()
		ClientState.Wait()
		local s = Settings.Get()
		if s.Quality == "" then
			SettingsPanel.Chooser(invRoot, ctx, function()
				ctx.GraphicsChosen = true
			end)
		else
			ctx.GraphicsChosen = true
		end
	end)
	local tutorial = TutorialGuide.Build(hud, ctx, panels)

	updateScales()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)

	-- данные
	ClientState.Changed:Connect(function(data)
		hud.Refresh(data)
		local now = ClientState.ServerNow()
		local ready = false
		for i = 1, 3 do
			local s = data.Incubator and data.Incubator[tostring(i)]
			if s and s.Seed and (now - s.Planted) >= (s.Duration - (s.Cut or 0)) then
				ready = true
			end
		end
		hud.MenuButtons.Incubator.Badge.Visible = ready
		hud.MenuButtons.Rebirth.Badge.Visible = data.Derived and data.Derived.CanRebirth or false
		-- бейдж у «Заданий» + тост, когда что-то стало можно забрать
		local claimable = QuestPanel.Claimable(data)
		hud.SetBadge("Quests", claimable > 0)
		if claimable > (UIController._lastClaimable or 0) then
			hud.Toast("Задание выполнено! Открой «Задания», чтобы забрать награду", "good")
		end
		UIController._lastClaimable = claimable
	end)

	-- сервер -> клиент
	Net.Get("Notify").OnClientEvent:Connect(function(text, kind, sound)
		hud.Toast(text, kind)
		if sound then
			Sound.Play(sound, 0.05)
		end
	end)
	Net.Get("CoinsGained").OnClientEvent:Connect(function(amount)
		hud.CoinPop(amount)
		Sound.Play("Coins", 0.08)
	end)
	Net.Get("SystemAlert").OnClientEvent:Connect(function(kind, payload)
		payload = payload or {}
		if kind == "ResetWarn" then
			if payload.Level == 2 then
				hud.Banner("ВАЙП ШАХТЫ ЧЕРЕЗ 10 СЕКУНД! ВЫБИРАЙСЯ!", UI.Colors.Red, 10, true)
				Sound.Play("Siren")
				task.delay(1, function()
					Sound.Play("Siren")
				end)
			else
				hud.Banner("Шахта восстановится через 30 секунд", UI.Colors.Yellow, 5, false)
				Sound.Play("Warning")
			end
		elseif kind == "Reset" then
			hud.Banner("Шахта восстановлена! Новые Хроно-Жилы ждут!", UI.Colors.Green, 3.5, false)
			Sound.Play("Unlock")
		elseif kind == "GoldRush" then
			hud.Banner("ЗОЛОТАЯ ЛИХОРАДКА: x2 Жилы и Семена на 3 минуты!", UI.Colors.Yellow, 4, true)
		elseif kind == "Unlock" then
			hud.Banner("ШЛЮЗ ОТКРЫТ: " .. string.upper(payload.Name or ""), UI.Colors.Purple, 4.5, true)
			Sound.Play("Unlock")
		elseif kind == "Rebirth" then
			hud.Banner("ПЕРЕРОЖДЕНИЕ #" .. tostring(payload.Rebirths) .. "!", UI.Colors.Pink, 4.5, true)
			Sound.Play("Unlock")
		elseif kind == "Teleported" then
			local f = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(150, 255, 240), BackgroundTransparency = 0.2, Size = UDim2.fromScale(1, 1), ZIndex = 100, Parent = hudGui })
			TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
			task.delay(0.5, function()
				f:Destroy()
			end)
			Sound.Play("Teleport", 0.05)
		end
	end)

	-- ProximityPrompt -> окна
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("Action")
		if action == "Egg" then
			for k, w in pairs(panels) do
				if w.IsOpen then
					w.Hide()
				end
			end
			panels.Egg.ShowEgg(prompt:GetAttribute("EggId"))
		elseif action == "Incubator" then
			ctx.OpenPanel("Incubator")
		elseif action == "Rebirth" then
			ctx.OpenPanel("Rebirth")
		elseif action == "NPC" then
			ctx.OpenPanel("Npc")
		end
	end)

	-- горячие клавиши
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local map = {
			[Enum.KeyCode.P] = "Pets", [Enum.KeyCode.B] = "Bag", [Enum.KeyCode.M] = "Worlds", [Enum.KeyCode.R] = "Rebirth",
			[Enum.KeyCode.K] = "Stats", [Enum.KeyCode.I] = "Index", [Enum.KeyCode.Q] = "Quests", [Enum.KeyCode.J] = "Daily", [Enum.KeyCode.L] = "Wheel",
		}
		local name = map[input.KeyCode]
		if name then
			ctx.OpenPanel(name)
		end
	end)

	-- Магазины — домики с зоной покупки: окно открывается, когда зашёл в зону, и закрывается, когда вышел
	local inZone = nil
	task.spawn(function()
		while true do
			task.wait(0.15)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local found = nil
			if root then
				for _, z in ipairs(CollectionService:GetTagged("ShopZone")) do
					local rel = z.CFrame:PointToObjectSpace(root.Position)
					local half = z.Size / 2
					if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and math.abs(rel.Y) <= half.Y + 3 then
						found = z
						break
					end
				end
			end
			if found ~= inZone then
				if inZone and panels.Shop.IsOpen then
					panels.Shop.Hide()
				end
				inZone = found
				if found then
					local kind = found:GetAttribute("Kind")
					for _, w in pairs(panels) do
						if w.IsOpen then
							w.Hide()
						end
					end
					panels.Shop.SelectTab(kind == "Backpack" and 2 or 1)
					panels.Shop.Open()
					Sound.Play("Click")
				end
			end
		end
	end)
	ctx.InShopZone = function()
		return inZone ~= nil
	end

	if ClientState.Data then
		hud.Refresh(ClientState.Data)
	end
	-- при входе показываем ежедневную награду, если она готова
	-- (новичкам — после обучения, чтобы окно не перекрывало подсказки)
	local function openDailyIfReady()
		local RewardPanels = require(UIFolder:WaitForChild("RewardPanels"))
		local ready = RewardPanels.DailyState(ctx)
		local anyOpen = false
		for _, w in pairs(panels) do
			if w.IsOpen then
				anyOpen = true
			end
		end
		-- показываем, только если игрок сейчас не смотрит другое окно
		if ready and panels.Daily and not anyOpen then
			panels.Daily.Open()
		end
	end
	ctx.AfterTutorial = openDailyIfReady
	task.spawn(function()
		ClientState.Wait()
		task.wait(2.5)
		if not tutorial.IsActive() then
			openDailyIfReady()
		end
	end)
	UIController.Ctx = ctx
	UIController.Panels = panels
end

return UIController
