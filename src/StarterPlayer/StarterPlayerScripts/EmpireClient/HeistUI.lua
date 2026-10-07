-- HEIST UI (v11): the 💰 HEISTS phone app, the bag HUD on a job ("RETURN TO MOUNTAIN HQ"), the security puzzles,
-- police alerts with an approximate search area, and hiding the [Arrest] prompt from anyone who isn't on duty.
-- Everything here only ASKS the server (GameServer > Heists); the server decides what happened.
-- Lifecycle: the app window asks for data once when it opens (see Menus.openModal); the HUD and puzzle panels are
-- built once and reused; temporary connections are kept in a list and disconnected when a puzzle closes.
return function(C)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RGB, V3 = Color3.fromRGB, Vector3.new
local new, label, button, card, header, clear, corner, stroke, panel = C.new, C.label, C.button, C.card, C.header, C.clear, C.corner, C.stroke, C.panel
local fmt, play, SND, act, R, U, gui, plr = C.fmt, C.play, C.SND, C.act, C.R, C.U, C.gui, C.plr
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local HU = {state = {active = false}, app = nil, tab = "jobs"}
C.HeistUI = HU

local function txt(parent, text, size, color, order, bold)
	return label({Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = size or 13, TextColor3 = color or WHITE, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, LayoutOrder = order}, parent)
end
local function btn(parent, text, color, order, fn, h)
	local b = button({Size = UDim2.new(1, -8, 0, h or 40), Text = text, TextSize = 14, TextWrapped = true, BackgroundColor3 = color or BLUE, LayoutOrder = order}, parent)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		fn(b)
	end)
	return b
end
local function mmss(s) s = math.max(0, math.floor(s or 0)) return string.format("%02d:%02d", math.floor(s / 60), s % 60) end

-- =====================================================================
-- THE APP
-- =====================================================================
local m = modal("heists", "💰  HEISTS", 600, 580)
if C.BusinessUI and C.BusinessUI.helpButton then C.BusinessUI.helpButton(m, "heists") end
local tabs = new("Frame", {Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1}, m.frame)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabs)
m.body.Position = UDim2.fromOffset(12, 92)
m.body.Size = UDim2.new(1, -24, 1, -104)
local TABS = {{"jobs", "📋 Jobs"}, {"job", "🎒 My job"}, {"crew", "🤝 Crew"}, {"gear", "🛠️ Gear"}, {"police", "🚓 Police"}}
local tabBtns = {}
for i, t in ipairs(TABS) do
	local b = button({Size = UDim2.new(1 / #TABS, -4, 1, 0), Text = t[2], TextSize = 12, BackgroundColor3 = GRAY, LayoutOrder = i}, tabs)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		HU.tab = t[1]
		HU.render()
	end)
	tabBtns[t[1]] = b
end
HU.window = m

local RENDER = {}
RENDER.jobs = function(a)
	local st = a.state
	if not st.discovered then
		txt(m.body, "⛰️ Jobs come from somewhere in the mountains north of the race track. Rumor has it there's a drain in a ravine... and a lever.", 14, GOLD, 0, true)
	elseif not st.tier then
		txt(m.body, "🔒 Heists unlock at " .. tostring(a.unlockTier) .. " reputation.", 14, RGB(255, 170, 140), 0, true)
	end
	for i, j in ipairs(a.jobs) do
		local c = card(m.body, 92, i, j.status == "OPEN" and RGB(30, 60, 40) or (j.status == "ALARM" and RGB(70, 30, 30) or nil))
		label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), Text = j.icon .. " " .. string.upper(j.name) .. "   " .. j.status .. (j.left and ("  " .. mmss(j.left)) or ""),
			TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = j.status == "OPEN" and GREEN or (j.status == "ALARM" and RED or WHITE)}, c)
		label({Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 18), Text = "Reward: $" .. fmt(j.low) .. "–$" .. fmt(j.high) .. "   •   Police alert: " .. j.alert,
			TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SUB}, c)
		label({Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 0, 18), Text = "Crew: " .. j.minP .. "–" .. j.maxP .. " players" .. (j.crew > 0 and ("  (" .. j.crew .. " on it)") or "") .. "   •   " .. j.area,
			TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SUB}, c)
		label({Position = UDim2.fromOffset(10, 68), Size = UDim2.new(1, -20, 0, 18), Text = j.cooldown > 0 and ("⏳ You can hit this one again in " .. mmss(j.cooldown)) or "RETURN TO THE MOUNTAIN AFTER LOOTING",
			TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = j.cooldown > 0 and RGB(255, 170, 140) or GOLD}, c)
	end
	txt(m.body, "Your record: " .. a.stats.done .. " jobs • $" .. fmt(a.stats.earned) .. " earned • best $" .. fmt(a.stats.best) .. " • " .. a.stats.failed .. " failed", 12, SUB, 50)
