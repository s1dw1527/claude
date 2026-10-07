-- RACE TRACK: time trials with checkpoints, prizes and a best-times board.
return function(C)
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, ball, cyl, billboard, surfaceText, burst, shockwave, tag = C.P, C.ball, C.cyl, C.billboard, C.surfaceText, C.burst, C.shockwave, C.tag
local RACE, REP_TIERS, fmt, notify = C.RACE, C.REP_TIERS, C.fmt, C.notify
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 250), RGB(30, 30, 36)

local f = Instance.new("Folder")
f.Name = "RaceTrack"
f.Parent = C.WORLD
-- v11.2: the north bend runs close to the terrain's random edge hills; keep the track and its barriers clear of them
if C.clearTerrain then C.clearTerrain(-275, -630, 45, -535, 40) end

-- closed Catmull-Rom spline through the control points
local CTRL = {V3(-180, 0, -355), V3(0, 0, -355), V3(180, 0, -355), V3(240, 0, -395), V3(235, 0, -470), V3(170, 0, -510), V3(80, 0, -480),
	V3(20, 0, -520), V3(-20, 0, -585), V3(-130, 0, -595), V3(-230, 0, -555), V3(-255, 0, -470), V3(-240, 0, -395)}
local S = {}
local SUB = 12
local n = #CTRL
for i = 1, n do
	local p0, p1, p2, p3 = CTRL[(i - 2) % n + 1], CTRL[i], CTRL[i % n + 1], CTRL[(i + 1) % n + 1]
	for s = 0, SUB - 1 do
		local t = s / SUB
		local t2, t3 = t * t, t * t * t
		table.insert(S, 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3))
	end
end
local N = #S
local WIDTH = 26
local ENTRY = V3(0, 0, -338)
local trackLen = 0
local startIdx, best = 1, math.huge
for i = 1, N do
	local a, b = S[i], S[i % N + 1]
	trackLen += (b - a).Magnitude
	local dd = (a - V3(0, 0, -355)).Magnitude
	if dd < best then
		best = dd
		startIdx = i
	end
	C.reserve(a.X - 24, a.Z - 24, a.X + 24, a.Z + 24)
end
RACE.par = math.floor(trackLen / 44)
-- the fastest any car can legally go: best car, max rebirth speed bonus (+30%), nitro (x1.4), plus a 15% margin
local topSpeed = 0
for _, c in ipairs(C.CARS) do topSpeed = math.max(topSpeed, c.speed) end
RACE.maxSpeed = topSpeed * 1.3 * 1.4 * 1.15
RACE.minTime = trackLen / RACE.maxSpeed
for i = 1, N do
	local a, b = S[i], S[i % N + 1]
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CF(mid, b)
	P(f, V3(WIDTH, 2.3, len + 1.6), cf * CF(0, -0.85, 0), RGB(46, 48, 54), MAT.Asphalt, SOLID)
	P(f, V3(0.4, 0.04, len + 1.6), cf * CF(-WIDTH / 2 + 1, 0.32, 0), WHITE)
	P(f, V3(0.4, 0.04, len + 1.6), cf * CF(WIDTH / 2 - 1, 0.32, 0), WHITE)
	local nearEntry = math.abs(mid.X - ENTRY.X) < 14 and math.abs(mid.Z + 355) < 12
	for _, sx in ipairs({-1, 1}) do
		P(f, V3(2.2, 0.4, len + 0.2), cf * CF(sx * (WIDTH / 2 + 1.1), 0.2, 0), (i % 2 == 0) and RGB(220, 40, 40) or WHITE, MAT.SmoothPlastic, SOLID)
		if not (nearEntry and sx == 1 and mid.Z > -360) then
			P(f, V3(1, 2.2, len + 0.6), cf * CF(sx * (WIDTH / 2 + 6), 1.1, 0), (math.floor(i / 3) % 2 == 0) and RGB(40, 90, 200) or WHITE, MAT.SmoothPlastic, SOLID)
		end
	end
