-- STORY: cutscenes with the rival (Lil Clipz), his speech bubbles, the on-screen story tracker and the
-- phone's Story app. Everything here is local to this player: other players never get pulled into
-- your cutscene, and all the parts are client-side (cleaned up when the scene ends).
return function(C)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RGB, V3, CF = Color3.fromRGB, Vector3.new, CFrame.new
local new, tween, label, button, corner, stroke, gradient, clear, vlist = C.new, C.tween, C.label, C.button, C.corner, C.stroke, C.gradient, C.clear, C.vlist
local fmt, play, SND, act, gui, U, plr = C.fmt, C.play, C.SND, C.act, C.gui, C.U, C.plr
local GOLD, GREEN, GRAY, WHITE, SUB, CARD = C.GOLD, C.GREEN, C.GRAY, C.WHITE, C.SUB, C.CARD
local remote = ReplicatedStorage:WaitForChild("Story")
local cat = C.catalog.story or {chapters = {}, cast = {}, rival = {name = "Lil Clipz", icon = "🎙️"}}
local CAST = cat.cast or {}

-- its own ScreenGui so cutscenes can hide the HUD and still show the dialogue
local sg = new("ScreenGui", {Name = "EmpireStory", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, plr:WaitForChild("PlayerGui"))

-- =====================================================================
-- THE CAST: built with the shared actor kit (EmpireClient > Actors); Lil Clipz is an original character
-- =====================================================================
local A = C.Actors
local FX
local function part(size, color, mat, shape) return A.part(FX, size, color, mat, shape) end
local function newFolder()
	if FX then FX:Destroy() end
	FX = new("Folder", {Name = "StoryScene"}, Workspace)
	return FX
end
local function makeActor(look) return A.make(FX, look) end
local pose, ANIMS = A.pose, A.ANIMS
local function chatPop(pos) A.chatPop(FX, pos) end
local function confetti(pos, n) A.confetti(FX, pos, n) end
local faceTowards = A.faceTowards

-- =====================================================================
-- STAGE PROPS: Kevin's copycat stand, the spotlight entrance, the golden limo
-- =====================================================================
local function copycatStand(where)
	local base = faceTowards(where.curb + V3(-26, 0, 0), where.focus)
	local p = part(V3(7, 3.4, 3), RGB(255, 230, 120), Enum.Material.WoodPlanks)
	p.CFrame = base * CF(0, 1.7, 0)
	local top = part(V3(8, 0.4, 4), RGB(255, 200, 60))
	top.CFrame = base * CF(0, 5.6, 0)
	for _, x in ipairs({-3.6, 3.6}) do
		local pole = part(V3(0.3, 2.2, 0.3), RGB(120, 90, 60))
		pole.CFrame = base * CF(x, 4.4, 0)
	end
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(160, 40), StudsOffset = V3(0, 3, 0), MaxDistance = 160}, top)
	label({Size = UDim2.fromScale(1, 1), Text = "🥤 LEMON-AID 🥤", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 230, 80), TextStrokeTransparency = 0.1}, bb)
	local kevin = makeActor("kevin")
	return {base = base * CF(0, 0, -3), kevin = kevin}
end
local function limo(where)
	local parts = {}
	local function add(size, off, color, mat)
		local p = part(size, color, mat)
		table.insert(parts, {p, off})
	end
	local gold = RGB(255, 200, 60)
	add(V3(7, 2.4, 24), CF(0, 2, 0), gold, Enum.Material.Metal)
	add(V3(6.4, 2, 18), CF(0, 4.2, 1), RGB(30, 30, 40), Enum.Material.Glass)
	add(V3(6.6, 0.3, 18.4), CF(0, 5.3, 1), gold, Enum.Material.Metal)
	for _, sx in ipairs({-3.2, 3.2}) do
		for _, sz in ipairs({-8.5, 8.5}) do add(V3(1, 2.6, 2.6), CF(sx, 1.3, sz), RGB(20, 20, 20)) end
		add(V3(1.2, 0.5, 0.2), CF(sx * 0.6, 2.4, -12.05), RGB(255, 250, 220), Enum.Material.Neon)
	end
	local from = faceTowards(where.street, where.curb)
	local to = faceTowards(where.curb, where.curb + (where.curb - where.street))
	local function place(cf) for _, e in ipairs(parts) do e[1].CFrame = cf * e[2] end end
	place(from)
	return function(k) place(from:Lerp(to, k)) end, to
