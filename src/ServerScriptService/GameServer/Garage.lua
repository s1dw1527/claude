-- GARAGE (v10): your cars. Equip (your default ride), favorite, rename (filtered), customize, sell, stats.
-- Customization is cosmetic (paint, wheels, window tint, interior, plate, decals, spoilers, bumpers, exhaust):
-- it never changes speed, so nobody pays to win races. Every change is validated and paid for here.
return function(C)
local F, data, R = C.F, C.data, C.R
local RGB, MAT = Color3.fromRGB, Enum.Material
local fmt, notify = C.fmt, C.notify
local CARS, CAR = C.CARS, C.CAR

C.CAR_CLASSES = {"Economy", "Sports", "Luxury", "SUV", "Truck", "Supercar", "Hypercar"}
-- prices scale a little with the car (5% of its price, at least the listed cost) so a hypercar wrap costs more
C.CAR_MODS = {
	paint = {
		{key = "red", name = "Racing Red", color = RGB(210, 30, 40), cost = 2000}, {key = "blue", name = "Deep Blue", color = RGB(30, 70, 200), cost = 2000},
		{key = "white", name = "Pearl White", color = RGB(245, 245, 248), cost = 2000}, {key = "black", name = "Midnight Black", color = RGB(18, 18, 22), cost = 2000},
		{key = "lime", name = "Lime Pop", color = RGB(150, 230, 40), cost = 3000}, {key = "orange", name = "Sunset Orange", color = RGB(255, 120, 30), cost = 3000},
		{key = "purple", name = "Royal Purple", color = RGB(120, 50, 200), cost = 3000}, {key = "pink", name = "Bubblegum", color = RGB(255, 120, 190), cost = 3000},
		{key = "teal", name = "Lagoon Teal", color = RGB(30, 180, 170), cost = 3000}, {key = "silver", name = "Liquid Silver", color = RGB(190, 195, 205), cost = 5000},
		{key = "gold", name = "24K Wrap", color = RGB(255, 200, 60), mat = MAT.Foil, cost = 250000}, {key = "neonwrap", name = "Neon Wrap", color = RGB(60, 255, 200), mat = MAT.Neon, cost = 500000},
	},
	wheels = {
		{key = "black", name = "Gloss Black Rims", color = RGB(25, 25, 28), cost = 1500}, {key = "chrome", name = "Mirror Chrome", color = RGB(235, 238, 245), cost = 3000},
		{key = "bronze", name = "Bronze Rims", color = RGB(170, 110, 50), cost = 4000}, {key = "red", name = "Red Rims", color = RGB(220, 40, 40), cost = 4000},
		{key = "gold", name = "Gold Rims", color = RGB(255, 205, 60), cost = 50000},
	},
	tint = {
		{key = "light", name = "Light Tint", color = RGB(40, 50, 60), transparency = 0.35, cost = 800}, {key = "dark", name = "Dark Tint", color = RGB(15, 15, 20), transparency = 0.15, cost = 1500},
		{key = "limo", name = "Limo Black", color = RGB(5, 5, 8), transparency = 0.05, cost = 3000}, {key = "blue", name = "Blue Mirror", color = RGB(40, 80, 160), transparency = 0.2, cost = 3000},
	},
	interior = {
		{key = "tan", name = "Tan Leather", color = RGB(190, 150, 100), cost = 2000}, {key = "red", name = "Red Leather", color = RGB(170, 30, 40), cost = 3000},
		{key = "white", name = "White Leather", color = RGB(235, 235, 230), cost = 3000}, {key = "carbon", name = "Carbon Sport", color = RGB(30, 30, 34), cost = 5000},
	},
	decal = {
		{key = "stripes", name = "Racing Stripes", color = RGB(250, 250, 250), cost = 2500}, {key = "flames", name = "Flames", cost = 6000},
		{key = "number", name = "Race Number", cost = 2000}, {key = "checker", name = "Checker Flag", cost = 3000},
	},
	spoiler = {
		{key = "none", name = "No Spoiler", cost = 0}, {key = "lip", name = "Lip Spoiler", cost = 2000}, {key = "wing", name = "Street Wing", cost = 6000}, {key = "gt", name = "GT Wing", cost = 15000},
	},
	bumper = {{key = "sport", name = "Sport Bumpers", cost = 4000}, {key = "offroad", name = "Off-road Bars", cost = 6000}},
	exhaust = {
		{key = "dual", name = "Dual Exhaust", pipes = {-0.3, 0.3}, cost = 2000}, {key = "quad", name = "Quad Exhaust", pipes = {-0.36, -0.24, 0.24, 0.36}, size = 0.36, cost = 5000},
		{key = "center", name = "Center Exit", pipes = {0}, size = 0.6, cost = 4000}, {key = "neon", name = "Neon Tips", pipes = {-0.3, 0.3}, color = RGB(80, 200, 255), neon = true, cost = 12000},
	},
}
local MOD_BY = {}
for kind, list in pairs(C.CAR_MODS) do
	MOD_BY[kind] = {}
	for _, o in ipairs(list) do MOD_BY[kind][o.key] = o end
