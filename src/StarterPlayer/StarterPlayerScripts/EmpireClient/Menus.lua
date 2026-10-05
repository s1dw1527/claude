-- MENUS: modal windows opened from the phone (and from world prompts).
return function(C)
local RGB = Color3.fromRGB
local new, tween, panel, label, button, card, header, bar, vlist, autoFrame, corner, stroke, gradient, clear =
	C.new, C.tween, C.panel, C.label, C.button, C.card, C.header, C.bar, C.vlist, C.autoFrame, C.corner, C.stroke, C.gradient, C.clear
local fmt, clock, stars, play, SND, act, gui, U, plr, catalog, R = C.fmt, C.clock, C.stars, C.play, C.SND, C.act, C.gui, C.U, C.plr, C.catalog, C.R
local BG, CARD, GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.BG, C.CARD, C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modals = C.modals

local LOCKS = {garage = "cars", staff = "staff", market = "market", marketing = "ads", properties = "properties", fun = "funpark"}
C.MODAL_LOCKS = LOCKS
local function modal(key, title, w, h)
	local f = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(w, h), Visible = false, ZIndex = 10}, gui)
	gradient(f, RGB(40, 44, 64), RGB(20, 22, 32))
	label({Size = UDim2.new(1, 0, 0, 50), Text = title, TextSize = 24, Font = Enum.Font.GothamBlack}, f)
	local x = button({Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(36, 36), Text = "X", TextSize = 18, BackgroundColor3 = RED}, f)
	local body = new("ScrollingFrame", {Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, f)
	vlist(body, 8)
	local m = {frame = f, body = body, scale = new("UIScale", {}, f)}
	x.MouseButton1Click:Connect(function()
		play(SND.click)
		f.Visible = false
	end)
	modals[key] = m
	return m
end
C.makeModal = modal   -- (other modules build their windows the same way)
function C.closeModals()
	for _, o in pairs(modals) do o.frame.Visible = false end
end
function C.openModal(key, extra)
	local m = modals[key]
	if not m then return end
	if LOCKS[key] and C.locked(LOCKS[key]) then
		U.toast(C.lockText(LOCKS[key]))
		return
	end
	local was = m.frame.Visible
	C.closeModals()
	if was and not extra then return end
	m.extra = extra
	m.frame.Visible = true
	-- small screens (phones): shrink the window to fit instead of running off the edges
	local cam = game:GetService("Workspace").CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local fs = m.frame.Size
	local fit = math.clamp(math.min((vp.X - 16) / math.max(1, fs.X.Offset), (vp.Y - 16) / math.max(1, fs.Y.Offset)), 0.45, 1)
	m.scale.Scale = 0.6 * fit
	tween(m.scale, 0.3, {Scale = fit}, Enum.EasingStyle.Back)
	if C.S and m.update then m.update(C.S) end
end
C.onState(function(s)
	for _, m in pairs(modals) do
		if m.frame.Visible and m.update then m.update(s) end
	end
end)

-- ===== PASSES =====
do
	local m = modal("passes", "🛒  GAME PASSES", 620, 500)
	local grid = autoFrame(m.body, 1)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(182, 196), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, grid)
	local cards = {}
	for _, p in ipairs(catalog.passes) do
		local c = new("Frame", {BackgroundColor3 = CARD, BorderSizePixel = 0}, grid)
		corner(c, 10)
		local st = stroke(c, GOLD, 2, 0.6)
		label({Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 46), Text = p.icon, TextSize = 40}, c)
		label({Position = UDim2.fromOffset(6, 56), Size = UDim2.new(1, -12, 0, 22), Text = p.name, TextSize = 16, Font = Enum.Font.GothamBlack}, c)
		label({Position = UDim2.fromOffset(8, 78), Size = UDim2.new(1, -16, 0, 50), Text = p.desc, TextSize = 12, TextWrapped = true, TextColor3 = SUB}, c)
		local btn = button({Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -20, 0, 42), TextSize = 16, Text = "R$ " .. p.price}, c)
		btn.MouseButton1Click:Connect(function() play(SND.click) act("pass", p.key) end)
		cards[p.key] = {btn = btn, stroke = st, price = p.price}
	end
	m.update = function(s)
		for key, c in pairs(cards) do
			local owned = s.passes[key]
			c.btn.Text = owned and "✔ OWNED" or ("R$ " .. c.price)
			c.btn.BackgroundColor3 = owned and GRAY or GREEN
			c.stroke.Transparency = owned and 0 or 0.6
		end
	end
end

