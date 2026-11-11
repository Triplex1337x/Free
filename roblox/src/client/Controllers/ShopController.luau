-- Shop (game passes + developer products) and promo codes.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config.Monetization)

local UI = require(script.Parent.Parent.UI)
local Hud = require(script.Parent.HudController)

local Theme = UI.Theme
local player = Players.LocalPlayer

local ShopController = {}

local function sorted(map)
	local list = {}
	for key, item in map do
		if item.Id ~= 0 then
			table.insert(list, { Key = key, Item = item })
		end
	end
	table.sort(list, function(a, b)
		return (a.Item.Order or 99) < (b.Item.Order or 99)
	end)
	return list
end

local function fetchPrice(item, infoType: Enum.InfoType, label: TextButton, ownedCheck: (() -> boolean)?)
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.Id, infoType)
		local price = if ok and info and info.PriceInRobux then info.PriceInRobux else item.Price
		if not (ownedCheck and ownedCheck()) then
			label.Text = ("R$ %d"):format(price)
		end
	end)
end

function ShopController:BuildShop()
	local panel = Hud:CreatePanel("Магазин", Vector2.new(860, 560))
	local scroll = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		Parent = panel.Content,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function header(text: string)
		UI.label({ Text = text, Font = Theme.FontHeavy, TextColor3 = Theme.Gold, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), MaxTextSize = 24, LayoutOrder = nextOrder(), Parent = scroll })
	end

	local function grid()
		return UI.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = scroll,
		}, { UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 120), CellPadding = UDim2.fromOffset(8, 8) }) })
	end

	local function card(parent, item, color: Color3)
		local frame = UI.new("Frame", { BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.2, Parent = parent }, { UI.corner(12), UI.stroke(color, 2, 0.2), UI.padding(10) })
		UI.label({ Text = item.Name, Font = Theme.FontHeavy, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -120, 0, 28), MaxTextSize = 22, Parent = frame })
		UI.label({ Text = item.Description, TextColor3 = Theme.SubText, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -120, 1, -32), Position = UDim2.fromOffset(0, 32), MaxTextSize = 15, Parent = frame })
		return frame
	end

	local passes = sorted(Config.GamePasses)
	if #passes > 0 then
		header("Пропуски — навсегда")
		local g = grid()
		for _, entry in passes do
			local frame = card(g, entry.Item, Theme.Gold)
			local attr = "Pass_" .. entry.Key
			local button = UI.button({ Text = "...", Color = Theme.Good, Size = UDim2.fromOffset(110, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Parent = frame, OnClick = function()
				Remotes.Action:FireServer("Buy", { Type = "Pass", Key = entry.Key })
			end })
			local function owned()
				return player:GetAttribute(attr) == true
			end
			player:GetAttributeChangedSignal(attr):Connect(function()
				if owned() then
					button.Text = "Куплено"
					button.BackgroundColor3 = Theme.PanelLight
				end
			end)
			if owned() then
				button.Text = "Куплено"
				button.BackgroundColor3 = Theme.PanelLight
			else
				fetchPrice(entry.Item, Enum.InfoType.GamePass, button, owned)
			end
		end
	end

	local products = sorted(Config.Products)
	if #products > 0 then
		header("Бусты и спины")
		UI.label({
			Text = "Спины и осколки дают случайные стили — точные шансы смотри в меню «Ролл» перед покупкой.",
			TextColor3 = Theme.SubText,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 22),
			MaxTextSize = 15,
			LayoutOrder = nextOrder(),
			Parent = scroll,
		})
		local g = grid()
		local randomCards = {}
		for _, entry in products do
			local frame = card(g, entry.Item, Theme.Accent)
			local button = UI.button({ Text = "...", Color = Theme.Good, Size = UDim2.fromOffset(110, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Parent = frame, OnClick = function()
				Remotes.Action:FireServer("Buy", { Type = "Product", Key = entry.Key })
			end })
			fetchPrice(entry.Item, Enum.InfoType.Product, button)
			if entry.Item.PaidRandom then
				table.insert(randomCards, frame)
			end
		end
		-- Hide paid random items where regional policy forbids them.
		local function applyPolicy()
			local restricted = player:GetAttribute("PaidRandomRestricted") ~= false
			for _, frame in randomCards do
				frame.Visible = not restricted
			end
		end
		player:GetAttributeChangedSignal("PaidRandomRestricted"):Connect(applyPolicy)
		applyPolicy()
	end

	if #passes == 0 and #products == 0 then
		UI.label({ Text = "Товары ещё не настроены (см. Config/Monetization).", TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 0, 30), MaxTextSize = 18, Parent = scroll })
	end
	return panel
end

function ShopController:BuildCodes()
	local panel = Hud:CreatePanel("Коды", Vector2.new(480, 260))
	local box = UI.new("TextBox", {
		PlaceholderText = "Введи код...",
		Text = "",
		ClearTextOnFocus = false,
		Font = Theme.FontHeavy,
		TextScaled = true,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundColor3 = Theme.Background,
		Size = UDim2.new(1, 0, 0, 54),
		Parent = panel.Content,
	}, { UI.corner(10), UI.stroke(Theme.Accent2, 2, 0.2), UI.padding(10), UI.new("UITextSizeConstraint", { MaxTextSize = 24 }) })

	local busy = false
	UI.button({ Text = "АКТИВИРОВАТЬ", Color = Theme.Accent, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 70), Parent = panel.Content, OnClick = function()
		if busy or box.Text == "" then
			return
		end
		busy = true
		local ok, response = pcall(Remotes.RedeemCode.InvokeServer, Remotes.RedeemCode, box.Text)
		if ok and type(response) == "table" then
			Hud:Toast(response.Message, if response.Ok then "success" else "error")
			if response.Ok then
				box.Text = ""
			end
		else
			Hud:Toast("Не удалось активировать, попробуй ещё раз.", "error")
		end
		busy = false
	end })
	UI.label({ Text = "Новые коды — в группе после каждого обновления!", TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 134), MaxTextSize = 15, Parent = panel.Content })
	return panel
end

function ShopController:Init()
	local shop = self:BuildShop()
	local codes = self:BuildCodes()
	Hud:AddMenuButton("Shop", Color3.fromRGB(255, 150, 40), 7, shop.Toggle)
	Hud:AddMenuButton("Codes", Theme.Good, 8, codes.Toggle)
end

return ShopController
