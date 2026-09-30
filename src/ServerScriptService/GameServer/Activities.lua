-- FUN PARK: ferris wheel, carousel, mini-game booths, fireworks. Ways to spend (and win) money.
return function(C)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, ball, cyl, xcyl, billboard, surfaceText, sparkle, burst, shockwave, tag =
	C.P, C.ball, C.cyl, C.xcyl, C.billboard, C.surfaceText, C.sparkle, C.burst, C.shockwave, C.tag
local MINIGAMES, FERRIS, FIREWORKS, REP_TIERS, fmt, notify = C.MINIGAMES, C.FERRIS, C.FIREWORKS, C.REP_TIERS, C.fmt, C.notify
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 250), RGB(35, 35, 40)

local f = Instance.new("Folder")
f.Name = "FunPark"
f.Parent = C.WORLD
C.reserve(-605, -115, -345, 115)
P(f, V3(250, 2, 95), CF(-475, -0.85, -60), RGB(210, 195, 170), MAT.Cobblestone, SOLID)
P(f, V3(250, 2, 95), CF(-475, -0.85, 60), RGB(210, 195, 170), MAT.Cobblestone, SOLID)
C.gate(f, V3(-350, 0, 0), true, "🎡 FUN PARK", "Rides & games • " .. REP_TIERS[C.FEATURES.funpark].name, RGB(255, 120, 200))

-- ===== FERRIS WHEEL (rotated on every client, stays in sync by time) =====
local HUB = V3(-470, 34, -62)
local RADIUS = 28
do
	local wheelM = Instance.new("Model")
	wheelM.Name = "FerrisWheel"
	wheelM:SetAttribute("Hub", HUB)
	wheelM:SetAttribute("Axis", "Z")
	wheelM:SetAttribute("Speed", 0.12)
	for _, sz in ipairs({-5, 5}) do
		for _, sx in ipairs({-16, 16}) do
			local a, b = V3(HUB.X + sx, 0, HUB.Z + sz), V3(HUB.X, HUB.Y, HUB.Z + sz)
			P(f, V3(1.2, 1.2, (b - a).Magnitude), CF((a + b) / 2, b), RGB(235, 235, 240), MAT.Metal, SOLID)
		end
	end
	xcyl(f, 12, 3, CF(HUB) * CFrame.Angles(0, math.rad(90), 0), RGB(200, 200, 210), MAT.Metal)
	local segs = 36
	for k = 0, segs - 1 do
		local a = k / segs * math.pi * 2
		local pos = HUB + V3(math.cos(a) * RADIUS, math.sin(a) * RADIUS, 0)
		for _, sz in ipairs({-3, 3}) do
			local p = P(wheelM, V3(0.8, 2 * math.pi * RADIUS / segs + 0.4, 0.8), CF(pos + V3(0, 0, sz)) * CFrame.Angles(0, 0, a), (k % 2 == 0) and RGB(255, 90, 170) or RGB(80, 200, 255), MAT.Neon)
			p:SetAttribute("Kind", "spin")
		end
	end
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local mid = HUB + V3(math.cos(a) * RADIUS / 2, math.sin(a) * RADIUS / 2, 0)
		for _, sz in ipairs({-3, 3}) do
			local p = P(wheelM, V3(RADIUS, 0.4, 0.4), CF(mid + V3(0, 0, sz)) * CFrame.Angles(0, 0, a), WHITE, MAT.Metal)
			p:SetAttribute("Kind", "spin")
		end
	end
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local pos = HUB + V3(math.cos(a) * RADIUS, math.sin(a) * RADIUS - 3.2, 0)
		local col = Color3.fromHSV(k / 12, 0.65, 1)
		local cab = P(wheelM, V3(4, 3.4, 4.4), CF(pos), col, MAT.SmoothPlastic)
		cab:SetAttribute("Kind", "gondola")
		cab:SetAttribute("Hang", 3.2)
		local roof = P(wheelM, V3(4.6, 0.5, 5), CF(pos + V3(0, 2, 0)), WHITE, MAT.SmoothPlastic)
		roof:SetAttribute("Kind", "gondola")
		roof:SetAttribute("Hang", 1.2)
		local win = P(wheelM, V3(4.1, 1.4, 3.4), CF(pos + V3(0, 0.6, 0)), RGB(170, 220, 255), MAT.Glass, {Transparency = 0.4})
		win:SetAttribute("Kind", "gondola")
		win:SetAttribute("Hang", 2.6)
	end
	wheelM.Parent = f
	tag(wheelM, "Rotator")
	local booth = P(f, V3(6, 4, 4), CF(-470, 2, -38), RGB(255, 90, 170), MAT.SmoothPlastic, SOLID)
	billboard(booth, UDim2.fromOffset(220, 60), V3(0, 4, 0), {{text = "🎡 FERRIS WHEEL", h = 0.55}, {text = "+10% income for 3 min", h = 0.45, color = RGB(140, 255, 170), font = Enum.Font.GothamBold}}, 120)
	C.prompt(booth, "Ride", "Ferris Wheel", 12, 0.3, function(plr) F.rideFerris(plr) end)
