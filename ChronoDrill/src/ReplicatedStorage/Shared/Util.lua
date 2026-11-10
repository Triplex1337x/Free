-- Util: форматирование чисел, интерполяция, взвешенный выбор и прочие мелочи.
local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s)
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

-- 1234567 -> "1.23M"
function Util.Format(n)
	n = tonumber(n) or 0
	if n ~= n then
		return "0"
	end
	local neg = n < 0
	if neg then
		n = -n
	end
	local out
	if n < 1000 then
		if n == math.floor(n) then
			out = tostring(math.floor(n))
		else
			out = trimZeros(string.format("%.1f", n))
		end
	else
		local i = 1
		while n >= 1000 and i < #SUFFIXES do
			n = n / 1000
			i = i + 1
		end
		local fmt
		if n < 10 then
			fmt = "%.2f"
		elseif n < 100 then
			fmt = "%.1f"
		else
			fmt = "%.0f"
		end
		out = trimZeros(string.format(fmt, n)) .. SUFFIXES[i]
	end
	if neg then
		out = "-" .. out
	end
	return out
end

-- 1234567 -> "1 234 567"
function Util.Commas(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(n))
	if #s > 15 then
		return Util.Format(n)
	end
	local out = string.reverse(string.gsub(string.reverse(s), "(%d%d%d)", "%1 "))
	out = string.gsub(out, "^ ", "")
	if n < 0 then
		out = "-" .. out
	end
	return out
end

function Util.Mult(n)
	return "x" .. Util.Format(n)
end

-- 3725 -> "1:02:05", 125 -> "2:05"
function Util.Time(sec)
	sec = math.max(0, math.floor(sec or 0))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Util.Lerp(a, b, t)
	return a + (b - a) * t
end

function Util.Clamp(x, a, b)
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

-- items = { {weight=..}, ... } или функция веса; rng = Random
function Util.WeightedPick(items, weightOf, rng)
	local total = 0
	for _, it in ipairs(items) do
		total = total + weightOf(it)
	end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	local acc = 0
	for _, it in ipairs(items) do
		acc = acc + weightOf(it)
		if roll <= acc then
			return it
		end
	end
	return items[#items]
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = Util.DeepCopy(v)
	end
	return out
end

-- Дописывает в data недостающие поля из template (для обновлений сохранений).
function Util.Reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = Util.DeepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			Util.Reconcile(data[k], v)
		end
	end
	return data
end

function Util.Color(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

function Util.Count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

return Util
