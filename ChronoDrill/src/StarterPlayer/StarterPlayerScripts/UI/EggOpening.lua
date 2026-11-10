-- EggOpening: анимация открытия яиц.
-- Обычное открытие: наезд камеры -> «зарядка» (раскачка, подпрыгивания, пульс кольца, разгон лучей) ->
-- вспышка, ударная волна и искры цвета редкости -> питомец влетает с разворотом, за ним крутятся лучи,
-- снизу имя, плашка редкости и чипы урона/продажи. Очень редкие — отдельная кинематографичная сцена.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local PetsData = require(Configs:WaitForChild("PetsData"))
local EggsData = require(Configs:WaitForChild("EggsData"))
local SeedsData = require(Configs:WaitForChild("SeedsData"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local GearBuilder = require(Shared:WaitForChild("GearBuilder"))

local UI = require(script.Parent.UIKit)

local EggOpening = {}
local gui, overlay, flash, row, hint
local cineBack, cineFront -- отдельные слои для эпичного выпадения: фон/лучи ниже 3D-сцены
local playing = false
local queue = {}
local ctxRef

local function anchorAll(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
end

local function fadeModel(model, t)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
		end
	end
end

-- «Тень»: питомец становится чёрным силуэтом (для неизвестных питомцев и драматичного появления)
local function silhouette(model)
	local saved = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			saved[d] = { d.Color, d.Material, d.Reflectance }
			d.Color = Color3.fromRGB(12, 10, 20)
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Fire") then
			saved[d] = d.Enabled
			d.Enabled = false
		end
	end
	return function()
		for inst, v in pairs(saved) do
			if inst.Parent then
				if type(v) == "table" then
					inst.Color, inst.Material, inst.Reflectance = v[1], v[2], v[3]
				else
					inst.Enabled = v
				end
			end
		end
	end
end
EggOpening.Silhouette = silhouette

local function isRare(petId)
	local def = PetsData.ById[petId]
	return def ~= nil and (def.Rarity == "Mythic" or def.Rarity == "Legendary" or (def.Chance > 0 and def.Chance <= 1))
end
EggOpening.IsRare = isRare

-- плавная анимация числа: fn(k) вызывается каждый кадр, k от 0 до 1 (с easing)
local function animate(duration, fn, style, dir)
	local t = 0
	local es = style or Enum.EasingStyle.Quad
	local ed = dir or Enum.EasingDirection.Out
	fn(0)
	while t < duration do
		local dt = RunService.RenderStepped:Wait()
		t = math.min(duration, t + dt)
		fn(TweenService:GetValue(t / duration, es, ed))
	end
end

local function rarityOf(petId, tier)
	local def = PetsData.ById[petId]
	local r = def and PetsData.Rarity[def.Rarity]
	local rc = r and Color3.fromRGB(r.Color[1], r.Color[2], r.Color[3]) or Color3.fromRGB(150, 148, 170)
	if tier == 6 then
		rc = Color3.fromRGB(90, 210, 255)
	end
	return def, r, rc, (r and r.Index or 1)
end

-- лучи за питомцем: 12 полос с мягкими концами, крутятся; цвет и яркость задаются при раскрытии
local function makeRays(parent, size, z)
	local holder = UI.new("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = z, Parent = parent })
	local rays = {}
	for k = 0, 11 do
		local wide = k % 2 == 0
		local ray = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, wide and math.floor(size * 0.12) or math.floor(size * 0.05), 1, 0), Rotation = k * 15, ZIndex = z, Parent = holder })
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = ray
		table.insert(rays, ray)
	end
	return holder, rays
end

local function setRays(rays, color, transparency, t)
	for _, ray in ipairs(rays) do
		if t and t > 0 then
			TweenService:Create(ray, TweenInfo.new(t), { BackgroundColor3 = color, BackgroundTransparency = transparency }):Play()
		else
			ray.BackgroundColor3 = color
			ray.BackgroundTransparency = transparency
		end
	end
end

-- взрыв в слоте: ударная волна-кольцо и разлёт искр-ромбиков цвета редкости
local function slotBurst(slot, col, strength)
	local c = slot.center
	local wave = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), ZIndex = 6, Parent = c })
	UI.Corner(wave, UDim.new(1, 0))
	local ws = UI.Stroke(wave, 10, UI.Lighter(col, 0.25))
	TweenService:Create(wave, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(slot.size * 1.5, slot.size * 1.5) }):Play()
	TweenService:Create(ws, TweenInfo.new(0.55), { Transparency = 1, Thickness = 2 }):Play()
	task.delay(0.6, function()
		wave:Destroy()
	end)
	for i = 1, 8 + strength * 3 do
		local ang = (i / (8 + strength * 3)) * math.pi * 2 + math.random() * 0.4
		local dist = slot.size * (0.45 + math.random() * 0.35)
		local sz = math.random(8, 16)
		local st = UI.new("Frame", { BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or UI.Lighter(col, 0.2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(sz, sz), Rotation = 45, ZIndex = 7, Parent = c })
		UI.Corner(st, 3)
		TweenService:Create(st, TweenInfo.new(0.7 + math.random() * 0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist),
			BackgroundTransparency = 1,
			Rotation = 45 + math.random(-160, 160),
			Size = UDim2.fromOffset(sz * 0.3, sz * 0.3),
		}):Play()
		task.delay(1.1, function()
			st:Destroy()
		end)
	end
