-- ADMIN PANEL (v10): only built after the server says you're an admin ("adminHello"). Every button just ASKS the
-- server (GameServer > Admin), which checks your role again on every request. Dangerous tools come back with a
-- confirmation the server issued; nothing dangerous happens from one tap. Fly / noclip only work while the
-- server has switched them on for you.
return function(C)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RGB, V3 = Color3.fromRGB, Vector3.new
local new, label, button, card, header, clear, corner = C.new, C.label, C.button, C.card, C.header, C.clear, C.corner
local fmt, play, SND, act, R, U, gui, plr = C.fmt, C.play, C.SND, C.act, C.R, C.U, C.gui, C.plr
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local AP = {role = nil, state = nil, tab = "OVERVIEW", target = nil}
C.AdminPanel = AP
local TABS = {"OVERVIEW", "PLAYERS", "ECONOMY", "ITEMS", "BUSINESSES", "PROPERTIES", "VEHICLES", "EVENTS", "HEISTS", "TELEPORT", "MODERATION", "SERVER", "DEVELOPER"}

local m, built
local area, tabBar, resultL, targetL
local function adm(tool, args) act("adm", tool, args or {}) end
local function btn(parent, text, fn, color, w, order)
	local b = button({Size = UDim2.fromOffset(w or 150, 34), Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE, LayoutOrder = order}, parent)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		fn(b)
	end)
	return b
end
local function row(order, h)
	local f = new("Frame", {Size = UDim2.new(1, -8, 0, h or 38), BackgroundTransparency = 1, LayoutOrder = order}, area)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center}, f)
	return f
end
local function grid(order)
	local f = new("Frame", {Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order}, area)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(150, 34), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	return f
end
local function box(parent, placeholder, w, order)
	local t = new("TextBox", {Size = UDim2.fromOffset(w or 150, 34), BackgroundColor3 = RGB(18, 20, 30), TextColor3 = WHITE, PlaceholderText = placeholder, Text = "", Font = Enum.Font.GothamBold,
		TextSize = 13, ClearTextOnFocus = false, LayoutOrder = order}, parent)
	corner(t, 6)
	return t
end
local function line(text, order, color)
	return label({Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = 12, TextColor3 = color or WHITE, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order}, area)
end
local function num(t) return tonumber((string.gsub(t.Text, "[,%s%$]", ""))) end
local function needTarget()
	if not AP.target then U.toast("🛡️ Pick a player in the PLAYERS tab first.") return nil end
	return AP.target
end
local function targetName()
	if not AP.target or not AP.state then return "nobody" end
	for _, p in ipairs(AP.state.players) do if p.id == AP.target then return p.name end end
	return "nobody"
end
-- pick a value from a list
local function picker(order, list, cur, onPick, fmtItem)
	local g = grid(order)
	for i, it in ipairs(list) do
		local key = type(it) == "table" and it.key or it
		btn(g, fmtItem and fmtItem(it) or tostring(key), function() onPick(key) end, key == cur and GREEN or RGB(52, 58, 80), nil, i)
	end
	return g
end

local RENDER = {}
RENDER.OVERVIEW = function(s)
	local sv = s.server
	line("🛡️ You are: " .. string.upper(s.role) .. (sv.studio and "   (Studio test session)" or ""), 1, GOLD)
	line("Version " .. sv.version .. " • schema " .. sv.schema .. " • " .. sv.players .. " players • up " .. math.floor(sv.uptime / 60) .. " min • server " .. sv.jobId, 2, SUB)
	line("Blocked admin requests from non-admins this server: " .. sv.denied, 3, sv.denied > 0 and RGB(255, 170, 140) or SUB)
	header(area, "Recent admin actions", 4)
	for i, e in ipairs(s.log) do
		if i > 25 then break end
		line(os.date("!%H:%M", e.t) .. "  " .. e.admin .. " → " .. e.tool .. (e.target and (" • " .. e.target) or "") .. (e.detail and (" • " .. e.detail) or ""), 4 + i, e.tool == "DENIED" and RGB(255, 140, 140) or WHITE)
	end
