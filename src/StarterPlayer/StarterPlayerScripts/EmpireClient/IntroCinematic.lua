-- INTRO CINEMATIC (v16): "GET RICH OR GO BROKE". About 20 seconds over the REAL city (scripted camera, a few
-- small temporary props), played once per account before the save slots (GameServer > Players keeps the
-- introSeen flag in the account record), and any time from Settings → Opening movie.
--   1 THE STRUGGLE  a rainy night over the skyline, down to a street corner: "EVERY EMPIRE STARTS WITH NOTHING."
--   2 THE CHOICE    a lemonade stand and paying customers, a busy shop, a fancy car; a (fictional) briefcase swap
--                   in an alley, police lights far away: "BUILD IT LEGIT." "TAKE BIG RISKS." "OR RULE BOTH SIDES."
--   3 THE RISE      the Fun Park's Big Dipper, the Funland Grounds, the mountain, the Empire Spire, counters climbing:
--                   "YOUR CITY. YOUR EMPIRE. YOUR RULES."
--   4 THE TITLE     CORNER EMPIRE / Build Your Fortune. Risk Everything. Leave a Legacy. → START MY EMPIRE / SKIP
-- SKIP is on screen from the first frame (and Esc / the gamepad's B or Start). Only one intro can play at a
-- time. Whatever ends it (finished, skipped, an error, a respawn, the window being closed) runs ONE cleanup that
-- puts the camera, field of view, HUD and controls back and removes every temporary part, effect, sound and
-- connection. Sound uses the game's own effects and jingles only (no music asset IDs are invented).
return function(C)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local new, label, button, corner, stroke, tween = C.new, C.label, C.button, C.corner, C.stroke, C.tween
local play, SND, plr = C.play, C.SND, C.plr
local GOLD, WHITE = RGB(255, 205, 60), C.WHITE
local NAVY, BLACK = RGB(12, 18, 40), RGB(8, 8, 12)
local IN = {playing = false, conns = {}, shotIndex = 0, failAt = nil, ended = nil}
C.Intro = IN

-- ===== the shots: camera from → to over dur seconds, text shown at the start, an optional action =====
local function look(from, at) return CFrame.lookAt(from, at) end
local SHOTS = {
	-- 1 THE STRUGGLE (0-4 s)
	{dur = 2.2, scene = 1, from = look(V3(-260, 160, 300), V3(0, 60, 0)), to = look(V3(-180, 110, 220), V3(0, 40, 0)), fov = 60,
		text = "EVERY EMPIRE STARTS WITH NOTHING.", sound = "event"},
	{dur = 1.8, scene = 1, from = look(V3(-40, 30, 150), V3(-20, 2, 136)), to = look(V3(-26, 8, 142), V3(-20, 2, 136)), fov = 55, props = "corner"},
	-- 2 THE CHOICE (4-9.5 s)
	{dur = 1.4, scene = 2, from = look(V3(-14, 6, 152), V3(-20, 2.5, 144)), to = look(V3(-16, 5, 149), V3(-20, 2.5, 144)), fov = 50, props = "stand", text = "BUILD IT LEGIT.", sound = "buy"},
	{dur = 1.3, scene = 2, from = look(V3(60, 18, 40), V3(62, 6, 62)), to = look(V3(50, 12, 50), V3(62, 6, 62)), fov = 55, props = "car"},
	{dur = 1.5, scene = 2, from = look(V3(214, 8, -48), V3(220, 3, -60)), to = look(V3(217, 5, -52), V3(220, 3, -60)), fov = 45, props = "alley", text = "TAKE BIG RISKS.", sound = "event"},
	{dur = 1.3, scene = 2, from = look(V3(150, 60, -150), V3(0, 30, 0)), to = look(V3(110, 70, -110), V3(0, 40, 0)), fov = 60, text = "OR RULE BOTH SIDES.", sound = "buy"},
	-- 3 THE RISE (9.5-15.5 s)
	{dur = 1.5, scene = 3, from = look(V3(-400, 40, 140), V3(-470, 15, 95)), to = look(V3(-450, 30, 130), V3(-500, 15, 90)), fov = 60, text = "YOUR CITY. YOUR EMPIRE. YOUR RULES.",
		counters = true, sound = "msg"},
	{dur = 1.4, scene = 3, from = look(V3(-640, 40, -110), V3(-750, 5, -150)), to = look(V3(-660, 60, -190), V3(-780, 5, -150)), fov = 60},
	{dur = 1.4, scene = 3, from = look(V3(300, 120, -300), V3(300, 60, -700)), to = look(V3(300, 160, -380), V3(300, 60, -760)), fov = 60},
	{dur = 1.7, scene = 3, from = look(V3(70, 20, 70), V3(0, 120, 0)), to = look(V3(30, 10, 30), V3(0, 200, 0)), fov = 70},
	-- 4 THE TITLE (15.5 s →): a slow orbit behind the card until the player chooses
	{dur = 60, scene = 4, from = look(V3(-300, 150, 260), V3(0, 60, 0)), to = look(V3(260, 150, 300), V3(0, 60, 0)), fov = 60, title = true, sound = "msg"},
}
IN.SHOTS = SHOTS
local function lengthTo(scene)
	local t = 0
	for _, s in ipairs(SHOTS) do if s.scene < scene then t += s.dur end end
	return t
end
IN.titleAt = lengthTo(4)

-- ===== temporary props (client-only, no collision, all in one folder that cleanup removes) =====
local function part(folder, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = folder
	return p
end
local function person(folder, cf, shirt)
	local CC = C.CityCrowd
	if CC and CC.buildPerson then
		local n = CC.buildPerson()
		CC.dress(n, "casual")
		n.torso.Color, n.la.Color, n.ra.Color = shirt, shirt, shirt
		for _, k in ipairs({"torso", "head", "hair", "la", "ra", "ll", "rl", "acc", "dog"}) do n[k].Parent = folder end
		CC.showPerson(n)
		n.acc.Transparency, n.dog.Transparency = 1, 1
		CC.pose(n, cf, 0, "chat")
		return n
	end
	return part(folder, V3(2, 5, 1), cf * CF(0, 2.5, 0), shirt)
end
local PROPS = {}
PROPS.corner = function(f)
	-- an empty wallet on the curb and a run-down storefront
	part(f, V3(1.2, 0.2, 0.8), CF(-20, 0.6, 136), RGB(90, 60, 40), Enum.Material.Leather)
	local shop = part(f, V3(14, 9, 1), CF(-20, 4.5, 128), RGB(90, 84, 80), Enum.Material.Brick)
	local sign = part(f, V3(8, 1.6, 0.2), CF(-20, 7.5, 128.7), RGB(40, 40, 46))
	sign.Name = "ForRent"
	local g = Instance.new("SurfaceGui")
	g.Face, g.LightInfluence = Enum.NormalId.Back, 0
	g.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.TextScaled, t.Text, t.TextColor3, t.Font = UDim2.fromScale(1, 1), 1, true, "FOR RENT", RGB(255, 90, 90), Enum.Font.GothamBlack
	t.Parent = g
	local _ = shop
end
PROPS.stand = function(f)
	-- a lemonade stand and a paying customer
	part(f, V3(5, 2.2, 2.4), CF(-20, 1.4, 144), RGB(150, 105, 62), Enum.Material.Wood)
	part(f, V3(5.4, 0.25, 2.8), CF(-20, 2.6, 144), RGB(196, 146, 84), Enum.Material.WoodPlanks)
	for _, sx in ipairs({-2.4, 2.4}) do part(f, V3(0.25, 4.5, 0.25), CF(-20 + sx, 4.6, 143), RGB(150, 105, 62), Enum.Material.Wood) end
	for k = 0, 5 do part(f, V3(5.4 / 6, 0.2, 2.6), CF(-20 - 2.7 + (k + 0.5) * 0.9, 6.9, 143.5), k % 2 == 0 and RGB(255, 214, 60) or WHITE, Enum.Material.Fabric) end
	person(f, CF(-20, 0.2, 142) * CFrame.Angles(0, math.pi, 0), RGB(255, 200, 60))
	person(f, CF(-19, 0.2, 147), RGB(90, 120, 200))
	local cash = part(f, V3(0.9, 0.1, 0.5), CF(-19.4, 3.1, 145.4), RGB(120, 200, 110))
	cash.Name = "Cash"
end
PROPS.car = function(f)
	-- a luxury car pulls up
	local body = part(f, V3(5, 1.6, 10), CF(56, 1.4, 70), RGB(20, 20, 26), Enum.Material.SmoothPlastic)
	part(f, V3(4.4, 1.2, 5), CF(56, 2.8, 70.5), RGB(40, 50, 70), Enum.Material.Glass)
	for _, sx in ipairs({-2.6, 2.6}) do
		for _, sz in ipairs({-3.4, 3.4}) do part(f, V3(1, 2, 2), CF(56 + sx, 1, 70 + sz) * CFrame.Angles(0, 0, math.pi / 2), BLACK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) end
	end
	part(f, V3(4.6, 0.3, 0.2), CF(56, 1.6, 64.95), RGB(255, 245, 210), Enum.Material.Neon)
	IN.carBody = body
end
PROPS.alley = function(f)
	-- a fictional, suspicious briefcase swap in an alley; police lights flash far away
	person(f, CF(218, 0.2, -60) * CFrame.Angles(0, -math.pi / 2, 0), RGB(30, 30, 36))
	person(f, CF(222, 0.2, -60) * CFrame.Angles(0, math.pi / 2, 0), RGB(60, 40, 70))
	part(f, V3(1.6, 1.2, 0.4), CF(220, 2.6, -60), RGB(70, 45, 30), Enum.Material.Leather).Name = "Briefcase"
	local red = part(f, V3(1, 0.6, 1), CF(250, 4, -110), RGB(255, 40, 40), Enum.Material.Neon)
	local blue = part(f, V3(1, 0.6, 1), CF(252, 4, -110), RGB(40, 90, 255), Enum.Material.Neon)
	IN.siren = {red, blue}
end

-- ===== the overlay (letterbox, words, counters, the title card, SKIP) =====
local gui, letterTop, letterBot, words, skipB, counters, titleCard, startB, skip2B
local function buildGui()
	gui = new("ScreenGui", {Name = "IntroGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Enabled = true}, plr:WaitForChild("PlayerGui"))
	letterTop = new("Frame", {Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0}, gui)
	letterBot = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0}, gui)
	words = label({Name = "IntroWords", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.new(0.9, 0, 0.12, 0), Text = "", TextScaled = true,
		Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextTransparency = 1, TextStrokeTransparency = 0.3}, gui)
	new("UITextSizeConstraint", {MaxTextSize = 54, MinTextSize = 16}, words)
	skipB = button({Name = "IntroSkip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(132, 44), Text = "SKIP INTRO ⏭", TextSize = 15,
		BackgroundColor3 = RGB(30, 34, 52)}, gui)
	stroke(skipB, GOLD, 1, 0.3)
	-- counters (scene 3): cash, reputation, empire value
	counters = new("Frame", {Name = "IntroCounters", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.new(0.9, 0, 0, 44), BackgroundTransparency = 1, Visible = false}, gui)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10)}, counters)
	IN.counterLabels = {}
	for i, c in ipairs({{"💰", "Cash"}, {"⭐", "Rep"}, {"👑", "Empire"}}) do
		local l = label({Size = UDim2.new(0.3, -8, 1, 0), Text = c[1] .. " 0", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, BackgroundColor3 = NAVY, BackgroundTransparency = 0.2, LayoutOrder = i}, counters)
		corner(l, 8)
		new("UITextSizeConstraint", {MaxTextSize = 24, MinTextSize = 10}, l)
		IN.counterLabels[i] = l
	end
	-- the title card
	titleCard = new("Frame", {Name = "IntroTitle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0.62, 0), BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.12, Visible = false}, gui)
	new("UISizeConstraint", {MaxSize = Vector2.new(720, 420)}, titleCard)
	corner(titleCard, 18)
	stroke(titleCard, GOLD, 3, 0)
	new("UIGradient", {Color = ColorSequence.new(RGB(24, 32, 70), BLACK), Rotation = 90}, titleCard)
	local t = label({Name = "TitleText", Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.34), Text = "CORNER EMPIRE", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = GOLD}, titleCard)
	new("UITextSizeConstraint", {MaxTextSize = 80, MinTextSize = 22}, t)
	new("UIStroke", {Thickness = 3, Color = RGB(60, 40, 0)}, t)
	local tag = label({Name = "Tagline", Position = UDim2.fromScale(0.05, 0.42), Size = UDim2.fromScale(0.9, 0.14), Text = "Build Your Fortune. Risk Everything. Leave a Legacy.", TextScaled = true,
		TextColor3 = WHITE, Font = Enum.Font.GothamBold}, titleCard)
	new("UITextSizeConstraint", {MaxTextSize = 24, MinTextSize = 11}, tag)
	startB = button({Name = "IntroStart", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.62, 0.18), Text = "START MY EMPIRE",
		TextScaled = true, BackgroundColor3 = RGB(200, 150, 30), TextColor3 = BLACK}, titleCard)
	new("UISizeConstraint", {MinSize = Vector2.new(180, 48)}, startB)
	new("UITextSizeConstraint", {MaxTextSize = 26, MinTextSize = 14}, startB)
	skip2B = button({Name = "IntroSkip2", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.83), Size = UDim2.fromScale(0.36, 0.12), Text = "SKIP INTRO",
		TextScaled = true, BackgroundColor3 = RGB(40, 44, 64)}, titleCard)
	new("UISizeConstraint", {MinSize = Vector2.new(130, 40)}, skip2B)
	new("UITextSizeConstraint", {MaxTextSize = 18, MinTextSize = 12}, skip2B)
