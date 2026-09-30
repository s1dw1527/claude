-- HUD: top bar, events, toasts, splash, war results, collapsible business panel + leaderboard,
-- problem card, delivery card, tutorial card.
return function(C)
local RunService = game:GetService("RunService")
local RGB = Color3.fromRGB
local new, tween, panel, label, button, card, bar, vlist, corner, stroke, gradient =
	C.new, C.tween, C.panel, C.label, C.button, C.card, C.bar, C.vlist, C.corner, C.stroke, C.gradient
local fmt, clock, play, SND, act, gui, U, plr = C.fmt, C.clock, C.play, C.SND, C.act, C.gui, C.U, C.plr
local BG, CARD, GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.BG, C.CARD, C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local R = C.R

local freezeOverlay = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(140, 210, 255), BackgroundTransparency = 1, BorderSizePixel = 0}, gui)
new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.55)})}, freezeOverlay)

-- ===== TOP BAR =====
do
	local top = panel({Position = UDim2.new(0.5, 0, 0, 56), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(760, 86)}, gui)
	gradient(top, RGB(40, 44, 64), RGB(20, 22, 32))
	label({Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(44, 44), Text = "💰", TextSize = 32}, top)
	local cashL = label({Position = UDim2.fromOffset(58, 6), Size = UDim2.fromOffset(260, 30), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, Text = "$0"}, top)
	local incL = label({Position = UDim2.fromOffset(58, 36), Size = UDim2.fromOffset(300, 18), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, TextColor3 = GREEN}, top)
	local multL = label({Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(370, 18), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 13, TextColor3 = SUB, TextTruncate = Enum.TextTruncate.AtEnd}, top)
	local tierL = label({Position = UDim2.new(1, -382, 0, 6), Size = UDim2.fromOffset(370, 24), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 19, Font = Enum.Font.GothamBlack, TextColor3 = GOLD}, top)
	local repFill = bar(top, UDim2.new(1, -382, 0, 34), UDim2.fromOffset(370, 9), GOLD)
	gradient(repFill, RGB(255, 170, 40), RGB(255, 235, 110), 0)
	local repL = label({Position = UDim2.new(1, -382, 0, 44), Size = UDim2.fromOffset(370, 16), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, TextColor3 = SUB, TextTruncate = Enum.TextTruncate.AtEnd}, top)
	local statsL = label({Position = UDim2.new(1, -382, 0, 60), Size = UDim2.fromOffset(370, 18), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd}, top)
	local shown, target, lastCash = 0, 0, nil
	RunService.RenderStepped:Connect(function(dt)
		shown += (target - shown) * math.clamp(dt * 8, 0, 1)
		if math.abs(target - shown) < 1 then shown = target end
		cashL.Text = "$" .. fmt(shown)
	end)
	local function floatText(text, color)
		local l = label({Text = text, TextColor3 = color, TextSize = 20, Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, -230, 0, 80), Size = UDim2.fromOffset(200, 30)}, gui)
		new("UIStroke", {Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3}, l)
		tween(l, 1.1, {Position = UDim2.new(0.5, -230, 0, 30), TextTransparency = 1})
		task.delay(1.1, function() l:Destroy() end)
	end
	C.onState(function(s)
		if lastCash then
			if s.cash > lastCash + 0.5 then floatText("+$" .. fmt(s.cash - lastCash), GREEN)
			elseif s.cash < lastCash - 0.5 then floatText("-$" .. fmt(lastCash - s.cash), RED) end
		end
		lastCash = s.cash
		target = s.cash
		incL.Text = "+$" .. fmt(s.income) .. "/sec"
		local m = {string.format("Boost x%.2f", s.gm)}
		if s.passMult > 1 then table.insert(m, "💎 x" .. s.passMult) end
		if s.rebirth.count > 0 then table.insert(m, "♻️ +" .. s.rebirth.mult .. "%") end
		if s.buffMult then table.insert(m, string.format("⚔️ x%.1f %s", s.buffMult, clock(s.buffLeft))) end
		if s.adName then table.insert(m, "📣 " .. clock(s.adLeft)) end
		if s.relaxedLeft > 0 then table.insert(m, "🎡 " .. clock(s.relaxedLeft)) end
		if s.trending then table.insert(m, "📱 TRENDING") end
		multL.Text = table.concat(m, "   ")
		tierL.Text = "⭐ " .. s.tierName
		if s.nextRep then
			repFill.Size = UDim2.fromScale(math.clamp((s.rep - s.prevRep) / (s.nextRep - s.prevRep), 0, 1), 1)
			repL.Text = fmt(s.rep) .. "/" .. fmt(s.nextRep) .. " rep → " .. s.nextName .. " unlocks " .. table.concat(s.nextUnlocks or {}, ", ")
		else
			repFill.Size = UDim2.fromScale(1, 1)
			repL.Text = fmt(s.rep) .. " reputation  •  MAX TIER"
		end
		statsL.Text = string.format("🏆 %d  ♻️ %d  👥 %s followers  ⭐ %.1f  🏙️ %d%%", s.trophies, s.rebirth.count, fmt(s.followers), s.stars, math.floor(s.cityPct + 0.5))
		tween(freezeOverlay, 0.4, {BackgroundTransparency = s.frozen > 0 and 0.35 or 1})
	end)
