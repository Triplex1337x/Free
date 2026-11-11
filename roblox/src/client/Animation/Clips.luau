-- Hand-authored fighting animations for R15 rigs.
--
-- A pose maps a Motor6D name to { rotX, rotY, rotZ, posX, posY, posZ }
-- (degrees / studs, all optional). Conventions for these joints:
--   Shoulder  +X raises the arm forward, +Z raises the RIGHT arm out to the
--             side (use -Z for the left arm), +Y swings a forward arm left
--   Elbow     +X bends the forearm up          Knee  -X bends the shin back
--   Hip       +X kicks the leg forward          Waist -X leans forward, +Y twists left
--   Neck      -X looks down                     Root  moves / turns the whole body
-- Each keyframe eases INTO its pose with `Ease` (Expo for snappy hits, Back
-- for overshoot). Every clip ends close to neutral and fades out on top of
-- the default walk / idle animation, so movement keeps working.

local Clips = {}

local function merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		local pose = (select(i, ...))
		for joint, entry in pose do
			out[joint] = entry
		end
	end
	return out
end

local function key(time: number, pose, ease: string?)
	return { Time = time, Pose = pose, Ease = ease }
end

---------------------------------------------------------------------------
-- Base poses
---------------------------------------------------------------------------

local NEUTRAL = {}

local GUARD = {
	Waist = { 0, -12, 0 },
	Neck = { 0, 12, 0 },
	RightShoulder = { 55, 0, 14 },
	RightElbow = { 110, 0, 0 },
	LeftShoulder = { 70, 0, -14 },
	LeftElbow = { 115, 0, 0 },
}

local CROUCH = {
	Root = { 0, 0, 0, 0, -0.9, 0 },
	RightHip = { 45, 0, 6 },
	LeftHip = { 45, 0, -6 },
	RightKnee = { -75, 0, 0 },
	LeftKnee = { -75, 0, 0 },
	RightAnkle = { 30, 0, 0 },
	LeftAnkle = { 30, 0, 0 },
}

local STAND_LEGS = {
	Root = { 0, 0, 0 },
	RightHip = { 0, 0, 0 },
	LeftHip = { 0, 0, 0 },
	RightKnee = { 0, 0, 0 },
	LeftKnee = { 0, 0, 0 },
	RightAnkle = { 0, 0, 0 },
	LeftAnkle = { 0, 0, 0 },
}

---------------------------------------------------------------------------
-- M1 combo (4 hits)
---------------------------------------------------------------------------

-- 1: snapping right straight
Clips.M1 = {}
Clips.M1[1] = {
	Name = "M1_1",
	FadeIn = 0.03,
	FadeOut = 0.1,
	Keyframes = {
		key(0, GUARD),
		key(0.06, merge(GUARD, { Waist = { 0, -28, 0 }, RightShoulder = { 35, 0, 25 }, RightElbow = { 125, 0, 0 } }), "Quad"),
		key(0.12, {
			Root = { 0, 0, 0, 0, 0, -0.6 },
			Waist = { -6, 32, 0 },
			Neck = { 0, -24, 0 },
			RightShoulder = { 92, 8, 0 },
			RightElbow = { 4, 0, 0 },
			LeftShoulder = { 62, 0, -16 },
			LeftElbow = { 118, 0, 0 },
		}, "Expo"),
		key(0.22, {
			Root = { 0, 0, 0, 0, 0, -0.5 },
			Waist = { -4, 28, 0 },
			Neck = { 0, -20, 0 },
			RightShoulder = { 88, 6, 0 },
			RightElbow = { 10, 0, 0 },
			LeftShoulder = { 62, 0, -16 },
			LeftElbow = { 118, 0, 0 },
		}),
		key(0.36, GUARD, "Quad"),
	},
}

