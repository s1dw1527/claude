-- v11.1: the responsive (mobile) layout. Run with: python3 tests/run.py tests/mobile_test.lua
-- The simulated engine has no renderer, so this test computes every element's on-screen rectangle itself (Position,
-- Size, AnchorPoint, UIScale, UIPadding, UIListLayout and UIGridLayout) and checks the layout at real phone sizes.
-- It can't see text that's wider than its label, real fonts, the real safe area or real touch controls: those are on
-- the Studio checklist.
H.main(function()
	local V2 = H.G.Vector2.new
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	T.newGame(bob, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut = 0
	C.G.nextEvent = H.now() + 3600
	H.task.wait(2)
	local L = cc.Layout
	local gui = cc.gui
	local cam = H.workspace.CurrentCamera
	local function setViewport(w, h)
		rawget(cam, "_p").ViewportSize = V2(w, h)
		cam:GetPropertyChangedSignal("ViewportSize"):Fire()
		H.task.wait(0.3)
	end
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end

	-- ===== geometry =====
	local function scaleOf(o)
		for _, ch in ipairs(o:GetChildren()) do if ch.ClassName == "UIScale" then return ch.Scale end end
		return 1
	end
	local function layoutOf(o)
		for _, ch in ipairs(o:GetChildren()) do
			if ch.ClassName == "UIListLayout" or ch.ClassName == "UIGridLayout" then return ch end
		end
	end
	local function paddingOf(o)
		for _, ch in ipairs(o:GetChildren()) do
			if ch.ClassName == "UIPadding" then return ch end
		end
	end
	local function isGui(o) return o.ClassName == "Frame" or o.ClassName == "TextLabel" or o.ClassName == "TextButton" or o.ClassName == "ScrollingFrame" or o.ClassName == "TextBox" or o.ClassName == "ImageLabel" or o.ClassName == "ImageButton" end
	local rect
	-- the content box of a parent (after UIPadding)
	local function content(p)
		local r = rect(p)
		local pad = paddingOf(p)
		if not pad then return r end
		local function u(x, total) if not x then return 0 end return x.Scale * total + x.Offset * r.k end
		local l, t = u(pad.PaddingLeft, r.w), u(pad.PaddingTop, r.h)
		local rr, b = u(pad.PaddingRight, r.w), u(pad.PaddingBottom, r.h)
		return {x = r.x + l, y = r.y + t, w = r.w - l - rr, h = r.h - t - b, k = r.k}
	end
	local function siblings(p)
		local list = {}
		for i, ch in ipairs(p:GetChildren()) do
			if isGui(ch) and ch.Visible then table.insert(list, {o = ch, i = i}) end
		end
		table.sort(list, function(x, y)
			if x.o.LayoutOrder ~= y.o.LayoutOrder then return x.o.LayoutOrder < y.o.LayoutOrder end
			return x.i < y.i
		end)
		return list
	end
	local function ownSize(o, pr)
		local s = scaleOf(o)
		local S = o.Size
		return (S.X.Scale * pr.w + S.X.Offset * pr.k) * s, (S.Y.Scale * pr.h + S.Y.Offset * pr.k) * s, pr.k * s
	end
	rect = function(o)
		local p = o.Parent
		if not p or p.ClassName == "ScreenGui" or p.ClassName == "PlayerGui" then
			local vp = cam.ViewportSize
			if not p or p.ClassName ~= "ScreenGui" then return {x = 0, y = 0, w = vp.X, h = vp.Y, k = 1} end
			local pr = {x = 0, y = 0, w = vp.X, h = vp.Y, k = 1}
			if o.ClassName == "ScreenGui" then return pr end
			local w, h, k = ownSize(o, pr)
			local P = o.Position
			return {x = P.X.Scale * pr.w + P.X.Offset - o.AnchorPoint.X * w, y = P.Y.Scale * pr.h + P.Y.Offset - o.AnchorPoint.Y * h, w = w, h = h, k = k}
		end
		local pr = content(p)
		local lay = layoutOf(p)
		if lay and lay.ClassName == "UIGridLayout" then
			local cs, pad = lay.CellSize, lay.CellPadding
			local w, h = cs.X.Scale * pr.w + cs.X.Offset * pr.k, cs.Y.Scale * pr.h + cs.Y.Offset * pr.k
			local px, py = pad.X.Scale * pr.w + pad.X.Offset * pr.k, pad.Y.Scale * pr.h + pad.Y.Offset * pr.k
			local per = math.max(1, math.floor((pr.w + px) / (w + px) + 1e-6))
			local idx = 0
			for n, e in ipairs(siblings(p)) do if e.o == o then idx = n end end
			local col, row = (idx - 1) % per, math.floor((idx - 1) / per)
			return {x = pr.x + col * (w + px), y = pr.y + row * (h + py), w = w, h = h, k = pr.k * scaleOf(o)}
		end
		local w, h, k = ownSize(o, pr)
		if lay and lay.ClassName == "UIListLayout" then
			local horiz = lay.FillDirection == H.G.Enum.FillDirection.Horizontal
			local padU = lay.Padding
			local gap = padU.Scale * (horiz and pr.w or pr.h) + padU.Offset * pr.k
			local list = siblings(p)
			local before, total = 0, 0
			for n, e in ipairs(list) do
				local ew, eh = ownSize(e.o, pr)
				local len = horiz and ew or eh
				if e.o == o then before = total end
				total += len + (n < #list and gap or 0)
			end
			local x, y
			if horiz then
				x = pr.x + before
				local va = lay.VerticalAlignment
				y = va == H.G.Enum.VerticalAlignment.Bottom and (pr.y + pr.h - h) or (va == H.G.Enum.VerticalAlignment.Center and (pr.y + (pr.h - h) / 2) or pr.y)
				if lay.HorizontalAlignment == H.G.Enum.HorizontalAlignment.Center and p.ClassName ~= "ScrollingFrame" then x += (pr.w - total) / 2 end
			else
				y = (lay.VerticalAlignment == H.G.Enum.VerticalAlignment.Bottom) and (pr.y + pr.h - total + before) or (pr.y + before)
				local ha = lay.HorizontalAlignment
				x = ha == H.G.Enum.HorizontalAlignment.Center and (pr.x + (pr.w - w) / 2) or (ha == H.G.Enum.HorizontalAlignment.Right and (pr.x + pr.w - w) or pr.x)
			end
			return {x = x, y = y, w = w, h = h, k = k}
		end
		local P = o.Position
		return {x = pr.x + P.X.Scale * pr.w + P.X.Offset * pr.k - o.AnchorPoint.X * w, y = pr.y + P.Y.Scale * pr.h + P.Y.Offset * pr.k - o.AnchorPoint.Y * h, w = w, h = h, k = k}
	end
	local function shown(o)
		local x = o
		while x and x.ClassName ~= "ScreenGui" do
			if x.Visible == false then return false end
			x = x.Parent
		end
		return x == nil or x.Enabled ~= false
	end
	local function inside(r, box, tol)
		tol = tol or 1
		return r.x >= box.x - tol and r.y >= box.y - tol and r.x + r.w <= box.x + box.w + tol and r.y + r.h <= box.y + box.h + tol
	end
	local function overlap(r1, r2)
		local w = math.min(r1.x + r1.w, r2.x + r2.w) - math.max(r1.x, r2.x)
		local h = math.min(r1.y + r1.h, r2.y + r2.h) - math.max(r1.y, r2.y)
		return w > 1 and h > 1
	end
	local function fmtR(r) return string.format("(%d,%d %dx%d)", r.x, r.y, r.w, r.h) end
	local function screen() local vp = cam.ViewportSize return {x = 0, y = 0, w = vp.X, h = vp.Y} end
	-- the HUD pieces that are on screen when no window is open (the "permanent" UI)
	local function hudPieces()
		local out = {}
		local function add(o, name)
			if o and shown(o) then
				local r = rect(o)
				local nm = name or o.Name
				if nm == o.ClassName then
					-- unnamed: say what it is
					local first = ""
					for _, ch in ipairs(o:GetDescendants()) do if (ch.ClassName == "TextLabel" or ch.ClassName == "TextButton") and ch.Text ~= "" then first = ch.Text break end end
					nm = nm .. "'" .. first:sub(1, 24) .. "'" .. fmtR(r)
				end
				table.insert(out, {o = o, name = nm, r = r})
			end
		end
		for _, ch in ipairs(gui:GetChildren()) do
			if isGui(ch) and ch.Visible then
				if ch.Name:match("^Compact") then
					for _, x in ipairs(ch:GetChildren()) do
						if isGui(x) and x.Visible then
							if ch.Name == "CompactHUD" then add(x, x.Name) else add(x, ch.Name .. "/" .. x.Name) end
						end
					end
				-- (toasts and the money float are 1-5 s messages that sit over HUD row 2 on purpose)
				elseif ch.Name ~= "PhoneDim" and ch.Name ~= "MoneyFloat" and ch.ZIndex ~= L.Z.toast and not (ch.Size.X.Scale == 1 and ch.Size.Y.Scale == 1) then
					add(ch, ch.Name)
				end
			end
		end
		return out
	end
	local function majorsOpen()
		local n, names = 0, {}
		for name, o in pairs(L.majors) do
			if o.frame.Visible and (not o.compactOnly or L.compact) then n += 1 table.insert(names, name) end
		end
		return n, table.concat(names, ",")
	end
	local function closeAll()
		cc.togglePhone(false)
		L.CloseAll()
		H.task.wait(0.3)
	end
	-- every visible descendant of a window stays inside it (horizontally; vertically too unless it scrolls)
	local function contentFits(frame)
		local fr = rect(frame)
		local bad = {}
		for _, x in ipairs(frame:GetDescendants()) do
			if isGui(x) and shown(x) then
				local inScroll, inScrollX = false, false
				local p = x.Parent
				while p and p ~= frame do
					if p.ClassName == "ScrollingFrame" then
						inScroll = true
						if p.ScrollingDirection == H.G.Enum.ScrollingDirection.X then inScrollX = true end
					end
					p = p.Parent
				end
				if not inScrollX then
					local r = rect(x)
					local okX = r.x >= fr.x - 2 and r.x + r.w <= fr.x + fr.w + 2
					local okY = inScroll or (r.y >= fr.y - 2 and r.y + r.h <= fr.y + fr.h + 2)
					if not (okX and okY) and #bad < 3 then table.insert(bad, x.ClassName .. "'" .. tostring(x.Text or x.Name):sub(1, 18) .. "' " .. fmtR(r)) end
				end
			end
		end
		return #bad == 0, table.concat(bad, "; ")
	end

	-- ===== DESKTOP: record the classic layout =====
	H.section("Desktop (1280×720): classic layout")
	setViewport(1280, 720)
	H.check(L.mode == "desktop" and not L.compact, "1280×720 is the desktop layout")
	local function find(name) return gui:FindFirstChild(name, true) end
	local KEYS = {"BusinessPanel", "LeaderboardPanel", "PhoneButton", "SettingsButton", "CameraButton", "TutorialCard", "StoryTracker", "Phone", "MegaBar", "ProblemCard", "DeliveryCard", "GuideTip"}
	local desk = {}
	local function u2(v) return string.format("%g,%g,%g,%g", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset) end
	local function snap(o) return {o.Parent.Name, u2(o.Position), u2(o.Size), o.AnchorPoint.X .. "," .. o.AnchorPoint.Y, o.ZIndex} end
	for _, k in ipairs(KEYS) do local o = find(k) if o then desk[k] = snap(o) end end
	local topBar
	for _, ch in ipairs(gui:GetChildren()) do
		if ch.ClassName == "Frame" and ch.Size.X.Offset == 760 and ch.Size.Y.Offset == 86 then topBar = ch end
	end
	H.check(topBar and topBar.Visible and topBar.Position.Y.Offset == 56, "the big top bar is there (760×86 at y=56)")
	H.check(find("BusinessPanel").Visible and find("LeaderboardPanel").Visible, "business panel and leaderboard on screen")
	H.check(not find("CompactHUD").Visible and not find("CompactRow2").Visible and not find("CompactLeft").Visible, "no phone-layout pieces on desktop")
	H.check(not find("BizButton").Visible and not find("BoardButton").Visible and not find("EventChip").Visible, "no edge buttons / chips on desktop")
	H.check(find("PhoneButton").Parent == gui and find("PhoneButton").Size.X.Offset == 74, "the phone button is the classic 74 px one")

	-- ===== PHONES =====
	-- (a grand-opening cinematic or a cutscene hides the HUD for a while: skip it first)
	local function settle()
		local t1 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying() or not gui.Enabled) and H.now() - t1 < 60 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	local function phoneChecks(w, h)
		H.section(string.format("Phone %d×%d", w, h))
		setViewport(w, h)
		closeAll()
		settle()
		H.check(L.compact and L.mode == "phone", "viewport " .. w .. "×" .. h .. " → phone layout")
		H.check(not topBar.Visible and not find("BusinessPanel").Visible and not find("LeaderboardPanel").Visible, "the desktop bar, business panel and leaderboard are off the screen")
		-- the CityBuzz feed (collapsed) and the story chip are showing: the worst case for the HUD
		cc.U.buzzNote({icon = "📣", text = "New player opened a corner!"})
		local tracker = find("StoryTracker")
		tracker.Visible = true
		H.task.wait(0.2)
		local pieces = hudPieces()
		local names = {}
		for _, p in ipairs(pieces) do names[p.name] = true end
		H.check(names.CashPill and names.TierBadge and names["CompactRow2/StoryTracker"] and names["CompactRow2/EventChip"] and names["CompactLeft/BizButton"] and names["CompactLeft/BoardButton"]
			and names["CompactRight/PhoneButton"] and names["CompactRight/SettingsButton"] and names["CompactTopStack/BuzzFeed"], "compact HUD: cash, ⭐ badge, story chip, event chip, 🏪, 🏆, 📱, ⚙️ and the CityBuzz feed")
		local out, ov = {}, {}
		local sc = screen()
		local safe = {x = L.safe.l - 1, y = L.safe.t - 1, w = w - L.safe.l - L.safe.r + 2, h = h - L.safe.t - L.safe.b + 2}
		for i, p in ipairs(pieces) do
			if not inside(p.r, sc) then table.insert(out, p.name .. fmtR(p.r)) end
			if not inside(p.r, safe) then table.insert(out, p.name .. " outside the safe area " .. fmtR(p.r)) end
			for j = i + 1, #pieces do
				if overlap(p.r, pieces[j].r) then table.insert(ov, p.name .. " × " .. pieces[j].name) end
			end
		end
		H.check(#out == 0, "every HUD piece is inside the screen and the safe area" .. (#out > 0 and (": " .. table.concat(out, ", ")) or ""))
		H.check(#ov == 0, "no HUD pieces overlap" .. (#ov > 0 and (": " .. table.concat(ov, ", ")) or ""))
		-- the money row is small: ≤ 34 px tall, and the story / event chips ≤ 26 px
		local rowH = 0
		for _, p in ipairs(pieces) do
			if p.name == "CashPill" or p.name == "TierBadge" then rowH = math.max(rowH, p.r.h) end
		end
		H.check(rowH <= 34, "the money / income / reputation row is " .. rowH .. " px tall")
		-- left buttons: 44 px, evenly spaced
		local lefts = {}
		for _, p in ipairs(pieces) do if p.name:find("^CompactLeft/") then table.insert(lefts, p.r) end end
		table.sort(lefts, function(x, y) return x.y < y.y end)
		local gaps, big = {}, false
		for i, r in ipairs(lefts) do
			if r.w > 44.5 or r.h > 44.5 then big = true end
			if i > 1 then table.insert(gaps, lefts[i].y - (lefts[i - 1].y + lefts[i - 1].h)) end
		end
		local even = #gaps >= 1
		for _, g in ipairs(gaps) do if math.abs(g - gaps[1]) > 1 then even = false end end
		H.check(#lefts >= 2 and not big and even, #lefts .. " left buttons, none bigger than 44 px, equal gaps (" .. table.concat(gaps, ", ") .. ")")
		-- the area where the player, the road and the businesses are: nothing of ours in it
		local area = 0
		local charZone = {x = w * 0.3, y = h * 0.38, w = w * 0.4, h = h * 0.34}
		local inMid = {}
		for _, p in ipairs(pieces) do
			area += p.r.w * p.r.h
			if overlap(p.r, charZone) then table.insert(inMid, p.name) end
		end
		local free = 1 - area / (w * h)
		H.check(free >= 0.7, string.format("%.0f%% of the screen is free for the game world (need ≥ 70%%)", free * 100))
		H.check(#inMid == 0, "the middle of the screen (30–70% across, 38–72% down) is clear" .. (#inMid > 0 and (": " .. table.concat(inMid, ", ")) or ""))
		-- the bottom stays free: nothing but Roblox's own controls (and ours at the right edge above the jump button)
		local jumpTop = h - L.safe.b - L.jumpZone.h
		local inCtl = {}
		for _, p in ipairs(pieces) do
			if p.r.y + p.r.h > jumpTop + 1 then table.insert(inCtl, p.name) end
		end
		H.check(#inCtl == 0, "the bottom band (thumbstick / jump button / action buttons) is free" .. (#inCtl > 0 and (": " .. table.concat(inCtl, ", ")) or ""))

		-- the real tutorial card is off for these checks: the server re-sends its state every second, which would race with forcing cards visible
		d.tut = 0
		H.task.wait(1.2)
		-- run each measurement right after a state packet, so the next one is a full second away
		local gotPacket = false
		cc.onState(function() gotPacket = true end)
		local function afterPacket()
			gotPacket = false
			local t0 = H.now()
			while not gotPacket and H.now() - t0 < 3 do H.task.wait(0.02) end
		end
		-- every notification card, one at a time: in the top-right stack, out of the middle, off the HUD and the right-hand buttons
		local CARDS = {"TutorialCard", "GuideTip", "ProblemCard", "DeliveryCard", "AchievementCard", "RivalBubble", "HouseTourPanel",
			"StoryPill", "BeefPill", "MegaBar", "HeistBagHUD", "PoliceAlertBar", "RacePanel", "InteriorBar", "ViralMomentPopup"}
		local cbad = {}
		local rightCol = {x = L.rightX, y = L.rightColTop, w = L.RSIDE, h = L.rightColH}
		local function stackProblems(o, name)
			local r = rect(o)
			local bad = {}
			if o.Parent ~= L.box.top then table.insert(bad, name .. " is not in the stack (parent " .. tostring(o.Parent) .. ")") end
			if not inside(r, sc) then table.insert(bad, name .. " off screen " .. fmtR(r)) end
			if scaleOf(o) < L.MIN_SCALE - 0.01 then table.insert(bad, name .. " scale " .. scaleOf(o)) end
			if math.abs((r.x + r.w) - (w - L.safe.r)) > 2 then table.insert(bad, name .. " is not against the right edge " .. fmtR(r)) end
			if overlap(r, rightCol) then table.insert(bad, name .. " reaches the right-hand buttons " .. fmtR(r)) end
			return bad, r
		end
		for _, name in ipairs(CARDS) do
			local o = find(name)
			if not o then
				table.insert(cbad, name .. " missing")
			else
				local was = o.Visible
				afterPacket()
				o.Visible = true
				H.task.wait(0.05)
				local bad, r = stackProblems(o, name)
				for _, b in ipairs(bad) do table.insert(cbad, b) end
				if overlap(r, charZone) then table.insert(cbad, name .. " reaches the middle " .. fmtR(r)) end
				for _, p in ipairs(pieces) do
					if p.o ~= o and not p.name:find(name) and not p.name:find("BuzzFeed") and overlap(r, p.r) then table.insert(cbad, name .. " × " .. p.name) end
				end
				o.Visible = was
				H.task.wait(0.05)
			end
		end
		H.check(#cbad == 0, #CARDS .. " notification cards each land in the top-right stack, against the right edge, out of the middle, off the HUD and the right-hand buttons" .. (#cbad > 0 and (": " .. table.concat(cbad, ", ")) or ""))

		-- the stack with everything at once: at most 3 cards, inside the budget, none stacked on another, the rest wait
		local wasVis = {}
		afterPacket()
		for _, name in ipairs(CARDS) do local o = find(name) wasVis[name] = o.Visible o.Visible = true end
		H.task.wait(0.06)
		local shownCards, waiting, rects = {}, 0, {}
		for _, name in ipairs(CARDS) do
			local o = find(name)
			if o.Parent == L.box.top then table.insert(shownCards, name) table.insert(rects, {name = name, r = rect(o)}) else waiting += 1 end
		end
		local feedShown = find("BuzzFeed").Parent == L.box.top and 1 or 0
		H.check(#shownCards + feedShown <= L.STACK_MAX and #shownCards >= 1, #shownCards + feedShown .. " of " .. #CARDS + 1 .. " notifications are in the stack (max " .. L.STACK_MAX .. "); " .. waiting + (1 - feedShown) .. " wait: " .. table.concat(shownCards, ", "))
		local stackBad = {}
		for i, a2 in ipairs(rects) do
			if i > 1 and a2.r.y + a2.r.h > L.stackBottom + 1 then table.insert(stackBad, a2.name .. " runs past the stack's budget") end
			if overlap(a2.r, charZone) then table.insert(stackBad, a2.name .. " reaches the middle") end
			for j = i + 1, #rects do if overlap(a2.r, rects[j].r) then table.insert(stackBad, a2.name .. " × " .. rects[j].name) end end
		end
		H.check(#stackBad == 0, "…inside the stack's budget, not reaching the middle, none on top of another" .. (#stackBad > 0 and (": " .. table.concat(stackBad, ", ")) or ""))
		-- dismiss the shown ones: the waiting ones move up
		-- (wireframe data for docs/mobile_layout_390x700.png: every piece on screen in the busiest state)
		for _, p in ipairs(hudPieces()) do
			print(string.format("WIRE %dx%d|%s|%d|%d|%d|%d", w, h, p.name, p.r.x, p.r.y, p.r.w, p.r.h))
		end
		local first = shownCards[1]
		find(first).Visible = false
		H.task.wait(0.2)
		local nowShown = 0
		for _, name in ipairs(CARDS) do if name ~= first and find(name).Parent == L.box.top then nowShown += 1 end end
		H.check(nowShown >= #shownCards - 1 and nowShown <= L.STACK_MAX, "dismissing one lets the next waiting one in (" .. nowShown .. " still showing)")
		for _, name in ipairs(CARDS) do find(name).Visible = wasVis[name] end
		H.task.wait(0.2)
		-- text in the cards shrinks to fit its box instead of spilling out
		local unscaled = 0
		for _, name in ipairs({"TutorialCard", "GuideTip", "ProblemCard", "DeliveryCard"}) do
			for _, x in ipairs(find(name):GetDescendants()) do
				if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and not x.TextScaled and x.AutomaticSize == H.G.Enum.AutomaticSize.None then unscaled += 1 end
			end
		end
		H.check(unscaled == 0, "text in the tutorial / tip / problem / delivery cards is set to shrink to fit (" .. unscaled .. " fixed-size labels)")

		-- the CityBuzz feed
		local feed = find("BuzzFeed")
		feed.Visible = true
		H.task.wait(0.2)
		local fr = rect(feed)
		H.check(feed.Parent == L.box.top and fr.h <= 28.5 and inside(fr, sc) and not overlap(fr, charZone), "CityBuzz is a one-line feed in the stack when collapsed " .. fmtR(fr))
		local head
		for _, x in ipairs(feed:GetChildren()) do if x.ClassName == "TextButton" and x.Size.Y.Offset == 28 then head = x end end
		click(head)
		local fr2 = rect(feed)
		local rows = 0
		for _, x in ipairs(feed:GetChildren()) do if x.ClassName == "TextLabel" and x.Visible then rows += 1 end end
		H.check(fr2.h > fr.h and inside(fr2, sc) and fr2.y + fr2.h <= h * 0.5 + 1 and fr2.x + fr2.w <= w - L.safe.r + 1, "tapping it opens the latest posts below it " .. fmtR(fr2) .. " (stays above half the screen)")
		H.task.wait(13)
		H.check(rect(feed).h <= 28.5, "it closes again by itself")
		feed.Visible = false
		tracker.Visible = false
		local tr = find("StoryTracker")
		cc.U.toast("💸 Not enough cash for that upgrade yet — keep earning!")
		H.task.wait(0.6)
		local toast
		for _, ch in ipairs(gui:GetChildren()) do if ch.ClassName == "Frame" and ch.ZIndex == L.Z.toast and ch.Visible and ch.Name ~= "MoneyFloat" then toast = ch end end
		H.check(toast and inside(rect(toast), sc) and rect(toast).y + rect(toast).h <= L.hudBottom + 30, "a toast fits the phone, in the top band " .. (toast and fmtR(rect(toast)) or "?"))
		tracker.Visible = true

		-- windows
		local win = {x = w * 0.04 - 1, y = 0, w = w * 0.92 + 2, h = h}
		local function windowOK(frame, label, maxH)
			local r = rect(frame)
			local fits = inside(r, sc) and r.w <= w * 0.92 + 1 and r.h <= h * (maxH or 0.85) + 1
			H.check(frame.Visible and fits, label .. " fits: " .. fmtR(r) .. string.format(" (%.0f%% × %.0f%%)", r.w / w * 100, r.h / h * 100))
			return r
		end
		click(find("BoardButton"))
		windowOK(find("LeaderboardPanel"), "🏆 leaderboard window", 0.7)
		H.check(majorsOpen() == 1, "one window open (" .. select(2, majorsOpen()) .. ")")
		H.check(not L.box.left.Visible and not L.box.row2.Visible and not L.box.top.Visible, "the rest of the HUD steps aside while it's open")
		click(find("BizButton"))
		H.check(not find("LeaderboardPanel").Visible, "opening 🏪 closes the leaderboard (one window at a time)")
		local br = windowOK(find("BusinessPanel"), "🏪 business window")
		local ok, why = contentFits(find("BusinessPanel"))
		H.check(ok, "the business window's content fits its width" .. (ok and "" or (": " .. why)))
		local x = find("BusinessPanel"):FindFirstChild("TextButton")
		for _, b in ipairs(find("BusinessPanel"):GetChildren()) do if b.ClassName == "TextButton" and b.Text == "X" then x = b end end
		local xr = rect(x)
		H.check(x.Visible and inside(xr, br) and xr.w * 1 >= 40, "it has a clear, big close button " .. fmtR(xr))
		click(x)
		H.check(not find("BusinessPanel").Visible and L.box.left.Visible, "closing it brings the HUD back")

		-- the phone
		cc.togglePhone(true)
		H.task.wait(0.4)
		local ph = find("Phone")
		local pr = rect(ph)
		H.check(inside(pr, sc) and pr.w >= w * 0.72 and pr.w <= w * 0.86 and pr.h >= h * 0.68 and pr.h <= h * 0.84,
			string.format("📱 the phone is %.0f%% × %.0f%% of the screen and inside it", pr.w / w * 100, pr.h / h * 100))
		H.check(find("PhoneDim").Visible and not L.box.row2.Visible and not L.box.left.Visible, "the game dims behind it and the HUD steps aside")
		local apps, cut = 0, {}
		for _, b in ipairs(ph:GetDescendants()) do
			if b.ClassName == "TextButton" and b.Size.X.Offset == 56 then
				apps += 1
				local r = rect(b)
				if r.x < pr.x or r.x + r.w > pr.x + pr.w then table.insert(cut, b.Text) end
			end
		end
		H.check(apps >= 21 and #cut == 0, apps .. " app icons, all inside the phone's width (the grid scrolls)")
		for _, view in ipairs({"buzz", "messages", "map", "story", "viral"}) do
			cc.phoneView(view)
			H.task.wait(0.3)
			local bad = {}
			for _, x2 in ipairs(ph:GetDescendants()) do
				if isGui(x2) and shown(x2) then
					local inScrollX = false
					local p = x2.Parent
					while p and p ~= ph do
						if p.ClassName == "ScrollingFrame" and p.ScrollingDirection == H.G.Enum.ScrollingDirection.X then inScrollX = true end
						p = p.Parent
					end
					local r = rect(x2)
					if not inScrollX and (r.x < pr.x - 2 or r.x + r.w > pr.x + pr.w + 2) and #bad < 3 then table.insert(bad, (x2.Text or x2.Name) .. fmtR(r)) end
				end
			end
			H.check(#bad == 0, "phone app '" .. view .. "' fits inside the phone" .. (#bad > 0 and (": " .. table.concat(bad, "; ")) or ""))
		end
		cc.phoneView("home")
		click(find("PhoneDim"))
		H.check(not cc.phoneOpen() and L.box.row2.Visible, "tapping outside the phone closes it and restores the HUD")

		-- every window
		local bad, big = {}, {}
		for key, m in pairs(cc.modals) do
			if key ~= "admin" then
				closeAll()
				cc.openModal(key, true)
				H.task.wait(0.5)
				if m.frame.Visible then
					local r = rect(m.frame)
					if not inside(r, sc) or r.w > w * 0.92 + 1 or r.h > h * 0.85 + 1 then table.insert(bad, key .. fmtR(r)) end
					local fits, why2 = contentFits(m.frame)
					if not fits then table.insert(big, key .. ": " .. why2) end
					if scaleOf(m.frame) < L.MIN_SCALE - 0.01 then table.insert(bad, key .. " text scale " .. scaleOf(m.frame)) end
					local cr = rect(m.close)
					if not inside(cr, r) then table.insert(bad, key .. " close button") end
				end
				local n = majorsOpen()
				if n > 1 then table.insert(bad, key .. " opened with " .. select(2, majorsOpen())) end
			end
		end
		closeAll()
		H.check(#bad == 0, "every window (" .. (function() local n = 0 for _ in pairs(cc.modals) do n += 1 end return n end)() .. ") fits: ≤ 92% wide, ≤ 85% tall, text ≥ 80%, close button inside, one at a time" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
		H.check(#big == 0, "nothing inside a window sticks out of it" .. (#big > 0 and (": " .. table.concat(big, " | ")) or ""))

		-- the Arcade app on this screen: vertical game cards with PLAY
		cc.togglePhone(true)
		cc.phoneView("home")
		for _, b in ipairs(find("Phone"):GetDescendants()) do
			if b.ClassName == "TextButton" and b.Text == "🕹️" and b.Size.X.Offset == 56 then click(b) end
		end
		H.task.wait(2)
		local info = cc.modals.arcadeInfo
		local cards, plays, xs = 0, 0, {}
		for _, c in ipairs(info.body:GetChildren()) do
			if c.Name == "GameCard" then
				cards += 1
				local r = rect(c)
				xs[math.floor(r.x)] = true
				for _, b in ipairs(c:GetChildren()) do if b.Name == "PlayButton" and inside(rect(b), r) then plays += 1 end end
			end
		end
		local cols = 0
		for _ in pairs(xs) do cols += 1 end
		H.check(info.frame.Visible and cards == 4 and plays == 4 and cols == 1, "🕹️ Arcade: 4 game cards stacked vertically, each with a ▶ PLAY button inside it")
		closeAll()
		tracker.Visible = false
	end
	phoneChecks(390, 700)
	phoneChecks(430, 932)
	phoneChecks(393, 852)
	phoneChecks(375, 667)

	H.section("Phone in landscape (844×390)")
	setViewport(844, 390)
	closeAll()
	H.check(L.compact, "a short landscape screen is still the phone layout")
	local out = {}
	for _, p in ipairs(hudPieces()) do if not inside(p.r, screen()) then table.insert(out, p.name) end end
	H.check(#out == 0, "every HUD piece is on screen" .. (#out > 0 and (": " .. table.concat(out, ", ")) or ""))
	cc.togglePhone(true)
	H.task.wait(0.4)
	H.check(inside(rect(find("Phone")), screen()), "the phone fits (scaled as a whole) " .. fmtR(rect(find("Phone"))))
	closeAll()
	cc.openModal("settings")
	H.task.wait(0.4)
	H.check(inside(rect(cc.modals.settings.frame), screen()), "windows fit " .. fmtR(rect(cc.modals.settings.frame)))
	closeAll()

	-- ===== other screens: main menu, story dialogue, chapter card, cinematic banner =====
	H.section("Main menu, story dialogue, cinematics on a phone (390×700)")
	setViewport(390, 700)
	closeAll()
	local pg = a.PlayerGui
	local function fitsScreen(o, label)
		local r = rect(o)
		H.check(o and inside(r, screen()), label .. " fits the screen " .. fmtR(r))
	end
	local mm = pg:FindFirstChild("MainMenu")
	local slots = mm:FindFirstChild("SaveSlots", true)
	fitsScreen(slots, "the main menu's save slots (a swipeable row)")
	H.check(slots.ScrollingDirection == H.G.Enum.ScrollingDirection.X, "save slots scroll sideways on a phone")
	for _, ch in ipairs(mm:GetChildren()) do
		if ch.ClassName == "TextLabel" and ch.Text == "Build a company. Take over the city." then fitsScreen(ch, "the main menu subtitle") end
	end
	local ov
	for _, ch in ipairs(mm:GetDescendants()) do if ch.ClassName == "Frame" and ch.Size.X.Offset >= 300 and ch.Parent and ch.Parent.ClassName == "Frame" and ch.Parent.Size.X.Scale == 1 then ov = ch end end
	if ov then fitsScreen(ov, "the starter-home / delete window") end
	local dlg = pg:FindFirstChild("StoryDialogue", true)
	dlg.Visible = true
	fitsScreen(dlg, "the story dialogue box")
	local okIn = true
	for _, x in ipairs(dlg:GetDescendants()) do
		if isGui(x) and x.Visible and x.ClassName ~= "TextButton" then
			local r = rect(x)
			if not inside(r, rect(dlg), 2) then okIn = false end
		end
	end
	H.check(okIn, "everything in the dialogue box stays inside it")
	dlg.Visible = false
	local card = pg:FindFirstChild("ChapterDoneCard", true)
	card.Visible = true
	H.task.wait(0.2)
	fitsScreen(card, "the chapter-complete card")
	card.Visible = false
	fitsScreen(pg:FindFirstChild("CinematicBanner", true), "the cinematic result banner")

	-- ===== driving =====
	H.section("Driving on a phone (390×700)")
	setViewport(390, 700)
	closeAll()
	local gauge, pedals, ctl = find("Speedometer"), find("Pedals"), find("DriveButtons")
	local pb = rect(find("PhoneButton"))
	local sc = screen()
	local jump = {x = 390 - L.safe.r - L.jumpZone.w, y = 700 - L.safe.b - L.jumpZone.h, w = L.jumpZone.w, h = L.jumpZone.h}
	local mid = {x = 390 * 0.3, y = 700 * 0.38, w = 390 * 0.4, h = 700 * 0.34}
	local thumb = {x = 0, y = 700 - 160, w = 390 * 0.33, h = 160}
	local probs = {}
	for _, e in ipairs({{gauge, "speedometer"}, {pedals, "GAS/BRAKE"}, {ctl, "nitro/drift"}}) do
		local r = rect(e[1])
		if not inside(r, sc) then table.insert(probs, e[2] .. " off screen " .. fmtR(r)) end
		if overlap(r, pb) then table.insert(probs, e[2] .. " under the phone button") end
		if overlap(r, jump) then table.insert(probs, e[2] .. " on the jump button") end
		if overlap(r, mid) then table.insert(probs, e[2] .. " in the middle of the road") end
		if overlap(r, thumb) then table.insert(probs, e[2] .. " on the thumbstick") end
	end
	H.check(#probs == 0, "speedometer, GAS/BRAKE and nitro/drift: on screen, clear of the phone button, the jump button, the thumbstick and the road" .. (#probs > 0 and (": " .. table.concat(probs, ", ")) or ""))
	local pr = rect(pedals)
	H.check(pr.x + pr.w / 2 > 390 / 2 and pr.y > 700 * 0.75, "the pedals are on the lower right " .. fmtR(pr))
	L.setDriving(true)
	H.check(not L.box.row2.Visible and not L.box.left.Visible and L.box.right.Visible and find("CompactHUD").Visible, "while driving: only the money row and the 📱 column stay")
	L.setDriving(false)
	H.check(L.box.row2.Visible and L.box.left.Visible, "after driving the HUD comes back")

	-- ===== Arcade lifecycle on a phone =====
	H.section("Arcade lifecycle on a phone: open → Button Battle → leave → close → reopen")
	local function asks(mark, action)
		local n = 0
		for i = mark + 1, #H.remoteLog do
			local e = H.remoteLog[i]
			if e.name == "Action" and e.dir == "c2s" and e.args[1] == action then n += 1 end
		end
		return n
	end
	local function openArcade()
		cc.togglePhone(true)
		cc.phoneView("home")
		H.task.wait(0.2)
		for _, b in ipairs(find("Phone"):GetDescendants()) do
			if b.ClassName == "TextButton" and b.Text == "🕹️" and b.Size.X.Offset == 56 then click(b) end
		end
	end
	local function count(text)
		local n = 0
		for _, x in ipairs(a.PlayerGui:GetDescendants()) do if x.ClassName == "TextLabel" and x.Text == text then n += 1 end end
		return n
	end
	local function arcadeWindows()
		local n = 0
		for _, x in ipairs(a.PlayerGui:GetDescendants()) do if x.Name == "ArcadeGameWindow" then n += 1 end end
		return n
	end
	local mk = #H.remoteLog
	openArcade()
	H.task.wait(2)
	local info = cc.modals.arcadeInfo
	H.check(info.frame.Visible and asks(mk, "arcInfo") == 1, "the Arcade opens with one request")
	local zone = H.workspace:FindFirstChild("City"):FindFirstChild("FunZone")
	local pp
	for _, x in ipairs(zone:GetDescendants()) do if x.ClassName == "ProximityPrompt" and x.ActionText == "Play Button Battle" then pp = x end end
	a.Character:PivotTo(CFrame.new(pp.Parent.Position + Vector3.new(0, 3, 5)))
	bob.Character:PivotTo(a.Character:GetPivot())
	H.signalOf(pp, "Triggered"):Fire(a)
	H.signalOf(pp, "Triggered"):Fire(bob)
	H.task.wait(3)
	local gw = cc.ArcadeUI.win
	H.check(gw.Visible and not info.frame.Visible, "Button Battle starts: the game window replaces the Arcade window (one big window)")
	H.check(inside(rect(gw), screen()) and rect(gw).w <= 390 * 0.92 + 1, "the game window fits the phone " .. fmtR(rect(gw)))
	local tapB
	for _, b in ipairs(gw:GetDescendants()) do if b.ClassName == "TextButton" and b.Text == "👆 TAP TAP TAP!" then tapB = b end end
	H.check(tapB and inside(rect(tapB), rect(gw)), "the TAP button is inside the window")
	-- leave (the Leave button asks first)
	local quit
	for _, b in ipairs(gw:GetChildren()) do if b.ClassName == "TextButton" and b.Text == "Leave" then quit = b end end
	click(quit)
	local box = find("ConfirmDialog")
	H.check(box.Visible and inside(rect(box), screen()), "\"Leave the game?\" fits the phone " .. fmtR(rect(box)))
	for _, b in ipairs(box:GetChildren()) do if b.ClassName == "TextButton" and b.Text == "Leave" then click(b) end end
	H.task.wait(1.5)
	H.check(not gw.Visible, "left the game")
	closeAll()
	mk = #H.remoteLog
	openArcade()
	H.task.wait(2)
	H.check(info.frame.Visible and count("🎟️  ARCADE PRIZES") == 1 and arcadeWindows() == 1, "reopened: exactly one Arcade window and one game window object")
	H.check(asks(mk, "arcInfo") == 1, "one request on reopen (no duplicate connections)")
	H.check(majorsOpen() == 1, "only the Arcade window is open")
	closeAll()
	cc.togglePhone(true)
	cc.phoneView("messages")
	H.task.wait(0.3)
	H.check(cc.phoneOpen(), "the phone still works afterwards")
	closeAll()

	-- ===== no layout work every frame =====
	H.section("Performance")
	local passes = L.passes
	H.task.wait(10)
	H.check(L.passes == passes, "no layout passes while nothing changes (10 s of state updates)")
	setViewport(392, 700)
	H.check(L.passes == passes + 1, "one pass per viewport change")

	-- ===== back to desktop: unchanged =====
	H.section("Back to desktop: the classic layout is restored exactly")
	setViewport(1280, 720)
	closeAll()
	local diff = {}
	for _, k in ipairs(KEYS) do
		local o = find(k)
		local s = desk[k]
		if o and s then
			local now = snap(o)
			for i = 1, 5 do
				if tostring(now[i]) ~= tostring(s[i]) then table.insert(diff, k .. "#" .. i .. " " .. tostring(s[i]) .. " → " .. tostring(now[i])) end
			end
		end
	end
	H.check(#diff == 0, "positions, sizes, anchors and parents match the original desktop layout" .. (#diff > 0 and (": " .. table.concat(diff, "; ")) or ""))
	H.check(topBar.Visible and find("BusinessPanel").Visible and find("LeaderboardPanel").Visible and not find("CompactHUD").Visible, "big top bar, business panel and leaderboard are back")

	T.assertClean("mobile layout")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
