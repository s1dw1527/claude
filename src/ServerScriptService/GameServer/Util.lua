-- UTIL: shared helpers for building things, effects, remotes and lighting.
return function(C)
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material

-- ===== input validation (anything that came from a client goes through these) =====
function C.finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
-- a whole number in [lo, hi], or nil
function C.int(v, lo, hi)
	if not C.finite(v) or v ~= math.floor(v) then return nil end
	if (lo and v < lo) or (hi and v > hi) then return nil end
	return v
end
-- a string no longer than maxLen, or nil
function C.str(v, maxLen)
	if type(v) == "string" and #v <= (maxLen or 40) then return v end
	return nil
end

function C.fmt(n)
	n = math.floor((n or 0) + 0.5)
	if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

-- v17 graphics pass: tame the "toy" colors. About 15% of the city's parts were maximum-saturation, maximum-
-- brightness plastic and 11% near pure white, which blows out under bloom and is the cheapest-looking thing in a
-- Roblox scene. Glowing materials (Neon, Glass) keep their color; everything else is pulled back a little: very
-- saturated + very bright colors lose some saturation and brightness, and pure white becomes a soft off-white.
-- The hue never changes, so every color still reads as the same color.
local GLOW = {[MAT.Neon] = true, [MAT.Glass] = true, [MAT.ForceField] = true}
function C.tameColor(c, mat)
	if GLOW[mat] or typeof(c) ~= "Color3" then return c end
	local h, s, v = c:ToHSV()
	if s > 0.8 and v > 0.88 then
		s = 0.8 + (s - 0.8) * 0.4
		v = 0.88 + (v - 0.88) * 0.5
		return Color3.fromHSV(h, s, v)
	elseif s < 0.06 and v > 0.96 then
		return Color3.fromHSV(h, s, 0.94)
	end
	return c
end
local function finish(p, parent, size, cf, color, mat, props)
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Material = mat or MAT.SmoothPlastic
	p.Color = C.tameColor(color, p.Material)
	if props then
		for k, v in pairs(props) do p[k] = v end
	end
	p.Parent = parent
	return p
end
function C.P(parent, size, cf, color, mat, props) return finish(Instance.new("Part"), parent, size, cf, color, mat, props) end
-- WedgePart: high edge at +Z (back), slope faces -Z (front)
function C.wedge(parent, size, cf, color, mat, props) return finish(Instance.new("WedgePart"), parent, size, cf, color, mat, props) end
function C.ball(parent, size, cf, color, mat, props)
	local p = C.P(parent, size, cf, color, mat, props)
	p.Shape = Enum.PartType.Ball
	return p
