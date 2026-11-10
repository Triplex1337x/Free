-- LeaderboardService: глобальные таблицы лидеров на базе каждого яруса.
-- «Больше всего блоков», «Больше всего ребёрсов», «Больше всего яиц».
-- Данные — OrderedDataStore (работает в опубликованной игре или в Studio с доступом к API);
-- если хранилище недоступно, доски показывают игроков на сервере.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MK = require(ReplicatedStorage.Shared.ModelKit)
local Util = require(ReplicatedStorage.Shared.Util)

local Core = script.Parent.Parent.Core
local DataManager = require(Core.DataManager)
local WorldBuilder = require(script.Parent.WorldBuilder)

local LB = {}
local V3 = Vector3.new
local CF = CFrame.new

local BOARDS = {
	{ Key = "Blocks", Title = "Топ по блокам", Store = "LB_Blocks_v2", Color = { 60, 150, 255 }, Get = function(d) return d.Stats.BlocksBroken or 0 end },
	{ Key = "Rebirths", Title = "Топ по ребёрсам", Store = "LB_Rebirths_v2", Color = { 255, 140, 40 }, Get = function(d) return d.Rebirths or 0 end },
	{ Key = "Eggs", Title = "Топ по яйцам", Store = "LB_Eggs_v2", Color = { 40, 200, 190 }, Get = function(d) return d.Stats.EggsOpened or 0 end },
}
local ROWS = 10
local labels = {} -- [boardKey] = { {name, value}... } списки TextLabel со всех ярусов
local names = {}

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.Name
		return p.Name
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and n or ("Игрок " .. userId)
	return names[userId]
end

-- яркая доска в стиле интерфейса: цветная рамка, белая панель, полосатые строки,
-- значение — в цветной «таблетке» справа, чтобы его было видно издалека
local function corner(gui, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = gui
end

local function buildBoard(parent, cf, def)
	local m = Instance.new("Model")
	m.Name = "Leaderboard_" .. def.Key
	m.Parent = parent
	local col = MK.C(def.Color)
	local dark = MK.Shade(col, -0.45)
	for _, sx in ipairs({ -1, 1 }) do
		local post = MK.Part(m, V3(1.4, 21, 1.4), cf * CF(sx * 7.6, 10.5, 0.5), dark)
		post.CanCollide = true
		MK.Ellipsoid(m, V3(2.2, 2.2, 2.2), cf * CF(sx * 7.6, 21.4, 0.5), col)
	end
	MK.Part(m, V3(16, 18.4, 1), cf * CF(0, 11.6, 0.7), col)
	MK.Part(m, V3(16.6, 1.2, 1.4), cf * CF(0, 20.9, 0.7), MK.Shade(col, 0.25))
	MK.Part(m, V3(16.6, 1.2, 1.4), cf * CF(0, 2.3, 0.7), dark)
	local panel = MK.Part(m, V3(14.6, 17, 0.2), cf * CF(0, 11.6, 0.1), { 255, 255, 255 })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(584, 680)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 200
	gui.Parent = panel
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(246, 248, 255)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0, 92)
	head.BackgroundColor3 = col
	head.BorderSizePixel = 0
	head.Parent = bg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(MK.Shade(col, 0.25), MK.Shade(col, -0.15))
	head.BackgroundColor3 = Color3.new(1, 1, 1) -- градиент умножается на фон
	g.Rotation = 90
	g.Parent = head
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -24, 1, -16)
	title.Position = UDim2.fromOffset(12, 8)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = def.Title
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = head
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = MK.Shade(col, -0.55)
	st.Parent = title
	local rows = {}
	for i = 1, ROWS do
		local y = 102 + (i - 1) * 57
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -20, 0, 51)
		row.Position = UDim2.fromOffset(10, y)
		row.BackgroundColor3 = (i % 2 == 1) and Color3.fromRGB(232, 236, 250) or Color3.fromRGB(255, 255, 255)
		row.BorderSizePixel = 0
		row.Parent = bg
		corner(row, 14)
		local medal = ({ Color3.fromRGB(255, 196, 30), Color3.fromRGB(170, 180, 200), Color3.fromRGB(226, 130, 60) })[i] or Color3.fromRGB(120, 110, 150)
		local num = Instance.new("TextLabel")
		num.Size = UDim2.fromOffset(52, 43)
		num.Position = UDim2.fromOffset(4, 4)
		num.BackgroundColor3 = medal
		num.Font = Enum.Font.FredokaOne
		num.TextScaled = true
		num.Text = tostring(i)
		num.TextColor3 = Color3.new(1, 1, 1)
		num.Parent = row
		corner(num, 12)
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.fromOffset(300, 38)
		name.Position = UDim2.fromOffset(66, 7)
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = "—"
		name.TextColor3 = Color3.fromRGB(40, 36, 60)
		name.Parent = row
		local pill = Instance.new("Frame")
		pill.Size = UDim2.fromOffset(180, 43)
		pill.Position = UDim2.new(1, -184, 0, 4)
		pill.BackgroundColor3 = col
		pill.BorderSizePixel = 0
		pill.Parent = row
		corner(pill, 20)
		local val = Instance.new("TextLabel")
		val.BackgroundTransparency = 1
		val.Size = UDim2.new(1, -16, 1, -8)
		val.Position = UDim2.fromOffset(8, 4)
		val.Font = Enum.Font.FredokaOne
		val.TextScaled = true
		val.Text = "0"
		val.TextColor3 = Color3.new(1, 1, 1)
		val.Parent = pill
		local vs = Instance.new("UIStroke")
		vs.Thickness = 2
		vs.Color = MK.Shade(col, -0.5)
		vs.Parent = val
		rows[i] = { name, val, pill }
	end
	labels[def.Key] = labels[def.Key] or {}
	table.insert(labels[def.Key], rows)
	return m
end

local function render(key, list)
	for _, rows in ipairs(labels[key] or {}) do
		for i = 1, ROWS do
			local e = list[i]
			rows[i][1].Text = e and e.name or "—"
			rows[i][2].Text = e and Util.Format(e.value) or ""
		end
	end
end

local function localList(def)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = DataManager.Get(p)
		if d then
			table.insert(list, { name = p.Name, value = def.Get(d) })
		end
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	return list
end

local function refresh()
	for _, def in ipairs(BOARDS) do
		local ok = pcall(function()
			local store = DataStoreService:GetOrderedDataStore(def.Store)
			for _, p in ipairs(Players:GetPlayers()) do
				local d = DataManager.Get(p)
				if d and not d._NoSave then
					store:SetAsync(tostring(p.UserId), math.floor(def.Get(d)))
				end
			end
			local page = store:GetSortedAsync(false, ROWS):GetCurrentPage()
			local list = {}
			for _, entry in ipairs(page) do
				table.insert(list, { name = nameOf(tonumber(entry.key) or 0), value = entry.value })
			end
			render(def.Key, list)
		end)
		if not ok then
			render(def.Key, localList(def))
		end
	end
end

function LB.Init()
	for b, pts in pairs(WorldBuilder.Points) do
		local O = pts.Origin
		local hub = workspace.World:FindFirstChild("Biome" .. b) and workspace.World["Biome" .. b]:FindFirstChild("Hub")
		if O and hub then
			for i, def in ipairs(BOARDS) do
				local pos = O + V3(-22 + (i - 1) * 18, 0, -201)
				buildBoard(hub, CFrame.lookAt(pos, O + V3(0, 0, -140)), def)
			end
		end
	end
	task.spawn(function()
		task.wait(5)
		while true do
			refresh()
			task.wait(90)
		end
	end)
end

return LB
