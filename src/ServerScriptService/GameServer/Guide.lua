-- GUIDE (v10): the tutorial keeps up with the game. After the 7 opening steps, 18 contextual tips appear the first
-- time you reach each new system (never twice, at most one every 20 seconds, and they can be switched off in
-- Settings). Every big window has a "What's this?" button that shows the help text below, and the computer's
-- Tasks app lists what to try next.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R

C.GUIDE_TIPS = {
	{key = "welcomeV10", icon = "🆕", title = "Corner Empire v10", text = "New: buy property plots around the city, name and brand your businesses, build an HQ, design your house, 16 cars and a Fun Zone with 2-player games. Tips will show up as you go."},
	{key = "claimProperty", icon = "🏙️", title = "Property", text = "You own this plot for good — it stays yours on every server. How many you can own grows with your reputation (and rebirths)."},
	{key = "chooseBusiness", icon = "🏪", title = "Choose a business", text = "Each plot runs one business. A new location of a business you already own adds its district bonus to that business."},
	{key = "nameBusiness", icon = "🏷️", title = "Name it", text = "Your business needs a name! It shows on the sign, the map and CityBuzz. The first rename is free."},
	{key = "createProduct", icon = "🍽️", title = "Products", text = "Price, quality and presentation decide demand. Cheap and great sells more; too pricey and customers walk away."},
	{key = "restock", icon = "📦", title = "Supplies", text = "Customers use up supplies. Below 20% sales drop (to 75% when empty) — restock at the business (🏪 Manage → Supplies), or remotely from an Executive computer."},
	{key = "brand", icon = "🎨", title = "Your brand", text = "Pick a logo, colours, uniforms and a menu style in 🏪 Manage → Brand. It's all over your buildings and staff."},
	{key = "buildHQ", icon = "🏢", title = "Your HQ", text = "Your Empire Tower can become a real HQ. Build the Reception floor from the 🏛️ HQ app, then walk in through the tower door."},
	{key = "visitHQ", icon = "🛎️", title = "Welcome to your HQ", text = "Each floor adds rooms. The elevator moves you between floors; the Management floor unlocks the General Manager."},
	{key = "hireManager", icon = "📋", title = "General Manager", text = "Your manager fixes problems and restocks while a contract runs (15-60 minutes). Repairs take time and cost the normal price. Contracts expire — renew them yourself."},
	{key = "useComputer", icon = "💻", title = "Your computer", text = "Check your empire from your desk. Better computers unlock more apps: Inventory, Businesses (remote restock), Product Analytics..."},
	{key = "furniture", icon = "🛋️", title = "Furniture", text = "Bought furniture waits in storage. Go inside your home and press 🔨 Build to place it on the grid."},
	{key = "homeBuilder", icon = "🔨", title = "Home builder", text = "Tap 🔨 Build to place furniture, change the room layout, ceiling, door and windows. Bigger houses hold more items."},
	{key = "visitors", icon = "🔐", title = "Who can visit", text = "Your house, businesses and HQ can be Public, Friends only, Invite only or Private (Home app → 🔐 Visitors)."},
	{key = "garage", icon = "🚗", title = "Your garage", text = "Phone → Garage: drive, favorite, rename and customize your cars. Every car has its own speed, handling, braking and drift."},
	{key = "customizeCar", icon = "🎨", title = "Customize", text = "Paint, wheels, tint, plates, decals, spoilers, bumpers and exhausts. Looks only: speed never changes, so races stay fair."},
	{key = "funZone", icon = "🕹️", title = "Fun Zone", text = "2-player games! Stand at a booth and ask someone to join: Reaction Duel, Button Battle, Hoop Duel and Kart Sprint. Winners earn tickets."},
	{key = "arcadePrize", icon = "🎟️", title = "Tickets", text = "You have enough tickets for a prize! Trade them at the Fun Zone prize counter for furniture."},
}
C.GUIDE_TIP = {}
for i, t in ipairs(C.GUIDE_TIPS) do
	t.n = i
	C.GUIDE_TIP[t.key] = t
