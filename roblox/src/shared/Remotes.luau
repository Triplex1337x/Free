-- Creates (server) or waits for (client) every remote the game uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Action", -- client -> server: combat input and shop prompts
	"DataSync", -- server -> client: player data snapshot
	"Fx", -- server -> all: visual effects
	"Knockback", -- server -> client: velocity to apply to your own character
	"Cooldown", -- server -> client: ability cooldown started
	"Notify", -- server -> client: toast message
	"Announce", -- server -> all: system chat message
}

local FUNCTIONS = {
	"GetData",
	"Roll",
	"Equip",
	"RedeemCode",
	"AllocateStat",
	"ResetStats",
	"Travel",
}

local Remotes = {}
local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in EVENTS do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in FUNCTIONS do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
