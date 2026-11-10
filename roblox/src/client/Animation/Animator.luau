-- Procedural keyframe animator for R15 rigs.
--
-- Each frame, after Roblox's own Animator has posed the character (walk,
-- idle...), we blend our keyframed pose on top by writing Motor6D.Transform
-- in RunService.Stepped. No uploaded animation assets are needed, so this
-- works in live servers immediately and every client sees the same moves.
--
-- Layers: tracks on the same layer replace each other. Layers are applied in
-- LAYER_ORDER, so "Action" (attacks) overrides "State" (block / stun).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Animator = {}

local LAYER_ORDER = { "State", "Action" }

type Track = {
	Clip: any,
	Start: number,
	Speed: number,
	Weight: number,
	StopAt: number?,
}

local rigs = setmetatable({}, { __mode = "k" }) :: { [Model]: any }

local EASING = {
	Linear = Enum.EasingStyle.Linear,
	Sine = Enum.EasingStyle.Sine,
	Quad = Enum.EasingStyle.Quad,
	Quart = Enum.EasingStyle.Quart,
	Expo = Enum.EasingStyle.Exponential,
	Back = Enum.EasingStyle.Back,
	Elastic = Enum.EasingStyle.Elastic,
}

local function toCFrame(entry): CFrame
	if not entry then
		return CFrame.identity
	end
	return CFrame.new(entry[4] or 0, entry[5] or 0, entry[6] or 0)
		* CFrame.Angles(math.rad(entry[1] or 0), math.rad(entry[2] or 0), math.rad(entry[3] or 0))
end

-- Turns an authored clip into per-joint CFrames once, then caches it.
local function prepare(clip)
	if clip.Prepared then
		return clip
	end
	local joints = {}
	for _, key in clip.Keyframes do
		for joint in key.Pose do
			joints[joint] = true
		end
	end
	local frames = {}
	for i, key in clip.Keyframes do
		local cfs = {}
		for joint in joints do
			cfs[joint] = toCFrame(key.Pose[joint])
		end
		frames[i] = {
			Time = key.Time,
			CFrames = cfs,
			Style = EASING[key.Ease or "Quad"] or Enum.EasingStyle.Quad,
			Direction = if key.In then Enum.EasingDirection.In else Enum.EasingDirection.Out,
		}
	end
	clip.Joints = joints
	clip.Frames = frames
	clip.Duration = clip.Duration or frames[#frames].Time
	clip.FadeIn = clip.FadeIn or 0.05
	clip.FadeOut = clip.FadeOut or 0.12
	clip.Prepared = true
	return clip
end

local function getRig(character: Model)
	local rig = rigs[character]
	if rig then
		return rig
	end
	local motors = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	if not motors.Waist then
		return nil -- not an R15 rig
	end
	rig = { Motors = motors, Layers = {} }
	rigs[character] = rig
	return rig
end

local function sample(clip, t: number, joint: string): CFrame
	local frames = clip.Frames
	if t <= frames[1].Time then
		return frames[1].CFrames[joint]
	end
	for i = 2, #frames do
		local b = frames[i]
		if t <= b.Time then
			local a = frames[i - 1]
			local span = b.Time - a.Time
			local alpha = if span > 0 then (t - a.Time) / span else 1
			alpha = TweenService:GetValue(alpha, b.Style, b.Direction)
			return a.CFrames[joint]:Lerp(b.CFrames[joint], alpha)
		end
	end
	return frames[#frames].CFrames[joint]
end

-- Returns the blend weight, or nil when the track is finished.
local function evaluate(track: Track, now: number)
	local clip = track.Clip
	local elapsed = now - track.Start
	local t = elapsed * track.Speed
	local weight = math.min(1, elapsed / clip.FadeIn)

	if clip.Loop then
		t %= clip.Duration
	elseif t >= clip.Duration then
		return nil
	else
		local remaining = clip.Duration - t
		if remaining < clip.FadeOut then
			weight *= remaining / clip.FadeOut
		end
	end

	if track.StopAt then
		local fade = 1 - (now - track.StopAt) / clip.FadeOut
		if fade <= 0 then
			return nil
		end
		weight *= fade
	end
	return weight * track.Weight, t
end

function Animator.Play(character: Model?, clip, options: { Speed: number?, Weight: number?, Layer: string? }?)
	if not character or not clip then
		return
	end
	local rig = getRig(character)
	if not rig then
		return
	end
	options = options or {}
	local layer = options.Layer or clip.Layer or "Action"
	rig.Layers[layer] = {
		Clip = prepare(clip),
		Start = os.clock(),
		Speed = options.Speed or 1,
		Weight = options.Weight or 1,
	}
end

-- Fades out whatever is playing on `layer` (only if it is `clip`, when given).
function Animator.Stop(character: Model?, layer: string, clip: any?)
	local rig = character and rigs[character]
	local track = rig and rig.Layers[layer]
	if track and not track.StopAt and (clip == nil or track.Clip == clip) then
		track.StopAt = os.clock()
	end
end

function Animator.IsPlaying(character: Model?, layer: string, clip: any?): boolean
	local rig = character and rigs[character]
	local track = rig and rig.Layers[layer]
	return track ~= nil and not track.StopAt and (clip == nil or track.Clip == clip)
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	for character, rig in rigs do
		if not character.Parent then
			rigs[character] = nil
			continue
		end
		for _, layer in LAYER_ORDER do
			local track = rig.Layers[layer]
			if track then
				local weight, t = evaluate(track, now)
				if not weight then
					rig.Layers[layer] = nil
				elseif weight > 0 then
					for joint in track.Clip.Joints do
						local motor = rig.Motors[joint]
						if motor then
							motor.Transform = motor.Transform:Lerp(sample(track.Clip, t, joint), weight)
						end
					end
				end
			end
		end
	end
end)

return Animator