end
RENDER.PLAYERS = function(s)
	line("Pick a player: the tools in the other tabs act on them. Selected: " .. targetName(), 0, GOLD)
	for i, p in ipairs(s.players) do
		local c = card(area, 46, i)
		label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -330, 0, 20), Text = p.name .. (p.role and ("  🛡️ " .. p.role) or "") .. (p.muted and "  🔇" or "") .. (p.frozen and "  🧊" or ""),
			TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, c)
		label({Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -330, 0, 18), Text = "$" .. fmt(p.cash) .. " • $" .. fmt(p.income) .. "/s • rep " .. fmt(p.rep), TextSize = 11, TextColor3 = SUB,
			TextXAlignment = Enum.TextXAlignment.Left}, c)
		local b = button({Position = UDim2.new(1, -320, 0.5, -15), Size = UDim2.fromOffset(90, 30), Text = AP.target == p.id and "✔ Selected" or "Select", TextSize = 12, BackgroundColor3 = AP.target == p.id and GREEN or BLUE}, c)
		b.MouseButton1Click:Connect(function() play(SND.click) AP.target = p.id AP.render() end)
		local v = button({Position = UDim2.new(1, -224, 0.5, -15), Size = UDim2.fromOffset(70, 30), Text = "View", TextSize = 12, BackgroundColor3 = PURPLE}, c)
		v.MouseButton1Click:Connect(function() play(SND.click) AP.target = p.id adm("inspect", {target = p.id}) end)
		local h = button({Position = UDim2.new(1, -148, 0.5, -15), Size = UDim2.fromOffset(66, 30), Text = "Heal", TextSize = 12, BackgroundColor3 = GREEN}, c)
		h.MouseButton1Click:Connect(function() play(SND.click) adm("heal", {target = p.id}) end)
		local r = button({Position = UDim2.new(1, -76, 0.5, -15), Size = UDim2.fromOffset(66, 30), Text = "Respawn", TextSize = 11, BackgroundColor3 = GRAY}, c)
		r.MouseButton1Click:Connect(function() play(SND.click) adm("respawn", {target = p.id}) end)
	end
end
RENDER.ECONOMY = function(s)
	line("Target: " .. targetName(), 0, GOLD)
	local r1 = row(1)
	local amt = box(r1, "Amount (e.g. 1000000)", 200, 1)
	btn(r1, "➕ Give cash", function() local t = needTarget() if t then adm("giveCash", {target = t, amount = num(amt)}) end end, GREEN, 120, 2)
	btn(r1, "➖ Remove cash", function() local t = needTarget() if t then adm("removeCash", {target = t, amount = num(amt)}) end end, RED, 120, 3)
	local r2 = row(2)
	local rep = box(r2, "Reputation", 200, 1)
	btn(r2, "⭐ Give rep", function() local t = needTarget() if t then adm("giveRep", {target = t, amount = num(rep)}) end end, GREEN, 120, 2)
	header(area, "City economy events", 3)
	picker(4, {"boom", "recession", "tourists", "investor"}, nil, function(k) adm("cityEvent", {key = k}) end)
end
RENDER.ITEMS = function(s)
	line("Target: " .. targetName() .. "  •  give furniture (goes into their storage) or arcade tickets", 0, GOLD)
	local r1 = row(1)
	local qty = box(r1, "Qty / tickets", 120, 1)
	btn(r1, "🎟️ Give tickets", function() local t = needTarget() if t then adm("giveTickets", {target = t, amount = num(qty)}) end end, PURPLE, 130, 2)
	picker(2, s.items, nil, function(k) local t = needTarget() if t then adm("giveItem", {target = t, key = k, amount = num(qty) or 1}) end end, function(it) return it.name end)
	header(area, "Remove an item from storage (asks to confirm)", 3)
	picker(4, s.items, nil, function(k) local t = needTarget() if t then adm("removeItem", {target = t, key = k}) end end, function(it) return "✖ " .. it.name end)
end
RENDER.BUSINESSES = function(s)
	line("Target: " .. targetName(), 0, GOLD)
	local r1 = row(1)
	local lvl = box(r1, "Level", 80, 1)
	btn(r1, "🔧 Fix problems + restock", function() local t = needTarget() if t then adm("fixAll", {target = t}) end end, GREEN, 200, 2)
	header(area, "Set a business level (up only)", 2)
	local list = {}
	for _, b in ipairs(C.catalog.businesses or {}) do table.insert(list, {key = b.key, name = (b.icon or "") .. " " .. (b.name or b.key)}) end
	if #list == 0 then for _, k in ipairs({"lemonade", "icecream", "bakery", "coffee", "pizza", "arcade", "tech", "factory"}) do table.insert(list, {key = k, name = k}) end end
	picker(3, list, nil, function(k) local t = needTarget() if t then adm("bizLevel", {target = t, key = k, amount = num(lvl)}) end end, function(it) return it.name end)
