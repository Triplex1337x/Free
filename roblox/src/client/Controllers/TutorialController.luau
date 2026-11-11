-- First-time tutorial: 7 short steps with a guide arrow, progress and a
-- reward at the end. Skippable. Only shown until completed once.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local TutorialController = {}

local hits = 0
local skillUsed = false
local startRolls = nil

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function panelOpen(title: string): boolean
	for _, p in Hud.Panels do
		if p.Frame.Name == title and p.Frame.Visible then
			return true
		end
	end
	return false
end

local function portalTarget(): Vector3?
	local arena = workspace:FindFirstChild("Arena")
	local portal = arena and arena:FindFirstChild("PortalCore", true)
	for _, d in (arena and arena:GetDescendants() or {}) do
		if d.Name == "Portal_Ember" and d:IsA("BasePart") then
			return d.Position
		end
	end
	return portal and portal.Position
end

local STEPS = {
	{
		Text = if touch then "Двигайся джойстиком слева" else "Двигайся: W A S D, прыжок — пробел",
		Start = function(s)
			local r = root()
			s.From = r and r.Position
		end,
		Done = function(s)
			local r = root()
			return r ~= nil and s.From ~= nil and (r.Position - s.From).Magnitude > 20
		end,
	},
	{
		Text = if touch then "Подойди к манекенам и бей кнопкой УДАР (5 ударов)" else "Подойди к манекенам и бей ЛКМ (5 ударов)",
		Target = function()
			return Vector3.new(0, 4, -55)
		end,
		Start = function()
			hits = 0
		end,
		Done = function()
			return hits >= 5
		end,
		Progress = function()
			return ("%d/5"):format(math.min(hits, 5))
		end,
	},
	{
		Text = if touch then "Используй скилл: кнопка Q справа" else "Используй скилл: нажми Q",
		Start = function()
			skillUsed = false
		end,
		Done = function()
			return skillUsed
		end,
	},
	{
		Text = if touch then "Зажми БЛОК — он гасит урон" else "Зажми F — блок гасит урон. Нажатие прямо перед ударом — парирование!",
		Done = function()
			local c = player.Character
			return c ~= nil and c:GetAttribute("Blocking") == true
		end,
	},
	{
		Text = "Открой меню РОЛЛ и крути новый стиль",
		Start = function()
			startRolls = State.Data and State.Data.TotalRolls or 0
		end,
		Done = function()
			return State.Data ~= nil and (State.Data.TotalRolls or 0) > (startRolls or 0)
		end,
	},
	{
		Text = "Открой КВЕСТЫ — там история, ежедневные задания и награды",
		Done = function()
			return panelOpen("Квесты")
		end,
	},
	{
		Text = "Отправляйся в Пепельные Пустоши: подойди к порталу в воротах и нажми T",
		Target = portalTarget,
		Done = function()
			return player:GetAttribute("Zone") == "Ember"
		end,
	},
}

function TutorialController:Run()
	local gui = Hud.Gui
	local card = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 240),
		Size = UDim2.fromOffset(340, 128),
		Rotation = 1,
		Parent = gui,
	}, {
		UI.corner(12),
		UI.new("UIGradient", { Color = ColorSequence.new(Theme.PanelLight, Theme.Background), Rotation = 90 }),
		UI.gradientStroke(Theme.Gold, Theme.Accent, 3),
	})
	UI.ribbon({ Text = "ОБУЧЕНИЕ", ColorA = Theme.Gold, ColorB = Color3.fromRGB(255, 120, 40), Size = UDim2.fromOffset(170, 34), Position = UDim2.fromOffset(-10, -16), MaxTextSize = 20, Parent = card })
	local stepLabel = UI.label({ Text = "", Font = Theme.FontHeavy, TextColor3 = Theme.Gold, MaxTextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 6), Parent = card })
	local text = UI.label({ Text = "", MaxTextSize = 18, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -24, 0, 62), Position = UDim2.fromOffset(12, 28), Parent = card })
	local _, setBar = UI.bar({ Color = Theme.Gold, Size = UDim2.new(1, -120, 0, 12), Position = UDim2.new(0, 12, 1, -24), MaxTextSize = 10, Parent = card })
	local skip = UI.button({ Text = "ПРОПУСТИТЬ", Color = Theme.SubText, Size = UDim2.fromOffset(96, 28), Position = UDim2.new(1, -106, 1, -36), MaxTextSize = 12, Parent = card })
	local scale = UI.new("UIScale", { Parent = card })

	-- 3D guide: a beam from you to the target and a bouncing marker.
	local marker = Instance.new("Part")
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	local markerGui = Instance.new("BillboardGui")
	markerGui.Size = UDim2.fromOffset(120, 60)
	markerGui.AlwaysOnTop = true
	markerGui.Parent = marker
	UI.label({ Text = "▼ СЮДА", Font = Theme.FontHeavy, TextColor3 = Theme.Gold, MaxTextSize = 30, Outline = 3, Parent = markerGui })
	local a1 = Instance.new("Attachment")
	a1.Parent = marker
	local beam = Instance.new("Beam")
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Theme.Gold)
	beam.Width0, beam.Width1 = 0.6, 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.3, 0.6)
	beam.Parent = marker

	local finished = false
	skip.Activated:Connect(function()
		finished = true
	end)

	local function hitListener(kind, payload)
		if kind == "Hit" and type(payload) == "table" and payload.Attacker == player.Character then
			hits += 1
		end
	end
	local c1 = Remotes.Fx.OnClientEvent:Connect(hitListener)
	local c2 = Remotes.Cooldown.OnClientEvent:Connect(function(key)
		if key == "Q" or key == "E" or key == "R" then
			skillUsed = true
		end
	end)

	for i, step in STEPS do
		if finished then
			break
		end
		local s = {}
		if step.Start then
			step.Start(s)
		end
		stepLabel.Text = ("ШАГ %d / %d"):format(i, #STEPS)
		text.Text = step.Text
		setBar((i - 1) / #STEPS)
		scale.Scale = 1.15
		UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		while not finished and not step.Done(s) do
			local target = step.Target and step.Target()
			local r = root()
			if target and r then
				marker.Position = target + Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.6, 0)
				marker.Parent = workspace
				local a0 = r:FindFirstChild("TutorialAttachment") or Instance.new("Attachment")
				a0.Name = "TutorialAttachment"
				a0.Parent = r
				beam.Attachment0 = a0
			else
				marker.Parent = nil
			end
			if step.Progress then
				text.Text = step.Text .. "  " .. step.Progress()
			end
			RunService.Heartbeat:Wait()
		end
		if not finished then
			Hud:Toast("✔ " .. step.Text, "success")
		end
	end

	c1:Disconnect()
	c2:Disconnect()
	marker:Destroy()
	setBar(1)
	-- Completed or skipped: either way it won't show again (reward once).
	pcall(Remotes.TutorialDone.InvokeServer, Remotes.TutorialDone)
	UI.tween(card, 0.3, { Position = UDim2.new(1, 400, 0, 240) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.35)
	card:Destroy()
end

function TutorialController:Start()
	-- Wait for data and for the title screen to close.
	while not State.Data do
		task.wait(0.5)
	end
	if State.Data.TutorialDone then
		return
	end
	while not Hud.Gui.Enabled do
		task.wait(0.3)
	end
	task.wait(1)
	self:Run()
end

return TutorialController
