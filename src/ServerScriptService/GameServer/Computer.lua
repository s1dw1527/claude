-- COMPUTER (v10): a real object in your home (furniture shop → Tech) and in your HQ's private office.
-- Walk up → [Use Computer] → the computer opens. The server only sends computer data to a player standing at a
-- computer they own, and the tier decides which apps work:
--   Basic Computer         Empire Overview, Finances, Messages, Tasks
--   Gaming PC              + Inventory, Vehicles, Events
--   Executive Workstation  + Businesses (remote restock), Stocks, Properties
--   Empire Command Center  + Product Analytics, remote manager contracts
-- Computers are tools, not income machines: nothing here pays money.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

C.COMPUTERS = {
	{tier = 1, key = "pc1", name = "Basic Computer", icon = "🖥️", cost = 5000, apps = {"overview", "finances", "messages", "tasks"}},
	{tier = 2, key = "pc2", name = "Gaming PC", icon = "🎮", cost = 250000, apps = {"inventory", "vehicles", "events"}},
	{tier = 3, key = "pc3", name = "Executive Workstation", icon = "💼", cost = 5000000, apps = {"businesses", "stocks", "properties"}},
	{tier = 4, key = "pc4", name = "Empire Command Center", icon = "🛰️", cost = 100000000, apps = {"analytics"}},
}
C.COMPUTER_APPS = {
	{key = "overview", name = "Empire Overview", icon = "📊"}, {key = "finances", name = "Finances", icon = "💰"}, {key = "inventory", name = "Inventory", icon = "📦"},
	{key = "businesses", name = "Businesses", icon = "🏢"}, {key = "stocks", name = "Stocks", icon = "📈"}, {key = "vehicles", name = "Vehicles", icon = "🚗"},
	{key = "properties", name = "Properties", icon = "🏠"}, {key = "messages", name = "Messages", icon = "📨"}, {key = "tasks", name = "Tasks", icon = "📋"},
	{key = "events", name = "Events", icon = "📅"}, {key = "analytics", name = "Product Analytics", icon = "📈"},
}
local APP_TIER = {}
for _, pc in ipairs(C.COMPUTERS) do for _, a in ipairs(pc.apps) do APP_TIER[a] = pc.tier end end
C.COMPUTER_APP_TIER = APP_TIER

