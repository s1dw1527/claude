-- FUN PARK (v15 makeover): the public Fun Park (GameServer > Activities: Ferris wheel, carousel, game booths,
-- fireworks) gets real rides and a crowd:
--   * 🎢 THE BIG DIPPER: a big roller coaster round the south side of the park: a lift hill, a big drop, camel
--     backs and a full loop. Its train runs on every client in time with the server clock (EmpireClient > ParkFX);
--     the station's 🎢 Ride prompt plays the ride (the camera rides the front car)
--   * 🗼 SKY DROP (drop tower) and 🌀 THE WHIRL (swing ride), with their own Ride prompts
--   * food stalls (cotton candy, popcorn, ice cream, balloons), string lights over the walkway, a fountain;
--     the people queueing and strolling with cotton candy are EmpireClient > CityCrowd's (FUNPARK_STALLS there
--     mirrors C.FUNPARK_STALLS here)
-- The rides use the same builders as the players' parks (GameServer > Park). Riding costs the same as the Ferris
-- wheel and needs the Fun Park unlocked; everything is checked here.
return function(C)
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data = C.F, C.data
local P, ball, tag = C.P, C.ball, C.tag
local fmt, notify = C.fmt, C.notify
local BUILD, PK = C.PARK_BUILD, C.PARK
if not (BUILD and PK and PK.buildCoaster) then return end
local FERRIS, REP_TIERS = C.FERRIS, C.REP_TIERS
local WHITE, DARK = RGB(250, 250, 250), RGB(40, 40, 46)

local fp = C.WORLD:FindFirstChild("FunPark") or C.WORLD
local f = Instance.new("Folder")
f.Name = "Rides"
f.Parent = fp
local FUN = {}
C.FUNPARK = FUN

local function fee(d) return F.funFee(d, FERRIS.fee) end
local function rideHere(m, spot, name, icon, dur, coaster)
	C.prompt(spot, icon .. " Ride", name, 14, 0, function(plr)
		local d = data[plr]
		if not d then return end
		if not F.unlocked(d, "funpark") then
			notify(plr, "🔒 The Fun Park unlocks at " .. REP_TIERS[C.FEATURES.funpark].name)
			return
		end
		local cost = fee(d)
		if d.cash < cost then
			notify(plr, "A ride costs $" .. fmt(cost))
			return
		end
		local length = dur
		if coaster then
			local train = m:FindFirstChild("Train")
			length = train and train:GetAttribute("Cycle") or 30
		end
		if F.playRide(plr, m, spot, length, {name = name, icon = icon, coaster = coaster}) then
			d.cash -= cost
			F.addRep(plr, 1)
		end
	end)
end
FUN.rideHere = rideHere

