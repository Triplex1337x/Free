-- Minimal Roblox API mock for rendering GUI code outside Roblox (runs in fengari / Lua 5.3).
local R = {}
SRC_ROOT = SRC_ROOT or "."

-- compat -----------------------------------------------------------------------------------
unpack = table.unpack
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
math.pow = math.pow or function(a, b) return a ^ b end
math.log10 = math.log10 or function(x) return math.log(x, 10) end
function math.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
function math.round(x) return math.floor(x + 0.5) end
function math.sign(x) return x > 0 and 1 or (x < 0 and -1 or 0) end
function math.noise() return 0 end
function table.find(t, v) for i, x in ipairs(t) do if x == v then return i end end end
function table.clear(t) for k in pairs(t) do t[k] = nil end end
function table.create(n, v) local t = {} for i = 1, n do t[i] = v end return t end
function table.freeze(t) return t end
function table.clone(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
function string.split(s, sep)
	sep = sep or ","
	local out, i = {}, 1
	while true do
		local a, b = string.find(s, sep, i, true)
		if not a then table.insert(out, string.sub(s, i)) break end
		table.insert(out, string.sub(s, i, a - 1))
		i = b + 1
	end
	return out
end
local rawtostring = tostring
function tostring(v)
	if math.type and math.type(v) == "float" and v == math.floor(v) and math.abs(v) < 1e15 then
		return string.format("%d", v)
	end
	return rawtostring(v)
end
local rawformat = string.format
string.format = function(fmt, ...)
	local args = table.pack(...)
	-- Luau tolerates %d with floats
	local i = 0
	for spec in string.gmatch(fmt, "%%[%-%+ #0]*%d*%.?%d*([%a%%])") do
		if spec ~= "%" then
			i = i + 1
			if (spec == "d" or spec == "i" or spec == "x" or spec == "X") and type(args[i]) == "number" then
				args[i] = math.floor(args[i] + (args[i] < 0 and 0 or 0))
			end
		end
	end
	return rawformat(fmt, table.unpack(args, 1, args.n))
end
function warn(...) print("[warn]", ...) end
function tick() return os.time() end
function time() return R.now end
function elapsedTime() return R.now end
R.now = 0
os.clock = function() return R.now end

-- typeof
local typeTags = setmetatable({}, { __mode = "k" })
function typeof(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt and mt.__type then return mt.__type end
		if typeTags[v] then return typeTags[v] end
	end
	return type(v)
end

-- datatypes --------------------------------------------------------------------------------
local function class(name)
	local mt = { __type = name }
	mt.__index = mt
	return mt
end

-- Vector2
local V2 = class("Vector2")
Vector2 = {}
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return Vector2.new(a * b.X, a * b.Y) end
	if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b) if type(b) == "number" then return Vector2.new(a.X / b, a.Y / b) end return Vector2.new(a.X / b.X, a.Y / b.Y) end
V2.__unm = function(a) return Vector2.new(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2) end
	if k == "Unit" then local m = math.sqrt(t.X ^ 2 + t.Y ^ 2) return m > 0 and Vector2.new(t.X / m, t.Y / m) or Vector2.new() end
	if k == "x" then return t.X end
	if k == "y" then return t.Y end
	return V2[k]
end
function V2:Lerp(b, a) return Vector2.new(self.X + (b.X - self.X) * a, self.Y + (b.Y - self.Y) * a) end
function V2:Dot(b) return self.X * b.X + self.Y * b.Y end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

-- Vector3
local V3 = class("Vector3")
Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end
	if k == "Unit" then local m = math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) return m > 0 and Vector3.new(t.X / m, t.Y / m, t.Z / m) or Vector3.new() end
	return V3[k]
end
function V3:Lerp(b, a) return self + (b - self) * a end
function V3:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
function V3:Cross(b) return Vector3.new(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X) end
Vector3.zero = Vector3.new()
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

-- CFrame: position + 3x3 rotation matrix (row-major r[1..9])
local CF = { __type = "CFrame" }
CFrame = {}
local function mk(px, py, pz, r)
	return setmetatable({ x = px, y = py, z = pz, r = r }, CF)
