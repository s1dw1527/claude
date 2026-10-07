-- v9: save migration, the eviction cinematic (and its edge cases), the cinematic controller, grand openings,
-- staff scenes, achievements, interiors (score, fixtures, staff + customer life) and multiplayer isolation.
-- Run with: python3 tests/run.py tests/v9_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local UIS = H.service("UserInputService")
	local db0 = rawget(T.slotStore(), "_data")

	-- =====================================================================
	H.section("An old v8 save with none of the v9 fields")
	db0["u101_s1"] = {SchemaVersion = 8, cash = 777777, earned = 9e6, levels = {lemonade = 10, icecream = 5, pizza = 4}, rep = 900, tut = 0, tutPaid = 7,
		mail = {}, interiors = {pizza = {wall = "brick", floor = "wood", light = "warm", spots = {["1"] = "booth"}}}, improve = {}, reviewBook = {}, homeVisits = 3,
		achievements = {million = 1}, saveSeq = 4, staff = {}, cars = {}}
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	T.act(a, "menuPlay", 1)
	H.task.wait(4)
	local d = T.data(a)
	H.check(d and not d.noSave and d.cash >= 777777 and d.levels.pizza == 4 and d.interiors.pizza.wall == "brick" and d.homeVisits == 3,
		"it loads with every v8 field intact (cash, levels, interiors, visits)")
	H.check(type(d.viral) == "table" and d.viral.score == 0 and d.evictions == 0 and type(d.openings) == "table", "v9 fields start with safe defaults")
	F.save(a)
	H.task.wait(0.5)
	local s1 = db0["u101_s1"]
	H.check(s1.SchemaVersion == C.VERSION.SCHEMA_VERSION and s1.saveSeq == 5 and s1.cash >= 777777 and s1.achievements.million and type(s1.viral) == "table", "saved back as the current schema (" .. C.VERSION.SCHEMA_VERSION .. ") without losing anything")
	local cc = H.clientC
	local pg = a:FindFirstChild("PlayerGui")
	local function findLike(pat, cls)
		for _, x in ipairs(pg:GetDescendants()) do
			if (x.ClassName == (cls or "TextLabel") or (not cls and x.ClassName == "TextButton")) and tostring(x.Text):find(pat) then return x end
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
	d.cash, d.rep = 1e9, 6000

	H.section("A v9 save whose viral record is damaged")
	db0["u101_s2"] = {SchemaVersion = 9, cash = 4242, earned = 5000, levels = {lemonade = 6}, rep = 30, tut = 0, tutPaid = 7, viral = {score = "lots", log = "nope"}, evictions = "many"}
	T.act(a, "menuExit")
	H.task.wait(1.5)
	T.act(a, "menuPlay", 2)
	H.task.wait(4)
	local d2 = T.data(a)
	H.check(d2 and not d2.noSave and d2.cash >= 4242 and d2.levels.lemonade == 6, "the rest of the save loads normally")
	H.check(d2.viral.score == 0 and type(d2.viral.log) == "table" and d2.evictions == 0, "the broken v9 parts are reset to safe values")
	F.save(a)
	H.task.wait(0.5)
	H.check(type(db0["u101_s2"].viralRecovered) == "table" and db0["u101_s2"].viralRecovered.score == "lots", "...and the damaged original is kept in the save (viralRecovered), not thrown away")
	T.act(a, "menuExit")
	H.task.wait(1.5)
	T.act(a, "menuPlay", 1)
	H.task.wait(4)
	d = T.data(a)
	calm()
	d.cash, d.rep = 1e9, 6000

	H.section("Migration self-test (v5 / v6 / v7 / v8 / v9 samples)")
	local okAll, lines = true, C.DataMigration.selfTest()
	for _, l in ipairs(lines) do if l:sub(1, 3) ~= "✅" then okAll = false print("    " .. l) end end
	H.check(okAll and #lines >= 10, #lines .. " migration checks, all passing (includes a crashing v9 step and a damaged v9 record)")

	-- =====================================================================
	H.section("Eviction: state first, cinematic second")
	T.act(a, "propBuy", 1, "walkup")
	H.task.wait(0.5)
	calm()
	local b = d.props[1]
	H.check(b ~= nil, "Alice owns a walk-up")
	table.insert(d.props[1].applicants, 1, F.newApplicant())
	T.act(a, "tenantAccept", 1, 1)
	local tenant = b.units[1]
	H.check(tenant and tenant.name, "a tenant moved into unit 1A (" .. tostring(tenant and tenant.name) .. ")")
	tenant.since = os.time() - 47 * C.GAME_DAY - 5
	calm()
	local mark = #H.remoteLog
	T.act(a, "evict", 1, 1)
	H.check(b.units[1] == false, "the unit is empty the moment you evict (before any animation)")
	H.check(d.evictions == 1 and d.achievements.kickRocks ~= nil, "eviction counted + \"Kick Rocks\" unlocked")
	local scenes = T.remotesSince(mark, "Cinematic", a)
	local sc = scenes[1] and scenes[1].args[1]
	H.check(sc and sc.kind == "evict" and sc.mode == "full" and sc.at and sc.at.LookVector ~= nil, "the eviction cinematic is sent to Alice")
	local said = {}
	for _, l in ipairs(sc and sc.lines or {}) do table.insert(said, l[2]) end
	print("    lines: " .. table.concat(said, " / "))
	H.check(#said >= 3 and sc.result and sc.result[1] == "EVICTION COMPLETE" and tostring(sc.result[2]):find("now available") ~= nil, "it has the banter and ends with EVICTION COMPLETE / available")
	local has47 = false
	for _, s in ipairs(said) do if s:find("47 game days") then has47 = true end end
	print("    (\"47 game days\" line picked this time: " .. tostring(has47) .. ")")
	local logged = false
	for _, e in ipairs(d.viral.log) do if e.key == "eviction" then logged = true end end
	H.check(logged, "it's a viral moment (\"Bro just got evicted\")")
	-- the property is available again
	H.check(#b.applicants >= 1, "applicants are still waiting")
	table.insert(d.props[1].applicants, 1, F.newApplicant())
	T.act(a, "tenantAccept", 1, 1)
	H.check(b.units[1] ~= false, "...and the freed unit can be rented again")

	H.section("The cinematic plays on the client, can be skipped, and cleans up")
	H.task.wait(1)
	H.check(cc.cinematicPlaying(), "the scene is playing")
	local cam = H.workspace.CurrentCamera
	H.check(cam.CameraType == Enum.CameraType.Scriptable and cc.gui.Enabled == false, "FULL mode: the camera is directed and the HUD steps aside")
	local cineGui = pg:FindFirstChild("EmpireCinematic")
	local skip
	for _, x in ipairs(cineGui:GetDescendants()) do if x.ClassName == "TextButton" and tostring(x.Text):find("^Skip") then skip = x end end
	H.check(skip and skip.Visible and skip.Size.Y.Offset >= 44, "a Skip button is on screen, big enough for a thumb (" .. tostring(skip and skip.Size.Y.Offset) .. "px)")
	H.check(skip and skip.Position.Y.Scale == 0 and skip.AnchorPoint.X == 1, "...in the top-right corner, away from the phone and the mobile jump button")
	H.task.wait(2)
	H.check(H.workspace:FindFirstChild("Cinematic_evict") ~= nil, "the actors and props exist while it plays")
	cc.Cinematics.queue[1] = nil   -- (Lil Clipz may react to the eviction a few seconds later; not part of this check)
	H.signalOf(skip, "MouseButton1Click"):Fire()
	H.task.wait(1)
	H.check(cc.Cinematics.last.kind == "evict" and cc.Cinematics.last.skipped, "Skip ends it")
	cc.Cinematics.clear()
	H.task.wait(1)
	H.check(H.workspace:FindFirstChild("Cinematic_evict") == nil, "every part of the scene is cleaned up")
	H.check(cam.CameraType == Enum.CameraType.Custom and cc.gui.Enabled == true, "camera and HUD are back to normal")
	H.check(findLike("EVICTION COMPLETE") ~= nil, "the result banner still shows")

	H.section("Controller and keyboard skip; an unskipped scene runs to the end")
	H.task.wait(5)
	cc.Cinematics.clear()
	H.task.wait(1)
	cc.Cinematics.play({kind = "hire", mode = "full", at = a.Character.HumanoidRootPart.CFrame, lines = {{"staff", "Test line one", "wave"}, {"you", "Test line two", "owner"}}, result = {"👋 HIRED", "test"}})
	H.task.wait(1)
	H.check(cc.cinematicPlaying(), "a test scene is playing")
	H.signalOf(UIS, "InputBegan"):Fire({KeyCode = Enum.KeyCode.ButtonB, UserInputType = Enum.UserInputType.Gamepad1}, false)
	H.task.wait(0.8)
	H.check(not cc.cinematicPlaying(), "controller Ⓑ skips")
	cc.Cinematics.play({kind = "hire", mode = "full", at = a.Character.HumanoidRootPart.CFrame, lines = {{"staff", "One", "wave"}}, result = {"👋", "t"}})
	H.task.wait(1)
	H.signalOf(UIS, "InputBegan"):Fire({KeyCode = Enum.KeyCode.Backspace, UserInputType = Enum.UserInputType.Keyboard}, false)
	H.task.wait(0.8)
	H.check(not cc.cinematicPlaying(), "Backspace skips")
	local played0 = cc.Cinematics.stats.played
	cc.Cinematics.play({kind = "upgrade", mode = "short", at = a.Character.HumanoidRootPart.CFrame, lines = {{"staff", "Boss, it's... beautiful.", "shock"}}, result = {"⬆️", "t"}})
	H.task.wait(12)
	H.check(cc.Cinematics.stats.played == played0 + 1 and not cc.Cinematics.last.skipped and cc.Cinematics.last.cleaned, "a SHORT scene plays to the end by itself and cleans up")
	H.check(cam.CameraType == Enum.CameraType.Custom, "SHORT scenes never take the camera")

	H.section("Missing animations never break anything")
	local AC = cc.AnimationConfig
	local how = AC.react("facepalm")
	H.check(how == "emoji" or how == "emote", "a reaction with no animation id falls back safely (" .. tostring(how) .. ")")
	H.check(AC.react("moonwalk") ~= nil, "an unknown reaction falls back to a default")
	cc.Cinematics.play({kind = "hire", mode = "full", at = a.Character.HumanoidRootPart.CFrame, lines = {{"staff", "Watch this", "moonwalk"}, {"you", "...", "backflip"}}, result = {"ok", ""}})
	H.task.wait(1)
	H.check(AC.logged["actor:moonwalk"] ~= nil, "a missing actor move is logged (Studio only) and replaced")
	H.task.wait(8)
	H.check(not cc.cinematicPlaying() and cc.Cinematics.last.error == false, "the scene finished without an error")
	cc.Cinematics.play({kind = "opening", mode = "full", ctx = {key = "notabusiness", crowd = true}, lines = {}, result = {"x", ""}})
	H.task.wait(1)
	cc.cinematicSkip()
	H.task.wait(1)
	cc.Cinematics.play({kind = "totallyUnknownKind", mode = "full", lines = {{"nobody", "hi"}}, result = {"x", ""}})
	H.task.wait(1)
	cc.cinematicSkip()
	H.task.wait(1)
	H.check(not cc.cinematicPlaying() and cc.Cinematics.stats.errors == 0, "unknown scene kinds, unknown businesses and a missing location all play safely")

	H.section("Cinematics setting: SHORT and OFF")
	cc.settings.cinematics = "off"
	local p0 = cc.Cinematics.stats.played
	cc.Cinematics.play({kind = "evict", mode = "full", at = a.Character.HumanoidRootPart.CFrame, lines = {{"tenant", "x"}}, result = {"EVICTION COMPLETE", "y"}})
	H.task.wait(1)
	H.check(not cc.cinematicPlaying() and cc.Cinematics.stats.played == p0, "OFF: no scene, just the result banner")
	cc.settings.cinematics = "short"
	cc.Cinematics.play({kind = "evict", mode = "full", at = a.Character.HumanoidRootPart.CFrame, lines = {{"tenant", "x"}}, result = {"EVICTION COMPLETE", "y"}, ctx = {item = "a sock", days = 2}})
	H.task.wait(1)
	H.check(cc.cinematicPlaying() and cam.CameraType ~= Enum.CameraType.Scriptable, "SHORT: the scene plays in the world without taking the camera")
	cc.cinematicSkip()
	H.task.wait(1)
	cc.settings.cinematics = "full"

	-- =====================================================================
	H.section("Grand openings")
	calm()
	-- (random city events, influencer visits and funny moments share the feed gap and the viral score: pause them
	-- so the post / score this section checks can't be pre-empted by luck — same as viral_test)
	C.G.nextEvent = H.now() + 7200
	if C.megaScheduler then C.megaScheduler.nextAt = H.now() + 7200 end
	if C.funnySchedule then C.funnySchedule[a] = H.now() + 7200 end
	if C.influencerLeave then C.influencerLeave("done") end
	if C.viralLastPost then for k in pairs(C.viralLastPost) do C.viralLastPost[k] = -1e9 end end
	mark = #H.remoteLog
	local feed0 = #C.FEED > 0 and C.FEED[1].id or 0
	T.act(a, "buy", "bakery")
	H.task.wait(0.5)
	H.check((d.levels.bakery or 0) == 1 and d.openings.bakery ~= nil, "the bakery opens and the opening is recorded")
	local op = T.remotesSince(mark, "Cinematic", a)[1]
	op = op and op.args[1]
	H.check(op and op.kind == "opening" and op.ctx.key == "bakery" and op.result[1] == "🎉 GRAND OPENING!", "a grand-opening scene for the bakery (" .. tostring(op and op.mode) .. ", crowd: " .. tostring(op and op.ctx.crowd) .. ")")
	local posted = false
	for _, p in ipairs(C.FEED) do if p.id > feed0 and (p.text:find("just opened") or p.text:find("crowd") or p.text:find("in town")) then posted = true end end
	H.check(posted, "CityBuzz: \"New business just opened!\"")
	local v0 = d.viral.score
	H.task.wait(1)
	calm()
	T.act(a, "buy", "bakery")
	H.task.wait(0.5)
	local again = false
	for _, e in ipairs(T.remotesSince(mark + 1, "Cinematic", a)) do if e.args[1].kind == "opening" and e.args[1].id ~= op.id then again = true end end
	H.check(not again and d.viral.score == v0, "upgrading doesn't open it again (no second opening, no extra score)")
	calm()

	H.section("Hiring and firing")
	d.levels.coffee = 3
	mark = #H.remoteLog
	T.act(a, "candidates", "coffee")
	T.act(a, "hire", "coffee", 1)
	local hired = d.staff.coffee
	local hs = T.remotesSince(mark, "Cinematic", a)[1]
	H.check(hired and hs and hs.args[1].kind == "hire" and hs.args[1].names.staff == hired.name, "hiring " .. tostring(hired and hired.name) .. " plays the hire scene")
	calm()
	mark = #H.remoteLog
	T.act(a, "fire", "coffee")
	local fs = T.remotesSince(mark, "Cinematic", a)[1]
	H.check(d.staff.coffee == nil and fs and fs.args[1].kind == "fire", "firing plays the clear-out-the-desk scene")
	calm()

	-- =====================================================================
	H.section("Two players, events at the same time, never crossing over")
	local bob = T.join("Bob", 202)
	local db = T.newGame(bob, 1, 2)
	db.cash, db.rep, db.tut = 1e9, 6000, 0
	T.act(bob, "propBuy", 2, "walkup")
	table.insert(db.props[1].applicants, 1, F.newApplicant())
	T.act(bob, "tenantAccept", 1, 1)
	table.insert(d.props[1].applicants, 1, F.newApplicant())
	T.act(a, "tenantAccept", 1, 1)
	local aUnit
	for i, u in ipairs(d.props[1].units) do if u then aUnit = i end end
	mark = #H.remoteLog
	T.act(a, "evict", 1, aUnit)
	T.act(bob, "evict", 1, 1)
	local toA, toB, leak = 0, 0, false
	for _, e in ipairs(T.remotesSince(mark, "Cinematic")) do
		if e.dir == "s2all" then leak = true
		elseif e.player == a then toA += 1
		elseif e.player == bob then toB += 1 end
	end
	H.check(toA == 1 and toB == 1 and not leak, "each landlord gets exactly their own eviction scene (Alice " .. toA .. ", Bob " .. toB .. ")")
	H.check(db.evictions == 1 and d.evictions >= 2, "each eviction counts only for its owner")

	H.section("A tenant evicted while another player is visiting")
	local lot = C.RENT_LOTS[d.props[1].lot]
	bob.Character:PivotTo(CFrame.new(lot.pos + Vector3.new(0, 4, 12)))
	table.insert(d.props[1].applicants, 1, F.newApplicant())
	T.act(a, "tenantAccept", 1, 1)
	local occ
	for i, u in ipairs(d.props[1].units) do if u then occ = i end end
	mark = #H.remoteLog
	T.act(a, "evict", 1, occ)
	H.task.wait(0.5)
	local bobGot = false
	for _, e in ipairs(T.remotesSince(mark, "Cinematic", bob)) do if e.player == bob or e.dir == "s2all" then bobGot = true end end
	H.check(not bobGot and d.props[1].units[occ] == false, "the visitor sees the building update, but isn't dragged into the scene")

	H.section("Leaving or disconnecting during an eviction")
	table.insert(db.props[1].applicants, 1, F.newApplicant())
	T.act(bob, "tenantAccept", 1, 1)
	local bUnit
	for i, u in ipairs(db.props[1].units) do if u then bUnit = i end end
	T.act(bob, "evict", 1, bUnit)
	H.removePlayer(bob)   -- gone the same moment the scene was sent
	H.task.wait(3)
	local bs = db0["u202_s1"]
	H.check(bs and bs.evictions == 2 and bs.props and bs.props[1] and bs.props[1].units[bUnit] == false, "Bob's save has the finished eviction (the scene was presentation only)")
	H.check(C.lastCinematic[bob] == nil, "nothing about Bob's scene is left on the server")
	-- Alice leaves to the main menu in the middle of a scene
	calm()
	table.insert(d.props[1].applicants, 1, F.newApplicant())
	T.act(a, "tenantAccept", 1, 1)
	for i, u in ipairs(d.props[1].units) do if u then occ = i end end
	T.act(a, "evict", 1, occ)
	H.task.wait(1.5)
	local wasPlaying = cc.cinematicPlaying()
	T.act(a, "menuExit")
	H.task.wait(2)
	H.check(wasPlaying and not cc.cinematicPlaying() and cc.gui.Enabled == false and H.workspace:FindFirstChild("Cinematic_evict") == nil,
		"going to the main menu mid-scene ends it cleanly (the HUD stays hidden for the menu)")
	local sv = db0["u101_s1"]
	H.check(sv.evictions == d.evictions and sv.props[1].units[occ] == false, "and the save has the eviction")
	T.act(a, "menuPlay", 1)
	H.task.wait(4)
	d = T.data(a)
	calm()
	d.cash, d.rep = 1e9, 6000

	H.section("Landlord Mode")
	d.evictions = 9
	table.insert(d.props[1].applicants, 1, F.newApplicant())
	T.act(a, "tenantAccept", 1, 1)
	for i, u in ipairs(d.props[1].units) do if u then occ = i end end
	T.act(a, "evict", 1, occ)
	H.check(d.evictions == 10 and d.achievements.landlordMode ~= nil, "10 evictions: \"Landlord Mode\"")
	calm()

	-- =====================================================================
	H.section("Interiors: every business has a real layout")
	for _, bz in ipairs(C.BUSINESSES) do if (d.levels[bz.key] or 0) < 5 then d.levels[bz.key] = 5 end end
	F.refreshDoors(a)
	local folder = H.workspace:FindFirstChild("Interiors")
	local expect = {lemonade = "CLASSIC", icecream = "SCOOP", bakery = "CROISSANT", coffee = "STAFF ONLY", pizza = "DELIVERY PICKUP", arcade = "HIGH SCORES", tech = "REPAIRS", factory = "LOADING DOCK"}
	-- v10: menu boards list the business's own products
	for _, k in ipairs({"lemonade", "icecream", "bakery"}) do expect[k] = F.productsOf(d, k)[1].name end
	local sizes = {}
	for _, bz in ipairs(C.BUSINESSES) do
		T.act(a, "enterBiz", bz.key)
		H.task.wait(0.6)
		local room = folder:FindFirstChild("Interior_Alice_" .. bz.key)
		local kinds, parts, text, office = {}, 0, false, false
		if room then
			for _, x in ipairs(room:GetDescendants()) do
				if x.ClassName == "Part" then parts += 1 end
				if x.Name == "WP" then kinds[x:GetAttribute("Kind")] = true end
				if x.ClassName == "TextLabel" and tostring(x.Text):find(expect[bz.key], 1, true) then text = true end
				if x.ClassName == "TextLabel" and tostring(x.Text):find("^MANAGER") then office = true end
			end
			sizes[bz.key] = room:GetChildren()[1] and room:GetChildren()[1].Size.X or 0
		end
		H.check(room and kinds.register and kinds.order and kinds.door and kinds.wander and text and parts < 450,
			bz.icon .. " " .. bz.name .. ": fixtures + \"" .. expect[bz.key] .. "\" + staff/customer waypoints (" .. parts .. " parts" .. (office and ", manager's office" or "") .. ")")
		T.act(a, "leaveInterior")
	end
	H.check((sizes.factory or 0) >= 80 and (sizes.factory or 0) > (sizes.pizza or 0), "the factory is much bigger (" .. tostring(sizes.factory) .. " studs wide)")

	H.section("Interior score (0-100) and tiers")
	d.interiors.coffee = nil
	H.check(F.interiorScore100(d, "coffee") == 0 and F.interiorTier(0) == "EMPTY", "an untouched interior: 0/100 — EMPTY")
	T.act(a, "enterBiz", "coffee")
	H.task.wait(0.5)
	for _, x in ipairs({{"wall", "wood"}, {"floor", "marble"}, {"light", "luxury"}}) do T.act(a, "decor", x[1], nil, x[2]) end
	local items = {"espresso", "couch", "plant", "lamp", "booth", "rug", "statue", "table"}
	for i, it in ipairs(items) do T.act(a, "decor", "spot", i, it) end
	T.act(a, "decor", "spot", 9, "art") T.act(a, "decor", "spot", 10, "tv") T.act(a, "decor", "spot", 11, "neonsign")
	local sc100 = F.interiorScore100(d, "coffee")
	H.check(sc100 >= 81 and (F.interiorTier(sc100) == "ELITE" or F.interiorTier(sc100) == "VIRAL"), "fully decorated with variety: " .. sc100 .. "/100 — " .. F.interiorTier(sc100))
	local inc0 = F.incomePerSec(d)
	H.check(math.abs(F.incomePerSec(d) - inc0) < 0.01 and F.interiorSatisfaction(d, "coffee") <= 10, "the score raises satisfaction (max +10), never income")
	H.task.wait(1.5)
	local card
	cc.selectBusiness("coffee")
	H.task.wait(1.2)
	card = findLike("Interior: %d+/100")
	H.check(card ~= nil, "the management card shows it: \"" .. tostring(card and card.Text) .. "\"")
	-- duplicates count half: eight statues aren't worth eight different things
	local copy = {wall = "white", floor = "concrete", light = "basic", spots = {}}
	for i = 1, 8 do copy.spots[tostring(i)] = "plant" end
	d.interiors.lemonade = copy
	local same = F.interiorScore100(d, "lemonade")
	copy.spots = {["1"] = "plant", ["2"] = "chair", ["3"] = "lamp", ["4"] = "rug", ["5"] = "table", ["6"] = "shelf", ["7"] = "desk", ["8"] = "couch"}
	H.check(F.interiorScore100(d, "lemonade") > same, "variety beats eight of the same thing")
	T.act(a, "leaveInterior")
	H.task.wait(1)

	H.section("Staff at work, customers living their lives")
	d.levels.pizza = 8
	d.staff.manager = {name = "Morgan", service = 3, speed = 3, exp = 2}
	T.act(a, "enterBiz", "pizza")
	H.task.wait(40)
	local st = cc.InteriorLife.stats
	print(string.format("    staff %d, customers %d now, %d came in, %d ordered", st.staff, st.customers, st.spawned, st.served))
	local beh = {}
	for k, n in pairs(st.behaviors) do table.insert(beh, k .. "=" .. n) end
	print("    behaviors: " .. table.concat(beh, ", "))
	H.check(st.staff >= 4, "cashier, cook, cleaner and manager are working (" .. st.staff .. ")")
	H.check(st.spawned >= 4 and st.served >= 2, "customers come in and order (" .. st.spawned .. " in, " .. st.served .. " served)")
	H.check(st.customers <= 8, "never more than 8 customers inside (" .. st.customers .. ")")
	local f = H.workspace:FindFirstChild("InteriorLife")
	H.check(f ~= nil and #f:GetChildren() > 20, "they're drawn in the room (" .. (f and #f:GetChildren() or 0) .. " parts), even after customers have left")
	local cl = H.workspace:FindFirstChild("CityLife")
	H.check(cl ~= nil, "the city-life folder survives actors coming and going")
	T.act(a, "leaveInterior")
	H.task.wait(2.5)
	H.check(H.workspace:FindFirstChild("InteriorLife") == nil and cc.InteriorLife.stats.customers == 0, "leaving removes all of them (nothing runs while you're outside)")

	H.section("Ownership: nobody else's business, nobody else's interior")
	local carl = T.join("Carl", 303)
	local dc = T.newGame(carl, 1, 3)
	dc.cash, dc.tut = 1e9, 0
	T.act(carl, "enterBiz", "pizza")
	H.check(carl:GetAttribute("Interior") == nil, "you can only use \"Go inside\" for your own open businesses")
	local before = d.interiors.coffee.wall
	T.act(carl, "decor", "wall", nil, "navy")
	H.check(d.interiors.coffee.wall == before and (dc.interiors.coffee == nil or dc.interiors.coffee.wall ~= "navy"), "decorating outside your own room does nothing")
	local v0c = d.viral.score
	F.viralMoment(carl, "eviction", {tenant = "X", item = "y", force = true})
	H.check(d.viral.score == v0c, "another player's viral moment never touches yours")

	T.assertClean("v9")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
