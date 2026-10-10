-- HEISTS (v11): robberies, the police, and the long drive home.
--
-- THE LOOP: a robbery opportunity opens somewhere in the city → a crew (1-4 players who found the mountain HQ)
-- starts it → crack the security (a short puzzle) → the vault opens (mind the lasers) → grab loot into your BAG →
-- the ALARM goes off and police get an alert → get out → drive the loot back to the mountain HQ → the Fence turns
-- it into cash. Getting the loot is half the job: it's only money once it's inside the mountain.
--
-- RULES (all on the server; clients only ask):
--   * loot is never cash until it's turned in at the base, and it's never saved: leaving, dying, being arrested,
--     abandoning or waiting too long loses it. Nothing else you own is ever touched.
--   * every grab is checked: you're in that robbery, at that station, at the right stage, with room in your bag,
--     the station still has loot. Puzzles are generated and checked here; timing puzzles are timed here.
--   * a robbery's loot pool is fixed, so adding crew members never multiplies the money; each robber banks what
--     they carried (scaled by their own progress so it stays meaningful but never beats the business empire).
--   * police are NPC officers (v14, GameServer > Police): units respond to the alarm, search the APPROXIMATE area,
--     chase a robber only once they actually see them, and arrest a robber who is slow or stopped right next to a
--     unit. An arrest costs the loot, a modest fine (never more than a small part of your cash), a short time in a
--     cell and a cooldown before the next job. Players no longer go on police duty.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local P, surfaceText, billboard = C.P, C.surfaceText, C.billboard
local fmt, notify = C.fmt, C.notify
local MC = C.MOUNTAIN
local SOLID = {CanCollide = true}

