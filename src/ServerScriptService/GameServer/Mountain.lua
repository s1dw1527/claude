-- MOUNTAIN (v11): the Blackrock Syndicate's secret base, hidden inside the mountain north of the race track.
--
-- From outside it's just a rocky mountain with a dirt road, a few vents and faint lights, and a drainage culvert in a
-- ravine. A rusty lever beside the culvert works a hidden mechanism: the lever swings, the gears shake, a rock-faced
-- slab slides aside and the tunnel lights come on. The tunnel is wide enough for every car in the game (it runs in
-- straight, wide sections) and opens into a huge chamber around a glowing lava core: a garage, the job board, the
-- fence, the quartermaster, the planning room and the crew. A second, smaller exit leads out of the east side.
--
-- The server owns the doors: everyone sees the same door, it stays open while anyone (or any car) is in the doorway,
-- it can always be opened from the inside (a panel, and it opens by itself when you walk up to it), so nobody can
-- be trapped. The base is the robbery turn-in (GameServer > Heists).
-- Original design: no map, geometry, names or art from any other game.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local P, wedge, cyl, surfaceText, billboard = C.P, C.wedge, C.cyl, C.surfaceText, C.billboard
local notify = C.notify
local SOLID = {CanCollide = true}

-- ===== layout (world coordinates; the ground is y = 0) =====
local MC = {
	center = V3(300, 0, -740),
	chamber = {x0 = 208, x1 = 392, z0 = -816, z1 = -680, h = 72},     -- the hollow inside
	tunnel = {x0 = 287, x1 = 313, z0 = -680, z1 = -628, h = 18},       -- the drive-in tunnel (26 wide, 18 high)
	exit = {z0 = -772, z1 = -748, x0 = 392, x1 = 452, h = 16},         -- the back exit (east)
	doorOpenSeconds = 10,
	sounds = {lever = "rbxasset://sounds/switch.wav", mechanism = "rbxasset://sounds/collide.wav"},   -- swap for your own ids
}
C.MOUNTAIN = MC
local CH, TU, EX = MC.chamber, MC.tunnel, MC.exit
C.reserve(140, -860, 470, -600)

local f = Instance.new("Folder")
f.Name = "Mountain"
f.Parent = C.WORLD
MC.folder = f
local ROCK = {RGB(92, 86, 80), RGB(78, 72, 68), RGB(104, 96, 88), RGB(70, 64, 62)}
local BASALT = RGB(40, 36, 38)
local rnd = Random.new(1111)

-- ===== the mountain shell: rotated rock blocks, skipping anything that would block the hollow parts =====
local KEEP_OUT = {
	{CH.x0 - 2, -2, CH.z0 - 2, CH.x1 + 2, CH.h + 2, CH.z1 + 2},             -- chamber
	{TU.x0 - 8, -2, TU.z0 - 2, TU.x1 + 8, TU.h + 6, TU.z1 + 34},            -- tunnel + the ravine in front of it
	{EX.x0 - 2, -2, EX.z0 - 4, EX.x1 + 30, EX.h + 6, EX.z1 + 4},            -- back exit + its mouth
}
local function blocked(c, half)
	for _, b in ipairs(KEEP_OUT) do
		if c.X + half > b[1] and c.X - half < b[4] and c.Y + half > b[2] and c.Y - half < b[5] and c.Z + half > b[3] and c.Z - half < b[6] then return true end
	end
	return false