end
-- start/finish gantry + checkered line
do
	local a, b = S[startIdx], S[startIdx % N + 1]
	local cf = CF(a, b)
	for r = 0, 1 do
		for c = 0, 12 do
			P(f, V3(2, 0.05, 2), cf * CF(-WIDTH / 2 + 1 + c * 2, 0.33, -1 + r * 2), ((r + c) % 2 == 0) and DARK or WHITE)
		end
	end
	for _, sx in ipairs({-1, 1}) do P(f, V3(1.4, 16, 1.4), cf * CF(sx * (WIDTH / 2 + 3), 8, 0), DARK, MAT.Metal, SOLID) end
	local banner = P(f, V3(WIDTH + 8, 4, 1), cf * CF(0, 15, 0), DARK, MAT.SmoothPlastic)
	surfaceText(banner, Enum.NormalId.Back, "🏁 START / FINISH 🏁", WHITE)
	surfaceText(banner, Enum.NormalId.Front, "🏁 CORNER EMPIRE RACEWAY 🏁", WHITE)
	for k = 0, 4 do ball(f, V3(1.2, 1.2, 1.2), cf * CF(-4 + k * 2, 12.3, 0.8), RGB(255, 40, 40), MAT.Neon) end
end
-- DRIFT ZONE: the twisty back section. Sliding through it during a time trial earns a bonus (scored on the server).
local DRIFT_FROM, DRIFT_TO = 5 * SUB + 1, 8 * SUB + SUB
local driftPts = {}
for i = DRIFT_FROM, DRIFT_TO do
	local a, b = S[i], S[i % N + 1]
	table.insert(driftPts, a)
	local cf = CF((a + b) / 2, b)
	local len = (b - a).Magnitude
	for _, sx in ipairs({-1, 1}) do
		P(f, V3(0.6, 0.12, len + 0.4), cf * CF(sx * (WIDTH / 2 - 2.2), 0.36, 0), (i % 2 == 0) and RGB(255, 140, 30) or RGB(255, 230, 120), MAT.Neon)
	end
end
for _, i in ipairs({DRIFT_FROM, DRIFT_TO}) do
	local a, b = S[i], S[i % N + 1]
	local cf = CF(a, b)
	for _, sx in ipairs({-1, 1}) do P(f, V3(1, 12, 1), cf * CF(sx * (WIDTH / 2 + 3.5), 6, 0), RGB(40, 40, 50), MAT.Metal, SOLID) end
	local ban = P(f, V3(WIDTH + 8, 3, 0.6), cf * CF(0, 12.5, 0), RGB(255, 120, 30), MAT.SmoothPlastic)
	surfaceText(ban, Enum.NormalId.Back, "💨 DRIFT ZONE 💨", WHITE)
	surfaceText(ban, Enum.NormalId.Front, "💨 DRIFT ZONE 💨", WHITE)
end
local function inDriftZone(flat)
	for _, p in ipairs(driftPts) do
		if (flat - p).Magnitude < WIDTH then return true end
	end
	return false
end
RACE.driftBonusMax = 0.3   -- a perfect drift run adds up to +30% to the lap prize

-- checkpoint arches
local CPS = {}
local step = math.floor(N / 10)
for k = 1, 9 do
	local idx = (startIdx - 1 + k * step) % N + 1
	local a, b = S[idx], S[idx % N + 1]
	local cf = CF(a, b)
	for _, sx in ipairs({-1, 1}) do P(f, V3(0.8, 10, 0.8), cf * CF(sx * (WIDTH / 2 + 2.5), 5, 0), RGB(255, 200, 60), MAT.Neon) end
	local top = P(f, V3(WIDTH + 5.8, 1.2, 0.8), cf * CF(0, 10, 0), RGB(255, 200, 60), MAT.Neon)
	billboard(top, UDim2.fromOffset(80, 50), V3(0, 3, 0), {{text = tostring(k)}}, 250)
	table.insert(CPS, a)
