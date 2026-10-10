-- WORLD: terrain, road grid, street furniture, player plots, business districts, the Spire.
return function(C)
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, plots = C.F, C.data, C.plots
local P, wedge, ball, cyl, xcyl, ghost, billboard, surfaceText, smoke, sparkle, spin, tag =
	C.P, C.wedge, C.ball, C.cyl, C.xcyl, C.ghost, C.billboard, C.surfaceText, C.smoke, C.sparkle, C.spin, C.tag
local fmt, REP_TIERS, DISTRICT = C.fmt, C.REP_TIERS, C.DISTRICT
local SOLID = {CanCollide = true}

local WORLD = Instance.new("Folder")
WORLD.Name = "City"
WORLD.Parent = Workspace
C.WORLD = WORLD
C.LOTS, C.DESTS, C.LAMPS, C.RESERVED = {}, {}, {}, {}
function C.reserve(x1, z1, x2, z2)
	table.insert(C.RESERVED, {math.min(x1, x2), math.min(z1, z2), math.max(x1, x2), math.max(z1, z2)})
end
function C.isFree(x, z, pad)
	pad = pad or 0
	for _, r in ipairs(C.RESERVED) do
		if x > r[1] - pad and x < r[3] + pad and z > r[2] - pad and z < r[4] + pad then return false end
	end
	return true
end

-- =====================================================================
-- TERRAIN
-- =====================================================================
do
	local T = Workspace.Terrain
	local G, S, W, R, LG, DIRT = MAT.Grass, MAT.Sand, MAT.Water, MAT.Rock, MAT.LeafyGrass, MAT.Ground
	pcall(function() T.Decoration = false end)   -- grass blades poke through roads, so they're off
	pcall(function()
		T:SetMaterialColor(G, RGB(98, 158, 74))
		T:SetMaterialColor(LG, RGB(78, 138, 60))
		T:SetMaterialColor(DIRT, RGB(128, 104, 78))
		T:SetMaterialColor(S, RGB(232, 214, 170))
		T:SetMaterialColor(R, RGB(120, 118, 122))
	end)
	-- CALIBRATION: Roblox terrain surfaces don't always land exactly where a fill ends.
	-- Build a small test patch far off the map, measure where its surface really is,
	-- and shift every fill so the real ground ends up just below y = 0 (under the roads).
	local TARGET = -0.15
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {T}
	local function probe()
		local hit = Workspace:Raycast(V3(0, 60, -3000), V3(0, -160, 0), params)
		return hit and hit.Position.Y or nil
	end
	local off, bestOff, bestErr = 0, -2, math.huge
	for _ = 1, 5 do
		T:FillBlock(CF(0, -20, -3000), V3(80, 80, 80), MAT.Air)
		T:FillBlock(CF(0, -8 + off, -3000), V3(56, 16, 56), G)
		task.wait()
		local y = probe()
		if not y then break end
		local err = y - TARGET
		if math.abs(err) < bestErr then bestErr, bestOff = math.abs(err), off end
		if math.abs(err) < 0.2 then break end
		off -= err
	end
	T:FillBlock(CF(0, -20, -3000), V3(80, 80, 80), MAT.Air)
	off = bestOff
	C.TERRAIN_OFF = off
	print(string.format("[CornerEmpire] terrain calibrated: offset %.2f (surface error %.2f)", off, bestErr))
	T:FillBlock(CF(0, -8 + off, -140), V3(1700, 16, 1400), G)                  -- grass world
	T:FillBlock(CF(0, -8 + off, 240), V3(230, 16, 200), S)                     -- beach district sand
	T:FillBlock(CF(0, -8 + off, 390), V3(1700, 16, 100), S)                    -- shoreline
	T:FillBlock(CF(0, -24 + off, 640), V3(1700, 6, 420), S)                    -- sea floor
	T:FillBlock(CF(0, -10.5 + off, 640), V3(1700, 21, 420), W)                 -- the ocean
	T:FillBlock(CF(0, -1 + off, 440), V3(1700, 2, 22), S)                      -- gentle slope into the water
	-- Hillside plateau
	T:FillBlock(CF(-230, 7 + off, -200), V3(168, 14, 108), R)
	T:FillBlock(CF(-230, 9 + off, -200), V3(160, 18, 100), G)
	-- rolling hills + mountains around the edge of the map
	local rnd = Random.new(7)
	for x = -780, 780, 120 do
		T:FillBall(V3(x + rnd:NextNumber(-30, 30), -40, -760 + rnd:NextNumber(-30, 30)), rnd:NextNumber(90, 140), G)
		T:FillBall(V3(x + rnd:NextNumber(-30, 30), -20, -840), rnd:NextNumber(110, 160), R)
	end
	for z = -700, 300, 130 do
		for _, sx in ipairs({-1, 1}) do
			T:FillBall(V3(sx * (800 + rnd:NextNumber(-20, 30)), -45, z + rnd:NextNumber(-30, 30)), rnd:NextNumber(80, 120), G)
		end
	end
	-- ground variety: leafy meadows and dirt patches so it isn't one flat slab of green
	local function repaint(x, z, sx, sz, to)
		pcall(function()
			local region = Region3.new(V3(x - sx / 2, -8 + off, z - sz / 2), V3(x + sx / 2, 2 + off, z + sz / 2)):ExpandToGrid(4)
			T:ReplaceMaterial(region, 4, G, to)
		end)
	end
	for _ = 1, 70 do
		repaint(rnd:NextNumber(-640, 640), rnd:NextNumber(-620, 320), rnd:NextNumber(30, 90), rnd:NextNumber(30, 90), LG)
	end
	for _ = 1, 30 do
		repaint(rnd:NextNumber(-640, 640), rnd:NextNumber(-620, 320), rnd:NextNumber(8, 20), rnd:NextNumber(8, 20), DIRT)
	end
	-- v11.2: clear the terrain out of a built-up area. The random edge hills above can cover anything built near
	-- the edge of the map (in v11 they filled the mountain base's tunnel and chamber and half-buried the heist
	-- targets). Everything above the ground in the box becomes air, then the normal ground surface goes back in, so
	-- a box with no hill in it comes out exactly as it was.
	C.clearedTerrain = {}
	function C.clearTerrain(x0, z0, x1, z1, h)
		h = h or 60
		local cx, cz, sx, sz = (x0 + x1) / 2, (z0 + z1) / 2, math.abs(x1 - x0), math.abs(z1 - z0)
		T:FillBlock(CF(cx, (h - 16) / 2, cz), V3(sx, h + 16, sz), MAT.Air)
		T:FillBlock(CF(cx, -8 + off, cz), V3(sx, 16, sz), G)
		table.insert(C.clearedTerrain, {math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1), h})
	end
	C.terrainPond = function(x, z, sx, sz)
		T:FillBlock(CF(x, -2 + off, z), V3(sx, 4, sz), W)
		T:FillBlock(CF(x, -5 + off, z), V3(sx + 4, 2, sz + 4), S)
	end