end

local function garage(d)
	d.garage = type(d.garage) == "table" and d.garage or {}
	local g = d.garage
	g.fav = type(g.fav) == "table" and g.fav or {}
	g.names = type(g.names) == "table" and g.names or {}
	d.carMods = type(d.carMods) == "table" and d.carMods or {}
	return g
end
function F.carName(d, key)
	local g = garage(d)
	local n = g.names[key]
	return type(n) == "string" and n ~= "" and n or (CAR[key] and CAR[key].name or key)
end
-- stats on a 1-10 scale for the garage cards
function F.carStats(spec)
	local function s(v, lo, hi) return math.clamp(math.floor(1 + 9 * (v - lo) / (hi - lo) + 0.5), 1, 10) end
	return {speed = s(spec.speed, 40, 132), accel = s(spec.accel or 1, 0.7, 1.5), handling = s(spec.turn, 1.7, 2.9), braking = s(spec.brake or 1, 0.75, 1.4),
		grip = s(spec.grip or 6, 4.5, 7.5), drift = s(spec.drift or 1, 0.5, 1.4), nitro = s(spec.nitro or 1.4, 1.25, 1.55)}
end
function F.ownedCarCount(plr)
	local n = 0
	for _, c in ipairs(CARS) do if F.ownsCar(plr, c) then n += 1 end end
	return n
end
function F.modCost(spec, opt)
	if opt.cost <= 0 then return 0 end
	return math.max(opt.cost, math.floor((spec.price or 1000000) * 0.02))
