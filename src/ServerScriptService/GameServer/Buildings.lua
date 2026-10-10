-- BUILDINGS: every business has its own themed architecture across 6 stages.
return function(C)
local TweenService = game:GetService("TweenService")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, wedge, ball, cyl, xcyl, ghost, billboard, surfaceText, smoke, sparkle, burst, shockwave, popIn, spin, tag =
	C.P, C.wedge, C.ball, C.cyl, C.xcyl, C.ghost, C.billboard, C.surfaceText, C.smoke, C.sparkle, C.burst, C.shockwave, C.popIn, C.spin, C.tag
local BIZ, BUSINESSES, COMBOS, SKINS, CFG = C.BIZ, C.BUSINESSES, C.COMBOS, C.SKINS, C.CFG
local SOLID = {CanCollide = true}
local DARK, WHITE, GOLD = RGB(32, 32, 38), RGB(250, 250, 250), RGB(255, 205, 60)
local LIT = RGB(255, 226, 160)

function C.stageOf(level, chains)
	if level <= 0 then return 0 end
	if level <= 2 then return 1 end
	if level <= 4 then return 2 end
	if level <= 7 then return 3 end
	if level <= 9 then return 4 end
	if chains >= #C.CHAINS then return 6 end
	return 5
end
local stageOf = C.stageOf

-- ===== small reusable details =====
local function awning(m, base, w, y, z, a, b, style)
	local n = math.max(4, math.floor(w / 1.2))
	for k = 1, n do
		local x = -w / 2 + (k - 0.5) * (w / n)
		local col = (style ~= "solid" and k % 2 == 0) and b or a
		P(m, V3(w / n, 0.2, 2.4), base * CF(x, y, z + 1.1) * CFrame.Angles(math.rad(-18), 0, 0), col, MAT.Fabric)
		if style == "scallop" then
			xcyl(m, 0.2, w / n, base * CF(x, y - 0.55, z + 2.25) * CFrame.Angles(0, math.rad(90), 0), col, MAT.Fabric)
		end
	end
	P(m, V3(w, 0.25, 0.25), base * CF(0, y - 0.35, z + 2.3), DARK, MAT.Metal)
end
local function umbrellaTable(m, base, x, z, col)
	cyl(m, 2.4, 0.25, base * CF(x, 1.5, z), DARK, MAT.Metal)
	cyl(m, 0.15, 2.4, base * CF(x, 2.2, z), WHITE, MAT.SmoothPlastic)
	cyl(m, 4.4, 0.18, base * CF(x, 3.3, z), RGB(200, 200, 200), MAT.Metal)
	cyl(m, 0.35, 4.6, base * CF(x, 5.4, z), col, MAT.Fabric)
	cyl(m, 0.4, 1.4, base * CF(x, 5.75, z), col, MAT.Fabric)
	for _, sx in ipairs({-1.5, 1.5}) do P(m, V3(1, 1, 1), base * CF(x + sx, 1.3, z), DARK, MAT.Metal) end
end
local function flowerBox(m, base, x, y, z, w)
	P(m, V3(w, 0.6, 0.8), base * CF(x, y, z), RGB(120, 80, 50), MAT.WoodPlanks)
	for k = 1, math.floor(w / 0.7) do
		ball(m, V3(0.6, 0.6, 0.6), base * CF(x - w / 2 + k * 0.7 - 0.35, y + 0.45, z), Color3.fromHSV(math.random(), 0.7, 1))
	end
end
local function chalkboard(m, base, x, z, text)
	local b = P(m, V3(1.8, 2.4, 0.2), base * CF(x, 1.8, z) * CFrame.Angles(math.rad(-10), 0, 0), RGB(40, 44, 40), MAT.Slate)
	surfaceText(b, Enum.NormalId.Back, text, RGB(240, 240, 230), nil, Enum.Font.Cartoon)
end
local function stringLights(m, base, w, y, z)
	for _, sx in ipairs({-w / 2 - 0.5, w / 2 + 0.5}) do P(m, V3(0.25, y, 0.25), base * CF(sx, y / 2 + 0.3, z), DARK, MAT.Metal) end
	for k = 0, 10 do
		local t = k / 10
		local sag = math.sin(t * math.pi) * 0.9
		ball(m, V3(0.35, 0.35, 0.35), base * CF(-w / 2 - 0.5 + t * (w + 1), y - sag, z), RGB(255, 220, 150), MAT.Neon)
	end
end
local function window(m, base, x, y, z, w, h, side)
	local lit = math.random() < 0.6
	local size = side and V3(0.15, h, w) or V3(w, h, 0.15)
	P(m, side and V3(0.2, h + 0.4, w + 0.4) or V3(w + 0.4, h + 0.4, 0.2), base * CF(x, y, z), WHITE, MAT.SmoothPlastic)
	P(m, size, base * CF(x + (side and (x > 0 and 0.06 or -0.06) or 0), y, z + (side and 0 or 0.06)), lit and LIT or RGB(90, 130, 170), lit and MAT.Neon or MAT.Glass, {Transparency = lit and 0.35 or 0.1})
end

-- ===== signature rooftop props =====
local PROPS = {}
PROPS.lemonade = function(m, o, s)
	ball(m, V3(2.4, 2.4, 2.9) * s, o * CF(0, 1.2 * s, 0), RGB(255, 226, 60))
	ball(m, V3(0.8, 0.5, 0.5) * s, o * CF(0, 1.2 * s, 1.45 * s), RGB(240, 200, 40))
	P(m, V3(0.9, 0.15, 0.5) * s, o * CF(0.35 * s, 2.45 * s, 0) * CFrame.Angles(0, 0, math.rad(20)), RGB(70, 170, 70))
	return 2.5 * s
end
PROPS.icecream = function(m, o, s)
	for k = 0, 3 do cyl(m, 0.7 * s, (0.5 + k * 0.4) * s, o * CF(0, (0.35 + k * 0.7) * s, 0), RGB(220, 170, 100), MAT.WoodPlanks) end
	ball(m, V3(2, 1.8, 2) * s, o * CF(0, 3.3 * s, 0), RGB(255, 160, 200))
	ball(m, V3(1.7, 1.5, 1.7) * s, o * CF(0, 4.4 * s, 0), RGB(255, 250, 240))
	ball(m, V3(1.4, 1.2, 1.4) * s, o * CF(0, 5.3 * s, 0), RGB(140, 90, 60))
	ball(m, V3(0.5, 0.5, 0.5) * s, o * CF(0, 6 * s, 0), RGB(220, 30, 50))
	return 6.3 * s
end
PROPS.bakery = function(m, o, s)
	ball(m, V3(3.2, 1.6, 1.9) * s, o * CF(0, 0.8 * s, 0), RGB(226, 168, 88))
	ball(m, V3(1.4, 1.1, 1.2) * s, o * CF(-1.6 * s, 0.55 * s, 0.4 * s), RGB(210, 150, 70))
	ball(m, V3(1.4, 1.1, 1.2) * s, o * CF(1.6 * s, 0.55 * s, 0.4 * s), RGB(210, 150, 70))
	return 1.7 * s
end
PROPS.coffee = function(m, o, s)
	local ch, cd = 2.6 * s, 2.8 * s
	cyl(m, ch, cd, o * CF(0, ch / 2, 0), WHITE)
	cyl(m, 0.12, cd * 0.86, o * CF(0, ch - 0.04, 0), RGB(70, 40, 25))
	cyl(m, 0.3, cd * 1.3, o * CF(0, 0.15, 0), WHITE)
	P(m, V3(0.35, ch * 0.5, 0.35), o * CF(cd / 2 + 0.6 * s, ch / 2, 0), WHITE)
	smoke(ghost(m, o * CF(0, ch + 0.3, 0)), false, 4)
	return ch + 1.5