end

-- =====================================================================
-- ROADS (with sidewalks that break at crossings, crosswalks, lane lines)
-- =====================================================================
local ASPHALT, LINE, WALK = RGB(52, 54, 60), RGB(250, 210, 60), RGB(198, 198, 204)
local function road(axis, c, a, b, w, crosses)
	local len = b - a
	local mid = (a + b) / 2
	local center = axis == "x" and V3(mid, -0.9, c) or V3(c, -0.9, mid)
	P(WORLD, axis == "x" and V3(len, 2.2, w) or V3(w, 2.2, len), CF(center), ASPHALT, MAT.Asphalt, SOLID)
	C.reserve(axis == "x" and a or c - w / 2 - 5, axis == "x" and c - w / 2 - 5 or a, axis == "x" and b or c + w / 2 + 5, axis == "x" and c + w / 2 + 5 or b)
	-- break points
	local cuts = {}
	for _, x in ipairs(crosses or {}) do table.insert(cuts, x) end
	table.sort(cuts)
	local function nearCut(v, r)
		for _, x in ipairs(cuts) do
			if math.abs(v - x) < r then return true end
		end
		return false
	end
	-- lane dashes
	for v = a + 6, b - 6, 12 do
		if not nearCut(v, 12) then
			local p = axis == "x" and V3(v, 0.22, c) or V3(c, 0.22, v)
			P(WORLD, axis == "x" and V3(5, 0.04, 0.5) or V3(0.5, 0.04, 5), CF(p), LINE, MAT.SmoothPlastic)
		end
	end
	-- sidewalks between crossings
	local segs, s = {}, a
	for _, x in ipairs(cuts) do
		if x > a and x < b then
			table.insert(segs, {s, x - 11})
			s = x + 11
		end
	end
	table.insert(segs, {s, b})
	for _, sg in ipairs(segs) do
		local l = sg[2] - sg[1]
		if l > 2 then
			local m = (sg[1] + sg[2]) / 2
			for _, side in ipairs({-1, 1}) do
				local off = c + side * (w / 2 + 2)
				P(WORLD, axis == "x" and V3(l, 2.3, 4) or V3(4, 2.3, l), CF(axis == "x" and V3(m, -0.85, off) or V3(off, -0.85, m)), WALK, MAT.Concrete, SOLID)
				P(WORLD, axis == "x" and V3(l, 0.34, 0.3) or V3(0.3, 0.34, l), CF(axis == "x" and V3(m, 0.17, c + side * (w / 2 + 0.15)) or V3(c + side * (w / 2 + 0.15), 0.17, m)), RGB(160, 160, 166), MAT.Concrete)
			end
		end
	end
	-- crosswalks at each crossing
	for _, x in ipairs(cuts) do
		if x > a and x < b then
			for _, side in ipairs({-1, 1}) do
				local base = x + side * 9
				for k = -w / 2 + 1, w / 2 - 1, 2 do
					local p = axis == "x" and V3(base, 0.22, c + k) or V3(c + k, 0.22, base)
					P(WORLD, axis == "x" and V3(3, 0.04, 1) or V3(1, 0.04, 3), CF(p), RGB(240, 240, 240), MAT.SmoothPlastic)
				end
			end
		end
	end
end
C.ROADS = {
	{"x", 0, -650, 650, 14, {-330, -128, 0, 128, 330}},          -- Main St
	{"z", 0, -140, 335, 12, {-128, 0, 128, 225, 335}},           -- Central Ave
	{"x", -128, -330, 330, 12, {-330, -128, 0, 128, 230, 330}},  -- North Ring
	{"x", 128, -330, 330, 12, {-330, -128, 0, 128, 330}},        -- South Ring
	{"z", -128, -128, 128, 12, {-128, 0, 128}},                  -- West Ring
	{"z", 128, -128, 128, 12, {-128, 0, 128}},                   -- East Ring
	{"z", -330, -300, 335, 12, {-300, -128, 0, 128, 225, 335}},  -- West Ave
	{"z", 330, -300, 335, 12, {-300, -215, -128, 0, 128, 335}},  -- East Ave
	{"x", -300, -650, 650, 12, {-330, -230, 0, 230, 330}},       -- North Rd
	{"x", 335, -650, 650, 12, {-330, 0, 330}},                   -- South Rd (shore)
	{"z", 230, -300, -128, 10, {-300, -128}},                    -- Luxury Rd
	{"x", -215, 330, 590, 10, {330}},                            -- Millionaire Ln
	{"x", 225, -600, 0, 10, {-330, 0}},                          -- Maple Ln
	{"z", 0, -348, -300, 12, {-300}},                            -- Race track entrance
}
for _, r in ipairs(C.ROADS) do road(r[1], r[2], r[3], r[4], r[5], r[6]) end
-- ramp up to the Hillside plateau (rises toward +Z)
wedge(WORLD, V3(12, 18, 44), CF(-230, 9, -272), ASPHALT, MAT.Asphalt, SOLID)
C.reserve(-240, -300, -220, -248)

