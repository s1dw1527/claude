-- LEADERS (v14): leaderboards and PRESTIGE.
-- LEADERBOARDS: Net Worth, Revenue, Popularity, Properties, Fastest Lap, Heists, Explorer and Prestige.
--   Three views: this SERVER (live), GLOBAL (every server: OrderedDataStores "CE_LB_<board>", written only by this
--   code, every 5 minutes per player and when they leave), and FRIENDS (your Roblox friends, from either list).
--   Values come from the server's own records, never from the client.
-- PRESTIGE: ten long-term goals (own every business, a landmark, a $1B empire, 30 Golden Corners, 10 heists,
--   100 theater shows, a business partner, 5 parties, 10 rival wins, 3 rebirths). Each one is a ⭐ forever:
--   +1% to all income per star and a title (Bronze → Silver → Gold → Platinum → Diamond). Goals a save already
--   meets are recognized on the first check.
return function(C)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local CFG = C.CFG

local LB = {publishEvery = 300, cacheFor = 60, top = 25, nameCache = 600}
C.LEADERS = LB

-- ===================================================================== PRESTIGE
local function count(t) local n = 0 for _ in pairs(type(t) == "table" and t or {}) do n += 1 end return n end
local GOALS = {
	{key = "allBiz", icon = "🏪", name = "Every business", text = "Own all " .. #C.BUSINESSES .. " business types", need = #C.BUSINESSES,
		have = function(d) local n = 0 for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then n += 1 end end return n end},
	{key = "landmark", icon = "🌟", name = "A landmark", text = "Grow a business into a landmark", need = 1,
		have = function(d) for _, b in ipairs(C.BUSINESSES) do if C.stageOf(d.levels[b.key] or 0, d.chains[b.key] or 0) >= 6 then return 1 end end return 0 end},
	{key = "billion", icon = "💎", name = "Billion-dollar empire", text = "Reach a $1B empire value", need = 1e9, money = true,
		have = function(d) return F.empireValue and F.empireValue(d) or 0 end},
	{key = "corners", icon = "✨", name = "Golden explorer", text = "Collect 30 Golden Corners", need = 30,
		have = function(d) return type(d.city) == "table" and count(d.city.corners) or 0 end},
	{key = "heists", icon = "💰", name = "Master heister", text = "Pull off 10 heists", need = 10,
		have = function(d) return type(d.heist) == "table" and (tonumber(d.heist.done) or 0) or 0 end},
	{key = "cinema", icon = "🎬", name = "Movie mogul", text = "Run 100 shows at your Movie Theater", need = 100,
		have = function(d) return type(d.theater) == "table" and (tonumber(d.theater.sessions) or 0) or 0 end},
	{key = "partner", icon = "🤝", name = "Better together", text = "Run a business with a partner", need = 1,
		have = function(d)
			local c = d.coop
			if type(c) ~= "table" then return 0 end
			for _, b in pairs(type(c.biz) == "table" and c.biz or {}) do if type(b) == "table" and count(b.members) > 0 then return 1 end end
			return count(c.of) > 0 and 1 or 0
		end},
	{key = "host", icon = "🎉", name = "Party legend", text = "Throw 5 home parties", need = 5,
		have = function(d) return type(d.party) == "table" and (tonumber(d.party.hosted) or 0) or 0 end},
	{key = "rivals", icon = "🥊", name = "Rival crusher", text = "Win 10 rival challenges", need = 10,
		have = function(d) return type(d.rivals) == "table" and (tonumber(d.rivals.wins) or 0) or 0 end},
	{key = "reborn", icon = "♻️", name = "Born again", text = "Rebirth 3 times", need = 3,
		have = function(d) return tonumber(d.rebirths) or 0 end},
}
C.PRESTIGE_GOALS = GOALS
local TITLES = {{0, nil}, {1, "🥉 Bronze"}, {3, "🥈 Silver"}, {5, "🥇 Gold"}, {7, "💠 Platinum"}, {9, "💎 Diamond"}}
local function prec(d)
	if type(d.prestige) ~= "table" then d.prestige = {} end
	d.prestige.stars = type(d.prestige.stars) == "table" and d.prestige.stars or {}
	return d.prestige
end
function F.prestigeStars(d)
	local p = type(d.prestige) == "table" and d.prestige.stars
	return type(p) == "table" and count(p) or 0
end
function F.prestigeTitle(d)
	local n, t = F.prestigeStars(d), nil
	for _, e in ipairs(TITLES) do if n >= e[1] then t = e[2] end end
	return t
