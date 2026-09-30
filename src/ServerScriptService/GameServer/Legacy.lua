-- LEGACY: hidden places to explore, relics, and (below) the Legacy Museum and Mystery Lots.
return function(C)
local Workspace = game:GetService("Workspace")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, ball, cyl, ghost, billboard, surfaceText, smoke, sparkle, burst, spin =
	C.P, C.ball, C.cyl, C.ghost, C.billboard, C.surfaceText, C.smoke, C.sparkle, C.burst, C.spin
local fmt, notify = C.fmt, C.notify
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 250), RGB(30, 30, 36)

local FOLDER = Instance.new("Folder")
FOLDER.Name = "Secrets"
FOLDER.Parent = C.WORLD

-- ===== HIDDEN SPOTS =====
-- each spot gets a small, easy-to-miss prop; walking close to it "finds" it (once per save)
for _, s in ipairs(C.SECRET_SPOTS) do
	local p = s.pos
	C.reserve(p.X - s.radius, p.Z - s.radius, p.X + s.radius, p.Z + s.radius)
	if s.key == "launchpad" then
		P(FOLDER, V3(26, 1, 26), CF(p + V3(0, 0.5, 0)), RGB(120, 120, 125), MAT.Concrete, SOLID)
		for _, sx in ipairs({-9, 9}) do
			for _, sz in ipairs({-9, 9}) do P(FOLDER, V3(0.8, 0.12, 0.8), CF(p + V3(sx, 1.05, sz)), RGB(255, 200, 40), MAT.Neon) end
		end
		P(FOLDER, V3(3, 30, 3), CF(p + V3(-8, 15.5, 0)), RGB(170, 90, 60), MAT.CorrodedMetal, SOLID)
		for y = 4, 28, 6 do P(FOLDER, V3(7, 0.4, 0.4), CF(p + V3(-5, y, 0)), RGB(170, 90, 60), MAT.CorrodedMetal) end
		cyl(FOLDER, 16, 4, CF(p + V3(0, 9, 0)), RGB(225, 225, 230), MAT.Metal)
		ball(FOLDER, V3(4, 6, 4), CF(p + V3(0, 18, 0)), RGB(220, 60, 50), MAT.Metal)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			P(FOLDER, V3(0.4, 4, 2.4), CF(p + V3(math.cos(a) * 2.4, 2.5, math.sin(a) * 2.4)) * CFrame.Angles(0, -a, 0), RGB(220, 60, 50), MAT.Metal)
		end
		local hatch = cyl(FOLDER, 0.3, 5, CF(p + V3(6, 1.15, 6)), RGB(90, 255, 160), MAT.Neon)
		billboard(hatch, UDim2.fromOffset(60, 40), V3(0, 3, 0), {{text = "???"}}, 45)
	else
		local relic
		if s.key == "goldenlemon" then
			relic = ball(FOLDER, V3(1.6, 1.6, 2), CF(p + V3(0, 0.8, 0)), RGB(255, 210, 50), MAT.Foil)
		elseif s.key == "diamondbean" then
			relic = ball(FOLDER, V3(1, 1.4, 0.8), CF(p + V3(0, 0.7, 0)), RGB(180, 240, 255), MAT.Glass, {Reflectance = 0.5, Transparency = 0.2})
		else
			relic = P(FOLDER, V3(1.6, 0.25, 1.2), CF(p + V3(0, 0.3, 0)) * CFrame.Angles(0, 0.4, 0), RGB(235, 215, 170), MAT.Fabric)
		end
		sparkle(relic, RGB(255, 235, 150), 4)
	end
end
local function findSpots(plr, d, root)
	d.found = d.found or {}
	for _, s in ipairs(C.SECRET_SPOTS) do
		if not d.found[s.key] then
			local dx, dz = root.Position.X - s.pos.X, root.Position.Z - s.pos.Z
			if dx * dx + dz * dz < s.radius * s.radius and math.abs(root.Position.Y - s.pos.Y) < 16 then
				d.found[s.key] = true
				d.cash += s.cash
				d.earned += s.cash
				F.addRep(plr, s.rep)
				R.Splash:FireClient(plr, s.icon .. " SECRET FOUND: " .. string.upper(s.name), s.text .. "  (+$" .. fmt(s.cash) .. ")", RGB(255, 225, 120))
				burst(s.pos + V3(0, 4, 0), RGB(255, 225, 120), 120)
				if s.relic and F.achieve then F.achieve(plr, "relic") end
				F.checkCombos(plr, d)
				if F.refreshMuseum then F.refreshMuseum(plr) end
			end
		end
	end
