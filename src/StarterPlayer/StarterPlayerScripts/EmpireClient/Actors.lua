-- ACTORS: the shared kit for every scripted character the client draws: the story cast, cinematic actors,
-- the city's influencers, interior staff and customers, crowds and photographers.
-- Actors are a handful of anchored, non-colliding parts posed every frame by a small procedural animation
-- (no Humanoids, no physics), so they are cheap and always clean up with their folder.
-- Every look here is an original design; none of them copies a real person.
return function(C)
local Workspace = game:GetService("Workspace")
local RGB, V3, CF = Color3.fromRGB, Vector3.new, CFrame.new
local new, tween, label, corner = C.new, C.tween, C.label, C.corner
local WHITE = Color3.new(1, 1, 1)

local A = {}
C.Actors = A

function A.part(folder, size, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = folder
	return p
end
function A.folder(name)
	return new("Folder", {Name = name}, Workspace)
end

-- ===== looks =====
-- shirt, pants, skin; optional: hat (color) + hatKind, tophat, tie, headset, shades (color), prop (in the right hand),
-- jacket (a second torso layer), live = a floating LIVE sign, tag = a name tag
local SKIN = {RGB(255, 220, 180), RGB(235, 190, 150), RGB(190, 140, 100), RGB(125, 88, 62)}
A.SKIN = SKIN
A.LOOKS = {
	-- story cast
	rival = {shirt = RGB(255, 70, 140), pants = RGB(30, 30, 40), skin = RGB(190, 140, 100), hat = RGB(20, 20, 24), headset = true, live = true},
	kevin = {shirt = RGB(255, 210, 60), pants = RGB(90, 90, 110), skin = RGB(255, 220, 180), hat = RGB(255, 240, 120)},
	ulysses = {shirt = RGB(120, 200, 255), pants = RGB(40, 50, 70), skin = RGB(235, 190, 150), tie = RGB(255, 60, 60)},
	brenda = {shirt = RGB(170, 120, 255), pants = RGB(40, 30, 60), skin = RGB(125, 88, 62), tie = RGB(255, 255, 255)},
	reginald = {shirt = RGB(30, 30, 34), pants = RGB(30, 30, 34), skin = RGB(255, 225, 200), tophat = true, tie = RGB(255, 205, 80)},
	fan = {shirt = RGB(80, 200, 140), pants = RGB(60, 70, 120), skin = RGB(235, 190, 150)},
	-- the city's influencers (v9): original characters with their own colors and props
	baysnaps = {shirt = RGB(0, 200, 190), jacket = RGB(255, 120, 30), pants = RGB(40, 40, 60), skin = RGB(190, 140, 100), hat = RGB(255, 225, 40), hatKind = "beanie",
		shades = RGB(255, 60, 200), prop = "selfiestick", live = true},
	jaxcash = {shirt = RGB(245, 245, 250), jacket = RGB(20, 30, 70), pants = RGB(20, 30, 70), skin = RGB(235, 190, 150), shades = RGB(210, 170, 60), tie = RGB(210, 170, 60), prop = "keys"},
	mayamax = {shirt = RGB(250, 225, 235), jacket = RGB(190, 160, 240), pants = RGB(150, 225, 200), skin = RGB(125, 88, 62), hat = RGB(255, 250, 240), hatKind = "bucket",
		shades = RGB(60, 40, 30), prop = "camera"},
	drewdeals = {shirt = RGB(255, 255, 255), jacket = RGB(70, 160, 70), pants = RGB(70, 160, 70), skin = RGB(255, 220, 180), tie = RGB(255, 60, 60), hat = RGB(70, 160, 70),
		hatKind = "cap", prop = "briefcase"},
	-- city people
	tenant = {shirt = RGB(200, 200, 210), pants = RGB(90, 110, 160), skin = RGB(235, 190, 150), hat = RGB(120, 70, 50), hatKind = "messy"},
	inspector = {shirt = RGB(200, 180, 140), jacket = RGB(170, 150, 110), pants = RGB(90, 80, 60), skin = RGB(255, 220, 180), hat = RGB(110, 90, 60), hatKind = "fedora", prop = "clipboard"},
	photographer = {shirt = RGB(60, 60, 66), jacket = RGB(120, 110, 80), pants = RGB(40, 40, 46), skin = RGB(235, 190, 150), hat = RGB(30, 30, 30), hatKind = "cap", prop = "camera"},
	richkid = {shirt = RGB(120, 30, 120), jacket = RGB(150, 40, 150), pants = RGB(250, 250, 250), skin = RGB(255, 225, 200), hat = RGB(255, 210, 60), hatKind = "crown", prop = "goldcard"},
	investor = {shirt = RGB(250, 250, 250), jacket = RGB(80, 84, 96), pants = RGB(80, 84, 96), skin = RGB(190, 140, 100), tie = RGB(40, 90, 200), prop = "briefcase"},
	courier = {shirt = RGB(230, 50, 50), pants = RGB(40, 40, 50), skin = RGB(125, 88, 62), hat = RGB(230, 50, 50), hatKind = "cap", prop = "pizzabox"},
	staff = {shirt = RGB(255, 214, 60), pants = RGB(60, 70, 120), skin = RGB(235, 190, 150), apron = WHITE},
	customer = {shirt = RGB(120, 160, 240), pants = RGB(50, 50, 60), skin = RGB(235, 190, 150)},
	you = {shirt = RGB(80, 140, 255), pants = RGB(40, 40, 60), skin = RGB(235, 190, 150)},
}
-- a random city person (deterministic from a seed, so the same NPC looks the same each time)
function A.randomLook(seed)
	local r = Random.new(seed or math.random(1, 1e6))
	return {shirt = Color3.fromHSV(r:NextNumber(), 0.55, 0.9), pants = Color3.fromHSV(r:NextNumber(), 0.3, 0.35), skin = SKIN[r:NextInteger(1, #SKIN)],
		hat = r:NextNumber() < 0.3 and Color3.fromHSV(r:NextNumber(), 0.6, 0.8) or nil, hatKind = r:NextNumber() < 0.5 and "cap" or "beanie"}
end
-- the local player's own colors (from their avatar), for the "you" actor in cinematics
function A.lookOfCharacter(char)
	local look = table.clone(A.LOOKS.you)
	if not char then return look end
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		look.skin = bc.HeadColor3
		look.shirt = bc.TorsoColor3
		look.pants = bc.LeftLegColor3
	end
	local shirt = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if shirt and shirt:IsA("BasePart") then look.shirt = shirt.Color end
	return look
end

-- ===== building one =====
local PROPS = {
	selfiestick = function(f) return {A.part(f, V3(0.15, 3.2, 0.15), RGB(40, 40, 40), Enum.Material.Metal), A.part(f, V3(0.9, 1.4, 0.15), RGB(20, 20, 26), Enum.Material.Glass),
		A.part(f, V3(1.2, 1.2, 0.1), RGB(255, 250, 230), Enum.Material.Neon, Enum.PartType.Cylinder)} end,
	keys = function(f) return {A.part(f, V3(0.5, 0.7, 0.2), RGB(20, 20, 24)), A.part(f, V3(0.3, 0.3, 0.3), RGB(210, 170, 60), Enum.Material.Metal, Enum.PartType.Ball)} end,
	camera = function(f) return {A.part(f, V3(1.1, 0.8, 0.7), RGB(30, 30, 34)), A.part(f, V3(0.5, 0.5, 0.6), RGB(60, 60, 70), Enum.Material.Glass, Enum.PartType.Cylinder)} end,
	briefcase = function(f) return {A.part(f, V3(1.6, 1.1, 0.4), RGB(110, 70, 40), Enum.Material.Leather), A.part(f, V3(0.6, 0.15, 0.15), RGB(210, 170, 60), Enum.Material.Metal)} end,
	clipboard = function(f) return {A.part(f, V3(1, 1.3, 0.1), RGB(150, 110, 70), Enum.Material.Wood), A.part(f, V3(0.8, 1, 0.05), WHITE)} end,
	goldcard = function(f) return {A.part(f, V3(0.8, 0.5, 0.05), RGB(255, 210, 60), Enum.Material.Neon)} end,
	pizzabox = function(f) return {A.part(f, V3(1.8, 0.3, 1.8), RGB(220, 190, 140))} end,
	notice = function(f)
		local p = A.part(f, V3(1.6, 2, 0.08), RGB(255, 250, 240))
		local sg = new("SurfaceGui", {Face = Enum.NormalId.Front, CanvasSize = Vector2.new(120, 150), LightInfluence = 0}, p)
		label({Size = UDim2.fromScale(1, 0.3), Text = "EVICTION", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = RGB(200, 30, 30)}, sg)
		label({Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.25), Text = "NOTICE", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = RGB(200, 30, 30)}, sg)
		label({Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.35), Text = "please pack your stuff :)", TextScaled = true, TextColor3 = RGB(40, 40, 40)}, sg)
		return {p}
	end,
	box = function(f) return {A.part(f, V3(1.6, 1.4, 1.4), RGB(200, 160, 100), Enum.Material.Cardboard)} end,
	phone = function(f) return {A.part(f, V3(0.45, 0.8, 0.1), RGB(20, 20, 26), Enum.Material.Glass)} end,
	cup = function(f) return {A.part(f, V3(0.4, 0.6, 0.4), RGB(255, 240, 200), nil, Enum.PartType.Cylinder)} end,
	mop = function(f) return {A.part(f, V3(0.15, 4, 0.15), RGB(150, 110, 70), Enum.Material.Wood), A.part(f, V3(1, 0.4, 0.6), RGB(230, 230, 240), Enum.Material.Fabric)} end,
	tray = function(f) return {A.part(f, V3(1.6, 0.15, 1.1), RGB(120, 120, 130), Enum.Material.Metal), A.part(f, V3(0.6, 0.4, 0.6), RGB(230, 150, 60))} end,
}
function A.setProp(a, kind)
	if a.propParts then
		for _, p in ipairs(a.propParts) do p:Destroy() end
		a.propParts = nil
	end
	a.prop = kind
	if kind and PROPS[kind] then
		local ok, parts = pcall(PROPS[kind], a.folder)
		if ok then a.propParts = parts end
	end
end
function A.make(folder, look, opts)
	local L = type(look) == "table" and look or A.LOOKS[look] or A.LOOKS.fan
	opts = opts or {}
	local P = function(size, color, mat, shape) return A.part(folder, size, color, mat, shape) end
	local a = {
		folder = folder, look = type(look) == "string" and look or "custom", scale = opts.scale or 1,
		torso = P(V3(2, 2, 1), L.shirt), head = P(V3(1.4, 1.4, 1.4), L.skin, nil, Enum.PartType.Ball),
		la = P(V3(0.9, 2, 0.9), L.jacket or L.shirt), ra = P(V3(0.9, 2, 0.9), L.jacket or L.shirt),
		ll = P(V3(0.95, 2, 0.95), L.pants), rl = P(V3(0.95, 2, 0.95), L.pants),
		eyes = P(V3(0.9, 0.22, 0.1), RGB(20, 20, 20)),
	}
	if L.jacket then a.jacket = P(V3(2.15, 2.05, 1.12), L.jacket) a.jacketGap = P(V3(0.7, 2.06, 1.14), L.shirt) end
	if L.apron then a.apron = P(V3(1.7, 2.2, 0.1), L.apron) end
	if L.hat then
		local kind = L.hatKind or "cap"
		if kind == "beanie" then a.hat = P(V3(1.5, 0.8, 1.5), L.hat, Enum.Material.Fabric)
		elseif kind == "bucket" then a.hat = P(V3(1.9, 0.6, 1.9), L.hat, Enum.Material.Fabric)
		elseif kind == "fedora" then a.hat = P(V3(1.3, 0.6, 1.3), L.hat) a.brim = P(V3(2.1, 0.12, 2.1), L.hat)
		elseif kind == "crown" then a.hat = P(V3(1.2, 0.6, 1.2), L.hat, Enum.Material.Neon)
		elseif kind == "messy" then a.hat = P(V3(1.6, 0.6, 1.6), L.hat, Enum.Material.Grass)
		else a.hat = P(V3(1.5, 0.45, 1.5), L.hat) a.brim = P(V3(1.5, 0.12, 0.8), L.hat) end
		a.hatKind = kind
	end
	if L.tophat then a.hat = P(V3(1.1, 1.2, 1.1), RGB(20, 20, 20), nil, Enum.PartType.Cylinder) a.hatKind = "tophat" end
	if L.tie then a.tie = P(V3(0.35, 1.2, 0.1), L.tie) end
	if L.shades then a.shades = P(V3(1.2, 0.3, 0.15), L.shades, Enum.Material.Glass) end
	if L.headset then
		a.band = P(V3(1.6, 0.2, 0.3), RGB(30, 30, 30))
		a.mic = P(V3(0.12, 0.12, 0.8), RGB(30, 30, 30))
		a.micTip = P(V3(0.3, 0.3, 0.3), RGB(255, 60, 60), Enum.Material.Neon, Enum.PartType.Ball)
	end
	if L.live or opts.tag then
		local bb = new("BillboardGui", {Size = UDim2.fromOffset(L.live and 90 or 160, 30), StudsOffset = V3(0, 3.2, 0), AlwaysOnTop = true, MaxDistance = 140}, a.head)
		local f = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = L.live and RGB(230, 30, 50) or RGB(20, 20, 30), BackgroundTransparency = L.live and 0 or 0.3, BorderSizePixel = 0}, bb)
		corner(f, 8)
		label({Size = UDim2.fromScale(1, 1), Text = L.live and "🔴 LIVE" or opts.tag, TextScaled = true, Font = Enum.Font.GothamBlack}, f)
		if L.live and opts.tag then
			bb.Size = UDim2.fromOffset(170, 30)
			f:FindFirstChildOfClass("TextLabel").Text = "🔴 LIVE • " .. opts.tag
		end
	end
	if opts.prop or L.prop then A.setProp(a, opts.prop or L.prop) end
	a.base = CF()
	return a
