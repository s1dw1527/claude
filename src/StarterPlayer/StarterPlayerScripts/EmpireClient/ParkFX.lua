-- PARK FX (v15): what makes the parks move on your screen.
--   * TRACK MOVERS: roller-coaster trains (tag "TrackMover", built by GameServer > Park and the Fun Park). The
--     track's points come in the Pts attribute; the train's place is worked out from the server clock, so every
--     player sees the same train in the same place. Slow up the lift hill, fast down the drops, upside down in a loop
--   * RIDING: "parkRide" from the server: the camera rides the car (or the seat of a spinning ride) for the ride's
--     length, then comes back
--   * VISITORS: people walking the paths of the player park you're standing in (some with cotton candy or a
--     balloon), pooled and only near you; how many depends on the park's rating
return function(C)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local R, U = C.R, C.U
local camera = Workspace.CurrentCamera
local PF = {movers = {}, riding = nil, visitors = {}, site = nil}
C.ParkFX = PF

-- ===== track movers =====
local function parsePts(s)
	local out = {}
	if type(s) ~= "string" then return out end
	for x, y, z in string.gmatch(s, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do table.insert(out, V3(tonumber(x), tonumber(y), tonumber(z))) end
	return out
end
-- the same timing as the server (GameServer > Park): slow on the lift, faster the further it has dropped
local function timing(pts, liftA, liftB)
	local hmax = -math.huge
	for _, p in ipairs(pts) do hmax = math.max(hmax, p.Y) end
	local T, t = {0}, 0
	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]
		local v
		if liftA and i >= liftA and i <= liftB then v = 5
		else v = math.max(7, math.sqrt(2 * 12 * math.max(0, hmax - (a.Y + b.Y) / 2)) + 5) end
		t += (b - a).Magnitude / v
		T[i + 1] = t
	end
	return T, t
end
local function frames(pts)
	local out, n = {}, #pts
	local up = V3(0, 1, 0)
	for i = 1, n do
		local look = (pts[i % n + 1] - pts[(i - 2) % n + 1])
		look = look.Magnitude > 0.001 and look.Unit or V3(0, 0, -1)
		up = up - look * up:Dot(look)
		up = up.Magnitude > 0.001 and up.Unit or V3(0, 1, 0)
		out[i] = {look = look, up = up}
	end
	return out
