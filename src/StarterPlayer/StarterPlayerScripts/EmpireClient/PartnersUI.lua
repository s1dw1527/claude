-- PARTNERS UI (v14): the 🤝 PARTNERS phone app (send a gift, your businesses' partners and managers, the
-- partnerships you're in, your transfer history) and the yes/no dialogs: a gift offered to you, "they accepted:
-- send it?", an invitation to someone's business. The server (GameServer > Partners + Ledger) checks and does
-- everything; this only shows it and sends the answers.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, stroke, panel, corner = C.new, C.label, C.button, C.card, C.clear, C.stroke, C.panel, C.corner
local fmt, play, SND, act, R, gui = C.fmt, C.play, C.SND, C.act, C.R, C.gui
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local Lay = C.Layout
local modal = C.makeModal
if not modal then return end
local PU = {info = nil, inviting = nil}
C.PartnersUI = PU

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
local KIND = {gift = "💸 gift", share = "🤝 share"}

local m = modal("partners", "🤝  PARTNERS", 580, 640)
local function render()
	local info = PU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local order = 0
	local function nextOrder() order += 1 return order end
	-- gifts
	local g = card(m.body, 30, nextOrder(), RGB(26, 28, 40))
	txt(g, "💸 SEND A GIFT   (today: $" .. fmt(info.giftLeft) .. " left)", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	if not info.giftsOn then
		local c = card(m.body, 34, nextOrder())
		txt(c, "🔒 Gifts unlock at LOCAL FAVORITE reputation.", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 12, SUB)
	elseif #info.players == 0 then
		local c = card(m.body, 34, nextOrder())
		txt(c, "Nobody else is in this server right now.", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 12, SUB)
	end
	for _, p in ipairs(info.giftsOn and info.players or {}) do
		local c = card(m.body, 50, nextOrder())
		txt(c, "👤 " .. p.name, UDim2.fromOffset(12, 14), UDim2.new(0.4, -12, 0, 22), 14, WHITE, true)
		local box = new("TextBox", {Position = UDim2.new(0.4, 0, 0, 8), Size = UDim2.new(0.3, -8, 0, 34), Text = "", PlaceholderText = "amount", ClearTextOnFocus = false,
			TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = WHITE, BackgroundColor3 = RGB(20, 22, 32), BorderSizePixel = 0}, c)
		box.Name = "GiftAmount_" .. p.uid
		corner(box, 6)
		btn(c, "Send $", UDim2.new(0.7, 0, 0, 8), UDim2.new(0.3, -10, 0, 34), GREEN, function()
			local n = tonumber((string.gsub(box.Text, "[^%d]", "")))
			if n then act("giftOffer", p.uid, n) end
		end, "Gift_" .. p.uid)
	end
	-- my businesses
	local h = card(m.body, 30, nextOrder(), RGB(26, 28, 40))
	txt(h, "🏪 YOUR BUSINESSES: partners share the work (and a slice of the income you choose)", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 12, GOLD, true)
	for _, b in ipairs(info.mine) do
		local rows = math.max(1, #b.members)
		local c = card(m.body, 44 + rows * 46 + (#b.log > 0 and 34 or 0) + (PU.inviting == b.key and (#info.players * 40 + 6) or 0), nextOrder())
		txt(c, b.icon .. "  " .. b.name, UDim2.fromOffset(12, 8), UDim2.new(1, -150, 0, 22), 15, WHITE, true)
		btn(c, PU.inviting == b.key and "Close" or "+ Invite", UDim2.new(1, -120, 0, 6), UDim2.fromOffset(108, 30), PURPLE, function()
			PU.inviting = PU.inviting ~= b.key and b.key or nil
			render()
		end, "Invite_" .. b.key)
		local y = 40
		if #b.members == 0 then
			txt(c, "No partners yet.", UDim2.fromOffset(12, y + 10), UDim2.new(1, -24, 0, 20), 12, SUB)
		end
		for _, mm in ipairs(b.members) do
			txt(c, (mm.here and "🟢 " or "⚪ ") .. mm.name .. "  " .. mm.roleName .. (mm.share > 0 and ("  " .. mm.share .. "%") or ""),
				UDim2.fromOffset(12, y + 2), UDim2.new(1, -250, 0, 18), 13, WHITE, true)
			txt(c, "paid in $" .. fmt(mm.contributed) .. "  •  received $" .. fmt(mm.paid), UDim2.fromOffset(12, y + 22), UDim2.new(1, -250, 0, 16), 11, SUB)
			local other = mm.role == "partner" and "manager" or "partner"
			btn(c, "⇄ Role", UDim2.new(1, -238, 0, y + 4), UDim2.fromOffset(56, 34), GRAY, function() act("coopSet", b.key, mm.uid, other .. ":" .. (other == "partner" and mm.share or 0)) end, "Role_" .. b.key .. "_" .. mm.uid)
			if mm.role == "partner" then
				btn(c, "−5%", UDim2.new(1, -178, 0, y + 4), UDim2.fromOffset(46, 34), GRAY, function() act("coopSet", b.key, mm.uid, "partner:" .. math.max(0, mm.share - 5)) end, "ShareDown_" .. b.key .. "_" .. mm.uid)
				btn(c, "+5%", UDim2.new(1, -128, 0, y + 4), UDim2.fromOffset(46, 34), GRAY, function() act("coopSet", b.key, mm.uid, "partner:" .. math.min(info.maxShare, mm.share + 5)) end, "ShareUp_" .. b.key .. "_" .. mm.uid)
			end
			btn(c, "Remove", UDim2.new(1, -78, 0, y + 4), UDim2.fromOffset(66, 34), RED, function()
				C.confirm("Remove " .. mm.name .. " from your " .. b.name .. "?", "Remove", function() act("coopRemove", b.key, mm.uid) end)
			end, "Remove_" .. b.key .. "_" .. mm.uid)
			y += 46
		end
		if #b.members == 0 then y += 46 end
		if #b.log > 0 then
			txt(c, "📜 " .. table.concat(b.log, "  •  "), UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, 30), 10, SUB)
			y += 34
		end
		if PU.inviting == b.key then
			for _, p in ipairs(info.players) do
				txt(c, "👤 " .. p.name, UDim2.fromOffset(20, y + 8), UDim2.new(0.4, 0, 0, 20), 13, WHITE)
				btn(c, "as 🤝 Partner", UDim2.new(0.42, 0, 0, y + 2), UDim2.new(0.28, -6, 0, 34), GREEN, function() act("coopInvite", b.key, p.uid, "partner") PU.inviting = nil render() end, "InvitePartner_" .. b.key .. "_" .. p.uid)
				btn(c, "as 🧑‍💼 Manager", UDim2.new(0.7, 0, 0, y + 2), UDim2.new(0.3, -12, 0, 34), BLUE, function() act("coopInvite", b.key, p.uid, "manager") PU.inviting = nil render() end, "InviteManager_" .. b.key .. "_" .. p.uid)
				y += 40
			end
		end
	end
	if #info.mine == 0 then
		local c = card(m.body, 34, nextOrder())
		txt(c, "Open a business first.", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 12, SUB)
	end
	-- partnerships I'm in
	local h2 = card(m.body, 30, nextOrder(), RGB(26, 28, 40))
	txt(h2, "🤝 YOU'RE PART OF", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	if #info.of == 0 then
		local c = card(m.body, 34, nextOrder())
		txt(c, "Nobody's business yet. Ask a friend to invite you!", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20), 12, SUB)
	end
	for _, e in ipairs(info.of) do
		local c = card(m.body, e.log and #e.log > 0 and 112 or 80, nextOrder())
		txt(c, e.icon .. "  " .. (e.biz or "a business") .. "  (" .. e.ownerName .. ")", UDim2.fromOffset(12, 8), UDim2.new(1, -150, 0, 20), 14, WHITE, true)
		txt(c, e.roleName .. (e.share and e.share > 0 and ("  •  " .. e.share .. "% share") or "") .. (e.ownerHere and "" or "  •  owner not in this server"),
			UDim2.fromOffset(12, 30), UDim2.new(1, -150, 0, 18), 11, SUB)
		if e.canContribute and e.cost then
			btn(c, "Pay next upgrade\n$" .. fmt(e.cost), UDim2.new(1, -140, 0, 6), UDim2.fromOffset(128, 38), GREEN, function() act("coopContribute", e.owner, e.key) end, "Contribute_" .. e.key)
		end
		btn(c, "Leave", UDim2.new(1, -140, 0, 46), UDim2.fromOffset(128, 26), RED, function()
			C.confirm("Leave " .. e.ownerName .. "'s business?", "Leave", function() act("coopLeave", e.owner, e.key) end)
		end, "Leave_" .. e.key)
		if e.log and #e.log > 0 then txt(c, "📜 " .. table.concat(e.log, "  •  "), UDim2.fromOffset(12, 78), UDim2.new(1, -24, 0, 30), 10, SUB) end
	end
	-- history
	local h3 = card(m.body, 30, nextOrder(), RGB(26, 28, 40))
	txt(h3, "📒 HISTORY", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	local lines = {}
	for _, l in ipairs(info.log) do
		table.insert(lines, (l.dir == "out" and "↗ to " or "↘ from ") .. tostring(l.who) .. ": $" .. fmt(l.amt) .. "  " .. (KIND[l.kind] or tostring(l.kind)) .. (l.state == "pending" and "  ⏳ pending" or ""))
	end
	local hc = card(m.body, math.max(34, #lines * 18 + 14), nextOrder())
	txt(hc, #lines > 0 and table.concat(lines, "\n") or "No transfers yet.", UDim2.fromOffset(12, 7), UDim2.new(1, -24, 1, -10), 12, #lines > 0 and WHITE or SUB)
end
PU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("partnersInfo")
	end
end

-- ===== yes / no dialogs (one at a time, queued) =====
local dlg = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(380, 170), Visible = false, ZIndex = 60}, gui)
dlg.Name = "PartnerDialog"
stroke(dlg, GOLD, 2, 0)
Lay.window("partnerDialog", dlg, {fixed = true, z = 60, major = false})
local dT = label({Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 26), TextSize = 17, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 61}, dlg)
local dB = label({Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 60), TextSize = 14, TextWrapped = true, ZIndex = 61}, dlg)
local yes = button({Position = UDim2.new(0, 14, 1, -54), Size = UDim2.new(0.5, -20, 0, 42), TextSize = 15, BackgroundColor3 = GREEN, ZIndex = 61}, dlg)
local no = button({Position = UDim2.new(0.5, 6, 1, -54), Size = UDim2.new(0.5, -20, 0, 42), TextSize = 15, BackgroundColor3 = RED, ZIndex = 61}, dlg)
yes.Name, no.Name = "DialogYes", "DialogNo"
local queue, cur = {}, nil
local function showNext()
	cur = table.remove(queue, 1)
	if not cur then dlg.Visible = false return end
	dT.Text, dB.Text, yes.Text, no.Text = cur.title, cur.body, cur.yes, cur.no
	dlg.Visible = true
	if C.jingle then C.jingle("coin", 0.3) end
end
local function ask(e)
	-- (a newer dialog for the same thing replaces the old one)
	for i = #queue, 1, -1 do if queue[i].id == e.id then table.remove(queue, i) end end
	table.insert(queue, e)
	if not cur then showNext() end
end
local function closeId(id)
	for i = #queue, 1, -1 do if queue[i].id == id then table.remove(queue, i) end end
	if cur and cur.id == id then showNext() end
end
yes.MouseButton1Click:Connect(function() play(SND.click) local e = cur if e then e.onYes() end showNext() end)
no.MouseButton1Click:Connect(function() play(SND.click) local e = cur if e then e.onNo() end showNext() end)
PU.dialog = dlg

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "partners" and type(a) == "table" then
		PU.info = a
		if m.frame.Visible then render() end
	elseif kind == "giftOffer" and type(a) == "table" then
		ask({id = "gift" .. a.id, title = "💸 A GIFT", body = a.from .. " wants to send you $" .. fmt(a.amt) .. ".", yes = "Accept", no = "No thanks",
			onYes = function() act("giftAnswer", a.id, true) end, onNo = function() act("giftAnswer", a.id, false) end})
	elseif kind == "giftConfirm" and type(a) == "table" then
		ask({id = "gift" .. a.id, title = "💸 CONFIRM", body = a.to .. " accepted. Send them $" .. fmt(a.amt) .. "? This can't be undone.", yes = "Send it", no = "Cancel",
			onYes = function() act("giftConfirm", a.id, true) end, onNo = function() act("giftConfirm", a.id, false) end})
	elseif kind == "giftClosed" and type(a) == "table" then
		closeId("gift" .. tostring(a.id))
		if m.frame.Visible then act("partnersInfo") end
	elseif kind == "coopInvite" and type(a) == "table" then
		ask({id = "coop" .. a.id, title = "🤝 AN INVITATION", body = a.owner .. " invites you into their " .. a.icon .. " " .. a.biz .. " as " .. a.role .. ".", yes = "Join", no = "No thanks",
			onYes = function() act("coopAnswer", a.id, true) end, onNo = function() act("coopAnswer", a.id, false) end})
	end
end)
end
