-- DAILY (v16): reasons to come back tomorrow. All of it belongs to the ACCOUNT (the meta key, GameServer >
-- Players: F.acct / F.acctCommit), so the three save slots share one streak, and every reward is written ahead
-- as a "grant" before it's paid into the slot being played (no duplicate or lost rewards; see F.payGrants).
--   * LOGIN REWARDS: a 7-day cycle on UTC calendar days. One claim per UTC day. Missing ONE day is forgiven
--     by the streak shield (it recharges every UTC week); more missed days step the cycle back by the days
--     missed, never below day 1 (it never resets from scratch)
--   * DAILY MISSIONS: 3 a day, picked for this account and this UTC day from the pool, only from what the
--     player's reputation tier can actually do; they move only from real server events (F.track)
--   * WEEKLY CHALLENGE: one bigger goal per UTC week (Monday to Sunday)
-- Definitions are data (C.DAILY_REWARDS, C.MISSION_POOL, C.WEEKLY_POOL): balance them there.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local DAY = 86400
C.dailyClock = C.dailyClock or nil   -- (tests can set a function returning the time)
local function now() return C.dailyClock and C.dailyClock() or os.time() end
function F.utcDay(t) return math.floor((t or now()) / DAY) end
-- weeks start on Monday (1970-01-01 was a Thursday)
function F.utcWeek(t) return math.floor((F.utcDay(t) + 3) / 7) end

-- ===== rewards (cash = max(min, income × secs)) =====
C.DAILY_REWARDS = {
	{icon = "💵", name = "Cash bonus", secs = 300, min = 1000},
	{icon = "🏷️", name = "Upgrade discount", text = "25% off your next business upgrade", item = "tokUpgrade", secs = 120, min = 500},
	{icon = "🎨", name = "Free car makeover", text = "your next car part or paint is free", item = "tokCarmod", secs = 120, min = 500},
	{icon = "🎓", name = "Staff training", text = "every employee gains experience", item = "training", secs = 180, min = 800},
	{icon = "🏺", name = "Rare decoration", text = "a Golden Statue for your home", item = "decor", secs = 180, min = 800},
	{icon = "📜", name = "Bonus contract", text = "an extra contract on your 🗺️ Roadmap", item = "contract", secs = 300, min = 1500},
	{icon = "👑", name = "Legacy reward", text = "the 👑 Week Champion title + a big cash bonus", item = "titleWeek", secs = 1200, min = 6000, rep = 10},
}
local DR = C.DAILY_REWARDS

