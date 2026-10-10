-- LAYOUT (v11.1): the responsive layout manager (also C.UIManager).
-- One place that knows the screen: viewport size and breakpoints, the safe area (notch, Roblox's top bar, the
-- home indicator), where Roblox's touch controls sit, and which big window is open.
--   • desktop / tablet: the classic layout, untouched.
--   • phone (viewport ≤ 700 wide or ≤ 500 tall): a real mobile layout. A compact HUD at the top (money / income /
--     reputation, then the story chip and event chip), small evenly spaced buttons down the left edge, 📱 ⚙️ 📸 down the
--     right edge above Roblox's jump button, ONE notification stack in the top-right corner (at most 3 cards, and it
--     never grows into the middle of the screen), the bottom of the screen left free for driving controls and
--     interaction buttons, every window sized to the screen, and only ONE big window at a time.
--     The other modules hand their frames to this one with L.slot / L.window / L.major.
-- Layout work only runs when the viewport (or the safe area) changes and when a window opens or closes —
-- never every frame.
return function(C)
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local new, gui, plr = C.new, C.gui, C.plr
local L = {}
C.Layout = L
C.UIManager = L

-- display order (top-level ZIndex in EmpireUI). Lower = further back.
-- gameplay controls < compact HUD < notifications < phone < windows < game windows < splash < critical confirm.
-- (Toasts sit above windows on purpose: "not enough cash" has to be readable while a shop is open.)
L.Z = {hud = 5, controls = 6, stack = 30, phoneDim = 33, phone = 34, modal = 40, window = 45, puzzle = 50, toast = 55, splash = 60, critical = 80}
L.MIN_SCALE = 0.8          -- windows never shrink text below 80% on a phone: they reflow (narrower, scrolling) instead
L.ROW1, L.ROW2 = 34, 26    -- compact HUD rows (px): money row, story / event chips
L.SIDE = 44                -- left-column buttons (px)
L.RSIDE = 52               -- right-column width (px): the 📱 phone button is 52, ⚙️ and 📸 are 44
L.STACK_MAX = 3            -- notification cards visible at once
L.GAP = 6

-- ===== breakpoints =====
function L.classify(vp)
	if vp.X <= 700 or vp.Y <= 500 then return "phone" end
	if vp.X < 1100 or vp.Y < 700 then return "tablet" end
	return "desktop"
end

-- ===== safe area =====
-- Two invisible probes: one fills the whole screen, one fills the area Roblox calls safe (clear of the notch, the
-- top-bar buttons and the home indicator). The difference is the inset on each side.
local pg = plr:WaitForChild("PlayerGui")
local probeFull = new("ScreenGui", {Name = "EmpireSafeProbe", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, DisplayOrder = -50}, pg)
local fullF = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false}, probeFull)
local probeSafe = new("ScreenGui", {Name = "EmpireSafeProbe2", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = -50}, pg)
local safeF = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false}, probeSafe)
local MARGIN = 8
local function computeSafe(vp)
	local ok, l, t, r, b = pcall(function()
		local fp, fs = fullF.AbsolutePosition, fullF.AbsoluteSize
		local sp, ss = safeF.AbsolutePosition, safeF.AbsoluteSize
		-- the probes are only trusted once they really cover the screen
		if math.abs(fs.X - vp.X) > 2 or math.abs(fs.Y - vp.Y) > 2 or ss.X < vp.X * 0.5 or ss.Y < vp.Y * 0.5 then error("probe not ready") end
		return sp.X - fp.X, sp.Y - fp.Y, (fp.X + fs.X) - (sp.X + ss.X), (fp.Y + fs.Y) - (sp.Y + ss.Y)
	end)
	if not ok then
		-- fallback: Roblox's top bar only
		local inset = 36
		pcall(function() inset = GuiService:GetGuiInset().Y end)
		l, t, r, b = 0, inset, 0, 0
	end
	return {l = math.max(0, l) + MARGIN, t = math.max(36, t) + 6, r = math.max(0, r) + MARGIN, b = math.max(0, b) + MARGIN}
end

