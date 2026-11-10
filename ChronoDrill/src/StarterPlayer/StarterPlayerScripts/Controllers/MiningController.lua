-- MiningController: зажатие ЛКМ / экрана / R2 -> удары по блоку с частотой бура.
-- Подсветка цели, полоска HP блока, предсказание эффектов на клиенте.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local Balance = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Balance"))

local Controllers = script.Parent
local ClientState = require(Controllers.ClientState)
local Sound = require(Controllers.SoundController)
local VFX = require(script.Parent.Parent:WaitForChild("Visuals"):WaitForChild("BlockBreakVFX"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Mining = {}
Mining.Holding = false
Mining.Target = nil
Mining.Enabled = true
Mining.Mining = false -- для анимации руки

local holdingTouch = nil
local holdingInput = nil
local lastFire = 0
local selection, hpGui, hpFill, hpText
local mines
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function makeIndicators()
	selection = Instance.new("SelectionBox")
	selection.LineThickness = 0.06
	selection.Color3 = Color3.fromRGB(255, 255, 255)
	selection.SurfaceTransparency = 0.92
	selection.SurfaceColor3 = Color3.fromRGB(255, 255, 255)
	selection.Transparency = 0.25
	selection.Parent = workspace

	hpGui = Instance.new("BillboardGui")
	hpGui.Size = UDim2.fromOffset(120, 22)
	hpGui.StudsOffset = Vector3.new(0, 3.2, 0)
	hpGui.AlwaysOnTop = true
	hpGui.LightInfluence = 0
	hpGui.Enabled = false
	hpGui.Parent = player:WaitForChild("PlayerGui")
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 24, 40)
	bg.Parent = hpGui
	Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 16, 28)
	stroke.Parent = bg
	hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(110, 230, 100)
	hpFill.Parent = bg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	grad.Rotation = 90
	grad.Parent = hpFill
	hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.ZIndex = 3
	hpText.Parent = bg
	local ts = Instance.new("UIStroke")
	ts.Thickness = 1.5
	ts.Color = Color3.fromRGB(20, 16, 28)
	ts.Parent = hpText
end

local function blockFromHit(inst)
	if not inst then
		return nil
	end
	if inst.Name == "Vein" and inst.Parent and inst.Parent:IsA("BasePart") then
		inst = inst.Parent
	end
	if inst:GetAttribute("MaxHealth") then
		return inst
	end
	return nil
end

local function pointerRay()
	camera = workspace.CurrentCamera
	if holdingTouch then
		-- координаты касания — экранные (без верхней панели)
		return camera:ScreenPointToRay(holdingTouch.X, holdingTouch.Y)
	elseif UserInputService.MouseEnabled and UserInputService:GetLastInputType() ~= Enum.UserInputType.Gamepad1 then
		local pos = UserInputService:GetMouseLocation()
		return camera:ViewportPointToRay(pos.X, pos.Y)
	end
	local vs = camera.ViewportSize
	return camera:ViewportPointToRay(vs.X / 2, vs.Y / 2)
end

local function findTarget()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not mines then
		return nil
	end
	rayParams.FilterDescendantsInstances = { mines }
	local ray = pointerRay()
	local res = workspace:Raycast(ray.Origin, ray.Direction * 200, rayParams)
	local block = res and blockFromHit(res.Instance)
	if block and (block.Position - root.Position).Magnitude <= Balance.MineReach then
		return block, res.Position
	end
	-- автонаведение: ближайший блок под/перед персонажем, если курсор мимо
	if Mining.Holding then
		local dirs = { Vector3.new(0, -6, 0), root.CFrame.LookVector * 6 + Vector3.new(0, -2, 0), root.CFrame.LookVector * 6 }
		for _, d in ipairs(dirs) do
			local r2 = workspace:Raycast(root.Position, d, rayParams)
			local b2 = r2 and blockFromHit(r2.Instance)
			if b2 then
				return b2, r2.Position
			end
		end
	end
	return nil