-- ===== missions =====
-- kind = the F.track event; n = target (money targets scale with income: n = max(n, income × incomeSecs));
-- tier = the reputation tier needed (1 = everyone); path = mogul / under / any (for the Roadmap's paths)
C.MISSION_POOL = {
	{key = "serve30", kind = "serve", n = 30, text = "Serve %d customers", tier = 1, path = "mogul"},
	{key = "serve80", kind = "serve", n = 80, text = "Serve %d customers", tier = 2, path = "mogul"},
	{key = "cook2", kind = "cook", n = 2, text = "Serve %d perfect 🍳 Rush Orders", tier = 1, path = "mogul"},
	{key = "cook5", kind = "cook", n = 5, text = "Serve %d perfect 🍳 Rush Orders", tier = 2, path = "mogul"},
	{key = "upgrade2", kind = "upgrade", n = 2, text = "Upgrade a business %d times", tier = 1, path = "mogul"},
	{key = "earn", kind = "earnLegit", n = 5000, incomeSecs = 900, text = "Earn $%s from your businesses", tier = 1, path = "mogul", money = true},
	{key = "job1", kind = "job", n = 1, text = "Finish %d 💼 City Job", tier = 1, path = "any"},
	{key = "job3", kind = "job", n = 3, text = "Finish %d 💼 City Jobs", tier = 2, path = "any"},
	{key = "corner1", kind = "corner", n = 1, text = "Find %d ✨ Golden Corner", tier = 1, path = "any"},
	{key = "drive", kind = "drive", n = 3000, text = "Drive %s studs in your car", tier = 2, path = "any"},
	{key = "ride3", kind = "ride", n = 3, text = "Take %d 🎢 rides (any park or the Fun Park)", tier = 2, path = "any"},
	{key = "visit", kind = "visitPark", n = 1, text = "Ride at %d other player's 🎢 park", tier = 2, path = "any"},
	{key = "race1", kind = "race", n = 1, text = "Finish %d 🏁 race", tier = 3, path = "any"},
	{key = "show2", kind = "show", n = 2, text = "Run %d 🎬 theater shows", tier = 3, path = "mogul"},
	{key = "party1", kind = "party", n = 1, text = "Throw or join %d 🎉 party", tier = 1, path = "any"},
	{key = "heist1", kind = "heist", n = 1, text = "Pull off %d heist and get the loot to the base", tier = 3, path = "under", needs = "heist"},
	{key = "heist2", kind = "heist", n = 2, text = "Pull off %d heists without getting caught", tier = 4, path = "under", needs = "heist"},
	{key = "gift1", kind = "gift", n = 1, text = "Send someone a 💸 gift", tier = 2, path = "any"},
}
C.WEEKLY_POOL = {
	{key = "w_serve", kind = "serve", n = 100, text = "Serve %d customers this week", secs = 1800, min = 8000, rep = 20, badge = "weekServe", badgeName = "🧾 Crowd Pleaser"},
	{key = "w_cook", kind = "cook", n = 15, text = "Serve %d perfect 🍳 Rush Orders this week", secs = 1800, min = 8000, rep = 20, badge = "weekCook", badgeName = "🍳 Line Cook"},
	{key = "w_jobs", kind = "job", n = 5, text = "Finish %d 💼 City Jobs this week", secs = 1800, min = 8000, rep = 20, badge = "weekJobs", badgeName = "💼 Hustler"},
	{key = "w_earn", kind = "earnLegit", n = 50000, incomeSecs = 7200, text = "Earn $%s from your businesses this week", money = true, secs = 1800, min = 8000, rep = 20, badge = "weekEarn", badgeName = "💹 Money Maker"},
	{key = "w_park", kind = "parkRating", n = 70, max = true, tier = 4, text = "Build a 🎢 park rated %d or more", secs = 2400, min = 10000, rep = 25, badge = "weekPark", badgeName = "🎢 Thrill Builder"},
	{key = "w_ride", kind = "ride", n = 12, text = "Take %d 🎢 rides this week", secs = 1500, min = 6000, rep = 15, badge = "weekRide", badgeName = "🎡 Ride Fanatic"},
}
local MISSION, WEEKLY = {}, {}
for _, m in ipairs(C.MISSION_POOL) do MISSION[m.key] = m end
for _, m in ipairs(C.WEEKLY_POOL) do WEEKLY[m.key] = m end
C.DAILY = {missionSecs = 240, missionMin = 1200, missionRep = 3, claimGap = 1}

local function cashFor(d, secs, minimum)
	return math.max(minimum or 0, math.floor((F.incomePerSec and F.incomePerSec(d) or 0) * (secs or 0)))
end
local function targetOf(d, def)
	if def.money then return math.max(def.n, math.floor((F.incomePerSec(d) or 0) * (def.incomeSecs or 0) / 100) * 100) end
	return def.n
end
local function fill(def, n) return string.format(def.text, def.money and fmt(n) or (def.kind == "drive" and fmt(n) or n)) end

-- ===== the login streak =====
-- what claiming today would do: returns the cycle day (1-7), the new streak, whether the shield is used,
-- and the shield state after
local function streakToday(dl, today)
	local shield, shieldWeek = dl.shield, dl.shieldWeek
	local wk = F.utcWeek(today * DAY)
	if shieldWeek < wk then shield, shieldWeek = 1, wk end
	if dl.claimed <= 0 then return 1, 1, false, shield, shieldWeek end
	local gap = today - dl.claimed
	if gap <= 0 then return nil end
	local missed = gap - 1
	local used = false
	if missed >= 1 and shield >= 1 then
		missed -= 1
		shield = 0
		used = true
	end
	local nextDay = dl.cycle % 7 + 1
	if missed <= 0 then return nextDay, dl.streak + 1, used, shield, shieldWeek end
	return math.max(1, nextDay - missed), 1, used, shield, shieldWeek
end
F.dailyStreakToday = streakToday

-- ===== today's missions + this week's challenge (rolled when the day / week changes) =====
local function roll(plr, d, acct)
	local today, wk = F.utcDay(), F.utcWeek()
	local m = acct.missions
	if m.day ~= today then
		local tier = F.tierIndex(d.rep)
		local heistOK = type(d.heist) == "table" and d.heist.discovered == true
		local pool = {}
		for _, def in ipairs(C.MISSION_POOL) do
			if def.tier <= tier and (def.needs ~= "heist" or heistOK) then table.insert(pool, def) end
		end
		local rng = Random.new((plr.UserId % 100000) * 1000 + today % 1000)
		local picks, used = {}, {}
		while #picks < 3 and #pool > 0 do
			local i = rng:NextInteger(1, #pool)
			local def = table.remove(pool, i)
			if not used[def.kind] then
				used[def.kind] = true
				table.insert(picks, def.key)
			end
		end
		acct.missions = {day = today, picks = picks, p = {0, 0, 0}, done = {false, false, false}, t = {}}
		for i, key in ipairs(picks) do acct.missions.t[i] = targetOf(d, MISSION[key]) end
	end
	local w = acct.weekly
	if w.week ~= wk then
		local tier = F.tierIndex(d.rep)
		local pool = {}
		for _, def in ipairs(C.WEEKLY_POOL) do if (def.tier or 1) <= tier then table.insert(pool, def) end end
		local def = pool[(wk % #pool) + 1]
		acct.weekly = {week = wk, key = def.key, p = 0, claimed = false, t = targetOf(d, def)}
	end
end
local function missionTarget(acct, i)
	local key = acct.missions.picks[i]
	return (acct.missions.t and acct.missions.t[i]) or (MISSION[key] and MISSION[key].n) or 1
end

-- ===== progress: only from F.track (server code), never from the client =====
local lastNote = {}
function F.dailyTrack(plr, kind, n)
	local d = data[plr]
	local acct = F.acct and F.acct(plr)
	if not (d and acct) then return end
	n = tonumber(n) or 1
	if n ~= n or n <= 0 then return end
	roll(plr, d, acct)
	local m = acct.missions
	for i, key in ipairs(m.picks) do
		local def = MISSION[key]
		local target = missionTarget(acct, i)
		if def and def.kind == kind and not m.done[i] and m.p[i] < target then
			m.p[i] = math.min(target, def.max and math.max(m.p[i], math.floor(n)) or (m.p[i] + math.floor(n)))
			if m.p[i] >= target then
				notify(plr, "✅ Daily mission done: " .. fill(def, target) .. "  (claim it in 🎁 Daily)", {pri = "critical", cat = "rep", key = "mission" .. i})
				R.Menu:FireClient(plr, "dailyPing", {what = "mission"})
			end
		end
	end
	local w = acct.weekly
	local wdef = WEEKLY[w.key]
	if wdef and wdef.kind == kind and not w.claimed then
		local target = w.t or wdef.n
		if w.p < target then
			w.p = math.min(target, wdef.max and math.max(w.p, math.floor(n)) or (w.p + math.floor(n)))
			if w.p >= target then
				notify(plr, "🏆 Weekly challenge done: " .. fill(wdef, target) .. "  (claim it in 🎁 Daily)", {pri = "critical", cat = "rep", key = "weekly"})
				R.Menu:FireClient(plr, "dailyPing", {what = "weekly"})
			end
		end
	end
	local _ = lastNote
end
-- chain onto the game's event bus (GameServer > Occasions' F.track feeds occasions + onboarding)
do
	local base = F.track
	F.track = function(plr, kind, n)
		if base then base(plr, kind, n) end
		F.dailyTrack(plr, kind, n)
		if F.pathTrack then F.pathTrack(plr, kind, n) end
		if F.liveTrack then F.liveTrack(plr, kind, n) end
	end
end

-- ===== reward items (paid with a grant into the slot being played) =====
C.GRANT_ITEMS = C.GRANT_ITEMS or {}
local GI = C.GRANT_ITEMS
GI.tokUpgrade = function(plr, d)
	d.tokens = type(d.tokens) == "table" and d.tokens or {}
	d.tokens.upgrade = math.min(5, (tonumber(d.tokens.upgrade) or 0) + 1)
end
GI.tokCarmod = function(plr, d)
	d.tokens = type(d.tokens) == "table" and d.tokens or {}
	d.tokens.carmod = math.min(5, (tonumber(d.tokens.carmod) or 0) + 1)
end
GI.training = function(plr, d)
	for _, st in pairs(d.staff or {}) do
		if type(st) == "table" then st.xp = (tonumber(st.xp) or 0) + 40 end
	end
end
GI.decor = function(plr, d)
	d.furniture = type(d.furniture) == "table" and d.furniture or {}
	local key = C.DAILY_DECOR or "goldstatue"
	d.furniture[key] = (tonumber(d.furniture[key]) or 0) + 1
end
GI.contract = function(plr, d)
	if F.pathBonusContract then F.pathBonusContract(plr, d) end
end
GI.titleWeek = function() end   -- (the title goes into the account wardrobe when it's claimed)

-- ===== claims =====
local claimAt = {}
local function gap(plr)
	local t = os.clock()
	if claimAt[plr] and t - claimAt[plr] < C.DAILY.claimGap then return false end
	claimAt[plr] = t
	return true
end
function F.dailyClaim(plr)
	local d = data[plr]
	if not (d and F.acct(plr)) or d.noSave then
		if d and d.noSave then notify(plr, "⚠️ Rewards can't be claimed while your save isn't loading properly. Rejoin to try again.", {pri = "critical", cat = "warn"}) end
		return false
	end
	if not gap(plr) then return false end
	local today = F.utcDay()
	local got
	local ok = F.acctCommit(plr, function(acct)
		local dl = acct.daily
		local day, streak, used, shield, shieldWeek = streakToday(dl, today)
		if not day then return false end
		local r = DR[day]
		acct.daily = {claimed = today, cycle = day, streak = streak, best = math.max(dl.best, streak), shield = shield, shieldWeek = shieldWeek}
		if r.item == "titleWeek" then acct.wardrobe.titles.weekChamp = true end
		F.addGrant(plr, acct, {cash = cashFor(d, r.secs, r.min), rep = r.rep or 0, item = r.item, what = "Day " .. day .. ": " .. r.icon .. " " .. r.name})
		got = {day = day, used = used}
		return true
	end)
	if not ok then
		notify(plr, "🎁 Today's reward is already claimed. Next one in " .. F.dailyCountdown() .. ".", {pri = "normal", cat = "info"})
		return false
	end
	if got.used then notify(plr, "🛡️ Your streak shield saved your streak!", {pri = "critical", cat = "rep"}) end
	F.payGrants(plr)
	return true
end
function F.missionClaim(plr, i)
	local d = data[plr]
	if not (d and F.acct(plr)) or d.noSave or not C.int(i, 1, 3) then return false end
	if not gap(plr) then return false end
	local today = F.utcDay()
	local ok = F.acctCommit(plr, function(acct)
		local m = acct.missions
		local key = m.picks[i]
		local def = MISSION[key]
		if m.day ~= today or not def or m.done[i] or m.p[i] < missionTarget(acct, i) then return false end
		m.done[i] = true
		local DC = C.DAILY
		F.addGrant(plr, acct, {cash = cashFor(d, DC.missionSecs, DC.missionMin), rep = DC.missionRep, item = "path_" .. def.path, what = "Mission: " .. fill(def, missionTarget(acct, i))})
		return true
	end)
	if ok then F.payGrants(plr) end
	return ok
end
function F.weeklyClaim(plr)
	local d = data[plr]
	if not (d and F.acct(plr)) or d.noSave then return false end
	if not gap(plr) then return false end
	local wk = F.utcWeek()
	local ok = F.acctCommit(plr, function(acct)
		local w = acct.weekly
		local def = WEEKLY[w.key]
		if w.week ~= wk or not def or w.claimed or w.p < (w.t or def.n) then return false end
		w.claimed = true
		acct.wardrobe.badges[def.badge] = true
		F.addGrant(plr, acct, {cash = cashFor(d, def.secs, def.min), rep = def.rep, what = "Weekly: " .. def.badgeName})
		return true
	end)
	if ok then F.payGrants(plr) end
	return ok
end
-- (path XP from a mission: the mission's path, or "any" → nothing extra)
for _, p in ipairs({"mogul", "under", "any"}) do
	GI["path_" .. p] = function(plr, d) if F.pathXP and p ~= "any" then F.pathXP(plr, d, p, 25) end end
end

function F.dailyCountdown()
	local left = (F.utcDay() + 1) * DAY - now()
	return string.format("%dh %02dm", math.floor(left / 3600), math.floor(left % 3600 / 60))
end
function F.dailyInfo(plr)
	local d = data[plr]
	local acct = F.acct and F.acct(plr)
	if not (d and acct) then return nil end
	roll(plr, d, acct)
	local today = F.utcDay()
	local dl = acct.daily
	local day, streak, used = streakToday(dl, today)
	local info = {claimedToday = dl.claimed == today, today = day or dl.cycle, streak = dl.streak, best = dl.best, shield = (day and select(4, streakToday(dl, today))) or dl.shield,
		shieldUsedIfClaim = used == true, nextIn = (today + 1) * DAY - now(), rewards = {}, missions = {}, weekly = nil, canSave = not d.noSave}
	for i, r in ipairs(DR) do
		table.insert(info.rewards, {day = i, icon = r.icon, name = r.name, text = r.text, cash = cashFor(d, r.secs, r.min)})
	end
	local _ = streak
	local m = acct.missions
	for i, key in ipairs(m.picks) do
		local def = MISSION[key]
		if def then
			local target = missionTarget(acct, i)
			table.insert(info.missions, {i = i, text = fill(def, target), p = m.p[i], n = target, done = m.p[i] >= target, claimed = m.done[i], path = def.path,
				cash = cashFor(d, C.DAILY.missionSecs, C.DAILY.missionMin)})
		end
	end
	local w = acct.weekly
	local wdef = WEEKLY[w.key]
	if wdef then
		local target = w.t or wdef.n
		info.weekly = {text = fill(wdef, target), p = w.p, n = target, done = w.p >= target, claimed = w.claimed, badge = wdef.badgeName, cash = cashFor(d, wdef.secs, wdef.min),
			endsIn = (math.floor((F.utcDay() + 3) / 7) + 1) * 7 * DAY - 3 * DAY - now()}
	end
	if F.liveInfo then info.event = F.liveInfo(plr) end
	return info
end

C.ACTIONS = C.ACTIONS or {}
local function send(plr)
	local info = F.dailyInfo(plr)
	if info then R.Menu:FireClient(plr, "daily", info) end
end
C.ACTIONS.dailyInfo = function(plr) send(plr) end
C.ACTIONS.dailyClaim = function(plr) F.dailyClaim(plr) send(plr) end
C.ACTIONS.missionClaim = function(plr, d, a) F.missionClaim(plr, a) send(plr) end
C.ACTIONS.weeklyClaim = function(plr) F.weeklyClaim(plr) send(plr) end

-- ===== server-side sources the bus didn't have yet =====
-- driving: sampled every 2 s while the player sits in their own spawned car; a jump faster than any car can
-- go (a teleport) doesn't count
local lastPos = {}
task.spawn(function()
	while true do
		task.wait(2)
		for _, plr in ipairs(Players:GetPlayers()) do
			local car = F.activeCar and F.activeCar(plr)
			local seat = car and car.seat
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if seat and hum and seat.Occupant == hum and data[plr] then
				local p = seat.Position
				local prev = lastPos[plr]
				lastPos[plr] = p
				if prev then
					local dist = (p - prev).Magnitude
					if dist > 1 and dist < 2 * 160 then F.track(plr, "drive", math.floor(dist)) end
				end
			else
				lastPos[plr] = nil
			end
		end
		-- the park's rating, for "build a park rated N" (max-type: it only counts the best value)
		for plr, d in pairs(data) do
			if (d.levels.park or 0) > 0 and F.parkScore then
				local rating = F.parkScore(d)
				if rating > 0 then F.dailyTrack(plr, "parkRating", rating) end
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) lastPos[plr], claimAt[plr] = nil, nil end)
end
