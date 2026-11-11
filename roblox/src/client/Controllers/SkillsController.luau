-- "СКИЛЛЫ" panel: what every ability of your equipped style does, whether it
-- homes in or has to be aimed, damage, control effects and the style passive.
-- Works the same on phones (tap the menu button) and PC. Quick version of the
-- same info: hover a skill (PC) or hold it (touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Styles = require(Shared.Config.Styles)
local Prog = require(Shared.Config.Progression)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme

local SkillsController = {}

local KEYS = { "Q", "E", "R", "G" }

function SkillsController:Init()
	local panel = Hud:CreatePanel("Скиллы", Vector2.new(760, 640))
	local list = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 1, -8),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = panel.Content,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
	})

	local function card(order: number, height: number, color: Color3)
		return UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -8, 0, height), LayoutOrder = order, Parent = list }, {
			UI.corner(10),
			UI.new("UIGradient", { Color = ColorSequence.new(Theme.PanelLight, Theme.Background) }),
			UI.stroke(color, 3),
		})
	end

	local function render()
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local d = State.Data
		local style = d and Styles.Get(d.EquippedStyle)
		if not style then
			return
		end

		local head = card(0, 96, style.Color)
		UI.label({ Text = style.Name, Font = Theme.FontHeavy, MaxTextSize = 24, TextColor3 = style.Color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 6), Parent = head })
		UI.label({ Text = ("Пассивка «%s»: %s"):format(style.Passive.Name, style.Passive.Description), MaxTextSize = 15, Outline = false, TextWrapped = true, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -24, 0, 54), Position = UDim2.fromOffset(12, 38), Parent = head })

		for i, key in KEYS do
			local ability = Styles.GetAbility(d.EquippedStyle, key)
			if ability then
				local info = Styles.Describe(ability, key == "G")
				local unlocked = Prog.IsUnlocked(d, d.EquippedStyle, key)
				local height = 84 + #info.Lines * 20
				local frame = card(i, height, if key == "G" then Theme.Gold else Theme.Ink)
				local badge = UI.new("Frame", { BackgroundColor3 = if key == "G" then Theme.Gold else style.Color, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 10), Parent = frame }, { UI.corner(28), UI.stroke(Theme.Ink, 3) })
				UI.label({ Text = if key == "G" then "G" else key, Font = Theme.FontHeavy, MaxTextSize = 28, Outline = 3, Parent = badge })
				local title = ability.Name .. (if unlocked then "" else ("   🔒 мастерство %d"):format(Prog.Mastery.Unlocks[key] or 0))
				UI.label({ Text = title, Font = Theme.FontHeavy, MaxTextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -90, 0, 28), Position = UDim2.fromOffset(78, 8), Parent = frame })
				UI.label({
					Text = info.Aim,
					Font = Theme.FontHeavy,
					MaxTextSize = 15,
					TextWrapped = true,
					TextColor3 = if ability.Homing then Theme.Good elseif ability.Kind == "AoE" and not ability.Offset then Theme.Accent2 else Theme.Gold,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -90, 0, 36),
					Position = UDim2.fromOffset(78, 36),
					Parent = frame,
				})
				UI.label({
					Text = "• " .. table.concat(info.Lines, "\n• "),
					MaxTextSize = 15,
					Outline = false,
					TextWrapped = true,
					TextColor3 = Theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Size = UDim2.new(1, -90, 0, #info.Lines * 20 + 4),
					Position = UDim2.fromOffset(78, 74),
					Parent = frame,
				})
			end
		end

		local hint = card(10, 54, Theme.SubText)
		UI.label({ Text = "Подсказка: на ПК наведи мышь на скилл, на телефоне — зажми кнопку скилла.", MaxTextSize = 15, Outline = false, TextWrapped = true, TextColor3 = Theme.SubText, Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(12, 4), Parent = hint })
	end

	panel.OnOpen = render
	State.Observe(function()
		if panel.Frame.Visible then
			render()
		end
	end)
	Hud:AddMenuButton("Skills", Color3.fromRGB(90, 220, 255), 4, panel.Toggle)
end

return SkillsController
