-- v15: nothing stands in the street. Every solid prop the world builds (benches, trees, rocks, lamps, hydrants, bus
-- stops, buildings, parked cars...) is checked against every road's asphalt and every reserved path (the mountain
-- dirt road, the heist driveways), traffic never drives through the Empire Spire, and the mountain road is clear.
-- Run with: python3 tests/run.py tests/layout_test.lua
H.main(function()
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	T.newGame(a, 1, 1)
	H.task.wait(2)
	local V3 = Vector3.new

	-- the drivable asphalt of each road (the lanes, not the sidewalks)
	local lanes = {}
	for _, r in ipairs(C.ROADS) do
		local axis, c, a1, b1, w = r[1], r[2], r[3], r[4], r[5]
		if axis == "x" then table.insert(lanes, {name = "road z=" .. c, x1 = a1, x2 = b1, z1 = c - w / 2 + 0.5, z2 = c + w / 2 - 0.5})
		else table.insert(lanes, {name = "road x=" .. c, x1 = c - w / 2 + 0.5, x2 = c + w / 2 - 0.5, z1 = a1, z2 = b1}) end
	end
	for _, p in ipairs(C.PATHS) do table.insert(lanes, {name = p.name, x1 = p[1], z1 = p[2], x2 = p[3], z2 = p[4], path = true}) end
	local function footprint(p)
		-- (axis-aligned bounds of the part's footprint, good enough for props)
		local cf, s = p.CFrame, p.Size
		local hx, hz = 0, 0
		for _, v in ipairs({cf.RightVector * s.X / 2, cf.UpVector * s.Y / 2, cf.LookVector * s.Z / 2}) do
			hx += math.abs(v.X)
			hz += math.abs(v.Z)
		end
		return p.Position.X - hx, p.Position.Z - hz, p.Position.X + hx, p.Position.Z + hz
	end
	local function overlaps(p, l)
		local x1, z1, x2, z2 = footprint(p)
		return x1 < l.x2 and x2 > l.x1 and z1 < l.z2 and z2 > l.z1
	end
	-- what may legitimately be on a road: the asphalt and its markings, overhead things, see-through helpers,
	-- and things that are part of the road itself (crosswalk stripes, manholes, traffic-light arms high up)
	local function exempt(p)
		if p.Transparency >= 0.99 then return true end
		if p.Material == Enum.Material.Asphalt then return true end
		local bottom = p.Position.Y - p.Size.Y / 2
		local top = p.Position.Y + p.Size.Y / 2
		if top <= 0.6 then return true end           -- paint, markings, flat paths
		if bottom >= 6 then return true end          -- overhead: signs, arms, wires, lights, bridges
		return false
	end
	local hits = {}
	local checked = 0
	local function scan(root, label)
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") and not exempt(p) then
				checked += 1
				for _, l in ipairs(lanes) do
					-- (the dirt road and the driveways are drawn as flat parts: covered by the top <= 0.6 rule)
					if overlaps(p, l) then
						table.insert(hits, label .. "/" .. p:GetFullName():gsub("^Workspace%.", "") .. " on " .. l.name .. string.format(" at (%d, %d)", p.Position.X, p.Position.Z))
						break
					end
				end
			end
		end
	end

	H.section("Nothing solid on the roads or the paths")
	local city = H.workspace:FindFirstChild("City")
	H.check(city ~= nil and #C.PATHS >= 4, "the city is built; " .. #C.PATHS .. " reserved paths (mountain road, heist driveways, lanes)")
	scan(city, "City")
	for _, name in ipairs({"Police", "Homes", "Interiors"}) do
		local f = H.workspace:FindFirstChild(name)
		if f then scan(f, name) end
	end
	local shown = {}
	for i = 1, math.min(12, #hits) do shown[i] = hits[i] end
	H.check(#hits == 0, checked .. " solid parts checked: " .. #hits .. " in the street" .. (#hits > 0 and (": " .. table.concat(shown, " | ")) or ""))
	local nature = city:FindFirstChild("Nature")
	local inPath = 0
	for _, p in ipairs(nature and nature:GetDescendants() or {}) do
		if p:IsA("BasePart") then
			for _, l in ipairs(lanes) do if l.path and overlaps(p, l) then inPath += 1 end end
		end
	end
	H.check(nature and inPath == 0, "no tree, bush, flower or rock on the mountain road or the heist driveways")

	H.section("The plaza benches")
	local benches = 0
	for _, p in ipairs(city:GetDescendants()) do
		if p:IsA("BasePart") and p.Material == Enum.Material.WoodPlanks and math.abs(p.Size.X - 5) < 0.01 and math.abs(p.Size.Y - 0.3) < 0.01 then
			local x, z = p.Position.X, p.Position.Z
			if math.abs(math.abs(x) - 60) < 1 or math.abs(math.abs(z) - 60) < 1 then
				if math.max(math.abs(x), math.abs(z)) > 110 and math.max(math.abs(x), math.abs(z)) < 125 then
					benches += 1
					H.check(math.max(math.abs(x), math.abs(z)) < 121, string.format("plaza bench at (%d, %d) is on the plaza sidewalk, off the ring road", x, z))
				end
			end
		end
	end
	H.check(benches == 6, "the 6 plaza benches are there (" .. benches .. ")")

	H.section("Traffic and the Empire Spire")
	local inner = 0
	for _, r in ipairs(C.trafficRoads()) do
		if r[2] == 0 and r[3] < 10 and r[4] > -10 then inner += 1 end
	end
	H.check(inner == 0, "no traffic road runs through the plaza's middle, where the Spire stands")
	local cat = C.catalog and C.catalog.map or (C.F.mapCatalog and C.F.mapCatalog())
	local cl = H.clientC
	local CC = cl and cl.CityCrowd
	if CC then
		local through = 0
		for _, r in ipairs(CC.ROADS) do
			if r.c == 0 and r.a < 10 and r.b > -10 then through += 1 end
		end
		H.check(through == 0, "the client's traffic network doesn't cross the Spire either")
	end

	H.section("The mountain road")
	local f = H.workspace.City:FindFirstChild("Mountain") or H.workspace:FindFirstChild("Mountain")
	local blocked = {}
	for _, root in ipairs({H.workspace}) do
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide and p.Transparency < 0.99 then
				local x1, z1, x2, z2 = footprint(p)
				local bottom, top = p.Position.Y - p.Size.Y / 2, p.Position.Y + p.Size.Y / 2
				if x1 < 304 and x2 > 296 and z1 < -306 and z2 > -600 and top > 0.6 and bottom < 7 then table.insert(blocked, p:GetFullName()) end
			end
		end
	end
	H.check(#blocked == 0, "a car-wide lane from North Rd to the ravine is clear" .. (#blocked > 0 and (": " .. table.concat(blocked, ", "):sub(1, 300)) or ""))
	local _ = f

	T.assertClean("layout")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