end
PROPS.pizza = function(m, o, s)
	local w = wedge(m, V3(0.5 * s, 3.2 * s, 3 * s), o * CF(0, 1.8 * s, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(180), 0, 0), RGB(245, 190, 80))
	w.Material = MAT.SmoothPlastic
	for k = 1, 3 do cyl(m, 0.1, 0.6 * s, o * CF(0.27 * s, (0.9 + k * 0.6) * s, (k - 2) * 0.35 * s) * CFrame.Angles(0, 0, math.rad(90)), RGB(200, 40, 40)) end
	P(m, V3(0.6 * s, 0.4 * s, 3.1 * s), o * CF(0, 3.45 * s, 0), RGB(200, 140, 60))
	return 3.8 * s
end
PROPS.arcade = function(m, o, s)
	P(m, V3(3, 0.8, 2.2) * s, o * CF(0, 0.4 * s, 0), RGB(40, 40, 50))
	cyl(m, 2 * s, 0.4 * s, o * CF(0, 1.8 * s, 0), RGB(200, 200, 210), MAT.Metal)
	ball(m, V3(1.1, 1.1, 1.1) * s, o * CF(0, 2.9 * s, 0), RGB(255, 40, 60), MAT.Neon)
	for k, col in ipairs({RGB(60, 200, 255), RGB(255, 220, 60)}) do
		cyl(m, 0.25 * s, 0.6 * s, o * CF((0.4 + k * 0.5) * s, 0.9 * s, 0.4 * s), col, MAT.Neon)
	end
	return 3.4 * s
end
PROPS.tech = function(m, o, s)
	P(m, V3(0.3, 4 * s, 0.3), o * CF(0, 2 * s, 0), RGB(170, 175, 185), MAT.Metal)
	local b = ball(m, V3(0.8, 0.8, 0.8) * s, o * CF(0, 4.2 * s, 0), RGB(255, 60, 60), MAT.Neon)
	TweenService:Create(b, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.85}):Play()
	return 4.6 * s
end
PROPS.factory = function(m, o, s)
	return 0.5
end
PROPS.theater = function(m, o, s)
	-- a giant popcorn bucket on the roof
	cyl(m, 3 * s, 2.2 * s, o * CF(0, 1.5 * s, 0), WHITE)
	for k = 0, 5 do P(m, V3(0.36 * s, 3 * s, 0.1), o * CF(math.cos(k * math.pi / 3) * 1.1 * s, 1.5 * s, math.sin(k * math.pi / 3) * 1.1 * s) * CFrame.Angles(0, -k * math.pi / 3 + math.pi / 2, 0), RGB(220, 40, 60)) end
	for k = 0, 6 do ball(m, V3(0.9, 0.8, 0.9) * s, o * CF(math.cos(k) * 0.6 * s, (3.2 + (k % 3) * 0.25) * s, math.sin(k) * 0.6 * s), RGB(255, 236, 170)) end
	return 3.8 * s
end
-- the theater's lit marquee with the film that's showing (GameServer > Theater changes the title)
local function marquee(m, o, w, y, z, title)
	local box = P(m, V3(w, 2.2, 0.6), o * CF(0, y, z), RGB(30, 20, 26), MAT.SmoothPlastic)
	box.Name = "Marquee"
	surfaceText(box, Enum.NormalId.Back, "NOW SHOWING\n" .. string.upper(title or "COMING SOON"), RGB(255, 236, 160))
	local bulbs = Instance.new("Model")
	bulbs.Name = "MarqueeBulbs"
	bulbs.Parent = m
	local n = math.max(8, math.floor(w / 0.9))
	for k = 0, n - 1 do
		ball(bulbs, V3(0.32, 0.32, 0.32), o * CF(-w / 2 + (k + 0.5) * (w / n), y + 1.2, z + 0.32), RGB(255, 230, 120), MAT.Neon)
		ball(bulbs, V3(0.32, 0.32, 0.32), o * CF(-w / 2 + (k + 0.5) * (w / n), y - 1.2, z + 0.32), RGB(255, 230, 120), MAT.Neon)
	end
	tag(bulbs, "ChaseLights")
	return box
end
C.theaterMarquee = marquee

