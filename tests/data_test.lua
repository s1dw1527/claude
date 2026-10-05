-- v8 data safety: schema versioning, migrations, UpdateAsync conflict protection, failed loads.
-- Run with: python3 tests/run.py tests/data_test.lua
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
	local function leave(plr)
		T.act(plr, "menuExit")
		H.task.wait(1.5)
	end

	H.section("Version + store names")
	H.check(C.VERSION.VERSION == "10.0.0" and C.VERSION.SCHEMA_VERSION == 10 and C.VERSION.MIN_SUPPORTED_SCHEMA == 6, "C.VERSION is 10.0.0 / schema 10 / oldest 6")
	H.check(C.CFG.DATASTORE == "CornerEmpire_v5", "the live DataStore name is unchanged (CornerEmpire_v5)")
	H.check(C.storeName(C.CFG.DATASTORE) == "CornerEmpire_v5_StudioTest", "Studio playtests use a separate test copy of the store")

	H.section("The Studio self-test (real load/save code, fake store)")
	local report = F.dataSafetyTest()
	local bad = 0
	for _, line in ipairs(report) do
		print("    " .. line)
		if line:sub(1, 3) ~= "✅" then bad += 1 end
	end
	H.check(#report >= 15 and bad == 0, #report .. " self-test checks, " .. bad .. " failed")

	H.section("Existing v6 and v7 saves through the real join flow")
	local a = T.join("Alice", 101)
	db["u101_s1"] = {cash = 3e7, earned = 5e8, rep = 2100, tut = 0, tutPaid = 7, served = 3000, levels = {lemonade = 10, icecream = 10, bakery = 8},
		combos = {frozenlemon = true}, cars = {moped = true}, achievements = {million = 1}, trophies = 2, followers = 900, rebirths = 1,
		modFieldFromSomewhere = {keep = true}}
	db["u101_s2"] = {cash = 9e5, earned = 4e6, storyEarned = 3e6, rep = 500, tut = 0, tutPaid = 7, levels = {lemonade = 10, icecream = 6, bakery = 3, coffee = 1},
		story = {ch = 4, done = {c1 = true, c2 = true, c3 = true}, paid = {c1 = true, c2 = true, c3 = true}, obj = {}, intro = {c4 = true}, flags = {}, title = "Local Menace"}, saveSeq = 7}
	local d = play(a, 1)
	H.check(d and not d.noSave and d.cash >= 3e7 and d.levels.bakery == 8 and d.rebirths == 1 and d.cars.moped and d.trophies == 2, "v6 save: money, levels, rebirths, cars, trophies all kept")
	H.check(d.mail and d.interiors and d.improve and d.reviewBook and d.homeVisits == 0, "v6 save: v8 fields added")
	F.save(a)
	H.task.wait(0.5)
	local s1 = db["u101_s1"]
	H.check(s1.SchemaVersion == C.VERSION.SCHEMA_VERSION and s1.gameVersion == C.VERSION.VERSION and s1.saveSeq == 1 and type(s1.viral) == "table" and s1.evictions == 0
		and type(s1.deeds) == "table" and type(s1.brands) == "table", "saved back at the current schema (with the v9 + v10 records), save counter 1")
	H.check(s1.modFieldFromSomewhere and s1.modFieldFromSomewhere.keep == true, "a field this version doesn't know about is kept")
	H.check(s1.earned >= 5e8 and s1.levels.lemonade == 10 and s1.tutPaid == 7, "every old field survives the round trip")
	leave(a)
	d = play(a, 2)
	H.check(d and not d.noSave and d.story.ch == 4 and d.story.title == "Local Menace" and d.storyEarned >= 3e6, "v7 save: story chapter, title and story earnings kept")
	F.save(a)
	H.task.wait(0.5)
	H.check(db["u101_s2"].saveSeq == 8 and db["u101_s2"].SchemaVersion == C.VERSION.SCHEMA_VERSION, "the v7 save's counter continues (7 -> 8) and it's at the current schema")

	H.section("Leaving and rejoining")
	d.cash = 777777
	leave(a)
	d = play(a, 2)
	H.check(d and math.floor(d.cash) >= 777777 and not d.noSave, "progress saved on leave is there after rejoining")

	H.section("Server switching: a stale server never overwrites newer progress")
	-- another server saved this slot while Alice was still here (simulated by bumping the stored counter)
	db["u101_s2"].saveSeq += 5
	db["u101_s2"].cash = 123
	local mark = #H.remoteLog
	local ok = F.save(a)
	H.check(ok == false and d.noSave == true, "the save is refused and this server stops saving")
	H.check(db["u101_s2"].cash == 123, "the newer stored progress is untouched")
	local warned = false
	for _, txt in ipairs(T.announcesSince(mark, a)) do if tostring(txt):find("updated somewhere else") then warned = true end end
	H.check(warned, "the player is told to rejoin")
	leave(a)
	H.check(db["u101_s2"].cash == 123, "leaving doesn't overwrite it either")

	H.section("A save from a newer version of the game")
	db["u101_s3"] = {SchemaVersion = C.VERSION.SCHEMA_VERSION + 1, cash = 42, earned = 42, levels = {lemonade = 2}, rep = 0, brandNewFutureThing = {1, 2, 3}}
	d = play(a, 3)
	H.check(d and d.noSave and d.loadProblem == "newer" and d.levels.lemonade == 2, "it loads (read-only) and this server won't save it")
	d.cash = 1e9
	leave(a)
	H.check(db["u101_s3"].SchemaVersion == C.VERSION.SCHEMA_VERSION + 1 and db["u101_s3"].cash == 42 and db["u101_s3"].brandNewFutureThing, "the newer save is untouched")

	H.section("Corrupt saves and failed loads never become a fresh save")
	local b = T.join("Bob", 202)
	db["u202_s1"] = {cash = "lots", earned = 0, levels = {lemonade = "ten"}}
	local dbb = play(b, 1)
	H.check(dbb and dbb.noSave and dbb.loadProblem == "migration", "a corrupt save: the session is marked unsafe")
	leave(b)
	H.check(db["u202_s1"].cash == "lots", "...and the stored save is untouched")
	db["u202_s2"] = {cash = 5e6, earned = 9e6, levels = {lemonade = 10}, rep = 300}
	H.dsReadFail = true
	T.act(b, "menuPlay", 2)
	H.task.wait(8)   -- the loader retries with back-off before giving up
	H.dsReadFail = false
	dbb = T.data(b)
	H.check(dbb and dbb.noSave and dbb.loadProblem == "load", "a failed load: the session is marked unsafe")
	dbb.cash = 0
	leave(b)
	H.check(db["u202_s2"].cash == 5e6, "...and the real save (cash $5M) is never replaced by a blank one")

	H.section("New games and deleting slots")
	local c = T.join("Cara", 303)
	db["u303_s1"] = {cash = 50, earned = 50, levels = {}, rep = 0, saveSeq = 12, SchemaVersion = 8}
	T.act(c, "menuNew", 1, 1)
	H.task.wait(3)
	local dc = T.data(c)
	dc.cash = 4242
	H.check(F.save(c) == true and db["u303_s1"].saveSeq == 13 and db["u303_s1"].cash == 4242, "starting a new game in a used slot replaces it on purpose (counter 12 -> 13)")
	leave(c)
	T.act(c, "menuDelete", 1)
	H.task.wait(1)
	local meta = db["u303_meta"]
	H.check(db["u303_s1"] == nil and meta and meta.slots.s1 == nil, "deleting a slot removes it from the save list too")

	-- these scenarios are failures on purpose: each should leave exactly its warning in the server log
	local function warned(pat)
		for _, w in ipairs(H.warnings) do if w:find(pat) then return true end end
		return false
	end
	H.check(warned("not saving Alice") and warned("couldn't migrate Bob") and warned("load attempt 3 failed"), "each failure is logged as a warning for the developer")
	H.warnings = {}
	T.assertClean("data safety (no script errors)")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
