-- HOME BUILDER (v10): build the inside of your home your way.
--
--   * FURNITURE SHOP: 9 categories (Living Room, Bedroom, Kitchen, Bathroom, Office, Gaming, Decor, Lighting,
--     Luxury). Buying puts the item in your furniture inventory (d.furniture); nothing is placed automatically.
--   * GRID PLACEMENT: inside your own home, place items on a controlled grid (14 x 10 cells of 4 studs). The server
--     checks every placement: inside the room, not on a wall, not in the doorway, not on top of something else, and
--     no more items than your house tier allows. Picking an item up puts it back in your inventory (no refund loop).
--   * HOUSE STYLES: room layout (classic rooms, open loft, split level, master suite), ceiling, door and windows,
--     on top of the v8 wall / floor / lighting styles. A style you bought once can be switched back to for free.
--   * HOUSE TIERS: Starter Home -> Expanded -> Luxury -> Modern Estate -> Mansion -> Mega Mansion -> Empire Estate.
--     Each tier changes the outside (Housing) and raises how many items you can place and which styles unlock.
--   * VISITORS: PUBLIC / FRIENDS / INVITE ONLY / PRIVATE, separately for your house, businesses and HQ.
-- Everything is decoration: it raises the interior score (house ratings, tours) but never adds income.
-- The v8 numbered decor spots keep working: anything already placed there stays exactly where it was.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

