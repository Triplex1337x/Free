dofile(EMU .. "/harness.lua")
local Mining = require(H.CF.MiningController)
local VFX = require(H.PS.Visuals.BlockBreakVFX)
Mining.Init()
local g = H.screen("Preview", 1)
local function lift(bb, x, y, scale)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = bb.Size
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Parent = g
	local s = Instance.new("UIScale")
	s.Scale = scale or 1
	s.Parent = f
	for _, c in ipairs(bb:GetChildren()) do c.Parent = f end
	return f
end
-- HP bar in "just hit" state
local hp
for _, c in ipairs(H.lp.PlayerGui:GetChildren()) do if c.ClassName == "BillboardGui" then hp = c end end
local root = hp:GetChildren()[1]
local name = root:FindFirstChildOfClass("TextLabel")
name.Text = "Медь"
local bg = root:FindFirstChildOfClass("Frame")
local track = bg:FindFirstChildOfClass("Frame")
local kids = track:GetChildren()
local trail, fill, txt
for _, k in ipairs(kids) do
	if k.ClassName == "TextLabel" then txt = k elseif k.ZIndex == 2 then fill = k else trail = k end
end
trail.Size = UDim2.fromScale(0.72, 1)
fill.Size = UDim2.fromScale(0.48, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 214, 60):Lerp(Color3.fromRGB(255, 76, 70), 0.1)
txt.Text = "1.15K"
lift(hp, 640, 250, 1.6)
VFX.DamageNumber(Vector3.new(), "345", false)
VFX.DamageNumber(Vector3.new(), "КРИТ! 1.04K", true)
local i = 0
for _, p in ipairs(workspace:GetDescendants()) do
	if p.ClassName == "BillboardGui" and p.Name == "BB" then
		i = i + 1
		local l = p:FindFirstChild("L")
		l.TextTransparency = 0
		l.UIStroke.Transparency = 0
		lift(p, i == 1 and 470 or 820, 420, 1.3)
	end
end
H.out()
