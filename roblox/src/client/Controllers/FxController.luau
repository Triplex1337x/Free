-- Turns server combat events into animation + visual effects.
-- Generic effects run for everything; each element (Fire, Water, Wind,
-- Earth, Lightning, Void, Light) then layers its own signature look on top.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local GameConfig = require(Shared.Config.Game)

local Client = script.Parent.Parent
local UI = require(Client.UI)
local Vfx = require(Client.Vfx)
local Animator = require(Client.Animation.Animator)
local Clips = require(Client.Animation.Clips)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer
local rng = Random.new()

local FxController = {}

local WHITE = Color3.new(1, 1, 1)

local function elementOf(model: Instance?): string
	return model and model:GetAttribute("Element") or "Fire"
end

local function rootOf(model: Instance?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isLocal(model: Instance?): boolean
	return model ~= nil and model == player.Character
end

local function near(pos: Vector3?, dist: number): boolean
	return pos == nil or (workspace.CurrentCamera.CFrame.Position - pos).Magnitude <= dist
end

---------------------------------------------------------------------------
-- Optional uploaded animation assets (override the procedural ones)
---------------------------------------------------------------------------

local trackCache = setmetatable({}, { __mode = "k" })

local function playAsset(character: Model?, id: number?): boolean
	if not character or not id or id == 0 then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
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
	return true
end

---------------------------------------------------------------------------
-- Element-specific layers
---------------------------------------------------------------------------

local function spike(pos: Vector3, height: number, color: Color3, delay: number)
	task.delay(delay, function()
		local width = height * 0.35
		local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3))
		local rock = Vfx.Part({
			Size = Vector3.new(width, height, width),
			CFrame = cf * CFrame.new(0, -height / 2, 0),
			Color = color,
			Material = Enum.Material.Slate,
		})
		Vfx.Tween(rock, 0.12, { CFrame = cf * CFrame.new(0, height * 0.35, 0) }, Enum.EasingStyle.Back)
		task.delay(0.9, function()
			Vfx.Tween(rock, 0.4, { CFrame = cf * CFrame.new(0, -height, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.4)
			rock:Destroy()
		end)
	end)
end

local function tornado(pos: Vector3, radius: number, color: Color3, time: number)
	for i = 0, 4 do
		task.delay(i * 0.05, function()
			local cf = CFrame.new(pos + Vector3.new(0, -2 + i * 2.6, 0)) * CFrame.Angles(0, i, 0)
			Vfx.Ring(cf, radius * (0.3 + i * 0.12), radius * (0.6 + i * 0.18), color, time, 0.45, 18)
		end)
	end
end

local function skyBolts(pos: Vector3, radius: number, color: Color3, count: number)
	for i = 1, count do
		task.delay(i * 0.04, function()
			local ground = pos + Vector3.new(rng:NextNumber(-radius, radius) * 0.6, -2.5, rng:NextNumber(-radius, radius) * 0.6)
			Vfx.Lightning(ground + Vector3.new(rng:NextNumber(-6, 6), 45, rng:NextNumber(-6, 6)), ground, color, 0.6, 3.5, 0.3)
			Vfx.Emit(ground, "Sparks", 10, color)
		end)
	end
end

local Elements = {}

Elements.Fire = {
	Hit = function(pos, color)
		Vfx.Emit(pos, "Flame", 5, color)
		Vfx.Emit(pos, "Embers", 8, color)
	end,
	Swing = function(pos, color)
		Vfx.Emit(pos, "Embers", 5, color)
	end,
	Melee = function(d)
		local front = (d.CFrame * CFrame.new(0, 0, -d.Range * 0.6)).Position
		Vfx.Emit(front, "Flame", 22, d.Color)
		Vfx.Emit(front, "Embers", 16, d.Color)
	end,
	Dash = function(d)
		for i = 0, 6 do
			Vfx.Emit(d.From:Lerp(d.To, i / 6), "Flame", 5, d.Color)
		end
	end,
	Burst = function(d)
		Vfx.Emit(d.Pos, "Flame", math.clamp(d.Radius * 3, 10, 60), d.Color)
		Vfx.Emit(d.Pos, "Embers", 30, d.Color)
		Vfx.Emit(d.Pos, "Smoke", 8, Color3.fromRGB(60, 40, 35))
	end,
	Projectile = function(ball, color)
		Vfx.Attach(ball, "Flame", 45, color)
		Vfx.Attach(ball, "Embers", 18, color)
	end,
}

Elements.Water = {
	Hit = function(pos, color)
		Vfx.Debris(pos, 6, color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Size = 0.45, Speed = 32, Life = 0.7, Transparency = 0.25 })
		Vfx.Emit(pos, "Mist", 4, color)
		Vfx.Emit(pos, "Splash", 1, color)
	end,
	Swing = function(pos, color)
		Vfx.Emit(pos, "Mist", 3, color)
	end,
	Melee = function(d)
		task.delay(0.06, function()
			Vfx.Crescent(d.CFrame * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(-20)), d.Range * 0.55, d.Color, 150, 1.2, 0.35)
		end)
		Vfx.Emit((d.CFrame * CFrame.new(0, 0, -d.Range * 0.5)).Position, "Mist", 14, d.Color)
	end,
	Dash = function(d)
		for i = 0, 5 do
			Vfx.Emit(d.From:Lerp(d.To, i / 5), "Mist", 4, d.Color)
		end
	end,
	Burst = function(d)
		Vfx.Pillar(d.Pos - Vector3.new(0, 3, 0), d.Color, d.Radius * 0.3, d.Radius * 1.4, 0.7)
		Vfx.Debris(d.Pos, 14, d.Color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Glass, Size = 0.7, Speed = 55, Life = 1, Transparency = 0.2 })
		Vfx.Emit(d.Pos, "Mist", 18, d.Color)
		Vfx.Emit(d.Pos, "Splash", 2, d.Color)
	end,
	Projectile = function(ball, color)
		Vfx.Attach(ball, "Mist", 30, color)
		Vfx.Attach(ball, "Glitter", 12, WHITE)
	end,
}

