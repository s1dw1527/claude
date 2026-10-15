-- UI: theme, helper functions, sounds, the main ScreenGui. Everything else builds on this.
return function(C)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local plr = Players.LocalPlayer
local RGB = Color3.fromRGB
C.plr = plr

C.R = {}
for _, n in ipairs({"State", "Announce", "Splash", "Customer", "Buzz", "BuzzUpdate", "Msg", "WarResults", "Menu", "Action", "Race", "Mega"}) do
	C.R[n] = ReplicatedStorage:WaitForChild(n)
end
C.GetCatalog = ReplicatedStorage:WaitForChild("GetCatalog")
C.catalog = C.GetCatalog:InvokeServer("catalog")
function C.act(...) C.R.Action:FireServer(...) end

C.BG, C.CARD = RGB(22, 24, 34), RGB(36, 40, 56)
-- (v14: GREEN is a little deeper so white text on green buttons is readable (3.8:1, was 2.8:1); green text on the dark
-- panels stays readable too (4.9:1))
C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE = RGB(255, 205, 70), RGB(46, 170, 90), RGB(74, 78, 96), RGB(220, 70, 80), RGB(60, 130, 230), RGB(140, 90, 230)
C.WHITE, C.SUB = Color3.new(1, 1, 1), RGB(175, 182, 205)
-- v14 THEME: what each color MEANS, used the same way on every screen (and never alone: always with its icon or a word)
--   💰 money / cash ....... GOLD        📈 income, gains, "go" buttons ... GREEN
--   ⭐ reputation .......... GOLD        ⚠️ danger, losses, police ......... RED (+ an icon)
--   ℹ️ info, travel, maps .. BLUE        👑 premium, special, selected ..... PURPLE
-- Panels are dark navy with white text (high contrast on any background); secondary text is SUB.
C.THEME = {money = C.GOLD, income = C.GREEN, rep = C.GOLD, danger = C.RED, info = C.BLUE, premium = C.PURPLE, panel = C.BG, card = C.CARD, text = C.WHITE, sub = C.SUB}

function C.fmt(n)
	n = math.floor((n or 0) + 0.5)
	if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e5 then return string.format("%.1fK", n / 1e3) end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end
function C.stars(n)
	n = math.clamp(math.floor(n + 0.5), 0, 5)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end
function C.clock(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end
function C.tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
function C.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local new, tween = C.new, C.tween
function C.corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 10)}, o) end
-- v16.1 BOLD UI: chunky cartoon buttons and windows (thick dark outlines, glossy gradients, outlined lettering).
-- Everything is built from frames, strokes and gradients (no uploaded images), and every screen gets it through
-- these helpers. A UIStroke on an object is its OUTLINE: C.stroke and C.gradient reuse the one already there
-- (Roblox draws only one of each), so a screen that recolors an outline (e.g. "selected" in gold) just changes it.
local kp = ColorSequenceKeypoint.new
C.STYLE = {
	outline = RGB(24, 18, 40),          -- the chunky dark edge around buttons, windows and cards
	font = Enum.Font.FredokaOne,        -- rounded, bold: titles and buttons (body text stays Gotham, easier to read)
	gloss = ColorSequence.new({kp(0, Color3.new(1, 1, 1)), kp(0.45, RGB(232, 232, 232)), kp(1, RGB(165, 165, 165))}),   -- light top, darker "lip"
	glass = ColorSequence.new({kp(0, RGB(200, 225, 255)), kp(1, RGB(150, 160, 200))}),
}
local STYLE = C.STYLE
function C.shade(c, k)
	k = k or 0.55
	return Color3.new(c.R * k, c.G * k, c.B * k)
end
local function lum(c)
	local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
