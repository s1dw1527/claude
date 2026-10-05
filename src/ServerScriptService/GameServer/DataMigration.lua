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
}
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
	for _, name in ipairs({"v5", "v6", "v7", "v8"}) do
		local orig = samples[name]
		local before = deepCopy(orig)
		local ok, t, log = M.migrate(orig)
		local kept = ok and t.cash == before.cash and t.earned == before.earned and t.rep == before.rep
		if ok and before.levels then
			for k, v in pairs(before.levels) do if t.levels[k] ~= v then kept = false end end
		end
		if ok and before.story then kept = kept and t.story.ch == before.story.ch and t.story.title == before.story.title end
		local untouched = orig.SchemaVersion == before.SchemaVersion and orig.viral == nil
		add(ok and kept and untouched and t.SchemaVersion == V.SCHEMA_VERSION and t.mail ~= nil and type(t.viral) == "table" and t.evictions == 0,
			name .. " save → schema " .. tostring(t and t.SchemaVersion) .. ", progress kept (" .. table.concat(log, " | ") .. ")")
	end
	do
		local ok, t, log = M.migrate(samples.v9)
		add(ok and t.SchemaVersion == V.SCHEMA_VERSION and #log == 0 and t.viral.score == 350 and t.evictions == 2, "v9 save loads with no changes")
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
		local broken = deepCopy(samples.v8)
		local real = M.steps[8]
		M.steps[8] = function() error("simulated bug in the v9 step") end
		local ok, _, _, err = M.migrate(broken)
		M.steps[8] = real
		add(not ok and tostring(err):find("8 %-> 9") ~= nil and samples.v8.viral == nil, "a crashing v9 step is refused and the stored v8 save is untouched: " .. tostring(err))
	end
	return report
end
end
