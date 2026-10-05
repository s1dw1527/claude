-- CITY LIFE: what the whole server sees when something happens in the city.
--   influencer sightings (the influencer standing there, a 🚨 marker you can find from anywhere)
--   THE CROWD outside a business, PAPARAZZI following a player, EVERYONE KNOWS YOU passers-by
--   the "VIRAL MOMENT" pop-up (with a 📸 capture button) and the beef / live-challenge tracker
-- Performance: actors are only built near the camera and animated only when close; everything is capped and
-- removed when its event ends. Another player's event far across the city costs you (almost) nothing.
return function(C)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RGB, V3, CF = Color3.fromRGB, Vector3.new, CFrame.new
local new, tween, label, button, corner, stroke = C.new, C.tween, C.label, C.button, C.corner, C.stroke
local play, SND, act, gui, plr, U = C.play, C.SND, C.act, C.gui, C.plr, C.U
local GOLD, WHITE, SUB = C.GOLD, C.WHITE, C.SUB
local A = C.Actors
local remote = ReplicatedStorage:WaitForChild("Viral")

local FOLDER = A.folder("CityLife")
local BUILD_DIST, ANIM_DIST = 260, 160
local MAX_EXTRA = 24          -- crowd + paparazzi + passers-by actors on screen at once
local CL = {events = {}, actorCount = 0}
C.CityLife = CL

local function camPos() return Workspace.CurrentCamera.CFrame.Position end
local function myRoot() return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") end
local function count() return CL.actorCount end

-- =====================================================================
-- EVENTS: each one owns its actors and gets a step(dt, now) until it ends
-- =====================================================================
local events = CL.events
local function addEvent(ev)
	ev.actors = ev.actors or {}
	ev.started = os.clock()
	table.insert(events, ev)
	return ev
end
local function freeActor(ev, a)
	for i, x in ipairs(ev.actors) do
		if x == a then table.remove(ev.actors, i) break end
	end
	A.destroy(a)
	CL.actorCount -= 1
end
local function endEvent(ev)
	for _, a in ipairs(ev.actors) do A.destroy(a) CL.actorCount -= 1 end
	ev.actors = {}
	if ev.marker then ev.marker:Destroy() end
	ev.dead = true
end
local function makeActor(ev, look, cf, opts)
	if CL.actorCount >= MAX_EXTRA + (ev.vip and 4 or 0) then return nil end
	local a = A.make(FOLDER, look, opts)
	a.base = cf
	CL.actorCount += 1
	table.insert(ev.actors, a)
	return a
end
CL.endAll = function() for _, ev in ipairs(events) do endEvent(ev) end table.clear(events) end

-- =====================================================================
-- INFLUENCERS
-- =====================================================================
local influencerEv = {}   -- [visit id] = event
local function marker(pos, text, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = V3(0.5, 0.5, 0.5)
	p.CFrame = CF(pos + V3(0, 9, 0))
	p.Parent = FOLDER
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(210, 34), AlwaysOnTop = true, MaxDistance = 900, LightInfluence = 0}, p)
	local f = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or RGB(230, 30, 80), BorderSizePixel = 0}, bb)
	corner(f, 10)
	label({Size = UDim2.fromScale(1, 1), Text = text, TextScaled = true, Font = Enum.Font.GothamBlack}, f)
	return p