end
function A.destroy(a)
	for k, v in pairs(a) do
		-- (never the shared folder the actor lives in: other actors are still using it)
		if k ~= "folder" and typeof(v) == "Instance" then v:Destroy() end
	end
	if a.propParts then for _, p in ipairs(a.propParts) do p:Destroy() end end
	a.dead = true
end
-- show / hide (an actor waiting off-stage)
function A.setVisible(a, on)
	for _, v in pairs(a) do
		if typeof(v) == "Instance" and v:IsA("BasePart") then v.LocalTransparencyModifier = on and 0 or 1 end
	end
	if a.propParts then for _, p in ipairs(a.propParts) do p.LocalTransparencyModifier = on and 0 or 1 end end
	a.hidden = not on
end

-- ===== posing =====
-- base = where they stand (facing -Z of the CFrame); p = {la, ra (arm swing), laz, raz (arm out), bounce, lean, tilt, kneel, sit, walk, look (head yaw)}
function A.pose(a, base, p)
	local y = (p.bounce or 0) - (p.kneel or 0) - (p.sit and 1.1 or 0)
	local root = base * CF(0, y, 0) * CFrame.Angles(p.lean or 0, p.turn or 0, p.tilt or 0)
	local sw = p.walk and math.sin(p.walk) * 0.6 or 0
	local head = root * CF(0, 4.7, 0) * CFrame.Angles(p.nod or 0, p.look or 0, 0)
	a.torso.CFrame = root * CF(0, 3, 0)
	a.head.CFrame = head
	a.eyes.CFrame = head * CF(0, 0.1, -0.68)
	if p.sit then
		a.ll.CFrame = root * CF(-0.5, 2, 0) * CFrame.Angles(1.5, 0, 0) * CF(0, -1, 0)
		a.rl.CFrame = root * CF(0.5, 2, 0) * CFrame.Angles(1.5, 0, 0) * CF(0, -1, 0)
	else
		a.ll.CFrame = root * CF(-0.5, 2 + (p.kneel or 0) * 0.5, 0) * CFrame.Angles(sw + (p.kneel and p.kneel > 0 and 1.2 or 0), 0, 0) * CF(0, -1, 0)
		a.rl.CFrame = root * CF(0.5, 2, 0) * CFrame.Angles(-sw, 0, 0) * CF(0, -1, 0)
	end
	local laCF = root * CF(-1.45, 3.9, 0) * CFrame.Angles(p.la or -sw, 0, p.laz or 0) * CF(0, -0.9, 0)
	local raCF = root * CF(1.45, 3.9, 0) * CFrame.Angles(p.ra or sw, 0, p.raz or 0) * CF(0, -0.9, 0)
	a.la.CFrame = laCF
	a.ra.CFrame = raCF
	if a.jacket then
		a.jacket.CFrame = root * CF(0, 3, 0)
		a.jacketGap.CFrame = root * CF(0, 3, -0.02)
	end
	if a.apron then a.apron.CFrame = root * CF(0, 2.6, -0.56) end
	if a.hat then
		local k = a.hatKind
		if k == "tophat" or a.look == "reginald" then a.hat.CFrame = head * CF(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		elseif k == "beanie" then a.hat.CFrame = head * CF(0, 0.55, 0.05)
		elseif k == "bucket" then a.hat.CFrame = head * CF(0, 0.6, 0)
		elseif k == "crown" then a.hat.CFrame = head * CF(0, 0.85, 0)
		elseif k == "messy" then a.hat.CFrame = head * CF(0, 0.6, 0.1)
		else a.hat.CFrame = head * CF(0, 0.65, 0.05) end
	end
	if a.brim then a.brim.CFrame = a.hatKind == "fedora" and head * CF(0, 0.4, 0) or head * CF(0, 0.5, -0.7) end
	if a.tie then a.tie.CFrame = root * CF(0, 3.2, -0.58) end
	if a.shades then a.shades.CFrame = head * CF(0, 0.12, -0.7) end
	if a.band then
		a.band.CFrame = head * CF(0, 0.65, 0)
		a.mic.CFrame = head * CF(0.62, -0.2, -0.45)
		a.micTip.CFrame = head * CF(0.62, -0.25, -0.85)
	end
	if a.propParts then
		-- the prop sits in the right hand (or both hands for carried things)
		local hand = raCF * CF(0, -1.1, -0.2)
		local k = a.prop
		local pp = a.propParts
		if k == "selfiestick" then
			pp[1].CFrame = hand * CFrame.Angles(-0.4, 0, 0) * CF(0, 1.4, 0)
			pp[2].CFrame = hand * CFrame.Angles(-0.4, 0, 0) * CF(0, 3, 0)
			pp[3].CFrame = hand * CFrame.Angles(-0.4, 0, 0) * CF(0, 3, 0.15) * CFrame.Angles(0, math.pi / 2, 0)
		elseif k == "box" or k == "pizzabox" or k == "tray" then
			local mid = root * CF(0, 3.3, -1.3)
			for i, part in ipairs(pp) do part.CFrame = mid * CF(0, (i - 1) * 0.3, 0) end
		elseif k == "camera" then
			pp[1].CFrame = head * CF(0.2, -0.1, -1.2)
			pp[2].CFrame = head * CF(0.2, -0.1, -1.7) * CFrame.Angles(0, math.pi / 2, 0)
		else
			for i, part in ipairs(pp) do part.CFrame = hand * CF(0, -0.2, -0.1 * i) end
		end
	end
end

-- ===== procedural animations (pose for t seconds into the move). Names are listed in AnimationConfig. =====
A.ANIMS = {
	idle = function(t) return {bounce = math.abs(math.sin(t * 2)) * 0.1, la = 0.1, ra = -0.1} end,
	entrance = function(t)
		if t < 0.7 then return {bounce = (1 - t / 0.7) ^ 2 * 30, la = -2.6, ra = -2.6} end
		local k = math.max(0, 1 - (t - 0.7) * 3)
		return {bounce = math.abs(math.sin((t - 0.7) * 9)) * 0.6 * k, kneel = 0.4 * k, la = -2.4, ra = -2.4}
	end,
	point = function(t) return {ra = -1.6, la = 0.2, bounce = math.abs(math.sin(t * 6)) * 0.15, lean = -0.05} end,
	laugh = function(t) return {bounce = math.abs(math.sin(t * 14)) * 0.5, lean = 0.25 + math.sin(t * 7) * 0.08, la = -0.6 + math.sin(t * 14) * 0.3, ra = -0.6 - math.sin(t * 14) * 0.3} end,
	clap = function(t) local s = math.abs(math.sin(t * 10)) return {la = -1.3, ra = -1.3, laz = -0.5 * s, raz = 0.5 * s, bounce = s * 0.1} end,
	shrug = function(t) return {laz = 0.9, raz = -0.9, la = -0.4, ra = -0.4, tilt = math.sin(t * 2) * 0.08} end,
	shock = function(t) return {bounce = t < 0.3 and math.sin(t / 0.3 * math.pi) * 1.5 or 0, lean = 0.3, la = -2.8, ra = -2.8} end,
	kneel = function(t) return {kneel = 1.4, la = -1.5 + math.sin(t * 5) * 0.1, ra = -1.5 - math.sin(t * 5) * 0.1, lean = -0.15} end,
	hype = function(t) return {bounce = math.abs(math.sin(t * 8)) * 1.6, la = -2.9, ra = -2.9, laz = -0.3, raz = 0.3} end,
	talk = function(t) return {la = 0.1, ra = -0.5 + math.sin(t * 6) * 0.35, bounce = math.abs(math.sin(t * 6)) * 0.05} end,
	walk = function(t) return {walk = t * 9, bounce = math.abs(math.sin(t * 9)) * 0.15} end,
	run = function(t) return {walk = t * 15, bounce = math.abs(math.sin(t * 15)) * 0.35, lean = -0.2} end,
	knock = function(t) local k = math.abs(math.sin(t * 9)) return {ra = -1.5 - k * 0.4, la = 0.1, lean = -0.05} end,
	wave = function(t) return {ra = -2.8, raz = 0.4 + math.sin(t * 10) * 0.4, la = 0.1} end,
	show = function() return {ra = -1.5, la = -1.5, laz = -0.2, raz = 0.2} end,
	flail = function(t) return {la = -2.6 + math.sin(t * 18) * 0.8, ra = -2.6 - math.sin(t * 18) * 0.8, bounce = math.abs(math.sin(t * 12)) * 0.6, tilt = math.sin(t * 9) * 0.15} end,
	carry = function(t) return {la = -1.4, ra = -1.4, laz = -0.25, raz = 0.25, walk = t * 8, bounce = math.abs(math.sin(t * 8)) * 0.1} end,
	throw = function(t) local k = math.min(1, t * 3) return {la = -2.6 + k * 1.8, ra = -2.6 + k * 1.8, lean = 0.2 - k * 0.4} end,
	gesture = function(t) return {ra = -1.4, raz = 1.2, la = 0.1, look = 0.4} end,
	facepalm = function(t) return {ra = -2.4, raz = -0.9, la = 0.2, nod = 0.25, lean = 0.1} end,
	crossed = function() return {la = -1.4, ra = -1.4, laz = 0.9, raz = -0.9} end,
	think = function(t) return {ra = -2.1, raz = -0.6, la = -1.2, laz = 0.8, nod = -0.15, tilt = math.sin(t) * 0.05} end,
	money = function(t) return {la = -2.6, ra = -2.6 + math.sin(t * 12) * 0.5, raz = 0.3, bounce = math.abs(math.sin(t * 8)) * 0.8} end,
	owner = function() return {la = -0.2, laz = 0.5, ra = -0.2, raz = -0.5, lean = -0.08, nod = -0.1} end,
	celebrate = function(t) return {bounce = math.abs(math.sin(t * 7)) * 1.2, la = -2.9, ra = -2.9} end,
	sit = function(t) return {sit = true, la = -0.6, ra = -0.6} end,
	eat = function(t) return {sit = true, la = -0.6, ra = -1.8 - math.abs(math.sin(t * 3)) * 0.5, raz = -0.3} end,
	phone = function(t) return {ra = -1.7, raz = -0.25, nod = 0.35, la = 0.05} end,
	sitphone = function(t) return {sit = true, ra = -1.7, raz = -0.25, nod = 0.35, la = -0.6} end,
	selfie = function(t) return {ra = -2.6, raz = 0.5, la = 0.2, tilt = 0.12, bounce = math.abs(math.sin(t * 4)) * 0.1} end,
	wipe = function(t) return {ra = -1.2 + math.sin(t * 8) * 0.3, raz = math.sin(t * 8) * 0.5, lean = 0.35} end,
	cook = function(t) return {la = -1.3, ra = -1.3 + math.sin(t * 9) * 0.4, laz = -0.2, raz = 0.2 + math.cos(t * 9) * 0.2, lean = 0.12} end,
	type = function(t) return {la = -1.4 + math.abs(math.sin(t * 16)) * 0.2, ra = -1.4 + math.abs(math.cos(t * 16)) * 0.2, lean = 0.1} end,
	clipboard = function(t) return {la = -1.3, ra = -1.1 + math.sin(t * 4) * 0.2, nod = 0.2, look = math.sin(t * 0.7) * 0.5} end,
	lift = function(t) local k = math.abs(math.sin(t * 2)) return {la = -1.4, ra = -1.4, laz = -0.3, raz = 0.3, kneel = (1 - k) * 0.8} end,
	stir = function(t) return {ra = -1.3, raz = math.sin(t * 6) * 0.4, la = -0.6, lean = 0.08} end,
	sweep = function(t) return {la = -0.9 + math.sin(t * 5) * 0.4, ra = -0.9 + math.sin(t * 5) * 0.4, lean = 0.2} end,
	dramatic = function(t) return {la = -2.9, ra = 0.4, laz = 0.4, lean = 0.4 + math.sin(t * 3) * 0.1, tilt = -0.3, kneel = 0.6} end,
	flash = function(t) return {ra = -1.6, la = -1.6, bounce = math.abs(math.sin(t * 10)) * 0.1} end,
	look = function(t) return {look = math.sin(t * 1.3) * 0.9, la = 0.05, ra = -0.05} end,
}

-- ===== moving =====
function A.faceTowards(at, target)
	local flat = V3(target.X, at.Y, target.Z)
	if (flat - at).Magnitude < 0.1 then return CF(at) end
	return CFrame.lookAt(at, flat)
end
-- start walking somewhere: A.step moves them along; done when they arrive
function A.walkTo(a, pos, speed)
	a.goal = pos
	a.speed = speed or 7
end
-- advance one frame. anim = the move to show when standing still. Returns true while still walking.
function A.step(a, dt, now)
	if a.dead then return false end
	local walking = false
	if a.goal then
		local here = a.base.Position
		local flat = V3(a.goal.X, here.Y, a.goal.Z)
		local dist = (flat - here).Magnitude
		local stepLen = (a.speed or 7) * dt
		if dist <= stepLen or dist < 0.05 then
			a.base = A.faceTowards(flat, flat + a.base.LookVector)
			a.goal = nil
		else
			local dir = (flat - here).Unit
			a.base = CFrame.lookAt(here + dir * stepLen, here + dir * (stepLen + 1))
			walking = true
		end
	end
	if a.hidden then return walking end
	local name = walking and ((a.speed or 7) > 12 and "run" or (a.prop == "box" and "carry" or "walk")) or (a.anim or "idle")
	local fn = A.ANIMS[name] or A.ANIMS.idle
	A.pose(a, a.base, fn(now - (a.animT or 0)))
	return walking
end
function A.play(a, name, now)
	if not A.ANIMS[name] and C.AnimationConfig then name = C.AnimationConfig.actorFallback(name) end
	a.anim = name
	a.animT = now or os.clock()
end

-- ===== effects =====
local CHAT = {"💀💀💀", "W", "L + ratio", "CLIP IT", "chat is crying 😭", "🔥🔥", "NO WAY", "😂😂", "+1000 aura", "-500 aura", "he's cooked", "WHAT JUST HAPPENED"}
A.CHAT = CHAT
function A.chatPop(folder, pos, lines)
	local a = A.part(folder, V3(0.2, 0.2, 0.2), WHITE)
	a.Transparency = 1
	a.CFrame = CF(pos + V3(math.random(-30, 30) / 10, math.random(0, 20) / 10, 0))
	local pool = lines or CHAT
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(150, 28), AlwaysOnTop = true, MaxDistance = 140}, a)
	local l = label({Size = UDim2.fromScale(1, 1), TextScaled = true, Text = pool[math.random(#pool)], Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromHSV(math.random(), 0.6, 1), TextStrokeTransparency = 0.2}, bb)
	tween(a, 1.6, {CFrame = a.CFrame + V3(0, 5, 0)})
	tween(l, 1.6, {TextTransparency = 1, TextStrokeTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.delay(1.7, function() a:Destroy() end)
end
function A.confetti(folder, pos, n)
	for _ = 1, n do
		local p = A.part(folder, V3(0.4, 0.05, 0.6), Color3.fromHSV(math.random(), 0.8, 1), Enum.Material.Neon)
		p.CFrame = CF(pos + V3(math.random(-6, 6), math.random(6, 12), math.random(-6, 6))) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		tween(p, 2 + math.random(), {CFrame = p.CFrame * CF(0, -10, 0) * CFrame.Angles(4, 2, 1), Transparency = 1})
		task.delay(3.2, function() p:Destroy() end)
	end
end
-- a white speech bubble over a spot in the world for a few seconds
function A.bubble(pos, who, text, dur, parent)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = V3(0.2, 0.2, 0.2)
	a.CFrame = CF(pos)
	a.Parent = parent or Workspace
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(240, 60), MaxDistance = 90, LightInfluence = 0, AlwaysOnTop = true}, a)
	local f = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0}, bb)
	corner(f, 12)
	label({Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 14), TextSize = 11, Text = who or "", TextColor3 = RGB(120, 120, 140), TextXAlignment = Enum.TextXAlignment.Left}, f)
	label({Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 1, -22), TextSize = 13, TextWrapped = true, Text = text, TextColor3 = RGB(20, 20, 30), TextXAlignment = Enum.TextXAlignment.Left}, f)
	task.delay(dur or 6, function() a:Destroy() end)
	return a
end
-- a camera flash at a spot (paparazzi, selfies)
function A.flashAt(folder, pos)
	local p = A.part(folder, V3(0.6, 0.6, 0.6), WHITE, Enum.Material.Neon, Enum.PartType.Ball)
	p.CFrame = CF(pos)
	local l = Instance.new("PointLight")
	l.Brightness, l.Range, l.Color = 8, 14, WHITE
	l.Parent = p
	task.delay(0.12, function() p:Destroy() end)
end
end
