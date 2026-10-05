-- REVIEWS + IMPROVEMENTS: a living reputation.
-- A bad review names a real reason (slow service, a dirty floor...) tied to one of five improvements every
-- business has. Improving that area doesn't erase the review: the next time a customer visits that business,
-- the unhappy customer may come back and update it ("Much faster this time!"). Improvements only raise
-- customer satisfaction (reviews and reputation), never income directly, so they can't be farmed for money.
return function(C)
local F, data, R = C.F, C.data, C.R
local BIZ = C.BIZ
local fmt, notify = C.fmt, C.notify
local RGB = Color3.fromRGB

C.IMPROVEMENTS = {
	{key = "quality", name = "Quality", icon = "🍽️", desc = "Better ingredients and products"},
	{key = "speed", name = "Speed", icon = "⚡", desc = "Faster counters, a second register"},
	{key = "cleanliness", name = "Cleanliness", icon = "🧽", desc = "Cleaning crew and new floors"},
	{key = "service", name = "Service", icon = "🤝", desc = "Training and friendlier staff"},
	{key = "atmosphere", name = "Atmosphere", icon = "🎶", desc = "Music, lighting and decor"},
}
C.IMPROVEMENT = {}
for _, im in ipairs(C.IMPROVEMENTS) do C.IMPROVEMENT[im.key] = im end
local MAX_IMPROVE = 5
C.MAX_IMPROVE = MAX_IMPROVE

-- what an unhappy customer says about each area (%s = what the business sells)
local COMPLAINTS = {
	quality = {"The %s tasted kinda bad.", "Not the best %s I've had.", "My %s was... fine? Barely."},
	speed = {"The line was way too long.", "Took forever to get my %s.", "Food was slow and I was hungry."},
	cleanliness = {"The place was kinda dirty.", "Sticky tables. Just saying.", "Food was slow and the place was dirty."},
	service = {"Staff was kinda rude.", "Nobody even said hi.", "Asked for help, got a shrug."},
	atmosphere = {"The place felt so boring.", "Needs some decoration. Or anything.", "Zero vibes. Zero."},
}
-- what they say when they come back after you improved it
local PRAISE = {
	quality = {"Wow, the %s is SO much better now!", "The %s actually slaps now."},
	speed = {"Much faster this time!", "In and out in a minute. Love it."},
	cleanliness = {"Spotless now. Respect.", "Clean tables! A miracle!"},
	service = {"Staff was super friendly this time!", "They remembered my name!"},
	atmosphere = {"Love the new look!", "The vibes are immaculate now."},
}
local BIG = {"Wow. This place completely changed!", "From 2 stars to my favorite spot. Unreal."}

local function stars(n)
	n = math.clamp(math.floor(n + 0.5), 0, 5)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end
local function improveOf(d, key)
	d.improve = type(d.improve) == "table" and d.improve or {}
	local t = d.improve[key]
	if type(t) ~= "table" then
		t = {}
		d.improve[key] = t
	end
	return t
end
function F.improveLevel(d, key, attr) return tonumber(improveOf(d, key)[attr]) or 0 end
function F.improveTotal(d, key)
	local n = 0
	for _, im in ipairs(C.IMPROVEMENTS) do n += F.improveLevel(d, key, im.key) end
	return n
end
-- price: a share of that business's next upgrade, doubling each level (always a real decision)
function F.improveCost(d, key, attr)
	local lvl = F.improveLevel(d, key, attr)
	if lvl >= MAX_IMPROVE then return nil end
	local base = BIZ[key].cost * C.ECONOMY.upgradeGrowth ^ math.max(0, (d.levels[key] or 1) - 1)
	return math.floor(base * 0.35 * 2 ^ lvl)
end
function F.buyImprovement(plr, d, key, attr)
	if not (BIZ[key] and C.IMPROVEMENT[attr]) then return end
	if (d.levels[key] or 0) <= 0 then
		notify(plr, "Open that business first!")
		return
	end
	local cost = F.improveCost(d, key, attr)
	if not cost then return end
	if d.cash < cost then
		notify(plr, "You need $" .. fmt(cost) .. " for that improvement.")
		return
	end
	d.cash -= cost
	local t = improveOf(d, key)
	t[attr] = (tonumber(t[attr]) or 0) + 1
	notify(plr, C.IMPROVEMENT[attr].icon .. " " .. BIZ[key].name .. " " .. C.IMPROVEMENT[attr].name .. " is now level " .. t[attr] .. "! Unhappy customers may come back and change their minds.")