Elements.Wind = {
	Hit = function(pos, color)
		Vfx.Ring(CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), 0.5, 4, color, 0.25, 0.3, 14)
		Vfx.Emit(pos, "Swirl", 1, color)
	end,
	Swing = function(pos, color)
		Vfx.Emit(pos, "Glitter", 3, color)
	end,
	Melee = function(d)
		for i = 1, 2 do
			task.delay(i * 0.05, function()
				Vfx.Crescent(d.CFrame * CFrame.new(0, 0.4 + i * 0.9, 0) * CFrame.Angles(0, 0, math.rad(i * 15)), d.Range * (0.45 + i * 0.1), d.Color, 120, 0.7, 0.3)
			end)
		end
	end,
	Dash = function(d)
		local dir = d.To - d.From
		for i = 1, 4 do
			local p = d.From:Lerp(d.To, i / 5)
			Vfx.Ring(CFrame.lookAt(p, p + dir) * CFrame.Angles(math.rad(90), 0, 0), 1, 4, d.Color, 0.3, 0.3, 16)
		end
	end,
	Burst = function(d)
		tornado(d.Pos, d.Radius, d.Color, 0.5)
		Vfx.Emit(d.Pos, "Glitter", 20, WHITE)
		Vfx.Emit(d.Pos, "Swirl", 3, d.Color)
	end,
	Projectile = function(ball, color)
		Vfx.Attach(ball, "Glitter", 25, color)
	end,
}

Elements.Earth = {
	Hit = function(pos, color)
		Vfx.Debris(pos, 3, Color3.fromRGB(120, 95, 70), { Size = 0.6, Speed = 30, Life = 1 })
		Vfx.Emit(pos, "Smoke", 3, Color3.fromRGB(150, 125, 95))
	end,
	Swing = function(pos)
		Vfx.Emit(pos, "Smoke", 2, Color3.fromRGB(150, 125, 95))
	end,
	Melee = function(d)
		for i = 1, 4 do
			local p = (d.CFrame * CFrame.new(rng:NextNumber(-1, 1), -2.8, -i * d.Range / 4)).Position
			spike(p, 4 + i, Color3.fromRGB(110, 85, 60), i * 0.03)
		end
	end,
	Dash = function(d)
		for i = 0, 4 do
			Vfx.Emit(d.From:Lerp(d.To, i / 4) - Vector3.new(0, 2.5, 0), "Smoke", 4, Color3.fromRGB(150, 125, 95))
		end
		Vfx.Debris(d.To, 6, Color3.fromRGB(110, 85, 60), { Size = 0.8, Speed = 35 })
	end,
	Burst = function(d)
		Vfx.Debris(d.Pos, math.clamp(math.floor(d.Radius), 6, 22), Color3.fromRGB(110, 85, 60), { Size = 1.4, Speed = 60, Life = 1.8 })
		Vfx.Emit(d.Pos, "Smoke", 14, Color3.fromRGB(150, 125, 95))
		local n = 8
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			spike(d.Pos + Vector3.new(math.cos(a) * d.Radius * 0.6, -2.8, math.sin(a) * d.Radius * 0.6), 5 + d.Radius * 0.2, Color3.fromRGB(110, 85, 60), i * 0.02)
		end
	end,
	Projectile = function(ball)
		Vfx.Attach(ball, "Smoke", 20, Color3.fromRGB(150, 125, 95))
	end,
}

