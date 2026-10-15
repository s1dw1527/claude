-- v16: PLAYING TOGETHER. Park visits (a real ride at someone else's park pays the visitor and the host once a day
-- each, capped), co-op bonuses between partners (once per pair per day), the 🪪 showcase (public, derived data
-- only), wearing titles and badges (only ones you own), and the park visit list.
-- Run with: python3 tests/run.py tests/social_test.lua
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
	local V3, CF = Vector3.new, CFrame.new
	local function find(root, pred) for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end end
	local function named(n) return find(a.PlayerGui, function(x) return x.Name == n end) end
	local function grantsWith(plr, pat)
		local n = 0
		for _, g in ipairs(F.acct(plr).grants) do if g.what:find(pat, 1, true) then n += 1 end end
		local d0 = C.data[plr]
		return n, d0
	end
	-- Bob opens a park with a carousel
	db.rep, db.cash = 5000, 1e10
	F.plotBuyFor(bob, "suburbs", "park")
	db.levels.park = 3
	H.task.wait(3)
	local okP, it = F.parkPlace(bob, "carousel", 4, 4, 0)
	local bsite = F.parkSite(bob)
	H.check(okP and bsite ~= nil, "Bob's park is open with a 🎠 carousel")
	local spot = bsite.models[it.id]:FindFirstChild("RideSpot")
	local hrp = a.Character.HumanoidRootPart

	H.section("Visiting a park")
	local aCash, bCash = d.cash, db.cash
	hrp.CFrame = CF(spot.Position + V3(60, 1, 60))
	H.check(not F.parkRide(a, bob, it.id), "too far from the ride: no ride")
	H.task.wait(1.5)
	H.check(d.cash - aCash < F.incomePerSec(d) * 3 + 1, "...and no visitor reward without a real ride")
	local mark = d.cash
	T.act(a, "parkVisit", bob.UserId)
	H.task.wait(0.5)
	H.check(d.cash - mark < F.incomePerSec(d) * 2 + 1, "the client has no way to ask for a visit reward")
	-- start clean for the real-ride checks
	F.acct(a).coop = {}
	F.acct(bob).coop = {}
	aCash, bCash = d.cash, db.cash
	hrp.CFrame = CF(spot.Position + V3(-3, 1, 0))
	H.check(F.parkRide(a, bob, it.id), "Alice rides Bob's carousel")
	H.task.wait(2)
	H.check(d.cash - aCash >= C.SOCIAL.visitMin, "Alice gets a visitor reward (+$" .. C.fmt(d.cash - aCash) .. ")")
	H.check(db.cash - bCash >= C.SOCIAL.hostMin, "Bob gets a host bonus on top of his ticket (+$" .. C.fmt(db.cash - bCash) .. ")")
	H.task.wait(16)
	aCash = d.cash
	local bHost = 0
	for k, v in pairs(F.acct(bob).coop) do if k == "h" .. a.UserId then bHost += 1 end end
	H.check(F.parkRide(a, bob, it.id), "Alice rides again the same day")
	H.task.wait(2)
	H.check(d.cash - aCash < C.SOCIAL.visitMin, "no second visitor reward from the same park today")
	H.check(bHost == 1, "the host bonus is recorded once per visitor per day")
	-- the daily cap across parks
	local today = F.utcDay()
	F.acct(a).coop = {v1 = today, v2 = today, v3 = today}
	F.acct(a).coop["v" .. bob.UserId] = nil
	H.task.wait(16)
	aCash = d.cash
	F.parkRide(a, bob, it.id)
	H.task.wait(2)
	H.check(d.cash - aCash < C.SOCIAL.visitMin, "after " .. C.SOCIAL.visitCap .. " parks in a day, no more visitor rewards")

	H.section("Co-op")
	local c1, c2 = d.cash, db.cash
	F.coopCredit(a, bob, "test")
	H.task.wait(2)
	F.coopCredit(a, bob, "test again")
	F.coopCredit(bob, a, "the other way round")
	H.task.wait(2)
	local na = grantsWith(a, "Co-op with Bob")
	H.check(d.cash - c1 >= C.SOCIAL.coopMin and db.cash - c2 >= C.SOCIAL.coopMin, "partners working together: both get a co-op bonus")
	local got = 0
	for id in pairs(d.grantsGot) do local _ = id got += 1 end
	H.check(d.cash - c1 < 2 * C.SOCIAL.coopMin + F.incomePerSec(d) * 30 and na == 0, "...once per pair per day, however many times it's triggered")

	H.section("The 🪪 showcase")
	local sc = F.showcase(bob)
	H.check(sc and sc.name == "Bob" and sc.stage >= 1 and sc.businesses >= 1 and type(sc.worth) == "string" and sc.park ~= nil, "Bob's card: stage " .. sc.stage .. ", " .. sc.businesses .. " businesses, " .. sc.worth .. ", park ⭐ " .. tostring(sc.park))
	local allowed = {name = true, stage = true, stageName = true, businesses = true, worth = true, park = true, prestige = true, title = true, badge = true, paths = true, rare = true}   -- (v17: rare = lucky-sale counts)
	local leak
	for k in pairs(sc) do if not allowed[k] then leak = k end end
	H.check(leak == nil and sc.cash == nil and sc.settings == nil and sc.wardrobe == nil, "only public, derived data (no exact cash, settings or private fields)" .. (leak and (": " .. leak) or ""))
	cc.openShowcase(bob.UserId)
	H.task.wait(1)
	H.check(cc.modals.showcase.frame.Visible and cc.ShowcaseUI.info and cc.ShowcaseUI.info.name == "Bob" and cc.ShowcaseUI.info.wardrobe == nil, "Alice opens Bob's card (without his wardrobe)")
	cc.closeModals()

	H.section("Wearing a title")
	F.acct(a).wardrobe.titles.weekChamp = true
	T.act(a, "wear", "title", "mogul8")
	H.task.wait(0.3)
	H.check(F.acct(a).wardrobe.title == "", "a title you don't own can't be worn")
	cc.openShowcase(nil)
	H.task.wait(1)
	local wb = named("Wear_title_weekChamp")
	H.check(wb ~= nil, "your own card lists your titles")
	H.signalOf(wb, "MouseButton1Click"):Fire()
	H.task.wait(1)
	H.check(F.acct(a).wardrobe.title == "weekChamp" and F.showcase(a).title == "👑 Week Champion", "wear one: it shows on your card")
	cc.closeModals()

	H.section("The park list")
	cc.openPark("park")
	H.task.wait(1.5)
	local row
	for _, p in ipairs(cc.ParkUI.list or {}) do if p.name == "Bob" then row = p end end
	H.check(row and row.visitors ~= nil and row.featured and row.featured:find("Carousel", 1, true), "the park list shows Bob's visitors and his star ride (" .. tostring(row and row.featured) .. ")")
	H.check(named("ParkVisit_" .. bob.UserId) and named("ParkProfile_" .. bob.UserId), "...with Visit and 🪪 buttons")
	cc.closeModals()

	T.assertClean("social")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