end

-- =====================================================================
-- DIALOGUE BOX
-- =====================================================================
local box = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.9, 0, 0, 150), BackgroundColor3 = RGB(16, 16, 24),
	BackgroundTransparency = 0.05, BorderSizePixel = 0, Visible = false, ZIndex = 10}, sg)
new("UISizeConstraint", {MaxSize = Vector2.new(820, 170)}, box)
corner(box, 18)
local boxStroke = stroke(box, RGB(255, 70, 140), 3, 0)
local portrait = new("Frame", {Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(90, 90), BackgroundColor3 = RGB(40, 30, 50), BorderSizePixel = 0, ZIndex = 11}, box)
corner(portrait, 45)
local portraitL = label({Size = UDim2.fromScale(1, 1), TextScaled = true, Text = "🎙️", ZIndex = 12}, portrait)
local nameL = label({Position = UDim2.fromOffset(118, 10), Size = UDim2.new(1, -240, 0, 26), TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11}, box)
local textL = label({Position = UDim2.fromOffset(118, 40), Size = UDim2.new(1, -134, 1, -66), TextSize = 20, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 11}, box)
local hintL = label({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -6), Size = UDim2.fromOffset(330, 18), TextSize = 12, TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Right, Text = "Click / tap / Enter / Ⓐ to continue", ZIndex = 11}, box)
local chapterL = label({Position = UDim2.new(1, -230, 0, 10), Size = UDim2.fromOffset(120, 22), TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11}, box)
local skipB = button({Position = UDim2.new(1, -100, 0, 10), Size = UDim2.fromOffset(86, 28), Text = "Skip ⏭", TextSize = 14, BackgroundColor3 = GRAY, ZIndex = 12}, box)
local clickArea = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 10}, box)
-- v11.1 phone layout: a smaller portrait, the name on its own line, the line of dialogue under it at a size that fits
box.Name = "StoryDialogue"
local boxCap = box:FindFirstChildOfClass("UISizeConstraint")
local textCap = new("UITextSizeConstraint", {MaxTextSize = 20, MinTextSize = 12}, textL)
C.Layout.onChange(function(L)
	local c = L.compact
	box.Size = c and UDim2.new(0.94, 0, 0, 196) or UDim2.new(0.9, 0, 0, 150)
	boxCap.MaxSize = c and Vector2.new(820, 210) or Vector2.new(820, 170)
	portrait.Size = c and UDim2.fromOffset(52, 52) or UDim2.fromOffset(90, 90)
	portrait.Position = c and UDim2.fromOffset(10, 10) or UDim2.fromOffset(14, 14)
	nameL.Position = c and UDim2.fromOffset(72, 10) or UDim2.fromOffset(118, 10)
	nameL.Size = c and UDim2.new(1, -176, 0, 24) or UDim2.new(1, -240, 0, 26)
	nameL.TextSize = c and 16 or 20
	chapterL.Visible = not c
	textL.Position = c and UDim2.fromOffset(12, 68) or UDim2.fromOffset(118, 40)
	textL.Size = c and UDim2.new(1, -24, 1, -94) or UDim2.new(1, -134, 1, -66)
	textL.TextScaled = c
	textCap.MaxTextSize = c and 17 or 20
	hintL.Size = c and UDim2.fromOffset(250, 18) or UDim2.fromOffset(330, 18)
end)
-- letterbox bars for a "movie" feel
local barTop = new("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5}, sg)
local barBot = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5}, sg)
local titleCard = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.new(0.8, 0, 0, 44), TextScaled = true, Font = Enum.Font.GothamBlack,
	TextColor3 = GOLD, TextStrokeTransparency = 0.2, Visible = false, ZIndex = 9}, sg)
local flash = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 8}, sg)

local advance, skipping = false, false
clickArea.MouseButton1Click:Connect(function() advance = true end)
skipB.MouseButton1Click:Connect(function() skipping = true play(SND.click) end)
UserInputService.InputBegan:Connect(function(input)
	if not box.Visible then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.Return or k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.KeypadEnter then advance = true end
	if k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.Backspace then skipping = true end
end)

