-- POLICE (v14): the city's police are NPC officers in patrol cars. Players don't play police any more.
--
-- Each unit has a simple state machine, decided on the server twice a second and moved ten times a second:
--   PATROL   cruise the roads near the station and the city center
--   RESPOND  an alarm went off: the nearest free units drive to the APPROXIMATE alert area
--   SEARCH   drive around that area; the search center moves with the (approximate) updates Heists sends
--   PURSUE   a unit actually SEES a robber carrying loot (within `detect` studs): it chases them, along the roads
--            when far and straight at them when close. Get more than `lose` studs away for `loseTime` seconds and
--            it falls back to searching around where it last saw you. Reaching the mountain ends the chase.
--   ARREST   a unit right next to a robber who is slow or stopped for `arrestHold` seconds: the loot is lost, a
--            modest fine, a short time in a cell and a cooldown before the next job. Nothing else is ever taken.
-- Units only know what they see: they never get a robber's exact position from the server unless they spot them.
-- Movement follows the road network (the same table the world and the traffic are built from), so police cars
-- drive the streets instead of through buildings; only the last stretch of a close chase leaves the road.
-- Clients draw the cars (EmpireClient > PoliceCars) from each unit's root part and its attributes.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local HC = C.HEIST
local PC = HC.police
local MC = C.MOUNTAIN
local HS = C.HEIST_STATE
local STATION = C.POLICE_STATION

