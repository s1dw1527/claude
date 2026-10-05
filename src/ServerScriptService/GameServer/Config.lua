-- CONFIG: every number, name and piece of content in the game lives here.
return function(C)
local RGB = Color3.fromRGB

-- ===== VERSION (bump these with every published update; see README "How to update Corner Empire") =====
C.VERSION = {
	VERSION = "10.0.0",
	UPDATE_NAME = "Ownership, HQ, Cars & Lifestyle",
	SCHEMA_VERSION = 10,         -- the shape of a player's save. Raise it only together with a new step in DataMigration.
	MIN_SUPPORTED_SCHEMA = 6,   -- saves older than v6 (no version field, no tutorial-reward tracking) are treated as v6
	-- shown once to every returning player after an update (Messages app)
	NOTES = {
		"🏙️ A real city real-estate market: 8 districts, ~100 plots, ownership limits that grow with you",
		"🏷️ Name your businesses, customize your brand, and create your own products",
		"🏢 Build an HQ with floors, an Empire Wall, and a General Manager on contract",
		"💻 Computers for your home and HQ, with apps for your whole empire",
		"🏡 Seven house tiers, furniture shop and grid furniture placement",
		"🚗 15 new original cars with real stats, classes and customization",
		"🕹️ Fun Zone + two-player arcade games (in friends' arcades too)",
		"🎓 A new guide that explains every new system as you reach it",
	},
}

C.CFG = {
	MAX_PLAYERS = 4,
	SAVE_SLOTS = 3,
	MAX_LEVEL = 10,
	EVENT_INTERVAL = 60,
	WAR_INTERVAL = 600,          -- Corner War every 10 min (1200 = 20 min)
	WAR_BUFF_TIME = 300,
	SABOTAGE_TIME = 10, SABOTAGE_COOLDOWN = 45,
	DAY_SPEED = 0.01,
	SAVE_ENABLED = true,
	DATASTORE = "CornerEmpire_v5",   -- keep this name FOREVER: it's where everyone's existing saves live
	-- Studio playtests use separate copies of every DataStore ("..._StudioTest"), so testing can never touch live
	-- player data. Set this to true only if you really mean to read/write the live saves from Studio.
	STUDIO_USES_LIVE_DATA = false,
	RICH_START_BONUS = 5000,
	RENT_INTERVAL = 30,
	STOCK_SELL_FEE = 0.10,       -- 10% fee on every share sale, so buy/sell loops can't create money
	MAX_SHARES_PER_ORDER = 100000,
	ACTION_RATE = 12,            -- button presses per second each player may send (burst below)
	ACTION_BURST = 30,
	LOAD_RETRIES = 3,            -- DataStore read attempts before a save is treated as unavailable
	TUTORIAL_DEBUG = true,       -- Studio only: print why a tutorial step hasn't advanced yet (Output window)
}

-- the real DataStore name to use: the live name in published games, a separate test copy in Studio
function C.storeName(name)
	local ok, studio = pcall(function() return game:GetService("RunService"):IsStudio() end)
	if ok and studio and not C.CFG.STUDIO_USES_LIVE_DATA then return name .. "_StudioTest" end
	return name
end

