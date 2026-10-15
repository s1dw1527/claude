-- COLLECTION UI (v18): the 📚 COLLECTION phone app (found treasures in full; the rest as "❓ ???" cards with only
-- their rarity color and where to look, plus the milestones), and the 🔮 NEXT TIME card in the notification stack
-- (what's coming: tomorrow's reward, the next city event, the next Bazaar restock). The server decides everything
-- (GameServer > Collection).
return function(C)
local RGB = Color3.fromRGB
local new, label, card, clear, stroke, corner, gradient, panel, button = C.new, C.label, C.card, C.clear, C.stroke, C.corner, C.gradient, C.panel, C.button
local play, SND, act, R, fmt, gui = C.play, C.SND, C.act, C.R, C.fmt, C.gui
local SUB, GOLD, GRAY = C.SUB, C.GOLD, C.GRAY
local Lay = C.Layout
local modal = C.makeModal
if not modal then return end
local CU = {info = nil}
C.CollectionUI = CU
local RAR = {common = RGB(170, 175, 190), uncommon = RGB(90, 200, 120), rare = RGB(70, 150, 255), epic = RGB(170, 90, 255), legendary = RGB(255, 185, 40), mythic = RGB(255, 80, 200)}

local m = modal("collection", "📚  COLLECTION", 560, 620)
local function render()
	local info = CU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local head = card(m.body, 64, 0, RGB(40, 50, 90))
	C.titleText(label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 26), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "📚 " .. info.found .. " / " .. info.total .. " FOUND"}, head))
	local fill = C.bar(head, UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 16), GOLD)
	fill.Size = UDim2.fromScale(info.total > 0 and info.found / info.total or 0, 1)
	-- milestones
	local ms = new("Frame", {Size = UDim2.new(1, -8, 0, 50), BackgroundTransparency = 1, LayoutOrder = 1}, m.body)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, ms)
	for _, mi in ipairs(info.milestones) do
		local kind = mi.claimed and "off" or (mi.done and "buy" or "off")
		local b = C.pill({Size = UDim2.new(1 / #info.milestones, -6, 1, 0), TextSize = 12, TextWrapped = true, LayoutOrder = mi.i,
			Text = mi.claimed and ("✔ " .. mi.name) or (mi.done and ("🎁 " .. mi.name .. "\nCLAIM") or ("🔒 " .. mi.need .. " found\n" .. mi.name))}, ms, kind)
		b.Name = "Milestone" .. mi.i
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			if mi.done and not mi.claimed then act("collectClaim", mi.i) end
		end)
	end
	-- the grid
	local grid = C.autoFrame(m.body, 2)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(120, 112), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	for i, it in ipairs(info.items) do
		local col = RAR[it.rarity] or GRAY
		local c = new("Frame", {Name = "Item_" .. i, BackgroundColor3 = it.found and C.shade(col, 0.45) or RGB(30, 30, 40), BorderSizePixel = 0, LayoutOrder = i}, grid)
		corner(c, 12)
		gradient(c, C.STYLE.gloss)
		stroke(c, it.found and col or C.STYLE.outline, it.found and 3 or 2, 0)
		label({Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 44), Text = it.found and it.icon or "❓", TextSize = 36}, c)
		local nm = C.titleText(label({Name = "ItemName", Position = UDim2.fromOffset(4, 54), Size = UDim2.new(1, -8, 0, 30), Text = it.found and it.name or "???", TextSize = 13,
			TextWrapped = true, TextScaled = true}, c))
		new("UITextSizeConstraint", {MaxTextSize = 14, MinTextSize = 9}, nm)
		label({Position = UDim2.fromOffset(4, 86), Size = UDim2.new(1, -8, 0, 20), Text = string.upper(it.rarity) .. (it.found and "" or ("  •  " .. it.where)), TextSize = 9,
			TextWrapped = true, TextColor3 = it.found and RGB(235, 235, 245) or SUB}, c)
	end
end
CU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("collectInfo")
	end
end

-- ===== 🔮 NEXT TIME card (once a session, in the notification stack; never full-screen) =====
local tc = panel({Position = UDim2.new(1, -12, 1, -480), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(300, 150), BackgroundColor3 = RGB(30, 22, 60), Visible = false}, gui)
stroke(tc, RGB(190, 120, 255), 3, 0)
tc.Name = "TeaserCard"
Lay.slot(tc, "top", 6.9)
C.titleText(label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = RGB(220, 190, 255),
	Text = "🔮 COMING UP NEXT"}, tc))
local lines = label({Name = "TeaserLines", Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 1, -64), TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Text = ""}, tc)
local okB = button({Name = "TeaserOk", Position = UDim2.new(0, 8, 1, -32), Size = UDim2.new(0.5, -12, 0, 26), Text = "Got it", TextSize = 12, BackgroundColor3 = RGB(110, 70, 200)}, tc)
local colB = button({Name = "TeaserCollection", Position = UDim2.new(0.5, 4, 1, -32), Size = UDim2.new(0.5, -12, 0, 26), Text = "📚 Collection", TextSize = 12, BackgroundColor3 = RGB(40, 110, 200)}, tc)
okB.MouseButton1Click:Connect(function() play(SND.click) tc.Visible = false end)
colB.MouseButton1Click:Connect(function()
	play(SND.click)
	tc.Visible = false
	C.openModal("collection", true)
end)
CU.card = tc
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "collection" and type(a) == "table" then
		CU.info = a
		if m.frame.Visible then render() end
	elseif kind == "teaser" and type(a) == "table" and type(a.lines) == "table" then
		local t = {}
		for _, l in ipairs(a.lines) do table.insert(t, tostring(l.icon) .. " " .. tostring(l.text)) end
		lines.Text = table.concat(t, "\n")
		tc.Visible = true
		play(SND.msg)
	elseif kind == "mainmenu" then
		tc.Visible = false
	end
end)
end
