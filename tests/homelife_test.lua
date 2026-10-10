-- v14 Phase C: HOME LIFE. Lofts vs houses vs mansions, the Skyline Lofts, home parties (invites, the party card,
-- joining, guests, favors, capacity, permissions, the dance floor and party music, ending, cooldown, saving).
-- Run with: python3 tests/run.py tests/homelife_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	local cy = H.addPlayer("Cy", 103)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local dc = T.newGame(cy, 1, 1)
	local cc = H.clientC
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	for _, x in ipairs({d, db, dc}) do x.tut = 0 x.rep = 2000 x.cash = 1e8 end
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local HL = C.HOMELIFE
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local function click(name)
		local b = find(a.PlayerGui, function(x) return x.Name == name end)
		if b then H.signalOf(b, "MouseButton1Click"):Fire() end
		return b
	end
	local function inside(p, owner, key) return p:GetAttribute("Interior") == key and p:GetAttribute("InteriorOwner") == owner.UserId end

	H.section("Three ways to live")
	H.check(#C.HOME_KINDS == 3 and C.HOME_KINDS[1].key == "loft", "City Loft, House and Mansion, each with pros and cons")
	local had = d.home and d.home.level or 0
	d.home = d.home or {level = 0}
	d.home.level = 0
	H.check(F.homeKind(d) == nil, "no house built: no house")
	d.home.level = 3
	local rich = F.homeHood(d) == "rich"
	H.check(F.homeKind(d) == (rich and "mansion" or "house"), "a level-3 home is a " .. tostring(F.homeKind(d)))
	d.home.level = 5
	H.check(F.homeKind(d) == "mansion", "level 5+ is a mansion")
	d.home.level = had
	local lobby = find(H.workspace, function(x) return x.Name == "SkylineLofts" end)
	local door = lobby and find(lobby, function(x) return x.ClassName == "ProximityPrompt" end)
	H.check(lobby and door and (lobby:FindFirstChild("LobbyDoor").Position - Vector3.new(230, 3, 31.6)).Magnitude < 2, "the Skyline Lofts entrance downtown")

	H.section("A City Loft")
	cc.openModal("party", true)
	H.task.wait(0.8)
	local c0 = d.cash
	H.check(click("LoftBuy") ~= nil, "the 🎉 Home & Party app offers a loft")
	H.task.wait(0.5)
	H.check(d.loft.level == 1 and math.abs((c0 - d.cash) - HL.loft[1].cost) < F.incomePerSec(d) * 3 + 1, "leased: " .. HL.loft[1].name .. " for $" .. C.fmt(HL.loft[1].cost))
	H.task.wait(0.4)
	click("LoftEnter")
	H.task.wait(1.5)
	H.check(inside(a, a, "loft"), "Alice goes up to her loft")
	F.leaveInterior(a)
	H.signalOf(door, "Triggered"):Fire(a)
	H.task.wait(1.2)
	H.check(inside(a, a, "loft"), "...or through the lobby door")
	F.leaveInterior(a)
	H.signalOf(door, "Triggered"):Fire(cy)
	H.task.wait(0.5)
	H.check(not cy:GetAttribute("Interior"), "Cy has no loft: the lobby sends him to the app instead")
	F.loftBuy(a)
	H.check(d.loft.level == 2, "moving up: " .. HL.loft[2].name)
	dc.rep = 0
	dc.cash = 1e9
	F.loftBuy(cy)
	F.loftBuy(cy)
	H.check(dc.loft.level == 1, "the bigger lofts need more reputation")
	cc.closeModals()

	H.section("Bob throws a party")
	F.loftBuy(bob)
	local mark = #H.remoteLog
	H.check(F.partyStart(bob, "loft") and inside(bob, bob, "loft"), "Bob starts a party at his Studio Loft (and goes there)")
	H.task.wait(0.6)
	H.check(cc.HomeLifeUI.card.Visible and find(cc.HomeLifeUI.card, function(x) return x.ClassName == "TextLabel" and x.Text:find("Bob is throwing a party", 1, true) end) ~= nil,
		"Alice sees a 🎉 party card in her notification stack")
	local buzz = false
	for i = mark + 1, #H.remoteLog do
		local e = H.remoteLog[i]
		if e.name == "Buzz" and type(e.args[1]) == "table" and tostring(e.args[1].text):find("throwing a party") then buzz = true end
	end
	H.check(buzz, "...and a CityBuzz post")
	local room = F.interiorModel(bob, "loft")
	local props = room and room:FindFirstChild("PartyProps")
	local floor = props and props:FindFirstChild("DanceFloor")
	H.check(floor and H.service("CollectionService"):HasTag(floor, "ChaseLights") and #floor:GetChildren() >= 25, "the loft gets a light-up dance floor, a DJ booth and balloons")
	local rep0, cash0 = db.rep, d.cash
	local fav = math.floor(math.max(HL.favorMin, F.incomePerSec(d) * HL.favorSecs) * HL.loftFavor)
	click("PartyCardJoin")
	H.task.wait(1.5)
	H.check(inside(a, bob, "loft"), "Alice taps Join: she's at the party")
	H.check(db.rep - rep0 == HL.guestRep, "Bob gets +" .. HL.guestRep .. " reputation for a guest")
	H.check(d.cash - cash0 >= fav - 1 and d.cash - cash0 < fav + F.incomePerSec(d) * 4 + 2, "Alice gets a party favor: +$" .. C.fmt(fav) .. " (30 s of her own income, +50% at a loft)")
	H.check(cc.AudioDirector.moodNow() == "party", "the music turns into party music")
	F.leaveInterior(a)
	H.task.wait(0.3)
	cash0 = d.cash
	F.partyJoin(a, 102)
	H.task.wait(1)
	H.check(inside(a, bob, "loft") and db.rep - rep0 == HL.guestRep and d.cash - cash0 < F.incomePerSec(d) * 4 + 2, "coming back: no second favor, no second rep")
	-- capacity
	C.PARTIES[bob].cap = 1
	H.check(not F.partyJoin(cy, 102) and not cy:GetAttribute("Interior"), "a full party turns people away")
	C.PARTIES[bob].cap = 6
	-- permissions still apply
	F.setPerm(bob, "house", "private")
	H.task.wait(0.3)
	H.check(not F.partyJoin(cy, 102), "a private home stays private, party or not")
	F.setPerm(bob, "house", "public")
	H.check(not inside(a, bob, "loft"), "(going private shows the guests out)")
	H.check(F.partyJoin(cy, 102) and inside(cy, bob, "loft"), "back to public: Cy joins")
	F.partyJoin(a, 102)
	H.check(not F.partyStart(bob, "loft"), "one party at a time")
	local cyHome = dc.home
	dc.home = {level = 0}
	H.check(not F.partyStart(cy, "home") and not F.partyStart(cy, "castle") and C.PARTIES[cy] == nil, "no house: no house party; no made-up venues")
	dc.home = cyHome

	H.section("The party ends")
	local info = F.homeLifeInfo(a)
	H.check(#info.parties == 1 and info.parties[1].here == 2, "the app lists Bob's party (2 guests inside)" .. string.format(" [%d parties, here %s; Alice %s/%s, Cy %s/%s]", #info.parties, tostring(info.parties[1] and info.parties[1].here), tostring(a:GetAttribute("Interior")), tostring(a:GetAttribute("InteriorOwner")), tostring(cy:GetAttribute("Interior")), tostring(cy:GetAttribute("InteriorOwner"))))
	mark = #H.remoteLog
	H.task.wait(HL.partyTime + 3)
	H.check(C.PARTIES[bob] == nil and db.party.hosted == 1 and db.party.guests == 2 and db.party.best == 2, "after 4 minutes it's over: 1 party, 2 guests on Bob's record")
	room = F.interiorModel(bob, "loft")
	H.check(room and room:FindFirstChild("PartyProps") == nil, "the decorations come down")
	H.check(cc.AudioDirector.moodNow() ~= "party" and not cc.HomeLifeUI.card.Visible, "the music and the card go back to normal")
	H.check(not F.partyStart(bob, "loft"), "then a " .. math.floor(HL.cooldown / 60) .. "-minute rest")
	db.party.lastAt -= HL.cooldown
	H.check(F.partyStart(bob, "loft"), "after the rest he can throw another")
	H.removePlayer(bob)
	H.task.wait(2.5)
	H.check(C.PARTIES[bob] == nil, "the host leaving ends the party")

	H.section("Saved")
	F.save(a)
	local rec = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(rec and rec.loft and rec.loft.level == 2 and type(rec.party) == "table", "the loft and party record are saved")

	T.assertClean("homelife")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
