-- DRIVING: smooth client-side car physics (you own your car's physics), speedometer, race HUD.
return function(C)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local V3, RGB = Vector3.new, Color3.fromRGB
local new, tween, panel, label, corner, stroke, gradient = C.new, C.tween, C.panel, C.label, C.corner, C.stroke, C.gradient
local fmt, play, SND, gui, U, plr, R = C.fmt, C.play, C.SND, C.gui, C.U, C.plr, C.R
local GOLD, GREEN, RED, WHITE, SUB = C.GOLD, C.GREEN, C.RED, C.WHITE, C.SUB

-- ===== SPEEDOMETER =====
local GAUGE_MAX = 160
local gauge = new("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -156, 1, -16), Size = UDim2.fromOffset(210, 210), BackgroundColor3 = RGB(14, 15, 22), BorderSizePixel = 0, Visible = false}, gui)
new("UICorner", {CornerRadius = UDim.new(0.5, 0)}, gauge)
stroke(gauge, RGB(90, 95, 120), 4, 0)
gradient(gauge, RGB(40, 44, 64), RGB(10, 10, 16))
local STEPS = 8
for k = 0, STEPS * 2 do
	local frac = k / (STEPS * 2)
	local a = math.rad(-135 + frac * 270)
	local major = k % 2 == 0
	local holder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(190, 190), BackgroundTransparency = 1, Rotation = -135 + frac * 270}, gauge)
	new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(major and 3 or 2, major and 14 or 8),
		BackgroundColor3 = frac > 0.75 and RED or WHITE, BorderSizePixel = 0}, holder)
	if major then
		label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(a) * 68, 0.5, -math.cos(a) * 68), Size = UDim2.fromOffset(34, 16),
			Text = tostring(math.floor(frac * GAUGE_MAX)), TextSize = 12, TextColor3 = frac > 0.75 and RED or SUB, Font = Enum.Font.GothamBlack}, gauge)
	end
end
local needleHolder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 1, Rotation = -135}, gauge)
local needle = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(4, 80), BackgroundColor3 = RGB(255, 70, 60), BorderSizePixel = 0}, needleHolder)
corner(needle, 2)
local hub = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = RGB(200, 200, 210), BorderSizePixel = 0}, gauge)
new("UICorner", {CornerRadius = UDim.new(0.5, 0)}, hub)
local speedL = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 26), Size = UDim2.fromOffset(120, 34), TextSize = 32, Font = Enum.Font.GothamBlack, Text = "0"}, gauge)
local unitL = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 58), Size = UDim2.fromOffset(120, 14), TextSize = 12, TextColor3 = SUB, Text = "MPH"}, gauge)
local nitroBg = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(90, 7), BackgroundColor3 = RGB(40, 40, 50), BorderSizePixel = 0}, gauge)
corner(nitroBg, 3)
local nitroFill = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(80, 200, 255), BorderSizePixel = 0}, nitroBg)
corner(nitroFill, 3)
local nitroL = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -26), Size = UDim2.fromOffset(240, 18), TextSize = 13, TextStrokeTransparency = 0.4, Text = ""}, gauge)
local shown = 0
local function setGauge(v, boosting, hasNitro, nitro, nitroHint)
	shown += (v - shown) * 0.25
	local display = C.settings.units == "KMH" and shown * 1.6 or shown
	needleHolder.Rotation = -135 + math.clamp(display / GAUGE_MAX, 0, 1.03) * 270
	speedL.Text = tostring(math.floor(display + 0.5))
	unitL.Text = C.settings.units == "KMH" and "KM/H" or "MPH"
	nitroBg.Visible = hasNitro
	nitroFill.Size = UDim2.fromScale(nitro, 1)
	nitroFill.BackgroundColor3 = boosting and RGB(255, 140, 40) or RGB(80, 200, 255)
	nitroL.Text = boosting and "🔥 NITRO!" or (hasNitro and (nitroHint or "Hold SHIFT for nitro") or "")
	needle.BackgroundColor3 = boosting and RGB(255, 180, 40) or RGB(255, 70, 60)
