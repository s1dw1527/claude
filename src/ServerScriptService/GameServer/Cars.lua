-- CARS: realistic part-built cars, the Corner Motors showroom, game passes.
return function(C)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, wedge, ball, cyl, xcyl, ghost, billboard, surfaceText, sparkle, burst =
	C.P, C.wedge, C.ball, C.cyl, C.xcyl, C.ghost, C.billboard, C.surfaceText, C.sparkle, C.burst
local CARS, CAR, PASSES, REP_TIERS, fmt, notify = C.CARS, C.CAR, C.PASSES, C.REP_TIERS, C.fmt, C.notify
local WHITE, DARK, CHROME = RGB(250, 250, 250), RGB(22, 22, 26), RGB(210, 212, 218)
local GLASS = RGB(30, 40, 55)

-- ===================================================================
-- CAR BUILDER (front of the car = -Z, ground = y 0 of cf)
-- ===================================================================
local function wheel(m, cf, D, rimColor, gold)
	xcyl(m, 0.95, D, cf, RGB(28, 28, 30), MAT.SmoothPlastic)
	xcyl(m, 1.0, D * 0.64, cf, rimColor, gold and MAT.Foil or MAT.Metal, {Reflectance = 0.25})
	for k = 0, 4 do
		P(m, V3(1.04, D * 0.56, 0.18), cf * CFrame.Angles(math.rad(k * 36), 0, 0), rimColor:Lerp(DARK, 0.15), MAT.Metal)
	end
	xcyl(m, 1.08, D * 0.2, cf, DARK, MAT.Metal)
end

