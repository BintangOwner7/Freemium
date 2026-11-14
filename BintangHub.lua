-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Remove the previous instance when the script is executed again.
if shared.BintangHub then
	pcall(shared.BintangHub.destroy)
end

-- Services.
local playersService = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local localPlayer = playersService.LocalPlayer

-- Constants.
local TITLE = "BintangHub"
local GAME_NAME = "Violence District"
local DISCORD_LINK = "https://discord.gg/isi-link-kamu"
local TIKTOK_NAME = "@isi-tiktok-kamu"
local LOGO_URL = ""
local FOLDER = "BintangHub"
local CONFIG_FOLDER = FOLDER .. "/configs"
local LOGO_PATH = FOLDER .. "/logo.png"
local ESP_NAME = "BintangESP"
local DEFAULT_SPEED = 16
local SIDEBAR_WIDTH = 120
local TOPBAR_HEIGHT = 34
local MIN_SIZE = Vector2.new(420, 260)
local MAX_SIZE = Vector2.new(720, 460)

local BG = Color3.fromRGB(12, 8, 20)
local PANEL = Color3.fromRGB(22, 15, 36)
local ACTIVE = Color3.fromRGB(42, 26, 70)
local ACCENT = Color3.fromRGB(150, 70, 255)
local ACCENT_SOFT = Color3.fromRGB(196, 150, 255)
local DIVIDER = Color3.fromRGB(70, 44, 120)
local TEXT = Color3.fromRGB(246, 241, 255)
local MUTED = Color3.fromRGB(165, 148, 196)
local TRACK_OFF = Color3.fromRGB(20, 13, 34)
local BAR = Color3.fromRGB(80, 58, 120)
local COLOR_PRESETS = {
	Color3.fromRGB(150, 70, 255),
	Color3.fromRGB(255, 50, 80),
	Color3.fromRGB(60, 200, 255),
	Color3.fromRGB(80, 255, 130),
	Color3.fromRGB(255, 255, 255),
}
local TAB_NAMES = { "Info", "Exclusive", "Survivor", "Killer", "ESP", "Config" }
local ICONS = {
	Info = "ⓘ",
	Exclusive = "⌂",
	Survivor = "☺",
	Killer = "⚔",
	ESP = "◉",
	Config = "⚙",
}

-- State.
local connections = {}
local values = {}
local setters = {}
local tabs = {}
local windowLocked = false
local layoutCounter = 0

-- Feature state.
local espEnabled = false
local speedEnabled = false
local speedValue = 1
local playerColor = COLOR_PRESETS[1]

-- Folders for logo and configs.
if makefolder then
	if not isfolder(FOLDER) then
		makefolder(FOLDER)
	end
	if not isfolder(CONFIG_FOLDER) then
		makefolder(CONFIG_FOLDER)
	end
end

---Keep a connection so it can be cleaned up when the hub closes.
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function nextOrder()
	layoutCounter = layoutCounter + 1
	return layoutCounter
end

local function create(class, props, parent)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function makeLabel(parent, props)
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	return create("TextLabel", base, parent)
end

---Soft purple glow made of stacked translucent layers. Must be created before the target.
---@param parent Instance
---@param baseRadius number? Corner radius of the target, nil for a circle.
---@param layers number
local function makeGlow(parent, baseRadius, layers)
	for index = layers, 1, -1 do
		local pad = index * 3
		local layer = create("Frame", {
			Position = UDim2.new(0, -pad, 0, -pad),
			Size = UDim2.new(1, pad * 2, 1, pad * 2),
			BackgroundColor3 = ACCENT,
			BackgroundTransparency = 0.8 + (index - 1) * 0.045,
			BorderSizePixel = 0,
		}, parent)
		create("UICorner", {
			CornerRadius = baseRadius and UDim.new(0, baseRadius + pad) or UDim.new(1, 0),
		}, layer)
	end
end

-- Download the logo once when a url is configured.
local function downloadLogo()
	if LOGO_URL == "" or not request or not writefile then
		return
	end
	if isfile(LOGO_PATH) then
		return
	end
	local ok, response = pcall(request, { Url = LOGO_URL, Method = "GET" })
	if ok and response and response.Success then
		writefile(LOGO_PATH, response.Body)
	end
