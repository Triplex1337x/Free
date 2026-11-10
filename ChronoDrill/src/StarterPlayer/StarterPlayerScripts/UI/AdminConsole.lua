-- AdminConsole: текстовая консоль разработчика (F3; основная панель — F2). Видна только админам (атрибут IsAdmin от сервера).
-- Ввод команды + Enter, стрелки ↑/↓ — история, Tab — дополнить имя команды.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local UI = require(script.Parent.UIKit)

local AdminConsole = {}
local player = Players.LocalPlayer
local MONO = Enum.Font.Code

function AdminConsole.Build(screen, ctx)
	local root = UI.new("Frame", { Name = "AdminConsole", BackgroundColor3 = Color3.fromRGB(14, 12, 24), BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(820, 360), Visible = false, ZIndex = 80, Parent = screen })
	UI.Corner(root, 14)
	UI.Stroke(root, 3, Color3.fromRGB(110, 240, 160), true)
	local head = UI.Text(root, "КОНСОЛЬ РАЗРАБОТЧИКА · F3 — закрыть · help — список команд · @ник — для другого игрока", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(110, 240, 160), MaxText = 15, ZIndex = 81, StrokeThickness = 1 })
	local log = UI.new("ScrollingFrame", { BackgroundColor3 = Color3.fromRGB(6, 6, 12), BackgroundTransparency = 0.2, BorderSizePixel = 0, Size = UDim2.new(1, -20, 1, -110), Position = UDim2.fromOffset(10, 32), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ZIndex = 81, Parent = root })
	UI.Corner(log, 8)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = log
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = log
	local hint = UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 1, -74), Font = MONO, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 150, 190), Text = "", ZIndex = 81, Parent = root })
	local box = UI.new("TextBox", { BackgroundColor3 = Color3.fromRGB(30, 26, 48), Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 1, -50), Font = MONO, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), PlaceholderText = "команда, например: coins 1m", PlaceholderColor3 = Color3.fromRGB(120, 120, 150), ClearTextOnFocus = false, Text = "", ZIndex = 82, Parent = root })
	UI.Corner(box, 8)
	local bpad = Instance.new("UIPadding")
	bpad.PaddingLeft = UDim.new(0, 10)
	bpad.Parent = box

	local order = 0
	local function line(text, color)
		for piece in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
			order = order + 1
			UI.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = MONO, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or Color3.fromRGB(220, 220, 235), Text = piece, LayoutOrder = order, ZIndex = 82, Parent = log })
		end
		task.defer(function()
			log.CanvasPosition = Vector2.new(0, 1e6)
		end)
	end

	local commands = {}
	local history, hpos = {}, 0
	local function loadCommands()
		local ok, res = pcall(function()
			return Net.Get("AdminCommand"):InvokeServer("__list")
		end)
		if ok and res and res.ok then
			commands = res.commands
		end
	end

	local function run(text)
		text = string.gsub(text or "", "^%s+", "")
		if text == "" then
			return
		end
		table.insert(history, text)
		hpos = #history + 1
		line("> " .. text, Color3.fromRGB(110, 240, 160))
		local ok, res = pcall(function()
			return Net.Get("AdminCommand"):InvokeServer(text)
		end)
		if not ok then
			line("Ошибка соединения", Color3.fromRGB(255, 120, 120))
		elseif res then
			line(res.text or "", res.ok and Color3.fromRGB(220, 220, 235) or Color3.fromRGB(255, 140, 120))
		end
	end

	box.FocusLost:Connect(function(enter)
		if enter then
			run(box.Text)
			box.Text = ""
			task.defer(function()
				if root.Visible then
					box:CaptureFocus()
				end
			end)
		end
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local word = string.match(box.Text, "^(%S*)") or ""
		local found = {}
		if word ~= "" then
			for _, c in ipairs(commands) do
				if string.sub(c.Name, 1, #word) == string.lower(word) then
					table.insert(found, c.Name .. (c.Usage ~= "" and (" " .. c.Usage) or "") .. " — " .. c.Desc)
				end
				if #found >= 2 then
					break
				end
			end
		end
		hint.Text = table.concat(found, "   |   ")
	end)

	local function toggle()
		if not player:GetAttribute("IsAdmin") then
			return
		end
		root.Visible = not root.Visible
		if root.Visible then
			if #commands == 0 then
				loadCommands()
				line("Готово. Напиши help, чтобы увидеть все команды.", Color3.fromRGB(150, 150, 190))
			end
			task.defer(function()
				box:CaptureFocus()
			end)
		else
			box:ReleaseFocus()
		end
	end
	AdminConsole.Toggle = toggle

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.F3 then
			toggle()
			return
		end
		if not root.Visible or not box:IsFocused() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Up and #history > 0 then
			hpos = math.max(1, hpos - 1)
			box.Text = history[hpos] or ""
			box.CursorPosition = #box.Text + 1
		elseif input.KeyCode == Enum.KeyCode.Down and #history > 0 then
			hpos = math.min(#history + 1, hpos + 1)
			box.Text = history[hpos] or ""
			box.CursorPosition = #box.Text + 1
		elseif input.KeyCode == Enum.KeyCode.Tab then
			local word = string.match(box.Text, "^(%S*)") or ""
			for _, c in ipairs(commands) do
				if word ~= "" and string.sub(c.Name, 1, #word) == string.lower(word) then
					box.Text = c.Name .. " "
					box.CursorPosition = #box.Text + 1
					break
				end
			end
		end
	end)
	return root
end

return AdminConsole
