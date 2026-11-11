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
local Prog = require(Shared.Config.Progression)

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
	local panel = Hud:CreatePanel("Ролл стилей", Vector2.new(820, 520))
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
		Text = ("Гарант: легендарный+ максимум за %d роллов. За повторы дают осколки."):format(GachaConfig.PityRolls),
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
		luckLabel.Text = ("Твоя удача: x%.2f"):format(luck)
		for id, row in rows do
			local rarity = Gacha.GetRarity(row.Style.Rarity)
			row.Label.Text = ('<font color="#%s"><b>%s</b></font>  %s — %s%%'):format(
				rarity.Color:ToHex(),
				rarity.Name,
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
	local revealTitle = UI.label({ Text = "Крути новый стиль!", Font = Theme.FontHeavy, Size = UDim2.new(1, -20, 0.4, 0), Position = UDim2.new(0, 10, 0.12, 0), MaxTextSize = 40, Parent = reveal })
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
			string.upper(Gacha.GetRarity(result.Rarity).Name),
			if result.New then "  •  НОВЫЙ!" else ("  •  повтор (+%d ◆)"):format(result.Refund),
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
				Text = Styles.Get(result.Style).Name .. (if result.New then "\nНОВЫЙ" else ""),
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
			Hud:Toast("Ролл не удался, попробуй ещё раз.", "error")
		elseif not response.Ok then
			Hud:Toast(response.Error or "Сейчас нельзя крутить.", "error")
		elseif count == 1 then
			showSingle(response.Results[1])
		else
			showMany(response.Results)
		end
		rolling = false
	end

	UI.button({ Text = "РОЛЛ x1", Color = Theme.Accent, Size = UDim2.new(0.5, -5, 0, 50), Position = UDim2.new(0, 0, 1, -76), Parent = right, OnClick = function()
		roll(1)
	end })
	local roll10 = UI.button({ Text = "РОЛЛ x10", Color = Theme.Gold, Size = UDim2.new(0.5, -5, 0, 50), Position = UDim2.new(0.5, 5, 1, -76), Parent = right, OnClick = function()
		if not player:GetAttribute("Pass_QuickRoll") then
			Hud:Toast("Для ролла x10 нужен пропуск «Быстрый ролл» (см. магазин).", "info")
			return
		end
		roll(10)
	end })
	UI.label({
		Text = ("1 ролл = 1 ✦ или %d ◆, если спины кончились"):format(GachaConfig.RollCostShards),
		TextColor3 = Theme.SubText,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -22),
		MaxTextSize = 14,
		Parent = right,
	})

	State.Observe(function(d)
		pityLabel.Text = ("Спины: %d   •   Легендарный+ гарантирован через %d роллов"):format(d.Spins, GachaConfig.PityRolls - d.RollsSincePity)
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
	local panel = Hud:CreatePanel("Мои стили", Vector2.new(820, 580))
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
				BackgroundColor3 = Color3.new(1, 1, 1),
				Size = UDim2.new(1, -10, 0, if owned then 156 else 70),
				LayoutOrder = i,
				Parent = list,
			}, {
				UI.corner(12),
				UI.new("UIGradient", { Color = ColorSequence.new((if owned then style.Color else Theme.PanelLight):Lerp(Theme.Background, 0.6), Theme.Background) }),
				UI.stroke(if owned then rarity.Color else Theme.Ink, 3),
				UI.padding(10),
			})
			UI.label({
				Text = ('%s  <font color="#%s">[%s]</font>'):format(if owned then string.upper(style.Name) else "???", rarity.Color:ToHex(), string.upper(rarity.Name)),
				RichText = true,
				Font = Theme.FontHeavy,
				TextColor3 = if owned then style.Color else Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -140, 0, 28),
				MaxTextSize = 24,
				Parent = row,
			})
			if not owned then
				UI.label({ Text = "Выбей этот стиль в ролле.", TextColor3 = Theme.SubText, Outline = false, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -140, 0, 22), Position = UDim2.fromOffset(0, 30), MaxTextSize = 15, Parent = row })
			else
				if style.Passive then
					UI.label({
						Text = ("★ %s: %s   •   СИЛА x%.2f"):format(style.Passive.Name, style.Passive.Description, rarity.Power or 1),
						TextColor3 = Theme.Gold,
						Outline = false,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 14,
						Size = UDim2.new(1, -140, 0, 18),
						Position = UDim2.fromOffset(0, 116),
						Parent = row,
					})
				end
				local level, xp = Prog.GetMastery(d, id)
				local maxed = level >= Prog.Mastery.MaxLevel
				local _, setBar = UI.bar({ Color = style.Color, Size = UDim2.new(1, -140, 0, 16), Position = UDim2.fromOffset(0, 34), MaxTextSize = 12, Parent = row })
				setBar(if maxed then 1 else xp / Prog.MasteryXpFor(level), if maxed then "МАСТЕРСТВО МАКС." else ("МАСТЕРСТВО %d  •  %d / %d"):format(level, xp, Prog.MasteryXpFor(level)))
				-- Skill unlock chips.
				local chips = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, -140, 0, 52), Parent = row }, {
					UI.new("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 50), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
				})
				for k, key in { "Q", "E", "R", "G" } do
					local ability = Styles.GetAbility(id, key)
					local need = Prog.Mastery.Unlocks[key]
					local open = level >= need
					local chip = UI.new("Frame", { BackgroundColor3 = if open then style.Color:Lerp(Theme.Background, 0.3) else Theme.Ink, LayoutOrder = k, Parent = chips }, { UI.corner(8), UI.stroke(if key == "G" then Theme.Gold else Theme.Ink, 2) })
					UI.label({
						Text = if open then ("%s  %s"):format(key, ability.Name) else ("🔒 %s  мастерство %d"):format(key, need),
						Font = Theme.FontHeavy,
						TextWrapped = true,
						TextColor3 = if open then Theme.Text else Theme.SubText,
						MaxTextSize = 14,
						Size = UDim2.new(1, -8, 1, -6),
						Position = UDim2.fromOffset(4, 3),
						Parent = chip,
					})
				end
			end
			if owned then
				local equipped = d.EquippedStyle == id
				UI.button({
					Text = if equipped then "ВЫБРАН" else "ВЫБРАТЬ",
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
							Hud:Toast("Выбран стиль: " .. style.Name, "success")
						else
							Hud:Toast(ok and type(response) == "table" and response.Error or "Не удалось выбрать стиль.", "error")
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
