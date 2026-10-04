-- ECONOMY SIMULATOR: a bot plays a fresh save on the REAL server code (simulated time) and records when it
-- reaches each milestone. Nothing here is a formula of its own: every dollar comes from the game's own
-- income loop, customers, problems, events, deliveries and rewards.
--
--   SIM_ARGS='profile="casual", hours=10' python3 tests/run.py tests/economy_sim.lua
--   profile = "casual"  : checks in every ~15s, buys the best-value upgrade, repairs problems, no side activities
--             "active"  : checks in every 2s, also does deliveries, plays the Fun Park to its cap, runs ads,
--                         contributes to the Spire, and rebirths when it can (an experienced player)
--   passes  = "x2" / "x4" / "vip" (comma list) to see what paid passes do to the curve
local ARGS = SIM_ARGS or {}
local PROFILE = ARGS.profile or "casual"
local HOURS = ARGS.hours or 10
local ACTIVE = PROFILE == "active"
math.randomseed(ARGS.seed or 7)

H.main(function()
	H.fast = true
	H.quiet = true
	local C = T.startServer()
	local F, BIZ = C.F, C.BIZ
	local plr = H.addPlayer("Sim", 4242)
	H.task.wait(1.5)
	if ARGS.passes then
		for k in string.gmatch(ARGS.passes, "[^,]+") do H.ownedPasses[k] = true end
	end
	local d = T.newGame(plr, 1, 1)
	if ARGS.passes then
		for k in string.gmatch(ARGS.passes, "[^,]+") do d.passes[k] = true end
	end
	local t0 = H.now()
	local function mins() return (H.now() - t0) / 60 end
	local marks, order = {}, {}
	local function mark(key, label)
		if marks[key] then return end
		marks[key] = {t = mins(), label = label, earned = d.earned, inc = F.incomePerSec(d)}
		table.insert(order, key)
	end

	-- capture mini-game tokens the server sends to "the client"
	local token
	H.remoteHook = function(name, p, kind, key, tok)
		if name == "Menu" and p == plr and kind == "minigame" then token = tok end
	end

	-- value of a change = how much income/sec it adds (measured with the game's own F.income)
	local function incomeWith(fn, undo)
		fn()
		local v = F.income(d, os.clock())
		undo()
		return v
	end
	local function candidates()
		local now = os.clock()
		local base = F.income(d, now)
		local list = {}
		for _, b in ipairs(C.BUSINESSES) do
			local lvl = d.levels[b.key] or 0
			if lvl < C.CFG.MAX_LEVEL and F.bizUnlocked(d, b.key) then
				local cost = F.upgradeCost(d, b.key)
				local v = incomeWith(function() d.levels[b.key] = lvl + 1 end, function() d.levels[b.key] = lvl > 0 and lvl or nil end) - base
				-- a brand new business also brings its own customers; count that a little extra
				if lvl == 0 then v *= 1.5 end
				table.insert(list, {kind = "buy", key = b.key, cost = cost, gain = v})
			elseif lvl >= C.CFG.MAX_LEVEL and F.unlocked(d, "chains") then
				local cost = F.chainCost(d, b.key)
				if cost then
					local ch = d.chains[b.key] or 0
					local v = incomeWith(function() d.chains[b.key] = ch + 1 end, function() d.chains[b.key] = ch > 0 and ch or nil end) - base
					table.insert(list, {kind = "chain", key = b.key, cost = cost, gain = v})
				end
			end
		end
		-- district lots (land that pays income and boosts businesses)
		for _, lot in ipairs(C.LOTS) do
			local dd = C.DISTRICT[lot.dkey]
			if not lot.owner and F.tierIndex(d.rep) >= dd.tier then
				local v = incomeWith(function() d.lots[lot.id] = true end, function() d.lots[lot.id] = nil end) - base
				table.insert(list, {kind = "lot", lot = lot, cost = dd.cost, gain = v})
				break
			end
		end
		-- staff: +4% per star on that business (managers: +2% per star on everything)
		if F.unlocked(d, "staff") then
			for _, slot in ipairs(C.STAFF_ORDER) do
				if not d.staff[slot] and (not BIZ[slot] or (d.levels[slot] or 0) > 0) then
					local cost = F.hireCost(slot)
					local _, per = F.income(d, now)
					local v
					if BIZ[slot] then v = (per[slot] or 0) * 0.04 * 6 * 1.6
					elseif slot == "manager" then v = base * 0.02 * 6
					elseif slot == "marketer" then v = base * 0.3
					else v = base * 0.08 end
					table.insert(list, {kind = "hire", key = slot, cost = cost, gain = v})
				end
			end
		end
		-- home upgrades (+income %)
		local hc = F.homeBuildCost(d)
		if hc then
			local lvl = d.home.level
			local v = incomeWith(function() d.home.level = lvl + 1 end, function() d.home.level = lvl end) - base
			table.insert(list, {kind = "home", cost = hc, gain = v})
		end
		-- rental property (rent per unit every rent cycle)
		if F.unlocked(d, "properties") and #d.props < 3 then
			for _, r in ipairs(C.RENTALS) do
				local free
				for i, l in ipairs(C.RENT_LOTS) do if not l.owner then free = i break end end
				if free then
					local units = F.rentalUnits(r.key, 1)
					local v = F.rentPerUnit(r.key) * units / C.CFG.RENT_INTERVAL * F.globalRentMult(d) * 0.8
					table.insert(list, {kind = "prop", key = r.key, lot = free, cost = r.cost, gain = v})
				end
			end
		end
		return list
	end
	local function doBuy(c)
		if c.kind == "buy" then T.act(plr, "buy", c.key)
		elseif c.kind == "chain" then T.act(plr, "chain", c.key)
		elseif c.kind == "lot" then F.buyLot(plr, c.lot)
		elseif c.kind == "hire" then
			T.act(plr, "candidates", c.key)
			-- pick the best of the three candidates
			local best, bi = -1, 1
			for i, cand in ipairs(d.cands[c.key] or {}) do
				local s = cand.service + cand.speed + cand.exp
				if s > best then best, bi = s, i end
			end
			T.act(plr, "hire", c.key, bi)
		elseif c.kind == "home" then T.act(plr, "homeBuild")
		elseif c.kind == "prop" then T.act(plr, "propBuy", c.lot, c.key)
		end
	end
	local function spend()
		for _ = 1, 12 do
			local list = candidates()
			local best
			for _, c in ipairs(list) do
				c.ratio = c.cost / math.max(c.gain, 1e-6)
				if c.gain > 0 and (not best or c.ratio < best.ratio) then best = c end
			end
			if not best then return end
			local pick = best
			if d.cash < best.cost then
				-- can't afford the best deal yet: take a nearly-as-good affordable one, otherwise save up
				pick = nil
				for _, c in ipairs(list) do
					if c.gain > 0 and c.cost <= d.cash and c.ratio <= best.ratio * 1.35 and (not pick or c.ratio < pick.ratio) then pick = c end
				end
				if not pick then return end
			end
			local before = d.cash
			doBuy(pick)
			if d.cash >= before then return end
		end
	end

	local luxury = C.CAR.coupe
	local lastSpireAt, lastFun, lastAd = 0, -1e9, -1e9
	local nextCheck = 0
	local ticks = 0
	local rebirthAt
	-- where the money comes from: wrap the real functions and add up what each one pays
	local src = {}
	local function addSrc(k, v) src[k] = (src[k] or 0) + v end
	local function wrap(name, label)
		local orig = F[name]
		if not orig then return end
		F[name] = function(p, ...)
			local dd = C.data[p] or (type(p) == "table" and p.cash and p)
			local c0 = dd and dd.cash
			local r = table.pack(orig(p, ...))
			if dd and c0 and dd.cash > c0 then addSrc(label, dd.cash - c0) end
			return table.unpack(r, 1, r.n)
		end
	end
	local origServe = F.serveCustomer
	F.serveCustomer = function(p, dd, ...)
		local c0 = dd.cash
		origServe(p, dd, ...)
		if dd == d then addSrc("customers", dd.cash - c0) end
	end
	wrap("deliveryTick", "deliveries")
	wrap("finishMinigame", "mini-games")
	wrap("rentalTick", "rent")
	wrap("advanceTutorial", "tutorial")
	local lastCash = d.cash
	local repSrc = {}
	local origRep = F.addRep
	F.addRep = function(p, amount, ...)
		if p == plr and amount > 0 then
			local who = debug.info(2, "n") or "?"
			local line = debug.info(2, "l") or 0
			local k = who .. ":" .. line
			repSrc[k] = (repSrc[k] or 0) + amount * ((d.viralUntil or 0) > os.clock() and 2 or 1)
		end
		return origRep(p, amount, ...)
	end
	while mins() < HOURS * 60 do
		H.task.wait(1)
		ticks += 1
		local now = os.clock()
		if d.frozenUntil <= now then addSrc("passive income", F.income(d, now)) end
		-- milestones
		local lv, owned, total = 0, 0, 0
		for _, b in ipairs(C.BUSINESSES) do
			local l = d.levels[b.key] or 0
			total += l
			if l > 0 then owned += 1 end
			if l >= 2 then lv += 1 end
		end
		if lv > 0 then mark("firstUpgrade", "First business upgrade (Lemonade Lv 2)") end
		if owned >= 2 then mark("secondBiz", "Second business (Ice Cream Cart)") end
		if owned >= 4 then mark("fourBiz", "4 businesses") end
		if owned >= 8 then mark("allBiz", "All 8 businesses open") end
		if next(d.staff) then mark("firstStaff", "First employee") end
		if #d.props > 0 then mark("firstProp", "First rental property") end
		if d.tut == 0 then mark("tutorial", "Tutorial complete") end
		for i, tier in ipairs(C.REP_TIERS) do
			if i > 1 and d.rep >= tier.rep then mark("tier" .. i, "Reputation: " .. tier.name) end
		end
		for _, m in ipairs({{1e3, "$1K"}, {1e4, "$10K"}, {1e5, "$100K"}, {1e6, "$1M"}, {1e7, "$10M"}, {1e8, "$100M"}, {1e9, "$1B"}, {1e10, "$10B"}}) do
			if d.earned >= m[1] then mark("earned" .. m[2], "Lifetime earned " .. m[2]) end
		end
		local g = C.G.spire
		for e = 2, 5 do
			if g.era >= e then mark("era" .. e, "City Era " .. e .. " (" .. C.eraName(e) .. ")") end
		end
		if d.rebirths >= 1 then mark("rebirth1", "First rebirth") end
		if d.rebirths >= 2 then mark("rebirth2", "Second rebirth") end
		if F.storyChapter then
			local ch = F.storyChapter(d)
			for i = 2, ch do mark("story" .. i, "Story chapter " .. i .. (C.STORY and C.STORY[i] and (": " .. C.STORY[i].title) or "")) end
		end

		if H.now() >= nextCheck then
			nextCheck = H.now() + (ACTIVE and 2 or 15)
			-- tutorial chores (the steps a player does by hand)
			if d.tut == 4 then T.act(plr, "tut", "phone", true) T.act(plr, "tut", "phone", false) end
			if d.tut == 5 then
				local lot = F.homeLot(d)
				if lot and plr.Character then plr.Character.HumanoidRootPart.CFrame = CFrame.new(lot.pos + Vector3.new(0, 3, 0)) end
			end
			-- problems: repair them (that's what a sensible player does)
			for key, pr in pairs(d.problems) do
				if pr.state == "new" then T.act(plr, "problem", key, d.cash >= pr.repair and "repair" or "ignore") end
			end
			spend()
			-- the first car (tutorial step 7) and the first luxury car
			if F.unlocked(d, "cars") and not d.cars.moped and d.cash >= C.CAR.moped.price * 1.5 then
				T.act(plr, "car", "spawn", "moped")
				local car = F.activeCar(plr)
				if car then car.seat.Occupant = plr.Character:FindFirstChildOfClass("Humanoid") end
			end
			if not marks.luxuryCar and F.unlocked(d, "cars") and d.cash >= luxury.price * 2 then
				T.act(plr, "car", "spawn", "coupe")
				if d.cars.coupe then mark("luxuryCar", "First luxury purchase (" .. luxury.name .. ", $" .. C.fmt(luxury.price) .. ")") end
			end
			-- tenants: accept applicants into empty units
			for bi, b in ipairs(d.props) do
				for i = 1, #b.units do
					if not b.units[i] and b.applicants and #b.applicants > 0 then T.act(plr, "tenantAccept", bi, 1) end
				end
			end
			if ACTIVE then
				-- deliveries: accept, drive there (about 45 studs/s), arrive
				local dl = d.delivery
				if dl and dl.state == "offer" then T.act(plr, "delivery", "accept") end
				dl = d.delivery
				if dl and dl.state == "active" and not dl.simArrive then
					dl.simArrive = H.now() + (C.DESTS[dl.dest].pos - d.plot.center).Magnitude / 45
				end
				if dl and dl.state == "active" and H.now() >= dl.simArrive and plr.Character then
					plr.Character.HumanoidRootPart.CFrame = CFrame.new(C.DESTS[dl.dest].pos + Vector3.new(0, 3, 0))
				end
				-- the Fun Park: play memory match (perfect score) until the 10-minute cap pays nothing more
				if F.unlocked(d, "funpark") and H.now() - lastFun > 600 then
					lastFun = H.now()
					for _ = 1, 6 do
						token = nil
						F.startMinigame(plr, "memory")
						if not token then break end
						H.task.wait(8)
						local c0 = d.cash
						F.finishMinigame(plr, token, 3)
						if d.cash <= c0 then break end
						H.task.wait(3.2)
					end
				end
				-- ads when they're cheap compared to income
				if F.unlocked(d, "ads") and H.now() - lastAd > 180 and d.adUntil < now then
					local inc = F.incomePerSec(d)
					for i = #C.ADS, 1, -1 do
						local ad = C.ADS[i]
						if ad.cost <= inc * 45 and d.cash >= ad.cost * 2 then
							T.act(plr, "ad", ad.key)
							lastAd = H.now()
							break
						end
					end
				end
				-- the Spire: put in about 5% of what the empire earned since last time (a "good citizen")
				if H.now() - lastSpireAt > 120 then
					local amt = math.floor((d.earned - (d.simSpireBase or 0)) * 0.05)
					d.simSpireBase = d.earned
					lastSpireAt = H.now()
					if amt >= 1 and d.cash >= amt then F.contribute(plr, amt) end
				end
				-- rebirth as soon as it's allowed
				if F.unlocked(d, "rebirth") and d.cash >= F.rebirthCost(d) and d.rebirths < 2 then
					T.act(plr, "rebirth")
				end
			end
		end
		if ARGS.debugAt and ticks == ARGS.debugAt * 60 then
			local inc, per, g = F.income(d, now)
			print(string.format("DEBUG t=%dmin cash=%s inc=%s global=%.2f pass=%.2f rep=%d home=%.2f followers=%d", ticks / 60, C.fmt(d.cash), C.fmt(inc), g, F.passMult(d), d.rep, F.homeMult(d), d.followers or 0))
			for _, b in ipairs(C.BUSINESSES) do
				if (d.levels[b.key] or 0) > 0 then print(string.format("   %-9s lvl %2d chains %d bizMult %.2f per %s", b.key, d.levels[b.key], d.chains[b.key] or 0, F.bizMult(d, b.key), C.fmt(per[b.key]))) end
			end
			for k in pairs(d.combos) do print("   combo " .. k) end
			for k, st in pairs(d.staff) do print("   staff " .. k .. " stars " .. (st.service + st.speed + st.exp)) end
			print("   lots " .. F.countLots(d) .. "  era " .. C.G.spire.era .. " event " .. tostring(C.G.event and C.G.event.key) .. " mega " .. tostring(C.G.megaBiz ~= nil))
			for k, v in pairs(src) do print(string.format("   src %-16s %s", k, C.fmt(v))) end
			print("   earned " .. C.fmt(d.earned))
		end
		if ticks % 1800 == 0 then
			H.errors, H.warnings = {}, {}
			print(string.format("  ... %5.0f min  earned $%s  income $%s/s  rep %d  businesses %d  levels %d", mins(), C.fmt(d.earned), C.fmt(F.incomePerSec(d)), d.rep, owned, total))
		end
	end
	print(string.format("\n== %s player, %s, %d simulated hours ==", PROFILE, ARGS.passes and ("passes: " .. ARGS.passes) or "no passes", HOURS))
	table.sort(order, function(a, b) return marks[a].t < marks[b].t end)
	for _, k in ipairs(order) do
		local m = marks[k]
		local h = math.floor(m.t / 60)
		print(string.format("  %7s  %-52s  income then: $%s/s", h > 0 and string.format("%dh%02dm", h, math.floor(m.t % 60)) or string.format("%.1fm", m.t), m.label, C.fmt(m.inc)))
	end
	local tot = 0
	for _, v in pairs(src) do tot += v end
	tot = math.max(tot, d.earned)
	print("\n  where the money came from (of $" .. C.fmt(d.earned) .. " earned):")
	local keys = {}
	for k in pairs(src) do table.insert(keys, k) end
	table.sort(keys, function(a, b) return src[a] > src[b] end)
	for _, k in ipairs(keys) do print(string.format("    %-16s %5.1f%%", k, src[k] / tot * 100)) end
	if ARGS.repDebug then
		print("\n  reputation sources:")
		local rk = {}
		for k in pairs(repSrc) do table.insert(rk, k) end
		table.sort(rk, function(a, b) return repSrc[a] > repSrc[b] end)
		for _, k in ipairs(rk) do print(string.format("    %-30s %8.0f", k, repSrc[k])) end
	end
	print("\nMILESTONES_JSON " .. H.jsonEncode((function()
		local out = {}
		for k, m in pairs(marks) do out[k] = {t = math.floor(m.t * 10) / 10, label = m.label} end
		return out
	end)()))
end)
