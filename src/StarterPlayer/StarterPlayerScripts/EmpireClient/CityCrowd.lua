-- CITY CROWD (v13): the people and traffic that make the city feel alive, drawn by each client for itself.
--
-- The old version spread 30 walkers and 16 cars over the whole map on fixed rectangles, so wherever you stood you saw
-- two or three people, and the cars ignored the lights and drove through each other. Now:
--   * a POOL of pedestrians and cars is kept around YOU (a bubble that follows the camera): when one gets too far
--     behind, it is recycled to a free spot ahead or out of view. The same budget always fills the place you are at.
--   * everything moves on the REAL road network (the server sends the roads, their crossings and the traffic lights):
--     cars drive in the right-hand lane, stop at red lights, keep their distance from the car in front, turn at
--     crossings and U-turn at dead ends; people walk the sidewalks, turn corners, wait for the light before crossing,
--     stop to window-shop, look at their phone or chat.
--   * every district has its own crowd: suits and coffee downtown, hard hats in the industrial zone, swimsuits and
--     surfboards at the beach, joggers and dog walkers in the suburbs, tourists in the entertainment district, hikers
--     in the hills. Plus a few things going on: a street musician, a hot-dog cart with a queue, beach umbrellas,
--     sunbathers and a volleyball game.
--   * cheap: nothing here touches the server or pathfinding; positions are computed from a 1-D position along a
--     road/sidewalk. Far ones update less often, invisible ones not at all. Settings → Crowds: HIGH / LOW / OFF.
return function(C)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local U, catalog = C.U, C.catalog
local camera = Workspace.CurrentCamera

local CC = {}
C.CityCrowd = CC
local CFG = {
	peds = {high = 44, low = 22, off = 0},
	cars = {high = 18, low = 9, off = 0},
	pedNear = 20, pedFar = 140, pedDrop = 175, pedNew = 80,   -- spawn ring around the camera; recycled beyond pedDrop,
	carNear = 50, carFar = 190, carDrop = 240, carNew = 120,  -- respawned at least pedNew/carNew away (out of view)
	jump = 150,                                       -- the camera moved this far at once (a teleport): refill around it
	lodNear = 110,                                    -- closer than this: updated every frame; further: ~10 times a second
	cycle = 16, yellow = 2,                           -- traffic lights: 8 s per direction, the last 2 s yellow
}
CC.CFG = CFG

local map = catalog.map or {}
local ROADS = {}
for i, r in ipairs(map.roads or {}) do
	-- cuts: crossings inside the road (sidewalks break there); nodes: every junction, including one at either end
	local cuts, nodes = {}, {}
	for _, x in ipairs(r[6] or {}) do
		if x > r[3] and x < r[4] then table.insert(cuts, x) end
		if x >= r[3] - 0.5 and x <= r[4] + 0.5 then table.insert(nodes, x) end
	end
	table.sort(cuts)
	table.sort(nodes)
	ROADS[i] = {i = i, axis = r[1], c = r[2], a = r[3], b = r[4], w = r[5], cuts = cuts, nodes = nodes}
end
local LIGHTS = {}
for _, p in ipairs(map.lights or {}) do LIGHTS[p[1] .. "," .. p[2]] = true end
CC.ROADS, CC.LIGHTS = ROADS, LIGHTS

-- ===== the traffic light cycle (server time, so every client sees the same lights) =====
-- returns: which axis has the green (0 = X, 1 = Z), whether it's yellow now, and seconds left in this phase
function CC.phase()
	local t = Workspace:GetServerTimeNow() % CFG.cycle
	local half = CFG.cycle / 2
	return t < half and 0 or 1, (t % half) > half - CFG.yellow, half - (t % half)
end
-- green for traffic moving along `axis` ("x" or "z")? (yellow is not green: nobody new starts across)
function CC.green(axis)
	local ph, yellow = CC.phase()
	return ((axis == "x" and ph == 0) or (axis == "z" and ph == 1)) and not yellow
end
-- red for `axis`: the other direction has its green (or yellow)
function CC.red(axis)
	local ph = CC.phase()
	return not ((axis == "x" and ph == 0) or (axis == "z" and ph == 1))
end

-- ===== geometry =====
local function roadPoint(r, s, perp, y)
	if r.axis == "x" then return V3(s, y, perp) end
	return V3(perp, y, s)
end
local function laneOf(r, dir)
	-- right-hand traffic: heading +X drives on the +Z side, heading +Z on the -X side
	if r.axis == "x" then return r.c + dir * r.w / 4 end
	return r.c - dir * r.w / 4
end
-- the road that crosses r at coordinate x (along r), if any
local function crossingRoad(r, x)
	for _, r2 in ipairs(ROADS) do
		if r2.axis ~= r.axis and math.abs(r2.c - x) < 0.5 and r2.a <= r.c + 0.5 and r2.b >= r.c - 0.5 then return r2 end
	end
end
local NODES = {}   -- [road i][cut x] = crossing road
for _, r in ipairs(ROADS) do
	NODES[r.i] = {}
	for _, x in ipairs(r.nodes) do NODES[r.i][x] = crossingRoad(r, x) end
end
local function hasLight(r, x)
	if r.axis == "x" then return LIGHTS[x .. "," .. r.c] end
	return LIGHTS[r.c .. "," .. x]
end
CC.hasLight = hasLight

-- sidewalk segments: both sides of each road, broken at the crossings (exactly as World builds them)
local WALKS = {}
for _, r in ipairs(ROADS) do
	local s = r.a
	local spans = {}
	for _, x in ipairs(r.cuts) do
		table.insert(spans, {s, x - 11})
		s = x + 11
	end
	table.insert(spans, {s, r.b})
	for _, sp in ipairs(spans) do
		if sp[2] - sp[1] > 8 then
			for _, side in ipairs({-1, 1}) do
				table.insert(WALKS, {r = r, side = side, s1 = sp[1], s2 = sp[2], perp = r.c + side * (r.w / 2 + 2)})
			end
		end
	end
