-- v11.2: nothing the game builds is buried in the terrain's random edge hills.
-- World.lua drops random grass/rock hills (Terrain:FillBall) along the map edges. The simulated engine has no
-- terrain, so this test takes the WORST CASE of those hills (any jitter, the biggest radius) and checks that every
-- solid part that could end up inside one sits in an area the game clears (C.clearTerrain).
-- Run with: python3 tests/run.py tests/terrain_test.lua
H.main(function()
	local C = T.startServer()
	local function hillDepth(p)
		local best = -1e9
		local function ball(cx0, cx1, cz0, cz1, cy, r)
			local dx = math.max(cx0 - p.X, 0, p.X - cx1)
			local dz = math.max(cz0 - p.Z, 0, p.Z - cz1)
			best = math.max(best, r - math.sqrt(dx * dx + dz * dz + (p.Y - cy) ^ 2))
		end
		for x = -780, 780, 120 do
			ball(x - 30, x + 30, -790, -730, -40, 140)
			ball(x - 30, x + 30, -840, -840, -20, 160)
		end
		for z = -700, 300, 130 do
			ball(780, 830, z - 30, z + 30, -45, 120)
			ball(-830, -780, z - 30, z + 30, -45, 120)
		end
		return best
	end
	local function cleared(p, size)
		for _, b in ipairs(C.clearedTerrain) do
			if p.X >= b[1] and p.X <= b[3] and p.Z >= b[2] and p.Z <= b[4] and p.Y + size.Y / 2 <= b[5] then return true end
		end
		return false
	end
	H.section("Terrain hills vs. buildings")
	H.check(#C.clearedTerrain >= 10, #C.clearedTerrain .. " areas are cleared of terrain")
	-- (trees, loose rocks and the crater on the mountain's slopes may sit in the hill too: they're scenery on it)
	local mountainFolder = C.MOUNTAIN.folder
	local function scenery(p) return p:IsDescendantOf(mountainFolder) and (p.Position.Y > 100 or not cleared(Vector3.new(p.Position.X, 0, p.Position.Z), Vector3.new(0, 0, 0))) end
	local buried, byGroup = 0, {}
	for _, p in ipairs(C.WORLD:GetDescendants()) do
		-- (the mountain's own rock blocks are meant to sit in the hill: they ARE the mountain)
		if p:IsA("BasePart") and p.CanCollide and p.Position.Y > 0.5 and p.Name ~= "MountainRock" then
			-- the part's lowest point a player can touch: 1 stud above the ground
			local probe = Vector3.new(p.Position.X, math.max(1, p.Position.Y - p.Size.Y / 2 + 1), p.Position.Z)
			if hillDepth(probe) > 1 and not cleared(p.Position, p.Size) and not scenery(p) then
				buried += 1
				local g = (p:GetFullName():match("^Workspace%.City%.([^%.]+)") or p:GetFullName()) .. (DEBUG_T and (" " .. p.Name .. "@" .. math.floor(p.Position.X) .. "," .. math.floor(p.Position.Y) .. "," .. math.floor(p.Position.Z)) or "")
				byGroup[g] = (byGroup[g] or 0) + 1
			end
		end
	end
	local list = {}
	for g, n in pairs(byGroup) do table.insert(list, g .. " ×" .. n) end
	table.sort(list)
	H.check(buried == 0, "no solid part can end up inside a terrain hill" .. (buried > 0 and (" (" .. buried .. "): " .. table.concat(list, ", ")) or ""))
	local MC = C.MOUNTAIN
	local key = {lever = MC.mainLever.Parent.Position, tunnelMouth = Vector3.new(300, 3, MC.tunnel.z1 + 2), chamber = Vector3.new(300, 3, -748),
		backExit = Vector3.new(MC.exit.x1 + 10, 3, (MC.exit.z0 + MC.exit.z1) / 2)}
	for k, st in pairs(MC.stations) do key["station " .. k] = st.pos end
	for _, s in ipairs(C.HEIST_SITES) do key["target " .. s.key] = s.pos + Vector3.new(0, 3, 0) end
	local bad = {}
	for name, p in pairs(key) do if not cleared(p, Vector3.new(1, 6, 1)) then table.insert(bad, name) end end
	table.sort(bad)
	H.check(#bad == 0, "the base (lever, tunnel, chamber, all 7 stations, back exit) and all 8 heist targets are in cleared ground" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
	-- the way in: a clear path from North Rd (z = -300) up the dirt road into the ravine
	local gap = false
	for z = -560, MC.tunnel.z1, -4 do
		local p = Vector3.new(300, 2, z)
		if hillDepth(p) > 0 and not cleared(p, Vector3.new(1, 8, 1)) then gap = true end
	end
	H.check(not gap, "the dirt road up to the drain is clear of terrain all the way")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