end

-- маленький чип «иконка + множитель» под питомцем
local function statChip(parent, glyph, order, h)
	local f = UI.new("Frame", { Size = UDim2.fromOffset(0, h), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, ZIndex = 4, Parent = parent })
	UI.Glass(f, UDim.new(1, 0), 0.12)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	UI.List(f, 4, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center)
	local icHolder = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(h, h), LayoutOrder = 1, ZIndex = 5, Parent = f })
	local ic = require(script.Parent.Icons2D).New(icHolder, glyph, h - 4, { ZIndex = 5, Shadow = false })
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	local l = UI.Text(f, "", { Size = UDim2.fromOffset(0, h - 8), AutomaticSize = Enum.AutomaticSize.X, TextScaled = false, TextSize = math.floor(h * 0.62), MaxText = math.floor(h * 0.62), LayoutOrder = 2, ZIndex = 5, StrokeThickness = 1.6 })
	l.Size = UDim2.fromOffset(0, h - 8)
	return f, l
end

-- слот: лучи и круглая подложка за питомцем (подложка — фон самого ViewportFrame, всегда ПОД питомцем),
-- ниже имя, плашка редкости и чипы урона/продажи
local function slotFrame(i, n)
	local compact = n > 3
	local w = (n == 1) and 460 or (compact and 270 or 340)
	local h = compact and 270 or 480
	local vpH = compact and 180 or 340
	local f = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), LayoutOrder = i, Parent = row })
	local center = UI.new("Frame", { Name = "Center", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, vpH / 2), Size = UDim2.fromOffset(vpH, vpH), ZIndex = 2, Parent = f })
	local raysHolder, rays = makeRays(center, math.floor(vpH * 1.55), 2)
	local vp = UI.new("ViewportFrame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 186, 206),
		LightColor = Color3.fromRGB(255, 252, 245),
		LightDirection = Vector3.new(-0.3, -1, -0.5),
		ZIndex = 3,
		Parent = center,
	})
	UI.Corner(vp, UDim.new(1, 0))
	local ring = UI.Stroke(vp, compact and 4 or 6, Color3.new(1, 1, 1), true)
	ring.Transparency = 1
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.Parent = vp
	vp.CurrentCamera = cam
	local y = vpH + (compact and 4 or 10)
	local name = UI.Text(f, "", { Size = UDim2.new(1, 0, 0, compact and 28 or 40), Position = UDim2.fromOffset(0, y), MaxText = compact and 24 or 34, TextTransparency = 1, ZIndex = 4, StrokeThickness = compact and 2.2 or 3 })
	y = y + (compact and 30 or 44)
	local pillF = UI.new("Frame", { BackgroundColor3 = UI.Colors.Gray, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(compact and 150 or 200, compact and 24 or 30), ZIndex = 4, Parent = f })
	UI.Corner(pillF, UDim.new(1, 0))
	local pillGrad = UI.Candy(pillF, UI.Colors.Gray)
	local pillStroke = UI.Stroke(pillF, 2.5, Color3.new(1, 1, 1), true)
	pillStroke.Transparency = 1
	local sub = UI.Text(pillF, "", { Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), MaxText = compact and 15 or 19, TextTransparency = 1, ZIndex = 5, StrokeThickness = 1.6 })
	y = y + (compact and 30 or 38)
	local stats = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.new(1, 0, 0, compact and 28 or 34), Visible = false, ZIndex = 4, Parent = f })
	UI.List(stats, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local _, dmgL = statChip(stats, "Pickaxe", 1, compact and 26 or 32)
	local _, sellL = statChip(stats, "Coin", 2, compact and 26 or 32)
	return {
		frame = f, center = center, size = vpH, vp = vp, cam = cam, glow = vp, ring = ring, rays = rays, raysHolder = raysHolder,
		name = name, sub = sub, pill = pillF, pillGrad = pillGrad, pillStroke = pillStroke, stats = stats, dmgL = dmgL, sellL = sellL,
	}
end

local function showTexts(slot, petId, mult, tier, deleted)
	local def, r, rc = rarityOf(petId, tier)
	slot.name.Text = def and def.Name or petId
	local pw = (mult or (def and def.P) or 0) * ((tier == 6) and 5.6 or 1)
	local dm = 1 + pw * (def and def.DmgF or 1)
	local sm = 1 + pw * (def and def.SellF or 1)
	if tier == 6 then
		slot.name.Text = "✦ " .. slot.name.Text .. " ✦"
		slot.name.TextColor3 = Color3.fromRGB(170, 245, 255)
	end
	if deleted then
		slot.sub.Text = "Автоудалён"
		slot.pillGrad.Color = UI.CandySeq(Color3.fromRGB(120, 116, 140))
	else
		slot.sub.Text = tier == 6 and "Шайни" or (r and r.Name or "")
		slot.pillGrad.Color = UI.CandySeq(rc)
		slot.dmgL.Text = "x" .. string.format("%.2f", dm)
		slot.sellL.Text = "x" .. string.format("%.2f", sm)
		slot.stats.Visible = true
		UI.Pop(slot.stats, 0.6)
	end
	local ss = slot.sub:FindFirstChildOfClass("UIStroke")
	if ss then
		ss.Color = UI.Darker(deleted and Color3.fromRGB(120, 116, 140) or rc, 0.55)
	end
	TweenService:Create(slot.name, TweenInfo.new(0.3), { TextTransparency = deleted and 0.45 or 0 }):Play()
	TweenService:Create(slot.sub, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	TweenService:Create(slot.pill, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(slot.pillStroke, TweenInfo.new(0.3), { Transparency = 0.2 }):Play()
	UI.Pop(slot.name, 0.6)
	UI.Pop(slot.pill, 0.5)
	-- подложка окрашивается в цвет редкости (под питомцем, не поверх)
	slot.glow.BackgroundColor3 = deleted and Color3.fromRGB(90, 86, 110) or rc
	slot.ring.Color = deleted and Color3.fromRGB(120, 116, 140) or UI.Lighter(rc, 0.35)
	TweenService:Create(slot.glow, TweenInfo.new(0.35), { BackgroundTransparency = 0.68 }):Play()
	TweenService:Create(slot.ring, TweenInfo.new(0.35), { Transparency = 0.15 }):Play()
end

-- яйцо «заряжается» (раскачка с нарастанием, подпрыгивания, пульс кольца) -> вспышка, волна, искры ->
-- питомец влетает с разворотом и пружинкой, за ним вращаются лучи цвета редкости
local function animateSlot(slot, eggModel, petId, mult, delayStart, tier, fast, deleted)
	local vp, cam = slot.vp, slot.cam
	local k = fast and 0.55 or 1
	local _, _, rc, rIndex = rarityOf(petId, tier)
	local strength = math.clamp(rIndex - 1, 0, 4) + ((tier == 6) and 2 or 0)
	eggModel.Parent = vp
	eggModel:PivotTo(CFrame.new(0, 0, 0))
	local pet = ctxRef.PetModel(petId, tier or 0)
	anchorAll(pet)
	local _, petSize = pet:GetBoundingBox()
	local near = CFrame.lookAt(Vector3.new(2, 1.6, -13.5), Vector3.new(0, 0.2, 0))
	local far = CFrame.lookAt(Vector3.new(3, 2.6, -19), Vector3.new(0, 0, 0))
	cam.CFrame = far
	-- лучи медленно крутятся всё время, пока открыт слот
	local raySpin = 0
	local raySpeed = 14
	local rayConn = RunService.RenderStepped:Connect(function(dt)
		raySpin = raySpin + dt * raySpeed
		slot.raysHolder.Rotation = raySpin
	end)
	setRays(slot.rays, Color3.new(1, 1, 1), 0.92, 0)
	task.wait(delayStart)
	-- плавный наезд камеры
	animate(0.45 * k, function(a)
		cam.CFrame = far:Lerp(near, a)
	end, Enum.EasingStyle.Sine)
	-- «зарядка»: раскачка с нарастающей амплитудой и подпрыгиваниями, кольцо пульсирует, лучи разгораются
	ctxRef.Sound.Play("EggShake", 0.1)
	slot.ring.Color = Color3.new(1, 1, 1)
	local wobble = 1.25 * k
	animate(wobble, function(a)
		local amp = math.rad(6 + 22 * a)
		local ang = math.sin(a * math.pi * 6) * amp
		local hop = math.abs(math.sin(a * math.pi * 6)) * 0.3 * a
		eggModel:PivotTo(CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, ang))
		slot.ring.Transparency = 1 - (0.25 + 0.5 * math.abs(math.sin(a * math.pi * 6))) * a
		raySpeed = 14 + 60 * a
		for _, ray in ipairs(slot.rays) do
			ray.BackgroundTransparency = 0.92 - 0.3 * a
		end
	end, Enum.EasingStyle.Linear)
	-- сжатие перед взрывом
	local eggScale = eggModel:GetScale()
	animate(0.14 * k, function(a)
		eggModel:ScaleTo(eggScale * (1 - 0.14 * a))
		eggModel:PivotTo(CFrame.new(0, 0, 0))
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	ctxRef.Sound.Play("EggCrack", 0.05)
	-- вспышка в круге + волна + искры
	slot.glow.BackgroundColor3 = Color3.new(1, 1, 1)
	slot.glow.BackgroundTransparency = 0.1
	task.spawn(function()
		animate(0.35, function(a)
			slot.glow.BackgroundTransparency = 0.1 + 0.8 * a
		end)
	end)
	if not deleted then
		slotBurst(slot, rc, strength)
	end
	-- лучи: цвет редкости, чем реже — тем ярче и шире
	setRays(slot.rays, deleted and Color3.fromRGB(120, 116, 140) or rc, deleted and 0.9 or math.max(0.35, 0.78 - strength * 0.1), 0.25)
	raySpeed = 10 + strength * 6
	slot.raysHolder.Size = UDim2.fromOffset(math.floor(slot.size * (1.35 + strength * 0.08)), math.floor(slot.size * (1.35 + strength * 0.08)))
	UI.Pop(slot.raysHolder, 0.6)
	-- яйцо раздувается и тает
	task.spawn(function()
		animate(0.25, function(a)
			eggModel:ScaleTo(eggScale * (0.86 + 0.55 * a))
			eggModel:PivotTo(CFrame.new(0, 0, 0))
		end)
		eggModel.Parent = nil
	end)
	fadeModel(eggModel, 0.22)
	-- питомец влетает с разворотом (Back.Out) и потом плавно покачивается
	pet.Parent = vp
	local fit = 4.3 / math.max(petSize.X, petSize.Y, petSize.Z, 1)
	local target = fit * (pet:GetAttribute("Scale") or 1)
	pet:ScaleTo(0.05)
	local spin = 0
	local introTurn = math.pi * 2
	local conn = RunService.RenderStepped:Connect(function(dt)
		spin = spin + dt
		pet:PivotTo(CFrame.new(0, -0.5 + math.sin(spin * 2) * 0.12, 0) * CFrame.Angles(0, math.pi + introTurn + math.sin(spin * 0.9) * 0.5, 0))
	end)
	ctxRef.Sound.Play("Reveal", 0.05)
	task.spawn(function()
		animate(0.55, function(a)
			pet:ScaleTo(math.max(0.05, target * a))
			introTurn = math.pi * 2 * (1 - math.min(1, a))
		end, Enum.EasingStyle.Back)
		introTurn = 0
	end)
	task.wait(0.2)
	showTexts(slot, petId, mult, tier, deleted)
	if deleted then
		-- автоудалённый: питомец показывается и тает
		task.delay(0.6, function()
			fadeModel(pet, 0.4)
		end)
	end
	return function()
		conn:Disconnect()
		rayConn:Disconnect()
	end
end

---------------------------------------------------------------------------------------------
-- Кинематографичное выпадение очень редкого питомца
---------------------------------------------------------------------------------------------
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 255, 120)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 110, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 120)),
})

