-- SettingsController: качество графики и громкость. Хранится на сервере (data.Settings),
-- поэтому выбор сохраняется между входами и на всех устройствах игрока.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local ClientState = require(script.Parent.ClientState)

local SettingsController = {}
local changed = Instance.new("BindableEvent")
SettingsController.Changed = changed.Event

local DEFAULTS = { Quality = "", Music = 0.5, Sfx = 0.75 }
local local_ = nil -- локальная копия (сразу после изменения, до синхронизации)

function SettingsController.Get()
	local s = local_ or (ClientState.Data and ClientState.Data.Settings) or {}
	return {
		Quality = s.Quality or DEFAULTS.Quality,
		Music = s.Music or DEFAULTS.Music,
		Sfx = s.Sfx or DEFAULTS.Sfx,
	}
end

-- качество для применения: пока игрок не выбрал — «Средняя»
function SettingsController.Quality()
	local q = SettingsController.Get().Quality
	if q == "" then
		return "Medium"
	end
	return q
end

function SettingsController.Set(key, value)
	local cur = SettingsController.Get()
	cur[key] = value
	local_ = cur
	pcall(function()
		Net.Get("SaveSettings"):FireServer(key, value)
	end)
	changed:Fire(cur)
end

function SettingsController.Init()
	local last = ""
	ClientState.Changed:Connect(function(data)
		local s = data.Settings
		if not s then
			return
		end
		local sig = tostring(s.Quality) .. "|" .. tostring(s.Music) .. "|" .. tostring(s.Sfx)
		if sig ~= last then
			last = sig
			-- сервер подтвердил — локальная копия больше не нужна
			if local_ and local_.Quality == s.Quality and local_.Music == s.Music and local_.Sfx == s.Sfx then
				local_ = nil
			end
			if not local_ then
				changed:Fire(SettingsController.Get())
			end
		end
	end)
end

return SettingsController
