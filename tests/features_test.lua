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

-- ===== 9 + 10. drifting and nitro controls =====
section("drift", function(ctx)
	H.section("9/10. Drifting and Nitro on every control type")
	local a, da = ctx.a, ctx.da
	local cc = H.clientC
	da.cash, da.rep = 1e7, 500
	T.act(a, "car", "spawn", "coupe")
	H.task.wait(1)
	local car = T.F.activeCar(a)
	H.check(car and car.seat.Occupant ~= nil and not car.root.Anchored, "Alice is driving an unanchored coupe")
	H.check(car.seat:GetAttribute("Grip") == 6 and car.seat:GetAttribute("Drift") == 1.35, "the coupe carries its own handling (grip 6, drift 1.35)")
	local gui = H.clientC.gui
	local function find(textPart)
		for _, d in ipairs(gui:GetDescendants()) do
			if d.ClassName == "TextButton" and tostring(d.Text):find(textPart, 1, true) then return d end
		end
	end
	local nitroBtn, driftBtn = find("NITRO"), find("DRIFT")
	H.task.wait(0.3)
	H.check(driftBtn and driftBtn.Parent.Visible, "the DRIFT button shows while driving")
	H.check(nitroBtn and not nitroBtn.Visible, "the NITRO button is hidden without the Nitro pass")
	-- straight line, then a normal turn vs a drift turn
	local seat, root = car.seat, car.root
	local function lateral()
		local v = root.AssemblyLinearVelocity
		local lv = root.CFrame.LookVector
		local look = Vector3.new(lv.X, 0, lv.Z).Unit
		return math.abs(v:Dot(Vector3.new(-look.Z, 0, look.X)))
	end
	seat.ThrottleFloat = 1
	H.task.wait(3)
	local fwdSpeed = root.AssemblyLinearVelocity.Magnitude
	H.check(fwdSpeed > 40, string.format("throttle accelerates the car (%.0f studs/s)", fwdSpeed))
	seat.SteerFloat = 1
	H.task.wait(1)
	local latGrip = lateral()
	H.keysDown[Enum.KeyCode.Q] = true
	-- the fake engine has no physics, so move the car along its own velocity while it drifts
	for _ = 1, 10 do
		local v = root.AssemblyLinearVelocity
		root.CFrame = root.CFrame + Vector3.new(v.X, 0, v.Z) * 0.1
		H.task.wait(0.1)
	end
	local latDrift = lateral()
	local label = ""
	for _, d in ipairs(gui:GetDescendants()) do
		if d.ClassName == "TextLabel" and tostring(d.Text):find("DRIFT") then label = d.Text end
	end
	H.check(latDrift > latGrip * 3 and latDrift > 8, string.format("holding Q makes the tail slide (sideways %.1f vs %.1f with grip)", latDrift, latGrip))
	local fwdNow = math.abs(root.AssemblyLinearVelocity:Dot(Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit))
	H.check(latDrift <= fwdNow * 0.9, string.format("the slide angle is capped (sideways %.0f vs forward %.0f)", latDrift, fwdNow))
	H.check(label:find("DRIFT") ~= nil, "the drift combo meter counts up (" .. label .. ")")
	H.keysDown[Enum.KeyCode.Q] = false
	seat.SteerFloat = 0
	H.task.wait(1.5)
	H.check(lateral() < 3, "letting go of drift regains grip")
	-- skid marks appear on the ground while sliding
	local fx = H.workspace:FindFirstChild("CarFX")
	H.check(fx and #fx:GetChildren() > 0, "skid marks were drawn (" .. (fx and #fx:GetChildren() or 0) .. " segments)")
	-- touch/mouse drift button works the same as the key
	driftBtn.InputBegan:Fire({UserInputType = Enum.UserInputType.Touch})
	seat.SteerFloat = -1
	H.task.wait(1)
	H.check(lateral() > 8, "holding the on-screen DRIFT button drifts too")
	driftBtn.InputEnded:Fire({UserInputType = Enum.UserInputType.Touch})
	seat.SteerFloat = 0
	-- nitro: pass owners get the button and every input boosts
	T.act(a, "pass", "nitro")
	H.task.wait(0.3)
	H.check(nitroBtn.Visible, "the NITRO button appears once Alice owns Nitro")
	local base = root.AssemblyLinearVelocity.Magnitude
	nitroBtn.InputBegan:Fire({UserInputType = Enum.UserInputType.MouseButton1})
	H.task.wait(2)
	local boosted = root.AssemblyLinearVelocity.Magnitude
	nitroBtn.InputEnded:Fire({UserInputType = Enum.UserInputType.MouseButton1})
	H.check(boosted > base * 1.2, string.format("clicking/tapping NITRO boosts (%.0f -> %.0f)", base, boosted))
	H.task.wait(3)
	H.keysDown[Enum.KeyCode.ButtonB] = true
	H.task.wait(1.5)
	local padBoost = root.AssemblyLinearVelocity.Magnitude
	H.keysDown[Enum.KeyCode.ButtonB] = false
	H.check(padBoost > 85, string.format("controller Ⓑ boosts too (%.0f)", padBoost))
	seat.ThrottleFloat = 0
	-- race drift zone: the server scores the car's own slide
	H.task.wait(2)
	local T0 = da.cash
	local function drive(to, speed, slide)
		local from = root.Position
		local dist = (to - from).Magnitude
		local steps = math.max(1, math.ceil(dist / speed / 0.1))
		for i = 1, steps do
			root.CFrame = CFrame.new(from:Lerp(to, i / steps) + Vector3.new(0, 2, 0))
			root.AssemblyLinearVelocity = slide and Vector3.new(45, 0, -45) or Vector3.new(0, 0, -60)
			H.task.wait(0.1)
		end
	end
	T.F.startRace(a)
	local armed = T.lastRemote("Race", a).args[1]
	drive(armed.start, 500)
	H.task.wait(0.3)
	local fin
	for _ = 1, 20 do
		local ev = T.lastRemote("Race", a).args[1]
		if ev.state ~= "running" then fin = ev break end
		drive(ev.next, 70, true)
		H.task.wait(0.2)
	end
	fin = fin or T.lastRemote("Race", a).args[1]
	H.check(fin.state == "finished" and (fin.driftBonus or 0) > 0, "sliding through the Drift Zone earns a server-scored bonus ($" .. tostring(fin.driftBonus) .. ", " .. tostring(fin.drift) .. " pts)")
	T.act(a, "car", "despawn")
	H.task.wait(0.5)
	T.assertClean("drift section")
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