-- ===== GARAGE: see GarageUI (v10) =====
-- ===== STAFF + candidates =====
do
	local m = modal("staff", "👥  STAFF", 640, 540)
	label({Size = UDim2.new(1, -8, 0, 34), TextSize = 13, TextColor3 = SUB, TextWrapped = true, LayoutOrder = 0,
		Text = "Each employee has ★ Service, Speed and Experience. Service makes customers happier (better reviews). Train them to level up!"}, m.body)
	local rows = {}
	for i, st in ipairs(catalog.staff) do
		local row = card(m.body, 70, i)
		label({Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(44, 70), Text = st.icon, TextSize = 28}, row)
		label({Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -260, 0, 20), Text = st.role, TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, row)
		local r = {desc = st.desc}
		r.info = label({Position = UDim2.fromOffset(56, 26), Size = UDim2.new(1, -260, 0, 40), TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true}, row)
		r.b1 = button({Position = UDim2.new(1, -196, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(110, 48), TextSize = 12, TextWrapped = true}, row)
		r.b2 = button({Position = UDim2.new(1, -80, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(72, 48), TextSize = 12, Text = "Fire", BackgroundColor3 = RED}, row)
		r.b1.MouseButton1Click:Connect(function()
			play(SND.click)
			if r.hired then act("train", st.slot) else act("candidates", st.slot) end
		end)
		r.b2.MouseButton1Click:Connect(function() play(SND.click) act("fire", st.slot) end)
		rows[st.slot] = r
	end
	m.update = function(s)
		for slot, r in pairs(rows) do
			local st = s.staff[slot]
			r.hired = st.hired
			r.b2.Visible = st.hired
			if st.hired then
				r.info.Text = st.name .. "   Service " .. stars(st.service) .. "  Speed " .. stars(st.speed) .. "  Exp " .. stars(st.exp) .. "\n" .. r.desc
				if st.trainCost then
					r.b1.Text = "📚 Train\n$" .. fmt(st.trainCost)
					r.b1.BackgroundColor3 = s.cash >= st.trainCost and BLUE or GRAY
				else
					r.b1.Text = "⭐ MAX EXP"
					r.b1.BackgroundColor3 = RGB(190, 145, 30)
				end
			else
				r.info.Text = "Not hired.  " .. r.desc
				if st.locked then
					r.b1.Text = "🔒 Open the\nbusiness first"
					r.b1.BackgroundColor3 = GRAY
				else
					r.b1.Text = "Hire\n$" .. fmt(st.hireCost)
					r.b1.BackgroundColor3 = s.cash >= st.hireCost and GREEN or GRAY
				end
			end
		end
	end
	local cp = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 260), Visible = false, ZIndex = 20}, gui)
	gradient(cp, RGB(45, 55, 80), RGB(22, 26, 38))
	local cpT = label({Size = UDim2.new(1, 0, 0, 44), TextSize = 20, Font = Enum.Font.GothamBlack}, cp)
	local cx = button({Position = UDim2.new(1, -44, 0, 6), Size = UDim2.fromOffset(34, 34), Text = "X", BackgroundColor3 = RED}, cp)
	cx.MouseButton1Click:Connect(function() cp.Visible = false end)
	local cands = {}
	local curSlot
	for i = 1, 3 do
		local c = new("Frame", {Position = UDim2.new((i - 1) / 3, 8, 0, 50), Size = UDim2.new(1 / 3, -16, 1, -60), BackgroundColor3 = CARD, BorderSizePixel = 0}, cp)
		corner(c, 10)
		local e = {}
		e.name = label({Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 26), TextSize = 18, Font = Enum.Font.GothamBlack}, c)
		e.stats = label({Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 0, 90), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = GOLD}, c)
		e.btn = button({Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -16, 0, 40), Text = "HIRE", TextSize = 15}, c)
		e.btn.MouseButton1Click:Connect(function() play(SND.click) act("hire", curSlot, i) end)
		cands[i] = e
	end
	R.Menu.OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "candidates" then
			curSlot = a
			local role = a
			for _, st in ipairs(catalog.staff) do
				if st.slot == a then role = st.icon .. " " .. st.role end
			end
			cpT.Text = "Pick your new " .. role .. "  ($" .. fmt(c) .. ")"
			for i, e in ipairs(cands) do
				local cand = b[i]
				e.name.Text = cand.name
				e.stats.Text = "Service  " .. stars(cand.service) .. "\nSpeed     " .. stars(cand.speed) .. "\nExp        " .. stars(cand.exp)
			end
			cp.Visible = true
		elseif kind == "closeCandidates" then
			cp.Visible = false
		elseif kind == "open" then
			if a == "home" or a == "properties" or modals[a] then C.openModal(a, b) end
		end
	end)
end

