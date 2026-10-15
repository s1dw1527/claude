-- v18: CURIOSITY. The 📚 Collection Book shows found treasures in full and the rest as "❓ ???" (the server never
-- sends an unfound item's name or icon), finds come from real play (Bazaar buys, lucky sales) and are announced
-- once, milestones pay once and only when reached, it's saved; and the 🔮 "coming up next" card arrives once a
-- session after a while of play, with tomorrow's reward, the next city event and the next Bazaar restock.
-- Run with: python3 tests/run.py tests/collection_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut = 0
	d.frozenUntil = H.now() + 1e7
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local clock = 1750000000
	C.bazaarClock = function() return clock end

	H.section("Mystery first")
	local info = F.collectInfo(a)
	local total = #C.BAZAAR_ITEMS + #C.RARE_SALES.list
	local hidden = true
	for _, it in ipairs(info.items) do if it.found or it.name ~= nil or it.icon ~= nil or not it.rarity or not it.where then hidden = false end end
	H.check(info.total == total and info.found == 0 and hidden, total .. " entries, all \"❓ ???\": the server sends only the rarity and where to look, never the name")

	H.section("Finding things")
	d.cash = 1e9
	local w = F.bazaarWindow(clock)
	local s1 = F.bazaarStock(w)[1]
	H.check(F.bazaarBuy(a, 1, w), "buy " .. s1.key .. " in the Bazaar")
	local mark = #H.remoteLog
	H.task.wait(C.TEASER.check + 1)
	local heard = false
	for _, m in ipairs(T.announcesSince(mark, a)) do if tostring(m):find("New in your collection", 1, true) then heard = true end end
	info = F.collectInfo(a)
	local shown
	for _, it in ipairs(info.items) do if it.key == s1.key then shown = it end end
	H.check(info.found == 1 and shown and shown.found and shown.name == C.FURNITURE_BY[s1.key].name, "it's in the book with its name and icon (1 / " .. total .. ")")
	H.check(heard, "\"📚 New in your collection\" is announced")
	-- placing it at home doesn't lose it
	d.furniture[s1.key] = nil
	H.check(F.collectInfo(a).found == 1, "once found, always found (even after it's placed or gone from storage)")
	-- a lucky sale counts
	d.frozenUntil = 0
	F.serveCustomer(a, d, "lemonade", C.NPC_TYPES[1], nil, "golden")
	d.levels.lemonade = 1
	F.serveCustomer(a, d, "lemonade", C.NPC_TYPES[1], nil, "golden")
	d.frozenUntil = H.now() + 1e7
	info = F.collectInfo(a)
	local gold = false
	for _, it in ipairs(info.items) do if it.key == "rare_golden" and it.found then gold = true end end
	H.check(gold, "a ✨ Golden customer goes in the book too")

	H.section("Milestones")
	local cash0 = d.cash
	H.check(not F.collectClaim(a, 1) and d.cash == cash0, "milestone 1 (5 found) can't be claimed with " .. F.collectInfo(a).found)
	for i = 2, 6 do d.furniture[C.BAZAAR_ITEMS[i].key] = 1 end
	info = F.collectInfo(a)
	H.check(info.found >= 5 and info.milestones[1].done, "5+ found: the first milestone is ready")
	local rep0 = d.rep
	H.task.wait(0.6)   -- (claims are at least half a second apart)
	H.check(F.collectClaim(a, 1) and d.cash > cash0 and d.rep > rep0, string.format("claimed: +$%s, +%d ⭐", C.fmt(d.cash - cash0), d.rep - rep0))
	cash0 = d.cash
	H.task.wait(0.6)
	H.check(not F.collectClaim(a, 1) and d.cash == cash0, "only once")
	T.act(a, "collectClaim", 4)
	H.task.wait(0.6)
	H.check(d.cash == cash0, "the 'everything' milestone stays locked until everything is found")

	H.section("The app")
	cc.closeModals()
	cc.openModal("collection", true)
	H.task.wait(1.5)
	local m = cc.modals.collection
	local q, named = 0, 0
	for _, x in ipairs(m.frame:GetDescendants()) do
		if x.Name == "ItemName" then
			if x.Text == "???" then q += 1 else named += 1 end
		end
	end
	H.check(m.frame.Visible and q > 0 and named == F.collectInfo(a).found, string.format("📚 Collection: %d found cards, %d \"???\" cards", named, q))
	cc.closeModals()

	H.section("🔮 Coming up next")
	local mark2 = #H.remoteLog
	H.task.wait(C.TEASER.after + C.TEASER.check * 2)
	local got = T.remotesSince(mark2, "Menu", a)
	local teasers = {}
	for _, e in ipairs(got) do if e.args[1] == "teaser" then table.insert(teasers, e.args[2]) end end
	local txt = ""
	if teasers[1] then for _, l in ipairs(teasers[1].lines) do txt = txt .. l.text .. " | " end end
	H.check(#teasers == 1, "after " .. C.TEASER.after / 60 .. " minutes of play: one \"coming up next\" card")
	H.check(txt:find("Bazaar restock in %d+:%d%d") and txt:find("city event", 1, true) and (txt:find("Tomorrow", 1, true) or txt:find("still waiting", 1, true)),
		"it tells what's coming: " .. txt:sub(1, 200))
	local card = a.PlayerGui:FindFirstChild("TeaserCard", true)
	H.check(card and card.Visible, "shown in the notification stack")
	H.task.wait(C.TEASER.check * 3)
	local again = 0
	for _, e in ipairs(T.remotesSince(mark2, "Menu", a)) do if e.args[1] == "teaser" then again += 1 end end
	H.check(again == 1, "once a session")

	H.section("Saved")
	H.removePlayer(a)
	H.task.wait(3)
	local db = rawget(T.slotStore(), "_data")
	local saved = db["u101_s1"]
	H.check(saved and type(saved.collect) == "table" and saved.collect.found[s1.key] ~= nil and saved.collect.claimed["1"] ~= nil, "the book and the claimed milestone are in the save")

	T.assertClean("collection")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
