-- ClientMain: точка входа клиента.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Parent:WaitForChild("Controllers")
ReplicatedStorage:WaitForChild("Remotes")
local assets = ReplicatedStorage:WaitForChild("Assets")
while not assets:GetAttribute("Ready") do
	assets:GetAttributeChangedSignal("Ready"):Wait()
end

local ClientState = require(Controllers:WaitForChild("ClientState"))
local Sound = require(Controllers:WaitForChild("SoundController"))
local Mining = require(Controllers:WaitForChild("MiningController"))
local PetFollow = require(Controllers:WaitForChild("PetFollowController"))
local CharacterController = require(Controllers:WaitForChild("CharacterController"))
local LightingController = require(Controllers:WaitForChild("LightingController"))
local WorldFx = require(Controllers:WaitForChild("WorldFxController"))
local UIController = require(Controllers:WaitForChild("UIController"))
local Settings = require(Controllers:WaitForChild("SettingsController"))
local Music = require(Controllers:WaitForChild("MusicController"))
local Detail = require(Controllers:WaitForChild("DetailController"))

ClientState.Init()
Settings.Init()
Sound.Init()
PetFollow.Init()
UIController.Init(PetFollow)
Mining.Init()
CharacterController.Init(Mining)
LightingController.Init()
WorldFx.Init()
Music.Init()
Detail.Init()
