-- WORLD FX: customers, pedestrians, traffic, rides, traffic lights, marquees, weather, guide beams.
return function(C)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local new, tween, label, stars, U, plr, catalog, R = C.new, C.tween, C.label, C.stars, C.U, C.plr, C.catalog, C.R
local WHITE, GOLD, GREEN = C.WHITE, C.GOLD, C.GREEN
local camera = Workspace.CurrentCamera

local FX = Instance.new("Folder")
FX.Name = "ClientCity"
FX.Parent = Workspace
local function fxPart(size, color, mat)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Parent = FX
	return p
end

-- ===== people =====
local SKIN = {RGB(255, 220, 180), RGB(235, 190, 150), RGB(190, 140, 100), RGB(125, 88, 62)}
local HAIR = {RGB(40, 30, 25), RGB(90, 60, 30), RGB(230, 200, 120), RGB(160, 60, 30), RGB(20, 20, 20)}
local function makePerson(ti)
	local t = catalog.npcs[ti] or catalog.npcs[1]
	local skin = SKIN[math.random(#SKIN)]
	local n = {
		torso = fxPart(V3(2, 2, 1), t.shirt), head = fxPart(V3(1.3, 1.3, 1.3), skin), hair = fxPart(V3(1.35, 0.5, 1.35), HAIR[math.random(#HAIR)]),
		la = fxPart(V3(0.9, 2, 0.9), t.shirt), ra = fxPart(V3(0.9, 2, 0.9), t.shirt),
		ll = fxPart(V3(0.95, 2, 0.95), t.pants), rl = fxPart(V3(0.95, 2, 0.95), t.pants),
	}
	n.head.Shape = Enum.PartType.Ball
	if t.fancy then n.hat = fxPart(V3(1.4, 0.9, 1.4), RGB(20, 20, 24)) end
	return n
end
local function posePerson(n, cf, phase)
	local sw = math.sin(phase) * 0.6
	n.torso.CFrame = cf * CF(0, 3, 0)
	n.head.CFrame = cf * CF(0, 4.65, 0)
	n.hair.CFrame = cf * CF(0, 5.2, 0.05)
	n.ll.CFrame = cf * CF(-0.5, 2, 0) * CFrame.Angles(sw, 0, 0) * CF(0, -1, 0)
	n.rl.CFrame = cf * CF(0.5, 2, 0) * CFrame.Angles(-sw, 0, 0) * CF(0, -1, 0)
	n.la.CFrame = cf * CF(-1.45, 3.9, 0) * CFrame.Angles(-sw, 0, 0) * CF(0, -0.9, 0)
	n.ra.CFrame = cf * CF(1.45, 3.9, 0) * CFrame.Angles(sw, 0, 0) * CF(0, -0.9, 0)
	if n.hat then n.hat.CFrame = cf * CF(0, 5.45, 0) end
end
local function setVisible(parts, v)
	for _, p in pairs(parts) do
		if typeof(p) == "Instance" then
			p.Transparency = v and 0 or 1
		else
			p[1].Transparency = v and (p[3] or 0) or 1
		end
	end
end
local function removePerson(n)
	for _, p in pairs(n) do p:Destroy() end
end
local function floatBillboard(pos, lines, life)
	local a = fxPart(V3(0.2, 0.2, 0.2), WHITE)
	a.Transparency = 1
	a.CFrame = CF(pos)
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(230, 22 * #lines), MaxDistance = 90, LightInfluence = 0}, a)
	local labels = {}
	for i, ln in ipairs(lines) do
		labels[i] = label({Position = UDim2.fromScale(0, (i - 1) / #lines), Size = UDim2.fromScale(1, 1 / #lines), TextScaled = true, Text = ln[1], TextColor3 = ln[2],
			TextStrokeTransparency = 0.2, Font = Enum.Font.GothamBlack}, bb)
	end
	tween(a, life, {CFrame = CF(pos + V3(0, 4, 0))})
	for _, l in ipairs(labels) do tween(l, life, {TextTransparency = 1, TextStrokeTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In) end
	task.delay(life, function() a:Destroy() end)
end

-- customers walk from the street to the business door
local customers = {}
R.Customer.OnClientEvent:Connect(function(c)
	if c.rent then return end
	if #customers >= 45 or C.settings.crowd == "off" then return end
	local pts = {c.start, c.entry, c.door}
	local segs, total = {}, 0
	for i = 1, #pts - 1 do
		local len = (pts[i + 1] - pts[i]).Magnitude
		segs[i] = len
		total += len
	end
	table.insert(customers, {n = makePerson(c.npc), pts = pts, segs = segs, total = total, t = c.t, age = 0, review = c.review, door = c.door, shout = c.shout})
end)

-- (v13: the pedestrians and traffic that used to loop around fixed rectangles here are now CityCrowd: a pool that
-- keeps the area around you busy, on the real road network, obeying the traffic lights.)
-- (loop helpers and the car body are still used by the flying cars of the later City Eras, below)
local function loop(points)
	local segs, total = {}, 0
	for i = 1, #points do
		local a, b = points[i], points[i % #points + 1]
		segs[i] = (b - a).Magnitude
		total += segs[i]
	end
	return {pts = points, segs = segs, total = total}
end
local function loopAt(l, d)
	d = d % l.total
	for i, len in ipairs(l.segs) do
		if d <= len then
			local a, b = l.pts[i], l.pts[i % #l.pts + 1]
			local dir = (b - a).Unit
			return a + dir * d, dir
		end
		d -= len
	end
	return l.pts[1], V3(0, 0, -1)
end
local function makeTrafficCar()
	local col = Color3.fromHSV(math.random(), 0.55, 0.85)
	local parts = {}
	local function add(size, off, color, mat, shape, tr)
		local p = fxPart(size, color, mat)
		if shape then p.Shape = shape end
		if tr then p.Transparency = tr end
		table.insert(parts, {p, off, tr})
	end
	add(V3(6, 2.2, 13), CF(0, 2, 0), col)
	add(V3(6, 2.2, 2.2), CF(0, 2, -6.5) * CFrame.Angles(0, 0, math.rad(90)), col, nil, Enum.PartType.Cylinder)
	add(V3(5.2, 2.4, 6), CF(0, 4.3, 0.8), RGB(35, 45, 60), Enum.Material.Glass, nil, 0.2)
	add(V3(5.4, 0.25, 6.2), CF(0, 5.6, 0.8), col)
	for _, sx in ipairs({-1.9, 1.9}) do
		add(V3(1.2, 0.5, 0.2), CF(sx, 2.6, -6.6), RGB(255, 250, 225), Enum.Material.Neon)
		add(V3(1.2, 0.5, 0.2), CF(sx, 2.6, 6.55), RGB(255, 40, 40), Enum.Material.Neon)
		for _, sz in ipairs({-4, 4}) do
			add(V3(0.9, 2.6, 2.6), CF(sx * 1.45, 1.3, sz), RGB(25, 25, 28), nil, Enum.PartType.Cylinder)
			add(V3(0.95, 1.5, 1.5), CF(sx * 1.47, 1.3, sz), RGB(200, 200, 210), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	return parts
end

-- ===== WEATHER =====
local wxPart = fxPart(V3(90, 1, 90), WHITE)
wxPart.Transparency = 1
local wx = new("ParticleEmitter", {Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0, EmissionDirection = Enum.NormalId.Bottom,
	Speed = NumberRange.new(2), Lifetime = NumberRange.new(4, 6)}, wxPart)
local WEATHER = {
	none = {rate = 0},
	snow = {rate = 260, color = ColorSequence.new(WHITE), accel = V3(1, -6, 0), size = 0.45, life = 6, light = 0.4},
	rain = {rate = 450, color = ColorSequence.new(RGB(160, 190, 230)), accel = V3(0, -110, 0), size = 0.18, life = 1.3, light = 0.2},
	gold = {rate = 120, color = ColorSequence.new(RGB(255, 215, 80)), accel = V3(0, -25, 0), size = 0.6, life = 3, light = 1},
	confetti = {rate = 160, color = ColorSequence.new({ColorSequenceKeypoint.new(0, RGB(255, 80, 150)), ColorSequenceKeypoint.new(0.5, RGB(80, 200, 255)), ColorSequenceKeypoint.new(1, RGB(255, 220, 60))}), accel = V3(0, -14, 0), size = 0.55, life = 5, light = 0.8},
	heat = {rate = 40, color = ColorSequence.new(RGB(255, 160, 80)), accel = V3(0, -1.5, 0), size = 0.35, life = 6, light = 0.6},
}
function U.applyWeather()
	local w = WEATHER[Workspace:GetAttribute("Weather") or "none"] or WEATHER.none
	if not C.settings.weather then w = WEATHER.none end
	wx.Rate = w.rate
	if w.rate > 0 then
		wx.Color = w.color
		wx.Acceleration = w.accel
		wx.Size = NumberSequence.new(w.size)
		wx.Lifetime = NumberRange.new(w.life * 0.8, w.life)
		wx.LightEmission = w.light
	end
end
U.applyWeather()

-- ===== GUIDE BEAM (race > delivery > tutorial) =====
do
	local target = fxPart(V3(1, 1, 1), WHITE)
	target.Transparency = 1
	local att1 = new("Attachment", {}, target)
	local pillar = fxPart(V3(160, 3, 3), RGB(80, 255, 140), Enum.Material.Neon)
	pillar.Transparency = 0.55
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Parent = nil
	local beam = new("Beam", {Color = ColorSequence.new(RGB(80, 255, 140)), Width0 = 0.7, Width1 = 0.7, FaceCamera = true, LightEmission = 1,
		Transparency = NumberSequence.new(0.25), Segments = 20, Attachment1 = att1, Enabled = false}, target)
	local function hookChar(char)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if hrp then beam.Attachment0 = new("Attachment", {Name = "GuideAtt"}, hrp) end
	end
	if plr.Character then task.spawn(hookChar, plr.Character) end
	plr.CharacterAdded:Connect(hookChar)
	local targets = {}
	-- (v11.1: "heist" — the route home with loot — was set by the Heists HUD but never listed here, so it never
	-- showed; "arcade" is the Arcade app's way to a booth)
	local COLORS = {race = RGB(255, 210, 60), heist = RGB(255, 150, 40), delivery = RGB(80, 255, 140), job = RGB(60, 230, 200), tut = RGB(90, 170, 255), map = RGB(255, 120, 220), arcade = RGB(170, 110, 255)}
	local function refresh()
		local kind, pos
		for _, k in ipairs({"race", "heist", "delivery", "job", "tut", "map", "arcade"}) do
			if targets[k] then
				kind, pos = k, targets[k]
				break
			end
		end
		if not pos then
			beam.Enabled = false
			pillar.Parent = nil
			return
		end
		local col = COLORS[kind]
		beam.Color = ColorSequence.new(col)
		pillar.Color = col
		target.CFrame = CF(pos + V3(0, 3, 0))
		pillar.CFrame = CF(pos + V3(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Parent = FX
		beam.Enabled = true
	end
	function U.setBeamTarget(kind, pos)
		if targets[kind] == pos then return end
		targets[kind] = pos
		refresh()
	end
end

-- ===== rotating rides (ferris wheel, carousel) =====
local rotators = {}
local function addRotator(m)
	local hub = m:GetAttribute("Hub")
	if not hub then return end
	local hubCF = CF(hub)
	local entry = {model = m, hubCF = hubCF, axis = m:GetAttribute("Axis") or "Y", speed = m:GetAttribute("Speed") or 0.3, parts = {}}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local kind = p:GetAttribute("Kind")
			if kind == "gondola" then
				local hang = p:GetAttribute("Hang") or 0
				table.insert(entry.parts, {p = p, gondola = true, rel = hubCF:PointToObjectSpace(p.Position + V3(0, hang, 0)), hang = hang, rot = p.CFrame - p.Position})
			elseif kind == "spin" then
				table.insert(entry.parts, {p = p, rel = hubCF:ToObjectSpace(p.CFrame)})
			end
		end
	end
	rotators[m] = entry
end
for _, m in ipairs(CollectionService:GetTagged("Rotator")) do addRotator(m) end
CollectionService:GetInstanceAddedSignal("Rotator"):Connect(addRotator)

-- ===== PER-FRAME ANIMATION =====
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local camPos = camera.CFrame.Position
	for i = #customers, 1, -1 do
		local c = customers[i]
		c.age += dt
		local d = math.min(c.age / c.t, 1) * c.total
		local pos, dir = c.pts[1], V3(0, 0, -1)
		for k, len in ipairs(c.segs) do
			if d <= len or k == #c.segs then
				local a, b = c.pts[k], c.pts[k + 1]
				local diff = b - a
				dir = diff.Magnitude > 0.01 and diff.Unit or dir
				pos = a + dir * math.min(d, len)
				break
			end
			d -= len
		end
		local flat = V3(dir.X, 0, dir.Z)
		if flat.Magnitude < 0.01 then flat = V3(0, 0, -1) end
		posePerson(c.n, CFrame.lookAt(pos, pos + flat), c.age * 9)
		if c.age >= c.t then
			removePerson(c.n)
			table.remove(customers, i)
			local lines = {{"💵", GREEN}}
			if c.review then lines = {{stars(c.review.stars), GOLD}, {"\"" .. c.review.text .. "\"", WHITE}} end
			-- fans who recognize the owner (story chapter 3+)
			if c.shout then table.insert(lines, 1, {"🗣️ " .. c.shout, RGB(255, 140, 200)}) end
			floatBillboard(c.door + V3(0, 6, 0), lines, (c.review or c.shout) and 3.5 or 1.2)
			-- a soft "ka-ching" when it happens near you (v14)
			if C.jingle and (c.door - camPos).Magnitude < 70 then C.jingle("sale", 0.16) end
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("Spin")) do
		if p:IsA("BasePart") then
			local sp = p:GetAttribute("SpinSpeed") or 1
			p.CFrame = CF(p.Position) * CFrame.Angles(0, sp * dt, 0) * (p.CFrame - p.Position)
		end
	end
	local serverT = Workspace:GetServerTimeNow()
	for m, r in pairs(rotators) do
		if not m.Parent then
			rotators[m] = nil
		elseif (r.hubCF.Position - camPos).Magnitude < 700 then
			local th = serverT * r.speed
			local rot = r.axis == "Z" and CFrame.Angles(0, 0, th) or CFrame.Angles(0, th, 0)
			local base = r.hubCF * rot
			for _, e in ipairs(r.parts) do
				if e.gondola then
					e.p.CFrame = CF(base:PointToWorldSpace(e.rel) - V3(0, e.hang, 0)) * e.rot
				else
					e.p.CFrame = base * e.rel
				end
			end
		end
	end
	-- traffic lights: 8s per direction, yellow for the last 2s. Server time, so every client (and CityCrowd's cars
	-- and pedestrians) sees the same lights.
	local cyc = Workspace:GetServerTimeNow() % 16
	local phaseGreen = cyc < 8 and 0 or 1
	local yellow = (cyc % 8) > 6
	for _, m in ipairs(CollectionService:GetTagged("TrafficLight")) do
		local mine = m:GetAttribute("Phase") == phaseGreen
		local l1, l2, l3 = m:FindFirstChild("L1"), m:FindFirstChild("L2"), m:FindFirstChild("L3")
		if l1 and l2 and l3 then
			l1.Transparency = (not mine) and 0 or 0.8
			l2.Transparency = (mine and yellow) and 0 or 0.8
			l3.Transparency = (mine and not yellow) and 0 or 0.8
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("ChaseLights")) do
		local i = 0
		for _, b in ipairs(m:GetChildren()) do
			if b:IsA("BasePart") then
				i += 1
				local on = (math.floor(now * 8) + i) % 3 == 0
				b.Color = on and Color3.fromHSV((now * 0.2 + i * 0.07) % 1, 0.7, 1) or RGB(255, 230, 120)
				b.Transparency = on and 0 or 0.4
			end
		end
	end
	wxPart.CFrame = CF(camPos + V3(0, 28, 0))
end)

-- camera flashes (influencers filming a business that just went viral)
function U.flashes(pos)
	if (camera.CFrame.Position - pos).Magnitude > 400 then return end
	for i = 1, 14 do
		task.delay(i * 0.22, function()
			local p = fxPart(V3(0.8, 0.8, 0.8), WHITE, Enum.Material.Neon)
			p.Shape = Enum.PartType.Ball
			p.CFrame = CF(pos + V3(math.random(-6, 6), math.random(2, 7), math.random(-6, 6)))
			local l = Instance.new("PointLight")
			l.Brightness, l.Range = 6, 16
			l.Parent = p
			task.delay(0.12, function() p:Destroy() end)
		end)
	end
end

-- ===== MEGA EVENT MOVERS (the tornado) + CITY ERA LOOK =====
do
	local Lighting = game:GetService("Lighting")
	local movers = {}
	local function addMover(m)
		local parts = {}
		local from = m:GetAttribute("From")
		if not from then return end
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then table.insert(parts, {p = p, rel = p.Position - from}) end
		end
		movers[m] = parts
	end
	for _, m in ipairs(CollectionService:GetTagged("MegaMover")) do addMover(m) end
	CollectionService:GetInstanceAddedSignal("MegaMover"):Connect(addMover)
	-- era tint (a client-only effect so it never fights the server's event lighting) + flying cars from Era 4
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EraGrade"
	grade.Parent = Lighting
	local ERA_TINT = {Color3.new(1, 1, 1), Color3.fromRGB(255, 250, 240), Color3.fromRGB(240, 245, 255), Color3.fromRGB(225, 245, 255), Color3.fromRGB(245, 225, 255)}
	local flyers = {}
	local FLY_LOOPS = {
		loop({V3(-300, 60, -300), V3(300, 60, -300), V3(300, 60, 300), V3(-300, 60, 300)}),
		loop({V3(-200, 78, 200), V3(200, 78, 200), V3(200, 78, -200), V3(-200, 78, -200)}),
		loop({V3(-500, 70, 0), V3(500, 70, 0), V3(500, 70, 30), V3(-500, 70, 30)}),
	}
	local function applyEra()
		local era = Workspace:GetAttribute("Era") or 1
		grade.TintColor = ERA_TINT[math.clamp(era, 1, #ERA_TINT)]
		grade.Saturation = era >= 5 and 0.15 or 0
		if era >= 4 and #flyers == 0 then
			for i = 1, 9 do
				local parts = makeTrafficCar()
				for _, e in ipairs(parts) do
					if e[1].Material == Enum.Material.SmoothPlastic then e[1].Material = Enum.Material.Neon end
				end
				local l = FLY_LOOPS[(i - 1) % #FLY_LOOPS + 1]
				table.insert(flyers, {parts = parts, l = l, d = math.random() * l.total, speed = 40 + math.random() * 20})
			end
		end
		for _, f in ipairs(flyers) do setVisible(f.parts, era >= 4 and C.settings.crowd ~= "off") end
	end
	Workspace:GetAttributeChangedSignal("Era"):Connect(applyEra)
	applyEra()
	RunService.RenderStepped:Connect(function(dt)
		local st = Workspace:GetServerTimeNow()
		for m, parts in pairs(movers) do
			if not m.Parent then
				movers[m] = nil
			else
				local from, to = m:GetAttribute("From"), m:GetAttribute("To")
				local a = math.clamp((st - (m:GetAttribute("T0") or st)) / math.max(1, m:GetAttribute("Dur") or 1), 0, 1)
				local pos = from:Lerp(to, a)
				for _, e in ipairs(parts) do
					e.p.CFrame = CF(pos + e.rel) * (e.p.CFrame - e.p.Position)
				end
			end
		end
		if #flyers > 0 and (Workspace:GetAttribute("Era") or 1) >= 4 then
			for _, f in ipairs(flyers) do
				f.d += f.speed * dt
				local pos, dir = loopAt(f.l, f.d)
				local cf = CFrame.lookAt(pos, pos + dir) * CF(0, math.sin(f.d * 0.05) * 3, 0)
				for _, e in ipairs(f.parts) do e[1].CFrame = cf * e[2] end
			end
		end
	end)
end
end