end
local IDLE = {baysnaps = {"selfie", "hype", "talk", "selfie"}, jaxcash = {"crossed", "owner", "phone"}, mayamax = {"look", "selfie", "think"}, drewdeals = {"talk", "show", "phone"}}
local function influencer(e)
	if typeof(e.cf) ~= "CFrame" then return end
	local mine = e.target == plr.UserId
	local ev = addEvent({kind = "influencer", id = e.id, who = e.who, vip = true, ends = os.clock() + (e.dur or 120) + 5})
	influencerEv[e.id] = ev
	ev.marker = marker(e.cf.Position, "🚨 " .. string.upper(e.name or "?") .. (mine and " • FOR YOU" or ""), mine and RGB(230, 30, 80) or RGB(120, 60, 200))
	ev.step = function(dt, now)
		local d = (camPos() - e.cf.Position).Magnitude
		if not ev.npc and d < BUILD_DIST then
			ev.npc = makeActor(ev, e.who, e.cf, {tag = e.name})
			if ev.npc then A.play(ev.npc, "wave", now) end
		elseif ev.npc and d > BUILD_DIST + 60 then
			freeActor(ev, ev.npc)
			ev.npc = nil
		end
		if ev.npc and d < ANIM_DIST then
			if now >= (ev.nextMove or 0) then
				ev.nextMove = now + 3 + math.random() * 2
				local list = IDLE[e.who] or {"idle"}
				A.play(ev.npc, list[math.random(#list)], now)
				if e.who == "baysnaps" and math.random() < 0.6 then
					for _ = 1, 2 do A.chatPop(FOLDER, ev.npc.head.Position + V3(0, 2, 0)) end
				end
				if math.random() < 0.3 then A.bubble(ev.npc.head.Position + V3(0, 3, 0), e.name, e.catch or "", 3, FOLDER) end
			end
			A.step(ev.npc, dt, now)
		end
	end
	if mine then
		play(SND.event)
		if C.Cinematics then C.Cinematics.showBanner({"🚨 " .. string.upper(e.name) .. " IS HERE", "At your " .. tostring(e.place) .. " — go talk to them!"}) end
		if U.setBeamTarget then U.setBeamTarget("map", e.cf.Position) end
		ev.beam = true
	elseif U.toast then
		U.toast("🚨 " .. e.name .. " spotted at " .. tostring(e.targetName) .. "'s " .. tostring(e.place) .. "!")
	end
end
local function influencerLeave(e)
	local ev = influencerEv[e.id]
	if not ev then return end
	influencerEv[e.id] = nil
	if ev.beam and U.setBeamTarget then U.setBeamTarget("map", nil) end
	if ev.marker then ev.marker:Destroy() ev.marker = nil end
	-- walk off, then gone
	if ev.npc then
		A.walkTo(ev.npc, ev.npc.base.Position + ev.npc.base.LookVector * -2 + V3(math.random(-30, 30), 0, math.random(-30, 30)), 8)
		ev.ends = os.clock() + 3.5
	else
		ev.ends = os.clock()
	end
end

-- =====================================================================
-- THE CROWD
-- =====================================================================
local CROWD_MOVES = {"hype", "selfie", "phone", "clap", "look", "point"}
local function crowd(e)
	if typeof(e.anchor) ~= "CFrame" then return end
	local ev = addEvent({kind = "crowd", ends = os.clock() + (e.dur or 40)})
	local o = e.anchor
	ev.step = function(dt, now)
		local d = (camPos() - o.Position).Magnitude
		if #ev.actors == 0 and d < BUILD_DIST and not ev.built then
			ev.built = true
			for i = 1, math.min(e.n or 12, 16) do
				local ring = 8 + (i % 3) * 3
				local ang = (i / (e.n or 12)) * math.pi - math.pi / 2
				local pos = (o * CF(math.sin(ang) * ring, 0, 6 + math.cos(ang) * ring * 0.6)).Position
				local a = makeActor(ev, A.randomLook(i * 31 + (e.owner or 0)), A.faceTowards(pos, o.Position))
				if a then A.play(a, CROWD_MOVES[math.random(#CROWD_MOVES)], now + math.random()) end
			end
		elseif ev.built and d > BUILD_DIST + 80 then
			for _, a in ipairs(table.clone(ev.actors)) do freeActor(ev, a) end
			ev.built = false
		end
		if d < ANIM_DIST then
			for _, a in ipairs(ev.actors) do
				if math.random() < dt * 0.25 then A.play(a, CROWD_MOVES[math.random(#CROWD_MOVES)], now) end
				if a.anim == "selfie" and math.random() < dt * 0.5 then A.flashAt(FOLDER, a.head.Position + a.base.LookVector * -1.5) end
				A.step(a, dt, now)
			end
		end
	end
	if e.owner == plr.UserId and U.toast then U.toast("👥 THE CROWD is outside your " .. tostring(e.biz) .. "!") end
end

-- =====================================================================
-- PAPARAZZI (follow a player around for a while)
-- =====================================================================
local function paparazzi(e)
	local who = Players:GetPlayerByUserId(e.userId or 0)
	if not who then return end
	local ev = addEvent({kind = "paparazzi", ends = os.clock() + (e.dur or 30)})
	ev.step = function(dt, now)
		local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local d = (camPos() - root.Position).Magnitude
		if not ev.built and d < BUILD_DIST then
			ev.built = true
			for i = 1, 5 do makeActor(ev, "photographer", CF(root.Position + V3(math.cos(i) * 10, -3, math.sin(i) * 10)), {prop = "camera"}) end
		end
		if d < ANIM_DIST then
			for i, a in ipairs(ev.actors) do
				local ang = now * 0.4 + i * (math.pi * 2 / 5)
				local goal = root.Position + V3(math.cos(ang) * 11, -3, math.sin(ang) * 11)
				if (a.base.Position - goal).Magnitude > 2 then A.walkTo(a, goal, 14) end
				if not a.goal then a.base = A.faceTowards(a.base.Position, root.Position) A.play(a, "flash", 0) end
				if math.random() < dt * 1.2 then A.flashAt(FOLDER, a.head.Position + (root.Position - a.head.Position).Unit * 1.5) end
				A.step(a, dt, now)
			end
		end
	end
	if who == plr and U.toast then U.toast("📸 PAPARAZZI MODE! Strike a pose (📸 → emotes).") end
end

-- =====================================================================
-- EVERYONE KNOWS YOU (just for you: people walking past recognize you)
-- =====================================================================
local function famous(e)
	if e.userId ~= plr.UserId then return end
	local lines = e.lines or {"THAT'S THEM!"}
	local ev = addEvent({kind = "famous", ends = os.clock() + (e.dur or 180)})
	ev.step = function(dt, now)
		local root = myRoot()
		if not root or plr:GetAttribute("Interior") then return end
		-- keep up to two passers-by around; each walks past, shouts once, then leaves
		if #ev.actors < 2 and now >= (ev.next or 0) then
			ev.next = now + 5 + math.random() * 3
			local side = math.random() < 0.5 and -1 or 1
			local fwd = root.CFrame.LookVector * V3(1, 0, 1)
			if fwd.Magnitude < 0.1 then fwd = V3(0, 0, -1) end
			fwd = fwd.Unit
			local right = V3(-fwd.Z, 0, fwd.X)
			local start = root.Position + fwd * 26 + right * side * 5 - V3(0, 3, 0)
			local a = makeActor(ev, A.randomLook(math.random(1, 1e5)), A.faceTowards(start, root.Position))
			if a then
				a.line = lines[math.random(#lines)]
				a.leave = now + 9
				A.walkTo(a, root.Position - fwd * 22 + right * side * 4 - V3(0, 3, 0), 6)
			end
		end
		for _, a in ipairs(table.clone(ev.actors)) do
			if a.line and (a.base.Position - root.Position).Magnitude < 14 then
				A.bubble(a.head.Position + V3(0, 2.6, 0), "", a.line, 3, FOLDER)
				A.play(a, math.random() < 0.5 and "point" or "shock", now)
				a.line = nil
				a.goal = nil
				task.delay(1.2, function() if not a.dead then A.walkTo(a, a.base.Position + V3(math.random(-20, 20), 0, math.random(-20, 20)), 7) end end)
			end
			A.step(a, dt, now)
			if now > a.leave then freeActor(ev, a) end
		end
	end
	play(SND.event)
end

-- =====================================================================
-- THE LOOP
-- =====================================================================
local last = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.min(0.1, now - last)
	last = now
	for i = #events, 1, -1 do
		local ev = events[i]
		if ev.dead or now > ev.ends then
			if not ev.dead then endEvent(ev) end
			table.remove(events, i)
		elseif ev.step then
			local ok, err = pcall(ev.step, dt, now)
			if not ok then
				warn("[CornerEmpire] city life: " .. tostring(err))
				endEvent(ev)
				table.remove(events, i)
			end
		end
	end
end)

-- =====================================================================
-- VIRAL MOMENT POP-UP (+ 📸 capture)
-- =====================================================================
local pop = C.panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 190), Size = UDim2.fromOffset(380, 96), BackgroundColor3 = RGB(40, 14, 30), Visible = false, ZIndex = 45}, gui)
stroke(pop, RGB(255, 90, 60), 2, 0.1)
local popTitle = label({Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 140, 90),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 46}, pop)
local popText = label({Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -120, 0, 60), TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 46}, pop)
local capB = button({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(98, 40), Text = "📸 Capture", TextSize = 14, BackgroundColor3 = RGB(230, 70, 150), ZIndex = 47}, pop)
local popId, popMoment = 0, nil
CL.lastMoment = nil
local function moment(e)
	CL.lastMoment = e
	popId += 1
	local my = popId
	popMoment = e
	popTitle.Text = (e.legendary and "🏆 LEGENDARY MOMENT" or (e.rare and "🌟 RARE VIRAL MOMENT" or "🔥 VIRAL MOMENT")) .. "  +" .. tostring(e.score) .. "  (" .. C.fmt(e.total or 0) .. ")"
	popText.Text = (e.icon or "🔥") .. " " .. tostring(e.title) .. "\n" .. tostring(e.text or "")
	pop.Visible = true
	play(SND.event)
	local s = new("UIScale", {Scale = 0.7}, pop)
	tween(s, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
	task.delay(10, function()
		s:Destroy()
		if popId == my then pop.Visible = false popMoment = nil end
	end)
end
capB.MouseButton1Click:Connect(function()
	local e = popMoment
	if not e then return end
	play(SND.click)
	pop.Visible = false
	popMoment = nil
	act("viral", "capture", e.id)
	if C.setPhoto then C.setPhoto(true) end
end)
CL.capture = function() if popMoment then act("viral", "capture", popMoment.id) end end

-- the beef / live challenge tracker (top center, under the event bar)
local pill = C.panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(440, 32), BackgroundColor3 = RGB(120, 30, 30), Visible = false, ZIndex = 30}, gui)
local pillL = label({Size = UDim2.fromScale(1, 1), TextSize = 13, Font = Enum.Font.GothamBlack, TextWrapped = true, ZIndex = 31}, pill)
C.onState(function(s)
	local b = s.beef
	pill.Visible = b ~= nil
	if b then
		pill.BackgroundColor3 = b.kind == "beef" and RGB(120, 30, 30) or RGB(150, 40, 110)
		pillL.Text = tostring(b.text) .. "  ⏱ " .. tostring(b.left) .. "s"
	end
end)

-- =====================================================================
-- CRASH DETECTION (your own car, hard stop next to your own business: the server checks the rest)
-- =====================================================================
local lastSpeed, lastCrash = 0, 0
RunService.Heartbeat:Connect(function()
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat:GetAttribute("CarOwner") == plr.UserId) then
		lastSpeed = 0
		return
	end
	local v = seat.AssemblyLinearVelocity
	if typeof(v) ~= "Vector3" then return end
	local speed = V3(v.X, 0, v.Z).Magnitude
	local now = os.clock()
	if lastSpeed > 45 and speed < lastSpeed * 0.35 and now - lastCrash > 60 then
		lastCrash = now
		act("viral", "crash", math.floor(lastSpeed))
	end
	lastSpeed = speed
end)

-- =====================================================================
remote.OnClientEvent:Connect(function(e)
	if type(e) ~= "table" then return end
	local ok, err = pcall(function()
		if e.kind == "influencer" then influencer(e)
		elseif e.kind == "influencerLeave" then influencerLeave(e)
		elseif e.kind == "crowd" then crowd(e)
		elseif e.kind == "paparazzi" then paparazzi(e)
		elseif e.kind == "famous" then famous(e)
		elseif e.kind == "moment" then moment(e)
		elseif e.kind == "say" then
			if typeof(e.pos) == "Vector3" then A.bubble(e.pos + V3(0, 7, 0), e.name or "", e.text or "", 4, FOLDER) end
		elseif e.kind == "beef" then
			play(SND.event)
			if C.Cinematics then C.Cinematics.showBanner({"🥩 BUSINESS BEEF", tostring(e.rival) .. " opened a pop-up next door. Serve " .. tostring(e.goal) .. " customers!"}) end
		elseif e.kind == "beefEnd" then
			if C.Cinematics then C.Cinematics.showBanner(e.won and {"🥩 BEEF WON", "The pop-up is packing up"} or {"🥩 BEEF OVER", "They'll be back. Probably."}) end
		elseif e.kind == "challenge" then
			play(SND.event)
			if C.Cinematics then C.Cinematics.showBanner({"📸 LIVE CHALLENGE", "Serve " .. tostring(e.goal) .. " customers in 2 minutes!"}) end
		end
	end)
	if not ok then warn("[CornerEmpire] viral event: " .. tostring(err)) end
end)
end
