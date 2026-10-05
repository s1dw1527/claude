-- HQ UI (v10): the HQ card (floors to build), the elevator, and the General Manager's contract panel.
-- Everything here only ASKS the server (GameServer > HQ); the server checks reputation, cash and where you are.
return function(C)
local RGB = Color3.fromRGB
local label, button, card, header, clear, stroke = C.label, C.button, C.card, C.header, C.clear, C.stroke
local fmt, play, SND, act, R = C.fmt, C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local BUI = C.BusinessUI or {}
local HQ = {}
C.HQUI = HQ

local function btn(parent, text, pos, size, color, fn)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 13, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		fn(b)
	end)
	return b
end
local function txt(parent, text, pos, size, sizePx, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = sizePx or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
-- ask the server for fresh data each time a window is opened from the phone
local function refreshOnOpen(m, action)
	local asked = false
	m.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not m.frame.Visible then asked = false end
	end)
	m.update = function()
		if not asked then
			asked = true
			act(action)
		end
	end
end
local function mins(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- =====================================================================
-- GENERAL MANAGER
-- =====================================================================
local mgrM = modal("manager", "📋  GENERAL MANAGER", 520, 520)
if BUI.helpButton then BUI.helpButton(mgrM, "manager") end
local function renderManager(info)
	clear(mgrM.body)
	if type(info) ~= "table" then return end
	local c = card(mgrM.body, 120, 1, RGB(36, 40, 60))
	if not info.hired then
		txt(c, "You haven't hired a Manager yet.", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 18, GOLD, true)
		txt(c, "Hire one in the 👥 Staff app. Then build your HQ's Management floor and sign a contract here.", UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 60), 13, SUB)
		return
	end
	txt(c, "👔 " .. tostring(info.name) .. "  •  Level " .. info.level .. " Manager", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 24), 18, GOLD, true)
	local status = info.left > 0 and ("🟢 Under contract: " .. mins(info.left) .. " left") or "🔴 No contract — your manager is on a break"
	txt(c, status, UDim2.fromOffset(14, 40), UDim2.new(1, -28, 0, 20), 14, info.left > 0 and GREEN or RGB(255, 160, 140), true)
	txt(c, "Repairs take " .. tostring(info.repair or "?") .. " s  •  " .. info.parallel .. " at a time" .. (info.level >= 4 and "  •  biggest earners first" or "")
		.. "\n" .. (info.advanced and "Handles advanced problems too (outages, theft, road works)" or "Advanced problems need a level 5 manager") .. "\nProblems handled: " .. tostring(info.handled),
		UDim2.fromOffset(14, 64), UDim2.new(1, -28, 0, 54), 12, SUB)
	local s = card(mgrM.body, 110, 2, RGB(26, 28, 40))
	if info.hq < 2 then
		txt(s, "🏢 Your HQ needs a Management floor before a manager can work from it.", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 40), 14, RGB(255, 200, 140), true)
		btn(s, "Open HQ", UDim2.new(1, -150, 1, -50), UDim2.fromOffset(140, 40), BLUE, function() act("hqInfo") end)
	else
		txt(s, "Contract: " .. info.minutes .. " minutes for $" .. fmt(info.cost) .. "\nOnly counts down while you play. Repairs and restocks are paid at the normal price.",
			UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 50), 12, SUB)
		btn(s, info.left > 60 and "Running..." or "✍️ Sign contract", UDim2.new(0, 12, 1, -50), UDim2.new(0.5, -18, 0, 40), info.left > 60 and GRAY or GREEN, function()
			act("mgrSign")
			task.delay(0.4, function() act("mgrInfo") end)
		end)
		btn(s, "Auto-renew: " .. (info.auto and "ON" or "OFF"), UDim2.new(0.5, 6, 1, -50), UDim2.new(0.5, -18, 0, 40), info.auto and PURPLE or GRAY, function()
			act("mgrAuto", not info.auto)
			task.delay(0.3, function() act("mgrInfo") end)
		end)
	end
	local n = card(mgrM.body, 40, 3, RGB(26, 28, 40))
	txt(n, "Auto-renew only works while you're actively playing, and at most 2 times in a row.", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 1, -12), 11, SUB)
	header(mgrM.body, "Working on", 4)
	if #(info.jobs or {}) == 0 then
		local j = card(mgrM.body, 34, 5)
		txt(j, "Nothing right now.", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 1, -10), 13, SUB)
	end
	for i, job in ipairs(info.jobs or {}) do
		local j = card(mgrM.body, 34, 5 + i)
		txt(j, (job.kind == "restock" and "📦 Restocking " or "🔧 Repairing ") .. tostring(job.biz) .. (job.left and ("  —  " .. job.left .. " s") or "  (queued)"),
			UDim2.fromOffset(12, 8), UDim2.new(1, -24, 1, -10), 13, WHITE)
	end
end
refreshOnOpen(mgrM, "mgrInfo")

