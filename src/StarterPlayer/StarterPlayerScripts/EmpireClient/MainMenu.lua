-- MAIN MENU: cinematic camera, 3 save slots, new game (pick a starter home), delete.
return function(C)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local V3, RGB = Vector3.new, Color3.fromRGB
local new, tween, panel, label, button, corner, stroke, gradient, clear = C.new, C.tween, C.panel, C.label, C.button, C.corner, C.stroke, C.gradient, C.clear
local fmt, play, SND, act, U, plr, R = C.fmt, C.play, C.SND, C.act, C.U, C.plr, C.R
local CARD, GOLD, GREEN, GRAY, RED, BLUE, WHITE, SUB = C.CARD, C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.WHITE, C.SUB

local mg = new("ScreenGui", {Name = "MainMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = true}, plr:WaitForChild("PlayerGui"))
local shade = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0}, mg)
new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0.1)}), Rotation = 90}, shade)
local title = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.06, 0), Size = UDim2.new(0.8, 0, 0, 100), Text = "🍋 CORNER EMPIRE", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = GOLD}, mg)
new("UIStroke", {Thickness = 5, Color = RGB(60, 30, 0)}, title)
local tscale = new("UIScale", {}, title)
local subtitle = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.06, 104), Size = UDim2.fromOffset(700, 30), Text = "Build a company. Take over the city.", TextSize = 24, TextColor3 = WHITE, TextStrokeTransparency = 0.4}, mg)
local notice = label({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(900, 40), TextSize = 14, TextWrapped = true, TextColor3 = RGB(255, 200, 120), TextStrokeTransparency = 0.4}, mg)
local status = label({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.06, 140), Size = UDim2.fromOffset(700, 24), TextSize = 16, TextColor3 = GREEN, Text = ""}, mg)
-- (a scrolling row: on a phone the save cards become a swipeable carousel)
local row = new("ScrollingFrame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(880, 330), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X}, mg)
row.Name = "SaveSlots"
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 20), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center}, row)
local musicB = button({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(150, 40), TextSize = 14, BackgroundColor3 = GRAY}, mg)
local function musicText() musicB.Text = C.settings.music and "🎵 Music: ON" or "🎵 Music: OFF" end
musicB.MouseButton1Click:Connect(function()
	play(SND.click)
	C.setSetting("music", not C.settings.music)
	musicText()
	if U.refreshSettings then U.refreshSettings() end
end)

-- overlay for starter homes + delete confirm
local overlay = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, Visible = false, ZIndex = 10}, mg)
local ovPanel = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(860, 420), ZIndex = 11}, overlay)
gradient(ovPanel, RGB(40, 44, 64), RGB(20, 22, 32))
local ovTitle = label({Size = UDim2.new(1, 0, 0, 56), TextSize = 26, Font = Enum.Font.GothamBlack, ZIndex = 12}, ovPanel)
local ovBody = new("ScrollingFrame", {Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 1, -80), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 12,
	ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X}, ovPanel)
local ovClose = button({Position = UDim2.new(1, -48, 0, 10), Size = UDim2.fromOffset(38, 38), Text = "X", BackgroundColor3 = RED, ZIndex = 13}, ovPanel)
ovClose.MouseButton1Click:Connect(function() overlay.Visible = false end)

-- v11.1 phone layout: everything sized to the screen. Save slots and starter homes become swipeable carousels
-- (full-size cards, scroll sideways) instead of three columns squeezed side by side.
local Lay = C.Layout
local rowScale = Lay.scaleOf(row)
local function fitMenu(L)
	local vp = L.vp
	if L.compact then
		subtitle.Size = UDim2.new(0.94, 0, 0, 30)
		subtitle.TextScaled = true
		status.Size = UDim2.new(0.94, 0, 0, 24)
		notice.Size = UDim2.new(0.94, 0, 0, 40)
		notice.TextScaled = true
		rowScale.Scale = math.min(1, (vp.Y * 0.55) / 330)
		row.Size = UDim2.fromOffset((vp.X - 16) / rowScale.Scale, 330)
		local a = L.win
		ovPanel.Size = UDim2.fromOffset(math.min(860, a.w), math.min(420, a.h))
	else
		subtitle.Size, subtitle.TextScaled = UDim2.fromOffset(700, 30), false
		status.Size = UDim2.fromOffset(700, 24)
		notice.Size, notice.TextScaled = UDim2.fromOffset(900, 40), false
		rowScale.Scale = 1
		row.Size = UDim2.fromOffset(880, 330)
		ovPanel.Size = UDim2.fromOffset(860, 420)
	end