end

-- one slow loop for exploration checks (4 players x a handful of spots, once a second)
task.spawn(function()
	while true do
		task.wait(1)
		for plr, d in pairs(data) do
			local ch = plr.Character
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			if root then
				local ok, err = pcall(findSpots, plr, d, root)
				if not ok then warn("[CornerEmpire] exploration check failed: " .. tostring(err)) end
			end
		end
	end
end)

-- =====================================================================
-- THE LEGACY MUSEUM: one gallery per player, filled with physical exhibits of their achievements.
-- Everything shown comes from data that survives rebirths (achievements, finds, eras, rebirth count).
-- =====================================================================
local MUSEUM = V3(120, 0, -215)
C.MUSEUM_AT = MUSEUM
C.reserve(MUSEUM.X - 52, MUSEUM.Z - 36, MUSEUM.X + 52, MUSEUM.Z + 66)
local GOLD, MARBLE = RGB(255, 205, 60), RGB(235, 232, 225)
local museum = Instance.new("Model")
museum.Name = "LegacyMuseum"
museum.Parent = C.WORLD
do
	local m = MUSEUM
	P(museum, V3(100, 1, 68), CF(m + V3(0, 0.5, 0)), MARBLE, MAT.Marble, SOLID)
	P(museum, V3(100, 22, 2), CF(m + V3(0, 12, -33)), RGB(210, 205, 195), MAT.Limestone, SOLID)
	for _, sx in ipairs({-49, 49}) do P(museum, V3(2, 22, 68), CF(m + V3(sx, 12, 0)), RGB(210, 205, 195), MAT.Limestone, SOLID) end
	for _, sx in ipairs({-31, 31}) do P(museum, V3(38, 22, 2), CF(m + V3(sx, 12, 33)), RGB(210, 205, 195), MAT.Limestone, SOLID) end
	P(museum, V3(24, 8, 2), CF(m + V3(0, 19, 33)), RGB(210, 205, 195), MAT.Limestone, SOLID)
	P(museum, V3(100, 1, 68), CF(m + V3(0, 23.5, 0)), RGB(170, 210, 240), MAT.Glass, {Transparency = 0.55, CanCollide = true})
	-- portico: steps, columns, pediment and the name
	P(museum, V3(44, 1, 14), CF(m + V3(0, 0.5, 40)), MARBLE, MAT.Marble, SOLID)
	for k = 0, 5 do cyl(museum, 20, 2.2, CF(m + V3(-19 + k * 7.6, 11, 44)), MARBLE, MAT.Marble) end
	P(museum, V3(48, 2, 10), CF(m + V3(0, 22, 42)), MARBLE, MAT.Marble)
	local sign = C.wedge(museum, V3(48, 7, 10), CF(m + V3(0, 26.5, 42)) * CFrame.Angles(0, math.pi, 0), MARBLE, MAT.Marble)
	local plate = P(museum, V3(30, 4, 0.4), CF(m + V3(0, 26, 47.3)), RGB(40, 36, 30), MAT.SmoothPlastic)
	surfaceText(plate, Enum.NormalId.Front, "🏛️ LEGACY MUSEUM", GOLD)
	surfaceText(plate, Enum.NormalId.Back, "🏛️ LEGACY MUSEUM", GOLD)
	-- gallery dividers
	for _, dx in ipairs({-24, 0, 24}) do P(museum, V3(1, 14, 40), CF(m + V3(dx, 8, -12)), RGB(225, 220, 210), MAT.Limestone, SOLID) end
end
local GALLERY_X = {-37, -12, 12, 37}
local galleries = {}
local function pedestal(parent, pos, color)
	cyl(parent, 3, 3.6, CF(pos + V3(0, 2, 0)), MARBLE, MAT.Marble, SOLID)
	cyl(parent, 0.3, 3.9, CF(pos + V3(0, 3.6, 0)), color, MAT.Neon)
	return pos + V3(0, 3.7, 0)
