-- ROADMAP UI (v16): the 🗺️ ROADMAP phone app. Seven stages from Street Starter to Empire Legend (built by the
-- server from the game's real rules: GameServer > Roadmap), where you are, what you need for the next one with
-- progress bars, what each stage opens up; your three paths (💼 Mogul, 🕶️ Underworld, 👑 Legend) with levels
-- and titles; your contracts (collect when done); and "change my starting attitude". Reaching a new stage gets a
-- celebration once (the server sends it once). The START CHOICE card after the intro also lives here.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, stroke, panel, corner = C.new, C.label, C.button, C.card, C.clear, C.stroke, C.panel, C.corner
local fmt, play, SND, act, R, gui, U = C.fmt, C.play, C.SND, C.act, C.R, C.gui, C.U
local GOLD, GREEN, GRAY, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local RU = {info = nil}
C.RoadmapUI = RU
local NAVY = RGB(18, 24, 48)

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
local function bar(parent, pos, size, f, color)
	local bg = new("Frame", {Position = pos, Size = size, BackgroundColor3 = RGB(50, 54, 70), BorderSizePixel = 0}, parent)
	corner(bg, 5)
	corner(new("Frame", {Size = UDim2.fromScale(math.clamp(f, 0, 1), 1), BackgroundColor3 = color or BLUE, BorderSizePixel = 0}, bg), 5)
end
local function money(r, v) return r.money and ("$" .. fmt(v)) or fmt(v) end

-- ===== the start choice (after the intro on a new game; again any time from here) =====
local CHOICES = {
	{key = "smart", icon = "💼", name = "PLAY IT SMART", text = "Build your business first: your first goal is a perfect Rush Order.", color = RGB(255, 205, 60)},
	{key = "risk", icon = "🎲", name = "TAKE A RISK", text = "Hit the streets: your first goal is a City Job. Some say the mountain up north hides more...", color = RGB(170, 90, 255)},
	{key = "explore", icon = "🧭", name = "EXPLORE THE CITY", text = "Look around first: Golden Corners, places to discover, the Fun Park.", color = RGB(80, 200, 255)},
}
local choiceM = modal("startChoice", "🏙️  HOW WILL YOU START?", 540, 420)
for i, ch in ipairs(CHOICES) do
	local c = card(choiceM.body, 96, i, NAVY)
	stroke(c, ch.color, 2, 0.2)
	txt(c, ch.icon .. "  " .. ch.name, UDim2.fromOffset(14, 10), UDim2.new(1, -170, 0, 24), 17, ch.color, true)
	txt(c, ch.text, UDim2.fromOffset(14, 38), UDim2.new(1, -170, 0, 50), 12, WHITE)
	btn(c, "Choose", UDim2.new(1, -146, 0.5, -20), UDim2.fromOffset(132, 40), GREEN, function()
		act("startChoice", ch.key)
		choiceM.frame.Visible = false
	end, "Choice_" .. ch.key)
end
local cn = card(choiceM.body, 36, 9, RGB(26, 28, 40))
txt(cn, "This only picks your first goal. Nothing is locked: business, risk or both, any time.", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 11, SUB)
choiceM.update = function() end
function C.openStartChoice() C.openModal("startChoice", true) end

-- ===== the roadmap =====
local m = modal("roadmap", "🗺️  EMPIRE ROADMAP", 580, 660)
local function render()
	local info = RU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local o = 0
	local function nx() o += 1 return o end
	local cur = info.stages[info.stage]
	local nxt = info.stages[info.stage + 1]
	local top = card(m.body, nxt and 120 or 70, nx(), NAVY)
	stroke(top, GOLD, 2, 0.3)
	txt(top, "YOU ARE: " .. cur.icon .. " " .. string.upper(cur.name) .. "   (stage " .. info.stage .. " of " .. #info.stages .. ")", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22), 15, GOLD, true)
	txt(top, cur.text, UDim2.fromOffset(12, 32), UDim2.new(1, -24, 0, 18), 12, SUB)
	if nxt then
		txt(top, "NEXT: " .. nxt.icon .. " " .. nxt.name .. "  •  reaching it pays $" .. fmt(info.reward) .. " + a title", UDim2.fromOffset(12, 54), UDim2.new(1, -24, 0, 18), 12, WHITE, true)
		local y = 76
		for _, r in ipairs(nxt.reqs) do
			if not r.done then
				txt(top, r.label, UDim2.fromOffset(12, y), UDim2.new(0.45, 0, 0, 16), 10, WHITE)
				bar(top, UDim2.new(0.46, 0, 0, y + 3), UDim2.new(0.36, 0, 0, 8), r.have / math.max(1, r.need), GOLD)
				txt(top, money(r, r.have) .. " / " .. money(r, r.need), UDim2.new(0.83, 0, 0, y), UDim2.new(0.17, -8, 0, 16), 9, SUB)
				y += 20
			end
		end
	end
	for _, st in ipairs(info.stages) do
		local c = card(m.body, 74, nx(), st.current and RGB(60, 50, 20) or (st.done and RGB(30, 46, 36) or RGB(30, 32, 44)))
		c.Name = "Stage_" .. st.i
		if st.current then stroke(c, GOLD, 2, 0) end
		txt(c, (st.done and "✅ " or "🔒 ") .. st.i .. ". " .. st.icon .. " " .. st.name, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 14, st.done and WHITE or SUB, true)
		local req = {}
		for _, r in ipairs(st.reqs) do table.insert(req, (r.done and "✓ " or "") .. r.label:gsub("^%S+ ", "") .. " " .. money(r, r.need)) end
		txt(c, #req > 0 and ("Needs: " .. table.concat(req, "  •  ")) or "Where every empire starts.", UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 16), 10, SUB)
		txt(c, "Opens: " .. table.concat(st.unlocks or {}, ", "), UDim2.fromOffset(12, 46), UDim2.new(1, -24, 0, 26), 10, st.done and RGB(170, 230, 170) or RGB(200, 200, 210))
	end
	-- paths
	local p = info.paths
	if type(p) == "table" then
		local h = card(m.body, 30, nx(), RGB(26, 28, 40))
		txt(h, "🛤️ YOUR PATHS (no choice is final: do both!)", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
		for _, path in ipairs(p.paths) do
			local c = card(m.body, 56, nx())
			c.Name = "Path_" .. path.key
			txt(c, path.icon .. " " .. path.name .. "  Lv " .. path.level .. ": " .. path.title, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, WHITE, true)
			if path.nextXP then
				bar(c, UDim2.fromOffset(12, 32), UDim2.new(0.6, 0, 0, 8), (path.xp - path.thisXP) / math.max(1, path.nextXP - path.thisXP), path.key == "under" and PURPLE or GOLD)
				txt(c, fmt(path.xp) .. "/" .. fmt(path.nextXP) .. " XP → " .. tostring(path.nextTitle), UDim2.new(0.62, 6, 0, 28), UDim2.new(0.38, -18, 0, 16), 10, SUB)
			else
				txt(c, "MAX LEVEL", UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 16), 11, GOLD, true)
			end
		end
		if not p.underOpen then
			local c = card(m.body, 36, nx(), RGB(30, 24, 40))
			txt(c, "🕶️ Underworld contracts open when you find what hums inside the mountain up north.", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 1, -12), 11, RGB(200, 170, 255))
		end
		local h2 = card(m.body, 30, nx(), RGB(26, 28, 40))
		txt(h2, "📜 CONTRACTS (" .. p.done .. " done)", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
		for _, ct in ipairs(p.contracts) do
			local c = card(m.body, 60, nx(), ct.done and RGB(30, 50, 36) or nil)
			txt(c, ct.icon .. "  " .. ct.text, UDim2.fromOffset(12, 6), UDim2.new(1, -170, 0, 22), 13, WHITE, true)
			local pr = {}
			for _, x in ipairs(ct.progress) do table.insert(pr, fmt(x.p) .. "/" .. fmt(x.n)) end
			txt(c, table.concat(pr, "  +  "), UDim2.fromOffset(12, 32), UDim2.new(1, -170, 0, 18), 11, SUB)
			btn(c, ct.done and ("📜 Collect $" .. fmt(ct.cash)) or "In progress", UDim2.new(1, -152, 0.5, -18), UDim2.fromOffset(140, 36), ct.done and GREEN or GRAY,
				function() if ct.done then act("contractClaim", ct.slot) end end, "Contract_" .. ct.slot)
		end
	end
	local ch = card(m.body, 50, nx(), RGB(26, 28, 40))
	txt(ch, "Starting attitude: " .. ((p and p.choice) and p.choice or "not chosen"), UDim2.fromOffset(12, 14), UDim2.new(1, -340, 0, 20), 12, SUB)
	btn(ch, "🪪 My showcase", UDim2.new(1, -328, 0.5, -17), UDim2.fromOffset(150, 34), GOLD, function() if C.openShowcase then C.openShowcase(nil) end end, "MyShowcase")
	btn(ch, "🏙️ Change it", UDim2.new(1, -170, 0.5, -17), UDim2.fromOffset(158, 34), BLUE, function() C.openStartChoice() end, "ChangeStart")
end
RU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("roadmapInfo")
	end
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "roadmap" and type(a) == "table" then
		RU.info = a
		if m.frame.Visible then render() end
	elseif kind == "roadmapStage" and type(a) == "table" then
		-- a new stage: celebrated once (the server only sends this when the stage really goes up)
		RU.celebrated = (RU.celebrated or 0) + 1
		if U.confetti then U.confetti(60) end
		if U.splash then U.splash("🗺️ " .. a.icon .. " " .. string.upper(a.name), a.text .. "  •  +$" .. fmt(a.cash) .. "  •  opens: " .. table.concat(a.unlocks or {}, ", "), GOLD) end
		if C.jingle then C.jingle("milestone", 0.5) end
		if m.frame.Visible then act("roadmapInfo") end
	elseif kind == "startChosen" and type(a) == "table" then
		if U.toast then U.toast("🏙️ " .. a.name .. ": " .. a.text) end
		if a.app then task.delay(0.6, function() C.openModal(a.app, true) end) end
	elseif kind == "play" then
		RU.wantChoice = type(a) == "table" and a.isNew == true
	elseif kind == "onboard" and RU.wantChoice and type(a) == "table" then
		-- a new game: once the tutorial is over and the next steps begin, pick how to start (if not chosen yet).
		-- It waits until no window is open and no cutscene is playing, so it never interrupts anything.
		RU.wantChoice = false
		if a.choice then return end
		task.spawn(function()
			for _ = 1, 60 do
				task.wait(2)
				if C.inMainMenu then return end
				local busy = C.cinematicPlaying and C.cinematicPlaying()
				for _, md in pairs(C.modals) do if md.frame.Visible then busy = true end end
				if not busy then
					C.openStartChoice()
					return
				end
			end
		end)
	end
end)
end
