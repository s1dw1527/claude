-- Interiors (enter, decorate, leave, visit) and visible house ratings.
-- Run with: python3 tests/run.py tests/interior_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local pg = a:FindFirstChild("PlayerGui")
	local function findLike(pat)
		for _, x in ipairs(pg:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end
	local function click(btn) H.signalOf(btn, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local t0 = H.now()
	while cc.storyCutscene() and H.now() - t0 < 120 do H.task.wait(0.5) end
	d.tut = 0
	d.cash, d.rep = 1e8, 2000
	local function prompts(root, action)
		local out = {}
		for _, x in ipairs(root:GetDescendants()) do
			if x.ClassName == "ProximityPrompt" and x.ActionText == action then table.insert(out, x) end
		end
		return out
	end
	local function trigger(pp, who) H.signalOf(pp, "Triggered"):Fire(who) H.task.wait(0.5) end
	local folder = H.workspace:FindFirstChild("Interiors")

	H.section("Every business has a door and a walk-in interior")
	T.act(a, "buy", "pizza")
	for _ = 1, 3 do T.act(a, "buy", "pizza") end
	H.task.wait(0.5)
	local enter = nil
	for _, pp in ipairs(prompts(folder, "Enter")) do if pp.ObjectText == "Pizza" then enter = pp end end
	H.check(enter ~= nil, "the Pizza place has an Enter door")
	trigger(enter, a)
	local root = a.Character.HumanoidRootPart
	H.check(a:GetAttribute("Interior") == "pizza" and root.Position.Y > 300, "entering takes you inside (y = " .. math.floor(root.Position.Y) .. ")")
	local room = folder:FindFirstChild("Interior_Alice_pizza")
	H.check(room ~= nil and #room:GetDescendants() > 30, "the room is built with its fixtures (" .. (room and #room:GetDescendants() or 0) .. " parts)")
	local glow = 0
	for _, p in ipairs(room:GetDescendants()) do if p.ClassName == "PointLight" then glow += 1 end end
	H.check(glow >= 4, "ovens and ceiling lights light the room (" .. glow .. " lights)")
	H.task.wait(1.2)
	H.check(cc.S.interior and cc.S.interior.mine and #cc.S.interior.spots >= 8, "the client knows it's in its own room, with " .. (cc.S.interior and #cc.S.interior.spots or 0) .. " decor spots")
	H.check(findLike("^🛋️ Decorate$") ~= nil and findLike("^🚪 Leave$") ~= nil, "the inside bar offers Decorate and Leave")

	H.section("Decorating")
	click(findLike("^🛋️ Decorate$"))
	H.check(findLike("DECORATE") ~= nil and findLike("Pick a numbered spot") ~= nil, "the decorate panel opens")
	local c0, s0 = d.cash, F.interiorScore(d, "pizza")
	T.act(a, "decor", "spot", 1, "booth")
	H.check(d.interiors.pizza.spots["1"] == "booth" and d.cash < c0 and F.interiorScore(d, "pizza") > s0, "placing a booth costs money and raises the score")
	T.act(a, "decor", "spot", 2, "brickoven")
	H.check(d.interiors.pizza.spots["2"] == "brickoven", "pizza places can have a Brick Oven (Pizza level 4 ≥ 3)")
	T.act(a, "decor", "spot", 3, "bed")
	H.check(d.interiors.pizza.spots["3"] == nil, "a bed isn't allowed in a pizza place")
	T.act(a, "decor", "spot", 3, "claw")
	H.check(d.interiors.pizza.spots["3"] == nil, "arcade items aren't allowed either")
	local wallSpot
	for i, sp in ipairs(cc.S.interior.spots) do if sp.place == "wall" then wallSpot = i end end
	T.act(a, "decor", "spot", 1, "tv")
	H.check(d.interiors.pizza.spots["1"] == "booth", "a wall item can't go on a floor spot")
	T.act(a, "decor", "spot", wallSpot, "pizzasign")
	H.check(d.interiors.pizza.spots[tostring(wallSpot)] == "pizzasign", "the pizza sign goes on a wall spot")
	T.act(a, "decor", "wall", nil, "brick")
	T.act(a, "decor", "floor", nil, "wood")
	T.act(a, "decor", "light", nil, "warm")
	H.check(d.interiors.pizza.wall == "brick" and d.interiors.pizza.floor == "wood" and d.interiors.pizza.light == "warm", "walls, floors and lighting change")
	local cashBefore = d.cash
	T.act(a, "decor", "spot", 1, "none")
	H.check(d.interiors.pizza.spots["1"] == nil and d.cash <= cashBefore + F.incomePerSec(d) * 2 + 1, "removing an item is free and refunds nothing (no buy/remove money loop)")
	H.check(F.interiorSatisfaction(d, "pizza") > 0 and F.interiorSatisfaction(d, "pizza") <= 10, "decor makes customers happier, capped at +10")
	local inc0 = F.incomePerSec(d)
	T.act(a, "decor", "spot", 4, "statue")
	H.check(math.abs(F.incomePerSec(d) - inc0) < 0.01, "decor never adds income directly")
	d.cash = 5
	T.act(a, "decor", "floor", nil, "gold")
	H.check(d.interiors.pizza.floor == "wood", "you can't buy what you can't afford")
	d.cash = 1e8

	H.section("Leaving, and the room cleaning itself up")
	T.act(a, "leaveInterior")
	H.check(a:GetAttribute("Interior") == nil and root.Position.Y < 100, "Leave puts you back outside the door")
	H.task.wait(80)
	H.check(folder:FindFirstChild("Interior_Alice_pizza") == nil, "an empty room is removed after a minute")
	T.act(a, "decor", "wall", nil, "navy")
	H.check(d.interiors.pizza.wall == "brick", "you can only decorate while you're inside")

	H.section("Homes: interior, visits and the rating sign")
	T.act(a, "homeBuild")
	H.task.wait(0.5)
	T.act(a, "enterHome")
	H.check(a:GetAttribute("Interior") == "home", "the Home app takes you inside your house")
	T.act(a, "decor", "spot", 1, "bed")
	T.act(a, "decor", "spot", 2, "couch")
	H.check(d.interiors.home.spots["1"] == "bed", "homes can have beds")
	T.act(a, "leaveInterior")
	local b = T.join("Bob", 202)
	local db = T.newGame(b, 1, 2)
	db.cash = 1e6
	-- Bob tours Alice's house
	T.act(b, "tourVisit", 101)
	H.task.wait(0.5)
	H.check((d.homeVisits or 0) == 1, "a visit is counted")
	T.act(b, "tourVisit", 101)
	H.check((d.homeVisits or 0) == 1, "...once per visitor per day")
	T.act(b, "tourVote", 101, "rate", 5)
	H.check(d.homeRatingN == 1 and d.homeRatingSum == 5, "Bob rates the house 5 stars")
	T.act(b, "tourVote", 101, "rate", 1)
	H.check(d.homeRatingN == 1, "he can't rate it again (once per week)")
	T.act(a, "tourVote", 101, "rate", 5)
	H.check(d.homeRatingN == 1, "Alice can't rate her own house")
	local lot = F.homeLot(d)
	local sign = lot.signGui
	H.check(sign and sign:FindFirstChild("L1").Text:find("ALICE'S HOUSE") and sign:FindFirstChild("L2").Text:find("★★★★★  5.0") and sign:FindFirstChild("L3").Text:find("1 ratings • 1 visits"),
		"the sign over the house shows: " .. (sign and (sign.L1.Text .. " | " .. sign.L2.Text .. " | " .. sign.L3.Text) or "?"))
	-- Bob walks inside Alice's home: he can look, not decorate
	local homeDoor
	for _, pp in ipairs(prompts(folder, "Enter")) do if pp.ObjectText == "Alice's Home" then homeDoor = pp end end
	H.check(homeDoor ~= nil, "the house has an Enter door")
	trigger(homeDoor, b)
	H.check(b:GetAttribute("Interior") == "home" and b:GetAttribute("InteriorOwner") == 101, "Bob can step inside Alice's home")
	T.act(b, "decor", "spot", 3, "statue")
	H.check(d.interiors.home.spots["3"] == nil and db.cash >= 1e6, "...but can't change anything in it")
	H.task.wait(1.2)
	H.check(F.interiorState(b, db).mine == false, "Bob's state says it's not his room")
	-- rate limit across houses
	local c = T.join("Cara", 303)
	local dc = T.newGame(c, 1, 3)
	T.act(c, "homeBuild")
	H.task.wait(0.5)
	T.act(b, "tourVisit", 303)
	T.act(b, "tourVote", 303, "like")
	T.act(b, "tourVote", 303, "rate", 4)
	H.check((dc.homeLikes or 0) == 1 and (dc.homeRatingN or 0) == 0, "a second vote within a few seconds is rate-limited")
	H.task.wait(6)
	T.act(b, "tourVote", 303, "rate", 4)
	H.check((dc.homeRatingN or 0) == 1, "...and works after a short wait")

	H.section("Saved")
	F.save(a)
	H.task.wait(0.5)
	local saved = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(saved.interiors and saved.interiors.pizza.wall == "brick" and saved.interiors.home.spots["1"] == "bed" and saved.homeVisits == 1, "interiors, visits and ratings are saved")

	T.assertClean("interiors + house ratings")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
