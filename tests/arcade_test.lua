-- v10: Fun Zone + 2-player arcade games (server-authoritative), rewards with anti-farm caps, forfeits, prizes,
-- arcade machines at home and in an Arcade business. Run with: python3 tests/run.py tests/arcade_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut, db.tut = 0, 0
	C.G.nextEvent = H.now() + 3600
	local zone = H.workspace:FindFirstChild("City"):FindFirstChild("FunZone")
	local function prompt(root, action)
		for _, x in ipairs(root:GetDescendants()) do
			if x.ClassName == "ProximityPrompt" and x.ActionText == action then return x end
		end
	end
	local function trigger(pp, who) H.signalOf(pp, "Triggered"):Fire(who) H.task.wait(0.3) end
	local function at(plr, cf) plr.Character:PivotTo(cf) end
	local function last(plr, state)
		for i = #H.remoteLog, 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.player == plr and e.args[1] == "arcade" and (state == nil or e.args[2].state == state) then return e.args[2], i end
		end
	end
	local function waitFor(plr, state, mark, timeout)
		local t = H.now()
		while H.now() - t < (timeout or 20) do
			local e, i = last(plr, state)
			if e and i > mark then return e end
			H.task.wait(0.1)
		end
	end
	local function stand(key, plr)
		local pp = prompt(zone, "Play " .. C.ARCADE_GAMES[key].name)
		at(plr, CFrame.new(pp.Parent.Position + Vector3.new(0, 3, 5)))
		return pp
	end

	H.section("The Fun Zone")
	H.check(zone ~= nil, "the Fun Zone pavilion is built in the Entertainment District")
	for _, key in ipairs(C.ARCADE_ORDER) do H.check(prompt(zone, "Play " .. C.ARCADE_GAMES[key].name) ~= nil, C.ARCADE_GAMES[key].icon .. " " .. C.ARCADE_GAMES[key].name .. " booth") end
	H.check(prompt(zone, "Prize Counter") ~= nil, "a prize counter")

	H.section("⚡ Reaction Duel")
	local booth = stand("reaction", a)
	at(bob, a.Character:GetPivot())
	local mk = #H.remoteLog
	trigger(booth, a)
	H.check(last(a, "waiting") ~= nil and cc.ArcadeUI.win.Visible, "Alice waits for a second player")
	trigger(booth, bob)
	H.check(waitFor(a, "matched", mk) ~= nil and waitFor(bob, "matched", mk) ~= nil, "Bob joins: matched")
	-- round 1: Alice jumps the gun
	waitFor(a, "round", mk)
	T.act(a, "arcPress")
	local re = waitFor(a, "roundEnd", mk)
	H.check(re and re.winner == "Bob" and tostring(re.why):find("jumped the gun"), "tapping before GO is a false start (the other player takes the round)")
	-- the next rounds: Bob taps first after GO
	for _ = 1, 3 do
		local m1 = #H.remoteLog
		if waitFor(a, "go", m1, 10) then
			T.act(bob, "arcPress")
			T.act(a, "arcPress")
		end
		if last(a, "end") then break end
	end
	local en = waitFor(a, "end", mk, 15)
	H.check(en and en.won == false, "Bob wins the duel (best of 3)")
	local eb = last(bob, "end")
	H.check(eb and eb.won and eb.tickets == C.ARCADE_RULES.winTickets, "the winner gets " .. C.ARCADE_RULES.winTickets .. " tickets")
	H.check(en and en.tickets == C.ARCADE_RULES.playTickets, "the loser gets " .. C.ARCADE_RULES.playTickets .. " for playing")
	H.check(db.arcade.wins == 1 and d.arcade.played == 1, "wins and games are counted")
	H.task.wait(0.5)

	H.section("👆 Button Battle")
	booth = stand("buttons", a)
	at(bob, a.Character:GetPivot())
	mk = #H.remoteLog
	trigger(booth, a)
	trigger(booth, bob)
	waitFor(a, "start", mk)
	for _ = 1, 44 do
		T.act(a, "arcTap", 8)   -- 32 taps a second: impossible for a person
		T.act(bob, "arcTap", 2)
		H.task.wait(0.25)
	end
	en = waitFor(a, "end", mk, 5)
	H.check(en and en.won, "Alice out-taps Bob")
	H.check(en and en.score <= C.ARCADE_GAMES.buttons.maxRate * 10.6 + 3, "taps above ~14 a second are ignored (" .. tostring(en and en.score) .. " counted)")
	T.act(a, "arcTap", 100)
	T.act(a, "arcTap", -5)
	H.task.wait(0.5)

	H.section("🏀 Hoop Duel")
	booth = stand("hoops", a)
	at(bob, a.Character:GetPivot())
	mk = #H.remoteLog
	trigger(booth, a)
	trigger(booth, bob)
	waitFor(a, "start", mk)
	local shots = 0
	for _ = 1, 12 do
		T.act(a, "arcShoot")
		T.act(a, "arcShoot")   -- (a second shot straight away is ignored)
		T.act(bob, "arcShoot")
		H.task.wait(0.7)
	end
	for i = mk + 1, #H.remoteLog do
		local e = H.remoteLog[i]
		if e.name == "Menu" and e.player == a and e.args[1] == "arcade" and e.args[2].state == "shot" then shots += 1 end
	end
	H.check(shots == C.ARCADE_GAMES.hoops.shots, "5 shots each, one at a time (" .. shots .. ")")
	en = waitFor(a, "end", mk, 5)
	H.check(en ~= nil, "the duel ends after the last shot (" .. tostring(en and en.score) .. " — " .. tostring(en and en.opp) .. ")")

	H.section("🏎️ Kart Sprint")
	booth = stand("sprint", a)
	at(bob, a.Character:GetPivot())
	mk = #H.remoteLog
	trigger(booth, a)
	trigger(booth, bob)
	waitFor(a, "start", mk)
	local st = H.now()
	for _ = 1, 40 do
		T.act(a, "arcStep", 6)
		T.act(bob, "arcStep", 1)
		H.task.wait(0.25)
		if last(a, "end") and select(2, last(a, "end")) > mk then break end
	end
	en = waitFor(a, "end", mk, 5)
	local took = H.now() - st
	H.check(en and en.won, "Alice's kart wins")
	H.check(took >= C.ARCADE_GAMES.sprint.goal / C.ARCADE_GAMES.sprint.maxRate - 0.5, "even spamming, the finish takes " .. string.format("%.1f", took) .. "s (max ~12 steps a second)")

	H.section("No farming")
	-- games 5 and 6 against the same opponent within 10 minutes: the 6th pays nothing
	local paid = {}
	for g = 1, 2 do
		booth = stand("buttons", a)
		at(bob, a.Character:GetPivot())
		mk = #H.remoteLog
		trigger(booth, a)
		trigger(booth, bob)
		waitFor(a, "start", mk)
		for _ = 1, 44 do T.act(a, "arcTap", 3) H.task.wait(0.25) end
		en = waitFor(a, "end", mk, 5)
		paid[g] = en and en.tickets or -1
	end
	H.check(paid[1] > 0 and paid[2] == 0, "after " .. C.ARCADE_RULES.pairCap .. " games with the same opponent in 10 minutes, no more tickets (" .. paid[1] .. ", " .. paid[2] .. ")")
	H.check(en and en.capped == true, "...and the player is told why")

	H.section("Forfeits")
	local carl = T.join("Carl", 103)
	local dc = T.newGame(carl, 1, 1)
	dc.tut = 0
	booth = stand("reaction", a)
	at(carl, a.Character:GetPivot())
	mk = #H.remoteLog
	trigger(booth, carl)
	trigger(booth, a)
	waitFor(a, "matched", mk)
	H.task.wait(7)
	carl.Character:PivotTo(CFrame.new(0, 5, 0))
	en = waitFor(a, "end", mk, 5)
	H.check(en and en.won and en.why == "forfeit", "walking away from the booth forfeits: Alice wins")
	H.check(dc.arcade.wins == 0, "the quitter gets nothing")
	booth = stand("reaction", a)
	at(carl, a.Character:GetPivot())
	mk = #H.remoteLog
	trigger(booth, a)
	trigger(booth, carl)
	waitFor(a, "matched", mk)
	H.removePlayer(carl)
	en = waitFor(a, "end", mk, 5)
	H.check(en and en.won and en.tickets == 0, "a disconnect forfeits too; an instant forfeit pays no tickets")

	H.section("Prizes and leaderboard")
	d.arcade.tickets = 100
	T.act(a, "arcPrize", "beanbag")
	H.check(d.arcade.tickets == 60 and d.furniture.beanbag == 1, "40 tickets → a Bean Bag in your furniture storage")
	T.act(a, "arcPrize", "arcademachine")
	H.check(d.arcade.tickets == 60 and not d.furniture.arcademachine, "not enough tickets for the Arcade Machine")
	T.act(a, "arcPrize", "money")
	H.check(d.arcade.tickets == 60, "tickets never turn into cash")
	local top = F.arcadeBoard()
	H.check(#top >= 2 and top[1].wins >= top[2].wins, "leaderboard: " .. (top[1] and (top[1].name .. " " .. top[1].wins) or "?"))
	trigger(prompt(zone, "Prize Counter"), a)
	H.task.wait(0.5)
	H.check(cc.modals.arcadeInfo.frame.Visible, "the prize counter opens")
	cc.closeModals()

	H.section("Arcade machines")
	d.home.level = 2
	d.cash = 1e8
	d.furniture.arcademachine = 1
	F.enterInterior(a, a, "home")
	T.act(a, "hbPlace", "arcademachine", {2, 8, 0})
	local room = H.workspace:FindFirstChild("Interiors"):FindFirstChild("Interior_Alice_home")
	local mach = prompt(room, "Play")
	H.check(mach ~= nil, "the arcade machine in Alice's home can be played")
	mk = #H.remoteLog
	trigger(mach, a)
	H.task.wait(0.5)
	H.check(cc.modals.arcadePick.frame.Visible, "the first player picks the game")
	local station
	for i = #H.remoteLog, mk + 1, -1 do
		local e = H.remoteLog[i]
		if e.name == "Menu" and e.player == a and e.args[1] == "arcadePick" then station = e.args[2].station end
	end
	T.act(a, "arcPick", station, "sprint")
	H.check(last(a, "waiting") ~= nil, "waiting at the machine")
	F.enterInterior(bob, a, "home")
	trigger(mach, bob)
	H.check(waitFor(bob, "matched", mk) ~= nil, "a friend in the house joins the same machine")
	H.task.wait(2)
	F.leaveInterior(bob)
	en = waitFor(a, "end", mk, 5)
	H.check(en and en.why == "forfeit", "leaving the house forfeits the machine game")
	mk = #H.remoteLog
	T.act(a, "arcPick", "booth:reaction", "buttons")
	H.check(last(a, "waiting") == nil or select(2, last(a, "waiting")) <= mk, "the machine-only pick action can't be used on a booth")
	F.leaveInterior(a)
	d.levels.arcade = 3
	F.enterInterior(a, a, "arcade")
	room = H.workspace:FindFirstChild("Interiors"):FindFirstChild("Interior_Alice_arcade")
	H.check(room and prompt(room, "Play 2P") ~= nil, "an Arcade business has a 2P duel cabinet")
	F.leaveInterior(a)

	T.assertClean("arcade + fun zone")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
