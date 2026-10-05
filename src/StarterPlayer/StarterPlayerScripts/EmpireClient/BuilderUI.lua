-- BUILDER UI (v10): the furniture shop, the home builder (a top-down grid of your home: tap a cell to place,
-- move or pick up furniture), house styles and who may visit you. The server (GameServer > HomeBuilder)
-- validates every placement; this only shows the plan and asks.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local new, label, button, card, header, clear, corner, stroke = C.new, C.label, C.button, C.card, C.header, C.clear, C.corner, C.stroke
local fmt, play, SND, act, R, U = C.fmt, C.play, C.SND, C.act, C.R, C.U
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
local cat = C.catalog.furniture
if not (modal and cat) then return end
local BUI = C.BusinessUI or {}
local B = {state = nil, tab = "place", shopCat = cat.cats[1]}
C.BuilderUI = B
-- names for the house tiers
C.HOME_LEVELS_NAMES = {"Starter Home", "Expanded Home", "Luxury Home", "Modern Estate", "Mansion", "Mega Mansion", "Empire Estate"}
local ITEM = {}
for _, it in ipairs(cat.items) do ITEM[it.key] = it end

local function btn(parent, text, pos, size, color, fn, order)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE, LayoutOrder = order}, parent)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		fn(b)
	end)
	return b
end
local function txt(parent, text, pos, size, sizePx, color, bold, order)
	return label({Position = pos, Size = size, Text = text, TextSize = sizePx or 13, TextColor3 = color or WHITE, TextWrapped = true, LayoutOrder = order,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function row(parent, order, h)
	local f = new("Frame", {Size = UDim2.new(1, -8, 0, h or 36), BackgroundTransparency = 1, LayoutOrder = order}, parent)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	return f
end

-- =====================================================================
-- FURNITURE SHOP
-- =====================================================================
local shopM = modal("furniture", "🛋️  FURNITURE SHOP", 620, 560)
if BUI.helpButton then BUI.helpButton(shopM, "furniture") end
local function renderShop()
	clear(shopM.body)
	local st = B.state
	local level = st and st.level or 0
	local owned = {}
	for _, e in ipairs(st and st.inventory or {}) do owned[e.k] = e.n end
	local tabs = new("Frame", {Size = UDim2.new(1, -8, 0, 64), BackgroundTransparency = 1, LayoutOrder = 0}, shopM.body)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(112, 28), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabs)
	for i, c in ipairs(cat.cats) do
		local b = button({Text = c, TextSize = 11, BackgroundColor3 = c == B.shopCat and PURPLE or GRAY, LayoutOrder = i}, tabs)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			B.shopCat = c
			renderShop()
		end)
	end
	txt(shopM.body, "Bought furniture goes into your storage. Place it with 🔨 Build inside your home.", UDim2.new(), UDim2.new(1, -8, 0, 18), 11, SUB, false, 1)
	local n = 1
	for _, it in ipairs(cat.items) do
		if it.cat == B.shopCat then
			n += 1
			local c = card(shopM.body, 52, n)
			label({Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(40, 52), Text = it.icon, TextSize = 26}, c)
			txt(c, it.name .. (owned[it.key] and ("   (" .. owned[it.key] .. " in storage)") or ""), UDim2.fromOffset(50, 6), UDim2.new(1, -190, 0, 20), 14, WHITE, true)
			local locked = level < it.tier
			txt(c, it.w .. "×" .. it.d .. " cells  •  +" .. it.score .. " style" .. (locked and ("  •  🔒 needs " .. C.HOME_LEVELS_NAMES[it.tier]) or ""), UDim2.fromOffset(50, 28), UDim2.new(1, -190, 0, 20), 11, locked and RGB(255, 160, 140) or SUB)
			btn(c, "Buy $" .. fmt(it.cost), UDim2.new(1, -130, 0.5, -17), UDim2.fromOffset(120, 34), locked and GRAY or GREEN, function()
				if not locked then act("hbBuy", it.key, 1) end
			end)
		end
	end