end
local function addMover(m)
	if not m:IsA("Model") then return end
	local pts = parsePts(m:GetAttribute("Pts"))
	if #pts < 4 then return end
	local T, cycle = timing(pts, m:GetAttribute("LiftA"), m:GetAttribute("LiftB"))
	local cum, total = {0}, 0
	for i = 1, #pts do
		total += (pts[i % #pts + 1] - pts[i]).Magnitude
		cum[i + 1] = total
	end
	local e = {model = m, pts = pts, fr = frames(pts), T = T, cycle = cycle, cum = cum, total = total, gap = m:GetAttribute("Gap") or 3.4,
		phase = m:GetAttribute("Phase") or 0, parts = {}, center = pts[1]}
	local sum = V3()
	for _, p in ipairs(pts) do sum += p end
	e.center = sum / #pts
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Car") then
			local off = p:GetAttribute("Off")
			table.insert(e.parts, {p = p, car = p:GetAttribute("Car"), off = typeof(off) == "CFrame" and off or CF()})
		end
	end
	PF.movers[m] = e
end
-- where along the track (studs from the start) the front of the train is at server time t
local function frontDist(e, t)
	local tt = (t + e.phase) % e.cycle
	local lo, hi = 1, #e.pts
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if e.T[mid] <= tt then lo = mid else hi = mid - 1 end
	end
	local seg = e.T[lo + 1] - e.T[lo]
	local f = seg > 0 and (tt - e.T[lo]) / seg or 0
	return e.cum[lo] + (e.cum[lo + 1] - e.cum[lo]) * f
end
-- the car's frame at a distance along the track
local function cfAt(e, dist)
	dist %= e.total
	local lo, hi = 1, #e.pts
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if e.cum[mid] <= dist then lo = mid else hi = mid - 1 end
	end
	local n = #e.pts
	local a, b = e.pts[lo], e.pts[lo % n + 1]
	local seg = e.cum[lo + 1] - e.cum[lo]
	local f = seg > 0 and (dist - e.cum[lo]) / seg or 0
	local pos = a:Lerp(b, f)
	local fa, fb = e.fr[lo], e.fr[lo % n + 1]
	local look = fa.look:Lerp(fb.look, f)
	look = look.Magnitude > 0.001 and look.Unit or fa.look
	local up = fa.up:Lerp(fb.up, f)
	local right = look:Cross(up)
	right = right.Magnitude > 0.001 and right.Unit or V3(1, 0, 0)
	return CFrame.fromMatrix(pos, right, right:Cross(look), -look)
end
function PF.trainCF(m, t, car)
	local e = PF.movers[m]
	if not e then return nil end
	return cfAt(e, frontDist(e, t or Workspace:GetServerTimeNow()) - (car or 0) * e.gap)
end
for _, m in ipairs(CollectionService:GetTagged("TrackMover")) do addMover(m) end
CollectionService:GetInstanceAddedSignal("TrackMover"):Connect(function(m) task.defer(addMover, m) end)

-- ===== riding =====
local rideLabel
local function stopRide()
	local r = PF.riding
	if not r then return end
	PF.riding = nil
	camera.CameraType = Enum.CameraType.Custom
	if rideLabel then rideLabel.Visible = false end
end
PF.stopRide = stopRide
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind ~= "parkRide" or type(a) ~= "table" or typeof(a.model) ~= "Instance" then return end
	local seat = a.model:FindFirstChild("RideSeat", true)
	if not seat then return end
	stopRide()
	PF.riding = {seat = seat, ends = os.clock() + (tonumber(a.dur) or 15), name = a.name, coaster = a.coaster}
	camera.CameraType = Enum.CameraType.Scriptable
	if not rideLabel and C.gui then
		rideLabel = C.label({Size = UDim2.fromOffset(300, 34), Position = UDim2.new(0.5, -150, 0, 70), BackgroundTransparency = 0.25, BackgroundColor3 = RGB(30, 20, 40),
			TextColor3 = C.GOLD or RGB(255, 210, 90), Font = Enum.Font.GothamBlack, TextSize = 16, Text = ""}, C.gui)
		rideLabel.Name = "RideBanner"
		if C.corner then C.corner(rideLabel, 10) end
	end
	if rideLabel then
		rideLabel.Text = (a.icon or "🎢") .. " Riding: " .. tostring(a.name) .. (a.owner and ("  (" .. a.owner .. "'s park)") or "")
		rideLabel.Visible = true
	end
	if C.jingle then C.jingle("milestone", 0.3) end
end)

-- ===== visitors in a player park =====
local CC = C.CityCrowd
local POOL_MAX = 14
local pool = {}
local function grounds() return Workspace:FindFirstChild("City") and Workspace.City:FindFirstChild("Funland") end
local function cellPos(gcf, x, z) return (gcf * CF(x * 4 + 2, 0, z * 4 + 2)).Position end
local function siteNear(pos)
	local g = grounds()
	if not g then return nil end
	for _, s in ipairs(g:GetChildren()) do
		local gcf = s:GetAttribute("GridCF")
		if typeof(gcf) == "CFrame" and (s:GetAttribute("Owner") or 0) ~= 0 then
			local center = (gcf * CF(40, 0, 48)).Position
			if (center - pos).Magnitude < 130 then return s, gcf end
		end
	end
	return nil
end
local function pathCells(site)
	local cells = {}
	local items = site:FindFirstChild("Items")
	for _, it in ipairs(items and items:GetChildren() or {}) do
		if it:GetAttribute("Kind") == "path" then
			local x, z = string.match(it:GetAttribute("Cell") or "", "(%d+),(%d+)")
			if x then cells[x .. "," .. z] = {tonumber(x), tonumber(z)} end
		end
	end
	return cells
end
local function ensurePool()
	if not (CC and CC.buildPerson) then return end
	while #pool < POOL_MAX do
		local n = CC.buildPerson()
		CC.hidePerson(n)
		table.insert(pool, {n = n, on = false})
	end
end
local function want(site)
	local crowd = C.settings and C.settings.crowd or "high"
	if crowd == "off" then return 0 end
	local n = math.clamp(3 + math.floor((site:GetAttribute("Rating") or 0) / 7), 3, POOL_MAX)
	return crowd == "low" and math.ceil(n / 2) or n
end
local function placeVisitor(v, gcf, cells, list)
	v.gcf = gcf
	if #list > 0 then
		local c = list[math.random(#list)]
		v.cell, v.prev = c, nil
		v.pos = cellPos(gcf, c[1], c[2])
		v.target = v.pos
		v.walk = true
	else
		-- no paths yet: they mill around inside the gate
		v.pos = cellPos(gcf, math.random(1, 3), math.random(9, 14)) + V3(math.random() - 0.5, 0, math.random() - 0.5) * 3
		v.target = v.pos
		v.walk = false
	end
	v.cells = cells
	v.look = ({"candy", "balloon", "candy", "tourist", "balloon", "casual"})[math.random(6)]
	CC.dress(v.n, v.look)
	CC.showPerson(v.n)
	v.on = true
	v.phase = math.random() * 6
	v.speed = 3.2 + math.random() * 1.6
end
local function nextCell(v)
	local c = v.cell
	local opts = {}
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		local k = (c[1] + d[1]) .. "," .. (c[2] + d[2])
		local nc = v.cells[k]
		if nc and nc ~= v.prev then table.insert(opts, nc) end
	end
	if #opts == 0 and v.prev then opts = {v.prev} end
	if #opts == 0 then return nil end
	v.prev = c
	v.cell = opts[math.random(#opts)]
	return cellPos(v.gcf, v.cell[1], v.cell[2]) + V3((math.random() - 0.5) * 1.6, 0, (math.random() - 0.5) * 1.6)
end
local checkT = 0
function PF.refreshVisitors()
	local site, gcf = siteNear(camera.CFrame.Position)
	if site then ensurePool() end   -- (built the first time you visit a park)
	PF.site = site
	local n = site and want(site) or 0
	local cells, list = {}, {}
	if site then
		cells = pathCells(site)
		for _, c in pairs(cells) do table.insert(list, c) end
	end
	PF.active = 0
	for i, v in ipairs(pool) do
		if i <= n then
			if not v.on or v.gcf ~= gcf or v.npaths ~= #list then placeVisitor(v, gcf, cells, list) end
			v.npaths = #list
			PF.active += 1
		elseif v.on then
			v.on = false
			CC.hidePerson(v.n)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local now = Workspace:GetServerTimeNow()
	local camPos = camera.CFrame.Position
	for m, e in pairs(PF.movers) do
		if not m.Parent then
			PF.movers[m] = nil
		elseif (e.center - camPos).Magnitude < 450 or (PF.riding and PF.riding.seat:IsDescendantOf(m)) then
			local front = frontDist(e, now)
			local cfs = {}
			for _, pp in ipairs(e.parts) do
				local base = cfs[pp.car]
				if not base then
					base = cfAt(e, front - pp.car * e.gap)
					cfs[pp.car] = base
				end
				pp.p.CFrame = base * pp.off
			end
		end
	end
	-- the ride camera (after the train has moved this frame)
	local r = PF.riding
	if r then
		if os.clock() >= r.ends or not r.seat.Parent then
			stopRide()
		else
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = r.seat.CFrame * CF(0, r.coaster and 2.4 or 2.8, r.coaster and 0.4 or 0)
		end
	end
	checkT += dt
	if checkT >= 0.5 then
		checkT = 0
		PF.refreshVisitors()
	end
	if CC and CC.pose then
		local clock = os.clock()
		for _, v in ipairs(pool) do
			if v.on then
				if v.walk then
					local d = v.target - v.pos
					if d.Magnitude < 0.3 then
						v.target = nextCell(v) or v.pos
					else
						v.pos += d.Unit * math.min(d.Magnitude, v.speed * dt)
					end
					v.phase += dt * 7
				end
				local dir = v.target - v.pos
				local flat = V3(dir.X, 0, dir.Z)
				local cf = flat.Magnitude > 0.05 and CFrame.lookAt(v.pos, v.pos + flat) or (CF(v.pos) * CFrame.Angles(0, v.phase, 0))
				CC.pose(v.n, cf * CF(0, 0.3, 0), v.walk and v.phase or clock * 2, v.walk and flat.Magnitude > 0.05 and "walk" or "chat")
			end
		end
	end
end)
end
