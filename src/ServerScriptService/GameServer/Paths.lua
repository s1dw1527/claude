-- PATHS (v16): three ways to build an empire, on the SAME economy (no new currency, nothing locked for good):
--   💼 BUSINESS MOGUL    serve customers, Rush Orders, upgrades, theater shows, building your park
--   🕶️ UNDERWORLD OPERATOR  heists that make it home to the mountain base (the existing heist system; fictional)
--   👑 EMPIRE LEGEND     both on the same day, and mixed contracts
-- Each path has XP and levels (with titles for your 🪪 showcase and a little reputation per level) and one
-- CONTRACT at a time: a bigger goal than a daily mission that pays more. The Underworld board opens once the
-- player has found the mountain base. Path progress lives in the save slot (d.path) and moves only from real
-- server events (F.track). The starting attitude chosen after the intro only picks the first suggested step.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify

C.PATHS_DEF = {
	{key = "mogul", icon = "💼", name = "Business Mogul", color = RGB(255, 205, 60),
		levels = {"Shopkeeper", "Entrepreneur", "Business Owner", "Executive", "Tycoon", "Mogul", "Magnate", "Business Legend"}},
	{key = "under", icon = "🕶️", name = "Underworld Operator", color = RGB(150, 90, 255),
		levels = {"Lookout", "Runner", "Crew Member", "Fixer", "Planner", "Mastermind", "Kingpin", "Underworld Legend"}},
	{key = "legend", icon = "👑", name = "Empire Legend", color = RGB(255, 120, 60),
		levels = {"Double Life", "Two-Faced", "Power Broker", "Shadow Tycoon", "Kingmaker", "City Legend", "Untouchable", "Empire Legend"}},
}
local PD = {}
for _, p in ipairs(C.PATHS_DEF) do PD[p.key] = p end
C.PATH_XP = {0, 100, 300, 700, 1500, 3000, 6000, 12000}
-- XP per event (only real server events)
C.PATH_GAIN = {serve = {"mogul", 1}, cook = {"mogul", 6}, upgrade = {"mogul", 10}, show = {"mogul", 5}, parkBuild = {"mogul", 4}, heist = {"under", 45}}
C.PATH_CFG = {legendDaily = 25, levelRep = 5, contractSecs = 900, contractMin = 4000, contractXP = 80}
-- contracts: kind = an F.track event (or parts = several), n scales with the tier (n × tier for "scale" ones)
C.CONTRACTS = {
	mogul = {
		{key = "m_serve", text = "Serve %d customers", kind = "serve", n = 40, scale = true},
		{key = "m_cook", text = "Serve %d perfect 🍳 Rush Orders", kind = "cook", n = 6},
		{key = "m_up", text = "Upgrade your businesses %d times", kind = "upgrade", n = 4},
		{key = "m_show", text = "Run %d 🎬 theater shows", kind = "show", n = 4, tier = 3},
		{key = "m_park", text = "Build %d things in your 🎢 park", kind = "parkBuild", n = 6, tier = 4},
	},
	under = {
		{key = "u_one", text = "Get %d heist home to the base", kind = "heist", n = 1},
		{key = "u_two", text = "Pull off %d heists without getting caught", kind = "heist", n = 2, tier = 4},
	},
	legend = {
		{key = "l_mix", text = "1 heist home + 8 perfect Rush Orders", parts = {{kind = "heist", n = 1}, {kind = "cook", n = 8}}},
		{key = "l_mix2", text = "1 heist home + serve 60 customers", parts = {{kind = "heist", n = 1}, {kind = "serve", n = 60}}},
	},
}
local CT = {}
for path, list in pairs(C.CONTRACTS) do for _, c in ipairs(list) do c.path = path CT[c.key] = c end end

local function rec(d)
	if type(d.path) ~= "table" then d.path = {} end
	local p = d.path
	p.xp = type(p.xp) == "table" and p.xp or {}
	for _, def in ipairs(C.PATHS_DEF) do p.xp[def.key] = math.max(0, math.floor(tonumber(p.xp[def.key]) or 0)) end
	p.contracts = type(p.contracts) == "table" and p.contracts or {}
	p.done = math.max(0, math.floor(tonumber(p.done) or 0))
	p.day = type(p.day) == "table" and p.day or {}
	return p
