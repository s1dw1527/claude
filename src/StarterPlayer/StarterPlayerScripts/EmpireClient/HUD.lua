-- HUD: top bar, events, toasts, splash, war results, collapsible business panel + leaderboard,
-- problem card, delivery card, tutorial card.
return function(C)
local RunService = game:GetService("RunService")
local RGB = Color3.fromRGB
local new, tween, panel, label, button, card, bar, vlist, corner, stroke, gradient =
	C.new, C.tween, C.panel, C.label, C.button, C.card, C.bar, C.vlist, C.corner, C.stroke, C.gradient
local fmt, clock, play, SND, act, gui, U, plr = C.fmt, C.clock, C.play, C.SND, C.act, C.gui, C.U, C.plr
local BG, CARD, GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.BG, C.CARD, C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local clear = C.clear
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
	-- v11.1 PHONE LAYOUT: one compact row instead of the big bar.
	--   [ 💰 $4.50M  +$37.0K/s ]            [ ⭐ LEGENDARY  9,859 REP ]
	-- Tap either side for the full details (the 📊 MY EMPIRE window). Desktop keeps the bar above.
	local Lay = C.Layout
	local row1 = new("Frame", {Name = "CompactHUD", BackgroundTransparency = 1, Visible = false, ZIndex = Lay.Z.hud}, gui)
	local function pill(color)
		local b = new("TextButton", {BackgroundColor3 = BG, BackgroundTransparency = 0.15, BorderSizePixel = 0, Text = "", AutoButtonColor = true, Size = UDim2.fromScale(0.5, 1)}, row1)
		corner(b, 10)
		stroke(b, color, 1.5, 0.4)
		return b
	end
	local function fitText(l, max, min)
		l.TextScaled = true
		new("UITextSizeConstraint", {MaxTextSize = max, MinTextSize = min or 9}, l)
		return l
	end
	local cashPill = pill(GOLD)
	cashPill.Name = "CashPill"
	local cCash = fitText(label({Position = UDim2.fromOffset(8, 4), Size = UDim2.new(0.56, -8, 1, -8), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, Text = "$0"}, cashPill), 22, 12)
	local cInc = fitText(label({Position = UDim2.new(0.56, 0, 0, 8), Size = UDim2.new(0.44, -8, 1, -16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GREEN, Text = ""}, cashPill), 15, 9)
	local tierPill = pill(RGB(255, 170, 40))
	tierPill.Name = "TierBadge"
	local cTier = fitText(label({Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0.55, -3), TextColor3 = GOLD, Font = Enum.Font.GothamBlack, Text = "⭐"}, tierPill), 14, 9)
	local cRep = fitText(label({Position = UDim2.new(0, 8, 0.55, 0), Size = UDim2.new(1, -16, 0.45, -3), TextColor3 = SUB, Text = ""}, tierPill), 11, 8)
	local cRepFill = bar(tierPill, UDim2.new(0, 6, 1, -4), UDim2.new(1, -12, 0, 2), GOLD)
	-- the short tier name for the badge ("LEGENDARY DISTRICT" → "LEGENDARY")
	local SHORT = {["UNKNOWN CORNER"] = "UNKNOWN", ["LOCAL FAVORITE"] = "LOCAL FAV", ["LEGENDARY DISTRICT"] = "LEGENDARY"}
	C.shortTier = function(name) return SHORT[name] or name end
	local function openDetails()
		play(SND.click)
		C.openModal("empire")
	end
	-- rent day (every 30 s): say where the money came from
	R.Customer.OnClientEvent:Connect(function(c)
		if type(c) ~= "table" or not c.rent then return end
		local net = (c.rent or 0) - (c.upkeep or 0)
		local l = label({Name = "MoneyFloat", Text = "🏢 Rent " .. (net >= 0 and "+$" or "-$") .. fmt(math.abs(net)), TextColor3 = net >= 0 and RGB(150, 220, 255) or RED, TextSize = 16,
			Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(220, 26), ZIndex = Lay.Z.toast,
			Position = Lay.compact and UDim2.fromOffset(Lay.safe.l + 110, Lay.safe.t + Lay.ROW1 + 64) or UDim2.new(0.5, -230, 0, 108)}, gui)
		new("UIStroke", {Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3}, l)
		tween(l, 2, {Position = l.Position - UDim2.fromOffset(0, 30), TextTransparency = 1})
		task.delay(2, function() l:Destroy() end)
	end)
	cashPill.MouseButton1Click:Connect(openDetails)
	tierPill.MouseButton1Click:Connect(openDetails)
	U.compactHUD = row1
	Lay.onChange(function(L)
		top.Visible = not L.compact
		row1.Visible = L.compact
		if not L.compact then return end
		local s, vp = L.safe, L.vp
		local w = vp.X - s.l - s.r
		row1.Position = UDim2.fromOffset(s.l, s.t)
		row1.Size = UDim2.fromOffset(w, L.ROW1)
		local tw = math.clamp(w * 0.4, 118, 190)
		cashPill.Size = UDim2.fromOffset(w - tw - 6, L.ROW1)
		tierPill.Position = UDim2.fromOffset(w - tw, 0)
		tierPill.Size = UDim2.fromOffset(tw, L.ROW1)
	end)
	local shown, target, lastCash = 0, 0, nil
	RunService.RenderStepped:Connect(function(dt)
		if shown == target then return end
		shown += (target - shown) * math.clamp(dt * 8, 0, 1)
		if math.abs(target - shown) < 1 then shown = target end
		cashL.Text = "$" .. fmt(shown)
		cCash.Text = "$" .. fmt(shown)
	end)
	local function floatText(text, color)
		-- (phone layout: it rises from under the cash pill instead of from the desktop bar's spot)
		local from, to = UDim2.new(0.5, -230, 0, 80), UDim2.new(0.5, -230, 0, 30)
		if Lay.compact then
			local x, y = Lay.safe.l + 90, Lay.safe.t + Lay.ROW1 + 40
			from, to = UDim2.fromOffset(x, y), UDim2.fromOffset(x, y - 34)
		end
		local l = label({Name = "MoneyFloat", Text = text, TextColor3 = color, TextSize = 20, Font = Enum.Font.GothamBlack, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = from, Size = UDim2.fromOffset(200, 30), ZIndex = Lay.Z.toast}, gui)
		new("UIStroke", {Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3}, l)
		tween(l, 1.1, {Position = to, TextTransparency = 1})
		task.delay(1.1, function() l:Destroy() end)
	end
	C.onState(function(s)
		if lastCash then
			if s.cash > lastCash + 0.5 then floatText("+$" .. fmt(s.cash - lastCash), GREEN)
			elseif s.cash < lastCash - 0.5 then floatText("-$" .. fmt(lastCash - s.cash), RED) end
		end
		lastCash = s.cash
		target = s.cash
		-- (v11.2: apartment rent is part of what you earn, so it's shown too)
		local rent = s.rentRate or 0
		incL.Text = "+$" .. fmt(s.income) .. "/sec" .. (rent ~= 0 and ("   🏢 " .. (rent > 0 and "+" or "-") .. "$" .. fmt(math.abs(rent)) .. "/s rent") or "")
		cInc.Text = "+$" .. fmt(s.income + math.max(0, rent)) .. "/s"
		if shown == target then cCash.Text = "$" .. fmt(s.cash) cashL.Text = "$" .. fmt(s.cash) end
		cTier.Text = "⭐ " .. C.shortTier(s.tierName)
		cRep.Text = fmt(s.rep) .. " REP"
		cRepFill.Size = UDim2.fromScale(s.nextRep and math.clamp((s.rep - s.prevRep) / (s.nextRep - s.prevRep), 0, 1) or 1, 1)
		local m = {string.format("Boost x%.2f", s.gm)}
		if s.passMult > 1 then table.insert(m, "💎 x" .. s.passMult) end
		if s.rebirth.count > 0 then table.insert(m, "♻️ +" .. s.rebirth.mult .. "%") end
		if s.buffMult then table.insert(m, string.format("⚔️ x%.1f %s", s.buffMult, clock(s.buffLeft))) end
		if s.adName then table.insert(m, "📣 " .. clock(s.adLeft)) end
		if s.relaxedLeft > 0 then table.insert(m, "🎡 " .. clock(s.relaxedLeft)) end
		if s.trending then table.insert(m, "📱 TRENDING") end
		if (s.viralLeft or 0) > 0 then table.insert(m, "🔥 VIRAL " .. clock(s.viralLeft)) end
		if (s.postBuffLeft or 0) > 0 then table.insert(m, string.format("📈 post x%.2f %s", s.postBuffMult or 1, clock(s.postBuffLeft))) end
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
	local chip, chipL
	local Lay = C.Layout
	local eventBar = panel({Position = UDim2.new(0.5, 0, 0, 148), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(760, 30)}, gui)
	local eventL = label({Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -200, 1, 0), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, eventBar)
	local warL = label({Position = UDim2.new(1, -190, 0, 0), Size = UDim2.new(0, 180, 1, 0), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GOLD, Font = Enum.Font.GothamBlack}, eventBar)
	U.ticker = label({Position = UDim2.new(0.5, 0, 0, 182), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(760, 20), TextSize = 13, TextColor3 = RGB(255, 170, 230), TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.5}, gui)
	-- v11.1 phone layout: a small event chip in HUD row 2 (tap → 📊 MY EMPIRE), and CityBuzz as a short-lived
	-- notification (4 s, tap → the CityBuzz app) instead of a permanent ticker
	chip = new("TextButton", {Name = "EventChip", Size = UDim2.fromOffset(160, 30), BackgroundColor3 = BG, BorderSizePixel = 0, Text = "", AutoButtonColor = true}, gui)
	corner(chip, 8)
	chipL = label({Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 1, 0), TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd}, chip)
	chip.MouseButton1Click:Connect(function() play(SND.click) C.openModal("empire") end)
	Lay.slot(chip, "row2", 2, {compactOnly = true, size = function(L) return UDim2.fromOffset(math.floor((L.vp.X - L.safe.l - L.safe.r) * 0.46), L.ROW2) end})
	local note = new("TextButton", {Name = "BuzzNote", Size = UDim2.fromOffset(340, 34), BackgroundColor3 = RGB(120, 30, 80), BorderSizePixel = 0, Text = "", AutoButtonColor = true, Visible = false}, gui)
	corner(note, 10)
	local noteL = label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, note)
	Lay.slot(note, "top", 1)
	local noteId = 0
	function U.buzzNote(p)
		if not Lay.compact or type(p) ~= "table" then return end
		noteId += 1
		local mine = noteId
		noteL.Text = "📣 CityBuzz: " .. tostring(p.icon or "") .. " " .. tostring(p.text or "")
		note.Visible = true
		task.delay(4, function() if noteId == mine then note.Visible = false end end)
	end
	note.MouseButton1Click:Connect(function()
		play(SND.click)
		note.Visible = false
		if C.togglePhone then C.togglePhone(true) C.phoneView("buzz") end
	end)
	Lay.onChange(function(L)
		eventBar.Visible = not L.compact
		U.ticker.Visible = not L.compact
		if not L.compact then note.Visible = false end
	end)
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
		-- phone: the short version in the event chip
		if s.frozen > 0 then
			chipL.Text = "❄️ FROZEN " .. s.frozen .. "s"
		elseif s.eventLeft then
			chipL.Text = (s.eventText or ""):gsub("%s*%(.-%)", "") .. " " .. clock(s.eventLeft)
		else
			chipL.Text = "📰 Next event " .. clock(s.nextEvent or 0)
		end
		chip.BackgroundColor3 = col
	end)
	local toast = panel({Position = UDim2.new(0.5, 0, 0, -60), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(640, 52), BackgroundColor3 = RGB(45, 70, 140), Visible = false, ZIndex = Lay.Z.toast}, gui)
	-- phone: full safe width, just under the top row (over row 2, which it covers for 5 s)
	local toastY = 208
	gradient(toast, RGB(80, 120, 230), RGB(40, 60, 140))
	local toastL = label({Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 16, TextWrapped = true, Font = Enum.Font.GothamBlack, ZIndex = 51}, toast)
	-- (v11.2: smaller on a phone, and the text shrinks to fit instead of spilling out of the box)
	local toastCap
	Lay.onChange(function(L)
		toastY = L.compact and (L.safe.t + L.ROW1 + 4) or 208
		toast.Size = L.compact and UDim2.fromOffset(math.min(640, L.vp.X - L.safe.l - L.safe.r), 46) or UDim2.fromOffset(640, 52)
		if toast.Visible then toast.Position = UDim2.new(0.5, 0, 0, toastY) end
		if toastL then
			toastL.TextScaled = L.compact
			toastCap = toastCap or new("UITextSizeConstraint", {MaxTextSize = 14, MinTextSize = 10}, toastL)
		end
	end)
	local id = 0
	function U.toast(msg)
		id += 1
		local mine = id
		toastL.Text = msg
		toast.Visible = true
		toast.Position = UDim2.new(0.5, 0, 0, -60)
		tween(toast, 0.4, {Position = UDim2.new(0.5, 0, 0, toastY)}, Enum.EasingStyle.Back)
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
	war.Name = "WarResults"
	C.Layout.window("warResults", war, {fixed = true, major = false})
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
	-- phone: the panel is a window opened from an edge button, so "—" becomes a big ✕
	local x = button({Position = UDim2.new(1, -46, 0, 2), Size = UDim2.fromOffset(42, 34), Text = "X", TextSize = 18, BackgroundColor3 = RED, Visible = false}, p)
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
	return body, function(compact)
		btn.Visible = not compact
		x.Visible = compact
		if compact then
			open = true
			body.Visible = true
			btn.Text = "—"
		end
	end, x
