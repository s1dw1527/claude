-- The phone apps through the real client, with Roblox's real member rules (tests/roblox_api.lua):
-- Messages, Map, Story app and CityBuzz posts. Run with: python3 tests/run.py tests/phone_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local pg = a:FindFirstChild("PlayerGui")
	local function texts(pred)
		local out = {}
		for _, x in ipairs(pg:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and pred(tostring(x.Text)) then table.insert(out, x) end
		end
		return out
	end
	local function find(text) return texts(function(t) return t == text end)[1] end
	local function findLike(pat) return texts(function(t) return t:find(pat) ~= nil end)[1] end
	local function click(btn) H.signalOf(btn, "MouseButton1Click"):Fire() H.task.wait(0.3) end
	local function calm()
		local t = H.now()
		while cc.storyCutscene() and H.now() - t < 120 do H.task.wait(0.5) end
	end
	local function visibleChain(x)
		while x and x ~= pg do
			if x.ClassName ~= "ScreenGui" and x.Visible == false then return false end
			if x.ClassName == "ScreenGui" and x.Enabled == false then return false end
			x = x.Parent
		end
		return true
	end
	H.check(#H.errors == 0, "the whole client loads with Roblox's real member rules (no 'not a valid member' errors)")
	for _, w in ipairs(H.warnings) do if w:find("module") then print("    " .. w) end end
	calm()
	d.tut = 0
	d.cash = 1e6

	H.section("Messages")
	F.pushMsg(a, {icon = "🧃", from = "Sam (Juice Maker)", cat = "staff", text = "Boss, we're almost out of supplies."})
	F.pushMsg(a, {icon = "🔓", from = "City Hall", important = true, text = "You reached LOCAL FAVORITE!"})
	H.task.wait(1.2)
	H.check(cc.unread >= 2 and T.state(a).unread == cc.unread, "unread count from the server drives the badge (" .. cc.unread .. ")")
	local badgeLabel = findLike("^%d+$")
	cc.togglePhone(true)
	cc.phoneView("messages")
	H.task.wait(0.5)
	local row
	for _, x in ipairs(texts(function(t) return t:find("Sam %(Juice Maker%)") ~= nil end)) do
		if x.Parent and x.Parent.ClassName == "TextButton" then row = x end
	end
	H.check(row ~= nil and visibleChain(row), "the inbox lists the message with its sender")
	H.check(findLike("ago$") ~= nil or findLike("just now") ~= nil, "messages show when they arrived")
	-- open it: marks it read
	local before = cc.unread
	H.check(before == F.unreadCount(d), "the badge matches the server's unread count (" .. before .. ")")
	click(row.Parent)
	H.task.wait(0.5)
	H.check(findLike("^Boss, we're almost out") ~= nil, "tapping a message opens it")
	local samRead = false
	for _, m in ipairs(d.inbox) do if m.from == "Sam (Juice Maker)" then samRead = m.read end end
	H.check(samRead and cc.unread == F.unreadCount(d), "opening a message marks it read on the server, and the badge follows (" .. cc.unread .. ")")
	click(find("‹ Inbox"))
	click(find("✓ All read"))
	H.task.wait(0.5)
	H.check(cc.unread == 0 and T.state(a).unread == 0, "Mark all read clears the badge")
	-- generated messages come by themselves, a few minutes apart
	local n0 = #d.inbox
	H.task.wait(600)
	local got = #d.inbox - n0
	H.check(got >= 1 and got <= 4, "the city texts you on its own, without spamming (" .. got .. " in 10 minutes)")
	-- important mail survives leaving and rejoining; tenant-choice objects are never saved
	F.save(a)
	H.task.wait(0.5)
	local saved = rawget(T.slotStore(), "_data")["u101_s1"]
	local hasCityHall = false
	for _, m in ipairs(saved.mail or {}) do if m.from == "City Hall" then hasCityHall = true end end
	H.check(hasCityHall, "important messages are saved with the slot")
	cc.togglePhone(false)
	T.act(a, "menuExit")
	H.task.wait(1)
	T.act(a, "menuPlay", 1)
	H.task.wait(4)
	d = T.data(a)
	local kept = false
	for _, m in ipairs(d.inbox) do if m.from == "City Hall" then kept = true end end
	H.check(kept, "...and are back in the inbox after rejoining")
	calm()
	-- another player's messages never reach Alice
	local b = T.join("Bob", 202)
	local db = T.newGame(b, 1, 2)
	local mark = #H.remoteLog
	F.pushMsg(b, {icon = "🤫", from = "Secret", text = "for Bob only"})
	H.task.wait(0.5)
	local leaked = false
	for _, e in ipairs(T.remotesSince(mark, "Msg")) do
		if e.dir == "s2all" or e.player == a then leaked = true end
	end
	H.check(not leaked, "one player's messages are never sent to another")

	H.section("Map")
	d.cash = 1e7
	d.rep = 500
	T.act(a, "propBuy", 1, "walkup")
	H.task.wait(1.5)
	cc.togglePhone(true)
	cc.phoneView("map")
	H.task.wait(1)
	H.check(find("🏪") ~= nil, "your business is on the map")
	H.check(find("🏠") ~= nil, "your home is on the map")
	H.check(findLike("^🏢  Walk%-Up") ~= nil, "your property is listed")
	H.check(findLike("Bob's Empire") ~= nil, "other players' empires are on the map")
	H.check(find("▲") ~= nil, "you are the arrow")
	local lux = findLike("Luxury Hills")
	H.check(lux ~= nil and lux.Text:find("🔒") ~= nil, "locked places say so (" .. tostring(lux and lux.Text) .. ")")
	click(lux)
	H.check(findLike("Needs EMPIRE") ~= nil, "the info card explains what unlocks it")
	click(find("📍 Mark"))
	H.check(find("✖ Unmark") ~= nil, "Mark sets a guide beam to the place")
	click(find("✕"))
	local museum = findLike("Legacy Museum")
	click(museum)
	click(find("🚀 Go"))
	H.task.wait(0.5)
	local root = a.Character.HumanoidRootPart
	H.check((root.Position - C.MUSEUM_AT).Magnitude < 90, "Go takes you there")

	H.section("Story app")
	cc.togglePhone(true)
	cc.phoneView("story")
	H.task.wait(0.5)
	H.check(find("CURRENT OBJECTIVE") ~= nil, "shows the current objective")
	H.check(find("👥 CHARACTERS") ~= nil and findLike("Roasting you live") ~= nil, "shows the characters and how they feel about you")
	H.check(find("📚 CHAPTERS") ~= nil and findLike("▶ In progress") ~= nil and findLike("🔒 Locked") ~= nil, "lists chapters: in progress / locked")
	-- finish chapter 1, then check rewards, the event pill and that replays pay nothing
	d.story.obj = {c1o1 = true, c1o2 = true, c1o3 = true}
	H.task.wait(2.5)
	T.act(a, "story", "clapback", 1)
	H.task.wait(2.5)
	H.check(d.story.ch == 2, "chapter 1 done")
	local pill = findLike("NEW STORY EVENT")
	H.check(pill ~= nil and pill.Visible, "a NEW STORY EVENT alert shows")
	calm()
	cc.togglePhone(false)
	click(pill)
	H.task.wait(0.5)
	H.check(cc.phoneOpen() and findLike("REWARDS COLLECTED") ~= nil and findLike("^Ch 1") ~= nil, "tapping it opens the Story app, with the collected reward listed")
	H.check(findLike("▶ Ending") ~= nil and findLike("✅ Complete") ~= nil, "finished chapters are marked Complete and their ending can be replayed")
	local c0, ch0 = d.cash, d.story.ch
	local m2 = #H.remoteLog
	T.act(a, "story", "replay", 1, "ending")
	T.act(a, "story", "replay", 1)
	H.task.wait(1)
	local scenes = 0
	for _, e in ipairs(T.remotesSince(m2, "Story", a)) do if e.args[1].kind == "cutscene" then scenes += 1 end end
	H.check(scenes == 2 and d.story.ch == ch0 and d.cash - c0 < F.incomePerSec(d) * 3 + 1, "replaying the intro and ending plays them, pays nothing and changes no progress")
	T.act(a, "story", "replay", 3, "ending")
	H.task.wait(0.5)
	local scenes2 = 0
	for _, e in ipairs(T.remotesSince(m2, "Story", a)) do if e.args[1].kind == "cutscene" then scenes2 += 1 end end
	H.check(scenes2 == 2, "you can't replay the ending of a chapter you haven't finished")
	calm()

	H.section("CityBuzz posts")
	T.act(a, "buy", "lemonade")
	cc.togglePhone(true)
	cc.phoneView("buzz")
	H.task.wait(0.5)
	local box
	for _, x in ipairs(pg:GetDescendants()) do if x.ClassName == "TextBox" then box = x end end
	box.Text = "Grand opening today!"
	local chip
	for _, x in ipairs(texts(function(t) return t == "🏪 Business" end)) do
		if x.TextSize == 9 then chip = x end   -- the composer's attach chip (Photo Mode has a button with the same text)
	end
	click(chip)
	local m0 = #H.remoteLog
	click(find("Post"))
	H.task.wait(1)
	for _, t in ipairs(T.announcesSince(m0, a)) do print("    notify: " .. tostring(t)) end
	local post = C.FEED[1]
	H.check(post and post.author == "Alice" and post.text == "Grand opening today!" and post.card and post.card.kind == "business", "a text post with a business card goes up")
	H.check(findLike("Grand opening today") ~= nil, "it shows in Alice's own feed right away (the live feed listener works)")
	H.check(post.card.title:find("Lemonade") ~= nil, "the card is built from the real business: " .. tostring(post.card.title))
	-- Bob reacts, likes and views; Alice can't react to herself
	T.act(b, "react", post.id, "fire")
	T.act(b, "react", post.id, "fire")
	T.act(b, "like", post.id)
	T.act(a, "react", post.id, "wow")
	local feed = F.feedList(b)
	H.check(post.reactions.fire == 1 and post.reactions.wow == 0, "one reaction per player per kind, none on your own post")
	H.check(post.views >= 1, "views are counted (" .. post.views .. ")")
	-- spam protection
	box.Text = "spam"
	click(find("Post"))
	H.task.wait(0.5)
	H.check(C.FEED[1].id == post.id, "a second post right away is blocked by the cooldown")
	-- photo mode posts a photo card
	d.story = d.story
	H.task.wait(21)
	cc.setPhoto(true)
	H.task.wait(0.5)
	click(findLike("Post to CityBuzz"))
	H.task.wait(0.5)
	click(find("Post"))
	H.task.wait(1)
	H.check(C.FEED[1].card and C.FEED[1].card.kind == "photo" and C.FEED[1].card.title:find("^Photo at") ~= nil, "Photo Mode → Post to CityBuzz makes a photo card: " .. tostring(C.FEED[1].card and C.FEED[1].card.title))
	click(find("🔥 Trending"))
	H.check(findLike("Grand opening today") ~= nil, "the Trending tab shows popular player posts")
	local _ = feed

	T.assertClean("phone apps")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
