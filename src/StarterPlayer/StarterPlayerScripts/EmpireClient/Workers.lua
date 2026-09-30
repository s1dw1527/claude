-- WORKERS: your hired staff, standing at their businesses in uniform and working.
-- The server publishes a roster on each plot folder (attribute "Workers"); this module draws it.
-- Everything here is client-only visuals: no physics, no collisions, capped count, frozen when far away.
return function(C)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local new, U = C.new, C.U
local camera = Workspace.CurrentCamera

local FOLDER = Instance.new("Folder")
FOLDER.Name = "Workers"
FOLDER.Parent = Workspace
local MAX_WORKERS = 48       -- 4 plots x 11 staff slots, with a little headroom
local ANIM_DIST = 240        -- beyond this a worker holds still (no per-frame work)
local TAG_DIST = 45          -- name tags only show up close
local WALK_SPEED = 4.2
local hidden = false         -- Settings > Crowds & traffic = OFF hides workers
local WHITE, DARK = RGB(250, 250, 250), RGB(35, 35, 40)

-- uniform per staff slot: shirt, pants, and optional apron / vest / hat / tool / work animation
local UNIFORMS = {
	lemonade = {shirt = RGB(255, 214, 60), pants = RGB(60, 70, 120), apron = WHITE, hat = "cap", hatColor = RGB(255, 190, 40), work = "stir"},
	icecream = {shirt = RGB(255, 170, 210), pants = RGB(240, 240, 250), apron = WHITE, hat = "paper", hatColor = WHITE, work = "stir"},
	bakery = {shirt = WHITE, pants = RGB(60, 60, 70), apron = RGB(235, 225, 205), hat = "chef", work = "knead"},
	coffee = {shirt = RGB(55, 62, 58), pants = RGB(35, 35, 40), apron = RGB(30, 110, 70), hat = "beanie", hatColor = RGB(120, 80, 55), work = "pour"},
	pizza = {shirt = RGB(230, 70, 50), pants = WHITE, apron = WHITE, hat = "chef", work = "knead"},
	arcade = {shirt = RGB(150, 80, 255), pants = RGB(30, 30, 40), hat = "cap", hatColor = RGB(255, 60, 180), work = "wave"},
	tech = {shirt = RGB(40, 44, 58), pants = RGB(60, 70, 120), hat = "headset", hatColor = RGB(90, 200, 255), work = "type", tool = "laptop"},
	factory = {shirt = RGB(90, 94, 102), pants = RGB(50, 60, 90), vest = RGB(255, 140, 30), hat = "hardhat", hatColor = RGB(255, 205, 40), work = "lift", tool = "box"},
	manager = {shirt = RGB(30, 36, 62), pants = RGB(30, 36, 62), tie = RGB(200, 40, 50), work = "clipboard", tool = "clipboard"},
	marketer = {shirt = RGB(255, 110, 200), pants = RGB(245, 245, 250), hat = "cap", hatColor = RGB(255, 200, 60), work = "wave", tool = "megaphone"},
	engineer = {shirt = RGB(60, 90, 140), pants = RGB(50, 50, 60), vest = RGB(255, 140, 30), hat = "hardhat", hatColor = RGB(255, 205, 40), work = "hammer", tool = "wrench"},
}
local SKIN = {RGB(255, 220, 180), RGB(235, 190, 150), RGB(190, 140, 100), RGB(125, 88, 62)}
local HAIR = {RGB(40, 30, 25), RGB(90, 60, 30), RGB(230, 200, 120), RGB(160, 60, 30), RGB(20, 20, 20)}