-- 2: left hook
Clips.M1[2] = {
	Name = "M1_2",
	FadeIn = 0.03,
	FadeOut = 0.1,
	Keyframes = {
		key(0, GUARD),
		key(0.07, merge(GUARD, { Waist = { 0, 30, 0 }, Neck = { 0, -10, 0 }, LeftShoulder = { 25, 0, -55 }, LeftElbow = { 100, 0, 0 } }), "Quad"),
		key(0.13, {
			Root = { 0, -10, 0, 0, 0, -0.4 },
			Waist = { -4, -40, 6 },
			Neck = { 0, 28, 0 },
			LeftShoulder = { 12, 0, -88 },
			LeftElbow = { 95, 0, 0 },
			RightShoulder = { 58, 0, 16 },
			RightElbow = { 115, 0, 0 },
		}, "Expo"),
		key(0.23, {
			Root = { 0, -8, 0, 0, 0, -0.3 },
			Waist = { -3, -36, 4 },
			Neck = { 0, 24, 0 },
			LeftShoulder = { 14, 0, -82 },
			LeftElbow = { 98, 0, 0 },
			RightShoulder = { 58, 0, 16 },
			RightElbow = { 115, 0, 0 },
		}),
		key(0.37, GUARD, "Quad"),
	},
}

-- 3: rising uppercut
Clips.M1[3] = {
	Name = "M1_3",
	FadeIn = 0.03,
	FadeOut = 0.12,
	Keyframes = {
		key(0, GUARD),
		key(0.08, merge(GUARD, CROUCH, { Root = { 0, 0, 0, 0, -0.6, 0 }, Waist = { -18, -22, 0 }, RightShoulder = { 5, 0, 18 }, RightElbow = { 115, 0, 0 } }), "Quad"),
		key(0.15, merge(STAND_LEGS, {
			Root = { 0, 0, 0, 0, 0.45, -0.4 },
			Waist = { 16, 22, 0 },
			Neck = { 22, -10, 0 },
			RightShoulder = { 165, 0, 8 },
			RightElbow = { 35, 0, 0 },
			LeftShoulder = { 40, 0, -25 },
			LeftElbow = { 100, 0, 0 },
			RightHip = { 0, 0, 0 },
			LeftHip = { 25, 0, 0 },
			LeftKnee = { -40, 0, 0 },
		}), "Expo"),
		key(0.26, merge(STAND_LEGS, {
			Root = { 0, 0, 0, 0, 0.35, -0.3 },
			Waist = { 12, 18, 0 },
			Neck = { 18, -8, 0 },
			RightShoulder = { 158, 0, 8 },
			RightElbow = { 40, 0, 0 },
			LeftShoulder = { 40, 0, -25 },
			LeftElbow = { 100, 0, 0 },
		})),
		key(0.42, merge(GUARD, STAND_LEGS), "Quad"),
	},
}

-- 4: spinning roundhouse finisher
Clips.M1[4] = {
	Name = "M1_4",
	FadeIn = 0.03,
	FadeOut = 0.15,
	Keyframes = {
		key(0, GUARD),
		key(0.09, merge(GUARD, {
			Root = { 0, 55, 0, 0, -0.3, 0 },
			Waist = { 0, -25, 0 },
			RightShoulder = { 20, 0, 70 },
			RightElbow = { 30, 0, 0 },
			LeftShoulder = { 20, 0, -70 },
			LeftElbow = { 30, 0, 0 },
			RightHip = { -20, 0, 0 },
			LeftKnee = { -25, 0, 0 },
		}), "Quad"),
		key(0.17, {
			Root = { 0, -75, -12, 0, 0.2, 0 },
			Waist = { 0, 35, 22 },
			Neck = { 0, 40, -10 },
			RightHip = { 88, 0, 50 },
			RightKnee = { -4, 0, 0 },
			RightAnkle = { -30, 0, 0 },
			LeftHip = { 10, 0, -8 },
			LeftKnee = { -22, 0, 0 },
			RightShoulder = { 30, 0, 95 },
			RightElbow = { 10, 0, 0 },
			LeftShoulder = { 40, 0, -60 },
			LeftElbow = { 60, 0, 0 },
		}, "Expo"),
		key(0.3, {
			Root = { 0, -70, -10, 0, 0.15, 0 },
			Waist = { 0, 30, 18 },
			Neck = { 0, 36, -8 },
			RightHip = { 80, 0, 46 },
			RightKnee = { -10, 0, 0 },
			LeftHip = { 10, 0, -8 },
			LeftKnee = { -22, 0, 0 },
			RightShoulder = { 30, 0, 90 },
			LeftShoulder = { 40, 0, -60 },
			LeftElbow = { 60, 0, 0 },
		}),
		key(0.5, merge(GUARD, STAND_LEGS), "Quad"),
	},
}

