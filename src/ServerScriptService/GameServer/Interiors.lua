-- INTERIORS: every business and every home has an inside you can walk into and decorate.
-- Rooms are built away from the city (high above the far edge of the map) only while someone is inside, and
-- removed shortly after they're empty. Each business type has its own functional areas (counter, kitchen,
-- ovens, arcade machines...); homes have a living room, kitchen, bedroom, bathroom and (bigger homes) a garage.
-- Decorating: numbered spots for furniture and decorations, plus wall, floor and lighting styles. Everything
-- is validated here on the server, paid for in cash, and saved in d.interiors. Decor raises an interior score
-- that makes customers a little happier (capped, reviews/reputation only) and shows on house signs:
-- it never adds income, so it can't be farmed.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local F, data, plots = C.F, C.data, C.plots
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local MAT = Enum.Material
local SOLID = {CanCollide = true}
local fmt, notify = C.fmt, C.notify
local P = C.P
local BIZ = C.BIZ

local FOLDER = Instance.new("Folder")
FOLDER.Name = "Interiors"
FOLDER.Parent = Workspace

-- ===== styles =====
C.WALLS = {
	{key = "white", name = "Clean White", icon = "⬜", cost = 0, score = 0, color = RGB(236, 234, 228), mat = "SmoothPlastic"},
	{key = "cream", name = "Warm Cream", icon = "🟨", cost = 400, score = 2, color = RGB(242, 226, 190), mat = "SmoothPlastic"},
	{key = "mint", name = "Mint Paint", icon = "🟩", cost = 600, score = 3, color = RGB(170, 220, 190), mat = "SmoothPlastic"},
	{key = "navy", name = "Navy Accent", icon = "🟦", cost = 900, score = 4, color = RGB(40, 60, 110), mat = "SmoothPlastic"},
	{key = "brick", name = "Exposed Brick", icon = "🧱", cost = 2500, score = 6, color = RGB(160, 85, 65), mat = "Brick"},
	{key = "wood", name = "Wood Paneling", icon = "🪵", cost = 4000, score = 7, color = RGB(150, 105, 70), mat = "WoodPlanks"},
	{key = "marble", name = "Marble Walls", icon = "🏛️", cost = 60000, score = 12, color = RGB(235, 235, 240), mat = "Marble"},
}
C.FLOORS = {
	{key = "concrete", name = "Bare Concrete", icon = "⬛", cost = 0, score = 0, color = RGB(150, 150, 152), mat = "Concrete"},
	{key = "tile", name = "Tile", icon = "🔲", cost = 500, score = 2, color = RGB(220, 220, 225), mat = "Slate"},
	{key = "wood", name = "Wood Floor", icon = "🪵", cost = 1500, score = 4, color = RGB(160, 115, 75), mat = "WoodPlanks"},
	{key = "carpet", name = "Soft Carpet", icon = "🟥", cost = 1200, score = 3, color = RGB(150, 60, 70), mat = "Fabric"},
	{key = "marble", name = "Marble Floor", icon = "🤍", cost = 50000, score = 10, color = RGB(240, 240, 245), mat = "Marble"},
	{key = "gold", name = "Gold-Vein Premium", icon = "✨", cost = 900000, score = 16, color = RGB(235, 205, 120), mat = "Marble"},
}
C.LIGHTS = {
	{key = "basic", name = "Basic Bulbs", icon = "💡", cost = 0, score = 0, color = RGB(255, 244, 220), brightness = 1.4},
	{key = "warm", name = "Warm Ceiling Lights", icon = "🕯️", cost = 800, score = 3, color = RGB(255, 210, 160), brightness = 1.8},
	{key = "cool", name = "Cool Daylight", icon = "🌤️", cost = 800, score = 3, color = RGB(210, 230, 255), brightness = 2},
	{key = "neon", name = "Neon Glow", icon = "🌈", cost = 6000, score = 7, color = RGB(255, 80, 220), brightness = 2.4, neon = true},
	{key = "luxury", name = "Crystal Chandeliers", icon = "💎", cost = 120000, score = 12, color = RGB(255, 236, 200), brightness = 2.6, chandelier = true},
}
-- ===== furniture + decorations (place = floor / wall; for = home, biz, or a business key) =====
-- unlock = business level needed (business-only items)
C.DECOR = {
	-- furniture
	{key = "chair", name = "Chair", icon = "🪑", cat = "Furniture", place = "floor", cost = 150, score = 1, for_ = "any"},
	{key = "table", name = "Table", icon = "🟫", cat = "Furniture", place = "floor", cost = 300, score = 2, for_ = "any"},
	{key = "couch", name = "Couch", icon = "🛋️", cat = "Furniture", place = "floor", cost = 900, score = 4, for_ = "any"},
	{key = "bed", name = "Bed", icon = "🛏️", cat = "Furniture", place = "floor", cost = 1200, score = 4, for_ = "home"},
	{key = "desk", name = "Desk", icon = "🖥️", cat = "Furniture", place = "floor", cost = 700, score = 3, for_ = "any"},
	{key = "shelf", name = "Shelves", icon = "📚", cat = "Furniture", place = "floor", cost = 500, score = 2, for_ = "any"},
	{key = "booth", name = "Diner Booth", icon = "🍽️", cat = "Furniture", place = "floor", cost = 3000, score = 6, for_ = "biz"},
	-- decorations
	{key = "plant", name = "Potted Plant", icon = "🪴", cat = "Decorations", place = "floor", cost = 120, score = 1, for_ = "any"},
	{key = "lamp", name = "Floor Lamp", icon = "🛋️", cat = "Decorations", place = "floor", cost = 400, score = 2, for_ = "any", light = true},
	{key = "rug", name = "Rug", icon = "🟪", cat = "Decorations", place = "floor", cost = 350, score = 2, for_ = "any"},
	{key = "tv", name = "Big TV", icon = "📺", cat = "Decorations", place = "wall", cost = 2500, score = 5, for_ = "any"},
	{key = "poster", name = "Poster", icon = "🖼️", cat = "Decorations", place = "wall", cost = 200, score = 1, for_ = "any"},
	{key = "art", name = "Fancy Artwork", icon = "🎨", cat = "Decorations", place = "wall", cost = 25000, score = 9, for_ = "any"},
	{key = "neonsign", name = "Neon Sign", icon = "✨", cat = "Decorations", place = "wall", cost = 5000, score = 6, for_ = "any"},
	{key = "statue", name = "Golden Statue", icon = "🗿", cat = "Decorations", place = "floor", cost = 400000, score = 14, for_ = "any"},
	-- business-specific (unlock with the business's level)
	{key = "brickoven", name = "Brick Oven", icon = "🔥", cat = "Special", place = "floor", cost = 40000, score = 8, for_ = "pizza", unlock = 3},
	{key = "pizzasign", name = "Pizza Sign", icon = "🍕", cat = "Special", place = "wall", cost = 15000, score = 5, for_ = "pizza", unlock = 2},
	{key = "wallmenu", name = "Wall Menu", icon = "📋", cat = "Special", place = "wall", cost = 2500, score = 3, for_ = "biz", unlock = 2},
	{key = "espresso", name = "Espresso Machine", icon = "☕", cat = "Special", place = "floor", cost = 12000, score = 6, for_ = "coffee", unlock = 2},
	{key = "cabinet", name = "Arcade Cabinet", icon = "🕹️", cat = "Special", place = "floor", cost = 150000, score = 8, for_ = "arcade", unlock = 2},
	{key = "claw", name = "Claw Machine", icon = "🧸", cat = "Special", place = "floor", cost = 400000, score = 9, for_ = "arcade", unlock = 5},
	{key = "display", name = "Product Display", icon = "📱", cat = "Special", place = "floor", cost = 900000, score = 8, for_ = "tech", unlock = 2},
	{key = "freezer", name = "Gelato Freezer", icon = "🍨", cat = "Special", place = "floor", cost = 3000, score = 5, for_ = "icecream", unlock = 3},
	{key = "juicer", name = "Juice Press", icon = "🍋", cat = "Special", place = "floor", cost = 600, score = 4, for_ = "lemonade", unlock = 3},
	{key = "showcase", name = "Pastry Showcase", icon = "🥐", cat = "Special", place = "floor", cost = 20000, score = 6, for_ = "bakery", unlock = 3},
	{key = "robotarm", name = "Robot Arm", icon = "🦾", cat = "Special", place = "floor", cost = 9000000, score = 10, for_ = "factory", unlock = 2},
	{key = "kitchen", name = "Premium Kitchen", icon = "👨‍🍳", cat = "Special", place = "floor", cost = 50000, score = 8, for_ = "home", unlock = 0},
}
C.DECOR_BY = {}
for _, it in ipairs(C.DECOR) do C.DECOR_BY[it.key] = it end
local STYLE = {wall = C.WALLS, floor = C.FLOORS, light = C.LIGHTS}
local function styleOf(kind, key)
	for _, s in ipairs(STYLE[kind]) do if s.key == key then return s end end
	return STYLE[kind][1]
end

-- ===== room layouts: size, functional fixtures, decor spots =====
-- spots: {x, z, place, yaw} in room space (origin = room center on the floor, door on the +Z wall)
local function grid(xs, zs, place)
	local out = {}
	for _, z in ipairs(zs) do for _, x in ipairs(xs) do table.insert(out, {x, z, place}) end end
	return out
end
local function walls(w, d)
	return {{-w / 2 + 6, -d / 2 + 0.6, "wall", 0}, {0, -d / 2 + 0.6, "wall", 0}, {w / 2 - 6, -d / 2 + 0.6, "wall", 0}}
end
local LAYOUTS = {
	-- small stands get a cozy back room
	lemonade = {w = 30, d = 22, fixtures = {"counter", "storage"}, spots = grid({-8, 0, 8}, {0, 5}, "floor")},
	icecream = {w = 32, d = 22, fixtures = {"counter", "freezers", "seating"}, spots = grid({-9, 0, 9}, {2, 6}, "floor")},
	bakery = {w = 38, d = 26, fixtures = {"counter", "kitchen", "seating", "storage"}, spots = grid({-12, -4, 4, 12}, {2, 7}, "floor")},
	coffee = {w = 40, d = 28, fixtures = {"counter", "kitchen", "seating", "storage"}, spots = grid({-12, -4, 4, 12}, {2, 8}, "floor")},
	pizza = {w = 44, d = 30, fixtures = {"counter", "ovens", "kitchen", "seating", "delivery"}, spots = grid({-14, -5, 5, 14}, {3, 9}, "floor")},
	arcade = {w = 48, d = 32, fixtures = {"machines", "prizes", "seating"}, spots = grid({-16, -6, 6, 16}, {2, 9}, "floor")},
	tech = {w = 48, d = 32, fixtures = {"displays", "computers", "checkout", "storage"}, spots = grid({-16, -6, 6, 16}, {3, 9}, "floor")},
	factory = {w = 56, d = 36, fixtures = {"conveyor", "storage", "checkout"}, spots = grid({-20, -8, 8, 20}, {4, 11}, "floor")},
	home = {w = 60, d = 44, fixtures = {"homeRooms"}, spots = grid({-22, -12, 10, 22}, {-4, 6, 14}, "floor")},
}
for _, L in pairs(LAYOUTS) do
	for _, s in ipairs(walls(L.w, L.d)) do table.insert(L.spots, s) end
end
C.INTERIOR_LAYOUTS = LAYOUTS

-- ===== saved data =====
local function roomData(d, key)
	d.interiors = type(d.interiors) == "table" and d.interiors or {}
	local r = d.interiors[key]
	if type(r) ~= "table" then
		r = {wall = "white", floor = key == "home" and "wood" or "tile", light = "basic", spots = {}}
		d.interiors[key] = r
	end
	r.spots = type(r.spots) == "table" and r.spots or {}
	return r
end
function F.interiorScore(d, key)
	local r = d.interiors and d.interiors[key]
	if type(r) ~= "table" then return 0 end
	local score = styleOf("wall", r.wall).score + styleOf("floor", r.floor).score + styleOf("light", r.light).score
	for _, item in pairs(type(r.spots) == "table" and r.spots or {}) do
		local it = C.DECOR_BY[item]
		if it then score += it.score end
	end
	return score
end
function F.interiorStars(d, key) return math.clamp(F.interiorScore(d, key) / 16, 0, 5) end
-- decorated businesses make customers a bit happier: up to +10 satisfaction (reviews and reputation, never income)
function F.interiorSatisfaction(d, key) return math.min(10, math.floor(F.interiorScore(d, key) / 8)) end

-- ===== building a room =====
local rooms = {}   -- [roomId] = {model, owner, key, origin, occupants = {}, empty = t}
local MATERIALS = {SmoothPlastic = MAT.SmoothPlastic, Brick = MAT.Brick, WoodPlanks = MAT.WoodPlanks, Marble = MAT.Marble, Slate = MAT.Slate,
	Fabric = MAT.Fabric, Concrete = MAT.Concrete}
local function mat(name) return MATERIALS[name] or MAT.SmoothPlastic end
local function box(m, size, cf, color, material, props)
	local p = P(m, size, cf, color, material or MAT.SmoothPlastic, props)
	return p
end
local function addLight(part, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range or 22
	l.Parent = part
end
local function buildItem(m, it, cf, accent)
	local k = it.key
	if it.place == "wall" then
		local colors = {tv = RGB(20, 20, 24), poster = accent, art = RGB(200, 160, 60), neonsign = RGB(255, 80, 200), pizzasign = RGB(230, 80, 40), wallmenu = RGB(30, 40, 30)}
		local p = box(m, V3(k == "tv" and 7 or 4, k == "tv" and 4 or 3, 0.3), cf * CF(0, 6, 0), colors[k] or accent, k == "neonsign" and MAT.Neon or MAT.SmoothPlastic)
		if k == "art" then box(m, V3(3.2, 2.2, 0.35), cf * CF(0, 6, 0.05), RGB(80, 130, 200)) end
		if k == "neonsign" then addLight(p, RGB(255, 80, 200), 1.5, 12) end
		return
	end
	if k == "chair" then
		box(m, V3(2, 0.4, 2), cf * CF(0, 1.6, 0), RGB(150, 100, 60), MAT.Wood)
		box(m, V3(2, 2, 0.3), cf * CF(0, 2.8, 0.9), RGB(150, 100, 60), MAT.Wood)
	elseif k == "table" then
		box(m, V3(4, 0.3, 4), cf * CF(0, 2.6, 0), RGB(170, 120, 75), MAT.Wood)
		box(m, V3(0.5, 2.5, 0.5), cf * CF(0, 1.3, 0), RGB(90, 70, 50), MAT.Wood)
	elseif k == "couch" or k == "booth" then
		local col = k == "booth" and RGB(200, 40, 50) or accent
		box(m, V3(6, 1.2, 2.6), cf * CF(0, 1.2, 0), col, MAT.Fabric)
		box(m, V3(6, 2, 0.8), cf * CF(0, 2.4, 1), col, MAT.Fabric)
	elseif k == "bed" then
		box(m, V3(5, 1.2, 7), cf * CF(0, 1, 0), RGB(240, 240, 245), MAT.Fabric)
		box(m, V3(5, 2.4, 0.5), cf * CF(0, 1.8, 3.4), RGB(110, 80, 60), MAT.Wood)
		box(m, V3(4.6, 0.3, 4), cf * CF(0, 1.7, -1.2), accent, MAT.Fabric)
	elseif k == "desk" then
		box(m, V3(5, 0.3, 2.5), cf * CF(0, 2.6, 0), RGB(80, 80, 90))
		box(m, V3(2, 1.4, 0.2), cf * CF(0, 3.5, 0.6), RGB(20, 20, 26), MAT.Glass)
	elseif k == "shelf" then
		for y = 1, 3 do box(m, V3(5, 0.25, 1.4), cf * CF(0, y * 1.4, 0), RGB(140, 100, 70), MAT.Wood) end
		box(m, V3(0.3, 4.4, 1.4), cf * CF(-2.4, 2.2, 0), RGB(140, 100, 70), MAT.Wood)
	elseif k == "plant" then
		box(m, V3(1.4, 1.4, 1.4), cf * CF(0, 0.9, 0), RGB(170, 90, 60), MAT.Slate)
		local leaf = box(m, V3(2.4, 2.4, 2.4), cf * CF(0, 2.6, 0), RGB(70, 160, 80), MAT.Grass)
		leaf.Shape = Enum.PartType.Ball
	elseif k == "lamp" then
		box(m, V3(0.3, 4, 0.3), cf * CF(0, 2.2, 0), RGB(40, 40, 40), MAT.Metal)
		local shade = box(m, V3(1.6, 1, 1.6), cf * CF(0, 4.4, 0), RGB(255, 240, 200), MAT.Neon)
		addLight(shade, RGB(255, 220, 170), 1.2, 14)
	elseif k == "rug" then
		box(m, V3(7, 0.1, 5), cf * CF(0, 0.65, 0), accent, MAT.Fabric)
	elseif k == "statue" then
		box(m, V3(2.5, 1, 2.5), cf * CF(0, 1, 0), RGB(60, 60, 64), MAT.Marble)
		local s = box(m, V3(1.6, 4, 1.6), cf * CF(0, 3.5, 0), RGB(255, 205, 60), MAT.Metal)
		s.Reflectance = 0.3
	elseif k == "brickoven" then
		box(m, V3(5, 4, 4), cf * CF(0, 2.6, 0), RGB(160, 80, 60), MAT.Brick)
		local fire = box(m, V3(2, 1.2, 0.2), cf * CF(0, 2.2, -2.05), RGB(255, 120, 30), MAT.Neon)
		addLight(fire, RGB(255, 140, 60), 2, 12)
	elseif k == "espresso" or k == "juicer" or k == "freezer" or k == "showcase" then
		box(m, V3(3, 3, 2), cf * CF(0, 2, 0), k == "freezer" and RGB(220, 240, 255) or RGB(190, 190, 200), MAT.Metal)
		box(m, V3(2.6, 1, 0.2), cf * CF(0, 2.6, -1.05), BIZ[it.for_] and BIZ[it.for_].color or accent, MAT.Neon)
	elseif k == "cabinet" or k == "claw" then
		box(m, V3(3, 6, 3), cf * CF(0, 3.6, 0), k == "claw" and RGB(255, 120, 200) or RGB(60, 40, 140))
		local scr = box(m, V3(2.4, 2, 0.2), cf * CF(0, 4.5, -1.55), RGB(80, 220, 255), MAT.Neon)
		addLight(scr, RGB(80, 220, 255), 1, 8)
	elseif k == "display" then
		box(m, V3(4, 3, 2), cf * CF(0, 2, 0), RGB(240, 240, 245))
		box(m, V3(0.8, 1.4, 0.1), cf * CF(0, 4.2, 0), RGB(20, 20, 26), MAT.Glass)
	elseif k == "robotarm" then
		box(m, V3(2, 1, 2), cf * CF(0, 1, 0), RGB(255, 170, 30), MAT.Metal)
		box(m, V3(0.8, 5, 0.8), cf * CF(0, 3.8, 0) * CFrame.Angles(0, 0, 0.4), RGB(255, 170, 30), MAT.Metal)
	elseif k == "kitchen" then
		box(m, V3(8, 3, 2.5), cf * CF(0, 2, 0), RGB(250, 250, 252), MAT.Marble)
		box(m, V3(8, 0.3, 2.7), cf * CF(0, 3.6, 0), RGB(40, 40, 46), MAT.Granite)
	else
		box(m, V3(2, 2, 2), cf * CF(0, 1.6, 0), accent)
	end
end
-- the functional areas each business type always has
local function buildFixtures(m, o, L, key, accent)
	local hw, hd = L.w / 2, L.d / 2
	local function counter(x, z, w)
		box(m, V3(w, 3.4, 2.4), o * CF(x, 2.2, z), RGB(230, 225, 215), MAT.SmoothPlastic)
		box(m, V3(w + 0.2, 0.3, 2.6), o * CF(x, 4, z), accent)
	end
	for _, f in ipairs(L.fixtures) do
		if f == "counter" or f == "checkout" then
			counter(0, -hd + 7, L.w * 0.45)
			box(m, V3(1.2, 1, 1), o * CF(L.w * 0.15, 4.7, -hd + 7), RGB(30, 30, 34))   -- register
		elseif f == "kitchen" then
			box(m, V3(L.w * 0.35, 3.4, 2.4), o * CF(-hw + L.w * 0.2, 2.2, -hd + 2), RGB(200, 200, 205), MAT.Metal)
			box(m, V3(3, 0.4, 2), o * CF(-hw + L.w * 0.12, 4.1, -hd + 2), RGB(30, 30, 30), MAT.Metal)
		elseif f == "ovens" then
			for i = 0, 1 do
				box(m, V3(4, 4, 3), o * CF(hw - 4 - i * 5, 2.5, -hd + 2.2), RGB(170, 90, 60), MAT.Brick)
				local glow = box(m, V3(2, 1, 0.2), o * CF(hw - 4 - i * 5, 2.2, -hd + 3.75), RGB(255, 130, 40), MAT.Neon)
				addLight(glow, RGB(255, 140, 60), 1.5, 10)
			end
		elseif f == "seating" then
			for _, x in ipairs({-hw + 5, hw - 5}) do
				box(m, V3(4, 0.3, 4), o * CF(x, 2.6, hd - 7), RGB(170, 120, 75), MAT.Wood)
				box(m, V3(0.5, 2.5, 0.5), o * CF(x, 1.3, hd - 7), RGB(90, 70, 50), MAT.Wood)
			end
		elseif f == "storage" then
			for i = 0, 2 do box(m, V3(3, 3, 3), o * CF(hw - 3, 2, -hd + 9 + i * 3.2), RGB(170, 130, 80), MAT.WoodPlanks) end
		elseif f == "freezers" then
			for i = 0, 1 do box(m, V3(5, 3, 2.4), o * CF(-hw + 4, 2, -hd + 6 + i * 4), RGB(220, 240, 255), MAT.Glass) end
		elseif f == "delivery" then
			box(m, V3(6, 0.2, 6), o * CF(hw - 5, 0.6, hd - 5), RGB(255, 210, 60), MAT.SmoothPlastic)
			for i = 0, 3 do box(m, V3(2, 0.4, 2), o * CF(hw - 5, 1 + i * 0.45, hd - 5), RGB(220, 200, 160), MAT.SmoothPlastic) end
		elseif f == "machines" then
			for i = 0, 4 do
				box(m, V3(3, 6, 3), o * CF(-hw + 4 + i * 4, 3.6, -hd + 2.5), Color3.fromHSV(i / 5, 0.6, 0.8))
				box(m, V3(2.4, 2, 0.2), o * CF(-hw + 4 + i * 4, 4.5, -hd + 4.05), RGB(80, 220, 255), MAT.Neon)
			end
		elseif f == "prizes" then
			box(m, V3(8, 5, 1.5), o * CF(hw - 6, 3, -hd + 1.5), RGB(255, 200, 230))
			for i = 0, 5 do box(m, V3(1, 1, 1), o * CF(hw - 9 + i * 1.2, 4.6, -hd + 1.2), Color3.fromHSV(i / 6, 0.7, 1)) end
		elseif f == "displays" then
			for i = 0, 3 do box(m, V3(4, 3, 2), o * CF(-hw + 6 + i * 6, 2, -2), RGB(240, 240, 245)) end
		elseif f == "computers" then
			for i = 0, 2 do
				box(m, V3(4, 0.3, 2.5), o * CF(hw - 5, 2.6, -hd + 8 + i * 4), RGB(80, 80, 90))
				box(m, V3(2, 1.4, 0.2), o * CF(hw - 5, 3.5, -hd + 7.2 + i * 4), RGB(20, 30, 50), MAT.Neon)
			end
		elseif f == "conveyor" then
			box(m, V3(L.w * 0.7, 2, 3), o * CF(0, 1.6, -hd + 5), RGB(60, 60, 66), MAT.Metal)
			for i = 0, 6 do box(m, V3(1.6, 1.6, 1.6), o * CF(-L.w * 0.3 + i * L.w * 0.1, 3.4, -hd + 5), RGB(200, 160, 100), MAT.SmoothPlastic) end
		elseif f == "homeRooms" then
			-- partitions: living room (front), kitchen (back left), bedroom (back middle), bathroom (back right), garage (left)
			box(m, V3(L.w, 12, 0.6), o * CF(0, 6.6, -4), RGB(220, 215, 205))
			for _, x in ipairs({-8, 8}) do box(m, V3(0.6, 12, hd - 4), o * CF(x, 6.6, -hd / 2 - 2), RGB(220, 215, 205)) end
			-- doorways (gaps are left by building the walls in pieces would be nicer; a coloured frame marks each room)
			box(m, V3(6, 0.2, 0.7), o * CF(-16, 9.5, -4), accent)
			box(m, V3(6, 0.2, 0.7), o * CF(0, 9.5, -4), accent)
			box(m, V3(6, 0.2, 0.7), o * CF(16, 9.5, -4), accent)
			-- kitchen counter, bed area rug, bathtub
			box(m, V3(12, 3, 2.4), o * CF(-hw + 9, 2, -hd + 2), RGB(240, 240, 240), MAT.Marble)
			box(m, V3(6, 2, 3), o * CF(hw - 6, 1.6, -hd + 3), RGB(250, 250, 255), MAT.Marble)
			for _, lbl in ipairs({{"🍳 KITCHEN", -18}, {"🛏️ BEDROOM", 0}, {"🛁 BATHROOM", 18}}) do
				local sign = box(m, V3(6, 1.2, 0.2), o * CF(lbl[2], 10.6, -4.4), RGB(30, 30, 34))
				C.surfaceText(sign, Enum.NormalId.Front, lbl[1], Color3.new(1, 1, 1))
			end
		end
	end
end
local function buildRoom(room)
	local owner, key = room.owner, room.key
	local d = data[owner]
	if not d then return end
	if room.model then room.model:Destroy() end
	local m = Instance.new("Model")
	m.Name = "Interior_" .. owner.Name .. "_" .. key
	m.Parent = FOLDER
	room.model = m
	local L = LAYOUTS[BIZ[key] and key or "home"]
	local r = roomData(d, key)
	local wall, floor, light = styleOf("wall", r.wall), styleOf("floor", r.floor), styleOf("light", r.light)
	local o = room.origin
	local accent = BIZ[key] and BIZ[key].color or d.plot.color
	local H = 14
	box(m, V3(L.w, 1, L.d), o * CF(0, 0, 0), floor.color, mat(floor.mat), SOLID)
	box(m, V3(L.w, 1, L.d), o * CF(0, H, 0), RGB(245, 245, 245), nil, SOLID)
	box(m, V3(L.w, H, 1), o * CF(0, H / 2, -L.d / 2), wall.color, mat(wall.mat), SOLID)
	box(m, V3(1, H, L.d), o * CF(-L.w / 2, H / 2, 0), wall.color, mat(wall.mat), SOLID)
	box(m, V3(1, H, L.d), o * CF(L.w / 2, H / 2, 0), wall.color, mat(wall.mat), SOLID)
	-- front wall with the exit door
	box(m, V3(L.w / 2 - 3, H, 1), o * CF(-L.w / 4 - 1.5, H / 2, L.d / 2), wall.color, mat(wall.mat), SOLID)
	box(m, V3(L.w / 2 - 3, H, 1), o * CF(L.w / 4 + 1.5, H / 2, L.d / 2), wall.color, mat(wall.mat), SOLID)
	box(m, V3(6, H - 9, 1), o * CF(0, H - (H - 9) / 2, L.d / 2), wall.color, mat(wall.mat), SOLID)
	local door = box(m, V3(6, 9, 0.6), o * CF(0, 4.5, L.d / 2), RGB(90, 60, 40), MAT.Wood, SOLID)
	C.prompt(door, "Leave", (BIZ[key] and BIZ[key].name or "Home"), 10, 0, function(plr) F.leaveInterior(plr) end)
	-- name over the door, inside
	local sign = box(m, V3(14, 2, 0.3), o * CF(0, 11.5, L.d / 2 - 0.7), RGB(30, 30, 34))
	C.surfaceText(sign, Enum.NormalId.Back, (BIZ[key] and (BIZ[key].icon .. " " .. owner.Name .. "'s " .. BIZ[key].name) or ("🏠 " .. owner.Name .. "'s Home")), Color3.new(1, 1, 1))
	-- lights
	local nx = math.max(2, math.floor(L.w / 16))
	for i = 1, nx do
		local x = -L.w / 2 + i * L.w / (nx + 1)
		local fixture = box(m, light.chandelier and V3(3, 1.5, 3) or V3(3, 0.3, 3), o * CF(x, H - (light.chandelier and 1.4 or 0.4), 0),
			light.chandelier and RGB(255, 215, 120) or light.color, MAT.Neon)
		addLight(fixture, light.color, light.brightness, 26)
	end
	if light.neon then
		box(m, V3(L.w - 2, 0.3, 0.3), o * CF(0, H - 1.5, -L.d / 2 + 0.7), light.color, MAT.Neon)
	end
	buildFixtures(m, o, L, BIZ[key] and key or "home", accent)
	-- decorations in their spots
	for i, sp in ipairs(L.spots) do
		local item = r.spots[tostring(i)]
		local it = item and C.DECOR_BY[item]
		if it then
			local yaw = sp[3] == "wall" and 0 or math.pi
			buildItem(m, it, o * CF(sp[1], 0.5, sp[2]) * CFrame.Angles(0, yaw, 0), accent)
		end
	end
	room.spawn = o * CF(0, 3, L.d / 2 - 4)
end

-- ===== entering / leaving =====
local nextSlot = 0
local function roomId(owner, key) return owner.UserId .. ":" .. key end
local function roomFor(owner, key)
	local id = roomId(owner, key)
	local room = rooms[id]
	if not room then
		nextSlot += 1
		local d = data[owner]
		local px = d and d.plot.index or 1
		local idx = BIZ[key] and BIZ[key].index or 9
		-- far above the eastern edge of the map, each owner in their own column, each room in its own row
		room = {owner = owner, key = key, occupants = {}, origin = CF(1800 + px * 160, 400, -600 + idx * 70)}
		rooms[id] = room
	end
	return room
end
local where = {}   -- player -> {room, back = CFrame}
-- respawning (or leaving the game) while inside: forget the room without teleporting
local function forget(plr)
	local w = where[plr]
	if not w then return end
	where[plr] = nil
	w.room.occupants[plr] = nil
	if next(w.room.occupants) == nil then w.room.empty = os.clock() end
	pcall(function()
		plr:SetAttribute("Interior", nil)
		plr:SetAttribute("InteriorOwner", nil)
	end)
end
Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function() forget(plr) end) end)
for _, plr in ipairs(Players:GetPlayers()) do plr.CharacterAdded:Connect(function() forget(plr) end) end
Players.PlayerRemoving:Connect(forget)
function F.enterInterior(plr, owner, key)
	local d, od = data[plr], data[owner]
	if not (d and od) then return end
	if BIZ[key] then
		if (od.levels[key] or 0) <= 0 then return end
	elseif key ~= "home" or not (od.home and od.home.level and od.home.level > 0) then
		return
	end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local room = roomFor(owner, key)
	if not room.model or not room.model.Parent then buildRoom(room) end
	where[plr] = {room = room, back = root.CFrame}
	room.occupants[plr] = true
	room.empty = nil
	F.despawnCar(plr)
	char:PivotTo(room.spawn)
	plr:SetAttribute("Interior", key)
	plr:SetAttribute("InteriorOwner", owner.UserId)
	-- walking into someone's home counts as a visit (the same once-a-day rule as house tours)
	if owner ~= plr and key == "home" and F.countHomeVisit then F.countHomeVisit(plr, owner) end
