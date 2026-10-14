-- ROADMAP (v16): the 🗺️ Empire Roadmap. Seven stages from a street corner to a legend, each built from the
-- game's REAL rules (reputation tiers from C.REP_TIERS, the businesses you run, your city plots, the empire
-- value), so it never promises something the game doesn't do. Each stage shows what you need, how far along you
-- are, and what opens up. Reaching a new stage is celebrated once (with a small cash gift); a save that was
-- already past some stages when v16 arrived is placed on the map without replaying (or paying) them.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local REP_TIERS = C.REP_TIERS

local function bizOpen(d)
	local n = 0
	for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then n += 1 end end
	return n
end
local function rep(t) return {label = "⭐ Reputation: " .. REP_TIERS[t].name, have = function(d) return math.floor(d.rep) end, need = REP_TIERS[t].rep} end
-- each stage: requirements (all of them), what it opens up, the reward for reaching it
C.ROADMAP = {
	{key = "street", icon = "🛒", name = "Street Starter", text = "A lemonade stand and a dream.", reqs = {},
		unlocks = REP_TIERS[1].unlocks},
	{key = "local", icon = "🏪", name = "Local Owner", text = "The neighborhood knows your name.", reqs = {rep(2)},
		unlocks = REP_TIERS[2].unlocks},
	{key = "builder", icon = "🏗️", name = "Business Builder", text = "Four businesses running at once.", reqs = {rep(2), {label = "🏪 Businesses open", have = bizOpen, need = 4}},
		unlocks = {"More customers and combos between your businesses", "Staff for every business"}},
	{key = "player", icon = "🏙️", name = "City Player", text = "The whole city is your market.", reqs = {rep(3)},
		unlocks = REP_TIERS[3].unlocks},
	{key = "property", icon = "🏢", name = "Property Mogul", text = "Your name on the city's best corners.",
		reqs = {rep(3), {label = "🏙️ City plots owned", have = function(d) return #(d.deeds or {}) end, need = 2}},
		unlocks = {"Businesses in two districts (location bonuses)", "The 🎬 Movie Theater on a city plot"}},
	{key = "icon", icon = "🌆", name = "City Icon", text = "A skyline with your logo on it.", reqs = {rep(4)},
		unlocks = REP_TIERS[4].unlocks},
	{key = "legend", icon = "👑", name = "Empire Legend", text = "A billion-dollar empire. Your legacy.",
		reqs = {rep(5), {label = "💎 Empire value", have = function(d) return F.empireValue and math.floor(F.empireValue(d)) or 0 end, need = 1e9, money = true}},
		unlocks = REP_TIERS[5].unlocks},
}
local STAGES = C.ROADMAP
C.ROADMAP_REWARD = {secs = 600, min = 2000}

-- how far along the map a save is (stages are reached in order)
function F.roadmapStage(d)
	local stage = 1
	for i = 2, #STAGES do
		local ok = true
		for _, r in ipairs(STAGES[i].reqs) do
			local okH, have = pcall(r.have, d)
			if not okH or (tonumber(have) or 0) < r.need then ok = false break end
		end
		if not ok then break end
		stage = i
	end
	return stage
end
local function rec(d)
	if type(d.roadmap) ~= "table" then d.roadmap = {} end
	d.roadmap.stage = math.max(0, math.floor(tonumber(d.roadmap.stage) or 0))
	return d.roadmap
end
local function rewardOf(d) return math.max(C.ROADMAP_REWARD.min, math.floor(F.incomePerSec(d) * C.ROADMAP_REWARD.secs)) end
function F.roadmapCheck(plr)
	local d = data[plr]
	if not d or (d.tut or 0) ~= 0 then return end
	local rm = rec(d)
	local stage = F.roadmapStage(d)
	if not rm.seeded then
		-- first look at this save: place it on the map, nothing replayed
		rm.seeded = true
		rm.stage = stage
		return
	end
	while rm.stage < stage do
		rm.stage += 1
		local st = STAGES[rm.stage]
		local cash = rewardOf(d)
		d.cash += cash
		F.earn(d, cash)
		local acct = F.acct and F.acct(plr)
		if acct then acct.wardrobe.titles["stage" .. rm.stage] = true end
		notify(plr, "🗺️ New stage: " .. st.icon .. " " .. st.name .. "  +$" .. fmt(cash), {pri = "critical", cat = "rep"})
		R.Menu:FireClient(plr, "roadmapStage", {stage = rm.stage, icon = st.icon, name = st.name, text = st.text, cash = cash, unlocks = st.unlocks})
	end
end

function F.roadmapInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local rm = rec(d)
	local now = F.roadmapStage(d)
	local out = {stage = now, celebrated = rm.stage, stages = {}, reward = rewardOf(d)}
	for i, st in ipairs(STAGES) do
		local reqs = {}
		for _, r in ipairs(st.reqs) do
			local okH, have = pcall(r.have, d)
			have = okH and (tonumber(have) or 0) or 0
			table.insert(reqs, {label = r.label, have = have, need = r.need, money = r.money, done = have >= r.need})
		end
		table.insert(out.stages, {i = i, key = st.key, icon = st.icon, name = st.name, text = st.text, reqs = reqs, unlocks = st.unlocks, done = i <= now, current = i == now})
	end
	if F.pathInfo then out.paths = F.pathInfo(plr) end
	return out
end
function F.roadmapSend(plr)
	local info = F.roadmapInfo(plr)
	if info then R.Menu:FireClient(plr, "roadmap", info) end
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.roadmapInfo = function(plr) F.roadmapSend(plr) end

task.spawn(function()
	while true do
		task.wait(4)
		for _, plr in ipairs(Players:GetPlayers()) do
			if data[plr] then pcall(F.roadmapCheck, plr) end
		end
	end
end)
end