end
-- a little sculpture for each kind of exhibit
local SHAPES = {}
function SHAPES.stand(m, at)
	P(m, V3(2.4, 1.2, 1.4), CF(at + V3(0, 0.6, 0)), RGB(170, 120, 70), MAT.Wood)
	for k = 0, 3 do P(m, V3(0.6, 0.1, 1.2), CF(at + V3(-0.9 + k * 0.6, 1.9, 0)) * CFrame.Angles(math.rad(-15), 0, 0), k % 2 == 0 and RGB(255, 214, 60) or WHITE) end
end
function SHAPES.tower(m, at)
	for k = 0, 3 do P(m, V3(1.8 - k * 0.3, 0.8, 1.8 - k * 0.3), CF(at + V3(0, 0.4 + k * 0.8, 0)), GOLD, MAT.Foil) end
	ball(m, V3(0.6, 0.6, 0.6), CF(at + V3(0, 3.6, 0)), GOLD, MAT.Neon)
end
function SHAPES.coins(m, at)
	for k = 0, 4 do cyl(m, 0.3, 1.4, CF(at + V3(math.sin(k) * 0.2, 0.15 + k * 0.3, 0)), GOLD, MAT.Foil) end
end
function SHAPES.diamond(m, at)
	local dm = ball(m, V3(1.6, 2, 1.6), CF(at + V3(0, 1.3, 0)), RGB(180, 240, 255), MAT.Glass, {Transparency = 0.2, Reflectance = 0.5})
	spin(dm, 1)
	sparkle(dm, RGB(200, 245, 255), 6)
end
function SHAPES.trophy(m, at)
	cyl(m, 0.4, 1.2, CF(at + V3(0, 0.2, 0)), GOLD, MAT.Foil)
	cyl(m, 1, 0.3, CF(at + V3(0, 0.9, 0)), GOLD, MAT.Foil)
	cyl(m, 1.2, 1.4, CF(at + V3(0, 2, 0)), GOLD, MAT.Foil)
end
function SHAPES.house(m, at)
	P(m, V3(2, 1.4, 1.6), CF(at + V3(0, 0.7, 0)), RGB(236, 226, 205), MAT.Limestone)
	C.wedge(m, V3(2.2, 0.9, 0.9), CF(at + V3(0, 1.85, -0.45)), RGB(60, 60, 70))
	C.wedge(m, V3(2.2, 0.9, 0.9), CF(at + V3(0, 1.85, 0.45)) * CFrame.Angles(0, math.pi, 0), RGB(60, 60, 70))
end
function SHAPES.orb(m, at, color)
	local o = ball(m, V3(1.6, 1.6, 1.6), CF(at + V3(0, 1, 0)), color or RGB(255, 120, 255), MAT.Neon)
	sparkle(o, color or RGB(255, 120, 255), 8)
end
function SHAPES.vault(m, at)
	P(m, V3(2, 2, 1.6), CF(at + V3(0, 1, 0)), RGB(60, 64, 76), MAT.Metal)
	C.xcyl(m, 0.2, 1.4, CF(at + V3(0, 1, 0.85)) * CFrame.Angles(0, math.rad(90), 0), RGB(180, 185, 195), MAT.Metal)
end
function SHAPES.relic(m, at, color)
	local r = ball(m, V3(1.2, 1.2, 1.4), CF(at + V3(0, 0.8, 0)), color or GOLD, MAT.Foil)
	sparkle(r, RGB(255, 235, 150), 6)
end
function SHAPES.crate(m, at, color)
	P(m, V3(1.8, 1.8, 1.8), CF(at + V3(0, 0.9, 0)), RGB(160, 120, 70), MAT.WoodPlanks)
	P(m, V3(1.9, 0.2, 1.9), CF(at + V3(0, 1.85, 0)), color or GOLD, MAT.Neon)
end
function SHAPES.spire(m, at, color)
	cyl(m, 1, 1.6, CF(at + V3(0, 0.5, 0)), RGB(170, 175, 185), MAT.Granite)
	cyl(m, 2, 0.9, CF(at + V3(0, 2, 0)), RGB(70, 110, 170), MAT.Glass)
	ball(m, V3(0.7, 0.7, 0.7), CF(at + V3(0, 3.3, 0)), color or RGB(120, 220, 255), MAT.Neon)
end
function SHAPES.phone(m, at)
	P(m, V3(1, 1.8, 0.2), CF(at + V3(0, 1, 0)), RGB(20, 20, 24))
	P(m, V3(0.85, 1.55, 0.05), CF(at + V3(0, 1, 0.11)), RGB(255, 110, 200), MAT.Neon)