-- =====================================================================
-- STREET FURNITURE
-- =====================================================================
do
	local function lamp(x, z, face)
		P(WORLD, V3(0.6, 12, 0.6), CF(x, 6, z), RGB(40, 42, 48), MAT.Metal, SOLID)
		local arm = CF(x, 12, z) * CFrame.Angles(0, face, 0)
		P(WORLD, V3(0.35, 0.35, 3.4), arm * CF(0, 0, -1.6), RGB(40, 42, 48), MAT.Metal)
		P(WORLD, V3(1.3, 0.5, 1.8), arm * CF(0, -0.2, -3.2), RGB(40, 42, 48), MAT.Metal)
		local bulb = P(WORLD, V3(1.1, 0.2, 1.5), arm * CF(0, -0.5, -3.2), RGB(255, 228, 170), MAT.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 34
		light.Angle = 110
		light.Brightness = 2.4
		light.Color = RGB(255, 214, 150)
		light.Enabled = false
		light.Parent = bulb
		table.insert(C.LAMPS, light)
	end
	for _, r in ipairs(C.ROADS) do
		local axis, c, a, b, w = r[1], r[2], r[3], r[4], r[5]
		local k = 0
		for v = a + 20, b - 20, 46 do
			k += 1
			local near = false
			for _, x in ipairs(r[6]) do
				if math.abs(v - x) < 16 then near = true end
			end
			if not near and w >= 12 then
				local side = (k % 2 == 0) and 1 or -1
				local off = c + side * (w / 2 + 3.2)
				if axis == "x" then
					lamp(v, off, side == 1 and 0 or math.pi)
				else
					lamp(off, v, side == 1 and math.pi / 2 or -math.pi / 2)
				end
			end
		end
	end
	-- traffic lights (client cycles the colors)
	local function trafficLight(x, z, yaw, phase)
		local cf = CF(x, 0, z) * CFrame.Angles(0, yaw, 0)
		P(WORLD, V3(0.6, 14, 0.6), cf * CF(0, 7, 0), RGB(40, 42, 48), MAT.Metal, SOLID)
		P(WORLD, V3(0.4, 0.4, 7), cf * CF(0, 13.5, -3.5), RGB(40, 42, 48), MAT.Metal)
		local box = P(WORLD, V3(1.4, 3.8, 1.2), cf * CF(0, 12, -6.5), RGB(30, 30, 34), MAT.SmoothPlastic)
		local lights = Instance.new("Model")
		lights.Name = "TrafficLight"
		lights.Parent = WORLD
		for i, col in ipairs({RGB(255, 50, 50), RGB(255, 190, 40), RGB(60, 255, 100)}) do
			local l = ball(lights, V3(0.9, 0.9, 0.9), cf * CF(0, 13.2 - (i - 1) * 1.2, -7.15), col, MAT.Neon)
			l.Name = "L" .. i
		end
		lights:SetAttribute("Phase", phase)
		tag(lights, "TrafficLight")
		return box
	end
	-- Phase 0 = east-west traffic (along X) has green, phase 1 = north-south (along Z). The client's traffic obeys
	-- the same cycle (v13). Each light hangs over the road it controls (the phase-1 light used to hang over the
	-- east-west road too, so north-south traffic had no signal).
	C.TRAFFIC_LIGHTS = {{-128, 0}, {128, 0}, {-330, 0}, {330, 0}, {0, 128}, {0, -128}, {-330, -128}, {330, -128}, {-330, 128}, {330, 128}}
	for _, pos in ipairs(C.TRAFFIC_LIGHTS) do
		local x, z = pos[1], pos[2]
		trafficLight(x + 11, z + 11, 0, 0)
		trafficLight(x - 11, z - 11, -math.pi / 2, 1)
	end
	-- benches, hydrants, bins, bus stops
	local function bench(x, z, yaw)
		local cf = CF(x, 0, z) * CFrame.Angles(0, yaw, 0)
		P(WORLD, V3(5, 0.3, 1.4), cf * CF(0, 1.4, 0), RGB(150, 100, 60), MAT.WoodPlanks, SOLID)
		P(WORLD, V3(5, 1.2, 0.3), cf * CF(0, 2.3, 0.6), RGB(150, 100, 60), MAT.WoodPlanks)
		for _, sx in ipairs({-2.2, 2.2}) do P(WORLD, V3(0.3, 1.3, 1.2), cf * CF(sx, 0.65, 0), RGB(40, 40, 45), MAT.Metal) end
	end
	local function hydrant(x, z)
		cyl(WORLD, 1.8, 0.9, CF(x, 0.9, z), RGB(220, 40, 40), MAT.Metal, SOLID)
		ball(WORLD, V3(0.9, 0.9, 0.9), CF(x, 1.9, z), RGB(220, 40, 40), MAT.Metal)
		xcyl(WORLD, 1.4, 0.4, CF(x, 1.2, z), RGB(200, 200, 200), MAT.Metal)
	end
	local function busStop(x, z, yaw)
		local cf = CF(x, 0, z) * CFrame.Angles(0, yaw, 0)
		P(WORLD, V3(9, 0.3, 3.6), cf * CF(0, 8, 0), RGB(40, 44, 56), MAT.Metal)
		P(WORLD, V3(9, 6.5, 0.2), cf * CF(0, 4.3, 1.7), RGB(170, 215, 255), MAT.Glass, {Transparency = 0.5})
		for _, sx in ipairs({-4.3, 4.3}) do P(WORLD, V3(0.3, 8, 0.3), cf * CF(sx, 4, 1.6), RGB(40, 44, 56), MAT.Metal, SOLID) end
		local ad = P(WORLD, V3(0.2, 5, 3), cf * CF(-4.4, 4, 0), RGB(255, 200, 60), MAT.SmoothPlastic)
		surfaceText(ad, Enum.NormalId.Left, "🍋 CORNER EMPIRE", RGB(40, 30, 10))
		bench(x, z, yaw)
	end
	for _, x in ipairs({-230, -470, 230, 470}) do
		busStop(x, -11.5, 0)
		busStop(x + 20, 11.5, math.pi)
		hydrant(x + 8, -10.5)
		bench(x - 16, 11, math.pi)
	end
	for _, pos in ipairs({{-60, -123}, {60, -123}, {-60, 123}, {60, 123}, {-123, -60}, {123, 60}}) do
		bench(pos[1], pos[2], 0)
	end
end

-- =====================================================================
-- CORE: plaza + 4 player plots (90x90)
-- =====================================================================
local PLOT_CENTERS = {V3(-62, 0, -62), V3(62, 0, -62), V3(-62, 0, 62), V3(62, 0, 62)}
local PLOT_COLORS = {RGB(226, 80, 80), RGB(80, 140, 235), RGB(80, 200, 120), RGB(245, 165, 55)}
do
	P(WORLD, V3(232, 2, 232), CF(0, -0.85, 0), RGB(200, 200, 205), MAT.Concrete, SOLID)
	C.reserve(-122, -122, 122, 122)
	P(WORLD, V3(34, 0.5, 34), CF(0, 0.25, 0), RGB(205, 195, 175), MAT.Cobblestone, SOLID)
	for _, sx in ipairs({-12, 12}) do
		for _, sz in ipairs({-12, 12}) do
			cyl(WORLD, 1.4, 5, CF(sx, 0.9, sz), RGB(150, 150, 155), MAT.Concrete)
			ball(WORLD, V3(4.2, 3.2, 4.2), CF(sx, 2.4, sz), RGB(70, 150, 70), MAT.Grass)
			ball(WORLD, V3(0.9, 0.9, 0.9), CF(sx + 0.9, 3.6, sz), RGB(255, 110, 150))
			ball(WORLD, V3(0.9, 0.9, 0.9), CF(sx - 0.8, 3.5, sz + 0.7), RGB(255, 220, 90))
		end
	end
	for i = 1, 4 do
		local c = PLOT_CENTERS[i]
		local fz = c.Z < 0 and 1 or -1
		local col = PLOT_COLORS[i]
		local folder = Instance.new("Folder")
		folder.Name = "Plot" .. i
		folder:SetAttribute("Workers", "")
		folder.Parent = Workspace
		tag(folder, "EmpirePlot")
		local function at(xl, y, zl) return V3(c.X + xl, y, c.Z + zl * fz) end
		P(folder, V3(90, 3, 90), CF(c + V3(0, -0.5, 0)), RGB(96, 170, 96), MAT.Grass, {CanCollide = true, Name = "Base"})
		P(folder, V3(90.6, 2.4, 90.6), CF(c + V3(0, -0.7, 0)), col, MAT.SmoothPlastic)
		P(folder, V3(86, 0.12, 36), CF(at(0, 1.06, 26)), RGB(196, 186, 165), MAT.Cobblestone)
		for _, sx in ipairs({-44, 44}) do
			P(folder, V3(1.6, 2, 60), CF(at(sx, 2, -14)), RGB(60, 130, 60), MAT.Grass)
		end
		P(folder, V3(88, 2, 1.6), CF(at(0, 2, -44)), RGB(60, 130, 60), MAT.Grass)
		local sp = Instance.new("SpawnLocation")
		sp.Anchored = true
		sp.Neutral = true
		sp.Duration = 0
		sp.Size = V3(8, 0.6, 8)
		sp.CFrame = CF(at(0, 1.3, 34))
		sp.Color = col
		sp.Material = MAT.SmoothPlastic
		sp.Enabled = false
		local dec = sp:FindFirstChildOfClass("Decal")
		if dec then dec:Destroy() end
		sp.Parent = folder
		for _, sx in ipairs({-10, 10}) do
			P(folder, V3(0.7, 9, 0.7), CF(at(sx, 5.5, -41)), RGB(90, 60, 40), MAT.Wood, SOLID)
		end
		local board = P(folder, V3(22, 6, 0.6), CF(at(0, 10, -41)), col:Lerp(Color3.new(0, 0, 0), 0.35), MAT.SmoothPlastic, {Name = "Board"})
		local names, tiers = {}, {}
		for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
			local sg = Instance.new("SurfaceGui")
			sg.Face = face
			sg.CanvasSize = Vector2.new(880, 240)
			sg.LightInfluence = 0
			sg.Parent = board
			local a = Instance.new("TextLabel")
			a.Size = UDim2.fromScale(1, 0.62)
			a.BackgroundTransparency = 1
			a.Font = Enum.Font.GothamBlack
			a.TextScaled = true
			a.TextColor3 = Color3.new(1, 1, 1)
			a.Text = "Empty Plot"
			a.Parent = sg
			local b = a:Clone()
			b.Position = UDim2.fromScale(0, 0.62)
			b.Size = UDim2.fromScale(1, 0.34)
			b.TextColor3 = RGB(255, 215, 90)
			b.Text = ""
			b.Parent = sg
			table.insert(names, a)
			table.insert(tiers, b)
		end
		plots[i] = {index = i, folder = folder, spawn = sp, center = c, fz = fz, color = col, at = at,
			nameLabels = names, tierLabels = tiers, slots = {}, kiosks = {}, owner = nil}
	end
end
function F.setPlotSign(plot, name, tier)
	for _, l in ipairs(plot.nameLabels) do l.Text = name end
	for _, l in ipairs(plot.tierLabels) do l.Text = tier or "" end
end
-- business slot layout: 2 rows of 4, 16x16 each
function F.slotCF(plot, key)
	-- v14: a business that lives on a city plot (the Movie Theater) stands on its owner's plot; until it has one,
	-- its "slot" is the front of the home plot (customers and moments still have somewhere to go)
	if C.BIZ[key].lotOnly then
		local lot = F.siteLot and F.siteLot(plot.owner, key)
		if lot then return CF(lot.pos) * CFrame.Angles(0, lot.yaw or 0, 0) end
		return CF(plot.at(0, 1, 30)) * CFrame.Angles(0, plot.fz == 1 and 0 or math.pi, 0)
	end
	local i = C.BIZ[key].index
	local col = (i - 1) % 4
	local zl = i <= 4 and -28 or -6
	return CF(plot.at(-32 + col * 19, 1, zl)) * CFrame.Angles(0, plot.fz == 1 and 0 or math.pi, 0)
end

-- =====================================================================
-- DISTRICT DECOR + BUSINESS LOTS
-- =====================================================================
function C.skyscraper(parent, x, z, w, d, h, color, trim)
	P(parent, V3(w, h, d), CF(x, h / 2, z), color, MAT.Glass, {CanCollide = true, Reflectance = 0.2, Transparency = 0.02})
	for y = 7, h - 3, 7 do P(parent, V3(w + 0.3, 0.5, d + 0.3), CF(x, y, z), trim, MAT.SmoothPlastic) end
	for _, sx in ipairs({-1, 1}) do
		for _, sz in ipairs({-1, 1}) do P(parent, V3(0.8, h, 0.8), CF(x + sx * w / 2, h / 2, z + sz * d / 2), trim, MAT.SmoothPlastic) end
	end
	P(parent, V3(w * 0.6, 4, d * 0.6), CF(x, h + 2, z), trim, MAT.Concrete)
	local blink = ball(parent, V3(1, 1, 1), CF(x, h + 6, z), RGB(255, 60, 60), MAT.Neon)
	P(parent, V3(0.3, 2, 0.3), CF(x, h + 5, z), RGB(60, 60, 60), MAT.Metal)
	TweenService:Create(blink, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.9}):Play()
	C.reserve(x - w / 2, z - d / 2, x + w / 2, z + d / 2)