-- =====================================================================
-- CATALOG
-- =====================================================================
C.FURNITURE_CATS = {"Living Room", "Bedroom", "Kitchen", "Bathroom", "Office", "Gaming", "Decor", "Lighting", "Luxury"}
-- size = {cells wide, cells deep}; tier = house level needed; shape = parts {sx, sy, sz, ox, oy, oz, color, material}
-- ("accent" = your house colour). Heights are from the floor.
local A = "accent"
C.FURNITURE = {
	-- Living Room
	{key = "sofa", name = "Sofa", icon = "🛋️", cat = "Living Room", cost = 1500, score = 4, size = {2, 1}, tier = 1,
		shape = {{7, 1.2, 2.6, 0, 1.1, 0, A, "Fabric"}, {7, 2, 0.8, 0, 2.3, 1, A, "Fabric"}, {0.8, 1.6, 2.6, -3.1, 1.8, 0, A, "Fabric"}, {0.8, 1.6, 2.6, 3.1, 1.8, 0, A, "Fabric"}}},
	{key = "armchair", name = "Armchair", icon = "💺", cat = "Living Room", cost = 700, score = 2, size = {1, 1}, tier = 1,
		shape = {{3, 1.2, 2.8, 0, 1.1, 0, A, "Fabric"}, {3, 2.2, 0.7, 0, 2.3, 1.1, A, "Fabric"}}},
	{key = "coffeetable", name = "Coffee Table", icon = "🟫", cat = "Living Room", cost = 600, score = 2, size = {1, 1}, tier = 1,
		shape = {{3.4, 0.3, 2.4, 0, 1.6, 0, RGB(150, 105, 70), "Wood"}, {0.4, 1.2, 0.4, -1.4, 0.9, -0.9, RGB(80, 60, 45), "Wood"}, {0.4, 1.2, 0.4, 1.4, 0.9, 0.9, RGB(80, 60, 45), "Wood"}}},
	{key = "tvstand", name = "TV Wall", icon = "📺", cat = "Living Room", cost = 3500, score = 5, size = {2, 1}, tier = 1,
		shape = {{7, 1.6, 1.6, 0, 1.3, 0.8, RGB(40, 40, 46)}, {7.4, 4, 0.3, 0, 4.6, 1.2, RGB(15, 15, 20), "Glass"}}},
	{key = "bookcase", name = "Bookcase", icon = "📚", cat = "Living Room", cost = 900, score = 3, size = {1, 1}, tier = 1,
		shape = {{3.4, 6, 1.4, 0, 3.5, 1.2, RGB(140, 100, 70), "Wood"}, {3, 0.8, 1, 0, 2.2, 1.0, RGB(200, 60, 60)}, {3, 0.8, 1, 0, 4.2, 1.0, RGB(60, 120, 200)}}},
	-- Bedroom
	{key = "singlebed", name = "Single Bed", icon = "🛏️", cat = "Bedroom", cost = 1200, score = 3, size = {1, 2}, tier = 1,
		shape = {{3.4, 1.2, 7, 0, 1, 0, RGB(240, 240, 245), "Fabric"}, {3.4, 2.4, 0.5, 0, 1.8, 3.4, RGB(110, 80, 60), "Wood"}, {3.2, 0.3, 4, 0, 1.7, -1.2, A, "Fabric"}}},
	{key = "kingbed", name = "King Bed", icon = "👑", cat = "Bedroom", cost = 9000, score = 7, size = {2, 2}, tier = 3,
		shape = {{7, 1.4, 7.2, 0, 1.1, 0, RGB(245, 245, 250), "Fabric"}, {7.4, 3.6, 0.6, 0, 2.4, 3.5, RGB(70, 50, 40), "Wood"}, {6.8, 0.3, 4, 0, 1.95, -1.4, A, "Fabric"}}},
	{key = "wardrobe", name = "Wardrobe", icon = "🚪", cat = "Bedroom", cost = 1600, score = 3, size = {1, 1}, tier = 1,
		shape = {{3.4, 7, 1.8, 0, 4, 1, RGB(170, 125, 85), "Wood"}, {0.2, 0.8, 0.2, 0.4, 4, 0.05, RGB(220, 190, 80), "Metal"}}},
	{key = "nightstand", name = "Nightstand + Lamp", icon = "🕯️", cat = "Bedroom", cost = 500, score = 2, size = {1, 1}, tier = 1, light = {0, 3.6, 0},
		shape = {{2, 1.8, 2, 0, 1.4, 0, RGB(150, 105, 70), "Wood"}, {1, 1, 1, 0, 2.8, 0, RGB(255, 235, 190), "Neon"}}},
	-- Kitchen
	{key = "fridge", name = "Fridge", icon = "🧊", cat = "Kitchen", cost = 1800, score = 3, size = {1, 1}, tier = 1,
		shape = {{3, 7, 2.6, 0, 4, 0.4, RGB(225, 230, 235), "Metal"}, {0.2, 2, 0.2, 1.1, 4.5, -0.95, RGB(120, 120, 130), "Metal"}}},
	{key = "stove", name = "Stove", icon = "🍳", cat = "Kitchen", cost = 1400, score = 3, size = {1, 1}, tier = 1,
		shape = {{3.4, 3, 2.6, 0, 2, 0.4, RGB(60, 60, 66), "Metal"}, {2.6, 0.1, 2, 0, 3.55, 0.4, RGB(30, 30, 34)}}},
	{key = "island", name = "Kitchen Island", icon = "🏝️", cat = "Kitchen", cost = 6000, score = 5, size = {2, 1}, tier = 2,
		shape = {{7, 3, 3, 0, 2, 0, RGB(250, 250, 252), "Marble"}, {7.2, 0.3, 3.2, 0, 3.6, 0, RGB(40, 40, 46), "Granite"}}},
	{key = "diningset", name = "Dining Set", icon = "🍽️", cat = "Kitchen", cost = 2200, score = 4, size = {2, 2}, tier = 1,
		shape = {{6, 0.3, 4, 0, 2.6, 0, RGB(170, 120, 75), "Wood"}, {0.6, 2.4, 0.6, 0, 1.3, 0, RGB(90, 70, 50), "Wood"},
			{1.6, 0.3, 1.6, -2, 1.6, 2.8, RGB(150, 100, 60), "Wood"}, {1.6, 0.3, 1.6, 2, 1.6, 2.8, RGB(150, 100, 60), "Wood"}, {1.6, 0.3, 1.6, -2, 1.6, -2.8, RGB(150, 100, 60), "Wood"}, {1.6, 0.3, 1.6, 2, 1.6, -2.8, RGB(150, 100, 60), "Wood"}}},
	-- Bathroom
	{key = "bathtub", name = "Bathtub", icon = "🛁", cat = "Bathroom", cost = 2500, score = 4, size = {2, 1}, tier = 1,
		shape = {{6.4, 2, 3, 0, 1.5, 0, RGB(250, 250, 255), "Marble"}, {5.6, 0.3, 2.2, 0, 2.3, 0, RGB(120, 200, 255), "Glass"}}},
	{key = "shower", name = "Glass Shower", icon = "🚿", cat = "Bathroom", cost = 4000, score = 4, size = {1, 1}, tier = 2,
		shape = {{3.4, 0.3, 3.4, 0, 0.7, 0, RGB(220, 225, 230), "Marble"}, {0.2, 7, 3.4, -1.6, 4, 0, RGB(200, 230, 255), "Glass"}, {3.4, 7, 0.2, 0, 4, -1.6, RGB(200, 230, 255), "Glass"}}},
	{key = "vanity", name = "Vanity + Mirror", icon = "🪞", cat = "Bathroom", cost = 1500, score = 3, size = {1, 1}, tier = 1,
		shape = {{3.4, 3, 1.8, 0, 2, 1, RGB(250, 250, 252), "Marble"}, {2.6, 3, 0.2, 0, 5.4, 1.8, RGB(220, 235, 245), "Glass"}}},
	-- Office
	{key = "officedesk", name = "Office Desk", icon = "🗄️", cat = "Office", cost = 1200, score = 3, size = {2, 1}, tier = 1,
		shape = {{6, 0.3, 2.8, 0, 2.6, 0, RGB(80, 80, 90)}, {0.3, 2.4, 2.6, -2.8, 1.4, 0, RGB(60, 60, 70)}, {0.3, 2.4, 2.6, 2.8, 1.4, 0, RGB(60, 60, 70)}, {1.8, 2, 1.8, 0, 1.4, 2.2, RGB(30, 30, 36), "Fabric"}}},
	{key = "computer", name = "Computer", icon = "💻", cat = "Office", cost = 0, score = 4, size = {1, 1}, tier = 1, shop = false, use = "computer",
		shape = {{3.4, 0.3, 2.4, 0, 2.6, 0, RGB(60, 60, 70)}, {0.4, 2.4, 2, 0, 1.4, 0, RGB(60, 60, 70)}, {2.6, 1.6, 0.2, 0, 3.7, 0.6, RGB(30, 80, 160), "Neon"}}},
	{key = "filing", name = "Filing Cabinet", icon = "🗃️", cat = "Office", cost = 400, score = 1, size = {1, 1}, tier = 1,
		shape = {{2, 4, 2, 0, 2.5, 0.6, RGB(120, 125, 135), "Metal"}}},
	-- Gaming
	{key = "gamingsetup", name = "Gaming Setup", icon = "🎮", cat = "Gaming", cost = 8000, score = 5, size = {2, 1}, tier = 2, light = {0, 4, 1},
		shape = {{6, 0.3, 2.8, 0, 2.6, 0.2, RGB(20, 20, 24)}, {2.6, 1.6, 0.2, -1.5, 3.7, 1, RGB(120, 60, 255), "Neon"}, {2.6, 1.6, 0.2, 1.5, 3.7, 1, RGB(255, 60, 160), "Neon"}, {2, 3.4, 2, 0, 1.8, -1.8, RGB(200, 30, 50), "Fabric"}}},
	{key = "arcademachine", name = "Arcade Machine", icon = "🕹️", cat = "Gaming", cost = 25000, score = 6, size = {1, 1}, tier = 2, use = "arcade", light = {0, 4.5, -1.6},
		shape = {{3, 6.4, 3, 0, 3.7, 0, RGB(60, 40, 140)}, {2.4, 2, 0.2, 0, 4.6, -1.55, RGB(80, 220, 255), "Neon"}, {2.6, 0.4, 1, 0, 3, -1.8, RGB(30, 30, 36)}}},
	{key = "pooltable", name = "Pool Table", icon = "🎱", cat = "Gaming", cost = 15000, score = 5, size = {2, 1}, tier = 3,
		shape = {{7, 0.6, 3.6, 0, 2.6, 0, RGB(30, 120, 60), "Fabric"}, {7.4, 0.4, 4, 0, 2.2, 0, RGB(90, 60, 40), "Wood"}, {0.8, 2, 0.8, -3, 1.2, 0, RGB(90, 60, 40), "Wood"}, {0.8, 2, 0.8, 3, 1.2, 0, RGB(90, 60, 40), "Wood"}}},
	{key = "beanbag", name = "Bean Bag", icon = "🫘", cat = "Gaming", cost = 300, score = 1, size = {1, 1}, tier = 1, ball = true,
		shape = {{2.8, 2.2, 2.8, 0, 1.5, 0, A, "Fabric"}}},
	-- Decor
	{key = "pottedplant", name = "Potted Plant", icon = "🪴", cat = "Decor", cost = 150, score = 1, size = {1, 1}, tier = 1,
		shape = {{1.4, 1.4, 1.4, 0, 1.2, 0, RGB(170, 90, 60), "Slate"}, {2.6, 2.6, 2.6, 0, 3, 0, RGB(70, 160, 80), "Grass", true}}},
	{key = "bigrug", name = "Big Rug", icon = "🟪", cat = "Decor", cost = 500, score = 2, size = {2, 2}, tier = 1, flat = true,
		shape = {{7.2, 0.1, 7.2, 0, 0.56, 0, A, "Fabric"}}},
	{key = "aquarium", name = "Aquarium", icon = "🐠", cat = "Decor", cost = 12000, score = 5, size = {2, 1}, tier = 3, light = {0, 3, 0},
		shape = {{6.4, 1.6, 2.4, 0, 1.3, 0, RGB(40, 40, 46)}, {6.4, 3, 2.4, 0, 3.6, 0, RGB(80, 180, 255), "Glass"}, {1, 0.6, 0.3, -1, 3.5, 0, RGB(255, 140, 40), "Neon"}}},
	{key = "sculpture", name = "Modern Sculpture", icon = "🗿", cat = "Decor", cost = 30000, score = 6, size = {1, 1}, tier = 3,
		shape = {{2.4, 1, 2.4, 0, 1, 0, RGB(40, 40, 46), "Marble"}, {1.2, 3.6, 1.2, 0, 3.3, 0, RGB(230, 230, 235), "Marble"}}},
	-- Lighting
	{key = "floorlamp", name = "Floor Lamp", icon = "💡", cat = "Lighting", cost = 400, score = 2, size = {1, 1}, tier = 1, light = {0, 5, 0},
		shape = {{0.3, 4.4, 0.3, 0, 2.7, 0, RGB(40, 40, 40), "Metal"}, {1.6, 1, 1.6, 0, 5, 0, RGB(255, 240, 200), "Neon"}}},
	{key = "neonbar", name = "Neon Light Bar", icon = "🌈", cat = "Lighting", cost = 2500, score = 3, size = {2, 1}, tier = 2, light = {0, 1.5, 0},
		shape = {{7, 0.4, 0.4, 0, 1.2, 1.4, RGB(255, 60, 200), "Neon"}}},
	{key = "chandelier", name = "Standing Chandelier", icon = "💎", cat = "Lighting", cost = 45000, score = 7, size = {1, 1}, tier = 4, light = {0, 7, 0},
		shape = {{0.4, 6, 0.4, 0, 3.5, 0, RGB(220, 190, 90), "Metal"}, {2.6, 1.6, 2.6, 0, 7, 0, RGB(255, 230, 170), "Neon"}}},
	-- Luxury
	{key = "piano", name = "Grand Piano", icon = "🎹", cat = "Luxury", cost = 120000, score = 9, size = {2, 2}, tier = 4,
		shape = {{6, 1.6, 6, 0, 3.2, 0, RGB(15, 15, 18)}, {0.6, 2.4, 0.6, -2, 1.3, -2, RGB(15, 15, 18)}, {0.6, 2.4, 0.6, 2, 1.3, -2, RGB(15, 15, 18)}, {0.6, 2.4, 0.6, 0, 1.3, 2, RGB(15, 15, 18)}, {5, 0.3, 1, 0, 3.1, -3.2, RGB(245, 245, 245)}}},
	{key = "goldstatue", name = "Golden Statue", icon = "🏆", cat = "Luxury", cost = 400000, score = 12, size = {1, 1}, tier = 5,
		shape = {{2.6, 1, 2.6, 0, 1, 0, RGB(60, 60, 64), "Marble"}, {1.6, 4, 1.6, 0, 3.5, 0, RGB(255, 205, 60), "Metal"}}},
	{key = "hottub", name = "Indoor Hot Tub", icon = "♨️", cat = "Luxury", cost = 250000, score = 10, size = {2, 2}, tier = 5,
		shape = {{7, 2, 7, 0, 1.5, 0, RGB(200, 180, 150), "Wood"}, {6, 0.3, 6, 0, 2.4, 0, RGB(60, 180, 255), "Glass"}}},
	{key = "trophycase", name = "Trophy Case", icon = "🏅", cat = "Luxury", cost = 80000, score = 8, size = {2, 1}, tier = 4,
		shape = {{7, 6, 2, 0, 3.5, 0.8, RGB(200, 230, 255), "Glass"}, {1, 1.4, 1, -2, 3.6, 0.8, RGB(255, 205, 60), "Metal"}, {1, 1.4, 1, 2, 3.6, 0.8, RGB(220, 220, 230), "Metal"}}},
}
C.FURNITURE_BY = {}
for _, it in ipairs(C.FURNITURE) do C.FURNITURE_BY[it.key] = it end

