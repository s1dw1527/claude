-- PHONE: app launcher + CityBuzz social media + Messages + Map (press P).
return function(C)
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RGB = Color3.fromRGB
local new, tween, label, button, corner, stroke, gradient, clear, vlist = C.new, C.tween, C.label, C.button, C.corner, C.stroke, C.gradient, C.clear, C.vlist
local fmt, play, SND, act, gui, U, plr, catalog, R = C.fmt, C.play, C.SND, C.act, C.gui, C.U, C.plr, C.catalog, C.R
local CARD, GOLD, GREEN, GRAY, RED, BLUE, WHITE, SUB = C.CARD, C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.WHITE, C.SUB

-- phone button + badge
local pbtn = button({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(74, 74), Text = "📱", TextSize = 38, BackgroundColor3 = RGB(40, 44, 64)}, gui)
stroke(pbtn, WHITE, 2, 0.4)
local badge = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = RED, BorderSizePixel = 0, Visible = false, ZIndex = 5}, pbtn)
corner(badge, 13)
local badgeL = label({Size = UDim2.fromScale(1, 1), TextSize = 13, Font = Enum.Font.GothamBlack, ZIndex = 6}, badge)
local pLabel = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(80, 14), Text = "PHONE (P)", TextSize = 10, TextColor3 = WHITE, TextStrokeTransparency = 0.4}, pbtn)
local gear = button({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -98, 1, -16), Size = UDim2.fromOffset(46, 46), Text = "⚙️", TextSize = 22, BackgroundColor3 = RGB(60, 64, 84)}, gui)
gear.MouseButton1Click:Connect(function() play(SND.click) C.openModal("settings") end)

-- phone body
local Lay = C.Layout
local phone = new("Frame", {Name = "Phone", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -104), Size = UDim2.fromOffset(330, 600), BackgroundColor3 = RGB(12, 12, 16), BorderSizePixel = 0, Visible = false, ZIndex = Lay.Z.phone}, gui)
-- phone layout: the game darkens a little behind the phone; tapping outside the phone closes it
local dim = new("TextButton", {Name = "PhoneDim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Text = "",
	AutoButtonColor = false, Visible = false, ZIndex = Lay.Z.phoneDim}, gui)
corner(phone, 36)
stroke(phone, RGB(90, 90, 110), 3, 0)
local screen = new("Frame", {Position = UDim2.fromOffset(12, 14), Size = UDim2.new(1, -24, 1, -28), BackgroundColor3 = RGB(24, 28, 44), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 21}, phone)
corner(screen, 26)
gradient(screen, RGB(50, 60, 110), RGB(20, 22, 40))
local timeL = label({Position = UDim2.fromOffset(20, 6), Size = UDim2.fromOffset(80, 18), TextSize = 13, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22}, screen)
label({Position = UDim2.new(1, -90, 0, 6), Size = UDim2.fromOffset(74, 18), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Text = "📶 🔋", ZIndex = 22}, screen)
new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(90, 18), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 23}, screen)
local sc = new("UIScale", {}, phone)
-- phone layout: a clear ✕ on the phone itself
local closeX = button({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 15), Size = UDim2.fromOffset(38, 28), Text = "X", TextSize = 17, BackgroundColor3 = RED, ZIndex = 40, Visible = false}, phone)

local views = {}
-- what to run when a view opens. (Kept in a Lua table: Roblox doesn't allow custom fields on Instances, so
-- "frame.refresh = fn" throws an error in a real game. Until v8 that error stopped this whole module halfway,
-- which is why Messages, the Map and new CityBuzz posts never worked in Studio.)
local refreshers = {}
local current = "home"
local function makeView(name)
	local v = new("Frame", {Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1, Visible = false, ZIndex = 22}, screen)
	views[name] = v
	return v
end
local function topBar(v, title, color)
	local b = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 23}, v)
	label({Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -54, 1, 0), Text = title, TextSize = 17, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24}, b)
	local back = button({Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(32, 30), Text = "‹", TextSize = 22, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 24}, b)
	back.BackgroundTransparency = 0.7
	back.MouseButton1Click:Connect(function()
		play(SND.click)
		C.phoneView("home")
	end)
	return b