end
local RARITY_COLOR = {Common = RGB(200, 200, 210), Uncommon = RGB(90, 220, 120), Rare = RGB(80, 160, 255), LEGENDARY = GOLD}
local function exhibitsFor(d)
	local a = d.achievements or {}
	local list = {}
	local function add(icon, title, shape, color) table.insert(list, {icon = icon, title = title, shape = shape, color = color}) end
	if a.firstBusiness then add("🏪", "First Business", "stand") end
	if a.firstLandmark then add("🌟", "First Landmark", "tower") end
	if a.million then add("💰", "First Million", "coins") end
	if a.billion then add("💎", "First Billion", "diamond") end
	if a.trackRecord then add("🏆", "Track Record", "trophy") elseif a.raceWin then add("🏁", "Race Champion", "trophy") end
	if a.mansion then add("🏰", "First Mansion", "house") elseif a.dreamHome then add("🏡", "Dream Home", "house") end
	for _, r in ipairs({{10, "💼", RGB(90, 200, 255)}, {50, "🎩", RGB(200, 120, 255)}, {100, "👑", GOLD}}) do
		if d.rebirths >= r[1] then add(r[2], r[1] .. " Rebirths", "orb", r[3]) end
	end
	local secrets = 0
	for _, c in ipairs(C.COMBOS) do
		if c.secret and d.combos[c.key] then secrets += 1 end
	end
	if secrets > 0 then add("🤫", secrets .. " Secret Business" .. (secrets > 1 and "es" or ""), "vault") end
	for _, sp in ipairs(C.SECRET_SPOTS) do
		if sp.relic and d.found and d.found[sp.key] then
			add(sp.icon, sp.name, "relic", sp.key == "diamondbean" and RGB(180, 240, 255) or (sp.key == "blueprint" and RGB(235, 215, 170) or GOLD))
		end
	end
	for _, f in ipairs(C.MYSTERY_FINDS) do
		if d.mystery and (d.mystery[f.key] or 0) > 0 and (f.rarity == "Rare" or f.rarity == "LEGENDARY") then add(f.icon, f.name, "crate", RARITY_COLOR[f.rarity]) end
	end
	if (d.eraContrib or 1) >= 2 then add("🌆", "Built Era " .. d.eraContrib .. ": " .. C.eraName(d.eraContrib), "spire") end
	if a.viral then add("🔥", "Went Viral", "phone") end
	if d.trophies > 0 then add("🏆", d.trophies .. " Trophies", "trophy") end
	while #list > 12 do table.remove(list) end
	return list
end
C.museumExhibits = exhibitsFor
local function buildGallery(idx, plr)
	local g = galleries[idx]
	if g then g:Destroy() end
	g = Instance.new("Model")
	g.Name = "Gallery" .. idx
	g.Parent = museum
	galleries[idx] = g
	local x = MUSEUM.X + GALLERY_X[idx]
	local d = plr and data[plr]
	local color = C.plots[idx] and C.plots[idx].color or WHITE
	P(g, V3(20, 0.1, 44), CF(x, 1.06, MUSEUM.Z - 8), color:Lerp(WHITE, 0.6), MAT.SmoothPlastic)
	local banner = P(g, V3(16, 4, 0.3), CF(x, 17, MUSEUM.Z - 31.8), color, MAT.Fabric)
	surfaceText(banner, Enum.NormalId.Back, d and (plr.Name .. "'s Legacy") or "Gallery closed", WHITE)
	if not d then return end
	local list = exhibitsFor(d)
	for i = 1, 12 do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local pos = V3(x - 6 + col * 6, 1, MUSEUM.Z - 26 + row * 11)
		local e = list[i]
		local top = pedestal(g, pos, e and (e.color or color) or RGB(120, 120, 130))
		local mdl = Instance.new("Model")
		mdl.Parent = g
		if e then
			local shape = SHAPES[e.shape] or SHAPES.orb
			shape(mdl, top, e.color)
			local tag = ghost(mdl, CF(top + V3(0, 3.6, 0)))
			billboard(tag, UDim2.fromOffset(150, 40), V3(0, 0.6, 0), {{text = e.icon, h = 0.5}, {text = e.title, h = 0.5, font = Enum.Font.GothamBold, color = RGB(255, 225, 150)}}, 32)
		else
			local tag = ghost(mdl, CF(top + V3(0, 1.4, 0)))
			billboard(tag, UDim2.fromOffset(40, 36), V3(0, 0, 0), {{text = "?", color = RGB(170, 170, 180)}}, 26)
		end
	end
