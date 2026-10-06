-- CITY EVENTS: the unexpected things that happen while you're running your empire.
--
-- Funny random events (one player at a time, minutes apart, never during the tutorial):
--   Health Inspector, Customer Army, Delivery Disaster, Rich Kid, Bad Investor
-- Rare viral events:
--   THE CROWD            - a big crowd gathers outside a business (after an influencer visit or a rush)
--   PAPARAZZI MODE       - photographers follow a player around for a bit (after a luxury purchase)
--   EVERYONE KNOWS YOU   - city people recognize you and shout as you walk past (Viral Score milestones)
--   BUSINESS BEEF        - a rival opens a pop-up next to your business: out-serve it before time runs out
-- The server decides everything and applies any reward; clients only draw the NPCs, and only near them.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

C.CITY_EVENTS = {
	funnyEvery = {420, 720},     -- seconds between funny events for one player
	crowdSize = 14, crowdTime = 40, crowdCustomers = 25,
	paparazziTime = 30, famousTime = 180,
	beefTime = 240, beefGoal = 0.8,  -- serve 80% of your usual customers for 4 minutes... at the business under attack
}
local E = C.CITY_EVENTS

local function ownedBusinesses(d)
	local out = {}
	for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then table.insert(out, b.key) end end
	return out
end
local function bestBusiness(d)
	local best, lvl = nil, 0
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > lvl then best, lvl = b.key, d.levels[b.key] end
	end
	return best
end
local function doorOf(d, key) return (F.slotCF(d.plot, key) * CF(0, 0, 9)).Position end

-- =====================================================================
-- RARE VIRAL EVENTS
-- =====================================================================
local busy = {}   -- [plr] = {crowd = t, paparazzi = t, famous = t, beef = {...}}
local function state(plr)
	busy[plr] = busy[plr] or {}
	return busy[plr]
end
-- THE CROWD: real extra customers at one business, and a crowd everyone nearby can see
function F.theCrowd(plr, key, why)
	local d = data[plr]
	if not d or (d.levels[key] or 0) <= 0 then return false end
	local st = state(plr)
	if (st.crowd or 0) > os.clock() then return false end
	st.crowd = os.clock() + E.crowdTime
	local door = doorOf(d, key)
	R.Viral:FireAllClients({kind = "crowd", owner = plr.UserId, pos = door, anchor = F.bizAnchor(d, key), n = E.crowdSize, dur = E.crowdTime, biz = BIZ[key].name, why = why})
	F.viralMoment(plr, "theCrowd", {biz = BIZ[key].name, pos = door})
	-- the crowd actually buys things: a burst of customers over 30 seconds
	task.spawn(function()
		local t = C.NPC_TYPES[1]
		for _ = 1, E.crowdCustomers do
			task.wait(30 / E.crowdCustomers)
			if data[plr] ~= d or (d.levels[key] or 0) <= 0 then return end   -- left, or sold the business: stop quietly
			F.serveCustomer(plr, d, key, t, nil)
		end
	end)
	return true
end
-- PAPARAZZI: photographers follow you (drawn by nearby clients)
function F.paparazzi(plr)
	local d = data[plr]
	if not d then return false end
	local st = state(plr)
	if (st.paparazzi or 0) > os.clock() then return false end
	st.paparazzi = os.clock() + E.paparazziTime
	R.Viral:FireAllClients({kind = "paparazzi", userId = plr.UserId, dur = E.paparazziTime})
	F.viralMoment(plr, "paparazzi", {})
	return true
end
-- EVERYONE KNOWS YOU: for a few minutes, people in the city recognize you
local FAMOUS_LINES = {"YO, THAT'S THE {biz} BOSS.", "IS THAT THE BILLIONAIRE?", "Bro owns half the city.", "Can I get a selfie?!", "My cousin works at your {biz}!",
	"THAT'S {name}!", "I saw you on CityBuzz!"}