-- ===== stage 1: small stands, carts and stalls =====
local function stand(m, o, b, accent)
	local wood = RGB(150, 105, 62)
	if b.key == "lemonade" then
		P(m, V3(7, 2.2, 3.6), o * CF(0, 1.4, 1), wood, MAT.Wood, SOLID)
		P(m, V3(7.4, 0.3, 4), o * CF(0, 2.6, 1), RGB(196, 146, 84), MAT.WoodPlanks, SOLID)
		local sb = P(m, V3(4.4, 1.2, 0.15), o * CF(0, 1.5, 2.85), RGB(226, 70, 60))
		surfaceText(sb, Enum.NormalId.Back, b.signName and string.upper(b.signName) or "LEMONADE")
		for _, sx in ipairs({-3.4, 3.4}) do P(m, V3(0.35, 6, 0.35), o * CF(sx, 3.3, -0.6), wood, MAT.Wood) end
		awning(m, o * CF(0, 0, -2.4), 7.4, 6.1, 0, RGB(255, 214, 60), WHITE, "stripe")
		PROPS.lemonade(m, o * CF(0.8, 2.75, 0.8), 0.7)
		cyl(m, 1.2, 0.9, o * CF(-2.2, 3.35, 1), RGB(255, 245, 160), MAT.Glass, {Transparency = 0.3})
		return 7
	elseif b.key == "icecream" then
		P(m, V3(6, 3, 3.4), o * CF(0, 2.2, 0), RGB(255, 200, 225), MAT.SmoothPlastic, SOLID)
		P(m, V3(6.2, 0.3, 3.6), o * CF(0, 3.8, 0), RGB(120, 220, 200))
		for _, sx in ipairs({-2, 2}) do xcyl(m, 0.5, 1.6, o * CF(sx, 0.8, 1.8) * CFrame.Angles(0, 0, 0), DARK) end
		P(m, V3(0.3, 0.3, 2), o * CF(-3.4, 2.6, 0) , RGB(200, 200, 200), MAT.Metal)
		cyl(m, 4, 0.2, o * CF(0, 5.8, 0), RGB(220, 220, 220), MAT.Metal)
		for k = 0, 7 do
			local a = k * math.pi / 4
			P(m, V3(3.2, 0.12, 1.5), o * CF(math.cos(a) * 1.5, 7.6, math.sin(a) * 1.5) * CFrame.Angles(0, -a, math.rad(15)), (k % 2 == 0) and RGB(255, 150, 200) or WHITE, MAT.Fabric)
		end
		PROPS.icecream(m, o * CF(1.8, 3.95, 0), 0.35)
		return 8
	elseif b.key == "bakery" then
		P(m, V3(7, 2, 3.4), o * CF(0, 1.3, 0.6), RGB(220, 60, 60), MAT.Fabric, SOLID)
		P(m, V3(7.2, 0.2, 3.6), o * CF(0, 2.35, 0.6), WHITE, MAT.Fabric)
		for k = -2, 2 do ball(m, V3(1.2, 0.7, 0.8), o * CF(k * 1.3, 2.8, 0.6), RGB(215, 155, 75)) end
		for _, sx in ipairs({-3.4, 3.4}) do P(m, V3(0.3, 5.5, 0.3), o * CF(sx, 2.9, -0.8), wood, MAT.Wood) end
		awning(m, o * CF(0, 0, -2.6), 7.4, 5.7, 0, RGB(40, 120, 70), RGB(40, 120, 70), "solid")
		chalkboard(m, o, 4.4, 3.2, "FRESH\nBREAD")
		return 6.5
	elseif b.key == "coffee" then
		P(m, V3(6, 5, 4), o * CF(0, 2.8, 0), RGB(60, 70, 64), MAT.SmoothPlastic, SOLID)
		P(m, V3(4, 2, 0.2), o * CF(0, 3.4, 2.05), LIT, MAT.Neon, {Transparency = 0.4})
		P(m, V3(6.4, 0.4, 5.4), o * CF(0, 1.6, 1.2), RGB(120, 85, 55), MAT.WoodPlanks)
		P(m, V3(1.4, 1.2, 1), o * CF(-1.4, 2.4, 1.4), RGB(200, 200, 210), MAT.Metal)
		awning(m, o * CF(0, 0, 0), 6.4, 5.6, 2, RGB(30, 110, 70), WHITE, "stripe")
		PROPS.coffee(m, o * CF(0, 5.3, -0.5), 0.5)
		return 7.5
	elseif b.key == "pizza" then
		P(m, V3(6, 5, 5), o * CF(0, 2.8, -0.5), RGB(245, 230, 205), MAT.SmoothPlastic, SOLID)
		P(m, V3(3, 1.8, 0.3), o * CF(0, 3, 2.05), DARK, MAT.SmoothPlastic)
		P(m, V3(3.4, 0.3, 1), o * CF(0, 2.1, 2.4), RGB(150, 100, 60), MAT.WoodPlanks)
		local cols = {RGB(40, 140, 70), WHITE, RGB(220, 50, 50)}
		for k = 1, 3 do P(m, V3(2.2, 0.2, 2), o * CF(-2.2 + (k - 1) * 2.2, 4.3, 2.8) * CFrame.Angles(math.rad(-18), 0, 0), cols[k], MAT.Fabric) end
		P(m, V3(1.4, 3, 1.4), o * CF(2, 6.5, -2), RGB(150, 70, 50), MAT.Brick)
		ball(m, V3(1, 0.6, 1), o * CF(2, 8, -2), RGB(255, 140, 40), MAT.Neon)
		smoke(ghost(m, o * CF(2, 8.3, -2)), true, 4)
		return 8.5
	elseif b.key == "arcade" then
		P(m, V3(8, 0.4, 5), o * CF(0, 5.2, 0), RGB(40, 30, 60), MAT.SmoothPlastic)
		for _, sx in ipairs({-3.8, 3.8}) do
			for _, sz in ipairs({-2.3, 2.3}) do P(m, V3(0.3, 5, 0.3), o * CF(sx, 2.8, sz), DARK, MAT.Metal) end
		end
		for k, sx in ipairs({-1.8, 1.8}) do
			P(m, V3(2, 4, 1.6), o * CF(sx, 2.3, 0), RGB(30, 30, 40), MAT.SmoothPlastic, SOLID)
			P(m, V3(1.6, 1.3, 0.1), o * CF(sx, 3.2, 0.82), Color3.fromHSV(k * 0.3, 0.8, 1), MAT.Neon)
			P(m, V3(1.8, 0.2, 0.7), o * CF(sx, 2.2, 1), RGB(80, 80, 90))
		end
		P(m, V3(8, 0.3, 0.3), o * CF(0, 5.5, 2.6), RGB(255, 60, 200), MAT.Neon)
		return 6
	elseif b.key == "tech" then
		P(m, V3(8, 6, 7), o * CF(0, 3.3, -1), RGB(200, 205, 215), MAT.Concrete, SOLID)
		P(m, V3(5.6, 4.4, 0.2), o * CF(0, 2.5, 2.52), RGB(25, 25, 32), MAT.SmoothPlastic)
		P(m, V3(3, 0.2, 1.4), o * CF(0, 1.4, 1.5), RGB(150, 110, 70), MAT.WoodPlanks)
		P(m, V3(1.2, 0.8, 0.1), o * CF(0, 1.9, 1.2), RGB(120, 200, 255), MAT.Neon)
		local sb = P(m, V3(5, 1, 0.2), o * CF(0, 5.3, 2.55), RGB(40, 40, 50))
		surfaceText(sb, Enum.NormalId.Back, b.signName and string.upper(b.signName) or "STARTUP", RGB(120, 200, 255))
		return 7
	elseif b.key == "theater" then
		-- a pop-up outdoor screen: a big white screen on scaffolding, a ticket booth and folding chairs
		for _, sx in ipairs({-5, 5}) do P(m, V3(0.4, 9, 0.4), o * CF(sx, 4.5, -4), DARK, MAT.Metal) end
		P(m, V3(10.6, 0.4, 0.4), o * CF(0, 9, -4), DARK, MAT.Metal)
		local scr = P(m, V3(9.6, 5.4, 0.2), o * CF(0, 6, -3.9), RGB(245, 245, 250), MAT.SmoothPlastic)
		scr.Name = "Screen"
		surfaceText(scr, Enum.NormalId.Back, "🎬", RGB(40, 40, 60))
		P(m, V3(3.4, 3.4, 2.6), o * CF(-5.6, 1.9, 4.6), RGB(220, 40, 60), MAT.SmoothPlastic, SOLID)
		local sb = P(m, V3(3.6, 0.8, 0.2), o * CF(-5.6, 4, 5.95), RGB(30, 20, 26))
		surfaceText(sb, Enum.NormalId.Back, "🎟️ TICKETS", RGB(255, 230, 120))
		for r = 0, 1 do
			for k = -2, 2 do P(m, V3(1.2, 1, 1.2), o * CF(k * 1.8, 0.8, 1 + r * 2.4), RGB(40, 40, 50), MAT.Fabric) end
		end
		PROPS.theater(m, o * CF(5.6, 0.3, 4.6), 0.6)
		return 10
	else -- factory workshop
		P(m, V3(9, 6, 8), o * CF(0, 3.3, -0.5), RGB(150, 84, 64), MAT.Brick, SOLID)
		P(m, V3(4.5, 4.2, 0.2), o * CF(-1.5, 2.4, 3.55), RGB(120, 125, 135), MAT.DiamondPlate)
		for k = 0, 2 do P(m, V3(9.4, 0.3, 3), o * CF(0, 6.8, -3 + k * 2.6) * CFrame.Angles(math.rad(20), 0, 0), RGB(100, 100, 110), MAT.CorrodedMetal) end
		cyl(m, 5, 1.2, o * CF(3, 8.5, -3), RGB(180, 70, 55), MAT.Brick)
		smoke(ghost(m, o * CF(3, 11.2, -3)), true, 5)
		P(m, V3(1.6, 1.6, 1.6), o * CF(3, 1.1, 3), RGB(160, 120, 70), MAT.WoodPlanks)
		return 11
	end
end

