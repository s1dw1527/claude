-- SHOWCASE (v16): playing together.
--   * PARK VISITS: riding at another player's 🎢 park pays the visitor a small reward the first time each day at
--     each park (3 parks a day at most), and the owner a small "a friend dropped by" bonus once per visitor per
--     day (on top of the usual capped ride tickets). Both are account rewards, written ahead (no duplicates)
--   * CO-OP: partners who put money into a shared business (GameServer > Partners) both get a co-op bonus, once
--     per pair per day
--   * 🪪 SHOWCASE: a public profile card: empire stage, how many businesses, a net-worth TIER (never the exact
--     cash), park rating, prestige stars, paths, and the title + badge the player chose to wear. Nothing private
--     (no settings, no exact money, no account details) is in it.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify

C.SOCIAL = {visitSecs = 120, visitMin = 600, visitCap = 3, hostSecs = 90, hostMin = 400, coopSecs = 180, coopMin = 800}
local S = C.SOCIAL

-- display names for wardrobe keys (titles come from paths, stages, daily rewards; badges from weekly challenges)
function F.titleName(key)
	if type(key) ~= "string" or key == "" then return nil end
	if key == "weekChamp" then return "👑 Week Champion" end
	local path, lv = string.match(key, "^(%a+)(%d+)$")
	if path == "stage" and C.ROADMAP and C.ROADMAP[tonumber(lv)] then local st = C.ROADMAP[tonumber(lv)] return st.icon .. " " .. st.name end
	for _, def in ipairs(C.PATHS_DEF or {}) do
		if def.key == path and def.levels[tonumber(lv)] then return def.icon .. " " .. def.levels[tonumber(lv)] end
	end
	return nil
end
function F.badgeName(key)
	for _, w in ipairs(C.WEEKLY_POOL or {}) do if w.badge == key then return w.badgeName end end
	return nil
end

