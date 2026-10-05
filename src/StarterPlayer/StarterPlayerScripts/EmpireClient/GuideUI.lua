-- GUIDE UI (v10): contextual tip cards (from GameServer > Guide), the "What's this?" help window every big
-- window can open (C.showHelp), and a Tips on/off switch in Settings.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, corner, stroke, panel, tween = C.new, C.label, C.button, C.card, C.clear, C.corner, C.stroke, C.panel, C.tween
local play, SND, act, R, gui = C.play, C.SND, C.act, C.R, C.gui
local GOLD, GREEN, GRAY, BLUE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.BLUE, C.WHITE, C.SUB
local cat = C.catalog.guide or {help = {}, tips = {}}
local GU = {shown = {}}
C.GuideUI = GU

-- ===== tip card (bottom-left, out of the way of the HUD) =====
local tip = panel({AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -110), Size = UDim2.fromOffset(340, 150), BackgroundColor3 = RGB(30, 34, 56), Visible = false, ZIndex = 30}, gui)
stroke(tip, GOLD, 2, 0.2)
local tipIcon = label({Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(36, 36), TextSize = 28, ZIndex = 31}, tip)
local tipTitle = label({Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -60, 0, 22), TextSize = 16, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31}, tip)
local tipCount = label({Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -60, 0, 14), TextSize = 10, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31}, tip)
local tipText = label({Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 0, 56), TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31}, tip)
local ok = button({Position = UDim2.new(1, -110, 1, -40), Size = UDim2.fromOffset(100, 30), Text = "Got it", TextSize = 13, BackgroundColor3 = GREEN, ZIndex = 31}, tip)
local off = button({Position = UDim2.new(0, 10, 1, -40), Size = UDim2.fromOffset(120, 30), Text = "Turn off tips", TextSize = 11, BackgroundColor3 = GRAY, ZIndex = 31}, tip)
ok.MouseButton1Click:Connect(function() play(SND.click) tip.Visible = false end)
off.MouseButton1Click:Connect(function()
	play(SND.click)
	tip.Visible = false
	act("guideOff", true)
	GU.off = true
end)
GU.tip = tip
local token = 0
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind ~= "guideTip" or type(a) ~= "table" then return end
	token += 1
	local my = token
	tipIcon.Text = tostring(a.icon)
	tipTitle.Text = tostring(a.title)
	tipText.Text = tostring(a.text)
	tipCount.Text = "Tip " .. tostring(a.n) .. " of " .. tostring(a.total)
	tip.Visible = true
	table.insert(GU.shown, a.key)
	play(SND.event)
	-- tips step aside on their own after a while
	task.delay(22, function() if my == token then tip.Visible = false end end)
end)

-- ===== "What's this?" =====
local helpM = C.makeModal and C.makeModal("help", "❓  WHAT'S THIS?", 480, 380)
function C.showHelp(topic)
	if not helpM then return end
	local h = cat.help and cat.help[topic]
	clear(helpM.body)
	label({Size = UDim2.new(1, -8, 0, 30), Text = h and h.title or "Help", TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1}, helpM.body)
	label({Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = h and h.text or "No help for this yet.", TextSize = 14, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, helpM.body)
	local back = button({Size = UDim2.new(1, -8, 0, 40), Text = "OK", TextSize = 15, BackgroundColor3 = BLUE, LayoutOrder = 3}, helpM.body)
	back.MouseButton1Click:Connect(function() play(SND.click) helpM.frame.Visible = false end)
	-- (opened on top of the window that asked, without closing it)
	helpM.frame.Visible = true
	helpM.frame.ZIndex = 60
	GU.lastHelp = topic
end

-- ===== Settings: tips on/off + show them again =====
local settings = C.modals and C.modals.settings
if settings then
	local c = card(settings.body, 52, 90)
	label({Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -330, 1, 0), TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Text = "💡 Tips"}, c)
	local t = button({Position = UDim2.new(1, -320, 0.5, -19), Size = UDim2.fromOffset(150, 38), Text = "On / Off", TextSize = 14, BackgroundColor3 = BLUE}, c)
	t.MouseButton1Click:Connect(function()
		play(SND.click)
		GU.off = not GU.off
		act("guideOff", GU.off == true)
	end)
	local r = button({Position = UDim2.new(1, -160, 0.5, -19), Size = UDim2.fromOffset(150, 38), Text = "Show all again", TextSize = 13, BackgroundColor3 = GRAY}, c)
	r.MouseButton1Click:Connect(function()
		play(SND.click)
		GU.off = false
		act("guideReset")
	end)
end
end
