-- World map panel (travel between zones), per-zone lighting and the anime
-- title card shown when you arrive somewhere new.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Config.Zones)

local UI = require(script.Parent.Parent.UI)
local State = require(script.Parent.Parent.State)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local ZoneController = {}

local hubLighting = nil

local function captureHub()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChild("RiftColor")
	hubLighting = {
		ClockTime = Lighting.ClockTime,
		AtmosphereColor = atmosphere and atmosphere.Color,
		AtmosphereDecay = atmosphere and atmosphere.Decay,
		Density = atmosphere and atmosphere.Density,
		Haze = atmosphere and atmosphere.Haze,
		Tint = cc and cc.TintColor,
		Saturation = cc and cc.Saturation,
	}
end

local function applyLighting(preset)
	if not preset then
		return
	end
	local function goal(map)
		local out, any = {}, false
		for k, v in map do
			if v ~= nil then
				out[k] = v
				any = true
			end
		end
		return any and out or nil
	end
	if preset.ClockTime then
		UI.tween(Lighting, 1.5, { ClockTime = preset.ClockTime }, Enum.EasingStyle.Sine)
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosphereGoal = goal({ Color = preset.AtmosphereColor, Decay = preset.AtmosphereDecay, Density = preset.Density, Haze = preset.Haze })
	if atmosphere and atmosphereGoal then
		UI.tween(atmosphere, 1.5, atmosphereGoal, Enum.EasingStyle.Sine)
	end
	local cc = Lighting:FindFirstChild("RiftColor")
	local ccGoal = goal({ TintColor = preset.Tint, Saturation = preset.Saturation })
	if cc and ccGoal then
		UI.tween(cc, 1.5, ccGoal, Enum.EasingStyle.Sine)
	end
end

local function titleCard(zone)
	local gui = Hud.Gui
	local band = UI.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(1.4, 0, 0, 0),
		Rotation = -4,
		ZIndex = 40,
		Parent = gui,
	}, { UI.new("UIStroke", { Color = zone.Color, Thickness = 4 }) })
	local title = UI.label({
		Text = string.upper(zone.Name),
		Font = Theme.FontHeavy,
		TextColor3 = zone.Color,
		MaxTextSize = 80,
		Outline = 5,
		Size = UDim2.new(0.7, 0, 0.62, 0),
		Position = UDim2.fromScale(0.15, 0.04),
		ZIndex = 41,
		TextTransparency = 1,
		Parent = band,
	})
	local sub = UI.label({
		Text = zone.Subtitle,
		Font = Theme.FontHeavy,
		MaxTextSize = 26,
		Size = UDim2.new(0.7, 0, 0.3, 0),
		Position = UDim2.fromScale(0.15, 0.66),
		ZIndex = 41,
		TextTransparency = 1,
		Parent = band,
	})
	UI.tween(band, 0.3, { Size = UDim2.new(1.4, 0, 0, 150) }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		UI.tween(title, 0.3, { TextTransparency = 0 })
		UI.tween(sub, 0.3, { TextTransparency = 0 })
	end)
	task.delay(2.6, function()
		UI.tween(title, 0.3, { TextTransparency = 1 })
		UI.tween(sub, 0.3, { TextTransparency = 1 })
		UI.tween(band, 0.35, { Size = UDim2.new(1.4, 0, 0, 0), BackgroundTransparency = 1 })
		task.wait(0.4)
		band:Destroy()
	end)
end

function ZoneController:BuildMap()
	local panel = Hud:CreatePanel("World Map", Vector2.new(900, 560))
	local grid = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = panel.Content,
	}, {
		UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -10, 0, 150), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
	})

	local cards = {}
	for i, id in Zones.Order do
		local zone = Zones.Get(id)
		local card = UI.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = i,
			Parent = grid,
		}, {
			UI.corner(12),
			UI.new("UIGradient", { Color = ColorSequence.new(zone.Color:Lerp(Theme.Background, 0.35), Theme.Background), Rotation = 120 }),
			UI.stroke(Theme.Ink, 3),
		})
		UI.label({ Text = string.upper(zone.Name), Font = Theme.FontHeavy, TextColor3 = Theme.Text, MaxTextSize = 30, Outline = 3, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(14, 10), Parent = card })
		UI.label({ Text = zone.Subtitle, TextColor3 = zone.Color, Font = Theme.FontHeavy, MaxTextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(14, 50), Parent = card })
		local boss = zone.Boss and ("BOSS: %s (Lv.%d)"):format(zone.Boss.Name, zone.Boss.Level) or ""
		UI.label({ Text = boss, TextColor3 = Theme.SubText, MaxTextSize = 15, Outline = false, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(14, 82), Parent = card })
		local button = UI.button({
			Text = "TRAVEL",
			Color = zone.Color,
			Size = UDim2.fromOffset(130, 46),
			Position = UDim2.new(1, -144, 1, -58),
			MaxTextSize = 20,
			Parent = card,
			OnClick = function()
				local ok, result = pcall(Remotes.Travel.InvokeServer, Remotes.Travel, id)
				if ok and type(result) == "table" then
					if result.Ok then
						panel.Close()
					else
						Hud:Toast(result.Error, "error")
					end
				end
			end,
		})
		cards[id] = { Button = button, Zone = zone }
	end

	local function refresh()
		local d = State.Data
		local current = player:GetAttribute("Zone") or "Hub"
		for id, c in cards do
			local locked = d and d.Level < c.Zone.MinLevel
			c.Button.Text = if id == current then "YOU'RE HERE" elseif locked then ("🔒 LV.%d"):format(c.Zone.MinLevel) else "TRAVEL"
		end
	end
	State.Observe(refresh)
	player:GetAttributeChangedSignal("Zone"):Connect(refresh)
	panel.OnOpen = refresh

	Hud:AddMenuButton("Map", Color3.fromRGB(120, 90, 255), 4, panel.Toggle)
end

function ZoneController:Init()
	captureHub()
	self:BuildMap()

	local last = player:GetAttribute("Zone") or "Hub"
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local id = player:GetAttribute("Zone") or "Hub"
		if id == last then
			return
		end
		last = id
		local zone = Zones.Get(id)
		if not zone then
			return
		end
		applyLighting(if id == "Hub" then hubLighting else zone.Lighting)
		titleCard(zone)
	end)
end

return ZoneController
