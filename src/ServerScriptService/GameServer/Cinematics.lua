-- CINEMATICS (server): decides WHEN an interaction cinematic plays and WHAT everyone says. The client's
-- CinematicController (EmpireClient > Cinematics) plays it: camera, actors, props, skip button.
--
-- Cinematics are pure presentation. Every state change (an eviction, a hire, a purchase, a reward) has already
-- happened on the server before the scene is sent, so skipping a scene, leaving during it, disconnecting or a
-- missing animation can never change or corrupt anything. Only the player involved gets the scene.
--
-- All dialogue lives here so it's easy to edit. Lines are {who, text, move}; `who` is a cast key (see CAST),
-- `move` is an actor move from EmpireClient > Actors (unknown moves fall back safely).
return function(C)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local F, data, R = C.F, C.data, C.R
local CF, V3 = CFrame.new, Vector3.new
local BIZ = C.BIZ
local GAME_DAY = 24 / (C.CFG.DAY_SPEED * 4)   -- seconds in one in-game day (ClockTime moves DAY_SPEED every 0.25 s)
C.GAME_DAY = GAME_DAY

local function pick(t) return t[math.random(#t)] end
local function first(name) return string.match(tostring(name or "Someone"), "^(%S+)") or "Someone" end

-- who's who on screen (names can be overridden per scene with ctx.names)
C.CAST = {
	you = {name = "You", icon = "😎"},
	tenant = {name = "Tenant", icon = "🧑", look = "tenant"},
	staff = {name = "Employee", icon = "🧑‍🍳", look = "staff"},
	manager = {name = "Manager", icon = "📋", look = "investor"},
	cashier = {name = "Cashier", icon = "🧾", look = "staff"},
	customer = {name = "Customer", icon = "🙂", look = "customer"},
	crowd1 = {name = "Someone in the crowd", icon = "🙋", look = "fan"},
	crowd2 = {name = "Someone else", icon = "🤷", look = "customer"},
	inspector = {name = "Health Inspector", icon = "🕵️", look = "inspector"},
	realtor = {name = "Realtor", icon = "🔑", look = "investor"},
	investor = {name = "Investor", icon = "💼", look = "investor"},
	richkid = {name = "Rich Kid", icon = "👑", look = "richkid"},
	courier = {name = "Delivery Driver", icon = "🛵", look = "courier"},
	rival = {name = "Lil Clipz", icon = "🎙️", look = "rival"},
	baysnaps = {name = "Bay Snaps", icon = "📸", look = "baysnaps"},
	jaxcash = {name = "Jax Cash", icon = "💼", look = "jaxcash"},
	mayamax = {name = "Maya Max", icon = "✨", look = "mayamax"},
	drewdeals = {name = "Drew Deals", icon = "🤝", look = "drewdeals"},
}

-- ===== grand openings: a crowd joke per business, and the signature moment's name =====
C.OPENING_CROWD = {
	lemonade = {{"crowd1", "Is it fresh-squeezed?", "point"}, {"crowd2", "It's squeezed. Let's not ask by who.", "shrug"}, {"crowd1", "I'll take TWO.", "hype"}},
	icecream = {{"crowd1", "Is that... a FREEZER?!", "shock"}, {"crowd2", "It's literally an ice cream shop.", "crossed"}, {"crowd1", "AND IT HAS A FREEZER.", "hype"}},
	bakery = {{"crowd1", "Do you smell that?", "look"}, {"crowd2", "Is that... croissants?", "shock"}, {"crowd1", "I'm not leaving. I live here now.", "kneel"}},
	coffee = {{"crowd1", "Is that an espresso machine or a spaceship?", "point"}, {"crowd2", "Yes.", "shrug"}, {"crowd1", "Take my money and my sleep schedule.", "hype"}},
	pizza = {{"crowd1", "IS THAT FREE PIZZA?", "shock"}, {"crowd2", "I don't think it's free.", "crossed"}, {"crowd1", "IT IS NOW.", "hype"}},
	arcade = {{"crowd1", "The lights. THE LIGHTS.", "shock"}, {"crowd2", "My mom said we're leaving at six.", "shrug"}, {"crowd1", "It's 5:59. RUN.", "hype"}},
	tech = {{"crowd1", "Do they have the new phone?", "point"}, {"crowd2", "Which one?", "shrug"}, {"crowd1", "The one that's newer than mine.", "hype"}},
	factory = {{"crowd1", "What do they even make here?", "think"}, {"crowd2", "Stuff. Big stuff.", "crossed"}, {"crowd1", "I NEED BIG STUFF.", "hype"}},
}
C.OPENING_SIGNATURE = {
	lemonade = "flips the OPEN sign", icecream = "opens the freezer", bakery = "opens the oven", coffee = "fires up the espresso machine",
	pizza = "spins the first pizza", arcade = "turns the lights on", tech = "powers up the screens", factory = "starts the machines",
}

-- ===== eviction: cartoon slapstick, never violence =====
local EVICT_ITEMS = {"a rubber duck", "a lava lamp", "a trophy that says WORLD'S OKAYEST TENANT", "a goldfish bowl (the fish is fine)", "a single sock",
	"a keyboard with no Q key", "a giant teddy bear", "a cactus named Gerald"}
local EVICT_BANTER = {
	function(c) return {{"tenant", "WAIT! I JUST GOT HERE!", "flail"}, {"you", "You've been here for " .. c.days .. " game day" .. (c.days == 1 and "" or "s") .. ".", "point"}, {"tenant", "...Fair.", "shrug"}} end,
	function(c) return {{"tenant", "Is this about the drum practice?", "shock"}, {"you", "It's about ALL the drum practice.", "crossed"}, {"tenant", "...It was a good solo though.", "shrug"}} end,
	function(c) return {{"tenant", "Can I at least take the lamp?", "dramatic"}, {"you", "It's MY lamp.", "point"}, {"tenant", "...It was a nice lamp.", "shrug"}} end,
	function(c) return {{"tenant", "But I was gonna pay rent... eventually!", "flail"}, {"you", "Eventually was " .. c.days .. " game day" .. (c.days == 1 and "" or "s") .. " ago.", "crossed"}, {"tenant", "Time flies, huh.", "shrug"}} end,
}

-- ===== other interactions =====
local LINES = {
	hire = function(c) return pick({
		{{"staff", "I won't let you down, boss!", "wave"}, {"you", "Welcome to the team, " .. first(c.name) .. "!", "owner"}},
		{{"staff", "Do I get a name tag? I've always wanted a name tag.", "hype"}, {"you", "You get a name tag.", "owner"}, {"staff", "BEST DAY EVER.", "celebrate"}},
	}) end,
	fire = function(c) return pick({
		{{"staff", "Was it the thing with the register?", "shock"}, {"you", "It was ALL the things.", "crossed"}, {"staff", "...Can I keep the hat?", "shrug"}},
		{{"staff", "I'll be back. As a CUSTOMER.", "point"}, {"you", "We'll give you the employee discount.", "shrug"}},
	}) end,
	buyProperty = function(c) return {{"realtor", "Congratulations! The keys are yours. Please don't lose them.", "talk"}, {"you", "When have I EVER lost keys?", "owner"}, {"realtor", "...I've heard stories.", "shrug"}} end,
	upgrade = function(c) return pick({
		{{"staff", "Boss, it's... beautiful.", "shock"}, {"you", "I know.", "owner"}},
		{{"staff", "New " .. c.biz .. "! I'm telling everyone!", "hype"}},
	}) end,
	complaint = function(c) return {{"customer", c.text or "I WAITED 14 MINUTES FOR A LEMONADE. I HAVE AGED.", "dramatic"}, {"you", "...Would a free napkin help?", "facepalm"}} end,
	inspection = function(c) return {{"inspector", "Don't mind me.", "clipboard"}, {"inspector", "...", "look"}, {"inspector", "Actually, I mind you.", "point"}, {"you", "Is that... bad?", "facepalm"}} end,
	competition = function(c) return {{"crowd1", "THAT'S THE CHAMPION!", "hype"}, {"you", "Thank you, thank you. No autographs. Okay, ONE autograph.", "owner"}} end,
	investment = function(c) return {{"investor", "I've seen your numbers. I'm IN.", "talk"}, {"you", "How in?", "think"}, {"investor", "$" .. C.fmt(c.amount or 0) .. " in.", "show"}, {"you", "...I'm gonna need a bigger wallet.", "money"}} end,
	luxury = function(c) return {{"crowd1", "IS THAT THE BILLIONAIRE?", "shock"}, {"crowd2", "Bro owns half the city.", "point"}, {"you", "Only half? I need to work harder.", "owner"}} end,
	customerArmy = function(c) return {{"manager", "Boss... look outside.", "shock"}, {"manager", "Ten customers. At once. We're cooked.", "facepalm"}, {"you", "We're not cooked. We're COOKING.", "hype"}} end,
	deliveryDisaster = function(c) return {{"courier", "Small problem.", "phone"}, {"you", "What?", "think"}, {"courier", "The pizza is currently in a fountain.", "shrug"}, {"you", "...Is the fountain at least happy?", "facepalm"}} end,
	richKid = function(c) return {{"richkid", "Do you accept a gold card?", "show"}, {"cashier", "We accept normal money.", "crossed"}, {"richkid", "...Embarrassing.", "facepalm"}} end,
	badInvestor = function(c) return {{"investor", "I have a revolutionary business idea.", "talk"}, {"you", "What?", "think"}, {"investor", "Lemonade. But expensive.", "show"}, {"you", "...That's just my business.", "facepalm"}} end,
}

-- ===== where a scene happens: a CFrame at the front door, its -Z pointing INTO the building =====
local function facingOut(doorPos, insidePos)
	local out = doorPos + (doorPos - insidePos)
	return CFrame.lookAt(doorPos, V3(out.X, doorPos.Y, out.Z)) * CFrame.Angles(0, math.pi, 0)
end
function F.bizAnchor(d, key)
	local slot = F.slotCF(d.plot, key)
	local door = (slot * CF(0, 0, 9)).Position
	return facingOut(V3(door.X, slot.Position.Y, door.Z), slot.Position)
end
function F.rentalAnchor(lot)
	local o = CF(lot.pos) * CFrame.Angles(0, lot.yaw, 0)
	return o * CF(0, 0.4, 3.6)
end
function F.homeAnchor(lot)
	return CF(lot.pos) * CFrame.Angles(0, lot.yaw, 0) * CF(0, 0.2, lot.size / 2 - 9)
end
function F.playerAnchor(plr)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.CFrame * CF(0, -3, 0)) or nil
end

-- ===== sending a scene =====
local seq = 0
local lastOf = {}       -- [plr] = {kind -> os.clock()}  (minor scenes don't repeat back to back)
C.lastCinematic = {}    -- [plr] = the last payload sent (tests and Studio tools read this)
local MINOR_GAP = {hire = 20, fire = 20, upgrade = 45, complaint = 90, inspection = 60, buyProperty = 20}
local FULL = {evict = true, opening = true, competition = true, investment = true, luxury = true, influencer = true, clipz = true}
function F.cinematic(plr, kind, ctx, opts)
	local d = data[plr]
	if not d or not plr.Parent then return nil end
	opts = opts or {}
	-- no surprise scenes while the tutorial is teaching you the basics
	if d.tut and d.tut > 0 and not opts.duringTutorial then return nil end
	local now = os.clock()
	lastOf[plr] = lastOf[plr] or {}
	if MINOR_GAP[kind] and now - (lastOf[plr][kind] or -1e9) < MINOR_GAP[kind] and not opts.force then return nil end
	lastOf[plr][kind] = now
	ctx = ctx or {}
	local lines = opts.lines
	if not lines and kind == "evict" then
		lines = pick(EVICT_BANTER)(ctx)
	elseif not lines and kind == "opening" and ctx.crowd then
		lines = C.OPENING_CROWD[ctx.key] or C.OPENING_CROWD.pizza
	elseif not lines and LINES[kind] then
		lines = LINES[kind](ctx)
	end
	seq += 1
	local names = {}
	for who, nm in pairs(ctx.names or {}) do names[who] = nm end
	names.you = plr.DisplayName
	local payload = {
		id = seq, kind = kind, at = opts.at, mode = opts.mode or (FULL[kind] and "full" or "short"),
		title = opts.title, result = opts.result, lines = lines or {}, ctx = ctx, names = names, moment = opts.moment, react = opts.react,
	}
	C.lastCinematic[plr] = payload
	R.Cinematic:FireClient(plr, payload)
	return payload
end
Players.PlayerRemoving:Connect(function(plr)
	lastOf[plr] = nil
	C.lastCinematic[plr] = nil
end)

-- ===== the specific scenes the rest of the server asks for =====
function F.cineEvict(plr, d, b, ui, tenant)
	local lot = C.RENT_LOTS[b.lot]
	if not lot then return end
	local days = math.max(1, math.floor((os.time() - (tonumber(tenant.since) or os.time())) / GAME_DAY))
	local unit = C.rentalUnitName and C.rentalUnitName(ui) or tostring(ui)
	return F.cinematic(plr, "evict", {tenant = tenant.name, days = days, unit = unit, item = pick(EVICT_ITEMS), emoji = tenant.emoji,
		names = {tenant = tenant.name}}, {at = F.rentalAnchor(lot), title = "🚪 EVICTION NOTICE",
		result = {"EVICTION COMPLETE", "Unit " .. unit .. " is now available."}, react = "ownerPose"})
end
function F.cineOpening(plr, d, key, crowd, moment)
	local b = BIZ[key]
	return F.cinematic(plr, "opening", {key = key, biz = b.tiers[1], icon = b.icon, crowd = crowd, signature = C.OPENING_SIGNATURE[key]},
		{at = F.bizAnchor(d, key), title = b.icon .. " GRAND OPENING", result = {"🎉 GRAND OPENING!", b.tiers[1] .. " is open for business"},
		react = "celebrate", mode = crowd and "full" or "short", moment = moment})
end
function F.cineStaff(plr, d, slot, name, hired)
	local at = BIZ[slot] and F.bizAnchor(d, slot) or F.playerAnchor(plr)
	if not at then return end
	return F.cinematic(plr, hired and "hire" or "fire", {name = name, slot = slot, names = {staff = name}},
		{at = at, title = hired and "👋 NEW HIRE" or "📦 CLEARING OUT THE DESK",
		result = hired and {"👋 HIRED", name .. " joined the team"} or {"📦 " .. string.upper(first(name)) .. " LEFT", "The desk is free"}, react = hired and "wave" or "armsCrossed"})
end

-- ===== Studio-only test buttons (Settings → 🧪) =====
C.DEBUG = C.DEBUG or {}
C.DEBUG.cineEvict = function(plr, d)
	-- evicts nobody: plays the scene with a pretend tenant at your first property (or the first rental lot)
	local b = d.props[1] or {lot = 1}
	F.cinematic(plr, "evict", {tenant = "Testy McTestface", days = 47, unit = "1A", item = pick(EVICT_ITEMS), names = {tenant = "Testy McTestface"}},
		{at = F.rentalAnchor(C.RENT_LOTS[b.lot] or C.RENT_LOTS[1]), title = "🚪 EVICTION NOTICE (TEST)", result = {"EVICTION COMPLETE", "(Studio test: nobody was evicted)"}, react = "ownerPose", force = true, duringTutorial = true})
end
C.DEBUG.cineOpening = function(plr, d, which)
	local key = BIZ[which] and which or nil
	if not key then
		for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then key = b.key end end
	end
	key = key or "lemonade"
	local b = BIZ[key]
	F.cinematic(plr, "opening", {key = key, biz = b.tiers[1], icon = b.icon, crowd = true, signature = C.OPENING_SIGNATURE[key]},
		{at = F.bizAnchor(d, key), title = b.icon .. " GRAND OPENING (TEST)", result = {"🎉 GRAND OPENING!", b.tiers[1] .. " is open for business"}, react = "celebrate", mode = "full", force = true, duringTutorial = true})
end
C.DEBUG.cineCamera = function(plr, d)
	local at = F.playerAnchor(plr)
	if at then F.cinematic(plr, "luxury", {}, {at = at, title = "🎥 CINEMATIC CAMERA TEST", result = {"🎥 CAMERA TEST", "Camera, letterbox, skip and photo buttons"}, force = true, duringTutorial = true}) end
end
C.DEBUG.inspection = function(plr, d)
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 then
			F.cinematic(plr, "inspection", {biz = b.name}, {at = F.bizAnchor(d, b.key), title = "🕵️ SURPRISE INSPECTION", result = {"🕵️ INSPECTION", "(Studio test)"}, force = true, duringTutorial = true})
			return
		end
	end
end
C.DEBUG.interior = function(plr, d)
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 and F.enterInterior then F.enterInterior(plr, plr, b.key) return end
	end
end
end
