-- v12: empire value, verified billionaire milestones, the Empire Plaza + Hall of Fame, storefront makeovers,
-- tier grand openings, the first five minutes, and the Empire Hall window.
-- Run with: python3 tests/run.py tests/empire_test.lua
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
	local function calm()
		local t = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut, db.tut = 0, 0
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function inModal(key, pat)
		for _, x in ipairs(cc.modals[key].frame:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end

	H.section("Empire value (server side)")
	H.check(F.empireTier(d) == 0 and F.empireValue(d) >= math.floor(d.cash), "a new save: tier 0, value >= cash")
	local v0 = F.empireValue(d)
	d.cash += 1000
	d.levels.lemonade = 5
	H.check(F.empireValue(d) > v0 + 1000, "upgrades count toward the value")
	local before = F.empireValue(d)
	d.cash -= 500
	d.levels.lemonade = 1
	H.check(F.empireValue(d) < before, "selling/losing things lowers it")
	H.check(select(1, pcall(F.empireValue, {cash = 0 / 0, levels = {}, chains = {}, cars = {}})) == true, "a corrupt save value doesn't crash the calculation")
	local nanV = F.empireValue({cash = 0 / 0, levels = {}, chains = {}, cars = {}})
	H.check(nanV == 0, "NaN cash is worth 0 (" .. tostring(nanV) .. ")")

	H.section("Milestones: verified on the server, paid once")
	d.cash, d.earned = 1.2e6, 0
	local claimed = F.checkEmpire(a, d, H.now())
	H.check(claimed == nil and F.empireTier(d) == 0, "$1M in cash but no real earnings -> NOT claimed (admin/lucky cash can't buy it)")
	d.earned = 1.2e6
	local cash0 = d.cash
	local mark = T.remotesSince and nil
	claimed = F.checkEmpire(a, d, H.now())
	H.check(claimed and #claimed == 1 and claimed[1].key == C.EMPIRE_MILESTONES[1].key, "$1M + real earnings -> MILLIONAIRE claimed")
	H.check(F.empireTier(d) == 1, "tier is 1")
	H.check(d.cash >= cash0 + C.EMPIRE_MILESTONES[1].cash, "the cash reward was paid by the server")
	local cash1 = d.cash
	claimed = F.checkEmpire(a, d, H.now())
	H.check(claimed == nil and d.cash == cash1, "checking again pays nothing (once per save)")
	T.act(a, "empClaim", "m1", 1e12)
	T.act(a, "empInfo", {value = 1e12})
	H.task.wait(0.3)
	H.check(F.empireTier(d) == 1 and d.cash >= cash1 and d.cash < cash1 + 1e6, "the client can't claim or send a value")
	d.cash, d.earned = 2e9, 2e9
	local got = F.checkEmpire(a, d, H.now())
	H.check(got and #got == 3 and F.empireTier(d) == 4, "a huge jump claims the remaining three in order (tier " .. F.empireTier(d) .. ")")
	H.check(d.achievements and d.achievements["empire_" .. C.EMPIRE_MILESTONES[4].key], "the Billionaire achievement is recorded")
	local flag = d.empire.ms[C.EMPIRE_MILESTONES[4].key]
	H.check(type(flag) == "number", "claim times are stored")

	H.section("Rebirth/reset safety: nothing is lost or duplicated")
	d.empire.ms = {x = "bad", [C.EMPIRE_MILESTONES[1].key] = 5}
	H.check(F.empireTier(d) == 1 and d.empire.ms.x == nil, "damaged milestone record is repaired on read")
	d.empire.ms = {}
	for _, m in ipairs(C.EMPIRE_MILESTONES) do d.empire.ms[m.key] = 1 end

	H.section("The living tower")
	F.refreshTower(a, true)
	local tower = d.plot.tower
	H.check(tower ~= nil and (tower:GetAttribute("Top") or 0) > 60, "a billionaire's tower is tall and has a crown (Top " .. tostring(tower and tower:GetAttribute("Top")) .. ")")
	local found = false
	for _, x in ipairs(tower:GetDescendants()) do
		if x.ClassName == "TextLabel" and tostring(x.Text):find("BILLIONAIRE") then found = true end
		if x.ClassName == "BillboardGui" then for _, y in ipairs(x:GetDescendants()) do if y.ClassName == "TextLabel" and tostring(y.Text):find("BILLIONAIRE") then found = true end end end
	end
	H.check(found, "the tower is labelled BILLIONAIRE")
	local db4 = F.empireTier(db)
	H.check(db4 == 0, "another player's tower isn't affected")

	H.section("Storefront makeovers")
	d.empire.ms = {}
	d.cash, d.earned = 100, 100   -- (the server re-checks every few seconds: stay under $1M)
	d.levels.lemonade = 3
	T.act(a, "brand", "lemonade", "style", "modern")
	H.check(d.brands.lemonade and d.brands.lemonade.style == "modern", "a free style applies")
	T.act(a, "brand", "lemonade", "style", "luxury")
	H.check(d.brands.lemonade.style == "modern", "Luxury is refused below $10M (server check)")
	T.act(a, "brand", "lemonade", "style", "nonsense")
	H.check(d.brands.lemonade.style == "modern", "an unknown style is refused")
	d.empire.ms[C.EMPIRE_MILESTONES[1].key] = 1
	d.empire.ms[C.EMPIRE_MILESTONES[2].key] = 1
	T.act(a, "brand", "lemonade", "style", "luxury")
	H.check(d.brands.lemonade.style == "luxury", "Luxury applies at tier 2")
	T.act(a, "brand", "lemonade", "style", "billionaire")
	H.check(d.brands.lemonade.style == "luxury", "Billionaire needs tier 4")
	for _, k in ipairs({"neon", "retro", "modern", "luxury", "classic"}) do
		d.brands.lemonade.style = k
		local ok, err = pcall(F.refreshBuilding, a, "lemonade", false)
		H.check(ok and d.plot.slots.lemonade ~= nil, "style " .. k .. " builds (" .. tostring(err) .. ")")
	end

	H.section("Empire Plaza + Hall of Fame")
	local plaza = H.workspace:FindFirstChild("EmpirePlaza", true)
	H.check(plaza ~= nil and C.PLAZA_AT ~= nil, "the Empire Plaza exists")
	do
		local out, parts, tallest, stand = {}, 0, 0, 0
		for _, x in ipairs(plaza:GetDescendants()) do
			if x:IsA("BasePart") then
				parts += 1
				local p = x.Position
				if math.abs(p.X - C.PLAZA_AT.X) > 70 or math.abs(p.Z - C.PLAZA_AT.Z) > 42 then table.insert(out, x.Name .. string.format(" (%.0f, %.0f)", p.X, p.Z)) end
				local top = p.Y + x.Size.Y / 2
				if p.X > C.PLAZA_AT.X + 10 and p.X < C.PLAZA_AT.X + 34 then tallest = math.max(tallest, top) end
				if p.X < C.PLAZA_AT.X - 20 and p.X > C.PLAZA_AT.X - 32 then stand = math.max(stand, top) end
			end
		end
		H.check(#out == 0 and parts < 150, "all " .. parts .. " plaza parts stay inside its reserved beach site" .. (#out > 0 and (": " .. table.concat(out, ", ")) or ""))
		H.check(stand > 3 and tallest > stand * 10, string.format("the thumbnail shot: a %.0f-stud starter stand beside a %.0f-stud golden tower", stand, tallest))
	end
	d.empire.ms = {}
	for _, m in ipairs(C.EMPIRE_MILESTONES) do d.empire.ms[m.key] = 1 end
	d.cash, d.earned = 3e9, 3e9
	db.cash, db.earned = 5e6, 5e6
	local list = F.hallList(a)
	H.check(#list >= 2 and list[1].userId == 101 and list[2].userId == 102, "the board ranks by value, live for everyone in the server (" .. #list .. " rows)")
	H.check(list[1].tags and list[1].tags:find(C.EMPIRE_MILESTONES[4].tag, 1, true), "verified milestone tags are shown")
	C.updateHallBoard(list)
	local boardText
	for _, x in ipairs(plaza:GetDescendants()) do
		if x.ClassName == "TextLabel" and tostring(x.Text):find("HALL OF FAME") and tostring(x.Text):find("Alice") then boardText = x.Text end
	end
	H.check(boardText ~= nil, "the billboards show the empire names")
	local anyVisit = list[1].canVisit
	H.check(anyVisit == false, "you can't 'visit' yourself")
	H.check(list[2].canVisit ~= nil, "visit flag is computed for others")
	H.check(select(1, pcall(function() T.act(a, "empVisit", 102) T.act(a, "empVisit", -5) T.act(a, "empVisit", "x") end)), "visit requests with bad arguments don't error")

	H.section("Grand openings for major tier unlocks")
	local shown = 0
	local oldC = F.cinematic
	F.cinematic = function(plr, kind, ...) if kind == "opening" then shown += 1 end return oldC(plr, kind, ...) end
	d.openings = {}
	local b = C.BUSINESSES[1]
	local ok1 = F.tierOpening(a, d, b.key, 1, 2)
	local ok2 = F.tierOpening(a, d, b.key, 1, 2)
	F.cinematic = oldC
	H.check(ok1 == true and ok2 == false, "a tier opening plays once per business and building")
	H.check(shown == 1, "one cinematic with a crowd")
	calm()

	H.section("The first five minutes")
	local f1 = T.join("Carol", 103)
	local dc = T.newGame(f1, 1, 1)
	dc.tut = 0
	H.check(dc.empire and dc.empire.firstIncome == false and dc.empire.firstUpgrade == false, "a new save starts with both firsts unclaimed")
	dc.cash = math.max(dc.cash, 100)
	T.act(f1, "buy", "lemonade")
	H.task.wait(0.3)
	H.check((dc.levels.lemonade or 0) >= 1 and dc.empire.firstIncome == false, "buying the stand is not 'first income' yet (the corner's trickle doesn't count)")
	local t0 = H.now()
	while not dc.empire.firstIncome and H.now() - t0 < 60 do H.task.wait(1) end
	H.check(dc.empire.firstIncome == true, "💵 FIRST INCOME fires once the stand itself has made money (" .. math.floor(H.now() - t0) .. " s)")
	F.empireFirst(f1, "income")
	H.check(dc.empire.firstIncome == true, "first income marks once")
	F.empireFirst(f1, "upgrade")
	H.check(dc.empire.firstUpgrade == true, "first upgrade marks once")
	H.check(C.TUTORIAL and #C.TUTORIAL >= 3, "tutorial steps exist")
	for i = 1, 3 do H.check(#C.TUTORIAL[i].text <= 100, "tutorial step " .. i .. " is short enough for a phone (" .. #C.TUTORIAL[i].text .. " chars)") end

	H.section("Empire Hall window")
	T.act(a, "empInfo")
	H.task.wait(0.6)
	H.check(cc.modals.empireHall and cc.modals.empireHall.frame.Visible, "the Empire Hall opens")
	H.check(inModal("empireHall", "Your empire is worth") ~= nil, "it shows the value")
	click(inModal("empireHall", "Milestones"))
	H.check(inModal("empireHall", "BILLIONAIRE") ~= nil, "the milestones tab lists all four")
	click(inModal("empireHall", "Makeovers"))
	H.check(inModal("empireHall", "Neon Nights") ~= nil, "the makeovers tab lists the styles")
	click(inModal("empireHall", "Hall of Fame"))
	H.check(inModal("empireHall", "Alice") ~= nil or inModal("empireHall", "Empire") ~= nil, "the Hall of Fame tab lists empires")

	H.section("Admin celebration test")
	H.check(C.EMPIRE_ADMIN and type(C.EMPIRE_ADMIN.celebrate) == "function", "the admin test hook exists (server-side only)")
	local tier0 = F.empireTier(d)
	C.EMPIRE_ADMIN.celebrate(a, d, "m1000")
	H.check(F.empireTier(d) == tier0, "the test celebration claims and pays nothing")
	calm()
	local ok, msg = C.ADMIN_TOOLS.empireShow.run(a, {target = 101, key = "m1"})
	H.check(ok == true and F.empireTier(d) == tier0, "the admin 'test celebration' tool plays the show and claims nothing (" .. tostring(msg) .. ")")
	local bad, _ = C.ADMIN_TOOLS.empireShow.run(a, {target = 999})
	H.check(bad == false, "the admin tool refuses a missing player")
	calm()

	H.section("Update day: a rich save from before v12")
	local dan = T.join("Dan", 104)
	rawget(T.slotStore(), "_data")["u104_s1"] = {SchemaVersion = 11, cash = 5e7, earned = 3e8, rep = 1500, tut = 0, tutPaid = 7,
		levels = {lemonade = 10, icecream = 10, bakery = 8}, staff = {}, cars = {}, viral = {score = 0}}
	T.act(dan, "menuPlay", 1)
	H.task.wait(8)
	local dd = T.data(dan)
	H.check(dd and dd.empire and dd.empire.legacy == true and dd.empire.seeded == true, "the migration marks it as a pre-v12 save, and the first check ran")
	H.check(F.empireTier(dd) == 2, "milestones it had already passed are recognized ($1M, $10M): tier " .. F.empireTier(dd))
	H.check(dd.cash < 5e7 + F.incomePerSec(dd) * 10 + 1, "...but NOT paid out again on update day (cash " .. C.fmt(dd.cash) .. ")")
	H.check((dd.viral and dd.viral.score or 0) == 0, "...and no viral score flood")
	H.check(dd.achievements and dd.achievements["empire_" .. C.EMPIRE_MILESTONES[2].key], "the badges are given")
	dd.cash = 2e8
	local cashBefore = dd.cash
	local newly = F.checkEmpire(dan, dd, H.now())
	H.check(newly and #newly == 1 and newly[1].key == C.EMPIRE_MILESTONES[3].key and dd.cash >= cashBefore + C.EMPIRE_MILESTONES[3].cash,
		"a milestone reached AFTER the update is celebrated and paid normally")
	calm()

	T.assertClean("empire test run")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