end
for i, wk in ipairs(WALKS) do wk.i = i end
CC.WALKS = WALKS
-- what's at each end of a sidewalk: the next one straight across the crossing, or the one around the corner
for _, wk in ipairs(WALKS) do
	wk.next = {}
	for _, e in ipairs({-1, 1}) do
		local endS = e == 1 and wk.s2 or wk.s1
		local opts = {}
		for _, o in ipairs(WALKS) do
			if o ~= wk then
				if o.r == wk.r and o.side == wk.side and math.abs((e == 1 and o.s1 or o.s2) - (endS + e * 22)) < 1 then
					table.insert(opts, {w = o, enter = e == 1 and 1 or -1, cross = true, at = endS + e * 11})
				elseif o.r.axis ~= wk.r.axis then
					-- the corner: their sidewalk line passes our end, and our sidewalk line passes their end
					local oEnd1, oEnd2 = o.s1, o.s2
					if math.abs(o.perp - (endS + e * 5)) < 4 then
						for _, oe in ipairs({1, -1}) do
							local oS = oe == 1 and oEnd1 or oEnd2
							if math.abs(oS - wk.perp) < 6 and (o.s2 - o.s1) > 8 then
								table.insert(opts, {w = o, enter = oe, corner = true})
							end
						end
					end
				end
			end
		end
		wk.next[e] = opts
	end
end

-- ===== districts: who walks where =====
-- business districts keep their key; home neighborhoods are "hood_<key>"
local DISTRICT_AT = {}
for _, p in ipairs(map.places or {}) do
	if p.at and (p.kind == "Business district" or p.kind == "Neighborhood") then
		table.insert(DISTRICT_AT, {key = (p.kind == "Neighborhood" and "hood_" or "") .. p.key, biz = p.kind == "Business district" and p.key or nil, x = p.at[1], z = p.at[2]})
	end
end
function CC.zoneAt(pos)
	if pos.Z > 300 and math.abs(pos.X) < 300 then return "beach" end
	local best, bd = nil, 190
	for _, dd in ipairs(DISTRICT_AT) do
		local d = math.sqrt((pos.X - dd.x) ^ 2 + (pos.Z - dd.z) ^ 2)
		if d < bd then best, bd = dd.key, d end
	end
	return best or "city"
end
-- archetypes: outfit colors + an accessory + how they move
local LOOKS = {
	suit = {shirt = {RGB(40, 44, 60), RGB(70, 70, 80), RGB(30, 40, 70)}, pants = {RGB(30, 30, 36)}, acc = "briefcase", speed = {6, 7.5}},
	coffee = {shirt = {RGB(200, 200, 205), RGB(120, 140, 170)}, pants = {RGB(50, 55, 70)}, acc = "cup", speed = {5, 6.5}},
	worker = {shirt = {RGB(255, 200, 40), RGB(255, 140, 30)}, pants = {RGB(60, 70, 100)}, acc = "hardhat", speed = {4.5, 6}},
	swim = {shirt = {RGB(255, 120, 150), RGB(70, 200, 230), RGB(255, 220, 80)}, pants = {RGB(255, 120, 150), RGB(60, 140, 230)}, acc = "surf", speed = {4, 5.5}},
	jogger = {shirt = {RGB(240, 70, 70), RGB(60, 200, 120), RGB(250, 250, 250)}, pants = {RGB(30, 30, 34)}, acc = nil, speed = {10, 12}, jog = true},
	dog = {shirt = {RGB(120, 160, 110), RGB(170, 120, 90)}, pants = {RGB(60, 60, 80)}, acc = "dog", speed = {3.5, 4.5}},
	tourist = {shirt = {RGB(255, 170, 60), RGB(120, 220, 120), RGB(80, 170, 255), RGB(240, 90, 200)}, pants = {RGB(220, 200, 160), RGB(60, 70, 110)}, acc = "bag", speed = {4, 5.5}},
	hiker = {shirt = {RGB(90, 120, 70), RGB(170, 90, 50)}, pants = {RGB(80, 70, 55)}, acc = "backpack", speed = {4.5, 5.5}},
	casual = {shirt = {RGB(90, 120, 200), RGB(200, 90, 90), RGB(90, 170, 90), RGB(230, 230, 230), RGB(60, 60, 70)}, pants = {RGB(50, 60, 110), RGB(40, 40, 45)}, acc = nil, speed = {4.5, 6.5}},
}
CC.LOOKS = LOOKS
local MIX = {
	downtown = {suit = 5, coffee = 3, casual = 2},
	midtown = {casual = 4, coffee = 2, tourist = 2, suit = 1},
	industrial = {worker = 8, casual = 1},
	beach = {swim = 5, jogger = 1, tourist = 2, casual = 1},
	suburbs = {jogger = 2, dog = 3, casual = 4},
	entertainment = {tourist = 5, casual = 3},
	luxury = {suit = 3, dog = 2, jogger = 2},
	expansion = {worker = 4, casual = 3},
	hood_oldtown = {casual = 4, dog = 2, jogger = 1, tourist = 1},
	hood_suburbs = {jogger = 3, dog = 3, casual = 3},
	hood_ocean = {swim = 3, jogger = 3, dog = 1},
	hood_hills = {hiker = 5, jogger = 2, suit = 1},
	hood_rich = {suit = 3, dog = 3, jogger = 2},
	city = {casual = 5, coffee = 1, tourist = 1, jogger = 1},
}
CC.MIX = MIX
local function pickLook(zone)
	local mix = MIX[zone] or MIX.city
	local total = 0
	for _, w in pairs(mix) do total += w end
	local r = math.random() * total
	for k, w in pairs(mix) do
		r -= w
		if r <= 0 then return k end
	end
	return "casual"
end

