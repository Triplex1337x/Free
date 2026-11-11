-- Anime / manga UI kit: comic fonts, thick ink outlines, gradients, slanted
-- shapes and springy buttons. No uploaded images needed.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Theme = {
	Background = Color3.fromRGB(14, 11, 26),
	Panel = Color3.fromRGB(26, 20, 46),
	PanelLight = Color3.fromRGB(48, 36, 82),
	Ink = Color3.fromRGB(8, 5, 14),
	Accent = Color3.fromRGB(255, 70, 140),
	Accent2 = Color3.fromRGB(70, 200, 255),
	Gold = Color3.fromRGB(255, 205, 60),
	Good = Color3.fromRGB(90, 235, 140),
	Bad = Color3.fromRGB(255, 80, 90),
	Text = Color3.fromRGB(255, 252, 245),
	SubText = Color3.fromRGB(185, 175, 215),
	-- Cyrillic-capable fonts (the comic Latin fonts have no Russian letters).
	Font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	FontHeavy = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
}

local Theme = UI.Theme

function UI.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		elseif key == "Font" and typeof(value) == "Font" then
			(inst :: any).FontFace = value
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
		Color = color or Theme.Accent,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
end

-- Two-colour gradient outline (e.g. pink -> cyan) for that anime UI glow.
function UI.gradientStroke(a: Color3, b: Color3, thickness: number?)
	local stroke = UI.stroke(Color3.new(1, 1, 1), thickness or 3, 0)
	UI.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = 35, Parent = stroke })
	return stroke
end

function UI.padding(px: number)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

