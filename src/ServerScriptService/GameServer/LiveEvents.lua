-- LIVE EVENTS (v16): something always going on in the city. One CITY EVENT at a time on a fixed UTC schedule
-- (4-hour windows), worked out from the clock alone, so every server runs the same event at the same time:
--   weekdays rotate through 🍽️ Restaurant Rush, 🎡 Funland Night, 🥊 Rival Takeover, 📦 Double Delivery,
--   🚨 Underworld Alert and 🏎️ Luxury Showcase; Saturdays and Sundays (UTC) are 🤝 Community Weekend.
-- Each event boosts something (F.liveMult, read by the systems it touches; events only ever ADD, nothing is
-- taken away when one ends) and has an optional goal with a reward: claimed once per event window per account
-- (written ahead like every account reward). The plaza board shows the event; a player hears about a new one
-- when they're not busy (riding, mid-heist, cooking, in a cutscene). Definitions are data: C.LIVE_EVENTS.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local P, surfaceText = C.P, C.surfaceText
local V3, CF, MAT = Vector3.new, CFrame.new, Enum.Material

C.LIVE_WINDOW = 4 * 3600
C.LIVE_EVENTS = {
	{key = "rush", icon = "🍽️", name = "Restaurant Rush", color = RGB(255, 140, 60), text = "Hungry crowds: +25% customers at every business.",
		mult = {customers = 1.25}, goal = {kind = "cook", n = 5, text = "Serve 5 perfect 🍳 Rush Orders"}, reward = {secs = 600, min = 3000}},
	{key = "funland", icon = "🎡", name = "Funland Night", color = RGB(255, 90, 200), text = "Parks are packed: twice the visitors, ride tickets ×1.5.",
		mult = {parkVisitors = 2, parkTicket = 1.5}, goal = {kind = "ride", n = 3, text = "Take 3 🎢 rides"}, reward = {secs = 600, min = 3000}},
	{key = "rival", icon = "🥊", name = "Rival Takeover", color = RGB(230, 70, 70), text = "The rivals are pushing hard: rival challenge prizes ×2.",
		mult = {rivalPrize = 2}, goal = {kind = "rivalWin", n = 1, text = "Win a 🥊 rival challenge"}, reward = {secs = 900, min = 4000}},
	{key = "delivery", icon = "📦", name = "Double Delivery Day", color = RGB(90, 200, 120), text = "City Jobs pay double.",
		mult = {jobPay = 2}, goal = {kind = "job", n = 3, text = "Finish 3 💼 City Jobs"}, reward = {secs = 600, min = 3000}},
	{key = "underworld", icon = "🚨", name = "Underworld Alert", color = RGB(150, 90, 255), text = "Big scores out there: heist payouts +30% (the police are watching too). Optional!",
		mult = {heistPay = 1.3}, goal = {kind = "heist", n = 1, text = "Get 1 heist home to the base", needs = "heist"}, reward = {secs = 900, min = 5000}},
	{key = "luxury", icon = "🏎️", name = "Luxury Showcase", color = RGB(255, 210, 90), text = "Show off your ride: customize your cars.",
		mult = {}, goal = {kind = "carmod", n = 2, text = "Customize your car twice (paint or parts)"}, reward = {secs = 600, min = 3000}},
	{key = "community", icon = "🤝", name = "Community Weekend", color = RGB(80, 200, 255), text = "Visit each other's parks: visitor rewards ×2, more park visitors.",
		mult = {visitReward = 2, parkVisitors = 1.5}, goal = {kind = "visitPark", n = 2, text = "Ride at 2 other players' parks"}, reward = {secs = 900, min = 4000}, weekend = true},
}
local LIST, BYKEY = {}, {}
for _, e in ipairs(C.LIVE_EVENTS) do
	BYKEY[e.key] = e
	if not e.weekend then table.insert(LIST, e) end
