-- Procedural keyframe animator for R15 rigs.
--
-- Each frame, after Roblox's own Animator has posed the character (walk,
-- idle...), we blend our keyframed pose on top by writing Motor6D.Transform
-- in RunService.Stepped. No uploaded animation assets are needed, so this
-- works in live servers immediately and every client sees the same moves.
--
-- Layers: tracks on the same layer replace each other. Layers are applied in
-- LAYER_ORDER, so "Action" (attacks) overrides "State" (block / stun).
--
-- Clips are authored for R15. R6 rigs get an automatic conversion (no
-- elbows/knees there, the rest maps onto the R6 joints). NPCs, which have no
-- default Animate script, get a procedural walk / idle cycle underneath.

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

local function cf6(rx, ry, rz, px, py, pz): CFrame
	return CFrame.new(px or 0, py or 0, pz or 0) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

-- R15 pose -> R6 joint CFrames. R6 joints use rotated C0 frames, so axes are
-- remapped per joint; waist rotation is folded into the root.
local function toR6(pose)
	local out = {}
	local function g(name)
		local e = pose[name]
		return (e and e[1] or 0), (e and e[2] or 0), (e and e[3] or 0)
	end
	local x, y, z = g("RightShoulder")
	out["Right Shoulder"] = cf6(-z, y, x)
	x, y, z = g("LeftShoulder")
	out["Left Shoulder"] = cf6(z, y, -x)
	x, y, z = g("RightHip")
	out["Right Hip"] = cf6(-z, y, x)
	x, y, z = g("LeftHip")
	out["Left Hip"] = cf6(z, y, -x)
	x, y, z = g("Neck")
	out["Neck"] = cf6(-x, z, y)
	local rx, ry, rz = g("Root")
	local wx, wy, wz = g("Waist")
	local root = pose.Root
	out["RootJoint"] = cf6(-(rx + wx), rz + wz, ry + wy, -(root and root[4] or 0), (root and root[6] or 0), (root and root[5] or 0))
	return out
end

local R6_JOINTS = { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck", "RootJoint" }

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
	local frames, framesR6 = {}, {}
	for i, key in clip.Keyframes do
		local cfs = {}
		for joint in joints do
			cfs[joint] = toCFrame(key.Pose[joint])
		end
		local style = EASING[key.Ease or "Quad"] or Enum.EasingStyle.Quad
		local direction = if key.In then Enum.EasingDirection.In else Enum.EasingDirection.Out
		frames[i] = { Time = key.Time, CFrames = cfs, Style = style, Direction = direction }
		framesR6[i] = { Time = key.Time, CFrames = toR6(key.Pose), Style = style, Direction = direction }
	end
	local jointsR6 = {}
	for _, name in R6_JOINTS do
		jointsR6[name] = true
	end
	clip.Joints = joints
	clip.Frames = frames
	clip.JointsR6 = jointsR6
	clip.FramesR6 = framesR6
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
	-- Classic rigs use Motor6D joints; rigs converted by Roblox's avatar joint
	-- upgrade use AnimationConstraint. Both expose the same Transform property.
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			if not motors[d.Name] or d:IsA("AnimationConstraint") then
				motors[d.Name] = d
			end
		end
	end
	local rigType
	if motors.Waist then
		rigType = "R15"
	elseif motors.RootJoint and motors["Right Shoulder"] then
		rigType = "R6"
	else
		return nil
	end
	rig = { Motors = motors, Layers = {}, Type = rigType, Phase = 0 }
	rigs[character] = rig
	return rig
end

local function sample(frames, t: number, joint: string): CFrame
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

-- Procedural walk / run / idle for rigs without an Animate script (NPCs).
function Animator.EnableLocomotion(character: Model)
	local rig = getRig(character)
	if rig and rig.Type == "R15" then
		rig.Locomotion = character:FindFirstChild("HumanoidRootPart")
	end
end

local function locomotion(rig, dt: number)
	local root = rig.Locomotion :: BasePart?
	if not root or not root.Parent then
		return
	end
	local m = rig.Motors
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = math.clamp(speed / 14, 0, 1.3)
	rig.Phase += dt * (4 + speed * 0.45)
	local s = math.sin(rig.Phase)
	local c = math.cos(rig.Phase)
	local breath = math.sin(os.clock() * 2) * (1 - math.min(moving, 1))
	local swing = 38 * moving
	local function set(name, cf)
		local motor = m[name]
		if motor then
			motor.Transform = cf
		end
	end
	set("Root", cf6(0, 0, 0, 0, math.abs(c) * 0.25 * moving + breath * 0.04, 0))
	set("Waist", cf6(-8 * moving + breath * 2, s * 8 * moving, 0))
	set("Neck", cf6(4 * moving, -s * 6 * moving, 0))
	set("RightHip", cf6(-s * swing, 0, 0))
	set("LeftHip", cf6(s * swing, 0, 0))
	set("RightKnee", cf6(-math.max(0, c) * 50 * moving, 0, 0))
	set("LeftKnee", cf6(-math.max(0, -c) * 50 * moving, 0, 0))
	set("RightShoulder", cf6(s * swing * 0.9 + 8, 0, 6 + breath * 2))
	set("LeftShoulder", cf6(-s * swing * 0.9 + 8, 0, -6 - breath * 2))
	set("RightElbow", cf6(20 + 25 * moving, 0, 0))
	set("LeftElbow", cf6(20 + 25 * moving, 0, 0))
end

local lastStep = os.clock()
RunService.Stepped:Connect(function()
	local now = os.clock()
	local dt = math.min(0.1, now - lastStep)
	lastStep = now
	for character, rig in rigs do
		if not character.Parent then
			rigs[character] = nil
			continue
		end
		if rig.Locomotion then
			locomotion(rig, dt)
		end
		for _, layer in LAYER_ORDER do
			local track = rig.Layers[layer]
			if track then
				local weight, t = evaluate(track, now)
				if not weight then
					rig.Layers[layer] = nil
				elseif weight > 0 then
					local isR6 = rig.Type == "R6"
					local frames = if isR6 then track.Clip.FramesR6 else track.Clip.Frames
					for joint in (if isR6 then track.Clip.JointsR6 else track.Clip.Joints) do
						local motor = rig.Motors[joint]
						if motor then
							motor.Transform = motor.Transform:Lerp(sample(frames, t, joint), weight)
						end
					end
				end
			end
		end
	end
end)

return Animator
