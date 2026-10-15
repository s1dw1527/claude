-- BAZAAR UI (v17): the 🛍️ CITY BAZAAR phone app (also opened from the stall in the plaza). Six cards, one per
-- slot in this restock: the item, its rarity (colored), how many you can still buy and a green price pill, plus
-- a live countdown to the next restock. Everything is decided by the server (GameServer > Bazaar): the client only
-- shows what it was sent and asks to buy a slot (with the restock it was looking at, so a purchase never lands on
-- a different item after a restock).
return function(C)
local RGB = Color3.fromRGB
local new, label, card, clear, stroke, corner, gradient = C.new, C.label, C.card, C.clear, C.stroke, C.corner, C.gradient
local play, SND, act, R, fmt = C.play, C.SND, C.act, C.R, C.fmt
local SUB = C.SUB
local modal = C.makeModal
if not modal then return end
local BU = {info = nil, at = 0}
C.BazaarUI = BU

local m = modal("bazaar", "🛍️  CITY BAZAAR", 560, 600)
local function render()
	local info = BU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local head = card(m.body, 56, 0, RGB(70, 30, 70))
	head.Name = "BazaarHead"
	BU.timer = C.titleText(label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 26), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Text = ""}, head))
	BU.timer.Name = "BazaarTimer"
	label({Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 20), TextSize = 12, TextColor3 = RGB(230, 210, 240), TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Same stock in every server. Rare finds sell out: limits are per restock."}, head)
	for i, s in ipairs(info.slots) do
		local c = card(m.body, 84, i, RGB(48, 40, 78))
		c.Name = "Slot" .. i
		if s.rank >= 4 then stroke(c, s.color, 3, 0) end
		local chip = new("Frame", {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = C.shade(s.color, 0.7), BorderSizePixel = 0}, c)
		corner(chip, 14)
		gradient(chip, C.STYLE.gloss)
		stroke(chip, C.STYLE.outline, 2.5)
		label({Size = UDim2.fromScale(1, 1), Text = s.icon, TextSize = 38}, chip)
		C.titleText(label({Position = UDim2.fromOffset(86, 6), Size = UDim2.new(1, -230, 0, 24), Text = s.name, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, c))
		local tag = new("Frame", {Position = UDim2.fromOffset(86, 32), Size = UDim2.fromOffset(104, 20), BackgroundColor3 = C.shade(s.color, 0.55), BorderSizePixel = 0}, c)
		tag.Name = "Rarity"
		corner(tag, 999)
		stroke(tag, C.STYLE.outline, 1.5)
		label({Size = UDim2.fromScale(1, 1), Text = string.upper(s.rname), TextSize = 11, Font = C.STYLE.font}, tag)
		label({Position = UDim2.fromOffset(86, 54), Size = UDim2.new(1, -230, 0, 22), TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
			Text = (s.left > 0 and ("🛒 " .. s.left .. " of " .. s.qty .. " left for you") or "✔ You bought them all") .. "   •   ⭐ +" .. s.score .. " home"}, c)
		local afford = (info.cash or 0) >= s.price
		local kind = s.left <= 0 and "off" or (afford and "buy" or "off")
		local b = C.pill({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(124, 46), TextSize = 15,
			Text = s.left <= 0 and "SOLD OUT" or ("$" .. fmt(s.price))}, c, kind)
		b.Name = "Buy" .. i
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			if s.left > 0 then act("bazaarBuy", s.slot, info.win) end
		end)
	end
end
BU.render = render
local function tick()
	if not (BU.timer and BU.info) then return end
	local left = math.max(0, math.floor(BU.info.endsIn - (os.clock() - BU.at)))
	BU.timer.Text = "⏳ RESTOCK IN " .. C.clock(left)
	if left <= 0 and not BU.waiting then
		BU.waiting = true
		task.delay(1, function() BU.waiting = false act("bazaarInfo") end)
	end
end
task.spawn(function()
	while true do
		task.wait(1)
		if m.frame.Visible then tick() end
	end
end)
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("bazaarInfo")
	end
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "bazaar" and type(a) == "table" then
		BU.info, BU.at = a, os.clock()
		if m.frame.Visible then
			render()
			tick()
		end
	elseif kind == "bazaarPing" then
		if m.frame.Visible then act("bazaarInfo") end
	elseif kind == "openBazaar" then
		C.openModal("bazaar", true)
	end
end)
end