end
table.insert(CPS, S[startIdx])
-- grandstand, crowd, pit kiosk, leaderboard
do
	for r = 0, 4 do
		P(f, V3(100, 1.5, 2.6), CF(-100, 0.75 + r * 1.5, -322 + r * 2.6), RGB(170, 170, 180), MAT.Concrete, SOLID)
		for k = 0, 24 do
			if math.random() < 0.7 then
				P(f, V3(1.2, 2, 0.8), CF(-146 + k * 3.8 + math.random(), 2.5 + r * 1.5, -322 + r * 2.6), Color3.fromHSV(math.random(), 0.7, 0.9))
				ball(f, V3(1, 1, 1), CF(-146 + k * 3.8, 4, -322 + r * 2.6), RGB(255, 205, 160))
			end
		end
	end
	P(f, V3(104, 0.6, 16), CF(-100, 13, -316), RGB(40, 44, 56), MAT.Metal)
	for _, x in ipairs({-150, -100, -50}) do P(f, V3(0.8, 12, 0.8), CF(x, 6, -309), RGB(40, 44, 56), MAT.Metal, SOLID) end
	C.reserve(-154, -330, -46, -306)
end
local board = P(f, V3(28, 14, 1), CF(70, 9, -322), DARK, MAT.SmoothPlastic, SOLID)
for _, x in ipairs({60, 80}) do P(f, V3(1, 4, 1), CF(x, 2, -322), DARK, MAT.Metal) end
local boardLabel = surfaceText(board, Enum.NormalId.Front, "🏆 BEST LAPS\n—", RGB(255, 220, 100))
C.reserve(54, -326, 86, -318)
local kiosk = P(f, V3(5, 4, 3), CF(16, 2, -328), RGB(220, 40, 40), MAT.SmoothPlastic, SOLID)
billboard(kiosk, UDim2.fromOffset(220, 70), V3(0, 5, 0), {{text = "🏁 TIME TRIAL", h = 0.55}, {text = "Needs " .. REP_TIERS[C.FEATURES.race].name .. " • drive in, press E", h = 0.45, font = Enum.Font.GothamBold, color = RGB(255, 220, 120)}}, 150)
C.reserve(12, -332, 20, -324)
C.DESTS_EXTRA = {name = "Race Track", icon = "🏁", pos = V3(0, 0.2, -330)}

-- ===== race logic =====
local racing = {}
C.serverBest = {}
local function updateBoard()
	local lines = {"🏆 BEST LAPS"}
	for i, e in ipairs(C.serverBest) do
		table.insert(lines, i .. ". " .. e.name .. "  " .. string.format("%.2fs", e.time))
	end
	if #C.serverBest == 0 then table.insert(lines, "No laps yet — be first!") end
	boardLabel.Text = table.concat(lines, "\n")
