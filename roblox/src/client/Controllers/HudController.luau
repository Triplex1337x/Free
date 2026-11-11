-- Main HUD in an anime / fighting-game style: player card with avatar,
-- slanted HP / awakening bars, skill cards with mastery locks and cooldowns,
-- combo counter, menu, panels, toasts, kill feed and mobile buttons.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Styles = require(Shared.Config.Styles)
local GameConfig = require(Shared.Config.Game)
local Prog = require(Shared.Config.Progression)
local Zones = require(Shared.Config.Zones)
local Gacha = require(Shared.Gacha)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Input = require(script.Parent.InputController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local Hud = {}
Hud.Panels = {}

local cooldownEnd: { [string]: number } = {}
local cooldownTotal: { [string]: number } = {}
local slots = {}
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function formatNumber(n: number): string
	if n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end
Hud.FormatNumber = formatNumber

function Hud.RarityColor(rarityId: string): Color3
	return Gacha.GetRarity(rarityId).Color
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------

function Hud:CreatePanel(title: string, maxSize: Vector2)
	local frame = UI.new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.82),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = self.Gui,
	}, {
		UI.corner(14),
		UI.gradientStroke(Theme.Accent, Theme.Accent2, 4),
		UI.new("UISizeConstraint", { MaxSize = maxSize }),
		UI.new("UIGradient", { Color = ColorSequence.new(Theme.PanelLight, Theme.Background), Rotation = 110 }),
	})
	-- Diagonal speed-line pattern across the panel background.
	for i = 1, 6 do
		UI.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.15 + i * 0.14, 0.5),
			Size = UDim2.new(0, 10 + (i % 3) * 8, 1.6, 0),
			Rotation = 25,
			Parent = frame,
		})
	end
	frame.ClipsDescendants = false
	local scale = UI.new("UIScale", { Parent = frame })

	UI.ribbon({
		Text = string.upper(title),
		Size = UDim2.fromOffset(320, 50),
		Position = UDim2.fromOffset(-14, -22),
		ZIndex = 25,
		Parent = frame,
	})

	local content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 1, -60),
		ZIndex = 21,
		Parent = frame,
	})

	local panel = { Frame = frame, Content = content, OnOpen = nil }
	function panel.Open()
		for _, other in Hud.Panels do
			if other ~= panel then
				other.Close()
			end
		end
		self.Dim.Visible = true
		frame.Visible = true
		scale.Scale = 0.8
		frame.Rotation = -3
		UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.tween(frame, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
		if panel.OnOpen then
			task.spawn(panel.OnOpen)
		end
	end
	function panel.Close()
		frame.Visible = false
		local anyOpen = false
		for _, p in Hud.Panels do
			if p.Frame.Visible then
				anyOpen = true
			end
		end
		self.Dim.Visible = anyOpen
	end
	function panel.Toggle()
		if frame.Visible then
			panel.Close()
		else
			panel.Open()
		end
	end

	local close = UI.button({
		Text = "X",
		Color = Theme.Bad,
		Radius = 22,
		Size = UDim2.fromOffset(44, 44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Parent = frame,
		OnClick = panel.Close,
	})
	close.ZIndex = 26

	table.insert(self.Panels, panel)
	return panel
end

function Hud:CloseAll()
	for _, p in self.Panels do
		p.Close()
	end
end

local MENU_ICONS = { Roll = "✦", Arts = "⚔", Stats = "▲", Map = "◈", Quests = "!", Shop = "$", Codes = "#" }

function Hud:AddMenuButton(text: string, color: Color3, order: number, onClick: () -> ())
	local button = UI.button({
		Text = (MENU_ICONS[text] or "•") .. " " .. string.upper(text),
		Color = color,
		Size = UDim2.new(1, 0, 0, if isTouch then 40 else 46),
		LayoutOrder = order,
		Rotation = -3,
		MaxTextSize = 22,
		Parent = self.Menu,
		OnClick = onClick,
	})
	return button
end

---------------------------------------------------------------------------
-- Toasts / kill feed / combo
---------------------------------------------------------------------------

local toastKinds = {
	success = { Theme.Good, Color3.fromRGB(40, 160, 90) },
	error = { Theme.Bad, Color3.fromRGB(150, 30, 60) },
	info = { Theme.Accent2, Color3.fromRGB(60, 90, 200) },
	level = { Theme.Gold, Color3.fromRGB(255, 120, 40) },
	kill = { Theme.Accent, Color3.fromRGB(150, 40, 200) },
}

function Hud:Toast(text: string, kind: string?)
	local colors = toastKinds[kind or "info"] or toastKinds.info
	local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(460, 44), Parent = self.Toasts })
	local ribbon = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(-1.2, 0),
		Rotation = -2,
		Parent = holder,
	}, {
		UI.new("UIGradient", { Color = ColorSequence.new(colors[2], colors[1]) }),
		UI.new("UIStroke", { Color = Theme.Ink, Thickness = 3 }),
	})
	UI.label({ Text = text, Font = Theme.FontHeavy, MaxTextSize = 20, Outline = 2, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), Parent = ribbon })
	UI.tween(ribbon, 0.3, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	task.delay(3.6, function()
		UI.tween(ribbon, 0.25, { Position = UDim2.fromScale(1.3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.3)
		holder:Destroy()
	end)
end

function Hud:KillFeed(killer: string, victim: string)
	local row = UI.label({
		Text = ("%s  ⚔  %s"):format(killer, victim),
		Font = Theme.FontHeavy,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 20,
		Parent = self.Feed,
	})
	task.delay(6, function()
		row:Destroy()
	end)
	local labels = {}
	for _, child in self.Feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > 5 then
		labels[1]:Destroy()
	end
end

local comboCount, comboToken = 0, 0
function Hud:AddHit(damage: number)
	comboCount += 1
	comboToken += 1
	local token = comboToken
	local label = self.Combo
	label.Visible = true
	label.Text = ("%d HITS"):format(comboCount)
	label.TextColor3 = if comboCount >= 20 then Theme.Accent elseif comboCount >= 10 then Theme.Gold else Theme.Text
	label.Rotation = math.random(-8, 4)
	self.ComboScale.Scale = 1.5
	UI.tween(self.ComboScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	self.ComboDamage.Text = ("+%d"):format(damage)
	task.delay(1.8, function()
		if comboToken == token then
			comboCount = 0
			label.Visible = false
		end
	end)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

function Hud:BuildPlayerCard()
	local card = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(300, 112),
		Rotation = -1.5,
		Parent = self.Gui,
	}, {
		UI.corner(12),
		UI.new("UIGradient", { Color = ColorSequence.new(Theme.PanelLight, Theme.Background), Rotation = 90 }),
		UI.gradientStroke(Theme.Accent, Theme.Accent2, 3),
	})

	-- Avatar portrait with a glowing ring.
	local portrait = UI.new("ImageLabel", {
		BackgroundColor3 = Theme.Background,
		Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(player.UserId),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(78, 78),
		Parent = card,
	}, { UI.corner(39), UI.gradientStroke(Theme.Gold, Theme.Accent, 4) })
	local badge = UI.new("Frame", {
		BackgroundColor3 = Theme.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(46, 26),
		Rotation = -6,
		Parent = portrait,
	}, { UI.corner(6), UI.stroke(Theme.Ink, 3) })
	local levelText = UI.label({ Text = "1", Font = Theme.FontHeavy, MaxTextSize = 20, Parent = badge })

	UI.label({
		Text = player.DisplayName,
		Font = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Position = UDim2.fromOffset(100, 8),
		Size = UDim2.new(1, -110, 0, 26),
		Parent = card,
	})
	local _, setXp = UI.bar({ Color = Theme.Gold, Size = UDim2.new(1, -112, 0, 16), Position = UDim2.fromOffset(100, 38), MaxTextSize = 12, Parent = card })

	local pills = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(100, 62),
		Size = UDim2.new(1, -110, 0, 40),
		Parent = card,
	}, { UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }) })
	local function pill(color: Color3, width: number)
		local p = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(width, 26), Parent = pills }, { UI.corner(13), UI.stroke(Theme.Ink, 2) })
		return UI.label({ Text = "", Font = Theme.FontHeavy, MaxTextSize = 15, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), Parent = p })
	end
	local shards = pill(Color3.fromRGB(40, 140, 220), 92)
	local spins = pill(Color3.fromRGB(220, 50, 130), 84)

	-- "Stat points available" alert under the card.
	local points = UI.button({
		Text = "",
		Color = Theme.Gold,
		Size = UDim2.fromOffset(230, 34),
		Position = UDim2.fromOffset(20, 132),
		Rotation = -2,
		MaxTextSize = 18,
		Parent = self.Gui,
		OnClick = function()
			if self.OpenStats then
				self.OpenStats()
			end
		end,
	})
	points.Visible = false
	task.spawn(function()
		while true do
			if points.Visible then
				UI.tween(points, 0.4, { Rotation = 1 }, Enum.EasingStyle.Sine)
				task.wait(0.4)
				UI.tween(points, 0.4, { Rotation = -3 }, Enum.EasingStyle.Sine)
			end
			task.wait(0.4)
		end
	end)

	-- Current zone tag.
	local zoneTag = UI.label({
		Text = "",
		Font = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Position = UDim2.fromOffset(22, 172),
		Size = UDim2.fromOffset(300, 22),
		Parent = self.Gui,
	})
	local function updateZone()
		local zoneId = player:GetAttribute("Zone") or "Hub"
		local zone = Zones.Get(zoneId)
		if not zone then
			return
		end
		local tag = ""
		if zone.Pvp then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local generated = workspace:FindFirstChild("Arena") and workspace.Arena:GetAttribute("Generated")
			if State.Data and State.Data.Level < Zones.HubSafe.NewbieLevel then
				tag = ("  •  SAFE UNTIL LV.%d"):format(Zones.HubSafe.NewbieLevel)
			elseif generated and root and Zones.IsHubSafe(root.Position) then
				tag = "  •  SAFE ZONE"
			else
				tag = "  •  ⚔ PVP"
			end
		else
			tag = "  •  PVE"
		end
		zoneTag.Text = "◈ " .. string.upper(zone.Name) .. tag
		zoneTag.TextColor3 = zone.Color
	end
	task.spawn(function()
		while true do
			updateZone()
			task.wait(0.4)
		end
	end)

	-- Playtime gift countdown.
	local gift = UI.label({
		Text = "",
		Font = Theme.FontHeavy,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Position = UDim2.fromOffset(22, 196),
		Size = UDim2.fromOffset(320, 20),
		Parent = self.Gui,
	})
	task.spawn(function()
		while true do
			local at = player:GetAttribute("NextGiftAt")
			if at then
				local left = math.max(0, math.floor(at - workspace:GetServerTimeNow()))
				gift.Text = ("🎁 GIFT IN %d:%02d — %s"):format(left // 60, left % 60, player:GetAttribute("NextGiftText") or "")
			else
				gift.Text = ""
			end
			task.wait(1)
		end
	end)

	State.Observe(function(d)
		levelText.Text = tostring(d.Level)
		setXp(d.Xp / math.max(1, d.XpNeeded), ("%s / %s XP"):format(formatNumber(d.Xp), formatNumber(d.XpNeeded)))
		shards.Text = "◆ " .. formatNumber(d.Shards)
		spins.Text = "✦ " .. tostring(d.Spins)
		points.Visible = (d.StatPoints or 0) > 0
		points.Text = ("▲ %d STAT POINTS!"):format(d.StatPoints or 0)
	end)
end

function Hud:BuildCombat()
	local bottom = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(470, 172),
		Parent = self.Gui,
	})

	local hpFrame, setHealth, healthFill = UI.bar({ Color = Theme.Good, Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 0), MaxTextSize = 18, Parent = bottom })
	hpFrame.Rotation = -1.5
	UI.label({ Text = "HP", Font = Theme.FontHeavy, MaxTextSize = 24, Outline = 3, Size = UDim2.fromOffset(40, 30), Position = UDim2.fromOffset(-22, -2), TextColor3 = Theme.Good, ZIndex = 4, Parent = hpFrame })
	local awFrame, setAwaken, awakenFill = UI.bar({ Color = Theme.Accent, Size = UDim2.new(1, -80, 0, 14), Position = UDim2.fromOffset(40, 32), MaxTextSize = 12, Parent = bottom })
	awFrame.Rotation = -1.5
	local shimmer = UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 20,
	})
	local shine = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 2, BackgroundTransparency = 0, Parent = awakenFill }, { shimmer })

	local row = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 108),
		Parent = bottom,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for i, key in { "Q", "E", "R", "G" } do
		local slot = UI.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(98, 100),
			Rotation = -4,
			LayoutOrder = i,
			ClipsDescendants = true,
			Parent = row,
		}, { UI.corner(10) })
		local gradient = UI.new("UIGradient", { Rotation = 90, Parent = slot })
		local stroke = UI.stroke(Theme.Ink, 3)
		stroke.Parent = slot
		local keyBadge = UI.new("Frame", { BackgroundColor3 = Theme.Ink, Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = slot }, { UI.corner(13) })
		UI.label({ Text = if isTouch then "" else key, Font = Theme.FontHeavy, MaxTextSize = 18, ZIndex = 4, Parent = keyBadge })
		keyBadge.Visible = not isTouch
		local glyph = UI.label({ Text = "", Font = Theme.FontHeavy, MaxTextSize = 38, Outline = 3, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 10), ZIndex = 3, Parent = slot })
		local name = UI.label({ Text = "", Font = Theme.FontHeavy, Size = UDim2.new(1, -10, 0, 34), Position = UDim2.new(0, 5, 1, -40), TextWrapped = true, MaxTextSize = 15, ZIndex = 3, Parent = slot })
		local overlay = UI.new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.3,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			ZIndex = 5,
			Parent = slot,
		})
		local timer = UI.label({ Text = "", Font = Theme.FontHeavy, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 18), MaxTextSize = 34, Outline = 3, ZIndex = 6, Parent = slot })
		local lock = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), ZIndex = 7, Visible = false, Parent = slot })
		local lockText = UI.label({ Text = "", Font = Theme.FontHeavy, MaxTextSize = 15, TextWrapped = true, TextColor3 = Theme.SubText, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), ZIndex = 8, Parent = lock })
		local scale = UI.new("UIScale", { Parent = slot })
		slot.Activated:Connect(function()
			UI.tween(scale, 0.05, { Scale = 0.9 })
			task.delay(0.05, function()
				UI.tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
			Input.Ability(key)
		end)
		slots[key] = { Frame = slot, Gradient = gradient, Glyph = glyph, Name = name, Overlay = overlay, Timer = timer, Stroke = stroke, Lock = lock, LockText = lockText, Scale = scale }
	end

	local ELEMENT_GLYPH = { Fire = "炎", Water = "水", Wind = "風", Earth = "岩", Lightning = "雷", Void = "虚", Light = "光" }

	State.Observe(function(d)
		local style = Styles.Get(d.EquippedStyle)
		if not style then
			return
		end
		local h, s, v = style.Color:ToHSV()
		local dark = Color3.fromHSV(h, math.min(1, s + 0.2), v * 0.45)
		for key, slot in slots do
			local ability = Styles.GetAbility(d.EquippedStyle, key)
			slot.Name.Text = ability and ability.Name or ""
			slot.Glyph.Text = if key == "G" then "覚" else (ELEMENT_GLYPH[style.Element] or "技")
			slot.Gradient.Color = if key == "G" then ColorSequence.new(Theme.Gold, Color3.fromRGB(150, 60, 20)) else ColorSequence.new(style.Color, dark)
			local unlocked = Prog.IsUnlocked(d, d.EquippedStyle, key)
			slot.Lock.Visible = not unlocked
			slot.LockText.Text = ("🔒\nMASTERY %d"):format(Prog.Mastery.Unlocks[key])
		end
		awakenFill.BackgroundColor3 = style.Color
	end)

	local function bindHumanoid(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local function update()
			local ratio = humanoid.Health / math.max(1, humanoid.MaxHealth)
			setHealth(ratio, ("%d / %d"):format(math.ceil(humanoid.Health), math.floor(humanoid.MaxHealth)))
			healthFill.BackgroundColor3 = if ratio > 0.5 then Theme.Good elseif ratio > 0.25 then Theme.Gold else Theme.Bad
		end
		humanoid.HealthChanged:Connect(update)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
		update()
	end
	if player.Character then
		task.spawn(bindHumanoid, player.Character)
	end
	player.CharacterAdded:Connect(bindHumanoid)

	local function updateAwakening()
		local value = player:GetAttribute("Awakening") or 0
		local max = GameConfig.Awakening.Max
		local ready = value >= max
		local percent = math.floor(value / max * 100)
		setAwaken(value / max, if ready then "★ AWAKENING READY — PRESS G ★" else ("AWAKENING %d%%"):format(percent))
		local g = slots.G
		g.Overlay.Size = UDim2.fromScale(1, 1 - value / max)
		g.Timer.Text = if ready then "" else ("%d%%"):format(percent)
	end
	player:GetAttributeChangedSignal("Awakening"):Connect(updateAwakening)
	updateAwakening()

	Remotes.Cooldown.OnClientEvent:Connect(function(key, duration)
		cooldownEnd[key] = os.clock() + duration
		cooldownTotal[key] = duration
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for key, slot in slots do
			if key ~= "G" then
				local remaining = (cooldownEnd[key] or 0) - now
				if remaining > 0 then
					slot.Overlay.Size = UDim2.fromScale(1, remaining / cooldownTotal[key])
					slot.Timer.Text = ("%.1f"):format(remaining)
				elseif slot.Timer.Text ~= "" then
					slot.Overlay.Size = UDim2.fromScale(1, 0)
					slot.Timer.Text = ""
					-- "Ready" pop.
					slot.Scale.Scale = 1.15
					UI.tween(slot.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end
		end
		local ready = (player:GetAttribute("Awakening") or 0) >= GameConfig.Awakening.Max
		slots.G.Stroke.Color = if ready then Theme.Gold else Theme.Ink
		slots.G.Stroke.Thickness = if ready then 4 + math.sin(now * 8) * 1.5 else 3
		shimmer.Offset = Vector2.new(((now * 0.8) % 2) - 1, 0)
		shine.Visible = ready
	end)

	if isTouch then
		self:BuildTouchButtons()
	end
end

function Hud:BuildCombo()
	local label = UI.label({
		Text = "",
		Font = Theme.FontHeavy,
		MaxTextSize = 56,
		Outline = 4,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.42, 0),
		Size = UDim2.fromOffset(300, 70),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = self.Gui,
	})
	self.ComboScale = UI.new("UIScale", { Parent = label })
	self.ComboDamage = UI.label({ Text = "", Font = Theme.FontHeavy, MaxTextSize = 26, TextColor3 = Theme.Gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, 0, 0, 30), Parent = label })
	self.Combo = label
end

function Hud:BuildTouchButtons()
	local attack = UI.button({
		Text = "HIT",
		Color = Theme.Accent,
		Radius = 50,
		Size = UDim2.fromOffset(100, 100),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, -180),
		MaxTextSize = 32,
		Parent = self.Gui,
	})
	attack.MouseButton1Down:Connect(function()
		Input.SetHoldingAttack(true)
	end)
	attack.MouseButton1Up:Connect(function()
		Input.SetHoldingAttack(false)
	end)
	attack.MouseLeave:Connect(function()
		Input.SetHoldingAttack(false)
	end)

	local block = UI.button({
		Text = "BLOCK",
		Color = Theme.Accent2,
		Radius = 40,
		Size = UDim2.fromOffset(78, 78),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -146, 1, -160),
		MaxTextSize = 18,
		Parent = self.Gui,
	})
	block.MouseButton1Down:Connect(function()
		Input.SetBlock(true)
	end)
	block.MouseButton1Up:Connect(function()
		Input.SetBlock(false)
	end)
	block.MouseLeave:Connect(function()
		Input.SetBlock(false)
	end)