end
B.renderShop = renderShop
do
	local asked = false
	shopM.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not shopM.frame.Visible then asked = false end end)
	shopM.update = function()
		if not asked then
			asked = true
			act("hbState")
			renderShop()
		end
	end
end

-- =====================================================================
-- HOME BUILDER
-- =====================================================================
local bM = modal("builder", "🔨  HOME BUILDER", 780, 580)
if BUI.helpButton then BUI.helpButton(bM, "builder") end
bM.body.Visible = false
local tabBar = new("Frame", {Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1}, bM.frame)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, tabBar)
local area = new("Frame", {Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 1, -100), BackgroundTransparency = 1}, bM.frame)
B.area = area
local TABS = {{"place", "🔨 Furniture"}, {"styles", "🎨 House style"}, {"visitors", "🔐 Visitors"}}
local tabBtns = {}
for i, t in ipairs(TABS) do
	tabBtns[t[1]] = btn(tabBar, t[2], UDim2.new(), UDim2.fromOffset(150, 32), GRAY, function()
		B.tab = t[1]
		B.render()
	end, i)
end
local sel = {inv = nil, item = nil, r = 0}   -- picked from storage / picked a placed item / rotation
B.sel = sel

local CELL = 30
local function renderPlace(st)
	local gw, gh = st.cols * CELL, st.rows * CELL
	local gridF = new("Frame", {Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(gw, gh), BackgroundColor3 = RGB(26, 28, 38), BorderSizePixel = 0}, area)
	corner(gridF, 6)
	B.grid = gridF
	txt(area, "🏠 " .. tostring(st.levelName) .. "  •  " .. #st.items .. " / " .. st.cap .. " items  •  interior score " .. st.score .. (st.inside and "" or "   (go inside your home to place things)"),
		UDim2.fromOffset(0, 2), UDim2.fromOffset(gw + 300, 20), 12, st.inside and GOLD or RGB(255, 170, 140), true)
	-- the door is at the bottom of the plan
	txt(area, "⬇ front door", UDim2.fromOffset(gw / 2 - 40, gh + 28), UDim2.fromOffset(120, 16), 11, SUB)
	local blocked = {}
	for _, b in ipairs(st.blocked) do blocked[b[1]] = b[2] end
	local occ = {}
	for _, it in ipairs(st.items) do
		local w, d = it.w, it.d
		if it.r % 2 == 1 then w, d = d, w end
		for cx = it.x, it.x + w - 1 do for cz = it.z, it.z + d - 1 do if not it.flat or not occ[cx .. "," .. cz] then occ[cx .. "," .. cz] = it end end end
	end
	B.cells = {}
	for cz = 1, st.rows do
		for cx = 1, st.cols do
			local k = cx .. "," .. cz
			local it = occ[k]
			local color = blocked[k] and RGB(70, 40, 44) or (it and (sel.item == it.i and RGB(255, 90, 170) or (it.flat and RGB(90, 70, 120) or RGB(70, 110, 170))) or RGB(44, 48, 64))
			local c = button({Position = UDim2.fromOffset((cx - 1) * CELL + 1, (cz - 1) * CELL + 1), Size = UDim2.fromOffset(CELL - 2, CELL - 2), BackgroundColor3 = color, AutoButtonColor = true,
				Text = (it and it.x == cx and it.z == cz) and it.icon or (blocked[k] == "door" and "🚪" or ""), TextSize = 16}, gridF)
			B.cells[k] = c
			c.MouseButton1Click:Connect(function()
				play(SND.click)
				if sel.inv then
					act("hbPlace", sel.inv, {cx, cz, sel.r})
				elseif sel.item and sel.moving then
					act("hbMove", sel.item, {cx, cz, sel.r})
					sel.moving = false
				elseif it then
					sel.item, sel.r, sel.moving = it.i, it.r, false
					B.render()
				else
					sel.item = nil
					B.render()
				end
			end)
		end
	end
	-- side panel: storage, or the selected item
	local side = new("ScrollingFrame", {Position = UDim2.fromOffset(gw + 12, 26), Size = UDim2.new(1, -(gw + 12), 1, -30), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, area)
	new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, side)
	B.side = side
	local picked
	for _, it in ipairs(st.items) do if it.i == sel.item then picked = it end end
	if picked then
		txt(side, picked.icon .. " " .. picked.name, UDim2.new(), UDim2.new(1, -4, 0, 22), 15, GOLD, true, 1)
		btn(side, sel.moving and "Tap a cell to move it…" or "✋ Move", UDim2.new(), UDim2.new(1, -4, 0, 34), sel.moving and PURPLE or BLUE, function()
			sel.moving = true
			B.render()
		end, 2)
		btn(side, "🔄 Rotate", UDim2.new(), UDim2.new(1, -4, 0, 34), BLUE, function()
			act("hbMove", picked.i, {picked.x, picked.z, (picked.r + 1) % 4})
		end, 3)
		btn(side, "📦 Pick up (back to storage)", UDim2.new(), UDim2.new(1, -4, 0, 34), RED, function()
			act("hbPick", picked.i)
			sel.item = nil
		end, 4)
		btn(side, "Done", UDim2.new(), UDim2.new(1, -4, 0, 30), GRAY, function()
			sel.item, sel.moving = nil, false
			B.render()
		end, 5)
		return
	end
	txt(side, sel.inv and ("Placing: " .. (ITEM[sel.inv] and ITEM[sel.inv].name or sel.inv) .. " — tap a cell") or "📦 Storage — pick an item, then tap the plan", UDim2.new(), UDim2.new(1, -4, 0, 34), 12, sel.inv and GOLD or SUB, true, 1)
	if sel.inv then
		btn(side, "🔄 Rotation: " .. (sel.r * 90) .. "°", UDim2.new(), UDim2.new(1, -4, 0, 30), BLUE, function()
			sel.r = (sel.r + 1) % 4
			B.render()
		end, 2)
		btn(side, "Cancel", UDim2.new(), UDim2.new(1, -4, 0, 30), GRAY, function()
			sel.inv = nil
			B.render()
		end, 3)
	end
	if #st.inventory == 0 then txt(side, "Storage is empty. Buy furniture in the shop.", UDim2.new(), UDim2.new(1, -4, 0, 34), 12, SUB, false, 10) end
	for i, e in ipairs(st.inventory) do
		local b = btn(side, e.icon .. " " .. e.name .. "  ×" .. e.n .. "  (" .. e.w .. "×" .. e.d .. ")", UDim2.new(), UDim2.new(1, -4, 0, 32), sel.inv == e.k and PURPLE or RGB(52, 58, 80), function()
			sel.inv = sel.inv ~= e.k and e.k or nil
			sel.item = nil
			B.render()
		end, 10 + i)
		b.TextXAlignment = Enum.TextXAlignment.Left
	end
	btn(side, "🛒 Furniture shop", UDim2.new(), UDim2.new(1, -4, 0, 34), GREEN, function() C.openModal("furniture", true) end, 999)