-- ===== STOCK MARKET =====
do
	local m = modal("market", "📈  STOCK MARKET", 640, 520)
	local head = label({Size = UDim2.new(1, -8, 0, 44), TextSize = 14, TextWrapped = true, TextColor3 = SUB, LayoutOrder = 0}, m.body)
	local rows = {}
	local function makeRow(e, order)
		local row = card(m.body, 96, order)
		local r = {row = row, userId = e.userId, bars = {}}
		r.tick = label({Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(200, 22), TextSize = 18, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, row)
		r.price = label({Position = UDim2.fromOffset(10, 28), Size = UDim2.fromOffset(200, 20), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD}, row)
		r.mine = label({Position = UDim2.fromOffset(10, 48), Size = UDim2.fromOffset(200, 18), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SUB}, row)
		local chart = new("Frame", {Position = UDim2.fromOffset(200, 8), Size = UDim2.fromOffset(150, 56), BackgroundColor3 = RGB(18, 20, 28), BorderSizePixel = 0}, row)
		corner(chart, 6)
		for k = 1, 24 do
			r.bars[k] = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((k - 1) / 24, 1, 1, -2), Size = UDim2.new(1 / 24, -2, 0, 2), BackgroundColor3 = GREEN, BorderSizePixel = 0}, chart)
		end
		local function tb(text, x, w, fn, color)
			local b = button({Position = UDim2.fromOffset(x, 70), Size = UDim2.fromOffset(w, 22), Text = text, TextSize = 11, BackgroundColor3 = color or GREEN}, row)
			b.MouseButton1Click:Connect(function() play(SND.click) fn() end)
		end
		tb("Buy 1", 10, 60, function() act("stock", r.userId, "buy", 1) end)
		tb("Buy 10", 76, 60, function() act("stock", r.userId, "buy", 10) end)
		tb("Buy 100", 142, 64, function() act("stock", r.userId, "buy", 100) end)
		tb("Sell All", 212, 70, function() act("stock", r.userId, "sell", 0) end, RED)
		r.note = label({Position = UDim2.fromOffset(360, 8), Size = UDim2.new(1, -370, 0, 80), TextSize = 12, TextWrapped = true, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, row)
		return r
	end
	m.update = function(s)
		head.Text = "💼 Portfolio value: $" .. fmt(s.portfolio) .. "\nShare prices follow each company's income & reputation. Buy low, sell high! Owners get 10% of what others invest."
		local seen = {}
		for i, e in ipairs(s.market) do
			seen[e.userId] = true
			local r = rows[e.userId]
			if not r then
				r = makeRow(e, i)
				rows[e.userId] = r
			end
			local ch = e.first > 0 and (e.price / e.first - 1) * 100 or 0
			r.tick.Text = e.ticker .. (e.userId == plr.UserId and "  (you)" or "")
			r.tick.TextColor3 = e.color
			r.price.Text = string.format("$%s   %s%.1f%%", fmt(e.price), ch >= 0 and "▲ +" or "▼ ", ch)
			r.price.TextColor3 = ch >= 0 and GREEN or RED
			r.mine.Text = "You own " .. fmt(e.mine) .. " shares ($" .. fmt(e.mine * e.price) .. ")"
			r.note.Text = e.name .. " Inc.\n" .. (e.userId == plr.UserId and "Your own company. Invest in yourself!" or "Invest to profit when they grow.")
			local lo, hi = math.huge, -math.huge
			for _, v in ipairs(e.hist) do lo, hi = math.min(lo, v), math.max(hi, v) end
			for k, bf in ipairs(r.bars) do
				local v = e.hist[k]
				bf.Visible = v ~= nil
				if v then
					local f = hi > lo and (v - lo) / (hi - lo) or 0.5
					bf.Size = UDim2.new(1 / 24, -2, 0, 4 + f * 46)
					bf.BackgroundColor3 = (k > 1 and e.hist[k - 1] and v < e.hist[k - 1]) and RED or GREEN
				end
			end
		end
		for id, r in pairs(rows) do
			if not seen[id] then
				r.row:Destroy()
				rows[id] = nil
			end
		end
	end
end

-- ===== MARKETING (ads + reviews) =====
do
	local m = modal("marketing", "📣  MARKETING", 620, 520)
	local adRow = new("Frame", {Size = UDim2.new(1, -8, 0, 86), BackgroundTransparency = 1, LayoutOrder = 1}, m.body)
	local adBtns = {}
	for i, a in ipairs(catalog.ads) do
		local b = button({Position = UDim2.new((i - 1) / 3, 4, 0, 0), Size = UDim2.new(1 / 3, -8, 1, 0), TextSize = 13, TextWrapped = true, BackgroundColor3 = RGB(235, 130, 40),
			Text = "📣 " .. a.name .. "\n$" .. fmt(a.cost) .. "\n" .. a.customers .. "x customers • " .. a.dur .. "s"}, adRow)
		b.MouseButton1Click:Connect(function() play(SND.click) act("ad", a.key) end)
		adBtns[i] = {btn = b, cost = a.cost, ad = a}
	end
	local adStatus = label({Size = UDim2.new(1, -8, 0, 20), TextSize = 13, TextColor3 = GOLD, LayoutOrder = 2}, m.body)
	header(m.body, "⭐ Reviews of your businesses", 5)
	local revs = autoFrame(m.body, 6)
	vlist(revs, 6)
	m.update = function(s)
		for i, a in ipairs(adBtns) do
			-- ads cost their price or a few minutes of your income, whichever is more (the server sends today's price)
			local cost = s.adCosts and s.adCosts[i] or a.cost
			a.btn.Text = "📣 " .. a.ad.name .. "\n$" .. fmt(cost) .. "\n" .. a.ad.customers .. "x customers • " .. a.ad.dur .. "s"
			a.btn.BackgroundColor3 = (not s.adName and s.cash >= cost) and RGB(235, 130, 40) or GRAY
		end
		adStatus.Text = s.adName and ("📣 " .. s.adName .. " running — " .. clock(s.adLeft) .. " left") or "No campaign running. Ads bring more customers (a Major campaign may unlock a secret...)"
		clear(revs)
		if #s.reviews == 0 then
			local c = card(revs, 30, 1)
			label({Size = UDim2.fromScale(1, 1), Text = "No reviews yet — customers review your businesses as they visit.", TextSize = 12, TextColor3 = SUB}, c)
		end
		for i, r in ipairs(s.reviews) do
			local c = card(revs, 44, i)
			label({Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 20), Text = stars(r.stars) .. "   " .. r.biz, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Font = Enum.Font.GothamBlack}, c)
			label({Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 18), Text = "\"" .. r.text .. "\"", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, c)
		end
	end
end

-- ===== ARCHIVE =====
do
	local m = modal("archive", "📖  EMPIRE ARCHIVE", 640, 560)
	local stats = {}
	local rowsBox = autoFrame(m.body, 1)
	vlist(rowsBox, 4)
	header(m.body, "✨ Discoveries (combine businesses at level 3+)", 2)
	local grid = autoFrame(m.body, 3)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(186, 86), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center}, grid)
	header(m.body, "🏆 Awards & Skins", 4)
	local awardL = label({Size = UDim2.new(1, -8, 0, 22), TextSize = 14, TextColor3 = GOLD, LayoutOrder = 5}, m.body)
	local skinRow = autoFrame(m.body, 6)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(112, 70), CellPadding = UDim2.fromOffset(6, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center}, skinRow)
	local comboCards, skinCards = {}, {}
	m.update = function(s)
		local a = s.archive
		for i, r in ipairs(a.rows) do
			local e = stats[i]
			if not e then
				local c = card(rowsBox, 30, i)
				e = {
					l = label({Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14}, c),
					n = label({Position = UDim2.new(1, -90, 0, 0), Size = UDim2.new(0, 80, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, Font = Enum.Font.GothamBlack}, c),
				}
				e.fill = bar(c, UDim2.new(0.4, 0, 0.5, -5), UDim2.new(0.6, -100, 0, 10), GOLD)
				stats[i] = e
			end
			e.l.Text = r[1]
			e.n.Text = r[2] .. " / " .. r[3]
			e.fill.Size = UDim2.fromScale(math.clamp(r[2] / r[3], 0, 1), 1)
		end
		for i, c in ipairs(a.combos) do
			local e = comboCards[i]
			if not e then
				local f = new("Frame", {BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i}, grid)
				corner(f, 10)
				e = {f = f, st = stroke(f, WHITE, 2, 0.8),
					icon = label({Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 30), TextSize = 24}, f),
					name = label({Position = UDim2.fromOffset(4, 34), Size = UDim2.new(1, -8, 0, 20), TextSize = 14, Font = Enum.Font.GothamBlack}, f),
					rec = label({Position = UDim2.fromOffset(4, 54), Size = UDim2.new(1, -8, 0, 28), TextSize = 11, TextWrapped = true, TextColor3 = SUB}, f)}
				comboCards[i] = e
			end
			e.icon.Text = c.icon
			e.name.Text = c.name
			e.name.TextColor3 = c.found and c.color or SUB
			e.rec.Text = c.recipe
			e.st.Color = c.found and c.color or WHITE
			e.st.Transparency = c.found and 0 or 0.8
		end
		awardL.Text = "🏆 Trophies: " .. s.trophies .. "     💎 Empire Points: " .. s.ep .. "     (win Corner Wars to unlock skins)"
		for i, sk in ipairs(a.skins) do
			local e = skinCards[i]
			if not e then
				local b = button({LayoutOrder = i, TextSize = 12, TextWrapped = true}, skinRow)
				b.MouseButton1Click:Connect(function() play(SND.click) act("skin", sk.key) end)
				e = {btn = b}
				skinCards[i] = e
			end
			e.btn.Text = sk.name .. "\n" .. (sk.equipped and "✔ EQUIPPED" or (sk.unlocked and "Equip" or (sk.era and ("🔒 help reach Era " .. sk.era) or ("🔒 🏆x" .. sk.need))))
			e.btn.BackgroundColor3 = sk.unlocked and sk.color or GRAY
		end
	end
end

