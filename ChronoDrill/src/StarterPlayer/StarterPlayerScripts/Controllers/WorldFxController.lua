-- WorldFxController: "живой" мир на клиенте — вращение витрин, покачивание яиц,
-- пульсация неона, орбиты циферблата, анимация Drill-Bot 3000, подписи порталов.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local BiomesData = require(Configs:WaitForChild("BiomesData"))
local QuestsData = require(Configs:WaitForChild("QuestsData"))

local ClientState = require(script.Parent.ClientState)

local Fx = {}
local tracked = {}

local function track(tag, init)
	tracked[tag] = {}
	local function add(inst)
		local rec = { inst = inst, seed = math.random() * 10 }
		if init then
			init(inst, rec)
		end
		tracked[tag][inst] = rec
	end
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		tracked[tag][inst] = nil
	end)
end

local function nearLocal(pos, dist)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - pos).Magnitude < dist
end

local function npcInit(model, rec)
	rec.parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			rec.parts[p] = p.CFrame
		end
	end
	rec.pivot = model:GetPivot()
	rec.nextBlink = os.clock() + 2
end

local function updatePortalLabels()
	local data = ClientState.Data
	if not data then
		return
	end
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	for _, biomeFolder in ipairs(world:GetChildren()) do
		local hub = biomeFolder:FindFirstChild("Hub")
		if hub then
			for _, m in ipairs(hub:GetChildren()) do
				local target = m:GetAttribute("Target")
				if target then
					local disc = m:FindFirstChild("PortalDisc")
					local bb = disc and disc:FindFirstChildOfClass("BillboardGui")
					local lbl = bb and bb:FindFirstChild("LockLabel")
					if lbl then
						if target <= (data.UnlockedBiome or 1) then
							lbl.Text = "Открыто"
							lbl.TextColor3 = Color3.fromRGB(140, 255, 150)
							disc.Transparency = 0.15
						else
							lbl.Text = "Закрыто: сломай блок на дне прошлого яруса"
							lbl.TextColor3 = Color3.fromRGB(255, 120, 110)
							disc.Transparency = 0.6
						end
					end
				end
			end
		end
	end
end

local function storyReady()
	local data = ClientState.Data
	if not data then
		return false
	end
	local q = QuestsData.Story[data.StoryIndex or 1]
	if not q then
		return false
	end
	local cur
	if q.Stat == "SessionEggs" then
		cur = data.Derived and data.Derived.SessionEggs or 0
	else
		cur = data.Stats and data.Stats[q.Stat] or 0
	end
	return cur >= q.Target
end