local function today() return F.utcDay and F.utcDay() or math.floor(os.time() / 86400) end
local function countToday(acct, prefix)
	local n, t = 0, today()
	for k, v in pairs(acct.coop) do if string.sub(k, 1, #prefix) == prefix and v == t then n += 1 end end
	return n
end
-- old keys go (only today's matter)
local function prune(acct)
	local t = today()
	for k, v in pairs(acct.coop) do if v < t - 1 then acct.coop[k] = nil end end
end

-- a guest rode at owner's park (called by GameServer > Park after a real, server-checked ride)
function F.parkVisit(guest, owner)
	if guest == owner then return end
	local gd, od = data[guest], data[owner]
	if not (gd and od) or gd.noSave then return end
	local t = today()
	local key = "v" .. owner.UserId
	local mult = F.liveMult and F.liveMult("visitReward") or 1
	task.spawn(function()
		local ok = F.acctCommit(guest, function(acct)
			prune(acct)
			if acct.coop[key] == t or countToday(acct, "v") >= S.visitCap then return false end
			acct.coop[key] = t
			F.addGrant(guest, acct, {cash = math.floor(math.max(S.visitMin, F.incomePerSec(gd) * S.visitSecs) * mult), rep = 2, what = "🎢 Visited " .. owner.Name .. "'s park"})
			return true
		end)
		if ok then F.payGrants(guest) end
		if od.noSave then return end
		local hkey = "h" .. guest.UserId
		local ok2 = F.acctCommit(owner, function(acct)
			prune(acct)
			if acct.coop[hkey] == t then return false end
			acct.coop[hkey] = t
			F.addGrant(owner, acct, {cash = math.floor(math.max(S.hostMin, F.incomePerSec(od) * S.hostSecs) * mult), rep = 1, what = "🤝 " .. guest.Name .. " visited your park"})
			return true
		end)
		if ok2 then
			F.payGrants(owner)
			if F.track then F.track(owner, "coop") end
		end
	end)
end
-- two partners worked on a shared business together (called by GameServer > Partners)
function F.coopCredit(a, b, what)
	if a == b then return end
	for _, pair in ipairs({{a, b}, {b, a}}) do
		local me, other = pair[1], pair[2]
		local d = data[me]
		if d and not d.noSave then
			local key = "c" .. other.UserId
			task.spawn(function()
				local ok = F.acctCommit(me, function(acct)
					prune(acct)
					if acct.coop[key] == today() then return false end
					acct.coop[key] = today()
					F.addGrant(me, acct, {cash = math.max(S.coopMin, math.floor(F.incomePerSec(d) * S.coopSecs)), rep = 2, what = "🤝 Co-op with " .. other.Name .. (what and (": " .. what) or "")})
					return true
				end)
				if ok then
					F.payGrants(me)
					if F.track then F.track(me, "coop") end
				end
			end)
		end
	end
end

-- ===== 🪪 the public profile =====
local WORTH = {{1e10, "💎 $10B+"}, {1e9, "💎 $1B+"}, {1e8, "💰 $100M+"}, {1e6, "💰 $1M+"}, {1e5, "💵 $100K+"}, {1e3, "💵 $1K+"}, {0, "🪙 Just starting"}}
local function worthTier(v)
	for _, w in ipairs(WORTH) do if v >= w[1] then return w[2] end end
	return WORTH[#WORTH][2]
end
function F.showcase(target)
	local d = data[target]
	if not d then return nil end
	local acct = F.acct and F.acct(target)
	local stage = F.roadmapStage and F.roadmapStage(d) or 1
	local st = C.ROADMAP and C.ROADMAP[stage]
	local biz = 0
	for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then biz += 1 end end
	local out = {name = target.Name, stage = stage, stageName = st and (st.icon .. " " .. st.name) or "", businesses = biz, worth = worthTier(F.empireValue and F.empireValue(d) or d.cash),
		park = (d.levels.park or 0) > 0 and F.parkScore and (F.parkScore(d)) or nil, prestige = F.prestigeStars and F.prestigeStars(d) or 0,
		title = acct and F.titleName(acct.wardrobe.title) or nil, badge = acct and F.badgeName(acct.wardrobe.badge) or nil, paths = {}}
	if F.pathRec then
		local p = F.pathRec(d)
		for _, def in ipairs(C.PATHS_DEF) do
			local lv = F.pathLevel(p.xp[def.key])
			table.insert(out.paths, {icon = def.icon, name = def.name, level = lv, title = def.levels[lv]})
		end
	end
	return out
end
-- what I can wear (my own titles and badges only)
function F.wardrobeInfo(plr)
	local acct = F.acct and F.acct(plr)
	if not acct then return nil end
	local out = {titles = {}, badges = {}, title = acct.wardrobe.title, badge = acct.wardrobe.badge}
	for k in pairs(acct.wardrobe.titles) do local n = F.titleName(k) if n then table.insert(out.titles, {key = k, name = n}) end end
	for k in pairs(acct.wardrobe.badges) do local n = F.badgeName(k) if n then table.insert(out.badges, {key = k, name = n}) end end
	table.sort(out.titles, function(x, y) return x.name < y.name end)
	table.sort(out.badges, function(x, y) return x.name < y.name end)
	return out
end
function F.wear(plr, kind, key)
	local acct = F.acct and F.acct(plr)
	if not acct or (kind ~= "title" and kind ~= "badge") or type(key) ~= "string" then return false end
	local owned = kind == "title" and acct.wardrobe.titles or acct.wardrobe.badges
	if key ~= "" and not owned[key] then return false end
	acct.wardrobe[kind] = key
	return true
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.showcase = function(plr, d, a)
	local target = C.int(a, 1) and Players:GetPlayerByUserId(a) or plr
	local sc = target and F.showcase(target)
	if sc then
		if target == plr then sc.wardrobe = F.wardrobeInfo(plr) end
		R.Menu:FireClient(plr, "showcase", sc)
	end
end
C.ACTIONS.wear = function(plr, d, a, b)
	if C.str(a, 8) and C.str(b, 24) and F.wear(plr, a, b) then C.ACTIONS.showcase(plr, d) end
end
end