-- ===== CITY (Spire + business land) =====
do
	local m = modal("city", "🏙️  THE CITY", 640, 560)
	local sp = card(m.body, 150, 1, RGB(40, 50, 75))
	local spT = label({Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 24), TextSize = 18, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, sp)
	label({Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		Text = "The whole server builds this landmark together. Finishing it starts a NEW ERA."}, sp)
	local spFill = bar(sp, UDim2.fromOffset(12, 56), UDim2.new(1, -24, 0, 12), RGB(120, 220, 255))
	local spP = label({Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 0, 18), TextSize = 13, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left}, sp)
	for i, b in ipairs({{"+$1K", "k1"}, {"+$10K", "k10"}, {"+10% cash", "p10"}, {"+50% cash", "p50"}, {"📍 Go", "tp"}}) do
		local bt = button({Position = UDim2.new((i - 1) / 5, 4, 0, 96), Size = UDim2.new(1 / 5, -8, 0, 44), Text = b[1], TextSize = 13, BackgroundColor3 = b[2] == "tp" and BLUE or RGB(235, 160, 30)}, sp)
		bt.MouseButton1Click:Connect(function()
			play(SND.click)
			if b[2] == "tp" then
				act("tp", "spire")
				m.frame.Visible = false
			else
				act("contribute", b[2])
			end
		end)
	end
	local ctrl = header(m.body, "", 2)
	local cards = {}
	for i = 1, 8 do
		local c = card(m.body, 84, 2 + i)
		local e = {c = c}
		e.t = label({Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, c)
		e.a = label({Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -150, 0, 16), TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left}, c)
		e.b = label({Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -150, 0, 16), TextSize = 12, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left}, c)
		e.l = label({Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -150, 0, 16), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, c)
		e.btn = button({Position = UDim2.new(1, -130, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(120, 48), TextSize = 13, TextWrapped = true, BackgroundColor3 = BLUE}, c)
		e.btn.MouseButton1Click:Connect(function()
			play(SND.click)
			if e.key then
				act("tp", e.key)
				m.frame.Visible = false
			end
		end)
		cards[i] = e
	end
	m.update = function(s)
		local sp2 = s.spire
		spT.Text = "🏙️ ERA " .. sp2.era .. " " .. (sp2.eraName or "") .. "  •  next: " .. sp2.name
		spFill.Size = UDim2.fromScale(math.clamp(sp2.progress / sp2.goal, 0, 1), 1)
		spP.Text = "$" .. fmt(sp2.progress) .. " / $" .. fmt(sp2.goal) .. "     Top builder: " .. sp2.top
		local es = s.estate
		ctrl.Text = "🗺️ Real Estate — " .. (es and (es.used .. " / " .. es.capacity .. " properties (plots + rental buildings)") or (s.lotsMine .. " plots"))
		for i, e in ipairs(cards) do e.c.Visible = s.districts[i] ~= nil end
		for i, dd in ipairs(s.districts) do
			local e = cards[i]
			if not e then break end
			e.key = dd.key
			e.t.Text = dd.icon .. " " .. dd.name .. (dd.unlocked and "" or "   🔒")
			e.t.TextColor3 = dd.color
			local ed = es and es.districts and es.districts[i]
			e.a.Text = "Plot price $" .. fmt(ed and ed.price or dd.cost) .. "  •  +$" .. fmt(dd.income) .. "/s per plot  •  needs " .. dd.tierName
			e.b.Text = (ed and (ed.kind .. "  " .. string.rep("★", ed.stars) .. "  •  ") or "") .. "Bonus: " .. dd.boost
			e.l.Text = "You own " .. dd.mine .. (ed and ("/" .. ed.cap) or "") .. "  •  " .. (dd.total - dd.sold) .. " of " .. dd.total .. " plots for sale"
			e.btn.Text = "📍 Visit\n" .. dd.name
		end
	end
end

-- ===== HOME =====
do
	local m = modal("home", "🏠  MY HOME", 620, 560)
	local cur = card(m.body, 150, 1, RGB(40, 55, 50))
	local hT = label({Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 26), TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, cur)
	local hS = label({Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 44), TextSize = 12, TextColor3 = SUB, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, cur)
	local pips = {}
	for k = 1, 7 do
		local pp = new("Frame", {Position = UDim2.fromOffset(14 + (k - 1) * 30, 78), Size = UDim2.fromOffset(25, 10), BackgroundColor3 = GRAY, BorderSizePixel = 0}, cur)
		corner(pp, 3)
		pips[k] = pp
	end
	local buildB = button({Position = UDim2.new(0, 14, 1, -52), Size = UDim2.new(0.6, -20, 0, 42), TextSize = 15, TextWrapped = true}, cur)
	local goB = button({Position = UDim2.new(0.6, 0, 1, -52), Size = UDim2.new(0.2, -10, 0, 42), Text = "📍 Go", TextSize = 14, BackgroundColor3 = BLUE}, cur)
	local inB = button({Position = UDim2.new(0.8, 0, 1, -52), Size = UDim2.new(0.2, -14, 0, 42), Text = "🛋️ Inside", TextSize = 13, BackgroundColor3 = RGB(200, 90, 160)}, cur)
	inB.MouseButton1Click:Connect(function() play(SND.click) act("enterHome") m.frame.Visible = false end)
	buildB.MouseButton1Click:Connect(function() play(SND.click) act("homeBuild") end)
	goB.MouseButton1Click:Connect(function() play(SND.click) act("tp", "home") m.frame.Visible = false end)
	-- v10: furniture, the home builder and visitor permissions
	local tools = card(m.body, 50, 2, RGB(34, 38, 54))
	for i, t in ipairs({{"🛒 Furniture shop", function() C.openModal("furniture", true) end}, {"🔨 Home builder", function() if C.BuilderUI then C.BuilderUI.open("place") end end},
		{"🔐 Visitors", function() if C.BuilderUI then C.BuilderUI.open("visitors") end end}}) do
		local b = button({Position = UDim2.new((i - 1) / 3, 6, 0, 6), Size = UDim2.new(1 / 3, -10, 0, 38), Text = t[1], TextSize = 13, BackgroundColor3 = i == 1 and GREEN or (i == 2 and RGB(230, 140, 40) or PURPLE)}, tools)
		b.MouseButton1Click:Connect(function() play(SND.click) t[2]() end)
	end
	header(m.body, "🗺️ Neighborhoods — visit a FOR SALE sign to buy land", 3)
	local rows = {}
	m.update = function(s)
		local hi = s.homeInfo
		local h = hi.home
		if h then
			hT.Text = h.icon .. " " .. h.levelName .. " in " .. h.hood
			hT.TextColor3 = h.color
			hS.Text = "Home income bonus: +" .. h.bonus .. "%\nPerk: " .. h.perk .. "\n" .. (h.ratings and h.ratings > 0 and
				(C.stars(h.rating) .. " " .. string.format("%.1f", h.rating) .. " from " .. fmt(h.ratings) .. " ratings") or "☆☆☆☆☆ not rated yet") ..
				"  •  " .. fmt(h.visits or 0) .. " visits  •  ❤ " .. fmt(h.likes or 0)
			for k, pp in ipairs(pips) do pp.BackgroundColor3 = k <= h.level and h.color or GRAY end
			if h.cost then
				buildB.Text = "🔨 Build: " .. h.nextName .. "  $" .. fmt(h.cost)
				buildB.BackgroundColor3 = s.cash >= h.cost and GREEN or GRAY
			else
				buildB.Text = "🌟 EMPIRE ESTATE COMPLETE"
				buildB.BackgroundColor3 = RGB(190, 145, 30)
			end
			goB.Visible = true
		else
			hT.Text = "🏚️ You don't own a home"
			hT.TextColor3 = WHITE
			hS.Text = "Visit a neighborhood below and buy a lot from a FOR SALE sign, then build your house here."
			for _, pp in ipairs(pips) do pp.BackgroundColor3 = GRAY end
			buildB.Text = "No home yet"
			buildB.BackgroundColor3 = GRAY
			goB.Visible = false
		end
		for i, hd in ipairs(hi.hoods) do
			local r = rows[i]
			if not r then
				local c = card(m.body, 74, 3 + i)
				r = {c = c, key = hd.key}
				r.t = label({Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, c)
				r.a = label({Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -150, 0, 16), TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left}, c)
				r.b = label({Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -150, 0, 16), TextSize = 12, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left}, c)
				r.btn = button({Position = UDim2.new(1, -130, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(120, 46), TextSize = 13, TextWrapped = true, BackgroundColor3 = BLUE, Text = "📍 Visit"}, c)
				r.btn.MouseButton1Click:Connect(function()
					play(SND.click)
					act("tp", r.key)
					m.frame.Visible = false
				end)
				rows[i] = r
			end
			r.t.Text = hd.icon .. " " .. hd.name .. (hd.mine and "  (you live here)" or "") .. (hd.unlocked and "" or "  🔒")
			r.t.TextColor3 = hd.color
			r.a.Text = "Land $" .. fmt(hd.price) .. "  •  " .. hd.free .. " lots free  •  needs " .. hd.tierName
			r.b.Text = hd.perk
		end
	end
end

-- ===== PROPERTIES (management company) =====
do
	local m = modal("properties", "🏢  PROPERTY MANAGEMENT", 700, 600)
	local summary = label({Size = UDim2.new(1, -8, 0, 40), TextSize = 13, TextColor3 = SUB, TextWrapped = true, LayoutOrder = 0}, m.body)
	local listBox = autoFrame(m.body, 1)
	vlist(listBox, 8)
	header(m.body, "🏗️ Build a new building on Rental Row", 2)
	local buildBox = autoFrame(m.body, 3)
	vlist(buildBox, 6)
	local lastKey
	local function tenantRow(parent, order, u, bi, ui)
		local c = card(parent, 40, order, RGB(30, 34, 48))
		c.Size = UDim2.new(1, -16, 0, 40)
		if u.tenant then
			local t = u.tenant
			label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -110, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
				Text = u.unit .. "  " .. t.emoji .. " " .. t.name .. " " .. (t.moodIcon or "") .. " • " .. t.job .. " • " .. t.trait .. " • credit " .. string.rep("★", t.credit) .. (t.strikes > 0 and ("  ⚠️" .. t.strikes .. "/3") or "") .. (t.owes and ("  owes $" .. fmt(t.owes)) or "")}, c)
			local ev = button({Position = UDim2.new(1, -96, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(88, 30), Text = "🚪 Evict", TextSize = 12, BackgroundColor3 = RED}, c)
			ev.MouseButton1Click:Connect(function() play(SND.click) act("evict", bi, ui) end)
		else
			label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SUB, Text = u.unit .. "  — vacant (applicants will show up)"}, c)
		end
	end
	m.update = function(s)
		local P = s.props
		-- rebuild only when the buildings change or a button becomes (un)affordable
		local afford = {}
		for _, b in ipairs(P.list) do table.insert(afford, s.cash >= (b.upgradeCost or math.huge) and "1" or "0") end
		for _, r in ipairs(catalog.rentals) do table.insert(afford, s.cash >= r.cost and "1" or "0") end
		local key = game:GetService("HttpService"):JSONEncode(P) .. table.concat(afford)
		summary.Text = "Buy apartment buildings, upgrade them, pick tenants and collect rent every 30s. Happy tenants (😀) pay on time; grumpy ones (😠) cause drama and may leave. Total rent earned: $" .. fmt(P.earned)
		if key == lastKey then return end
		lastKey = key
		clear(listBox)
		clear(buildBox)
		if #P.list == 0 then
			local c = card(listBox, 34, 1)
			label({Size = UDim2.fromScale(1, 1), Text = "You don't own any buildings yet.", TextSize = 13, TextColor3 = SUB}, c)
		end
		for i, b in ipairs(P.list) do
			local box = new("Frame", {Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = i}, listBox)
			corner(box, 10)
			vlist(box, 4)
			new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, box)
			local occ = 0
			for _, u in ipairs(b.units) do
				if u.tenant then occ += 1 end
			end
			label({Size = UDim2.new(1, -16, 0, 22), LayoutOrder = 0, TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "🏢 " .. b.name .. " " .. string.rep("★", b.level or 1) .. (b.offsite and " (offsite)" or "") .. "   •   " .. occ .. "/" .. #b.units .. " rented"}, box)
			label({Size = UDim2.new(1, -16, 0, 16), LayoutOrder = 1, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = b.condition < 50 and RED or GOLD,
				Text = (b.levelName or "") .. "  •  Condition " .. b.condition .. "%  •  Rent $" .. fmt(b.rent) .. "/unit  •  Upkeep $" .. fmt(b.upkeep or 0) .. " / 30s  •  Value $" .. fmt(b.value or 0)}, box)
			local btnRow = new("Frame", {Size = UDim2.new(1, -16, 0, 32), BackgroundTransparency = 1, LayoutOrder = 2}, box)
			local up = button({Size = UDim2.new(0.4, -4, 1, 0), TextSize = 11, TextWrapped = true, BackgroundColor3 = b.upgradeCost and (s.cash >= b.upgradeCost and GREEN or GRAY) or GOLD,
				Text = b.upgradeCost and ("⬆️ " .. b.nextName .. " $" .. fmt(b.upgradeCost) .. "  (" .. b.nextUnits .. " units, $" .. fmt(b.nextRent) .. " rent)") or "🌟 Fully upgraded"}, btnRow)
			local rn = button({Position = UDim2.new(0.4, 4, 0, 0), Size = UDim2.new(0.3, -4, 1, 0), Text = "🛠️ Renovate $" .. fmt(b.renovate), TextSize = 11, BackgroundColor3 = BLUE}, btnRow)
			local sl = button({Position = UDim2.new(0.7, 4, 0, 0), Size = UDim2.new(0.3, -4, 1, 0), Text = "💼 Sell $" .. fmt(b.sell), TextSize = 11, BackgroundColor3 = GRAY}, btnRow)
			up.MouseButton1Click:Connect(function() play(SND.click) if b.upgradeCost then act("propUpgrade", b.bi) end end)
			rn.MouseButton1Click:Connect(function() play(SND.click) act("renovate", b.bi) end)
			sl.MouseButton1Click:Connect(function() play(SND.click) act("propSell", b.bi) end)
			for ui, u in ipairs(b.units) do tenantRow(box, 2 + ui, u, b.bi, ui) end
			if #b.applicants > 0 then
				label({Size = UDim2.new(1, -16, 0, 20), LayoutOrder = 50, TextSize = 13, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = "📬 Applicants"}, box)
				for ai, a in ipairs(b.applicants) do
					local c = card(box, 44, 50 + ai, RGB(40, 50, 70))
					c.Size = UDim2.new(1, -16, 0, 44)
					label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -190, 1, 0), TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
						Text = a.emoji .. " " .. a.name .. " • " .. a.job .. " • " .. a.trait .. " • credit " .. string.rep("★", a.credit)}, c)
					local ok = button({Position = UDim2.new(1, -176, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(84, 32), Text = "✅ Accept", TextSize = 12}, c)
					local no = button({Position = UDim2.new(1, -86, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(78, 32), Text = "❌ Reject", TextSize = 12, BackgroundColor3 = GRAY}, c)
					ok.MouseButton1Click:Connect(function() play(SND.click) act("tenantAccept", b.bi, ai) end)
					no.MouseButton1Click:Connect(function() play(SND.click) act("tenantReject", b.bi, ai) end)
				end
			end
		end
		if #P.free == 0 then
			local c = card(buildBox, 34, 1)
			label({Size = UDim2.fromScale(1, 1), Text = "All Rental Row lots are taken right now.", TextSize = 13, TextColor3 = SUB}, c)
		else
			local lotId = (m.extra and table.find(P.free, m.extra)) and m.extra or P.free[1]
			label({Size = UDim2.new(1, -8, 0, 18), LayoutOrder = 0, TextSize = 12, TextColor3 = SUB, Text = #P.free .. " building sites free • building on site #" .. lotId}, buildBox)
			for i, r in ipairs(catalog.rentals) do
				local c = card(buildBox, 54, i)
				label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -180, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = "🏢 " .. r.name}, c)
				label({Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -180, 0, 18), TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
					Text = r.units .. " units  •  ~$" .. fmt(r.rent) .. " rent per unit / 30s"}, c)
				local b = button({Position = UDim2.new(1, -164, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(156, 40), TextSize = 13, Text = "Build $" .. fmt(r.cost),
					BackgroundColor3 = s.cash >= r.cost and GREEN or GRAY}, c)
				b.MouseButton1Click:Connect(function() play(SND.click) act("propBuy", lotId, r.key) end)
			end
		end
		local tp = button({Size = UDim2.new(1, -8, 0, 38), LayoutOrder = 99, Text = "📍 Go to Rental Row", TextSize = 14, BackgroundColor3 = BLUE}, buildBox)
		tp.MouseButton1Click:Connect(function() play(SND.click) act("tp", "rental") m.frame.Visible = false end)
	end
end

-- ===== FUN & RACE =====
do
	local m = modal("fun", "🎡  FUN & RACING", 600, 520)
	local rowsDef = {
		{"🏀 Hoop Shot", "hoop", "5 shots. Hit the green zone! Win up to 2.5x your entry."},
		{"🍋 Lemonade Rush", "rush", "30 seconds. Serve the orders in the right order! Up to 3x."},
		{"🧠 Memory Match", "memory", "Match the pairs in as few moves as possible. Up to 3x."},
		{"🎡 Ferris Wheel", "ferris", "A scenic ride. +10% income for 3 minutes."},
		{"🎆 Fireworks", "fireworks", "Launch a show over your business. +5 reputation."},
		{"🏁 Race Track", "race", "Time trial in your car. Faster lap = bigger prize (up to 3x)."},
	}
	local rows = {}
	for i, d in ipairs(rowsDef) do
		local c = card(m.body, 60, i)
		label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -150, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = d[1]}, c)
		local sub = label({Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -150, 0, 28), TextSize = 12, TextColor3 = SUB, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = d[3]}, c)
		local b = button({Position = UDim2.new(1, -130, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(120, 44), TextSize = 13, TextWrapped = true, BackgroundColor3 = BLUE}, c)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			act("tp", d[2] == "race" and "race" or "funpark")
			m.frame.Visible = false
		end)
		rows[d[2]] = {b = b, sub = sub, text = d[3]}
	end
	local best = label({Size = UDim2.new(1, -8, 0, 22), TextSize = 14, TextColor3 = GOLD, LayoutOrder = 20}, m.body)
	m.update = function(s)
		for k, r in pairs(rows) do
			r.b.Text = "📍 Go\nfee $" .. fmt(s.fees[k] or 0)
		end
		best.Text = s.raceBest and string.format("🏁 Your best lap: %.2fs", s.raceBest) or "🏁 No lap time yet — race needs " .. catalog.features.race.tierName
	end
