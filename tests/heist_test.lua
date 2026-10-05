-- v11: the secret mountain base (lever, door, tunnel, chamber, crew, discovery) and the robbery system (rotation,
-- puzzles, loot, alarm, police, escape, turn-in, arrests, failures, teams, upgrades, anti-exploit), with 1-4 players.
-- Run with: python3 tests/run.py tests/heist_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local MC = C.MOUNTAIN
	local HS = C.HEIST_STATE
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut, db.tut = 0, 0
	d.rep, db.rep = 1500, 1500       -- CITY ICON: heists unlocked
	C.G.nextEvent = H.now() + 7200
	HS.G.nextOpen = H.now() + 7200   -- (no random openings during the test: we open targets ourselves)
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function trigger(pp, who) H.signalOf(pp, "Triggered"):Fire(who) H.task.wait(0.3) end
	local function prompt(root, action, object)
		for _, x in ipairs(root:GetDescendants()) do
			if x.ClassName == "ProximityPrompt" and x.ActionText == action and (not object or x.ObjectText == object) then return x end
		end
	end
	local function at(plr, pos)
		if not plr.Character then print("    (no character: " .. plr.Name .. ")") return end
		plr.Character:PivotTo(CFrame.new(pos))
		H.task.wait(0.1)
	end
	local function lastMenu(plr, kind, mark)
		for i = #H.remoteLog, (mark or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.player == plr and e.args[1] == kind then return e.args[2] end
		end
	end
	local function splashed(plr, pat, mark)
		for i = (mark or 0) + 1, #H.remoteLog do
			local e = H.remoteLog[i]
			if e.name == "Splash" and e.player == plr and tostring(e.args[1]):find(pat) then return true end
		end
		return false
	end
	local mtn = H.workspace:FindFirstChild("City"):FindFirstChild("Mountain")
	local sites = H.workspace:FindFirstChild("City"):FindFirstChild("HeistSites")
	local TU, CH = MC.tunnel, MC.chamber

	H.section("The mountain")
	H.check(mtn ~= nil and MC.shellParts > 150, "a mountain of " .. MC.shellParts .. " rock blocks north of the race track")
	H.check(MC.doorState("main") == "closed" and MC.doorState("back") == "closed", "both secret doors start closed")
	-- the drivable volume of the tunnel must be clear of every part (except the door itself)
	local widest, tallest = 0, 0
	for _, c in ipairs(C.CARS) do
		widest = math.max(widest, c.W or 2)
		tallest = math.max(tallest, (c.clear or 1) + (c.H or 2) + (c.roof or 0))
	end
	local blockers = {}
	local door = MC.doors.main.part
	for _, p in ipairs(H.workspace:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide and p ~= door and not p:FindFirstAncestorOfClass("Model") then
			local q = p.Position
			if q.X > TU.x0 + 1 and q.X < TU.x1 - 1 and q.Z > TU.z0 + 1 and q.Z < TU.z1 - 1 and q.Y > 0.5 and q.Y < TU.h - 1 then table.insert(blockers, p:GetFullName()) end
		end
	end
	H.check(#blockers == 0, "the tunnel lane is clear" .. (#blockers > 0 and (": " .. table.concat(blockers, ", ")) or ""))
	H.check(TU.x1 - TU.x0 >= widest * 3 and TU.h >= tallest * 1.6, "the tunnel (" .. (TU.x1 - TU.x0) .. " wide, " .. TU.h .. " high) fits every car (widest " .. widest .. ", tallest " .. string.format("%.1f", tallest) .. ")")
	H.check(CH.x1 - CH.x0 > 150 and CH.h > 60, "a huge chamber inside (" .. (CH.x1 - CH.x0) .. " × " .. (CH.z1 - CH.z0) .. ", " .. CH.h .. " high)")
	local stations = 0
	for _ in pairs(MC.stations) do stations += 1 end
	H.check(stations == 7, "7 working stations: job board, fence, quartermaster, planning, computer, base upgrades, garage")
	local crewText = mtn:GetAttribute("Crew") or ""
	local nCrew = select(2, string.gsub(crewText, "\n", "\n")) + 1
	H.check(nCrew == 8 and crewText:find("The Boss") and not crewText:lower():find("jailbreak"), "8 fictional crew members (The Blackrock Syndicate)")

	H.section("The lever and the door")
	local lever = MC.mainLever
	at(a, Vector3.new(300, 4, TU.z1 + 20))
	at(bob, Vector3.new(305, 4, TU.z1 + 24))
	trigger(lever, a)
	H.check(MC.doorState("main") == "opening", "pulling the lever starts the mechanism (lever, sound, gears)")
	H.task.wait(3.5)
	H.check(MC.doorState("main") == "open" and mtn:GetAttribute("Door_main") == "open", "the hidden door slides open (everyone sees the same door)")
	H.check((door.Position - MC.doors.main.closed.Position).Magnitude > 20, "it moved aside, it didn't vanish")
	local lit = 0
	for _, p in ipairs(mtn:GetDescendants()) do if p.ClassName == "PointLight" and p.Enabled and p.Parent.Position.Z > TU.z0 and p.Parent.Position.Z < TU.z1 and p.Parent.Position.X > TU.x0 and p.Parent.Position.X < TU.x1 then lit += 1 end end
	H.check(lit >= 4, "the tunnel lights come on (" .. lit .. ")")
	-- someone standing in the doorway keeps it open
	at(bob, Vector3.new(300, 4, TU.z1 - 2))
	H.task.wait(MC.doorOpenSeconds + 4)
	H.check(MC.doorState("main") == "open", "it stays open while someone is in the doorway")
	at(bob, Vector3.new(300, 4, TU.z1 + 60))
	at(a, Vector3.new(300, 4, TU.z1 + 60))
	H.task.wait(MC.doorOpenSeconds + 5)
	H.check(MC.doorState("main") == "closed", "with nobody around it closes again")
	-- a car in the doorway keeps it open too
	trigger(lever, a)
	H.task.wait(3.5)
	F.buyOrDrive(a, "moped")
	d.cash = 1e9
	F.buyOrDrive(a, "truck")
	H.task.wait(0.5)
	local car = F.activeCar(a)
	if car then
		for _, x in ipairs(car.model:GetDescendants()) do if x:IsA("BasePart") then x.Anchored = true end end
		car.model:PivotTo(CFrame.new(300, 2, TU.z1 - 4))
	end
	at(a, Vector3.new(300, 4, TU.z1 + 70))
	H.task.wait(MC.doorOpenSeconds + 4)
	H.check(car and MC.doorState("main") == "open", "a car in the doorway keeps it open (nothing gets crushed)")
	F.despawnCar(a)
	H.task.wait(MC.doorOpenSeconds + 5)
	H.check(MC.doorState("main") == "closed", "...and it closes once the car is gone")
	-- nobody can be trapped: from inside, walking up to the door opens it
	at(a, Vector3.new(300, 4, -700))
	H.task.wait(2)
	H.check(d.heist.discovered and splashed(a, "SECRET HQ"), "first time inside: \"YOU FOUND THE SECRET HQ\"")
	H.check(a:GetAttribute("InBase") == true, "the server knows Alice is in the base")
	at(a, Vector3.new(300, 4, TU.z1 - 12))
	H.task.wait(1.5)
	H.check(MC.doorState("main") ~= "closed", "walking up to the door from inside opens it (you can't get trapped)")
	H.task.wait(4)
	at(a, Vector3.new(300, 4, -700))
	H.task.wait(MC.doorOpenSeconds + 5)
	trigger(MC.mainPanel, a)
	H.check(MC.doorState("main") == "opening" or MC.doorState("main") == "open", "the inside panel opens it too")
	at(a, Vector3.new(420, 4, -760))
	H.task.wait(1.5)
	H.check(MC.doorState("back") ~= "closed", "the back exit opens from inside as you walk up")
	-- the crew shows up on your screen near the base
	at(a, Vector3.new(300, 4, -720))
	H.task.wait(1.5)
	H.check(cc.MountainLife.active and #cc.MountainLife.actors == 8, "the crew is drawn while you're near (" .. #cc.MountainLife.actors .. ")")
	at(a, Vector3.new(0, 4, 0))
	H.task.wait(1.5)
	H.check(not cc.MountainLife.active, "...and removed when you leave")

	H.section("Opening a target")
	local bank = HS.sites.bank
	H.check(not bank.open, "targets are closed until an opportunity comes up")
	at(a, bank.entrance)
	T.act(a, "hsState")
	F.heistStart(a, "bank")
	H.check(HS.robbers[a] == nil, "you can't rob a closed target")
	local mk = #H.remoteLog
	F.heistOpen("bank")
	H.check(bank.open and splashed(a, "ROBBERY OPPORTUNITY", mk), "BANK ROBBERY AVAILABLE (shown to players who found the base)")
	H.check(not splashed(bob, "ROBBERY OPPORTUNITY", mk), "...not to players who haven't (yet)")
	local opened = 0
	for _, st in pairs(HS.sites) do if st.open then opened += 1 end end
	H.check(opened <= C.HEIST.maxOpen, "only a couple of targets are open at once")
	at(bob, bank.entrance)
	F.heistStart(bob, "bank")
	H.check(HS.robbers[bob] == nil, "you have to find the hideout before you can take jobs")
	at(a, bank.entrance + Vector3.new(80, 0, 0))
	F.heistStart(a, "bank")
	H.check(HS.robbers[a] == nil, "you have to be at the entrance")

	H.section("The bank job")
	at(a, bank.entrance)
	F.heistStart(a, "bank")
	local r = HS.robbers[a]
	H.check(r ~= nil and r.bag == 0, "robbery started: Alice gets an empty bag")
	H.check(a.Character:FindFirstChild("RobberyBag") ~= nil, "the bag is visible on her character")
	H.task.wait(2.5)
	H.check(cc.HeistUI.hud.Visible and cc.HeistUI.bagLabel.Text:find("BAG"), "the bag HUD: " .. cc.HeistUI.bagLabel.Text)
	F.heistGrab(a, "bank", 1)
	H.check(r.bag == 0, "the vault is locked until security is down")
	-- the security panel: a real puzzle, checked on the server
	local panel = bank.panels[1]
	at(a, panel.pos + Vector3.new(2, 0, 0))
	mk = #H.remoteLog
	F.heistPanel(a, "bank", 1)
	local pz = lastMenu(a, "heistPuzzle", mk)
	H.check(pz and pz.kind == "keypad" and #pz.seq == 5, "a keypad sequence to memorize (" .. (pz and #pz.seq or 0) .. " digits)")
	H.task.wait(0.5)
	H.check(cc.HeistUI.puzzle.Visible, "the puzzle window opens on Alice's screen")
	T.act(a, "hsSolve", {"0", "0", "0", "0", "0"})
	H.check(r.heist.stage == "security" and r.heist.heat > 0, "a wrong code resets the panel and makes a little noise")
	F.heistPanel(a, "bank", 1)
	pz = lastMenu(a, "heistPuzzle")
	H.task.wait(3)   -- (the code is shown for a moment, then hidden)
	-- type it on the client's keypad
	for _, sym in ipairs(pz.seq) do
		local b
		for _, x in ipairs(cc.HeistUI.pad:GetChildren()) do if x.ClassName == "TextButton" and x.Text == sym then b = x end end
		click(b)
	end
	H.task.wait(0.5)
	H.check(r.heist.stage == "vault", "typing the code on the keypad cracks it: the vault opens")
	H.check(not cc.HeistUI.puzzle.Visible, "the puzzle window closes")
	-- the client can't fake a reward, a loot amount or a stage
	T.act(a, "hsSolve", {"lots", "of", "money"})
	T.act(a, "hsSolve", 999999)
	T.act(a, "hsTurnIn", 1e12)
	T.act(a, "hsGrab", "bank", 1, 1e9)
	H.check(r.bag == 0 and d.cash < 1e9 + 1e7, "made-up requests (amounts, stages, rewards) do nothing")
	-- grabbing loot
	local stn = bank.stations[1]
	at(a, stn.pos + Vector3.new(0, 0, -3))
	F.heistGrab(a, "bank", 1)
	H.check(r.bag == C.HEIST_SITE.bank.grab, "grab: +$" .. C.fmt(r.bag * r.mult) .. " into the bag (not into cash)")
	local cashBefore = d.cash
	F.heistGrab(a, "bank", 4)
	H.check(r.bag == C.HEIST_SITE.bank.grab, "you have to be at the station you grab from")
	for i = 1, 6 do
		at(a, bank.stations[i].pos + Vector3.new(0, 0, -3))
		for _ = 1, 3 do F.heistGrab(a, "bank", i) end
	end
	H.check(r.bag == r.cap, "the bag fills up to its capacity ($" .. C.fmt(r.cap * r.mult) .. ") and no further")
	H.check(math.abs(d.cash - cashBefore) < F.incomePerSec(d) * 30 + 1, "none of it is money yet")
	H.check(r.heist.stage == "alarm" and splashed(a, "ALARM TRIGGERED"), "BANK ALARM TRIGGERED")
	local arrestPP = a.Character.HumanoidRootPart:FindFirstChild("ArrestPrompt")
	H.check(arrestPP ~= nil, "a robber with loot can be arrested")
	H.task.wait(1)
	H.check(arrestPP.Enabled == false, "...but Alice (not police) doesn't even see the [Arrest] prompt on screen")

	H.section("The escape")
	at(a, bank.entrance + Vector3.new(-120, 0, 0))
	H.task.wait(1.5)
	H.check(r.escaped and splashed(a, "RETURN TO MOUNTAIN HQ"), "RETURN TO MOUNTAIN HQ")
	H.task.wait(2.5)
	H.check(cc.HeistUI.objLabel.Text:find("RETURN TO MOUNTAIN HQ"), "the HUD says so too")
	-- a turn-in anywhere else does nothing
	F.heistTurnIn(a)
	H.check(r.bag == r.cap, "loot can only be turned in inside the mountain")
	local before = d.cash
	local carried = r.bag * r.mult
	at(a, Vector3.new(300, 4, -720))
	H.task.wait(1.5)
	local gained = d.cash - before
	H.check(HS.robbers[a] == nil and gained >= carried and gained < carried * 1.2 + F.incomePerSec(d) * 3, "inside the mountain the Fence pays $" .. C.fmt(gained) .. " for the loot")
	H.check(d.heist.done == 1 and d.heist.earned >= carried, "robbery stats: 1 job, $" .. C.fmt(d.heist.earned))
	H.check(a.Character:FindFirstChild("RobberyBag") == nil, "the bag is gone after the job")
	local cash2 = d.cash
	F.heistTurnIn(a)
	trigger(MC.stations.fence.prompt, a)
	H.check(math.abs(d.cash - cash2) < F.incomePerSec(d) * 2 + 1, "turning in twice pays nothing more")
	local post = false
	for _, p in ipairs(C.FEED) do if tostring(p.text):find("Corner Bank") then post = true end end
	H.check(post, "CityBuzz reports the (real) robbery")
	H.task.wait(1)
	H.check(not cc.HeistUI.hud.Visible, "the HUD goes away")
	F.heistStart(a, "bank")
	H.check(HS.robbers[a] == nil, "the same target is on cooldown for you")

	H.section("Police")
	T.act(bob, "hsPolice", true)
	H.check(HS.police[bob] ~= nil and bob:GetAttribute("Police"), "Bob goes on police duty")
	db.heist.discovered = true
	F.heistOpen("jewelry")
	local jw = HS.sites.jewelry
	at(a, jw.entrance)
	F.heistStart(a, "jewelry")
	r = HS.robbers[a]
	H.check(r ~= nil, "Alice starts the jewelry job")
	at(bob, jw.entrance)
	F.heistStart(bob, "jewelry")
	H.check(HS.robbers[bob] == nil, "police can't join a robbery")
	T.act(a, "hsPolice", true)
	H.check(HS.police[a] == nil, "a robber can't go on duty mid-job")
	-- solve the symbols panel straight on the server
	at(a, jw.panels[1].pos)
	mk = #H.remoteLog
	F.heistPanel(a, "jewelry", 1)
	pz = lastMenu(a, "heistPuzzle", mk)
	T.act(a, "hsSolve", pz.seq)
	H.check(r.heist.stage == "vault", "symbols puzzle solved")
	mk = #H.remoteLog
	for i = 1, 5 do
		at(a, jw.stations[i].pos + Vector3.new(0, 0, -3))
		F.heistGrab(a, "jewelry", i)
		F.heistGrab(a, "jewelry", i)
	end
	H.check(r.heist.stage == "alarm", "alarm")
	local alert = lastMenu(bob, "heistAlert", mk)
	H.check(alert and alert.text:find("ROBBERY IN PROGRESS") and alert.radius > 0, "police get: " .. tostring(alert and alert.text))
	at(a, jw.entrance + Vector3.new(150, 0, 0))
	H.task.wait(17)
	alert = lastMenu(bob, "heistAlert")
	local exact = a.Character.HumanoidRootPart.Position
	H.check(alert and alert.text:find("Suspect") and (alert.pos - exact).Magnitude > 0.5, "updates are approximate: \"" .. tostring(alert and alert.text) .. "\"")
	-- a non-police player can't arrest
	local carl = T.join("Carl", 103)
	local dcarl = T.newGame(carl, 1, 1)
	dcarl.tut = 0
	at(carl, a.Character.HumanoidRootPart.Position + Vector3.new(3, 0, 0))
	trigger(a.Character.HumanoidRootPart:FindFirstChild("ArrestPrompt"), carl)
	H.check(HS.robbers[a] ~= nil, "only police can arrest")
	-- police too far away can't
	at(bob, a.Character.HumanoidRootPart.Position + Vector3.new(60, 0, 0))
	trigger(a.Character.HumanoidRootPart:FindFirstChild("ArrestPrompt"), bob)
	H.check(HS.robbers[a] ~= nil, "police have to be close")
	at(bob, a.Character.HumanoidRootPart.Position + Vector3.new(4, 0, 0))
	local aCash, bCash = d.cash, db.cash
	trigger(a.Character.HumanoidRootPart:FindFirstChild("ArrestPrompt"), bob)
	H.check(HS.robbers[a] == nil and splashed(a, "BUSTED"), "ARRESTED: the loot is gone")
	H.check(math.abs(d.cash - aCash) < F.incomePerSec(d) * 3 + 1, "Alice keeps all her own money (only the loot is lost)")
	H.check(db.cash > bCash and db.heist.arrests == 1, "Bob is paid by the city (+$" .. C.fmt(db.cash - bCash) .. ")")
	H.check((a.Character.HumanoidRootPart.Position - C.POLICE_STATION.pos).Magnitude < 30, "Alice waits in a cell")
	H.task.wait(C.HEIST.police.jail + 2)
	H.check((a.Character.HumanoidRootPart.Position - C.POLICE_STATION.pos).Magnitude > 20, "...and is let out")
	T.act(bob, "hsPolice", false)
	H.check(HS.police[bob] ~= nil, "switching back right away is on a short cooldown")

	H.section("Every way a job can fail")
	C.HEIST_ADMIN.reset()
	H.task.wait(0.5)
	-- leaving the server
	C.HEIST_ADMIN.giveBag(carl)
	dcarl.heist.discovered = true
	HS.robbers[carl].bag = 3000
	local s0 = dcarl.cash
	H.removePlayer(carl)
	H.task.wait(1)
	H.check(HS.robbers[carl] == nil, "disconnecting with loot: the loot is gone (it's never saved)")
	H.check(math.abs(dcarl.cash - s0) < 1e6, "(and nothing else of Carl's changed)")
	-- dying
	C.HEIST_ADMIN.giveBag(a)
	HS.robbers[a].bag = 2000
	local c1 = d.cash
	a.Character.Humanoid.Health = 0
	H.signalOf(a.Character.Humanoid, "Died"):Fire()
	H.task.wait(1)
	H.check(HS.robbers[a] == nil and math.abs(d.cash - c1) < F.incomePerSec(d) * 3 + 1, "going down: loot lost, nothing else")
	a:LoadCharacter()
	H.task.wait(1)
	-- abandoning
	C.HEIST_ADMIN.giveBag(a)
	HS.robbers[a].bag = 2000
	T.act(a, "hsAbandon")
	H.check(HS.robbers[a] == nil and d.cash >= 0, "abandoning: loot lost")
	-- too slow
	C.HEIST_ADMIN.giveBag(a)
	r = HS.robbers[a]
	r.bag, r.alarmAt = 2000, H.now() - C.HEIST.hotSeconds - 5
	H.task.wait(2)
	H.check(HS.robbers[a] == nil, "holding loot too long after the alarm: it gets too hot and is lost")
	-- the window closes before anything was taken
	C.HEIST_ADMIN.reset()
	F.heistOpen("electronics")
	local el = HS.sites.electronics
	at(a, el.entrance)
	F.heistStart(a, "electronics")
	H.check(HS.robbers[a] ~= nil, "(started the electronics job)")
	el.closesAt = H.now() - 70
	H.task.wait(2)
	H.check(HS.robbers[a] == nil and el.heist == nil, "the window closing before any loot: the job falls apart")
	H.check(d.cash >= 0 and d.heist.failed >= 1, "never negative cash; failures are counted (" .. d.heist.failed .. ")")

	H.section("Crews")
	C.HEIST_ADMIN.reset()
	F.heistOpen("museum")
	local mu = HS.sites.museum
	at(a, mu.entrance)
	F.heistStart(a, "museum")
	at(a, mu.panels[1].pos)
	F.heistPanel(a, "museum", 1)
	H.check(lastMenu(a, "heistPuzzle") == nil or HS.robbers[a].heist.puzzles[a] == nil, "the museum needs 2+ people before the panels work")
	T.act(bob, "hsPolice", false)
	H.task.wait(C.HEIST.police.switchCooldown + 1)
	T.act(bob, "hsPolice", false)
	T.act(a, "hsInvite", bob.UserId)
	at(bob, mu.entrance)
	F.heistStart(bob, "museum")
	local Hm = HS.robbers[a].heist
	H.check(#Hm.crew == 2 and HS.robbers[bob].heist == Hm, "Bob joins Alice's crew")
	for i, who in ipairs({a, bob}) do
		at(who, mu.panels[i].pos)
		mk = #H.remoteLog
		F.heistPanel(who, "museum", i)
		local p2 = lastMenu(who, "heistPuzzle", mk)
		T.act(who, "hsSolve", p2.seq)
	end
	H.check(Hm.stage == "vault", "two panels, two people: the vault opens")
	for i = 1, 6 do
		for _, who in ipairs({a, bob}) do
			at(who, mu.stations[i].pos + Vector3.new(0, 0, -3))
			for _ = 1, 3 do F.heistGrab(who, "museum", i) end
		end
	end
	local total = HS.robbers[a].bag + HS.robbers[bob].bag
	H.check(total <= C.HEIST_SITE.museum.pool, "the crew can't take more than the target holds (" .. total .. " ≤ " .. C.HEIST_SITE.museum.pool .. ")")
	C.HEIST_ADMIN.reset()

	H.section("4 players")
	local dan = T.join("Dan", 104)
	local dd = T.newGame(dan, 1, 1)
	local eve = T.join("Eve", 105)
	local de = T.newGame(eve, 1, 1)
	for _, x in ipairs({dd, de}) do x.tut, x.rep, x.heist.discovered = 0, 1500, true end
	F.heistOpen("cargo")
	local cy = HS.sites.cargo
	for _, who in ipairs({a, bob, dan, eve}) do
		at(who, cy.entrance)
		F.heistStart(who, "cargo")
	end
	local Hc = HS.robbers[a] and HS.robbers[a].heist
	H.check(Hc and #Hc.crew == 4, "4 players on one job (a full server)")
	C.HEIST_ADMIN.reset()
	-- a target with a smaller crew limit turns the extra person away
	C.HEIST_SITE.warehouse.maxP = 3
	F.heistOpen("warehouse")
	local wh = HS.sites.warehouse
	for _, who in ipairs({a, bob, dan, eve}) do
		at(who, wh.entrance)
		F.heistStart(who, "warehouse")
	end
	H.check(#wh.heist.crew == 3 and HS.robbers[eve] == nil, "the crew limit holds (3 of 4 got in)")
	C.HEIST_SITE.warehouse.maxP = 4
	C.HEIST_ADMIN.reset()

	H.section("Gear and the base")
	d.cash = 1e9
	at(a, Vector3.new(0, 4, 0))
	H.task.wait(1.5)
	T.act(a, "hsBag", 2)
	H.check(d.heist.bag == 1, "bags are bought inside the hideout")
	at(a, Vector3.new(300, 4, -720))
	H.task.wait(1.5)
	T.act(a, "hsBag", 3)
	H.check(d.heist.bag == 1, "one step at a time")
	T.act(a, "hsBag", 2)
	H.check(d.heist.bag == 2, "Reinforced Bag bought")
	trigger(MC.stations.garage.prompt, a)
	H.check(F.activeCar(a) == nil, "the Escape Garage needs the base's Garage Level")
	T.act(a, "hsBase", 2)
	H.check(d.heist.base == 2, "base upgraded to the Garage Level")
	trigger(MC.stations.garage.prompt, a)
	local gc = F.activeCar(a)
	H.check(gc and MC.inChamber(gc.root.Position), "the Escape Garage brings your car out inside the base")
	F.despawnCar(a)

	H.section("The Heists app")
	cc.closeModals()
	mk = #H.remoteLog
	cc.openModal("heists")
	H.task.wait(1.5)
	local asks = 0
	for i = mk + 1, #H.remoteLog do if H.remoteLog[i].name == "Action" and H.remoteLog[i].dir == "c2s" and H.remoteLog[i].args[1] == "hsApp" then asks += 1 end end
	H.check(cc.modals.heists.frame.Visible and asks == 1, "the app opens with one request")
	local open = 0
	for _, x in ipairs(cc.modals.heists.body:GetDescendants()) do if x.ClassName == "TextLabel" and tostring(x.Text):find("CORNER BANK") then open += 1 end end
	H.check(open == 1, "the Jobs tab lists the targets")
	cc.HeistUI.tab = "gear"
	cc.HeistUI.render()
	H.check(cc.modals.heists.body:FindFirstChildWhichIsA("TextButton") ~= nil, "the Gear tab renders")
	cc.closeModals()
	cc.openModal("heists")
	H.task.wait(1)
	H.check(cc.modals.heists.frame.Visible, "it reopens cleanly")
	cc.closeModals()

	H.section("Saving")
	F.save(a)
	H.task.wait(0.5)
	local saved = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(saved and saved.SchemaVersion == C.VERSION.SCHEMA_VERSION and saved.heist and saved.heist.done == 1 and saved.heist.bag == 2 and saved.heist.discovered, "the heist record is saved (jobs, bag, base, discovered)")
	H.check(saved.heist.loot == nil and saved.bag == nil, "loot is never saved")
	H.check(type(saved.deeds) == "table" and type(saved.levels) == "table", "business and property data untouched")

	T.assertClean("mountain + heists")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