end
function F.garageInfo(plr)
	local d = data[plr]
	local g = garage(d)
	local list = {}
	local active = F.activeCar(plr)
	for i, c in ipairs(CARS) do
		local owned = F.ownsCar(plr, c)
		table.insert(list, {key = c.key, name = F.carName(d, c.key), model = c.name, class = c.class, price = c.price or 0, pass = c.pass, rebirths = c.rebirths, owned = owned,
			fav = g.fav[c.key] == true, equipped = g.equipped == c.key, active = active ~= nil and active.key == c.key, stats = F.carStats(c), speed = c.speed, color = c.color,
			delivery = c.delivery, mods = owned and d.carMods[c.key] or nil, sellFor = (owned and not c.pass and not c.rebirths) and math.floor((c.price or 0) * 0.5) or nil, order = i,
			role = F.vehicleRole and select(2, F.vehicleRole(c)) or nil, tune = owned and F.tuneInfo and F.tuneInfo(d, c) or nil})
	end
	-- favorites first, then owned, then the rest in showroom order
	table.sort(list, function(x, y)
		if x.fav ~= y.fav then return x.fav end
		if x.owned ~= y.owned then return x.owned end
		return x.order < y.order
	end)
	local mods = {}
	for kind, opts in pairs(C.CAR_MODS) do
		mods[kind] = {}
		for _, o in ipairs(opts) do table.insert(mods[kind], {key = o.key, name = o.name, cost = o.cost, color = o.color}) end
	end
	return {owned = F.ownedCarCount(plr), total = #CARS, cars = list, mods = mods, classes = C.CAR_CLASSES}
end
local function send(plr) R.Menu:FireClient(plr, "garage", F.garageInfo(plr)) end
F.sendGarage = send

function F.equipCar(plr, key)
	local d = data[plr]
	local spec = CAR[key]
	if not (d and spec and F.ownsCar(plr, spec)) then return false end
	garage(d).equipped = key
	notify(plr, "🔑 " .. F.carName(d, key) .. " is your main ride now.")
	return true
end
function F.favCar(plr, key)
	local d = data[plr]
	if not (d and CAR[key] and F.ownsCar(plr, CAR[key])) then return false end
	local g = garage(d)
	g.fav[key] = (not g.fav[key]) or nil
	return true
end
function F.renameCar(plr, key, text)
	local d = data[plr]
	local spec = CAR[key]
	if not (d and spec and F.ownsCar(plr, spec)) then return false end
	if text == "" then
		garage(d).names[key] = nil
		notify(plr, "🚗 Name reset to " .. spec.name .. ".")
		return true
	end
	local name, why = C.filterText(plr, text, 2, 20)
	if not name then
		notify(plr, "🚗 " .. tostring(why))
		return false
	end
	garage(d).names[key] = name
	notify(plr, "🚗 Your " .. spec.name .. " is now called \"" .. name .. "\".")
	return true
end
function F.customizeCar(plr, key, kind, value)
	local d = data[plr]
	local spec = CAR[key]
	if not (d and spec and F.ownsCar(plr, spec)) then return false end
	garage(d)
	d.carMods[key] = type(d.carMods[key]) == "table" and d.carMods[key] or {}
	local mods = d.carMods[key]
	if kind == "plate" then
		if value == "" then mods.plate = nil
		else
			local text, why = C.filterText(plr, value, 1, 7)
			if not text then notify(plr, "🔤 " .. tostring(why)) return false end
			if d.cash < 500 then notify(plr, "🔤 A custom plate costs $500.") return false end
			d.cash -= 500
			mods.plate = string.upper(text)
		end
	elseif kind == "number" then
		local n = C.int(value, 0, 99)
		if not n then return false end
		mods.number = n
	elseif MOD_BY[kind] then
		if value == "stock" then
			mods[kind] = nil   -- back to factory: free, no refund
		else
			local opt = MOD_BY[kind][value]
			if not opt then return false end
			if mods[kind] == value then return false end
			local cost = F.modCost(spec, opt)
			if d.cash < cost then notify(plr, "🎨 " .. opt.name .. " costs $" .. fmt(cost) .. ".") return false end
			d.cash -= cost
			mods[kind] = value
			notify(plr, "🎨 " .. opt.name .. (cost > 0 and (" (-$" .. fmt(cost) .. ")") or ""))
		end
	else
		return false
	end
	if next(mods) == nil then d.carMods[key] = nil end
	-- the car you're driving updates right away
	local active = F.activeCar(plr)
	if active and active.key == key then
		if active.seat.Occupant then
			notify(plr, "🚗 You'll see it the next time you take the car out.")
		else
			local cf = active.root.CFrame
			F.spawnCar(plr, key, cf * CFrame.new(0, -(spec.clear + (spec.H + 0.8) / 2), 0))
		end
	end
	return true
end
function F.sellCar(plr, key)
	local d = data[plr]
	local spec = CAR[key]
	if not (d and spec) or spec.pass or spec.rebirths or d.cars[key] ~= true then return false end
	local active = F.activeCar(plr)
	if active and active.key == key then F.despawnCar(plr) end
	local back = math.floor((spec.price or 0) * 0.5)
	d.cars[key] = nil
	local g = garage(d)
	g.fav[key], g.names[key] = nil, nil
	if g.equipped == key then g.equipped = nil end
	d.carMods[key] = nil
	d.cash += back
	notify(plr, "💰 Sold the " .. spec.name .. " for $" .. fmt(back) .. ".")
	return true
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.garageInfo = function(plr) send(plr) end
C.ACTIONS.carEquip = function(plr, d, a) if C.str(a, 16) then F.equipCar(plr, a) end send(plr) end
C.ACTIONS.carFav = function(plr, d, a) if C.str(a, 16) then F.favCar(plr, a) end send(plr) end
C.ACTIONS.carName = function(plr, d, a, b) if C.str(a, 16) and C.str(b, 60) then F.renameCar(plr, a, b) end send(plr) end
C.ACTIONS.carMod = function(plr, d, a, b, c)
	if C.str(a, 16) and C.str(b, 12) and (C.str(c, 24) or C.int(c, 0, 99)) then F.customizeCar(plr, a, b, c) end
	send(plr)
end
C.ACTIONS.carSell = function(plr, d, a, b)
	-- b must be true: the client only sends it from the confirmation dialog
	if C.str(a, 16) and b == true then F.sellCar(plr, a) end
	send(plr)
end
C.ACTIONS.carDrive = function(plr, d, a)
	local key = C.str(a, 16) and a or garage(d).equipped
	if key and CAR[key] and F.ownsCar(plr, CAR[key]) then
		if not F.unlocked(d, "cars") then return end
		F.spawnCar(plr, key)
	end
end
end
