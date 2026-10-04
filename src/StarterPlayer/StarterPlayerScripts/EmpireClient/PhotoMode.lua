-- PHOTO MODE ("Empire Flex"): hide the UI, fly a free camera, cinematic orbits, poses and framing guides.
-- Open with V, the 📸 button, or D-pad Up on a controller. Everything here is local to this player.
return function(C)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local new, tween, label, button, corner, stroke = C.new, C.tween, C.label, C.button, C.corner, C.stroke
local play, SND, act, gui, U, plr = C.play, C.SND, C.act, C.gui, C.U, C.plr
local GOLD, GRAY, RED, BLUE, WHITE, SUB = C.GOLD, C.GRAY, C.RED, C.BLUE, C.WHITE, C.SUB
local camera = Workspace.CurrentCamera

local P = {on = false, mode = "free", yaw = 0, pitch = -0.2, pos = V3(0, 60, 80), fov = 70, speed = 40, orbitA = 0, orbitR = 30, orbitH = 12, target = nil, barHidden = false}
C.photoActive = false

-- ===== screen =====
local pg = plr:WaitForChild("PlayerGui")
local sg = new("ScreenGui", {Name = "PhotoMode", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Enabled = false}, pg)
local grid = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, sg)
for _, f in ipairs({1 / 3, 2 / 3}) do
	new("Frame", {Position = UDim2.new(f, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, BorderSizePixel = 0}, grid)
	new("Frame", {Position = UDim2.new(0, 0, f, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, BorderSizePixel = 0}, grid)
end
local bars = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, sg)
new("Frame", {Size = UDim2.new(1, 0, 0.1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0}, bars)
new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0}, bars)
local bar = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0, 760, 0, 104), BackgroundColor3 = RGB(20, 22, 32), BackgroundTransparency = 0.15, BorderSizePixel = 0}, sg)
corner(bar, 12)
new("UISizeConstraint", {MaxSize = Vector2.new(760, 104)}, bar)
local hint = label({Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0, 18), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "📸 PHOTO MODE • WASD/QE fly • hold right-click or drag to look • SHIFT fast • H hides this bar • V exits • take the shot with Roblox's Capture button"}, bar)
local row1 = new("Frame", {Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 38), BackgroundTransparency = 1}, bar)
local row2 = new("Frame", {Position = UDim2.fromOffset(8, 62), Size = UDim2.new(1, -16, 0, 38), BackgroundTransparency = 1}, bar)
for _, r in ipairs({row1, row2}) do new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, r) end
local function pbtn(parent, text, w, color, fn)
	local b = button({Size = UDim2.fromOffset(w, 36), Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		fn(b)
	end)
	return b
end
-- mobile / mouse movement pad for the free camera
local pad = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -130), Size = UDim2.fromOffset(150, 150), BackgroundTransparency = 1}, sg)
local held = {}
local function padBtn(text, pos, key)
	local b = new("TextButton", {Position = pos, Size = UDim2.fromOffset(46, 46), Text = text, TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = WHITE,
		BackgroundColor3 = RGB(40, 44, 64), BackgroundTransparency = 0.2, AutoButtonColor = false, BorderSizePixel = 0}, pad)
	corner(b, 23)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then held[key] = true end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then held[key] = false end
	end)
end
padBtn("▲", UDim2.fromOffset(52, 0), "fwd")
padBtn("▼", UDim2.fromOffset(52, 104), "back")
padBtn("◀", UDim2.fromOffset(0, 52), "left")
padBtn("▶", UDim2.fromOffset(104, 52), "right")
padBtn("⤒", UDim2.fromOffset(104, 0), "up")
padBtn("⤓", UDim2.fromOffset(104, 104), "down")

-- ===== targets for cinematic shots =====
local function myCar()
	local folder = Workspace:FindFirstChild("Cars")
	if not folder then return nil end
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("Owner") == plr.UserId and m.PrimaryPart then return m.PrimaryPart end
	end
	return nil
end
local function targetPos(kind)
	local s = C.S
	local sc = s and s.showcase
	if kind == "me" then
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		return hrp and hrp.Position, 14, 4
	elseif kind == "car" then
		local r = myCar()
		return r and r.Position, 22, 5
	elseif kind == "business" then
		return sc and sc.best, 34, 14
	elseif kind == "home" then
		return sc and sc.home, 44, 18
	elseif kind == "empire" then
		return sc and sc.plot, 90, 45
	end
	return nil
end

