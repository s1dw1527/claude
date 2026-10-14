-- PARK UI (v15): the 🎢 PARK phone app. Before you have one: how to open it (a city plot for the ticket gate,
-- then your own site at the Funland Grounds). After: the park's rating and why, its sales boost, visitors and
-- rides, "go to my park", other players' parks to visit, and the BUILD tab: a top-down plan of your site (tap a
-- cell to place the ride or stall you picked from the shop; tap something built to move, turn or sell it).
-- The server (GameServer > Park) checks every placement; this only shows the plan and asks.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, corner, stroke = C.new, C.label, C.button, C.card, C.clear, C.corner, C.stroke
local fmt, play, SND, act, R = C.fmt, C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local PU = {info = nil, tab = "park", list = nil}
C.ParkUI = PU
local sel = {k = nil, id = nil, r = 0, moving = false}
PU.sel = sel

local function txt(parent, text, pos, size, px, color, bold, order)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true, LayoutOrder = order,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, pos, size, color, fn, name, order)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE, LayoutOrder = order}, parent)
	if name then b.Name = name end
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end
local KIND_COLOR = {ride = RGB(255, 120, 60), stall = RGB(255, 140, 200), decor = RGB(90, 170, 90), path = RGB(170, 150, 120)}

local m = modal("park", "🎢  AMUSEMENT PARK", 600, 640)
local function renderClosed(info)
	local c = card(m.body, 200, 1, RGB(60, 30, 40))
	stroke(c, RGB(255, 120, 40), 2, 0.3)
	txt(c, "🎢 BUILD YOUR OWN AMUSEMENT PARK", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 17, GOLD, true)
	txt(c, "Open it on a city plot (that's its ticket gate), and you get your own site at the 🎢 Funland Grounds, out west past the Fun Park. "
		.. "Build carousels, Ferris wheels, a pirate ship, drop towers and roller coasters, add cotton candy and popcorn stands, paths and trees. "
		.. "The better the park, the more it earns, and other players pay a ticket every time they ride.\n\n"
		.. "Opening costs $" .. fmt(info.cost) .. " + the plot.  " .. (info.unlocked and "You can open one now." or ("🔒 Unlocks at " .. tostring(info.need) .. " reputation.")),
		UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 110), 12, WHITE)
	btn(c, "🏙️ Choose a plot", UDim2.new(1, -184, 1, -48), UDim2.fromOffset(170, 38), info.unlocked and GREEN or GRAY, function() if C.openLotShop then C.openLotShop("park") end end, "ParkPlots")
	PU.renderList()   -- (v16: visit other players' parks before you have one)
end

-- other parks in this server (anyone can visit, with or without a park of their own)
function PU.renderList()
	local h = card(m.body, 30, 10, RGB(26, 28, 40))
	txt(h, "👀 PARKS IN THIS SERVER", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	if #(PU.list or {}) == 0 then
		local c = card(m.body, 34, 11)
		txt(c, "No parks open in this server yet.", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 12, SUB)
	end
	for i, p in ipairs(PU.list or {}) do
		local c = card(m.body, 58, 10 + i)
		txt(c, "🎢 " .. p.park .. "  (" .. p.name .. ")  ⭐ " .. p.rating, UDim2.fromOffset(12, 6), UDim2.new(1, -200, 0, 20), 13, WHITE, true)
		-- (v16: visitors and the star ride; a visit pays a small reward the first time each day)
		txt(c, "👥 " .. fmt(p.visitors or 0) .. " visitors" .. (p.featured and ("  •  " .. p.featured) or ""), UDim2.fromOffset(12, 30), UDim2.new(1, -200, 0, 18), 11, SUB)
		btn(c, "🪪", UDim2.new(1, -186, 0.5, -16), UDim2.fromOffset(52, 32), GRAY, function() if C.openShowcase then C.openShowcase(p.userId) end end, "ParkProfile_" .. p.userId)
		if not p.mine then btn(c, "Visit", UDim2.new(1, -126, 0.5, -16), UDim2.fromOffset(114, 32), BLUE, function() act("parkGo", p.userId) C.closeModals() end, "ParkVisit_" .. p.userId) end
	end
end
local function renderOverview(info)
	local top = card(m.body, 116, 2, RGB(50, 30, 40))
	stroke(top, GOLD, 2, 0.4)
	txt(top, "🎢 " .. string.upper(info.name) .. "   Lv " .. info.level, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 22), 17, GOLD, true)
	txt(top, string.format("⭐ Rating %d / 100   •   sales ×%.2f   •   %s visitors   •   %s rides (%s by guests)", info.rating, info.mult, fmt(info.visitors), fmt(info.rides), fmt(info.guestRides)),
		UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 34), 12, WHITE)
	local why = {}
	for _, p in ipairs(info.parts) do table.insert(why, p[1] .. " +" .. p[2]) end
	txt(top, table.concat(why, "   "), UDim2.fromOffset(14, 70), UDim2.new(1, -28, 0, 40), 11, SUB)
	local row = card(m.body, 56, 3, RGB(30, 34, 46))
	btn(row, "🚶 Go to my park", UDim2.fromOffset(10, 10), UDim2.new(0.5, -15, 0, 36), GREEN, function() act("parkGo") C.closeModals() end, "ParkGo")
	btn(row, "🔨 Build", UDim2.new(0.5, 5, 0, 10), UDim2.new(0.5, -15, 0, 36), PURPLE, function() PU.tab = "build" PU.render() end, "ParkBuildTab")
	if not info.hasPlot then
		local w = card(m.body, 40, 4, RGB(70, 40, 20))
		txt(w, "📍 Your park has no city plot right now: open it on one of your plots to sell tickets again.", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 12, GOLD)
	end
	PU.renderList()
	local n = card(m.body, 58, 40, RGB(26, 28, 40))
	txt(n, "The rating comes from exciting rides (new kinds count most), food stalls to go with them, decorations and paths. "
		.. "It boosts the park's sales up to ×1.8 and brings more visitors. Every ride has a 🎢 Ride prompt: step up and ride it.",
		UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 11, SUB)
