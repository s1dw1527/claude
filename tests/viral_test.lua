-- v9: Viral Moments (score, cooldowns, uniqueness, CityBuzz), influencers (spawn, talk, rewards only for the target,
-- despawn), rare and funny city events, the Viral app, weekly boards, achievements, Lil Clipz, and performance caps.
-- Run with: python3 tests/run.py tests/viral_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local pg = a:FindFirstChild("PlayerGui")
	local function findLike(pat)
		for _, x in ipairs(pg:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end
	local function calm()
		local t = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut = 0
	d.cash, d.rep = 1e9, 6000
	for _, k in ipairs({"lemonade", "pizza", "arcade"}) do T.act(a, "buy", k) end
	H.task.wait(1)
	calm()

	-- =====================================================================
	H.section("Viral Score, cooldowns and \"only once\" moments")
	local v = d.viral
	local s0 = v.score
	local m1 = F.viralMoment(a, "eviction", {tenant = "Gus", item = "a rubber duck"})
	H.check(m1 and v.score == s0 + 60 and v.weekScore >= 60 and v.mentions >= 1, "an eviction moment: +60 (score " .. v.score .. ")")
	local m2 = F.viralMoment(a, "eviction", {tenant = "Gus", item = "a sock"})
	H.check(m2 == nil and v.score == s0 + 60, "the same moment again right away: cooldown, no score")
	H.task.wait(301)
	H.check(F.viralMoment(a, "eviction", {tenant = "Gus", item = "a lamp"}) ~= nil, "after the 5-minute cooldown it counts again")
	local o1 = F.viralMoment(a, "opening", {uniq = "tech", biz = "Tech Store"})
	local o2 = F.viralMoment(a, "opening", {uniq = "tech", biz = "Tech Store"})
	H.check(o1 ~= nil and o2 == nil, "a grand opening counts once per business, ever")
	local farm = 0
	for _ = 1, 50 do if F.viralMoment(a, "lostKeys", {}) then farm += 1 end end
	H.check(farm == 1, "spamming one action can't farm score (" .. farm .. " of 50 counted)")
	local cash0 = d.cash
	F.viralMoment(a, "theCrowd", {biz = "Pizza", force = true})
	H.check(math.abs(d.cash - cash0) < F.incomePerSec(d) * 2 + 1, "Viral Score never pays cash")

	H.section("CityBuzz: moments become posts, without spamming the feed")
	local mark = C.FEED[1] and C.FEED[1].id or 0
	H.task.wait(100)
	local before = #C.FEED
	local n = 0
	for i = 1, 6 do
		if F.viralMoment(a, "funnyEvent", {title = "Test " .. i, post = "Funny thing #" .. i, force = true}) then n += 1 end
	end
	local newPosts = 0
	for _, p in ipairs(C.FEED) do if p.id > mark and tostring(p.text):find("^Funny thing") then newPosts += 1 end end
	H.check(n == 6 and newPosts <= 1, "6 quick low-importance moments: all scored, at most 1 post (" .. newPosts .. ")")
	local hit = false
	for _, p in ipairs(C.FEED) do if tostring(p.text):find("evicted") or tostring(p.text):find("Gus") then hit = true end end
	H.check(hit, "the eviction became a CityBuzz post")

	H.section("The pop-up and Photo Mode capture (\"Bro Got Content\")")
	H.task.wait(1)
	local last = cc.CityLife.lastMoment
	H.check(last and last.id and findLike("VIRAL MOMENT") ~= nil, "a VIRAL MOMENT pop-up shows on screen")
	local cap = findLike("📸 Capture")
	H.check(cap ~= nil and cap.Size.Y.Offset >= 40, "with a 📸 Capture button big enough to tap")
	-- capture the newest moment from the pop-up
	F.viralMoment(a, "luxuryCar", {car = "Test Car"})
	H.task.wait(0.5)
	cap = findLike("📸 Capture")
	local capturedId = cc.CityLife.lastMoment.id
	H.signalOf(cap, "MouseButton1Click"):Fire()
	H.task.wait(0.8)
	H.check(cc.photoActive and d.achievements.broGotContent ~= nil, "capturing opens Photo Mode and unlocks \"Bro Got Content\"")
	cc.setPhoto(false)
	H.check(F.viralCapture(a, capturedId) == false, "the same moment can't be captured twice")
	H.check(cc.CityLife.lastMoment.key ~= "capture", "capturing doesn't pop up a moment of its own")
	H.check(F.viralCapture(a, 999999) == false, "made-up moment ids are refused")
	local old = F.viralMoment(a, "competition", {})
	H.task.wait(200)
	H.check(old and F.viralCapture(a, old.id) == false, "moments older than 3 minutes can't be captured")

	H.section("Detectors that watch real play")
	-- 25 customers at one business in 30 seconds
	local t = C.NPC_TYPES[1]
	for _ = 1, 25 do F.serveCustomer(a, d, "pizza", t, nil) end
	H.check(d.achievements.whoInvited ~= nil, "25 customers at one business in 30 s: \"WHO INVITED EVERYONE?\"")
	-- a 1-star review can become a moment (35% of the time)
	local got = 0
	for _ = 1, 40 do
		v.cd.terribleReview = nil
		local before2 = v.score
		F.viralReview(a, d, "pizza", {stars = 1, text = "Too much pizza."})
		if v.score > before2 then got += 1 end
	end
	H.check(got > 4 and got < 30, "1-star reviews sometimes go viral (" .. got .. "/40)")
	-- a crash only counts in your own car next to your own business
	local vs = v.score
	T.act(a, "viral", "crash", 90)
	H.check(v.score == vs, "a crash report without a car is ignored")
	F.spawnCar(a, "moped", F.bizAnchor(d, "pizza") * CFrame.new(0, 2, 2))
	H.task.wait(0.5)
	local car = F.activeCar(a)
	if car then
		local hum = a.Character:FindFirstChildOfClass("Humanoid")
		car.seat:Sit(hum)
		H.task.wait(0.3)
		T.act(a, "viral", "crash", 9999)
		H.check(v.score == vs, "an impossible speed is ignored")
		T.act(a, "viral", "crash", 80)
		H.check(v.score > vs, "your own car, next to your own business: \"Local CEO declares war on parking lot.\"")
		car.seat.Occupant = nil
		rawget(hum, "_p").SeatPart = nil
		F.despawnCar(a)
	else
		H.check(false, "couldn't spawn a car for the crash test")
	end
	-- the billionaire lemonade guy
	d.home = d.home or {level = 0}
	d.home.level = 4
	F.viralTick(a, d)
	local lem = false
	for _, e in ipairs(v.log) do if e.key == "billionaireLemonade" then lem = true end end
	H.check(lem, "a big house and a tiny lemonade stand: THE BILLIONAIRE LEMONADE GUY")
	d.home.level = 0
	calm()

	H.section("Lil Clipz notices")
	local cl = #H.remoteLog
	local gap = C.VIRAL.clipzGap
	C.VIRAL.clipzGap = 0   -- (he may already have reacted to something earlier in this test)
	F.viralMoment(a, "carCrash", {car = "Moped", biz = "Pizza", force = true, clipzChance = 1})
	C.VIRAL.clipzGap = gap
	H.task.wait(5)
	local clipz
	for _, e in ipairs(T.remotesSince(cl, "Cinematic", a)) do if e.args[1].kind == "clipz" then clipz = e.args[1] end end
	H.check(clipz and clipz.lines[1][1] == "rival" and clipz.mode == "short", "Lil Clipz reacts (" .. tostring(clipz and clipz.lines[1][2]) .. ")")
	calm()

	-- =====================================================================
	H.section("Influencers")
	local bob = T.join("Bob", 202)
	local db = T.newGame(bob, 1, 2)
	db.cash, db.rep, db.tut = 1e8, 2000, 0
	T.act(bob, "buy", "lemonade")
	H.check(C.INFLUENCER_TIMING.gap[1] >= 300 and C.INFLUENCER_TIMING.first[1] >= 180, "visits are rare: minutes apart, one at a time")
	for _, inf in ipairs(C.INFLUENCERS) do
		H.check(inf.name and inf.catch and inf.bio, inf.icon .. " " .. inf.name .. ": \"" .. inf.catch .. "\"")
	end
	-- (a scheduled visit may already have happened during this long test: clear it and its cooldown)
	if C.influencerState() then C.influencerLeave("done") end
	v.cd.influencerVisit = nil
	mark = #H.remoteLog
	local vb0 = v.score
	local visit = F.startInfluencer("baysnaps", a)
	H.task.wait(1)
	H.check(visit and visit.target == a, "Bay Snaps shows up at Alice's business")
	local seen = T.remotesSince(mark, "Viral")
	local spawnMsg
	for _, e in ipairs(seen) do if e.args[1].kind == "influencer" and e.dir == "s2all" then spawnMsg = e.args[1] end end
	H.check(spawnMsg and spawnMsg.who == "baysnaps", "everyone in the server sees the sighting")
	H.check(v.score >= vb0 + 50, "the visit itself: +50")
	local function worldText(pat)
		for _, x in ipairs(H.workspace:FindFirstChild("CityLife"):GetDescendants()) do
			if x.ClassName == "TextLabel" and tostring(x.Text):find(pat) then return x end
		end
	end
	local marker = worldText("BAY SNAPS • FOR YOU")
	H.check(marker ~= nil, "Alice's screen shows a 🚨 marker she can find")
	local sightings = cc.S and cc.S.viral and cc.S.viral.sightings or {}
	H.task.wait(1.5)
	sightings = cc.S.viral.sightings
	H.check(#sightings >= 1 and sightings[1].here, "the Viral app lists the sighting as HERE NOW")
	-- Bob walks up first: just a hello, no rewards
	local bobScore = db.viral.score
	local prompt
	for _, x in ipairs(visit.part:GetDescendants()) do if x.ClassName == "ProximityPrompt" then prompt = x end end
	H.signalOf(prompt, "Triggered"):Fire(bob)
	H.task.wait(0.5)
	H.check(db.viral.score == bobScore and not visit.met, "Bob can say hi, but the visit (and the rewards) aren't his")
	-- Alice talks to Bay Snaps
	mark = #H.remoteLog
	H.signalOf(prompt, "Triggered"):Fire(a)
	H.task.wait(0.5)
	local scene
	for _, e in ipairs(T.remotesSince(mark, "Cinematic", a)) do if e.args[1].kind == "influencer" then scene = e.args[1] end end
	H.check(visit.met and scene and scene.lines[1][2] == "CHAT, WE GOTTA SEE THIS.", "talking to Bay Snaps plays the scene: \"" .. tostring(scene and scene.lines[2][2]) .. "\"")
	H.signalOf(prompt, "Triggered"):Fire(a)
	H.check(#T.remotesSince(mark, "Cinematic", a) == 1, "...only once per visit")
	-- leaving
	H.task.wait(40)
	H.check(C.influencerState() == nil and visit.part.Parent == nil, "after the visit Bay Snaps leaves and the prompt is gone")
	H.task.wait(5)
	H.check(worldText("BAY SNAPS • FOR YOU") == nil, "...and the marker disappears from the world")
	calm()

	H.section("Influencer despawns when their player leaves; the others")
	local v2 = F.startInfluencer("jaxcash", bob)
	H.check(v2 and v2.target == bob, "Jax Cash visits Bob")
	H.removePlayer(bob)
	H.task.wait(1)
	H.check(C.influencerState() == nil and v2.part.Parent == nil, "Bob leaves: Jax Cash leaves too (no orphaned NPC)")
	local v3 = F.startInfluencer("mayamax", a)
	H.check(v3 ~= nil, "Maya Max visits (" .. tostring(v3 and v3.place) .. ")")
	if v3 then F.influencerTalk(a) end
	H.task.wait(1)
	calm()
	C.influencerLeave("done")
	-- Drew Deals: an honest gamble in Messages
	local v4 = F.startInfluencer("drewdeals", a)
	F.influencerTalk(a)
	H.task.wait(1)
	local offer
	for _, m in ipairs(d.inbox) do if m.kind == "deal" and not m.resolved then offer = m end end
	H.check(offer and offer.choices and #offer.choices == 2, "Drew Deals leaves an offer in Messages: \"" .. tostring(offer and offer.text) .. "\"")
	local c0 = d.cash
	T.act(a, "msgChoice", offer.id, 2)
	H.check(d.cash == c0 or math.abs(d.cash - c0) < F.incomePerSec(d) + 1, "saying no costs nothing")
	-- the odds lose a little on average (no money printer)
	local total, put = 0, 0
	local fake = {kind = "deal", ref = {stake = 1000, win = true}}
	for _ = 1, 4000 do
		local cbefore = d.cash
		F.dealChoice(a, fake, 1)
		total += d.cash - cbefore + 1000
		put += 1000
	end
	H.check(total / put < 1 and total / put > 0.75, string.format("Drew's deals return %.2fx on average: a gamble, never a money printer", total / put))
	C.influencerLeave("done")
	local _ = v4
	calm()

	-- =====================================================================
	H.section("Rare viral events")
	local served0 = d.bizServed.pizza or 0
	cc.CityLife.endAll()
	local camera = H.workspace.CurrentCamera
	camera.CFrame = CFrame.new((F.bizAnchor(d, "pizza") * CFrame.new(0, 10, 25)).Position)
	H.check(F.theCrowd(a, "pizza", "test"), "THE CROWD gathers outside the pizza place")
	H.task.wait(2)
	H.check(cc.CityLife.actorCount >= 10, "a crowd is drawn near the camera (" .. cc.CityLife.actorCount .. " people)")
	H.task.wait(32)
	H.check((d.bizServed.pizza or 0) - served0 >= 25, "the crowd really buys: " .. ((d.bizServed.pizza or 0) - served0) .. " extra customers")
	H.check(d.achievements.mainCharacter ~= nil, "a rare event: \"Main Character\"")
	H.task.wait(10)
	H.check(cc.CityLife.actorCount == 0, "when it's over, every crowd NPC is gone")
	-- far away: nothing is built
	camera.CFrame = CFrame.new(5000, 400, 5000)
	F.viralMoment(a, "theCrowd", {}) -- (score only)
	local st = C.CITY_EVENTS
	H.check(st.crowdSize <= 16, "crowds are capped")
	d.cd = nil
	local ok = F.theCrowd(a, "pizza", "test")
	H.task.wait(2)
	H.check(ok == false or cc.CityLife.actorCount == 0, "a crowd across the city costs this player nothing (0 NPCs built)")
	camera.CFrame = CFrame.new(a.Character.HumanoidRootPart.Position + Vector3.new(0, 10, 25))
	-- paparazzi + everyone knows you + a crowd at the same time stay under the cap
	H.check(F.paparazzi(a), "PAPARAZZI MODE")
	H.check(F.everyoneKnows(a, 0), "EVERYONE KNOWS YOU")
	H.task.wait(12)
	H.check(cc.CityLife.actorCount <= 28, "everything at once stays under the NPC cap (" .. cc.CityLife.actorCount .. ")")
	H.task.wait(30)
	-- business beef, and a business sold mid-event
	H.check(F.businessBeef(a, "arcade"), "BUSINESS BEEF: a rival pop-up opens next to the arcade")
	local beef = C.beefState(a)
	H.task.wait(1.5)
	H.check(cc.S.beef and tostring(cc.S.beef.text):find("BEEF"), "the HUD tracks it: \"" .. tostring(cc.S.beef and cc.S.beef.text) .. "\"")
	for _ = 1, beef.goal do F.serveCustomer(a, d, "arcade", t, nil) end
	H.task.wait(4)
	H.check(C.beefState(a) == nil and beef.model.Parent == nil, "serve enough customers and you win; the pop-up packs up")
	H.check(F.businessBeef(a, "lemonade"), "another beef...")
	local beef2 = C.beefState(a)
	d.levels.lemonade = 0
	H.task.wait(4)
	H.check(C.beefState(a) == nil and beef2.model.Parent == nil, "...ends quietly if that business is sold mid-event")
	d.levels.lemonade = 1
	F.theCrowd(a, "arcade", "test2")
	H.task.wait(3)
	local arc0 = d.bizServed.arcade
	d.levels.arcade = 0
	H.task.wait(30)
	H.check(d.bizServed.arcade == arc0, "a crowd at a business that's sold mid-event stops buying (no errors)")
	d.levels.arcade = 1

	H.section("Funny random events")
	for _, k in ipairs({"inspector", "customerArmy", "deliveryDisaster", "richKid", "badInvestor"}) do
		local mk = #H.remoteLog
		local cashB = d.cash
		local okE = F.funnyEvent(a, k)
		local sc
		for _, e in ipairs(T.remotesSince(mk, "Cinematic", a)) do sc = e.args[1] end
		H.check(okE and sc and sc.lines and #sc.lines >= 2, k .. ": \"" .. tostring(sc and sc.lines[#sc.lines][2]) .. "\"")
		if k == "richKid" then H.check(d.cash - cashB <= F.incomePerSec(d) * 25 + 30, "the rich kid's tip is a treat, not a payday") end
		calm()
	end

	-- =====================================================================
	H.section("The Viral app")
	H.task.wait(1.5)
	cc.togglePhone(true)
	cc.phoneView("viral")
	H.task.wait(0.5)
	H.check(findLike("YOUR VIRAL SCORE") ~= nil and findLike("^🔥 [%d,%.KM]+$") ~= nil, "shows your Viral Score")
	H.check(findLike("mentioned %d+ time") ~= nil, "\"Your empire has been mentioned N times.\"")
	H.check(findLike("YOUR RECENT MOMENTS") ~= nil, "your recent moments")
	H.signalOf(findLike("🏙️ City"), "MouseButton1Click"):Fire()
	H.task.wait(0.3)
	H.check(findLike("INFLUENCER SIGHTINGS") and findLike("TRENDING IN THE CITY") and findLike("FUNNIEST RECENT EVENTS") and findLike("TOP CITYBUZZ POSTS"), "City tab: sightings, trending, funniest, top posts")
	C.refreshViralBoards()
	H.task.wait(1.5)
	H.signalOf(findLike("🏆 Weekly"), "MouseButton1Click"):Fire()
	H.task.wait(0.3)
	H.check(findLike("Most Viral Business") and findLike("Funniest Moments") and findLike("Best Interior") and findLike("Biggest Empire"), "Weekly tab: every category")
	H.check(findLike("Alice  %(you%)") ~= nil, "Alice is on the board")
	H.check(d.achievements.actuallyFamous ~= nil and #v.hall >= 1, "top 3 this week: \"Actually Famous\" (kept in the Hall of Fame)")
	cc.togglePhone(false)

	H.section("Achievements and saving")
	v.score = math.max(v.score, 9990)
	F.viralMoment(a, "funnyEvent", {title = "x", post = "y", force = true})
	H.check(d.achievements.empireInfluencer ~= nil, "10,000 Viral Score: \"Empire Influencer\"")
	H.check(d.achievements.internetFamous ~= nil, "an influencer posted about you: \"Internet Famous\"")
	for _, k in ipairs({"kickRocks", "landlordMode", "whoInvited", "mainCharacter", "internetFamous", "actuallyFamous", "broGotContent", "empireInfluencer"}) do
		H.check(C.ACHIEVEMENTS[k] and C.ACHIEVEMENTS[k].title, "achievement " .. k .. ": " .. tostring(C.ACHIEVEMENTS[k] and C.ACHIEVEMENTS[k].title))
	end
	H.check(C.ACHIEVEMENTS.firstBusiness.title == "Open for Business", "\"Open for Business\" (the first-business achievement)")
	F.save(a)
	H.task.wait(0.5)
	local saved = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(saved.viral and saved.viral.score == v.score and #saved.viral.log >= 5 and #saved.viral.hall >= 1, "Viral Score, moments and the Hall of Fame are saved")
	T.act(a, "menuExit")
	H.task.wait(1.5)
	T.act(a, "menuPlay", 1)
	H.task.wait(4)
	H.check(T.data(a).viral.score == saved.viral.score, "...and loaded back after rejoining")

	T.assertClean("viral")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