end
local function scroller(v, top)
	local s = new("ScrollingFrame", {Position = UDim2.fromOffset(4, top), Size = UDim2.new(1, -8, 1, -top - 4), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22}, v)
	vlist(s, 6)
	return s
end
-- other modules (Story) add their own apps with these
C.phoneKit = {makeView = makeView, topBar = topBar, scroller = scroller, onOpen = function(name, fn) refreshers[name] = fn end}
function C.phoneView(name)
	current = name
	for n, v in pairs(views) do v.Visible = n == name end
	if refreshers[name] then refreshers[name]() end
end
-- the phone is 600px tall: shrink it on short screens so it always fits.
-- v11.1 phone layout: a real phone-sized phone, centred: ~82% of the screen wide and ~78% tall (clamped so it
-- never leaves the screen), at full text size. In landscape (no room for 500 px) it scales down as a whole.
local function fitScale()
	if Lay.compact then
		local a = Lay.win
		local w = math.min(math.clamp(Lay.vp.X * 0.82, 280, 420), a.w)
		local h = math.min(math.clamp(Lay.vp.Y * 0.78, 500, 760), a.h)
		phone.AnchorPoint = Vector2.new(0.5, 0.5)
		phone.Position = UDim2.fromOffset(a.x + a.w / 2, a.y + a.h / 2)
		if h >= 500 then
			phone.Size = UDim2.fromOffset(w, h)
			return 1
		end
		phone.Size = UDim2.fromOffset(330, 600)
		return math.max(0.4, math.min(a.h / 600, a.w / 330))
	end
	phone.Size = UDim2.fromOffset(330, 600)
	phone.AnchorPoint = Vector2.new(1, 1)
	phone.Position = C.touchLift and UDim2.new(1, -16, 1, -16) or UDim2.new(1, -16, 1, -104)
	local cam = game:GetService("Workspace").CurrentCamera
	local h = cam and cam.ViewportSize.Y or 800
	return math.clamp((h - 130) / 600, 0.5, 1)
end
function C.togglePhone(force)
	local open = force
	if open == nil then open = not phone.Visible end
	if open then
		C.closeModals()
		local fit = fitScale()
		sc.Scale = 0.7 * fit
		phone.Visible = true
		tween(sc, 0.25, {Scale = fit}, Enum.EasingStyle.Back)
		C.phoneView("home")
	else
		phone.Visible = false
	end
	play(SND.click)
end
-- the dim, the ✕ and the HUD (which steps aside: see Layout) follow the phone however it opens or closes
phone:GetPropertyChangedSignal("Visible"):Connect(function()
	dim.Visible = phone.Visible and Lay.compact
	closeX.Visible = Lay.compact
end)
dim.MouseButton1Click:Connect(function() C.togglePhone(false) end)
closeX.MouseButton1Click:Connect(function() C.togglePhone(false) end)
Lay.major("phone", phone, {close = function() phone.Visible = false end})
-- tell the server whenever the phone opens or closes, however it happened (button, P, controller, an app
-- closing it, photo mode). The tutorial's "open your phone" step checks this, so it can't be missed.
local function reportPhone()
	if C.S and C.S.tut then act("tut", "phone", phone.Visible) end
end
phone:GetPropertyChangedSignal("Visible"):Connect(reportPhone)
C.reportPhone = reportPhone
C.phoneOpen = function() return phone.Visible end
pbtn.MouseButton1Click:Connect(function() C.togglePhone() end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not C.gui.Enabled then return end
	-- keyboard: P   •   controller: Y
	if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.ButtonY then C.togglePhone() end
end)
-- touch screens: Roblox's jump button sits in the bottom-right corner, right on top of the phone button.
-- Lift the phone, settings and camera buttons above it so a tap opens the phone instead of jumping.
if UserInputService.TouchEnabled then
	pbtn.Position = UDim2.new(1, -16, 1, -170)
	gear.Position = UDim2.new(1, -98, 1, -170)
	phone.Position = UDim2.new(1, -16, 1, -16)
	C.touchLift = 154