end

local CELL = 14
local function renderBuild(info)
	local compact = C.Layout and C.Layout.compact
	local aw = m.frame.Size.X.Offset - 24
	CELL = compact and math.clamp(math.floor(aw / info.gw), 10, 18) or 14
	local gw, gh = info.gw * CELL, info.gh * CELL
	local area = new("Frame", {Size = UDim2.new(1, 0, 0, compact and (gh + 330) or (gh + 40)), BackgroundTransparency = 1, LayoutOrder = 2}, m.body)
	txt(area, string.format("🔨 %d / %d pieces   •   ⭐ %d   •   💵 $%s", #info.items, info.cap, info.rating, fmt(info.cash)), UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 12, GOLD, true)
	local gridF = new("Frame", {Position = UDim2.fromOffset(0, 22), Size = UDim2.fromOffset(gw, gh), BackgroundColor3 = RGB(60, 110, 60), BorderSizePixel = 0}, area)
	gridF.Name = "ParkGrid"
	corner(gridF, 4)
	PU.grid = gridF
	local occ = {}
	for _, it in ipairs(info.items) do
		for cx = it.x, it.x + it.w - 1 do for cz = it.z, it.z + it.h - 1 do occ[cx .. "," .. cz] = it end end
	end
	PU.cells = {}
	for cz = 0, info.gh - 1 do
		for cx = 0, info.gw - 1 do
			local k = cx .. "," .. cz
			local it = occ[k]
			local gate = cx == 0 and cz >= info.gate[1] and cz <= info.gate[2]
			local color = it and (sel.id == it.id and RGB(255, 90, 170) or KIND_COLOR[it.kind]) or (gate and RGB(200, 60, 100) or RGB(78, 130, 72))
			local c = button({Position = UDim2.fromOffset(cx * CELL, cz * CELL), Size = UDim2.fromOffset(CELL - 1, CELL - 1), BackgroundColor3 = color, AutoButtonColor = true,
				Text = (it and it.x == cx and it.z == cz) and it.icon or (gate and cz == info.gate[1] and "🚪" or ""), TextSize = math.max(8, CELL - 4)}, gridF)
			c.Name = "Cell_" .. k
			PU.cells[k] = c
			c.MouseButton1Click:Connect(function()
				play(SND.click)
				if sel.k then
					act("parkPlace", sel.k, {cx, cz, sel.r})
				elseif sel.id and sel.moving then
					act("parkMove", sel.id, {cx, cz, sel.r})
					sel.moving = false
				elseif it then
					sel.id, sel.r, sel.moving = it.id, it.r, false
					PU.render()
				else
					sel.id = nil
					PU.render()
				end
			end)
		end
	end
	txt(area, "⬅ gate (the promenade)", UDim2.fromOffset(0, gh + 24), UDim2.fromOffset(200, 14), 10, SUB)
	-- the side panel: the shop, or what's selected
	local side = new("ScrollingFrame", {Position = compact and UDim2.fromOffset(0, gh + 42) or UDim2.fromOffset(gw + 12, 22), Size = compact and UDim2.new(1, 0, 0, 286) or UDim2.new(1, -(gw + 12), 0, gh),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, area)
	side.Name = "ParkSide"
	new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, side)
	local picked
	for _, it in ipairs(info.items) do if it.id == sel.id then picked = it end end
	if picked then
		txt(side, picked.icon .. " " .. picked.name, UDim2.new(), UDim2.new(1, -4, 0, 22), 15, GOLD, true, 1)
		btn(side, sel.moving and "Tap a cell to move it…" or "✋ Move", UDim2.new(), UDim2.new(1, -4, 0, 34), sel.moving and PURPLE or BLUE, function()
			sel.moving = true
			PU.render()
		end, "ParkMove", 2)
		btn(side, "🔄 Turn", UDim2.new(), UDim2.new(1, -4, 0, 34), BLUE, function()
			act("parkMove", picked.id, {picked.x, picked.z, (picked.r + 1) % 4})
		end, "ParkTurn", 3)
		btn(side, "💵 Sell (half back)", UDim2.new(), UDim2.new(1, -4, 0, 34), RED, function()
			local id = picked.id
			local function sell() act("parkSell", id, true) sel.id = nil end
			if C.confirm then C.confirm("Sell the " .. picked.name .. "? You get half its price back.", "Sell", sell) else sell() end
		end, "ParkSell", 4)
		btn(side, "Done", UDim2.new(), UDim2.new(1, -4, 0, 30), GRAY, function()
			sel.id, sel.moving = nil, false
			PU.render()
		end, "ParkDone", 5)
		return
	end
	txt(side, sel.k and "Placing — tap a cell on the plan (its top-left corner)" or "🛒 Pick something, then tap the plan", UDim2.new(), UDim2.new(1, -4, 0, 30), 12, sel.k and GOLD or SUB, true, 1)
	if sel.k then
		btn(side, "🔄 Turn: " .. (sel.r * 90) .. "°", UDim2.new(), UDim2.new(1, -4, 0, 30), BLUE, function()
			sel.r = (sel.r + 1) % 4
			PU.render()
		end, "ParkRotate", 2)
		btn(side, "Cancel", UDim2.new(), UDim2.new(1, -4, 0, 30), GRAY, function()
			sel.k = nil
			PU.render()
		end, "ParkCancel", 3)
	end
	for i, s in ipairs(info.shop) do
		local can = not s.locked and info.cash >= s.cost
		local line = s.icon .. " " .. s.name .. "  " .. s.w .. "×" .. s.h .. "  $" .. fmt(s.cost) .. (s.excite and ("  ⚡" .. s.excite) or "") .. (s.locked and ("  🔒 Lv " .. s.lvl) or "")
		local b = btn(side, line, UDim2.new(), UDim2.new(1, -4, 0, 34), sel.k == s.k and PURPLE or (can and RGB(52, 58, 80) or RGB(40, 40, 48)), function()
			if s.locked then
				if C.U and C.U.toast then C.U.toast("🔒 " .. s.name .. " unlocks at park level " .. s.lvl .. ".") end
				return
			end
			sel.k = sel.k ~= s.k and s.k or nil
			sel.id = nil
			PU.render()
		end, "Shop_" .. s.k, 10 + i)
		b.TextXAlignment = Enum.TextXAlignment.Left
	end
end

function PU.render()
	local info = PU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	if not info.open then
		renderClosed(info)
		return
	end
	local tabs = card(m.body, 40, 1, RGB(26, 28, 40))
	btn(tabs, "📊 Park", UDim2.fromOffset(6, 5), UDim2.new(0.5, -9, 1, -10), PU.tab == "park" and GOLD or GRAY, function() PU.tab = "park" PU.render() end, "ParkTabPark")
	btn(tabs, "🔨 Build", UDim2.new(0.5, 3, 0, 5), UDim2.new(0.5, -9, 1, -10), PU.tab == "build" and GOLD or GRAY, function() PU.tab = "build" PU.render() end, "ParkTabBuild")
	if PU.tab == "build" then renderBuild(info) else renderOverview(info) end
end
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not m.frame.Visible then
		asked = false
		sel.k, sel.id, sel.moving = nil, nil, false
	end
end)
m.update = function()
	if not asked then
		asked = true
		act("parkInfo")
		act("parkList")
	end
end
function C.openPark(tab)
	PU.tab = tab or PU.tab
	asked = false
	C.openModal("park", true)
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "park" and type(a) == "table" then
		PU.info = a
		if m.frame.Visible then PU.render() end
	elseif kind == "parkList" and type(a) == "table" then
		PU.list = a
		if m.frame.Visible and (PU.tab == "park" or not (PU.info and PU.info.open)) and PU.info then PU.render() end
	end
end)
end