end
Lay.onChange(fitMenu)

local payload = nil
local busy = false
local function setBusy(text)
	busy = true
	status.Text = text
	overlay.Visible = false
end
local function pickStarter(slot)
	clear(ovBody)
	ovTitle.Text = "🏠 Choose your starter home"
	overlay.Visible = true
	for i, st in ipairs(payload.starters) do
		local c = new("Frame", {Position = UDim2.new((i - 1) / 3, 8, 0, 0), Size = UDim2.new(1 / 3, -16, 1, 0), BackgroundColor3 = CARD, BorderSizePixel = 0, ZIndex = 12}, ovBody)
		if Lay.compact then
			c.Position = UDim2.fromOffset((i - 1) * 262, 0)
			c.Size = UDim2.new(0, 250, 1, -8)
		end
		corner(c, 14)
		stroke(c, st.color, 3, 0)
		label({Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 60), Text = st.icon, TextSize = 54, ZIndex = 13}, c)
		label({Position = UDim2.fromOffset(8, 80), Size = UDim2.new(1, -16, 0, 26), Text = st.name, TextSize = 20, Font = Enum.Font.GothamBlack, ZIndex = 13}, c)
		label({Position = UDim2.fromOffset(8, 106), Size = UDim2.new(1, -16, 0, 20), Text = st.hood, TextSize = 14, TextColor3 = st.color, ZIndex = 13}, c)
		label({Position = UDim2.fromOffset(12, 134), Size = UDim2.new(1, -24, 0, 90), Text = st.desc, TextSize = 14, TextWrapped = true, TextColor3 = SUB, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 13}, c)
		local b = button({AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -28, 0, 48), Text = "MOVE IN", TextSize = 18, ZIndex = 13}, c)
		b.MouseButton1Click:Connect(function()
			if busy then return end
			play(SND.buy)
			setBusy("Building your city... 🏗️")
			act("menuNew", slot, i)
		end)
	end
end
local function confirmDelete(slot)
	clear(ovBody)
	ovTitle.Text = "🗑 Delete Save " .. slot .. "?"
	overlay.Visible = true
	label({Size = UDim2.new(1, 0, 0, 80), Text = "This permanently deletes this save. Your other saves are safe.", TextSize = 18, TextWrapped = true, TextColor3 = SUB, ZIndex = 13}, ovBody)
	local bw = Lay.compact and UDim2.new(0.46, 0, 0, 56) or UDim2.fromOffset(220, 56)
	local yes = button({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(Lay.compact and 0.26 or 0.35, 0, 0, 120), Size = bw, Text = "🗑 DELETE", TextSize = 18, BackgroundColor3 = RED, ZIndex = 13}, ovBody)
	local no = button({AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(Lay.compact and 0.74 or 0.65, 0, 0, 120), Size = bw, Text = "Keep it", TextSize = 18, BackgroundColor3 = GRAY, ZIndex = 13}, ovBody)
	yes.MouseButton1Click:Connect(function()
		play(SND.click)
		overlay.Visible = false
		act("menuDelete", slot)
	end)
	no.MouseButton1Click:Connect(function() overlay.Visible = false end)
