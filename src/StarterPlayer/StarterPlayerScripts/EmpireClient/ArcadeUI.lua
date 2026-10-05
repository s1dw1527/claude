-- ARCADE UI (v10): the 2-player duel window (Reaction Duel, Button Battle, Hoop Duel, Kart Sprint), the game picker
-- for arcade machines, and the prize counter. The server (GameServer > Arcade) runs the games: this window only
-- sends taps and shots and shows what the server says.
return function(C)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local RGB = Color3.fromRGB
local new, label, button, card, header, clear, corner, stroke, gradient, panel = C.new, C.label, C.button, C.card, C.header, C.clear, C.corner, C.stroke, C.gradient, C.panel
local fmt, play, SND, act, gui, R, U = C.fmt, C.play, C.SND, C.act, C.gui, C.R, C.U
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local A = {state = nil}
C.ArcadeUI = A
local NAMES = {reaction = "⚡ REACTION DUEL", buttons = "👆 BUTTON BATTLE", hoops = "🏀 HOOP DUEL", sprint = "🏎️ KART SPRINT"}

local win = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(560, 440), Visible = false, ZIndex = 45}, gui)
gradient(win, RGB(40, 30, 80), RGB(16, 14, 30))
stroke(win, GOLD, 3, 0)
new("UIScale", {}, win)
local title = label({Size = UDim2.new(1, -60, 0, 44), Position = UDim2.fromOffset(10, 0), TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 46}, win)
local sub = label({Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 22), TextSize = 14, TextColor3 = SUB, ZIndex = 46}, win)
local quit = button({Position = UDim2.new(1, -96, 0, 8), Size = UDim2.fromOffset(86, 30), Text = "Leave", TextSize = 13, BackgroundColor3 = RED, ZIndex = 47}, win)
local area = new("Frame", {Position = UDim2.fromOffset(14, 68), Size = UDim2.new(1, -28, 1, -82), BackgroundColor3 = RGB(16, 16, 28), BorderSizePixel = 0, ZIndex = 46, ClipsDescendants = true}, win)
corner(area, 12)
A.win, A.area, A.title, A.sub = win, area, title, sub
local function z(o, n) o.ZIndex = n or 47 return o end
local function big(text, color, y)
	return z(label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y or 120), Size = UDim2.new(1, -20, 0, 60), Text = text, TextSize = 40, Font = Enum.Font.GothamBlack,
		TextColor3 = color or WHITE}, area))
end
local function bigButton(text, color, y, fn)
	local b = z(button({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(300, 70), Text = text, TextSize = 26, BackgroundColor3 = color}, area))
	b.MouseButton1Click:Connect(fn)
	return b
end
quit.MouseButton1Click:Connect(function()
	play(SND.click)
	C.confirm("Leave the game? Leaving a match counts as a loss.", "Leave", function()
		act("arcLeave")
		win.Visible = false
	end)
end)

-- one connection per screen, cleaned up between screens
local conns = {}
local function reset()
	for _, c in ipairs(conns) do c:Disconnect() end
	conns = {}
	clear(area)
end
local function scoreBar(names, scores, goal, y)
	for i = 1, 2 do
		local yy = y + (i - 1) * 38
		z(label({Position = UDim2.fromOffset(12, yy), Size = UDim2.fromOffset(120, 30), Text = tostring(names[i]), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = names[i] == C.plr.Name and GOLD or WHITE}, area))
		local bg = z(new("Frame", {Position = UDim2.fromOffset(136, yy + 8), Size = UDim2.new(1, -210, 0, 14), BackgroundColor3 = RGB(50, 50, 70), BorderSizePixel = 0}, area))
		corner(bg, 6)
		local fill = z(new("Frame", {Size = UDim2.fromScale(math.clamp((scores[i] or 0) / math.max(1, goal), 0, 1), 1), BackgroundColor3 = i == 1 and RGB(255, 120, 60) or RGB(80, 200, 255), BorderSizePixel = 0}, bg), 48)
		corner(fill, 6)
		z(label({Position = UDim2.new(1, -66, 0, yy), Size = UDim2.fromOffset(60, 30), Text = tostring(scores[i] or 0), TextSize = 18, Font = Enum.Font.GothamBlack}, area))
	end
