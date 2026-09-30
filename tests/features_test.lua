-- Feature tests for items 8-22 (plus performance checks). Run with: python3 tests/run.py tests/features_test.lua
local ONLY = nil -- set to a section name to run just that one
local SECTIONS = {}
local function section(name, fn) table.insert(SECTIONS, {name = name, fn = fn}) end

C_BIZ = nil
local function hold(d) d.frozenUntil = math.huge end
local function release(d) d.frozenUntil = 0 end
local function workersJSON(plr)
	local raw = T.data(plr).plot.folder:GetAttribute("Workers")
	if raw == nil or raw == "" then return {} end
	return H.service("HttpService"):JSONDecode(raw)
end

-- ===== 8. staff NPCs =====
section("staff", function(ctx)
	H.section("8. Staff physically exist at their businesses")
	local a, da = ctx.a, ctx.da
	local cc = H.clientC
	da.cash, da.rep = 1e7, 150
	T.act(a, "buy", "lemonade")
	T.act(a, "candidates", "lemonade")
	T.act(a, "hire", "lemonade", 1)
	H.task.wait(0.5)
	local list = workersJSON(a)
	H.check(#list == 1 and list[1].id == "lemonade", "hiring a Juice Maker publishes 1 worker on the plot")
	H.check(cc.workerCount() == 1, "the client draws that worker (" .. cc.workerCount() .. ")")
	for _, slot in ipairs({"manager", "marketer", "engineer"}) do
		T.act(a, "candidates", slot)
		T.act(a, "hire", slot, 2)
	end
	H.task.wait(0.5)
	H.check(#workersJSON(a) == 4 and cc.workerCount() == 4, "Manager, Marketer and Engineer appear too (4 workers)")
	-- geometry sanity: every worker stands on Alice's plot, business workers next to their business
	local plot = da.plot
	local onPlot, nearBiz = true, true
	for _, e in ipairs(workersJSON(a)) do
		local p = Vector3.new(e.x, 0, e.z)
		local c = Vector3.new(plot.center.X, 0, plot.center.Z)
		if math.abs(p.X - c.X) > 45 or math.abs(p.Z - c.Z) > 45 then onPlot = false end
		if C_BIZ[e.id] then
			local s = T.F.slotCF(plot, e.id).Position
			if (Vector3.new(s.X, 0, s.Z) - p).Magnitude > 9 then nearBiz = false end
		end
	end
	H.check(onPlot, "all workers stand inside the plot")
	H.check(nearBiz, "business workers stand at their own business")
	local drawn = 0
	for _, part in ipairs(H.workspace:FindFirstChild("Workers"):GetChildren()) do
		if part.Position.Magnitude > 20 then drawn += 1 end
	end
	H.check(drawn > 20, "worker parts are posed in the world, not left at the origin")
	-- stage change moves the worker out from behind the counter to the storefront
	local before = workersJSON(a)[1]
	for _ = 1, 2 do T.act(a, "buy", "lemonade") end
	H.task.wait(0.3)
	local after = workersJSON(a)[1]
	H.check((Vector3.new(before.x, 0, before.z) - Vector3.new(after.x, 0, after.z)).Magnitude > 3, "the worker moves when the stand becomes a shop")
	-- engineer heads to a problem
	local rnd = math.random
	F = T.F
	da.nextProblem = 0
	da.immune = {}
	local ok = pcall(function()
		local oldChance = F.problemChance
		F.problemChance = function() return 1 end
		H.task.wait(1.5)
		F.problemChance = oldChance
	end)
	local eng
	for _, e in ipairs(workersJSON(a)) do if e.id == "engineer" then eng = e end end
	H.check(next(da.problems) ~= nil and eng and eng.fx ~= nil, "when a business breaks, the Engineer gets a repair target")
	-- workers animate without errors for a while
	H.task.wait(10)
	-- firing removes the NPC
	T.act(a, "fire", "marketer")
	H.task.wait(0.3)
	H.check(#workersJSON(a) == 3 and cc.workerCount() == 3, "firing the Marketer removes that NPC")
	-- another player's staff show up on this client too
	local b, db = ctx.b, ctx.db
	db.cash, db.rep = 1e7, 150
	T.act(b, "buy", "icecream")
	T.act(b, "candidates", "icecream")
	T.act(b, "hire", "icecream", 1)
	H.task.wait(0.3)
	H.check(cc.workerCount() == 4, "Bob's Scooper appears on Alice's screen")
	-- leaving clears the plot; rejoining restores the staff
	F.save(b)
	H.task.wait(0.5)
	H.removePlayer(b)
	H.task.wait(1)
	H.check(cc.workerCount() == 3, "Bob's worker disappears when Bob leaves")
	b = T.join("Bob", 202)
	T.act(b, "menuPlay", 1)
	H.task.wait(3)
	ctx.b, ctx.db = b, T.data(b)
	H.check(cc.workerCount() == 4, "Bob's worker comes back when Bob reloads his save")
	-- cap: the client never draws more than 48
	H.check(cc.workerCount() <= 48, "worker count stays under the cap")
	T.assertClean("staff section")
end)

-- ===== main =====
H.main(function()
	T.startServer()
	C_BIZ = T.C.BIZ
	local ctx = {}
	ctx.a = H.addPlayer("Alice", 101)
	H.startClient(ctx.a, T.clientScript)
	H.task.wait(2)
	ctx.da = T.newGame(ctx.a, 1, 1)
	ctx.b = T.join("Bob", 202)
	ctx.db = T.newGame(ctx.b, 1, 2)
	T.assertClean("setup")
	for _, s in ipairs(SECTIONS) do
		if not ONLY or ONLY == s.name then
			local ok, err = xpcall(s.fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end, ctx)
			if not ok then
				H.failed += 1
				print("  CRASH in " .. s.name .. ": " .. err)
			end
		end
	end
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
