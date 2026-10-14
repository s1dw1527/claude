-- PARK (v15): the 🎢 AMUSEMENT PARK business. Like the Movie Theater it opens on a city plot (its ticket gate
-- stands there), and its owner gets their own site at the FUNLAND GROUNDS (far west, past the Fun Park) to build
-- the park on:
--   * GROUNDS: 4 sites of 20 x 24 cells (4 studs each) along a central promenade; one per player in the server,
--     handed out when their park is open and freed when they leave (like the home plots). Anyone can walk in.
--   * BUILD: rides (carousel, teacups, Ferris wheel, swing ride, pirate ship, bumper cars, drop tower, two roller
--     coasters), food stalls (cotton candy, popcorn, balloons, ice cream), paths and decorations. Every placement is
--     checked here: on your site, inside the grid, not over another piece or the gate, under the item cap, the
--     ride unlocked by your park's level, and paid for. Saved as d.park.items = {{id, k, x, z, r}}
--   * RATING: excitement from the rides (with variety), stalls to feed the crowd, paths and decorations. It sets the
--     park's sales (×1 … ×1.8, in Systems' bizMult) and how many visitors walk around it
--   * RIDES: every ride has a 🎢 Ride prompt: the server checks the rider and plays the ride on their screen (the
--     camera rides the car, the client moves the trains in time with the server clock). Another player riding
--     your rides pays you a ticket and a little reputation
-- Everything is decided on the server; the client (EmpireClient > ParkUI / ParkFX) only shows it and asks.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local P, ball, cyl, xcyl, billboard, surfaceText, tag = C.P, C.ball, C.cyl, C.xcyl, C.billboard, C.surfaceText, C.tag
local BIZ = C.BIZ
local SOLID = {CanCollide = true}
local WHITE, DARK, GOLD = RGB(250, 250, 250), RGB(40, 40, 46), RGB(255, 205, 60)

local PK = {
	cell = 4, gw = 20, gh = 24,         -- the grid: 20 x 24 cells of 4 studs (80 x 96 studs)
	gate = {9, 14},                      -- gate cells on the promenade side (x = 0, z 9..14) stay free
	baseItems = 24, itemsPerLevel = 6, maxItems = 84,
	sellBack = 0.5,
	rideCooldown = 6, rideMax = 45, rideRange = 26,
	ticketSecs = 4,                      -- a guest's ticket pays the owner this many seconds of the park's income
	guestRep = 1, guestRepPerHour = 30,
	statEvery = 30,
	multMax = 1.8,
}
C.PARK = PK

-- ===== the catalog =====
-- w x h cells, cost, excite (rides), lvl = the park level that unlocks it, kind: ride / stall / path / decor
local ITEMS = {
	{k = "path", name = "Path", icon = "🟫", kind = "path", w = 1, h = 1, cost = 20000, lvl = 1, desc = "Visitors walk on paths."},
	{k = "flowers", name = "Flower Bed", icon = "🌷", kind = "decor", w = 1, h = 1, cost = 50000, lvl = 1, desc = "Pretty. +rating."},
	{k = "bench", name = "Bench", icon = "🪑", kind = "decor", w = 1, h = 1, cost = 60000, lvl = 1, desc = "A rest for tired feet."},
	{k = "lamp", name = "Lamp", icon = "💡", kind = "decor", w = 1, h = 1, cost = 80000, lvl = 1, desc = "Glows at night."},
	{k = "tree", name = "Tree", icon = "🌳", kind = "decor", w = 1, h = 1, cost = 100000, lvl = 1, desc = "Shade and green."},
	{k = "fountain", name = "Fountain", icon = "⛲", kind = "decor", w = 2, h = 2, cost = 1500000, lvl = 2, desc = "The park's centerpiece."},
	{k = "cottoncandy", name = "Cotton Candy", icon = "🍭", kind = "stall", w = 1, h = 1, cost = 400000, lvl = 1, desc = "A pink cloud on a stick."},
	{k = "popcorn", name = "Popcorn Cart", icon = "🍿", kind = "stall", w = 1, h = 1, cost = 400000, lvl = 1, desc = "Salty, buttery, loud."},
	{k = "balloons", name = "Balloon Stand", icon = "🎈", kind = "stall", w = 1, h = 1, cost = 300000, lvl = 2, desc = "Every color. Hold on tight."},
	{k = "icecream", name = "Ice Cream Kiosk", icon = "🍦", kind = "stall", w = 1, h = 1, cost = 500000, lvl = 2, desc = "Two scoops, sprinkles."},
	{k = "carousel", name = "Carousel", icon = "🎠", kind = "ride", w = 3, h = 3, cost = 3000000, excite = 8, lvl = 1, dur = 14, desc = "Painted horses, round and round."},
	{k = "teacups", name = "Spinning Teacups", icon = "☕", kind = "ride", w = 3, h = 3, cost = 4000000, excite = 9, lvl = 1, dur = 12, desc = "Spin it faster. No, faster."},
	{k = "ferris", name = "Ferris Wheel", icon = "🎡", kind = "ride", w = 4, h = 2, cost = 8000000, excite = 14, lvl = 2, dur = 20, desc = "The best view in Funland."},
	{k = "bumper", name = "Bumper Cars", icon = "🚗", kind = "ride", w = 4, h = 3, cost = 12000000, excite = 15, lvl = 3, dur = 14, desc = "Bonk. Bonk. BONK."},
	{k = "swing", name = "Swing Ride", icon = "🌀", kind = "ride", w = 4, h = 4, cost = 10000000, excite = 16, lvl = 3, dur = 14, desc = "Chairs that fly out wide."},
	{k = "pirate", name = "Pirate Ship", icon = "🏴‍☠️", kind = "ride", w = 4, h = 2, cost = 14000000, excite = 18, lvl = 4, dur = 14, desc = "Swings higher every pass."},
	{k = "junior", name = "Junior Coaster", icon = "🐛", kind = "ride", w = 6, h = 4, cost = 25000000, excite = 26, lvl = 4, coaster = true, desc = "Little hills, big smiles."},
	{k = "droptower", name = "Drop Tower", icon = "🗼", kind = "ride", w = 2, h = 2, cost = 20000000, excite = 24, lvl = 5, dur = 16, desc = "Up slowly. Down NOT slowly."},
	{k = "loop", name = "Loop Coaster", icon = "🎢", kind = "ride", w = 8, h = 5, cost = 60000000, excite = 40, lvl = 6, coaster = true, desc = "A lift hill, a drop and a full loop."},
}
local ITEM = {}
for i, it in ipairs(ITEMS) do
	it.order = i
	ITEM[it.k] = it
end
C.PARK_ITEMS = ITEMS