end
local pending = {}
function F.refreshMuseum(plr)
	local d = data[plr]
	if not d or pending[plr] then return end
	pending[plr] = true
	task.delay(1, function()
		pending[plr] = nil
		local dd = data[plr]
		if dd then buildGallery(dd.plot.index, plr) end
	end)
end
function F.closeGallery(plot) buildGallery(plot.index, nil) end
for i = 1, 4 do buildGallery(i, nil) end
C.DESTS_MUSEUM = {name = "Legacy Museum", icon = "🏛️", pos = MUSEUM + V3(0, 0.2, 52)}

-- =====================================================================
-- MYSTERY LOTS
-- =====================================================================
local MYST = C.MYSTERY
local SITES = {V3(-230, 0, 95), V3(0, 0, -250), V3(-420, 0, -200), V3(430, 0, -345)}
for _, p in ipairs(SITES) do C.reserve(p.X - 13, p.Z - 13, p.X + 13, p.Z + 13) end
local lot = {active = nil, nextAt = os.clock() + MYST.first}
C.MYSTERY_STATE = lot
function F.mysteryPerk(d, kind)
	local m = 1
	if not d.mystery then return 1 end
	for _, f in ipairs(C.MYSTERY_FINDS) do
		local n = math.min(d.mystery[f.key] or 0, 5)
		if n > 0 and f.perk and f.perk[kind] then m *= f.perk[kind] ^ n end
	end
	return m
end
function F.mysteryPrice(d) return math.max(MYST.minPrice, math.floor(F.incomePerSec(d) * MYST.priceSeconds)) end
local function rollFind()
	local total = 0
	for _, f in ipairs(C.MYSTERY_FINDS) do total += f.weight end
	local r = math.random() * total
	for _, f in ipairs(C.MYSTERY_FINDS) do
		r -= f.weight
		if r <= 0 then return f end
	end
	return C.MYSTERY_FINDS[1]
end
local function clearLot()
	if lot.active then
		lot.active.folder:Destroy()
		lot.active = nil
	end
end
local function reveal(site, f)
	local fold = Instance.new("Model")
	fold.Name = "MysteryReveal"
	fold.Parent = C.WORLD
	local color = RARITY_COLOR[f.rarity] or GOLD
	P(fold, V3(22, 0.6, 22), CF(site + V3(0, 0.3, 0)), RGB(120, 120, 125), MAT.Concrete, SOLID)
	local b = P(fold, V3(14, 10, 12), CF(site + V3(0, 5.6, 0)), color:Lerp(WHITE, 0.4), MAT.SmoothPlastic, SOLID)
	P(fold, V3(14.6, 0.6, 12.6), CF(site + V3(0, 10.9, 0)), color, MAT.Neon)
	billboard(b, UDim2.fromOffset(260, 70), V3(0, 9, 0), {{text = f.icon .. " " .. f.name, h = 0.55}, {text = f.rarity .. "!", h = 0.45, color = color, font = Enum.Font.GothamBold}}, 300)
	sparkle(b, color, 20)
	C.popIn(fold)
	burst(site + V3(0, 12, 0), color, f.rarity == "LEGENDARY" and 300 or 150)
	C.shockwave(site + V3(0, 1, 0), color, 40)
	task.delay(40, function() if fold.Parent then fold:Destroy() end end)
