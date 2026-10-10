-- v14: the MOVIE THEATER. It opens on a city plot (not the home plot), shows films the owner picks, a show's
-- turnout sets its sales, premieres, upgrades, the marquee and the big screen inside, and the 🍿 Theater app.
-- Run with: python3 tests/run.py tests/theater_test.lua
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
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut, db.tut = 0, 0
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local Lighting = H.service("Lighting")
	Lighting.ClockTime = 13
	local LOTS = C.LOTS
	local function lotIn(dkey) for _, l in ipairs(LOTS) do if l.dkey == dkey and not l.owner then return l end end end
	local function buzzSince(mark, pat)
		for i = mark + 1, #H.remoteLog do
			local e = H.remoteLog[i]
			for _, v in ipairs(e.args or {}) do
				if type(v) == "string" and v:find(pat, 1, true) then return v end
				if type(v) == "table" and type(v.text) == "string" and v.text:find(pat, 1, true) then return v.text end
			end
		end
	end
	local function lastMenu(kind, since, who)
		for i = #H.remoteLog, (since or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.dir == "s2c" and e.args[1] == kind and e.player == (who or a) then return e.args[2] end
		end
	end
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local function guiText(pat)
		return find(a.PlayerGui, function(x) return (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and x.Text:find(pat, 1, true) ~= nil and x.Visible end)
	end

	H.section("It needs a city plot")
	H.check(C.BIZ.theater and C.BIZ.theater.lotOnly and C.BIZ.theater.index == 9, "the Movie Theater is business #9 and lives on city plots")
	d.rep = 2000
	d.cash = 1e9
	H.check(F.bizUnlocked(d, "theater"), "(Alice has the reputation for it)")
	local mark = #H.remoteLog
	F.buyUpgrade(a, d, "theater")
	H.task.wait(0.6)
	H.check((d.levels.theater or 0) == 0 and d.cash == 1e9, "buying it from the business list without a plot does nothing (no charge)")
	H.check(lastMenu("needPlot", mark) == "theater", "...and says why")
	H.check(cc.modals.theater.frame.Visible and guiText("OPEN A MOVIE THEATER") ~= nil and find(a.PlayerGui, function(x) return x.Name == "GoProperties" end) ~= nil,
		"the 🍿 Theater app opens with how to get one (and a button to Properties)")
	cc.closeModals()

	H.section("Opening on a plot")
	local lot = lotIn("downtown") or lotIn("midtown")
	local deed = F.buyPlot(a, lot)
	H.check(deed and lot.owner == a, "Alice buys a " .. lot.dkey .. " plot")
	local cost = F.upgradeCost(d, "theater")
	local cash0 = d.cash
	H.check(F.setDeedBiz(a, deed.id, "theater") == true, "she chooses 🎬 Movie Theater on it")
	local spent = cash0 - d.cash
	H.task.wait(0.5)
	calm()
	H.check(d.levels.theater == 1 and deed.biz == "theater" and spent <= cost and spent >= cost - F.incomePerSec(d) * 5, "it opens there for $" .. C.fmt(cost))
	local slot = d.plot.slots.theater
	H.check(slot ~= nil and slot == lot.folder, "the theater's building is the plot's building")
	H.check(find(d.plot.folder, function(x) return x.Name == "Screen" end) == nil and find(lot.folder, function(x) return x.Name == "Screen" end) ~= nil,
		"the Pop-up Screen stands on the city plot, nothing on the home plot")
	local scf = F.slotCF(d.plot, "theater")
	H.check((scf.Position - lot.pos).Magnitude < 1, "customers, moments and the Rush Orders counter go to the plot")
	H.check(find(lot.folder, function(x) return x.ClassName == "ProximityPrompt" and x.ActionText:find("Rush orders") end) ~= nil, "the plot has a 🍳 Rush orders counter")
	H.check(find(lot.folder, function(x) return x.ClassName == "ProximityPrompt" and x.ActionText:find("Programme") end) ~= nil, "...and a 🎬 Programme box office")
	-- growing into a real cinema
	for _ = 1, 3 do F.buyUpgrade(a, d, "theater") end
	H.task.wait(0.5)
	calm()
	slot = d.plot.slots.theater
	local marq = slot and find(slot, function(x) return x.Name == "Marquee" and x:IsA("BasePart") end)
	local film = F.theaterFilm(d)
	local mt = marq and find(marq, function(x) return x.ClassName == "TextLabel" end)
	H.check(d.levels.theater == 4 and marq ~= nil, "at level 4 it's a " .. C.BIZ.theater.tiers[C.stageOf(4, 0)] .. " with a lit marquee")
	H.check(mt and mt.Text:find(string.upper(film.title), 1, true), "the marquee shows the film: " .. tostring(mt and mt.Text))

	H.section("Shows")
	mark = #H.remoteLog
	local last = F.theaterShow(a)
	H.check(last and last.guests > 0 and last.guests <= last.cap and d.theater.sessions == 1, string.format("a show: %d / %d guests (%d%%)", last.guests, last.cap, last.fill))
	H.check(buzzSince(mark, "PREMIERE NIGHT") ~= nil, "the film's first show is its PREMIERE (CityBuzz)")
	H.check(d.theater.premiered[film.key] == true, "...remembered")
	local mult = F.theaterMult(d, "theater")
	H.check(mult >= C.THEATER.mult.lo and mult <= C.THEATER.mult.max, string.format("the turnout sets the theater's sales: ×%.2f", mult))
	local saved = d.theater.mult
	d.theater.mult = 1
	local base = F.bizMult(d, "theater")
	d.theater.mult = saved
	H.check(math.abs(F.bizMult(d, "theater") - base * saved) < 1e-6 * base + 1e-9 and F.theaterMult(d, "pizza") == 1, "...through the theater's own multiplier (other businesses untouched)")
	mark = #H.remoteLog
	local second = F.theaterShow(a)
	H.check(buzzSince(mark, "PREMIERE NIGHT") == nil and second.fill < last.fill, string.format("the next show of the same film: no premiere, and the hype fades (%d%% → %d%%)", last.fill, second.fill))
	-- time of day: a horror film sells at night
	local info = F.theaterInfo(a)
	local function partsSum(i) local s = 0 for _, p in ipairs(i.parts) do s += p[2] end return s end
	Lighting.ClockTime = 22
	local night = F.theaterInfo(a)
	Lighting.ClockTime = 13
	H.check(partsSum(night) > partsSum(info), "night shows are fuller (" .. partsSum(info) .. "% by day → " .. partsSum(night) .. "% at night)")

	H.section("Choosing the film")
	local films = F.filmsNow()
	H.check(#films == 3 and films[1].key ~= films[2].key and films[2].key ~= films[3].key, "3 original films are in release: " .. films[1].title .. ", " .. films[2].title .. ", " .. films[3].title)
	local other
	for _, f in ipairs(films) do if f.key ~= d.theater.film then other = f break end end
	T.act(a, "theaterFilm", other.key)
	H.task.wait(0.3)
	H.check(d.theater.film == other.key and d.theater.filmShows == 0, "Alice puts on " .. other.title)
	local mt2 = find(d.plot.slots.theater, function(x) return x.Name == "Marquee" and x:IsA("BasePart") end)
	mt2 = mt2 and find(mt2, function(x) return x.ClassName == "TextLabel" end)
	H.check(mt2 and mt2.Text:find(string.upper(other.title), 1, true), "the marquee changes")
	local third
	for _, f in ipairs(films) do if f.key ~= other.key then third = f break end end
	T.act(a, "theaterFilm", third.key)
	H.task.wait(0.3)
	H.check(d.theater.film == other.key, "changing again right away is refused (the projectionist needs a minute)")
	local out
	for _, f in ipairs(C.FILMS) do
		local inRel = false
		for _, g in ipairs(films) do if g.key == f.key then inRel = true end end
		if not inRel then out = f break end
	end
	H.task.wait(C.THEATER.changeCooldown + 1)
	for _, bad in ipairs({out.key, "notafilm", 42, {}}) do T.act(a, "theaterFilm", bad) end
	H.task.wait(0.3)
	H.check(d.theater.film == other.key, "films not in release and made-up ones are refused")
	-- it rotates: a few hours later different films are out (the same in every server)
	local later = F.filmsNow(os.time() + C.THEATER.release)
	H.check(later[1].key ~= films[1].key, "the release list rotates every " .. (C.THEATER.release / 3600) .. " h")

	H.section("Upgrades")
	local cap0 = F.theaterInfo(a).capacity
	local c0 = d.cash
	local upCost = F.theaterUpCost(0)
	T.act(a, "theaterUp", "seats")
	H.task.wait(0.3)
	local paid = c0 - d.cash
	H.check(d.theater.up.seats == 1 and F.theaterInfo(a).capacity > cap0 and paid <= upCost and paid >= upCost - F.incomePerSec(d) * 2, "💺 Seats level 1: " .. cap0 .. " → " .. F.theaterInfo(a).capacity .. " seats for $" .. C.fmt(upCost))
	local f0 = F.theaterInfo(a).fill
	T.act(a, "theaterUp", "screen")
	H.task.wait(0.3)
	H.check(d.theater.up.screen == 1 and F.theaterInfo(a).fill > f0, "🖥️ Screen: fuller shows (" .. f0 .. "% → " .. F.theaterInfo(a).fill .. "%)")
	d.cash = 10
	T.act(a, "theaterUp", "sound")
	H.task.wait(0.3)
	H.check(d.theater.up.sound == 0 and d.cash >= 10, "not enough cash: refused")
	d.cash = 1e12
	for _ = 1, 8 do T.act(a, "theaterUp", "snacks") end
	H.task.wait(0.3)
	H.check(d.theater.up.snacks == 5, "upgrades stop at level 5")
	local before, ups0 = d.cash, table.clone(d.theater.up)
	for _, bad in ipairs({"hack", 5, {}, nil}) do T.act(a, "theaterUp", bad) end
	T.act(bob, "theaterUp", "seats")
	H.task.wait(0.3)
	local same = true
	for k, v in pairs(ups0) do if d.theater.up[k] ~= v then same = false end end
	H.check(same and d.cash >= before and (db.theater == nil or db.theater.up == nil or (db.theater.up.seats or 0) == 0), "made-up upgrades, and someone without a theater, do nothing")

	H.section("The 🍿 Theater app")
	cc.openModal("theater", true)
	H.task.wait(0.8)
	H.check(guiText("NOW SHOWING") ~= nil and guiText(other.title) ~= nil, "the app shows what's on")
	local fb = find(a.PlayerGui, function(x) return x.Name:sub(1, 5) == "Film_" and x.Visible end)
	H.check(fb ~= nil, "...the other films in release with a Show this button")
	local ub = find(a.PlayerGui, function(x) return x.Name == "Up_sound" end)
	H.check(ub ~= nil, "...and the upgrades")
	local s0 = d.theater.up.sound
	H.signalOf(ub, "MouseButton1Click"):Fire()
	H.task.wait(0.6)
	H.check(d.theater.up.sound == s0 + 1, "tapping an upgrade buys it (server-checked)")
	cc.closeModals()
	-- the box office prompt opens it for the owner; others are told what's on
	local bo = find(d.plot.slots.theater, function(x) return x.ClassName == "ProximityPrompt" and x.ActionText:find("Programme") end)
	mark = #H.remoteLog
	H.signalOf(bo, "Triggered"):Fire(bob)
	H.task.wait(0.3)
	H.check(buzzSince(mark, "Now showing at Alice") ~= nil and not cc.modals.theater.frame.Visible, "Bob at the box office: told what's showing")
	H.signalOf(bo, "Triggered"):Fire(a)
	H.task.wait(0.8)
	H.check(cc.modals.theater.frame.Visible, "Alice at the box office: the app opens")
	cc.closeModals()

	H.section("Inside")
	F.enterInterior(a, a, "theater")
	H.task.wait(1.5)
	local room = H.workspace:FindFirstChild("Interiors")
	local scr = room and find(room, function(x) return x.Name == "Screen" and x:IsA("BasePart") end)
	local st = scr and find(scr, function(x) return x.ClassName == "TextLabel" end)
	H.check(st and st.Text:find(string.upper(other.title), 1, true), "the big screen inside shows the film")
	local seats = 0
	for _, x in ipairs(room:GetDescendants()) do if x:IsA("BasePart") and x.Material == Enum.Material.Fabric and x.Color == Color3.fromRGB(190, 30, 50) then seats += 1 end end
	H.check(seats >= 24, "rows of red seats (" .. seats .. ")")
	if F.leaveInterior then F.leaveInterior(a) end
	H.task.wait(1)

	H.section("Shows run by themselves")
	local n0 = d.theater.sessions
	H.task.wait(C.THEATER.session + 5)
	H.check(d.theater.sessions > n0, "a show starts every " .. C.THEATER.session .. " s while Alice plays (" .. n0 .. " → " .. d.theater.sessions .. ")")

	H.section("Moving plots")
	H.check(F.sellDeed(a, deed.id), "Alice sells the theater's plot")
	H.task.wait(0.5)
	H.check(d.levels.theater == 4 and F.theaterShow(a) == nil and F.theaterInfo(a).hasPlot == false, "the theater keeps its level; no shows until it has a plot again")
	local lot2 = lotIn("midtown") or lotIn("suburbs")
	local deed2 = F.buyPlot(a, lot2)
	local c1 = d.cash
	H.check(deed2 and F.setDeedBiz(a, deed2.id, "theater") and d.cash == c1 and d.plot.slots.theater == lot2.folder, "choosing it on a new plot moves it there for free")
	H.check(F.theaterShow(a) ~= nil, "...and the shows go on")

	H.section("Saved")
	local okSave = F.save and F.save(a)
	local store = rawget(T.slotStore(), "_data")
	local rec
	for k, v in pairs(store or {}) do if type(v) == "table" and k:find("u101_s") and type(v.theater) == "table" then rec = v.theater end end
	H.check(okSave and rec and rec.sessions == d.theater.sessions and rec.up.seats == 1 and rec.premiered[film.key] == true, "the theater record is saved (shows, upgrades, premieres)")

	T.assertClean("theater")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
