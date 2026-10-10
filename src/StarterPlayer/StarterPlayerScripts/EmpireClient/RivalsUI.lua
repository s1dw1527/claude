-- RIVALS UI (v14): the 🥊 RIVALS phone app (your market share per business against the AI companies, the active
-- challenge, your record, who the rivals are) and the challenge card in the notification stack while a rival's
-- challenge is running. The server (GameServer > Rivals) decides everything.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, stroke, panel = C.new, C.label, C.button, C.card, C.clear, C.stroke, C.panel
local fmt, play, SND, act, R, gui = C.fmt, C.play, C.SND, C.act, C.R, C.gui
local GOLD, GREEN, GRAY, RED, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.WHITE, C.SUB
local Lay = C.Layout
local modal = C.makeModal
if not modal then return end
local RU = {info = nil}
C.RivalsUI = RU

local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function clock(s)
	s = math.max(0, math.floor(s or 0))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local m = modal("rivals", "🥊  RIVALS", 560, 600)
local function render()
	local info = RU.info
	clear(m.body)
	if type(info) ~= "table" then return end
	local top = card(m.body, 60, 1, RGB(40, 30, 50))
	stroke(top, GOLD, 2, 0.4)
	txt(top, string.format("🏆 %d won   ⏱️ %d lost   🥊 %d moves against you", info.wins, info.losses, info.moves), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22), 15, GOLD, true)
	txt(top, "Rivals creep in while you play. Upgrades, Rush Orders, ads, hiring and premieres push them back.", UDim2.fromOffset(12, 32), UDim2.new(1, -24, 0, 24), 11, SUB)
	if info.ch then
		local c = card(m.body, 84, 2, RGB(70, 30, 30))
		stroke(c, RED, 2, 0.2)
		txt(c, info.ch.icon .. "  CHALLENGE FROM " .. string.upper(info.ch.rival or "?") .. "   ⏱ " .. clock(info.ch.left), UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22), 14, RGB(255, 170, 150), true)
		txt(c, info.ch.text .. "   (" .. info.ch.got .. "/" .. info.ch.need .. ")", UDim2.fromOffset(12, 34), UDim2.new(1, -24, 0, 40), 13, WHITE)
	end
	if #info.biz == 0 then
		local c = card(m.body, 40, 3)
		txt(c, "Open a business and the rivals will notice.", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 20), 13, SUB)
	end
	for i, b in ipairs(info.biz) do
		local c = card(m.body, 56, 10 + i)
		txt(c, b.icon .. "  " .. b.name, UDim2.fromOffset(12, 6), UDim2.new(0.55, -12, 0, 20), 14, WHITE, true)
		txt(c, "vs " .. b.rivalIcon .. " " .. b.rival, UDim2.fromOffset(12, 30), UDim2.new(0.55, -12, 0, 18), 11, SUB)
		local bar = new("Frame", {Position = UDim2.new(0.55, 0, 0, 12), Size = UDim2.new(0.45, -14, 0, 12), BackgroundColor3 = RGB(120, 40, 50), BorderSizePixel = 0}, c)
		local fill = new("Frame", {Size = UDim2.fromScale(b.share / 100, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0}, bar)
		fill.Name = "Share"
		txt(c, string.format("Your share %d%%  •  sales ×%.2f", b.share, b.mult), UDim2.new(0.55, 0, 0, 30), UDim2.new(0.45, -14, 0, 18), 11, b.mult >= 1 and GREEN or RGB(255, 150, 140))
	end
	local h = card(m.body, 30, 40, RGB(26, 28, 40))
	txt(h, "THE RIVALS", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
	for i, r in ipairs(info.rivals) do
		local c = card(m.body, 44, 40 + i)
		txt(c, r.icon .. "  " .. r.name .. "  (" .. r.boss .. ")", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 18), 13, WHITE, true)
		txt(c, "Competes with: " .. r.targets, UDim2.fromOffset(12, 24), UDim2.new(1, -24, 0, 16), 11, SUB)
	end
end
RU.render = render
local asked = false
m.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not m.frame.Visible then asked = false end end)
m.update = function()
	if not asked then
		asked = true
		act("rivalInfo")
	end
end

-- the challenge card in the notification stack
local rc = panel({Position = UDim2.new(1, -12, 1, -372), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(290, 96), BackgroundColor3 = RGB(70, 28, 30), Visible = false}, gui)
stroke(rc, RED, 2, 0)
rc.Name = "RivalCard"
Lay.slot(rc, "top", 5)
local rt = label({Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 180, 160), TextXAlignment = Enum.TextXAlignment.Left}, rc)
local rd = label({Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 34), TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, rc)
local ro = button({Position = UDim2.new(0, 8, 1, -30), Size = UDim2.new(1, -16, 0, 24), Text = "🥊 Open Rivals", TextSize = 12, BackgroundColor3 = RGB(110, 40, 44)}, rc)
ro.MouseButton1Click:Connect(function() play(SND.click) C.openModal("rivals", true) end)
local ends, head = 0, ""
local function showCard(icon, rival, text, left)
	ends = os.clock() + (left or 0)
	head = icon .. " " .. string.upper(rival or "RIVAL") .. " CHALLENGE"
	rd.Text = text
	rc.Visible = true
end
RU.card = rc
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "rivals" and type(a) == "table" then
		RU.info = a
		if a.ch then showCard(a.ch.icon, a.ch.rival, a.ch.text .. " (" .. a.ch.got .. "/" .. a.ch.need .. ")", a.ch.left) else rc.Visible = false end
		if m.frame.Visible then render() end
	elseif kind == "rivalMove" and type(a) == "table" then
		showCard(a.icon, a.rival, a.text, a.left)
		if C.jingle then C.jingle("fail", 0.25) end
		if m.frame.Visible then act("rivalInfo") end
	elseif kind == "rivalResult" and type(a) == "table" then
		rc.Visible = false
		if a.won and C.jingle then C.jingle("success", 0.4) end
		if m.frame.Visible then act("rivalInfo") end
	end
end)
task.spawn(function()
	while true do
		task.wait(1)
		if rc.Visible then rt.Text = head .. "   ⏱ " .. clock(ends - os.clock()) end
	end
end)
end