end
RENDER.job = function(a)
	local st = a.state
	if st.jailed then txt(m.body, "🚓 You're in a cell for " .. st.jailed .. " more seconds.", 16, BLUE, 0, true) return end
	if not st.active then
		txt(m.body, "You're not on a job. Pick an OPEN target in Jobs, drive there, and press Start robbery at the entrance.", 14, SUB, 0)
		return
	end
	txt(m.body, (st.icon or "") .. " " .. tostring(st.site) .. " — " .. string.upper(tostring(st.stage)), 18, GOLD, 1, true)
	txt(m.body, "🎒 BAG: $" .. fmt(st.bag) .. " / $" .. fmt(st.cap), 16, WHITE, 2, true)
	txt(m.body, "➡ " .. tostring(st.objective), 15, st.escaped and RGB(255, 170, 60) or WHITE, 3, true)
	if st.hot then txt(m.body, "🔥 The loot goes cold in " .. mmss(st.hot) .. ".", 13, RGB(255, 150, 120), 4) end
	txt(m.body, "Crew: " .. table.concat(st.crew or {}, ", "), 13, SUB, 5)
	btn(m.body, "🏳️ Abandon the job (lose the loot)", RED, 10, function()
		C.confirm("Walk away from this job? Any loot in your bag is lost.", "Abandon", function() act("hsAbandon") end)
	end)
end
RENDER.crew = function(a)
	if not a.state.active then txt(m.body, "Start a job first, then invite people here. A crew shares one target: the loot doesn't grow with more people, so bring friends because it's safer, not to multiply money.", 13, SUB, 0) return end
	txt(m.body, "Invite players in this server (they join at the target's entrance):", 13, SUB, 0)
	for i, p in ipairs(a.invite) do btn(m.body, "🤝 Invite " .. p.name, PURPLE, i, function() act("hsInvite", p.id) end, 36) end
	if #a.invite == 0 then txt(m.body, "Nobody free to invite right now.", 13, SUB, 1) end
end
RENDER.gear = function(a)
	txt(m.body, a.inBase and "You're in the hideout: you can buy upgrades here." or "Upgrades are bought inside the mountain hideout (Quartermaster / Base Upgrades).", 13, a.inBase and GREEN or SUB, 0)
	header(m.body, "🎒 Bags", 1)
	for i, b in ipairs(a.bags) do
		local can = a.inBase and not b.owned
		btn(m.body, b.name .. "  —  holds $" .. fmt(b.cap) .. (b.owned and "   ✔" or ("   $" .. fmt(b.cost))), b.owned and GREEN or (can and BLUE or GRAY), 1 + i, function()
			if can then act("hsBag", b.level) end
		end, 38)
	end
	header(m.body, "⛰️ Base", 20)
	for i, b in ipairs(a.base) do
		local can = a.inBase and not b.owned
		btn(m.body, b.name .. " — " .. b.perk .. (b.owned and "   ✔" or ("   $" .. fmt(b.cost))), b.owned and GREEN or (can and BLUE or GRAY), 20 + i, function()
			if can then act("hsBase", b.level) end
		end, 46)
	end
end
RENDER.police = function(a)
	local p = a.police
	btn(m.body, p.on and "🚓 ON DUTY — tap to go off duty" or "🚓 Go on police duty", p.on and BLUE or GRAY, 0, function() act("hsPolice", not p.on) end, 46)
	txt(m.body, "On duty you get robbery alerts and an approximate search area (never the exact spot). Hold [Arrest] next to a robber carrying loot. The city pays you; robbers lose only the loot.", 12, SUB, 1)
	if p.count then txt(m.body, "👮 Police on duty in this server: " .. p.count, 13, GOLD, 2, true) end
	header(m.body, "Alerts", 3)
	if #p.alerts == 0 then txt(m.body, p.on and "Quiet... for now." or "Go on duty to see alerts.", 13, SUB, 4) end
	for i, al in ipairs(p.alerts) do txt(m.body, "🚨 " .. al.icon .. " " .. al.text .. " — " .. al.area, 13, RGB(255, 140, 140), 4 + i, true) end
	txt(m.body, "Arrests: " .. a.stats.arrests .. " • earned $" .. fmt(a.stats.policeEarned), 12, SUB, 40)
