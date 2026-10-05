-- MAP APP: a real city map in the phone. Roads and districts are drawn from the server's world data; markers show
-- your businesses, home, properties and land, other players' empires, attractions, the Mystery Lot, your delivery
-- and the tutorial objective. You are the arrow. Tap a marker (or a place in the list) to see what it is, whether
-- it's unlocked, and to Mark it (a beam guides you) or Go there.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RGB, V3 = Color3.fromRGB, Vector3.new
local new, tween, label, button, corner, stroke, clear, vlist = C.new, C.tween, C.label, C.button, C.corner, C.stroke, C.clear, C.vlist
local fmt, play, SND, act, U, plr = C.fmt, C.play, C.SND, C.act, C.U, C.plr
local GOLD, GREEN, GRAY, WHITE, SUB, CARD, RED = C.GOLD, C.GREEN, C.GRAY, C.WHITE, C.SUB, C.CARD, C.RED
local kit = C.phoneKit
local cat = C.catalog.map
if not (kit and cat) then return end

local view = kit.makeView("map")
kit.topBar(view, "🗺️ Map", RGB(40, 110, 200))
local B = cat.bounds   -- minX, minZ, maxX, maxZ
local W, H = 290, 250
local clip = new("Frame", {Position = UDim2.fromOffset(4, 44), Size = UDim2.fromOffset(W, H), BackgroundColor3 = RGB(70, 120, 70), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 22}, view)
corner(clip, 10)
local canvas = new("Frame", {Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 22}, clip)
local zoom = 1
-- world (x, z) -> pixels on the canvas at zoom 1 (north = -Z is up)
local function px(x, z)
	return (x - B[1]) / (B[3] - B[1]) * W, (z - B[2]) / (B[4] - B[2]) * H
end
-- water along the south shore, roads, and district tints
do
	local _, sy = px(0, 345)
	new("Frame", {Position = UDim2.fromOffset(0, sy), Size = UDim2.new(1, 0, 1, -sy), BackgroundColor3 = RGB(60, 130, 200), BorderSizePixel = 0, ZIndex = 22}, canvas)
	for _, r in ipairs(cat.roads) do
		local axis, c, a, b, w = r[1], r[2], r[3], r[4], r[5]
		local x1, y1, x2, y2
		if axis == "x" then
			x1, y1 = px(a, c - w / 2)
			x2, y2 = px(b, c + w / 2)
		else
			x1, y1 = px(c - w / 2, a)
			x2, y2 = px(c + w / 2, b)
		end
		new("Frame", {Position = UDim2.fromOffset(x1, y1), Size = UDim2.fromOffset(math.max(2, x2 - x1), math.max(2, y2 - y1)), BackgroundColor3 = RGB(60, 60, 66), BorderSizePixel = 0, ZIndex = 23}, canvas)
	end
end
local markers = {}
local placeOf = {}   -- marker key -> the place it shows (a Lua table: Instances can't hold custom fields)
local layer = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 25}, canvas)
local arrow = label({AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), Text = "▲", TextSize = 20, TextColor3 = RGB(255, 255, 255), TextStrokeTransparency = 0,
	Font = Enum.Font.GothamBlack, ZIndex = 40}, canvas)
-- info card
local info = C.panel({Position = UDim2.fromOffset(4, 44 + H + 4), Size = UDim2.fromOffset(W, 108), BackgroundColor3 = CARD, Visible = false, ZIndex = 26}, view)
local iTitle = label({Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -40, 0, 20), TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 27}, info)
local iKind = label({Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -16, 0, 14), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 27}, info)
local iDesc = label({Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 0, 30), TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 27}, info)
local iClose = button({Position = UDim2.new(1, -30, 0, 4), Size = UDim2.fromOffset(24, 22), Text = "✕", TextSize = 12, BackgroundColor3 = GRAY, ZIndex = 28}, info)
local iMark = button({Position = UDim2.new(0, 8, 1, -32), Size = UDim2.new(0.5, -12, 0, 26), Text = "📍 Mark", TextSize = 12, BackgroundColor3 = RGB(200, 70, 170), ZIndex = 28}, info)
local iGo = button({Position = UDim2.new(0.5, 4, 1, -32), Size = UDim2.new(0.5, -12, 0, 26), Text = "🚀 Go", TextSize = 12, BackgroundColor3 = RGB(50, 120, 220), ZIndex = 28}, info)
-- the list of places (also the easiest way to pick one with a controller)
local list = new("ScrollingFrame", {Position = UDim2.fromOffset(4, 44 + H + 4), Size = UDim2.new(1, -8, 1, -(44 + H + 8)), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22}, view)
vlist(list, 4)
local zin = button({Position = UDim2.new(0, W - 34, 0, 50), Size = UDim2.fromOffset(28, 26), Text = "+", TextSize = 18, BackgroundColor3 = GRAY, ZIndex = 30}, view)
local zout = button({Position = UDim2.new(0, W - 34, 0, 80), Size = UDim2.fromOffset(28, 26), Text = "−", TextSize = 18, BackgroundColor3 = GRAY, ZIndex = 30}, view)
local marked
local selected