Elements.Lightning = {
	Hit = function(pos, color)
		for _ = 1, 2 do
			local offset = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 3), rng:NextNumber(-3, 3))
			Vfx.Lightning(pos + offset, pos - offset * 0.5, color, 0.2, 1, 0.2)
		end
		Vfx.Emit(pos, "Sparks", 6, color)
	end,
	Swing = function(pos, color)
		Vfx.Lightning(pos + Vector3.new(0, 1.5, 0), pos - Vector3.new(0, 1, 0), color, 0.15, 0.8, 0.15)
	end,
	Melee = function(d)
		for i = -1, 1 do
			local from = (d.CFrame * CFrame.new(0, 0.5, -1)).Position
			local to = (d.CFrame * CFrame.Angles(0, math.rad(i * 18), 0) * CFrame.new(0, 0, -d.Range)).Position
			Vfx.Lightning(from, to, d.Color, 0.35, 1.5, 0.25)
		end
	end,
	Dash = function(d)
		for _ = 1, 2 do
			Vfx.Lightning(d.From, d.To, d.Color, 0.45, 2.5, 0.35)
		end
		Vfx.Emit(d.To, "Sparks", 14, d.Color)
	end,
	Burst = function(d)
		skyBolts(d.Pos, d.Radius, d.Color, math.clamp(math.floor(d.Radius / 3), 3, 8))
		Vfx.Flash(d.Color, 0.15, 0.25)
	end,
	Projectile = function(ball, color)
		Vfx.Attach(ball, "Sparks", 40, color)
	end,
}

Elements.Void = {
	Hit = function(pos, color)
		Vfx.Implode(pos, 3, color, 0.12)
	end,
	Swing = function(pos, color)
		Vfx.Ball(pos, 0.5, 2, Color3.fromRGB(15, 0, 30), 0.2, 0.2, Enum.Material.SmoothPlastic)
		Vfx.Emit(pos, "Mist", 2, color)
	end,
	Melee = function(d)
		task.delay(0.04, function()
			Vfx.Crescent(d.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(25)), d.Range * 0.5, Color3.fromRGB(20, 0, 40), 160, 1.6, 0.4)
		end)
	end,
	Dash = function(d)
		Vfx.Implode(d.From, 6, d.Color, 0.2)
		Vfx.Ball(d.To, 1, 9, d.Color, 0.35, 0.3)
	end,
	Burst = function(d)
		Vfx.Implode(d.Pos, d.Radius, d.Color, 0.3)
		task.delay(0.3, function()
			Vfx.Ring(CFrame.new(d.Pos - Vector3.new(0, 2.6, 0)), 1, d.Radius * 1.3, Color3.fromRGB(30, 0, 60), 0.5, 1.2, 32)
			Vfx.Emit(d.Pos, "Mist", 16, d.Color)
		end)
	end,
	Projectile = function(ball, color)
		Vfx.Attach(ball, "Mist", 35, Color3.fromRGB(40, 0, 80))
		Vfx.Attach(ball, "Glitter", 10, color)
	end,
}

Elements.Light = {
	Hit = function(pos, color)
		Vfx.Emit(pos, "Glitter", 8, Theme.Gold)
		Vfx.Rays(pos, color, 5, 4, 0.25)
		Vfx.Emit(pos, "Sunburst", 1, Theme.Gold)
	end,
	Swing = function(pos)
		Vfx.Emit(pos, "Glitter", 3, Theme.Gold)
	end,
	Melee = function(d)
		Vfx.Rays((d.CFrame * CFrame.new(0, 0, -d.Range * 0.5)).Position, d.Color, 8, d.Range * 0.6, 0.35)
	end,
	Dash = function(d)
		Vfx.Rays(d.To, d.Color, 10, 8, 0.35)
		for i = 0, 5 do
			Vfx.Emit(d.From:Lerp(d.To, i / 5), "Glitter", 4, Theme.Gold)
		end
	end,
	Burst = function(d)
		Vfx.Pillar(d.Pos - Vector3.new(0, 3, 0), d.Color, d.Radius * 0.35, 80, 0.9)
		Vfx.Rays(d.Pos, Theme.Gold, 14, d.Radius * 1.1, 0.5)
		Vfx.Emit(d.Pos, "Glitter", 30, Theme.Gold)
		Vfx.Emit(d.Pos, "Sunburst", 2, Theme.Gold)
	end,
	Projectile = function(ball)
		Vfx.Attach(ball, "Glitter", 30, Theme.Gold)
	end,
}

local function layer(element: string, kind: string, ...)
	local set = Elements[element]
	local fn = set and set[kind]
	if fn then
		fn(...)
	end
end

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------

local Handlers = {}