C.HEIST = {
	unlockTier = 3,                       -- HOTSPOT
	firstOpen = 90, gapMin = 150, gapMax = 260,   -- seconds between new opportunities
	window = 180,                         -- an opportunity stays open this long (a robbery in progress keeps going)
	maxOpen = 2,
	siteRadius = 70,                      -- leaving this far from the target = you're escaping
	hotSeconds = 600,                     -- loot that isn't home 10 minutes after the alarm is too hot: it's lost
	playerCooldown = 300,                 -- per target, after you robbed it
	tierMult = {1, 2, 15, 60, 220, 700},  -- loot value scales with your reputation tier
	bags = {
		{name = "Basic Bag", cap = 5000, cost = 0},
		{name = "Reinforced Bag", cap = 10000, cost = 25000},
		{name = "Heavy Duty Bag", cap = 20000, cost = 500000},
		{name = "Elite Bag", cap = 35000, cost = 10000000},
	},
	base = {
		{name = "Hideout", cost = 0, perk = "Job board, the Fence, the Quartermaster"},
		{name = "Garage Level", cost = 100000, perk = "Use the Escape Garage terminal"},
		{name = "Command Center", cost = 1000000, perk = "Police scanner: see what the city's patrol cars are doing"},
		{name = "Storage Vaults", cost = 10000000, perk = "+10% bag capacity"},
		{name = "Luxury Lair", cost = 100000000, perk = "The Fence pays +5%"},
		{name = "Underground Empire", cost = 1000000000, perk = "The Fence pays +10% and a gold bag"},
	},
	-- v14 NPC police. speed: studs/s per state (a sports car can outrun them on a straight; on foot you can't)
	police = {jail = 20, cooldown = 120, fineCash = 0.02, fineLoot = 0.25, units = 2, perAlert = 2, maxUnits = 6,
		detect = 70, lose = 170, loseTime = 5, direct = 60, arrestRange = 9, arrestSlow = 14, arrestHold = 1.5,
		searchTime = 70, patrolRadius = 320, idleRemove = 60, speed = {patrol = 22, respond = 48, search = 30, pursue = 58}},
	puzzleSeconds = 25,
}
local HC = C.HEIST
-- base values (multiplied by each robber's tier multiplier). game = the security puzzle; panels = how many to crack
C.HEIST_SITES = {
	{key = "bank", name = "Corner Bank", icon = "🏦", pos = V3(740, 0, 0), yaw = math.pi / 2, color = RGB(60, 120, 90), pool = 15000, grab = 1250, stations = 6,
		game = "keypad", panels = 1, lasers = true, minP = 1, maxP = 4, alert = "HIGH", cooldown = 600, area = "Main St East",
		open = "BANK ROBBERY AVAILABLE — the security window is vulnerable for 3 minutes."},
	{key = "jewelry", name = "Gem & Gold Jewelers", icon = "💎", pos = V3(-740, 0, 0), yaw = -math.pi / 2, color = RGB(150, 70, 160), pool = 9000, grab = 900, stations = 5,
		game = "symbols", panels = 1, lasers = true, minP = 1, maxP = 3, alert = "MEDIUM", cooldown = 420, area = "Main St West",
		open = "JEWELRY STORE SECURITY FAILURE — crew needed immediately."},
	{key = "warehouse", name = "Luxury Warehouse", icon = "📦", pos = V3(-740, 0, -300), yaw = -math.pi / 2, color = RGB(140, 110, 70), pool = 12000, grab = 1000, stations = 6,
		game = "wires", panels = 1, lasers = false, minP = 1, maxP = 4, alert = "MEDIUM", cooldown = 480, area = "North Rd West",
		open = "LUXURY WAREHOUSE — designer goods just arrived and the guards are on break."},
	{key = "electronics", name = "Volt Electronics Depot", icon = "🔌", pos = V3(740, 0, -300), yaw = math.pi / 2, color = RGB(60, 110, 200), pool = 8000, grab = 800, stations = 5,
		game = "timing", panels = 1, lasers = false, minP = 1, maxP = 3, alert = "LOW", cooldown = 360, area = "North Rd East",
		open = "ELECTRONICS DEPOT — a power glitch knocked out the alarms."},
	{key = "cargo", name = "Northside Cargo Yard", icon = "🚢", pos = V3(-560, 0, -740), yaw = math.pi, color = RGB(200, 120, 40), pool = 14000, grab = 1400, stations = 6,
		game = "timing", panels = 1, lasers = false, minP = 1, maxP = 4, alert = "MEDIUM", cooldown = 540, area = "the north-west yards",
		open = "CARGO YARD OPPORTUNITY — high-value shipment detected."},
	{key = "museum", name = "City History Museum", icon = "🏛️", pos = V3(-180, 0, -740), yaw = math.pi, color = RGB(190, 180, 150), pool = 20000, grab = 2000, stations = 6,
		game = "symbols", panels = 2, lasers = true, minP = 2, maxP = 4, alert = "HIGH", cooldown = 720, area = "the north museum",
		open = "MUSEUM NIGHT — a golden exhibit is on display. Needs a crew of 2+."},
	{key = "vault", name = "City Vault", icon = "🔐", pos = V3(740, 0, 300), yaw = math.pi / 2, color = RGB(90, 90, 100), pool = 30000, grab = 2500, stations = 8,
		game = "keypad", panels = 2, lasers = true, minP = 1, maxP = 4, alert = "EXTREME", cooldown = 900, area = "the east shore",
		open = "CITY VAULT — a maintenance window opened. This one is hard."},
	{key = "carlot", name = "Prestige Car Garage", icon = "🏎️", pos = V3(720, 0, -700), yaw = math.pi, color = RGB(180, 40, 50), pool = 16000, grab = 1600, stations = 5,
		game = "wires", panels = 1, lasers = true, minP = 1, maxP = 4, alert = "HIGH", cooldown = 600, area = "the north-east garages",
		open = "PRESTIGE GARAGE — the key cabinet is unguarded for a few minutes."},
}
C.HEIST_SITE = {}
for _, s in ipairs(C.HEIST_SITES) do C.HEIST_SITE[s.key] = s end
local SITES = C.HEIST_SITES

-- =====================================================================
-- PLAYER RECORD + HELPERS
-- =====================================================================
local function rec(d)
	d.heist = type(d.heist) == "table" and d.heist or {}
	local h = d.heist
	for k, v in pairs({done = 0, failed = 0, earned = 0, best = 0, bag = 1, base = 1, arrests = 0, policeEarned = 0}) do
		if type(h[k]) ~= "number" or h[k] ~= h[k] or h[k] < 0 then h[k] = v end
	end
	h.bag = math.clamp(math.floor(h.bag), 1, #HC.bags)
	h.base = math.clamp(math.floor(h.base), 1, #HC.base)
	h.discovered = h.discovered == true
	return h
end
F.heistRecord = rec
local function mult(d) return HC.tierMult[math.clamp(F.tierIndex(d.rep), 1, #HC.tierMult)] or 1 end
local function bagCap(d)
	local h = rec(d)
	return math.floor(HC.bags[h.bag].cap * (h.base >= 4 and 1.1 or 1))
end
local function fenceBonus(d)
	local b = rec(d).base
	return b >= 6 and 1.1 or (b >= 5 and 1.05 or 1)
end
local function rootOf(p) return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function near(p, pos, dist)
	local r = rootOf(p)
	return r ~= nil and (r.Position - pos).Magnitude <= dist
end
local function districtName(pos)
	local best, bd = "the city", 1e9
	for _, dist in ipairs(C.DISTRICTS) do
		local sx, sz, n = 0, 0, 0
		for _, lot in ipairs(C.LOTS) do if lot.dkey == dist.key then sx += lot.pos.X sz += lot.pos.Z n += 1 end end
		if n > 0 then
			local dd = (V3(sx / n, 0, sz / n) - V3(pos.X, 0, pos.Z)).Magnitude
			if dd < bd then best, bd = dist.name, dd end
		end
	end
	if MC and (V3(pos.X, 0, pos.Z) - V3(MC.center.X, 0, MC.center.Z)).Magnitude < 260 then return "the mountain district" end
	if bd > 260 then
		if pos.Z < -600 then return "the northern outskirts" end
		if pos.X > 620 then return "the east edge of town" end
		if pos.X < -620 then return "the west edge of town" end
	end
	return best
end
C.heistDistrictName = districtName

-- =====================================================================
-- STATE
-- =====================================================================
local siteState = {}      -- [key] = {open = false, closesAt, cooldownUntil, heist = H or nil, model, stations, lasers, vaultDoor, sign}
local robbers = {}        -- [plr] = {heist = H, bag = base units, cap, escaped, alarmAt, at}
local police = {}         -- (v14: always empty: police are NPCs now; kept so old references stay harmless)
local arrestedAt = {}     -- [plr] = when the NPC police last arrested them (job cooldown)
local jailed = {}         -- [plr] = until
local lastRob = {}        -- [plr] = {[site] = os.clock()}
local invites = {}        -- [plr] = {from = plr, site, at}
local alerts = {}         -- list of {site, text, pos, radius, t}
local G = {nextOpen = os.clock() + HC.firstOpen, opened = 0, completed = 0, arrests = 0}
C.HEIST_STATE = {sites = siteState, robbers = robbers, police = police, G = G}

-- v14: alarms go to the NPC police dispatcher (GameServer > Police)
local function broadcastPolice(payload)
	if C.policeDispatch then C.policeDispatch(payload) end
end
local function pushState(plr)
	if plr.Parent and F.heistState then R.Menu:FireClient(plr, "heist", F.heistState(plr)) end
end
local function setBagVisual(plr, on, gold)
	local char = plr.Character
	if not char then return end
	local old = char:FindFirstChild("RobberyBag")
	if old then old:Destroy() end
	if not on then return end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not torso then return end
	local bag = Instance.new("Part")
	bag.Name = "RobberyBag"
	bag.Size = V3(1.8, 2, 1)
	bag.Color = gold and RGB(255, 200, 60) or RGB(60, 50, 40)
	bag.Material = MAT.Fabric
	bag.CanCollide, bag.CanQuery, bag.Massless = false, false, true
	bag.CFrame = torso.CFrame * CF(0, 0, 1.1)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = torso, bag
	w.Parent = bag
	bag.Parent = char
end
-- the arrest prompt every robber with loot carries (clients only show it to police)
-- (v14: NPC police arrest on the server, so robbers no longer carry an [Arrest] prompt; this just cleans up one
-- left over from an older server)
local function setArrestPrompt(plr)
	local root = rootOf(plr)
	local old = root and root:FindFirstChild("ArrestPrompt")
	if old then old:Destroy() end
end

-- ending a robbery for one robber: lost loot never becomes money anywhere
local function dropRobber(plr, why, countFail)
	local r = robbers[plr]
	if not r then return end
	robbers[plr] = nil
	local H = r.heist
	if H then
		for i = #H.crew, 1, -1 do if H.crew[i] == plr then table.remove(H.crew, i) end end
	end
	if plr.Parent then
		setBagVisual(plr, false)
		setArrestPrompt(plr, false)
		plr:SetAttribute("Robber", nil)
		if why then notify(plr, why) end
		local d = data[plr]
		if d and countFail and r.bag > 0 then rec(d).failed += 1 end
		R.Menu:FireClient(plr, "heist", {active = false, ended = why})
	end
	-- the last robber gone: the target resets
	if H and #H.crew == 0 then F.heistFinishSite(H.site.key) end
end
F.heistDrop = dropRobber

-- =====================================================================
-- THE TARGETS (buildings)
-- =====================================================================
local FOLDER = Instance.new("Folder")
FOLDER.Name = "HeistSites"
FOLDER.Parent = C.WORLD
local function buildSite(s)
	local st = {open = false, closesAt = 0, cooldownUntil = 0, stations = {}, lasers = {}, panels = {}}
	siteState[s.key] = st
	local m = Instance.new("Model")
	m.Name = "Heist_" .. s.key
	m.Parent = FOLDER
	st.model = m
	local o = CF(s.pos) * CFrame.Angles(0, s.yaw, 0)
	st.origin = o
	C.reserve(s.pos.X - 30, s.pos.Z - 30, s.pos.X + 30, s.pos.Z + 30)
	local W, D, Hh = 40, 44, 16
	local wall, trim = RGB(225, 222, 214), s.color
	local outdoor = s.key == "cargo"
	P(m, V3(W + 10, 0.4, D + 10), o * CF(0, 0.2, 0), RGB(90, 90, 94), MAT.Concrete, SOLID)
	local function box(size, cf, color, mat, props) return P(m, size, o * cf, color, mat or MAT.SmoothPlastic, props or SOLID) end
	if outdoor then
		-- a fenced yard with containers
		for _, sx in ipairs({-1, 1}) do box(V3(0.4, 8, D), CF(sx * W / 2, 4, 0), RGB(150, 150, 155), MAT.DiamondPlate) end
		box(V3(W, 8, 0.4), CF(0, 4, D / 2), RGB(150, 150, 155), MAT.DiamondPlate)
		for _, x in ipairs({-W / 2 + 6, W / 2 - 6}) do box(V3(12, 8, 0.4), CF(x, 4, -D / 2), RGB(150, 150, 155), MAT.DiamondPlate) end
		for i = 0, 3 do
			box(V3(10, 9, 22), CF(-15 + i * 10, 4.5, 8), Color3.fromHSV(i * 0.23 % 1, 0.6, 0.7), MAT.CorrugatedSteel)
		end
	else
		box(V3(W, 1, D), CF(0, Hh, 0), RGB(70, 70, 76))
		box(V3(0.8, Hh, D), CF(-W / 2, Hh / 2, 0), wall, MAT.Concrete)
		box(V3(0.8, Hh, D), CF(W / 2, Hh / 2, 0), wall, MAT.Concrete)
		box(V3(W, Hh, 0.8), CF(0, Hh / 2, D / 2), wall, MAT.Concrete)
		-- front with a doorway
		box(V3(W / 2 - 5, Hh, 0.8), CF(-W / 4 - 2.5, Hh / 2, -D / 2), wall, MAT.Concrete)
		box(V3(W / 2 - 5, Hh, 0.8), CF(W / 4 + 2.5, Hh / 2, -D / 2), wall, MAT.Concrete)
		box(V3(10, Hh - 9, 0.8), CF(0, Hh - (Hh - 9) / 2, -D / 2), wall, MAT.Concrete)
		-- partition between lobby and vault, with the vault door
		box(V3(W / 2 - 5, Hh, 0.8), CF(-W / 4 - 2.5, Hh / 2, 2), RGB(120, 120, 128), MAT.Metal)
		box(V3(W / 2 - 5, Hh, 0.8), CF(W / 4 + 2.5, Hh / 2, 2), RGB(120, 120, 128), MAT.Metal)
		box(V3(10, Hh - 9, 0.8), CF(0, Hh - (Hh - 9) / 2, 2), RGB(120, 120, 128), MAT.Metal)
		st.vaultClosed = o * CF(0, 4.5, 2)
		st.vaultOpen = o * CF(9.5, 4.5, 2)
		st.vaultDoor = P(m, V3(10, 9, 1.4), st.vaultClosed, RGB(160, 160, 170), MAT.DiamondPlate, SOLID)
		local wheel = C.cyl(m, 1.2, 4, st.vaultClosed * CF(0, 0, -0.9) * CFrame.Angles(math.pi / 2, 0, 0), RGB(200, 180, 90), MAT.Metal)
		local ww = Instance.new("WeldConstraint")
		ww.Part0, ww.Part1 = st.vaultDoor, wheel
		ww.Parent = wheel
		wheel.Anchored = false
	end
	-- the sign over the entrance + a status board
	local sg = box(V3(24, 3.4, 0.6), CF(0, Hh + 2.4, -D / 2 - 0.4), trim)
	surfaceText(sg, Enum.NormalId.Front, s.icon .. " " .. string.upper(s.name), RGB(255, 255, 255))
	local board = box(V3(6, 4, 0.4), CF(-W / 2 + 4, 3, -D / 2 - 3), RGB(20, 20, 26))
	st.sign = billboard(board, UDim2.fromOffset(220, 60), V3(0, 4, 0), {{text = s.icon .. " " .. s.name, h = 0.5}, {text = "CLOSED", h = 0.5, color = RGB(200, 200, 210), font = Enum.Font.GothamBold}}, 260)
	st.signLabel = st.sign and st.sign:FindFirstChild("L2", true)
	-- start / join
	local starter = box(V3(2, 4, 2), CF(W / 2 - 4, 2, -D / 2 - 3), RGB(40, 40, 46), MAT.Metal)
	st.startPrompt = C.prompt(starter, "Start robbery", s.name, 10, 0.8, function(plr) F.heistStart(plr, s.key) end)
	st.entrance = (o * CF(0, 3, -D / 2 - 4)).Position
	-- security panels in the lobby
	for i = 1, s.panels do
		local x = (i == 1 and -1 or 1) * (W / 2 - 3)
		local panel = box(V3(0.6, 3, 2.4), CF(x, 4, -10), RGB(30, 34, 44), MAT.Metal)
		P(m, V3(0.2, 1.4, 1.6), o * CF(x + (x < 0 and 0.4 or -0.4), 4.6, -10), RGB(80, 220, 255), MAT.Neon)
		table.insert(st.panels, {part = panel, solved = false, pos = (o * CF(x, 4, -10)).Position})
		C.prompt(panel, "Hack security", "Security panel " .. i, 8, 0.4, function(plr) F.heistPanel(plr, s.key, i) end)
	end
	-- lasers between the vault door and the loot (they cycle on and off once the vault is open)
	if s.lasers then
		for k = 0, 1 do
			local lz = 6 + k * 5
			local beam = P(m, V3(W - 2, 0.25, 0.25), o * CF(0, 1.8 + k * 1.6, lz), RGB(255, 40, 40), MAT.Neon, {Transparency = 1, CanCollide = false})
			table.insert(st.lasers, {part = beam, z = lz, on = false})
		end
	end
	-- loot stations in the vault
	for i = 1, s.stations do
		local x = -W / 2 + 4 + (i - 1) * ((W - 8) / math.max(1, s.stations - 1))
		local z = outdoor and (i % 2 == 0 and 14 or -6) or (D / 2 - 4)
		local stn = box(V3(3, 3, 2.4), CF(x, 1.5, z), outdoor and RGB(120, 90, 60) or RGB(200, 180, 90), outdoor and MAT.WoodPlanks or MAT.Metal)
		local cash = P(m, V3(2.4, 1, 1.8), o * CF(x, 3.5, z), RGB(90, 200, 110), MAT.SmoothPlastic)
		local entry = {part = stn, cash = cash, left = 0, pos = (o * CF(x, 2, z)).Position}
		table.insert(st.stations, entry)
		C.prompt(stn, "Grab loot", s.name, 8, 1.2, function(plr) F.heistGrab(plr, s.key, i) end)
	end
	st.center = (o * CF(0, 2, 0)).Position
	return st
end
-- v11.2: the targets sit near the edge of the map, where the terrain's random edge hills are: clear the hills out of
-- each target's lot and its way in (in v11 they could half-bury a building in Studio)
for _, s in ipairs(SITES) do
	local x, z = s.pos.X, s.pos.Z
	C.clearTerrain(x - 42, z - 42, x + 42, z + 42, 70)
	if math.abs(x) > 600 then
		-- east / west edge: a lane back towards the city
		local inner = x > 0 and 640 or -640
		C.clearTerrain(math.min(inner, x), z - 12, math.max(inner, x), z + 12, 50)
	else
		-- north edge: a lane south, out of the hills
		C.clearTerrain(x - 12, z, x + 12, -550, 50)
	end
end
for _, s in ipairs(SITES) do buildSite(s) end
-- simple access driveways out to where the roads end
P(FOLDER, V3(90, 0.2, 12), CF(695, 0.12, 0), RGB(52, 54, 60), MAT.Asphalt)
P(FOLDER, V3(90, 0.2, 12), CF(-695, 0.12, 0), RGB(52, 54, 60), MAT.Asphalt)
P(FOLDER, V3(90, 0.2, 12), CF(695, 0.12, -300), RGB(52, 54, 60), MAT.Asphalt)
P(FOLDER, V3(90, 0.2, 12), CF(-695, 0.12, -300), RGB(52, 54, 60), MAT.Asphalt)

-- the police station (go on duty here; the cells are where arrested robbers wait)
local STATION
do
	local at = V3(-140, 0, -240)
	C.reserve(at.X - 26, at.Z - 26, at.X + 26, at.Z + 26)
	local m = Instance.new("Model")
	m.Name = "PoliceStation"
	m.Parent = FOLDER
	P(m, V3(44, 0.4, 40), CF(at + V3(0, 0.2, 0)), RGB(90, 90, 94), MAT.Concrete, SOLID)
	P(m, V3(30, 12, 0.8), CF(at + V3(0, 6, 14)), RGB(40, 60, 110), MAT.SmoothPlastic, SOLID)
	for _, sx in ipairs({-1, 1}) do P(m, V3(0.8, 12, 28), CF(at + V3(sx * 15, 6, 0)), RGB(40, 60, 110), MAT.SmoothPlastic, SOLID) end
	P(m, V3(31, 1, 29), CF(at + V3(0, 12.5, 0)), RGB(30, 40, 70), MAT.SmoothPlastic, SOLID)
	local sign = P(m, V3(20, 3, 0.5), CF(at + V3(0, 14.5, -14)), RGB(20, 30, 60))
	surfaceText(sign, Enum.NormalId.Front, "🚓 CITY POLICE", RGB(255, 255, 255))
	local desk = P(m, V3(6, 3.4, 2), CF(at + V3(-6, 1.7, -8)), RGB(40, 60, 110), MAT.Metal, SOLID)
	C.prompt(desk, "Ask the desk", "City Police", 10, 0.4, function(plr)
		local st = C.policeStatus and C.policeStatus() or {total = 0}
		C.notify(plr, "🚓 \"" .. st.total .. " units on the street. " .. ((st.pursue or 0) > 0 and "One's in a chase right now." or "Quiet day.") .. "\"")
	end)
	-- the cells (bars), behind the desk
	for i = 0, 3 do
		local cx = at.X - 9 + i * 6
		for k = 0, 4 do P(m, V3(0.2, 8, 0.2), CF(cx - 2 + k, 4, at.Z + 6), RGB(70, 70, 76), MAT.Metal, SOLID) end
	end
	STATION = {pos = at, cells = {}, release = CF(at + V3(0, 3, -24))}
	for i = 0, 3 do STATION.cells[i + 1] = CF(at.X - 9 + i * 6, 3, at.Z + 10) end
	C.POLICE_STATION = STATION
end

-- =====================================================================
-- OPPORTUNITIES (rotation)
-- =====================================================================
local function setSign(st, text, color)
	if st.signLabel then
		st.signLabel.Text = text
		st.signLabel.TextColor3 = color
	end
end
function F.heistOpen(key)
	local s, st = C.HEIST_SITE[key], siteState[key]
	if not (s and st) or st.open or st.heist then return false end
	st.open = true
	st.closesAt = os.clock() + HC.window
	G.opened += 1
	setSign(st, "OPEN — " .. math.floor(HC.window / 60) .. " min", RGB(120, 255, 150))
	-- only people who can actually do something about it hear about it
	for _, p in ipairs(Players:GetPlayers()) do
		local d = data[p]
		if d and (police[p] or rec(d).discovered) then
			R.Splash:FireClient(p, "💰 ROBBERY OPPORTUNITY", s.icon .. " " .. s.open, s.color)
		end
	end
	if F.guideTipAll then F.guideTipAll("robberyJobs") end
	return true
end
function F.heistFinishSite(key)
	local st = siteState[key]
	if not st then return end
	local s = C.HEIST_SITE[key]
	st.heist = nil
	st.open = false
	st.cooldownUntil = os.clock() + s.cooldown
	for _, p in ipairs(st.panels) do p.solved = false end
	for _, l in ipairs(st.lasers) do l.on = false l.part.Transparency = 1 end
	if st.vaultDoor then st.vaultDoor.CFrame = st.vaultClosed end
	for _, stn in ipairs(st.stations) do stn.left = 0 stn.cash.Transparency = 0 end
	setSign(st, "CLOSED", RGB(200, 200, 210))
	for i = #alerts, 1, -1 do if alerts[i].site == key then table.remove(alerts, i) end end
end
local function siteCount(pred)
	local n = 0
	for _, st in pairs(siteState) do if pred(st) then n += 1 end end
	return n
end

-- =====================================================================
-- STARTING / JOINING
-- =====================================================================
function F.heistCanStart(plr, key)
	local d = data[plr]
	local s, st = C.HEIST_SITE[key], siteState[key]
	if not (d and s and st) then return false, "?" end
	local h = rec(d)
	if not h.discovered then return false, "Word is, jobs come from somewhere in the mountains up north. Find the hideout first." end
	if F.tierIndex(d.rep) < HC.unlockTier then return false, "Heists unlock at " .. C.REP_TIERS[HC.unlockTier].name .. " reputation." end
	if jailed[plr] then return false, "You're in a cell." end
	if arrestedAt[plr] and os.clock() - arrestedAt[plr] < HC.police.cooldown then
		return false, "Lie low for a bit: the police know your face. (" .. math.ceil(HC.police.cooldown - (os.clock() - arrestedAt[plr])) .. " s)"
	end
	if robbers[plr] then return false, "Finish your current job first." end
	local last = lastRob[plr] and lastRob[plr][key]
	if last and os.clock() - last < HC.playerCooldown then return false, "This place is still on alert. Try again in " .. math.ceil((HC.playerCooldown - (os.clock() - last)) / 60) .. " min." end
	if not near(plr, st.entrance, 14) then return false, "Get to the entrance." end
	if st.heist then
		local H = st.heist
		if #H.crew >= s.maxP then return false, "This crew is full." end
		if H.stage == "alarm" or H.stage == "escape" then return false, "Too late: the alarm's going." end
		return true, "join"
	end
	if not st.open then return false, "Not now: this place isn't vulnerable yet. Watch the Heists app." end
	return true, "start"
end
function F.heistStart(plr, key)
	local ok, how = F.heistCanStart(plr, key)
	if not ok then notify(plr, "💰 " .. tostring(how)) return false end
	local d = data[plr]
	local s, st = C.HEIST_SITE[key], siteState[key]
	local H = st.heist
	if not H then
		local pool = s.pool
		H = {site = s, crew = {}, stage = "security", started = os.clock(), heat = 0, pool = pool, grabbed = 0, puzzles = {}}
		st.heist = H
		for i, stn in ipairs(st.stations) do stn.left = math.floor(pool / s.stations) stn.cash.Transparency = 0 end
		setSign(st, "ROBBERY IN PROGRESS", RGB(255, 90, 90))
	end
	table.insert(H.crew, plr)
	robbers[plr] = {heist = H, bag = 0, cap = bagCap(d), escaped = false, mult = mult(d)}
	lastRob[plr] = lastRob[plr] or {}
	lastRob[plr][key] = os.clock()
	plr:SetAttribute("Robber", key)
	setBagVisual(plr, true, rec(d).base >= 6)
	for _, mate in ipairs(H.crew) do if mate ~= plr then notify(mate, "🤝 " .. plr.Name .. " joined the crew.") end end
	notify(plr, how == "join" and ("🤝 You joined the " .. s.name .. " job.") or ("💰 " .. s.name .. ": crack the security panel" .. (s.panels > 1 and "s" or "") .. " to open the vault."))
	if #H.crew < s.minP then notify(plr, "👥 This job needs " .. s.minP .. " people. Invite someone from the Heists app.") end
	if F.guideTip then F.guideTip(plr, "robberyBag") end
	pushState(plr)
	return true
end

-- =====================================================================
-- SECURITY PUZZLES (generated and checked here)
-- =====================================================================
local SYMBOLS = {
	keypad = {"1", "2", "3", "4", "5", "6", "7", "8", "9"},
	symbols = {"⭐", "🔺", "🟦", "🌙", "❤️", "⚡", "🍀", "💠"},
	wires = {"🔴", "🟢", "🔵", "🟡", "🟣", "⚪"},
}
function F.heistPanel(plr, key, i)
	local r = robbers[plr]
	local s, st = C.HEIST_SITE[key], siteState[key]
	if not (r and r.heist and st and r.heist == st.heist) then notify(plr, "💰 Start the robbery first (the terminal by the entrance).") return false end
	local H = r.heist
	local panel = st.panels[i]
	if not panel or panel.solved or H.stage ~= "security" then return false end
	if not near(plr, panel.pos, 10) then return false end
	if #H.crew < s.minP then notify(plr, "👥 This job needs " .. s.minP .. " people.") return false end
	local puzzle = {kind = s.game, panel = i, site = key, expires = os.clock() + HC.puzzleSeconds}
	if s.game == "timing" then
		puzzle.speed = 1.4 + math.random() * 0.8
		puzzle.center = 0.2 + math.random() * 0.6
		puzzle.start = os.clock()
		puzzle.hits = 0
		puzzle.need = 3
	else
		local pool = SYMBOLS[s.game]
		local len = s.game == "keypad" and 5 or 4
		puzzle.seq = {}
		for k = 1, len do puzzle.seq[k] = pool[math.random(#pool)] end
		puzzle.options = pool
	end
	H.puzzles[plr] = puzzle
	R.Menu:FireClient(plr, "heistPuzzle", {kind = puzzle.kind, seq = puzzle.seq, options = puzzle.options, speed = puzzle.speed, center = puzzle.center,
		need = puzzle.need, seconds = HC.puzzleSeconds, site = s.name})
	return true
end
local function panelSolved(plr, H, puzzle)
	local st = siteState[H.site.key]
	st.panels[puzzle.panel].solved = true
	H.puzzles[plr] = nil
	for _, p in ipairs(st.panels) do if not p.solved then
		for _, mate in ipairs(H.crew) do notify(mate, "🔓 One panel down. " .. "Crack the other one!") end
		return
	end end
	H.stage = "vault"
	if st.vaultDoor then
		task.spawn(function()
			local from = st.vaultDoor.CFrame
			for k = 1, 20 do st.vaultDoor.CFrame = from:Lerp(st.vaultOpen, k / 20) task.wait(0.05) end
		end)
	end
	for _, mate in ipairs(H.crew) do
		R.Splash:FireClient(mate, "🔓 SECURITY DOWN", "The vault is open. Grab the loot" .. (#st.lasers > 0 and " — mind the lasers!" or "!"), RGB(120, 255, 150))
		pushState(mate)
		if F.guideTip then F.guideTip(mate, "collectLoot") end
	end
end
function F.heistSolve(plr, answer)
	local r = robbers[plr]
	local H = r and r.heist
	local puzzle = H and H.puzzles[plr]
	if not puzzle then return false end
	if os.clock() > puzzle.expires then
		H.puzzles[plr] = nil
		notify(plr, "⌛ Too slow — the panel reset. Try again.")
		return false
	end
	if puzzle.kind == "timing" then
		-- the client only says "now"; the server decides where the needle was
		local v = (math.sin((os.clock() - puzzle.start) * puzzle.speed * 2) + 1) / 2
		if math.abs(v - puzzle.center) < 0.09 then
			puzzle.hits += 1
			R.Menu:FireClient(plr, "heistPuzzleHit", {ok = true, hits = puzzle.hits, need = puzzle.need})
			if puzzle.hits >= puzzle.need then panelSolved(plr, H, puzzle) return true end
		else
			puzzle.hits = 0
			H.heat += 0.25
			R.Menu:FireClient(plr, "heistPuzzleHit", {ok = false, hits = 0, need = puzzle.need})
		end
		return false
	end
	if type(answer) ~= "table" or #answer ~= #puzzle.seq then return false end
	for k = 1, #puzzle.seq do
		if answer[k] ~= puzzle.seq[k] then
			H.puzzles[plr] = nil
			H.heat += 0.5
			notify(plr, "❌ Wrong sequence. The panel reset" .. (H.heat >= 1.5 and " — someone may have noticed..." or "."))
			R.Menu:FireClient(plr, "heistPuzzleHit", {ok = false, done = true})
			return false
		end
	end
	R.Menu:FireClient(plr, "heistPuzzleHit", {ok = true, done = true})
	panelSolved(plr, H, puzzle)
	return true
end

-- =====================================================================
-- LOOT + ALARM
-- =====================================================================
local function soundAlarm(H, why)
	if H.stage == "alarm" or H.stage == "escape" then return end
	H.stage = "alarm"
	H.alarmAt = os.clock()
	local s = H.site
	local st = siteState[s.key]
	setSign(st, "🚨 ALARM", RGB(255, 60, 60))
	for _, mate in ipairs(H.crew) do
		R.Splash:FireClient(mate, "🚨 " .. string.upper(s.name) .. " ALARM TRIGGERED", "Get out and RETURN TO THE MOUNTAIN HQ with the loot!", RGB(255, 80, 60))
		local r = robbers[mate]
		if r and not r.alarmAt then r.alarmAt = H.alarmAt end
		setArrestPrompt(mate, true)
		pushState(mate)
		if F.guideTip then F.guideTip(mate, "returnToMountain") end
	end
	local alert = {site = s.key, name = s.name, icon = s.icon, text = string.upper(s.name) .. " ROBBERY IN PROGRESS", area = s.area, pos = st.center, radius = 60, level = s.alert, t = os.clock()}
	table.insert(alerts, alert)
	broadcastPolice(alert)
	for _, p in ipairs(Players:GetPlayers()) do
		if not police[p] and not robbers[p] then notify(p, "🚨 " .. s.icon .. " " .. s.name .. " alarm! (" .. (why or "") .. ")") end
	end
	for _, mate in ipairs(H.crew) do if F.guideTip then F.guideTip(mate, "policeChase") end end
end
function F.heistGrab(plr, key, i)
	local r = robbers[plr]
	local st = siteState[key]
	if not (r and st and r.heist and r.heist == st.heist) then return false end
	local H = r.heist
	if H.stage == "security" or H.stage == "escape" then notify(plr, "🔒 The vault is still locked.") return false end
	local stn = st.stations[i]
	if not stn or not near(plr, stn.pos, 10) then return false end
	if stn.left <= 0 then notify(plr, "💸 Empty.") return false end
	local room = r.cap - r.bag
	if room <= 0 then notify(plr, "🎒 Your bag is full. Get out!") return false end
	local take = math.min(H.site.grab, room, stn.left)
	stn.left -= take
	r.bag += take
	H.grabbed += take
	if stn.left <= 0 then stn.cash.Transparency = 1 end
	if H.stage == "vault" then H.stage = "loot" end
	notify(plr, "💰 +$" .. fmt(take * r.mult) .. "  (bag $" .. fmt(r.bag * r.mult) .. " / $" .. fmt(r.cap * r.mult) .. ")")
	-- the alarm: enough taken, a full bag, or too much noise
	if H.grabbed >= H.pool * 0.4 or r.bag >= r.cap or H.heat >= 2 then soundAlarm(H, H.heat >= 2 and "sloppy work" or "loot taken") end
	pushState(plr)
	return true
end

-- =====================================================================
-- POLICE
-- =====================================================================
local switchedAt = {}
-- v14: police duty is gone (the police are NPCs); old clients asking for it get an explanation
function F.togglePolice(plr)
	C.notify(plr, "🚓 The city police are NPC officers now. Robbers: watch for patrol cars!")
	return false
end
-- an NPC unit arrests a robber: the loot is gone, a modest fine, a short time in a cell, a cooldown.
-- Nothing else the player owns is touched. (unit = the police unit from GameServer > Police)
function F.npcArrest(unit, target)
	local r = robbers[target]
	if not r or (r.bag <= 0 and not r.alarmAt) then return false end
	local b = rootOf(target)
	if not b then return false end
	local s = r.heist and r.heist.site
	local d = data[target]
	local value = r.bag * (r.mult or 1)
	local fine = 0
	if d then
		fine = math.floor(math.max(0, math.min(d.cash * HC.police.fineCash, value * HC.police.fineLoot)))
		d.cash -= fine
		rec(d).failed += 1
	end
	G.arrests += 1
	r.bag = 0
	local where = districtName(b.Position)
	dropRobber(target, "🚓 ARRESTED. The loot is gone" .. (fine > 0 and (" and you paid a $" .. fmt(fine) .. " fine") or "") .. " (everything else you own is safe).", false)
	F.despawnCar(target)
	if F.leaveInterior then F.leaveInterior(target) end
	jailed[target] = os.clock() + HC.police.jail
	arrestedAt[target] = os.clock()
	local cell = STATION.cells[(G.arrests % #STATION.cells) + 1]
	if target.Character then target.Character:PivotTo(cell) end
	R.Splash:FireClient(target, "🚓 BUSTED", "Out in " .. HC.police.jail .. " s. No new job for " .. math.floor(HC.police.cooldown / 60) .. " min.", RGB(80, 140, 255))
	if F.buzz then F.buzz("🚓", "City police caught a robbery crew near " .. where .. (s and (" after the " .. s.name .. " job") or "") .. "!", RGB(80, 140, 255)) end
	return true
end

-- =====================================================================
-- THE TURN-IN (only inside the mountain)
-- =====================================================================
function F.heistTurnIn(plr)
	local r = robbers[plr]
	local d = data[plr]
	if not (r and d) then return false end
	local root = rootOf(plr)
	if not (root and MC.inBase(root.Position)) then return false end
	if r.bag <= 0 then return false end
	-- clear the bag FIRST: a second call (or a double prompt) finds nothing
	local value = r.bag
	r.bag = 0
	local pay = math.floor(value * r.mult * fenceBonus(d))
	d.cash += pay
	d.earned += pay
	local h = rec(d)
	h.done += 1
	h.earned += pay
	h.best = math.max(h.best, pay)
	G.completed += 1
	local s = r.heist and r.heist.site
	dropRobber(plr, nil, false)
	R.Splash:FireClient(plr, "💰 THE FENCE PAID UP", "+$" .. fmt(pay) .. (s and (" from the " .. s.name .. " job") or ""), RGB(120, 255, 150))
	if s and F.buzz then
		local lines = {"BREAKING: " .. s.name .. " hit! A mystery crew escaped into the mountains.", "Mystery crew vanishes after the " .. s.name .. " job. Police baffled.",
			"Where did they go? " .. s.name .. " robbers lost somewhere north of the city."}
		F.buzz(s.icon, lines[math.random(#lines)], s.color)
	end
	if F.addRep then F.addRep(plr, 5) end
	return true
end
F.heistEnteredBase = function(plr) if robbers[plr] and robbers[plr].bag > 0 then F.heistTurnIn(plr) end end

-- =====================================================================
-- THE HEARTBEAT (once a second; only active robberies and police do any work)
-- =====================================================================
local nextUpdate = {}
local function step(now)
	-- rotation
	if now >= G.nextOpen and siteCount(function(st) return st.open or st.heist end) < HC.maxOpen then
		local pool = {}
		for _, s in ipairs(SITES) do
			local st = siteState[s.key]
			if not st.open and not st.heist and now >= st.cooldownUntil then table.insert(pool, s.key) end
		end
		if #pool > 0 then F.heistOpen(pool[math.random(#pool)]) end
		G.nextOpen = now + math.random(HC.gapMin, HC.gapMax)
	end
	for key, st in pairs(siteState) do
		local H = st.heist
		if st.open and not H and now > st.closesAt then F.heistFinishSite(key) st.cooldownUntil = now + 30 end
		if H then
			-- the window closed before anyone took anything: the job falls apart
			if (H.stage == "security" or H.stage == "vault") and now > st.closesAt + 60 then
				for _, mate in ipairs(table.clone(H.crew)) do dropRobber(mate, "⌛ The window closed. The job's off.", false) end
			end
			-- lasers cycle once the vault is open; standing in a live one makes noise
			if #st.lasers > 0 and H.stage ~= "security" then
				local on = math.floor(now / 2) % 2 == 0
				for _, l in ipairs(st.lasers) do
					l.on = on
					l.part.Transparency = on and 0.2 or 0.85
				end
				if on then
					for _, mate in ipairs(H.crew) do
						local root = rootOf(mate)
						if root then
							local lp = st.origin:PointToObjectSpace(root.Position)
							for _, l in ipairs(st.lasers) do
								if math.abs(lp.Z - l.z) < 1.2 and math.abs(lp.X) < 19 and lp.Y < 8 then
									H.heat += 1
									notify(mate, "🔴 You tripped a laser!")
									if H.heat >= 2 then soundAlarm(H, "lasers tripped") end
								end
							end
						end
					end
				end
			end
		end
	end
	-- robbers: escaping, too hot, police updates
	for plr, r in pairs(robbers) do
		local root = rootOf(plr)
		local H = r.heist
		if not plr.Parent then
			dropRobber(plr, nil, true)
		elseif not root then
			-- (no character = they died: handled by Died below)
		else
			local st = H and siteState[H.site.key]
			if st and not r.escaped and r.bag > 0 and (root.Position - st.center).Magnitude > HC.siteRadius then
				r.escaped = true
				if not r.alarmAt then soundAlarm(H, "robbers spotted leaving") end
				if H.stage == "alarm" then H.stage = "escape" end
				R.Splash:FireClient(plr, "🏃 RETURN TO MOUNTAIN HQ", "The loot only counts once it's inside the mountain.", RGB(255, 170, 60))
				pushState(plr)
			end
			if r.alarmAt and now - r.alarmAt > HC.hotSeconds and r.bag > 0 then
				r.bag = 0
				dropRobber(plr, "🔥 The loot got too hot to move. It's gone.", true)
			elseif r.escaped and (not nextUpdate[plr] or now >= nextUpdate[plr]) then
				-- escalating, APPROXIMATE information for the NPC police (an area, never the exact spot)
				nextUpdate[plr] = now + 15
				local pos = root.Position
				local off = V3(math.random(-60, 60), 0, math.random(-60, 60))
				if C.policeReport then C.policeReport(plr, pos + off, H.site.key) end
			end
		end
	end
	-- the jail
	for plr, untilT in pairs(jailed) do
		if not plr.Parent then jailed[plr] = nil
		elseif now >= untilT then
			jailed[plr] = nil
			if plr.Character then plr.Character:PivotTo(STATION.release) end
			notify(plr, "🚪 You're free to go. Stay out of trouble (or don't).")
		end
	end
end
task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(step, os.clock())
		if not ok then warn("[CornerEmpire] heists: " .. tostring(err)) end
	end
end)
-- dying or leaving loses the loot (never your money)
local function hook(plr)
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.Died:Connect(function()
				if robbers[plr] then
					robbers[plr].bag = 0
					dropRobber(plr, "💀 You went down. The loot is gone.", true)
				end
			end)
		end
	end)
end
Players.PlayerAdded:Connect(hook)
for _, p in ipairs(Players:GetPlayers()) do hook(p) end
Players.PlayerRemoving:Connect(function(plr)
	if robbers[plr] then
		robbers[plr].bag = 0
		dropRobber(plr, nil, false)
	end
	police[plr], jailed[plr], lastRob[plr], invites[plr], switchedAt[plr], nextUpdate[plr], arrestedAt[plr] = nil, nil, nil, nil, nil, nil, nil
end)

-- =====================================================================
-- THE MOUNTAIN'S STATIONS
-- =====================================================================
MC.onStation = function(plr, key)
	local d = data[plr]
	if not d then return end
	if key == "fence" then
		if robbers[plr] and robbers[plr].bag > 0 then F.heistTurnIn(plr) else notify(plr, "💰 \"Nothing to sell? Come back with a full bag.\"") end
	elseif key == "garage" then
		if rec(d).base < 2 then notify(plr, "🚗 The Escape Garage needs the base's Garage Level (Base Upgrades).") return end
		local key2 = d.garage and d.garage.equipped
		if not (key2 and C.CAR[key2] and F.ownsCar(plr, C.CAR[key2])) then
			key2 = nil
			for _, c in ipairs(C.CARS) do if F.ownsCar(plr, c) then key2 = c.key end end
		end
		if not key2 then notify(plr, "🚗 You don't own a car yet.") return end
		F.spawnCar(plr, key2, MC.garageCF)
	else
		-- (v11.2: the planning room and the computer asked for an "intel" tab the app doesn't have → an empty window)
		R.Menu:FireClient(plr, "heistApp", {tab = ({jobs = "jobs", quartermaster = "gear", base = "gear", planning = "jobs", computer = "police"})[key] or "jobs"})
		if F.guideTip then F.guideTip(plr, key == "jobs" and "robberyJobs" or "heistsApp") end
	end
end

-- =====================================================================
-- CREWS, GEAR, THE APP
-- =====================================================================
function F.heistInvite(plr, targetId)
	local r = robbers[plr]
	local target = Players:GetPlayerByUserId(targetId)
	if not (r and target and target ~= plr and data[target]) then return false end
	if police[target] then notify(plr, "🚓 They're a cop.") return false end
	invites[target] = {from = plr, site = r.heist.site.key, at = os.clock()}
	notify(target, "🤝 " .. plr.Name .. " wants you on the " .. r.heist.site.name .. " job! Head to the entrance and press Start robbery (Heists app has the details).")
	notify(plr, "🤝 Invited " .. target.Name .. ".")
	if F.guideTip then F.guideTip(target, "robberyTeam") end
	return true
end
function F.buyBag(plr, level)
	local d = data[plr]
	local bag = HC.bags[level]
	if not (d and bag) then return false end
	local h = rec(d)
	if not plr:GetAttribute("InBase") then notify(plr, "🎒 Talk to the Quartermaster inside the hideout.") return false end
	if h.bag >= level then return false end
	if level ~= h.bag + 1 then notify(plr, "🎒 Upgrade one step at a time.") return false end
	if d.cash < bag.cost then notify(plr, "🎒 The " .. bag.name .. " costs $" .. fmt(bag.cost) .. ".") return false end
	d.cash -= bag.cost
	h.bag = level
	notify(plr, "🎒 " .. bag.name .. " — holds $" .. fmt(bag.cap * mult(d)) .. " at your level.")
	return true
end
function F.buyBase(plr, level)
	local d = data[plr]
	local up = HC.base[level]
	if not (d and up) then return false end
	local h = rec(d)
	if not plr:GetAttribute("InBase") then notify(plr, "⛰️ Upgrade the base from inside it.") return false end
	if h.base >= level or level ~= h.base + 1 then return false end
	if d.cash < up.cost then notify(plr, "⛰️ " .. up.name .. " costs $" .. fmt(up.cost) .. ".") return false end
	d.cash -= up.cost
	h.base = level
	R.Splash:FireClient(plr, "⛰️ " .. string.upper(up.name), up.perk, RGB(255, 150, 60))
	return true
end
function F.heistState(plr)
	local d = data[plr]
	if not d then return {active = false} end
	local h = rec(d)
	local r = robbers[plr]
	local m = mult(d)
	local out = {active = r ~= nil, police = false, chase = C.policeChasing and C.policeChasing(plr) or false, discovered = h.discovered, tier = F.tierIndex(d.rep) >= HC.unlockTier, jailed = jailed[plr] and math.ceil(jailed[plr] - os.clock()) or nil}
	if r then
		local H = r.heist
		local st = H and siteState[H.site.key]
		local crew = {}
		for _, mate in ipairs(H and H.crew or {}) do table.insert(crew, mate.Name) end
		out.site = H and H.site.name
		out.icon = H and H.site.icon
		out.stage = H and H.stage
		out.bag, out.cap = r.bag * m, r.cap * m
		out.escaped = r.escaped
		out.crew = crew
		out.hot = r.alarmAt and math.max(0, math.ceil(HC.hotSeconds - (os.clock() - r.alarmAt))) or nil
		out.objective = (not H) and "" or (H.stage == "security" and ("Crack the security panel" .. (#(st and st.panels or {}) > 1 and "s" or "")))
			or ((H.stage == "vault" or H.stage == "loot") and "Grab the loot (watch your bag)")
			or (r.escaped and "RETURN TO MOUNTAIN HQ") or "Get out of the building!"
		out.home = r.escaped and MC.hqSpawn.Position or nil
	end
	return out
end
function F.heistApp(plr)
	local d = data[plr]
	local h = rec(d)
	local m = mult(d)
	local now = os.clock()
	local jobs = {}
	for _, s in ipairs(SITES) do
		local st = siteState[s.key]
		local status = st.heist and (st.heist.stage == "alarm" or st.heist.stage == "escape") and "ALARM" or (st.heist and "IN PROGRESS") or (st.open and "OPEN") or "CLOSED"
		local per = math.min(HC.bags[h.bag].cap, s.pool / math.max(1, s.minP))
		table.insert(jobs, {key = s.key, name = s.name, icon = s.icon, status = status, left = st.open and math.max(0, math.ceil(st.closesAt - now)) or nil,
			low = math.floor(s.grab * 2 * m), high = math.floor(per * m), minP = s.minP, maxP = s.maxP, alert = s.alert, area = s.area,
			crew = st.heist and #st.heist.crew or 0, cooldown = lastRob[plr] and lastRob[plr][s.key] and math.max(0, math.ceil(HC.playerCooldown - (now - lastRob[plr][s.key]))) or 0})
	end
	local bags = {}
	for i, b in ipairs(HC.bags) do table.insert(bags, {level = i, name = b.name, cap = b.cap * m, cost = b.cost, owned = h.bag >= i}) end
	local base = {}
	for i, b in ipairs(HC.base) do table.insert(base, {level = i, name = b.name, perk = b.perk, cost = b.cost, owned = h.base >= i}) end
	local crewInvite = {}
	if robbers[plr] then
		for _, p in ipairs(Players:GetPlayers()) do if p ~= plr and not police[p] and not robbers[p] then table.insert(crewInvite, {id = p.UserId, name = p.Name}) end end
	end
	-- robbery alarms are public news; the police units' work is shown as a status
	local news = {}
	for _, a in ipairs(alerts) do if os.clock() - (a.t or 0) < 600 then table.insert(news, {text = a.text, name = a.name, icon = a.icon, area = a.area}) end end
	return {state = F.heistState(plr), jobs = jobs, bags = bags, base = base, invite = crewInvite, inBase = plr:GetAttribute("InBase") == true,
		stats = {done = h.done, failed = h.failed, earned = h.earned, best = h.best, arrests = h.arrests, policeEarned = h.policeEarned},
		police = {npc = true, status = C.policeStatus and C.policeStatus() or nil, alerts = news, cooldown = arrestedAt[plr] and math.max(0, math.ceil(HC.police.cooldown - (os.clock() - arrestedAt[plr]))) or 0}, unlockTier = C.REP_TIERS[HC.unlockTier].name}
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.hsApp = function(plr) R.Menu:FireClient(plr, "heistAppData", F.heistApp(plr)) end
C.ACTIONS.hsSolve = function(plr, d, a)
	if a ~= nil and type(a) ~= "table" then return end
	if type(a) == "table" then
		if #a > 8 then return end
		for _, v in ipairs(a) do if not C.str(v, 8) then return end end
	end
	F.heistSolve(plr, a)
	pushState(plr)
end
C.ACTIONS.hsAbandon = function(plr)
	if robbers[plr] then
		robbers[plr].bag = 0
		dropRobber(plr, "🏳️ You walked away from the job. No loot, no money.", true)
	end
end
C.ACTIONS.hsInvite = function(plr, d, a) local id = C.int(a, 1) if id then F.heistInvite(plr, id) end end
C.ACTIONS.hsPolice = function(plr, d, a) F.togglePolice(plr, a == true) R.Menu:FireClient(plr, "heistAppData", F.heistApp(plr)) end
C.ACTIONS.hsBag = function(plr, d, a) local l = C.int(a, 1, #HC.bags) if l then F.buyBag(plr, l) end R.Menu:FireClient(plr, "heistAppData", F.heistApp(plr)) end
C.ACTIONS.hsBase = function(plr, d, a) local l = C.int(a, 1, #HC.base) if l then F.buyBase(plr, l) end R.Menu:FireClient(plr, "heistAppData", F.heistApp(plr)) end
C.ACTIONS.hsState = function(plr) pushState(plr) end
-- (the robbery state is light, so it's pushed every 2 s while you're on a job)
task.spawn(function()
	while true do
		task.wait(2)
		for plr in pairs(robbers) do pcall(pushState, plr) end
	end
end)

-- a rumor in CityBuzz now and then, for people who haven't found the base yet
task.spawn(function()
	local rumors = {"Hikers swear a drain pipe up north hums at night. 👀", "Anyone else see lights INSIDE the mountain north of the race track?",
		"My cousin says there's a lever in a ravine up north. He won't say what it does.", "Delivery driver here: some trucks drive into the mountain and don't come out."}
	task.wait(300)
	while true do
		local undiscovered = false
		for _, p in ipairs(Players:GetPlayers()) do local d = data[p] if d and not rec(d).discovered then undiscovered = true end end
		if undiscovered and F.buzz then F.buzz("⛰️", rumors[math.random(#rumors)], RGB(150, 140, 130), "Anonymous") end
		task.wait(math.random(600, 900))
	end
end)

-- =====================================================================
-- ADMIN (used by the panel; the panel checks the admin's role before calling these)
-- =====================================================================
C.HEIST_ADMIN = {
	open = function(key) if C.HEIST_SITE[key] then siteState[key].cooldownUntil = 0 return F.heistOpen(key) end return false end,
	finish = function(key) if siteState[key] then
		for _, mate in ipairs(table.clone(siteState[key].heist and siteState[key].heist.crew or {})) do robbers[mate].bag = 0 dropRobber(mate, "🛑 An admin ended this robbery.", false) end
		F.heistFinishSite(key) siteState[key].cooldownUntil = 0 return true end return false end,
	giveBag = function(plr, siteKey)
		local s = C.HEIST_SITE[siteKey or "bank"]
		local st = siteState[s.key]
		if robbers[plr] then return false end
		st.heist = st.heist or {site = s, crew = {}, stage = "vault", started = os.clock(), heat = 0, pool = s.pool, grabbed = 0, puzzles = {}}
		table.insert(st.heist.crew, plr)
		robbers[plr] = {heist = st.heist, bag = 0, cap = bagCap(data[plr]), escaped = false, mult = mult(data[plr])}
		plr:SetAttribute("Robber", s.key)
		setBagVisual(plr, true)
		pushState(plr)
		return true
	end,
	fillBag = function(plr) local r = robbers[plr] if not r then return false end r.bag = r.cap r.heist.grabbed = math.max(r.heist.grabbed, r.cap) soundAlarm(r.heist, "admin test") return true end,
	alert = function() local s = C.HEIST_SITE.bank local a = {site = "bank", name = s.name, icon = s.icon, text = "TEST ALERT — " .. s.name, area = s.area, pos = siteState.bank.center, radius = 60, level = "TEST", t = os.clock()}
		table.insert(alerts, a) broadcastPolice(a) return true end,
	clearAlerts = function() table.clear(alerts) if C.policeClear then C.policeClear() end return true end,
	-- v14: give a player a clean slate (tests / admins): no arrest cooldown
	unarrest = function(plr) arrestedAt[plr] = nil jailed[plr] = nil return true end,
	reset = function()
		for plr, r in pairs(robbers) do r.bag = 0 dropRobber(plr, "🛑 Robberies were reset by an admin.", false) end
		for key, st in pairs(siteState) do F.heistFinishSite(key) st.cooldownUntil = 0 end
		table.clear(alerts)
		if C.policeClear then C.policeClear() end
		table.clear(arrestedAt)
		G.nextOpen = os.clock() + 30
		return true
	end,
}
end