function C.buildCar(spec, cf, plateText)
	local m = Instance.new("Model")
	m.Name = spec.name
	local L, W, H, Cl, D = spec.L, spec.W, spec.H, spec.clear, spec.wheel
	local col = spec.color
	local paintMat = spec.gold and MAT.Foil or MAT.SmoothPlastic
	local paint = {Reflectance = spec.gold and 0 or 0.12}
	local rimCol = spec.gold and RGB(255, 205, 60) or (spec.key == "legend" and RGB(255, 200, 60) or CHROME)
	local root
	if spec.style == "moped" then
		root = P(m, V3(2.4, 2.6, 6), cf * CF(0, 1.1 + 1.3, 0), WHITE, MAT.SmoothPlastic, {Transparency = 1, CanCollide = true, Name = "Chassis"})
		P(m, V3(1.4, 1.2, 4), cf * CF(0, 2.2, 0.3), col, paintMat, paint)
		wedge(m, V3(1.8, 2.4, 1.2), cf * CF(0, 3, -1.9), col, paintMat, paint)
		P(m, V3(1.2, 0.5, 2.2), cf * CF(0, 3.05, 0.9), DARK, MAT.Fabric)
		P(m, V3(2.4, 0.25, 0.25), cf * CF(0, 4.4, -2.3), DARK, MAT.Metal)
		P(m, V3(0.25, 1.6, 0.25), cf * CF(0, 3.6, -2.3), CHROME, MAT.Metal)
		P(m, V3(0.8, 0.5, 0.2), cf * CF(0, 3.6, -2.55), RGB(255, 250, 230), MAT.Neon)
		P(m, V3(0.6, 0.3, 0.2), cf * CF(0, 2.5, 2.35), RGB(255, 40, 40), MAT.Neon)
		for _, z in ipairs({-2.2, 2.1}) do
			xcyl(m, 0.5, D, cf * CF(0, D / 2, z), RGB(28, 28, 30))
			xcyl(m, 0.55, D * 0.6, cf * CF(0, D / 2, z), CHROME, MAT.Metal)
		end
	else
		local yb = Cl + H
		root = P(m, V3(W * 0.94, H + 0.8, L * 0.94), cf * CF(0, Cl + (H + 0.8) / 2, 0), WHITE, MAT.SmoothPlastic, {Transparency = 1, CanCollide = true, Name = "Chassis"})
		local Lm = L - H
		-- lower body with rounded bumpers
		P(m, V3(W, H, Lm), cf * CF(0, Cl + H / 2, 0), col, paintMat, paint)
		xcyl(m, W - 0.02, H, cf * CF(0, Cl + H / 2, -Lm / 2), col, paintMat, paint)
		xcyl(m, W - 0.02, H, cf * CF(0, Cl + H / 2, Lm / 2), col, paintMat, paint)
		P(m, V3(W * 0.9, 0.35, 1.2), cf * CF(0, Cl + 0.2, -L / 2 + 0.7), DARK, MAT.SmoothPlastic)
		P(m, V3(W * 0.9, 0.35, 1.2), cf * CF(0, Cl + 0.2, L / 2 - 0.7), DARK, MAT.SmoothPlastic)
		-- cabin
		local Rh, CL, cz = spec.roof, spec.cab, spec.cabZ
		local WS = ({hatch = 2.6, sedan = 2.8, van = 1.6, suv = 2.4, pickup = 2.2, coupe = 3.4, hyper = 3.6})[spec.style] or 2.6
		local RW = ({hatch = 1.2, sedan = 2.4, van = 0.4, suv = 0.8, pickup = 0.6, coupe = 3.6, hyper = 2.8})[spec.style] or 2
		local cw = W - 0.7
		P(m, V3(cw, Rh, CL), cf * CF(0, yb + Rh / 2, cz), GLASS, MAT.Glass, {Transparency = 0.25, Reflectance = 0.2})
		P(m, V3(cw + 0.2, 0.3, CL + 0.2), cf * CF(0, yb + Rh + 0.15, cz), col, paintMat, paint)
		wedge(m, V3(cw, Rh, WS), cf * CF(0, yb + Rh / 2, cz - CL / 2 - WS / 2), GLASS, MAT.Glass, {Transparency = 0.25, Reflectance = 0.2})
		wedge(m, V3(cw, Rh, RW), cf * CF(0, yb + Rh / 2, cz + CL / 2 + RW / 2) * CFrame.Angles(0, math.pi, 0), GLASS, MAT.Glass, {Transparency = 0.25, Reflectance = 0.2})
		local ang = math.atan2(Rh, WS)
		local hyp = math.sqrt(Rh * Rh + WS * WS)
		for _, sx in ipairs({-1, 1}) do
			P(m, V3(0.28, 0.3, hyp), cf * CF(sx * cw / 2, yb + Rh / 2, cz - CL / 2 - WS / 2) * CFrame.Angles(-ang, 0, 0), col, paintMat, paint)
			P(m, V3(0.28, Rh, 0.35), cf * CF(sx * cw / 2, yb + Rh / 2, cz), col, paintMat, paint)
			P(m, V3(0.28, Rh, 0.3), cf * CF(sx * cw / 2, yb + Rh / 2, cz + CL / 2 - 0.15), col, paintMat, paint)
			P(m, V3(0.3, 0.25, CL), cf * CF(sx * cw / 2, yb + Rh - 0.1, cz), col, paintMat, paint)
		end
		-- hood + trunk slopes
		local hoodStart = cz - CL / 2 - WS
		local hoodLen = hoodStart - (-L / 2 + H * 0.35)
		if hoodLen > 0.8 then
			wedge(m, V3(W - 0.15, 0.45, hoodLen), cf * CF(0, yb + 0.22, hoodStart - hoodLen / 2), col, paintMat, paint)
			P(m, V3(0.12, 0.05, hoodLen * 0.8), cf * CF(-W * 0.2, yb + 0.47, hoodStart - hoodLen / 2), col:Lerp(DARK, 0.2))
			P(m, V3(0.12, 0.05, hoodLen * 0.8), cf * CF(W * 0.2, yb + 0.47, hoodStart - hoodLen / 2), col:Lerp(DARK, 0.2))
		end
		local trunkStart = cz + CL / 2 + RW
		local trunkLen = (L / 2 - H * 0.35) - trunkStart
		if trunkLen > 0.8 and spec.style ~= "pickup" then
			wedge(m, V3(W - 0.15, 0.35, trunkLen), cf * CF(0, yb + 0.17, trunkStart + trunkLen / 2) * CFrame.Angles(0, math.pi, 0), col, paintMat, paint)
		end
		-- interior (visible through the glass)
		local seatDrop = (spec.style == "coupe" or spec.style == "hyper") and 1.25 or 0.9
		for _, sx in ipairs({-W * 0.2, W * 0.2}) do
			P(m, V3(1.7, 2.2, 0.4), cf * CF(sx, yb - seatDrop + 1.6, cz + 1.2) * CFrame.Angles(math.rad(-12), 0, 0), RGB(40, 40, 44), MAT.Fabric)
		end
		P(m, V3(cw - 0.2, 0.6, 1.2), cf * CF(0, yb + 0.3, cz - CL / 2 + 0.2), RGB(30, 30, 34), MAT.SmoothPlastic)
		xcyl(m, 0.15, 1.2, cf * CF(-W * 0.2, yb + 0.9, cz - CL / 2 + 1.1) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(25)), RGB(30, 30, 34))
		-- fenders, wheel wells, wheels
		local fz, rz = -L / 2 + D * 0.72 + 0.7, L / 2 - D * 0.72 - 0.7
		if spec.style == "pickup" then fz, rz = -L / 2 + D * 0.62, L / 2 - D * 0.62 end
		for _, z in ipairs({fz, rz}) do
			for _, sx in ipairs({-1, 1}) do
				local x = sx * (W / 2 - 0.45)
				xcyl(m, 1.05, D + 1.0, cf * CF(x + sx * 0.05, D / 2 + 0.1, z), col, paintMat, paint)
				xcyl(m, 1.1, D + 0.4, cf * CF(x + sx * 0.05, D / 2 + 0.05, z), DARK)
				wheel(m, cf * CF(x + sx * 0.08, D / 2, z), D, rimCol, spec.gold)
			end
		end
		-- lights, grille, plates
		for _, sx in ipairs({-1, 1}) do
			P(m, V3(W * 0.22, H * 0.2, 0.25), cf * CF(sx * W * 0.3, Cl + H * 0.72, -L / 2 + H * 0.06), RGB(255, 250, 235), MAT.Neon)
			P(m, V3(W * 0.24, H * 0.18, 0.25), cf * CF(sx * W * 0.31, Cl + H * 0.72, L / 2 - H * 0.06), RGB(255, 30, 40), MAT.Neon)
			P(m, V3(0.25, 0.35, 0.65), cf * CF(sx * (W / 2 + 0.15), yb + 0.45, cz - CL / 2 - WS * 0.3), col, paintMat, paint)
			P(m, V3(0.06, H * 0.85, 0.08), cf * CF(sx * (W / 2 + 0.01), Cl + H * 0.5, cz + 0.25), col:Lerp(DARK, 0.5))
			P(m, V3(0.08, 0.14, 0.6), cf * CF(sx * (W / 2 + 0.05), Cl + H * 0.78, cz - 0.4), CHROME, MAT.Metal)
			if spec.style == "sedan" or spec.style == "suv" then
				P(m, V3(0.06, H * 0.85, 0.08), cf * CF(sx * (W / 2 + 0.01), Cl + H * 0.5, cz - CL / 2 + 0.2), col:Lerp(DARK, 0.5))
				P(m, V3(0.08, 0.14, 0.6), cf * CF(sx * (W / 2 + 0.05), Cl + H * 0.78, cz + CL / 2 - 0.9), CHROME, MAT.Metal)
			end
			P(m, V3(0.12, 0.35, Lm - D * 2.2), cf * CF(sx * (W / 2 + 0.02), Cl + 0.2, (fz + rz) / 2), DARK, MAT.SmoothPlastic)
		end
		P(m, V3(W * 0.36, H * 0.32, 0.2), cf * CF(0, Cl + H * 0.42, -L / 2 + 0.03), DARK, MAT.Metal)
		for k = -1, 1 do P(m, V3(W * 0.34, 0.06, 0.25), cf * CF(0, Cl + H * (0.42 + k * 0.09), -L / 2 + 0.02), CHROME, MAT.Metal) end
		P(m, V3(1.9, 0.55, 0.1), cf * CF(0, Cl + H * 0.2, -L / 2 + H * 0.08), WHITE)
		local plate = P(m, V3(1.9, 0.55, 0.1), cf * CF(0, Cl + H * 0.35, L / 2 - H * 0.02), WHITE)
		local tl = surfaceText(plate, Enum.NormalId.Back, string.upper(string.sub(plateText or "EMPIRE", 1, 7)), RGB(20, 40, 120))
		tl.Parent.CanvasSize = Vector2.new(190, 55)
		for _, sx in ipairs({-W * 0.28, W * 0.28}) do
			xcyl(m, 0.7, 0.42, cf * CF(sx, Cl + 0.3, L / 2 - 0.1) * CFrame.Angles(0, math.rad(90), 0), CHROME, MAT.Metal)
		end
		-- ===== style extras =====
		if spec.style == "coupe" then
			P(m, V3(W - 0.6, 0.2, 1.2), cf * CF(0, yb + 0.55, L / 2 - 1.5), col, paintMat, paint)
		elseif spec.style == "hyper" then
			for _, sx in ipairs({-W * 0.32, W * 0.32}) do P(m, V3(0.3, 1.4, 0.5), cf * CF(sx, yb + 0.7, L / 2 - 1.4), DARK) end
			P(m, V3(W + 0.4, 0.25, 1.8), cf * CF(0, yb + 1.45, L / 2 - 1.5), spec.gold and col or DARK, spec.gold and MAT.Foil or MAT.SmoothPlastic)
			for _, sx in ipairs({-1, 1}) do
				wedge(m, V3(0.3, H * 0.7, 2.4), cf * CF(sx * (W / 2 + 0.05), Cl + H * 0.55, cz + CL / 2 + 0.8), DARK)
			end
			for k = 0, 4 do P(m, V3(W * 0.5, 0.06, 0.2), cf * CF(0, yb + 0.42, cz + CL / 2 + RW + 0.4 + k * 0.45), DARK) end
			P(m, V3(W * 0.8, 0.12, 0.2), cf * CF(0, Cl + H * 0.72, L / 2 - H * 0.05), RGB(255, 30, 40), MAT.Neon)
		elseif spec.style == "suv" then
			for _, sx in ipairs({-cw * 0.42, cw * 0.42}) do P(m, V3(0.2, 0.25, CL * 0.9), cf * CF(sx, yb + Rh + 0.45, cz), DARK, MAT.Metal) end
			xcyl(m, 0.8, D * 0.95, cf * CF(0, Cl + H * 0.6, L / 2 + 0.3) * CFrame.Angles(0, math.rad(90), 0), RGB(28, 28, 30))
			xcyl(m, 0.85, D * 0.55, cf * CF(0, Cl + H * 0.6, L / 2 + 0.3) * CFrame.Angles(0, math.rad(90), 0), CHROME, MAT.Metal)
		elseif spec.style == "van" then
			for _, sx in ipairs({-1, 1}) do
				local panel = P(m, V3(0.1, Rh * 0.55, CL * 0.62), cf * CF(sx * (cw / 2 + 0.06), yb + Rh * 0.5, cz + CL * 0.12), col, paintMat, paint)
				surfaceText(panel, sx == 1 and Enum.NormalId.Right or Enum.NormalId.Left, "🍋 EMPIRE DELIVERY", RGB(220, 60, 60))
			end
			P(m, V3(cw + 0.2, Rh * 0.94, 0.1), cf * CF(0, yb + Rh * 0.47, cz + CL / 2 + 0.3), col, paintMat, paint)
		elseif spec.style == "pickup" then
			local bedZ0 = cz + CL / 2 + RW
			local bedLen = L / 2 - bedZ0 - 0.4
			for _, sx in ipairs({-1, 1}) do P(m, V3(0.3, 1.3, bedLen), cf * CF(sx * (W / 2 - 0.15), yb + 0.65, bedZ0 + bedLen / 2), col, paintMat, paint) end
			P(m, V3(W, 1.3, 0.3), cf * CF(0, yb + 0.65, bedZ0 + bedLen), col, paintMat, paint)
			P(m, V3(W - 0.6, 0.1, bedLen), cf * CF(0, yb + 0.05, bedZ0 + bedLen / 2), DARK, MAT.DiamondPlate)
			for _, sx in ipairs({-1, 1}) do
				P(m, V3(0.35, 2.4, 0.35), cf * CF(sx * (W / 2 - 0.3), yb + 1.2, bedZ0 + 0.5), DARK, MAT.Metal)
			end
			P(m, V3(W - 0.4, 0.35, 0.35), cf * CF(0, yb + 2.4, bedZ0 + 0.5), DARK, MAT.Metal)
			for k = -1, 1 do P(m, V3(0.8, 0.6, 0.4), cf * CF(k * 1.2, yb + Rh + 0.6, cz - 0.5), RGB(255, 250, 220), MAT.Neon) end
			P(m, V3(W * 0.7, 0.8, L * 0.6), cf * CF(0, Cl - 0.6, 0), DARK, MAT.Metal)
		end
		if spec.glow then
			for _, sx in ipairs({-1, 1}) do P(m, V3(0.15, 0.15, L * 0.7), cf * CF(sx * (W / 2 - 0.3), Cl - 0.1, 0), spec.glow, MAT.Neon) end
			local pl = Instance.new("PointLight")
			pl.Color = spec.glow
			pl.Range = 10
			pl.Brightness = 2
			pl.Parent = root
		end
		if spec.gold or spec.key == "legend" then sparkle(root, RGB(255, 220, 110), 5) end
	end
	-- weld everything to the invisible chassis
	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 1, 1)
	m.PrimaryPart = root
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			p.Anchored = false
		end
	end
	root.Anchored = true
	return m, root
