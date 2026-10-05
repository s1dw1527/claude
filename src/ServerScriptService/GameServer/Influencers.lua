-- INFLUENCERS: four original, fictional city celebrities who show up now and then.
--   Bay Snaps   - chaotic livestreamer, rates businesses live           "CHAT, WE GOTTA SEE THIS."
--   Jax Cash    - luxury-business influencer, inspects cars             "That's an empire move."
--   Maya Max    - lifestyle creator, rates houses and interiors         "Okay... this place actually eats."
--   Drew Deals  - "business opportunities" of questionable quality      "I've got an opportunity."
-- None of them is based on a real person; names, looks, catchphrases and personalities are their own.
--
-- A visit: one influencer appears at one player's business / home / car (rare: minutes apart, one at a time).
-- Everyone sees the sighting; only the player they came for can get the rewards (talk to them before they leave).
-- Rewards are Viral Score, a CityBuzz post, a short customer boost and reputation: never a big cash payout.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

C.INFLUENCERS = {
	{key = "baysnaps", name = "Bay Snaps", handle = "@baysnaps.live", icon = "📸", color = RGB(0, 200, 190), catch = "CHAT, WE GOTTA SEE THIS.",
		bio = "Chaotic livestreamer. Talks fast. Films everything. Loves a good business.", visits = {"business"}},
	{key = "jaxcash", name = "Jax Cash", handle = "@jaxcash", icon = "💼", color = RGB(210, 170, 60), catch = "That's an empire move.",
		bio = "Luxury-business influencer. Expensive cars. Talks about \"the grind\". Takes himself VERY seriously.", visits = {"car", "business"}},
	{key = "mayamax", name = "Maya Max", handle = "@maya.max", icon = "✨", color = RGB(190, 160, 240), catch = "Okay... this place actually eats.",
		bio = "Lifestyle creator. Rates houses, decor and restaurants. Aesthetics are everything.", visits = {"house", "business"}},
	{key = "drewdeals", name = "Drew Deals", handle = "@drewdeals", icon = "🤝", color = RGB(70, 160, 70), catch = "I've got an opportunity.",
		bio = "Always making deals. Appears out of nowhere. Advice: sometimes terrible.", visits = {"deal"}},
}
C.INFLUENCER = {}
for _, inf in ipairs(C.INFLUENCERS) do C.INFLUENCER[inf.key] = inf end
C.INFLUENCER_TIMING = {first = {240, 420}, gap = {360, 660}, stay = 120, afterMeet = 25}
local TIMING = C.INFLUENCER_TIMING

local FOLDER = Instance.new("Folder")
FOLDER.Name = "Influencers"
FOLDER.Parent = Workspace

local active = nil         -- the visit in progress
local nextVisit = os.clock() + math.random(TIMING.first[1], TIMING.first[2])
local lastVisited = {}     -- [userId] = os.clock()
local visitSeq = 0
C.influencerState = function() return active end

local function bestBusiness(d)
	local best, lvl = nil, 0
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > lvl then best, lvl = b.key, d.levels[b.key] end
	end
	return best
end
local function bestCar(plr, d)
	local best
	for _, c in ipairs(C.CARS) do
		if F.ownsCar and F.ownsCar(plr, c) and (not best or c.price > best.price) then best = c end
	end
	return best
end
local function sightingList()
	local s = C.influencerSightings
	return s
end

-- ===== starting a visit =====
local function placeFor(inf, plr, d, kind)
	if kind == "house" then
		local lot = F.homeLot(d)
		if lot and d.home and d.home.level > 0 then return F.homeAnchor(lot) * CF(3, 0, 7), "home", nil end
		return nil
	elseif kind == "car" then
		local car = bestCar(plr, d)
		if not car then return nil end
		local key = bestBusiness(d)
		if not key then return nil end
		return F.bizAnchor(d, key) * CF(-4, 0, 9), car.name, key
	else
		local key = bestBusiness(d)
		if not key then return nil end
		return F.bizAnchor(d, key) * CF(3.5, 0, 6), BIZ[key].name, key
	end
end
local function leave(reason)
	local v = active
	if not v then return end
	active = nil
	if v.part then v.part:Destroy() end
	v.entry.active = false
	R.Viral:FireAllClients({kind = "influencerLeave", id = v.id})
	if reason == "noshow" and v.target.Parent then
		F.buzz(v.inf.icon, v.inf.name .. " waited at " .. v.target.Name .. "'s " .. v.place .. "... and left. Nobody came. 💀", v.inf.color, v.inf.name)
		notify(v.target, v.inf.icon .. " " .. v.inf.name .. " got tired of waiting and left. Next time, run!")
	end