-- ===== state =====
L.vp = Vector2.new(1280, 720)
L.mode = "desktop"
L.compact = false
L.safe = {l = MARGIN, t = 42, r = MARGIN, b = MARGIN}
local listeners, busyListeners = {}, {}
local sig = ""
local function fire(list, ...)
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn, ...)
		if not ok then warn("[CornerEmpire] layout: " .. tostring(err)) end
	end
end
-- the space each part of the compact layout gets (pixels, absolute)
local function zones()
	local vp, s = L.vp, L.safe
	-- Roblox's own touch controls: thumbstick bottom-left, jump button bottom-right
	local smallCtl = math.min(vp.X, vp.Y) <= 500
	L.jumpZone = smallCtl and {w = 100, h = 92} or {w = 175, h = 215}
	L.controlsH = L.jumpZone.h + 6
	L.hudTop = s.t
	L.hudBottom = s.t + L.ROW1 + 4 + L.ROW2
	-- edge columns
	L.leftX = s.l
	L.rightX = vp.X - s.r - L.RSIDE
	L.colTop = L.hudBottom + 8
	L.rightBottom = vp.Y - s.b - L.controlsH          -- the right column ends just above the jump button
	L.rightColH = 44 + 44 + 52 + 2 * L.GAP            -- 📸 ⚙️ 📱
	L.rightColTop = L.rightBottom - L.rightColH
	-- THE notification stack: top-right, below the HUD rows. It is never allowed below ~38% of the screen height
	-- (the middle of the screen is where the player, the road and the businesses are), and it stops above the right-hand
	-- buttons. On a short landscape screen there's no room above them, so it moves in beside them instead.
	L.stackY = L.hudBottom + 6
	local want = L.portrait and vp.Y * 0.38 or vp.Y * 0.5
	local edge = vp.X - s.r
	if want > L.rightColTop - 8 then edge = L.rightX - 6 end
	L.stackW = math.clamp(math.min(math.floor(vp.X * (L.portrait and 0.72 or 0.4)), edge - s.l - L.SIDE - 8), 180, 300)   -- ≈ 72% of a portrait phone's width
	L.stackX = edge - L.stackW
	L.stackBottom = math.max(L.stackY + 76, want)                      -- normal budget
	L.stackMaxBottom = math.max(L.stackBottom, math.min(vp.Y * 0.5, L.portrait and L.rightColTop - 8 or vp.Y * 0.62))   -- only for a feed you opened yourself
	-- windows (modals, the phone, game windows): ~92% wide, ~84% tall, below the HUD's first row
	local wTop = s.t + L.ROW1 + 6
	local w = math.min(vp.X * 0.92, vp.X - s.l - s.r)
	local h = math.min(vp.Y * 0.84, vp.Y - wTop - s.b)
	L.win = {x = (vp.X - w) / 2, y = wTop + math.max(0, (vp.Y - wTop - s.b - h) / 2), w = w, h = h}
end
function L.refresh(force)
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	if vp.X < 50 or vp.Y < 50 then return end     -- the camera isn't ready yet
	local safe = computeSafe(vp)
	local mode = L.classify(vp)
	local s = mode .. "|" .. math.floor(vp.X) .. "x" .. math.floor(vp.Y) .. "|" .. safe.l .. "," .. safe.t .. "," .. safe.r .. "," .. safe.b
	if s == sig and not force then return end
	sig = s
	L.vp, L.mode, L.safe = vp, mode, safe
	L.compact = mode == "phone"
	L.portrait = vp.Y > vp.X
	L.small = math.min(vp.X, vp.Y) <= 430
	L.tiny = math.min(vp.X, vp.Y) <= 390
	zones()
	gui:SetAttribute("LayoutMode", mode)
	L.passes = (L.passes or 0) + 1     -- (tests check this stays put while nothing changes: no per-frame layout)
	fire(listeners, L)
end
-- fn(L) now and on every layout change
function L.onChange(fn)
	table.insert(listeners, fn)
	local ok, err = pcall(fn, L)
	if not ok then warn("[CornerEmpire] layout: " .. tostring(err)) end
end
-- several changes in one frame → one layout pass
local pending = false
local function schedule()
	if pending then return end
	pending = true
	task.defer(function()
		pending = false
		L.refresh()
	end)