end
C.lum = lum
function C.stroke(o, color, th, tr)
	local s = o:FindFirstChild("Outline")
	if s and s:IsA("UIStroke") then
		s.Color, s.Thickness, s.Transparency = color, th or 2, tr or 0
		return s
	end
	s = new("UIStroke", {Color = color, Thickness = th or 2, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
	s.Name = "Outline"
	return s
end
function C.gradient(o, a, b, rot)
	local g = o:FindFirstChildOfClass("UIGradient")
	local col = a
	if typeof(a) ~= "ColorSequence" then col = ColorSequence.new(a, b) end
	if g then
		g.Color, g.Rotation = col, rot or 90
		return g
	end
	return new("UIGradient", {Color = col, Rotation = rot or 90}, o)
end
-- outlined lettering: a dark edge around light text (never around dark text, where it would only blur it)
function C.outlineText(o)
	if lum(o.TextColor3) > 0.35 then
		o.TextStrokeColor3 = STYLE.outline
		o.TextStrokeTransparency = 0.35
	end
	return o
end
function C.titleText(o)
	o.Font = STYLE.font
	return C.outlineText(o)
end
-- v19: the CORNER EMPIRE crown, built from frames (no image asset): three gold points tipped with gems over a
-- jewelled band. h is its height in pixels; it is twice as wide. Used by the main menu and the intro title card.
function C.crownLogo(props, parent, h)
	h = h or 48
	local z = props.ZIndex or 1
	props.BackgroundTransparency, props.Size = 1, UDim2.fromOffset(h * 2, h)
	local f = new("Frame", props, parent)
	local function circle(x, y, d, col)
		local g = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 0, y), Size = UDim2.fromOffset(d, d), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = z + 2}, f)
		new("UICorner", {CornerRadius = UDim.new(0.5, 0)}, g)
		C.stroke(g, STYLE.outline, 2, 0)
	end
	for _, s in ipairs({{0.2, 0.56, 0.5}, {0.5, 0.48, 0.62}, {0.8, 0.56, 0.5}}) do
		local side = h * s[3]
		local spike = new("Frame", {Name = "Point", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(s[1], 0, s[2], 0), Size = UDim2.fromOffset(side, side), Rotation = 45,
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = z}, f)
		C.stroke(spike, STYLE.outline, 2, 0)
		C.gradient(spike, Color3.fromRGB(255, 236, 140), Color3.fromRGB(220, 150, 20), 0)
		circle(s[1], s[2] * h - side * 0.707, h * 0.17, Color3.fromRGB(255, 250, 235))
	end
	local band = new("Frame", {Name = "Band", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.6, 0), Size = UDim2.new(0.84, 0, 0.34, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = z + 1}, f)
	C.corner(band, math.max(3, math.floor(h * 0.08)))
	C.stroke(band, STYLE.outline, 2, 0)
	C.gradient(band, Color3.fromRGB(255, 226, 110), Color3.fromRGB(196, 128, 16))
	for i, col in ipairs({Color3.fromRGB(230, 50, 70), Color3.fromRGB(60, 200, 110), Color3.fromRGB(70, 140, 255)}) do
		circle(0.5 + (i - 2) * 0.24, h * 0.77, h * 0.16, col)
	end
	return f
end
function C.panel(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or C.BG
	props.BorderSizePixel = 0
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	local f = new("Frame", props, parent)
	C.corner(f, 14)
	C.stroke(f, STYLE.outline, 3, 0.05)
	return f
end
function C.label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or C.WHITE
	props.TextSize = props.TextSize or 16
	return new("TextLabel", props, parent)
end
-- a chunky button: glossy, a thick dark outline, outlined lettering, and it answers every press.
-- props.flat = true: no outline (tiny inline buttons, icon tiles that draw their own frame)
function C.button(props, parent)
	local flat = props.flat
	props.flat = nil
	props.Font = props.Font or STYLE.font
	props.TextColor3 = props.TextColor3 or C.WHITE
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.BackgroundColor3 = props.BackgroundColor3 or C.GREEN
	local b = new("TextButton", props, parent)
	C.corner(b, 10)
	C.gradient(b, STYLE.gloss)
	if not flat then C.stroke(b, STYLE.outline, 2.5) end
	C.outlineText(b)
	local sc = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() tween(sc, 0.12, {Scale = 1.05}) end)
	b.MouseLeave:Connect(function() tween(sc, 0.12, {Scale = 1}) end)
	-- every press answers right away: a squeeze and a soft tap sound (v14)
	b.MouseButton1Down:Connect(function()
		tween(sc, 0.06, {Scale = 0.93})
		if C.SND and C.SND.tap then C.play(C.SND.tap) end
	end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.2, {Scale = 1.05}, Enum.EasingStyle.Back) end)
	return b
end
function C.card(parent, h, order, color)
	local c = new("Frame", {Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = color or C.CARD, BorderSizePixel = 0, LayoutOrder = order or 0}, parent)
	C.corner(c, 12)
	C.gradient(c, Color3.new(1, 1, 1), RGB(205, 205, 215))
	C.stroke(c, STYLE.outline, 2, 0.15)
	return c
end
function C.header(parent, text, order)
	return C.titleText(C.label({Size = UDim2.new(1, -8, 0, 30), Text = text, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order or 0}, parent))
end
function C.bar(parent, pos, size, color)
	local bg = new("Frame", {Position = pos, Size = size, BackgroundColor3 = RGB(12, 13, 20), BorderSizePixel = 0}, parent)
	C.corner(bg, 6)
	C.stroke(bg, STYLE.outline, 2)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0}, bg)
	C.corner(fill, 6)
	C.gradient(fill, STYLE.gloss)
	return fill, bg
end
-- the red close button on a window's corner (one look everywhere)
function C.closeX(props, parent)
	props.Text = props.Text or "X"
	props.TextSize = props.TextSize or 20
	props.BackgroundColor3 = C.RED
	props.Rotation = props.Rotation or 0
	local b = C.button(props, parent)
	b.Name = "CloseX"
	return b
