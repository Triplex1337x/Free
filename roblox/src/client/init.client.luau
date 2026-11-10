-- Client bootstrap.

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"InputController",
	"HudController",
	"RollController",
	"ShopController",
	"FxController",
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