end

-- ===== EVENT BANNER + TICKER + TOAST =====
do
	local eventBar = panel({Position = UDim2.new(0.5, 0, 0, 148), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(760, 30)}, gui)
	local eventL = label({Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -200, 1, 0), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, eventBar)
	local warL = label({Position = UDim2.new(1, -190, 0, 0), Size = UDim2.new(0, 180, 1, 0), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GOLD, Font = Enum.Font.GothamBlack}, eventBar)
	U.ticker = label({Position = UDim2.new(0.5, 0, 0, 182), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(760, 20), TextSize = 13, TextColor3 = RGB(255, 170, 230), TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.5}, gui)
	C.onState(function(s)
		local t = s.eventText
		local col = BG
		if s.frozen > 0 then
			t, col = "❄️  YOUR INCOME IS FROZEN (" .. s.frozen .. "s)", RGB(60, 130, 200)
		elseif s.eventLeft then
			t = t .. "  (" .. s.eventLeft .. "s)"
			if s.crash or t:find("RECESSION") or t:find("TAX") then col = RGB(140, 45, 55)
			elseif t:find("SNOW") then col = RGB(60, 110, 170)
			elseif t:find("VIRAL") or t:find("CONCERT") then col = RGB(150, 50, 130)
			else col = RGB(150, 110, 20) end
		else
			t = "📰 " .. t .. "   •   Next city event in " .. s.nextEvent .. "s"
		end
		eventBar.BackgroundColor3 = col
		eventL.Text = t
		warL.Text = "⚔️ CORNER WAR " .. clock(s.warLeft)
	end)
	local toast = panel({Position = UDim2.new(0.5, 0, 0, -60), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(640, 52), BackgroundColor3 = RGB(45, 70, 140), Visible = false, ZIndex = 50}, gui)
	gradient(toast, RGB(80, 120, 230), RGB(40, 60, 140))
	local toastL = label({Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 16, TextWrapped = true, Font = Enum.Font.GothamBlack, ZIndex = 51}, toast)
	local id = 0
	function U.toast(msg)
		id += 1
		local mine = id
		toastL.Text = msg
		toast.Visible = true
		toast.Position = UDim2.new(0.5, 0, 0, -60)
		tween(toast, 0.4, {Position = UDim2.new(0.5, 0, 0, 208)}, Enum.EasingStyle.Back)
		play(SND.event)
		task.delay(5, function()
			if id ~= mine then return end
			tween(toast, 0.3, {Position = UDim2.new(0.5, 0, 0, -60)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.3, function() if id == mine then toast.Visible = false end end)
		end)
	end
	R.Announce.OnClientEvent:Connect(U.toast)
end

-- ===== SPLASH + CONFETTI + WAR RESULTS =====
do
	local frame = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 60}, gui)
	local title = label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.9, 0, 0, 90), TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 61}, frame)
	new("UIStroke", {Thickness = 4, Color = RGB(40, 25, 0)}, title)
	local sub = label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.new(0.8, 0, 0, 60), TextScaled = true, TextWrapped = true, ZIndex = 61}, frame)
	new("UIStroke", {Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3}, sub)
	local sc = new("UIScale", {}, title)
	function U.confetti(n)
		for _ = 1, n or 60 do
			local c = new("Frame", {Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)), Position = UDim2.new(math.random(), 0, -0.05, 0),
				BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1), BorderSizePixel = 0, Rotation = math.random(0, 360), ZIndex = 62}, gui)
			local t = 2.5 + math.random() * 2
			tween(c, t, {Position = UDim2.new(c.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0), Rotation = c.Rotation + math.random(-540, 540)}, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			task.delay(t, function() c:Destroy() end)
		end
	end
	local sid = 0
	function U.splash(t, s, color)
		sid += 1
		local mine = sid
		title.Text = t
		sub.Text = s or ""
		sub.TextColor3 = color or WHITE
		title.TextColor3 = color or GOLD
		frame.Visible = true
		frame.BackgroundTransparency = 1
		sc.Scale = 0.2
		tween(frame, 0.4, {BackgroundTransparency = 0.55})
		tween(sc, 0.6, {Scale = 1}, Enum.EasingStyle.Back)
		play(SND.event)
		U.confetti(50)
		task.delay(4.5, function()
			if sid ~= mine then return end
			tween(frame, 0.5, {BackgroundTransparency = 1})
			task.delay(0.5, function() if sid == mine then frame.Visible = false end end)
		end)
	end
	R.Splash.OnClientEvent:Connect(U.splash)
	local war = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 360), Visible = false, ZIndex = 65}, gui)
	gradient(war, RGB(70, 50, 20), RGB(25, 20, 12))
	stroke(war, GOLD, 3, 0)
	label({Size = UDim2.new(1, 0, 0, 56), Text = "🏆 CORNER WAR RESULTS 🏆", TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 66}, war)
	local rows = {}
	for i = 1, 5 do
		local r = new("Frame", {Position = UDim2.fromOffset(16, 58 + (i - 1) * 52), Size = UDim2.new(1, -32, 0, 46), BackgroundColor3 = RGB(50, 40, 20), BorderSizePixel = 0, ZIndex = 66}, war)
		corner(r, 8)
		rows[i] = {
			cat = label({Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, ZIndex = 67}, r),
			who = label({Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 67}, r),
		}
	end
	R.WarResults.OnClientEvent:Connect(function(results)
		for i, r in ipairs(rows) do
			local e = results[i]
			r.cat.Text = e and e.cat or ""
			r.who.Text = e and (e.name .. "  (" .. e.value .. ")") or ""
		end
		war.Visible = true
		play(SND.event)
		U.confetti(80)
		task.delay(9, function() war.Visible = false end)
	end)