local function damageNumber(d, color: Color3)
	if not Vfx.DamageNumbers then
		return
	end
	local anchor = Vfx.Part({ Transparency = 1, Size = Vector3.one * 0.1, Position = d.Pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 2.5, rng:NextNumber(-1, 1)) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 56)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Adornee = anchor
	gui.Parent = anchor
	local big = (d.Damage or 0) >= 20 or d.Crit == true
	local text = if d.Crit then ("КРИТ %d!"):format(d.Damage or 0) elseif d.Immune then "НЕУЯЗВИМ" elseif d.Parried then "ПАРИРОВАНИЕ!" elseif d.Blocked then ("БЛОК %d"):format(d.Damage or 0) else tostring(d.Damage or "")
	local label = UI.label({
		Text = text,
		Font = Theme.FontHeavy,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		Rotation = rng:NextNumber(-8, 8),
		MaxTextSize = if big then 46 else 32,
		Parent = gui,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 1.8
	scale.Parent = label
	Vfx.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	Vfx.Tween(anchor, 0.8, { Position = anchor.Position + Vector3.new(0, 3.5, 0) })
	task.delay(0.45, function()
		Vfx.Tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.8, function()
		anchor:Destroy()
	end)
end

function Handlers.Hit(d)
	local attackerColor = d.Attacker and d.Attacker:GetAttribute("StyleColor")
	local color = d.Color or attackerColor or WHITE
	if d.Parried then
		color = Theme.Accent2
	elseif d.Blocked then
		color = Color3.fromRGB(170, 205, 255)
	end
	local big = (d.Damage or 0) >= 20

	-- Reaction animation on the victim.
	if d.Target then
		if d.Parried then
			Animator.Play(d.Target, Clips.Parry)
		elseif not d.Blocked then
			Animator.Play(d.Target, if big then Clips.HurtHeavy else Clips.Hurt)
		end
	end

	Vfx.Emit(d.Pos, "Sparks", if d.Blocked or d.Parried then 8 else 14, color)
	Vfx.Emit(d.Pos, "Flash", 1, color)
	if not d.Blocked then
		Vfx.Emit(d.Pos, "Impact", 1, color)
	end
	Vfx.Ball(d.Pos, 1, if big then 7 else 4, WHITE, 0.12, 0.1)
	Vfx.Ring(CFrame.new(d.Pos) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)), 0.5, if big then 6 else 3.5, color, 0.2, 0.25, 16)
	Vfx.Light(d.Pos, color, 14, 3, 0.2)
	if not d.Blocked and not d.Parried then
		layer(elementOf(d.Attacker), "Hit", d.Pos, color)
	end
	if d.Parried then
		Vfx.Ring(CFrame.new(d.Pos), 1, 8, Theme.Accent2, 0.3, 0.5, 24)
		Vfx.Emit(d.Pos, "Glitter", 14, Theme.Accent2)
	end
	damageNumber(d, color)
	Vfx.Sound(GameConfig.Sounds.Hit, d.Pos, if big then 0.9 else 0.6, if d.Blocked then 0.8 elseif big then 1.2 else rng:NextNumber(1.5, 1.8))
	if isLocal(d.Attacker) and not d.Parried and (d.Damage or 0) > 0 then
		Hud:AddHit(d.Damage)
	end

	local shake = if big then 0.45 else 0.15
	if isLocal(d.Attacker) or isLocal(d.Target) then
		shake *= 1.6
		if big then
			Vfx.FovPunch(-4, 0.2)
		end
	end
	Vfx.Shake(shake, 0.12, d.Pos)
end

function Handlers.Swing(d)
	local index = math.clamp(d.Combo or 1, 1, 4)
	if not playAsset(d.Character, GameConfig.Animations.M1[index]) then
		Animator.Play(d.Character, Clips.M1[index])
	end
	local color = d.Color or WHITE
	if d.Character then
		Vfx.LimbTrails(d.Character, color, 0.25)
	end
	Vfx.Sound(if d.Finisher then GameConfig.Sounds.Heavy else GameConfig.Sounds.Swing, d.CFrame.Position, if d.Finisher then 0.8 else 0.5, rng:NextNumber(1.05, 1.3))
	local rolls = { 35, -35, 75, 0 }
	task.delay(0.08, function()
		local cf = d.CFrame * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(rolls[index]))
		if d.Finisher then
			Vfx.Crescent(cf, 4.5, color, 220, 1.3, 0.35)
			Vfx.Ring(d.CFrame * CFrame.new(0, -2.6, 0), 1, 9, color, 0.35, 0.5, 24)
		else
			Vfx.Crescent(cf, 3.4, color, 120, 0.7, 0.22)
		end
		layer(elementOf(d.Character), "Swing", (d.CFrame * CFrame.new(0, 0, -3.5)).Position, color)
	end)
end

