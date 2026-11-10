-- ClientState: последний снимок данных игрока с сервера + сигнал изменений.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ClientState = {}
ClientState.Data = nil
ClientState.ReceivedAt = 0
ClientState.ServerOffset = 0

local changed = Instance.new("BindableEvent")
ClientState.Changed = changed.Event

local function apply(snap)
	if not snap then
		return
	end
	ClientState.Data = snap
	ClientState.ReceivedAt = os.clock()
	if snap.Derived and snap.Derived.ServerTime then
		ClientState.ServerOffset = snap.Derived.ServerTime - os.time()
	end
	changed:Fire(snap)
end

-- unix-время сервера (для инкубатора)
function ClientState.ServerNow()
	return os.time() + ClientState.ServerOffset
end

-- оставшееся время активного буста с учётом локального отсчёта
function ClientState.BoostLeft(id)
	local d = ClientState.Data
	if not d or not d.ActiveBoosts then
		return 0
	end
	local t = d.ActiveBoosts[id] or 0
	return math.max(0, t - (os.clock() - ClientState.ReceivedAt))
end

function ClientState.Init()
	Net.Get("DataSync").OnClientEvent:Connect(apply)
	task.spawn(function()
		local snap = Net.Get("RequestSync"):InvokeServer()
		while not snap do
			task.wait(1)
			snap = Net.Get("RequestSync"):InvokeServer()
		end
		if not ClientState.Data then
			apply(snap)
		end
	end)
end

function ClientState.Wait()
	while not ClientState.Data do
		task.wait(0.1)
	end
	return ClientState.Data
end

return ClientState
