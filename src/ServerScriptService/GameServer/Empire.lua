-- EMPIRE (v12): CITY TAKEOVER & BILLIONAIRE PROGRESSION.
--
--   EMPIRE VALUE   what the player's empire is really worth, worked out HERE from their saved assets (cash, every
--                  business upgrade and chain location, land deeds, apartment buildings, cars, home, HQ floors).
--   MILESTONES     $1M / $10M / $100M / $1B. Claimed once per save, only when the value is real (lifetime earned
--                  income must be at least 20% of the milestone, so admin-granted cash or a lucky one-off can't buy a
--                  title), rewards paid by the server, never by the client. A rebirth never takes one away.
--   CELEBRATION    fireworks over the player's tower, a camera moment, a splash and a CityBuzz post from the real event.
--   LIVING CITY    the Empire Tower on the plot grows a crown for every milestone (see F.empireCrown, drawn by Buildings).
--   HALL OF FAME   top empires across the whole game (OrderedDataStore, written only by the server), shown on the
--                  billboards at the Empire Plaza (EmpirePlaza) and in the Empire Hall window, with a Visit button.
--   FIRST MINUTES  the first-income / first-upgrade celebrations.
-- The client only ever ASKS (empInfo, empVisit); it never sends a value, a milestone or a reward.
return function(C)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local CFG, fmt, notify = C.CFG, C.fmt, C.notify
local BIZ, E, MS = C.BIZ, C.EMPIRE, C.EMPIRE_MILESTONES
local GROWTH = C.ECONOMY and C.ECONOMY.upgradeGrowth or 1.6

-- ===== the saved record (repaired on every read, never fatal) =====
local function rec(d)
	if type(d.empire) ~= "table" then d.empire = {} end
	local e = d.empire
	if type(e.ms) ~= "table" then e.ms = {} end
	for k, v in pairs(e.ms) do
		if not C.EMPIRE_MS[k] or type(v) ~= "number" then e.ms[k] = nil end
	end
	e.best = (type(e.best) == "number" and e.best == e.best and e.best >= 0) and e.best or 0
	e.pub = (type(e.pub) == "number" and e.pub >= 0) and e.pub or 0
	e.pubAt = (type(e.pubAt) == "number" and e.pubAt >= 0) and e.pubAt or 0
	e.visits = (type(e.visits) == "number" and e.visits >= 0) and e.visits or 0
	e.firstIncome = e.firstIncome == true
	e.firstUpgrade = e.firstUpgrade == true
	e.legacy = e.legacy == true
	e.seeded = e.seeded == true
	return e
end
C.EMPIRE_MS = {}
for i, m in ipairs(MS) do C.EMPIRE_MS[m.key] = m m.index = i end
F.empireRec = rec