function Handlers.Cast(d)
	local isUlt = d.Key == "G"
	if not playAsset(d.Character, GameConfig.Animations[d.Key]) then
		Animator.Play(d.Character, Clips.Cast(d.Kind, d.Windup or 0.1, isUlt))
	end
	local root = rootOf(d.Character)
	if not root then
		return
	end
	Vfx.Sound(GameConfig.Sounds.Cast, root.Position, 0.6, rng:NextNumber(0.9, 1.1))
	if d.Character then
		Vfx.LimbTrails(d.Character, d.Color, (d.Windup or 0) + 0.4)
	end
	local windup = d.Windup or 0
	if windup >= 0.2 then
		-- Charge-up: energy sucked into the caster.
		local orb = Vfx.Part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 12, Color = d.Color, Transparency = 0.85, CFrame = root.CFrame })
		local follow = game:GetService("RunService").RenderStepped:Connect(function()
			orb.CFrame = root.CFrame
		end)
		Vfx.Tween(orb, windup, { Size = Vector3.one * 2.5, Transparency = 0.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Vfx.Emit(root.Position, "Glitter", 12, d.Color)
		Vfx.ChargeOrb(root, d.Color, windup)
		task.delay(windup, function()
			follow:Disconnect()
			orb:Destroy()
		end)
	end
end

function Handlers.Melee(d)
	local cf = d.CFrame * CFrame.new(0, 0.6, 0)
	Vfx.Crescent(cf, d.Range * 0.6, d.Color, 150, 1.4, 0.3)
	Vfx.Ring(cf * CFrame.new(0, 0, -d.Range * 0.8) * CFrame.Angles(math.rad(90), 0, 0), 0.5, d.Width * 0.7, d.Color, 0.25, 0.4, 20)
	layer(elementOf(d.Character), "Melee", d)
	Vfx.Shake(0.25, 0.12, d.CFrame.Position)
end

function Handlers.Dash(d)
	local length = (d.To - d.From).Magnitude
	if length < 0.5 then
		return
	end
	local cf = CFrame.lookAt(d.From:Lerp(d.To, 0.5), d.To)
	local beam = Vfx.Part({ Size = Vector3.new(1.6, 1.6, length), CFrame = cf, Color = d.Color, Transparency = 0.15 })
	Vfx.Fade(beam, 0.35, { Size = Vector3.new(0.05, 0.05, length) })
	local core = Vfx.Part({ Size = Vector3.new(0.5, 0.5, length), CFrame = cf, Color = WHITE, Transparency = 0 })
	Vfx.Fade(core, 0.2)
	if d.Character then
		Vfx.Afterimages(d.Character, d.From, d.To, d.Color, 5)
	end
	Vfx.Ball(d.From, 1, 6, d.Color, 0.3, 0.3)
	Vfx.Ball(d.To, 1, 6, d.Color, 0.3, 0.3)
	layer(elementOf(d.Character), "Dash", d)
	if isLocal(d.Character) then
		Vfx.SpeedLines(0.35, d.Color)
		Vfx.FovPunch(12, 0.4)
	end
end

function Handlers.Burst(d)
	local hits = math.max(1, d.Hits or 1)
	local element = elementOf(d.Character)
	task.spawn(function()
		for i = 1, hits do
			Vfx.Ball(d.Pos, 2, d.Radius * 2, d.Color, 0.4, 0.35)
			Vfx.Ball(d.Pos, 1, d.Radius * 0.9, WHITE, 0.18, 0.1)
			Vfx.Ring(CFrame.new(d.Pos - Vector3.new(0, 2.6, 0)), 1, d.Radius * 1.15, d.Color, 0.45, if d.Small then 0.4 else 0.9, 32)
			Vfx.Light(d.Pos, d.Color, d.Radius * 2.5, 5, 0.4)
			if i == 1 or i == hits then
				layer(element, "Burst", d)
			end
			if i == 1 then
				Vfx.GroundDecal(d.Pos, "ShockwaveRing", d.Radius * 0.6, d.Color, 0.05, 0.4, 3.2)
				if not d.Small and (d.Radius >= 14 or element == "Earth") then
					Vfx.GroundDecal(d.Pos, "GroundCrack", d.Radius * 1.6, Color3.fromRGB(30, 22, 18), 2.5, 1.2)
					Vfx.GroundDecal(d.Pos, "GroundCrack", d.Radius * 1.6, d.Color, 0.3, 0.8)
				end
			end
			local strength = math.clamp(d.Radius / 25, 0.15, 0.9)
			Vfx.Shake(strength, 0.25, d.Pos)
			if not d.Small and d.Radius >= 18 and near(d.Pos, 90) then
				Vfx.ImpactFrame()
			end
			if i < hits then
				task.wait(d.Interval or 0.15)
			end
		end
	end)
end

function Handlers.GuardBreak(d)
	Vfx.Ring(CFrame.new(d.Pos), 1, 9, Theme.Bad, 0.3, 0.6, 24)
	Vfx.Emit(d.Pos, "Sparks", 20, Theme.Bad)
	Vfx.Shake(0.4, 0.15, d.Pos)
	if d.Target then
		Animator.Play(d.Target, Clips.HurtHeavy)
	end
end

-- Ultimate: no full-screen text. The caster becomes a beacon — golden
-- glow, energy dome, spinning rings, light pillar — then a huge release.
function Handlers.Ultimate(d)
	local root = rootOf(d.Character)
	local pos = root and root.Position
	if not root or not near(pos, 200) then
		return
	end
	local windup = d.Windup or 0.6
	local color = d.Color or Theme.Gold
	local caster = isLocal(d.Character)

	Vfx.Sound(GameConfig.Sounds.Cast, pos, 1, 0.7)
	Vfx.Shake(0.35, windup, pos)
	if caster then
		Vfx.FovPunch(-8, windup + 0.3)
	end

	-- Energy dome that breathes during the charge.
	local dome = Vfx.Part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Position = pos, Color = color, Transparency = 0.55, Material = Enum.Material.ForceField })
	Vfx.Tween(dome, windup, { Size = Vector3.one * 22, Transparency = 0.3 }, Enum.EasingStyle.Sine)
	-- Three spinning rings around the caster.
	local rings = {}
	for i = 1, 3 do
		local ring = Vfx.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 10 + i * 4, 10 + i * 4), Color = if i == 2 then Color3.new(1, 1, 1) else color, Transparency = 0.35, CFrame = root.CFrame })
		rings[i] = ring
	end
	-- Light pillar + rising sparks.
	Vfx.Pillar(pos - Vector3.new(0, 3, 0), color, 5, 160, windup + 0.6)
	Vfx.Emit(pos, "Glitter", 40, color)
	local start = os.clock()
	local follow = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - start
		local p = root.Position
		dome.Position = p
		for i, ring in rings do
			ring.CFrame = CFrame.new(p) * CFrame.Angles(t * (2 + i), t * (3 - i), math.rad(90) + t * i)
		end
	end)

	task.delay(windup, function()
		follow:Disconnect()
		for _, ring in rings do
			Vfx.Fade(ring, 0.3, { Size = ring.Size * 2.5 })
		end
		Vfx.Fade(dome, 0.35, { Size = Vector3.one * 70 })
		local p = root.Parent and root.Position or pos
		-- Release: stacked shockwaves, flash, cracks, impact frame.
		for i = 0, 2 do
			task.delay(i * 0.08, function()
				Vfx.Ring(CFrame.new(p - Vector3.new(0, 2.6, 0)), 2, 30 + i * 18, if i == 1 then Color3.new(1, 1, 1) else color, 0.6, 1.2, 40)
			end)
		end
		Vfx.Ball(p, 4, 46, color, 0.5, 0.2)
		Vfx.Ball(p, 2, 24, Color3.new(1, 1, 1), 0.25, 0)
		Vfx.Rays(p, color, 18, 40, 0.6)
		Vfx.GroundDecal(p, "GroundCrack", 50, color, 2, 1.5)
		Vfx.Debris(p, 18, Color3.fromRGB(110, 95, 90), { Size = 1.6, Speed = 70, Life = 2 })
		Vfx.Sound(GameConfig.Sounds.Heavy, p, 1, 0.6)
		if near(p, 120) then
			Vfx.ImpactFrame()
			Vfx.Flash(color, 0.35, 0.6)
			Vfx.Shake(0.9, 0.5, p)
		end
		if caster then
			Vfx.SpeedLines(0.5, color)
		end
	end)
