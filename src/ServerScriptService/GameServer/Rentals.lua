-- RENTALS: property management company. Buy apartment buildings, pick tenants, deal with the drama.
return function(C)
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, ball, cyl, ghost, billboard, surfaceText, smoke, burst, shockwave =
	C.P, C.ball, C.cyl, C.ghost, C.billboard, C.surfaceText, C.smoke, C.burst, C.shockwave
local RENTALS, RENTAL, TENANT, REP_TIERS, fmt, notify = C.RENTALS, C.RENTAL, C.TENANT, C.REP_TIERS, C.fmt, C.notify
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 250), RGB(35, 35, 40)

local FOLDER = Instance.new("Folder")
FOLDER.Name = "RentalRow"
FOLDER.Parent = C.WORLD
C.RENT_LOTS = {}
for _, x in ipairs({380, 450, 520}) do
	for _, z in ipairs({-50, 50}) do
		table.insert(C.RENT_LOTS, {id = #C.RENT_LOTS + 1, pos = V3(x, 0, z), yaw = z < 0 and 0 or math.pi})
		C.reserve(x - 20, z - 20, x + 20, z + 20)
	end
end
C.gate(FOLDER, V3(350, 0, 0), true, "🏢 RENTAL ROW", "Property Management • " .. REP_TIERS[C.FEATURES.properties].name, RGB(120, 170, 255))
P(FOLDER, V3(230, 2, 150), CF(455, -0.85, 0), RGB(190, 190, 196), MAT.Concrete, SOLID)

local function unitName(i) return math.ceil(i / 2) .. (i % 2 == 1 and "A" or "B") end
C.unitName = unitName
function F.rentPerUnit(typeKey) return math.floor(RENTAL[typeKey].cost * 0.006) end

-- ===== building visuals =====
function F.buildRental(lot)
	if not lot then return end
	if lot.folder then lot.folder:Destroy() end
	local f = Instance.new("Model")
	f.Name = "Rental" .. lot.id
	f.Parent = FOLDER
	lot.folder = f
	local o = CF(lot.pos) * CFrame.Angles(0, lot.yaw, 0)
	P(f, V3(40, 2.4, 40), o * CF(0, -0.8, 0), RGB(170, 170, 175), MAT.Concrete, SOLID)
	local b = lot.owner and lot.prop
	if not b then
		P(f, V3(0.4, 5, 0.4), o * CF(0, 2.5, 16), RGB(110, 80, 50), MAT.Wood)
		local sign = P(f, V3(7, 3.4, 0.3), o * CF(0, 5.4, 16), WHITE)
		billboard(sign, UDim2.fromOffset(220, 80), V3(0, 3.8, 0), {
			{text = "🏢 BUILDING SITE", h = 0.38, color = RGB(120, 190, 255)}, {text = "From $" .. fmt(RENTALS[1].cost), h = 0.34, color = RGB(120, 255, 150)},
			{text = "Needs " .. REP_TIERS[C.FEATURES.properties].name, h = 0.28, font = Enum.Font.GothamBold}}, 100)
		C.prompt(sign, "Build Apartments", "Rental Row", 14, 0.3, function(plr)
			local d = data[plr]
			if d then R.Menu:FireClient(plr, "open", "properties", lot.id) end
		end)
		for _, sx in ipairs({-18, 18}) do P(f, V3(0.3, 1.5, 36), o * CF(sx, 1, 0), RGB(240, 150, 40)) end
		return
	end
	local T = RENTAL[b.type]
	local w, d, fh = b.type == "walkup" and 18 or 24, 14, 7
	local h = T.floors * fh
	local mat = b.type == "walkup" and MAT.Brick or (b.type == "tower" and MAT.Glass or MAT.SmoothPlastic)
	local body = P(f, V3(w, h, d), o * CF(0, 0.4 + h / 2, -4), T.color, mat, SOLID)
	if b.type == "tower" then body.Reflectance = 0.25 end
	for fl = 1, T.floors do
		local y = 0.4 + (fl - 1) * fh + fh * 0.55
		P(f, V3(w + 0.3, 0.4, d + 0.3), o * CF(0, 0.4 + fl * fh, -4), WHITE)
		for side = 1, 2 do
			local ui = (fl - 1) * 2 + side
			local occupied = b.units[ui] and true or false
			local x = side == 1 and -w * 0.25 or w * 0.25
			for _, dx in ipairs({-w * 0.09, w * 0.09}) do
				P(f, V3(w * 0.14 + 0.3, fh * 0.52, 0.2), o * CF(x + dx, y, -4 + d / 2 + 0.05), WHITE)
				P(f, V3(w * 0.14, fh * 0.48, 0.15), o * CF(x + dx, y, -4 + d / 2 + 0.12), occupied and RGB(255, 222, 150) or RGB(60, 70, 85), occupied and MAT.Neon or MAT.Glass, {Transparency = occupied and 0.35 or 0.05})
			end
			if b.type ~= "walkup" and fl > 1 then
				P(f, V3(w * 0.36, 0.3, 2), o * CF(x, 0.4 + (fl - 1) * fh + 0.2, -4 + d / 2 + 1), RGB(200, 200, 205), MAT.Concrete)
				P(f, V3(w * 0.36, 1.2, 0.15), o * CF(x, 0.4 + (fl - 1) * fh + 0.9, -4 + d / 2 + 2), RGB(170, 210, 240), MAT.Glass, {Transparency = 0.4})
			end
		end
	end
	if b.type == "walkup" then
		for fl = 1, T.floors do
			P(f, V3(0.2, 0.2, 4), o * CF(w / 2 + 2, 0.4 + fl * fh - 1, -4), DARK, MAT.Metal)
			P(f, V3(3, 0.2, 5), o * CF(w / 2 + 1.5, 0.4 + fl * fh - 1.2, -4), DARK, MAT.DiamondPlate)
		end
		cyl(f, 3, 3, o * CF(-w * 0.25, h + 1.9, -6), RGB(150, 110, 80), MAT.WoodPlanks)
	elseif b.type == "tower" then
		P(f, V3(w * 0.7, 4, d * 0.7), o * CF(0, h + 2.4, -4), T.color, MAT.Glass, {Reflectance = 0.3})
		P(f, V3(w * 0.72, 0.4, d * 0.72), o * CF(0, h + 4.6, -4), RGB(255, 205, 80), MAT.Neon)
	end
	for k = 0, 1 do P(f, V3(2.4, 1.6, 2.4), o * CF(-w * 0.3 + k * 3.2, h + 1.2, -8), RGB(200, 200, 205), MAT.Metal) end
	-- entrance + company sign
	P(f, V3(4, 5, 0.3), o * CF(0, 2.9, -4 + d / 2 + 0.1), RGB(150, 200, 240), MAT.Glass, {Transparency = 0.3})
	P(f, V3(7, 0.4, 3), o * CF(0, 5.6, -4 + d / 2 + 1.5), DARK, MAT.Metal)
	local sign = P(f, V3(12, 1.6, 0.3), o * CF(0, 6.8, -4 + d / 2 + 0.2), RGB(30, 40, 70))
	surfaceText(sign, Enum.NormalId.Back, lot.owner.Name .. " Property Co.", RGB(255, 220, 120))
	if b.condition < 50 then
		for k = 1, 4 do ball(f, V3(1.4, 1.4, 1.2), o * CF(-w / 2 + k * 1.6, 1.1, -4 + d / 2 + 3), RGB(30, 30, 30), MAT.Plastic) end
		smoke(ghost(f, o * CF(w * 0.3, h + 1, -4)), true, 3)
	end
	local occ = 0
	for i = 1, T.units do
		if b.units[i] then occ += 1 end
	end
	billboard(body, UDim2.fromOffset(240, 60), V3(0, h / 2 + 6, 0), {
		{text = "🏢 " .. T.name, h = 0.5}, {text = occ .. "/" .. T.units .. " rented • Condition " .. math.floor(b.condition) .. "%", h = 0.5, color = b.condition < 50 and RGB(255, 120, 100) or RGB(140, 255, 170), font = Enum.Font.GothamBold}}, 200)
	local door = ghost(f, o * CF(0, 3, -4 + d / 2 + 2))
	C.prompt(door, "Manage Building", T.name, 12, 0.2, function(plr)
		if plr == lot.owner then R.Menu:FireClient(plr, "open", "properties") end
	end)
end
for _, lot in ipairs(C.RENT_LOTS) do F.buildRental(lot) end

-- ===== tenants =====
local rnd = Random.new()
local function pick(t) return t[rnd:NextInteger(1, #t)] end
function F.newApplicant()
	local trait = rnd:NextInteger(1, #TENANT.traits)
	local credit = rnd:NextInteger(1, 5)
	return {name = pick(TENANT.first) .. " " .. pick(TENANT.last), job = pick(TENANT.jobs), trait = trait, credit = credit,
		emoji = pick({"🧑", "👩", "👨", "🧔", "👵", "👴", "🧑‍🦰", "👱"}), strikes = 0}
end
local function story(t, unit)
	local first = string.match(t.name, "^(%S+)")
	return first .. " in Unit " .. unit .. " " .. pick(TENANT.acts) .. " " .. pick(TENANT.objects) .. " " .. pick(TENANT.whens) .. ". " .. pick(TENANT.results)
end

local function propByLot(d, lotId)
	for i, b in ipairs(d.props) do
		if b.lot == lotId then return b, i end
	end
end
function F.propBuy(plr, lotId, typeKey)
	local d = data[plr]
	local lot = C.RENT_LOTS[lotId]
	local T = RENTAL[typeKey]
	if not (d and lot and T) then return end
	if not F.unlocked(d, "properties") then
		notify(plr, "🔒 Property Management unlocks at " .. REP_TIERS[C.FEATURES.properties].name)
		return
	end
	if lot.owner then
		notify(plr, "That lot is taken.")
		return
	end
	if d.cash < T.cost then
		notify(plr, "You need $" .. fmt(T.cost) .. " for a " .. T.name .. ".")
		return
	end
	d.cash -= T.cost
	local b = {lot = lotId, type = typeKey, units = {}, condition = 100, applicants = {}, events = {}}
	for i = 1, T.units do b.units[i] = false end
	table.insert(d.props, b)
	lot.owner = plr
	lot.prop = b
	F.buildRental(lot)
	burst(lot.pos + V3(0, 14, 0), RGB(120, 190, 255), 120)
	shockwave(lot.pos + V3(0, 0.6, 0), RGB(120, 190, 255), 40)
	R.Splash:FireClient(plr, "🏢 " .. T.name .. " BUILT!", "Applicants will start showing up soon. Choose wisely...", RGB(120, 190, 255))
	F.buzz("🏢", plr.Name .. " Property Co. just opened a " .. T.name .. " on Rental Row!", RGB(120, 190, 255))
	for _ = 1, 2 do table.insert(b.applicants, F.newApplicant()) end
end
function F.tenantAccept(plr, bi, ai)
	local d = data[plr]
	local b = d and d.props[bi]
	local a = b and b.applicants[ai]
	if not a then return end
	for i = 1, #b.units do
		if not b.units[i] then
			a.since = os.time()
			b.units[i] = a
			table.remove(b.applicants, ai)
			notify(plr, "🔑 " .. a.name .. " moved into Unit " .. unitName(i) .. "!")
			F.buildRental(C.RENT_LOTS[b.lot])
			return
		end
	end
	notify(plr, "No vacant units! Evict someone first.")
end
function F.tenantReject(plr, bi, ai)
	local d = data[plr]
	local b = d and d.props[bi]
	if b and b.applicants[ai] then table.remove(b.applicants, ai) end
end
function F.evict(plr, bi, ui, reason)
	local d = data[plr]
	local b = d and d.props[bi]
	local t = b and b.units[ui]
	if not t then return end
	b.units[ui] = false
	notify(plr, "🚪 " .. t.name .. " was evicted from Unit " .. unitName(ui) .. "." .. (reason or ""))
	F.buildRental(C.RENT_LOTS[b.lot])
end
function F.renovate(plr, bi)
	local d = data[plr]
	local b = d and d.props[bi]
	if not b then return end
	local cost = math.floor(RENTAL[b.type].cost * 0.08)
	if d.cash < cost then
		notify(plr, "Renovation costs $" .. fmt(cost))
		return
	end
	d.cash -= cost
	b.condition = 100
	notify(plr, "🛠️ Building renovated! Condition back to 100%.")
	F.buildRental(C.RENT_LOTS[b.lot])
end
function F.sellProp(plr, bi)
	local d = data[plr]
	local b = d and d.props[bi]
	if not b then return end
	local refund = math.floor(RENTAL[b.type].cost * 0.5)
	d.cash += refund
	local lot = C.RENT_LOTS[b.lot]
	if lot and lot.owner == plr then
		lot.owner = nil
		lot.prop = nil
		F.buildRental(lot)
	end
	table.remove(d.props, bi)
	notify(plr, "💼 Sold the building for $" .. fmt(refund))
end

-- inbox choices for tenant drama
function F.tenantChoice(plr, msg, choice)
	local d = data[plr]
	if not d then return "" end
	local b = d.props[msg.ref and msg.ref.b or 0]
	local ui = msg.ref and msg.ref.u
	local t = b and b.units[ui]
	if not t or t.name ~= msg.ref.name then return "They don't live there anymore." end
	local first = string.match(t.name, "^(%S+)")
	if choice == 1 then
		t.strikes = (t.strikes or 0) + 1
		if t.strikes >= 3 then
			b.units[ui] = false
			F.buildRental(C.RENT_LOTS[b.lot])
			return "⚠️ That was strike 3. " .. first .. " packed up and left in the middle of the night."
		end
		return "😐 " .. first .. " promises to behave. (Strike " .. t.strikes .. "/3.) They probably won't."
	elseif choice == 2 then
		local fine = F.rentPerUnit(b.type) * 2
		d.cash += fine
		if rnd:NextNumber() < 0.25 then
			b.units[ui] = false
			F.buildRental(C.RENT_LOTS[b.lot])
			return "💸 You collected a $" .. fmt(fine) .. " fine... and " .. first .. " moved out in protest."
		end
		return "💸 " .. first .. " paid a $" .. fmt(fine) .. " fine and is sulking loudly."
	else
		b.units[ui] = false
		F.buildRental(C.RENT_LOTS[b.lot])
		return "🚪 " .. first .. " has been evicted. The neighbors threw a small party."
	end
end

-- ===== simulation (called from the main loop every second) =====
local timers = {}
function F.rentalTick(plr, d, now)
	local tm = timers[plr]
	if not tm then
		tm = {rent = now + C.CFG.RENT_INTERVAL, apps = {}, events = {}}
		timers[plr] = tm
	end
	if #d.props == 0 then return end
	-- rent
	if now >= tm.rent then
		tm.rent = now + C.CFG.RENT_INTERVAL
		local total, late = 0, nil
		for bi, b in ipairs(d.props) do
			local per = F.rentPerUnit(b.type)
			for ui = 1, #b.units do
				local t = b.units[ui]
				if t then
					if rnd:NextNumber() < (5 - t.credit) * 0.035 then
						late = late or {bi = bi, ui = ui, t = t}
					else
						total += per * (0.75 + t.credit * 0.07) * (0.5 + b.condition / 200)
					end
				end
			end
			b.condition = math.max(10, b.condition - 0.4)
		end
		total = math.floor(total * F.globalRentMult(d))
		if total > 0 then
			d.cash += total
			d.earned += total
			d.rentEarned = (d.rentEarned or 0) + total
			R.Customer:FireClient(plr, {rent = total})
		end
		if late and rnd:NextNumber() < 0.5 then
			F.pushMsg(plr, {icon = "💸", from = late.t.name, text = late.t.name .. " " .. pick(TENANT.late)})
		end
	end
	for bi, b in ipairs(d.props) do
		local key = b.lot
		-- applicants for vacant units
		local vacant = 0
		for ui = 1, #b.units do
			if not b.units[ui] then vacant += 1 end
		end
		tm.apps[key] = tm.apps[key] or (now + rnd:NextNumber(20, 40))
		if now >= tm.apps[key] then
			tm.apps[key] = now + rnd:NextNumber(30, 55)
			if vacant > 0 and #b.applicants < 3 then
				local a = F.newApplicant()
				table.insert(b.applicants, a)
				F.pushMsg(plr, {icon = "📬", from = RENTAL[b.type].name, text = "New rental application from " .. a.name .. " (" .. a.job .. ", " .. TENANT.traits[a.trait].icon .. " " .. TENANT.traits[a.trait].name .. "). Open the Properties app to review."})
			end
		end
		-- tenant drama
		tm.events[key] = tm.events[key] or (now + rnd:NextNumber(45, 80))
		if now >= tm.events[key] then
			tm.events[key] = now + rnd:NextNumber(55, 110)
			local occupied = {}
			for ui = 1, #b.units do
				if b.units[ui] then table.insert(occupied, ui) end
			end
			if #occupied > 0 then
				local ui = occupied[rnd:NextInteger(1, #occupied)]
				local t = b.units[ui]
				local badChance = 0.3 + (5 - t.credit) * 0.08 + TENANT.traits[t.trait].bad
				if rnd:NextNumber() < badChance then
					b.condition = math.max(10, b.condition - 6)
					F.pushMsg(plr, {icon = "🚨", from = RENTAL[b.type].name .. " • Unit " .. unitName(ui), text = story(t, unitName(ui)),
						choices = {"😐 Warn", "💸 Fine $" .. fmt(F.rentPerUnit(b.type) * 2), "🚪 Evict"}, kind = "tenant", ref = {b = bi, u = ui, name = t.name}})
					F.buildRental(C.RENT_LOTS[b.lot])
				else
					local first = string.match(t.name, "^(%S+)")
					local good = pick(TENANT.good)
					if string.find(good, "rent") then
						d.cash += F.rentPerUnit(b.type) * 3
					elseif string.find(good, "elevator") or string.find(good, "clean") then
						b.condition = math.min(100, b.condition + 10)
					else
						F.addRep(plr, 2)
					end
					F.pushMsg(plr, {icon = "💚", from = RENTAL[b.type].name .. " • Unit " .. unitName(ui), text = first .. " " .. good})
				end
			end
		end
	end
end
function F.clearRentalTimers(plr) timers[plr] = nil end

function F.claimRentals(plr, d)
	for _, b in ipairs(d.props) do
		local lot = C.RENT_LOTS[b.lot]
		if not lot or lot.owner then
			lot = nil
			for _, l in ipairs(C.RENT_LOTS) do
				if not l.owner then
					lot = l
					break
				end
			end
		end
		if lot then
			b.lot = lot.id
			lot.owner = plr
			lot.prop = b
			F.buildRental(lot)
		else
			b.lot = 0
		end
		b.applicants = b.applicants or {}
		b.events = {}
	end
end
function F.releaseRentals(plr)
	for _, lot in ipairs(C.RENT_LOTS) do
		if lot.owner == plr then
			lot.owner = nil
			lot.prop = nil
			F.buildRental(lot)
		end
	end
end
C.propByLot = propByLot
end
