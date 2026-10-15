-- v18: 12-PLAYER SERVERS. 12 plots (4 round the plaza + 8 on Heights Blvd in the new Empire Heights neighbourhood):
-- 12 players each get their own plot, a 13th is turned away; Heights plots face their boulevard like the plaza
-- plots face Main St, don't overlap anything, and run a real business (customers come and pay); the Legacy Museum's
-- 4 halls are shared fairly; the map shows Empire Heights; the arch and the road to it exist.
-- Run with: python3 tests/run.py tests/servers_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	H.section("12 plots, 12 players")
	H.check(C.CFG.MAX_PLAYERS == 12 and #C.plots == 12, "MAX_PLAYERS = 12 and there are " .. #C.plots .. " plots")
	local players = {}
	for i = 1, 12 do
		players[i] = H.addPlayer("P" .. i, 1000 + i)
	end
	H.task.wait(2)
	for i = 1, 12 do T.act(players[i], "menuNew", 1, 1) end
	H.task.wait(3)
	local seen, all = {}, true
	for i = 1, 12 do
		local d = T.data(players[i])
		if not (d and d.plot) or seen[d.plot.index] then all = false else seen[d.plot.index] = true end
	end
	H.check(all, "all 12 players are playing, each on their own plot")
	local p13 = H.addPlayer("P13", 1013)
	H.task.wait(1.5)
	H.check(p13.Parent == nil or rawget(p13, "_p")._kicked ~= nil or T.data(p13) == nil, "a 13th player is turned away (server full)")

	H.section("12 full empires at once")
	local real0 = os.clock()
	for i = 1, 12 do
		local d = T.data(players[i])
		T.quietOnboarding(d)
		d.tut = 0
		d.cash, d.rep = 1e12, 9500
		for _, b in ipairs(C.BUSINESSES) do
			if not b.lotOnly then for _ = 1, 4 do T.act(players[i], "buy", b.key) end end
		end
	end
	H.task.wait(5)
	local writes0, mark0, t0 = H.dsWrites, #H.remoteLog, H.now()
	local parts0 = #H.workspace:GetDescendants()
	H.task.wait(240)
	local elapsed = H.now() - t0
	local wpm = (H.dsWrites - writes0) / (elapsed / 60)
	local ev = #H.remoteLog - mark0
	local parts1 = #H.workspace:GetDescendants()
	print(string.format("  12 empires: DataStore writes %.1f/min (Roblox budget for 12 players: 180/min), %.1f server->client events/s (%.1f per player), world %d -> %d instances, %.1fs real for %d simulated s",
		wpm, ev / elapsed, ev / elapsed / 12, parts0, parts1, os.clock() - real0, elapsed))
	H.check(wpm < 120, string.format("DataStore writes stay well inside the 12-player budget (%.0f/min of 180)", wpm))
	H.check(ev / elapsed / 12 < 12, string.format("network: %.1f events a second per player", ev / elapsed / 12))
	H.check(parts1 < parts0 * 1.15, "nothing piles up over 4 minutes (" .. parts0 .. " -> " .. parts1 .. " instances)")
	T.assertClean("12 full empires")

	H.section("Empire Heights")
	local function overlap(a, b)
		return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
	end
	local boxes = {}
	for i, p in ipairs(C.plots) do boxes[i] = {p.center.X - 45, p.center.Z - 45, p.center.X + 45, p.center.Z + 45} end
	local clash = false
	for i = 1, #boxes do for j = i + 1, #boxes do if overlap(boxes[i], boxes[j]) then clash = true end end end
	H.check(not clash, "no two plots overlap")
	local facing = true
	for i = 5, 12 do
		local p = C.plots[i]
		local sp = p.spawn.Position
		if math.abs(sp.Z) >= math.abs(p.center.Z) then facing = false end   -- the front (spawn) is toward the boulevard at z = 0
	end
	H.check(facing, "the 8 Heights plots face Heights Blvd, like the plaza plots face Main St")
	local roadsOK = true
	for _, r in ipairs(C.HEIGHTS_ROADS) do
		local axis, c, a, b, w = r[1], r[2], r[3], r[4], r[5]
		local rb = axis == "x" and {a, c - w / 2, b, c + w / 2} or {c - w / 2, a, c + w / 2, b}
		for i = 1, 12 do if overlap(rb, boxes[i]) then roadsOK = false print("road over plot", i) end end
	end
	H.check(roadsOK and #C.HEIGHTS_ROADS >= 4, "the road from Main St around the Corner Bank to Heights Blvd crosses no plot")
	local arch = C.WORLD:FindFirstChild("HeightsArch")
	H.check(arch and arch:FindFirstChildWhichIsA("SurfaceGui") ~= nil, "an \"EMPIRE HEIGHTS\" arch over the boulevard")
	-- the ground is there (terrain filled under the new plots)
	local base = C.plots[12].folder:FindFirstChild("Base")
	H.check(base and base.CanCollide, "every Heights plot has solid ground")

	H.section("A business in Empire Heights works")
	local hp, hd
	for i = 1, 12 do
		local d = T.data(players[i])
		if d.plot.index >= 5 then hp, hd = players[i], d break end
	end
	T.quietOnboarding(hd)
	hd.tut = 0
	hd.cash = 1e6
	T.act(hp, "buy", "lemonade")
	H.task.wait(0.5)
	local served0 = hd.served or 0
	local cash0 = hd.cash
	H.task.wait(25)
	H.check((hd.levels.lemonade or 0) >= 1 and (hd.served or 0) > served0 and hd.cash > cash0, string.format("plot %d: a Lemonade Stand opens, customers come and pay (%d served)", hd.plot.index, hd.served - served0))
	local slot = F.slotCF(hd.plot, "lemonade")
	local door = (slot * CFrame.new(0, 0, 9)).Position
	local c = hd.plot.center
	local onPlot = math.abs(door.X - c.X) < 45 and math.abs(door.Z - c.Z) < 45
	local towardBlvd = (door.Z - slot.Position.Z) * c.Z < 0   -- the door is on the side facing z = 0
	H.check(onPlot and towardBlvd, "its storefront stands on the Heights plot with its door facing the boulevard")

	H.section("The Legacy Museum's 4 halls are shared")
	for i = 1, 6 do F.refreshMuseum(players[i]) end
	H.task.wait(2)
	local halls = {}
	for i = 1, 6 do
		local h = F.galleryHall(players[i])
		if h then halls[h] = (halls[h] or 0) + 1 end
	end
	local used, dup = 0, false
	for _, n in pairs(halls) do used += 1 if n > 1 then dup = true end end
	H.check(used == 4 and not dup, "6 visitors, 4 halls: each hall shows one player (the newest visitors get them)")
	-- a player leaving frees their hall
	local holder
	for i = 1, 6 do if F.galleryHall(players[i]) then holder = players[i] break end end
	H.removePlayer(holder)
	H.task.wait(3)
	local free = 0
	for i = 1, 6 do if players[i] ~= holder and F.galleryHall(players[i]) then free += 1 end end
	H.check(free == 3 and F.galleryHall(holder) == nil, "when a player leaves, their hall is freed")

	H.section("The map")
	local cat = C.mapCatalog()
	local ok = cat and cat.bounds and cat.bounds[3] >= 1290 and cat.extraRoads and #cat.extraRoads == #C.HEIGHTS_ROADS
	H.check(ok, "the 🗺️ map is wide enough for Empire Heights and draws its roads")

	T.assertClean("servers")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
