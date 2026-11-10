-- Notifier: тосты, баннеры и всплывающие монеты для клиентов.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local Notifier = {}

-- kind: "info" | "good" | "warn" | "error" | "seed" | "unlock"
function Notifier.Toast(player, text, kind, sound)
	Net.Get("Notify"):FireClient(player, text, kind or "info", sound)
end

function Notifier.ToastAll(text, kind, sound)
	Net.Get("Notify"):FireAllClients(text, kind or "info", sound)
end

-- Баннер (вайп шахты и т.п.)
function Notifier.Alert(player, kind, payload)
	Net.Get("SystemAlert"):FireClient(player, kind, payload)
end

function Notifier.AlertAll(kind, payload)
	Net.Get("SystemAlert"):FireAllClients(kind, payload)
end

function Notifier.Coins(player, amount, where)
	Net.Get("CoinsGained"):FireClient(player, amount, where)
end

return Notifier
