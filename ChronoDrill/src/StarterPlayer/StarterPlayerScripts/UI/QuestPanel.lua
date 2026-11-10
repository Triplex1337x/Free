-- QuestPanel: окно «Задания» (открывается кнопкой в меню).
-- Вкладка «Задания»: сюжетный квест Drill-Bot 3000 и 3 динамических (всегда разные).
-- Вкладка «Неделя»: 4 недельных задания и бонус за все — эксклюзивный Звёздный Грифон.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configs = ReplicatedStorage:WaitForChild("Configs")
local QuestsData = require(Configs:WaitForChild("QuestsData"))
local BoostsData = require(Configs:WaitForChild("BoostsData"))
local RewardsData = require(Configs:WaitForChild("RewardsData"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local UI = require(script.Parent.UIKit)
local Icons2D = require(script.Parent.Icons2D)
local Icons3D = require(script.Parent.Icons3D)

local QuestPanel = {}

local TYPE_GLYPH = {
	MineBlocks = "Pickaxe", MineOre = "Chest", MineVeins = "Shard", Depth = "Rocket", DealDamage = "Sword",
	Nuggets = "Coin", OpenEggs = "Egg", UseBoosts = "Flask", GrowSeed = "Sprout", EarnCoins = "Coin",
	SellCount = "ShopBag", Crits = "Bolt", Hits = "Pickaxe", SellFull = "Backpack", PlayMinutes = "Clock",
}

local function rewardText(r, data)
	local parts = {}
	local coins = r.Coins
	if r.Trips and data then
		-- недельные: монеты по открытому ярусу (как на сервере)
		local rb = data.Derived and data.Derived.RebirthMult or 1
		coins = math.floor(RewardsData.CoinScale(math.max(1, data.UnlockedBiome or 1)) * r.Trips * rb)
	end
	if coins and coins > 0 then
		table.insert(parts, Util.Format(coins) .. " монет")
	end
	if r.Boosts then
		for id, n in pairs(r.Boosts) do
			local b = BoostsData.ById[id]
			table.insert(parts, n .. "x " .. (b and b.Name or id))
		end
	end
	if r.Shards and r.Shards > 0 then
		table.insert(parts, r.Shards .. " осколок")
	end
	if r.PetSlot then
		table.insert(parts, "+1 слот питомца")
	end
	return table.concat(parts, ", ")
end

local function rewardGlyph(r)
	if r.PetSlot then
		return "Paw"
	end
	if r.Shards then
		return "Shard"
	end
	if r.Boosts then
		for id in pairs(r.Boosts) do
			return id
		end
	end
	return "Coin"
end

local function weeklyDone(w)
	local n = 0
	for _, q in ipairs((w and w.Quests) or {}) do
		if q.Claimed then
			n = n + 1
		end
	end
	return n
end

-- Сколько заданий можно забрать прямо сейчас (для бейджа «!»)
function QuestPanel.Claimable(data)
	if not data then
		return 0
	end
	local n = 0
	local q = QuestsData.Story[data.StoryIndex or 1]
	if q then
		local cur = (q.Stat == "SessionEggs") and (data.Derived and data.Derived.SessionEggs or 0) or (data.Stats and data.Stats[q.Stat] or 0)
		if cur >= q.Target then
			n = n + 1
		end
	end
	for i = 1, 3 do
		local dq = data.Dynamic and data.Dynamic[tostring(i)]
		if dq and dq.Type and dq.Progress >= dq.Target then
			n = n + 1
		end
	end
	local w = data.Weekly
	if w and w.Quests then
		for _, wq in ipairs(w.Quests) do
			if not wq.Claimed and wq.Progress >= wq.Target then
				n = n + 1
			end
		end
		if #w.Quests > 0 and not w.BonusClaimed and weeklyDone(w) == #w.Quests then
			n = n + 1
		end
	end
	return n
end

local function claim(ctx, kind, slot)
	local ok, res = pcall(function()
		return Net.Get("ClaimQuest"):InvokeServer(kind, slot)
	end)
	if ok and res and res.ok then
		ctx.Sound.Play("Unlock")
	elseif ok and res and res.msg then
		ctx.Toast(res.msg, "warn")
	end
end

function QuestPanel.Build(screen, ctx)
	local win = UI.Window(screen, { Name = "Quests", Title = "ЗАДАНИЯ", Color = UI.Colors.Blue, Size = UDim2.fromOffset(800, 570) })
	local c = win.Content

	local pages = {}
	for i = 1, 2 do
		pages[i] = UI.new("Frame", { Name = "Page" .. i, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -56), Position = UDim2.fromOffset(0, 56), Visible = i == 1, Parent = c })
	end
	UI.List(pages[1], 10)

	local function badgeIcon(parent, glyph, size)
		for _, ch in ipairs(parent:GetChildren()) do
			if ch:IsA("Frame") and ch.Name == "Glyph" then
				ch:Destroy()
			end
		end
		local ic = Icons2D.New(parent, glyph, size, { ZIndex = 3 })
		ic.Name = "Glyph"
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.47)
	end

	-- широкая карточка (вкладка «Задания»)
	local function card(order, color, glyph, height)
		local holder, face = UI.Plate(pages[1], UDim2.new(1, 0, 0, height), nil, UI.Colors.Panel, 16)
		holder.LayoutOrder = order
		UI.Gradient(face, Color3.new(1, 1, 1), Color3.fromRGB(222, 218, 240))
		local badge = UI.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(height - 20, height - 20), Position = UDim2.fromOffset(10, 10), Parent = face })
		UI.Corner(badge, 14)
		UI.Stroke(badge, 3, UI.Ink, true)
		UI.Gradient(badge, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
		local isz = math.floor((height - 20) * 0.72)
		badgeIcon(badge, glyph, isz)
		local x0 = height + 4
		local tag = UI.Text(face, "", { Size = UDim2.new(1, -(x0 + 200), 0, 20), Position = UDim2.fromOffset(x0, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color, Stroke = false, MaxText = 16 })
		local title = UI.Text(face, "", { Size = UDim2.new(1, -(x0 + 200), 0, 28), Position = UDim2.fromOffset(x0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 24 })
		local bar = UI.Bar(face, UDim2.new(1, -(x0 + 200), 0, 22), UDim2.new(0, x0, 1, -34), color)
		local rewardHolder = UI.new("Frame", { BackgroundColor3 = UI.Colors.Panel2, Size = UDim2.fromOffset(176, height - 64), Position = UDim2.new(1, -188, 0, 10), Parent = face })
		UI.Corner(rewardHolder, 12)
		UI.Stroke(rewardHolder, 2, UI.Colors.Panel3, true)
		local rglyph = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(4, 2), Parent = rewardHolder })
		local reward = UI.Text(rewardHolder, "", { Size = UDim2.new(1, -44, 1, -6), Position = UDim2.fromOffset(40, 3), TextColor3 = UI.Ink, Stroke = false, MaxText = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		local btn = UI.Button({ Parent = face, Text = "ЗАБРАТЬ", Color = UI.Colors.Green, Size = UDim2.fromOffset(176, 40), Position = UDim2.new(1, -188, 1, -50), TextSize = 20, Glyph = "Check" })
		local timer = UI.Text(face, "", { Size = UDim2.fromOffset(176, 40), Position = UDim2.new(1, -188, 1, -50), TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 18 })
		local obj = { Tag = tag, Title = title, Bar = bar, Reward = reward, Btn = btn, Timer = timer, LastGlyph = nil, Glyph = glyph }
		function obj.SetRewardGlyph(name)
			if obj.LastGlyph ~= name then
				obj.LastGlyph = name
				for _, ch in ipairs(rglyph:GetChildren()) do
					ch:Destroy()
				end
				Icons2D.New(rglyph, name, 34, { Shadow = false, ZIndex = 3, Color = (name == "Coin") and Color3.fromRGB(255, 208, 64) or nil })
			end
		end
		function obj.SetGlyph(name)
			if name and obj.Glyph ~= name then
				obj.Glyph = name
				badgeIcon(badge, name, isz)
			end
		end
		return obj
	end

	local story = card(0, UI.Colors.Orange, "Quest", 118)
	local slotGlyphs = { "Pickaxe", "Egg", "Star" }
	local slotColors = { UI.Colors.Teal, UI.Colors.Purple, UI.Colors.Pink }
	local slotTags = { "ДОБЫЧА", "КОЛЛЕКЦИЯ", "МАСТЕРСТВО" }
	local slots = {}
	for i = 1, 3 do
		slots[i] = card(i, slotColors[i], slotGlyphs[i], 100)
		slots[i].Btn.Activated:Connect(function()
			claim(ctx, "Dynamic", i)
		end)
	end
	story.Btn.Activated:Connect(function()
		claim(ctx, "Story")
	end)

	-----------------------------------------------------------------------------------------
	-- Неделя
	-----------------------------------------------------------------------------------------
	local wp = pages[2]
	local weekTimer = UI.Text(wp, "", { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Blue, Stroke = false, MaxText = 20 })
	local grid = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 294), Position = UDim2.fromOffset(0, 30), Parent = wp })
	local weekColors = { UI.Colors.Teal, UI.Colors.Purple, UI.Colors.Orange, UI.Colors.Pink }
	local weekly = {}
	for i = 1, 4 do
		local col = weekColors[i]
		local gx, gy = (i - 1) % 2, math.floor((i - 1) / 2)
		local _, face = UI.Plate(grid, UDim2.new(0.5, -6, 0, 142), UDim2.new(gx * 0.5, gx * 6, 0, gy * 152), UI.Colors.Panel, 16)
		UI.Gradient(face, Color3.new(1, 1, 1), Color3.fromRGB(222, 218, 240))
		local badge = UI.new("Frame", { BackgroundColor3 = col, Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(10, 10), Parent = face })
		UI.Corner(badge, 14)
		UI.Stroke(badge, 3, UI.Ink, true)
		UI.Gradient(badge, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 212))
		local title = UI.Text(face, "", { Size = UDim2.new(1, -90, 0, 58), Position = UDim2.fromOffset(78, 10), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 21, TextWrapped = true })
		local bar = UI.Bar(face, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 72), col)
		local rglyph = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 10, 1, -40), Parent = face })
		local reward = UI.Text(face, "", { Size = UDim2.new(1, -190, 0, 36), Position = UDim2.new(0, 44, 1, -43), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 14, TextWrapped = true })
		local btn = UI.Button({ Parent = face, Text = "ЗАБРАТЬ", Color = UI.Colors.Green, Size = UDim2.fromOffset(132, 36), Position = UDim2.new(1, -142, 1, -44), TextSize = 18 })
		local state = UI.Text(face, "", { Size = UDim2.fromOffset(132, 36), Position = UDim2.new(1, -142, 1, -44), TextColor3 = UI.Colors.Gray, Stroke = false, MaxText = 16 })
		local obj = { Title = title, Bar = bar, Reward = reward, Btn = btn, State = state, Glyph = nil, RGlyph = nil }
		function obj.Set(glyph, rg)
			if obj.Glyph ~= glyph then
				obj.Glyph = glyph
				badgeIcon(badge, glyph, 42)
			end
			if obj.RGlyph ~= rg then
				obj.RGlyph = rg
				for _, ch in ipairs(rglyph:GetChildren()) do
					ch:Destroy()
				end
				Icons2D.New(rglyph, rg, 30, { Shadow = false, ZIndex = 3, Color = (rg == "Coin") and Color3.fromRGB(255, 208, 64) or nil })
			end
		end
		btn.Activated:Connect(function()
			claim(ctx, "Weekly", i)
		end)
		weekly[i] = obj
	end

	-- бонус за все недельные: эксклюзивный питомец
	local bHolder, bFace = UI.Plate(wp, UDim2.new(1, 0, 0, 108), UDim2.fromOffset(0, 334), Color3.fromRGB(255, 236, 170), 18)
	UI.Gradient(bFace, Color3.fromRGB(255, 250, 225), Color3.fromRGB(255, 214, 120))
	local petBox = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 196, 70), Size = UDim2.fromOffset(88, 88), Position = UDim2.fromOffset(10, 10), Parent = bFace })
	UI.Corner(petBox, 16)
	UI.Stroke(petBox, 3, UI.Ink, true)
	UI.Gradient(petBox, Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 170, 60))
	local petId = QuestsData.WeeklyBonus.Reward.Pet
	local okPet, petModel = pcall(function()
		return ctx.PetModel(petId, false)
	end)
	if okPet and petModel then
		Icons3D.New(petBox, petModel, { Size = 88, View = Vector3.new(0.6, 0.3, -1) })
	else
		badgeIcon(petBox, "Paw", 60)
	end
	UI.Text(bFace, "НЕДЕЛЬНЫЙ БОНУС · ЭКСКЛЮЗИВ", { Size = UDim2.new(1, -300, 0, 20), Position = UDim2.fromOffset(114, 10), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 110, 20), Stroke = false, MaxText = 16 })
	local bTitle = UI.Text(bFace, "", { Size = UDim2.new(1, -300, 0, 30), Position = UDim2.fromOffset(114, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Ink, Stroke = false, MaxText = 24 })
	local bBar = UI.Bar(bFace, UDim2.new(1, -300, 0, 22), UDim2.fromOffset(114, 70), UI.Colors.Orange)
	local bBtn = UI.Button({ Parent = bFace, Text = "ЗАБРАТЬ", Color = UI.Colors.Orange, Size = UDim2.fromOffset(170, 48), Position = UDim2.new(1, -182, 0.5, -24), TextSize = 20, Glyph = "Gift" })
	local bState = UI.Text(bFace, "", { Size = UDim2.fromOffset(170, 48), Position = UDim2.new(1, -182, 0.5, -24), TextColor3 = Color3.fromRGB(150, 100, 40), Stroke = false, MaxText = 18 })
	bBtn.Activated:Connect(function()
		claim(ctx, "WeeklyBonus")
	end)

	local tabs
	local current = 1
	local tabBadge

	local function renderMain(data)
		local idx = data.StoryIndex or 1
		local q = QuestsData.Story[idx]
		if q then
			local cur = (q.Stat == "SessionEggs") and (data.Derived and data.Derived.SessionEggs or 0) or (data.Stats and data.Stats[q.Stat] or 0)
			cur = math.min(cur, q.Target)
			story.Tag.Text = "СЮЖЕТ · DRILL-BOT 3000 · " .. idx .. "/" .. #QuestsData.Story
			story.Title.Text = q.Title .. ": " .. q.Text
			story.Bar.Set(cur / q.Target, Util.Format(cur) .. " / " .. Util.Format(q.Target))
			story.Reward.Text = rewardText(q.Reward)
			story.SetRewardGlyph(rewardGlyph(q.Reward))
			local done = cur >= q.Target
			story.Btn.Holder.Visible = done
			story.Timer.Text = done and "" or "В процессе"
		else
			story.Tag.Text = "СЮЖЕТ"
			story.Title.Text = "Все сюжетные задания выполнены!"
			story.Bar.Set(1, "★")
			story.Reward.Text = "—"
			story.Btn.Holder.Visible = false
			story.Timer.Text = ""
		end
		for i = 1, 3 do
			local s = slots[i]
			local dq = data.Dynamic and data.Dynamic[tostring(i)]
			s.Tag.Text = slotTags[i]
			if dq and dq.Type then
				s.SetGlyph(TYPE_GLYPH[dq.Type] or slotGlyphs[i])
				s.Title.Text = dq.Text
				s.Bar.Set(dq.Progress / dq.Target, Util.Format(dq.Progress) .. " / " .. Util.Format(dq.Target))
				s.Reward.Text = rewardText(dq.Reward or {})
				s.SetRewardGlyph(rewardGlyph(dq.Reward or {}))
				local done = dq.Progress >= dq.Target
				s.Btn.Holder.Visible = done
				s.Timer.Text = done and "" or "В процессе"
			else
				s.SetGlyph("Hourglass")
				s.Title.Text = "Новое задание скоро..."
				s.Bar.Set(0, "")
				s.Reward.Text = "—"
				s.Btn.Holder.Visible = false
				if dq and dq.Cooldown then
					s.Timer.Text = "Через " .. Util.Time(math.max(0, dq.Cooldown - ctx.ClientState.ServerNow()))
				end
			end
		end
	end

	local function renderWeek(data)
		local w = data.Weekly or {}
		local list = w.Quests or {}
		local now = ctx.ClientState.ServerNow()
		if w.Ends then
			local left = math.max(0, w.Ends - now)
			local t
			if left >= 86400 then
				t = math.floor(left / 86400) .. " д " .. math.floor(left % 86400 / 3600) .. " ч"
			else
				t = Util.Time(left)
			end
			weekTimer.Text = "Новые недельные задания через " .. t
		else
			weekTimer.Text = "Недельные задания"
		end
		for i = 1, 4 do
			local o = weekly[i]
			local q = list[i]
			if q then
				o.Set(TYPE_GLYPH[q.Type] or "Star", rewardGlyph(q.Reward or {}))
				o.Title.Text = q.Text
				o.Bar.Set(q.Progress / q.Target, Util.Format(q.Progress) .. " / " .. Util.Format(q.Target))
				o.Reward.Text = rewardText(q.Reward or {}, data)
				local done = q.Progress >= q.Target
				o.Btn.Holder.Visible = done and not q.Claimed
				o.State.Text = q.Claimed and "Получено" or (done and "" or "В процессе")
			else
				o.Set("Hourglass", "Coin")
				o.Title.Text = "Загрузка..."
				o.Bar.Set(0, "")
				o.Reward.Text = ""
				o.Btn.Holder.Visible = false
				o.State.Text = ""
			end
		end
		local done = weeklyDone(w)
		local total = math.max(#list, 4)
		local mult = RewardsData.SpecialMult(petId, data.UnlockedBiome or 1)
		bTitle.Text = RewardsData.SpecialPets[petId].Name .. " x" .. Util.Format(mult) .. " + бусты"
		bBar.Set(done / total, "Выполнено " .. done .. " / " .. total)
		local ready = done >= total and not w.BonusClaimed
		bBtn.Holder.Visible = ready
		bState.Text = w.BonusClaimed and "Получено" or (ready and "" or "Заверши все 4")
	end

	local function render()
		local data = ctx.ClientState.Data
		if not data then
			return
		end
		if current == 1 then
			renderMain(data)
		else
			renderWeek(data)
		end
		-- «!» на вкладке недели, если там есть что забрать
		local wn = 0
		local w = data.Weekly
		if w and w.Quests then
			for _, q in ipairs(w.Quests) do
				if not q.Claimed and q.Progress >= q.Target then
					wn = wn + 1
				end
			end
			if #w.Quests > 0 and not w.BonusClaimed and weeklyDone(w) == #w.Quests then
				wn = wn + 1
			end
		end
		tabBadge.Visible = wn > 0
	end

	tabs = UI.Tabs(c, { "Задания", "Неделя" }, { UI.Colors.Blue, UI.Colors.Orange }, function(i)
		current = i
		for k, pg in ipairs(pages) do
			pg.Visible = k == i
		end
		render()
	end)
	local weekBtn = tabs.Buttons[2]
	tabBadge = UI.new("Frame", { Name = "Badge", BackgroundColor3 = UI.Colors.Red, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -14, 0, -8), Visible = false, ZIndex = 8, Parent = weekBtn.Holder })
	UI.Corner(tabBadge, UDim.new(1, 0))
	UI.Stroke(tabBadge, 2.5, UI.Ink, true)
	UI.Text(tabBadge, "!", { Size = UDim2.fromScale(1, 1), ZIndex = 9, MaxText = 18 })

	win.SelectTab = function(i)
		tabs.Select(i)
	end
	ctx.ClientState.Changed:Connect(function()
		if win.IsOpen then
			render()
		end
	end)
	win.Opened:Connect(function()
		tabs.Select(current)
	end)
	task.spawn(function()
		while true do
			if win.IsOpen then
				render()
			end
			task.wait(1)
		end
	end)
	return win
end

return QuestPanel
