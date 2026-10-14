-- v15: the 🎢 AMUSEMENT PARK business. Opening it through the menus (city plot = ticket gate), the player's own
-- site at the Funland Grounds, building rides / stalls / paths through the 🎢 Park app's plan (and every way the
-- server refuses a bad placement), moving / turning / selling, the rating and the sales boost, rides that move
-- (spinning rides and roller-coaster trains in time with the server clock), riding (the camera rides the car,
-- other players pay the owner a ticket), visitors with cotton candy on the paths, sites freed when a player
-- leaves, and the save.
-- Run with: python3 tests/run.py tests/park_test.lua
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
	local V3, CF = Vector3.new, CFrame.new
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
	local PK = C.PARK
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local function named(n) return find(a.PlayerGui, function(x) return x.Name == n end) end
	local function click(b) if b then H.signalOf(b, "MouseButton1Click"):Fire() end H.task.wait(0.6) end
	local function count(t) local n = 0 for _ in pairs(t) do n += 1 end return n end
	local function lastMenu(kind, since, who)
		for i = #H.remoteLog, (since or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.dir == "s2c" and e.args[1] == kind and e.player == (who or a) then return e.args[2] end
		end
	end

	H.section("The business")
	local B = C.BIZ.park
	H.check(B and B.index == 10 and B.lotOnly and B.unlock == 4, "the Amusement Park is business #10, opens on a city plot, unlocks at " .. C.REP_TIERS[4].name)
	H.check(#C.PARK_ITEMS >= 19 and C.PARK.gw == 20 and C.PARK.gh == 24 and #PK.sites == 4, #C.PARK_ITEMS .. " things to build, a 20 × 24 plan, 4 sites at the Funland Grounds")
	local kinds = {}
	for _, it in ipairs(C.PARK_ITEMS) do kinds[it.kind] = (kinds[it.kind] or 0) + 1 end
	H.check(kinds.ride >= 9 and kinds.stall >= 4 and kinds.decor >= 5 and kinds.path == 1, string.format("%d rides, %d food stalls, %d decorations, paths", kinds.ride, kinds.stall, kinds.decor))
	d.rep, d.cash = 500, 1e10
	local lot0
	for _, l in ipairs(C.LOTS) do if not l.owner and l.dkey == "downtown" then lot0 = l break end end
	T.act(a, "plotBuyFor", lot0.dkey, "park")
	H.task.wait(0.5)
	H.check((d.levels.park or 0) == 0 and #d.deeds == 0, "below " .. C.REP_TIERS[4].name .. " it can't be opened, even by a forged request")

	H.section("Opening it through the menus")
	d.rep = 2000
	cc.selectBusiness("park")
	H.task.wait(1.5)
	local open = find(a.PlayerGui, function(x) return x.ClassName == "TextButton" and x.Text:find("OPEN ON A CITY PLOT", 1, true) ~= nil and x.Visible end)
	H.check(open ~= nil, "the business card says 🏙️ OPEN ON A CITY PLOT")
	click(open)
	H.task.wait(0.6)
	H.check(cc.modals.lotShop.frame.Visible and cc.LotShopUI.info and cc.LotShopUI.info.key == "park", "the plot picker opens for the park")
	local dkey
	for _, dd in ipairs(cc.LotShopUI.info.districts) do if not dd.why and not dkey then dkey = dd.key end end
	click(named("BuyFor_" .. dkey))
	H.task.wait(1.5)
	calm()
	H.check(d.levels.park == 1 and F.siteDeed(d, "park") ~= nil, "Buy & open: the park opens, its ticket gate on a " .. dkey .. " plot")
	H.task.wait(2.5)
	local site = F.parkSite(a)
	H.check(site ~= nil and site.owner == a, "Alice gets Funland site " .. (site and site.i or "?"))
	H.check(site and site.folder:GetAttribute("Owner") == a.UserId and site.folder:GetAttribute("OwnerName") == "Alice", "the site's gate sign shows whose park it is")
	local lotF = d.plot.slots.park
	H.check(lotF and find(lotF, function(x) return x.Name == "ParkGate" end) ~= nil, "the city plot has the ticket gate (🎢 Go to the park)")
	H.check(lotF and find(lotF, function(x) return x.Name == "KiddieCarousel" end) ~= nil, "...with a kiddie carousel turning in front")

	H.section("The 🎢 Park app")
	cc.openPark("park")
	H.task.wait(1.5)
	local info = cc.ParkUI.info
	H.check(cc.modals.park.frame.Visible and type(info) == "table" and info.open and info.site == site.i and info.rating == 0, "the app opens: Lv 1, site " .. tostring(info and info.site) .. ", rating 0")
	click(named("ParkTabBuild"))
	H.task.wait(0.6)
	H.check(named("ParkGrid") ~= nil and count(cc.ParkUI.cells) == PK.gw * PK.gh, "the BUILD tab shows the plan (" .. count(cc.ParkUI.cells or {}) .. " cells)")
	local cash0 = d.cash
	click(named("Shop_carousel"))
	click(cc.ParkUI.cells["3,2"])
	H.task.wait(0.6)
	local it1 = d.park.items[1]
	H.check(it1 and it1.k == "carousel" and it1.x == 3 and it1.z == 2 and math.abs((cash0 - d.cash) - 3000000) < F.incomePerSec(d) * 5 + 1, "pick 🎠 Carousel, tap a cell: it's built there and paid for")
	local m1 = site.models[it1 and it1.id or 0]
	local spinner = m1 and m1:FindFirstChild("Spinner")
	H.check(spinner and spinner:GetAttribute("Hub") ~= nil and find(m1, function(x) return x.Name == "RideSeat" end) ~= nil and m1:FindFirstChild("RideSpot") ~= nil,
		"the carousel stands in the park: a turning top, a seat to ride, a 🎢 Ride prompt")

	H.section("What the server refuses")
	local n0, c0 = #d.park.items, d.cash
	local function refused(label, k, x, z, r)
		T.act(a, "parkPlace", k, {x, z, r})
		H.task.wait(0.2)
		H.check(#d.park.items == n0 and d.cash >= c0, label)
	end
	refused("on top of the carousel", "teacups", 4, 3, 0)
	refused("over the gate (only paths may go there)", "bench", 0, 10, 0)
	refused("off the edge of the site", "ferris", 18, 23, 0)
	refused("a ride the park's level hasn't unlocked (🎢 Loop Coaster at Lv 1)", "loop", 8, 10, 0)
	refused("a made-up kind", "nuke", 5, 5, 0)
	refused("half a cell", "bench", 5.5, 5, 0)
	refused("a rotation of 7", "bench", 5, 5, 7)
	refused("huge numbers", "bench", 1e9, -1e9, 0)
	T.act(a, "parkPlace", "bench", "5,5,0")
	T.act(a, "parkPlace", {"bench"}, {5, 5, 0})
	H.task.wait(0.2)
	H.check(#d.park.items == n0 and d.cash >= c0, "...and badly shaped requests")
	d.cash = 1000
	c0 = d.cash
	refused("not enough cash", "teacups", 8, 2, 0)
	d.cash = 1e10
	c0 = d.cash
	T.act(bob, "parkPlace", "bench", {6, 6, 0})
	H.task.wait(0.2)
	H.check(#(F.parkRec(db).items) == 0 and F.parkSite(bob) == nil, "Bob (no park) can't build anywhere")
	T.act(a, "parkPlace", "path", {0, 10, 0})
	H.task.wait(0.2)
	H.check(#d.park.items == n0 + 1, "a path on the gate is fine")
	local cap = PK.baseItems
	for i = #d.park.items, cap - 1 do F.parkPlace(a, "path", 19, i - 2, 0) end
	local nn = #d.park.items
	T.act(a, "parkPlace", "flowers", {18, 0, 0})
	H.task.wait(0.2)
	H.check(nn == cap and #d.park.items == cap, "a Lv 1 park holds " .. cap .. " pieces; the next one is refused")

	H.section("Move, turn, sell")
	d.levels.park = 6
	-- clear the test paths
	for i = #d.park.items, 1, -1 do
		local it = d.park.items[i]
		if it.k == "path" and it.x == 19 then F.parkSell(a, it.id) end
	end
	cc.openPark("build")
	H.task.wait(1.2)
	click(named("ParkCancel"))
	click(cc.ParkUI.cells["3,2"])
	H.check(cc.ParkUI.sel.id == it1.id and named("ParkTurn") ~= nil, "tap the carousel: it's selected (Move / Turn / Sell)")
	click(named("ParkMove"))
	click(cc.ParkUI.cells["6,6"])
	H.task.wait(0.6)
	H.check(it1.x == 6 and it1.z == 6 and site.models[it1.id] and site.models[it1.id].Parent ~= nil and site.models[it1.id]:GetAttribute("Cell") == "6,6", "✋ Move, tap a cell: it moves there (rebuilt in place)")
	local ok, it2 = F.parkPlace(a, "ferris", 10, 0, 0)
	T.act(a, "parkInfo")
	H.task.wait(0.4)
	H.check(ok and it2.r == 0, "a 🎡 Ferris wheel (4 × 2) goes in")
	cc.ParkUI.sel.id = it2.id
	cc.ParkUI.render()
	click(named("ParkTurn"))
	H.task.wait(0.4)
	H.check(it2.r == 1 and site.models[it2.id]:GetAttribute("Size") == "2,4", "🔄 Turn: it turns a quarter (now 2 × 4)")
	local cs = d.cash
	cc.ParkUI.sel.id = it2.id
	cc.ParkUI.render()
	click(named("ParkSell"))
	local yes = cc.confirmBox and cc.confirmBox.Visible and find(cc.confirmBox, function(x) return x.ClassName == "TextButton" and x.Text == "Sell" end)
	H.check(yes ~= nil and #d.park.items >= 2, "selling asks first")
	click(yes)
	H.task.wait(0.4)
	local gone = true
	for _, it in ipairs(d.park.items) do if it.id == it2.id then gone = false end end
	H.check(gone and site.models[it2.id] == nil and d.cash - cs >= 4000000 - 1 and d.cash - cs < 4000000 + F.incomePerSec(d) * 12 + 1,
		string.format("...then it's gone and half its price comes back (+$%s)", C.fmt(d.cash - cs)))
	T.act(a, "parkSell", it1.id)
	H.task.wait(0.2)
	H.check(#d.park.items >= 1 and d.park.items[1].k == "carousel", "selling without the confirmation does nothing")

	H.section("Rating and sales")
	local r0 = F.parkScore(d)
	local m0 = F.parkMult(d, "park")
	for _, t in ipairs({{"loop", 2, 12, 0}, {"pirate", 12, 0, 0}, {"droptower", 16, 4, 0}, {"swing", 12, 16, 0}, {"teacups", 2, 2, 0}, {"bumper", 10, 6, 1},
		{"junior", 14, 10, 1}, {"ferris", 2, 18, 0}, {"cottoncandy", 1, 8, 0}, {"popcorn", 2, 8, 0}, {"icecream", 3, 8, 0}, {"balloons", 4, 8, 0}, {"fountain", 6, 2, 0}}) do
		local okP, why = F.parkPlace(a, t[1], t[2], t[3], t[4])
		if not okP then print("place failed", t[1], F.parkCanPlace(d, t[1], t[2], t[3], t[4])) end
	end
	for z = 9, 14 do F.parkPlace(a, "path", 1, z, 0) F.parkPlace(a, "path", 2, z, 0) end
	for x = 3, 9 do F.parkPlace(a, "path", x, 11, 0) end
	for _, t in ipairs({{"tree", 9, 9}, {"tree", 9, 13}, {"lamp", 3, 10}, {"bench", 4, 10}, {"flowers", 5, 10}}) do F.parkPlace(a, t[1], t[2], t[3], 0) end
	local r1, parts = F.parkScore(d)
	local m1x = F.parkMult(d, "park")
	H.check(r1 > r0 + 40 and m1x > m0 and m1x <= PK.multMax, string.format("more rides, stalls and paths: rating %d → %d, sales ×%.2f → ×%.2f (max ×%.1f)", r0, r1, m0, m1x, PK.multMax))
	local seen = {}
	for _, p in ipairs(parts) do seen[p[1]] = p[2] end
	H.check(seen["🎢 Rides"] > 0 and seen["🌈 Variety"] > 0 and seen["🍭 Food & treats"] > 0 and seen["🟫 Paths"] > 0, "the app shows why (rides, variety, food, decoration, paths)")
	local bm = F.bizMult(d, "park")
	d.levels.park = 6
	H.check(bm > 0 and math.abs(F.bizMult(d, "park") / bm - 1) < 0.01 and F.parkMult(d, "pizza") == 1, "the boost is part of the park's sales (and only the park's)")
	-- a pile of the same ride isn't worth as much as variety
	local dd = {levels = {park = 6}, park = {items = {}}}
	for i = 0, 4 do table.insert(dd.park.items, {id = i + 1, k = "carousel", x = (i % 5) * 4, z = 0, r = 0}) end
	local same = F.parkScore(dd)
	local dv = {levels = {park = 6}, park = {items = {{id = 1, k = "carousel", x = 0, z = 0, r = 0}, {id = 2, k = "teacups", x = 4, z = 0, r = 0}, {id = 3, k = "ferris", x = 8, z = 0, r = 0},
		{id = 4, k = "bumper", x = 12, z = 0, r = 0}, {id = 5, k = "swing", x = 0, z = 4, r = 0}}}}
	H.check(F.parkScore(dv) > same, "five different rides rate higher than five carousels")
	local dmax = {levels = {park = 10}, park = {items = {}}}
	local id = 0
	for x = 0, 19, 4 do for z = 0, 23, 4 do id += 1 table.insert(dmax.park.items, {id = id, k = ({"loop", "droptower", "pirate", "swing"})[id % 4 + 1] == "loop" and "carousel" or "teacups", x = x, z = z, r = 0}) end end
	H.check(F.parkMult(dmax, "park") <= PK.multMax + 1e-9, "the boost never goes over ×" .. PK.multMax)

	H.section("The rides move")
	H.task.wait(1)
	local wfx = cc.ParkFX
	local loopIt
	for _, it in ipairs(d.park.items) do if it.k == "loop" then loopIt = it end end
	local lm = loopIt and site.models[loopIt.id]
	local train = lm and lm:FindFirstChild("Train")
	H.check(train and wfx.movers[train] ~= nil and train:GetAttribute("Cycle") > 8, "the 🎢 Loop Coaster's train is on its track (" .. string.format("%.1f", train and train:GetAttribute("Cycle") or 0) .. " s a lap)")
	local seat = train and train:FindFirstChild("RideSeat")
	local cam = H.workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt((site.cf * CF(30, 30, 40)).Position, (site.cf * CF(30, 0, 60)).Position)
	local p1 = seat.Position
	H.task.wait(1.5)
	local p2 = seat.Position
	H.check((p2 - p1).Magnitude > 1, string.format("the train moves along the track (%.1f studs in 1.5 s)", (p2 - p1).Magnitude))
	local want = wfx.trainCF(train, nil, 0)
	H.check(want and (want.Position - seat.Position).Magnitude < 6, "...where the server clock says it should be (every player sees the same train)")
	local lowestUp, topY = 1, -1e9
	for t = 0, train:GetAttribute("Cycle"), 0.25 do
		local cfx = wfx.trainCF(train, t, 0)
		if cfx.UpVector.Y < lowestUp then lowestUp = cfx.UpVector.Y end
		topY = math.max(topY, cfx.Position.Y)
	end
	H.check(lowestUp < -0.5, string.format("it goes upside down in the loop (lowest up = %.2f)", lowestUp))
	H.check(topY > 12, string.format("and climbs the lift hill (top %.1f studs)", topY))
	local car = m1 and site.models[it1.id]:FindFirstChild("RideSeat", true)
	local q1 = car.CFrame
	H.task.wait(1)
	H.check((car.Position - q1.Position).Magnitude > 0.5, "the carousel turns")
	local dropIt
	for _, it in ipairs(d.park.items) do if it.k == "droptower" then dropIt = it end end
	local dseat = site.models[dropIt.id]:FindFirstChild("RideSeat", true)
	local ys = {}
	for _ = 1, 8 do table.insert(ys, dseat.Position.Y) H.task.wait(1.2) end
	local lo, hi = math.huge, -math.huge
	for _, y in ipairs(ys) do lo, hi = math.min(lo, y), math.max(hi, y) end
	H.check(hi - lo > 8, string.format("the drop tower lifts and drops (%.1f to %.1f)", lo, hi))

	H.section("Riding")
	local hrp = a.Character.HumanoidRootPart
	local spot = site.models[it1.id]:FindFirstChild("RideSpot")
	hrp.CFrame = CF(spot.Position + V3(-3, 1, 0))
	local mk = #H.remoteLog
	local okR = F.parkRide(a, a, it1.id)
	H.task.wait(0.5)
	H.check(okR and lastMenu("parkRide", mk) ~= nil and cam.CameraType == Enum.CameraType.Scriptable and wfx.riding ~= nil, "Alice rides her carousel: the camera rides the horse")
	local banner = named("RideBanner")
	H.check(banner and banner.Visible and banner.Text:find("Carousel", 1, true) ~= nil, "a banner says what you're riding")
	H.check(hrp.Anchored == true, "(she's held in place while the camera rides)")
	H.task.wait(16)
	H.check(cam.CameraType == Enum.CameraType.Custom and wfx.riding == nil and not hrp.Anchored, "after the ride the camera comes back")
	-- Bob rides it: Alice gets a ticket
	local bh = bob.Character.HumanoidRootPart
	bh.CFrame = CF(spot.Position + V3(40, 1, 40))
	H.check(not F.parkRide(bob, a, it1.id), "too far from the ride: no ride")
	bh.CFrame = CF(spot.Position + V3(-3, 1, 2))
	local ac, ar, gr = d.cash, d.rep, d.park.guestRides
	H.check(F.parkRide(bob, a, it1.id) == true, "Bob steps up and rides Alice's carousel")
	H.check(d.cash > ac and d.rep >= ar + 1 and d.park.guestRides == gr + 1, "Alice gets a ticket ($" .. C.fmt(d.cash - ac) .. ") and a little reputation")
	H.check(not F.parkRide(bob, a, it1.id), "one ride at a time")
	H.task.wait(16)
	H.check(not F.parkRide(bob, a, 99999), "a ride that doesn't exist: nothing")
	local coasterRide = F.parkRide(bob, a, loopIt.id)
	H.check(not coasterRide, "the coaster's prompt is at the coaster (Bob is at the carousel)")

	H.section("Visitors")
	cam.CFrame = CFrame.lookAt((site.cf * CF(20, 25, 48)).Position, (site.cf * CF(30, 0, 48)).Position)
	H.task.wait(2)
	H.check(wfx.site == site.folder and (wfx.active or 0) >= 3, (wfx.active or 0) .. " visitors walk around Alice's park")
	local onPath, candy, total = 0, 0, 0
	local pathSet = {}
	for _, it in ipairs(d.park.items) do if it.k == "path" then pathSet[it.x .. "," .. it.z] = true end end
	H.task.wait(3)
	-- (ParkFX keeps its pool private; check the people it posed through the CityCrowd person parts)
	local inv = site.cf:Inverse()
	for _, p in ipairs(H.workspace.CityCrowd:GetChildren()) do
		if p:IsA("BasePart") and p.Transparency == 0 and p.Size == V3(2, 2, 1) then
			local lp = inv * p.Position
			if lp.X > -2 and lp.X < 80 and lp.Z > 0 and lp.Z < 96 then
				total += 1
				local cx, cz = math.floor(lp.X / 4), math.floor(lp.Z / 4)
				if pathSet[cx .. "," .. cz] then onPath += 1 end
			end
		end
		if p:IsA("BasePart") and p.Transparency == 0 and p.Shape == Enum.PartType.Ball and p.Size == V3(1.3, 1.5, 1.3) then candy += 1 end
	end
	H.check(total >= 3 and onPath >= total - 1, onPath .. " of " .. total .. " visitors are on the paths")
	H.check(candy >= 1, candy .. " of them carry cotton candy")

	H.section("Visiting and leaving")
	cc.openPark("park")
	H.task.wait(1.5)
	H.check(cc.ParkUI.list and #cc.ParkUI.list == 1 and cc.ParkUI.list[1].name == "Alice", "the app lists the parks open in this server")
	db.rep, db.cash = 2000, 1e10
	H.check(F.plotBuyFor(bob, "suburbs", "park") or F.plotBuyFor(bob, "midtown", "park"), "Bob opens a park too")
	H.task.wait(2.5)
	local bsite = F.parkSite(bob)
	H.check(bsite and bsite ~= site, "...and gets his own site (" .. (bsite and bsite.i or "?") .. ")")
	F.parkPlace(bob, "carousel", 5, 5, 0)
	T.act(a, "parkGo", bob.UserId)
	H.task.wait(0.4)
	local ap = a.Character.HumanoidRootPart.Position
	H.check((ap - (bsite.cf * CF(0, 0, 48)).Position).Magnitude < 20, "Alice visits Bob's park (Visit → his gate)")
	local bdn = #db.park.items
	H.removePlayer(bob)
	H.task.wait(1)
	H.check(bsite.owner == nil and #bsite.items:GetChildren() == 0 and bsite.folder:GetAttribute("Owner") == 0, "Bob leaves: his site is cleared and free again")
	H.check(bdn == 1, "(his park is in his save, not lost)")

	H.section("Saved")
	local okSave = F.save and F.save(a)
	local store = rawget(T.slotStore(), "_data")
	local rec
	for k, v in pairs(store or {}) do if type(v) == "table" and k:find("u101_s") and type(v.park) == "table" then rec = v.park end end
	H.check(okSave and rec and #rec.items == #d.park.items and rec.guestRides == d.park.guestRides and rec.items[1].k == d.park.items[1].k, "the park is saved (" .. (rec and #rec.items or 0) .. " pieces, rides, guests)")
	-- a damaged record: bad entries are put aside, the rest builds
	local broken = {levels = {park = 3}, park = {items = {{id = 1, k = "carousel", x = 0, z = 0, r = 0}, {id = 2, k = "teacups", x = 1, z = 1, r = 0}, {k = "rocket", x = 3, z = 3}, "junk",
		{id = 5, k = "bench", x = 99, z = 0, r = 0}, {k = "bench", x = 10, z = 10, r = 1}}, visitors = "lots"}}
	local pr = F.parkRec(broken)
	H.check(#pr.items == 2 and pr.items[2].k == "bench" and pr.items[2].id > 0 and #pr.lost == 4 and pr.visitors == 0, "a damaged park loads what fits (the overlapping and unknown pieces are kept aside, not lost)")

	T.assertClean("park")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