end
F.pathRec = rec
function F.pathLevel(xp)
	local lv = 1
	for i, need in ipairs(C.PATH_XP) do if xp >= need then lv = i end end
	return lv
end
local function underOpen(d) return type(d.heist) == "table" and d.heist.discovered == true end

-- a new contract for a path (the first one the save's tier allows that isn't the one just finished)
local function newContract(d, path, avoid)
	local tier = F.tierIndex(d.rep)
	local opts = {}
	for _, c in ipairs(C.CONTRACTS[path]) do
		if (c.tier or 1) <= tier and c.key ~= avoid then table.insert(opts, c) end
	end
	if #opts == 0 then return nil end
	local c = opts[math.random(#opts)]
	local entry = {key = c.key, p = {}, n = {}}
	if c.parts then
		for i, part in ipairs(c.parts) do entry.p[i], entry.n[i] = 0, part.n end
	else
		entry.p[1], entry.n[1] = 0, c.scale and c.n * tier or c.n
	end
	return entry
end
local function ensure(d)
	local p = rec(d)
	for _, path in ipairs({"mogul", "under", "legend"}) do
		local ok = path == "mogul" or underOpen(d)
		if ok and (type(p.contracts[path]) ~= "table" or not CT[p.contracts[path].key]) then p.contracts[path] = newContract(d, path) end
	end
	if p.bonus == true and type(p.contracts.bonus) ~= "table" then p.contracts.bonus = newContract(d, "mogul") end
	return p
end
local function contractDone(e) for i, need in ipairs(e.n) do if (tonumber(e.p[i]) or 0) < need then return false end end return true end

function F.pathXP(plr, d, path, amount)
	local p = rec(d)
	if not PD[path] then return end
	local before = F.pathLevel(p.xp[path])
	p.xp[path] += math.max(0, math.floor(amount))
	local after = F.pathLevel(p.xp[path])
	if after > before then
		local def = PD[path]
		local title = def.levels[after]
		F.addRep(plr, C.PATH_CFG.levelRep)
		local acct = F.acct and F.acct(plr)
		if acct then acct.wardrobe.titles[path .. after] = true end
		notify(plr, def.icon .. " " .. def.name .. " level " .. after .. ": " .. title .. "!", {pri = "critical", cat = "rep"})
		R.Splash:FireClient(plr, def.icon .. " " .. string.upper(title), def.name .. " level " .. after .. "  •  new title for your 🪪 showcase", def.color)
	end
	-- 👑 Legend: progress on BOTH sides on the same day
	if path ~= "legend" then
		local today = F.utcDay and F.utcDay() or 0
		p.day[path] = today
		if p.day.mogul == today and p.day.under == today and p.day.legend ~= today then
			p.day.legend = today
			F.pathXP(plr, d, "legend", C.PATH_CFG.legendDaily)
			notify(plr, "👑 Both sides of the city in one day: +" .. C.PATH_CFG.legendDaily .. " Empire Legend XP", {pri = "normal", cat = "rep"})
		end
	end
end
function F.pathTrack(plr, kind, n)
	local d = data[plr]
	if not d then return end
	n = math.max(0, math.floor(tonumber(n) or 1))
	if n <= 0 then return end
	local g = C.PATH_GAIN[kind]
	if g then F.pathXP(plr, d, g[1], g[2] * math.min(n, 50)) end
	local p = ensure(d)
	for slotName, e in pairs(p.contracts) do
		local c = type(e) == "table" and CT[e.key]
		if c and not contractDone(e) then
			local parts = c.parts or {{kind = c.kind}}
			local moved = false
			for i, part in ipairs(parts) do
				if part.kind == kind and (tonumber(e.p[i]) or 0) < e.n[i] then
					e.p[i] = math.min(e.n[i], (tonumber(e.p[i]) or 0) + n)
					moved = true
				end
			end
			if moved and contractDone(e) then
				notify(plr, "📜 Contract complete: " .. string.format(c.text, e.n[1]) .. "  (collect it in 🗺️ Roadmap)", {pri = "critical", cat = "rep", key = "contract" .. slotName})
			end
		end
	end
end
-- collect a finished contract: paid straight into this slot (the contract lives in the slot's save too)
function F.contractClaim(plr, slotName)
	local d = data[plr]
	if not d or type(slotName) ~= "string" then return false end
	local p = ensure(d)
	local e = p.contracts[slotName]
	local c = type(e) == "table" and CT[e.key]
	if not (c and contractDone(e)) then return false end
	local cash = math.max(C.PATH_CFG.contractMin, math.floor(F.incomePerSec(d) * C.PATH_CFG.contractSecs))
	d.cash += cash
	F.earn(d, cash)
	p.done += 1
	local xpPath = slotName == "bonus" and "mogul" or slotName
	if slotName == "bonus" then
		p.contracts.bonus = nil
		p.bonus = nil
	else
		p.contracts[slotName] = newContract(d, slotName, e.key)
	end
	F.pathXP(plr, d, xpPath, C.PATH_CFG.contractXP)
	notify(plr, "📜 Contract paid: +$" .. fmt(cash) .. " and +" .. C.PATH_CFG.contractXP .. " " .. PD[xpPath].name .. " XP", {pri = "critical", cat = "money"})
	return true
end
-- daily reward day 6: an extra contract
function F.pathBonusContract(plr, d)
	local p = rec(d)
	p.bonus = true
	ensure(d)
end

function F.pathInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local p = ensure(d)
	local out = {choice = p.choice, done = p.done, paths = {}, contracts = {}, underOpen = underOpen(d)}
	for _, def in ipairs(C.PATHS_DEF) do
		local xp = p.xp[def.key]
		local lv = F.pathLevel(xp)
		table.insert(out.paths, {key = def.key, icon = def.icon, name = def.name, level = lv, title = def.levels[lv], xp = xp, nextXP = C.PATH_XP[lv + 1],
			thisXP = C.PATH_XP[lv], nextTitle = def.levels[lv + 1]})
	end
	for _, slotName in ipairs({"mogul", "under", "legend", "bonus"}) do
		local e = p.contracts[slotName]
		local c = type(e) == "table" and CT[e.key]
		if c then
			local prog = {}
			for i, need in ipairs(e.n) do table.insert(prog, {p = tonumber(e.p[i]) or 0, n = need}) end
			table.insert(out.contracts, {slot = slotName, text = c.parts and c.text or string.format(c.text, e.n[1]), progress = prog, done = contractDone(e),
				icon = (PD[c.path] or PD.mogul).icon, cash = math.max(C.PATH_CFG.contractMin, math.floor(F.incomePerSec(d) * C.PATH_CFG.contractSecs))})
		end
	end
	return out
end

-- ===== the starting attitude (after the intro; can be changed from the Roadmap) =====
C.START_CHOICES = {
	smart = {icon = "💼", name = "Play It Smart", step = "cook", text = "Start with your business: serve a perfect 🍳 Rush Order."},
	risk = {icon = "🎲", name = "Take a Risk", step = "job", text = "Hit the streets: take a 💼 City Job. (Rumors say something hums inside the mountain up north...)"},
	explore = {icon = "🧭", name = "Explore the City", step = "corner", text = "Look around: Golden Corners, places to discover, the Fun Park.", app = "explore"},
}
function F.startChoice(plr, key)
	local d = data[plr]
	local ch = type(key) == "string" and C.START_CHOICES[key]
	if not (d and ch) then return false end
	rec(d).choice = key
	if F.onboardFirst then F.onboardFirst(plr, ch.step) end
	R.Menu:FireClient(plr, "startChosen", {key = key, name = ch.name, text = ch.text, app = ch.app})
	return true
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.startChoice = function(plr, d, a) F.startChoice(plr, a) end
C.ACTIONS.contractClaim = function(plr, d, a)
	if F.contractClaim(plr, a) and F.roadmapSend then F.roadmapSend(plr) end
end
local _ = Players
end
