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
if which == "Egg" then
	H.Data.AutoDelete = { MushroomPup = true, PetalBunny = true }
	for _, id in ipairs({ "MushroomPup", "PetalBunny", "MossTurtle", "GlowJelly", "FairyFox", "Bunny", "Kitty", "Puppy" }) do H.Data.Index[id] = true end
	panels.Egg.ShowEgg(os.getenv("SC_EGG") or "Fairy")
else
	panels[which].Open()
end
R.run(0.6)
local clickN = tonumber(os.getenv("SC_CLICK") or "")
if clickN then
	local n = 0
	for _, d in ipairs(panels[which].Root:GetDescendants()) do
		if d.ClassName == "TextButton" and d.ZIndex == 9 and d.Text == "" then
			n = n + 1
			if n == clickN then d.Activated:Fire() break end
		end
	end
	R.run(0.4)
end
H.out()