end

-- ===== REBIRTH (bank) =====
do
	local m = modal("rebirth", "♻️  REBIRTH", 600, 540)
	local info = card(m.body, 130, 1, RGB(60, 35, 70))
	local t = label({Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 26), TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, info)
	local d = label({Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 44), TextSize = 13, TextColor3 = SUB, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Rebirth resets your cash, business levels, chains and staff. You KEEP reputation, land, your home, rentals, cars and trophies — and earn a permanent +10% income per rebirth."}, info)
	local btn = button({Position = UDim2.new(0, 14, 1, -48), Size = UDim2.new(1, -28, 0, 40), TextSize = 16, BackgroundColor3 = RGB(200, 80, 220)}, info)
	local confirming = false
	btn.MouseButton1Click:Connect(function()
		play(SND.click)
		if not C.S or not C.S.rebirth.unlocked then
			U.toast(C.lockText("rebirth"))
			return
		end
		if not confirming then
			confirming = true
			btn.Text = "⚠️ ARE YOU SURE? Click again to rebirth"
			task.delay(4, function() confirming = false end)
			return
		end
		confirming = false
		act("rebirth")
	end)
	header(m.body, "🎁 Rebirth perks", 2)
	local perkRows = {}
	m.update = function(s)
		local r = s.rebirth
		t.Text = "♻️ Rebirths: " .. r.count .. "   •   income bonus +" .. r.mult .. "%"
		if not confirming then
			btn.Text = r.unlocked and ("REBIRTH for $" .. fmt(r.cost)) or C.lockText("rebirth")
		end
		btn.BackgroundColor3 = (r.unlocked and s.cash >= r.cost) and RGB(200, 80, 220) or GRAY
		for i, p in ipairs(r.perks) do
			local e = perkRows[i]
			if not e then
				local c = card(m.body, 60, 2 + i)
				e = {c = c,
					a = label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 24), TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, c),
					b = label({Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 24), TextSize = 12, TextColor3 = SUB, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left}, c)}
				perkRows[i] = e
			end
			e.a.Text = p.icon .. " " .. p.at .. " REBIRTHS — " .. p.name .. (p.got and "  ✅" or "  🔒")
			e.a.TextColor3 = p.got and GOLD or WHITE
			e.b.Text = p.desc
		end
	end
