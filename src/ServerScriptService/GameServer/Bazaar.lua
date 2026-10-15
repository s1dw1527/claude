-- CITY BAZAAR (v17): a shop that RESTOCKS EVERY 5 MINUTES with rare, Bazaar-only furniture (the hook behind
-- Grow a Garden's seed shop: everyone checks back for the rare one). The stock is worked out from the UTC clock
-- alone (the 5-minute window number seeds the roll), so EVERY SERVER SHOWS THE SAME STOCK at the same time:
-- "a Mythic is in the Bazaar right now" is true everywhere, and players can tell each other.
--   * 6 slots per restock, each rolled by rarity (Common .. 🌈 Mythic); each slot has a per-player quantity
--   * bought with in-game cash only; the price is the rarity's base price or a few minutes of the buyer's income,
--     whichever is more (so it stays meaningful at every stage). Bazaar items can't be sold back (no farming)
--   * what you bought this restock is saved in the slot (d.bazaar), so rejoining or hopping servers doesn't
--     reset your limit
--   * a restock with an Epic or better item is announced to the server (never to someone mid-ride/heist/cutscene)
--   * a stall in the plaza shows the countdown and the best item in stock
-- Definitions are data: C.BAZAAR (rules), C.BAZAAR_RARITY, C.BAZAAR_ITEMS (added to C.FURNITURE, shop = false).
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local P, surfaceText = C.P, C.surfaceText
local V3, CF, MAT = Vector3.new, CFrame.new, Enum.Material

C.BAZAAR = {window = 300, slots = 6, buyGap = 0.4, announceFrom = 4}   -- announceFrom = rarity index (4 = Epic)
C.BAZAAR_RARITY = {
	{key = "common",    name = "Common",    color = RGB(170, 175, 190), chance = 0.55,  qty = 3, base = 5000,      secs = 120},
	{key = "uncommon",  name = "Uncommon",  color = RGB(90, 200, 120),  chance = 0.25,  qty = 2, base = 25000,     secs = 300},
	{key = "rare",      name = "Rare",      color = RGB(70, 150, 255),  chance = 0.12,  qty = 1, base = 150000,    secs = 900},
	{key = "epic",      name = "Epic",      color = RGB(170, 90, 255),  chance = 0.06,  qty = 1, base = 1000000,   secs = 2400},
	{key = "legendary", name = "Legendary", color = RGB(255, 185, 40),  chance = 0.018, qty = 1, base = 10000000,  secs = 6000},
	{key = "mythic",    name = "🌈 Mythic", color = RGB(255, 80, 200),  chance = 0.002, qty = 1, base = 100000000, secs = 15000},
}
local RAR, RIDX = {}, {}
for i, r in ipairs(C.BAZAAR_RARITY) do RAR[r.key] = r RIDX[r.key] = i end
-- the Bazaar-only furniture (placed like any furniture; tier 1 so any home can show it off)
local A = "accent"
C.BAZAAR_ITEMS = {
	{key = "bz_flamingo", name = "Neon Flamingo", icon = "🦩", rarity = "common", score = 3, size = {1, 1}, light = {0, 3, 0},
		shape = {{0.3, 3, 0.3, 0, 1.5, 0, RGB(255, 90, 180), "Neon"}, {1.6, 1.2, 0.8, 0, 3.4, 0, RGB(255, 90, 180), "Neon"}}},
	{key = "bz_lavalamp", name = "Lava Lamp Tower", icon = "🧪", rarity = "common", score = 3, size = {1, 1}, light = {0, 3, 0},
		shape = {{1.4, 0.6, 1.4, 0, 0.3, 0, RGB(40, 40, 46), "Metal"}, {1, 4, 1, 0, 2.6, 0, RGB(255, 120, 40), "Neon"}}},
	{key = "bz_cactus", name = "Disco Cactus", icon = "🌵", rarity = "common", score = 2, size = {1, 1},
		shape = {{1.2, 4, 1.2, 0, 2, 0, RGB(60, 180, 90), "Grass"}, {1.6, 0.8, 1.6, 0, 0.4, 0, RGB(200, 120, 60), "Brick"}}},
	{key = "bz_gnome", name = "Golden Garden Gnome", icon = "🧙", rarity = "common", score = 2, size = {1, 1},
		shape = {{1.2, 2, 1.2, 0, 1, 0, RGB(255, 205, 60), "Metal"}, {1, 1.2, 1, 0, 2.6, 0, RGB(220, 40, 50)}}},
	{key = "bz_beanbag", name = "Galaxy Beanbag", icon = "🫘", rarity = "common", score = 2, size = {1, 1},
		shape = {{3, 1.6, 3, 0, 0.8, 0, RGB(60, 40, 140), "Fabric"}}},
	{key = "bz_neonsign", name = "\"OPEN 24/7\" Neon Sign", icon = "🔆", rarity = "common", score = 3, size = {1, 1}, light = {0, 3, 0},
		shape = {{3, 1.4, 0.3, 0, 3, 1.4, RGB(255, 60, 90), "Neon"}}},
	{key = "bz_popcorn", name = "Popcorn Machine", icon = "🍿", rarity = "uncommon", score = 4, size = {1, 1},
		shape = {{2.4, 2.4, 2, 0, 1.2, 0, RGB(200, 30, 40)}, {2.4, 2.4, 2, 0, 3.6, 0, RGB(255, 240, 200), "Glass"}}},
	{key = "bz_hammock", name = "Tropical Hammock", icon = "🌴", rarity = "uncommon", score = 4, size = {2, 1},
		shape = {{0.4, 4, 0.4, -3, 2, 0, RGB(120, 80, 50), "Wood"}, {0.4, 4, 0.4, 3, 2, 0, RGB(120, 80, 50), "Wood"}, {5.6, 0.3, 2, 0, 1.8, 0, RGB(255, 170, 60), "Fabric"}}},
	{key = "bz_gumball", name = "Giant Gumball Machine", icon = "🍬", rarity = "uncommon", score = 4, size = {1, 1},
		shape = {{1.8, 2.4, 1.8, 0, 1.2, 0, RGB(220, 40, 50)}, {2.6, 2.6, 2.6, 0, 3.7, 0, RGB(220, 240, 255), "Glass"}}},
	{key = "bz_jukebox", name = "Retro Jukebox", icon = "📻", rarity = "uncommon", score = 4, size = {1, 1}, light = {0, 3, -0.6},
		shape = {{3, 5, 2, 0, 2.5, 0.5, RGB(150, 60, 40), "Wood"}, {2.4, 2, 0.2, 0, 3.4, -0.55, RGB(255, 200, 80), "Neon"}}},
	{key = "bz_aquarium", name = "Aquarium Wall", icon = "🐠", rarity = "rare", score = 7, size = {2, 1}, light = {0, 3, 0},
		shape = {{7, 5, 1.6, 0, 3, 0.8, RGB(80, 170, 255), "Glass"}, {7.2, 0.6, 1.8, 0, 0.3, 0.8, RGB(30, 30, 36)}, {1, 0.6, 0.2, 1, 3, 0.2, RGB(255, 140, 40), "Neon"}}},
	{key = "bz_arcade", name = "Rainbow Arcade Cabinet", icon = "🕹️", rarity = "rare", score = 6, size = {1, 1}, light = {0, 4, -0.5},
		shape = {{3, 6, 2.4, 0, 3, 0.4, RGB(40, 30, 80)}, {2.4, 1.8, 0.2, 0, 4.4, -0.85, RGB(120, 255, 200), "Neon"}}},
	{key = "bz_meteor", name = "Meteor Rock", icon = "☄️", rarity = "epic", score = 9, size = {1, 1}, light = {0, 2, 0},
		shape = {{3, 2.6, 3, 0, 1.3, 0, RGB(60, 50, 60), "Basalt"}, {1.2, 1, 1.2, 0.6, 2.4, 0.3, RGB(255, 110, 40), "Neon"}}},
	{key = "bz_throne", name = "Velvet Throne", icon = "🪑", rarity = "epic", score = 9, size = {1, 1},
		shape = {{3, 1.4, 3, 0, 1.2, 0, RGB(150, 20, 50), "Fabric"}, {3, 5, 0.8, 0, 3.5, 1.2, RGB(255, 200, 60), "Metal"}}},
	{key = "bz_chandelier", name = "Diamond Chandelier", icon = "💠", rarity = "legendary", score = 12, size = {1, 1}, light = {0, 7, 0},
		shape = {{0.4, 6, 0.4, 0, 3.5, 0, RGB(220, 230, 255), "Metal"}, {3, 2, 3, 0, 7, 0, RGB(200, 240, 255), "Glass"}, {1.4, 1, 1.4, 0, 7, 0, RGB(255, 255, 255), "Neon"}}},
	{key = "bz_fountain", name = "Gold Fountain", icon = "⛲", rarity = "legendary", score = 13, size = {2, 2},
		shape = {{7, 1.2, 7, 0, 0.6, 0, RGB(255, 205, 60), "Metal"}, {6, 0.3, 6, 0, 1.2, 0, RGB(90, 190, 255), "Glass"}, {1, 4, 1, 0, 3, 0, RGB(255, 205, 60), "Metal"}}},
	{key = "bz_unicorn", name = "Rainbow Unicorn Statue", icon = "🦄", rarity = "mythic", score = 18, size = {1, 1}, light = {0, 5, 0},
		shape = {{2.6, 1, 2.6, 0, 0.5, 0, RGB(250, 250, 255), "Marble"}, {1.4, 4, 2.4, 0, 3, 0, RGB(255, 120, 230), "Neon"}}},
	{key = "bz_blackhole", name = "Pocket Black Hole", icon = "🌌", rarity = "mythic", score = 18, size = {1, 1}, light = {0, 3, 0},
		shape = {{3, 3, 3, 0, 2.5, 0, RGB(20, 0, 40), "Glass"}, {1.6, 1.6, 1.6, 0, 2.5, 0, RGB(170, 60, 255), "Neon"}}},
}
local POOL = {}
for _, it in ipairs(C.BAZAAR_ITEMS) do
	local r = RAR[it.rarity]
	it.cat, it.tier, it.shop, it.bazaar, it.cost = "Decor", 1, false, it.rarity, r.base
	table.insert(C.FURNITURE, it)
	C.FURNITURE_BY[it.key] = it
	POOL[it.rarity] = POOL[it.rarity] or {}
	table.insert(POOL[it.rarity], it)
end

local function now() return C.bazaarClock and C.bazaarClock() or os.time() end
local function mmss(sec) sec = math.max(0, math.floor(sec)) return string.format("%d:%02d", sec // 60, sec % 60) end
function F.bazaarWindow(t)
	local w = math.floor((t or now()) / C.BAZAAR.window)
	return w, (w + 1) * C.BAZAAR.window
end
-- the stock of window w: the same answer on every server (seeded from the window number alone)
local cache = {}
function F.bazaarStock(w)
	if cache[w] then return cache[w] end
	local rng = Random.new(w * 7919 + 104729)
	local out, used = {}, {}
	for i = 1, C.BAZAAR.slots do
		local roll, rar = rng:NextNumber(), C.BAZAAR_RARITY[1]
		local acc = 0
		for _, r in ipairs(C.BAZAAR_RARITY) do
			acc += r.chance
			if roll < acc then rar = r break end
		end
		local pool = POOL[rar.key] or POOL.common
		local it = pool[rng:NextInteger(1, #pool)]
		if used[it.key] then
			-- (no item twice in one restock: another of the same rarity, else the nearest rarity with one left)
			it = nil
			local start = RIDX[rar.key]
			for dist = 0, #C.BAZAAR_RARITY do
				for _, ri in ipairs({start - dist, start + dist}) do
					local r = C.BAZAAR_RARITY[ri]
					if not it and r then
						for _, cand in ipairs(POOL[r.key] or {}) do
							if not used[cand.key] then it, rar = cand, r break end
						end
					end
				end
				if it then break end
			end
		end
		used[it.key] = true
		out[i] = {slot = i, key = it.key, rarity = rar.key}
	end
	cache[w] = out
	-- (keep the last few windows only)
	for k in pairs(cache) do if k < w - 3 then cache[k] = nil end end
	return out
end
function F.bazaarPrice(d, rarity)
	local r = RAR[rarity]
	local ips = F.incomePerSec and F.incomePerSec(d) or 0
	return math.max(r.base, math.floor(ips * r.secs))
end
local function rec(d, w)
	local b = d.bazaar
	if type(b) ~= "table" or type(b.bought) ~= "table" then b = {win = w, bought = {}} d.bazaar = b end
	if b.win ~= w then b.win, b.bought = w, {} end
	return b
end
local lastBuy = {}
function F.bazaarBuy(plr, slot, w)
	local d = data[plr]
	if not d then return false end
	local t = os.clock()
	if lastBuy[plr] and t - lastBuy[plr] < C.BAZAAR.buyGap then return false end
	lastBuy[plr] = t
	slot = math.floor(tonumber(slot) or 0)
	local cur = F.bazaarWindow()
	if w ~= nil and tonumber(w) ~= cur then
		notify(plr, "🛍️ The Bazaar just restocked! Have a look at the new stock.", {pri = "critical", cat = "info"})
		return false
	end
	local s = F.bazaarStock(cur)[slot]
	if not s then return false end
	local it, r = C.FURNITURE_BY[s.key], RAR[s.rarity]
	local b = rec(d, cur)
	local got = tonumber(b.bought[tostring(slot)]) or 0
	if got >= r.qty then notify(plr, "🛍️ You've bought all of this restock's " .. it.name .. ". New stock in " .. mmss((cur + 1) * C.BAZAAR.window - now()) .. ".", {pri = "critical", cat = "info"}) return false end
	local price = F.bazaarPrice(d, s.rarity)
	if d.cash < price then notify(plr, "🛍️ " .. it.name .. " costs $" .. fmt(price) .. ".", {pri = "critical", cat = "warn"}) return false end
	d.furniture = type(d.furniture) == "table" and d.furniture or {}
	local owned = 0
	for _, n in pairs(d.furniture) do owned += tonumber(n) or 0 end
	if owned + 1 > 120 then notify(plr, "🛋️ Your storage is full (120 items). Place or sell some first.", {pri = "critical", cat = "warn"}) return false end
	d.cash -= price
	d.furniture[it.key] = (tonumber(d.furniture[it.key]) or 0) + 1
	b.bought[tostring(slot)] = got + 1
	notify(plr, "🛍️ " .. it.icon .. " " .. r.name .. " " .. it.name .. " is in your furniture storage (-$" .. fmt(price) .. "). Place it with 🔨 Build at home.", {pri = "critical", cat = "money"})
	if F.track then F.track(plr, "bazaar") end
	if F.analyticsSink then F.analyticsSink(plr, price, "Bazaar", it.key) end
	if RIDX[s.rarity] >= RIDX.legendary then
		if F.analyticsCustom then F.analyticsCustom(plr, "BazaarRareBuy", RIDX[s.rarity]) end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= plr then notify(p, "🛍️ " .. plr.Name .. " just bought the " .. r.name .. " " .. it.icon .. " " .. it.name .. " from the Bazaar!", {pri = "low", cat = "info", key = "bazaarBuy"}) end
		end
	end
	return true
end
function F.bazaarInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local w, ends = F.bazaarWindow()
	local b = rec(d, w)
	local slots = {}
	for i, s in ipairs(F.bazaarStock(w)) do
		local it, r = C.FURNITURE_BY[s.key], RAR[s.rarity]
		local got = tonumber(b.bought[tostring(i)]) or 0
		slots[i] = {slot = i, key = s.key, name = it.name, icon = it.icon, rarity = s.rarity, rname = r.name, color = r.color, rank = RIDX[s.rarity],
			price = F.bazaarPrice(d, s.rarity), qty = r.qty, left = math.max(0, r.qty - got), score = it.score, w = it.size[1], d = it.size[2]}
	end
	return {win = w, endsIn = ends - now(), slots = slots, cash = d.cash}
end
local function send(plr)
	local info = F.bazaarInfo(plr)
	if info then R.Menu:FireClient(plr, "bazaar", info) end
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.bazaarInfo = function(plr) send(plr) end
C.ACTIONS.bazaarBuy = function(plr, d, a, b)
	F.bazaarBuy(plr, a, b)
	send(plr)
end
-- the best item in a window's stock (for the stall and the announcement)
function F.bazaarBest(w)
	local best
	for _, s in ipairs(F.bazaarStock(w)) do
		if not best or RIDX[s.rarity] > RIDX[best.rarity] then best = s end
	end
	return best
end

-- ===== the stall in the plaza =====
local stall
do
	local f = C.WORLD
	local base = P(f, V3(10, 1, 6), CF(30, 0.5, 126), RGB(120, 70, 40), MAT.WoodPlanks)
	base.Name = "BazaarStall"
	local counter = P(f, V3(10, 3, 2), CF(30, 2.5, 128), RGB(150, 90, 50), MAT.Wood)
	counter.Name = "BazaarCounter"
	local roof = P(f, V3(11, 0.6, 7), CF(30, 7.5, 126), RGB(200, 60, 140), MAT.Fabric)
	roof.Name = "BazaarRoof"
	for _, x in ipairs({-4.6, 4.6}) do
		local pole = P(f, V3(0.5, 6.4, 0.5), CF(30 + x, 4.2, 123.5), RGB(60, 40, 30), MAT.Wood)
		pole.Name = "BazaarPole"
	end
	stall = P(f, V3(9, 3, 0.4), CF(30, 5.4, 129.2), RGB(30, 18, 48), MAT.SmoothPlastic)
	stall.Name = "BazaarSign"
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Browse the Bazaar"
	pp.ObjectText = "🛍️ City Bazaar"
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = counter
	pp.Triggered:Connect(function(plr)
		send(plr)
		R.Menu:FireClient(plr, "openBazaar")
	end)
end
local shownWin
local function refreshStall(w)
	if shownWin == w then return end
	shownWin = w
	for _, x in ipairs(stall:GetChildren()) do if x:IsA("SurfaceGui") then x:Destroy() end end
	local best = F.bazaarBest(w)
	local it, r = C.FURNITURE_BY[best.key], RAR[best.rarity]
	local txt = "🛍️ CITY BAZAAR\nBest now: " .. it.icon .. " " .. string.upper(r.name) .. " " .. it.name .. "\nRestocks every 5 minutes"
	surfaceText(stall, Enum.NormalId.Front, txt, r.color)
	surfaceText(stall, Enum.NormalId.Back, txt, r.color)
end

-- ===== restocks: refresh the stall, tell open apps, announce an Epic or better =====
local told = {}
task.spawn(function()
	while true do
		local w = F.bazaarWindow()
		refreshStall(w)
		local best = F.bazaarBest(w)
		local rank = RIDX[best.rarity]
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			if d and told[plr] ~= w then
				told[plr] = w
				R.Menu:FireClient(plr, "bazaarPing", {win = w})
				if rank >= C.BAZAAR.announceFrom and (d.tut or 0) == 0 and not (F.playerBusy and F.playerBusy(plr)) then
					local it, r = C.FURNITURE_BY[best.key], RAR[best.rarity]
					notify(plr, "🛍️ RESTOCK! A " .. string.upper(r.name) .. " " .. it.icon .. " " .. it.name .. " is in the City Bazaar for 5 minutes!",
						{pri = rank >= RIDX.mythic and "normal" or "low", cat = "info", key = "bazaar"})
				end
			end
		end
		task.wait(2)
	end
end)
Players.PlayerRemoving:Connect(function(plr) told[plr], lastBuy[plr] = nil, nil end)
end