end
local function now() return C.dailyClock and C.dailyClock() or os.time() end
-- the event at time t (and its window): the same answer on every server
function F.liveAt(t)
	t = t or now()
	local win = math.floor(t / C.LIVE_WINDOW)
	local day = math.floor(t / 86400)
	local weekday = (day + 4) % 7   -- 0 = Sunday (1970-01-01 was a Thursday)
	local ev
	if weekday == 0 or weekday == 6 then ev = BYKEY.community
	else ev = LIST[(win * 5 + 3) % #LIST + 1] end
	return ev, win, win * C.LIVE_WINDOW, (win + 1) * C.LIVE_WINDOW
end
function F.liveMult(kind)
	local ev = F.liveAt()
	return ev and ev.mult[kind] or 1
end

-- ===== the goal (progress this session, per window; the reward is claimed once per window per account) =====
local prog = {}   -- [plr] = {id, p}
local function evId(ev, win) return ev.key .. win end
function F.liveTrack(plr, kind, n)
	local ev, win = F.liveAt()
	if not (ev and ev.goal and ev.goal.kind == kind) then return end
	local id = evId(ev, win)
	local pr = prog[plr]
	if not pr or pr.id ~= id then
		pr = {id = id, p = 0}
		prog[plr] = pr
	end
	if pr.p >= ev.goal.n then return end
	pr.p = math.min(ev.goal.n, pr.p + math.max(1, math.floor(tonumber(n) or 1)))
	if pr.p >= ev.goal.n then
		notify(plr, ev.icon .. " " .. ev.name .. " goal done! Claim it in 🎁 Daily.", {pri = "critical", cat = "rep", key = "liveGoal"})
		R.Menu:FireClient(plr, "dailyPing", {what = "event"})
	end
end
function F.liveClaim(plr)
	local d = data[plr]
	if not d or d.noSave then return false end
	local ev, win = F.liveAt()
	local id = evId(ev, win)
	local pr = prog[plr]
	if not (ev.goal and pr and pr.id == id and pr.p >= ev.goal.n) then return false end
	local ok = F.acctCommit(plr, function(acct)
		if acct.events[id] then return false end
		acct.events[id] = win
		-- keep only the recent windows (a week's worth)
		for k, w in pairs(acct.events) do if (tonumber(w) or 0) < win - 42 then acct.events[k] = nil end end
		F.addGrant(plr, acct, {cash = math.max(ev.reward.min, math.floor(F.incomePerSec(d) * ev.reward.secs)), rep = 5, what = ev.icon .. " " .. ev.name})
		return true
	end)
	if ok then F.payGrants(plr) end
	return ok
end
function F.liveInfo(plr)
	local ev, win, t0, t1 = F.liveAt()
	local nxt = F.liveAt(t1 + 1)
	local pr = prog[plr]
	local id = evId(ev, win)
	local acct = F.acct and F.acct(plr)
	local p = (pr and pr.id == id) and pr.p or 0
	local d = data[plr]
	return {key = ev.key, icon = ev.icon, name = ev.name, text = ev.text, color = ev.color, startsAt = t0, endsAt = t1, endsIn = t1 - now(),
		goal = ev.goal and ev.goal.text or nil, p = p, n = ev.goal and ev.goal.n or 0, done = ev.goal ~= nil and p >= ev.goal.n,
		claimed = acct ~= nil and acct.events[id] ~= nil, cash = d and math.max(ev.reward.min, math.floor(F.incomePerSec(d) * ev.reward.secs)) or 0,
		nextName = nxt.name, nextIcon = nxt.icon}
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.liveClaim = function(plr)
	F.liveClaim(plr)
	if C.ACTIONS.dailyInfo then C.ACTIONS.dailyInfo(plr) end
end

-- ===== is a player in the middle of something? (no announcements then) =====
function F.playerBusy(plr)
	if F.isRiding and F.isRiding(plr) then return true end
	if F.heistActive and F.heistActive(plr) then return true end
	if F.cookShift and F.cookShift(plr) ~= nil then return true end
	if plr:GetAttribute("InCinematic") or plr:GetAttribute("Racing") then return true end
	return false
end

-- ===== the plaza board =====
local board
do
	local f = C.WORLD
	local post = P(f, V3(0.8, 10, 0.8), CF(30, 5, 112), RGB(40, 42, 48), MAT.Metal)
	post.Name = "EventBoardPost"
	board = P(f, V3(14, 6, 0.6), CF(30, 12, 112), RGB(18, 24, 48), MAT.SmoothPlastic)
	board.Name = "EventBoard"
end
local shown
local function refreshBoard()
	local ev, win = F.liveAt()
	if shown == win then return end
	shown = win
	for _, x in ipairs(board:GetChildren()) do if x:IsA("SurfaceGui") then x:Destroy() end end
	surfaceText(board, Enum.NormalId.Front, ev.icon .. " CITY EVENT: " .. string.upper(ev.name) .. "\n" .. ev.text, ev.color)
	surfaceText(board, Enum.NormalId.Back, ev.icon .. " CITY EVENT: " .. string.upper(ev.name) .. "\n" .. ev.text, ev.color)
	game:GetService("Workspace"):SetAttribute("LiveEvent", ev.key)
end
refreshBoard()

-- ===== hearing about it (once per window, when not busy) =====
local told = {}
task.spawn(function()
	while true do
		task.wait(5)
		refreshBoard()
		local ev, win = F.liveAt()
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			if d and (d.tut or 0) == 0 and told[plr] ~= win and not F.playerBusy(plr) then
				told[plr] = win
				notify(plr, ev.icon .. " City event: " .. ev.name .. "! " .. ev.text, {pri = "normal", cat = "info", key = "live"})
			end
		end
	end
end)
-- ===== moments with a reason: a tour bus at a well-rated park =====
-- A park rated 60+ sometimes gets a tour bus: for 2 minutes twice the visitors walk round it (the visitor count
-- really goes up). At most once every 20 minutes per park; never while the owner is busy.
C.MOMENTS = {parkRushRating = 60, parkRushChance = 0.35, parkRushEvery = 300, parkRushGap = 1200, parkRushTime = 120, parkRushVisitors = 40}
local rushAt = {}
task.spawn(function()
	while true do
		task.wait(C.MOMENTS.parkRushEvery)
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			local site = d and F.parkSite and F.parkSite(plr)
			if site and F.parkScore and (F.parkScore(d)) >= C.MOMENTS.parkRushRating and os.clock() - (rushAt[plr] or -1e9) > C.MOMENTS.parkRushGap
				and not F.playerBusy(plr) and math.random() < C.MOMENTS.parkRushChance then
				rushAt[plr] = os.clock()
				F.parkRush(plr)
			end
		end
	end
end)
function F.parkRush(plr)
	local d = data[plr]
	local site = d and F.parkSite and F.parkSite(plr)
	if not site then return false end
	local p = F.parkRec(d)
	p.visitors += C.MOMENTS.parkRushVisitors
	site.folder:SetAttribute("Boost", 2 * (F.liveMult("parkVisitors") or 1))
	notify(plr, "🚌 A tour bus just pulled up at your park: +" .. C.MOMENTS.parkRushVisitors .. " visitors!", {pri = "normal", cat = "rep", key = "parkRush"})
	task.delay(C.MOMENTS.parkRushTime, function()
		if site.folder.Parent and F.parkSite(plr) == site then site.folder:SetAttribute("Boost", F.liveMult("parkVisitors") or 1) end
	end)
	return true
end
Players.PlayerRemoving:Connect(function(plr) prog[plr], told[plr], rushAt[plr] = nil, nil, nil end)
end