-- ===== the save record =====
local function rec(d)
	local p = d.park
	if type(p) ~= "table" then
		p = {}
		d.park = p
	end
	if type(p.items) ~= "table" then p.items = {} end
	if type(p.stats) ~= "table" then p.stats = {} end
	for _, k in ipairs({"visitors", "rides", "guestRides", "best", "seq"}) do
		local v = tonumber(p[k])
		p[k] = (v and v == v and v >= 0 and v < 1e15) and math.floor(v) or 0
	end
	-- items: known kinds, whole numbers inside the grid, no overlaps (anything else is kept aside, never lost)
	local clean, used = {}, {}
	local maxId = p.seq
	for _, it in ipairs(p.items) do
		local def = type(it) == "table" and ITEM[it.k]
		local ok = def and type(it.x) == "number" and type(it.z) == "number" and it.x == math.floor(it.x) and it.z == math.floor(it.z)
		if ok then
			it.r = (tonumber(it.r) or 0) % 4
			it.id = tonumber(it.id) or 0
			local w, h = def.w, def.h
			if it.r % 2 == 1 then w, h = h, w end
			if it.x < 0 or it.z < 0 or it.x + w > PK.gw or it.z + h > PK.gh then ok = false end
			if ok then
				for cx = it.x, it.x + w - 1 do
					for cz = it.z, it.z + h - 1 do if used[cx * 100 + cz] then ok = false end end
				end
			end
			if ok then
				for cx = it.x, it.x + w - 1 do
					for cz = it.z, it.z + h - 1 do used[cx * 100 + cz] = true end
				end
			end
		end
		if ok then
			if it.id <= 0 then
				maxId += 1
				it.id = maxId
			end
			maxId = math.max(maxId, it.id)
			table.insert(clean, it)
		else
			p.lost = type(p.lost) == "table" and p.lost or {}
			if #p.lost < 50 then table.insert(p.lost, it) end
		end
	end
	p.items = clean
	p.seq = maxId
	return p
end
F.parkRec = rec

local function itemCap(d) return math.min(PK.maxItems, PK.baseItems + PK.itemsPerLevel * math.max(0, (d.levels.park or 0) - 1)) end
local function footprint(def, x, z, r)
	local w, h = def.w, def.h
	if (r or 0) % 2 == 1 then w, h = h, w end
	return x, z, w, h
end

-- ===== rating =====
function F.parkScore(d)
	local p = rec(d)
	local excite, kinds, rides, stalls, decor, paths = 0, {}, 0, 0, 0, 0
	for _, it in ipairs(p.items) do
		local def = ITEM[it.k]
		if def.kind == "ride" then
			rides += 1
			-- a second (third...) copy of the same ride is less exciting than something new
			kinds[it.k] = (kinds[it.k] or 0) + 1
			excite += def.excite * (kinds[it.k] == 1 and 1 or 0.4)
		elseif def.kind == "stall" then stalls += 1
		elseif def.kind == "decor" then decor += 1
		elseif def.kind == "path" then paths += 1 end
	end
	local variety = 0
	for _ in pairs(kinds) do variety += 1 end
	local parts = {
		{"🎢 Rides", math.floor(math.min(55, excite * 0.45))},
		{"🌈 Variety", math.min(15, variety * 2)},
		{"🍭 Food & treats", math.min(12, math.min(stalls, rides + 1) * 3)},
		{"🌳 Decoration", math.min(10, math.floor(decor * 0.5))},
		{"🟫 Paths", math.min(8, math.floor(paths / 4))},
	}
	local rating = 0
	for _, x in ipairs(parts) do rating += x[2] end
	rating = math.clamp(rating, 0, 100)
	return rating, parts, {rides = rides, stalls = stalls, decor = decor, paths = paths, variety = variety}
end
function F.parkMult(d, key)
	if key ~= "park" then return 1 end
	if not d or (d.levels.park or 0) <= 0 or type(d.park) ~= "table" then return 1 end
	local rating = F.parkScore(d)
	return math.min(PK.multMax, 1 + rating / 100 * (PK.multMax - 1))
end