end

function Handlers.CounterStance(d)
	Animator.Play(d.Character, Clips.Block)
	task.delay(0.45, function()
		Animator.Stop(d.Character, "State", Clips.Block)
	end)
	local root = rootOf(d.Character)
	if root then
		Vfx.Ring(CFrame.new(root.Position) * CFrame.Angles(math.rad(90), 0, 0), 1, 6, Theme.Accent2, 0.4, 0.3, 24)
		Vfx.Ball(root.Position, 8, 4, Theme.Accent2, 0.4, 0.7, Enum.Material.ForceField)
	end
end

function Handlers.Counter(d)
	Animator.Play(d.Character, Clips.Parry)
	local root = rootOf(d.Character)
	if root then
		Vfx.Afterimages(d.Character, root.Position + root.CFrame.LookVector * -6, root.Position, Theme.Accent2, 4)
	end
	Vfx.Ball(d.Pos, 2, 14, Color3.new(1, 1, 1), 0.25, 0)
	Vfx.Ring(CFrame.new(d.Pos), 1, 14, Theme.Accent2, 0.4, 0.8, 32)
	Vfx.Emit(d.Pos, "Sparks", 30, Theme.Accent2)
	Vfx.Sound(GameConfig.Sounds.Heavy, d.Pos, 1, 1.4)
	if isLocal(d.Character) or isLocal(d.Target) then
		Vfx.ImpactFrame()
		Vfx.Shake(0.6, 0.25, d.Pos)
	end
	Hud:Toast(if isLocal(d.Character) then "КОНТРАТАКА!" else "ТЕБЯ КОНТРАТАКОВАЛИ!", if isLocal(d.Character) then "success" else "error")
end

function Handlers.Chain(d)
	Vfx.Lightning(d.From, d.To, d.Color or Theme.Gold, 0.35, 1.5, 0.3)
	Vfx.Emit(d.To, "Sparks", 8, d.Color or Theme.Gold)
end

