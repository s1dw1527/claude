-- EXPLORE UI (v13): the 🧭 EXPLORE phone app (City Jobs, Golden Corners, Places), the active-job card in the
-- notification stack, the guide beam to the next job stop, and the things only YOU see in the world: the Golden
-- Corners you haven't collected yet, the parcel, the lost dog (who follows you home) and the litter piles.
-- The server (GameServer > Explore) decides everything; this only draws it and asks to take or drop a job.
return function(C)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local new, label, button, card, header, clear, stroke, panel = C.new, C.label, C.button, C.card, C.header, C.clear, C.stroke, C.panel
local fmt, play, SND, act, R, U, gui, plr = C.fmt, C.play, C.SND, C.act, C.R, C.U, C.gui, C.plr
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local Lay = C.Layout
local modal = C.makeModal
if not modal then return end
local E = {tab = "jobs", info = nil, job = nil}
C.ExploreUI = E

local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, pos, size, color, fn)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 13, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end
local function clock(s)
	s = math.max(0, math.floor(s or 0))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- =====================================================================
-- THE APP
-- =====================================================================
local m = modal("explore", "🧭  EXPLORE", 560, 600)
if C.BusinessUI and C.BusinessUI.helpButton then C.BusinessUI.helpButton(m, "explore") end
local function render()
	local info = E.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local top = card(m.body, 66, 1, RGB(36, 40, 60))
	stroke(top, GOLD, 2, 0.4)
	txt(top, string.format("✨ %d / %d Golden Corners    📍 %d / %d places    💼 %d jobs done", info.corners, info.cornersTotal, info.placesFound, #info.places, info.jobsDone),
		UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22), 14, GOLD, true)
	txt(top, "Explore the city: City Jobs pay a slice of your income, Golden Corners and new places pay too.", UDim2.fromOffset(12, 34), UDim2.new(1, -24, 0, 28), 11, SUB)
	local tabs = card(m.body, 52, 2, RGB(26, 28, 40))
	for i, t in ipairs({{"jobs", "💼 City Jobs"}, {"corners", "✨ Corners"}, {"places", "📍 Places"}}) do
		btn(tabs, t[2], UDim2.new((i - 1) / 3, 3, 0, 5), UDim2.new(1 / 3, -6, 1, -10), E.tab == t[1] and PURPLE or GRAY, function()
			E.tab = t[1]
			render()
		end)
	end
	if E.tab == "jobs" then
		local j = info.jobs or {}
		if j.active then
			local a = j.active
			local c = card(m.body, 120, 10, RGB(30, 55, 40))
			stroke(c, GREEN, 2, 0.3)
			txt(c, a.icon .. "  " .. string.upper(a.name) .. (a.left and ("   ⏱ " .. clock(a.left)) or ""), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22), 16, GREEN, true)
			txt(c, a.text, UDim2.fromOffset(12, 34), UDim2.new(1, -150, 0, 70), 13, WHITE)
			btn(c, "Drop job", UDim2.new(1, -128, 1, -50), UDim2.fromOffset(116, 40), RED, function()
				C.confirm("Drop this job? (no reward)", "Drop", function() act("jobDrop") end)
			end)
		else
			if (j.cooldown or 0) > 0 then
				local c = card(m.body, 36, 9)
				txt(c, "⏳ Next job in " .. j.cooldown .. " s", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 13, SUB)
			end
			for i, o in ipairs(j.offers or {}) do
				local c = card(m.body, 104, 10 + i)
				txt(c, o.icon .. "  " .. o.name, UDim2.fromOffset(12, 8), UDim2.new(1, -150, 0, 22), 16, WHITE, true)
				txt(c, o.text, UDim2.fromOffset(12, 34), UDim2.new(1, -150, 0, 64), 12, SUB)
				btn(c, "Take job", UDim2.new(1, -128, 0.5, -20), UDim2.fromOffset(116, 40), GREEN, function() act("jobTake", o.i) end)
			end
		end
		local n = card(m.body, 40, 30, RGB(26, 28, 40))
		txt(n, "Jobs are done on foot or by car: a teleport cancels the job. Total earned from jobs: $" .. fmt(info.jobPay or 0), UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 11, SUB)
	elseif E.tab == "corners" then
		for i, z in ipairs(info.zones or {}) do
			local done = z.got >= z.total
			local c = card(m.body, done and 40 or 58, 10 + i, done and RGB(40, 50, 40) or nil)
			txt(c, z.icon .. "  " .. z.name .. "   " .. z.got .. " / " .. z.total .. (done and "  ✔" or ""), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 14, done and GREEN or WHITE, true)
			if not done and z.hint then txt(c, "💡 " .. z.hint, UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 24), 11, GOLD) end
		end
	else
		for i, p in ipairs(info.places or {}) do
			local c = card(m.body, 40, 10 + i, p.found and RGB(40, 50, 40) or nil)
			txt(c, (p.found and (p.icon .. "  " .. p.name) or ("❔  " .. p.name)) .. "   •   " .. p.kind .. (p.found and "  ✔" or "  (not visited yet)"),
				UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 20), 13, p.found and GREEN or SUB, p.found)
		end
	end