end
function C.warehouse(parent, x, z, w, d, h, color, stacks)
	P(parent, V3(w, h, d), CF(x, h / 2, z), color, MAT.Brick, SOLID)
	for k = 0, math.floor(w / 5) - 1 do
		P(parent, V3(4.6, 0.3, d + 0.4), CF(x - w / 2 + 2.5 + k * 5, h + 0.9, z) * CFrame.Angles(0, 0, math.rad(-22)), RGB(110, 110, 120), MAT.CorrodedMetal)
	end
	P(parent, V3(6, 5, 0.3), CF(x, 2.5, z + d / 2 + 0.1), RGB(120, 125, 135), MAT.DiamondPlate)
	for s = 1, (stacks or 0) do
		local sx = x - w / 2 + s * (w / (stacks + 1))
		cyl(parent, h + 10, 2.4, CF(sx, (h + 10) / 2, z - d / 2 + 2.5), RGB(190, 70, 55), MAT.Brick)
		cyl(parent, 0.8, 2.5, CF(sx, h + 6, z - d / 2 + 2.5), RGB(240, 240, 240), MAT.Concrete)
		smoke(ghost(parent, CF(sx, h + 10.5, z - d / 2 + 2.5)), true, 6)
	end
	C.reserve(x - w / 2, z - d / 2, x + w / 2, z + d / 2)
