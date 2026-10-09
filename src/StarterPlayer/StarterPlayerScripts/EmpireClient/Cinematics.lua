-- CINEMATIC CONTROLLER: plays the short interaction cinematics the server sends (GameServer > Cinematics):
-- evictions, grand openings, hires, inspections, influencer visits...
--
-- One reusable stage does the work for every scene: camera shots, part-built actors (EmpireClient > Actors),
-- props, timed dialogue, a Skip button (mouse, touch, Backspace, controller B) and a 📸 button that pauses the
-- scene in Photo Mode. Scenes are pure presentation: the server already applied every change before sending it,
-- so skipping, respawning or leaving mid-scene can't break anything, and everything is cleaned up afterwards.
--
-- Two ways to show a scene (Settings → 🎬 Cinematics):
--   FULL  - the camera takes over with letterbox bars and the HUD steps aside (big moments)
--   SHORT - nothing takes your camera: the actors act it out in the world and lines pop up as bubbles
--   OFF   - just the result banner
-- Only the player involved gets the scene; actors only appear if you're close to where it happens.
return function(C)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RGB, V3, CF = Color3.fromRGB, Vector3.new, CFrame.new
local new, tween, label, button, corner, stroke = C.new, C.tween, C.label, C.button, C.corner, C.stroke
local play, SND, act, gui, plr = C.play, C.SND, C.act, C.gui, C.plr
local GOLD, WHITE, SUB, GRAY = C.GOLD, C.WHITE, C.SUB, C.GRAY
local A = C.Actors
local remote = ReplicatedStorage:WaitForChild("Cinematic")
local CAST = (C.catalog and C.catalog.cast) or {}

local CC = {stats = {played = 0, skipped = 0, cleaned = 0, errors = 0, dropped = 0}}
C.Cinematics = CC
local NEAR = 170            -- SHORT scenes only draw actors if you're this close
local MAX_QUEUE = 3

-- =====================================================================
-- SCREEN
-- =====================================================================
local sg = new("ScreenGui", {Name = "EmpireCinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 22, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, plr:WaitForChild("PlayerGui"))
local barTop = new("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2}, sg)
local barBot = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2}, sg)
local titleCard = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.7, 0, 0, 40), TextScaled = true, Font = Enum.Font.GothamBlack,
	TextColor3 = GOLD, TextStrokeTransparency = 0.2, Visible = false, ZIndex = 5}, sg)
-- subtitles (FULL) / caption (SHORT)
local sub = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.new(0.8, 0, 0, 74), BackgroundColor3 = RGB(14, 14, 22),
	BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false, ZIndex = 6}, sg)
new("UISizeConstraint", {MaxSize = Vector2.new(720, 90)}, sub)
corner(sub, 14)
local subStroke = stroke(sub, WHITE, 2, 0.3)
local subIcon = label({Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(56, 56), TextScaled = true, Text = "💬", ZIndex = 7}, sub)
local subName = label({Position = UDim2.fromOffset(74, 6), Size = UDim2.new(1, -84, 0, 20), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, sub)
local subText = label({Position = UDim2.fromOffset(74, 26), Size = UDim2.new(1, -84, 1, -30), TextSize = 17, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7}, sub)
-- buttons: big enough for thumbs, top-right so they never cover the mobile jump button or the phone
local skipB = button({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 70), Size = UDim2.fromOffset(122, 44), Text = "Skip ⏭", TextSize = 16, BackgroundColor3 = GRAY, Visible = false, ZIndex = 8}, sg)
local photoB = button({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -144, 0, 70), Size = UDim2.fromOffset(54, 44), Text = "📸", TextSize = 22, BackgroundColor3 = RGB(230, 70, 150), Visible = false, ZIndex = 8}, sg)
local hintL = label({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 116), Size = UDim2.fromOffset(240, 16), TextSize = 11, TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "Skip: Backspace / Ⓑ  •  Next line: Space / Ⓐ", Visible = false, ZIndex = 8}, sg)
if UserInputService.TouchEnabled then hintL.Text = "Tap Skip to skip" end
-- result banner (shown after every scene, even skipped or OFF)
local banner = C.panel and C.panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(420, 86), BackgroundColor3 = RGB(30, 20, 44), Visible = false, ZIndex = 9}, sg)
	or new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(420, 86), BackgroundColor3 = RGB(30, 20, 44), Visible = false, ZIndex = 9}, sg)