-- =====================================================================
-- HQ CARD
-- =====================================================================
local hqM = modal("hq", "🏢  EMPIRE HQ", 560, 560)
if BUI.helpButton then BUI.helpButton(hqM, "hq") end
local function renderHQ(info)
	clear(hqM.body)
	if type(info) ~= "table" then return end
	local top = card(hqM.body, 84, 1, RGB(36, 40, 60))
	stroke(top, GOLD, 2, 0.4)
	txt(top, info.level > 0 and ("Your HQ: " .. info.level .. " / " .. #info.floors .. " floors") or "Your HQ is an empty tower.", UDim2.fromOffset(14, 10), UDim2.new(1, -170, 0, 26), 19, GOLD, true)
	txt(top, info.unlocked and "Build floors to unlock rooms, the General Manager and your office." or ("🔒 Unlocks at " .. tostring(info.needs) .. " reputation."),
		UDim2.fromOffset(14, 42), UDim2.new(1, -170, 0, 36), 12, info.unlocked and SUB or RGB(255, 160, 140))
	btn(top, "🚪 Enter HQ", UDim2.new(1, -150, 0.5, -20), UDim2.fromOffset(136, 40), info.level > 0 and PURPLE or GRAY, function()
		if info.level > 0 then
			act("hqEnter")
			hqM.frame.Visible = false
		end
	end)
	for i, f in ipairs(info.floors) do
		local c = card(hqM.body, 58, 1 + i, f.built and RGB(30, 50, 40) or nil)
		label({Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(44, 58), Text = f.icon, TextSize = 26}, c)
		txt(c, "Floor " .. f.n .. ": " .. f.name, UDim2.fromOffset(54, 6), UDim2.new(1, -200, 0, 20), 15, WHITE, true)
		txt(c, f.desc, UDim2.fromOffset(54, 28), UDim2.new(1, -200, 0, 28), 11, SUB)
		if f.built then
			txt(c, "✔ Built", UDim2.new(1, -130, 0, 18), UDim2.fromOffset(120, 22), 15, GREEN, true)
		elseif f.n == info.level + 1 then
			btn(c, "Build $" .. fmt(f.cost), UDim2.new(1, -140, 0.5, -19), UDim2.fromOffset(130, 38), info.unlocked and GREEN or GRAY, function()
				if not info.unlocked then return end
				C.confirm("Build the " .. f.name .. " floor for $" .. fmt(f.cost) .. "?", "Build", function()
					act("hqBuy")
					task.delay(0.4, function() act("hqInfo") end)
				end)
			end)
		else
			txt(c, "$" .. fmt(f.cost), UDim2.new(1, -130, 0, 18), UDim2.fromOffset(120, 22), 13, SUB)
		end
	end
	local m = card(hqM.body, 50, 20, RGB(26, 28, 40))
	local mi = info.manager or {}
	txt(m, "📋 General Manager: " .. (mi.hired and (tostring(mi.name) .. (mi.left and mi.left > 0 and (" — " .. mins(mi.left) .. " left") or " — no contract")) or "not hired"),
		UDim2.fromOffset(12, 14), UDim2.new(1, -170, 0, 24), 13, WHITE, true)
	btn(m, "Manager", UDim2.new(1, -140, 0.5, -17), UDim2.fromOffset(130, 34), BLUE, function() act("mgrInfo") end)
end
refreshOnOpen(hqM, "hqInfo")

-- =====================================================================
-- ELEVATOR
-- =====================================================================
local elM = modal("elevator", "🛗  ELEVATOR", 380, 460)
local function renderElevator(info)
	clear(elM.body)
	if type(info) ~= "table" then return end
	header(elM.body, tostring(info.ownerName) .. "'s HQ", 0)
	local here = C.plr:GetAttribute("Interior")
	for i = #info.floors, 1, -1 do
		local f = info.floors[i]
		local c = card(elM.body, 50, #info.floors - i + 1)
		local cur = here == ("hq" .. f.n)
		btn(c, f.icon .. "  " .. f.n .. " — " .. f.name .. (cur and "  (you're here)" or ""), UDim2.fromOffset(6, 5), UDim2.new(1, -12, 1, -10), cur and GRAY or BLUE, function()
			if cur then return end
			act("hqFloor", f.n, info.owner)
			elM.frame.Visible = false
		end)
	end
	local out = card(elM.body, 50, 99)
	btn(out, "🚪 Leave the HQ", UDim2.fromOffset(6, 5), UDim2.new(1, -12, 1, -10), RED, function()
		act("leaveInterior")
		elM.frame.Visible = false
	end)
end

R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "hq" and type(a) == "table" then
		if not hqM.frame.Visible then C.openModal("hq", true) end
		renderHQ(a)
	elseif kind == "manager" and type(a) == "table" then
		if not mgrM.frame.Visible then C.openModal("manager", true) end
		renderManager(a)
	elseif kind == "elevator" and type(a) == "table" then
		C.openModal("elevator", true)
		renderElevator(a)
	end
end)
-- keep the contract timer fresh while the window is open
task.spawn(function()
	while true do
		task.wait(5)
		if mgrM.frame.Visible then act("mgrInfo") end
	end
end)
end