-- ===== ECONOMY SETTINGS (v7) =====
-- Every balance knob in one place. Prices and incomes of individual businesses, homes, cars, land and
-- rentals live in their own tables below; this section holds the rules that connect them.
-- tests/economy_sim.lua plays the real game with these numbers and prints how long each milestone takes.
C.ECONOMY = {
	startCash = 100,            -- a new save starts with this much
	tutorialReward = 250,       -- each tutorial step pays this x the step number, once per save ($7,000 in total)
	baseIncome = 1,             -- the empty corner earns $1/s, so nobody is ever completely stuck
	-- businesses
	upgradeGrowth = 1.6,        -- every level costs 60% more than the one before (income grows linearly)
	crashDiscount = 0.7,        -- upgrades cost 30% less during a Market Crash
	chainIncome = 10,           -- each extra location adds this many levels' worth of income
	chainCost = {3, 8, 20},     -- location 2/3/4 cost = the business's Lv 10 upgrade price x this
	staffPerStar = 0.03,        -- a worker adds +3% to their business per star (was 4%)
	managerPerStar = 0.015,     -- a manager adds +1.5% to everything per star (was 2%)
	-- customers (each one pays a few seconds of that business's income)
	customerSale = 1.5,         -- seconds of income per customer (was 4)
	customerBase = 0.12, customerPerLevel = 0.03, maxCustomers = 2.5,   -- customers per second
	reviewRep = 0.25,           -- reputation from a good review (x1 for 4 stars, x2 for 5). The tier thresholds are
	                            -- unchanged so existing saves keep their tier; reputation is just earned more slowly
	-- empire-wide multipliers
	repTierBonus = 0.04,        -- +4% income per reputation tier above the first (was 5%)
	eraBonus = 0.1,             -- +10% income per City Era (was 20%)
	vipBonus = 0.25,            -- VIP adds +25% on top of the money pass (added, not multiplied)
	districtBoostOnce = true,   -- a district's boost counts once, however many of its lots you own (was per lot)
	-- costs that keep a running empire honest
	repairSeconds = 30, repairFloor = 25,      -- fixing a problem costs 30s of that business's income (min $25)
	sabotageCost = 1000, sabotageSeconds = 20, -- freezing a rival costs $1,000 or 20s of your income, whichever is more
	adSeconds = {60, 120, 240},                -- ads cost their listed price or this many seconds of income, whichever is more
	-- rewards outside the businesses (all scale with your income, so they stay meaningful but never skip ahead)
	deliverySeconds = 40, deliveryFloor = 60,  -- a delivery pays ~40s of income (more for far drops)
	minigameCapSeconds = 150, minigameCapFloor = 300,  -- Fun Park profit per 10 minutes (was 900s of income, min $2,000)
	funFeeFloor = 20,                          -- smallest Fun Park entry fee (was $100)
	eventFloorScale = 0.15,                    -- mega event rewards: the minimum payout is 15% of the old flat amounts
	investorSeconds = 90, investorFloor = 150, -- Angel Investor gift to the smallest empire (was 120s, min $2,500)
	warSeconds = 60, warMinPlayers = 2,        -- Corner War prizes: 60s of income per win, only with 2+ empires playing
	richStartWarSeconds = 30, richStartWarMax = 5000, -- Rich Start's war bonus: 30s of income, up to $5,000 (was a flat $5,000)
	secretSeconds = 180,                       -- hidden spots pay 180s of income (min = a tenth of their old flat amount)
	stockPositionSeconds = 1200,               -- you can hold at most 20 minutes of YOUR income in any one company's shares
	-- the Empire Spire (City Eras)
	spireStages = {25000, 150000, 750000, 3000000, 10000000},
	eraGoalBase = 60000000, eraGoalGrowth = 4, -- every era after that: $60M, $240M, $960M...
	-- rebirth
	rebirthBase = 250000000, rebirthStep = 0.5,   -- rebirth needs $250M cash (+50% per rebirth)
	rebirthTycoonCash = 250000,                    -- the 10-rebirth Tycoon perk's starting cash (was $25K)
}
local E = C.ECONOMY

-- older names for some economy values (kept so every script reads the same number)
C.CFG.START_CASH, C.CFG.BASE_INCOME, C.CFG.CRASH_DISCOUNT = E.startCash, E.baseIncome, E.crashDiscount
C.CFG.MAX_CUSTOMERS_PER_SEC, C.CFG.SABOTAGE_COST = E.maxCustomers, E.sabotageCost

-- ===== REPUTATION TIERS + what each one unlocks =====
C.REP_TIERS = {
	{name = "UNKNOWN CORNER",     rep = 0,    unlocks = {"Lemonade Stand", "Ice Cream Cart", "Your home", "Phone & CityBuzz"}},
	{name = "LOCAL FAVORITE",     rep = 100,  unlocks = {"Bakery & Coffee Shop", "Staff", "Cars & Deliveries", "Fun Park", "Downtown & Midtown plots"}},
	{name = "HOTSPOT",            rep = 400,  unlocks = {"Pizza & Arcade", "Stock Market", "Ads", "Property Management", "Race Track", "Empire Tower", "Industrial & Entertainment plots", "Your HQ"}},
	{name = "CITY ICON",          rep = 1200, unlocks = {"Tech Startup", "Business chains", "Rebirth", "Waterfront plots", "Oceanfront homes"}},
	{name = "EMPIRE",             rep = 3500, unlocks = {"Factory", "Luxury Hills & Expansion plots", "Hillside homes"}},
	{name = "LEGENDARY DISTRICT", rep = 9000, unlocks = {"Millionaire Row", "Legend status"}},
}
C.FEATURES = {staff = 2, cars = 2, deliveries = 2, funpark = 2, sabotage = 2, market = 3, ads = 3, properties = 3, race = 3, tower = 3, chains = 4, rebirth = 4}
C.FEATURE_NAMES = {staff = "Staff", cars = "Cars", deliveries = "Deliveries", funpark = "Fun Park", sabotage = "Freeze", market = "Stock Market",
	ads = "Ads", properties = "Property Management", race = "Race Track", tower = "Empire Tower", chains = "Business chains", rebirth = "Rebirth"}

-- ===== BUSINESSES =====
C.BUSINESSES = {
	{key = "lemonade", name = "Lemonade",  cost = 40,     income = 1.5,    unlock = 1, icon = "🍋", color = RGB(255, 214, 60),  wall = RGB(255, 246, 214), roof = RGB(255, 190, 40),  thing = "lemonade",
		tiers = {"Lemonade Stand", "Lemonade Shop", "Lemonade Café", "Lemonade Factory", "Lemonade Corporation", "🍋 LEMON EMPIRE HQ"}},
	{key = "icecream", name = "Ice Cream", cost = 600,    income = 6,    unlock = 1, icon = "🍦", color = RGB(255, 150, 200), wall = RGB(255, 232, 242), roof = RGB(120, 220, 200), thing = "ice cream",
		tiers = {"Ice Cream Cart", "Ice Cream Parlor", "Gelato House", "Creamery", "Ice Cream Tower", "🍦 FROZEN EMPIRE HQ"}},
	{key = "bakery",   name = "Bakery",    cost = 7500,    income = 25,   unlock = 2, icon = "🥐", color = RGB(235, 150, 80),  wall = RGB(176, 92, 62),   roof = RGB(90, 60, 50),    thing = "croissants",
		tiers = {"Bread Stall", "Bakery", "Patisserie", "Grand Bakery", "Bakery Corporation", "🥐 CROISSANT CASTLE"}},
	{key = "coffee",   name = "Coffee",    cost = 150000,   income = 90,   unlock = 2, icon = "☕", color = RGB(150, 100, 70),  wall = RGB(60, 70, 64),    roof = RGB(40, 44, 42),    thing = "coffee",
		tiers = {"Coffee Cart", "Coffee Shop", "Coffee House", "Roastery", "Coffee Corporation", "☕ BEAN EMPIRE HQ"}},
	{key = "pizza",    name = "Pizza",     cost = 2000000,   income = 330,  unlock = 3, icon = "🍕", color = RGB(230, 70, 50),   wall = RGB(245, 230, 205), roof = RGB(40, 130, 70),   thing = "pizza",
		tiers = {"Pizza Window", "Pizza Place", "Pizzeria", "Pizza Palace", "Pizza Corporation", "🍕 PIZZA DOME"}},
	{key = "arcade",   name = "Arcade",    cost = 20000000,  income = 1100,  unlock = 3, icon = "🕹️", color = RGB(150, 80, 255),  wall = RGB(38, 28, 66),    roof = RGB(255, 60, 180),  thing = "games",
		tiers = {"Game Corner", "Arcade", "Mega Arcade", "Game Center", "eSports Arena", "🕹️ GAMING CITADEL"}},
	{key = "tech",     name = "Tech",      cost = 150000000,  income = 4200, unlock = 4, icon = "💻", color = RGB(70, 150, 255),  wall = RGB(225, 232, 244), roof = RGB(40, 42, 52),    thing = "app",
		tiers = {"Garage Startup", "Tech Startup", "Tech Company", "Tech Campus", "Tech Giant", "💻 SILICON SPIRE"}},
	{key = "factory",  name = "Factory",   cost = 600000000, income = 14000, unlock = 5, icon = "🏭", color = RGB(170, 175, 190), wall = RGB(150, 84, 64),   roof = RGB(90, 94, 102),   thing = "products",
		tiers = {"Workshop", "Factory", "Big Factory", "Industrial Plant", "Mega Factory", "🏭 INDUSTRIAL TITAN"}},
}
C.BIZ = {}
for i, b in ipairs(C.BUSINESSES) do
	b.index = i
	C.BIZ[b.key] = b
end
C.CHAINS = {{name = "Downtown", mult = E.chainCost[1]}, {name = "Airport", mult = E.chainCost[2]}, {name = "Luxury", mult = E.chainCost[3]}}   -- x the Lv 10 price

C.COMBOS = {
	{key = "cafebakery",  name = "Café Bakery",         icon = "☕🥐", needs = {"bakery", "coffee"},     lvl = 3, mult = 1.25, color = RGB(200, 140, 90)},
	{key = "frozenlemon", name = "Frozen Lemonade Bar", icon = "🍋🍦", needs = {"lemonade", "icecream"}, lvl = 3, mult = 1.25, color = RGB(255, 230, 120)},
	{key = "dessert",     name = "Dessert Parlor",      icon = "🍰",   needs = {"icecream", "bakery"},   lvl = 3, mult = 1.25, color = RGB(255, 170, 200)},
	{key = "pizzaarcade", name = "Pizza Arcade",        icon = "🕹️🍕", needs = {"pizza", "arcade"},      lvl = 3, mult = 1.25, color = RGB(230, 90, 160)},
	{key = "startupcafe", name = "Startup Café",        icon = "💻☕", needs = {"tech", "coffee"},       lvl = 3, mult = 1.25, color = RGB(90, 150, 220)},
	{key = "gamestudio",  name = "Game Studio",         icon = "🎮",   needs = {"arcade", "tech"},       lvl = 3, mult = 1.25, color = RGB(120, 90, 255)},
	{key = "indbakery",   name = "Industrial Bakery",   icon = "🥖",   needs = {"bakery", "factory"},    lvl = 5, mult = 1.5, color = RGB(180, 140, 100), secret = true},
	{key = "aicafe",      name = "AI Café",             icon = "☕🤖", needs = {"coffee", "tech"},       lvl = 5, mult = 1.5, color = RGB(80, 230, 255), secret = true, marketing = true, hint = "needs a Major ad campaign"},
	{key = "spacediner",  name = "Space Diner",         icon = "🚀🍕", needs = {"pizza", "tech", "factory"}, lvl = 5, mult = 1.75, color = RGB(255, 120, 60), secret = true, era = 2, hint = "unlocks in Era 2"},
	-- RARE SECRETS: their own buildings on your plot and an empire-wide perk. The UI only ever shows the riddle.
	{key = "moviestudio", name = "Movie Studio",       icon = "🎬", needs = {"arcade", "tech"}, levels = {arcade = 5, tech = 3}, viral = true, mult = 1.5, color = RGB(255, 80, 80),
		secret = true, rare = true, riddle = "'The cameras only come for a viral star...'", perk = {customers = 1.25}, perkText = "+25% customers"},
	{key = "robotfactory", name = "Robot Factory",     icon = "🤖", needs = {"factory", "tech"}, levels = {factory = 7, tech = 7}, era = 3, mult = 1.75, color = RGB(120, 200, 255),
		secret = true, rare = true, riddle = "'Machines dream of a much bigger city...'", perk = {problems = 0.6}, perkText = "40% fewer problems"},
	{key = "bank",        name = "Billionaire Bank",   icon = "🏦", needs = {}, earned = 1e8, rebirths = 10, mult = 1, color = RGB(255, 205, 60),
		secret = true, rare = true, riddle = "'Only the richest, reborn again and again...'", perk = {all = 1.1}, perkText = "+10% ALL income"},
	{key = "spacecenter", name = "Space Center",       icon = "🚀", needs = {"tech", "factory"}, levels = {tech = 10, factory = 5}, era = 4, found = "launchpad", mult = 2, color = RGB(200, 200, 255),
		secret = true, rare = true, riddle = "'Someone left a launch pad out past the far hills...'", perk = {all = 1.15}, perkText = "+15% ALL income"},
}

-- hidden places to find by exploring (walk close). Some unlock secrets, relics go in your Legacy Museum.
C.SECRET_SPOTS = {
	{key = "launchpad", name = "Abandoned Launch Pad", icon = "🚀", pos = Vector3.new(600, 0, -520), radius = 18, cash = 5000, rep = 10,
		text = "You found an abandoned launch pad... someone with a big enough tech empire could build something here."},
	{key = "goldenlemon", name = "Golden Lemon", icon = "🍋", pos = Vector3.new(0, 1.6, 476), radius = 7, cash = 2500, rep = 5, relic = true,
		text = "A GOLDEN LEMON at the very end of the pier! It's going in your museum."},
	{key = "diamondbean", name = "Diamond Coffee Bean", icon = "💎", pos = Vector3.new(180, 0.4, 191), radius = 6, cash = 2500, rep = 5, relic = true,
		text = "A diamond coffee bean was hiding behind the park fountain!"},
	{key = "blueprint", name = "Ancient Blueprint", icon = "📜", pos = Vector3.new(-300, 18.4, -160), radius = 7, cash = 4000, rep = 8, relic = true,
		text = "An ancient empire blueprint, tucked in a corner of Hillside. Priceless."},
}

-- ===== ACHIEVEMENTS (shareable on CityBuzz, shown in the Legacy Museum) =====
C.ACHIEVEMENTS = {
	firstBusiness = {icon = "🏪", title = "Open for Business", post = "I just opened my very first business! 🍋"},
	firstLandmark = {icon = "🌟", title = "First Landmark", post = "I built my first golden LANDMARK! 🌟"},
	million = {icon = "💰", title = "First Million", post = "My empire has earned its first $1,000,000! 💰"},
	billion = {icon = "💎", title = "First Billion", post = "ONE. BILLION. DOLLARS. 💎💎💎"},
	raceWin = {icon = "🏁", title = "Race Champion", post = "I beat par at the Corner Empire Raceway! 🏁"},
	trackRecord = {icon = "🏆", title = "Track Record", post = "I just set a new TRACK RECORD! 🏆🏎️"},
	rebirth1 = {icon = "♻️", title = "Reborn", post = "Rebirth #1 done. Starting over, but stronger! ♻️"},
	rebirth10 = {icon = "💼", title = "10 Rebirths", post = "10 rebirths! Tycoon status unlocked 💼"},
	rebirth50 = {icon = "🎩", title = "50 Rebirths", post = "50 rebirths. I am the Mogul now 🎩"},
	rebirth100 = {icon = "👑", title = "100 Rebirths", post = "100 REBIRTHS. LEGEND STATUS. 👑"},
	mansion = {icon = "🏰", title = "Millionaire Mansion", post = "Just built my mansion on Millionaire Row 🏰"},
	dreamHome = {icon = "🏡", title = "Dream Home", post = "My Dream Home is finally complete! 🏡✨"},
	viral = {icon = "🔥", title = "Went Viral", post = "An influencer made my business go VIRAL! 🔥📱"},
	iconicBuilding = {icon = "🏢", title = "Iconic Building", post = "My apartment building just hit ICONIC status 🏢🌟"},
	era2 = {icon = "🏙️", title = "Growing City", post = "I helped build the Empire Spire into Era 2! 🏙️"},
	era3 = {icon = "🌆", title = "Mega City", post = "Era 3: MEGA CITY. I helped build it 🌆"},
	era4 = {icon = "🛸", title = "Future City", post = "Flying cars! I helped bring the city into the future 🛸"},
	era5 = {icon = "🌃", title = "Cyber City", post = "CYBER CITY unlocked. Neon everywhere 🌃"},
	secret = {icon = "🤫", title = "Secret Discovery", post = "I discovered a SECRET business 🤫"},
	rare = {icon = "🗝️", title = "Rare Secret", post = "I unlocked a RARE secret business. Good luck finding it 🗝️"},
	relic = {icon = "🏺", title = "Relic Hunter", post = "Found a hidden relic somewhere in the city... not telling where 🏺"},
	mystery = {icon = "❓", title = "Mystery Lot", post = "I bought a Mystery Lot. You won't BELIEVE what was inside ❓"},
	houseStar = {icon = "⭐", title = "Home of the Week", post = "My house won Home of the Week! ⭐🏠"},
	showcaseStar = {icon = "🏆", title = "Empire of the Week", post = "My empire won the Weekly Empire Showcase! 🏆"},
	weeklyChamp = {icon = "🥇", title = "Weekly Champion", post = "I topped a weekly leaderboard! 🥇"},
	legendary = {icon = "🌠", title = "Legendary Find", post = "I found something LEGENDARY in a Mystery Lot 🌠"},
	storyLegend = {icon = "🎙️", title = "Golden Mic", post = "I finished the Corner Empire story. Lil Clipz owes me an apology 🎙️✨"},
	-- v9
	kickRocks = {icon = "🚪", title = "Kick Rocks", post = "First eviction: complete. The rubber duck went flying. 🦆🚪"},
	landlordMode = {icon = "🏢", title = "Landlord Mode", post = "10 evictions. I am the landlord now. 🏢"},
	whoInvited = {icon = "👥", title = "WHO INVITED EVERYONE?", post = "25 customers at ONE of my businesses in 30 seconds. WHO INVITED EVERYONE? 👥"},
	mainCharacter = {icon = "🎬", title = "Main Character", post = "I just triggered a rare viral event. Main character energy. 🎬"},
	internetFamous = {icon = "📱", title = "Internet Famous", post = "An influencer just posted about my business. I'm internet famous now 📱"},
	actuallyFamous = {icon = "🌟", title = "Actually Famous", post = "I'm on the weekly Most Viral leaderboard! 🌟"},
	broGotContent = {icon = "📸", title = "Bro Got Content", post = "Captured a viral moment in Photo Mode. Content secured. 📸"},
	empireInfluencer = {icon = "👑", title = "Empire Influencer", post = "10,000 Viral Score. I AM the content now. 👑🔥"},
}
for _, b in ipairs(C.BUSINESSES) do
	C.ACHIEVEMENTS["biz_" .. b.key] = {icon = b.icon, title = "New: " .. b.name, post = "Just opened a brand new " .. b.tiers[1] .. "! " .. b.icon, quiet = b.key == "lemonade"}
end

-- ===== BUSINESS LAND (districts) =====
-- v10: the city real-estate market. Every district has a fixed number of plots (GameServer > RealEstate places them)
-- and a per-player limit (cap), so in a 4-player server nobody can buy up a whole district. Prime districts are
-- small and pricey on purpose. kind = what can be built there; stars = location potential (1-5);
-- loc = income bonus for a business located there (locFor = bigger bonus for the business types that fit it).
-- (The first four keys are the v5-v9 land districts: their keys stay the same so existing saves keep their land.)
C.DISTRICTS = {
	{key = "downtown",   name = "Downtown",        icon = "🏙️", tier = 2, cost = 400000,   income = 150,   color = RGB(80, 140, 235), boost = {coffee = 1.15, tech = 1.15}, boostText = "Coffee & Tech +15%",
		kind = "Premium commercial", stars = 5, cap = 2, loc = 0.25, locFor = {coffee = 0.35, tech = 0.35}, blurb = "Prime visibility. Few plots. Big prestige."},
	{key = "industrial", name = "Industrial Zone", icon = "🏭", tier = 3, cost = 2500000,  income = 1000,   color = RGB(235, 165, 50), boost = {factory = 1.25, bakery = 1.1}, boostText = "Factory +25%, Bakery +10%",
		kind = "Large industrial", stars = 4, cap = 2, loc = 0.15, locFor = {factory = 0.3, bakery = 0.25}, blurb = "Big plots for factories and warehouses."},
	{key = "beach",      name = "Waterfront",      icon = "🌊", tier = 4, cost = 40000000,  income = 10000,  color = RGB(80, 210, 220), boost = {lemonade = 1.5, icecream = 1.5}, boostText = "Lemonade & Ice Cream +50%",
		kind = "Premium waterfront", stars = 5, cap = 1, loc = 0.2, locFor = {lemonade = 0.4, icecream = 0.4}, blurb = "Luxury beachfront. Very few plots."},
	{key = "luxury",     name = "Luxury Hills",    icon = "💎", tier = 5, cost = 600000000, income = 100000, color = RGB(190, 110, 255), boost = {all = 1.1}, boostText = "ALL income +10%",
		kind = "Premium luxury", stars = 5, cap = 1, loc = 0.25, blurb = "The most exclusive address in the city."},
	{key = "suburbs",    name = "Northside Suburbs", icon = "🏘️", tier = 1, cost = 20000,   income = 15,     color = RGB(120, 190, 120), boost = {lemonade = 1.1, icecream = 1.1}, boostText = "Lemonade & Ice Cream +10%",
		kind = "Commercial", stars = 2, cap = 5, loc = 0.08, blurb = "Cheap plots and plenty of them. Great first property."},
	{key = "midtown",    name = "Midtown",         icon = "🏬", tier = 2, cost = 120000,   income = 60,     color = RGB(230, 120, 80), boost = {bakery = 1.1, coffee = 1.1}, boostText = "Bakery & Coffee +10%",
		kind = "Commercial", stars = 3, cap = 5, loc = 0.12, blurb = "The main business area. Lots of room to grow."},
	{key = "entertainment", name = "Entertainment District", icon = "🎪", tier = 3, cost = 900000, income = 400, color = RGB(255, 90, 200), boost = {arcade = 1.2, pizza = 1.1}, boostText = "Arcade +20%, Pizza +10%",
		kind = "Commercial", stars = 4, cap = 3, loc = 0.15, locFor = {arcade = 0.3, pizza = 0.3}, blurb = "Next to the Fun Park and the Fun Zone. Arcades love it here."},
	{key = "expansion",  name = "Expansion District", icon = "🚧", tier = 5, cost = 120000000, income = 25000, color = RGB(150, 160, 175), boost = {all = 1.05}, boostText = "ALL income +5%",
		kind = "Late-game land", stars = 4, cap = 5, loc = 0.2, blurb = "New land at the edge of the city, for empires that ran out of room."},
}
C.DISTRICT = {}
for _, d in ipairs(C.DISTRICTS) do C.DISTRICT[d.key] = d end

-- ===== HOMES: 5 neighborhoods, from poor to rich =====
C.HOODS = {
	{key = "oldtown", name = "Old Town",        icon = "🏚️", tier = 1, price = 1500,    build = 500,    mult = 1,   style = "cottage",
		perk = "Street Smart: 30% fewer business problems", color = RGB(170, 120, 90)},
	{key = "suburbs", name = "Maple Suburbs",   icon = "🏡", tier = 1, price = 20000,    build = 6000,   mult = 1.5, style = "bungalow",
		perk = "Family Friendly: +10% customers", color = RGB(110, 180, 110)},
	{key = "ocean",   name = "Oceanfront",      icon = "🌊", tier = 4, price = 2500000,  build = 400000,  mult = 2.5, style = "beach",
		perk = "Beach Vibes: Lemonade & Ice Cream +25%", color = RGB(80, 200, 230)},
	{key = "hills",   name = "Hillside",        icon = "⛰️", tier = 5, price = 25000000,  build = 4000000,  mult = 3,   style = "modern",
		perk = "Great View: +15% reputation gains", color = RGB(120, 160, 90)},
	{key = "rich",    name = "Millionaire Row", icon = "💎", tier = 6, price = 250000000, build = 40000000, mult = 4,   style = "mansion",
		perk = "Old Money: +15% ALL income", color = RGB(230, 190, 90)},
}
C.HOOD = {}
for _, h in ipairs(C.HOODS) do C.HOOD[h.key] = h end
-- v10: seven house tiers (levels 1-5 kept their place; 6 and 7 are new)
C.HOME_LEVELS = {"Starter Home", "Expanded Home", "Luxury Home", "Modern Estate", "Mansion", "Mega Mansion", "Empire Estate"}
C.STARTER_HOMES = {
	{hood = "oldtown", name = "Old Town Cottage",  desc = "Tiny, cheap and full of character. Fewer business problems."},
	{hood = "suburbs", name = "Suburban Starter",   desc = "A classic family home. More customers."},
	{hood = "ocean",   name = "Beach Shack",        desc = "Right on the sand! Lemonade & Ice Cream earn more."},
}

-- ===== PROPERTY MANAGEMENT =====
C.RENTALS = {
	{key = "walkup",  name = "Walk-Up",           units = 4,  floors = 2, cost = 300000, payback = 1800,   color = RGB(170, 90, 70)},
	{key = "complex", name = "Apartment Complex", units = 8,  floors = 4, cost = 3000000, payback = 2700,  color = RGB(225, 210, 180)},
	{key = "tower",   name = "Luxury Tower",      units = 12, floors = 6, cost = 40000000, payback = 4000, color = RGB(80, 110, 150)},
}
-- payback = seconds of full-occupancy rent to earn back the building's price (v6 was 1250s / 625s / 417s)
C.RENTAL = {}
for _, r in ipairs(C.RENTALS) do C.RENTAL[r.key] = r end
-- building upgrades: floors = extra floors (2 units each), rent = rent multiplier, cost = price as a share of the building's base cost
C.RENTAL_LEVELS = {
	{name = "Standard",  floors = 0, rent = 1.00, cost = 0},
	{name = "Renovated", floors = 1, rent = 1.05, cost = 0.6},
	{name = "Modern",    floors = 1, rent = 1.25, cost = 1.0},
	{name = "Premium",   floors = 2, rent = 1.30, cost = 1.6},
	{name = "Iconic",    floors = 2, rent = 1.50, cost = 2.4},
}
C.RENTAL_UPKEEP = 0.0012   -- upkeep every rent cycle, as a share of everything invested in the building
C.TENANT = {
	first = {"Gary", "Brenda", "Kevin", "Linda", "Dwayne", "Karen", "Chad", "Doris", "Todd", "Marge", "Steve", "Pam", "Bob", "Tina", "Hank", "Wanda", "Rick", "Sheila", "Dale", "Gloria", "Earl", "Bev", "Lenny", "Rhonda"},
	last = {"Pickles", "McBiscuit", "Wiggins", "Bumblefoot", "Noodleman", "Fluffernut", "Crumb", "Wobble", "Snorkel", "Puddleby", "Grumbles", "Tater"},
	jobs = {"Professional Juggler", "Part-time Wizard", "Accountant", "Dog Groomer", "Aspiring Rapper", "Night Security Guard", "Yoga Teacher", "Food Critic", "Magician", "Mime", "Dentist", "Crypto Guy", "Llama Farmer", "Opera Singer"},
	-- bad = extra chance of drama, temper = how hard warnings/fines hit their mood, loyal = how hard it is to make them leave
	traits = {
		{name = "Party Animal", icon = "🎉", bad = 0.25, temper = 1.3, loyal = 0.8,
			warn = "says the party is 'basically over'. The bass disagrees.", fine = "paid the fine in crumpled party tickets.", angry = "is throwing a 'goodbye forever' party. It's loud."},
		{name = "Pet Lover", icon = "🐾", bad = 0.15, temper = 0.9, loyal = 1.1,
			warn = "apologized on behalf of the llama.", fine = "paid, but the parrot is now yelling your name.", angry = "packed up 6 cats, 2 goats and one very judgmental parrot."},
		{name = "DIY Enthusiast", icon = "🔨", bad = 0.15, temper = 1.0, loyal = 1.0, fixes = true,
			warn = "promised to stop drilling after midnight. Mostly. They also fixed a squeaky door.", fine = "paid and built you a 'complaints box'. It's nailed shut.", angry = "took the shelves they built. And the doorknobs."},
		{name = "Mysterious", icon = "🕵️", bad = 0.1, temper = 0.6, loyal = 1.2, mystery = true,
			warn = "nodded slowly and closed the door. Nobody knows what that means.", fine = "slid an envelope under your door. Exact change. And a feather.", angry = "vanished overnight. The unit smells faintly of cinnamon."},
		{name = "Home Chef", icon = "👨‍🍳", bad = 0.05, temper = 0.8, loyal = 1.2, cookies = true,
			warn = "left apology cookies at your office. 🍪", fine = "paid and is 'cooking about it'. The whole hallway smells amazing.", angry = "moved out and took the good recipes with them."},
		{name = "Musician", icon = "🎸", bad = 0.2, temper = 1.1, loyal = 0.9,
			warn = "wrote a sad song about it. It's honestly pretty good.", fine = "paid entirely in quarters from their guitar case.", angry = "released a diss track about you. It has 40 streams."},
		{name = "Neat Freak", icon = "🧼", bad = -0.15, temper = 1.4, loyal = 1.0,
			warn = "is deeply offended and alphabetized their complaints about YOU.", fine = "paid, then sanitized the pen you used to write the fine.", angry = "left a 12-page cleanliness review of the building."},
		{name = "Quiet Bookworm", icon = "📚", bad = -0.2, temper = 1.2, loyal = 1.3,
			warn = "whispered 'sorry' and went back to chapter 14.", fine = "paid and is now reading a book called 'Tenant Rights'.", angry = "left a strongly worded bookmark behind."},
	},
	acts = {"tried to adopt", "set up a drum kit for", "started a secret bakery with", "threw a surprise birthday party for", "tried to train",
		"built a trampoline park for", "hosted a karaoke tournament with", "filled the hallway with", "opened an illegal petting zoo featuring", "held a wrestling match against"},
	objects = {"a llama named Kevin", "47 rubber ducks", "a live goat", "an inflatable T-rex", "their cousin's heavy metal band", "3,000 bouncy balls",
		"a pet raccoon", "a smoke machine", "a very loud parrot", "an entire tuba section", "a mini horse", "a disco ball the size of a car"},
	whens = {"at 3 AM", "during a thunderstorm", "on a Tuesday for no reason", "without asking anyone", "while wearing a banana costume", "during the building's fire drill"},
	results = {"The neighbors are NOT happy.", "The hallway is now slightly sticky.", "The fire alarm has opinions.", "Someone called the news.",
		"The elevator smells like cheese now.", "Unit 1A wants to move out.", "There are feathers everywhere.", "The landlord group chat is exploding."},
	good = {"baked cookies for the whole building! 🍪", "fixed the broken elevator by themselves! 🔧", "planted a rooftop garden! 🌻",
		"paid 3 months of rent early! 💵", "organized a building clean-up day! 🧹", "rescued a cat from the roof! 🐱"},
	late = {"says the rent is 'in the mail'.", "paid the rent in pennies. It took 4 hours to count.", "tried to pay rent with a coupon for a free smoothie.",
		"says their dog ate the rent money.", "offered to pay rent in 'exposure' on their podcast."},
}

-- ===== STAFF =====
C.STAFF_ROLES = {
	lemonade = {role = "Juice Maker", icon = "🧃"}, icecream = {role = "Scooper", icon = "🍦"},
	bakery = {role = "Chef", icon = "👨‍🍳"}, coffee = {role = "Barista", icon = "☕"},
	pizza = {role = "Pizza Chef", icon = "🍕"}, arcade = {role = "Game Host", icon = "🕹️"},
	tech = {role = "Developer", icon = "🧑‍💻"}, factory = {role = "Warehouse Worker", icon = "📦"},
	manager = {role = "Manager", icon = "💰", cost = 500000, desc = "+1.5% ALL income per star"},
	marketer = {role = "Marketer", icon = "📣", cost = 120000, desc = "+6% customers per star"},
	engineer = {role = "Engineer", icon = "🔧", cost = 30000, desc = "Fewer problems, cheaper repairs"},
}
C.STAFF_ORDER = {"lemonade", "icecream", "bakery", "coffee", "pizza", "arcade", "tech", "factory", "manager", "marketer", "engineer"}
C.NAMES = {"Alex", "Sam", "Jordan", "Riley", "Casey", "Morgan", "Taylor", "Jamie", "Avery", "Quinn", "Maya", "Leo", "Zoe", "Omar", "Priya", "Kai", "Nina", "Luca", "Ivy", "Theo", "Rosa", "Ben", "Aria", "Milo"}

C.PROBLEMS = {
	{text = "Machine broke!", icon = "⚙️"}, {text = "An employee called out!", icon = "🤒"}, {text = "Power outage!", icon = "🔌"},
	{text = "Supply shortage!", icon = "📦"}, {text = "Delivery truck broke down!", icon = "🚚"}, {text = "Customer complaint!", icon = "😠"},
	{text = "A bad review is spreading!", icon = "👎"}, {text = "A competitor opened nearby!", icon = "🏪"}, {text = "Theft! Stock was stolen!", icon = "🦹"},
	{text = "Construction is blocking the road!", icon = "🚧"},
	{text = "Surprise inspection! The inspector found a mess.", icon = "🧑‍⚖️"},   -- story chapter 4 only
}
C.PROBLEM_RANDOM = 10          -- random problems use the first 10 types
C.INSPECTION_PROBLEM = 11

C.NPC_TYPES = {
	{key = "office",     icon = "💼", shirt = RGB(60, 75, 120),   pants = RGB(35, 35, 45),   likes = {coffee = 3, tech = 2, bakery = 1}},
	{key = "family",     icon = "👪", shirt = RGB(90, 170, 90),   pants = RGB(60, 70, 120),  likes = {bakery = 3, pizza = 2, icecream = 2}, family = true},
	{key = "student",    icon = "🎓", shirt = RGB(235, 125, 45),  pants = RGB(50, 60, 110),  likes = {arcade = 3, pizza = 2, lemonade = 2}},
	{key = "gym",        icon = "🏋️", shirt = RGB(220, 50, 60),   pants = RGB(30, 30, 30),   likes = {lemonade = 3, icecream = 1}},
	{key = "builder",    icon = "🛠️", shirt = RGB(250, 170, 30),  pants = RGB(70, 80, 110),  likes = {factory = 3, bakery = 2, coffee = 1}},
	{key = "rich",       icon = "💰", shirt = RGB(25, 25, 30),    pants = RGB(25, 25, 30),   likes = {tech = 2, coffee = 2, pizza = 1}, tip = 3, fancy = true},
	{key = "influencer", icon = "🤳", shirt = RGB(255, 110, 200), pants = RGB(240, 240, 250), likes = {}, trendy = true},
}
C.REVIEWS = {
	[5] = {"The %s was amazing!", "Best %s in the city!", "10/10 would come back!", "Absolutely perfect!", "This %s changed my life.",
		"The bathroom deserves its own business.", "I came for one %s and left with four. No regrets."},
	[4] = {"Nice place but a bit expensive.", "Really good %s!", "Great vibes here.", "Nice building!", "This place is fire. My mom said we're leaving. I disagree."},
	[3] = {"It was okay.", "Pretty average honestly.", "Decent %s, nothing special."},
	[2] = {"The line was way too long.", "Service was slow...", "Kinda disappointing %s."},
	[1] = {"Terrible! Never again.", "Worst visit ever.", "Something was broken...", "I waited 14 minutes for a %s. I have aged.",
		"Too much %s. Way too much. (Is that a complaint? Yes.)"},
}

C.EVENTS = {
	{key = "heatwave",  text = "🔥 HEATWAVE! Lemonade & Ice Cream +100%, Factories -20%", dur = 60, biz = {lemonade = 2, icecream = 2, factory = 0.8}, weather = "heat",
		look = {RGB(255, 225, 190), 0.25, 0.4, RGB(255, 210, 160), 0.8}},
	{key = "snowstorm", text = "❄️ SNOWSTORM! Coffee +75%, outdoor businesses -80%", dur = 60, biz = {coffee = 1.75, lemonade = 0.2, icecream = 0.2}, weather = "snow",
		look = {RGB(215, 230, 255), -0.2, 0.55, RGB(220, 230, 245), 0.6}},
	{key = "concert",   text = "🎤 CELEBRITY CONCERT at the Beach! Pizza & Arcade +100%, beach lot owners 3x customers", dur = 60, biz = {pizza = 2, arcade = 2}, concert = true,
		look = {RGB(255, 210, 250), 0.45, 0.3, RGB(255, 200, 240), 1.2}},
	{key = "viral",     text = "📱 VIRAL TREND!", dur = 90, viral = true, weather = "confetti", look = {RGB(255, 215, 245), 0.4, 0.3, RGB(255, 200, 240), 1.1}},
	{key = "crash",     text = "🏦 MARKET CRASH! Stocks -35%, upgrades 30% OFF. Sell? Hold? Expand?", dur = 60, crash = true, weather = "rain",
		look = {RGB(180, 185, 210), -0.35, 0.5, RGB(130, 135, 155), 0.3}},
	{key = "boom",      text = "📈 ECONOMIC BOOM! All income +50%", dur = 45, all = 1.5, weather = "gold", look = {RGB(255, 245, 205), 0.35, 0.28, RGB(255, 225, 170), 1.0}},
	{key = "recession", text = "📉 RECESSION! All income -40%", dur = 45, all = 0.6, weather = "rain", look = {RGB(170, 180, 205), -0.4, 0.5, RGB(120, 130, 150), 0.3}},
	{key = "tax",       text = "🧾 TAX SEASON! Everyone pays 10% of their cash", tax = 0.1, look = {RGB(255, 200, 200), 0, 0.35, RGB(230, 170, 170), 0.4}},
	{key = "investor",  text = "😇 ANGEL INVESTOR! The smallest empire gets a cash boost", investor = true, look = {RGB(255, 240, 170), 0.3, 0.3, RGB(255, 235, 170), 1.0}},
	{key = "tourists",  text = "🧳 TOURIST WAVE! Customers x2, all income +25%", dur = 60, all = 1.25, customers = 2, era = 2, look = {RGB(220, 255, 230), 0.3, 0.3, RGB(200, 240, 220), 0.9}},
}
C.WAR_CATS = {
	{key = "profit", name = "💰 Most Profitable"}, {key = "customers", name = "👥 Most Customers"}, {key = "rep", name = "⭐ Highest Reputation"},
	{key = "empire", name = "🏗️ Biggest Empire"}, {key = "district", name = "🎨 Best District"},
}
C.SKINS = {
	{key = "classic", name = "Classic", trophies = 0}, {key = "gold", name = "Champion Gold", trophies = 1, color = RGB(255, 200, 50)},
	{key = "neon", name = "Neon Night", trophies = 3, color = RGB(60, 255, 220)}, {key = "diamond", name = "Diamond", trophies = 6, color = RGB(170, 230, 255)},
	{key = "royal", name = "Royal Purple", trophies = 10, color = RGB(170, 80, 255)},
	{key = "cyber", name = "Cyber Neon", trophies = 0, era = 5, color = RGB(255, 60, 220)},   -- for everyone who helped reach Cyber City
}
C.ADS = {
	{key = "small", name = "Small campaign", cost = 5000, customers = 1.5, income = 1, dur = 60},
	{key = "major", name = "Major campaign", cost = 60000, customers = 2.5, income = 1.1, dur = 90, marketing = true},
	{key = "citywide", name = "Citywide campaign", cost = 2000000, customers = 4, income = 1.3, dur = 120, marketing = true},
}
C.SPIRE_STAGES = {
	{name = "🏗️ Foundation", cost = E.spireStages[1]}, {name = "🏢 Lower Floors", cost = E.spireStages[2]}, {name = "🏙️ Tower", cost = E.spireStages[3]},
	{name = "🌟 Crown", cost = E.spireStages[4]}, {name = "🚀 City Beacon", cost = E.spireStages[5]},
}

-- ===== CITY ERAS: finishing the Empire Spire moves the whole server into the next era =====
C.ERAS = {
	{name = "Small Town",   icon = "🏘️", unlocks = {}},
	{name = "Growing City", icon = "🏙️", unlocks = {"Tourist Wave events", "👽 Alien Invasion mega event", "🚀 Space Diner secret", "cranes & new towers"}},
	{name = "Mega City",    icon = "🌆", unlocks = {"🤖 Robot Factory secret", "a giant skyline", "more mega events"}},
	{name = "Future City",  icon = "🛸", unlocks = {"🚀 Space Center secret", "flying cars", "floating holo-rings"}},
	{name = "Cyber City",   icon = "🌃", unlocks = {"🌃 Cyber skin for everyone who helped", "neon streets & holograms"}},
}
function C.eraName(era)
	local e = C.ERAS[math.min(era, #C.ERAS)]
	return era > #C.ERAS and (e.name .. " " .. (era - #C.ERAS + 1)) or e.name
end

-- ===== MEGA EVENTS: big server-wide moments every few minutes =====
C.MEGA = {first = 240, gapMin = 420, gapMax = 600}   -- seconds: first one after 4 min, then every 7-10 min
C.MEGA_EVENTS = {
	{key = "ufo",       icon = "🛸", title = "UFO INVASION!",        sub = "Zap the alien probes before the UFO abducts your cash!", dur = 90,  color = RGB(120, 255, 140)},
	{key = "aliens",    icon = "👽", title = "ALIEN INVASION!",      sub = "Three motherships! Zap every probe to save the city!", dur = 120, color = RGB(170, 90, 255), era = 2},
	{key = "tornado",   icon = "🌪️", title = "TORNADO WARNING!",     sub = "A tornado is tearing through the city. Grab the flying cash!", dur = 70, color = RGB(170, 180, 200)},
	{key = "investor",  icon = "💰", title = "A BILLIONAIRE IS HERE!", sub = "Pitch your empire at the Spire plaza. The best empire wins the deal!", dur = 75, color = RGB(255, 205, 60)},
	{key = "festival",  icon = "🎉", title = "CITY FESTIVAL!",       sub = "+50% customers for everyone. Find the festival tokens!", dur = 90,  color = RGB(255, 110, 200)},
	{key = "tourists",  icon = "🧳", title = "TOURIST EXPLOSION!",   sub = "3x customers and happier reviews for 60 seconds!", dur = 60, color = RGB(90, 220, 170)},
	{key = "robbery",   icon = "🦹", title = "ROBBERY WAVE!",        sub = "Robbers are hitting businesses. Stop them before they escape!", dur = 75, color = RGB(255, 80, 80)},
	{key = "heatwave",  icon = "🔥", title = "MEGA HEATWAVE!",       sub = "Lemonade & Ice Cream x3! Grab the ice pops around the city!", dur = 70, color = RGB(255, 150, 60)},
	{key = "blizzard",  icon = "❄️", title = "BLIZZARD!",            sub = "Coffee x3! Smash the snowmen for prizes!", dur = 70, color = RGB(170, 220, 255)},
	{key = "concert",   icon = "🎤", title = "DOWNTOWN CONCERT!",    sub = "Head to the Downtown stage: fans get +15% income and reputation!", dur = 90, color = RGB(255, 90, 220)},
}

-- ===== WEEKLY COMPETITIONS (reset every Monday 00:00 UTC; rewards are trophies + cosmetics only) =====
C.WEEKLY = {
	{key = "richest",   name = "💰 Richest"},
	{key = "rep",       name = "⭐ Highest Reputation"},
	{key = "lap",       name = "🏁 Fastest Lap", ascending = true, unit = "time"},
	{key = "rebirths",  name = "♻️ Most Rebirths"},
	{key = "property",  name = "🏢 Most Valuable Property"},
	{key = "business",  name = "🔥 Most Popular Business"},
	{key = "followers", name = "📱 Most CityBuzz Followers"},
	{key = "house",     name = "🏠 Best House"},
}
C.WEEKLY_REWARD = {3, 2, 1}   -- trophies for 1st/2nd/3rd in each board (the featured board of the week pays double)

-- ===== MYSTERY LOTS: a lot appears now and then; nobody knows what's inside until someone buys it =====
C.MYSTERY = {first = 360, gapMin = 720, gapMax = 1200, life = 300, priceSeconds = 150, minPrice = 5000, tier = 2}
C.MYSTERY_FINDS = {
	{key = "arcade",   name = "Secret Arcade",           icon = "🕹️", weight = 30, rarity = "Common",    perk = {all = 1.02},       perkText = "+2% ALL income"},
	{key = "bank",     name = "Bank Vault",              icon = "🏦", weight = 24, rarity = "Common",    cashSeconds = 240,        perkText = "a vault full of cash"},
	{key = "lab",      name = "Research Lab",            icon = "🔬", weight = 18, rarity = "Uncommon",  perk = {all = 1.04},       perkText = "+4% ALL income"},
	{key = "stadium",  name = "Stadium",                 icon = "🏟️", weight = 12, rarity = "Uncommon",  perk = {customers = 1.08}, perkText = "+8% customers"},
	{key = "studio",   name = "Movie Studio Backlot",    icon = "🎬", weight = 8,  rarity = "Rare",      followers = 300, trophies = 1, perkText = "+300 followers and a trophy"},
	{key = "robots",   name = "Robot Factory Warehouse", icon = "🤖", weight = 6,  rarity = "Rare",      perk = {problems = 0.85},  perkText = "15% fewer problems"},
	{key = "space",    name = "Space Center Hangar",     icon = "🚀", weight = 2,  rarity = "LEGENDARY", perk = {all = 1.1},        perkText = "+10% ALL income"},
}

-- ===== REBIRTH =====
C.REBIRTH = {
	base = E.rebirthBase, step = E.rebirthStep,   -- cost = base * (1 + step * rebirths)
	incomePer = 0.1,                    -- +10% income per rebirth (permanent)
	perks = {
		{at = 10,  name = "Tycoon", icon = "💼", desc = "Start every rebirth with $250K and keep your staff"},
		{at = 50,  name = "Mogul",  icon = "🎩", desc = "Businesses restart at Level 3, problems fix themselves, 1.5x customers"},
		{at = 100, name = "Legend", icon = "👑", desc = "x2 ALL income, the Legend Hypercar and a golden aura"},
	},
}

-- ===== GAME PASSES (paste your IDs; 0 = free test in Studio) =====
C.PASSES = {
	{key = "x2",        id = 0, price = 99,  icon = "💵", name = "2x Money",        desc = "Double all of your income."},
	{key = "x4",        id = 0, price = 249, icon = "💰", name = "4x Money",        desc = "4x all income (replaces 2x)."},
	{key = "goldcar",   id = 0, price = 399, icon = "🏎️", name = "Golden Supercar", desc = "Unlock the golden supercar."},
	{key = "nitro",     id = 0, price = 79,  icon = "🔥", name = "Nitro Boost",     desc = "Hold SHIFT for nitro in any car, and run faster."},
	{key = "shield",    id = 0, price = 49,  icon = "🛡️", name = "Freeze Shield",   desc = "Rivals can't freeze your income."},
	{key = "richstart", id = 0, price = 59,  icon = "🎁", name = "Rich Start",      desc = "+$5,000 when you start a save (once per save), plus a bonus after every Corner War (30s of income, up to $5,000)."},
	{key = "vip",       id = 0, price = 149, icon = "👑", name = "VIP",             desc = "+25% income (added on top of any money pass) and a gold VIP tag."},
}

-- ===== CARS (realistic part-built bodies) =====
-- grip = how quickly sideways sliding stops (higher = more planted), drift = how easily the tail kicks out (1 = normal)
-- L/W = size, H = body height, clear = ground clearance, wheel = wheel size, roof = cabin height, cab = cabin length, cabZ = cabin offset (+ = rear)
C.CARS = {
	{key = "moped",  name = "Moped",           price = 800,    speed = 45,  turn = 2.8, grip = 7.5, drift = 0.55,  color = RGB(90, 220, 140),  style = "moped",  L = 6,  W = 2.2, H = 1.2, clear = 1.2, wheel = 2},
	{key = "hatch",  name = "City Hatch",      price = 6000,   speed = 52,  turn = 2.3, grip = 6, drift = 1.0,  color = RGB(70, 140, 235),  style = "hatch",  L = 13, W = 6.2, H = 2.4, clear = 1.0, wheel = 2.7, roof = 3.0, cab = 6.5, cabZ = 1.2},
	{key = "sedan",  name = "Sedan LX",        price = 40000,  speed = 60,  turn = 2.1, grip = 6.5, drift = 0.85,  color = RGB(236, 236, 240), style = "sedan",  L = 15.5, W = 6.6, H = 2.3, clear = 1.0, wheel = 2.8, roof = 3.0, cab = 7, cabZ = 0.4},
	{key = "van",    name = "Delivery Van",    price = 60000,  speed = 52,  turn = 1.9, grip = 5, drift = 0.75,  color = RGB(245, 245, 245), style = "van",    L = 17, W = 7,   H = 2.5, clear = 1.2, wheel = 3.0, roof = 4.3, cab = 12, cabZ = 2.2, delivery = true},
	{key = "suv",    name = "Trail SUV",       price = 250000,  speed = 58,  turn = 2.0, grip = 5.5, drift = 0.8,  color = RGB(60, 90, 70),    style = "suv",    L = 15.5, W = 7, H = 2.8, clear = 1.7, wheel = 3.4, roof = 3.1, cab = 9, cabZ = 1.4},
	{key = "truck",  name = "Monster Truck",   price = 400000,  speed = 56,  turn = 1.8, grip = 4.5, drift = 0.95,  color = RGB(220, 60, 60),   style = "pickup", L = 16, W = 7.6, H = 2.8, clear = 3.4, wheel = 5.4, roof = 3.0, cab = 5.5, cabZ = -1.5},
	{key = "coupe",  name = "Sports Coupe",    price = 2500000, speed = 82,  turn = 2.4, grip = 6, drift = 1.35,  color = RGB(255, 130, 30),  style = "coupe",  L = 15, W = 6.8, H = 2.0, clear = 0.8, wheel = 2.7, roof = 2.6, cab = 5.6, cabZ = 1.4},
	{key = "hyper",  name = "Hyper Car",       price = 50000000, speed = 104, turn = 2.6, grip = 7, drift = 1.2,  color = RGB(150, 60, 255),  style = "hyper",  L = 16, W = 7.2, H = 1.8, clear = 0.7, wheel = 2.7, roof = 2.4, cab = 5, cabZ = -0.4, glow = RGB(170, 90, 255)},
	{key = "golden", name = "Golden Supercar", pass = "goldcar", speed = 116, turn = 2.7, grip = 7, drift = 1.25,  color = RGB(255, 200, 50), style = "hyper", L = 16, W = 7.2, H = 1.8, clear = 0.7, wheel = 2.7, roof = 2.4, cab = 5, cabZ = -0.4, gold = true, glow = RGB(255, 210, 80)},
	{key = "legend", name = "Legend Hypercar", rebirths = 100, speed = 132, turn = 2.8, grip = 7.5, drift = 1.3,  color = RGB(20, 20, 26), style = "hyper", L = 16.5, W = 7.4, H = 1.8, clear = 0.7, wheel = 2.8, roof = 2.4, cab = 5, cabZ = -0.4, glow = RGB(255, 200, 60)},
}
C.CAR = {}
for _, c in ipairs(C.CARS) do C.CAR[c.key] = c end

-- ===== FUN PARK + RACE =====
-- scores come from the player's screen, so the server only accepts what's physically possible:
-- minTime = the shortest real game, perPoint = seconds of play each point needs, maxTime = token expiry
C.MINIGAMES = {
	hoop   = {name = "Hoop Shot",     icon = "🏀", fee = 15, minTime = 6,  maxTime = 90,  maxScore = 10, perPoint = 0.6},
	rush   = {name = "Lemonade Rush", icon = "🍋", fee = 20, minTime = 29, maxTime = 90,  maxScore = 30, perPoint = 0.9},
	memory = {name = "Memory Match",  icon = "🧠", fee = 15, minTime = 6,  maxTime = 120, maxScore = 3,  perPoint = 2},
}
C.MINIGAME_PROFIT_CAP = E.minigameCapSeconds   -- max mini-game profit per 10 minutes, in seconds of your income
C.FERRIS = {fee = 10, buff = 0.1, buffTime = 180}
C.FIREWORKS = {fee = 30, cooldown = 60}
C.RACE = {fee = 20, par = 42, maxTime = 300}

-- ===== TUTORIAL =====
C.TUTORIAL = {
	{text = "Welcome to Corner Empire! 🍋 Tap BUY on the Lemonade Stand in your business panel.", target = "plot"},
	{text = "Nice! Upgrade the Lemonade Stand to Level 3 — watch it transform.", target = "plot"},
	{text = "Buy the Ice Cream Cart. More businesses = more customers!", target = "plot"},
	{text = "Open your 📱 Phone: press P, tap the 📱 button, or press Y on a controller. Everything lives in there.", target = nil},
	{text = "Visit your home! Walk there, or use Phone → Map → My Home.", target = "home"},
	{text = "Customers leave reviews. Reach LOCAL FAVORITE reputation to unlock Staff, Cars & Deliveries.", target = "plot"},
	{text = "Go to Corner Motors, buy a car and hop in! (Phone → Map → Dealership)", target = "dealer"},
}
end
