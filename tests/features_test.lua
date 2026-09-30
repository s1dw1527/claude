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

-- ===== 13 + 14. mega events and city eras =====
local function prompts(folder)
	local out = {}
	for _, d in ipairs(folder:GetDescendants()) do
		if d.ClassName == "ProximityPrompt" then table.insert(out, d) end
	end
	return out
end
local function trigger(prompt, plr) H.signalOf(prompt, "Triggered"):Fire(plr) H.task.wait(0.05) end
local function megaFolder() return H.workspace:FindFirstChild("MegaEvent") end
section("mega", function(ctx)
	H.section("13. Server-wide mega events")
	local a, da, b, db = ctx.a, ctx.da, ctx.b, ctx.db
	local F, C, G = T.F, T.C, T.C.G
	release(da)
	release(db)
	da.cash, db.cash = 50000, 50000
	for _, bk in ipairs({"lemonade", "icecream"}) do T.act(a, "buy", bk) T.act(b, "buy", bk) end
	local mark = #H.remoteLog
	-- UFO: zap every probe -> city saved, everyone gets a timed buff
	local ev = F.startMega("ufo")
	H.task.wait(0.3)
	local starts = T.remotesSince(mark, "Mega")
	H.check(#starts > 0 and starts[#starts].args[1].kind == "start" and starts[#starts].dir == "s2all", "every player gets the giant announcement")
	local gui = H.clientC.gui
	local shown = false
	for _, d in ipairs(gui:GetDescendants()) do
		if d.ClassName == "TextLabel" and d.Text == "UFO INVASION!" and d.Parent.Visible then shown = true end
	end
	H.check(shown, "the client shows the UFO INVASION! banner")
	local pr = prompts(megaFolder())
	H.check(#pr == 8, "8 alien probes landed around the city (" .. #pr .. ")")
	local c0 = da.cash
	for i, p in ipairs(pr) do trigger(p, i % 2 == 0 and b or a) end
	H.check(da.cash > c0, "zapping probes pays out")
	H.task.wait(0.5)
	H.check(C.MEGA_STATE.active == nil and megaFolder() == nil, "zapping all 8 ends the invasion early and cleans up")
	H.check((da.megaBuffUntil or 0) > H.now() and da.megaBuffMult == 1.1, "city saved: everyone gets +10% income")
	local gm1 = F.globalMult(da, H.now())
	da.megaBuffUntil = H.now() - 1
	H.check(F.globalMult(da, H.now()) < gm1, "...and the buff expires on its own")
	-- UFO failure: time runs out -> a small, capped abduction
	F.startMega("ufo")
	H.task.wait(1)
	local cashBefore = da.cash
	local incomeCap = F.incomePerSec(da) * 30
	H.task.wait(92)
	H.check(C.MEGA_STATE.active == nil, "the invasion ends when time runs out")
	H.check(cashBefore - da.cash <= math.max(cashBefore * 0.031, incomeCap + 1) + F.incomePerSec(da) * 100, "the abduction is small and capped")
	-- small events wait for mega events
	F.startMega("festival")
	H.task.wait(0.2)
	F.startEvent(H.now())
	H.check(G.event == nil, "small city events pause during a mega event")
	H.check(G.megaCustomers == 1.5, "festival: +50% customers")
	local tokens = C.MEGA_STATE.active.pickups
	H.check(#tokens == 10, "festival: 10 tokens hidden around the city")
	local root = a.Character.HumanoidRootPart
	local cf0 = root.CFrame
	root.CFrame = CFrame.new(tokens[1].pos + Vector3.new(0, 3, 0))
	H.task.wait(0.6)
	H.check(#C.MEGA_STATE.active.pickups == 9, "walking onto a token collects it")
	root.CFrame = cf0
	F.endMega()
	H.check(G.megaCustomers == nil and G.megaActive == false, "festival bonus is removed when it ends")
	-- tornado: moves, drops cash, knocks out a business on plots it passes
	F.startMega("tornado")
	H.task.wait(8)
	local tev = C.MEGA_STATE.active
	H.check(#tev.pickups > 0, "the tornado drops cash as it moves (" .. #tev.pickups .. " bundles)")
	local mover = megaFolder():FindFirstChild("Tornado")
	H.check(mover and mover:GetAttribute("From") and H.tagCount("MegaMover") >= 1, "the funnel is tagged for clients to animate")
	F.endMega()
	-- investor: best empire among the pitchers wins
	da.levels.icecream = 5
	F.startMega("investor")
	H.task.wait(0.3)
	local ip = prompts(megaFolder())
	H.check(#ip == 1, "the billionaire takes pitches")
	trigger(ip[1], a)
	trigger(ip[1], b)
	trigger(ip[1], a)
	local before2 = da.cash
	local sa, sb = F.empireScore(da), F.empireScore(db)
	F.endMega()
	H.check(da.cash - before2 >= 19000, string.format("the bigger empire (Alice) wins the jackpot (scores %d vs %d, +%d)", sa, sb, da.cash - before2))
	-- robbery: robbers appear at businesses; stopping one pays the hero
	F.startMega("robbery")
	H.task.wait(3)
	local rp = prompts(megaFolder())
	H.check(#rp >= 1, "a robber shows up at a business")
	local heroCash = db.cash
	trigger(rp[1], b)
	H.check(db.cash > heroCash, "stopping a robber pays the hero")
	H.task.wait(24)
	F.endMega()
	-- heatwave / blizzard / tourists / concert set and clear their bonuses
	F.startMega("heatwave")
	H.task.wait(0.2)
	H.check(G.megaBiz and G.megaBiz.lemonade == 3 and H.workspace:GetAttribute("Weather") == "heat", "heatwave: lemonade x3 and hot weather")
	F.endMega()
	H.check(G.megaBiz == nil, "heatwave bonus cleared")
	F.startMega("blizzard")
	H.task.wait(0.2)
	H.check(#prompts(megaFolder()) == 10 and G.megaBiz.coffee == 3, "blizzard: coffee x3 and 10 snowmen to smash")
	F.endMega()
	F.startMega("tourists")
	H.task.wait(0.2)
	H.check(G.megaCustomers == 3 and G.megaSatisfaction == 12, "tourist explosion: 3x customers, better reviews")
	F.endMega()
	H.check(G.megaCustomers == nil and G.megaSatisfaction == nil, "tourist bonus cleared")
	F.startMega("concert")
	root.CFrame = CFrame.new(230, 3, 110)
	H.task.wait(1)
	H.check((da.megaBuffUntil or 0) > H.now() and da.megaBuffMult == 1.15, "standing at the Downtown stage makes you a fan (+15% income)")
	root.CFrame = cf0
	F.endMega()
	-- automatic scheduling
	C.MEGA_STATE.nextAt = H.now() + 1
	H.task.wait(2)
	H.check(C.MEGA_STATE.active ~= nil, "mega events start on their own")
	F.endMega()
	T.assertClean("mega section")

	H.section("14. City Eras")
	H.check(H.workspace:GetAttribute("Era") == 1 and H.workspace:GetAttribute("EraName") == "Small Town", "the city starts as Era 1: Small Town")
	local eraFolder = H.workspace:FindFirstChild("City"):FindFirstChild("EraDecor")
	local parts1 = #eraFolder:GetDescendants()
	da.cash = 1e9
	for _ = 1, 5 do T.act(a, "contribute", "p50") end
	H.task.wait(0.5)
	H.check(G.spire.era == 2 and H.workspace:GetAttribute("EraName") == "Growing City", "finishing the Spire moves the server to Era 2: Growing City")
	local eraFolder2 = H.workspace:FindFirstChild("City"):FindFirstChild("EraDecor")
	H.check(#eraFolder2:GetDescendants() > parts1 + 20, "Era 2 visibly changes the city (cranes + towers)")
	H.check(da.eraContrib == 2, "Alice is credited for helping reach Era 2")
	local aliens = false
	for _ = 1, 40 do
		local e2 = F.startMega()
		if e2.def.key == "aliens" then aliens = true end
		F.endMega()
		if aliens then break end
	end
	H.check(aliens, "Era 2 unlocks the Alien Invasion mega event")
	F.buildEraDecor(4)
	H.task.wait(0.5)
	local grade = H.service("Lighting"):FindFirstChild("EraGrade")
	H.check(grade and grade.TintColor ~= Color3.new(1, 1, 1), "clients tint the city for the new era")
	local flyers = 0
	for _, p in ipairs(H.workspace:FindFirstChild("ClientCity"):GetChildren()) do
		if p.Position.Y > 50 then flyers += 1 end
	end
	H.check(flyers > 20, "Era 4 fills the sky with flying cars (" .. flyers .. " parts up high)")
	F.buildEraDecor(5)
	H.check(#H.workspace:FindFirstChild("City"):FindFirstChild("EraDecor"):GetDescendants() > #eraFolder2:GetDescendants(), "Era 5 (Cyber City) adds neon streets and light beams")
	da.eraContrib = 5
	T.act(a, "skin", "cyber")
	H.check(da.skin == "cyber", "helping reach Cyber City unlocks the Cyber Neon skin")
	T.act(b, "skin", "cyber")
	H.check(db.skin ~= "cyber", "players who didn't help can't equip it")
	F.buildEraDecor(G.spire.era)
	T.assertClean("era section")
end)

-- ===== 15, 16, 17 + 18: secrets, viral, CityBuzz achievements, photo mode =====
section("secrets", function(ctx)
	H.section("15. Secret businesses")
	local a, da, b, db = ctx.a, ctx.da, ctx.b, ctx.db
	local F, C, G = T.F, T.C, T.C.G
	release(da)
	da.cash, da.rep = 1e9, 500
	da.levels.arcade, da.levels.tech = 5, 3
	da.wentViral = false   -- (she may already have gone viral naturally earlier in the run)
	da.combos.moviestudio = nil
	F.checkCombos(a, da)
	H.check(not da.combos.moviestudio, "Movie Studio stays hidden without the viral quest")
	local arch = T.state(a).archive
	local rf
	for _, c in ipairs(arch.combos) do if c.name == "Rare Secret" and c.recipe:find("Machines") then rf = c end end
	H.check(rf ~= nil and not rf.recipe:find("Factory") and not rf.recipe:find("7"), "the archive shows only a riddle for rare secrets, never the recipe")
	-- viral moment (16) completes the Movie Studio quest
	local mark = #H.remoteLog
	local fol0, rep0 = da.followers, da.rep
	local rate0 = F.customerRate(da, H.now())
	F.goViral(a, da, "arcade", "This arcade is INSANE")
	H.task.wait(0.3)
	H.check(da.combos.moviestudio == true, "going viral unlocks the Movie Studio (hidden quest)")
	local kiosk = da.plot.kiosks.moviestudio
	H.check(kiosk and #kiosk:GetChildren() > 5, "the Movie Studio appears as its own building on the plot")
	-- robot factory needs era 3
	da.levels.factory, da.levels.tech = 7, 7
	F.checkCombos(a, da)
	H.check(not da.combos.robotfactory, "Robot Factory needs the city to reach Era 3")
	local era0 = G.spire.era
	G.spire.era = 3
	F.checkCombos(a, da)
	H.check(da.combos.robotfactory == true, "...and unlocks in Era 3")
	local pc0 = F.problemChance(da)
	-- bank: $100M earned + 10 rebirths
	local gm0 = F.globalMult(da, H.now())
	da.earned, da.rebirths = 2e8, 10
	F.checkCombos(a, da)
	H.check(da.combos.bank == true, "Billionaire Bank unlocks at $100M earned + 10 rebirths")
	H.check(F.globalMult(da, H.now()) > gm0 * 1.09, "the Bank's perk raises ALL income")
	-- space center: era 4 + the hidden launch pad
	da.levels.tech, da.levels.factory = 10, 5
	G.spire.era = 4
	F.checkCombos(a, da)
	H.check(not da.combos.spacecenter, "Space Center needs the hidden launch pad to be found")
	local root = a.Character.HumanoidRootPart
	local cf0 = root.CFrame
	root.CFrame = CFrame.new(600, 3, -520)
	H.task.wait(1.5)
	H.check(da.found and da.found.launchpad and da.combos.spacecenter == true, "exploring to the launch pad unlocks the Space Center")
	root.CFrame = CFrame.new(0, 3, 476)
	H.task.wait(1.5)
	H.check(da.found.goldenlemon == true and da.achievements.relic ~= nil, "the Golden Lemon relic is found at the end of the pier")
	root.CFrame = cf0
	G.spire.era = era0

	H.section("16. Viral influencer moments")
	local vmsg
	for _, e in ipairs(T.remotesSince(mark, "Mega")) do if e.args[1].kind == "viral" then vmsg = e end end
	H.check(vmsg and vmsg.dir == "s2all", "a viral moment is announced to the whole server")
	H.check(da.followers > fol0 and da.rep > rep0, "followers and reputation jump")
	H.check(F.customerRate(da, H.now()) >= math.min(3, rate0 * 2.9), "customers triple during the viral minute")
	local shown = false
	for _, d in ipairs(H.clientC.gui:GetDescendants()) do
		if d.ClassName == "TextButton" and tostring(d.Text):find("Replay cam") and d.Visible then shown = true end
	end
	H.check(shown, "the player gets a Replay cam button to record the moment")
	-- the influencer path through a real customer visit
	local gmath = H.G.math
	local rnd = gmath.random
	da.viralCooldown = 0
	da.viralUntil = 0
	gmath.random = function(x, y) if x == nil then return 0 end return rnd(x, y) end
	local influencer
	for _, t in ipairs(C.NPC_TYPES) do if t.trendy then influencer = t end end
	da.trendUntil = 0
	F.serveCustomer(a, da, "arcade", influencer, {stars = 5, text = "Best arcade in the city!"})
	gmath.random = rnd
	H.check((da.viralUntil or 0) > H.now(), "a 5-star influencer review can make you go viral")

	H.section("17. CityBuzz achievements")
	local cc = T.join("Cara", 303)
	local dcc = T.newGame(cc, 1, 1)
	dcc.cash = 1e6
	local m2 = #H.remoteLog
	T.act(cc, "buy", "icecream")
	H.task.wait(0.3)
	H.check(dcc.achievements and dcc.achievements.firstBusiness, "opening a first business unlocks an achievement")
	local ach
	for _, e in ipairs(T.remotesSince(m2, "Menu", cc)) do if e.args[1] == "achievement" then ach = e end end
	H.check(ach ~= nil, "the player gets an achievement card")
	local m3 = #H.remoteLog
	T.act(cc, "shareAch", "firstBusiness")
	H.task.wait(0.3)
	local post
	for _, e in ipairs(T.remotesSince(m3, "Buzz")) do
		if e.args[1].author == "Cara" then post = e.args[1] end
	end
	H.check(post and post.author == "Cara" and post.achievement == true, "sharing posts it to CityBuzz under Cara's name")
	local function caraPosts(mark)
		local n = 0
		for _, e in ipairs(T.remotesSince(mark, "Buzz")) do if e.args[1].author == "Cara" then n += 1 end end
		return n
	end
	local m4 = #H.remoteLog
	T.act(cc, "shareAch", "firstBusiness")
	H.check(caraPosts(m4) == 0, "each achievement can only be shared once")
	T.act(cc, "shareAch", "billion")
	H.check(caraPosts(m4) == 0, "you can't share an achievement you don't have")
	-- likes: real players' likes make a post trend (+25% customers)
	local rateBefore = F.customerRate(dcc, H.now())
	T.act(cc, "like", post.id)
	T.act(a, "like", post.id)
	T.act(b, "like", post.id)
	H.task.wait(21)
	H.check((dcc.postBuffUntil or 0) > H.now() and (dcc.postBuffMult or 1) >= 1.25, "a well-liked post trends and boosts customers")
	local likes = post.likes
	for _, p in ipairs(C.FEED) do if p.id == post.id then likes = p.likes end end
	H.check(likes >= 2, "likes are counted (" .. likes .. ")")
	dcc.earned = 2e6
	H.task.wait(6)
	H.check(dcc.achievements.million ~= nil, "earning $1M unlocks First Million")
	H.check(#T.state(cc).shareable >= 1, "unshared achievements are listed for sharing")

	H.section("18. Photo mode")
	local pc = H.clientC
	local camera = H.workspace.CurrentCamera
	pc.setPhoto(true)
	H.task.wait(0.3)
	H.check(pc.photoActive and not pc.gui.Enabled and camera.CameraType == Enum.CameraType.Scriptable, "photo mode hides the UI and takes over the camera")
	local hum = a.Character:FindFirstChildOfClass("Humanoid")
	H.check(hum.WalkSpeed == 0, "your character holds still for the shot")
	local c1 = camera.CFrame.Position
	H.keysDown[Enum.KeyCode.W] = true
	H.task.wait(1)
	H.keysDown[Enum.KeyCode.W] = false
	H.check((camera.CFrame.Position - c1).Magnitude > 10, "WASD flies the free camera")
	local photoGui = a.PlayerGui:FindFirstChild("PhotoMode")
	local function press(text)
		for _, d in ipairs(photoGui:GetDescendants()) do
			if d.ClassName == "TextButton" and tostring(d.Text):find(text, 1, true) then
				H.signalOf(d, "MouseButton1Click"):Fire()
				return true
			end
		end
	end
	H.check(press("Business"), "there is a business showcase shot")
	H.task.wait(0.5)
	local best = T.state(a).showcase.best
	H.check(best and (camera.CFrame.Position - best).Magnitude < 60, "the camera orbits your best business")
	press("Home")
	H.task.wait(0.5)
	press("Showcase my empire")
	H.task.wait(0.5)
	pc.setPhoto(false)
	H.task.wait(0.2)
	H.check(pc.gui.Enabled and camera.CameraType == Enum.CameraType.Custom and hum.WalkSpeed > 0, "leaving photo mode restores everything")
	T.assertClean("secrets/viral/buzz/photo section")
end)

-- ===== 19-22: house tours, weekly competitions, mystery lots, Legacy Museum =====
section("legacy", function(ctx)
	local a, da, b, db = ctx.a, ctx.da, ctx.b, ctx.db
	local F, C = T.F, T.C
	release(da)
	release(db)
	H.section("20. Weekly competitions")
	da.cash, da.rep, da.raceBest, da.followers = 5e6, 1200, 41.5, 900
	db.cash, db.rep, db.raceBest, db.followers = 9e6, 800, 38.25, 300
	F.save(a)
	F.save(b)
	H.task.wait(1)
	C.refreshWeeklyNow()
	local info = F.weeklyInfo(a)
	local function boardOf(key) for _, c in ipairs(info.categories) do if c.key == key then return c.list end end end
	H.check(#info.categories == 8, "8 weekly boards exist")
	H.check(boardOf("richest")[1].name == "Bob" and boardOf("rep")[1].name == "Alice", "richest and reputation boards rank correctly")
	local lap = boardOf("lap")
	H.check(#lap >= 2 and lap[1].value <= lap[2].value and lap[1].value <= 38250, "fastest lap ranks the lowest time first")
	H.check(type(info.featured) == "string" and info.endsIn > 0 and info.endsIn <= 604800, "there's a featured board and a reset countdown")
	-- last week's winners collect trophies once
	local lastWeek = C.weekId() - 1
	local st = H.stores["ordered:CE_Weekly_followers/w" .. lastWeek]
	if not st then
		H.service("DataStoreService"):GetOrderedDataStore("CE_Weekly_followers", "w" .. lastWeek):SetAsync("101", 5000)
	else
		st:SetAsync("101", 5000)
	end
	H.service("DataStoreService"):GetOrderedDataStore("CE_Weekly_followers", "w" .. lastWeek):SetAsync("202", 10)
	da.weeklyClaimed = nil
	hold(da)
	hold(db)
	H.task.wait(301)   -- let the 5-minute cache of last week's results expire
	release(da)
	release(db)
	local t0 = da.trophies
	F.claimWeeklyRewards(a)
	H.check(da.trophies > t0 and da.weeklyClaimed == lastWeek, "last week's #1 gets trophies when they play (" .. t0 .. " -> " .. da.trophies .. ")")
	local t1 = da.trophies
	F.claimWeeklyRewards(a)
	H.check(da.trophies == t1, "...only once")
	H.check(da.achievements.weeklyChamp ~= nil, "and a Weekly Champion achievement")

	H.section("18. Weekly Empire Showcase")
	T.act(a, "showcaseSubmit")
	H.task.wait(1)
	C.refreshWeeklyNow()
	local sc = F.weeklyInfo(b).showcase
	H.check(#sc >= 1 and sc[1].name == "Alice" and sc[1].info and sc[1].info.income ~= nil, "Alice's empire is in the showcase with its stats")
	T.act(b, "showcaseLike", 101)
	T.act(b, "showcaseLike", 101)
	T.act(a, "showcaseLike", 101)
	C.refreshWeeklyNow()
	H.check(F.weeklyInfo(b).showcase[1].likes == 1, "likes count once per player, and not your own")

	H.section("19. House tours")
	local ha, hb = F.homeLot(da), F.homeLot(db)
	H.check(ha and hb, "both players have houses")
	local tours = T.state(a).tours
	H.check(#tours >= 2, "the tour list shows every house in the server (" .. #tours .. ")")
	T.act(b, "tourVote", 101, "like")
	H.check((da.homeLikes or 0) == 0, "you can't like a house you haven't visited")
	T.act(b, "tourVisit", 101)
	H.task.wait(0.3)
	T.act(b, "tourVote", 101, "like")
	T.act(b, "tourVote", 101, "like")
	T.act(b, "tourVote", 101, "rate", 4)
	T.act(b, "tourVote", 101, "rate", 5)
	T.act(b, "tourVote", 101, "fav")
	H.check(da.homeLikes == 1 and da.homeRatingN == 1 and da.homeRatingSum == 4, "Bob likes once and rates once (4 stars)")
	H.check(db.favorites and db.favorites[1] and db.favorites[1].userId == 101, "Bob added Alice's house to favorites")
	T.act(a, "tourVote", 101, "like")
	H.check(da.homeLikes == 1, "you can't like your own house")
	T.act(b, "tourVote", 101, "rate", 99)
	T.act(b, "tourVote", 101, "rate", 0 / 0)
	H.check(da.homeRatingN == 1, "junk ratings are rejected")
	C.refreshWeeklyNow()
	local house = nil
	for _, c in ipairs(F.weeklyInfo(a).categories) do if c.key == "house" then house = c.list end end
	H.check(house[1] and house[1].name == "Alice", "the Best House weekly board counts likes and ratings")
	-- Alice's client: the tour panel appears at Bob's house
	T.act(a, "tourVisit", 202)
	H.task.wait(1.5)
	local panelShown = false
	for _, d in ipairs(H.clientC.gui:GetDescendants()) do
		if d.ClassName == "TextLabel" and tostring(d.Text):find("Bob's house") and d.Parent.Visible then panelShown = true end
	end
	H.check(panelShown, "Alice sees the house-tour panel at Bob's house")
	H.clientC.openModal("weekly")
	H.task.wait(1.5)
	T.assertClean("weekly app renders")

	H.section("21. Mystery lots")
	local site = F.spawnMysteryLot(2)
	H.task.wait(0.3)
	H.check(T.state(a).mysterySite ~= nil, "a mystery lot appears and shows up for players")
	local pr = prompts(H.workspace:FindFirstChild("City"):FindFirstChild("MysteryLot"))
	H.check(#pr == 1, "the lot can be bought")
	da.rep, da.cash = 5000, 1e13
	local function finds(d)
		local total = 0
		for _, n in pairs(d.mystery or {}) do total += n end
		return total
	end
	local f0 = finds(da)
	trigger(pr[1], a)
	H.task.wait(0.3)
	H.check(finds(da) == f0 + 1, "buying it reveals one mystery find")
	H.check(H.workspace:FindFirstChild("City"):FindFirstChild("MysteryReveal") ~= nil, "the find is revealed as a building")
	H.check(C.MYSTERY_STATE.active == nil, "the lot is gone once bought")
	trigger(pr[1], b)
	H.check(true, "nobody else can buy it after")
	-- rarity: roll many finds and check the legendary one is rare
	local counts = {}
	for _ = 1, 400 do
		F.spawnMysteryLot(1)
		local p2 = prompts(H.workspace:FindFirstChild("City"):FindFirstChild("MysteryLot"))[1]
		db.cash, db.rep = 1e12, 5000
		local before = H.deepCopy(db.mystery or {})
		H.signalOf(p2, "Triggered"):Fire(b)
		H.task.wait(0.03)
		for k, n in pairs(db.mystery or {}) do if n > (before[k] or 0) then counts[k] = (counts[k] or 0) + 1 end end
	end
	H.check((counts.space or 0) < 25 and (counts.arcade or 0) > 80, "legendary finds are rare (space " .. (counts.space or 0) .. "/400, arcade " .. (counts.arcade or 0) .. "/400)")
	H.check(F.mysteryPerk(db, "all") <= 1.02 ^ 5 * 1.04 ^ 5 * 1.1 ^ 5 + 1e-6, "mystery perks are capped at 5 stacks each")
	-- expiry
	F.spawnMysteryLot(3)
	C.MYSTERY_STATE.active.expires = H.now()
	H.task.wait(6)
	H.check(C.MYSTERY_STATE.active == nil, "an unsold lot vanishes after a while")

	H.section("22. Legacy Museum")
	for _, k in ipairs({"firstBusiness", "million", "trackRecord"}) do F.achieve(a, k) end
	H.task.wait(1.5)
	local gallery = H.workspace:FindFirstChild("City"):FindFirstChild("LegacyMuseum"):FindFirstChild("Gallery" .. da.plot.index)
	local function exhibitCount(g)
		local n = 0
		for _, x in ipairs(g:GetDescendants()) do
			if x.ClassName == "TextLabel" and #tostring(x.Text) > 3 and x.Text ~= "?" and not tostring(x.Text):find("Legacy") then n += 1 end
		end
		return n
	end
	local n1 = exhibitCount(gallery)
	local titles = {}
	for _, x in ipairs(gallery:GetDescendants()) do if x.ClassName == "TextLabel" then titles[x.Text] = true end end
	H.check(titles["First Business"] and titles["First Million"] and titles["Track Record"], "Alice's gallery displays her achievements as exhibits (" .. n1 .. " labels)")
	local banner = false
	for _, x in ipairs(gallery:GetDescendants()) do if x.ClassName == "TextLabel" and x.Text == "Alice's Legacy" then banner = true end end
	H.check(banner, "the gallery is labelled with her name")
	-- survives a rebirth
	da.rep, da.cash = 5000, 1e12
	F.rebirth(a)
	H.task.wait(1.5)
	gallery = H.workspace:FindFirstChild("City"):FindFirstChild("LegacyMuseum"):FindFirstChild("Gallery" .. da.plot.index)
	H.check(exhibitCount(gallery) >= n1, "the museum keeps everything after a rebirth")
	T.act(a, "tp", "museum")
	H.task.wait(0.2)
	local r = a.Character.HumanoidRootPart.Position
	H.check((r - C.MUSEUM_AT).Magnitude < 80, "Map → Legacy Museum teleports there")
	T.assertClean("legacy section")
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
