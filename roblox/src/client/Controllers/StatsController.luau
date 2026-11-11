-- Stats panel: spend points from levelling on Strength / Vitality / Agility /
-- Spirit and see the resulting bonuses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Prog = require(Shared.Config.Progression)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme

local StatsController = {}

local function allocate(statId: string, amount: number)
	local ok, result = pcall(Remotes.AllocateStat.InvokeServer, Remotes.AllocateStat, statId, amount)
	if not ok or type(result) ~= "table" then
		Hud:Toast("Couldn't spend points, try again.", "error")
	elseif not result.Ok then
		Hud:Toast(result.Error, "error")
	end
end

function StatsController:Init()
	local panel = Hud:CreatePanel("Stats", Vector2.new(760, 560))
	local content = panel.Content

	local header = UI.label({
		Text = "",
		Font = Theme.FontHeavy,
		TextColor3 = Theme.Gold,
		MaxTextSize = 30,
		Outline = 3,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 6),
		Parent = content,
	})

	local list = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -150),
		Parent = content,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local rows = {}
	for i, stat in Prog.Stats do
		local row = UI.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, -10, 0, 74),
			LayoutOrder = i,
			Parent = list,
		}, {
			UI.corner(10),
			UI.new("UIGradient", { Color = ColorSequence.new(stat.Color:Lerp(Theme.Background, 0.55), Theme.Background), Rotation = 0 }),
			UI.stroke(Theme.Ink, 3),
		})
		UI.new("Frame", { BackgroundColor3 = stat.Color, Size = UDim2.new(0, 8, 1, 0), BorderSizePixel = 0, Parent = row }, { UI.corner(4) })
		UI.label({ Text = stat.Short, Font = Theme.FontHeavy, TextColor3 = stat.Color, MaxTextSize = 34, Outline = 3, Size = UDim2.fromOffset(80, 50), Position = UDim2.fromOffset(18, 12), Parent = row })
		UI.label({ Text = string.upper(stat.Name), Font = Theme.FontHeavy, MaxTextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.45, 0, 0, 28), Position = UDim2.fromOffset(104, 8), Parent = row })
		UI.label({ Text = stat.Description, TextColor3 = Theme.SubText, MaxTextSize = 15, Outline = false, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.45, 0, 0, 24), Position = UDim2.fromOffset(104, 40), Parent = row })
		local value = UI.label({ Text = "0", Font = Theme.FontHeavy, MaxTextSize = 34, Outline = 3, Size = UDim2.fromOffset(80, 50), Position = UDim2.new(1, -330, 0, 12), Parent = row })
		for j, amount in { 1, 5, 10 } do
			UI.button({
				Text = "+" .. amount,
				Color = stat.Color,
				Size = UDim2.fromOffset(66, 44),
				Position = UDim2.new(1, -236 + (j - 1) * 76, 0.5, -22),
				MaxTextSize = 20,
				Parent = row,
				OnClick = function()
					allocate(stat.Id, amount)
				end,
			})
		end
		rows[stat.Id] = value
	end

	local summary = UI.label({
		Text = "",
		RichText = true,
		Font = Theme.FontHeavy,
		MaxTextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -220, 0, 60),
		Position = UDim2.new(0, 4, 1, -76),
		Parent = content,
	})
	UI.button({
		Text = ("RESET (%d ◆)"):format(Prog.ResetCostShards),
		Color = Theme.Bad,
		Size = UDim2.fromOffset(200, 48),
		Position = UDim2.new(1, -204, 1, -70),
		MaxTextSize = 18,
		Parent = content,
		OnClick = function()
			local ok, result = pcall(Remotes.ResetStats.InvokeServer, Remotes.ResetStats)
			if ok and type(result) == "table" then
				Hud:Toast(if result.Ok then "Stats reset — points refunded!" else result.Error, if result.Ok then "success" else "error")
			end
		end,
	})

	State.Observe(function(d)
		local stats = d.Stats or {}
		header.Text = if (d.StatPoints or 0) > 0 then ("▲ %d POINTS TO SPEND ▲"):format(d.StatPoints) else "LEVEL UP TO EARN POINTS (+3 PER LEVEL)"
		for id, label in rows do
			label.Text = tostring(stats[id] or 0)
		end
		local str, vit, agi, spi = stats.Strength or 0, stats.Vitality or 0, stats.Agility or 0, stats.Spirit or 0
		summary.Text = ('<font color="#FF5A5A">+%d%% DMG</font>   <font color="#5AEB8C">+%d HP</font>   <font color="#5AC8FF">-%d%% CD</font>   <font color="#BE6EFF">+%d%% AWAKEN</font>'):format(
			math.floor(str * Prog.StrengthDamage * 100),
			vit * Prog.VitalityHealth,
			math.floor(math.min(Prog.AgilityCooldownCap, agi * Prog.AgilityCooldown) * 100),
			math.floor(spi * Prog.SpiritAwakening * 100)
		)
	end)

	Hud.OpenStats = panel.Open
	Hud:AddMenuButton("Stats", Theme.Gold, 3, panel.Toggle)
end

return StatsController