end
function HU.render()
	for k, b in pairs(tabBtns) do b.BackgroundColor3 = k == HU.tab and PURPLE or GRAY end
	clear(m.body)
	if HU.app and RENDER[HU.tab] then RENDER[HU.tab](HU.app) end
end
do
	local asked = false
	m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
	m.update = function()
		if not asked then
			asked = true
			act("hsApp")
		end
	end
end

-- =====================================================================
-- THE BAG HUD
-- =====================================================================
local hud = panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 200), Size = UDim2.fromOffset(340, 64), BackgroundColor3 = RGB(30, 24, 20), Visible = false}, gui)
stroke(hud, GOLD, 2, 0.2)
local bagL = label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = GOLD}, hud)
local objL = label({Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 26), TextSize = 14, Font = Enum.Font.GothamBlack, TextWrapped = true}, hud)
HU.hud, HU.bagLabel, HU.objLabel = hud, bagL, objL
hud.Name = "HeistBagHUD"
C.Layout.slot(hud, "top", 5)   -- phone layout: the top notification stack
local function showState(st)
	HU.state = st
	hud.Visible = st.active == true
	if st.active then
		bagL.Text = "🎒 BAG: $" .. fmt(st.bag) .. " / $" .. fmt(st.cap)
		objL.Text = (st.escaped and "⛰️ " or "➡ ") .. tostring(st.objective) .. (st.hot and ("  (" .. mmss(st.hot) .. ")") or "")
		objL.TextColor3 = st.escaped and RGB(255, 170, 60) or WHITE
	end
	-- the route home only shows while you're carrying loot out
	if U.setBeamTarget then U.setBeamTarget("heist", st.active and st.home or nil) end
	if st.ended then U.toast(st.ended) end
end

-- =====================================================================
-- SECURITY PUZZLES
-- =====================================================================
local pz = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 380), BackgroundColor3 = RGB(18, 22, 32), Visible = false, ZIndex = 50}, gui)
stroke(pz, RGB(80, 220, 255), 2, 0.2)
new("UIScale", {}, pz)
local pzTitle = label({Size = UDim2.new(1, 0, 0, 40), TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = RGB(80, 220, 255), ZIndex = 51, Text = "🔐 SECURITY PANEL"}, pz)
local pzInfo = label({Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 40), TextSize = 14, TextWrapped = true, ZIndex = 51}, pz)
local pzArea = new("Frame", {Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 1, -140), BackgroundTransparency = 1, ZIndex = 51}, pz)
local pzClose = button({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(160, 38), Text = "Step away", TextSize = 14, BackgroundColor3 = GRAY, ZIndex = 52}, pz)
HU.puzzle = pz
local pzConns = {}
local function closePuzzle()
	for _, c in ipairs(pzConns) do c:Disconnect() end
	pzConns = {}
	clear(pzArea)
	pz.Visible = false
end
pzClose.MouseButton1Click:Connect(function() play(SND.click) closePuzzle() end)
-- sized to the screen when it opens (scaled as a whole: the keypad must keep its shape); a big window on phones
pz.Name = "HeistPuzzle"
C.Layout.window("heistPuzzle", pz, {fixed = true, close = closePuzzle})
local function openPuzzle(p)
	closePuzzle()
	pz.Visible = true
	HU.lastPuzzle = p
	if p.kind == "timing" then
		pzInfo.Text = "Hit NOW when the marker is in the green zone, " .. p.need .. " times in a row."
		local bar = new("Frame", {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = RGB(40, 44, 60), BorderSizePixel = 0, ZIndex = 52}, pzArea)
		corner(bar, 8)
		new("Frame", {Position = UDim2.fromScale(p.center - 0.09, 0), Size = UDim2.fromScale(0.18, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 53}, bar)
		local needle = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 54}, bar)
		local hits = label({Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 30), TextSize = 18, Font = Enum.Font.GothamBlack, ZIndex = 52, Text = "0 / " .. p.need}, pzArea)
		HU.hitsLabel = hits
		local t0 = os.clock()
		table.insert(pzConns, RunService.RenderStepped:Connect(function()
			needle.Position = UDim2.fromScale((math.sin((os.clock() - t0) * p.speed * 2) + 1) / 2, 0)
		end))
		local now = button({Position = UDim2.new(0.5, -110, 0, 110), Size = UDim2.fromOffset(220, 60), Text = "NOW!", TextSize = 24, BackgroundColor3 = RGB(80, 160, 255), ZIndex = 53}, pzArea)
		now.MouseButton1Click:Connect(function() act("hsSolve") end)
		table.insert(pzConns, UserInputService.InputBegan:Connect(function(input, gp)
			if not gp and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then act("hsSolve") end
		end))
		return
	end
	-- sequence puzzles: watch it, then repeat it
	pzInfo.Text = (p.kind == "wires" and "Watch the wire order, then connect them the same way." or (p.kind == "symbols" and "Memorize the symbols, then tap them in order." or "Memorize the code, then type it in.")) .. " (" .. p.seconds .. " s)"
	local show = label({Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 50), TextSize = 34, Font = Enum.Font.GothamBlack, ZIndex = 52, Text = table.concat(p.seq, "  ")}, pzArea)
	local entered = {}
	local typed = label({Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Font = Enum.Font.GothamBlack, ZIndex = 52, TextColor3 = GOLD, Text = ""}, pzArea)
	local pad = new("Frame", {Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 1, -90), BackgroundTransparency = 1, ZIndex = 52}, pzArea)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(84, 44), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, pad)
	HU.pad = pad
	for i, o in ipairs(p.options) do
		local b = button({Text = o, TextSize = 22, BackgroundColor3 = RGB(50, 56, 80), LayoutOrder = i, ZIndex = 53}, pad)
		b.MouseButton1Click:Connect(function()
			if show.Text ~= "" then return end
			play(SND.click)
			table.insert(entered, o)
			typed.Text = table.concat(entered, " ")
			if #entered >= #p.seq then act("hsSolve", entered) end
		end)
	end
	task.delay(2.6, function() if show.Parent then show.Text = "" end end)
