-- BoostsData: бусты (ТЗ 7.1). Хранятся стаками, применяются вручную.
local function c(r, g, b) return { r, g, b } end

local Boosts = {
	{ Id = "CoinElixir", Name = "Эликсир монет", Desc = "x2 к продаже руды на 10 минут", Duration = 600, Mult = 2, Color = c(255, 196, 46), Shape = "flask" },
	{ Id = "DrillOvercharge", Name = "Перегрузка бура", Desc = "x2 к урону бура на 10 минут", Duration = 600, Mult = 2, Color = c(255, 90, 70), Shape = "bolt" },
	{ Id = "LuckyCharm", Name = "Талисман удачи", Desc = "+150% к шансу редких петов и семян на 15 минут", Duration = 900, Mult = 2.5, Color = c(90, 220, 110), Shape = "clover" },
	{ Id = "BioFertilizer", Name = "Био-удобрение", Desc = "Срезает 15 минут с таймера инкубатора", Instant = true, Cut = 900, Color = c(170, 110, 255), Shape = "drop" },
}

local byId = {}
for i, b in ipairs(Boosts) do
	b.Index = i
	byId[b.Id] = b
end

return { List = Boosts, ById = byId }