---------------------------------------------------------------------------
-- States (looping)
---------------------------------------------------------------------------

local BLOCK_POSE = {
	Root = { 0, 0, 0, 0, -0.35, 0 },
	Waist = { -12, 0, 0 },
	Neck = { -8, 0, 0 },
	RightShoulder = { 105, 38, 0 },
	RightElbow = { 75, 0, 0 },
	LeftShoulder = { 100, -38, 0 },
	LeftElbow = { 80, 0, 0 },
	RightHip = { 18, 0, 4 },
	LeftHip = { 18, 0, -4 },
	RightKnee = { -30, 0, 0 },
	LeftKnee = { -30, 0, 0 },
}

Clips.Block = {
	Name = "Block",
	Layer = "State",
	Loop = true,
	FadeIn = 0.06,
	FadeOut = 0.12,
	Duration = 1.2,
	Keyframes = {
		key(0, BLOCK_POSE),
		key(0.6, merge(BLOCK_POSE, { Root = { 0, 0, 0, 0, -0.42, 0 }, Neck = { -12, 0, 0 } }), "Sine"),
		key(1.2, BLOCK_POSE, "Sine"),
	},
}

local DIZZY = {
	Waist = { 12, 0, 6 },
	Neck = { -18, 0, 12 },
	RightShoulder = { -6, 0, 10 },
	LeftShoulder = { -6, 0, -10 },
	RightElbow = { 15, 0, 0 },
	LeftElbow = { 15, 0, 0 },
}

Clips.Stunned = {
	Name = "Stunned",
	Layer = "State",
	Loop = true,
	FadeIn = 0.08,
	FadeOut = 0.15,
	Duration = 1,
	Keyframes = {
		key(0, DIZZY),
		key(0.5, merge(DIZZY, { Waist = { 12, 0, -6 }, Neck = { -18, 0, -12 } }), "Sine"),
		key(1, DIZZY, "Sine"),
	},
}

---------------------------------------------------------------------------
-- Reactions
---------------------------------------------------------------------------

Clips.Hurt = {
	Name = "Hurt",
	FadeIn = 0.02,
	FadeOut = 0.15,
	Keyframes = {
		key(0, NEUTRAL),
		key(0.06, {
			Root = { 0, 0, 0, 0, 0, 0.45 },
			Waist = { 24, 0, 8 },
			Neck = { 26, 0, -6 },
			RightShoulder = { -25, 0, 40 },
			LeftShoulder = { -25, 0, -40 },
			RightElbow = { 30, 0, 0 },
			LeftElbow = { 30, 0, 0 },
		}, "Expo"),
		key(0.34, NEUTRAL, "Quad"),
	},
}

Clips.HurtHeavy = {
	Name = "HurtHeavy",
	FadeIn = 0.02,
	FadeOut = 0.2,
	Keyframes = {
		key(0, NEUTRAL),
		key(0.07, {
			Root = { 0, 0, 0, 0, 0, 0.8 },
			Waist = { 38, 0, -10 },
			Neck = { 35, 0, 8 },
			RightShoulder = { -40, 0, 70 },
			LeftShoulder = { -40, 0, -70 },
			RightElbow = { 10, 0, 0 },
			LeftElbow = { 10, 0, 0 },
			RightHip = { 30, 0, 0 },
			RightKnee = { -40, 0, 0 },
		}, "Expo"),
		key(0.55, NEUTRAL, "Quad"),
	},
}

