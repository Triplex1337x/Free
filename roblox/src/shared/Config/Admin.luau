-- Who can open the admin panel.
--  * the experience owner (or rank >= GroupRank in the owning group) — automatically
--  * anyone listed in UserIds (put your Roblox UserId here to be sure)
--  * everyone while testing in Roblox Studio
-- Every command is re-checked on the server.

return {
	UserIds = {
		-- 123456789,
	},
	GroupRank = 254,
	AllowInStudio = true,
}
