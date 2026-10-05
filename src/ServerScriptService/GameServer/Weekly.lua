-- WEEKLY: rotating weekly leaderboards, the weekly Empire Showcase, and house tours (visit / like / rate / favorite).
-- Boards live in OrderedDataStores scoped to the week, so every server sees the same rankings.
-- Without DataStore access (e.g. Studio with API access off) everything still works, but only in memory.
return function(C)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local CFG, fmt, notify = C.CFG, C.fmt, C.notify
local WEEKLY = C.WEEKLY

-- weeks start Monday 00:00 UTC (the Unix epoch was a Thursday, hence the 4-day offset)
local function weekId(t) return math.floor(((t or os.time()) - 345600) / 604800) end
C.weekId = weekId
local function weekEnds() return (weekId() + 1) * 604800 + 345600 - os.time() end
local function featured(week) return WEEKLY[(week % #WEEKLY) + 1].key end
C.weeklyFeatured = featured

-- ===== storage (real OrderedDataStores, or an in-memory stand-in) =====
local enabled = CFG.SAVE_ENABLED
local memory = {}
local function board(name, week)
	local key = name .. "@" .. week
	local b = {mem = memory[key]}
	if not b.mem then
		b.mem = {}
		memory[key] = b.mem
	end
	if enabled then
		local ok, st = pcall(function() return DataStoreService:GetOrderedDataStore(C.storeName("CE_" .. name), "w" .. week) end)
		if ok then b.store = st end
	end
	return b
end
local function clampInt(v) return math.clamp(math.floor(v + 0.5), -9e15, 9e15) end
local function writeValue(b, key, value, mode)
	value = clampInt(value)
	local old = b.mem[key]
	if mode == "min" and old and old <= value then return end
	if mode == "max" and old and old >= value then return end
	b.mem[key] = value
	if b.store then
		task.spawn(function()
			pcall(function()
				if mode == "min" or mode == "max" then
					b.store:UpdateAsync(key, function(cur)
						if cur and ((mode == "min" and cur <= value) or (mode == "max" and cur >= value)) then return nil end
						return value
					end)
				else
					b.store:SetAsync(key, value)
				end
			end)
		end)
	end
end
local function addValue(b, key, delta)
	b.mem[key] = (b.mem[key] or 0) + delta
	if b.store then
		task.spawn(function() pcall(function() b.store:IncrementAsync(key, delta) end) end)
	end
end
local function top(b, n, ascending)
	if b.store then
		local ok, page = pcall(function() return b.store:GetSortedAsync(ascending == true, n):GetCurrentPage() end)
		if ok and type(page) == "table" then
			local out = {}
			for _, e in ipairs(page) do table.insert(out, {key = e.key, value = e.value}) end
			return out
		end
	end
	local out = {}
	for k, v in pairs(b.mem) do table.insert(out, {key = k, value = v}) end
	table.sort(out, function(x, y) if ascending then return x.value < y.value end return x.value > y.value end)
	while #out > n do table.remove(out) end
	return out
end
local names = {}
local function nameOf(userId)
	userId = tonumber(userId)
	if not userId then return "?" end
	local p = Players:GetPlayerByUserId(userId)
	if p then names[userId] = p.Name end
	if names[userId] then return names[userId] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = ok and n or ("Player " .. userId)
	return names[userId]
end

-- ===== the stats each board ranks =====
local function propertyValue(d)
	local v = 0
	for _, b in ipairs(d.props) do v += F.rentalValue(b) end
	local hl = F.homeLot(d)
	if hl and d.home then
		local hood = C.HOOD[hl.hood]
		v += hood.price + hood.build * (2.2 ^ d.home.level - 1) / 1.2
	end
	return v
end
local STATS = {
	richest = function(d) return d.cash end,
	rep = function(d) return d.rep end,
	lap = function(d) return d.raceBest and d.raceBest * 1000 or nil end,
	rebirths = function(d) return d.rebirths end,
	property = propertyValue,
	business = function(d) return d.weekServed and d.weekServed.n or 0 end,
	followers = function(d) return d.followers end,
}
local published = {}   -- plr -> {cat -> last value}, so unchanged numbers aren't rewritten
function F.publishWeekly(plr, d)
	if d.noSave then return end
	local week = weekId()
	published[plr] = published[plr] or {}
	for _, cat in ipairs(WEEKLY) do
		local stat = STATS[cat.key]
		local v = stat and stat(d)
		if v and v == v and v >= 0 and published[plr][cat.key] ~= math.floor(v) then
			published[plr][cat.key] = math.floor(v)
			writeValue(board("Weekly_" .. cat.key, week), tostring(plr.UserId), v, cat.ascending and "min" or nil)
		end
	end
end
-- customers served this week (for "Most Popular Business"): reset when the week changes
function F.countServed(d)
	local week = weekId()
	if not d.weekServed or d.weekServed.w ~= week then d.weekServed = {w = week, n = 0} end
	d.weekServed.n += 1
end

-- ===== cached boards (refreshed every 2 minutes to stay well inside DataStore limits) =====
local cache = {week = -1, boards = {}, showcase = {}, t = 0}
local entries = {}      -- showcase entry details by userId
local function refresh()
	local week = weekId()
	local out = {}
	for _, cat in ipairs(WEEKLY) do
		local list = {}
		for i, e in ipairs(top(board("Weekly_" .. cat.key, week), 10, cat.ascending)) do
			list[i] = {rank = i, userId = tonumber(e.key), name = nameOf(e.key), value = e.value}
		end
		out[cat.key] = list
	end
	local sc = {}
	for i, e in ipairs(top(board("ShowcaseLikes", week), 10, false)) do
		local id = tonumber(e.key)
		local info = entries[id]
		if not info and enabled then
			local ok, v = pcall(function() return DataStoreService:GetDataStore(C.storeName("CE_Showcase"), "w" .. week):GetAsync("u" .. id) end)
			if ok and type(v) == "table" then info = v end
			entries[id] = info
		end
		sc[i] = {rank = i, userId = id, name = nameOf(id), likes = e.value, info = info}
	end
	cache.week, cache.boards, cache.showcase, cache.t = week, out, sc, os.clock()
end
task.spawn(function()
	while true do
		if next(data) ~= nil then
			local ok, err = pcall(refresh)
			if not ok then warn("[CornerEmpire] weekly refresh failed: " .. tostring(err)) end
		end
		task.wait(120)
	end
end)
function F.weeklyInfo(plr)
	local d = data[plr]
	local week = weekId()
	local cats = {}
	for _, cat in ipairs(WEEKLY) do
		table.insert(cats, {key = cat.key, name = cat.name, ascending = cat.ascending, unit = cat.unit, list = cache.boards[cat.key] or {}})
	end
	local favs = {}
	for _, f in ipairs(d and d.favorites or {}) do table.insert(favs, {userId = f.userId, name = f.name, here = Players:GetPlayerByUserId(f.userId) ~= nil}) end
	return {week = week, featured = featured(week), endsIn = weekEnds(), categories = cats, showcase = cache.showcase, favorites = favs,
		submitted = d and d.showcaseWeek == week, myId = plr.UserId}
end
C.refreshWeeklyNow = refresh

-- ===== Empire Showcase =====
function F.showcaseSubmit(plr)
	local d = data[plr]
	if not d then return end
	local now = os.clock()
	if now < (d.showcaseCool or 0) then
		notify(plr, "🏆 You just submitted — try again in a minute.")
		return
	end
	d.showcaseCool = now + 60
	local week = weekId()
	local landmarks, open = 0, 0
	for _, b in ipairs(C.BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		if lvl > 0 then open += 1 end
		if C.stageOf(lvl, d.chains[b.key] or 0) == 6 then landmarks += 1 end
	end
	local hl = F.homeLot(d)
	local info = {name = plr.Name, income = math.floor(F.incomePerSec(d)), score = F.empireScore(d), businesses = open, landmarks = landmarks,
		rebirths = d.rebirths, tier = C.REP_TIERS[F.tierIndex(d.rep)].name, home = hl and (C.HOOD[hl.hood].name .. " • " .. C.HOME_LEVELS[math.max(1, d.home.level)]) or "No home",
		props = #d.props, followers = d.followers}
	entries[plr.UserId] = info
	if enabled then
		task.spawn(function()
			pcall(function() DataStoreService:GetDataStore(C.storeName("CE_Showcase"), "w" .. week):SetAsync("u" .. plr.UserId, info) end)
		end)
	end
	local b = board("ShowcaseLikes", week)
	if b.mem[tostring(plr.UserId)] == nil then writeValue(b, tostring(plr.UserId), 0, "max") end
	local first = d.showcaseWeek ~= week
	d.showcaseWeek = week
	notify(plr, first and "🏆 Your empire is in this week's Empire Showcase! Get other players to ❤️ it." or "🏆 Showcase entry updated.")
	if first then F.buzz("🏆", plr.Name .. " entered their empire in the Weekly Empire Showcase!", d.plot.color) end
	task.defer(function() pcall(refresh) end)
end
local function voteKey(week, kind, id) return kind .. week .. ":" .. id end
local function pruneVotes(d)
	local week = weekId()
	for k in pairs(d.votes or {}) do
		local w = tonumber(string.match(k, "^%a+(%-?%d+):"))
		if not w or w < week then d.votes[k] = nil end
	end
end
function F.showcaseLike(plr, targetId)
	local d = data[plr]
	if not d or targetId == plr.UserId then return end
	local week = weekId()
	d.votes = d.votes or {}
	local k = voteKey(week, "s", targetId)
	if d.votes[k] then
		notify(plr, "❤️ You already liked that empire this week.")
		return
	end
	local exists = false
	for _, e in ipairs(cache.showcase) do if e.userId == targetId then exists = true end end
	if not exists then return end
	d.votes[k] = true
	addValue(board("ShowcaseLikes", week), tostring(targetId), 1)
	for _, e in ipairs(cache.showcase) do if e.userId == targetId then e.likes += 1 end end
	notify(plr, "❤️ Liked " .. nameOf(targetId) .. "'s empire!")
	local owner = Players:GetPlayerByUserId(targetId)
	if owner then notify(owner, "❤️ " .. plr.Name .. " liked your empire in the Weekly Showcase!") end
end

-- ===== HOUSE TOURS =====
local function homeOf(userId)
	local owner = Players:GetPlayerByUserId(userId)
	local od = owner and data[owner]
	local lot = od and F.homeLot(od)
	if not lot then return nil end
	return owner, od, lot
end
function F.toursList()
	local out = {}
	for p, d in pairs(data) do
		local lot = F.homeLot(d)
		if lot and d.home and d.home.level > 0 then
			local n = d.homeRatingN or 0
			table.insert(out, {userId = p.UserId, name = p.Name, pos = lot.pos, hood = C.HOOD[lot.hood].name, icon = C.HOOD[lot.hood].icon, level = d.home.level,
				likes = d.homeLikes or 0, rating = n > 0 and math.floor((d.homeRatingSum or 0) / n * 10 + 0.5) / 10 or 0, ratings = n})
		end
	end
	table.sort(out, function(x, y) return x.name < y.name end)
	return out
end
local function nearHome(plr, lot)
	local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	return r and (V3(r.Position.X, 0, r.Position.Z) - V3(lot.pos.X, 0, lot.pos.Z)).Magnitude < 60
end
function F.tourVisit(plr, targetId)
	local owner, _, lot = homeOf(targetId)
	if not owner then
		notify(plr, "🏠 That player isn't in this server (or has no house yet).")
		return
	end
	local char = plr.Character
	if char then
		F.despawnCar(plr)
		char:PivotTo(CF(lot.pos) * CFrame.Angles(0, lot.yaw, 0) * CF(0, 4, lot.size / 2 + 4) * CFrame.Angles(0, math.pi, 0))
	end
	notify(plr, "🏠 Welcome to " .. owner.Name .. "'s home! Like it, rate it, or add it to your favorites.")
end
local function houseScore(owner, delta)
	addValue(board("Weekly_house", weekId()), tostring(owner.UserId), delta)
end
function F.tourVote(plr, targetId, kind, stars)
	local d = data[plr]
	if not d or targetId == plr.UserId then return end
	local owner, od, lot = homeOf(targetId)
	if not owner then return end
	if not nearHome(plr, lot) then
		notify(plr, "🏠 Go visit the house first! (Phone → Weekly → House Tours → Visit)")
		return
	end
	local week = weekId()
	d.votes = d.votes or {}
	if kind == "like" then
		local k = voteKey(week, "l", targetId)
		if d.votes[k] then
			notify(plr, "❤️ You already liked this house this week.")
			return
		end
		d.votes[k] = true
		od.homeLikes = (od.homeLikes or 0) + 1
		houseScore(owner, 3)
		notify(plr, "❤️ You liked " .. owner.Name .. "'s house!")
		notify(owner, "❤️ " .. plr.Name .. " liked your house!")
	elseif kind == "rate" then
		local k = voteKey(week, "r", targetId)
		if d.votes[k] then
			notify(plr, "⭐ You already rated this house this week.")
			return
		end
		d.votes[k] = true
		od.homeRatingSum = (od.homeRatingSum or 0) + stars
		od.homeRatingN = (od.homeRatingN or 0) + 1
		houseScore(owner, stars)
		notify(plr, "⭐ You gave " .. owner.Name .. "'s house " .. string.rep("★", stars))
		notify(owner, "⭐ " .. plr.Name .. " rated your house " .. string.rep("★", stars) .. "!")
	elseif kind == "fav" then
		d.favorites = d.favorites or {}
		for i, f in ipairs(d.favorites) do
			if f.userId == targetId then
				table.remove(d.favorites, i)
				notify(plr, "📌 Removed " .. owner.Name .. "'s house from your favorites.")
				return
			end
		end
		if #d.favorites >= 12 then table.remove(d.favorites, 1) end
		table.insert(d.favorites, {userId = targetId, name = owner.Name})
		notify(plr, "📌 Added " .. owner.Name .. "'s house to your favorites!")
		notify(owner, "📌 " .. plr.Name .. " added your house to their favorites!")
	end
end

-- ===== last week's winners get their trophies the next time they play =====
local lastWeek = {week = -1, boards = nil, t = 0}
local function lastWeekBoards()
	local week = weekId() - 1
	-- cached for 5 minutes (other servers may still be flushing their final saves right after the reset)
	if lastWeek.week == week and lastWeek.boards and os.clock() - lastWeek.t < 300 then return lastWeek.boards end
	local out = {}
	for _, cat in ipairs(WEEKLY) do
		out[cat.key] = top(board("Weekly_" .. cat.key, week), 3, cat.ascending)
		task.wait(0.5)
	end
	out.showcase = top(board("ShowcaseLikes", week), 1, false)
	lastWeek.week, lastWeek.boards, lastWeek.t = week, out, os.clock()
	return out
end
function F.claimWeeklyRewards(plr)
	local d = data[plr]
	if not d or d.noSave then return end
	local week = weekId() - 1
	if (d.weeklyClaimed or -1) >= week then return end
	local ok, boards = pcall(lastWeekBoards)
	if not ok or not data[plr] then return end
	d.weeklyClaimed = week
	local wins, trophies = {}, 0
	local feat = featured(week)
	for _, cat in ipairs(WEEKLY) do
		for rank, e in ipairs(boards[cat.key] or {}) do
			if tonumber(e.key) == plr.UserId then
				local t = (C.WEEKLY_REWARD[rank] or 0) * (cat.key == feat and 2 or 1)
				trophies += t
				table.insert(wins, "#" .. rank .. " " .. cat.name)
				if rank == 1 then
					if F.achieve then F.achieve(plr, cat.key == "house" and "houseStar" or "weeklyChamp") end
				end
			end
		end
	end
	local sc = boards.showcase and boards.showcase[1]
	if sc and tonumber(sc.key) == plr.UserId and sc.value > 0 then
		trophies += 3
		table.insert(wins, "🏆 Empire of the Week")
		if F.achieve then F.achieve(plr, "showcaseStar") end
	end
	if trophies > 0 then
		d.trophies += trophies
		F.refreshTower(plr, true)
		R.Splash:FireClient(plr, "🥇 LAST WEEK'S RESULTS", "You placed: " .. table.concat(wins, ", ") .. "  •  +" .. trophies .. " trophies!", RGB(255, 215, 90))
		F.buzz("🥇", plr.Name .. " picked up " .. trophies .. " trophies from last week's competitions!", RGB(255, 215, 90))
	end
end
C.pruneVotes = pruneVotes

-- a leaderboard wall in front of the Legacy Museum so everyone can see who's winning this week
do
	local at = C.MUSEUM_AT + V3(-30, 0, 44)
	C.reserve(at.X - 16, at.Z - 3, at.X + 16, at.Z + 3)
	local wall = C.P(C.WORLD, V3(28, 13, 1), CF(at + V3(0, 9, 0)), RGB(20, 22, 32), MAT.SmoothPlastic, {CanCollide = true})
	for _, sx in ipairs({-11, 11}) do C.P(C.WORLD, V3(1, 3, 1), CF(at + V3(sx, 1.5, 0)), RGB(40, 40, 50), MAT.Metal, {CanCollide = true}) end
	local lines = {}
	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		table.insert(lines, C.surfaceText(wall, face, "🏆 THIS WEEK", RGB(255, 215, 90)))
	end
	task.spawn(function()
		while true do
			task.wait(15)
			local week = weekId()
			local feat = featured(week)
			local out = {"🏆 THIS WEEK'S LEADERS (resets in " .. math.floor(weekEnds() / 86400) .. "d)"}
			for _, cat in ipairs(WEEKLY) do
				local first = cache.boards[cat.key] and cache.boards[cat.key][1]
				if first then
					local v = cat.unit == "time" and string.format("%.2fs", first.value / 1000) or fmt(first.value)
					table.insert(out, (cat.key == feat and "⭐ " or "") .. cat.name .. ": " .. first.name .. " (" .. v .. ")")
				end
			end
			if #out == 1 then table.insert(out, "Play to get on the boards!") end
			for _, l in ipairs(lines) do l.Text = table.concat(out, "\n") end
		end
	end)
end
end