-- =====================================================================
-- PLAYING A CUTSCENE
-- =====================================================================
local queue, playing = {}, false
C.storyCutscene = function() return playing end
local function speaker(who)
	if who == "you" then return {name = plr.DisplayName, icon = "😎", color = RGB(120, 230, 150)} end
	return CAST[who] or {name = who, icon = "💬", color = WHITE}
end
local function sepia(on)
	local cc = Lighting:FindFirstChild("StoryFlashback")
	if on and not cc then
		new("ColorCorrectionEffect", {Name = "StoryFlashback", Saturation = -0.9, Contrast = 0.1, TintColor = RGB(255, 225, 180)}, Lighting)
	elseif not on and cc then
		cc:Destroy()
	end
end
local function play1(sc)
	playing = true
	skipping = false
	local cam = Workspace.CurrentCamera
	local w = sc.where
	newFolder()
	-- the HUD steps aside while the scene plays
	local guiWas = gui.Enabled
	gui.Enabled = false
	local oldType, oldCF = cam.CameraType, cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	local mid = (w.at + w.focus) / 2 + V3(0, 3, 0)
	cam.CFrame = CFrame.lookAt(w.cam + V3(0, 12, 0), mid)
	tween(cam, 1.2, {CFrame = CFrame.lookAt(w.cam, mid)}, Enum.EasingStyle.Sine)
	tween(barTop, 0.5, {Size = UDim2.new(1, 0, 0, 60)})
	tween(barBot, 0.5, {Size = UDim2.new(1, 0, 0, 60)})
	titleCard.Text = (sc.part == "intro" and ("CHAPTER " .. sc.ch .. ": ") or "") .. sc.icon .. " " .. sc.title
	titleCard.Visible = true
	titleCard.TextTransparency = 0
	-- cast on stage: the rival always, plus whoever speaks in this scene
	local actors = {}
	local function actor(who)
		if actors[who] then return actors[who] end
		if who == "narrator" or who == "gazette" or who == "you" then return nil end
		local a = makeActor(who)
		local n = 0
		for _ in pairs(actors) do n += 1 end
		local spot = w.at + V3(n * 4.5, 0, n * 2)
		a.base = faceTowards(spot, w.cam)
		actors[who] = a
		pose(a, a.base, ANIMS.idle(0))
		return a
	end
	local rival = actor("rival")
	local driveLimo
	if sc.stage == "spotlight" then
		for i = -1, 1, 2 do
			local beam = part(V3(4, 60, 4), RGB(255, 245, 200), Enum.Material.Neon, Enum.PartType.Cylinder)
			beam.Transparency = 0.75
			beam.CFrame = CF(w.at + V3(i * 8, 28, 0)) * CFrame.Angles(0, 0, math.pi / 2 + i * 0.25)
		end
		for i = 1, 4 do
			local f = makeActor("fan")
			f.base = faceTowards(w.at + V3(-6 + i * 3, 0, 8), w.at)
			f.fan = i
			actors["fan" .. i] = f
		end
		confetti(w.at, 40)
	elseif sc.stage == "limo" then
		local drive, stop = limo(w)
		driveLimo = drive
		local carpet = part(V3(4, 0.1, 14), RGB(200, 20, 40), Enum.Material.Fabric)
		carpet.CFrame = faceTowards(w.curb, w.at) * CF(0, 0.1, -9)
		for i = 1, 3 do
			local f = makeActor("fan")
			f.base = faceTowards(w.curb + V3(-8 + i * 4, 0, -6), w.curb)
			f.paparazzi = true
			actors["pap" .. i] = f
		end
		rival.base = faceTowards(stop.Position + (w.at - stop.Position).Unit * 6, w.cam)
	end
	if sc.copycat then
		local st = copycatStand(w)
		st.kevin.base = st.base
		actors.kevin = st.kevin
	end
	local t0 = os.clock()
	local current = {anim = "entrance", who = "rival", t = 0}
	local conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for who, a in pairs(actors) do
			local fn
			if who == current.who then fn = ANIMS[current.anim] or ANIMS.talk
			elseif a.fan then fn = function(t) return {bounce = math.abs(math.sin(t * 9 + a.fan)) * 1.2, la = -2.8, ra = -2.8} end
			elseif a.paparazzi then fn = function(t) return {ra = -1.7, la = -1.7, bounce = math.abs(math.sin(t * 3)) * 0.1} end
			else fn = ANIMS.idle end
			pose(a, a.base, fn(now - (who == current.who and current.t or t0)))
		end
		if driveLimo then driveLimo(math.clamp((now - t0) / 2.5, 0, 1)) end
	end)
	-- paparazzi flashes
	local flashing = sc.stage == "limo"
	if flashing then
		task.spawn(function()
			while flashing do
				flash.BackgroundTransparency = 0.6
				tween(flash, 0.25, {BackgroundTransparency = 1})
				task.wait(0.3 + math.random() * 0.6)
			end
		end)
	end
	task.wait(sc.stage == "limo" and 2.6 or 0.8)
	tween(titleCard, 0.6, {TextTransparency = 1})
	box.Visible = true
	chapterL.Text = sc.part == "intro" and ("Chapter " .. sc.ch) or ""
	for i, line in ipairs(sc.lines) do
		if skipping then break end
		local who, text, anim, fb = line[1], line[2], line[3], line[4]
		local sp = speaker(who)
		nameL.Text = sp.name ~= "" and sp.name or "🎬"
		nameL.TextColor3 = sp.color or WHITE
		portraitL.Text = sp.icon or "💬"
		boxStroke.Color = sp.color or WHITE
		sepia(fb == true)
		local a = actor(who)
		current = {who = who, anim = anim or (who == "rival" and "talk" or "talk"), t = os.clock()}
		if a and who == "rival" and i == 1 and sc.part == "intro" then current.anim = anim or "entrance" end
		if anim == "laugh" or anim == "hype" or anim == "shock" then
			for _ = 1, 4 do chatPop((a or rival).head.Position + V3(0, 2, 0)) end
		end
		if anim == "hype" then confetti(w.at, 30) end
		-- typewriter text, then wait for the player (or auto-continue)
		advance = false
		textL.Text = text
		textL.MaxVisibleGraphemes = 0
		local n = utf8.len(text) or #text
		local shown = 0
		while shown < n and not advance and not skipping do
			shown = math.min(n, shown + 2)
			textL.MaxVisibleGraphemes = shown
			task.wait(0.03)
		end
		textL.MaxVisibleGraphemes = -1
		advance = false
		local waitUntil = os.clock() + math.max(3.5, n * 0.06)
		while not advance and not skipping and os.clock() < waitUntil do task.wait(0.05) end
		play(SND.click)
	end
	flashing = false
	sepia(false)
	box.Visible = false
	titleCard.Visible = false
	conn:Disconnect()
	tween(barTop, 0.4, {Size = UDim2.new(1, 0, 0, 0)})
	tween(barBot, 0.4, {Size = UDim2.new(1, 0, 0, 0)})
	cam.CameraType = oldType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or oldType
	if oldType == Enum.CameraType.Scriptable then cam.CFrame = oldCF end
	if FX then FX:Destroy() FX = nil end
	gui.Enabled = guiWas ~= false
	playing = false