end
HU.openPuzzle = openPuzzle

-- =====================================================================
-- POLICE: alerts + an approximate search area (a local marker only police see)
-- =====================================================================
local marker
local function setMarker(pos, radius)
	if marker then marker:Destroy() marker = nil end
	if not pos then return end
	marker = Instance.new("Part")
	marker.Name = "PoliceSearchArea"
	marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = V3(1, radius * 2, radius * 2)
	marker.CFrame = CFrame.new(pos.X, 1, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
	marker.Color = RGB(80, 140, 255)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.75
	marker.Parent = Workspace
	HU.marker = marker
end
local alertBar = panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 270), Size = UDim2.fromOffset(420, 46), BackgroundColor3 = RGB(20, 30, 70), Visible = false}, gui)
stroke(alertBar, RGB(80, 140, 255), 2, 0.2)
local alertL = label({Size = UDim2.fromScale(1, 1), TextSize = 15, Font = Enum.Font.GothamBlack, TextWrapped = true}, alertBar)
HU.alertBar, HU.alertLabel = alertBar, alertL
alertBar.Name = "PoliceAlertBar"
C.Layout.slot(alertBar, "top", 6)
local alertToken = 0
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "heist" and type(a) == "table" then
		showState(a)
	elseif kind == "heistAppData" and type(a) == "table" then
		HU.app = a
		if a.state then showState(a.state) end
		if m.frame.Visible then HU.render() end
	elseif kind == "heistApp" and type(a) == "table" then
		HU.tab = a.tab or HU.tab
		if not m.frame.Visible then C.openModal("heists", true) end
		HU.render()
	elseif kind == "heistPuzzle" and type(a) == "table" then
		openPuzzle(a)
	elseif kind == "heistPuzzleHit" and type(a) == "table" then
		if a.done then
			if a.ok then U.toast("🔓 Panel cracked!") else U.toast("❌ Wrong — try the panel again.") end
			closePuzzle()
		elseif HU.hitsLabel then
			HU.hitsLabel.Text = a.hits .. " / " .. a.need
			HU.hitsLabel.TextColor3 = a.ok and GREEN or RED
			if a.ok and a.hits >= a.need then closePuzzle() U.toast("🔓 Panel cracked!") end
		end
	elseif kind == "heistAlert" and type(a) == "table" then
		if a.clear then
			setMarker(nil)
			alertBar.Visible = false
			return
		end
		alertToken += 1
		local my = alertToken
		alertL.Text = "🚨 " .. tostring(a.icon) .. " " .. tostring(a.text)
		alertBar.Visible = true
		setMarker(a.pos, a.radius or 80)
		play(SND.event)
		task.delay(20, function() if my == alertToken then alertBar.Visible = false end end)
	end
end)
-- the [Arrest] prompt rides on every robber carrying loot; only police see it
task.spawn(function()
	while true do
		task.wait(0.5)
		local cop = plr:GetAttribute("Police") == true
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local pp = root and root:FindFirstChild("ArrestPrompt")
			if pp then pp.Enabled = cop and p ~= plr end
		end
		if not cop and marker then setMarker(nil) end
	end
end)
end
