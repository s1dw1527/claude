-- v16: the EMPIRE ROADMAP, the three PATHS and their CONTRACTS, and the STARTING ATTITUDE. Stages follow the
-- game's real rules (tiers, businesses, plots, empire value); a save is placed on the map without replaying old
-- stages; a new stage is celebrated (and paid) once; paths only move from real events; contracts pay once; the
-- Underworld board opens with the mountain base; the starting choice only reorders the first suggested step.
-- Run with: python3 tests/run.py tests/roadmap_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut = 0
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local function find(root, pred) for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end end
	local function named(n) return find(a.PlayerGui, function(x) return x.Name == n end) end
	local function click(b) if b then H.signalOf(b, "MouseButton1Click"):Fire() end H.task.wait(0.6) end
	local function lastMenu(kind, since)
		for i = #H.remoteLog, (since or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.dir == "s2c" and e.args[1] == kind and e.player == a then return e.args[2] end
		end
	end

	H.section("Stages follow the real rules")
	local RT = C.REP_TIERS
	H.check(#C.ROADMAP == 7 and C.ROADMAP[1].name == "Street Starter" and C.ROADMAP[7].name == "Empire Legend", "7 stages, Street Starter → Empire Legend")
	H.check(C.ROADMAP[2].reqs[1].need == RT[2].rep and C.ROADMAP[4].reqs[1].need == RT[3].rep and C.ROADMAP[6].reqs[1].need == RT[4].rep and C.ROADMAP[7].reqs[1].need == RT[5].rep,
		"the reputation needed for each stage is the game's own tier reputation")
	H.check(C.ROADMAP[4].unlocks == RT[3].unlocks, "what a stage opens is the game's own unlock list")
	local probe = {rep = 0, levels = {lemonade = 1}, chains = {}, deeds = {}}
	H.check(F.roadmapStage(probe) == 1, "a new save: Street Starter")
	probe.rep = RT[2].rep
	H.check(F.roadmapStage(probe) == 2, "LOCAL FAVORITE reputation: Local Owner")
	probe.levels = {lemonade = 1, icecream = 1, bakery = 1, coffee = 1}
	H.check(F.roadmapStage(probe) == 3, "4 businesses: Business Builder")
	probe.rep = RT[4].rep
	H.check(F.roadmapStage(probe) == 4, "CITY ICON reputation without 2 plots stops at City Player (stages are in order)")
	probe.deeds = {{id = "1"}, {id = "2"}}
	H.check(F.roadmapStage(probe) == 6, "with 2 city plots: Property Mogul, then City Icon")

	H.section("Placed on the map, then celebrated once per new stage")
	H.task.wait(5)
	H.check(d.roadmap.seeded and d.roadmap.stage == F.roadmapStage(d), "the save is placed on the map without a celebration (stage " .. d.roadmap.stage .. ")")
	local mark = #H.remoteLog
	local c0 = d.cash
	d.rep = RT[2].rep
	H.task.wait(5)
	local ev = lastMenu("roadmapStage", mark)
	H.check(ev and ev.stage == 2 and d.roadmap.stage == 2, "reaching Local Owner: celebrated")
	H.check(d.cash - c0 >= C.ROADMAP_REWARD.min, "...with a gift (+$" .. C.fmt(d.cash - c0) .. ")")
	H.check(F.acct(a).wardrobe.titles.stage2 == true, "...and a title for the showcase")
	mark = #H.remoteLog
	H.task.wait(9)
	H.check(lastMenu("roadmapStage", mark) == nil, "not celebrated again")
	-- the app
	cc.openModal("roadmap", true)
	H.task.wait(1.2)
	local stages = 0
	for i = 1, 7 do if named("Stage_" .. i) then stages += 1 end end
	H.check(cc.modals.roadmap.frame.Visible and stages == 7, "the 🗺️ Roadmap app shows all 7 stages")
	H.check(find(cc.modals.roadmap.body, function(x) return x:IsA("TextLabel") and x.Text:find("NEXT: ", 1, true) ~= nil end) ~= nil, "...and what the next one needs")
	H.check(named("Path_mogul") and named("Path_under") and named("Path_legend"), "...and the three paths")
	cc.closeModals()

	H.section("Paths move only from real events")
	local p = F.pathRec(d)
	local x0 = p.xp.mogul
	T.act(a, "pathXP", "mogul", 1e6)
	T.act(a, "pathTrack", "heist", 50)
	H.task.wait(0.4)
	H.check(p.xp.mogul == x0 and p.xp.under == 0, "the client can't add path XP")
	F.track(a, "cook")
	H.check(p.xp.mogul == x0 + C.PATH_GAIN.cook[2], "a perfect Rush Order: +" .. C.PATH_GAIN.cook[2] .. " Mogul XP")
	mark = #H.remoteLog
	F.pathXP(a, d, "mogul", 200)
	H.check(F.pathLevel(p.xp.mogul) >= 2 and F.acct(a).wardrobe.titles.mogul2 == true, "levelling up gives a title (" .. C.PATHS_DEF[1].levels[F.pathLevel(p.xp.mogul)] .. ")")

	H.section("Contracts")
	local info = F.pathInfo(a)
	local slots = {}
	for _, ct in ipairs(info.contracts) do slots[ct.slot] = ct end
	H.check(slots.mogul ~= nil and slots.under == nil and slots.legend == nil and not info.underOpen, "before the mountain base is found: only the 💼 Mogul contract")
	d.heist = d.heist or {}
	d.heist.discovered = true
	info = F.pathInfo(a)
	slots = {}
	for _, ct in ipairs(info.contracts) do slots[ct.slot] = ct end
	H.check(slots.under ~= nil and slots.legend ~= nil, "after: 🕶️ Underworld and 👑 Legend contracts too")
	c0 = d.cash
	H.check(not F.contractClaim(a, "mogul"), "an unfinished contract can't be collected")
	T.act(a, "contractClaim", "nope")
	T.act(a, "contractClaim", 5)
	H.task.wait(0.3)
	H.check(d.cash - c0 < F.incomePerSec(d) * 2 + 1, "...nor a made-up one")
	local e = p.contracts.mogul
	local def
	for _, list in pairs(C.CONTRACTS) do for _, c in ipairs(list) do if c.key == e.key then def = c end end end
	F.track(a, def.kind, e.n[1])
	info = F.pathInfo(a)
	for _, ct in ipairs(info.contracts) do slots[ct.slot] = ct end
	H.check(slots.mogul.done, "the Mogul contract is done (" .. slots.mogul.text .. ")")
	cc.openModal("roadmap", true)
	H.task.wait(1.2)
	c0 = d.cash
	click(named("Contract_mogul"))
	H.task.wait(0.4)
	H.check(d.cash - c0 >= C.PATH_CFG.contractMin and p.done == 1 and p.contracts.mogul.key ~= nil, "collected through the app: paid, and a new contract appears")
	c0 = d.cash
	H.check(not F.contractClaim(a, "mogul"), "the new one isn't done yet: no double pay")
	cc.closeModals()
	-- legend: a mixed contract needs both sides
	local le = p.contracts.legend
	F.track(a, "heist", 1)
	local mixedDone = true
	for i, need in ipairs(le.n) do if (le.p[i] or 0) < need then mixedDone = false end end
	H.check(not mixedDone, "a mixed contract isn't done with only one side")
	-- both sides on one day → legend XP
	local lx = p.xp.legend
	p.day = {}
	F.pathXP(a, d, "mogul", 1)
	F.pathXP(a, d, "under", 1)
	H.check(p.xp.legend == lx + C.PATH_CFG.legendDaily, "business AND underworld progress on the same day: +👑 Legend XP")
	F.pathXP(a, d, "mogul", 1)
	F.pathXP(a, d, "under", 1)
	H.check(p.xp.legend == lx + C.PATH_CFG.legendDaily, "...once a day")

	H.section("The starting attitude")
	local ob = d.onboard
	local cash0 = d.cash
	T.act(a, "startChoice", "risk")
	H.task.wait(0.6)
	H.check(F.pathRec(d).choice == "risk" and ob.first == "job", "🎲 Take a Risk: the first suggested step is a City Job")
	local st = cc.JourneyUI and cc.JourneyUI.step
	H.check(st and (st.key == "job" or st.finished or ob.done.job), "the Next Step card shows it")
	H.check(d.cash - cash0 < F.incomePerSec(d) * 2 + 1, "choosing pays nothing (it only picks a goal)")
	T.act(a, "startChoice", "cheat")
	H.task.wait(0.3)
	H.check(F.pathRec(d).choice == "risk", "an unknown choice is ignored")
	cc.openStartChoice()
	H.task.wait(0.4)
	click(named("Choice_smart"))
	H.task.wait(0.4)
	H.check(F.pathRec(d).choice == "smart" and ob.first == "cook" and not cc.modals.startChoice.frame.Visible, "changed from the Roadmap: 💼 Play It Smart → Rush Order first")

	H.section("The 🎁 Daily app (through the real client)")
	local mk = #H.remoteLog
	T.act(a, "dailyInfo")
	H.task.wait(0.8)
	local card = cc.DailyUI.card
	H.check(card and card.Visible and card:FindFirstChildWhichIsA("TextLabel").Text:find("reward is ready", 1, true), "a small 🎁 card says today's reward is waiting (not a full-screen window)")
	click(named("DailyOpen"))
	H.task.wait(1)
	H.check(cc.modals.daily.frame.Visible and named("Day1") and named("Day7") and named("DailyClaim"), "it opens the 🎁 Daily app: the 7-day strip and Claim")
	local cbefore = d.cash
	click(named("DailyClaim"))
	H.task.wait(1.5)
	H.check(d.cash > cbefore and cc.DailyUI.info.claimedToday, "Claim pays today's reward, and the app shows it's claimed")
	H.check(named("DailyClaim") == nil, "the Claim button is gone until tomorrow")
	local nm = 0
	for i = 1, 3 do if named("Mission_" .. i) then nm += 1 end end
	H.check(nm == 3 and named("WeeklyClaim") ~= nil, "today's 3 missions and the weekly challenge are listed")
	cc.closeModals()
	local _ = mk

	T.assertClean("roadmap")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