Clips.Parry = {
	Name = "Parry",
	FadeIn = 0.02,
	FadeOut = 0.12,
	Keyframes = {
		key(0, BLOCK_POSE),
		key(0.08, {
			Waist = { 6, -20, 0 },
			RightShoulder = { 120, 0, 60 },
			RightElbow = { 20, 0, 0 },
			LeftShoulder = { 70, 0, -20 },
			LeftElbow = { 100, 0, 0 },
		}, "Back"),
		key(0.35, GUARD, "Quad"),
	},
}

-- Quick tucked flip for double / triple jumps.
Clips.AirFlip = {
	-- Root rotation advances < 180 degrees per key so CFrame interpolation
	-- always spins forward.
	Name = "AirFlip",
	FadeIn = 0.03,
	FadeOut = 0.1,
	Keyframes = {
		key(0, NEUTRAL),
		key(0.08, merge(CROUCH, { Root = { -110, 0, 0, 0, 0.4, 0 }, Waist = { -25, 0, 0 }, Neck = { -20, 0, 0 }, RightShoulder = { 60, 0, 30 }, LeftShoulder = { 60, 0, -30 }, RightElbow = { 100, 0, 0 }, LeftElbow = { 100, 0, 0 } }), "Linear"),
		key(0.17, merge(CROUCH, { Root = { -220, 0, 0, 0, 0.4, 0 }, Waist = { -25, 0, 0 }, RightShoulder = { 60, 0, 30 }, LeftShoulder = { 60, 0, -30 }, RightElbow = { 100, 0, 0 }, LeftElbow = { 100, 0, 0 } }), "Linear"),
		key(0.26, merge(CROUCH, { Root = { -330, 0, 0, 0, 0.2, 0 }, RightShoulder = { 40, 0, 50 }, LeftShoulder = { 40, 0, -50 } }), "Linear"),
		key(0.34, merge(STAND_LEGS, { Root = { 0, 0, 0 }, RightShoulder = { 20, 0, 60 }, LeftShoulder = { 20, 0, -60 } }), "Quad"),
	},
}

Clips.LevelUp = {
	Name = "LevelUp",
	FadeIn = 0.08,
	FadeOut = 0.25,
	Keyframes = {
		key(0, NEUTRAL),
		key(0.2, {
			Waist = { 10, 0, 0 },
			Neck = { 20, 0, 0 },
			RightShoulder = { 170, 0, 10 },
			RightElbow = { 30, 0, 0 },
			LeftShoulder = { 30, 0, -40 },
			LeftElbow = { 110, 0, 0 },
		}, "Back"),
		key(0.8, {
			Waist = { 8, 0, 0 },
			Neck = { 16, 0, 0 },
			RightShoulder = { 165, 0, 10 },
			RightElbow = { 30, 0, 0 },
			LeftShoulder = { 30, 0, -40 },
			LeftElbow = { 110, 0, 0 },
		}),
		key(1.1, NEUTRAL, "Quad"),
	},
}

---------------------------------------------------------------------------
-- Ability casts: built per windup so the strike lands exactly when the
-- server's hitbox does.
---------------------------------------------------------------------------

local castCache = {}

local function cached(name: string, windup: number, build)
	local id = ("%s_%.2f"):format(name, windup)
	local clip = castCache[id]
	if not clip then
		clip = build(math.max(windup, 0.06))
		clip.Name = id
		castCache[id] = clip
	end
	return clip
end

local Cast = {}