end
-- v11.1 phone layout: one column on the right edge, just above Roblox's jump button: ⚙️ above 📱
pbtn.Name, gear.Name = "PhoneButton", "SettingsButton"
Lay.slot(pbtn, "right", 3, {size = UDim2.fromOffset(52, 52), onCompact = function(c)
	pLabel.Visible = not c
	pbtn.TextSize = c and 28 or 38
end})
Lay.slot(gear, "right", 2, {size = UDim2.fromOffset(44, 44), onCompact = function(c) gear.TextSize = c and 20 or 22 end})
Lay.onChange(function()
	local fit = fitScale()
	if phone.Visible then sc.Scale = fit end
	dim.Visible = phone.Visible and Lay.compact
	closeX.Visible = Lay.compact
end)

-- ===== HOME SCREEN =====
do
	local v = makeView("home")
	label({Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 44), TextSize = 40, Font = Enum.Font.GothamBlack, Text = "12:00", ZIndex = 23, Name = "BigClock"}, v)
	label({Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = SUB, Text = "Corner Empire OS", ZIndex = 23}, v)
	-- (scrolls when the phone is shorter than the app grid — phone layout, landscape)
	local grid = new("ScrollingFrame", {Position = UDim2.fromOffset(10, 84), Size = UDim2.new(1, -20, 1, -94), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 22,
		ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y}, v)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(62, 72), CellPadding = UDim2.fromOffset(8, 3), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	local APPS = {
		{"📱", "Buzz", "view", "buzz", RGB(230, 70, 150)}, {"💬", "Messages", "view", "messages", RGB(60, 190, 90)}, {"🗺️", "Map", "view", "map", RGB(60, 140, 230)},
		{"🏠", "Home", "modal", "home", RGB(110, 180, 110)}, {"🚗", "Garage", "modal", "garage", RGB(60, 130, 230), "cars"}, {"👥", "Staff", "modal", "staff", RGB(70, 170, 120), "staff"},
		{"🏢", "Properties", "modal", "properties", RGB(120, 150, 240), "properties"}, {"📈", "Stocks", "modal", "market", RGB(60, 160, 90), "market"}, {"📣", "Marketing", "modal", "marketing", RGB(235, 130, 40), "ads"},
		{"🎡", "Fun & Race", "modal", "fun", RGB(255, 110, 190), "funpark"}, {"♻️", "Rebirth", "modal", "rebirth", RGB(200, 80, 220)}, {"🏙️", "City", "modal", "city", RGB(60, 150, 200)},
		{"📖", "Archive", "modal", "archive", RGB(140, 90, 230)}, {"🛒", "Store", "modal", "passes", RGB(235, 170, 30)}, {"🏆", "Weekly", "modal", "weekly", RGB(230, 150, 40)},
		{"🎬", "Story", "view", "story", RGB(200, 50, 120)}, {"🔥", "Viral", "view", "viral", RGB(255, 90, 60)}, {"🏛️", "HQ", "modal", "hq", RGB(90, 120, 200)}, {"👑", "Empire", "modal", "empireHall", RGB(210, 160, 30)}, {"🧭", "Explore", "modal", "explore", RGB(40, 170, 140)}, {"🍿", "Theater", "modal", "theater", RGB(200, 40, 60)}, {"🔔", "Activity", "modal", "activity", RGB(230, 90, 100)}, {"🕹️", "Arcade", "modal", "arcadeInfo", RGB(150, 80, 255)}, {"💰", "Heists", "modal", "heists", RGB(40, 40, 46)},
		{"⚙️", "Settings", "modal", "settings", RGB(100, 104, 124)},
	}
	local icons = {}
	for i, a in ipairs(APPS) do
		local cell = new("Frame", {BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 22}, grid)
		local b = button({Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(3, 0), Text = a[1], TextSize = 28, BackgroundColor3 = a[5], ZIndex = 23}, cell)
		corner(b, 14)
		label({Position = UDim2.fromOffset(-6, 58), Size = UDim2.new(1, 12, 0, 16), Text = a[2], TextSize = 11, ZIndex = 23}, cell)
		local lock = label({Size = UDim2.fromScale(1, 1), Text = "🔒", TextSize = 24, Visible = false, ZIndex = 25}, b)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			if a[6] and C.locked(a[6]) then
				U.toast(C.lockText(a[6]))
				return
			end
			if a[3] == "view" then
				C.phoneView(a[4])
			else
				phone.Visible = false
				C.openModal(a[4])
			end
		end)
		icons[i] = {lock = lock, btn = b, feature = a[6]}
	end
	C.onState(function()
		for _, ic in ipairs(icons) do
			local l = ic.feature and C.locked(ic.feature)
			ic.lock.Visible = l
			ic.btn.TextTransparency = l and 0.7 or 0
		end
	end)
	task.spawn(function()
		while true do
			local t = Lighting.ClockTime
			local txt = string.format("%d:%02d", math.floor(t), math.floor((t % 1) * 60))
			timeL.Text = txt
			local bc = v:FindFirstChild("BigClock")
			if bc then bc.Text = txt end
			task.wait(1)
		end
	end)
