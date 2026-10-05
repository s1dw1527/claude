-- BRANDS + PRODUCTS (v10): you don't own "a lemonade stand", you own Spencer's Lemon Lab and its Blue Raspberry Blast.
--
-- NAMES: every business can be named (3-24 characters, run through Roblox's text filter on the server; if the
-- filter can't be reached the name is simply not changed). The first name is free; renaming later has a cooldown
-- and a small fee. The name shows on the building, the plot sign, the business card, the map and CityBuzz.
--
-- BRAND: logo, sign color, accent, exterior color, interior theme, uniform color and menu style. Cosmetic only.
--
-- PRODUCTS: each business gets more product slots as it levels (1 / 2 at Lv3 / 3 at Lv5 / 4 at Lv7 / 5 at Lv10).
-- A product has a price, quality, presentation, ingredients, popularity and a trend score. They change income only
-- through a bounded multiplier (0.6x - 1.35x): price too high and demand drops, too low and you leave money on the
-- table. Defaults (fair price, no upgrades) give exactly 1.0x, so nobody's economy changes until they tinker.
--
-- SUPPLIES: three supplies per business that customers use up. Below 20% sales drop (down to half at 0%).
-- Restock at the business, remotely with an Executive computer (+10% delivery fee), or let your manager do it.
--
-- TRENDS: now and then a popular product goes viral for 90 seconds (more customers, a CityBuzz post). Cooldowns
-- per product and per player keep it rare.
return function(C)
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local F, data, R = C.F, C.data, C.R
local RGB = Color3.fromRGB
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

-- =====================================================================
-- CONTENT
-- =====================================================================
C.BRAND_LOGOS = {"🍋", "⭐", "👑", "🔥", "💎", "🌈", "⚡", "🍀", "🌙", "☀️", "🎯", "🚀", "🍦", "🥐", "☕", "🍕", "🕹️", "💻", "🏭", "🐝"}
C.BRAND_COLORS = {RGB(255, 214, 60), RGB(255, 120, 40), RGB(230, 60, 60), RGB(255, 110, 200), RGB(170, 90, 255), RGB(70, 120, 255),
	RGB(60, 200, 230), RGB(60, 200, 120), RGB(140, 100, 60), RGB(245, 245, 245), RGB(40, 40, 46), RGB(210, 170, 60)}
C.BRAND_THEMES = {"Classic", "Modern", "Retro", "Neon", "Luxury", "Cozy"}
C.MENU_STYLES = {"Chalkboard", "Neon", "Classic", "Minimal"}
C.PRODUCT_TEMPLATES = {
	lemonade = {fair = 3, list = {{k = "classic", name = "Classic Lemonade", icon = "🍋", desc = "Fresh-squeezed. The original."},
		{k = "straw", name = "Strawberry Splash", icon = "🍓", desc = "Strawberry lemonade, extra pink."}, {k = "blue", name = "Blue Raspberry Blast", icon = "🫐", desc = "Cold blue raspberry lemonade."},
		{k = "mango", name = "Mango Lemon Rush", icon = "🥭", desc = "Tropical and tangy."}, {k = "mystery", name = "Mystery Flavor", icon = "🔥", desc = "Nobody knows. Not even you."},
		{k = "pink", name = "Pink Lemonade", icon = "🌸", desc = "A classic, but pinker."}}},
	icecream = {fair = 4, list = {{k = "vanilla", name = "Vanilla Cloud", icon = "🍦", desc = "Soft and simple."}, {k = "choco", name = "Chocolate Thunder", icon = "🍫", desc = "Very chocolate. Loudly."},
		{k = "straw", name = "Strawberry Swirl", icon = "🍓", desc = "Swirled with real berries."}, {k = "cookie", name = "Cookie Crunch", icon = "🍪", desc = "Cookies in every bite."},
		{k = "rainbow", name = "Rainbow Blast", icon = "🌈", desc = "Every flavor. At once."}}},
	bakery = {fair = 5, list = {{k = "croissant", name = "Butter Croissant", icon = "🥐", desc = "Flaky, golden, perfect."}, {k = "sourdough", name = "Sourdough Loaf", icon = "🍞", desc = "Slow-rised for 2 days."},
		{k = "cinnamon", name = "Cinnamon Roll", icon = "🌀", desc = "Gooey in the middle."}, {k = "muffin", name = "Choco Muffin", icon = "🧁", desc = "Double chocolate chip."},
		{k = "cake", name = "Celebration Cake", icon = "🎂", desc = "For every occasion."}}},
	coffee = {fair = 5, list = {{k = "latte", name = "House Latte", icon = "☕", desc = "Smooth and creamy."}, {k = "cold", name = "Cold Brew", icon = "🧊", desc = "Steeped 18 hours."},
		{k = "caramel", name = "Caramel Cloud", icon = "🍮", desc = "Sweet foam on top."}, {k = "matcha", name = "Matcha Rush", icon = "🍵", desc = "Green and energizing."},
		{k = "midnight", name = "Midnight Espresso", icon = "🌙", desc = "For the night shift."}}},
	pizza = {fair = 14, list = {{k = "marg", name = "Classic Margherita", icon = "🍕", desc = "Tomato, mozzarella, basil."}, {k = "pep", name = "Pepperoni Party", icon = "🎉", desc = "Pepperoni edge to edge."},
		{k = "veggie", name = "Veggie Supreme", icon = "🥦", desc = "Loaded with vegetables."}, {k = "bbq", name = "BBQ Blaze", icon = "🔥", desc = "Smoky and spicy."},
		{k = "cheese", name = "Four Cheese Dream", icon = "🧀", desc = "Four cheeses. No regrets."}}},
	arcade = {fair = 8, list = {{k = "tokens", name = "Token Pack", icon = "🪙", desc = "20 tokens."}, {k = "racing", name = "Racing Pass", icon = "🏎️", desc = "Unlimited racing for an hour."},
		{k = "tickets", name = "Prize Ticket Bundle", icon = "🎟️", desc = "Win big. Maybe."}, {k = "vip", name = "VIP Hour", icon = "⭐", desc = "Every machine, no lines."},
		{k = "party", name = "Birthday Party", icon = "🎂", desc = "Cake, games, chaos."}}},
	tech = {fair = 60, list = {{k = "case", name = "Phone Case", icon = "📱", desc = "Drop-proof (mostly)."}, {k = "buds", name = "Earbuds", icon = "🎧", desc = "Wireless and loud."},
		{k = "mouse", name = "Gaming Mouse", icon = "🖱️", desc = "RGB adds +10 skill."}, {k = "watch", name = "Smart Watch", icon = "⌚", desc = "Tells time and more."},
		{k = "laptop", name = "Laptop Pro", icon = "💻", desc = "Fast, thin, shiny."}}},
	factory = {fair = 500, list = {{k = "widgets", name = "Widget Batch", icon = "⚙️", desc = "1,000 widgets."}, {k = "toys", name = "Toy Line", icon = "🧸", desc = "Holiday best-sellers."},
		{k = "crates", name = "Shipping Crates", icon = "📦", desc = "Sturdy and stackable."}, {k = "robots", name = "Robot Parts", icon = "🤖", desc = "Beep boop components."},
		{k = "solar", name = "Solar Panels", icon = "☀️", desc = "Clean energy."}}},
}
C.SUPPLIES = {
	lemonade = {"🍋 Lemons", "🍬 Sugar", "🥤 Cups"}, icecream = {"🥛 Cream", "🍫 Toppings", "🍦 Cones"}, bakery = {"🌾 Flour", "🧈 Butter", "📦 Boxes"},
	coffee = {"☕ Coffee Beans", "🥛 Milk", "🥤 Cups"}, pizza = {"🌾 Dough", "🧀 Cheese", "📦 Boxes"}, arcade = {"🪙 Tokens", "🎁 Prizes", "🔧 Parts"},
	tech = {"🔋 Batteries", "📟 Chips", "📦 Packaging"}, factory = {"🔩 Steel", "⚡ Power", "📦 Pallets"},
}
C.INGREDIENTS = {{k = "std", name = "Standard", demand = 0, supply = 1}, {k = "prem", name = "Premium", demand = 0.04, supply = 1.3}, {k = "art", name = "Artisan", demand = 0.08, supply = 1.7}}
C.BRANDING = {
	nameMin = 3, nameMax = 24, renameCooldown = 600, renameFeeShare = 0.02, renameFeeMin = 500,
	slots = {{1, 1}, {3, 2}, {5, 3}, {7, 4}, {10, 5}},      -- {business level, product slots}
	priceMin = 0.5, priceMax = 2.0, multMin = 0.6, multMax = 1.35,
	useStock = 0.08,          -- % of each supply one customer uses
	lowStock = 20,            -- below this, sales start dropping
	restockMinutes = 1,       -- a full restock costs about this many minutes of that business's income
	remoteFee = 1.1,          -- restocking from the computer costs 10% more
	trendChance = 0.03, trendTime = 90, trendCooldown = 1800, trendPlayerCooldown = 900, trendMinPop = 70, trendCustomers = 1.5,
}
local B = C.BRANDING
local INGREDIENT = {}
for _, i in ipairs(C.INGREDIENTS) do INGREDIENT[i.k] = i end
local TEMPLATE = {}
for key, t in pairs(C.PRODUCT_TEMPLATES) do
	TEMPLATE[key] = {}
	for _, p in ipairs(t.list) do TEMPLATE[key][p.k] = p end
end

-- =====================================================================
-- NAMES (always filtered on the server)
-- =====================================================================
local function trim(s) return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", "")) end
-- returns the filtered text, or nil + a reason
function C.filterText(plr, text, minLen, maxLen)
	if type(text) ~= "string" then return nil, "No text." end
	text = trim(string.gsub(text, "[%c]", ""))
	text = string.gsub(text, "%s+", " ")
	local n = utf8.len(text) or #text
	if n < (minLen or 1) then return nil, "Too short (at least " .. (minLen or 1) .. " characters)." end
	if n > (maxLen or 24) then return nil, "Too long (at most " .. (maxLen or 24) .. " characters)." end
	local ok, res = pcall(function()
		local r = TextService:FilterStringAsync(text, plr.UserId)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(res) ~= "string" then return nil, "The name check isn't available right now. Try again in a moment." end
	if string.find(res, "#", 1, true) and not string.find(text, "#", 1, true) then return nil, "That text isn't allowed. Try something else." end
	return res, nil
end
local function brandOf(d, key)
	d.brands = type(d.brands) == "table" and d.brands or {}
	local b = d.brands[key]
	if type(b) ~= "table" then
		b = {}
		d.brands[key] = b
	end
	return b
end
function F.bizName(d, key)
	local b = d and type(d.brands) == "table" and d.brands[key]
	if type(b) == "table" and type(b.name) == "string" and b.name ~= "" then return b.name end
	return BIZ[key] and BIZ[key].name or tostring(key)
end
function F.hasBizName(d, key)
	local b = type(d.brands) == "table" and d.brands[key]
	return type(b) == "table" and type(b.name) == "string" and b.name ~= ""
end
function F.renameFee(d, key)
	local b = brandOf(d, key)
	if not b.name then return 0 end
	return math.max(B.renameFeeMin, math.floor(F.upgradeCost(d, key) * B.renameFeeShare))
end
function F.renameBiz(plr, key, text)
	local d = data[plr]
	if not (d and BIZ[key]) or (d.levels[key] or 0) <= 0 then return false, "Open that business first." end
	local b = brandOf(d, key)
	local now = os.time()
	if b.name and b.renamedAt and now - b.renamedAt < B.renameCooldown then
		return false, "You can rename again in " .. math.ceil((B.renameCooldown - (now - b.renamedAt)) / 60) .. " min."
	end
	local name, why = C.filterText(plr, text, B.nameMin, B.nameMax)
	if not name then return false, why end
	local fee = F.renameFee(d, key)
	if d.cash < fee then return false, "Renaming costs $" .. fmt(fee) .. "." end
	d.cash -= fee
	local first = b.name == nil
	b.name = name
	b.renamedAt = now
	F.refreshBuilding(plr, key, false)
	F.refreshBrandEverywhere(plr, key)
	notify(plr, "🏷️ Your " .. BIZ[key].name .. " is now \"" .. name .. "\"" .. (fee > 0 and (" (-$" .. fmt(fee) .. ")") or "") .. "!")
	if first then
		F.buzz(BIZ[key].icon, "New in town: " .. name .. " (" .. plr.Name .. "'s " .. BIZ[key].name .. ")", BIZ[key].color, "CityBuzz")
		if F.guideTip then F.guideTip(plr, "nameBusiness") end
	end
	return true
end
-- ask the client to name a business (after opening it)
function F.askBizName(plr, key)
	local d = data[plr]
	if not d or F.hasBizName(d, key) then return end
	R.Menu:FireClient(plr, "nameBiz", {key = key, icon = BIZ[key].icon, biz = BIZ[key].name, suggestion = plr.Name .. "'s " .. BIZ[key].name, first = true, fee = 0})
end
-- the plot buildings show the name too
function F.refreshBrandEverywhere(plr, key)
	local d = data[plr]
	if not d then return end
	for _, loc in ipairs(F.plotLocations and F.plotLocations(plr, d) or {}) do
		if loc.key == key then F.buildLot(loc.lot) end
	end
end

-- =====================================================================
-- BRAND STYLE (cosmetic)
-- =====================================================================
local BRAND_FIELDS = {
	logo = function(v) return table.find(C.BRAND_LOGOS, v) ~= nil end,
	sign = function(v) return C.int(v, 1, #C.BRAND_COLORS) ~= nil end,
	accent = function(v) return C.int(v, 1, #C.BRAND_COLORS) ~= nil end,
	exterior = function(v) return C.int(v, 1, #C.BRAND_COLORS) ~= nil end,
	uniform = function(v) return C.int(v, 1, #C.BRAND_COLORS) ~= nil end,
	theme = function(v) return table.find(C.BRAND_THEMES, v) ~= nil end,
	menu = function(v) return table.find(C.MENU_STYLES, v) ~= nil end,
}
function F.setBrand(plr, key, field, value)
	local d = data[plr]
	if not (d and BIZ[key]) or (d.levels[key] or 0) <= 0 then return false end
	local ok = BRAND_FIELDS[field]
	if not (ok and ok(value)) then return false end
	brandOf(d, key)[field] = value
	F.refreshBuilding(plr, key, false)
	F.refreshBrandEverywhere(plr, key)
	return true
end
function F.brandAccent(d, key)
	local b = d.brands and d.brands[key]
	return type(b) == "table" and b.accent and C.BRAND_COLORS[b.accent] or (d.plot and d.plot.color) or RGB(255, 255, 255)
end
-- the business definition with this brand's colors (used by the building builder)
function F.brandedBiz(d, key)
	local base = BIZ[key]
	local b = d.brands and d.brands[key]
	if type(b) ~= "table" or not (b.exterior or b.sign) then return base end
	return setmetatable({wall = b.exterior and C.BRAND_COLORS[b.exterior] or base.wall, color = b.sign and C.BRAND_COLORS[b.sign] or base.color}, {__index = base})
end
function F.brandInfo(d, key)
	local b = (d.brands and d.brands[key]) or {}
	return {name = F.bizName(d, key), named = F.hasBizName(d, key), logo = b.logo or BIZ[key].icon, sign = b.sign, accent = b.accent, exterior = b.exterior, uniform = b.uniform,
		theme = b.theme or "Classic", menu = b.menu or "Chalkboard", renameFee = F.renameFee(d, key),
		renameIn = (b.renamedAt and math.max(0, B.renameCooldown - (os.time() - b.renamedAt))) or 0}
end

-- =====================================================================
-- PRODUCTS
-- =====================================================================
function F.productSlots(d, key)
	local lvl = d.levels[key] or 0
	local n = 0
	for _, s in ipairs(B.slots) do if lvl >= s[1] then n = s[2] end end
	return n
end
local function productsOf(d, key)
	d.products = type(d.products) == "table" and d.products or {}
	local list = d.products[key]
	if type(list) ~= "table" then
		list = {}
		d.products[key] = list
	end
	-- every open business always has at least its classic product (so old saves start exactly where they were)
	if #list == 0 and (d.levels[key] or 0) > 0 and C.PRODUCT_TEMPLATES[key] then
		local t = C.PRODUCT_TEMPLATES[key].list[1]
		table.insert(list, {id = 1, t = t.k, name = t.name, price = 1, q = 0, pres = 0, ing = "std", pop = 50, trend = 0, sold = 0})
	end
	return list
end
F.productsOf = productsOf
local function demandOf(p)
	local ing = INGREDIENT[p.ing] or INGREDIENT.std
	return math.clamp(1.6 - 0.6 * (tonumber(p.price) or 1) + 0.03 * (tonumber(p.q) or 0) + 0.03 * (tonumber(p.pres) or 0) + 0.002 * ((tonumber(p.pop) or 50) - 50) + ing.demand, 0.2, 1.5)
end
F.productDemand = demandOf
-- the income multiplier a business gets from its product line (bounded; 1.0 with defaults)
function F.productMult(d, key)
	local list = d.products and d.products[key]
	if type(list) ~= "table" or #list == 0 then return 1 end
	local sum = 0
	for _, p in ipairs(list) do sum += (tonumber(p.price) or 1) * demandOf(p) end
	local avg = sum / #list
	local variety = 1 + 0.03 * (#list - 1)
	return math.clamp(avg * variety, B.multMin, B.multMax)
end
-- more customers come for a business with in-demand products (and a trending one)
function F.productCustomerMult(d, key)
	local list = d.products and d.products[key]
	local m = 1
	if type(list) == "table" and #list > 0 then
		local sum = 0
		for _, p in ipairs(list) do sum += demandOf(p) end
		m = math.clamp(sum / #list, 0.4, 1.4)
	end
	if d.trending and d.trending.key == key and d.trending.untilT > os.clock() then m *= B.trendCustomers end
	return m
end
local function upgradeCost(d, key, what, p)
	local base = BIZ[key].cost * C.ECONOMY.upgradeGrowth ^ math.max(0, (d.levels[key] or 1) - 1)
	if what == "q" then return (tonumber(p.q) or 0) < 5 and math.floor(base * 0.4 * 2 ^ (tonumber(p.q) or 0)) or nil end
	if what == "pres" then return (tonumber(p.pres) or 0) < 3 and math.floor(base * 0.3 * 2 ^ (tonumber(p.pres) or 0)) or nil end
	if what == "new" then return math.floor(base * 0.5) end
	return nil
end
F.productUpgradeCost = upgradeCost
function F.productAction(plr, key, action, a, b)
	local d = data[plr]
	if not (d and BIZ[key]) or (d.levels[key] or 0) <= 0 then return false, "Open that business first." end
	local list = productsOf(d, key)
	if action == "new" then
		if #list >= F.productSlots(d, key) then return false, "No free product slot. Level up the business for more." end
		local t = TEMPLATE[key][a]
		if not t then return false end
		local name = t.name
		if type(b) == "string" and b ~= "" and b ~= t.name then
			local filtered, why = C.filterText(plr, b, 3, 28)
			if not filtered then return false, why end
			name = filtered
		end
		local cost = upgradeCost(d, key, "new")
		if d.cash < cost then return false, "A new product costs $" .. fmt(cost) .. "." end
		d.cash -= cost
		local id = 0
		for _, p in ipairs(list) do id = math.max(id, tonumber(p.id) or 0) end
		table.insert(list, {id = id + 1, t = t.k, name = name, price = 1, q = 0, pres = 0, ing = "std", pop = 40, trend = 0, sold = 0})
		notify(plr, "🆕 " .. t.icon .. " " .. name .. " is on the menu at " .. F.bizName(d, key) .. "!")
		if F.guideTip then F.guideTip(plr, "createProduct") end
		return true
	end
	local id = C.int(a, 1)
	local p
	for _, x in ipairs(list) do if x.id == id then p = x end end
	if not p then return false end
	if action == "price" then
		local v = tonumber(b)
		if not v or v ~= v then return false end
		p.price = math.clamp(math.floor(v * 10 + 0.5) / 10, B.priceMin, B.priceMax)
		return true
	elseif action == "q" or action == "pres" then
		local cost = upgradeCost(d, key, action, p)
		if not cost then return false, "Already maxed." end
		if d.cash < cost then return false, "That costs $" .. fmt(cost) .. "." end
		d.cash -= cost
		p[action] = (tonumber(p[action]) or 0) + 1
		return true
	elseif action == "ing" then
		if not INGREDIENT[b] then return false end
		p.ing = b
		return true
	elseif action == "rename" then
		local filtered, why = C.filterText(plr, b, 3, 28)
		if not filtered then return false, why end
		p.name = filtered
		return true
	elseif action == "remove" then
		if #list <= 1 then return false, "A business needs at least one product." end
		for i, x in ipairs(list) do if x == p then table.remove(list, i) end end
		return true
	end
	return false
end
-- a customer bought something: which product, and what it does to popularity and supplies
function F.productServed(plr, d, key)
	local list = productsOf(d, key)
	if #list == 0 then return nil end
	local total = 0
	for _, p in ipairs(list) do total += demandOf(p) end
	local r = math.random() * total
	local chosen = list[#list]
	for _, p in ipairs(list) do
		r -= demandOf(p)
		if r <= 0 then chosen = p break end
	end
	chosen.sold = (tonumber(chosen.sold) or 0) + 1
	local target = math.clamp(50 + (demandOf(chosen) - 1) * 60 + 4 * (tonumber(chosen.q) or 0), 5, 100)
	chosen.pop = (tonumber(chosen.pop) or 50) + (target - (tonumber(chosen.pop) or 50)) * 0.02
	F.useStock(d, key)
	return chosen
end

-- =====================================================================
-- SUPPLIES
-- =====================================================================
local function stockOf(d, key)
	d.stock = type(d.stock) == "table" and d.stock or {}
	local s = d.stock[key]
	if type(s) ~= "table" then
		s = {100, 100, 100}
		d.stock[key] = s
	end
	for i = 1, 3 do s[i] = math.clamp(tonumber(s[i]) or 100, 0, 100) end
	return s
end
F.stockOf = stockOf
function F.useStock(d, key)
	local s = stockOf(d, key)
	for i = 1, 3 do s[i] = math.max(0, s[i] - B.useStock * (0.6 + math.random() * 0.8)) end
end
function F.stockMult(d, key)
	local s = d.stock and d.stock[key]
	if type(s) ~= "table" then return 1 end
	local low = math.min(tonumber(s[1]) or 100, tonumber(s[2]) or 100, tonumber(s[3]) or 100)
	return 0.5 + 0.5 * math.min(1, low / B.lowStock)
end
function F.restockCost(d, key, remote)
	local s = stockOf(d, key)
	local missing = (300 - s[1] - s[2] - s[3]) / 300
	if missing <= 0 then return 0 end
	local _, per = F.income(d, os.clock())
	local supply = 1
	for _, p in ipairs(productsOf(d, key)) do supply = math.max(supply, (INGREDIENT[p.ing] or INGREDIENT.std).supply) end
	return math.max(10, math.floor((per[key] or 0) * 60 * B.restockMinutes * missing * supply * (remote and B.remoteFee or 1)))
end
-- where you can restock from: at the business (or one of its locations), with an Executive computer, or your manager
function F.canRestockHere(plr, d, key)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local pos = root.Position
	local door = (F.slotCF(d.plot, key) * CFrame.new(0, 0, 9)).Position
	if (door - pos).Magnitude < 70 then return true end
	if plr:GetAttribute("Interior") == key and plr:GetAttribute("InteriorOwner") == plr.UserId then return true end
	for _, loc in ipairs(F.plotLocations and F.plotLocations(plr, d) or {}) do
		if loc.key == key and (loc.lot.pos - pos).Magnitude < 60 then return true end
	end
	return false
end
function F.restock(plr, key, how)
	local d = data[plr]
	if not (d and BIZ[key]) or (d.levels[key] or 0) <= 0 then return false end
	local remote = how == "remote"
	if how == "manager" then
		remote = false
	elseif remote then
		-- only from a computer you're standing at (see Computer.lua), and only an Executive Workstation or better
		if not (F.computerOpen and F.computerOpen(plr) and F.computerSessionTier(plr, d) >= 3) then
			notify(plr, "📦 Remote restocking works from an Executive Workstation (or better) computer.")
			return false
		end
	elseif not F.canRestockHere(plr, d, key) then
		notify(plr, "📦 Go to your " .. F.bizName(d, key) .. " to restock (or restock remotely from an Executive computer).")
		return false
	end
	local cost = F.restockCost(d, key, remote)
	if cost <= 0 then
		if how ~= "manager" then notify(plr, "📦 Already fully stocked.") end
		return false
	end
	if d.cash < cost then
		if how ~= "manager" then notify(plr, "📦 Restocking costs $" .. fmt(cost) .. ".") end
		return false
	end
	d.cash -= cost
	local s = stockOf(d, key)
	for i = 1, 3 do s[i] = 100 end
	if how ~= "manager" then notify(plr, "📦 " .. F.bizName(d, key) .. " restocked (-$" .. fmt(cost) .. ").") end
	return true, cost
end

-- =====================================================================
-- TRENDS (checked once a minute per player)
-- =====================================================================
local lastTrend = {}
task.spawn(function()
	while true do
		task.wait(60)
		local now = os.clock()
		for plr, d in pairs(data) do
			pcall(function()
				if (d.tut or 0) > 0 or (lastTrend[plr] or -1e9) + B.trendPlayerCooldown > now then return end
				for _, b in ipairs(C.BUSINESSES) do
					if (d.levels[b.key] or 0) > 0 then
						for _, p in ipairs(productsOf(d, b.key)) do
							p.trend = math.clamp((tonumber(p.trend) or 0) + math.random(-8, 10) + ((tonumber(p.pop) or 50) - 60) * 0.1, 0, 100)
							local cool = (tonumber(p.trendAt) or 0) + B.trendCooldown < os.time()
							if cool and (tonumber(p.pop) or 0) >= B.trendMinPop and math.random() < B.trendChance * (1 + p.trend / 100) then
								F.productTrending(plr, d, b.key, p)
								return
							end
						end
					end
				end
			end)
		end
	end
end)
function F.productTrending(plr, d, key, p)
	lastTrend[plr] = os.clock()
	p.trendAt = os.time()
	p.pop = math.min(100, (tonumber(p.pop) or 50) + 10)
	d.trending = {key = key, id = p.id, name = p.name, untilT = os.clock() + B.trendTime}
	local brand = F.bizName(d, key)
	local t = TEMPLATE[key] and TEMPLATE[key][p.t]
	R.Splash:FireClient(plr, "🔥 YOUR " .. string.upper(p.name) .. " IS TRENDING", "More customers for " .. B.trendTime .. " seconds", RGB(255, 110, 60))
	if F.viralMoment then
		F.viralMoment(plr, "productTrending", {product = p.name, brand = brand, icon = t and t.icon or "🔥", force = true})
	end
end

-- =====================================================================
-- STATE + ACTIONS
-- =====================================================================
function F.bizBrandState(d, key)
	if (d.levels[key] or 0) <= 0 then return nil end
	local prods = {}
	for _, p in ipairs(productsOf(d, key)) do
		local t = TEMPLATE[key] and TEMPLATE[key][p.t]
		local fair = C.PRODUCT_TEMPLATES[key].fair
		table.insert(prods, {id = p.id, name = p.name, icon = t and t.icon or "⭐", desc = t and t.desc or "", price = p.price, dollars = math.max(1, math.floor(fair * p.price + 0.5)),
			q = p.q, pres = p.pres, ing = p.ing, pop = math.floor(tonumber(p.pop) or 50), trend = math.floor(tonumber(p.trend) or 0), sold = p.sold,
			demand = math.floor(demandOf(p) * 100 + 0.5), qCost = upgradeCost(d, key, "q", p) or -1, presCost = upgradeCost(d, key, "pres", p) or -1})
	end
	local s = stockOf(d, key)
	local templates = {}
	for _, t in ipairs(C.PRODUCT_TEMPLATES[key].list) do table.insert(templates, {k = t.k, name = t.name, icon = t.icon, desc = t.desc}) end
	return {brand = F.brandInfo(d, key), products = prods, slots = F.productSlots(d, key), newCost = upgradeCost(d, key, "new"), templates = templates,
		stock = {{name = C.SUPPLIES[key][1], v = math.floor(s[1])}, {name = C.SUPPLIES[key][2], v = math.floor(s[2])}, {name = C.SUPPLIES[key][3], v = math.floor(s[3])}},
		restock = F.restockCost(d, key, false), restockRemote = F.restockCost(d, key, true), productMult = math.floor(F.productMult(d, key) * 100 + 0.5),
		trending = d.trending and d.trending.key == key and d.trending.untilT > os.clock() and d.trending.name or nil, locations = F.locationMult and math.floor((F.locationMult(d, key) - 1) * 100 + 0.5) or 0}
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.bizName = function(plr, d, a, b)
	if not (C.str(a, 20) and type(b) == "string" and #b <= 80) then return end
	local ok, why = F.renameBiz(plr, a, b)
	R.Menu:FireClient(plr, "nameResult", {key = a, ok = ok, why = why, name = F.bizName(d, a)})
end
C.ACTIONS.brand = function(plr, d, a, b, c)
	if C.str(a, 20) and C.str(b, 12) and (type(c) == "number" or C.str(c, 12)) then F.setBrand(plr, a, b, c) end
end
C.ACTIONS.product = function(plr, d, a, b, c)
	-- a = business key, b = {action, id/template, value}
	if not (C.str(a, 20) and type(b) == "table") then return end
	local action, x, y = b[1], b[2], b[3]
	if not C.str(action, 10) then return end
	if type(y) == "string" and #y > 80 then return end
	local ok, why = F.productAction(plr, a, action, x, y)
	if not ok and why then notify(plr, "📦 " .. why) end
end
C.ACTIONS.restock = function(plr, d, a, b)
	-- (remote restocking goes through the computer: pcRestock)
	if C.str(a, 20) then F.restock(plr, a, "here") end
end
Players.PlayerRemoving:Connect(function(plr) lastTrend[plr] = nil end)

-- ===== Studio tool =====
C.DEBUG = C.DEBUG or {}
C.DEBUG.trend = function(plr, d)
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 then F.productTrending(plr, d, b.key, productsOf(d, b.key)[1]) return end
	end
end
end
