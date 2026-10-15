-- v17: RARE SALES. Odds as configured (✨ Golden 1/250, 💎 Diamond 1/2,500, 🌈 Rainbow 1/25,000), the glowing
-- customer every client sees walk in, the sale multiplied (and the extra capped), the seller's big pop, the server
-- shout only for Diamond and up, CityBuzz for a Rainbow, the counts on the showcase and in the save.
-- Run with: python3 tests/run.py tests/raresale_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
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
	d.tut = 0
	d.frozenUntil = H.now() + 1e7   -- (no income ticks or customers in the middle of exact cash checks)
	d.firstPlay = nil
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local b = T.join("Bob", 202)
	T.newGame(b, 1, 1)
	H.task.wait(1)
	d.levels.lemonade = 5
	local nt = C.NPC_TYPES[1]

	H.section("The odds")
	math.randomseed(42)
	local n, got = 400000, {}
	for _ = 1, n do
		local r = F.rollRare(d)
		if r then got[r] = (got[r] or 0) + 1 end
	end
	local g, dm, rb = got.golden or 0, got.diamond or 0, got.rainbow or 0
	H.check(math.abs(g / n - 1 / 250) < 0.0008 and math.abs(dm / n - 1 / 2500) < 0.0002 and rb < 60,
		string.format("%d rolls: %d golden (~1/%d), %d diamond (~1/%d), %d rainbow", n, g, math.floor(n / math.max(1, g)), dm, math.floor(n / math.max(1, dm)), rb))

	H.section("A golden sale")
	-- the plain sale first (exact, the same call the customer makes)
	d.frozenUntil = 0
	local c0 = d.cash
	F.serveCustomer(a, d, "lemonade", nt, nil, nil)
	local plain = d.cash - c0
	c0 = d.cash
	F.serveCustomer(a, d, "lemonade", nt, nil, "golden", "Classic Lemonade")
	local gold = d.cash - c0
	d.frozenUntil = H.now() + 1e7
	H.check(plain > 0 and math.abs(gold / plain - 10) < 0.01, string.format("✨ GOLDEN pays x10 ($%.2f vs $%.2f)", gold, plain))
	H.check(d.rareSales and d.rareSales.golden == 1, "counted in the save (rareSales.golden = 1)")
	-- the cap
	local cap0 = C.RARE_SALES.capSecs
	C.RARE_SALES.capSecs = 1
	d.frozenUntil = 0
	c0 = d.cash
	F.serveCustomer(a, d, "lemonade", nt, nil, "rainbow")
	local capped = d.cash - c0
	d.frozenUntil = H.now() + 1e7
	C.RARE_SALES.capSecs = cap0
	local ips = F.incomePerSec(d)
	H.check(capped < plain * 250 and capped <= plain + math.max(ips * 1, plain * 2) + 0.01, string.format("the extra is capped (a Rainbow paid $%.2f, not x250)", capped))

	H.section("Everyone sees the glowing customer")
	C.RARE_FORCE = "golden"
	local mark = #H.remoteLog
	F.spawnCustomer(a, d, os.clock())
	C.RARE_FORCE = nil
	local ev
	for _, e in ipairs(T.remotesSince(mark, "Customer")) do if type(e.args[1]) == "table" and e.args[1].rare then ev = e end end
	H.check(ev and ev.dir == "s2all" and ev.args[1].rare == "golden", "the rare customer goes to every client (rare = golden)")
	H.task.wait(0.5)
	local tag
	for _, x in ipairs(H.workspace:GetDescendants()) do if x.ClassName == "TextLabel" and tostring(x.Text):find("GOLDEN CUSTOMER", 1, true) then tag = x end end
	H.check(tag ~= nil, "on screen: a neon, sparkling customer with \"✨ GOLDEN CUSTOMER\" over their head")
	d.frozenUntil = 0
	H.task.wait(ev and (ev.args[1].t + 1.5) or 8)
	d.frozenUntil = H.now() + 1e7
	H.check(d.rareSales.golden == 2, "when they reach the counter, it's a golden sale")

	H.section("The pop and the shout")
	mark = #H.remoteLog
	d.frozenUntil = 0
	F.serveCustomer(a, d, "lemonade", nt, nil, "golden")
	d.frozenUntil = H.now() + 1e7
	H.task.wait(0.5)
	local pop
	for _, x in ipairs(a.PlayerGui:GetDescendants()) do if x.Name == "RareSalePop" then pop = x end end
	H.check(pop and pop.Text:find("GOLDEN SALE", 1, true), "the seller sees a big \"✨ GOLDEN SALE! +$…\"")
	local bobHeard = false
	for _, m in ipairs(T.announcesSince(mark, b)) do if tostring(m):find("GOLDEN", 1, true) then bobHeard = true end end
	H.check(not bobHeard, "a golden sale isn't shouted to the server (it's common enough)")
	mark = #H.remoteLog
	d.frozenUntil = 0
	F.serveCustomer(a, d, "lemonade", nt, nil, "diamond", "Classic Lemonade")
	d.frozenUntil = H.now() + 1e7
	H.task.wait(0.3)
	for _, m in ipairs(T.announcesSince(mark, b)) do if tostring(m):find("DIAMOND", 1, true) and tostring(m):find("Alice", 1, true) then bobHeard = true end end
	H.check(bobHeard, "💎 a DIAMOND sale is shouted to everyone: \"Alice just sold a DIAMOND Classic Lemonade!\"")
	mark = #H.remoteLog
	d.frozenUntil = 0
	F.serveCustomer(a, d, "lemonade", nt, nil, "rainbow")
	d.frozenUntil = H.now() + 1e7
	H.task.wait(0.3)
	local buzz = false
	for _, e in ipairs(H.remoteLog) do
		local post = e.args[1]
		if e.name == "Buzz" and type(post) == "table" and tostring(post.text or ""):find("RAINBOW", 1, true) then buzz = true end
	end
	H.check(buzz, "🌈 a RAINBOW sale makes CityBuzz")

	H.section("Showcase and save")
	local sc = F.showcase(a)
	H.check(sc.rare and sc.rare.golden == 3 and sc.rare.diamond == 1 and sc.rare.rainbow == 2, "the 🪪 showcase shows the lucky sales (3 golden, 1 diamond, 2 rainbow)")
	H.removePlayer(a)
	H.task.wait(3)
	local db = rawget(T.slotStore(), "_data")
	local saved = db["u101_s1"]
	H.check(saved and type(saved.rareSales) == "table" and saved.rareSales.golden == 3, "saved with the slot")

	T.assertClean("raresale")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