end

-- Load the logo from the workspace folder if it exists.
local function getLogoAsset()
	if isfile and getcustomasset and isfile(LOGO_PATH) then
		local ok, asset = pcall(getcustomasset, LOGO_PATH)
		if ok then
			return asset
		end
	end
	return ""
end

pcall(downloadLogo)
local logoAsset = getLogoAsset()

---Circular logo with a purple ring and glow.
local function makeLogo(parent, size, position, glowLayers)
	local holder = create("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		BackgroundTransparency = 1,
	}, parent)
	makeGlow(holder, nil, glowLayers)
	local logo = create("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ACTIVE,
		BorderSizePixel = 0,
		Image = logoAsset,
		ScaleType = Enum.ScaleType.Crop,
	}, holder)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, logo)
	stroke(logo, ACCENT_SOFT, 1.5)
	return holder
end

---Drag a target by its handle; onTap fires when released without moving.
local function makeDraggable(handle, target, canDrag, onTap)
	local dragging, moved, dragStart, startPos = false, false, nil, nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		moved = false
		dragStart = input.Position
		startPos = target.Position
	end)

	connect(userInputService.InputChanged, function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		if delta.Magnitude > 4 then
			moved = true
		end
		if canDrag and not canDrag() then
			return
		end
		target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end)

	connect(userInputService.InputEnded, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if dragging and not moved and onTap then
			onTap()
		end
		dragging = false
	end)
end

-- Root gui, hidden from the game when possible.
local screenGui = create("ScreenGui", {
	Name = "BintangHubUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
}, gethui and gethui() or localPlayer:WaitForChild("PlayerGui"))

-- Window holder keeps the glow outside of the clipped main frame.
local window = create("Frame", {
	Size = UDim2.fromOffset(500, 312),
	Position = UDim2.new(0.5, -250, 0.5, -156),
	BackgroundTransparency = 1,
}, screenGui)
makeGlow(window, 10, 4)

local main = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BG,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Active = true,
}, window)
corner(main, 10)
stroke(main, ACCENT, 1.5)

-- Sidebar.
local sidebar = create("Frame", {
	Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
	BackgroundTransparency = 1,
}, main)

create("Frame", {
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, 1, 1, 0),
	BackgroundColor3 = DIVIDER,
	BorderSizePixel = 0,
}, sidebar)

local sidebarHeader = create("Frame", {
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	Active = true,
}, sidebar)
makeLogo(sidebarHeader, 22, UDim2.fromOffset(10, 7), 2)
makeLabel(sidebarHeader, {
	Position = UDim2.fromOffset(40, 0),
	Size = UDim2.new(1, -44, 1, 0),
	Text = TITLE,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
})

local searchFrame = create("Frame", {
	Position = UDim2.fromOffset(8, 40),
	Size = UDim2.new(1, -16, 0, 28),
	BackgroundColor3 = PANEL,
}, sidebar)
corner(searchFrame, 8)
stroke(searchFrame, ACCENT, 1)
makeLabel(searchFrame, {
	Position = UDim2.fromOffset(8, 0),
	Size = UDim2.fromOffset(16, 28),
	Text = "⌕",
	TextSize = 15,
	TextColor3 = ACCENT_SOFT,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local searchBox = create("TextBox", {
	Position = UDim2.fromOffset(28, 0),
	Size = UDim2.new(1, -32, 1, 0),
	BackgroundTransparency = 1,
	PlaceholderText = "Search",
	PlaceholderColor3 = MUTED,
	Text = "",
	TextColor3 = TEXT,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
}, searchFrame)

local tabList = create("Frame", {
	Position = UDim2.fromOffset(6, 76),
	Size = UDim2.new(1, -12, 1, -134),
	BackgroundTransparency = 1,
}, sidebar)
create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, tabList)

-- Profile card at the bottom of the sidebar.
local profile = create("Frame", {
	Position = UDim2.new(0, 8, 1, -52),
	Size = UDim2.new(1, -16, 0, 46),
	BackgroundTransparency = 1,
}, sidebar)
create("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = DIVIDER,
	BorderSizePixel = 0,
}, profile)

