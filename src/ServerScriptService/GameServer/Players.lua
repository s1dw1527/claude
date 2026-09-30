-- PLAYERS: save slots + main menu, loading/unloading, state sync, button actions, main loops.
return function(C)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local F, data, plots, R, G = C.F, C.data, C.plots, C.R, C.G
local CFG, BUSINESSES, BIZ, CHAINS, COMBOS, REP_TIERS, DISTRICTS, DISTRICT = C.CFG, C.BUSINESSES, C.BIZ, C.CHAINS, C.COMBOS, C.REP_TIERS, C.DISTRICTS, C.DISTRICT
local STAFF_ROLES, STAFF_ORDER, PROBLEMS, NPC_TYPES, EVENTS, ADS, SKINS, PASSES, CARS, CAR = C.STAFF_ROLES, C.STAFF_ORDER, C.PROBLEMS, C.NPC_TYPES, C.EVENTS, C.ADS, C.SKINS, C.PASSES, C.CARS, C.CAR
local HOODS, HOOD, HOME_LEVELS, STARTER_HOMES, RENTALS, RENTAL, TENANT, REBIRTH, TUTORIAL, FEATURES, FEATURE_NAMES =
	C.HOODS, C.HOOD, C.HOME_LEVELS, C.STARTER_HOMES, C.RENTALS, C.RENTAL, C.TENANT, C.REBIRTH, C.TUTORIAL, C.FEATURES, C.FEATURE_NAMES
local MINIGAMES, FERRIS, FIREWORKS, RACE = C.MINIGAMES, C.FERRIS, C.FIREWORKS, C.RACE
local fmt, notify, stageOf, staffStars = C.fmt, C.notify, C.stageOf, C.staffStars
local LOTS, DESTS, ADS_BY = C.LOTS, C.DESTS, C.ADS_BY
if C.DESTS_EXTRA then table.insert(DESTS, C.DESTS_EXTRA) end
if C.DESTS_MUSEUM then table.insert(DESTS, C.DESTS_MUSEUM) end
Players.CharacterAutoLoads = false
local session = {}

-- =====================================================================
-- SAVING (meta key = slot summaries + settings, one key per slot)
-- =====================================================================
local store = nil
if CFG.SAVE_ENABLED then
	local ok, s = pcall(function() return DataStoreService:GetDataStore(CFG.DATASTORE) end)
	if ok then store = s end
end
local SAVE_KEYS = {"cash", "levels", "chains", "staff", "combos", "rep", "ep", "trophies", "skin", "cars", "seen", "served", "deliveries",
	"marketing", "revSum", "revN", "contributed", "rebirths", "followers", "home", "raceBest", "tut", "earned", "rentEarned",
	"tutPaid", "richClaimed", "eraContrib", "achievements", "shared", "found", "wentViral", "viralCount",
	"mystery", "weekServed", "weeklyClaimed", "showcaseWeek", "votes", "favorites", "homeLikes", "homeRatingSum", "homeRatingN"}
local function metaKey(plr) return "u" .. plr.UserId .. "_meta" end
local function slotKey(plr, slot) return "u" .. plr.UserId .. "_s" .. slot end
local DEFAULT_SETTINGS = {music = true, musicVol = 5, sfx = true, crowd = "high", weather = true, units = "MPH", spawnAt = "business"}
-- every setting has a validator, so a client can't store junk (NaN, huge numbers, unknown words) in the save
local function oneOf(...)
	local ok = {}
	for _, v in ipairs({...}) do ok[v] = true end
	return function(v) return ok[v] == true end
end
local function isBool(v) return type(v) == "boolean" end
local SETTING_OK = {
	music = isBool, sfx = isBool, weather = isBool,
	musicVol = function(v) return C.int(v, 1, 10) ~= nil end,
	crowd = oneOf("high", "low", "off"), units = oneOf("MPH", "KMH"), spawnAt = oneOf("business", "home"),
}
local function applySettings(target, incoming)
	if type(incoming) ~= "table" then return end
	for k, v in pairs(incoming) do
		local ok = SETTING_OK[k]
		if ok and ok(v) then target[k] = v end
	end
end

-- DataStore reads are retried a few times; `nil, true` means the read really failed
local function readKey(key)
	for attempt = 1, CFG.LOAD_RETRIES do
		local ok, v = pcall(function() return store:GetAsync(key) end)
		if ok then return v, false end
		warn("[CornerEmpire] load attempt " .. attempt .. " failed for " .. key .. ": " .. tostring(v))
		if attempt < CFG.LOAD_RETRIES then task.wait(attempt * 1.5) end
	end
	return nil, true
end

local function loadMeta(plr)
	local meta = {slots = {}, settings = table.clone(DEFAULT_SETTINGS)}
	if not store then return meta, false end
	local saved, failed = readKey(metaKey(plr))
	if failed then return meta, true end
	if type(saved) == "table" then
		meta.slots = type(saved.slots) == "table" and saved.slots or {}
		applySettings(meta.settings, saved.settings)
	end
	return meta, false
end
local function saveMeta(plr)
	local s = session[plr]
	if not store or not s or s.metaFail then return end
	pcall(function() store:SetAsync(metaKey(plr), {slots = s.meta.slots, settings = s.meta.settings}) end)
end
local function serializeProps(d)
	local out = {}
	for _, b in ipairs(d.props) do
		local units = {}
		for i, t in ipairs(b.units) do units[i] = t or false end
		table.insert(out, {lot = b.lot, type = b.type, units = units, condition = b.condition, applicants = b.applicants, level = b.level, invested = b.invested})
	end
	return out
end
function F.save(plr)
	local d = data[plr]
	local s = session[plr]
	if not store or not d or not s or d.noSave then return end
	if F.publishWeekly then pcall(F.publishWeekly, plr, d) end
	local payload = {lots = {}, props = serializeProps(d)}
	for _, k in ipairs(SAVE_KEYS) do payload[k] = d[k] end
	payload.cash = math.floor(d.cash)
	for id in pairs(d.lots) do table.insert(payload.lots, id) end
	pcall(function() store:SetAsync(slotKey(plr, s.slot), payload) end)
	local hood = F.homeHood(d)
	s.meta.slots["s" .. s.slot] = {cash = math.floor(d.cash), tier = REP_TIERS[F.tierIndex(d.rep)].name, rebirths = d.rebirths,
		income = math.floor(F.incomePerSec(d)), home = hood and HOOD[hood].name or "Homeless", played = os.time()}
	saveMeta(plr)
