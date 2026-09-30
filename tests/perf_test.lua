-- 4-player soak test: everything running for 40 simulated minutes. Checks that parts, NPCs, effects,
-- remote traffic and DataStore usage stay bounded (no leaks), and that nothing errors along the way.
H.main(function()
	local clockStart = os.clock()
	local C = T.startServer()
	local F = C.F
	local players = {}
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	table.insert(players, a)
	for i, n in ipairs({"Bob", "Cara", "Dev"}) do table.insert(players, T.join(n, 200 + i)) end
	for i, p in ipairs(players) do T.act(p, "menuNew", 1, (i - 1) % 3 + 1) end
	H.task.wait(3)
	-- grow every empire: all businesses, all staff, a car, a rental, a home upgrade
	for i, p in ipairs(players) do
		local d = T.data(p)
		d.cash, d.rep = 1e12, 9500
		for _, b in ipairs(C.BUSINESSES) do
			for _ = 1, 6 do T.act(p, "buy", b.key) end
		end
		for _, slot in ipairs(C.STAFF_ORDER) do
			T.act(p, "candidates", slot)
			T.act(p, "hire", slot, 1)
		end
		T.act(p, "propBuy", i, "complex")
		T.act(p, "homeBuild")
		T.act(p, "car", "spawn", ({"coupe", "sedan", "van", "hyper"})[i])
		T.act(p, "ad", "small")
	end
	H.task.wait(5)
	T.assertClean("setup of 4 full empires")
	local cc = H.clientC
	H.check(cc.workerCount() == 44, "4 plots x 11 staff = 44 worker NPCs drawn (" .. cc.workerCount() .. ")")

	local function count(inst) return #inst:GetDescendants() end
	local function snapshot()
		return {
			world = count(H.workspace),
			workers = cc.workerCount(),
			carfx = H.workspace:FindFirstChild("CarFX") and #H.workspace.CarFX:GetChildren() or 0,
			clientCity = #H.workspace.ClientCity:GetChildren(),
			mega = H.workspace:FindFirstChild("MegaEvent") and count(H.workspace.MegaEvent) or 0,
		}
	end
	-- drive Alice's car around in circles (skids + smoke) while the city runs
	local car = F.activeCar(a)
	local mark = #H.remoteLog
	local writes0 = H.dsWrites
	local t0 = H.now()
	local samples = {}
	for minute = 1, 40 do
		for _ = 1, 6 do
			-- players keep doing things: posts, likes, upgrades, stock trades
			for _, p in ipairs(players) do
				local d = T.data(p)
				if d then
					T.act(p, "buy", C.BUSINESSES[math.random(#C.BUSINESSES)].key)
					if math.random() < 0.2 then T.act(p, "post", math.random(1, 7)) end
					if math.random() < 0.2 then T.act(p, "stock", players[math.random(#players)].UserId, "buy", 5) end
					if math.random() < 0.1 then T.act(p, "stock", players[math.random(#players)].UserId, "sell", 0) end
				end
			end
			if car and car.model.Parent then
				car.seat.ThrottleFloat, car.seat.SteerFloat = 1, math.sin(H.now()) > 0 and 1 or -1
				H.keysDown[Enum.KeyCode.Q] = math.random() < 0.5
				local v = car.root.AssemblyLinearVelocity
				car.root.CFrame = car.root.CFrame + Vector3.new(v.X, 0, v.Z) * 0.1
			end
			H.task.wait(10)
		end
		if minute == 5 or minute == 20 or minute == 40 then samples[minute] = snapshot() end
	end
	H.keysDown[Enum.KeyCode.Q] = false
	local elapsed = H.now() - t0
	T.assertClean("40 minutes of 4-player play")

	H.section("bounded growth (no leaks)")
	local s5, s20, s40 = samples[5], samples[20], samples[40]
	print(string.format("  world parts: %d (5 min) -> %d (20 min) -> %d (40 min)", s5.world, s20.world, s40.world))
	print(string.format("  client city FX: %d -> %d -> %d   skid marks: %d -> %d", s5.clientCity, s20.clientCity, s40.clientCity, s5.carfx, s40.carfx))
	H.check(math.abs(s40.world - s20.world) < 3000, "workspace size is stable between minute 20 and 40")
	H.check(s40.workers <= 48, "worker NPCs stay under the cap (" .. s40.workers .. ")")
	H.check(s40.carfx <= 160, "skid marks are recycled from a pool of 160 (" .. s40.carfx .. ")")
	H.check(s40.clientCity < s20.clientCity + 200, "client-side effects don't pile up")

	H.section("network + datastore budget")
	local states = T.remotesSince(mark, "State", a)
	local perSec = #states / elapsed
	local total = 0
	for _, e in ipairs(states) do total += #H.jsonEncode(e.args[1]) end
	local bytes = total / #states
	local full = #H.jsonEncode(T.state(a))
	print(string.format("  State packets to Alice: %.2f/s, %.1f KB on average (a full packet would be %.1f KB)", perSec, bytes / 1024, full / 1024))
	H.check(perSec <= 1.05, "state is sent at most once a second per player")
	H.check(bytes < full * 0.6, "unchanged sections are left out, so packets average well under a full state")
	local cs = H.clientC.S
	local complete = cs and cs.archive and cs.biz and cs.props and cs.tours and cs.market and cs.homeInfo
	H.check(complete ~= nil and complete ~= false, "the client still has every section of the state")
	local all = 0
	for i = mark + 1, #H.remoteLog do all += 1 end
	print(string.format("  all server->client remote events: %.1f/s for 4 players", all / elapsed))
	local wpm = (H.dsWrites - writes0) / (elapsed / 60)
	print(string.format("  DataStore writes: %.1f per minute (Roblox budget for 4 players: 100/min)", wpm))
	H.check(wpm < 60, "DataStore writes stay well inside the budget")
	print(string.format("\n  (simulated %d minutes in %.1fs of real time)", math.floor(elapsed / 60), os.clock() - clockStart))
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