end
-- "What's this?" texts (the client shows them from the catalog)
C.GUIDE_HELP = {
	property = {title = "🏙️ Property plots", text = "Plots are permanent: once bought, a plot is yours on every server and comes back when you join. Prime districts (Downtown, Waterfront, Luxury) have few plots and a low per-player cap, so everyone gets a chance; Midtown, Suburbs and Expansion have plenty. You can own more properties as your reputation grows (+1 per 10 rebirths). Selling returns half of what you paid."},
	chooseBusiness = {title = "🏪 Choosing a business", text = "A plot runs one business type. If you already own that business, the plot becomes another location of it: your income from that business gets the district's bonus (capped). You can change the business later."},
	products = {title = "🍽️ Products, supplies and brand", text = "More product slots unlock at business levels 1, 3, 5, 7 and 10. Demand depends on price, quality, presentation, popularity and ingredients; a trending product brings extra customers for a while. Supplies run down as you sell: keep them above 20%. Brand choices are cosmetic."},
	hq = {title = "🏢 HQ", text = "Six floors: Reception, Management (unlocks the General Manager), Finance, Executive (Empire Wall), Private Office (your computer and safe) and the Rooftop. Floors are built in order. Visitors need permission (HQ is Friends-only by default)."},
	manager = {title = "📋 General Manager", text = "Hire a Manager in the Staff app, build the Management floor, then sign a contract. While it runs (only while you play) the manager repairs problems (90 s at level 1, 45 s at level 5), restocks low supplies and, at level 3+, handles several at once. Level 5 also handles outages, theft and road works. Auto-renew only works while you're active, twice in a row."},
	computer = {title = "💻 Computer", text = "Basic: overview, finances, messages, tasks. Gaming PC: inventory, vehicles, events. Executive Workstation: businesses with remote restock, stocks, properties. Empire Command Center: product analytics and remote manager contracts. Computers never pay money."},
	furniture = {title = "🛋️ Furniture shop", text = "9 categories. Bought items go to storage; place them inside your home with 🔨 Build. Selling an item back returns 40%. Some items need a bigger house."},
	builder = {title = "🔨 Home builder", text = "Tap an item in storage, then a cell on the plan. Items can't block the doorway, stand on walls or overlap (rugs can go under things). Tap a placed item to move, rotate or pick it up. House styles: layout, ceiling, door and windows — once bought, a style is free to switch back to."},
	garage = {title = "🚗 Garage", text = "OWNED shows how many of the 16 cars you have. Equip sets your main ride; favorites go to the top. Selling returns half the price (game-pass and rebirth cars can't be sold)."},
	carCustom = {title = "🎨 Customizing cars", text = "Everything here is cosmetic. Changes show the next time the car spawns (or right away if it's parked)."},
	arcade = {title = "🕹️ Arcade", text = "Two real players, decided by the server. Win = 12 tickets, play = 3. Against the same opponent only 5 games per 10 minutes pay, and 30 games per hour in total. Leaving or walking away forfeits. Tickets buy furniture, never cash."},
}

local function guide(d)
	d.guide = type(d.guide) == "table" and d.guide or {}
	local g = d.guide
	g.seen = type(g.seen) == "table" and g.seen or {}
	return g
