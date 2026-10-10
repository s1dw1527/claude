-- v14: UI clarity. Toasts (2-4.5 s, one at a time, repeats counted, overflow to the Activity log), the 🔔 Activity
-- app and its badge, a sound on every button press, and TEXT CONTRAST: every visible text on the HUD and in every
-- window, measured against the background actually behind it (WCAG ratio).
-- Run with: python3 tests/run.py tests/ui_test.lua
H.main(function()
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut = 0
	d.rep, d.cash = 1e7, 1e9
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	H.task.wait(2)
	local U = cc.U
	local gui = a.PlayerGui

	H.section("Toasts")
	local toast
	for _, x in ipairs(gui:GetDescendants()) do
		if x.ClassName == "Frame" and x.ZIndex == cc.Layout.Z.toast then toast = x end
	end
	H.check(toast ~= nil, "the toast panel exists")
	local function toastText() for _, x in ipairs(toast:GetChildren()) do if x.ClassName == "TextLabel" then return x.Text end end end
	-- wait for anything already showing to clear
	H.task.wait(6)
	table.clear(U.toastQueue)
	local log0 = #U.activity
	U.toast("💰 Test sale +$100")
	H.task.wait(0.5)
	H.check(toast.Visible and toastText():find("Test sale"), "a toast shows")
	U.toast("💰 Test sale +$100")
	U.toast("💰 Test sale +$100")
	H.task.wait(0.1)
	H.check(toastText():find("×3"), "the same message again counts up (×3) instead of stacking: " .. tostring(toastText()))
	U.toast("ℹ️ Second")
	U.toast("⚠️ Third")
	U.toast("ℹ️ Fourth")
	U.toast("ℹ️ Fifth (overflow)")
	H.check(#U.toastQueue == 3, "while one shows, the next ones wait (3 at most): " .. #U.toastQueue)
	H.check((U.unread or 0) >= 1, "the overflow goes to the Activity log unread (" .. tostring(U.unread) .. ")")
	H.check(#U.activity >= log0 + 5, "every toast is logged (" .. (#U.activity - log0) .. " new)")
	-- timing: a short toast leaves after ~2 s, a long one stays longer but at most 4.5 s
	table.clear(U.toastQueue)
	H.task.wait(6)
	local function lifeOf(msg)
		U.toast(msg)
		local start = H.now()
		H.task.wait(0.4)
		while toast.Visible and H.now() - start < 10 do H.task.wait(0.1) end
		return H.now() - start
	end
	local short = lifeOf("ℹ️ Short")
	local long = lifeOf("ℹ️ " .. string.rep("A long message that goes on and on. ", 6))
	H.check(short >= 2 and short <= 3.2, string.format("a short toast is on screen %.1f s", short))
	H.check(long > short and long <= 5.2, string.format("a long one %.1f s (never more than 4.5 s + the slide)", long))
	-- categories: color AND icon
	local edge
	for _, x in ipairs(toast:GetChildren()) do if x.ClassName == "Frame" and x.Size.X.Offset == 6 then edge = x end end
	U.toast("⚠️ Danger test")
	H.task.wait(0.3)
	local warnColor = edge and edge.BackgroundColor3
	H.task.wait(5)
	U.toast("💰 Money test +$5")
	H.task.wait(0.3)
	local moneyColor = edge and edge.BackgroundColor3
	H.check(edge and warnColor ~= moneyColor, "a warning and a money toast have different colored edges (plus their own icon)")
	H.task.wait(5)

	H.section("🔔 Activity app")
	cc.openModal("activity", true)
	H.task.wait(0.5)
	local m = cc.modals.activity
	local rows = 0
	for _, x in ipairs(m.body:GetDescendants()) do if x.ClassName == "TextLabel" and tostring(x.Text):find("Test sale") then rows += 1 end end
	H.check(m.frame.Visible and rows >= 1, "the Activity app lists past notifications")
	H.check(U.unread == 0, "opening it clears the unread count")
	local badge = gui:FindFirstChild("UnreadBadge", true)
	H.check(badge and not badge.Visible, "the phone button's badge is hidden when there's nothing unread")
	cc.closeModals()

	H.section("Every button answers")
	local played = 0
	local realPlay = cc.play
	cc.play = function(s) if s == cc.SND.tap then played += 1 end return realPlay(s) end
	local pressed, total = 0, 0
	cc.openModal("explore", true)
	H.task.wait(1)
	for _, x in ipairs(gui:GetDescendants()) do
		if x.ClassName == "TextButton" and x.AutoButtonColor == false and x:FindFirstChildOfClass("UIScale") then
			total += 1
			local before = played
			H.signalOf(x, "MouseButton1Down"):Fire()
			H.task.wait(0.07)
			if played > before then pressed += 1 end
			if total >= 40 then break end
		end
	end
	cc.play = realPlay
	cc.closeModals()
	H.check(total >= 20 and pressed == total, pressed .. " / " .. total .. " buttons give a sound the moment they're pressed (plus the squeeze)")

	H.section("Text contrast")
	-- relative luminance + WCAG contrast ratio
	local function lum(c)
		local function ch(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
		return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
	end
	local function ratio(a1, b1)
		local l1, l2 = lum(a1), lum(b1)
		if l1 < l2 then l1, l2 = l2, l1 end
		return (l1 + 0.05) / (l2 + 0.05)
	end
	-- the background behind a text: the nearest ancestor (or itself) that is mostly opaque; gradients are averaged
	local function bgOf(x)
		local o = x
		while o and o.ClassName ~= "ScreenGui" do
			if (o.ClassName == "Frame" or o.ClassName == "TextButton" or o.ClassName == "TextLabel" or o.ClassName == "ScrollingFrame" or o.ClassName == "ImageButton")
				and (o.BackgroundTransparency or 0) < 0.5 then
				local col = o.BackgroundColor3
				local g = o:FindFirstChildOfClass("UIGradient")
				if g and g.Color then
					local kps = g.Color.Keypoints
					local r, gg, b = 0, 0, 0
					for _, k in ipairs(kps) do r += k.Value.R gg += k.Value.G b += k.Value.B end
					local avg = Color3.new(r / #kps, gg / #kps, b / #kps)
					col = Color3.new(col.R * avg.R, col.G * avg.G, col.B * avg.B)
				end
				return col
			end
			o = o.Parent
		end
		return nil
	end
	local function shown(x)
		local o = x
		while o and o.ClassName ~= "ScreenGui" do
			if o.Visible == false then return false end
			o = o.Parent
		end
		return true
	end
	local bad, checked = {}, 0
	local function scan(root, where)
		for _, x in ipairs(root:GetDescendants()) do
			-- (emoji-only texts draw in their own colors: only text with letters or digits is measured)
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find("[%w]") and shown(x) and (x.TextTransparency or 0) < 0.5 then
				local bg = bgOf(x)
				-- a dark outline around the letters counts as their own background
				local stroked = (x.TextStrokeTransparency or 1) < 0.6 or x:FindFirstChildOfClass("UIStroke") ~= nil
				if bg and not stroked then
					checked += 1
					local r = ratio(x.TextColor3, bg)
					if r < 3 then table.insert(bad, string.format("%s: \"%s\" %.1f:1", where, tostring(x.Text):sub(1, 30), r)) end
				end
			end
		end
	end
	scan(gui, "HUD")
	local windows = 0
	for key, mm in pairs(cc.modals) do
		if key ~= "admin" then
			cc.closeModals()
			cc.openModal(key, true)
			H.task.wait(0.6)
			if mm.frame.Visible then
				windows += 1
				scan(mm.frame, key)
			end
		end
	end
	cc.closeModals()
	H.check(checked > 200 and #bad == 0, string.format("%d texts on the HUD and %d windows are readable (contrast ≥ 3:1 against what's behind them)", checked, windows)
		.. (#bad > 0 and (": " .. #bad .. " too faint:\n      " .. table.concat(bad, "\n      ")) or ""))

	T.assertClean("ui clarity")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