end
local function buyLot(plr)
	local d = data[plr]
	local cur = lot.active
	if not (d and cur) or cur.sold then return end
	if F.tierIndex(d.rep) < MYST.tier then
		notify(plr, "🔒 Mystery Lots need " .. C.REP_TIERS[MYST.tier].name .. " reputation.")
		return
	end
	local price = F.mysteryPrice(d)
	if d.cash < price then
		notify(plr, "❓ This lot costs you $" .. fmt(price) .. " (the price scales with your empire).")
		return
	end
	cur.sold = true
	d.cash -= price
	local f = rollFind()
	d.mystery = d.mystery or {}
	d.mystery[f.key] = (d.mystery[f.key] or 0) + 1
	local extra = ""
	if f.cashSeconds then
		local cash = math.max(price * 2, math.floor(F.incomePerSec(d) * f.cashSeconds))
		d.cash += cash
		d.earned += cash
		extra = "  +$" .. fmt(cash)
	end
	if f.followers then d.followers += f.followers end
	if f.trophies then
		d.trophies += f.trophies
		F.refreshTower(plr, true)
	end
	local site = cur.site
	clearLot()
	reveal(site, f)
	R.Splash:FireClient(plr, "❓ MYSTERY LOT: " .. f.icon .. " " .. string.upper(f.name), f.rarity .. " find! " .. f.perkText .. extra, RARITY_COLOR[f.rarity] or GOLD)
	C.announceAll("❓ " .. plr.Name .. " opened a Mystery Lot and found a " .. string.upper(f.rarity) .. " " .. f.icon .. " " .. f.name .. "!")
	F.buzz(f.icon, plr.Name .. " bought a Mystery Lot... it was a " .. f.rarity .. " " .. f.name .. "!", RARITY_COLOR[f.rarity] or GOLD)
	if F.achieve then
		F.achieve(plr, "mystery")
		if f.rarity == "LEGENDARY" then F.achieve(plr, "legendary") end
	end
	F.refreshMuseum(plr)
	lot.nextAt = os.clock() + math.random(MYST.gapMin, MYST.gapMax)
end
function F.spawnMysteryLot(siteIndex)
	clearLot()
	local site = SITES[siteIndex or math.random(#SITES)]
	local fold = Instance.new("Model")
	fold.Name = "MysteryLot"
	fold.Parent = C.WORLD
	P(fold, V3(22, 0.6, 22), CF(site + V3(0, 0.3, 0)), RGB(110, 85, 60), MAT.Ground, SOLID)
	for _, sx in ipairs({-10.8, 10.8}) do P(fold, V3(0.4, 2, 22), CF(site + V3(sx, 1.3, 0)), RGB(90, 60, 140), MAT.Metal) end
	for _, sz in ipairs({-10.8, 10.8}) do P(fold, V3(22, 2, 0.4), CF(site + V3(0, 1.3, sz)), RGB(90, 60, 140), MAT.Metal) end
	for k = 1, 3 do P(fold, V3(3, 3, 3), CF(site + V3(-6 + k * 3.5, 2.1, 4 - k)), RGB(150, 110, 70), MAT.WoodPlanks) end
	local q = P(fold, V3(1, 9, 6), CF(site + V3(0, 9, 0)), RGB(170, 90, 255), MAT.Neon)
	spin(q, 1.2)
	local beam = cyl(fold, 160, 3, CF(site + V3(0, 80, 0)), RGB(170, 90, 255), MAT.Neon, {Transparency = 0.7, CastShadow = false})
	beam.CastShadow = false
	local sign = P(fold, V3(6, 3, 0.4), CF(site + V3(0, 3.2, 10.6)), RGB(30, 20, 50))
	billboard(sign, UDim2.fromOffset(250, 80), V3(0, 4, 0), {{text = "❓ MYSTERY LOT", h = 0.4, color = RGB(200, 150, 255)}, {text = "Nobody knows what's inside...", h = 0.3},
		{text = "Price scales with your empire", h = 0.3, color = RGB(120, 255, 150), font = Enum.Font.GothamBold}}, 400)
	C.prompt(sign, "Buy the Mystery Lot ❓", "Mystery Lot", 16, 1, buyLot)
	lot.active = {folder = fold, site = site, expires = os.clock() + MYST.life}
	C.announceAll("❓ A MYSTERY LOT just appeared somewhere in the city! Check your Map → Mystery Lot. First to buy it finds out what's inside.")
	F.buzz("❓", "A Mystery Lot appeared! Rumors say it could be anything... even something legendary.", RGB(170, 90, 255))
	return lot.active
end
C.mysterySite = function() return lot.active and lot.active.site or nil end
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.clock()
		if lot.active and now > lot.active.expires then
			clearLot()
			C.announceAll("❓ The Mystery Lot vanished... maybe next time!")
			lot.nextAt = now + math.random(MYST.gapMin, MYST.gapMax)
		elseif not lot.active and now >= lot.nextAt then
			if next(data) ~= nil then F.spawnMysteryLot() else lot.nextAt = now + 60 end
		end
	end
end)
end