end
-- a price / confirm pill: "buy" (green), "robux" (green, R$), "danger" (red), "off" (grey: owned, can't afford)
local PILL = {buy = C.GREEN, robux = C.GREEN, danger = C.RED, off = C.GRAY, gold = RGB(190, 130, 20), info = C.BLUE}
function C.pill(props, parent, kind)
	kind = kind or "buy"
	props.BackgroundColor3 = PILL[kind] or C.GREEN
	if kind == "robux" and props.Text and not tostring(props.Text):find("R%$") then props.Text = "R$ " .. props.Text end
	props.TextSize = props.TextSize or 16
	local b = C.button(props, parent)
	C.corner(b, 999)
	b:SetAttribute("Pill", kind)
	return b
end
function C.setPill(b, kind, text)
	b.BackgroundColor3 = PILL[kind] or C.GREEN
	if text then b.Text = text end
	b:SetAttribute("Pill", kind)
end
-- a chunky tab strip: {{key, label}, ...}; onPick(key). Returns the strip and setTab(key).
function C.tabs(parent, list, onPick, props)
	props = props or {}
	local strip = new("Frame", {Size = props.Size or UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, LayoutOrder = props.LayoutOrder or 0, Name = "Tabs"}, parent)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, strip)
	local btns, current = {}, nil
	local w = 1 / math.max(1, #list)
	local function setTab(key)
		current = key
		for k, b in pairs(btns) do
			local on = k == key
			b.BackgroundColor3 = on and (props.color or C.PURPLE) or C.GRAY
			b.TextTransparency = on and 0 or 0.15
			b:SetAttribute("Selected", on)
			C.stroke(b, on and C.GOLD or STYLE.outline, on and 3 or 2.5)
		end
	end
	for i, t in ipairs(list) do
		local b = C.button({Size = UDim2.new(w, -6, 1, 0), Text = t[2], TextSize = props.TextSize or 15, LayoutOrder = i, BackgroundColor3 = C.GRAY}, strip)
		b.Name = "Tab_" .. t[1]
		btns[t[1]] = b
		b.MouseButton1Click:Connect(function()
			C.play(C.SND.click)
			setTab(t[1])
			if onPick then onPick(t[1]) end
		end)
	end
	return strip, setTab, function() return current end, btns
end
-- a "Statistics" row: an icon chip, a name and the value in a pill on the right
function C.statRow(parent, icon, name, value, order, color)
	local r = C.card(parent, 40, order, RGB(44, 40, 72))
	local chip = new("Frame", {Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = color or C.PURPLE, BorderSizePixel = 0}, r)
	C.corner(chip, 8)
	C.stroke(chip, STYLE.outline, 2)
	C.label({Size = UDim2.fromScale(1, 1), Text = icon, TextSize = 17}, chip)
	C.label({Position = UDim2.fromOffset(44, 0), Size = UDim2.new(0.55, -44, 1, 0), Text = name, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true}, r)
	local vb = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0.42, 0, 0, 28), BackgroundColor3 = RGB(20, 18, 34), BorderSizePixel = 0}, r)
	C.corner(vb, 999)
	C.stroke(vb, STYLE.outline, 2)
	local v = C.titleText(C.label({Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), Text = tostring(value), TextSize = 15, TextColor3 = C.GOLD, TextScaled = true}, vb))
	new("UITextSizeConstraint", {MaxTextSize = 15, MinTextSize = 9}, v)
	return r, v
end
function C.vlist(parent, pad)
	return new("UIListLayout", {Padding = UDim.new(0, pad or 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, parent)
end
function C.autoFrame(parent, order)
	return new("Frame", {Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order or 0}, parent)
end
function C.clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

-- built-in sounds (no uploads needed)
local function sound(id, vol) return new("Sound", {SoundId = id, Volume = vol or 0.5}, SoundService) end
C.SND = {
	buy = sound("rbxasset://sounds/electronicpingshort.wav", 0.5),
	click = sound("rbxasset://sounds/switch.wav", 0.4),
	event = sound("rbxasset://sounds/snap.mp3", 0.6),
	msg = sound("rbxasset://sounds/electronicpingshort.wav", 0.3),
	tap = sound("rbxasset://sounds/switch.wav", 0.18),
}
C.settings = {music = true, musicVol = 5, sfx = true, crowd = "high", weather = true, units = "MPH", spawnAt = "business", cinematics = "full", alerts = "all", sfxVol = 7}
-- the same sound twice within a moment plays once (a button's tap + its click handler, two toasts at once)
local lastPlayed = {}
function C.play(s)
	if not (s and C.settings.sfx) then return end
	local now = os.clock()
	if lastPlayed[s] and now - lastPlayed[s] < 0.06 then return end
	lastPlayed[s] = now
	pcall(function() SoundService:PlayLocalSound(s) end)
end

C.gui = new("ScreenGui", {Name = "EmpireUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, plr:WaitForChild("PlayerGui"))
C.U = {}
C.S = nil
C.modals = {}
C.stateHooks = {}
function C.onState(fn) table.insert(C.stateHooks, fn) end
function C.locked(feature)
	local s = C.S
	if not s or not s.unlocks then return false end
	return s.unlocks[feature] == false
end
function C.lockText(feature)
	local f = C.catalog.features[feature]
	return f and ("🔒 " .. f.name .. " unlocks at " .. f.tierName .. " reputation") or "🔒 Locked"
end
end
