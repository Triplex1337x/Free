-- Spirit Roll panel (odds, x1 / x10 rolls, reveal animation) and the Arts
-- panel (owned styles, equip).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Styles = require(Shared.Config.Styles)
local GachaConfig = require(Shared.Config.Gacha)
local MonetizationConfig = require(Shared.Config.Monetization)
local Gacha = require(Shared.Gacha)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local RollController = {}

local rolling = false

local function estimateLuck(): number
	local luck = 1
	if player:GetAttribute("Pass_VIP") then
		luck *= MonetizationConfig.VipLuckMultiplier
	end
	if player:GetAttribute("Pass_Luck") then
		luck *= MonetizationConfig.LuckPassMultiplier
	end
	if (workspace:GetAttribute("ServerLuckUntil") or 0) > workspace:GetServerTimeNow() then
		luck *= MonetizationConfig.ServerLuckMultiplier
	end
	return luck
end

local function abilitySummary(styleId: string): string
	local style = Styles.Get(styleId)
	return ("Q %s • E %s • R %s • G %s"):format(
		style.Abilities.Q.Name,
		style.Abilities.E.Name,
		style.Abilities.R.Name,
		style.Ultimate.Name
	)
end

function RollController:BuildRollPanel()
	local panel = Hud:CreatePanel("Spirit Roll", Vector2.new(820, 520))
	local content = panel.Content

	-- Left: odds table (always visible, as Roblox requires for random items).
	local oddsBox = UI.new("ScrollingFrame", {
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(0.42, -8, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		Parent = content,
	}, { UI.corner(12), UI.padding(10), UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local luckLabel = UI.label({ Text = "", TextColor3 = Theme.Gold, Size = UDim2.new(1, 0, 0, 22), MaxTextSize = 18, LayoutOrder = 0, Parent = oddsBox })
	local rows = {}
	for i, id in Styles.Order do
		local style = Styles.Get(id)
		local row = UI.label({
			Text = "",
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 24),
			MaxTextSize = 18,
			LayoutOrder = i,
			Parent = oddsBox,
		})
		rows[id] = { Label = row, Style = style }
	end
	UI.label({
		Text = ("Pity: guaranteed Legendary+ within %d rolls. Duplicates refund Shards."):format(GachaConfig.PityRolls),
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 40),
		MaxTextSize = 14,
		LayoutOrder = 100,
		Parent = oddsBox,
	})

	local function refreshOdds()
		local luck = estimateLuck()
		local odds = Gacha.GetStyleOdds(luck)
		luckLabel.Text = ("Your luck: x%.2f"):format(luck)
		for id, row in rows do
			local rarity = Gacha.GetRarity(row.Style.Rarity)
			row.Label.Text = ('<font color="#%s"><b>%s</b></font>  %s — %s%%'):format(
				rarity.Color:ToHex(),
				rarity.Id,
				row.Style.Name,
				(("%.2f"):format(odds[id] * 100))
			)
		end
	end

	-- Right: reveal area + buttons.
	local right = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.42, 8, 0, 0),
		Size = UDim2.new(0.58, -8, 1, 0),
		Parent = content,
	})
	local reveal = UI.new("Frame", {
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, 0, 1, -110),
		Parent = right,
	}, { UI.corner(12) })
	local revealStroke = UI.stroke(Theme.Accent, 3, 0.2)
	revealStroke.Parent = reveal
	local revealTitle = UI.label({ Text = "Roll for a new Art!", Font = Theme.FontHeavy, Size = UDim2.new(1, -20, 0.4, 0), Position = UDim2.new(0, 10, 0.12, 0), MaxTextSize = 40, Parent = reveal })
	local revealSub = UI.label({ Text = "", TextColor3 = Theme.SubText, TextWrapped = true, Size = UDim2.new(1, -20, 0.36, 0), Position = UDim2.new(0, 10, 0.55, 0), MaxTextSize = 18, Parent = reveal })
	local grid = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		Visible = false,
		Parent = reveal,
	}, { UI.new("UIGridLayout", { CellSize = UDim2.new(0.2, -6, 0.5, -6), CellPadding = UDim2.fromOffset(6, 6) }) })

	local pityLabel = UI.label({ Text = "", TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -104), MaxTextSize = 16, Parent = right })

	local function showSingle(result)
		grid.Visible = false
		revealTitle.Visible, revealSub.Visible = true, true
		local names = {}
		for _, id in Styles.Order do
			table.insert(names, id)
		end
		for i = 1, 14 do
			local id = names[(i % #names) + 1]
			local s = Styles.Get(id)
			revealTitle.Text = s.Name
			revealTitle.TextColor3 = s.Color
			task.wait(0.03 + i * 0.008)
		end
		local style = Styles.Get(result.Style)
		local rarity = Gacha.GetRarity(result.Rarity)
		revealTitle.Text = style.Name
		revealTitle.TextColor3 = rarity.Color
		revealStroke.Color = rarity.Color
		revealSub.Text = ("%s%s\n%s"):format(
			result.Rarity:upper(),
			if result.New then "  •  NEW!" else ("  •  duplicate (+%d Shards)"):format(result.Refund),
			style.Description
		)
	end

	local function showMany(results)
		revealTitle.Visible, revealSub.Visible = false, false
		grid.Visible = true
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, result in results do
			local rarity = Gacha.GetRarity(result.Rarity)
			local cell = UI.new("Frame", { BackgroundColor3 = Theme.PanelLight, Parent = grid }, { UI.corner(8), UI.stroke(rarity.Color, 2, 0) })
			UI.label({
				Text = Styles.Get(result.Style).Name .. (if result.New then "\nNEW" else ""),
				TextColor3 = rarity.Color,
				TextWrapped = true,
				Size = UDim2.new(1, -6, 1, -6),
				Position = UDim2.fromOffset(3, 3),
				MaxTextSize = 14,
				Parent = cell,
			})
			task.wait(0.08)
		end
	end

	local function roll(count: number)
		if rolling then
			return
		end
		rolling = true
		local ok, response = pcall(Remotes.Roll.InvokeServer, Remotes.Roll, count)
		if not ok or type(response) ~= "table" then
			Hud:Toast("Roll failed, try again.", "error")
		elseif not response.Ok then
			Hud:Toast(response.Error or "Can't roll right now.", "error")
		elseif count == 1 then
			showSingle(response.Results[1])
		else
			showMany(response.Results)
		end
		rolling = false
	end

	UI.button({ Text = "Roll x1", Color = Theme.Accent, Size = UDim2.new(0.5, -5, 0, 50), Position = UDim2.new(0, 0, 1, -76), Parent = right, OnClick = function()
		roll(1)
	end })
	local roll10 = UI.button({ Text = "Roll x10", Color = Theme.Gold, Size = UDim2.new(0.5, -5, 0, 50), Position = UDim2.new(0.5, 5, 1, -76), Parent = right, OnClick = function()
		if not player:GetAttribute("Pass_QuickRoll") then
			Hud:Toast("x10 rolls need the Quick Roll pass (see Shop).", "info")
			return
		end
		roll(10)
	end })
	UI.label({
		Text = ("1 roll = 1 Spin, or %d Shards when out of spins"):format(GachaConfig.RollCostShards),
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -22),
		MaxTextSize = 14,
		Parent = right,
	})

	State.Observe(function(d)
		pityLabel.Text = ("Spins: %d   •   Legendary+ guaranteed in %d rolls"):format(d.Spins, GachaConfig.PityRolls - d.RollsSincePity)
		roll10.Text = if player:GetAttribute("Pass_QuickRoll") then "Roll x10" else "Roll x10 🔒"
	end)

	panel.OnOpen = refreshOdds
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 5) == "Pass_" then
			refreshOdds()
		end
	end)
	workspace:GetAttributeChangedSignal("ServerLuckUntil"):Connect(refreshOdds)
	refreshOdds()
	return panel
