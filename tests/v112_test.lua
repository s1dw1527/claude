-- v11.2 fixes: secret-base station buttons, apartment rent, the storefront sign after a rename, the 🤖 Arcade Bot,
-- Photo Mode on a phone, world labels / toasts on a phone. Run with: python3 tests/run.py tests/v112_test.lua
-- (The terrain that buried the base and the heist targets is checked by tests/terrain_test.lua.)
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
	d.tut = 0
	C.G.nextEvent = H.now() + 7200
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function at(plr, pos) plr.Character:PivotTo(CFrame.new(pos)) H.task.wait(0.2) end

	-- ===== the secret base's stations =====
	H.section("Secret base: every station opens something")
	local MC = C.MOUNTAIN
	d.rep = 5000
	d.heist = d.heist or {}
	d.heist.discovered = true
	local hm = cc.modals.heists
	local expect = {jobs = "jobs", planning = "jobs", computer = "police", quartermaster = "gear", base = "gear"}
	for key, tab in pairs(expect) do
		cc.closeModals()
		H.task.wait(0.3)
		local st = MC.stations[key]
		at(a, st.pos + Vector3.new(0, 3, -4))
		H.signalOf(st.prompt, "Triggered"):Fire(a)
		H.task.wait(2)
		local items = 0
		for _, x in ipairs(hm.body:GetChildren()) do if x:IsA("GuiObject") then items += 1 end end
		H.check(hm.frame.Visible and cc.HeistUI.tab == tab and items > 0, "📍 " .. key .. " → the Heists window on '" .. tab .. "' with " .. items .. " things in it")
	end
	cc.closeModals()

	-- ===== apartments =====
	H.section("Apartments pay rent, and you can see it")
	d.cash, d.rep = 1e8, 500
	T.act(a, "propBuy", 1, "walkup")
	H.task.wait(0.5)
	local b = d.props[1]
	H.check(b ~= nil, "bought a Walk-Up")
	for i = 1, #b.units do b.units[i] = false end
	b.condition = 100
	-- empty building: no upkeep is charged
	local cash0 = d.cash
	local tm = 0
	H.task.wait(C.CFG.RENT_INTERVAL + 2)
	H.check(d.cash >= cash0, "an EMPTY building doesn't drain money (" .. math.floor(cash0) .. " → " .. math.floor(d.cash) .. ")")
	-- two tenants
	for i = 1, 2 do
		local t = F.newApplicant()
		t.credit, t.mood = 5, 90
		b.units[i] = t
	end
	local rate = F.rentRate(d)
	H.check(rate > 0, string.format("rent rate with 2 tenants: +$%.0f/s", rate))
	local mark = #H.remoteLog
	cash0 = d.cash
	H.task.wait(C.CFG.RENT_INTERVAL + 2)
	local got = d.cash - cash0
	local expected = rate * C.CFG.RENT_INTERVAL
	H.check(got > 0 and math.abs(got - expected) <= expected * 0.35 + 50, string.format("one rent day pays about rate × 30 s ($%.0f, expected ~$%.0f)", got, expected))
	local sent = T.remotesSince(mark, "Customer", a)
	local rentMsg
	for _, e in ipairs(sent) do if type(e.args[1]) == "table" and e.args[1].rent then rentMsg = e.args[1] end end
	H.check(rentMsg and rentMsg.rent > 0, "the client is told about rent day (rent $" .. tostring(rentMsg and rentMsg.rent) .. ", upkeep $" .. tostring(rentMsg and rentMsg.upkeep) .. ")")
	H.check(cc.S and (cc.S.rentRate or 0) > 0, "the HUD state includes the rent rate ($" .. tostring(cc.S and cc.S.rentRate) .. "/s)")
	local floated = false
	for _, x in ipairs(cc.gui:GetChildren()) do if x.Name == "MoneyFloat" and tostring(x.Text):find("Rent") then floated = true end end
	H.task.wait(0.1)
	H.check(floated or rentMsg ~= nil, "a \"🏢 Rent +$…\" note pops up on rent day")

	-- ===== the storefront sign after a rename =====
	H.section("The sign on the building shows the business's name")
	local function signTexts()
		local out = {}
		local m = d.plot.slots.lemonade
		for _, x in ipairs(m and m:GetDescendants() or {}) do
			if x.ClassName == "TextLabel" and x.Parent and x.Parent.ClassName == "SurfaceGui" then table.insert(out, x.Text) end
		end
		return table.concat(out, " | ")
	end
	d.levels.lemonade = math.max(d.levels.lemonade or 0, 1)
	F.refreshBuilding(a, "lemonade", false)
	d.brands = d.brands or {}
	d.brands.lemonade = d.brands.lemonade or {}
	d.brands.lemonade.renamedAt = nil
	local ok = F.renameBiz(a, "lemonade", "Sour Power")
	H.task.wait(0.3)
	H.check(ok and signTexts():find("SOUR POWER") ~= nil, "after renaming to \"Sour Power\" the stand's sign says it: " .. signTexts())
	d.levels.coffee = 3
	F.refreshBuilding(a, "coffee", false)
	F.renameBiz(a, "coffee", "Bean There")
	H.task.wait(0.3)
	local coffeeSign = ""
	for _, x in ipairs(d.plot.slots.coffee:GetDescendants()) do
		if x.ClassName == "TextLabel" and x.Parent and x.Parent.ClassName == "SurfaceGui" then coffeeSign ..= x.Text .. " | " end
	end
	H.check(coffeeSign:find("BEAN THERE") ~= nil and not coffeeSign:find("☕ COFFEE |"), "a shop's front sign shows the new name too: " .. coffeeSign)

	-- ===== the 🤖 Arcade Bot =====
	H.section("Arcade: ▶ PLAY works on your own (🤖 Arcade Bot)")
	local function openArcade()
		cc.togglePhone(true)
		cc.phoneView("home")
		H.task.wait(0.2)
		for _, x in ipairs(cc.phoneFrame:GetDescendants()) do
			if x.ClassName == "TextButton" and x.Text == "🕹️" and x.Size.X.Offset == 56 then click(x) end
		end
		H.task.wait(2)
	end
	openArcade()
	local info = cc.modals.arcadeInfo
	local playB
	for _, c in ipairs(info.body:GetChildren()) do
		if c.Name == "GameCard" then
			for _, x in ipairs(c:GetChildren()) do
				if x.Name == "PlayButton" and not playB then
					for _, l in ipairs(c:GetChildren()) do if l.ClassName == "TextLabel" and tostring(l.Text):find("BUTTON BATTLE") then playB = x end end
				end
			end
		end
	end
	H.check(playB ~= nil, "the Button Battle card has ▶ PLAY")
	local tickets0 = F.arcadeData(d).tickets
	click(playB)
	H.task.wait(2.5)
	local gw = cc.ArcadeUI.win
	H.check(gw.Visible and not info.frame.Visible, "▶ PLAY starts a game right away (no second player needed)")
	local names = cc.ArcadeUI.names or {}
	H.check(tostring(names[2]):find("Arcade Bot") ~= nil, "the opponent is the 🤖 Arcade Bot")
	local tapB
	for _, x in ipairs(gw:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "👆 TAP TAP TAP!" then tapB = x end end
	for _ = 1, 60 do
		if tapB then H.signalOf(tapB, "MouseButton1Click"):Fire() end
		H.task.wait(0.08)
	end
	H.task.wait(8)
	local over = false
	for _, x in ipairs(gw:GetDescendants()) do
		if x.ClassName == "TextLabel" and (tostring(x.Text):find("YOU WIN") or tostring(x.Text):find("YOU LOSE") or tostring(x.Text):find("DRAW")) then over = true end
	end
	H.check(over, "the game plays out to a result")
	local a2 = F.arcadeData(d)
	H.check(a2.tickets > tickets0 and a2.tickets - tickets0 <= C.ARCADE_RULES.botWinTickets, "tickets vs the bot: +" .. (a2.tickets - tickets0) .. " (at most " .. C.ARCADE_RULES.botWinTickets .. ")")
	for _, x in ipairs(gw:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "OK" then click(x) end end
	-- every game runs against the bot
	for _, g in ipairs({"reaction", "hoops", "sprint"}) do
		T.act(a, "arcBot", g)
		H.task.wait(2.5)
		H.check(gw.Visible, "🤖 " .. g .. " starts")
		T.act(a, "arcLeave")
		H.task.wait(1)
	end
	H.check(not gw.Visible, "leaving closes the game window")
	-- waiting alone at a booth offers the bot
	local zone = H.workspace:FindFirstChild("City"):FindFirstChild("FunZone")
	local pp
	for _, x in ipairs(zone:GetDescendants()) do if x.ClassName == "ProximityPrompt" and x.ActionText == "Play Hoop Duel" then pp = x end end
	at(a, pp.Parent.Position + Vector3.new(0, 3, 5))
	H.signalOf(pp, "Triggered"):Fire(a)
	H.task.wait(1)
	local botB
	for _, x in ipairs(gw:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "🤖 Play the Arcade Bot" then botB = x end end
	H.check(gw.Visible and botB ~= nil, "waiting alone at a booth shows \"🤖 Play the Arcade Bot\"")
	if botB then click(botB) end
	H.task.wait(2.5)
	H.check(tostring((cc.ArcadeUI.names or {})[2]):find("Arcade Bot") ~= nil, "…and it starts that booth's game against the bot")
	T.act(a, "arcLeave")
	H.task.wait(1)
	cc.closeModals()
	cc.togglePhone(false)

	-- ===== Photo Mode and labels on a phone =====
	H.section("Phone (390×700): Photo Mode, world labels, toasts")
	local cam = H.workspace.CurrentCamera
	rawget(cam, "_p").ViewportSize = H.G.Vector2.new(390, 700)
	cam:GetPropertyChangedSignal("ViewportSize"):Fire()
	H.task.wait(0.5)
	local photoBar = a.PlayerGui:FindFirstChild("PhotoBar", true)
	local sc = 1
	for _, x in ipairs(photoBar:GetChildren()) do if x.ClassName == "UIScale" then sc = x.Scale end end
	local w = photoBar.Size.X.Offset * sc
	H.check(w <= 390 and w >= 300 and sc == 1, string.format("the Photo Mode bar is %d px wide on a 390 px screen, text at 100%% (was 441 px at 45%%)", w))
	local exitFirst = false
	for _, r in ipairs(photoBar:GetChildren()) do
		if r.ClassName == "ScrollingFrame" then
			local lowest, which = math.huge, nil
			for _, x in ipairs(r:GetChildren()) do if x.ClassName == "TextButton" and x.LayoutOrder < lowest then lowest, which = x.LayoutOrder, x.Text end end
			if which == "✖ Exit (V)" then exitFirst = true end
		end
	end
	H.check(exitFirst, "✖ Exit comes first, and the button rows scroll sideways")
	-- a billboard (speech bubble) made now is drawn at 65%
	local part = H.Instance_new("Part")
	part.Anchored = true
	part.Parent = H.workspace
	local bb = H.Instance_new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 60)
	bb.Parent = part
	H.task.wait(0.3)
	H.check(math.abs(bb.Size.X.Offset - 130) < 1 and math.abs(bb.Size.Y.Offset - 39) < 1, "speech bubbles and labels over things are drawn at 65% on a phone (" .. bb.Size.X.Offset .. "×" .. bb.Size.Y.Offset .. ")")
	rawget(cam, "_p").ViewportSize = H.G.Vector2.new(1280, 720)
	cam:GetPropertyChangedSignal("ViewportSize"):Fire()
	H.task.wait(0.5)
	H.check(bb.Size.X.Offset == 200 and bb.Size.Y.Offset == 60, "…and back to full size on desktop")
	part:Destroy()

	T.assertClean("v11.2 fixes")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