function Handlers.Shatter(d)
	Vfx.Emit(d.Pos, "Smoke", 10, Color3.fromRGB(160, 140, 120))
	Vfx.Ring(CFrame.new(d.Pos - Vector3.new(0, 1.5, 0)), 1, 8, d.Color, 0.35, 0.4, 20)
	Vfx.Sound(GameConfig.Sounds.Hit, d.Pos, 0.8, 0.7)
	Vfx.Shake(0.2, 0.15, d.Pos)
end

function Handlers.LevelUp(d)
	Animator.Play(d.Character, Clips.LevelUp)
	local root = rootOf(d.Character)
	if not root then
		return
	end
	Vfx.Pillar(root.Position - Vector3.new(0, 3, 0), Theme.Gold, 3, 40, 1)
	Vfx.Rays(root.Position, Theme.Gold, 12, 7, 0.6)
	Vfx.Emit(root.Position, "Glitter", 30, Theme.Gold)
	Vfx.Ring(CFrame.new(root.Position - Vector3.new(0, 2.6, 0)), 1, 10, Theme.Gold, 0.6, 0.5, 28)
end

function Handlers.AirJump(d)
	local root = rootOf(d.Character)
	if not root then
		return
	end
	local color = d.Character:GetAttribute("StyleColor") or Color3.new(1, 1, 1)
	local pos = root.Position - Vector3.new(0, 2.5, 0)
	Vfx.Ring(CFrame.new(pos), 0.5, if d.Count == 2 then 6 else 4.5, color, 0.3, 0.35, 20)
	Vfx.Emit(pos, "Mist", 6, Color3.new(1, 1, 1))
	if d.Count == 2 then
		Vfx.Emit(pos, "Glitter", 10, color)
	end
	Animator.Play(d.Character, Clips.AirFlip)
end

function Handlers.Potion(d)
	local root = rootOf(d.Character)
	if not root then
		return
	end
	Vfx.Emit(root.Position, "Glitter", 24, d.Color)
	Vfx.Ring(CFrame.new(root.Position - Vector3.new(0, 2.6, 0)), 1, 7, d.Color, 0.5, 0.4, 24)
	Vfx.Ball(root.Position, 2, 8, d.Color, 0.4, 0.5)
	if isLocal(d.Character) then
		Vfx.Flash(d.Color, 0.2, 0.4)
	end
end

function Handlers.Teleport(d)
	local root = rootOf(d.Character)
	if not root then
		return
	end
	Vfx.Pillar(root.Position - Vector3.new(0, 3, 0), d.Color, 4, 60, 0.8)
	Vfx.Ring(CFrame.new(root.Position - Vector3.new(0, 2.6, 0)), 1, 12, d.Color, 0.5, 0.6, 28)
	Vfx.Emit(root.Position, "Glitter", 30, d.Color)
	if isLocal(d.Character) then
		Vfx.Flash(d.Color, 0.5, 0.6)
		Vfx.SpeedLines(0.5, d.Color)
	end
end

function Handlers.KillFeed(d)
	Hud:KillFeed(d.Killer, d.Victim)
end

---------------------------------------------------------------------------
-- Persistent visuals: block / stun poses, awakening aura, projectiles
---------------------------------------------------------------------------

local function watchModel(model: Model)
	local function onBlocking()
		if model:GetAttribute("Blocking") then
			if not playAsset(model, GameConfig.Animations.Block) then
				Animator.Play(model, Clips.Block)
			end
		else
			Animator.Stop(model, "State", Clips.Block)
		end
	end
	local function onStunned()
		if model:GetAttribute("Stunned") then
			if not model:GetAttribute("Blocking") then
				Animator.Play(model, Clips.Stunned)
			end
		else
			Animator.Stop(model, "State", Clips.Stunned)
		end
	end
	model:GetAttributeChangedSignal("Blocking"):Connect(onBlocking)
	model:GetAttributeChangedSignal("Stunned"):Connect(onStunned)

	-- Dizzy stars orbiting the head while stunned.
	local stars = nil
	model:GetAttributeChangedSignal("Stunned"):Connect(function()
		if model:GetAttribute("Stunned") and not stars then
			local head = model:FindFirstChild("Head") :: BasePart?
			if not head then
				return
			end
			local parts = {}
			for i = 1, 3 do
				parts[i] = Vfx.Part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = Theme.Gold })
			end
			local t0 = os.clock()
			stars = game:GetService("RunService").RenderStepped:Connect(function()
				if not head.Parent then
					return
				end
				local t = os.clock() - t0
				for i, part in parts do
					local a = t * 6 + i * 2.1
					part.Position = head.Position + Vector3.new(math.cos(a) * 1.4, head.Size.Y * 0.9 + math.sin(t * 8 + i) * 0.15, math.sin(a) * 1.4)
				end
			end)
			model:GetAttributeChangedSignal("Stunned"):Once(function()
				if stars then
					stars:Disconnect()
					stars = nil
				end
				for _, part in parts do
					part:Destroy()
				end
			end)
		end
	end)

	-- Burning (Ember passive): flames on the torso while it lasts.
	model:GetAttributeChangedSignal("Burning"):Connect(function()
		local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
		local existing = torso and torso:FindFirstChild("RiftBurn")
		if model:GetAttribute("Burning") and torso and not existing then
			local attachment = Instance.new("Attachment")
			attachment.Name = "RiftBurn"
			attachment.Parent = torso
			Vfx.Attach(attachment, "Flame", 18, Color3.fromRGB(255, 120, 40))
		elseif not model:GetAttribute("Burning") and existing then
			existing:Destroy()
		end
	end)

	-- Hyper armor = golden outline; invulnerable (ultimate) = golden glow.
	local function armorVisual()
		local glow = model:FindFirstChild("RiftArmorGlow")
		local armored = model:GetAttribute("HyperArmor") or model:GetAttribute("Invulnerable")
		if armored and not glow then
			glow = Instance.new("Highlight")
			glow.Name = "RiftArmorGlow"
			glow.FillColor = Theme.Gold
			glow.OutlineColor = Color3.fromRGB(255, 240, 180)
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.Parent = model
		elseif not armored and glow then
			glow:Destroy()
			return
		end
		if glow then
			glow.FillTransparency = if model:GetAttribute("Invulnerable") then 0.55 else 1
			glow.OutlineTransparency = 0
		end
	end
	model:GetAttributeChangedSignal("HyperArmor"):Connect(armorVisual)
	model:GetAttributeChangedSignal("Invulnerable"):Connect(armorVisual)
