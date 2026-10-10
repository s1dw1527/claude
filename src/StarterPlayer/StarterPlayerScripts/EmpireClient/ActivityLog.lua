-- ACTIVITY LOG (v14): every notification of the session, newest first, in the 🔔 Activity phone app. Toasts stay
-- short and never pile up on screen (HUD); anything you might have missed is here. The phone button shows a small
-- badge with the number of messages that were logged without being shown.
return function(C)
local RGB = Color3.fromRGB
local label, card, clear, new, corner = C.label, C.card, C.clear, C.new, C.corner
local U, SUB, WHITE = C.U, C.SUB, C.WHITE
local modal = C.makeModal
if not modal then return end
local A = {}
C.ActivityLog = A

local COLORS = {money = C.GOLD, rep = RGB(255, 225, 120), warn = RGB(235, 80, 80), info = RGB(120, 170, 255)}
local ICONS = {money = "💰", rep = "⭐", warn = "⚠️", info = "ℹ️"}
local m = modal("activity", "🔔  ACTIVITY", 520, 560)
local function ago(t)
	local d = math.max(0, os.time() - t)
	if d < 60 then return d .. "s ago" end
	if d < 3600 then return math.floor(d / 60) .. "m ago" end
	return math.floor(d / 3600) .. "h ago"
end
local function render()
	clear(m.body)
	local list = U.activity or {}
	if #list == 0 then
		local c = card(m.body, 44, 1)
		label({Size = UDim2.fromScale(1, 1), Text = "Nothing yet. Notifications show up here.", TextSize = 13, TextColor3 = SUB}, c)
		return
	end
	for i, e in ipairs(list) do
		local c = card(m.body, 46, i)
		local bar = new("Frame", {Size = UDim2.new(0, 5, 1, -10), Position = UDim2.fromOffset(4, 5), BorderSizePixel = 0, BackgroundColor3 = COLORS[e.cat] or COLORS.info}, c)
		corner(bar, 3)
		label({Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(26, 46), Text = ICONS[e.cat] or "ℹ️", TextSize = 16}, c)
		local t = label({Position = UDim2.fromOffset(42, 4), Size = UDim2.new(1, -110, 1, -8), Text = e.msg, TextSize = 13, TextWrapped = true, TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, c)
		t.Font = Enum.Font.GothamMedium
		label({Position = UDim2.new(1, -66, 0, 0), Size = UDim2.fromOffset(60, 46), Text = ago(e.t), TextSize = 11, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Right}, c)
	end
end
A.render = render
-- the badge on the phone button
local badge
local function updateBadge()
	if not badge then
		local pb = C.gui:FindFirstChild("PhoneButton", true)
		if not pb then return end
		badge = new("TextLabel", {Name = "UnreadBadge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = RGB(230, 60, 70), TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextSize = 11, BorderSizePixel = 0, ZIndex = (pb.ZIndex or 1) + 2, Visible = false}, pb)
		corner(badge, 9)
	end
	local n = U.unread or 0
	badge.Visible = n > 0
	badge.Text = n > 9 and "9+" or tostring(n)
end
A.updateBadge = updateBadge
U.onActivity = function()
	updateBadge()
	if m.frame.Visible then render() end
end
m.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if m.frame.Visible then
		U.unread = 0
		updateBadge()
		render()
	end
end)
task.defer(updateBadge)
end