end
local KIND_NAMES = {layout = "🏠 Room layout", ceiling = "⬜ Ceiling", door = "🚪 Door", window = "🪟 Windows"}
local function renderStyles(st)
	local list = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, area)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, list)
	txt(list, st.inside and "Pick a style — a style you bought once is free to switch back to." or "Go inside your home to restyle it.", UDim2.new(), UDim2.new(1, -8, 0, 18), 12, st.inside and SUB or RGB(255, 170, 140), false, 0)
	local order = 1
	for _, kind in ipairs({"layout", "ceiling", "door", "window"}) do
		local s = st.styles[kind]
		header(list, KIND_NAMES[kind], order)
		order += 1
		local r = row(list, order, 58)
		order += 1
		for i, o in ipairs(s.list) do
			local locked = st.level < o.tier
			local cur = s.current == o.key
			local b = btn(r, o.icon .. " " .. o.name .. "\n" .. (cur and "✔ current" or (locked and ("🔒 " .. C.HOME_LEVELS_NAMES[o.tier]) or (o.owned and "owned" or ("$" .. fmt(o.cost))))),
				UDim2.new(), UDim2.fromOffset(176, 56), cur and GREEN or (locked and GRAY or BLUE), function()
					if cur or locked then return end
					if kind == "layout" then
						C.confirm("Switch to " .. o.name .. "?" .. (o.owned and "" or (" ($" .. fmt(o.cost) .. ")")) .. "\nFurniture that doesn't fit goes back into storage.", "Switch", function() act("hbStyle", kind, o.key) end)
					else
						act("hbStyle", kind, o.key)
					end
				end, i)
			b.TextSize = 11
		end
	end
