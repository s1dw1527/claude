-- HOME LIFE UI (v14): the 🎉 HOME & PARTY phone app: parties going on now (Join), throwing your own party (at
-- your house/mansion or your loft), the City Loft (lease / move up / go inside), and the three ways to live side by
-- side (loft, house, mansion). Plus the "party!" card in the notification stack when someone starts one.
-- The server (GameServer > HomeLife) decides everything.
return function(C)
local RGB = Color3.fromRGB
local label, button, card, clear, stroke, panel = C.label, C.button, C.card, C.clear, C.stroke, C.panel
local fmt, play, SND, act, R, gui, plr = C.fmt, C.play, C.SND, C.act, C.R, C.gui, C.plr
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local Lay = C.Layout
local modal = C.makeModal
if not modal then return end
local HU = {info = nil, live = {}}   -- live[uid] = {host, venue, place, ends}
C.HomeLifeUI = HU
-- is there a party in this room? (the music director asks)
function C.partyAt(ownerUid, venue)
	local p = ownerUid and HU.live[ownerUid]
	return p ~= nil and p.venue == venue
end

local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, pos, size, color, fn, name)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 13, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	if name then b.Name = name end
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end
local function clock(s)
	s = math.max(0, math.floor(s or 0))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local m = modal("party", "🎉  HOME & PARTY", 560, 640)