-- ===== stages 2-6: themed shops that grow floor by floor =====
local THEME = {
	lemonade = {mat = MAT.SmoothPlastic, trim = WHITE, aw = {RGB(255, 214, 60), WHITE, "stripe"}, patio = RGB(255, 214, 60)},
	icecream = {mat = MAT.SmoothPlastic, trim = RGB(120, 220, 200), aw = {RGB(255, 150, 200), WHITE, "scallop"}, benches = true},
	bakery   = {mat = MAT.Brick, trim = RGB(240, 230, 210), aw = {RGB(40, 120, 70), RGB(40, 120, 70), "solid"}, flowers = true, chimney = true, board = "FRESH\nBREAD"},
	coffee   = {mat = MAT.SmoothPlastic, trim = RGB(150, 110, 70), aw = {RGB(30, 110, 70), WHITE, "stripe"}, patio = RGB(30, 110, 70), lights = true, board = "LATTE\n$3"},
	pizza    = {mat = MAT.SmoothPlastic, trim = RGB(160, 80, 60), aw = {RGB(40, 140, 70), RGB(220, 50, 50), "tricolor"}, oven = true, patio = RGB(220, 50, 50)},
	arcade   = {mat = MAT.SmoothPlastic, trim = RGB(255, 60, 200), aw = {RGB(40, 30, 60), RGB(40, 30, 60), "solid"}, arcade = true},
	tech     = {mat = MAT.Glass, trim = WHITE, aw = {RGB(40, 42, 52), RGB(40, 42, 52), "solid"}, tech = true},
	factory  = {mat = MAT.Brick, trim = RGB(90, 94, 102), aw = {RGB(90, 94, 102), RGB(90, 94, 102), "solid"}, factory = true},
	theater  = {mat = MAT.SmoothPlastic, trim = RGB(255, 210, 90), aw = {RGB(30, 20, 26), RGB(30, 20, 26), "solid"}, theater = true},
}
local DIMS = {nil, {12, 10, 1, 7.5}, {13, 11, 2, 6.5}, {14, 12, 3, 6}, {14.5, 12.5, 4, 6}, {15, 13, 5, 6}}

