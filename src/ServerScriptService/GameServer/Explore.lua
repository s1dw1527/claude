-- EXPLORE (v13): reasons to go out into the city.
--   GOLDEN CORNERS  30 small golden tokens tucked at street corners in every district and neighborhood. Walk or drive
--                   up to one to collect it (once per save). Every district's set, and all 30, pay a bonus.
--   PLACES          every place on the map (landmarks, business districts, neighborhoods) gives a small reward the
--                   first time you get there.
--   CITY JOBS       short side missions with real destinations: a courier run (pick up, drop off, beat the clock),
--                   a lost dog (find it, walk it home), a street clean-up (bag 5 piles of litter before time runs out).
--                   Three offers at a time, one active job.
-- Everything is checked HERE, on the server, from the player's real character position once a second. The client
-- only draws the tokens / dog / litter and the guide beam, and ASKS to take or drop a job. A teleport cancels the
-- active job (no warping to the drop-off). Rewards are a number of seconds of the player's own income, with a
-- floor for new players, so they matter early and stay fair late.
return function(C)
local Players = game:GetService("Players")
local V3, RGB = Vector3.new, Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify

local X = {
	cornerSecs = 45, cornerMin = 100, cornerRadius = 7,
	placeSecs = 30, placeMin = 75, placeRadius = {Landmark = 45, ["Business district"] = 80, Neighborhood = 80},
	setSecs = 120, setMin = 500,           -- a district's whole set
	allSecs = 900, allMin = 25000,         -- all 30
	offers = 4, refreshEvery = 480, cooldown = 15,
	jobs = {
		courier = {icon = "📦", name = "Courier run", secs = 90, min = 250, rep = 4},
		pet = {icon = "🐶", name = "Lost dog", secs = 75, min = 200, rep = 6},
		cleanup = {icon = "🧹", name = "Street clean-up", secs = 60, min = 150, rep = 5},
		catering = {icon = "🎂", name = "Catering order", secs = 120, min = 400, rep = 8},   -- v14: needs a food business
	},
	reach = 9,        -- how close counts as "there" for a job step
	petExpire = 360,
	cleanupTime = 150, cleanupSpread = 40, litter = 5,
}
C.EXPLORE = X

-- ===== the network (same tables the world was built from) =====
local ROAD_NAMES = {"Main St", "Central Ave", "North Ring", "South Ring", "West Ring", "East Ring", "West Ave", "East Ave",
	"North Rd", "South Rd", "Luxury Rd", "Millionaire Ln", "Maple Ln", "Raceway Dr"}
local roads = {}
for i, r in ipairs(C.ROADS) do roads[i] = {i = i, axis = r[1], c = r[2], a = r[3], b = r[4], w = r[5], cuts = r[6] or {}, name = ROAD_NAMES[i] or "a side street"} end
local function crossingName(r, x)
	for _, r2 in ipairs(roads) do
		if r2.axis ~= r.axis and math.abs(r2.c - x) < 0.5 and r2.a <= r.c + 0.5 and r2.b >= r.c - 0.5 then return r2.name end
	end
end
-- sidewalk corners: the end of each sidewalk segment next to a crossing, at the outer edge of the sidewalk
local corners = {}
for _, r in ipairs(roads) do
	for _, x in ipairs(r.cuts) do
		if x > r.a and x < r.b then
			local other = crossingName(r, x)
			for _, e in ipairs({-1, 1}) do
				for _, side in ipairs({-1, 1}) do
					local s = x + e * 16   -- (the traffic-light poles stand 11 studs out from the crossing)
					-- only where there IS sidewalk: inside the road's length and not in another crossing's gap
					local onWalk = s > r.a + 2 and s < r.b - 2
					for _, x2 in ipairs(r.cuts) do if x2 ~= x and math.abs(s - x2) < 13 then onWalk = false end end
					if onWalk then
						local perp = r.c + side * (r.w / 2 + 3.4)
						local pos = r.axis == "x" and V3(s, 1.4, perp) or V3(perp, 1.4, s)
						table.insert(corners, {pos = pos, road = r.name, other = other})
					end
				end
			end
		end
	end
