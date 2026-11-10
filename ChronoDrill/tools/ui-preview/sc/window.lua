dofile(EMU .. "/harness.lua")
local UI = require(H.UIF.UIKit)
local Panels = require(H.UIF.Panels)
H.profile()
local g = H.screen("InventoryGui", 5)
local root = Instance.new("Frame")
root.Name = "Scaled"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = g
local ctx = H.ctx()
local panels = Panels.Build(root, ctx)
ctx.OpenPanel = function(n) if panels[n] then panels[n].Open() end end
local which = os.getenv and os.getenv("SC_WINDOW") or "Pets"
panels[which].Open()
R.run(0.6)
H.out()
