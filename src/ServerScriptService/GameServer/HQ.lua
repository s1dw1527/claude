-- HQ + GENERAL MANAGER (v10)
--
-- HQ: your Empire Tower (it appears on your plot at HOTSPOT) becomes a real headquarters you can walk into. Each
-- HQ level adds a floor, built like the other interiors (only while someone is on it):
--   1 Reception (front desk, receptionist, your empire logo)     2 Management (desks, business screens, the manager)
--   3 Finance (income, investments, revenue charts)               4 Executive (meeting table, city view, EMPIRE WALL)
--   5 Private office (your desk + computer, safe, awards)         6 Rooftop (helipad, lounge, skyline)
-- An elevator panel on every floor moves you between floors.
--
-- GENERAL MANAGER: your hired Manager (Staff app) can sign a contract once the HQ has a Management floor.
-- While the contract runs (it only counts down while you're playing) the manager takes care of problems:
--   * repairs take time (90 s at level 1 down to 45 s at level 5) and cost the normal repair price
--   * level 3+ handles up to 3 problems at once, level 4+ fixes your biggest earners first,
--     level 5 also handles the advanced problems (power outages, theft, road works)
--   * low supplies get restocked (at the normal price)
-- Contracts last 15 / 20 / 30 / 40 / 60 minutes (manager level 1-5) and then EXPIRE: renew it yourself. An optional
-- auto-renew only works while you're actively playing (an action in the last 10 minutes) and at most 2 times in a
-- row, so the manager never turns the game into AFK income.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local P, surfaceText = C.P, C.surfaceText
local fmt, notify = C.fmt, C.notify
local BIZ, REP_TIERS = C.BIZ, C.REP_TIERS
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 252), RGB(30, 30, 36)

C.HQ_FLOORS = {
	{n = 1, name = "Reception", icon = "🛎️", cost = 250000, desc = "Front desk, receptionist and your empire logo."},
	{n = 2, name = "Management", icon = "📋", cost = 2000000, desc = "Staff desks and business screens. Unlocks the General Manager."},
	{n = 3, name = "Finance", icon = "💹", cost = 15000000, desc = "Income, investments and revenue charts."},
	{n = 4, name = "Executive", icon = "🏙️", cost = 100000000, desc = "Meeting table, city view and the Empire Wall."},
	{n = 5, name = "Private Office", icon = "🗄️", cost = 600000000, desc = "Your desk and computer, a safe, your awards."},
	{n = 6, name = "Rooftop", icon = "🚁", cost = 3000000000, desc = "Helipad, lounge and the best view in the city."},
}
C.HQ_TIER = C.FEATURES.tower
C.MANAGER = {
	minutes = {15, 20, 30, 40, 60},                 -- contract length by manager level (staff stars 1-5)
	repairSeconds = {90, 80, 68, 56, 45},
	parallel = {1, 1, 3, 3, 3},
	costShare = 0.08,                              -- a contract costs ~8% of what you earn during it
	costMin = 2000,
	autoMaxInRow = 2, activeWindow = 600,
	advanced = {[3] = true, [9] = true, [10] = true},   -- power outage, theft, road works: level 5 only
	restockBelow = 25,
}
local M = C.MANAGER

-- =====================================================================
-- HQ ROOMS (Interiors builds them; these fill them in)
-- =====================================================================
C.HQ_LAYOUT = {w = 56, d = 40}
local function sign(m, size, cf, text, face, color, bg)
	local p = P(m, size, cf, bg or DARK)
	surfaceText(p, face or Enum.NormalId.Back, text, color or WHITE)
	return p
end
local function desk(m, o, x, z, color)
	P(m, V3(5, 0.3, 2.6), o * CF(x, 2.6, z), color or RGB(90, 70, 55), MAT.Wood, SOLID)
	for _, sx in ipairs({-2.2, 2.2}) do P(m, V3(0.3, 2.5, 2.2), o * CF(x + sx, 1.3, z), color or RGB(90, 70, 55), MAT.Wood) end
	P(m, V3(1.8, 1.2, 0.15), o * CF(x, 3.5, z - 0.8), RGB(20, 30, 50), MAT.Neon)
	P(m, V3(1.6, 1.8, 1.6), o * CF(x, 1.4, z + 2), RGB(40, 40, 46), MAT.Fabric)
