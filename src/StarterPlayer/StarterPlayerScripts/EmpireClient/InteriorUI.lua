-- INTERIOR UI: while you're inside a business or a home: a small bar (whose place, interior score, Leave) and,
-- in your own rooms, the Decorate panel: numbered spots for furniture and decorations, walls, floors and lighting.
-- Every change is a request; the server checks the price, the spot and the unlocks.
return function(C)
local Workspace = game:GetService("Workspace")
local RGB, V3 = Color3.fromRGB, Vector3.new
local new, tween, label, button, corner, stroke, clear, vlist = C.new, C.tween, C.label, C.button, C.corner, C.stroke, C.clear, C.vlist
local fmt, play, SND, act, gui, U = C.fmt, C.play, C.SND, C.act, C.gui, C.U
local GOLD, GREEN, GRAY, WHITE, SUB, CARD, BLUE = C.GOLD, C.GREEN, C.GRAY, C.WHITE, C.SUB, C.CARD, C.BLUE
local cat = C.catalog.interiors
if not cat then return end

local bar = C.panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 148), Size = UDim2.fromOffset(470, 44), BackgroundColor3 = RGB(36, 30, 50), Visible = false}, gui)
local barL = label({Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -220, 1, 0), TextSize = 13, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd}, bar)
local decoB = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.fromOffset(110, 32), Text = "🛋️ Decorate", TextSize = 13, BackgroundColor3 = RGB(200, 90, 160)}, bar)
local leaveB = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(84, 32), Text = "🚪 Leave", TextSize = 13, BackgroundColor3 = GRAY}, bar)
leaveB.MouseButton1Click:Connect(function() play(SND.click) act("leaveInterior") end)
C.interiorBar, C.interiorBarLabel = bar, barL   -- (BuilderUI adds its Build button here)

-- the decorate panel
local panel = C.panel({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(330, 470), BackgroundColor3 = RGB(28, 26, 40), Visible = false, ZIndex = 5}, gui)
new("UISizeConstraint", {MaxSize = Vector2.new(330, 470)}, panel)
label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -60, 0, 30), Text = "🛋️ DECORATE", TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, panel)
local closeB = button({Position = UDim2.new(1, -40, 0, 6), Size = UDim2.fromOffset(30, 26), Text = "✕", TextSize = 14, BackgroundColor3 = GRAY, ZIndex = 6}, panel)
local scoreL = label({Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 16), TextSize = 11, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, panel)
local tabRow = new("Frame", {Position = UDim2.fromOffset(8, 52), Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 1, ZIndex = 6}, panel)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, tabRow)
local list = new("ScrollingFrame", {Position = UDim2.fromOffset(8, 86), Size = UDim2.new(1, -16, 1, -94), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 6}, panel)
vlist(list, 5)
local tab = "spots"
local pickedSpot
local tabs = {}
local markers = {}

local function clearMarkers()
	for _, m in ipairs(markers) do m:Destroy() end
	markers = {}
end
-- numbered spot markers in the room (only on your screen, only while the panel is open)
local function showMarkers(st)
	clearMarkers()
	if not (panel.Visible and st and st.spots) then return end
	for i, sp in ipairs(st.spots) do
		local a = Instance.new("Part")
		a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
		a.Size = V3(0.5, 0.5, 0.5)
		a.CFrame = sp.at + V3(0, sp.place == "wall" and 8 or 3, 0)
		a.Parent = Workspace
		local bb = new("BillboardGui", {Size = UDim2.fromOffset(34, 34), AlwaysOnTop = true, MaxDistance = 80}, a)
		local f = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = i == pickedSpot and RGB(255, 90, 170) or (sp.item ~= "" and GREEN or RGB(60, 64, 84)), BorderSizePixel = 0}, bb)
		corner(f, 17)
		label({Size = UDim2.fromScale(1, 1), Text = tostring(i), TextScaled = true, Font = Enum.Font.GothamBlack}, f)
		table.insert(markers, a)
	end
end
local ITEM = {}
for _, it in ipairs(cat.items) do ITEM[it.key] = it end
local function allowed(it, st)
	if it.for_ == "any" then return true end
	if it.for_ == "home" then return st.key == "home" end
	if it.for_ == "biz" then return st.key ~= "home" end
	return it.for_ == st.key
end
local render
local function row(h, color)
	local f = new("Frame", {Size = UDim2.new(1, -6, 0, h), BackgroundColor3 = color or CARD, BorderSizePixel = 0, ZIndex = 6}, list)
	corner(f, 8)
	return f
end
local function choiceButton(parent, text, color, fn)
	local b = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(92, 26), Text = text, TextSize = 11, BackgroundColor3 = color, ZIndex = 7}, parent)
	b.MouseButton1Click:Connect(function() play(SND.click) fn() end)
	return b