local function locked(p)
	local s = C.S
	if not s then return false, "" end
	if p.need and (s.tier or 1) < p.need then return true, "🔒 Needs " .. (C.catalog.tiers[p.need] and C.catalog.tiers[p.need].name or "more reputation") end
	if p.feature and C.locked(p.feature) then return true, C.lockText(p.feature) end
	return false, "🔓 Unlocked"
end
local function select(p)
	selected = p
	info.Visible = true
	list.Visible = false
	iTitle.Text = (p.icon or "📍") .. " " .. p.name
	local isLocked, why = locked(p)
	iKind.Text = (p.kind or "") .. "  •  " .. why
	iKind.TextColor3 = isLocked and RGB(255, 150, 120) or RGB(140, 230, 160)
	iDesc.Text = p.desc or ""
	iGo.Visible = p.tp ~= nil
	iMark.Text = (marked == p.key) and "✖ Unmark" or "📍 Mark"
end
iClose.MouseButton1Click:Connect(function()
	play(SND.click)
	info.Visible = false
	list.Visible = true
	selected = nil
end)
iMark.MouseButton1Click:Connect(function()
	if not selected then return end
	play(SND.click)
	if marked == selected.key then
		marked = nil
		if U.setBeamTarget then U.setBeamTarget("map", nil) end
	else
		marked = selected.key
		if U.setBeamTarget then U.setBeamTarget("map", V3(selected.at[1], 1, selected.at[2])) end
		if U.toast then U.toast("📍 " .. selected.name .. " marked: follow the pink beam") end
	end
	select(selected)
end)
iGo.MouseButton1Click:Connect(function()
	if not (selected and selected.tp) then return end
	play(SND.click)
	act("tp", selected.tp)
	if C.togglePhone then C.togglePhone(false) end
end)

local function placeMarker(key, p, color)
	local m = markers[key]
	if not m then
		m = new("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = color, Text = p.icon or "•", TextSize = 13,
			AutoButtonColor = true, BorderSizePixel = 0, ZIndex = 30}, layer)
		corner(m, 11)
		stroke(m, WHITE, 1.5, 0.2)
		m.MouseButton1Click:Connect(function()
			play(SND.click)
			select(placeOf[key] or p)
		end)
		markers[key] = m
	end
	placeOf[key] = p
	local x, y = px(p.at[1], p.at[2])
	m.Position = UDim2.fromOffset(x * zoom, y * zoom)
	m.BackgroundColor3 = color
	return m
