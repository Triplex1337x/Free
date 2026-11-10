-- AssetForge: при старте сервера собирает все модели в ReplicatedStorage.Assets
-- (Pets, Drills, Backpacks, Eggs, NPC). Клиенты клонируют их оттуда.
-- Совет: запустите Play, скопируйте папку Assets, остановите игру и вставьте её —
-- так модели можно будет доработать руками в Studio (AssetForge не перезапишет готовые).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local PetLooks = require(Configs.PetLooks)
local DrillsData = require(Configs.DrillsData)
local BackpacksData = require(Configs.BackpacksData)
local EggsData = require(Configs.EggsData)
local PetBuilder = require(ReplicatedStorage.Shared.PetBuilder)
local GearBuilder = require(ReplicatedStorage.Shared.GearBuilder)
local NPCBuilder = require(ReplicatedStorage.Shared.NPCBuilder)

local AssetForge = {}

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

function AssetForge.Build()
	local assets = folder(ReplicatedStorage, "Assets")
	local pets = folder(assets, "Pets")
	local drills = folder(assets, "Drills")
	local packs = folder(assets, "Backpacks")
	local eggs = folder(assets, "Eggs")
	local npc = folder(assets, "NPC")
	folder(assets, "SFX")

	local n = 0
	for id in pairs(PetLooks) do
		if not pets:FindFirstChild(id) then
			local ok, model = pcall(PetBuilder.Build, id)
			if ok and model then
				model.Parent = pets
			else
				warn("[AssetForge] не удалось собрать питомца", id, model)
			end
			n = n + 1
			if n % 10 == 0 then
				task.wait()
			end
		end
	end
	for _, d in ipairs(DrillsData.List) do
		if not drills:FindFirstChild(d.Id) then
			GearBuilder.Drill(d).Parent = drills
		end
	end
	for _, p in ipairs(BackpacksData.List) do
		if not packs:FindFirstChild(p.Id) then
			GearBuilder.Backpack(p).Parent = packs
		end
	end
	for _, e in ipairs(EggsData.List) do
		if not eggs:FindFirstChild(e.Id) then
			GearBuilder.Egg(e).Parent = eggs
		end
	end
	if not npc:FindFirstChild("DrillBot3000") then
		NPCBuilder.DrillBot().Parent = npc
	end
	assets:SetAttribute("Ready", true)
	return {
		Pets = pets,
		Drills = drills,
		Backpacks = packs,
		Eggs = eggs,
		NPC = npc,
	}
end

return AssetForge