end
-- improvements make customers happier (reviews + reputation only): +1 satisfaction per level, at most +20
function F.improveSatisfaction(d, key)
	return math.min(20, F.improveTotal(d, key))
end

-- a fresh bad review: blame the business's weakest area (or the problem it has right now)
function F.reviewReason(d, key, stars)
	if stars > 2 then return nil end
	local weakest, low = {}, math.huge
	for _, im in ipairs(C.IMPROVEMENTS) do
		local l = F.improveLevel(d, key, im.key)
		if l < low then weakest, low = {im.key}, l elseif l == low then table.insert(weakest, im.key) end
	end
	local attr = weakest[math.random(#weakest)]
	if d.problems[key] then attr = math.random() < 0.5 and "speed" or "quality" end
	local pool = COMPLAINTS[attr]
	return attr, string.gsub(pool[math.random(#pool)], "%%s", BIZ[key].thing)
end
-- remember it (only the latest dozen are kept and saved)
function F.bookReview(plr, d, key, review, customerName)
	if not review.attr then return end
	d.reviewBook = type(d.reviewBook) == "table" and d.reviewBook or {}
	d.reviewSeq = (d.reviewSeq or 0) + 1
	table.insert(d.reviewBook, 1, {id = d.reviewSeq, biz = key, stars = review.stars, text = review.text, attr = review.attr, who = customerName,
		at = F.improveLevel(d, key, review.attr), problem = d.problems[key] ~= nil, t = os.time()})
	while #d.reviewBook > 12 do table.remove(d.reviewBook) end
end
-- a customer just visited this business: maybe someone unhappy came back and things are better now
function F.revisitReviews(plr, d, key)
	if type(d.reviewBook) ~= "table" or math.random() > 0.5 then return end
	for _, rv in ipairs(d.reviewBook) do
		if rv.biz == key and not rv.updated then
			local now = F.improveLevel(d, key, rv.attr)
			local gain = now - (tonumber(rv.at) or 0)
			local fixedProblem = rv.problem and not d.problems[key]
			if gain > 0 or fixedProblem then
				local newStars = math.min(5, rv.stars + 1 + gain + (fixedProblem and 1 or 0))
				local text = newStars >= 5 and F.improveTotal(d, key) >= 8 and BIG[math.random(#BIG)]
					or string.gsub(PRAISE[rv.attr][math.random(#PRAISE[rv.attr])], "%%s", BIZ[key].thing)
				rv.updated = {stars = newStars, text = text, t = os.time()}
				F.addRep(plr, (newStars - rv.stars) * C.ECONOMY.reviewRep * 2)
				notify(plr, "⭐ " .. (rv.who or "A customer") .. " updated their review of your " .. BIZ[key].name .. ": " .. stars(rv.stars) .. " → " .. stars(newStars) .. " \"" .. text .. "\"")
				if F.pushMsg then
					F.pushMsg(plr, {icon = "😋", from = (rv.who or "A customer") .. " (customer)", cat = "customer", text = "Came back to your " .. BIZ[key].name .. ". " .. text .. " Updated my review to " .. newStars .. "★."})
				end
				return
			end
		end
	end
end
-- for the business panel
function F.reviewsFor(d, key)
	local out = {}
	for _, rv in ipairs(type(d.reviewBook) == "table" and d.reviewBook or {}) do
		if rv.biz == key then
			table.insert(out, {stars = rv.stars, text = rv.text, attr = rv.attr, who = rv.who, fix = C.IMPROVEMENT[rv.attr] and C.IMPROVEMENT[rv.attr].name or nil,
				updated = rv.updated and {stars = rv.updated.stars, text = rv.updated.text} or nil})
			if #out >= 4 then break end
		end
	end
	return out
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.improve = function(plr, d, a, b)
	if C.str(a, 20) and C.str(b, 20) then F.buyImprovement(plr, d, a, b) end
end
end
