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

local function finish(p, parent, size, cf, color, mat, props)
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or MAT.SmoothPlastic
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
function C.notify(plr, msg) C.R.Announce:FireClient(plr, msg) end
function C.announceAll(msg) C.R.Announce:FireAllClients(msg) end

-- ===== LIGHTING =====
Lighting.Brightness = 2.6
Lighting.ClockTime = 14
Lighting.GlobalShadows = true
Lighting.OutdoorAmbient = RGB(140, 140, 160)
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
local atm = getFx("Atmosphere", {Density = 0.28, Offset = 0.25, Color = RGB(199, 215, 240), Decay = RGB(255, 235, 200), Glare = 0.2, Haze = 1.4})
local bloom = getFx("BloomEffect", {Intensity = 0.5, Size = 24, Threshold = 1.6})
local grade = getFx("ColorCorrectionEffect", {Saturation = 0.15, Contrast = 0.08})
getFx("SunRaysEffect", {Intensity = 0.1, Spread = 0.8})
getFx("DepthOfFieldEffect", {FarIntensity = 0.12, FocusDistance = 120, InFocusRadius = 150, NearIntensity = 0})
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
pcall(function()
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.6
	clouds.Parent = Workspace.Terrain
end)
end