end
local pumping = false
local function pump()
	-- one queue runner at a time (two would race for the same scene)
	if pumping then return end
	pumping = true
	task.spawn(function()
		while #queue > 0 do
			-- wait for a calm moment: in the game (not the menu), not in photo mode, not driving
			while true do
				local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
				local seated = hum and hum.SeatPart ~= nil
				local cine = C.cinematicPlaying and C.cinematicPlaying()
				if gui.Enabled and not C.photoActive and not seated and C.S and not cine then break end
				task.wait(0.5)
			end
			local sc = table.remove(queue, 1)
			if sc.kind == "chapterDone" then
				C.splashStory(sc)
			else
				local ok, err = pcall(play1, sc)
				if not ok then
					warn("[CornerEmpire] story cutscene error: " .. tostring(err))
					playing = false
					sepia(false)
					box.Visible = false
					gui.Enabled = true
					local cam = Workspace.CurrentCamera
					cam.CameraType = Enum.CameraType.Custom
				end
			end
		end
		pumping = false
	end)
end

-- chapter-complete card (after the outro)
local doneCard = C.panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(460, 170), BackgroundColor3 = RGB(40, 20, 50), Visible = false, ZIndex = 30}, sg)
gradient(doneCard, RGB(255, 90, 170), RGB(90, 40, 140))
local doneTitle = label({Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 34), TextSize = 26, Font = Enum.Font.GothamBlack, ZIndex = 31}, doneCard)
local doneName = label({Position = UDim2.fromOffset(10, 52), Size = UDim2.new(1, -20, 0, 30), TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 31}, doneCard)
local doneReward = label({Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 0, 60), TextSize = 17, TextWrapped = true, ZIndex = 31}, doneCard)
doneCard.Name = "ChapterDoneCard"
C.Layout.window("chapterDone", doneCard, {fixed = true, major = false})
function C.splashStory(sc)
	doneTitle.Text = "📖 CHAPTER " .. sc.ch .. " COMPLETE"
	doneName.Text = sc.icon .. " " .. sc.title
	doneReward.Text = sc.reward ~= "" and ("Reward: " .. sc.reward) or "Reward already collected on this save."
	doneCard.Visible = true
	local s = new("UIScale", {Scale = 0.5}, doneCard)
	tween(s, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
	play(SND.event)
	task.wait(4)
	doneCard.Visible = false
	s:Destroy()
end

-- =====================================================================
-- SPEECH BUBBLES (roasts while you play: small, bottom-left, a few seconds, never blocking)
-- =====================================================================
local bubble = C.panel({AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 372, 1, -150), Size = UDim2.fromOffset(360, 74), BackgroundColor3 = RGB(30, 16, 34), Visible = false, ZIndex = 25}, gui)
bubble.Name = "RivalBubble"
C.Layout.slot(bubble, "bottom", 6)
stroke(bubble, RGB(255, 70, 140), 2, 0)
local bubIcon = label({Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(56, 56), TextScaled = true, Text = "🎙️", ZIndex = 26}, bubble)
local bubName = label({Position = UDim2.fromOffset(70, 4), Size = UDim2.new(1, -78, 0, 18), TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 110, 170),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 26}, bubble)
local bubText = label({Position = UDim2.fromOffset(70, 22), Size = UDim2.new(1, -78, 1, -26), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 26}, bubble)
local bubbleId = 0
local function showBubble(who, text)
	if playing then return end
	local sp = speaker(who)
	bubbleId += 1
	local id = bubbleId
	bubIcon.Text = sp.icon or "💬"
	bubName.Text = (sp.name or "") .. (who == "rival" and ("  " .. (cat.rival and cat.rival.handle or "")) or "")
	bubName.TextColor3 = sp.color or WHITE
	bubText.Text = text
	bubble.Visible = true
	if not C.Layout.isSlotted(bubble) then
		bubble.Position = UDim2.new(0, 372, 1, -60)
		tween(bubble, 0.35, {Position = UDim2.new(0, 372, 1, -150)}, Enum.EasingStyle.Back)
	end
	task.delay(math.max(5, #text * 0.07), function()
		if bubbleId == id then bubble.Visible = false end
	end)
end
-- small speech bubble over something in the world (your employees muttering at work)
local function worldBubble(pos, who, text) A.bubble(pos, who, text, 6) end

remote.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then return end
	if msg.kind == "cutscene" then
		table.insert(queue, msg)
		pump()
	elseif msg.kind == "chapterDone" then
		table.insert(queue, msg)
		pump()
	elseif msg.kind == "roast" then
		showBubble(msg.who or "rival", msg.text)
		play(SND.msg)
	elseif msg.kind == "bubble" then
		worldBubble(msg.pos, msg.who, msg.text)
	elseif msg.kind == "event" then
		C.storyEventPill(msg.text)
	end
end)