end
local ID = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mmul(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function mvec(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end
local function tr(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
local function rx(a) local c, s = math.cos(a), math.sin(a) return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(a) local c, s = math.cos(a), math.sin(a) return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(a) local c, s = math.cos(a), math.sin(a) return { c, -s, 0, s, c, 0, 0, 0, 1 } end
local function lookRot(dx, dy, dz, ux, uy, uz)
	-- z axis points backwards (away from target)
	local zl = math.sqrt(dx * dx + dy * dy + dz * dz)
	if zl < 1e-9 then return ID end
	local zx, zy, zz = -dx / zl, -dy / zl, -dz / zl
	ux, uy, uz = ux or 0, uy or 1, uz or 0
	local xx, xy, xz = uy * zz - uz * zy, uz * zx - ux * zz, ux * zy - uy * zx
	local xl = math.sqrt(xx * xx + xy * xy + xz * xz)
	if xl < 1e-6 then
		-- looking straight up/down: pick another up
		ux, uy, uz = 0, 0, 1
		xx, xy, xz = uy * zz - uz * zy, uz * zx - ux * zz, ux * zy - uy * zx
		xl = math.sqrt(xx * xx + xy * xy + xz * xz)
	end
	xx, xy, xz = xx / xl, xy / xl, xz / xl
	local yx, yy, yz = zy * xz - zz * xy, zz * xx - zx * xz, zx * xy - zy * xx
	return { xx, yx, zx, xy, yy, zy, xz, yz, zz }
end
CFrame.new = function(a, b, c, ...)
	if a == nil then return mk(0, 0, 0, ID) end
	if type(a) == "table" then
		if b then
			return mk(a.X, a.Y, a.Z, lookRot(b.X - a.X, b.Y - a.Y, b.Z - a.Z))
		end
		return mk(a.X, a.Y, a.Z, ID)
	end
	local rest = { ... }
	if #rest == 9 then return mk(a, b, c, rest) end
	if #rest == 4 then
		local qx, qy, qz, qw = rest[1], rest[2], rest[3], rest[4]
		return mk(a, b, c, {
			1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy) })
	end
	return mk(a, b or 0, c or 0, ID)
end
CFrame.lookAt = function(at, target, up)
	return mk(at.X, at.Y, at.Z, lookRot(target.X - at.X, target.Y - at.Y, target.Z - at.Z, up and up.X, up and up.Y, up and up.Z))
end
CFrame.Angles = function(a, b, c) return mk(0, 0, 0, mmul(mmul(rx(a or 0), ry(b or 0)), rz(c or 0))) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.fromEulerAnglesYXZ = function(a, b, c) return mk(0, 0, 0, mmul(mmul(ry(b or 0), rx(a or 0)), rz(c or 0))) end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
CFrame.fromAxisAngle = function(v, t)
	local m = math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2)
	local x, y, z = v.X / m, v.Y / m, v.Z / m
	local c, s = math.cos(t), math.sin(t)
	local C = 1 - c
	return mk(0, 0, 0, { c + x * x * C, x * y * C - z * s, x * z * C + y * s, y * x * C + z * s, c + y * y * C, y * z * C - x * s, z * x * C - y * s, z * y * C + x * s, c + z * z * C })
end
CFrame.fromMatrix = function(p, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return mk(p.X, p.Y, p.Z, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
CFrame.identity = mk(0, 0, 0, ID)
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		local x, y, z = mvec(a.r, b.X, b.Y, b.Z)
		return Vector3.new(x + a.x, y + a.y, z + a.z)
	end
	local x, y, z = mvec(a.r, b.x, b.y, b.z)
	return mk(x + a.x, y + a.y, z + a.z, mmul(a.r, b.r))
end
CF.__add = function(a, v) return mk(a.x + v.X, a.y + v.Y, a.z + v.Z, a.r) end
CF.__sub = function(a, v) return mk(a.x - v.X, a.y - v.Y, a.z - v.Z, a.r) end
CF.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
local cfm = {}
CF.__index = function(t, k)
	if cfm[k] then return cfm[k] end
	local r = t.r
	if k == "Position" or k == "p" then return Vector3.new(t.x, t.y, t.z) end
	if k == "X" then return t.x elseif k == "Y" then return t.y elseif k == "Z" then return t.z end
	if k == "LookVector" then return Vector3.new(-r[3], -r[6], -r[9]) end
	if k == "RightVector" or k == "XVector" then return Vector3.new(r[1], r[4], r[7]) end
	if k == "UpVector" or k == "YVector" then return Vector3.new(r[2], r[5], r[8]) end
	if k == "ZVector" then return Vector3.new(r[3], r[6], r[9]) end
	if k == "Rotation" then return mk(0, 0, 0, r) end
	return nil
end
function cfm.Inverse(a)
	local it = tr(a.r)
	local x, y, z = mvec(it, -a.x, -a.y, -a.z)
	return mk(x, y, z, it)
end
local function toQuat(r)
	local t = r[1] + r[5] + r[9]
	local w, x, y, z
	if t > 0 then
		local s = math.sqrt(t + 1) * 2
		w, x, y, z = s / 4, (r[8] - r[6]) / s, (r[3] - r[7]) / s, (r[4] - r[2]) / s
	elseif r[1] > r[5] and r[1] > r[9] then
		local s = math.sqrt(1 + r[1] - r[5] - r[9]) * 2
		w, x, y, z = (r[8] - r[6]) / s, s / 4, (r[2] + r[4]) / s, (r[3] + r[7]) / s
	elseif r[5] > r[9] then
		local s = math.sqrt(1 + r[5] - r[1] - r[9]) * 2
		w, x, y, z = (r[3] - r[7]) / s, (r[2] + r[4]) / s, s / 4, (r[6] + r[8]) / s
	else
		local s = math.sqrt(1 + r[9] - r[1] - r[5]) * 2
		w, x, y, z = (r[4] - r[2]) / s, (r[3] + r[7]) / s, (r[6] + r[8]) / s, s / 4
	end
	return x, y, z, w
end
function cfm.Lerp(a, b, t)
	local ax, ay, az, aw = toQuat(a.r)
	local bx, by, bz, bw = toQuat(b.r)
	local d = ax * bx + ay * by + az * bz + aw * bw
	if d < 0 then bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d end
	local qx, qy, qz, qw = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t, aw + (bw - aw) * t
	local m = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
	local c = CFrame.new(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, qx / m, qy / m, qz / m, qw / m)
	return c
end
function cfm.ToWorldSpace(a, b) return a * b end
function cfm.ToObjectSpace(a, b) return a:Inverse() * b end
function cfm.PointToWorldSpace(a, v) return a * v end
function cfm.PointToObjectSpace(a, v) return a:Inverse() * v end
function cfm.VectorToWorldSpace(a, v) local x, y, z = mvec(a.r, v.X, v.Y, v.Z) return Vector3.new(x, y, z) end
function cfm.VectorToObjectSpace(a, v) local x, y, z = mvec(tr(a.r), v.X, v.Y, v.Z) return Vector3.new(x, y, z) end
function cfm.ToEulerAnglesXYZ(a)
	local r = a.r
	return math.atan(-r[6], r[9]), math.asin(math.max(-1, math.min(1, r[3]))), math.atan(-r[2], r[1])
end
function cfm.ToEulerAnglesYXZ(a)
	local r = a.r
	return math.asin(math.max(-1, math.min(1, -r[6]))), math.atan(r[3], r[9]), math.atan(r[4], r[5])
end
cfm.ToOrientation = cfm.ToEulerAnglesYXZ
function cfm.ToAxisAngle(a) local x, y, z, w = toQuat(a.r) local s = math.sqrt(1 - w * w) if s < 1e-6 then return Vector3.new(1, 0, 0), 0 end return Vector3.new(x / s, y / s, z / s), 2 * math.acos(w) end
function cfm.GetComponents(a) local r = a.r return a.x, a.y, a.z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end
cfm.components = cfm.GetComponents
function cfm.Orthonormalize(a) return a end
R.CFMT = CF

-- Color3
local C3 = class("Color3")
Color3 = {}
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return Color3.new(v, t, p) elseif i == 1 then return Color3.new(q, v, p) elseif i == 2 then return Color3.new(p, v, t)
	elseif i == 3 then return Color3.new(p, q, v) elseif i == 4 then return Color3.new(t, p, v) else return Color3.new(v, p, q) end
end
function Color3.fromHex(h)
	h = h:gsub("#", "")
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
function Color3.toHSV(c) return c:ToHSV() end
C3.__eq = function(a, b) return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6 end
function C3:Lerp(b, a) return Color3.new(self.R + (b.R - self.R) * a, self.G + (b.G - self.G) * a, self.B + (b.B - self.B) * a) end
function C3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, mx > 0 and d / mx or 0, mx
end
function C3:ToHex() return string.format("%02X%02X%02X", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5)) end

-- BrickColor
BrickColor = { new = function() return setmetatable({ Color = Color3.new(0.5, 0.5, 0.5), Name = "Medium stone grey" }, class("BrickColor")) end }
BrickColor.random = BrickColor.new
BrickColor.White = BrickColor.new
BrickColor.Black = BrickColor.new

-- UDim / UDim2
local UD = class("UDim")
UDim = {}
function UDim.new(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end
UD.__add = function(a, b) return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset) end
UD.__sub = function(a, b) return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset) end
local UD2 = class("UDim2")
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then return setmetatable({ X = xs, Y = xo }, UD2) end
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2)
end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
UD2.__add = function(a, b) return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
UD2.__sub = function(a, b) return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
UD2.__eq = function(a, b) return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset end
UD2.__index = function(t, k)
	if k == "Width" then return t.X end
	if k == "Height" then return t.Y end
	return UD2[k]
