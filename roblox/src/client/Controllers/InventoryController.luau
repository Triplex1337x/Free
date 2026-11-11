-- Inventory (potions you own + potion shop) and the active-buff bar in the
-- bottom-left corner with hover tooltips.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Potions = require(Shared.Config.Potions)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local InventoryController = {}

local buffsLeft = {} :: { [string]: number }
local receivedAt = os.clock()

local function remaining(id: string): number
	local left = buffsLeft[id]
	if not left then
		return 0
	end
	return math.max(0, left - (os.clock() - receivedAt))
end

local function clock(seconds: number): string
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		return ("%d:%02d:%02d"):format(seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function invoke(remote, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		Hud:Toast("Что-то пошло не так, попробуй ещё раз.", "error")
		return false
	elseif not result.Ok then
		Hud:Toast(result.Error, "error")
		return false
	end
	return true
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local tooltip, tipTitle, tipBody, tipTime
local tipTarget: string? = nil

local function buildTooltip()
	tooltip = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(250, 96),
		AnchorPoint = Vector2.new(0, 1),
		Visible = false,
		ZIndex = 60,
		Parent = Hud.Gui,
	}, {
		UI.corner(10),
		UI.new("UIGradient", { Color = ColorSequence.new(Theme.PanelLight, Theme.Background), Rotation = 90 }),
		UI.gradientStroke(Theme.Accent, Theme.Accent2, 3),
	})
	tipTitle = UI.label({ Text = "", Font = Theme.FontHeavy, MaxTextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 8), ZIndex = 61, Parent = tooltip })
	tipBody = UI.label({ Text = "", MaxTextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 36), ZIndex = 61, Parent = tooltip })
	tipTime = UI.label({ Text = "", Font = Theme.FontHeavy, TextColor3 = Theme.Gold, MaxTextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 64), ZIndex = 61, Parent = tooltip })
end

local function showTip(id: string, anchor: GuiObject)
	local potion = Potions.Get(id)
	tipTarget = id
	tipTitle.Text = string.upper(potion.Name)
	tipTitle.TextColor3 = potion.Color
	tipBody.Text = potion.Description
	tooltip.Position = UDim2.fromOffset(anchor.AbsolutePosition.X, anchor.AbsolutePosition.Y - 8)
	tooltip.Visible = true
end

local function hideTip(id: string?)
	if id == nil or tipTarget == id then
		tipTarget = nil
		tooltip.Visible = false
	end
end

---------------------------------------------------------------------------
-- Active buffs bar (bottom-left)
---------------------------------------------------------------------------

function InventoryController:BuildBuffBar()
	local bar = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(420, 84),
		Parent = Hud.Gui,
	}, { UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom }) })

	local entries = {}
	local function rebuild()
		for _, e in entries do
			e.Frame:Destroy()
		end
		table.clear(entries)
		for i, id in Potions.Order do
			if remaining(id) > 0 then
				local potion = Potions.Get(id)
				local holder = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 80), LayoutOrder = i, Parent = bar })
				local icon = UI.potionIcon(potion, 52, holder)
				local scale = UI.new("UIScale", { Parent = icon })
				local track = UI.new("Frame", { BackgroundColor3 = Theme.Ink, Position = UDim2.fromOffset(2, 56), Size = UDim2.fromOffset(52, 6), Parent = holder }, { UI.corner(3) })
				local fill = UI.new("Frame", { BackgroundColor3 = potion.Color, Size = UDim2.fromScale(1, 1), Parent = track }, { UI.corner(3) })
				local time = UI.label({ Text = "", Font = Theme.FontHeavy, MaxTextSize = 14, Size = UDim2.fromOffset(56, 16), Position = UDim2.fromOffset(0, 63), Parent = holder })
				holder.MouseEnter:Connect(function()
					UI.tween(scale, 0.12, { Scale = 1.12 }, Enum.EasingStyle.Back)
					showTip(id, holder)
				end)
				holder.MouseLeave:Connect(function()
					UI.tween(scale, 0.12, { Scale = 1 })
					hideTip(id)
				end)
				holder.Activated:Connect(function() -- touch: tap to toggle the tooltip
					if tooltip.Visible and tipTarget == id then
						hideTip(id)
					else
						showTip(id, holder)
					end
				end)
				table.insert(entries, { Id = id, Frame = holder, Fill = fill, Time = time, Total = potion.Minutes * 60 })
			end
		end
	end
	State.Observe(function(d)
		buffsLeft = d.BuffsLeft or {}
		receivedAt = os.clock()
		rebuild()
	end)

	RunService.Heartbeat:Connect(function()
		local any = false
		for _, e in entries do
			local left = remaining(e.Id)
			e.Time.Text = clock(left)
			e.Fill.Size = UDim2.fromScale(math.clamp(left / math.max(e.Total, left), 0, 1), 1)
			e.Time.TextColor3 = if left < 60 then Theme.Bad else Theme.Text
			if left <= 0 then
				any = true
			end
			if tipTarget == e.Id then
				tipTime.Text = "ОСТАЛОСЬ: " .. clock(left)
			end
		end
		if any then
			rebuild()
		end
	end)
