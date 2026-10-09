-- v13: the living city (EmpireClient > CityCrowd). Pedestrians and traffic are a pool kept around the player, on
-- the real road network, obeying the traffic lights. Run with: python3 tests/run.py tests/city_test.lua
H.main(function()
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut = 0
	local CC = cc.CityCrowd
	local cam = H.workspace.CurrentCamera
	local V3, CF = Vector3.new, CFrame.new
	local function lookFrom(x, z)
		cam.CFrame = CFrame.lookAt(V3(x, 20, z), V3(x + 1, 0, z + 40))
	end
	local function onPeds() local n = 0 for _, p in ipairs(CC.peds) do if p.on then n += 1 end end return n end
	local function onCars() local n = 0 for _, c in ipairs(CC.cars) do if c.on then n += 1 end end return n end
	local function flat(p) return V3(p.X, 0, p.Z) end

	H.section("The network the server sends")
	H.check(#CC.ROADS >= 14 and #CC.WALKS >= 80, #CC.ROADS .. " roads, " .. #CC.WALKS .. " sidewalk segments")
	local nl = 0
	for _ in pairs(CC.LIGHTS) do nl += 1 end
	H.check(nl == 10, nl .. " traffic-light crossings")
	local dead = 0
	for _, w in ipairs(CC.WALKS) do if #w.next[1] == 0 and #w.next[-1] == 0 then dead += 1 end end
	H.check(dead < #CC.WALKS * 0.1, "sidewalks connect: only " .. dead .. " of " .. #CC.WALKS .. " are cut off at both ends")

	H.section("Pool sizes (Settings → Crowds)")
	lookFrom(0, -20)
	H.task.wait(2)
	H.check(onPeds() == CC.CFG.peds.high and onCars() == CC.CFG.cars.high, "HIGH: " .. onPeds() .. " people, " .. onCars() .. " cars")
	cc.setSetting("crowd", "low")
	H.task.wait(1)
	H.check(onPeds() == CC.CFG.peds.low and onCars() == CC.CFG.cars.low, "LOW: " .. onPeds() .. " people, " .. onCars() .. " cars")
	cc.setSetting("crowd", "off")
	H.task.wait(1)
	local visible = 0
	for _, x in ipairs(H.workspace.CityCrowd:GetChildren()) do if x.Transparency < 1 then visible += 1 end end
	H.check(onPeds() == 0 and onCars() == 0 and visible == 0, "OFF: nothing moves and nothing is drawn (" .. visible .. " visible parts)")
	cc.setSetting("crowd", "high")
	H.task.wait(1)
	local parts, solid = 0, 0
	for _, x in ipairs(H.workspace.CityCrowd:GetChildren()) do
		parts += 1
		if x.CanCollide or x.CanQuery or x.CanTouch then solid += 1 end
	end
	H.check(solid == 0, "crowd parts never collide, block clicks or touch anything (" .. parts .. " parts)")
	H.check(parts < 1200, "the whole crowd is " .. parts .. " parts (built once, reused)")

	H.section("Busy wherever you are")
	local places = {
		{"Downtown", 230, 0, {suit = true, coffee = true}},
		{"Industrial Zone", -230, 0, {worker = true}},
		{"the beach", 150, 335, {swim = true, tourist = true, jogger = true}},
		{"Maple suburbs (homes)", -230, 225, {jogger = true, dog = true, casual = true}},
		{"Hillside", -235, -195, {hiker = true, jogger = true}},
		{"the center", 0, 0, nil},
	}
	for _, pl in ipairs(places) do
		lookFrom(pl[2], pl[3])
		H.task.wait(14)
		local f = V3(pl[2], 0, pl[3])
		local near, typed, far = 0, 0, 0
		local looks = {}
		for _, p in ipairs(CC.peds) do
			if p.on then
				local pos = CC.WALKS[p.w.i] and Vector3.new(0, 0, 0)
				local w = p.w
				local pp = w.r.axis == "x" and V3(p.t, 0, w.perp) or V3(w.perp, 0, p.t)
				local dist = (pp - f).Magnitude
				if dist < 160 then
					near += 1
					looks[p.look] = (looks[p.look] or 0) + 1
					if pl[4] and pl[4][p.look] then typed += 1 end
				end
				if dist > CC.CFG.pedDrop + 20 then far += 1 end
				local _ = pos
			end
		end
		local carsNear = 0
		for _, c in ipairs(CC.cars) do
			if c.on then
				local cp = c.r.axis == "x" and V3(c.s, 0, c.r.c) or V3(c.r.c, 0, c.s)
				if (cp - f).Magnitude < 220 then carsNear += 1 end
			end
		end
		local mix = {}
		for k, n in pairs(looks) do table.insert(mix, k .. " " .. n) end
		table.sort(mix)
		H.check(near >= 18 and far == 0, string.format("%s: %d people within 160 studs (the old fixed loops: ~2-5), none left far behind", pl[1], near))
		H.check(carsNear >= 8, string.format("%s: %d cars within 220 studs", pl[1], carsNear))
		if pl[4] then
			H.check(typed >= near * 0.5, string.format("%s has its own crowd: %d / %d are %s (%s)", pl[1], typed, near, (function() local t = {} for k in pairs(pl[4]) do table.insert(t, k) end table.sort(t) return table.concat(t, "/") end)(), table.concat(mix, ", ")))
		end
	end

	H.section("Where they walk and drive")
	lookFrom(0, 0)
	local offWalk, offLane, overlaps, samples = {}, {}, 0, 0
	local function checkPositions()
		for _, p in ipairs(CC.peds) do
			if p.on then
				local w = p.w
				local inside = p.t >= w.s1 - 0.5 and p.t <= w.s2 + 0.5
				local crossing = p.cross ~= nil and math.abs(p.t - p.cross.from) <= 23
				if not (inside or crossing) then table.insert(offWalk, string.format("%.0f on [%.0f,%.0f]", p.t, w.s1, w.s2)) end
			end
		end
		for i, c in ipairs(CC.cars) do
			if c.on then
				if c.s < c.r.a - 2 or c.s > c.r.b + 2 then table.insert(offLane, c.kind .. string.format(" at %.0f on [%.0f,%.0f]", c.s, c.r.a, c.r.b)) end
				for j = i + 1, #CC.cars do
					local o = CC.cars[j]
					if o.on and o.r == c.r and o.dir == c.dir and not c.blend and not o.blend and math.abs(o.s - c.s) < (o.len + c.len) / 2 - 0.5 then overlaps += 1 end
				end
			end
		end
		samples += 1
	end
	for _ = 1, 60 do H.task.wait(0.5) checkPositions() end
	H.check(#offWalk == 0, "every person stays on a sidewalk or a crosswalk (" .. samples .. " samples)" .. (#offWalk > 0 and (": " .. table.concat(offWalk, ", "):sub(1, 300)) or ""))
	H.check(#offLane == 0, "every car stays on its road" .. (#offLane > 0 and (": " .. table.concat(offLane, ", "):sub(1, 300)) or ""))
	H.check(overlaps == 0, "no car drives into the one in front of it (" .. overlaps .. " overlaps)")

	H.section("Traffic lights")
	-- watch every car at every light: crossing the stop line while its light is red is running a red light
	local ran, stoppedAtRed, crossedOnGreen = 0, 0, 0
	local last = {}
	local pedOnRed, pedCross = 0, 0
	local wasCrossing = {}
	local conn = H.service("RunService").RenderStepped:Connect(function()
		for _, c in ipairs(CC.cars) do
			if c.on then
				local prev = last[c]
				-- (a car recycled to a new spot jumps: that's not driving over a line)
				if prev and prev.r == c.r and prev.dir == c.dir and math.abs(c.s - prev.s) < 8 then
					for _, x in ipairs(c.r.cuts) do
						if CC.hasLight(c.r, x) then
							local line = x - c.dir * 13
							if (prev.s - line) * c.dir < 0 and (c.s - line) * c.dir >= 0 then
								-- running a red = crossing the line while it is red (and was already red a frame ago);
								-- clearing the crossing on yellow is allowed
								if CC.red(c.r.axis) and prev.red then ran += 1 else crossedOnGreen += 1 end
							end
							if CC.red(c.r.axis) and math.abs(c.s - line) < 3 and c.v < 0.5 then stoppedAtRed += 1 end
						end
					end
				end
				last[c] = {r = c.r, dir = c.dir, s = c.s, red = CC.red(c.r.axis)}
			end
		end
		for _, p in ipairs(CC.peds) do
			if p.on then
				if p.cross and not wasCrossing[p] then
					pedCross += 1
					local x = p.dir == 1 and (p.cross.from + 11) or (p.cross.from - 11)
					if CC.hasLight(p.w.r, x) and not CC.green(p.w.r.axis) then pedOnRed += 1 end
				end
				wasCrossing[p] = p.cross ~= nil
			end
		end
	end)
	lookFrom(0, 0)
	H.task.wait(60)
	lookFrom(-200, 0)
	H.task.wait(40)
	conn:Disconnect()
	H.check(crossedOnGreen >= 10, crossedOnGreen .. " cars drove through a light on green (or cleared it on yellow)")
	H.check(ran == 0, "no car ran a red light (" .. ran .. ")")
	H.check(stoppedAtRed > 0, "cars wait at the stop line on red")
	H.check(pedCross >= 3 and pedOnRed == 0, pedCross .. " people crossed at a crossing; none started on red (" .. pedOnRed .. ")")

	H.section("Cost per frame")
	local f0, p0 = CC.stats.frames, CC.stats.posed
	H.task.wait(10)
	local frames, posed = CC.stats.frames - f0, CC.stats.posed - p0
	local per = posed / math.max(1, frames)
	H.check(per <= CC.CFG.peds.high + CC.CFG.cars.high, string.format("%.1f people/cars re-posed per frame on HIGH (far ones ~10x a second, budget %d)", per, CC.CFG.peds.high + CC.CFG.cars.high))
	local clock0 = os.clock()
	for _ = 1, 200 do H.service("RunService").RenderStepped:Fire(1 / 60) end
	H.task.wait(0.1)
	local ms = (os.clock() - clock0) / 200 * 1000
	H.check(ms < 8, string.format("one frame of the whole client (crowd included) takes %.2f ms in the test engine (Lua-only timing; real devices differ)", ms))

	H.section("Little scenes")
	local kinds = {}
	for _, s in ipairs(CC.SPOTS) do kinds[s.kind] = (kinds[s.kind] or 0) + 1 end
	H.check((kinds.musician or 0) >= 1 and (kinds.hotdog or 0) >= 1 and (kinds.umbrella or 0) >= 4 and (kinds.volley or 0) >= 2,
		"a street musician, hot-dog carts, beach umbrellas and volleyball (" .. #CC.SPOTS .. " scenes)")
	lookFrom(97, 400)
	H.task.wait(2)
	local beachOn = 0
	for _, s in ipairs(CC.SPOTS) do if s.on then beachOn += 1 end end
	lookFrom(-600, -400)
	H.task.wait(2)
	local stillOn = 0
	for _, s in ipairs(CC.SPOTS) do if s.on then stillOn += 1 end end
	H.check(beachOn >= 3 and stillOn == 0, "scenes appear when you're near (" .. beachOn .. " at the beach) and hide when you leave (" .. stillOn .. ")")

	T.assertClean("living city")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
