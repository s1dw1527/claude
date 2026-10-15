-- v16.1: the BOLD UI. Chunky outlined buttons everywhere, a colored title banner and one red X on every window
-- (and the X closes it), the tabbed 🛒 Store (a Robux pill per pass that matches the catalog, OWNED when owned),
-- glossy phone tiles with a lock that matches what's locked, the level bar's % = real reputation progress,
-- and Settings values colored ON/OFF. Simulated engine: this checks the structure, not how it looks in Studio.
-- Run with: python3 tests/run.py tests/style_test.lua
H.main(function()
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	T.quietOnboarding(d)
	d.tut = 0
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	H.task.wait(2)
	local gui = cc.gui
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function shown(x)
		local o = x
		while o and o.ClassName ~= "ScreenGui" do
			if o.Visible == false then return false end
			o = o.Parent
		end
		return true
	end
	local function outline(x)
		local s = x:FindFirstChild("Outline")
		return s and s.ClassName == "UIStroke" and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and s
	end

	H.section("Chunky outlined buttons")
	local total, plain = 0, {}
	local function scan(root, where)
		for _, x in ipairs(root:GetDescendants()) do
			if x.ClassName == "TextButton" and shown(x) and x.BackgroundTransparency < 0.5 then
				total += 1
				if not outline(x) then table.insert(plain, where .. ":" .. x.Name .. " \"" .. tostring(x.Text):sub(1, 16) .. "\"") end
			end
		end
	end
	scan(gui, "HUD")
	local windows = 0
	for key, m in pairs(cc.modals) do
		if key ~= "admin" then
			cc.closeModals()
			cc.openModal(key, true)
			H.task.wait(0.4)
			if m.frame.Visible then
				windows += 1
				scan(m.frame, key)
			end
		end
	end
	cc.closeModals()
	-- (the compact phone-layout pills and a few icon buttons draw their own frame: allow a small handful)
	if #plain > 0 then print("buttons without the outline: " .. table.concat(plain, ", ")) end
	H.check(total > 150 and #plain <= math.floor(total * 0.03), string.format("%d buttons on the HUD and in %d windows: %d have the thick dark outline", total, windows, total - #plain))

	H.section("Windows: a title banner and one red X that closes it")
	local bad = {}
	for key, m in pairs(cc.modals) do
		local band = m.frame:FindFirstChild("TitleBand")
		local xs = 0
		for _, x in ipairs(m.frame:GetChildren()) do if x.Name == "CloseX" then xs += 1 end end
		if not band then table.insert(bad, key .. " no banner") end
		if xs ~= 1 or m.close.Name ~= "CloseX" then table.insert(bad, key .. " close x" .. xs) end
		if m.title.Font ~= Enum.Font.FredokaOne or (m.title.TextStrokeTransparency or 1) >= 0.6 then table.insert(bad, key .. " title") end
	end
	H.check(#bad == 0, "every window (" .. windows .. ") has its colored banner, a chunky outlined title and exactly one red X" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
	H.check(cc.modals.passes.frame.TitleBand.BackgroundColor3 == cc.WINDOW_COLORS.passes and cc.modals.heists.frame.TitleBand.BackgroundColor3 == cc.WINDOW_COLORS.heists,
		"each window has its own banner color (Store purple, Heists red)")
	local closedAll = true
	for key, m in pairs(cc.modals) do
		if key ~= "admin" then
			cc.closeModals()
			cc.openModal(key, true)
			H.task.wait(0.3)
			if m.frame.Visible then
				click(m.close)
				if m.frame.Visible then closedAll = false print("X didn't close " .. key) end
			end
		end
	end
	H.check(closedAll, "the X closes every window")

	H.section("The 🛒 Store")
	cc.openModal("passes", true)
	H.task.wait(0.6)
	local st = cc.modals.passes.frame
	local function f(n) for _, x in ipairs(st:GetDescendants()) do if x.Name == n then return x end end end
	H.check(f("Tab_all") and f("Tab_money") and f("Tab_perks") and f("Tab_all"):GetAttribute("Selected") == true, "tabs: ⭐ All / 💵 Money / 🏎️ Perks (All selected)")
	local priced = true
	for _, p in ipairs(C.PASSES) do
		local card, pill = f("Pass_" .. p.key), f("Buy_" .. p.key)
		if not (card and pill and pill.Text == "R$ " .. p.price and pill:GetAttribute("Pill") == "robux" and card.Visible) then priced = false print("pass", p.key, pill and pill.Text) end
	end
	H.check(priced, "a card for each of the " .. #C.PASSES .. " passes with its Robux price pill, straight from the catalog")
	click(f("Tab_money"))
	H.check(f("Pass_x2").Visible and f("Pass_vip").Visible and not f("Pass_goldcar").Visible and not f("Pass_shield").Visible and f("Tab_money"):GetAttribute("Selected") == true,
		"💵 Money shows the money passes only")
	click(f("Tab_perks"))
	H.check(f("Pass_goldcar").Visible and f("Pass_nitro").Visible and not f("Pass_x2").Visible, "🏎️ Perks shows the others")
	click(f("Tab_all"))
	local all = true
	for _, p in ipairs(C.PASSES) do if not f("Pass_" .. p.key).Visible then all = false end end
	H.check(all, "⭐ All shows them all again")
	-- owning one
	d.passes.nitro = true
	H.task.wait(2)
	H.check(f("Buy_nitro").Text == "✔ OWNED" and f("Buy_nitro"):GetAttribute("Pill") == "off" and f("Buy_x2").Text == "R$ " .. C.PASSES[1].price, "an owned pass shows a grey ✔ OWNED pill; the rest keep their price")
	cc.closeModals()

	H.section("Phone tiles")
	cc.togglePhone(true)
	cc.phoneView("home")
	H.task.wait(0.6)
	local tiles, ok, lockOK = 0, true, true
	for _, x in ipairs(a.PlayerGui:GetDescendants()) do
		if x.ClassName == "TextButton" and x.Name:sub(1, 4) == "App_" then
			tiles += 1
			if not (outline(x) and x:FindFirstChild("Shine")) then ok = false end
			local glass = x:FindFirstChild("LockGlass")
			if not glass then lockOK = false end
		end
	end
	H.check(tiles >= 30 and ok, tiles .. " glossy app tiles (outline + shine)")
	-- a locked feature: rep low enough that the garage is locked
	local lockedKey
	for _, x in ipairs(a.PlayerGui:GetDescendants()) do
		if x.Name == "App_garage" then lockedKey = x end
	end
	H.check(lockOK and lockedKey and lockedKey.LockGlass.Visible == (cc.locked("cars") == true), "the 🔒 glass shows exactly when the app is locked (Garage: " .. tostring(cc.locked("cars")) .. ")")
	cc.togglePhone(false)

	H.section("The level bar")
	d.rep = 150
	H.task.wait(2)
	local s = cc.S
	local xp = cc.U.xpBar
	local want = s.nextRep and math.floor(math.clamp((s.rep - s.prevRep) / (s.nextRep - s.prevRep), 0, 1) * 100) .. "%" or "MAX"
	H.check(xp and xp.pct.Text == want and math.abs(xp.fill.Size.X.Scale - (s.nextRep and (s.rep - s.prevRep) / (s.nextRep - s.prevRep) or 1)) < 0.01,
		"⭐ " .. s.tierName .. ": the bar and its % (" .. tostring(xp and xp.pct.Text) .. ") are the real reputation progress")
	d.rep = 1e7
	H.task.wait(2)
	H.check(xp.pct.Text == "MAX" and xp.fill.Size.X.Scale == 1, "top tier: full bar, MAX")

	H.section("Settings and stats")
	cc.openModal("settings", true)
	H.task.wait(0.5)
	local onB, offB
	for _, x in ipairs(cc.modals.settings.frame:GetDescendants()) do
		if x.ClassName == "TextButton" and x.Text == "ON" then onB = x end
		if x.ClassName == "TextButton" and x.Text == "OFF" then offB = x end
	end
	H.check(onB and onB.BackgroundColor3 == cc.GREEN, "ON is green")
	if onB then
		click(onB)
		H.check(onB.Text == "OFF" and onB.BackgroundColor3 == cc.RED, "tap it: OFF, red")
		click(onB)
		H.check(onB.Text == "ON" and onB.BackgroundColor3 == cc.GREEN, "and back: ON, green")
	end
	local _ = offB
	cc.closeModals()
	cc.openModal("empire", true)
	H.task.wait(1.5)
	local trophyRow
	for _, x in ipairs(cc.modals.empire.frame:GetDescendants()) do
		if x.ClassName == "TextLabel" and x.Text == "Trophies" then trophyRow = x.Parent end
	end
	local val
	if trophyRow then for _, x in ipairs(trophyRow:GetDescendants()) do if x.ClassName == "TextLabel" and x.TextColor3 == cc.GOLD then val = x end end end
	H.check(val and val.Text == tostring(cc.S.trophies), "📊 My Empire: Statistics rows with the value in a pill (🏆 Trophies " .. tostring(val and val.Text) .. ")")
	cc.closeModals()

	T.assertClean("style")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