end
function F.raceFee(d) return math.max(200, math.floor(F.incomePerSec(d) * RACE.fee)) end
function F.startRace(plr)
	local d = data[plr]
	if not d then return end
	if not F.unlocked(d, "race") then
		notify(plr, "🔒 The Race Track unlocks at " .. REP_TIERS[C.FEATURES.race].name)
		return
	end
	local car = F.activeCar(plr)
	if not (car and car.seat.Occupant and car.seat.Occupant.Parent == plr.Character) then
		notify(plr, "🚗 Get in your car first, then drive up to the kiosk!")
		return
	end
	local fee = F.raceFee(d)
	if d.cash < fee then
		notify(plr, "Entry fee is $" .. fmt(fee))
		return
	end
	d.cash -= fee
	racing[plr] = {state = "armed", fee = fee, cp = 1}
	R.Race:FireClient(plr, {state = "armed", fee = fee, start = S[startIdx], total = #CPS})
	notify(plr, "🏁 Armed! Cross the start line to begin your lap.")
end
C.prompt(kiosk, "Start Time Trial", "Raceway", 22, 0, function(plr) F.startRace(plr) end)
function F.cancelRace(plr, why)
	if racing[plr] then
		racing[plr] = nil
		R.Race:FireClient(plr, {state = "cancel", why = why})
	end
end
task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for plr, st in pairs(racing) do
			local car = F.activeCar(plr)
			local d = data[plr]
			if not (d and car and car.seat.Occupant) then
				F.cancelRace(plr, "You left your car!")
			else
				local pos = car.root.Position
				local flat = V3(pos.X, 0, pos.Z)
				if st.state == "armed" then
					if (flat - S[startIdx]).Magnitude < WIDTH * 0.6 then
						st.state = "running"
						st.t0 = now
						st.cp = 1
						st.lastPos, st.lastT = S[startIdx], now
						st.drift = 0
						R.Race:FireClient(plr, {state = "running", cp = 1, total = #CPS, next = CPS[1]})
					end
				elseif st.state == "running" then
					local t = now - st.t0
					-- drift scoring: the server measures the car's own sideways slide (no client numbers involved)
					local vel = car.root.AssemblyLinearVelocity
					local lv = car.root.CFrame.LookVector
					local look = V3(lv.X, 0, lv.Z)
					if vel.Magnitude > 22 and look.Magnitude > 0.1 and inDriftZone(flat) then
						look = look.Unit
						local side = math.abs(vel:Dot(V3(-look.Z, 0, look.X)))
						local fwd = math.abs(vel:Dot(look))
						if side > 5 and side / math.max(8, fwd) > 0.22 then st.drift = math.min(100, st.drift + 0.1 * vel.Magnitude * 0.15) end
					end
					if t > RACE.maxTime then
						F.cancelRace(plr, "Too slow — lap timed out.")
					elseif (flat - CPS[st.cp]).Magnitude < WIDTH * 0.75 then
						-- server-side sanity check: nobody covers the gap between checkpoints faster than the fastest car can
						local gap = (CPS[st.cp] - st.lastPos).Magnitude
						local dt = math.max(0.05, now - st.lastT)
						if gap / dt > RACE.maxSpeed then
							racing[plr] = nil
							R.Race:FireClient(plr, {state = "cancel", why = "Lap invalid."})
							continue
						end
						st.lastPos, st.lastT = CPS[st.cp], now
						st.cp += 1
						if st.cp > #CPS then
							racing[plr] = nil
							if t < RACE.minTime then
								R.Race:FireClient(plr, {state = "cancel", why = "Lap invalid."})
							else
								local prize = math.floor(st.fee * math.clamp(1.6 * RACE.par / t, 0.3, 3))
								local driftBonus = math.floor(prize * RACE.driftBonusMax * math.clamp((st.drift or 0) / 100, 0, 1))
								prize += driftBonus
								d.cash += prize
								F.earn(d, prize)
								local pb = not d.raceBest or t < d.raceBest
								if pb then d.raceBest = t end
								local record = (not C.serverBest[1]) or t < C.serverBest[1].time
								table.insert(C.serverBest, {name = plr.Name, time = t})
								table.sort(C.serverBest, function(a, b) return a.time < b.time end)
								while #C.serverBest > 5 do table.remove(C.serverBest) end
								updateBoard()
								F.addRep(plr, 3)
								burst(pos + V3(0, 6, 0), RGB(255, 220, 80), 120)
								shockwave(pos, RGB(255, 220, 80), 30)
								R.Race:FireClient(plr, {state = "finished", time = t, prize = prize, best = d.raceBest, pb = pb, record = record, par = RACE.par, drift = math.floor(st.drift or 0), driftBonus = driftBonus})
								if record then F.buzz("🏁", plr.Name .. " set a new track record: " .. string.format("%.2fs", t) .. "!", RGB(255, 220, 80)) end
								F.pushMsg(plr, {icon = "🏁", from = "Raceway", text = string.format("Lap time %.2fs — you won $%s!%s", t, fmt(prize), pb and " New personal best!" or "")})
								F.tutorialEvent(plr, "race")
								if F.achieve then
									if t < RACE.par then F.achieve(plr, "raceWin") end
									if record then F.achieve(plr, "trackRecord") end
								end
							end
						else
							R.Race:FireClient(plr, {state = "running", cp = st.cp, total = #CPS, next = CPS[st.cp], drift = math.floor(st.drift or 0)})
						end
					end
				end
			end
		end
	end
end)
end
