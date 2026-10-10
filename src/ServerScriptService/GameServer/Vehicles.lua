-- VEHICLES (v14): every car has a ROLE (from its class) and can be TUNED.
--   ROLES, each with one real effect, only while you're actually driving that car:
--     🛵 Commuter (Economy)   tuning costs half
--     🚚 Hauler (Trucks)      +25% City Job pay when you finish the job at the wheel
--     🕶️ Getaway (SUVs)       if the police catch you in it, the fine is halved
--     🏁 Racer (Sports, Supercar, Hypercar)   +15% race prizes
--     🎩 VIP (Luxury)         +10% reputation gains
--   TUNING: Engine (top speed), Turbo (acceleration), Suspension (handling), Brakes. 5 levels each, small steps
--     (at most +10% top speed), bought here with cash and checked here. The server writes the tuned numbers on
--     the car's seat when it spawns; the driving controller only reads them. Paint and parts stay looks-only.
return function(C)
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local CAR = C.CAR

local VR = {
	roles = {
		commuter = {icon = "🛵", name = "Commuter", text = "Tuning costs half"},
		hauler = {icon = "🚚", name = "Hauler", text = "+25% City Job pay when you finish at the wheel", jobs = 1.25},
		getaway = {icon = "🕶️", name = "Getaway", text = "Police fines halved if they catch you in it", fine = 0.5},
		racer = {icon = "🏁", name = "Racer", text = "+15% race prizes", race = 1.15},
		vip = {icon = "🎩", name = "VIP", text = "+10% reputation gains while driving", rep = 1.1},
	},
	byClass = {Economy = "commuter", Truck = "hauler", SUV = "getaway", Sports = "racer", Supercar = "racer", Hypercar = "racer", Luxury = "vip"},
	parts = {
		{key = "engine", name = "Engine", icon = "⚙️", what = "top speed", per = 0.02, attr = "MaxSpeed"},
		{key = "turbo", name = "Turbo", icon = "💨", what = "acceleration", per = 0.04, attr = "Accel"},
		{key = "handling", name = "Suspension", icon = "🛞", what = "handling", per = 0.03, attr = "Turn"},
		{key = "brakes", name = "Brakes", icon = "🛑", what = "braking", per = 0.05, attr = "Brake"},
	},
	maxLevel = 5, costShare = 0.03, costMin = 500, passPrice = 2000000,
}
C.VEHICLES = VR
local PART = {}
for _, p in ipairs(VR.parts) do PART[p.key] = p end

function F.vehicleRole(spec)
	local key = spec and VR.byClass[spec.class]
	return key, key and VR.roles[key] or nil
end
-- the role of the car this player is driving right now (nil on foot)
function F.drivingRole(plr)
	local car = F.activeCar and F.activeCar(plr)
	if not (car and car.seat and car.key) then return nil end
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not hum or car.seat.Occupant ~= hum then return nil end
	local key, role = F.vehicleRole(CAR[car.key])
	return key, role
end
-- multiplier for a reward kind ("jobs", "race", "fine", "rep") from the car being driven
function F.vehicleBonus(plr, kind)
	local _, role = F.drivingRole(plr)
	return role and role[kind] or 1
end

local function tunes(d)
	d.tune = type(d.tune) == "table" and d.tune or {}
	return d.tune
end
function F.tuneLevel(d, carKey, part)
	local t = tunes(d)[carKey]
	return type(t) == "table" and math.clamp(math.floor(tonumber(t[part]) or 0), 0, VR.maxLevel) or 0
end
function F.tuneMult(d, carKey, part)
	local p = PART[part]
	return p and (1 + p.per * F.tuneLevel(d, carKey, part)) or 1
end
function F.tuneCost(spec, lvl)
	local base = spec.price or VR.passPrice
	local c = math.max(VR.costMin, math.floor(base * VR.costShare * (lvl + 1)))
	if VR.byClass[spec.class] == "commuter" then c = math.floor(c / 2) end
	return c
end
function F.tuneCar(plr, carKey, part)
	local d = data[plr]
	local spec = type(carKey) == "string" and CAR[carKey]
	local p = type(part) == "string" and PART[part]
	if not (d and spec and p) then return false end
	if not F.ownsCar(plr, spec) then notify(plr, "🔧 You don't own that car.") return false end
	local lvl = F.tuneLevel(d, carKey, part)
	if lvl >= VR.maxLevel then notify(plr, "🔧 " .. p.name .. " is fully tuned.") return false end
	local cost = F.tuneCost(spec, lvl)
	if d.cash < cost then notify(plr, "🔧 " .. p.name .. " level " .. (lvl + 1) .. " costs $" .. fmt(cost) .. ".") return false end
	d.cash -= cost
	local t = tunes(d)
	t[carKey] = type(t[carKey]) == "table" and t[carKey] or {}
	t[carKey][part] = lvl + 1
	notify(plr, "🔧 " .. p.icon .. " " .. p.name .. " level " .. (lvl + 1) .. ": +" .. math.floor(p.per * (lvl + 1) * 100 + 0.5) .. "% " .. p.what .. " (-$" .. fmt(cost) .. ")")
	-- the car you're standing next to gets it now; the one you're driving the next time you take it out
	local active = F.activeCar(plr)
	if active and active.key == carKey then
		if active.seat.Occupant then
			notify(plr, "🚗 You'll feel it the next time you take the car out.")
		else
			local cf = active.root.CFrame
			F.spawnCar(plr, carKey, cf * CFrame.new(0, -(spec.clear + (spec.H + 0.8) / 2), 0))
		end
	end
	return true
end
-- the seat numbers for a freshly spawned car (Cars.spawnCar calls this)
function F.applyTuning(plr, seat, carKey)
	local d = data[plr]
	if not d then return end
	for _, p in ipairs(VR.parts) do
		local v = seat:GetAttribute(p.attr)
		if type(v) == "number" then seat:SetAttribute(p.attr, v * F.tuneMult(d, carKey, p.key)) end
	end
	local key = F.vehicleRole(CAR[carKey])
	seat:SetAttribute("Role", key or "")
end
function F.tuneInfo(d, spec)
	local out = {}
	for _, p in ipairs(VR.parts) do
		local lvl = F.tuneLevel(d, spec.key, p.key)
		table.insert(out, {key = p.key, name = p.name, icon = p.icon, what = p.what, level = lvl, max = VR.maxLevel,
			bonus = math.floor(p.per * lvl * 100 + 0.5), cost = lvl < VR.maxLevel and F.tuneCost(spec, lvl) or nil})
	end
	return out
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.carTune = function(plr, d, a, b)
	if F.tuneCar(plr, a, b) and F.sendGarage then F.sendGarage(plr) end
end
end