end
local function screen(m, cf, size, lines, color)
	local p = P(m, size, cf, RGB(10, 14, 24), MAT.Glass)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.CanvasSize = Vector2.new(size.X * 50, size.Y * 50)
	sg.LightInfluence = 0
	sg.Parent = p
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = color or RGB(120, 230, 255)
	tl.TextScaled = true
	tl.Font = Enum.Font.Code
	tl.TextXAlignment = Enum.TextXAlignment.Left
	tl.TextYAlignment = Enum.TextYAlignment.Top
	tl.Text = table.concat(lines, "\n")
	tl.Parent = sg
	return p
end
C.hqElevator = function(m, o, L, owner)
	local panel = P(m, V3(2, 3, 0.4), o * CF(L.w / 2 - 6, 4, L.d / 2 - 0.9), RGB(200, 200, 210), MAT.Metal)
	P(m, V3(5, 9, 0.3), o * CF(L.w / 2 - 10, 4.5, L.d / 2 - 0.7), RGB(170, 175, 185), MAT.Metal)
	sign(m, V3(4, 0.8, 0.2), o * CF(L.w / 2 - 10, 9.6, L.d / 2 - 0.8), "ELEVATOR", Enum.NormalId.Front, WHITE, DARK)
	C.prompt(panel, "Elevator", "HQ floors", 10, 0, function(plr)
		local od = data[owner]
		if not od then return end
		local floors = {}
		for _, f in ipairs(C.HQ_FLOORS) do if f.n <= (od.hq and od.hq.level or 0) then table.insert(floors, {n = f.n, name = f.name, icon = f.icon}) end end
		R.Menu:FireClient(plr, "elevator", {owner = owner.UserId, floors = floors, ownerName = owner.Name})
	end)