local function getAvatar()
	local ok, content = pcall(
		playersService.GetUserThumbnailAsync,
		playersService,
		localPlayer.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size48x48
	)
	return ok and content or ""
end

local avatar = create("ImageLabel", {
	Position = UDim2.fromOffset(0, 9),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Image = getAvatar(),
}, profile)
corner(avatar, 6)
stroke(avatar, DIVIDER, 1)
makeLabel(profile, {
	Position = UDim2.fromOffset(38, 9),
	Size = UDim2.new(1, -38, 0, 15),
	Text = localPlayer.DisplayName,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
makeLabel(profile, {
	Position = UDim2.fromOffset(38, 24),
	Size = UDim2.new(1, -38, 0, 14),
	Text = GAME_NAME,
	Font = Enum.Font.Gotham,
	TextSize = 9,
	TextColor3 = MUTED,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

-- Topbar with page title and window buttons.
local topBar = create("Frame", {
	Position = UDim2.fromOffset(SIDEBAR_WIDTH + 1, 0),
	Size = UDim2.new(1, -(SIDEBAR_WIDTH + 1), 0, TOPBAR_HEIGHT),
	BackgroundTransparency = 1,
	Active = true,
}, main)
create("Frame", {
	Position = UDim2.new(0, 0, 1, -1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = DIVIDER,
	BorderSizePixel = 0,
}, topBar)

local pageIcon = makeLabel(topBar, {
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.fromOffset(18, TOPBAR_HEIGHT),
	Text = ICONS.Info,
	TextSize = 15,
	TextColor3 = ACCENT_SOFT,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local pageTitle = makeLabel(topBar, {
	Position = UDim2.fromOffset(36, 0),
	Size = UDim2.new(1, -140, 1, 0),
	Text = "Info",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
})

local function makeTopButton(text, xOffset)
	return create("TextButton", {
		Position = UDim2.new(1, xOffset, 0, 5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = MUTED,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
	}, topBar)
end

local lockButton = makeTopButton("🔓", -86)
local minimizeButton = makeTopButton("–", -58)
local closeButton = makeTopButton("X", -30)

local contentArea = create("Frame", {
	Position = UDim2.fromOffset(SIDEBAR_WIDTH + 1, TOPBAR_HEIGHT + 1),
	Size = UDim2.new(1, -(SIDEBAR_WIDTH + 1), 1, -(TOPBAR_HEIGHT + 1)),
	BackgroundTransparency = 1,
}, main)

-- Tabs and columns.
local function makeColumn(page, side)
	local size = side == "full" and UDim2.new(1, -12, 1, -8) or UDim2.new(0.5, -9, 1, -8)
	local position = side == "right" and UDim2.new(0.5, 3, 0, 4) or UDim2.fromOffset(6, 4)
	local column = create("ScrollingFrame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = ACCENT,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, page)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, column)
	create("UIPadding", { PaddingRight = UDim.new(0, 6) }, column)
	return column
end

local function selectTab(name)
	for tabName, tab in pairs(tabs) do
		local active = tabName == name
		tab.page.Visible = active
		tab.button.BackgroundTransparency = active and 0 or 1
		tab.indicator.Visible = active
		tab.icon.TextColor3 = active and ACCENT_SOFT or MUTED
		tab.label.TextColor3 = active and TEXT or MUTED
	end
	pageTitle.Text = name
	pageIcon.Text = ICONS[name] or ""
end

local function addTab(name, full)
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = ACTIVE,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, tabList)
	corner(button, 6)

	local indicator = create("Frame", {
		Position = UDim2.new(0, 0, 0.5, -7),
		Size = UDim2.fromOffset(2, 14),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		Visible = false,
	}, button)
	local icon = makeLabel(button, {
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.fromOffset(16, 28),
		Text = ICONS[name] or "",
		TextColor3 = MUTED,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local label = makeLabel(button, {
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Text = name,
		TextColor3 = MUTED,
	})

	local page = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, contentArea)

	local tab = {
		button = button,
		indicator = indicator,
		icon = icon,
		label = label,
		page = page,
	}
	if full then
		tab.left = makeColumn(page, "full")
	else
		tab.left = makeColumn(page, "left")
		tab.right = makeColumn(page, "right")
	end

	tabs[name] = tab
	button.MouseButton1Click:Connect(function()
		selectTab(name)
	end)
	return tab
end

-- Control builders.
local function makeRow(section, height)
	return create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	}, section)
end

---Collapsible section with an underlined header. Returns the body frame.
local function addSection(column, title)
	local section = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	}, column)
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, section)

	local header = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
	}, section)
	makeLabel(header, {
		Size = UDim2.new(1, -20, 1, 0),
		Text = title,
		Font = Enum.Font.GothamBold,
	})
	local chevron = makeLabel(header, {
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.fromOffset(14, 26),
		Text = "▼",
		TextSize = 8,
		TextColor3 = ACCENT_SOFT,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	create("Frame", {
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
	}, header)

	local body = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, section)
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 2) }, body)

	header.MouseButton1Click:Connect(function()
		body.Visible = not body.Visible
		chevron.Text = body.Visible and "▼" or "▲"
	end)

	return body