-- Twin palm strike.
function Cast.Melee(w: number)
	return {
		FadeIn = 0.04,
		FadeOut = 0.15,
		Keyframes = {
			key(0, GUARD),
			key(w * 0.85, merge(GUARD, {
				Root = { 0, 0, 0, 0, -0.3, 0.3 },
				Waist = { 0, -42, 0 },
				Neck = { 0, 30, 0 },
				RightShoulder = { 25, 0, 40 },
				RightElbow = { 105, 0, 0 },
				LeftShoulder = { 25, 0, -30 },
				LeftElbow = { 105, 0, 0 },
			}), "Quad"),
			key(w + 0.06, {
				Root = { 0, 0, 0, 0, -0.25, -1.1 },
				Waist = { -12, 22, 0 },
				Neck = { 0, -14, 0 },
				RightShoulder = { 96, 10, 0 },
				RightElbow = { 0, 0, 0 },
				LeftShoulder = { 94, -10, 0 },
				LeftElbow = { 2, 0, 0 },
				RightHip = { -20, 0, 0 },
				LeftHip = { 40, 0, 0 },
				LeftKnee = { -40, 0, 0 },
			}, "Expo"),
			key(w + 0.32, {
				Root = { 0, 0, 0, 0, -0.2, -0.9 },
				Waist = { -10, 18, 0 },
				RightShoulder = { 92, 8, 0 },
				LeftShoulder = { 90, -8, 0 },
				RightHip = { -18, 0, 0 },
				LeftHip = { 36, 0, 0 },
				LeftKnee = { -36, 0, 0 },
			}),
			key(w + 0.5, merge(GUARD, STAND_LEGS), "Quad"),
		},
	}
end

-- Sprinter's lean, arms swept back.
function Cast.Dash(w: number)
	local lean = {
		Root = { 0, 0, 0, 0, -0.7, 0 },
		Waist = { -42, 0, 0 },
		Neck = { 32, 0, 0 },
		RightShoulder = { -70, 0, 25 },
		LeftShoulder = { -70, 0, -25 },
		RightElbow = { 10, 0, 0 },
		LeftElbow = { 10, 0, 0 },
		RightHip = { -30, 0, 0 },
		LeftHip = { 55, 0, 0 },
		LeftKnee = { -70, 0, 0 },
		RightKnee = { -15, 0, 0 },
	}
	return {
		FadeIn = 0.03,
		FadeOut = 0.15,
		Keyframes = {
			key(0, NEUTRAL),
			key(w, lean, "Expo"),
			key(w + 0.3, lean),
			key(w + 0.5, NEUTRAL, "Quad"),
		},
	}
end

-- Gather energy low, then release with arms flung wide.
function Cast.AoE(w: number)
	return {
		FadeIn = 0.05,
		FadeOut = 0.18,
		Keyframes = {
			key(0, NEUTRAL),
			key(w * 0.9, merge(CROUCH, {
				Waist = { -28, 0, 0 },
				Neck = { -22, 0, 0 },
				RightShoulder = { 45, -32, 0 },
				LeftShoulder = { 45, 32, 0 },
				RightElbow = { 120, 0, 0 },
				LeftElbow = { 120, 0, 0 },
			}), "Quad"),
			key(w + 0.08, merge(STAND_LEGS, {
				Root = { 0, 0, 0, 0, 0.35, 0 },
				Waist = { 22, 0, 0 },
				Neck = { 28, 0, 0 },
				RightShoulder = { 30, 0, 125 },
				LeftShoulder = { 30, 0, -125 },
				RightElbow = { 5, 0, 0 },
				LeftElbow = { 5, 0, 0 },
				RightHip = { 0, 0, 18 },
				LeftHip = { 0, 0, -18 },
			}), "Back"),
			key(w + 0.4, merge(STAND_LEGS, {
				Root = { 0, 0, 0, 0, 0.2, 0 },
				Waist = { 16, 0, 0 },
				Neck = { 20, 0, 0 },
				RightShoulder = { 30, 0, 115 },
				LeftShoulder = { 30, 0, -115 },
				RightHip = { 0, 0, 14 },
				LeftHip = { 0, 0, -14 },
			})),
			key(w + 0.65, NEUTRAL, "Quad"),
		},
	}