end
function UD2:Lerp(b, a)
	return UDim2.new(self.X.Scale + (b.X.Scale - self.X.Scale) * a, self.X.Offset + (b.X.Offset - self.X.Offset) * a,
		self.Y.Scale + (b.Y.Scale - self.Y.Scale) * a, self.Y.Offset + (b.Y.Offset - self.Y.Offset) * a)
end

-- Sequences
local CSK = class("ColorSequenceKeypoint")
ColorSequenceKeypoint = { new = function(t, c) return setmetatable({ Time = t, Value = c }, CSK) end }
local CS = class("ColorSequence")
ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and getmetatable(a) ~= C3 then return setmetatable({ Keypoints = a }, CS) end
		b = b or a
		return setmetatable({ Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) } }, CS)
	end,
}
local NSK = class("NumberSequenceKeypoint")
NumberSequenceKeypoint = { new = function(t, v, e) return setmetatable({ Time = t, Value = v, Envelope = e or 0 }, NSK) end }
local NS = class("NumberSequence")
NumberSequence = {
	new = function(a, b)
		if type(a) == "table" then return setmetatable({ Keypoints = a }, NS) end
		b = b or a
		return setmetatable({ Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) } }, NS)
	end,
}
NumberRange = { new = function(a, b) return setmetatable({ Min = a, Max = b or a }, class("NumberRange")) end }
Rect = { new = function(a, b, c, d) return setmetatable({ Min = Vector2.new(a, b), Max = Vector2.new(c, d) }, class("Rect")) end }
PhysicalProperties = { new = function() return {} end }
Region3 = { new = function() return {} end }
Ray = { new = function(o, d) return { Origin = o, Direction = d } end }
local function bag(name) return { new = function() return setmetatable({}, { __type = name }) end } end
RaycastParams = bag("RaycastParams")
OverlapParams = bag("OverlapParams")
DateTime = { now = function() return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000, FormatUniversalTime = function() return "" end, ToUniversalTime = function() return { Year = 2026, Month = 1, Day = 1, Hour = 0, Minute = 0, Second = 0 } end } end }
DateTime.fromUnixTimestamp = DateTime.now
Font = { new = function(family, weight, style) return setmetatable({ Family = family, Weight = weight, Style = style }, class("Font")) end }
Font.fromEnum = function(e) return Font.new("enum:" .. tostring(e and e.Name), nil) end
Font.fromName = function(n, w) return Font.new(n, w) end
Content = { fromObject = function(o) return { Object = o } end, fromUri = function(u) return { Uri = u } end }
Random = {
	new = function(seed)
		local s = seed or 1
		local r = {}
		local function nx() s = (s * 1103515245 + 12345) % 2147483648 return s / 2147483648 end
		function r:NextNumber(a, b) a = a or 0 b = b or 1 return a + (b - a) * nx() end
		function r:NextInteger(a, b) return math.floor(a + (b - a + 1) * nx()) end
		return r
	end,
}
local rawrandom = math.random
math.randomseed(7)

-- TweenInfo
TweenInfo = {
	new = function(t, style, dir, rep, rev, delay)
		return setmetatable({ Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0 }, class("TweenInfo"))
	end,
}

-- Enum: any Enum.X.Y works
local enumItems = {}
local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = EnumItemMT
EnumItemMT.__tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end
local enumVals = 0
Enum = setmetatable({}, {
	__index = function(_, typ)
		local t = setmetatable({}, {
			__index = function(tt, name)
				enumVals = enumVals + 1
				local it = setmetatable({ Name = name, EnumType = typ, Value = enumVals }, EnumItemMT)
				rawset(tt, name, it)
				return it
			end,
		})
		t.GetEnumItems = function() return {} end
		rawset(Enum, typ, t)
		return t
	end,
})

-- Signals ----------------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
Signal.__type = "RBXScriptSignal"
function Signal.new() return setmetatable({ handlers = {} }, Signal) end
function Signal:Connect(fn)
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	local conn = setmetatable({ Connected = true }, { __type = "RBXScriptConnection" })
	function conn.Disconnect() h.connected = false conn.Connected = false end
	conn.disconnect = conn.Disconnect
	return conn
end
Signal.connect = Signal.Connect
function Signal:Once(fn)
	local c
	c = self:Connect(function(...) c:Disconnect() fn(...) end)
	return c
end
function Signal:Fire(...)
	local snap, live = {}, {}
	for _, h in ipairs(self.handlers) do
		if h.connected then table.insert(snap, h) table.insert(live, h) end
	end
	self.handlers = live
	for _, h in ipairs(snap) do
		if h.connected then
			local ok, err = pcall(h.fn, ...)
			if not ok then print("[signal error]", err) end
		end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	local c
	c = self:Connect(function(...) c:Disconnect() R.resume(co, ...) end)
	return coroutine.yield()
end
R.Signal = Signal

-- scheduler --------------------------------------------------------------------------------
local queue = {}
function R.resume(co, ...)
	if coroutine.status(co) ~= "suspended" then return end
	local ok, err = coroutine.resume(co, ...)
	if not ok then print("[task error]", err, debug and debug.traceback and debug.traceback(co) or "") end