end

local function addToggle(section, text, flag, default, callback)
	local row = makeRow(section, 26)
	makeLabel(row, { Size = UDim2.new(1, -44, 1, 0), Text = text })

	local track = create("TextButton", {
		Position = UDim2.new(1, -34, 0.5, -8),
		Size = UDim2.fromOffset(34, 16),
		BackgroundColor3 = TRACK_OFF,
		Text = "",
		AutoButtonColor = false,
	}, row)
	corner(track, 8)
	local trackStroke = stroke(track, ACCENT, 1)
	local knob = create("Frame", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, track)
	corner(knob, 6)

	local state = false
	local function set(value)
		state = value and true or false
		values[flag] = state
		tweenService:Create(track, TweenInfo.new(0.15), {
			BackgroundColor3 = state and ACCENT or TRACK_OFF,
		}):Play()
		tweenService:Create(knob, TweenInfo.new(0.15), {
			Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
		}):Play()
		trackStroke.Color = state and ACCENT_SOFT or ACCENT
		if callback then
			task.spawn(callback, state)
		end
	end

	setters[flag] = set
	track.MouseButton1Click:Connect(function()
		set(not state)
	end)
	set(default)
end

local function addKeybind(section, text, flag, callback)
	local row = makeRow(section, 26)
	makeLabel(row, { Size = UDim2.new(1, -54, 1, 0), Text = text, TextColor3 = MUTED })

	local button = create("TextButton", {
		Position = UDim2.new(1, -48, 0.5, -10),
		Size = UDim2.fromOffset(48, 20),
		BackgroundColor3 = PANEL,
		Text = "None",
		TextColor3 = TEXT,
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		AutoButtonColor = false,
	}, row)
	corner(button, 5)
	stroke(button, ACCENT, 1)

	local listening = false
	local function set(name)
		values[flag] = name
		button.Text = name
	end

	setters[flag] = set
	set("None")

	button.MouseButton1Click:Connect(function()
		listening = true
		button.Text = "..."
	end)

	connect(userInputService.InputBegan, function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if listening then
			listening = false
			set(input.KeyCode == Enum.KeyCode.Escape and "None" or input.KeyCode.Name)
			return
		end
		if processed or values[flag] == "None" then
			return
		end
		if input.KeyCode.Name == values[flag] and callback then
			callback()
		end
	end)
end