end
local function loadSlot(plr, d, slot)
	if not store then return end
	local saved, failed = readKey(slotKey(plr, slot))
	if failed then
		-- never overwrite a save we couldn't read: this whole session stays unsaved
		d.noSave = true
		return
	end
	if type(saved) ~= "table" then return end
	for _, k in ipairs(SAVE_KEYS) do
		if saved[k] ~= nil then d[k] = saved[k] end
	end
	-- saves from before tutorial rewards were tracked: treat the steps already walked as paid
	if saved.tutPaid == nil then
		local tut = tonumber(saved.tut) or 1
		d.tutPaid = (tut == 0) and #TUTORIAL or math.max(0, tut - 1)
	end
	d.seen.stages = d.seen.stages or {}
	d.seen.events = d.seen.events or {}
	d.seen.roles = d.seen.roles or {}
	d.savedLots = saved.lots or {}
	if type(saved.props) == "table" then
		for _, b in ipairs(saved.props) do
			if RENTAL[b.type] then
				local level = C.rentalLevelOf(b)
				local units = {}
				for i = 1, F.rentalUnits(b.type, level) do units[i] = (type(b.units) == "table" and b.units[i]) or false end
				table.insert(d.props, {lot = b.lot or 0, type = b.type, units = units, condition = b.condition or 100, applicants = b.applicants or {}, events = {},
					level = level, invested = tonumber(b.invested) or RENTAL[b.type].cost})
			end
		end
	end
end

-- =====================================================================
-- PLAYER DATA
-- =====================================================================
local function newData(plot)
	local now = os.clock()
	return {
		cash = CFG.START_CASH, earned = 0, levels = {}, chains = {}, staff = {}, cands = {},
		combos = {}, rep = 0, ep = 0, trophies = 0, skin = "classic", passes = {}, cars = {},
		shares = {}, company = {price = 10, hist = {10}, crashF = 1}, lots = {},
		problems = {}, immune = {}, reviews = {}, revSum = 0, revN = 0, served = 0, deliveries = 0, contributed = 0,
		seen = {stages = {}, events = {}, roles = {}},
		war = {earned = 0, customers = 0, rep = 0, stars = 0, starsN = 0},
		frozenUntil = 0, sabCooldown = 0, buffUntil = 0, buffWins = 0, adUntil = 0, adKey = "small", trendUntil = 0, relaxedUntil = 0,
		marketing = false, custAcc = 0, nextProblem = now + 90, nextDelivery = now + 45,
		rebirths = 0, followers = 0, home = nil, props = {}, inbox = {}, raceBest = nil, tut = 1, rentEarned = 0,
		plot = plot,
	}
end

