-- ONBOARDING (v14): after the tutorial, a staged path of 10 next steps, one at a time, that walks a new player
-- through everything the city has (each with a "Show me" that opens the right app, and a small reward):
--   1 serve a perfect Rush Order   2 hire an employee   3 open a second business   4 find a Golden Corner
--   5 finish a City Job   6 tune or customize a car   7 buy a city plot   8 throw or join a party
--   9 win a rival challenge   10 open the Movie Theater
-- A step that needs more reputation says so and can be skipped for now (it comes back at the end). Steps a
-- save has already done are recognized on the first check without paying them again (veterans aren't flooded).
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify

local function count(t) local n = 0 for _ in pairs(type(t) == "table" and t or {}) do n += 1 end return n end
local S = function(key, icon, title, text, app, tier, check) return {key = key, icon = icon, title = title, text = text, app = app, tier = tier or 1, check = check} end
local STEPS = {
	S("cook", "🍳", "Serve a perfect Rush Order", "Walk up to your business and press 🍳 Rush orders, then tap the recipe steps in order.", nil, 1,
		function(d, o) return (o.c.cook or 0) >= 1 end),
	S("hire", "👥", "Hire your first employee", "Phone → 👥 Staff → Hire. Pick a trait you like and a shift.", "staff", 2,
		function(d) return next(d.staff or {}) ~= nil end),
	S("second", "🏪", "Open a second business", "Tap a business you haven't opened on your plot (the Ice Cream Cart is a good start).", nil, 1,
		function(d) local n = 0 for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then n += 1 end end return n >= 2 end),
	S("corner", "✨", "Find a Golden Corner", "Glowing coins hide on street corners all over the city. Phone → 🧭 Explore shows hints.", "explore", 1,
		function(d) return type(d.city) == "table" and count(d.city.corners) >= 1 end),
	S("job", "💼", "Finish a City Job", "Phone → 🧭 Explore → City Jobs: deliver a parcel, walk a dog...", "explore", 1,
		function(d) return type(d.city) == "table" and (tonumber(d.city.jobs) or 0) >= 1 end),
	S("car", "🔧", "Tune or customize a car", "Phone → 🚗 Garage → 🎨 on a car you own: paint, parts and 🔧 tuning.", "garage", 2,
		function(d) return next(type(d.tune) == "table" and d.tune or {}) ~= nil or next(type(d.carMods) == "table" and d.carMods or {}) ~= nil end),
	S("plot", "🏙️", "Buy a city plot", "Phone → 🏢 Properties: a plot in a district gives a business a new location.", "properties", 2,
		function(d) return #(d.deeds or {}) >= 1 end),
	S("party", "🎉", "Throw or join a party", "Phone → 🎉 Party: start one at your home or loft, or join someone's.", "party", 1,
		function(d, o) return (o.c.party or 0) >= 1 or (type(d.party) == "table" and (tonumber(d.party.hosted) or 0) >= 1) end),
	S("rival", "🥊", "Win a rival challenge", "When a rival moves on your business, do what the challenge card says before time runs out.", "rivals", 1,
		function(d) return type(d.rivals) == "table" and (tonumber(d.rivals.wins) or 0) >= 1 end),
	S("theater", "🎬", "Open the Movie Theater", "Buy a city plot, then choose 🎬 Movie Theater on it.", "theater", 3,
		function(d) return (d.levels.theater or 0) > 0 end),
}
C.ONBOARD_STEPS = STEPS
local OB = {rewardSecs = 60, rewardMin = 200, rep = 5}
C.ONBOARD = OB

local function rec(d)
	if type(d.onboard) ~= "table" then d.onboard = {} end
	local o = d.onboard
	o.done = type(o.done) == "table" and o.done or {}
	o.skip = type(o.skip) == "table" and o.skip or {}
	o.c = type(o.c) == "table" and o.c or {}
	return o
end
-- the step to show: the first not-done, not-skipped one (skipped ones come back once the rest are done)
local function current(d, o)
	for i, s in ipairs(STEPS) do if not o.done[s.key] and not o.skip[s.key] then return i, s end end
	for i, s in ipairs(STEPS) do if not o.done[s.key] then return i, s end end
	return nil
end
local function view(plr, d)
	local o = rec(d)
	local i, s = current(d, o)
	if not s then return {finished = true, done = count(o.done), total = #STEPS} end
	local locked = F.tierIndex(d.rep) < s.tier
	return {step = i, total = #STEPS, done = count(o.done), key = s.key, icon = s.icon, title = s.title, text = s.text, app = s.app,
		locked = locked, need = locked and C.REP_TIERS[s.tier].name or nil, reward = math.floor(math.max(OB.rewardMin, F.incomePerSec(d) * OB.rewardSecs))}
end
local last = {}
local function push(plr, d, force)
	local v = view(plr, d)
	local sig = (v.key or "fin") .. ":" .. tostring(v.locked) .. ":" .. tostring(v.done)
	if force or last[plr] ~= sig then
		last[plr] = sig
		R.Menu:FireClient(plr, "onboard", v)
	end
end
function F.onboardCheck(plr, force)
	local d = data[plr]
	if not d or (d.tut or 0) ~= 0 then return 0 end   -- (the tutorial comes first)
	local o = rec(d)
	local first = o.seeded ~= true
	local n = 0
	for _, s in ipairs(STEPS) do
		if not o.done[s.key] then
			local ok, yes = pcall(s.check, d, o)
			if ok and yes then
				o.done[s.key] = os.time()
				n += 1
				if not first then
					local cash = math.floor(math.max(OB.rewardMin, F.incomePerSec(d) * OB.rewardSecs))
					d.cash += cash
					F.earn(d, cash)
					F.addRep(plr, OB.rep)
					notify(plr, "✅ " .. s.icon .. " " .. s.title .. ": +$" .. fmt(cash) .. " and +" .. OB.rep .. " rep")
					R.Menu:FireClient(plr, "onboardDone", {title = s.title, icon = s.icon, cash = cash})
				end
			end
		end
	end
	if first then o.seeded = true end
	if count(o.done) >= #STEPS and not o.finished then
		o.finished = true
		if not first then
			R.Splash:FireClient(plr, "🧭 YOU KNOW THE CITY!", "All 10 steps done. The rest is up to you.", RGB(120, 230, 150))
		end
	end
	push(plr, d, force)
	return n
end
-- counted events (things with no lasting record of their own)
function F.onboardTrack(plr, kind, n)
	local d = data[plr]
	if not d or (kind ~= "cook" and kind ~= "party") then return end
	local o = rec(d)
	o.c[kind] = (tonumber(o.c[kind]) or 0) + (n or 1)
	F.onboardCheck(plr)
end
function F.onboardSkip(plr)
	local d = data[plr]
	if not d then return false end
	local o = rec(d)
	local _, s = current(d, o)
	if not s or o.skip[s.key] then return false end
	o.skip[s.key] = true
	push(plr, d, true)
	return true
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.onboardSkip = function(plr) F.onboardSkip(plr) end
C.ACTIONS.onboardInfo = function(plr) F.onboardCheck(plr, true) end

task.spawn(function()
	while true do
		task.wait(3)
		for _, plr in ipairs(Players:GetPlayers()) do
			if data[plr] then pcall(F.onboardCheck, plr) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) last[plr] = nil end)
end
