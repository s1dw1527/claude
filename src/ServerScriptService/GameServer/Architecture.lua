-- ARCHITECTURE (v19): one place that decides what buildings LOOK like, per style. Districts ask for a style
-- ("restaurant", "neon", "glass"...) and get a building with its own materials, colors, roof, windows, awning,
-- sign and extras; change a style here and every building of that style changes. Every building is a handful of
-- parts (a body, window bands, a cornice, a storefront, an awning, a sign, a few extras), so a whole district stays
-- cheap. Windows are tagged "NightWindow": players' clients light them warm at night (EmpireClient > WorldFX),
-- so dusk costs no network traffic and no server work.
--   C.ARCH_STYLES[key] = {walls = {colors}, mat, trim, glass, floor (height of a storey), maxExtra (storeys a building
--     may add above its base height, for variety), awnings = {colors} or nil,
--     roof = "parapet" | "flat" | "gable" | "crown", storefront = true/false, extras = {"seating", "neon", ...}}
--   C.archBuild(parent, o, w, d, h, key, opts) -> top height. o = the CFrame of the footprint's centre on the
--     ground, FRONT = local +Z. opts = {seed = number, sign = "text", signColor, banner = "text", bannerColor}
return function(C)
local RGB, V3, CF, MAT = Color3.fromRGB, Vector3.new, CFrame.new, Enum.Material
local P, wedge, cyl = C.P, C.wedge, C.cyl

