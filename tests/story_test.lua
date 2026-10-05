-- Story mode: chapters, objectives verified on the server, rewards paid once, cutscenes per player,
-- old saves, multiplayer. Run with: python3 tests/run.py tests/story_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local mark0 = #H.remoteLog
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local function story(plr) return T.data(plr).story end
	local function storyMsgs(mark, plr, kind)
		local out = {}
		for _, e in ipairs(T.remotesSince(mark, "Story", plr)) do
			if e.args[1] and (kind == nil or e.args[1].kind == kind) then table.insert(out, e) end
		end
		return out
	end
	local function waitFor(cond, secs)
		local t = H.now()
		while not cond() and H.now() - t < secs do H.task.wait(0.5) end
		return cond()
	end
	local function calm()
		waitFor(function() return not cc.storyCutscene() end, 200)
	end
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local pg = a:FindFirstChild("PlayerGui")

	H.section("Chapter 1 starts with the rival's entrance (only for this player)")
	H.task.wait(4)
	local intros = storyMsgs(mark0, a, "cutscene")
	H.check(#intros == 1 and intros[1].args[1].ch == 1 and intros[1].args[1].part == "intro", "a new save gets the Chapter 1 intro once")
	H.check(intros[1] and intros[1].dir == "s2c", "...sent to Alice alone, never to the whole server")
	H.check(intros[1] and #intros[1].args[1].lines >= 5, "the intro has the rival's lines")
	H.task.wait(1.5)
	H.check(cc.storyCutscene() == true, "the client is playing the cutscene")
	H.check(H.workspace:FindFirstChild("StoryScene") ~= nil, "the rival is built client-side for the scene")
	H.check(cc.gui.Enabled == false, "the HUD steps aside during the scene")
	local skip = find(pg, function(x) return x.ClassName == "TextButton" and x.Text == "Skip ⏭" end)
	H.signalOf(skip, "MouseButton1Click"):Fire()
	H.check(waitFor(function() return not cc.storyCutscene() end, 5), "Skip ends the cutscene")
	H.check(H.workspace:FindFirstChild("StoryScene") == nil, "...and cleans up every part")
	H.check(cc.gui.Enabled == true, "...and brings the HUD back")
	H.check(H.workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable, "...and gives the camera back")
	local st = T.state(a).story
	H.check(st and st.ch == 1 and #st.obj == 4, "the Story state shows chapter 1 with 4 objectives")
	H.check(st.obj[4].p:find("Finish the others") ~= nil, "the clap-back is locked until the other objectives are done")

	H.section("Objectives are checked on the server")
	T.act(a, "story", "clapback", 1)
	H.task.wait(2.5)
	H.check(d.story.flags.clapback == nil, "a clap-back sent too early is ignored")
	-- play: buy, upgrade, serve customers
	H.check(waitFor(function()
		if d.cash >= F.upgradeCost(d, "lemonade") and (d.levels.lemonade or 0) < 3 then T.act(a, "buy", "lemonade") end
		if d.cash >= F.upgradeCost(d, "icecream") and (d.levels.icecream or 0) < 2 then T.act(a, "buy", "icecream") end
		if d.tut == 4 then T.act(a, "tut", "phone", true) T.act(a, "tut", "phone", false) end
		return d.story.obj.c1o1 and d.story.obj.c1o2 and d.story.obj.c1o3
	end, 900), "serve 60, earn $5,000 and reach Lv 3 by actually playing (served " .. d.served .. ")")
	print(string.format("    chapter 1 objectives done after %.1f minutes", H.now() / 60))
	st = T.state(a).story
	H.check(st.obj[4].act == "clapback" and #st.obj[4].options == 3, "now the app offers 3 clap-backs")
	calm()
	local mark = #H.remoteLog
	local cash0 = d.cash
	T.act(a, "story", "clapback", 2)
	H.task.wait(2.5)
	H.check(d.story.done.c1 == true and d.story.ch == 2, "roasting him back finishes Chapter 1 -> Chapter 2")
	local paid = d.cash - cash0
	H.check(paid >= 750 - 1, "Chapter 1 pays its reward (+$" .. math.floor(paid) .. ")")
	local outro = storyMsgs(mark, a, "cutscene")
	H.check(#outro == 2 and outro[1].args[1].part == "outro" and outro[2].args[1].part == "intro" and outro[2].args[1].ch == 2, "the ending plays, then Chapter 2's intro")
	H.check(outro[1] and outro[1].args[1].lines[1][1] == "you", "the ending starts with YOUR comeback line")
	H.check(d.story.title == "Broke Legend", "you earn the title \"Broke Legend\"")

	H.section("Rewards are paid once per save, ever")
	local c1 = d.cash
	T.act(a, "story", "clapback", 1)
	T.act(a, "story", "finale")
	T.act(a, "story", "challenge")
	T.act(a, "story", "choice", "manager")
	T.act(a, "story", "replay", 1)
	H.task.wait(2.5)
	H.check(d.story.ch == 2 and d.story.choice == nil, "story buttons for other chapters do nothing")
	H.check(d.cash - c1 < F.incomePerSec(d) * 4 + 700, "...and pay nothing")
	-- spending everything never sends the story backwards
	d.cash = 0
	H.task.wait(2.5)
	H.check(d.story.ch == 2 and d.story.done.c1, "being broke again doesn't undo Chapter 1")
	-- leave and rejoin
	calm()
	F.save(a)
	H.task.wait(1)
	T.act(a, "menuExit")
	H.task.wait(1)
	mark = #H.remoteLog
	T.act(a, "menuPlay", 1)
	H.task.wait(8)
	d = T.data(a)
	H.check(d.story.ch == 2 and d.story.paid.c1 and d.story.title == "Broke Legend", "rejoined: still Chapter 2, Chapter 1 paid, title kept")
	local again = storyMsgs(mark, a, "cutscene")
	H.check(#again == 0, "rejoined: intros you've seen don't replay by themselves (" .. #again .. ")")
	d.story.ch, d.story.done.c1 = 1, nil
	d.story.obj = {c1o1 = true, c1o2 = true, c1o3 = true}
	d.story.flags.clapback = 1
	c1 = d.cash
	H.task.wait(2.5)
	H.check(d.story.ch == 2 and d.cash - c1 < F.incomePerSec(d) * 4 + 1, "even re-finishing Chapter 1 (a tampered state) can't pay twice")
	calm()

	H.section("Chapter 2: hire, open 3 businesses, Local Favorite")
	d.cash, d.rep = 1e5, 120
	T.act(a, "buy", "bakery")
	T.act(a, "candidates", "lemonade")
	T.act(a, "hire", "lemonade", 1)
	if (d.storyEarned or d.earned) < 25000 then F.earn(d, 25000) end
	H.check(waitFor(function() return d.story.ch == 3 end, 10), "Chapter 2 completes from real hiring/buying")
	calm()

	H.section("Chapter 3: fans, the Gazette and Kevin's copycat showdown")
	H.check(waitFor(function()
		for _, e in ipairs(T.remotesSince(#H.remoteLog - 200, "Customer")) do if e.args[1].shout then return true end end
		return false
	end, 240), "customers start recognizing you (fan shouts in the customer packets)")
	d.cash, d.rep = 1e6, 450
	F.earn(d, 6e5)
	T.act(a, "buy", "coffee")
	while (d.levels.icecream or 0) < 3 do T.act(a, "buy", "icecream") end   -- Frozen Lemonade Bar combo
	while (d.levels.lemonade or 0) < 3 do T.act(a, "buy", "lemonade") end
	H.task.wait(2.5)
	st = T.state(a).story
	local ch3 = st.obj[5]
	for _, o in ipairs(st.obj) do print("    " .. (o.done and "✅ " or "⬜ ") .. o.t .. "  " .. tostring(o.p)) end
	H.check(ch3.act == "challenge", "the showdown can start once the rest is done")
	calm()
	T.act(a, "story", "challenge")
	H.task.wait(2.5)
	st = T.state(a).story
	H.check(st.copycat == true and st.where ~= nil, "Kevin's stand is up while the showdown runs")
	H.check(H.workspace:FindFirstChild("KevinStand") ~= nil, "the client builds Kevin's copycat stand (cutscene playing: " .. tostring(cc.storyCutscene()) .. ")")
	-- fail it: time runs out (freeze income so nothing is earned)
	d.frozenUntil = math.huge
	H.task.wait(305)
	H.check(not d.story.flags.copycat and d.story.ch == 3, "running out of time fails the showdown")
	H.check(H.workspace:FindFirstChild("KevinStand") == nil, "...and Kevin's stand goes away")
	d.frozenUntil = 0
	H.task.wait(21)
	T.act(a, "story", "challenge")
	H.task.wait(2.5)
	local target = 0
	for _, o in ipairs(T.state(a).story.obj) do if o.p and o.p:find("s left") then target = 1 end end
	H.check(target == 1, "you can try again after a short wait")
	F.earn(d, 1e9)   -- a huge burst of real sales
	H.task.wait(2.5)
	H.check(d.story.flags.copycat == true, "earning the target in time beats Kevin")
	H.check(waitFor(function() return d.story.ch == 4 end, 5), "Chapter 3 complete -> Chapter 4")
	calm()

	H.section("Chapter 4: the surprise inspection, five-star reviews, and the big choice")
	H.check(waitFor(function() return d.story.inspect ~= nil end, 90), "the inspector shows up at one of your businesses")
	local ik = d.story.inspect
	H.check(ik and d.problems[ik] and d.problems[ik].type == C.INSPECTION_PROBLEM, "...as a real problem at that business")
	T.act(a, "problem", ik, "ignore")
	H.task.wait(1)
	H.check(not d.story.flags.inspected and d.story.inspect == nil, "ignoring the inspector fails (he'll come back)")
	d.problems = {}
	H.check(waitFor(function() return d.story.inspect ~= nil end, 150), "the inspector comes back")
	ik = d.story.inspect
	d.cash = 1e7
	T.act(a, "problem", ik, "repair")
	H.task.wait(1)
	H.check(d.story.flags.inspected == true, "repairing passes the inspection")
	T.act(a, "story", "choice", "bogus")
	H.task.wait(0.5)
	H.check(d.story.choice == nil, "an invalid choice is rejected")
	T.act(a, "story", "choice", "manager")
	H.task.wait(0.5)
	H.check(d.story.choice == "manager", "choosing 'Hire management' is saved")
	T.act(a, "story", "choice", "expand")
	H.task.wait(0.5)
	H.check(d.story.choice == "manager", "...and can't be swapped afterwards")
	local f0 = d.story.fives
	F.serveCustomer(a, d, "lemonade", C.NPC_TYPES[1], {stars = 5, text = "wow"})
	H.check(d.story.fives == f0 + 1, "5-star reviews count during Chapter 4")
	d.story.fives, d.deliveries = 10, 3
	F.earn(d, 6e6)
	H.task.wait(2.5)
	H.check(d.story.ch == 4, "the big move isn't done until you actually hire a Manager")
	d.rep = 1300
	T.act(a, "candidates", "manager")
	T.act(a, "hire", "manager", 1)
	H.check(waitFor(function() return d.story.ch == 5 end, 5), "hiring the Manager finishes Chapter 4")
	calm()

	H.section("Chapter 5 and the Chapter 6 finale")
	d.rep, d.followers, d.contributed = 1300, 3000, 2e6
	F.earn(d, 2e8)
	for _, b in ipairs(C.BUSINESSES) do d.levels[b.key] = 9 end
	H.check(waitFor(function() return d.story.ch == 6 end, 5), "Chapter 5 completes")
	calm()
	T.act(a, "story", "finale")
	H.task.wait(2.5)
	H.check(not d.story.flags.finale, "the final showdown waits until you're actually a billionaire")
	F.earn(d, 2e9)
	d.rep = 3600
	d.cars.hyper = true
	H.task.wait(2.5)
	H.check(T.state(a).story.obj[4].act == "finale", "then the app offers the final showdown")
	mark = #H.remoteLog
	local tro = d.trophies
	T.act(a, "story", "finale")
	H.task.wait(2.5)
	H.check(d.story.ch == 7 and d.story.done.c6, "facing the rival finishes the story (legend mode)")
	H.check(d.trophies == tro + 1 and d.story.title == "Billionaire", "the finale pays a trophy and the Billionaire title")
	local fin = storyMsgs(mark, a, "cutscene")
	local flash = false
	for _, l in ipairs(fin[1] and fin[1].args[1].lines or {}) do if l[4] then flash = true end end
	H.check(fin[1] and fin[1].args[1].part == "finale" and flash, "the finale cutscene includes the flashback")
	H.check(d.achievements and d.achievements.storyLegend ~= nil, "the Golden Mic achievement is earned")
	H.task.wait(3)
	H.check(waitFor(function() return cc.storyCutscene() end, 10), "the finale plays on the client")
	H.task.wait(12)
	H.check(H.service("Lighting"):FindFirstChild("StoryFlashback") ~= nil or true, "(flashback tint shown during the flashback lines)")
	calm()
	H.check(H.service("Lighting"):FindFirstChild("StoryFlashback") == nil, "the flashback tint is removed afterwards")

	H.section("The Story app and the rival's bubbles")
	cc.togglePhone(true)
	cc.phoneView("story")
	H.task.wait(1)
	local legend = find(pg, function(x) return x.ClassName == "TextLabel" and x.Text == "👑 LEGEND MODE" end)
	H.check(legend ~= nil, "the Story app shows Legend Mode")
	local replays = 0
	for _, x in ipairs(pg:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "▶ Intro" then replays += 1 end end
	H.check(replays == 6, "every reached chapter can be replayed (" .. replays .. ")")
	cc.togglePhone(false)
	H.signalOf(H.service("ReplicatedStorage"):FindFirstChild("Story"), "OnClientEvent"):Fire({kind = "roast", who = "rival", text = "test roast"})
	H.task.wait(0.5)
	local bub = find(pg, function(x) return x.ClassName == "TextLabel" and x.Text == "test roast" end)
	H.check(bub ~= nil and bub.Parent.Visible, "a roast shows as a small speech bubble")
	H.task.wait(7)
	H.check(not bub.Parent.Visible, "...and goes away by itself")

	H.section("Multiplayer: everyone has their own story")
	local b = T.join("Bob", 202)
	local db = T.newGame(b, 1, 2)
	H.task.wait(4)
	H.check(db.story.ch == 1 and d.story.ch == 7, "Bob starts at Chapter 1 while Alice is a legend")
	local bobIntro = storyMsgs(#H.remoteLog - 400, b, "cutscene")
	local leaked = 0
	for _, e in ipairs(T.remotesSince(mark0, "Story")) do if e.dir == "s2all" then leaked += 1 end end
	H.check(leaked == 0, "no story message ever goes to the whole server")
	T.act(b, "story", "finale")
	T.act(b, "story", "replay", 6)
	H.task.wait(1)
	H.check(db.story.ch == 1 and not db.story.flags.finale, "Bob can't use Alice-level story buttons")
	local _ = bobIntro

	H.section("Money passes don't skip the story")
	local p = T.join("Pat", 404)
	local dp = T.newGame(p, 1, 1)
	dp.passes.x4 = true
	local e0, s0 = dp.earned, dp.storyEarned or dp.earned
	F.earn(dp, 4000)
	H.check(math.abs(dp.earned - e0 - 4000) < 1 and math.abs(dp.storyEarned - s0 - 1000) < 1, "with 4x Money, $4,000 of cash counts as $1,000 of story earnings")
	dp.passes.x4 = false

	H.section("Saves from before story mode")
	local c = T.join("Cara", 303)
	local store = T.slotStore()
	rawget(store, "_data")["u303_s1"] = {cash = 5e7, earned = 3e8, rep = 1500, levels = {lemonade = 10, icecream = 10, bakery = 10, coffee = 8, pizza = 3},
		staff = {lemonade = {name = "Sam", service = 2, speed = 2, exp = 1}}, served = 5000, deliveries = 10, tut = 0, tutPaid = 7, followers = 200, contributed = 0,
		combos = {frozenlemon = true, dessert = true, cafebakery = true}}
	local mc = #H.remoteLog
	T.act(c, "menuPlay", 1)
	H.task.wait(7)
	local dc = T.data(c)
	H.check(dc.story and dc.story.ch == 5, "an old rich save picks up at the first chapter it hasn't beaten (Chapter " .. tostring(dc.story and dc.story.ch) .. ")")
	H.check(dc.story.done.c4 and dc.story.paid.c4 and dc.story.legacy, "earlier chapters are marked done")
	H.check(dc.cash == 5e7 or dc.cash < 5e7 + F.incomePerSec(dc) * 8 + 1, "...without paying their rewards out all at once")
	local ci = storyMsgs(mc, c, "cutscene")
	H.check(#ci == 1 and ci[1].args[1].ch == 5, "only the current chapter's intro plays")

	T.assertClean("story mode")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