local function archiveData(plr, d)
	local owned, landmarks, stages, roles, events, cars = 0, 0, 0, 0, 0, 0
	for _, b in ipairs(BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 then owned += 1 end
		if stageOf(lvl, d.chains[b.key] or 0) == 6 then landmarks += 1 end
	end
	for _ in pairs(d.seen.stages) do stages += 1 end
	for _ in pairs(d.seen.roles) do roles += 1 end
	for _ in pairs(d.seen.events) do events += 1 end
	for _, c in ipairs(CARS) do
		if F.ownsCar(plr, c) then cars += 1 end
	end
	local found, combos = 0, {}
	for _, c in ipairs(COMBOS) do
		local got = d.combos[c.key] == true
		if got then found += 1 end
		local recipe
		if c.rare then
			-- rare secrets never reveal their requirements: only a riddle until you unlock them
			table.insert(combos, {icon = got and c.icon or "🗝️", name = got and c.name or "Rare Secret", recipe = got and (c.perkText or "") or c.riddle, found = got, color = c.color})
			continue
		end
		if got then
			local names = {}
			for _, n in ipairs(c.needs) do table.insert(names, BIZ[n].name) end
			recipe = table.concat(names, " + ")
		elseif c.secret then
			recipe = "??? + ???" .. (c.hint and ("  (" .. c.hint .. ")") or "")
		else
			recipe = BIZ[c.needs[1]].icon .. " " .. BIZ[c.needs[1]].name .. " + ???"
		end
		table.insert(combos, {icon = got and c.icon or "❓", name = got and c.name or (c.secret and "Secret Business" or "Undiscovered"), recipe = recipe, found = got, color = c.color})
	end
	local districtsOwned = 0
	for _, dd in ipairs(DISTRICTS) do
		if F.countLots(d, dd.key) > 0 then districtsOwned += 1 end
	end
	local skins = {}
	for _, s in ipairs(SKINS) do
		local unlocked = d.trophies >= s.trophies and (not s.era or (d.eraContrib or 1) >= s.era)
		table.insert(skins, {key = s.key, name = s.name, need = s.trophies, era = s.era, unlocked = unlocked, equipped = d.skin == s.key, color = s.color or d.plot.color})
	end
	return {
		rows = {
			{"🏪 Businesses", owned, #BUSINESSES}, {"🏗️ Buildings", stages, #BUSINESSES * 6}, {"👥 Employees", roles, #STAFF_ORDER},
			{"🌦️ Events", events, #EVENTS}, {"✨ Discoveries", found, #COMBOS}, {"🌟 Landmarks", landmarks, #BUSINESSES},
			{"🗺️ Districts", districtsOwned, #DISTRICTS}, {"🚗 Vehicles", cars, #CARS},
		},
		combos = combos, skins = skins,
	}
end

local function homeState(d)
	local lot = F.homeLot(d)
	local hoods = {}
	for _, h in ipairs(HOODS) do
		local free = 0
		for _, l in ipairs(C.HOME_LOTS) do
			if l.hood == h.key and not l.owner then free += 1 end
		end
		table.insert(hoods, {key = h.key, name = h.name, icon = h.icon, price = h.price, tierName = REP_TIERS[h.tier].name,
			unlocked = F.tierIndex(d.rep) >= h.tier, perk = h.perk, free = free, color = h.color, mine = lot ~= nil and lot.hood == h.key})
	end
	local home
	if lot then
		local h = HOOD[lot.hood]
		home = {hood = h.name, icon = h.icon, level = d.home.level, levelName = d.home.level > 0 and HOME_LEVELS[d.home.level] or "Empty lot",
			max = #HOME_LEVELS, cost = F.homeBuildCost(d), bonus = math.floor((F.homeMult(d) - 1) * 100 + 0.5), perk = h.perk, color = h.color,
			nextName = HOME_LEVELS[d.home.level + 1]}
	end
	return {home = home, hoods = hoods}
end
local function propsState(plr, d)
	local list = {}
	for bi, b in ipairs(d.props) do
		local T = RENTAL[b.type]
		local units = {}
		for ui = 1, #b.units do
			local t = b.units[ui]
			local mood = t and (tonumber(t.mood) or 70) or 0
			units[ui] = {unit = C.unitName(ui), tenant = t and {name = t.name, emoji = t.emoji, job = t.job, trait = TENANT.traits[t.trait].icon .. " " .. TENANT.traits[t.trait].name,
				credit = t.credit, strikes = t.strikes or 0, mood = math.floor(mood), moodIcon = C.moodEmoji(mood), owes = t.owes} or false}
		end
		local apps = {}
		for ai, a in ipairs(b.applicants) do
			apps[ai] = {name = a.name, emoji = a.emoji, job = a.job, trait = TENANT.traits[a.trait].icon .. " " .. TENANT.traits[a.trait].name, credit = a.credit}
		end
		local lvl = C.rentalLevelOf(b)
		local nxt = C.RENTAL_LEVELS[lvl + 1]
		table.insert(list, {bi = bi, name = T.name, lot = b.lot, condition = math.floor(b.condition), units = units, applicants = apps,
			rent = F.rentalRent(b), renovate = F.rentalRenovateCost(b), sell = F.rentalSellPrice(b), offsite = b.lot == 0,
			level = lvl, maxLevel = #C.RENTAL_LEVELS, levelName = C.RENTAL_LEVELS[lvl].name, value = F.rentalValue(b), upkeep = F.rentalUpkeep(b),
			upgradeCost = F.rentalUpgradeCost(b), nextName = nxt and nxt.name or nil,
			nextUnits = nxt and F.rentalUnits(b.type, lvl + 1) or nil, nextRent = nxt and math.floor(F.rentPerUnit(b.type) * nxt.rent) or nil})
	end
	local free = {}
	for _, l in ipairs(C.RENT_LOTS) do
		if not l.owner then table.insert(free, l.id) end
	end
	return {list = list, free = free, unlocked = F.unlocked(d, "properties"), earned = d.rentEarned or 0}
end

-- Big, slow-changing parts of the state are only sent when they change (the client keeps the last copy).
-- Keep this list in sync with HEAVY in EmpireClient.
local HEAVY = {"archive", "homeInfo", "props", "districts", "market", "staff", "reviews", "tours", "shareable", "standings", "passes", "cars", "showcase", "biz", "warLeaders",
	"rebirth", "unlocks", "fees", "spire"}
local function sig(v)
	local t = type(v)
	if t == "table" then
		local keys = {}
		for k in pairs(v) do table.insert(keys, k) end
		table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
		local parts = table.create(#keys)
		for i, k in ipairs(keys) do parts[i] = tostring(k) .. "=" .. sig(v[k]) end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "number" then
		return string.format("%.6g", v)
	end
	return tostring(v)
end

-- where photo mode's cinematic shots point: your plot, your home, and your biggest business
function F.showcasePoints(d)
	local best, bestLvl = nil, 0
	for _, b in ipairs(BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > bestLvl then best, bestLvl = b.key, lvl end
	end
	local hl = F.homeLot(d)
	return {plot = d.plot.center + V3(0, 1, 0), home = hl and hl.pos or nil, best = best and (F.slotCF(d.plot, best) * CF(0, 4, 0)).Position or nil}
end
function F.sendState(plr, now)
	local d = data[plr]
	if not d then return end
	local inc, per, gm = F.income(d, now)
	local tier = F.tierIndex(d.rep)
	local biz = {}
	for _, b in ipairs(BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		local ch = d.chains[b.key] or 0
		local st = stageOf(lvl, ch)
		local s = d.staff[b.key]
		biz[b.index] = {
			key = b.key, icon = b.icon, color = b.color, level = lvl, stage = st,
			name = b.tiers[math.max(st, 1)], income = per[b.key] or 0, unit = b.income,
			cost = lvl < CFG.MAX_LEVEL and F.upgradeCost(d, b.key) or -1,
			chains = ch, chainCost = (lvl >= CFG.MAX_LEVEL and F.unlocked(d, "chains")) and F.chainCost(d, b.key) or nil,
			chainName = CHAINS[ch + 1] and CHAINS[ch + 1].name or nil,
			problem = d.problems[b.key] ~= nil, staffStars = s and staffStars(s) or 0,
			locked = tier < b.unlock, unlockName = REP_TIERS[b.unlock].name,
		}
	end
	local standings = {}
	for p, od in pairs(data) do
		table.insert(standings, {name = p.Name, userId = p.UserId, color = od.plot.color, tier = REP_TIERS[F.tierIndex(od.rep)].name,
			income = (F.income(od, now)), rebirths = od.rebirths})
	end
	table.sort(standings, function(x, y) return x.income > y.income end)
	local market, portfolio = {}, 0
	for p, od in pairs(data) do
		local c = od.company
		local mine = d.shares[p.UserId] or 0
		portfolio += mine * c.price
		table.insert(market, {userId = p.UserId, name = p.Name, ticker = string.upper(string.sub(p.Name, 1, 4)), price = c.price, first = c.hist[1], hist = c.hist, mine = mine, color = od.plot.color})
	end
	local staff = {}
	for _, slot in ipairs(STAFF_ORDER) do
		local s = d.staff[slot]
		staff[slot] = {hired = s ~= nil, name = s and s.name, service = s and s.service, speed = s and s.speed, exp = s and s.exp,
			trainCost = (s and s.exp < 5) and F.trainCost(slot, s) or nil, hireCost = F.hireCost(slot), locked = BIZ[slot] ~= nil and (d.levels[slot] or 0) <= 0}
	end
	local problems = {}
	for key, pr in pairs(d.problems) do
		table.insert(problems, {key = key, biz = BIZ[key].name, icon = PROBLEMS[pr.type].icon, text = PROBLEMS[pr.type].text,
			repair = pr.repair, replace = pr.replace, state = pr.state, left = pr.untilT and math.max(0, math.ceil(pr.untilT - now)) or nil})
	end
	local dl
	if d.delivery then
		local dest = DESTS[d.delivery.dest]
		local b = BIZ[d.delivery.biz]
		dl = {state = d.delivery.state, text = b.icon .. " " .. d.delivery.qty .. " " .. b.thing .. "  →  " .. dest.icon .. " " .. dest.name,
			reward = d.delivery.reward, left = math.max(0, math.ceil(d.delivery.expires - now)), pos = dest.pos}
	end
	local districts = {}
	for _, dd in ipairs(DISTRICTS) do
		local total, sold, mine = 0, 0, 0
		for _, lot in ipairs(LOTS) do
			if lot.dkey == dd.key then
				total += 1
				if lot.owner then sold += 1 end
				if lot.owner == plr then mine += 1 end
			end
		end
		table.insert(districts, {key = dd.key, name = dd.name, icon = dd.icon, tierName = REP_TIERS[dd.tier].name, unlocked = tier >= dd.tier,
			cost = dd.cost, income = dd.income, boost = dd.boostText, total = total, sold = sold, mine = mine, color = dd.color})
	end
	local sName, sGoal = F.spireGoal()
	local topName, topAmt = "—", 0
	for n, amt in pairs(G.spire.top) do
		if amt > topAmt then topName, topAmt = n, amt end
	end
	local leaders = {}
	for _, l in ipairs(F.warLeaders()) do table.insert(leaders, {cat = l.cat, name = l.name, value = l.value}) end
	local unlocks = {}
	for k, t in pairs(FEATURES) do unlocks[k] = tier >= t end
	local perks = {}
	for _, p in ipairs(REBIRTH.perks) do table.insert(perks, {at = p.at, name = p.name, icon = p.icon, desc = p.desc, got = d.rebirths >= p.at}) end
	local tut
	if d.tut and d.tut > 0 and TUTORIAL[d.tut] then
		tut = {step = d.tut, total = #TUTORIAL, text = TUTORIAL[d.tut].text, target = F.tutorialTarget(d)}
	end
	local lotsMine = F.countLots(d)
	local car = F.activeCar(plr)
	local st = {
		cash = d.cash, income = inc, passMult = F.passMult(d), gm = gm,
		frozen = math.max(0, math.ceil(d.frozenUntil - now)),
		sabCd = math.max(0, math.ceil(d.sabCooldown - now)), sabCost = CFG.SABOTAGE_COST, sabTime = CFG.SABOTAGE_TIME,
		rep = d.rep, tier = tier, tierName = REP_TIERS[tier].name, prevRep = REP_TIERS[tier].rep,
		nextRep = REP_TIERS[tier + 1] and REP_TIERS[tier + 1].rep or nil, nextName = REP_TIERS[tier + 1] and REP_TIERS[tier + 1].name or nil,
		nextUnlocks = REP_TIERS[tier + 1] and REP_TIERS[tier + 1].unlocks or nil,
		ep = d.ep, trophies = d.trophies, stars = d.revN > 0 and d.revSum / d.revN or 0, served = d.served,
		lotsMine = lotsMine, cityPct = lotsMine / #LOTS * 100,
		eventText = G.eventText or "Markets are calm.", eventLeft = G.event and math.max(0, math.ceil(G.eventEnds - now)) or nil,
		nextEvent = math.max(0, math.ceil(G.nextEvent - now)), crash = (G.event and G.event.crash) and true or false,
		warLeft = math.max(0, math.ceil(G.warEnds - now)), warLeaders = leaders,
		buffMult = d.buffUntil > now and (1 + 0.2 * d.buffWins) or nil, buffLeft = math.max(0, math.ceil(d.buffUntil - now)),
		adName = d.adUntil > now and ADS_BY[d.adKey].name or nil, adLeft = math.max(0, math.ceil(d.adUntil - now)),
		relaxedLeft = math.max(0, math.ceil((d.relaxedUntil or 0) - now)),
		trending = d.trendUntil > now,
		biz = biz, standings = standings, market = market, portfolio = portfolio, staff = staff,
		problems = problems, delivery = dl, archive = archiveData(plr, d), districts = districts,
		spire = {era = G.spire.era, eraName = C.eraName(G.spire.era), name = sName, progress = G.spire.progress, goal = sGoal, top = topName},
		mega = C.megaState and C.megaState() or nil,
		reviews = d.reviews, passes = d.passes, cars = d.cars, rebirthsOwned = d.rebirths,
		activeCar = car and car.key or false,
		maxLevel = CFG.MAX_LEVEL, unlocks = unlocks, followers = d.followers,
		homeInfo = homeState(d), props = propsState(plr, d),
		rebirth = {count = d.rebirths, cost = F.rebirthCost(d), mult = math.floor((F.rebirthMult(d) - 1) * 100 + 0.5), perks = perks, unlocked = unlocks.rebirth},
		tut = tut, raceBest = d.raceBest,
		showcase = F.showcasePoints(d), tours = F.toursList(), mysterySite = C.mysterySite and C.mysterySite() or nil,
		mysteryPrice = C.mysterySite and C.mysterySite() and F.mysteryPrice(d) or nil,
		shareable = C.shareableList(d), viralLeft = math.max(0, math.ceil((d.viralUntil or 0) - now)),
		postBuffLeft = math.max(0, math.ceil((d.postBuffUntil or 0) - now)), postBuffMult = d.postBuffMult,
		fees = {hoop = F.funFee(d, MINIGAMES.hoop.fee), rush = F.funFee(d, MINIGAMES.rush.fee), memory = F.funFee(d, MINIGAMES.memory.fee),
			ferris = F.funFee(d, FERRIS.fee), fireworks = F.funFee(d, FIREWORKS.fee), race = F.raceFee(d)},
		slot = session[plr] and session[plr].slot,
	}
	-- only send the heavy sections that changed since the last packet
	local sess = session[plr]
	if sess then
		sess.sent = sess.sent or {}
		for _, k in ipairs(HEAVY) do
			local v = st[k]
			if v ~= nil then
				local g = sig(v)
				if sess.sent[k] == g then st[k] = nil else sess.sent[k] = g end
			end
		end
	end
	R.State:FireClient(plr, st)
end

function F.refreshAll(plr)
	local d = data[plr]
	if not d then return end
	for _, b in ipairs(BUSINESSES) do F.refreshBuilding(plr, b.key, false) end
	F.refreshTower(plr, true)
	for _, lot in ipairs(LOTS) do
		if lot.owner == plr then F.buildLot(lot) end
	end
	local hl = F.homeLot(d)
	if hl then F.buildHome(hl) end
end

-- =====================================================================
-- CHARACTER
-- =====================================================================
function F.applyCharacter(plr, char)
	local d = data[plr]
	if not (d and char) then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hum then hum.WalkSpeed = F.hasPass(plr, "nitro") and 24 or 18 end
	local head = char:FindFirstChild("Head")
	if head then
		local old = head:FindFirstChild("EmpireTag")
		if old then old:Destroy() end
		local line2 = REP_TIERS[F.tierIndex(d.rep)].name
		if d.rebirths > 0 then line2 = "♻️" .. d.rebirths .. "  " .. line2 end
		local tagColor = d.rebirths >= 100 and RGB(255, 205, 60) or (d.passes.vip and RGB(255, 215, 90) or RGB(220, 220, 230))
		local bb = C.billboard(head, UDim2.fromOffset(200, 44), V3(0, 2.6, 0), {
			{text = (d.passes.vip and "👑 VIP " or "") .. plr.Name, h = 0.55, color = tagColor}, {text = line2, h = 0.45, font = Enum.Font.GothamBold, color = d.plot.color}}, 80)
		bb.Name = "EmpireTag"
	end
	if hrp then
		local aura = hrp:FindFirstChild("LegendAura")
		if aura then aura:Destroy() end
		if d.rebirths >= 100 then
			local e = C.sparkle(hrp, RGB(255, 210, 80), 14)
			e.Name = "LegendAura"
		end
	end
end
local function spawnCF(plr, d)
	local s = session[plr]
	if s and s.meta.settings.spawnAt == "home" then
		local cf = F.homeSpawn(d)
		if cf then return cf end
	end
	return d.plot.spawn.CFrame + V3(0, 4, 0)
end

-- =====================================================================
-- START / LEAVE A SAVE
-- =====================================================================
local function freePlot()
	for _, p in ipairs(plots) do
		if not p.owner then return p end
	end
end
local function sendMenu(plr)
	local s = session[plr]
	if not s then return end
	local starters = {}
	for i, st in ipairs(STARTER_HOMES) do
		local h = HOOD[st.hood]
		starters[i] = {name = st.name, desc = st.desc, hood = h.name, icon = h.icon, color = h.color}
	end
	R.Menu:FireClient(plr, "mainmenu", {slots = s.meta.slots, settings = s.meta.settings, saving = store ~= nil and not s.metaFail,
		starters = starters, count = CFG.SAVE_SLOTS, studio = RunService:IsStudio()})
end

function F.startGame(plr, slot, starterIdx)
	local s = session[plr]
	if not s or data[plr] or s.busy then return end
	if type(slot) ~= "number" or slot < 1 or slot > CFG.SAVE_SLOTS then return end
	local plot = freePlot()
	if not plot then
		notify(plr, "No free plot right now — try again in a moment.")
		return
	end
	s.busy = true
	plot.owner = plr
	s.slot = slot
	local d = newData(plot)
	local isNew = starterIdx ~= nil
	if not isNew then loadSlot(plr, d, slot) end
	-- if the save list itself couldn't load we can't know what's in this slot, so don't save over it
	if s.metaFail then d.noSave = true end
	if not plr.Parent then
		plot.owner = nil
		return
	end
	data[plr] = d
	s.busy = false
	F.loadPasses(plr, d)
	F.claimRichStart(plr, d)
	-- business + land
	F.setPlotSign(plot, plr.Name .. "'s Empire", REP_TIERS[F.tierIndex(d.rep)].name)
	for _, b in ipairs(BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 then
			F.refreshBuilding(plr, b.key, false)
			d.seen.stages[b.key .. stageOf(lvl, d.chains[b.key] or 0)] = true
		end
	end
	F.refreshKiosks(plr)
	F.refreshTower(plr, true)
	F.refreshWorkers(plr)
	for _, id in ipairs(d.savedLots or {}) do
		local lot = LOTS[id]
		if lot and not lot.owner then
			lot.owner = plr
			d.lots[id] = true
			F.buildLot(lot)
		end
	end
	-- home
	if isNew then
		local st = STARTER_HOMES[starterIdx] or STARTER_HOMES[1]
		d.home = {lot = nil, level = 1}
		if not F.claimHome(plr, d, st.hood) then d.home = nil end
		if d.home then F.pushMsg(plr, {icon = "🏠", from = "Realtor", text = "Welcome to your new " .. st.name .. " in " .. HOOD[st.hood].name .. "! Upgrade it from the Home app."}) end
	elseif d.home and d.home.lot then
		local lot = C.HOME_LOTS[d.home.lot]
		local hoodKey = lot and lot.hood or "oldtown"
		if not F.claimHome(plr, d, hoodKey, d.home.lot) then
			d.home = nil
			F.pushMsg(plr, {icon = "🏠", from = "Realtor", text = "Your neighborhood was full, so you'll need to buy a new home."})
		end
	end
	-- rentals
	F.claimRentals(plr, d)
	-- legacy museum gallery, weekly rewards from last week, old votes cleaned up
	if C.pruneVotes then C.pruneVotes(d) end
	F.refreshMuseum(plr)
	if F.claimWeeklyRewards then task.spawn(F.claimWeeklyRewards, plr) end
	-- leaderstats
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = ls
		local tierV = Instance.new("StringValue")
		tierV.Name = "Reputation"
		tierV.Parent = ls
		ls.Parent = plr
	end
	F.pushMsg(plr, {icon = "👋", from = "Corner Empire", text = isNew and "Welcome! Follow the tutorial card at the bottom of your screen to get started." or "Welcome back! Your empire missed you."})
	R.Menu:FireClient(plr, "play")
	s.sent = {}   -- the next state packet after "play" is a full one
	if d.noSave then
		local warnText = "⚠️ Couldn't load your save. This session won't be saved — rejoin to try again."
		notify(plr, warnText)
		F.pushMsg(plr, {icon = "⚠️", from = "Save System", text = warnText .. " Your real save is safe and untouched."})
		task.delay(1.5, function()
			if data[plr] == d then R.Splash:FireClient(plr, "⚠️ SAVE NOT LOADED", warnText, RGB(255, 170, 60)) end
		end)
	end
	plr:LoadCharacter()
	F.buzz("👋", plr.Name .. " opened their corner! Welcome to the city.", plot.color)
end

local function settleStocks(plr, d)
	for p, od in pairs(data) do
		if p ~= plr then
			local mine = d.shares[p.UserId]
			local keep = 1 - CFG.STOCK_SELL_FEE
			if mine and mine > 0 then d.cash += mine * od.company.price * keep end
			local theirs = od.shares[plr.UserId]
			if theirs and theirs > 0 then
				local pay = theirs * d.company.price * keep
				od.cash += pay
				od.shares[plr.UserId] = nil
				notify(p, "📈 " .. plr.Name .. " left — your " .. theirs .. " shares were sold for $" .. fmt(pay))
			end
		end
	end
	d.shares = {}
end
function F.unload(plr, backToMenu)
	local d = data[plr]
	if not d then return end
	settleStocks(plr, d)
	F.save(plr)
	F.despawnCar(plr)
	F.cancelRace(plr, "")
	F.clearRentalTimers(plr)
	F.clearFun(plr)
	F.clearSocial(plr)
	for _, lot in ipairs(LOTS) do
		if lot.owner == plr then
			lot.owner = nil
			F.buildLot(lot)
		end
	end
	F.releaseHome(plr)
	F.releaseRentals(plr)
	local plot = d.plot
	for _, m in pairs(plot.slots) do m:Destroy() end
	plot.slots = {}
	for _, m in pairs(plot.kiosks) do m:Destroy() end
	plot.kiosks = {}
	if plot.tower then
		plot.tower:Destroy()
		plot.tower = nil
	end
	F.setIce(plot, false)
	F.clearWorkers(plot)
	if F.closeGallery then F.closeGallery(plot) end
	plot.owner = nil
	F.setPlotSign(plot, "Empty Plot", "")
	data[plr] = nil
	if backToMenu then
		if plr.Character then plr.Character:Destroy() end
		plr.Character = nil
		sendMenu(plr)
	end
end

-- =====================================================================
-- ACTIONS
-- =====================================================================
local TP = {
	dealer = CFrame.lookAt(V3(0, 4, -128), V3(0, 4, -160)),
	downtown = CFrame.lookAt(V3(150, 4, -12), V3(230, 4, -12)),
	industrial = CFrame.lookAt(V3(-150, 4, -12), V3(-230, 4, -12)),
	beach = CFrame.lookAt(V3(0, 4, 150), V3(0, 4, 230)),
	luxury = CFrame.lookAt(V3(230, 4, -140), V3(230, 4, -220)),
	spire = CFrame.lookAt(V3(0, 4, 24), V3(0, 4, 0)),
	funpark = CFrame.lookAt(V3(-360, 4, 12), V3(-470, 4, 12)),
	race = CFrame.lookAt(V3(0, 4, -318), V3(0, 4, -360)),
	rental = CFrame.lookAt(V3(345, 4, 12), V3(450, 4, 12)),
	oldtown = CFrame.lookAt(V3(-400, 4, 225), V3(-500, 4, 225)),
	suburbs = CFrame.lookAt(V3(-150, 4, 225), V3(-240, 4, 225)),
	ocean = CFrame.lookAt(V3(300, 4, 345), V3(340, 4, 380)),
	hills = CFrame.lookAt(V3(-230, 22, -212), V3(-230, 22, -180)),
	rich = CFrame.lookAt(V3(345, 4, -215), V3(450, 4, -215)),
}
local function teleport(plr, d, key)
	local cf = TP[key]
	if key == "business" then cf = d.plot.spawn.CFrame + V3(0, 4, 0) end
	if key == "museum" and C.MUSEUM_AT then cf = CFrame.lookAt(C.MUSEUM_AT + V3(0, 4, 60), C.MUSEUM_AT + V3(0, 4, 0)) end
	if key == "mystery" then
		local site = C.mysterySite and C.mysterySite()
		if not site then
			notify(plr, "❓ There's no Mystery Lot right now. Keep an eye on CityBuzz!")
			return
		end
		cf = CFrame.lookAt(site + V3(0, 4, 20), site + V3(0, 4, 0))
	end
	if key == "home" then
		cf = F.homeSpawn(d)
		if not cf then
			notify(plr, "You don't own a home yet!")
			return
		end
	end
	local char = plr.Character
	if cf and char then
		F.despawnCar(plr)
		char:PivotTo(cf)
	end
end

-- =====================================================================
-- INPUT VALIDATION + RATE LIMIT: nothing a client sends is trusted
-- =====================================================================
local int, str, finite = C.int, C.str, C.finite
-- true if a value (or anything inside a table) is NaN or infinite
local function poisoned(v, depth)
	if type(v) == "number" then return not finite(v) end
	if type(v) == "table" and (depth or 0) < 3 then
		for k, x in pairs(v) do
			if poisoned(k, (depth or 0) + 1) or poisoned(x, (depth or 0) + 1) then return true end
		end
	end
	return false
end
local buckets = {}
local function allow(plr, cost)
	local t = os.clock()
	local bk = buckets[plr]
	if not bk then
		bk = {tokens = CFG.ACTION_BURST, t = t}
		buckets[plr] = bk
	end
	bk.tokens = math.min(CFG.ACTION_BURST, bk.tokens + (t - bk.t) * CFG.ACTION_RATE)
	bk.t = t
	if bk.tokens < (cost or 1) then return false end
	bk.tokens -= (cost or 1)
	return true
end
C.allowAction = allow
local CONTRIB = {k1 = true, k10 = true, p10 = true, p50 = true}
local PROBLEM_CHOICE = {repair = true, replace = true, ignore = true}
local TUT_ACTIONS = {phone = true, skip = true, restart = true}
C.ACTIONS = {}  -- other modules can add validated actions: C.ACTIONS[name] = function(plr, d, a, b, c, now) end

R.Action.OnServerEvent:Connect(function(plr, action, a, b, c)
	if type(action) ~= "string" or #action > 24 then return end
	local s = session[plr]
	if not s then return end
	if poisoned(a) or poisoned(b) or poisoned(c) then return end
	if not allow(plr) then return end
	-- menu actions (no save loaded yet)
	if action == "menuPlay" then
		local slot = int(a, 1, CFG.SAVE_SLOTS)
		if slot then F.startGame(plr, slot, nil) end
		return
	elseif action == "menuNew" then
		local slot = int(a, 1, CFG.SAVE_SLOTS)
		if not slot or data[plr] or s.busy then return end
		local starter = int(b, 1, #STARTER_HOMES) or 1
		s.meta.slots["s" .. slot] = nil
		F.startGame(plr, slot, starter)
		return
	elseif action == "menuDelete" then
		local slot = int(a, 1, CFG.SAVE_SLOTS)
		if not slot or data[plr] or s.metaFail then return end
		s.meta.slots["s" .. slot] = nil
		if store then pcall(function() store:RemoveAsync(slotKey(plr, slot)) end) end
		saveMeta(plr)
		sendMenu(plr)
		return
	elseif action == "menuExit" then
		F.unload(plr, true)
		return
	elseif action == "settings" then
		applySettings(s.meta.settings, a)
		return
	end
	local d = data[plr]
	if not d then return end
	local now = os.clock()
	if action == "buy" then
		if BIZ[a] then F.buyUpgrade(plr, d, a) end
	elseif action == "chain" then
		if BIZ[a] then F.openChain(plr, d, a) end
	elseif action == "sabotage" then
		local target = int(a, 1)
		if target and target ~= plr.UserId then F.sabotage(plr, d, target, now) end
	elseif action == "candidates" and STAFF_ROLES[a] then
		if not F.unlocked(d, "staff") then
			notify(plr, "🔒 Staff unlocks at " .. REP_TIERS[FEATURES.staff].name)
			return
		end
		if BIZ[a] and (d.levels[a] or 0) <= 0 then
			notify(plr, "Open that business first!")
			return
		end
		R.Menu:FireClient(plr, "candidates", a, F.candidates(d, a), F.hireCost(a))
	elseif action == "hire" and STAFF_ROLES[a] then
		local pick = int(b, 1, 3)
		local cand = pick and d.cands[a] and d.cands[a][pick]
		if not cand or not F.unlocked(d, "staff") then return end
		local cost = F.hireCost(a)
		if d.cash < cost then
			notify(plr, "You need $" .. fmt(cost) .. " to hire.")
			return
		end
		d.cash -= cost
		d.staff[a] = {name = cand.name, service = cand.service, speed = cand.speed, exp = cand.exp}
		d.cands[a] = nil
		d.seen.roles[a] = true
		notify(plr, "👋 Hired " .. cand.name .. " as your " .. STAFF_ROLES[a].role .. "!")
		R.Menu:FireClient(plr, "closeCandidates")
		if F.refreshWorkers then F.refreshWorkers(plr) end
	elseif action == "train" and STAFF_ROLES[a] and d.staff[a] then
		local st = d.staff[a]
		if st.exp >= 5 then return end
		local cost = F.trainCost(a, st)
		if d.cash < cost then
			notify(plr, "You need $" .. fmt(cost) .. " to train.")
			return
		end
		d.cash -= cost
		st.exp += 1
		notify(plr, "📚 " .. st.name .. " leveled up! Experience " .. st.exp .. "★")
		if F.refreshWorkers then F.refreshWorkers(plr) end
	elseif action == "fire" and STAFF_ROLES[a] and d.staff[a] then
		notify(plr, "👋 " .. d.staff[a].name .. " left the company.")
		d.staff[a] = nil
		if F.refreshWorkers then F.refreshWorkers(plr) end
	elseif action == "problem" then
		if BIZ[a] and PROBLEM_CHOICE[b] then F.resolveProblem(plr, d, a, b, now) end
	elseif action == "ad" then
		if str(a, 20) then F.runAd(plr, d, a, now) end
	elseif action == "stock" then
		local owner = int(a, 1)
		local qty = int(c, 0, CFG.MAX_SHARES_PER_ORDER)
		if owner and qty and (b == "buy" or b == "sell") then F.tradeStock(plr, d, owner, b, qty) end
	elseif action == "delivery" then
		if d.delivery and d.delivery.state == "offer" then
			if a == "accept" then
				d.delivery.state = "active"
				d.delivery.expires = now + 180
				notify(plr, "🚚 Delivery accepted! Follow the green beam. A Delivery Van pays 1.5x.")
			elseif a == "decline" then
				d.delivery = nil
			end
		end
	elseif action == "contribute" then
		if CONTRIB[a] then
			local amt = ({k1 = 1000, k10 = 10000, p10 = d.cash * 0.1, p50 = d.cash * 0.5})[a]
			F.contribute(plr, amt)
		end
	elseif action == "skin" then
		if str(a, 20) then
			for _, sk in ipairs(SKINS) do
				if sk.key == a and d.trophies >= sk.trophies and (not sk.era or (d.eraContrib or 1) >= sk.era) then
					d.skin = a
					F.refreshAll(plr)
					notify(plr, "🎨 Equipped skin: " .. sk.name)
				end
			end
		end
	elseif action == "pass" then
		if str(a, 20) then F.promptPass(plr, a) end
	elseif action == "car" then
		if a == "spawn" and str(b, 20) and CAR[b] then
			F.buyOrDrive(plr, b)
		elseif a == "despawn" then
			F.despawnCar(plr)
		end
	elseif action == "tp" then
		if str(a, 20) then teleport(plr, d, a) end
	elseif action == "homeBuild" then
		F.buildHomeLevel(plr)
	elseif action == "propBuy" then
		local lot = int(a, 1, #C.RENT_LOTS)
		if lot and str(b, 20) then F.propBuy(plr, lot, b) end
	elseif action == "tenantAccept" or action == "tenantReject" or action == "evict" then
		local bi, i = int(a, 1, #d.props), int(b, 1, 64)
		if bi and i then
			if action == "tenantAccept" then F.tenantAccept(plr, bi, i)
			elseif action == "tenantReject" then F.tenantReject(plr, bi, i)
			else F.evict(plr, bi, i) end
		end
	elseif action == "renovate" or action == "propSell" or action == "propUpgrade" then
		local bi = int(a, 1, #d.props)
		if bi then
			if action == "renovate" then F.renovate(plr, bi)
			elseif action == "propUpgrade" then F.upgradeRental(plr, bi)
			else F.sellProp(plr, bi) end
		end
	elseif action == "minigame" then
		if str(a, 20) and finite(b) then F.finishMinigame(plr, a, b) end
	elseif action == "like" then
		local id = int(a, 1)
		if id then F.like(plr, id) end
	elseif action == "post" then
		local preset = int(a, 1, 50)
		if preset then F.playerPost(plr, preset, nil)
		elseif str(b, 200) then F.playerPost(plr, nil, b) end
	elseif action == "msgChoice" then
		local id, choice = int(a, 1), int(b, 1, 3)
		if id and choice then F.msgChoice(plr, id, choice) end
	elseif action == "rebirth" then
		F.rebirth(plr)
	elseif action == "tut" then
		if not TUT_ACTIONS[a] then return end
		if a == "phone" then
			F.tutorialEvent(plr, "phone")
		elseif a == "skip" then
			d.tut = 0
			notify(plr, "Tutorial skipped. You can always ask around the city! 😉")
		elseif a == "restart" then
			d.tut = 1
			notify(plr, "🎓 Tutorial restarted. (Rewards are only paid once per save.)")
		end
	elseif action == "raceCancel" then
		F.cancelRace(plr, "Race cancelled.")
	elseif action == "debug" then
		-- Studio-only test tools: never available in a live server
		if not RunService:IsStudio() or not str(a, 20) then return end
		if a == "cash" then
			d.cash += 1e6
		elseif a == "rep" then
			local t = F.tierIndex(d.rep)
			local nxt = REP_TIERS[t + 1]
			F.addRep(plr, nxt and (nxt.rep - d.rep) or 1000)
		elseif a == "mega" then
			F.startMega(str(b, 20))
		elseif a == "mystery" then
			F.spawnMysteryLot()
		elseif a == "spire" then
			local _, goal = F.spireGoal()
			d.cash += goal
			F.contribute(plr, goal)
		elseif a == "viral" then
			local best, lvl = nil, 0
			for _, bz in ipairs(BUSINESSES) do
				if (d.levels[bz.key] or 0) > lvl then best, lvl = bz.key, d.levels[bz.key] end
			end
			if best then F.goViral(plr, d, best, "Studio test: this place is AMAZING") end
		elseif a == "save" then
			F.save(plr)
			notify(plr, "💾 Saved.")
		end
	elseif action == "shareAch" then
		if str(a, 30) then F.shareAchievement(plr, a) end
	elseif action == "showcaseSubmit" then
		F.showcaseSubmit(plr)
	elseif action == "showcaseLike" then
		local id = int(a, 1)
		if id then F.showcaseLike(plr, id) end
	elseif action == "tourVisit" then
		local id = int(a, 1)
		if id then F.tourVisit(plr, id) end
	elseif action == "tourVote" then
		local id = int(a, 1)
		if id and (b == "like" or b == "fav") then F.tourVote(plr, id, b)
		elseif id and b == "rate" and int(c, 1, 5) then F.tourVote(plr, id, "rate", c) end
	elseif C.ACTIONS[action] then
		C.ACTIONS[action](plr, d, a, b, c, now)
	end
end)

-- static info the client needs once
do
	local GetCatalog = Instance.new("RemoteFunction")
	GetCatalog.Name = "GetCatalog"
	GetCatalog.Parent = ReplicatedStorage
	GetCatalog.OnServerInvoke = function(plr, what)
		if not allow(plr, 3) then return nil end
		if what == "feed" then return F.feedList() end
		if what == "weekly" then return F.weeklyInfo(plr) end
		if what == "inbox" then
			local d = data[plr]
			return d and F.inboxList(d) or {}
		end
		local cars, passes, staff, ads, npcs, rentals, features = {}, {}, {}, {}, {}, {}, {}
		for _, c in ipairs(CARS) do
			table.insert(cars, {key = c.key, name = c.name, price = c.price or 0, speed = c.speed, pass = c.pass, rebirths = c.rebirths, color = c.color, delivery = c.delivery})
		end
		for _, p in ipairs(PASSES) do table.insert(passes, {key = p.key, name = p.name, price = p.price, icon = p.icon, desc = p.desc}) end
		for _, slot in ipairs(STAFF_ORDER) do
			local r = STAFF_ROLES[slot]
			table.insert(staff, {slot = slot, role = r.role, icon = r.icon, desc = r.desc or ("Boosts your " .. BIZ[slot].name .. " (+4% per star)")})
		end
		for _, a in ipairs(ADS) do table.insert(ads, {key = a.key, name = a.name, cost = a.cost, dur = a.dur, customers = a.customers}) end
		for _, t in ipairs(NPC_TYPES) do table.insert(npcs, {icon = t.icon, shirt = t.shirt, pants = t.pants, fancy = t.fancy}) end
		for _, r in ipairs(RENTALS) do table.insert(rentals, {key = r.key, name = r.name, units = r.units, cost = r.cost, rent = F.rentPerUnit(r.key)}) end
		for k, t in pairs(FEATURES) do features[k] = {tier = t, tierName = REP_TIERS[t].name, name = FEATURE_NAMES[k]} end
		local tiers = {}
		for i, t in ipairs(REP_TIERS) do tiers[i] = {name = t.name, rep = t.rep, unlocks = t.unlocks} end
		return {cars = cars, passes = passes, staff = staff, ads = ads, npcs = npcs, chains = #CHAINS, rentals = rentals,
			features = features, tiers = tiers, presets = C.PRESET_COUNT, minigames = MINIGAMES, homeLevels = HOME_LEVELS}
	end
end

-- =====================================================================
-- JOIN / LEAVE
-- =====================================================================
local function onPlayerAdded(plr)
	if #Players:GetPlayers() > CFG.MAX_PLAYERS then
		plr:Kick("Server full (max " .. CFG.MAX_PLAYERS .. " players).")
		return
	end
	local meta, fail = loadMeta(plr)
	session[plr] = {meta = meta, metaFail = fail, slot = nil}
	plr.CharacterAdded:Connect(function(char)
		local d = data[plr]
		if not d then return end
		local hrp = char:WaitForChild("HumanoidRootPart", 5)
		if hrp and data[plr] then char:PivotTo(spawnCF(plr, d)) end
		F.applyCharacter(plr, char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				task.delay(4, function()
					if data[plr] and plr.Parent and plr.Character == char then plr:LoadCharacter() end
				end)
			end)
		end
	end)
	task.wait(1)
	sendMenu(plr)
end
local function onPlayerRemoving(plr)
	F.unload(plr, false)
	if session[plr] then saveMeta(plr) end
	session[plr] = nil
	buckets[plr] = nil
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, p) end
-- the client asks for the menu again if it loaded late
R.Menu.OnServerEvent:Connect(function(plr, what)
	if what == "ready" and session[plr] and not data[plr] and allow(plr, 5) then sendMenu(plr) end
	-- the client is missing part of its state: send everything next time
	if what == "resync" and session[plr] and allow(plr, 5) then session[plr].sent = {} end
end)

-- build the world's for-sale signs, then trees last (after everything reserved its space)
for _, lot in ipairs(LOTS) do F.buildLot(lot) end
for _, lot in ipairs(C.HOME_LOTS) do F.buildHome(lot) end
F.scatterTrees()
Workspace:SetAttribute("Weather", "none")

game:BindToClose(function()
	for p in pairs(data) do F.save(p) end
	for p in pairs(session) do saveMeta(p) end
	task.wait(2)
end)

-- =====================================================================
-- MAIN LOOPS
-- =====================================================================
task.spawn(function()
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		local now = os.clock()
		if G.event and now >= G.eventEnds then F.endEvent() end
		if now >= G.nextEvent then F.startEvent(now) end
		if now >= G.warEnds then F.endWar(now) end
		if tick % 5 == 0 then F.updateStocks(now) end
		for plr, d in pairs(data) do
			local ok, err = pcall(function()
				if d.frozenUntil <= now then
					local inc = F.income(d, now)
					d.cash += inc
					d.earned += inc
					d.war.earned += inc
				end
				d.custAcc = math.min(5, d.custAcc + F.customerRate(d, now))
				local spawned = 0
				while d.custAcc >= 1 and spawned < 4 do
					d.custAcc -= 1
					spawned += 1
					F.spawnCustomer(plr, d, now)
				end
				for key, pr in pairs(d.problems) do
					if pr.state == "ignored" and now >= pr.untilT then
						d.problems[key] = nil
						F.problemVisual(plr, key, false)
						F.refreshWorkers(plr)
					end
				end
				if now >= d.nextProblem then
					d.nextProblem = now + math.random(60, 110)
					local active = 0
					for _ in pairs(d.problems) do active += 1 end
					if active < 2 and math.random() < F.problemChance(d) then F.makeProblem(plr, d, now) end
				end
				if tick % 5 == 0 then F.checkMilestones(plr, d) end
				F.deliveryTick(plr, d, now)
				F.rentalTick(plr, d, now)
				F.tutorialTick(plr, d)
				F.setIce(d.plot, d.frozenUntil > now)
				local ls = plr:FindFirstChild("leaderstats")
				if ls then
					ls.Cash.Value = math.min(2 ^ 53, math.floor(d.cash))
					ls.Reputation.Value = REP_TIERS[F.tierIndex(d.rep)].name
				end
				F.sendState(plr, now)
			end)
			if not ok then warn("[CornerEmpire] tick error for " .. plr.Name .. ": " .. tostring(err)) end
		end
		local sName, sGoal = F.spireGoal()
		F.setSpireBoard("Era " .. G.spire.era .. " " .. C.eraName(G.spire.era) .. " • " .. sName, "$" .. fmt(G.spire.progress) .. " / $" .. fmt(sGoal))
	end
end)
-- day / night
task.spawn(function()
	while true do
		task.wait(0.25)
		Lighting.ClockTime = (Lighting.ClockTime + CFG.DAY_SPEED) % 24
		local t = Lighting.ClockTime
		local night = t < 6.2 or t > 17.8
		for _, l in ipairs(C.LAMPS) do l.Enabled = night end
	end
end)
-- autosave
task.spawn(function()
	while true do
		task.wait(120)
		for p in pairs(data) do task.spawn(F.save, p) end
	end
end)
end
