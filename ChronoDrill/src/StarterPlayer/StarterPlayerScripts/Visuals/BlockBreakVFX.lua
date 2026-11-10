-- BlockBreakVFX: процедурные эффекты бурения (ТЗ 9.3).
--  * Squash & Stretch блока: Y -15%, X/Z +10%, возврат за 0.08 с
--  * 4-6 кубических low-poly осколков + облачко пыли
--  * руда летит в рюкзак, всплывающие цифры урона
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local VFX = {}
local fxFolder
local squashing = {}
local BASE = Vector3.new(4, 4, 4)

local function fx()
	if not fxFolder or not fxFolder.Parent then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "ClientFX"
		fxFolder.Parent = workspace
	end
	return fxFolder
end

function VFX.Squash(part)
	if not part or not part.Parent or squashing[part] then
		return
	end
	local home = part:GetAttribute("Home")
	if typeof(home) ~= "Vector3" then
		return
	end
	squashing[part] = true
	local orig = CFrame.new(home)
	local squash = Vector3.new(BASE.X * 1.1, BASE.Y * 0.85, BASE.Z * 1.1)
	local down = orig * CFrame.new(0, -BASE.Y * 0.075, 0)
	local t1 = TweenService:Create(part, TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = squash, CFrame = down })
	local t2
	local conn
	local function finish()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		squashing[part] = nil
	end
	-- сервер переиспользует детали из пула: если блок "переехал", сразу возвращаем его на новое место
	conn = part:GetAttributeChangedSignal("Home"):Connect(function()
		t1:Cancel()
		if t2 then
			t2:Cancel()
		end
		local h = part:GetAttribute("Home")
		if typeof(h) == "Vector3" then
			part.CFrame = CFrame.new(h)
		end
		part.Size = BASE
		finish()
	end)
	t1:Play()
	t1.Completed:Connect(function(state)
		if state ~= Enum.PlaybackState.Completed or not squashing[part] then
			return
		end
		t2 = TweenService:Create(part, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = BASE, CFrame = orig })
		t2:Play()
		t2.Completed:Connect(finish)
	end)
end

local function puff(pos, color, count, size)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.CFrame = CFrame.new(pos)
	a.Parent = fx()
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size * 1.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.45, 0.8)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 6
	e.Rate = 0
	e.LightInfluence = 1
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 1.2)
end

function VFX.Sparkle(pos, color, count)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.CFrame = CFrame.new(pos)
	a.Parent = fx()
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = a
	e:Emit(count or 12)
	Debris:AddItem(a, 1)
end

function VFX.HitSpark(pos, color, crit)
	puff(pos, color, crit and 6 or 3, 0.7)
	if crit then
		VFX.Sparkle(pos, Color3.fromRGB(255, 200, 60), 10)
	end
end

local function quality()
	local ok, Detail = pcall(function()
		return require(script.Parent.Parent.Controllers.DetailController)
	end)
	return ok and Detail.Quality and Detail.Quality() or "Medium"
end

-- мягкое светящееся кольцо и вспышка света на месте сломанного блока
local function ring(pos, color)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.Material = Enum.Material.Neon
	r.Color = color:Lerp(Color3.new(1, 1, 1), 0.55)
	r.Transparency = 0.35
	r.Size = Vector3.new(0.15, 1.5, 1.5)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	r.Parent = fx()
	local light = Instance.new("PointLight")
	light.Color = r.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = r
	TweenService:Create(r, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.08, 7, 7), Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	Debris:AddItem(r, 0.4)
end