end
local MODES = {{"public", "🌍 Public"}, {"friends", "👥 Friends"}, {"invite", "💌 Invite only"}, {"private", "🔒 Private"}}
local function renderVisitors(st)
	local list = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, area)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, list)
	txt(list, "Who may walk into your places. Visitors who aren't allowed any more are shown out.", UDim2.new(), UDim2.new(1, -8, 0, 18), 12, SUB, false, 0)
	local order = 1
	for _, kind in ipairs({{"house", "🏠 House"}, {"business", "🏪 Businesses"}, {"hq", "🏢 HQ"}}) do
		header(list, kind[2], order)
		local r = row(list, order + 1, 36)
		order += 2
		for i, mo in ipairs(MODES) do
			local cur = st.perms[kind[1]] == mo[1]
			btn(r, mo[2], UDim2.new(), UDim2.fromOffset(170, 34), cur and GREEN or GRAY, function()
				if not cur then act("perm", kind[1], mo[1]) end
			end, i)
		end
	end
	header(list, "💌 Invites (players in this server)", 50)
	local invited = {}
	for _, e in ipairs(st.perms.invites or {}) do invited[e.id] = true end
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= C.plr then
			n += 1
			local c = card(list, 40, 50 + n)
			txt(c, p.Name .. (invited[p.UserId] and "   ✔ invited" or ""), UDim2.fromOffset(12, 10), UDim2.new(1, -160, 0, 20), 13, invited[p.UserId] and GREEN or WHITE, true)
			btn(c, invited[p.UserId] and "Uninvite" or "Invite", UDim2.new(1, -130, 0.5, -15), UDim2.fromOffset(120, 30), invited[p.UserId] and RED or PURPLE, function()
				act("invite", p.UserId, not invited[p.UserId])
			end)
		end
	end
	if n == 0 then txt(list, "Nobody else is in this server right now.", UDim2.new(), UDim2.new(1, -8, 0, 18), 12, SUB, false, 51) end
end
function B.render()
	for k, b in pairs(tabBtns) do b.BackgroundColor3 = k == B.tab and PURPLE or GRAY end
	clear(area)
	local st = B.state
	if not st then return end
	if B.tab == "styles" then renderStyles(st)
	elseif B.tab == "visitors" then renderVisitors(st)
	else renderPlace(st) end
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "builder" and type(a) == "table" then
		B.state = a
		-- forget a selection that no longer exists
		if sel.inv then
			local still = false
			for _, e in ipairs(a.inventory) do if e.k == sel.inv then still = true end end
			if not still then sel.inv = nil end
		end
		if sel.item and not a.items[sel.item] then sel.item = nil end
		if bM.frame.Visible then B.render() end
		if shopM.frame.Visible then renderShop() end
	end
end)
function B.open(tab)
	B.tab = tab or B.tab
	act("hbState")
	C.openModal("builder", true)
	B.render()
end
-- the inside bar gets a Build button in your own home
local bar, barL = C.interiorBar, C.interiorBarLabel
if bar then
	local bb = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -212, 0.5, 0), Size = UDim2.fromOffset(96, 32), Text = "🔨 Build", TextSize = 13, BackgroundColor3 = RGB(230, 140, 40), Visible = false}, bar)
	bb.MouseButton1Click:Connect(function() play(SND.click) B.open("place") end)
	B.barButton = bb
	C.onState(function(s)
		local st = s.interior
		local show = st ~= nil and st.mine == true and st.key == "home"
		bb.Visible = show
		bar.Size = UDim2.fromOffset(show and 570 or 470, 44)
		if barL then barL.Size = UDim2.new(1, show and -320 or -220, 1, 0) end
	end)
end
end