end

local function watchPlayer(p: Player)
	local cleanup: (() -> ())? = nil
	local function refreshAura()
		local character = p.Character
		local full = (p:GetAttribute("Awakening") or 0) >= GameConfig.Awakening.Max
		if full and character and not cleanup then
			local color = character:GetAttribute("StyleColor") or Theme.Accent
			cleanup = Vfx.Aura(character, color, character:GetAttribute("Element"))
		elseif (not full or not character) and cleanup then
			cleanup()
			cleanup = nil
		end
	end
	p:GetAttributeChangedSignal("Awakening"):Connect(refreshAura)
	p.CharacterAdded:Connect(function(character)
		if cleanup then
			cleanup()
			cleanup = nil
		end
		watchModel(character)
		task.defer(refreshAura)
	end)
	if p.Character then
		watchModel(p.Character)
		refreshAura()
	end
end

local function decorateProjectile(ball: Instance)
	if not ball:IsA("BasePart") then
		return
	end
	task.defer(function()
		layer(ball:GetAttribute("Element") or "Fire", "Projectile", ball, ball.Color)
	end)
end

---------------------------------------------------------------------------

local function systemMessage(text: string)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage('<font color="#FFD23C">[Разлом] ' .. text .. "</font>")
		end
	end)
end

function FxController:Start()
	Remotes.Fx.OnClientEvent:Connect(function(kind, payload)
		local handler = Handlers[kind]
		if handler and type(payload) == "table" then
			local ok, err = pcall(handler, payload)
			if not ok then
				warn("[Fx] " .. tostring(kind) .. ": " .. tostring(err))
			end
		end
	end)

	-- Short controlled push (LinearVelocity) — no spinning ragdoll.
	Remotes.Knockback.OnClientEvent:Connect(function(velocity: Vector3, duration: number?)
		local character = player.Character
		local root = rootOf(character)
		if not root or typeof(velocity) ~= "Vector3" then
			return
		end
		local old = root:FindFirstChild("KnockbackPush")
		if old then
			old:Destroy()
		end
		local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
		if not attachment then
			root.AssemblyLinearVelocity = velocity
			return
		end
		local push = Instance.new("LinearVelocity")
		push.Name = "KnockbackPush"
		push.Attachment0 = attachment
		push.MaxForce = 1e6
		push.VectorVelocity = velocity
		push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.Parent = root
		task.delay(duration or 0.18, function()
			push:Destroy()
		end)
		if velocity.Magnitude > 40 then
			Vfx.SpeedLines(0.25)
		end
	end)

	Remotes.Announce.OnClientEvent:Connect(function(text)
		systemMessage(text)
		Hud:Toast(text, "level")
	end)

	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	local npcs = workspace:WaitForChild("NPCs", 10)
	if npcs then
		for _, model in npcs:GetChildren() do
			watchModel(model)
		end
		npcs.ChildAdded:Connect(watchModel)
		local function walker(model)
			task.defer(function()
				if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
					Animator.EnableLocomotion(model)
				end
			end)
		end
		for _, model in npcs:GetChildren() do
			walker(model)
		end
		npcs.ChildAdded:Connect(walker)
	end

	local projectiles = workspace:WaitForChild("Projectiles", 10)
	if projectiles then
		projectiles.ChildAdded:Connect(decorateProjectile)
	end
end

return FxController