-- ===== EMPIRE VALUE =====
-- Everything is counted at what the player PAID, so spending never lowers it and selling a building takes it out.
function F.empireValue(d)
	local v = math.max(0, tonumber(d.cash) or 0)
	for _, b in ipairs(C.BUSINESSES) do
		local lvl = math.max(0, math.floor(tonumber(d.levels[b.key]) or 0))
		if lvl > 0 then v += b.cost * (GROWTH ^ lvl - 1) / (GROWTH - 1) end
		local ch = math.max(0, math.floor(tonumber(d.chains[b.key]) or 0))
		for c = 1, math.min(ch, #C.CHAINS) do v += b.cost * GROWTH ^ (CFG.MAX_LEVEL - 1) * C.CHAINS[c].mult end
	end
	for _, deed in ipairs(d.deeds or {}) do v += tonumber(type(deed) == "table" and deed.paid) or 0 end
	for _, b in ipairs(d.props or {}) do v += F.rentalValue(b) end
	for _, car in ipairs(C.CARS) do
		if car.price and d.cars[car.key] == true then v += car.price end
	end
	local hl = F.homeLot and F.homeLot(d)
	if hl and d.home and (d.home.level or 0) > 0 then
		local hood = C.HOOD[hl.hood]
		v += hood.price + hood.build * (2.2 ^ d.home.level - 1) / 1.2
	end
	for _, f in ipairs(C.HQ_FLOORS or {}) do
		if f.n <= (F.hqLevel and F.hqLevel(d) or 0) then v += f.cost end
	end
	if v ~= v or v == math.huge then v = 0 end
	return math.floor(v)
end
-- how many milestones this save has reached (0-4): the "empire tier" that drives the tower, makeovers and the Hall
function F.empireTier(d)
	local n = 0
	for _, m in ipairs(MS) do if rec(d).ms[m.key] then n += 1 end end
	return n
end
local function tags(d)
	local out = ""
	for _, m in ipairs(MS) do if rec(d).ms[m.key] then out ..= m.tag end end
	return out
end
-- the flagship: the business with the most levels (ties: the later one in the list)
local function flagship(d)
	local best, bestLvl
	for _, b in ipairs(C.BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 and (not bestLvl or lvl >= bestLvl) then best, bestLvl = b, lvl end
	end
	if not best then return nil end
	return {key = best.key, name = F.bizName(d, best.key), icon = (d.brands and d.brands[best.key] and d.brands[best.key].logo) or best.icon, level = bestLvl}
end
F.empireFlagship = flagship

-- the small packet in every state update (the HUD's 📊 MY EMPIRE window shows it)
function F.empireBrief(d)
	local e = rec(d)
	local v = F.empireValue(d)
	local nextM
	for _, m in ipairs(MS) do if not e.ms[m.key] then nextM = m break end end
	local out = {value = v, tier = F.empireTier(d), tags = tags(d)}
	if nextM then
		local prev = 0
		for _, m in ipairs(MS) do if m.index == nextM.index - 1 then prev = m.value end end
		out.next = {key = nextM.key, name = nextM.name, icon = nextM.icon, short = nextM.short, value = nextM.value,
			pct = math.clamp((v - prev) / (nextM.value - prev), 0, 1), legit = (tonumber(d.earned) or 0) >= nextM.value * E.earnedShare}
	end
	return out
end

-- ===== the tower anchor: where the camera and the fireworks go =====
local function towerBase(d) return d.plot.at(38.5, 1, -26) end
local function towerTop(d)
	local t = d.plot.tower
	local top = t and t:GetAttribute("Top") or 40
	return towerBase(d) + V3(0, top, 0)
end
F.empireTowerTop = towerTop
function F.empireTowerAnchor(d)
	local base = towerBase(d)
	local door = base + V3(0, 0, 9 * d.plot.fz)
	return F.facingOut and F.facingOut(V3(door.X, base.Y, door.Z), V3(base.X, base.Y, base.Z)) or CF(door)
end

for _, m in ipairs(C.EMPIRE_MILESTONES) do
	C.ACHIEVEMENTS["empire_" .. m.key] = {icon = m.icon, title = m.name, post = m.icon .. " My empire is worth " .. m.short .. "! It started with one lemonade stand. " .. m.icon}
end
-- viral moments that belong to this update (the table is shared with ViralMoments, which loads first)
C.VIRAL_MOMENTS.empireMilestone = {icon = "👑", title = "{name} reached {short}", score = 400, cat = "empire", importance = "high", once = true, rare = true,
	posts = {"👑 {name} just hit {short}! It started with ONE lemonade stand.", "BREAKING: {name}'s empire is now worth {short}. Take a picture, it's the tower."}}
C.VIRAL_MOMENTS.tierOpening = {icon = "🎊", title = "Grand Re-Opening", score = 80, cat = "biz", importance = "normal", once = true,
	posts = {"🎊 {name}'s {biz} just got a GRAND RE-OPENING. Free samples (not actually free)."}}

-- ===== LIVING CITY: the tower grows a crown, storefronts dress up =====
-- called by Buildings.refreshTower inside the tower model. base = ground point under the tower, topY = height of the last floor.
function F.empireCrown(m, base, topY, tier, accent)
	if tier <= 0 then return topY end
	local P, ball, cyl, sparkle = C.P, C.ball, C.cyl, C.sparkle
	local GOLD = RGB(255, 205, 60)
	-- 1+: a gold crown band and a helipad
	P(m, V3(9, 0.8, 9), CF(base + V3(0, topY + 0.4, 0)), GOLD, Enum.Material.Metal, {CanCollide = true})
	cyl(m, 0.3, 6, CF(base + V3(0, topY + 0.9, 0)), RGB(40, 40, 50), Enum.Material.Concrete, {CanCollide = false})
	local h = topY + 1
	if tier >= 2 then -- 2+: a glowing spire
		cyl(m, 14, 0.8, CF(base + V3(0, h + 7, 0)), GOLD, Enum.Material.Metal, {CanCollide = false})
		ball(m, V3(1.6, 1.6, 1.6), CF(base + V3(0, h + 14.5, 0)), RGB(255, 245, 160), Enum.Material.Neon)
		h += 15
	end
	if tier >= 3 then -- 3+: a light beam you can see across the city
		local beam = C.ghost(m, CF(base + V3(0, h + 60, 0)))
		beam.Size = V3(2, 120, 2)
		beam.Color = GOLD
		beam.Material = Enum.Material.Neon
		beam.Transparency = 0.75
		local L = Instance.new("PointLight") L.Range = 70 L.Brightness = 3 L.Color = GOLD L.Parent = beam
		sparkle(beam, GOLD, 10)
	end
	if tier >= 4 then -- 4: the billionaire crown, a slowly turning ring of gold
		local ring = cyl(m, 0.8, 16, CF(base + V3(0, h + 6, 0)), GOLD, Enum.Material.Neon, {Transparency = 0.1, CanCollide = false})
		C.spin(ring, 0.8)
		C.billboard(ring, UDim2.fromOffset(240, 60), V3(0, 6, 0), {{text = "👑 BILLIONAIRE", h = 0.6, color = GOLD}}, 800)
	end
	return h
end

-- extra look for a storefront: the empire tier opens richer styles, the chosen style decorates the front.
-- o = slot CFrame (front is +Z), top = building height
function F.empireDress(m, o, d, key, top, tier)
	local P, cyl = C.P, C.cyl
	local b = d.brands and d.brands[key]
	local style = type(b) == "table" and b.style or "classic"
	local st = C.STOREFRONT[style]
	if not st or tier < st.need then style = "classic" end
	local GOLD = RGB(255, 205, 60)
	local function put(size, off, color, mat, props) return P(m, size, o * CF(off.X, off.Y, off.Z), color, mat, props or {CanCollide = false}) end
	if tier >= 1 then -- a richer street: planters + lamps beside every open business
		for _, sx in ipairs({-7.5, 7.5}) do
			put(V3(1.6, 1.2, 1.6), V3(sx, 0.9, 8.4), RGB(120, 90, 70), Enum.Material.Wood, {CanCollide = true})
			C.ball(m, V3(2, 2, 2), o * CF(sx, 2.3, 8.4), RGB(70, 160, 80), Enum.Material.Grass)
		end
	end
	if style == "modern" then
		put(V3(15, 0.3, 0.3), V3(0, top - 0.4, 8.3), RGB(230, 235, 245), Enum.Material.Metal)
		put(V3(15, 0.3, 0.3), V3(0, 0.5, 8.3), RGB(230, 235, 245), Enum.Material.Metal)
	elseif style == "neon" then
		local c = (F.brandAccent and F.brandAccent(d, key)) or RGB(255, 80, 200)
		put(V3(15, 0.4, 0.4), V3(0, top - 0.4, 8.4), c, Enum.Material.Neon)
		put(V3(15, 0.4, 0.4), V3(0, 0.6, 8.4), c, Enum.Material.Neon)
		for _, sx in ipairs({-7.5, 7.5}) do put(V3(0.4, top - 1, 0.4), V3(sx, top / 2, 8.4), c, Enum.Material.Neon) end
	elseif style == "retro" then
		for i = -3, 3 do
			put(V3(2.1, 0.4, 3), V3(i * 2.1, top - 1.5, 9.6), i % 2 == 0 and RGB(235, 60, 60) or RGB(250, 250, 250), Enum.Material.Fabric)
		end
	elseif style == "luxury" or style == "billionaire" then
		for _, sx in ipairs({-5.5, 5.5}) do put(V3(1, top - 0.5, 1), V3(sx, (top - 0.5) / 2, 9), GOLD, Enum.Material.Metal, {CanCollide = true}) end
		put(V3(12, 0.7, 1.4), V3(0, top - 0.2, 9), GOLD, Enum.Material.Metal)
		put(V3(3.2, 0.1, 6), V3(0, 0.35, 12.2), RGB(190, 30, 50), Enum.Material.Fabric)
		if style == "billionaire" then
			local crown = cyl(m, 0.5, 5, o * CF(0, top + 3, 0), GOLD, Enum.Material.Neon, {CanCollide = false})
			C.spin(crown, 1)
			local sp = C.ghost(m, o * CF(0, top + 3, 0))
			C.sparkle(sp, GOLD, 12)
		end
	end
end

-- ===== CELEBRATION =====
-- test = true plays the show without claiming or paying anything (the admin tool)
function F.empireCelebrate(plr, d, m, test)
	local top = towerTop(d)
	local big = m.index >= 4
	local color = m.color
	local shows = big and 14 or (m.index * 3 + 2)
	task.spawn(function()
		for i = 1, shows do
			if not plr.Parent then return end
			local pos = top + V3(math.random(-18, 18), math.random(4, 26), math.random(-18, 18))
			C.burst(pos, i % 3 == 0 and RGB(255, 255, 255) or (i % 2 == 0 and color or RGB(255, 210, 70)), big and 120 or 70)
			if i % 4 == 1 then C.shockwave(top + V3(0, -6, 0), color, 36 + m.index * 8) end
			task.wait(big and 0.45 or 0.6)
		end
	end)
	if big then
		R.Splash:FireAllClients(m.icon .. " " .. m.name .. "! " .. m.icon, plr.Name .. " just reached $1 BILLION!", color)
	else
		R.Splash:FireClient(plr, m.icon .. " " .. m.name .. "! " .. m.icon, "Your empire is worth " .. "$" .. fmt(m.value) .. "!", color)
	end
	if F.cinematic then
		F.cinematic(plr, "milestone", {name = m.name, icon = m.icon, short = m.short, index = m.index},
			{at = F.empireTowerAnchor(d), title = m.icon .. " " .. m.name, result = {m.icon .. " " .. m.name .. "!", "Empire value: $" .. fmt(m.value)},
			react = "celebrate", mode = "full", force = true, duringTutorial = true})
	end
	if not test then
		F.buzz(m.icon, plr.Name .. " just became a " .. m.name .. "! Their empire is worth $" .. fmt(m.value) .. " " .. m.icon, color, plr.Name, plr, true)
		if F.viralMoment then F.viralMoment(plr, "empireMilestone", {uniq = m.key, short = m.short}) end
	end
end

-- ===== CLAIMING (server-verified) =====
-- Returns the list of milestones claimed this call. All checks are on server data.
function F.checkEmpire(plr, d, now)
	local e = rec(d)
	local v = F.empireValue(d)
	if v > e.best then e.best = v end
	-- update day for a save from before v12: the milestones it already passed are RECOGNIZED (badges, tower,
	-- storefronts, one banner) but not paid out again. Only milestones reached from now on pay rewards.
	if not e.seeded then
		e.seeded = true
		if e.legacy then
			local top
			for _, m in ipairs(MS) do
				if not e.ms[m.key] and v >= m.value and (tonumber(d.earned) or 0) >= m.value * E.earnedShare then
					e.ms[m.key] = os.time()
					top = m
					if F.achieve then F.achieve(plr, "empire_" .. m.key) end
				end
			end
			if top then
				if F.refreshTower then F.refreshTower(plr, true) end
				for _, bz in ipairs(C.BUSINESSES) do if (d.levels[bz.key] or 0) > 0 then F.refreshBuilding(plr, bz.key, false) end end
				R.Splash:FireClient(plr, top.icon .. " WELCOME BACK, " .. top.name .. "!", "Your empire is already worth $" .. fmt(v) .. ". The city noticed: look at your tower.", top.color)
				F.empirePublish(plr, d, true)
			end
			return nil
		end
	end
	local claimed
	for _, m in ipairs(MS) do
		if not e.ms[m.key] and v >= m.value and (tonumber(d.earned) or 0) >= m.value * E.earnedShare then
			e.ms[m.key] = os.time()
			claimed = claimed or {}
			table.insert(claimed, m)
			-- rewards: paid here, once. Cash is modest (1% of the milestone), the rest is reputation and fans.
			d.cash += m.cash
			if F.addRep then F.addRep(plr, m.rep) end
			d.followers = (d.followers or 0) + m.followers
			notify(plr, m.icon .. " " .. m.name .. "! +$" .. fmt(m.cash) .. ", +" .. fmt(m.rep) .. " reputation, +" .. fmt(m.followers) .. " followers")
			if F.achieve then F.achieve(plr, "empire_" .. m.key) end
		end
	end
	if claimed then
		if F.refreshTower then F.refreshTower(plr, true) end
		for _, bz in ipairs(C.BUSINESSES) do if (d.levels[bz.key] or 0) > 0 then F.refreshBuilding(plr, bz.key, false) end end
		F.empireCelebrate(plr, d, claimed[#claimed], false)
		F.empirePublish(plr, d, true)
		if F.storyEvent then F.storyEvent(plr, "empire", e) end
	end
	return claimed
end

-- ===== the first minutes: first income, first upgrade =====
function F.empireFirst(plr, what)
	local d = data[plr]
	if not d then return end
	local e = rec(d)
	if what == "income" and not e.firstIncome then
		e.firstIncome = true
		R.Splash:FireClient(plr, "💵 FIRST INCOME!", "Customers are paying you. This is how every empire starts.", RGB(120, 230, 150))
		if F.slotCF and (d.levels.lemonade or 0) > 0 then
			C.burst((F.slotCF(d.plot, "lemonade") * CF(0, 7, 0)).Position, RGB(120, 230, 150), 60)
		end
	elseif what == "upgrade" and not e.firstUpgrade then
		e.firstUpgrade = true
		R.Splash:FireClient(plr, "⭐ FIRST UPGRADE!", "Look at your stand. It just got better. Keep upgrading!", RGB(255, 210, 70))
	end
end
-- called from the main loop (every 5 s per player)
function F.empireTick(plr, d, now)
	local e = rec(d)
	-- first income = the first money the new stand makes (the empty corner earns a trickle before it, which doesn't count)
	if not e.firstIncome and (d.levels.lemonade or 0) > 0 then
		local earned = tonumber(d.earned) or 0
		if type(e.incomeBase) ~= "number" then
			e.incomeBase = earned
		elseif earned >= e.incomeBase + 10 then
			e.incomeBase = nil
			F.empireFirst(plr, "income")
		end
	end
	F.checkEmpire(plr, d, now)
	F.empirePublish(plr, d, false)
end

-- =====================================================================
-- THE HALL OF FAME (cross-server, written only by this server code)
-- =====================================================================
local ordered, info
if CFG.SAVE_ENABLED then
	local ok = pcall(function()
		ordered = DataStoreService:GetOrderedDataStore(C.storeName("CE_EmpireValue"))
		info = DataStoreService:GetDataStore(C.storeName("CE_Empires"))
	end)
	if not ok then ordered, info = nil, nil end
end
local mem = {}          -- userId -> entry (the fallback when DataStores are off, and what this server has published)
local published = {}    -- plr -> {at, value, tier}
local cache = {list = {}, at = 0}
C.HALL = cache

local function entryOf(plr, d)
	local fs = flagship(d)
	local v = F.empireValue(d)
	return {userId = plr.UserId, name = plr.Name, value = v, tier = F.empireTier(d), tags = tags(d), biz = fs and fs.name or nil, icon = fs and fs.icon or nil,
		public = (type(d.perms) == "table" and d.perms.business or "public") == "public", job = game.JobId, at = os.time()}
end
function F.empirePublish(plr, d, force)
	if d.noSave then return end
	local pubd = published[plr]
	local v = F.empireValue(d)
	local tier = F.empireTier(d)
	local now = os.clock()
	if not force and pubd and (now - pubd.at < E.publishGap or (math.abs(v - pubd.value) < math.max(1, pubd.value * E.publishDelta) and tier == pubd.tier)) then return end
	if not pubd and v <= 0 then return end
	published[plr] = {at = now, value = v, tier = tier}
	local entry = entryOf(plr, d)
	mem[plr.UserId] = entry
	if ordered and info then
		task.spawn(function()
			pcall(function()
				ordered:SetAsync(tostring(plr.UserId), math.clamp(v, 0, 9e15))
				info:SetAsync("u" .. plr.UserId, {n = entry.name, t = entry.tier, g = entry.tags, b = entry.biz, i = entry.icon, p = entry.public, j = entry.job, at = entry.at})
			end)
		end)
	end
end
local function refreshHall()
	local list = {}
	if ordered and info then
		local ok, pages = pcall(function() return ordered:GetSortedAsync(false, E.boardSize) end)
		if ok and pages then
			local ok2, page = pcall(function() return pages:GetCurrentPage() end)
			if ok2 and type(page) == "table" then
				for _, row in ipairs(page) do
					local uid = tonumber(row.key)
					local inf
					pcall(function() inf = info:GetAsync("u" .. uid) end)
					if uid and type(row.value) == "number" then
						table.insert(list, {userId = uid, value = row.value, name = type(inf) == "table" and tostring(inf.n or ("Player " .. uid)) or ("Player " .. uid),
							tier = type(inf) == "table" and tonumber(inf.t) or 0, tags = type(inf) == "table" and tostring(inf.g or "") or "",
							biz = type(inf) == "table" and inf.b or nil, icon = type(inf) == "table" and inf.i or nil, public = type(inf) ~= "table" or inf.p ~= false,
							job = type(inf) == "table" and inf.j or nil})
					end
				end
			end
		end
	end
	cache.list, cache.at = list, os.clock()
end
F.refreshHall = refreshHall
-- the board as the player sees it: the cross-server list, with everybody in THIS server up to date, best 10
function F.hallList(plr)
	local byId = {}
	for _, row in ipairs(cache.list) do byId[row.userId] = row end
	for uid, row in pairs(mem) do
		if not byId[uid] or byId[uid].value < row.value then byId[uid] = row end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local pd = data[p]
		if pd and F.empireValue then
			local row = entryOf(p, pd)
			if row.value > 0 then byId[p.UserId] = row end
		end
	end
	local out = {}
	for _, row in pairs(byId) do table.insert(out, row) end
	table.sort(out, function(a, b) return a.value > b.value end)
	while #out > E.boardSize do table.remove(out) end
	local res = {}
	for i, row in ipairs(out) do
		local owner = Players:GetPlayerByUserId(row.userId)
		local here = owner ~= nil and data[owner] ~= nil
		local canVisit = false
		if here and plr and owner ~= plr then
			local od = data[owner]
			local key
			for _, b in ipairs(C.BUSINESSES) do if (od.levels[b.key] or 0) > 0 then key = b.key end end
			canVisit = F.canVisit ~= nil and F.canVisit(plr, owner, key or "lemonade")
		end
		table.insert(res, {rank = i, userId = row.userId, name = row.name, value = row.value, tier = row.tier, tags = row.tags, biz = row.biz, icon = row.icon,
			here = here, canVisit = canVisit, me = plr ~= nil and row.userId == plr.UserId})
	end
	return res
end
task.spawn(function()
	while true do
		if next(data) ~= nil then
			local ok, err = pcall(function()
				refreshHall()
				if C.updateHallBoard then C.updateHallBoard(F.hallList(nil)) end
			end)
			if not ok then warn("[CornerEmpire] hall of fame refresh failed: " .. tostring(err)) end
		end
		task.wait(E.boardEvery)
	end
end)
-- keep the in-world billboards fresh for people standing in front of them (cheap: text only)
task.spawn(function()
	while true do
		task.wait(20)
		if next(data) ~= nil and C.updateHallBoard then pcall(function() C.updateHallBoard(F.hallList(nil)) end) end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	-- one last write so the board is right when they leave
	local d = data[plr]
	if d then pcall(F.empirePublish, plr, d, true) end
	published[plr] = nil
end)

-- =====================================================================
-- WHAT THE EMPIRE HALL WINDOW SHOWS
-- =====================================================================
function F.empireInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local e = rec(d)
	local brief = F.empireBrief(d)
	local list = {}
	for _, m in ipairs(MS) do
		table.insert(list, {key = m.key, name = m.name, icon = m.icon, short = m.short, value = m.value, perk = m.perk, rep = m.rep, cash = m.cash, followers = m.followers,
			done = e.ms[m.key] ~= nil, at = e.ms[m.key],
			legit = (tonumber(d.earned) or 0) >= m.value * E.earnedShare})
	end
	local styles = {}
	for _, s in ipairs(C.STOREFRONT_STYLES) do table.insert(styles, {k = s.k, name = s.name, icon = s.icon, need = s.need, desc = s.desc, open = brief.tier >= s.need}) end
	local biz = {}
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 then
			local bi = F.brandInfo and F.brandInfo(d, b.key)
			table.insert(biz, {key = b.key, icon = bi and bi.logo or b.icon, name = bi and bi.name or b.name, style = bi and bi.style or "classic"})
		end
	end
	return {brief = brief, biz = biz, milestones = list, hall = F.hallList(plr), best = e.best, earned = math.floor(tonumber(d.earned) or 0), visits = e.visits, styles = styles,
		earnedShare = E.earnedShare, me = plr.UserId, tags = brief.tags}
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.empInfo = function(plr)
	local info2 = F.empireInfo(plr)
	if info2 then R.Menu:FireClient(plr, "empireHall", info2) end
end

-- ===== visiting a public business =====
local visitAt = {}
function F.empireVisit(plr, targetId)
	local d = data[plr]
	if not d then return false end
	local now = os.clock()
	if now - (visitAt[plr] or -1e9) < E.visitCooldown then notify(plr, "🏙️ One trip at a time!") return false end
	local owner = Players:GetPlayerByUserId(targetId)
	local od = owner and data[owner]
	if not od then notify(plr, "🏙️ That empire isn't in this server right now.") return false end
	if owner ~= plr then
		local key
		for _, b in ipairs(C.BUSINESSES) do if (od.levels[b.key] or 0) > 0 then key = b.key end end
		if not (F.canVisit and F.canVisit(plr, owner, key or "lemonade")) then
			notify(plr, "🔒 " .. owner.Name .. " keeps their businesses " .. (rec(od) and "private") .. ".")
			return false
		end
	end
	local char = plr.Character
	if not char then return false end
	visitAt[plr] = now
	if F.cityOnTeleport then F.cityOnTeleport(plr) end
	F.despawnCar(plr)
	local plot = od.plot
	char:PivotTo(CFrame.lookAt(plot.at(0, 4, 34 + 6), plot.at(0, 4, -10)))
	if owner ~= plr then
		local oe = rec(od)
		oe.visits += 1
		notify(plr, "🏙️ Welcome to " .. owner.Name .. "'s empire! Walk up to a door to go inside.")
		notify(owner, "👋 " .. plr.Name .. " is visiting your empire!")
	end
	return true
end
C.ACTIONS.empVisit = function(plr, d, a)
	local id = C.int(a, 1)
	if id then F.empireVisit(plr, id) end
end
Players.PlayerRemoving:Connect(function(plr) visitAt[plr] = nil end)

-- =====================================================================
-- SCENES: HQ reveal and the big-upgrade grand re-opening
-- =====================================================================
function F.cineHQ(plr, d, floor)
	if not F.cinematic then return end
	return F.cinematic(plr, "hqReveal", {floor = floor.name, icon = floor.icon, level = floor.n, desc = floor.desc},
		{at = F.empireTowerAnchor(d), title = "🏢 HQ: " .. string.upper(floor.name) .. " FLOOR", result = {"🏢 " .. string.upper(floor.name), floor.desc},
		react = "celebrate", mode = floor.n >= 3 and "full" or "short", force = true})
end
-- a major business upgrade (a bigger building) is a grand re-opening, once per business and building
function F.tierOpening(plr, d, key, oldStage, newStage)
	local b = BIZ[key]
	d.openings = type(d.openings) == "table" and d.openings or {}
	local uniq = key .. "#" .. newStage
	if d.openings[uniq] then return false end
	d.openings[uniq] = os.time()
	local door = (F.slotCF(d.plot, key) * CF(0, 6, 9)).Position
	C.burst(door, b.color, 90)
	C.shockwave(door - V3(0, 5, 0), b.color, 30)
	if F.viralMoment then F.viralMoment(plr, "tierOpening", {uniq = uniq, biz = b.tiers[newStage], pos = door}) end
	if F.cinematic then
		F.cinematic(plr, "opening", {key = key, biz = b.tiers[newStage], icon = b.icon, crowd = true, signature = C.OPENING_SIGNATURE[key], tier = newStage},
			{at = F.bizAnchor(d, key), title = b.icon .. " GRAND RE-OPENING", result = {"🎉 GRAND RE-OPENING!", b.tiers[newStage] .. " is open for business"},
			react = "celebrate", mode = newStage >= 4 and "full" or "short"})
	end
	return true
end

-- ===== admin / Studio test: play a celebration without claiming anything =====
C.EMPIRE_ADMIN = {
	celebrate = function(plr, d, which)
		local m = C.EMPIRE_MS[which] or MS[1]
		F.empireCelebrate(plr, d, m, true)
		return m.name
	end,
}
end
