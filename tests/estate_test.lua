-- v10: real estate (districts, plots, deeds, limits, choosing a business, selling), business names (filtered),
-- brands, products, supplies and trending products. Run with: python3 tests/run.py tests/estate_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local LOTS = C.LOTS
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local pg = a:FindFirstChild("PlayerGui")
	local function findLike(pat)
		for _, x in ipairs(pg:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) and x.Visible ~= false then return x end
		end
	end
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function inModal(key, pat)
		for _, x in ipairs(cc.modals[key].frame:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end
	local function calm()
		local t = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut = 0
	local function lotIn(dkey, free)
		for _, l in ipairs(LOTS) do if l.dkey == dkey and (not free or not l.owner) then return l end end
	end

	H.section("The city: districts and plots")
	local counts = {}
	for _, l in ipairs(LOTS) do counts[l.dkey] = (counts[l.dkey] or 0) + 1 end
	local parts = {}
	for _, dist in ipairs(C.DISTRICTS) do table.insert(parts, dist.name .. " " .. (counts[dist.key] or 0)) end
	print("    " .. table.concat(parts, ", "))
	H.check(#C.DISTRICTS == 8 and #LOTS >= 95, #C.DISTRICTS .. " districts, " .. #LOTS .. " plots")
	H.check(counts.downtown < counts.midtown and counts.beach < counts.suburbs and counts.luxury <= 4, "prime districts are small, regular ones are big")
	local sumCaps = 0
	for _, dist in ipairs(C.DISTRICTS) do
		sumCaps += dist.cap
		H.check(dist.cap * 4 <= (counts[dist.key] or 0) + 2, dist.name .. ": a per-player cap of " .. dist.cap .. " leaves room for 4 players")
	end
	local overlap = false
	for i, l1 in ipairs(LOTS) do
		for j = i + 1, #LOTS do
			local l2 = LOTS[j]
			if math.abs(l1.pos.X - l2.pos.X) < 23 and math.abs(l1.pos.Z - l2.pos.Z) < 23 then overlap = true print("    overlap: " .. l1.id .. " / " .. l2.id) end
		end
	end
	H.check(not overlap, "no two plots overlap")
	local onRoad = false
	for _, l in ipairs(LOTS) do
		for _, r in ipairs(C.ROADS) do
			local axis, c, a1, b1, w = r[1], r[2], r[3], r[4], r[5]
			local along, across = axis == "x" and l.pos.X or l.pos.Z, axis == "x" and l.pos.Z or l.pos.X
			if along > a1 and along < b1 and math.abs(across - c) < w / 2 + 11 then onRoad = true print("    on a road: plot " .. l.id) end
		end
	end
	H.check(not onRoad, "no plot sits on a road")
	local signs = 0
	for _, x in ipairs(H.workspace:FindFirstChild("City"):FindFirstChild("RealEstate"):GetDescendants()) do
		if x.ClassName == "TextLabel" and x.Text == "PROPERTY FOR SALE" then signs += 1 end
	end
	H.check(signs == #LOTS, "every free plot has a PROPERTY FOR SALE sign (" .. signs .. ")")

	H.section("Buying, limits and fairness")
	d.cash = 1e6
	H.check(F.propertyCapacity(d) == 1, "a brand-new player can own 1 property")
	local s1 = lotIn("suburbs", true)
	local mark = #H.remoteLog
	T.act(a, "plotView", s1.id)
	H.task.wait(0.5)
	H.check(inModal("plot", "PROPERTY FOR SALE") ~= nil and inModal("plot", "^BUY") ~= nil, "viewing a plot shows the PROPERTY FOR SALE card with BUY")
	H.check(inModal("plot", "Potential: ★★☆☆☆") ~= nil and inModal("plot", "District: 🏘️") ~= nil, "...with the district, type and potential")
	local price = F.plotPrice(d, "suburbs")
	local cashB = d.cash
	click(inModal("plot", "^BUY"))
	H.task.wait(0.5)
	H.check(#d.deeds == 1 and d.deeds[1].district == "suburbs" and s1.owner == a and math.abs((cashB - d.cash) - price) < 50, "BUY: a deed, the plot is Alice's, $" .. C.fmt(price) .. " paid")
	local choose
	for _, e in ipairs(T.remotesSince(mark, "Menu", a)) do if e.args[1] == "chooseBiz" then choose = e.args[2] end end
	H.check(choose and #choose.options == 8, "then: CHOOSE YOUR BUSINESS with all 8 types")
	H.check(findLike("CHOOSE YOUR BUSINESS") ~= nil, "the chooser opens on screen")
	local s2 = lotIn("suburbs", true)
	T.act(a, "plotBuy", s2.id)
	H.check(#d.deeds == 1 and not s2.owner, "a 2nd property is refused at the first reputation tier (1/1)")
	-- choose a business on the plot: Lemonade isn't open yet in this save, so it opens there
	H.check((d.levels.lemonade or 0) == 0, "(Alice hasn't opened anything yet)")
	mark = #H.remoteLog
	T.act(a, "plotBiz", d.deeds[1].id, "lemonade")
	H.task.wait(0.5)
	H.check(d.levels.lemonade == 1 and d.deeds[1].biz == "lemonade", "choosing Lemonade opens it on that plot")
	local ask
	for _, e in ipairs(T.remotesSince(mark, "Menu", a)) do if e.args[1] == "nameBiz" then ask = e.args[2] end end
	H.check(ask and ask.key == "lemonade" and ask.suggestion == "Alice's Lemonade", "...and asks for a name (suggested: " .. tostring(ask and ask.suggestion) .. ")")
	T.act(a, "plotBiz", d.deeds[1].id, "tech")
	H.check(d.deeds[1].biz == "lemonade", "a business you haven't unlocked can't be chosen")
	H.check(F.locationMult(d, "lemonade") > 1, string.format("a location adds income: x%.2f", F.locationMult(d, "lemonade")))
	-- more reputation: more capacity, district caps and rising prices
	d.rep = 1300   -- CITY ICON
	H.check(F.propertyCapacity(d) == 6, "CITY ICON: 6 properties")
	d.cash = 1e9
	local dt1, dt2, dt3 = nil, nil, nil
	for _, l in ipairs(LOTS) do
		if l.dkey == "downtown" and not l.owner then
			if not dt1 then dt1 = l elseif not dt2 then dt2 = l elseif not dt3 then dt3 = l end
		end
	end
	local p1 = F.plotPrice(d, "downtown")
	T.act(a, "plotBuy", dt1.id)
	local p2 = F.plotPrice(d, "downtown")
	T.act(a, "plotBuy", dt2.id)
	H.check(dt1.owner == a and dt2.owner == a and math.abs(p2 / p1 - 1.25) < 0.01, "each extra plot in a district costs 25% more ($" .. C.fmt(p1) .. " → $" .. C.fmt(p2) .. ")")
	T.act(a, "plotBuy", dt3.id)
	H.check(not dt3.owner, "Downtown's per-player cap (2) stops a 3rd plot")
	-- another player can't buy Alice's plot
	local bob = T.join("Bob", 202)
	local db = T.newGame(bob, 1, 2)
	db.tut, db.cash, db.rep = 0, 1e9, 1300
	T.act(bob, "plotBuy", dt1.id)
	H.check(dt1.owner == a and #db.deeds == 0, "Bob can't buy Alice's plot")
	T.act(bob, "plotView", dt1.id)
	local view
	for _, e in ipairs(T.remotesSince(#H.remoteLog - 5, "Menu", bob)) do if e.args[1] == "plot" then view = e.args[2] end end
	H.check(view and view.owner == "Alice" and not view.mine and view.price == nil, "Bob sees OWNED BY: Alice (no price, no BUY)")
	T.act(bob, "plotBuy", dt3.id)
	H.check(dt3.owner == bob, "Bob buys his own Downtown plot")

	H.section("Deeds are permanent (leaving, rejoining, full districts)")
	local deedCount = #d.deeds
	local income0 = F.income(d, os.clock())
	F.save(a)
	H.task.wait(0.5)
	local saved = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(#saved.deeds == deedCount and saved.deeds[1].biz == "lemonade", "deeds are saved with the business on them")
	T.act(a, "menuExit")
	H.task.wait(1.5)
	H.check(dt1.owner == nil and dt2.owner == nil and s1.owner == nil, "leaving frees the plots for everyone")
	-- Bob grabs one of Alice's downtown plots while she's away
	T.act(bob, "plotBuy", dt1.id)
	H.check(dt1.owner == bob, "Bob buys a plot Alice used to stand on")
	T.act(a, "menuPlay", 1)
	H.task.wait(4)
	d = T.data(a)
	calm()
	local placed, free = 0, 0
	for _, deed in ipairs(d.deeds) do if F.lotOfDeed(a, deed) then placed += 1 end end
	H.check(#d.deeds == deedCount and placed == deedCount, "Alice keeps every deed; each one is placed on a plot again (" .. placed .. "/" .. deedCount .. ")")
	local where = {}
	for _, deed in ipairs(d.deeds) do if deed.district == "downtown" then table.insert(where, deed.plot) end end
	H.check(#where == 2 and where[1] ~= dt1.id and where[2] ~= dt1.id, "her downtown deed moved to another free Downtown plot")
	-- a full district: the deed still counts and still earns
	local wf = {}
	for _, l in ipairs(LOTS) do if l.dkey == "beach" then table.insert(wf, l) end end
	d.rep = 2000
	d.deedSeq += 1
	table.insert(d.deeds, {id = "d" .. d.deedSeq, district = "beach", paid = 1})
	for _, l in ipairs(wf) do l.owner = bob end   -- (simulated: the Waterfront is full in this server)
	F.placeDeeds(a, d)
	local wd = d.deeds[#d.deeds]
	H.check(F.lotOfDeed(a, wd) == nil and F.countLots(d, "beach") == 1, "a Waterfront deed in a full Waterfront still counts")
	local inc = F.income(d, os.clock())
	H.check(inc > income0, "...and still earns")
	for _, l in ipairs(wf) do l.owner = nil end
	F.placeDeeds(a, d)
	H.check(F.lotOfDeed(a, wd) ~= nil, "when a plot frees up, it's placed")

	H.section("Old land lots become deeds")
	rawget(T.slotStore(), "_data")["u303_s1"] = {SchemaVersion = 9, cash = 5e6, earned = 1e8, levels = {lemonade = 10, coffee = 4}, rep = 2000, tut = 0, tutPaid = 7, lots = {2, 7}}
	local carl = T.join("Carl", 303)
	T.act(carl, "menuPlay", 1)
	H.task.wait(4)
	local dc = T.data(carl)
	H.check(dc and #dc.deeds == 2 and dc.deeds[1].district == "downtown" and dc.deeds[2].district == "industrial", "a v9 save's lots {2, 7} became Downtown + Industrial deeds")
	H.check(F.lotOfDeed(carl, dc.deeds[1]) ~= nil, "...placed in the world")
	H.check(dc.deeds[1].biz == nil, "...as vacant plots waiting for a business")

	H.section("Selling")
	local sellDeed = d.deeds[1]
	local cash0 = d.cash
	local others = #d.deeds - 1
	T.act(a, "plotSell", sellDeed.id)
	H.check(F.deedById(d, sellDeed.id) ~= nil, "selling without the confirmation flag does nothing")
	T.act(a, "plotSell", sellDeed.id, true)
	H.check(F.deedById(d, sellDeed.id) == nil and math.abs((d.cash - cash0) - math.floor(sellDeed.paid * 0.5)) < F.incomePerSec(d) + 1, "confirmed: sold for half of what it cost")
	H.check(#d.deeds == others and F.deedById(d, d.deeds[1].id) ~= nil, "only that deed is gone; the others are untouched")

	H.section("Business names (filtered by the server)")
	d.levels.coffee = 3
	local function rename(key, name)
		local m0 = #H.remoteLog
		T.act(a, "bizName", key, name)
		for _, e in ipairs(T.remotesSince(m0, "Menu", a)) do if e.args[1] == "nameResult" then return e.args[2] end end
	end
	local r1 = rename("lemonade", "Spencer's Lemon Lab")
	H.check(r1 and r1.ok and F.bizName(d, "lemonade") == "Spencer's Lemon Lab", "first name: \"Spencer's Lemon Lab\" (free)")
	H.task.wait(1.5)
	local bb = cc.S.biz[1]
	H.check(bb.brand == "Spencer's Lemon Lab", "the business card uses the name")
	local sign = false
	for _, x in ipairs(d.plot.folder:GetDescendants()) do if x.ClassName == "TextLabel" and x.Text == "SPENCER'S LEMON LAB" then sign = true end end
	H.check(sign, "the world sign says SPENCER'S LEMON LAB")
	local r2 = rename("coffee", "badword cafe")
	H.check(r2 and not r2.ok and F.bizName(d, "coffee") == "Coffee", "filtered text is refused: " .. tostring(r2 and r2.why))
	H.filterFail = true
	local r3 = rename("coffee", "Bean There")
	H.filterFail = false
	H.check(r3 and not r3.ok and F.bizName(d, "coffee") == "Coffee", "if the filter can't be reached, the name isn't changed: " .. tostring(r3 and r3.why))
	local r4 = rename("coffee", "X")
	local r5 = rename("coffee", string.rep("A", 30))
	H.check(not r4.ok and not r5.ok, "too short / too long are refused")
	local r6 = rename("lemonade", "Lemon Lab 2")
	H.check(not r6.ok and F.bizName(d, "lemonade") == "Spencer's Lemon Lab", "renaming again right away: cooldown (" .. tostring(r6.why) .. ")")
	H.task.wait(601)
	local c0 = d.cash
	local fee = F.renameFee(d, "lemonade")
	local r7 = rename("lemonade", "The Lemon Lab")
	H.check(r7.ok and fee > 0 and c0 - d.cash >= fee - 1, "after the cooldown a rename costs a fee ($" .. C.fmt(fee) .. ")")
	T.act(bob, "bizName", "lemonade", "Bob Was Here")
	H.check(F.bizName(d, "lemonade") == "The Lemon Lab", "nobody can rename another player's business")

	H.section("Brand style")
	T.act(a, "brand", "lemonade", "logo", "🐝")
	T.act(a, "brand", "lemonade", "accent", 4)
	T.act(a, "brand", "lemonade", "theme", "Neon")
	T.act(a, "brand", "lemonade", "accent", 99)
	T.act(a, "brand", "lemonade", "logo", "💩💩")
	local br = d.brands.lemonade
	H.check(br.logo == "🐝" and br.accent == 4 and br.theme == "Neon", "logo, accent and theme are saved")
	H.check(br.accent == 4 and br.logo == "🐝", "invalid values are ignored")

	H.section("Products")
	d.levels.lemonade = 1
	H.check(F.productSlots(d, "lemonade") == 1 and #F.productsOf(d, "lemonade") == 1, "Lv 1: one product (the classic, made automatically)")
	H.check(math.abs(F.productMult(d, "lemonade") - 1) < 0.001, "defaults change nothing: x1.00")
	T.act(a, "product", "lemonade", {"new", "blue", "Blue Raspberry Blast"})
	H.check(#F.productsOf(d, "lemonade") == 1, "no free slot at Lv 1")
	d.levels.lemonade = 5
	T.act(a, "product", "lemonade", {"new", "blue", "Blue Raspberry Blast"})
	T.act(a, "product", "lemonade", {"new", "mango", "badword juice"})
	local list = F.productsOf(d, "lemonade")
	H.check(#list == 2 and list[2].name == "Blue Raspberry Blast", "Lv 5: create Blue Raspberry Blast (a filtered name is refused)")
	local id = list[2].id
	T.act(a, "product", "lemonade", {"price", id, 9})
	H.check(list[2].price == 2, "prices are clamped (max 200% of fair)")
	local high = F.productMult(d, "lemonade")
	T.act(a, "product", "lemonade", {"price", id, 1.3})
	local good = F.productMult(d, "lemonade")
	T.act(a, "product", "lemonade", {"price", id, 0.5})
	local low = F.productMult(d, "lemonade")
	print(string.format("    income multiplier: price 200%% x%.2f, 130%% x%.2f, 50%% x%.2f", high, good, low))
	H.check(good > high and good > low and good <= 1.35, "the best price is a bit above fair; too high or too low loses money")
	T.act(a, "product", "lemonade", {"price", id, 1})
	for _ = 1, 5 do T.act(a, "product", "lemonade", {"q", id}) end
	T.act(a, "product", "lemonade", {"q", id})
	H.check(list[2].q == 5, "quality upgrades up to 5")
	local upgraded = F.productMult(d, "lemonade")
	H.check(upgraded > 1 and upgraded <= 1.35, string.format("upgrades help, within the cap (x%.2f)", upgraded))
	local inc1 = F.incomePerSec(d)
	local customersBefore = F.productCustomerMult(d, "lemonade")
	H.check(customersBefore > 1, "in-demand products bring more customers")

	H.section("Supplies")
	local st = F.stockOf(d, "lemonade")
	H.check(math.min(st[1], st[2], st[3]) > 20 and F.stockMult(d, "lemonade") == 1, "well stocked: no effect (" .. math.floor(st[1]) .. "%)")
	local t1 = C.NPC_TYPES[1]
	for _ = 1, 1100 do F.serveCustomer(a, d, "lemonade", t1, nil) end
	print(string.format("    after 1,100 customers: %d%% / %d%% / %d%%", st[1], st[2], st[3]))
	H.check(math.min(st[1], st[2], st[3]) < 20 and F.stockMult(d, "lemonade") < 1, "customers use supplies; low stock cuts sales")
	a.Character:PivotTo(CFrame.new(3000, 5, 3000))
	T.act(a, "restock", "lemonade")
	H.check(st[1] < 100, "you have to be at the business to restock it")
	T.act(a, "restock", "lemonade", "remote")
	H.check(st[1] < 100, "remote restocking needs an Executive computer")
	d.computer.tier = 3
	local cost = F.restockCost(d, "lemonade", true)
	local cash1 = d.cash
	T.act(a, "restock", "lemonade", "remote")
	H.check(st[1] == 100 and st[2] == 100 and math.abs((cash1 - d.cash) - cost) < F.incomePerSec(d) + 2, "with an Executive computer: remote restock ($" .. C.fmt(cost) .. ", +10% delivery)")
	d.computer.tier = 0

	H.section("Trending products")
	H.task.wait(20)   -- (the big burst of test customers above just made its own CityBuzz post)
	local m1 = #H.remoteLog
	F.productTrending(a, d, "lemonade", list[2])
	H.check(F.productCustomerMult(d, "lemonade") >= customersBefore * 1.4, "trending: more customers for a while")
	local post = false
	for _, p in ipairs(C.FEED) do if tostring(p.text):find("Blue Raspberry Blast") then post = true end end
	H.check(post, "CityBuzz: \"" .. (C.FEED[1] and C.FEED[1].text or "?") .. "\"")
	local splash = false
	for _, e in ipairs(T.remotesSince(m1, "Splash", a)) do if tostring(e.args[1]):find("TRENDING") then splash = true end end
	H.check(splash, "\"YOUR BLUE RASPBERRY BLAST IS TRENDING\"")
	H.task.wait(95)
	H.check(F.productCustomerMult(d, "lemonade") < customersBefore * 1.4, "...and it wears off")

	H.section("The manage window")
	H.task.wait(1.5)
	cc.BusinessUI.openManage("lemonade", "products")
	H.task.wait(0.5)
	H.check(findLike("Blue Raspberry Blast") ~= nil and findLike("Quality 5/5") ~= nil, "Products tab")
	cc.BusinessUI.openManage("lemonade", "supplies")
	H.task.wait(0.5)
	H.check(findLike("Lemons") ~= nil and findLike("Restock here") ~= nil, "Supplies tab")
	cc.BusinessUI.openManage("lemonade", "brand")
	H.task.wait(0.5)
	H.check(findLike("The Lemon Lab") ~= nil and findLike("Employee uniforms") ~= nil, "Brand tab")
	cc.closeModals()

	T.assertClean("estate + brands")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
