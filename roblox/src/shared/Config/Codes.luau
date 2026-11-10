-- Promo codes. Keys are case-insensitive. `Expires` is a unix timestamp
-- (os.time()) or nil for no expiry. Release new codes on updates and
-- like/favourite milestones: it is one of the strongest retention levers.

return {
	RELEASE = { Spins = 5, Shards = 500 },
	RIFTOPEN = { Spins = 3 },
	THANKYOU1K = { Shards = 1000, Expires = nil },
}