end

local function updateHp(block)
	if not block then
		hpGui.Enabled = false
		return
	end
	local max = block:GetAttribute("MaxHealth") or 1
	local cur = block:GetAttribute("CurrentHealth") or max
	hpGui.Adornee = block
	hpGui.Enabled = Mining.Holding or cur < max
	local f = math.clamp(cur / max, 0, 1)
	hpFill.Size = UDim2.fromScale(math.max(f, 0.04), 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(255, 80, 70):Lerp(Color3.fromRGB(110, 230, 100), f)
	hpText.Text = Util.Format(math.max(0, cur))
end

local function faceTarget(block)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.MoveDirection.Magnitude > 0.1 then
		return
	end
	local flat = Vector3.new(block.Position.X, root.Position.Y, block.Position.Z)
	if (flat - root.Position).Magnitude > 1 then
		root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, flat), 0.35)
	end
end

local function step()
	if not Mining.Enabled then
		selection.Adornee = nil
		hpGui.Enabled = false
		Mining.Mining = false
		return
	end
	local block, hitPos = findTarget()
	Mining.Target = block
	selection.Adornee = block
	updateHp(block)
	Mining.Mining = Mining.Holding and block ~= nil
	if not Mining.Holding or not block then
		return
	end
	faceTarget(block)
	local data = ClientState.Data
	local interval = (data and data.Derived and data.Derived.HitInterval) or Balance.HitInterval
	local now = os.clock()
	if now - lastFire < interval then
		return
	end
	lastFire = now
	Net.Get("MineBlock"):FireServer(block)
	VFX.Squash(block)
	VFX.HitSpark(hitPos or block.Position, block.Color, false)
	Sound.Play("DrillHit", 0.12, 0.8)
end

local function isOverGui(pos)
	local guis = player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	for _, g in ipairs(guis) do
		if g.Visible and g.BackgroundTransparency < 1 or g:IsA("GuiButton") then
			return true
		end
	end
	return false
end

function Mining.Init()
	makeIndicators()
	mines = workspace:WaitForChild("Mines")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Mining.Holding = true
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local vs = workspace.CurrentCamera.ViewportSize
			-- зона виртуального джойстика (низ-лево) не запускает бурение
			local inStick = p.X < vs.X * 0.33 and p.Y > vs.Y * 0.45
			if not holdingInput and not inStick and not isOverGui(p) then
				holdingInput = input
				holdingTouch = p
				Mining.Holding = true
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			Mining.Holding = true
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == holdingInput then
			holdingTouch = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			Mining.Holding = false
		elseif input == holdingInput then
			-- отпускаем бур только когда поднят ИМЕННО тот палец, которым бурили
			holdingInput = nil
			holdingTouch = nil
			Mining.Holding = false
		end
	end)

	Net.Get("HitResult").OnClientEvent:Connect(function(block, dmg, crit, reason)
		if reason == "owned" then
			if block and block.Parent then
				VFX.DamageNumber(block.Position, "ЗАНЯТО", false)
			end
			return
		end
		if reason == "full" or not block then
			return
		end
		local pos = block.Parent and block.Position or nil
		if pos then
			VFX.DamageNumber(pos, (crit and "КРИТ! " or "") .. Util.Format(dmg), crit)
			if crit then
				VFX.HitSpark(pos, block.Color, true)
				Sound.Play("Crit", 0.1)
			end
		end
	end)

	Net.Get("BlockBroken").OnClientEvent:Connect(function(biome, pos, color, vein, breakerId, glass)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pos).Magnitude > 160 then
			return
		end
		VFX.Break(pos, color, vein, glass)
		if breakerId == player.UserId then
			Sound.Play("BlockBreak", 0.15)
			VFX.OreFly(pos, color, char)
			task.delay(0.4, function()
				Sound.Play("OrePickup", 0.2, 0.6)
			end)
		end
	end)

	RunService.RenderStepped:Connect(step)
end

return Mining