end
local shellCount = 0
do
	local mc = MC.center
	for layer = 0, 10 do
		local y = 6 + layer * 11
		local t = layer / 10
		local rx, rz = 150 * (1 - t * 0.72), 112 * (1 - t * 0.7)
		local n = math.max(8, math.floor(2 * math.pi * math.max(rx, rz) / 30))
		for i = 1, n do
			local a = (i / n) * 2 * math.pi + layer * 0.37
			local s = 30 + rnd:NextNumber(0, 14) - layer * 1.2
			-- a few rings filling inwards so the mountain is solid where the chamber isn't
			for _, k in ipairs({1, 0.8, 0.6, 0.4}) do
				local c = V3(mc.X + math.cos(a) * rx * k, y, mc.Z + math.sin(a) * rz * k)
				if not blocked(c, s * 0.62) then
					P(f, V3(s, s * 0.8, s), CF(c) * CFrame.Angles(rnd:NextNumber(-0.3, 0.3), rnd:NextNumber(0, 6.28), rnd:NextNumber(-0.3, 0.3)),
						ROCK[rnd:NextInteger(1, #ROCK)], layer > 7 and MAT.Basalt or MAT.Slate, SOLID)
					shellCount += 1
				end
			end
		end
	end
	-- the chamber's own walls and roof (a sealed box of volcanic rock under the shell)
	local cx, cz = (CH.x0 + CH.x1) / 2, (CH.z0 + CH.z1) / 2
	local w, d = CH.x1 - CH.x0, CH.z1 - CH.z0
	P(f, V3(w + 16, 8, d + 16), CF(cx, CH.h + 4, cz), BASALT, MAT.Basalt, SOLID)                       -- roof
	P(f, V3(w + 16, 1, d + 16), CF(cx, -0.4, cz), RGB(52, 46, 44), MAT.Basalt, SOLID)                    -- floor
	P(f, V3(8, CH.h, d + 16), CF(CH.x0 - 4, CH.h / 2, cz), BASALT, MAT.Basalt, SOLID)                   -- west wall
	P(f, V3(w + 16, CH.h, 8), CF(cx, CH.h / 2, CH.z0 - 4), BASALT, MAT.Basalt, SOLID)                   -- north wall
	-- east wall, with the back-exit opening
	P(f, V3(8, CH.h, EX.z0 - (CH.z0 - 8)), CF(CH.x1 + 4, CH.h / 2, (CH.z0 - 8 + EX.z0) / 2), BASALT, MAT.Basalt, SOLID)
	P(f, V3(8, CH.h, (CH.z1 + 8) - EX.z1), CF(CH.x1 + 4, CH.h / 2, (EX.z1 + CH.z1 + 8) / 2), BASALT, MAT.Basalt, SOLID)
	P(f, V3(8, CH.h - EX.h, EX.z1 - EX.z0), CF(CH.x1 + 4, EX.h + (CH.h - EX.h) / 2, (EX.z0 + EX.z1) / 2), BASALT, MAT.Basalt, SOLID)
	-- south wall, with the tunnel opening
	local tw = TU.x1 - TU.x0
	P(f, V3(TU.x0 - (CH.x0 - 8), CH.h, 8), CF((CH.x0 - 8 + TU.x0) / 2, CH.h / 2, CH.z1 + 4), BASALT, MAT.Basalt, SOLID)
	P(f, V3((CH.x1 + 8) - TU.x1, CH.h, 8), CF((TU.x1 + CH.x1 + 8) / 2, CH.h / 2, CH.z1 + 4), BASALT, MAT.Basalt, SOLID)
	P(f, V3(tw, CH.h - TU.h, 8), CF((TU.x0 + TU.x1) / 2, TU.h + (CH.h - TU.h) / 2, CH.z1 + 4), BASALT, MAT.Basalt, SOLID)
	-- the crater on top: a glowing lava lake and smoke
	local top = V3(mc.X, 122, mc.Z - 6)
	cyl(f, 6, 46, CF(top), RGB(60, 52, 50), MAT.Basalt, SOLID)
	local lava = cyl(f, 1, 34, CF(top + V3(0, 3.2, 0)), RGB(255, 110, 30), MAT.Neon)
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness = RGB(255, 120, 40), 60, 3
	pl.Parent = lava
	C.smoke(lava, true, 6)
end

-- ===== outside: the dirt road, the ravine, the culvert, subtle clues =====
do
	-- dirt road from North Rd up to the ravine
	P(f, V3(12, 0.2, 320), CF(300, 0.15, -466), RGB(130, 100, 70), MAT.Ground)
	P(f, V3(30, 0.2, 40), CF(300, 0.15, -610), RGB(120, 92, 66), MAT.Ground)
	-- ravine walls in front of the culvert
	for _, sx in ipairs({-1, 1}) do
		for k = 0, 3 do
			P(f, V3(10, 22 - k * 3, 12), CF(300 + sx * 25, (22 - k * 3) / 2, TU.z1 + 6 + k * 10) * CFrame.Angles(0, sx * 0.08, 0),
				ROCK[(k % #ROCK) + 1], MAT.Slate, SOLID)
		end
	end
	-- the culvert: a concrete drain frame around the tunnel mouth
	local mouthZ = TU.z1
	P(f, V3(TU.x1 - TU.x0 + 6, 3, 2), CF(300, TU.h + 1.5, mouthZ), RGB(150, 150, 146), MAT.Concrete, SOLID)
	for _, x in ipairs({TU.x0 - 1.5, TU.x1 + 1.5}) do P(f, V3(3, TU.h + 3, 2), CF(x, (TU.h + 3) / 2, mouthZ), RGB(150, 150, 146), MAT.Concrete, SOLID) end
	local plate = P(f, V3(6, 1.2, 0.2), CF(300, TU.h + 1.5, mouthZ + 1.1), RGB(90, 90, 86), MAT.Metal)
	surfaceText(plate, Enum.NormalId.Front, "DRAIN 7", RGB(220, 220, 210))
	P(f, V3(6, 0.15, 30), CF(300, 0.12, mouthZ + 15), RGB(70, 110, 120), MAT.Glass, {Transparency = 0.3})   -- a trickle of water
	-- vents and faint lights on the slopes (things that look a little too man-made)
	for _, v in ipairs({{250, 54, -700}, {350, 62, -705}, {300, 88, -770}, {230, 40, -790}}) do
		P(f, V3(3, 4, 3), CF(v[1], v[2], v[3]), RGB(70, 70, 74), MAT.DiamondPlate, SOLID)
		local glow = P(f, V3(2.6, 0.3, 2.6), CF(v[1], v[2] + 2.1, v[3]), RGB(255, 150, 60), MAT.Neon)
		C.smoke(glow, false, 2)
	end
	for _, v in ipairs({{262, 30, -660}, {338, 34, -662}, {420, 26, -730}}) do
		local l = P(f, V3(0.6, 0.6, 0.6), CF(v[1], v[2], v[3]), RGB(255, 60, 40), MAT.Neon)
		local pl = Instance.new("PointLight")
		pl.Color, pl.Range, pl.Brightness = RGB(255, 60, 40), 10, 0.6
		pl.Parent = l
	end
	for _, t in ipairs({{250, -600}, {360, -606}, {225, -640}, {380, -640}, {320, -560}}) do C.tree(f, t[1], t[2], 1.1) end
	for i = 1, 14 do
		local x, z = 300 + rnd:NextNumber(-120, 120), -590 + rnd:NextNumber(-30, 30)
		if math.abs(x - 300) > 20 then P(f, V3(4, 3, 4) * rnd:NextNumber(0.6, 1.6), CF(x, 1, z) * CFrame.Angles(0, rnd:NextNumber(0, 6), 0.2), ROCK[(i % #ROCK) + 1], MAT.Slate, SOLID) end
	end
end

-- ===== the tunnel: straight, wide sections, sewer details =====
local tunnelLights = {}
do
	local x0, x1, z0, z1, h = TU.x0, TU.x1, TU.z0, TU.z1, TU.h
	local cx, len = (x0 + x1) / 2, z1 - z0
	local midZ = (z0 + z1) / 2
	P(f, V3(x1 - x0, 1, len), CF(cx, -0.4, midZ), RGB(96, 96, 92), MAT.Concrete, SOLID)
	P(f, V3(x1 - x0 + 2, 1, len), CF(cx, h + 0.5, midZ), RGB(84, 80, 76), MAT.Concrete, SOLID)
	for _, sx in ipairs({-1, 1}) do
		local wx = sx < 0 and x0 - 1 or x1 + 1
		P(f, V3(2, h, len), CF(wx, h / 2, midZ), RGB(120, 70, 60), MAT.Brick, SOLID)
		-- drainage channels along both sides (shallow, flush: cars roll over them)
		P(f, V3(1.6, 0.12, len), CF(cx + sx * (x1 - x0) / 2 - sx * 1.2, 0.12, midZ), RGB(60, 90, 96), MAT.Glass, {Transparency = 0.25})
		-- a pipe along each wall
		C.xcyl(f, len, 1.6, CF(wx - sx * 1.6, h - 3, midZ) * CFrame.Angles(0, math.pi / 2, 0), RGB(90, 96, 100), MAT.Metal)
	end
	for i = 0, 3 do
		local z = z0 + 6 + i * (len - 12) / 3
		local lamp = P(f, V3(3, 0.4, 1.4), CF(cx, h - 0.3, z), RGB(60, 60, 60), MAT.SmoothPlastic)
		local pl = Instance.new("PointLight")
		pl.Color, pl.Range, pl.Brightness, pl.Enabled = RGB(255, 210, 150), 24, 1.6, false
		pl.Parent = lamp
		table.insert(tunnelLights, {part = lamp, light = pl})
	end
	-- a maintenance door, puddles, steam and some (harmless) graffiti
	P(f, V3(0.4, 8, 5), CF(x0 - 0.2, 4, z0 + 14), RGB(70, 80, 70), MAT.Metal)
	for _, z in ipairs({z0 + 20, z0 + 36}) do P(f, V3(5, 0.06, 4), CF(cx + 4, 0.1, z), RGB(70, 90, 100), MAT.Glass, {Transparency = 0.3}) end
	C.smoke(P(f, V3(1, 0.2, 1), CF(x1 - 2, 0.3, z0 + 28), RGB(80, 80, 80), MAT.Metal, {Transparency = 1}), false, 3)
	local tag = P(f, V3(0.2, 3, 8), CF(x1 - 0.1, 5, z0 + 30), RGB(120, 70, 60), MAT.Brick)
	surfaceText(tag, Enum.NormalId.Left, "BLACKROCK ⛰️", RGB(255, 200, 60))
end
-- the back exit (east): a smaller tunnel with its own door
do
	local cx, cz = (EX.x0 + EX.x1) / 2, (EX.z0 + EX.z1) / 2
	P(f, V3(EX.x1 - EX.x0, 1, EX.z1 - EX.z0), CF(cx, -0.4, cz), RGB(96, 96, 92), MAT.Concrete, SOLID)
	P(f, V3(EX.x1 - EX.x0, 1, EX.z1 - EX.z0 + 2), CF(cx, EX.h + 0.5, cz), RGB(84, 80, 76), MAT.Concrete, SOLID)
	for _, z in ipairs({EX.z0 - 1, EX.z1 + 1}) do P(f, V3(EX.x1 - EX.x0, EX.h, 2), CF(cx, EX.h / 2, z), RGB(120, 70, 60), MAT.Brick, SOLID) end
end

-- =====================================================================
-- DOORS (server state; everyone sees the same thing)
-- =====================================================================
MC.doors = {}
local function makeDoor(id, closedCF, openCF, size, sensor, outsideLever, insidePanel)
	local door = P(f, size, closedCF, RGB(84, 78, 72), MAT.Slate, SOLID)
	door.Name = "SecretDoor_" .. id
	-- rock-faced front, so the closed door looks like part of the mountain
	local face = P(f, size + V3(1, 1, 0.5), closedCF * CF(0, 0, -0.2), ROCK[2], MAT.Slate, {CanCollide = false})
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = door, face
	weld.Parent = face
	face.Anchored = false
	local dr = {id = id, part = door, closed = closedCF, open = openCF, state = "closed", openedAt = 0, sensor = sensor, opens = 0}
	MC.doors[id] = dr
	f:SetAttribute("Door_" .. id, "closed")
	return dr
end
local function anyoneIn(box)
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local q = r.Position
			if q.X > box[1] and q.X < box[4] and q.Y > box[2] - 4 and q.Y < box[5] + 8 and q.Z > box[3] and q.Z < box[6] then return true end
		end
	end
	for _, c in pairs(C.activeCars or {}) do
		local r = c.root
		if r and r.Parent then
			local q = r.Position
			if q.X > box[1] - 4 and q.X < box[4] + 4 and q.Y > box[2] - 4 and q.Y < box[5] + 8 and q.Z > box[3] - 6 and q.Z < box[6] + 6 then return true end
		end
	end
	return false
end
local function moveDoor(dr, to, seconds)
	local from = dr.part.CFrame
	local steps = math.max(1, math.floor(seconds * 15))
	for i = 1, steps do
		dr.part.CFrame = from:Lerp(to, i / steps)
		task.wait(seconds / steps)
	end
	dr.part.CFrame = to
end
function MC.openDoor(id, who)
	local dr = MC.doors[id]
	if not dr then return false end
	dr.openedAt = os.clock()
	if dr.state == "open" or dr.state == "opening" then return true end
	if dr.state == "closing" then dr.reopen = true return true end
	dr.state = "opening"
	dr.opens += 1
	f:SetAttribute("Door_" .. id, "opening")
	task.spawn(function()
		-- 1) the lever swings  2) a clunk  3) the gears shake  4) the slab slides  5) lights on
		if dr.lever then
			local base = dr.lever.CFrame
			for i = 1, 6 do
				dr.lever.CFrame = base * CFrame.Angles(math.rad(-12 * i), 0, 0)
				task.wait(0.04)
			end
		end
		if dr.sound then dr.sound:Play() end
		if dr.gear then
			local g = dr.gear.CFrame
			for i = 1, 8 do
				dr.gear.CFrame = g * CF(rnd:NextNumber(-0.25, 0.25), rnd:NextNumber(-0.2, 0.2), 0) * CFrame.Angles(0, 0, i * 0.4)
				task.wait(0.05)
			end
			dr.gear.CFrame = g
		end
		moveDoor(dr, dr.open, 2.2)
		dr.state = "open"
		dr.openedAt = os.clock()
		f:SetAttribute("Door_" .. id, "open")
		if id == "main" then for _, l in ipairs(tunnelLights) do l.light.Enabled = true l.part.Color = RGB(255, 225, 170) l.part.Material = MAT.Neon end end
		if dr.lever then dr.lever.CFrame = dr.leverCF end
	end)
	if who and F.heistDoorUsed then F.heistDoorUsed(who, id) end
	return true
end
function MC.closeDoor(id)
	local dr = MC.doors[id]
	if not dr or dr.state ~= "open" then return false end
	dr.state = "closing"
	f:SetAttribute("Door_" .. id, "closing")
	task.spawn(function()
		local from = dr.part.CFrame
		local steps = 30
		for i = 1, steps do
			-- someone stepped into the doorway: stop and open again (nobody gets crushed or trapped)
			if dr.reopen or anyoneIn(dr.sensor) then
				dr.reopen = nil
				dr.state = "open"
				dr.openedAt = os.clock()
				f:SetAttribute("Door_" .. id, "open")
				moveDoor(dr, dr.open, 0.5)
				return
			end
			dr.part.CFrame = from:Lerp(dr.closed, i / steps)
			task.wait(2.2 / steps)
		end
		dr.part.CFrame = dr.closed
		dr.state = "closed"
		f:SetAttribute("Door_" .. id, "closed")
		if id == "main" then for _, l in ipairs(tunnelLights) do l.light.Enabled = false l.part.Color = RGB(60, 60, 60) l.part.Material = MAT.SmoothPlastic end end
	end)
	return true
end
function MC.doorState(id) return MC.doors[id] and MC.doors[id].state or "missing" end

do
	-- MAIN door: in the culvert mouth
	local w, h = TU.x1 - TU.x0, TU.h
	local closedCF = CF(300, h / 2, TU.z1 - 1)
	local dr = makeDoor("main", closedCF, closedCF * CF(w + 2, 0, 0), V3(w, h, 2.4),
		{TU.x0 - 2, 0, TU.z1 - 16, TU.x1 + 2, TU.h, TU.z1 + 10})
	-- the lever: on a rock to the right of the culvert, a little rusty
	P(f, V3(3, 4, 3), CF(TU.x1 + 5, 2, TU.z1 + 16), ROCK[3], MAT.Slate, SOLID)
	local box = P(f, V3(1.6, 2, 1.2), CF(TU.x1 + 5, 5, TU.z1 + 16), RGB(110, 70, 50), MAT.CorrodedMetal, SOLID)
	local leverCF = CF(TU.x1 + 5, 6.5, TU.z1 + 15.6) * CFrame.Angles(math.rad(30), 0, 0)
	local lever = P(f, V3(0.3, 2.4, 0.3), leverCF, RGB(150, 40, 30), MAT.CorrodedMetal)
	lever.Name = "Lever"
	dr.lever, dr.leverCF = lever, leverCF
	dr.gear = cyl(f, 0.6, 4, CF(TU.x1 + 3, h + 4, TU.z1 + 0.5) * CFrame.Angles(math.pi / 2, 0, 0), RGB(90, 80, 70), MAT.CorrodedMetal)
	local snd = Instance.new("Sound")
	snd.SoundId = MC.sounds.mechanism
	snd.Volume = 0.8
	snd.Parent = dr.part
	dr.sound = snd
	MC.mainLever = C.prompt(box, "Pull lever", "Rusty lever", 8, 0.6, function(plr) MC.openDoor("main", plr) end)
	-- inside: a panel next to the door, and it opens by itself when you walk or drive up to it
	local panel = P(f, V3(0.4, 3, 2), CF(TU.x1 - 0.2, 4, TU.z1 - 6), RGB(60, 60, 66), MAT.Metal, SOLID)
	P(f, V3(0.2, 1.2, 1.2), CF(TU.x1 - 0.45, 4.4, TU.z1 - 6), RGB(80, 255, 120), MAT.Neon)
	MC.mainPanel = C.prompt(panel, "Open door", "Exit", 10, 0, function(plr) MC.openDoor("main", plr) end)
	dr.insideSensor = {TU.x0 - 1, 0, TU.z1 - 22, TU.x1 + 1, TU.h, TU.z1 - 3}
end
do
	-- BACK door: the east exit. Opens from inside on approach; outside, a hidden valve wheel.
	local h, d = EX.h, EX.z1 - EX.z0
	local closedCF = CF(EX.x1 - 1, h / 2, (EX.z0 + EX.z1) / 2)
	local dr = makeDoor("back", closedCF, closedCF * CF(0, 0, d + 2), V3(2.4, h, d),
		{EX.x1 - 14, 0, EX.z0 - 2, EX.x1 + 12, EX.h, EX.z1 + 2})
	dr.insideSensor = {EX.x0, 0, EX.z0, EX.x1 - 3, EX.h, EX.z1}
	local valve = cyl(f, 0.5, 3, CF(EX.x1 + 6, 3, EX.z1 + 6) * CFrame.Angles(0, 0, math.pi / 2), RGB(150, 40, 30), MAT.CorrodedMetal, SOLID)
	MC.backValve = C.prompt(valve, "Turn valve", "Old valve", 8, 0.8, function(plr) MC.openDoor("back", plr) end)
	dr.lever, dr.leverCF = valve, valve.CFrame
end
-- door upkeep: open for people inside walking up, close when the doorway is clear (twice a second, only near doors)
task.spawn(function()
	while true do
		task.wait(0.5)
		for id, dr in pairs(MC.doors) do
			if dr.state == "closed" and dr.insideSensor and anyoneIn(dr.insideSensor) then MC.openDoor(id) end
			if dr.state == "open" then
				if anyoneIn(dr.sensor) or (dr.insideSensor and anyoneIn(dr.insideSensor)) then dr.openedAt = os.clock()
				elseif os.clock() - dr.openedAt > MC.doorOpenSeconds then MC.closeDoor(id) end
			end
		end
	end
end)

-- =====================================================================
-- THE CHAMBER
-- =====================================================================
local stations = {}
MC.stations = stations
do
	local cx = (CH.x0 + CH.x1) / 2
	local core = V3(cx, 0, -770)
	MC.core = core
	-- the lava core: a glowing pool with a rising column of light
	cyl(f, 2, 50, CF(core + V3(0, 0.5, 0)), RGB(50, 44, 42), MAT.Basalt, SOLID)
	local pool = cyl(f, 0.6, 42, CF(core + V3(0, 1.5, 0)), RGB(255, 100, 20), MAT.Neon)
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness = RGB(255, 110, 40), 60, 3
	pl.Parent = pool
	local column = cyl(f, CH.h - 4, 6, CF(core + V3(0, CH.h / 2, 0)), RGB(255, 140, 50), MAT.Neon, {Transparency = 0.55})
	column.CanQuery = false
	C.smoke(pool, true, 4)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		P(f, V3(1, 2.4, 1), CF(core + V3(math.cos(a) * 27, 1.2, math.sin(a) * 27)), RGB(255, 200, 40), MAT.Metal)
	end
	-- catwalk around the north half, with stairs
	P(f, V3(CH.x1 - CH.x0 - 20, 0.6, 10), CF(cx, 14, CH.z0 + 8), RGB(70, 72, 78), MAT.DiamondPlate, SOLID)
	P(f, V3(CH.x1 - CH.x0 - 20, 2, 0.3), CF(cx, 15.6, CH.z0 + 13), RGB(200, 60, 40), MAT.Metal, SOLID)
	wedge(f, V3(8, 14, 22), CF(CH.x0 + 18, 7, CH.z0 + 24) * CFrame.Angles(0, math.pi, 0), RGB(70, 72, 78), MAT.DiamondPlate, SOLID)
	-- big pipes, warning lights, crates
	for _, z in ipairs({-700, -740, -790}) do C.xcyl(f, CH.x1 - CH.x0 - 4, 3, CF(cx, CH.h - 8, z), RGB(90, 96, 100), MAT.Metal) end
	for _, p in ipairs({{CH.x0 + 2, -700}, {CH.x1 - 2, -700}, {CH.x0 + 2, -800}, {CH.x1 - 2, -800}}) do
		local l = P(f, V3(1, 1, 1), CF(p[1], 20, p[2]), RGB(255, 60, 40), MAT.Neon)
		local pl2 = Instance.new("PointLight")
		pl2.Color, pl2.Range, pl2.Brightness = RGB(255, 80, 40), 28, 1.4
		pl2.Parent = l
	end
	for i = 0, 7 do P(f, V3(5, 5, 5), CF(CH.x0 + 14 + (i % 4) * 6, 2.5 + math.floor(i / 4) * 5, CH.z0 + 30), RGB(150, 110, 70), MAT.WoodPlanks, SOLID) end
	for i = 1, 6 do
		local l = P(f, V3(30, 0.4, 2), CF(cx - 60 + (i - 1) * 24, CH.h - 0.5, -748), RGB(255, 210, 160), MAT.Neon)
		local pl3 = Instance.new("PointLight")
		pl3.Color, pl3.Range, pl3.Brightness = RGB(255, 190, 140), 40, 1.2
		pl3.Parent = l
	end
	-- the escape garage (just inside the tunnel): three bays and a terminal
	for i = -1, 1 do
		P(f, V3(16, 0.1, 22), CF(cx + i * 22, 0.12, CH.z1 - 16), RGB(255, 200, 60), MAT.SmoothPlastic)
	end
	local gsign = P(f, V3(20, 3, 0.4), CF(cx - 44, 12, CH.z1 - 1), RGB(30, 30, 34))
	surfaceText(gsign, Enum.NormalId.Back, "🚗 ESCAPE GARAGE", RGB(255, 200, 60))
	MC.garageCF = CF(cx + 22, 0.5, CH.z1 - 16) * CFrame.Angles(0, math.pi, 0)
	-- stations: each is a counter with a screen and a prompt (Heists hooks them up)
	local function station(key, title, pos, color, action)
		local base = P(f, V3(8, 3.4, 3), CF(pos), RGB(50, 50, 56), MAT.Metal, SOLID)
		local scr = P(f, V3(7, 3.4, 0.3), CF(pos + V3(0, 3.6, -1.2)), RGB(14, 16, 24), MAT.SmoothPlastic)
		surfaceText(scr, Enum.NormalId.Front, title, color)
		local pp = C.prompt(base, action, title, 10, 0, function(plr) if MC.onStation then MC.onStation(plr, key) end end)
		stations[key] = {part = base, prompt = pp, pos = pos}
	end
	station("jobs", "📋 JOB BOARD", V3(CH.x0 + 12, 1.7, -730), RGB(255, 200, 60), "Check jobs")
	station("fence", "💰 THE FENCE", V3(CH.x0 + 12, 1.7, -760), RGB(120, 255, 150), "Turn in loot")
	station("quartermaster", "🎒 QUARTERMASTER", V3(CH.x0 + 12, 1.7, -790), RGB(120, 200, 255), "Bags & gear")
	station("planning", "🗺️ PLANNING ROOM", V3(CH.x1 - 12, 1.7, -730), RGB(255, 120, 90), "Open intel")
	station("computer", "💻 SECRET COMPUTER", V3(CH.x1 - 12, 1.7, -760), RGB(120, 230, 255), "Use computer")
	station("base", "⛰️ BASE UPGRADES", V3(CH.x1 - 12, 1.7, -790), RGB(255, 150, 60), "Upgrade base")
	station("garage", "🚗 GARAGE TERMINAL", V3(cx - 44, 1.7, CH.z1 - 8), RGB(255, 200, 60), "Get a car")
	-- crew area: couches and a table near the core
	for _, sx in ipairs({-1, 1}) do
		P(f, V3(12, 1.4, 3.4), CF(cx + sx * 46, 1, -805), RGB(90, 30, 30), MAT.Fabric, SOLID)
		P(f, V3(12, 2.6, 1), CF(cx + sx * 46, 2.3, -807), RGB(90, 30, 30), MAT.Fabric)
	end
	P(f, V3(14, 0.4, 7), CF(cx, 2.8, -800), RGB(60, 40, 30), MAT.Wood, SOLID)
	local banner = P(f, V3(40, 8, 0.6), CF(cx, 30, CH.z0 + 1), RGB(20, 18, 20))
	surfaceText(banner, Enum.NormalId.Back, "⛰️ THE BLACKROCK SYNDICATE", RGB(255, 140, 60))
end

-- the crew (client-side NPCs, like the HQ staff): role, name, x, z, idle move, lines
C.SYNDICATE = {
	{"boss", "The Boss", 300, -808, "clipboard", {"The city thinks we're just another business.", "Clean jobs. No mess.", "You did good out there."}},
	{"driver", "Wheels", 322, -700, "lift", {"Tunnel's wide enough for anything with four wheels.", "Keep the engine warm."}},
	{"lookout", "Hawk", 230, -706, "look", {"Police scanners are lighting up.", "Keep your head down out there."}},
	{"mechanic", "Sparks", 278, -700, "wipe", {"Who scratched the paint again?", "She'll run. Probably."}},
	{"fence", "Velvet", 222, -760, "show", {"Bring the bag here. I make it look legit.", "Clean money, minus my cut."}},
	{"hacker", "Glitch", 378, -760, "type", {"Bank firewall? Cute.", "Cameras loop in three... two..."}},
	{"quartermaster", "Crates", 222, -790, "lift", {"Bigger bag, bigger payday.", "Don't lose my gear."}},
	{"dispatcher", "Static", 378, -730, "type", {"New job just came in.", "Bring the package back here."}},
}
do
	local parts = {}
	for _, n in ipairs(C.SYNDICATE) do
		table.insert(parts, table.concat({n[1], n[2], n[3], n[4], n[5], table.concat(n[6], "|")}, ";"))
	end
	f:SetAttribute("Crew", table.concat(parts, "\n"))
	f:SetAttribute("Core", MC.core)
end

-- =====================================================================
-- HELPERS FOR OTHER MODULES
-- =====================================================================
function MC.inChamber(pos)
	return pos.X > CH.x0 and pos.X < CH.x1 and pos.Z > CH.z0 and pos.Z < CH.z1 and pos.Y > -6 and pos.Y < CH.h
end
function MC.inBase(pos)
	return MC.inChamber(pos) or (pos.X > TU.x0 and pos.X < TU.x1 and pos.Z > TU.z0 and pos.Z < TU.z1 - 4 and pos.Y < TU.h + 4)
end
MC.hqSpawn = CF(300, 4, -712) * CFrame.Angles(0, math.pi, 0)
MC.outsideSpawn = CF(300, 4, TU.z1 + 30)
MC.shellParts = shellCount

-- discovery: the first time you get inside, the base is yours to know about
local inside = {}
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			local d = data[p]
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local now = r and MC.inBase(r.Position) or false
			if d and now and not inside[p] then
				d.heist = type(d.heist) == "table" and d.heist or {}
				if not d.heist.discovered then
					d.heist.discovered = true
					R.Splash:FireClient(p, "⛰️ YOU FOUND THE SECRET HQ", "The Blackrock Syndicate's base, inside the mountain. Check the Job Board.", RGB(255, 140, 60))
					if F.guideTip then F.guideTip(p, "mountainHQ") end
				end
				if F.heistEnteredBase then F.heistEnteredBase(p, d) end
			end
			inside[p] = now or nil
			if d then p:SetAttribute("InBase", now or nil) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(p) inside[p] = nil end)
end
