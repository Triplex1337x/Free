-- Daily quests panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme

local QuestController = {}

function QuestController:Init()
	local panel = Hud:CreatePanel("Daily Quests", Vector2.new(720, 520))
	local content = panel.Content

	local list = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 1, -90),
		Parent = content,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local footer = UI.label({
		Text = "",
		RichText = true,
		Font = Theme.FontHeavy,
		MaxTextSize = 20,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 1, -70),
		Parent = content,
	})
	local resetLabel = UI.label({
		Text = "",
		TextColor3 = Theme.SubText,
		MaxTextSize = 16,
		Outline = false,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -34),
		Parent = content,
	})

	local function render(d)
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local quests = d.Quests and d.Quests.List or {}
		local done = 0
		for i, entry in quests do
			local quest = Economy.GetQuest(entry.Id)
			if quest then
				if entry.Done then
					done += 1
				end
				local color = if entry.Done then Theme.Good else Theme.Accent2
				local card = UI.new("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1),
					Size = UDim2.new(1, -8, 0, 96),
					LayoutOrder = i,
					Rotation = if i % 2 == 0 then 0.6 else -0.6,
					Parent = list,
				}, {
					UI.corner(10),
					UI.new("UIGradient", { Color = ColorSequence.new(color:Lerp(Theme.Background, 0.55), Theme.Background) }),
					UI.stroke(Theme.Ink, 3),
				})
				UI.label({
					Text = (if entry.Done then "✔ " else "") .. string.upper(quest.Text:format(quest.Goal)),
					Font = Theme.FontHeavy,
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 22,
					Size = UDim2.new(1, -24, 0, 30),
					Position = UDim2.fromOffset(14, 8),
					Parent = card,
				})
				local _, setBar = UI.bar({ Color = color, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(14, 46), MaxTextSize = 13, Parent = card })
				setBar(entry.Progress / quest.Goal, ("%s / %s"):format(Hud.FormatNumber(entry.Progress), Hud.FormatNumber(quest.Goal)))
				UI.label({
					Text = "REWARD: " .. Economy.DescribeReward(quest.Reward, d.Level),
					Font = Theme.FontHeavy,
					TextColor3 = Theme.Gold,
					TextXAlignment = Enum.TextXAlignment.Right,
					MaxTextSize = 17,
					Size = UDim2.new(0.38, -14, 0, 40),
					Position = UDim2.new(0.62, 0, 0, 36),
					TextWrapped = true,
					Parent = card,
				})
			end
		end
		footer.Text = if d.Quests and d.Quests.Bonus
			then '<font color="#5AEB8C">★ ALL QUESTS COMPLETE — BONUS CLAIMED ★</font>'
			else ('COMPLETE ALL %d FOR A BONUS: <font color="#FFCD3C">%s</font>   (%d/%d)'):format(#quests, Economy.DescribeReward(Economy.AllQuestsBonus), done, #quests)
	end
	State.Observe(render)

	task.spawn(function()
		while true do
			local secondsLeft = 86400 - (os.time() % 86400)
			resetLabel.Text = ("New quests in %dh %02dm"):format(secondsLeft // 3600, (secondsLeft % 3600) // 60)
			task.wait(20)
		end
	end)

	Hud:AddMenuButton("Quests", Color3.fromRGB(80, 220, 170), 5, panel.Toggle)
end

return QuestController
