-- DAILY UI (v16): the 🎁 DAILY phone app (the 7-day login rewards with today's highlighted, the streak and its
-- 🛡️ shield, the countdown to the next UTC day, today's 3 missions, the weekly challenge and the live city
-- event), plus a small 🎁 card in the notification stack, once a session, when something is waiting to be
-- claimed. Never full-screen. The server (GameServer > Daily / LiveEvents) decides and pays everything.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, stroke, panel, corner, gradient = C.new, C.label, C.button, C.card, C.clear, C.stroke, C.panel, C.corner, C.gradient
local fmt, play, SND, act, R, gui = C.fmt, C.play, C.SND, C.act, C.R, C.gui
local GOLD, GREEN, GRAY, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local Lay = C.Layout
local modal = C.makeModal
if not modal then return end
local DU = {info = nil, cardShown = false}
C.DailyUI = DU
local NAVY = RGB(18, 24, 48)

local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, pos, size, color, fn, name)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 14, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	if name then b.Name = name end
	-- (v16.1: claim buttons are green pills)
	if name and name:find("Claim") then
		corner(b, 999)
		b:SetAttribute("Pill", color == GREEN and "buy" or "off")
	end
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end
local function bar(parent, pos, size, f, color)
	local bg = new("Frame", {Position = pos, Size = size, BackgroundColor3 = RGB(50, 54, 70), BorderSizePixel = 0}, parent)
	corner(bg, 6)
	stroke(bg, C.STYLE.outline, 2)
	local fill = new("Frame", {Size = UDim2.fromScale(math.clamp(f, 0, 1), 1), BackgroundColor3 = color or BLUE, BorderSizePixel = 0}, bg)
	corner(fill, 6)
	gradient(fill, C.STYLE.gloss)
	return bg
end
local function hm(s)
	s = math.max(0, math.floor(s or 0))
	if s >= 86400 then return math.floor(s / 86400) .. "d " .. math.floor(s % 86400 / 3600) .. "h" end
	return math.floor(s / 3600) .. "h " .. math.floor(s % 3600 / 60) .. "m"
end
local PATH_ICON = {mogul = "💼", under = "🕶️", any = "🏙️"}

