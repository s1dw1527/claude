-- DATA MIGRATION: brings any older save up to the current schema, one version at a time, and checks the result.
--
--   saved table (from the DataStore, never modified)
--     -> detect its schema (SchemaVersion, or inferred for saves from before versioning)
--     -> copy it, then run every migration step in order: 6 -> 7 -> 8 -> ...
--     -> validate the result
--   Only a save that made it through all of that becomes the player's profile. If anything fails, the
--   session is marked unsafe to save, so the player's real save is never overwritten.
--
-- Rules for a migration step: only ADD missing fields with safe defaults, or translate an old field into a
-- new one. Never delete or reset a field that already has a value. Bump C.VERSION.SCHEMA_VERSION together
-- with each new step.
return function(C)
local M = {}
C.DataMigration = M
local V = C.VERSION

local function deepCopy(v, depth)
	if type(v) ~= "table" then return v end
	if (depth or 0) > 20 then error("save is nested too deeply") end
	local out = {}
	for k, x in pairs(v) do out[k] = deepCopy(x, (depth or 0) + 1) end
	return out
end
M.copy = deepCopy

-- which schema is this save? (v8+ saves carry SchemaVersion; earlier ones are recognised by their fields)
function M.detect(saved)
	local sv = tonumber(saved.SchemaVersion)
	if sv then return math.floor(sv) end
	if saved.story ~= nil or saved.storyEarned ~= nil then return 7 end
	return 6   -- v5/v6 saves (v5 saves have no tutPaid; the 6 -> 7 step fills it in)
end