end
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("exploreInfo")
	end
end

-- =====================================================================
-- THE ACTIVE JOB: a card in the notification stack + the guide beam
-- =====================================================================
local jc = panel({Position = UDim2.new(1, -12, 1, -372), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(290, 100), BackgroundColor3 = RGB(25, 55, 45), Visible = false}, gui)
stroke(jc, GREEN, 2, 0)
jc.Name = "CityJobCard"
Lay.slot(jc, "top", 4)
local jt = label({Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextColor3 = RGB(150, 255, 190), TextXAlignment = Enum.TextXAlignment.Left}, jc)
local jd = label({Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 40), TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, jc)
local jo = button({Position = UDim2.new(0, 8, 1, -30), Size = UDim2.new(1, -16, 0, 24), Text = "🧭 Open Explore", TextSize = 12, BackgroundColor3 = RGB(40, 90, 70)}, jc)
jo.MouseButton1Click:Connect(function() play(SND.click) C.openModal("explore", true) end)
local function nearestTarget()
	local j = E.job
	if not (j and j.targets and #j.targets > 0) then return nil end
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local best, bd
	for _, t in ipairs(j.targets) do
		local p = V3(t[1], t[2], t[3])
		local d = root and (root.Position - p).Magnitude or 0
		if not bd or d < bd then best, bd = p, d end
	end
	return best, bd
end
local jobGotAt = 0
local function showJob()
	local j = E.job
	jc.Visible = j ~= nil
	if not j then
		if U.setBeamTarget then U.setBeamTarget("job", nil) end
		return
	end
	local left = j.left and math.max(0, j.left - (os.clock() - jobGotAt)) or nil
	jt.Text = j.icon .. " " .. string.upper(j.name) .. (left and ("  ⏱ " .. clock(left)) or "")
	local p, dist = nearestTarget()
	jd.Text = j.text .. (dist and ("  •  " .. math.floor(dist) .. " studs") or "")
	if U.setBeamTarget then U.setBeamTarget("job", p) end
end

-- =====================================================================
-- THE WORLD (client-only parts: what only you see)
-- =====================================================================
local FX = Instance.new("Folder")
FX.Name = "ExploreFX"
FX.Parent = Workspace
local function part(size, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = FX
	return p
end
-- Golden Corners: an L of gold bars with a glow, spinning slowly; drawn only when you're near and haven't found it
local tokens = {}
local cat = C.catalog.explore or {corners = {}}
for _, g in ipairs(cat.corners or {}) do
	local pos = V3(g.p[1], g.p[2], g.p[3])
	local a = part(V3(0.5, 0.5, 2.2), RGB(255, 210, 60), Enum.Material.Neon)
	local b = part(V3(2.2, 0.5, 0.5), RGB(255, 210, 60), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Range, glow.Brightness, glow.Color = 10, 1.5, RGB(255, 210, 80)
	glow.Parent = a
	a.Transparency, b.Transparency = 1, 1
	glow.Enabled = false
	tokens[g.id] = {pos = pos, a = a, b = b, glow = glow, left = true, on = false}
end
E.tokens = tokens
local function setToken(t, on)
	if t.on == on then return end
	t.on = on
	t.a.Transparency, t.b.Transparency = on and 0 or 1, on and 0 or 1
	t.glow.Enabled = on
end
-- job props: parcel + drop flag, the dog, litter piles
local parcel = part(V3(2, 1.6, 2), RGB(190, 140, 80), Enum.Material.Cardboard)
local flag = part(V3(0.3, 7, 0.3), RGB(240, 240, 240))
local flagCloth = part(V3(0.1, 1.6, 2.4), RGB(80, 220, 140), Enum.Material.Fabric)
local dog = {body = part(V3(1.1, 1.1, 2.4), RGB(200, 150, 90)), head = part(V3(1, 1, 1), RGB(200, 150, 90)), tail = part(V3(0.25, 0.25, 1), RGB(200, 150, 90))}
local litter = {}
for i = 1, 6 do litter[i] = part(V3(1.6, 1.4, 1.6), RGB(40, 40, 46), Enum.Material.Plastic, Enum.PartType.Ball) end
local function hideJobProps()
	for _, p in ipairs({parcel, flag, flagCloth, dog.body, dog.head, dog.tail}) do p.Transparency = 1 end
	for _, p in ipairs(litter) do p.Transparency = 1 end
end
hideJobProps()
local dogPos
local function drawJob(now)
	hideJobProps()
	local j = E.job
	if not j then dogPos = nil return end
	local ts = j.targets or {}
	if j.kind == "courier" or j.kind == "catering" then
		local p = ts[1] and V3(ts[1][1], ts[1][2], ts[1][3])
		if p and not j.carrying then
			parcel.Transparency = 0
			parcel.CFrame = CF(p + V3(0, 0.9 + math.sin(now * 3) * 0.15, 0)) * CFrame.Angles(0, now, 0)
		elseif p then
			flag.Transparency, flagCloth.Transparency = 0, 0
			flag.CFrame = CF(p + V3(0, 3.5, 0))
			flagCloth.CFrame = CF(p + V3(0, 6, 1.2)) * CFrame.Angles(0, math.sin(now * 2) * 0.2, 0)
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root then
				parcel.Transparency = 0
				parcel.CFrame = root.CFrame * CF(0, 1.5, -1.6)
			end
		end
	elseif j.kind == "pet" then
		local p = ts[1] and V3(ts[1][1], ts[1][2], ts[1][3])
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local at
		if j.carrying and root then
			-- the dog trots along behind you
			local goal = (root.CFrame * CF(2.5, 0, 3)).Position
			dogPos = dogPos and dogPos:Lerp(goal, 0.12) or goal
			at = CF(V3(dogPos.X, 0.85, dogPos.Z), V3(root.Position.X, 0.85, root.Position.Z))
		elseif p then
			at = CF(p + V3(0, 0.55, 0)) * CFrame.Angles(0, now * 0.6, 0)
		end
		if at then
			local hop = math.abs(math.sin(now * 8)) * 0.2
			dog.body.CFrame = at * CF(0, hop, 0)
			dog.head.CFrame = at * CF(0, 0.6 + hop, -1.5)
			dog.tail.CFrame = at * CF(0, 0.7 + hop, 1.4) * CFrame.Angles(0.6, math.sin(now * 14) * 0.6, 0)
			for _, x in pairs(dog) do x.Transparency = 0 end
		end
	elseif j.kind == "cleanup" then
		for i, t in ipairs(ts) do
			local l = litter[i]
			if l then
				l.Transparency = 0
				l.CFrame = CF(V3(t[1], t[2] + 0.7, t[3]))
			end
		end
	end
end

-- =====================================================================
-- EVENTS
-- =====================================================================
C.onState(function(s)
	local ex = s.explore
	if ex and ex.left then
		local left = {}
		for _, id in ipairs(ex.left) do left[id] = true end
		for id, t in pairs(tokens) do
			t.left = left[id] == true
			if not t.left then setToken(t, false) end
		end
	end
	showJob()
end)
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "explore" and type(a) == "table" then
		E.info = a
		E.job = a.jobs and a.jobs.active or nil
		jobGotAt = os.clock()
		if not m.frame.Visible then C.openModal("explore", true) end
		render()
		showJob()
	elseif kind == "cityJobs" and type(a) == "table" then
		E.job = a.active
		jobGotAt = os.clock()
		if E.info then
			E.info.jobs = a
			if m.frame.Visible then render() end
		end
		showJob()
	elseif kind == "cityCorner" and type(a) == "table" then
		local t = tokens[a.id]
		if t then
			t.left = false
			setToken(t, false)
		end
		play(SND.cash or SND.click)
	end
end)
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	acc += dt
	if acc >= 0.5 then
		acc = 0
		local cam = Workspace.CurrentCamera.CFrame.Position
		for _, t in pairs(tokens) do setToken(t, t.left and (t.pos - cam).Magnitude < 140) end
		showJob()
	end
	for _, t in pairs(tokens) do
		if t.on then
			local cf = CF(t.pos + V3(0, math.sin(now * 2) * 0.25, 0)) * CFrame.Angles(0, now * 1.5, 0)
			t.a.CFrame = cf * CF(-0.85, 0, 0)
			t.b.CFrame = cf * CF(0, 0, 0.85)
		end
	end
	drawJob(now)
end)
end