end
RENDER.PROPERTIES = function(s)
	line("Target: " .. targetName(), 0, GOLD)
	local r1 = row(1)
	local lvl = box(r1, "Level", 80, 1)
	btn(r1, "🏢 Set HQ floors (0-6)", function() local t = needTarget() if t then adm("hqLevel", {target = t, amount = num(lvl)}) end end, BLUE, 180, 2)
	btn(r1, "🏠 Set house tier (1-7)", function() local t = needTarget() if t then adm("homeLevel", {target = t, amount = num(lvl)}) end end, BLUE, 180, 3)
	header(area, "Enter their places (moderation; logged)", 2)
	picker(3, {"home", "hq1", "lemonade", "pizza", "arcade", "tech"}, nil, function(k) local t = needTarget() if t then adm("enterInterior", {target = t, key = k}) end end)
end
RENDER.VEHICLES = function(s)
	line("Target: " .. targetName(), 0, GOLD)
	header(area, "Give a car", 1)
	picker(2, s.cars, nil, function(k) local t = needTarget() if t then adm("giveCar", {target = t, key = k}) end end, function(it) return "🚗 " .. it.name end)
	header(area, "Take a car away (asks to confirm)", 3)
	picker(4, s.cars, nil, function(k) local t = needTarget() if t then adm("removeCar", {target = t, key = k}) end end, function(it) return "✖ " .. it.name end)
end
RENDER.EVENTS = function(s)
	header(area, "City events", 1)
	picker(2, s.events, nil, function(k) adm("cityEvent", {key = k}) end, function(e) return e.key end)
	header(area, "Mega events", 3)
	picker(4, s.megas, nil, function(k) adm("megaEvent", {key = k}) end, function(e) return e.text end)
	header(area, "Fun", 5)
	local g = grid(6)
	btn(g, "🏃 Customer rush", function() adm("rush") end, PURPLE, nil, 1)
	btn(g, "🌟 Influencer visit", function() adm("influencer") end, PURPLE, nil, 2)
	btn(g, "🎲 Rare event", function() adm("rareEvent") end, PURPLE, nil, 3)
	btn(g, "😂 Funny event", function() adm("funny") end, PURPLE, nil, 4)
	btn(g, "🎬 Grand opening cinematic", function() adm("cinematic", {key = "opening"}) end, PURPLE, nil, 5)
	btn(g, "🎬 Eviction cinematic", function() adm("cinematic", {key = "evict"}) end, PURPLE, nil, 6)
	local r = row(7)
	local post = box(r, "CityBuzz post", 320, 1)
	btn(r, "📢 Post", function() adm("buzz", {text = post.Text}) end, BLUE, 100, 2)
end
RENDER.HEISTS = function(s)
	line("Robbery testing. Target for bag tools: " .. targetName(), 0, GOLD)
	for i, h in ipairs(s.heists or {}) do
		local r = row(i, 38)
		label({Size = UDim2.fromOffset(250, 34), Text = h.name .. " — " .. h.status, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0}, r)
		btn(r, "▶ Open", function() adm("heistOpen", {key = h.key}) end, GREEN, 80, 1)
		btn(r, "■ End", function() adm("heistEnd", {key = h.key}) end, RED, 70, 2)
		btn(r, "📍 Go", function() adm("tpHeist", {key = h.key}) end, BLUE, 70, 3)
	end
	local g = grid(30)
	btn(g, "⛰️ Go: mountain HQ", function() adm("tpHeist", {key = "mountain"}) end, BLUE, nil, 1)
	btn(g, "⛰️ Go: outside the door", function() adm("tpHeist", {key = "mountainOutside"}) end, BLUE, nil, 2)
	btn(g, "🚪 Open secret door", function() adm("secretDoor", {key = "main", on = true}) end, PURPLE, nil, 3)
	btn(g, "🚪 Close secret door", function() adm("secretDoor", {key = "main", on = false}) end, GRAY, nil, 4)
	btn(g, "🎒 Give target a bag", function() local t = needTarget() if t then adm("giveBag", {target = t}) end end, PURPLE, nil, 5)
	btn(g, "💰 Fill target's bag", function() local t = needTarget() if t then adm("fillBag", {target = t}) end end, PURPLE, nil, 6)
	btn(g, "🚨 Test police alert", function() adm("policeAlert") end, BLUE, nil, 7)
	btn(g, "🧹 Clear police alerts", function() adm("clearAlerts") end, GRAY, nil, 8)
	btn(g, "♻️ Reset all robberies", function() adm("heistReset") end, RED, nil, 9)
