-- Icons3D: объёмные иконки — 3D-модель во ViewportFrame с мягким светом.
-- При наведении иконка плавно поворачивается и подпрыгивает.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local IconModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IconModels"))

local Icons3D = {}
local spinning = {}

local function frame(vp, cam, model, view, zoom)
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.55 / (zoom or 1)
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05
	local dir = (view or Vector3.new(0.3, 0.22, -1)).Unit
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	return cf.Position
end

-- name: имя из IconModels или готовая Model; opts: { Size = px, Zoom, View, NoHover }
function Icons3D.New(parent, name, opts)
	opts = opts or {}
	local size = opts.Size or 48
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Icon3D"
	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.Size = UDim2.fromOffset(size, size)
	vp.Ambient = Color3.fromRGB(190, 186, 205)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-0.5, -1, -0.7)
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model
	if typeof(name) == "Instance" then
		model = name
	else
		model = IconModels.Get(name)
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	model.Parent = vp
	local center = frame(vp, cam, model, opts.View, opts.Zoom)
	local base = model:GetPivot()
	local obj = { Viewport = vp, Model = model }
	function obj.SetSpin(on)
		if on then
			spinning[obj] = spinning[obj] or { t = 0 }
		else
			spinning[obj] = nil
			model:PivotTo(base)
		end
	end
	function obj.Bounce()
		local s = vp:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", vp)
		s.Scale = 1.25
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	obj.Base = base
	obj.Center = center
	if not opts.NoHover then
		vp.MouseEnter:Connect(function()
			obj.SetSpin(true)
		end)
		vp.MouseLeave:Connect(function()
			obj.SetSpin(false)
		end)
	end
	vp.Destroying:Connect(function()
		spinning[obj] = nil
	end)
	return obj
end

RunService.RenderStepped:Connect(function(dt)
	for obj, st in pairs(spinning) do
		if not obj.Viewport.Parent then
			spinning[obj] = nil
		else
			st.t = st.t + dt
			local pivotPos = obj.Center
			local rot = CFrame.new(pivotPos) * CFrame.Angles(0, math.sin(st.t * 3) * 0.5, 0) * CFrame.new(0, math.abs(math.sin(st.t * 6)) * 0.15, 0) * CFrame.new(-pivotPos)
			obj.Model:PivotTo(rot * obj.Base)
		end
	end
end)

return Icons3D
