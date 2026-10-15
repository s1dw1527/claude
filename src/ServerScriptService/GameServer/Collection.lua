-- COLLECTION + "NEXT TIME" (v18): reasons to come back because you're CURIOUS, not only because you're told to.
--   * 📚 COLLECTION BOOK: everything rare there is to find: every Bazaar-only treasure and every kind of lucky
--     customer. What you've found shows in full; what you haven't is a "❓ ???" card with only its rarity color and
--     where to look ("Bazaar • Mythic"), so you know it exists but not what it is. Milestones (5 / 10 / 15 / all)
--     pay once per save. Found = bought or placed at least once, or a lucky sale of that kind (kept in the save)
--   * 🔮 NEXT TIME: after a while in a session, one card with what's coming: tomorrow's daily reward (or that
--     today's is waiting), the next city event and when it starts, the next Bazaar restock, and how much of the
--     collection is still hidden. Shown once per session, never during a ride/heist/cutscene.
-- The server decides what's found and pays the milestones; the client only shows.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify

C.COLLECTION = {
	milestones = {
		{n = 5, rep = 5, secs = 300, min = 2000, name = "Collector"},
		{n = 10, rep = 10, secs = 600, min = 5000, name = "Treasure Hunter"},
		{n = 15, rep = 20, secs = 1200, min = 15000, name = "Curator"},
		{n = 0, rep = 50, secs = 3600, min = 50000, name = "Completionist"},   -- n = 0: everything
	},
}
C.TEASER = {after = 480, check = 10}

-- the book's entries: Bazaar treasures (rarest last) + the lucky customers
local function entries()
	local out = {}
	for _, it in ipairs(C.BAZAAR_ITEMS or {}) do
		table.insert(out, {key = it.key, kind = "bazaar", icon = it.icon, name = it.name, rarity = it.rarity, where = "City Bazaar"})
	end
	for i = #((C.RARE_SALES and C.RARE_SALES.list) or {}), 1, -1 do
		local r = C.RARE_SALES.list[i]
		table.insert(out, {key = "rare_" .. r.key, kind = "rare", rk = r.key, icon = r.icon, name = r.name:sub(1, 1) .. r.name:sub(2):lower() .. " Customer",
			rarity = ({golden = "rare", diamond = "epic", rainbow = "mythic"})[r.key] or "rare", where = "a lucky customer at your shops"})
	end
	return out
end
local ENTRIES
local function list()
	ENTRIES = ENTRIES or entries()
	return ENTRIES
end
local function rec(d)
	local c = d.collect
	if type(c) ~= "table" or type(c.found) ~= "table" or type(c.claimed) ~= "table" then
		c = {found = type(c) == "table" and type(c.found) == "table" and c.found or {}, claimed = type(c) == "table" and type(c.claimed) == "table" and c.claimed or {}}
		d.collect = c
	end
	return c
end
-- look at what the player has (storage, placed furniture, lucky sales) and remember anything new
function F.collectScan(d)
	local c = rec(d)
	local new = {}
	local placed = {}
	local hb = type(d.homeBuild) == "table" and d.homeBuild or nil
	for _, item in ipairs(hb and type(hb.items) == "table" and hb.items or {}) do if type(item) == "table" and item.k then placed[item.k] = true end end
	local rs = type(d.rareSales) == "table" and d.rareSales or {}
	for _, e in ipairs(list()) do
		if not c.found[e.key] then
			local have
			if e.kind == "bazaar" then
				have = (type(d.furniture) == "table" and (tonumber(d.furniture[e.key]) or 0) > 0) or placed[e.key]
			else
				have = (tonumber(rs[e.rk]) or 0) > 0
			end
			if have then
				c.found[e.key] = os.time()
				table.insert(new, e)
			end
		end
	end
	return new
end
function F.collectCount(d)
	local c = rec(d)
	local n = 0
	for _, e in ipairs(list()) do if c.found[e.key] then n += 1 end end
	return n, #list()
end
local function milestoneNeed(m) return m.n > 0 and m.n or #list() end
local function payFor(d, m) return math.max(m.min, math.floor((F.incomePerSec and F.incomePerSec(d) or 0) * m.secs)) end
function F.collectInfo(plr)
	local d = data[plr]
	if not d then return nil end
	F.collectScan(d)
	local c = rec(d)
	local n, total = F.collectCount(d)
	local out = {found = n, total = total, items = {}, milestones = {}}
	for _, e in ipairs(list()) do
		local got = c.found[e.key] ~= nil
		-- (an unfound entry sends only its rarity and where to look: the name and icon stay a mystery)
		table.insert(out.items, {key = e.key, found = got, icon = got and e.icon or nil, name = got and e.name or nil, rarity = e.rarity, where = e.where})
	end
	for i, m in ipairs(C.COLLECTION.milestones) do
		local need = milestoneNeed(m)
		table.insert(out.milestones, {i = i, need = need, name = m.name, rep = m.rep, cash = payFor(d, m), done = n >= need, claimed = c.claimed[tostring(i)] ~= nil})
	end
	return out
end
local claimAt = {}
function F.collectClaim(plr, i)
	local d = data[plr]
	i = math.floor(tonumber(i) or 0)
	local m = C.COLLECTION.milestones[i]
	if not (d and m) or d.noSave then return false end
	local t = os.clock()
	if claimAt[plr] and t - claimAt[plr] < 0.5 then return false end
	claimAt[plr] = t
	F.collectScan(d)
	local c = rec(d)
	if c.claimed[tostring(i)] then return false end
	local n = F.collectCount(d)
	if n < milestoneNeed(m) then return false end
	c.claimed[tostring(i)] = os.time()
	local cash = payFor(d, m)
	d.cash += cash
	F.earn(d, cash)
	F.addRep(plr, m.rep)
	notify(plr, "📚 Collection milestone: " .. m.name .. "!  +$" .. fmt(cash) .. "  +" .. m.rep .. " ⭐", {pri = "critical", cat = "money"})
	if F.analyticsSource then F.analyticsSource(plr, cash, "Reward", "collection" .. i) end
	return true
end
local function send(plr)
	local info = F.collectInfo(plr)
	if info then R.Menu:FireClient(plr, "collection", info) end
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.collectInfo = function(plr) send(plr) end
C.ACTIONS.collectClaim = function(plr, d, a) F.collectClaim(plr, a) send(plr) end
-- a new find is announced (once): "📚 New in your collection: 🦄 Rainbow Unicorn Statue (11 / 21)"
function F.collectCheck(plr)
	local d = data[plr]
	if not d then return end
	for _, e in ipairs(F.collectScan(d)) do
		local n, total = F.collectCount(d)
		notify(plr, "📚 New in your collection: " .. e.icon .. " " .. e.name .. "  (" .. n .. " / " .. total .. ")", {pri = "normal", cat = "rep", key = "collect"})
	end
end

-- ===== 🔮 NEXT TIME =====
local function mmss(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then return math.floor(sec / 3600) .. "h " .. math.floor(sec % 3600 / 60) .. "m" end
	return string.format("%d:%02d", sec // 60, sec % 60)
end
function F.teaserInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local lines = {}
	local di = F.dailyInfo and F.dailyInfo(plr)
	if di then
		if not di.claimedToday then
			table.insert(lines, {icon = "🎁", text = "Today's reward is still waiting in 🎁 Daily!"})
		else
			local nextDay = (di.today % #di.rewards) + 1
			local r = di.rewards[nextDay]
			if r then table.insert(lines, {icon = "🎁", text = "Tomorrow, day " .. nextDay .. ": " .. r.icon .. " " .. r.name .. " (in " .. mmss(di.nextIn) .. ")"}) end
		end
	end
	local li = F.liveInfo and F.liveInfo(plr)
	if li and li.nextName then
		table.insert(lines, {icon = li.nextIcon or "📅", text = "Next city event: " .. li.nextName .. " in " .. mmss(li.endsIn)})
	end
	if F.bazaarWindow then
		local _, ends = F.bazaarWindow()
		table.insert(lines, {icon = "🛍️", text = "Bazaar restock in " .. mmss(ends - (F.bazaarNow and F.bazaarNow() or os.time())) .. ". What will it be?"})
	end
	local n, total = F.collectCount(d)
	if total > 0 and n < total then table.insert(lines, {icon = "📚", text = (total - n) .. " treasures still hidden in your collection (❓ ???)"}) end
	return {lines = lines}
end
local started, shown = {}, {}
task.spawn(function()
	while true do
		task.wait(C.TEASER.check)
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			if d then
				F.collectCheck(plr)
				started[plr] = started[plr] or os.clock()
				if not shown[plr] and os.clock() - started[plr] >= C.TEASER.after and (d.tut or 0) == 0 and not (F.playerBusy and F.playerBusy(plr)) then
					shown[plr] = true
					local info = F.teaserInfo(plr)
					if info and #info.lines > 0 then R.Menu:FireClient(plr, "teaser", info) end
				end
			else
				started[plr], shown[plr] = nil, nil
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) started[plr], shown[plr], claimAt[plr] = nil, nil, nil end)
end