end

-- v11.1 phone layout: the business panel and the leaderboard become windows behind small edge buttons
-- (🏪 Lv 10, 🏆 #2). One window at a time; they never sit on top of the game.
local Lay = C.Layout
local function sheet(name, p, full, maxW, maxH, onCompact, closeBtn, edgeBtn)
	local sc = Lay.scaleOf(p)
	local isOpen = false
	local designPos, designAnchor = p.Position, p.AnchorPoint
	local function apply()
		if Lay.compact then
			local a = Lay.win
			local w, h = math.min(maxW, a.w), math.min(maxH, a.h)
			p.AnchorPoint = Vector2.new(0.5, 0.5)
			p.Position = UDim2.fromOffset(a.x + a.w / 2, a.y + a.h / 2)
			p.Size = UDim2.fromOffset(w, h)
			p.ZIndex = Lay.Z.modal
			p.Visible = isOpen
		else
			p.Position, p.AnchorPoint, p.Size, p.ZIndex = designPos, designAnchor, full, 1
			p.Visible = true
		end
		onCompact(Lay.compact)
	end
	local function setOpen(v)
		isOpen = v
		if Lay.compact then p.Visible = v end
	end
	closeBtn.MouseButton1Click:Connect(function()
		play(SND.click)
		setOpen(false)
	end)
	edgeBtn.MouseButton1Click:Connect(function()
		play(SND.click)
		setOpen(not isOpen)
	end)
	Lay.major(name, p, {compactOnly = true, close = function() setOpen(false) end})
	Lay.onChange(function() apply() end)
	return sc, setOpen
end
-- a square edge button: big icon + a short line under it
local function edgeButton(name, icon, order)
	local b = new("TextButton", {Name = name, Size = UDim2.fromOffset(56, 56), BackgroundColor3 = BG, BackgroundTransparency = 0.1, BorderSizePixel = 0, Text = "", AutoButtonColor = true, Visible = false}, gui)
	corner(b, 12)
	stroke(b, WHITE, 1.5, 0.7)
	label({Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 30), Text = icon, TextSize = 24}, b)
	local sub = label({Position = UDim2.new(0, 2, 1, -20), Size = UDim2.new(1, -4, 0, 16), TextSize = 11, Font = Enum.Font.GothamBlack, Text = ""}, b)
	local dot = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0, Visible = false}, b)
	corner(dot, 5)
	Lay.slot(b, "left", order, {compactOnly = true})
	return b, sub, dot