function Fx.Init()
	track("SpinDisplay")
	track("EggDisplay")
	track("Pulse", function(p, rec)
		rec.base = p.Transparency
	end)
	track("Float", function(p, rec)
		rec.base = p.CFrame
	end)
	track("Orbit", function(p, rec)
		rec.base = p.CFrame
		rec.center = p:GetAttribute("Center")
	end)
	track("Nugget", function(p, rec)
		rec.base = p.CFrame
	end)
	track("DrillBot", npcInit)
	track("Cloud", function(m, rec)
		rec.base = m:GetAttribute("Base")
	end)
	track("Spin", function(m, rec)
		rec.base = m:GetAttribute("Base")
		rec.speed = m:GetAttribute("SpinSpeed") or 1
	end)

	track("Rainbow", function(m, rec)
		rec.parts = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Hue") then
				rec.parts[d] = d:GetAttribute("Hue")
			end
		end
	end)

	ClientState.Changed:Connect(updatePortalLabels)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for m, rec in pairs(tracked.SpinDisplay) do
			local base = m:GetAttribute("Base")
			if base and nearLocal(base.Position, 120) then
				m:PivotTo(base * CFrame.new(0, math.sin(t * 1.5 + rec.seed) * 0.4, 0) * CFrame.Angles(0, t * 0.9, 0) * CFrame.Angles(math.rad(90), 0, 0))
			end
		end
		for m, rec in pairs(tracked.EggDisplay) do
			local base = m:GetAttribute("Base")
			if base and nearLocal(base.Position, 140) then
				local wob = 0
				local cyc = (t + rec.seed) % 5
				if cyc < 0.6 then
					wob = math.sin(cyc * 30) * math.rad(8) * (1 - cyc / 0.6)
				end
				m:PivotTo(base * CFrame.new(0, math.sin(t * 2 + rec.seed) * 0.5, 0) * CFrame.Angles(0, t * 0.5, wob))
			end
		end
		for p, rec in pairs(tracked.Pulse) do
			p.Transparency = math.clamp(rec.base + (math.sin(t * 3 + rec.seed) * 0.5 + 0.5) * 0.35, 0, 0.95)
		end
		for p, rec in pairs(tracked.Float) do
			p.CFrame = rec.base * CFrame.new(0, math.sin(t * 1.3 + rec.seed) * 1.2, 0) * CFrame.Angles(0, t * 0.4, 0)
		end
		for p, rec in pairs(tracked.Orbit) do
			if rec.center then
				local offset = rec.base.Position - rec.center
				local newPos = rec.center + CFrame.Angles(0, t * 0.35, 0):VectorToWorldSpace(offset)
				p.CFrame = CFrame.lookAt(newPos, rec.center)
			end
		end
		for p, rec in pairs(tracked.Nugget) do
			p.CFrame = rec.base * CFrame.new(0, math.sin(t * 4 + rec.seed) * 0.3, 0) * CFrame.Angles(0, t * 3, 0)
		end
		for m, rec in pairs(tracked.Cloud) do
			if rec.base and m.Parent and nearLocal(rec.base.Position, 520) then
				m:PivotTo(rec.base * CFrame.new(math.sin(t * 0.08 + rec.seed) * 14, math.sin(t * 0.3 + rec.seed) * 1.5, 0))
			end
		end
		for m, rec in pairs(tracked.Spin) do
			if rec.base and m.Parent and nearLocal(rec.base.Position, 300) then
				m:PivotTo(rec.base * CFrame.Angles(0, 0, t * rec.speed))
			end
		end
		-- радужные питомцы: плавно перебираем оттенок
		local hueT = (t * 0.15) % 1
		for m, rec in pairs(tracked.Rainbow) do
			if m.Parent then
				for part, h in pairs(rec.parts) do
					part.Color = Color3.fromHSV((h + hueT) % 1, 0.62, 1)
				end
			end
		end
		local ready = storyReady()
		for m, rec in pairs(tracked.DrillBot) do
			if nearLocal(rec.pivot.Position, 150) then
				local bob = math.sin(t * 2) * 0.15
				local blink = 1
				if t > rec.nextBlink then
					blink = 0.1
					if t > rec.nextBlink + 0.12 then
						rec.nextBlink = t + 2 + math.random() * 3
					end
				end
				for p, cf in pairs(rec.parts) do
					if p.Parent then
						local name = p.Name
						if name == "Head" or name == "Visor" or name == "Eye" or name == "Mouth" or name == "Antenna" or name == "AntennaBulb" then
							local tilt = CFrame.Angles(0, math.sin(t * 0.8) * 0.12, math.sin(t * 1.1) * 0.04)
							local pivot = rec.pivot * CFrame.new(0, 2.4, 0)
							local rel = pivot:ToObjectSpace(cf)
							p.CFrame = (pivot * CFrame.new(0, bob, 0) * tilt) * rel
							if name == "Eye" then
								p.Size = Vector3.new(p.Size.X, 0.62 * blink, p.Size.Z)
							elseif name == "AntennaBulb" then
								p.Color = ready and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 80, 80)
							end
						elseif name == "DrillBit" then
							p.CFrame = cf * CFrame.Angles(t * 9, 0, 0)
						end
					end
				end
				local tag = m.PrimaryPart and m.PrimaryPart:FindFirstChild("NameTag")
				local lbl = tag and tag:FindFirstChildOfClass("TextLabel")
				if lbl then
					lbl.Text = ready and "! Drill-Bot 3000 !" or "Drill-Bot 3000"
					lbl.TextColor3 = ready and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 220, 90)
				end
			end
		end
	end)
end

return Fx
