-- MINI-GAMES: Hoop Shot, Lemonade Rush, Memory Match + the Ferris wheel camera ride.
return function(C)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local new, tween, panel, label, button, corner, stroke, gradient, clear = C.new, C.tween, C.panel, C.label, C.button, C.corner, C.stroke, C.gradient, C.clear
local fmt, play, SND, act, gui, U, R = C.fmt, C.play, C.SND, C.act, C.gui, C.U, C.R
local CARD, GOLD, GREEN, GRAY, RED, BLUE, WHITE, SUB = C.CARD, C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.WHITE, C.SUB

local win = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(560, 460), Visible = false, ZIndex = 40}, gui)
gradient(win, RGB(50, 40, 90), RGB(20, 18, 36))
stroke(win, GOLD, 3, 0)
local titleL = label({Size = UDim2.new(1, 0, 0, 46), TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, ZIndex = 41}, win)
local infoL = label({Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), TextSize = 14, TextColor3 = SUB, ZIndex = 41}, win)
local area = new("Frame", {Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 1, -88), BackgroundColor3 = RGB(16, 16, 28), BorderSizePixel = 0, ZIndex = 41, ClipsDescendants = true}, win)
corner(area, 12)
local active = nil
local function finish(token, score, delay)
	task.delay(delay or 1.5, function()
		act("minigame", token, score)
		win.Visible = false
		active = nil
	end)
end
local function z(o) o.ZIndex = 42 return o end

