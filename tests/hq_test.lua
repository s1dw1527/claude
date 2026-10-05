-- v10: HQ floors, the elevator, the HQ crew, the General Manager's contracts and the computer.
-- Run with: python3 tests/run.py tests/hq_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local function calm()
		local t = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut, db.tut = 0, 0
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function inModal(key, pat)
		for _, x in ipairs(cc.modals[key].frame:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end
	local function prompts(root, action)
		local out = {}
		for _, x in ipairs(root:GetDescendants()) do
			if x.ClassName == "ProximityPrompt" and x.ActionText == action then table.insert(out, x) end
		end
		return out
	end
	local function trigger(pp, who) H.signalOf(pp, "Triggered"):Fire(who) H.task.wait(0.6) end
	local folder = H.workspace:FindFirstChild("Interiors")
	local function room(owner, key) return folder:FindFirstChild("Interior_" .. owner.Name .. "_" .. key) end

	H.section("Buying the HQ")
	d.cash, d.rep = 1e12, 0
	T.act(a, "hqBuy")
	H.check(F.hqLevel(d) == 0, "the HQ is locked below " .. C.REP_TIERS[C.HQ_TIER].name)
	d.rep = C.REP_TIERS[C.HQ_TIER].rep
	F.refreshTower(a, true)
	T.act(a, "hqInfo")
	H.task.wait(0.5)
	H.check(cc.modals.hq.frame.Visible and inModal("hq", "Reception") ~= nil, "the HQ card lists the floors")
	local build = inModal("hq", "^Build %$")
	H.check(build ~= nil, "the next floor has a Build button (" .. (build and build.Text or "?") .. ")")
	local cash0 = d.cash
	click(build)
	H.check(F.hqLevel(d) == 0 and cc.confirmBox.Visible, "building asks for confirmation first")
	local yes
	for _, x in ipairs(cc.confirmBox:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "Build" then yes = x end end
	click(yes)
	H.task.wait(0.5)
	H.check(F.hqLevel(d) == 1 and cash0 - d.cash >= C.HQ_FLOORS[1].cost - F.incomePerSec(d) * 3 - 1, "floor 1 (Reception) built for $" .. C.fmt(C.HQ_FLOORS[1].cost))

	H.section("Walking in")
	local door
	for _, pp in ipairs(prompts(d.plot.folder, "Enter HQ")) do door = pp end
	H.check(door ~= nil, "the Empire Tower has an Enter HQ door")
	trigger(door, a)
	H.check(a:GetAttribute("Interior") == "hq1" and a:GetAttribute("InteriorOwner") == a.UserId, "the door takes you into the HQ lobby")
	local r1 = room(a, "hq1")
	H.check(r1 ~= nil and #r1:GetDescendants() > 30, "the reception floor is built (" .. (r1 and #r1:GetDescendants() or 0) .. " parts)")
	H.check(r1 and tostring(r1:GetAttribute("Crew")):find("receptionist"), "the server lists a receptionist")
	H.task.wait(2)
	H.check(cc.InteriorLife.stats.staff >= 1, "the client draws the HQ crew (" .. cc.InteriorLife.stats.staff .. ")")
	local logo = false
	for _, x in ipairs(r1:GetDescendants()) do if x.ClassName == "TextLabel" and tostring(x.Text):find("ALICE EMPIRE") then logo = true end end
	H.check(logo, "the empire logo is on the lobby wall")

	H.section("The elevator")
	local el = prompts(r1, "Elevator")[1]
	H.check(el ~= nil, "every floor has an elevator panel")
	trigger(el, a)
	H.check(cc.modals.elevator.frame.Visible and inModal("elevator", "Reception") ~= nil and inModal("elevator", "Management") == nil, "the elevator only lists built floors")
	T.act(a, "hqBuy")
	H.check(F.hqLevel(d) == 2, "floor 2 (Management) built")
	T.act(a, "hqFloor", 2, a.UserId)
	H.task.wait(1)
	H.check(a:GetAttribute("Interior") == "hq2", "the elevator takes you up to Management")
	H.task.wait(2)
	H.check(cc.InteriorLife.stats.staff >= 4, "desk workers and the manager are at work (" .. cc.InteriorLife.stats.staff .. ")")
	T.act(a, "hqFloor", 5, a.UserId)
	H.check(a:GetAttribute("Interior") == "hq2", "you can't ride to a floor that isn't built")
	T.act(bob, "hqFloor", 1, a.UserId)
	H.check(bob:GetAttribute("Interior") == nil, "someone outside the HQ can't use the elevator remote to get in")
	T.act(bob, "hqFloor", 1, 999999)
	H.check(bob:GetAttribute("Interior") == nil, "bad owner ids are ignored")

	H.section("General Manager")
	T.act(a, "mgrSign")
	H.check(d.mgr.left == 0, "no contract without a hired manager")
	d.staff.manager = {name = "Morgan", service = 3, speed = 3, exp = 1}
	local cost = F.contractCost(d)
	cash0 = d.cash
	T.act(a, "mgrSign")
	H.check(d.mgr.left > 14 * 60 and d.mgr.left <= 15 * 60 and cash0 - d.cash >= cost - F.incomePerSec(d) * 3 - 1, "a level 1 manager signs a 15-minute contract ($" .. C.fmt(cost) .. ")")
	T.act(a, "mgrSign")
	H.check(d.mgr.left <= 15 * 60, "can't stack contracts while one is running")
	T.act(a, "mgrInfo")
	H.task.wait(0.5)
	H.check(cc.modals.manager.frame.Visible and inModal("manager", "Under contract") ~= nil, "the manager panel shows the contract")
	T.act(a, "buy", "lemonade")
	local key
	for _ = 1, 20 do
		F.makeProblem(a, d, os.clock())
		key = next(d.problems)
		if key and not C.MANAGER.advanced[d.problems[key].type] then break end
		d.problems = {}
	end
	H.check(key ~= nil and d.problems[key].manager == true, "a new problem is picked up by the manager")
	H.task.wait(1.2)
	H.check(T.state(a).problems[1] and T.state(a).problems[1].managing == true, "the HUD knows the manager is on it")
	H.task.wait(30)
	H.check(d.problems[key] ~= nil, "repairs take time (still working after 30 s)")
	H.task.wait(65)
	H.check(d.problems[key] == nil and d.mgr.handled >= 1, "fixed after ~90 s (level 1), paid at the normal price")
	-- advanced problems need a level 5 manager
	d.problems.lemonade = {type = 3, repair = 100, replace = 400, state = "new"}
	F.managerOnProblem(a, d, "lemonade")
	H.check(d.problems.lemonade.manager == nil, "a level 1 manager leaves a " .. C.PROBLEMS[3].text .. " to you")
	d.staff.manager.exp = 5
	F.managerOnProblem(a, d, "lemonade")
	H.check(d.problems.lemonade.manager == true, "a level 5 manager handles it")
	d.problems.lemonade = nil
	H.check(C.MANAGER.minutes[5] == 60 and C.MANAGER.repairSeconds[5] < C.MANAGER.repairSeconds[1] and C.MANAGER.parallel[3] > C.MANAGER.parallel[1], "better managers: longer contracts, faster, more at once")
	-- low supplies: the manager restocks
	local st = F.stockOf(d, "lemonade")
	st[1], st[2], st[3] = 10, 10, 10
	H.task.wait(32)
	H.check(st[1] > 90, "low supplies get restocked by the manager")

	H.section("Contracts expire")
	local m0 = #H.remoteLog
	d.mgr.left, d.mgr.auto = 2, false
	H.task.wait(3)
	local expired = false
	for _, e in ipairs(T.remotesSince(m0, "Splash", a)) do if tostring(e.args[1]):find("MANAGER CONTRACT EXPIRED") then expired = true end end
	H.check(expired and d.mgr.left == 0, "\"MANAGER CONTRACT EXPIRED\"")
	F.makeProblem(a, d, os.clock())
	key = next(d.problems)
	H.check(key and not d.problems[key].manager, "after it expires, problems wait for you")
	d.problems = {}
	T.act(a, "mgrSign")
	T.act(a, "mgrAuto", true)
	H.check(d.mgr.auto == true, "auto-renew can be switched on")
	local renewed = 0
	for _ = 1, 3 do
		d.mgr.left = 1
		T.act(a, "mgrInfo")   -- (you're actively playing)
		H.task.wait(2.5)
		if d.mgr.left > 60 then renewed += 1 end
	end
	H.check(renewed == 2 and d.mgr.left == 0, "auto-renew works at most 2 times in a row (" .. renewed .. ")")

	H.section("Computer")
	T.act(a, "leaveInterior")
	m0 = #H.remoteLog
	T.act(a, "pcUse", "home")
	H.check(#T.remotesSince(m0, "Menu", a) == 0, "the computer only opens while you're at it")
	F.enterInterior(a, a, "home")
	H.task.wait(0.5)
	T.act(a, "pcUse", "home")
	H.check(not cc.modals.computer.frame.Visible, "no computer, no desktop")
	cash0 = d.cash
	T.act(a, "pcBuy", 1)
	H.check(F.computerTier(d) == 1 and d.furniture.computer == 1 and cash0 - d.cash >= C.COMPUTERS[1].cost, "bought a Basic Computer (it goes into your furniture)")
	T.act(a, "pcUse", "home")
	H.task.wait(0.5)
	H.check(cc.modals.computer.frame.Visible, "the desktop opens")
	local lockedInv = false
	for _, x in ipairs(cc.ComputerUI.side:GetDescendants()) do if x.ClassName == "TextButton" and x.Text:find("🔒 Inventory") then lockedInv = true end end
	H.check(lockedInv, "a Basic Computer shows Inventory as locked")
	st[1], st[2], st[3] = 10, 10, 10
	T.act(a, "pcRestock", "lemonade")
	H.check(st[1] < 50, "remote restock needs an Executive Workstation")
	T.act(a, "pcBuy", 3)
	H.check(F.computerTier(d) == 3, "upgraded to an Executive Workstation")
	T.act(a, "pcUse", "home")
	T.act(a, "pcRefresh", "businesses")
	H.task.wait(0.5)
	local restockBtn
	for _, x in ipairs(cc.ComputerUI.main:GetDescendants()) do if x.ClassName == "TextButton" and x.Text:find("^Restock") then restockBtn = x end end
	H.check(restockBtn ~= nil, "the Businesses app shows a Restock button")
	click(restockBtn)
	H.check(st[1] > 90, "remote restock from the computer works")
	local inc0 = F.incomePerSec(d)
	H.check(math.abs(F.incomePerSec(d) - inc0) < 0.01, "the computer never adds income")
	T.act(a, "leaveInterior")
	H.task.wait(0.5)
	H.check(not cc.modals.computer.frame.Visible, "walking away closes the computer")
	st[1], st[2], st[3] = 10, 10, 10
	T.act(a, "pcRestock", "lemonade")
	H.check(st[1] < 50, "after walking away, remote restock is refused")
	T.act(bob, "pcRestock", "lemonade")
	H.check(st[1] < 50, "another player can't restock through your computer")

	H.section("The rest of the tower")
	d.hq.level = 6
	for n = 3, 6 do
		F.enterInterior(a, a, "hq" .. n)
		H.task.wait(0.4)
		local r = room(a, "hq" .. n)
		H.check(a:GetAttribute("Interior") == "hq" .. n and r and #r:GetDescendants() > 10, C.HQ_FLOORS[n].name .. " floor builds")
		if n == 4 then
			local wall = prompts(r, "Inspect Empire")[1]
			trigger(wall, a)
			H.check(cc.modals.computer.frame.Visible, "the Empire Wall opens your empire overview")
		elseif n == 5 then
			cc.modals.computer.frame.Visible = false
			local pc = prompts(r, "Use Computer")[1]
			trigger(pc, a)
			H.check(cc.modals.computer.frame.Visible, "the office computer works")
		end
	end
	F.leaveInterior(a)

	H.section("Saving")
	H.check(type(d.hq) == "table" and type(d.mgr) == "table" and type(d.computer) == "table", "HQ, manager and computer are saved fields")
	T.assertClean("HQ, manager, computer")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