end

-- Draw back and thrust a palm forward.
function Cast.Projectile(w: number)
	return {
		FadeIn = 0.04,
		FadeOut = 0.15,
		Keyframes = {
			key(0, GUARD),
			key(w, {
				Waist = { 0, -48, 0 },
				Neck = { 0, 42, 0 },
				RightShoulder = { -25, 0, 38 },
				RightElbow = { 115, 0, 0 },
				LeftShoulder = { 90, 32, 0 },
				LeftElbow = { 15, 0, 0 },
				Root = { 0, 0, 0, 0, -0.2, 0.3 },
			}, "Quad"),
			key(w + 0.06, {
				Root = { 0, 0, 0, 0, -0.2, -0.7 },
				Waist = { -6, 28, 0 },
				Neck = { 0, -20, 0 },
				RightShoulder = { 96, 0, 0 },
				RightElbow = { 0, 0, 0 },
				LeftShoulder = { 40, 0, -32 },
				LeftElbow = { 85, 0, 0 },
			}, "Expo"),
			key(w + 0.3, {
				Root = { 0, 0, 0, 0, -0.1, -0.5 },
				Waist = { -4, 24, 0 },
				RightShoulder = { 92, 0, 0 },
				RightElbow = { 4, 0, 0 },
				LeftShoulder = { 40, 0, -32 },
				LeftElbow = { 85, 0, 0 },
			}),
			key(w + 0.5, GUARD, "Quad"),
		},
	}
end

-- Ultimate: curl up, rise with arms to the sky, then unleash.
function Cast.Ultimate(w: number)
	return {
		FadeIn = 0.06,
		FadeOut = 0.25,
		Keyframes = {
			key(0, NEUTRAL),
			key(w * 0.45, merge(CROUCH, {
				Neck = { -38, 0, 0 },
				Waist = { -32, 0, 0 },
				RightShoulder = { 55, 40, 0 },
				LeftShoulder = { 55, -40, 0 },
				RightElbow = { 105, 0, 0 },
				LeftElbow = { 105, 0, 0 },
			}), "Quad"),
			key(w * 0.9, merge(STAND_LEGS, {
				Root = { 0, 0, 0, 0, 0.7, 0 },
				Waist = { 22, 0, 0 },
				Neck = { 32, 0, 0 },
				RightShoulder = { 168, 0, 26 },
				LeftShoulder = { 168, 0, -26 },
				RightElbow = { 8, 0, 0 },
				LeftElbow = { 8, 0, 0 },
				RightHip = { 0, 0, 12 },
				LeftHip = { 0, 0, -12 },
			}), "Back"),
			key(w + 0.12, {
				Root = { 0, 0, 0, 0, -0.5, -0.9 },
				Waist = { -24, 0, 0 },
				Neck = { 10, 0, 0 },
				RightShoulder = { 98, 6, 0 },
				LeftShoulder = { 98, -6, 0 },
				RightElbow = { 0, 0, 0 },
				LeftElbow = { 0, 0, 0 },
				RightHip = { -25, 0, 0 },
				LeftHip = { 50, 0, 0 },
				LeftKnee = { -55, 0, 0 },
			}, "Expo"),
			key(w + 0.6, {
				Root = { 0, 0, 0, 0, -0.45, -0.8 },
				Waist = { -20, 0, 0 },
				RightShoulder = { 94, 6, 0 },
				LeftShoulder = { 94, -6, 0 },
				RightHip = { -22, 0, 0 },
				LeftHip = { 46, 0, 0 },
				LeftKnee = { -50, 0, 0 },
			}),
			key(w + 0.95, NEUTRAL, "Quad"),
		},
	}
end

function Clips.Cast(kind: string?, windup: number, isUltimate: boolean)
	if isUltimate then
		return cached("Ult", windup, Cast.Ultimate)
	end
	local build = Cast[kind or ""] or Cast.Melee
	return cached(kind or "Melee", windup, build)
end

return Clips