-- ===== enter / exit =====
local saved = {}
local function freezeCharacter(freeze)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if freeze then
		saved.walk, saved.jump = hum.WalkSpeed, hum.JumpHeight
		hum.WalkSpeed, hum.JumpHeight = 0, 0
	elseif saved.walk then
		hum.WalkSpeed, hum.JumpHeight = saved.walk, saved.jump
		saved.walk = nil
	end
end
local function setCore(on)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, on) end)
end
function C.setPhoto(on)
	if on == P.on then return end
	if on and not C.gui.Enabled then return end   -- only while playing (not in the main menu)
	P.on = on
	C.photoActive = on
	if on then
		if C.togglePhone then C.togglePhone(false) end
		C.closeModals()
		P.guiWas = C.gui.Enabled
		C.gui.Enabled = false
		sg.Enabled = true
		bar.Visible, P.barHidden = true, false
		setCore(false)
		freezeCharacter(true)
		local cf = camera.CFrame
		P.pos = cf.Position
		local lx, ly, lz = cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z
		P.yaw = math.atan2(-lx, -lz)
		P.pitch = math.asin(math.clamp(ly, -1, 1))
		P.fov = camera.FieldOfView
		P.mode = "free"
		camera.CameraType = Enum.CameraType.Scriptable
		pad.Visible = UserInputService.TouchEnabled
	else
		sg.Enabled = false
		C.gui.Enabled = P.guiWas ~= false
		setCore(true)
		freezeCharacter(false)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		camera.FieldOfView = 70
		camera.CameraType = Enum.CameraType.Custom
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end
end
local function orbit(kind)
	local pos = targetPos(kind)
	if not pos then
		if U.toast then U.toast("📸 Nothing to frame there yet!") end
		return
	end
	P.mode, P.target = "orbit", kind
	local _, r, h = targetPos(kind)
	P.orbitR, P.orbitH, P.orbitA = r, h, P.orbitA
end

-- ===== the bar =====
pbtn(row1, "🕊️ Free cam", 84, BLUE, function() P.mode = "free" end)
pbtn(row1, "🎬 Me", 60, RGB(120, 90, 220), function() orbit("me") end)
pbtn(row1, "🏎️ My car", 76, RGB(120, 90, 220), function() orbit("car") end)
pbtn(row1, "🏪 Business", 84, RGB(120, 90, 220), function() orbit("business") end)
pbtn(row1, "🏠 Home", 70, RGB(120, 90, 220), function() orbit("home") end)
pbtn(row1, "🏙️ Empire", 76, RGB(120, 90, 220), function() orbit("empire") end)
pbtn(row1, "🏆 Showcase my empire", 150, RGB(200, 150, 30), function() act("showcaseSubmit") end)
pbtn(row1, "✖ Exit (V)", 76, RED, function() C.setPhoto(false) end)
local EMOTES = {{"👋", "wave"}, {"🕺", "dance"}, {"🎉", "cheer"}, {"👉", "point"}, {"😂", "laugh"}}
for _, e in ipairs(EMOTES) do
	pbtn(row2, e[1], 40, RGB(60, 150, 90), function()
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			local ok, played = pcall(function() return hum:PlayEmote(e[2]) end)
			if not (ok and played) and U.toast then U.toast("📸 That pose isn't available on this avatar.") end
		end
	end)
end
pbtn(row2, "# Grid", 60, GRAY, function() grid.Visible = not grid.Visible end)
pbtn(row2, "▭ Bars", 60, GRAY, function() bars.Visible = not bars.Visible end)
pbtn(row2, "🔍 −", 44, GRAY, function() P.fov = math.clamp(P.fov + 10, 20, 100) end)
pbtn(row2, "🔍 +", 44, GRAY, function() P.fov = math.clamp(P.fov - 10, 20, 100) end)
pbtn(row2, "🐢 Slow", 60, GRAY, function(b)
	P.speed = P.speed == 40 and 12 or 40
	b.Text = P.speed == 40 and "🐢 Slow" or "🐇 Fast"
end)
pbtn(row2, "🙈 Hide bar (H)", 110, GRAY, function()
	bar.Visible, P.barHidden = false, true
end)
-- tap the top-left corner to bring the bar back on touch screens
local unhide = new("TextButton", {Size = UDim2.fromOffset(80, 80), BackgroundTransparency = 1, Text = ""}, sg)
unhide.MouseButton1Click:Connect(function()
	if P.barHidden then bar.Visible, P.barHidden = true, false end
end)

