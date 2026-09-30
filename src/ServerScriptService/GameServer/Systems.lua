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
function F.countLots(d, dkey)
	local n = 0
	for id in pairs(d.lots) do
		if not dkey or LOTS[id].dkey == dkey then n += 1 end
	end
	return n
end

-- ===== ECONOMY =====
function F.passMult(d)
	local m = 1
	if d.passes.x4 then m = 4 elseif d.passes.x2 then m = 2 end
	if d.passes.vip then m *= 1.25 end
	return m
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
		d.cash += CFG.RICH_START_BONUS
		d.earned += CFG.RICH_START_BONUS
		notify(plr, "🎁 Rich Start: +$" .. fmt(CFG.RICH_START_BONUS) .. " to kick off your empire!")
	end
end
function F.bizMult(d, key)
	local m = 1
	local ev = G.event
	if ev and ev.biz and ev.biz[key] then m *= ev.biz[key] end
	if G.viralKey == key then m *= 3 end
	local s = d.staff[key]
	if s then m *= 1 + 0.04 * staffStars(s) end
	for _, c in ipairs(COMBOS) do
		if d.combos[c.key] and table.find(c.needs, key) then m *= c.mult end
	end
	for id in pairs(d.lots) do
		local boost = DISTRICT[LOTS[id].dkey].boost[key]
		if boost then m *= boost end
	end
	if F.homeHood(d) == "ocean" and (key == "lemonade" or key == "icecream") then m *= 1.25 end
	if G.megaBiz and G.megaBiz[key] then m *= G.megaBiz[key] end
	if d.problems[key] then m *= 0.5 end
	return m