stroke(banner, GOLD, 2, 0.2)
banner.Name = "CinematicBanner"
local banTitle = label({Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 36), TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 10}, banner)
local banSub = label({Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 30), TextSize = 15, TextWrapped = true, ZIndex = 10}, banner)
-- v11.1 phone layout: never wider than the screen; the title shrinks to fit
if C.Layout then
	new("UITextSizeConstraint", {MaxTextSize = 26, MinTextSize = 14}, banTitle)
	C.Layout.onChange(function(L)
		banner.Size = UDim2.fromOffset(math.min(420, L.vp.X - 16), 86)
		banTitle.TextScaled = L.compact
	end)
end
local bannerId = 0
local function showBanner(r)
	if type(r) ~= "table" or not r[1] then return end
	bannerId += 1
	local id = bannerId
	banTitle.Text = tostring(r[1])
	banSub.Text = tostring(r[2] or "")
	banner.Visible = true
	local s = new("UIScale", {Scale = 0.6}, banner)
	tween(s, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
	play(SND.event)
	task.delay(3, function()
		s:Destroy()
		if bannerId == id then banner.Visible = false end
	end)
end
CC.showBanner = showBanner

-- =====================================================================
-- THE STAGE: one per scene
-- =====================================================================
local Stage = {}
Stage.__index = Stage
local current = nil      -- the playing stage
local advance = false

local function newStage(scene)
	local S = setmetatable({}, Stage)
	S.scene, S.kind, S.anchor = scene, scene.kind, scene.at
	S.mode = scene.mode
	S.folder = A.folder("Cinematic_" .. scene.kind)
	S.actors, S.updaters, S.alias = {}, {}, {}
	S.skipped, S.paused = false, false
	S.cam = Workspace.CurrentCamera
	S.names = scene.names or {}
	-- SHORT scenes far away: no actors (lines show as captions only)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	S.near = S.mode == "full" or (root ~= nil and (root.Position - S.anchor.Position).Magnitude < NEAR)
	return S
end
-- a point in front of the door, in anchor space (x: right, z: towards the street)
function Stage:pt(x, z, y) return (self.anchor * CF(x, y or 0, z)).Position end
function Stage:wait(t)
	local left = t
	while left > 0 and not self.skipped do
		local dt = task.wait(0.03)
		if not self.paused then left -= dt end
	end
end
function Stage:actor(who, pos, faceTo, opts)
	if not self.near then return nil end
	local look = (opts and opts.look) or (who == "you" and A.lookOfCharacter(plr.Character)) or (CAST[who] and CAST[who].look) or who
	local a = A.make(self.folder, look, opts)
	a.base = A.faceTowards(pos, faceTo or self.anchor.Position)
	a.who = who
	self.actors[who] = a
	A.step(a, 0, os.clock())
	return a
end
function Stage:move(a, name)
	if a then A.play(a, name, os.clock()) end
end
function Stage:walk(a, pos, speed, waitArrive)
	if not a then return end
	A.walkTo(a, pos, speed or 7)
	if waitArrive then
		local limit = os.clock() + 4
		while a.goal and os.clock() < limit and not self.skipped do task.wait(0.03) end
	end
end
function Stage:part(size, color, mat, cf, shape)
	local p = A.part(self.folder, size, color, mat, shape)
	p.CFrame = cf
	return p
end
-- camera shot: a position and a look-at point in anchor space (FULL mode only)
function Stage:shot(pos, look, dur)
	if self.mode ~= "full" then return end
	local cf = CFrame.lookAt((self.anchor * CF(pos)).Position, (self.anchor * CF(look)).Position)
	self.lastShot = cf
	if not dur or dur <= 0 then
		self.cam.CFrame = cf
	else
		tween(self.cam, dur, {CFrame = cf}, Enum.EasingStyle.Sine)
	end
end
function Stage:sfx(name)
	if name == "knock" then
		task.spawn(function() for _ = 1, 3 do play(SND.click) task.wait(0.22) end end)
	else
		play(SND[name] or SND.event)
	end
end
function Stage:speaker(who)
	local c = CAST[who] or {}
	local name = self.names[who] or c.name or who
	if who == "you" then name = plr.DisplayName end
	return name, c.icon or (who == "you" and "😎" or "💬")
end
-- one line of dialogue: the speaker acts it out; FULL shows subtitles, SHORT shows a bubble over their head
function Stage:say(who, text, move)
	if self.skipped then return end
	text = tostring(text or "")
	local a = self.actors[who] or self.alias[who]
	if a then
		self:move(a, move or "talk")
		if move == "hype" or move == "shock" or move == "flail" or move == "laugh" then
			for _ = 1, 3 do A.chatPop(self.folder, a.head.Position + V3(0, 2, 0)) end
		end
	end
	local name, icon = self:speaker(who)
	if self.mode == "full" then
		subName.Text = name
		subIcon.Text = icon
		subText.Text = text
		sub.Visible = true
	else
		local pos = a and (a.head.Position + V3(0, 2.6, 0)) or (self.anchor.Position + V3(0, 7, 0))
		if self.near then A.bubble(pos, name, text, 3, self.folder) end
		if C.U and C.U.toast and not self.near then C.U.toast(icon .. " " .. name .. ": " .. text) end
	end
	advance = false
	local dur = math.clamp(#text * 0.04 + 0.9, 1.3, 2.8)
	local left = dur
	while left > 0 and not self.skipped and not advance do
		local dt = task.wait(0.03)
		if not self.paused then left -= dt end
	end
	advance = false
	if a and not self.skipped then self:move(a, "idle") end
end
function Stage:lines(list, from, to)
	for i = from or 1, to or #list do
		local l = list[i]
		if not l or self.skipped then break end
		self:say(l[1], l[2], l[3])
	end
end
-- throw a prop in an arc (with bounces) from a CFrame to a point
function Stage:toss(kind, fromCF, toPos, height, dur, bounces, label_)
	if not self.near then return end
	local p
	if kind == "box" then
		p = self:part(V3(1.6, 1.3, 1.4), RGB(200, 160, 100), Enum.Material.Cardboard, fromCF)
	else
		p = self:part(V3(1.3, 1.3, 1.3), Color3.fromHSV(math.random(), 0.7, 1), Enum.Material.SmoothPlastic, fromCF, Enum.PartType.Ball)
		if label_ then
			local bb = new("BillboardGui", {Size = UDim2.fromOffset(200, 26), StudsOffset = V3(0, 1.6, 0), AlwaysOnTop = true, MaxDistance = 120}, p)
			label({Size = UDim2.fromScale(1, 1), Text = "✨ " .. label_, TextScaled = true, Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.2}, bb)
		end
	end
	local from = fromCF.Position
	local t = 0
	local hops = {{from, toPos, height, dur}}
	local land = toPos
	for i = 1, bounces or 0 do
		local nxt = land + (land - from).Unit * (3 / i) + V3(0, 0, 0)
		table.insert(hops, {land, V3(nxt.X, toPos.Y, nxt.Z), height / (i * 2.2), dur / (i + 1)})
		land = V3(nxt.X, toPos.Y, nxt.Z)
	end
	local hop = 1
	table.insert(self.updaters, function(dt)
		local h = hops[hop]
		if not h then return true end
		t += dt
		local k = math.min(1, t / h[4])
		local pos = h[1]:Lerp(h[2], k) + V3(0, math.sin(k * math.pi) * h[3], 0)
		p.CFrame = CF(pos) * CFrame.Angles(t * 7, t * 5, 0)
		if k >= 1 then
			hop += 1
			t = 0
		end
		return false
	end)
	return p
end
-- swing a door around its hinge
function Stage:swing(door, hinge, angle, dur)
	local rel = hinge:ToObjectSpace(door.CFrame)
	local startA = door:GetAttribute("Swing") or 0
	local t = 0
	table.insert(self.updaters, function(dt)
		t += dt
		local k = math.min(1, t / dur)
		local a = startA + (angle - startA) * k
		door.CFrame = hinge * CFrame.Angles(0, a, 0) * rel
		if k >= 1 then door:SetAttribute("Swing", angle) return true end
		return false
	end)
end

-- =====================================================================
-- SCENES
-- =====================================================================
local T = {}
-- a simple face-off: you on the left, the other speakers in a row on the right, then their lines
local function dialogue(S, o, lines, opts)
	opts = opts or {}
	local you = S:actor("you", S:pt(-2.6, 7), S:pt(2.5, 6.5))
	local who = {}
	for _, l in ipairs(lines) do
		if l[1] ~= "you" and not who[l[1]] then
			who[l[1]] = true
			local n = 0
			for _ in pairs(S.actors) do n += 1 end
			S:actor(l[1], S:pt(1.6 + (n - 1) * 2.8, 5.6 - (n - 1) * 0.6), S:pt(-2.6, 7), {prop = opts.props and opts.props[l[1]] or nil})
		end
	end
	S:shot(V3(0.4, 4.6, 17), V3(0, 3.6, 6), 0)
	S:shot(V3(1.2, 4.2, 14.5), V3(0, 3.6, 6.2), 1.6)
	if opts.before then opts.before(you) end
	S:lines(lines)
	return you
end
T.evict = function(S, o, ctx, lines)
	local you = S:actor("you", S:pt(-3, 17), S:pt(0, 0))
	local door = S:part(V3(5, 8, 0.4), RGB(120, 80, 50), Enum.Material.Wood, o * CF(0, 4, 0.25))
	local tenant = S:actor("tenant", S:pt(0, -1.4), S:pt(0, 10))
	if tenant then A.setVisible(tenant, false) end
	S:shot(V3(15, 7, 24), V3(0, 3, 4), 0)
	S:walk(you, S:pt(0, 4.3), 9, true)
	S:shot(V3(8, 5, 10), V3(0, 4, 2), 0.7)
	S:move(you, "knock")
	S:sfx("knock")
	S:wait(0.9)
	S:swing(door, o * CF(-2.5, 4, 0.25), -1.7, 0.35)
	if tenant then
		A.setVisible(tenant, true)
		tenant.base = A.faceTowards(S:pt(0, 1.8), S:pt(0, 10))
	end
	S:wait(0.3)
	S:move(you, "show")
	if you then A.setProp(you, "notice") end
	S:shot(V3(-6, 5, 9.5), V3(0, 4, 2.5), 0.5)
	S:lines(lines)
	if you then A.setProp(you, nil) end
	-- the move-out, cartoon style
	if tenant then A.setProp(tenant, "box") end
	S:move(you, "gesture")
	S:shot(V3(13, 8, 17), V3(0, 2, 8), 0.7)
	S:walk(tenant, S:pt(5, 11), 9)
	for i = 1, 3 do
		S:toss("box", o * CF(0, 6, 0.6), S:pt(-5 + i * 2.6, 8.5 + i), 6, 0.8)
		S:wait(0.3)
	end
	S:toss("item", o * CF(0, 6, 0.6), S:pt(6.5, 13), 9, 1.2, 3, ctx.item)
	if you then for _ = 1, 3 do A.chatPop(S.folder, you.head.Position + V3(0, 3, 0), {"💀", "NOT THE " .. string.upper(string.match(tostring(ctx.item), "(%S+)$") or "STUFF"), "W landlord", "CLIP IT"}) end end
	S:wait(1.2)
	S:walk(tenant, S:pt(16, 26), 11)
	S:walk(you, S:pt(0, 4.8), 6, true)
	S:swing(door, o * CF(-2.5, 4, 0.25), 0, 0.3)
	S:move(you, "owner")
	S:wait(0.9)
end
-- each business's signature opening moment
local SIGNATURE = {
	lemonade = function(S, o)
		local sign = S:part(V3(4, 2, 0.3), RGB(255, 225, 60), Enum.Material.SmoothPlastic, o * CF(2.5, 5, 1.2))
		local front = new("SurfaceGui", {Face = Enum.NormalId.Back, CanvasSize = Vector2.new(200, 100), LightInfluence = 0}, sign)
		label({Size = UDim2.fromScale(1, 1), Text = "CLOSED", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = RGB(200, 40, 40)}, front)
		local back = new("SurfaceGui", {Face = Enum.NormalId.Front, CanvasSize = Vector2.new(200, 100), LightInfluence = 0}, sign)
		label({Size = UDim2.fromScale(1, 1), Text = "OPEN 🍋", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = RGB(30, 150, 60)}, back)
		local t = 0
		local base = sign.CFrame * CFrame.Angles(0, math.pi, 0)
		sign.CFrame = base
		S:wait(0.5)
		table.insert(S.updaters, function(dt)
			t += dt
			local k = math.min(1, t / 0.6)
			sign.CFrame = base * CFrame.Angles(0, math.pi * k + math.sin(k * math.pi) * 0.3, 0)
			return k >= 1
		end)
	end,
	icecream = function(S, o)
		local box = S:part(V3(5, 2.6, 2.4), RGB(220, 240, 255), Enum.Material.Glass, o * CF(0, 1.3, 2.6))
		local lid = S:part(V3(5, 0.3, 2.4), RGB(180, 220, 255), Enum.Material.SmoothPlastic, o * CF(0, 2.75, 2.6))
		S:swing(lid, o * CF(0, 2.75, 1.4), 0, 0.01)
		S:wait(0.4)
		local hinge = o * CF(0, 2.75, 1.4)
		local rel = hinge:ToObjectSpace(lid.CFrame)
		local t = 0
		table.insert(S.updaters, function(dt)
			t += dt
			local k = math.min(1, t / 0.5)
			lid.CFrame = hinge * CFrame.Angles(-1.4 * k, 0, 0) * rel
			return k >= 1
		end)
		for i = 1, 12 do
			local m = S:part(V3(1, 1, 1), RGB(235, 250, 255), Enum.Material.Neon, o * CF(math.random(-20, 20) / 10, 3, 2.6), Enum.PartType.Ball)
			m.Transparency = 0.3
			tween(m, 1.6, {Size = V3(5, 5, 5), Transparency = 1, CFrame = m.CFrame + V3(math.random(-30, 30) / 10, 3 + math.random() * 2, 2)})
			if i % 4 == 0 then S:wait(0.15) end
		end
		local _ = box
	end,
	bakery = function(S, o)
		S:part(V3(5, 4, 3), RGB(170, 90, 60), Enum.Material.Brick, o * CF(0, 2, 2.5))
		local glow = S:part(V3(3, 1.4, 0.2), RGB(255, 140, 40), Enum.Material.Neon, o * CF(0, 2, 4.05))
		glow.Transparency = 1
		tween(glow, 0.5, {Transparency = 0})
		for i = 1, 6 do
			local w = S:part(V3(0.25, 1.4, 0.25), RGB(255, 240, 220), Enum.Material.Neon, o * CF(-1.5 + i * 0.5, 4.5, 4))
			tween(w, 1.8, {CFrame = w.CFrame * CF(math.sin(i) * 2, 5, 3) * CFrame.Angles(0, 0, 0.6), Transparency = 1})
		end
		S:wait(0.6)
	end,
	coffee = function(S, o)
		local m = S:part(V3(3, 3, 2), RGB(190, 190, 200), Enum.Material.Metal, o * CF(0, 1.5, 2.6))
		for i = 1, 8 do
			local puff = S:part(V3(0.8, 0.8, 0.8), WHITE, Enum.Material.Neon, o * CF(0.5, 3.2, 2.6), Enum.PartType.Ball)
			tween(puff, 1.2, {CFrame = puff.CFrame + V3(math.random(-10, 10) / 10, 3, math.random(0, 10) / 10), Size = V3(2, 2, 2), Transparency = 1})
			S:wait(0.1)
		end
		A.bubble(m.Position + V3(0, 3, 0), "Espresso machine", "BRRRRRRRRR ☕", 2.5, S.folder)
	end,
	pizza = function(S, o)
		S:part(V3(5, 4, 3), RGB(170, 90, 60), Enum.Material.Brick, o * CF(-2, 2, 2.5))
		S:part(V3(4, 2.6, 2), RGB(230, 225, 215), Enum.Material.SmoothPlastic, o * CF(3, 1.3, 3.2))
		local pz = S:part(V3(0.3, 2.6, 2.6), RGB(240, 180, 70), Enum.Material.SmoothPlastic, o * CF(-2, 2.4, 4), Enum.PartType.Cylinder)
		local t = 0
		table.insert(S.updaters, function(dt)
			t += dt
			local k = math.min(1, t / 1.2)
			local pos = (o * CF(-2, 2.4, 4)).Position:Lerp((o * CF(3, 2.9, 3.2)).Position, k) + V3(0, math.sin(k * math.pi) * 4, 0)
			pz.CFrame = CF(pos) * CFrame.Angles(0, t * 14, math.pi / 2)
			return k >= 1
		end)
		S:wait(1.3)
	end,
	arcade = function(S, o)
		local lights = {}
		for i = 1, 7 do
			local l = S:part(V3(1.4, 1.4, 0.3), Color3.fromHSV(i / 7, 0.8, 0.25), Enum.Material.Neon, o * CF(-6 + i * 1.5, 7, 0.8))
			lights[i] = l
		end
		for i, l in ipairs(lights) do
			l.Color = Color3.fromHSV(i / 7, 0.8, 1)
			play(SND.click)
			S:wait(0.12)
		end
	end,
	tech = function(S, o)
		for i = 1, 4 do
			local scr = S:part(V3(2.6, 1.6, 0.2), RGB(10, 10, 14), Enum.Material.Glass, o * CF(-4.5 + i * 1.8 + (i > 2 and 0.6 or 0), 4, 1))
			S:wait(0.18)
			scr.Material = Enum.Material.Neon
			scr.Color = RGB(80, 200, 255)
		end
	end,
	factory = function(S, o)
		local gears = {}
		for i = 1, 2 do gears[i] = S:part(V3(0.6, 3, 3), RGB(160, 160, 170), Enum.Material.Metal, o * CF(-3 + i * 3.5, 3, 1.5), Enum.PartType.Cylinder) end
		local t = 0
		table.insert(S.updaters, function(dt)
			t += dt
			for i, g in ipairs(gears) do g.CFrame = o * CF(-3 + i * 3.5, 3, 1.5) * CFrame.Angles(0, math.pi / 2, t * (i == 1 and 4 or -4)) end
			return t > 6
		end)
		for _ = 1, 6 do
			local puff = S:part(V3(1.2, 1.2, 1.2), RGB(200, 200, 205), Enum.Material.SmoothPlastic, o * CF(0, 7, 0.5), Enum.PartType.Ball)
			tween(puff, 1.6, {CFrame = puff.CFrame + V3(math.random(-10, 10) / 10, 5, 0), Size = V3(3, 3, 3), Transparency = 1})
			S:wait(0.18)
		end
	end,
}
T.opening = function(S, o, ctx, lines)
	local you = S:actor("you", S:pt(-1.5, 6), S:pt(0, 0))
	S:shot(V3(6, 5, 15), V3(0, 3.5, 2), 0)
	S:shot(V3(3, 4.5, 11), V3(0, 3.5, 2), 1.2)
	S:move(you, "owner")
	local sig = SIGNATURE[ctx.key] or SIGNATURE.lemonade
	local ok, err = pcall(sig, S, o)
	if not ok then warn("[CornerEmpire] opening signature: " .. tostring(err)) end
	S:wait(0.6)
	if ctx.crowd then
		local crowd = {}
		for i = 1, 6 do
			local a = S.near and A.make(S.folder, A.randomLook(i * 37 + #tostring(ctx.key)))
			if a then
				a.base = A.faceTowards(S:pt(-6 + i * 2.2, 13 + (i % 2) * 2), S:pt(0, 0))
				crowd[i] = a
				S.actors["crowd" .. i] = a
			end
		end
		S.alias.crowd1, S.alias.crowd2 = crowd[2], crowd[4]
		S:shot(V3(9, 6, 22), V3(0, 3, 9), 0.8)
		S:lines(lines)
		-- the rush for the door
		for _, a in ipairs(crowd) do A.walkTo(a, S:pt(math.random(-15, 15) / 10, 1.5), 15 + math.random() * 4) end
		S:shot(V3(-8, 5, 12), V3(0, 3, 4), 0.6)
		S:wait(1.1)
	end
	A.confetti(S.folder, S:pt(0, 5), 30)
	S:move(you, "celebrate")
	S:wait(1.2)
end
-- v12: the billionaire moment. The camera starts on the owner at the foot of their tower, then tilts up the whole height while confetti falls.
T.milestone = function(S, o, ctx, lines)
	local you = S:actor("you", S:pt(0, 8), S:pt(0, 0))
	local up = 6 + (ctx.index or 1) * 14
	S:shot(V3(0, 3.2, 20), V3(0, 4, 2), 0)
	S:move(you, "owner")
	S:wait(0.8)
	S:shot(V3(4, 8, 24), V3(0, up * 0.6, -6), 1.6)
	S:shot(V3(10, up * 0.5, 34), V3(0, up, -6), 1.8)
	A.confetti(S.folder, S:pt(0, up * 0.5), 40)
	S:lines(lines)
	S:move(you, "celebrate")
	A.confetti(S.folder, S:pt(0, 12), 40)
	S:wait(1.4)
end
T.hqReveal = function(S, o, ctx, lines)
	local you = S:actor("you", S:pt(0, 9), S:pt(0, 0))
	S:shot(V3(0, 3, 18), V3(0, 6, 0), 0)
	S:wait(0.5)
	S:shot(V3(8, 12, 26), V3(0, 18, -4), 1.8)
	A.confetti(S.folder, S:pt(0, 14), 30)
	S:lines(lines)
	S:move(you, "celebrate")
	S:wait(1.0)
end
T.hire = function(S, o, ctx, lines) dialogue(S, o, lines) end
T.fire = function(S, o, ctx, lines)
	dialogue(S, o, lines, {props = {staff = "box"}})
	local staff = S.actors.staff
	S:walk(staff, S:pt(14, 20), 8)
	S:wait(1.2)
end
T.buyProperty = function(S, o, ctx, lines)
	dialogue(S, o, lines, {props = {realtor = "keys"}})
	A.confetti(S.folder, S:pt(0, 6), 20)
end
T.upgrade = function(S, o, ctx, lines)
	A.confetti(S.folder, S:pt(0, 3, 6), 24)
	dialogue(S, o, lines)
end
T.complaint = function(S, o, ctx, lines) dialogue(S, o, lines) end
T.inspection = function(S, o, ctx, lines) dialogue(S, o, lines, {props = {inspector = "clipboard"}}) end
T.competition = function(S, o, ctx, lines)
	S:part(V3(6, 1.5, 4), RGB(255, 205, 60), Enum.Material.Neon, o * CF(-2.6, 0.75, 7))
	local you = dialogue(S, o, lines, {before = function(you) if you then you.base = you.base + V3(0, 1.5, 0) end end})
	A.confetti(S.folder, S:pt(-2.6, 7), 40)
	S:move(you, "celebrate")
	S:wait(1)
end
T.investment = function(S, o, ctx, lines)
	local you = dialogue(S, o, lines, {props = {investor = "briefcase"}})
	for _ = 1, 4 do A.chatPop(S.folder, S:pt(-2.6, 7, 6), {"💸", "💰", "$$$", "💵💵"}) end
	S:move(you, "money")
	S:wait(1)
end
T.luxury = function(S, o, ctx, lines)
	local you = S:actor("you", S:pt(0, 5), S:pt(0, 14))
	for i = 1, 4 do
		local p = S:actor("photographer" .. i, S:pt(-6 + i * 2.4, 12 + (i % 2)), S:pt(0, 5), {prop = "camera", look = "photographer"})
		if p then p.anim = "flash" end
	end
	S.alias.crowd1, S.alias.crowd2 = S.actors.photographer2, S.actors.photographer3
	S:shot(V3(3, 4, 10), V3(0, 4, 5), 0)
	S:shot(V3(-2, 4.5, 12), V3(0, 4, 5), 2)
	S:move(you, "owner")
	local flashing = true
	task.spawn(function()
		while flashing and not S.skipped do
			A.flashAt(S.folder, S:pt(math.random(-6, 6), 12, 4.5))
			task.wait(0.2 + math.random() * 0.3)
		end
	end)
	S:lines(lines)
	flashing = false
end
T.customerArmy = function(S, o, ctx, lines)
	S:actor("manager", S:pt(3, 4), S:pt(0, 14), {prop = "clipboard"})
	S:actor("you", S:pt(-3, 5), S:pt(0, 14))
	for i = 1, 10 do
		local a = S.near and A.make(S.folder, A.randomLook(i * 13))
		if a then
			a.base = A.faceTowards(S:pt(-10 + i * 2, 24 + (i % 3) * 2), S:pt(0, 0))
			A.walkTo(a, S:pt(math.random(-20, 20) / 10, 1), 14 + math.random() * 5)
			S.actors["army" .. i] = a
		end
	end
	S:shot(V3(8, 6, 16), V3(0, 3, 10), 0)
	S:lines(lines)
end
T.deliveryDisaster = function(S, o, ctx, lines) dialogue(S, o, lines, {props = {courier = "pizzabox"}}) end
T.richKid = function(S, o, ctx, lines) dialogue(S, o, lines, {props = {richkid = "goldcard"}}) end
T.badInvestor = function(S, o, ctx, lines) dialogue(S, o, lines, {props = {investor = "briefcase"}}) end
T.influencer = function(S, o, ctx, lines)
	local you = dialogue(S, o, lines)
	if ctx.influencer == "baysnaps" then for _ = 1, 5 do A.chatPop(S.folder, S:pt(2, 6, 6)) end end
	S:move(you, "owner")
end
T.clipz = function(S, o, ctx, lines) dialogue(S, o, lines) end

-- =====================================================================
-- PLAYING
-- =====================================================================
local queue, playing = {}, false
C.cinematicPlaying = function() return playing end
CC.queue = queue
local function setUI(full, on)
	sub.Visible = false
	skipB.Visible = on
	hintL.Visible = on and full
	photoB.Visible = on and full and C.setPhoto ~= nil
	titleCard.Visible = false
	if full then
		tween(barTop, 0.35, {Size = UDim2.new(1, 0, 0, on and 56 or 0)})
		tween(barBot, 0.35, {Size = UDim2.new(1, 0, 0, on and 56 or 0)})
	end
end
local function run(scene)
	local S = newStage(scene)
	current = S
	playing = true
	local full = S.mode == "full"
	local guiWas = gui.Enabled
	local cam = S.cam
	local oldType = cam.CameraType
	if full then
		gui.Enabled = false
		cam.CameraType = Enum.CameraType.Scriptable
	end
	setUI(full, true)
	if scene.title then
		titleCard.Text = scene.title
		titleCard.Visible = true
		titleCard.TextTransparency = 0
		task.delay(1.6, function() if current == S then tween(titleCard, 0.5, {TextTransparency = 1}) end end)
	end
	local last = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = math.min(0.1, now - last)
		last = now
		if S.paused then return end
		for _, a in pairs(S.actors) do A.step(a, dt, now) end
		for i = #S.updaters, 1, -1 do
			local ok, done = pcall(S.updaters[i], dt, now)
			if not ok or done then table.remove(S.updaters, i) end
		end
	end)
	local tmpl = T[scene.kind] or function(St, o, ctx, lines) dialogue(St, o, lines) end
	local ok, err = pcall(tmpl, S, S.anchor, scene.ctx or {}, scene.lines or {})
	if not ok then
		CC.stats.errors += 1
		warn("[CornerEmpire] cinematic \"" .. tostring(scene.kind) .. "\" error (cleaned up safely): " .. tostring(err))
	end
	-- always clean up, whatever happened
	conn:Disconnect()
	S.folder:Destroy()
	setUI(full, false)
	-- (back on the main menu? it owns the camera and the HUD stays hidden)
	if full and not C.inMainMenu then
		cam.CameraType = (oldType == Enum.CameraType.Scriptable) and Enum.CameraType.Custom or oldType
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
		gui.Enabled = guiWas ~= false
	end
	if S.skipped then CC.stats.skipped += 1 end
	CC.stats.played += 1
	CC.stats.cleaned += 1
	CC.last = {kind = scene.kind, id = scene.id, skipped = S.skipped, mode = S.mode, near = S.near, error = not ok, cleaned = S.folder.Parent == nil}
	current = nil
	playing = false
	showBanner(scene.result)
	if scene.react and C.AnimationConfig then pcall(C.AnimationConfig.react, scene.react) end
end
local pumping = false
local function pump()
	if pumping then return end
	pumping = true
	task.spawn(function()
		while #queue > 0 do
			local scene = queue[1]
			-- wait for a calm moment: in the game, not in Photo Mode, not during a story cutscene
			local waited = os.clock()
			while true do
				local busy = not gui.Enabled or C.photoActive or (C.storyCutscene and C.storyCutscene()) or not C.S
				if not busy then break end
				if os.clock() - waited > 20 then break end
				task.wait(0.25)
			end
			table.remove(queue, 1)
			local setting = C.settings and C.settings.cinematics or "full"
			if os.clock() - waited > 20 or setting == "off" then
				-- too late (or turned off): just the result
				CC.stats.dropped += 1
				showBanner(scene.result)
			else
				local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
				if setting == "short" or (hum and hum.SeatPart ~= nil) then scene.mode = "short" end
				if typeof(scene.at) ~= "CFrame" then
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					scene.at = root and root.CFrame * CF(0, -3, -8) or CF()
				end
				run(scene)
			end
		end
		pumping = false
	end)
end
function CC.play(scene)
	if type(scene) ~= "table" or type(scene.kind) ~= "string" then return end
	if #queue >= MAX_QUEUE then
		-- never let scenes pile up: drop the oldest (its result banner still shows)
		local old = table.remove(queue, 1)
		CC.stats.dropped += 1
		showBanner(old.result)
	end
	table.insert(queue, scene)
	pump()
end
remote.OnClientEvent:Connect(CC.play)
function C.cinematicSkip()
	if current then current.skipped = true end
end
-- leaving to the main menu: end the scene and forget anything queued
function CC.clear()
	table.clear(queue)
	if current then current.skipped = true end
	banner.Visible = false
end
skipB.MouseButton1Click:Connect(function()
	play(SND.click)
	C.cinematicSkip()
end)
UserInputService.InputBegan:Connect(function(input)
	if not playing then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.Backspace or k == Enum.KeyCode.ButtonB then C.cinematicSkip() end
	if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then advance = true end
end)
-- respawning mid-scene ends it cleanly
plr.CharacterAdded:Connect(function() if current then current.skipped = true end end)
-- 📸: pause the scene and open Photo Mode at the current shot
photoB.MouseButton1Click:Connect(function()
	local S = current
	if not (S and S.mode == "full" and C.setPhoto) then return end
	play(SND.click)
	S.paused = true
	if S.scene.moment then act("viral", "capture", S.scene.moment) end
	local shot = S.cam.CFrame
	sg.Enabled = false
	gui.Enabled = true
	C.setPhoto(true)
	task.spawn(function()
		while C.photoActive do task.wait(0.1) end
		gui.Enabled = false
		sg.Enabled = true
		if current == S then
			S.cam.CameraType = Enum.CameraType.Scriptable
			S.cam.CFrame = S.lastShot or shot
		end
		S.paused = false
	end)
end)
end