-- =====================================================================
-- HOUSE STYLES
-- =====================================================================
C.HOME_STYLES = {
	layout = {
		{key = "classic", name = "Classic Rooms", icon = "🏠", cost = 0, score = 0, tier = 1, desc = "Living room in front; kitchen, bedroom and bathroom in back."},
		{key = "open", name = "Open Loft", icon = "🏙️", cost = 15000, score = 3, tier = 2, desc = "One big open space. No walls."},
		{key = "split", name = "Split Level", icon = "🪜", cost = 40000, score = 4, tier = 3, desc = "Front lounge and a raised back half."},
		{key = "suite", name = "Master Suite", icon = "👑", cost = 150000, score = 6, tier = 5, desc = "A private suite on one side, a big living area on the other."},
	},
	ceiling = {
		{key = "plain", name = "Plain", icon = "⬜", cost = 0, score = 0, tier = 1},
		{key = "beams", name = "Wood Beams", icon = "🪵", cost = 3000, score = 2, tier = 1},
		{key = "coffered", name = "Coffered", icon = "🔳", cost = 20000, score = 4, tier = 3},
		{key = "skylight", name = "Skylight", icon = "🌤️", cost = 80000, score = 6, tier = 4},
		{key = "stars", name = "Starry Night", icon = "✨", cost = 300000, score = 8, tier = 6},
	},
	door = {
		{key = "wood", name = "Wooden Door", icon = "🚪", cost = 0, score = 0, tier = 1},
		{key = "modern", name = "Modern Door", icon = "⬛", cost = 4000, score = 2, tier = 1},
		{key = "glass", name = "Glass Door", icon = "🪟", cost = 20000, score = 3, tier = 3},
		{key = "gold", name = "Golden Double Door", icon = "✨", cost = 500000, score = 6, tier = 6},
	},
	window = {
		{key = "none", name = "No Windows", icon = "▫️", cost = 0, score = 0, tier = 1},
		{key = "classic", name = "Classic Windows", icon = "🪟", cost = 2000, score = 2, tier = 1},
		{key = "wide", name = "Wide Windows", icon = "🖼️", cost = 15000, score = 4, tier = 2},
		{key = "panoramic", name = "Panoramic Glass", icon = "🌇", cost = 150000, score = 7, tier = 5},
	},
}
local STYLE_BY = {}
for kind, list in pairs(C.HOME_STYLES) do
	STYLE_BY[kind] = {}
	for _, s in ipairs(list) do STYLE_BY[kind][s.key] = s end
