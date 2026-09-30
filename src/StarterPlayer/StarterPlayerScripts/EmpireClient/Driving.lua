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
local function setGauge(v, boosting, hasNitro, nitro)
	shown += (v - shown) * 0.25
	local display = C.settings.units == "KMH" and shown * 1.6 or shown
	needleHolder.Rotation = -135 + math.clamp(display / GAUGE_MAX, 0, 1.03) * 270
	speedL.Text = tostring(math.floor(display + 0.5))
	unitL.Text = C.settings.units == "KMH" and "KM/H" or "MPH"
	nitroBg.Visible = hasNitro
	nitroFill.Size = UDim2.fromScale(nitro, 1)
	nitroFill.BackgroundColor3 = boosting and RGB(255, 140, 40) or RGB(80, 200, 255)
	nitroL.Text = boosting and "🔥 NITRO!" or (hasNitro and "Hold SHIFT for nitro" or "")
	needle.BackgroundColor3 = boosting and RGB(255, 180, 40) or RGB(255, 70, 60)
end

-- ===== CAR CONTROLLER =====
local driving = false
local speed = 0
local nitro = 1
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function moveToward(v, target, step)
	if v < target then return math.min(v + step, target) end
	return math.max(v - step, target)
end
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.05)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat:GetAttribute("CarOwner") == plr.UserId) then
		if driving then
			driving = false
			gauge.Visible = false
			speed = 0
		end
		return
	end
	local car = seat.Parent
	local root = car and car.PrimaryPart
	if not root then return end
	if not driving then
		driving = true
		gauge.Visible = true
		speed = root.CFrame.LookVector:Dot(root.AssemblyLinearVelocity)
	end
	local hasNitro = seat:GetAttribute("Nitro") == true
	if root.Anchored then
		setGauge(0, false, hasNitro, nitro)
		return
	end
	local maxS = seat:GetAttribute("MaxSpeed") or 60
	local turn = seat:GetAttribute("Turn") or 2
	local hover = seat:GetAttribute("Hover") or 1
	local half = seat:GetAttribute("Half") or 1.5
	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat
	local boosting = hasNitro and throttle > 0 and nitro > 0 and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
	if boosting then
		nitro = math.max(0, nitro - dt * 0.3)
	else
		nitro = math.min(1, nitro + dt * 0.1)
	end
	local top = maxS * (boosting and 1.4 or 1)
	local target = throttle > 0 and top or (throttle < 0 and -maxS * 0.45 or 0)
	local rate
	if throttle == 0 then
		rate = maxS * 0.55
	elseif (target > 0 and speed < 0) or (target < 0 and speed > 0) then
		rate = maxS * 2.2
	else
		rate = maxS * (boosting and 1.1 or 0.65)
	end
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
	local lat = vel:Dot(right) * math.clamp(1 - dt * (boosting and 3 or 6), 0, 1)
	root.AssemblyLinearVelocity = look * speed + right * lat + V3(0, vy, 0)
	local grip = math.clamp(math.abs(speed) / 16, 0, 1)
	root.AssemblyAngularVelocity = V3(0, -steer * turn * grip * (speed >= 0 and 1 or -1), 0)
	local ao = root:FindFirstChild("Upright")
	if ao then
		local _, yaw = cf:ToOrientation()
		ao.CFrame = CFrame.Angles(0, yaw, 0)
	end
	setGauge(math.abs(speed), boosting, hasNitro, nitro)
end)

-- ===== RACE HUD =====
do
	local rp = panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 266), Size = UDim2.fromOffset(380, 78), BackgroundColor3 = RGB(30, 30, 36), Visible = false}, gui)
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
			cpL.Text = "Checkpoint " .. math.min(e.cp, e.total) .. "/" .. e.total
			U.setBeamTarget("race", e.next)
		elseif e.state == "finished" then
			running = false
			timer.Text = string.format("%.2f", e.time)
			cpL.Text = e.record and "🏆 TRACK RECORD!" or (e.pb and "⭐ New personal best!" or "Finished!")
			U.setBeamTarget("race", nil)
			U.splash("🏁 " .. string.format("%.2fs", e.time), "Prize: $" .. fmt(e.prize) .. "   •   Par " .. e.par .. "s" .. (e.pb and "   •   NEW PERSONAL BEST!" or ""), e.record and GOLD or GREEN)
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
