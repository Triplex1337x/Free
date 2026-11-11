-- Anime-style title screen shown on join: orbiting camera over the arena,
-- big slanted logo, PLAY button. The HUD appears after you press PLAY.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.Parent.UI)
local Hud = require(script.Parent.HudController)
local Input = require(script.Parent.InputController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local MenuController = {}

function MenuController:Start()
	local camera = workspace.CurrentCamera
	local gui = UI.new("ScreenGui", {
		Name = "RiftMenu",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Hud.Gui.Enabled = false
	Input.Enabled = false

	local root = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	-- Vignette + diagonal colour wash.
	UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}, {
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(40, 10, 60), Color3.fromRGB(10, 5, 20)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.1) }),
			Rotation = 20,
		}),
	})
	-- Moving speed lines.
	local lines = {}
	for i = 1, 14 do
		local line = UI.new("Frame", {
			BackgroundColor3 = if i % 3 == 0 then Theme.Accent elseif i % 3 == 1 then Theme.Accent2 else Color3.new(1, 1, 1),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.random(), math.random()),
			Size = UDim2.new(0, math.random(200, 600), 0, math.random(2, 6)),
			Rotation = -20,
			Parent = root,
		})
		table.insert(lines, { Frame = line, Speed = math.random(20, 60) / 100 })
	end

	local logo = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.8, 0.36), Rotation = -6, Parent = root })
	local rift = UI.label({ Text = "RIFT", Font = Theme.FontHeavy, MaxTextSize = 200, Outline = 8, Size = UDim2.fromScale(1, 0.6), Parent = logo })
	UI.new("UIGradient", { Color = ColorSequence.new(Theme.Gold, Theme.Accent), Rotation = 90, Parent = rift })
	local bg = UI.label({ Text = "BATTLEGROUNDS", Font = Theme.FontHeavy, MaxTextSize = 90, Outline = 6, Size = UDim2.fromScale(1, 0.38), Position = UDim2.fromScale(0, 0.6), Parent = logo })
	UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Accent2), Rotation = 90, Parent = bg })

	UI.ribbon({
		Text = "7 ELEMENTAL ARTS  •  5 REALMS  •  RAID BOSSES",
		Size = UDim2.fromOffset(560, 44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxTextSize = 22,
		Parent = root,
	})

	local play = UI.button({
		Text = "PLAY",
		Color = Theme.Accent,
		Size = UDim2.fromOffset(280, 80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.74),
		Rotation = -3,
		MaxTextSize = 52,
		Parent = root,
	})
	UI.label({ Text = "Click PLAY to enter the Rift", TextColor3 = Theme.SubText, MaxTextSize = 18, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromOffset(400, 26), Parent = root })

	-- Logo pulse + title camera orbit.
	local logoScale = UI.new("UIScale", { Parent = logo })
	local playScale = play:FindFirstChildOfClass("UIScale")
	local angle = 0
	local running = true
	camera.CameraType = Enum.CameraType.Scriptable
	local connection = RunService.RenderStepped:Connect(function(dt)
		angle += dt * 0.12
		camera.CameraType = Enum.CameraType.Scriptable
		local t = os.clock()
		camera.CFrame = CFrame.lookAt(Vector3.new(math.cos(angle) * 120, 55 + math.sin(t * 0.5) * 6, math.sin(angle) * 120), Vector3.new(0, 10, 0))
		logoScale.Scale = 1 + math.sin(t * 2) * 0.02
		for _, l in lines do
			local p = l.Frame.Position
			local x = p.X.Scale + l.Speed * dt
			l.Frame.Position = UDim2.fromScale(if x > 1.3 then -0.3 else x, p.Y.Scale)
		end
	end)

	play.Activated:Connect(function()
		if not running then
			return
		end
		running = false
		UI.tween(logo, 0.35, { Position = UDim2.fromScale(0.5, -0.4) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		UI.tween(play, 0.3, { Position = UDim2.fromScale(0.5, 1.3) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		if playScale then
			UI.tween(playScale, 0.2, { Scale = 1.3 })
		end
		task.wait(0.35)
		connection:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		gui:Destroy()
		Hud.Gui.Enabled = true
		Input.Enabled = true
	end)
end

return MenuController