-- "NEW STORY EVENT": a small pill under the top bar; tap it to open the Story app
do
	local pill = button({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 148), Size = UDim2.fromOffset(360, 34), Text = "", TextSize = 13, TextWrapped = true,
		BackgroundColor3 = RGB(200, 50, 130), Visible = false, ZIndex = 30}, gui)
	pill.Name = "StoryPill"
	C.Layout.slot(pill, "top", 2)
	local id = 0
	function C.storyEventPill(text)
		id += 1
		local my = id
		pill.Text = "📖 NEW STORY EVENT: " .. text .. "  ›"
		pill.Visible = true
		task.delay(6, function() if id == my then pill.Visible = false end end)
	end
	pill.MouseButton1Click:Connect(function()
		play(SND.click)
		pill.Visible = false
		if C.togglePhone then C.togglePhone(true) C.phoneView("story") end
	end)
end

-- =====================================================================
-- STORY TRACKER (top-left: chapter + the next objective; tap to open the Story app)
-- =====================================================================
local tracker = C.panel({Position = UDim2.fromOffset(12, 56), Size = UDim2.fromOffset(280, 92), BackgroundColor3 = RGB(34, 18, 40), Visible = false}, gui)
stroke(tracker, RGB(255, 70, 140), 1.5, 0.3)
local trTitle = label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 140, 190),
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, tracker)
local trObj = label({Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 34), TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top}, tracker)
local trFill, trBg = C.bar(tracker, UDim2.fromOffset(10, 62), UDim2.new(1, -20, 0, 8), RGB(255, 90, 160))
local trProg = label({Position = UDim2.fromOffset(10, 72), Size = UDim2.new(1, -20, 0, 16), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd}, tracker)
local trBtn = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ""}, tracker)
-- v11.1 phone layout: the tracker shrinks to a chip in HUD row 2 — "📖 CH 1 · Broke Legend" and a thin progress
-- line; tap it for the whole objective (the Story app)
tracker.Name = "StoryTracker"
local Lay = C.Layout
Lay.slot(tracker, "row2", 1, {
	size = function(L) return UDim2.fromOffset(math.floor((L.vp.X - L.safe.l - L.safe.r) * 0.52), L.ROW2) end,
	onCompact = function(c)
		trObj.Visible, trProg.Visible = not c, not c
		trTitle.Position = c and UDim2.fromOffset(8, 2) or UDim2.fromOffset(10, 4)
		trTitle.Size = c and UDim2.new(1, -16, 0, 20) or UDim2.new(1, -20, 0, 20)
		trTitle.TextSize = c and 12 or 13
		trBg.Position = c and UDim2.new(0, 8, 1, -6) or UDim2.fromOffset(10, 62)
		trBg.Size = c and UDim2.new(1, -16, 0, 3) or UDim2.new(1, -20, 0, 8)
	end,
})
trBtn.MouseButton1Click:Connect(function()
	play(SND.click)
	if C.togglePhone then C.togglePhone(true) C.phoneView("story") end
end)