C.ARCH_STYLES = {
	-- Midtown • Restaurant Row: brick and stucco, striped awnings, tables outside
	restaurant = {walls = {RGB(170, 80, 60), RGB(205, 150, 95), RGB(130, 60, 55), RGB(225, 200, 160), RGB(95, 110, 85)}, mat = MAT.Brick,
		trim = RGB(245, 235, 215), glass = RGB(60, 75, 95), floor = 9, roof = "parapet", storefront = true,
		awnings = {RGB(200, 45, 50), RGB(40, 120, 70), RGB(230, 160, 40), RGB(40, 90, 160), RGB(120, 40, 90)}, extras = {"seating", "menu", "lights"}},
	-- Entertainment District: dark walls, neon trim, marquee-style signs
	neon = {walls = {RGB(45, 30, 70), RGB(30, 35, 60), RGB(60, 25, 55)}, mat = MAT.SmoothPlastic, trim = RGB(255, 80, 200), glass = RGB(40, 30, 70),
		floor = 10, roof = "flat", roofColor = RGB(38, 32, 50), storefront = true, maxExtra = 1, neonTrim = {RGB(255, 70, 200), RGB(80, 220, 255), RGB(255, 210, 60), RGB(140, 255, 120)}, extras = {"neon"}},
	-- Northside Suburbs: small painted shops with gable roofs
	shop = {walls = {RGB(235, 225, 200), RGB(190, 215, 225), RGB(225, 200, 200), RGB(210, 225, 190)}, mat = MAT.WoodPlanks,
		trim = RGB(250, 250, 245), glass = RGB(70, 90, 110), floor = 8, roof = "gable", maxExtra = 1, roofColors = {RGB(150, 70, 55), RGB(70, 80, 100), RGB(90, 110, 80)},
		storefront = true, awnings = {RGB(70, 130, 190), RGB(200, 90, 80), RGB(90, 160, 100)}, extras = {"planters"}},
	-- Downtown: glass and steel
	glass = {walls = {RGB(70, 110, 160), RGB(60, 90, 130), RGB(110, 140, 170), RGB(80, 100, 120)}, mat = MAT.Glass, trim = RGB(220, 225, 235),
		glass = RGB(40, 60, 90), floor = 7, roof = "crown", storefront = true},
	-- Expansion District: going up (scaffolding and a crane arm)
	construction = {walls = {RGB(165, 160, 150), RGB(150, 150, 155)}, mat = MAT.Concrete, trim = RGB(240, 170, 40), glass = RGB(80, 85, 95),
		floor = 8, roof = "flat", roofColor = RGB(120, 120, 125), storefront = false, maxExtra = 2, extras = {"scaffold"}},
	-- Industrial: sheds with a roller door and a loading dock
	shed = {walls = {RGB(150, 115, 90), RGB(120, 125, 130), RGB(140, 100, 80)}, mat = MAT.CorrugatedSteel, trim = RGB(240, 180, 40), glass = RGB(70, 75, 80),
		floor = 9, roof = "flat", roofColor = RGB(110, 112, 118), storefront = false, maxExtra = 0, extras = {"dock"}},
	-- Waterfront: beach houses on stilts, pastel and white
	beach = {walls = {RGB(250, 245, 235), RGB(190, 230, 235), RGB(250, 220, 200), RGB(220, 240, 210)}, mat = MAT.WoodPlanks, trim = RGB(255, 255, 255),
		glass = RGB(80, 150, 180), floor = 8, roof = "gable", maxExtra = 1, roofColors = {RGB(60, 150, 190), RGB(230, 120, 90)}, storefront = true,
		awnings = {RGB(60, 170, 200), RGB(250, 150, 90)}, extras = {"umbrella"}},
}
C.ARCH_COUNT = 0   -- (parts made by the kit, for the budget check in world_test)
local function pick(list, seed, salt) return list[((seed or 1) + (salt or 0)) % #list + 1] end
local function part(parent, size, cf, color, mat, props)
	C.ARCH_COUNT += 1
	return P(parent, size, cf, color, mat, props)
end
local function window(parent, size, cf, glass)
	local w = part(parent, size, cf, glass, MAT.Glass, {Reflectance = 0.15, CastShadow = false})
	w.Name = "Window"
	C.tag(w, "NightWindow")
	return w
end

function C.archBuild(parent, o, w, d, h, key, opts)
	opts = opts or {}
	local st = C.ARCH_STYLES[key] or C.ARCH_STYLES.shop
	local seed = opts.seed or 1
	local wall = pick(st.walls, seed)
	local SOLID = {CanCollide = true}
	-- the body (a little narrower than the footprint, set back from the front)
	part(parent, V3(w, h, d), o * CF(0, h / 2, 0), wall, st.mat, SOLID)
	-- window bands on the front and the two sides, one per storey (the ground floor is the storefront)
	local floors = math.max(1, math.floor(h / st.floor))
	for f = 1, floors - 1 do
		local y = f * st.floor + st.floor * 0.5
		if y < h - 1.5 then
			window(parent, V3(w - 2, st.floor * 0.45, 0.3), o * CF(0, y, d / 2 + 0.05), st.glass)
			for _, sx in ipairs({-1, 1}) do window(parent, V3(0.3, st.floor * 0.45, d - 2), o * CF(sx * (w / 2 + 0.05), y, 0), st.glass) end
			if key == "glass" then part(parent, V3(w + 0.4, 0.4, d + 0.4), o * CF(0, f * st.floor, 0), st.trim, MAT.Metal) end
		end
	end
	-- the roof
	if st.roof == "parapet" then
		part(parent, V3(w + 0.8, 1.2, d + 0.8), o * CF(0, h + 0.6, 0), st.trim, MAT.Concrete)
		part(parent, V3(2.4, 1.6, 2.4), o * CF(w * 0.2, h + 2, -d * 0.2), RGB(180, 185, 190), MAT.Metal)   -- AC unit
	elseif st.roof == "gable" then
		local rc = pick(st.roofColors or {RGB(120, 60, 50)}, seed, 1)
		local rh = math.min(h * 0.3 + 1.5, 5.5)
		wedge(parent, V3(w + 1, rh, d / 2 + 0.6), o * CF(0, h + rh / 2, d / 4 + 0.15) * CFrame.Angles(0, math.pi, 0), rc, MAT.Slate)
		wedge(parent, V3(w + 1, rh, d / 2 + 0.6), o * CF(0, h + rh / 2, -d / 4 - 0.15), rc, MAT.Slate)
		C.ARCH_COUNT += 2
	elseif st.roof == "crown" then
		part(parent, V3(w * 0.7, 3, d * 0.7), o * CF(0, h + 1.5, 0), st.trim, MAT.Metal)
		part(parent, V3(w * 0.4, 4, d * 0.4), o * CF(0, h + 5, 0), wall, MAT.Glass, {Reflectance = 0.2})
		part(parent, V3(0.6, 8, 0.6), o * CF(0, h + 11, 0), RGB(200, 200, 210), MAT.Metal)
		local beacon = part(parent, V3(1, 1, 1), o * CF(0, h + 15.3, 0), RGB(255, 60, 60), MAT.Neon)
		beacon.Shape = Enum.PartType.Ball
	else
		part(parent, V3(w + 0.4, 0.8, d + 0.4), o * CF(0, h + 0.4, 0), st.roofColor or st.trim, MAT.Concrete)
	end
	-- the storefront: a big window, a door and a sign board above
	if st.storefront then
		window(parent, V3(w - 4, st.floor * 0.55, 0.3), o * CF(-1, st.floor * 0.4, d / 2 + 0.06), st.glass)
		part(parent, V3(2.4, st.floor * 0.7, 0.3), o * CF(w / 2 - 2.2, st.floor * 0.35, d / 2 + 0.1), RGB(70, 50, 40), MAT.Wood)
		local sign = part(parent, V3(w - 2, 2, 0.4), o * CF(0, st.floor * 0.85 + 0.6, d / 2 + 0.25), opts.bannerColor or st.trim, MAT.SmoothPlastic)
		sign.Name = "ArchSign"
		if opts.sign or opts.banner then
			C.surfaceText(sign, Enum.NormalId.Front, opts.banner or opts.sign, opts.signColor or RGB(30, 30, 40))
		end
		if st.awnings then
			local aw = wedge(parent, V3(w - 1, 1.6, 3.2), o * CF(0, st.floor * 0.85 - 0.6, d / 2 + 1.7) * CFrame.Angles(0, math.pi, 0), pick(st.awnings, seed, 2), MAT.Fabric)
			aw.CanCollide = false
			C.ARCH_COUNT += 1
		end
		if st.neonTrim then
			local nc = pick(st.neonTrim, seed, 3)
			part(parent, V3(w + 0.2, 0.35, 0.35), o * CF(0, st.floor * 0.85 + 1.8, d / 2 + 0.3), nc, MAT.Neon)
			part(parent, V3(0.35, h, 0.35), o * CF(-w / 2 - 0.1, h / 2, d / 2 + 0.1), nc, MAT.Neon)
			part(parent, V3(0.35, h, 0.35), o * CF(w / 2 + 0.1, h / 2, d / 2 + 0.1), nc, MAT.Neon)
		end
	elseif opts.banner then
		local sign = part(parent, V3(w - 4, 2.4, 0.4), o * CF(0, h - 2, d / 2 + 0.25), opts.bannerColor or st.trim, MAT.SmoothPlastic)
		sign.Name = "ArchSign"
		C.surfaceText(sign, Enum.NormalId.Front, opts.banner, opts.signColor or RGB(30, 30, 40))
	end
	-- extras (in front of the building, inside the footprint, clear of the doorway)
	for _, ex in ipairs(st.extras or {}) do
		if ex == "seating" then
			for i, sx in ipairs({-w / 2 + 3, -w / 2 + 8}) do
				local z = d / 2 + 3.2
				part(parent, V3(2.4, 0.3, 2.4), o * CF(sx, 2.4, z), RGB(240, 240, 235), MAT.SmoothPlastic)
				part(parent, V3(0.3, 2.4, 0.3), o * CF(sx, 1.2, z), RGB(60, 60, 60), MAT.Metal)
				part(parent, V3(0.25, 4.6, 0.25), o * CF(sx, 2.3, z), RGB(80, 80, 80), MAT.Metal)
				local um = part(parent, V3(4.6, 0.4, 4.6), o * CF(sx, 4.8, z), pick(st.awnings, seed, 2 + i), MAT.Fabric)
				um.CanCollide = false
			end
		elseif ex == "menu" then
			part(parent, V3(1.6, 2.6, 0.3), o * CF(w / 2 - 5, 1.3, d / 2 + 2.4) * CFrame.Angles(math.rad(-12), 0, 0), RGB(40, 40, 40), MAT.Slate)
		elseif ex == "lights" then
			-- a string of warm bulbs along the awning (lit at night with the windows)
			local s = part(parent, V3(w - 1, 0.25, 0.25), o * CF(0, st.floor * 0.85 - 1.5, d / 2 + 3.1), RGB(255, 225, 160), MAT.SmoothPlastic, {CastShadow = false})
			s.Name = "BulbString"
			C.tag(s, "NightWindow")
		elseif ex == "planters" then
			for _, sx in ipairs({-w / 2 + 1.5, w / 2 - 4.5}) do
				part(parent, V3(2, 1.2, 1.2), o * CF(sx, 0.6, d / 2 + 1.2), RGB(120, 85, 60), MAT.Wood)
				part(parent, V3(1.8, 1, 1), o * CF(sx, 1.6, d / 2 + 1.2), RGB(80, 160, 80), MAT.Grass)
			end
		elseif ex == "scaffold" then
			for _, sx in ipairs({-w / 2 - 0.8, w / 2 + 0.8}) do part(parent, V3(0.4, h + 4, 0.4), o * CF(sx, (h + 4) / 2, d / 2 + 1), RGB(240, 170, 40), MAT.Metal) end
			for y = 4, h, 6 do part(parent, V3(w + 2, 0.3, 1.6), o * CF(0, y, d / 2 + 1), RGB(150, 110, 70), MAT.WoodPlanks) end
			if seed % 3 == 0 then   -- (a crane on every third site)
				part(parent, V3(0.8, h + 14, 0.8), o * CF(-w / 2 + 2, (h + 14) / 2, -d / 2 + 2), RGB(240, 180, 30), MAT.Metal)
				part(parent, V3(1, 1, w + 6), o * CF(-w / 2 + 2, h + 14, 1), RGB(240, 180, 30), MAT.Metal)
			end
		elseif ex == "dock" then
			part(parent, V3(w * 0.6, h * 0.6, 0.3), o * CF(0, h * 0.3, d / 2 + 0.1), RGB(190, 195, 200), MAT.DiamondPlate)
			part(parent, V3(w * 0.7, 1.2, 3), o * CF(0, 0.6, d / 2 + 1.6), RGB(140, 140, 145), MAT.Concrete, {CanCollide = true})
			for _, sx in ipairs({-w * 0.35 - 0.5, w * 0.35 + 0.5}) do part(parent, V3(0.6, 3, 0.6), o * CF(sx, 1.5, d / 2 + 3), RGB(240, 200, 40), MAT.SmoothPlastic) end
		elseif ex == "umbrella" then
			part(parent, V3(0.25, 4, 0.25), o * CF(-w / 2 + 3, 2, d / 2 + 3), RGB(240, 240, 240), MAT.Wood)
			local um = part(parent, V3(4.4, 0.4, 4.4), o * CF(-w / 2 + 3, 4.1, d / 2 + 3), pick(st.awnings, seed, 5), MAT.Fabric)
			um.CanCollide = false
		end
	end
	local top = h + (st.roof == "crown" and 16 or (st.roof == "gable" and math.min(h * 0.3 + 1.5, 5.5) or 1.5))
	return top
end

-- how tall a building of this style is: its base height plus 0..maxExtra storeys, picked from the seed
function C.archHeight(key, base, seed)
	local st = C.ARCH_STYLES[key] or C.ARCH_STYLES.shop
	local extra = st.maxExtra == nil and 2 or st.maxExtra
	return base + ((seed or 1) * 7 % (extra + 1)) * st.floor
end
-- ===== streets inside a district: sidewalks, trees, lamps and (Restaurant Row) strings of lights across =====
-- axis "x": the street runs along X at z = c, from a to b, w wide. opts = {lights = true, trees = true, walk = color}
function C.archStreet(parent, axis, c, a, b, w, opts)
	opts = opts or {}
	local len, mid = b - a, (a + b) / 2
	local function at(along, across, y)
		if axis == "x" then return V3(along, y, c + across) end
		return V3(c + across, y, along)
	end
	local function size(along, across, y)
		if axis == "x" then return V3(along, y, across) end
		return V3(across, y, along)
	end
	if opts.asphalt then part(parent, size(len, w, 0.12), CF(at(mid, 0, 0.2)), RGB(60, 62, 68), MAT.Asphalt) end
	for _, side in ipairs({-1, 1}) do
		part(parent, size(len, 4, 0.4), CF(at(mid, side * (w / 2 + 2), 0.25)), opts.walk or RGB(200, 196, 188), MAT.Concrete)
		part(parent, size(len, 0.4, 0.5), CF(at(mid, side * (w / 2 + 0.2), 0.3)), RGB(160, 160, 166), MAT.Concrete)
	end
	local n = 0
	for v = a + 10, b - 10, 22 do
		n += 1
		local side = (n % 2 == 0) and 1 or -1
		if opts.trees ~= false then
			local t = at(v, side * (w / 2 + 3), 0)
			part(parent, V3(1.6, 0.6, 1.6), CF(t + V3(0, 0.5, 0)), RGB(110, 90, 70), MAT.Wood)
			part(parent, V3(0.6, 5, 0.6), CF(t + V3(0, 3, 0)), RGB(110, 80, 55), MAT.Wood)
			local crown = part(parent, V3(4.5, 4, 4.5), CF(t + V3(0, 6.6, 0)), RGB(70, 150, 70), MAT.Grass)
			crown.Shape = Enum.PartType.Ball
		end
		if opts.lights and n % 2 == 1 then
			-- poles on both sidewalks and a warm string of bulbs across the street
			for _, sd in ipairs({-1, 1}) do part(parent, V3(0.4, 10, 0.4), CF(at(v, sd * (w / 2 + 3.6), 5)), RGB(50, 50, 55), MAT.Metal) end
			local bulbs = part(parent, size(0.3, w + 7.2, 0.3), CF(at(v, 0, 9.4)), RGB(255, 225, 160), MAT.SmoothPlastic, {CastShadow = false})
			bulbs.Name = "BulbString"
			C.tag(bulbs, "NightWindow")
		end
	end
end
-- fictional restaurants and cafés the city runs itself (decoration: they make Restaurant Row feel alive)
C.ROW_NAMES = {"Nonna's Kitchen", "Golden Wok", "Taco Corner", "Bean There", "Sweet Crumbs", "Burger Barn", "Sushi Wave", "The Noodle Bar",
	"Pancake Palace", "Curry Leaf", "Big Slice Pizza", "Café Soleil", "Smoky's BBQ", "Dumpling House", "Gelato Bros", "Fry Day"}

-- ===== a small park: lawn, crossing paths, trees, benches and a fountain in the middle =====
function C.archPark(parent, cx, cz, w, d, opts)
	opts = opts or {}
	part(parent, V3(w, 0.4, d), CF(cx, 0.22, cz), RGB(96, 170, 96), MAT.Grass)
	part(parent, V3(w, 0.45, 3), CF(cx, 0.24, cz), RGB(205, 195, 175), MAT.Cobblestone)
	part(parent, V3(3, 0.45, d), CF(cx, 0.24, cz), RGB(205, 195, 175), MAT.Cobblestone)
	-- the fountain
	cyl(parent, 1.4, 9, CF(cx, 0.7, cz), RGB(200, 200, 205), MAT.Marble)
	C.ARCH_COUNT += 1
	local water = cyl(parent, 0.3, 7.6, CF(cx, 1.35, cz), RGB(90, 170, 230), MAT.Glass)
	water.Transparency = 0.25
	cyl(parent, 3.6, 1.2, CF(cx, 2.4, cz), RGB(200, 200, 205), MAT.Marble)
	C.ARCH_COUNT += 2
	part(parent, V3(1, 1, 1), CF(cx, 4.4, cz), RGB(200, 200, 205), MAT.Marble)
	-- trees in the four quarters, benches by the paths
	for _, qx in ipairs({-1, 1}) do
		for _, qz in ipairs({-1, 1}) do
			for k = 1, opts.trees or 2 do
				local tx = cx + qx * (w / 2) * (0.25 + 0.4 * (k - 1) / math.max(1, (opts.trees or 2) - 1))
				local tz = cz + qz * d * 0.25
				part(parent, V3(0.8, 6, 0.8), CF(tx, 3, tz), RGB(110, 80, 55), MAT.Wood)
				local crown = part(parent, V3(6, 5.5, 6), CF(tx, 7.4, tz), RGB(60 + k * 10, 145, 70), MAT.Grass)
				crown.Shape = Enum.PartType.Ball
			end
			part(parent, V3(4, 0.4, 1.4), CF(cx + qx * 6, 1.2, cz + qz * 3), RGB(140, 100, 60), MAT.WoodPlanks)
		end
	end
end
end