end
U.edgeButton = edgeButton

-- ===== BUSINESS PANEL (left, collapsible): pick a business, manage it =====
-- A compact strip of business chips (level, lock, problem and "can upgrade" markers) and one management card
-- for the business you picked: level, income, expenses, staff, customers, rating, problems, the upgrade
-- button, improvements and reviews. The pick is remembered for the session.
do
	local full = UDim2.new(0, 300, 1, -232)
	local p = panel({Position = UDim2.new(0, 12, 0, 214), Size = full, ClipsDescendants = true}, gui)
	p.Name = "BusinessPanel"
	local body, onCompact, closeX = collapsible(p, "🏢  BUSINESSES", full, "biz")
	local bizBtn, bizSub, bizDot = edgeButton("BizButton", "🏪", 1)
	-- smaller screens (tablets): scale the whole panel down instead of covering the game.
	-- phones: a window behind the 🏪 button (sized to the screen, text at full size)
	local sc, setOpen = sheet("business", p, full, 360, 620, onCompact, closeX, bizBtn)
	U.openBusinessPanel = function(v) setOpen(v ~= false) end
	Lay.onChange(function(L)
		if L.compact then sc.Scale = 1 return end
		local vp = L.vp
		sc.Scale = math.clamp(math.min(vp.Y / 820, vp.X / 1100), 0.6, 1)
	end)
	local strip = new("ScrollingFrame", {Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 0, 56), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X}, body)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, strip)
	local cardF = new("ScrollingFrame", {Position = UDim2.fromOffset(6, 60), Size = UDim2.new(1, -12, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, body)
	local lay = vlist(cardF, 5)
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local selected = nil
	local chips = {}
	local lastLevels = {}
	-- the management card (built once, filled in on every state update)
	local head = new("Frame", {Size = UDim2.new(1, -6, 0, 46), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = 1}, cardF)
	corner(head, 10)
	local hIcon = label({Position = UDim2.fromOffset(4, 3), Size = UDim2.fromOffset(40, 40), TextSize = 26}, head)
	local hName = label({Position = UDim2.fromOffset(48, 4), Size = UDim2.new(1, -54, 0, 20), TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, head)
	local pips = {}
	for k = 1, 10 do
		local pip = new("Frame", {Position = UDim2.fromOffset(48 + (k - 1) * 9, 28), Size = UDim2.fromOffset(7, 10), BackgroundColor3 = GRAY, BorderSizePixel = 0}, head)
		corner(pip, 2)
		pips[k] = pip
	end
	local hLvl = label({Position = UDim2.new(1, -80, 0, 26), Size = UDim2.fromOffset(74, 14), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Right}, head)
	local action = button({Size = UDim2.new(1, -6, 0, 36), TextSize = 14, LayoutOrder = 2}, cardF)
	local stats = new("Frame", {Size = UDim2.new(1, -6, 0, 64), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = 3}, cardF)
	corner(stats, 10)
	new("UIGridLayout", {CellSize = UDim2.new(0.5, -4, 0, 18), CellPadding = UDim2.fromOffset(4, 2), SortOrder = Enum.SortOrder.LayoutOrder}, stats)
	new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4)}, stats)
	local stat = {}
	for i, k in ipairs({"income", "expense", "staff", "served", "rating", "where"}) do
		stat[k] = label({Text = "", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i}, stats)
	end
	local probRow = new("Frame", {Size = UDim2.new(1, -6, 0, 32), BackgroundColor3 = RGB(80, 30, 30), BorderSizePixel = 0, LayoutOrder = 4, Visible = false}, cardF)
	corner(probRow, 8)
	local probL = label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -100, 1, 0), TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = RGB(255, 190, 170)}, probRow)
	local probFix = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(88, 26), TextSize = 11, BackgroundColor3 = RGB(235, 160, 30)}, probRow)
	-- v9: the interior score (0-100) and a way in
	local intRow = new("Frame", {Size = UDim2.new(1, -6, 0, 30), BackgroundColor3 = RGB(40, 34, 60), BorderSizePixel = 0, LayoutOrder = 5, Visible = false}, cardF)
	corner(intRow, 8)
	local intL = label({Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -86, 1, 0), TextSize = 11, Font = Enum.Font.GothamBlack, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left}, intRow)
	local intGo = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(76, 24), Text = "🚪 Go inside", TextSize = 10, BackgroundColor3 = PURPLE}, intRow)
	local TIER_COLOR = {EMPTY = SUB, BASIC = WHITE, DECENT = RGB(140, 220, 255), PROFESSIONAL = RGB(120, 255, 160), ELITE = GOLD, VIRAL = RGB(255, 110, 200)}
	local impTitle = label({Size = UDim2.new(1, -6, 0, 18), Text = "IMPROVEMENTS (happier customers, better reviews)", TextSize = 10, TextColor3 = SUB, Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 7}, cardF)
	local impRows = {}
	for i = 1, 5 do
		local r = new("Frame", {Size = UDim2.new(1, -6, 0, 26), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = 7 + i}, cardF)
		corner(r, 6)
		local l = label({Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -96, 1, 0), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, r)
		local b = button({AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(86, 22), TextSize = 10, BackgroundColor3 = BLUE}, r)
		impRows[i] = {frame = r, label = l, btn = b}
	end
	local revTitle = label({Size = UDim2.new(1, -6, 0, 18), Text = "REVIEWS", TextSize = 10, TextColor3 = SUB, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 20}, cardF)
	local revHolder = new("Frame", {Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 21}, cardF)
	vlist(revHolder, 4)
	local cur = {}
	C.bizCardFrame = cardF   -- (EmpireClient > BusinessUI adds the Products / Supplies / Brand buttons here)
	C.bizCardCurrent = function() return cur.b and cur.b.level > 0 and cur.b.key or nil end
	action.MouseButton1Click:Connect(function()
		play(SND.click)
		local b = cur.b
		if not b then return end
		if cur.mode == "buy" then act("buy", b.key) elseif cur.mode == "chain" then act("chain", b.key)
		elseif cur.mode == "locked" then U.toast("🔒 " .. b.name .. " unlocks at " .. b.unlockName .. " reputation. Keep earning good reviews!") end
	end)
	probFix.MouseButton1Click:Connect(function()
		if cur.b then play(SND.click) act("problem", cur.b.key, "repair") end
	end)
	intGo.MouseButton1Click:Connect(function()
		if cur.b then play(SND.click) act("enterBiz", cur.b.key) end
	end)
	for i, r in ipairs(impRows) do
		r.btn.MouseButton1Click:Connect(function()
			local im = cur.b and cur.b.improve and cur.b.improve[i]
			if im then play(SND.click) act("improve", cur.b.key, im.key) end
		end)
	end
	local revSig
	local function fillCard(s, b)
		cur.b = b
		hIcon.Text = b.icon
		hName.Text = b.locked and ("🔒 " .. b.name) or (b.level > 0 and (b.brand or b.name) or (b.name .. "  (not open)"))
		hLvl.Text = "Lv " .. b.level .. "/" .. s.maxLevel
		for k, pip in ipairs(pips) do pip.BackgroundColor3 = k <= b.level and (b.level >= s.maxLevel and GOLD or b.color) or GRAY end
		if b.locked then
			cur.mode = "locked"
			action.Text = "🔒 Unlocks at " .. b.unlockName
			action.BackgroundColor3 = GRAY
		elseif b.cost >= 0 then
			cur.mode = "buy"
			action.Text = (s.crash and "🔥 SALE  " or "") .. (b.level == 0 and "BUY  " or "UPGRADE  ") .. "$" .. fmt(b.cost)
			action.BackgroundColor3 = s.cash >= b.cost and GREEN or GRAY
		elseif b.chainCost then
			cur.mode = "chain"
			action.Text = "📍 OPEN LOCATION #" .. (b.chains + 2) .. " (" .. b.chainName .. ")  $" .. fmt(b.chainCost)
			action.BackgroundColor3 = s.cash >= b.chainCost and PURPLE or GRAY
		else
			cur.mode = nil
			action.Text = b.stage == 6 and "🌟 LANDMARK" or "⭐ MAX LEVEL (new locations at CITY ICON)"
			action.BackgroundColor3 = RGB(190, 145, 30)
		end
		local open = b.level > 0
		stat.income.Text = open and ("💵 $" .. fmt(b.income) .. "/s") or ("💵 $" .. fmt(b.unit) .. "/s per level")
		stat.expense.Text = b.repair and ("🔧 Repair: $" .. fmt(b.repair)) or "🔧 Expenses: none"
		stat.staff.Text = b.staffName and ("👤 " .. b.staffName .. " ★" .. b.staffStars) or "👤 No staff yet"
		stat.served.Text = "🧍 " .. fmt(b.served or 0) .. " customers"
		stat.rating.Text = b.rating and ("⭐ " .. string.format("%.1f", b.rating) .. " (" .. b.ratingN .. ")") or "⭐ No ratings yet"
		stat.where.Text = "📍 Spot " .. (b.slot or 1) .. (b.chains > 0 and ("  • " .. (b.chains + 1) .. " places") or "")
		probRow.Visible = b.problem == true
		if b.problem then
			probL.Text = "⚠️ " .. (b.problemText or "Problem") .. " (earning -50%)"
			probFix.Text = "Fix $" .. fmt(b.repair or 0)
			probFix.BackgroundColor3 = s.cash >= (b.repair or 0) and RGB(235, 160, 30) or GRAY
		end
		intRow.Visible = open and b.interior ~= nil
		if b.interior then
			intL.Text = "🛋️ " .. b.name .. " Interior: " .. b.interior.score .. "/100 — " .. b.interior.tier
			intL.TextColor3 = TIER_COLOR[b.interior.tier] or WHITE
		end
		impTitle.Visible = open and b.improve ~= nil
		for i, r in ipairs(impRows) do
			local im = open and b.improve and b.improve[i]
			r.frame.Visible = im ~= nil
			if im then
				r.label.Text = im.icon .. " " .. im.name .. "  " .. string.rep("■", im.level) .. string.rep("□", 5 - im.level)
				r.btn.Text = im.cost >= 0 and ("+ $" .. fmt(im.cost)) or "MAX"
				r.btn.BackgroundColor3 = (im.cost >= 0 and s.cash >= im.cost) and BLUE or GRAY
			end
		end
		-- reviews: rebuilt only when they change
		local sig = b.key
		for _, rv in ipairs(b.reviews or {}) do sig ..= "|" .. rv.text .. tostring(rv.updated and rv.updated.text) end
		if sig ~= revSig then
			revSig = sig
			clear(revHolder)
			revTitle.Visible = open
			if open and #(b.reviews or {}) == 0 then
				label({Size = UDim2.new(1, 0, 0, 18), Text = "No complaints. Keep it up!", TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left}, revHolder)
			end
			for i, rv in ipairs(b.reviews or {}) do
				local f = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = rv.updated and RGB(30, 60, 40) or RGB(60, 34, 34), BorderSizePixel = 0, LayoutOrder = i}, revHolder)
				corner(f, 8)
				new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, f)
				local l2 = vlist(f, 2)
				l2.HorizontalAlignment = Enum.HorizontalAlignment.Left
				label({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1,
					Text = C.stars(rv.stars) .. "  \"" .. rv.text .. "\"" .. (rv.who and (" — " .. rv.who) or "")}, f)
				label({Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2,
					TextColor3 = rv.updated and RGB(150, 255, 170) or GOLD,
					Text = rv.updated and ("✅ Came back: " .. C.stars(rv.updated.stars) .. "  \"" .. rv.updated.text .. "\"") or ("🔧 Improve " .. (rv.fix or "the business") .. " to win them back")}, f)
			end
		end
	end
	local update
	update = function(s)
		if not s.biz then return end
		-- default pick: the first business you own (or the lemonade stand)
		if not selected then
			for _, b in ipairs(s.biz) do if b.level > 0 then selected = b.key break end end
			selected = selected or s.biz[1].key
		end
		local anyProblem, anyBuy = false, false
		for i, b in ipairs(s.biz) do
			local c = chips[i]
			if not c then
				local btn = new("TextButton", {Size = UDim2.fromOffset(48, 50), BackgroundColor3 = CARD, Text = "", AutoButtonColor = true, BorderSizePixel = 0, LayoutOrder = i}, strip)
				corner(btn, 10)
				local st = stroke(btn, b.color, 2, 1)
				c = {btn = btn, stroke = st,
					icon = label({Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 2), Text = b.icon, TextSize = 22}, btn),
					lvl = label({Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 16), TextSize = 10, Font = Enum.Font.GothamBlack}, btn),
					dot = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(9, 9), BorderSizePixel = 0, Visible = false}, btn)}
				corner(c.dot, 5)
				btn.MouseButton1Click:Connect(function()
					play(SND.click)
					selected = b.key
					revSig = nil
					if C.S then update(C.S) end
				end)
				chips[i] = c
			end
			c.icon.TextTransparency = b.locked and 0.6 or 0
			c.lvl.Text = b.locked and "🔒" or (b.level > 0 and ("Lv " .. b.level) or "BUY")
			c.stroke.Transparency = b.key == selected and 0 or 1
			c.btn.BackgroundColor3 = b.key == selected and RGB(56, 62, 88) or CARD
			-- red dot: a problem; green dot: you can afford the next upgrade
			local canBuy = not b.locked and b.cost >= 0 and s.cash >= b.cost
			c.dot.Visible = b.problem or canBuy
			c.dot.BackgroundColor3 = b.problem and RED or GREEN
			if b.problem then anyProblem = true elseif canBuy then anyBuy = true end
			if b.key == selected then bizSub.Text = b.level > 0 and ("Lv " .. b.level) or "BUY" end
			if lastLevels[i] and b.level > lastLevels[i] then play(SND.buy) end
			lastLevels[i] = b.level
			if b.key == selected then fillCard(s, b) end
		end
		-- the 🏪 button: red dot = a problem somewhere, green = you can afford an upgrade
		bizDot.Visible = anyProblem or anyBuy
		bizDot.BackgroundColor3 = anyProblem and RED or GREEN
	end
	C.onState(update)
	C.selectBusiness = function(key) selected = key revSig = nil end
	C.selectedBusiness = function() return selected end
