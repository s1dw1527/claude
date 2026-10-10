-- KITCHEN UI (v14): the RUSH ORDERS panel. A customer (with their type: 🎓 Student, 💼 Office worker...) orders one of
-- your products; the ticket shows its recipe; tap the ingredient/step buttons in that order before the patience bar
-- runs out. Every tap answers (a rising note when right, a buzz when wrong), a perfect dish plays a "ka-ching" and
-- flies the dish out to the customer. The server (GameServer > Kitchen) makes the orders and judges them.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, panel, stroke, corner, gradient = C.new, C.label, C.button, C.panel, C.stroke, C.corner, C.gradient
local fmt, play, SND, act, R, gui, U = C.fmt, C.play, C.SND, C.act, C.R, C.gui, C.U
local GOLD, GREEN, GRAY, RED, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.WHITE, C.SUB
local Lay = C.Layout
local KU = {order = nil, tapped = {}}
C.KitchenUI = KU

local win = panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(520, 380), Visible = false, ZIndex = 45}, gui)
win.Name = "KitchenWindow"
gradient(win, RGB(60, 40, 25), RGB(28, 20, 14))
stroke(win, GOLD, 3, 0)
Lay.window("kitchen", win, {fixed = true, z = Lay.Z.window})   -- (scaled as a whole on phones, like the Arcade game window)
local function z(o, n) o.ZIndex = n or 46 return o end
local title = z(label({Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -130, 0, 28), TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "🍳 RUSH ORDERS"}, win))
local stats = z(label({Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 18), TextSize = 13, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Left}, win))
local endBtn = z(button({Position = UDim2.new(1, -112, 0, 8), Size = UDim2.fromOffset(100, 36), Text = "End shift", TextSize = 13, BackgroundColor3 = GRAY}, win), 47)
endBtn.MouseButton1Click:Connect(function() play(SND.click) act("cookEnd") end)
-- the customer and the ticket
local cust = z(label({Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 0, 24), TextSize = 16, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left}, win))
local ticket = z(new("Frame", {Position = UDim2.fromOffset(14, 86), Size = UDim2.new(1, -28, 0, 56), BackgroundColor3 = RGB(250, 244, 225), BorderSizePixel = 0}, win))
corner(ticket, 8)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center}, ticket)
-- patience
local patienceBg = z(new("Frame", {Position = UDim2.fromOffset(14, 148), Size = UDim2.new(1, -28, 0, 10), BackgroundColor3 = RGB(20, 14, 10), BorderSizePixel = 0}, win))
corner(patienceBg, 5)
local patience = z(new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0}, patienceBg), 47)
corner(patience, 5)
-- the buttons
local grid = z(new("Frame", {Position = UDim2.fromOffset(14, 166), Size = UDim2.new(1, -28, 1, -210), BackgroundTransparency = 1}, win))
new("UIGridLayout", {CellSize = UDim2.new(1 / 3, -8, 0.5, -6), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
local feedback = z(label({Position = UDim2.new(0, 14, 1, -40), Size = UDim2.new(1, -28, 0, 30), TextSize = 16, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, Text = ""}, win))
KU.win, KU.grid, KU.ticket, KU.feedback, KU.patience = win, grid, ticket, feedback, patience

local slots = {}
local function renderTicket()
	for _, x in ipairs(ticket:GetChildren()) do if x:IsA("GuiObject") then x:Destroy() end end
	table.clear(slots)
	local o = KU.order
	if not o then return end
	for i, st in ipairs(o.steps) do
		local done = KU.tapped[i] ~= nil
		local f = z(new("Frame", {Size = UDim2.fromOffset(78, 46), BackgroundColor3 = done and RGB(120, 200, 120) or RGB(230, 220, 195), BorderSizePixel = 0, LayoutOrder = i}, ticket), 47)
		corner(f, 6)
		z(label({Size = UDim2.new(1, 0, 0.6, 0), Text = st.i, TextSize = 20}, f), 48)
		z(label({Position = UDim2.fromScale(0, 0.58), Size = UDim2.new(1, 0, 0.42, 0), Text = st.n, TextSize = 10, TextColor3 = RGB(40, 30, 20), TextScaled = false}, f), 48)
		slots[i] = f
	end
end
local function send()
	local o = KU.order
	if not o then return end
	local seq = {}
	for i, st in ipairs(KU.tapped) do seq[i] = st end
	act("cookDone", o.id, seq)
	KU.order = nil
end
local function tap(opt)
	local o = KU.order
	if not o then return end
	local i = #KU.tapped + 1
	local want = o.steps[i]
	table.insert(KU.tapped, opt.n)
	if want and opt.n == want.n then
		if C.AudioDirector then C.AudioDirector.note(i * 2, 0.25) end
		renderTicket()
		if #KU.tapped == #o.steps then send() end
	else
		-- a wrong step: the order is off (the server agrees: it checks the whole sequence)
		if C.jingle then C.jingle("fail", 0.3) end
		feedback.Text = "❌ Not " .. opt.n .. "!"
		feedback.TextColor3 = RED
		send()
	end
end
local function renderButtons()
	for _, x in ipairs(grid:GetChildren()) do if x:IsA("GuiObject") then x:Destroy() end end
	local o = KU.order
	if not o then return end
	for k, opt in ipairs(o.options) do
		local b = z(button({Text = opt.i .. "\n" .. opt.n, TextSize = 15, TextWrapped = true, BackgroundColor3 = RGB(110, 70, 40), LayoutOrder = k}, grid), 47)
		b.Name = "Step_" .. opt.n
		b.MouseButton1Click:Connect(function() tap(opt) end)
	end
end
KU.tap = tap
local shownAt = 0
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "cookOrder" and type(a) == "table" then
		KU.order = a
		KU.tapped = {}
		shownAt = os.clock()
		title.Text = "🍳 " .. string.upper(a.bizName or "RUSH ORDERS")
		stats.Text = string.format("Served %d  •  streak %d  •  tips $%s  •  🔥 rush +%d%%", a.served or 0, a.streak or 0, fmt(a.tips or 0), math.floor((a.rush or 0) * 100))
		cust.Text = a.customer.icon .. " " .. a.customer.name .. " wants  " .. a.icon .. " " .. a.dish
		feedback.Text = ""
		renderTicket()
		renderButtons()
		if not win.Visible then
			if C.closeModals then C.closeModals() end
			win.Visible = true
		end
	elseif kind == "cookResult" and type(a) == "table" then
		if a.ok then
			feedback.Text = "✅ Perfect!  +$" .. fmt(a.tip) .. "   🔥 streak " .. a.streak .. "  •  sales +" .. math.floor((a.rush or 0) * 100) .. "%"
			feedback.TextColor3 = GREEN
			if C.jingle then C.jingle("sale", 0.35) end
		else
			feedback.Text = "😕 " .. tostring(a.why) .. "  (" .. a.misses .. "/" .. a.limit .. ")"
			feedback.TextColor3 = RED
		end
		KU.order = nil
		renderButtons()
	elseif kind == "cookEnd" then
		KU.order = nil
		win.Visible = false
	end
end)
-- the patience bar
game:GetService("RunService").RenderStepped:Connect(function()
	local o = KU.order
	if win.Visible and o then
		local left = math.clamp(1 - (os.clock() - shownAt) / o.limit, 0, 1)
		patience.Size = UDim2.fromScale(left, 1)
		patience.BackgroundColor3 = left > 0.5 and GREEN or (left > 0.25 and GOLD or RED)
	end
end)
end