end
local lastTip = {}   -- [plr] = os.clock()
local queue = {}     -- [plr] = {key...}
local function show(plr, key)
	local t = C.GUIDE_TIP[key]
	if not t then return end
	R.Menu:FireClient(plr, "guideTip", {key = key, icon = t.icon, title = t.title, text = t.text, n = t.n, total = #C.GUIDE_TIPS})
	lastTip[plr] = os.clock()
end
function F.guideTip(plr, key)
	local d = plr and data[plr]
	if not (d and key and C.GUIDE_TIP[key]) then return false end
	local g = guide(d)
	if g.seen[key] or g.off then return false end
	if (d.tut or 0) > 0 and key ~= "nameBusiness" then return false end   -- the opening tutorial comes first
	g.seen[key] = true
	if lastTip[plr] and os.clock() - lastTip[plr] < 20 then
		queue[plr] = queue[plr] or {}
		table.insert(queue[plr], key)
	else
		show(plr, key)
	end
	return true
end
function F.guideReset(plr)
	local d = data[plr]
	if d then guide(d).seen = {} guide(d).off = nil end
end

-- the computer's Tasks app: what to try next
function F.guideTasks(d)
	local cars = 0
	for _, c in ipairs(C.CARS) do if d.cars and d.cars[c.key] then cars += 1 end end
	local named, products = false, false
	for _, b in ipairs(C.BUSINESSES) do
		if F.hasBizName and F.hasBizName(d, b.key) then named = true end
		local list = d.products and d.products[b.key]
		if type(list) == "table" and #list > 1 then products = true end
	end
	local placed = type(d.homeBuild) == "table" and type(d.homeBuild.items) == "table" and #d.homeBuild.items or 0
	local mgr = type(d.mgr) == "table" and (tonumber(d.mgr.handled) or 0) > 0
	return {
		{text = "Own a property plot", done = #(d.deeds or {}) > 0},
		{text = "Give a business its own name", done = named},
		{text = "Create a second product", done = products},
		{text = "Build your HQ's Reception floor", done = F.hqLevel and F.hqLevel(d) >= 1},
		{text = "Let a General Manager fix something", done = mgr},
		{text = "Buy a computer", done = F.computerTier and F.computerTier(d) > 0},
		{text = "Place 5 pieces of furniture at home", done = placed >= 5},
		{text = "Own 3 cars", done = cars >= 3},
		{text = "Win a 2-player arcade game", done = type(d.arcade) == "table" and (tonumber(d.arcade.wins) or 0) > 0},
		{text = "Reach the Empire Estate (house tier 7)", done = d.home and (d.home.level or 0) >= 7},
	}
end
C.guideCatalog = function()
	local tips = {}
	for _, t in ipairs(C.GUIDE_TIPS) do table.insert(tips, {key = t.key, icon = t.icon, title = t.title}) end
	return {help = C.GUIDE_HELP, tips = tips}
end

-- tips that follow what you're doing (checked every few seconds; cheap)
task.spawn(function()
	while true do
		task.wait(4)
		local now = os.clock()
		for plr, d in pairs(data) do
			local ok, err = pcall(function()
				-- queued tips (one every 20 s)
				local q = queue[plr]
				if q and #q > 0 and (not lastTip[plr] or now - lastTip[plr] >= 20) then show(plr, table.remove(q, 1)) end
				if (d.tut or 0) > 0 then return end
				local g = guide(d)
				if g.off then return end
				local seen = g.seen
				if not seen.welcomeV10 then F.guideTip(plr, "welcomeV10") return end
				if not seen.restock and F.stockOf then
					for _, b in ipairs(C.BUSINESSES) do
						if (d.levels[b.key] or 0) > 0 then
							local s = F.stockOf(d, b.key)
							if math.min(s[1], s[2], s[3]) < 20 then F.guideTip(plr, "restock") break end
						end
					end
				end
				if not seen.brand and (d.levels.lemonade or 0) >= 5 then F.guideTip(plr, "brand") end
				if not seen.buildHQ and F.tierIndex(d.rep) >= C.FEATURES.tower and F.hqLevel and F.hqLevel(d) == 0 then F.guideTip(plr, "buildHQ") end
				if not seen.homeBuilder and plr:GetAttribute("Interior") == "home" and plr:GetAttribute("InteriorOwner") == plr.UserId then F.guideTip(plr, "homeBuilder") end
				if not seen.visitors and seen.homeBuilder and #(d.deeds or {}) > 0 then F.guideTip(plr, "visitors") end
				if not seen.garage then
					for _, c in ipairs(C.CARS) do if d.cars and d.cars[c.key] then F.guideTip(plr, "garage") break end end
				end
				if not seen.customizeCar and seen.garage and F.activeCar and F.activeCar(plr) then F.guideTip(plr, "customizeCar") end
				if not seen.funZone and C.FUN_ZONE_AT then
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - C.FUN_ZONE_AT.Position).Magnitude < 90 then F.guideTip(plr, "funZone") end
				end
				if not seen.arcadePrize and type(d.arcade) == "table" and (tonumber(d.arcade.tickets) or 0) >= 40 then F.guideTip(plr, "arcadePrize") end
			end)
			if not ok then warn("[CornerEmpire] guide: " .. tostring(err)) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) lastTip[plr], queue[plr] = nil, nil end)

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.guideOff = function(plr, d, a)
	guide(d).off = a == true or nil
	C.notify(plr, a == true and "💡 Tips switched off. (Settings → Tips to turn them back on.)" or "💡 Tips are on.")
end
C.ACTIONS.guideReset = function(plr)
	F.guideReset(plr)
	C.notify(plr, "💡 All tips will show again.")
end
end
