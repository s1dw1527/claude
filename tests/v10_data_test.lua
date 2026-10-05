-- v10 data: v8 / v9 saves → schema 10 through the real join flow (land lots become permanent deeds, every new
-- field gets a safe default), broken v10 fields are repaired, a disconnect in the middle of a purchase, switching
-- servers with deeds, and two players buying the same plot at the same moment.
-- Run with: python3 tests/run.py tests/v10_data_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local store = T.slotStore()
	local db = rawget(store, "_data")
	local function play(plr, slot)
		T.act(plr, "menuPlay", slot)
		H.task.wait(3)
		return T.data(plr)
	end

	H.section("A v8 save → v10")
	db["u101_s1"] = {SchemaVersion = 8, cash = 5e6, earned = 9e7, rep = 1300, tut = 0, tutPaid = 7, levels = {lemonade = 10, icecream = 8, pizza = 3}, cars = {sedan = true},
		mail = {}, interiors = {home = {wall = "brick", floor = "wood", light = "warm", spots = {["2"] = "couch"}}}, homeVisits = 4, saveSeq = 3, staff = {}}
	local a = T.join("Alice", 101)
	local d = play(a, 1)
	H.check(d and not d.noSave and d.cash >= 5e6 and d.levels.pizza == 3 and d.cars.sedan and d.interiors.home.spots["2"] == "couch", "everything from v8 is still there (cash, levels, cars, home decor)")
	H.check(type(d.deeds) == "table" and #d.deeds == 0 and type(d.brands) == "table" and type(d.hq) == "table" and d.hq.level == 0 and type(d.mgr) == "table"
		and type(d.homeBuild) == "table" and type(d.furniture) == "table" and type(d.garage) == "table" and type(d.arcade) == "table" and type(d.perms) == "table", "every v10 field starts with a safe default")
	H.check(d.perms.house == "public" and d.perms.hq == "friends", "visitor defaults: house public, HQ friends-only")
	F.save(a)
	H.task.wait(0.5)
	H.check(db["u101_s1"].SchemaVersion == C.VERSION.SCHEMA_VERSION and db["u101_s1"].saveSeq == 4, "saved back as the current schema")

	H.section("A v9 save with land lots → permanent deeds")
	db["u102_s1"] = {SchemaVersion = 9, cash = 8e6, earned = 3e8, rep = 1500, tut = 0, tutPaid = 7, levels = {lemonade = 10, coffee = 6, pizza = 3}, lots = {1, 6}, mail = {}, saveSeq = 9,
		viral = {score = 40, log = {}}, staff = {}}
	local b = T.join("Bob", 102)
	local dbb = play(b, 1)
	local districts = {}
	for _, deed in ipairs(dbb.deeds) do table.insert(districts, deed.district) end
	H.check(#dbb.deeds == 2 and districts[1] == "downtown" and districts[2] == "industrial", "v9 lots 1 and 6 became a Downtown and an Industrial deed")
	local placed = 0
	for _, deed in ipairs(dbb.deeds) do if F.lotOfDeed(b, deed) then placed += 1 end end
	H.check(placed == 2, "both deeds are standing on plots in the city")

	H.section("Broken v10 fields are repaired, not fatal")
	db["u103_s1"] = {SchemaVersion = 10, cash = 1234, earned = 5000, rep = 10, tut = 0, tutPaid = 7, levels = {lemonade = 2}, saveSeq = 2, staff = {},
		deeds = "oops", brands = 7, hq = {level = "five"}, homeBuild = {items = "x"}, garage = false, arcade = {tickets = -50}, perms = {house = "everyone"}}
	local c = T.join("Carl", 103)
	local dc = play(c, 1)
	H.check(dc and not dc.noSave and dc.cash >= 1234 and dc.levels.lemonade == 2, "the save still loads (cash and levels intact)")
	H.check(type(dc.deeds) == "table" and type(dc.brands) == "table" and F.hqLevel(dc) == 0 and type(dc.homeBuild.items) == "table" and type(dc.garage) == "table", "broken fields were reset to safe values")
	H.check(F.arcadeData(dc).tickets == 0 and F.permState(dc).house == "public", "negative tickets and unknown visitor modes are fixed")

	H.section("Disconnecting in the middle of a purchase")
	d.rep = 1300
	local lot
	for _, l in ipairs(C.LOTS) do if l.dkey == "downtown" and not l.owner then lot = l break end end
	local cash0 = d.cash
	T.act(a, "plotBuy", lot.id)
	H.removePlayer(a)    -- straight away: the leave-save happens with the purchase applied
	H.task.wait(2)
	local s = db["u101_s1"]
	H.check(#s.deeds == 1 and s.deeds[1].district == "downtown" and s.cash <= cash0 - s.deeds[1].paid + 50, "the saved data has both the deed and the payment (never just one)")
	H.check(lot.owner == nil, "the plot is free again in this server while Alice is away")

	H.section("Switching servers")
	-- someone else takes "her" plot while she's gone; when she comes back, her deed moves to another plot in the same district
	local dd = T.data(b)
	dd.rep = 1500
	dd.cash = 1e8
	T.act(b, "plotBuy", lot.id)
	H.check(lot.owner == b, "Bob bought the plot Alice used to stand on")
	local a2 = T.join("Alice", 101)
	local d2 = play(a2, 1)
	local where = d2 and d2.deeds[1] and F.lotOfDeed(a2, d2.deeds[1])
	H.check(#d2.deeds == 1 and where and where ~= lot and where.dkey == "downtown", "Alice's deed is still hers: placed on another Downtown plot (" .. tostring(where and where.id) .. ")")

	H.section("Two players buying the same plot at the same moment")
	local free
	for _, l in ipairs(C.LOTS) do if l.dkey == "midtown" and not l.owner then free = l break end end
	d2.rep, dd.rep = 1500, 1500
	d2.cash, dd.cash = 1e8, 1e8
	local ca, cb = d2.cash, dd.cash
	-- both requests arrive in the same frame
	H.signalOf(T.R.Action, "OnServerEvent"):Fire(a2, "plotBuy", free.id)
	H.signalOf(T.R.Action, "OnServerEvent"):Fire(b, "plotBuy", free.id)
	H.task.wait(0.5)
	local paidA, paidB = ca - d2.cash > 1000, cb - dd.cash > 1000
	H.check(free.owner ~= nil and (paidA ~= paidB), "exactly one of them gets it (" .. tostring(free.owner and free.owner.Name) .. ") and only that one pays")

	T.assertClean("v10 data")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
