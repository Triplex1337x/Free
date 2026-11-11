-- Server bootstrap: require every service, Init them (wiring), then Start them.

local Players = game:GetService("Players")

-- Characters are spawned by DataService once a profile has loaded, so no one
-- fights with default stats before their data is in.
Players.CharacterAutoLoads = false

local ORDER = {
	"DataService",
	"MapService",
	"ZoneService",
	"MonetizationService",
	"ProgressionService",
	"QuestService",
	"InventoryService",
	"CombatService",
	"GachaService",
	"CodesService",
	"DummyService",
	"MobService",
	"AdminService",
}

local Services = {}
for _, name in ORDER do
	Services[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = Services[name]
	if service.Init then
		service:Init(Services)
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print(("[Rift] Server started with %d services"):format(#ORDER))