function F.computerTier(d) return type(d.computer) == "table" and math.clamp(tonumber(d.computer.tier) or 0, 0, #C.COMPUTERS) or 0 end
function F.buyComputer(plr, tier)
	local d = data[plr]
	local pc = C.COMPUTERS[tier]
	if not (d and pc) then return false end
	if F.computerTier(d) >= tier then notify(plr, "💻 You already have a " .. C.COMPUTERS[F.computerTier(d)].name .. ".") return false end
	if d.cash < pc.cost then notify(plr, "💻 A " .. pc.name .. " costs $" .. fmt(pc.cost) .. ".") return false end
	d.cash -= pc.cost
	d.computer = type(d.computer) == "table" and d.computer or {}
	local first = F.computerTier(d) == 0
	d.computer.tier = tier
	-- the first computer goes into your furniture, ready to place at home
	if first then
		d.furniture = type(d.furniture) == "table" and d.furniture or {}
		d.furniture.computer = (tonumber(d.furniture.computer) or 0) + 1
	end
	notify(plr, "💻 " .. pc.icon .. " " .. pc.name .. " bought!" .. (first and " Place it in your home (🛋️ Decorate → Furniture), then walk up and use it." or " Your computer was upgraded."))
	if F.homeRefresh then F.homeRefresh(plr) end
	return true
end

-- ===== access: only at a computer you own =====
local session = {}   -- [plr] = {at = os.clock(), where = "home" | "hq" | "wall"}
function F.computerOpen(plr)
	local s = session[plr]
	if not s or os.clock() - s.at > 900 then return false end
	local inside = plr:GetAttribute("Interior")
	local own = plr:GetAttribute("InteriorOwner") == plr.UserId
	if not own then return false end
	if s.where == "home" then return inside == "home" end
	if s.where == "hq" then return inside == "hq5" end
	if s.where == "wall" then return inside == "hq4" end
	return false
end
function F.openComputer(plr, where)
	local d = data[plr]
	if not d then return false end
	local inside = plr:GetAttribute("Interior")
	local own = plr:GetAttribute("InteriorOwner") == plr.UserId
	local okPlace = own and ((where == "home" and inside == "home") or (where == "hq" and inside == "hq5") or (where == "wall" and inside == "hq4"))
	if not okPlace then return false end
	local tier = F.computerTier(d)
	if where ~= "home" then tier = math.max(1, tier) end   -- the HQ has a computer of its own
	if tier <= 0 then
		notify(plr, "💻 You need a computer first (furniture shop → Tech).")
		return false
	end
	session[plr] = {at = os.clock(), where = where}
	R.Menu:FireClient(plr, "computer", F.computerData(plr, tier, where == "wall" and "overview" or nil))
	if F.guideTip then F.guideTip(plr, "useComputer") end
	return true
end
local function sessionTier(plr, d)
	local s = session[plr]
	local tier = F.computerTier(d)
	if s and s.where ~= "home" then tier = math.max(1, tier) end
	return tier
end
F.computerSessionTier = sessionTier

-- ===== what the apps show =====
function F.computerData(plr, tier, startApp)
	local d = data[plr]
	local now = os.clock()
	local inc, per = F.income(d, now)
	local out = {tier = tier, tierName = C.COMPUTERS[tier] and C.COMPUTERS[tier].name or "Computer", app = startApp, apps = {}}
	for _, a in ipairs(C.COMPUTER_APPS) do table.insert(out.apps, {key = a.key, name = a.name, icon = a.icon, need = APP_TIER[a.key], locked = APP_TIER[a.key] > tier}) end
	local function open(app) return APP_TIER[app] <= tier end
	-- overview
	local bizCount, cars = 0, 0
	for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then bizCount += 1 end end
	for _, c in ipairs(C.CARS) do if F.ownsCar(plr, c) then cars += 1 end end
	local propValue = 0
	for _, deed in ipairs(d.deeds or {}) do propValue += tonumber(deed.paid) or 0 end
	for _, b in ipairs(d.props or {}) do propValue += F.rentalValue(b) end
	out.overview = {name = plr.Name, cash = d.cash, income = F.incomePerSec(d), earned = d.earned, tier = C.REP_TIERS[F.tierIndex(d.rep)].name, rep = d.rep,
		businesses = bizCount, properties = F.propertiesUsed(d), capacity = F.propertyCapacity(d), cars = cars, carsTotal = #C.CARS, hq = F.hqLevel and F.hqLevel(d) or 0,
		viral = d.viral and d.viral.score or 0, followers = d.followers or 0, netWorth = d.cash + propValue, rebirths = d.rebirths}
	if open("finances") then
		local rows = {}
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 then table.insert(rows, {icon = b.icon, name = F.bizName(d, b.key), income = (per[b.key] or 0)}) end
		end
		local costs = {}
		for key, pr in pairs(d.problems or {}) do table.insert(costs, {text = "Repair at " .. F.bizName(d, key), amount = pr.repair}) end
		if F.managerLevel and F.managerLevel(d) > 0 then table.insert(costs, {text = "Manager contract", amount = F.contractCost(d)}) end
		for _, b in ipairs(d.props or {}) do table.insert(costs, {text = "Upkeep: " .. (C.RENTAL[b.type] and C.RENTAL[b.type].name or "building"), amount = F.rentalUpkeep(b)}) end
		out.finances = {cash = d.cash, income = F.incomePerSec(d), rows = rows, costs = costs, rent = d.rentEarned or 0}
	end
	if open("inventory") then
		local supplies, products = {}, {}
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 and F.stockOf then
				local s = F.stockOf(d, b.key)
				table.insert(supplies, {biz = F.bizName(d, b.key), icon = b.icon, items = {{C.SUPPLIES[b.key][1], math.floor(s[1])}, {C.SUPPLIES[b.key][2], math.floor(s[2])}, {C.SUPPLIES[b.key][3], math.floor(s[3])}}})
				for _, p in ipairs(F.productsOf(d, b.key)) do table.insert(products, {biz = F.bizName(d, b.key), name = p.name, sold = p.sold or 0}) end
			end
		end
		local furniture = {}
		for k, n in pairs(d.furniture or {}) do if (tonumber(n) or 0) > 0 then table.insert(furniture, {key = k, count = n}) end end
		local placed = type(d.homeBuild) == "table" and type(d.homeBuild.items) == "table" and #d.homeBuild.items or 0
		local relics = {}
		for k in pairs(d.found or {}) do table.insert(relics, tostring(k)) end
		local mods = 0
		for _, m in pairs(d.carMods or {}) do if type(m) == "table" then mods += 1 end end
		out.inventory = {supplies = supplies, products = products, furniture = furniture, placed = placed, collectibles = relics, vehicleItems = mods,
			special = {tickets = d.arcade and d.arcade.tickets or 0, mystery = d.mystery and #d.mystery or 0}}
	end
	if open("businesses") then
		local list = {}
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 then
				local s = F.stockOf and F.stockOf(d, b.key) or {100, 100, 100}
				table.insert(list, {key = b.key, icon = b.icon, name = F.bizName(d, b.key), level = d.levels[b.key], income = per[b.key] or 0, stock = math.floor(math.min(s[1], s[2], s[3])),
					restock = F.restockCost and F.restockCost(d, b.key, true) or 0, problem = d.problems[b.key] and C.PROBLEMS[d.problems[b.key].type].text or nil,
					products = F.productsOf and #F.productsOf(d, b.key) or 0})
			end
		end
		out.businesses = list
	end
	if open("vehicles") then
		local list = {}
		for _, c in ipairs(C.CARS) do if F.ownsCar(plr, c) then table.insert(list, {key = c.key, name = F.carName and F.carName(d, c.key) or c.name, class = c.class}) end end
		out.vehicles = list
	end
	if open("properties") then
		out.properties = {estate = F.estateState(plr, d), rentals = #(d.props or {}), home = d.home and d.home.level and C.HOME_LEVELS[d.home.level] or "No home",
			hood = F.homeHood(d) and C.HOOD[F.homeHood(d)].name or nil, hq = F.hqLevel and F.hqLevel(d) or 0}
	end
	out.messages = {unread = F.unreadCount and F.unreadCount(d) or 0}
	out.tasks = F.guideTasks and F.guideTasks(d) or {}
	if open("events") then
		local G = C.G
		local sight = {}
		for _, s in ipairs(C.influencerSightings or {}) do if s.active then table.insert(sight, s.icon .. " " .. s.name .. " at " .. s.place) end end
		out.events = {event = G and G.eventText or "Markets are calm.", mega = C.megaState and C.megaState() and C.megaState().text or nil, sightings = sight,
			beef = F.beefInfo and F.beefInfo(plr, d, now) and F.beefInfo(plr, d, now).text or nil, trending = d.trending and d.trending.untilT > now and d.trending.name or nil}
	end
	if open("analytics") then
		local list = {}
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 then
				for _, p in ipairs(F.productsOf(d, b.key)) do
					table.insert(list, {biz = F.bizName(d, b.key), name = p.name, sold = p.sold or 0, pop = math.floor(tonumber(p.pop) or 0), trend = math.floor(tonumber(p.trend) or 0),
						demand = math.floor(F.productDemand(p) * 100), price = math.floor((tonumber(p.price) or 1) * 100)})
				end
			end
		end
		table.sort(list, function(x, y) return x.sold > y.sold end)
		out.analytics = list
	end
	return out
end

-- ===== actions (all require being at your computer) =====
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.pcBuy = function(plr, d, a) local t = C.int(a, 1, #C.COMPUTERS) if t then F.buyComputer(plr, t) end end
C.ACTIONS.pcRefresh = function(plr, d, a)
	if not F.computerOpen(plr) then return end
	R.Menu:FireClient(plr, "computer", F.computerData(plr, sessionTier(plr, d), C.str(a, 16) and a or nil))
end
C.ACTIONS.pcRestock = function(plr, d, a)
	if not F.computerOpen(plr) or sessionTier(plr, d) < 3 then return end
	if C.str(a, 20) and BIZ[a] and F.restock then F.restock(plr, a, "remote") end
	R.Menu:FireClient(plr, "computer", F.computerData(plr, sessionTier(plr, d), "businesses"))
end
C.ACTIONS.pcManager = function(plr, d)
	if not F.computerOpen(plr) or sessionTier(plr, d) < 4 then return end
	if F.signContract then F.signContract(plr, false) end
end
C.ACTIONS.pcUse = function(plr, d, a)
	-- the computer in your home (a furniture item) asks for this through its prompt; the server checks where you are
	if a == "home" then F.openComputer(plr, "home") end
end
Players.PlayerRemoving:Connect(function(plr) session[plr] = nil end)
end