-- ===== parts (client-only, no collision, no queries) =====
local FX = Instance.new("Folder")
FX.Name = "CityCrowd"
FX.Parent = Workspace
local function part(size, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = FX
	return p
end
local SKIN = {RGB(255, 220, 180), RGB(235, 190, 150), RGB(190, 140, 100), RGB(125, 88, 62)}
local HAIR = {RGB(40, 30, 25), RGB(90, 60, 30), RGB(230, 200, 120), RGB(160, 60, 30), RGB(20, 20, 20)}
-- a person: {parts = {{part, offset-fn-key}}, ...}; built once per pool slot and re-dressed when recycled
local function buildPerson()
	local n = {
		torso = part(V3(2, 2, 1), RGB(255, 255, 255)), head = part(V3(1.3, 1.3, 1.3), SKIN[1], nil, Enum.PartType.Ball), hair = part(V3(1.35, 0.5, 1.35), HAIR[1]),
		la = part(V3(0.9, 2, 0.9), RGB(255, 255, 255)), ra = part(V3(0.9, 2, 0.9), RGB(255, 255, 255)),
		ll = part(V3(0.95, 2, 0.95), RGB(40, 40, 40)), rl = part(V3(0.95, 2, 0.95), RGB(40, 40, 40)),
		acc = part(V3(1, 1, 1), RGB(255, 255, 255)),
		dog = part(V3(1, 1.1, 2.2), RGB(150, 110, 70)),
	}
	return n
end
local function dress(n, look)
	local L = LOOKS[look]
	local shirt = L.shirt[math.random(#L.shirt)]
	n.torso.Color, n.la.Color, n.ra.Color = shirt, shirt, shirt
	local pants = L.pants[math.random(#L.pants)]
	n.ll.Color, n.rl.Color = pants, pants
	local skin = SKIN[math.random(#SKIN)]
	n.head.Color = skin
	n.hair.Color = HAIR[math.random(#HAIR)]
	if look == "swim" then n.la.Color, n.ra.Color = skin, skin end
	local acc = L.acc
	n.accKind = acc
	if acc == "briefcase" then n.acc.Size, n.acc.Color = V3(0.4, 1.2, 1.6), RGB(70, 45, 30)
	elseif acc == "cup" then n.acc.Size, n.acc.Color = V3(0.5, 0.7, 0.5), RGB(240, 240, 235)
	elseif acc == "hardhat" then n.acc.Size, n.acc.Color = V3(1.5, 0.6, 1.5), RGB(255, 210, 30)
	elseif acc == "surf" then n.acc.Size, n.acc.Color = V3(0.3, 5.5, 1.5), Color3.fromHSV(math.random(), 0.6, 1)
	elseif acc == "bag" then n.acc.Size, n.acc.Color = V3(0.5, 1.2, 1.1), Color3.fromHSV(math.random(), 0.5, 0.95)
	elseif acc == "backpack" then n.acc.Size, n.acc.Color = V3(1.6, 1.8, 0.8), RGB(60, 90, 140)
	end
	n.acc.Transparency = (acc and acc ~= "dog") and 0 or 1
	n.dog.Transparency = acc == "dog" and 0 or 1
	n.dog.Color = ({RGB(150, 110, 70), RGB(240, 230, 210), RGB(40, 35, 30)})[math.random(3)]
end
local PERSON_KEYS = {"torso", "head", "hair", "la", "ra", "ll", "rl", "acc", "dog"}
local function hidePerson(n)
	for _, k in ipairs(PERSON_KEYS) do n[k].Transparency = 1 end
end
local function showPerson(n)
	for _, k in ipairs({"torso", "head", "hair", "la", "ra", "ll", "rl"}) do n[k].Transparency = 0 end
	n.acc.Transparency = (n.accKind and n.accKind ~= "dog") and 0 or 1
	n.dog.Transparency = n.accKind == "dog" and 0 or 1
end
-- pose: walking swing, standing still, arm up (phone / cup), or a little wave (chatting)
local function pose(n, cf, phase, mode)
	local sw = mode == "walk" and math.sin(phase) * 0.6 or 0
	n.torso.CFrame = cf * CF(0, 3, 0)
	n.head.CFrame = cf * CF(0, 4.65, 0)
	n.hair.CFrame = cf * CF(0, 5.2, 0.05)
	n.ll.CFrame = cf * CF(-0.5, 2, 0) * CFrame.Angles(sw, 0, 0) * CF(0, -1, 0)
	n.rl.CFrame = cf * CF(0.5, 2, 0) * CFrame.Angles(-sw, 0, 0) * CF(0, -1, 0)
	n.la.CFrame = cf * CF(-1.45, 3.9, 0) * CFrame.Angles(-sw, 0, 0) * CF(0, -0.9, 0)
	local raise = (mode == "phone" or n.accKind == "cup") and -1.9 or (mode == "chat" and (-0.6 + math.sin(phase * 0.7) * 0.5) or sw)
	n.ra.CFrame = cf * CF(1.45, 3.9, 0) * CFrame.Angles(raise, 0, 0) * CF(0, -0.9, 0)
	local a = n.accKind
	if a == "briefcase" or a == "bag" then n.acc.CFrame = cf * CF(-1.5, 1.9, 0)
	elseif a == "cup" then n.acc.CFrame = n.ra.CFrame * CF(0, -1.1, -0.4)
	elseif a == "hardhat" then n.acc.CFrame = cf * CF(0, 5.45, 0)
	elseif a == "surf" then n.acc.CFrame = cf * CF(1.6, 3.2, 0.4) * CFrame.Angles(0, 0, 0.12)
	elseif a == "backpack" then n.acc.CFrame = cf * CF(0, 3.1, 0.9)
	elseif a == "dog" then
		local bob = math.abs(math.sin(phase * 1.6)) * 0.25
		n.dog.CFrame = cf * CF(-2.4, 0.85 + bob, -2.6)
	end
	if mode == "phone" then n.acc.CFrame = n.acc.CFrame end
end

-- ===== vehicles =====
local function buildCar(kind)
	local parts = {}
	local function add(size, off, color, mat, shape, tr)
		local p = part(size, color, mat, shape)
		if tr then p.Transparency = tr end
		table.insert(parts, {p, off, tr or 0})
		return p
	end
	local len = 13
	if kind == "bus" then
		len = 26
		local col = RGB(40, 120, 220)
		add(V3(7, 6.5, 26), CF(0, 4.2, 0), col)
		add(V3(7.1, 1.8, 24), CF(0, 5.6, 0), RGB(30, 40, 55), Enum.Material.Glass, nil, 0.2)
		add(V3(7.15, 0.5, 26.1), CF(0, 2.2, 0), RGB(250, 210, 60))
		local sign = add(V3(5, 1, 0.2), CF(0, 7.1, -13.05), RGB(20, 20, 24), Enum.Material.SmoothPlastic)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.LightInfluence = 0
		g.Parent = sign
		local t = Instance.new("TextLabel")
		t.Size, t.BackgroundTransparency, t.TextScaled, t.Text = UDim2.fromScale(1, 1), 1, true, "CITY LOOP"
		t.TextColor3, t.Font = RGB(255, 190, 60), Enum.Font.GothamBlack
		t.Parent = g
		for _, sz in ipairs({-9, 9}) do for _, sx in ipairs({-1, 1}) do add(V3(1, 2.8, 2.8), CF(sx * 3.3, 1.4, sz) * CFrame.Angles(0, 0, math.rad(90)), RGB(25, 25, 28), nil, Enum.PartType.Cylinder) end end
	elseif kind == "van" then
		len = 15
		add(V3(6.4, 6, 10), CF(0, 4, 2), RGB(245, 245, 245))
		add(V3(6.2, 4.2, 5), CF(0, 3.1, -5.2), RGB(230, 120, 40))
		add(V3(5.6, 1.8, 0.2), CF(0, 4.4, -7.75), RGB(35, 45, 60), Enum.Material.Glass, nil, 0.2)
		local logo = add(V3(0.2, 2.2, 6), CF(3.25, 4.5, 2), RGB(230, 120, 40))
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Right
		g.LightInfluence = 0
		g.Parent = logo
		local t = Instance.new("TextLabel")
		t.Size, t.BackgroundTransparency, t.TextScaled, t.Text = UDim2.fromScale(1, 1), 1, true, "📦 DELIVERY"
		t.TextColor3, t.Font = RGB(255, 255, 255), Enum.Font.GothamBlack
		t.Parent = g
		for _, sz in ipairs({-5, 4.5}) do for _, sx in ipairs({-1, 1}) do add(V3(0.9, 2.6, 2.6), CF(sx * 2.9, 1.3, sz) * CFrame.Angles(0, 0, math.rad(90)), RGB(25, 25, 28), nil, Enum.PartType.Cylinder) end end
	else
		local col = kind == "taxi" and RGB(255, 205, 40) or (kind == "sport" and Color3.fromHSV(math.random(), 0.85, 0.95) or Color3.fromHSV(math.random(), 0.45, 0.85))
		local h = kind == "sport" and 1.6 or 2.2
		add(V3(6, h, 13), CF(0, 1.2 + h / 2, 0), col)
		add(V3(5.2, kind == "sport" and 1.6 or 2.4, kind == "sport" and 5 or 6), CF(0, 1.2 + h + (kind == "sport" and 0.8 or 1.2), 0.8), RGB(35, 45, 60), Enum.Material.Glass, nil, 0.2)
		if kind == "taxi" then add(V3(2.4, 0.8, 1), CF(0, 1.2 + h + 2.8, 0.8), RGB(255, 250, 230), Enum.Material.Neon) end
		for _, sx in ipairs({-1.9, 1.9}) do
			add(V3(1.2, 0.5, 0.2), CF(sx, 2.4, -6.6), RGB(255, 250, 225), Enum.Material.Neon)
			add(V3(1.2, 0.5, 0.2), CF(sx, 2.4, 6.55), RGB(255, 40, 40), Enum.Material.Neon)
		end
		for _, sz in ipairs({-4, 4}) do for _, sx in ipairs({-1, 1}) do add(V3(0.9, 2.6, 2.6), CF(sx * 2.75, 1.3, sz) * CFrame.Angles(0, 0, math.rad(90)), RGB(25, 25, 28), nil, Enum.PartType.Cylinder) end end
	end
	return parts, len
end
local function placeCar(c, cf)
	for _, e in ipairs(c.parts) do e[1].CFrame = cf * e[2] end
end
local function showCar(c, on)
	for _, e in ipairs(c.parts) do e[1].Transparency = on and e[3] or 1 end
end
local CAR_KINDS = {{"sedan", 55}, {"taxi", 12}, {"van", 15}, {"bus", 7}, {"sport", 11}}
local function pickCarKind()
	local r = math.random(100)
	for _, k in ipairs(CAR_KINDS) do
		r -= k[2]
		if r <= 0 then return k[1] end
	end
	return "sedan"
end

-- ===== state =====
local peds, cars = {}, {}
CC.peds, CC.cars = peds, cars
local function focus()
	local p = camera.CFrame.Position
	return V3(p.X, 0, p.Z), camera.CFrame.LookVector
end
local function behind(pos, f, look)
	local d = pos - f
	local flat = V3(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 or d.Magnitude < 0.01 then return true end
	return d.Unit:Dot(flat.Unit) < 0.2
end
local function walkPos(w, t) return roadPoint(w.r, t, w.perp, 0.3) end

-- pedestrians ------------------------------------------------------------------------------------------
-- the sidewalks / lanes that pass within `hi` of the camera (only those are worth trying)
local function nearWalks(f, hi)
	local out = {}
	for _, w in ipairs(WALKS) do
		local along = w.r.axis == "x" and f.X or f.Z
		local q = walkPos(w, math.clamp(along, w.s1, w.s2))
		if (q - f).Magnitude <= hi then table.insert(out, w) end
	end
	return out
end
local function spawnPed(p, f, look, initial, cand)
	cand = cand or nearWalks(f, CFG.pedFar)
	if #cand > 0 then
		for _ = 1, 30 do
			local w = cand[math.random(#cand)]
			local t = w.s1 + math.random() * (w.s2 - w.s1)
			local pos = walkPos(w, t)
			local dist = (pos - f).Magnitude
			local lo = initial and CFG.pedNear or CFG.pedNew
			if dist >= lo and dist <= CFG.pedFar and (initial or behind(pos, f, look) or dist > CFG.pedFar * 0.85) then
				p.w, p.t, p.dir = w, t, math.random() < 0.5 and 1 or -1
				p.zone = CC.zoneAt(pos)
				p.look = pickLook(p.zone)
				dress(p.n, p.look)
				local sp = LOOKS[p.look].speed
				p.speed = sp[1] + math.random() * (sp[2] - sp[1])
				p.mode, p.timer, p.nextIdle = "walk", 0, 6 + math.random() * 14
				p.cross, p.wait = nil, nil
				p.phase = math.random() * 6
				p.lane = (math.random() - 0.5) * 1.6   -- not everyone on the center line of the sidewalk
				showPerson(p.n)
				p.on = true
				return true
			end
		end
	end
	p.on = false
	hidePerson(p.n)
	return false
end
-- at the end of a sidewalk: cross (if the light lets us), turn the corner, or turn back
local function atEnd(p, e)
	local opts = p.w.next[e] or {}
	if #opts > 0 and math.random() < 0.85 then
		local o = opts[math.random(#opts)]
		if o.cross then
			-- crossing the other road: its traffic must be stopped, i.e. OUR axis has the green
			if hasLight(p.w.r, o.at) then
				if not CC.green(p.w.r.axis) then
					p.mode, p.wait = "wait", true
					return
				end
			end
			p.cross = {from = p.t, to = e == 1 and o.w.s1 or o.w.s2, w = o.w}
		else
			p.w = o.w
			p.t = o.enter == 1 and o.w.s1 or o.w.s2
			p.dir = o.enter
		end
		p.wait = nil
		p.mode = "walk"
	else
		p.dir = -p.dir
	end
end
local function stepPed(p, dt)
	p.phase += dt * (LOOKS[p.look].jog and 12 or 8)
	if p.mode == "wait" then
		local e = p.dir
		if CC.green(p.w.r.axis) then p.mode = "walk" atEnd(p, e) end
		return
	end
	if p.mode ~= "walk" then
		p.timer -= dt
		if p.timer <= 0 then p.mode = "walk" p.nextIdle = 8 + math.random() * 16 end
		return
	end
	p.nextIdle -= dt
	if p.nextIdle <= 0 and not p.cross and not LOOKS[p.look].jog then
		local r = math.random()
		p.mode = r < 0.45 and "shop" or (r < 0.8 and "phone" or "chat")
		p.timer = 3 + math.random() * 5
		return
	end
	p.t += p.dir * p.speed * dt
	if p.cross then
		if (p.t - p.cross.to) * p.dir >= 0 then
			p.w, p.t, p.cross = p.cross.w, p.cross.to, nil
		end
		return
	end
	if p.t > p.w.s2 then
		p.t = p.w.s2
		atEnd(p, 1)
	elseif p.t < p.w.s1 then
		p.t = p.w.s1
		atEnd(p, -1)
	end
end
local function pedCF(p)
	local w = p.w
	local perp = w.perp + p.lane * 0.6
	local pos = roadPoint(w.r, p.t, perp, 0.3)
	local fwd = w.r.axis == "x" and V3(p.dir, 0, 0) or V3(0, 0, p.dir)
	if p.mode == "shop" then
		-- turn to face away from the road (the shop windows)
		local away = w.r.axis == "x" and V3(0, 0, w.side) or V3(w.side, 0, 0)
		return CFrame.lookAt(pos, pos + away)
	end
	return CFrame.lookAt(pos, pos + fwd)
end

-- cars -------------------------------------------------------------------------------------------------
local function laneFree(r, dir, s, gap, me)
	for _, o in ipairs(cars) do
		if o ~= me and o.on and o.r == r and o.dir == dir and math.abs(o.s - s) < gap then return false end
	end
	return true
end
local function nearRoads(f, hi)
	local out = {}
	for _, r in ipairs(ROADS) do
		local along = r.axis == "x" and f.X or f.Z
		local q = roadPoint(r, math.clamp(along, r.a, r.b), r.c, 0)
		if (V3(q.X, 0, q.Z) - f).Magnitude <= hi then table.insert(out, r) end
	end
	return out
end
local function spawnCar(c, f, look, initial, cand)
	cand = cand or nearRoads(f, CFG.carFar)
	if #cand > 0 then
		for _ = 1, 30 do
			local r = cand[math.random(#cand)]
			local dir = math.random() < 0.5 and 1 or -1
			local s = r.a + 10 + math.random() * (r.b - r.a - 20)
			local pos = roadPoint(r, s, laneOf(r, dir), 0)
			local dist = (pos - f).Magnitude
			local lo = initial and CFG.carNear or CFG.carNew
			-- not right in the middle of a crossing
			-- not in a crossing, and not just before one (a car must be able to stop for a red light)
			local inCrossing = false
			for _, x in ipairs(r.cuts) do
				local ahead = (x - s) * dir
				if math.abs(s - x) < 14 or (ahead > 0 and ahead < 45) then inCrossing = true end
			end
			if not inCrossing and dist >= lo and dist <= CFG.carFar and (initial or behind(pos, f, look) or dist > CFG.carFar * 0.85) and laneFree(r, dir, s, 30) then
				c.r, c.dir, c.s = r, dir, s
				c.vmax = (r.w >= 14 and 30 or (r.w >= 12 and 24 or 18)) * (0.85 + math.random() * 0.3)
				if c.kind == "bus" then c.vmax *= 0.75 end
				c.v = c.vmax * 0.6
				c.blend = nil
				showCar(c, true)
				c.on = true
				return true
			end
		end
	end
	c.on = false
	showCar(c, false)
	return false
end
-- the next crossing ahead of a car (and whether it has a light)
local function nextCut(c)
	local best
	for _, x in ipairs(c.r.nodes) do
		if (x - c.s) * c.dir > 0.5 and (not best or math.abs(x - c.s) < math.abs(best - c.s)) then best = x end
	end
	return best
end
local function carCF(c)
	local r = c.r
	local pos = roadPoint(r, c.s, laneOf(r, c.dir), 0.2)
	local fwd = r.axis == "x" and V3(c.dir, 0, 0) or V3(0, 0, c.dir)
	local cf = CFrame.lookAt(pos, pos + fwd)
	if c.blend then
		local a = math.clamp(c.blend.t / 0.7, 0, 1)
		cf = c.blend.from:Lerp(cf, a)
	end
	return cf
end
local function turnAt(c, x)
	local r2 = NODES[c.r.i][x]
	local opts = {}
	-- straight on (weighted)
	if (c.dir == 1 and c.r.b - x > 20) or (c.dir == -1 and x - c.r.a > 20) then
		table.insert(opts, {r = c.r, dir = c.dir, s = x}) table.insert(opts, opts[1])
	end
	if r2 then
		for _, d2 in ipairs({1, -1}) do
			-- only turn into a lane that has room where we'd join it
			if ((d2 == 1 and r2.b - c.r.c > 20) or (d2 == -1 and c.r.c - r2.a > 20)) and laneFree(r2, d2, c.r.c + d2 * 2, c.len + 8, c) then
				table.insert(opts, {r = r2, dir = d2, s = c.r.c})
			end
		end
	end
	if #opts == 0 then
		if (c.dir == 1 and x >= c.r.b - 0.5) or (c.dir == -1 and x <= c.r.a + 0.5) then
			c.s, c.v = x - c.dir * 0.1, 0   -- the end of the road: wait at the junction for room to turn
		end
		return
	end
	local o = opts[math.random(#opts)]
	if o.r ~= c.r then
		c.blend = {from = carCF(c), t = 0}
		c.r, c.dir, c.s = o.r, o.dir, o.s + o.dir * 2
		c.passed = nil
	end
end
local BRAKE, MAXBRAKE = 22, 40   -- planned braking (studs/s²) and what the brakes can actually do
local function stepCar(c, dt)
	local r = c.r
	if c.blend then
		c.blend.t += dt
		if c.blend.t >= 0.7 then c.blend = nil end
	end
	local want = c.vmax
	-- red light ahead: stop at the line
	local x = nextCut(c)
	if x and hasLight(r, x) and not CC.green(r.axis) then
		local stopLine = x - c.dir * 13
		local dist = (stopLine - c.s) * c.dir
		-- red: always stop at the line. Yellow: stop if there's room to, otherwise clear the crossing.
		-- (a car already over the line keeps going)
		-- yellow: carry on only if we'll be over the line before it turns red; otherwise stop (hard if we must)
		local _, _, left = CC.phase()
		local makesIt = c.v > 1 and (dist / c.v) < left - 0.1
		if dist > -1 and (CC.red(r.axis) or not makesIt) then
			-- the speed from which we can still stop at the line (brakes never need more than BRAKE)
			want = dist < 0.5 and 0 or math.min(want, math.sqrt(2 * BRAKE * (dist - 0.5)))
		end
	end
	-- the end of the road ahead: stop there unless it's a junction we can turn at
	do
		local endS = c.dir == 1 and r.b or r.a
		local node = NODES[r.i][endS]
		local stopAt = node and endS or (endS - c.dir * 8)
		local dist = (stopAt - c.s) * c.dir
		local canTurn = false
		if node then
			for _, d2 in ipairs({1, -1}) do
				if ((d2 == 1 and node.b - r.c > 20) or (d2 == -1 and r.c - node.a > 20)) and laneFree(node, d2, r.c + d2 * 2, c.len + 8, c) then canTurn = true end
			end
		end
		if dist > 0 and not canTurn then want = math.min(want, math.sqrt(2 * BRAKE * math.max(0, dist - 0.5))) end
	end
	-- the car in front (same road, same direction)
	for _, o in ipairs(cars) do
		if o ~= c and o.on and o.r == r and o.dir == c.dir then
			local ahead = (o.s - c.s) * c.dir
			if ahead > 0 then
				local gap = ahead - (o.len + c.len) / 2 - 3
				want = math.min(want, o.v + math.sqrt(2 * BRAKE * math.max(0, gap)) * 0.5, math.max(0, gap) * 1.4 + o.v)
			end
		end
	end
	local dv = want - c.v
	c.v += math.clamp(dv, -MAXBRAKE * dt, 10 * dt)
	if c.v < 0 then c.v = 0 end
	local before = c.s
	c.s += c.dir * c.v * dt
	-- passed the middle of a junction: maybe turn (at a junction at the end of the road: must turn)
	for _, cx in ipairs(r.nodes) do
		if (before - cx) * c.dir < 0 and (c.s - cx) * c.dir >= 0 then
			turnAt(c, cx)
			break
		end
	end
	-- a dead end (no junction): U-turn once the other lane has room
	if c.r == r and ((c.dir == 1 and c.s > r.b - 8) or (c.dir == -1 and c.s < r.a + 8)) and not NODES[r.i][c.dir == 1 and r.b or r.a] then
		if laneFree(r, -c.dir, c.s, c.len + 8, c) then
			c.blend = {from = carCF(c), t = 0}
			c.dir = -c.dir
		else
			c.v = 0
		end
	end
end

-- ===== small things going on (built once, shown when you are near) =====
local SPOTS = {}
CC.SPOTS = SPOTS
local function walkNear(zone)
	-- the sidewalk segment closest to a district's center
	local best, bd
	for _, dd in ipairs(DISTRICT_AT) do
		if dd.biz == zone then
			for _, w in ipairs(WALKS) do
				local mid = walkPos(w, (w.s1 + w.s2) / 2)
				local d = (mid - V3(dd.x, 0.3, dd.z)).Magnitude
				if (w.s2 - w.s1) > 30 and (not bd or d < bd) then best, bd = w, d end
			end
		end
	end
	return best
end
local function addSpot(kind, cf)
	local s = {kind = kind, cf = cf, parts = {}, people = {}}
	local function add(size, off, color, mat, shape)
		local p = part(size, color, mat, shape)
		p.CFrame = cf * off
		table.insert(s.parts, p)
		return p
	end
	if kind == "musician" then
		local n = buildPerson()
		dress(n, "casual")
		table.insert(s.people, {n = n, off = CF(0, 0, 0), mode = "chat"})
		add(V3(1.6, 0.7, 1), CF(1.6, 0.65, -0.6), RGB(90, 50, 30), Enum.Material.Wood)   -- guitar case
		local note = add(V3(0.2, 0.2, 0.2), CF(0, 7, 0), RGB(255, 255, 255))
		note.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size, bb.MaxDistance, bb.LightInfluence = UDim2.fromOffset(60, 40), 70, 0
		bb.Parent = note
		local t = Instance.new("TextLabel")
		t.Size, t.BackgroundTransparency, t.TextScaled, t.Text, t.TextColor3 = UDim2.fromScale(1, 1), 1, true, "♪ ♫", RGB(255, 230, 120)
		t.Parent = bb
		s.note = note
		for i = 1, 3 do
			local w = buildPerson()
			dress(w, "tourist")
			table.insert(s.people, {n = w, off = CF(-3 + i * 2.2, 0, -4.2) * CFrame.Angles(0, math.pi, 0), mode = "stand"})
		end
	elseif kind == "hotdog" then
		add(V3(4, 2.6, 2.4), CF(0, 1.6, 0), RGB(220, 60, 50))
		add(V3(4.6, 0.3, 3), CF(0, 5.4, 0), RGB(255, 230, 120), Enum.Material.Fabric)
		add(V3(0.25, 2.6, 0.25), CF(0, 4.1, 0), RGB(200, 200, 205), Enum.Material.Metal)
		local sign = add(V3(3.6, 0.9, 0.2), CF(0, 3.4, -1.25), RGB(255, 255, 255))
		local g = Instance.new("SurfaceGui")
		g.Face, g.LightInfluence = Enum.NormalId.Front, 0
		g.Parent = sign
		local t = Instance.new("TextLabel")
		t.Size, t.BackgroundTransparency, t.TextScaled, t.Text, t.TextColor3, t.Font = UDim2.fromScale(1, 1), 1, true, "🌭 HOT DOGS", RGB(200, 40, 40), Enum.Font.GothamBlack
		t.Parent = g
		local v = buildPerson()
		dress(v, "casual")
		v.torso.Color = RGB(250, 250, 250)
		table.insert(s.people, {n = v, off = CF(0, 0, 2) * CFrame.Angles(0, math.pi, 0), mode = "stand"})
		for i = 1, 3 do
			local q = buildPerson()
			dress(q, i == 1 and "suit" or "casual")
			table.insert(s.people, {n = q, off = CF(0, 0, -2.6 - i * 2.1), mode = i == 1 and "stand" or "phone"})
		end
	elseif kind == "umbrella" then
		add(V3(0.3, 8, 0.3), CF(0, 4, 0), RGB(240, 240, 240))
		add(V3(9, 0.6, 9), CF(0, 8, 0), Color3.fromHSV(math.random(), 0.55, 1), Enum.Material.Fabric, Enum.PartType.Cylinder).CFrame = cf * CF(0, 8, 0) * CFrame.Angles(0, 0, math.rad(90))
		for i = -1, 1, 2 do
			add(V3(2.6, 0.15, 6), CF(i * 2, 0.2, 2.5), Color3.fromHSV(math.random(), 0.5, 1), Enum.Material.Fabric)
			local b = buildPerson()
			dress(b, "swim")
			b.accKind = nil
			table.insert(s.people, {n = b, off = CF(i * 2, 0.6, 2.5) * CFrame.Angles(-math.pi / 2, 0, 0) * CF(0, -3, 0), mode = "lie"})
		end
	elseif kind == "volley" then
		add(V3(0.3, 8, 0.3), CF(-8, 4, 0), RGB(240, 240, 240))
		add(V3(0.3, 8, 0.3), CF(8, 4, 0), RGB(240, 240, 240))
		add(V3(16, 2.5, 0.1), CF(0, 6.5, 0), RGB(250, 250, 250), Enum.Material.Fabric).Transparency = 0.4
		s.ball = add(V3(1.2, 1.2, 1.2), CF(0, 9, 0), RGB(255, 240, 120), nil, Enum.PartType.Ball)
		for i = -1, 1, 2 do
			local b = buildPerson()
			dress(b, "swim")
			b.accKind = nil
			table.insert(s.people, {n = b, off = CF(0, 0, i * 7) * CFrame.Angles(0, i == 1 and 0 or math.pi, 0), mode = "chat"})
		end
	end
	for _, pp in ipairs(s.people) do hidePerson(pp.n) end
	for _, p in ipairs(s.parts) do p:SetAttribute("T", p.Transparency) p.Transparency = 1 end
	s.on = false
	table.insert(SPOTS, s)
	return s
end
do
	-- a street musician downtown and in the entertainment district, hot-dog carts in midtown and downtown
	for _, z in ipairs({{"musician", "downtown"}, {"musician", "entertainment"}, {"hotdog", "midtown"}, {"hotdog", "downtown"}}) do
		local w = walkNear(z[2])
		if w then
			local t = w.s1 + (w.s2 - w.s1) * (z[1] == "hotdog" and 0.3 or 0.65)
			local edge = w.perp + w.side * 1.2
			local pos = roadPoint(w.r, t, edge, 0.3)
			local away = w.r.axis == "x" and V3(0, 0, w.side) or V3(w.side, 0, 0)
			-- the cart runs along the sidewalk; the musician faces the street
			local cf = z[1] == "hotdog" and CFrame.lookAt(pos, pos + (w.r.axis == "x" and V3(1, 0, 0) or V3(0, 0, 1))) or CFrame.lookAt(pos, pos - away)
			addSpot(z[1], cf)
		end
	end
	-- the beach: umbrellas with sunbathers and a volleyball game on the free sand beside the Empire Plaza
	for _, x in ipairs({-108, -88, 88, 108}) do addSpot("umbrella", CF(x, 0.2, 372) * CFrame.Angles(0, math.rad(math.random(0, 40) - 20), 0)) end
	addSpot("volley", CF(-97, 0.2, 405))
	addSpot("volley", CF(97, 0.2, 405))
end
local function spotPose(s, now)
	for i, pp in ipairs(s.people) do
		local cf = s.cf * pp.off
		pose(pp.n, cf, now * 3 + i, pp.mode == "stand" and "stand" or pp.mode)
	end
	if s.note then s.note.CFrame = s.cf * CF(0, 7 + math.sin(now * 2) * 0.4, 0) end
	if s.ball then
		local k = (now * 0.6) % 2
		local side = k < 1 and k or (2 - k)
		s.ball.CFrame = s.cf * CF(0, 7 + math.sin(side * math.pi) * 6, -6 + side * 12)
	end
end

-- ===== the pool =====
local pedPool, carPool = {}, {}
local function ensurePools()
	while #pedPool < CFG.peds.high do
		local p = {n = buildPerson(), on = false}
		hidePerson(p.n)
		table.insert(pedPool, p)
	end
	while #carPool < CFG.cars.high do
		local kind = pickCarKind()
		local parts, len = buildCar(kind)
		local c = {parts = parts, len = len, kind = kind, on = false}
		showCar(c, false)
		table.insert(carPool, c)
	end
end
ensurePools()
local function wantPeds() return CFG.peds[C.settings.crowd] or CFG.peds.high end
local function wantCars() return CFG.cars[C.settings.crowd] or CFG.cars.high end
local function refreshActive(initial, all)
	local f, look = focus()
	local wc, rc = nearWalks(f, CFG.pedFar), nearRoads(f, CFG.carFar)
	table.clear(peds)
	for i, p in ipairs(pedPool) do
		if i <= wantPeds() then
			if not p.on or all then spawnPed(p, f, look, initial, wc) end
			if p.on then table.insert(peds, p) end
		else
			p.on = false
			hidePerson(p.n)
		end
	end
	table.clear(cars)
	for i, c in ipairs(carPool) do
		if i <= wantCars() then
			if not c.on or all then spawnCar(c, f, look, initial, rc) end
			if c.on then table.insert(cars, c) end
		else
			c.on = false
			showCar(c, false)
		end
	end
end
CC.refresh = refreshActive
-- called by the Settings → Crowds button (and by WorldFX's old hook)
function CC.apply() refreshActive(true, true) end
U.applyCrowd = CC.apply
refreshActive(true, true)

-- recycle anything that fell behind (twice a second: cheap)
local recycleT, slowT = 0, 0
local lastF
local stats = {frames = 0, posed = 0}
CC.stats = stats
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local f, look = focus()
	local now = os.clock()
	recycleT += dt
	slowT += dt
	local slowTick = slowT >= 0.1
	if slowTick then slowT = 0 end
	if recycleT >= 0.5 then
		recycleT = 0
		if not lastF or (f - lastF).Magnitude > CFG.jump then
			-- a teleport (or the first frame): fill the new place right away
			refreshActive(true, true)
		else
			local wc, rc = nearWalks(f, CFG.pedFar), nearRoads(f, CFG.carFar)
			for _, p in ipairs(peds) do
				if p.on and (walkPos(p.w, p.t) - f).Magnitude > CFG.pedDrop then spawnPed(p, f, look, false, wc) end
			end
			for _, c in ipairs(cars) do
				if c.on and (roadPoint(c.r, c.s, laneOf(c.r, c.dir), 0) - f).Magnitude > CFG.carDrop then spawnCar(c, f, look, false, rc) end
			end
			if #peds < wantPeds() or #cars < wantCars() then refreshActive(false) end
		end
		lastF = f
		-- the little scenes: only built into view when you're close
		for _, s in ipairs(SPOTS) do
			local near = (s.cf.Position - f).Magnitude < 160 and C.settings.crowd ~= "off"
			if near ~= s.on then
				s.on = near
				for _, p in ipairs(s.parts) do p.Transparency = near and (p:GetAttribute("T") or 0) or 1 end
				for _, pp in ipairs(s.people) do if near then showPerson(pp.n) else hidePerson(pp.n) end end
			end
		end
	end
	stats.frames += 1
	for _, c in ipairs(cars) do
		if c.on then
			stepCar(c, dt)
			local cf = carCF(c)
			if slowTick or (cf.Position - f).Magnitude < CFG.lodNear then
				placeCar(c, cf)
				stats.posed += 1
			end
		end
	end
	for _, p in ipairs(peds) do
		if p.on then
			stepPed(p, dt)
			local cf = pedCF(p)
			if slowTick or (cf.Position - f).Magnitude < CFG.lodNear then
				pose(p.n, cf, p.phase, p.mode == "walk" and "walk" or p.mode)
				stats.posed += 1
			end
		end
	end
	if slowTick then
		for _, s in ipairs(SPOTS) do if s.on then spotPose(s, now) end end
	end
end)
end