end

-- ===================================================================
-- DRIVABLE CARS
-- ===================================================================
local CARS_FOLDER = Instance.new("Folder")
CARS_FOLDER.Name = "Cars"
CARS_FOLDER.Parent = Workspace
local activeCars = {}
C.activeCars = activeCars

function F.hasPass(plr, key)
	local d = data[plr]
	return d and d.passes[key] == true
end
function F.ownsCar(plr, spec)
	local d = data[plr]
	if not d then return false end
	if spec.pass then return F.hasPass(plr, spec.pass) end
	if spec.rebirths then return d.rebirths >= spec.rebirths end
	return d.cars[spec.key] == true
end
function F.activeCar(plr)
	local c = activeCars[plr]
	if c and c.model.Parent then return c end
	return nil
end
function F.despawnCar(plr)
	local c = activeCars[plr]
	if c then
		c.model:Destroy()
		activeCars[plr] = nil
	end
end
function F.spawnCar(plr, key, at)
	local d = data[plr]
	local spec = CAR[key]
	if not (d and spec) then return end
	F.despawnCar(plr)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local cf = at
	if not cf then
		if not hrp then return end
		local look = hrp.CFrame.LookVector
		local flat = V3(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then flat = V3(0, 0, -1) end
		flat = flat.Unit
		local pos = hrp.Position + flat * 9
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {char, CARS_FOLDER}
		params.FilterType = Enum.RaycastFilterType.Exclude
		local hit = Workspace:Raycast(pos + V3(0, 30, 0), V3(0, -80, 0), params)
		local y = hit and hit.Position.Y or 0
		cf = CF(V3(pos.X, y + 0.2, pos.Z), V3(pos.X, y + 0.2, pos.Z) + flat)
	end
	local m, root = C.buildCar(spec, cf, plr.Name)
	-- driver seat (hidden inside the body) + upright stabilizer
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.Size = V3(2, 1, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	if spec.style == "moped" then
		seat.CFrame = cf * CF(0, 3.2, 0.9)
	else
		local drop = (spec.style == "coupe" or spec.style == "hyper") and 1.25 or 0.9
		seat.CFrame = cf * CF(-spec.W * 0.2, spec.clear + spec.H - drop, spec.cabZ + 0.9)
	end
	seat.Parent = m
	local wc = Instance.new("WeldConstraint")
	wc.Part0 = root
	wc.Part1 = seat
	wc.Parent = seat
	seat:SetAttribute("CarOwner", plr.UserId)
	seat:SetAttribute("MaxSpeed", spec.speed * (1 + math.min(0.3, d.rebirths * 0.005)))
	seat:SetAttribute("Turn", spec.turn)
	seat:SetAttribute("Grip", spec.grip or 6)
	seat:SetAttribute("Drift", spec.drift or 1)
	seat:SetAttribute("Hover", spec.style == "moped" and 1.1 or spec.clear)
	seat:SetAttribute("Half", root.Size.Y / 2)
	seat:SetAttribute("Nitro", F.hasPass(plr, "nitro"))
	seat:SetAttribute("Delivery", spec.delivery == true)
	-- keep the car upright WITHOUT locking its heading. (Before v8 this constraint held all three axes, so
	-- every physics step it pulled the car back to the heading it had at the start of the frame and ate
	-- most of the steering: cars barely turned and slid sideways instead. Now it only keeps the car's
	-- up axis pointing up, and turning is left entirely to the driving controller.)
	local att = Instance.new("Attachment")
	att.Name = "UprightAxis"
	att.CFrame = CFrame.Angles(0, 0, math.pi / 2)   -- this attachment's primary (X) axis points up
	att.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Upright"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.AlignType = Enum.AlignType.PrimaryAxisParallel
	ao.PrimaryAxis = Vector3.new(0, 1, 0)
	ao.Attachment0 = att
	ao.MaxTorque = 4e6
	ao.Responsiveness = 35
	ao.Parent = root
	m:SetAttribute("Owner", plr.UserId)
	m.Parent = CARS_FOLDER
	local entry = {model = m, root = root, seat = seat, key = key}
	activeCars[plr] = entry
	C.prompt(root, "Drive", spec.name, 14, 0, function(who)
		if who ~= plr then return end
		local h = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if h and not seat.Occupant then seat:Sit(h) end
	end)
	-- network ownership: the driver's computer runs the physics (smooth, no lag)
	local parkToken = 0
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occ = seat.Occupant
		if occ then
			local who = Players:GetPlayerFromCharacter(occ.Parent)
			if who ~= plr then
				occ.Sit = false
				return
			end
			root.Anchored = false
			pcall(function() root:SetNetworkOwner(plr) end)
		else
			parkToken += 1
			local my = parkToken
			task.delay(1.5, function()
				if my == parkToken and root.Parent and not seat.Occupant then
					local _, yaw = root.CFrame:ToOrientation()
					root.AssemblyLinearVelocity = Vector3.zero
					root.Anchored = true
					root.CFrame = CF(root.Position) * CFrame.Angles(0, yaw, 0)
				end
			end)
		end
	end)
	if hum and not at then
		task.delay(0.2, function()
			if seat.Parent and hum.Parent and not seat.Occupant then seat:Sit(hum) end
		end)
	end
	return entry
end
-- parked cars whose owner wandered far away for 3 minutes go back to the garage (no abandoned cars piling up)
task.spawn(function()
	while true do
		task.wait(10)
		for plr, c in pairs(activeCars) do
			if not c.model.Parent or not plr.Parent then
				activeCars[plr] = nil
				if c.model.Parent then c.model:Destroy() end
			elseif c.seat.Occupant then
				c.idle = 0
			else
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				local far = not hrp or (hrp.Position - c.root.Position).Magnitude > 350
				c.idle = far and (c.idle or 0) + 10 or 0
				if c.idle >= 180 then
					F.despawnCar(plr)
					notify(plr, "🅿️ Your parked car was sent back to the garage. Spawn it again from the Garage app.")
				end
			end
		end
	end
end)
function F.buyOrDrive(plr, key)
	local d = data[plr]
	local spec = CAR[key]
	if not (d and spec) then return end
	if not F.unlocked(d, "cars") then
		notify(plr, "🔒 Cars unlock at " .. REP_TIERS[C.FEATURES.cars].name .. " reputation.")
		return
	end
	if F.ownsCar(plr, spec) then
		F.spawnCar(plr, key)
		return
	end
	if spec.pass then
		F.promptPass(plr, spec.pass)
		return
	end
	if spec.rebirths then
		notify(plr, "👑 The " .. spec.name .. " unlocks at " .. spec.rebirths .. " rebirths.")
		return
	end
	if d.cash < spec.price then
		notify(plr, "You need $" .. fmt(spec.price) .. " for the " .. spec.name .. ".")
		return
	end
	d.cash -= spec.price
	d.cars[key] = true
	if spec.price >= 1000000 and F.storyEvent then F.storyEvent(plr, "luxury", key) end
	if spec.price >= 1000000 and F.viralMoment then
		F.viralMoment(plr, "luxuryCar", {car = spec.name})
		if F.paparazzi and math.random() < 0.4 then task.delay(4, function() if plr.Parent then F.paparazzi(plr) end end) end
	end
	R.Splash:FireClient(plr, "🚗 NEW CAR!", "You bought the " .. spec.name .. "! Hold SHIFT for nitro (with the pass).", spec.color)
	F.buzz("🚗", plr.Name .. " just bought a " .. spec.name .. "!", spec.color)
	F.spawnCar(plr, key)
end

-- ===================================================================
-- CORNER MOTORS SHOWROOM (north of the core)
-- ===================================================================
do
	local f = Instance.new("Folder")
	f.Name = "CornerMotors"
	f.Parent = C.WORLD
	C.reserve(-58, -202, 58, -132)
	local SOLIDP = {CanCollide = true}
	P(f, V3(116, 2.2, 18), CF(0, -0.9, -142), RGB(58, 60, 66), MAT.Asphalt, SOLIDP)
	for x = -50, 50, 10 do P(f, V3(0.3, 0.05, 8), CF(x, 0.22, -145), WHITE) end
	P(f, V3(112, 0.6, 50), CF(0, 0.3, -175), RGB(235, 235, 238), MAT.Marble, SOLIDP)
	P(f, V3(112, 16, 1), CF(0, 8, -200), RGB(40, 44, 56), MAT.SmoothPlastic, SOLIDP)
	for _, sx in ipairs({-1, 1}) do P(f, V3(1, 16, 50), CF(sx * 56, 8, -175), RGB(40, 44, 56), MAT.SmoothPlastic, SOLIDP) end
	for _, seg in ipairs({{-31, 50}, {31, 50}}) do
		P(f, V3(seg[2], 13.4, 0.4), CF(seg[1], 7.3, -150), RGB(160, 210, 245), MAT.Glass, {CanCollide = true, Transparency = 0.6, Reflectance = 0.2})
	end
	for x = -56, 56, 7 do P(f, V3(0.5, 16, 0.6), CF(x, 8, -150), RGB(40, 44, 56), MAT.Metal) end
	P(f, V3(114, 1.4, 52), CF(0, 16.7, -175), RGB(40, 44, 56), MAT.SmoothPlastic, SOLIDP)
	P(f, V3(114, 0.5, 0.6), CF(0, 15.8, -149.6), RGB(255, 60, 60), MAT.Neon)
	local sign = P(f, V3(46, 6, 1), CF(0, 21, -151), RGB(20, 20, 26), MAT.SmoothPlastic)
	surfaceText(sign, Enum.NormalId.Back, "🚗 CORNER MOTORS", RGB(255, 80, 80))
	local back = P(f, V3(40, 5, 0.3), CF(0, 11, -199.3), RGB(20, 20, 26))
	surfaceText(back, Enum.NormalId.Back, "DRIVE YOUR EMPIRE", WHITE)
	for x = -45, 45, 15 do
		local l = P(f, V3(8, 0.3, 1.2), CF(x, 15.8, -175), RGB(255, 250, 240), MAT.Neon)
		local pl = Instance.new("PointLight")
		pl.Range = 22
		pl.Brightness = 1.4
		pl.Parent = l
	end
	for i, spec in ipairs(CARS) do
		local row = i <= 5 and 0 or 1
		local col = (i - 1) % 5
		local x, z = -44 + col * 22, row == 0 and -166 or -188
		cyl(f, 0.5, 18, CF(x, 0.85, z), RGB(40, 42, 50), MAT.Metal, SOLIDP)
		cyl(f, 0.1, 18.2, CF(x, 1.12, z), spec.gold and RGB(255, 200, 60) or RGB(255, 60, 60), MAT.Neon)
		local model = C.buildCar(spec, CF(x, 1.1, z) * CFrame.Angles(0, math.rad(200 + col * 8), 0), "SHOWRM")
		model.Parent = f
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		local stand = P(f, V3(4, 3, 0.4), CF(x + 7, 1.8, z + 8), RGB(30, 30, 36), MAT.SmoothPlastic, SOLIDP)
		local priceText = spec.pass and "🎟️ GAME PASS" or (spec.rebirths and ("👑 " .. spec.rebirths .. " REBIRTHS") or ("$" .. fmt(spec.price)))
		billboard(stand, UDim2.fromOffset(190, 64), V3(0, 3.5, 0), {
			{text = spec.name, h = 0.5}, {text = priceText, h = 0.3, color = RGB(120, 255, 150)},
			{text = spec.speed .. " MPH top speed", h = 0.2, font = Enum.Font.GothamBold, color = RGB(200, 200, 210)}}, 60)
		C.prompt(stand, "Buy / Drive", spec.name, 10, 0.3, function(plr) F.buyOrDrive(plr, spec.key) end)
	end
	-- a few parked customer cars outside
	local parked = {"sedan", "hatch", "suv", "van", "sedan", "coupe"}
	for i, key in ipairs(parked) do
		local spec = table.clone(CAR[key])
		spec.color = Color3.fromHSV((i * 0.17) % 1, 0.55, 0.85)
		local m = C.buildCar(spec, CF(-50 + (i - 1) * 20 + 5, 0.2, -142) * CFrame.Angles(0, math.rad(90), 0), "CITY" .. i)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		m.Parent = f
	end
end

-- ===================================================================
-- GAME PASSES
-- ===================================================================
local PASS_BY_KEY = {}
for _, p in ipairs(PASSES) do PASS_BY_KEY[p.key] = p end
function F.loadPasses(plr, d)
	for _, p in ipairs(PASSES) do
		if p.id == 0 then
			-- not on sale yet. In Studio, "buy" it from the Store app to test it (see F.promptPass).
			d.passes[p.key] = d.passes[p.key] or false
		else
			local ok, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, p.id) end)
			if ok and owns then d.passes[p.key] = true end
		end
	end
end
-- turn a pass on for this session and apply its effects right away
function F.grantPass(plr, key)
	local d = data[plr]
	if not d or not PASS_BY_KEY[key] then return end
	d.passes[key] = true
	if key == "richstart" then F.claimRichStart(plr, d) end
	local car = F.activeCar(plr)
	if key == "nitro" and car then car.seat:SetAttribute("Nitro", true) end
	F.applyCharacter(plr, plr.Character)
end
function F.promptPass(plr, key)
	local p = PASS_BY_KEY[key]
	if not p then return end
	if p.id == 0 then
		local d = data[plr]
		if d and RunService:IsStudio() then
			F.grantPass(plr, key)
			notify(plr, "🧪 Studio test: " .. p.name .. " granted (set a real pass ID to sell it).")
		else
			notify(plr, "This pass isn't set up yet.")
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(plr, p.id)
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, bought)
	if not bought then return end
	local d = data[plr]
	if not d then return end
	for _, p in ipairs(PASSES) do
		if p.id == passId then
			F.grantPass(plr, p.key)
			R.Splash:FireClient(plr, p.icon .. " " .. p.name, "Thanks for your support!", RGB(255, 205, 60))
		end
	end
end)
end
