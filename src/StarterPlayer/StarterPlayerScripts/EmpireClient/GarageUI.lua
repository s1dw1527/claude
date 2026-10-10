-- GARAGE UI (v10): "OWNED: 7 / 16" — every car with its class and stats; drive, equip, favorite, rename,
-- customize and sell. The server (GameServer > Garage) checks ownership, prices and names.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, header, clear, corner = C.new, C.label, C.button, C.card, C.header, C.clear, C.corner
local fmt, play, SND, act, R = C.fmt, C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local G = {info = nil}
C.GarageUI = G
local CLASS_COLOR = {Economy = RGB(120, 200, 120), Sports = RGB(255, 140, 40), Luxury = RGB(200, 160, 255), SUV = RGB(120, 170, 120), Truck = RGB(180, 140, 90),
	Supercar = RGB(255, 80, 80), Hypercar = RGB(255, 210, 70)}
local STATS = {{"speed", "Speed"}, {"accel", "Accel"}, {"handling", "Handling"}, {"braking", "Braking"}, {"grip", "Grip"}, {"drift", "Drift"}, {"nitro", "Nitro"}}

local function btn(parent, text, pos, size, color, fn, order)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE, LayoutOrder = order}, parent)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		fn(b)
	end)
	return b
end
local function txt(parent, text, pos, size, sizePx, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = sizePx or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end

local m = modal("garage", "🚗  MY GARAGE", 700, 600)
if C.BusinessUI and C.BusinessUI.helpButton then C.BusinessUI.helpButton(m, "garage") end
local function render()
	clear(m.body)
	local info = G.info
	if not info then return end
	local top = card(m.body, 56, 0, RGB(36, 40, 60))
	txt(top, "OWNED: " .. info.owned .. " / " .. info.total, UDim2.fromOffset(14, 14), UDim2.fromOffset(200, 30), 22, GOLD, true)
	btn(top, "📍 Corner Motors", UDim2.new(1, -330, 0.5, -18), UDim2.fromOffset(150, 36), BLUE, function() act("tp", "dealer") m.frame.Visible = false end)
	btn(top, "🅿 Put car away", UDim2.new(1, -170, 0.5, -18), UDim2.fromOffset(150, 36), GRAY, function() act("car", "despawn") end)
	txt(m.body, "Drive: WASD / arrows • Q or CTRL drift • SHIFT nitro (pass) • SPACE hop out • Controller Ⓧ drift, Ⓑ nitro • Phone: on-screen buttons",
		UDim2.new(), UDim2.new(1, -8, 0, 30), 11, SUB).LayoutOrder = 1
	for i, c in ipairs(info.cars) do
		local row = card(m.body, 104, 1 + i, if c.owned then nil else RGB(30, 30, 40))
		local sw = new("Frame", {Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = c.color, BorderSizePixel = 0}, row)
		corner(sw, 23)
		label({Size = UDim2.fromScale(1, 1), Text = c.delivery and "🚚" or (c.key == "moped" and "🛵" or "🚗"), TextSize = 24}, sw)
		txt(row, (c.fav and "⭐ " or "") .. c.name .. (c.name ~= c.model and ("  (" .. c.model .. ")") or "") .. (c.equipped and "  🔑" or ""), UDim2.fromOffset(62, 6), UDim2.new(1, -260, 0, 22), 16, c.owned and WHITE or SUB, true)
		local cl = label({Position = UDim2.fromOffset(62, 30), Size = UDim2.fromOffset(84, 18), Text = c.class, TextSize = 11, Font = Enum.Font.GothamBlack, BackgroundColor3 = CLASS_COLOR[c.class] or GRAY,
			TextColor3 = RGB(20, 20, 24)}, row)
		cl.BackgroundTransparency = 0.1   -- (C.label always makes labels see-through: the colored pill never showed, so the dark class name was invisible on the dark card)
		corner(cl, 6)
		local price = c.pass and "🎟️ Game Pass" or (c.rebirths and ("👑 " .. c.rebirths .. " rebirths") or ("$" .. fmt(c.price)))
		txt(row, c.speed .. " MPH  •  " .. price, UDim2.fromOffset(152, 31), UDim2.new(1, -350, 0, 18), 11, SUB)
		-- stat bars
		for k, st in ipairs(STATS) do
			local x = 62 + ((k - 1) % 4) * 112
			local y = 54 + math.floor((k - 1) / 4) * 22
			label({Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(52, 16), Text = st[2], TextSize = 10, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left}, row)
			local bg = new("Frame", {Position = UDim2.fromOffset(x + 52, y + 5), Size = UDim2.fromOffset(52, 7), BackgroundColor3 = RGB(50, 54, 70), BorderSizePixel = 0}, row)
			corner(bg, 3)
			local v = c.stats[st[1]] or 1
			local fill = new("Frame", {Size = UDim2.fromScale(v / 10, 1), BackgroundColor3 = v >= 8 and GOLD or (v >= 5 and GREEN or BLUE), BorderSizePixel = 0}, bg)
			corner(fill, 3)
		end
		-- actions
		if c.owned then
			btn(row, c.active and "🔄 Respawn" or "🔑 Drive", UDim2.new(1, -184, 0, 8), UDim2.fromOffset(84, 30), GREEN, function()
				act("car", "spawn", c.key)
				m.frame.Visible = false
			end)
			btn(row, c.equipped and "Main ride" or "Equip", UDim2.new(1, -94, 0, 8), UDim2.fromOffset(84, 30), c.equipped and GRAY or BLUE, function() act("carEquip", c.key) end)
			btn(row, c.fav and "★ Unfav" or "☆ Fav", UDim2.new(1, -184, 0, 40), UDim2.fromOffset(56, 26), PURPLE, function() act("carFav", c.key) end)
			btn(row, "✏️", UDim2.new(1, -124, 0, 40), UDim2.fromOffset(34, 26), BLUE, function() G.rename(c) end)
			btn(row, "🎨", UDim2.new(1, -86, 0, 40), UDim2.fromOffset(34, 26), RGB(230, 140, 40), function() G.customize(c) end)
			if c.sellFor then
				btn(row, "💰", UDim2.new(1, -48, 0, 40), UDim2.fromOffset(38, 26), RED, function()
					C.confirm("Sell your " .. c.name .. " for $" .. fmt(c.sellFor) .. "?\n(Half of the price. Its paint and parts go with it.)", "Sell", function() act("carSell", c.key, true) end)
				end)
			end
		elseif c.pass then
			btn(row, "🎫 Get pass", UDim2.new(1, -150, 0, 8), UDim2.fromOffset(140, 34), RGB(235, 170, 30), function() act("pass", c.pass) end).TextColor3 = RGB(35, 25, 5)
		elseif c.rebirths then
			btn(row, "👑 Rebirth " .. c.rebirths, UDim2.new(1, -150, 0, 8), UDim2.fromOffset(140, 34), GRAY, function() end)
		else
			btn(row, "Buy at Dealer\n$" .. fmt(c.price), UDim2.new(1, -150, 0, 8), UDim2.fromOffset(140, 40), (C.S and C.S.cash or 0) >= c.price and PURPLE or GRAY, function()
				act("tp", "dealer")
				m.frame.Visible = false
			end)
		end
	end
end
G.render = render
do
	local asked = false
	m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
	m.update = function()
		if not asked then
			asked = true
			act("garageInfo")
		end
	end
end

-- ===== rename =====
local nm = modal("carName", "✏️  NAME YOUR CAR", 440, 260)
local nmCar
local box = new("TextBox", {Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = RGB(18, 20, 30), TextColor3 = WHITE, PlaceholderText = "Car name", Text = "", Font = Enum.Font.GothamBlack,
	TextSize = 20, ClearTextOnFocus = false, LayoutOrder = 1}, nm.body)
corner(box, 8)
txt(nm.body, "2-20 characters, checked by Roblox's text filter. Leave it empty to reset.", UDim2.new(), UDim2.new(1, -8, 0, 30), 11, SUB).LayoutOrder = 2
btn(nm.body, "✔ Save", UDim2.new(), UDim2.new(1, -8, 0, 42), GREEN, function()
	if nmCar then act("carName", nmCar.key, box.Text) end
	nm.frame.Visible = false
	C.openModal("garage", true)
end, 3)
function G.rename(c)
	nmCar = c
	box.Text = c.name ~= c.model and c.name or ""
	C.openModal("carName", true)
end

-- ===== customize =====
local cm = modal("carCustom", "🎨  CUSTOMIZE", 640, 580)
if C.BusinessUI and C.BusinessUI.helpButton then C.BusinessUI.helpButton(cm, "carCustom") end
local cmCar
local KINDS = {{"paint", "🎨 Paint"}, {"wheels", "🛞 Wheels"}, {"tint", "🕶️ Window tint"}, {"interior", "💺 Interior"}, {"decal", "🏁 Decals"}, {"spoiler", "🪽 Spoiler"},
	{"bumper", "🛡️ Bumpers"}, {"exhaust", "💨 Exhaust"}}
local function renderCustom()
	clear(cm.body)
	local info, c = G.info, cmCar
	if not (info and c) then return end
	for _, car in ipairs(info.cars) do if car.key == c.key then c = car cmCar = car end end
	local mods = c.mods or {}
	txt(cm.body, c.name .. "  •  looks only: customizing never changes speed.", UDim2.new(), UDim2.new(1, -8, 0, 20), 13, GOLD, true).LayoutOrder = 0
	local order = 1
	for _, k in ipairs(KINDS) do
		header(cm.body, k[2] .. (mods[k[1]] and ("  —  " .. mods[k[1]]) or "  —  stock"), order)
		local rowF = new("Frame", {Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order + 1}, cm.body)
		new("UIGridLayout", {CellSize = UDim2.fromOffset(146, 40), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder}, rowF)
		order += 2
		btn(rowF, "Stock", UDim2.new(), UDim2.new(), mods[k[1]] == nil and GREEN or GRAY, function() act("carMod", c.key, k[1], "stock") end, 0)
		for i, o in ipairs(info.mods[k[1]] or {}) do
			local cur = mods[k[1]] == o.key
			local b = btn(rowF, o.name .. (cur and "\n✔" or (o.cost > 0 and ("\n$" .. fmt(o.cost)) or "")), UDim2.new(), UDim2.new(), cur and GREEN or (o.color or BLUE), function()
				if not cur then act("carMod", c.key, k[1], o.key) end
			end, i)
			if o.color then b.TextStrokeTransparency = 0.3 end
		end
	end
	header(cm.body, "🔤 License plate" .. (mods.plate and ("  —  " .. mods.plate) or ""), 90)
	local plate = new("TextBox", {Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = RGB(240, 240, 240), TextColor3 = RGB(20, 40, 120), PlaceholderText = "PLATE ($500, 7 max)",
		Text = mods.plate or "", Font = Enum.Font.GothamBlack, TextSize = 20, ClearTextOnFocus = false, LayoutOrder = 91}, cm.body)
	corner(plate, 6)
	btn(cm.body, "Save plate", UDim2.new(), UDim2.new(1, -8, 0, 36), GREEN, function() act("carMod", c.key, "plate", string.sub(plate.Text, 1, 7)) end, 92)
end
function G.customize(c)
	cmCar = c
	C.openModal("carCustom", true)
	renderCustom()
end
G.renderCustom = renderCustom

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "garage" and type(a) == "table" then
		G.info = a
		if m.frame.Visible then render() end
		if cm.frame.Visible then renderCustom() end
	end
end)
end