local function render()
	local info = HU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local o = 0
	local function nx() o += 1 return o end
	-- parties now
	local h = card(m.body, 30, nx(), RGB(60, 26, 60))
	txt(h, "🎉 PARTIES RIGHT NOW", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, RGB(255, 150, 230), true)
	if #info.parties == 0 then
		local c = card(m.body, 34, nx())
		txt(c, "No parties right now. Throw one!", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 12, SUB)
	end
	for _, p in ipairs(info.parties) do
		local c = card(m.body, 52, nx())
		txt(c, "🎉 " .. p.host .. "'s " .. p.place, UDim2.fromOffset(12, 6), UDim2.new(1, -140, 0, 20), 14, WHITE, true)
		txt(c, p.here .. "/" .. p.cap .. " guests  •  " .. clock(p.left) .. " left", UDim2.fromOffset(12, 28), UDim2.new(1, -140, 0, 18), 11, SUB)
		btn(c, "Join", UDim2.new(1, -120, 0.5, -18), UDim2.fromOffset(108, 36), PURPLE, function() act("partyJoin", p.uid) C.closeModals() end, "PartyJoin_" .. p.uid)
	end
	-- your party
	local h2 = card(m.body, 30, nx(), RGB(26, 28, 40))
	txt(h2, "🥳 THROW A PARTY   (" .. info.hosted .. " thrown, " .. info.guests .. " guests, best " .. info.best .. ")", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 12, GOLD, true)
	if info.mine then
		local c = card(m.body, 56, nx(), RGB(60, 26, 60))
		txt(c, "🎉 Your party is on: " .. info.mine.n .. " guests, +" .. info.mine.rep .. " rep, " .. clock(info.mine.left) .. " left", UDim2.fromOffset(12, 8), UDim2.new(1, -140, 0, 40), 13, WHITE, true)
		btn(c, "End it", UDim2.new(1, -120, 0.5, -18), UDim2.fromOffset(108, 36), RED, function() act("partyEnd") end, "PartyEnd")
	elseif #info.venues == 0 then
		local c = card(m.body, 40, nx())
		txt(c, "You need a place first: build a house (🏠 Home app) or lease a City Loft below.", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 12, SUB)
	else
		for _, v in ipairs(info.venues) do
			local c = card(m.body, 52, nx())
			txt(c, (v.key == "loft" and "🏢 " or "🏠 ") .. "At your " .. v.name, UDim2.fromOffset(12, 6), UDim2.new(1, -150, 0, 20), 14, WHITE, true)
			txt(c, "up to " .. v.cap .. " guests  •  4 minutes" .. (v.key == "loft" and "  •  🌃 +50% favors" or ""), UDim2.fromOffset(12, 28), UDim2.new(1, -150, 0, 18), 11, SUB)
			if info.cooldown > 0 then
				txt(c, "⏳ " .. math.ceil(info.cooldown / 60) .. " min", UDim2.new(1, -130, 0.5, -9), UDim2.fromOffset(118, 20), 13, SUB, true)
			else
				btn(c, "🎉 Start party", UDim2.new(1, -140, 0.5, -18), UDim2.fromOffset(128, 36), GREEN, function() act("partyStart", v.key) C.closeModals() end, "PartyStart_" .. v.key)
			end
		end
	end
	-- the loft
	local h3 = card(m.body, 30, nx(), RGB(26, 28, 40))
	txt(h3, "🏢 YOUR CITY LOFT (Skyline Lofts, downtown)", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	local lc = card(m.body, 56, nx())
	txt(lc, info.loftName and ("🏢 " .. info.loftName) or "No loft yet", UDim2.fromOffset(12, 8), UDim2.new(1, -290, 0, 20), 14, WHITE, true)
	if info.loftNext then
		local n = info.loftNext
		txt(lc, (info.loftName and "Move up: " or "Lease: ") .. n.name .. " (" .. n.cap .. " guests)" .. (n.locked and ("  🔒 " .. n.need) or ""), UDim2.fromOffset(12, 30), UDim2.new(1, -290, 0, 20), 11, SUB)
		btn(lc, "$" .. fmt(n.cost), UDim2.new(1, -270, 0.5, -18), UDim2.fromOffset(128, 36), (not n.locked and info.cash >= n.cost) and GREEN or GRAY, function() act("loftBuy") end, "LoftBuy")
	end
	if info.loftName then
		btn(lc, "Go inside", UDim2.new(1, -132, 0.5, -18), UDim2.fromOffset(120, 36), BLUE, function() act("loftEnter") C.closeModals() end, "LoftEnter")
	end
	-- loft vs house vs mansion
	local h4 = card(m.body, 30, nx(), RGB(26, 28, 40))
	txt(h4, "🏡 WAYS TO LIVE" .. (info.kind and ("   (you: " .. info.kind .. (info.loft > 0 and " + loft" or "") .. ")") or ""), UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	for _, k in ipairs(info.kinds) do
		local c = card(m.body, 96, nx(), (info.kind == k.key or (k.key == "loft" and info.loft > 0)) and RGB(36, 60, 44) or nil)
		txt(c, k.icon .. "  " .. k.name .. "  —  " .. k.sub, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 14, WHITE, true)
		txt(c, "✅ " .. table.concat(k.good, "\n✅ "), UDim2.fromOffset(12, 28), UDim2.new(0.6, -12, 0, 64), 11, RGB(170, 240, 180))
		txt(c, "➖ " .. table.concat(k.bad, "\n➖ "), UDim2.new(0.6, 0, 0, 28), UDim2.new(0.4, -12, 0, 64), 11, RGB(255, 190, 170))
	end
end
HU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("homeLifeInfo")
	end
end

-- the party card in the notification stack
local pc = panel({Position = UDim2.new(1, -12, 1, -372), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(290, 84), BackgroundColor3 = RGB(70, 26, 70), Visible = false}, gui)
stroke(pc, RGB(255, 120, 220), 2, 0)
pc.Name = "PartyCard"
Lay.slot(pc, "top", 6)
local pt = label({Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 40), TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 190, 240), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, pc)
local pj = button({Position = UDim2.new(0, 8, 1, -32), Size = UDim2.new(0.6, -12, 0, 26), Text = "🎉 Join the party", TextSize = 12, BackgroundColor3 = PURPLE}, pc)
pj.Name = "PartyCardJoin"
local px = button({Position = UDim2.new(0.6, 0, 1, -32), Size = UDim2.new(0.4, -8, 0, 26), Text = "Not now", TextSize = 12, BackgroundColor3 = GRAY}, pc)
local cardFor
pj.MouseButton1Click:Connect(function() play(SND.click) if cardFor then act("partyJoin", cardFor) end pc.Visible = false end)
px.MouseButton1Click:Connect(function() play(SND.click) pc.Visible = false end)
HU.card = pc

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "homeLife" and type(a) == "table" then
		HU.info = a
		if m.frame.Visible then render() end
	elseif kind == "openParty" then
		asked = false
		C.openModal("party", true)
	elseif kind == "partyOn" and type(a) == "table" then
		HU.live[a.uid] = {host = a.host, venue = a.venue, place = a.place, ends = os.clock() + (a.left or 0)}
		if a.uid ~= plr.UserId then
			cardFor = a.uid
			pt.Text = "🎉 " .. a.host .. " is throwing a party at their " .. a.place .. "!"
			pc.Visible = true
			task.delay(60, function() if cardFor == a.uid then pc.Visible = false end end)
		end
		if C.jingle then C.jingle("success", 0.3) end
		if C.AudioDirector then C.AudioDirector.apply() end
		if m.frame.Visible then act("homeLifeInfo") end
	elseif kind == "partyOff" and type(a) == "table" then
		HU.live[a.uid] = nil
		if cardFor == a.uid then pc.Visible = false cardFor = nil end
		if C.AudioDirector then C.AudioDirector.apply() end
		if m.frame.Visible then act("homeLifeInfo") end
	end
end)
end