end

---------------------------------------------------------------------------
-- Inventory panel
---------------------------------------------------------------------------

function InventoryController:BuildPanel()
	local panel = Hud:CreatePanel("Зелья", Vector2.new(880, 580))
	local content = panel.Content

	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 6), Parent = content }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }),
	})
	local pages = {}
	local tabButtons = {}
	local function page()
		return UI.new("ScrollingFrame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(1, 0, 1, -60),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 5,
			Visible = false,
			Parent = content,
		}, {
			UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -10, 0, 120), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			UI.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
		})
	end
	local function select(name: string)
		for n, p in pages do
			p.Visible = n == name
			tabButtons[n].BackgroundTransparency = if n == name then 0 else 0.45
		end
	end
	for i, name in { "МОИ ЗЕЛЬЯ", "МАГАЗИН ЗЕЛИЙ" } do
		pages[name] = page()
		local button = UI.button({ Text = name, Color = if i == 1 then Theme.Accent2 else Theme.Gold, Size = UDim2.fromOffset(200, 42), Rotation = -2, MaxTextSize = 20, LayoutOrder = i, Parent = tabs, OnClick = function()
			select(name)
		end })
		tabButtons[name] = button
	end
	select("МОИ ЗЕЛЬЯ")

	local function card(parent, potion, order)
		local frame = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = parent }, {
			UI.corner(12),
			UI.new("UIGradient", { Color = ColorSequence.new(potion.Color:Lerp(Theme.Background, 0.55), Theme.Background), Rotation = 0 }),
			UI.stroke(Theme.Ink, 3),
		})
		local icon = UI.potionIcon(potion, 84, frame)
		icon.Position = UDim2.fromOffset(10, 18)
		UI.label({ Text = string.upper(potion.Name), Font = Theme.FontHeavy, TextColor3 = potion.Color, MaxTextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 0, 26), Position = UDim2.fromOffset(104, 10), Parent = frame })
		UI.label({ Text = ("%s  •  %d мин"):format(potion.Description, potion.Minutes), MaxTextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, -110, 0, 36), Position = UDim2.fromOffset(104, 36), Parent = frame })
		return frame
	end

	local mine = pages["МОИ ЗЕЛЬЯ"]
	local empty = UI.label({ Text = "Зелий пока нет — получай их за квесты, боссов и время в игре или купи в магазине!", TextColor3 = Theme.SubText, TextWrapped = true, MaxTextSize = 20, Size = UDim2.new(1, -40, 0, 80), Position = UDim2.fromOffset(20, 120), Visible = false, Parent = content })

	State.Observe(function(d)
		for _, child in mine:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local count = 0
		for i, id in Potions.Order do
			local have = d.Inventory and d.Inventory[id] or 0
			if have > 0 then
				count += 1
				local potion = Potions.Get(id)
				local frame = card(mine, potion, i)
				UI.label({ Text = "x" .. have, Font = Theme.FontHeavy, TextColor3 = Theme.Gold, MaxTextSize = 24, Outline = 3, Size = UDim2.fromOffset(60, 30), Position = UDim2.fromOffset(52, 84), Parent = frame })
				UI.button({ Text = "ВЫПИТЬ", Color = potion.Color, Size = UDim2.fromOffset(120, 40), Position = UDim2.new(1, -132, 1, -50), MaxTextSize = 18, Parent = frame, OnClick = function()
					if invoke(Remotes.UsePotion, id) then
						Hud:Toast("Действует: " .. potion.Name, "success")
					end
				end })
			end
		end
		empty.Visible = count == 0 and mine.Visible
	end)
	mine:GetPropertyChangedSignal("Visible"):Connect(function()
		local d = State.Data
		local count = 0
		for _, n in (d and d.Inventory or {}) do
			count += n
		end
		empty.Visible = mine.Visible and count == 0
	end)

	local shop = pages["МАГАЗИН ЗЕЛИЙ"]
	for i, id in Potions.Order do
		local potion = Potions.Get(id)
		local frame = card(shop, potion, i)
		UI.button({ Text = ("◆ %d"):format(potion.Price), Color = Theme.Gold, Size = UDim2.fromOffset(130, 40), Position = UDim2.new(1, -142, 1, -50), MaxTextSize = 18, Parent = frame, OnClick = function()
			if invoke(Remotes.BuyPotion, id, 1) then
				Hud:Toast("Куплено: " .. potion.Name, "success")
			end
		end })
	end

	Hud:AddMenuButton("Items", Color3.fromRGB(255, 120, 200), 6, panel.Toggle)
end

function InventoryController:Init()
	buildTooltip()
	self:BuildBuffBar()
	self:BuildPanel()
	if UserInputService.TouchEnabled then
		-- Hide the tooltip when tapping elsewhere.
		UserInputService.InputBegan:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.Touch and not processed then
				hideTip(nil)
			end
		end)
	end
end

return InventoryController
