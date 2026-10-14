-- LOT SHOP UI (v15): "open this business on a city plot", for businesses too big for the home plot (the 🎬 Movie
-- Theater, the 🎢 Amusement Park). Lists your plots ("Open it here") and every district with its price, or why you
-- can't buy there right now ("Buy a plot & open"). The server (GameServer > RealEstate: plotShop / plotOpenHere /
-- plotBuyFor) checks everything again; this only shows the choices.
return function(C)
local RGB = Color3.fromRGB
local label, button, card, clear, stroke = C.label, C.button, C.card, C.clear, C.stroke
local fmt, play, SND, act, R = C.fmt, C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local LS = {info = nil, key = nil}
C.LotShopUI = LS

local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, pos, size, color, fn, name)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	if name then b.Name = name end
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end

local m = modal("lotShop", "🏙️  CHOOSE A CITY PLOT", 560, 620)
local function render()
	local info = LS.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local o = 0
	local function nx() o += 1 return o end
	local top = card(m.body, 78, nx(), RGB(40, 36, 60))
	stroke(top, GOLD, 2, 0.4)
	txt(top, info.icon .. "  " .. string.upper(info.name), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22), 17, GOLD, true)
	local line = info.open and "Already open: move it to another plot of yours below." or ("Opening it costs $" .. fmt(info.cost) .. " (plus the plot if you buy one).")
	if not info.unlocked then line = "🔒 Unlocks at " .. info.need .. " reputation." end
	txt(top, line .. "   Properties: " .. info.used .. "/" .. info.capacity, UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 36), 12, info.unlocked and WHITE or RGB(255, 170, 150))
	-- your plots
	local h = card(m.body, 30, nx(), RGB(26, 28, 40))
	txt(h, "📍 YOUR PLOTS", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	if #info.plots == 0 then
		local c = card(m.body, 34, nx())
		txt(c, "You don't own a city plot yet: buy one below.", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 12, SUB)
	end
	for _, p in ipairs(info.plots) do
		local c = card(m.body, 52, nx(), p.here and RGB(36, 60, 44) or nil)
		txt(c, p.icon .. "  " .. p.district .. " plot", UDim2.fromOffset(12, 6), UDim2.new(1, -160, 0, 20), 14, WHITE, true)
		txt(c, p.here and ("✅ Your " .. info.name .. " is here") or (p.bizName and ("Runs: " .. p.bizName .. " (it moves off this plot)") or "Empty"), UDim2.fromOffset(12, 28), UDim2.new(1, -160, 0, 18), 11, SUB)
		if not p.here then
			btn(c, info.icon .. " Open it here", UDim2.new(1, -146, 0.5, -18), UDim2.fromOffset(136, 36), info.unlocked and GREEN or GRAY, function()
				if info.unlocked then act("plotOpenHere", p.id, info.key) end
			end, "OpenHere_" .. p.id)
		end
	end
	-- buy a plot
	if not info.siteId then
		local h2 = card(m.body, 30, nx(), RGB(26, 28, 40))
		txt(h2, "🛒 BUY A PLOT AND OPEN IT THERE", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
		for _, dd in ipairs(info.districts) do
			local c = card(m.body, 52, nx())
			txt(c, dd.icon .. "  " .. dd.name .. "  " .. string.rep("★", dd.stars or 0), UDim2.fromOffset(12, 6), UDim2.new(1, -160, 0, 20), 14, WHITE, true)
			txt(c, dd.why or ("Plot $" .. fmt(dd.price) .. "  •  total $" .. fmt(dd.total)), UDim2.fromOffset(12, 28), UDim2.new(1, -160, 0, 18), 11, dd.why and RGB(255, 170, 150) or SUB)
			local can = info.unlocked and not dd.why and info.cash >= dd.total
			btn(c, dd.why and "—" or ("Buy & open\n$" .. fmt(dd.total)), UDim2.new(1, -146, 0.5, -18), UDim2.fromOffset(136, 36), can and GREEN or GRAY, function()
				if can then act("plotBuyFor", dd.key, info.key) end
			end, "BuyFor_" .. dd.key)
		end
	end
end
LS.render = render
function C.openLotShop(key)
	LS.key = key
	C.openModal("lotShop", true)
	act("plotShop", key)
end
m.update = function() end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "plotShop" and type(a) == "table" then
		LS.info = a
		if m.frame.Visible then render() end
	elseif kind == "plotBizDone" and type(a) == "table" then
		if C.jingle then C.jingle("milestone", 0.4) end
		if m.frame.Visible and LS.key == a.key then m.frame.Visible = false end
	end
end)
end