local function addSlider(section, text, flag, minValue, maxValue, default, callback)
	local row = makeRow(section, 36)
	makeLabel(row, { Size = UDim2.new(1, -44, 0, 18), Text = text, TextColor3 = MUTED })
	local valueLabel = makeLabel(row, {
		Size = UDim2.new(1, 0, 0, 18),
		Text = tostring(default),
		TextColor3 = ACCENT_SOFT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local bar = create("Frame", {
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = BAR,
		BorderSizePixel = 0,
	}, row)
	corner(bar, 2)
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
	}, bar)
	corner(fill, 2)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, bar)
	corner(knob, 7)
	stroke(knob, ACCENT, 2)

	local function set(value)
		value = math.clamp(math.floor(value + 0.5), minValue, maxValue)
		local ratio = (value - minValue) / (maxValue - minValue)
		fill.Size = UDim2.fromScale(ratio, 1)
		knob.Position = UDim2.fromScale(ratio, 0.5)
		valueLabel.Text = tostring(value)
		values[flag] = value
		if callback then
			task.spawn(callback, value)
		end
	end

	setters[flag] = set

	local hit = create("TextButton", {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "",
	}, row)

	local dragging = false
	local function updateFromX(x)
		local ratio = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		set(minValue + (maxValue - minValue) * ratio)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)
	connect(userInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end)
	connect(userInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	set(default)
end

local function addColor(section, text, flag, callback)
	local row = makeRow(section, 26)
	makeLabel(row, { Size = UDim2.new(1, -50, 1, 0), Text = text, TextColor3 = MUTED })

	local swatch = create("TextButton", {
		Position = UDim2.new(1, -40, 0.5, -8),
		Size = UDim2.fromOffset(40, 16),
		BackgroundColor3 = COLOR_PRESETS[1],
		Text = "",
		AutoButtonColor = false,
	}, row)
	corner(swatch, 4)
	stroke(swatch, ACCENT_SOFT, 1)

	local function set(index)
		index = math.clamp(math.floor(index), 1, #COLOR_PRESETS)
		values[flag] = index
		swatch.BackgroundColor3 = COLOR_PRESETS[index]
		if callback then
			task.spawn(callback, COLOR_PRESETS[index])
		end
	end

	setters[flag] = set
	swatch.MouseButton1Click:Connect(function()
		set(values[flag] % #COLOR_PRESETS + 1)
	end)
	set(1)
end

local function addInput(section, text, placeholder)
	local row = makeRow(section, 46)
	makeLabel(row, { Size = UDim2.new(1, 0, 0, 18), Text = text, Font = Enum.Font.GothamBold })
	local box = create("TextBox", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = PANEL,
		PlaceholderText = placeholder,
		PlaceholderColor3 = BAR,
		Text = "",
		TextColor3 = TEXT,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	}, row)
	corner(box, 5)
	stroke(box, ACCENT, 1)
	create("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
	return box
end

local function addDropdown(section, text, options, default)
	local row = makeRow(section, 46)
	makeLabel(row, { Size = UDim2.new(1, 0, 0, 18), Text = text, Font = Enum.Font.GothamBold })

	local box = create("TextButton", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = PANEL,
		Text = "",
		AutoButtonColor = false,
	}, row)
	corner(box, 5)
	stroke(box, ACCENT, 1)
	local valueLabel = makeLabel(box, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = default,
		Font = Enum.Font.Gotham,
		TextSize = 11,
	})
	makeLabel(box, {
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.fromOffset(12, 24),
		Text = "▼",
		TextSize = 8,
		TextColor3 = ACCENT_SOFT,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local list = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = nextOrder(),
	}, section)
	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local dropdown = { value = default }

	function dropdown.set(value)
		dropdown.value = value
		valueLabel.Text = value
	end

	function dropdown.refresh(newOptions)
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for _, option in ipairs(newOptions) do
			local item = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = ACTIVE,
				Text = option,
				TextColor3 = TEXT,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				AutoButtonColor = false,
			}, list)
			corner(item, 4)
			item.MouseButton1Click:Connect(function()
				dropdown.set(option)
				list.Visible = false
			end)
		end
	end

	box.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
	end)

	dropdown.refresh(options)
	return dropdown
end

local function addButton(section, text, callback)
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = PANEL,
		Text = text,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, section)
	corner(button, 5)
	stroke(button, ACCENT, 1)

	button.MouseButton1Click:Connect(function()
		button.BackgroundColor3 = ACCENT
		tweenService:Create(button, TweenInfo.new(0.25), { BackgroundColor3 = PANEL }):Play()
		callback()
	end)
	return button
end