end
function F.leaveInterior(plr)
	local w = where[plr]
	if not w then return end
	where[plr] = nil
	w.room.occupants[plr] = nil
	if next(w.room.occupants) == nil then w.room.empty = os.clock() end
	plr:SetAttribute("Interior", nil)
	plr:SetAttribute("InteriorOwner", nil)
	local char = plr.Character
	if char then char:PivotTo(w.back + Vector3.new(0, 2, 0)) end
end
function F.interiorOf(plr) return where[plr] and where[plr].room end

-- doors: an "Enter" prompt at every open business and every built home
local doors = {}
local function door(id, cf, label, objectText, onEnter)
	if doors[id] and doors[id].Parent then return end
	local p = Instance.new("Part")
	p.Name = "Door_" .. id
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, true, false, 1
	p.Size = V3(4, 6, 1)
	p.CFrame = cf
	p.Parent = FOLDER
	doors[id] = p
	C.prompt(p, label, objectText, 10, 0.3, onEnter)
end
function F.refreshDoors(plr)
	local d = data[plr]
	if not d then return end
	for _, b in ipairs(C.BUSINESSES) do
		local id = plr.UserId .. ":" .. b.key
		if (d.levels[b.key] or 0) > 0 then
			local cf = F.slotCF(d.plot, b.key) * CF(0, 3, 7)
			door(id, cf, "Enter", b.name, function(who) F.enterInterior(who, plr, b.key) end)
		elseif doors[id] then
			doors[id]:Destroy()
			doors[id] = nil
		end
	end
	local lot = F.homeLot(d)
	local hid = plr.UserId .. ":home"
	if lot and d.home.level > 0 then
		if doors[hid] and doors[hid]:GetAttribute("Lot") ~= lot.id then doors[hid]:Destroy() doors[hid] = nil end
		door(hid, CF(lot.pos) * CFrame.Angles(0, lot.yaw, 0) * CF(0, 3, lot.size / 2 - 9), "Enter", plr.Name .. "'s Home", function(who) F.enterInterior(who, plr, "home") end)
		doors[hid]:SetAttribute("Lot", lot.id)
	elseif doors[hid] then
		doors[hid]:Destroy()
		doors[hid] = nil
	end
