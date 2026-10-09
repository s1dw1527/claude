-- EMPIRE UI (v12): the Empire Hall window (your value, the four billionaire milestones, storefront makeovers, the Hall of
-- Fame with Visit buttons). It only ASKS the server (GameServer > Empire): values, rewards and rankings all come from there.
return function(C)
local RGB = Color3.fromRGB
local label, button, card, header, clear, stroke = C.label, C.button, C.card, C.header, C.clear, C.stroke
local fmt, play, SND, act, R = C.fmt, C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local E = {tab = "hall", pick = nil}
C.EmpireUI = E

local m = modal("empireHall", "👑  EMPIRE HALL", 560, 600)
local last
local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, pos, size, color, fn)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 13, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end
local function money(v)
	v = tonumber(v) or 0
	if v >= 1e9 then return string.format("$%.2fB", v / 1e9) end
	if v >= 1e6 then return string.format("$%.1fM", v / 1e6) end
	if v >= 1e3 then return string.format("$%.0fK", v / 1e3) end
	return "$" .. math.floor(v)
end
E.money = money

local function render(info)
	clear(m.body)
	if type(info) ~= "table" then return end
	last = info
	local b = info.brief or {}
	-- the headline
	local top = card(m.body, 96, 1, RGB(36, 40, 60))
	stroke(top, GOLD, 2, 0.4)
	txt(top, "Your empire is worth " .. money(b.value), UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 28), 20, GOLD, true)
	local nx = b.next
	if nx then
		txt(top, "Next: " .. nx.icon .. " " .. nx.name .. " at " .. nx.short .. (nx.legit and "" or "   (keep earning: milestones count real income)"), UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 18), 12, SUB)
		local bar = C.new("Frame", {Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 14), BackgroundColor3 = RGB(20, 22, 34), BorderSizePixel = 0}, top)
		C.corner(bar, 7)
		local fill = C.new("Frame", {Size = UDim2.fromScale(math.clamp(nx.pct or 0, 0.02, 1), 1), BackgroundColor3 = GOLD, BorderSizePixel = 0}, bar)
		C.corner(fill, 7)
	else
		txt(top, "👑 You have reached every milestone. You own the city.", UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 40), 14, GREEN, true)
	end
	-- tabs
	local tabs = card(m.body, 52, 2, RGB(26, 28, 40))
	local names = {{"hall", "🏆 Hall of Fame"}, {"ms", "💎 Milestones"}, {"style", "🎨 Makeovers"}}
	for i, t in ipairs(names) do
		btn(tabs, t[2], UDim2.new((i - 1) / 3, 3, 0, 5), UDim2.new(1 / 3, -6, 1, -10), E.tab == t[1] and PURPLE or GRAY, function()
			E.tab = t[1]
			render(last)
		end)
	end
	if E.tab == "hall" then
		for i, row in ipairs(info.hall or {}) do
			local c = card(m.body, 60, 10 + i, row.me and RGB(40, 50, 40) or nil)
			txt(c, "#" .. row.rank, UDim2.fromOffset(8, 16), UDim2.fromOffset(40, 24), 16, row.rank == 1 and GOLD or WHITE, true)
			txt(c, (row.icon or "🏪") .. " " .. tostring(row.biz or "Empire") .. ((type(row.tags) == "string" and row.tags ~= "") and ("  " .. row.tags) or ""), UDim2.fromOffset(50, 6), UDim2.new(1, -190, 0, 22), 14, WHITE, true)
			txt(c, tostring(row.name) .. "  •  " .. money(row.value), UDim2.fromOffset(50, 30), UDim2.new(1, -190, 0, 20), 12, SUB)
			if row.canVisit then
				btn(c, "🚶 Visit", UDim2.new(1, -118, 0.5, -20), UDim2.fromOffset(106, 40), GREEN, function()
					act("empVisit", row.userId)
					m.frame.Visible = false
				end)
			elseif row.me then
				txt(c, "YOU", UDim2.new(1, -70, 0, 18), UDim2.fromOffset(60, 22), 14, GREEN, true)
			end
		end
		if #(info.hall or {}) == 0 then
			local c = card(m.body, 50, 10)
			txt(c, "Nobody is on the board yet. Be the first!", UDim2.fromOffset(12, 14), UDim2.new(1, -24, 0, 24), 14, SUB)
		end
		local g = card(m.body, 52, 40)
		btn(g, "📍 Go to the Empire Plaza", UDim2.fromOffset(6, 5), UDim2.new(1, -12, 1, -10), BLUE, function()
			act("tp", "plaza")
			m.frame.Visible = false
		end)
	elseif E.tab == "ms" then
		for i, ms in ipairs(info.milestones or {}) do
			local c = card(m.body, 74, 10 + i, ms.done and RGB(40, 50, 40) or nil)
			txt(c, ms.icon .. "  " .. ms.name .. "  (" .. ms.short .. ")", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 22), 15, ms.done and GOLD or WHITE, true)
			txt(c, ms.perk or "", UDim2.fromOffset(12, 30), UDim2.new(1, -110, 0, 38), 11, SUB)
			txt(c, ms.done and "✔ Reached" or ("Reward: $" .. fmt(ms.cash) .. " + " .. ms.rep .. " rep"), UDim2.new(1, -150, 0, 6), UDim2.fromOffset(138, 22), 12, ms.done and GREEN or GOLD, true)
		end
		local n = card(m.body, 44, 40, RGB(26, 28, 40))
		txt(n, "Empire value = cash + upgrades + properties + cars + home + HQ. The server checks it, and it must come from real earnings.", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -10), 11, SUB)
	else
		local sel = E.pick
		local open = info.biz or {}
		if not sel or not (function() for _, b2 in ipairs(open) do if b2.key == sel then return true end end end)() then sel = open[1] and open[1].key end
		E.pick = sel
		local rowc = card(m.body, 52, 10)
		for i, b2 in ipairs(open) do
			btn(rowc, b2.icon, UDim2.fromOffset(6 + (i - 1) * 50, 4), UDim2.fromOffset(44, 44), b2.key == sel and PURPLE or GRAY, function()
				E.pick = b2.key
				render(last)
			end)
		end
		if #open == 0 then txt(rowc, "Open a business first.", UDim2.fromOffset(12, 14), UDim2.new(1, -24, 0, 24), 13, SUB) end
		local cur
		for _, b2 in ipairs(open) do if b2.key == sel then cur = b2 end end
		for i, st in ipairs(info.styles or {}) do
			local c = card(m.body, 60, 10 + i)
			txt(c, st.icon .. " " .. st.name, UDim2.fromOffset(12, 6), UDim2.new(1, -140, 0, 20), 14, WHITE, true)
			txt(c, st.desc, UDim2.fromOffset(12, 28), UDim2.new(1, -140, 0, 26), 11, SUB)
			local isCur = cur and cur.style == st.k
			if not st.open then
				txt(c, "🔒 locked", UDim2.new(1, -120, 0, 18), UDim2.fromOffset(110, 22), 13, RGB(255, 160, 140), true)
			elseif cur then
				btn(c, isCur and "✔ In use" or "Apply", UDim2.new(1, -120, 0.5, -20), UDim2.fromOffset(108, 40), isCur and GRAY or GREEN, function()
					if isCur then return end
					act("brand", cur.key, "style", st.k)
					task.delay(0.5, function() act("empInfo") end)
				end)
			end
		end
	end
end

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "empireHall" and type(a) == "table" then
		if not m.frame.Visible then C.openModal("empireHall", true) end
		render(a)
	end
end)
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not m.frame.Visible then asked = false end
end)
m.update = function()
	if not asked then
		asked = true
		act("empInfo")
	end
end
end