end

-- ===== SETTINGS =====
do
	local m = modal("settings", "⚙️  SETTINGS", 560, 560)
	local rows = {}
	local function row(order, title, getText, onClick)
		local c = card(m.body, 52, order)
		label({Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -180, 1, 0), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = title}, c)
		local b = button({Position = UDim2.new(1, -160, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(150, 38), TextSize = 14, BackgroundColor3 = BLUE}, c)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			onClick()
			for _, r in ipairs(rows) do r.b.Text = r.get() end
		end)
		table.insert(rows, {b = b, get = getText})
		b.Text = getText()
	end
	local st = C.settings
	row(1, "🎵 Music", function() return st.music and "ON" or "OFF" end, function() C.setSetting("music", not st.music) end)
	row(2, "🔊 Music volume", function() return string.rep("▮", st.musicVol) .. string.rep("▯", 10 - st.musicVol) end,
		function() C.setSetting("musicVol", (st.musicVol % 10) + 1) end)
	row(3, "🔔 Sound effects", function() return st.sfx and "ON" or "OFF" end, function() C.setSetting("sfx", not st.sfx) end)
	row(4, "🚶 Crowds & traffic", function() return string.upper(st.crowd) end, function()
		C.setSetting("crowd", ({high = "low", low = "off", off = "high"})[st.crowd] or "high")
	end)
	row(5, "🌦️ Weather effects", function() return st.weather and "ON" or "OFF" end, function() C.setSetting("weather", not st.weather) end)
	row(6, "🚗 Speed units", function() return st.units end, function() C.setSetting("units", st.units == "MPH" and "KMH" or "MPH") end)
	row(7, "📍 Spawn at", function() return st.spawnAt == "home" and "🏠 Home" or "🏢 Business" end, function() C.setSetting("spawnAt", st.spawnAt == "home" and "business" or "home") end)
	row(8, "🎬 Cinematics", function() return ({full = "FULL", short = "SHORT", off = "OFF"})[st.cinematics or "full"] end, function()
		C.setSetting("cinematics", ({full = "short", short = "off", off = "full"})[st.cinematics or "full"] or "full")
	end)
	row(10, "🎓 Tutorial", function() return "Restart" end, function() act("tut", "restart") end)
	row(9, "🏢 Panels", function() return "Show all" end, function()
		if U.collapse_biz then U.collapse_biz(true) end
		if U.collapse_board then U.collapse_board(true) end
	end)
	if game:GetService("RunService"):IsStudio() then
		-- 🧪 Studio-only helpers for playtesting (the server ignores these in a live game)
		local tools = {{"🧪 +$1M", "cash"}, {"🧪 Next reputation tier", "rep"}, {"🧪 Start a mega event", "mega"}, {"🧪 Spawn a Mystery Lot", "mystery"},
			{"🧪 Finish a Spire stage", "spire"}, {"🧪 Go viral now", "viral"}, {"🧪 Save now", "save"},
			{"🧪 Update + data safety test", "dataTest"},
			-- v9
			{"🧪 Eviction cinematic", "cineEvict"}, {"🧪 Grand opening", "cineOpening"}, {"🧪 Influencer visit", "influencer"}, {"🧪 Viral moment", "viralMoment"},
			{"🧪 Rare event: paparazzi", "rareEvent"}, {"🧪 CityBuzz post", "buzzPost"}, {"🧪 Customer rush (THE CROWD)", "rush"}, {"🧪 Inspection", "inspection"},
			{"🧪 Funny random event", "funny"}, {"🧪 Enter a business interior", "interior"}, {"🧪 Cinematic camera", "cineCamera"}}
		for i, t in ipairs(tools) do
			row(100 + i, t[1], function() return "Run" end, function() act("debug", t[2]) end)
		end
		-- jump the story to the next chapter (plays its intro) to test cutscenes quickly
		row(120, "🧪 Story: jump to next chapter", function()
			local st = C.S and C.S.story
			return st and ("→ Ch " .. math.min(st.ch + 1, 7)) or "Run"
		end, function()
			local st = C.S and C.S.story
			act("debug", "story", st and math.min(st.ch + 1, 7) or 2)
		end)
	end
	C.U.refreshSettings = function()
		for _, r in ipairs(rows) do r.b.Text = r.get() end
	end
	local note = label({Size = UDim2.new(1, -8, 0, 36), TextSize = 12, TextColor3 = SUB, TextWrapped = true, LayoutOrder = 20}, m.body)
	m.update = function()
		note.Text = C.musicAvailable and "Music plays from the playlist in EmpireClient > Audio." or "🎵 No music added yet — the game owner pastes Roblox audio IDs into EmpireClient > Audio."
	end
	local menuConfirm = false
	local exitB = button({Size = UDim2.new(1, -8, 0, 46), LayoutOrder = 30, Text = "🏠 Save & return to Main Menu", TextSize = 15, BackgroundColor3 = RED}, m.body)
	exitB.MouseButton1Click:Connect(function()
		play(SND.click)
		if not menuConfirm then
			menuConfirm = true
			exitB.Text = "Click again to confirm"
			task.delay(3, function()
				menuConfirm = false
				exitB.Text = "🏠 Save & return to Main Menu"
			end)
			return
		end
		menuConfirm = false
		exitB.Text = "🏠 Save & return to Main Menu"
		m.frame.Visible = false
		act("menuExit")
	end)