local function shop(m, o, b, st, accent)
	local T = THEME[b.key]
	local dm = DIMS[st]
	local w, d, floors, fh = dm[1], dm[2], dm[3], dm[4]
	local landmark = st == 6
	local trim = landmark and GOLD or T.trim
	local base = o * CF(0, 0, -1.5)
	local h = floors * fh
	local fz = d / 2 + 0.05
	-- walls, plinth, pilasters, bands, cornice
	local wall = P(m, V3(w, h, d), base * CF(0, 0.3 + h / 2, 0), b.wall, T.mat, SOLID)
	if T.tech then
		wall.Reflectance = 0.25
		wall.Color = RGB(90, 140, 190)
	end
	if T.factory then
		P(m, V3(w + 0.2, 2, d + 0.2), base * CF(0, 1.3, 0), RGB(120, 120, 125), MAT.Concrete)
	else
		P(m, V3(w + 0.4, 0.9, d + 0.4), base * CF(0, 0.75, 0), RGB(170, 170, 175), MAT.Concrete)
	end
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do P(m, V3(0.7, h, 0.7), base * CF(sx * w / 2, 0.3 + h / 2, sz * d / 2), trim, landmark and MAT.Foil or MAT.SmoothPlastic) end
	end
	for f = 1, floors - 1 do P(m, V3(w + 0.3, 0.45, d + 0.3), base * CF(0, 0.3 + f * fh, 0), trim) end
	P(m, V3(w + 0.9, 0.9, d + 0.9), base * CF(0, 0.3 + h + 0.45, 0), trim, landmark and MAT.Foil or MAT.SmoothPlastic)
	-- storefront
	local sfH = math.min(fh - 1.4, 5.2)
	for _, sx in ipairs({-1, 1}) do
		P(m, V3(w * 0.3 + 0.4, sfH - 0.8, 0.2), base * CF(sx * w * 0.27, 1.6 + (sfH - 1.6) / 2, fz), DARK, MAT.Metal)
		P(m, V3(w * 0.3, sfH - 1.2, 0.2), base * CF(sx * w * 0.27, 1.6 + (sfH - 1.6) / 2, fz + 0.05), LIT, MAT.Neon, {Transparency = 0.55})
	end
	P(m, V3(2.8, 4.6, 0.25), base * CF(0, 2.6, fz), DARK, MAT.Metal)
	P(m, V3(2.2, 4.2, 0.2), base * CF(0, 2.5, fz + 0.06), RGB(150, 200, 240), MAT.Glass, {Transparency = 0.3})
	local aw = T.aw
	if aw[3] == "tricolor" then
		local cols = {RGB(40, 140, 70), WHITE, RGB(220, 50, 50)}
		local n = 9
		for k = 1, n do
			P(m, V3(w / n, 0.2, 2.4), base * CF(-w / 2 + (k - 0.5) * (w / n), 0.3 + sfH + 0.2, fz + 1.1) * CFrame.Angles(math.rad(-18), 0, 0), cols[(k - 1) % 3 + 1], MAT.Fabric)
		end
	else
		awning(m, base, w, 0.3 + sfH + 0.2, fz, aw[1], aw[2], aw[3])
	end
	-- sign
	local sb = P(m, V3(w * 0.8, 1.6, 0.3), base * CF(0, 0.3 + sfH + 1.5, fz + 0.15), T.arcade and RGB(20, 16, 40) or (landmark and GOLD or b.roof), landmark and MAT.Foil or MAT.SmoothPlastic)
	surfaceText(sb, Enum.NormalId.Back, b.icon .. " " .. string.upper(b.signName or b.name), T.arcade and RGB(255, 90, 220) or WHITE)
	-- upper floor windows (front + sides)
	for f = 1, floors - 1 do
		local y = 0.3 + f * fh + fh * 0.5
		for i = -1, 1 do window(m, base, i * w * 0.3, y, fz, w * 0.18, fh * 0.5, false) end
		for _, sx in ipairs({-1, 1}) do
			for _, zz in ipairs({-d * 0.22, d * 0.22}) do window(m, base, sx * (w / 2 + 0.05), y, zz, d * 0.2, fh * 0.5, true) end
		end
		if T.flowers then flowerBox(m, base, 0, y - fh * 0.32, fz + 0.4, w * 0.8) end
	end
	local roofY = 0.3 + h + 0.9
	-- ===== theme features =====
	if T.patio then
		umbrellaTable(m, o, -w / 2 + 1.2, 6.2, T.patio)
		umbrellaTable(m, o, w / 2 - 1.2, 6.2, T.patio)
	end
	if T.benches then
		for _, sx in ipairs({-w / 2 + 1.5, w / 2 - 1.5}) do
			P(m, V3(3, 0.3, 1), o * CF(sx, 1.4, 6.5), RGB(255, 170, 200), MAT.WoodPlanks)
			P(m, V3(3, 1, 0.2), o * CF(sx, 2, 6.9), RGB(255, 170, 200), MAT.WoodPlanks)
		end
		for k = 1, 12 do
			ball(m, V3(0.35, 0.35, 0.2), base * CF(-w / 2 + k * (w / 13), 0.3 + fh * 0.93, fz + 0.1), Color3.fromHSV(k / 12, 0.7, 1), MAT.Neon)
		end
	end
	if T.board then chalkboard(m, o, w / 2 - 0.8, 6.2, T.board) end
	if T.lights then stringLights(m, o, w, 6.5, 7.2) end
	if T.chimney then
		P(m, V3(1.6, 4, 1.6), base * CF(w * 0.3, roofY + 1.6, -d * 0.25), RGB(150, 70, 50), MAT.Brick)
		smoke(ghost(m, base * CF(w * 0.3, roofY + 3.8, -d * 0.25)), false, 5)
	end
	if T.oven then
		P(m, V3(2, 5, 2), base * CF(-w * 0.32, roofY + 2.1, -d * 0.25), RGB(150, 70, 50), MAT.Brick)
		ball(m, V3(1.6, 0.9, 1.6), base * CF(-w * 0.32, roofY + 4.8, -d * 0.25), RGB(255, 130, 40), MAT.Neon)
		smoke(ghost(m, base * CF(-w * 0.32, roofY + 5.2, -d * 0.25)), true, 5)
		P(m, V3(w + 0.1, 1.6, d + 0.1), base * CF(0, 1.9, 0), RGB(160, 80, 60), MAT.Brick)
	end
	if T.arcade then
		-- cabinets out front + chasing marquee bulbs + pixel invader art
		for k, sx in ipairs({-w / 2 + 1.4, w / 2 - 1.4}) do
			P(m, V3(1.8, 4, 1.5), base * CF(sx, 2.3, fz + 1.4), RGB(30, 30, 40), MAT.SmoothPlastic, SOLID)
			P(m, V3(1.5, 1.3, 0.1), base * CF(sx, 3.2, fz + 2.17), Color3.fromHSV(0.1 + k * 0.4, 0.8, 1), MAT.Neon)
			P(m, V3(1.7, 0.2, 0.7), base * CF(sx, 2.2, fz + 2.3), RGB(80, 80, 90))
		end
		local marquee = Instance.new("Model")
		marquee.Name = "Marquee"
		marquee.Parent = m
		for k = 0, 13 do
			ball(marquee, V3(0.4, 0.4, 0.4), base * CF(-w * 0.4 + k * (w * 0.8 / 13), 0.3 + sfH + 2.45, fz + 0.35), RGB(255, 230, 120), MAT.Neon)
		end
		tag(marquee, "ChaseLights")
		local invader = {"00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"}
		local px = 0.42
		for r, row in ipairs(invader) do
			for c = 1, #row do
				if row:sub(c, c) == "1" then
					P(m, V3(0.1, px, px), base * CF(w / 2 + 0.1, 0.3 + fh * floors * 0.55 + (8 - r) * px, (c - 6) * px), RGB(80, 255, 120), MAT.Neon)
				end
			end
		end
		for f = 0, floors - 1 do P(m, V3(w + 0.35, 0.2, 0.2), base * CF(0, 0.3 + f * fh + 0.3, fz + 0.05), RGB(80, 200, 255), MAT.Neon) end
	end
	if T.tech then
		for k = 0, math.floor(w / 1.2) do P(m, V3(0.15, h, 0.15), base * CF(-w / 2 + k * 1.2, 0.3 + h / 2, fz + 0.05), WHITE) end
		local logo = P(m, V3(4, 1.6, 0.2), base * CF(0, roofY - 1.8, fz + 0.2), RGB(20, 20, 30))
		surfaceText(logo, Enum.NormalId.Back, "</>", RGB(90, 200, 255))
		for k = 0, 2 do
			P(m, V3(w * 0.25, 0.2, 2), base * CF(-w * 0.3 + k * w * 0.3, roofY + 0.8, -d * 0.15) * CFrame.Angles(math.rad(-25), 0, 0), RGB(30, 50, 110), MAT.Glass, {Reflectance = 0.3})
		end
		local dish = ball(m, V3(2.4, 0.8, 2.4), base * CF(w * 0.3, roofY + 1.6, d * 0.25) * CFrame.Angles(math.rad(35), 0, 0), RGB(230, 230, 235), MAT.Metal)
		P(m, V3(0.3, 1.4, 0.3), base * CF(w * 0.3, roofY + 0.7, d * 0.25), RGB(160, 160, 170), MAT.Metal)
		for k = 0, 2 do P(m, V3(0.15, 1, 1.4), o * CF(-w / 2 + 1 + k * 0.9, 1.1, 6.6), DARK, MAT.Metal) end
	end
	if T.factory then
		-- sawtooth roof, loading dock, crates, stacks, water tower
		local teeth = math.max(2, math.floor(w / 3.4))
		for k = 0, teeth - 1 do
			local x = -w / 2 + (k + 0.5) * (w / teeth)
			wedge(m, V3(w / teeth, 2.4, d), base * CF(x, roofY + 1.2, 0) * CFrame.Angles(0, math.rad(90), 0), RGB(110, 110, 120), MAT.CorrodedMetal)
			P(m, V3(0.15, 2.2, d - 0.4), base * CF(x + w / teeth / 2 - 0.1, roofY + 1.1, 0), RGB(170, 210, 240), MAT.Glass, {Transparency = 0.3})
		end
		P(m, V3(w * 0.4, 1, 3), base * CF(-w * 0.28, 0.8, fz + 1.5), RGB(150, 150, 155), MAT.Concrete, SOLID)
		for k = 0, 3 do P(m, V3(1.5, 1.5, 1.5), o * CF(w / 2 - 1 - (k % 2) * 1.6, 1.05 + math.floor(k / 2) * 1.5, 6.5), RGB(160, 120, 70), MAT.WoodPlanks) end
		for _, sx in ipairs({-w * 0.3, w * 0.3}) do
			local sh = 6 + st * 2
			cyl(m, sh, 1.6, base * CF(sx, roofY + sh / 2, -d * 0.35), RGB(185, 70, 55), MAT.Brick)
			cyl(m, 0.6, 1.7, base * CF(sx, roofY + sh * 0.8, -d * 0.35), WHITE, MAT.Concrete)
			smoke(ghost(m, base * CF(sx, roofY + sh + 0.4, -d * 0.35)), true, 7)
		end
		if st >= 4 then
			for _, lx in ipairs({-1, 1}) do
				for _, lz in ipairs({-1, 1}) do P(m, V3(0.3, 4, 0.3), base * CF(lx * 1.3, roofY + 2, d * 0.2 + lz * 1.3), DARK, MAT.Metal) end
			end
			cyl(m, 3, 3.6, base * CF(0, roofY + 5.5, d * 0.2), RGB(150, 110, 80), MAT.WoodPlanks)
			cyl(m, 0.8, 4, base * CF(0, roofY + 7.4, d * 0.2), RGB(90, 60, 45), MAT.Wood)
		end
	end
	if T.theater then
		-- the marquee over the doors, a red carpet, velvet ropes, poster cases and searchlights at night
		local film = b.film or "Coming Soon"
		marquee(m, base, w * 0.9, 0.3 + sfH + 3.6, fz + 0.5, film)
		P(m, V3(3, 0.08, 6), o * CF(0, 0.34, 4.4), RGB(180, 20, 40), MAT.Fabric)
		for _, sx in ipairs({-1, 1}) do
			for k = 0, 2 do P(m, V3(0.25, 1.6, 0.25), o * CF(sx * 2, 1.1, 2.2 + k * 2.2), GOLD, MAT.Foil) end
			P(m, V3(0.2, 0.2, 4.6), o * CF(sx * 2, 1.7, 4.4), RGB(150, 20, 40), MAT.Fabric)
			local pc = P(m, V3(2.4, 3.4, 0.2), base * CF(sx * w * 0.36, 2.6, fz + 0.25), RGB(20, 16, 22))
			surfaceText(pc, Enum.NormalId.Back, sx < 0 and "🍿\nNOW\nSHOWING" or "🎞️\nCOMING\nSOON", RGB(255, 220, 120))
		end
		for _, sx in ipairs({-w * 0.35, w * 0.35}) do
			local beam = P(m, V3(0.6, 14, 0.6), base * CF(sx, roofY + 7, 0) * CFrame.Angles(0, 0, math.rad(sx < 0 and 12 or -12)), RGB(255, 245, 210), MAT.Neon, {Transparency = 0.75})
			beam.Name = "Searchlight"
			cyl(m, 1, 1.4, base * CF(sx, roofY + 0.5, 0), DARK, MAT.Metal)
		end
	end
	-- stage 5+: setback tower
	local top = roofY
	if st >= 5 then
		local th = landmark and 12 or 9
		P(m, V3(w * 0.62, th, d * 0.62), base * CF(0, roofY + th / 2, 0), b.color:Lerp(WHITE, 0.25), MAT.Glass, {CanCollide = true, Reflectance = 0.25})
		for _, sx in ipairs({-1, 1}) do
			for _, sz in ipairs({-1, 1}) do
				P(m, V3(0.35, th, 0.35), base * CF(sx * w * 0.31, roofY + th / 2, sz * d * 0.31), landmark and GOLD or accent, MAT.Neon)
			end
		end
		top = roofY + th
		P(m, V3(w * 0.68, 0.6, d * 0.68), base * CF(0, top + 0.3, 0), landmark and GOLD or trim, landmark and MAT.Foil or MAT.SmoothPlastic)
		top += 0.6
	end
	if landmark then
		P(m, V3(4.4, 2.4, 4.4), base * CF(0, top + 1.2, 0), GOLD, MAT.Foil)
		top += 2.4
		P(m, V3(0.35, 6, 0.35), base * CF(0, top + 3, 0), RGB(230, 230, 235), MAT.Metal)
		local orb = ball(m, V3(1.4, 1.4, 1.4), base * CF(0, top + 6.4, 0), GOLD, MAT.Neon)
		local pl = Instance.new("PointLight")
		pl.Color = GOLD
		pl.Range = 30
		pl.Brightness = 3
		pl.Parent = orb
		sparkle(orb, RGB(255, 225, 120), 18)
		local ring = cyl(m, 0.25, w * 0.9, base * CF(0, top - 4, 0), GOLD, MAT.Neon, {Transparency = 0.3})
		spin(ring, 1)
		return top + 7.5
	end
	local ptop = PROPS[b.key](m, base * CF(0, top, -d * 0.1), 0.8 + st * 0.18)
	if st == 5 then sparkle(ghost(m, base * CF(0, top + ptop, 0)), accent, 10) end
	return top + ptop
