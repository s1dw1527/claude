-- HOUSING: buy a home lot in one of 5 neighborhoods and build it up (5 levels).
return function(C)
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, wedge, ball, cyl, xcyl, ghost, billboard, surfaceText, smoke, sparkle, burst, shockwave, popIn =
	C.P, C.wedge, C.ball, C.cyl, C.xcyl, C.ghost, C.billboard, C.surfaceText, C.smoke, C.sparkle, C.burst, C.shockwave, C.popIn
local HOODS, HOOD, HOME_LEVELS, REP_TIERS, fmt, notify = C.HOODS, C.HOOD, C.HOME_LEVELS, C.REP_TIERS, C.fmt, C.notify
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 250), RGB(35, 35, 40)

local FOLDER = Instance.new("Folder")
FOLDER.Name = "Homes"
FOLDER.Parent = C.WORLD

-- lot positions (yaw 0 = house faces +Z)
C.HOME_LOTS = {}
local function addLots(hood, size, y, list)
	for _, e in ipairs(list) do
		table.insert(C.HOME_LOTS, {id = #C.HOME_LOTS + 1, hood = hood, pos = V3(e[1], y, e[2]), yaw = e[3], size = size})
		C.reserve(e[1] - size / 2, e[2] - size / 2, e[1] + size / 2, e[2] + size / 2)
	end
end
addLots("oldtown", 30, 0, {{-385, 180, 0}, {-455, 180, 0}, {-525, 180, 0}, {-385, 270, math.pi}, {-455, 270, math.pi}})
addLots("suburbs", 34, 0, {{-175, 180, 0}, {-230, 180, 0}, {-285, 180, 0}, {-175, 270, math.pi}, {-285, 270, math.pi}})
addLots("ocean", 34, 0, {{200, 372, math.pi}, {270, 372, math.pi}, {340, 372, math.pi}, {410, 372, math.pi}, {480, 372, math.pi}})
addLots("hills", 34, 18, {{-185, -175, math.pi}, {-235, -175, math.pi}, {-285, -175, math.pi}, {-185, -225, 0}, {-285, -225, 0}})
addLots("rich", 40, 0, {{385, -180, math.pi}, {455, -180, math.pi}, {525, -180, math.pi}, {385, -250, 0}, {455, -250, 0}})

-- neighborhood entrance signs + plateau paths
C.gate(FOLDER, V3(-420, 0, 225), true, "🏚️ OLD TOWN", "Homes from $" .. fmt(HOOD.oldtown.price), HOOD.oldtown.color)
C.gate(FOLDER, V3(-300, 0, 225), true, "🏡 MAPLE SUBURBS", "Homes from $" .. fmt(HOOD.suburbs.price), HOOD.suburbs.color)
C.gate(FOLDER, V3(560, 0, 335), true, "🌊 OCEANFRONT", "Needs " .. REP_TIERS[HOOD.ocean.tier].name, HOOD.ocean.color)
C.gate(FOLDER, V3(-230, 0, -296), false, "⛰️ HILLSIDE", "Needs " .. REP_TIERS[HOOD.hills.tier].name, HOOD.hills.color)
C.gate(FOLDER, V3(345, 0, -215), true, "💎 MILLIONAIRE ROW", "Needs " .. REP_TIERS[HOOD.rich.tier].name, HOOD.rich.color)
P(FOLDER, V3(150, 2.2, 8), CF(-235, 17.1, -200), RGB(52, 54, 60), MAT.Asphalt, SOLID)
P(FOLDER, V3(8, 2.2, 50), CF(-230, 17.1, -225), RGB(52, 54, 60), MAT.Asphalt, SOLID)
for _, x in ipairs({-305, -300}) do
	P(FOLDER, V3(0.8, 3, 110), CF(x == -305 and -311 or -149, 19.5, -200), RGB(90, 90, 95), MAT.Concrete, SOLID)
end

-- ===== house pieces =====
local function gable(m, cf, w, d, rh, col, mat)
	wedge(m, V3(w + 1.2, rh, d / 2 + 0.6), cf * CF(0, rh / 2, -d / 4 - 0.3), col, mat or MAT.Slate)
	wedge(m, V3(w + 1.2, rh, d / 2 + 0.6), cf * CF(0, rh / 2, d / 4 + 0.3) * CFrame.Angles(0, math.pi, 0), col, mat or MAT.Slate)
end
local function hwindow(m, cf, w, h, lit)
	P(m, V3(w + 0.4, h + 0.4, 0.2), cf, WHITE)
	P(m, V3(w, h, 0.15), cf * CF(0, 0, 0.06), lit and RGB(255, 226, 160) or RGB(120, 160, 200), lit and MAT.Neon or MAT.Glass, {Transparency = lit and 0.4 or 0.15})
	P(m, V3(w + 0.6, 0.25, 0.5), cf * CF(0, -h / 2 - 0.2, 0.2), WHITE)
end
local function bush(m, cf, s)
	ball(m, V3(2.4, 1.8, 2.4) * s, cf * CF(0, 0.9 * s, 0), RGB(60, 140, 60), MAT.Grass)
	ball(m, V3(0.5, 0.5, 0.5) * s, cf * CF(0.5 * s, 1.6 * s, 0.4 * s), Color3.fromHSV(math.random(), 0.6, 1))
end
local function pool(m, cf, w, d)
	P(m, V3(w + 1.6, 0.5, d + 1.6), cf * CF(0, 0.25, 0), RGB(230, 230, 225), MAT.Concrete, SOLID)
	P(m, V3(w, 0.2, d), cf * CF(0, 0.52, 0), RGB(60, 180, 255), MAT.Glass, {Transparency = 0.2, Reflectance = 0.3})
	for _, sx in ipairs({-1, 1}) do
		P(m, V3(1.6, 0.3, 3.6), cf * CF(sx * (w / 2 + 2.4), 0.9, 0), WHITE, MAT.Fabric)
	end
end
local function fence(m, cf, size)
	for _, side in ipairs({-1, 1}) do
		P(m, V3(0.3, 1.8, size - 2), cf * CF(side * (size / 2 - 0.5), 0.9, 0), WHITE, MAT.WoodPlanks)
	end
	P(m, V3(size - 1, 1.8, 0.3), cf * CF(0, 0.9, -size / 2 + 0.5), WHITE, MAT.WoodPlanks)
end

local STYLE = {
	cottage  = {w = 11, d = 9,  wall = RGB(190, 150, 110), mat = MAT.WoodPlanks, roof = RGB(120, 70, 50),  kind = "gable", chimney = true},
	bungalow = {w = 15, d = 11, wall = RGB(170, 205, 230), mat = MAT.WoodPlanks, roof = RGB(90, 90, 100),  kind = "gable", garage = true},
	beach    = {w = 14, d = 11, wall = RGB(120, 200, 220), mat = MAT.WoodPlanks, roof = WHITE,             kind = "gable", stilts = true},
	modern   = {w = 17, d = 13, wall = RGB(240, 240, 238), mat = MAT.SmoothPlastic, roof = DARK,         kind = "flat", glass = true},
	mansion  = {w = 24, d = 16, wall = RGB(236, 226, 205), mat = MAT.Limestone, roof = RGB(60, 60, 70),   kind = "gable", columns = true, garage = true},
}

local function buildHouse(m, o, hood, lvl, ownerName, accent)
	local S = STYLE[hood.style]
	local w = S.w * (1 + (lvl - 1) * 0.07)
	local d = S.d * (1 + (lvl - 1) * 0.05)
	local floors = lvl >= 3 and 2 or 1
	local fh = hood.style == "mansion" and 8 or 7
	local y0 = 0.4
	if S.stilts then
		y0 = 3.4
		for _, sx in ipairs({-1, 1}) do
			for _, sz in ipairs({-1, 0, 1}) do P(m, V3(0.8, 3.2, 0.8), o * CF(sx * (w / 2 - 0.6), 1.9, sz * (d / 2 - 0.6)), RGB(150, 110, 70), MAT.Wood, SOLID) end
		end
		P(m, V3(w + 5, 0.4, d + 5), o * CF(0, y0 - 0.2, 1.5), RGB(170, 125, 80), MAT.WoodPlanks, SOLID)
		for k = 0, 4 do P(m, V3(3, 0.4, 1), o * CF(0, 0.6 + k * 0.7, d / 2 + 4 + (4 - k) * 0.9), RGB(170, 125, 80), MAT.WoodPlanks, SOLID) end
	end
	local h = floors * fh
	P(m, V3(w, h, d), o * CF(0, y0 + h / 2, 0), S.wall, S.mat, SOLID)
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do P(m, V3(0.5, h, 0.5), o * CF(sx * w / 2, y0 + h / 2, sz * d / 2), WHITE) end
	end
	if floors == 2 then P(m, V3(w + 0.3, 0.4, d + 0.3), o * CF(0, y0 + fh, 0), WHITE) end
	-- front door + windows
	P(m, V3(2.6, 4.6, 0.25), o * CF(0, y0 + 2.3, d / 2 + 0.05), WHITE)
	P(m, V3(2.1, 4.2, 0.2), o * CF(0, y0 + 2.2, d / 2 + 0.12), accent, MAT.SmoothPlastic)
	ball(m, V3(0.3, 0.3, 0.3), o * CF(0.7, y0 + 2.2, d / 2 + 0.25), RGB(230, 190, 60), MAT.Metal)
	local lit = math.random() < 0.7
	for f = 0, floors - 1 do
		local y = y0 + f * fh + fh * 0.55
		for _, sx in ipairs(f == 0 and {-w * 0.3, w * 0.3} or {-w * 0.3, 0, w * 0.3}) do
			if S.glass then
				P(m, V3(w * 0.26, fh * 0.7, 0.15), o * CF(sx, y, d / 2 + 0.06), RGB(120, 170, 210), MAT.Glass, {Transparency = 0.2, Reflectance = 0.3})
			else
				hwindow(m, o * CF(sx, y, d / 2 + 0.05), 2.4, 2.4, lit)
			end
		end
		for _, sx in ipairs({-1, 1}) do
			hwindow(m, o * CF(sx * (w / 2 + 0.05), y, 0) * CFrame.Angles(0, sx * math.pi / 2, 0), 2.4, 2.4, lit)
		end
	end
	local top = y0 + h
	if S.kind == "gable" then
		local rh = math.min(5, d * 0.4)
		gable(m, o * CF(0, top, 0), w, d, rh, S.roof)
		if S.chimney then
			P(m, V3(1.4, 4, 1.4), o * CF(w * 0.3, top + 2.4, -d * 0.2), RGB(150, 70, 50), MAT.Brick)
			smoke(ghost(m, o * CF(w * 0.3, top + 4.6, -d * 0.2)), false, 3)
		end
		top += rh
	else
		P(m, V3(w + 2, 0.6, d + 2), o * CF(0, top + 0.3, 0), S.roof, MAT.SmoothPlastic)
		top += 0.6
	end
	if S.columns then
		for _, sx in ipairs({-2.8, 2.8}) do cyl(m, h, 1.1, o * CF(sx, y0 + h / 2, d / 2 + 2.6), WHITE, MAT.Marble) end
		P(m, V3(8, 0.8, 4.4), o * CF(0, y0 + h + 0.4, d / 2 + 2), WHITE, MAT.Marble)
		P(m, V3(8, 0.3, 4), o * CF(0, 0.55, d / 2 + 2), RGB(220, 220, 220), MAT.Marble)
	end
	-- level 2+: porch / garage
	if lvl >= 2 then
		if S.garage then
			local gx = w / 2 + 4.2
			P(m, V3(8, 6, d * 0.8), o * CF(gx, y0 + 3, -d * 0.1), S.wall, S.mat, SOLID)
			P(m, V3(6.4, 4.6, 0.2), o * CF(gx, y0 + 2.4, d * 0.3 + 0.05), RGB(230, 230, 230), MAT.DiamondPlate)
			P(m, V3(8.8, 0.5, d * 0.8 + 0.6), o * CF(gx, y0 + 6.25, -d * 0.1), S.roof)
		elseif not S.stilts then
			P(m, V3(w * 0.7, 0.4, 3.2), o * CF(0, y0 + 4.9, d / 2 + 1.6), S.roof)
			for _, sx in ipairs({-w * 0.33, w * 0.33}) do P(m, V3(0.4, 4.6, 0.4), o * CF(sx, y0 + 2.5, d / 2 + 3), WHITE) end
			P(m, V3(w * 0.7, 0.3, 3.2), o * CF(0, 0.55, d / 2 + 1.6), RGB(170, 125, 80), MAT.WoodPlanks)
		end
	end
	-- level 4+: pool + garden
	if lvl >= 4 then
		pool(m, o * CF(-w * 0.1, 0, -d / 2 - 5.5), math.min(11, w * 0.6), 5)
		for _, sx in ipairs({-1, 1}) do bush(m, o * CF(sx * (w / 2 + 1.5), 0.3, d / 2 + 1), 1) end
	end
	-- level 5: dream home extras
	if lvl >= 5 then
		for k = 0, 9 do
			ball(m, V3(0.35, 0.35, 0.35), o * CF(-w / 2 + k * (w / 9), top - 0.3, d / 2 + 0.6), RGB(255, 220, 150), MAT.Neon)
		end
		if hood.style == "mansion" then
			cyl(m, 1.2, 7, o * CF(0, 0.9, d / 2 + 9), RGB(220, 220, 225), MAT.Marble, SOLID)
			cyl(m, 0.3, 6, o * CF(0, 1.4, d / 2 + 9), RGB(80, 180, 255), MAT.Glass, {Transparency = 0.2})
			cyl(m, 3, 1.2, o * CF(0, 2.5, d / 2 + 9), RGB(220, 220, 225), MAT.Marble)
			sparkle(ghost(m, o * CF(0, 4.2, d / 2 + 9)), RGB(170, 220, 255), 20)
			cyl(m, 0.3, 10, o * CF(-w / 2 - 7, 0.5, -d / 2), RGB(60, 60, 66), MAT.Concrete, SOLID)
			local hp = P(m, V3(6, 0.1, 6), o * CF(-w / 2 - 7, 0.7, -d / 2), WHITE)
			surfaceText(hp, Enum.NormalId.Top, "H", RGB(255, 200, 60))
		elseif hood.style == "modern" then
			for k = 0, 2 do P(m, V3(w * 0.28, 0.2, 2.2), o * CF(-w * 0.3 + k * w * 0.3, top + 0.8, 0) * CFrame.Angles(math.rad(-20), 0, 0), RGB(30, 50, 110), MAT.Glass, {Reflectance = 0.3}) end
		else
			cyl(m, 1.2, 4, o * CF(w / 2 + 3, y0 + 0.6, d / 2 + 4), RGB(150, 110, 70), MAT.WoodPlanks)
			cyl(m, 0.2, 3.4, o * CF(w / 2 + 3, y0 + 1.25, d / 2 + 4), RGB(80, 200, 255), MAT.Glass, {Transparency = 0.2})
		end
	end
	-- mailbox with the owner's name
	local mb = P(m, V3(1, 1, 1.6), o * CF(w / 2 - 1, 3.4, d / 2 + 6), accent, MAT.Metal)
	P(m, V3(0.3, 3, 0.3), o * CF(w / 2 - 1, 1.5, d / 2 + 6), DARK, MAT.Metal)
	return top, mb
end

function F.buildHome(lot)
	if lot.folder then lot.folder:Destroy() end
	local hood = HOOD[lot.hood]
	local f = Instance.new("Model")
	f.Name = "HomeLot" .. lot.id
	f.Parent = FOLDER
	lot.folder = f
	local o = CF(lot.pos) * CFrame.Angles(0, lot.yaw, 0)
	local owner = lot.owner and data[lot.owner]
	local level = owner and owner.home and owner.home.level or 0
	f.PrimaryPart = P(f, V3(lot.size, 2.4, lot.size), o * CF(0, -0.8, 0), owner and RGB(100, 175, 95) or RGB(130, 110, 85), owner and MAT.Grass or MAT.Ground, SOLID)
	P(f, V3(4, 0.45, lot.size / 2), o * CF(0, 0.25, lot.size / 4), RGB(190, 190, 195), MAT.Concrete)
	if not owner then
		P(f, V3(0.4, 5, 0.4), o * CF(0, 2.5, lot.size / 2 - 3), RGB(110, 80, 50), MAT.Wood)
		local sign = P(f, V3(6, 3.4, 0.3), o * CF(0, 5.4, lot.size / 2 - 3), WHITE, MAT.SmoothPlastic)
		billboard(sign, UDim2.fromOffset(200, 80), V3(0, 3.8, 0), {
			{text = hood.icon .. " HOME FOR SALE", h = 0.38, color = RGB(255, 120, 90)}, {text = "$" .. fmt(hood.price), h = 0.34, color = RGB(120, 255, 150)},
			{text = "Needs " .. REP_TIERS[hood.tier].name, h = 0.28, font = Enum.Font.GothamBold}}, 90)
		C.prompt(sign, "Buy Home ($" .. fmt(hood.price) .. ")", hood.name, 14, 0.5, function(plr) F.buyHome(plr, lot) end)
		return
	end
	local accent = F.accentFor(lot.owner)
	local mbPos
	if level <= 0 then
		for _, sx in ipairs({-7, 7}) do
			for _, sz in ipairs({-5, 5}) do P(f, V3(0.3, 1.6, 0.3), o * CF(sx, 1, sz), RGB(240, 150, 40), MAT.Wood) end
		end
		P(f, V3(14, 0.3, 10), o * CF(0, 0.5, 0), RGB(170, 170, 170), MAT.Concrete)
		mbPos = P(f, V3(1, 1, 1.6), o * CF(5, 3.4, lot.size / 2 - 4), accent, MAT.Metal)
		P(f, V3(0.3, 3, 0.3), o * CF(5, 1.5, lot.size / 2 - 4), DARK, MAT.Metal)
	else
		local top
		top, mbPos = buildHouse(f, o, hood, level, lot.owner.Name, accent)
	end
	billboard(mbPos, UDim2.fromOffset(220, 52), V3(0, 4, 0), {
		{text = "🏠 " .. lot.owner.Name, h = 0.55}, {text = level > 0 and (HOME_LEVELS[level] .. " • " .. hood.name) or "Empty lot — build it!", h = 0.45, color = hood.color, font = Enum.Font.GothamBold}}, 120)
	C.prompt(mbPos, "Home Menu", hood.name, 12, 0.2, function(plr)
		if plr == lot.owner then R.Menu:FireClient(plr, "open", "home") end
	end)
end

function F.homeLot(d)
	return d.home and d.home.lot and C.HOME_LOTS[d.home.lot] or nil
end
function F.homeHood(d)
	local lot = F.homeLot(d)
	return lot and lot.hood or nil
end
function F.homeMult(d)
	local lot = F.homeLot(d)
	if not lot or d.home.level <= 0 then return 1 end
	local hood = HOOD[lot.hood]
	return 1 + d.home.level * hood.mult * 0.02 + (lot.hood == "rich" and 0.15 or 0)
end
function F.homeBuildCost(d)
	local lot = F.homeLot(d)
	if not lot or d.home.level >= #HOME_LEVELS then return nil end
	return math.floor(HOOD[lot.hood].build * 2.2 ^ d.home.level)
end
function F.homeSpawn(d)
	local lot = F.homeLot(d)
	if not lot then return nil end
	return CF(lot.pos) * CFrame.Angles(0, lot.yaw, 0) * CF(0, 4, lot.size / 2 - 2) * CFrame.Angles(0, math.pi, 0)
end

function F.releaseHome(plr)
	for _, lot in ipairs(C.HOME_LOTS) do
		if lot.owner == plr then
			lot.owner = nil
			F.buildHome(lot)
		end
	end
end
function F.claimHome(plr, d, hoodKey, preferId)
	local chosen = preferId and C.HOME_LOTS[preferId]
	if chosen and chosen.owner then chosen = nil end
	if not chosen then
		for _, lot in ipairs(C.HOME_LOTS) do
			if lot.hood == hoodKey and not lot.owner then
				chosen = lot
				break
			end
		end
	end
	if not chosen then return false end
	chosen.owner = plr
	d.home.lot = chosen.id
	F.buildHome(chosen)
	return true
end

function F.buyHome(plr, lot)
	local d = data[plr]
	if not d then return end
	if lot.owner then return end
	local hood = HOOD[lot.hood]
	if F.tierIndex(d.rep) < hood.tier then
		notify(plr, "🔒 " .. hood.name .. " needs reputation: " .. REP_TIERS[hood.tier].name)
		return
	end
	if d.cash < hood.price then
		notify(plr, "You need $" .. fmt(hood.price) .. " for a home in " .. hood.name .. ".")
		return
	end
	d.cash -= hood.price
	F.releaseHome(plr)
	lot.owner = plr
	d.home = {lot = lot.id, level = 0}
	F.buildHome(lot)
	burst(lot.pos + V3(0, 8, 0), hood.color, 100)
	notify(plr, "🏠 You bought land in " .. hood.name .. "! Open Phone → Home to build your house.")
	F.buzz(hood.icon, plr.Name .. " just moved to " .. hood.name .. "!", hood.color)
	F.pushMsg(plr, {icon = "🏠", from = "Realtor", text = "Congrats on your new lot in " .. hood.name .. "! Build your house from the Home app."})
end

function F.buildHomeLevel(plr)
	local d = data[plr]
	local lot = d and F.homeLot(d)
	if not lot then return end
	local cost = F.homeBuildCost(d)
	if not cost then return end
	if d.cash < cost then
		notify(plr, "You need $" .. fmt(cost) .. " to build.")
		return
	end
	d.cash -= cost
	d.home.level += 1
	F.buildHome(lot)
	if lot.folder then popIn(lot.folder) end
	burst(lot.pos + V3(0, 10, 0), HOOD[lot.hood].color, 120)
	shockwave(lot.pos + V3(0, 0.6, 0), HOOD[lot.hood].color, 30)
	C.R.Splash:FireClient(plr, "🏠 " .. HOME_LEVELS[d.home.level] .. "!", "Your home in " .. HOOD[lot.hood].name .. " got an upgrade. Home income bonus: +" .. math.floor((F.homeMult(d) - 1) * 100 + 0.5) .. "%", HOOD[lot.hood].color)
end
end
