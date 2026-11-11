-- Client bootstrap.

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"InputController",
	"HudController",
	"RollController",
	"StatsController",
	"ZoneController",
	"QuestController",
	"InventoryController",
	"ShopController",
	"FxController",
	"JumpController",
	"AdminController",
	"MenuController",
}

local loaded = {}
for _, name in ORDER do
	loaded[name] = require(Controllers:WaitForChild(name))
end

for _, name in ORDER do
	local controller = loaded[name]
	if controller.Init then
		controller:Init()
	end
end

for _, name in ORDER do
	local controller = loaded[name]
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end