end

function F.accentFor(plr)
	local d = data[plr]
	if not d then return WHITE end
	for _, s in ipairs(SKINS) do
		if s.key == d.skin and s.color then return s.color end
	end
	return d.plot.color
end

-- v10: the same storefronts are built on city plots (GameServer > RealEstate)
C.bizBuilders = {stand = function(...) return stand(...) end, shop = function(...) return shop(...) end}
function F.refreshBuilding(plr, key, animate)
	local d = data[plr]
	if not d then return end
	local plot = d.plot
	local b = BIZ[key]
	local lvl = d.levels[key] or 0
	local chains = d.chains[key] or 0
	if b.lotOnly then
		-- v14: lives on a city plot (GameServer > RealEstate builds it there), never on the home plot
		local lot = F.siteLot and F.siteLot(plr, key)
		if lot and lvl > 0 then
			F.buildLot(lot)
			if animate then
				local o = F.slotCF(plot, key)
				burst(o.Position + V3(0, 8, 0), b.color, 50)
				shockwave(o.Position + V3(0, 0.4, 0), b.color, 22)
			end
		end
		return
	end
	if plot.slots[key] then
		plot.slots[key]:Destroy()
		plot.slots[key] = nil
	end
	if lvl <= 0 then return end
	local stage = stageOf(lvl, chains)
	local o = F.slotCF(plot, key)
	local m = Instance.new("Model")
	m.Name = b.tiers[stage]
	local base = P(m, V3(16, 0.3, 16), o * CF(0, 0.15, 0), RGB(205, 205, 210), MAT.Concrete, SOLID)
	m.PrimaryPart = base
	-- v10: the brand's colors and name
	local bb = F.brandedBiz and F.brandedBiz(d, key) or b
	local accent = (F.brandAccent and d.brands and d.brands[key] and d.brands[key].accent) and F.brandAccent(d, key) or F.accentFor(plr)
	local top = stage == 1 and stand(m, o, bb, accent) or shop(m, o, bb, stage, accent)
	local status
	if stage == 6 then
		status = {text = "🌟 LANDMARK", color = GOLD}
	elseif lvl >= CFG.MAX_LEVEL then
		status = {text = "MAX" .. (chains > 0 and ("  📍x" .. (chains + 1)) or ""), color = GOLD}
	else
		status = {text = "LEVEL " .. lvl, color = b.color:Lerp(WHITE, 0.35)}
	end
	status.h = 0.42
	status.font = Enum.Font.GothamBold
	local brandName = F.bizName and F.hasBizName and F.hasBizName(d, key) and F.bizName(d, key) or nil
	if brandName then
		status.text = b.tiers[stage] .. "  •  " .. status.text
		billboard(base, UDim2.fromOffset(240, 58), V3(0, top + 2, 0), {{text = string.upper(brandName), h = 0.58}, status}, 170)
	else
		billboard(base, UDim2.fromOffset(220, 54), V3(0, top + 2, 0), {{text = b.tiers[stage], h = 0.58}, status}, 170)
	end
	if F.empireDress then F.empireDress(m, o, d, key, top, F.empireTier and F.empireTier(d) or 0) end
	-- v14: the owner can run the counter (Rush Orders)
	if C.RECIPES and C.RECIPES[key] then
		C.prompt(base, "🍳 Rush orders", b.tiers[stage], 14, 0.2, function(who)
			if who == plr then F.cookStart(plr, key) else C.notify(who, "🍳 Only the owner runs this counter.") end
		end)
	end
	m:SetAttribute("Top", top)
	m.Parent = plot.folder
	plot.slots[key] = m
	if d.problems[key] then F.problemVisual(plr, key, true) end
	if animate then
		popIn(m)
		burst(o.Position + V3(0, top * 0.5, 0), b.color, 50)
		shockwave(o.Position + V3(0, 0.4, 0), b.color, 22)
	end
end

function F.problemVisual(plr, key, on)
	local d = data[plr]
	local m = d and d.plot.slots[key]
	if not m then return end
	local old = m:FindFirstChild("ProblemFX")
	if old then old:Destroy() end
	if not on then return end
	local top = m:GetAttribute("Top") or 8
	local a = ghost(m, m.PrimaryPart.CFrame * CF(0, top * 0.6, 0))
	a.Name = "ProblemFX"
	local e = sparkle(a, RGB(255, 170, 40), 12)
	e.Speed = NumberRange.new(4, 8)
	C.smoke(a, true, 4)
	billboard(a, UDim2.fromOffset(60, 60), V3(0, top * 0.4 + 6, 0), {{text = "⚠️"}}, 140)
end

-- rare secret businesses get their own little landmark in the plaza (second row)
local RARE_LOOKS = {}
function RARE_LOOKS.moviestudio(m, pos, c)
	P(m, V3(7, 5, 6), CF(pos + V3(0, 2.8, 0)), RGB(60, 60, 70), MAT.SmoothPlastic, SOLID)
	local sign = P(m, V3(7.4, 1.4, 0.3), CF(pos + V3(0, 6, 3.1)), RGB(20, 20, 26))
	surfaceText(sign, Enum.NormalId.Back, "🎬 STUDIO", RGB(255, 90, 90))
	surfaceText(sign, Enum.NormalId.Front, "🎬 STUDIO", RGB(255, 90, 90))
	for _, sx in ipairs({-2, 2}) do
		local reel = C.xcyl(m, 0.4, 2.2, CF(pos + V3(sx, 7.6, 0)), DARK, MAT.Metal)
		spin(reel, 1)
	end
	local lamp = ball(m, V3(1.4, 1.4, 1.4), CF(pos + V3(3, 6.4, 3)), RGB(255, 250, 220), MAT.Neon)
	local sl = Instance.new("SpotLight")
	sl.Range, sl.Angle, sl.Brightness, sl.Face = 60, 30, 4, Enum.NormalId.Top
	sl.Parent = lamp
	return 9