end
RENDER.TELEPORT = function(s)
	line("Target: " .. targetName(), 0, GOLD)
	local r = row(1)
	btn(r, "➡ Go to target", function() local t = needTarget() if t then adm("gotoPlayer", {target = t}) end end, BLUE, 150, 1)
	btn(r, "⬅ Bring target", function() local t = needTarget() if t then adm("bring", {target = t}) end end, BLUE, 150, 2)
	header(area, "Places", 2)
	picker(3, s.places, nil, function(k) adm("place", {key = k}) end)
end
RENDER.MODERATION = function(s)
	line("Target: " .. targetName(), 0, GOLD)
	local r1 = row(1)
	btn(r1, "🧊 Freeze", function() local t = needTarget() if t then adm("freeze", {target = t, on = true}) end end, BLUE, 110, 1)
	btn(r1, "Unfreeze", function() local t = needTarget() if t then adm("freeze", {target = t, on = false}) end end, GRAY, 100, 2)
	btn(r1, "🔇 Mute", function() local t = needTarget() if t then adm("mute", {target = t, on = true}) end end, BLUE, 100, 3)
	btn(r1, "Unmute", function() local t = needTarget() if t then adm("mute", {target = t, on = false}) end end, GRAY, 100, 4)
	local r2 = row(2)
	local msg = box(r2, "Warning / kick reason", 320, 1)
	btn(r2, "⚠️ Warn", function() local t = needTarget() if t then adm("warn", {target = t, text = msg.Text}) end end, RGB(230, 150, 40), 90, 2)
	btn(r2, "👢 Kick", function() local t = needTarget() if t then adm("kick", {target = t, text = msg.Text}) end end, RED, 90, 3)
	line("Kicking asks for confirmation. Mutes last for this server only.", 3, SUB)
end
RENDER.SERVER = function(s)
	local r1 = row(1)
	local msg = box(r1, "Announcement to everyone", 360, 1)
	btn(r1, "📢 Announce", function() adm("announce", {text = msg.Text}) end, BLUE, 120, 2)
	header(area, "Time of day", 2)
	picker(3, {"6", "9", "12", "15", "18", "21", "0"}, nil, function(k) adm("time", {amount = tonumber(k)}) end, function(k) return k .. ":00" end)
end
RENDER.DEVELOPER = function(s)
	header(area, "Your tools (only work for admins)", 1)
	local g = grid(2)
	btn(g, plr:GetAttribute("AdminFly") and "🕊️ Fly: ON" or "🕊️ Fly: off", function() adm("fly", {on = not plr:GetAttribute("AdminFly")}) end, PURPLE, nil, 1)
	btn(g, plr:GetAttribute("AdminNoclip") and "👻 Noclip: ON" or "👻 Noclip: off", function() adm("noclip", {on = not plr:GetAttribute("AdminNoclip")}) end, PURPLE, nil, 2)
	btn(g, plr:GetAttribute("AdminInvisible") and "🫥 Invisible: ON" or "🫥 Invisible: off", function() adm("invisible", {on = not plr:GetAttribute("AdminInvisible")}) end, PURPLE, nil, 3)
	btn(g, "🧍 Spawn test NPC", function() adm("npc") end, PURPLE, nil, 4)
	btn(g, "🧹 Clear NPCs", function() adm("clearNpcs") end, GRAY, nil, 5)
	local r = row(3)
	local v = box(r, "Value", 90, 1)
	btn(r, "🏃 Walk speed", function() adm("speed", {amount = num(v)}) end, BLUE, 120, 2)
	btn(r, "🦘 Jump power", function() adm("jump", {amount = num(v)}) end, BLUE, 120, 3)
	header(area, "Admins" .. (s.role == "owner" and "" or "  (only owners can change this)"), 4)
	for i, e in ipairs(s.admins) do
		local c = card(area, 40, 4 + i)
		label({Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -140, 1, 0), Text = e.name .. "  (" .. e.id .. ")  • added by " .. e.by, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, c)
		if s.role == "owner" then
			local b = button({Position = UDim2.new(1, -120, 0.5, -14), Size = UDim2.fromOffset(110, 28), Text = "Remove", TextSize = 12, BackgroundColor3 = RED}, c)
			b.MouseButton1Click:Connect(function() play(SND.click) adm("removeAdmin", {target = e.id}) end)
		end
	end
	if #s.admins == 0 then line("No added admins (owners come from the server config).", 30, SUB) end
	if s.role == "owner" then
		local r2 = row(40)
		local name = box(r2, "Roblox username", 220, 1)
		btn(r2, "➕ Add admin", function() adm("addAdmin", {text = name.Text}) end, GREEN, 130, 2)
		line("The server looks the username up and stores the account's UserId in the admin list (not in player saves).", 41, SUB)
	end
