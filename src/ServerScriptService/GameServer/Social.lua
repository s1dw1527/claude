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
local function send(post)
	return {id = post.id, icon = post.icon, text = post.text, color = post.color, author = post.author, authorId = post.authorId, likes = post.likes, t = post.t, achievement = post.achievement}
end
function F.buzz(icon, text, color, author, authorPlr, achievement)
	nextId += 1
	local post = {id = nextId, icon = icon, text = text, color = color or RGB(255, 255, 255), author = author or "CityBuzz", authorId = authorPlr and authorPlr.UserId or 0, likes = 0, t = os.time(),
		achievement = achievement == true}
	table.insert(FEED, 1, post)
	likedBy[post.id] = {}
	while #FEED > 40 do
		local old = table.remove(FEED)
		likedBy[old.id] = nil
	end
	R.Buzz:FireAllClients(send(post))
	return post
end
function F.feedList()
	local out = {}
	for i, p in ipairs(FEED) do out[i] = send(p) end
	return out
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
	R.BuzzUpdate:FireAllClients(post.id, post.likes)
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
				R.BuzzUpdate:FireAllClients(post.id, post.likes)
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
local postCool = {}
function F.playerPost(plr, preset, text)
	local d = data[plr]
	if not d then return end
	if postCool[plr] and os.clock() < postCool[plr] then
		notify(plr, "📱 Slow down! You can post again in " .. math.ceil(postCool[plr] - os.clock()) .. "s")
		return
	end
	local body
	if type(preset) == "number" and PRESETS[preset] then
		body = PRESETS[preset](plr, d)
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
	local post = F.buzz("💬", body, d.plot.color, plr.Name, plr)
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
local function msgOut(m)
	return {id = m.id, icon = m.icon, from = m.from, text = m.text, choices = m.choices, resolved = m.resolved, t = m.t}
end
function F.pushMsg(plr, msg)
	local d = data[plr]
	if not d then return end
	d.msgSeq = (d.msgSeq or 0) + 1
	msg.id = d.msgSeq
	msg.t = os.time()
	msg.from = msg.from or "City"
	table.insert(d.inbox, 1, msg)
	while #d.inbox > 40 do table.remove(d.inbox) end
	R.Msg:FireClient(plr, "add", msgOut(msg))
end
function F.inboxList(d)
	local out = {}
	for i, m in ipairs(d.inbox) do out[i] = msgOut(m) end
	return out
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
			R.Msg:FireClient(plr, "resolve", id, result)
			return
		end
	end
end
end
