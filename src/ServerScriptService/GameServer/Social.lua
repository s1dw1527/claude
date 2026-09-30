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
	return {id = post.id, icon = post.icon, text = post.text, color = post.color, author = post.author, authorId = post.authorId, likes = post.likes, t = post.t}
end
function F.buzz(icon, text, color, author, authorPlr)
	nextId += 1
	local post = {id = nextId, icon = icon, text = text, color = color or RGB(255, 255, 255), author = author or "CityBuzz", authorId = authorPlr and authorPlr.UserId or 0, likes = 0, t = os.time()}
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
local function addLike(post, fromUserId)
	post.likes += 1
	R.BuzzUpdate:FireAllClients(post.id, post.likes)
	local author = post.authorId ~= 0 and Players:GetPlayerByUserId(post.authorId)
	local d = author and data[author]
	if d and author.UserId ~= fromUserId then
		d.followers += 1
	end
end
function F.like(plr, id)
	for _, p in ipairs(FEED) do
		if p.id == id then
			local lb = likedBy[id]
			if lb and not lb[plr.UserId] then
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
	-- the city reacts: NPC likes roll in over the next 20 seconds
	local total = math.random(2, 6) + math.floor(math.sqrt(d.followers + d.rep / 10) * 0.8)
	for _ = 1, math.min(total, 60) do
		task.delay(math.random() * 20, function()
			if likedBy[post.id] then
				post.likes += 1
				R.BuzzUpdate:FireAllClients(post.id, post.likes)
				if math.random() < 0.35 and data[plr] then data[plr].followers += 1 end
			end
		end)
	end
	F.tutorialEvent(plr, "post")
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
