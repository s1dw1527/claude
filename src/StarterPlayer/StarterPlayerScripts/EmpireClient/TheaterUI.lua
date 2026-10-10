-- THEATER UI (v14): the 🍿 THEATER phone app. What's showing, the next show, how full it will be (and why), the
-- films in release to pick from, the upgrades (seats, screen, sound, concessions) and the theater's record.
-- Before you have one: how to open it (buy a city plot, choose 🎬 on it). The server (GameServer > Theater)
-- decides everything; this only asks for the info and sends "show this film" / "buy this upgrade".
return function(C)
local RGB = Color3.fromRGB
local label, button, card, clear, stroke = C.label, C.button, C.card, C.clear, C.stroke
local fmt, play, SND, act, R = C.fmt, C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local TU = {info = nil}
C.TheaterUI = TU

local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, pos, size, color, fn, name)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 13, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	if name then b.Name = name end
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end
local function clock(s)
	s = math.max(0, math.floor(s or 0))
	if s >= 3600 then return string.format("%dh %02dm", math.floor(s / 3600), math.floor(s % 3600 / 60)) end
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local m = modal("theater", "🍿  MOVIE THEATER", 560, 620)
local function render()
	local info = TU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	if not info.open then
		local c = card(m.body, 190, 1, RGB(50, 24, 34))
		stroke(c, RGB(220, 40, 60), 2, 0.3)
		txt(c, "🎬 OPEN A MOVIE THEATER", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 18, GOLD, true)
		txt(c, "A theater is too big for your home plot: it opens on a city plot.\n\n1. 🏢 Properties: buy a plot in any district\n2. Choose 🎬 Movie Theater on it ($" .. fmt(info.cost) .. ")\n\n"
			.. (info.unlocked and "You can open one now." or "🔒 Unlocks at a higher reputation."), UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 110), 13, WHITE)
		btn(c, "🏢 Open Properties", UDim2.new(1, -184, 1, -48), UDim2.fromOffset(170, 38), GREEN, function() C.openModal("properties", true) end, "GoProperties")
		return
	end
	-- now showing
	local top = card(m.body, 112, 1, RGB(40, 22, 30))
	stroke(top, GOLD, 2, 0.3)
	local now
	for _, f in ipairs(info.films) do if f.showing then now = f end end
	txt(top, "NOW SHOWING", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 16), 11, SUB, true)
	txt(top, now and (now.icon .. "  " .. now.title) or "—", UDim2.fromOffset(14, 24), UDim2.new(1, -28, 0, 26), 20, GOLD, true)
	txt(top, string.format("Next show in %s  •  %d seats  •  expected %d%% full  •  sales ×%.2f", clock(info.nextShow or 0), info.capacity, info.fill, info.mult or 1),
		UDim2.fromOffset(14, 54), UDim2.new(1, -28, 0, 18), 12, WHITE)
	local why = {}
	for _, p in ipairs(info.parts or {}) do table.insert(why, p[1] .. " " .. (p[2] >= 0 and "+" or "") .. p[2] .. "%") end
	txt(top, table.concat(why, "   "), UDim2.fromOffset(14, 74), UDim2.new(1, -28, 0, 34), 10, SUB)
	if not info.hasPlot then
		local w = card(m.body, 40, 2, RGB(70, 40, 20))
		txt(w, "📍 Your theater has no plot right now: choose 🎬 on one of your plots to start the shows again.", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 12, GOLD)
	end
	-- the last show
	if type(info.last) == "table" then
		local l = card(m.body, 40, 3, RGB(30, 34, 44))
		txt(l, string.format("🎟️ Last show: %d / %d guests (%d%%)   •   %d shows, %s tickets, best %d", info.last.guests, info.last.cap, info.last.fill,
			info.sessions, fmt(info.tickets), info.best), UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 20), 12, WHITE)
	end
	-- films in release
	local h = card(m.body, 30, 4, RGB(26, 28, 40))
	txt(h, "🎞️ IN RELEASE   (new films in " .. clock(info.rotateIn) .. ")", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	for i, f in ipairs(info.films) do
		local c = card(m.body, 62, 4 + i, f.showing and RGB(36, 60, 44) or RGB(34, 36, 48))
		local tags = {f.genre}
		if f.night then table.insert(tags, "🌙 best at night") end
		if f.day then table.insert(tags, "☀️ best by day") end
		if not f.premiered then table.insert(tags, "🎬 premiere!") end
		if f.old then table.insert(tags, "📼 out of release") end
		txt(c, f.icon .. "  " .. f.title, UDim2.fromOffset(12, 8), UDim2.new(1, -150, 0, 22), 15, WHITE, true)
		txt(c, table.concat(tags, "  •  "), UDim2.fromOffset(12, 34), UDim2.new(1, -150, 0, 22), 11, SUB)
		if f.showing then
			txt(c, "✅ Showing", UDim2.new(1, -128, 0.5, -9), UDim2.fromOffset(116, 20), 13, GREEN, true)
		elseif not f.old then
			btn(c, "Show this", UDim2.new(1, -128, 0.5, -19), UDim2.fromOffset(116, 38), PURPLE, function() act("theaterFilm", f.key) end, "Film_" .. f.key)
		end
	end
	-- upgrades
	local u = card(m.body, 30, 20, RGB(26, 28, 40))
	txt(u, "🛠️ UPGRADES", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	for i, up in ipairs(info.ups) do
		local c = card(m.body, 58, 20 + i)
		txt(c, up.icon .. "  " .. up.name .. "  " .. string.rep("●", up.level) .. string.rep("○", up.max - up.level), UDim2.fromOffset(12, 8), UDim2.new(1, -170, 0, 22), 14, WHITE, true)
		txt(c, up.what, UDim2.fromOffset(12, 32), UDim2.new(1, -170, 0, 20), 11, SUB)
		if up.cost then
			local can = (info.cash or 0) >= up.cost
			btn(c, "$" .. fmt(up.cost), UDim2.new(1, -150, 0.5, -19), UDim2.fromOffset(138, 38), can and GREEN or GRAY, function() act("theaterUp", up.key) end, "Up_" .. up.key)
		else
			txt(c, "MAX", UDim2.new(1, -100, 0.5, -9), UDim2.fromOffset(88, 20), 14, GOLD, true)
		end
	end
	local n = card(m.body, 44, 40, RGB(26, 28, 40))
	txt(n, "A show starts every 3 minutes while you play. How full it is sets the theater's sales until the next one. Run the concession stand with 🍳 Rush orders at the theater.",
		UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 11, SUB)
end
TU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("theaterInfo")
	end
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "theater" and type(a) == "table" then
		TU.info = a
		if m.frame.Visible then render() end
	elseif kind == "openTheater" then
		asked = false
		C.openModal("theater", true)
	elseif kind == "needPlot" then
		asked = false
		C.openModal("theater", true)
	elseif kind == "theaterShow" and type(a) == "table" then
		if m.frame.Visible then act("theaterInfo") end
		if a.premiere and C.jingle then C.jingle("milestone", 0.4) end
	end
end)
end