local function addText(section, text, size)
	return makeLabel(section, {
		Size = UDim2.new(1, 0, 0, size or 16),
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = MUTED,
		TextWrapped = true,
		LayoutOrder = nextOrder(),
	})
end

-- Features.
---Remove every ESP highlight we created.
local function clearESP()
	for _, player in ipairs(playersService:GetPlayers()) do
		local character = player.Character
		local highlight = character and character:FindFirstChild(ESP_NAME)
		if highlight then
			highlight:Destroy()
		end
	end
end

local function getHumanoid()
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setESP(state)
	espEnabled = state
	if not state then
		clearESP()
	end
end

local function setSpeedBoost(state)
	local wasEnabled = speedEnabled
	speedEnabled = state
	if wasEnabled and not state then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = DEFAULT_SPEED
		end
	end
end

-- Apply ESP and speed every frame so new players and respawns are covered.
connect(runService.Heartbeat, function()
	if espEnabled then
		for _, player in ipairs(playersService:GetPlayers()) do
			local character = player.Character
			if player ~= localPlayer and character then
				local highlight = character:FindFirstChild(ESP_NAME)
				if not highlight then
					highlight = create("Highlight", {
						Name = ESP_NAME,
						DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
						OutlineColor = Color3.new(1, 1, 1),
					}, character)
				end
				highlight.FillColor = playerColor
			end
		end
	end

	if speedEnabled then
		local humanoid = getHumanoid()
		local target = DEFAULT_SPEED * speedValue
		if humanoid and humanoid.WalkSpeed ~= target then
			humanoid.WalkSpeed = target
		end
	end
end)

---Close the hub and clean everything up.
local function destroyHub()
	setESP(false)
	setSpeedBoost(false)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	screenGui:Destroy()
	shared.BintangHub = nil
end

-- Config helpers.
local function listConfigs()
	local names = {}
	if not listfiles then
		return names
	end
	for _, path in ipairs(listfiles(CONFIG_FOLDER)) do
		local name = path:match("([^/\\]+)%.json$")
		if name then
			table.insert(names, name)
		end
	end
	return names
end

-- Tabs.
local infoTab = addTab("Info", true)
local exclusiveTab = addTab("Exclusive")
local survivorTab = addTab("Survivor")
local killerTab = addTab("Killer")
local espTab = addTab("ESP")
local configTab = addTab("Config")

-- Info page.
local infoBanner = create("Frame", {
	Size = UDim2.new(1, 0, 0, 150),
	BackgroundTransparency = 1,
	LayoutOrder = nextOrder(),
}, infoTab.left)
makeLogo(infoBanner, 88, UDim2.new(0.5, -44, 0, 10), 4)
makeLabel(infoBanner, {
	Position = UDim2.fromOffset(0, 106),
	Size = UDim2.new(1, 0, 0, 24),
	Text = TITLE,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
})
makeLabel(infoBanner, {
	Position = UDim2.fromOffset(0, 128),
	Size = UDim2.new(1, 0, 0, 16),
	Text = "Script Hub  |  " .. GAME_NAME,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Center,
})
addButton(infoTab.left, "COPY DISCORD", function()
	if setclipboard then
		setclipboard(DISCORD_LINK)
	end
end)
addButton(infoTab.left, "COPY TIKTOK", function()
	if setclipboard then
		setclipboard(TIKTOK_NAME)
	end
end)
addText(infoTab.left, "TIKTOK " .. TIKTOK_NAME)

-- Exclusive page.
local exclusiveSection = addSection(exclusiveTab.left, "Exclusive")
addToggle(exclusiveSection, "Auto Generator", "autoGenerator", false)
addToggle(exclusiveSection, "Auto Heal", "autoHeal", false)
addToggle(exclusiveSection, "Auto Escape", "autoEscape", false)
local exclusiveExtra = addSection(exclusiveTab.right, "Extras")
addToggle(exclusiveExtra, "Auto Skillcheck", "autoSkillcheck", false)
addToggle(exclusiveExtra, "Instant Interact", "instantInteract", false)