end

-- ===== DRIVE BUTTONS (touch + mouse) and input helpers =====
-- Nitro: SHIFT, gamepad B / R1, or the 🔥 button. Drift: Q or CTRL, gamepad X / L1, or the 💨 button.
local held = {nitro = false, drift = false, gas = false, brake = false}
local ctl = new("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -376, 1, -16), Size = UDim2.fromOffset(104, 222), BackgroundTransparency = 1, Visible = false}, gui)
local function holdButton(text, y, color)
	local b = new("TextButton", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, y), Size = UDim2.fromOffset(100, 100), Text = text, TextSize = 20,
		Font = Enum.Font.GothamBlack, TextColor3 = WHITE, BackgroundColor3 = color, BackgroundTransparency = 0.15, AutoButtonColor = false, BorderSizePixel = 0}, ctl)
	new("UICorner", {CornerRadius = UDim.new(0.5, 0)}, b)
	stroke(b, WHITE, 3, 0.35)
	return b
end
local nitroBtn = holdButton("🔥\nNITRO", 0, RGB(235, 110, 30))
local driftBtn = holdButton("💨\nDRIFT", -114, RGB(70, 120, 220))
local function bindHold(btn, key)
	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			held[key] = true
			btn.BackgroundTransparency = 0
		end
	end)
	btn.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			held[key] = false
			btn.BackgroundTransparency = 0.15
		end
	end)
end
bindHold(nitroBtn, "nitro")
bindHold(driftBtn, "drift")
-- v11.1 touch screens: GAS and BRAKE pedals bottom-right (Roblox's thumbstick, bottom-left, steers). They only
-- show on touch screens / the phone layout, so a desktop with a keyboard looks exactly as before.
local Lay = C.Layout
local pedals = new("Frame", {Name = "Pedals", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(146, 76), BackgroundTransparency = 1, Visible = false, ZIndex = Lay.Z.controls}, gui)
local function pedal(text, x, h, color)
	local b = new("TextButton", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, x, 1, 0), Size = UDim2.fromOffset(h, h), Text = text, TextSize = 16,
		Font = Enum.Font.GothamBlack, TextColor3 = WHITE, BackgroundColor3 = color, BackgroundTransparency = 0.15, AutoButtonColor = false, BorderSizePixel = 0}, pedals)
	new("UICorner", {CornerRadius = UDim.new(0.3, 0)}, b)
	stroke(b, WHITE, 2, 0.4)
	return b
