-- v11: the phone's Arcade app (and every phone app that opens a window) has a clean lifecycle:
-- open → one request → active → close → reopen works. Regression test for the v10 bug where opening the Arcade
-- app made the phone UI glitch. Run with: python3 tests/run.py tests/phoneapp_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut, db.tut = 0, 0
	C.G.nextEvent = H.now() + 3600
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	-- how many times the client asked the server for something since `mark`
	local function asks(mark, action)
		local n = 0
		for i = mark + 1, #H.remoteLog do
			local e = H.remoteLog[i]
			if e.name == "Action" and e.dir == "c2s" and e.args[1] == action then n += 1 end
		end
		return n
	end
	local function appButton(icon)
		for _, x in ipairs(a.PlayerGui:GetDescendants()) do
			if x.ClassName == "TextButton" and x.Text == icon and x.Size.X.Offset == 56 then return x end
		end
	end
	local function openArcadeFromPhone()
		cc.togglePhone(true)
		cc.phoneView("home")
		H.task.wait(0.3)
		click(appButton("🕹️"))
	end
	local function arcadeWindows()
		local n = 0
		for _, x in ipairs(a.PlayerGui:GetDescendants()) do
			if x.ClassName == "TextLabel" and x.Text == "🎟️  ARCADE PRIZES" then n += 1 end
		end
		return n
	end
	local info = cc.modals.arcadeInfo

	H.section("Open → Close → Open")
	local mk = #H.remoteLog
	openArcadeFromPhone()
	H.task.wait(5)
	H.check(info.frame.Visible, "the Arcade app opens")
	H.check(asks(mk, "arcInfo") == 1, "it asks the server exactly once (asked " .. asks(mk, "arcInfo") .. " times in 5 s)")
	H.check(not cc.phoneOpen(), "the phone steps aside while the Arcade window is open")
	cc.closeModals()
	H.task.wait(0.5)
	H.check(not info.frame.Visible, "it closes")
	mk = #H.remoteLog
	openArcadeFromPhone()
	H.task.wait(3)
	H.check(info.frame.Visible and asks(mk, "arcInfo") == 1 and arcadeWindows() == 1, "it reopens (one request, one window)")
	local before = #info.body:GetChildren()
	cc.closeModals()
	for _ = 1, 5 do
		openArcadeFromPhone()
		H.task.wait(1)
		cc.closeModals()
	end
	openArcadeFromPhone()
	H.task.wait(1.5)
	H.check(#info.body:GetChildren() == before, "opening it 7 times doesn't pile up rows (" .. before .. " → " .. #info.body:GetChildren() .. ")")

	H.section("Open → switch app → Arcade → switch app → Arcade")
	mk = #H.remoteLog
	cc.togglePhone(true)
	cc.phoneView("buzz")
	H.task.wait(0.5)
	openArcadeFromPhone()
	H.task.wait(1)
	cc.togglePhone(true)
	cc.phoneView("map")
	H.task.wait(0.5)
	H.check(cc.phoneOpen(), "another phone app opens fine after the Arcade")
	openArcadeFromPhone()
	H.task.wait(1)
	cc.togglePhone(true)
	cc.phoneView("messages")
	H.task.wait(0.5)
	openArcadeFromPhone()
	H.task.wait(3)
	H.check(info.frame.Visible and arcadeWindows() == 1 and asks(mk, "arcInfo") == 3, "Arcade ↔ other apps: one window, one request per open (" .. asks(mk, "arcInfo") .. ")")
	cc.closeModals()
	cc.togglePhone(true)
	cc.phoneView("home")
	H.task.wait(0.3)
	H.check(cc.phoneOpen() and appButton("🕹️") ~= nil and appButton("💬") ~= nil, "the phone's home screen is intact")
	cc.togglePhone(false)

	H.section("Every phone window opens with a single request")
	local loops = {}
	for _, key in ipairs({"hq", "garage", "arcadeInfo", "furniture", "manager"}) do
		mk = #H.remoteLog
		cc.closeModals()
		cc.openModal(key)
		H.task.wait(3)
		local n = 0
		for i = mk + 1, #H.remoteLog do if H.remoteLog[i].name == "Action" and H.remoteLog[i].dir == "c2s" then n += 1 end end
		if n > 2 then table.insert(loops, key .. " (" .. n .. ")") end
	end
	cc.closeModals()
	H.check(#loops == 0, "no window keeps re-asking the server" .. (#loops > 0 and (": " .. table.concat(loops, ", ")) or ""))

	H.section("Arcade → start game → leave game → reopen Arcade")
	local zone = H.workspace:FindFirstChild("City"):FindFirstChild("FunZone")
	local pp
	for _, x in ipairs(zone:GetDescendants()) do if x.ClassName == "ProximityPrompt" and x.ActionText == "Play Button Battle" then pp = x end end
	a.Character:PivotTo(CFrame.new(pp.Parent.Position + Vector3.new(0, 3, 5)))
	bob.Character:PivotTo(a.Character:GetPivot())
	H.signalOf(pp, "Triggered"):Fire(a)
	H.signalOf(pp, "Triggered"):Fire(bob)
	H.task.wait(3)
	H.check(cc.ArcadeUI.win.Visible, "a 2-player game is running")
	openArcadeFromPhone()
	H.task.wait(1)
	H.check(info.frame.Visible, "the Arcade app opens during a game")
	T.act(a, "arcLeave")
	H.task.wait(1.5)
	cc.closeModals()
	openArcadeFromPhone()
	H.task.wait(2)
	H.check(info.frame.Visible and arcadeWindows() == 1 and not cc.ArcadeUI.win.Visible, "after leaving the game, the Arcade app reopens cleanly")
	cc.closeModals()

	H.section("Inside an Arcade business, at home, on a phone-sized screen")
	d.levels.arcade = 3
	F.enterInterior(a, a, "arcade")
	openArcadeFromPhone()
	H.task.wait(1.5)
	H.check(info.frame.Visible, "inside an Arcade business")
	cc.closeModals()
	F.leaveInterior(a)
	F.enterInterior(a, a, "home")
	openArcadeFromPhone()
	H.task.wait(1.5)
	H.check(info.frame.Visible, "at home")
	cc.closeModals()
	F.leaveInterior(a)
	local cam = H.workspace.CurrentCamera
	local old = cam.ViewportSize
	rawget(cam, "_p").ViewportSize = old * 0.4
	openArcadeFromPhone()
	H.task.wait(1.5)
	local s = info.scale.Scale
	H.check(info.frame.Visible and s > 0 and s < 1 and s == s, "on a phone-sized screen the window scales to fit (" .. string.format("%.2f", s) .. ")")
	rawget(cam, "_p").ViewportSize = old
	cc.closeModals()

	T.assertClean("phone apps lifecycle")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