end
function F.prestigeMult(d) return 1 + 0.01 * F.prestigeStars(d) end
function F.prestigeCheck(plr)
	local d = data[plr]
	if not d then return 0 end
	local p = prec(d)
	local first = p.seeded ~= true
	local new = 0
	for _, g in ipairs(GOALS) do
		if not p.stars[g.key] then
			local ok, have = pcall(g.have, d)
			if ok and (tonumber(have) or 0) >= g.need then
				p.stars[g.key] = os.time()
				new += 1
				if not first then
					local title = F.prestigeTitle(d)
					R.Splash:FireClient(plr, "🌟 PRESTIGE STAR: " .. string.upper(g.name), g.text .. "  •  +1% all income forever" .. (title and ("  •  " .. title) or ""), RGB(255, 215, 90))
					F.buzz("🌟", plr.Name .. " earned the prestige star \"" .. g.name .. "\" (" .. F.prestigeStars(d) .. "/10)!", RGB(255, 215, 90))
				end
			end
		end
	end
	if first then
		p.seeded = true
		if new > 0 then notify(plr, "🌟 Prestige: your empire already earned " .. new .. " star" .. (new == 1 and "" or "s") .. " (+" .. new .. "% income). See 📊 Leaders.") end
	end
	return new
end
function F.prestigeInfo(d)
	local p = prec(d)
	local out = {stars = F.prestigeStars(d), title = F.prestigeTitle(d), goals = {}}
	for _, g in ipairs(GOALS) do
		local ok, have = pcall(g.have, d)
		have = ok and (tonumber(have) or 0) or 0
		table.insert(out.goals, {key = g.key, icon = g.icon, name = g.name, text = g.text, done = p.stars[g.key] ~= nil,
			have = g.money and fmt(math.min(have, g.need)) or math.min(have, g.need), need = g.money and fmt(g.need) or g.need})
	end
	return out
end

-- ===================================================================== BOARDS
local BOARDS = {
	{key = "networth", icon = "💰", name = "Net Worth", money = true, value = function(d) return F.empireValue and F.empireValue(d) or d.cash end},
	{key = "revenue", icon = "📈", name = "Revenue", money = true, per = "/s", value = function(d) return F.incomePerSec(d) end},
	{key = "popularity", icon = "⭐", name = "Popularity", value = function(d) return d.rep end},
	{key = "properties", icon = "🏙️", name = "Properties", value = function(d) return F.propertiesUsed and F.propertiesUsed(d) or 0 end},
	{key = "race", icon = "🏁", name = "Fastest Lap", time = true, asc = true, value = function(d) return tonumber(d.raceBest) end},
	{key = "heists", icon = "💼", name = "Heists", money = true, value = function(d) return type(d.heist) == "table" and tonumber(d.heist.earned) or 0 end},
	{key = "explorer", icon = "🧭", name = "Explorer", value = function(d)
		local c = type(d.city) == "table" and d.city or {}
		return count(c.corners) + count(c.places) + (tonumber(c.jobs) or 0)
	end},
	{key = "prestige", icon = "🌟", name = "Prestige", value = function(d) return F.prestigeStars(d) end},
}
C.BOARDS = BOARDS
local BOARD = {}
for _, b in ipairs(BOARDS) do BOARD[b.key] = b end
local function valueOf(b, d)
	local ok, v = pcall(b.value, d)
	v = ok and tonumber(v) or nil
	if not v or v ~= v or v == math.huge then return nil end
	if b.asc and v <= 0 then return nil end
	return v
end
-- what's stored globally: integers (lap times in milliseconds)
local function stored(b, v) return b.time and math.floor(v * 1000 + 0.5) or math.floor(v) end
local function shown(b, v) return b.time and (v / 1000) or v end

local stores, names
if CFG.SAVE_ENABLED then
	pcall(function()
		stores = {}
		for _, b in ipairs(BOARDS) do stores[b.key] = DataStoreService:GetOrderedDataStore(C.storeName("CE_LB_" .. b.key)) end
		names = DataStoreService:GetDataStore(C.storeName("CE_LB_Names"))
	end)
end
local published = {}   -- [plr] = {at, values = {}}
function F.boardsPublish(plr, force)
	local d = data[plr]
	if not (d and stores) or d.noSave then return 0 end
	local pub = published[plr]
	if not pub then
		pub = {at = -1e9, values = {}, named = false}
		published[plr] = pub
	end
	if not force and os.clock() - pub.at < LB.publishEvery then return 0 end
	pub.at = os.clock()
	local n = 0
	for _, b in ipairs(BOARDS) do
		local v = valueOf(b, d)
		if v then
			local sv = stored(b, v)
			if pub.values[b.key] ~= sv then
				local ok = pcall(function() stores[b.key]:SetAsync(tostring(plr.UserId), sv) end)
				if ok then pub.values[b.key] = sv n += 1 end
			end
		end
	end
	if not pub.named and names then
		pub.named = pcall(function() names:SetAsync("n" .. plr.UserId, {name = plr.Name, t = os.time()}) end)
	end
	return n