end
local function render()
	clear(row)
	for i = 1, payload.count do
		local s = payload.slots["s" .. i]
		local c = new("Frame", {Size = UDim2.fromOffset(270, 320), BackgroundColor3 = RGB(24, 26, 38), BackgroundTransparency = 0.08, BorderSizePixel = 0, LayoutOrder = i}, row)
		corner(c, 16)
		stroke(c, s and GOLD or WHITE, 2, s and 0.2 or 0.7)
		gradient(c, RGB(50, 54, 80), RGB(20, 22, 32))
		label({Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 30), Text = "SAVE " .. i, TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = s and GOLD or SUB}, c)
		if s then
			local lines = {
				"💰 $" .. fmt(s.cash), "📈 $" .. fmt(s.income or 0) .. "/s", "⭐ " .. (s.tier or "?"),
				"♻️ " .. (s.rebirths or 0) .. " rebirths", "🏠 " .. (s.home or "—"),
				"🕒 " .. (s.played and os.date("%b %d, %I:%M %p", s.played) or ""),
			}
			for k, ln in ipairs(lines) do
				label({Position = UDim2.fromOffset(18, 44 + (k - 1) * 28), Size = UDim2.new(1, -36, 0, 26), Text = ln, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, c)
			end
			local p = button({Position = UDim2.new(0, 14, 1, -62), Size = UDim2.new(1, -84, 0, 48), Text = "▶ PLAY", TextSize = 20}, c)
			local d = button({Position = UDim2.new(1, -62, 1, -62), Size = UDim2.fromOffset(48, 48), Text = "🗑", TextSize = 20, BackgroundColor3 = RED}, c)
			p.MouseButton1Click:Connect(function()
				if busy then return end
				play(SND.buy)
				setBusy("Loading Save " .. i .. "... 🏗️")
				act("menuPlay", i)
			end)
			d.MouseButton1Click:Connect(function()
				if busy then return end
				play(SND.click)
				confirmDelete(i)
			end)
		else
			label({Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 80), Text = "✨", TextSize = 60}, c)
			label({Position = UDim2.fromOffset(0, 170), Size = UDim2.new(1, 0, 0, 24), Text = "Empty slot", TextSize = 16, TextColor3 = SUB}, c)
			local n = button({Position = UDim2.new(0, 14, 1, -62), Size = UDim2.new(1, -28, 0, 48), Text = "+ NEW GAME", TextSize = 20, BackgroundColor3 = BLUE}, c)
			n.MouseButton1Click:Connect(function()
				if busy then return end
				play(SND.click)
				pickStarter(i)
			end)
		end
	end
	if not payload.saving then
		notice.Text = payload.studio and "⚠️ Saving is OFF in this Studio session. To test saving: Game Settings → Security → turn on 'Enable Studio Access to API Services' (the game must be published)."
			or "⚠️ Saving is unavailable right now — your progress this session may not be saved."
	else
		notice.Text = "💾 Your progress saves automatically every 2 minutes and when you leave."
	end
end

-- cinematic camera orbit
local cam = Workspace.CurrentCamera
local ang = 0
local camConn
local function startCamera()
	if camConn then return end
	camConn = RunService.RenderStepped:Connect(function(dt)
		ang += dt * 0.05
		cam.CameraType = Enum.CameraType.Scriptable
		local pos = V3(math.cos(ang) * 280, 110 + math.sin(ang * 0.7) * 20, math.sin(ang) * 280)
		cam.CFrame = CFrame.lookAt(pos, V3(0, 20, 0))
		tscale.Scale = 1 + math.sin(os.clock() * 2) * 0.02
	end)
end
local function stopCamera()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	cam.CameraType = Enum.CameraType.Custom
end

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "mainmenu" then
		payload = a
		busy = false
		status.Text = ""
		for k, v in pairs(a.settings or {}) do C.settings[k] = v end
		C.applySettings()
		musicText()
		if U.refreshSettings then U.refreshSettings() end
		C.gui.Enabled = false
		C.inMainMenu = true
		-- v9: nothing from the city keeps playing behind the menu
		if C.Cinematics then C.Cinematics.clear() end
		if C.CityLife then C.CityLife.endAll() end
		if C.InteriorLife then C.InteriorLife.stop() end
		if C.phoneFrame then C.phoneFrame.Visible = false end
		C.closeModals()
		mg.Enabled = true
		render()
		startCamera()
	elseif kind == "play" then
		mg.Enabled = false
		overlay.Visible = false
		stopCamera()
		C.inMainMenu = false
		C.gui.Enabled = true
		C.S = nil
		if C.reloadInbox then task.spawn(C.reloadInbox) end
		play(SND.event)
	end
end)
R.Announce.OnClientEvent:Connect(function(msg)
	if mg.Enabled then
		busy = false
		status.Text = msg
	end
end)
startCamera()
musicText()
R.Menu:FireServer("ready")
end