end
function C.palm(parent, x, z)
	for k = 0, 5 do
		P(parent, V3(1, 1.9, 1), CF(x + k * 0.3, 0.95 + k * 1.8, z) * CFrame.Angles(0, 0, math.rad(-8)), RGB(140, 100, 60), MAT.Wood)
	end
	for a = 0, 5 do
		P(parent, V3(0.3, 0.6, 6), CF(x + 1.6, 10.8, z) * CFrame.Angles(0, math.rad(a * 60), 0) * CF(0, 0, -2.6) * CFrame.Angles(math.rad(-22), 0, 0), RGB(60, 160, 70), MAT.Grass)
	end
	ball(parent, V3(1.2, 1.2, 1.2), CF(x + 1.6, 10.2, z), RGB(120, 80, 40))
end
function C.villa(parent, x, z, color, y)
	y = y or 0
	P(parent, V3(18, 6, 14), CF(x, y + 3, z), RGB(245, 245, 240), MAT.SmoothPlastic, SOLID)
	P(parent, V3(12, 5, 10), CF(x - 2, y + 8.5, z - 1), RGB(245, 245, 240), MAT.SmoothPlastic, SOLID)
	P(parent, V3(18.4, 0.5, 14.4), CF(x, y + 6.2, z), color, MAT.SmoothPlastic)
	P(parent, V3(12.4, 0.5, 10.4), CF(x - 2, y + 11.2, z - 1), color, MAT.SmoothPlastic)
	P(parent, V3(16, 4, 0.2), CF(x, y + 3, z + 7.05), RGB(150, 210, 255), MAT.Glass, {Transparency = 0.3})
	P(parent, V3(9, 0.3, 6), CF(x + 3, y + 0.3, z + 11), RGB(60, 170, 255), MAT.Glass, {Transparency = 0.2})
end
local function gate(parent, pos, alongX, title, sub, color)
	local off = alongX and V3(0, 0, 10) or V3(10, 0, 0)
	for _, s in ipairs({-1, 1}) do P(parent, V3(1.4, 14, 1.4), CF(pos + off * s + V3(0, 7, 0)), RGB(60, 60, 70), MAT.Metal, SOLID) end
	local banner = P(parent, alongX and V3(1, 4, 22) or V3(22, 4, 1), CF(pos + V3(0, 13, 0)), color, MAT.SmoothPlastic)
	billboard(banner, UDim2.fromOffset(280, 72), V3(0, 5, 0), {{text = title, h = 0.6}, {text = sub, h = 0.4, color = RGB(255, 225, 120), font = Enum.Font.GothamBold}}, 350)
end
C.gate = gate

