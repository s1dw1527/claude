-- SOCIAL: CityBuzz (posts, likes, followers) + the phone's Messages inbox.
return function(C)
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local BIZ, BUSINESSES, HOOD, REP_TIERS, fmt, notify = C.BIZ, C.BUSINESSES, C.HOOD, C.REP_TIERS, C.fmt, C.notify

local FEED, likedBy = {}, {}
local nextId = 0
C.FEED = FEED
local REACTIONS = {fire = true, laugh = true, wow = true}
local function send(post)
	return {id = post.id, icon = post.icon, text = post.text, color = post.color, author = post.author, authorId = post.authorId, likes = post.likes, t = post.t,
		achievement = post.achievement, card = post.card, views = post.views or 0, reactions = post.reactions, empire = post.empire}
end
function F.buzz(icon, text, color, author, authorPlr, achievement, card)
	nextId += 1
	local post = {id = nextId, icon = icon, text = text, color = color or RGB(255, 255, 255), author = author or "CityBuzz", authorId = authorPlr and authorPlr.UserId or 0, likes = 0, t = os.time(),
		achievement = achievement == true, card = card, views = 0, viewedBy = {}, reactions = {fire = 0, laugh = 0, wow = 0}, reactedBy = {},
		empire = authorPlr and (authorPlr.Name .. "'s Empire") or nil}
	table.insert(FEED, 1, post)
	likedBy[post.id] = {}
	while #FEED > 40 do
		local old = table.remove(FEED)
		likedBy[old.id] = nil
	end
	R.Buzz:FireAllClients(send(post))
	return post
end
local function broadcastCounts(post)
	R.BuzzUpdate:FireAllClients(post.id, post.likes, post.reactions, post.views)
end
-- reading the feed counts as one view per player per post (never your own)
function F.feedList(plr)
	local out = {}
	for i, p in ipairs(FEED) do
		if plr and p.authorId ~= 0 and p.authorId ~= plr.UserId and not p.viewedBy[plr.UserId] and i <= 25 then
			p.viewedBy[plr.UserId] = true
			p.views += 1
		end
		out[i] = send(p)
	end
	return out
end
-- reactions: one of each per player per post, never on your own post
function F.react(plr, id, kind)
	if not REACTIONS[kind] then return end
	for _, p in ipairs(FEED) do
		if p.id == id then
			if p.authorId == plr.UserId then return end
			local mine = p.reactedBy[plr.UserId] or {}
			p.reactedBy[plr.UserId] = mine
			if mine[kind] then return end
			mine[kind] = true
			p.reactions[kind] += 1
			broadcastCounts(p)
			return
		end
	end
end
-- popular posts pay off: likes from real players count 5x. Trending = +25% customers, viral = +50% and new followers.
local function checkPopular(post)
	local author = post.authorId ~= 0 and Players:GetPlayerByUserId(post.authorId)
	local d = author and data[author]
	if not d then return end
	local score = (post.playerLikes or 0) * 5 + (post.likes - (post.playerLikes or 0))
	local now = os.clock()
	local level = score >= 40 and 2 or (score >= 15 and 1 or 0)
	if level <= (post.paidLevel or 0) or now < (d.postBuffCooldown or 0) then return end
	post.paidLevel = level
	d.postBuffCooldown = now + 240
	local mult = level == 2 and 1.5 or 1.25
	if (d.postBuffUntil or 0) > now then mult = math.max(mult, d.postBuffMult or 1) end
	d.postBuffUntil, d.postBuffMult = now + 120, mult
	if level == 2 then
		d.followers += 50
		notify(author, "🔥 Your CityBuzz post went VIRAL! +50% customers for 2 minutes and +50 followers.")
		F.buzz("🔥", author.Name .. "'s post is blowing up on CityBuzz!", RGB(255, 110, 200))
	else
		notify(author, "📈 Your CityBuzz post is trending! +25% customers for 2 minutes.")
	end
end
local function addLike(post, fromUserId)
	post.likes += 1
	post.playerLikes = (post.playerLikes or 0) + 1
	broadcastCounts(post)
	local author = post.authorId ~= 0 and Players:GetPlayerByUserId(post.authorId)
	local d = author and data[author]
	if d and author.UserId ~= fromUserId then
		d.followers += 1
	end
	checkPopular(post)
