-- COMPUTER UI (v10): the desktop that opens when you use a computer you own (home or HQ office).
-- The server sends the data (GameServer > Computer) only while you're standing at the computer; locked apps show
-- which computer tier unlocks them. Actions (remote restock, manager contract) are checked again on the server.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, header, clear, corner = C.new, C.label, C.button, C.card, C.header, C.clear, C.corner
local fmt, play, SND, act, R = C.fmt, C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local CUI = {}
C.ComputerUI = CUI
local TIER_NAMES = {"Basic Computer", "Gaming PC", "Executive Workstation", "Empire Command Center"}

local m = modal("computer", "💻  COMPUTER", 700, 560)
if C.BusinessUI and C.BusinessUI.helpButton then C.BusinessUI.helpButton(m, "computer") end
-- the desktop: an app bar on the left, the app on the right
m.body.Visible = false
local side = new("ScrollingFrame", {Position = UDim2.fromOffset(12, 54), Size = UDim2.new(0, 176, 1, -66), BackgroundColor3 = RGB(18, 22, 34), BorderSizePixel = 0,
	ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, m.frame)
corner(side, 10)
new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, side)
new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, side)
local main = new("ScrollingFrame", {Position = UDim2.fromOffset(196, 54), Size = UDim2.new(1, -208, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, m.frame)
new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, main)
CUI.side, CUI.main = side, main
-- v11.1 phone layout: the app bar becomes a scrolling strip across the top, the app gets the full width below
local sideList = side:FindFirstChildOfClass("UIListLayout")
m.onFit = function(compact)
	CUI.compact = compact
	side.Size = compact and UDim2.new(1, -24, 0, 50) or UDim2.new(0, 176, 1, -66)
	side.AutomaticCanvasSize = compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
	side.ScrollingDirection = compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.XY
	sideList.FillDirection = compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	main.Position = compact and UDim2.fromOffset(12, 110) or UDim2.fromOffset(196, 54)
	main.Size = compact and UDim2.new(1, -24, 1, -122) or UDim2.new(1, -208, 1, -66)
	for _, ch in ipairs(side:GetChildren()) do
		if ch:IsA("GuiObject") then ch.Size = compact and UDim2.new(0, 124, 1, -10) or UDim2.new(1, 0, 0, 34) end
	end
end

local DATA, APP = nil, "overview"
local function line(text, order, color, size, h)
	local c = card(main, h or 34, order)
	label({Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Text = text, TextSize = size or 13, TextColor3 = color or WHITE, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold}, c)
	return c
end
local function locked(app)
	clear(main)
	header(main, app.icon .. " " .. app.name, 0)
	line("🔒 Needs a " .. TIER_NAMES[app.need] .. " (or better).", 1, RGB(255, 170, 140), 15, 50)
	line("Upgrade in the furniture shop → Tech, or the Home app.", 2, SUB, 12)
end
local RENDER = {}
RENDER.overview = function(o)
	line("👤 " .. o.name .. "  •  " .. o.tier .. "  (rep " .. fmt(o.rep) .. ")", 1, GOLD, 15, 40)
	line("💵 Cash: $" .. fmt(o.cash) .. "    📈 Income: $" .. fmt(o.income) .. "/s", 2)
	line("🏦 Lifetime earnings: $" .. fmt(o.earned) .. "    ♻️ Rebirths: " .. o.rebirths, 3)
	line("🏪 Businesses: " .. o.businesses .. "    🏙️ Properties: " .. o.properties .. " / " .. o.capacity, 4)
	line("🚗 Vehicles: " .. o.cars .. " / " .. o.carsTotal .. "    🏢 HQ floors: " .. o.hq, 5)
	line("🔥 Viral score: " .. fmt(o.viral) .. "    👥 Followers: " .. fmt(o.followers), 6)
	line("💎 Net worth (cash + property): $" .. fmt(o.netWorth), 7, GREEN, 15, 40)
end
RENDER.finances = function(f)
	line("💵 Cash $" .. fmt(f.cash) .. "  •  Income $" .. fmt(f.income) .. "/s  •  Rent earned $" .. fmt(f.rent), 1, GOLD, 13, 40)
	header(main, "Income by business", 2)
	for i, r in ipairs(f.rows) do line(r.icon .. " " .. r.name .. "  —  $" .. fmt(r.income) .. "/s", 2 + i) end
	header(main, "Costs", 40)
	if #f.costs == 0 then line("No open costs.", 41, SUB) end
	for i, r in ipairs(f.costs) do line(r.text .. "  —  $" .. fmt(r.amount), 41 + i, RGB(255, 190, 160)) end
end
RENDER.inventory = function(v)
	header(main, "📦 Supplies", 1)
	for i, s in ipairs(v.supplies) do
		local t = {}
		for _, it in ipairs(s.items) do table.insert(t, it[1] .. " " .. it[2] .. "%") end
		line(s.icon .. " " .. s.biz .. ":  " .. table.concat(t, "  •  "), 1 + i, nil, 12)
	end
	header(main, "🍽️ Products", 30)
	for i, p in ipairs(v.products) do if i <= 16 then line(p.name .. "  (" .. p.biz .. ")  —  " .. fmt(p.sold) .. " sold", 30 + i, nil, 12) end end
	header(main, "🛋️ Furniture", 60)
	local f = {}
	for _, it in ipairs(v.furniture) do table.insert(f, it.key .. " ×" .. it.count) end
	line((#f > 0 and table.concat(f, ", ") or "None in storage") .. "   •   placed: " .. v.placed, 61, nil, 12, 44)
	line("🏺 Collectibles: " .. #v.collectibles .. "   •   🚗 customized vehicles: " .. v.vehicleItems .. "   •   🎟️ tickets: " .. v.special.tickets .. "   •   🎁 mystery: " .. v.special.mystery, 62, nil, 12, 44)
end
RENDER.businesses = function(list)
	header(main, "Remote stock check", 0)
	if #list == 0 then line("No businesses yet.", 1, SUB) end
	for i, b in ipairs(list) do
		local c = card(main, 64, i)
		label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 22), Text = b.icon .. " " .. b.name .. "  Lv " .. b.level .. "  •  $" .. fmt(b.income) .. "/s", TextSize = 14,
			Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, c)
		label({Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -150, 0, 28), Text = "Stock " .. b.stock .. "%  •  " .. b.products .. " products" .. (b.problem and ("  •  ⚠️ " .. b.problem) or ""),
			TextSize = 12, TextColor3 = b.stock < 25 and RGB(255, 160, 140) or SUB, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true}, c)
		local r = button({Position = UDim2.new(1, -138, 0.5, -18), Size = UDim2.fromOffset(128, 36), Text = b.restock > 0 and ("Restock $" .. fmt(b.restock)) or "Full", TextSize = 12,
			BackgroundColor3 = b.restock > 0 and GREEN or GRAY}, c)
		r.MouseButton1Click:Connect(function()
			play(SND.click)
			if b.restock > 0 then act("pcRestock", b.key) end
		end)
	end
end
RENDER.stocks = function()
	line("📈 Trade shares in the 📈 Stocks app — opening it now.", 1, nil, 13, 44)
	local b = button({Size = UDim2.new(1, -8, 0, 40), Text = "Open Stocks", TextSize = 14, BackgroundColor3 = BLUE, LayoutOrder = 2}, main)
	b.MouseButton1Click:Connect(function() play(SND.click) C.openModal("market") end)
end
RENDER.vehicles = function(list)
	header(main, #list .. " vehicles", 0)
	for i, v in ipairs(list) do line("🚗 " .. v.name .. "  (" .. tostring(v.class) .. ")", i) end
	local b = button({Size = UDim2.new(1, -8, 0, 40), Text = "Open Garage", TextSize = 14, BackgroundColor3 = BLUE, LayoutOrder = 99}, main)
	b.MouseButton1Click:Connect(function() play(SND.click) C.openModal("garage") end)
end
RENDER.properties = function(p)
	local e = p.estate or {}
	line("🏙️ Properties: " .. tostring(e.used or 0) .. " / " .. tostring(e.capacity or 0) .. "   •   🏢 HQ floors: " .. p.hq, 1, GOLD, 14, 40)
	for i, dd in ipairs(e.deeds or {}) do line((dd.icon or "📍") .. " " .. tostring(dd.district) .. "  —  " .. tostring(dd.bizName or "vacant"), 1 + i, nil, 12) end
	line("🏠 Home: " .. tostring(p.home) .. (p.hood and ("  in " .. p.hood) or "") .. "   •   🏬 Rental buildings: " .. p.rentals, 50, nil, 12, 40)
end
RENDER.messages = function(msg)
	line("📨 " .. msg.unread .. " unread message" .. (msg.unread == 1 and "" or "s"), 1, GOLD, 15, 44)
	local b = button({Size = UDim2.new(1, -8, 0, 40), Text = "Open Messages", TextSize = 14, BackgroundColor3 = BLUE, LayoutOrder = 2}, main)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		m.frame.Visible = false
		if C.phoneView then C.phoneView("messages") end
	end)
end
RENDER.tasks = function(list)
	header(main, "📋 To do", 0)
	if #list == 0 then line("All caught up!", 1, SUB) end
	for i, t in ipairs(list) do line((t.done and "✅ " or "⬜ ") .. tostring(t.text), i, t.done and SUB or WHITE, 12, 40) end
end
RENDER.events = function(e)
	line("📅 " .. tostring(e.event), 1, nil, 13, 44)
	if e.mega then line("🌆 " .. e.mega, 2, GOLD, 13, 44) end
	if e.beef then line("🥊 " .. e.beef, 3, RGB(255, 150, 120), 13, 44) end
	if e.trending then line("🔥 Trending: " .. e.trending, 4, RGB(255, 150, 90)) end
	for i, s in ipairs(e.sightings or {}) do line("👀 " .. s, 4 + i, PURPLE) end
end
RENDER.analytics = function(list)
	header(main, "Best sellers", 0)
	if #list == 0 then line("No products yet.", 1, SUB) end
	for i, p in ipairs(list) do
		if i <= 20 then
			line(i .. ". " .. p.name .. " (" .. p.biz .. ")  •  sold " .. fmt(p.sold) .. "  •  pop " .. p.pop .. "  •  demand " .. p.demand .. "%  •  price " .. p.price .. "%"
				.. (p.trend > 0 and "  🔥" or ""), i, i <= 3 and GOLD or WHITE, 12, 40)
		end
	end
end

local function render()
	clear(side)
	if not DATA then return end
	local cellSize = CUI.compact and UDim2.new(0, 124, 1, -10) or UDim2.new(1, 0, 0, 34)
	local t = label({Size = cellSize, Text = DATA.tierName, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, LayoutOrder = 0}, side)
	t.BackgroundTransparency = 1
	local cur
	for i, a in ipairs(DATA.apps) do
		if a.key == APP then cur = a end
		local b = button({Size = cellSize, Text = (a.locked and "🔒 " or a.icon .. " ") .. a.name, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = a.key == APP and BLUE or (a.locked and RGB(40, 40, 48) or RGB(34, 40, 58)), LayoutOrder = i}, side)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			APP = a.key
			render()
		end)
	end
	clear(main)
	if not cur then return end
	if cur.locked then return locked(cur) end
	header(main, cur.icon .. " " .. cur.name, -1)
	local payload = DATA[cur.key]
	if RENDER[cur.key] and payload ~= nil then RENDER[cur.key](payload) end
	if cur.key == "overview" and DATA.tier >= 4 then
		local b = button({Size = UDim2.new(1, -8, 0, 40), Text = "📋 Sign a manager contract (remote)", TextSize = 13, BackgroundColor3 = PURPLE, LayoutOrder = 90}, main)
		b.MouseButton1Click:Connect(function() play(SND.click) act("pcManager") end)
	end
	local rf = button({Size = UDim2.new(1, -8, 0, 34), Text = "🔄 Refresh", TextSize = 12, BackgroundColor3 = GRAY, LayoutOrder = 999}, main)
	rf.MouseButton1Click:Connect(function() play(SND.click) act("pcRefresh", APP) end)
end
CUI.render = render
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "computer" and type(a) == "table" then
		DATA = a
		if a.app then APP = a.app end
		if not m.frame.Visible then C.openModal("computer", true) end
		render()
	end
end)
-- leaving the room closes the computer
C.plr:GetAttributeChangedSignal("Interior"):Connect(function()
	if m.frame.Visible then m.frame.Visible = false end
end)
end