end

-- ===== each game's screen =====
local SCREEN = {}
SCREEN.reaction = function(e)
	reset()
	local wins = e.wins or {0, 0}
	big("WAIT...", RGB(255, 120, 120), 110)
	z(label({Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 24), Text = (A.names and A.names[1] or "") .. "  " .. wins[1] .. "  —  " .. wins[2] .. "  " .. (A.names and A.names[2] or ""), TextSize = 18,
		Font = Enum.Font.GothamBlack}, area))
	bigButton("TAP!", RGB(200, 60, 60), 220, function() act("arcPress") end)
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Enum.KeyCode.Space then act("arcPress") end
	end))
end
SCREEN.buttons = function(e)
	reset()
	A.taps = 0
	local t0 = os.clock()
	local timeL = big(tostring(e.seconds or 10), WHITE, 40)
	A.scoreY = 90
	scoreBar(A.names or {"", ""}, {0, 0}, 140, 90)
	bigButton("👆 TAP TAP TAP!", RGB(255, 90, 160), 190, function() A.taps += 1 end)
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Enum.KeyCode.Space then A.taps += 1 end
	end))
	-- taps go to the server in small batches (the server caps the rate)
	table.insert(conns, RunService.Heartbeat:Connect(function()
		timeL.Text = tostring(math.max(0, math.ceil((e.seconds or 10) - (os.clock() - t0))))
	end))
	task.spawn(function()
		while win.Visible and A.game == "buttons" and not A.over do
			task.wait(0.25)
			if A.taps > 0 then
				local n = math.min(8, A.taps)
				A.taps -= n
				act("arcTap", n)
			end
		end
	end)
end
SCREEN.hoops = function(e)
	reset()
	local t0 = os.clock()
	z(label({Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 24), Text = "Shoot when the ball is over the hoop!", TextSize = 15}, area))
	local barBg = z(new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.new(0.9, 0, 0, 30), BackgroundColor3 = RGB(40, 40, 60), BorderSizePixel = 0}, area))
	corner(barBg, 8)
	z(new("Frame", {Position = UDim2.fromScale((e.center or 0.5) - 0.06, 0), Size = UDim2.fromScale(0.12, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0}, barBg), 48)
	z(new("Frame", {Position = UDim2.fromScale((e.center or 0.5) - 0.13, 0), Size = UDim2.fromScale(0.26, 1), BackgroundColor3 = RGB(230, 200, 60), BackgroundTransparency = 0.5, BorderSizePixel = 0}, barBg), 47)
	local ball = z(label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(36, 36), Text = "🏀", TextSize = 30}, barBg), 49)
	A.scoreY = 110
	scoreBar(A.names or {"", ""}, {0, 0}, 10, 110)
	A.shotL = z(label({Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 24), Text = (e.shots or 5) .. " shots left", TextSize = 15, TextColor3 = SUB}, area))
	bigButton("🏀 SHOOT!", RGB(255, 130, 40), 230, function() act("arcShoot") end)
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Enum.KeyCode.Space then act("arcShoot") end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function()
		local v = (math.sin((os.clock() - t0) * (e.speed or 2) * 2) + 1) / 2
		ball.Position = UDim2.fromScale(v, 0.5)
	end))
