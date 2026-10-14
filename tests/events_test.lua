-- v16: LIVE CITY EVENTS. The same event at the same UTC time everywhere, clean window boundaries, weekends,
-- boosts that apply only during their window (and never take anything away after), goals whose reward is
-- claimed once per window per account, the plaza board, and no announcements while a player is busy.
-- Run with: python3 tests/run.py tests/events_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	d.tut = 0
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local W = C.LIVE_WINDOW
	local clock = 1750000000
	C.dailyClock = function() return clock end
	local function weekday(t) return (math.floor(t / 86400) + 4) % 7 end
	-- a weekday window with a given event
	local function findWindow(key)
		local t = math.floor(1750000000 / W) * W
		for _ = 1, 400 do
			local ev = F.liveAt(t)
			if ev.key == key then return t end
			t += W
		end
	end

	H.section("The schedule")
	local e1, w1, t0, t1 = F.liveAt(1750000000)
	local e2, w2 = F.liveAt(1750000000)
	H.check(e1 == e2 and w1 == w2, "the same time gives the same event (every server works it out from the clock alone)")
	H.check(t0 <= 1750000000 and 1750000000 < t1 and t1 - t0 == W, "4-hour windows: " .. e1.name)
	local ea = F.liveAt(t1 - 1)
	local eb = F.liveAt(t1)
	H.check(ea == e1, "the last second of a window still has its event")
	local seen = {}
	local t = math.floor(1750000000 / 86400) * 86400
	for _ = 1, 7 * 6 do
		local ev = F.liveAt(t)
		seen[ev.key] = true
		if weekday(t) == 0 or weekday(t) == 6 then
			if ev.key ~= "community" then seen.bad = true end
		elseif ev.key == "community" then seen.bad = true end
		t += W
	end
	H.check(not seen.bad, "🤝 Community Weekend on Saturdays and Sundays (UTC), the rotation on weekdays")
	local n = 0
	for k in pairs(seen) do if k ~= "bad" then n += 1 end end
	H.check(n == #C.LIVE_EVENTS, "a week covers all " .. #C.LIVE_EVENTS .. " events")
	local _ = eb

	H.section("Boosts only while their event runs")
	d.levels.lemonade = math.max(3, d.levels.lemonade or 0)
	clock = findWindow("rush") + 60
	local rRush = F.customerRate(d, os.clock())
	clock = findWindow("delivery") + 60
	local rOther = F.customerRate(d, os.clock())
	H.check(math.abs(rRush / rOther - 1.25) < 0.01, string.format("🍽️ Restaurant Rush: customers ×%.2f", rRush / rOther))
	H.check(F.liveMult("jobPay") == 2 and F.liveMult("customers") == 1, "📦 Double Delivery: City Jobs ×2, customers back to normal")
	clock = findWindow("underworld") + 60
	H.check(F.liveMult("heistPay") == 1.3 and F.liveMult("jobPay") == 1, "🚨 Underworld Alert: heists +30%, jobs back to normal")

	H.section("The goal and its reward")
	clock = findWindow("rush") + 120
	local info = F.liveInfo(a)
	H.check(info.key == "rush" and info.goal and info.n == 5 and info.p == 0 and info.endsIn > 0, "the goal: " .. info.goal .. " (ends in " .. math.floor(info.endsIn / 60) .. " min)")
	T.act(a, "liveClaim")
	H.task.wait(0.3)
	H.check(not F.liveInfo(a).claimed, "not done yet: nothing to claim")
	T.act(a, "liveTrack", "cook", 5)
	H.task.wait(0.2)
	H.check(F.liveInfo(a).p == 0, "the client can't move the goal")
	F.track(a, "serve", 10)
	H.check(F.liveInfo(a).p == 0, "other events don't count")
	for _ = 1, 5 do F.track(a, "cook") end
	H.check(F.liveInfo(a).done, "5 real Rush Orders: done")
	local c0 = d.cash
	H.check(F.liveClaim(a) and d.cash > c0, "claimed: +$" .. C.fmt(d.cash - c0))
	c0 = d.cash
	H.task.wait(1.2)
	H.check(not F.liveClaim(a) and d.cash - c0 < F.incomePerSec(d) * 3 + 1, "only once per event window")
	H.check(F.liveInfo(a).claimed, "the app shows it as claimed")
	-- the next window: a new goal
	clock = findWindow("funland") + 60
	H.check(F.liveInfo(a).key == "funland" and F.liveInfo(a).p == 0 and not F.liveInfo(a).claimed, "the next event starts fresh: " .. F.liveInfo(a).goal)
	local cashEnd = d.cash
	H.task.wait(1)
	H.check(d.cash >= cashEnd, "nothing is taken back when an event ends")

	H.section("The board and announcements")
	H.task.wait(6)
	local board = C.WORLD:FindFirstChild("EventBoard")
	local txt = board and board:FindFirstChildWhichIsA("SurfaceGui") and board:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel")
	H.check(txt and txt.Text:find("FUNLAND NIGHT", 1, true), "the plaza board shows the current event")
	-- busy players aren't interrupted
	local realBusy = F.isRiding
	F.isRiding = function(p) return p == a end
	clock = findWindow("luxury") + 60
	local mark = #H.remoteLog
	H.task.wait(7)
	local heard = false
	for _, msg in ipairs(T.announcesSince(mark, a)) do if tostring(msg):find("City event", 1, true) then heard = true end end
	H.check(not heard, "mid-ride: no event announcement")
	F.isRiding = realBusy
	H.task.wait(6)
	heard = false
	for _, msg in ipairs(T.announcesSince(mark, a)) do if tostring(msg):find("Luxury Showcase", 1, true) then heard = true end end
	H.check(heard, "after the ride: told about 🏎️ Luxury Showcase, once")

	H.section("Moments with a reason")
	d.levels.park = 3
	d.rep = 5000
	H.task.wait(3)
	local site = F.parkSite(a)
	local v0 = F.parkRec(d).visitors
	H.check(site and F.parkRush(a) and F.parkRec(d).visitors == v0 + C.MOMENTS.parkRushVisitors and site.folder:GetAttribute("Boost") >= 2,
		"🚌 a park tour bus: the visitor count really goes up and the park gets busier for a while")

	T.assertClean("events")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
