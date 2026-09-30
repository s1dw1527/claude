-- CONFIG: every number, name and piece of content in the game lives here.
return function(C)
local RGB = Color3.fromRGB

C.CFG = {
	MAX_PLAYERS = 4,
	SAVE_SLOTS = 3,
	START_CASH = 100,
	BASE_INCOME = 1,
	MAX_LEVEL = 10,
	EVENT_INTERVAL = 60,
	WAR_INTERVAL = 600,          -- Corner War every 10 min (1200 = 20 min)
	WAR_BUFF_TIME = 300,
	SABOTAGE_COST = 1000, SABOTAGE_TIME = 10, SABOTAGE_COOLDOWN = 45,
	DAY_SPEED = 0.01,
	SAVE_ENABLED = true,
	DATASTORE = "CornerEmpire_v5",
	RICH_START_BONUS = 5000,
	MAX_CUSTOMERS_PER_SEC = 3,
	CRASH_DISCOUNT = 0.7,
	RENT_INTERVAL = 30,
	STOCK_SELL_FEE = 0.10,       -- 10% fee on every share sale, so buy/sell loops can't create money
	MAX_SHARES_PER_ORDER = 100000,
	ACTION_RATE = 12,            -- button presses per second each player may send (burst below)
	ACTION_BURST = 30,
	LOAD_RETRIES = 3,            -- DataStore read attempts before a save is treated as unavailable
}

-- ===== REPUTATION TIERS + what each one unlocks =====
C.REP_TIERS = {
	{name = "UNKNOWN CORNER",     rep = 0,    unlocks = {"Lemonade Stand", "Ice Cream Cart", "Your home", "Phone & CityBuzz"}},
	{name = "LOCAL FAVORITE",     rep = 100,  unlocks = {"Bakery & Coffee Shop", "Staff", "Cars & Deliveries", "Fun Park", "Downtown lots"}},
	{name = "HOTSPOT",            rep = 400,  unlocks = {"Pizza & Arcade", "Stock Market", "Ads", "Property Management", "Race Track", "Empire Tower", "Industrial lots"}},
	{name = "CITY ICON",          rep = 1200, unlocks = {"Tech Startup", "Business chains", "Rebirth", "Beach lots", "Oceanfront homes"}},
	{name = "EMPIRE",             rep = 3500, unlocks = {"Factory", "Luxury Hills lots", "Hillside homes"}},
	{name = "LEGENDARY DISTRICT", rep = 9000, unlocks = {"Millionaire Row", "Legend status"}},
}
C.FEATURES = {staff = 2, cars = 2, deliveries = 2, funpark = 2, sabotage = 2, market = 3, ads = 3, properties = 3, race = 3, tower = 3, chains = 4, rebirth = 4}
C.FEATURE_NAMES = {staff = "Staff", cars = "Cars", deliveries = "Deliveries", funpark = "Fun Park", sabotage = "Freeze", market = "Stock Market",
	ads = "Ads", properties = "Property Management", race = "Race Track", tower = "Empire Tower", chains = "Business chains", rebirth = "Rebirth"}

