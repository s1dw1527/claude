-- OCCASIONS (v14): scheduled special events on the real calendar (UTC, the same in every server).
--   🎃 Spooky Season (Oct 10 - Nov 1)   ❄️ Winter Lights (Dec 10 - Jan 2)   💘 Sweetheart Week (Feb 7 - 15)
--   🌸 Spring Fair (Apr 1 - 14)         ☀️ Summer Beach Fest (Jul 1 - 21)   🎂 City Birthday (the 1st-3rd of every month)
--   plus 🔥 WEEKEND RUSH every Saturday and Sunday: Rush Orders tips ×1.5 (the per-minute cap still applies).
-- Each occasion has 3 tasks (cook, throw or join a party, find Golden Corners, theater shows, City Jobs, gifts...)
-- tracked on the server as you play. Finish all three to claim its reward: cash (minutes of your own income),
-- reputation and a keepsake that stays in your save. Progress and claims are SAVED per occasion instance (e.g.
-- spooky2026), so leaving doesn't lose anything, a reward can't be claimed twice, and a late claim is accepted for
-- 3 days after it ends. While one is on, the Empire Plaza is decorated for it.
return function(C)
local Players = game:GetService("Players")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local MAT = Enum.Material
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local P = C.P

local OC = {grace = 3 * 86400, keep = 8}
C.OCCASION = OC
-- t = function() → the time used (tests set C.occasionClock)
local function now() return C.occasionClock and C.occasionClock() or os.time() end
local T = function(kind, n, text) return {kind = kind, n = n, text = text} end
local LIST = {
	{key = "spooky", icon = "🎃", name = "Spooky Season", from = {10, 10}, to = {11, 1}, color = RGB(255, 140, 30),
		tasks = {T("cook", 15, "Serve 15 perfect 🍳 Rush Orders"), T("party", 1, "Throw or join a 🎉 party"), T("corner", 3, "Find 3 ✨ Golden Corners")},
		reward = {secs = 900, min = 5000, rep = 25, keep = "🎃 Pumpkin Mogul badge"}},
	{key = "winter", icon = "❄️", name = "Winter Lights", from = {12, 10}, to = {1, 2}, color = RGB(140, 200, 255),
		tasks = {T("show", 5, "Run 5 🎬 theater shows"), T("job", 3, "Finish 3 💼 City Jobs"), T("gift", 1, "Send someone a 💸 gift")},
		reward = {secs = 900, min = 5000, rep = 25, keep = "❄️ Snow Globe badge"}},
	{key = "sweet", icon = "💘", name = "Sweetheart Week", from = {2, 7}, to = {2, 15}, color = RGB(255, 110, 170),
		tasks = {T("partner", 1, "Team up with a 🤝 partner"), T("cook", 10, "Serve 10 perfect 🍳 Rush Orders"), T("party", 1, "Throw or join a 🎉 party")},
		reward = {secs = 600, min = 3000, rep = 20, keep = "💘 Sweetheart badge"}},
	{key = "spring", icon = "🌸", name = "Spring Fair", from = {4, 1}, to = {4, 14}, color = RGB(255, 170, 210),
		tasks = {T("upgrade", 10, "Upgrade businesses 10 times"), T("corner", 3, "Find 3 ✨ Golden Corners"), T("race", 1, "Finish a 🏁 race")},
		reward = {secs = 600, min = 3000, rep = 20, keep = "🌸 Blossom badge"}},
	{key = "summer", icon = "☀️", name = "Summer Beach Fest", from = {7, 1}, to = {7, 21}, color = RGB(255, 210, 80),
		tasks = {T("cook", 20, "Serve 20 perfect 🍳 Rush Orders"), T("job", 3, "Finish 3 💼 City Jobs"), T("party", 2, "Throw or join 2 🎉 parties")},
		reward = {secs = 900, min = 5000, rep = 25, keep = "☀️ Beach Boss badge"}},
	{key = "birthday", icon = "🎂", name = "City Birthday", monthly = {1, 3}, color = RGB(255, 205, 80),
		tasks = {T("upgrade", 3, "Upgrade businesses 3 times"), T("cook", 5, "Serve 5 perfect 🍳 Rush Orders"), T("corner", 1, "Find a ✨ Golden Corner")},
		reward = {secs = 300, min = 1000, rep = 10}},
}
C.OCCASIONS = LIST

