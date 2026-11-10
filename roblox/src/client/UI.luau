-- Tiny UI toolkit: consistent anime-neon look without a UI library.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Theme = {
	Background = Color3.fromRGB(16, 14, 26),
	Panel = Color3.fromRGB(28, 24, 44),
	PanelLight = Color3.fromRGB(42, 36, 66),
	Accent = Color3.fromRGB(255, 80, 150),
	Accent2 = Color3.fromRGB(90, 200, 255),
	Gold = Color3.fromRGB(255, 205, 60),
	Good = Color3.fromRGB(90, 230, 140),
	Bad = Color3.fromRGB(255, 90, 90),
	Text = Color3.fromRGB(245, 240, 255),
	SubText = Color3.fromRGB(175, 165, 205),
	Font = Enum.Font.GothamBold,
	FontHeavy = Enum.Font.GothamBlack,
}

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(radius: number?)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UI.stroke(color: Color3?, thickness: number?, transparency: number?)
	return UI.new("UIStroke", {
		Color = color or UI.Theme.Accent,
		Thickness = thickness or 2,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(px: number)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function UI.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UI.Theme.Font,
		TextColor3 = UI.Theme.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		if k ~= "MaxTextSize" then
			defaults[k] = v
		end
	end
	local label = UI.new("TextLabel", defaults)
	UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = label })
	return label
end

function UI.tween(inst: Instance, time: number, goal, style: Enum.EasingStyle?)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

function UI.button(props)
	local color = props.Color or UI.Theme.Accent
	local button = UI.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = UI.Theme.FontHeavy,
		TextColor3 = UI.Theme.Text,
		TextScaled = true,
		Text = props.Text or "",
		Size = props.Size or UDim2.fromOffset(120, 40),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, {
		UI.corner(props.Radius or 10),
		UI.new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.75, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 22 }),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	local scale = UI.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		UI.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UI.tween(scale, 0.06, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(scale, 0.1, { Scale = 1 })
	end)
	if props.OnClick then
		button.Activated:Connect(props.OnClick)
	end
	return button
end

-- A bar with a fill frame. Returns frame, setter(ratio, text?).
function UI.bar(props)
	local frame = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 8, 18),
		BackgroundTransparency = 0.2,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Parent = props.Parent,
	}, { UI.corner(props.Radius or 6), UI.stroke(props.Color, 1.5, 0.5) })
	local fill = UI.new("Frame", {
		BackgroundColor3 = props.Color,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, {
		UI.corner(props.Radius or 6),
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.25) }),
			Rotation = 90,
		}),
	})
	local text = UI.label({
		Text = "",
		ZIndex = 3,
		TextStrokeTransparency = 0.4,
		MaxTextSize = props.MaxTextSize or 16,
		Size = UDim2.new(1, -8, 1, -2),
		Position = UDim2.fromOffset(4, 1),
		Parent = frame,
	})
	local function set(ratio: number, label: string?)
		UI.tween(fill, 0.15, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
		if label then
			text.Text = label
		end
	end
	return frame, set, fill
end

return UI
