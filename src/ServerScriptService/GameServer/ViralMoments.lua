-- VIRAL MOMENTS: the city notices what players actually do and turns it into a moment.
--
--   something happens (an eviction, a grand opening, a crash into your own bakery, a 1-star review...)
--     -> F.viralMoment(plr, key, ctx)
--     -> checks: per-player cooldown, "only once" uniqueness, chance
--     -> Viral Score (+ this week's score per category), the player's moment log (saved, d.viral)
--     -> maybe a CityBuzz post (a server-wide gap per importance stops feed spam)
--     -> the player gets a "VIRAL MOMENT" pop-up with a 📸 capture button; Lil Clipz may react
--
-- Viral Score can't be farmed: every moment has a cooldown, many count only once per save (or per business),
-- and it never pays cash. Weekly "Most Viral" boards reset each week; top-3 finishes are kept forever (d.viral.hall).
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local RGB = Color3.fromRGB
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

-- ===== tuning =====
C.VIRAL = {
	rushWindow = 60, rushCount = 100,          -- "WHO TOLD EVERYONE?": customers served across your empire in a minute
	crowdWindow = 30, crowdCount = 25,         -- "WHO INVITED EVERYONE?": customers at ONE business in 30 seconds
	feedGap = {low = 90, normal = 40, high = 15, legendary = 0},   -- seconds between automatic CityBuzz posts, server-wide
	famousAt = {1000, 5000, 25000},             -- Viral Score milestones that make the whole city recognize you for a while
	influencerScore = 10000,                    -- "Empire Influencer" achievement
	clipzGap = 900,                             -- Lil Clipz reacts at most every 15 minutes
}
local V = C.VIRAL

-- {name}, {biz}, {thing}, {car}, {tenant}, {who}, {stars}... are filled from the moment's ctx
-- cat: which weekly board it counts for (biz, house, car, funny, interior, empire); score per the v9 table
C.VIRAL_MOMENTS = {
	opening = {icon = "🎉", title = "Grand Opening", score = 50, cat = "biz", importance = "normal", once = true,
		posts = {"🔥 New business just opened! {name}'s {biz} is OPEN.", "New {biz} in town. {name} said \"come thru\" and the whole block came thru."}},
	openingCrowd = {icon = "🍕", title = "Grand Opening Crowd", score = 100, cat = "biz", importance = "high", once = true,
		posts = {"🔥 A crowd just stormed {name}'s new {biz}. Someone yelled FREE. It was not free."}},
	eviction = {icon = "💀", title = "Bro Just Got Evicted", score = 60, cat = "funny", importance = "normal", cd = 300,
		posts = {"💀 Bro just got evicted.", "{tenant} \"just got here\". {name} disagreed.", "Breaking: {tenant}'s stuff is on the sidewalk. Including {item}."},
		clipz = {{"rival", "Bro, I saw that eviction clip.", "laugh"}, {"you", "You saw that?", "shock"}, {"rival", "THE WHOLE CITY SAW THAT.", "hype"}}},
	lostKeys = {icon = "🔑", title = "Lost The Keys", score = 40, cat = "funny", importance = "low", cd = 600,
		posts = {"CEO {name} reportedly lost the keys. (They sold the building.)"}},
	billionaireLemonade = {icon = "🍋", title = "THE BILLIONAIRE LEMONADE GUY", score = 250, cat = "funny", importance = "high", once = true, rare = true,
		posts = {"Bro owns a mansion and STILL sells lemonade. Respect? Concern? Both."},
		clipz = {{"rival", "You live in a MANSION and you're still squeezing lemons?", "shock"}, {"you", "It's called staying humble.", "owner"}, {"rival", "It's called a cry for help.", "laugh"}}},
	carCrash = {icon = "🚗", title = "War On The Parking Lot", score = 120, cat = "car", importance = "high", cd = 600,
		posts = {"Local CEO declares war on parking lot.", "Someone crashed a {car} into a {biz}. The {biz} belongs to them. 💀"},
		clipz = {{"rival", "Chat. They crashed into their OWN business.", "laugh"}, {"you", "It was a parking strategy.", "shrug"}, {"rival", "Clipped. Posted. Framed.", "hype"}}},
	terribleReview = {icon = "⭐", title = "One Star Legend", score = 40, cat = "funny", importance = "low", cd = 900, chance = 0.35,
		posts = {"Customer gives {name}'s {biz} 1 star for \"too much {thing}\".", "1 star: \"{review}\" — a customer of {name}'s {biz}"}},
	customerRush = {icon = "🏃", title = "WHO TOLD EVERYONE?", score = 250, cat = "biz", importance = "high", cd = 1800, rare = true,
		posts = {"WHO TOLD EVERYONE? {name}'s empire just served {n} customers in a minute."}},
	bizCrowd = {icon = "👥", title = "Line Around The Block", score = 100, cat = "biz", importance = "normal", cd = 1200,
		posts = {"There's a line around the block at {name}'s {biz}. Bring snacks. (They sell snacks.)"}},
	houseRating = {icon = "🏠", title = "House Rating: {rating}/100", score = 150, cat = "house", importance = "normal", cd = 604800,
		posts = {"House rating: {rating}/100. {name}'s home is officially a vibe."}},
	luxuryCar = {icon = "🏎️", title = "Big Purchase", score = 100, cat = "car", importance = "normal", cd = 300,
		posts = {"{name} just pulled up in a {car}. The street is not ready."}},
	luxuryHome = {icon = "🏰", title = "Living Large", score = 150, cat = "house", importance = "high", cd = 600,
		posts = {"{name} just moved into {home}. The neighbors are already jealous."}},
	interiorElite = {icon = "🛋️", title = "ELITE Interior", score = 100, cat = "interior", importance = "normal", once = true,
		posts = {"{name}'s {biz} interior just hit ELITE. Okay... this place actually eats."}},
	interiorViral = {icon = "💎", title = "VIRAL Interior", score = 250, cat = "interior", importance = "high", once = true, rare = true,
		posts = {"{name}'s {biz} interior is so good it went VIRAL. 100/100 vibes."}},
	influencerVisit = {icon = "🤳", title = "{who} Visited", score = 50, cat = "biz", importance = "normal", cd = 240,
		posts = {"🚨 {who} is at {name}'s {place}!"}},
	influencerPost = {icon = "📱", title = "{who} Posted About You", score = 100, cat = "biz", importance = "high", cd = 240,
		clipz = {{"rival", "{who} posted YOU? Before ME?", "shock"}, {"you", "Jealous?", "owner"}, {"rival", "...A little. Chat, don't clip that.", "facepalm"}}},
	wentViral = {icon = "🔥", title = "Went Viral", score = 250, cat = "biz", importance = "high", cd = 300},
	theCrowd = {icon = "👥", title = "THE CROWD", score = 250, cat = "biz", importance = "high", cd = 1200, rare = true,
		posts = {"👥 THE CROWD has gathered outside {name}'s {biz}. Nobody knows why. Everybody's staying."}},
	paparazzi = {icon = "📸", title = "PAPARAZZI MODE", score = 250, cat = "empire", importance = "high", cd = 1800, rare = true,
		posts = {"📸 PAPARAZZI spotted following {name}. CityBuzz is EXPLODING."}},
	everyoneKnows = {icon = "🌟", title = "EVERYONE KNOWS YOU", score = 500, cat = "empire", importance = "high", rare = true, once = true,
		posts = {"🌟 The whole city knows {name} now. \"Bro owns half the city.\""}},
	beefWon = {icon = "🥩", title = "Business Beef: WON", score = 250, cat = "biz", importance = "high", cd = 1200, rare = true,
		posts = {"🥩 {name} just WON the business beef against {rival}. That pop-up is packing up."}},
	fullSet = {icon = "🏆", title = "THE FULL SET", score = 1000, cat = "empire", importance = "legendary", rare = true, once = true,
		posts = {"🏆 LEGENDARY: all four city influencers posted about {name} in one week. THE FULL SET."}},
	funnyEvent = {icon = "😂", title = "{title}", score = 30, cat = "funny", importance = "low", cd = 300,
		posts = {"{post}"}},
	capture = {icon = "📸", title = "Captured It", score = 25, cat = "funny", importance = "low", cd = 120, quiet = true},
	competition = {icon = "🏆", title = "Champion", score = 150, cat = "empire", importance = "high", cd = 3600},
	productTrending = {icon = "🔥", title = "{product} Is Trending", score = 150, cat = "biz", importance = "high", cd = 900,
		posts = {"🔥 TRENDING: {name}'s {product} is EVERYWHERE.", "🔥 Everyone's talking about the {product} at {brand}. EVERYONE."}},
}
local MOMENTS = C.VIRAL_MOMENTS
C.VIRAL_CATS = {
	{key = "all", name = "🔥 Most Viral"}, {key = "biz", name = "🏪 Most Viral Business"}, {key = "house", name = "🏠 Most Viral House"},
	{key = "car", name = "🏎️ Most Viral Car"}, {key = "funny", name = "😂 Funniest Moments"}, {key = "interior", name = "🛋️ Best Interior"},
	{key = "empire", name = "🏙️ Biggest Empire"},
}

-- ===== helpers =====
local function fill(text, ctx)
	return (string.gsub(text, "{(%w+)}", function(k)
		local v = ctx[k]
		if v == nil then return "{" .. k .. "}" end
		return tostring(v)
	end))
end
local function viralOf(d)
	if type(d.viral) ~= "table" then d.viral = C.DataMigration.defaultViral() end
	local v = d.viral
	local week = C.weekId and C.weekId() or 0
	if v.week ~= week then
		v.week, v.weekScore, v.cats = week, 0, {}
	end
	return v
end
F.viralOf = viralOf

-- server-wide: recent moments (for everyone's Viral app) and the CityBuzz gap
local city = {}            -- newest first: {who, key, title, icon, text, cat, t, userId}
C.cityMoments = city
local lastPost = {low = -1e9, normal = -1e9, high = -1e9, legendary = -1e9}
local recent = {}          -- [plr] = {[momentId] = os.clock()}  moments that can be captured in Photo Mode
local nextMomentId = 0
local IMPORTANCE = {low = 1, normal = 2, high = 3, legendary = 4}
local lastClipz = {}

-- ===== the core =====
function F.viralMoment(plr, key, ctx)
	local d = data[plr]
	local m = MOMENTS[key]
	if not (d and m) or not plr.Parent then return nil end
	ctx = ctx or {}
	local v = viralOf(d)
	local now = os.time()
	local uniq = key .. (ctx.uniq and (":" .. tostring(ctx.uniq)) or "")
	if m.once and v.seen[uniq] then return nil end
	if m.cd and (tonumber(v.cd[key]) or 0) > now and not ctx.force then return nil end
	if m.chance and not ctx.force and math.random() > m.chance then return nil end
	-- the text for this moment
	ctx.name = ctx.name or plr.Name
	local title = fill(m.title, ctx)
	local post = m.posts and fill(m.posts[math.random(#m.posts)], ctx) or nil
	-- record it
	if m.cd then v.cd[key] = now + m.cd end
	if m.once then v.seen[uniq] = now end
	local score = m.score
	v.score += score
	v.weekScore += score
	local cat = ctx.cat or m.cat
	v.cats[cat] = (tonumber(v.cats[cat]) or 0) + score
	v.mentions += 1
	table.insert(v.log, 1, {key = key, t = now, title = title, icon = m.icon, text = post or title, score = score})
	while #v.log > 30 do table.remove(v.log) end
	table.insert(city, 1, {who = plr.Name, userId = plr.UserId, key = key, title = title, icon = m.icon, text = post or title, cat = cat, t = now, rare = m.rare == true})
	while #city > 25 do table.remove(city) end
	-- weekly boards (the score this week, overall and per category)
	local W = C.weeklyStore
	if W and not d.noSave and C.weekId then
		local week = C.weekId()
		W.add(W.board("Viral_all", week), tostring(plr.UserId), score)
		W.add(W.board("Viral_" .. cat, week), tostring(plr.UserId), score)
	end
	-- CityBuzz, unless the feed just had one of these
	local imp = m.importance or "normal"
	local clock = os.clock()
	local posted = false
	if post and clock - lastPost[imp] >= (V.feedGap[imp] or 40) then
		-- a quieter moment also waits for any louder one
		local ok = true
		for k, lvl in pairs(IMPORTANCE) do
			if lvl > IMPORTANCE[imp] and clock - lastPost[k] < 8 then ok = false end
		end
		if ok then
			lastPost[imp] = clock
			F.buzz(m.icon, post, d.plot and d.plot.color or RGB(255, 110, 200), ctx.author or "CityBuzz")
			posted = true
		end
	end
	-- tell the player (with a capture button for Photo Mode). Quiet moments (like the capture itself) don't pop up.
	nextMomentId += 1
	if not m.quiet then
		recent[plr] = recent[plr] or {}
		recent[plr][nextMomentId] = clock
		local pos = ctx.pos
		R.Viral:FireClient(plr, {kind = "moment", id = nextMomentId, key = key, title = title, icon = m.icon, text = post or title, score = score,
			total = v.score, pos = typeof(pos) == "Vector3" and pos or nil, rare = m.rare == true, legendary = imp == "legendary"})
	end
	-- achievements
	if F.achieve then
		if m.rare then F.achieve(plr, "mainCharacter") end
		if key == "influencerPost" then F.achieve(plr, "internetFamous") end
		if v.score >= V.influencerScore then F.achieve(plr, "empireInfluencer") end
	end
	-- the whole city recognizes you after big milestones
	for _, at in ipairs(V.famousAt) do
		if v.score >= at and v.score - score < at and F.everyoneKnows then
			task.defer(F.everyoneKnows, plr, at)
		end
	end
	-- Lil Clipz saw it too (now and then, and only once the story has started)
	if m.clipz and d.story and (lastClipz[plr] or -1e9) + V.clipzGap < clock and math.random() < (ctx.clipzChance or 0.4) and F.cinematic then
		lastClipz[plr] = clock
		local lines = {}
		for i, l in ipairs(m.clipz) do lines[i] = {l[1], fill(l[2], ctx), l[3]} end
		task.delay(4, function()
			if plr.Parent and data[plr] == d then
				F.cinematic(plr, "clipz", {}, {lines = lines, at = F.playerAnchor(plr), mode = "short", title = "🎙️ LIL CLIPZ SAW THAT"})
			end
		end)
	end
	return {id = nextMomentId, key = key, title = title, score = score, posted = posted}
end

-- Photo Mode capture of a moment (from the pop-up or the cinematic's 📸 button): validated, once per moment
function F.viralCapture(plr, id)
	local d = data[plr]
	local r = recent[plr]
	local at = r and r[id]
	if not (d and at) then return false end
	r[id] = nil
	if os.clock() - at > 180 then return false end
	if F.achieve then F.achieve(plr, "broGotContent") end
	F.viralMoment(plr, "capture", {})
	return true
end

-- ===== detectors that watch normal play =====
local served = {}   -- [plr] = {times = {...}, biz = {[key] = {...}}}
local function pushWindow(list, now, window)
	table.insert(list, now)
	while list[1] and now - list[1] > window do table.remove(list, 1) end
	return #list
end
function F.viralServed(plr, d, key)
	local now = os.clock()
	local s = served[plr]
	if not s then
		s = {times = {}, biz = {}}
		served[plr] = s
	end
	local n = pushWindow(s.times, now, V.rushWindow)
	if n >= V.rushCount then
		s.times = {}
		F.viralMoment(plr, "customerRush", {n = n})
	end
	s.biz[key] = s.biz[key] or {}
	local nb = pushWindow(s.biz[key], now, V.crowdWindow)
	if nb >= V.crowdCount then
		s.biz[key] = {}
		if F.achieve then F.achieve(plr, "whoInvited") end
		F.viralMoment(plr, "bizCrowd", {biz = BIZ[key].name, n = nb})
	end
end
function F.viralReview(plr, d, key, review)
	if review.stars ~= 1 then return end
	F.viralMoment(plr, "terribleReview", {biz = BIZ[key].name, thing = BIZ[key].thing, review = review.text})
end
-- checked every few seconds per player (cheap): the "billionaire lemonade" and interior tiers
function F.viralTick(plr, d)
	local lem = d.levels.lemonade or 0
	local rich = (d.home and d.home.level and d.home.level >= 4) or (d.earned or 0) >= 1e9
	if rich and lem > 0 and lem <= 4 then F.viralMoment(plr, "billionaireLemonade", {}) end
	if F.interiorScore100 then
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 then
				local sc = F.interiorScore100(d, b.key)
				if sc >= 81 then F.viralMoment(plr, "interiorElite", {uniq = b.key, biz = b.name}) end
				if sc >= 96 then F.viralMoment(plr, "interiorViral", {uniq = b.key, biz = b.name}) end
			end
		end
	end
end
-- a crash into your own business, reported by your client and checked here: you must be driving your own car
-- and actually be next to one of your businesses. (Viral Score only, never cash, and on a 10-minute cooldown.)
function F.viralCrash(plr, speed)
	local d = data[plr]
	if not d or type(speed) ~= "number" or speed < 40 or speed > 400 then return end
	local car = F.activeCar and F.activeCar(plr)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (car and seat and seat:GetAttribute("CarOwner") == plr.UserId) then return end
	local pos = seat.Position
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 then
			local door = (F.slotCF(d.plot, b.key) * CFrame.new(0, 0, 9)).Position
			if (door - pos).Magnitude < 28 then
				local spec = C.CAR[car.key]
				F.viralMoment(plr, "carCrash", {car = spec and spec.name or "car", biz = b.name, pos = pos})
				return
			end
		end
	end
end

-- ===== weekly boards (refreshed one category at a time, to stay far inside DataStore limits) =====
local boards = {}
C.viralBoards = boards
local function refreshCat(cat)
	local W = C.weeklyStore
	if not (W and C.weekId) then return end
	local list = {}
	for i, e in ipairs(W.top(W.board("Viral_" .. cat.key, C.weekId()), 5, false)) do
		list[i] = {rank = i, userId = tonumber(e.key), name = W.nameOf(e.key), value = e.value}
	end
	boards[cat.key] = list
	-- a top-3 finish is remembered forever (and earns "Actually Famous")
	for _, e in ipairs(list) do
		if e.rank <= 3 and e.value > 0 then
			local p = Players:GetPlayerByUserId(e.userId or 0)
			local d = p and data[p]
			if d then
				local v = viralOf(d)
				local tag = C.weekId() .. ":" .. cat.key
				local have = false
				for _, h in ipairs(v.hall) do if h.tag == tag then have = true if e.rank < h.rank then h.rank = e.rank end end end
				if not have then
					table.insert(v.hall, 1, {tag = tag, week = C.weekId(), cat = cat.key, name = cat.name, rank = e.rank})
					while #v.hall > 20 do table.remove(v.hall) end
				end
				if F.achieve then F.achieve(p, "actuallyFamous") end
			end
		end
	end
end
C.refreshViralBoards = function() for _, cat in ipairs(C.VIRAL_CATS) do pcall(refreshCat, cat) end end
task.spawn(function()
	local i = 0
	while true do
		task.wait(40)
		if next(data) ~= nil then
			i = i % #C.VIRAL_CATS + 1
			local ok, err = pcall(refreshCat, C.VIRAL_CATS[i])
			if not ok then warn("[CornerEmpire] viral board refresh failed: " .. tostring(err)) end
		end
	end
end)
-- best interior / biggest empire are "best value this week" boards (not sums)
function F.publishViralBests(plr, d)
	local W = C.weeklyStore
	if not (W and C.weekId) or d.noSave then return end
	local best = 0
	if F.interiorScore100 then
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 then best = math.max(best, F.interiorScore100(d, b.key)) end
		end
	end
	local week = C.weekId()
	if best > 0 then W.write(W.board("Viral_interior", week), tostring(plr.UserId), best, "max") end
	if F.empireScore then W.write(W.board("Viral_empire", week), tostring(plr.UserId), F.empireScore(d), "max") end
end

-- ===== what the Viral app shows =====
local sightings = {}       -- filled by Influencers
C.influencerSightings = sightings
function F.viralState(plr, d)
	local v = viralOf(d)
	local mine = {}
	for i = 1, math.min(10, #v.log) do
		local e = v.log[i]
		mine[i] = {icon = e.icon, title = e.title, text = e.text, score = e.score, t = e.t}
	end
	local cityList, funny = {}, {}
	for _, e in ipairs(city) do
		if #cityList < 10 then table.insert(cityList, {icon = e.icon, title = e.title, text = e.text, who = e.who, t = e.t, rare = e.rare}) end
		if e.cat == "funny" and #funny < 5 then table.insert(funny, {icon = e.icon, text = e.text, who = e.who, t = e.t}) end
	end
	local top = {}
	for _, p in ipairs(C.FEED or {}) do table.insert(top, p) end
	table.sort(top, function(x, y) return (x.likes + (x.reactions and (x.reactions.fire + x.reactions.laugh + x.reactions.wow) or 0)) > (y.likes + (y.reactions and (y.reactions.fire + y.reactions.laugh + y.reactions.wow) or 0)) end)
	local topPosts = {}
	for i = 1, math.min(3, #top) do topPosts[i] = {icon = top[i].icon, text = top[i].text, author = top[i].author, likes = top[i].likes} end
	local sight = {}
	for _, s in ipairs(sightings) do table.insert(sight, {who = s.who, name = s.name, icon = s.icon, place = s.place, target = s.targetName, t = s.t, here = s.active}) end
	local bl = {}
	for i, cat in ipairs(C.VIRAL_CATS) do bl[i] = {key = cat.key, name = cat.name, list = boards[cat.key] or {}} end
	local hall = {}
	for i = 1, math.min(6, #v.hall) do hall[i] = {name = v.hall[i].name, rank = v.hall[i].rank, week = v.hall[i].week} end
	return {score = v.score, week = v.weekScore, mentions = v.mentions, mine = mine, city = cityList, funny = funny, top = topPosts, sightings = sight,
		boards = bl, hall = hall, myId = plr.UserId}
end

-- ===== actions =====
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.viral = function(plr, d, a, b)
	if a == "capture" then
		local id = C.int(b, 1)
		if id then F.viralCapture(plr, id) end
	elseif a == "crash" then
		if C.finite(b) then F.viralCrash(plr, b) end
	end
end

Players.PlayerRemoving:Connect(function(plr)
	served[plr] = nil
	recent[plr] = nil
	lastClipz[plr] = nil
end)

-- ===== Studio tools =====
C.DEBUG = C.DEBUG or {}
C.DEBUG.viralMoment = function(plr, d)
	F.viralMoment(plr, "eviction", {tenant = "Testy McTestface", item = "a rubber duck", force = true})
end
C.DEBUG.buzzPost = function(plr, d)
	F.buzz("🧪", "Studio test post from " .. plr.Name .. ": WHO LET HIM COOK?", d.plot.color, "CityBuzz")
end
end