do
	local function addLot(dkey, pos) table.insert(C.LOTS, {id = #C.LOTS + 1, dkey = dkey, pos = pos}) C.reserve(pos.X - 12, pos.Z - 12, pos.X + 12, pos.Z + 12) end
	local function addDest(name, icon, pos)
		local pad = cyl(WORLD, 0.3, 12, CF(pos + V3(0, 0.3, 0)), RGB(80, 255, 140), MAT.Neon, {Transparency = 0.45})
		billboard(pad, UDim2.fromOffset(200, 40), V3(0, 4, 0), {{text = icon .. " " .. name}}, 90)
		table.insert(C.DESTS, {name = name, icon = icon, pos = pos})
	end
	-- DOWNTOWN (east of the core)
	local dt = Instance.new("Folder", WORLD)
	dt.Name = "Downtown"
	P(dt, V3(188, 2, 240), CF(230, -0.85, 0), RGB(185, 185, 195), MAT.Concrete, SOLID)
	for _, lx in ipairs({175, 285}) do
		for _, lz in ipairs({-70, 70}) do addLot("downtown", V3(lx, 0, lz)) end
	end
	C.skyscraper(dt, 230, -42, 26, 18, 58, RGB(90, 130, 190), RGB(230, 230, 240))
	local hs = P(dt, V3(16, 4, 0.5), CF(230, 50, -32.7), RGB(200, 40, 60), MAT.SmoothPlastic)
	surfaceText(hs, Enum.NormalId.Back, "🏨 GRAND HOTEL")
	addDest("Grand Hotel", "🏨", V3(230, 0.2, -18))
	C.skyscraper(dt, 230, 42, 22, 18, 46, RGB(70, 90, 120), RGB(255, 205, 80))
	C.skyscraper(dt, 175, -24, 16, 12, 36, RGB(110, 140, 170), RGB(240, 240, 245))
	C.skyscraper(dt, 285, 24, 16, 12, 64, RGB(60, 110, 160), RGB(220, 225, 235))
	C.skyscraper(dt, 175, 24, 16, 12, 30, RGB(150, 120, 110), RGB(240, 230, 220))
	C.skyscraper(dt, 285, -24, 16, 12, 42, RGB(80, 100, 140), RGB(255, 255, 255))
	gate(dt, V3(142, 0, 0), true, "🏙️ DOWNTOWN", "Lots need " .. REP_TIERS[DISTRICT.downtown.tier].name, DISTRICT.downtown.color)
	-- INDUSTRIAL (west of the core)
	local ind = Instance.new("Folder", WORLD)
	ind.Name = "Industrial"
	P(ind, V3(188, 2, 240), CF(-230, -0.85, 0), RGB(120, 120, 128), MAT.Asphalt, SOLID)
	for _, lx in ipairs({-175, -285}) do
		for _, lz in ipairs({-70, 70}) do addLot("industrial", V3(lx, 0, lz)) end
	end
	C.warehouse(ind, -230, -44, 26, 16, 12, RGB(160, 110, 90), 0)
	addDest("Factory Gate", "🏭", V3(-230, 0.2, -18))
	C.warehouse(ind, -230, 44, 26, 18, 14, RGB(150, 100, 80), 2)
	for _, pos in ipairs({{-175, -24}, {-285, 24}, {-175, 24}, {-285, -24}}) do
		cyl(ind, 22, 10, CF(pos[1], 11, pos[2]), RGB(205, 205, 210), MAT.Metal, SOLID)
		cyl(ind, 1.2, 10.4, CF(pos[1], 22.6, pos[2]), RGB(235, 165, 50), MAT.SmoothPlastic)
		C.reserve(pos[1] - 5, pos[2] - 5, pos[1] + 5, pos[2] + 5)
	end
	gate(ind, V3(-142, 0, 0), true, "🏭 INDUSTRIAL ZONE", "Lots need " .. REP_TIERS[DISTRICT.industrial.tier].name, DISTRICT.industrial.color)
	-- BEACH DISTRICT (south of the core)
	local bch = Instance.new("Folder", WORLD)
	bch.Name = "Beach"
	for _, lx in ipairs({-50, 50}) do
		for _, lz in ipairs({180, 280}) do addLot("beach", V3(lx, 0, lz)) end
	end
	C.reserve(-118, 138, 118, 345)
	for px = -100, 100, 200 do
		for pz = 150, 320, 34 do C.palm(bch, px, pz) end
	end
	-- pier out into the ocean
	P(bch, V3(10, 0.8, 80), CF(0, 1.2, 440), RGB(150, 110, 70), MAT.WoodPlanks, SOLID)
	for pz = 406, 476, 10 do
		for _, sx in ipairs({-4.5, 4.5}) do cyl(bch, 8, 0.8, CF(sx, -2.8, pz), RGB(110, 80, 50), MAT.Wood) end
	end
	for pz = 406, 476, 10 do
		for _, sx in ipairs({-5, 5}) do P(bch, V3(0.3, 2.5, 0.3), CF(sx, 2.8, pz), RGB(240, 240, 240), MAT.Wood) end
	end
	addDest("Boardwalk Pier", "🌊", V3(0, 0.3, 398))
	-- concert stage
	local stage = P(bch, V3(16, 2.4, 26), CF(95, 1.2, 230), RGB(40, 40, 50), MAT.SmoothPlastic, SOLID)
	P(bch, V3(1, 16, 26), CF(103, 9, 230), RGB(30, 30, 38), MAT.SmoothPlastic, SOLID)
	P(bch, V3(16, 1, 28), CF(95, 17, 230), RGB(30, 30, 38), MAT.Metal)
	C.reserve(86, 216, 105, 244)
	local stageLights = {}
	for k, sz in ipairs({220, 226, 234, 240}) do
		local l = ball(bch, V3(1.4, 1.4, 1.4), CF(92, 16, sz), Color3.fromHSV(k / 4, 0.8, 1), MAT.Neon)
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Left
		sl.Range = 45
		sl.Angle = 45
		sl.Brightness = 0
		sl.Color = l.Color
		sl.Parent = l
		table.insert(stageLights, sl)
	end
	billboard(stage, UDim2.fromOffset(220, 44), V3(0, 18, 0), {{text = "🎤 BEACH STAGE"}}, 250)
	C.stageLights = stageLights
	gate(bch, V3(0, 0, 142), false, "🏖️ BEACH DISTRICT", "Lots need " .. REP_TIERS[DISTRICT.beach.tier].name, DISTRICT.beach.color)
	-- LUXURY HILLS (north-east)
	local lux = Instance.new("Folder", WORLD)
	lux.Name = "LuxuryHills"
	for _, lx in ipairs({190, 270}) do
		for _, lz in ipairs({-180, -260}) do addLot("luxury", V3(lx, 0, lz)) end
	end
	addDest("Luxury Villa", "💎", V3(212, 0.2, -222))
	gate(lux, V3(230, 0, -140), false, "💎 LUXURY HILLS", "Lots need " .. REP_TIERS[DISTRICT.luxury.tier].name, DISTRICT.luxury.color)
	addDest("Corner Motors", "🚗", V3(40, 0.2, -143))
	addDest("Fun Park", "🎡", V3(-470, 0.2, 18))
	addDest("Rental Row", "🏢", V3(415, 0.2, 18))
end

-- ===== BUSINESS LOT visuals (for sale / owned) =====
function F.buildLot(lot)
	if lot.folder then lot.folder:Destroy() end
	local dd = DISTRICT[lot.dkey]
	local f = Instance.new("Folder")
	f.Name = "Lot" .. lot.id
	f.Parent = WORLD
	lot.folder = f
	local p = lot.pos
	local owner = lot.owner and data[lot.owner]
	local base = P(f, V3(22, 2.4, 22), CF(p + V3(0, -0.65, 0)), owner and owner.plot.color:Lerp(RGB(60, 60, 60), 0.3) or RGB(150, 150, 150), MAT.Concrete, SOLID)
	if not owner then
		for _, sx in ipairs({-10.6, 10.6}) do
			for _, sz in ipairs({-10.6, 10.6}) do P(f, V3(0.4, 1.5, 0.4), CF(p + V3(sx, 1.2, sz)), RGB(240, 240, 240)) end
		end
		P(f, V3(0.4, 5, 0.4), CF(p + V3(0, 2.5, 0)), RGB(110, 80, 50), MAT.Wood)
		local sign = P(f, V3(6, 3.5, 0.3), CF(p + V3(0, 5.5, 0)), RGB(245, 245, 245), MAT.SmoothPlastic, {Name = "Sign"})
		billboard(sign, UDim2.fromOffset(190, 80), V3(0, 3.8, 0), {
			{text = "FOR SALE", h = 0.38, color = RGB(255, 90, 90)}, {text = "$" .. fmt(dd.cost), h = 0.34, color = RGB(120, 255, 150)},
			{text = "Needs " .. REP_TIERS[dd.tier].name, h = 0.28, font = Enum.Font.GothamBold}}, 90)
		C.prompt(sign, "Buy Lot ($" .. fmt(dd.cost) .. ")", dd.name .. " Lot", 14, 0.5, function(plr) F.buyLot(plr, lot) end)
		return
	end
	local col = owner.plot.color
	local accent = F.accentFor(lot.owner)
	if lot.dkey == "downtown" then
		P(f, V3(14, 30, 14), CF(p + V3(0, 15.5, 0)), RGB(80, 120, 170), MAT.Glass, {CanCollide = true, Reflectance = 0.2})
		for y = 5, 30, 5 do P(f, V3(14.3, 0.4, 14.3), CF(p + V3(0, y, 0)), accent) end
		P(f, V3(7, 3, 7), CF(p + V3(0, 32, 0)), accent, MAT.Neon)
	elseif lot.dkey == "industrial" then
		C.warehouse(f, p.X, p.Z, 16, 14, 9, col:Lerp(RGB(150, 110, 90), 0.6), 1)
	elseif lot.dkey == "beach" then
		P(f, V3(12, 6, 10), CF(p + V3(0, 3.5, 0)), RGB(255, 245, 225), MAT.WoodPlanks, SOLID)
		P(f, V3(13, 0.5, 11), CF(p + V3(0, 6.8, 0)), accent)
		cyl(f, 4, 0.3, CF(p + V3(7, 2.5, 7)), RGB(240, 240, 240))
		cyl(f, 0.3, 6, CF(p + V3(7, 4.6, 7)), accent, MAT.Fabric)
	else
		C.villa(f, p.X, p.Z - 1, accent)
	end
	P(f, V3(0.3, 12, 0.3), CF(p + V3(-10, 6, -10)), RGB(230, 230, 230), MAT.Metal)
	P(f, V3(0.1, 2.4, 4), CF(p + V3(-10, 10.6, -8)), col, MAT.Fabric)
	billboard(base, UDim2.fromOffset(200, 50), V3(0, 36, 0), {{text = lot.owner.Name, h = 0.55}, {text = dd.icon .. " " .. dd.name, h = 0.45, color = dd.color, font = Enum.Font.GothamBold}}, 250)
end

-- =====================================================================
-- THE EMPIRE SPIRE
-- =====================================================================
local SPIRE = {}
do
	local kiosk = P(WORLD, V3(7, 3.5, 2.4), CF(10, 2.25, 15.5), RGB(60, 60, 75), MAT.SmoothPlastic, SOLID)
	P(WORLD, V3(7.4, 0.4, 2.8), CF(10, 4.2, 15.5), RGB(255, 200, 60), MAT.Neon)
	SPIRE.board = billboard(kiosk, UDim2.fromOffset(300, 90), V3(0, 6.5, 0), {
		{text = "🏙️ THE EMPIRE SPIRE", h = 0.36}, {text = "", h = 0.34, color = RGB(255, 215, 90)},
		{text = "", h = 0.3, color = RGB(120, 255, 150), font = Enum.Font.GothamBold}}, 300)
	C.prompt(kiosk, "Contribute 10% of cash", "Empire Spire", 12, 0.4, function(plr)
		local d = data[plr]
		if d then F.contribute(plr, math.floor(d.cash * 0.1)) end
	end)
end
function F.buildSpire(stages, era)
	if SPIRE.folder then SPIRE.folder:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "EmpireSpire"
	f.Parent = Workspace
	SPIRE.folder = f
	local eraColor = Color3.fromHSV(((era - 1) * 0.17 + 0.12) % 1, 0.75, 1)
	if stages < 5 then
		local h = ({4, 20, 46, 56, 64})[stages + 1]
		for _, sx in ipairs({-7, 7}) do
			for _, sz in ipairs({-7, 7}) do P(f, V3(0.45, h, 0.45), CF(sx, 0.5 + h / 2, sz), RGB(240, 180, 40), MAT.Metal) end
		end
		for y = 4, h, 6 do
			P(f, V3(14.4, 0.3, 0.3), CF(0, y, -7), RGB(240, 180, 40), MAT.Metal)
			P(f, V3(14.4, 0.3, 0.3), CF(0, y, 7), RGB(240, 180, 40), MAT.Metal)
		end
	end
	if stages >= 1 then
		cyl(f, 2.2, 18, CF(0, 1.6, 0), RGB(175, 175, 185), MAT.Granite, SOLID)
		cyl(f, 0.4, 18.4, CF(0, 2.8, 0), eraColor, MAT.Neon)
	end
	if stages >= 2 then
		cyl(f, 18, 12, CF(0, 11.7, 0), RGB(70, 110, 170), MAT.Glass, {CanCollide = true, Reflectance = 0.25})
		for y = 5, 19, 4 do cyl(f, 0.3, 12.3, CF(0, y, 0), RGB(230, 230, 240)) end
	end
	if stages >= 3 then
		cyl(f, 26, 8, CF(0, 33.7, 0), RGB(60, 95, 160), MAT.Glass, {CanCollide = true, Reflectance = 0.3})
		for k = 0, 3 do
			local a = k * math.pi / 2
			P(f, V3(0.4, 26, 0.4), CF(math.cos(a) * 4, 33.7, math.sin(a) * 4), eraColor, MAT.Neon)
		end
	end
	if stages >= 4 then
		cyl(f, 2, 10, CF(0, 47.7, 0), RGB(255, 200, 60), MAT.Foil)
		cyl(f, 3, 7, CF(0, 50.2, 0), RGB(255, 200, 60), MAT.Foil)
		cyl(f, 3, 4, CF(0, 53.2, 0), RGB(255, 200, 60), MAT.Foil)
	end
	if stages >= 5 then
		P(f, V3(0.6, 12, 0.6), CF(0, 60.7, 0), RGB(220, 220, 230), MAT.Metal)
		local orb = ball(f, V3(3.4, 3.4, 3.4), CF(0, 67, 0), eraColor, MAT.Neon)
		local pl = Instance.new("PointLight")
		pl.Range = 60
		pl.Brightness = 3
		pl.Color = eraColor
		pl.Parent = orb
		sparkle(orb, eraColor, 20)
		local beam = cyl(f, 220, 1.6, CF(0, 178, 0), eraColor, MAT.Neon, {Transparency = 0.6})
		beam.CastShadow = false
		for k = 1, era do
			local ring = cyl(f, 0.3, 14 + k * 3, CF(0, 22 + k * 8, 0), eraColor, MAT.Neon, {Transparency = 0.2})
			spin(ring, 0.5 + k * 0.2)
		end
		local holo = ball(f, V3(1, 1, 1), CF(0, 72, 0), eraColor, MAT.Neon, {Transparency = 1})
		billboard(holo, UDim2.fromOffset(320, 70), V3(0, 4, 0), {{text = "🌆 ERA " .. era, h = 0.55}, {text = "THE CITY LIVES", h = 0.45, color = eraColor}}, 900)
	end
end
function F.setSpireBoard(l2, l3)
	SPIRE.board.L2.Text = l2
	SPIRE.board.L3.Text = l3
end

-- CENTRAL PARK (south-east): pond, paths, fountain, benches, flower beds
do
	local pk = Instance.new("Folder", WORLD)
	pk.Name = "CentralPark"
	C.terrainPond(250, 232, 48, 32)
	local PATH = RGB(205, 190, 160)
	local function path(x, z, sx, sz)
		P(pk, V3(sx, 2.2, sz), CF(x, -0.9, z), PATH, MAT.Cobblestone, SOLID)
		C.reserve(x - sx / 2 - 2, z - sz / 2 - 2, x + sx / 2 + 2, z + sz / 2 + 2)
	end
	path(250, 208, 70, 5)     -- around the pond
	path(250, 256, 70, 5)
	path(213, 232, 5, 53)
	path(287, 232, 5, 53)
	path(250, 160, 5, 46)     -- to the south ring road
	path(180, 232, 62, 5)     -- to Central Ave side
	path(250, 300, 5, 40)     -- to the shore road
	C.reserve(226, 216, 274, 248)
	-- fountain
	local fc = V3(180, 0, 180)
	cyl(pk, 1.4, 16, CF(fc + V3(0, 0.7, 0)), RGB(210, 210, 215), MAT.Marble, SOLID)
	cyl(pk, 0.3, 14.5, CF(fc + V3(0, 1.3, 0)), RGB(80, 170, 240), MAT.Glass, {Transparency = 0.25, Reflectance = 0.2})
	cyl(pk, 4, 1.6, CF(fc + V3(0, 3, 0)), RGB(210, 210, 215), MAT.Marble)
	cyl(pk, 0.6, 5, CF(fc + V3(0, 5, 0)), RGB(210, 210, 215), MAT.Marble)
	local spray = ghost(pk, CF(fc + V3(0, 5.5, 0)))
	local e = sparkle(spray, RGB(170, 220, 255), 40)
	e.Speed = NumberRange.new(6, 9)
	e.Acceleration = V3(0, -18, 0)
	e.SpreadAngle = Vector2.new(20, 20)
	C.reserve(170, 170, 190, 190)
	-- flower beds + benches along the paths
	for i, pos in ipairs({{230, 200}, {270, 200}, {230, 264}, {270, 264}, {160, 220}, {200, 245}}) do
		local x, z = pos[1], pos[2]
		P(pk, V3(8, 0.8, 3), CF(x, 0.4, z), RGB(110, 75, 50), MAT.WoodPlanks)
		for k = 0, 9 do
			ball(pk, V3(0.8, 0.8, 0.8), CF(x - 3.6 + k * 0.8, 1.1, z + (k % 2 == 0 and -0.6 or 0.6)), Color3.fromHSV((i * 0.13 + k * 0.05) % 1, 0.65, 1))
		end
	end
	for _, pos in ipairs({{240, 213.5, 0}, {262, 213.5, 0}, {240, 250.5, math.pi}, {262, 250.5, math.pi}}) do
		local cf = CF(pos[1], 0, pos[2]) * CFrame.Angles(0, pos[3], 0)
		P(pk, V3(5, 0.3, 1.4), cf * CF(0, 1.4, 0), RGB(150, 100, 60), MAT.WoodPlanks, SOLID)
		P(pk, V3(5, 1.2, 0.3), cf * CF(0, 2.3, 0.6), RGB(150, 100, 60), MAT.WoodPlanks)
	end
	-- little dock + ducks on the pond
	P(pk, V3(4, 0.4, 10), CF(250, 0.6, 222), RGB(150, 110, 70), MAT.WoodPlanks, SOLID)
	for k = 1, 4 do
		ball(pk, V3(1, 0.8, 1.3), CF(236 + k * 5, 0.4, 238 - (k % 2) * 4), RGB(250, 250, 240))
		ball(pk, V3(0.6, 0.6, 0.6), CF(236 + k * 5, 1, 237.4 - (k % 2) * 4), RGB(60, 130, 60))
	end
	gate(pk, V3(250, 0, 140), false, "🌳 CENTRAL PARK", "Relax by the pond", RGB(90, 190, 110))
end

-- trees, bushes, wildflowers and rocks are scattered last (after every module reserved its space)
function F.scatterTrees()
	local f = Instance.new("Folder", WORLD)
	f.Name = "Nature"
	local rnd = Random.new(42)
	local function onPlateau(x, z) return x > -310 and x < -150 and z > -250 and z < -150 end
	local placed = 0
	for _ = 1, 5000 do
		local x, z = rnd:NextNumber(-660, 660), rnd:NextNumber(-600, 325)
		if placed < 650 and C.isFree(x, z, 5) then
			C.tree(f, x, z, rnd:NextNumber(0.8, 1.3), onPlateau(x, z) and 18 or 0)
			C.reserve(x - 3, z - 3, x + 3, z + 3)
			placed += 1
		end
	end
	local bushes, flowers, rocks = 0, 0, 0
	for _ = 1, 5000 do
		local x, z = rnd:NextNumber(-660, 660), rnd:NextNumber(-600, 325)
		if C.isFree(x, z, 2.5) then
			local y = onPlateau(x, z) and 18 or 0
			local roll = rnd:NextNumber()
			if roll < 0.4 and bushes < 260 then
				local s = rnd:NextNumber(0.8, 1.5)
				local col = Color3.fromHSV(0.28 + rnd:NextNumber() * 0.06, 0.6, 0.45 + rnd:NextNumber() * 0.15)
				ball(f, V3(3, 2.2, 3) * s, CF(x, y + 0.8 * s, z), col, MAT.Grass)
				ball(f, V3(2.2, 1.8, 2.2) * s, CF(x + 1.3 * s, y + 0.6 * s, z + 0.6 * s), col:Lerp(RGB(40, 90, 40), 0.3), MAT.Grass)
				bushes += 1
			elseif roll < 0.85 and flowers < 320 then
				local hue = rnd:NextNumber()
				for k = 1, 5 do
					local fx, fz = x + rnd:NextNumber(-1.8, 1.8), z + rnd:NextNumber(-1.8, 1.8)
					P(f, V3(0.15, 0.9, 0.15), CF(fx, y + 0.45, fz), RGB(70, 140, 60))
					ball(f, V3(0.6, 0.45, 0.6), CF(fx, y + 1, fz), Color3.fromHSV((hue + k * 0.03) % 1, 0.55, 1))
				end
				flowers += 1
			elseif rocks < 90 then
				local s = rnd:NextNumber(1, 3)
				local rk = ball(f, V3(s * 1.4, s, s * 1.2), CF(x, y + s * 0.25, z) * CFrame.Angles(0, rnd:NextNumber() * 6, 0), RGB(125, 122, 118), MAT.Slate)
				rk.CanCollide = true
				rocks += 1
			end
			C.reserve(x - 2, z - 2, x + 2, z + 2)
		end
	end
end
end