end

-- =====================================================================
-- THE GRID
-- =====================================================================
local G = {cols = 14, rows = 10, cell = 4}
C.HOME_GRID = G
-- cell (cx, cz) -> its centre in room coordinates (room centre = 0,0; the door is on the +Z wall)
local function cellX(cx) return -G.cols * G.cell / 2 + (cx - 0.5) * G.cell end
local function cellZ(cz) return -G.rows * G.cell / 2 + (cz - 0.5) * G.cell end
local function key2(cx, cz) return cx .. "," .. cz end

function F.homeLevel(d) return d.home and tonumber(d.home.level) or 0 end
local function hb(d)
	d.homeBuild = type(d.homeBuild) == "table" and d.homeBuild or {}
	local b = d.homeBuild
	b.items = type(b.items) == "table" and b.items or {}
	b.styles = type(b.styles) == "table" and b.styles or {}
	b.owned = type(b.owned) == "table" and b.owned or {}
	b.v = tonumber(b.v) or 0
	d.furniture = type(d.furniture) == "table" and d.furniture or {}
	return b
end
F.homeBuildData = hb
function F.homeStyle(d, kind)
	local s = hb(d).styles[kind]
	if STYLE_BY[kind][s or ""] then return s end
	return C.HOME_STYLES[kind][1].key
end
function F.homeLayout(d) return F.homeStyle(d, "layout") end
-- how many grid items your house tier allows
function F.homeItemCap(d) return 10 + 8 * math.max(1, F.homeLevel(d)) end