end
C.influencerLeave = leave
local meet
function F.startInfluencer(forceWho, forceTarget, forceKind)
	if active then return nil end
	-- the player they visit: someone playing (not in the tutorial) with a business, least recently visited
	local target, td
	if forceTarget then
		target, td = forceTarget, data[forceTarget]
	else
		local oldest = math.huge
		for p, d in pairs(data) do
			if p.Parent and (d.tut or 0) == 0 and bestBusiness(d) then
				local t = lastVisited[p.UserId] or 0
				if t < oldest then target, td, oldest = p, d, t end
			end
		end
	end
	if not (target and td) then return nil end
	-- who comes, and what they look at
	local options = {}
	for _, inf in ipairs(C.INFLUENCERS) do
		if not forceWho or forceWho == inf.key then
			for _, kind in ipairs(inf.visits) do
				local want = forceKind or kind
				if want == kind then
					local cf, place, key = placeFor(inf, target, td, kind == "deal" and "business" or kind)
					if cf then table.insert(options, {inf = inf, kind = kind, cf = cf, place = place, key = key}) break end
				end
			end
		end
	end
	if #options == 0 then return nil end
	local o = options[math.random(#options)]
	visitSeq += 1
	local inf = o.inf
	local part = Instance.new("Part")
	part.Name = "Influencer_" .. inf.key
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Transparency = true, false, true, false, 1
	part.Size = V3(3, 6, 3)
	part.CFrame = o.cf * CF(0, 3, 0)
	part.Parent = FOLDER
	local entry = {who = inf.key, name = inf.name, icon = inf.icon, place = target.Name .. "'s " .. o.place, targetName = target.Name, t = os.time(), active = true}
	local list = sightingList()
	table.insert(list, 1, entry)
	while #list > 8 do table.remove(list) end
	active = {id = visitSeq, inf = inf, kind = o.kind, key = o.key, target = target, cf = o.cf, place = o.place, part = part, expires = os.clock() + TIMING.stay, met = false, entry = entry}
	lastVisited[target.UserId] = os.clock()
	local visit = active
	C.prompt(part, "Talk", inf.name, 14, 0.2, function(who) meet(who, visit) end)
	R.Viral:FireAllClients({kind = "influencer", id = visitSeq, who = inf.key, name = inf.name, icon = inf.icon, catch = inf.catch, cf = o.cf,
		target = target.UserId, targetName = target.Name, place = o.place, dur = TIMING.stay})
	notify(target, "🚨 " .. string.upper(inf.name) .. " IS AT YOUR " .. string.upper(o.place) .. "! Go talk to them before they leave!")
	F.viralMoment(target, "influencerVisit", {who = inf.name, place = o.place, pos = o.cf.Position})
	return active
end

-- ===== meeting them =====
local function rate10(x) return math.clamp(math.floor(x + 0.5), 1, 10) end
local function influencerPost(plr, d, inf, text, cat)
	local post = F.buzz(inf.icon, text, inf.color, inf.name)
	if post then post.likes = math.random(40, 400) end
	F.viralMoment(plr, "influencerPost", {who = inf.name, cat = cat or "biz", clipzChance = 0.6})
	-- the full set: all four influencers posted about you in one week (legendary, once per save)
	local v = F.viralOf(d)
	local week = C.weekId and C.weekId() or 0
	if type(v.posted) ~= "table" or v.posted.week ~= week then v.posted = {week = week, by = {}} end
	v.posted.by[inf.key] = true
	local n = 0
	for _ in pairs(v.posted.by) do n += 1 end
	if n >= #C.INFLUENCERS then F.viralMoment(plr, "fullSet", {}) end
end
local DEALS = {
	{text = "I'm opening a lemonade stand. On the MOON. Need investors.", win = false},
	{text = "Two words: subscription. Lemonade.", win = true},
	{text = "Hear me out: a car wash, but for shoes.", win = false},
	{text = "I know a guy who knows a guy who sells really good chairs.", win = true},
	{text = "Expensive water. In a FANCY bottle.", win = true},
}
function meet(plr, visit)
	local d = data[plr]
	if not d or visit ~= active then return end
	local inf = visit.inf
	-- anyone can say hi; only the player they came for gets the visit
	if plr ~= visit.target then
		R.Viral:FireClient(plr, {kind = "say", who = inf.key, name = inf.name, text = inf.catch .. " (I'm here for " .. visit.target.Name .. ", but hi!)", pos = visit.cf.Position})
		return
	end
	if visit.met then return end
	visit.met = true
	visit.expires = os.clock() + TIMING.afterMeet
	local now = os.clock()
	local lines, result, react
	if inf.key == "baysnaps" then
		local key = visit.key or bestBusiness(d)
		local rating = rate10((F.satisfaction and F.satisfaction(d, key) or 60) / 10 + math.random(-1, 1))
		lines = {{"baysnaps", "CHAT, WE GOTTA SEE THIS.", "hype"}, {"baysnaps", "We're LIVE at " .. plr.Name .. "'s " .. BIZ[key].name .. "! Chat says... " .. rating .. "/10!", rating >= 7 and "celebrate" or "shrug"},
			{"you", rating >= 7 and "Tell your chat to come through!" or "...Can we do a retake?", rating >= 7 and "owner" or "facepalm"}}
		result = {"📸 BAY SNAPS RATED YOU " .. rating .. "/10", rating >= 7 and "Trending: customers x2 for a minute" or "Chat was... honest."}
		react = rating >= 7 and "celebrate" or "facepalm"
		if rating >= 6 then
			d.trendUntil = math.max(d.trendUntil or 0, now + 60)
			influencerPost(plr, d, inf, "CHAT. " .. plr.Name .. "'s " .. BIZ[key].name .. " is a " .. rating .. "/10. WE GOTTA COME BACK. 📸🔥", "biz")
		end
		F.addRep(plr, rating >= 7 and 8 or 2)
		if F.theCrowd and math.random() < 0.35 then task.delay(6, function() if plr.Parent then F.theCrowd(plr, key, inf.name) end end) end
		if F.startChallenge and math.random() < 0.3 then task.delay(8, function() if plr.Parent then F.startChallenge(plr, key, inf) end end) end
	elseif inf.key == "jaxcash" then
		local car = bestCar(plr, d)
		local fancy = car and car.price >= 1e6
		lines = {{"jaxcash", "Let me see the whip.", "crossed"}, {"jaxcash", car and (car.name .. "? " .. (fancy and "That's an empire move." or "...We all start somewhere.")) or "No whip? That's a walk move.", fancy and "point" or "shrug"},
			{"you", fancy and "I know." or "It has character.", fancy and "owner" or "shrug"}, {"jaxcash", "Remember: the grind never sleeps. I nap, though.", "talk"}}
		result = {"💼 JAX CASH INSPECTED YOUR RIDE", fancy and "\"That's an empire move.\"" or "\"We all start somewhere.\""}
		react = fancy and "ownerPose" or "confused"
		influencerPost(plr, d, inf, fancy and ("Just saw " .. plr.Name .. "'s " .. car.name .. ". That's an empire move. 💼") or (plr.Name .. " drives a " .. (car and car.name or "pair of shoes") .. ". Respect the grind. Upgrade the grind."), "car")
		F.addRep(plr, fancy and 6 or 2)
		if fancy and F.paparazzi and math.random() < 0.3 then task.delay(5, function() if plr.Parent then F.paparazzi(plr) end end) end
	elseif inf.key == "mayamax" then
		local home = visit.place == "home"
		local key = visit.key or "home"
		local score = F.interiorScore100 and F.interiorScore100(d, home and "home" or key) or 30
		local rating = rate10(score / 10 + 2)
		local eats = rating >= 7
		lines = {{"mayamax", "Okay, let's see the " .. (home and "house" or "space") .. "...", "look"}, {"mayamax", eats and "Okay... this place actually eats." or "It's giving... potential.", eats and "celebrate" or "think"},
			{"mayamax", "Aesthetic score: " .. rating .. "/10.", "show"}, {"you", eats and "I did the decorating myself." or "The decor is... in the mail.", eats and "owner" or "facepalm"}}
		result = {"✨ MAYA MAX: " .. rating .. "/10", eats and "\"This place actually eats.\"" or "Tip: decorate it (walk inside → 🛋️ Decorate)"}
		react = eats and "celebrate" or "thinking"
		influencerPost(plr, d, inf, eats and (plr.Name .. "'s " .. (home and "home" or BIZ[key].name) .. "? Okay... this place actually eats. ✨ " .. rating .. "/10") or
			(plr.Name .. "'s " .. (home and "home" or BIZ[key].name) .. " is giving potential. " .. rating .. "/10 ✨"), home and "house" or "interior")
		F.addRep(plr, eats and 6 or 2)
		if home and eats then F.viralMoment(plr, "houseRating", {rating = math.min(100, rating * 10)}) end
	else
		-- Drew Deals: an "opportunity", answered in Messages. The odds are honest: on average it slightly loses money.
		local deal = DEALS[math.random(#DEALS)]
		local stake = math.max(100, math.floor(math.min(d.cash * 0.05, F.incomePerSec(d) * 120)))
		lines = {{"drewdeals", "I've got an opportunity.", "talk"}, {"you", "What kind?", "think"}, {"drewdeals", "...We'll figure that part out.", "shrug"},
			{"drewdeals", deal.text .. " Check your messages.", "show"}}
		result = {"🤝 DREW DEALS MADE AN OFFER", "Check Messages. (Is it a good idea? Probably not.)"}
		react = "thinking"
		if F.pushMsg then
			F.pushMsg(plr, {icon = "🤝", from = "Drew Deals", cat = "investor", important = true, kind = "deal", ref = {stake = stake, win = deal.win},
				text = deal.text .. " Put in $" .. fmt(stake) .. " and I'll make it worth your while. Probably. Maybe.",
				choices = {"🤝 Deal ($" .. fmt(stake) .. ")", "🙅 No deal"}})
		end
	end
	F.cinematic(plr, "influencer", {influencer = inf.key, names = {[inf.key] = inf.name}}, {lines = lines, at = visit.cf * CF(-3.5, 0, -6), mode = "full",
		title = inf.icon .. " " .. string.upper(inf.name) .. " IS HERE", result = result, react = react, force = true})
end
-- the answer to Drew's offer (from Messages): an honest gamble that loses a little on average (EV ≈ 0.9x)
function F.dealChoice(plr, m, choice)
	local d = data[plr]
	if not d or type(m.ref) ~= "table" then return "Done." end
	if choice ~= 1 then return "🙅 You passed. Drew: \"Your loss! ...Probably.\"" end
	local stake = tonumber(m.ref.stake) or 0
	if d.cash < stake then return "Not enough cash. Drew: \"Call me when you're liquid.\"" end
	d.cash -= stake
	local r = math.random()
	local back
	if r < 0.45 then back = 0
	elseif r < 0.85 then back = math.floor(stake * 1.3)
	else back = math.floor(stake * 2.5) end
	d.cash += back
	if back == 0 then
		F.viralMoment(plr, "funnyEvent", {title = "Took Drew's Deal", post = plr.Name .. " invested with Drew Deals. The money is \"on a journey\". 💸"})
		return "💸 The opportunity... didn't work out. Drew: \"Market conditions.\" (-$" .. fmt(stake) .. ")"
	end
	if back >= stake * 2 then
		F.viralMoment(plr, "funnyEvent", {title = "Drew's Deal Actually Worked", post = "Drew Deals' idea ACTUALLY worked for " .. plr.Name .. ". Nobody is more surprised than Drew."})
	end
	return "🤝 It worked! You got $" .. fmt(back) .. " back. Drew: \"Told you. (I didn't know.)\""
end

-- ===== the visit loop =====
task.spawn(function()
	while true do
		task.wait(5)
		local ok, err = pcall(function()
			local now = os.clock()
			if active then
				if not active.target.Parent or not data[active.target] then
					leave("gone")
					nextVisit = now + math.random(TIMING.gap[1], TIMING.gap[2])
				elseif now >= active.expires then
					leave(active.met and "done" or "noshow")
					nextVisit = now + math.random(TIMING.gap[1], TIMING.gap[2])
				end
			elseif now >= nextVisit then
				if F.startInfluencer() then
					nextVisit = math.huge   -- set again when they leave
				else
					nextVisit = now + 60
				end
			end
		end)
		if not ok then warn("[CornerEmpire] influencer loop: " .. tostring(err)) end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	if active and active.target == plr then leave("gone") nextVisit = os.clock() + math.random(TIMING.gap[1], TIMING.gap[2]) end
end)
function F.influencerTalk(plr) if active then meet(plr, active) end end

-- ===== Studio tools =====
C.DEBUG = C.DEBUG or {}
C.DEBUG.influencer = function(plr, d, who)
	if active then leave("done") end
	local v = F.startInfluencer(C.INFLUENCER[who] and who or nil, plr)
	if not v then notify(plr, "🧪 No influencer could visit (open a business first).") end
end
end