end

function Hud:BuildServerLuck()
	local banner = UI.ribbon({
		Text = "",
		ColorA = Theme.Gold,
		ColorB = Color3.fromRGB(255, 120, 40),
		Size = UDim2.fromOffset(340, 36),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 22,
		Parent = self.Gui,
	})
	banner.Visible = false
	local text = banner:FindFirstChildOfClass("TextLabel")
	task.spawn(function()
		while true do
			local remaining = math.floor((workspace:GetAttribute("ServerLuckUntil") or 0) - workspace:GetServerTimeNow())
			if remaining > 0 then
				banner.Visible = true
				text.Text = ("★ x2 SERVER LUCK  %d:%02d ★"):format(remaining // 60, remaining % 60)
			else
				banner.Visible = false
			end
			task.wait(0.5)
		end
	end)
end

function Hud:SetupChatTags()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		if not source then
			return nil
		end
		local sender = Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("Pass_VIP") then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = '<font color="#FFD23C">[VIP]</font> ' .. message.PrefixText
			return props
		end
		return nil
	end
end

function Hud:Init()
	self.Gui = UI.new("ScreenGui", {
		Name = "RiftHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Dims the game behind open panels; click to close.
	self.Dim = UI.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 15,
		Parent = self.Gui,
	})
	self.Dim.Activated:Connect(function()
		self:CloseAll()
	end)

	self.Menu = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.56, 0),
		Size = UDim2.fromOffset(if isTouch then 120 else 150, 400),
		Parent = self.Gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	self.Toasts = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54),
		Size = UDim2.fromOffset(460, 240),
		ClipsDescendants = false,
		Parent = self.Gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

	self.Feed = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 60),
		Size = UDim2.fromOffset(320, 170),
		Parent = self.Gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

	self:BuildPlayerCard()
	self:BuildCombat()
	self:BuildCombo()
	self:BuildServerLuck()
	self:SetupChatTags()

	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		self:Toast(text, kind)
	end)
end

return Hud