end

-- ===== CITYBUZZ =====
-- post text and/or a card built from your real empire (business, house, car, empire, or a Photo Mode shot);
-- like and react to other people's posts; Latest / Trending tabs
do
	local v = makeView("buzz")
	topBar(v, "📱 CityBuzz", RGB(200, 50, 130))
	local prof = new("Frame", {Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 0, 192), BackgroundColor3 = CARD, BorderSizePixel = 0, ZIndex = 22}, v)
	corner(prof, 12)
	label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Text = "@" .. plr.Name}, prof)
	local pStats = label({Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, prof)
	local box = new("TextBox", {Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -76, 0, 32), BackgroundColor3 = RGB(18, 20, 30), TextColor3 = WHITE, PlaceholderText = "What's happening in your empire?",
		PlaceholderColor3 = SUB, Text = "", TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, BorderSizePixel = 0}, prof)
	corner(box, 8)
	new("UIPadding", {PaddingLeft = UDim.new(0, 6)}, box)
	local send = button({Position = UDim2.new(1, -64, 0, 42), Size = UDim2.fromOffset(56, 32), Text = "Post", TextSize = 13, BackgroundColor3 = RGB(230, 70, 150), ZIndex = 23}, prof)
	-- attach a card: one at a time, tap again to remove
	local ATTACH = {{"business", "🏪 Business"}, {"house", "🏠 House"}, {"car", "🚗 Car"}, {"empire", "👑 Empire"}, {"photo", "📸 Photo"}}
	local attach
	local attachRow = new("Frame", {Position = UDim2.fromOffset(8, 78), Size = UDim2.new(1, -16, 0, 26), BackgroundTransparency = 1, ZIndex = 23}, prof)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3)}, attachRow)
	local chips = {}
	local function paintChips()
		for key, b in pairs(chips) do b.BackgroundColor3 = attach == key and RGB(230, 70, 150) or RGB(60, 64, 84) end
	end
	for _, a in ipairs(ATTACH) do
		local b = button({Size = UDim2.fromOffset(54, 26), Text = a[2], TextSize = 9, TextWrapped = true, BackgroundColor3 = RGB(60, 64, 84), ZIndex = 24}, attachRow)
		chips[a[1]] = b
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			attach = attach ~= a[1] and a[1] or nil
			paintChips()
		end)
	end
	C.composePost = function(kind)
		attach = kind
		paintChips()
		if C.togglePhone then C.togglePhone(true) C.phoneView("buzz") end
	end
	send.MouseButton1Click:Connect(function()
		if #box.Text > 0 or attach then
			play(SND.click)
			act("post", nil, box.Text, attach)
			box.Text = ""
			attach = nil
			paintChips()
		end
	end)
	local PRESETS = {"📣 Promote", "⭐ Rep", "📈 Income", "🏁 Race me", "🏠 My home", "🧑‍🍳 Hiring", "🎡 Fun Park"}
	local pr = new("ScrollingFrame", {Position = UDim2.fromOffset(8, 108), Size = UDim2.new(1, -16, 0, 34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 23}, prof)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, pr)
	for i = 1, math.min(#PRESETS, catalog.presets or #PRESETS) do
		local b = button({Size = UDim2.fromOffset(78, 28), Text = PRESETS[i], TextSize = 10, BackgroundColor3 = RGB(90, 60, 140), ZIndex = 24}, pr)
		b.MouseButton1Click:Connect(function() play(SND.click) act("post", i, nil, attach) end)
	end
	-- achievements waiting to be shared
	local shareRow = new("ScrollingFrame", {Position = UDim2.fromOffset(8, 152), Size = UDim2.new(1, -16, 0, 32), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 23}, prof)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, shareRow)
	local shareKey = ""
	C.onState(function(s)
		local list = s.shareable or {}
		local keys = {}
		for _, a in ipairs(list) do table.insert(keys, a.key) end
		local k = table.concat(keys, ",")
		if k == shareKey then return end
		shareKey = k
		clear(shareRow)
		if #list == 0 then
			label({Size = UDim2.fromOffset(250, 28), Text = "🏆 Unlock achievements to share them here", TextSize = 10, TextColor3 = SUB, ZIndex = 24}, shareRow)
		end
		for _, a in ipairs(list) do
			local b = button({Size = UDim2.fromOffset(120, 28), Text = "🏆 " .. a.icon .. " " .. a.title, TextSize = 10, TextWrapped = true, BackgroundColor3 = RGB(190, 140, 30), ZIndex = 24}, shareRow)
			b.MouseButton1Click:Connect(function() play(SND.click) act("shareAch", a.key) end)
		end
	end)
	-- Latest / Trending
	local tabRow = new("Frame", {Position = UDim2.fromOffset(6, 240), Size = UDim2.new(1, -12, 0, 26), BackgroundTransparency = 1, ZIndex = 22}, v)
	local mode = "latest"
	local tabs = {}
	local feed = scroller(v, 270)
	local posts = {}
	local liked = {}
	local reacted = {}
	local cards = {}
	local function ago(t)
		local sec = math.max(0, os.time() - (t or os.time()))
		if sec < 60 then return "now" end
		if sec < 3600 then return math.floor(sec / 60) .. "m" end
		return math.floor(sec / 3600) .. "h"
	end
	local function score(p)
		local r = p.reactions or {}
		return (p.likes or 0) + 2 * ((r.fire or 0) + (r.laugh or 0) + (r.wow or 0)) + (p.views or 0) * 0.2
	end
	local function render()
		clear(feed)
		cards = {}
		local list = posts
		if mode == "trending" then
			list = {}
			for _, p in ipairs(posts) do
				if p.authorId ~= 0 and os.time() - (p.t or 0) < 1800 then table.insert(list, p) end
			end
			table.sort(list, function(a, b) return score(a) > score(b) end)
		end
		if #list == 0 then
			label({Size = UDim2.new(1, 0, 0, 40), Text = mode == "trending" and "Nothing trending yet. Post something!" or "No posts yet.", TextSize = 12, TextColor3 = SUB, ZIndex = 23}, feed)
		end
		for i = 1, math.min(25, #list) do
			local p = list[i]
			local c = new("Frame", {Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 22}, feed)
			corner(c, 10)
			new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, c)
			local lay = vlist(c, 4)
			lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
			local author = p.author == "CityBuzz" and "📰 CityBuzz News" or ((p.achievement and "🏆 " or "👤 ") .. p.author .. (p.empire and ("  •  " .. p.empire) or ""))
			if p.author ~= "CityBuzz" and p.author ~= "Corner Gazette" and not p.empire then author = "📰 " .. p.author end
			label({Size = UDim2.new(1, 0, 0, 16), Text = author .. "  •  " .. ago(p.t), TextSize = 10, TextColor3 = SUB, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23, LayoutOrder = 1}, c)
			if p.text and p.text ~= "" then
				local body = label({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = (p.card and "" or (p.icon .. " ")) .. p.text, TextSize = 13,
					TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = p.color, ZIndex = 23, LayoutOrder = 2}, c)
				body.Font = Enum.Font.GothamMedium
			end
			if p.card then
				local cd = new("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = RGB(24, 26, 38), BorderSizePixel = 0, ZIndex = 23, LayoutOrder = 3}, c)
				corner(cd, 8)
				label({Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(40, 44), Text = p.card.icon or "📸", TextSize = 28, ZIndex = 24}, cd)
				label({Position = UDim2.fromOffset(50, 6), Size = UDim2.new(1, -56, 0, 18), Text = p.card.title or "", TextSize = 13, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 24}, cd)
				label({Position = UDim2.fromOffset(50, 26), Size = UDim2.new(1, -56, 0, 20), Text = (p.card.stars and p.card.stars > 0 and (C.stars(p.card.stars) .. "  ") or "") .. (p.card.sub or ""),
					TextSize = 10, TextWrapped = true, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24}, cd)
			end
			local row = new("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, ZIndex = 23, LayoutOrder = 4}, c)
			new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, row)
			local mine = p.authorId == plr.UserId
			local lk = button({Size = UDim2.fromOffset(62, 22), TextSize = 11, ZIndex = 24, BackgroundColor3 = liked[p.id] and RGB(230, 70, 120) or RGB(60, 64, 84), Text = "❤ " .. fmt(p.likes)}, row)
			lk.MouseButton1Click:Connect(function()
				if liked[p.id] or mine then return end
				liked[p.id] = true
				play(SND.click)
				act("like", p.id)
				lk.BackgroundColor3 = RGB(230, 70, 120)
			end)
			local rb = {}
			for _, rk in ipairs({{"fire", "🔥"}, {"laugh", "😂"}, {"wow", "😮"}}) do
				local key = p.id .. rk[1]
				local b = button({Size = UDim2.fromOffset(42, 22), TextSize = 11, ZIndex = 24, BackgroundColor3 = reacted[key] and RGB(230, 120, 40) or RGB(60, 64, 84),
					Text = rk[2] .. " " .. ((p.reactions and p.reactions[rk[1]]) or 0)}, row)
				b.MouseButton1Click:Connect(function()
					if reacted[key] or mine then return end
					reacted[key] = true
					play(SND.click)
					act("react", p.id, rk[1])
					b.BackgroundColor3 = RGB(230, 120, 40)
				end)
				rb[rk[1]] = {b = b, icon = rk[2]}
			end
			local vw = label({Size = UDim2.fromOffset(46, 22), TextSize = 10, TextColor3 = SUB, Text = "👁 " .. fmt(p.views or 0), ZIndex = 24}, row)
			cards[p.id] = {lk = lk, rb = rb, vw = vw}
		end
	end
	for i, t in ipairs({{"latest", "🆕 Latest"}, {"trending", "🔥 Trending"}}) do
		local b = button({Position = UDim2.new((i - 1) / 2, 2, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Text = t[2], TextSize = 12, BackgroundColor3 = i == 1 and RGB(200, 50, 130) or RGB(60, 64, 84), ZIndex = 23}, tabRow)
		tabs[t[1]] = b
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			mode = t[1]
			for k, tb in pairs(tabs) do tb.BackgroundColor3 = k == mode and RGB(200, 50, 130) or RGB(60, 64, 84) end
			render()
		end)
	end
	local function fetch()
		local ok, list = pcall(function() return C.GetCatalog:InvokeServer("feed") end)
		if ok and type(list) == "table" then posts = list end
	end
	fetch()
	refreshers.buzz = function()
		fetch()
		render()
	end
	R.Buzz.OnClientEvent:Connect(function(p)
		table.insert(posts, 1, p)
		if #posts > 40 then table.remove(posts) end
		if U.ticker then U.ticker.Text = "📱 CITYBUZZ: " .. p.icon .. " " .. p.text end
		-- phone layout: a 4-second notification instead of the ticker (not while you're reading the feed)
		if U.buzzNote and not (phone.Visible and current == "buzz") then U.buzzNote(p) end
		if phone.Visible and current == "buzz" then render() end
	end)
	R.BuzzUpdate.OnClientEvent:Connect(function(id, likes, reactions, views)
		for _, p in ipairs(posts) do
			if p.id == id then p.likes, p.reactions, p.views = likes, reactions or p.reactions, views or p.views end
		end
		local cd = cards[id]
		if cd then
			cd.lk.Text = "❤ " .. fmt(likes)
			for k, e in pairs(cd.rb) do e.b.Text = e.icon .. " " .. ((reactions and reactions[k]) or 0) end
			if views then cd.vw.Text = "👁 " .. fmt(views) end
		end
	end)
	if posts[1] and U.ticker then U.ticker.Text = "📱 CITYBUZZ: " .. posts[1].icon .. " " .. posts[1].text end
	if U.buzzSeed then U.buzzSeed(posts) end   -- (v11.3: the phone layout's small CityBuzz feed starts with the latest posts)
	C.onState(function(s)
		pStats.Text = fmt(s.followers) .. " followers  •  +" .. math.floor(math.min(50, s.followers / 20)) .. "% customers from fans"
	end)
end

-- ===== MESSAGES =====
-- an inbox (newest first, unread dot, time) and a message view; opening a message marks it read on the server
do
	local v = makeView("messages")
	local bar = topBar(v, "💬 Messages", RGB(40, 150, 70))
	local allRead = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(84, 26), Text = "✓ All read", TextSize = 11,
		BackgroundColor3 = RGB(30, 110, 50), ZIndex = 24}, bar)
	local list = scroller(v, 44)
	-- the open message
	local detail = new("Frame", {Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundColor3 = RGB(24, 28, 44), BorderSizePixel = 0, Visible = false, ZIndex = 30}, v)
	local dBack = button({Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(70, 26), Text = "‹ Inbox", TextSize = 12, BackgroundColor3 = GRAY, ZIndex = 31}, detail)
	local dFrom = label({Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 20), TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31}, detail)
	local dTime = label({Position = UDim2.fromOffset(10, 58), Size = UDim2.new(1, -20, 0, 14), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31}, detail)
	local dScroll = new("ScrollingFrame", {Position = UDim2.fromOffset(6, 78), Size = UDim2.new(1, -12, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 31}, detail)
	local dLay = vlist(dScroll, 8)
	dLay.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local msgs = {}
	local openId
	C.unread = 0
	local CAT_COLOR = {staff = RGB(70, 170, 120), customer = RGB(230, 150, 60), tenant = RGB(120, 150, 240), rival = RGB(220, 70, 80), story = RGB(255, 70, 140),
		cityhall = RGB(255, 205, 70), event = RGB(255, 110, 200), investor = RGB(90, 200, 120), business = RGB(110, 120, 150), system = RGB(120, 220, 255)}
	local function ago(t)
		if not t or t == 0 then return "" end
		local s = math.max(0, os.time() - t)
		if s < 60 then return "just now" end
		if s < 3600 then return math.floor(s / 60) .. "m ago" end
		if s < 86400 then return math.floor(s / 3600) .. "h ago" end
		return math.floor(s / 86400) .. "d ago"
	end
	local function setBadge(n)
		C.unread = n or 0
		badge.Visible = C.unread > 0
		badgeL.Text = tostring(math.min(99, C.unread))
	end
	local render
	local function openMsg(m)
		openId = m.id
		detail.Visible = true
		clear(dScroll)
		dFrom.Text = (m.icon or "💬") .. "  " .. (m.from or "")
		dFrom.TextColor3 = CAT_COLOR[m.cat] or WHITE
		dTime.Text = ago(m.t) .. (m.important and "  •  ⭐ saved" or "")
		local body = label({Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = m.text or "", TextSize = 14, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 32, LayoutOrder = 1}, dScroll)
		body.Font = Enum.Font.GothamMedium
		if m.resolved then
			label({Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "➡️ " .. m.resolved, TextSize = 13, TextWrapped = true, TextColor3 = GOLD,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32, LayoutOrder = 2}, dScroll)
		elseif m.choices then
			local cols = {GRAY, RGB(235, 160, 30), RED}
			for k, ch in ipairs(m.choices) do
				local b = button({Size = UDim2.new(1, -8, 0, 32), Text = ch, TextSize = 12, TextWrapped = true, BackgroundColor3 = cols[k] or BLUE, ZIndex = 32, LayoutOrder = 2 + k}, dScroll)
				b.MouseButton1Click:Connect(function()
					play(SND.click)
					act("msgChoice", m.id, k)
				end)
			end
		end
		if not m.read then
			m.read = true
			act("msgRead", m.id)
			render()
		end
	end
	dBack.MouseButton1Click:Connect(function()
		play(SND.click)
		detail.Visible = false
		openId = nil
	end)
	allRead.MouseButton1Click:Connect(function()
		play(SND.click)
		for _, m in ipairs(msgs) do m.read = true end
		act("msgRead", "all")
		render()
	end)
	render = function()
		clear(list)
		if #msgs == 0 then
			label({Size = UDim2.new(1, 0, 0, 60), Text = "No messages yet.\nYour staff, tenants, customers and rivals will text you here.", TextSize = 12, TextWrapped = true, TextColor3 = SUB, ZIndex = 23}, list)
		end
		for i, m in ipairs(msgs) do
			local c = new("TextButton", {Size = UDim2.new(1, -6, 0, 54), BackgroundColor3 = m.read and CARD or RGB(44, 52, 76), BorderSizePixel = 0, LayoutOrder = i, ZIndex = 22,
				Text = "", AutoButtonColor = true}, list)
			corner(c, 10)
			new("Frame", {Position = UDim2.fromOffset(0, 8), Size = UDim2.new(0, 4, 1, -16), BackgroundColor3 = CAT_COLOR[m.cat] or GRAY, BorderSizePixel = 0, ZIndex = 23}, c)
			label({Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(30, 46), Text = m.icon or "💬", TextSize = 22, ZIndex = 23}, c)
			label({Position = UDim2.fromOffset(44, 4), Size = UDim2.new(1, -110, 0, 18), Text = m.from or "", TextSize = 12, Font = m.read and Enum.Font.GothamBold or Enum.Font.GothamBlack,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = CAT_COLOR[m.cat] or WHITE, ZIndex = 23}, c)
			label({Position = UDim2.new(1, -66, 0, 4), Size = UDim2.fromOffset(58, 18), Text = ago(m.t), TextSize = 10, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23}, c)
			label({Position = UDim2.fromOffset(44, 24), Size = UDim2.new(1, -60, 0, 26), Text = m.text or "", TextSize = 11, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = m.read and SUB or WHITE, ZIndex = 23}, c)
			if not m.read then
				local dot = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.6, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = RGB(80, 160, 255), BorderSizePixel = 0, ZIndex = 24}, c)
				corner(dot, 5)
			end
			if m.choices and not m.resolved then
				label({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -2), Size = UDim2.fromOffset(90, 14), Text = "needs an answer", TextSize = 9, TextColor3 = GOLD,
					TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 24}, c)
			end
			c.MouseButton1Click:Connect(function()
				play(SND.click)
				openMsg(m)
			end)
		end
	end
	refreshers.messages = function()
		detail.Visible = false
		openId = nil
		render()
	end
	C.openMessages = function() if C.togglePhone then C.togglePhone(true) C.phoneView("messages") end end
	local function load()
		local ok, list2 = pcall(function() return C.GetCatalog:InvokeServer("inbox") end)
		if ok and type(list2) == "table" then
			-- merge: a message that arrived while this request was on its way must not be dropped
			local have = {}
			for _, m in ipairs(list2) do have[m.id] = true end
			for _, m in ipairs(msgs) do if not have[m.id] then table.insert(list2, m) end end
			table.sort(list2, function(x, y) return (x.id or 0) > (y.id or 0) end)
			msgs = list2
		end
		local n = 0
		for _, m in ipairs(msgs) do if not m.read then n += 1 end end
		setBadge(n)
	end
	C.reloadInbox = load
	R.Msg.OnClientEvent:Connect(function(kind, a, b, c2)
		if kind == "add" then
			table.insert(msgs, 1, a)
			if #msgs > 50 then table.remove(msgs) end
			setBadge(b or C.unread + 1)
			-- a subtle nudge: the phone button wiggles, and a short toast if the phone is closed
			if not (phone.Visible and current == "messages") then
				tween(pbtn, 0.1, {Rotation = 12})
				task.delay(0.1, function() tween(pbtn, 0.2, {Rotation = 0}, Enum.EasingStyle.Back) end)
				if U.toast and not (C.storyCutscene and C.storyCutscene()) then U.toast("💬 " .. (a.from or "New message")) end
			end
			play(SND.msg)
		elseif kind == "resolve" then
			for _, m in ipairs(msgs) do
				if m.id == a then m.resolved, m.choices, m.read = b, nil, true end
			end
			if c2 then setBadge(c2) end
			if openId == a then
				for _, m in ipairs(msgs) do if m.id == a then openMsg(m) end end
			end
		elseif kind == "unread" then
			setBadge(a)
		end
		if phone.Visible and current == "messages" and not detail.Visible then render() end
	end)
end

-- (the Map app lives in its own module: MapApp)
C.phoneFrame = phone
C.phoneView("home")
end
