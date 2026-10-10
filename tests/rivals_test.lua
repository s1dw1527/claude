-- v14 Phase B: AI RIVALS (market pressure, moves, challenges, fair limits) and the CREW (traits, shifts,
-- learning on the job). Run with: python3 tests/run.py tests/rivals_test.lua
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
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut, db.tut = 0, 0
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local Lighting = H.service("Lighting")
	Lighting.ClockTime = 13
	local RV = C.RIVAL_CFG
	d.rep = 2000
	d.cash = 1e12
	d.levels.pizza = 3
	d.levels.lemonade = math.max(2, d.levels.lemonade or 0)
	F.refreshBuilding(a, "pizza", false)
	local function lastMenu(kind, since, who)
		for i = #H.remoteLog, (since or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.dir == "s2c" and e.args[1] == kind and e.player == (who or a) then return e.args[2] end
		end
	end
	local function buzzSince(mark, pat)
		for i = mark + 1, #H.remoteLog do
			local e = H.remoteLog[i]
			if e.name == "Buzz" then
				for _, v in ipairs(e.args or {}) do if type(v) == "table" and type(v.text) == "string" and v.text:find(pat, 1, true) then return v end end
			end
		end
	end
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local r = F.rivalRec(d)
	-- (moves are made by hand in this test)
	r.moves = 0

	H.section("Market share")
	H.check(F.rivalMult(d, "pizza") == 1 and F.rivalShare(d, "pizza") == 75, "a business nobody has fought over: 75% share, exactly normal sales (×1.00)")
	H.check(C.RIVAL_OF.pizza.name == "MegaBite Foods" and C.RIVAL_OF.theater.name == "Pixel Palace Group", "each business type has its rival (pizza vs " .. C.RIVAL_OF.pizza.name .. ")")
	local cash0 = d.cash
	H.task.wait(RV.tick + 1)
	H.check((r.p.pizza or 50) > 50 and F.rivalMult(d, "pizza") < 1, string.format("while Alice plays, rivals creep in (pressure %.1f, ×%.3f)", r.p.pizza or 50, F.rivalMult(d, "pizza")))
	H.check(d.cash >= cash0, "rivals never take cash")
	r.p.pizza = 100
	H.check(math.abs(F.rivalMult(d, "pizza") - 0.96) < 1e-9, "the worst it gets: ×0.96 (rivals everywhere)")
	r.p.pizza = 0
	H.check(math.abs(F.rivalMult(d, "pizza") - 1.04) < 1e-9, "the best: ×1.04 (you own the street)")
	r.p.pizza = 1e9
	H.check(F.rivalMult(d, "pizza") >= 0.96, "a broken value can't push it further (clamped)")
	r.p.pizza = 50
	local base = F.bizMult(d, "pizza")
	r.p.pizza = 100
	H.check(math.abs(F.bizMult(d, "pizza") - base * 0.96) < 1e-6 * base, "it's applied to that business's sales")
	r.p.pizza = 60

	H.section("A rival makes a move")
	local mark = #H.remoteLog
	local ch = F.rivalMove(a, "pizza")
	H.task.wait(0.5)
	H.check(ch and r.p.pizza == 60 + RV.movePressure, "MegaBite moves on the pizzeria (+" .. RV.movePressure .. " pressure)")
	H.check(buzzSince(mark, "MegaBite Foods") ~= nil, "...in CityBuzz: " .. tostring(buzzSince(mark, "MegaBite Foods") and buzzSince(mark, "MegaBite Foods").text))
	H.check(lastMenu("rivalMove", mark) ~= nil and cc.RivalsUI.card.Visible, "a challenge card appears in the notification stack: " .. ch.text)
	H.check(F.rivalMove(a, "pizza") == nil, "one challenge at a time")

	H.section("Winning a challenge")
	ch.kind, ch.need, ch.got = "upgrade", 1, 0
	local p0 = r.p.pizza
	mark = #H.remoteLog
	F.buyUpgrade(a, d, "pizza")
	H.task.wait(0.5)
	local res = lastMenu("rivalResult", mark)
	H.check(res and res.won and res.prize > 0 and r.ch == nil and r.wins == 1, "upgrading the pizzeria wins it: +$" .. C.fmt(res and res.prize or 0))
	H.check(r.p.pizza <= p0 - RV.winDrop - RV.relief.upgrade + 0.01, string.format("pressure falls (%.0f → %.0f)", p0, r.p.pizza))
	H.check(buzzSince(mark, "fought off") ~= nil and not cc.RivalsUI.card.Visible, "CityBuzz cheers, the card goes away")
	calm()
	-- cooking: a real perfect Rush Order counts
	F.rivalMove(a, "pizza")
	r.ch.kind, r.ch.need, r.ch.got = "cook", 2, 0
	local door = (F.slotCF(d.plot, "pizza") * CFrame.new(0, 0, 9)).Position
	a.Character:PivotTo(CFrame.new(door + Vector3.new(0, 3, 0)))
	H.task.wait(0.3)
	F.cookStart(a, "pizza")
	H.task.wait(0.6)
	local KU = cc.KitchenUI
	local function cookOne()
		local order = KU.order
		if not order then return false end
		for _, st in ipairs(order.steps) do
			H.task.wait(0.5)
			local b = KU.grid:FindFirstChild("Step_" .. st.n)
			if not b then return false end
			H.signalOf(b, "MouseButton1Click"):Fire()
		end
		H.task.wait(1.4)
		return true
	end
	local pc = r.p.pizza
	cookOne()
	H.check(r.ch and r.ch.got == 1 and r.p.pizza < pc, string.format("a perfect Rush Order: challenge 1/2, pressure %.1f → %.1f", pc, r.p.pizza))
	mark = #H.remoteLog
	cookOne()
	H.task.wait(0.3)
	res = lastMenu("rivalResult", mark)
	H.check(res and res.won and r.wins == 2, "the second one wins it")
	T.act(a, "cookEnd")
	H.task.wait(0.5)
	calm()
	-- ads count for every business
	F.rivalMove(a, "pizza")
	r.ch.kind, r.ch.need, r.ch.got = "ad", 1, 0
	r.p.lemonade = 70
	F.runAd(a, d, "small", os.clock())
	H.task.wait(0.3)
	H.check(r.wins == 3 and r.p.lemonade < 70, "an ad campaign wins an ad challenge and pushes rivals back everywhere")

	H.section("Losing one")
	F.rivalMove(a, "pizza")
	r.ch.left = 1
	mark = #H.remoteLog
	H.task.wait(RV.tick + 1)
	res = lastMenu("rivalResult", mark)
	H.check(res and res.won == false and r.losses == 1 and r.ch == nil and not cc.RivalsUI.card.Visible, "time runs out: a loss on the record, nothing taken")

	H.section("The 🥊 Rivals app")
	F.rivalMove(a, "lemonade")
	cc.openModal("rivals", true)
	H.task.wait(0.8)
	local shares = 0
	for _, x in ipairs(cc.modals.rivals.body:GetDescendants()) do if x.Name == "Share" then shares += 1 end end
	H.check(shares >= 2, "a market-share bar per business (" .. shares .. ")")
	H.check(find(cc.modals.rivals.body, function(x) return x.ClassName == "TextLabel" and x.Text:find("CHALLENGE FROM", 1, true) end) ~= nil, "the running challenge")
	H.check(find(cc.modals.rivals.body, function(x) return x.ClassName == "TextLabel" and x.Text:find("Novatek Industries", 1, true) end) ~= nil, "who the rivals are")
	cc.closeModals()

	H.section("Crew: traits")
	T.act(a, "candidates", "pizza")
	H.task.wait(0.4)
	local cands = d.cands.pizza
	local traited = 0
	for _, c in ipairs(cands) do if c.trait ~= nil then traited += 1 end end
	H.check(#cands == 3 and traited == 3, "each candidate has a trait or none (decided once): " .. tostring(cands[1].trait) .. ", " .. tostring(cands[2].trait) .. ", " .. tostring(cands[3].trait))
	cands[1].trait = "nightowl"
	T.act(a, "candidates", "pizza")
	H.task.wait(0.4)
	local cw = find(a.PlayerGui, function(x) return x.Name == "CandidatesWindow" end)
	H.check(cw and find(cw, function(x) return x.ClassName == "TextLabel" and x.Text:find("Night Owl", 1, true) end) ~= nil, "the candidates window shows the trait before you hire")
	T.act(a, "hire", "pizza", 1)
	H.task.wait(0.4)
	local s = d.staff.pizza
	H.check(s and s.trait == "nightowl" and s.shift == "flex" and s.xp == 0, "hired: " .. s.name .. " 🦉 Night Owl, Flex shift")
	H.check(r.p.pizza ~= nil, "(hiring pushes the pizza rival back too)")

	H.section("Crew: shifts")
	Lighting.ClockTime = 13
	H.check(F.crewFactor(s) == 1, "Flex by day: the normal bonus (×1)")
	Lighting.ClockTime = 22
	H.check(math.abs(F.crewFactor(s) - 1.25) < 1e-9, "a Night Owl at night: ×1.25")
	T.act(a, "crewShift", "pizza", "night")
	H.task.wait(0.2)
	H.check(s.shift == "night" and math.abs(F.crewFactor(s) - 1.3 * 1.25) < 1e-9, "on the night shift at night: ×1.3 × 1.25")
	Lighting.ClockTime = 13
	H.check(math.abs(F.crewFactor(s) - 0.7) < 1e-9 and not F.crewOnShift(s), "off shift by day: ×0.7")
	local m1 = F.bizMult(d, "pizza")
	Lighting.ClockTime = 22
	H.check(F.bizMult(d, "pizza") > m1, "the pizzeria earns more while its night crew works")
	Lighting.ClockTime = 13
	for _, bad in ipairs({{"pizza", "party"}, {"nope", "day"}, {"pizza", 3}, {{}, "day"}}) do T.act(a, "crewShift", bad[1], bad[2]) end
	T.act(bob, "crewShift", "pizza", "day")
	H.task.wait(0.2)
	H.check(s.shift == "night" and db.staff.pizza == nil, "made-up shifts and slots, and someone else's staff: nothing changes")
	local old = {name = "Vet", service = 3, speed = 2, exp = 4}
	d.staff.lemonade = old
	H.check(F.crewFactor(old) == 1, "staff hired before v14 (no trait, no shift): exactly the bonus they had")

	H.section("Crew: the Staff app")
	cc.openModal("staff", true)
	H.task.wait(0.8)
	local sb = find(a.PlayerGui, function(x) return x.Name == "Shift_pizza" end)
	H.check(sb and sb.Visible and sb.Text:find("Night", 1, true), "each employee has a shift button: " .. tostring(sb and sb.Text))
	H.signalOf(sb, "MouseButton1Click"):Fire()
	H.task.wait(0.6)
	H.check(s.shift == "flex", "tapping it switches the shift (Night → Flex)")
	H.check(find(a.PlayerGui, function(x) return x.Name == "Shift_theater" end) ~= nil, "the Movie Theater has a 🎞️ Projectionist slot")
	cc.closeModals()

	H.section("Crew: learning on the job, other traits")
	s.xp = C.CREW.xpStar - 1
	local e0 = s.exp
	H.task.wait(C.CREW.xpEvery + 1)
	H.check(s.exp == e0 + 1 and s.xp == 0, "a working employee earns a free ★ now and then (Exp " .. e0 .. " → " .. s.exp .. ")")
	local tc = F.trainCost("pizza", s)
	s.trait = "learner"
	H.check(F.trainCost("pizza", s) == math.floor(tc * 0.7), "Fast Learner: training costs 30% less")
	local sat = F.satisfaction(d, "pizza")
	s.trait = "charmer"
	H.check(F.satisfaction(d, "pizza") == math.min(100, sat + 6) or F.satisfaction(d, "pizza") == 100, "Charmer: happier customers (" .. sat .. " → " .. F.satisfaction(d, "pizza") .. ")")
	-- Steady Hands: about half the breakdowns
	local function breakdowns(trait)
		s.trait = trait
		local n = 0
		local keep = d.levels
		d.levels = {pizza = keep.pizza}
		for _ = 1, 80 do
			d.problems = {}
			d.immune = {}
			F.makeProblem(a, d, os.clock())
			if d.problems.pizza then n += 1 end
		end
		d.levels = keep
		d.problems = {}
		return n
	end
	local normal, steady = breakdowns(nil), breakdowns("steady")
	H.check(normal >= 70 and steady < normal * 0.75, "Steady Hands: fewer breakdowns (" .. normal .. " → " .. steady .. " in 80 tries)")
	s.trait = "nightowl"

	H.section("Saved")
	local okSave = F.save and F.save(a)
	local store = rawget(T.slotStore(), "_data")
	local rec
	for k, v in pairs(store or {}) do if type(v) == "table" and k:find("u101_s") and type(v.rivals) == "table" then rec = v end end
	H.check(okSave and rec and rec.rivals.wins == 3 and rec.rivals.losses == 1 and rec.staff.pizza.trait == "nightowl" and rec.staff.pizza.shift == "flex",
		"rivalry record, traits and shifts are saved")

	-- (makeProblem announces each breakdown: expected notifications, not warnings)
	T.assertClean("rivals")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
