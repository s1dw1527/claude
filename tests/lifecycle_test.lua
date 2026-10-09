-- v13: every phone app has a clean lifecycle. Open → close, four times in a row, for EVERY app on the phone's home
-- screen, then app ↔ app switching and a 2-player Arcade round trip. After the first open (which may build its UI
-- once), the number of live event connections and the number of UI objects must stop growing: growth on every
-- open is a leak that eventually makes the phone glitch and slows low-end phones down.
-- Run with: python3 tests/run.py tests/lifecycle_test.lua
H.main(function()
	H.traceConnections = true   -- remember where every connection is made (to group live ones by code line)
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut, db.tut = 0, 0
	-- unlock every app (reputation + a few businesses), and keep the city quiet so only the app under test changes the UI
	d.rep, d.cash = 1e7, 1e9
	for _, b in ipairs(C.BUSINESSES) do d.levels[b.key] = 3 end
	-- CityBuzz shows up to 25 posts: fill it, so a post arriving mid-test replaces one instead of adding a row
	-- (a growing-but-capped feed is content, not a leak)
	for i = 1, 30 do F.buzz("📰", "Test post " .. i, Color3.fromRGB(200, 200, 200)) end
	C.G.nextEvent = H.now() + 1e6
	if C.MEGA_STATE then C.MEGA_STATE.nextAt = H.now() + 1e6 end
	H.task.wait(3)
	calm()
	local gui = a.PlayerGui
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function icons()
		local out = {}
		for _, x in ipairs(gui:GetDescendants()) do
			if x.ClassName == "TextButton" and x.Size.X.Offset == 56 and x.Size.Y.Offset == 56 and x.Parent and x.Parent.Parent and x.Parent.Parent.ClassName == "ScrollingFrame" then
				local name = ""
				for _, l in ipairs(x.Parent:GetChildren()) do if l.ClassName == "TextLabel" then name = l.Text end end
				table.insert(out, {icon = x.Text, name = name})
			end
		end
		return out
	end
	local function iconButton(icon)
		for _, x in ipairs(gui:GetDescendants()) do
			if x.ClassName == "TextButton" and x.Text == icon and x.Size.X.Offset == 56 then return x end
		end
	end
	local function closeAll()
		cc.closeModals()
		if cc.phoneOpen() then cc.togglePhone(false) end
		H.task.wait(0.6)
	end
	-- the apps' own UI: the phone and every window (the HUD around them changes with the game: income pop-ups, rows)
	local function appObjects()
		local n = 0
		local root = gui:FindFirstChild("EmpireUI")
		for _, top in ipairs(root and root:GetChildren() or {}) do
			if top.Name == "Phone" or top.Name:sub(1, 6) == "Modal_" or top.Name == "ArcadeGameWindow" then n += 1 + #top:GetDescendants() end
		end
		return n
	end
	local function measure()
		closeAll()
		H.task.wait(1.2)
		return H.liveConnections, appObjects()
	end
	local function openApp(icon)
		cc.togglePhone(true)
		cc.phoneView("home")
		H.task.wait(0.3)
		local b = iconButton(icon)
		if b then click(b) end
		H.task.wait(1.5)
	end

	cc.togglePhone(true)
	cc.phoneView("home")
	H.task.wait(0.5)
	local apps = icons()
	closeAll()
	H.check(#apps >= 20, "found " .. #apps .. " apps on the phone's home screen")

	H.section("Every app: open → close, eight times")
	-- A leak grows on EVERY open: after two warm-up opens, 6 more opens of the app, then group what is still alive
	-- (live event connections by the code line that made them, UI objects by their path). A line or path that gained
	-- ≥ 1 per open is a leak. Bounded content (CityBuzz showing a few new posts) stays well below that.
	local REOPENS = 6
	local function codeLine(where)
		for line in tostring(where):gmatch("[^\n]+") do
			local m = line:match("EmpireClient%.([%w_]+:%d+)")
			if m and not m:match("^UI:") then return m end
		end
		return "?"
	end
	local function paths()
		local m = {}
		local root = gui:FindFirstChild("EmpireUI")
		for _, top in ipairs(root and root:GetChildren() or {}) do
			if top.Name == "Phone" or top.Name:sub(1, 6) == "Modal_" or top.Name == "ArcadeGameWindow" then
				for _, x in ipairs(top:GetDescendants()) do
					local k = x:GetFullName():gsub("^.-EmpireUI%.", "")
					m[k] = (m[k] or 0) + 1
				end
			end
		end
		return m
	end
	local function liveByLine()
		local m = {}
		for h in pairs(H.connSet) do
			if h.connected then
				local k = codeLine(h.where)
				m[k] = (m[k] or 0) + 1
			end
		end
		return m
	end
	local leaks, opened, worst = {}, 0, 0
	for _, app in ipairs(apps) do
		local before, p0
		for cycle = 1, 2 + REOPENS do
			openApp(app.icon)
			local visible = cc.phoneOpen()
			for _, m in pairs(cc.modals) do if m.frame.Visible then visible = true end end
			if cycle == 1 and visible then opened += 1 end
			closeAll()
			if cycle == 2 then
				H.task.wait(1.2)
				before = liveByLine()
				p0 = paths()
			end
		end
		H.task.wait(1.2)
		for k, n in pairs(liveByLine()) do
			local g = n - (before[k] or 0)
			worst = math.max(worst, g)
			if g >= REOPENS then table.insert(leaks, string.format("%s %s: +%d live connections from %s", app.icon, app.name, g, k)) end
		end
		for k, n in pairs(paths()) do
			local g = n - (p0[k] or 0)
			worst = math.max(worst, g)
			if g >= REOPENS then table.insert(leaks, string.format("%s %s: +%d × %s", app.icon, app.name, g, k)) end
		end
	end
	H.check(opened == #apps, opened .. " / " .. #apps .. " apps open something when tapped")
	H.check(#leaks == 0, "no app leaks on reopen: nothing grows once per open (6 reopens after warm-up; largest growth of one code line or UI element: " .. worst .. ")"
		.. (#leaks > 0 and (":\n      " .. table.concat(leaks, "\n      ")) or ""))

	H.section("Switching apps back and forth")
	local c0, o0 = measure()
	for _ = 1, 3 do
		for _, icon in ipairs({"🕹️", "🗺️", "🕹️", "📱", "👑", "💬", "🏛️", "🕹️"}) do openApp(icon) end
	end
	local c1, o1 = measure()
	for _ = 1, 3 do
		for _, icon in ipairs({"🕹️", "🗺️", "🕹️", "📱", "👑", "💬", "🏛️", "🕹️"}) do openApp(icon) end
	end
	local c2, o2 = measure()
	H.check(c2 - c1 < 24 and o2 - o1 < 24, string.format("24 app switches, twice: connections %d → %d → %d, UI objects %d → %d → %d", c0, c1, c2, o0, o1, o2))
	local modalsOpen = 0
	for _, m in pairs(cc.modals) do if m.frame.Visible then modalsOpen += 1 end end
	H.check(modalsOpen == 0 and not cc.phoneOpen(), "afterwards: no window left open, phone closed")
	cc.togglePhone(true)
	cc.phoneView("home")
	H.task.wait(0.4)
	H.check(#icons() == #apps, "the phone's home screen still has all " .. #apps .. " apps")
	closeAll()

	H.section("Arcade: play the bot, leave, reopen — three times")
	local function arcadeRound()
		openApp("🕹️")
		local play
		for _, x in ipairs(cc.modals.arcadeInfo.body:GetDescendants()) do
			if x.ClassName == "TextButton" and tostring(x.Text):find("PLAY") then play = x break end
		end
		if play then click(play) end
		H.task.wait(3)
		local running = cc.ArcadeUI.win.Visible
		T.act(a, "arcLeave")
		H.task.wait(2)
		return running
	end
	local ran = 0
	if arcadeRound() then ran += 1 end
	local ac1, ao1 = measure()
	if arcadeRound() then ran += 1 end
	if arcadeRound() then ran += 1 end
	local ac2, ao2 = measure()
	H.check(ran == 3, "▶ PLAY started a bot game " .. ran .. " / 3 times")
	H.check(ac2 - ac1 < 2 and ao2 - ao1 < 2, string.format("after 2 more games: connections %d → %d, UI objects %d → %d", ac1, ac2, ao1, ao2))
	H.check(not cc.ArcadeUI.win.Visible, "the game window is closed after leaving")
	openApp("🕹️")
	local arcadeWins = 0
	for _, x in ipairs(gui:GetDescendants()) do if x.ClassName == "TextLabel" and x.Text == "🎟️  ARCADE PRIZES" then arcadeWins += 1 end end
	H.check(cc.modals.arcadeInfo.frame.Visible and arcadeWins == 1, "the Arcade app reopens: one window")
	closeAll()

	T.assertClean("phone app lifecycle")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
