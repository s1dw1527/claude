-- The business selector + management card, improvements, and reviews you can win back.
-- Run with: python3 tests/run.py tests/business_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local pg = a:FindFirstChild("PlayerGui")
	local function all(pred)
		local out = {}
		for _, x in ipairs(pg:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and pred(tostring(x.Text), x) then table.insert(out, x) end
		end
		return out
	end
	local function findLike(pat) return all(function(t) return t:find(pat) ~= nil end)[1] end
	local function click(btn) H.signalOf(btn, "MouseButton1Click"):Fire() H.task.wait(0.3) end
	local t = H.now()
	while cc.storyCutscene() and H.now() - t < 120 do H.task.wait(0.5) end
	d.tut = 0
	d.cash, d.rep = 1e7, 500

	H.section("Business selector")
	H.task.wait(1.2)
	local chips = {}
	local icons = {}
	for _, b in ipairs(C.BUSINESSES) do icons[b.icon] = true end
	for _, x in ipairs(pg:GetDescendants()) do
		if x.ClassName == "TextLabel" and icons[x.Text] and x.TextSize == 22 and x.Parent.ClassName == "TextButton" then table.insert(chips, x.Parent) end
	end
	H.check(#chips == #C.BUSINESSES, "one compact chip per business (" .. #chips .. ")")
	H.check(findLike("^BUY  %$") ~= nil, "the card's action button offers to buy the selected business")
	-- pick the Bakery and buy it from the card
	local bakeryChip
	for _, c in ipairs(chips) do
		for _, ch in ipairs(c:GetChildren()) do if ch.ClassName == "TextLabel" and ch.Text == "🥐" then bakeryChip = c end end
	end
	click(bakeryChip)
	H.task.wait(1.2)
	H.check(cc.selectedBusiness() == "bakery", "tapping a chip selects that business")
	H.check(findLike("Bread Stall") ~= nil, "the card now shows the Bakery")
	click(findLike("^BUY  %$"))
	H.task.wait(1.2)
	H.check((d.levels.bakery or 0) == 1, "the card's button bought the selected business")
	H.check(findLike("^UPGRADE  %$") ~= nil and findLike("^Lv 1/10$") ~= nil, "now it offers the next upgrade")
	H.check(cc.selectedBusiness() == "bakery", "the pick is remembered while you play")
	H.check(findLike("customers$") ~= nil and findLike("Expenses") ~= nil, "the card shows customers and expenses")
	-- small screens: the panel scales down instead of covering the game
	local cam = H.workspace.CurrentCamera
	cam.ViewportSize = H.G.Vector2.new(667, 375)
	H.task.wait(0.2)
	local scale
	for _, x in ipairs(pg:GetDescendants()) do
		if x.ClassName == "UIScale" and x.Parent and x.Parent:FindFirstChild("ScrollingFrame", true) and x.Scale < 1 then scale = x.Scale end
	end
	H.check(scale == nil or scale < 1, "on a phone-sized screen the panel scales down (" .. tostring(scale) .. ")")

	H.section("Improvements")
	local c0 = d.cash
	local cost = F.improveCost(d, "bakery", "speed")
	T.act(a, "improve", "bakery", "speed")
	H.check(F.improveLevel(d, "bakery", "speed") == 1 and math.abs((c0 - d.cash) - cost) < 1, "buying Speed costs $" .. C.fmt(cost) .. " and raises it to level 1")
	T.act(a, "improve", "bakery", "lasers")
	T.act(a, "improve", "factory", "speed")
	H.check(F.improveLevel(d, "factory", "speed") == 0, "unknown improvements and businesses you don't own are refused")
	H.check(F.improveCost(d, "bakery", "speed") > cost, "each level costs more")
	local sat0 = F.satisfaction(d, "bakery")
	for _ = 1, 3 do T.act(a, "improve", "bakery", "service") end
	H.check(F.satisfaction(d, "bakery") > sat0, "improvements make customers happier (" .. sat0 .. " -> " .. F.satisfaction(d, "bakery") .. ")")
	local inc0 = F.incomePerSec(d)
	T.act(a, "improve", "bakery", "quality")
	H.check(math.abs(F.incomePerSec(d) - inc0) < 0.01, "...but never add income directly (no money exploit)")

	H.section("Reviews you can win back")
	local function stars(n) return string.rep("★", n) .. string.rep("☆", 5 - n) end
	d.levels.icecream = 2
	d.improve.icecream = {}
	local npc = C.NPC_TYPES[1]
	local attr, text = F.reviewReason(d, "icecream", 2)
	H.check(attr ~= nil and text ~= nil, "a bad review names a reason: \"" .. tostring(text) .. "\" (" .. tostring(attr) .. ")")
	F.serveCustomer(a, d, "icecream", npc, {stars = 2, text = text, attr = attr, who = "Gary"})
	local rv = d.reviewBook[1]
	H.check(rv and rv.biz == "icecream" and rv.attr == attr and not rv.updated, "it's recorded against the Ice Cream business")
	-- improving the area doesn't change it by itself
	T.act(a, "improve", "icecream", attr)
	H.task.wait(1)
	H.check(not rv.updated, "upgrading alone doesn't rewrite the review")
	-- the customer has to come back
	local tries = 0
	while not rv.updated and tries < 20 do
		tries += 1
		F.serveCustomer(a, d, "icecream", npc, nil)
	end
	H.check(rv.updated and rv.updated.stars > rv.stars, "a later visit wins them back: " .. stars(rv.stars) .. " → " .. (rv.updated and stars(rv.updated.stars) or "?") .. " \"" .. tostring(rv.updated and rv.updated.text) .. "\"")
	H.check(rv.text == text, "the original words are never edited: the customer added an update")
	H.task.wait(1.5)
	cc.selectBusiness("icecream")
	H.task.wait(1.2)
	H.check(findLike("^✅ Came back") ~= nil, "the card shows the won-back review")
	-- a second bad review that hasn't been fixed shows how to fix it
	F.serveCustomer(a, d, "icecream", npc, {stars = 1, text = "Zero vibes. Zero.", attr = "atmosphere", who = "Brenda"})
	H.task.wait(1.5)
	H.check(findLike("Improve Atmosphere to win them back") ~= nil, "an open complaint says which improvement fixes it")
	-- saved with the slot
	F.save(a)
	H.task.wait(0.5)
	local saved = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(saved.reviewBook and #saved.reviewBook >= 2 and saved.improve and saved.improve.icecream, "reviews and improvements are saved")

	H.section("Another player can't touch your business")
	local b = T.join("Bob", 202)
	local db = T.newGame(b, 1, 2)
	db.cash = 1e9
	local before = F.improveLevel(d, "icecream", "atmosphere")
	T.act(b, "improve", "icecream", "atmosphere")
	H.check(F.improveLevel(d, "icecream", "atmosphere") == before, "Bob's improvements only ever apply to Bob's own businesses")

	T.assertClean("business panel + reviews")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