end
function F.globalMult(d, now)
	local m = F.passMult(d)
	m *= 1 + 0.05 * (F.tierIndex(d.rep) - 1)
	if G.event and G.event.all then m *= G.event.all end
	if d.buffUntil > now then m *= 1 + 0.2 * d.buffWins end
	if d.adUntil > now then m *= ADS_BY[d.adKey].income end
	if (d.relaxedUntil or 0) > now then m *= 1 + C.FERRIS.buff end
	local mgr = d.staff.manager
	if mgr then m *= 1 + 0.02 * staffStars(mgr) end
	if (d.megaBuffUntil or 0) > now then m *= d.megaBuffMult or 1 end
	for id in pairs(d.lots) do
		local all = DISTRICT[LOTS[id].dkey].boost.all
		if all then m *= all end
	end
	m *= 1 + 0.2 * (G.spire.era - 1)
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
	for id in pairs(d.lots) do total += DISTRICT[LOTS[id].dkey].income end
	for _, b in ipairs(BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 then
			local base = b.income * lvl + b.income * 10 * (d.chains[b.key] or 0)
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
	local c = BIZ[key].cost * 1.5 ^ (d.levels[key] or 0)
	if G.event and G.event.crash then c *= CFG.CRASH_DISCOUNT end
	return math.floor(c)
end
function F.chainCost(d, key)
	local c = d.chains[key] or 0
	if c >= #CHAINS then return nil end
	return math.floor(BIZ[key].cost * CHAINS[c + 1].mult)
end

-- ===== REPUTATION + UNLOCKS =====
function F.addRep(plr, amount)
	local d = data[plr]
	if not d then return end
	if amount > 0 and F.homeHood(d) == "hills" then amount *= 1.15 end
	if amount > 0 and (d.viralUntil or 0) > os.clock() then amount *= 2 end
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
			F.pushMsg(plr, {icon = "🔓", from = "City Hall", text = "You reached " .. REP_TIERS[new].name .. "! New unlocks: " .. table.concat(REP_TIERS[new].unlocks, ", ") .. "."})
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
	local n = 0
	for _ in pairs(d.problems) do n += 1 end
	if d.problems[key] then s -= 30 end
	s += G.megaSatisfaction or 0
	s -= n * 4
	s += stageOf(d.levels[key] or 0, d.chains[key] or 0) * 2
	return math.clamp(s, 5, 100)
end
function F.customerRate(d, now)
	local levels = 0
	for _, b in ipairs(BUSINESSES) do levels += d.levels[b.key] or 0 end
	if levels == 0 then return 0 end
	local r = 0.15 + 0.04 * levels
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
		local pr = d.problems[key]
		if pr and stars <= 2 then text = PROBLEMS[pr.type].icon .. " " .. PROBLEMS[pr.type].text end
		review = {stars = stars, text = text}
	end
	R.Customer:FireAllClients({plot = plot.index, npc = ti, start = start, entry = entry, door = V3(door.X, 1, door.Z), t = travel, review = review})
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
	if F.countServed then F.countServed(d) end
	if d.frozenUntil <= now then
		local sale = BIZ[key].income * lvl * 4 * F.bizMult(d, key) * F.globalMult(d, now) * (t.tip or 1)
		d.cash += sale
		d.earned += sale
		d.war.earned += sale
	end
	if review then
		F.addRep(plr, ({-2, -1, 0, 1, 2})[review.stars])
		d.war.stars += review.stars
		d.war.starsN += 1
		d.revSum += review.stars
		d.revN += 1
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
	end
	if lvl + 1 == CFG.MAX_LEVEL then
		notify(plr, "⭐ " .. b.tiers[newStage] .. " is MAX level!" .. (F.unlocked(d, "chains") and " Open new locations to build a chain." or ""))
		F.refreshTower(plr)
	end
	if lvl == 0 and F.achieve then
		F.achieve(plr, "firstBusiness")
		F.achieve(plr, "biz_" .. key)
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
function F.sabotage(plr, d, targetId, now)
	if not F.unlocked(d, "sabotage") then return end
	local target = Players:GetPlayerByUserId(targetId)
	local td = target and data[target]
	if not td or target == plr then return end
	if F.hasPass(target, "shield") then
		notify(plr, "🛡️ " .. target.Name .. " has a Freeze Shield!")
		return
	end
	if now < d.sabCooldown or d.cash < CFG.SABOTAGE_COST then return end
	d.cash -= CFG.SABOTAGE_COST
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
	local ti = math.random(#PROBLEMS)
	if d.rebirths >= 50 then
		notify(plr, "🔧 Your crew auto-fixed a problem at your " .. BIZ[key].name .. " (" .. PROBLEMS[ti].text .. ")")
		return
	end
	local _, per = F.income(d, now)
	local eng = d.staff.engineer
	local discount = eng and (1 - 0.04 * staffStars(eng)) or 1
	local repair = math.max(100, math.floor((per[key] or 0) * 30 * discount))
	d.problems[key] = {type = ti, repair = repair, replace = repair * 4, state = "new"}
	F.problemVisual(plr, key, true)
	F.refreshWorkers(plr)
	notify(plr, "⚠️ PROBLEM at your " .. BIZ[key].name .. ": " .. PROBLEMS[ti].text)
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
function F.runAd(plr, d, key, now)
	local ad = ADS_BY[key]
	if not ad then return end
	if not F.unlocked(d, "ads") then return end
	if d.adUntil > now then
		notify(plr, "A campaign is already running!")
		return
	end
	if d.cash < ad.cost then
		notify(plr, "You need $" .. fmt(ad.cost) .. " for a " .. ad.name .. ".")
		return
	end
	d.cash -= ad.cost
	d.adKey = key
	d.adUntil = now + ad.dur
	if ad.marketing then d.marketing = true end
	F.buzz("📣", plr.Name .. "'s " .. ad.name .. " is live!", RGB(255, 170, 60))
	F.checkCombos(plr, d)
end

-- ===== CITY EVENTS =====
function F.startEvent(now)
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
			local gift = math.max(2500, math.floor(lowI * 120))
			lowD.cash += gift
			notify(lowP, "😇 An angel investor gave you $" .. fmt(gift) .. "!")
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
	for _, l in ipairs(F.warLeaders()) do
		table.insert(results, {cat = l.cat, name = l.name, value = l.value})
		local p = l.plr
		local d = p and data[p]
		if d then
			if d.buffUntil > now then d.buffWins += 1 else d.buffWins = 1 end
			d.buffUntil = now + CFG.WAR_BUFF_TIME
			d.cash += F.income(d, now) * 90
			d.ep += 1
			d.trophies += 1
			F.addRep(p, 30)
			F.refreshTower(p)
		end
	end
	R.WarResults:FireAllClients(results)
	F.buzz("🏆", "CORNER WAR results are in! Winners get buffs, cash, trophies & rare skins.", RGB(255, 200, 60))
	for _, d in pairs(data) do
		d.war = {earned = 0, customers = 0, rep = 0, stars = 0, starsN = 0}
		if d.passes.richstart then d.cash += CFG.RICH_START_BONUS end
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
				reward = math.floor(math.max(400, inc * 45) * (0.8 + dist / 400)), expires = now + 25}
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
			d.earned += reward
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
	return "🌆 Era " .. (s.era + 1) .. ": " .. C.eraName(s.era + 1), 40000000 * 3 ^ (s.era - 2)
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
		R.Splash:FireAllClients(info.icon .. " ERA " .. s.era .. ": " .. string.upper(C.eraName(s.era)) .. " " .. info.icon, "All income +" .. (20 * (s.era - 1)) .. "%  •  NEW: " .. unlocks, RGB(120, 220, 255))
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
	d.cash = CFG.START_CASH + (n >= 10 and 25000 or 0)
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
	if F.achieve then
		for _, at in ipairs({1, 10, 50, 100}) do
			if n >= at then F.achieve(plr, "rebirth" .. at) end
		end
	end
	F.checkCombos(plr, d)
end

-- ===== TUTORIAL =====
function F.tutorialEvent(plr, ev)
	local d = data[plr]
	if not d or d.tut == 0 then return end
	if ev == "phone" and d.tut == 4 then F.advanceTutorial(plr, d) end
end
function F.advanceTutorial(plr, d)
	-- each step pays once per save, ever: restarting the tutorial re-walks the steps without paying again
	if d.tut > (d.tutPaid or 0) then
		local reward = 250 * d.tut
		d.cash += reward
		d.tutPaid = d.tut
		notify(plr, "🎓 Tutorial step complete! +$" .. fmt(reward))
	end
	d.tut += 1
	if d.tut > #TUTORIAL then
		d.tut = 0
		R.Splash:FireClient(plr, "🎓 TUTORIAL COMPLETE", "You know the basics. Now go build your empire! 👑", RGB(120, 220, 255))
	end
end
function F.tutorialTick(plr, d)
	local s = d.tut
	if not s or s == 0 then return end
	local done = false
	if s == 1 then
		done = (d.levels.lemonade or 0) >= 1
	elseif s == 2 then
		done = (d.levels.lemonade or 0) >= 3
	elseif s == 3 then
		done = (d.levels.icecream or 0) >= 1
	elseif s == 5 then
		local lot = F.homeLot(d)
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		done = (not lot) or (root and (root.Position - lot.pos).Magnitude < 32)
	elseif s == 6 then
		done = F.tierIndex(d.rep) >= 2
	elseif s == 7 then
		local car = F.activeCar(plr)
		done = car ~= nil and car.seat.Occupant ~= nil
	end
	if done then F.advanceTutorial(plr, d) end
end
function F.tutorialTarget(d)
	local s = d.tut
	if not s or s == 0 then return nil end
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