end

function RollController:BuildArtsPanel()
	local panel = Hud:CreatePanel("My Arts", Vector2.new(720, 520))
	local list = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		Parent = panel.Content,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local function render(d)
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i, id in Styles.Order do
			local style = Styles.Get(id)
			local owned = d.OwnedStyles[id] == true
			local rarity = Gacha.GetRarity(style.Rarity)
			local row = UI.new("Frame", {
				BackgroundColor3 = Theme.Background,
				BackgroundTransparency = if owned then 0.2 else 0.6,
				Size = UDim2.new(1, -8, 0, 84),
				LayoutOrder = i,
				Parent = list,
			}, { UI.corner(12), UI.stroke(rarity.Color, 2, if owned then 0.1 else 0.7), UI.padding(10) })
			UI.label({
				Text = ('%s  <font color="#%s">[%s]</font>'):format(if owned then style.Name else "???", rarity.Color:ToHex(), rarity.Id),
				RichText = true,
				Font = Theme.FontHeavy,
				TextColor3 = if owned then style.Color else Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -130, 0, 28),
				MaxTextSize = 22,
				Parent = row,
			})
			UI.label({
				Text = if owned then abilitySummary(id) else "Roll to unlock this Art.",
				TextColor3 = Theme.SubText,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -130, 0, 34),
				Position = UDim2.fromOffset(0, 30),
				MaxTextSize = 15,
				Parent = row,
			})
			if owned then
				local equipped = d.EquippedStyle == id
				UI.button({
					Text = if equipped then "Equipped" else "Equip",
					Color = if equipped then Theme.Good else Theme.Accent,
					Size = UDim2.fromOffset(110, 44),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Parent = row,
					OnClick = function()
						if equipped then
							return
						end
						local ok, response = pcall(Remotes.Equip.InvokeServer, Remotes.Equip, id)
						if ok and type(response) == "table" and response.Ok then
							Hud:Toast("Equipped " .. style.Name, "success")
						else
							Hud:Toast(ok and type(response) == "table" and response.Error or "Couldn't equip.", "error")
						end
					end,
				})
			end
		end
	end

	State.Observe(render)
	return panel
end

function RollController:Init()
	local rollPanel = self:BuildRollPanel()
	local artsPanel = self:BuildArtsPanel()
	Hud:AddMenuButton("Roll", Theme.Accent, 1, rollPanel.Toggle)
	Hud:AddMenuButton("Arts", Theme.Accent2, 2, artsPanel.Toggle)
end

return RollController
