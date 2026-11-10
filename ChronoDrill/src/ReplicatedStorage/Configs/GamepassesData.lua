-- GamepassesData: геймпассы доната (магазин «Донат» в меню).
--
-- КАК ПОДКЛЮЧИТЬ: Creator Hub → твоя игра → Monetization → Passes → Create a Pass.
-- Скопируй ID пасса и впиши в поле Id нужной строки (вместо 0). Цену (Price) поставь ту же,
-- что указал на сайте, — она только показывается в меню.
-- Пока Id = 0, кнопка «Купить» пишет, что пасс не настроен (а админ может выдать пасс в F2).
local List = {
	{ Key = "VIP", Name = "VIP", Desc = "x1.25 монет и урона, +1 слот питомца, VIP-тег над головой", Price = 399, Glyph = "Crown", Color = { 255, 190, 40 }, Id = 0 },
	{ Key = "Coins2x", Name = "x2 Монеты", Desc = "Вся руда продаётся в 2 раза дороже", Price = 349, Glyph = "Coin", Color = { 255, 160, 30 }, Id = 0 },
	{ Key = "Damage2x", Name = "x2 Урон", Desc = "Бур бьёт в 2 раза сильнее", Price = 299, Glyph = "Pickaxe", Color = { 255, 84, 84 }, Id = 0 },
	{ Key = "Lucky", Name = "Удача", Desc = "x2 шанс редких, легендарных и мифических питомцев", Price = 249, Glyph = "Clover", Color = { 70, 205, 100 }, Id = 0 },
	{ Key = "HatchX8", Name = "Открытие x8", Desc = "Открывай сразу 8 яиц за раз", Price = 299, Glyph = "Egg", Color = { 170, 110, 255 }, Id = 0 },
	{ Key = "PetSlots", Name = "+2 питомца", Desc = "Надевай одновременно на 2 питомца больше", Price = 199, Glyph = "Paw", Color = { 255, 130, 60 }, Id = 0 },
	{ Key = "Storage100", Name = "+100 мест", Desc = "Инвентарь питомцев больше на 100 мест", Price = 149, Glyph = "Chest", Color = { 150, 100, 230 }, Id = 0 },
	{ Key = "BigBackpack", Name = "x2 Рюкзак", Desc = "Рюкзак вмещает в 2 раза больше руды", Price = 149, Glyph = "Backpack", Color = { 60, 150, 255 }, Id = 0 },
	{ Key = "AutoHatch", Name = "Автооткрытие", Desc = "Кнопка «Авто» в окне яйца: яйца открываются сами", Price = 299, Glyph = "Bolt", Color = { 40, 200, 190 }, Id = 0 },
	{ Key = "InfiniteBackpack", Name = "Бесконечный рюкзак", Desc = "ЭКСКЛЮЗИВ: рюкзак никогда не заполняется", Price = 3999, Glyph = "Backpack", Color = { 255, 70, 140 }, Id = 0, Exclusive = true },
	{ Key = "Speed", Name = "Быстрые ноги", Desc = "+30% к скорости бега", Price = 99, Glyph = "Rocket", Color = { 255, 100, 170 }, Id = 0 },
	{ Key = "Incubator", Name = "Слот инкубатора", Desc = "3-й слот для семян в инкубаторе", Price = 149, Glyph = "Sprout", Color = { 110, 200, 70 }, Id = 0 },
}

-- силы пассов (используются в Stats)
local Effects = {
	VIPCoins = 1.25,
	VIPDamage = 1.25,
	VIPSlots = 1,
	Coins2x = 2,
	Damage2x = 2,
	LuckyMult = 2,
	PetSlots = 2,
	BigBackpack = 2,
	Speed = 1.3,
}

local ById, ByKey = {}, {}
for i, p in ipairs(List) do
	p.Order = i
	ByKey[p.Key] = p
end

-- ID пасса (для слота инкубатора берём старое поле Balance.IncubatorGamepassId, если тут 0)
local function idOf(key)
	local p = ByKey[key]
	if not p then
		return 0
	end
	if p.Key == "Incubator" and (p.Id or 0) == 0 then
		local ok, Balance = pcall(function()
			return require(script.Parent.Balance)
		end)
		if ok and Balance.IncubatorGamepassId then
			return Balance.IncubatorGamepassId
		end
	end
	return p.Id or 0
end

local function rebuildIds()
	for k in pairs(ById) do
		ById[k] = nil
	end
	for _, p in ipairs(List) do
		local id = idOf(p.Key)
		if id ~= 0 then
			ById[id] = p
		end
	end
end
rebuildIds()

return {
	List = List,
	ByKey = ByKey,
	ById = ById,
	IdOf = idOf,
	Effects = Effects,
}
