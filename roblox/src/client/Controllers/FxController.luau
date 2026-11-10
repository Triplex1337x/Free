-- Client-side visuals: hit sparks, damage numbers, slashes, dashes, bursts,
-- ultimate cut-ins, camera shake, knockback, animations, chat announcements.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local GameConfig = require(Shared.Config.Game)

local UI = require(script.Parent.Parent.UI)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FxController = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFx"
fxFolder.Parent = workspace

local shakeUntil, shakeStrength = 0, 0

local function tween(inst, time, goal, style)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function neon(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		p[k] = v
	end
	p.Parent = fxFolder
	return p
end

local function fadeAndDestroy(part: BasePart, time: number, goal)
	goal = goal or {}
	goal.Transparency = 1
	tween(part, time, goal)
	task.delay(time, function()
		part:Destroy()
	end)
end

local function shake(strength: number, duration: number, origin: Vector3?)
	if origin then
		local d = (camera.CFrame.Position - origin).Magnitude
		strength *= math.clamp(1 - d / 140, 0, 1)
	end
	if strength <= 0 then
		return
	end
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

---------------------------------------------------------------------------
-- Animations (optional, from GameConfig.Animations)
---------------------------------------------------------------------------

local trackCache = setmetatable({}, { __mode = "k" })

local function playAnimation(character: Model?, id: number?)
	if not character or not id or id == 0 then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local cache = trackCache[animator]
	if not cache then
		cache = {}
		trackCache[animator] = cache
	end
	local track = cache[id]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. id
		track = animator:LoadAnimation(animation)
		cache[id] = track
	end
	track:Play(0.05)
end

---------------------------------------------------------------------------
-- Effect handlers
---------------------------------------------------------------------------

local Handlers = {}

function Handlers.Hit(d)
	local color = d.Color or Color3.new(1, 1, 1)
	if d.Parried then
		color = Theme.Accent2
	elseif d.Blocked then
		color = Color3.fromRGB(170, 200, 255)
	end

	local sparks = if d.Blocked or d.Parried then 3 else 6
	for _ = 1, sparks do
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.2, math.random() - 0.5).Unit
		local spark = neon({ Size = Vector3.new(0.25, 0.25, 1.6), Color = color, CFrame = CFrame.lookAt(d.Pos, d.Pos + dir) })
		fadeAndDestroy(spark, 0.25, { CFrame = spark.CFrame * CFrame.new(0, 0, -3), Size = Vector3.new(0.05, 0.05, 0.4) })
	end

	local anchor = neon({ Transparency = 1, Size = Vector3.one * 0.1, Position = d.Pos + Vector3.new(math.random() * 2 - 1, 2.5, 0) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Adornee = anchor
	gui.Parent = anchor
	local text = if d.Parried then "PARRY!" elseif d.Blocked then ("BLOCK %d"):format(d.Damage or 0) else tostring(d.Damage or "")
	local label = UI.label({
		Text = text,
		Font = Theme.FontHeavy,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		MaxTextSize = if (d.Damage or 0) >= 20 then 40 else 30,
		Parent = gui,
	})
	tween(anchor, 0.7, { Position = anchor.Position + Vector3.new(0, 3, 0) })
	tween(label, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.7, function()
		anchor:Destroy()
	end)
	shake(if (d.Damage or 0) >= 20 then 0.35 else 0.12, 0.12, d.Pos)
end

function Handlers.Swing(d)
	local index = math.clamp(d.Combo or 1, 1, 4)
	playAnimation(d.Character, GameConfig.Animations.M1[index])
	local side = if index % 2 == 0 then -1 else 1
	local cf = d.CFrame * CFrame.new(0, 0.5, -3.5) * CFrame.Angles(0, 0, math.rad(35 * side))
	local slash = neon({ Size = Vector3.new(if d.Finisher then 9 else 6, 0.2, 1.2), Color = d.Color, Transparency = 0.2, CFrame = cf })
	fadeAndDestroy(slash, 0.18, { CFrame = cf * CFrame.Angles(0, math.rad(-60 * side), 0), Size = slash.Size * Vector3.new(1.3, 1, 0.3) })
end

function Handlers.Cast(d)
	playAnimation(d.Character, GameConfig.Animations[d.Key])
	local root = d.Character and d.Character:FindFirstChild("HumanoidRootPart")
	if not root or (d.Windup or 0) < 0.2 then
		return
	end
	local orb = neon({ Shape = Enum.PartType.Ball, Size = Vector3.one * 10, Color = d.Color, Transparency = 0.85, CFrame = root.CFrame })
	local follow = RunService.RenderStepped:Connect(function()
		orb.CFrame = root.CFrame
	end)
	tween(orb, d.Windup, { Size = Vector3.one * 2, Transparency = 0.3 })
	task.delay(d.Windup, function()
		follow:Disconnect()
		orb:Destroy()
	end)
end

function Handlers.Melee(d)
	local cf = d.CFrame * CFrame.new(0, 0, -d.Range / 2)
	local box = neon({ Size = Vector3.new(d.Width, 0.3, d.Range), Color = d.Color, Transparency = 0.3, CFrame = cf * CFrame.new(0, 0.5, 0) })
	fadeAndDestroy(box, 0.25, { Size = Vector3.new(d.Width * 1.4, 0.1, d.Range * 1.2) })
	local wave = neon({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = d.Color, Transparency = 0.2, CFrame = d.CFrame * CFrame.new(0, 0, -d.Range) })
	fadeAndDestroy(wave, 0.3, { Size = Vector3.one * d.Width })
	shake(0.2, 0.1, d.CFrame.Position)
end

function Handlers.Dash(d)
	local length = (d.To - d.From).Magnitude
	if length < 0.5 then
		return
	end
	local cf = CFrame.lookAt(d.From:Lerp(d.To, 0.5), d.To)
	local beam = neon({ Size = Vector3.new(1.4, 1.4, length), Color = d.Color, Transparency = 0.1, CFrame = cf })
	fadeAndDestroy(beam, 0.35, { Size = Vector3.new(0.1, 0.1, length) })
	for _, pos in { d.From, d.To } do
		local puff = neon({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = d.Color, Transparency = 0.3, Position = pos })
		fadeAndDestroy(puff, 0.3, { Size = Vector3.one * 7 })
	end
end

function Handlers.Burst(d)
	local hits = math.max(1, d.Hits or 1)
	task.spawn(function()
		for i = 1, hits do
			local sphere = neon({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = d.Color, Transparency = 0.2, Position = d.Pos })
			fadeAndDestroy(sphere, 0.35, { Size = Vector3.one * d.Radius * 2 })
			local ring = neon({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 2, 2),
				Color = d.Color,
				Transparency = 0.1,
				CFrame = CFrame.new(d.Pos.X, d.Pos.Y - 2.6, d.Pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			})
			fadeAndDestroy(ring, 0.5, { Size = Vector3.new(0.1, d.Radius * 2.4, d.Radius * 2.4) })
			shake(math.clamp(d.Radius / 30, 0.15, 0.8), 0.2, d.Pos)
			if i < hits then
				task.wait(d.Interval or 0.15)
			end
		end
	end)
end

function Handlers.GuardBreak(d)
	local ring = neon({ Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = Theme.Bad, Transparency = 0.2, Position = d.Pos })
	fadeAndDestroy(ring, 0.3, { Size = Vector3.one * 10 })
end

function Handlers.Ultimate(d)
	local root = d.Character and d.Character:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position
	if pos and (camera.CFrame.Position - pos).Magnitude > 160 then
		return
	end
	shake(0.6, 0.6, pos)

	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = d.Color
	cc.Brightness = 0.25
	cc.Parent = Lighting
	tween(cc, 0.8, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	task.delay(0.8, function()
		cc:Destroy()
	end)

	-- Anime-style cut-in banner.
	local banner = UI.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.5, 0.32),
		Size = UDim2.new(1.2, 0, 0, 80),
		Rotation = -4,
		Parent = Hud.Gui,
	}, { UI.stroke(d.Color, 3, 0) })
	UI.label({ Text = (d.Caster or "") .. " — " .. (d.Name or ""), Font = Theme.FontHeavy, TextColor3 = d.Color, TextStrokeTransparency = 0, MaxTextSize = 46, Parent = banner })
	tween(banner, 0.25, { Position = UDim2.fromScale(0.5, 0.32) }, Enum.EasingStyle.Back)
	task.delay(1.2, function()
		tween(banner, 0.25, { Position = UDim2.fromScale(1.6, 0.32) })
		task.wait(0.25)
		banner:Destroy()
	end)