-- звёздочки-искры, разлетающиеся из центра
local function burstStars(parent, n, col, z, radius)
	for _ = 1, n do
		local ang = math.random() * math.pi * 2
		local dist = (radius or 420) * (0.5 + math.random() * 0.6)
		local sz = math.random(10, 22)
		local st = UI.new("Frame", { BackgroundColor3 = (math.random() < 0.5) and Color3.new(1, 1, 1) or col, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(sz, sz), Rotation = 45, ZIndex = z, Parent = parent })
		UI.Corner(st, 3)
		TweenService:Create(st, TweenInfo.new(0.9 + math.random() * 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(ang) * dist, 0.45, math.sin(ang) * dist * 0.75),
			BackgroundTransparency = 1,
			Rotation = 45 + math.random(-180, 180),
			Size = UDim2.fromOffset(sz * 0.4, sz * 0.4),
		}):Play()
		task.delay(1.6, function()
			st:Destroy()
		end)
	end
end

-- Эпичное выпадение очень редкого питомца (легендарный, мифический, шайни):
-- киношные полосы сверху и снизу, лучи и сияние ЗА яйцом (отдельный слой ниже 3D-сцены),
-- нарастающая тряска с наездом камеры, взрыв-вспышка, ударные волны, искры, силуэт → раскрытие.
local function cinematic(eggModel, p)
	local def = PetsData.ById[p.Id]
	local r = def and PetsData.Rarity[def.Rarity]
	local col = r and Color3.fromRGB(r.Color[1], r.Color[2], r.Color[3]) or Color3.new(1, 1, 1)
	local huge = def and def.Rarity == "Huge"
	local mythic = def and (def.Rarity == "Mythic" or huge)
	local shiny = p.T == 6
	if shiny then
		col = Color3.fromRGB(120, 230, 255)
	end
	cineBack.Enabled = true
	cineFront.Enabled = true
	-- задний слой: полупрозрачный тёмный фон в оттенок редкости (мир чуть видно), сияние и лучи
	local bg = UI.new("Frame", { BackgroundColor3 = col:Lerp(Color3.fromRGB(14, 10, 30), 0.8), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = cineBack })
	TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 0.22 }):Play()
	local center = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(10, 10), Parent = bg })
	local glow = UI.new("Frame", { BackgroundColor3 = col, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(260, 260), Parent = center })
	UI.Corner(glow, UDim.new(1, 0))
	local rays = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1100, 1100), Parent = center })
	local rayScale = Instance.new("UIScale")
	rayScale.Scale = 0.3
	rayScale.Parent = rays
	for k = 0, 15 do
		local ray = UI.new("Frame", { BackgroundColor3 = (k % 2 == 0) and col or Color3.new(1, 1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, (k % 2 == 0) and 90 or 40, 1, 0), Rotation = k * 11.25, Parent = rays })
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.05), NumberSequenceKeypoint.new(1, 1) })
		g.Rotation = 90
		g.Parent = ray
		if mythic and k % 2 == 0 then
			ray.BackgroundColor3 = Color3.new(1, 1, 1)
			local rg = Instance.new("UIGradient")
			rg.Color = RAINBOW
			rg.Transparency = g.Transparency
			rg.Rotation = 90
			g:Destroy()
			rg.Parent = ray
		end
	end
	-- киношные полосы
	local barTop = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0, 0), Parent = cineFront })
	local barBot = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), Parent = cineFront })
	TweenService:Create(barTop, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0.08, 0) }):Play()
	TweenService:Create(barBot, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0.08, 0) }):Play()
	-- передний слой: 3D-сцена и надписи
	local box = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, 640), ZIndex = 2, Parent = cineFront })
	local sc = Instance.new("UIScale")
	sc.Parent = box
	ctxRef.RegisterScale(sc, cineFront, 980, 680)
	local vp = UI.new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(900, 560), ZIndex = 3, Ambient = Color3.fromRGB(170, 160, 200), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.3, -1, -0.6), Parent = box })
	local cam = Instance.new("Camera")
	cam.FieldOfView = 36
	cam.Parent = vp
	vp.CurrentCamera = cam
	local camFar = CFrame.lookAt(Vector3.new(0, 2.2, -20), Vector3.new(0, 0.6, 0))
	local camNear = CFrame.lookAt(Vector3.new(0, 1.4, -12.5), Vector3.new(0, 0.6, 0))
	cam.CFrame = camFar
	eggModel.Parent = vp
	eggModel:PivotTo(CFrame.new(0, 0, 0))
	local title = UI.Text(box, shiny and "✦ Что-то сияет... ✦" or "Что-то необычное...", { Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 40), MaxText = 46, ZIndex = 5, StrokeThickness = 4 })
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title
	UI.Pop(title, 0.6)
	ctxRef.Sound.Play("Warning")
	local spin, speed = 0, 18
	local fxConn = RunService.RenderStepped:Connect(function(dt)
		spin = spin + dt * speed
		rays.Rotation = spin
		glow.Rotation = -spin
	end)
	TweenService:Create(rayScale, TweenInfo.new(2.4, Enum.EasingStyle.Sine), { Scale = 0.75 }):Play()
	TweenService:Create(glow, TweenInfo.new(1.2), { BackgroundTransparency = 0.55 }):Play()
	-- 5 всё более сильных раскачиваний: камера подъезжает, экран дрожит, яйцо наливается цветом
	for i = 1, 5 do
		ctxRef.Sound.Play("EggShake", 0.15, 0.6 + i * 0.2)
		local dur = 0.42 - i * 0.04
		local a = math.rad(8 + i * 7)
		animate(dur, function(k)
			eggModel:PivotTo(CFrame.new(math.sin(k * 40) * 0.05 * i, math.abs(math.sin(k * math.pi * 2)) * 0.22 * i, 0) * CFrame.Angles(0, 0, math.sin(k * math.pi * 2) * a))
			box.Position = UDim2.new(0.5, math.random(-3, 3) * i, 0.5, math.random(-3, 3) * i)
		end, Enum.EasingStyle.Linear)
		eggModel:PivotTo(CFrame.new(0, 0, 0))
		box.Position = UDim2.fromScale(0.5, 0.5)
		for _, d in ipairs(eggModel:GetDescendants()) do
			if d:IsA("BasePart") and i >= 3 then
				d.Color = d.Color:Lerp(col, 0.35)
				if i == 5 then
					d.Material = Enum.Material.Neon
				end
			end
		end
		local camFrom = camFar:Lerp(camNear, (i - 1) / 5)
		local camTo = camFar:Lerp(camNear, i / 5)
		task.spawn(function()
			animate(0.12, function(k)
				cam.CFrame = camFrom:Lerp(camTo, k)
			end)
		end)
		glow.Size = UDim2.fromOffset(260 + i * 40, 260 + i * 40)
		speed = 18 + i * 14
		task.wait(0.1)
	end
	-- ВЗРЫВ: вспышка цвета редкости, две ударные волны, искры, «удар» камеры
	flash.BackgroundColor3 = col
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	ctxRef.Sound.Play("EggCrack")
	ctxRef.Sound.Play("Unlock")
	for w = 1, 2 do
		local wave = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60), Parent = center })
		UI.Corner(wave, UDim.new(1, 0))
		local ws = UI.Stroke(wave, w == 1 and 14 or 6, w == 1 and col or Color3.new(1, 1, 1))
		task.delay((w - 1) * 0.15, function()
			TweenService:Create(wave, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(1300, 1300) }):Play()
			TweenService:Create(ws, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end)
		task.delay(1.2, function()
			wave:Destroy()
		end)
	end
	burstStars(cineFront, mythic and 40 or 26, col, 6, 520)
	task.spawn(function()
		animate(0.35, function(k)
			cam.FieldOfView = 30 + 6 * k
		end, Enum.EasingStyle.Back)
	end)
	rayScale.Scale = 1
	speed = 40
	eggModel.Parent = nil
	-- питомец сначала тенью...
	local pet = ctxRef.PetModel(p.Id, p.T or 0)
	anchorAll(pet)
	local _, size = pet:GetBoundingBox()
	pet:ScaleTo(pet:GetScale() * 5.2 / math.max(size.X, size.Y, size.Z, 1))
	pet.Parent = vp
	local restore = silhouette(pet)
	local petSpin = 0
	local petConn = RunService.RenderStepped:Connect(function(dt)
		petSpin = petSpin + dt
		pet:PivotTo(CFrame.new(0, -0.3 + math.sin(petSpin * 2) * 0.15, 0) * CFrame.Angles(0, math.pi + petSpin * 1.4, 0))
	end)
	title.Text = "???"
	UI.Pop(title, 0.5)
	task.wait(mythic and 1.4 or 1.1)
	-- ...и вот он!
	restore()
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.05
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	ctxRef.Sound.Play("Reveal")
	ctxRef.Sound.Play("Upgrade")
	ctxRef.Sound.Play("LevelUp")
	burstStars(cineFront, mythic and 50 or 30, col, 6, 600)
	title.Text = shiny and "✦ ШАЙНИ! ✦" or (huge and "★ ОГРОМНЫЙ! ★" or (mythic and "МИФИЧЕСКИЙ!" or string.upper((r and r.Name or "") .. "!")))
	title.TextColor3 = (mythic or shiny) and Color3.new(1, 1, 1) or col
	if mythic or shiny then
		local g = Instance.new("UIGradient")
		g.Color = shiny and ColorSequence.new(Color3.fromRGB(140, 240, 255), Color3.fromRGB(255, 160, 235)) or RAINBOW
		g.Parent = title
		task.spawn(function()
			while title.Parent do
				g.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.5, 0)
				RunService.RenderStepped:Wait()
			end
		end)
	end
	-- надпись «впечатывается»: огромная → нормальная с пружинкой
	titleScale.Scale = 2.6
	TweenService:Create(titleScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local nameL = UI.Text(box, def and def.Name or p.Id, { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 520), MaxText = 42, ZIndex = 5, StrokeThickness = 3.5 })
	local chance = def and def.Chance or 0
	local mult = (p.M or (def and def.P) or 0) * (shiny and 5.6 or 1)
	local subF = UI.new("Frame", { BackgroundColor3 = col, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 574), Size = UDim2.fromOffset(560, 32), ZIndex = 5, Parent = box })
	UI.Corner(subF, UDim.new(1, 0))
	UI.Text(subF, (chance > 0 and ("Шанс " .. (chance < 1 and string.format("%.2f", chance) or string.format("%.1f", chance)) .. "%  ·  ") or "") .. "урон x" .. string.format("%.2f", 1 + mult * (def and def.DmgF or 1)) .. "  ·  продажа x" .. string.format("%.2f", 1 + mult * (def and def.SellF or 1)), { Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), MaxText = 22, ZIndex = 6 })
	UI.Pop(nameL, 0.5)
	UI.Pop(subF, 0.5)
	-- конфетти с двух сторон + искры, пока игрок любуется
	for k = 1, mythic and 110 or 70 do
		local c = Color3.fromHSV(math.random(), 0.65, 1)
		local fromLeft = k % 2 == 0
		local f = UI.new("Frame", { BackgroundColor3 = c, Size = UDim2.fromOffset(math.random(8, 16), math.random(10, 20)), Position = UDim2.new(fromLeft and -0.02 or 1.02, 0, 0.7 + math.random() * 0.3, 0), Rotation = math.random(0, 360), ZIndex = 4, Parent = cineFront })
		UI.Corner(f, 3)
		local tx = fromLeft and (0.1 + math.random() * 0.5) or (0.4 + math.random() * 0.5)
		TweenService:Create(f, TweenInfo.new(1 + math.random() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(tx, 0, math.random() * 0.4, 0), Rotation = f.Rotation + math.random(-300, 300) }):Play()
		task.delay(1.2 + math.random() * 0.5, function()
			if f.Parent then
				TweenService:Create(f, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(f.Position.X.Scale, 0, 1.1, 0), BackgroundTransparency = 0.3 }):Play()
			end
		end)
	end
	local sparkle = true
	task.spawn(function()
		while sparkle do
			burstStars(cineFront, 3, col, 6, 300)
			task.wait(0.18)
		end
	end)
	-- ждём клика или 5 с
	local clicked = false
	local btn = UI.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = cineFront })
	btn.Activated:Connect(function()
		clicked = true
	end)
	local waited = math.max(task.wait(1), 1)
	while not clicked and waited < 5 do
		waited = waited + math.max(task.wait(0.05), 0.05)
	end
	sparkle = false
	fxConn:Disconnect()
	petConn:Disconnect()
	TweenService:Create(bg, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(barTop, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	TweenService:Create(barBot, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	box.Visible = false
	rays.Visible = false
	glow.Visible = false
	task.wait(0.32)
	for _, g2 in ipairs({ cineBack, cineFront }) do
		for _, ch in ipairs(g2:GetChildren()) do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
	end
	cineBack.Enabled = false
	cineFront.Enabled = false
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
end

local function play(eggModels, pets, opts)
	opts = opts or {}
	local fast = opts.Fast == true
	playing = true
	gui.Enabled = true
	for _, c in ipairs(row:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	-- однотонный фон, плавно появляется
	overlay.BackgroundTransparency = 1
	-- немного тёмный полупрозрачный фон: мир позади видно, но питомцы читаются
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.42 }):Play()
	hint.TextTransparency = 1
	-- очень редкие питомцы и шайни получают отдельное кинематографичное появление
	for i, p in ipairs(pets) do
		if (isRare(p.Id) or p.T == 6) and not p.Deleted then
			local egg = eggModels[i]:Clone()
			local ok, err = pcall(cinematic, egg, p)
			if not ok then
				warn("[EggOpening] cinematic", err)
			end
		end
	end
	local cleanups = {}
	local n = #pets
	local layout = row:FindFirstChildOfClass("UIListLayout")
	if layout then
		pcall(function()
			layout.Wraps = n > 3
		end)
	end
	local done = 0
	for i, p in ipairs(pets) do
		local slot = slotFrame(i, n)
		UI.Pop(slot.frame, 0.85)
		task.spawn(function()
			local ok, stop = pcall(animateSlot, slot, eggModels[i], p.Id, p.M, (i - 1) * (fast and 0.05 or 0.12), p.T, fast, p.Deleted)
			if ok and stop then
				table.insert(cleanups, stop)
			elseif not ok then
				warn("[EggOpening]", stop)
				showTexts(slot, p.Id, p.M, p.T, p.Deleted)
			end
			done = done + 1
		end)
	end
	while done < n do
		task.wait(0.05)
	end
	local clicked = false
	local btn = overlay:FindFirstChild("Catch")
	local c1 = btn.Activated:Connect(function()
		clicked = true
	end)
	local limit = fast and 0.9 or 3.2
	if not fast then
		TweenService:Create(hint, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		task.spawn(function()
			local hs = hint:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			hs.Parent = hint
			while not clicked and gui.Enabled do
				hs.Scale = 1 + math.sin(os.clock() * 5) * 0.04
				RunService.RenderStepped:Wait()
			end
			hs.Scale = 1
		end)
	end
	local waited = 0
	while not clicked and waited < limit do
		waited = waited + math.max(task.wait(0.05), 0.05)
	end
	c1:Disconnect()
	-- плавное исчезновение
	for _, c in ipairs(row:GetChildren()) do
		if c:IsA("Frame") then
			local sc = c:FindFirstChildOfClass("UIScale")
			if sc then
				TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
			end
		end
	end
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(hint, TweenInfo.new(0.15), { TextTransparency = 1 }):Play()
	task.wait(0.2)
	for _, f in ipairs(cleanups) do
		f()
	end
	gui.Enabled = false
	playing = false
	if #queue > 0 then
		local nextJob = table.remove(queue, 1)
		task.spawn(play, nextJob[1], nextJob[2], nextJob[3])
	end
end

function EggOpening.IsBusy()
	return playing or #queue > 0
end

function EggOpening.Build(ctx)
	ctxRef = ctx
	gui = UI.new("ScreenGui", { Name = "EggOpeningGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = ctx.PlayerGui })
	-- однотонный мягкий фон (без лучей и узоров)
	overlay = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 14, 38), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	-- виньетка: края темнее центра
	local vig = Instance.new("UIGradient")
	vig.Rotation = 90
	vig.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) })
	vig.Parent = overlay
	local catch = UI.new("TextButton", { Name = "Catch", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = overlay })
	row = UI.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1200, 540), Parent = overlay })
	UI.List(row, 10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local scale = Instance.new("UIScale")
	scale.Parent = row
	ctx.RegisterScale(scale, gui, 1260, 640)
	hint = UI.Text(overlay, "Нажми, чтобы продолжить", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(500, 34), MaxText = 26, TextTransparency = 1 })
	-- слои кинематографа: ниже — фон и лучи, выше — 3D-сцена, надписи и вспышка
	cineBack = UI.new("ScreenGui", { Name = "EggCineBack", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 21, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = ctx.PlayerGui })
	cineFront = UI.new("ScreenGui", { Name = "EggCineFront", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 22, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = ctx.PlayerGui })
	local flashGui = UI.new("ScreenGui", { Name = "EggFlash", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 23, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = ctx.PlayerGui })
	flash = UI.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = flashGui })
end

function EggOpening.Play(eggId, pets, opts)
	local egg = EggsData.ById[eggId]
	local src = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Eggs"):FindFirstChild(eggId)
	local models = {}
	for i = 1, #pets do
		local m = src and src:Clone() or GearBuilder.Egg(egg)
		anchorAll(m)
		models[i] = m
	end
	if playing then
		table.insert(queue, { models, pets, opts })
		return
	end
	task.spawn(play, models, pets, opts)
end

-- Питомец из инкубатора: "яйцо" в цвет семени
function EggOpening.Hatch(pet)
	local seed = SeedsData.ByPet[pet.Id]
	local col = seed and seed.Color or { 255, 190, 70 }
	local m = GearBuilder.Egg({ Id = "Seed", Look = { Base = col, Accent = { 255, 255, 255 }, Band = { 80, 170, 60 }, Pattern = "glass", Neon = true } })
	anchorAll(m)
	if playing then
		table.insert(queue, { { m }, { pet } })
		return
	end
	task.spawn(play, { m }, { pet })
end

return EggOpening