end
local nameCache = {}
local function nameOf(uid)
	local p = Players:GetPlayerByUserId(uid)
	if p then return p.Name end
	local c = nameCache[uid]
	if c and os.clock() - c.at < LB.nameCache then return c.name end
	local name = "Player " .. uid
	if names then
		local ok, v = pcall(function() return names:GetAsync("n" .. uid) end)
		if ok and type(v) == "table" and type(v.name) == "string" then name = v.name end
	end
	nameCache[uid] = {name = name, at = os.clock()}
	return name
end
local globalCache = {}
local function globalTop(b)
	local c = globalCache[b.key]
	if c and os.clock() - c.at < LB.cacheFor then return c.list end
	local list = {}
	if stores then
		local ok, pages = pcall(function() return stores[b.key]:GetSortedAsync(b.asc == true, LB.top) end)
		if ok and pages then
			local ok2, page = pcall(function() return pages:GetCurrentPage() end)
			if ok2 and type(page) == "table" then
				for _, e in ipairs(page) do
					local uid = tonumber(e.key)
					if uid then table.insert(list, {uid = uid, value = shown(b, tonumber(e.value) or 0)}) end
				end
			end
		end
	end
	for _, e in ipairs(list) do e.name = nameOf(e.uid) end
	globalCache[b.key] = {at = os.clock(), list = list}
	return list
end
local friendCache = {}
local function isFriend(plr, uid)
	if uid == plr.UserId then return true end
	if C.friendCheckId then return C.friendCheckId(plr, uid) end
	friendCache[plr] = friendCache[plr] or {}
	local c = friendCache[plr][uid]
	if c ~= nil then return c end
	local ok, yes = pcall(function() return plr:IsFriendsWith(uid) end)
	friendCache[plr][uid] = ok and yes == true
	return friendCache[plr][uid]
end
function F.boardList(plr, key, scope)
	local b = BOARD[key]
	if not (b and data[plr]) then return nil end
	local list = {}
	if scope == "global" or scope == "friends" then
		for _, e in ipairs(globalTop(b)) do
			if scope == "global" or isFriend(plr, e.uid) then table.insert(list, {uid = e.uid, name = e.name, value = e.value}) end
		end
		-- friends in this server count even before their score reaches the global list
		if scope == "friends" then
			for _, p in ipairs(Players:GetPlayers()) do
				local d = data[p]
				local v = d and valueOf(b, d)
				if v and isFriend(plr, p.UserId) then
					local found = false
					for _, e in ipairs(list) do if e.uid == p.UserId then found = true e.value = v end end
					if not found then table.insert(list, {uid = p.UserId, name = p.Name, value = v}) end
				end
			end
		end
	else
		scope = "server"
		for _, p in ipairs(Players:GetPlayers()) do
			local d = data[p]
			local v = d and valueOf(b, d)
			if v then table.insert(list, {uid = p.UserId, name = p.Name, value = v}) end
		end
	end
	table.sort(list, function(x, y) if b.asc then return x.value < y.value end return x.value > y.value end)
	local mine
	for i, e in ipairs(list) do
		e.rank = i
		e.title = nil
		local p = Players:GetPlayerByUserId(e.uid)
		if p and data[p] then e.title = F.prestigeTitle(data[p]) end
		if e.uid == plr.UserId then mine = i end
		if i > LB.top then list[i] = nil end
	end
	local boards = {}
	for _, x in ipairs(BOARDS) do table.insert(boards, {key = x.key, icon = x.icon, name = x.name}) end
	return {key = b.key, name = b.name, icon = b.icon, scope = scope, money = b.money, per = b.per, time = b.time, list = list, mine = mine, boards = boards,
		prestige = F.prestigeInfo(data[plr]), globalOn = stores ~= nil}
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.boardInfo = function(plr, d, a, b)
	local key = type(a) == "string" and BOARD[a] and a or "networth"
	local scope = (b == "global" or b == "friends") and b or "server"
	local info = F.boardList(plr, key, scope)
	if info then R.Menu:FireClient(plr, "leaders", info) end
end

task.spawn(function()
	while true do
		task.wait(30)
		for _, plr in ipairs(Players:GetPlayers()) do
			if data[plr] then
				pcall(F.prestigeCheck, plr)
				pcall(F.boardsPublish, plr, false)
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	if data[plr] then pcall(F.boardsPublish, plr, true) end
	published[plr], friendCache[plr] = nil, nil
end)
end