end
-- the city reacts to a player's post: NPC likes roll in over the next 20 seconds
local function rollLikes(plr, post, bonus)
	local d = data[plr]
	if not d then return end
	local total = math.random(2, 6) + math.floor(math.sqrt(d.followers + d.rep / 10) * 0.8) + (bonus or 0)
	for _ = 1, math.min(total, 60) do
		task.delay(math.random() * 20, function()
			if likedBy[post.id] then
				post.likes += 1
				if math.random() < 0.6 then post.views += math.random(1, 3) end   -- NPC readers
				broadcastCounts(post)
				if math.random() < 0.35 and data[plr] then data[plr].followers += 1 end
				checkPopular(post)
			end
		end)
	end
end
function F.like(plr, id)
	for _, p in ipairs(FEED) do
		if p.id == id then
			local lb = likedBy[id]
			-- you can't like your own post
			if lb and not lb[plr.UserId] and p.authorId ~= plr.UserId then
				lb[plr.UserId] = true
				addLike(p, plr.UserId)
			end
			return
		end
	end
end

-- player posts: presets built from their empire, or custom text (filtered by Roblox)
local PRESETS = {
	function(plr, d)
		local best, bl = nil, 0
		for _, b in ipairs(BUSINESSES) do
			if (d.levels[b.key] or 0) > bl then best, bl = b, d.levels[b.key] end
		end
		return best and ("Come visit my " .. best.tiers[C.stageOf(bl, d.chains[best.key] or 0)] .. "! " .. best.icon .. "🎉") or "Just opened my first business! 🍋"
	end,
	function(plr, d) return "Just hit " .. REP_TIERS[F.tierIndex(d.rep)].name .. " reputation! ⭐" end,
	function(plr, d) return "My empire makes $" .. fmt(F.incomePerSec(d)) .. "/s now 📈" end,
	function(plr, d) return "Anyone want to race me at the Raceway? 🏁" end,
	function(plr, d)
		local h = F.homeHood(d)
		return h and ("Chilling at my place in " .. HOOD[h].name .. " " .. HOOD[h].icon) or "House hunting... any tips? 🏠"
	end,
	function(plr, d) return "Hiring! Looking for the best staff in the city 🧑‍🍳" end,
	function(plr, d) return "Who's coming to the Fun Park? 🎡" end,
}
C.PRESET_COUNT = #PRESETS
-- what a post can show off, built from the player's REAL data on the server (the client only picks which one)
local function bestBusiness(d)
	local best, bl = nil, 0
	for _, b in ipairs(BUSINESSES) do
		if (d.levels[b.key] or 0) > bl then best, bl = b, d.levels[b.key] end
	end
	return best, bl