local liveShards = 0
function VFX.Break(pos, color, vein, glass)
	local q = quality()
	local n = q == "High" and math.random(6, 9) or (q == "Low" and 2 or math.random(4, 6))
	if liveShards > 70 then
		n = 2
	end
	if q ~= "Low" then
		ring(pos, color)
		VFX.Sparkle(pos, color:Lerp(Color3.new(1, 1, 1), 0.6), q == "High" and 8 or 4)
	end
	for i = 1, n do
		local s = Instance.new("Part")
		local size = 0.55 + math.random() * 0.55
		s.Size = Vector3.new(size, size, size)
		s.CFrame = CFrame.new(pos + Vector3.new(math.random() * 2 - 1, math.random() * 1.5, math.random() * 2 - 1)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		local c = color:Lerp((i % 2 == 0) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), 0.1 + math.random() * 0.1)
		s.Color = c
		s.Material = glass and Enum.Material.Glass or Enum.Material.SmoothPlastic
		s.Transparency = glass and 0.2 or 0
		s.TopSurface = Enum.SurfaceType.Smooth
		s.BottomSurface = Enum.SurfaceType.Smooth
		s.CanCollide = true
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.CollisionGroup = "Debris"
		s.Parent = fx()
		s.AssemblyLinearVelocity = Vector3.new(math.random() * 18 - 9, 14 + math.random() * 10, math.random() * 18 - 9)
		s.AssemblyAngularVelocity = Vector3.new(math.random() * 20 - 10, math.random() * 20 - 10, math.random() * 20 - 10)
		liveShards = liveShards + 1
		task.delay(0.55 + math.random() * 0.3, function()
			local tw = TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 })
			tw:Play()
			tw.Completed:Connect(function()
				s:Destroy()
				liveShards = liveShards - 1
			end)
		end)
	end
	puff(pos, color, 10, 1.4)
	if vein then
		VFX.Sparkle(pos, Color3.fromRGB(255, 230, 120), 24)
	end
end

-- Самоцвет руды летит по дуге к рюкзаку игрока
function VFX.OreFly(pos, color, character)
	local target = character and (character:FindFirstChild("EquippedPack") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart"))
	if not target then
		return
	end
	local gem = Instance.new("Part")
	gem.Size = Vector3.new(0.7, 0.7, 0.7)
	gem.Material = Enum.Material.Neon
	gem.Color = color:Lerp(Color3.new(1, 1, 1), 0.25)
	gem.Anchored = true
	gem.CanCollide = false
	gem.CanQuery = false
	gem.CanTouch = false
	gem.CastShadow = false
	gem.CFrame = CFrame.new(pos)
	gem.Parent = fx()
	local start = pos
	local t0 = os.clock()
	local dur = 0.42
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - t0) / dur)
		local tp
		if target:IsA("Model") then
			tp = target:GetPivot().Position
		else
			tp = target.Position
		end
		local mid = (start + tp) / 2 + Vector3.new(0, 6, 0)
		local a = start:Lerp(mid, t)
		local b = mid:Lerp(tp, t)
		local p = a:Lerp(b, t)
		gem.CFrame = CFrame.new(p) * CFrame.Angles(t * 8, t * 6, 0)
		gem.Size = Vector3.new(0.7, 0.7, 0.7) * (1 - t * 0.6)
		if t >= 1 then
			conn:Disconnect()
			gem:Destroy()
		end
	end)
end

-- Всплывающая цифра урона
local pool = {}
function VFX.DamageNumber(pos, text, crit)
	local holder = table.remove(pool)
	if not holder then
		holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		local bb = Instance.new("BillboardGui")
		bb.Name = "BB"
		bb.Size = UDim2.fromOffset(180, 50)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Parent = holder
		local l = Instance.new("TextLabel")
		l.Name = "L"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = Color3.fromRGB(30, 22, 40)
		st.Parent = l
	end
	holder.Parent = fx()
	local bb = holder.BB
	local l = bb.L
	l.Text = text
	l.TextColor3 = crit and Color3.fromRGB(255, 170, 40) or Color3.fromRGB(255, 255, 255)
	l.TextTransparency = 0
	l.UIStroke.Transparency = 0
	bb.Size = crit and UDim2.fromOffset(220, 64) or UDim2.fromOffset(150, 40)
	local p = pos + Vector3.new(math.random() * 2 - 1, 2.5, math.random() * 2 - 1)
	holder.CFrame = CFrame.new(p)
	local tw = TweenService:Create(holder, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(p + Vector3.new(0, 3, 0)) })
	tw:Play()
	TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1 }):Play()
	TweenService:Create(l.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { Transparency = 1 }):Play()
	task.delay(0.72, function()
		holder.Parent = nil
		table.insert(pool, holder)
	end)
end

return VFX
