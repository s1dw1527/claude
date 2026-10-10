-- v14 Phase D: VEHICLE ROLES + TUNING (server-checked), LEADERBOARDS (server / global / friends) and PRESTIGE.
-- Run with: python3 tests/run.py tests/leaders_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	local cy = H.addPlayer("Cy", 103)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local dc = T.newGame(cy, 1, 1)
	local cc = H.clientC
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	for _, x in ipairs({d, db, dc}) do x.tut = 0 x.rep = 2000 x.cash = 1e9 end
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local VR = C.VEHICLES
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local function click(name)
		local b = find(a.PlayerGui, function(x) return x.Name == name end)
		if b then H.signalOf(b, "MouseButton1Click"):Fire() end
		return b
	end

	H.section("Vehicle roles")
	local roleOf = function(k) return (F.vehicleRole(C.CAR[k])) end
	H.check(roleOf("moped") == "commuter" and roleOf("van") == "hauler" and roleOf("suv") == "getaway" and roleOf("coupe") == "racer" and roleOf("velmora") == "vip" and roleOf("hyper") == "racer",
		"every class has a role: 🛵 Commuter, 🚚 Hauler, 🕶️ Getaway, 🏁 Racer, 🎩 VIP")
	d.cars.coupe, d.cars.velmora, d.cars.moped = true, true, true
	local car = F.spawnCar(a, "coupe") or F.activeCar(a)
	car = F.activeCar(a)
	H.check(car and car.seat:GetAttribute("Role") == "racer", "a spawned car knows its role")
	H.check(F.vehicleBonus(a, "race") == 1, "standing next to it: no bonus")
	car.seat:Sit(a.Character:FindFirstChildOfClass("Humanoid"))
	H.check(F.drivingRole(a) == "racer" and F.vehicleBonus(a, "race") == 1.15, "driving it: 🏁 +15% race prizes")
	F.spawnCar(a, "velmora")
	F.activeCar(a).seat:Sit(a.Character:FindFirstChildOfClass("Humanoid"))
	local rep0 = d.rep
	F.addRep(a, 10)
	H.check(math.abs((d.rep - rep0) - 11) < 0.01, "driving the VIP car: +10% reputation (" .. (d.rep - rep0) .. ")")
	F.despawnCar(a)

	H.section("Tuning")
	local spec = C.CAR.coupe
	local c0 = d.cash
	local cost = F.tuneCost(spec, 0)
	T.act(a, "carTune", "coupe", "engine")
	H.check(F.tuneLevel(d, "coupe", "engine") == 1 and c0 - d.cash >= cost - 1 and c0 - d.cash < cost + 1 + F.incomePerSec(d) * 2, "Engine level 1 for $" .. C.fmt(cost))
	H.check(F.tuneCost(C.CAR.moped, 0) == math.floor(math.max(VR.costMin, math.floor(C.CAR.moped.price * VR.costShare)) / 2), "🛵 Commuter cars tune for half")
	for _ = 1, 8 do T.act(a, "carTune", "coupe", "engine") end
	H.check(F.tuneLevel(d, "coupe", "engine") == VR.maxLevel, "up to level " .. VR.maxLevel)
	T.act(a, "carTune", "hyper", "engine")
	T.act(a, "carTune", "coupe", "nitrous")
	T.act(a, "carTune", 5, {})
	H.check(F.tuneLevel(d, "hyper", "engine") == 0, "a car you don't own, a made-up part, garbage: refused")
	F.spawnCar(a, "coupe")
	local seat = F.activeCar(a).seat
	local base = spec.speed * (1 + math.min(0.3, d.rebirths * 0.005))
	H.check(math.abs(seat:GetAttribute("MaxSpeed") - base * 1.1) < 0.01, string.format("the server writes the tuned top speed on the seat: %.1f → %.1f MPH (+10%% max)", base, seat:GetAttribute("MaxSpeed")))
	-- in the garage
	cc.openModal("garage", true)
	H.task.wait(0.8)
	cc.GarageUI.customize({key = "coupe"})
	H.task.wait(0.5)
	local lvl = F.tuneLevel(d, "coupe", "turbo")
	H.check(click("Tune_turbo") ~= nil, "the garage's customize screen has the tuning buttons")
	H.task.wait(0.6)
	H.check(F.tuneLevel(d, "coupe", "turbo") == lvl + 1, "tapping Turbo tunes it")
	cc.closeModals()
	F.despawnCar(a)

	H.section("Leaderboards: this server")
	d.rep, db.rep, dc.rep = 5000, 9000, 100
	local info = F.boardList(a, "popularity", "server")
	H.check(info and #info.list == 3 and info.list[1].name == "Bob" and info.list[3].name == "Cy" and info.mine == 2, "Popularity in this server: Bob, Alice, Cy (you: #2)")
	d.raceBest, db.raceBest = 41.5, 39.25
	info = F.boardList(a, "race", "server")
	H.check(#info.list == 2 and info.list[1].name == "Bob", "Fastest Lap: lowest time first, players without a lap aren't listed")
	H.check(#C.BOARDS == 8, "8 boards: " .. (function() local n = {} for _, b in ipairs(C.BOARDS) do table.insert(n, b.name) end return table.concat(n, ", ") end)())

	H.section("Leaderboards: global and friends")
	for _, p in ipairs({a, bob, cy}) do F.boardsPublish(p, true) end
	local st = H.stores["ordered:" .. C.storeName("CE_LB_popularity") .. "/global"]
	H.check(st and rawget(st, "_data")["101"] == 5000 and rawget(st, "_data")["102"] == 9000, "values are published to the global boards (written by the server)")
	H.check(rawget(H.stores["ordered:" .. C.storeName("CE_LB_race") .. "/global"], "_data")["102"] == 39250, "(lap times as milliseconds)")
	H.removePlayer(cy)
	H.task.wait(0.5)
	info = F.boardList(a, "popularity", "global")
	local names = {}
	for _, e in ipairs(info.list) do table.insert(names, e.name) end
	H.check(#info.list == 3 and info.list[3].name == "Cy", "global: everyone, even players in other servers (" .. table.concat(names, ", ") .. ")")
	C.friendCheckId = function(p, uid) return uid == 102 end
	info = F.boardList(a, "popularity", "friends")
	names = {}
	for _, e in ipairs(info.list) do table.insert(names, e.name) end
	H.check(#info.list == 2 and table.concat(names, ","):find("Bob") and not table.concat(names, ","):find("Cy"), "friends: just your friends and you (" .. table.concat(names, ", ") .. ")")

	H.section("The 📊 Leaders app")
	cc.openModal("leaders", true)
	H.task.wait(0.8)
	click("Board_race")
	H.task.wait(0.6)
	H.check(cc.LeadersUI.info.key == "race" and find(cc.modals.leaders.body, function(x) return x.Name == "Row_1" end) ~= nil, "pick a board: its ranking shows")
	click("Scope_global")
	H.task.wait(0.6)
	H.check(cc.LeadersUI.info.scope == "global", "switch to Global")
	click("TabPrestige")
	H.task.wait(0.3)
	local goals = 0
	for _, x in ipairs(cc.modals.leaders.body:GetDescendants()) do if x.ClassName == "TextLabel" and (x.Text:find("^☆") or x.Text:find("^⭐")) then goals += 1 end end
	H.check(goals == 10, "the prestige tab lists the 10 goals (" .. goals .. ")")
	cc.closeModals()

	H.section("Prestige")
	d.prestige = {stars = {}}
	F.prestigeCheck(a)
	H.check(d.prestige.seeded == true, "the first check only recognizes what's already done")
	local m0 = F.bizMult(d, "lemonade")
	d.heist.done = 10
	local mark = #H.remoteLog
	H.check(F.prestigeCheck(a) == 1 and F.prestigeStars(d) == (function() local n = 0 for _ in pairs(d.prestige.stars) do n += 1 end return n end)(), "10 heists: a prestige star")
	local splash = false
	for i = mark + 1, #H.remoteLog do
		local e = H.remoteLog[i]
		if e.name == "Splash" and tostring(e.args[1]):find("PRESTIGE STAR") then splash = true end
	end
	H.check(splash, "...celebrated")
	H.check(math.abs(F.bizMult(d, "lemonade") / m0 - (1 + 0.01 * F.prestigeStars(d)) / (1 + 0.01 * (F.prestigeStars(d) - 1))) < 1e-6, "+1% to all income per star")
	H.check(F.prestigeTitle(d) ~= nil, "and a title: " .. tostring(F.prestigeTitle(d)))
	-- a veteran save: stars for what it already did, quietly
	db.prestige = nil
	db.rebirths = 3
	db.levels.lemonade = 30
	db.chains.lemonade = 3
	mark = #H.remoteLog
	local got = F.prestigeCheck(bob)
	local loud = false
	for i = mark + 1, #H.remoteLog do
		local e = H.remoteLog[i]
		if e.name == "Splash" and e.player == bob then loud = true end
	end
	H.check(got >= 2 and not loud, "a veteran's first check: " .. got .. " stars recognized at once, without fanfare")

	H.section("Saved")
	F.save(a)
	local rec = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(rec and rec.tune and rec.tune.coupe.engine == 5 and rec.prestige and rec.prestige.stars.heists ~= nil, "tuning and prestige are saved")

	T.assertClean("leaders")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
