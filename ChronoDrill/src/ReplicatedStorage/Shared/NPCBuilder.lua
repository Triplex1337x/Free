-- NPCBuilder: квестовый робот Drill-Bot 3000.
-- Модель стоит на y = 0, смотрит в -Z. Детали "Eye", "Head", "Antenna", "Arm" анимирует клиент.
local MK = require(script.Parent.ModelKit)

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local NPCBuilder = {}

function NPCBuilder.DrillBot()
	local model = Instance.new("Model")
	model.Name = "DrillBot3000"
	local yellow = Color3.fromRGB(255, 196, 46)
	local dark = Color3.fromRGB(46, 44, 58)
	local steel = Color3.fromRGB(176, 182, 196)
	local screen = Color3.fromRGB(22, 30, 44)
	local cyan = Color3.fromRGB(90, 230, 255)

	local root = MK.Part(model, V3(1, 1, 1), CF(0, 3, 0), steel, { Name = "Root", Transparency = 1 })
	model.PrimaryPart = root

	-- гусеничная база
	for _, s in ipairs({ -1, 1 }) do
		MK.Part(model, V3(1.1, 1.3, 3.6), CF(s * 1.45, 0.65, 0), dark)
		for k = -1, 1 do
			MK.Cylinder(model, 1.16, 1.0, CF(s * 1.45, 0.6, k * 1.1), steel)
		end
		MK.Part(model, V3(1.16, 0.18, 3.7), CF(s * 1.45, 1.32, 0), yellow)
	end
	MK.Part(model, V3(2.0, 0.8, 2.6), CF(0, 1.1, 0), dark)

	-- корпус
	local body = MK.Part(model, V3(3.2, 2.6, 2.4), CF(0, 2.75, 0), yellow, { Name = "Body" })
	MK.Part(model, V3(3.3, 0.3, 2.5), CF(0, 1.55, 0), dark)
	MK.Part(model, V3(2.0, 1.2, 0.2), CF(0, 2.8, -1.25), screen)
	for i = -1, 1 do
		local c = (i == 0) and Color3.fromRGB(110, 230, 120) or ((i < 0) and Color3.fromRGB(255, 90, 90) or cyan)
		MK.Ellipsoid(model, V3(0.3, 0.3, 0.15), CF(i * 0.55, 2.55, -1.36), c, { Material = "Neon", Name = "Led" })
	end
	MK.Part(model, V3(1.4, 0.16, 0.12), CF(0, 3.1, -1.36), cyan, { Material = "Neon" })
	-- болты и полосы
	for _, x in ipairs({ -1.45, 1.45 }) do
		for _, y in ipairs({ 1.8, 3.7 }) do
			MK.Ellipsoid(model, V3(0.22, 0.22, 0.1), CF(x, y, -1.22), steel)
		end
	end
	for k = -2, 2 do
		MK.Wedge(model, V3(0.3, 0.4, 0.25), CF(k * 0.6, 3.95, -1.1) * ANG(0, 0, 0), dark)
	end

	-- шея и голова
	MK.Cylinder(model, 0.6, 0.9, CF(0, 4.3, 0) * ANG(0, 0, rad(90)), steel)
	local head = MK.Part(model, V3(2.6, 1.8, 2.0), CF(0, 5.4, 0), steel, { Name = "Head" })
	MK.Part(model, V3(2.2, 1.3, 0.12), CF(0, 5.4, -1.02), screen, { Name = "Visor" })
	for _, s in ipairs({ -1, 1 }) do
		local eye = MK.Ellipsoid(model, V3(0.5, 0.62, 0.12), CF(s * 0.5, 5.5, -1.1), cyan, { Material = "Neon", Name = "Eye" })
		eye:SetAttribute("BaseY", 0.62)
		MK.Cylinder(model, 0.3, 0.7, CF(s * 1.42, 5.4, 0), yellow)
	end
	MK.Ellipsoid(model, V3(0.7, 0.18, 0.1), CF(0, 5.05, -1.1), cyan, { Material = "Neon", Name = "Mouth" })
	-- каска с фонарём
	MK.Part(model, V3(2.8, 0.4, 2.2), CF(0, 6.45, 0), yellow)
	MK.Part(model, V3(3.1, 0.15, 2.5), CF(0, 6.3, -0.1), yellow)
	MK.Cylinder(model, 0.3, 0.6, CF(0, 6.5, -1.15) * ANG(0, rad(90), 0), Color3.fromRGB(255, 250, 210), { Material = "Neon" })
	-- антенна
	MK.Cylinder(model, 1.1, 0.12, CF(0.8, 7.2, 0.3) * ANG(0, 0, rad(90)), dark, { Name = "Antenna" })
	local bulb = MK.Ellipsoid(model, V3(0.4, 0.4, 0.4), CF(0.8, 7.8, 0.3), Color3.fromRGB(255, 80, 80), { Material = "Neon", Name = "AntennaBulb" })
	MK.Light(bulb, { 255, 80, 80 }, 6, 1)

	-- руки: левая — клешня, правая — бур
	for _, s in ipairs({ -1, 1 }) do
		local shoulder = V3(s * 1.85, 3.4, 0)
		MK.Ellipsoid(model, V3(0.9, 0.9, 0.9), CF(shoulder), dark, { Name = "Arm" })
		MK.CylinderBetween(model, shoulder, shoulder + V3(s * 0.3, -1.2, -0.5), 0.45, steel).Name = "Arm"
		local hand = shoulder + V3(s * 0.3, -1.4, -0.7)
		if s < 0 then
			MK.Part(model, V3(0.5, 0.25, 0.7), CF(hand + V3(0, 0.15, -0.2)), dark).Name = "Arm"
			MK.Part(model, V3(0.5, 0.25, 0.7), CF(hand + V3(0, -0.2, -0.2)), dark).Name = "Arm"
		else
			MK.Cylinder(model, 0.5, 0.75, CF(hand) * ANG(0, rad(90), 0), dark).Name = "Arm"
			local z = hand.Z - 0.25
			for i, d in ipairs({ 0.6, 0.42, 0.26 }) do
				MK.Cylinder(model, 0.35, d, CF(hand.X, hand.Y, z - 0.18) * ANG(0, rad(90), 0), steel, { Material = "Metal", Name = "DrillBit" })
				z = z - 0.32
			end
		end
	end

	model:SetAttribute("Npc", "DrillBot")
	return model
end

return NPCBuilder