end
function RARE_LOOKS.robotfactory(m, pos, c)
	P(m, V3(7, 5, 6), CF(pos + V3(0, 2.8, 0)), RGB(150, 160, 175), MAT.DiamondPlate, SOLID)
	P(m, V3(0.8, 5, 0.8), CF(pos + V3(2, 7.5, 0)), RGB(255, 170, 40), MAT.Metal)
	P(m, V3(4, 0.8, 0.8), CF(pos + V3(0.4, 10, 0)), RGB(255, 170, 40), MAT.Metal)
	local head = P(m, V3(2, 1.6, 1.6), CF(pos + V3(0, 7, 3.2)), RGB(200, 210, 225), MAT.Metal)
	for _, sx in ipairs({-0.45, 0.45}) do P(m, V3(0.4, 0.4, 0.1), CF(pos + V3(sx, 7.1, 4.02)), RGB(90, 220, 255), MAT.Neon) end
	sparkle(head, RGB(120, 200, 255), 4)
	return 11
end
function RARE_LOOKS.bank(m, pos, c)
	P(m, V3(8, 0.6, 6.5), CF(pos + V3(0, 0.6, 0)), RGB(235, 235, 230), MAT.Marble, SOLID)
	for _, sx in ipairs({-3, -1, 1, 3}) do cyl(m, 4.6, 0.8, CF(pos + V3(sx, 3.2, 2.6)), RGB(245, 245, 240), MAT.Marble) end
	P(m, V3(7, 4.6, 4), CF(pos + V3(0, 3.2, -0.8)), RGB(225, 220, 205), MAT.Marble, SOLID)
	C.wedge(m, V3(8.4, 2, 6.5), CF(pos + V3(0, 6.5, 0)) * CFrame.Angles(0, math.pi, 0), RGB(255, 205, 60), MAT.Foil)
	local vault = C.xcyl(m, 0.3, 2.6, CF(pos + V3(0, 3, 1.25)) * CFrame.Angles(0, math.rad(90), 0), RGB(180, 185, 195), MAT.Metal)
	sparkle(vault, RGB(255, 220, 120), 6)
	return 8
end
function RARE_LOOKS.spacecenter(m, pos, c)
	P(m, V3(7, 0.6, 7), CF(pos + V3(0, 0.6, 0)), RGB(130, 130, 140), MAT.Concrete, SOLID)
	cyl(m, 9, 2.4, CF(pos + V3(0, 5.4, 0)), WHITE, MAT.Metal)
	ball(m, V3(2.4, 3.4, 2.4), CF(pos + V3(0, 10.4, 0)), RGB(220, 60, 50), MAT.Metal)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		P(m, V3(0.3, 2.6, 1.6), CF(pos + V3(math.cos(a) * 1.5, 2.2, math.sin(a) * 1.5)) * CFrame.Angles(0, -a, 0), RGB(220, 60, 50), MAT.Metal)
	end
	local flame = ball(m, V3(1.4, 1.4, 1.4), CF(pos + V3(0, 1.2, 0)), RGB(255, 150, 40), MAT.Neon)
	sparkle(flame, RGB(255, 180, 60), 12)
	P(m, V3(0.8, 12, 0.8), CF(pos + V3(-2.8, 6.6, -2.8)), RGB(170, 90, 60), MAT.CorrodedMetal)
	return 12
end

-- combo kiosks (front row) + rare secret landmarks (second row)
function F.refreshKiosks(plr)
	local d = data[plr]
	if not d then return end
	local plot = d.plot
	for _, k in pairs(plot.kiosks) do k:Destroy() end
	plot.kiosks = {}
	local row1, row2 = 0, 0
	for _, c in ipairs(COMBOS) do
		local m = Instance.new("Model")
		m.Name = "Combo_" .. c.key
		if c.rare then
			row2 += 1
			local pos = plot.at(-18 + (row2 - 1) * 12, 1, 22)
			if d.combos[c.key] then
				local top = RARE_LOOKS[c.key] and RARE_LOOKS[c.key](m, pos, c) or 6
				local anchor = ghost(m, CF(pos + V3(0, top, 0)))
				billboard(anchor, UDim2.fromOffset(170, 60), V3(0, 2.5, 0), {{text = c.icon .. " " .. c.name, h = 0.55, color = c.color}, {text = c.perkText or "", h = 0.45, font = Enum.Font.GothamBold}}, 160)
			else
				local q = P(m, V3(1, 1, 1), CF(pos + V3(0, 2, 0)), WHITE, MAT.SmoothPlastic, {Transparency = 1})
				billboard(q, UDim2.fromOffset(40, 40), V3(0, 0, 0), {{text = "🗝️", color = RGB(200, 200, 210)}}, 40)
			end
			m.Parent = plot.folder
			plot.kiosks[c.key] = m
			continue
		end
		row1 += 1
		local pos = plot.at(-36 + (row1 - 1) * 8.2, 1, 14)
		if d.combos[c.key] then
			P(m, V3(5.2, 0.3, 5.2), CF(pos + V3(0, 0.15, 0)), RGB(60, 60, 70), MAT.SmoothPlastic, SOLID)
			P(m, V3(4.4, 3.4, 4.4), CF(pos + V3(0, 2, 0)), RGB(250, 248, 240), MAT.SmoothPlastic, SOLID)
			local roof = P(m, V3(5.2, 0.6, 5.2), CF(pos + V3(0, 4, 0)), c.color, MAT.Neon)
			P(m, V3(3.4, 1.6, 0.1), CF(pos + V3(0, 2.2, 2.22 * plot.fz)), LIT, MAT.Neon, {Transparency = 0.5})
			billboard(roof, UDim2.fromOffset(130, 60), V3(0, 3, 0), {{text = c.icon, h = 0.55}, {text = c.name, h = 0.45, font = Enum.Font.GothamBold, color = c.color}}, 100)
		else
			P(m, V3(5.2, 0.3, 5.2), CF(pos + V3(0, 0.15, 0)), RGB(90, 90, 100), MAT.SmoothPlastic, {Transparency = 0.4})
			local q = P(m, V3(1, 1, 1), CF(pos + V3(0, 2, 0)), WHITE, MAT.SmoothPlastic, {Transparency = 1})
			billboard(q, UDim2.fromOffset(40, 40), V3(0, 0, 0), {{text = "?", color = RGB(200, 200, 210)}}, 60)
		end
		m.Parent = plot.folder
		plot.kiosks[c.key] = m
	end
end

