-- POLICE CARS (v14): draws the city's NPC police units. The server (GameServer > Police) moves one invisible root
-- part per unit ten times a second; here each one gets a black-and-white patrol car that glides smoothly to it, a
-- light bar that flashes red/blue while the siren is on, and a siren you hear when you're near.
return function(C)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local PCars = {cars = {}}
C.PoliceCars = PCars

local FX = Instance.new("Folder")
FX.Name = "PoliceCarsFX"
FX.Parent = Workspace
local function part(size, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = FX
	return p
end
local function build(root)
	local car = {root = root, parts = {}, cf = root.CFrame}
	local function add(size, off, color, mat, shape)
		local p = part(size, color, mat, shape)
		table.insert(car.parts, {p, off})
		return p
	end
	-- (the root part's -Z is the car's front)
	add(V3(6, 2.2, 13), CF(0, -0.5, 0), RGB(20, 22, 28))                       -- black body
	add(V3(6.05, 1.2, 5.5), CF(0, 0.2, 0.3), RGB(245, 245, 245))                -- white doors
	add(V3(5.2, 2.2, 6), CF(0, 1.4, 0.8), RGB(35, 45, 60), Enum.Material.Glass)
	add(V3(5.4, 0.25, 6.2), CF(0, 2.55, 0.8), RGB(245, 245, 245))
	car.red = add(V3(1.6, 0.5, 1), CF(-1.1, 2.9, 0.8), RGB(120, 20, 20), Enum.Material.Neon)
	car.blue = add(V3(1.6, 0.5, 1), CF(1.1, 2.9, 0.8), RGB(20, 40, 120), Enum.Material.Neon)
	for _, sx in ipairs({-1.9, 1.9}) do
		add(V3(1.2, 0.5, 0.2), CF(sx, -0.4, -6.6), RGB(255, 250, 225), Enum.Material.Neon)
		add(V3(1.2, 0.5, 0.2), CF(sx, -0.4, 6.55), RGB(255, 40, 40), Enum.Material.Neon)
	end
	for _, sz in ipairs({-4, 4}) do for _, sx in ipairs({-1, 1}) do
		add(V3(0.9, 2.6, 2.6), CF(sx * 2.75, -1.4, sz) * CFrame.Angles(0, 0, math.rad(90)), RGB(25, 25, 28), nil, Enum.PartType.Cylinder)
	end end
	local logo = add(V3(0.1, 1, 3.2), CF(3.06, 0.2, 0.3), RGB(245, 245, 245))
	local g = Instance.new("SurfaceGui")
	g.Face, g.LightInfluence = Enum.NormalId.Right, 0
	g.Parent = logo
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.TextScaled, t.Text, t.TextColor3, t.Font = UDim2.fromScale(1, 1), 1, true, "POLICE", RGB(20, 40, 120), Enum.Font.GothamBlack
	t.Parent = g
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Enabled = 24, 3, false
	light.Parent = car.red
	car.light = light
	local siren = Instance.new("Sound")
	siren.SoundId = (C.AUDIO and C.AUDIO.siren) or ""
	siren.Looped, siren.Volume, siren.RollOffMaxDistance = true, 0.35, 160
	siren.Parent = car.red
	car.siren = siren
	return car
end
local function drop(car)
	for _, e in ipairs(car.parts) do e[1]:Destroy() end
end
local folder = Workspace:WaitForChild("Police", 10)
local function track(root)
	if root:IsA("BasePart") and not PCars.cars[root] then PCars.cars[root] = build(root) end
end
if folder then
	for _, r in ipairs(folder:GetChildren()) do track(r) end
	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(function(r)
		local car = PCars.cars[r]
		if car then drop(car) PCars.cars[r] = nil end
	end)
end
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local flash = math.floor(now * 6) % 2 == 0
	local camPos = Workspace.CurrentCamera.CFrame.Position
	for root, car in pairs(PCars.cars) do
		if root.Parent then
			-- glide toward the server's position (it updates ten times a second)
			car.cf = car.cf:Lerp(root.CFrame, math.min(1, dt * 10))
			for _, e in ipairs(car.parts) do e[1].CFrame = car.cf * e[2] end
			local on = root:GetAttribute("Siren") == true
			car.red.Color = (on and flash) and RGB(255, 40, 40) or RGB(120, 20, 20)
			car.blue.Color = (on and not flash) and RGB(40, 90, 255) or RGB(20, 40, 120)
			car.light.Enabled = on
			car.light.Color = flash and RGB(255, 40, 40) or RGB(40, 90, 255)
			local near = on and (car.cf.Position - camPos).Magnitude < 160 and C.settings.sfx ~= false
			if near and not car.siren.IsPlaying and car.siren.SoundId ~= "" then car.siren:Play() elseif not near and car.siren.IsPlaying then car.siren:Stop() end
		end
	end
end)
end