-- the 📸 button next to the phone
local camBtn = button({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -98, 1, -70), Size = UDim2.fromOffset(46, 46), Text = "📸", TextSize = 22, BackgroundColor3 = RGB(60, 64, 84)}, gui)
if C.touchLift then camBtn.Position = UDim2.new(1, -98, 1, -70 - C.touchLift) end
camBtn.MouseButton1Click:Connect(function() C.setPhoto(true) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.DPadUp then
		if P.on then C.setPhoto(false) elseif C.gui.Enabled then C.setPhoto(true) end
	elseif input.KeyCode == Enum.KeyCode.H and P.on then
		P.barHidden = not P.barHidden
		bar.Visible = not P.barHidden
	end
end)
-- look around: right mouse drag, one-finger drag, or the right thumbstick
local look = V3()
UserInputService.InputChanged:Connect(function(input, processed)
	if not P.on then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		P.yaw -= input.Delta.X * 0.005
		P.pitch = math.clamp(P.pitch - input.Delta.Y * 0.005, -1.4, 1.4)
	elseif t == Enum.UserInputType.Touch and not processed then
		P.yaw -= input.Delta.X * 0.006
		P.pitch = math.clamp(P.pitch - input.Delta.Y * 0.006, -1.4, 1.4)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		look = V3(input.Position.X, input.Position.Y, 0)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
		held.stick = V3(input.Position.X, 0, input.Position.Y)
	end
end)

local function key(k) return UserInputService:IsKeyDown(k) end
RunService.RenderStepped:Connect(function(dt)
	if not P.on then return end
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	if math.abs(look.X) > 0.15 or math.abs(look.Y) > 0.15 then
		P.yaw -= look.X * dt * 2
		P.pitch = math.clamp(P.pitch + look.Y * dt * 1.5, -1.4, 1.4)
	end
	camera.FieldOfView = camera.FieldOfView + (P.fov - camera.FieldOfView) * math.min(1, dt * 6)
	if P.mode == "orbit" then
		local pos = targetPos(P.target)
		if not pos then
			P.mode = "free"
			return
		end
		P.orbitA += dt * 0.35
		local eye = pos + V3(math.cos(P.orbitA) * P.orbitR, P.orbitH, math.sin(P.orbitA) * P.orbitR)
		camera.CFrame = CFrame.lookAt(eye, pos + V3(0, 2, 0))
		P.pos = eye
		return
	end
	local rot = CFrame.fromOrientation(P.pitch, P.yaw, 0)
	local move = V3()
	if key(Enum.KeyCode.W) or held.fwd then move += V3(0, 0, -1) end
	if key(Enum.KeyCode.S) or held.back then move += V3(0, 0, 1) end
	if key(Enum.KeyCode.A) or held.left then move += V3(-1, 0, 0) end
	if key(Enum.KeyCode.D) or held.right then move += V3(1, 0, 0) end
	if key(Enum.KeyCode.E) or held.up then move += V3(0, 1, 0) end
	if key(Enum.KeyCode.Q) or held.down then move += V3(0, -1, 0) end
	if held.stick and held.stick.Magnitude > 0.15 then move += V3(held.stick.X, 0, -held.stick.Z) end
	local speed = P.speed * ((key(Enum.KeyCode.LeftShift) or key(Enum.KeyCode.RightShift)) and 3 or 1)
	if move.Magnitude > 0 then P.pos += rot:VectorToWorldSpace(move.Unit) * speed * dt end
	P.pos = V3(math.clamp(P.pos.X, -900, 900), math.clamp(P.pos.Y, 2, 500), math.clamp(P.pos.Z, -900, 700))
	camera.CFrame = CF(P.pos) * rot
end)

-- ===== viral replay cam: a short cinematic orbit around the business that just went viral =====
local replay = button({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 270), Size = UDim2.fromOffset(240, 46), Text = "🎬 Replay cam (record it!)", TextSize = 15,
	BackgroundColor3 = RGB(230, 70, 150), Visible = false, ZIndex = 60}, gui)
local replayPos
function C.offerReplay(pos)
	if typeof(pos) ~= "Vector3" then return end
	replayPos = pos
	replay.Visible = true
	task.delay(12, function() if replayPos == pos then replay.Visible = false end end)
end
replay.MouseButton1Click:Connect(function()
	replay.Visible = false
	local pos = replayPos
	if not pos then return end
	replayPos = nil
	local guiWas = C.gui.Enabled
	C.gui.Enabled = false
	setCore(false)
	camera.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 7 or P.on then
			conn:Disconnect()
			if not P.on then
				camera.CameraType = Enum.CameraType.Custom
				C.gui.Enabled = guiWas
				setCore(true)
			end
			return
		end
		local a = t * 0.6
		local r = 26 - t * 1.5
		camera.CFrame = CFrame.lookAt(pos + V3(math.cos(a) * r, 5 + t * 1.2, math.sin(a) * r), pos + V3(0, 4, 0))
	end)
end)
end