end
local gasBtn = pedal("⬆\nGAS", 0, 76, RGB(50, 170, 80))
local brakeBtn = pedal("⬇\nBRAKE", -84, 62, RGB(200, 60, 60))
bindHold(gasBtn, "gas")
bindHold(brakeBtn, "brake")
gauge.Name, ctl.Name = "Speedometer", "DriveButtons"
local ctlScale = Lay.scaleOf(ctl)
local gaugeScale = Lay.scaleOf(gauge)
local design = {gauge = gauge.Position, gaugeAnchor = gauge.AnchorPoint, ctl = ctl.Position, ctlSize = ctl.Size, nitro = nitroBtn.Position, drift = driftBtn.Position}
-- where everything goes. Phone layout: a low cluster just left of Roblox's jump button, nothing in the middle of
-- the road and nothing over the thumbstick (bottom-left):
--   [gauge, small, top-LEFT]          [notifications, top-right]
--                                           [⚙️]
--                          [💨] [🔥]         [📱]
--   [ thumbstick ]     [BRAKE] [ GAS ]  [jump]
-- (v11.3: the speedometer moved to the top-left, where the left buttons hide while you drive, so it never fights the
-- notification stack in the top-right corner)
local function placeDriving()
	if Lay.compact then
		local s, vp = Lay.safe, Lay.vp
		local right = vp.X - s.r - Lay.jumpZone.w      -- just left of Roblox's jump button
		gaugeScale.Scale = 0.43
		gauge.AnchorPoint = Vector2.new(0, 0)
		gauge.Position = UDim2.fromOffset(s.l, Lay.colTop + 22)
		pedals.Position = UDim2.fromOffset(right, vp.Y - s.b - 4)
		-- 🔥 / 💨 side by side, half size, above the pedals
		ctlScale.Scale = 0.5
		ctl.Size = UDim2.fromOffset(212, 100)
		driftBtn.Position = UDim2.new(0, 50, 1, 0)
		nitroBtn.Position = UDim2.new(1, -50, 1, 0)
		ctl.Position = UDim2.fromOffset(right, vp.Y - s.b - 4 - 76 - 8)
	else
		gaugeScale.Scale = 1
		gauge.AnchorPoint, gauge.Position = design.gaugeAnchor, design.gauge
		ctlScale.Scale = 1
		ctl.Position, ctl.Size = design.ctl, design.ctlSize
		nitroBtn.Position, driftBtn.Position = design.nitro, design.drift
		pedals.Position = UDim2.new(1, -16 - (UserInputService.TouchEnabled and 170 or 0), 1, -16)
	end
end
Lay.onChange(placeDriving)
local function showPedals() return Lay.compact or UserInputService.TouchEnabled end
local PAD = Enum.UserInputType.Gamepad1
local function down(key) return UserInputService:IsKeyDown(key) end
local function pad(key)
	local ok, v = pcall(function() return UserInputService:IsGamepadButtonDown(PAD, key) end)
	return ok and v
end
local function wantNitro()
	return held.nitro or down(Enum.KeyCode.LeftShift) or down(Enum.KeyCode.RightShift) or pad(Enum.KeyCode.ButtonB) or pad(Enum.KeyCode.ButtonR1)
end
local function wantDrift()
	return held.drift or down(Enum.KeyCode.Q) or down(Enum.KeyCode.LeftControl) or pad(Enum.KeyCode.ButtonX) or pad(Enum.KeyCode.ButtonL1)
end
local function inputHints()
	local t = UserInputService:GetLastInputType()
	if t == Enum.UserInputType.Touch then return "Hold 🔥 for nitro", "Hold 💨 to drift" end
	if t.Name:find("Gamepad") then return "Hold Ⓑ for nitro", "Hold Ⓧ to drift" end
	return "Hold SHIFT for nitro", "Hold Q / CTRL to drift"
end
local driftL = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -48), Size = UDim2.fromOffset(260, 22), TextSize = 18, Font = Enum.Font.GothamBlack,
	TextColor3 = RGB(255, 200, 80), TextStrokeTransparency = 0.2, Text = ""}, gauge)
local hintL = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(240, 14), TextSize = 11, TextColor3 = SUB, TextStrokeTransparency = 0.5, Text = ""}, gauge)

-- ===== CAR CONTROLLER =====
C.carInput = {}   -- what the driver is doing right now (the car details below read it)
local driving = false
local speed = 0
local nitro = 1
local drift = {on = false, combo = 0, calm = 0, boostT = 0}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function moveToward(v, target, step)
	if v < target then return math.min(v + step, target) end
	return math.max(v - step, target)
end
local function endDrift(showScore)
	if drift.combo > 30 and showScore then
		-- a clean drift earns a small, short speed boost (never more than +10% for ~1s)
		drift.boostT = math.min(1.1, drift.combo / 500)
		driftL.Text = "🔥 DRIFT " .. fmt(drift.combo)
		task.delay(1.4, function() if not drift.on then driftL.Text = "" end end)
	end
	drift.on, drift.combo, drift.calm = false, 0, 0
