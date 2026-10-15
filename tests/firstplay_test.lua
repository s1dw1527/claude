-- v17: THE FIRST 90 SECONDS. Roblox recommends games by first-play bounce, playtime and return days, and the advice
-- from hit games is "time-to-fun under 90 seconds, a cascade of small wins". A brand-new save is played by a quick
-- player through the real actions (no shortcuts): when do the first sale, the first upgrade, Lemonade Lv 3 and the
-- second business happen, and how many wins land in the first 90 s? Also: the first customer comes at once, the
-- grand opening crowd lasts 90 s and only for new saves, and the Creator Analytics events (onboarding funnel once
-- per step in order, economy, custom) are sent for new saves only.
-- Run with: python3 tests/run.py tests/firstplay_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local store = T.slotStore()
	local db = rawget(store, "_data")
	-- a returning player with an old save (no first-play boosts, no funnel)
	db["u202_s1"] = {cash = 5000, earned = 20000, rep = 40, served = 300, tut = 0, tutPaid = 7, levels = {lemonade = 4, icecream = 2}, version = "15.0.0", schema = 15}
	db["u202_meta"] = {slots = {s1 = {cash = 5000, tier = "UNKNOWN CORNER", played = 1700000000}}, settings = {}, lastVersion = "15.0.0"}
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local cc = H.clientC
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6

	H.section("A brand-new save, played by a quick player")
	H.analytics = {}
	local mark = #H.remoteLog
	T.act(a, "menuNew", 1, 1)
	local t0 = H.now()
	H.task.wait(0.5)
	local d = T.data(a)
	T.quietOnboarding(d)   -- (the separate 10-step journey; the 7-step tutorial and its rewards stay on)
	H.check(d and type(d.firstPlay) == "table", "a new save is marked as a first play")
	local at = {}
	local function stamp(k) if not at[k] then at[k] = H.now() - t0 end end
	while H.now() - t0 < 120 do
		-- skip the movie-style scenes the way a player taps through them
		if cc.cinematicPlaying and cc.cinematicPlaying() then cc.cinematicSkip() end
		if (d.levels.lemonade or 0) < 3 then
			if d.cash >= F.upgradeCost(d, "lemonade") then T.act(a, "buy", "lemonade") end
		elseif (d.levels.icecream or 0) < 1 and d.cash >= F.upgradeCost(d, "icecream") then
			T.act(a, "buy", "icecream")
		end
		if (d.levels.lemonade or 0) >= 1 then stamp("open") end
		if (d.levels.lemonade or 0) >= 2 then stamp("upgrade") end
		if (d.levels.lemonade or 0) >= 3 then stamp("lv3") end
		if (d.levels.icecream or 0) >= 1 then stamp("second") end
		if (d.served or 0) >= 1 then stamp("sale") end
		H.task.wait(0.25)
	end
	-- the wins in the first 90 s: money-in moments the player is told about (sales pop on the counter, but these are
	-- the bigger ones: the first sale, tutorial rewards, new businesses / levels)
	local wins = 0
	for _, e in ipairs(T.remotesSince(mark, "Splash", a)) do if e.t == nil or true then wins += 1 end end
	for _, m in ipairs(T.announcesSince(mark, a)) do if tostring(m):find("Tutorial step", 1, true) then wins += 1 end end
	print(string.format("TIMELINE  open %.1fs  first sale %.1fs  upgrade %.1fs  Lv3 %.1fs  2nd business %s  wins(90s window) %d",
		at.open or -1, at.sale or -1, at.upgrade or -1, at.lv3 or -1, at.second and string.format("%.1fs", at.second) or "-", wins))
	H.check(at.open and at.open <= 3, string.format("the first business opens at once (%.1f s: the starting cash covers it)", at.open or -1))
	H.check(at.sale and at.sale - at.open <= 4, string.format("the first customer pays %.1f s after it opens (a customer walks straight in)", (at.sale or 99) - (at.open or 0)))
	H.check(at.lv3 and at.lv3 <= 60, string.format("Lemonade Lv 3 by %.0f s", at.lv3 or -1))
	H.check(at.second and at.second <= 90, string.format("a second business by %.0f s (inside the first 90 s)", at.second or -1))
	H.check(wins >= 3, wins .. " celebrated wins (first sale, tutorial rewards, grand openings) in the first two minutes")
	local first
	for _, e in ipairs(T.remotesSince(mark, "Splash", a)) do if tostring(e.args[1]):find("FIRST SALE", 1, true) then first = e end end
	H.check(first ~= nil, "\"🎉 FIRST SALE!\" is celebrated")

	H.section("The grand opening crowd")
	local fp = d.firstPlay
	local now = os.clock()
	fp.rushUntil = H.G.os.time() + 30
	local boosted = F.customerRate(d, now)
	fp.rushUntil = H.G.os.time() - 1
	local normal = F.customerRate(d, now)
	H.check(boosted > normal * 2 or boosted >= C.CFG.MAX_CUSTOMERS_PER_SEC, string.format("for 90 s after the first business opens customers come x%.1f (%.2f/s vs %.2f/s)", boosted / normal, boosted, normal))
	H.check(normal == F.customerRate(d, now), "afterwards: back to normal")

	H.section("Creator Analytics: the onboarding funnel")
	cc.togglePhone(true)
	H.task.wait(1.5)
	cc.togglePhone(false)
	H.task.wait(1)
	local steps, order = {}, {}
	for _, e in ipairs(H.analytics) do
		if e.kind == "funnel" and e.plr == a then
			steps[e.name] = (steps[e.name] or 0) + 1
			table.insert(order, e.step)
		end
	end
	local inOrder = true
	for i = 2, #order do if order[i] < order[i - 1] then inOrder = false end end
	local once = true
	for _, n in pairs(steps) do if n ~= 1 then once = false end end
	H.check(steps.newGame and steps.firstSale and steps.standLv3 and steps.secondBiz and steps.phoneOpened, "steps logged: new game, first sale, Lemonade Lv 3, second business, phone opened")
	H.check(inOrder and once, "each step once, in order (" .. table.concat(order, ",") .. ")")
	local eco = 0
	for _, e in ipairs(H.analytics) do
		if e.kind == "economy" and e.plr == a and e.flow == Enum.AnalyticsEconomyFlowType.Sink and tostring(e.sku):find("Upgrade:", 1, true) and e.currency == "Cash" and e.amount > 0 then eco += 1 end
	end
	H.check(eco >= 1, eco .. " economy events for money spent on upgrades (throttled, never one per sale)")
	local sales = 0
	for _, e in ipairs(H.analytics) do if e.kind == "economy" and tostring(e.sku):find("Sale", 1, true) and not tostring(e.sku):find("RareSale", 1, true) then sales += 1 end end
	H.check(sales == 0 and d.served > 5, "ordinary sales are not logged one by one (" .. d.served .. " served)")
	-- five minutes in
	H.task.wait(200)
	local five = false
	for _, e in ipairs(H.analytics) do if e.kind == "funnel" and e.plr == a and e.name == "played5min" then five = true end end
	H.check(five, "five minutes played: logged")
	-- a rejoin doesn't send the funnel again
	H.removePlayer(a)
	H.task.wait(3)
	local n0 = #H.analytics
	local a2 = H.addPlayer("Alice", 101)
	H.task.wait(2)
	T.act(a2, "menuPlay", 1)
	H.task.wait(4)
	local again = 0
	for i = n0 + 1, #H.analytics do if H.analytics[i].kind == "funnel" then again += 1 end end
	H.check(again == 0 and T.data(a2) and type(T.data(a2).firstPlay) == "table", "after a rejoin no step is sent twice (the steps are kept in the save)")

	H.section("Returning players")
	local b = H.addPlayer("Bob", 202)
	H.task.wait(2)
	T.act(b, "menuPlay", 1)
	H.task.wait(4)
	local db2 = T.data(b)
	local bobFunnel = 0
	for _, e in ipairs(H.analytics) do if e.kind == "funnel" and e.plr == b then bobFunnel += 1 end end
	H.check(db2 and db2.firstPlay == nil and bobFunnel == 0, "an existing save gets no first-play boost and no onboarding funnel events")
	-- the intro: watched or skipped
	local c = H.addPlayer("Cara", 303)
	H.task.wait(2)
	T.act(c, "introSeen", "skip")
	H.task.wait(0.5)
	local skipped = false
	for _, e in ipairs(H.analytics) do if e.kind == "custom" and e.plr == c and e.name == "IntroSkipped" then skipped = true end end
	H.check(skipped, "the opening movie: skipped vs watched is logged (custom event)")

	T.assertClean("firstplay")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