end

-- ===== CAROUSEL =====
do
	local cm = Instance.new("Model")
	cm.Name = "Carousel"
	local c0 = V3(-395, 0, -62)
	cm:SetAttribute("Hub", c0)
	cm:SetAttribute("Axis", "Y")
	cm:SetAttribute("Speed", 0.5)
	cyl(f, 1, 26, CF(c0 + V3(0, 0.5, 0)), RGB(240, 220, 170), MAT.WoodPlanks, SOLID)
	cyl(f, 12, 2, CF(c0 + V3(0, 6.5, 0)), RGB(255, 205, 60), MAT.Foil)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local cone = P(cm, V3(8, 0.5, 13), CF(c0 + V3(0, 12.6, 0)) * CFrame.Angles(0, a, 0) * CF(0, 0, -6) * CFrame.Angles(math.rad(18), 0, 0), (k % 2 == 0) and RGB(255, 90, 90) or WHITE, MAT.Fabric)
		cone:SetAttribute("Kind", "spin")
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local pos = c0 + V3(math.cos(a) * 9, 0, math.sin(a) * 9)
		local pole = P(cm, V3(0.3, 11, 0.3), CF(pos + V3(0, 6.5, 0)), RGB(255, 215, 90), MAT.Metal)
		pole:SetAttribute("Kind", "spin")
		local horse = P(cm, V3(1.2, 2, 3.6), CF(pos + V3(0, 3.5 + (k % 2) * 1, 0)) * CFrame.Angles(0, -a, 0), Color3.fromHSV(k / 8, 0.4, 1), MAT.SmoothPlastic)
		horse:SetAttribute("Kind", "spin")
		local head = P(cm, V3(1, 1.6, 1.2), CF(pos + V3(0, 5 + (k % 2) * 1, 0)) * CFrame.Angles(0, -a, 0) * CF(0, 0, -1.8), Color3.fromHSV(k / 8, 0.4, 1), MAT.SmoothPlastic)
		head:SetAttribute("Kind", "spin")
	end
	cm.Parent = f
	tag(cm, "Rotator")
end

-- ===== GAME BOOTHS =====
local function booth(x, key)
	local g = MINIGAMES[key]
	local o = CF(x, 0, 60) * CFrame.Angles(0, math.pi, 0)
	P(f, V3(12, 3.2, 3), o * CF(0, 1.6, -3), RGB(250, 245, 235), MAT.WoodPlanks, SOLID)
	P(f, V3(12, 8, 0.6), o * CF(0, 4, 3.5), RGB(60, 50, 90), MAT.SmoothPlastic, SOLID)
	for _, sx in ipairs({-5.8, 5.8}) do P(f, V3(0.5, 9, 0.5), o * CF(sx, 4.5, -3), WHITE) end
	for k = 0, 7 do
		P(f, V3(1.6, 0.3, 8), o * CF(-5.6 + k * 1.6, 9.2, 0) * CFrame.Angles(math.rad(-12), 0, 0), (k % 2 == 0) and Color3.fromHSV((x % 97) / 97, 0.7, 1) or WHITE, MAT.Fabric)
	end
	for k = 0, 9 do
		ball(f, V3(1.3, 1.3, 1.3), o * CF(-4.8 + (k % 5) * 2.4, 5 + math.floor(k / 5) * 1.8, 2.9), Color3.fromHSV(k / 10, 0.6, 1))
	end
	local sign = P(f, V3(10, 2, 0.3), o * CF(0, 10.5, -3), DARK)
	surfaceText(sign, Enum.NormalId.Front, g.icon .. " " .. string.upper(g.name), RGB(255, 220, 100))
	C.prompt(sign, "Play", g.name, 14, 0.2, function(plr) F.startMinigame(plr, key) end)
end
booth(-400, "hoop")
booth(-460, "rush")
booth(-520, "memory")

-- ===== FIREWORKS LAUNCHER =====
do
	local pad = cyl(f, 1, 12, CF(-560, 0.5, -40), RGB(60, 60, 70), MAT.DiamondPlate, SOLID)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		cyl(f, 3, 1, CF(-560 + math.cos(a) * 3.5, 2.5, -40 + math.sin(a) * 3.5), Color3.fromHSV(k / 6, 0.8, 1), MAT.SmoothPlastic)
	end
	billboard(pad, UDim2.fromOffset(240, 60), V3(0, 6, 0), {{text = "🎆 FIREWORKS", h = 0.55}, {text = "Launch a show over your business! +Rep", h = 0.45, color = RGB(255, 220, 120), font = Enum.Font.GothamBold}}, 120)
	C.prompt(pad, "Launch Fireworks", "Fireworks", 12, 0.5, function(plr) F.launchFireworks(plr) end)
