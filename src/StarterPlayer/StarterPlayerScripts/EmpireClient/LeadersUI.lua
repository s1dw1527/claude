-- LEADERS UI (v14): the 📊 LEADERS phone app. Eight leaderboards (Net Worth, Revenue, Popularity, Properties,
-- Fastest Lap, Heists, Explorer, Prestige) in three views (this server, global, friends), your place, and your
-- PRESTIGE: the ten goals, your stars and title. The server (GameServer > Leaders) computes everything.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, stroke = C.new, C.label, C.button, C.card, C.clear, C.stroke
local fmt, play, SND, act, R, plr = C.fmt, C.play, C.SND, C.act, C.R, C.plr
local GOLD, GREEN, GRAY, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local LU = {info = nil, board = "networth", scope = "server", tab = "boards"}
C.LeadersUI = LU

local function txt(parent, text, pos, size, px, color, bold, align)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, parent)
end
local function btn(parent, text, pos, size, color, fn, name)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	if name then b.Name = name end
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end
local function ask() act("boardInfo", LU.board, LU.scope) end
local function value(info, v)
	if info.time then return string.format("%.2f s", v) end
	if info.money then return "$" .. fmt(v) .. (info.per or "") end
	return fmt(v)
end

local m = modal("leaders", "📊  LEADERS", 580, 640)
local function render()
	local info = LU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local pr = info.prestige
	local top = card(m.body, 52, 1, RGB(50, 40, 20))
	stroke(top, GOLD, 2, 0.4)
	txt(top, "🌟 Prestige: " .. pr.stars .. "/10" .. (pr.title and ("  •  " .. pr.title) or "") .. "  •  +" .. pr.stars .. "% all income", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 40), 14, GOLD, true)
	local tabs = card(m.body, 48, 2, RGB(26, 28, 40))
	btn(tabs, "📊 Leaderboards", UDim2.new(0, 4, 0, 5), UDim2.new(0.5, -8, 1, -10), LU.tab == "boards" and PURPLE or GRAY, function() LU.tab = "boards" render() end, "TabBoards")
	btn(tabs, "🌟 Prestige goals", UDim2.new(0.5, 4, 0, 5), UDim2.new(0.5, -8, 1, -10), LU.tab == "prestige" and PURPLE or GRAY, function() LU.tab = "prestige" render() end, "TabPrestige")
	if LU.tab == "prestige" then
		for i, g in ipairs(pr.goals) do
			local c = card(m.body, 50, 10 + i, g.done and RGB(40, 64, 44) or nil)
			txt(c, (g.done and "⭐ " or "☆ ") .. g.icon .. " " .. g.name, UDim2.fromOffset(12, 4), UDim2.new(1, -140, 0, 22), 14, g.done and GOLD or WHITE, true)
			txt(c, g.text, UDim2.fromOffset(12, 26), UDim2.new(1, -140, 0, 20), 11, SUB)
			txt(c, g.done and "DONE" or (tostring(g.have) .. " / " .. tostring(g.need)), UDim2.new(1, -128, 0, 0), UDim2.fromOffset(116, 50), 13, g.done and GREEN or SUB, true, Enum.TextXAlignment.Right)
		end
		return
	end
	-- the eight boards
	local grid = card(m.body, 96, 3, RGB(26, 28, 40))
	for i, b in ipairs(info.boards) do
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		btn(grid, b.icon .. " " .. b.name, UDim2.new(col / 4, 3, 0, 4 + row * 46), UDim2.new(0.25, -6, 0, 42), info.key == b.key and PURPLE or GRAY, function()
			LU.board = b.key
			ask()
		end, "Board_" .. b.key)
	end
	local sc = card(m.body, 44, 4, RGB(26, 28, 40))
	for i, s in ipairs({{"server", "🖥️ This server"}, {"global", "🌍 Global"}, {"friends", "👥 Friends"}}) do
		btn(sc, s[2], UDim2.new((i - 1) / 3, 3, 0, 4), UDim2.new(1 / 3, -6, 1, -8), info.scope == s[1] and BLUE or GRAY, function()
			LU.scope = s[1]
			ask()
		end, "Scope_" .. s[1])
	end
	local head = card(m.body, 30, 5, RGB(30, 34, 50))
	txt(head, info.icon .. " " .. string.upper(info.name) .. (info.mine and ("   •   you: #" .. info.mine) or ""), UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 13, GOLD, true)
	if info.scope ~= "server" and not info.globalOn then
		local c = card(m.body, 34, 6)
		txt(c, "Global boards need saving to be on (they are in the live game).", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 12, SUB)
	end
	if #info.list == 0 then
		local c = card(m.body, 34, 7)
		txt(c, "Nobody on this board yet.", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 12, SUB)
	end
	for i, e in ipairs(info.list) do
		local me = e.uid == plr.UserId
		local c = card(m.body, 36, 10 + i, me and RGB(40, 56, 80) or nil)
		c.Name = "Row_" .. i
		local medal = ({"🥇", "🥈", "🥉"})[e.rank] or ("#" .. e.rank)
		txt(c, medal, UDim2.fromOffset(8, 0), UDim2.fromOffset(44, 36), 15, GOLD, true, Enum.TextXAlignment.Center)
		txt(c, e.name .. (e.title and ("  " .. e.title) or ""), UDim2.fromOffset(56, 0), UDim2.new(0.6, -56, 1, 0), 13, me and GOLD or WHITE, true)
		txt(c, value(info, e.value), UDim2.new(0.6, 0, 0, 0), UDim2.new(0.4, -12, 1, 0), 13, WHITE, true, Enum.TextXAlignment.Right)
	end
end
LU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		ask()
	end
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "leaders" and type(a) == "table" then
		LU.info = a
		LU.board, LU.scope = a.key, a.scope
		if m.frame.Visible then render() end
	end
end)
end
