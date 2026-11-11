-- Quests panel: STORY chain + DAILY / WEEKLY / MONTHLY tabs with reset timers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Potions = require(Shared.Config.Potions)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme

local QuestController = {}

local TAB_COLORS = {
	STORY = Theme.Accent,
	DAILY = Theme.Accent2,
	WEEKLY = Theme.Gold,
	MONTHLY = Color3.fromRGB(180, 110, 255),
}
local TAB_ORDER = { "STORY", "DAILY", "WEEKLY", "MONTHLY" }

local potionNames = {}
for id, potion in Potions.List do
	potionNames[id] = potion.Name
end

local function countdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	if days > 0 then
		return ("%dd %dh"):format(days, (seconds % 86400) // 3600)
	end
	return ("%dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
end

local function rewardRow(parent: Instance, reward, level: number, position: UDim2)
	local row = UI.new("Frame", { BackgroundTransparency = 1, Position = position, Size = UDim2.new(1, -20, 0, 34), Parent = parent }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
	local function pill(text: string, color: Color3)
		local p = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Parent = row }, {
			UI.corner(14),
			UI.stroke(Theme.Ink, 2),
			UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		})
		local label = UI.label({ Text = text, Font = Theme.FontHeavy, MaxTextSize = 15, TextScaled = false, TextSize = 15, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Parent = p })
		return label
	end
	if reward.Shards then
		pill(("◆ %d"):format(Economy.ScaledShards(reward.Shards, level)), Color3.fromRGB(40, 140, 220))
	end
	if reward.Spins then
		pill(("✦ %d"):format(reward.Spins), Color3.fromRGB(220, 50, 130))
	end
	for id, count in reward.Potions or {} do
		local potion = Potions.Get(id)
		if potion then
			local holder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 34), Parent = row })
			UI.potionIcon(potion, 34, holder)
			if count > 1 then
				UI.label({ Text = "x" .. count, Font = Theme.FontHeavy, MaxTextSize = 13, TextColor3 = Theme.Gold, Size = UDim2.fromOffset(24, 14), Position = UDim2.fromOffset(18, 22), Parent = holder })
			end
		end
	end
	return row
end

local function questCard(parent: Instance, quest, progress: number, done: boolean, level: number, color: Color3, order: number, tag: string?)
	local card = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -10, 0, 108),
		LayoutOrder = order,
		Rotation = if order % 2 == 0 then 0.5 else -0.5,
		Parent = parent,
	}, {
		UI.corner(10),
		UI.new("UIGradient", { Color = ColorSequence.new((if done then Theme.Good else color):Lerp(Theme.Background, 0.55), Theme.Background) }),
		UI.stroke(Theme.Ink, 3),
	})
	UI.label({
		Text = (if done then "✔ " else "") .. (if tag then tag .. "  " else "") .. string.upper(quest.Text:format(quest.Goal)),
		Font = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 21,
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(14, 8),
		Parent = card,
	})
	local _, setBar = UI.bar({ Color = if done then Theme.Good else color, Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(14, 48), MaxTextSize = 13, Parent = card })
	setBar(progress / quest.Goal, ("%s / %s"):format(Hud.FormatNumber(progress), Hud.FormatNumber(quest.Goal)))
	rewardRow(card, quest.Reward, level, UDim2.new(0, 10, 1, -42))
	return card
end

function QuestController:Init()
	local panel = Hud:CreatePanel("Quests", Vector2.new(860, 600))
	local content = panel.Content

	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 6), Parent = content }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local header = UI.label({ Text = "", Font = Theme.FontHeavy, MaxTextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(4, 58), Parent = content })
	local list = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 1, -90),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = content,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
	})

	local current = "STORY"
	local buttons = {}
	local render

	for i, name in TAB_ORDER do
		buttons[name] = UI.button({ Text = name, Color = TAB_COLORS[name], Size = UDim2.fromOffset(150, 42), Rotation = -2, MaxTextSize = 20, LayoutOrder = i, Parent = tabs, OnClick = function()
			current = name
			render()
		end })
	end

	render = function()
		local d = State.Data
		for name, b in buttons do
			b.BackgroundTransparency = if name == current then 0 else 0.5
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if not d or not d.Quests or not d.Quests.Chain then
			return
		end
		local color = TAB_COLORS[current]
		if current == "STORY" then
			local step = d.Quests.Chain.Step
			local quest = Economy.ChainQuest(step)
			local isBounty = step > #Economy.Chain
			header.Text = if isBounty then "STORY COMPLETE — ENDLESS BOUNTIES" else ("CHAPTER %d / %d  •  the next quest unlocks when this one is done"):format(step, #Economy.Chain)
			header.TextColor3 = color
			questCard(list, quest, d.Quests.Chain.Progress, false, d.Level, color, 1, if isBounty then nil else ("#%d"):format(step))
			-- Teaser of what comes next.
			local nextQuest = Economy.ChainQuest(step + 1)
			local teaser = UI.new("Frame", { BackgroundColor3 = Theme.Ink, BackgroundTransparency = 0.3, Size = UDim2.new(1, -10, 0, 54), LayoutOrder = 2, Parent = list }, { UI.corner(10), UI.stroke(Theme.Ink, 2) })
			UI.label({ Text = "🔒 NEXT: " .. string.upper(nextQuest.Text:format(nextQuest.Goal)), Font = Theme.FontHeavy, TextColor3 = Theme.SubText, MaxTextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 1, -10), Position = UDim2.fromOffset(12, 5), Parent = teaser })
			return
		end

		local kind = if current == "DAILY" then "Daily" elseif current == "WEEKLY" then "Weekly" else "Monthly"
		local set = d.Quests[kind]
		local done = 0
		for i, entry in set.List do
			local quest = Economy.GetQuest(entry.Id)
			if quest then
				if entry.Done then
					done += 1
				end
				questCard(list, quest, entry.Progress, entry.Done, d.Level, color, i)
			end
		end
		header.Text = ("%s  •  %d/%d DONE  •  RESETS IN %s"):format(current, done, #set.List, countdown(Economy.SecondsLeft(kind)))
		header.TextColor3 = color
		local bonus = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -10, 0, 70), LayoutOrder = 99, Parent = list }, {
			UI.corner(10),
			UI.new("UIGradient", { Color = ColorSequence.new(if set.Bonus then Theme.Good else Theme.Gold, Theme.Background) }),
			UI.stroke(Theme.Ink, 3),
		})
		UI.label({ Text = if set.Bonus then "★ BONUS CLAIMED ★" else "COMPLETE ALL FOR A BONUS:", Font = Theme.FontHeavy, MaxTextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromOffset(14, 0), Parent = bonus })
		rewardRow(bonus, Economy.Periods[kind].Bonus, d.Level, UDim2.new(0, 10, 0.5, -17))
	end

	State.Observe(function()
		if panel.Frame.Visible then
			render()
		end
	end)
	panel.OnOpen = render
	task.spawn(function()
		while true do
			task.wait(30)
			if panel.Frame.Visible then
				render()
			end
		end
	end)

	Hud:AddMenuButton("Quests", Color3.fromRGB(80, 220, 170), 5, panel.Toggle)
end

return QuestController
