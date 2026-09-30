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

-- ===== 11 + 12. property upgrades and tenant consequences =====
section("property", function(ctx)
	H.section("11/12. Property upgrades and tenant consequences")
	local a, da = ctx.a, ctx.da
	local F, C = T.F, T.C
	da.cash, da.rep = 1e8, 500
	T.act(a, "propBuy", 1, "walkup")
	H.task.wait(0.3)
	local b = da.props[1]
	H.check(b and b.level == 1 and #b.units == 4, "a new Walk-Up is level 1 with 4 units")
	local cost1 = F.rentalUpgradeCost(b)
	local rent1, upkeep1, value1 = F.rentalRent(b), F.rentalUpkeep(b), F.rentalValue(b)
	local lotParts1 = #C.RENT_LOTS[1].folder:GetDescendants()
	T.act(a, "propUpgrade", 1)
	H.task.wait(0.3)
	H.check(b.level == 2 and #b.units == 6, "upgrading adds a floor: level 2, 6 units")
	H.check(#C.RENT_LOTS[1].folder:GetDescendants() > lotParts1, "the building is rebuilt bigger (" .. lotParts1 .. " -> " .. #C.RENT_LOTS[1].folder:GetDescendants() .. " parts)")
	local cost2 = F.rentalUpgradeCost(b)
	H.check(cost2 > cost1, "each upgrade costs more ($" .. cost1 .. " then $" .. cost2 .. ")")
	for _ = 1, 3 do T.act(a, "propUpgrade", 1) end
	H.task.wait(0.3)
	H.check(b.level == 5 and #b.units == 8, "fully upgraded Iconic Walk-Up has 8 units")
	H.check(F.rentalRent(b) > rent1 * 1.4, "rent per unit went up (" .. rent1 .. " -> " .. F.rentalRent(b) .. ")")
	H.check(F.rentalValue(b) > value1 * 5 and F.rentalUpkeep(b) > upkeep1 * 5, "value and upkeep grew with the investment")
	local c0 = da.cash
	T.act(a, "propUpgrade", 1)
	H.check(da.cash == c0, "no upgrade past the top level")
	H.check(F.rentalSellPrice(b) == math.floor(F.rentalValue(b) * 0.5), "selling pays half of everything invested")
	-- save + reload keeps level, units and tenant mood
	T.act(a, "tenantAccept", 1, 1)
	local t = b.units[1]
	H.check(t and type(t.mood) == "number", "tenants have a mood")
	t.mood = 33
	F.save(a)
	H.task.wait(0.5)
	local saved = rawget(H.stores["CornerEmpire_v5/global"], "_data")["u101_s1"]
	H.check(saved.props[1].level == 5 and #saved.props[1].units == 8 and saved.props[1].units[1].mood == 33, "level, units and mood are saved")
	-- old saves (no level) still load as level 1
	local old = H.deepCopy(saved)
	old.props[1].level, old.props[1].invested = nil, nil
	rawget(H.stores["CornerEmpire_v5/global"], "_data")["u101_s3"] = old
	-- tenant choices: warn / fine / evict have different effects
	local function place(credit, trait, strikes, mood)
		for i = 1, #b.units do b.units[i] = false end
		local ten = F.newApplicant()
		ten.credit, ten.trait, ten.strikes, ten.mood = credit, trait, strikes or 0, mood or 70
		b.units[1] = ten
		return ten
	end
	local function choose(ten, choice)
		local msg = {ref = {b = 1, u = 1, name = ten.name}}
		return F.tenantChoice(a, msg, choice)
	end
	local chef = place(5, 5)
	local rep0 = da.rep
	local r1 = choose(chef, 1)
	H.check(chef.strikes == 1 and chef.mood < 70 and da.rep > rep0, "Warn: a Home Chef takes a strike, a small mood hit, and sends cookies (+rep): " .. r1)
	local nerd = place(5, 8, 0, 70)
	local cashA = da.cash
	local r2 = choose(nerd, 2)
	H.check(nerd.strikes == 1 and nerd.mood <= 70 - 20 and (da.cash > cashA or b.units[1] == false), "Fine: strike + big mood hit + money: " .. r2)
	local broke = place(1, 1, 0, 70)
	local owes = 0
	for _ = 1, 30 do
		broke.strikes, broke.mood = 0, 70
		choose(broke, 2)
		if broke.owes then owes += 1 end
		b.units[1] = broke
		broke.owes = nil
	end
	H.check(owes > 3, "Fine: broke tenants (credit 1) often can't pay right away (" .. owes .. "/30 times)")
	local clean = place(4, 3, 0, 70)
	local neighbor = F.newApplicant()
	neighbor.mood = 70
	b.units[2] = neighbor
	local repB, cashB = da.rep, da.cash
	local r3 = choose(clean, 3)
	H.check(b.units[1] == false and da.rep < repB and da.cash < cashB and neighbor.mood < 70, "Evict (clean record): legal fee, -rep, nervous neighbors: " .. r3)
	local bad = place(2, 1, 2, 40)
	b.units[2] = neighbor
	local nm = neighbor.mood
	local r4 = choose(bad, 3)
	H.check(neighbor.mood > nm, "Evict (2 strikes): the neighbors are happier: " .. r4)
	local three = place(3, 2, 2, 60)
	local r5 = choose(three, 1)
	H.check(b.units[1] == false, "Warn: strike 3 means they leave: " .. r5)
	-- miserable tenants move out on their own at rent time
	local sad = place(3, 2, 0, 5)
	H.task.wait(35)
	H.check(b.units[1] == false, "a tenant at mood 5 moves out on their own")
	-- load the old-format save
	T.act(a, "menuExit")
	H.task.wait(1)
	T.act(a, "menuPlay", 3)
	H.task.wait(2)
	local d3 = T.data(a)
	H.check(d3 and d3.props[1] and d3.props[1].level == 1 and #d3.props[1].units == 4, "an old save without levels loads as a level 1 building")
	T.act(a, "menuExit")
	H.task.wait(1)
	T.act(a, "menuPlay", 1)
	H.task.wait(2)
	ctx.da = T.data(a)
	H.check(ctx.da.props[1].level == 5 and #ctx.da.props[1].units == 8, "the upgraded save reloads with its upgrades")
	-- the Properties app renders all of this without errors
	H.clientC.openModal("properties")
	H.task.wait(1.2)
	T.assertClean("property section")
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