end

function Handlers.LevelUp(d)
	local root = d.Character and d.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pillar = neon({ Size = Vector3.new(6, 30, 6), Color = Theme.Gold, Transparency = 0.4, CFrame = root.CFrame * CFrame.new(0, 12, 0) })
	fadeAndDestroy(pillar, 0.9, { Size = Vector3.new(0.2, 40, 0.2) })
end

function Handlers.KillFeed(d)
	Hud:KillFeed(d.Killer, d.Victim)
end

---------------------------------------------------------------------------

local function systemMessage(text: string)
	local ok = pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage('<font color="#FFD23C">[Rift] ' .. text .. "</font>")
		end
	end)
	if not ok then
		warn(text)
	end
end

function FxController:Start()
	Remotes.Fx.OnClientEvent:Connect(function(kind, payload)
		local handler = Handlers[kind]
		if handler and type(payload) == "table" then
			local ok, err = pcall(handler, payload)
			if not ok then
				warn("[Fx] " .. kind .. ": " .. tostring(err))
			end
		end
	end)

	Remotes.Knockback.OnClientEvent:Connect(function(velocity: Vector3)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and typeof(velocity) == "Vector3" then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			root.AssemblyLinearVelocity = velocity
		end
	end)

	Remotes.Announce.OnClientEvent:Connect(function(text)
		systemMessage(text)
		Hud:Toast(text, "level")
	end)

	RunService:BindToRenderStep("RiftCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		if now < shakeUntil then
			local s = shakeStrength
			camera.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
		else
			shakeStrength = 0
		end
	end)
end

return FxController