end
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat:GetAttribute("CarOwner") == plr.UserId) then
		C.carInput.car = nil
		if driving then
			driving = false
			gauge.Visible = false
			ctl.Visible = false
			pedals.Visible = false
			Lay.setDriving(false)
			held.nitro, held.drift, held.gas, held.brake = false, false, false, false
			speed = 0
			endDrift(false)
			driftL.Text = ""
		end
		return
	end
	local car = seat.Parent
	local root = car and car.PrimaryPart
	if not root then return end
	local hasNitro = seat:GetAttribute("Nitro") == true
	if not driving then
		driving = true
		gauge.Visible = true
		ctl.Visible = true
		pedals.Visible = showPedals()
		Lay.setDriving(true)   -- phone layout: the HUD's second row and the left buttons step aside while you drive
		speed = root.CFrame.LookVector:Dot(root.AssemblyLinearVelocity)
	end
	nitroBtn.Visible = hasNitro
	local nitroHint, driftHint = inputHints()
	hintL.Text = driftHint
	if root.Anchored then
		setGauge(0, false, hasNitro, nitro, nitroHint)
		return
	end
	local maxS = seat:GetAttribute("MaxSpeed") or 60
	local turn = seat:GetAttribute("Turn") or 2
	local hover = seat:GetAttribute("Hover") or 1
	local half = seat:GetAttribute("Half") or 1.5
	local grip = seat:GetAttribute("Grip") or 6
	local driftK = seat:GetAttribute("Drift") or 1
	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat
	-- the touch pedals win over the thumbstick's forward/back
	if held.gas then throttle = 1 elseif held.brake then throttle = -1 end
	local photo = C.photoActive == true     -- photo mode: the car coasts to a stop and ignores the keys
	if photo then throttle, steer = 0, 0 end
	local boosting = not photo and hasNitro and throttle > 0 and nitro > 0 and wantNitro()
	local drifting = not photo and wantDrift() and speed > 22
	if boosting then
		nitro = math.max(0, nitro - dt * 0.3)
	else
		nitro = math.min(1, nitro + dt * (drifting and 0.16 or 0.1))
	end
	drift.boostT = math.max(0, drift.boostT - dt)
	-- v10: every car has its own acceleration, braking and nitro power
	local accelK = seat:GetAttribute("Accel") or 1
	local brakeK = seat:GetAttribute("Brake") or 1
	local nitroK = seat:GetAttribute("NitroPower") or 1.4
	local top = maxS * (boosting and nitroK or 1) * (drift.boostT > 0 and 1.1 or 1)
	local target = throttle > 0 and top or (throttle < 0 and -maxS * 0.45 or 0)
	local rate
	if throttle == 0 then
		rate = maxS * 0.55
	elseif (target > 0 and speed < 0) or (target < 0 and speed > 0) then
		rate = maxS * 2.2 * brakeK
	else
		rate = maxS * (boosting and 1.1 or 0.65) * accelK
	end
	local ci = C.carInput
	ci.car, ci.throttle, ci.steer, ci.speed = car, throttle, steer, speed
	ci.braking = (target > 0 and speed < 0) or (target < 0 and speed > 0) or (throttle < 0 and speed > 2)
	speed = moveToward(speed, target, rate * dt)
	local cf = root.CFrame
	local look = V3(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 0.05 then return end
	look = look.Unit
	local right = V3(-look.Z, 0, look.X)
	local vel = root.AssemblyLinearVelocity
	-- crashing into something: lose speed
	local actual = vel:Dot(look)
	if math.abs(speed) > 8 and math.abs(actual) < math.abs(speed) * 0.35 then speed = actual end
	params.FilterDescendantsInstances = {car, char}
	local hit = Workspace:Raycast(root.Position + V3(0, 2, 0), V3(0, -60, 0), params)
	local vy
	if hit then
		local err = (hit.Position.Y + hover + half) - root.Position.Y
		vy = math.clamp(err * 12, -80, 45)
	else
		vy = math.max(vel.Y - 196 * dt, -150)
	end
	-- sideways grip: normally the car stays planted; drifting lets the tail slide out
	local latDamp = grip
	if drifting then
		latDamp = grip * 0.14 / driftK
		speed *= 1 - dt * 0.2                       -- drifting always costs a little speed
	elseif boosting then
		latDamp = grip * 0.5
	end
	local lat = vel:Dot(right) * math.clamp(1 - dt * latDamp, 0, 1)
	local yawK = 1
	if drifting then
		lat += -steer * math.abs(speed) * 0.9 * driftK * dt   -- kick the rear out, away from the turn
		-- cap the slide angle (~35-45 degrees depending on the car) so a drift never turns into a spin
		local maxLat = math.abs(speed) * 0.7 * math.sqrt(driftK)
		lat = math.clamp(lat, -maxLat, maxLat)
		yawK = 1.3 + 0.25 * driftK
	end
	root.AssemblyLinearVelocity = look * speed + right * lat + V3(0, vy, 0)
	local gripF = math.clamp(math.abs(speed) / 16, 0, 1)
	root.AssemblyAngularVelocity = V3(0, -steer * turn * gripF * yawK * (speed >= 0 and 1 or -1), 0)
	-- (the "Upright" constraint only holds the car level now, so steering no longer has to fight it)
	-- drift combo meter (just for fun: the only drift money comes from the race track's Drift Zone, scored by the server)
	local angle = math.deg(math.atan2(math.abs(lat), math.max(1, math.abs(speed))))
	if drifting and angle > 8 then
		drift.on = true
		drift.calm = 0
		drift.combo += dt * math.abs(speed) * angle / 12
		driftL.Text = "💨 DRIFT " .. fmt(drift.combo)
	elseif drift.on then
		drift.calm += dt
		if drift.calm > 0.45 then endDrift(true) end
	end
	setGauge(math.abs(speed), boosting, hasNitro, nitro, nitroHint)
end)

-- ===== SKID MARKS + TIRE SMOKE (every car in the city, drawn locally) =====
do
	local TweenService = game:GetService("TweenService")
	local FX = Instance.new("Folder")
	FX.Name = "CarFX"
	FX.Parent = Workspace
	local POOL = 160
	local skids, nextSkid = {}, 1
	local function skidPart()
		local p = skids[nextSkid]
		if not p then
			p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = RGB(25, 25, 28)
			p.Parent = FX
			skids[nextSkid] = p
		end
		nextSkid = nextSkid % POOL + 1
		return p
	end
	local tracked = {}  -- car model -> {emitters, lastL, lastR}
	local function fxFor(m, root)
		local e = tracked[m]
		if e then return e end
		e = {emitters = {}}
		for _, sx in ipairs({-1, 1}) do
			local att = Instance.new("Attachment")
			att.Position = V3(sx * root.Size.X * 0.42, -root.Size.Y / 2, root.Size.Z * 0.38)
			att.Parent = root
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
			pe.Rate = 28
			pe.Lifetime = NumberRange.new(0.8, 1.4)
			pe.Speed = NumberRange.new(1, 3)
			pe.SpreadAngle = Vector2.new(35, 35)
			pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5)})
			pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})
			pe.Color = ColorSequence.new(RGB(235, 235, 240))
			pe.Enabled = false
			pe.Parent = att
			table.insert(e.emitters, {att = att, pe = pe, side = sx})
		end
		tracked[m] = e
		return e
	end
	local fadeInfo = TweenInfo.new(5, Enum.EasingStyle.Linear)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then return end
		local step = acc
		acc = 0
		local folder = Workspace:FindFirstChild("Cars")
		if not folder then return end
		for m, e in pairs(tracked) do
			if not m.Parent then tracked[m] = nil end
		end
		for _, m in ipairs(folder:GetChildren()) do
			local root = m.PrimaryPart
			local seat = m:FindFirstChild("DriveSeat")
			if root and seat and not root.Anchored then
				local vel = root.AssemblyLinearVelocity
				local lv = root.CFrame.LookVector
				local look = V3(lv.X, 0, lv.Z)
				if look.Magnitude > 0.05 then
					look = look.Unit
					local right = V3(-look.Z, 0, look.X)
					local fwd, side = vel:Dot(look), vel:Dot(right)
					local slipping = vel.Magnitude > 18 and math.abs(side) > 5 and math.abs(side) / math.max(8, math.abs(fwd)) > 0.2
					local e = fxFor(m, root)
					local groundY = root.Position.Y - (seat:GetAttribute("Hover") or 1) - (seat:GetAttribute("Half") or 1.5) + 0.07
					for _, w in ipairs(e.emitters) do
						w.pe.Enabled = slipping
						local wp = root.CFrame:PointToWorldSpace(w.att.Position)
						local pos = V3(wp.X, groundY, wp.Z)
						local last = w.last
						if slipping and last and (pos - last).Magnitude > 0.8 and (pos - last).Magnitude < 12 then
							local p = skidPart()
							local len = (pos - last).Magnitude
							p.Size = V3(0.55, 0.05, len + 0.2)
							p.CFrame = CFrame.lookAt((pos + last) / 2, pos)
							p.Transparency = 0.25
							TweenService:Create(p, fadeInfo, {Transparency = 1}):Play()
						end
						if slipping then w.last = pos else w.last = nil end
					end
				end
			end
		end
	end)