-- ===== THE BIG DIPPER =====
do
	local m = Instance.new("Model")
	m.Name = "BigDipper"
	m.Parent = f
	local ctrl = {
		{-385, 2, 104}, {-400, 2, 104}, {-415, 6, 104}, {-445, 22, 104}, {-470, 32, 104}, {-484, 31, 103},
		{-500, 12, 104}, {-515, 3, 104}, {-530, 10, 104}, {-545, 16, 102}, {-560, 8, 100},
		{-578, 4, 94}, {-586, 6, 86}, {-580, 8, 79}, {-566, 5, 77},
		-- the loop (it drifts sideways a little so the track doesn't meet itself)
		{-552, 3, 77}, {-541, 6, 76.5}, {-537, 14, 76}, {-544, 22, 75.5}, {-552, 14, 75}, {-548, 6, 74.5}, {-536, 3, 74},
		{-515, 12, 74}, {-495, 4, 74}, {-470, 14, 74}, {-445, 4, 74}, {-420, 9, 76},
		{-392, 4, 80}, {-373, 3, 88}, {-370, 2, 98}, {-376, 2, 104},
	}
	local cfg = {ctrl = ctrl, cars = 4, color = RGB(255, 60, 120), lift = {0.025, 0.12}, station = 14, phase = 0}
	PK.buildCoaster(cfg, m, CF())
	-- a station roof with a sign, and the queue rail
	P(m, V3(8, 0.4, 18), CF(-392, 8.2, 101), RGB(255, 60, 120), MAT.SmoothPlastic)
	for _, x in ipairs({-388.5, -395.5}) do
		for _, z in ipairs({93, 109}) do P(m, V3(0.5, 7, 0.5), CF(x, 4.6, z), WHITE, MAT.Metal) end
	end
	local sign = P(m, V3(12, 2.4, 0.4), CF(-392, 10, 92), RGB(30, 20, 40), MAT.SmoothPlastic)
	sign.Name = "DipperSign"
	C.surfaceText(sign, Enum.NormalId.Front, "🎢 THE BIG DIPPER", RGB(255, 220, 120))
	local bulbs = Instance.new("Model")
	bulbs.Name = "SignBulbs"
	bulbs.Parent = m
	for k = 0, 11 do ball(bulbs, V3(0.35, 0.35, 0.35), CF(-397.5 + k, 11.4, 91.7), RGB(255, 230, 120), MAT.Neon) end
	tag(bulbs, "ChaseLights")
	local spot = P(m, V3(1, 1, 1), CF(-392, 2.6, 96), WHITE, MAT.SmoothPlastic, {Transparency = 1, Name = "RideSpot"})
	rideHere(m, spot, "The Big Dipper", "🎢", nil, true)
	FUN.dipper = m
end

-- ===== SKY DROP + THE WHIRL =====
do
	local m = Instance.new("Model")
	m.Name = "SkyDrop"
	m.Parent = f
	local o = CF(-582, 0, -92)
	BUILD.droptower(m, o)
	local spot = P(m, V3(1, 1, 1), o * CF(0, 2.5, 6), WHITE, MAT.SmoothPlastic, {Transparency = 1, Name = "RideSpot"})
	rideHere(m, spot, "Sky Drop", "🗼", 16, false)
	FUN.drop = m
	local w = Instance.new("Model")
	w.Name = "Whirl"
	w.Parent = f
	local o2 = CF(-545, 0, -92)
	BUILD.swing(w, o2)
	local spot2 = P(w, V3(1, 1, 1), o2 * CF(0, 2.5, 10), WHITE, MAT.SmoothPlastic, {Transparency = 1, Name = "RideSpot"})
	rideHere(w, spot2, "The Whirl", "🌀", 14, false)
	FUN.whirl = w
end

-- ===== food stalls, lights, a fountain =====
-- (EmpireClient > CityCrowd puts a vendor and a queue at each of these: keep FUNPARK_STALLS there in step)
local STALLS = {
	{"cottoncandy", -415, 26, math.pi}, {"popcorn", -455, -26, 0}, {"cottoncandy", -505, -26, 0}, {"icecream", -545, 26, math.pi},
	{"balloons", -375, -26, 0}, {"cottoncandy", -585, 26, math.pi},
}
C.FUNPARK_STALLS = STALLS
do
	local s = Instance.new("Folder")
	s.Name = "Stalls"
	s.Parent = f
	for i, st in ipairs(STALLS) do
		local m = Instance.new("Model")
		m.Name = "Stall" .. i
		m.Parent = s
		-- a stall faces the walkway (z = 0)
		BUILD[st[1]](m, CF(st[2], 0, st[3]) * CFrame.Angles(0, st[4], 0))
	end
	-- string lights over the walkway: poles each side, a line of bulbs high up
	local lights = Instance.new("Model")
	lights.Name = "StringLights"
	lights.Parent = f
	for x = -380, -580, -40 do
		for _, z in ipairs({-21, 21}) do P(lights, V3(0.3, 10, 0.3), CF(x, 5, z), DARK, MAT.Metal) end
		-- (each string is its own model: ChaseLights chases the bulbs that are a model's direct children)
		local line = Instance.new("Model")
		line.Name = "Bulbs"
		line.Parent = lights
		for k = 0, 13 do
			local z = -19.5 + k * 3
			local sag = math.sin(k / 13 * math.pi) * 1.4
			ball(line, V3(0.45, 0.45, 0.45), CF(x, 9.6 - sag, z), Color3.fromHSV((k % 6) / 6, 0.55, 1), MAT.Neon)
		end
		tag(line, "ChaseLights")
	end
	local fm = Instance.new("Model")
	fm.Name = "Fountain"
	fm.Parent = f
	BUILD.fountain(fm, CF(-592, 0, 38))   -- (off Main St, which runs through the park)
end
end