end

-- ===== cleanup: the ONE way out =====
local cam = Workspace.CurrentCamera
local saved
local folder, grade, rain
local function controls(on)
	pcall(function()
		local pm = plr:FindFirstChild("PlayerScripts") and plr.PlayerScripts:FindFirstChild("PlayerModule")
		if pm then
			local c = require(pm):GetControls()
			if on then c:Enable() else c:Disable() end
		end
	end)
end
local function finish(reason)
	if not IN.playing then return end
	IN.playing = false
	IN.ended = reason
	for _, cn in ipairs(IN.conns) do pcall(function() cn:Disconnect() end) end
	IN.conns = {}
	for _, x in ipairs({gui, folder, grade, rain}) do if x then pcall(function() x:Destroy() end) end end
	gui, folder, grade, rain = nil, nil, nil, nil
	IN.siren, IN.carBody = nil, nil
	if saved then
		pcall(function()
			cam.CameraType = saved.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.type
			cam.FieldOfView = saved.fov
			if saved.subject and saved.subject.Parent then cam.CameraSubject = saved.subject end
		end)
	end
	if saved and saved.hud ~= nil and C.gui then C.gui.Enabled = saved.hud end
	controls(true)
	plr:SetAttribute("InCinematic", nil)
	local cb = IN.onDone
	IN.onDone = nil
	saved = nil
	if cb then task.spawn(cb, reason) end