end

-- ===== CAR DETAILS (v10): brake lights, turn signals, the dash speed readout and a steering wheel that turns =====
-- Every client works these out on its own from how each nearby car is moving (so everyone sees them, with no
-- network traffic); your own car uses your actual inputs.
do
	local cars = {}   -- model -> {brake = {parts}, left = {}, right = {}, head = {}, dash, wheel, weld, c0, last, on = {}}
	local BRAKE_ON, BRAKE_OFF = RGB(255, 30, 40), RGB(150, 20, 26)
	local SIG_ON, SIG_OFF = RGB(255, 170, 40), RGB(150, 90, 20)
	local function scan(m)
		local e = {brake = {}, left = {}, right = {}, head = {}}
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name == "BrakeLight" then table.insert(e.brake, p)
				elseif p.Name == "SignalL" then table.insert(e.left, p)
				elseif p.Name == "SignalR" then table.insert(e.right, p)
				elseif p.Name == "Headlight" then table.insert(e.head, p)
				elseif p.Name == "Dash" then e.dash = p:FindFirstChild("DashGui") and p.DashGui:FindFirstChild("Speed")
				elseif p.Name == "SteeringWheel" then
					e.weld = p:FindFirstChild("SteerWeld")
					e.c0 = e.weld and e.weld.C0
				end
			end
		end
		e.on = {}
		return e
	end
	local function setLights(list, on, onC, offC, key, e)
		if e.on[key] == on then return end
		e.on[key] = on
		for _, p in ipairs(list) do
			p.Color = on and onC or offC
			p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	C.carDetails = cars
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 15 then return end
		local step = acc
		acc = 0
		local folder = Workspace:FindFirstChild("Cars")
		if not folder then return end
		for m in pairs(cars) do if not m.Parent then cars[m] = nil end end
		local me = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local cam = Workspace.CurrentCamera
		local camPos = me and me.Position or (cam and cam.CFrame.Position or V3())
		local blink = (os.clock() * 2.5) % 1 < 0.5
		local mine = C.carInput.car
		for _, m in ipairs(folder:GetChildren()) do
			local root = m.PrimaryPart
			if root and (root.Position - camPos).Magnitude < 220 then
				local e = cars[m]
				if not e then
					e = scan(m)
					cars[m] = e
				end
				local vel = root.AssemblyLinearVelocity
				local fwd = vel:Dot(root.CFrame.LookVector)
				local spd = math.abs(fwd)
				local braking, yaw
				if m == mine then
					braking = C.carInput.braking == true
					yaw = -(C.carInput.steer or 0)
				else
					braking = e.last ~= nil and (e.last - spd) / step > 22 and spd > 3
					yaw = root.AssemblyAngularVelocity.Y
				end
				e.last = spd
				if root.Anchored then braking, yaw = false, 0 end
				setLights(e.brake, braking, BRAKE_ON, BRAKE_OFF, "brake", e)
				local turning = math.abs(yaw) > (m == mine and 0.3 or 0.45) and spd > 4
				setLights(e.left, turning and yaw > 0 and blink, SIG_ON, SIG_OFF, "left", e)
				setLights(e.right, turning and yaw < 0 and blink, SIG_ON, SIG_OFF, "right", e)
				if m == mine then
					if e.dash then
						local mph = math.floor(spd + 0.5)
						e.dash.Text = (C.settings.units == "KMH" and (math.floor(mph * 1.6) .. " KM/H") or (mph .. " MPH"))
					end
					if e.weld and e.c0 then e.weld.C0 = e.c0 * CFrame.Angles(-(C.carInput.steer or 0) * 1.4, 0, 0) end
				end
			end
		end
	end)