end
function F.clearInteriors(plr)
	for id, p in pairs(doors) do
		if string.sub(id, 1, #tostring(plr.UserId) + 1) == plr.UserId .. ":" then p:Destroy() doors[id] = nil end
	end
	for id, room in pairs(rooms) do
		if room.owner == plr then
			for who in pairs(room.occupants) do F.leaveInterior(who) end
			if room.model then room.model:Destroy() end
			rooms[id] = nil
		end
	end
	if where[plr] then F.leaveInterior(plr) end
end

-- ===== customizing (owner only, while inside that room) =====
local function allowedFor(it, key)
	if it.for_ == "any" then return true end
	if it.for_ == "home" then return key == "home" end
	if it.for_ == "biz" then return BIZ[key] ~= nil end
	return it.for_ == key
end
function F.decorate(plr, what, slot, itemKey)
	local d = data[plr]
	local w = where[plr]
	if not (d and w) or w.room.owner ~= plr then
		notify(plr, "🛋️ Go inside your business or home to decorate it.")
		return
	end
	local key = w.room.key
	local r = roomData(d, key)
	local L = LAYOUTS[BIZ[key] and key or "home"]
	local cost, label
	if what == "wall" or what == "floor" or what == "light" then
		local st
		for _, s in ipairs(STYLE[what]) do if s.key == itemKey then st = s end end
		if not st or r[what] == st.key then return end
		cost, label = st.cost, st.name
		if d.cash < cost then notify(plr, "You need $" .. fmt(cost) .. " for " .. label .. ".") return end
		d.cash -= cost
		r[what] = st.key
	elseif what == "spot" then
		local i = C.int(slot, 1, #L.spots)
		if not i then return end
		local sp = L.spots[i]
		if itemKey == "none" then
			r.spots[tostring(i)] = nil   -- removing is free (and refunds nothing, so buy/remove can't make money)
			label = "Removed"
			cost = 0
		else
			local it = C.DECOR_BY[itemKey]
			if not it or it.place ~= sp[3] or not allowedFor(it, key) then return end
			if it.unlock and BIZ[key] and (d.levels[key] or 0) < it.unlock then
				notify(plr, "🔒 " .. it.name .. " unlocks at " .. BIZ[key].name .. " level " .. it.unlock .. ".")
				return
			end
			if r.spots[tostring(i)] == it.key then return end
			cost, label = it.cost, it.name
			if d.cash < cost then notify(plr, "You need $" .. fmt(cost) .. " for " .. label .. ".") return end
			d.cash -= cost
			r.spots[tostring(i)] = it.key
		end
	else
		return
	end
	buildRoom(w.room)
	-- everyone inside stays inside (the room was rebuilt in the same place)
	notify(plr, "🛋️ " .. label .. (cost > 0 and (" (-$" .. fmt(cost) .. ")") or "") .. " • Interior score " .. F.interiorScore(d, key))
	if key == "home" then
		local lot = F.homeLot(d)
		if lot then F.refreshHomeSign(lot) end
	end
end
-- what the decorate panel needs (only while you're inside your own room)
function F.interiorState(plr, d)
	local w = where[plr]
	if not w then return nil end
	local key = w.room.key
	local mine = w.room.owner == plr
	local od = data[w.room.owner]
	if not od then return nil end
	local out = {key = key, owner = w.room.owner.Name, mine = mine, score = F.interiorScore(od, key), stars = F.interiorStars(od, key),
		name = BIZ[key] and BIZ[key].name or "Home"}
	if mine then
		local r = roomData(d, key)
		local L = LAYOUTS[BIZ[key] and key or "home"]
		out.wall, out.floor, out.light = r.wall, r.floor, r.light
		out.spots = {}
		for i, sp in ipairs(L.spots) do out.spots[i] = {place = sp[3], item = r.spots[tostring(i)] or "", at = w.room.origin * CF(sp[1], 1, sp[2])} end
		out.level = BIZ[key] and (d.levels[key] or 0) or nil
	end
	return out
end
function C.interiorCatalog()
	local items = {}
	for _, it in ipairs(C.DECOR) do
		table.insert(items, {key = it.key, name = it.name, icon = it.icon, cat = it.cat, place = it.place, cost = it.cost, score = it.score, for_ = it.for_, unlock = it.unlock})
	end
	local function styles(list)
		local out = {}
		for _, s in ipairs(list) do table.insert(out, {key = s.key, name = s.name, icon = s.icon, cost = s.cost, score = s.score}) end
		return out
	end
	return {items = items, walls = styles(C.WALLS), floors = styles(C.FLOORS), lights = styles(C.LIGHTS)}
end

-- rooms nobody is in are removed after a minute (they're rebuilt the next time someone enters)
task.spawn(function()
	while true do
		task.wait(15)
		local now = os.clock()
		for id, room in pairs(rooms) do
			for who in pairs(room.occupants) do
				if not who.Parent or not data[who] then room.occupants[who] = nil where[who] = nil end
			end
			if next(room.occupants) == nil then
				room.empty = room.empty or now
				if now - room.empty > 60 and room.model then
					room.model:Destroy()
					room.model = nil
				end
			end
			if not room.owner.Parent then rooms[id] = nil end
		end
		for plr in pairs(data) do pcall(F.refreshDoors, plr) end
	end
end)

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.decor = function(plr, d, a, b, c)
	if (a == "wall" or a == "floor" or a == "light") and C.str(c, 20) then F.decorate(plr, a, nil, c)
	elseif a == "spot" and C.str(c, 20) then F.decorate(plr, "spot", b, c) end
end
C.ACTIONS.leaveInterior = function(plr) F.leaveInterior(plr) end
-- from the Home app: step inside your own home (must be built)
C.ACTIONS.enterHome = function(plr, d)
	if d.home and d.home.level and d.home.level > 0 then F.enterInterior(plr, plr, "home")
	else notify(plr, "🏠 Build your house first (Home app → Build).") end
end
end