end
render = function()
	local s = C.S
	local st = s and s.interior
	clear(list)
	if not (st and st.mine) then return end
	scoreL.Text = "Interior score " .. st.score .. "  •  " .. C.stars(st.stars) .. "  (happier customers & a better house sign)"
	for k, b in pairs(tabs) do b.BackgroundColor3 = k == tab and RGB(200, 90, 160) or RGB(60, 64, 84) end
	if tab == "spots" then
		if not pickedSpot then
			label({Size = UDim2.new(1, -6, 0, 30), Text = "Pick a numbered spot in the room:", TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, list)
			for i, sp in ipairs(st.spots) do
				local it = ITEM[sp.item]
				local r = row(34)
				label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -110, 1, 0), Text = "#" .. i .. "  " .. (sp.place == "wall" and "🧱 wall spot" or "⬛ floor spot") .. "  " ..
					(it and (it.icon .. " " .. it.name) or "(empty)"), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, r)
				choiceButton(r, "Choose", BLUE, function()
					pickedSpot = i
					render()
					showMarkers(st)
				end)
			end
		else
			local sp = st.spots[pickedSpot]
			local top = row(34, RGB(60, 30, 60))
			label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -110, 1, 0), Text = "Spot #" .. pickedSpot .. " (" .. sp.place .. ")", TextSize = 13, Font = Enum.Font.GothamBlack,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, top)
			choiceButton(top, "‹ All spots", GRAY, function()
				pickedSpot = nil
				render()
				showMarkers(st)
			end)
			if sp.item ~= "" then
				local r = row(34)
				label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -110, 1, 0), Text = "Remove " .. (ITEM[sp.item] and ITEM[sp.item].name or sp.item), TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, r)
				choiceButton(r, "Remove", C.RED, function() act("decor", "spot", pickedSpot, "none") end)
			end
			local lastCat
			for _, it in ipairs(cat.items) do
				if it.place == sp.place and allowed(it, st) then
					if it.cat ~= lastCat then
						lastCat = it.cat
						label({Size = UDim2.new(1, -6, 0, 18), Text = string.upper(it.cat), TextSize = 10, TextColor3 = SUB, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6}, list)
					end
					local locked = it.unlock and st.level and st.level < it.unlock
					local r = row(36)
					label({Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -110, 0, 18), Text = it.icon .. " " .. it.name .. (sp.item == it.key and "  ✅" or ""), TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, r)
					label({Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -110, 0, 14), Text = locked and ("🔒 business level " .. it.unlock) or ("+" .. it.score .. " score"), TextSize = 10,
						TextColor3 = locked and RGB(255, 150, 120) or GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, r)
					local can = not locked and (s.cash >= it.cost)
					choiceButton(r, it.cost > 0 and ("$" .. fmt(it.cost)) or "Free", can and GREEN or GRAY, function()
						if not locked then act("decor", "spot", pickedSpot, it.key) end
					end)
				end
			end
		end
	else
		local styles = tab == "wall" and cat.walls or (tab == "floor" and cat.floors or cat.lights)
		for _, sty in ipairs(styles) do
			local r = row(36)
			local current = st[tab] == sty.key
			label({Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -110, 0, 18), Text = sty.icon .. " " .. sty.name .. (current and "  ✅" or ""), TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, r)
			label({Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -110, 0, 14), Text = "+" .. sty.score .. " score", TextSize = 10, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7}, r)
			if not current then
				choiceButton(r, sty.cost > 0 and ("$" .. fmt(sty.cost)) or "Free", s.cash >= sty.cost and GREEN or GRAY, function() act("decor", tab, nil, sty.key) end)
			end
		end
	end
end
for _, t in ipairs({{"spots", "🛋️ Items"}, {"wall", "🧱 Walls"}, {"floor", "🪵 Floors"}, {"light", "💡 Lights"}}) do
	local b = button({Size = UDim2.fromOffset(74, 28), Text = t[2], TextSize = 11, BackgroundColor3 = RGB(60, 64, 84), ZIndex = 7}, tabRow)
	tabs[t[1]] = b
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		tab = t[1]
		render()
	end)
end
decoB.MouseButton1Click:Connect(function()
	play(SND.click)
	panel.Visible = not panel.Visible
	pickedSpot = nil
	render()
	showMarkers(C.S and C.S.interior)
end)
closeB.MouseButton1Click:Connect(function()
	play(SND.click)
	panel.Visible = false
	clearMarkers()
end)
local lastSig
C.onState(function(s)
	local st = s.interior
	bar.Visible = st ~= nil
	if not st then
		if panel.Visible then panel.Visible = false clearMarkers() end
		return
	end
	barL.Text = (st.key == "home" and "🏠 " or "🏪 ") .. st.owner .. "'s " .. st.name .. "   " .. C.stars(st.stars) .. "  score " .. st.score
	decoB.Visible = st.mine
	if panel.Visible then
		-- redraw when something changed (an item placed, a style picked, cash crossed a price)
		local sig = st.score .. tostring(st.wall) .. tostring(st.floor) .. tostring(st.light) .. math.floor(s.cash / 100)
		for _, sp in ipairs(st.spots or {}) do sig ..= sp.item end
		if sig ~= lastSig then
			lastSig = sig
			render()
			showMarkers(st)
		end
	end
end)
C.openDecorate = function()
	panel.Visible = true
	render()
	showMarkers(C.S and C.S.interior)
end
end
