-- SoundsData: все звуки и музыка игры.
--
-- КАК ПОСТАВИТЬ НАШИ ЗВУКИ (папка SFX в архиве, 19 звуков + 3 трека музыки):
--   1) Studio → View → Asset Manager → кнопка «Bulk Import» → выбери все .ogg из папки SFX.
--   2) В Asset Manager → Audio появятся звуки. Перетащи каждый в Explorer в папку
--      ReplicatedStorage → CustomSounds (имя Sound должно совпадать с именем файла: BlockBreak, Music_Hub...).
--   Всё — игра сама берёт звуки из CustomSounds. Ничего вписывать сюда не нужно.
--   (Можно и по-старому: скопировать ID и вписать в Id ниже как "rbxassetid://123456".)
--
-- Пока свои звуки не загружены, играют мягкие встроенные звуки Roblox (без «взрывов»), музыки нет.
return {
	Click = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.18, Pitch = 2 },
	Hover = { Id = "", Volume = 0.1 },
	DrillHit = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.22, Pitch = 0.6 },
	Crit = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 1.4 },
	BlockBreak = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Pitch = 0.42 },
	OrePickup = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.12, Pitch = 2.4 },
	Coins = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Pitch = 1.25 },
	EggShake = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Pitch = 0.7 },
	EggCrack = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Pitch = 1.1 },
	Reveal = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 0.9 },
	Warning = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 0.7 },
	Siren = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 0.5 },
	Teleport = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.3, Pitch = 1.1 },
	Unlock = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.0 },
	Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.3, Pitch = 0.5 },
	Full = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.3, Pitch = 0.45 },
	Seed = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.8 },
	LevelUp = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.5 },
	Upgrade = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 1.2 },

	-- фоновая музыка (зацикленная): база, шахта, глубины (Магма и Бездна)
	Music = {
		Music_Hub = { Id = "" },
		Music_Mine = { Id = "" },
		Music_Deep = { Id = "" },
	},
}