local m = modal("daily", "🎁  DAILY", 560, 640)
local function render()
	local info = DU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local o = 0
	local function nx() o += 1 return o end
	-- the streak + the 7 days
	local top = card(m.body, 168, nx(), NAVY)
	stroke(top, GOLD, 2, 0.3)
	txt(top, "🔥 STREAK " .. info.streak .. " day" .. (info.streak == 1 and "" or "s") .. "   •   best " .. info.best .. "   •   🛡️ shield " .. (info.shield >= 1 and "ready" or "used this week"),
		UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	local strip = new("Frame", {Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 76), BackgroundTransparency = 1}, top)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, strip)
	for _, r in ipairs(info.rewards) do
		local isToday = r.day == info.today
		local past = r.day < info.today or (isToday and info.claimedToday)
		-- (v16.1: glossy day cards: today gold-rimmed, claimed days dimmed with ✅)
		local c = new("Frame", {Size = UDim2.new(1 / 7, -4, 1, 0), BackgroundColor3 = isToday and RGB(110, 80, 20) or (past and RGB(30, 32, 44) or RGB(52, 46, 90)), BorderSizePixel = 0, LayoutOrder = r.day}, strip)
		c.Name = "Day" .. r.day
		corner(c, 10)
		gradient(c, C.STYLE.gloss)
		stroke(c, isToday and GOLD or C.STYLE.outline, isToday and 3 or 2, 0)
		C.titleText(label({Size = UDim2.new(1, 0, 0, 16), Text = "DAY " .. r.day, TextSize = 11, TextColor3 = isToday and GOLD or SUB}, c))
		label({Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), Text = past and "✅" or r.icon, TextSize = 22}, c)
		local l = label({Position = UDim2.fromOffset(2, 46), Size = UDim2.new(1, -4, 0, 28), Text = r.name, TextSize = 9, TextWrapped = true, TextColor3 = WHITE}, c)
		l.TextScaled = true
	end
	local tr = info.rewards[info.today]
	if info.claimedToday then
		txt(top, "✅ Today's reward is claimed. Next reward in " .. hm(info.nextIn) .. " (midnight UTC).", UDim2.fromOffset(12, 116), UDim2.new(1, -24, 0, 40), 12, GREEN, true)
	elseif tr then
		txt(top, "Today: " .. tr.icon .. " " .. tr.name .. (tr.text and (" — " .. tr.text) or "") .. "  + $" .. fmt(tr.cash) .. (info.shieldUsedIfClaim and "  (🛡️ your shield saves the streak)" or ""),
			UDim2.fromOffset(12, 112), UDim2.new(1, -170, 0, 50), 11, WHITE)
		btn(top, "🎁 Claim", UDim2.new(1, -150, 1, -50), UDim2.fromOffset(138, 40), info.canSave and GREEN or GRAY, function() if info.canSave then act("dailyClaim") end end, "DailyClaim")
	end
	-- the live city event
	local ev = info.event
	if type(ev) == "table" then
		local c = card(m.body, 92, nx(), RGB(40, 26, 50))
		stroke(c, ev.color or PURPLE, 2, 0.3)
		txt(c, ev.icon .. "  CITY EVENT: " .. string.upper(ev.name) .. "   •   ends in " .. hm(ev.endsIn), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
		txt(c, ev.text, UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 30), 11, WHITE)
		if ev.goal then
			txt(c, "🎯 " .. ev.goal .. "  " .. ev.p .. "/" .. ev.n, UDim2.fromOffset(12, 62), UDim2.new(0.6, 0, 0, 20), 11, SUB)
			if ev.claimed then
				txt(c, "✅ Claimed", UDim2.new(1, -150, 0, 60), UDim2.fromOffset(138, 22), 12, GREEN, true)
			else
				btn(c, ev.done and ("🎁 $" .. fmt(ev.cash)) or (ev.p .. "/" .. ev.n), UDim2.new(1, -150, 0, 54), UDim2.fromOffset(138, 32), ev.done and GREEN or GRAY,
					function() if ev.done then act("liveClaim") end end, "LiveClaim")
			end
		end
		if ev.nextName then txt(c, "Next: " .. ev.nextIcon .. " " .. ev.nextName .. " in " .. hm(ev.endsIn), UDim2.fromOffset(12, 78), UDim2.new(0.6, 0, 0, 14), 10, SUB) end
	end
	-- missions
	local h = card(m.body, 30, nx(), RGB(26, 28, 40))
	txt(h, "🎯 TODAY'S MISSIONS   (new ones in " .. hm(info.nextIn) .. ")", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	for _, ms in ipairs(info.missions) do
		local c = card(m.body, 62, nx(), ms.claimed and RGB(30, 50, 36) or nil)
		txt(c, (PATH_ICON[ms.path] or "🎯") .. "  " .. ms.text, UDim2.fromOffset(12, 8), UDim2.new(1, -170, 0, 22), 13, WHITE, true)
		bar(c, UDim2.fromOffset(12, 38), UDim2.new(1, -184, 0, 10), ms.p / math.max(1, ms.n), ms.done and GREEN or BLUE)
		txt(c, fmt(ms.p) .. "/" .. fmt(ms.n), UDim2.new(1, -168, 0, 34), UDim2.fromOffset(60, 18), 11, SUB)
		if ms.claimed then
			txt(c, "✅ Done", UDim2.new(1, -104, 0.5, -10), UDim2.fromOffset(92, 20), 13, GREEN, true)
		else
			btn(c, ms.done and ("🎁 $" .. fmt(ms.cash)) or "In progress", UDim2.new(1, -112, 0.5, -17), UDim2.fromOffset(100, 34), ms.done and GREEN or GRAY,
				function() if ms.done then act("missionClaim", ms.i) end end, "Mission_" .. ms.i)
		end
	end
	-- weekly
	local w = info.weekly
	if type(w) == "table" then
		local c = card(m.body, 74, nx(), RGB(36, 30, 20))
		stroke(c, GOLD, 1, 0.5)
		txt(c, "🏆 WEEKLY: " .. w.text .. "   (" .. hm(w.endsIn) .. " left)", UDim2.fromOffset(12, 8), UDim2.new(1, -170, 0, 36), 12, GOLD, true)
		bar(c, UDim2.fromOffset(12, 50), UDim2.new(1, -184, 0, 10), w.p / math.max(1, w.n), w.done and GREEN or GOLD)
		txt(c, fmt(w.p) .. "/" .. fmt(w.n) .. "  •  " .. w.badge, UDim2.new(1, -168, 0, 46), UDim2.fromOffset(150, 18), 10, SUB)
		if w.claimed then
			txt(c, "✅ Claimed", UDim2.new(1, -104, 0, 14), UDim2.fromOffset(92, 20), 13, GREEN, true)
		else
			btn(c, w.done and ("🎁 $" .. fmt(w.cash)) or "In progress", UDim2.new(1, -112, 0, 8), UDim2.fromOffset(100, 34), w.done and GREEN or GRAY,
				function() if w.done then act("weeklyClaim") end end, "WeeklyClaim")
		end
	end
	local n = card(m.body, 44, nx(), RGB(26, 28, 40))
	txt(n, "Days are UTC calendar days. Miss one day and your 🛡️ shield keeps the streak (once a week); miss more and the 7-day strip steps back a little, never all the way.",
		UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 10, SUB)
end
DU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("dailyInfo")
	end
end

-- ===== the 🎁 card (once a session, only when something is waiting) =====
local dc = panel({Position = UDim2.new(1, -12, 1, -480), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(290, 76), BackgroundColor3 = NAVY, Visible = false}, gui)
stroke(dc, GOLD, 2, 0)
dc.Name = "DailyCard"
Lay.slot(dc, "top", 6.5)
local dt = label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 34), TextSize = 12, TextWrapped = true, Font = Enum.Font.GothamBlack, TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, dc)
local open = button({Position = UDim2.new(0, 8, 1, -32), Size = UDim2.new(0.6, -12, 0, 26), Text = "🎁 Open", TextSize = 12, BackgroundColor3 = GREEN}, dc)
open.Name = "DailyOpen"
local later = button({Position = UDim2.new(0.6, 0, 1, -32), Size = UDim2.new(0.4, -8, 0, 26), Text = "Later", TextSize = 12, BackgroundColor3 = GRAY}, dc)
later.Name = "DailyLater"
open.MouseButton1Click:Connect(function()
	play(SND.click)
	dc.Visible = false
	C.openModal("daily", true)
end)
later.MouseButton1Click:Connect(function() play(SND.click) dc.Visible = false end)
DU.card = dc
local function waiting(info)
	if not info.claimedToday and info.canSave then return "🎁 Day " .. info.today .. " reward is ready  •  🔥 streak " .. info.streak end
	for _, ms in ipairs(info.missions) do if ms.done and not ms.claimed then return "🎯 A daily mission is done: claim it!" end end
	if info.weekly and info.weekly.done and not info.weekly.claimed then return "🏆 Weekly challenge done: claim it!" end
	return nil
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "daily" and type(a) == "table" then
		DU.info = a
		if m.frame.Visible then render() end
		local w = waiting(a)
		if w and not DU.cardShown and not m.frame.Visible then
			DU.cardShown = true
			dt.Text = w
			dc.Visible = true
		elseif not w then
			dc.Visible = false
		end
	elseif kind == "dailyPing" then
		if m.frame.Visible then act("dailyInfo") end
	elseif kind == "play" then
		-- a few seconds after the game starts (after the welcome-back messages), see if anything's waiting
		DU.cardShown = false
		task.delay(6, function() if not C.inMainMenu then act("dailyInfo") end end)
	elseif kind == "mainmenu" then
		dc.Visible = false
	end
end)
end