end
local function schedule(at, co, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end
task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	R.resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	schedule(R.now, co, ...)
	return co
end
function task.delay(t, f, ...)
	local co = coroutine.create(f)
	schedule(R.now + (t or 0), co, ...)
	return co
end
function task.wait(t)
	local co, main = coroutine.running()
	if main or not co then return t or 0 end
	schedule(R.now + (t or 1 / 60), co, t or 1 / 60)
	return coroutine.yield()
end
function task.cancel(co) for _, q in ipairs(queue) do if q.co == co then q.dead = true end end end
function task.synchronize() end
function task.desynchronize() end
wait = task.wait
spawn = function(f) return task.defer(f) end
delay = task.delay

-- Instances --------------------------------------------------------------------------------
local Instance_ = {}
R.instances = {}
local DEFAULTS = {
	GuiObject = {
		BackgroundColor3 = Color3.fromRGB(163, 162, 165), BackgroundTransparency = 0, BorderSizePixel = 1, Size = UDim2.new(0, 100, 0, 100),
		Position = UDim2.new(), AnchorPoint = Vector2.new(), Visible = true, ZIndex = 1, Rotation = 0, LayoutOrder = 0, ClipsDescendants = false,
		Active = false, Transparency = 0, AutomaticSize = nil,
	},
	Text = { Text = "Label", TextColor3 = Color3.new(0, 0, 0), TextSize = 14, TextScaled = false, TextWrapped = false, TextTransparency = 0,
		TextXAlignment = nil, TextYAlignment = nil, Font = nil, RichText = false, TextStrokeTransparency = 1, TextStrokeColor3 = Color3.new(0, 0, 0), LineHeight = 1 },
	Image = { Image = "", ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0, ImageRectOffset = Vector2.new(), ImageRectSize = Vector2.new(), ScaleType = nil, SliceCenter = nil },
}
local GUI = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, ViewportFrame = true, CanvasGroup = true, VideoFrame = true }
local ISA = {
	GuiObject = GUI, GuiButton = { TextButton = true, ImageButton = true }, GuiBase2d = GUI, LayerCollector = { ScreenGui = true, BillboardGui = true, SurfaceGui = true },
	BasePart = { Part = true, MeshPart = true, WedgePart = true, UnionOperation = true, TrussPart = true, CornerWedgePart = true, Seat = true, SpawnLocation = true },
	UIGridStyleLayout = { UIListLayout = true, UIGridLayout = true }, Light = { PointLight = true, SpotLight = true, SurfaceLight = true },
	ValueBase = { StringValue = true, NumberValue = true, IntValue = true, BoolValue = true, ObjectValue = true, Color3Value = true },
	LuaSourceContainer = { ModuleScript = true, Script = true, LocalScript = true }, PVInstance = { Model = true, Part = true, MeshPart = true },
	PostEffect = { BlurEffect = true, BloomEffect = true, ColorCorrectionEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true },
	Constraint = { WeldConstraint = true, Weld = true, Motor6D = true, AlignPosition = true, AlignOrientation = true }, JointInstance = { Weld = true, Motor6D = true },
}
local EVENTS = {
	MouseEnter = 1, MouseLeave = 1, MouseButton1Down = 1, MouseButton1Up = 1, MouseButton1Click = 1, MouseButton2Click = 1, Activated = 1,
	InputBegan = 1, InputEnded = 1, InputChanged = 1, ChildAdded = 1, ChildRemoved = 1, DescendantAdded = 1, DescendantRemoving = 1, AncestryChanged = 1,
	Changed = 1, Destroying = 1, Touched = 1, TouchEnded = 1, FocusLost = 1, Focused = 1, Completed = 1, Event = 1, OnClientEvent = 1, OnServerEvent = 1,
	Triggered = 1, PromptShown = 1, PromptHidden = 1, Died = 1, HealthChanged = 1, Running = 1, StateChanged = 1, MoveToFinished = 1, CharacterAdded = 1,
	CharacterRemoving = 1, PlayerAdded = 1, PlayerRemoving = 1, Played = 1, Ended = 1, Stopped = 1, DidLoop = 1, TriggerEnded = 1, Heartbeat = 1,
	RenderStepped = 1, Stepped = 1, PreRender = 1, PostSimulation = 1, PreSimulation = 1, MouseWheelForward = 1, MouseWheelBackward = 1, ReturnPressedFromOnScreenKeyboard = 1,
	PromptTriggered = 1, PromptButtonHoldBegan = 1, PromptButtonHoldEnded = 1, TouchTap = 1, TouchLongPress = 1, TouchStarted = 1, TouchMoved = 1, LastInputTypeChanged = 1, GamepadConnected = 1,
	GamepadDisconnected = 1, WindowFocused = 1, WindowFocusReleased = 1, Idled = 1, KeyframeReached = 1, Loaded = 1,
}
local InstMT = { __type = "Instance" }
local methods = {}
local function isa(self, cls)
	if self.ClassName == cls or cls == "Instance" then return true end
	local set = ISA[cls]
	return set ~= nil and set[self.ClassName] == true