end
-- vertical cylinder (height along world Y of cf)
function C.cyl(parent, height, diameter, cf, color, mat, props)
	local p = C.P(parent, V3(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- cylinder whose axis runs along the local X of cf (wheels, bars)
function C.xcyl(parent, length, diameter, cf, color, mat, props)
	local p = C.P(parent, V3(length, diameter, diameter), cf, color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
function C.ghost(parent, cf)
	return C.P(parent, V3(0.5, 0.2, 0.5), cf, Color3.new(1, 1, 1), MAT.SmoothPlastic, {Transparency = 1})
end
function C.billboard(parent, size, offset, lines, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffsetWorldSpace = offset
	bb.MaxDistance = maxDist or 150
	bb.LightInfluence = 0
	local y = 0
	for i, ln in ipairs(lines) do
		local h = ln.h or (1 / #lines)
		local tl = Instance.new("TextLabel")
		tl.Name = "L" .. i
		tl.Position = UDim2.fromScale(0, y)
		tl.Size = UDim2.fromScale(1, h)
		tl.BackgroundTransparency = 1
		tl.Font = ln.font or Enum.Font.GothamBlack
		tl.TextScaled = true
		tl.TextColor3 = ln.color or Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.25
		tl.Text = ln.text
		tl.Parent = bb
		y += h
	end
	bb.Parent = parent
	return bb
end
function C.surfaceText(part, face, text, color, bg, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.CanvasSize = Vector2.new(math.max(part.Size.X, part.Size.Z) * 40, part.Size.Y * 40)
	sg.LightInfluence = 0
	sg.Parent = part
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = bg and 0 or 1
	tl.BackgroundColor3 = bg or Color3.new(0, 0, 0)
	tl.Font = font or Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.TextColor3 = color or Color3.new(1, 1, 1)
	tl.Text = text
	tl.Parent = sg
	return tl
end
function C.smoke(part, dark, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = rate or 5
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Speed = NumberRange.new(2, 3)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = V3(0.6, 1.5, 0)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.5)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
	e.Color = ColorSequence.new(dark and RGB(70, 70, 75) or RGB(240, 240, 240))
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = part
	return e
end
function C.sparkle(part, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
	e.Parent = part
	return e
end
function C.burst(pos, color, count, size)
	local a = C.P(Workspace, V3(1, 1, 1), CF(pos), Color3.new(1, 1, 1), MAT.SmoothPlastic, {Transparency = 1})
	local e = C.sparkle(a, color, 0)
	e.Speed = NumberRange.new(14, 26)
	e.Acceleration = V3(0, -30, 0)
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size or 1.2), NumberSequenceKeypoint.new(1, 0)})
	e:Emit(count)
	Debris:AddItem(a, 3)
end
function C.shockwave(pos, color, size)
	local r = C.P(Workspace, V3(0.2, 2, 2), CF(pos) * CFrame.Angles(0, 0, math.rad(90)), color, MAT.Neon, {Transparency = 0.3})
	r.Shape = Enum.PartType.Cylinder
	local s = size or 18
	TweenService:Create(r, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = V3(0.2, s, s), Transparency = 1}):Play()
	Debris:AddItem(r, 1)
end
function C.popIn(model)
	local nv = Instance.new("NumberValue")
	nv.Value = 0.6
	model:ScaleTo(0.6)
	local conn = nv.Changed:Connect(function(v)
		if model.Parent then model:ScaleTo(v) end
	end)
	local tw = TweenService:Create(nv, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Value = 1})
	tw.Completed:Connect(function()
		conn:Disconnect()
		nv:Destroy()
	end)
	tw:Play()
end
function C.spin(part, speed)
	part:SetAttribute("SpinSpeed", speed or 1)
	CollectionService:AddTag(part, "Spin")
end
function C.tag(inst, name) CollectionService:AddTag(inst, name) end
function C.prompt(parent, action, object, dist, hold, onTrigger)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object or ""
	pp.MaxActivationDistance = dist or 12
	pp.HoldDuration = hold or 0.3
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	pp.Triggered:Connect(onTrigger)
	return pp
end
-- simple tree with a clustered, less blocky canopy
function C.tree(parent, x, z, s, y)
	y = y or 0
	C.cyl(parent, 5 * s, 1 * s, CF(x, y + 2.5 * s, z), RGB(105, 72, 45), MAT.Wood, {CanCollide = true})
	local base = Color3.fromHSV(0.27 + math.random() * 0.07, 0.55 + math.random() * 0.15, 0.5 + math.random() * 0.15)
	local blobs = {{0, 6.2, 0, 5.4}, {1.6, 7.4, -0.6, 3.8}, {-1.5, 7, 0.9, 3.6}, {0.3, 8.6, 0.4, 3.4}, {-0.4, 5.6, -1.5, 3.2}}
	for _, b in ipairs(blobs) do
		C.ball(parent, V3(b[4], b[4] * 0.9, b[4]) * s, CF(x + b[1] * s, y + b[2] * s, z + b[3] * s), base:Lerp(RGB(40, 90, 40), math.random() * 0.25), MAT.Grass)
	end
end

-- ===== REMOTES =====
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = ReplicatedStorage
	return r
end
C.R = {}
for _, n in ipairs({"State", "Announce", "Splash", "Customer", "Buzz", "BuzzUpdate", "Msg", "WarResults", "Menu", "Action", "Race", "Mega", "Cinematic", "Viral"}) do
	C.R[n] = remote(n)
end
-- opts (v16, optional): {pri = "critical" | "normal" | "low", cat = "money" | "rep" | "warn" | "info", key = "..."}
-- critical ones are never dropped and jump the queue; low ones are grouped, and can be muted in Settings
function C.notify(plr, msg, opts) C.R.Announce:FireClient(plr, msg, type(opts) == "table" and opts or nil) end
function C.announceAll(msg) C.R.Announce:FireAllClients(msg) end

-- ===== LIGHTING =====
-- v17 graphics pass (compared with how popular Roblox games set up their lighting): the place file now asks for
-- FUTURE lighting (tools/build.py), so these values are tuned for it. Less flat ambient light, so shadows and
-- shapes read (it was so bright from every side that buildings looked flat); a clearer atmosphere (less milky
-- haze); a gentler bloom and a grade with more contrast and less saturation (the colors were already strong); and
-- no blur on the city: depth of field only softens the far horizon now (it blurred everything past 120 studs).
Lighting.Brightness = 3
Lighting.ClockTime = 14
Lighting.GlobalShadows = true
Lighting.OutdoorAmbient = RGB(118, 120, 136)
Lighting.Ambient = RGB(70, 72, 92)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
local function getFx(class, props)
	local fx = Lighting:FindFirstChildOfClass(class)
	if not fx then
		fx = Instance.new(class)
		for k, v in pairs(props) do fx[k] = v end
		fx.Parent = Lighting
	end
	return fx
end
local atm = getFx("Atmosphere", {Density = 0.3, Offset = 0.2, Color = RGB(199, 215, 240), Decay = RGB(150, 160, 185), Glare = 0.45, Haze = 0.6})
local bloom = getFx("BloomEffect", {Intensity = 0.35, Size = 24, Threshold = 1.6})
local grade = getFx("ColorCorrectionEffect", {Saturation = 0.05, Contrast = 0.14})
getFx("SunRaysEffect", {Intensity = 0.06, Spread = 0.8})
getFx("DepthOfFieldEffect", {FarIntensity = 0.08, FocusDistance = 260, InFocusRadius = 500, NearIntensity = 0})
local normal = {grade.TintColor, grade.Saturation, atm.Density, atm.Color, bloom.Intensity}
function C.setLook(look)
	local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
	TweenService:Create(grade, info, {TintColor = look[1], Saturation = look[2]}):Play()
	TweenService:Create(atm, info, {Density = look[3], Color = look[4]}):Play()
	TweenService:Create(bloom, info, {Intensity = look[5]}):Play()
end
function C.resetLook()
	C.setLook(normal)
	Workspace:SetAttribute("Weather", "none")
end
-- v15: a proper sky (sun, moon and stars: the default skybox, no image assets), softer shadows, and a grade that
-- follows the time of day: warm at sunrise and sunset, cool and blue at night, where a night bloom makes neon
-- signs, lamps and ride lights glow. (Weather and events use the main grade above; this one is separate.)
-- Lighting.Technology can't be set by a script: set it to ShadowMap (or Future) in Studio, see the v15 report.
pcall(function() Lighting.ShadowSoftness = 0.2 end)
local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
pcall(function()
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
end)
sky.Parent = Lighting
local tod = Lighting:FindFirstChild("TimeOfDayGrade") or Instance.new("ColorCorrectionEffect")
tod.Name = "TimeOfDayGrade"
tod.Parent = Lighting
local nightBloom = Lighting:FindFirstChild("NightBloom") or Instance.new("BloomEffect")
nightBloom.Name = "NightBloom"
nightBloom.Size, nightBloom.Threshold = 28, 0.95
nightBloom.Parent = Lighting
-- (hour → tint, brightness, night bloom, outdoor ambient)
local KEYS = {
	{0, RGB(170, 185, 255), -0.04, 0.7, RGB(70, 80, 120)},
	{5, RGB(190, 195, 255), -0.02, 0.6, RGB(90, 95, 130)},
	{6.5, RGB(255, 205, 170), 0.02, 0.15, RGB(135, 118, 120)},
	{8.5, RGB(255, 248, 240), 0, 0, RGB(118, 120, 136)},
	{16.5, RGB(255, 248, 238), 0, 0, RGB(118, 120, 136)},
	{18, RGB(255, 190, 150), 0.03, 0.2, RGB(140, 112, 110)},
	{19.5, RGB(200, 190, 255), -0.01, 0.55, RGB(90, 90, 130)},
	{24, RGB(170, 185, 255), -0.04, 0.7, RGB(70, 80, 120)},
}
function C.timeOfDayLook(h)
	h = h % 24
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if h >= a[1] and h <= b[1] then
			local f = (h - a[1]) / math.max(0.001, b[1] - a[1])
			return a[2]:Lerp(b[2], f), a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f, a[5]:Lerp(b[5], f)
		end
	end
	return KEYS[1][2], KEYS[1][3], KEYS[1][4], KEYS[1][5]
end
local lastH
function C.applyTimeOfDay(h)
	-- (only when it has moved a little: every property change is sent to every player)
	if lastH and math.abs(h - lastH) < 0.05 then return end
	lastH = h
	local tint, bright, bloomI, amb = C.timeOfDayLook(h)
	tod.TintColor, tod.Brightness, nightBloom.Intensity = tint, bright, bloomI
	Lighting.OutdoorAmbient = amb
end
C.applyTimeOfDay(Lighting.ClockTime)
pcall(function()
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.6
	clouds.Parent = Workspace.Terrain
end)
end
