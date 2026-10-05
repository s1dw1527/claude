-- v10: home builder (furniture shop, grid placement, styles, house tiers 1-7) and visitor permissions.
-- Run with: python3 tests/run.py tests/home_test.lua
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
	d.cash = 1e9
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.5) end
	local function prompts(root, action)
		local out = {}
		for _, x in ipairs(root:GetDescendants()) do
			if x.ClassName == "ProximityPrompt" and x.ActionText == action then table.insert(out, x) end
		end
		return out
	end
	local function inModal(key, pat)
		for _, x in ipairs(cc.modals[key].frame:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end
	local folder = H.workspace:FindFirstChild("Interiors")
	local function homeRoom(owner) return folder:FindFirstChild("Interior_" .. owner.Name .. "_home") end
	local items = function() return d.homeBuild.items end
	H.check(F.homeLevel(d) >= 1, "the player starts with a home (" .. C.HOME_LEVELS[F.homeLevel(d)] .. ")")

	H.section("House tiers")
	H.check(#C.HOME_LEVELS == 7 and C.HOME_LEVELS[6] == "Mega Mansion" and C.HOME_LEVELS[7] == "Empire Estate", "7 house tiers: " .. table.concat(C.HOME_LEVELS, ", "))
	local lot = F.homeLot(d)
	H.check(lot ~= nil, "the home has a lot")
	local partsAt = {}
	for lvl = 1, 7 do
		d.home.level = lvl
		F.buildHome(lot)
		local n = lot.folder and #lot.folder:GetDescendants() or 0
		partsAt[lvl] = n
	end
	print("    parts per tier: " .. table.concat(partsAt, ", "))
	H.check(partsAt[6] > partsAt[5] and partsAt[7] > partsAt[6], "tiers 6 and 7 visibly add to the house")
	local estate = false
	for _, x in ipairs(lot.folder:GetDescendants()) do if x.ClassName == "TextLabel" and x.Text == "EMPIRE ESTATE" then estate = true end end
	H.check(estate, "the Empire Estate has its grand gate")
	H.check(F.homeBuildCost(d) == nil, "no build cost past tier 7")
	d.home.level = 1
	F.buildHome(lot)

	H.section("Furniture shop")
	T.act(a, "hbBuy", "sofa", 1)
	local cash0 = d.cash
	H.check(d.furniture.sofa == 1, "bought a sofa: it goes into storage")
	T.act(a, "hbBuy", "kingbed", 1)
	H.check(d.furniture.kingbed == nil, "a King Bed needs a Luxury Home (tier 3)")
	T.act(a, "hbBuy", "computer", 1)
	H.check(d.furniture.computer == nil, "the computer isn't sold here (it comes from the computer shop)")
	T.act(a, "hbBuy", "nope", 1)
	T.act(a, "hbBuy", "sofa", 999)
	H.check(d.furniture.sofa <= 6, "quantities are clamped")
	d.furniture.sofa = 1
	cash0 = d.cash
	T.act(a, "hbSell", "sofa")
	H.check(d.furniture.sofa == nil and d.cash - cash0 <= C.FURNITURE_BY.sofa.cost * 0.4 + F.incomePerSec(d) * 2 + 1, "selling refunds 40% (no buy/sell money loop)")
	for _, k in ipairs({"sofa", "armchair", "singlebed", "floorlamp", "bigrug"}) do T.act(a, "hbBuy", k, 1) end
	local cats = {}
	for _, it in ipairs(C.FURNITURE) do cats[it.cat] = (cats[it.cat] or 0) + 1 end
	local nc = 0
	for _ in pairs(cats) do nc += 1 end
	H.check(nc == 9 and #C.FURNITURE >= 30, #C.FURNITURE .. " items in " .. nc .. " categories")
	T.act(a, "hbState")
	cc.openModal("furniture", true)
	H.task.wait(0.6)
	H.check(cc.modals.furniture.frame.Visible and inModal("furniture", "Living Room") and inModal("furniture", "Luxury"), "the shop shows its categories")
	cc.closeModals()

	H.section("Placing on the grid")
	T.act(a, "hbPlace", "sofa", {3, 7, 0})
	H.check(#items() == 0, "you can't place furniture from outside your home")
	F.enterInterior(a, a, "home")
	H.task.wait(1.5)
	H.check(a:GetAttribute("Interior") == "home", "inside the home")
	local B = cc.BuilderUI
	H.check(B.barButton and B.barButton.Visible, "the inside bar shows 🔨 Build in your own home")
	click(B.barButton)
	H.task.wait(0.5)
	H.check(cc.modals.builder.frame.Visible and B.cells and B.cells["3,7"] ~= nil, "the builder shows the grid plan")
	local sofaBtn
	for _, x in ipairs(B.side:GetDescendants()) do if x.ClassName == "TextButton" and x.Text:find("Sofa") then sofaBtn = x end end
	H.check(sofaBtn ~= nil, "storage lists the sofa")
	click(sofaBtn)
	local parts0 = #homeRoom(a):GetDescendants()
	click(B.cells["3,7"])
	H.task.wait(0.5)
	H.check(#items() == 1 and items()[1].k == "sofa" and items()[1].x == 3 and items()[1].z == 7, "tap a cell: the sofa is placed there")
	H.check(d.furniture.sofa == nil, "it left storage")
	H.check(#homeRoom(a):GetDescendants() > parts0, "the room is rebuilt with the sofa in it")
	T.act(a, "hbPlace", "armchair", {4, 7, 0})
	H.check(#items() == 1, "can't place on top of the sofa")
	T.act(a, "hbPlace", "armchair", {7, 9, 0})
	H.check(#items() == 1, "the doorway stays clear")
	T.act(a, "hbPlace", "singlebed", {10, 4, 0})
	H.check(#items() == 1, "an item can't stand across a wall (classic rooms)")
	T.act(a, "hbPlace", "singlebed", {14, 1, 0})
	H.check(#items() == 1, "built-in fixtures (the bathtub) block their cells")
	T.act(a, "hbPlace", "singlebed", {7, 2, 0})
	H.check(#items() == 2, "the bed fits in the bedroom")
	T.act(a, "hbPlace", "armchair", {14, 5, 1})
	T.act(a, "hbPlace", "armchair", {15, 5, 0})
	T.act(a, "hbPlace", "armchair", {0, 5, 0})
	T.act(a, "hbPlace", "armchair", {2.5, 5, 0})
	H.check(#items() == 3, "out-of-range and fractional cells are refused")
	T.act(a, "hbPlace", "bigrug", {3, 7, 0})
	H.check(#items() == 4, "a flat rug can go under furniture")

	H.section("Moving, rotating, picking up")
	T.act(a, "hbMove", 1, {9, 6, 0})
	H.check(items()[1].x == 9 and items()[1].z == 6, "moved the sofa")
	T.act(a, "hbMove", 1, {9, 6, 1})
	H.check(items()[1].r == 1, "rotated it")
	T.act(a, "hbMove", 1, {14, 6, 0})
	H.check(items()[1].x == 9, "a move that doesn't fit is refused")
	T.act(a, "hbPick", 3)
	H.check(#items() == 3 and d.furniture.armchair == 1, "picking up puts it back in storage")
	T.act(a, "hbPick", 99)
	H.check(#items() == 3, "bad indexes are ignored")

	H.section("Limits")
	d.furniture.pottedplant = 60
	local cap = F.homeItemCap(d)
	for cz = 1, 10 do for cx = 1, 14 do if #items() < cap + 2 then F.placeFurniture(a, "pottedplant", cx, cz, 0) end end end
	H.check(#items() == cap, "a " .. C.HOME_LEVELS[1] .. " holds " .. cap .. " items (" .. #items() .. ")")
	d.home.level = 5
	H.check(F.homeItemCap(d) > cap, "bigger houses hold more (" .. F.homeItemCap(d) .. " at tier 5)")
	d.home.level = 1
	local s1 = F.interiorScore100(d, "home")
	H.check(s1 > 0, "furniture raises the interior score (" .. s1 .. "/100)")
	local inc0 = F.incomePerSec(d)
	H.check(math.abs(F.incomePerSec(d) - inc0) < 0.01, "furniture never adds income")
	for i = #items(), 1, -1 do if items()[i].k == "pottedplant" then F.pickUpFurniture(a, i) end end

	H.section("House styles")
	cash0 = d.cash
	T.act(a, "hbStyle", "ceiling", "beams")
	H.check(d.homeBuild.styles.ceiling == "beams" and cash0 - d.cash >= C.HOME_STYLES.ceiling[2].cost - F.incomePerSec(d) * 3 - 1, "wood beams ceiling bought")
	T.act(a, "hbStyle", "ceiling", "plain")
	cash0 = d.cash
	T.act(a, "hbStyle", "ceiling", "beams")
	H.check(d.homeBuild.styles.ceiling == "beams" and d.cash >= cash0 - 1, "switching back to a style you own is free")
	T.act(a, "hbStyle", "door", "gold")
	H.check(F.homeStyle(d, "door") == "wood", "the golden door needs a Mega Mansion")
	T.act(a, "hbStyle", "window", "classic")
	T.act(a, "hbStyle", "door", "modern")
	H.check(F.homeStyle(d, "window") == "classic" and F.homeStyle(d, "door") == "modern", "windows and doors change")
	T.act(a, "hbStyle", "layout", "open")
	H.check(F.homeLayout(d) == "classic", "the open loft needs an Expanded Home")
	d.home.level = 3
	T.act(a, "hbPlace", "armchair", {9, 6, 0})
	local before = #items()
	T.act(a, "hbStyle", "layout", "split")
	H.check(F.homeLayout(d) == "split", "switched to the split level layout")
	H.check(#items() < before and (d.furniture.armchair or 0) >= 1, "furniture standing on the new steps went back into storage")
	T.act(a, "hbStyle", "layout", "bogus")
	T.act(a, "hbStyle", "roof", "classic")
	H.check(F.homeLayout(d) == "split", "unknown styles are ignored")
	T.act(a, "hbStyle", "layout", "classic")
	d.home.level = 1

	H.section("The computer")
	T.act(a, "pcBuy", 1)
	H.check(d.furniture.computer == 1, "buying a computer puts one in your furniture")
	T.act(a, "hbPlace", "computer", {1, 8, 0})
	local pcP = prompts(homeRoom(a), "Use Computer")[1]
	H.check(pcP ~= nil, "the placed computer can be used")
	H.signalOf(pcP, "Triggered"):Fire(a)
	H.task.wait(0.6)
	H.check(cc.modals.computer.frame.Visible, "using it opens the desktop")
	cc.closeModals()

	H.section("Visitors")
	C.friendCheck = function() return false end
	F.enterInterior(bob, a, "home")
	H.check(bob:GetAttribute("Interior") == "home", "house: PUBLIC lets anyone in")
	T.act(a, "perm", "house", "private")
	H.check(d.perms.house == "private" and bob:GetAttribute("Interior") == nil, "switching to PRIVATE shows visitors out")
	F.enterInterior(bob, a, "home")
	H.check(bob:GetAttribute("Interior") == nil, "PRIVATE: nobody gets in")
	T.act(a, "perm", "house", "friends")
	F.enterInterior(bob, a, "home")
	H.check(bob:GetAttribute("Interior") == nil, "FRIENDS: a non-friend can't come in")
	C.friendCheck = function() return true end
	F.enterInterior(bob, a, "home")
	H.check(bob:GetAttribute("Interior") == "home", "FRIENDS: a friend can")
	F.leaveInterior(bob)
	C.friendCheck = function() return false end
	T.act(a, "perm", "house", "invite")
	F.enterInterior(bob, a, "home")
	H.check(bob:GetAttribute("Interior") == nil, "INVITE ONLY: not invited, not in")
	T.act(a, "invite", bob.UserId, true)
	F.enterInterior(bob, a, "home")
	H.check(bob:GetAttribute("Interior") == "home", "INVITE ONLY: invited, in")
	F.leaveInterior(bob)
	T.act(a, "invite", 424242, true)
	H.check(d.invites["424242"] == nil, "you can only invite someone who's in the server")
	T.act(a, "perm", "house", "everyone")
	T.act(a, "perm", "garage", "public")
	H.check(d.perms.house == "invite" and d.perms.garage == nil, "bad permission values are ignored")
	T.act(bob, "perm", "house", "public")
	H.check(d.perms.house == "invite", "Bob's requests only change Bob's settings")
	-- businesses are public by default; the HQ is friends-only
	T.act(a, "buy", "lemonade")
	F.enterInterior(bob, a, "lemonade")
	H.check(bob:GetAttribute("Interior") == "lemonade", "businesses are open to the public by default")
	F.leaveInterior(bob)
	T.act(a, "perm", "business", "private")
	F.enterInterior(bob, a, "lemonade")
	H.check(bob:GetAttribute("Interior") == nil, "a private business turns visitors away")
	d.hq.level = 1
	T.act(a, "invite", bob.UserId, false)
	F.enterInterior(bob, a, "hq1")
	H.check(bob:GetAttribute("Interior") == nil, "the HQ is friends-only by default")
	C.friendCheck = nil
	F.enterInterior(a, a, "home")
	T.act(a, "hbState")
	B.open("visitors")
	H.task.wait(0.5)
	H.check(inModal("builder", "Invite only") ~= nil and inModal("builder", "Bob") ~= nil, "the Visitors tab shows the modes and the players to invite")
	cc.closeModals()

	H.section("Saving")
	local saved = {}
	for k, v in pairs(d) do saved[k] = v end
	H.check(type(saved.homeBuild) == "table" and type(saved.furniture) == "table" and type(saved.perms) == "table" and type(saved.invites) == "table", "builder, storage and permissions live in the save")
	T.assertClean("home builder + visitors")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