-- Survivor page.
local parrySection = addSection(survivorTab.left, "Auto Parry")
addToggle(parrySection, "Enable Auto Parry", "autoParry", false)
addKeybind(parrySection, "Parry Keybind", "parryKey")
addToggle(parrySection, "Anti Lag", "antiLag", true)
addToggle(parrySection, "Safety Parry", "safetyParry", true)
addToggle(parrySection, "Show Parry Radius", "showParryRadius", false)
addToggle(parrySection, "Anti Fake Hit", "antiFakeHit", true)
addSlider(parrySection, "Face Angle (Anti Fake)", "faceAngle", 0, 180, 60)
addSlider(parrySection, "Parry Radius", "parryRadius", 1, 40, 15)

local aimSection = addSection(survivorTab.right, "Silent Aim Twist of Fate")
addToggle(aimSection, "Silent Aim ToF", "silentAim", false)
addKeybind(aimSection, "ToF Keybind", "tofKey")
addToggle(aimSection, "Auto Prediction", "autoPrediction", true)
addToggle(aimSection, "Anti Zigzag", "antiZigzag", true)
addToggle(aimSection, "Enable Laser", "enableLaser", false)
addToggle(aimSection, "FOV Circle", "fovCircle", false)
addSlider(aimSection, "FOV Radius", "fovRadius", 10, 400, 200)

-- Killer page.
local killerSection = addSection(killerTab.left, "Killer")
addToggle(killerSection, "Fast Attack", "fastAttack", false)
addToggle(killerSection, "Hitbox Expander", "hitboxExpander", false)
addSlider(killerSection, "Hitbox Size", "hitboxSize", 1, 30, 5)
local killerExtra = addSection(killerTab.right, "Extras")
addToggle(killerExtra, "No Slowdown", "noSlowdown", false)
addToggle(killerExtra, "Auto Hook", "autoHook", false)

-- ESP page.
local espSection = addSection(espTab.left, "ESP Players")
addToggle(espSection, "Enable Esp", "espEnabled", false, setESP)
addToggle(espSection, "Esp Survivor", "espSurvivor", false)
addColor(espSection, "Player Color", "playerColor", function(color)
	playerColor = color
end)
addToggle(espSection, "Esp Killer", "espKiller", false)
addColor(espSection, "Killer Color", "killerColor")
addToggle(espSection, "Esp Bot / NPC", "espBot", false)
addToggle(espSection, "Mode Outline", "modeOutline", false)
addToggle(espSection, "Show Hook Count", "showHookCount", false)

local infoPlayerSection = addSection(espTab.right, "Info Player")
addToggle(infoPlayerSection, "FPS + Ping", "fpsPing", false)
addToggle(infoPlayerSection, "Next Killer", "nextKiller", false)
addToggle(infoPlayerSection, "Next Map", "nextMap", false)
addToggle(infoPlayerSection, "Stun Indicator", "stunIndicator", false)
addToggle(infoPlayerSection, "Show Killer Perks", "showKillerPerks", false)
addToggle(infoPlayerSection, "Killer Tracker UI", "killerTrackerUi", false)
addKeybind(infoPlayerSection, "Tracker Keybind", "trackerKey")
local worldSection = addSection(espTab.right, "World Effects")
addToggle(worldSection, "Fullbright", "fullbright", false)
addToggle(worldSection, "No Fog", "noFog", false)

-- Config page.
local configSection = addSection(configTab.left, "Config Manager")
local configNameBox = addInput(configSection, "Config Name", "my config")
local configDropdown = addDropdown(configSection, "Configs", listConfigs(), "none")
addText(configSection, "autoload: none")

---Pick the config name from the textbox first, then from the dropdown.
local function getConfigName()
	local name = configNameBox.Text:gsub("[^%w%-_ ]", "")
	if name ~= "" then
		return name
	end
	return configDropdown.value
end

