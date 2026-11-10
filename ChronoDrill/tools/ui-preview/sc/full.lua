dofile(EMU .. "/harness.lua")
H.profile()
local UIC = require(H.CF.UIController)
local ok, err = pcall(UIC.Init, { DisplayModel = function() return Instance.new("Model") end })
print("Init ok:", ok, err)
H.ClientState.Data.Tutorial = false
R.run(1.5)
-- fire a data change and open a few panels through keyboard-less path
local cs = H.ClientState
H.out()