end

-- ===== LEADERBOARD (right, collapsible) =====
do
	local full = UDim2.fromOffset(290, 318)
	local p = panel({Position = UDim2.new(1, -12, 0, 214), AnchorPoint = Vector2.new(1, 0), Size = full, ClipsDescendants = true}, gui)
	p.Name = "LeaderboardPanel"
	local body, onCompact, closeX = collapsible(p, "🏆  CITY LEADERBOARD", full, "board")
	local boardBtn, boardSub = edgeButton("BoardButton", "🏆", 2)
	sheet("leaderboard", p, full, 300, 330, onCompact, closeX, boardBtn)
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
		local rank = "—"
		for i, e in ipairs(s.standings) do if e.userId == plr.UserId then rank = "#" .. i end end
		boardSub.Text = rank
	end)
end

-- ===== PROBLEM CARD + DELIVERY CARD =====
do
	local pc = panel({Position = UDim2.new(1, -312, 0, 214), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(290, 150), BackgroundColor3 = RGB(70, 30, 30), Visible = false}, gui)
	stroke(pc, RED, 2, 0)
	pc.Name = "ProblemCard"
	Lay.slot(pc, "bottom", 2)
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
	dc.Name = "DeliveryCard"
	Lay.slot(dc, "bottom", 3)
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
	local tc = panel({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(540, 124), BackgroundColor3 = RGB(30, 70, 140), Visible = false}, gui)
	gradient(tc, RGB(70, 130, 230), RGB(30, 60, 140))
	stroke(tc, RGB(150, 200, 255), 2, 0)
	-- small screens: keep the card inside the screen and clear of the corner buttons.
	-- phones: the bottom notification stack (full stack width, text at ≥ 80%)
	tc.Name = "TutorialCard"
	Lay.slot(tc, "bottom", 1)
	Lay.onChange(function(L)
		L.resize(tc, UDim2.fromOffset(L.compact and 540 or math.min(540, L.vp.X - 220), 124))
	end)
	local title = label({Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -120, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left}, tc)
	local body = label({Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 40), TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, tc)
	-- live progress for the current step, worked out by the server ("Level 2 / 3", "84 studs to your home"...)
	local prog = label({Position = UDim2.fromOffset(14, 74), Size = UDim2.new(1, -28, 0, 42), TextSize = 13, TextWrapped = true, TextColor3 = RGB(255, 236, 150),
		Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, tc)
	local skip = button({Position = UDim2.new(1, -96, 0, 6), Size = UDim2.fromOffset(84, 24), Text = "Skip tutorial", TextSize = 11, BackgroundColor3 = GRAY}, tc)
	skip.MouseButton1Click:Connect(function()
		play(SND.click)
		act("tut", "skip")
		tc.Visible = false
	end)
	-- step 4 gets its own big button, so it works with touch, controller selection and mouse alike
	local open = button({AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(150, 34), Text = "📱 Open Phone", TextSize = 15, BackgroundColor3 = GREEN, Visible = false}, tc)
	open.MouseButton1Click:Connect(function()
		if C.togglePhone then C.togglePhone(true) end
	end)
	local lastStep, lastSent = nil, 0
	C.onState(function(s)
		local t = s.tut
		tc.Visible = t ~= nil
		if U.setBeamTarget then U.setBeamTarget("tut", t and t.target or nil) end
		if not t then return end
		title.Text = "🎓 TUTORIAL  •  Step " .. t.step .. " of " .. t.total
		body.Text = t.text
		-- phone: the business panel lives behind the 🏪 button, so say where it is
		if Lay.compact and t.step <= 3 then body.Text = t.text .. "  (Tap 🏪 on the left.)" end
		prog.Text = t.progress or ""
		open.Visible = t.phone == true
		prog.Size = UDim2.new(1, open.Visible and -178 or -28, 0, 42)
		-- the phone may already be open when step 4 starts: say so again (the server ignores repeats)
		if t.phone and C.phoneOpen and C.phoneOpen() and os.clock() - lastSent > 2 then
			lastSent = os.clock()
			if C.reportPhone then C.reportPhone() end
		end
		if lastStep ~= t.step then
			if lastStep and t.step > lastStep then play(SND.buy) end
			lastStep = t.step
			if not Lay.compact then
				tc.Position = UDim2.new(0.5, 0, 1, 140)
				tween(tc, 0.5, {Position = UDim2.new(0.5, 0, 1, -16)}, Enum.EasingStyle.Back)
			end
		end
	end)
end

-- ===== MEGA EVENTS: giant announcement across the whole screen, then a compact progress bar =====
do
	local big = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0.86, 0, 0, 190), BackgroundTransparency = 1, Visible = false, ZIndex = 70}, gui)
	local bigScale = new("UIScale", {}, big)
	local bigIcon = label({Size = UDim2.new(1, 0, 0, 70), TextScaled = true, Font = Enum.Font.GothamBlack, ZIndex = 71}, big)
	local bigTitle = label({Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 74), TextScaled = true, Font = Enum.Font.GothamBlack, ZIndex = 71}, big)
	new("UIStroke", {Thickness = 5, Color = Color3.new(0, 0, 0), Transparency = 0.1}, bigTitle)
	local bigSub = label({Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 40), TextScaled = true, ZIndex = 71}, big)
	new("UIStroke", {Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.2}, bigSub)
	local flash = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 69}, gui)
	local bar = panel({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 214), Size = UDim2.fromOffset(540, 44), Visible = false, ZIndex = 30}, gui)
	bar.Name = "MegaBar"
	Lay.slot(bar, "top", 4)
	stroke(bar, GOLD, 2, 0)
	local barTitle = label({Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -110, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31}, bar)
	local barText = label({Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -110, 0, 18), TextSize = 12, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 31}, bar)
	local barTime = label({Position = UDim2.new(1, -100, 0, 0), Size = UDim2.fromOffset(90, 44), TextSize = 22, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 31}, bar)
	local current, endsAt, bigId = nil, 0, 0
	local function showBar(e)
		current = e.key
		bar.Visible = true
		bar.BackgroundColor3 = (e.color or GOLD):Lerp(Color3.new(0, 0, 0), 0.6)
		barTitle.Text = (e.icon or "") .. " " .. (e.title or "")
		barText.Text = e.text or e.sub or ""
		if e.left then endsAt = os.clock() + e.left end
	end
	C.megaActive = function() return current ~= nil end
	R.Mega.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" then return end
		if e.kind == "start" then
			bigId += 1
			local mine = bigId
			bigIcon.Text = e.icon or ""
			bigTitle.Text = e.title or ""
			bigTitle.TextColor3 = e.color or GOLD
			bigSub.Text = (e.sub or "") .. "   📸 V = photo mode"
			big.Visible = true
			bigScale.Scale = 0.3
			tween(bigScale, 0.7, {Scale = 1}, Enum.EasingStyle.Back)
			flash.BackgroundColor3 = e.color or GOLD
			flash.BackgroundTransparency = 0.4
			tween(flash, 0.8, {BackgroundTransparency = 1})
			play(SND.event)
			U.confetti(90)
			showBar({key = e.key, icon = e.icon, title = e.title, text = e.text or e.sub, color = e.color, left = e.dur})
			task.delay(6, function()
				if bigId ~= mine then return end
				tween(bigScale, 0.35, {Scale = 0.2}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.35, function() if bigId == mine then big.Visible = false end end)
			end)
		elseif e.kind == "progress" then
			if current == e.key then
				barText.Text = e.text or ""
				if e.left then endsAt = os.clock() + e.left end
				if not Lay.compact then
					tween(bar, 0.08, {Size = UDim2.fromOffset(556, 46)})
					task.delay(0.08, function() tween(bar, 0.15, {Size = UDim2.fromOffset(540, 44)}) end)
				end
			end
		elseif e.kind == "end" then
			current = nil
			bar.Visible = false
			big.Visible = false
			U.splash(e.title or "", e.sub or "", e.color)
		end
	end)
	-- joined mid-event (or missed the start): rebuild the bar from the state packet
	C.onState(function(s)
		local m = s.mega
		if m and current ~= m.key then showBar({key = m.key, icon = m.icon, title = m.title, text = m.text or m.sub, color = m.color, left = m.left}) end
		if not m and current then
			current = nil
			bar.Visible = false
		end
	end)
	RunService.RenderStepped:Connect(function()
		if bar.Visible then barTime.Text = clock(endsAt - os.clock()) end
	end)
