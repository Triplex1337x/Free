-- Latest player data snapshot from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local State = {}
State.Data = nil :: any

local changed = Instance.new("BindableEvent")

local function apply(snapshot)
	if type(snapshot) ~= "table" then
		return
	end
	State.Data = snapshot
	changed:Fire(snapshot)
end

Remotes.DataSync.OnClientEvent:Connect(apply)
task.spawn(function()
	local ok, snapshot = pcall(Remotes.GetData.InvokeServer, Remotes.GetData)
	if ok and snapshot and not State.Data then
		apply(snapshot)
	end
end)

-- Calls `fn` now (if data exists) and on every change.
function State.Observe(fn: (any) -> ())
	if State.Data then
		task.spawn(fn, State.Data)
	end
	return changed.Event:Connect(fn)
end

return State
