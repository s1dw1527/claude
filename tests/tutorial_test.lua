-- The whole tutorial, steps 1-7, played through the real client from a fresh save, with extra attention on
-- step 4 (open the phone). Run with: python3 tests/run.py tests/tutorial_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local UIS = H.service("UserInputService")
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local pg = a:FindFirstChild("PlayerGui")
	local pbtn = find(pg, function(x) return x.ClassName == "TextButton" and x.Text == "📱" end)
	local cardOpen = find(pg, function(x) return x.ClassName == "TextButton" and x.Text == "📱 Open Phone" end)
	local function click(btn) H.signalOf(btn, "MouseButton1Click"):Fire() H.task.wait(0.2) end
	local function key(k) H.signalOf(UIS, "InputBegan"):Fire({KeyCode = k, UserInputType = Enum.UserInputType.Keyboard}, false) H.task.wait(0.2) end
	local function card() return cc.S and cc.S.tut end
	local function waitFor(cond, secs)
		local t = H.now()
		while not cond() and H.now() - t < secs do H.task.wait(0.5) end
		return cond()
	end
	local function buyWhenAffordable(key, secs)
		return waitFor(function()
			if d.cash >= F.upgradeCost(d, key) then T.act(a, "buy", key) end
			return false
		end, 0) or waitFor(function()
			if d.cash >= F.upgradeCost(d, key) then T.act(a, "buy", key) return true end
			return false
		end, secs)
	end
	local paid = {}

	H.section("Steps 1-3: lemonade stand, level 3, ice cream cart (bought with money the game actually earns)")
	H.check(d.tut == 1 and card() and card().step == 1, "a fresh save starts on step 1 and the card shows it")
	H.check(card() and card().progress ~= nil and card().progress ~= "", "step 1 shows a progress line: " .. tostring(card() and card().progress))
	H.check(buyWhenAffordable("lemonade", 60), "the Lemonade Stand is affordable within a minute")
	H.check(waitFor(function() return d.tut == 2 end, 3), "step 1 -> 2 after buying the stand")
	paid[1] = d.tutPaid
	H.check(waitFor(function() if d.cash >= F.upgradeCost(d, "lemonade") then T.act(a, "buy", "lemonade") end return (d.levels.lemonade or 0) >= 3 end, 300), "lemonade reaches level 3 (" .. (d.levels.lemonade or 0) .. ")")
	H.task.wait(1.5)
	H.check(d.tut == 3, "step 2 -> 3")
	print("    step 3 card: " .. tostring(card() and card().progress))
	-- open the phone a moment BEFORE step 4 begins, and leave it open: this is exactly what used to get stuck
	H.check(waitFor(function() return d.cash >= F.upgradeCost(d, "icecream") end, 600), "the Ice Cream Cart becomes affordable")
	cc.togglePhone(true)
	H.task.wait(0.3)
	H.check(d.tut == 3, "(the phone is opened while the server is still on step 3)")
	T.act(a, "buy", "icecream")

	H.section("Step 4: open the phone")
	H.check(waitFor(function() return d.tut == 5 end, 4), "phone opened just before step 4 and left open: step 4 still completes (was stuck forever in v6)")
	H.check(d.tutPaid == 4, "step 4 paid once")
	cc.togglePhone(false)
	H.task.wait(0.5)
	-- now walk step 4 again with each input method, using restart (which re-walks finished steps for free)
	local function toStep4()
		T.act(a, "tut", "restart")
		return waitFor(function() return d.tut == 4 end, 6)
	end
	local cash0 = d.cash
	H.check(toStep4(), "restart walks back to step 4 (steps 1-3 are already done)")
	H.task.wait(2)
	H.check(d.tut == 4, "step 4 waits while the phone is closed")
	H.check(card() and card().step == 4 and card().phone == true, "the card shows step 4 with the Open Phone button")
	H.check(card().progress:find("not opened") ~= nil, "progress says the phone isn't open yet: " .. card().progress)
	H.check(cardOpen ~= nil and cardOpen.Visible, "the card's 📱 Open Phone button is visible")
	click(pbtn)
	H.check(waitFor(function() return d.tut == 5 end, 3), "tapping the 📱 phone button (mouse / touch) completes step 4")
	H.check(d.cash - cash0 < 300, "...and pays nothing the second time (gained $" .. math.floor(d.cash - cash0) .. ")")
	cc.togglePhone(false)
	H.check(toStep4(), "back on step 4")
	H.task.wait(1.5)
	key(Enum.KeyCode.P)
	H.check(waitFor(function() return d.tut == 5 end, 3), "pressing P completes step 4")
	cc.togglePhone(false)
	H.check(toStep4(), "back on step 4")
	H.task.wait(1.5)
	key(Enum.KeyCode.ButtonY)
	H.check(waitFor(function() return d.tut == 5 end, 3), "pressing Y on a controller completes step 4")
	cc.togglePhone(false)
	H.check(toStep4(), "back on step 4")
	H.task.wait(1.5)
	click(cardOpen)
	H.check(waitFor(function() return d.tut == 5 end, 3), "the card's Open Phone button completes step 4")
	cc.togglePhone(false)
	H.task.wait(0.5)
	-- opening and closing the phone during step 4 (between server ticks) still counts
	H.check(toStep4(), "back on step 4")
	H.task.wait(1.5)
	cc.togglePhone(true)
	H.task.wait(0.1)
	cc.togglePhone(false)
	H.check(waitFor(function() return d.tut == 5 end, 3), "a quick open-and-close between server ticks still counts")
	H.check(d.tutPaid == 4, "tutPaid is still 4 after five more completions")

	H.section("Step 4 survives leaving and rejoining")
	H.check(toStep4(), "on step 4")
	F.save(a)
	H.task.wait(1)
	T.act(a, "menuExit")
	H.task.wait(1)
	T.act(a, "menuPlay", 1)
	H.task.wait(3)
	d = T.data(a)
	print("    after rejoin: tut=" .. tostring(d and d.tut) .. " phoneOpen=" .. tostring(d and d.phoneOpen) .. " clientPhone=" .. tostring(cc.phoneOpen()))
	H.check(d and d.tut == 4, "rejoined: still on step 4")
	H.check(d.tutPaid == 4, "rejoined: tutPaid kept")
	H.task.wait(2)
	H.check(d.tut == 4, "rejoined: step 4 doesn't skip itself")
	click(pbtn)
	H.check(waitFor(function() return d.tut == 5 end, 3), "rejoined: opening the phone completes step 4")
	cc.togglePhone(false)

	H.section("Multiplayer: someone else can't finish your steps")
	local b = H.addPlayer("Bob", 202)
	H.task.wait(1.5)
	local db = T.newGame(b, 1, 2)
	db.tut = 4
	db.tutStepAt = os.clock()
	T.act(a, "tut", "phone", true)   -- Alice's phone
	H.task.wait(2)
	H.check(db.tut == 4, "Alice opening her phone doesn't complete Bob's step 4")
	T.act(b, "tut", "phone", true)
	H.task.wait(1.5)
	H.check(db.tut == 5, "Bob opening his own phone does")

	H.section("Step 5: visit your home")
	local lot = F.homeLot(d)
	print("    step 5 card: " .. tostring(card() and card().progress))
	H.check(card() and card().progress:find("studs") ~= nil, "step 5 shows the distance to your home")
	a.Character.HumanoidRootPart.CFrame = CFrame.new(lot.pos + Vector3.new(3, 3, 0))
	H.check(waitFor(function() return d.tut == 6 end, 3), "walking home completes step 5")

	H.section("Step 6: reach LOCAL FAVORITE (earned by running the businesses)")
	local s6 = H.now()
	print("    step 6 card: " .. tostring(card() and card().progress))
	H.check(waitFor(function()
		for _, k in ipairs({"lemonade", "icecream"}) do
			if d.cash >= F.upgradeCost(d, k) and (d.levels[k] or 0) < 5 then T.act(a, "buy", k) end
		end
		for key in pairs(d.problems) do T.act(a, "problem", key, "repair") end
		return d.tut == 7
	end, 1800), "reputation reaches LOCAL FAVORITE from real customer reviews")
	print(string.format("    step 6 took %.1f minutes (rep %d)", (H.now() - s6) / 60, d.rep))

	H.section("Step 7: buy a car and hop in")
	print("    step 7 card: " .. tostring(card() and card().progress))
	-- Bob sits in Alice's car: that must not finish Alice's tutorial
	local cheap = C.CAR.moped
	H.check(waitFor(function() return d.cash >= cheap.price end, 900), "the cheapest car becomes affordable")
	T.act(a, "car", "spawn", "moped")
	H.task.wait(0.5)
	local car = F.activeCar(a)
	H.check(car ~= nil, "Alice's moped spawned")
	if car then
		car.seat.Occupant = b.Character and b.Character:FindFirstChildOfClass("Humanoid")
		H.task.wait(2)
		H.check(d.tut == 7, "Bob sitting in Alice's car doesn't finish her step 7")
		car.seat.Occupant = a.Character:FindFirstChildOfClass("Humanoid")
	end
	H.check(waitFor(function() return d.tut == 0 end, 3), "Alice in her own car finishes the tutorial")
	H.check(d.tutPaid == 7, "all 7 steps paid exactly once (tutPaid = " .. tostring(d.tutPaid) .. ")")
	H.check(card() == nil, "the tutorial card is gone")
	print(string.format("    whole tutorial: %.1f minutes of simulated play", (H.now() - t0) / 60))
	-- step rewards are the only cash that doesn't count as "earned", so cash - earned shows any reward paid
	local c0, e0 = d.cash, d.earned
	T.act(a, "tut", "restart")
	waitFor(function() return d.tut == 4 end, 10)
	cc.togglePhone(true)
	waitFor(function() return d.tut ~= 4 end, 3)
	cc.togglePhone(false)
	waitFor(function() return d.tut == 0 end, 5)
	H.check(d.tut == 0, "a restarted tutorial can be walked to the end again")
	H.check(math.abs((d.cash - c0) - (d.earned - e0)) < 1, "restarting a finished tutorial pays no step rewards (extra $" .. math.floor((d.cash - c0) - (d.earned - e0)) .. ")")
	T.assertClean("the whole tutorial")
	local dbg = 0
	for _, p in ipairs(H.prints) do if tostring(p):find("%[Tutorial%]") then dbg += 1 end end
	H.check(dbg > 0, "Studio debug lines explain why steps are waiting (" .. dbg .. " lines)")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
