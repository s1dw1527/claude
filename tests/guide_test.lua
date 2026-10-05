-- v10: the tutorial keeps up — 18 contextual tips, "What's this?" help for every new window, tips on/off, tasks.
-- Run with: python3 tests/run.py tests/guide_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
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
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function tips(mark)
		local out = {}
		for i = mark + 1, #H.remoteLog do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.player == a and e.args[1] == "guideTip" then table.insert(out, e.args[2].key) end
		end
		return out
	end

	H.section("Tips")
	H.check(#C.GUIDE_TIPS == 27, "27 contextual tips (18 from v10 + 9 for the mountain and heists)")
	local mk = #H.remoteLog
	H.check(d.tut and d.tut > 0, "a new player starts in the opening tutorial")
	F.guideTip(a, "claimProperty")
	H.task.wait(5)
	H.check(#tips(mk) == 0, "no contextual tips during the opening tutorial")
	d.guide.seen.claimProperty = nil
	d.tut = 0
	H.task.wait(6)
	local got = tips(mk)
	H.check(got[1] == "welcomeV10" and cc.GuideUI.tip.Visible, "after the tutorial: the v10 welcome tip, on screen")
	F.guideTip(a, "claimProperty")
	H.task.wait(1)
	H.check(#tips(mk) == 1, "the next tip waits (one every 20 seconds)")
	H.task.wait(24)
	got = tips(mk)
	H.check(got[2] == "claimProperty", "...then shows")
	F.guideTip(a, "claimProperty")
	H.task.wait(25)
	H.check(#tips(mk) == 2, "each tip shows only once")
	-- context: walking to the Fun Zone
	a.Character:PivotTo(CFrame.new(C.FUN_ZONE_AT.Position + Vector3.new(0, 4, 20)))
	H.task.wait(10)
	got = tips(mk)
	H.check(got[#got] == "funZone", "walking into the Fun Zone shows its tip")
	-- turning tips off
	local offB
	for _, x in ipairs(cc.GuideUI.tip:GetChildren()) do if x.ClassName == "TextButton" and x.Text == "Turn off tips" then offB = x end end
	click(offB)
	H.check(d.guide.off == true, "Turn off tips")
	local n = #tips(mk)
	d.arcade.tickets = 100
	F.guideTip(a, "garage")
	H.task.wait(25)
	H.check(#tips(mk) == n, "no tips while they're off")
	T.act(a, "guideReset")
	H.check(not d.guide.off and next(d.guide.seen) == nil, "Settings → Show all again")

	H.section("What's this?")
	local topics = {"property", "chooseBusiness", "products", "hq", "manager", "computer", "furniture", "builder", "garage", "carCustom", "arcade", "heists", "police", "mountain"}
	local missing = {}
	for _, t in ipairs(topics) do if not (C.GUIDE_HELP[t] and #C.GUIDE_HELP[t].text > 40) then table.insert(missing, t) end end
	H.check(#missing == 0, #topics .. " help topics written" .. (#missing > 0 and (" (missing: " .. table.concat(missing, ", ") .. ")") or ""))
	local helpBtns = 0
	for key, m in pairs(cc.modals) do
		for _, x in ipairs(m.frame:GetChildren()) do if x.ClassName == "TextButton" and x.Text == "❓ What's this?" then helpBtns += 1 end end
	end
	H.check(helpBtns >= 10, helpBtns .. " windows have a ❓ What's this? button")
	T.act(a, "hqInfo")
	H.task.wait(0.5)
	local hb
	for _, x in ipairs(cc.modals.hq.frame:GetChildren()) do if x.ClassName == "TextButton" and x.Text == "❓ What's this?" then hb = x end end
	click(hb)
	local shown = false
	for _, x in ipairs(cc.modals.help.frame:GetDescendants()) do if x.ClassName == "TextLabel" and tostring(x.Text):find("Six floors") then shown = true end end
	H.check(cc.modals.help.frame.Visible and shown, "the HQ window's ❓ explains the HQ")

	H.section("Tasks")
	local tasks = F.guideTasks(d)
	H.check(#tasks >= 10 and tasks[1].text ~= nil, #tasks .. " tasks in the computer's Tasks app")
	H.check(C.TUTORIAL[1].text:find("name"), "the opening tutorial mentions naming your stand")

	T.assertClean("guide")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
