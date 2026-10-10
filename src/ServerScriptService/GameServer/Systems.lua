-- SYSTEMS: economy, reputation & unlocks, customers, staff, problems, stocks, lots, ads,
-- city events, Corner Wars, deliveries, the Spire, rebirths and the tutorial.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local CFG, BUSINESSES, BIZ, CHAINS, COMBOS, REP_TIERS, DISTRICTS, DISTRICT = C.CFG, C.BUSINESSES, C.BIZ, C.CHAINS, C.COMBOS, C.REP_TIERS, C.DISTRICTS, C.DISTRICT
local STAFF_ROLES, NAMES, PROBLEMS, NPC_TYPES, REVIEWS, EVENTS, WAR_CATS, ADS, SPIRE_STAGES = C.STAFF_ROLES, C.NAMES, C.PROBLEMS, C.NPC_TYPES, C.REVIEWS, C.EVENTS, C.WAR_CATS, C.ADS, C.SPIRE_STAGES
local FEATURES, FEATURE_NAMES, REBIRTH, TUTORIAL, HOOD, CAR = C.FEATURES, C.FEATURE_NAMES, C.REBIRTH, C.TUTORIAL, C.HOOD, C.CAR
local fmt, notify, announceAll, burst, stageOf = C.fmt, C.notify, C.announceAll, C.burst, C.stageOf
local LOTS, DESTS = C.LOTS, C.DESTS
local E = C.ECONOMY

local G = {
	event = nil, eventText = nil, eventEnds = 0, nextEvent = os.clock() + CFG.EVENT_INTERVAL, viralKey = nil,
	warEnds = os.clock() + CFG.WAR_INTERVAL,
	spire = {era = 1, stage = 0, progress = 0, top = {}},
}
C.G = G
local ADS_BY = {}
for _, a in ipairs(ADS) do ADS_BY[a.key] = a end
C.ADS_BY = ADS_BY
local function staffStars(s) return s.service + s.speed + s.exp end
C.staffStars = staffStars

function F.tierIndex(rep)
	local t = 1
	for i, tier in ipairs(REP_TIERS) do
		if rep >= tier.rep then t = i end
	end
	return t