end
IN.finish = finish

local function fmtBig(n)
	if n >= 1e9 then return string.format("$%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("$%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("$%.0fK", n / 1e3) end
	return "$" .. math.floor(n)
end
local function showWords(text)
	if not words then return end
	words.Text = text
	words.TextTransparency = 1
	words.Position = UDim2.fromScale(0.5, 0.74)
	tween(words, 0.35, {TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.7)})
end
local function ease(a) return a * a * (3 - 2 * a) end

-- play the intro. returnToMenu = played from the main menu (the HUD stays as it is). Returns false if one is
-- already playing.
function C.playIntro(replay, onDone)
	if IN.playing then return false end
	IN.playing = true
	IN.ended = nil
	IN.onDone = onDone
	IN.shotIndex = 0
	saved = {type = cam.CameraType, fov = cam.FieldOfView, subject = cam.CameraSubject, hud = C.gui and C.gui.Enabled}
	if C.gui and not C.inMainMenu then C.gui.Enabled = false end
	if C.closeModals then pcall(C.closeModals) end
	controls(false)
	plr:SetAttribute("InCinematic", true)
	folder = Instance.new("Folder")
	folder.Name = "IntroProps"
	folder.Parent = Workspace
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "IntroGrade"
	grade.TintColor, grade.Brightness, grade.Contrast, grade.Saturation = RGB(150, 170, 230), -0.12, 0.15, -0.15
	grade.Parent = Lighting
	-- rain (only with crowds/effects on, so low-end devices skip it)
	if C.settings.weather ~= false and C.settings.crowd ~= "off" then
		rain = part(Workspace, V3(60, 1, 60), cam.CFrame, WHITE)
		rain.Name = "IntroRain"
		rain.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Rate = C.settings.crowd == "low" and 60 or 160
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Speed = NumberRange.new(70, 90)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Size = NumberSequence.new(0.08)
		e.Transparency = NumberSequence.new(0.35)
		e.Color = ColorSequence.new(RGB(190, 210, 255))
		e.Parent = rain
	end
	local okGui = pcall(buildGui)
	if not okGui then finish("error") return false end
	skipB.MouseButton1Click:Connect(function() play(SND.click) finish("skip") end)
	skip2B.MouseButton1Click:Connect(function() play(SND.click) finish("skip") end)
	startB.MouseButton1Click:Connect(function() play(SND.buy) finish("start") end)
	table.insert(IN.conns, UserInputService.InputBegan:Connect(function(input)
		local k = input.KeyCode
		if k == Enum.KeyCode.Escape or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.ButtonStart then finish("skip") end
	end))
	table.insert(IN.conns, plr.CharacterAdded:Connect(function() finish("respawn") end))
	cam.CameraType = Enum.CameraType.Scriptable
	-- "cinematics: off" (Settings) goes straight to the title card
	local start = C.settings.cinematics == "off" and IN.titleAt or 0
	local t = start
	local shotAt = 0
	local function shotFor(time)
		local acc = 0
		for i, s in ipairs(SHOTS) do
			if time < acc + s.dur or i == #SHOTS then return i, s, time - acc end
			acc += s.dur
		end
	end
	table.insert(IN.conns, RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(function()
			t += math.min(dt, 0.1)
			local i, s, local_t = shotFor(t)
			if i ~= IN.shotIndex then
				IN.shotIndex = i
				shotAt = t
				if IN.failAt == i then error("simulated intro failure") end
				if s.props and PROPS[s.props] then PROPS[s.props](folder) end
				if s.text then showWords(s.text) end
				if s.sound and SND[s.sound] then play(SND[s.sound]) end
				if s.counters then counters.Visible = true end
				if s.scene == 4 then
					counters.Visible = false
					words.Visible = false
					titleCard.Visible = true
					letterTop.Visible, letterBot.Visible = false, false
					if grade then grade.Brightness, grade.TintColor = 0, RGB(255, 245, 230) end
					if C.jingle then C.jingle("milestone", 0.5) end
				end
			end
			local a = ease(math.clamp(local_t / s.dur, 0, 1))
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = s.from:Lerp(s.to, a)
			cam.FieldOfView = s.fov or 60
			if rain then rain.CFrame = cam.CFrame * CF(0, 18, -20) end
			if IN.siren then
				local on = math.floor(t * 6) % 2 == 0
				IN.siren[1].Transparency, IN.siren[2].Transparency = on and 0 or 1, on and 1 or 0
			end
			if IN.carBody and s.props == "car" then IN.carBody.CFrame = CF(56, 1.4, 70 - (1 - a) * 18) end
			if counters.Visible then
				local f = math.clamp((t - lengthTo(3)) / (IN.titleAt - lengthTo(3)), 0, 1)
				local g = f ^ 3
				IN.counterLabels[1].Text = "💰 " .. fmtBig(40 + g * 1e9)
				IN.counterLabels[2].Text = "⭐ " .. math.floor(g * 9000)
				IN.counterLabels[3].Text = "👑 " .. fmtBig(g * 2.5e9)
			end
			local _ = shotAt
		end)
		if not ok then
			warn("[Intro] stopped: " .. tostring(err))
			finish("error")
		end
	end))
	return true
end
-- the menu closes / the player leaves the menu for a game: never leave the intro running underneath
function IN.stop(reason) finish(reason or "stopped") end
local _ = Players
end