-- ===== BUSINESSES =====
C.BUSINESSES = {
	{key = "lemonade", name = "Lemonade",  cost = 25,     income = 2,    unlock = 1, icon = "🍋", color = RGB(255, 214, 60),  wall = RGB(255, 246, 214), roof = RGB(255, 190, 40),  thing = "lemonade",
		tiers = {"Lemonade Stand", "Lemonade Shop", "Lemonade Café", "Lemonade Factory", "Lemonade Corporation", "🍋 LEMON EMPIRE HQ"}},
	{key = "icecream", name = "Ice Cream", cost = 120,    income = 6,    unlock = 1, icon = "🍦", color = RGB(255, 150, 200), wall = RGB(255, 232, 242), roof = RGB(120, 220, 200), thing = "ice cream",
		tiers = {"Ice Cream Cart", "Ice Cream Parlor", "Gelato House", "Creamery", "Ice Cream Tower", "🍦 FROZEN EMPIRE HQ"}},
	{key = "bakery",   name = "Bakery",    cost = 500,    income = 18,   unlock = 2, icon = "🥐", color = RGB(235, 150, 80),  wall = RGB(176, 92, 62),   roof = RGB(90, 60, 50),    thing = "croissants",
		tiers = {"Bread Stall", "Bakery", "Patisserie", "Grand Bakery", "Bakery Corporation", "🥐 CROISSANT CASTLE"}},
	{key = "coffee",   name = "Coffee",    cost = 2000,   income = 60,   unlock = 2, icon = "☕", color = RGB(150, 100, 70),  wall = RGB(60, 70, 64),    roof = RGB(40, 44, 42),    thing = "coffee",
		tiers = {"Coffee Cart", "Coffee Shop", "Coffee House", "Roastery", "Coffee Corporation", "☕ BEAN EMPIRE HQ"}},
	{key = "pizza",    name = "Pizza",     cost = 7000,   income = 180,  unlock = 3, icon = "🍕", color = RGB(230, 70, 50),   wall = RGB(245, 230, 205), roof = RGB(40, 130, 70),   thing = "pizza",
		tiers = {"Pizza Window", "Pizza Place", "Pizzeria", "Pizza Palace", "Pizza Corporation", "🍕 PIZZA DOME"}},
	{key = "arcade",   name = "Arcade",    cost = 25000,  income = 550,  unlock = 3, icon = "🕹️", color = RGB(150, 80, 255),  wall = RGB(38, 28, 66),    roof = RGB(255, 60, 180),  thing = "games",
		tiers = {"Game Corner", "Arcade", "Mega Arcade", "Game Center", "eSports Arena", "🕹️ GAMING CITADEL"}},
	{key = "tech",     name = "Tech",      cost = 90000,  income = 1700, unlock = 4, icon = "💻", color = RGB(70, 150, 255),  wall = RGB(225, 232, 244), roof = RGB(40, 42, 52),    thing = "app",
		tiers = {"Garage Startup", "Tech Startup", "Tech Company", "Tech Campus", "Tech Giant", "💻 SILICON SPIRE"}},
	{key = "factory",  name = "Factory",   cost = 350000, income = 5500, unlock = 5, icon = "🏭", color = RGB(170, 175, 190), wall = RGB(150, 84, 64),   roof = RGB(90, 94, 102),   thing = "products",
		tiers = {"Workshop", "Factory", "Big Factory", "Industrial Plant", "Mega Factory", "🏭 INDUSTRIAL TITAN"}},
}
C.BIZ = {}
for i, b in ipairs(C.BUSINESSES) do
	b.index = i
	C.BIZ[b.key] = b
end
C.CHAINS = {{name = "Downtown", mult = 40}, {name = "Airport", mult = 120}, {name = "Luxury", mult = 350}}

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
}

-- ===== BUSINESS LAND (districts) =====
C.DISTRICTS = {
	{key = "downtown",   name = "Downtown",        icon = "🏙️", tier = 2, cost = 20000,   income = 80,    color = RGB(80, 140, 235), boost = {coffee = 1.15, tech = 1.15}, boostText = "Coffee & Tech +15%"},
	{key = "industrial", name = "Industrial Zone", icon = "🏭", tier = 3, cost = 150000,  income = 500,   color = RGB(235, 165, 50), boost = {factory = 1.25, bakery = 1.1}, boostText = "Factory +25%, Bakery +10%"},
	{key = "beach",      name = "Beach District",  icon = "🏖️", tier = 4, cost = 800000,  income = 2500,  color = RGB(80, 210, 220), boost = {lemonade = 1.5, icecream = 1.5}, boostText = "Lemonade & Ice Cream +50%"},
	{key = "luxury",     name = "Luxury Hills",    icon = "💎", tier = 5, cost = 4000000, income = 12000, color = RGB(190, 110, 255), boost = {all = 1.1}, boostText = "ALL income +10%"},
}
C.DISTRICT = {}
for _, d in ipairs(C.DISTRICTS) do C.DISTRICT[d.key] = d end

-- ===== HOMES: 5 neighborhoods, from poor to rich =====
C.HOODS = {
	{key = "oldtown", name = "Old Town",        icon = "🏚️", tier = 1, price = 1500,    build = 400,    mult = 1,   style = "cottage",
		perk = "Street Smart: 30% fewer business problems", color = RGB(170, 120, 90)},
	{key = "suburbs", name = "Maple Suburbs",   icon = "🏡", tier = 1, price = 8000,    build = 2500,   mult = 1.5, style = "bungalow",
		perk = "Family Friendly: +10% customers", color = RGB(110, 180, 110)},
	{key = "ocean",   name = "Oceanfront",      icon = "🌊", tier = 4, price = 150000,  build = 20000,  mult = 2.5, style = "beach",
		perk = "Beach Vibes: Lemonade & Ice Cream +25%", color = RGB(80, 200, 230)},
	{key = "hills",   name = "Hillside",        icon = "⛰️", tier = 5, price = 400000,  build = 60000,  mult = 3,   style = "modern",
		perk = "Great View: +15% reputation gains", color = RGB(120, 160, 90)},
	{key = "rich",    name = "Millionaire Row", icon = "💎", tier = 6, price = 2500000, build = 300000, mult = 4,   style = "mansion",
		perk = "Old Money: +15% ALL income", color = RGB(230, 190, 90)},
}
C.HOOD = {}
for _, h in ipairs(C.HOODS) do C.HOOD[h.key] = h end
C.HOME_LEVELS = {"Starter", "Cozy", "Two-Story", "Deluxe", "Dream Home"}
C.STARTER_HOMES = {
	{hood = "oldtown", name = "Old Town Cottage",  desc = "Tiny, cheap and full of character. Fewer business problems."},
	{hood = "suburbs", name = "Suburban Starter",   desc = "A classic family home. More customers."},
	{hood = "ocean",   name = "Beach Shack",        desc = "Right on the sand! Lemonade & Ice Cream earn more."},
}