end
InstMT.__index = function(self, k)
	local raw = rawget(self, "_p")
	local v = raw[k]
	if v ~= nil then return v end
	if methods[k] then return methods[k] end
	local child = rawget(self, "_named")[k]
	if child then return child end
	if EVENTS[k] then
		local s = Signal.new()
		raw[k] = s
		return s
	end
	local d = rawget(self, "_defaults")
	if d and d[k] ~= nil then return d[k] end
	if ISA.BasePart[raw.ClassName] then
		if k == "CFrame" then return CFrame.new() end
		if k == "Position" then local c = raw.CFrame return c and c.Position or Vector3.new() end
		if k == "Orientation" then local c = raw.CFrame or CFrame.new() local x, y, z = c:ToOrientation() return Vector3.new(math.deg(x), math.deg(y), math.deg(z)) end
		if k == "Rotation" then return Vector3.new() end
		if k == "Mass" then local sz = self.Size return sz.X * sz.Y * sz.Z end
	end
	if k == "AbsoluteSize" then return Vector2.new(1280, 720) end
	if k == "AbsolutePosition" then return Vector2.new(0, 0) end
	if k == "AbsoluteRotation" then return 0 end
	if k == "AbsoluteContentSize" then return Vector2.new(0, 0) end
	if k == "AbsoluteCanvasSize" or k == "AbsoluteWindowSize" then return Vector2.new(1280, 720) end
	if k == "TextBounds" then return Vector2.new(#tostring(raw.Text or "") * 9, 20) end
	if k == "Character" then return nil end
	return nil
end
InstMT.__newindex = function(self, k, v)
	local raw = rawget(self, "_p")
	if k == "Parent" then
		local old = raw.Parent
		if old == v then return end
		if old then
			local kids = rawget(old, "_kids")
			for i, c in ipairs(kids) do if c == self then table.remove(kids, i) break end end
			local named = rawget(old, "_named")
			if named[raw.Name] == self then named[raw.Name] = nil end
			old.ChildRemoved:Fire(self)
		end
		raw.Parent = v
		if v then
			table.insert(rawget(v, "_kids"), self)
			local named = rawget(v, "_named")
			if named[raw.Name] == nil then named[raw.Name] = self end
			v.ChildAdded:Fire(self)
			local a = v
			while a do
				local ps = rawget(a, "_p")
				if ps.DescendantAdded then ps.DescendantAdded:Fire(self) end
				a = ps.Parent
			end
		end
		self.AncestryChanged:Fire(self, v)
		return
	end
	if ISA.BasePart[raw.ClassName] then
		if k == "Position" then
			local c = raw.CFrame or CFrame.new()
			raw.CFrame = CFrame.new(v) * c.Rotation
			return
		elseif k == "Orientation" then
			local c = raw.CFrame or CFrame.new()
			raw.CFrame = CFrame.new(c.Position) * CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
			return
		end
	end
	if k == "Name" and raw.Parent then
		local named = rawget(raw.Parent, "_named")
		if named[raw.Name] == self then named[raw.Name] = nil end
		if named[v] == nil then named[v] = self end
	end
	local old = raw[k]
	raw[k] = v
	if old ~= v then
		local sigs = rawget(self, "_propsig")
		if sigs[k] then sigs[k]:Fire() end
		if raw.Changed then raw.Changed:Fire(k) end
	end
end
InstMT.__tostring = function(self) return rawget(self, "_p").Name end

local serial = 0
function R.newInstance(class, name)
	serial = serial + 1
	local defaults = {}
	if GUI[class] then
		for k, v in pairs(DEFAULTS.GuiObject) do defaults[k] = v end
		if class == "TextLabel" or class == "TextButton" or class == "TextBox" then for k, v in pairs(DEFAULTS.Text) do defaults[k] = v end end
		if class == "ImageLabel" or class == "ImageButton" then for k, v in pairs(DEFAULTS.Image) do defaults[k] = v end end
		if class == "TextButton" or class == "ImageButton" then defaults.AutoButtonColor = true end
		if class == "ScrollingFrame" then defaults.CanvasSize = UDim2.new() defaults.CanvasPosition = Vector2.new() end
	end
	if class == "UIStroke" then defaults.Thickness = 1 defaults.Color = Color3.new(0, 0, 0) defaults.Transparency = 0 defaults.Enabled = true end
	if class == "UICorner" then defaults.CornerRadius = UDim.new(0, 8) end
	if class == "UIScale" then defaults.Scale = 1 end
	if class == "UIGradient" then defaults.Rotation = 0 defaults.Enabled = true defaults.Offset = Vector2.new() defaults.Color = ColorSequence.new(Color3.new(1, 1, 1)) defaults.Transparency = NumberSequence.new(0) end
	if class == "UIListLayout" or class == "UIGridLayout" then defaults.Padding = UDim.new() defaults.FillDirection = Enum.FillDirection.Vertical defaults.SortOrder = Enum.SortOrder.Name defaults.HorizontalAlignment = Enum.HorizontalAlignment.Left defaults.VerticalAlignment = Enum.VerticalAlignment.Top end
	if class == "UIGridLayout" then defaults.CellSize = UDim2.new(0, 100, 0, 100) defaults.CellPadding = UDim2.new(0, 5, 0, 5) defaults.FillDirection = Enum.FillDirection.Horizontal defaults.FillDirectionMaxCells = 0 end
	if class == "UIPadding" then for _, s in ipairs({ "Left", "Right", "Top", "Bottom" }) do defaults["Padding" .. s] = UDim.new() end end
	if class == "ScreenGui" then defaults.Enabled = true defaults.DisplayOrder = 0 end
	if class == "Sound" then defaults.Volume = 0.5 defaults.IsPlaying = false defaults.TimeLength = 1 defaults.PlaybackSpeed = 1 end
	if class == "Humanoid" then defaults.Health = 100 defaults.MaxHealth = 100 defaults.WalkSpeed = 16 end
	if ISA.BasePart[class] then
		defaults.Size = Vector3.new(4, 1, 2)
		defaults.Color = Color3.fromRGB(163, 162, 165)
		defaults.Transparency = 0
		defaults.Reflectance = 0
		defaults.Material = Enum.Material.Plastic
		defaults.Shape = Enum.PartType.Block
		defaults.Anchored = false
		defaults.CastShadow = true
		defaults.AssemblyLinearVelocity = Vector3.new()
		defaults.AssemblyAngularVelocity = Vector3.new()
		defaults.Velocity = Vector3.new()
	end
	if class == "SpecialMesh" then defaults.Scale = Vector3.new(1, 1, 1) defaults.Offset = Vector3.new() end
	if class == "Camera" then defaults.CFrame = CFrame.new() defaults.FieldOfView = 70 defaults.ViewportSize = Vector2.new(1280, 720) end
	local self = setmetatable({ _p = { Name = name or class, ClassName = class }, _kids = {}, _named = {}, _attrs = {}, _attrsig = {}, _propsig = {}, _defaults = defaults, _serial = serial }, InstMT)
	table.insert(R.instances, self)
	return self
end
Instance = {
	new = function(class, parent)
		local i = R.newInstance(class)
		if parent then i.Parent = parent end
		return i
	end,
}
function methods.IsA(self, c) return isa(self, c) end
function methods.GetChildren(self) local t = {} for i, c in ipairs(rawget(self, "_kids")) do t[i] = c end return t end
function methods.GetDescendants(self)
	local out = {}
	local function rec(i) for _, c in ipairs(rawget(i, "_kids")) do table.insert(out, c) rec(c) end end
	rec(self)
	return out
end
function methods.FindFirstChild(self, n, recursive)
	for _, c in ipairs(rawget(self, "_kids")) do if c.Name == n then return c end end
	if recursive then for _, c in ipairs(rawget(self, "_kids")) do local f = c:FindFirstChild(n, true) if f then return f end end end
	return nil
end
function methods.WaitForChild(self, n)
	local c = self:FindFirstChild(n)
	if c then return c end
	-- auto-create folders for services that tests don't populate
	print("[WaitForChild missing]", self.Name, n)
	local f = Instance.new("Folder")
	f.Name = n
	f.Parent = self
	return f
end
function methods.FindFirstChildOfClass(self, cls) for _, c in ipairs(rawget(self, "_kids")) do if c.ClassName == cls then return c end end end
function methods.FindFirstChildWhichIsA(self, cls, rec)
	for _, c in ipairs(rawget(self, "_kids")) do if isa(c, cls) then return c end end
	if rec then for _, c in ipairs(rawget(self, "_kids")) do local f = c:FindFirstChildWhichIsA(cls, true) if f then return f end end end
end
function methods.FindFirstAncestor(self, n) local p = self.Parent while p do if p.Name == n then return p end p = p.Parent end end
function methods.FindFirstAncestorOfClass(self, c) local p = self.Parent while p do if p.ClassName == c then return p end p = p.Parent end end
function methods.FindFirstAncestorWhichIsA(self, c) local p = self.Parent while p do if isa(p, c) then return p end p = p.Parent end end
function methods.IsDescendantOf(self, a) local p = self.Parent while p do if p == a then return true end p = p.Parent end return false end
function methods.IsAncestorOf(self, d) return d:IsDescendantOf(self) end
function methods.Destroy(self)
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
	rawget(self, "_p").Destroying = rawget(self, "_p").Destroying
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function methods.ClearAllChildren(self) for _, c in ipairs(self:GetChildren()) do c:Destroy() end end
function methods.Clone(self)
	local c = R.newInstance(self.ClassName)
	for k, v in pairs(rawget(self, "_p")) do
		if k ~= "Parent" and getmetatable(v) ~= Signal then rawget(c, "_p")[k] = v end
	end
	for k, v in pairs(rawget(self, "_attrs")) do rawget(c, "_attrs")[k] = v end
	for _, ch in ipairs(rawget(self, "_kids")) do ch:Clone().Parent = c end
	return c
end
function methods.GetPropertyChangedSignal(self, p)
	local s = rawget(self, "_propsig")
	if not s[p] then s[p] = Signal.new() end
	return s[p]
end
function methods.GetAttribute(self, k) return rawget(self, "_attrs")[k] end
function methods.GetAttributes(self) return rawget(self, "_attrs") end
function methods.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
	local s = rawget(self, "_attrsig")[k]
	if s then s:Fire() end
end
function methods.GetAttributeChangedSignal(self, k)
	local s = rawget(self, "_attrsig")
	if not s[k] then s[k] = Signal.new() end
	return s[k]
end
function methods.GetFullName(self) local n = self.Name local p = self.Parent while p and p.Name ~= "game" do n = p.Name .. "." .. n p = p.Parent end return n end
local function parts(self)
	local out = {}
	if isa(self, "BasePart") then table.insert(out, self) end
	for _, d in ipairs(self:GetDescendants()) do if isa(d, "BasePart") then table.insert(out, d) end end
	return out
end
function methods.GetBoundingBox(self)
	local mn, mx
	for _, p in ipairs(parts(self)) do
		local c, sz = p.CFrame, p.Size
		for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz2 in ipairs({ -1, 1 }) do
			local w = c * Vector3.new(sx * sz.X / 2, sy * sz.Y / 2, sz2 * sz.Z / 2)
			if not mn then mn, mx = w, w else
				mn = Vector3.new(math.min(mn.X, w.X), math.min(mn.Y, w.Y), math.min(mn.Z, w.Z))
				mx = Vector3.new(math.max(mx.X, w.X), math.max(mx.Y, w.Y), math.max(mx.Z, w.Z))
			end
		end end end
	end
	if not mn then return CFrame.new(), Vector3.new() end
	return CFrame.new((mn + mx) / 2), mx - mn
end
function methods.GetExtentsSize(self) local _, s = self:GetBoundingBox() return s end
function methods.GetPivot(self)
	if isa(self, "BasePart") then return self.CFrame end
	local pp = rawget(self, "_p").PrimaryPart
	if pp then return pp.CFrame end
	local wp = rawget(self, "_p").WorldPivot
	if wp then return wp end
	local c = self:GetBoundingBox()
	return c
end
function methods.PivotTo(self, target)
	local pivot = self:GetPivot()
	local delta = target * pivot:Inverse()
	for _, p in ipairs(parts(self)) do p.CFrame = delta * p.CFrame end
	if not isa(self, "BasePart") and not rawget(self, "_p").PrimaryPart then rawget(self, "_p").WorldPivot = target end
end
function methods.SetPrimaryPartCFrame(self, cf) self:PivotTo(cf) end
function methods.GetPrimaryPartCFrame(self) return self:GetPivot() end
function methods.GetScale(self) return rawget(self, "_scale") or 1 end
function methods.ScaleTo(self, s)
	local k = s / self:GetScale()
	rawset(self, "_scale", s)
	local pivot = self:GetPivot()
	for _, p in ipairs(parts(self)) do
		local rel = pivot:Inverse() * p.CFrame
		p.CFrame = pivot * (CFrame.new(rel.Position * k) * rel.Rotation)
		p.Size = p.Size * k
	end
end
function methods.TranslateBy(self, v) self:PivotTo(self:GetPivot() + v) end
function methods.Play(self) rawget(self, "_p").IsPlaying = true end
function methods.Stop(self) rawget(self, "_p").IsPlaying = false end
function methods.Pause() end
function methods.Resume() end
function methods.Emit() end
function methods.Clear() end
function methods.TweenSize(self, s) self.Size = s return true end
function methods.TweenPosition(self, p) self.Position = p return true end
function methods.TweenSizeAndPosition(self, s, p) self.Size = s self.Position = p return true end
function methods.CaptureFocus() end
function methods.ReleaseFocus() end
function methods.Fire(self, ...) self.Event:Fire(...) end
function methods.FireServer() end
function methods.FireAllClients() end
function methods.FireClient() end
function methods.InvokeServer() return nil end
function methods.LoadAnimation(self) local t = R.newInstance("AnimationTrack") return t end
function methods.GetPlayingAnimationTracks() return {} end
function methods.MoveTo() end
function methods.ApplyImpulse() end
function methods.BreakJoints() end
function methods.GetMass() return 1 end
function methods.GetTouchingParts() return {} end
function methods.ChangeState() end
function methods.GetState() return Enum.HumanoidStateType.Running end
function methods.SetStateEnabled() end
function methods.UnequipTools() end
function methods.AddTag(self, a, b) local inst, t = self, a if b then inst, t = a, b end rawget(inst, "_attrs")["__tag_" .. t] = true end
function methods.HasTag(self, a, b) local inst, t = self, a if b then inst, t = a, b end return rawget(inst, "_attrs")["__tag_" .. t] == true end
function methods.RemoveTag(self, a, b) local inst, t = self, a if b then inst, t = a, b end rawget(inst, "_attrs")["__tag_" .. t] = nil end
function methods.ScreenPointToRay(self, x, y) return Ray.new(Vector3.new(), Vector3.new(0, 0, -1)) end
function methods.ViewportPointToRay(self, x, y) return Ray.new(Vector3.new(), Vector3.new(0, 0, -1)) end
function methods.WorldToViewportPoint(self, p) return Vector3.new(640, 360, 10), true end
function methods.WorldToScreenPoint(self, p) return Vector3.new(640, 360, 10), true end
function methods.Raycast() return nil end
function methods.GetPartBoundsInBox() return {} end
function methods.GetPartBoundsInRadius() return {} end
function methods.GetPartsInPart() return {} end
function methods.GetServerTimeNow() return R.now + 1e9 end
function methods.GetRankInGroup() return 0 end
function methods.IsInGroup() return false end
function methods.GetUserIdFromNameAsync() return 1 end
function methods.Kick() end
function methods.GetMouse(self) local m = R.newInstance("Mouse") rawget(m, "_p").Hit = CFrame.new() rawget(m, "_p").X = 0 rawget(m, "_p").Y = 0 return m end

-- game & services -------------------------------------------------------------------------
game = R.newInstance("DataModel", "game")
local services = {}
function methods.GetService(self, name)
	if services[name] then return services[name] end
	local s = R.newInstance(name, name)
	s.Parent = game
	services[name] = s
	return s
end
methods.FindService = methods.GetService
workspace = game:GetService("Workspace")
Workspace = workspace
local cam = Instance.new("Camera")
cam.Parent = workspace
rawget(workspace, "_p").CurrentCamera = cam
rawget(workspace, "_p").Gravity = 196.2
local terrain = Instance.new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
function methods.GetServerTimeNow() return 1e9 + R.now end

local Players = game:GetService("Players")
local lp = Instance.new("Player")
lp.Name = "Player1"
rawget(lp, "_p").UserId = 1
rawget(lp, "_p").DisplayName = "Player1"
lp.Parent = Players
rawget(Players, "_p").LocalPlayer = lp
local pg = Instance.new("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = lp
local ps = Instance.new("PlayerScripts")
ps.Name = "PlayerScripts"
ps.Parent = lp
function methods.GetPlayers(self) return { lp } end
function methods.GetPlayerFromCharacter() return nil end
function methods.GetPlayerByUserId() return lp end
function methods.GetUserThumbnailAsync() return "rbxassetid://0", true end
function methods.GetCoreGuiEnabled() return true end
function methods.SetCoreGuiEnabled() end
function methods.SetCore() end
function methods.GetCore() return nil end
function methods.Create(self, inst, info, goal)
	-- TweenService:Create — tweens jump to the goal when played (static screenshots)
	local tw = R.newInstance("Tween")
	rawget(tw, "_p").PlaybackState = Enum.PlaybackState.Begin
	function tw.Play()
		local delay_ = (info and info.DelayTime or 0) + (info and info.Time or 0)
		local reps = info and info.RepeatCount or 0
		if reps < 0 or (info and info.Reverses) then
			-- looping / yoyo tweens: leave start state (it is what the loop returns to)
			if not (info and info.Reverses) then for k, v in pairs(goal) do inst[k] = v end end
			return
		end
		for k, v in pairs(goal) do inst[k] = v end
		task.delay(delay_, function() tw.Completed:Fire(Enum.PlaybackState.Completed) end)
	end
	tw.Cancel = function() end
	tw.Pause = function() end
	tw.Destroy = function() end
	return tw
end
function methods.GetValue(self, a) return a end
function methods.IsKeyDown() return false end
function methods.IsMouseButtonPressed() return false end
function methods.GetMouseLocation() return Vector2.new(640, 360) end
function methods.GetLastInputType() return Enum.UserInputType.MouseMovement end
function methods.GetConnectedGamepads() return {} end
function methods.GetGamepadConnected() return false end
function methods.IsStudio() return true end
function methods.IsClient() return true end
function methods.IsServer() return false end
function methods.IsRunning() return true end
function methods.BindToRenderStep(self, name, prio, fn) self.RenderStepped:Connect(fn) end
function methods.UnbindFromRenderStep() end
function methods.PlayLocalSound() end
function methods.PreloadAsync() end
function methods.GetProductInfo() return { PriceInRobux = 0, Name = "" } end
function methods.UserOwnsGamePassAsync() return false end
function methods.PromptGamePassPurchase() end
function methods.PromptProductPurchase() end
function methods.GenerateGUID() serial = serial + 1 return "guid-" .. serial end
function methods.JSONEncode() return "{}" end
function methods.JSONDecode() return {} end
function methods.GetTagged() return {} end
function methods.GetInstanceAddedSignal() return Signal.new() end
function methods.GetInstanceRemovedSignal() return Signal.new() end
function methods.CreateEditableImage() return nil end
function methods.GetTextSize(self, text, size) return Vector2.new(#text * size * 0.55, size) end
function methods.GetTextBoundsAsync() return Vector2.new(100, 20) end
function methods.GetFriendsOnline() return {} end
function methods.GetAsync() return nil end
function methods.SetAsync() end
function methods.UpdateAsync() end
function methods.GetDataStore() return R.newInstance("DataStore") end
function methods.GetOrderedDataStore() return R.newInstance("DataStore") end

local UIS = game:GetService("UserInputService")
rawget(UIS, "_p").TouchEnabled = false
rawget(UIS, "_p").KeyboardEnabled = true
rawget(UIS, "_p").MouseEnabled = true
rawget(UIS, "_p").GamepadEnabled = false
rawget(UIS, "_p").MouseBehavior = Enum.MouseBehavior.Default
game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
rawget(Lighting, "_p").ClockTime = 14
rawget(Lighting, "_p").ExposureCompensation = 0
R.services = services

-- module loading ---------------------------------------------------------------------------
local cache = {}
local rawrequire = require
function R.mountTree(parent, dir, rel)
	-- mirror a src/ directory into Instances (folders + scripts)
	for _, e in ipairs(R.listdir(dir)) do
		local full = dir .. "/" .. e.name
		if e.dir then
			local f = parent:FindFirstChild(e.name) or Instance.new("Folder")
			f.Name = e.name
			f.Parent = parent
			R.mountTree(f, full)
		elseif e.name:match("%.lua$") then
			local cls, name = "ModuleScript", e.name:gsub("%.lua$", "")
			if e.name:match("%.server%.lua$") then cls, name = "Script", e.name:gsub("%.server%.lua$", "") end
			if e.name:match("%.client%.lua$") then cls, name = "LocalScript", e.name:gsub("%.client%.lua$", "") end
			local s = Instance.new(cls)
			s.Name = name
			rawset(s, "_path", full)
			s.Parent = parent
		end
	end
end
function require(m)
	if type(m) == "string" then return rawrequire(m) end
	if cache[m] ~= nil then return cache[m] end
	local path = rawget(m, "_path")
	if not path then error("require of non-module " .. tostring(m)) end
	local env = setmetatable({ script = m }, { __index = _G, __newindex = _G })
	local chunk, err = loadfile(path, "t", env)
	if not chunk then error(err) end
	local res = chunk()
	cache[m] = res
	return res
end

-- simulation -------------------------------------------------------------------------------
function R.step(dt)
	R.now = R.now + dt
	local rs = game:GetService("RunService")
	local p = rawget(rs, "_p")
	if p.RenderStepped then p.RenderStepped:Fire(dt) end
	if p.Heartbeat then p.Heartbeat:Fire(dt) end
	if p.PreRender then p.PreRender:Fire(dt) end
	if p.Stepped then p.Stepped:Fire(R.now, dt) end
	local ready = {}
	local rest = {}
	for _, q in ipairs(queue) do
		if not q.dead then
			if q.at <= R.now then table.insert(ready, q) else table.insert(rest, q) end
		end
	end
	queue = rest
	table.sort(ready, function(a, b) return a.at < b.at end)
	for _, q in ipairs(ready) do R.resume(q.co, table.unpack(q.args, 1, q.args.n)) end
end
function R.run(seconds, dt)
	dt = dt or 1 / 30
	local n = math.floor(seconds / dt + 0.5)
	for _ = 1, n do R.step(dt) end
end

-- serialize GUI tree to JSON ---------------------------------------------------------------
local function jstr(s)
	return '"' .. tostring(s):gsub('[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end
local function enc(v)
	local t = typeof(v)
	if v == nil then return "null"
	elseif t == "number" then if v ~= v or v == math.huge or v == -math.huge then return "0" end return rawformat("%.6g", v)
	elseif t == "boolean" then return tostring(v)
	elseif t == "string" then return jstr(v)
	elseif t == "Color3" then return rawformat("[%.4f,%.4f,%.4f]", v.R, v.G, v.B)
	elseif t == "UDim" then return rawformat('{"s":%.6g,"o":%.6g}', v.Scale, v.Offset)
	elseif t == "UDim2" then return rawformat('{"xs":%.6g,"xo":%.6g,"ys":%.6g,"yo":%.6g}', v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	elseif t == "Vector2" then return rawformat("[%.6g,%.6g]", v.X, v.Y)
	elseif t == "EnumItem" then return jstr(v.Name)
	elseif t == "ColorSequence" then
		local parts = {}
		for _, k in ipairs(v.Keypoints) do table.insert(parts, rawformat("[%.4f,%.4f,%.4f,%.4f]", k.Time, k.Value.R, k.Value.G, k.Value.B)) end
		return "[" .. table.concat(parts, ",") .. "]"
	elseif t == "NumberSequence" then
		local parts = {}
		for _, k in ipairs(v.Keypoints) do table.insert(parts, rawformat("[%.4f,%.4f]", k.Time, k.Value)) end
		return "[" .. table.concat(parts, ",") .. "]"
	elseif t == "Font" then return jstr((v.Family or "") .. "|" .. tostring(v.Weight and v.Weight.Name or ""))
	end
	return "null"
end
local KEEP = {
	"Name", "ClassName", "Size", "Position", "AnchorPoint", "Visible", "ZIndex", "Rotation", "LayoutOrder", "ClipsDescendants", "BackgroundColor3",
	"BackgroundTransparency", "Text", "TextColor3", "TextSize", "TextScaled", "TextWrapped", "TextTransparency", "TextXAlignment", "TextYAlignment",
	"Font", "FontFace", "RichText", "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize", "ScaleType", "Thickness", "Color",
	"Transparency", "ApplyStrokeMode", "CornerRadius", "Scale", "Rotation", "Offset", "Enabled", "Padding", "FillDirection", "SortOrder",
	"HorizontalAlignment", "VerticalAlignment", "CellSize", "CellPadding", "FillDirectionMaxCells", "PaddingLeft", "PaddingRight", "PaddingTop",
	"PaddingBottom", "MaxTextSize", "MinTextSize", "AutomaticSize", "CanvasSize", "DisplayOrder", "TextStrokeTransparency", "TextStrokeColor3",
	"LineHeight", "AspectRatio", "MaxSize", "MinSize", "HorizontalFlex", "VerticalFlex", "Wraps", "ItemLineAlignment", "SliceCenter", "GroupTransparency",
}
function R.serialize(inst)
	local parts = {}
	for _, k in ipairs(KEEP) do
		local v = inst[k]
		if v ~= nil and type(v) ~= "function" and getmetatable(v) ~= InstMT then
			local e = enc(v)
			if e ~= "null" then table.insert(parts, jstr(k) .. ":" .. e) end
		end
	end
	local kids = {}
	for _, c in ipairs(rawget(inst, "_kids")) do table.insert(kids, R.serialize(c)) end
	if rawget(inst, "_p").ClassName == "ViewportFrame" then
		local cam = inst.CurrentCamera
		if cam and cam.CFrame then
			table.insert(parts, '"_vp":' .. R.serialize3d(inst))
			table.insert(parts, rawformat('"_cam":[%s],"_fov":%.3f', table.concat({ (function(...) local t = {} for i, v in ipairs({ ... }) do t[i] = rawformat("%.5f", v) end return table.unpack(t) end)(cam.CFrame:GetComponents()) }, ","), cam.FieldOfView or 70))
		end
	end
	table.insert(parts, '"_id":' .. rawget(inst, "_serial"))
	table.insert(parts, '"Children":[' .. table.concat(kids, ",") .. "]")
	return "{" .. table.concat(parts, ",") .. "}"
end
function R.serialize3d(model)
	local out = {}
	for _, p in ipairs(parts(model)) do
		local c, sz, col = p.CFrame, p.Size, p.Color
		local mesh = p:FindFirstChildOfClass("SpecialMesh")
		local light = p:FindFirstChildOfClass("PointLight")
		local mat = p.Material
		table.insert(out, rawformat('{"c":"%s","shape":"%s","s":[%.4f,%.4f,%.4f],"cf":[%s],"col":[%.4f,%.4f,%.4f],"mat":"%s","t":%.3f,"mesh":%s,"light":%s}',
			p.ClassName, p.Shape and p.Shape.Name or "Block", sz.X, sz.Y, sz.Z,
			table.concat({ (function(...) local t = {} for i, v in ipairs({ ... }) do t[i] = rawformat("%.5f", v) end return table.unpack(t) end)(c:GetComponents()) }, ","),
			col.R, col.G, col.B, mat and mat.Name or "Plastic", p.Transparency or 0,
			mesh and rawformat('{"type":"%s","scale":[%.4f,%.4f,%.4f]}', mesh.MeshType and mesh.MeshType.Name or "Brick", mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z) or "null",
			light and rawformat('{"col":[%.3f,%.3f,%.3f],"range":%.2f,"b":%.2f}', light.Color.R, light.Color.G, light.Color.B, light.Range or 8, light.Brightness or 1) or "null"))
	end
	return "[" .. table.concat(out, ",") .. "]"
end
R.InstMT = InstMT
return R
