-- Main HUD: stats, health / awakening bars, ability slots with cooldowns,
-- menu buttons, panels, toasts, kill feed, server luck timer, mobile buttons.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Styles = require(Shared.Config.Styles)
local GameConfig = require(Shared.Config.Game)
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

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

function Hud:CreatePanel(title: string, maxSize: Vector2)
	local frame = UI.new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.84),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = self.Gui,
	}, {
		UI.corner(16),
		UI.stroke(Theme.Accent, 2.5, 0.1),
		UI.new("UISizeConstraint", { MaxSize = maxSize }),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Theme.PanelLight, Theme.Panel),
			Rotation = 90,
		}),
	})
	local scale = UI.new("UIScale", { Parent = frame })
	UI.label({
		Text = title,
		Font = Theme.FontHeavy,
		TextColor3 = Theme.Text,
		Size = UDim2.new(1, -120, 0, 40),
		Position = UDim2.fromOffset(20, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		ZIndex = 21,
		Parent = frame,
	})
	local content = UI.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 1, -74),
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
		frame.Visible = true
		scale.Scale = 0.85
		UI.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		if panel.OnOpen then
			panel.OnOpen()
		end
	end
	function panel.Close()
		frame.Visible = false
	end
	function panel.Toggle()
		if frame.Visible then
			panel.Close()
		else
			panel.Open()
		end
	end

	UI.button({
		Text = "X",
		Color = Theme.Bad,
		Size = UDim2.fromOffset(36, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Parent = frame,
		OnClick = panel.Close,
	}).ZIndex = 22

	table.insert(self.Panels, panel)
	return panel
end

function Hud:AddMenuButton(text: string, color: Color3, order: number, onClick: () -> ())
	return UI.button({
		Text = text,
		Color = color,
		Size = UDim2.new(1, 0, 0, if isTouch then 44 else 50),
		LayoutOrder = order,
		Parent = self.Menu,
		OnClick = onClick,
	})
end

local toastKinds = {
	success = Theme.Good,
	error = Theme.Bad,
	info = Theme.Accent2,
	level = Theme.Gold,
	kill = Theme.Accent,
}

function Hud:Toast(text: string, kind: string?)
	local color = toastKinds[kind or "info"] or Theme.Accent2
	local toast = UI.new("Frame", {
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(380, 40),
		Parent = self.Toasts,
	}, { UI.corner(10), UI.stroke(color, 2, 0) })
	UI.label({ Text = text, TextColor3 = color, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), MaxTextSize = 20, Parent = toast })
	task.delay(3.5, function()
		UI.tween(toast, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.3)
		toast:Destroy()
	end)
end

function Hud:KillFeed(killer: string, victim: string)
	local row = UI.label({
		Text = ("%s  ⚔  %s"):format(killer, victim),
		TextColor3 = Theme.Text,
		TextStrokeTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 18,
		Parent = self.Feed,
	})
	task.delay(6, function()
		row:Destroy()
	end)
	local rows = self.Feed:GetChildren()
	local labels = {}
	for _, child in rows do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels > 5 then
		labels[1]:Destroy()
	end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