local function part(size, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = FOLDER
	return p
end

-- a stable pseudo-random number from a string (so a worker keeps the same look on every client)
local function hash(s)
	local h = 7
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end
	return h
end

local count = 0
local function build(e)
	local u = UNIFORMS[e.id] or UNIFORMS.manager
	local h = hash(e.name .. e.id)
	local w = {e = e, u = u, parts = {}, pos = V3(e.x, e.y, e.z), state = "work", timer = 1 + (h % 30) / 10, phase = (h % 100) / 10}
	local function add(key, size, color, mat, shape)
		local p = part(size, color, mat, shape)
		w[key] = p
		table.insert(w.parts, p)
		return p
	end
	add("torso", V3(2, 2, 1), u.shirt)
	add("head", V3(1.3, 1.3, 1.3), SKIN[h % #SKIN + 1], nil, Enum.PartType.Ball)
	add("hair", V3(1.35, 0.5, 1.35), HAIR[h % #HAIR + 1])
	add("la", V3(0.9, 2, 0.9), u.shirt)
	add("ra", V3(0.9, 2, 0.9), u.shirt)
	add("ll", V3(0.95, 2, 0.95), u.pants)
	add("rl", V3(0.95, 2, 0.95), u.pants)
	if u.apron then add("apron", V3(1.7, 1.9, 0.12), u.apron, Enum.Material.Fabric) end
	if u.vest then add("vest", V3(2.12, 1.5, 1.1), u.vest, Enum.Material.Neon) end
	if u.tie then add("tie", V3(0.3, 1.2, 0.1), u.tie) end
	if u.hat == "cap" then
		add("hat", V3(1.42, 0.4, 1.42), u.hatColor)
		add("brim", V3(1.2, 0.12, 0.8), u.hatColor)
	elseif u.hat == "chef" then
		add("hat", V3(1.3, 1.4, 1.3), WHITE, Enum.Material.Fabric)
	elseif u.hat == "paper" then
		add("hat", V3(1.4, 0.55, 0.9), u.hatColor, Enum.Material.Fabric)
	elseif u.hat == "beanie" then
		add("hat", V3(1.42, 0.55, 1.42), u.hatColor, Enum.Material.Fabric)
	elseif u.hat == "hardhat" then
		add("hat", V3(1.6, 0.8, 1.6), u.hatColor, nil, Enum.PartType.Ball)
		add("brim", V3(1.9, 0.12, 1.9), u.hatColor)
	elseif u.hat == "headset" then
		add("hat", V3(1.5, 0.18, 0.3), DARK)
		add("brim", V3(1.6, 0.5, 0.5), u.hatColor, Enum.Material.Neon)
	end
	if u.tool == "clipboard" then add("tool", V3(0.9, 1.2, 0.12), RGB(150, 105, 60))
	elseif u.tool == "megaphone" then add("tool", V3(0.7, 1.4, 0.7), RGB(255, 60, 60))
	elseif u.tool == "wrench" then add("tool", V3(0.25, 1.4, 0.25), RGB(180, 185, 195), Enum.Material.Metal)
	elseif u.tool == "laptop" then add("tool", V3(1.4, 0.1, 1), RGB(60, 64, 76), Enum.Material.Metal)
	elseif u.tool == "box" then add("tool", V3(1.3, 1.1, 1.1), RGB(170, 125, 75), Enum.Material.WoodPlanks) end
	-- name tag (only visible up close)
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(170, 38), StudsOffsetWorldSpace = V3(0, 2.2, 0), MaxDistance = TAG_DIST, LightInfluence = 0, AlwaysOnTop = false}, w.head)
	w.nameL = new("TextLabel", {Size = UDim2.new(1, 0, 0.55, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = WHITE, TextStrokeTransparency = 0.3}, bb)
	w.roleL = new("TextLabel", {Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, 0, 0.45, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = RGB(255, 215, 90), TextStrokeTransparency = 0.3}, bb)
	count += 1
	return w
end
local function label(w)
	local e = w.e
	w.nameL.Text = e.name
	w.roleL.Text = e.role .. "  " .. string.rep("★", math.clamp(math.floor((e.stars or 0) / 3 + 0.5), 1, 5))
end
local function destroy(w)
	for _, p in ipairs(w.parts) do p:Destroy() end
	w.parts = {}
	count -= 1
end

-- ===== pose: feet at cf, facing cf.LookVector =====
local function armCF(cf, side, pitch, roll)
	return cf * CF(side * 1.45, 3.9, 0) * CFrame.Angles(pitch, 0, roll or 0) * CF(0, -0.9, 0)
end
local function pose(w, cf, walking, t)
	local u = w.u
	local sw = walking and math.sin(t * 9) * 0.6 or 0
	local bob = 0
	local lp, rp, lr, rr = sw, -sw, 0, 0
	if not walking then
		local k = u.work
		if k == "stir" then
			lp, rp = -0.5, -1.15 + math.sin(t * 6) * 0.2
			rr = math.cos(t * 6) * 0.2
		elseif k == "knead" then
			lp, rp = -1.0 + math.sin(t * 8) * 0.3, -1.0 - math.sin(t * 8) * 0.3
		elseif k == "pour" then
			lp, rp = -0.4, -1.4 + math.sin(t * 2) * 0.15
			rr = -0.3
		elseif k == "type" then
			lp, rp = -1.2 + math.sin(t * 15) * 0.07, -1.2 - math.sin(t * 15) * 0.07
		elseif k == "wave" then
			lp, rp = 0, -2.9
			rr = math.sin(t * 5) * 0.45
		elseif k == "lift" then
			lp, rp = -1.3, -1.3
			bob = math.abs(math.sin(t * 2.2)) * 0.35
		elseif k == "clipboard" then
			lp, rp = -1.0, -0.8 + math.sin(t * 7) * 0.12
		elseif k == "hammer" then
			lp, rp = -0.6, -1.6 + math.sin(t * 9) * 0.6
		end
	end
	local body = cf * CF(0, -bob, 0)
	w.torso.CFrame = body * CF(0, 3, 0)
	w.head.CFrame = body * CF(0, 4.65, 0)
	w.hair.CFrame = body * CF(0, 5.2, 0.05)
	w.ll.CFrame = cf * CF(-0.5, 2, 0) * CFrame.Angles(sw, 0, 0) * CF(0, -1, 0)
	w.rl.CFrame = cf * CF(0.5, 2, 0) * CFrame.Angles(-sw, 0, 0) * CF(0, -1, 0)
	local la, ra = armCF(body, -1, lp, lr), armCF(body, 1, rp, rr)
	w.la.CFrame, w.ra.CFrame = la, ra
	if w.apron then w.apron.CFrame = body * CF(0, 2.55, -0.57) end
	if w.vest then w.vest.CFrame = body * CF(0, 3.25, 0) end
	if w.tie then w.tie.CFrame = body * CF(0, 3.3, -0.56) end
	local hat = u.hat
	if hat == "cap" then
		w.hat.CFrame = body * CF(0, 5.35, 0)
		w.brim.CFrame = body * CF(0, 5.2, -0.85)
	elseif hat == "chef" then
		w.hat.CFrame = body * CF(0, 5.9, 0)
	elseif hat == "paper" or hat == "beanie" then
		w.hat.CFrame = body * CF(0, 5.4, 0)
	elseif hat == "hardhat" then
		w.hat.CFrame = body * CF(0, 5.3, 0)
		w.brim.CFrame = body * CF(0, 5.12, 0)
	elseif hat == "headset" then
		w.hat.CFrame = body * CF(0, 5.35, 0)
		w.brim.CFrame = body * CF(0, 4.7, 0)
	end
	local tool = u.tool
	if tool == "clipboard" then w.tool.CFrame = la * CF(0.1, -0.9, -0.45) * CFrame.Angles(math.rad(70), 0, 0)
	elseif tool == "megaphone" then w.tool.CFrame = ra * CF(0, -1.2, -0.3) * CFrame.Angles(math.rad(90), 0, 0)
	elseif tool == "wrench" then w.tool.CFrame = ra * CF(0, -1.25, -0.2)
	elseif tool == "laptop" then w.tool.CFrame = body * CF(0, 2.3, -1.3)
	elseif tool == "box" then w.tool.CFrame = body * CF(0, 3.1 + bob, -1.35) end
end

-- ===== roster sync =====
local plots = {}   -- folder -> {workers = {id -> worker}}
local function areaCF(e) return CF(e.x, e.y, e.z) * CFrame.Angles(0, e.yaw or 0, 0) end
local function faceCF(pos, e)
	-- stand at pos, facing the customers (the area's local +Z)
	local fwd = (CFrame.Angles(0, e.yaw or 0, 0)):VectorToWorldSpace(V3(0, 0, 1))
	return CFrame.lookAt(pos, pos + fwd)
end
local function sync(folder)
	local st = plots[folder]
	local raw = folder:GetAttribute("Workers")
	local list = {}
	if type(raw) == "string" and raw ~= "" then
		local ok, res = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(res) == "table" then list = res end
	end
	local seen = {}
	for _, e in ipairs(list) do
		if type(e) == "table" and type(e.id) == "string" and type(e.name) == "string" and type(e.x) == "number" then
			seen[e.id] = true
			local w = st.workers[e.id]
			if w and w.e.name ~= e.name then
				-- someone new was hired for this slot
				destroy(w)
				st.workers[e.id] = nil
				w = nil
			end
			local fresh = false
			if not w and count < MAX_WORKERS then
				w = build(e)
				st.workers[e.id] = w
				fresh = true
			end
			if w then
				local moved = (V3(w.e.x, w.e.y, w.e.z) - V3(e.x, e.y, e.z)).Magnitude > 0.5
				w.e = e
				if moved or fresh then
					w.state, w.timer = "work", 1 + math.random() * 3
					w.pos = areaCF(e).Position
					pose(w, faceCF(w.pos, e), false, w.phase)
				end
				if fresh and hidden then
					for _, p in ipairs(w.parts) do p.Transparency = 1 end
				end
				label(w)
			end
		end
	end
	for id, w in pairs(st.workers) do
		if not seen[id] then
			destroy(w)
			st.workers[id] = nil
		end
	end
end
local function hook(folder)
	if plots[folder] then return end
	plots[folder] = {workers = {}}
	sync(folder)
	folder:GetAttributeChangedSignal("Workers"):Connect(function() sync(folder) end)
end
for _, f in ipairs(CollectionService:GetTagged("EmpirePlot")) do hook(f) end
CollectionService:GetInstanceAddedSignal("EmpirePlot"):Connect(hook)

-- hide workers when crowds are switched off (Settings > Crowds & traffic)
local function applyVisibility()
	hidden = C.settings.crowd == "off"
	for _, st in pairs(plots) do
		for _, w in pairs(st.workers) do
			for _, p in ipairs(w.parts) do p.Transparency = hidden and 1 or 0 end
		end
	end
end
local baseCrowd = U.applyCrowd
U.applyCrowd = function()
	if baseCrowd then baseCrowd() end
	applyVisibility()
end
C.workerCount = function() return count end

-- ===== behaviour: work at a spot for a few seconds, stroll to another spot, repeat =====
RunService.RenderStepped:Connect(function(dt)
	if hidden or count == 0 then return end
	local camPos = camera.CFrame.Position
	local t = os.clock()
	for _, st in pairs(plots) do
		for _, w in pairs(st.workers) do
			local e = w.e
			if (w.pos - camPos).Magnitude <= ANIM_DIST then
				local goal
				if e.fx then goal = V3(e.fx, e.fy or e.y, e.fz) end
				if w.state == "walk" then
					local tgt = goal or w.target
					local to = tgt - w.pos
					local flat = V3(to.X, 0, to.Z)
					if flat.Magnitude < 0.4 then
						w.state = "work"
						w.timer = 4 + math.random() * 5
						pose(w, faceCF(w.pos, e), false, t + w.phase)
					else
						local step = math.min(flat.Magnitude, WALK_SPEED * dt)
						w.pos += flat.Unit * step + V3(0, (tgt.Y - w.pos.Y) * math.min(1, dt * 5), 0)
						pose(w, CFrame.lookAt(w.pos, w.pos + flat), true, t + w.phase)
					end
				else
					w.timer -= dt
					if goal and (V3(goal.X, 0, goal.Z) - V3(w.pos.X, 0, w.pos.Z)).Magnitude > 0.6 then
						-- the engineer heads straight to a broken business
						w.state = "walk"
					elseif w.timer <= 0 and not goal then
						w.target = (areaCF(e) * CF((math.random() * 2 - 1) * e.ex, 0, (math.random() * 2 - 1) * e.ez)).Position
						w.state = "walk"
					end
					if w.state == "work" then pose(w, faceCF(w.pos, e), false, t + w.phase) end
				end
			end
		end
	end
end)
end