-- which region a cell belongs to in each layout (an item can't stand across a wall)
local REGION = {
	classic = function(cx, cz)
		if cz >= 5 then return "living" end
		if cx <= 5 then return "kitchen" elseif cx <= 9 then return "bedroom" end
		return "bathroom"
	end,
	open = function() return "all" end,
	split = function(cx, cz) return cz <= 5 and "back" or "front" end,
	suite = function(cx, cz) return cx <= 5 and "suite" or "living" end,
}
-- cells nothing can stand on: the walkway from the door, built-in fixtures, and filled v8 decor spots
local function blockedCells(d, layout)
	local out = {}
	for _, cx in ipairs({7, 8}) do for _, cz in ipairs({9, 10}) do out[key2(cx, cz)] = "door" end end
	if layout == "classic" then
		for cx = 1, 4 do out[key2(cx, 1)] = "fixture" end   -- kitchen counter
		for cx = 13, 14 do out[key2(cx, 1)] = "fixture" end  -- bathtub
	elseif layout == "open" or layout == "suite" then
		for cx = 1, 4 do out[key2(cx, 1)] = "fixture" end
	elseif layout == "split" then
		for cx = 1, 14 do out[key2(cx, 6)] = "steps" end    -- the step up to the back half
		for _, cx in ipairs({7, 8}) do out[key2(cx, 6)] = nil end
	end
	-- v8 decor spots that hold something stay where they are
	local r = d.interiors and d.interiors.home
	local L = C.interiorLayoutOf and C.interiorLayoutOf("home")
	if type(r) == "table" and type(r.spots) == "table" and L then
		for i, sp in ipairs(L.spots) do
			if sp[3] == "floor" and r.spots[tostring(i)] then
				local cx = math.floor((sp[1] + G.cols * G.cell / 2) / G.cell) + 1
				local cz = math.floor((sp[2] + G.rows * G.cell / 2) / G.cell) + 1
				for dx = -1, 0 do for dz = -1, 0 do out[key2(cx + dx, cz + dz)] = "spot" end end
			end
		end
	end
	return out
end
local function footprint(it, x, z, r)
	local fw, fd = it.size[1], it.size[2]
	if r % 2 == 1 then fw, fd = fd, fw end
	local cells = {}
	for cx = x, x + fw - 1 do for cz = z, z + fd - 1 do table.insert(cells, {cx, cz}) end end
	return cells, fw, fd
end
-- can `it` go at (x, z, r)? `skip` = index of an item being moved (ignored for overlap)
function F.homeCanPlace(d, it, x, z, r, skip)
	local layout = F.homeLayout(d)
	local cells, fw, fd = footprint(it, x, z, r)
	if x < 1 or z < 1 or x + fw - 1 > G.cols or z + fd - 1 > G.rows then return false, "That doesn't fit there." end
	local blocked = blockedCells(d, layout)
	local used = {}
	for i, item in ipairs(hb(d).items) do
		local other = C.FURNITURE_BY[item.k]
		if i ~= skip and other and not other.flat then
			for _, c in ipairs((footprint(other, item.x, item.z, item.r))) do used[key2(c[1], c[2])] = true end
		end
	end
	local region
	for _, c in ipairs(cells) do
		local k = key2(c[1], c[2])
		if blocked[k] then return false, blocked[k] == "door" and "Keep the doorway clear." or "Something built-in is already there." end
		if used[k] and not it.flat then return false, "Something is already there." end
		local rg = REGION[layout](c[1], c[2])
		if region and rg ~= region then return false, "That would stand across a wall." end
		region = rg
	end
	return true
end

-- =====================================================================
-- BUILDING IT (Interiors calls these while it builds your home room)
-- =====================================================================
local H = C.interiorHelpers   -- Interiors' building helpers (box, addLight, wp)
local MATS = {Fabric = MAT.Fabric, Wood = MAT.Wood, Metal = MAT.Metal, Marble = MAT.Marble, Granite = MAT.Granite, Glass = MAT.Glass, Neon = MAT.Neon,
	Slate = MAT.Slate, Grass = MAT.Grass}
local WALLC = RGB(220, 215, 205)
-- a wall along X (at z) from x1 to x2 with door gaps {centre, width}
local function wallX(m, o, z, x1, x2, gaps, h, color)
	local cuts = {x1}
	for _, g in ipairs(gaps or {}) do table.insert(cuts, g[1] - g[2] / 2) table.insert(cuts, g[1] + g[2] / 2) end
	table.insert(cuts, x2)
	for i = 1, #cuts - 1, 2 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a > 0.2 then H.box(m, V3(b - a, h, 0.6), o * CF((a + b) / 2, h / 2 + 0.5, z), color or WALLC, nil, {CanCollide = true}) end
	end
	for _, g in ipairs(gaps or {}) do H.box(m, V3(g[2], 0.3, 0.7), o * CF(g[1], 9.5, z), RGB(160, 150, 140)) end
end
local function wallZ(m, o, x, z1, z2, gaps, h, color)
	local cuts = {z1}
	for _, g in ipairs(gaps or {}) do table.insert(cuts, g[1] - g[2] / 2) table.insert(cuts, g[1] + g[2] / 2) end
	table.insert(cuts, z2)
	for i = 1, #cuts - 1, 2 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a > 0.2 then H.box(m, V3(0.6, h, b - a), o * CF(x, h / 2 + 0.5, (a + b) / 2), color or WALLC, nil, {CanCollide = true}) end
	end
end
local function label(m, o, x, z, text)
	local s = H.box(m, V3(7, 1.2, 0.2), o * CF(x, 10.6, z), RGB(30, 30, 34))
	C.surfaceText(s, Enum.NormalId.Back, text, Color3.new(1, 1, 1))
end
-- the room layout (replaces the v8 fixed partitions). Returns true when it built the rooms.
function C.homeLayoutBuild(m, o, L, accent, layout)
	if not H then return false end
	local hw, hd = L.w / 2, L.d / 2
	local wh = 12
	if layout == "open" then
		H.box(m, V3(12, 3, 2.4), o * CF(-hw + 9, 2, -hd + 2), RGB(240, 240, 240), MAT.Marble)
		H.box(m, V3(12.2, 0.3, 2.6), o * CF(-hw + 9, 3.6, -hd + 2), accent)
	elseif layout == "split" then
		-- the back half is a raised platform with steps in the middle
		H.box(m, V3(L.w - 1, 1.2, hd - 1), o * CF(0, 1.1, -hd / 2 - 0.5 + 0.5), RGB(200, 190, 175), MAT.WoodPlanks, {CanCollide = true})
		for k = 0, 2 do H.box(m, V3(8, 0.4 * (k + 1), 1.4), o * CF(0, 0.5 + 0.2 * (k + 1), 1.5 + k * -1.3 + 1.6), RGB(190, 180, 165), MAT.WoodPlanks, {CanCollide = true}) end
		for _, sx in ipairs({-1, 1}) do H.box(m, V3(hw - 5, 3, 0.3), o * CF(sx * (hw / 2 + 2.5), 3.2, 0.2), RGB(200, 230, 255), MAT.Glass) end
		label(m, o, 0, -hd + 1.2, "🛋️ UPPER LOUNGE")
	elseif layout == "suite" then
		wallZ(m, o, -8, -hd, hd, {{6, 6}}, wh)
		H.box(m, V3(12, 3, 2.4), o * CF(4, 2, -hd + 2), RGB(240, 240, 240), MAT.Marble)
		label(m, o, -19, hd - 1.2, "👑 MASTER SUITE")
	else
		-- classic: front living room; kitchen / bedroom / bathroom in back, now with real doorways
		wallX(m, o, -4, -hw, hw, {{-18, 5}, {0, 5}, {18, 5}}, wh)
		wallZ(m, o, -8, -hd, -4, nil, wh)
		wallZ(m, o, 8, -hd, -4, nil, wh)
		H.box(m, V3(12, 3, 2.4), o * CF(-hw + 9, 2, -hd + 2), RGB(240, 240, 240), MAT.Marble)
		H.box(m, V3(6, 2, 3), o * CF(hw - 6, 1.6, -hd + 3), RGB(250, 250, 255), MAT.Marble)
		for _, lbl in ipairs({{"🍳 KITCHEN", -18}, {"🛏️ BEDROOM", 0}, {"🛁 BATHROOM", 18}}) do label(m, o, lbl[2], -3.6, lbl[1]) end
	end
	H.wp(m, o, "door", 0, hd - 2)
	for _, pt in ipairs({{-14, 6}, {12, 8}, {0, 2}, {-20, 14}}) do H.wp(m, o, "wander", pt[1], pt[2]) end
	return true
end
local layoutNow = "classic"
local function buildFurniture(m, o, it, item, accent, owner)
	local fw, fd = it.size[1], it.size[2]
	if item.r % 2 == 1 then fw, fd = fd, fw end
	local cx = cellX(item.x) + (fw - 1) * G.cell / 2
	local cz = cellZ(item.z) + (fd - 1) * G.cell / 2
	local lift = (layoutNow == "split" and item.z + fd - 1 <= 5) and 1.2 or 0
	local cf = o * CF(cx, lift, cz) * CFrame.Angles(0, item.r * math.pi / 2, 0)
	local first
	for _, s in ipairs(it.shape) do
		local col = s[7] == A and accent or s[7]
		local p = H.box(m, V3(s[1], s[2], s[3]), cf * CF(s[4], s[5], s[6]), col, MATS[s[8] or ""] or MAT.SmoothPlastic)
		if s[9] or it.ball then p.Shape = Enum.PartType.Ball end
		first = first or p
	end
	if it.light then
		local lp = H.box(m, V3(0.4, 0.4, 0.4), cf * CF(it.light[1], it.light[2], it.light[3]), RGB(255, 240, 210), MAT.Neon, {Transparency = 1})
		H.addLight(lp, RGB(255, 225, 180), 1.2, 16)
	end
	-- usable items: your computer, your arcade machine
	if it.use == "computer" then
		C.prompt(first, "Use Computer", "Computer", 8, 0, function(plr)
			if plr == owner and F.openComputer then F.openComputer(plr, "home") end
		end)
	elseif it.use == "arcade" then
		C.prompt(first, "Play", "Arcade Machine", 8, 0, function(plr)
			if F.arcadeMachine then F.arcadeMachine(plr, owner, "home") end
		end)
	end
	return first
end
local function buildStyles(m, o, L, d, accent)
	local hw, hd, top = L.w / 2, L.d / 2, 14
	local ceiling = F.homeStyle(d, "ceiling")
	if ceiling == "beams" then
		for x = -hw + 6, hw - 6, 8 do H.box(m, V3(1.2, 1.2, L.d - 1), o * CF(x, top - 1.1, 0), RGB(120, 85, 55), MAT.Wood) end
	elseif ceiling == "coffered" then
		for x = -hw + 8, hw - 8, 10 do H.box(m, V3(0.8, 1, L.d - 1), o * CF(x, top - 1, 0), RGB(250, 250, 250)) end
		for z = -hd + 8, hd - 8, 10 do H.box(m, V3(L.w - 1, 1, 0.8), o * CF(0, top - 1, z), RGB(250, 250, 250)) end
	elseif ceiling == "skylight" then
		H.box(m, V3(20, 0.3, 12), o * CF(0, top - 0.6, 4), RGB(150, 210, 255), MAT.Neon, {Transparency = 0.2})
		H.box(m, V3(21, 0.6, 13), o * CF(0, top - 0.4, 4), RGB(240, 240, 245))
	elseif ceiling == "stars" then
		H.box(m, V3(L.w - 1, 0.2, L.d - 1), o * CF(0, top - 0.6, 0), RGB(14, 16, 40))
		local rnd = Random.new(d.plot and d.plot.index or 1)
		for _ = 1, 40 do H.box(m, V3(0.3, 0.1, 0.3), o * CF(rnd:NextNumber(-hw + 1, hw - 1), top - 0.75, rnd:NextNumber(-hd + 1, hd - 1)), RGB(255, 255, 220), MAT.Neon) end
	end
	local door = F.homeStyle(d, "door")
	if door ~= "wood" then
		local col = ({modern = RGB(30, 30, 34), glass = RGB(200, 230, 255), gold = RGB(230, 190, 80)})[door]
		local p = H.box(m, V3(door == "gold" and 7 or 5.6, 8.6, 0.3), o * CF(0, 4.8, hd - 0.75), col, door == "glass" and MAT.Glass or (door == "gold" and MAT.Metal or MAT.SmoothPlastic))
		if door == "glass" then p.Transparency = 0.35 end
		if door == "gold" then H.box(m, V3(0.15, 8.6, 0.35), o * CF(0, 4.8, hd - 0.8), RGB(120, 90, 30), MAT.Metal) end
	end
	local win = F.homeStyle(d, "window")
	if win ~= "none" then
		local w, h = ({classic = {4, 4}, wide = {9, 5}, panoramic = {16, 8}})[win][1], ({classic = {4, 4}, wide = {9, 5}, panoramic = {16, 8}})[win][2]
		local zs = win == "panoramic" and {0} or {-hd / 2, hd / 2}
		for _, sx in ipairs({-1, 1}) do
			for _, z in ipairs(zs) do
				local g = H.box(m, V3(0.3, h, w), o * CF(sx * (hw - 0.6), 6.5, z), RGB(150, 200, 255), MAT.Glass)
				g.Transparency = 0.15
				H.box(m, V3(0.4, h + 0.6, 0.4), o * CF(sx * (hw - 0.65), 6.5, z - w / 2), RGB(250, 250, 250))
				H.box(m, V3(0.4, h + 0.6, 0.4), o * CF(sx * (hw - 0.65), 6.5, z + w / 2), RGB(250, 250, 250))
			end
		end
	end
end
-- everything placed with the builder (Interiors calls this at the end of building the home room)
function C.buildHomeExtras(m, o, L, d, owner, accent)
	if not H then return end
	local ok, err = pcall(buildStyles, m, o, L, d, accent)
	if not ok then warn("[CornerEmpire] home styles: " .. tostring(err)) end
	layoutNow = F.homeLayout(d)
	for _, item in ipairs(hb(d).items) do
		local it = C.FURNITURE_BY[item.k]
		if it then
			local ok2, err2 = pcall(buildFurniture, m, o, it, item, accent, owner)
			if not ok2 then warn("[CornerEmpire] furniture " .. tostring(item.k) .. ": " .. tostring(err2)) end
		end
	end
end

-- interior score: placed items (a repeated item counts half, so variety wins) + the house styles
function F.homeBuildScore(d)
	local b = hb(d)
	local score, used, n = 0, {}, 0
	for _, item in ipairs(b.items) do
		local it = C.FURNITURE_BY[item.k]
		if it then
			score += used[it.key] and it.score * 0.5 or it.score
			used[it.key] = true
			n += 1
		end
	end
	for kind in pairs(C.HOME_STYLES) do
		local s = STYLE_BY[kind][F.homeStyle(d, kind)]
		if s then score += s.score end
	end
	return score, n
end

-- =====================================================================
-- ACTIONS (all checked here)
-- =====================================================================
local function insideOwnHome(plr)
	return plr:GetAttribute("Interior") == "home" and plr:GetAttribute("InteriorOwner") == plr.UserId
end
local function rebuild(plr, d)
	hb(d).v += 1
	if F.rebuildInteriorOf then F.rebuildInteriorOf(plr) end
	local lot = F.homeLot and F.homeLot(d)
	if lot and F.refreshHomeSign then F.refreshHomeSign(lot) end
end
function F.builderState(plr, d)
	local b = hb(d)
	local layout = F.homeLayout(d)
	local blocked = {}
	for k, why in pairs(blockedCells(d, layout)) do table.insert(blocked, {k, why}) end
	local items = {}
	for i, item in ipairs(b.items) do
		local it = C.FURNITURE_BY[item.k]
		if it then table.insert(items, {i = i, k = item.k, x = item.x, z = item.z, r = item.r, w = it.size[1], d = it.size[2], icon = it.icon, name = it.name, flat = it.flat}) end
	end
	local inv = {}
	for k, n in pairs(d.furniture) do
		local it = C.FURNITURE_BY[k]
		if it and (tonumber(n) or 0) > 0 then table.insert(inv, {k = k, n = n, icon = it.icon, name = it.name, w = it.size[1], d = it.size[2]}) end
	end
	table.sort(inv, function(x, y) return x.name < y.name end)
	local styles = {}
	for kind, list in pairs(C.HOME_STYLES) do
		styles[kind] = {current = F.homeStyle(d, kind), list = {}}
		for _, s in ipairs(list) do
			table.insert(styles[kind].list, {key = s.key, name = s.name, icon = s.icon, cost = s.cost, tier = s.tier, owned = s.cost == 0 or b.owned[kind .. "." .. s.key] == true, desc = s.desc})
		end
	end
	local sc = F.interiorScore100 and F.interiorScore100(d, "home") or 0
	return {cols = G.cols, rows = G.rows, items = items, inventory = inv, blocked = blocked, styles = styles, cap = F.homeItemCap(d), level = F.homeLevel(d),
		levelName = C.HOME_LEVELS[math.max(1, F.homeLevel(d))], inside = insideOwnHome(plr), score = sc, perms = F.permState(d)}
end
local function sendBuilder(plr, d) R.Menu:FireClient(plr, "builder", F.builderState(plr, d)) end
F.sendBuilder = sendBuilder

function F.buyFurniture(plr, key, qty)
	local d = data[plr]
	local it = C.FURNITURE_BY[key]
	if not (d and it) or it.shop == false then return false end
	qty = math.clamp(qty or 1, 1, 5)
	if F.homeLevel(d) < it.tier then notify(plr, "🔒 " .. it.name .. " needs a " .. C.HOME_LEVELS[it.tier] .. ".") return false end
	local cost = it.cost * qty
	if d.cash < cost then notify(plr, "🛋️ " .. it.name .. " costs $" .. fmt(cost) .. ".") return false end
	hb(d)
	local owned = 0
	for _, n in pairs(d.furniture) do owned += tonumber(n) or 0 end
	if owned + qty > 120 then notify(plr, "🛋️ Your storage is full (120 items). Place or sell some first.") return false end
	d.cash -= cost
	d.furniture[key] = (tonumber(d.furniture[key]) or 0) + qty
	notify(plr, "🛋️ " .. it.icon .. " " .. it.name .. (qty > 1 and (" ×" .. qty) or "") .. " is in your furniture storage (-$" .. fmt(cost) .. ").")
	if F.guideTip then F.guideTip(plr, "furniture") end
	return true
end
function F.sellFurniture(plr, key)
	local d = data[plr]
	local it = C.FURNITURE_BY[key]
	if not (d and it) or it.shop == false then return false end
	hb(d)
	if (tonumber(d.furniture[key]) or 0) <= 0 then return false end
	d.furniture[key] -= 1
	if d.furniture[key] <= 0 then d.furniture[key] = nil end
	local back = math.floor(it.cost * 0.4)
	d.cash += back
	notify(plr, "🛋️ Sold a " .. it.name .. " for $" .. fmt(back) .. ".")
	return true
end
function F.placeFurniture(plr, key, x, z, r)
	local d = data[plr]
	local it = C.FURNITURE_BY[key]
	if not (d and it) then return false end
	if not insideOwnHome(plr) then notify(plr, "🔨 Go inside your home to place furniture.") return false end
	local b = hb(d)
	if (tonumber(d.furniture[key]) or 0) <= 0 then notify(plr, "🛋️ You don't have a " .. it.name .. " in storage.") return false end
	if #b.items >= F.homeItemCap(d) then notify(plr, "🏠 Your " .. C.HOME_LEVELS[math.max(1, F.homeLevel(d))] .. " holds " .. F.homeItemCap(d) .. " items. Upgrade the house for more room.") return false end
	local ok, why = F.homeCanPlace(d, it, x, z, r)
	if not ok then notify(plr, "🔨 " .. why) return false end
	d.furniture[key] -= 1
	if d.furniture[key] <= 0 then d.furniture[key] = nil end
	table.insert(b.items, {k = key, x = x, z = z, r = r})
	rebuild(plr, d)
	return true
end
function F.moveFurniture(plr, i, x, z, r)
	local d = data[plr]
	if not d or not insideOwnHome(plr) then return false end
	local b = hb(d)
	local item = b.items[i]
	local it = item and C.FURNITURE_BY[item.k]
	if not it then return false end
	local ok, why = F.homeCanPlace(d, it, x, z, r, i)
	if not ok then notify(plr, "🔨 " .. why) return false end
	item.x, item.z, item.r = x, z, r
	rebuild(plr, d)
	return true
end
function F.pickUpFurniture(plr, i)
	local d = data[plr]
	if not d or not insideOwnHome(plr) then return false end
	local b = hb(d)
	local item = b.items[i]
	if not item then return false end
	table.remove(b.items, i)
	if C.FURNITURE_BY[item.k] then d.furniture[item.k] = (tonumber(d.furniture[item.k]) or 0) + 1 end
	rebuild(plr, d)
	return true
end
function F.setHomeStyle(plr, kind, key)
	local d = data[plr]
	local s = STYLE_BY[kind] and STYLE_BY[kind][key]
	if not (d and s) then return false end
	if not insideOwnHome(plr) then notify(plr, "🔨 Go inside your home to restyle it.") return false end
	local b = hb(d)
	if F.homeStyle(d, kind) == key then return false end
	if F.homeLevel(d) < s.tier then notify(plr, "🔒 " .. s.name .. " needs a " .. C.HOME_LEVELS[s.tier] .. ".") return false end
	local id = kind .. "." .. key
	if s.cost > 0 and not b.owned[id] then
		if d.cash < s.cost then notify(plr, "🔨 " .. s.name .. " costs $" .. fmt(s.cost) .. ".") return false end
		d.cash -= s.cost
		b.owned[id] = true
	end
	if kind == "layout" then
		-- a new layout moves walls: anything that no longer fits goes back into storage
		b.styles.layout = key
		local returned = 0
		local items = b.items
		b.items = {}
		for _, item in ipairs(items) do
			local it = C.FURNITURE_BY[item.k]
			if it and F.homeCanPlace(d, it, item.x, item.z, item.r) then table.insert(b.items, item)
			elseif it then
				d.furniture[item.k] = (tonumber(d.furniture[item.k]) or 0) + 1
				returned += 1
			end
		end
		if returned > 0 then notify(plr, "📦 " .. returned .. " item" .. (returned == 1 and "" or "s") .. " didn't fit the new layout and went back into storage.") end
	else
		b.styles[kind] = key
	end
	notify(plr, "🔨 " .. s.icon .. " " .. s.name .. "!")
	rebuild(plr, d)
	return true
end

-- =====================================================================
-- VISITORS: who may come into your house / businesses / HQ
-- =====================================================================
C.PERM_MODES = {"public", "friends", "invite", "private"}
local PERM_OK = {public = true, friends = true, invite = true, private = true}
local PERM_DEFAULT = {house = "public", business = "public", hq = "friends"}
local function perms(d)
	d.perms = type(d.perms) == "table" and d.perms or {}
	for k, v in pairs(PERM_DEFAULT) do if not PERM_OK[d.perms[k] or ""] then d.perms[k] = v end end
	d.invites = type(d.invites) == "table" and d.invites or {}
	return d.perms
end
function F.permState(d)
	local p = perms(d)
	local inv = {}
	for id, on in pairs(d.invites) do
		if on then
			local who = Players:GetPlayerByUserId(tonumber(id) or 0)
			table.insert(inv, {id = tonumber(id), name = who and who.Name or ("#" .. tostring(id))})
		end
	end
	return {house = p.house, business = p.business, hq = p.hq, invites = inv}
end
local friendCache = {}   -- ["a:b"] = {ok, t}
function F.areFriends(a, b)
	if C.friendCheck then return C.friendCheck(a, b) end   -- (tests)
	local id = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	local c = friendCache[id]
	if c and os.clock() - c[2] < 300 then return c[1] end
	local ok, res = pcall(function() return a:IsFriendsWith(b.UserId) end)
	local yes = ok and res == true
	friendCache[id] = {yes, os.clock()}
	return yes
end
function F.canVisit(plr, owner, key)
	if plr == owner then return true end
	local od = data[owner]
	if not od then return false end
	local kind = BIZ[key] and "business" or (type(key) == "string" and key:match("^hq%d$") and "hq" or "house")
	local mode = perms(od)[kind]
	if mode == "public" then return true end
	if mode == "private" then return false end
	local invited = od.invites[tostring(plr.UserId)] == true
	if mode == "invite" then return invited end
	return invited or F.areFriends(plr, owner)
end
function F.setPerm(plr, kind, mode)
	local d = data[plr]
	if not (d and PERM_DEFAULT[kind] and PERM_OK[mode]) then return false end
	perms(d)[kind] = mode
	notify(plr, "🔐 " .. ({house = "House", business = "Businesses", hq = "HQ"})[kind] .. ": " .. string.upper(mode == "invite" and "invite only" or mode))
	-- visitors who aren't allowed any more are shown out
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= plr and other:GetAttribute("InteriorOwner") == plr.UserId then
			local where = other:GetAttribute("Interior")
			if where and not F.canVisit(other, plr, where) then
				F.leaveInterior(other)
				notify(other, "🔒 " .. plr.Name .. " closed their doors to visitors.")
			end
		end
	end
	return true
end
function F.setInvite(plr, targetId, on)
	local d = data[plr]
	local target = Players:GetPlayerByUserId(targetId)
	if not (d and target) or target == plr then return false end   -- you can only invite someone in this server
	perms(d)
	local n = 0
	for _, v in pairs(d.invites) do if v then n += 1 end end
	if on and n >= 30 then notify(plr, "🔐 Your invite list is full (30).") return false end
	d.invites[tostring(targetId)] = on and true or nil
	if on then
		notify(plr, "💌 Invited " .. target.Name .. ".")
		notify(target, "💌 " .. plr.Name .. " invited you to visit!")
	else
		notify(plr, "🔐 " .. target.Name .. " is no longer invited.")
	end
	return true
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.hbState = function(plr, d) sendBuilder(plr, d) end
C.ACTIONS.hbBuy = function(plr, d, a, b)
	if C.str(a, 24) then F.buyFurniture(plr, a, C.int(b, 1, 5) or 1) sendBuilder(plr, d) end
end
C.ACTIONS.hbSell = function(plr, d, a)
	if C.str(a, 24) then F.sellFurniture(plr, a) sendBuilder(plr, d) end
end
C.ACTIONS.hbPlace = function(plr, d, a, b, c)
	-- b = {x, z, r}
	if not (C.str(a, 24) and type(b) == "table") then return end
	local x, z, r = C.int(b[1], 1, G.cols), C.int(b[2], 1, G.rows), C.int(b[3], 0, 3)
	if x and z and r then F.placeFurniture(plr, a, x, z, r) end
	sendBuilder(plr, d)
end
C.ACTIONS.hbMove = function(plr, d, a, b)
	if type(b) ~= "table" then return end
	local i, x, z, r = C.int(a, 1, 200), C.int(b[1], 1, G.cols), C.int(b[2], 1, G.rows), C.int(b[3], 0, 3)
	if i and x and z and r then F.moveFurniture(plr, i, x, z, r) end
	sendBuilder(plr, d)
end
C.ACTIONS.hbPick = function(plr, d, a)
	local i = C.int(a, 1, 200)
	if i then F.pickUpFurniture(plr, i) end
	sendBuilder(plr, d)
end
C.ACTIONS.hbStyle = function(plr, d, a, b)
	if C.str(a, 12) and C.str(b, 16) then F.setHomeStyle(plr, a, b) end
	sendBuilder(plr, d)
end
C.ACTIONS.perm = function(plr, d, a, b)
	if C.str(a, 12) and C.str(b, 12) then F.setPerm(plr, a, b) end
	sendBuilder(plr, d)
end
C.ACTIONS.invite = function(plr, d, a, b)
	local id = C.int(a, 1)
	if id then F.setInvite(plr, id, b == true) end
	sendBuilder(plr, d)
end
C.furnitureCatalog = function()
	local out = {}
	for _, it in ipairs(C.FURNITURE) do
		if it.shop ~= false then table.insert(out, {key = it.key, name = it.name, icon = it.icon, cat = it.cat, cost = it.cost, score = it.score, w = it.size[1], d = it.size[2], tier = it.tier}) end
	end
	return {cats = C.FURNITURE_CATS, items = out}
end
Players.PlayerRemoving:Connect(function(plr)
	for id in pairs(friendCache) do
		if id:find(tostring(plr.UserId), 1, true) then friendCache[id] = nil end
	end
end)
end
