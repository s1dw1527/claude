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
label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(80, 14), Text = "PHONE (P)", TextSize = 10, TextColor3 = WHITE, TextStrokeTransparency = 0.4}, pbtn)
local gear = button({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -98, 1, -16), Size = UDim2.fromOffset(46, 46), Text = "⚙️", TextSize = 22, BackgroundColor3 = RGB(60, 64, 84)}, gui)
gear.MouseButton1Click:Connect(function() play(SND.click) C.openModal("settings") end)

-- phone body
local phone = new("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -104), Size = UDim2.fromOffset(330, 600), BackgroundColor3 = RGB(12, 12, 16), BorderSizePixel = 0, Visible = false, ZIndex = 20}, gui)
corner(phone, 36)
stroke(phone, RGB(90, 90, 110), 3, 0)
local screen = new("Frame", {Position = UDim2.fromOffset(12, 14), Size = UDim2.new(1, -24, 1, -28), BackgroundColor3 = RGB(24, 28, 44), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 21}, phone)
corner(screen, 26)
gradient(screen, RGB(50, 60, 110), RGB(20, 22, 40))
local timeL = label({Position = UDim2.fromOffset(20, 6), Size = UDim2.fromOffset(80, 18), TextSize = 13, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22}, screen)
label({Position = UDim2.new(1, -90, 0, 6), Size = UDim2.fromOffset(74, 18), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Text = "📶 🔋", ZIndex = 22}, screen)
new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(90, 18), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 23}, screen)
local sc = new("UIScale", {}, phone)

local views = {}
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
function C.phoneView(name)
	current = name
	for n, v in pairs(views) do v.Visible = n == name end
	if name == "messages" then
		C.unread = 0
		badge.Visible = false
	end
	if views[name] and views[name].refresh then views[name].refresh() end
