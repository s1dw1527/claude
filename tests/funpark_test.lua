-- v15: the FUN PARK makeover. The Big Dipper roller coaster (a train that runs on every client in time with the
-- server clock, a lift hill, a loop, a ride that puts the camera in the front car), the Sky Drop and the Whirl, food
-- stalls with queues of people holding cotton candy, groups of friends with balloons, string lights, and the
-- rules for riding (Fun Park unlocked, a fee, one ride at a time).
-- Run with: python3 tests/run.py tests/funpark_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
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
	d.tut = 0
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local FUN = C.FUNPARK
	local PF = cc.ParkFX
	local cam = H.workspace.CurrentCamera
	local function look(x, z) cam.CFrame = CFrame.lookAt(V3(x, 25, z + 30), V3(x, 0, z)) end

	H.section("The Big Dipper")
	local dip = FUN and FUN.dipper
	local train = dip and dip:FindFirstChild("Train")
	H.check(train ~= nil and train:GetAttribute("Cycle") > 20, string.format("the Big Dipper's train is on its track (%.0f s a lap)", train and train:GetAttribute("Cycle") or 0))
	local x1, z1, x2, z2, top = math.huge, math.huge, -math.huge, -math.huge, 0
	for _, p in ipairs(dip:GetDescendants()) do
		if p:IsA("BasePart") then
			x1, z1, x2, z2 = math.min(x1, p.Position.X), math.min(z1, p.Position.Z), math.max(x2, p.Position.X), math.max(z2, p.Position.Z)
			top = math.max(top, p.Position.Y)
		end
	end
	H.check(x1 > -605 and x2 < -345 and z1 > 60 and z2 < 115, string.format("it fits in the park's south side, clear of the booths and the road (x %d..%d, z %d..%d)", x1, x2, z1, z2))
	H.check(top > 28, string.format("it's big: the lift hill tops out at %.0f studs", top))
	local supports = 0
	for _, p in ipairs(dip:GetDescendants()) do if p.Name == "Support" then supports += 1 end end
	H.check(supports >= 20, supports .. " supports hold the track up")
	look(-480, 90)
	H.task.wait(1)
	H.check(PF.movers[train] ~= nil, "the client runs the train")
	local seat = train:FindFirstChild("RideSeat")
	local p1 = seat.Position
	H.task.wait(1)
	H.check((seat.Position - p1).Magnitude > 2, string.format("the train moves (%.1f studs in a second)", (seat.Position - p1).Magnitude))
	local lowestUp, speeds = 1, {}
	local cyc = train:GetAttribute("Cycle")
	local prev
	for t = 0, cyc, 0.5 do
		local cf = PF.trainCF(train, t, 0)
		lowestUp = math.min(lowestUp, cf.UpVector.Y)
		if prev then table.insert(speeds, (cf.Position - prev).Magnitude / 0.5) end
		prev = cf.Position
	end
	table.sort(speeds)
	H.check(lowestUp < -0.5, "it goes upside down in the loop")
	H.check(speeds[1] < 8 and speeds[#speeds] > 20, string.format("slow up the lift hill (%.0f studs/s), fast down the drop (%.0f studs/s)", speeds[1], speeds[#speeds]))
	local cars = {}
	for _, p in ipairs(train:GetDescendants()) do if p:GetAttribute("Car") then cars[p:GetAttribute("Car")] = true end end
	local nc = 0
	for _ in pairs(cars) do nc += 1 end
	H.check(nc == 4, "a 4-car train")
	local c0, c3 = PF.trainCF(train, 5, 0), PF.trainCF(train, 5, 3)
	H.check((c0.Position - c3.Position).Magnitude > 7 and (c0.Position - c3.Position).Magnitude < 13, "the cars follow each other along the track")

	H.section("Riding it")
	local spot = dip:FindFirstChild("RideSpot")
	local hrp = a.Character.HumanoidRootPart
	hrp.CFrame = CF(spot.Position + V3(0, 1, 3))
	local pp = spot:FindFirstChildOfClass("ProximityPrompt")
	H.check(pp and pp.ActionText:find("Ride", 1, true), "the station has a 🎢 Ride prompt")
	d.rep = 0
	local cash0 = d.cash
	H.signalOf(pp, "Triggered"):Fire(a)
	H.task.wait(0.5)
	H.check(PF.riding == nil and d.cash == cash0, "before the Fun Park unlocks: no ride")
	d.rep, d.cash = 200, 1e7
	local fee = F.funFee(d, C.FERRIS.fee)
	cash0 = d.cash
	H.signalOf(pp, "Triggered"):Fire(a)
	H.task.wait(0.5)
	H.check(PF.riding ~= nil and PF.riding.coaster and cam.CameraType == Enum.CameraType.Scriptable, "Alice rides: the camera is in the front car")
	H.check(cash0 - d.cash >= fee - 1 - F.incomePerSec(d) and cash0 - d.cash <= fee + 1, "the ride costs the same as the Ferris wheel ($" .. C.fmt(fee) .. ")")
	H.task.wait(2)
	H.check((cam.CFrame.Position - seat.Position).Magnitude < 4, "the camera stays with the car")
	local c1 = d.cash
	H.signalOf(pp, "Triggered"):Fire(a)
	H.task.wait(0.3)
	H.check(d.cash >= c1, "one ride at a time (no second charge)")
	H.task.wait(cyc + 1)
	H.check(PF.riding == nil and cam.CameraType == Enum.CameraType.Custom and not hrp.Anchored, "after one lap the camera comes back")

	H.section("Sky Drop and the Whirl")
	look(-560, -92)
	local dseat = FUN.drop:FindFirstChild("RideSeat", true)
	local wseat = FUN.whirl:FindFirstChild("RideSeat", true)
	local ys, ws = {}, wseat.Position
	for _ = 1, 8 do table.insert(ys, dseat.Position.Y) H.task.wait(1.2) end
	local lo, hi = math.huge, -math.huge
	for _, y in ipairs(ys) do lo, hi = math.min(lo, y), math.max(hi, y) end
	H.check(hi - lo > 10, string.format("🗼 Sky Drop lifts and drops (%.0f → %.0f)", lo, hi))
	H.check((wseat.Position - ws).Magnitude > 2, "🌀 the Whirl's swings fly round")
	for _, m in ipairs({FUN.drop, FUN.whirl}) do
		local sp = m:FindFirstChild("RideSpot")
		H.check(sp and sp:FindFirstChildOfClass("ProximityPrompt") ~= nil, m.Name .. " has a Ride prompt")
	end
	local wsp = FUN.whirl:FindFirstChild("RideSpot")
	hrp.CFrame = CF(wsp.Position + V3(0, 1, 2))
	H.task.wait(7)
	H.signalOf(wsp:FindFirstChildOfClass("ProximityPrompt"), "Triggered"):Fire(a)
	H.task.wait(0.5)
	H.check(PF.riding ~= nil and PF.riding.name == "The Whirl", "riding the Whirl: the camera rides a swing")
	H.task.wait(15)

	H.section("Stalls and people")
	local stalls = C.FUNPARK_STALLS
	local candyStalls = 0
	for _, s in ipairs(stalls) do if s[1] == "cottoncandy" then candyStalls += 1 end end
	local built = 0
	for _, m in ipairs(C.WORLD.FunPark.Rides.Stalls:GetChildren()) do if m:GetAttribute("Stall") then built += 1 end end
	H.check(built == #stalls and candyStalls >= 3, built .. " food stalls (" .. candyStalls .. " cotton candy)")
	local CC = cc.CityCrowd
	local same = #CC.FUNPARK_STALLS == #stalls
	for i, s in ipairs(stalls) do
		local c = CC.FUNPARK_STALLS[i]
		if not (c and c[1] == s[1] and c[2] == s[2] and c[3] == s[3]) then same = false end
	end
	H.check(same, "the client's queues stand at the server's stalls")
	local queues, groups = 0, 0
	for _, s in ipairs(CC.SPOTS) do
		if s.kind == "stallqueue" then queues += 1 end
		if s.kind == "parkgroup" then groups += 1 end
	end
	H.check(queues == #stalls and groups >= 5, queues .. " stall queues, " .. groups .. " groups of friends")
	look(-480, 0)
	H.task.wait(1.5)
	local shown, candy = 0, 0
	for _, s in ipairs(CC.SPOTS) do
		if (s.kind == "stallqueue" or s.kind == "parkgroup") and s.on then
			shown += 1
			for _, p in ipairs(s.people) do if p.n.accKind == "candy" and p.n.acc.Transparency == 0 then candy += 1 end end
		end
	end
	H.check(shown >= 6 and candy >= 6, shown .. " scenes near the camera, " .. candy .. " people holding cotton candy")
	local onRoad = 0
	for _, s in ipairs(CC.SPOTS) do
		if (s.kind == "stallqueue" or s.kind == "parkgroup") then
			for _, p in ipairs(s.people) do
				local pos = (s.cf * p.off).Position
				if math.abs(pos.Z) < 7.5 and pos.X > -650 and pos.X < -340 then onRoad += 1 end
			end
		end
	end
	H.check(onRoad == 0, "nobody stands on Main St (it runs through the park)")
	local lightsOK = 0
	for _, m in ipairs(C.WORLD.FunPark.Rides.StringLights:GetChildren()) do
		if m.Name == "Bulbs" and H.service("CollectionService"):HasTag(m, "ChaseLights") then lightsOK += 1 end
	end
	H.check(lightsOK >= 5, lightsOK .. " strings of chasing lights over the walkway")

	H.section("Occasions")
	local rideTask
	for _, o in ipairs(C.OCCASIONS) do for _, t in ipairs(o.tasks) do if t.kind == "ride" then rideTask = o end end end
	H.check(rideTask ~= nil, "a special occasion asks for rides (" .. (rideTask and rideTask.name or "none") .. ")")

	T.assertClean("funpark")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
