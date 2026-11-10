-- Custom VFX textures (PNG files in roblox/assets/textures, painted with
-- Figma AI and processed by tools/process_textures.py).
--
-- Upload each PNG to Roblox (Creator Hub -> Development Items -> Decals,
-- or Studio -> Asset Manager -> Bulk Import), copy the IMAGE asset id and
-- paste it below. 0 = not uploaded: the game falls back to Roblox's
-- built-in particle textures, so nothing breaks before you upload.
--
-- Tip: in Studio, inserting a Decal and pasting its id gives you a Texture
-- property like "rbxassetid://123". Use that number (the image id), not the
-- decal's catalogue id.

local Textures = {
	FlashStar = 0, -- flash_star.png       hit flashes, glitter
	FlashSoft = 0, -- flash_soft.png       soft glow
	ImpactBurst = 0, -- impact_burst.png   anime impact spikes
	Flame = 0, -- flame.png                flame tongues
	SmokePuff = 0, -- smoke_puff.png       smoke, dust, mist
	WaterSplash = 0, -- water_splash.png   Water element splashes
	WindSwirl = 0, -- wind_swirl.png       Wind element gusts
	Sunburst = 0, -- sunburst.png          Light element bursts
	EmberCluster = 0, -- ember_cluster.png awakening aura embers
	GroundCrack = 0, -- ground_crack.png   cracks left by heavy hits
	ShockwaveRing = 0, -- shockwave_ring.png  ground shockwaves
	SlashArc = 0, -- slash_arc.png         slash sprites (spare, for your own effects)
	SparkStreak = 0, -- spark_streak.png   velocity-stretched sparks
	LightningStrip = 0, -- lightning_strip.png  lightning beams
	EnergyOrb = 0, -- energy_orb.png       charge-up orbs
	Petal = 0, -- petal.png                falling petals on the map
}

-- Returns "rbxassetid://<id>" or nil when the texture isn't uploaded yet.
function Textures.Get(name: string): string?
	local id = Textures[name]
	if type(id) == "number" and id > 0 then
		return "rbxassetid://" .. id
	end
	return nil
end

return Textures