-- ===== the calendar =====
local function md(t) return t.month * 100 + t.day end
-- the instance (id, starts, ends) of an occasion around time ts, or nil
local function instanceAt(o, ts)
	local t = os.date("!*t", ts)
	if o.monthly then
		if t.day >= o.monthly[1] and t.day <= o.monthly[2] + 3 then
			local s = os.time({year = t.year, month = t.month, day = o.monthly[1], hour = 0})
			local e = os.time({year = t.year, month = t.month, day = o.monthly[2], hour = 23, min = 59, sec = 59})
			return {id = o.key .. t.year .. string.format("%02d", t.month), starts = s, ends = e}
		end
		return nil
	end
	local f, to = o.from[1] * 100 + o.from[2], o.to[1] * 100 + o.to[2]
	local x = md(t)
	local year = t.year
	local inside, startYear
	if f <= to then
		inside = x >= f and x <= to
		startYear = year
	else   -- wraps over New Year
		inside = x >= f or x <= to
		startYear = x >= f and year or year - 1
	end
	-- (a few days after the end still counts as "this one", for late claims)
	if not inside then
		local endYear = (f <= to) and year or (x >= f and year + 1 or year)
		local endT = os.time({year = endYear, month = o.to[1], day = o.to[2], hour = 23, min = 59, sec = 59})
		if ts > endT and ts - endT <= OC.grace then
			startYear = (f <= to) and year or year - 1
		else
			return nil
		end
	end
	local s = os.time({year = startYear, month = o.from[1], day = o.from[2], hour = 0})
	local e = os.time({year = (f <= to) and startYear or startYear + 1, month = o.to[1], day = o.to[2], hour = 23, min = 59, sec = 59})
	return {id = o.key .. startYear, starts = s, ends = e}
end
-- the occasions running now (or just ended, still claimable)
function F.occasionsNow(ts)
	ts = ts or now()
	local out = {}
	for _, o in ipairs(LIST) do
		local inst = instanceAt(o, ts)
		if inst and ts >= inst.starts then
			inst.o = o
			inst.live = ts <= inst.ends
			table.insert(out, inst)
		end
	end
	return out
end
function F.weekendRush(ts)
	local w = os.date("!*t", ts or now()).wday   -- 1 = Sunday, 7 = Saturday
	return w == 1 or w == 7
end
-- the multiplier a scheduled modifier gives right now
function F.occasionMult(kind)
	if kind == "tips" and F.weekendRush() then return 1.5 end
	return 1
end
-- the next few occasions (for the app)
local function upcoming(ts)
	local out = {}
	for day = 1, 120 do
		local t = ts + day * 86400
		for _, o in ipairs(LIST) do
			local inst = instanceAt(o, t)
			if inst and t >= inst.starts and t <= inst.ends and not out[o.key] then
				local live = false
				for _, n in ipairs(F.occasionsNow(ts)) do if n.o == o and n.live then live = true end end
				if not live then out[o.key] = {icon = o.icon, name = o.name, inDays = math.max(1, math.ceil((inst.starts - ts) / 86400)), order = inst.starts} end
			end
		end
	end
	local list = {}
	for _, e in pairs(out) do table.insert(list, e) end
	table.sort(list, function(x, y) return x.order < y.order end)
	while #list > 3 do table.remove(list) end
	return list
end

-- ===== progress (saved) =====
local function rec(d)
	if type(d.events) ~= "table" then d.events = {} end
	local e = d.events
	e.inst = type(e.inst) == "table" and e.inst or {}
	e.keep = type(e.keep) == "table" and e.keep or {}
	return e
end
local function instRec(d, id)
	local e = rec(d)
	local r = e.inst[id]
	if type(r) ~= "table" then
		r = {p = {}, t = os.time()}
		e.inst[id] = r
		-- only the latest few instances are kept
		local ids = {}
		for k, v in pairs(e.inst) do table.insert(ids, {k = k, t = type(v) == "table" and tonumber(v.t) or 0}) end
		table.sort(ids, function(x, y) return x.t > y.t end)
		for i = OC.keep + 1, #ids do e.inst[ids[i].k] = nil end
	end
	r.p = type(r.p) == "table" and r.p or {}
	return r
end
-- something happened that occasions (and onboarding) care about
function F.track(plr, kind, n)
	local d = data[plr]
	if not d then return end
	n = n or 1
	for _, inst in ipairs(F.occasionsNow()) do
		if inst.live then
			local r = instRec(d, inst.id)
			if not r.claimed then
				for i, task in ipairs(inst.o.tasks) do
					if task.kind == kind then
						local before = tonumber(r.p[i]) or 0
						if before < task.n then
							r.p[i] = math.min(task.n, before + n)
							if r.p[i] >= task.n then notify(plr, inst.o.icon .. " " .. inst.o.name .. ": \"" .. task.text .. "\" done!") end
						end
					end
				end
			end
		end
	end
	if F.onboardTrack then F.onboardTrack(plr, kind, n) end
