-- v14 Phase E: SPECIAL OCCASIONS on the calendar (tasks, saved progress and claims, late claims, New Year
-- wrap, monthly City Birthday, Weekend Rush, the plaza decorations) and the staged 10-step ONBOARDING.
-- Run with: python3 tests/run.py tests/journey_test.lua
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
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local function click(name)
		local b = find(a.PlayerGui, function(x) return x.Name == name end)
		if b then H.signalOf(b, "MouseButton1Click"):Fire() end
		return b
	end
	local function at(y, mo, day, h) return os.time({year = y, month = mo, day = day, hour = h or 12}) end
	local clock = at(2026, 10, 20)   -- a Tuesday in Spooky Season
	C.occasionClock = function() return clock end
	local function ids()
		local out = {}
		for _, i in ipairs(F.occasionsNow()) do table.insert(out, i.id .. (i.live and "" or "(late)")) end
		return table.concat(out, ",")
	end

	H.section("The calendar")
	H.check(ids() == "spooky2026", "Oct 20 2026: 🎃 Spooky Season is on (" .. ids() .. ")")
	clock = at(2026, 12, 31)
	H.check(ids() == "winter2026", "Dec 31: ❄️ Winter Lights (" .. ids() .. ")")
	clock = at(2027, 1, 2)
	H.check(ids():find("^winter2026,") ~= nil and ids():find("birthday202701") ~= nil, "Jan 2 2027: still the same Winter Lights (it wraps over New Year), and the monthly 🎂 City Birthday (" .. ids() .. ")")
	clock = at(2027, 1, 4)
	H.check(ids():find("winter2026%(late%)") ~= nil, "Jan 4: over, but claimable for 3 days (" .. ids() .. ")")
	clock = at(2027, 1, 9)
	H.check(ids() == "", "Jan 9: nothing on")
	clock = at(2026, 11, 2)
	H.check(ids():find("birthday202611") ~= nil and ids():find("spooky2026%(late%)") ~= nil, "Nov 2: 🎂 City Birthday (monthly) + Spooky Season's late claims (" .. ids() .. ")")
	clock = at(2026, 10, 17)   -- a Saturday
	H.check(F.weekendRush() and F.occasionMult("tips") == 1.5, "Saturday: 🔥 Weekend Rush (tips ×1.5)")
	clock = at(2026, 10, 20)
	H.check(not F.weekendRush() and F.occasionMult("tips") == 1, "Tuesday: normal tips")

	H.section("Doing the tasks")
	d.tut = 0
	F.track(a, "cook", 10)
	F.track(a, "corner", 3)
	cc.openModal("occasions", true)
	H.task.wait(0.8)
	local cb = find(a.PlayerGui, function(x) return x.Name == "Claim_spooky" end)
	H.check(cb and cb.Text:find("Finish", 1, true), "two of three tasks done: the reward isn't claimable yet")
	local c0 = d.cash
	H.check(not F.occasionClaim(a, "spooky2026") and d.cash - c0 < F.incomePerSec(d) * 2 + 1, "a forced claim is refused")
	F.track(a, "cook", 50)
	F.track(a, "party")
	H.check(d.events.inst.spooky2026.p[1] == 15, "progress stops at the goal (15/15)")
	cc.closeModals()
	cc.openModal("occasions", true)
	H.task.wait(0.8)
	c0 = d.cash
	local rep0 = d.rep
	click("Claim_spooky")
	H.task.wait(0.6)
	local want = math.max(C.OCCASIONS[1].reward.min, F.incomePerSec(d) * C.OCCASIONS[1].reward.secs)
	H.check(d.events.inst.spooky2026.claimed and d.cash - c0 >= want * 0.95 and d.rep > rep0, "Claim: +$" .. C.fmt(d.cash - c0) .. " and reputation")
	H.check(d.events.keep.spooky ~= nil, "...and a keepsake: " .. tostring(d.events.keep.spooky))
	c0 = d.cash
	H.check(not F.occasionClaim(a, "spooky2026") and d.cash - c0 < F.incomePerSec(d) * 2 + 1, "a second claim is refused")
	H.check(not F.occasionClaim(a, "winter2026") and not F.occasionClaim(a, "made up"), "events that aren't on (or don't exist) can't be claimed")
	cc.closeModals()
	-- Bob's progress is his own
	H.check(db.events == nil or db.events.inst == nil or db.events.inst.spooky2026 == nil or (db.events.inst.spooky2026.p[1] or 0) == 0, "each player has their own progress")

	H.section("The plaza dresses up")
	F.occasionDress()
	local deco = find(H.workspace, function(x) return x.Name == "OccasionDecor" end)
	H.check(deco and find(deco, function(x) return x.ClassName == "TextLabel" and x.Text:find("SPOOKY SEASON", 1, true) end) ~= nil, "a 🎃 Spooky Season arch and lanterns at the Empire Plaza")
	clock = at(2026, 11, 20)
	F.occasionDress()
	H.check(find(H.workspace, function(x) return x.Name == "OccasionDecor" end) == nil, "gone when it's over")
	clock = at(2026, 10, 20)

	H.section("Saved")
	F.save(a)
	local rec = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(rec and rec.events and rec.events.inst.spooky2026.claimed and rec.events.keep.spooky, "progress, the claim and the keepsake are saved")

	H.section("Onboarding: the next step, one at a time")
	d.onboard = nil
	d.rep = 0
	d.staff = {}
	F.onboardCheck(a, true)
	H.task.wait(0.4)
	local card = cc.JourneyUI.card
	H.check(card.Visible and cc.JourneyUI.step.key == "cook", "after the tutorial: NEXT STEP 1/10, serve a perfect Rush Order")
	c0 = d.cash
	F.track(a, "cook")
	H.task.wait(0.4)
	H.check(d.onboard.done.cook and d.cash > c0, "done: rewarded, and the card moves on")
	local s = cc.JourneyUI.step
	H.check(s.key ~= "cook" and s.step >= 2, "next: " .. tostring(s.title) .. (s.locked and " (locked)" or ""))
	if s.key == "hire" then
		H.check(s.locked and s.need ~= nil, "hiring needs more reputation: it says so")
		click("NextStepLater")
		H.task.wait(0.4)
		H.check(cc.JourneyUI.step.key ~= "hire", "Later: skipped for now (" .. tostring(cc.JourneyUI.step.title) .. ")")
	end
	-- a step with an app: "Show me" opens it
	d.onboard.skip = {}
	for _, st in ipairs(C.ONBOARD_STEPS) do if st.key ~= "corner" then d.onboard.done[st.key] = d.onboard.done[st.key] or os.time() end end
	F.onboardCheck(a, true)
	H.task.wait(0.4)
	H.check(cc.JourneyUI.step.key == "corner", "one step left: find a Golden Corner")
	click("NextStepShow")
	H.task.wait(0.5)
	H.check(cc.modals.explore.frame.Visible, "Show me opens 🧭 Explore")
	cc.closeModals()
	d.city.corners.gc1 = os.time()
	local mark = #H.remoteLog
	F.onboardCheck(a)
	H.task.wait(0.4)
	local splash = false
	for i = mark + 1, #H.remoteLog do
		local e = H.remoteLog[i]
		if e.name == "Splash" and e.player == a and tostring(e.args[1]):find("YOU KNOW THE CITY") then splash = true end
	end
	H.check(splash and not card.Visible, "all 10 done: a celebration, and the card goes away")

	H.section("Onboarding: veterans aren't paid again")
	db.tut = 0
	db.onboard = nil
	db.levels.icecream = 3
	db.levels.lemonade = math.max(1, db.levels.lemonade or 0)
	db.staff.lemonade = {name = "Vet", service = 2, speed = 2, exp = 2}
	db.deeds = db.deeds or {}
	table.insert(db.deeds, {id = "d9", district = "suburbs"})
	local cb0 = db.cash
	local n = F.onboardCheck(bob)
	H.check(n >= 3 and db.cash - cb0 < F.incomePerSec(db) * 2 + 1, "Bob's save already did " .. n .. " steps: recognized, not paid")

	T.assertClean("journey")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