-- Text with a thick ink outline, like manga lettering.
function UI.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		if k ~= "MaxTextSize" and k ~= "Outline" then
			defaults[k] = v
		end
	end
	local label = UI.new("TextLabel", defaults)
	UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = label })
	if props.Outline ~= false then
		UI.new("UIStroke", {
			Color = Theme.Ink,
			Thickness = props.Outline or 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	return label
end

function UI.tween(inst: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- Comic-style button: bold gradient fill, ink outline, slight slant,
-- springy hover / press, shine sweep on hover.
function UI.button(props)
	local color = props.Color or Theme.Accent
	local h, s, v = color:ToHSV()
	local light = Color3.fromHSV(h, math.max(0, s - 0.15), math.min(1, v + 0.15))
	local dark = Color3.fromHSV(h, math.min(1, s + 0.1), v * 0.7)
	local button = UI.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Font = Theme.FontHeavy,
		TextColor3 = Theme.Text,
		TextScaled = true,
		Text = props.Text or "",
		Size = props.Size or UDim2.fromOffset(120, 40),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Rotation = props.Rotation or 0,
		ClipsDescendants = false,
		Parent = props.Parent,
	}, {
		UI.corner(props.Radius or 8),
		UI.new("UIGradient", { Color = ColorSequence.new(light, dark), Rotation = 90 }),
		UI.new("UIStroke", { Color = Theme.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }),
		UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 24 }),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }),
	})
	-- Ink outline on the text itself.
	UI.new("UIStroke", { Color = Theme.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = button })

	local scale = UI.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UI.tween(scale, 0.15, { Scale = 1.07 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UI.tween(scale, 0.15, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UI.tween(scale, 0.06, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if props.OnClick then
		button.Activated:Connect(props.OnClick)
	end
	return button
end

-- A slanted bar with ink outline and glossy fill. Returns frame, set(ratio, text?), fill.
function UI.bar(props)
	local frame = UI.new("Frame", {
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.05,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Parent = props.Parent,
	}, {
		UI.corner(props.Radius or 4),
		UI.new("UIStroke", { Color = Theme.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local trail = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, { UI.corner(props.Radius or 4) })
	local fill = UI.new("Frame", {
		BackgroundColor3 = props.Color,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, {
		UI.corner(props.Radius or 4),
		UI.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.35, Color3.fromRGB(235, 235, 235)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
			}),
			Rotation = 90,
		}),
	})
	-- Segment ticks for that fighting-game look.
	for i = 1, 9 do
		UI.new("Frame", {
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(i / 10, 0),
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 2,
			Parent = frame,
		})
	end
	local text = UI.label({
		Text = "",
		Font = Theme.FontHeavy,
		ZIndex = 3,
		MaxTextSize = props.MaxTextSize or 16,
		Size = UDim2.new(1, -10, 1, -2),
		Position = UDim2.fromOffset(5, 1),
		Parent = frame,
	})
	local function set(ratio: number, label: string?)
		ratio = math.clamp(ratio, 0, 1)
		UI.tween(fill, 0.12, { Size = UDim2.fromScale(ratio, 1) })
		-- White "damage trail" catches up after a short delay.
		task.delay(0.25, function()
			UI.tween(trail, 0.35, { Size = UDim2.fromScale(ratio, 1) })
		end)
		if label then
			text.Text = label
		end
	end
	return frame, set, fill
end

-- Slanted header ribbon used on panels and banners.
function UI.ribbon(props)
	local ribbon = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or -3,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, {
		UI.new("UIGradient", { Color = ColorSequence.new(props.ColorA or Theme.Accent, props.ColorB or Theme.Accent2), Rotation = 0 }),
		UI.new("UIStroke", { Color = Theme.Ink, Thickness = 3 }),
	})
	UI.label({
		Text = props.Text or "",
		Font = Theme.FontHeavy,
		MaxTextSize = props.MaxTextSize or 30,
		Outline = 3,
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		ZIndex = (props.ZIndex or 1) + 1,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		Parent = ribbon,
	})
	return ribbon
end

-- Anime-style potion bottle drawn from frames: glass body with a liquid
-- line, neck, cork, shine, bubbles, glow and the effect glyph.
function UI.potionIcon(potion, size: number, parent: Instance?)
	local color = potion.Color
	local h, s, v = color:ToHSV()
	local light = Color3.fromHSV(h, math.max(0, s - 0.35), 1)
	local dark = Color3.fromHSV(h, math.min(1, s + 0.15), v * 0.55)
	local glass = Color3.fromRGB(215, 235, 255)

	local root = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	UI.new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.7,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.98, 0.98),
		Parent = root,
	}, { UI.corner(size), UI.new("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90 }) })

	local body = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.97),
		Size = UDim2.fromScale(0.74, 0.66),
		ZIndex = 3,
		Parent = root,
	}, {
		UI.corner(size),
		UI.new("UIStroke", { Color = UI.Theme.Ink, Thickness = math.max(2, size / 22) }),
		UI.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, glass),
				ColorSequenceKeypoint.new(0.3, glass:Lerp(color, 0.25)),
				ColorSequenceKeypoint.new(0.32, light),
				ColorSequenceKeypoint.new(0.6, color),
				ColorSequenceKeypoint.new(1, dark),
			}),
			Rotation = 90,
		}),
	})
	-- Neck and cork.
	UI.new("Frame", {
		BackgroundColor3 = glass,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.28, 0.2),
		ZIndex = 2,
		Parent = root,
	}, { UI.corner(3), UI.new("UIStroke", { Color = UI.Theme.Ink, Thickness = math.max(2, size / 22) }) })
	UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(170, 110, 60),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromScale(0.36, 0.14),
		ZIndex = 4,
		Parent = root,
	}, { UI.corner(4), UI.new("UIStroke", { Color = UI.Theme.Ink, Thickness = math.max(2, size / 24) }) })
	-- Shine and bubbles.
	UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.25,
		Position = UDim2.fromScale(0.16, 0.14),
		Size = UDim2.fromScale(0.16, 0.26),
		Rotation = 20,
		ZIndex = 5,
		Parent = body,
	}, { UI.corner(size) })
	for i, b in { { 0.62, 0.62, 0.1 }, { 0.72, 0.42, 0.07 } } do
		UI.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.35,
			Position = UDim2.fromScale(b[1], b[2]),
			Size = UDim2.fromScale(b[3], b[3] * 1.1),
			ZIndex = 5,
			Name = "Bubble" .. i,
			Parent = body,
		}, { UI.corner(size) })
	end
	UI.label({
		Text = potion.Glyph,
		Font = UI.Theme.FontHeavy,
		MaxTextSize = math.floor(size * 0.36),
		Outline = math.max(2, math.floor(size / 20)),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.6, 0.4),
		ZIndex = 6,
		Parent = root,
	})
	return root
end

return UI
