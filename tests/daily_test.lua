-- v16: DAILY RETURNS. Login rewards on UTC days (one claim a day, never twice: double, concurrent, forged and
-- crash-in-the-middle claims), the streak shield and the step-back rule, daily missions that only move from real
-- server events, weekly challenges, rewards written ahead into the account and paid once into the right slot,
-- and everything surviving a reconnect.
-- Run with: python3 tests/run.py tests/daily_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local store = T.slotStore()
	local db = rawget(store, "_data")
	local DAY = 86400
	local clock = 1750000000 - (1750000000 % DAY) + 3600 * 10   -- 10:00 UTC on some day
	C.dailyClock = function() return clock end
	local function setDay(n) clock = (math.floor(1750000000 / DAY) + n) * DAY + 3600 * 10 end
	setDay(0)
	local a = T.join("Alice", 101)
	local function play(plr, slot, new)
		if new then T.act(plr, "menuNew", slot, 1) else T.act(plr, "menuPlay", slot) end
		H.task.wait(3)
		local d = T.data(plr)
		if d then T.quietOnboarding(d) d.tut = 0 end
		return d
	end
	local function leave(plr)
		T.act(plr, "menuExit")
		H.task.wait(1.5)
	end
	local meta = function() return db["u101_meta"] end
	local d = play(a, 1, true)
	local acct = F.acct(a)

	H.section("Login rewards")
	H.check(acct and acct.daily.claimed == 0, "a new account hasn't claimed anything")
	local info = F.dailyInfo(a)
	H.check(info and info.today == 1 and not info.claimedToday and #info.rewards == 7 and info.nextIn > 0 and info.nextIn <= DAY, "day 1 is ready; the 7-day strip and a countdown to UTC midnight")
	local c0 = d.cash
	T.act(a, "dailyClaim")
	H.task.wait(1.2)
	local paid1 = d.cash - c0
	H.check(paid1 >= C.DAILY_REWARDS[1].min, "day 1 claimed: +$" .. C.fmt(paid1))
	H.check(meta() and meta().acct and meta().acct.daily.claimed == F.utcDay() and meta().acct.daily.cycle == 1, "the claim is stored in the account (meta key) before anything is paid")
	H.check(db["u101_s1"] and db["u101_s1"].grantsGot and next(db["u101_s1"].grantsGot) ~= nil, "the slot save notes the reward it received")
	H.task.wait(1.2)
	c0 = d.cash
	T.act(a, "dailyClaim")
	H.task.wait(1.2)
	T.act(a, "dailyClaim", 7)
	T.act(a, "dailyClaim", {day = 7, cash = 1e12})
	H.task.wait(1.2)
	H.check(d.cash - c0 < F.incomePerSec(d) * 5 + 1, "claiming again the same day (even with made-up arguments) pays nothing")
	-- two claims at once on a new day
	setDay(1)
	H.task.wait(1.2)
	c0 = d.cash
	local r1, r2
	H.task.spawn(function() r1 = F.dailyClaim(a) end)
	H.task.spawn(function() r2 = F.dailyClaim(a) end)
	H.task.wait(2)
	H.check((r1 and 1 or 0) + (r2 and 1 or 0) == 1 and F.acct(a).daily.cycle == 2, "two claims at the same moment: exactly one goes through (day 2)")
	H.check(type(d.tokens) == "table" and d.tokens.upgrade == 1, "day 2's 🏷️ upgrade discount token arrived")
	-- the token takes 25% off the next upgrade
	d.cash = 1e9
	local key = "lemonade"
	local cost = F.upgradeCost(d, key)
	local before = d.cash
	F.buyUpgrade(a, d, key)
	H.check(math.abs((before - d.cash) - math.floor(cost * 0.75)) < 2 and d.tokens.upgrade == 0, "...and it took 25% off the next upgrade")

	H.section("A crash between the claim and the payment")
	setDay(2)
	H.task.wait(1.2)
	local realPay = F.payGrants
	F.payGrants = function() return 0 end   -- (the server "crashes" right after the claim is stored)
	c0 = d.cash
	F.dailyClaim(a)
	F.payGrants = realPay
	H.check(#F.acct(a).grants >= 1 and d.cash - c0 < F.incomePerSec(d) * 3 + 1, "the claim is stored as a pending grant; nothing paid yet")
	local stored = meta().acct
	local pending = 0
	for _, g in ipairs(stored.grants) do if g.slot == 1 then pending += 1 end end
	H.check(pending >= 1, "the pending grant is in the stored account record")
	d.noSave = true   -- (the crash: this session's slot never gets saved)
	leave(a)
	d = play(a, 1)
	H.task.wait(1.5)
	local got3 = 0
	for _ in pairs(d.grantsGot or {}) do got3 += 1 end
	H.check(d and d.cash > 0 and got3 >= 3, "next time the slot loads, the waiting reward is paid (" .. got3 .. " rewards on record)")
	local cashAfter = d.cash
	leave(a)
	d = play(a, 1)
	H.task.wait(1.5)
	H.check(d.cash <= cashAfter + F.incomePerSec(d) * 10 + 1, "...and only once: rejoining again pays nothing more")
	H.task.wait(1)
	local left = 0
	for _, g in ipairs(meta().acct.grants) do if g.slot == 1 then left += 1 end end
	H.check(left == 0, "paid grants are dropped from the account record")

	H.section("Another save slot")
	leave(a)
	local d2 = play(a, 2, true)
	setDay(3)
	H.task.wait(1.2)
	local c2 = d2.cash
	F.dailyClaim(a)
	H.task.wait(1.2)
	H.check(d2.cash > c2 and F.acct(a).daily.cycle == 4, "slot 2 shares the account's streak (day 4) and gets the reward")
	H.task.wait(1.2)
	local again = F.dailyClaim(a)
	H.check(not again, "...and the account can't claim twice by switching slots")
	leave(a)
	d = play(a, 1)
	H.task.wait(1.5)
	local c1 = d.cash
	H.task.wait(1.2)
	H.check(not F.dailyClaim(a) and d.cash - c1 < F.incomePerSec(d) * 3 + 1, "back in slot 1: still claimed today, slot 2's reward stays in slot 2")

	H.section("Missing days: the streak shield, then stepping back")
	local acct2 = F.acct(a)
	H.check(acct2.daily.streak == 4, "streak 4")
	setDay(5)   -- missed day 4
	H.task.wait(1.2)
	F.dailyClaim(a)
	acct2 = F.acct(a)
	H.check(acct2.daily.cycle == 5 and acct2.daily.streak == 5 and acct2.daily.shield == 0, "one missed day: the 🛡️ shield keeps the streak (day 5, streak 5)")
	setDay(9)   -- missed days 6, 7, 8 (the shield is spent this week)
	H.task.wait(1.2)
	F.dailyClaim(a)
	acct2 = F.acct(a)
	local wk5, wk9 = F.utcWeek((math.floor(1750000000 / DAY) + 5) * DAY), F.utcWeek((math.floor(1750000000 / DAY) + 9) * DAY)
	if wk9 == wk5 then
		H.check(acct2.daily.cycle == 3 and acct2.daily.streak == 1, "3 missed days without a shield: the cycle steps back 3 (6 → 3), the streak count restarts")
	else
		H.check(acct2.daily.cycle == 4 and acct2.daily.streak == 1 and acct2.daily.shield == 0, "3 missed days in a new week: the recharged shield covers one, the cycle steps back 2 (6 → 4)")
	end
	setDay(30)
	H.task.wait(1.2)
	F.dailyClaim(a)
	H.check(F.acct(a).daily.cycle >= 1, "a long break never goes below day 1 (cycle " .. F.acct(a).daily.cycle .. ")")
	-- pure rule check
	local s1 = {F.dailyStreakToday({claimed = 100, cycle = 7, streak = 7, shield = 1, shieldWeek = F.utcWeek(101 * DAY)}, 101)}
	H.check(s1[1] == 1 and s1[2] == 8, "after day 7 the cycle starts again at day 1 (the streak keeps counting)")

	H.section("Daily missions")
	setDay(31)
	H.task.wait(1.2)
	info = F.dailyInfo(a)
	H.check(#info.missions == 3, "3 missions today: " .. (info.missions[1] and info.missions[1].text or "?") .. " / " .. (info.missions[2] and info.missions[2].text or "?") .. " / " .. (info.missions[3] and info.missions[3].text or "?"))
	local tierOK = true
	for _, m in ipairs(F.acct(a).missions.picks) do
		for _, def in ipairs(C.MISSION_POOL) do if def.key == m and def.tier > F.tierIndex(d.rep) then tierOK = false end end
	end
	H.check(tierOK, "every pick is something this save's tier can do")
	-- a brand-new account gets starter missions too
	local fresh = H.addPlayer("Newbie", 303)
	H.task.wait(2)
	T.act(fresh, "menuNew", 1, 1)
	H.task.wait(3)
	local fi = F.dailyInfo(fresh)
	local starter = fi and #fi.missions == 3
	for _, m in ipairs(F.acct(fresh).missions.picks) do for _, def in ipairs(C.MISSION_POOL) do if def.key == m and def.tier > 1 then starter = false end end end
	H.check(starter, "a brand-new player gets 3 starter missions (tier 1)")
	-- fake progress from the client does nothing
	local m1 = F.acct(a).missions
	local beforeP = {m1.p[1], m1.p[2], m1.p[3]}
	T.act(a, "missionClaim", 1)
	T.act(a, "track", "serve", 1000)
	T.act(a, "dailyTrack", "cook", 99)
	H.task.wait(1.2)
	H.check(m1.p[1] == beforeP[1] and m1.p[2] == beforeP[2] and not m1.done[1], "made-up progress or an early claim from the client does nothing")
	-- real events move it
	local i, mdef
	for k, key in ipairs(m1.picks) do
		for _, def in ipairs(C.MISSION_POOL) do if def.key == key and not def.max then i, mdef = k, def end end
		if i then break end
	end
	local target = m1.t[i] or mdef.n
	F.track(a, mdef.kind, target)
	H.check(m1.p[i] == target, "real server events move mission " .. i .. " (" .. mdef.kind .. ": " .. m1.p[i] .. "/" .. target .. ")")
	F.track(a, mdef.kind, target)
	H.check(m1.p[i] == target, "...and it stops at the goal")
	H.task.wait(1.2)
	c0 = d.cash
	T.act(a, "missionClaim", i)
	H.task.wait(1.2)
	H.check(m1.done[i] == true or F.acct(a).missions.done[i] == true, "claimed")
	H.check(d.cash - c0 >= C.DAILY.missionMin, "the mission paid +$" .. C.fmt(d.cash - c0))
	H.task.wait(1.2)
	c0 = d.cash
	T.act(a, "missionClaim", i)
	T.act(a, "missionClaim", 9)
	T.act(a, "missionClaim", "1")
	H.task.wait(1.2)
	H.check(d.cash - c0 < F.incomePerSec(d) * 4 + 1, "a claimed mission can't be farmed again")

	H.section("Weekly challenge")
	local w = F.acct(a).weekly
	H.check(w.key ~= "" and w.week == F.utcWeek(), "this week's challenge: " .. w.key)
	local wdef
	for _, def in ipairs(C.WEEKLY_POOL) do if def.key == w.key then wdef = def end end
	local half = math.floor((w.t or wdef.n) / 2)
	if wdef.max then F.dailyTrack(a, wdef.kind, half) else F.track(a, wdef.kind, half) end
	H.check(F.acct(a).weekly.p >= half, "progress " .. F.acct(a).weekly.p .. "/" .. (w.t or wdef.n))
	leave(a)
	H.task.wait(0.5)
	H.check(meta().acct.weekly.p >= half, "weekly progress is stored with the account")
	d = play(a, 1)
	H.check(F.acct(a).weekly.p >= half, "...and survives a reconnect")
	if wdef.max then F.dailyTrack(a, wdef.kind, w.t or wdef.n) else F.track(a, wdef.kind, (w.t or wdef.n)) end
	H.task.wait(1.2)
	c0 = d.cash
	H.check(F.weeklyClaim(a), "the finished weekly challenge is claimed")
	H.check(d.cash > c0 and F.acct(a).wardrobe.badges[wdef.badge], "cash + the " .. wdef.badgeName .. " badge")
	H.task.wait(1.2)
	H.check(not F.weeklyClaim(a), "only once")

	H.section("Saving off: no claims")
	d.noSave = true
	H.task.wait(1.2)
	setDay(40)
	c0 = d.cash
	H.check(not F.dailyClaim(a) and d.cash == c0, "a session that can't save can't claim (so nothing is lost or doubled)")
	d.noSave = false

	T.assertClean("daily")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