end
-- sidewalk points anywhere (for job stops): a few per segment
local walkPts = {}
for _, r in ipairs(roads) do
	local s0 = r.a
	local cuts = {}
	for _, x in ipairs(r.cuts) do if x > r.a and x < r.b then table.insert(cuts, x) end end
	table.sort(cuts)
	table.insert(cuts, r.b + 11)
	for _, x in ipairs(cuts) do
		local s1, s2 = s0, x - 11
		if s2 - s1 > 16 then
			for k = 1, 3 do
				local s = s1 + (s2 - s1) * k / 4
				for _, side in ipairs({-1, 1}) do
					local perp = r.c + side * (r.w / 2 + 2)
					table.insert(walkPts, {pos = r.axis == "x" and V3(s, 0.3, perp) or V3(perp, 0.3, s), road = r.name})
				end
			end
		end
		s0 = x + 11
	end
end
X.walkPts = walkPts

-- ===== places and Golden Corners (built once from the map catalog) =====
local PLACES = {}
local CORNERS = {}
local ZONES = {}
local function buildCatalog()
	local cat = F.mapCatalog and F.mapCatalog() or (C.mapCatalog and C.mapCatalog())
	local seen = {}
	for _, p in ipairs(cat and cat.places or {}) do
		local key = (p.kind == "Neighborhood" and "hood_" or "") .. p.key
		if not seen[key] and p.at then
			seen[key] = true
			table.insert(PLACES, {key = key, name = p.name, icon = p.icon, kind = p.kind, pos = V3(p.at[1], 0, p.at[2]), radius = X.placeRadius[p.kind] or 60})
		end
	end
	-- Golden Corners: the corner nearest each district / neighborhood / landmark, a second one for the big districts,
	-- never two at the same corner
	local used = {}
	local function nearestCorner(pos, skip)
		local best, bd
		for i, c in ipairs(corners) do
			if not used[i] then
				local d = (V3(c.pos.X, 0, c.pos.Z) - pos).Magnitude
				if d > (skip or 0) and (not bd or d < bd) then best, bd = i, d end
			end
		end
		return best
	end
	for _, pl in ipairs(PLACES) do
		local zone = {key = pl.key, name = pl.name, icon = pl.icon, corners = {}}
		local want = pl.kind == "Business district" and 2 or 1
		for k = 1, want do
			local i = nearestCorner(pl.pos, k == 2 and 60 or 0)
			if i then
				used[i] = true
				local c = corners[i]
				local id = "gc" .. (#CORNERS + 1)
				table.insert(CORNERS, {id = id, pos = c.pos, zone = pl.key, zoneName = pl.name,
					hint = pl.icon .. " " .. pl.name .. ": on " .. c.road .. (c.other and (", near " .. c.other) or "")})
				table.insert(zone.corners, id)
			end
		end
		if #zone.corners > 0 then table.insert(ZONES, zone) end
	end
end
buildCatalog()
-- fill up to 30 with corners spread over the map (farthest from the ones we have)
while #CORNERS < 30 and #CORNERS < #corners do
	local best, bd
	for i, c in ipairs(corners) do
		local dmin = math.huge
		for _, g in ipairs(CORNERS) do dmin = math.min(dmin, (g.pos - c.pos).Magnitude) end
		if dmin > (bd or 0) then best, bd = i, dmin end
	end
	if not best then break end
	local c = corners[best]
	-- belongs to the zone it is closest to
	local zk, zd
	for _, pl in ipairs(PLACES) do
		local d = (V3(c.pos.X, 0, c.pos.Z) - pl.pos).Magnitude
		if not zd or d < zd then zk, zd = pl, d end
	end
	local id = "gc" .. (#CORNERS + 1)
	table.insert(CORNERS, {id = id, pos = c.pos, zone = zk and zk.key or "city", zoneName = zk and zk.name or "The city",
		hint = (zk and (zk.icon .. " " .. zk.name) or "🏙️ The city") .. ": on " .. c.road .. (c.other and (", near " .. c.other) or "")})
	for _, z in ipairs(ZONES) do if zk and z.key == zk.key then table.insert(z.corners, id) end end
end
local CORNER = {}
for _, g in ipairs(CORNERS) do CORNER[g.id] = g end
C.GOLDEN_CORNERS, C.EXPLORE_PLACES, C.EXPLORE_ZONES = CORNERS, PLACES, ZONES

-- ===== saved record =====
local function rec(d)
	if type(d.city) ~= "table" then d.city = {} end
	local c = d.city
	if type(c.corners) ~= "table" then c.corners = {} end
	if type(c.places) ~= "table" then c.places = {} end
	for k, v in pairs(c.corners) do if not CORNER[k] or type(v) ~= "number" then c.corners[k] = nil end end
	for k, v in pairs(c.places) do if type(v) ~= "number" then c.places[k] = nil end end
	for _, k in ipairs({"jobs", "jobPay", "streak"}) do
		local v = c[k]
		c[k] = (type(v) == "number" and v == v and v >= 0 and v < math.huge) and v or 0
	end
	return c
end
F.cityRec = rec
local function count(t) local n = 0 for _ in pairs(t) do n += 1 end return n end
local function reward(d, secs, min)
	local inc = F.incomePerSec(d)
	if inc ~= inc or inc == math.huge then inc = 0 end
	return math.floor(math.max(min, inc * secs))
end
local function pay(plr, d, cash, rep)
	d.cash += cash
	F.earn(d, cash)
	if rep and rep > 0 and F.addRep then F.addRep(plr, rep) end
end

-- ===== achievements =====
C.ACHIEVEMENTS.cornerFirst = {icon = "✨", title = "Golden Corner", post = "Found my first Golden Corner! ✨ There are 30 hidden around the city..."}
C.ACHIEVEMENTS.cornerAll = {icon = "🌟", title = "Every Corner of the City", post = "I found ALL 30 Golden Corners! 🌟 I know this city better than the mayor."}
C.ACHIEVEMENTS.explorer = {icon = "🧭", title = "City Explorer", post = "Visited every single place in Corner City. 🧭"}
C.ACHIEVEMENTS.jobFirst = {icon = "💼", title = "Side Hustle", post = "Finished my first City Job! 💼"}
C.ACHIEVEMENTS.job25 = {icon = "🏅", title = "City Hero", post = "25 City Jobs done. The city runs on me. 🏅"}

-- ===== discovering =====
local function checkCorners(plr, d, pos)
	local c = rec(d)
	for _, g in ipairs(CORNERS) do
		if not c.corners[g.id] then
			local dx, dz = pos.X - g.pos.X, pos.Z - g.pos.Z
			if dx * dx + dz * dz < X.cornerRadius * X.cornerRadius and math.abs(pos.Y - g.pos.Y) < 12 then
				c.corners[g.id] = os.time()
				if F.track then F.track(plr, "corner") end
				local cash = reward(d, X.cornerSecs, X.cornerMin)
				pay(plr, d, cash, 2)
				local n = count(c.corners)
				C.burst(g.pos + V3(0, 2, 0), RGB(255, 215, 80), 50)
				local msg = "✨ GOLDEN CORNER " .. n .. " / " .. #CORNERS .. "  +$" .. fmt(cash)
				-- the whole set of this zone?
				local zone
				for _, z in ipairs(ZONES) do if z.key == g.zone then zone = z end end
				local setDone = zone ~= nil
				if zone then for _, id in ipairs(zone.corners) do if not c.corners[id] then setDone = false end end end
				if setDone and #zone.corners > 1 then
					local bonus = reward(d, X.setSecs, X.setMin)
					pay(plr, d, bonus, 5)
					msg = msg .. "  •  " .. zone.icon .. " " .. zone.name .. " set complete! +$" .. fmt(bonus)
				end
				notify(plr, msg)
				if n == 1 and F.achieve then F.achieve(plr, "cornerFirst") end
				if n == 1 and F.guideTip then F.guideTip(plr, "goldenCorner") end
				if n == #CORNERS then
					local big = reward(d, X.allSecs, X.allMin)
					pay(plr, d, big, 50)
					R.Splash:FireClient(plr, "🌟 EVERY CORNER OF THE CITY 🌟", "All " .. #CORNERS .. " Golden Corners found!  +$" .. fmt(big), RGB(255, 215, 80))
					if F.achieve then F.achieve(plr, "cornerAll") end
					if F.buzz then F.buzz("🌟", plr.Name .. " found every Golden Corner in the city!", RGB(255, 215, 80), plr.Name, plr) end
				end
				R.Menu:FireClient(plr, "cityCorner", {id = g.id, n = n, total = #CORNERS})
			end
		end
	end
end
local function checkPlaces(plr, d, pos)
	local c = rec(d)
	for _, pl in ipairs(PLACES) do
		if not c.places[pl.key] then
			local dx, dz = pos.X - pl.pos.X, pos.Z - pl.pos.Z
			if dx * dx + dz * dz < pl.radius * pl.radius then
				c.places[pl.key] = os.time()
				local cash = reward(d, X.placeSecs, X.placeMin)
				pay(plr, d, cash, 1)
				notify(plr, "📍 DISCOVERED: " .. pl.icon .. " " .. pl.name .. "  (" .. count(c.places) .. " / " .. #PLACES .. " places)  +$" .. fmt(cash))
				if count(c.places) == #PLACES and F.achieve then F.achieve(plr, "explorer") end
			end
		end
	end
end

-- ===== CITY JOBS =====
local jobs = {}      -- plr -> {offers = {...}, active = job|nil, nextRefresh, cooldownUntil}
local function rnd(list) return list[math.random(#list)] end
local function pointBetween(from, lo, hi, tries)
	for _ = 1, tries or 60 do
		local p = rnd(walkPts)
		local dist = (V3(p.pos.X, 0, p.pos.Z) - V3(from.X, 0, from.Z)).Magnitude
		if dist >= lo and dist <= hi then return p end
	end
	return rnd(walkPts)
end
local function zoneName(pos)
	local best, bd
	for _, pl in ipairs(PLACES) do
		local d = (V3(pos.X, 0, pos.Z) - pl.pos).Magnitude
		if not bd or d < bd then best, bd = pl, d end
	end
	return best and (best.icon .. " " .. best.name) or "🏙️ the city"
end
local NAMES = {"Mrs. Patel", "Grandpa Joe", "Dana", "Coach Rivera", "Ms. Kim", "Big Lou", "Aunt Rosa", "Mr. Okafor"}
local DOGS = {"Biscuit", "Noodle", "Captain", "Waffles", "Pepper", "Mochi", "Rex", "Pickles"}
local function makeOffer(plr, kind)
	local ch = plr.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	local here = root and root.Position or V3(0, 0, 0)
	local J = X.jobs[kind]
	local o = {kind = kind, icon = J.icon, name = J.name, id = tostring(math.random(1e6, 9e6))}
	if kind == "courier" then
		local a = pointBetween(here, 80, 320)
		local b = pointBetween(a.pos, 220, 520)
		local dist = (a.pos - b.pos).Magnitude
		o.stops = {a.pos, b.pos}
		o.limit = math.floor(dist / 13 + 45)
		o.text = "Pick up a parcel on " .. a.road .. " (" .. zoneName(a.pos) .. ") and get it to " .. b.road .. " (" .. zoneName(b.pos) .. ") within " .. o.limit .. " s."
		o.bonus = 1 + math.min(1, dist / 900)
	elseif kind == "pet" then
		local owner = pointBetween(here, 60, 260)
		local pet = pointBetween(owner.pos, 140, 380)
		o.stops = {pet.pos, owner.pos}
		o.who, o.dog = rnd(NAMES), rnd(DOGS)
		o.text = o.who .. "'s dog " .. o.dog .. " ran off! Last seen near " .. pet.road .. " (" .. zoneName(pet.pos) .. "). Find " .. o.dog .. " and walk them home."
		o.bonus = 1
	elseif kind == "catering" then
		-- one of YOUR food businesses cooks it; you take it to the party
		local d = data[plr]
		local own = {}
		for _, k in ipairs({"lemonade", "icecream", "bakery", "coffee", "pizza"}) do if d and (d.levels[k] or 0) > 0 then table.insert(own, k) end end
		local key = own[math.random(#own)]
		local door = (F.slotCF(d.plot, key) * CFrame.new(0, 0, 9)).Position
		local party = pointBetween(door, 200, 520)
		local dist = (door - party.pos).Magnitude
		local list = F.productsOf and F.productsOf(d, key) or {}
		local item = #list > 0 and list[math.random(#list)].name or C.BIZ[key].name
		local who = rnd({"A birthday party", "An office lunch", "A wedding rehearsal", "A soccer team", "A movie night", "A family reunion"})
		local qty = math.random(8, 24)
		o.stops = {V3(door.X, 0.3, door.Z), party.pos}
		o.limit = math.floor(dist / 12 + 50)
		o.key = key
		o.text = who .. " on " .. party.road .. " (" .. zoneName(party.pos) .. ") ordered " .. qty .. " × " .. C.BIZ[key].icon .. " " .. item .. " from " .. (F.bizName and F.bizName(d, key) or C.BIZ[key].name)
			.. ". Pick it up at your business, then deliver within " .. o.limit .. " s."
		o.bonus = 1 + math.min(1, dist / 900)
	else
		local center = pointBetween(here, 100, 380)
		local pts = {}
		for _ = 1, 80 do
			local p = rnd(walkPts)
			if (p.pos - center.pos).Magnitude < X.cleanupSpread then
				local ok = true
				for _, q in ipairs(pts) do if (q - p.pos).Magnitude < 8 then ok = false end end
				if ok then table.insert(pts, p.pos) end
			end
			if #pts >= X.litter then break end
		end
		while #pts < X.litter do table.insert(pts, center.pos + V3(math.random(-12, 12), 0, math.random(-12, 12))) end
		o.stops = pts
		o.limit = X.cleanupTime
		o.text = "Litter is piling up on " .. center.road .. " (" .. zoneName(center.pos) .. "). Bag all " .. X.litter .. " piles within " .. o.limit .. " s of the first."
		o.bonus = 1
	end
	return o
end
local function refreshOffers(plr, st)
	st.offers = {}
	for _, k in ipairs({"courier", "pet", "cleanup"}) do table.insert(st.offers, makeOffer(plr, k)) end
	local d = data[plr]
	local food = false
	for _, k in ipairs({"lemonade", "icecream", "bakery", "coffee", "pizza"}) do if d and (d.levels[k] or 0) > 0 then food = true end end
	if food and F.slotCF and d.plot then table.insert(st.offers, makeOffer(plr, "catering")) end
	st.nextRefresh = os.clock() + X.refreshEvery
end
local function stateOf(plr)
	local st = jobs[plr]
	if not st then
		st = {offers = {}, nextRefresh = 0, cooldownUntil = 0}
		jobs[plr] = st
	end
	if os.clock() >= st.nextRefresh and not st.active then refreshOffers(plr, st) end
	return st
end
-- what the client draws and shows
function F.cityJobView(plr)
	local st = stateOf(plr)
	local a = st.active
	local view = {offers = {}, cooldown = math.max(0, math.ceil(st.cooldownUntil - os.clock()))}
	for i, o in ipairs(st.offers) do table.insert(view.offers, {i = i, kind = o.kind, icon = o.icon, name = o.name, text = o.text}) end
	if a then
		local left = a.deadline and math.max(0, math.ceil(a.deadline - os.clock())) or nil
		local targets = {}
		if a.kind == "cleanup" then
			for i, p in ipairs(a.stops) do if not a.got[i] then table.insert(targets, {p.X, p.Y, p.Z}) end end
		else
			local p = a.stops[a.step]
			if p then targets = {{p.X, p.Y, p.Z}} end
		end
		view.active = {kind = a.kind, icon = a.icon, name = a.name, text = a.text, step = a.step, steps = #a.stops, left = left, targets = targets,
			dog = a.dog, who = a.who, carrying = a.step == 2 and (a.kind == "pet" or a.kind == "courier" or a.kind == "catering"), got = a.gotN}
	end
	return view
end
local function push(plr) R.Menu:FireClient(plr, "cityJobs", F.cityJobView(plr)) end
local function endJob(plr, st, ok, why)
	local a = st.active
	st.active = nil
	st.cooldownUntil = os.clock() + X.cooldown
	local d = data[plr]
	if not (a and d) then return end
	local c = rec(d)
	if ok then
		local J = X.jobs[a.kind]
		local cash = math.floor(reward(d, J.secs, J.min) * (a.bonus or 1) * (F.vehicleBonus and F.vehicleBonus(plr, "jobs") or 1))   -- (v14: 🚚 Hauler)
		pay(plr, d, cash, J.rep)
		c.jobs += 1
		c.jobPay += cash
		if F.track then F.track(plr, "job") end
		c.streak += 1
		R.Splash:FireClient(plr, a.icon .. " JOB DONE: " .. string.upper(a.name), (why or "Nice work!") .. "  +$" .. fmt(cash), RGB(120, 230, 150))
		if c.jobs == 1 and F.achieve then F.achieve(plr, "jobFirst") end
		if c.jobs == 25 and F.achieve then F.achieve(plr, "job25") end
	else
		c.streak = 0
		notify(plr, a.icon .. " " .. a.name .. ": " .. (why or "job cancelled."))
	end
	-- a fresh offer in its place
	for i, o in ipairs(st.offers) do if o.kind == a.kind then st.offers[i] = makeOffer(plr, a.kind) end end
	push(plr)
end
function F.cityJobTake(plr, i)
	local st = stateOf(plr)
	if st.active then notify(plr, "Finish (or drop) your current job first.") return false end
	if os.clock() < st.cooldownUntil then notify(plr, "Next job in " .. math.ceil(st.cooldownUntil - os.clock()) .. " s.") return false end
	local o = st.offers[i]
	if not o then return false end
	st.active = {kind = o.kind, icon = o.icon, name = o.name, text = o.text, stops = o.stops, step = 1, bonus = o.bonus, limit = o.limit,
		dog = o.dog, who = o.who, got = {}, gotN = 0, started = os.clock(), expires = os.clock() + X.petExpire}
	if o.kind == "courier" then st.active.text = "📦 Go to the pickup point (follow the beam)." end
	if o.kind == "pet" then st.active.text = "🐶 Find " .. o.dog .. " (follow the beam)." end
	if o.kind == "cleanup" then st.active.text = "🧹 Bag the litter piles (follow the beam)." end
	if o.kind == "catering" then st.active.text = "🎂 Go to your business to pick up the order (follow the beam)." end
	if F.guideTip then F.guideTip(plr, "cityJob") end
	push(plr)
	return true
end
function F.cityJobDrop(plr)
	local st = stateOf(plr)
	if st.active then endJob(plr, st, false, "dropped.") end
end
-- a teleport (phone map, Visit buttons...) cancels a job: no warping to the drop-off
function F.cityOnTeleport(plr)
	local st = jobs[plr]
	if st and st.active then endJob(plr, st, false, "cancelled: you teleported. City Jobs have to be done on foot or by car.") end
end
local function jobTick(plr, d, pos)
	local st = jobs[plr]
	local a = st and st.active
	if not a then return end
	local now = os.clock()
	if a.deadline and now > a.deadline then endJob(plr, st, false, "out of time!") return end
	if now > a.expires then endJob(plr, st, false, "the job expired.") return end
	local function at(p) return (V3(pos.X, 0, pos.Z) - V3(p.X, 0, p.Z)).Magnitude < X.reach and math.abs(pos.Y - p.Y) < 14 end
	if a.kind == "cleanup" then
		for i, p in ipairs(a.stops) do
			if not a.got[i] and at(p) then
				a.got[i] = true
				a.gotN += 1
				if a.gotN == 1 then a.deadline = now + a.limit end
				a.text = "🧹 " .. a.gotN .. " / " .. #a.stops .. " piles bagged."
				C.burst(p + V3(0, 1, 0), RGB(120, 230, 150), 20)
				if a.gotN == #a.stops then endJob(plr, st, true, "The street is spotless.") return end
				push(plr)
			end
		end
	elseif at(a.stops[a.step]) then
		if a.step == 1 then
			a.step = 2
			if a.kind == "courier" or a.kind == "catering" then
				a.deadline = now + a.limit
				a.text = a.kind == "catering" and ("🎂 Order packed! Get it to the party within " .. a.limit .. " s (follow the beam).")
					or ("📦 Parcel picked up! Deliver it within " .. a.limit .. " s (follow the beam).")
			else
				a.text = "🐶 You found " .. a.dog .. "! Walk them back to " .. a.who .. "."
			end
			push(plr)
		else
			endJob(plr, st, true, (a.kind == "courier" and "Delivered on time.") or (a.kind == "catering" and "The party loved it! (+reputation)")
				or (a.who .. " is so happy to have " .. a.dog .. " back!"))
		end
	end
end

-- ===== the loop: once a second per player =====
task.spawn(function()
	while true do
		task.wait(1)
		for plr, d in pairs(data) do
			local ch = plr.Character
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			if root and not d.noPlay then
				local ok, err = pcall(function()
					local pos = root.Position
					checkCorners(plr, d, pos)
					checkPlaces(plr, d, pos)
					jobTick(plr, d, pos)
				end)
				if not ok then warn("[CornerEmpire] explore check failed: " .. tostring(err)) end
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) jobs[plr] = nil end)

-- ===== what the Explore app shows =====
function F.exploreInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local c = rec(d)
	local zones = {}
	for _, z in ipairs(ZONES) do
		local got, hints = 0, {}
		for _, id in ipairs(z.corners) do
			if c.corners[id] then got += 1 else table.insert(hints, CORNER[id].hint) end
		end
		table.insert(zones, {key = z.key, name = z.name, icon = z.icon, got = got, total = #z.corners, hint = hints[1]})
	end
	local places = {}
	for _, pl in ipairs(PLACES) do table.insert(places, {key = pl.key, name = pl.name, icon = pl.icon, kind = pl.kind, found = c.places[pl.key] ~= nil}) end
	return {corners = count(c.corners), cornersTotal = #CORNERS, zones = zones, places = places, placesFound = count(c.places), jobs = F.cityJobView(plr),
		jobsDone = c.jobs, jobPay = c.jobPay, streak = c.streak}
end
-- the small packet in each state update: which corners YOU still have to find (the client only draws those)
function F.exploreBrief(d)
	local c = rec(d)
	local left = {}
	for _, g in ipairs(CORNERS) do if not c.corners[g.id] then table.insert(left, g.id) end end
	return {left = left, n = count(c.corners), total = #CORNERS}
end
-- positions for the client (sent once in the catalog)
function F.exploreCatalog()
	local out = {}
	for _, g in ipairs(CORNERS) do table.insert(out, {id = g.id, p = {g.pos.X, g.pos.Y, g.pos.Z}}) end
	return {corners = out}
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.exploreInfo = function(plr)
	local info = F.exploreInfo(plr)
	if info then R.Menu:FireClient(plr, "explore", info) end
end
C.ACTIONS.jobTake = function(plr, d, a)
	local i = C.int(a, 1, X.offers)
	if i and F.cityJobTake(plr, i) then C.ACTIONS.exploreInfo(plr) end
end
C.ACTIONS.jobDrop = function(plr)
	F.cityJobDrop(plr)
	C.ACTIONS.exploreInfo(plr)
end
end