end
local function complete(r, o)
	for i, task in ipairs(o.tasks) do if (tonumber(r.p[i]) or 0) < task.n then return false end end
	return true
end
function F.occasionClaim(plr, id)
	local d = data[plr]
	if not (d and type(id) == "string") then return false end
	for _, inst in ipairs(F.occasionsNow()) do
		if inst.id == id then
			local r = instRec(d, id)
			if r.claimed then notify(plr, "🎁 Already claimed.") return false end
			if not complete(r, inst.o) then notify(plr, "🎁 Finish all three tasks first.") return false end
			local rw = inst.o.reward
			local cash = math.floor(math.max(rw.min, F.incomePerSec(d) * rw.secs))
			r.claimed = os.time()
			d.cash += cash
			F.earn(d, cash)
			if rw.rep then F.addRep(plr, rw.rep) end
			if rw.keep then rec(d).keep[inst.o.key] = rw.keep end
			R.Splash:FireClient(plr, inst.o.icon .. " " .. string.upper(inst.o.name) .. " COMPLETE!", "+$" .. fmt(cash) .. (rw.rep and ("  •  +" .. rw.rep .. " rep") or "") .. (rw.keep and ("  •  " .. rw.keep) or ""), inst.o.color)
			F.buzz(inst.o.icon, plr.Name .. " completed " .. inst.o.name .. "!", inst.o.color)
			return true
		end
	end
	notify(plr, "🎁 That event is over.")
	return false
end
function F.occasionInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local ts = now()
	local info = {list = {}, weekend = F.weekendRush(ts), upcoming = upcoming(ts), keep = {}}
	for _, inst in ipairs(F.occasionsNow(ts)) do
		local r = instRec(d, inst.id)
		local tasks = {}
		for i, task in ipairs(inst.o.tasks) do table.insert(tasks, {text = task.text, have = tonumber(r.p[i]) or 0, n = task.n}) end
		table.insert(info.list, {id = inst.id, key = inst.o.key, icon = inst.o.icon, name = inst.o.name, live = inst.live, left = math.max(0, inst.ends - ts),
			tasks = tasks, claimed = r.claimed ~= nil, ready = complete(r, inst.o) and not r.claimed, keep = inst.o.reward.keep,
			cash = math.floor(math.max(inst.o.reward.min, F.incomePerSec(d) * inst.o.reward.secs)), rep = inst.o.reward.rep})
	end
	for _, v in pairs(rec(d).keep) do table.insert(info.keep, v) end
	return info
end
C.ACTIONS = C.ACTIONS or {}
local function refresh(plr) local i = F.occasionInfo(plr) if i then R.Menu:FireClient(plr, "occasions", i) end end
C.ACTIONS.occasionInfo = function(plr) refresh(plr) end
C.ACTIONS.occasionClaim = function(plr, d, a) F.occasionClaim(plr, a) refresh(plr) end

-- ===== the plaza dresses up for it =====
local deco, decoKey
local function dress()
	local live
	for _, inst in ipairs(F.occasionsNow()) do if inst.live and not inst.o.monthly then live = inst.o end end
	local key = live and live.key or nil
	if key == decoKey then return end
	decoKey = key
	if deco then deco:Destroy() deco = nil end
	if not live or not C.PLAZA_AT then return end
	deco = Instance.new("Model")
	deco.Name = "OccasionDecor"
	deco.Parent = C.WORLD
	local at = C.PLAZA_AT
	local col = live.color
	-- an arch with the occasion's name and lanterns along the plaza
	for _, sx in ipairs({-9, 9}) do P(deco, V3(1.4, 14, 1.4), CF(at + V3(sx, 7.4, 30)), col, MAT.SmoothPlastic) end
	local top = P(deco, V3(20, 3, 1.4), CF(at + V3(0, 15.4, 30)), col, MAT.Neon)
	C.surfaceText(top, Enum.NormalId.Front, live.icon .. " " .. string.upper(live.name) .. " " .. live.icon, RGB(30, 20, 20))
	C.surfaceText(top, Enum.NormalId.Back, live.icon .. " " .. string.upper(live.name) .. " " .. live.icon, RGB(30, 20, 20))
	for k = -5, 5 do
		local b = C.ball(deco, V3(1.8, 1.8, 1.8), CF(at + V3(k * 11, 1.7, 36)), col)
		b.Material = MAT.Neon
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = col, 12, 1.2
		l.Parent = b
	end
end
task.spawn(function()
	while true do
		pcall(dress)
		task.wait(60)
	end
end)
F.occasionDress = dress
end