end
SCREEN.sprint = function(e)
	reset()
	A.steps, A.lastSide = 0, nil
	A.goal = e.goal or 60
	z(label({Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 24), Text = "Alternate LEFT ⬅ and RIGHT ➡ (A / D, arrows or the buttons)", TextSize = 14}, area))
	A.scoreY = 50
	scoreBar(A.names or {"", ""}, {0, 0}, A.goal, 50)
	local function step(side)
		if A.lastSide ~= side then
			A.lastSide = side
			A.steps += 1
		end
	end
	local l = z(button({Position = UDim2.new(0, 20, 0, 170), Size = UDim2.new(0.5, -30, 0, 110), Text = "⬅", TextSize = 48, BackgroundColor3 = BLUE}, area))
	local r = z(button({Position = UDim2.new(0.5, 10, 0, 170), Size = UDim2.new(0.5, -30, 0, 110), Text = "➡", TextSize = 48, BackgroundColor3 = PURPLE}, area))
	l.MouseButton1Click:Connect(function() step("L") end)
	r.MouseButton1Click:Connect(function() step("R") end)
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		local k = input.KeyCode
		if k == Enum.KeyCode.A or k == Enum.KeyCode.Left or k == Enum.KeyCode.ButtonL1 then step("L")
		elseif k == Enum.KeyCode.D or k == Enum.KeyCode.Right or k == Enum.KeyCode.ButtonR1 then step("R") end
	end))
	task.spawn(function()
		while win.Visible and A.game == "sprint" and not A.over do
			task.wait(0.25)
			if A.steps > 0 then
				local n = math.min(6, A.steps)
				A.steps -= n
				act("arcStep", n)
			end
		end
	end)
end
local function redrawScores(e)
	if not (e.scores and A.scoreY) then return end
	-- drop the old bars and draw fresh ones
	for _, ch in ipairs(area:GetChildren()) do
		if ch:GetAttribute("Bar") then ch:Destroy() end
	end
	local before = {}
	for _, ch in ipairs(area:GetChildren()) do before[ch] = true end
	scoreBar(A.names or {"", ""}, e.scores, A.game == "sprint" and (A.goal or 60) or (A.game == "hoops" and 10 or 140), A.scoreY)
	for _, ch in ipairs(area:GetChildren()) do if not before[ch] then ch:SetAttribute("Bar", true) end end
	A.lastScores = e.scores
end

local function open()
	if not win.Visible then
		C.closeModals()
		win.Visible = true
	end
end
R.Menu.OnClientEvent:Connect(function(kind, e)
	if kind == "arcadePick" and type(e) == "table" then
		A.pick = e
		C.openModal("arcadePick", true)
		A.renderPick()
		return
	elseif kind == "arcadeInfo" and type(e) == "table" then
		A.info = e
		if not C.modals.arcadeInfo.frame.Visible then C.openModal("arcadeInfo", true) end
		A.renderInfo()
		return
	end
	if kind ~= "arcade" or type(e) ~= "table" then return end
	A.state = e.state
	if e.state == "waiting" then
		open()
		A.game, A.over = e.game, false
		reset()
		title.Text = NAMES[e.game] or "ARCADE"
		sub.Text = "Waiting for a second player... (ask a friend to join this game)"
		big("⏳", WHITE, 120)
	elseif e.state == "left" then
		win.Visible = false
	elseif e.state == "matched" then
		open()
		A.game, A.over, A.names = e.game, false, e.names
		reset()
		title.Text = NAMES[e.game] or "ARCADE"
		sub.Text = tostring(e.names[1]) .. "  vs  " .. tostring(e.names[2])
		big("GET READY!", GOLD, 120)
		play(SND.event)
	elseif e.state == "round" then
		A.names = e.names or A.names
		SCREEN.reaction(e)
		sub.Text = "Round " .. e.round .. " — wait for GO, then tap!"
	elseif e.state == "go" then
		for _, ch in ipairs(area:GetChildren()) do
			if ch:IsA("TextLabel") and ch.Text == "WAIT..." then ch.Text = "GO!" ch.TextColor3 = GREEN end
		end
		play(SND.buy)
	elseif e.state == "roundEnd" then
		for _, ch in ipairs(area:GetChildren()) do
			if ch:IsA("TextLabel") and (ch.Text == "GO!" or ch.Text == "WAIT...") then ch.Text = tostring(e.winner) .. " wins the round!" ch.TextSize = 26 ch.TextColor3 = GOLD end
		end
		sub.Text = tostring(e.why)
	elseif e.state == "start" then
		A.names = e.names or A.names
		if SCREEN[e.game] then SCREEN[e.game](e) end
		sub.Text = tostring(e.names and e.names[1] or "") .. "  vs  " .. tostring(e.names and e.names[2] or "")
	elseif e.state == "update" then
		redrawScores(e)
		if e.shotsLeft and A.shotL then
			local me = (A.names and A.names[1] == C.plr.Name) and 1 or 2
			A.shotL.Text = e.shotsLeft[me] .. " shots left"
		end
	elseif e.state == "shot" then
		U.toast(e.pts == 2 and "🏀 SWISH! +2" or (e.pts == 1 and "🏀 In! +1" or "🧱 Miss!"))
	elseif e.state == "end" then
		A.over = true
		reset()
		big(e.draw and "🤝 DRAW" or (e.won and "🏆 YOU WIN!" or "😵 YOU LOSE"), e.won and GOLD or (e.draw and WHITE or RGB(255, 140, 140)), 90)
		z(label({Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 30), Text = tostring(e.score or 0) .. " — " .. tostring(e.opp or 0), TextSize = 22, Font = Enum.Font.GothamBlack}, area))
		z(label({Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 30), TextSize = 16, TextColor3 = SUB,
			Text = e.tickets > 0 and ("🎟️ +" .. e.tickets .. " tickets (you have " .. e.total .. ")") or (e.capped and "No tickets: you've played this opponent a lot lately. Try someone new!" or "No tickets this time.")}, area))
		bigButton("OK", BLUE, 250, function() win.Visible = false end)
		play(e.won and SND.event or SND.click)
	elseif e.state == "forfeit" then
		A.over = true
		win.Visible = false
	end