end
function F.unlocked(d, feature) return F.tierIndex(d.rep) >= (FEATURES[feature] or 1) end
function F.bizUnlocked(d, key) return F.tierIndex(d.rep) >= BIZ[key].unlock end
-- land you own: v10 deeds (they count and earn even when a full district can't place them in this server)
function F.countLots(d, dkey)
	local n = 0
	for _, deed in ipairs(d.deeds or {}) do
		if not dkey or deed.district == dkey then n += 1 end
	end
	return n
end

-- ===== ECONOMY =====
function F.passMult(d)
	local m = 1
	if d.passes.x4 then m = 4 elseif d.passes.x2 then m = 2 end
	-- VIP adds +25% on top (4x + VIP = 4.25x, not 5x)
	if d.passes.vip then m += E.vipBonus end
	return m
end
-- every dollar the empire earns goes through here. storyEarned is the same money WITHOUT the Money pass
-- boost: the story measures what your businesses earned, so paid passes give more cash to spend but
-- can't skip story chapters
function F.earn(d, amount)
	d.earned += amount
	d.storyEarned = (d.storyEarned or d.earned - amount) + amount / F.passMult(d)
end
function F.rebirthMult(d)
	local m = 1 + REBIRTH.incomePer * d.rebirths
	if d.rebirths >= 100 then m *= 2 end
	return m
end
-- Rich Start pass: a one-time starting bonus per save (d.richClaimed is saved with the slot)
function F.claimRichStart(plr, d)
	if d.passes.richstart and not d.richClaimed then
		d.richClaimed = true
		-- a gift, not earnings: it doesn't count toward lifetime earnings (story chapters, achievements)
		d.cash += CFG.RICH_START_BONUS
		notify(plr, "🎁 Rich Start: +$" .. fmt(CFG.RICH_START_BONUS) .. " to kick off your empire!")
	end
end
function F.bizMult(d, key)
	local m = 1
	local ev = G.event
	if ev and ev.biz and ev.biz[key] then m *= ev.biz[key] end
	if G.viralKey == key then m *= 3 end
	local s = d.staff[key]
	if s then m *= 1 + E.staffPerStar * staffStars(s) * (F.crewFactor and F.crewFactor(s) or 1) end   -- v14: shifts + traits (Crew)
	for _, c in ipairs(COMBOS) do
		if d.combos[c.key] and table.find(c.needs, key) then m *= c.mult end
	end
	for dkey in pairs(F.ownedDistricts(d)) do
		local boost = DISTRICT[dkey].boost[key]
		if boost then m *= boost end
	end
	if F.homeHood(d) == "ocean" and (key == "lemonade" or key == "icecream") then m *= 1.25 end
	-- v10: locations around the city, products and supplies
	if F.locationMult then m *= F.locationMult(d, key) end
	if F.productMult then m *= F.productMult(d, key) end
	if F.stockMult then m *= F.stockMult(d, key) end
	if G.megaBiz and G.megaBiz[key] then m *= G.megaBiz[key] end
	if F.rushMult then m *= F.rushMult(d, key) end   -- v14: Rush Orders (Kitchen)
	if F.theaterMult then m *= F.theaterMult(d, key) end
	if F.rivalMult then m *= F.rivalMult(d, key) end   -- v14: market share against the AI rivals (Rivals)
	if F.prestigeMult then m *= F.prestigeMult(d) end   -- v14: +1% per prestige star (Leaders)   -- v14: how full the Movie Theater's shows are (Theater)
	if d.problems[key] then m *= 0.5 end
	return m
end
-- district boosts: once per district you own land in (or once per lot, if E.districtBoostOnce is off)
function F.ownedDistricts(d)
	local out = {}
	for _, deed in ipairs(d.deeds or {}) do
		local k = deed.district
		if DISTRICT[k] then out[k] = E.districtBoostOnce and 1 or (out[k] or 0) + 1 end
	end
	return out
end
local function districtBoost(d, kind)
	local m = 1
	for dkey, n in pairs(F.ownedDistricts(d)) do
		local b = DISTRICT[dkey].boost[kind]
		if b then m *= b ^ n end
	end
	return m
end
function F.globalMult(d, now)
	local m = F.passMult(d)
	m *= 1 + E.repTierBonus * (F.tierIndex(d.rep) - 1)
	if G.event and G.event.all then m *= G.event.all end
	if d.buffUntil > now then m *= 1 + 0.2 * d.buffWins end
	if d.adUntil > now then m *= ADS_BY[d.adKey].income end
	if (d.relaxedUntil or 0) > now then m *= 1 + C.FERRIS.buff end
	local mgr = d.staff.manager
	if mgr then m *= 1 + E.managerPerStar * staffStars(mgr) end
	if (d.megaBuffUntil or 0) > now then m *= d.megaBuffMult or 1 end
	m *= districtBoost(d, "all")
	m *= 1 + E.eraBonus * (G.spire.era - 1)
	m *= F.comboPerk(d, "all")
	if F.mysteryPerk then m *= F.mysteryPerk(d, "all") end
	m *= F.homeMult(d)
	m *= F.rebirthMult(d)
	return m
end
function F.income(d, now)
	local g = F.globalMult(d, now)
	local per = {}
	local total = CFG.BASE_INCOME
	for _, deed in ipairs(d.deeds or {}) do
		local dist = DISTRICT[deed.district]
		if dist then total += dist.income end
	end
	for _, b in ipairs(BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 then
			local base = b.income * lvl + b.income * E.chainIncome * (d.chains[b.key] or 0)
			local v = base * F.bizMult(d, b.key)
			per[b.key] = v * g
			total += v
		else
			per[b.key] = 0
		end
	end
	return total * g, per, g
end
function F.incomePerSec(d) return (F.income(d, os.clock())) end
function F.globalRentMult(d) return F.rebirthMult(d) * F.passMult(d) end
function F.upgradeCost(d, key)
	local c = BIZ[key].cost * E.upgradeGrowth ^ (d.levels[key] or 0)
	if G.event and G.event.crash then c *= CFG.CRASH_DISCOUNT end
	return math.floor(c)
end
function F.chainCost(d, key)
	local c = d.chains[key] or 0
	if c >= #CHAINS then return nil end
	-- a new location costs a multiple of that business's Lv 10 upgrade: a real investment, not a shortcut
	return math.floor(BIZ[key].cost * E.upgradeGrowth ^ (CFG.MAX_LEVEL - 1) * CHAINS[c + 1].mult)
end

-- ===== REPUTATION + UNLOCKS =====
function F.addRep(plr, amount)
	local d = data[plr]
	if not d then return end
	if amount > 0 and F.homeHood(d) == "hills" then amount *= 1.15 end
	if amount > 0 and (d.viralUntil or 0) > os.clock() then amount *= 2 end
	if amount > 0 and F.vehicleBonus then amount *= F.vehicleBonus(plr, "rep") end   -- v14: 🎩 VIP car
	local old = F.tierIndex(d.rep)
	d.rep = math.max(0, d.rep + amount)
	d.war.rep += amount
	if amount > 0 and math.random() < 0.5 then d.followers += math.max(1, math.floor(amount / 3)) end
	local new = F.tierIndex(d.rep)
	if new ~= old then
		F.setPlotSign(d.plot, plr.Name .. "'s Empire", REP_TIERS[new].name)
		if new > old then
			R.Splash:FireClient(plr, "⭐ " .. REP_TIERS[new].name .. " ⭐", "UNLOCKED: " .. table.concat(REP_TIERS[new].unlocks, " • "), RGB(255, 215, 80))
			F.buzz("⭐", plr.Name .. "'s empire reached " .. REP_TIERS[new].name .. "!", RGB(255, 215, 80))
			F.pushMsg(plr, {icon = "🔓", from = "City Hall", important = true, text = "You reached " .. REP_TIERS[new].name .. "! New unlocks: " .. table.concat(REP_TIERS[new].unlocks, ", ") .. "."})
			burst(d.plot.center + V3(0, 15, 0), RGB(255, 215, 80), 100)
		end
		F.refreshTower(plr)
	end
end

-- ===== DISCOVERIES =====
function F.checkCombos(plr, d)
	for _, c in ipairs(COMBOS) do
		if not d.combos[c.key] then
			local ok = true
			for _, n in ipairs(c.needs) do
				local need = (c.levels and c.levels[n]) or c.lvl
				if (d.levels[n] or 0) < need then ok = false end
			end
			if c.marketing and not d.marketing then ok = false end
			if c.era and G.spire.era < c.era then ok = false end
			if c.rebirths and d.rebirths < c.rebirths then ok = false end
			if c.earned and (d.earned or 0) < c.earned then ok = false end
			if c.found and not (d.found and d.found[c.found]) then ok = false end
			if c.viral and not d.wentViral then ok = false end
			if ok then
				d.combos[c.key] = true
				local what = c.perkText or ("its businesses earn +" .. math.floor((c.mult - 1) * 100 + 0.5) .. "%")
				R.Splash:FireClient(plr, c.rare and "🗝️ RARE SECRET UNLOCKED 🗝️" or "✨ NEW DISCOVERY ✨", c.icon .. " " .. c.name .. (c.secret and " (SECRET!)" or "") .. " — " .. what, c.color)
				F.buzz(c.icon, plr.Name .. (c.rare and " unlocked an ultra-rare " or " discovered the ") .. c.name .. "!" .. (c.secret and " 🤫 A secret business!" or ""), c.color)
				F.addRep(plr, c.rare and 150 or (c.secret and 50 or 25))
				F.refreshKiosks(plr)
				burst(d.plot.center + V3(0, 10, 0), c.color, c.rare and 250 or 120)
				if F.achieve then F.achieve(plr, c.rare and "rare" or (c.secret and "secret" or nil)) end
			end
		end
	end
end
-- empire-wide perks from rare secret businesses
function F.comboPerk(d, kind)
	local m = 1
	for _, c in ipairs(COMBOS) do
		if c.perk and c.perk[kind] and d.combos[c.key] then m *= c.perk[kind] end
	end
	return m
end

-- ===== CUSTOMERS =====
function F.satisfaction(d, key)
	local s = 66
	local st = d.staff[key]
	if st then s += st.service * 3 end
	if F.crewSatisfaction then s += F.crewSatisfaction(d, key) end   -- v14: a Charmer on staff
	local n = 0
	for _ in pairs(d.problems) do n += 1 end
	if d.problems[key] then s -= 30 end
	s += G.megaSatisfaction or 0
	-- improvements and decorated interiors make customers happier (capped; reviews and reputation only)
	if F.improveSatisfaction then s += F.improveSatisfaction(d, key) end
	if F.interiorSatisfaction then s += F.interiorSatisfaction(d, key) end
	s -= n * 4
	s += stageOf(d.levels[key] or 0, d.chains[key] or 0) * 2
	return math.clamp(s, 5, 100)
end
function F.customerRate(d, now)
	local levels = 0
	for _, b in ipairs(BUSINESSES) do levels += d.levels[b.key] or 0 end
	if levels == 0 then return 0 end
	local r = E.customerBase + E.customerPerLevel * levels
	if d.adUntil > now then r *= ADS_BY[d.adKey].customers end
	if d.trendUntil > now then r *= 2 end
	local mk = d.staff.marketer
	if mk then r *= 1 + 0.06 * staffStars(mk) end
	if G.event and G.event.customers then r *= G.event.customers end
	if G.megaCustomers then r *= G.megaCustomers end
	r *= F.comboPerk(d, "customers")
	if F.mysteryPerk then r *= F.mysteryPerk(d, "customers") end
	if (d.viralUntil or 0) > now then r *= 3 end
	if (d.postBuffUntil or 0) > now then r *= d.postBuffMult or 1 end
	if G.event and G.event.concert and F.countLots(d, "beach") > 0 then r *= 3 end
	r *= F.followerMult(d)
	if F.homeHood(d) == "suburbs" then r *= 1.1 end
	if d.rebirths >= 50 then r *= 1.5 end
	return math.min(r, CFG.MAX_CUSTOMERS_PER_SEC)
end
local function pickBusiness(d, t)
	local total, list = 0, {}
	for _, b in ipairs(BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 then
			local w = lvl * (1 + (t.likes[b.key] or 0))
			if F.productCustomerMult then w *= F.productCustomerMult(d, b.key) end
			if G.viralKey == b.key then w *= 4 end
			if G.event and G.event.biz and G.event.biz[b.key] then w *= G.event.biz[b.key] end
			if t.fancy and stageOf(lvl, d.chains[b.key] or 0) < 3 then w *= 0.2 end
			if t.trendy then
				for _, c in ipairs(COMBOS) do
					if d.combos[c.key] and table.find(c.needs, b.key) then w *= 2 end
				end
			end
			total += w
			table.insert(list, {b.key, w})
		end
	end
	if total <= 0 then return nil end
	local r = math.random() * total
	for _, e in ipairs(list) do
		r -= e[2]
		if r <= 0 then return e[1] end
	end
	return list[#list][1]
end
function F.spawnCustomer(plr, d, now)
	local ti = math.random(#NPC_TYPES)
	local t = NPC_TYPES[ti]
	local key = pickBusiness(d, t)
	if not key then return end
	local plot = d.plot
	local b = BIZ[key]
	local start = plot.at(math.random(-40, 40), 0.2, 52)
	local entry = plot.at(math.random(-6, 6), 1, 40)
	local door = (F.slotCF(plot, key) * CF(0, 0, 9)).Position
	local travel = ((entry - start).Magnitude + (door - entry).Magnitude) / 9
	local review
	if math.random() < (t.trendy and 1 or 0.4) then
		local sat = F.satisfaction(d, key)
		local stars = math.clamp(math.floor((sat + math.random(-18, 18)) / 20 + 0.5), 1, 5)
		local pool = REVIEWS[stars]
		local text = string.gsub(pool[math.random(#pool)], "%%s", b.thing)
		-- a bad review names a real reason (one of the business's improvement areas), so it can be won back
		local attr
		if stars <= 2 and F.reviewReason then attr, text = F.reviewReason(d, key, stars) end
		local pr = d.problems[key]
		if pr and stars <= 2 then text = PROBLEMS[pr.type].icon .. " " .. PROBLEMS[pr.type].text end
		review = {stars = stars, text = text, attr = attr, who = NAMES[math.random(#NAMES)]}
	end
	-- from story chapter 3 on, some customers recognize you and shout something
	local shout = F.storyShout and plr and F.storyShout(plr, d) or nil
	-- (v14: which business and which of its products, so the sale shows what was actually bought)
	local plist = F.productsOf and F.productsOf(d, key) or {}
	local item = #plist > 0 and plist[math.random(#plist)].name or nil
	R.Customer:FireAllClients({plot = plot.index, npc = ti, start = start, entry = entry, door = V3(door.X, 1, door.Z), t = travel, review = review, shout = shout, owner = plr.UserId,
		icon = BIZ[key].icon, item = item})
	task.delay(travel, function()
		if data[plr] == d then F.serveCustomer(plr, d, key, t, review) end
	end)
end
function F.serveCustomer(plr, d, key, t, review)
	local now = os.clock()
	local lvl = d.levels[key] or 0
	if lvl <= 0 then return end
	d.served += 1
	d.war.customers += 1
	d.bizServed = d.bizServed or {}
	d.bizServed[key] = (d.bizServed[key] or 0) + 1
	if F.revisitReviews then F.revisitReviews(plr, d, key) end
	if F.countServed then F.countServed(d) end
	if F.viralServed then F.viralServed(plr, d, key) end
	if F.productServed then F.productServed(plr, d, key) end
	if d.frozenUntil <= now then
		local sale = BIZ[key].income * lvl * E.customerSale * F.bizMult(d, key) * F.globalMult(d, now) * (t.tip or 1)
		d.cash += sale
		F.earn(d, sale)
		d.war.earned += sale
	end
	if review then
		-- good reviews build reputation slowly (E.reviewRep); bad ones still hurt at full strength
		local r = ({-2, -1, 0, 1, 2})[review.stars]
		F.addRep(plr, r > 0 and r * E.reviewRep or r)
		if F.storyEvent then F.storyEvent(plr, "review", review.stars) end
		d.war.stars += review.stars
		d.war.starsN += 1
		d.revSum += review.stars
		d.revN += 1
		d.bizStars = d.bizStars or {}
		local bs = d.bizStars[key] or {0, 0}
		d.bizStars[key] = {bs[1] + review.stars, bs[2] + 1}
		if review.attr and F.bookReview then F.bookReview(plr, d, key, review, review.who) end
		if F.viralReview then F.viralReview(plr, d, key, review) end
		-- a dramatic complaint plays out in front of you (only if you're there to see it)
		if review.stars == 1 and F.cinematic then
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			local door = (F.slotCF(d.plot, key) * CF(0, 0, 9)).Position
			if root and (root.Position - door).Magnitude < 70 then
				F.cinematic(plr, "complaint", {text = string.upper(review.text), names = {customer = review.who}}, {at = F.bizAnchor(d, key), title = "😤 A CUSTOMER HAS THOUGHTS",
					result = {"😤 COMPLAINT", "Tip: improvements win unhappy customers back"}, react = "facepalm"})
			end
		end
		table.insert(d.reviews, 1, {stars = review.stars, text = review.text, biz = BIZ[key].tiers[math.max(1, stageOf(lvl, d.chains[key] or 0))]})
		if #d.reviews > 8 then table.remove(d.reviews) end
		if t.trendy and review.stars >= 4 and d.trendUntil < now then
			d.trendUntil = now + 30
			-- sometimes the influencer's post blows up: YOU WENT VIRAL
			local chance = 0.22 + math.min(0.15, (d.followers or 0) / 20000)
			if review.stars >= 5 then chance += 0.1 end
			if now >= (d.viralCooldown or 0) and math.random() < chance then
				F.goViral(plr, d, key, review.text)
			else
				F.buzz("🤳", "Influencer: \"" .. review.text .. "\" — " .. plr.Name .. "'s " .. BIZ[key].name .. " is trending!", RGB(255, 110, 200))
			end
		end
	end
end

-- the big viral moment: 60s of 3x customers, double reputation, a follower surge and a server-wide shout-out
function F.goViral(plr, d, key, quote)
	local now = os.clock()
	d.viralUntil = now + 60
	d.viralCooldown = now + 300
	d.viralCount = (d.viralCount or 0) + 1
	d.wentViral = true
	local fans = math.floor(math.clamp(50 + d.rep / 4 + (d.followers or 0) * 0.08, 50, 5000))
	d.followers += fans
	F.addRep(plr, 15)
	local b = BIZ[key]
	local door = (F.slotCF(d.plot, key) * CF(0, 0, 9)).Position
	R.Mega:FireAllClients({kind = "viral", player = plr.Name, userId = plr.UserId, biz = b.name, icon = b.icon, quote = quote, fans = fans, pos = door, color = RGB(255, 110, 200)})
	F.buzz("🔥", plr.Name .. "'s " .. b.name .. " WENT VIRAL! \"" .. quote .. "\" (+" .. fmt(fans) .. " followers)", RGB(255, 110, 200))
	burst(door + V3(0, 6, 0), RGB(255, 110, 200), 200)
	C.shockwave(door + V3(0, 1, 0), RGB(255, 110, 200), 40)
	if F.achieve then F.achieve(plr, "viral") end
	if F.storyEvent then F.storyEvent(plr, "viral") end
	if F.viralMoment then F.viralMoment(plr, "wentViral", {biz = b.name, pos = door}) end
	F.checkCombos(plr, d)
end

-- ===== BUSINESS UPGRADES + CHAINS =====
function F.buyUpgrade(plr, d, key)
	local b = BIZ[key]
	local lvl = d.levels[key] or 0
	if lvl >= CFG.MAX_LEVEL then return end
	if not F.bizUnlocked(d, key) then
		notify(plr, "🔒 " .. b.name .. " unlocks at " .. REP_TIERS[b.unlock].name .. " reputation.")
		return
	end
	-- v14: the Movie Theater is too big for the home plot: it opens on a city plot (Properties → a plot → 🎬)
	if lvl <= 0 and b.lotOnly and not (F.siteDeed and F.siteDeed(d, key)) then
		notify(plr, b.icon .. " A " .. b.name .. " needs a city plot. Buy one in 🏙️ Properties, then choose " .. b.icon .. " on it.")
		R.Menu:FireClient(plr, "needPlot", key)
		return
	end
	local cost = F.upgradeCost(d, key)
	if d.cash < cost then return end
	d.cash -= cost
	d.levels[key] = lvl + 1
	local ch = d.chains[key] or 0
	local oldStage, newStage = stageOf(lvl, ch), stageOf(lvl + 1, ch)
	F.refreshBuilding(plr, key, true)
	d.seen.stages[key .. newStage] = true
	if newStage ~= oldStage then F.refreshWorkers(plr) end
	if newStage > oldStage and oldStage > 0 then
		F.buzz(b.icon, plr.Name .. "'s " .. b.tiers[oldStage] .. " transformed into a " .. b.tiers[newStage] .. "!", b.color)
		-- a major upgrade gets a short scene; the first time a business reaches a new building it is a Grand Opening (v12)
		if F.tierOpening and F.tierOpening(plr, d, key, oldStage, newStage) then
			-- celebrated by Empire.tierOpening
		elseif F.cinematic then
			F.cinematic(plr, "upgrade", {biz = b.tiers[newStage], names = {staff = d.staff[key] and d.staff[key].name or nil}}, {at = F.bizAnchor(d, key),
				title = "⬆️ " .. string.upper(b.tiers[newStage]), result = {"⬆️ MAJOR UPGRADE", b.tiers[oldStage] .. " → " .. b.tiers[newStage]}, react = "celebrate"})
		end
	end
	if lvl >= 1 and F.empireFirst then F.empireFirst(plr, "upgrade") end
	if lvl + 1 == CFG.MAX_LEVEL then
		notify(plr, "⭐ " .. b.tiers[newStage] .. " is MAX level!" .. (F.unlocked(d, "chains") and " Open new locations to build a chain." or ""))
		F.refreshTower(plr)
	end
	if lvl == 0 and F.achieve then
		F.achieve(plr, "firstBusiness")
		F.achieve(plr, "biz_" .. key)
	end
	if lvl == 0 and key ~= "lemonade" and F.storyEvent then F.storyEvent(plr, "newBusiness", key) end
	if lvl == 0 and F.refreshDoors then F.refreshDoors(plr) end
	if F.rivalAct then F.rivalAct(plr, "upgrade", key) end   -- v14: pushing rivals back (Rivals)
	if F.track then F.track(plr, "upgrade") end   -- v14: occasions
	-- v10: a new business gets a name (the client asks; "keep the default" is fine too)
	if lvl == 0 and F.askBizName then task.defer(F.askBizName, plr, key) end
	-- v9: grand opening. Every first opening gets its signature moment; bigger businesses often draw a crowd.
	if lvl == 0 then
		d.openings = type(d.openings) == "table" and d.openings or {}
		local firstTime = d.openings[key] == nil
		d.openings[key] = d.openings[key] or os.time()
		if firstTime then
			local crowd = key ~= "lemonade" and math.random() < 0.6
			local m = F.viralMoment and F.viralMoment(plr, crowd and "openingCrowd" or "opening", {uniq = key, biz = b.tiers[1], pos = (F.slotCF(d.plot, key) * CF(0, 0, 9)).Position})
			if F.cineOpening then F.cineOpening(plr, d, key, crowd, m and m.id or nil) end
		end
	end
	F.checkCombos(plr, d)
end
function F.openChain(plr, d, key)
	if (d.levels[key] or 0) < CFG.MAX_LEVEL then return end
	if not F.unlocked(d, "chains") then
		notify(plr, "🔒 Business chains unlock at " .. REP_TIERS[FEATURES.chains].name)
		return
	end
	local cost = F.chainCost(d, key)
	if not cost or d.cash < cost then return end
	d.cash -= cost
	local c = (d.chains[key] or 0) + 1
	d.chains[key] = c
	local b = BIZ[key]
	F.refreshBuilding(plr, key, true)
	d.seen.stages[key .. stageOf(d.levels[key], c)] = true
	F.refreshWorkers(plr)
	if c == #CHAINS then
		R.Splash:FireAllClients("🌟 NEW LANDMARK 🌟", plr.Name .. " built the " .. b.tiers[6] .. "!", RGB(255, 215, 80))
		F.buzz("🌟", plr.Name .. " built a LANDMARK: " .. b.tiers[6] .. "!", RGB(255, 215, 80))
		F.addRep(plr, 100)
		if F.achieve then F.achieve(plr, "firstLandmark") end
	else
		notify(plr, "📍 Opened Location #" .. (c + 1) .. ": " .. CHAINS[c].name .. " " .. b.name .. "!")
		F.buzz("📍", plr.Name .. " opened a " .. CHAINS[c].name .. " " .. b.name .. " location!", b.color)
		F.addRep(plr, 15)
	end
end
function F.sabotageCost(d) return math.max(E.sabotageCost, math.floor(F.incomePerSec(d) * E.sabotageSeconds)) end
function F.sabotage(plr, d, targetId, now)
	if not F.unlocked(d, "sabotage") then return end
	local target = Players:GetPlayerByUserId(targetId)
	local td = target and data[target]
	if not td or target == plr then return end
	if F.hasPass(target, "shield") then
		notify(plr, "🛡️ " .. target.Name .. " has a Freeze Shield!")
		return
	end
	local cost = F.sabotageCost(d)
	if now < d.sabCooldown or d.cash < cost then return end
	d.cash -= cost
	d.sabCooldown = now + CFG.SABOTAGE_COOLDOWN
	td.frozenUntil = now + CFG.SABOTAGE_TIME
	F.setIce(td.plot, true)
	burst(td.plot.center + V3(0, 8, 0), RGB(170, 225, 255), 80)
	announceAll("❄️ " .. plr.Name .. " froze " .. target.Name .. "'s income for " .. CFG.SABOTAGE_TIME .. "s!")
end

-- ===== STAFF =====
function F.hireCost(slot)
	local r = STAFF_ROLES[slot]
	if r.cost then return r.cost end
	return math.max(150, BIZ[slot].cost * 3)
end
function F.trainCost(slot, s) return math.floor(F.hireCost(slot) * 0.8 * s.exp) end
function F.candidates(d, slot)
	if not d.cands[slot] then
		local list = {}
		for i = 1, 3 do list[i] = {name = NAMES[math.random(#NAMES)], service = math.random(1, 4), speed = math.random(1, 4), exp = 1} end
		d.cands[slot] = list
	end
	return d.cands[slot]
end

-- ===== PROBLEMS =====
function F.makeProblem(plr, d, now)
	local owned = {}
	for _, b in ipairs(BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 and not d.problems[b.key] and (d.immune[b.key] or 0) < now then table.insert(owned, b.key) end
	end
	if #owned == 0 then return end
	local key = owned[math.random(#owned)]
	if F.crewSteady and F.crewSteady(d, key) and math.random() < 0.5 then return end   -- v14: Steady Hands on staff
	local ti = math.random(C.PROBLEM_RANDOM)   -- (the story's inspection is a problem type too, but never a random one)
	if d.rebirths >= 50 then
		notify(plr, "🔧 Your crew auto-fixed a problem at your " .. BIZ[key].name .. " (" .. PROBLEMS[ti].text .. ")")
		return
	end
	local _, per = F.income(d, now)
	local eng = d.staff.engineer
	local discount = eng and (1 - 0.04 * staffStars(eng)) or 1
	local repair = math.max(E.repairFloor, math.floor((per[key] or 0) * E.repairSeconds * discount))
	d.problems[key] = {type = ti, repair = repair, replace = repair * 4, state = "new"}
	F.problemVisual(plr, key, true)
	F.refreshWorkers(plr)
	notify(plr, "⚠️ PROBLEM at your " .. BIZ[key].name .. ": " .. PROBLEMS[ti].text)
	if F.managerOnProblem then F.managerOnProblem(plr, d, key) end
end
function F.resolveProblem(plr, d, key, choice, now)
	local pr = d.problems[key]
	if not pr or pr.state ~= "new" then return end
	if choice == "repair" or choice == "replace" then
		local cost = choice == "repair" and pr.repair or pr.replace
		if d.cash < cost then
			notify(plr, "Not enough cash!")
			return
		end
		d.cash -= cost
		d.problems[key] = nil
		F.problemVisual(plr, key, false)
		F.refreshWorkers(plr)
		if choice == "replace" then
			d.immune[key] = now + 300
			F.addRep(plr, 5)
			notify(plr, "✅ Replaced! No problems at this business for 5 minutes.")
		else
			notify(plr, "🔧 Repaired!")
		end
	elseif choice == "ignore" then
		pr.state = "ignored"
		pr.untilT = now + 120
		F.addRep(plr, -10)
		notify(plr, "😬 Ignored. That business earns -50% and customers are unhappy for 2 minutes.")
	end
	if F.storyEvent then F.storyEvent(plr, "problemResolved", key, choice) end
end
function F.problemChance(d)
	local eng = d.staff.engineer
	local c = 0.6 * (eng and (1 - 0.05 * staffStars(eng)) or 1)
	if F.homeHood(d) == "oldtown" then c *= 0.7 end
	return c * F.comboPerk(d, "problems") * (F.mysteryPerk and F.mysteryPerk(d, "problems") or 1)
end

-- ===== STOCK MARKET =====
function F.updateStocks(now)
	for _, d in pairs(data) do
		local c = d.company
		local inc = F.income(d, now)
		local fundamental = 10 + inc / 8 + d.rep / 15 + F.countLots(d) * 25
		c.crashF = math.min(1, c.crashF + 0.02)
		local target = fundamental * c.crashF
		c.price = math.max(1, c.price + (target - c.price) * 0.15 + c.price * (math.random() - 0.5) * 0.06)
		table.insert(c.hist, c.price)
		if #c.hist > 24 then table.remove(c.hist, 1) end
	end
end
function F.crashStocks()
	for _, d in pairs(data) do
		d.company.price *= 0.65
		d.company.crashF = 0.65
	end
end
function F.tradeStock(plr, d, ownerId, action, qty)
	if not F.unlocked(d, "market") then return end
	if not C.int(ownerId, 1) then return end
	local owner = Players:GetPlayerByUserId(ownerId)
	local od = owner and data[owner]
	if not od then return end
	local price = od.company.price
	-- prices and balances are server-side only; qty must be a sane whole number
	qty = C.int(qty, 0, CFG.MAX_SHARES_PER_ORDER)
	if not qty or not C.finite(price) then return end
	if action == "buy" then
		if qty < 1 then return end
		-- position limit: at most ~20 minutes of your own income in any one company. Crash dips recover on
		-- their own, so without a limit a rich player could park their whole bank in shares every crash.
		local limit = math.max(5000, F.incomePerSec(d) * E.stockPositionSeconds)
		local room = math.floor((limit - (d.shares[ownerId] or 0) * price) / price)
		if room < 1 then
			notify(plr, "📈 That's as many shares as you can hold in one company ($" .. fmt(limit) .. ", about 20 minutes of your income).")
			return
		end
		qty = math.min(qty, room)
		local cost = price * qty
		if d.cash < cost then
			notify(plr, "Not enough cash for " .. qty .. " shares.")
			return
		end
		d.cash -= cost
		d.shares[ownerId] = (d.shares[ownerId] or 0) + qty
		if owner ~= plr then
			od.cash += cost * 0.1
			notify(owner, "📈 " .. plr.Name .. " invested $" .. fmt(cost) .. " in your company! You got $" .. fmt(cost * 0.1) .. " in capital.")
		end
	elseif action == "sell" then
		local have = d.shares[ownerId] or 0
		if qty <= 0 or qty > have then qty = have end
		if qty <= 0 then return end
		d.shares[ownerId] = have - qty
		local payout = price * qty * (1 - CFG.STOCK_SELL_FEE)
		d.cash += payout
		notify(plr, "💵 Sold " .. qty .. " shares for $" .. fmt(payout) .. " (after the " .. math.floor(CFG.STOCK_SELL_FEE * 100 + 0.5) .. "% trading fee)")
	end
end

-- ===== BUSINESS LAND =====
function F.buyLot(plr, lot)
	-- v10: land is bought through the real-estate rules (limits, deeds, choosing a business)
	if F.buyPlot then return F.buyPlot(plr, lot) end
	local d = data[plr]
	if not d then return end
	if lot.owner then
		if lot.owner ~= plr then notify(plr, "This lot is owned by " .. lot.owner.Name) end
		return
	end
	local dd = DISTRICT[lot.dkey]
	if F.tierIndex(d.rep) < dd.tier then
		notify(plr, "🔒 " .. dd.name .. " lots need reputation: " .. REP_TIERS[dd.tier].name)
		return
	end
	if d.cash < dd.cost then
		notify(plr, "You need $" .. fmt(dd.cost) .. " for this lot.")
		return
	end
	d.cash -= dd.cost
	lot.owner = plr
	d.lots[lot.id] = true
	F.buildLot(lot)
	F.addRep(plr, 10)
	burst(lot.pos + V3(0, 8, 0), dd.color, 100)
	F.buzz(dd.icon, plr.Name .. " bought land in " .. dd.name .. "! They control " .. F.countLots(d) .. " lots.", dd.color)
end

-- ===== ADVERTISING =====
-- an ad costs its listed price or a few minutes of income, whichever is more (so it stays a real decision)
function F.adCost(d, key)
	local ad = ADS_BY[key]
	local i = table.find(ADS, ad) or 1
	return math.max(ad.cost, math.floor(F.incomePerSec(d) * (E.adSeconds[i] or 60)))
end
function F.runAd(plr, d, key, now)
	local ad = ADS_BY[key]
	if not ad then return end
	if not F.unlocked(d, "ads") then return end
	if d.adUntil > now then
		notify(plr, "A campaign is already running!")
		return
	end
	local cost = F.adCost(d, key)
	if d.cash < cost then
		notify(plr, "You need $" .. fmt(cost) .. " for a " .. ad.name .. ".")
		return
	end
	d.cash -= cost
	d.adKey = key
	d.adUntil = now + ad.dur
	if ad.marketing then d.marketing = true end
	F.buzz("📣", plr.Name .. "'s " .. ad.name .. " is live!", RGB(255, 170, 60))
	if F.rivalAct then F.rivalAct(plr, "ad") end
	F.checkCombos(plr, d)
end

-- ===== CITY EVENTS =====
function F.startEvent(now, forceKey)
	-- small events wait while a mega event is running
	if G.megaActive then
		G.nextEvent = now + 20
		return
	end
	-- only one city event at a time: end the current one (and every bonus it gave) first
	if G.event then F.endEvent() end
	local pool = {}
	for _, e in ipairs(EVENTS) do
		if not e.era or G.spire.era >= e.era then table.insert(pool, e) end
	end
	local ev = pool[math.random(#pool)]
	if forceKey then
		for _, e in ipairs(EVENTS) do if e.key == forceKey then ev = e end end
	end
	G.nextEvent = now + math.max(CFG.EVENT_INTERVAL, (ev.dur or 0) + 10)
	local text = ev.text
	if ev.viral then
		local owned = {}
		for _, d in pairs(data) do
			for _, bb in ipairs(BUSINESSES) do
				if (d.levels[bb.key] or 0) > 0 then table.insert(owned, bb) end
			end
		end
		local b = #owned > 0 and owned[math.random(#owned)] or BUSINESSES[math.random(#BUSINESSES)]
		G.viralKey = b.key
		text = "📱 " .. b.name .. " is going VIRAL! " .. b.name .. " businesses earn 3x for " .. ev.dur .. "s"
		F.buzz("📱", "#" .. string.gsub(b.name, " ", "") .. " is trending citywide! " .. b.icon, b.color)
	end
	for _, d in pairs(data) do d.seen.events[ev.key] = true end
	C.setLook(ev.look)
	Workspace:SetAttribute("Weather", ev.weather or "none")
	if ev.dur then
		G.event = ev
		G.eventText = text
		G.eventEnds = now + ev.dur
	end
	if ev.crash then F.crashStocks() end
	if ev.concert then
		for _, sl in ipairs(C.stageLights) do sl.Brightness = 6 end
	end
	if ev.tax then
		for _, d in pairs(data) do d.cash *= (1 - ev.tax) end
	end
	if ev.investor then
		local lowP, lowD, lowI
		for p, d in pairs(data) do
			local inc = F.income(d, now)
			if not lowD or inc < lowI then lowP, lowD, lowI = p, d, inc end
		end
		if lowD then
			local gift = math.max(E.investorFloor, math.floor(lowI * E.investorSeconds))
			lowD.cash += gift
			notify(lowP, "😇 An angel investor gave you $" .. fmt(gift) .. "!")
			if F.cinematic and gift >= 1e5 then
				local at = F.playerAnchor(lowP)
				if at then F.cinematic(lowP, "investment", {amount = gift}, {at = at, title = "😇 A HUGE INVESTMENT", result = {"💰 +$" .. fmt(gift), "An angel investor believes in you"}, react = "money"}) end
			end
			burst(lowD.plot.center + V3(0, 12, 0), RGB(255, 215, 80), 120)
		end
	end
	if not ev.dur then
		task.delay(5, function()
			if not G.event then C.resetLook() end
		end)
	end
	announceAll("CITY EVENT: " .. text)
end
function F.endEvent()
	G.event = nil
	G.viralKey = nil
	G.eventText = nil
	for _, sl in ipairs(C.stageLights) do sl.Brightness = 0 end
	C.resetLook()
end

-- ===== CORNER WARS =====
function F.empireScore(d)
	local s = 0
	for _, b in ipairs(BUSINESSES) do s += (d.levels[b.key] or 0) + 5 * (d.chains[b.key] or 0) end
	for _ in pairs(d.combos) do s += 3 end
	return s + F.countLots(d) * 4 + F.tierIndex(d.rep) * 2 + #d.props * 3 + d.rebirths
end
function F.warScore(d, cat)
	if cat == "profit" then return d.war.earned end
	if cat == "customers" then return d.war.customers end
	if cat == "rep" then return d.war.rep end
	if cat == "empire" then return F.empireScore(d) end
	if cat == "district" then return d.war.starsN >= 3 and d.war.stars / d.war.starsN or 0 end
	return 0
end
local function warValueText(key, v)
	if key == "profit" then return "$" .. fmt(v) end
	if key == "district" then return string.format("%.1f★", v) end
	return fmt(v)
end
function F.warLeaders()
	local out = {}
	for _, c in ipairs(WAR_CATS) do
		local bestP, best = nil, 0
		for p, d in pairs(data) do
			local v = F.warScore(d, c.key)
			if v > best then bestP, best = p, v end
		end
		table.insert(out, {cat = c.name, key = c.key, name = bestP and bestP.Name or "—", value = warValueText(c.key, best), plr = bestP})
	end
	return out
end
function F.endWar(now)
	local results = {}
	-- a war needs rivals: with fewer than 2 empires playing, nobody "wins" (a solo player used to win
	-- all 5 categories every 10 minutes, which was a free +75% income)
	local playing = 0
	for _ in pairs(data) do playing += 1 end
	local contested = playing >= E.warMinPlayers
	for _, l in ipairs(F.warLeaders()) do
		table.insert(results, {cat = l.cat, name = contested and l.name or "—", value = contested and l.value or "needs 2+ empires"})
		local p = l.plr
		local d = contested and p and data[p]
		if d then
			if d.buffUntil > now then d.buffWins += 1 else d.buffWins = 1 end
			d.buffUntil = now + CFG.WAR_BUFF_TIME
			d.cash += F.income(d, now) * E.warSeconds
			d.ep += 1
			d.trophies += 1
			F.addRep(p, 30)
			F.refreshTower(p)
			if F.viralMoment then F.viralMoment(p, "competition", {}) end
		end
	end
	R.WarResults:FireAllClients(results)
	F.buzz("🏆", "CORNER WAR results are in! Winners get buffs, cash, trophies & rare skins.", RGB(255, 200, 60))
	for _, d in pairs(data) do
		d.war = {earned = 0, customers = 0, rep = 0, stars = 0, starsN = 0}
		if d.passes.richstart then d.cash += math.min(E.richStartWarMax, math.floor(F.income(d, now) * E.richStartWarSeconds)) end
	end
	G.warEnds = now + CFG.WAR_INTERVAL
end

-- ===== DELIVERIES =====
function F.deliveryTick(plr, d, now)
	if not F.unlocked(d, "deliveries") then return end
	local dl = d.delivery
	if not dl then
		if now >= d.nextDelivery then
			d.nextDelivery = now + math.random(80, 140)
			local owned = {}
			for _, b in ipairs(BUSINESSES) do
				if (d.levels[b.key] or 0) > 0 then table.insert(owned, b) end
			end
			if #owned == 0 then return end
			local b = owned[math.random(#owned)]
			local di = math.random(#DESTS)
			local inc = F.income(d, now)
			local dist = (DESTS[di].pos - d.plot.center).Magnitude
			d.delivery = {state = "offer", dest = di, biz = b.key, qty = math.random(5, 24),
				reward = math.floor(math.max(E.deliveryFloor, inc * E.deliverySeconds) * (0.8 + dist / 400)), expires = now + 25}
		end
		return
	end
	if now > dl.expires then
		if dl.state == "active" then
			notify(plr, "❌ Delivery failed — you ran out of time.")
			F.addRep(plr, -3)
		end
		d.delivery = nil
		return
	end
	if dl.state == "active" then
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local dest = DESTS[dl.dest]
		if root and (V3(root.Position.X, 0, root.Position.Z) - V3(dest.pos.X, 0, dest.pos.Z)).Magnitude < 12 then
			local reward = dl.reward
			local car = F.activeCar(plr)
			local bonus = car ~= nil and CAR[car.key].delivery == true and car.seat.Occupant ~= nil
			if bonus then reward = math.floor(reward * 1.5) end
			d.cash += reward
			F.earn(d, reward)
			d.war.earned += reward
			d.deliveries += 1
			F.addRep(plr, 5)
			d.delivery = nil
			R.Splash:FireClient(plr, "✅ DELIVERY COMPLETE", "+$" .. fmt(reward) .. (bonus and "  (Delivery Van bonus x1.5!)" or ""), RGB(90, 230, 120))
			burst(root.Position + V3(0, 4, 0), RGB(90, 230, 120), 60)
			if d.deliveries % 5 == 0 then F.buzz("🚚", plr.Name .. " has completed " .. d.deliveries .. " deliveries!", RGB(90, 230, 120)) end
		end
	end
end

-- ===== EMPIRE SPIRE =====
function F.spireGoal()
	local s = G.spire
	if s.stage < #SPIRE_STAGES then return SPIRE_STAGES[s.stage + 1].name, SPIRE_STAGES[s.stage + 1].cost end
	return "🌆 Era " .. (s.era + 1) .. ": " .. C.eraName(s.era + 1), E.eraGoalBase * E.eraGoalGrowth ^ (s.era - 2)
end
function F.contribute(plr, amount)
	local d = data[plr]
	if not d then return end
	local s = G.spire
	local name, goal = F.spireGoal()
	amount = math.floor(math.min(amount, d.cash, goal - s.progress))
	if amount < 1 then
		notify(plr, "You need cash to contribute!")
		return
	end
	d.cash -= amount
	s.progress += amount
	s.top[plr.Name] = (s.top[plr.Name] or 0) + amount
	d.contributed += amount
	F.addRep(plr, math.clamp(math.floor(amount / goal * 60), 1, 25))
	notify(plr, "🏗️ You contributed $" .. fmt(amount) .. " to the Empire Spire!")
	if s.progress < goal then return end
	s.progress = 0
	local function enterEra()
		s.era += 1
		local info = C.ERAS[math.min(s.era, #C.ERAS)]
		local unlocks = (s.era <= #C.ERAS and #info.unlocks > 0) and table.concat(info.unlocks, " • ") or "an even bigger income bonus"
		R.Splash:FireAllClients(info.icon .. " ERA " .. s.era .. ": " .. string.upper(C.eraName(s.era)) .. " " .. info.icon, "All income +" .. math.floor(E.eraBonus * 100 * (s.era - 1) + 0.5) .. "%  •  NEW: " .. unlocks, RGB(120, 220, 255))
		F.buzz(info.icon, "THE EMPIRE SPIRE IS COMPLETE! The city entered Era " .. s.era .. ": " .. C.eraName(s.era) .. "!", RGB(120, 220, 255))
		-- everyone who helped build this era keeps credit for it forever (Legacy Museum, Cyber skin)
		for p, dd in pairs(data) do
			if (s.top[p.Name] or 0) > 0 then
				dd.eraContrib = math.max(dd.eraContrib or 1, s.era)
				if F.achieve then F.achieve(p, "era" .. math.min(s.era, 5)) end
			end
		end
		if F.buildEraDecor then F.buildEraDecor(s.era) end
	end
	if s.stage < #SPIRE_STAGES then
		s.stage += 1
		if s.stage == #SPIRE_STAGES then
			enterEra()
		else
			R.Splash:FireAllClients("🏗️ SPIRE STAGE COMPLETE", name .. " is built! Next: " .. SPIRE_STAGES[s.stage + 1].name, RGB(255, 200, 60))
			F.buzz("🏗️", "Empire Spire progress: " .. name .. " complete!", RGB(255, 200, 60))
		end
	else
		enterEra()
	end
	burst(V3(0, 40, 0), RGB(255, 215, 80), 200)
	F.buildSpire(s.stage, s.era)
	for p, dd in pairs(data) do F.checkCombos(p, dd) end
end
F.buildSpire(0, 1)

-- ===== REBIRTH =====
function F.rebirthCost(d) return math.floor(REBIRTH.base * (1 + REBIRTH.step * d.rebirths)) end
function F.rebirth(plr)
	local d = data[plr]
	if not d then return end
	if not F.unlocked(d, "rebirth") then
		notify(plr, "🔒 Rebirth unlocks at " .. REP_TIERS[FEATURES.rebirth].name)
		return
	end
	local cost = F.rebirthCost(d)
	if d.cash < cost then
		notify(plr, "You need $" .. fmt(cost) .. " cash to rebirth.")
		return
	end
	d.rebirths += 1
	local n = d.rebirths
	local owned = {}
	for key, lvl in pairs(d.levels) do
		if lvl > 0 then owned[key] = true end
	end
	d.cash = CFG.START_CASH + (n >= 10 and E.rebirthTycoonCash or 0)
	d.levels = {}
	if n >= 50 then
		for key in pairs(owned) do d.levels[key] = 3 end
	end
	d.chains = {}
	if n < 10 then d.staff = {} end
	d.cands = {}
	for key in pairs(d.problems) do F.problemVisual(plr, key, false) end
	d.problems = {}
	d.immune = {}
	d.delivery = nil
	for _, b in ipairs(BUSINESSES) do F.refreshBuilding(plr, b.key, false) end
	F.refreshTower(plr, true)
	F.refreshWorkers(plr)
	burst(d.plot.center + V3(0, 20, 0), RGB(255, 120, 255), 250)
	C.shockwave(d.plot.center + V3(0, 2, 0), RGB(255, 120, 255), 90)
	local perkText = ""
	for _, p in ipairs(REBIRTH.perks) do
		if n == p.at then perkText = "  NEW PERK: " .. p.icon .. " " .. p.name .. " — " .. p.desc end
	end
	R.Splash:FireClient(plr, "♻️ REBIRTH #" .. n, "Permanent income bonus is now +" .. math.floor((F.rebirthMult(d) - 1) * 100 + 0.5) .. "%." .. perkText, RGB(255, 120, 255))
	F.buzz("♻️", plr.Name .. " was reborn! (Rebirth #" .. n .. ")", RGB(255, 120, 255))
	if perkText ~= "" then F.pushMsg(plr, {icon = "🎁", from = "Rebirth", text = perkText}) end
	F.applyCharacter(plr, plr.Character)
	if F.storyEvent then F.storyEvent(plr, "rebirth") end
	if F.achieve then
		for _, at in ipairs({1, 10, 50, 100}) do
			if n >= at then F.achieve(plr, "rebirth" .. at) end
		end
	end
	F.checkCombos(plr, d)
end

-- ===== TUTORIAL =====
-- Every step is checked by the server once a second against the player's real state, so a step can't be
-- missed because a message arrived at the wrong moment. Step 4 (open the phone) used to be the only step
-- finished by a one-shot client message: it only counted if it arrived while the server was already on
-- step 4, so opening the phone a moment early, or having it open when the step began, left the
-- tutorial stuck there forever. Now the client reports whether the phone is open, and the server checks
-- that like any other condition.
local RunService = game:GetService("RunService")
local tutDebugAt = {}
local function tutDebug(plr, d, why)
	if not (CFG.TUTORIAL_DEBUG and RunService:IsStudio()) then return end
	local key = plr.UserId .. ":" .. d.tut
	local now = os.clock()
	if tutDebugAt[key] and now - tutDebugAt[key] < 10 then return end
	tutDebugAt[key] = now
	print("[Tutorial] " .. plr.Name .. " is on step " .. d.tut .. " of " .. #TUTORIAL .. ": " .. why)
end
function F.tutorialEvent(plr, ev, value)
	local d = data[plr]
	if not d then return end
	if ev == "phone" then
		-- the client tells us every time the phone opens or closes (even from an app button or photo mode)
		d.phoneOpen = value ~= false
		if d.phoneOpen then d.phoneOpenedAt = os.clock() end
	end
end
function F.advanceTutorial(plr, d)
	-- each step pays once per save, ever: restarting the tutorial re-walks the steps without paying again
	if d.tut > (d.tutPaid or 0) then
		local reward = (C.ECONOMY and C.ECONOMY.tutorialReward or 250) * d.tut
		d.cash += reward
		d.tutPaid = d.tut
		notify(plr, "🎓 Tutorial step " .. d.tut .. " complete! +$" .. fmt(reward))
	else
		notify(plr, "✅ Tutorial step " .. d.tut .. " complete!")
	end
	if CFG.TUTORIAL_DEBUG and RunService:IsStudio() then print("[Tutorial] " .. plr.Name .. " finished step " .. d.tut) end
	d.tut += 1
	d.tutStepAt = os.clock()
	if d.tut > #TUTORIAL then
		d.tut = 0
		R.Splash:FireClient(plr, "🎓 TUTORIAL COMPLETE", "You know the basics. Now go build your empire! 👑", RGB(120, 220, 255))
		if F.storyEvent then F.storyEvent(plr, "tutorialDone") end
	end
end
local function cheapestCar()
	local best
	for _, c in ipairs(C.CARS) do
		if c.price and (not best or c.price < best.price) then best = c end
	end
	return best
end
-- is the step done, and what should the card say about the player's progress?
function F.tutorialStatus(plr, d)
	local s = d.tut
	if s == 1 then
		local cost = F.upgradeCost(d, "lemonade")
		if (d.levels.lemonade or 0) >= 1 then return true, "✅ Lemonade Stand open!" end
		if d.cash < cost then return false, "You need $" .. fmt(cost) .. " (you have $" .. fmt(d.cash) .. "). Your corner earns a little on its own: wait a few seconds.", "not enough cash for the stand" end
		return false, "🍋 Lemonade Stand: $" .. fmt(cost) .. " • tap BUY in the business panel", "stand not bought yet"
	elseif s == 2 then
		local lvl = d.levels.lemonade or 0
		if lvl >= 3 then return true, "✅ Level 3!" end
		if lvl == 0 then return false, "Your Lemonade Stand is gone: buy it again in the business panel.", "lemonade level 0" end
		local cost = F.upgradeCost(d, "lemonade")
		local p = "🍋 Level " .. lvl .. " / 3 • next upgrade $" .. fmt(cost)
		if d.cash < cost then return false, p .. " (you have $" .. fmt(d.cash) .. ": customers are paying you, hang on!)", "saving for the upgrade" end
		return false, p, "can afford the upgrade, waiting for the player to press it"
	elseif s == 3 then
		if (d.levels.icecream or 0) >= 1 then return true, "✅ Ice Cream Cart open!" end
		local cost = F.upgradeCost(d, "icecream")
		if d.cash < cost then return false, "🍦 Ice Cream Cart: $" .. fmt(cost) .. " (you have $" .. fmt(d.cash) .. "). Keep serving customers!", "saving for the ice cream cart" end
		return false, "🍦 Ice Cream Cart: $" .. fmt(cost) .. " • you can afford it, tap BUY!", "can afford the cart, waiting for the player to buy it"
	elseif s == 4 then
		-- open right now, or opened since this step began (a quick open-and-close between two ticks counts;
		-- 2s of slack covers an open that raced the step change)
		local opened = d.phoneOpen == true or (d.phoneOpenedAt ~= nil and d.phoneOpenedAt >= (d.tutStepAt or 0) - 2)
		if opened then return true, "✅ Phone opened!" end
		return false, "📱 Phone: not opened yet • press P, tap 📱 (bottom right), press Y on a controller, or use the button here",
			"phone not opened since this step began (phoneOpen=" .. tostring(d.phoneOpen) .. ")"
	elseif s == 5 then
		local lot = F.homeLot(d)
		if not lot then return true, "✅ (no home lot)" end
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not root then return false, "🏠 Respawning...", "no character" end
		local dist = (root.Position - lot.pos).Magnitude
		if dist < 32 then return true, "✅ Welcome home!" end
		return false, "🏠 " .. math.floor(dist) .. " studs to your home • follow the blue beam", "player is " .. math.floor(dist) .. " studs from home (needs < 32)"
	elseif s == 6 then
		local need = REP_TIERS[2].rep
		if F.tierIndex(d.rep) >= 2 then return true, "✅ LOCAL FAVORITE!" end
		local p = "⭐ Reputation " .. math.floor(d.rep) .. " / " .. need .. " • good reviews raise it, so keep businesses running and fix problems fast"
		return false, p, "reputation " .. math.floor(d.rep) .. " / " .. need
	elseif s == 7 then
		local car = F.activeCar(plr)
		local occ = car and car.seat.Occupant
		-- only YOUR character in YOUR car counts (a friend sitting in it doesn't finish your tutorial)
		if occ and plr.Character and occ.Parent == plr.Character then return true, "✅ Vroom!" end
		if car then return false, "🚗 Your car is waiting: walk up and hop in!", "car spawned, player not in the seat" end
		local owned = d.cars and next(d.cars) ~= nil
		if owned then return false, "🚗 Phone → Garage → spawn your car, then hop in!", "owns a car but hasn't spawned it" end
		local cheap = cheapestCar()
		local p = "🚗 Cheapest car: " .. cheap.name .. " $" .. fmt(cheap.price)
		if d.cash < cheap.price then return false, p .. " (you have $" .. fmt(d.cash) .. ", keep earning!)", "saving for a car" end
		return false, p .. " • Phone → Map → Dealership", "can afford a car, hasn't bought one"
	end
	return false, nil
end
function F.tutorialTick(plr, d)
	local s = d.tut
	if not s or s == 0 or not TUTORIAL[s] then return end
	local done, _, why = F.tutorialStatus(plr, d)
	if done then
		F.advanceTutorial(plr, d)
	elseif why then
		tutDebug(plr, d, "waiting: " .. why)
	end
end
function F.tutorialTarget(d)
	local s = d.tut
	if not s or s == 0 or not TUTORIAL[s] then return nil end
	local t = TUTORIAL[s].target
	if t == "plot" then return d.plot.center + V3(0, 1, 0) end
	if t == "home" then
		local lot = F.homeLot(d)
		return lot and lot.pos or nil
	end
	if t == "dealer" then return V3(0, 1, -160) end
	return nil
end
end