end

-- ===== ACHIEVEMENT CARD (with a Share-to-CityBuzz button) =====
do
	local card = panel({AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -120), Size = UDim2.fromOffset(340, 70), BackgroundColor3 = RGB(60, 45, 15), Visible = false, ZIndex = 45}, gui)
	card.Name = "AchievementCard"
	Lay.slot(card, "bottom", 5)
	stroke(card, GOLD, 2, 0)
	local ic = label({Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(54, 70), TextSize = 36, ZIndex = 46}, card)
	local t1 = label({Position = UDim2.fromOffset(66, 8), Size = UDim2.new(1, -170, 0, 18), TextSize = 12, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "🏆 ACHIEVEMENT UNLOCKED", ZIndex = 46}, card)
	local t2 = label({Position = UDim2.fromOffset(66, 28), Size = UDim2.new(1, -170, 0, 30), TextSize = 17, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 46}, card)
	local share = button({Position = UDim2.new(1, -98, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(88, 44), Text = "📱 Share", TextSize = 14, BackgroundColor3 = RGB(230, 70, 150), ZIndex = 46}, card)
	local queue, showing, key = {}, false, nil
	local function nextCard()
		local a = table.remove(queue, 1)
		if not a then
			showing = false
			card.Visible = false
			return
		end
		showing = true
		key = a.key
		ic.Text = a.icon or "🏆"
		t2.Text = a.title or ""
		share.Visible = true
		card.Visible = true
		if not Lay.isSlotted(card) then
			card.Position = UDim2.new(0, -360, 1, -120)
			tween(card, 0.4, {Position = UDim2.new(0, 12, 1, -120)}, Enum.EasingStyle.Back)
		end
		play(SND.buy)
		task.delay(7, function()
			if key == a.key then nextCard() end
		end)
	end
	share.MouseButton1Click:Connect(function()
		if not key then return end
		play(SND.click)
		act("shareAch", key)
		share.Visible = false
	end)
	R.Menu.OnClientEvent:Connect(function(kind, a)
		if kind == "achievement" and type(a) == "table" then
			table.insert(queue, a)
			if not showing then nextCard() end
		end
	end)
end

-- ===== YOU WENT VIRAL! =====
do
	R.Mega.OnClientEvent:Connect(function(e)
		if type(e) ~= "table" or e.kind ~= "viral" then return end
		local mine = e.userId == plr.UserId
		if mine then
			U.splash("🔥 YOU WENT VIRAL! 🔥", "An influencer posted your " .. (e.biz or "business") .. ": \"" .. (e.quote or "") .. "\"  •  3x customers, 2x reputation, +" .. fmt(e.fans or 0) .. " followers!", RGB(255, 110, 200))
			U.confetti(140)
			if C.offerReplay then C.offerReplay(e.pos) end
		else
			U.toast("🔥 " .. (e.player or "Someone") .. "'s " .. (e.biz or "business") .. " just WENT VIRAL!")
		end
		-- camera flashes at the business, for everyone who's nearby
		if typeof(e.pos) == "Vector3" and U.flashes then U.flashes(e.pos) end
	end)
end

-- ===== HOUSE TOUR PANEL (shows up when you're at another player's house) =====
do
	local tp = panel({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -122), Size = UDim2.fromOffset(460, 92), BackgroundColor3 = RGB(35, 55, 45), Visible = false, ZIndex = 35}, gui)
	tp.Name = "HouseTourPanel"
	Lay.slot(tp, "bottom", 7)
	stroke(tp, GREEN, 2, 0)
	local title = label({Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 22), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 36}, tp)
	local row = new("Frame", {Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 0, 42), BackgroundTransparency = 1, ZIndex = 36}, tp)
	-- (button widths are fractions of the row, so the row also fits the narrower phone card)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.015, 0)}, row)
	local target
	local function vb(text, w, color, fn)
		local b = button({Size = UDim2.new(w, 0, 0, 40), Text = text, TextSize = 13, BackgroundColor3 = color, ZIndex = 37}, row)
		b.MouseButton1Click:Connect(function()
			if target then
				play(SND.click)
				fn(target)
			end
		end)
	end
	vb("❤️ Like", 0.18, RGB(230, 70, 120), function(id) act("tourVote", id, "like") end)
	for n = 1, 5 do vb("⭐" .. n, 0.09, RGB(200, 150, 30), function(id) act("tourVote", id, "rate", n) end) end
	vb("📌 Favorite", 0.25, BLUE, function(id) act("tourVote", id, "fav") end)
	C.onState(function(s)
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local near
		if root then
			for _, h in ipairs(s.tours or {}) do
				if h.userId ~= plr.UserId and typeof(h.pos) == "Vector3" and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(h.pos.X, 0, h.pos.Z)).Magnitude < 45 then near = h end
			end
		end
		tp.Visible = near ~= nil and not C.photoActive
		target = near and near.userId
		if near then
			title.Text = "🏠 " .. near.name .. "'s house  •  " .. near.hood .. "  •  ⭐ " .. string.format("%.1f", near.rating) .. " (" .. near.ratings .. ")  •  ❤️ " .. near.likes
		end
	end)
end
end