-- ===== HOOP SHOT =====
local function hoop(token)
	clear(area)
	titleL.Text = "🏀 HOOP SHOT"
	local shots, score = 5, 0
	local hoopF = z(new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(90, 12), BackgroundColor3 = RGB(255, 100, 40), BorderSizePixel = 0}, area))
	z(new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(150, 70), BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, BorderSizePixel = 0}, area))
	local ball = z(label({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(50, 50), Text = "🏀", TextSize = 44}, area))
	local barBg = z(new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.new(0.85, 0, 0, 22), BackgroundColor3 = RGB(40, 40, 60), BorderSizePixel = 0}, area))
	corner(barBg, 6)
	local zone = z(new("Frame", {Size = UDim2.fromScale(0.12, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0}, barBg))
	local near = z(new("Frame", {Size = UDim2.fromScale(0.26, 1), BackgroundColor3 = RGB(230, 200, 60), BackgroundTransparency = 0.5, BorderSizePixel = 0}, barBg))
	near.ZIndex = 42
	zone.ZIndex = 43
	local marker = z(new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 6, 1, 10), BackgroundColor3 = WHITE, BorderSizePixel = 0}, barBg))
	marker.ZIndex = 44
	local btn = z(button({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(200, 44), Text = "🏀 SHOOT! (click / space)", TextSize = 15}, area))
	btn.ZIndex = 44
	local center = 0.7
	local function newZone()
		center = 0.2 + math.random() * 0.65
		zone.Position = UDim2.fromScale(center - 0.06, 0)
		near.Position = UDim2.fromScale(center - 0.13, 0)
	end
	newZone()
	local t, busy = 0, false
	local conn = RunService.RenderStepped:Connect(function(dt)
		if busy then return end
		t += dt * (1.4 + (5 - shots) * 0.25)
		local v = (math.sin(t * 2) + 1) / 2
		marker.Position = UDim2.fromScale(v, 0.5)
		marker:SetAttribute("V", v)
	end)
	local function shoot()
		if busy or shots <= 0 or active ~= token then return end
		busy = true
		shots -= 1
		local v = marker:GetAttribute("V") or 0
		local d = math.abs(v - center)
		local pts = d <= 0.06 and 2 or (d <= 0.13 and 1 or 0)
		score += pts
		play(SND.click)
		local endX = pts > 0 and 0.5 or (0.5 + (v - center) * 1.2)
		tween(ball, 0.35, {Position = UDim2.new(0.5 + (endX - 0.5) * 0.5, 0, 0, -10)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.35, function()
			tween(ball, 0.3, {Position = UDim2.new(endX, 0, 0, pts > 0 and 40 or 100)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			infoL.Text = (pts == 2 and "SWISH! +2" or (pts == 1 and "In off the rim! +1" or "Miss!")) .. "   •   Score " .. score .. "   •   Shots left " .. shots
			if pts > 0 then play(SND.buy) end
		end)
		task.delay(1.2, function()
			ball.Position = UDim2.new(0.5, 0, 1, -120)
			busy = false
			newZone()
			if shots <= 0 then
				conn:Disconnect()
				infoL.Text = "Final score: " .. score .. " / 10"
				finish(token, score)
			end
		end)
	end
	btn.MouseButton1Click:Connect(shoot)
	local kc
	kc = UserInputService.InputBegan:Connect(function(i)
		if active ~= token then
			kc:Disconnect()
			return
		end
		if i.KeyCode == Enum.KeyCode.Space then shoot() end
	end)
	infoL.Text = "Stop the marker in the GREEN zone! 5 shots."
end

-- ===== LEMONADE RUSH =====
local function rush(token)
	clear(area)
	titleL.Text = "🍋 LEMONADE RUSH"
	local ING = {{"🍋", "Lemon"}, {"🍬", "Sugar"}, {"🧊", "Ice"}, {"🍓", "Berry"}, {"🌿", "Mint"}}
	local score, order, progress = 0, {}, 0
	local orderF = z(new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(320, 90), BackgroundColor3 = CARD, BorderSizePixel = 0}, area))
	corner(orderF, 12)
	z(label({Size = UDim2.new(1, 0, 0, 22), Text = "🧑 Customer order:", TextSize = 14, TextColor3 = SUB}, orderF))
	local slots = {}
	for k = 1, 3 do
		slots[k] = z(label({Position = UDim2.new((k - 1) / 3, 0, 0, 24), Size = UDim2.new(1 / 3, 0, 0, 60), TextSize = 42, Text = "?"}, orderF))
	end
	local timeL = z(label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116), Size = UDim2.fromOffset(300, 30), TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = GOLD}, area))
	local function newOrder()
		progress = 0
		for k = 1, 3 do
			order[k] = math.random(#ING)
			slots[k].Text = ING[order[k]][1]
			slots[k].TextTransparency = 0
		end
	end
	newOrder()
	local ended = false
	for i, ing in ipairs(ING) do
		local b = z(button({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new((i - 0.5) / #ING, 0, 1, -16), Size = UDim2.fromOffset(88, 100), Text = ing[1] .. "\n" .. ing[2], TextSize = 22, BackgroundColor3 = Color3.fromHSV(i / 6, 0.5, 0.8)}, area))
		b.MouseButton1Click:Connect(function()
			if ended or active ~= token then return end
			if order[progress + 1] == i then
				progress += 1
				slots[progress].TextTransparency = 0.75
				play(SND.click)
				if progress >= 3 then
					score += 1
					play(SND.buy)
					infoL.Text = "✅ Served! Orders completed: " .. score
					newOrder()
				end
			else
				infoL.Text = "❌ Wrong ingredient! Start that order again."
				progress = 0
				for k = 1, 3 do slots[k].TextTransparency = 0 end
				tween(orderF, 0.05, {Rotation = 4})
				task.delay(0.05, function() tween(orderF, 0.1, {Rotation = 0}) end)
			end
		end)
	end
	infoL.Text = "Tap the ingredients in order! 30 seconds."
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 30 and active == token do
			timeL.Text = "⏱ " .. math.ceil(30 - (os.clock() - t0)) .. "s   •   Served: " .. score
			task.wait(0.1)
		end
		ended = true
		timeL.Text = "⏱ TIME!   Served: " .. score
		if active == token then finish(token, score, 1) end
	end)
end

-- ===== MEMORY MATCH =====
local function memory(token)
	clear(area)
	titleL.Text = "🧠 MEMORY MATCH"
	local EMO = {"🍋", "🍦", "🥐", "☕", "🍕", "🕹️"}
	local deck = {}
	for _, e in ipairs(EMO) do
		table.insert(deck, e)
		table.insert(deck, e)
	end
	for i = #deck, 2, -1 do
		local j = math.random(i)
		deck[i], deck[j] = deck[j], deck[i]
	end
	local grid = z(new("Frame", {Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -40, 1, -20), BackgroundTransparency = 1}, area))
	new("UIGridLayout", {CellSize = UDim2.new(0.25, -10, 0.333, -10), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, grid)
	local open, matched, moves, busy, done = {}, 0, 0, false, false
	local cards = {}
	local t0 = os.clock()
	local function scoreFor()
		if matched < 6 then return 0 end
		if moves <= 8 then return 3 end
		if moves <= 12 then return 2 end
		if moves <= 18 then return 1 end
		return 0
	end
	for i, e in ipairs(deck) do
		local b = z(button({Text = "❓", TextSize = 34, BackgroundColor3 = BLUE, LayoutOrder = i}, grid))
		cards[i] = {b = b, e = e, up = false, done = false}
		b.MouseButton1Click:Connect(function()
			local c = cards[i]
			if busy or done or c.up or c.done or active ~= token then return end
			c.up = true
			b.Text = e
			b.BackgroundColor3 = RGB(250, 240, 200)
			play(SND.click)
			table.insert(open, i)
			if #open == 2 then
				moves += 1
				local a, bb = cards[open[1]], cards[open[2]]
				if a.e == bb.e then
					a.done, bb.done = true, true
					a.b.BackgroundColor3, bb.b.BackgroundColor3 = GREEN, GREEN
					matched += 1
					open = {}
					play(SND.buy)
					if matched == 6 then
						done = true
						infoL.Text = "🎉 Done in " .. moves .. " moves! Prize multiplier x" .. scoreFor()
						finish(token, scoreFor(), 1.5)
					end
				else
					busy = true
					task.delay(0.8, function()
						a.up, bb.up = false, false
						a.b.Text, bb.b.Text = "❓", "❓"
						a.b.BackgroundColor3, bb.b.BackgroundColor3 = BLUE, BLUE
						open = {}
						busy = false
					end)
				end
			end
			if not done then infoL.Text = "Moves: " .. moves .. "   •   Pairs: " .. matched .. "/6   •   ≤8 moves = 3x prize!" end
		end)
	end
	infoL.Text = "Find all 6 pairs. Fewer moves = bigger prize! (60s)"
	task.spawn(function()
		while active == token and not done do
			if os.clock() - t0 > 60 then
				done = true
				infoL.Text = "⏱ Time's up!"
				finish(token, 0, 1)
			end
			task.wait(0.25)
		end
	end)
end

R.Menu.OnClientEvent:Connect(function(kind, key, token, fee)
	if kind == "minigame" then
		active = token
		C.closeModals()
		if C.togglePhone then C.togglePhone(false) end
		win.Visible = true
		if key == "hoop" then hoop(token) elseif key == "rush" then rush(token) else memory(token) end
		infoL.Text = infoL.Text .. "   (entry $" .. fmt(fee) .. ")"
	elseif kind == "ferris" then
		-- scenic camera ride around the wheel
		local hubPos, radius = key, token
		local cam = Workspace.CurrentCamera
		local oldType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable
		local skip = button({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(200, 44), Text = "🎡 Get off the ride", TextSize = 15, BackgroundColor3 = GRAY, ZIndex = 45}, gui)
		local caption = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 220), Size = UDim2.fromOffset(600, 40), TextSize = 26, Font = Enum.Font.GothamBlack,
			Text = "🎡 Enjoy the view! (+10% income for 3 min)", TextStrokeTransparency = 0.3, ZIndex = 45}, gui)
		local stop = false
		skip.MouseButton1Click:Connect(function() stop = true end)
		local t0 = os.clock()
		local DUR = 24
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - t0) / DUR
			if t >= 1 or stop then
				conn:Disconnect()
				cam.CameraType = oldType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or oldType
				skip:Destroy()
				caption:Destroy()
				return
			end
			local a = -math.pi / 2 + t * math.pi * 2
			local pos = hubPos + V3(math.cos(a) * radius, math.sin(a) * radius - 1, 6)
			cam.CFrame = CFrame.lookAt(pos, V3(0, 25, 0):Lerp(pos + V3(200, -20, 60), 0.3))
		end)
	end
end)
end