end
-- decor: balloons + food carts
for k = 1, 10 do
	local x, z = -370 - k * 22, (k % 2 == 0) and 18 or -18
	P(f, V3(0.1, 8, 0.1), CF(x, 4, z), RGB(220, 220, 220))
	ball(f, V3(2, 2.4, 2), CF(x, 9, z), Color3.fromHSV(k / 10, 0.7, 1), MAT.SmoothPlastic)
end

-- ===== logic =====
local pending, cool = {}, {}
function F.funFee(d, mult) return math.max(100, math.floor(F.incomePerSec(d) * mult)) end
local function check(plr)
	local d = data[plr]
	if not d then return nil end
	if not F.unlocked(d, "funpark") then
		notify(plr, "🔒 The Fun Park unlocks at " .. REP_TIERS[C.FEATURES.funpark].name)
		return nil
	end
	return d
end
function F.startMinigame(plr, key)
	local d = check(plr)
	local g = MINIGAMES[key]
	if not (d and g) then return end
	if cool[plr] and os.clock() < cool[plr] then return end
	local fee = F.funFee(d, g.fee)
	if d.cash < fee then
		notify(plr, "Entry costs $" .. fmt(fee))
		return
	end
	d.cash -= fee
	cool[plr] = os.clock() + 3
	local token = tostring(math.random(1, 1e9))
	pending[plr] = {key = key, token = token, t0 = os.clock(), fee = fee}
	R.Menu:FireClient(plr, "minigame", key, token, fee)
end
function F.finishMinigame(plr, token, score)
	local d = data[plr]
	local p = pending[plr]
	if not (d and p and p.token == token and type(score) == "number") then return end
	pending[plr] = nil
	local g = MINIGAMES[p.key]
	if os.clock() - p.t0 < g.minTime then return end
	score = math.clamp(math.floor(score), 0, g.maxScore)
	local mult
	if p.key == "hoop" then
		mult = score * 0.25
	elseif p.key == "rush" then
		mult = math.min(3, score * 0.22)
	else
		mult = score
	end
	local prize = math.floor(p.fee * mult)
	d.cash += prize
	d.earned += prize
	F.addRep(plr, 1)
	if mult >= 2 then F.buzz(g.icon, plr.Name .. " crushed " .. g.name .. " and won $" .. fmt(prize) .. "!", RGB(255, 180, 60)) end
	R.Splash:FireClient(plr, g.icon .. " " .. (mult >= 1 and "YOU WIN!" or "NICE TRY!"), "Score: " .. score .. " • Prize: $" .. fmt(prize) .. " (entry was $" .. fmt(p.fee) .. ")", mult >= 1 and RGB(120, 255, 150) or RGB(255, 180, 120))
end
function F.rideFerris(plr)
	local d = check(plr)
	if not d then return end
	local fee = F.funFee(d, FERRIS.fee)
	if d.cash < fee then
		notify(plr, "A ride costs $" .. fmt(fee))
		return
	end
	d.cash -= fee
	d.relaxedUntil = os.clock() + FERRIS.buffTime
	R.Menu:FireClient(plr, "ferris", HUB, RADIUS)
	notify(plr, "🎡 Enjoy the view! +10% income for 3 minutes.")
end
function F.launchFireworks(plr)
	local d = check(plr)
	if not d then return end
	if d.fireworksCd and os.clock() < d.fireworksCd then
		notify(plr, "🎆 Reloading... try again in " .. math.ceil(d.fireworksCd - os.clock()) .. "s")
		return
	end
	local fee = F.funFee(d, FIREWORKS.fee)
	if d.cash < fee then
		notify(plr, "Fireworks cost $" .. fmt(fee))
		return
	end
	d.cash -= fee
	d.fireworksCd = os.clock() + FIREWORKS.cooldown
	F.addRep(plr, 5)
	C.announceAll("🎆 " .. plr.Name .. " is throwing a fireworks show over their empire!")
	local center = d.plot.center
	for i = 1, 16 do
		task.delay(i * 0.35, function()
			local start = center + V3(math.random(-30, 30), 2, math.random(-30, 30))
			local col = Color3.fromHSV(math.random(), 0.8, 1)
			local rocket = ball(Workspace, V3(0.8, 0.8, 0.8), CF(start), col, MAT.Neon)
			sparkle(rocket, col, 30)
			local top = start + V3(math.random(-6, 6), math.random(45, 70), math.random(-6, 6))
			TweenService:Create(rocket, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = top}):Play()
			task.delay(1.1, function()
				burst(top, col, 160, 1.6)
				shockwave(top, col, 30)
				rocket:Destroy()
			end)
			Debris:AddItem(rocket, 3)
		end)
	end
end
function F.clearFun(plr)
	pending[plr] = nil
	cool[plr] = nil
end
end
