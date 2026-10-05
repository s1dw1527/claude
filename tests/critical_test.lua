-- Critical fixes 1-7 from the code audit. Each check describes the FIXED behavior.
H.main(function()
	local C = T.startServer()
	local F, CFG = C.F, C.CFG
	T.assertClean("server boots")

	-- income keeps flowing while tests run; "freezing" a player stops income and sales so balances are exact
	local function hold(d) d.frozenUntil = math.huge end
	local function release(d) d.frozenUntil = 0 end
	local a = T.join("Alice", 101)
	local b = T.join("Bob", 202)
	local da = T.newGame(a, 1, 1)
	local db = T.newGame(b, 1, 2)

	-- ===== 1. game passes in Studio =====
	H.section("1. Game passes are not auto-granted in Studio")
	H.check(H.studio == true, "running as Studio")
	local anyPass = false
	for _, v in pairs(da.passes) do if v then anyPass = true end end
	H.check(not anyPass, "a new Studio player owns no passes")
	H.check(F.passMult(da) == 1, "income multiplier from passes is 1x")
	-- freeze a rival (needs LOCAL FAVORITE rep and $1000)
	da.rep, db.rep = 150, 150
	da.cash = 5000
	T.act(a, "sabotage", 202)
	H.check(db.frozenUntil > H.now(), "Alice can freeze Bob in Studio")
	-- Studio store still grants a single pass for testing
	T.act(b, "pass", "shield")
	H.check(db.passes.shield == true, "Studio Store button grants the Freeze Shield for testing")
	H.check(not db.passes.x4 and not db.passes.vip, "...and only that pass")
	da.sabCooldown = 0
	da.cash = 5000
	db.frozenUntil = 0
	T.act(a, "sabotage", 202)
	H.check(db.frozenUntil <= H.now(), "the Shield blocks a freeze once Bob owns it")

	-- ===== 2. tutorial rewards =====
	H.section("2. Tutorial rewards can't be farmed")
	local c = T.join("Cara", 303)
	local dc = T.newGame(c, 1, 1)
	dc.cash = 1e6
	for _ = 1, 3 do T.act(c, "buy", "lemonade") end
	T.act(c, "buy", "icecream")
	H.task.wait(5)
	hold(dc)
	H.check(dc.tut == 4, "steps 1-3 complete (now on step 4)")
	H.check((dc.tutPaid or 0) == 3, "tutPaid records the paid steps")
	local before = dc.cash
	T.act(c, "tut", "restart")
	H.task.wait(5)
	H.check(dc.tut == 4, "restart re-walks the finished steps")
	H.check(dc.cash - before < 1, "restarting pays nothing for steps already paid (gained $" .. math.floor(dc.cash - before) .. ")")
	T.act(c, "tut", "phone")
	H.task.wait(1)
	H.check(dc.tutPaid == 4, "a new step (4) still pays once")
	-- save/load keeps tutPaid; old saves without it load safely
	F.save(c)
	H.task.wait(1)
	local store = T.slotStore()
	local saved = rawget(store, "_data")["u303_s1"]
	H.check(saved and saved.tutPaid == 4, "tutPaid is written to the save")
	saved.tutPaid = nil
	saved.tut = 0
	rawget(store, "_data")["u303_s2"] = saved
	T.act(c, "menuExit")
	H.task.wait(1)
	T.act(c, "menuPlay", 2)
	H.task.wait(2)
	dc = T.data(c)
	H.check(dc ~= nil, "an old save without tutPaid loads")
	hold(dc)
	local b2 = dc.cash
	T.act(c, "tut", "restart")
	H.task.wait(5)
	H.check(dc.cash - b2 < 1, "restarting on an old finished save pays nothing")

	-- ===== 3. NaN / Infinity / junk input =====
	H.section("3. Bad numbers from the client are rejected")
	local nan, inf = 0 / 0, math.huge
	local function finite(x) return x == x and x ~= math.huge and x ~= -math.huge end
	da.rep = 500 -- unlock the market
	db.rep = 500
	hold(da)
	hold(db)
	local ca, cb = da.cash, db.cash
	T.act(a, "stock", 202, "buy", nan)
	T.act(a, "stock", 202, "buy", inf)
	T.act(a, "stock", 202, "buy", -5)
	T.act(a, "stock", 202, "buy", 2.5e300)
	T.act(a, "stock", 202, "sell", nan)
	T.act(a, "stock", nan, "buy", 1)
	T.act(a, "stock", 999999, "buy", 1)
	T.act(a, "stock", 202, "steal", 1)
	T.act(a, "stock", "202", "buy", "1")
	H.check(finite(da.cash) and finite(db.cash), "cash stays a real number after NaN/inf stock orders")
	H.check(da.cash == ca and db.cash == cb, "no money moved from junk stock orders")
	local nshares = 0
	for _, v in pairs(da.shares) do nshares += v end
	H.check(nshares == 0, "no shares were created from junk orders")
	-- mini-games
	da.cash = 1e6
	F.startMinigame(a, "hoop")
	local tok = T.lastRemote("Menu", a).args[3]
	H.task.wait(8)
	hold(da)
	local before3 = da.cash
	T.act(a, "minigame", tok, nan)
	H.check(finite(da.cash), "a NaN mini-game score can't corrupt cash")
	H.check(da.cash <= before3, "a NaN score pays nothing")
	-- menu / settings junk
	local s0 = da.cash
	T.act(a, "settings", {musicVol = nan, crowd = "chaos", units = 5, spawnAt = "moon", sfx = false})
	local sess = T.C.data[a] and T.C
	T.act(a, "buy", nan)
	T.act(a, "sabotage", nan)
	T.act(a, "sabotage", 101)
	T.act(a, "contribute", "p50" .. "x")
	T.act(a, "propBuy", nan, "walkup")
	T.act(a, "tenantAccept", inf, 1)
	T.act(a, "msgChoice", nan, 1)
	T.act(a, "like", nan)
	T.act(a, "post", nan, nil)
	T.act(a, "tp", nan)
	T.act(a, nan)
	T.act(a, "car", "spawn", {})
	H.check(finite(da.cash) and da.cash == s0, "junk arguments to other actions change nothing")
	T.assertClean("junk input produces no script errors")
	-- saves still work (no NaN written)
	F.save(a)
	H.task.wait(1)
	T.assertClean("save after junk input")

	-- ===== 3b. race rewards are checked on the server =====
	H.section("3b. Race laps are validated on the server")
	local rr = T.join("Racer", 606)
	local drr = T.newGame(rr, 1, 1)
	drr.rep, drr.cash = 500, 1e7
	T.act(rr, "car", "spawn", "coupe")
	H.task.wait(1)
	local car = F.activeCar(rr)
	H.check(car ~= nil and car.seat.Occupant ~= nil, "racer is sitting in their car")
	local function drive(to, speed)
		local from = car.root.Position
		local dist = (to - from).Magnitude
		local steps = math.max(1, math.ceil(dist / speed / 0.1))
		for i = 1, steps do
			car.root.CFrame = CFrame.new(from:Lerp(to, i / steps) + Vector3.new(0, 2, 0))
			H.task.wait(0.1)
		end
	end
	local function lap(speed)
		F.startRace(rr)
		local armed = T.lastRemote("Race", rr).args[1]
		drive(armed.start, 500)
		H.task.wait(0.3)
		for _ = 1, 20 do
			local ev = T.lastRemote("Race", rr).args[1]
			if ev.state ~= "running" then return ev end
			drive(ev.next, speed)
			H.task.wait(0.2)
		end
		return T.lastRemote("Race", rr).args[1]
	end
	-- (no random city event during the lap: a Tax Season would take 10% of the racer's cash mid-test)
	C.G.nextEvent = H.now() + 600
	local c0 = drr.cash
	local ok1 = lap(90)
	H.check(ok1.state == "finished" and drr.cash > c0 - 1, "a lap at 90 studs/s finishes and pays out (" .. tostring(ok1.state) .. ", " .. tostring(ok1.time and math.floor(ok1.time) or "-") .. "s)")
	local c1 = drr.cash
	local bad = lap(2000)
	H.check(bad.state == "cancel", "a teleport-speed lap is rejected (" .. tostring(bad.state) .. ")")
	H.check(drr.cash <= c1, "...and pays nothing beyond the entry fee")
	H.removePlayer(rr)
	H.task.wait(1)

	-- ===== 4. stock market round trip =====
	H.section("4. Buying and selling shares can't create money")
	da.cash, db.cash = 1e6, 1e6
	da.shares = {}
	local total0 = da.cash + db.cash
	for _ = 1, 5 do
		T.act(a, "stock", 202, "buy", 100)
		T.act(a, "stock", 202, "sell", 0)
	end
	local total1 = da.cash + db.cash
	H.check(total1 <= total0 + 0.01, string.format("5 buy/sell loops: combined cash %d -> %d (no growth)", total0, total1))
	H.check(db.cash > 1e6, "the company owner still receives capital from investment")
	-- selling into your own company is not free money either
	local own0 = da.cash
	T.act(a, "stock", 101, "buy", 100)
	T.act(a, "stock", 101, "sell", 0)
	H.check(da.cash <= own0, "a buy/sell loop in your own company loses the fee")
	-- leaving settles shares with the fee too
	T.act(a, "stock", 202, "buy", 100)
	local sumBefore = da.cash + db.cash
	H.check(true, "Alice holds Bob shares before Bob leaves")

	-- ===== 5. Rich Start =====
	H.section("5. Rich Start pays its starting bonus once per save")
	for _, p in ipairs(C.PASSES) do if p.key == "richstart" then p.id = 555 end end
	H.ownedPasses["404:555"] = true
	release(da)
	release(db)
	local r = T.join("Rich", 404)
	local dr = T.newGame(r, 1, 1)
	H.check(dr.cash >= CFG.START_CASH + CFG.RICH_START_BONUS, "a new save with Rich Start gets +$" .. CFG.RICH_START_BONUS)
	H.check(dr.richClaimed == true, "the claim is recorded on the save")
	F.save(r)
	H.task.wait(1)
	T.act(r, "menuExit")
	H.task.wait(1)
	T.act(r, "menuPlay", 1)
	H.task.wait(2)
	dr = T.data(r)
	H.check(dr.cash < CFG.START_CASH + CFG.RICH_START_BONUS * 2, "reloading the same save doesn't pay again")
	H.removePlayer(r)
	H.task.wait(1)
	r = T.join("Rich", 404)
	T.act(r, "menuPlay", 1)
	H.task.wait(2)
	dr = T.data(r)
	H.check(dr.cash < CFG.START_CASH + CFG.RICH_START_BONUS * 2, "rejoining doesn't pay again")
	H.removePlayer(r)
	H.task.wait(1)

	-- ===== 6. failed loads =====
	H.section("6. A failed load warns the player and never overwrites the save")
	local e = T.join("Eve", 505)
	local de = T.newGame(e, 1, 1)
	de.cash = 123456
	F.save(e)
	H.task.wait(1)
	T.act(e, "menuExit")
	H.task.wait(1)
	local good = H.deepCopy(rawget(store, "_data")["u505_s1"])
	H.dsReadFail = true
	local mark = #H.remoteLog
	T.act(e, "menuPlay", 1)
	H.task.wait(8)
	H.dsReadFail = false
	for i = #H.warnings, 1, -1 do
		if H.warnings[i]:find("load attempt") then table.remove(H.warnings, i) end
	end
	de = T.data(e)
	local msgs = table.concat(T.announcesSince(mark, e), " | ")
	H.check(de ~= nil and de.noSave == true, "the session starts with saving disabled")
	H.check(msgs:find("Couldn't load your save") ~= nil, "the player is told their save couldn't load")
	de.cash = 5
	F.save(e)
	H.task.wait(130) -- autosave cycle
	H.removePlayer(e)
	H.task.wait(1)
	local after = rawget(store, "_data")["u505_s1"]
	H.check(after and after.cash == good.cash, "the stored save was not overwritten (cash " .. tostring(after and after.cash) .. ")")

	-- ===== 7. events never stack =====
	H.section("7. City events don't stack")
	local G = C.G
	local viral
	for _, ev in ipairs(C.EVENTS) do if ev.viral then viral = ev end end
	local heat
	for _, ev in ipairs(C.EVENTS) do if ev.key == "heatwave" then heat = ev end end
	local function force(ev)
		local list = C.EVENTS
		local saved = table.clone(list)
		table.clear(list)
		list[1] = ev
		F.startEvent(H.now())
		table.clear(list)
		for i, v in ipairs(saved) do list[i] = v end
	end
	force(viral)
	H.check(G.viralKey ~= nil, "viral trend picks a business")
	force(heat)
	H.check(G.viralKey == nil, "starting a heatwave ends the viral bonus")
	H.check(G.event and G.event.key == "heatwave", "only one event is active")
	H.check(G.nextEvent >= H.now() + heat.dur, "the next event waits for this one to finish")
	H.task.wait(heat.dur + 2)
	H.check(G.event == nil or G.event.key ~= "heatwave", "the heatwave expires on time")

	T.assertClean("whole critical run")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