addButton(configSection, "SAVE CONFIG", function()
	local name = getConfigName()
	if name == "none" or not writefile then
		return
	end
	writefile(CONFIG_FOLDER .. "/" .. name .. ".json", httpService:JSONEncode(values))
	configDropdown.refresh(listConfigs())
	configDropdown.set(name)
end)
addButton(configSection, "LOAD CONFIG", function()
	local path = CONFIG_FOLDER .. "/" .. getConfigName() .. ".json"
	if not isfile or not isfile(path) then
		return
	end
	local ok, data = pcall(httpService.JSONDecode, httpService, readfile(path))
	if not ok then
		return
	end
	for flag, value in pairs(data) do
		if setters[flag] then
			setters[flag](value)
		end
	end
end)
addButton(configSection, "DELETE CONFIG", function()
	local name = getConfigName()
	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	if not isfile or not isfile(path) then
		return
	end
	delfile(path)
	configDropdown.refresh(listConfigs())
	configDropdown.set("none")
end)

local miscSection = addSection(configTab.right, "Misc")
addToggle(miscSection, "Apply Korless", "applyKorless", false)
addToggle(miscSection, "Skip Endscreen", "skipEndscreen", false)
addToggle(miscSection, "Hide Name", "hideName", false)
addToggle(miscSection, "Enable Speed Boost", "speedBoost", false, setSpeedBoost)
addSlider(miscSection, "Speed Boost Value", "speedBoostValue", 1, 5, 1, function(value)
	speedValue = value
end)

-- Filter sidebar tabs by the search text.
connect(searchBox:GetPropertyChangedSignal("Text"), function()
	local query = searchBox.Text:lower()
	for _, name in ipairs(TAB_NAMES) do
		tabs[name].button.Visible = query == "" or name:lower():find(query, 1, true) ~= nil
	end
end)

-- Window controls.
local minimized = false
local expandedHeight = 312
local resizeHandle

connect(minimizeButton.MouseButton1Click, function()
	minimized = not minimized
	if minimized then
		expandedHeight = window.AbsoluteSize.Y
		window.Size = UDim2.fromOffset(window.AbsoluteSize.X, TOPBAR_HEIGHT)
	else
		window.Size = UDim2.fromOffset(window.AbsoluteSize.X, expandedHeight)
	end
	contentArea.Visible = not minimized
	sidebar.Visible = not minimized
	resizeHandle.Visible = not minimized
end)

connect(lockButton.MouseButton1Click, function()
	windowLocked = not windowLocked
	lockButton.Text = windowLocked and "🔒" or "🔓"
end)

connect(closeButton.MouseButton1Click, destroyHub)

-- Drag the window by the topbar and the sidebar header.
local function canDragWindow()
	return not windowLocked
end
makeDraggable(topBar, window, canDragWindow)
makeDraggable(sidebarHeader, window, canDragWindow)

-- Resize handle in the bottom right corner.
resizeHandle = create("TextButton", {
	Position = UDim2.new(1, -22, 1, -22),
	Size = UDim2.fromOffset(16, 16),
	BackgroundColor3 = BG,
	Text = "+",
	TextColor3 = ACCENT_SOFT,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	AutoButtonColor = false,
	ZIndex = 5,
}, main)
corner(resizeHandle, 4)
stroke(resizeHandle, ACCENT, 1)

local resizing, resizeStart, startSize = false, nil, nil
resizeHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStart = input.Position
		startSize = window.AbsoluteSize
	end
end)
connect(userInputService.InputChanged, function(input)
	if not resizing then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local delta = input.Position - resizeStart
	local width = math.clamp(startSize.X + delta.X, MIN_SIZE.X, MAX_SIZE.X)
	local height = math.clamp(startSize.Y + delta.Y, MIN_SIZE.Y, MAX_SIZE.Y)
	window.Size = UDim2.fromOffset(width, height)
end)
connect(userInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = false
	end
end)

-- Floating logo button toggles the window.
local floatingButton = create("Frame", {
	Position = UDim2.fromOffset(24, 110),
	Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1,
	Active = true,
}, screenGui)
makeLogo(floatingButton, 44, UDim2.fromOffset(0, 0), 4)
makeDraggable(floatingButton, floatingButton, nil, function()
	window.Visible = not window.Visible
end)

-- Start on the Info tab and expose the singleton.
selectTab("Info")
shared.BintangHub = { destroy = destroyHub }