-- ===== the road graph =====
local nodes, nodeAt = {}, {}
local function nodeKey(x, z) return math.floor(x + 0.5) .. "," .. math.floor(z + 0.5) end
local function getNode(x, z)
	local k = nodeKey(x, z)
	local n = nodeAt[k]
	if not n then
		n = {pos = V3(x, 0, z), edges = {}, i = #nodes + 1}
		nodes[n.i] = n
		nodeAt[k] = n
	end
	return n
end
for _, r in ipairs(C.ROADS) do
	local axis, c, a, b = r[1], r[2], r[3], r[4]
	local coords = {a, b}
	for _, x in ipairs(r[6] or {}) do if x > a and x < b then table.insert(coords, x) end end
	table.sort(coords)
	local prev
	for _, s in ipairs(coords) do
		local n = axis == "x" and getNode(s, c) or getNode(c, s)
		if prev and prev ~= n then
			local d = (prev.pos - n.pos).Magnitude
			table.insert(prev.edges, {to = n, d = d})
			table.insert(n.edges, {to = prev, d = d})
		end
		prev = n
	end
end
local POLICE_GRAPH = {nodes = nodes}
local function nearestNode(pos)
	local best, bd
	for _, n in ipairs(nodes) do
		local d = (V3(pos.X, 0, pos.Z) - n.pos).Magnitude
		if not bd or d < bd then best, bd = n, d end
	end
	return best, bd
end
-- shortest path between two nodes (Dijkstra; ~70 nodes, cheap)
local function route(from, to)
	if from == to then return {to.pos} end
	local dist, prev, done = {[from] = 0}, {}, {}
	while true do
		local u, ud
		for n, d in pairs(dist) do
			if not done[n] and (not ud or d < ud) then u, ud = n, d end
		end
		if not u or u == to then break end
		done[u] = true
		for _, e in ipairs(u.edges) do
			local nd = ud + e.d
			if not dist[e.to] or nd < dist[e.to] then dist[e.to], prev[e.to] = nd, u end
		end
	end
	if not prev[to] then return {to.pos} end
	local path, n = {}, to
	while n and n ~= from do
		table.insert(path, 1, n.pos)
		n = prev[n]
	end
	return path
end
POLICE_GRAPH.route, POLICE_GRAPH.nearest = route, nearestNode
C.POLICE_GRAPH = POLICE_GRAPH

-- ===== units =====
local FOLDER = Instance.new("Folder")
FOLDER.Name = "Police"
FOLDER.Parent = Workspace
local units = {}
local seq = 0
local function spawnUnit()
	seq += 1
	local home = nearestNode(STATION.pos)
	local root = Instance.new("Part")
	root.Name = "Unit" .. seq
	root.Size = V3(6, 3, 13)
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.Transparency = 1
	root.CFrame = CF(home.pos + V3(0, 1.7, 0))
	root:SetAttribute("State", "patrol")
	root:SetAttribute("Siren", false)
	root.Parent = FOLDER
	local u = {id = seq, root = root, pos = home.pos, yaw = 0, path = {}, state = "patrol", speed = PC.speed.patrol, since = os.clock(), idleSince = os.clock()}
	table.insert(units, u)
	return u
end
local function removeUnit(u)
	for i, x in ipairs(units) do if x == u then table.remove(units, i) break end end
	u.root:Destroy()
end
local function setState(u, state, extra)
	u.state = state
	u.since = os.clock()
	u.path = {}
	u.hold = 0
	for k, v in pairs(extra or {}) do u[k] = v end
	u.speed = PC.speed[state] or PC.speed.patrol
	u.root:SetAttribute("State", state)
	u.root:SetAttribute("Siren", state ~= "patrol")
	if state ~= "pursue" then u.target = nil end
	if state == "patrol" then u.idleSince = os.clock() end
end
local function pathTo(u, pos, direct)
	local from = nearestNode(u.pos)
	local to = nearestNode(pos)
	u.path = route(from, to)
	if direct then table.insert(u.path, V3(pos.X, 0, pos.Z)) end
end
local function rootOf(p) return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local chasing = {}    -- [plr] = number of units chasing
local function chaseCount(plr)
	local n = 0
	for _, u in ipairs(units) do if u.state == "pursue" and u.target == plr then n += 1 end end
	return n
end
local function tellChase(plr)
	local n = chaseCount(plr)
	local was = chasing[plr] or 0
	chasing[plr] = n > 0 and n or nil
	if n > 0 and was == 0 then
		R.Splash:FireClient(plr, "🚓 POLICE ON YOUR TAIL", "Lose them, or get the loot into the mountain!", RGB(80, 140, 255))
	elseif n == 0 and was > 0 and HS.robbers[plr] then
		C.notify(plr, "🚓 You lost them... for now.")
	end
	R.Menu:FireClient(plr, "policeChase", {on = n > 0, units = n})
end
function C.policeChasing(plr) return (chasing[plr] or 0) > 0 end
function C.policeStatus()
	local out = {patrol = 0, respond = 0, search = 0, pursue = 0, total = #units}
	for _, u in ipairs(units) do out[u.state] = (out[u.state] or 0) + 1 end
	return out
end
C.POLICE_UNITS = units

-- ===== dispatch (called by Heists) =====
local searches = {}    -- [site key] = {pos, radius, until}
function C.policeDispatch(alert)
	if type(alert) ~= "table" or not alert.pos then return end
	local key = alert.site or "?"
	searches[key] = {pos = alert.pos, radius = alert.radius or 80, untilT = os.clock() + PC.searchTime}
	-- the nearest units that aren't already busy with a chase respond (new ones roll out of the station if needed)
	local free = {}
	for _, u in ipairs(units) do if u.state == "patrol" or u.state == "search" then table.insert(free, u) end end
	while #free < PC.perAlert and #units < PC.maxUnits do table.insert(free, spawnUnit()) end
	table.sort(free, function(a, b) return (a.pos - alert.pos).Magnitude < (b.pos - alert.pos).Magnitude end)
	for i = 1, math.min(PC.perAlert, #free) do
		local u = free[i]
		setState(u, "respond", {site = key})
		pathTo(u, alert.pos, true)
	end
end
-- an approximate update ("suspect last seen around Downtown"): searching units move their search there
function C.policeReport(plr, approxPos, siteKey)
	local s = searches[siteKey or "?"]
	if s then
		s.pos = approxPos
		s.untilT = math.max(s.untilT, os.clock() + PC.searchTime / 2)
	else
		searches[siteKey or "?"] = {pos = approxPos, radius = 90, untilT = os.clock() + PC.searchTime}
	end
	for _, u in ipairs(units) do
		if u.state == "search" and u.site == (siteKey or "?") then u.path = {} end
	end
end
function C.policeClear()
	for _, u in ipairs(units) do if u.state ~= "patrol" then setState(u, "patrol") end end
	table.clear(searches)
	for plr in pairs(chasing) do chasing[plr] = nil if plr.Parent then R.Menu:FireClient(plr, "policeChase", {on = false, units = 0}) end end
end

-- ===== decisions (twice a second) =====
local lastPos = {}     -- [plr] = {pos, t}: speed estimate from real movement
local function speedOf(plr, root)
	local lp = lastPos[plr]
	local now = os.clock()
	local s = 0
	if lp and now - lp.t > 0.05 then
		s = (V3(root.Position.X, 0, root.Position.Z) - V3(lp.pos.X, 0, lp.pos.Z)).Magnitude / (now - lp.t)
	end
	return s
end
local function wanted()
	-- robbers carrying loot after the alarm (the only people police can chase)
	local out = {}
	for plr, r in pairs(HS.robbers) do
		local root = rootOf(plr)
		if root and r.bag > 0 and r.alarmAt and not (MC.inBase and MC.inBase(root.Position)) then out[plr] = root end
	end
	return out
end
local function decide(dt)
	local now = os.clock()
	local W = wanted()
	local speeds = {}
	for plr, root in pairs(W) do speeds[plr] = speedOf(plr, root) end
	for _, u in ipairs(table.clone(units)) do
		-- anyone wanted in sight? (patrol, respond and search all keep their eyes open)
		if u.state ~= "pursue" then
			for plr, root in pairs(W) do
				if (V3(root.Position.X, 0, root.Position.Z) - u.pos).Magnitude <= PC.detect then
					setState(u, "pursue", {target = plr, lastSeen = root.Position, lostFor = 0, replan = 0})
					tellChase(plr)
					break
				end
			end
		end
		if u.state == "pursue" then
			local plr = u.target
			local root = plr and W[plr]
			if not root then
				-- they got into the mountain, dropped the loot, left, or were arrested by another unit
				setState(u, "patrol")
				if plr then tellChase(plr) end
			else
				local d = (V3(root.Position.X, 0, root.Position.Z) - u.pos).Magnitude
				if d <= PC.lose then
					u.lostFor = 0
					u.lastSeen = root.Position
				else
					u.lostFor += dt
				end
				if u.lostFor >= PC.loseTime then
					-- lost them: search where they were last seen
					local key = HS.robbers[plr] and HS.robbers[plr].heist and HS.robbers[plr].heist.site.key or "?"
					searches[key] = {pos = u.lastSeen, radius = 90, untilT = now + PC.searchTime}
					setState(u, "search", {site = key})
					tellChase(plr)
				else
					u.replan -= dt
					if u.replan <= 0 then
						u.replan = 1
						if d < PC.direct then u.path = {V3(root.Position.X, 0, root.Position.Z)} else pathTo(u, root.Position, true) end
					end
					-- the arrest: right next to them while they're slow or stopped
					if d <= PC.arrestRange and (speeds[plr] or 0) < PC.arrestSlow then
						u.hold = (u.hold or 0) + dt
						if u.hold >= PC.arrestHold and F.npcArrest then
							F.npcArrest(u, plr)
							for _, o in ipairs(units) do if o.target == plr then setState(o, "patrol") end end
							tellChase(plr)
						end
					else
						u.hold = 0
					end
				end
			end
		elseif u.state == "respond" then
			if #u.path == 0 then setState(u, "search", {site = u.site}) end
		elseif u.state == "search" then
			local s = searches[u.site or "?"]
			if not s or now > s.untilT then
				setState(u, "patrol")
			elseif #u.path == 0 then
				-- drive to a road junction somewhere in the search area (not the exact spot: it's an area)
				local cands = {}
				for _, n in ipairs(nodes) do if (n.pos - V3(s.pos.X, 0, s.pos.Z)).Magnitude <= s.radius + 60 then table.insert(cands, n) end end
				local goal = #cands > 0 and cands[math.random(#cands)].pos or s.pos
				pathTo(u, goal, false)
			end
		elseif u.state == "patrol" then
			if #u.path == 0 then
				local cands = {}
				for _, n in ipairs(nodes) do
					if (n.pos - V3(STATION.pos.X, 0, STATION.pos.Z)).Magnitude < PC.patrolRadius or n.pos.Magnitude < PC.patrolRadius then table.insert(cands, n) end
				end
				if #cands > 0 then pathTo(u, cands[math.random(#cands)].pos, false) end
			end
			-- extra units go back to the station when it's quiet
			if #units > PC.units and next(W) == nil and now - u.idleSince > PC.idleRemove then removeUnit(u) end
		end
	end
	for plr, root in pairs(W) do lastPos[plr] = {pos = root.Position, t = now} end
	for plr in pairs(lastPos) do if not W[plr] then lastPos[plr] = nil end end
	for plr in pairs(chasing) do if not W[plr] then tellChase(plr) end end
end
-- ===== movement (ten times a second) =====
local function move(dt)
	for _, u in ipairs(units) do
		local goal = u.path[1]
		if goal then
			local to = goal - u.pos
			local dist = to.Magnitude
			local step = u.speed * dt
			if dist <= step then
				u.pos = goal
				table.remove(u.path, 1)
			else
				u.pos += to.Unit * step
			end
			if dist > 0.1 then
				local want = math.atan2(-to.X, -to.Z)
				local diff = (want - u.yaw + math.pi) % (2 * math.pi) - math.pi
				u.yaw += diff * math.min(1, dt * 8)
			end
		end
		u.root.CFrame = CF(u.pos + V3(0, 1.7, 0)) * CFrame.Angles(0, u.yaw, 0)
	end
end
-- the station always has PC.units cars on patrol
for _ = 1, PC.units do spawnUnit() end
task.spawn(function()
	local acc = 0
	while true do
		local dt = task.wait(0.1)
		dt = math.min(dt or 0.1, 0.5)
		local ok, err = pcall(move, dt)
		if not ok then warn("[CornerEmpire] police move: " .. tostring(err)) end
		acc += dt
		if acc >= 0.5 then
			local ok2, err2 = pcall(decide, acc)
			if not ok2 then warn("[CornerEmpire] police: " .. tostring(err2)) end
			acc = 0
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	chasing[plr], lastPos[plr] = nil, nil
	for _, u in ipairs(units) do if u.target == plr then setState(u, "patrol") end end
end)
end