end
local ATTACH = {
	business = function(plr, d)
		local b, lvl = bestBusiness(d)
		if not b then return nil end
		local stars = d.revN > 0 and d.revSum / d.revN or 0
		return {kind = "business", icon = b.icon, title = b.tiers[C.stageOf(lvl, d.chains[b.key] or 0)], sub = "Level " .. lvl .. "  •  " .. string.format("%.1f", stars) .. "★ from " .. d.revN .. " reviews", stars = stars}
	end,
	house = function(plr, d)
		local lot = F.homeLot(d)
		if not (lot and d.home) then return nil end
		local hood = HOOD[lot.hood]
		local n = d.homeRatingN or 0
		local avg = n > 0 and (d.homeRatingSum or 0) / n or 0
		return {kind = "house", icon = hood.icon, title = plr.Name .. "'s House", sub = hood.name .. "  •  " .. (C.HOME_LEVELS[d.home.level] or "Lot") ..
			(n > 0 and ("  •  " .. string.format("%.1f", avg) .. "★ (" .. n .. " ratings)") or ""), stars = avg}
	end,
	car = function(plr, d)
		local best
		for _, c in ipairs(C.CARS) do
			if d.cars[c.key] or (c.pass and d.passes[c.pass]) then best = c end
		end
		if not best then return nil end
		return {kind = "car", icon = "🚗", title = best.name, sub = "Top speed " .. best.speed .. " • parked at " .. plr.Name .. "'s empire"}
	end,
	empire = function(plr, d)
		local n = 0
		for _, b in ipairs(BUSINESSES) do if (d.levels[b.key] or 0) > 0 then n += 1 end end
		return {kind = "empire", icon = "👑", title = plr.Name .. "'s Empire", sub = "$" .. fmt(F.incomePerSec(d)) .. "/s  •  " .. n .. " businesses  •  " .. REP_TIERS[F.tierIndex(d.rep)].name}
	end,
	-- a Photo Mode shot: what's near the player when they post it (the server checks, the client can't make it up)
	photo = function(plr, d)
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not root then return nil end
		local pos = root.Position
		local best, bestD = "the city", 150
		local function near(name, p)
			local dist = (Vector3.new(p.X, pos.Y, p.Z) - pos).Magnitude
			if dist < bestD then best, bestD = name, dist end
		end
		local b = bestBusiness(d)
		if b then near("my " .. b.tiers[C.stageOf(d.levels[b.key], d.chains[b.key] or 0)], d.plot.center) end
		local lot = F.homeLot(d)
		if lot then near("my house", lot.pos) end
		near("the Empire Spire", Vector3.new(0, 0, 0))
		if C.MUSEUM_AT then near("the Legacy Museum", C.MUSEUM_AT) end
		near("the Race Track", Vector3.new(0, 0, -360))
		near("the Fun Park", Vector3.new(-470, 0, 12))
		near("the beach", Vector3.new(0, 0, 360))
		return {kind = "photo", icon = "📸", title = "Photo at " .. best, sub = os.date("!%b %d") .. "  •  #CornerEmpire"}
	end,
}
C.POST_ATTACH = ATTACH
local postCool = {}
function F.playerPost(plr, preset, text, attach)
	local d = data[plr]
	if not d then return end
	if postCool[plr] and os.clock() < postCool[plr] then
		notify(plr, "📱 Slow down! You can post again in " .. math.ceil(postCool[plr] - os.clock()) .. "s")
		return
	end
	local body
	local card = (type(attach) == "string" and ATTACH[attach]) and ATTACH[attach](plr, d) or nil
	if type(attach) == "string" and ATTACH[attach] and not card then
		notify(plr, "📱 Nothing to show for that yet!")
		return
	end
	if type(preset) == "number" and PRESETS[preset] then
		body = PRESETS[preset](plr, d)
	elseif type(text) == "string" and #text:gsub("%s", "") == 0 and card then
		body = ""   -- a picture is worth a thousand words
	elseif type(text) == "string" then
		text = string.sub(text, 1, 120)
		if #text:gsub("%s", "") == 0 then return end
		local ok, res = pcall(function()
			local r = TextService:FilterStringAsync(text, plr.UserId)
			return r:GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			notify(plr, "📱 Couldn't post right now. Try again!")
			return
		end
		body = res
	else
		return
	end
	postCool[plr] = os.clock() + 20
	local post = F.buzz(card and card.icon or "💬", body, d.plot.color, plr.Name, plr, nil, card)
	rollLikes(plr, post)
	F.tutorialEvent(plr, "post")
end

-- ===== ACHIEVEMENTS: unlocked once per save, shareable once on CityBuzz =====
function F.achieve(plr, key)
	if not key then return end
	local d = data[plr]
	local a = C.ACHIEVEMENTS[key]
	if not d or not a then return end
	d.achievements = d.achievements or {}
	if d.achievements[key] then return end
	d.achievements[key] = os.time()
	if not a.quiet then R.Menu:FireClient(plr, "achievement", {key = key, icon = a.icon, title = a.title}) end
	if F.refreshMuseum then F.refreshMuseum(plr) end
end
function F.shareAchievement(plr, key)
	local d = data[plr]
	local a = C.ACHIEVEMENTS[key]
	if not (d and a and d.achievements and d.achievements[key]) then return end
	d.shared = d.shared or {}
	if d.shared[key] then
		notify(plr, "📱 You already shared that one!")
		return
	end
	if postCool[plr] and os.clock() < postCool[plr] - 15 then
		notify(plr, "📱 Slow down! Try again in a few seconds.")
		return
	end
	d.shared[key] = true
	postCool[plr] = os.clock() + 5
	local post = F.buzz("🏆", a.post, d.plot.color, plr.Name, plr, true)
	rollLikes(plr, post, 4)
	notify(plr, "📱 Shared on CityBuzz: " .. a.title)
end
-- money milestones are checked from the main loop
function F.checkMilestones(plr, d)
	if d.earned >= 1e6 then F.achieve(plr, "million") end
	if d.earned >= 1e9 then F.achieve(plr, "billion") end
end
C.ACTIONS = C.ACTIONS or {}
function C.shareableList(d)
	local out = {}
	if not d.achievements then return out end
	for key, t in pairs(d.achievements) do
		local a = C.ACHIEVEMENTS[key]
		if a and not a.quiet and not (d.shared and d.shared[key]) then table.insert(out, {key = key, icon = a.icon, title = a.title, t = t}) end
	end
	table.sort(out, function(x, y) return x.t > y.t end)
	while #out > 8 do table.remove(out) end
	return out
end
function F.followerMult(d) return 1 + math.min(0.5, (d.followers or 0) / 2000) end
function F.clearSocial(plr) postCool[plr] = nil end

-- ===== MESSAGES INBOX =====
-- d.inbox holds this session's messages (newest first). Saved with the slot as d.mail: plain text only, the
-- important ones (story, City Hall, updates, investors) kept longest. Each player only ever sees their own.
local MAIL_KEEP_IMPORTANT, MAIL_KEEP_OTHER, INBOX_MAX = 25, 15, 50
local CATEGORY_OF = {["City Hall"] = "cityhall", ["Story Mode"] = "story", ["Realtor"] = "business", ["Corner Empire"] = "system", ["Rebirth"] = "system",
	["Save System"] = "system", ["Raceway"] = "event", ["Update Test"] = "system"}
local function msgOut(m)
	return {id = m.id, icon = m.icon, from = m.from, text = m.text, choices = (not m.resolved) and m.choices or nil, resolved = m.resolved, t = m.t,
		read = m.read == true, important = m.important == true, cat = m.cat}
end
local function unreadCount(d)
	local n = 0
	for _, m in ipairs(d.inbox) do if not m.read then n += 1 end end
	return n
end
F.unreadCount = unreadCount
function F.pushMsg(plr, msg)
	local d = data[plr]
	if not d then return end
	d.msgSeq = (d.msgSeq or 0) + 1
	msg.id = d.msgSeq
	msg.t = os.time()
	msg.from = msg.from or "City"
	msg.read = false
	msg.cat = msg.cat or CATEGORY_OF[msg.from] or (msg.kind == "tenant" and "tenant") or "business"
	table.insert(d.inbox, 1, msg)
	-- trim: drop the oldest ordinary messages first, important ones last
	while #d.inbox > INBOX_MAX do
		local drop = #d.inbox
		for i = #d.inbox, 1, -1 do
			if not d.inbox[i].important then drop = i break end
		end
		table.remove(d.inbox, drop)
	end
	R.Msg:FireClient(plr, "add", msgOut(msg), unreadCount(d))
end
function F.inboxList(d)
	local out = {}
	for i, m in ipairs(d.inbox) do out[i] = msgOut(m) end
	return out
end
function F.markRead(plr, id)
	local d = data[plr]
	if not d then return end
	for _, m in ipairs(d.inbox) do
		if id == "all" or m.id == id then m.read = true end
	end
	R.Msg:FireClient(plr, "unread", unreadCount(d))
end
-- what goes into the save: plain fields only (messages with live choices, like tenant applications, are saved as text)
function F.mailForSave(d)
	local important, other = {}, {}
	for _, m in ipairs(d.inbox) do
		local e = {id = m.id, icon = m.icon, from = m.from, text = m.text, t = m.t, read = m.read == true, important = m.important == true, cat = m.cat,
			resolved = m.resolved or (m.choices and "(this needed an answer in an earlier session)") or nil}
		if m.important then
			if #important < MAIL_KEEP_IMPORTANT then table.insert(important, e) end
		elseif #other < MAIL_KEEP_OTHER then
			table.insert(other, e)
		end
	end
	local out = {}
	for _, e in ipairs(important) do table.insert(out, e) end
	for _, e in ipairs(other) do table.insert(out, e) end
	table.sort(out, function(a, b) return (a.id or 0) > (b.id or 0) end)
	return out
end
-- loading: saved mail becomes this session's inbox
function F.restoreMail(d)
	d.inbox = {}
	if type(d.mail) ~= "table" then return end
	for _, m in ipairs(d.mail) do
		if type(m) == "table" and type(m.text) == "string" then
			table.insert(d.inbox, {id = tonumber(m.id) or 0, icon = m.icon or "💬", from = m.from or "City", text = m.text, t = tonumber(m.t) or 0,
				read = m.read == true, important = m.important == true, cat = m.cat, resolved = m.resolved})
			d.msgSeq = math.max(d.msgSeq or 0, tonumber(m.id) or 0)
		end
	end
end
function F.msgChoice(plr, id, choice)
	local d = data[plr]
	if not d or type(id) ~= "number" or type(choice) ~= "number" then return end
	for _, m in ipairs(d.inbox) do
		if m.id == id then
			if m.resolved or not m.choices or not m.choices[choice] then return end
			local result = "Done."
			if m.kind == "tenant" then result = F.tenantChoice(plr, m, choice) end
			m.resolved = result
			m.read = true
			R.Msg:FireClient(plr, "resolve", id, result, unreadCount(d))
			return
		end
	end
end
end