-- =====================================================================
-- PHONE: the Story app
-- =====================================================================
local kit = C.phoneKit
local view, list
if kit then
	view = kit.makeView("story")
	kit.topBar(view, "🎬  Story", RGB(200, 50, 120))
	list = kit.scroller(view, 46)
end
local function storyButton(parent, text, color, fn)
	local b = button({Size = UDim2.new(1, -16, 0, 34), Text = text, TextSize = 13, TextWrapped = true, BackgroundColor3 = color, ZIndex = 24}, parent)
	b.MouseButton1Click:Connect(function() play(SND.click) fn() end)
	return b
end
local lastSig
local function renderApp(s, force)
	if not (list and s) then return end
	-- only rebuild when something in the story actually changed
	local sig = s.ch .. "|" .. tostring(s.title) .. "|" .. tostring(s.paid) .. "|" .. tostring(s.reward)
	for _, o in ipairs(s.obj or {}) do sig ..= "|" .. tostring(o.done) .. tostring(o.p) .. tostring(o.act) end
	for _, v in ipairs(s.done or {}) do sig ..= v and "1" or "0" end
	for _, v in ipairs(s.claimed or {}) do sig ..= "|" .. tostring(v) end
	if sig == lastSig and not force then return end
	lastSig = sig
	clear(list)
	local order = 0
	local function nextOrder() order += 1 return order end
	local function row(h, color)
		local f = new("Frame", {Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = color or CARD, BorderSizePixel = 0, LayoutOrder = nextOrder(), ZIndex = 22}, list)
		corner(f, 10)
		return f
	end
	local rival = cat.rival or {}
	if s.ch > s.total then
		local f = row(110, RGB(80, 40, 90))
		label({Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 26), Text = "👑 LEGEND MODE", TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 23}, f)
		label({Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 0, 70), TextSize = 13, TextWrapped = true, ZIndex = 23, TextYAlignment = Enum.TextYAlignment.Top,
			Text = "You finished the story. " .. (rival.name or "Your rival") .. " still comments on everything you do. Next goals: rebirths, City Eras and the weekly boards."}, f)
	else
		local f = row(78, RGB(60, 26, 70))
		label({Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 16), Text = "CHAPTER " .. s.ch .. " OF " .. s.total, TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, f)
		label({Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 26), Text = s.icon .. " " .. s.name, TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, ZIndex = 23}, f)
		local info = cat.chapters[s.ch]
		label({Position = UDim2.fromOffset(8, 46), Size = UDim2.new(1, -16, 0, 30), Text = info and info.blurb or "", TextSize = 11, TextWrapped = true, TextColor3 = SUB,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23}, f)
		-- the current objective, big
		local cur
		for _, o in ipairs(s.obj or {}) do if not o.done then cur = o break end end
		if cur then
			local co = row(62, RGB(80, 30, 70))
			label({Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 14), Text = "CURRENT OBJECTIVE", TextSize = 10, TextColor3 = RGB(255, 160, 210), Font = Enum.Font.GothamBlack,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, co)
			label({Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 18), Text = cur.t, TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23}, co)
			local cf = C.bar(co, UDim2.fromOffset(8, 40), UDim2.new(1, -16, 0, 10), RGB(255, 90, 160))
			cf.Size = UDim2.fromScale(math.clamp(cur.f or 0, 0, 1), 1)
			cf.ZIndex = 24
			label({Position = UDim2.fromOffset(8, 50), Size = UDim2.new(1, -16, 0, 12), Text = cur.p or "", TextSize = 10, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23}, co)
		end
		for _, o in ipairs(s.obj or {}) do
			local extra = 0
			if o.act == "clapback" or o.act == "choice" then extra = 40 * #(o.options or {}) elseif o.act then extra = 40 end
			local r = row(58 + extra)
			label({Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 18), Text = (o.done and "✅ " or "⬜ ") .. o.t, TextSize = 13, Font = Enum.Font.GothamBlack,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = o.done and GREEN or WHITE, ZIndex = 23}, r)
			local fill = C.bar(r, UDim2.fromOffset(8, 26), UDim2.new(1, -16, 0, 8), o.done and GREEN or RGB(255, 90, 160))
			fill.Size = UDim2.fromScale(math.clamp(o.f or 0, 0, 1), 1)
			fill.ZIndex = 24
			label({Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 0, 18), Text = o.p or "", TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23}, r)
			if o.act then
				local holder = new("Frame", {Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, extra), BackgroundTransparency = 1, ZIndex = 23}, r)
				vlist(holder, 6)
				if o.act == "clapback" then
					for i, line in ipairs(o.options or {}) do
						storyButton(holder, "🔥 \"" .. line .. "\"", RGB(220, 60, 120), function() act("story", "clapback", i) end)
					end
				elseif o.act == "choice" then
					for _, c in ipairs(o.options or {}) do
						storyButton(holder, c.label .. ": " .. c.text, RGB(60, 130, 230), function() act("story", "choice", c.key) end)
					end
				elseif o.act == "challenge" then
					storyButton(holder, "🥤 Start the showdown (5 minutes)", RGB(255, 170, 40), function() act("story", "challenge") end)
				elseif o.act == "finale" then
					storyButton(holder, "🎙️ Face " .. (rival.name or "the rival"), RGB(255, 200, 60), function() act("story", "finale") end)
				end
			end
		end
		local rr = row(40, RGB(40, 50, 40))
		label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Text = (s.paid and "🎁 Reward collected" or ("🎁 Reward: " .. (s.reward or ""))), TextSize = 12, TextWrapped = true,
			TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, rr)
	end
	if s.title then
		local tr = row(28, RGB(40, 30, 60))
		label({Size = UDim2.fromScale(1, 1), Text = "Your title: \"" .. s.title .. "\"", TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 170, 220), ZIndex = 23}, tr)
	end
	-- characters and how they feel about you right now
	local function section(text)
		label({Size = UDim2.new(1, -8, 0, 22), Text = text, TextSize = 13, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 160, 210), TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(), ZIndex = 23}, list)
	end
	section("👥 CHARACTERS")
	for _, rel in ipairs(cat.relations or {}) do
		if s.ch >= rel.meet then
			local who = CAST[rel.who] or {name = rel.who, icon = "💬"}
			local status
			if rel.by then
				status = s.ch > #cat.chapters and rel.after or rel.by[s.ch]
			else
				status = (s.done and s.done[rel.meet]) and rel.after or rel.now
			end
			local r = row(40, RGB(36, 30, 48))
			label({Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(32, 40), Text = who.icon or "💬", TextSize = 20, ZIndex = 23}, r)
			label({Position = UDim2.fromOffset(40, 3), Size = UDim2.new(1, -46, 0, 16), Text = who.name or "", TextSize = 12, Font = Enum.Font.GothamBlack, TextColor3 = who.color or WHITE,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, r)
			label({Position = UDim2.fromOffset(40, 20), Size = UDim2.new(1, -46, 0, 16), Text = status or "", TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23}, r)
		end
	end
	-- rewards you've already collected
	local anyClaimed = false
	for i, txt in ipairs(s.claimed or {}) do
		if txt ~= "" then
			if not anyClaimed then section("🎁 REWARDS COLLECTED") anyClaimed = true end
			local info = cat.chapters[i] or {}
			local r = row(30, RGB(30, 44, 34))
			label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Text = "Ch " .. i .. " " .. (info.icon or "") .. "  " .. txt, TextSize = 11, TextColor3 = GOLD,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23}, r)
		end
	end
	section("📚 CHAPTERS")
	-- the chapter list: replay intros you've reached and endings you've finished (replays never pay or advance anything)
	for i, info in ipairs(cat.chapters) do
		local reached = i <= s.ch
		local r = row(44, (s.done and s.done[i]) and RGB(30, 60, 40) or (i == s.ch and RGB(60, 26, 70) or RGB(30, 30, 40)))
		local done = s.done and s.done[i]
		local status = done and "✅ Complete" or (i == s.ch and "▶ In progress" or "🔒 Locked")
		label({Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -130, 0, 20), Text = i .. ". " .. (reached and (info.icon .. " " .. info.title) or "???"),
			TextSize = 12, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23}, r)
		label({Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -130, 0, 16), Text = status, TextSize = 10, TextColor3 = done and GREEN or SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, r)
		if reached then
			local b = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, done and -66 or -6, 0.5, 0), Size = UDim2.fromOffset(58, 28), Text = "▶ Intro", TextSize = 10, BackgroundColor3 = GRAY, ZIndex = 24}, r)
			b.MouseButton1Click:Connect(function()
				play(SND.click)
				if C.togglePhone then C.togglePhone(false) end
				act("story", "replay", i)
			end)
		end
		if done then
			local b = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(58, 28), Text = "▶ Ending", TextSize = 10, BackgroundColor3 = GRAY, ZIndex = 24}, r)
			b.MouseButton1Click:Connect(function()
				play(SND.click)
				if C.togglePhone then C.togglePhone(false) end
				act("story", "replay", i, "ending")
			end)
		end
	end