end)

-- ===== machine game picker =====
local modal = C.makeModal
local pickM = modal("arcadePick", "🕹️  PICK A GAME", 420, 380)
function A.renderPick()
	clear(pickM.body)
	local e = A.pick
	if not e then return end
	for i, key in ipairs(e.games) do
		local b = button({Size = UDim2.new(1, -8, 0, 54), Text = NAMES[key] or key, TextSize = 18, BackgroundColor3 = BLUE, LayoutOrder = i}, pickM.body)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			act("arcPick", e.station, key)
			pickM.frame.Visible = false
		end)
	end
end
-- ===== prize counter =====
local infoM = modal("arcadeInfo", "🎟️  ARCADE PRIZES", 520, 520)
if C.BusinessUI and C.BusinessUI.helpButton then C.BusinessUI.helpButton(infoM, "arcade") end
do
	local asked = false
	infoM.frame:GetPropertyChangedSignal("Visible"):Connect(function() if not infoM.frame.Visible then asked = false end end)
	infoM.update = function()
		if not asked then
			asked = true
			act("arcInfo")
		end
	end
end
function A.renderInfo()
	clear(infoM.body)
	local e = A.info
	if not e then return end
	local top = card(infoM.body, 54, 0, RGB(40, 34, 70))
	label({Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 38), Text = "🎟️ " .. e.tickets .. " tickets   •   🏆 " .. e.wins .. " wins   •   " .. e.played .. " games",
		TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = GOLD}, top)
	header(infoM.body, "Prizes (go into your furniture storage)", 1)
	for i, p in ipairs(e.prizes) do
		local c = card(infoM.body, 46, 1 + i)
		label({Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -160, 1, 0), Text = p.icon .. " " .. p.name, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left}, c)
		local b = button({Position = UDim2.new(1, -140, 0.5, -16), Size = UDim2.fromOffset(130, 32), Text = "🎟️ " .. p.tickets, TextSize = 14, BackgroundColor3 = e.tickets >= p.tickets and GREEN or GRAY}, c)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			if e.tickets >= p.tickets then act("arcPrize", p.key) end
		end)
	end
	header(infoM.body, "🏆 Top players in this server", 40)
	for i, b in ipairs(e.board) do label({Size = UDim2.new(1, -8, 0, 22), Text = i .. ". " .. b.name .. " — " .. b.wins .. " wins", TextSize = 14, LayoutOrder = 40 + i}, infoM.body) end
	header(infoM.body, "Games", 60)
	for i, g in ipairs(e.games) do label({Size = UDim2.new(1, -8, 0, 22), Text = g.icon .. " " .. g.name .. " — " .. g.desc, TextSize = 12, TextColor3 = SUB, TextWrapped = true, LayoutOrder = 60 + i}, infoM.body) end
end
end
