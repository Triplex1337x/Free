dofile(EMU .. "/harness.lua")
local UI = require(H.UIF.UIKit)
local EggOpening = require(H.UIF.EggOpening)
local PetsData = require(game:GetService("ReplicatedStorage").Configs.PetsData)
H.profile()
local ctx = H.ctx()
EggOpening.Build(ctx)
local want = { "Common", "Rare", "Epic" }
local pets = {}
for _, rk in ipairs(want) do
	local best
	for id, p in pairs(PetsData.ById) do
		if p.Rarity == rk and not p.Special and (not best or id < best) then best = id end
	end
	table.insert(pets, { Id = best, T = 0 })
end
local N = tonumber(os.getenv("EGG_N") or "3")
while #pets > N do table.remove(pets) end
while #pets < N do table.insert(pets, { Id = pets[1].Id, T = 0 }) end
local EggsData = require(game:GetService("ReplicatedStorage").Configs.EggsData)
local eggId
for id in pairs(EggsData.ById) do eggId = eggId or id end
EggOpening.Play(eggId, pets)
R.run(tonumber(os.getenv("EGG_T") or "2.8"))
H.out()