-- each step takes a save at schema n and returns it at schema n + 1, plus a note of what it did
M.steps = {
	[6] = function(t)
		local notes = {}
		-- tutorial rewards weren't tracked before v6: steps already walked count as paid
		if t.tutPaid == nil then
			local tut = tonumber(t.tut) or 1
			t.tutPaid = (tut == 0) and #C.TUTORIAL or math.max(0, tut - 1)
			table.insert(notes, "tutPaid = " .. t.tutPaid)
		end
		-- story mode arrived in v7: no "story" field yet means the Story module marks the chapters this empire has
		-- already beaten (it does that the first time the save loads); nothing to write here
		return notes
	end,
	[7] = function(t)
		local notes = {}
		local function default(key, value)
			if t[key] == nil then
				t[key] = value
				table.insert(notes, key)
			end
		end
		-- v8 fields
		default("mail", {})         -- saved Messages (important ones: story, City Hall, investors)
		default("interiors", {})    -- interior customization for each business and the home
		default("improve", {})      -- business improvements (quality, speed, cleanliness, service, atmosphere)
		default("reviewBook", {})   -- open bad reviews that can be won back
		default("homeVisits", 0)    -- how many people toured your home
		return notes
	end,
	[8] = function(t)
		local notes = {}
		-- v9: Viral Moments + new achievement counters. Nothing existing is touched.
		if t.viral == nil then
			t.viral = M.defaultViral()
			table.insert(notes, "viral")
		end
		if t.evictions == nil then
			t.evictions = 0
			table.insert(notes, "evictions")
		end
		if t.openings == nil then
			t.openings = {}
			table.insert(notes, "openings")
		end
		return notes
	end,
	[9] = function(t)
		local notes = {}
		-- v10: land becomes DEEDS. Before v10 a lot was only "yours" while you were in the server, and if someone
		-- else held it when you came back it quietly disappeared from your save. A deed is permanent: it says which
		-- district you own a plot in, and the server finds you a plot there every time you join.
		if t.deeds == nil then
			local deeds = {}
			for i, id in ipairs(type(t.lots) == "table" and t.lots or {}) do
				local n = tonumber(id)
				local dkey = n and M.OLD_LOT_DISTRICT[n]
				if dkey then table.insert(deeds, {id = "d" .. i, district = dkey, plot = n, bought = 0}) end
			end
			t.deeds = deeds
			t.deedSeq = #deeds
			table.insert(notes, "deeds (" .. #deeds .. " from old land lots)")
		end
		for k, v in pairs(M.v10Defaults()) do
			if t[k] == nil then
				t[k] = v
				table.insert(notes, k)
			end
		end
		return notes
	end,
	[10] = function(t)
		local notes = {}
		-- v11: the secret mountain HQ and robberies. One new record; robbery loot itself is never saved.
		for k, v in pairs(M.v11Defaults()) do
			if t[k] == nil then
				t[k] = v
				table.insert(notes, k)
			end
		end
		return notes
	end,
	[11] = function(t)
		local notes = {}
		-- v12: empire value milestones, first-income / first-upgrade moments, Hall of Fame bookkeeping.
		-- One new record; a save that already has any of it (or unknown extra fields) keeps them.
		for k, v in pairs(M.v12Defaults()) do
			if t[k] == nil then
				t[k] = v
				table.insert(notes, k)
			end
		end
		-- a veteran already had their first income and upgrade: no "first!" pop-ups for them
		if type(t.empire) == "table" and ((tonumber(t.earned) or 0) > 100 or (type(t.levels) == "table" and (tonumber(t.levels.lemonade) or 0) > 1)) then
			if t.empire.firstIncome == false then t.empire.firstIncome = true end
			if t.empire.firstUpgrade == false then t.empire.firstUpgrade = true end
			-- milestones this save had already passed before v12 are recognized on the first check, not paid again
			if t.empire.seeded ~= true then t.empire.legacy = true end
		end
		return notes
	end,
	[12] = function(t)
		local notes = {}
		-- v13: the living city: Golden Corners collected, places discovered, City Jobs done. One new record.
		for k, v in pairs(M.v13Defaults()) do
			if t[k] == nil then
				t[k] = v
				table.insert(notes, k)
			end
		end
		return notes
	end,
	[13] = function(t)
		local notes = {}
		-- v14: the Movie Theater and the rest of v14's records. All new; a save that already has any keeps it.
		for k, v in pairs(M.v14Defaults()) do
			if t[k] == nil then
				t[k] = v
				table.insert(notes, k)
			end
		end
		return notes
	end,
}
-- every new v14 field and its safe default
function M.v14Defaults()
	return {
		theater = {up = {}, sessions = 0, tickets = 0, best = 0, filmShows = 0, premiered = {}},
	}
end
-- every new v13 field and its safe default
function M.v13Defaults()
	return {
		city = {corners = {}, places = {}, jobs = 0, jobPay = 0, streak = 0},
	}
end
-- every new v12 field and its safe default
function M.v12Defaults()
	return {
		empire = {ms = {}, best = 0, pub = 0, pubAt = 0, firstIncome = false, firstUpgrade = false, visits = 0, legacy = false, seeded = false},
	}
end
-- every new v11 field and its safe default
function M.v11Defaults()
	return {
		heist = {discovered = false, done = 0, failed = 0, earned = 0, best = 0, bag = 1, base = 1, arrests = 0, policeEarned = 0},
	}
end
-- all the "new feature" records v10+ added (each repaired on its own, never fatal)
function M.featureDefaults()
	local out = M.v10Defaults()
	for k, v in pairs(M.v11Defaults()) do out[k] = v end
	for k, v in pairs(M.v12Defaults()) do out[k] = v end
	for k, v in pairs(M.v13Defaults()) do out[k] = v end
	for k, v in pairs(M.v14Defaults()) do out[k] = v end
	return out
end
-- the 16 land lots of v5-v9, in the order the world built them (4 per district)
M.OLD_LOT_DISTRICT = {"downtown", "downtown", "downtown", "downtown", "industrial", "industrial", "industrial", "industrial",
	"beach", "beach", "beach", "beach", "luxury", "luxury", "luxury", "luxury"}
-- every new v10 field and its safe default
function M.v10Defaults()
	return {
		brands = {},          -- business names, colors, logo, theme, uniform, menu style (per business type)
		products = {},        -- product lines per business type
		stock = {},           -- supplies per business type (0-100 each)
		hq = {level = 0},     -- headquarters (0 = not built)
		mgr = {left = 0, auto = false, handled = 0},   -- General Manager contract (seconds of play left)
		computer = {tier = 0},
		homeBuild = {items = {}, styles = {}, v = 0},    -- grid furniture + house styles
		furniture = {},       -- furniture you own but haven't placed (key -> count)
		carMods = {},         -- per car: paint, wheels, tint, plate...
		garage = {fav = {}, names = {}},
		arcade = {tickets = 0, wins = 0, played = 0},
		perms = {house = "public", business = "public", hq = "friends"},
		invites = {},
		guide = {},           -- tips already shown
	}
end
-- v10 data is repaired, never fatal: a broken new table is replaced by its default and the original is kept
function M.repairV10(t, fixes)
	for k, def in pairs(M.featureDefaults()) do
		if t[k] ~= nil and type(t[k]) ~= "table" then
			t[k .. "Recovered"] = t[k .. "Recovered"] == nil and t[k] or t[k .. "Recovered"]
			t[k] = def
			table.insert(fixes, k .. " repaired")
		end
	end
	-- one level deeper: a field inside a v10 record with the wrong type (e.g. homeBuild.items = "x") goes back
	-- to its default; numbers must be real, non-negative numbers
	for k, def in pairs(M.featureDefaults()) do
		local cur = t[k]
		if type(cur) == "table" then
			for sub, dv in pairs(def) do
				local v = cur[sub]
				local bad
				if type(dv) == "number" then bad = v ~= nil and (type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge or v < 0)
				elseif type(dv) == "table" then bad = v ~= nil and type(v) ~= "table"
				elseif type(dv) == "boolean" then bad = v ~= nil and type(v) ~= "boolean"
				elseif type(dv) == "string" then bad = v ~= nil and type(v) ~= "string" end
				if bad then
					cur[sub] = type(dv) == "table" and {} or dv
					table.insert(fixes, k .. "." .. sub .. " repaired")
				end
			end
		end
	end
	if t.deeds ~= nil then
		if type(t.deeds) ~= "table" then
			t.deedsRecovered = t.deeds
			t.deeds = {}
			table.insert(fixes, "deeds repaired")
		else
			local clean = {}
			for _, dd in ipairs(t.deeds) do
				if type(dd) == "table" and type(dd.district) == "string" and type(dd.id) == "string" then table.insert(clean, dd) end
			end
			if #clean ~= #t.deeds then table.insert(fixes, "bad deeds dropped") end
			t.deeds = clean
		end
	end
end
-- the v9 Viral Moments record (score, recent moments, cooldowns, weekly history)
function M.defaultViral()
	return {score = 0, mentions = 0, log = {}, seen = {}, cd = {}, hall = {}, week = 0, weekScore = 0, cats = {}}
end
-- repair a viral record field by field; anything unusable is replaced by a default. Returns the record and
-- whether something had to be repaired. (A broken new feature must never stop the rest of a save loading.)
function M.repairViral(v)
	local def = M.defaultViral()
	if type(v) ~= "table" then return def, true end
	local fixed = false
	for k, dv in pairs(def) do
		local cur = v[k]
		if type(dv) == "number" then
			if type(cur) ~= "number" or cur ~= cur or cur == math.huge or cur == -math.huge or cur < 0 then
				v[k] = dv
				if cur ~= nil then fixed = true end
			end
		elseif type(cur) ~= "table" then
			v[k] = dv
			if cur ~= nil then fixed = true end
		end
	end
	-- the log must be a list of small tables
	local clean = {}
	for _, e in ipairs(v.log) do
		if type(e) == "table" and type(e.key) == "string" then table.insert(clean, e) end
		if #clean >= 30 then break end
	end
	if #clean ~= #v.log then fixed = true end
	v.log = clean
	return v, fixed
end

-- hard problems make a save unsafe to load; small ones are repaired and noted
function M.validate(t)
	local problems, fixes = {}, {}
	local function num(k, min)
		local v = t[k]
		if v == nil then return end
		if type(v) ~= "number" then table.insert(problems, k .. " is a " .. type(v)) return end
		if v ~= v or v == math.huge or v == -math.huge then table.insert(problems, k .. " is not a finite number") return end
		if min and v < min then
			t[k] = min
			table.insert(fixes, k .. " was below " .. min)
		end
	end
	local function tbl(k)
		if t[k] ~= nil and type(t[k]) ~= "table" then table.insert(problems, k .. " is a " .. type(t[k]) .. ", not a table") end
	end
	-- tutorial rewards must always know what was already paid (a missing value would pay every step again)
	if t.tutPaid == nil then
		local tut = tonumber(t.tut) or 1
		t.tutPaid = (tut == 0) and #C.TUTORIAL or math.max(0, tut - 1)
		table.insert(fixes, "tutPaid was missing")
	end
	num("cash", 0) num("earned", 0) num("rep", 0) num("rebirths", 0) num("trophies", 0) num("served", 0) num("followers", 0)
	num("storyEarned", 0) num("tut") num("tutPaid", 0)
	for _, k in ipairs({"levels", "chains", "staff", "combos", "cars", "seen", "props", "story", "mail", "interiors", "improve", "reviewBook"}) do tbl(k) end
	-- v9 data is repaired, never fatal: a damaged viral record must not stop the rest of the save loading.
	-- The damaged original is kept (viralRecovered) so nothing is thrown away.
	if t.viral ~= nil then
		local orig = t.viral
		local v, fixed = M.repairViral(type(orig) == "table" and deepCopy(orig) or orig)
		if fixed then
			if t.viralRecovered == nil then t.viralRecovered = orig end
			table.insert(fixes, "viral record repaired")
		end
		t.viral = v
	end
	if t.evictions ~= nil and (type(t.evictions) ~= "number" or t.evictions ~= t.evictions or t.evictions < 0) then
		t.evictions = 0
		table.insert(fixes, "evictions reset")
	end
	if t.openings ~= nil and type(t.openings) ~= "table" then
		t.openings = {}
		table.insert(fixes, "openings reset")
	end
	M.repairV10(t, fixes)
	if type(t.levels) == "table" then
		for key, lvl in pairs(t.levels) do
			if type(lvl) ~= "number" or lvl ~= lvl then
				table.insert(problems, "levels." .. tostring(key) .. " is not a number")
			elseif lvl > C.CFG.MAX_LEVEL then
				t.levels[key] = C.CFG.MAX_LEVEL
				table.insert(fixes, "levels." .. key .. " capped")
			end
		end
	end
	return #problems == 0, problems, fixes
end

-- the whole pipeline. Returns ok, migrated copy, log (list of strings), and an error message when not ok.
-- status: "ok", "newer" (saved by a newer version of the game: loadable, but this server must not save it)
function M.migrate(saved)
	local log = {}
	if type(saved) ~= "table" then return false, nil, log, "save is not a table" end
	local okCopy, t = pcall(deepCopy, saved)
	if not okCopy then return false, nil, log, "couldn't copy the save: " .. tostring(t) end
	local from = M.detect(t)
	if from < V.MIN_SUPPORTED_SCHEMA then
		table.insert(log, "schema " .. from .. " is older than " .. V.MIN_SUPPORTED_SCHEMA .. ": treated as " .. V.MIN_SUPPORTED_SCHEMA)
		from = V.MIN_SUPPORTED_SCHEMA
	end
	local status = "ok"
	if from > V.SCHEMA_VERSION then
		-- a newer server already saved this (during an update rollout): read what we understand, never write
		status = "newer"
		table.insert(log, "saved by schema " .. from .. ", this server is " .. V.SCHEMA_VERSION)
	else
		for n = from, V.SCHEMA_VERSION - 1 do
			local step = M.steps[n]
			if not step then return false, nil, log, "no migration step from schema " .. n end
			local okStep, notes = pcall(step, t)
			if not okStep then return false, nil, log, "migration " .. n .. " -> " .. (n + 1) .. " failed: " .. tostring(notes) end
			table.insert(log, n .. " -> " .. (n + 1) .. ((notes and #notes > 0) and (": " .. table.concat(notes, ", ")) or ""))
		end
		t.SchemaVersion = V.SCHEMA_VERSION
	end
	local okV, problems, fixes = M.validate(t)
	for _, f in ipairs(fixes) do table.insert(log, "repaired: " .. f) end
	if not okV then return false, nil, log, "invalid save: " .. table.concat(problems, "; ") end
	return true, t, log, nil, status
end

-- =====================================================================
-- Studio self-test: runs the pipeline on sample saves in memory (never touches a DataStore)
-- =====================================================================
function M.sampleSaves()
	return {
		v5 = {cash = 1200, earned = 5000, levels = {lemonade = 3}, rep = 20, tut = 4, staff = {}},
		v6 = {cash = 3e7, earned = 5e8, rep = 2100, tut = 0, tutPaid = 7, levels = {lemonade = 10, icecream = 10, bakery = 8},
			combos = {frozenlemon = true}, cars = {moped = true}, home = {lot = 3, level = 2}, achievements = {million = 1}},
		v7 = {cash = 9e5, earned = 4e6, storyEarned = 3e6, rep = 500, tut = 0, tutPaid = 7, levels = {lemonade = 10, icecream = 6, bakery = 3, coffee = 1},
			story = {ch = 4, done = {c1 = true, c2 = true, c3 = true}, paid = {c1 = true, c2 = true, c3 = true}, obj = {}, intro = {c4 = true}, flags = {}, title = "Local Menace"}},
		v8 = {SchemaVersion = 8, cash = 50, earned = 10, levels = {lemonade = 1}, rep = 0, tut = 2, tutPaid = 1, mail = {}, interiors = {}, improve = {}, reviewBook = {}, homeVisits = 0},
		v9 = {SchemaVersion = 9, cash = 75, earned = 20, levels = {lemonade = 2}, rep = 1, tut = 0, tutPaid = 7, mail = {}, interiors = {}, improve = {}, reviewBook = {}, homeVisits = 0,
			viral = {score = 350, mentions = 4, log = {{key = "opening", t = 1}}, seen = {}, cd = {}, hall = {}, week = 0, weekScore = 0, cats = {}}, evictions = 2, openings = {}},
		v9old = {SchemaVersion = 9, cash = 9e6, earned = 2e8, levels = {lemonade = 10, coffee = 6, pizza = 3}, rep = 1500, tut = 0, tutPaid = 7, lots = {1, 6, 10}, mail = {},
			viral = {score = 12, mentions = 1, log = {}, seen = {}, cd = {}, hall = {}, week = 0, weekScore = 0, cats = {}}, evictions = 1, openings = {}},
		brokenV10 = {SchemaVersion = 10, cash = 31337, earned = 1e5, levels = {lemonade = 3}, rep = 50, tut = 0, tutPaid = 7, brands = "oops", deeds = {{id = "d1", district = "midtown"}, "junk"}},
		v10 = {SchemaVersion = 10, cash = 4.2e7, earned = 9e8, levels = {lemonade = 10, pizza = 6}, rep = 2500, tut = 0, tutPaid = 7, deeds = {{id = "d1", district = "downtown", plot = 2}},
			brands = {lemonade = {name = "Sunny Sips"}}, hq = {level = 3}, garage = {fav = {coupe = true}, names = {}}, cars = {coupe = true}, homeBuild = {items = {{k = "sofa", x = 3, z = 7, r = 0}}, styles = {}, v = 2}},
		brokenV11 = {SchemaVersion = 11, cash = 777, earned = 999, levels = {lemonade = 2}, rep = 5, tut = 0, tutPaid = 7, heist = {bag = "huge", done = -3, discovered = "yes"}},
		v11 = {SchemaVersion = 11, cash = 2.5e8, earned = 4e9, levels = {lemonade = 10, pizza = 9, tech = 4}, rep = 6000, tut = 0, tutPaid = 7, deeds = {{id = "d2", district = "luxury", plot = 1, paid = 5e6}},
			brands = {pizza = {name = "Slice Empire", style = "neon"}}, hq = {level = 4}, heist = {discovered = true, done = 7, failed = 1, earned = 123456, best = 40000, bag = 3, base = 4, arrests = 0, policeEarned = 0},
			unknownFuture = {keep = "me"}},
		v12 = {SchemaVersion = 12, cash = 3.3e9, earned = 9e9, levels = {lemonade = 10, pizza = 10, tech = 7}, rep = 9000, tut = 0, tutPaid = 7,
			deeds = {{id = "d3", district = "downtown", plot = 1, paid = 4e5}}, brands = {tech = {name = "Byte Barn", style = "billionaire"}},
			heist = {discovered = true, done = 3, failed = 0, earned = 5000, best = 2000, bag = 2, base = 2, arrests = 0, policeEarned = 0},
			empire = {ms = {m1 = 100, m10 = 200, m100 = 300, m1000 = 400}, best = 3.4e9, pub = 3.4e9, pubAt = 1, firstIncome = true, firstUpgrade = true, visits = 2, legacy = false, seeded = true},
			cars = {coupe = true}, home = {level = 4}, unknownFuture2 = {keep = "me too"}},
		v13 = {SchemaVersion = 13, cash = 7.7e9, earned = 2e10, levels = {lemonade = 10, pizza = 10, tech = 9, factory = 5}, rep = 12000, tut = 0, tutPaid = 7,
			deeds = {{id = "d4", district = "luxury", plot = 1, paid = 6e6, biz = "tech"}}, brands = {factory = {name = "Gear Giant"}},
			empire = {ms = {m1 = 1, m10 = 2, m100 = 3, m1000 = 4}, best = 7.7e9, pub = 7e9, pubAt = 1, firstIncome = true, firstUpgrade = true, visits = 0, legacy = false, seeded = true},
			city = {corners = {gc1 = true, gc7 = true}, places = {spire = 1}, jobs = 12, jobPay = 99000, streak = 2}, cars = {coupe = true, hyper = true}, unknownFuture3 = {keep = "me three"}},
		brokenV14 = {SchemaVersion = 14, cash = 4321, earned = 9000, levels = {lemonade = 5, theater = 2}, rep = 11, tut = 0, tutPaid = 7, theater = {up = "big", sessions = -2, premiered = {dino = true}}},
		brokenV13 = {SchemaVersion = 13, cash = 999, earned = 7000, levels = {lemonade = 4}, rep = 9, tut = 0, tutPaid = 7, city = {corners = "lots", jobs = -4, places = {spire = 5}}},
		brokenV12 = {SchemaVersion = 12, cash = 888, earned = 5000, levels = {lemonade = 3}, rep = 7, tut = 0, tutPaid = 7, empire = {ms = "oops", best = -5, firstIncome = "yes"}},
		brokenViral = {SchemaVersion = 9, cash = 500, earned = 900, levels = {lemonade = 4}, rep = 10, tut = 0, tutPaid = 7, viral = "garbage", evictions = -5},
		future = {SchemaVersion = 99, cash = 1, earned = 1, levels = {}, rep = 0, someNewThing = {x = 1}},
		corrupt = {cash = "lots", earned = 0/0, levels = {lemonade = "ten"}},
		missingField = {SchemaVersion = 8, cash = 10, earned = 10, levels = {}, rep = 0},
	}
end
function M.selfTest()
	local report = {}
	local function add(okFlag, text) table.insert(report, (okFlag and "✅ " or "❌ ") .. text) end
	local samples = M.sampleSaves()
	-- every older save comes out at the current schema with its progress untouched
	for _, name in ipairs({"v5", "v6", "v7", "v8", "v9old"}) do
		local orig = samples[name]
		local before = deepCopy(orig)
		local ok, t, log = M.migrate(orig)
		local kept = ok and t.cash == before.cash and t.earned == before.earned and t.rep == before.rep
		if ok and before.levels then
			for k, v in pairs(before.levels) do if t.levels[k] ~= v then kept = false end end
		end
		if ok and before.story then kept = kept and t.story.ch == before.story.ch and t.story.title == before.story.title end
		local untouched = orig.SchemaVersion == before.SchemaVersion and orig.deeds == nil
		add(ok and kept and untouched and t.SchemaVersion == V.SCHEMA_VERSION and t.mail ~= nil and type(t.viral) == "table" and t.evictions ~= nil
			and type(t.deeds) == "table" and type(t.brands) == "table" and type(t.homeBuild) == "table",
			name .. " save → schema " .. tostring(t and t.SchemaVersion) .. ", progress kept (" .. table.concat(log, " | ") .. ")")
	end
	do
		local ok, t = M.migrate(samples.v9)
		add(ok and t.SchemaVersion == V.SCHEMA_VERSION and t.viral.score == 350 and t.evictions == 2 and #t.deeds == 0, "v9 save keeps its viral record and gets the v10 fields")
	end
	do
		local ok, t = M.migrate(samples.v9old)
		local ds = {}
		for _, dd in ipairs(ok and t.deeds or {}) do table.insert(ds, dd.district) end
		add(ok and #t.deeds == 3 and ds[1] == "downtown" and ds[2] == "industrial" and ds[3] == "beach" and t.deeds[1].plot == 1,
			"old land lots become permanent deeds (" .. table.concat(ds, ", ") .. ")")
	end
	do
		local ok, t, log = M.migrate(samples.brokenV10)
		add(ok and t.cash == 31337 and type(t.brands) == "table" and t.brandsRecovered == "oops" and #t.deeds == 1,
			"a damaged v10 record is repaired and the rest loads (" .. table.concat(log, " | ") .. ")")
	end
	do
		local ok, t, log = M.migrate(samples.v10)
		add(ok and t.SchemaVersion == V.SCHEMA_VERSION and t.cash == 4.2e7 and #t.deeds == 1 and t.brands.lemonade.name == "Sunny Sips" and t.hq.level == 3
			and t.homeBuild.items[1].k == "sofa" and type(t.heist) == "table" and t.heist.discovered == false and t.heist.bag == 1,
			"v10 save keeps deeds, brand, HQ, garage and furniture, and gets the v11 heist record (" .. table.concat(log, " | ") .. ")")
	end
	do
		local orig = samples.v11
		local before = deepCopy(orig)
		local ok, t, log = M.migrate(orig)
		add(ok and t.SchemaVersion == V.SCHEMA_VERSION and t.cash == before.cash and t.earned == before.earned and t.levels.pizza == 9 and t.brands.pizza.style == "neon"
			and t.heist.done == 7 and t.heist.base == 4 and t.unknownFuture.keep == "me" and type(t.empire) == "table" and next(t.empire.ms) == nil and t.empire.best == 0
			and orig.empire == nil and orig.SchemaVersion == 11,
			"v11 save keeps cash, businesses, deeds, brand, HQ, heists and unknown fields, and gets the v12 empire record (" .. table.concat(log, " | ") .. ")")
	end
	do
		local ok, t, log = M.migrate(samples.brokenV12)
		add(ok and t.cash == 888 and type(t.empire.ms) == "table" and t.empire.best == 0 and t.empire.firstIncome == false and table.concat(log, "|"):find("empire.ms repaired", 1, true) ~= nil,
			"a damaged v12 empire record is repaired; the rest of the save loads (" .. table.concat(log, " | ") .. ")")
	end
	do
		local orig = samples.v12
		local before = deepCopy(orig)
		local ok, t, log = M.migrate(orig)
		add(ok and t.SchemaVersion == V.SCHEMA_VERSION and t.cash == before.cash and t.earned == before.earned and t.levels.tech == 7 and t.brands.tech.style == "billionaire"
			and t.empire.ms.m1000 == 400 and t.empire.seeded == true and t.heist.done == 3 and t.cars.coupe == true and t.home.level == 4 and t.unknownFuture2.keep == "me too"
			and type(t.city) == "table" and next(t.city.corners) == nil and t.city.jobs == 0 and orig.city == nil and orig.SchemaVersion == 12,
			"v12 save keeps cash, businesses, brand style, all 4 milestones, heists, cars, home and unknown fields, and gets the v13 city record (" .. table.concat(log, " | ") .. ")")
	end
	do
		local ok, t, log = M.migrate(samples.brokenV13)
		add(ok and t.cash == 999 and type(t.city.corners) == "table" and t.city.jobs == 0 and t.city.places.spire == 5,
			"a damaged v13 city record is repaired field by field; the rest of the save loads (" .. table.concat(log, " | ") .. ")")
	end
	do
		local broken = deepCopy(samples.v12)
		local real = M.steps[12]
		M.steps[12] = function() error("simulated bug in the v13 step") end
		local ok, _, _, err = M.migrate(broken)
		M.steps[12] = real
		add(not ok and tostring(err):find("12 %-> 13") ~= nil and samples.v12.city == nil, "a crashing v13 step is refused and the stored v12 save is untouched: " .. tostring(err))
	end
	do
		local orig = samples.v13
		local before = deepCopy(orig)
		local ok, t, log = M.migrate(orig)
		add(ok and t.SchemaVersion == V.SCHEMA_VERSION and t.cash == before.cash and t.earned == before.earned and t.levels.factory == 5 and t.deeds[1].biz == "tech"
			and t.city.jobs == 12 and t.city.corners.gc7 == true and t.empire.ms.m1000 == 4 and t.cars.hyper == true and t.unknownFuture3.keep == "me three"
			and type(t.theater) == "table" and t.theater.sessions == 0 and t.levels.theater == nil and orig.theater == nil and orig.SchemaVersion == 13,
			"v13 save keeps cash, businesses, plots, city progress, milestones, cars and unknown fields, and gets the v14 records (" .. table.concat(log, " | ") .. ")")
	end
	do
		local ok, t, log = M.migrate(samples.brokenV14)
		add(ok and t.cash == 4321 and t.levels.theater == 2 and type(t.theater.up) == "table" and t.theater.sessions == 0 and t.theater.premiered.dino == true,
			"a damaged v14 theater record is repaired field by field; the rest of the save loads (" .. table.concat(log, " | ") .. ")")
	end
	do
		local broken = deepCopy(samples.v13)
		local real = M.steps[13]
		M.steps[13] = function() error("simulated bug in the v14 step") end
		local ok, _, _, err = M.migrate(broken)
		M.steps[13] = real
		add(not ok and tostring(err):find("13 %-> 14") ~= nil and samples.v13.theater == nil, "a crashing v14 step is refused and the stored v13 save is untouched: " .. tostring(err))
	end
	do
		local broken = deepCopy(samples.v11)
		local real = M.steps[11]
		M.steps[11] = function() error("simulated bug in the v12 step") end
		local ok, _, _, err = M.migrate(broken)
		M.steps[11] = real
		add(not ok and tostring(err):find("11 %-> 12") ~= nil and samples.v11.empire == nil, "a crashing v12 step is refused and the stored v11 save is untouched: " .. tostring(err))
	end
	do
		local ok, t, log = M.migrate(samples.brokenV11)
		add(ok and t.cash == 777 and t.heist.bag == 1 and t.heist.done == 0 and t.heist.discovered == false,
			"a damaged v11 heist record is repaired; the rest of the save loads (" .. table.concat(log, " | ") .. ")")
	end
	do
		local broken = deepCopy(samples.v10)
		local real = M.steps[10]
		M.steps[10] = function() error("simulated bug in the v11 step") end
		local ok, _, _, err = M.migrate(broken)
		M.steps[10] = real
		add(not ok and tostring(err):find("10 %-> 11") ~= nil and samples.v10.heist == nil, "a crashing v11 step is refused and the stored v10 save is untouched: " .. tostring(err))
	end
	do
		local ok, t, log = M.migrate(samples.brokenViral)
		add(ok and t.cash == 500 and t.levels.lemonade == 4 and t.viral.score == 0 and t.viralRecovered == "garbage" and t.evictions == 0,
			"a damaged v9 viral record is repaired; the rest of the save loads (" .. table.concat(log, " | ") .. ")")
	end
	do
		local ok, t, _, _, status = M.migrate(samples.future)
		add(ok and status == "newer" and t.someNewThing ~= nil, "a save from a NEWER version loads read-only (status: " .. tostring(status) .. ")")
	end
	do
		local ok, _, _, err = M.migrate(samples.corrupt)
		add(not ok and err ~= nil, "a corrupt save is refused: " .. tostring(err))
	end
	do
		local ok = M.migrate(nil)
		add(not ok, "a missing/failed load never turns into a save")
	end
	do
		local s = samples.missingField
		s.SchemaVersion = 7
		local ok, t = M.migrate(s)
		add(ok and t.mail and t.interiors and t.improve and t.reviewBook and t.homeVisits == 0, "missing v8 fields are added with safe defaults")
	end
	do
		local broken = deepCopy(samples.v7)
		local real = M.steps[7]
		M.steps[7] = function() error("simulated bug in a migration") end
		local ok, _, _, err = M.migrate(broken)
		M.steps[7] = real
		add(not ok and tostring(err):find("7 %-> 8") ~= nil, "a migration that crashes halfway is refused: " .. tostring(err))
	end
	do
		local broken = deepCopy(samples.v9)
		local real9 = M.steps[9]
		M.steps[9] = function() error("simulated bug in the v10 step") end
		local ok9, _, _, err9 = M.migrate(broken)
		M.steps[9] = real9
		add(not ok9 and tostring(err9):find("9 %-> 10") ~= nil and samples.v9.deeds == nil, "a crashing v10 step is refused and the stored v9 save is untouched: " .. tostring(err9))
		broken = deepCopy(samples.v8)
		local real = M.steps[8]
		M.steps[8] = function() error("simulated bug in the v9 step") end
		local ok, _, _, err = M.migrate(broken)
		M.steps[8] = real
		add(not ok and tostring(err):find("8 %-> 9") ~= nil and samples.v8.viral == nil, "a crashing v9 step is refused and the stored v8 save is untouched: " .. tostring(err))
	end
	return report
end
end