end
local camConn
local function watchCamera()
	if camConn then camConn:Disconnect() end
	local cam = Workspace.CurrentCamera
	if cam then camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(schedule) end
	schedule()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
safeF:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
safeF:GetPropertyChangedSignal("AbsolutePosition"):Connect(schedule)
watchCamera()
L.refresh(true)

-- ===== one UIScale per frame (never stack two by accident) =====
function L.scaleOf(frame)
	local sc = frame:FindFirstChildOfClass("UIScale")
	if not sc then sc = new("UIScale", {}, frame) end
	return sc
end

-- ===== compact containers =====
-- row 2 of the HUD, the left and right button columns, and the two notification stacks. They only exist on the
-- phone layout; on desktop they're hidden and everything sits where it always did.
local function container(name, z, vertical, align, clip)
	local f = new("Frame", {Name = name, BackgroundTransparency = 1, Visible = false, ZIndex = z, ClipsDescendants = clip ~= false}, gui)
	local lay = new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = align or Enum.VerticalAlignment.Top}, f)
	return f, lay
end
L.box = {}
L.box.row2 = container("CompactRow2", L.Z.hud, false)
L.box.left = container("CompactLeft", L.Z.hud, true)
L.box.right = container("CompactRight", L.Z.controls, true, Enum.VerticalAlignment.Bottom)
L.box.top = container("CompactTopStack", L.Z.stack, true, nil, false)
L.box.bottom = L.box.top    -- (v11.3: there is ONE stack now; the bottom of the screen stays free for controls)
L.box.row2:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Left
L.box.left:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 10)             -- evenly spaced
L.box.top:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Right
-- cards that are waiting for a free place in the stack (visible = true, but parked here until there's room)
L.holder = new("Frame", {Name = "QueuedCards", BackgroundTransparency = 1, Visible = false, Size = UDim2.new()}, gui)
local function placeBoxes()
	local b = L.box
	for _, f in pairs(b) do f.Visible = false end
	if not L.compact then return end
	local s, vp = L.safe, L.vp
	b.row2.Position = UDim2.fromOffset(s.l, s.t + L.ROW1 + 4)
	b.row2.Size = UDim2.fromOffset(vp.X - s.l - s.r, L.ROW2)
	b.left.Position = UDim2.fromOffset(L.leftX, L.colTop)
	b.left.Size = UDim2.fromOffset(L.SIDE, math.max(60, L.rightBottom - L.colTop))
	b.right.Position = UDim2.fromOffset(L.rightX, L.colTop)
	b.right.Size = UDim2.fromOffset(L.RSIDE, math.max(60, L.rightBottom - L.colTop))
	b.top.Position = UDim2.fromOffset(L.stackX, L.stackY)
	b.top.Size = UDim2.fromOffset(L.stackW, L.stackMaxBottom - L.stackY)
	L.applyBusy()
end

-- ===== slots: a frame that moves into a compact container on phones =====
-- where: "row2" | "left" | "right" | "top" ("bottom" is the same stack). opts.size = the compact size (UDim2, or fn(L) →
-- UDim2); stack cards keep their height and are narrowed (and scaled down to at most 80%) to the stack's width, and
-- their text shrinks to fit its box.
-- opts.compactOnly: the frame only exists on the phone layout (hidden on desktop).
-- opts.expanded: fn() → true while the card is open because the PLAYER opened it (the CityBuzz feed).
local slots = {}
-- Who gets a place first when more than L.STACK_MAX cards are showing. Cards that need an answer come first.
local PRIORITY = {TutorialCard = 1, ProblemCard = 2, DeliveryCard = 3, PoliceAlertBar = 4, CityJobCard = 4.5, RivalCard = 4.7, HeistBagHUD = 5, RacePanel = 6, MegaBar = 7, BeefPill = 8,
	ViralMomentPopup = 9, StoryPill = 10, InteriorBar = 11, AchievementCard = 12, GuideTip = 13, RivalBubble = 14, HouseTourPanel = 15, BuzzFeed = 99}
local scheduleReflow, adaptOne
function L.slot(frame, where, order, opts)
	opts = opts or {}
	if where == "bottom" then where = "top" end
	local e = {frame = frame, where = where, order = order or 0, opts = opts, prio = PRIORITY[frame.Name] or (20 + (order or 0)),
		parent = frame.Parent, pos = frame.Position, anchor = frame.AnchorPoint, size = frame.Size, z = frame.ZIndex}
	table.insert(slots, e)
	if where == "top" then
		frame:GetPropertyChangedSignal("Visible"):Connect(function() scheduleReflow() end)
		-- labels and buttons added to the card later (most cards fill themselves in after they're registered)
		frame.DescendantAdded:Connect(function(x) if L.compact then task.defer(adaptOne, x, true) end end)
	end
	L.applySlot(e)
	return e
end
local function designSize(e)
	return e.opts.designSize or e.size
end

-- ===== text that fits (phone layout) =====
-- Cards were designed for a wide screen, so their text boxes are sized for the desktop. On a phone every label in a
-- stack card gets TextScaled with a cap at its own size, so the text shrinks to fit its box instead of spilling out of
-- it (never below 9 px before the card's scale: cards are never scaled below 80%).
local adapted = setmetatable({}, {__mode = "k"})
function adaptOne(x, on)
	if x.ClassName ~= "TextLabel" and x.ClassName ~= "TextButton" then return end
	local o = adapted[x]
	if on then
		if not o and not x.TextScaled and x.AutomaticSize == Enum.AutomaticSize.None then
			o = {size = x.TextSize}
			o.cap = new("UITextSizeConstraint", {MaxTextSize = x.TextSize, MinTextSize = math.min(x.TextSize, 9)}, x)
			x.TextScaled = true
			adapted[x] = o
		end
	elseif o then
		x.TextScaled = false
		x.TextSize = o.size
		o.cap:Destroy()
		adapted[x] = nil
	end
end
function L.adaptText(frame, on)
	for _, x in ipairs(frame:GetDescendants()) do adaptOne(x, on) end
end

local function cardScale(e)
	local ds = designSize(e)
	local dw = ds.X.Offset > 0 and ds.X.Offset or 300
	local s = math.clamp(L.stackW / dw, L.MIN_SCALE, 1)
	-- a tall card (problem, delivery) shrinks a little more rather than push into the middle of the screen
	local dh = e.opts.compactHeight or ds.Y.Offset
	if dh * s > L.stackBottom - L.stackY then s = math.max(L.MIN_SCALE, (L.stackBottom - L.stackY) / dh) end
	return s, dw, ds
end
function L.applySlot(e)
	local f = e.frame
	if L.compact then
		if e.where == "top" then
			local s, dw, ds = cardScale(e)
			L.scaleOf(f).Scale = s
			f.Size = UDim2.fromOffset(math.min(dw, L.stackW / s), e.opts.compactHeight or ds.Y.Offset)
			f.LayoutOrder = e.prio
			f.Parent = L.box.top
			L.adaptText(f, true)
		else
			f.Parent = L.box[e.where]
			f.LayoutOrder = e.order
			if e.opts.size then f.Size = type(e.opts.size) == "function" and e.opts.size(L) or e.opts.size end
		end
		if e.opts.compactOnly then f.Visible = true end
		if e.opts.onCompact then e.opts.onCompact(true) end
	else
		if e.opts.compactOnly then f.Visible = false end
		f.Parent = e.parent
		f.Position, f.AnchorPoint, f.Size = e.pos, e.anchor, e.size
		local sc = f:FindFirstChild("UIScale")
		if sc and e.where == "top" then sc.Scale = 1 end
		if e.where == "top" then L.adaptText(f, false) end
		if e.opts.onCompact then e.opts.onCompact(false) end
	end
end

-- ===== the notification stack: at most STACK_MAX cards, inside a height budget =====
-- Showing cards (Visible = true) are sorted by priority. A card gets a place if there are fewer than 3 and it fits in
-- the budget (the first card always gets one, whatever its size). The others wait in L.holder, still "visible" from
-- their owner's point of view, and move up as soon as a card is dismissed. A card the player opened on purpose (the
-- CityBuzz feed) may use the larger budget.
local reflowing = false
local function reflowStack()
	if not L.compact or reflowing then return end
	reflowing = true
	local list = {}
	for _, e in ipairs(slots) do
		if e.where == "top" and e.frame.Visible then table.insert(list, e) end
	end
	table.sort(list, function(x, y) return x.prio < y.prio end)
	local used, n = 0, 0
	local budget = L.stackBottom - L.stackY
	local maxBudget = L.stackMaxBottom - L.stackY
	for _, e in ipairs(list) do
		local s = cardScale(e)
		local h = (e.opts.compactHeight or designSize(e).Y.Offset) * s + L.GAP
		local mine = e.opts.expanded and e.opts.expanded()
		local fits = n == 0 or used + h <= budget or (mine and used + h <= maxBudget)
		if n < L.STACK_MAX and fits then
			e.frame.Parent = L.box.top
			e.frame.LayoutOrder = e.prio
			used += h
			n += 1
		else
			e.frame.Parent = L.holder
		end
	end
	reflowing = false
end
L.reflowStack = reflowStack
function scheduleReflow()
	task.defer(reflowStack)
end
-- a slotted card changed its own design size (e.g. the tutorial card, the CityBuzz feed)
function L.resize(frame, size)
	for _, e in ipairs(slots) do
		if e.frame == frame then
			e.size = size
			L.applySlot(e)
			scheduleReflow()
			return
		end
	end
	frame.Size = size
end
function L.isSlotted(frame)
	for _, e in ipairs(slots) do if e.frame == frame then return L.compact end end
	return false
end

-- ===== big windows (majors): only one at a time on a phone =====
local majors = {}
L.majors = majors
local busyNow = false
function L.busy()
	for _, o in pairs(majors) do
		if o.frame.Visible and o.frame.Parent and (not o.compactOnly or L.compact) then return true, o.name end
	end
	return false
end
function L.onBusy(fn) table.insert(busyListeners, fn) end
L.driving = false
function L.setDriving(v)
	if L.driving == v then return end
	L.driving = v
	L.applyBusy()
end
function L.applyBusy()
	local b = L.busy()
	busyNow = b
	local box = L.box
	if L.compact then
		-- priority 2 (row 2, the left column, the stacks) steps aside for a big window; driving keeps the road clear
		box.row2.Visible = not b and not L.driving
		box.left.Visible = not b and not L.driving
		box.top.Visible = not b
		box.right.Visible = true
	end
	fire(busyListeners, b)
end
function L.major(name, frame, opts)
	opts = opts or {}
	local o = {name = name, frame = frame, close = opts.close or function() frame.Visible = false end, compactOnly = opts.compactOnly}
	majors[name] = o
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible and L.compact and (not o.compactOnly or L.compact) then
			-- one big window at a time on a phone: close the others
			for n, other in pairs(majors) do
				if n ~= name and other.frame.Visible and not (other.compactOnly and not L.compact) then
					pcall(other.close)
				end
			end
		end
		L.applyBusy()
	end)
	return o
end

-- ===== window fitting =====
-- scrollable windows reflow on a phone: text stays ≥ 80% size, the window gets narrower/shorter and scrolls.
-- fixed windows (game screens, puzzles) scale as a whole to fit.
-- Returns the scale to use. Desktop: the window keeps its design size (only shrunk if the screen is smaller).
function L.fitWindow(frame, sc, dw, dh, fixed, sheet)
	if not L.compact then
		local s = math.min(1, (L.vp.X - 16) / dw, (L.vp.Y - 16) / dh)
		return math.max(0.45, s), UDim2.fromOffset(dw, dh)
	end
	local a = L.win
	local s, w, h
	if sheet then
		-- a bottom sheet: the lower ~45% of the screen, so the world above stays visible (decorating a room)
		s = math.clamp(a.w / dw, L.MIN_SCALE, 1)
		w = math.min(dw, a.w / s)
		h = math.min(dh, (L.vp.Y * 0.45) / s)
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.fromOffset(a.x + a.w / 2, L.vp.Y - L.safe.b)
		return s, UDim2.fromOffset(w, h)
	end
	if fixed then
		s = math.min(1, a.w / dw, a.h / dh)
		w, h = dw, dh
	else
		s = math.clamp(a.w / dw, L.MIN_SCALE, 1)
		w = math.min(dw, a.w / s)
		h = math.min(dh, a.h / s)
	end
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset(a.x + a.w / 2, a.y + a.h / 2)
	return s, UDim2.fromOffset(w, h)
end
-- a centred window that isn't a Menus modal: remember its design, fit it when it opens and when the screen changes
local windows = {}
function L.window(name, frame, opts)
	opts = opts or {}
	local w = {name = name, frame = frame, size = frame.Size, pos = frame.Position, anchor = frame.AnchorPoint, opts = opts, sc = L.scaleOf(frame)}
	windows[name] = w
	local function apply()
		if not frame.Visible and not opts.always then return end
		local s, size = L.fitWindow(frame, w.sc, w.size.X.Offset, w.size.Y.Offset, opts.fixed, opts.sheet)
		if not L.compact then
			frame.Position, frame.AnchorPoint = w.pos, w.anchor
			-- desktop: unchanged unless the window is bigger than the screen
			s = (opts.desktopFit == false) and 1 or s
		end
		frame.Size = size
		w.sc.Scale = s
		if opts.onFit then opts.onFit(L.compact, s) end
	end
	w.apply = apply
	frame:GetPropertyChangedSignal("Visible"):Connect(apply)
	table.insert(listeners, function() apply() end)
	if opts.major ~= false then L.major(name, frame, {close = opts.close}) end
	if opts.z then frame.ZIndex = opts.z end
	apply()
	return w
end

-- ===== UIManager API =====
function L.OpenModal(name)
	local m = C.modals[name]
	if m then
		if not m.frame.Visible then C.openModal(name) end
		return m.frame.Visible
	end
	local o = majors[name]
	if o then o.frame.Visible = true return true end
	return false
end
function L.CloseModal(name)
	local m = C.modals[name] or majors[name]
	if m then
		local o = majors[name]
		if o then pcall(o.close) else m.frame.Visible = false end
	end
end
function L.IsOpen(name)
	local m = C.modals[name] or majors[name]
	return m ~= nil and m.frame.Visible
end
function L.CloseAll()
	for _, o in pairs(majors) do if o.frame.Visible then pcall(o.close) end end
end
-- which big window is open (nil if none)
function L.Current()
	local _, name = L.busy()
	return name
end

-- ===== world labels and chat on a phone (v11.2) =====
-- Speech bubbles, the names over people and the signs over buildings are BillboardGuis sized in screen pixels, so on a
-- phone they cover far more of the view than on a monitor ("messages too big"). On the phone layout they're drawn at
-- 65%; the Roblox chat window and chat bubbles use smaller text. Desktop: untouched.
L.BILLBOARD_SCALE = 0.65
local bbOrig = setmetatable({}, {__mode = "k"})
local function fitBillboard(bb)
	if not bb.Parent then return end
	local o = bbOrig[bb]
	if not o then
		if not L.compact then return end
		o = bb.Size
		bbOrig[bb] = o
	end
	local k = L.compact and L.BILLBOARD_SCALE or 1
	bb.Size = UDim2.new(o.X.Scale, o.X.Offset * k, o.Y.Scale, o.Y.Offset * k)
end
L.fitBillboard = fitBillboard
Workspace.DescendantAdded:Connect(function(x)
	if L.compact and x:IsA("BillboardGui") then task.defer(fitBillboard, x) end
end)
local wasCompact = false
local function fitWorldAndChat()
	if L.compact == wasCompact then return end
	wasCompact = L.compact
	for _, x in ipairs(Workspace:GetDescendants()) do
		if x:IsA("BillboardGui") then fitBillboard(x) end
	end
	pcall(function()
		local tcs = game:GetService("TextChatService")
		local win, bub = tcs:FindFirstChildOfClass("ChatWindowConfiguration"), tcs:FindFirstChildOfClass("BubbleChatConfiguration")
		if win then
			win.TextSize = L.compact and 13 or 14
			win.HeightScale = L.compact and 0.6 or 1
		end
		if bub then bub.TextSize = L.compact and 13 or 16 end
	end)
end

-- re-place the containers and every slot on each layout change
table.insert(listeners, 1, function()
	placeBoxes()
	for _, e in ipairs(slots) do L.applySlot(e) end
	reflowStack()
	fitWorldAndChat()
end)
placeBoxes()
end