end
if view then kit.onOpen("story", function() renderApp(C.S and C.S.story, true) end) end

-- =====================================================================
-- STATE: tracker, app refresh, Kevin's stand while the showdown runs
-- =====================================================================
local copy
C.onState(function(s)
	local st = s.story
	if not st then
		tracker.Visible = false
		return
	end
	-- the tracker hides during the tutorial's first steps (one card at a time) and in legend mode
	local show = st.ch <= st.total and not (s.tut and s.tut.step <= 3) and not playing
	tracker.Visible = show
	if show then
		local nextObj
		for _, o in ipairs(st.obj or {}) do
			if not o.done then nextObj = o break end
		end
		trTitle.Text = Lay.compact and ("📖 CH " .. st.ch .. " · " .. (st.name or "")) or ("📖 CH " .. st.ch .. ": " .. (st.icon or "") .. " " .. (st.name or ""))
		trObj.Text = nextObj and nextObj.t or "Chapter complete!"
		trFill.Size = UDim2.fromScale(math.clamp(nextObj and nextObj.f or 1, 0, 1), 1)
		trProg.Text = nextObj and nextObj.p or ""
	end
	if view and view.Visible then renderApp(st) end
	-- Kevin's copycat stand stands across the street while the chapter 3 showdown is running
	local running = st.copycat == true
	if running and not copy and not playing then
		local w = st.where
		if w then
			copy = new("Folder", {Name = "KevinStand"}, Workspace)
			local keep = FX
			FX = copy
			local stand = copycatStand(w)
			pose(stand.kevin, stand.base, ANIMS.hype(0))
			FX = keep
		end
	elseif not running and copy then
		copy:Destroy()
		copy = nil
	end
end)
end