end
function C.togglePhone(force)
	local open = force
	if open == nil then open = not phone.Visible end
	if open then
		C.closeModals()
		phone.Visible = true
		sc.Scale = 0.7
		tween(sc, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
		C.phoneView("home")
		act("tut", "phone")
	else
		phone.Visible = false
	end
	play(SND.click)
end
pbtn.MouseButton1Click:Connect(function() C.togglePhone() end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.P and C.gui.Enabled then C.togglePhone() end
end)

-- ===== HOME SCREEN =====
do
	local v = makeView("home")
	label({Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 44), TextSize = 40, Font = Enum.Font.GothamBlack, Text = "12:00", ZIndex = 23, Name = "BigClock"}, v)
	label({Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = SUB, Text = "Corner Empire OS", ZIndex = 23}, v)
	local grid = new("Frame", {Position = UDim2.fromOffset(10, 84), Size = UDim2.new(1, -20, 1, -94), BackgroundTransparency = 1, ZIndex = 22}, v)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(62, 78), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	local APPS = {
		{"📱", "Buzz", "view", "buzz", RGB(230, 70, 150)}, {"💬", "Messages", "view", "messages", RGB(60, 190, 90)}, {"🗺️", "Map", "view", "map", RGB(60, 140, 230)},
		{"🏠", "Home", "modal", "home", RGB(110, 180, 110)}, {"🚗", "Garage", "modal", "garage", RGB(60, 130, 230), "cars"}, {"👥", "Staff", "modal", "staff", RGB(70, 170, 120), "staff"},
		{"🏢", "Properties", "modal", "properties", RGB(120, 150, 240), "properties"}, {"📈", "Stocks", "modal", "market", RGB(60, 160, 90), "market"}, {"📣", "Marketing", "modal", "marketing", RGB(235, 130, 40), "ads"},
		{"🎡", "Fun & Race", "modal", "fun", RGB(255, 110, 190), "funpark"}, {"♻️", "Rebirth", "modal", "rebirth", RGB(200, 80, 220)}, {"🏙️", "City", "modal", "city", RGB(60, 150, 200)},
		{"📖", "Archive", "modal", "archive", RGB(140, 90, 230)}, {"🛒", "Store", "modal", "passes", RGB(235, 170, 30)}, {"🏆", "Weekly", "modal", "weekly", RGB(230, 150, 40)},
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
do
	local v = makeView("buzz")
	topBar(v, "📱 CityBuzz", RGB(200, 50, 130))
	local prof = new("Frame", {Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 0, 156), BackgroundColor3 = CARD, BorderSizePixel = 0, ZIndex = 22}, v)
	corner(prof, 12)
	local pName = label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Text = "@" .. plr.Name}, prof)
	local pStats = label({Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, prof)
	local box = new("TextBox", {Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -76, 0, 32), BackgroundColor3 = RGB(18, 20, 30), TextColor3 = WHITE, PlaceholderText = "What's happening in your empire?",
		PlaceholderColor3 = SUB, Text = "", TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, BorderSizePixel = 0}, prof)
	corner(box, 8)
	new("UIPadding", {PaddingLeft = UDim.new(0, 6)}, box)
	local send = button({Position = UDim2.new(1, -64, 0, 42), Size = UDim2.fromOffset(56, 32), Text = "Post", TextSize = 13, BackgroundColor3 = RGB(230, 70, 150), ZIndex = 23}, prof)
	send.MouseButton1Click:Connect(function()
		if #box.Text > 0 then
			play(SND.click)
			act("post", nil, box.Text)
			box.Text = ""
		end
	end)
	local PRESETS = {"📣 Promote", "⭐ Rep", "📈 Income", "🏁 Race me", "🏠 My home", "🧑‍🍳 Hiring", "🎡 Fun Park"}
	local pr = new("ScrollingFrame", {Position = UDim2.fromOffset(8, 80), Size = UDim2.new(1, -16, 0, 34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 23}, prof)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, pr)
	for i = 1, math.min(#PRESETS, catalog.presets or #PRESETS) do
		local b = button({Size = UDim2.fromOffset(78, 28), Text = PRESETS[i], TextSize = 10, BackgroundColor3 = RGB(90, 60, 140), ZIndex = 24}, pr)
		b.MouseButton1Click:Connect(function() play(SND.click) act("post", i) end)
	end
	-- achievements waiting to be shared
	local shareRow = new("ScrollingFrame", {Position = UDim2.fromOffset(8, 118), Size = UDim2.new(1, -16, 0, 32), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
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
	local feed = scroller(v, 206)
	local posts = {}
	local liked = {}
	local ok, list = pcall(function() return C.GetCatalog:InvokeServer("feed") end)
	if ok and type(list) == "table" then posts = list end
	local cards = {}
	local function render()
		clear(feed)
		cards = {}
		for i = 1, math.min(25, #posts) do
			local p = posts[i]
			local c = new("Frame", {Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 22}, feed)
			corner(c, 10)
			new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 30), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, c)
			local author = p.author == "CityBuzz" and "📰 CityBuzz News" or ((p.achievement and "🏆 @" or "👤 @") .. p.author)
			label({Size = UDim2.new(1, 0, 0, 16), Text = author, TextSize = 11, TextColor3 = SUB, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, c)
			local body = label({Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = p.icon .. " " .. p.text, TextSize = 13,
				TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = p.color, ZIndex = 23}, c)
			body.Font = Enum.Font.GothamMedium
			local lk = button({AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 26), Size = UDim2.fromOffset(78, 22), TextSize = 12, ZIndex = 24,
				BackgroundColor3 = liked[p.id] and RGB(230, 70, 120) or RGB(60, 64, 84), Text = "❤ " .. fmt(p.likes)}, c)
			lk.MouseButton1Click:Connect(function()
				if liked[p.id] then return end
				liked[p.id] = true
				play(SND.click)
				act("like", p.id)
				lk.BackgroundColor3 = RGB(230, 70, 120)
			end)
			cards[p.id] = lk
		end
	end
	v.refresh = render
	R.Buzz.OnClientEvent:Connect(function(p)
		table.insert(posts, 1, p)
		if #posts > 40 then table.remove(posts) end
		if U.ticker then U.ticker.Text = "📱 CITYBUZZ: " .. p.icon .. " " .. p.text end
		if phone.Visible and current == "buzz" then render() end
	end)
	R.BuzzUpdate.OnClientEvent:Connect(function(id, likes)
		for _, p in ipairs(posts) do
			if p.id == id then p.likes = likes end
		end
		local lk = cards[id]
		if lk then lk.Text = "❤ " .. fmt(likes) end
	end)
	if posts[1] and U.ticker then U.ticker.Text = "📱 CITYBUZZ: " .. posts[1].icon .. " " .. posts[1].text end
	C.onState(function(s)
		pStats.Text = fmt(s.followers) .. " followers  •  +" .. math.floor(math.min(50, s.followers / 20)) .. "% customers from fans"
	end)
end

-- ===== MESSAGES =====
do
	local v = makeView("messages")
	topBar(v, "💬 Messages", RGB(40, 150, 70))
	local list = scroller(v, 44)
	local msgs = {}
	C.unread = 0
	local function render()
		clear(list)
		if #msgs == 0 then
			label({Size = UDim2.new(1, 0, 0, 40), Text = "No messages yet.", TextSize = 13, TextColor3 = SUB, ZIndex = 23}, list)
		end
		for i, m in ipairs(msgs) do
			local c = new("Frame", {Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = m.choices and not m.resolved and RGB(70, 40, 40) or CARD, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 22}, list)
			corner(c, 10)
			new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, c)
			local lay = vlist(c, 4)
			lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
			label({Size = UDim2.new(1, 0, 0, 16), Text = m.icon .. "  " .. m.from, TextSize = 12, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, LayoutOrder = 1}, c)
			local body = label({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = m.text, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, LayoutOrder = 2}, c)
			body.Font = Enum.Font.GothamMedium
			if m.resolved then
				label({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "➡️ " .. m.resolved, TextSize = 12, TextWrapped = true, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, LayoutOrder = 3}, c)
			elseif m.choices then
				local row = new("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 23, LayoutOrder = 3}, c)
				local n = #m.choices
				local cols = {GRAY, RGB(235, 160, 30), RED}
				for k, ch in ipairs(m.choices) do
					local b = button({Position = UDim2.new((k - 1) / n, 2, 0, 0), Size = UDim2.new(1 / n, -4, 1, 0), Text = ch, TextSize = 10, TextWrapped = true, BackgroundColor3 = cols[k] or BLUE, ZIndex = 24}, row)
					b.MouseButton1Click:Connect(function()
						play(SND.click)
						act("msgChoice", m.id, k)
					end)
				end
			end
		end
	end
	v.refresh = render
	local function load()
		local ok, list2 = pcall(function() return C.GetCatalog:InvokeServer("inbox") end)
		if ok and type(list2) == "table" then msgs = list2 end
	end
	C.reloadInbox = function()
		load()
		C.unread = 0
		badge.Visible = false
	end
	R.Msg.OnClientEvent:Connect(function(kind, a, b)
		if kind == "add" then
			table.insert(msgs, 1, a)
			if #msgs > 40 then table.remove(msgs) end
			if not (phone.Visible and current == "messages") then
				C.unread += 1
				badge.Visible = true
				badgeL.Text = tostring(math.min(99, C.unread))
				tween(pbtn, 0.1, {Rotation = 12})
				task.delay(0.1, function() tween(pbtn, 0.2, {Rotation = 0}, Enum.EasingStyle.Back) end)
			end
			play(SND.msg)
		elseif kind == "resolve" then
			for _, m in ipairs(msgs) do
				if m.id == a then m.resolved = b end
			end
		end
		if phone.Visible and current == "messages" then render() end
	end)
end

-- ===== MAP =====
do
	local v = makeView("map")
	topBar(v, "🗺️ Map", RGB(40, 110, 200))
	local list = scroller(v, 44)
	local PLACES = {
		{"🏢 My Business", "business"}, {"🏠 My Home", "home"}, {"🏙️ Empire Spire", "spire"}, {"🚗 Corner Motors", "dealer"},
		{"🏁 Race Track", "race"}, {"🎡 Fun Park", "funpark"}, {"🏢 Rental Row", "rental"}, {"🏙️ Downtown", "downtown"},
		{"🏭 Industrial Zone", "industrial"}, {"🏖️ Beach District", "beach"}, {"💎 Luxury Hills", "luxury"},
		{"🏚️ Old Town", "oldtown"}, {"🏡 Maple Suburbs", "suburbs"}, {"🌊 Oceanfront", "ocean"}, {"⛰️ Hillside", "hills"}, {"💎 Millionaire Row", "rich"},
		{"🏛️ Legacy Museum", "museum"}, {"❓ Mystery Lot", "mystery"},
	}
	for i, p in ipairs(PLACES) do
		local b = button({Size = UDim2.new(1, -8, 0, 36), Text = p[1], TextSize = 14, BackgroundColor3 = i <= 2 and RGB(60, 150, 90) or RGB(50, 90, 160), LayoutOrder = i, ZIndex = 23}, list)
		b.TextXAlignment = Enum.TextXAlignment.Left
		new("UIPadding", {PaddingLeft = UDim.new(0, 12)}, b)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			act("tp", p[2])
			phone.Visible = false
		end)
	end
end
C.phoneFrame = phone
C.phoneView("home")
end