-- Empire Tower HQ + trophies
function F.refreshTower(plr, force)
	local d = data[plr]
	if not d then return end
	local plot = d.plot
	local tier = F.tierIndex(d.rep)
	local maxed = 0
	for _, b in ipairs(BUSINESSES) do
		if (d.levels[b.key] or 0) >= CFG.MAX_LEVEL then maxed += 1 end
	end
	local floors = tier >= C.FEATURES.tower and (3 + tier + maxed + math.min(10, d.rebirths)) or 0
	-- v12: every verified empire milestone adds floors and a crown (a billionaire's tower is the tallest on the street)
	local etier = F.empireTier and F.empireTier(d) or 0
	if etier > 0 then floors = math.max(floors, 4) + etier * 3 end
	local key = floors .. "|" .. d.skin .. "|" .. d.trophies .. "|" .. d.rebirths .. "|e" .. etier
	if key == d.towerKey and not force then return end
	d.towerKey = key
	if plot.tower then plot.tower:Destroy() end
	local m = Instance.new("Model")
	m.Name = "EmpireTower"
	plot.tower = m
	local accent = F.accentFor(plr)
	if d.trophies > 0 then
		local tp = plot.at(38, 1, -6)
		P(m, V3(4, 1.6, 4), CF(tp + V3(0, 0.8, 0)), RGB(50, 50, 60), MAT.Marble, SOLID)
		cyl(m, 0.5, 1.6, CF(tp + V3(0, 1.85, 0)), GOLD, MAT.Foil)
		cyl(m, 1.5, 0.5, CF(tp + V3(0, 2.8, 0)), GOLD, MAT.Foil)
		local cup = cyl(m, 2, 2.6, CF(tp + V3(0, 4.5, 0)), GOLD, MAT.Foil)
		sparkle(cup, RGB(255, 225, 120), 6)
		billboard(cup, UDim2.fromOffset(120, 36), V3(0, 3, 0), {{text = "🏆 x" .. d.trophies, color = GOLD}}, 110)
	end
	if floors > 0 then
		local base = plot.at(38.5, 1, -26)
		local fh = 3.8
		local labels = {"LOBBY", "MANAGEMENT", "INVESTMENTS", "AWARDS", "CUSTOMIZE"}
		for f = 0, floors - 1 do
			local w = f < floors - 2 and 10 or 8.5
			local fl = P(m, V3(w, fh, w), CF(base + V3(0, f * fh + fh / 2, 0)), RGB(40, 44, 58), MAT.Glass, {CanCollide = true, Reflectance = 0.2})
			P(m, V3(w + 0.2, 0.25, w + 0.2), CF(base + V3(0, f * fh + fh, 0)), accent, MAT.Neon)
			if labels[f + 1] then
				local tl = surfaceText(fl, plot.fz == 1 and Enum.NormalId.Back or Enum.NormalId.Front, labels[f + 1], WHITE)
				tl.Parent.CanvasSize = Vector2.new(400, 150)
			end
		end
		local topY = floors * fh + 1
		if etier > 0 then topY = F.empireCrown(m, base, floors * fh, etier, accent) + 1 end
		m:SetAttribute("Top", topY)
		local ring = cyl(m, 0.3, 8, CF(base + V3(0, topY + 1.5, 0)), accent, MAT.Neon, {Transparency = 0.2})
		spin(ring, 1.2)
		local holo = ball(m, V3(3, 3, 3), CF(base + V3(0, topY + 3.2, 0)), accent, MAT.Neon, {Transparency = 0.35})
		spin(holo, -0.8)
		billboard(holo, UDim2.fromOffset(220, 70), V3(0, 3, 0), {{text = "🏢 " .. string.upper(plr.Name) .. " HQ", h = 0.6}, {text = floors .. " floors", h = 0.4, color = accent, font = Enum.Font.GothamBold}}, 500)
		local door = P(m, V3(3.4, 3.4, 0.3), CF(base + V3(0, 1.7, 5.2 * plot.fz)), RGB(255, 215, 90), MAT.Neon, {Transparency = 0.3})
		C.prompt(door, "Enter HQ", "Empire Tower", 10, 0.2, function(who)
			-- v10: the tower is your HQ. Walk in once it has a floor; otherwise the HQ card shows what to build.
			if who ~= plr then
				if F.hqLevel and data[plr] and F.hqLevel(data[plr]) >= 1 then F.enterInterior(who, plr, "hq1") end
			elseif F.hqLevel and F.hqLevel(data[plr]) >= 1 then
				F.enterInterior(plr, plr, "hq1")
			elseif F.hqInfo then
				R.Menu:FireClient(plr, "hq", F.hqInfo(plr))
			end
		end)
	end
	m.Parent = plot.folder
end

-- ===== STAFF ON SITE =====
-- The server publishes each plot's hired staff as a small JSON roster on the plot folder.
-- Every client draws the workers from it (see EmpireClient > Workers), so the server never moves NPCs.
local HttpService = game:GetService("HttpService")
local BEHIND_COUNTER = {lemonade = true, icecream = true, bakery = true}
-- plaza spots for the company-wide staff: {x, z, wander half-width, wander half-depth} in plot coordinates
local SPECIAL_SPOTS = {manager = {31, 27, 5, 4}, marketer = {0, 40, 10, 1.5}, engineer = {-31, 27, 5, 4}}
function F.refreshWorkers(plr)
	local d = data[plr]
	if not d then return end
	local plot = d.plot
	local yaw = plot.fz == 1 and 0 or math.pi
	local fixKey
	for _, b in ipairs(BUSINESSES) do
		if not fixKey and d.problems[b.key] and (d.levels[b.key] or 0) > 0 then fixKey = b.key end
	end
	local list = {}
	for _, slot in ipairs(C.STAFF_ORDER) do
		local s = d.staff[slot]
		local role = C.STAFF_ROLES[slot]
		if s and role then
			local e = {id = slot, name = s.name, role = role.role, stars = C.staffStars(s)}
			local b = BIZ[slot]
			if b then
				local lvl = d.levels[slot] or 0
				if lvl > 0 then
					local stage = stageOf(lvl, d.chains[slot] or 0)
					local spot
					if stage == 1 then
						spot = BEHIND_COUNTER[slot] and CF(0, 0.3, -2.6) or CF(0, 0.3, 4.6)
					else
						spot = CF(0, 0.3, 6.9)
					end
					local p = (F.slotCF(plot, slot) * spot).Position
					e.x, e.y, e.z, e.yaw = p.X, p.Y, p.Z, yaw
					e.ex, e.ez = stage == 1 and 1.8 or 3.4, stage == 1 and 0.2 or 0.7
					table.insert(list, e)
				end
			else
				local sp = SPECIAL_SPOTS[slot]
				local p = plot.at(sp[1], 1.15, sp[2])
				e.x, e.y, e.z, e.yaw, e.ex, e.ez = p.X, p.Y, p.Z, yaw, sp[3], sp[4]
				if slot == "engineer" and fixKey then
					local fp = (F.slotCF(plot, fixKey) * CF(2.5, 0.3, 8.2)).Position
					e.fx, e.fy, e.fz = fp.X, fp.Y, fp.Z
				end
				table.insert(list, e)
			end
		end
	end
	local json = #list > 0 and HttpService:JSONEncode(list) or ""
	if plot.folder:GetAttribute("Workers") ~= json then plot.folder:SetAttribute("Workers", json) end
end
function F.clearWorkers(plot) plot.folder:SetAttribute("Workers", "") end

function F.setIce(plot, on)
	if on and not plot.ice then
		local ice = P(plot.folder, V3(88, 24, 50), CF(plot.at(0, 13, -16)), RGB(170, 225, 255), MAT.Ice, {Transparency = 0.55, Name = "Ice"})
		local e = sparkle(ice, RGB(220, 245, 255), 30)
		e.Speed = NumberRange.new(0.5, 1.5)
		plot.ice = ice
	elseif (not on) and plot.ice then
		plot.ice:Destroy()
		plot.ice = nil
	end
end
end