function F.everyoneKnows(plr, milestone)
	local d = data[plr]
	if not d then return false end
	local st = state(plr)
	if (st.famous or 0) > os.clock() then return false end
	st.famous = os.clock() + E.famousTime
	local key = bestBusiness(d)
	local lines = {}
	for i, l in ipairs(FAMOUS_LINES) do lines[i] = (string.gsub(string.gsub(l, "{biz}", key and string.upper(BIZ[key].name) or "EMPIRE"), "{name}", string.upper(plr.Name))) end
	R.Viral:FireAllClients({kind = "famous", userId = plr.UserId, dur = E.famousTime, lines = lines})
	notify(plr, "🌟 EVERYONE KNOWS YOU. Walk around the city for a bit...")
	F.viralMoment(plr, "everyoneKnows", {})
	return true
end
-- BUSINESS BEEF: a rival pop-up next to your business. Serve enough customers there before it closes.
local beefFolder = Instance.new("Folder")
beefFolder.Name = "BusinessBeef"
beefFolder.Parent = Workspace
local RIVALS = {{name = "Lil Clipz", stand = "CLIPZ KIOSK 🎙️", color = RGB(255, 70, 140)}, {name = "Drew Deals", stand = "DREW'S DISCOUNT EVERYTHING 🤝", color = RGB(70, 160, 70)}}
function F.businessBeef(plr, key)
	local d = data[plr]
	if not d then return false end
	key = key or bestBusiness(d)
	if not key then return false end
	local st = state(plr)
	if st.beef then return false end
	local rival = RIVALS[math.random(#RIVALS)]
	local anchor = F.bizAnchor(d, key) * CF(12, 0, 8)
	local m = Instance.new("Model")
	m.Name = "Beef_" .. plr.UserId
	m.Parent = beefFolder
	C.P(m, V3(8, 3.4, 3.5), anchor * CF(0, 1.7, 0), RGB(240, 230, 210), Enum.Material.WoodPlanks)
	local top = C.P(m, V3(9, 0.4, 4.5), anchor * CF(0, 6, 0), rival.color)
	for _, x in ipairs({-4, 4}) do C.P(m, V3(0.3, 2.6, 0.3), anchor * CF(x, 4.6, 0), RGB(120, 90, 60)) end
	C.surfaceText(top, Enum.NormalId.Back, rival.stand, Color3.new(1, 1, 1))
	local rate = F.customerRate(d, os.clock())
	local share = (d.levels[key] or 1) / math.max(1, (function() local n = 0 for _, k in ipairs(ownedBusinesses(d)) do n += d.levels[k] end return n end)())
	local goal = math.max(8, math.floor(rate * share * E.beefTime * E.beefGoal))
	st.beef = {key = key, rival = rival, model = m, ends = os.clock() + E.beefTime, start = (d.bizServed and d.bizServed[key]) or 0, goal = goal}
	F.buzz("🥩", rival.name .. ": \"Let's see who actually knows how to run a business.\" (pop-up opened next to " .. plr.Name .. "'s " .. BIZ[key].name .. ")", rival.color, rival.name)
	notify(plr, "🥩 BUSINESS BEEF! " .. rival.name .. " opened a pop-up next to your " .. BIZ[key].name .. ". Serve " .. goal .. " customers there in 4 minutes!")
	R.Viral:FireClient(plr, {kind = "beef", key = key, rival = rival.name, goal = goal, dur = E.beefTime, pos = anchor.Position})
	return true
end
local function beefTick(plr, d, st)
	local b = st.beef
	if not b then return end
	local now = os.clock()
	local done = ((d.bizServed and d.bizServed[b.key]) or 0) - b.start
	if (d.levels[b.key] or 0) <= 0 then
		-- the business was sold mid-beef: the pop-up just packs up
		b.model:Destroy()
		st.beef = nil
		return
	end
	if done >= b.goal then
		b.model:Destroy()
		st.beef = nil
		F.addRep(plr, 15)
		notify(plr, "🥩 YOU WON THE BEEF! " .. b.rival.name .. " packed up the pop-up. (+15 rep)")
		F.viralMoment(plr, "beefWon", {rival = b.rival.name, biz = BIZ[b.key].name})
		R.Viral:FireClient(plr, {kind = "beefEnd", won = true})
	elseif now >= b.ends then
		b.model:Destroy()
		st.beef = nil
		notify(plr, "🥩 The pop-up closed. " .. b.rival.name .. " claims victory. (" .. done .. "/" .. b.goal .. " customers) Nothing lost, except pride.")
		F.buzz("🥩", b.rival.name .. ": \"Told you. I'm the CEO of " .. BIZ[b.key].name .. " now.\" (" .. plr.Name .. " served " .. done .. "/" .. b.goal .. ")", b.rival.color, b.rival.name)
		R.Viral:FireClient(plr, {kind = "beefEnd", won = false})
	end
end
C.beefState = function(plr) return busy[plr] and busy[plr].beef end
-- for the HUD: the beef in progress (and Bay Snaps' live challenge)
function F.beefInfo(plr, d, now)
	local st = busy[plr]
	if not st then return nil end
	local out
	if st.beef then
		local b = st.beef
		out = {kind = "beef", text = "🥩 BEEF vs " .. b.rival.name .. ": " .. math.max(0, ((d.bizServed and d.bizServed[b.key]) or 0) - b.start) .. "/" .. b.goal .. " customers at your " .. BIZ[b.key].name,
			left = math.max(0, math.ceil(b.ends - now))}
	elseif st.challenge then
		local c = st.challenge
		out = {kind = "challenge", text = "📸 LIVE CHALLENGE: " .. math.max(0, d.served - c.served) .. "/" .. c.goal .. " customers", left = math.max(0, math.ceil(c.ends - now))}
	end
	return out
end

-- Bay Snaps' live challenge: serve N customers in 2 minutes
function F.startChallenge(plr, key, inf)
	local d = data[plr]
	local st = state(plr)
	if not d or st.challenge then return false end
	local goal = math.max(6, math.floor(F.customerRate(d, os.clock()) * 120 * 0.9))
	st.challenge = {served = d.served, goal = goal, ends = os.clock() + 120, by = inf and inf.name or "Bay Snaps"}
	notify(plr, "📸 " .. st.challenge.by .. ": \"CHALLENGE! Serve " .. goal .. " customers in 2 minutes. CHAT IS WATCHING.\"")
	R.Viral:FireClient(plr, {kind = "challenge", goal = goal, dur = 120, by = st.challenge.by})
	return true
end
local function challengeTick(plr, d, st)
	local c = st.challenge
	if not c then return end
	local done = d.served - c.served
	if done >= c.goal then
		st.challenge = nil
		F.addRep(plr, 10)
		notify(plr, "📸 CHALLENGE COMPLETE! Chat is going crazy. (+10 rep)")
		F.viralMoment(plr, "funnyEvent", {title = "Beat The Live Challenge", post = "📸 " .. plr.Name .. " just beat " .. c.by .. "'s live challenge. Chat: \"W\"."})
	elseif os.clock() >= c.ends then
		st.challenge = nil
		notify(plr, "📸 Challenge over: " .. done .. "/" .. c.goal .. ". Chat says \"L\" but they're nice about it.")
	end
end

-- =====================================================================
-- FUNNY RANDOM EVENTS
-- =====================================================================
local FUNNY = {}
FUNNY.inspector = function(plr, d)
	local key = bestBusiness(d)
	if not key then return false end
	-- the grade follows how clean the place is (Cleanliness improvement + the interior)
	local clean = (F.improveLevel and F.improveLevel(d, key, "cleanliness") or 0) * 15 + (F.interiorScore100 and F.interiorScore100(d, key) or 0) * 0.5 + math.random(0, 40)
	local grade = clean >= 70 and "A" or (clean >= 35 and "B" or "C")
	local rep = ({A = 4, B = 1, C = -1})[grade]
	F.addRep(plr, rep)
	local lines = {{"inspector", "Don't mind me.", "clipboard"}, {"inspector", "...", "look"}, {"inspector", "Actually, I mind you.", "point"},
		{"inspector", "Grade: " .. grade .. ". " .. (grade == "A" and "Spotless. Suspiciously spotless." or (grade == "B" and "Fine. FINE." or "Clean. Your. Stuff.")), grade == "C" and "crossed" or "show"}}
	F.cinematic(plr, "inspection", {biz = BIZ[key].name}, {lines = lines, at = F.bizAnchor(d, key), title = "🕵️ SURPRISE INSPECTION",
		result = {"🕵️ INSPECTION: GRADE " .. grade, (rep >= 0 and "+" or "") .. rep .. " reputation" .. (grade == "C" and " • Tip: improve Cleanliness" or "")}, react = grade == "C" and "facepalm" or "ownerPose"})
	if grade == "C" then F.viralMoment(plr, "funnyEvent", {title = "Grade C", post = "The health inspector told " .. plr.Name .. "'s " .. BIZ[key].name .. " to \"clean your stuff\". 🧽"}) end
	return true
end
FUNNY.customerArmy = function(plr, d)
	local key = bestBusiness(d)
	if not key then return false end
	F.cinematic(plr, "customerArmy", {biz = BIZ[key].name}, {at = F.bizAnchor(d, key), title = "🏃 CUSTOMER ARMY", result = {"🏃 CUSTOMER ARMY", "10 customers at once!"}, react = "shocked"})
	task.spawn(function()
		local t = C.NPC_TYPES[1]
		for _ = 1, 10 do
			task.wait(0.5)
			if data[plr] ~= d or (d.levels[key] or 0) <= 0 then return end
			F.serveCustomer(plr, d, key, t, nil)
		end
	end)
	F.viralMoment(plr, "funnyEvent", {title = "Customer Army", post = "Ten customers just stormed " .. plr.Name .. "'s " .. BIZ[key].name .. " at once. The manager said \"we're cooked\"."})
	return true
end
FUNNY.deliveryDisaster = function(plr, d)
	local food = {}
	for _, k in ipairs({"pizza", "bakery", "coffee", "icecream"}) do if (d.levels[k] or 0) > 0 then table.insert(food, k) end end
	if #food == 0 then return false end
	local key = food[math.random(#food)]
	local thing = BIZ[key].thing
	local lines = {{"courier", "Small problem.", "phone"}, {"you", "What?", "think"}, {"courier", "The " .. thing .. " is currently in a fountain.", "shrug"}, {"you", "...Is the fountain at least happy?", "facepalm"}}
	F.cinematic(plr, "deliveryDisaster", {biz = BIZ[key].name}, {lines = lines, at = F.bizAnchor(d, key), title = "🛵 DELIVERY DISASTER", result = {"🛵 DELIVERY DISASTER", "The " .. thing .. " went for a swim"}, react = "facepalm"})
	if F.pushMsg then F.pushMsg(plr, {icon = "🛵", from = "Delivery Driver", cat = "staff", text = "Small problem. The " .. thing .. " is currently in a fountain. The ducks seem happy though."}) end
	F.viralMoment(plr, "funnyEvent", {title = "Delivery Disaster", post = "Local " .. thing .. " spotted swimming in the fountain. Delivered by " .. plr.Name .. "'s " .. BIZ[key].name .. ". 🦆"})
	return true
end
FUNNY.richKid = function(plr, d)
	local key = bestBusiness(d)
	if not key then return false end
	-- a small tip: 20 seconds of income (a treat, not a payday)
	local tip = math.max(25, math.floor(F.incomePerSec(d) * 20))
	d.cash += tip
	F.earn(d, tip)
	F.cinematic(plr, "richKid", {biz = BIZ[key].name}, {at = F.bizAnchor(d, key), title = "👑 A RICH KID WALKS IN", result = {"👑 RICH KID", "Paid in normal money. Tipped $" .. fmt(tip) .. "."}, react = "laughing"})
	return true
end
FUNNY.badInvestor = function(plr, d)
	local key = bestBusiness(d)
	if not key then return false end
	F.cinematic(plr, "badInvestor", {}, {at = F.bizAnchor(d, key), title = "💼 A REVOLUTIONARY IDEA", result = {"💼 BAD INVESTOR", "\"Lemonade. But expensive.\""}, react = "facepalm"})
	if F.pushMsg then F.pushMsg(plr, {icon = "💼", from = "An Investor", cat = "investor", text = "Following up on my revolutionary idea: lemonade, but expensive. Call me. Please. Nobody calls me."}) end
	return true
end
C.FUNNY_EVENTS = FUNNY
local FUNNY_KEYS = {"inspector", "customerArmy", "deliveryDisaster", "richKid", "badInvestor"}
function F.funnyEvent(plr, which)
	local d = data[plr]
	if not d then return false end
	local fn = FUNNY[which]
	if not fn then return false end
	local ok, res = pcall(fn, plr, d)
	if not ok then warn("[CornerEmpire] funny event " .. which .. ": " .. tostring(res)) return false end
	return res
end

-- =====================================================================
-- THE LOOP (every 3 seconds; cheap checks only)
-- =====================================================================
local nextFunny = {}
C.funnySchedule = nextFunny   -- (tests push it back so a random event can't land in the middle of a check)
local nextBest = {}
task.spawn(function()
	while true do
		task.wait(3)
		local now = os.clock()
		for plr, d in pairs(data) do
			local ok, err = pcall(function()
				local st = state(plr)
				beefTick(plr, d, st)
				challengeTick(plr, d, st)
				if F.viralTick then F.viralTick(plr, d) end
				if (nextBest[plr] or 0) <= now then
					nextBest[plr] = now + 120
					if F.publishViralBests then F.publishViralBests(plr, d) end
				end
				if (d.tut or 0) > 0 then return end
				nextFunny[plr] = nextFunny[plr] or now + math.random(E.funnyEvery[1], E.funnyEvery[2])
				if now >= nextFunny[plr] then
					nextFunny[plr] = now + math.random(E.funnyEvery[1], E.funnyEvery[2])
					local list = table.clone(FUNNY_KEYS)
					for _ = 1, #list do
						local i = math.random(#list)
						local k = table.remove(list, i)
						if F.funnyEvent(plr, k) then break end
					end
					-- very rarely, a rival opens a pop-up next door instead
					if math.random() < 0.12 then F.businessBeef(plr) end
				end
			end)
			if not ok then warn("[CornerEmpire] city events: " .. tostring(err)) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	local st = busy[plr]
	if st and st.beef then st.beef.model:Destroy() end
	busy[plr] = nil
	nextFunny[plr] = nil
	nextBest[plr] = nil
end)

-- ===== Studio tools =====
C.DEBUG = C.DEBUG or {}
C.DEBUG.funny = function(plr, d, which)
	local k = FUNNY[which] and which or FUNNY_KEYS[math.random(#FUNNY_KEYS)]
	if not F.funnyEvent(plr, k) then notify(plr, "🧪 That event needs a business first.") end
end
C.DEBUG.rush = function(plr, d)
	local key = bestBusiness(d)
	if not key then return end
	busy[plr] = busy[plr] or {}
	busy[plr].crowd = nil
	F.theCrowd(plr, key, "Studio test")
end
C.DEBUG.rareEvent = function(plr, d, which)
	local st = state(plr)
	st.paparazzi, st.famous = nil, nil
	if which == "paparazzi" then F.paparazzi(plr)
	elseif which == "famous" then F.everyoneKnows(plr, 0)
	elseif which == "beef" then F.businessBeef(plr)
	else F.paparazzi(plr) end
end
end
