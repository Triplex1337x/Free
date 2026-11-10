-- PetLooks: внешний вид каждого питомца для процедурного PetBuilder.
-- A  = архетип (quad, blob, bird, bug, crab, fish, dino, dragon, golem, orb, serpent, wisp, bat)
-- C  = основной цвет, C2 = акцентный цвет (живот, уши, когти), C3 = цвет деталей
-- M  = материал корпуса (SmoothPlastic по умолчанию), M2 = материал акцентов
-- X  = детали (уши, рога, крылья, ...), E = стиль глаз ("glow" — светящиеся)
-- Fly = летает ли питомец (по умолчанию определяется архетипом)
local function c(r, g, b) return { r, g, b } end

return {
	-- БИОМ 1 — Земляное яйцо
	Worm = { A = "serpent", C = c(240, 150, 160), C2 = c(255, 196, 200), X = { "cheeks" }, Fly = false },
	Mouse = { A = "quad", C = c(170, 172, 184), C2 = c(255, 190, 200), X = { "ears_round_big", "tail_thin", "whiskers", "nose", "cheeks" } },
	Mole = { A = "quad", C = c(94, 70, 62), C2 = c(255, 160, 180), X = { "claws", "nose_big", "whiskers" }, E = "small" },
	Hedgehog = { A = "quad", C = c(150, 104, 70), C2 = c(246, 220, 180), C3 = c(96, 64, 44), X = { "spikes_back", "nose", "cheeks" } },
	Armadillo = { A = "quad", C = c(200, 160, 120), C2 = c(236, 206, 170), C3 = c(160, 120, 86), X = { "shell", "ears_pointy", "tail_thin" } },

	-- Каменное яйцо
	Scarab = { A = "bug", C = c(46, 170, 140), C2 = c(30, 110, 96), C3 = c(255, 210, 80), M = "Metal", X = { "antennae", "horn_single" } },
	StoneCrab = { A = "crab", C = c(130, 140, 160), C2 = c(200, 120, 90), X = { "spots" } },
	CaveBat = { A = "bat", C = c(110, 80, 150), C2 = c(255, 170, 200), X = { "ears_pointy_big", "fangs" } },
	Badger = { A = "quad", C = c(60, 60, 68), C2 = c(244, 244, 246), X = { "stripe_head", "ears_round", "claws", "nose" } },
	IronPup = { A = "quad", C = c(150, 156, 170), C2 = c(90, 96, 110), C3 = c(255, 200, 60), M = "Metal", X = { "ears_pointy", "tail_thin", "bolts" }, E = "glow", EyeColor = c(100, 220, 255) },
	MicroGolem = { A = "golem", C = c(130, 126, 136), C2 = c(90, 220, 255), X = { "crystals", "moss" }, E = "glow", EyeColor = c(90, 230, 255) },

	-- БИОМ 2 — Окаменелое яйцо
	Anomalo = { A = "fish", C = c(230, 110, 70), C2 = c(255, 190, 120), X = { "feelers", "segments" } },
	Trilobite = { A = "bug", C = c(170, 140, 110), C2 = c(120, 96, 76), X = { "segments", "antennae" } },
	BabyRaptor = { A = "dino", C = c(100, 190, 90), C2 = c(236, 230, 160), X = { "crest_small", "claws", "stripes" } },
	Ptero = { A = "bird", C = c(150, 120, 190), C2 = c(255, 200, 140), X = { "wings_bat", "crest_long", "beak_long" } },
	Stego = { A = "dino", C = c(90, 160, 120), C2 = c(255, 150, 80), X = { "plates_back", "tail_spikes" } },
	SaberPup = { A = "quad", C = c(236, 160, 70), C2 = c(255, 236, 200), C3 = c(120, 70, 40), X = { "tusks_down", "ears_round", "stripes", "tail_thin" } },

	-- Янтарное яйцо
	AmberFly = { A = "bug", C = c(255, 160, 40), C2 = c(255, 220, 140), M = "Glass", X = { "wings_crystal", "antennae" }, Fly = true },
	Monitor = { A = "quad", C = c(110, 140, 80), C2 = c(200, 200, 140), X = { "tail_long", "snout", "spots", "tongue" }, Long = true },
	Mammoth = { A = "quad", C = c(150, 100, 70), C2 = c(250, 244, 230), X = { "tusks", "trunk", "ears_round_big", "fur_top" }, S = 1.1 },
	Ankylo = { A = "dino", C = c(170, 130, 90), C2 = c(230, 200, 150), X = { "spikes_back", "club_tail", "shell" } },
	Brachio = { A = "dino", C = c(120, 170, 200), C2 = c(220, 240, 255), X = { "long_neck", "spots" } },
	Rex = { A = "dino", C = c(200, 70, 60), C2 = c(255, 220, 160), X = { "big_head", "tiny_arms", "teeth" }, Biped = true },
	PrimeDrake = { A = "dragon", C = c(255, 150, 30), C2 = c(255, 230, 140), M2 = "Glass", X = { "horns", "wings_bat", "spikes_back", "glow" }, E = "glow", EyeColor = c(255, 240, 120) },

	-- БИОМ 3 — Снежное яйцо
	FrostPenguin = { A = "bird", C = c(40, 44, 62), C2 = c(248, 250, 255), X = { "beak", "belly", "scarf", "flippers" }, Fly = false },
	SnowHare = { A = "quad", C = c(248, 250, 255), C2 = c(255, 190, 210), X = { "ears_long", "tail_puff", "nose", "cheeks" } },
	IceWolf = { A = "quad", C = c(200, 224, 246), C2 = c(255, 255, 255), C3 = c(90, 150, 220), X = { "ears_pointy", "tail_fluffy", "snout", "fur_top" } },
	Walrus = { A = "blob", C = c(170, 120, 100), C2 = c(255, 236, 210), X = { "tusks_down", "whiskers", "flippers", "helmet" } },
	BlizzardOwl = { A = "bird", C = c(220, 230, 244), C2 = c(140, 170, 210), X = { "ear_tufts", "wings_feather", "beak", "belly" }, E = "big" },
	FrostStag = { A = "quad", C = c(160, 214, 250), C2 = c(240, 250, 255), M2 = "Glass", X = { "antlers", "ears_pointy", "tail_puff", "crystals" }, E = "glow", EyeColor = c(160, 240, 255) },

	-- Морозное яйцо
	CryoFox = { A = "quad", C = c(90, 210, 240), C2 = c(240, 252, 255), X = { "ears_pointy_big", "tail_fluffy", "snout", "cheeks" } },
	FrostWisp = { A = "wisp", C = c(160, 230, 255), C2 = c(255, 255, 255), M = "Glass", X = { "flame", "sparkle" }, E = "big" },
	CaveYeti = { A = "golem", C = c(236, 244, 255), C2 = c(120, 170, 220), X = { "fur_top", "horns_small" }, Furry = true },
	Narwhal = { A = "fish", C = c(110, 150, 220), C2 = c(220, 236, 255), M2 = "Glass", X = { "horn_single_long", "spots", "tail_fluke" }, Narrow = true },
	SapphireBear = { A = "quad", C = c(50, 90, 210), C2 = c(140, 200, 255), M2 = "Glass", X = { "ears_round", "crystals", "snout" }, S = 1.1 },
	FrostLeviathan = { A = "serpent", C = c(80, 170, 230), C2 = c(220, 250, 255), M2 = "Glass", X = { "horns", "fins", "glow" }, E = "glow", EyeColor = c(200, 250, 255) },
	StormMonarch = { A = "bird", C = c(110, 70, 220), C2 = c(255, 230, 100), X = { "crown", "wings_feather", "tail_feathers", "glow", "sparkle" }, E = "glow", EyeColor = c(255, 240, 120) },

	-- БИОМ 4 — Яйцо углей
	LavaSalamander = { A = "quad", C = c(240, 90, 40), C2 = c(255, 200, 80), X = { "tail_long", "spots_glow", "frills" }, Long = true },
	MagmaSlime = { A = "blob", C = c(255, 110, 30), C2 = c(255, 210, 80), M = "Glass", X = { "drips", "inner_core", "cheeks" } },
	BasaltCrab = { A = "crab", C = c(60, 56, 64), C2 = c(255, 110, 40), X = { "cracks_glow" } },
	ObsidianHound = { A = "quad", C = c(36, 28, 48), C2 = c(140, 70, 220), X = { "ears_pointy", "tail_thin", "spikes_back", "snout" }, E = "glow", EyeColor = c(255, 80, 60) },
	HellBat = { A = "bat", C = c(160, 30, 40), C2 = c(255, 140, 60), X = { "horns_small", "ears_pointy_big", "fangs" }, E = "glow", EyeColor = c(255, 220, 80) },
	LavaRay = { A = "fish", C = c(70, 40, 40), C2 = c(255, 120, 30), X = { "cracks_glow", "tail_whip", "glow" }, Wide = true },

	-- Яйцо Инферно
	MiniEfreet = { A = "wisp", C = c(255, 80, 40), C2 = c(255, 210, 80), M = "Neon", X = { "horns", "flame", "arms_small" }, E = "glow", EyeColor = c(255, 255, 200) },
	SulfurScorpion = { A = "bug", C = c(230, 200, 50), C2 = c(140, 110, 20), X = { "stinger", "pincers" } },
	InfernoTiger = { A = "quad", C = c(255, 120, 30), C2 = c(255, 240, 210), C3 = c(40, 30, 30), X = { "ears_round", "stripes", "tail_thin", "snout", "flame_tail" } },
	MoltenColossus = { A = "golem", C = c(50, 44, 50), C2 = c(255, 120, 30), X = { "cracks_glow", "shoulder_lava" }, E = "glow", EyeColor = c(255, 160, 40), S = 1.15 },
	SolarPhoenix = { A = "bird", C = c(255, 120, 30), C2 = c(255, 230, 80), X = { "wings_feather", "crest_long", "tail_feathers", "flame", "glow" }, E = "glow", EyeColor = c(255, 255, 220) },
	NetherWyrm = { A = "serpent", C = c(110, 20, 40), C2 = c(255, 90, 50), X = { "horns", "spikes_back", "glow" }, E = "glow", EyeColor = c(255, 200, 60) },
	CoreElemental = { A = "orb", C = c(255, 140, 30), C2 = c(255, 240, 160), M = "Neon", X = { "rings", "shards" }, E = "glow", EyeColor = c(255, 255, 255) },
	MagmaDeity = { A = "golem", C = c(255, 190, 60), C2 = c(255, 80, 30), M = "Metal", X = { "crown", "halo", "shoulder_lava", "glow" }, E = "glow", EyeColor = c(255, 255, 200), S = 1.2 },

	-- БИОМ 5 — Яйцо Сингулярности
	VoidWisp = { A = "wisp", C = c(110, 60, 210), C2 = c(200, 160, 255), M = "Glass", X = { "flame", "sparkle" }, E = "big" },
	RiftBug = { A = "bug", C = c(220, 70, 200), C2 = c(90, 240, 255), X = { "wings_crystal", "antennae", "cracks_glow" }, Fly = true },
	EtherRay = { A = "fish", C = c(90, 230, 255), C2 = c(220, 250, 255), M = "Glass", X = { "tail_whip", "sparkle" }, Wide = true },
	ChronoHound = { A = "quad", C = c(40, 50, 110), C2 = c(90, 240, 255), X = { "ears_pointy", "rings", "tail_thin", "snout" }, E = "glow", EyeColor = c(90, 240, 255) },
	AbyssPhantom = { A = "wisp", C = c(30, 20, 60), C2 = c(140, 90, 255), M = "Glass", X = { "hood", "arms_small", "flame" }, E = "glow", EyeColor = c(200, 140, 255) },
	QuantumTitan = { A = "golem", C = c(60, 50, 120), C2 = c(90, 240, 255), X = { "crystals", "rings", "cracks_glow" }, E = "glow", EyeColor = c(90, 240, 255), S = 1.15 },
	VoidEye = { A = "orb", C = c(40, 20, 80), C2 = c(255, 80, 200), X = { "eye_single", "rings", "tentacles" } },

	-- Яйцо Конца Времён
	StarShardling = { A = "orb", C = c(255, 230, 120), C2 = c(255, 255, 255), M = "Neon", X = { "star_points", "sparkle" } },
	GravitonWorm = { A = "serpent", C = c(120, 60, 220), C2 = c(255, 200, 255), X = { "rings", "glow" } },
	NebulaFox = { A = "quad", C = c(220, 100, 220), C2 = c(120, 200, 255), X = { "ears_pointy_big", "tail_fluffy", "stars", "snout" } },
	ChronosSentinel = { A = "golem", C = c(240, 200, 90), C2 = c(70, 120, 230), M = "Metal", X = { "halo", "crystals", "clock_face" }, E = "glow", EyeColor = c(120, 220, 255) },
	SupernovaBehemoth = { A = "quad", C = c(255, 170, 80), C2 = c(255, 250, 230), X = { "horns", "spikes_back", "glow", "sparkle" }, E = "glow", EyeColor = c(255, 255, 255), S = 1.25 },
	CosmicOuroboros = { A = "serpent", C = c(40, 30, 90), C2 = c(255, 200, 80), X = { "stars", "horns", "glow", "ring_self" }, E = "glow", EyeColor = c(255, 220, 120) },
	VoidArbiter = { A = "golem", C = c(20, 16, 30), C2 = c(200, 90, 255), M2 = "Neon", X = { "crown", "hood", "cracks_glow", "glow" }, E = "glow", EyeColor = c(220, 120, 255), S = 1.2 },
	EventHorizonDrake = { A = "dragon", C = c(20, 18, 34), C2 = c(255, 140, 40), X = { "horns", "wings_bat", "rings", "glow" }, E = "glow", EyeColor = c(255, 170, 60), S = 1.2 },
	PrimordialChronos = { A = "dragon", C = c(255, 220, 120), C2 = c(90, 240, 255), M = "Metal", M2 = "Glass", X = { "horns", "wings_crystal", "halo", "rings", "glow", "sparkle" }, E = "glow", EyeColor = c(150, 255, 255), S = 1.3 },

	-- Эксклюзивы: ежедневная награда и колесо удачи
	ChronoKitsune = { A = "quad", C = c(250, 250, 255), C2 = c(120, 230, 255), C3 = c(190, 120, 255), X = { "ears_pointy_big", "tails_multi", "halo", "sparkle", "glow", "cheeks" }, S = 1.15 },
	StarGriffin = { A = "bird", C = c(255, 214, 90), C2 = c(255, 250, 230), C3 = c(200, 140, 40), X = { "wings_feather", "crown", "tail_feathers", "beak", "sparkle", "glow" }, E = "big", S = 1.15 },
	FortuneCat = { A = "quad", C = c(255, 250, 240), C2 = c(255, 200, 60), C3 = c(255, 140, 60), X = { "ears_pointy", "tail_thin", "bell", "spots", "sparkle", "cheeks" }, S = 1.1 },

	-- Питомцы из семян
	SproutSprite = { A = "blob", C = c(120, 210, 90), C2 = c(255, 250, 200), X = { "leaf", "cheeks", "flowers" } },
	AmberTreant = { A = "golem", C = c(140, 96, 60), C2 = c(255, 170, 40), M2 = "Glass", X = { "leaf", "crystals", "moss" }, E = "glow", EyeColor = c(255, 200, 80) },
	GlacierMoth = { A = "bug", C = c(240, 248, 255), C2 = c(140, 220, 255), M2 = "Glass", X = { "wings_crystal", "antennae", "fur_top" }, Fly = true },
	MagmaHydra = { A = "serpent", C = c(200, 40, 30), C2 = c(255, 180, 50), X = { "horns", "extra_heads", "glow" }, E = "glow", EyeColor = c(255, 230, 100) },
	ChronoSeraph = { A = "bird", C = c(255, 240, 200), C2 = c(140, 110, 255), X = { "wings_feather", "halo", "rings", "tail_feathers", "glow", "sparkle" }, E = "glow", EyeColor = c(160, 240, 255), S = 1.2 },
	-- ПУШИСТОЕ ЯЙЦО (ярус 1)
	Bunny = { A = "quad", C = c(252, 252, 255), C2 = c(255, 205, 220), X = { "ears_long", "tail_puff", "nose", "cheeks" }, Iris = c(90, 200, 120) },
	Kitty = { A = "quad", C = c(255, 196, 120), C2 = c(255, 245, 225), C3 = c(220, 130, 60), X = { "ears_pointy", "tail_thin", "whiskers", "stripe_head", "cheeks" }, Iris = c(255, 180, 40) },
	Puppy = { A = "quad", C = c(230, 186, 140), C2 = c(255, 248, 235), C3 = c(140, 96, 70), X = { "ears_round_big", "tail_thin", "nose", "tongue", "spots" }, Iris = c(120, 80, 40) },
	RedPanda = { A = "quad", C = c(214, 96, 50), C2 = c(255, 245, 235), C3 = c(90, 50, 40), X = { "ears_round", "tail_fluffy", "stripes", "nose", "cheeks" } },
	Fox = { A = "quad", C = c(255, 140, 50), C2 = c(255, 250, 240), C3 = c(60, 40, 40), X = { "ears_pointy_big", "tail_fluffy", "nose", "cheeks" }, Iris = c(60, 200, 120) },
	Panda = { A = "quad", C = c(250, 250, 252), C2 = c(40, 38, 46), C3 = c(40, 38, 46), X = { "ears_round", "nose", "spots", "cheeks", "sparkle" }, Iris = c(80, 80, 90), S = 1.05 },
	DemonCat = { A = "quad", C = c(36, 26, 44), C2 = c(255, 60, 90), C3 = c(20, 14, 26), X = { "ears_pointy_big", "tails_multi", "fangs" }, E = "glow", EyeColor = c(255, 60, 70),
		Mythic = { Wings = "demon", Horns = "curved", Fire = c(255, 40, 60), Fire2 = c(255, 160, 60), Glow = c(255, 50, 90), Smoke = c(40, 10, 30), FlameTail = true } },

	-- мифики ярусa 1
	CelestialUnicorn = { A = "quad", C = c(255, 255, 255), C2 = c(255, 190, 240), C3 = c(190, 160, 255), X = { "ears_pointy", "tail_fluffy", "cheeks" }, E = "glow", EyeColor = c(150, 220, 255),
		Mythic = { Wings = "angel", Horns = "unicorn", Halo = true, Glow = c(170, 140, 255), C1 = c(255, 255, 255), C2 = c(255, 215, 120) } },
	ObsidianWyvern = { A = "quad", C = c(34, 30, 46), C2 = c(170, 90, 255), C3 = c(20, 16, 28), X = { "ears_pointy", "spikes_back", "tail_spikes", "fangs" }, E = "glow", EyeColor = c(200, 120, 255),
		Mythic = { Wings = "demon", Horns = "curved", Glow = c(180, 90, 255), Fire = c(140, 60, 255), Fire2 = c(240, 160, 255), Smoke = c(30, 10, 50) } },

	-- САВАННА (ярус 2)
	LionCub = { A = "quad", C = c(244, 190, 90), C2 = c(255, 240, 200), C3 = c(170, 100, 40), X = { "ears_round", "fur_top", "tail_thin", "nose", "cheeks" }, Iris = c(255, 170, 40) },
	Zebra = { A = "quad", C = c(250, 250, 250), C2 = c(240, 240, 244), C3 = c(30, 28, 34), X = { "ears_pointy", "stripes", "stripe_head", "fur_top", "tail_thin" } },
	Hippo = { A = "quad", C = c(170, 150, 200), C2 = c(255, 190, 210), X = { "ears_round", "nose_big", "teeth", "cheeks" }, S = 1.05 },
	Giraffe = { A = "quad", C = c(255, 200, 90), C2 = c(255, 240, 200), C3 = c(170, 100, 40), X = { "ears_pointy", "horns_small", "spots", "tail_thin" }, Box = { 2.1, 2.7, 2.0 } },
	Rhino = { A = "quad", C = c(160, 166, 176), C2 = c(220, 224, 230), X = { "ears_round", "horn_single", "nose" }, S = 1.08 },
	Elephant = { A = "quad", C = c(150, 170, 200), C2 = c(255, 200, 220), X = { "ears_round_big", "trunk", "tusks", "cheeks" }, S = 1.12 },
	SunLion = { A = "quad", C = c(255, 200, 60), C2 = c(255, 245, 200), C3 = c(220, 120, 30), X = { "ears_round", "fur_top", "tail_thin", "crown" }, E = "glow", EyeColor = c(255, 240, 120),
		Mythic = { Wings = "flame", Halo = true, HaloColor = c(255, 200, 60), Glow = c(255, 190, 40), Fire = c(255, 160, 30), Fire2 = c(255, 240, 140), Orbit = true } },

	-- мифики яруса 2
	AncientPhoenix = { A = "bird", C = c(255, 110, 40), C2 = c(255, 220, 90), C3 = c(200, 40, 30), X = { "beak", "crest_long", "tail_feathers" }, E = "glow", EyeColor = c(255, 230, 120),
		Mythic = { Wings = "flame", Glow = c(255, 160, 40), Fire = c(255, 90, 30), Fire2 = c(255, 220, 80), FlameTail = true } },
	AmberSeraph = { A = "orb", C = c(255, 170, 40), C2 = c(255, 235, 160), M = "Glass", X = { "inner_core", "cheeks" }, E = "glow", EyeColor = c(255, 250, 200),
		Mythic = { Body = "orb", Wings = "crystal", Halo = true, Glow = c(255, 200, 80), Orbit = true, Trim = false } },

	-- СЕВЕРНОЕ СИЯНИЕ (ярус 3)
	ArcticFox = { A = "quad", C = c(248, 252, 255), C2 = c(200, 230, 255), X = { "ears_pointy_big", "tail_fluffy", "nose" }, Iris = c(80, 170, 255) },
	SnowOwl = { A = "bird", C = c(250, 252, 255), C2 = c(220, 230, 240), C3 = c(60, 60, 70), X = { "beak", "ear_tufts", "spots" }, Iris = c(255, 200, 40), E = "big" },
	Seal = { A = "blob", C = c(200, 210, 224), C2 = c(250, 252, 255), X = { "whiskers", "nose", "flippers", "cheeks" }, Iris = c(60, 60, 80) },
	Reindeer = { A = "quad", C = c(170, 110, 70), C2 = c(250, 236, 214), X = { "antlers", "ears_round", "nose_big", "scarf" } },
	PolarBear = { A = "quad", C = c(250, 250, 255), C2 = c(230, 236, 245), X = { "ears_round", "nose", "claws" }, S = 1.1 },
	AuroraWolf = { A = "quad", C = c(80, 110, 170), C2 = c(140, 255, 210), C3 = c(200, 130, 255), X = { "ears_pointy_big", "tail_fluffy", "spots_glow", "fangs" }, E = "glow", EyeColor = c(140, 255, 220), S = 1.1 },
	AuroraStag = { A = "quad", C = c(60, 80, 160), C2 = c(120, 255, 210), C3 = c(210, 130, 255), X = { "antlers", "ears_pointy", "stars" }, E = "glow", EyeColor = c(160, 255, 230),
		Mythic = { Wings = "butterfly", C1 = c(80, 140, 255), C2 = c(140, 255, 210), Glow = c(220, 140, 255), Halo = true, HaloColor = c(140, 255, 220), Orbit = true } },

	-- мифики яруса 3
	FrostGriffin = { A = "bird", C = c(230, 244, 255), C2 = c(120, 200, 255), C3 = c(60, 110, 200), X = { "beak", "crest_small", "tail_feathers" }, E = "glow", EyeColor = c(120, 220, 255),
		Mythic = { Wings = "angel", C1 = c(240, 250, 255), C2 = c(120, 210, 255), Crown = true, Glow = c(120, 220, 255) } },
	BlizzardLord = { A = "quad", C = c(150, 210, 255), C2 = c(240, 250, 255), C3 = c(40, 80, 170), X = { "ears_pointy", "crystals", "fangs" }, E = "glow", EyeColor = c(200, 250, 255),
		Mythic = { Wings = "crystal", Horns = "straight", HornColor = c(200, 240, 255), Glow = c(130, 230, 255), Orbit = true, Smoke = c(220, 240, 255) } },

	-- ДРАКОНЬЕ ЯЙЦО (ярус 4)
	EmberPup = { A = "quad", C = c(70, 50, 52), C2 = c(255, 140, 50), X = { "ears_pointy", "tail_thin", "cracks_glow" }, Iris = c(255, 150, 40) },
	DrakeHatchling = { A = "quad", C = c(220, 70, 50), C2 = c(255, 210, 120), X = { "horns_small", "wings_bat", "tail_spikes" }, Iris = c(255, 210, 60) },
	LavaTurtle = { A = "quad", C = c(110, 160, 90), C2 = c(255, 150, 40), C3 = c(60, 40, 40), X = { "shell", "cracks_glow" } },
	FireFox = { A = "quad", C = c(255, 110, 30), C2 = c(255, 230, 120), X = { "ears_pointy_big", "tails_multi", "flame" }, E = "glow", EyeColor = c(255, 220, 80) },
	MagmaDragon = { A = "dino", C = c(180, 40, 30), C2 = c(255, 170, 40), X = { "horns", "wings_bat", "spikes_back", "cracks_glow" }, E = "glow", EyeColor = c(255, 230, 90) },
	ChaosDragon = { A = "dino", C = c(40, 20, 50), C2 = c(255, 60, 120), X = { "horns", "wings_bat", "spikes_back", "spots_glow", "glow" }, E = "glow", EyeColor = c(255, 80, 140), S = 1.1 },
	DragonEmperor = { A = "quad", C = c(170, 20, 30), C2 = c(255, 200, 60), C3 = c(40, 10, 20), X = { "ears_pointy", "spikes_back", "tail_spikes", "fangs" }, E = "glow", EyeColor = c(255, 220, 60),
		Mythic = { Wings = "demon", Horns = "curved", HornColor = c(255, 200, 60), Crown = true, Glow = c(255, 180, 40), Fire = c(255, 80, 20), Fire2 = c(255, 200, 60), Smoke = c(60, 20, 20) } },

	-- мифики яруса 4
	HellHound = { A = "quad", C = c(30, 24, 30), C2 = c(255, 90, 30), C3 = c(10, 8, 12), X = { "ears_pointy_big", "fangs", "cracks_glow", "tail_spikes" }, E = "glow", EyeColor = c(255, 120, 30),
		Mythic = { Horns = "curved", Fire = c(255, 70, 20), Fire2 = c(255, 180, 40), Glow = c(255, 110, 30), Smoke = c(40, 20, 20), FlameTail = true } },
	SolarDemon = { A = "quad", C = c(60, 20, 70), C2 = c(255, 200, 40), C3 = c(220, 40, 60), X = { "ears_pointy", "spots_glow" }, E = "glow", EyeColor = c(255, 230, 80),
		Mythic = { Wings = "butterfly", C1 = c(220, 40, 60), C2 = c(255, 160, 40), Glow = c(255, 220, 60), Horns = "curved", HornColor = c(255, 120, 40), Fire = c(255, 120, 30), Fire2 = c(255, 230, 90), Halo = true, HaloColor = c(255, 140, 40) } },

	-- КОСМИЧЕСКОЕ ЯЙЦО (ярус 5)
	StarBunny = { A = "quad", C = c(60, 50, 140), C2 = c(255, 230, 120), X = { "ears_long", "tail_puff", "stars", "cheeks" }, E = "glow", EyeColor = c(255, 240, 160) },
	CometCat = { A = "quad", C = c(110, 220, 255), C2 = c(255, 255, 255), C3 = c(60, 90, 200), X = { "ears_pointy", "flame", "stars" }, E = "glow", EyeColor = c(255, 255, 255) },
	NebulaPup = { A = "quad", C = c(200, 90, 220), C2 = c(110, 230, 255), X = { "ears_round_big", "tail_thin", "spots_glow", "tongue" }, Iris = c(110, 230, 255) },
	GalaxyOwl = { A = "bird", C = c(40, 30, 90), C2 = c(200, 120, 255), C3 = c(110, 240, 255), X = { "beak", "ear_tufts", "stars", "wings_feather" }, E = "glow", EyeColor = c(110, 240, 255) },
	MoonDragon = { A = "dino", C = c(220, 226, 240), C2 = c(160, 170, 255), X = { "horns", "wings_feather", "stars", "glow" }, E = "glow", EyeColor = c(180, 200, 255) },
	CosmicFox = { A = "quad", C = c(30, 20, 60), C2 = c(255, 120, 220), C3 = c(110, 240, 255), X = { "ears_pointy_big", "tails_multi", "stars", "rings" }, E = "glow", EyeColor = c(255, 140, 230), S = 1.1 },
	CosmicAngel = { A = "quad", C = c(250, 248, 255), C2 = c(120, 220, 255), C3 = c(255, 120, 220), X = { "ears_pointy", "stars" }, E = "glow", EyeColor = c(150, 230, 255),
		Mythic = { Wings = "angel", C1 = c(255, 255, 255), C2 = c(255, 130, 230), Halo = true, HaloColor = c(140, 230, 255), Glow = c(150, 220, 255), Orbit = true, Smoke = c(120, 100, 220) } },

	-- мифики яруса 5
	StarDevourer = { A = "orb", C = c(16, 10, 30), C2 = c(110, 240, 255), M2 = "Neon", X = { "rings", "stars", "tentacles" }, E = "glow", EyeColor = c(110, 240, 255),
		Mythic = { Body = "orb", Wings = "demon", C1 = c(20, 12, 40), Glow = c(110, 240, 255), Horns = "curved", HornColor = c(40, 30, 70), Smoke = c(40, 20, 90), Trim = false, Orbit = true } },
	TimeLord = { A = "quad", C = c(250, 246, 236), C2 = c(255, 210, 80), C3 = c(30, 26, 40), X = { "ears_pointy", "clock_face" }, E = "glow", EyeColor = c(255, 230, 120),
		Mythic = { Wings = "angel", C1 = c(30, 26, 40), C2 = c(255, 210, 80), Halo = true, Crown = true, Glow = c(255, 210, 80), Orbit = true } },

	-- «ОГРОМНЫЕ» (Huge): в 3 раза больше обычных; Mythic — крылья/рога/нимб, Huge — аура и особые детали
	HugeCloudCat = { A = "quad", C = c(255, 255, 255), C2 = c(255, 214, 236), C3 = c(214, 190, 255), X = { "ears_pointy", "tail_fluffy", "whiskers", "cheeks" }, Iris = c(110, 190, 255),
		Mythic = { Wings = "angel", C1 = c(255, 255, 255), C2 = c(255, 196, 232), Halo = true, HaloColor = c(255, 170, 225), Glow = c(255, 160, 220), Gem = false, Trim = false },
		Huge = { Cloud = true, Bow = c(255, 120, 190), Aura = c(255, 150, 220), Stars = true } },
	HugeAmberDragon = { A = "quad", C = c(255, 168, 40), C2 = c(255, 236, 170), C3 = c(210, 90, 20), X = { "horns", "spikes_back", "tail_spikes", "fangs", "cheeks" }, Iris = c(255, 120, 20),
		Mythic = { Wings = "flame", C1 = c(255, 110, 30), Glow = c(255, 190, 60), FlameTail = true, Fire = c(255, 130, 30), Fire2 = c(255, 230, 120), Gem = false, Trim = false },
		Huge = { Aura = c(255, 170, 40), Stars = true } },
	HugeFrostWolf = { A = "quad", C = c(220, 238, 255), C2 = c(255, 255, 255), C3 = c(70, 130, 220), X = { "ears_pointy_big", "tail_fluffy", "fangs", "nose" }, Iris = c(60, 170, 255),
		Mythic = { Wings = "angel", C1 = c(240, 250, 255), C2 = c(140, 210, 255), Glow = c(120, 220, 255), Smoke = c(230, 245, 255), Gem = false, Trim = false },
		Huge = { IceCrown = true, CrownColor = c(170, 235, 255), Aura = c(110, 210, 255), Stars = true } },
	HugeLavaPhoenix = { A = "bird", C = c(255, 96, 36), C2 = c(255, 214, 90), C3 = c(190, 30, 20), X = { "beak", "crest_long", "tail_feathers", "cheeks" }, Iris = c(255, 200, 40),
		Mythic = { Kind = "bird", Wings = "phoenix", Glow = c(255, 150, 40), Fire = c(255, 90, 30), Fire2 = c(255, 220, 80), Halo = true, HaloColor = c(255, 190, 60), FlameTail = true, Gem = false, Trim = false },
		Huge = { Aura = c(255, 110, 30), Stars = true } },
	HugeStarWhale = { A = "blob", C = c(56, 70, 170), C2 = c(180, 220, 255), C3 = c(120, 230, 255), X = { "tail_fluke", "flippers", "stars", "spots_glow", "cheeks" }, Iris = c(120, 220, 255), Fly = true, Box = { 2.8, 2.3, 3.2 },
		Mythic = { Kind = "blob", Glow = c(130, 220, 255), Gem = false, Trim = false },
		Huge = { Aura = c(120, 200, 255), Stars = true, Spout = c(140, 220, 255) } },
	HugeChronoDragon = { A = "quad", C = c(255, 214, 110), C2 = c(255, 250, 235), C3 = c(40, 34, 70), X = { "horns", "spikes_back", "tail_spikes", "cheeks" }, Iris = c(40, 200, 255),
		Mythic = { Wings = "royal", C1 = c(255, 255, 255), C2 = c(255, 200, 70), Glow = c(110, 240, 255), Crown = true, Gem = false, Trim = false },
		Huge = { Cape = c(110, 50, 190), Aura = c(110, 230, 255), Stars = true } },
	HugeRainbowUnicorn = { A = "quad", C = c(255, 255, 255), C2 = c(255, 226, 246), C3 = c(220, 200, 255), X = { "ears_pointy", "cheeks" }, Iris = c(200, 120, 255),
		Mythic = { Wings = "rainbow", Horns = "unicorn", HornColor = c(255, 236, 140), Halo = true, HaloColor = c(255, 240, 160), Glow = c(255, 170, 240), Gem = false, Trim = false },
		Huge = { Rainbow = true, Mane = true, RainbowTail = true, Aura = c(255, 170, 240), Stars = true } },
}