-- =====================================================================
-- THE FUNLAND GROUNDS: a promenade with 2 sites on each side
-- =====================================================================
local GROUNDS = Instance.new("Folder")
GROUNDS.Name = "Funland"
GROUNDS.Parent = C.WORLD
local PROM_X0, PROM_X1 = -760, -744          -- the promenade between the two columns of sites
local Z_ROWS = {{-250, -154}, {-146, -50}}
if C.clearTerrain then C.clearTerrain(-846, -258, -636, -40, 70) end
C.reserve(-846, -256, -640, -44)
C.path("Funland promenade", PROM_X0 + 2, -250, PROM_X1 - 2, -50)   -- (the lamps stand along its edges)
C.path("Funland walk", PROM_X1, -153, -640, -147)   -- (between the sites' railings)
local SITES = {}
for row, zr in ipairs(Z_ROWS) do
	for _, side in ipairs({1, -1}) do
		-- local +X points away from the promenade; the grid's cell (0, 0) corner is at `cf`
		local cf
		if side == 1 then cf = CF(PROM_X1, 0, zr[1])
		else cf = CF(PROM_X0, 0, zr[2]) * CFrame.Angles(0, math.pi, 0) end
		table.insert(SITES, {i = #SITES + 1, cf = cf, row = row, side = side})
	end
end
PK.sites = SITES
local function cellCF(site, x, z, w, h, r)
	-- the center of a footprint (w x h cells at x, z), turned r quarter turns
	local c = PK.cell
	return site.cf * CF((x + w / 2) * c, 0, (z + h / 2) * c) * CFrame.Angles(0, -(r or 0) * math.pi / 2, 0)
end
PK.cellCF = cellCF
do
	-- the promenade: pavers, lamps, flags and a big arch at the walk in from the city
	P(GROUNDS, V3(PROM_X1 - PROM_X0, 0.3, 200), CF((PROM_X0 + PROM_X1) / 2, 0.15, -150), RGB(214, 196, 168), MAT.Cobblestone)
	P(GROUNDS, V3(-640 - PROM_X1, 0.3, 8), CF((PROM_X1 - 640) / 2, 0.15, -150), RGB(214, 196, 168), MAT.Cobblestone)
	for z = -240, -60, 30 do
		for _, x in ipairs({PROM_X0 + 1, PROM_X1 - 1}) do
			if math.abs(z + 150) > 6 then
				P(GROUNDS, V3(0.4, 7, 0.4), CF(x, 3.5, z), DARK, MAT.Metal)
				local l = ball(GROUNDS, V3(1, 1, 1), CF(x, 7.4, z), RGB(255, 230, 160), MAT.Neon)
				local pl = Instance.new("PointLight")
				pl.Range, pl.Brightness, pl.Color = 14, 0.8, RGB(255, 220, 160)
				pl.Parent = l
				P(GROUNDS, V3(0.1, 1.6, 1.2), CF(x, 6, z + 0.7), Color3.fromHSV(((z + 240) / 30 % 6) / 6, 0.7, 1), MAT.Fabric)
			end
		end
	end
	-- the entrance arch where the walk meets the city (x = -646)
	for _, sz in ipairs({-1, 1}) do
		P(GROUNDS, V3(1.6, 12, 1.6), CF(-646, 6, -150 + sz * 5.2), RGB(255, 170, 40), MAT.SmoothPlastic, SOLID)
		ball(GROUNDS, V3(2.4, 2.4, 2.4), CF(-646, 12.8, -150 + sz * 5.2), RGB(255, 80, 120))
	end
	local arch = P(GROUNDS, V3(1, 2.4, 12), CF(-646, 11, -150), RGB(200, 40, 90), MAT.SmoothPlastic)
	arch.Name = "FunlandArch"
	surfaceText(arch, Enum.NormalId.Right, "🎢 FUNLAND GROUNDS", RGB(255, 245, 210))
	surfaceText(arch, Enum.NormalId.Left, "🎢 FUNLAND GROUNDS", RGB(255, 245, 210))
	local bulbs = Instance.new("Model")
	bulbs.Name = "ArchBulbs"
	bulbs.Parent = GROUNDS
	for k = 0, 11 do ball(bulbs, V3(0.4, 0.4, 0.4), CF(-646.6, 12.4, -155.5 + k), RGB(255, 230, 120), MAT.Neon) end
	tag(bulbs, "ChaseLights")
end
local function buildSiteBase(site)
	if site.folder then site.folder:Destroy() end
	local f = Instance.new("Model")
	f.Name = "Site" .. site.i
	f.Parent = GROUNDS
	site.folder = f
	local W, D = PK.gw * PK.cell, PK.gh * PK.cell
	local o = site.cf * CF(W / 2, 0, D / 2)
	P(f, V3(W, 0.2, D), o * CF(0, 0.1, 0), RGB(110, 170, 85), MAT.Grass).Name = "Ground"
	-- a low railing all round, open at the gate
	local function rail(len, cf) P(f, V3(len, 0.3, 0.3), cf * CF(0, 1.8, 0), WHITE, MAT.SmoothPlastic) P(f, V3(len, 2, 0.2), cf * CF(0, 1, 0), RGB(255, 170, 40), MAT.SmoothPlastic, SOLID) end
	rail(W, o * CF(0, 0, -D / 2))
	rail(W, o * CF(0, 0, D / 2))
	rail(D, o * CF(W / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	local g0, g1 = PK.gate[1] * PK.cell, (PK.gate[2] + 1) * PK.cell
	rail(g0, site.cf * CF(0, 0, g0 / 2) * CFrame.Angles(0, math.pi / 2, 0))
	rail(D - g1, site.cf * CF(0, 0, (g1 + D) / 2) * CFrame.Angles(0, math.pi / 2, 0))
	-- the gate: two posts, an arch with the owner's park name
	for _, gz in ipairs({g0, g1}) do P(f, V3(1.2, 9, 1.2), site.cf * CF(0, 4.5, gz), RGB(255, 120, 40), MAT.SmoothPlastic, SOLID) end
	local sign = P(f, V3(0.6, 2.2, g1 - g0 + 1.2), site.cf * CF(0, 9.4, (g0 + g1) / 2), RGB(200, 40, 90), MAT.SmoothPlastic)
	sign.Name = "GateSign"
	site.sign = sign
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = f
	site.items = items
	site.models = {}
	return f
end
local function siteTitle(site)
	local owner = site.owner
	local d = owner and data[owner]
	if not (owner and d) then return "FUNLAND SITE " .. site.i, "Open an 🎢 Amusement Park to build here" end
	local name = F.bizName and F.bizName(d, "park") or (owner.Name .. "'s Park")
	local rating = F.parkScore(d)
	return "🎢 " .. string.upper(name), owner.Name .. "  •  ⭐ " .. rating .. "/100"
end
local function refreshSign(site)
	local s = site.sign
	if not s then return end
	for _, x in ipairs(s:GetChildren()) do if x:IsA("SurfaceGui") or x:IsA("BillboardGui") then x:Destroy() end end
	local a, b = siteTitle(site)
	-- facing the promenade (local -X)
	surfaceText(s, Enum.NormalId.Left, a .. "\n" .. b, RGB(255, 245, 210))
	s.Parent:SetAttribute("Owner", site.owner and site.owner.UserId or 0)
	s.Parent:SetAttribute("OwnerName", site.owner and site.owner.Name or "")
	local d = site.owner and data[site.owner]
	s.Parent:SetAttribute("Rating", d and (F.parkScore(d)) or 0)
	s.Parent:SetAttribute("GridCF", site.cf)
end
for _, site in ipairs(SITES) do
	buildSiteBase(site)
	refreshSign(site)
end

-- ===== track math for the coasters (the client does the same with the same points) =====
local function catmull(ctrl, sub)
	local out, n = {}, #ctrl
	for i = 1, n do
		local p0, p1, p2, p3 = ctrl[(i - 2) % n + 1], ctrl[i], ctrl[i % n + 1], ctrl[(i + 1) % n + 1]
		for s = 0, sub - 1 do
			local t = s / sub
			local t2, t3 = t * t, t * t * t
			table.insert(out, 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3))
		end
	end
	return out
end
-- evenly spaced points along a closed curve
local function resample(pts, step)
	local cum, total = {0}, 0
	for i = 1, #pts do
		total += (pts[i % #pts + 1] - pts[i]).Magnitude
		cum[i + 1] = total
	end
	local out = {}
	local n = math.max(8, math.floor(total / step + 0.5))
	local k = 1
	for j = 0, n - 1 do
		local s = j / n * total
		while cum[k + 1] < s do k += 1 end
		local a, b = pts[k], pts[k % #pts + 1]
		local seg = cum[k + 1] - cum[k]
		table.insert(out, seg > 0 and a:Lerp(b, (s - cum[k]) / seg) or a)
	end
	return out, total
end
-- speed along the track: slow on the lift, faster the further it has dropped
local function timing(pts, liftA, liftB)
	local hmax = -math.huge
	for _, p in ipairs(pts) do hmax = math.max(hmax, p.Y) end
	local T, t = {0}, 0
	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]
		local v
		if liftA and i >= liftA and i <= liftB then v = 5
		else v = math.max(7, math.sqrt(2 * 12 * math.max(0, hmax - (a.Y + b.Y) / 2)) + 5) end
		t += (b - a).Magnitude / v
		T[i + 1] = t
	end
	return T, t
end
PK.timing = timing
local function packPts(pts)
	local s = {}
	for _, p in ipairs(pts) do table.insert(s, string.format("%.2f,%.2f,%.2f", p.X, p.Y, p.Z)) end
	return table.concat(s, ";")
end
-- the up direction carried along the track (so a loop turns the cars upside down, not sideways)
local function frames(pts)
	local out, n = {}, #pts
	local up = V3(0, 1, 0)
	for i = 1, n do
		local look = (pts[i % n + 1] - pts[(i - 2) % n + 1])
		look = look.Magnitude > 0.001 and look.Unit or V3(0, 0, -1)
		up = up - look * up:Dot(look)
		up = up.Magnitude > 0.001 and up.Unit or V3(0, 1, 0)
		out[i] = {look = look, up = up}
	end
	return out
end

-- ===== the ride builders. o = the footprint's center on the ground (turned with the ride), W x D its size in studs =====
local BUILD = {}
local function spinPart(p) p:SetAttribute("Kind", "spin") return p end
local function rotatorModel(parent, name, hubCF, axis, speed, mode, extra)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	m:SetAttribute("Hub", hubCF.Position)
	m:SetAttribute("HubCF", hubCF)
	m:SetAttribute("Axis", axis)
	m:SetAttribute("Speed", speed)
	if mode then m:SetAttribute("Mode", mode) end
	for k, v in pairs(extra or {}) do m:SetAttribute(k, v) end
	return m
end
local function stripes(m, cf, w, d, a, b)
	local n = math.max(2, math.floor(w / 1.2))
	for k = 0, n - 1 do P(m, V3(w / n, 0.25, d), cf * CF(-w / 2 + (k + 0.5) * w / n, 0, 0), k % 2 == 0 and a or b, MAT.Fabric) end
end
BUILD.path = function(m, o)
	P(m, V3(4, 0.3, 4), o * CF(0, 0.25, 0), RGB(214, 196, 168), MAT.Cobblestone).Name = "Paver"
end
BUILD.flowers = function(m, o)
	P(m, V3(3.4, 0.8, 3.4), o * CF(0, 0.5, 0), RGB(120, 84, 60), MAT.Wood)
	for k = 0, 5 do ball(m, V3(0.9, 0.9, 0.9), o * CF(math.cos(k) * 1, 1.2, math.sin(k) * 1), Color3.fromHSV(k / 6, 0.6, 1), MAT.SmoothPlastic) end
end
BUILD.bench = function(m, o)
	P(m, V3(3.4, 0.3, 1.2), o * CF(0, 1.3, 0), RGB(150, 105, 62), MAT.WoodPlanks)
	P(m, V3(3.4, 1, 0.2), o * CF(0, 2, 0.6), RGB(150, 105, 62), MAT.WoodPlanks)
	for _, sx in ipairs({-1.4, 1.4}) do P(m, V3(0.3, 1.2, 1.2), o * CF(sx, 0.6, 0), DARK, MAT.Metal) end
end
BUILD.lamp = function(m, o)
	P(m, V3(0.35, 7, 0.35), o * CF(0, 3.5, 0), DARK, MAT.Metal)
	local l = ball(m, V3(1.1, 1.1, 1.1), o * CF(0, 7.3, 0), RGB(255, 230, 160), MAT.Neon)
	local pl = Instance.new("PointLight")
	pl.Range, pl.Brightness, pl.Color = 14, 0.9, RGB(255, 220, 160)
	pl.Parent = l
end
BUILD.tree = function(m, o)
	C.tree(m, o.Position.X, o.Position.Z, 0.55)
end
BUILD.fountain = function(m, o)
	cyl(m, 1.2, 7.4, o * CF(0, 0.6, 0), RGB(200, 200, 205), MAT.Concrete, SOLID)
	cyl(m, 0.3, 6.6, o * CF(0, 1.1, 0), RGB(90, 170, 230), MAT.Glass, {Transparency = 0.25})
	cyl(m, 3, 0.8, o * CF(0, 2.2, 0), RGB(200, 200, 205), MAT.Concrete)
	local spout = ball(m, V3(1.6, 1.2, 1.6), o * CF(0, 3.9, 0), RGB(140, 210, 255), MAT.Glass, {Transparency = 0.3})
	local e = Instance.new("ParticleEmitter")
	e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 30, NumberRange.new(0.8, 1.2), NumberRange.new(7, 9), Vector2.new(18, 18)
	e.Acceleration = V3(0, -25, 0)
	e.Color = ColorSequence.new(RGB(190, 230, 255))
	e.Size = NumberSequence.new(0.35)
	e.Parent = spout
end
local STALL = {
	cottoncandy = {RGB(255, 140, 200), "🍭 COTTON CANDY", function(m, o) ball(m, V3(1.8, 1.5, 1.8), o * CF(0, 5.6, 0), RGB(255, 180, 225), MAT.Fabric) end},
	popcorn = {RGB(230, 50, 60), "🍿 POPCORN", function(m, o) P(m, V3(1.6, 1.6, 1.6), o * CF(0, 5.4, 0), RGB(255, 240, 190), MAT.Glass, {Transparency = 0.3}) end},
	balloons = {RGB(80, 160, 255), "🎈 BALLOONS", function(m, o)
		for k = 0, 4 do
			ball(m, V3(1, 1.2, 1), o * CF(math.cos(k * 1.3) * 0.8, 7 + (k % 2) * 0.8, math.sin(k * 1.3) * 0.8), Color3.fromHSV(k / 5, 0.7, 1)).Name = "Balloon"
		end
		P(m, V3(0.06, 2.4, 0.06), o * CF(0, 5.6, 0), WHITE)
	end},
	icecream = {RGB(120, 220, 200), "🍦 ICE CREAM", function(m, o)
		P(m, V3(0.8, 1.2, 0.8), o * CF(0, 5.2, 0), RGB(220, 170, 100), MAT.WoodPlanks)
		ball(m, V3(1.2, 1.2, 1.2), o * CF(0, 6.2, 0), RGB(255, 200, 230))
	end},
}
for k, s in pairs(STALL) do
	BUILD[k] = function(m, o)
		P(m, V3(3, 2.2, 2), o * CF(0, 1.3, 0), s[1], MAT.SmoothPlastic, SOLID)
		for _, sx in ipairs({-1.3, 1.3}) do P(m, V3(0.2, 2.4, 0.2), o * CF(sx, 3.6, -0.7), WHITE, MAT.Metal) end
		stripes(m, o * CF(0, 4.9, 0), 3.4, 2.6, s[1], WHITE)
		local sb = P(m, V3(3, 0.8, 0.15), o * CF(0, 2.8, 1.05), WHITE)
		sb.Name = "StallSign"
		surfaceText(sb, Enum.NormalId.Back, s[2], s[1])
		s[3](m, o)
		m:SetAttribute("Stall", k)
	end
end
-- spinning rides
BUILD.carousel = function(m, o)
	cyl(m, 0.8, 11.4, o * CF(0, 0.4, 0), RGB(240, 230, 210), MAT.WoodPlanks, SOLID)
	P(m, V3(0.8, 7, 0.8), o * CF(0, 4.3, 0), GOLD, MAT.Foil)
	local r = rotatorModel(m, "Spinner", o * CF(0, 0, 0), "Y", 0.5)
	spinPart(cyl(r, 0.8, 11.8, o * CF(0, 7.9, 0), RGB(255, 80, 120), MAT.SmoothPlastic))
	spinPart(ball(r, V3(2, 2, 2), o * CF(0, 8.8, 0), GOLD, MAT.Foil))
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local at = o * CFrame.Angles(0, -a, 0) * CF(4, 0, 0)
		local horse = spinPart(P(r, V3(0.7, 1.4, 2), at * CF(0, 2.2, 0), Color3.fromHSV(k / 8, 0.35, 1), MAT.SmoothPlastic))
		spinPart(P(r, V3(0.6, 0.9, 0.7), at * CF(0, 3.1, -0.9), Color3.fromHSV(k / 8, 0.35, 1), MAT.SmoothPlastic))
		spinPart(P(r, V3(0.15, 6.2, 0.15), at * CF(0, 4.6, 0), GOLD, MAT.Foil))
		if k == 0 then horse.Name = "RideSeat" end
	end
	tag(r, "Rotator")
end
BUILD.teacups = function(m, o)
	cyl(m, 0.6, 11.6, o * CF(0, 0.3, 0), RGB(170, 210, 255), MAT.SmoothPlastic, SOLID)
	local r = rotatorModel(m, "Spinner", o, "Y", 0.7)
	spinPart(cyl(r, 0.3, 10, o * CF(0, 0.75, 0), RGB(255, 240, 250), MAT.SmoothPlastic))
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		local at = o * CFrame.Angles(0, -a, 0) * CF(3.2, 0, 0)
		local cup = spinPart(cyl(r, 1.8, 3, at * CF(0, 1.8, 0), Color3.fromHSV(k / 4 + 0.05, 0.45, 1), MAT.SmoothPlastic))
		spinPart(cyl(r, 0.4, 3.3, at * CF(0, 2.8, 0), WHITE, MAT.SmoothPlastic))
		if k == 0 then cup.Name = "RideSeat" end
	end
	tag(r, "Rotator")
end
BUILD.ferris = function(m, o)
	local R, hubY = 6.4, 8
	for _, sz in ipairs({-1.4, 1.4}) do
		for _, sx in ipairs({-4.5, 4.5}) do
			local a, b = (o * CF(sx, 0, sz)).Position, (o * CF(0, hubY, sz)).Position
			P(m, V3(0.6, 0.6, (b - a).Magnitude), CF((a + b) / 2, b), RGB(235, 235, 240), MAT.Metal, SOLID)
		end
	end
	local hub = o * CF(0, hubY, 0)
	local r = rotatorModel(m, "Wheel", hub, "Z", 0.25)
	spinPart(xcyl(r, 3, 1.4, hub * CFrame.Angles(0, math.rad(90), 0), RGB(200, 200, 210), MAT.Metal))
	local n = 10
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		spinPart(P(r, V3(0.25, R, 0.25), hub * CFrame.Angles(0, 0, a) * CF(0, R / 2, 0), WHITE, MAT.Metal))
		local nx = (k + 1) / n * math.pi * 2
		local p1, p2 = hub * V3(math.cos(a) * R, math.sin(a) * R, 0), hub * V3(math.cos(nx) * R, math.sin(nx) * R, 0)
		local rim = spinPart(P(r, V3(0.3, 0.3, (p2 - p1).Magnitude), CF((p1 + p2) / 2, p2), RGB(255, 210, 90), MAT.Neon))
		rim.Name = "Rim"
		local g = P(r, V3(1.4, 1.4, 1.6), CF(hub * V3(math.cos(a) * R, math.sin(a) * R - 1, 0)) * (o - o.Position), Color3.fromHSV(k / n, 0.6, 1), MAT.SmoothPlastic)
		g:SetAttribute("Kind", "gondola")
		g:SetAttribute("Hang", 1)
		if k == 0 then g.Name = "RideSeat" end
	end
	tag(r, "Rotator")
end
BUILD.swing = function(m, o)
	cyl(m, 0.6, 15.4, o * CF(0, 0.3, 0), RGB(200, 200, 210), MAT.Concrete, SOLID)
	cyl(m, 12, 1.6, o * CF(0, 6.4, 0), RGB(255, 170, 40), MAT.Metal, SOLID)
	local r = rotatorModel(m, "Top", o, "Y", 0.9)
	spinPart(cyl(r, 1, 8, o * CF(0, 12.6, 0), RGB(80, 160, 255), MAT.SmoothPlastic))
	spinPart(ball(r, V3(2, 2, 2), o * CF(0, 13.6, 0), GOLD, MAT.Foil))
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local base = o * CFrame.Angles(0, -a, 0)
		local top = base * CF(3.8, 12.1, 0)
		local seatPos = base * CF(6.4, 6.6, 0)
		local chain = spinPart(P(r, V3(0.12, (top.Position - seatPos.Position).Magnitude, 0.12), CF((top.Position + seatPos.Position) / 2, seatPos.Position) * CFrame.Angles(math.rad(90), 0, 0), RGB(200, 200, 205), MAT.Metal))
		chain.Name = "Chain"
		local seat = spinPart(P(r, V3(1, 0.4, 1), seatPos, Color3.fromHSV(k / 10, 0.6, 1), MAT.SmoothPlastic))
		if k == 0 then seat.Name = "RideSeat" end
	end
	tag(r, "Rotator")
end
BUILD.pirate = function(m, o)
	local pivotY = 10
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-2.6, 2.6}) do
			local a, b = (o * CF(sx * 3.4, 0, sz)).Position, (o * CF(0, pivotY + 0.6, sz * 0.4)).Position
			P(m, V3(0.8, 0.8, (b - a).Magnitude), CF((a + b) / 2, b), RGB(120, 80, 50), MAT.Wood, SOLID)
		end
	end
	xcyl(m, 3, 0.8, o * CF(0, pivotY, 0) * CFrame.Angles(0, math.rad(90), 0), DARK, MAT.Metal)
	local hub = o * CF(0, pivotY, 0)
	local r = rotatorModel(m, "Ship", hub, "Z", 0.9, "swing", {Amp = 1.05})
	for _, sx in ipairs({-1, 1}) do spinPart(P(r, V3(0.4, 6, 0.4), hub * CF(sx * 2.2, -3.2, 0) * CFrame.Angles(0, 0, sx * 0.35), RGB(90, 60, 40), MAT.Wood)) end
	local hull = spinPart(P(r, V3(13, 2.4, 3.4), hub * CF(0, -7.4, 0), RGB(120, 70, 40), MAT.WoodPlanks))
	hull.Name = "Hull"
	for _, sx in ipairs({-1, 1}) do spinPart(C.wedge(r, V3(3.4, 2.4, 2.2), hub * CF(sx * 7.6, -7.4, 0) * CFrame.Angles(0, sx * math.pi / 2, 0), RGB(120, 70, 40), MAT.WoodPlanks)) end
	spinPart(P(r, V3(0.3, 6, 0.3), hub * CF(0, -3.6, 1.2), RGB(90, 60, 40), MAT.Wood))
	local flag = spinPart(P(r, V3(2.4, 1.6, 0.1), hub * CF(1.2, -1.4, 1.2), DARK, MAT.Fabric))
	flag.Name = "Flag"
	local seat = spinPart(P(r, V3(1.2, 0.4, 1.2), hub * CF(-5, -6, 0), RGB(200, 40, 50), MAT.Fabric))
	seat.Name = "RideSeat"
	tag(r, "Rotator")
end
BUILD.bumper = function(m, o)
	P(m, V3(15.6, 0.4, 11.6), o * CF(0, 0.2, 0), RGB(60, 60, 70), MAT.DiamondPlate, SOLID)
	for _, s in ipairs({{0, 5.7, 15.6, 0.6}, {0, -5.7, 15.6, 0.6}, {7.7, 0, 0.6, 11.6}, {-7.7, 0, 0.6, 11.6}}) do
		P(m, V3(s[3], 1.2, s[4]), o * CF(s[1], 1, s[2]), RGB(255, 200, 40), MAT.SmoothPlastic, SOLID)
	end
	for _, sx in ipairs({-7.4, 7.4}) do
		for _, sz in ipairs({-5.4, 5.4}) do P(m, V3(0.4, 7, 0.4), o * CF(sx, 3.9, sz), DARK, MAT.Metal) end
	end
	P(m, V3(15.6, 0.3, 11.6), o * CF(0, 7.5, 0), RGB(40, 40, 50), MAT.Metal)
	for k = 0, 5 do P(m, V3(14, 0.1, 0.12), o * CF(0, 7.3, -5 + k * 2), RGB(255, 230, 120), MAT.Neon) end
	local r = rotatorModel(m, "Cars", o, "Y", 0.35)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local at = o * CFrame.Angles(0, -a, 0) * CF(3.6, 0, 0) * CFrame.Angles(0, math.rad(90 + k * 25), 0)
		local car = spinPart(P(r, V3(2.2, 1, 3), at * CF(0, 0.9, 0), Color3.fromHSV(k / 5, 0.75, 1), MAT.SmoothPlastic))
		spinPart(P(r, V3(2.6, 0.5, 3.4), at * CF(0, 0.6, 0), DARK, MAT.Fabric))
		spinPart(P(r, V3(0.1, 5.6, 0.1), at * CF(0, 4.2, 1.2), RGB(200, 200, 205), MAT.Metal))
		if k == 0 then car.Name = "RideSeat" end
	end
	tag(r, "Rotator")
end
BUILD.droptower = function(m, o)
	P(m, V3(7.4, 0.6, 7.4), o * CF(0, 0.3, 0), RGB(200, 200, 205), MAT.Concrete, SOLID)
	P(m, V3(2, 30, 2), o * CF(0, 15, 0), RGB(80, 160, 255), MAT.Metal, SOLID)
	ball(m, V3(3, 3, 3), o * CF(0, 31, 0), RGB(255, 80, 120), MAT.Neon).Name = "Beacon"
	local r = rotatorModel(m, "Ring", o * CF(0, 2, 0), "Y", 0.11, "drop", {Lift = 22})
	spinPart(P(r, V3(5.4, 1, 5.4), o * CF(0, 2.6, 0), RGB(255, 200, 40), MAT.SmoothPlastic))
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		local seat = spinPart(P(r, V3(1.4, 1.6, 0.8), o * CFrame.Angles(0, -a, 0) * CF(0, 2.4, -2.8), RGB(220, 40, 60), MAT.SmoothPlastic))
		if k == 0 then seat.Name = "RideSeat" end
	end
	tag(r, "Rotator")
end
-- coasters: control points in the footprint's frame (x along the long side), then smoothed, supports, a station
local COASTER = {
	junior = {
		ctrl = {{-8, 2, 4.5}, {0, 2, 4.5}, {7, 3.5, 4.5}, {10, 5, 1}, {9, 6, -3}, {3, 4, -5}, {-3, 2.4, -5}, {-8, 5, -4}, {-10.5, 3, 0}},
		cars = 2, color = RGB(120, 220, 90), lift = {0.1, 0.32}},
	loop = {
		ctrl = {{-12, 2, 7.5}, {-4, 2, 7.5}, {5, 9, 7.5}, {10, 14, 6}, {14, 12, 2}, {12, 4, -2}, {6, 2, -4}, {1, 2, -4.5},
			-- the loop
			{-2, 4, -5.4}, {-2.6, 9, -6.2}, {0, 12, -6.8}, {2.6, 9, -7.4}, {2, 4, -8.2}, {-3, 2, -8}, {-10, 3, -6}, {-14.5, 3, 0}},
		cars = 3, color = RGB(255, 80, 60), lift = {0.04, 0.25}},
}
PK.COASTER = COASTER
local function coasterPoints(cfg, o)
	local ctrl = {}
	for _, c in ipairs(cfg.ctrl) do table.insert(ctrl, (o * CF(c[1], c[2], c[3])).Position) end
	local pts = resample(catmull(ctrl, 8), 1.6)
	local n = #pts
	local liftA, liftB = math.floor(n * cfg.lift[1]) + 1, math.floor(n * cfg.lift[2])
	return pts, liftA, liftB
end
local function buildCoaster(cfg, m, o)
	local pts, liftA, liftB = coasterPoints(cfg, o)
	local fr = frames(pts)
	local n = #pts
	-- the track: one piece per segment (a two-rail bed) + supports to the ground
	local track = Instance.new("Model")
	track.Name = "Track"
	track.Parent = m
	for i = 1, n do
		local a, b = pts[i], pts[i % n + 1]
		local mid = (a + b) / 2
		local look = (b - a).Magnitude > 0.001 and (b - a).Unit or fr[i].look
		local up = fr[i].up
		local right = look:Cross(up)
		right = right.Magnitude > 0.001 and right.Unit or V3(1, 0, 0)
		up = right:Cross(look)
		local cf = CFrame.fromMatrix(mid, right, up, -look)
		P(track, V3(2.2, 0.25, (b - a).Magnitude + 0.15), cf, RGB(70, 70, 80), MAT.Metal).Name = "Bed"
		for _, sx in ipairs({-0.95, 0.95}) do P(track, V3(0.25, 0.3, (b - a).Magnitude + 0.15), cf * CF(sx, 0.25, 0), cfg.color, MAT.Metal) end
		if i % 4 == 0 and mid.Y > 1.4 and up.Y > 0.3 then
			P(track, V3(0.5, mid.Y - 0.1, 0.5), CF(mid.X, (mid.Y - 0.1) / 2, mid.Z), WHITE, MAT.Metal, SOLID).Name = "Support"
		end
	end
	-- the station platform where the ride starts
	local s0 = pts[1]
	local plat = P(m, V3(3.2, 1.2, cfg.station or 7), CF(s0.X, 0.6, s0.Z) * CFrame.lookAt(V3(), fr[1].look * V3(1, 0, 1) + V3(0, 0, 0.001)) * CF(-2.8, 0, 0), RGB(200, 200, 205), MAT.Concrete, SOLID)
	plat.Name = "Station"
	-- the train: cars of parts, each with its offset in the car's frame (EmpireClient > ParkFX moves them)
	local train = Instance.new("Model")
	train.Name = "Train"
	train.Parent = m
	train:SetAttribute("Pts", packPts(pts))
	local T, cycle = timing(pts, liftA, liftB)
	train:SetAttribute("LiftA", liftA)
	train:SetAttribute("LiftB", liftB)
	train:SetAttribute("Cycle", cycle)
	train:SetAttribute("Gap", 3.4)
	train:SetAttribute("Phase", cfg.phase or (m:GetAttribute("ItemId") or 0) * 1.7)
	for c = 0, cfg.cars - 1 do
		local idx = (1 - c * 2 - 1) % n + 1
		local p, f = pts[idx], fr[idx]
		local right = f.look:Cross(f.up).Unit
		local carCF = CFrame.fromMatrix(p, right, right:Cross(f.look), -f.look)
		local function cp(size, off, color, mat, name)
			local part = P(train, size, carCF * off, color, mat)
			part:SetAttribute("Car", c)
			part:SetAttribute("Off", off)
			if name then part.Name = name end
			return part
		end
		local body = cp(V3(2, 1, 2.8), CF(0, 0.85, 0), cfg.color, MAT.SmoothPlastic, c == 0 and "RideSeat" or "Car")
		cp(V3(2, 1, 0.3), CF(0, 1.5, 1.2), cfg.color:Lerp(DARK, 0.3), MAT.SmoothPlastic)
		cp(V3(1.6, 0.4, 1.4), CF(0, 1.2, 0.2), DARK, MAT.Fabric)
		if c == 0 then cp(V3(1.6, 0.6, 0.3), CF(0, 1.1, -1.4), GOLD, MAT.Foil) end
		local _ = body
	end
	tag(train, "TrackMover")
	return pts, cycle
end
BUILD.junior = function(m, o) buildCoaster(COASTER.junior, m, o) end
BUILD.loop = function(m, o) buildCoaster(COASTER.loop, m, o) end
-- (the Fun Park's own rides use the same builders: GameServer > FunPark)
C.PARK_BUILD = BUILD
PK.buildCoaster = buildCoaster

-- =====================================================================
-- SITES: who builds where
-- =====================================================================
local siteOf = {}   -- [plr] = site
function F.parkSite(plr) return siteOf[plr] end
local function buildItem(site, d, it)
	local def = ITEM[it.k]
	local x, z, w, h = footprint(def, it.x, it.z, it.r)
	local o = cellCF(site, x, z, w, h, it.r)
	local m = Instance.new("Model")
	m.Name = "Item_" .. it.id
	m:SetAttribute("ItemId", it.id)
	m:SetAttribute("Kind", it.k)
	m:SetAttribute("Cell", x .. "," .. z)
	m:SetAttribute("Size", w .. "," .. h)
	m.Parent = site.items
	local ok, err = pcall(BUILD[it.k], m, o)
	if not ok then warn("[Park] couldn't build " .. it.k .. ": " .. tostring(err)) end
	if def.kind == "ride" then
		-- the ride's prompt at the footprint's front edge (towards the gate)
		local spot = P(m, V3(1, 1, 1), site.cf * CF(x * PK.cell + 1, 2.5, (z + h / 2) * PK.cell), WHITE, MAT.SmoothPlastic, {Transparency = 1, Name = "RideSpot"})
		local owner = site.owner
		C.prompt(spot, def.icon .. " Ride", def.name, 16, 0, function(who)
			if F.parkRide then F.parkRide(who, owner, it.id) end
		end)
	end
	site.models[it.id] = m
	return m
end
local function clearItems(site)
	if site.items then site.items:ClearAllChildren() end
	site.models = {}
end
local function buildAll(site, d)
	site.d = d
	clearItems(site)
	for _, it in ipairs(rec(d).items) do buildItem(site, d, it) end
	refreshSign(site)
end
function F.parkEnsure(plr)
	local d = data[plr]
	if not d or (d.levels.park or 0) <= 0 then return nil end
	local mine = siteOf[plr]
	if mine then
		-- (another save slot was loaded: build that save's park)
		if mine.d ~= d then buildAll(mine, d) end
		return mine
	end
	for _, site in ipairs(SITES) do
		if not site.owner then
			site.owner = plr
			siteOf[plr] = site
			buildAll(site, d)
			return site
		end
	end
	return nil
end
local function release(plr)
	local site = siteOf[plr]
	if not site then return end
	siteOf[plr] = nil
	site.owner = nil
	clearItems(site)
	refreshSign(site)
end
F.parkRelease = release

-- ===== placing =====
local function occupied(d, skipId)
	local used = {}
	for _, it in ipairs(rec(d).items) do
		if it.id ~= skipId then
			local x, z, w, h = footprint(ITEM[it.k], it.x, it.z, it.r)
			for cx = x, x + w - 1 do
				for cz = z, z + h - 1 do used[cx * 100 + cz] = it.id end
			end
		end
	end
	return used
end
-- can this piece go here? (nil, why) or true
function F.parkCanPlace(d, k, x, z, r, skipId)
	local def = ITEM[k]
	if not def then return false, "That's not something you can build." end
	if not (C.int(x, 0, PK.gw - 1) and C.int(z, 0, PK.gh - 1) and C.int(r, 0, 3)) then return false, "That's outside your site." end
	local _, _, w, h = footprint(def, x, z, r)
	if x + w > PK.gw or z + h > PK.gh then return false, "It doesn't fit there: too close to the edge." end
	if x == 0 and z <= PK.gate[2] and z + h - 1 >= PK.gate[1] then
		if def.kind ~= "path" then return false, "Keep the gate clear (paths are fine)." end
	end
	local used = occupied(d, skipId)
	for cx = x, x + w - 1 do
		for cz = z, z + h - 1 do
			if used[cx * 100 + cz] then return false, "Something is already built there." end
		end
	end
	return true
end
function F.parkPlace(plr, k, x, z, r)
	local d = data[plr]
	local def = ITEM[k]
	if not (d and def) then return false end
	if (d.levels.park or 0) <= 0 then notify(plr, "🎢 Open your Amusement Park first.") return false end
	local site = F.parkEnsure(plr)
	if not site then notify(plr, "🎢 Every Funland site is taken in this server right now.") return false end
	local p = rec(d)
	if (d.levels.park or 0) < def.lvl then notify(plr, "🔒 " .. def.name .. " unlocks at park level " .. def.lvl .. ".") return false end
	if #p.items >= itemCap(d) then notify(plr, "🎢 Your park holds " .. itemCap(d) .. " pieces at this level. Upgrade the park for more room.") return false end
	local ok, why = F.parkCanPlace(d, k, x, z, r)
	if not ok then notify(plr, "🎢 " .. why) return false end
	if d.cash < def.cost then notify(plr, "🎢 " .. def.name .. " costs $" .. fmt(def.cost) .. ".") return false end
	d.cash -= def.cost
	p.seq += 1
	local it = {id = p.seq, k = k, x = x, z = z, r = r}
	table.insert(p.items, it)
	buildItem(site, d, it)
	refreshSign(site)
	if def.kind == "ride" then
		C.burst((cellCF(site, footprint(def, x, z, r)) * CF(0, 6, 0)).Position, BIZ.park.color, 40)
		if F.track then F.track(plr, "parkBuild") end
	end
	return true, it
end
local function findItem(d, id)
	for i, it in ipairs(rec(d).items) do if it.id == id then return it, i end end
end
function F.parkMove(plr, id, x, z, r)
	local d = data[plr]
	local site = siteOf[plr]
	if not (d and site and C.int(id, 1)) then return false end
	local it = findItem(d, id)
	if not it then return false end
	local ok, why = F.parkCanPlace(d, it.k, x, z, r, id)
	if not ok then notify(plr, "🎢 " .. why) return false end
	it.x, it.z, it.r = x, z, r
	if site.models[id] then site.models[id]:Destroy() end
	buildItem(site, d, it)
	return true
end
function F.parkSell(plr, id)
	local d = data[plr]
	local site = siteOf[plr]
	if not (d and site and C.int(id, 1)) then return false end
	local it, i = findItem(d, id)
	if not it then return false end
	local def = ITEM[it.k]
	table.remove(d.park.items, i)
	local back = math.floor(def.cost * PK.sellBack)
	d.cash += back
	if site.models[id] then site.models[id]:Destroy() end
	site.models[id] = nil
	refreshSign(site)
	notify(plr, "🎢 Sold the " .. def.name .. " for $" .. fmt(back) .. ".")
	return true
end

-- ===== riding =====
local riding, rodeAt, repHour = {}, {}, {}
-- play a ride for one player: checks they're free and close enough, holds them in place, the client's camera
-- rides the model's RideSeat for dur seconds. Returns true or false, why.
function F.playRide(plr, m, spot, dur, show)
	if riding[plr] then return false, "busy" end
	if os.clock() - (rodeAt[plr] or -1e9) < PK.rideCooldown then return false, "cooldown" end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and spot and m and m.Parent) then return false, "missing" end
	if (root.Position - spot.Position).Magnitude > PK.rideRange then return false, "far" end
	dur = math.clamp(dur or 15, 5, PK.rideMax)
	riding[plr] = true
	rodeAt[plr] = os.clock()
	local back = root.CFrame
	root.Anchored = true
	show.model, show.dur = m, dur
	R.Menu:FireClient(plr, "parkRide", show)
	if F.track then F.track(plr, "ride") end
	task.delay(dur, function()
		riding[plr] = nil
		if root.Parent then
			root.Anchored = false
			root.CFrame = back
		end
	end)
	return true
end
function F.parkRide(plr, owner, id)
	local d, od = data[plr], owner and data[owner]
	local site = owner and siteOf[owner]
	if not (d and od and site and C.int(id, 1)) then return false end
	local m = site.models[id]
	local it = findItem(od, id)
	if not (m and m.Parent and it) then return false end
	local def = ITEM[it.k]
	if def.kind ~= "ride" then return false end
	local dur = def.dur
	if def.coaster then
		local train = m:FindFirstChild("Train")
		dur = train and train:GetAttribute("Cycle") or 20
	end
	local ok = F.playRide(plr, m, m:FindFirstChild("RideSpot"), dur, {name = def.name, icon = def.icon, coaster = def.coaster == true, owner = owner.Name})
	if not ok then return false end
	local op = rec(od)
	op.rides += 1
	if plr ~= owner then
		op.guestRides += 1
		-- the owner earns a ticket (and a little reputation, a few times an hour)
		local ticket = math.floor(math.max(BIZ.park.income, (F.incomePerSec and F.incomePerSec(od) or 0) * 0.05) * PK.ticketSecs)
		od.cash += ticket
		local h = math.floor(os.time() / 3600)
		repHour[owner] = (repHour[owner] and repHour[owner].h == h) and repHour[owner] or {h = h, n = 0}
		if repHour[owner].n < PK.guestRepPerHour then
			repHour[owner].n += 1
			F.addRep(owner, PK.guestRep)
		end
		notify(owner, "🎟️ " .. plr.Name .. " rode your " .. def.icon .. " " .. def.name .. ": +$" .. fmt(ticket))
	end
	return true
end

-- ===== info for the app =====
function F.parkInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local open = (d.levels.park or 0) > 0
	local p = rec(d)
	local site = open and F.parkEnsure(plr) or nil
	local rating, parts, counts = F.parkScore(d)
	local info = {open = open, level = d.levels.park or 0, cost = F.upgradeCost(d, "park"), unlocked = F.bizUnlocked(d, "park"), need = C.REP_TIERS[BIZ.park.unlock].name,
		hasPlot = F.siteDeed and F.siteDeed(d, "park") ~= nil, site = site and site.i or nil, gw = PK.gw, gh = PK.gh, gate = PK.gate, cash = d.cash,
		rating = rating, mult = F.parkMult(d, "park"), parts = {}, counts = counts, cap = itemCap(d), visitors = p.visitors, rides = p.rides, guestRides = p.guestRides,
		items = {}, shop = {}, name = F.bizName and F.bizName(d, "park") or BIZ.park.name}
	for _, x in ipairs(parts) do table.insert(info.parts, {x[1], x[2]}) end
	for _, it in ipairs(p.items) do
		local def = ITEM[it.k]
		local _, _, w, h = footprint(def, it.x, it.z, it.r)
		table.insert(info.items, {id = it.id, k = it.k, x = it.x, z = it.z, r = it.r, w = w, h = h, icon = def.icon, name = def.name, kind = def.kind})
	end
	for _, def in ipairs(ITEMS) do
		table.insert(info.shop, {k = def.k, name = def.name, icon = def.icon, kind = def.kind, w = def.w, h = def.h, cost = def.cost, lvl = def.lvl, excite = def.excite,
			desc = def.desc, locked = (d.levels.park or 0) < def.lvl})
	end
	return info
end

C.ACTIONS = C.ACTIONS or {}
local function sendInfo(plr)
	local info = F.parkInfo(plr)
	if info then R.Menu:FireClient(plr, "park", info) end
end
C.ACTIONS.parkInfo = function(plr) sendInfo(plr) end
C.ACTIONS.parkPlace = function(plr, d, a, b, c)
	-- a = item key, b = {x, z, r}
	if C.str(a, 20) and type(b) == "table" then
		F.parkPlace(plr, a, b[1], b[2], b[3])
		sendInfo(plr)
	end
end
C.ACTIONS.parkMove = function(plr, d, a, b)
	if type(b) == "table" then
		F.parkMove(plr, a, b[1], b[2], b[3])
		sendInfo(plr)
	end
end
C.ACTIONS.parkSell = function(plr, d, a, b)
	-- selling needs the confirm flag from the client's dialog
	if b == true then
		F.parkSell(plr, a)
		sendInfo(plr)
	end
end
C.ACTIONS.parkGo = function(plr, d, a)
	-- to your own site, or (a = a player's UserId) to theirs
	local target = plr
	if C.int(a, 1) then target = Players:GetPlayerByUserId(a) end
	local site = target and (target == plr and F.parkEnsure(plr) or siteOf[target])
	local char = plr.Character
	if site and char then
		if F.despawnCar then F.despawnCar(plr) end
		char:PivotTo(site.cf * CF(-5, 4, (PK.gate[1] + PK.gate[2] + 1) / 2 * PK.cell) * CFrame.Angles(0, -math.pi / 2, 0))
	elseif not site then
		notify(plr, "🎢 " .. (target == plr and "Open your Amusement Park first." or "That park isn't open right now."))
	end
end
-- the list of parks open in this server (for the app's "visit" row)
C.ACTIONS.parkList = function(plr)
	local out = {}
	for _, site in ipairs(SITES) do
		if site.owner and data[site.owner] then
			table.insert(out, {userId = site.owner.UserId, name = site.owner.Name, park = F.bizName and F.bizName(data[site.owner], "park") or BIZ.park.name,
				rating = (F.parkScore(data[site.owner])), site = site.i})
		end
	end
	R.Menu:FireClient(plr, "parkList", out)
end

-- ===== the park's day: visitors counted, signs kept fresh, sites handed out =====
task.spawn(function()
	local t = 0
	while true do
		task.wait(2)
		t += 2
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			if siteOf[plr] and (not d or (d.levels.park or 0) <= 0) then
				-- (a rebirth, or a save slot without a park: the site goes back to the pool; the park stays in the save)
				release(plr)
			end
			if d and (d.levels.park or 0) > 0 then
				local site = F.parkEnsure(plr)
				if site and t % PK.statEvery == 0 then
					local p = rec(d)
					local rating = F.parkScore(d)
					local v = math.floor(rating * (1 + (d.levels.park or 0) * 0.3) / 4)
					p.visitors += v
					p.best = math.max(p.best, rating)
					refreshSign(site)
				end
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	release(plr)
	riding[plr], rodeAt[plr], repHour[plr] = nil, nil, nil
end)
end