-- ===== PROPERTY MANAGEMENT =====
C.RENTALS = {
	{key = "walkup",  name = "Walk-Up",           units = 4,  floors = 2, cost = 30000,   color = RGB(170, 90, 70)},
	{key = "complex", name = "Apartment Complex", units = 8,  floors = 4, cost = 200000,  color = RGB(225, 210, 180)},
	{key = "tower",   name = "Luxury Tower",      units = 12, floors = 6, cost = 1500000, color = RGB(80, 110, 150)},
}
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
	manager = {role = "Manager", icon = "💰", cost = 40000, desc = "+2% ALL income per star"},
	marketer = {role = "Marketer", icon = "📣", cost = 12000, desc = "+6% customers per star"},
	engineer = {role = "Engineer", icon = "🔧", cost = 6000, desc = "Fewer problems, cheaper repairs"},
}
C.STAFF_ORDER = {"lemonade", "icecream", "bakery", "coffee", "pizza", "arcade", "tech", "factory", "manager", "marketer", "engineer"}
C.NAMES = {"Alex", "Sam", "Jordan", "Riley", "Casey", "Morgan", "Taylor", "Jamie", "Avery", "Quinn", "Maya", "Leo", "Zoe", "Omar", "Priya", "Kai", "Nina", "Luca", "Ivy", "Theo", "Rosa", "Ben", "Aria", "Milo"}