end

-- ===== WEEKLY: leaderboards, Empire Showcase, House Tours =====
do
	local m = modal("weekly", "🏆  WEEKLY", 660, 580)
	local tabs = new("Frame", {Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0}, m.body)
	local box = autoFrame(m.body, 1)
	vlist(box, 6)
	local tab, info, lastFetch = "boards", nil, 0
	local function fmtValue(cat, v)
		if cat.unit == "time" then return string.format("%.2fs", v / 1000) end
		return fmt(v)
	end
	local function render()
		clear(box)
		local s = C.S
		if tab == "boards" then
			if not info then
				label({Size = UDim2.new(1, -8, 0, 30), Text = "Loading this week's boards...", TextSize = 13, TextColor3 = SUB}, box)
				return
			end
			local days = math.floor(info.endsIn / 86400)
			local hours = math.floor((info.endsIn % 86400) / 3600)
			label({Size = UDim2.new(1, -8, 0, 34), TextWrapped = true, TextSize = 12, TextColor3 = SUB, LayoutOrder = 0,
				Text = "Boards reset in " .. days .. "d " .. hours .. "h. Top 3 in each board win trophies next week (⭐ featured board pays double). Rewards are trophies & skins only."}, box)
			for i, cat in ipairs(info.categories) do
				local featured = cat.key == info.featured
				local c = card(box, 34 + math.max(1, math.min(5, #cat.list)) * 20, i, featured and RGB(70, 55, 20) or CARD)
				label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 24), Text = (featured and "⭐ FEATURED • " or "") .. cat.name, TextSize = 15, Font = Enum.Font.GothamBlack,
					TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = featured and GOLD or WHITE}, c)
				if #cat.list == 0 then
					label({Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 18), Text = "No entries yet — be the first!", TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left}, c)
				end
				for r = 1, math.min(5, #cat.list) do
					local e = cat.list[r]
					label({Position = UDim2.fromOffset(14, 30 + (r - 1) * 20), Size = UDim2.new(1, -28, 0, 18), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = e.userId == info.myId and GREEN or WHITE, Text = ({"🥇", "🥈", "🥉", "4.", "5."})[r] .. "  " .. e.name .. "   " .. fmtValue(cat, e.value)}, c)
				end
			end
		elseif tab == "showcase" then
			local top = card(box, 64, 0, RGB(60, 45, 20))
			label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -190, 1, -8), TextWrapped = true, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Show off your empire! Submit it (or use 📸 Photo Mode), then get other players to ❤️ it. The most-liked empire of the week wins 3 trophies."}, top)
			local sub = button({Position = UDim2.new(1, -170, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(160, 44), TextSize = 13, BackgroundColor3 = GOLD,
				Text = (info and info.submitted) and "🔄 Update my entry" or "🏆 Submit my empire"}, top)
			sub.MouseButton1Click:Connect(function() play(SND.click) act("showcaseSubmit") lastFetch = 0 end)
			local list = info and info.showcase or {}
			if #list == 0 then label({Size = UDim2.new(1, -8, 0, 30), Text = "No empires in the showcase yet this week.", TextSize = 13, TextColor3 = SUB, LayoutOrder = 1}, box) end
			for i, e in ipairs(list) do
				local c = card(box, 64, i)
				local inf = e.info or {}
				label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -140, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
					Text = (({"🥇", "🥈", "🥉"})[i] or (i .. ".")) .. " " .. e.name .. "   ❤️ " .. fmt(e.likes)}, c)
				label({Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -140, 0, 34), TextSize = 11, TextWrapped = true, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
					Text = "$" .. fmt(inf.income or 0) .. "/s • " .. (inf.businesses or 0) .. " businesses • " .. (inf.landmarks or 0) .. " landmarks • ♻️" .. (inf.rebirths or 0) .. " • " .. (inf.home or "") .. " • " .. (inf.tier or "")}, c)
				if e.userId ~= (info and info.myId) then
					local lk = button({Position = UDim2.new(1, -120, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(110, 40), Text = "❤️ Like", TextSize = 14, BackgroundColor3 = RGB(230, 70, 120)}, c)
					lk.MouseButton1Click:Connect(function() play(SND.click) act("showcaseLike", e.userId) lastFetch = 0 end)
				end
			end
		else
			label({Size = UDim2.new(1, -8, 0, 34), TextWrapped = true, TextSize = 12, TextColor3 = SUB, LayoutOrder = 0,
				Text = "Visit other players' homes in this server, then ❤️ like, ⭐ rate and 📌 favorite them. The best-rated house of the week wins Home of the Week."}, box)
			local tours = s and s.tours or {}
			local any = false
			for i, h in ipairs(tours) do
				if h.userId ~= plr.UserId then
					any = true
					local c = card(box, 56, i)
					label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -140, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
						Text = h.icon .. " " .. h.name .. "'s house"}, c)
					label({Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -140, 0, 20), TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left,
						Text = h.hood .. " • level " .. h.level .. " • ⭐ " .. string.format("%.1f", h.rating) .. " (" .. h.ratings .. ") • ❤️ " .. h.likes}, c)
					local v = button({Position = UDim2.new(1, -120, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(110, 40), Text = "📍 Visit", TextSize = 14, BackgroundColor3 = BLUE}, c)
					v.MouseButton1Click:Connect(function() play(SND.click) act("tourVisit", h.userId) m.frame.Visible = false end)
				end
			end
			if not any then label({Size = UDim2.new(1, -8, 0, 30), Text = "Nobody else in this server has built a house yet.", TextSize = 13, TextColor3 = SUB, LayoutOrder = 1}, box) end
			local favs = info and info.favorites or {}
			if #favs > 0 then
				header(box, "📌 Your favorite houses", 50)
				for i, f in ipairs(favs) do
					label({Size = UDim2.new(1, -8, 0, 20), TextSize = 12, LayoutOrder = 50 + i, TextXAlignment = Enum.TextXAlignment.Left,
						Text = "  " .. f.name .. (f.here and "  • in this server" or "  • not in this server")}, box)
				end
			end
		end
	end
	for i, t in ipairs({{"boards", "🏆 Leaderboards"}, {"showcase", "🏛️ Empire Showcase"}, {"tours", "🏠 House Tours"}}) do
		local b = button({Position = UDim2.new((i - 1) / 3, 3, 0, 0), Size = UDim2.new(1 / 3, -6, 1, 0), Text = t[2], TextSize = 13, BackgroundColor3 = GRAY}, tabs)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			tab = t[1]
			render()
		end)
	end
	local busy = false
	m.update = function()
		if busy then return end
		if os.clock() - lastFetch > 15 then
			busy = true
			lastFetch = os.clock()
			task.spawn(function()
				local ok, res = pcall(function() return C.GetCatalog:InvokeServer("weekly") end)
				if ok and type(res) == "table" then info = res end
				busy = false
				render()
			end)
		elseif tab == "tours" then
			-- tours come from the live state; redraw only when the list changes
			local key = ""
			for _, h in ipairs(C.S and C.S.tours or {}) do key ..= h.userId .. ":" .. h.likes .. ":" .. h.ratings .. ";" end
			if key ~= m.toursKey then
				m.toursKey = key
				render()
			end
		end
	end
end
end