function Hud:BuildStats()
	local card = UI.new("Frame", {
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(250, 92),
		Parent = self.Gui,
	}, { UI.corner(12), UI.stroke(Theme.Accent, 2, 0.4), UI.padding(10) })

	local level = UI.label({ Text = "Lv. 1", Font = Theme.FontHeavy, TextColor3 = Theme.Gold, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local _, setXp = UI.bar({ Color = Theme.Gold, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 28), MaxTextSize = 12, Parent = card })
	local currency = UI.label({
		Text = "",
		RichText = true,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = card,
	})

	State.Observe(function(d)
		level.Text = ("Lv. %d"):format(d.Level)
		setXp(d.Xp / math.max(1, d.XpNeeded), ("%s / %s XP"):format(formatNumber(d.Xp), formatNumber(d.XpNeeded)))
		currency.Text = ('<font color="#5AC8FF">◆ %s Shards</font>   <font color="#FF5096">✦ %d Spins</font>'):format(formatNumber(d.Shards), d.Spins)
	end)
end

function Hud:BuildCombat()
	local bottom = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(420, 150),
		Parent = self.Gui,
	})

	local _, setHealth, healthFill = UI.bar({ Color = Theme.Good, Size = UDim2.new(1, 0, 0, 22), MaxTextSize = 16, Parent = bottom })
	local _, setAwaken, awakenFill = UI.bar({ Color = Theme.Accent, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 26), MaxTextSize = 11, Parent = bottom })

	local row = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 96),
		Parent = bottom,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for i, key in { "Q", "E", "R", "G" } do
		local slot = UI.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.15,
			Size = UDim2.fromOffset(92, 92),
			LayoutOrder = i,
			ClipsDescendants = true,
			Parent = row,
		}, { UI.corner(14) })
		local stroke = UI.stroke(Theme.Accent2, 2.5, 0.2)
		stroke.Parent = slot
		UI.label({ Text = if isTouch then "" else key, Font = Theme.FontHeavy, TextColor3 = Theme.SubText, Size = UDim2.fromOffset(24, 22), Position = UDim2.fromOffset(6, 4), MaxTextSize = 18, ZIndex = 3, Parent = slot })
		local name = UI.label({ Text = "", Size = UDim2.new(1, -10, 0, 40), Position = UDim2.new(0, 5, 1, -46), TextWrapped = true, MaxTextSize = 15, ZIndex = 3, Parent = slot })
		local overlay = UI.new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			ZIndex = 4,
			Parent = slot,
		})
		local timer = UI.label({ Text = "", Font = Theme.FontHeavy, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 16), MaxTextSize = 30, ZIndex = 5, Parent = slot })
		slot.Activated:Connect(function()
			Input.Ability(key)
		end)
		slots[key] = { Frame = slot, Name = name, Overlay = overlay, Timer = timer, Stroke = stroke }
	end

	State.Observe(function(d)
		local style = Styles.Get(d.EquippedStyle)
		if not style then
			return
		end
		for key, slot in slots do
			local ability = Styles.GetAbility(d.EquippedStyle, key)
			slot.Name.Text = ability and ability.Name or ""
			slot.Stroke.Color = if key == "G" then Theme.Gold else style.Color
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
		setAwaken(value / max, if ready then "AWAKENING READY — press G" else ("Awakening %d%%"):format(percent))
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
				else
					slot.Overlay.Size = UDim2.fromScale(1, 0)
					slot.Timer.Text = ""
				end
			end
		end
		local awakening = player:GetAttribute("Awakening") or 0
		if awakening >= GameConfig.Awakening.Max then
			slots.G.Stroke.Thickness = 2.5 + math.sin(now * 8) * 1.5
		else
			slots.G.Stroke.Thickness = 2.5
		end
	end)

	if isTouch then
		self:BuildTouchButtons()
	end
end

function Hud:BuildTouchButtons()
	local attack = UI.button({
		Text = "HIT",
		Color = Theme.Accent,
		Radius = 50,
		Size = UDim2.fromOffset(96, 96),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, -170),
		MaxTextSize = 28,
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
		Size = UDim2.fromOffset(76, 76),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -140, 1, -150),
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
	local banner = UI.label({
		Text = "",
		Font = Theme.FontHeavy,
		TextColor3 = Theme.Gold,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(360, 28),
		MaxTextSize = 22,
		Visible = false,
		Parent = self.Gui,
	})
	task.spawn(function()
		while true do
			local remaining = math.floor((workspace:GetAttribute("ServerLuckUntil") or 0) - workspace:GetServerTimeNow())
			if remaining > 0 then
				banner.Visible = true
				banner.Text = ("★ x2 SERVER LUCK  %d:%02d ★"):format(remaining // 60, remaining % 60)
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

	self.Menu = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(if isTouch then 110 else 130, 260),
		Parent = self.Gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	self.Toasts = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(380, 200),
		Parent = self.Gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

	self.Feed = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 60),
		Size = UDim2.fromOffset(300, 160),
		Parent = self.Gui,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

	self:BuildStats()
	self:BuildCombat()
	self:BuildServerLuck()
	self:SetupChatTags()

	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		self:Toast(text, kind)
	end)
end

function Hud.RarityColor(rarityId: string): Color3
	return Gacha.GetRarity(rarityId).Color
end

return Hud