end
local live = {}
local function rebuild()
	-- static places + this player's things + other empires
	local all = {}
	for _, p in ipairs(cat.places) do table.insert(all, {key = "p_" .. p.key, p = p, color = RGB(50, 90, 160)}) end
	local mp = C.S and C.S.map
	if mp then
		table.insert(all, {key = "mine", p = {key = "business", name = "My Business", icon = "🏪", kind = "Your empire", at = mp.mine, tp = "business", desc = "Your corner: every business you own is here."}, color = RGB(60, 170, 90)})
		if mp.home then table.insert(all, {key = "home", p = {key = "home", name = "My Home", icon = "🏠", kind = "Your home", at = mp.home, tp = "home", desc = "Upgrade it from the Home app."}, color = RGB(60, 170, 90)}) end
		for i, pr in ipairs(mp.props or {}) do
			table.insert(all, {key = "prop" .. i, p = {key = "prop" .. i, name = pr.name, icon = "🏢", kind = "Your property", at = pr.at, tp = "rental", desc = "Manage it from the Properties app."}, color = RGB(60, 170, 90)})
		end
		for i, l in ipairs(mp.lots or {}) do
			table.insert(all, {key = "lot" .. i, p = {key = "lot" .. i, name = l.name .. " lot", icon = "📍", kind = "Your land", at = l.at, desc = "Land you own: it earns income and boosts businesses."}, color = RGB(60, 170, 90)})
		end
		for i, o in ipairs(mp.plots or {}) do
			table.insert(all, {key = "other" .. i, p = {key = "other" .. i, name = o.name .. "'s Empire", icon = "👤", kind = "Another player", at = o.at, desc = "Visit to see what they've built."}, color = RGB(200, 120, 60)})
		end
		if mp.mystery then table.insert(all, {key = "mystery", p = {key = "mystery", name = "Mystery Lot", icon = "❓", kind = "Event", at = mp.mystery, tp = "mystery", desc = "Nobody knows what's inside until someone buys it."}, color = RGB(170, 80, 220)}) end
		if mp.delivery then table.insert(all, {key = "delivery", p = {key = "delivery", name = "Delivery: " .. mp.delivery.name, icon = "📦", kind = "Your delivery", at = mp.delivery.at, desc = "Drive here to finish the delivery."}, color = RGB(80, 220, 120)}) end
		if mp.objective then table.insert(all, {key = "objective", p = {key = "objective", name = mp.objective.name, icon = "⭐", kind = "Objective", at = mp.objective.at, desc = "Follow the blue beam."}, color = RGB(90, 170, 255)}) end
	end
	local seen = {}
	for _, e in ipairs(all) do
		seen[e.key] = true
		local m = placeMarker(e.key, e.p, e.color)
		local isLocked = locked(e.p)
		m.BackgroundTransparency = isLocked and 0.5 or 0
	end
	for k, m in pairs(markers) do
		if not seen[k] then m:Destroy() markers[k], placeOf[k] = nil, nil end
	end
	live = all
end
local function renderList()
	clear(list)
	for i, e in ipairs(live) do
		local isLocked, why = locked(e.p)
		local b = button({Size = UDim2.new(1, -6, 0, 30), Text = (e.p.icon or "📍") .. "  " .. e.p.name .. (isLocked and "  🔒" or ""), TextSize = 12,
			BackgroundColor3 = isLocked and RGB(60, 60, 70) or e.color, LayoutOrder = i, ZIndex = 23}, list)
		b.TextXAlignment = Enum.TextXAlignment.Left
		new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, b)
		b.MouseButton1Click:Connect(function() play(SND.click) select(e.p) end)
	end
end
local function setZoom(z)
	zoom = z
	canvas.Size = UDim2.fromOffset(W * zoom, H * zoom)
	rebuild()
end
zin.MouseButton1Click:Connect(function() play(SND.click) setZoom(math.min(3, zoom + 1)) end)
zout.MouseButton1Click:Connect(function() play(SND.click) setZoom(math.max(1, zoom - 1)) end)
-- scale the drawn roads with the zoom (they were laid out at zoom 1)
local baseRects = {}
for _, f in ipairs(canvas:GetChildren()) do
	if f:IsA("Frame") and f ~= layer then table.insert(baseRects, {f = f, pos = f.Position, size = f.Size}) end
end
local function applyZoomToRects()
	for _, r in ipairs(baseRects) do
		r.f.Position = UDim2.new(r.pos.X.Scale, r.pos.X.Offset * zoom, r.pos.Y.Scale, r.pos.Y.Offset * zoom)
		r.f.Size = UDim2.new(r.size.X.Scale, r.size.X.Offset * zoom, r.size.Y.Scale, r.size.Y.Offset * zoom)
	end
end
local oldSet = setZoom
setZoom = function(z) oldSet(z) applyZoomToRects() end

kit.onOpen("map", function()
	rebuild()
	renderList()
	info.Visible = false
	list.Visible = true
end)
-- the arrow follows you (and the map scrolls to keep you in view when zoomed in)
task.spawn(function()
	while true do
		task.wait(0.15)
		if view.Visible then
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local x, y = px(root.Position.X, root.Position.Z)
				arrow.Position = UDim2.fromOffset(x * zoom, y * zoom)
				local look = root.CFrame.LookVector
				arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
				local ox = math.clamp(W / 2 - x * zoom, W - W * zoom, 0)
				local oy = math.clamp(H / 2 - y * zoom, H - H * zoom, 0)
				canvas.Position = UDim2.fromOffset(ox, oy)
			end
		end
	end
end)
C.onState(function(s)
	if view.Visible and s.map then rebuild() end
end)
C.openMap = function() if C.togglePhone then C.togglePhone(true) C.phoneView("map") end end
end