end

-- collapsible panel helper (the "—" button minimizes a panel down to its title bar)
local function collapsible(p, titleText, fullSize, key)
	label({Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -60, 0, 36), Text = titleText, TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, p)
	local btn = button({Position = UDim2.new(1, -40, 0, 5), Size = UDim2.fromOffset(30, 26), Text = "—", TextSize = 16, BackgroundColor3 = GRAY}, p)
	local body = new("Frame", {Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38), BackgroundTransparency = 1}, p)
	local open = true
	local function set(v)
		open = v
		body.Visible = v
		btn.Text = v and "—" or "+"
		tween(p, 0.25, {Size = v and fullSize or UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 38)})
	end
	btn.MouseButton1Click:Connect(function()
		play(SND.click)
		set(not open)
	end)
	U["collapse_" .. key] = set
	return body
end

-- ===== BUSINESS PANEL (left, collapsible) =====
do
	local full = UDim2.new(0, 350, 1, -232)
	local p = panel({Position = UDim2.new(0, 12, 0, 214), Size = full, ClipsDescendants = true}, gui)
	local body = collapsible(p, "🏢  YOUR BUSINESSES", full, "biz")
	local list = new("ScrollingFrame", {Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 1, -6), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, body)
	vlist(list, 6)
	local rows = {}
	C.onState(function(s)
		for i, b in ipairs(s.biz) do
			local r = rows[i]
			if not r then
				local row = card(list, 80, i)
				local accent = new("Frame", {Size = UDim2.new(0, 5, 1, -14), Position = UDim2.fromOffset(5, 7), BackgroundColor3 = b.color, BorderSizePixel = 0}, row)
				corner(accent, 3)
				local ic = new("Frame", {Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = b.color, BackgroundTransparency = 0.7, BorderSizePixel = 0}, row)
				corner(ic, 23)
				r = {row = row, color = b.color, level = -1, stage = -1}
				r.icon = label({Size = UDim2.fromScale(1, 1), Text = b.icon, TextSize = 26}, ic)
				r.name = label({Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -168, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, Font = Enum.Font.GothamBlack, TextTruncate = Enum.TextTruncate.AtEnd}, row)
				r.info = label({Position = UDim2.fromOffset(70, 26), Size = UDim2.new(1, -168, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, TextColor3 = SUB, TextTruncate = Enum.TextTruncate.AtEnd}, row)
				r.tags = label({Position = UDim2.fromOffset(70, 42), Size = UDim2.new(1, -168, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, TextColor3 = GOLD}, row)
				r.pips = {}
				for k = 1, 10 do
					local pip = new("Frame", {Position = UDim2.fromOffset(70 + (k - 1) * 8, 60), Size = UDim2.fromOffset(6, 9), BackgroundColor3 = GRAY, BorderSizePixel = 0}, row)
					corner(pip, 2)
					r.pips[k] = pip
				end
				r.btn = button({Position = UDim2.new(1, -92, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(84, 58), TextSize = 12, TextWrapped = true}, row)
				r.btn.MouseButton1Click:Connect(function()
					play(SND.click)
					if r.mode == "buy" then act("buy", b.key) elseif r.mode == "chain" then act("chain", b.key)
					elseif r.mode == "locked" then U.toast("🔒 " .. b.name .. " unlocks at " .. r.unlockName .. " reputation. Keep earning good reviews!") end
				end)
				rows[i] = r
			end
			r.unlockName = b.unlockName
			r.row.BackgroundTransparency = b.locked and 0.4 or 0
			r.icon.TextTransparency = b.locked and 0.6 or 0
			if b.locked then
				r.name.Text = "🔒 " .. b.name
				r.info.Text = "Unlocks at " .. b.unlockName
			else
				r.name.Text = b.level > 0 and b.name or (b.name .. "  (not open)")
				if b.level > 0 then
					r.info.Text = "$" .. fmt(b.income) .. "/s  •  Lv " .. b.level .. "/" .. s.maxLevel .. (b.chains > 0 and ("  •  📍" .. (b.chains + 1)) or "")
				else
					r.info.Text = "Earns $" .. fmt(b.unit) .. "/s per level"
				end
			end
			local tags = {}
			if b.staffStars > 0 then table.insert(tags, "👤 staff ★" .. b.staffStars) end
			if b.problem then table.insert(tags, "⚠️ PROBLEM (-50%)") end
			if b.stage == 6 then table.insert(tags, "🌟 LANDMARK") end
			r.tags.Text = table.concat(tags, "   ")
			r.tags.TextColor3 = b.problem and RED or GOLD
			for k, pip in ipairs(r.pips) do
				pip.BackgroundColor3 = k <= b.level and (b.level >= s.maxLevel and GOLD or r.color) or GRAY
			end
			if r.level >= 0 and (b.level > r.level or b.stage > r.stage) then
				play(SND.buy)
				r.row.BackgroundColor3 = r.color
				tween(r.row, 0.6, {BackgroundColor3 = CARD})
			end
			r.level, r.stage = b.level, b.stage
			if b.locked then
				r.mode = "locked"
				r.btn.Text = "🔒\nLOCKED"
				r.btn.BackgroundColor3 = GRAY
			elseif b.cost >= 0 then
				r.mode = "buy"
				r.btn.Text = (s.crash and "🔥SALE " or "") .. (b.level == 0 and "BUY" or "UPGRADE") .. "\n$" .. fmt(b.cost)
				r.btn.BackgroundColor3 = s.cash >= b.cost and GREEN or GRAY
			elseif b.chainCost then
				r.mode = "chain"
				r.btn.Text = "📍 OPEN #" .. (b.chains + 2) .. "\n" .. b.chainName .. "\n$" .. fmt(b.chainCost)
				r.btn.BackgroundColor3 = s.cash >= b.chainCost and PURPLE or GRAY
			elseif b.stage == 6 then
				r.mode = nil
				r.btn.Text = "🌟\nLANDMARK"
				r.btn.BackgroundColor3 = RGB(190, 145, 30)
			else
				r.mode = nil
				r.btn.Text = "⭐ MAX\n(chains at\nCITY ICON)"
				r.btn.BackgroundColor3 = RGB(190, 145, 30)
			end
		end
	end)
end

-- ===== LEADERBOARD (right, collapsible) =====
do
	local full = UDim2.fromOffset(290, 318)
	local p = panel({Position = UDim2.new(1, -12, 0, 214), AnchorPoint = Vector2.new(1, 0), Size = full, ClipsDescendants = true}, gui)
	local body = collapsible(p, "🏆  CITY LEADERBOARD", full, "board")
	local MEDALS = {"🥇", "🥈", "🥉", "4."}
	local rows = {}
	for i = 1, 4 do
		local row = card(body, 58)
		row.Position = UDim2.fromOffset(10, (i - 1) * 62)
		row.Size = UDim2.new(1, -20, 0, 56)
		row.Visible = false
		local sw = new("Frame", {Size = UDim2.new(0, 5, 1, -14), Position = UDim2.fromOffset(5, 7), BorderSizePixel = 0}, row)
		corner(sw, 3)
		label({Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(30, 56), Text = MEDALS[i], TextSize = 22}, row)
		local r = {frame = row, swatch = sw, userId = 0}
		r.name = label({Position = UDim2.fromOffset(44, 5), Size = UDim2.new(1, -140, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, Font = Enum.Font.GothamBlack, TextTruncate = Enum.TextTruncate.AtEnd}, row)
		r.tier = label({Position = UDim2.fromOffset(44, 22), Size = UDim2.new(1, -140, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, TextColor3 = GOLD, TextTruncate = Enum.TextTruncate.AtEnd}, row)
		r.inc = label({Position = UDim2.fromOffset(44, 37), Size = UDim2.new(1, -140, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11, TextColor3 = SUB}, row)
		r.btn = button({Position = UDim2.new(1, -88, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(80, 36), TextSize = 12, Text = "❄ Freeze"}, row)
		r.btn.MouseButton1Click:Connect(function()
			play(SND.click)
			if C.locked("sabotage") then U.toast(C.lockText("sabotage")) return end
			act("sabotage", r.userId)
		end)
		rows[i] = r
	end
	local info = label({Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 34), TextSize = 11, TextWrapped = true, TextColor3 = SUB}, body)
	C.onState(function(s)
		for i, r in ipairs(rows) do
			local e = s.standings[i]
			r.frame.Visible = e ~= nil
			if e then
				r.userId = e.userId
				r.swatch.BackgroundColor3 = e.color
				r.name.Text = e.name .. (e.userId == plr.UserId and " (you)" or "")
				r.tier.Text = "⭐ " .. e.tier .. (e.rebirths > 0 and ("  ♻️" .. e.rebirths) or "")
				r.inc.Text = "$" .. fmt(e.income) .. "/sec"
				r.frame.BackgroundColor3 = e.userId == plr.UserId and RGB(48, 70, 58) or CARD
				r.btn.Visible = e.userId ~= plr.UserId
				if s.sabCd > 0 then
					r.btn.Text = "⏳ " .. s.sabCd .. "s"
					r.btn.BackgroundColor3 = GRAY
				else
					r.btn.Text = s.unlocks.sabotage and "❄ Freeze" or "🔒"
					r.btn.BackgroundColor3 = (s.unlocks.sabotage and s.cash >= s.sabCost) and BLUE or GRAY
				end
			end
		end
		info.Text = "❄ Freeze costs $" .. fmt(s.sabCost) .. " and stops a rival's income for " .. s.sabTime .. "s."
	end)
end

-- ===== PROBLEM CARD + DELIVERY CARD =====
do
	local pc = panel({Position = UDim2.new(1, -312, 0, 214), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(290, 150), BackgroundColor3 = RGB(70, 30, 30), Visible = false}, gui)
	stroke(pc, RED, 2, 0)
	local pt = label({Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 200, 120)}, pc)
	local pd = label({Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 36), TextSize = 13, TextWrapped = true}, pc)
	local cur
	local function b(text, x, color, choice)
		local bt = button({Position = UDim2.new(x, 4, 1, -64), Size = UDim2.new(1 / 3, -8, 0, 54), TextSize = 12, TextWrapped = true, BackgroundColor3 = color, Text = text}, pc)
		bt.MouseButton1Click:Connect(function()
			play(SND.click)
			if cur then act("problem", cur, choice) end
		end)
		return bt
	end
	local rep = b("", 0, BLUE, "repair")
	local rpl = b("", 1 / 3, GREEN, "replace")
	b("🙈 Ignore\n-50% for 2m", 2 / 3, GRAY, "ignore")
	C.onState(function(s)
		local p
		for _, pr in ipairs(s.problems) do
			if pr.state == "new" then
				p = pr
				break
			end
		end
		pc.Visible = p ~= nil
		if not p then
			cur = nil
			return
		end
		cur = p.key
		pt.Text = "⚠️ PROBLEM at your " .. p.biz
		pd.Text = p.icon .. " " .. p.text .. "  (earning -50% until fixed)"
		rep.Text = "🔧 Repair\n$" .. fmt(p.repair)
		rpl.Text = "✨ Replace\n$" .. fmt(p.replace)
	end)

	local dc = panel({Position = UDim2.new(1, -12, 1, -230), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(290, 128), BackgroundColor3 = RGB(25, 60, 40), Visible = false}, gui)
	stroke(dc, GREEN, 2, 0)
	local dt = label({Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextColor3 = RGB(150, 255, 170)}, dc)
	local dd = label({Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 34), TextSize = 13, TextWrapped = true}, dc)
	local dr = label({Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 18), TextSize = 13, TextColor3 = GOLD}, dc)
	local acc = button({Position = UDim2.new(0, 8, 1, -42), Size = UDim2.new(0.5, -12, 0, 34), Text = "✅ ACCEPT", TextSize = 14}, dc)
	local dec = button({Position = UDim2.new(0.5, 4, 1, -42), Size = UDim2.new(0.5, -12, 0, 34), Text = "Decline", TextSize = 14, BackgroundColor3 = GRAY}, dc)
	acc.MouseButton1Click:Connect(function() play(SND.click) act("delivery", "accept") end)
	dec.MouseButton1Click:Connect(function() play(SND.click) act("delivery", "decline") end)
	C.onState(function(s)
		local d = s.delivery
		dc.Visible = d ~= nil
		if not d then
			if U.setBeamTarget then U.setBeamTarget("delivery", nil) end
			return
		end
		dd.Text = d.text
		if d.state == "offer" then
			dt.Text = "📦 DELIVERY REQUEST"
			dr.Text = "Reward: $" .. fmt(d.reward) .. "   •   answer in " .. d.left .. "s"
			acc.Visible, dec.Visible = true, true
			if U.setBeamTarget then U.setBeamTarget("delivery", nil) end
		else
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			local dist = root and math.floor((root.Position - d.pos).Magnitude) or 0
			dt.Text = "🚚 DELIVERING...  " .. clock(d.left)
			dr.Text = "Reward: $" .. fmt(d.reward) .. "   •   " .. dist .. " studs away"
			acc.Visible, dec.Visible = false, false
			if U.setBeamTarget then U.setBeamTarget("delivery", d.pos) end
		end
	end)
end

-- ===== TUTORIAL CARD =====
do
	local tc = panel({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(540, 96), BackgroundColor3 = RGB(30, 70, 140), Visible = false}, gui)
	gradient(tc, RGB(70, 130, 230), RGB(30, 60, 140))
	stroke(tc, RGB(150, 200, 255), 2, 0)
	local title = label({Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -120, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, tc)
	local body = label({Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 56), TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, tc)
	local skip = button({Position = UDim2.new(1, -96, 0, 6), Size = UDim2.fromOffset(84, 24), Text = "Skip tutorial", TextSize = 11, BackgroundColor3 = GRAY}, tc)
	skip.MouseButton1Click:Connect(function()
		play(SND.click)
		act("tut", "skip")
		tc.Visible = false
	end)
	local lastStep
	C.onState(function(s)
		local t = s.tut
		tc.Visible = t ~= nil
		if U.setBeamTarget then U.setBeamTarget("tut", t and t.target or nil) end
		if not t then return end
		title.Text = "🎓 TUTORIAL  •  Step " .. t.step .. " of " .. t.total
		body.Text = t.text
		if lastStep ~= t.step then
			lastStep = t.step
			tc.Position = UDim2.new(0.5, 0, 1, 120)
			tween(tc, 0.5, {Position = UDim2.new(0.5, 0, 1, -16)}, Enum.EasingStyle.Back)
		end
	end)
end
end