end

local function build()
	if built then return end
	built = true
	m = modal("admin", "🛡️  ADMIN PANEL", 820, 600)
	tabBar = new("ScrollingFrame", {Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 40), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X}, m.frame)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabBar)
	AP.tabButtons = {}
	for i, t in ipairs(TABS) do
		local b = button({Size = UDim2.fromOffset(104, 32), Text = t, TextSize = 11, BackgroundColor3 = GRAY, LayoutOrder = i}, tabBar)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			AP.tab = t
			AP.render()
		end)
		AP.tabButtons[t] = b
	end
	resultL = label({Position = UDim2.new(0, 12, 1, -28), Size = UDim2.new(1, -24, 0, 22), Text = "", TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left}, m.frame)
	m.body.Position = UDim2.fromOffset(12, 96)
	m.body.Size = UDim2.new(1, -24, 1, -128)
	area = m.body
	AP.area = area
	do
		local asked = false
		m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
		m.update = function()
			if not asked then
				asked = true
				adm("state")
			end
		end
	end
	-- a small shield button on the screen (only admins ever get it)
	local fb = button({AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -220), Size = UDim2.fromOffset(46, 46), Text = "🛡️", TextSize = 24, BackgroundColor3 = RGB(60, 40, 90)}, gui)
	corner(fb, 23)
	fb.MouseButton1Click:Connect(function() play(SND.click) C.openModal("admin") end)
	fb.Name = "AdminButton"
	C.Layout.slot(fb, "left", 3, {size = UDim2.fromOffset(44, 44), onCompact = function(c) fb.TextSize = c and 20 or 24 end})   -- phone layout: the left edge column
	AP.floatButton = fb
end
function AP.render()
	if not (built and AP.state) then return end
	for t, b in pairs(AP.tabButtons) do b.BackgroundColor3 = t == AP.tab and PURPLE or GRAY end
	clear(area)
	local fn = RENDER[AP.tab]
	if fn then
		local ok, err = pcall(fn, AP.state)
		if not ok then warn("[CornerEmpire] admin panel: " .. tostring(err)) end
	end
end

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "adminHello" and type(a) == "table" then
		AP.role = a.role
		build()
		AP.floatButton.Visible = true
	elseif kind == "adminBye" then
		AP.role = nil
		if built then
			m.frame.Visible = false
			AP.floatButton.Visible = false
		end
	elseif kind == "adminState" and type(a) == "table" and built then
		AP.state = a
		AP.render()
	elseif kind == "adminResult" and type(a) == "table" and built then
		resultL.Text = (a.ok and "✅ " or "❌ ") .. tostring(a.tool) .. ": " .. tostring(a.text)
		resultL.TextColor3 = a.ok and GREEN or RGB(255, 150, 140)
		if a.tool == "inspect" and a.ok then U.splash("🔎 " .. targetName(), tostring(a.text), BLUE) end
	elseif kind == "adminConfirm" and type(a) == "table" and built then
		-- the server issued a one-time token for this dangerous action: ask, then send it back
		C.confirm("⚠️ Confirm: " .. tostring(a.text) .. "?", "Yes, do it", function() act("adm", "confirm", a.token) end)
	end
end)

-- ===== fly + noclip (only while the server has switched them on for you) =====
do
	local flyVel
	RunService.Heartbeat:Connect(function()
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum) then return end
		if plr:GetAttribute("AdminNoclip") then
			for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
		end
		if plr:GetAttribute("AdminFly") then
			if not flyVel then
				local att = root:FindFirstChild("AdminFlyAtt") or Instance.new("Attachment")
				att.Name = "AdminFlyAtt"
				att.Parent = root
				flyVel = Instance.new("LinearVelocity")
				flyVel.Attachment0 = att
				flyVel.MaxForce = 1e6
				flyVel.Parent = root
				hum.PlatformStand = true
			end
			local cam = Workspace.CurrentCamera
			local dir = hum.MoveDirection
			local up = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
			local look = cam and cam.CFrame.LookVector or V3(0, 0, -1)
			local v = dir * 60 + V3(0, up * 40 + (dir.Magnitude > 0 and look.Y * 40 or 0), 0)
			flyVel.VectorVelocity = v
		elseif flyVel then
			flyVel:Destroy()
			flyVel = nil
			hum.PlatformStand = false
		end
	end)
end
end