C.PROBLEMS = {
	{text = "Machine broke!", icon = "⚙️"}, {text = "An employee called out!", icon = "🤒"}, {text = "Power outage!", icon = "🔌"},
	{text = "Supply shortage!", icon = "📦"}, {text = "Delivery truck broke down!", icon = "🚚"}, {text = "Customer complaint!", icon = "😠"},
	{text = "A bad review is spreading!", icon = "👎"}, {text = "A competitor opened nearby!", icon = "🏪"}, {text = "Theft! Stock was stolen!", icon = "🦹"},
	{text = "Construction is blocking the road!", icon = "🚧"},
}

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
	[5] = {"The %s was amazing!", "Best %s in the city!", "10/10 would come back!", "Absolutely perfect!"},
	[4] = {"Nice place but a bit expensive.", "Really good %s!", "Great vibes here.", "Nice building!"},
	[3] = {"It was okay.", "Pretty average honestly.", "Decent %s, nothing special."},
	[2] = {"The line was way too long.", "Service was slow...", "Kinda disappointing %s."},
	[1] = {"Terrible! Never again.", "Worst visit ever.", "Something was broken..."},
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
	{key = "small", name = "Small campaign", cost = 2000, customers = 1.5, income = 1, dur = 60},
	{key = "major", name = "Major campaign", cost = 10000, customers = 2.5, income = 1.1, dur = 90, marketing = true},
	{key = "citywide", name = "Citywide campaign", cost = 100000, customers = 4, income = 1.3, dur = 120, marketing = true},
}
C.SPIRE_STAGES = {
	{name = "🏗️ Foundation", cost = 50000}, {name = "🏢 Lower Floors", cost = 300000}, {name = "🏙️ Tower", cost = 1500000},
	{name = "🌟 Crown", cost = 6000000}, {name = "🚀 City Beacon", cost = 20000000},
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

-- ===== REBIRTH =====
C.REBIRTH = {
	base = 1000000, step = 0.6,        -- cost = base * (1 + step * rebirths)
	incomePer = 0.1,                    -- +10% income per rebirth (permanent)
	perks = {
		{at = 10,  name = "Tycoon", icon = "💼", desc = "Start every rebirth with $25K and keep your staff"},
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
	{key = "richstart", id = 0, price = 59,  icon = "🎁", name = "Rich Start",      desc = "+$5,000 when you start a save (once per save) and after every Corner War."},
	{key = "vip",       id = 0, price = 149, icon = "👑", name = "VIP",             desc = "+25% income and a gold VIP tag."},
}

-- ===== CARS (realistic part-built bodies) =====
-- grip = how quickly sideways sliding stops (higher = more planted), drift = how easily the tail kicks out (1 = normal)
-- L/W = size, H = body height, clear = ground clearance, wheel = wheel size, roof = cabin height, cab = cabin length, cabZ = cabin offset (+ = rear)
C.CARS = {
	{key = "moped",  name = "Moped",           price = 800,    speed = 45,  turn = 2.8, grip = 7.5, drift = 0.55,  color = RGB(90, 220, 140),  style = "moped",  L = 6,  W = 2.2, H = 1.2, clear = 1.2, wheel = 2},
	{key = "hatch",  name = "City Hatch",      price = 2500,   speed = 52,  turn = 2.3, grip = 6, drift = 1.0,  color = RGB(70, 140, 235),  style = "hatch",  L = 13, W = 6.2, H = 2.4, clear = 1.0, wheel = 2.7, roof = 3.0, cab = 6.5, cabZ = 1.2},
	{key = "sedan",  name = "Sedan LX",        price = 15000,  speed = 60,  turn = 2.1, grip = 6.5, drift = 0.85,  color = RGB(236, 236, 240), style = "sedan",  L = 15.5, W = 6.6, H = 2.3, clear = 1.0, wheel = 2.8, roof = 3.0, cab = 7, cabZ = 0.4},
	{key = "van",    name = "Delivery Van",    price = 20000,  speed = 52,  turn = 1.9, grip = 5, drift = 0.75,  color = RGB(245, 245, 245), style = "van",    L = 17, W = 7,   H = 2.5, clear = 1.2, wheel = 3.0, roof = 4.3, cab = 12, cabZ = 2.2, delivery = true},
	{key = "suv",    name = "Trail SUV",       price = 45000,  speed = 58,  turn = 2.0, grip = 5.5, drift = 0.8,  color = RGB(60, 90, 70),    style = "suv",    L = 15.5, W = 7, H = 2.8, clear = 1.7, wheel = 3.4, roof = 3.1, cab = 9, cabZ = 1.4},
	{key = "truck",  name = "Monster Truck",   price = 60000,  speed = 56,  turn = 1.8, grip = 4.5, drift = 0.95,  color = RGB(220, 60, 60),   style = "pickup", L = 16, W = 7.6, H = 2.8, clear = 3.4, wheel = 5.4, roof = 3.0, cab = 5.5, cabZ = -1.5},
	{key = "coupe",  name = "Sports Coupe",    price = 120000, speed = 82,  turn = 2.4, grip = 6, drift = 1.35,  color = RGB(255, 130, 30),  style = "coupe",  L = 15, W = 6.8, H = 2.0, clear = 0.8, wheel = 2.7, roof = 2.6, cab = 5.6, cabZ = 1.4},
	{key = "hyper",  name = "Hyper Car",       price = 400000, speed = 104, turn = 2.6, grip = 7, drift = 1.2,  color = RGB(150, 60, 255),  style = "hyper",  L = 16, W = 7.2, H = 1.8, clear = 0.7, wheel = 2.7, roof = 2.4, cab = 5, cabZ = -0.4, glow = RGB(170, 90, 255)},
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
C.MINIGAME_PROFIT_CAP = 900   -- max mini-game profit per 10 minutes, in seconds of your income
C.FERRIS = {fee = 10, buff = 0.1, buffTime = 180}
C.FIREWORKS = {fee = 30, cooldown = 60}
C.RACE = {fee = 20, par = 42, maxTime = 300}

-- ===== TUTORIAL =====
C.TUTORIAL = {
	{text = "Welcome to Corner Empire! 🍋 Tap BUY on the Lemonade Stand in your business panel.", target = "plot"},
	{text = "Nice! Upgrade the Lemonade Stand to Level 3 — watch it transform.", target = "plot"},
	{text = "Buy the Ice Cream Cart. More businesses = more customers!", target = "plot"},
	{text = "Open your 📱 Phone (press P or tap the phone button). Everything lives in there.", target = nil},
	{text = "Visit your home! Walk there, or use Phone → Map → My Home.", target = "home"},
	{text = "Customers leave reviews. Reach LOCAL FAVORITE reputation to unlock Staff, Cars & Deliveries.", target = "plot"},
	{text = "Go to Corner Motors, buy a car and hop in! (Phone → Map → Dealership)", target = "dealer"},
}
end