end
local function businessLines(d)
	local out = {}
	local _, per = F.income(d, os.clock())
	for _, b in ipairs(C.BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 then table.insert(out, string.format("%s %-18s Lv%2d  $%s/s", b.icon, string.sub(F.bizName(d, b.key), 1, 18), lvl, fmt(per[b.key] or 0))) end
	end
	if #out == 0 then out = {"No businesses yet."} end
	return out
end
C.HQ_THEMES = {}
C.HQ_THEMES.hq1 = function(m, o, L, d, owner, accent)
	-- reception: front desk + receptionist (client draws her), seating, the empire logo
	P(m, V3(14, 3.6, 3), o * CF(0, 2.3, -4), RGB(235, 230, 220), MAT.Marble, SOLID)
	P(m, V3(14.2, 0.3, 3.2), o * CF(0, 4.2, -4), accent, MAT.SmoothPlastic)
	sign(m, V3(22, 5, 0.4), o * CF(0, 9, -L.d / 2 + 0.8), "🏢 " .. string.upper(owner.Name) .. " EMPIRE", Enum.NormalId.Back, WHITE, accent)
	for _, x in ipairs({-L.w / 2 + 6, L.w / 2 - 6}) do
		P(m, V3(6, 1.2, 2.6), o * CF(x, 1.2, 8), RGB(60, 60, 70), MAT.Fabric, SOLID)
		P(m, V3(6, 2, 0.8), o * CF(x, 2.4, 9.2), RGB(60, 60, 70), MAT.Fabric)
		local leaf = P(m, V3(2.6, 2.6, 2.6), o * CF(x, 2.6, 13), RGB(70, 160, 80), MAT.Grass)
		leaf.Shape = Enum.PartType.Ball
	end
	return {{"receptionist", 0, -6.5}}
end
C.HQ_THEMES.hq2 = function(m, o, L, d, owner, accent)
	for r = 0, 1 do
		for i = 0, 2 do desk(m, o, -14 + i * 9, -6 + r * 9) end
	end
	screen(m, o * CF(0, 8, -L.d / 2 + 0.8), V3(24, 7, 0.3), {"BUSINESS OVERVIEW", "", table.unpack(businessLines(d))})
	-- the General Manager's desk
	desk(m, o, L.w / 2 - 9, -10, RGB(60, 40, 30))
	local hub = P(m, V3(4, 4, 4), o * CF(L.w / 2 - 9, 2, -7), WHITE, MAT.SmoothPlastic, {Transparency = 1})
	sign(m, V3(6, 1, 0.2), o * CF(L.w / 2 - 9, 6.2, -12), "GENERAL MANAGER", Enum.NormalId.Back, WHITE, DARK)
	C.prompt(hub, "Talk to your manager", "General Manager", 10, 0, function(plr)
		if plr == owner then R.Menu:FireClient(plr, "manager", F.managerInfo(plr)) end
	end)
	return {{"worker", -14, -3.5}, {"worker", -5, 5.5}, {"worker", 4, -3.5}, {"manager", L.w / 2 - 9, -7.5}}
end
C.HQ_THEMES.hq3 = function(m, o, L, d, owner, accent)
	local inc = F.incomePerSec(d)
	local port = 0
	for id, n in pairs(d.shares or {}) do
		local p = Players:GetPlayerByUserId(id)
		local od = p and data[p]
		if od then port += n * od.company.price end
	end
	screen(m, o * CF(-10, 8, -L.d / 2 + 0.8), V3(18, 7, 0.3), {"FINANCES", "", "Cash: $" .. fmt(d.cash), "Income: $" .. fmt(inc) .. "/s", "Lifetime: $" .. fmt(d.earned),
		"Properties: " .. F.propertiesUsed(d) .. "/" .. F.propertyCapacity(d)}, RGB(120, 255, 150))
	screen(m, o * CF(12, 8, -L.d / 2 + 0.8), V3(16, 7, 0.3), {"INVESTMENTS", "", "Stock portfolio: $" .. fmt(port), "Your company: $" .. fmt(d.company and d.company.price or 0) .. "/share",
		"Rental buildings: " .. #(d.props or {})}, RGB(255, 220, 120))
	-- revenue chart: one bar per business
	local _, per = F.income(d, os.clock())
	local maxv = 1
	for _, v in pairs(per) do maxv = math.max(maxv, v) end
	for i, b in ipairs(C.BUSINESSES) do
		local h = math.max(0.3, 7 * (per[b.key] or 0) / maxv)
		P(m, V3(2, h, 2), o * CF(-14 + i * 3.4, 0.5 + h / 2, 6), b.color, MAT.Neon)
	end
	sign(m, V3(26, 1, 0.2), o * CF(1, 0.9, 7.2), "REVENUE BY BUSINESS", Enum.NormalId.Front, WHITE, DARK)
	for i = 0, 2 do desk(m, o, -12 + i * 12, 14) end
	return {{"worker", -12, 16.5}, {"worker", 12, 16.5}}
end
C.HQ_THEMES.hq4 = function(m, o, L, d, owner, accent)
	-- meeting table
	P(m, V3(18, 0.4, 6), o * CF(0, 2.8, 4), RGB(60, 40, 30), MAT.Wood, SOLID)
	for i = -3, 3, 2 do
		for _, sz in ipairs({0, 8}) do P(m, V3(1.6, 2.4, 1.6), o * CF(i * 2.6, 1.4, sz), RGB(30, 30, 36), MAT.Fabric) end
	end
	-- city view: a glass wall on the left
	local win = P(m, V3(0.4, 10, L.d - 4), o * CF(-L.w / 2 + 0.9, 6, 0), RGB(150, 200, 255), MAT.Glass)
	win.Transparency = 0.4
	-- the EMPIRE WALL: your empire on a big map
	local wall = P(m, V3(24, 10, 0.4), o * CF(4, 7, -L.d / 2 + 0.8), RGB(16, 22, 34), MAT.SmoothPlastic)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.CanvasSize = Vector2.new(960, 400)
	sg.LightInfluence = 0
	sg.Parent = wall
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.TextColor3 = WHITE
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Text = "🗺️ " .. string.upper(owner.Name) .. "'S EMPIRE"
	title.Parent = sg
	local b = C.mapBounds or {-650, -620, 650, 380}
	local function dot(x, z, text, color)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new((x - b[1]) / (b[3] - b[1]), 0, 0.12 + 0.86 * (z - b[2]) / (b[4] - b[2]), 0)
		l.Size = UDim2.fromOffset(46, 30)
		l.BackgroundTransparency = 1
		l.TextColor3 = color
		l.TextScaled = true
		l.Text = text
		l.Parent = sg
	end
	for _, dist in ipairs(C.DISTRICTS) do
		local sx, sz, n = 0, 0, 0
		for _, lot in ipairs(C.LOTS) do if lot.dkey == dist.key then sx += lot.pos.X sz += lot.pos.Z n += 1 end end
		if n > 0 then dot(sx / n, sz / n, dist.icon, dist.color) end
	end
	dot(d.plot.center.X, d.plot.center.Z, "🏢", accent)
	local hl = F.homeLot(d)
	if hl then dot(hl.pos.X, hl.pos.Z, "🏠", RGB(120, 255, 150)) end
	for _, deed in ipairs(d.deeds or {}) do
		local lot = F.lotOfDeed(owner, deed)
		if lot then dot(lot.pos.X, lot.pos.Z, deed.biz and BIZ[deed.biz].icon or "📍", RGB(255, 220, 120)) end
	end
	local hub = P(m, V3(6, 6, 2), o * CF(4, 3, -L.d / 2 + 3), WHITE, MAT.SmoothPlastic, {Transparency = 1})
	C.prompt(hub, "Inspect Empire", "Empire Wall", 12, 0, function(plr)
		if plr == owner and F.openComputer then F.openComputer(plr, "wall") end
	end)
	return {}
end
C.HQ_THEMES.hq5 = function(m, o, L, d, owner, accent)
	-- the player's desk + computer
	P(m, V3(8, 0.4, 3.4), o * CF(0, 2.8, -8), RGB(50, 32, 24), MAT.Wood, SOLID)
	local comp = P(m, V3(2.4, 1.5, 0.2), o * CF(0, 3.9, -9), RGB(20, 40, 70), MAT.Neon)
	P(m, V3(2, 2.4, 2), o * CF(0, 1.4, -5.6), RGB(20, 20, 24), MAT.Leather)
	C.prompt(comp, "Use Computer", "Office computer", 10, 0, function(plr)
		if plr == owner and F.openComputer then F.openComputer(plr, "hq") end
	end)
	-- the safe
	local safe = P(m, V3(3, 3.6, 3), o * CF(L.w / 2 - 4, 2.3, -L.d / 2 + 3), RGB(70, 72, 80), MAT.DiamondPlate, SOLID)
	P(m, V3(1, 1, 0.2), o * CF(L.w / 2 - 4, 2.6, -L.d / 2 + 4.55), RGB(200, 180, 90), MAT.Metal)
	C.prompt(safe, "Open Safe", "Your safe", 8, 0.8, function(plr)
		if plr ~= owner then return end
		local relics = 0
		for _ in pairs(d.found or {}) do relics += 1 end
		R.Splash:FireClient(plr, "🗄️ YOUR SAFE", "$" .. fmt(d.cash) .. " cash  •  🏆 " .. d.trophies .. " trophies  •  🏺 " .. relics .. " relics  •  " .. #(d.deeds or {}) .. " deeds", RGB(255, 215, 90))
	end)
	-- awards wall: achievements
	local list = {}
	for key in pairs(d.achievements or {}) do
		local a = C.ACHIEVEMENTS[key]
		if a and #list < 14 then table.insert(list, a.icon .. " " .. a.title) end
	end
	if #list == 0 then list = {"No awards yet."} end
	screen(m, o * CF(-L.w / 2 + 0.9, 7, 0) * CFrame.Angles(0, math.pi / 2, 0), V3(20, 8, 0.3), {"🏆 AWARDS", table.unpack(list)}, RGB(255, 220, 120))
	for i = 1, math.min(8, d.trophies or 0) do
		local cup = P(m, V3(0.9, 1.4, 0.9), o * CF(-12 + i * 2.4, 5.2, -L.d / 2 + 1.2), RGB(255, 205, 60), MAT.Foil)
		cup.Shape = Enum.PartType.Cylinder
	end
	P(m, V3(22, 0.3, 1.4), o * CF(-1, 4.3, -L.d / 2 + 1.2), RGB(60, 40, 30), MAT.Wood)
	return {}
end
C.HQ_THEMES.hq6 = function(m, o, L, d, owner, accent)
	-- rooftop: helipad, lounge, railings
	local pad = P(m, V3(18, 0.2, 18), o * CF(-10, 0.6, -4), RGB(60, 60, 66), MAT.Concrete)
	surfaceText(pad, Enum.NormalId.Top, "H", RGB(255, 210, 60))
	for _, x in ipairs({8, 14, 20}) do
		P(m, V3(2.4, 0.8, 5), o * CF(x, 1, 8) * CFrame.Angles(math.rad(-10), 0, 0), WHITE, MAT.Fabric)
	end
	local pool = P(m, V3(12, 0.4, 6), o * CF(14, 0.7, -10), RGB(60, 170, 255), MAT.Glass)
	pool.Transparency = 0.2
	return {}
end

-- =====================================================================
-- BUYING / UPGRADING THE HQ
-- =====================================================================
function F.hqLevel(d) return type(d.hq) == "table" and (tonumber(d.hq.level) or 0) or 0 end
function F.hqNextFloor(d) return C.HQ_FLOORS[F.hqLevel(d) + 1] end
function F.buyHQFloor(plr)
	local d = data[plr]
	if not d then return false end
	if F.tierIndex(d.rep) < C.HQ_TIER then
		notify(plr, "🏢 Your HQ unlocks at " .. REP_TIERS[C.HQ_TIER].name .. " reputation.")
		return false
	end
	local f = F.hqNextFloor(d)
	if not f then
		notify(plr, "🏢 Your HQ is complete!")
		return false
	end
	if d.cash < f.cost then
		notify(plr, "🏢 The " .. f.name .. " floor costs $" .. fmt(f.cost) .. ".")
		return false
	end
	d.cash -= f.cost
	d.hq = type(d.hq) == "table" and d.hq or {}
	d.hq.level = f.n
	R.Splash:FireClient(plr, "🏢 HQ: " .. string.upper(f.name) .. " FLOOR", f.desc, RGB(120, 190, 255))
	F.buzz("🏢", plr.Name .. "'s HQ just added a " .. f.name .. " floor!", d.plot.color)
	if F.refreshTower then F.refreshTower(plr, true) end
	if F.guideTip then F.guideTip(plr, f.n == 1 and "visitHQ" or (f.n == 2 and "hireManager" or nil)) end
	return true
end
function F.hqInfo(plr)
	local d = data[plr]
	local floors = {}
	for _, f in ipairs(C.HQ_FLOORS) do table.insert(floors, {n = f.n, name = f.name, icon = f.icon, cost = f.cost, desc = f.desc, built = f.n <= F.hqLevel(d)}) end
	return {level = F.hqLevel(d), floors = floors, unlocked = F.tierIndex(d.rep) >= C.HQ_TIER, needs = REP_TIERS[C.HQ_TIER].name, manager = F.managerInfo(plr)}
end

-- =====================================================================
-- THE GENERAL MANAGER
-- =====================================================================
local jobs = {}            -- [plr] = { {key, eta, kind} }
local activeAt = {}        -- [plr] = os.clock() of their last action
local autoInRow = {}
function F.markActive(plr) activeAt[plr] = os.clock() end
local function mgrOf(d)
	d.mgr = type(d.mgr) == "table" and d.mgr or {left = 0, auto = false, handled = 0}
	d.mgr.left = math.max(0, tonumber(d.mgr.left) or 0)
	return d.mgr
end
function F.managerLevel(d)
	local s = d.staff and d.staff.manager
	return s and math.clamp(math.floor(tonumber(s.exp) or 1), 1, 5) or 0
end
function F.contractCost(d)
	local lvl = math.max(1, F.managerLevel(d))
	local mins = M.minutes[lvl]
	return math.max(M.costMin, math.floor(F.incomePerSec(d) * 60 * mins * M.costShare))
end
function F.managerActive(d) return F.managerLevel(d) > 0 and F.hqLevel(d) >= 2 and mgrOf(d).left > 0 end
function F.signContract(plr, auto)
	local d = data[plr]
	if not d then return false end
	if F.managerLevel(d) <= 0 then notify(plr, "📋 Hire a Manager first (Staff app).") return false end
	if F.hqLevel(d) < 2 then notify(plr, "📋 Your HQ needs a Management floor first.") return false end
	local m = mgrOf(d)
	if m.left > 60 and not auto then notify(plr, "📋 The contract is still running (" .. math.ceil(m.left / 60) .. " min left).") return false end
	local cost = F.contractCost(d)
	if d.cash < cost then notify(plr, "📋 A contract costs $" .. fmt(cost) .. ".") return false end
	d.cash -= cost
	local lvl = F.managerLevel(d)
	m.left = m.left + M.minutes[lvl] * 60
	if not auto then autoInRow[plr] = 0 end
	notify(plr, "📋 " .. d.staff.manager.name .. " signed a " .. M.minutes[lvl] .. "-minute contract (-$" .. fmt(cost) .. ").")
	if F.guideTip then F.guideTip(plr, "hireManager") end
	return true
end
function F.setAutoRenew(plr, on)
	local d = data[plr]
	if d then mgrOf(d).auto = on == true end
end
local function canHandle(d, pr)
	local lvl = F.managerLevel(d)
	if M.advanced[pr.type] then return lvl >= 5 end
	return lvl >= 1
end
-- a new problem appeared: the manager takes it if they can
function F.managerOnProblem(plr, d, key)
	if not F.managerActive(d) then return end
	local pr = d.problems[key]
	if not pr or not canHandle(d, pr) then return end
	jobs[plr] = jobs[plr] or {}
	for _, j in ipairs(jobs[plr]) do if j.key == key and j.kind == "repair" then return end end
	local lvl = F.managerLevel(d)
	table.insert(jobs[plr], {key = key, kind = "repair", wait = M.repairSeconds[lvl], started = nil})
	pr.manager = true
	notify(plr, "📋 Your manager is on the " .. (C.PROBLEMS[pr.type] and C.PROBLEMS[pr.type].text or "problem") .. " at " .. F.bizName(d, key) .. ".")
end
local function step(plr, d, dt, now)
	local m = mgrOf(d)
	if F.managerLevel(d) <= 0 then return end
	if m.left > 0 then
		m.left = math.max(0, m.left - dt)
		if m.left <= 0 then
			-- expired: optional auto-renew, but only for an active player and only a couple of times in a row
			local active = (activeAt[plr] or -1e9) + M.activeWindow > now
			if m.auto and active and (autoInRow[plr] or 0) < M.autoMaxInRow and d.cash >= F.contractCost(d) then
				autoInRow[plr] = (autoInRow[plr] or 0) + 1
				F.signContract(plr, true)
				notify(plr, "📋 Contract auto-renewed (" .. autoInRow[plr] .. "/" .. M.autoMaxInRow .. " in a row).")
			else
				R.Splash:FireClient(plr, "📋 MANAGER CONTRACT EXPIRED", "\"" .. (d.staff.manager and d.staff.manager.name or "Your manager") .. " is taking a break.\" Renew it at your HQ.", RGB(255, 180, 80))
				jobs[plr] = {}
				for _, pr in pairs(d.problems) do pr.manager = nil end
			end
		end
	end
	if not F.managerActive(d) then return end
	local lvl = F.managerLevel(d)
	local list = jobs[plr] or {}
	jobs[plr] = list
	-- low supplies: restock (a job like any other)
	if F.stockOf then
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 then
				local s = F.stockOf(d, b.key)
				if math.min(s[1], s[2], s[3]) < M.restockBelow then
					local queued = false
					for _, j in ipairs(list) do if j.key == b.key and j.kind == "restock" then queued = true end end
					if not queued then table.insert(list, {key = b.key, kind = "restock", wait = 30}) end
				end
			end
		end
	end
	-- level 4+: biggest earners first
	if lvl >= 4 and #list > 1 then
		local _, per = F.income(d, now)
		table.sort(list, function(x, y)
			if (x.started ~= nil) ~= (y.started ~= nil) then return x.started ~= nil end
			return (per[x.key] or 0) > (per[y.key] or 0)
		end)
	end
	local working = 0
	for _, j in ipairs(list) do if j.started then working += 1 end end
	for _, j in ipairs(list) do
		if not j.started and working < M.parallel[lvl] then
			j.started = now
			working += 1
		end
	end
	for i = #list, 1, -1 do
		local j = list[i]
		if j.started and now - j.started >= j.wait then
			table.remove(list, i)
			if j.kind == "repair" then
				local pr = d.problems[j.key]
				if pr and pr.state == "new" then
					if d.cash >= pr.repair then
						d.cash -= pr.repair
						d.problems[j.key] = nil
						F.problemVisual(plr, j.key, false)
						F.refreshWorkers(plr)
						m.handled = (tonumber(m.handled) or 0) + 1
						notify(plr, "📋 Your manager fixed the problem at " .. F.bizName(d, j.key) .. " (-$" .. fmt(pr.repair) .. ").")
					else
						pr.manager = nil
						notify(plr, "📋 Your manager couldn't afford the repair at " .. F.bizName(d, j.key) .. " ($" .. fmt(pr.repair) .. ").")
					end
				end
			elseif j.kind == "restock" and F.restock then
				local ok, cost = F.restock(plr, j.key, "manager")
				if ok then
					m.handled = (tonumber(m.handled) or 0) + 1
					notify(plr, "📋 Your manager restocked " .. F.bizName(d, j.key) .. " (-$" .. fmt(cost) .. ").")
				end
			end
		end
	end
end
task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(1)
		local now = os.clock()
		local dt = now - last
		last = now
		for plr, d in pairs(data) do
			local ok, err = pcall(step, plr, d, dt, now)
			if not ok then warn("[CornerEmpire] manager: " .. tostring(err)) end
		end
	end
end)
function F.managerInfo(plr)
	local d = data[plr]
	local s = d.staff and d.staff.manager
	local lvl = F.managerLevel(d)
	local m = mgrOf(d)
	local working = {}
	for _, j in ipairs(jobs[plr] or {}) do
		table.insert(working, {biz = F.bizName(d, j.key), kind = j.kind, left = j.started and math.max(0, math.ceil(j.wait - (os.clock() - j.started))) or nil})
	end
	return {hired = s ~= nil, name = s and s.name, level = lvl, hq = F.hqLevel(d), left = math.ceil(m.left), auto = m.auto == true, handled = m.handled or 0,
		minutes = lvl > 0 and M.minutes[lvl] or M.minutes[1], cost = F.contractCost(d), repair = lvl > 0 and M.repairSeconds[lvl] or nil,
		parallel = lvl > 0 and M.parallel[lvl] or 1, advanced = lvl >= 5, jobs = working}
end
Players.PlayerRemoving:Connect(function(plr)
	jobs[plr], activeAt[plr], autoInRow[plr] = nil, nil, nil
end)

-- =====================================================================
-- ACTIONS
-- =====================================================================
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.hqBuy = function(plr) F.buyHQFloor(plr) end
C.ACTIONS.hqInfo = function(plr) R.Menu:FireClient(plr, "hq", F.hqInfo(plr)) end
C.ACTIONS.hqEnter = function(plr, d)
	if F.hqLevel(d) >= 1 then F.enterInterior(plr, plr, "hq1") else R.Menu:FireClient(plr, "hq", F.hqInfo(plr)) end
end
C.ACTIONS.hqFloor = function(plr, d, a, b)
	-- move between floors of an HQ you're standing in (yours, or one you're allowed into)
	local n = C.int(a, 1, #C.HQ_FLOORS)
	local owner = C.int(b, 1) and Players:GetPlayerByUserId(b)
	if not (n and owner and data[owner]) then return end
	local inside = plr:GetAttribute("InteriorOwner") == owner.UserId and string.match(tostring(plr:GetAttribute("Interior")), "^hq%d$")
	if inside then F.enterInterior(plr, owner, "hq" .. n) end
end
C.ACTIONS.mgrSign = function(plr) F.signContract(plr, false) end
C.ACTIONS.mgrAuto = function(plr, d, a) F.setAutoRenew(plr, a == true) end
C.ACTIONS.mgrInfo = function(plr) R.Menu:FireClient(plr, "manager", F.managerInfo(plr)) end
end
