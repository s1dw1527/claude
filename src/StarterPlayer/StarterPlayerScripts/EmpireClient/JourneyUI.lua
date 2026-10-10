-- JOURNEY UI (v14): the 📅 EVENTS phone app (the special occasions on now, their three tasks, Claim, what's
-- coming next, the Weekend Rush, your keepsakes) and the 🧭 NEXT STEP card: after the tutorial, one step at a time
-- out of ten, with "Show me" (opens the right app) and "Later" (skip for now). The server (GameServer >
-- Occasions + Onboarding) tracks and pays everything.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, stroke, panel, corner = C.new, C.label, C.button, C.card, C.clear, C.stroke, C.panel, C.corner
local fmt, play, SND, act, R, gui = C.fmt, C.play, C.SND, C.act, C.R, C.gui
local GOLD, GREEN, GRAY, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local Lay = C.Layout
local modal = C.makeModal
if not modal then return end
local JU = {info = nil, step = nil}
C.JourneyUI = JU

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
local function days(s)
	s = math.max(0, math.floor(s or 0))
	if s >= 86400 then return math.floor(s / 86400) .. "d " .. math.floor(s % 86400 / 3600) .. "h" end
	return math.floor(s / 3600) .. "h " .. math.floor(s % 3600 / 60) .. "m"
end

-- ===== 📅 EVENTS =====
local m = modal("occasions", "📅  EVENTS", 560, 620)
local function render()
	local info = JU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local o = 0
	local function nx() o += 1 return o end
	if info.weekend then
		local w = card(m.body, 40, nx(), RGB(80, 40, 20))
		stroke(w, RGB(255, 150, 60), 2, 0.3)
		txt(w, "🔥 WEEKEND RUSH: Rush Orders tips ×1.5 all weekend", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 20), 14, RGB(255, 190, 120), true)
	end
	if #info.list == 0 then
		local c = card(m.body, 40, nx())
		txt(c, "No special event right now. See what's coming below!", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 20), 13, SUB)
	end
	for _, e in ipairs(info.list) do
		local c = card(m.body, 70 + #e.tasks * 30 + 50, nx(), RGB(40, 30, 50))
		stroke(c, GOLD, 2, 0.4)
		txt(c, e.icon .. "  " .. string.upper(e.name) .. (e.live and ("   •   " .. days(e.left) .. " left") or "   •   ended: claim soon!"), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22), 15, GOLD, true)
		txt(c, "Reward: $" .. fmt(e.cash) .. (e.rep and ("  •  +" .. e.rep .. " rep") or "") .. (e.keep and ("  •  " .. e.keep) or ""), UDim2.fromOffset(12, 34), UDim2.new(1, -24, 0, 20), 11, SUB)
		for i, t in ipairs(e.tasks) do
			local y = 58 + (i - 1) * 30
			local done = t.have >= t.n
			txt(c, (done and "✅ " or "⬜ ") .. t.text, UDim2.fromOffset(12, y), UDim2.new(0.62, -12, 0, 22), 12, done and GREEN or WHITE)
			local bg = new("Frame", {Position = UDim2.new(0.62, 0, 0, y + 6), Size = UDim2.new(0.25, 0, 0, 10), BackgroundColor3 = RGB(50, 54, 70), BorderSizePixel = 0}, c)
			corner(bg, 5)
			corner(new("Frame", {Size = UDim2.fromScale(math.clamp(t.have / t.n, 0, 1), 1), BackgroundColor3 = done and GREEN or BLUE, BorderSizePixel = 0}, bg), 5)
			txt(c, t.have .. "/" .. t.n, UDim2.new(0.88, 0, 0, y), UDim2.new(0.12, -10, 0, 22), 12, SUB)
		end
		local by = 58 + #e.tasks * 30 + 6
		if e.claimed then
			txt(c, "🎁 Claimed!", UDim2.fromOffset(12, by + 8), UDim2.new(1, -24, 0, 22), 14, GREEN, true)
		else
			btn(c, e.ready and "🎁 Claim reward" or "Finish all three to claim", UDim2.new(0, 12, 0, by), UDim2.new(1, -24, 0, 38), e.ready and GREEN or GRAY, function()
				if e.ready then act("occasionClaim", e.id) end
			end, "Claim_" .. e.key)
		end
	end
	if #info.upcoming > 0 then
		local h = card(m.body, 30, nx(), RGB(26, 28, 40))
		txt(h, "🗓️ COMING UP", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
		for _, u in ipairs(info.upcoming) do
			local c = card(m.body, 34, nx())
			txt(c, u.icon .. "  " .. u.name .. "  —  in " .. u.inDays .. " day" .. (u.inDays == 1 and "" or "s"), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 13, WHITE)
		end
	end
	if #info.keep > 0 then
		local c = card(m.body, 40, nx(), RGB(26, 28, 40))
		txt(c, "🏅 Keepsakes: " .. table.concat(info.keep, "  •  "), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 1, -12), 12, GOLD)
	end
end
JU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("occasionInfo")
	end
end

-- ===== 🧭 NEXT STEP card =====
local nc = panel({Position = UDim2.new(1, -12, 1, -372), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(290, 106), BackgroundColor3 = RGB(26, 46, 60), Visible = false}, gui)
stroke(nc, RGB(120, 220, 255), 2, 0)
nc.Name = "NextStepCard"
Lay.slot(nc, "top", 7)
local nt = label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = RGB(150, 230, 255), TextXAlignment = Enum.TextXAlignment.Left}, nc)
local nd = label({Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 46), TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, nc)
local show = button({Position = UDim2.new(0, 8, 1, -30), Size = UDim2.new(0.6, -12, 0, 26), Text = "👉 Show me", TextSize = 12, BackgroundColor3 = BLUE}, nc)
show.Name = "NextStepShow"
local later = button({Position = UDim2.new(0.6, 0, 1, -30), Size = UDim2.new(0.4, -8, 0, 26), Text = "Later", TextSize = 12, BackgroundColor3 = GRAY}, nc)
later.Name = "NextStepLater"
show.MouseButton1Click:Connect(function()
	play(SND.click)
	local s = JU.step
	if s and s.app then C.openModal(s.app, true) end
end)
later.MouseButton1Click:Connect(function() play(SND.click) act("onboardSkip") end)
JU.card = nc
local function renderStep()
	local s = JU.step
	if type(s) ~= "table" or s.finished then nc.Visible = false return end
	nt.Text = "🧭 NEXT STEP " .. s.step .. "/" .. s.total .. ": " .. s.icon .. " " .. s.title
	nd.Text = s.locked and ("🔒 Needs " .. s.need .. " reputation. Tap Later to skip it for now.") or (s.text .. "  (+$" .. fmt(s.reward) .. ")")
	show.Visible = s.app ~= nil and not s.locked
	nc.Visible = true
end

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "occasions" and type(a) == "table" then
		JU.info = a
		if m.frame.Visible then render() end
	elseif kind == "onboard" and type(a) == "table" then
		JU.step = a
		renderStep()
	elseif kind == "onboardDone" and type(a) == "table" then
		if C.jingle then C.jingle("success", 0.35) end
	end
end)
end
