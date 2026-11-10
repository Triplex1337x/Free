dofile(EMU .. "/harness.lua")
local U = game:GetService("UserInputService")
rawget(U, "_p").TouchEnabled = true
rawget(U, "_p").KeyboardEnabled = false
local UI = require(H.UIF.UIKit)
local HUD = require(H.UIF.HUD)
local g = H.screen("HUD", 1)
local ctx = { ClientState = H.ClientState, Sound = { Play = function() end }, OpenPanel = function() end }
local hud = HUD.Build(g, ctx)
hud.Refresh(H.Data)
R.run(1.0)
hud.Toast("Новый бур куплен!", "good")
hud.CoinPop(12500)
R.run(0.3)
H.out()
