-- v16: the OPENING CINEMATIC. A first-ever account sees it before the save slots; a returning account doesn't
-- (it gets "Welcome back" with Continue / Replay); SKIP from the first frame; the title card's START; replay;
-- only one at a time; an error, a respawn or starting a game mid-intro all clean up (camera, field of view,
-- HUD, controls, parts, effects, connections); introSeen is kept in the account; the title card fits a phone.
-- Simulated engine: this checks the logic and the cleanup, not how it looks (see the Studio checklist).
-- Run with: python3 tests/run.py tests/intro_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local store = T.slotStore()
	local db = rawget(store, "_data")
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(1.5)
	local cc = H.clientC
	local IN = cc.Intro
	local cam = H.workspace.CurrentCamera
	local Lighting = H.service("Lighting")
	local function find(root, pred) for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end end
	local function named(n) return find(a.PlayerGui, function(x) return x.Name == n end) end
	local function click(b) if b then H.signalOf(b, "MouseButton1Click"):Fire() end H.task.wait(0.5) end
	local function leftovers()
		local n = 0
		if H.workspace:FindFirstChild("IntroProps") then n += 1 end
		if H.workspace:FindFirstChild("IntroRain") then n += 1 end
		if Lighting:FindFirstChild("IntroGrade") then n += 1 end
		if named("IntroGui") then n += 1 end
		return n + #IN.conns
	end

	H.section("A first-ever player")
	H.task.wait(0.5)
	H.check(IN.playing == true and named("IntroGui") ~= nil, "a brand-new account: the opening plays before the save slots")
	H.check(named("IntroSkip") and named("IntroSkip").Visible, "SKIP is on screen from the first frame")
	H.check(cam.CameraType == Enum.CameraType.Scriptable and Lighting:FindFirstChild("IntroGrade") ~= nil, "a scripted camera and a night grade")
	local menu = a.PlayerGui:FindFirstChild("MainMenu")
	H.check(menu and menu.Enabled == false, "the save slots wait behind it")
	H.task.wait(2.5)
	local w = named("IntroWords")
	H.check(w and w.Text:find("EVERY EMPIRE STARTS WITH NOTHING", 1, true), "scene 1: \"" .. (w and w.Text or "") .. "\"")
	H.task.wait(3)
	H.check(H.workspace:FindFirstChild("IntroProps") and #H.workspace.IntroProps:GetChildren() > 0, "scene 2 puts a few temporary props in the real city (lemonade stand, alley...)")
	local said = {}
	for _ = 1, 14 do
		said[named("IntroWords") and named("IntroWords").Text or ""] = true
		H.task.wait(0.5)
	end
	H.check(said["BUILD IT LEGIT."] or said["TAKE BIG RISKS."], "scene 2: build it legit / take big risks / rule both sides")
	H.check(said["YOUR CITY. YOUR EMPIRE. YOUR RULES."] or IN.shotIndex >= 7, "scene 3: \"YOUR CITY. YOUR EMPIRE. YOUR RULES.\"")
	H.task.wait(3)
	local title = named("IntroTitle")
	H.check(title and title.Visible and named("IntroStart") and named("IntroSkip2"), "scene 4: the CORNER EMPIRE title card with START MY EMPIRE and SKIP INTRO")
	H.check(find(title, function(x) return x.Name == "Tagline" and x.Text:find("Leave a Legacy", 1, true) end) ~= nil, "\"Build Your Fortune. Risk Everything. Leave a Legacy.\"")
	click(named("IntroStart"))
	H.task.wait(1)
	H.check(not IN.playing and IN.ended == "start" and leftovers() == 0, "START MY EMPIRE: the intro ends and nothing of it is left (gui, props, grade, rain, connections)")
	H.check(menu.Enabled == true, "the save slots appear")
	H.task.wait(1)
	local s = C.data[a]
	local acct = F.acct(a)
	H.check(acct and acct.introSeen == true, "the account remembers it")
	H.task.wait(1)
	H.check(db["u101_meta"] and db["u101_meta"].acct and db["u101_meta"].acct.introSeen == true, "...in the saved account record")
	local _ = s

	H.section("Not forced on returning players")
	T.act(a, "menuNew", 1, 1)
	H.task.wait(3)
	T.quietOnboarding(T.data(a))
	T.act(a, "menuExit")
	H.task.wait(2)
	H.check(not IN.playing, "back at the menu: no intro")
	H.check(named("WelcomeBack") and named("WelcomeBack").Visible and named("ContinueEmpire") and named("ReplayIntro"), "\"Welcome back\": Continue Empire / Replay intro")
	-- a veteran account (saves from before v16) never gets it forced
	local vet = H.addPlayer("Vet", 202)
	db["u202_meta"] = {slots = {s1 = {cash = 5e6, tier = "HOTSPOT", played = 1700000000}}, settings = {}, lastVersion = "15.0.0"}
	H.task.wait(2)
	local vacct = F.acct(vet)
	H.check(vacct and vacct.introSeen == true, "an account with saves from before v16 counts as having seen it")

	H.section("Skip on the first frame, replay, one at a time")
	local fov = cam.FieldOfView
	click(named("ReplayIntro"))
	H.check(IN.playing, "Replay intro plays it again")
	local again = cc.playIntro(true)
	H.task.wait(0.2)
	local guis = 0
	for _, x in ipairs(a.PlayerGui:GetChildren()) do if x.Name == "IntroGui" then guis += 1 end end
	H.check(again == false and guis == 1, "a second request while it plays is ignored (one intro at a time)")
	click(named("IntroSkip"))
	H.task.wait(0.5)
	H.check(not IN.playing and IN.ended == "skip" and leftovers() == 0 and math.abs(cam.FieldOfView - fov) < 0.01, "SKIP straight away: everything cleaned up, field of view back")
	H.check(menu.Enabled == true, "back to the save slots")
	-- keyboard / gamepad skip
	click(named("ReplayIntro"))
	H.task.wait(0.3)
	H.fireInput = H.fireInput
	local UIS = H.service("UserInputService")
	H.signalOf(UIS, "InputBegan"):Fire({KeyCode = Enum.KeyCode.ButtonB, UserInputType = Enum.UserInputType.Gamepad1}, false)
	H.task.wait(0.4)
	H.check(not IN.playing and leftovers() == 0, "the gamepad's B button skips it too")

	H.section("Errors, respawns and starting a game mid-intro")
	IN.failAt = 3
	click(named("ReplayIntro"))
	H.task.wait(6)
	IN.failAt = nil
	H.check(not IN.playing and IN.ended == "error" and leftovers() == 0, "an error in a scene: it stops and cleans up (no leftovers)")
	-- (the simulated failure is reported as a warning, as a real one would be in Studio's Output: that one is expected)
	local keep = {}
	for _, w in ipairs(H.warnings) do if not w:find("simulated intro failure", 1, true) then table.insert(keep, w) end end
	H.warnings = keep
	H.check(menu.Enabled == true, "...and the menu is usable")
	-- playing a save while the intro runs
	click(named("ReplayIntro"))
	H.task.wait(1)
	T.act(a, "menuPlay", 1)
	H.task.wait(3)
	H.check(not IN.playing and leftovers() == 0 and cc.gui.Enabled == true, "starting a game mid-intro ends it cleanly; the HUD is on")
	H.check(cam.CameraType ~= Enum.CameraType.Scriptable or (cc.cinematicPlaying and cc.cinematicPlaying()), "the camera is back to normal")
	-- replay from Settings while playing, then respawn
	cc.playIntro(true)
	H.task.wait(1)
	H.check(IN.playing and cc.gui.Enabled == false and a:GetAttribute("InCinematic") == true, "replayed from Settings in a game: the HUD hides")
	H.signalOf(a, "CharacterAdded"):Fire(a.Character)
	H.task.wait(0.5)
	H.check(not IN.playing and IN.ended == "respawn" and leftovers() == 0 and cc.gui.Enabled == true and a:GetAttribute("InCinematic") == nil,
		"a respawn ends it: HUD, camera and controls back, nothing left behind")
	local settingsRow = false
	cc.openModal("settings", true)
	H.task.wait(0.6)
	settingsRow = find(a.PlayerGui, function(x) return x:IsA("TextLabel") and x.Text:find("Opening movie", 1, true) end) ~= nil
	H.check(settingsRow, "Settings has an \"Opening movie ▶ Replay\" row")
	cc.closeModals()

	H.section("Phone size")
	local function absRect(o)
		local vp = cam.ViewportSize
		local ps, pp = H.G.Vector2.new(vp.X, vp.Y), H.G.Vector2.new(0, 0)
		local chain = {}
		local x = o
		while x and x:IsA("GuiObject") do table.insert(chain, 1, x) x = x.Parent end
		for _, g in ipairs(chain) do
			local w = g.Size.X.Scale * ps.X + g.Size.X.Offset
			local h = g.Size.Y.Scale * ps.Y + g.Size.Y.Offset
			local mc = g:FindFirstChildOfClass("UISizeConstraint")
			if mc then
				local mn, mx = mc.MinSize or H.G.Vector2.new(0, 0), mc.MaxSize or H.G.Vector2.new(1e9, 1e9)
				w, h = math.clamp(w, mn.X, mx.X), math.clamp(h, mn.Y, mx.Y)
			end
			local px = pp.X + g.Position.X.Scale * ps.X + g.Position.X.Offset - g.AnchorPoint.X * w
			local py = pp.Y + g.Position.Y.Scale * ps.Y + g.Position.Y.Offset - g.AnchorPoint.Y * h
			pp, ps = H.G.Vector2.new(px, py), H.G.Vector2.new(w, h)
		end
		return pp.X, pp.Y, ps.X, ps.Y
	end
	rawget(cam, "_p").ViewportSize = H.G.Vector2.new(390, 700)
	cam:GetPropertyChangedSignal("ViewportSize"):Fire()
	cc.playIntro(true)
	H.task.wait(0.3)
	IN.finish("test")   -- (stop, then check the card's layout by showing it directly)
	cc.playIntro(true)
	H.task.wait(0.2)
	named("IntroTitle").Visible = true
	local ok = true
	for _, n in ipairs({"IntroTitle", "IntroStart", "IntroSkip2", "IntroSkip"}) do
		local x, y, w, h = absRect(named(n))
		if x < 0 or y < 0 or x + w > 390 + 0.5 or y + h > 700 + 0.5 then ok = false print("off screen", n, x, y, w, h) end
		if (n == "IntroStart" or n == "IntroSkip2" or n == "IntroSkip") and (w < 44 or h < 36) then ok = false print("too small to tap", n, w, h) end
	end
	H.check(ok, "at 390×700 the title card, START, SKIP fit on screen and are big enough to tap")
	IN.finish("test")
	H.task.wait(0.3)
	H.check(leftovers() == 0, "and cleaned up")

	T.assertClean("intro")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