end

-- ===== RACE HUD =====
do
	local rp = panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 266), Size = UDim2.fromOffset(380, 78), BackgroundColor3 = RGB(30, 30, 36), Visible = false}, gui)
	rp.Name = "RacePanel"
	C.Layout.slot(rp, "top", 7)   -- phone layout: the top notification stack
	stroke(rp, GOLD, 2, 0)
	local title = label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left}, rp)
	local timer = label({Position = UDim2.fromOffset(12, 26), Size = UDim2.new(0.5, 0, 0, 44), TextSize = 36, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = "0.00"}, rp)
	local cpL = label({Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.new(0.5, -12, 0, 44), TextSize = 18, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right}, rp)
	local running, t0 = false, 0
	RunService.RenderStepped:Connect(function()
		if running then timer.Text = string.format("%.2f", os.clock() - t0) end
	end)
	R.Race.OnClientEvent:Connect(function(e)
		if e.state == "armed" then
			rp.Visible = true
			running = false
			title.Text = "🏁 TIME TRIAL  •  entry $" .. fmt(e.fee)
			timer.Text = "READY"
			cpL.Text = "Cross the start line!"
			U.setBeamTarget("race", e.start)
		elseif e.state == "running" then
			if not running then
				running = true
				t0 = os.clock()
				play(SND.event)
			else
				play(SND.buy)
			end
			rp.Visible = true
			title.Text = "🏁 GO GO GO!"
			cpL.Text = "Checkpoint " .. math.min(e.cp, e.total) .. "/" .. e.total .. ((e.drift or 0) > 0 and ("  •  💨 " .. e.drift) or "")
			U.setBeamTarget("race", e.next)
		elseif e.state == "finished" then
			running = false
			timer.Text = string.format("%.2f", e.time)
			cpL.Text = e.record and "🏆 TRACK RECORD!" or (e.pb and "⭐ New personal best!" or "Finished!")
			U.setBeamTarget("race", nil)
			U.splash("🏁 " .. string.format("%.2fs", e.time), "Prize: $" .. fmt(e.prize) .. "   •   Par " .. e.par .. "s" .. ((e.driftBonus or 0) > 0 and ("   •   💨 Drift bonus $" .. fmt(e.driftBonus)) or "") .. (e.pb and "   •   NEW PERSONAL BEST!" or ""), e.record and GOLD or GREEN)
			task.delay(6, function() if not running then rp.Visible = false end end)
		elseif e.state == "cancel" then
			running = false
			rp.Visible = false
			U.setBeamTarget("race", nil)
			if e.why and e.why ~= "" then U.toast("🏁 " .. e.why) end
		end
	end)
end
end
