-- REAL ESTATE (v10): the city's property market.
--
-- The city has 8 districts with a fixed number of plots each (~100 in total). Prime districts (Downtown, Waterfront,
-- Luxury Hills) are small on purpose; Midtown, the Suburbs and the Expansion district have plenty of room.
--
-- Ownership is a DEED, saved with the player: "a plot in Midtown, running my Pizza place". Every time you join, the
-- server places your deeds on free plots in their districts (your usual plot if it's free). Before v10 land was only
-- yours while you were in the server and could quietly vanish from your save if someone else held it when you came
-- back; a deed never vanishes. If a district is completely full in this server, the deed still counts and earns.
--
-- Limits keep it fair in a 4-player server:
--   * a property capacity that grows with your reputation tier (and a little with rebirths)
--   * a per-district cap per player (so one player can't buy a whole district)
--   * each extra plot in the same district costs 25% more
--
-- A plot runs one of your businesses (you choose which). Choosing a business you haven't opened yet opens it there;
-- choosing one you already run adds a new LOCATION of it, which raises that business's income (district bonus).
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local P, billboard = C.P, C.billboard
local fmt, notify = C.fmt, C.notify
local BIZ, DISTRICT, REP_TIERS, LOTS = C.BIZ, C.DISTRICT, C.REP_TIERS, C.LOTS
local SOLID = {CanCollide = true}
local WHITE = RGB(250, 250, 250)

-- ===== limits =====
C.ESTATE = {
	capacity = {1, 2, 4, 6, 9, 12},   -- properties (plots + rental buildings) by reputation tier
	rebirthPer = 10, rebirthMax = 4,  -- +1 capacity per 10 rebirths, up to +4
	priceStep = 1.25,                 -- each extra plot in the same district costs 25% more
	sellBack = 0.5,                   -- selling refunds half of what you paid
	maxLocationBonus = 0.8,           -- a business can get at most +80% income from its locations
	changeCooldown = 300,             -- seconds before a plot can switch to another business
}
local E = C.ESTATE

-- =====================================================================
-- THE MAP: new plots and new districts (lots 1-16 are the v5-v9 land lots, ids unchanged)
-- =====================================================================
local FOLDER = Instance.new("Folder")
FOLDER.Name = "RealEstate"
FOLDER.Parent = C.WORLD or Workspace
local PLOT = 22
local function addLot(dkey, x, z, yaw)
	local lot = {id = #LOTS + 1, dkey = dkey, pos = V3(x, 0, z), yaw = yaw or 0, size = PLOT}
	table.insert(LOTS, lot)
	C.reserve(x - PLOT / 2 - 2, z - PLOT / 2 - 2, x + PLOT / 2 + 2, z + PLOT / 2 + 2)
	return lot
end
-- the old lots get a facing too (their buildings face the district's middle)
for _, lot in ipairs(LOTS) do
	lot.size = lot.size or PLOT
	if lot.dkey == "downtown" or lot.dkey == "industrial" then lot.yaw = lot.pos.Z > 0 and math.pi or 0
	elseif lot.dkey == "beach" then lot.yaw = lot.pos.X > 0 and -math.pi / 2 or math.pi / 2
	else lot.yaw = math.pi end
end
local function slab(name, cx, cz, w, d, color, mat)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = FOLDER
	P(f, V3(w, 2, d), CF(cx, -0.85, cz), color, mat or MAT.Concrete, SOLID)
	C.reserve(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2)
	return f
end
-- Downtown, Industrial, Waterfront: a few more plots in the existing districts
for _, x in ipairs({175, 285}) do
	for _, z in ipairs({-105, 105}) do addLot("downtown", x, z, z > 0 and math.pi or 0) end
end
for _, x in ipairs({-175, -285}) do
	for _, z in ipairs({-105, 105}) do addLot("industrial", x, z, z > 0 and math.pi or 0) end
end
addLot("beach", 50, 230, -math.pi / 2)   -- (west of the avenue, z 225 is Maple Ln: no plot there)
-- Midtown: the big south-east business area (20 plots)
do
	local f = slab("Midtown", 510, 205, 270, 250, RGB(170, 168, 160))
	for _, x in ipairs({400, 455, 510, 565, 620}) do
		for i, z in ipairs({120, 175, 235, 290}) do addLot("midtown", x, z, (i % 2 == 1) and 0 or math.pi) end
	end
	C.gate(f, V3(352, 0, 205), true, "🏬 MIDTOWN", "Business plots • " .. REP_TIERS[DISTRICT.midtown.tier].name, DISTRICT.midtown.color)
	for _, z in ipairs({147, 262}) do P(f, V3(260, 0.12, 8), CF(510, 0.2, z), RGB(60, 62, 68), MAT.Asphalt) end
end
-- Entertainment District, next to the Fun Park, around the Fun Zone (15 plots)
do
	local f = slab("Entertainment", -480, -215, 290, 160, RGB(80, 70, 95))
	for _, x in ipairs({-605, -555, -505, -405, -360}) do
		for _, z in ipairs({-270, -215, -160}) do addLot("entertainment", x, z, x < -455 and -math.pi / 2 or math.pi / 2) end
	end
	C.gate(f, V3(-480, 0, -142), false, "🎪 ENTERTAINMENT DISTRICT", "Arcades, food & fun • " .. REP_TIERS[DISTRICT.entertainment.tier].name, DISTRICT.entertainment.color)
	for i = 0, 8 do P(f, V3(1, 0.3, 1), CF(-620 + i * 35, 0.3, -292), Color3.fromHSV(i / 9, 0.8, 1), MAT.Neon) end
	-- the Fun Zone pavilion stands in the middle (GameServer > FunZone builds it here)
	C.FUN_ZONE_AT = CF(-455, 0, -215)
	C.reserve(-480, -290, -430, -140)
end
-- Northside Suburbs, outside North Rd to the west (20 plots)
do
	local f = slab("Suburbs", -490, -478, 290, 250, RGB(150, 175, 140), MAT.Grass)
	for _, x in ipairs({-600, -545, -490, -435, -380}) do
		for i, z in ipairs({-560, -505, -450, -395}) do addLot("suburbs", x, z, (i % 2 == 1) and 0 or math.pi) end
	end
	C.gate(f, V3(-490, 0, -345), false, "🏘️ NORTHSIDE SUBURBS", "Cheap plots for new businesses", DISTRICT.suburbs.color)
end
-- Expansion District, outside North Rd to the east (20 plots, late game)
do
	local f = slab("Expansion", 470, -478, 290, 250, RGB(150, 150, 150), MAT.Asphalt)
	for _, x in ipairs({360, 415, 470, 525, 580}) do
		for i, z in ipairs({-560, -505, -450, -395}) do addLot("expansion", x, z, (i % 2 == 1) and 0 or math.pi) end
	end
	C.gate(f, V3(470, 0, -345), false, "🚧 EXPANSION DISTRICT", "Late-game land • " .. REP_TIERS[DISTRICT.expansion.tier].name, DISTRICT.expansion.color)
	for i = 0, 5 do
		local cone = P(f, V3(1.2, 2, 1.2), CF(340 + i * 50, 1, -350), RGB(255, 140, 30))
		cone.Shape = Enum.PartType.Cylinder
	end
end
C.DISTRICT_PLOTS = {}
for _, lot in ipairs(LOTS) do C.DISTRICT_PLOTS[lot.dkey] = (C.DISTRICT_PLOTS[lot.dkey] or 0) + 1 end

-- =====================================================================
-- RULES
-- =====================================================================
local function deedsIn(d, dkey)
	local n = 0
	for _, dd in ipairs(d.deeds or {}) do if dd.district == dkey then n += 1 end end
	return n
end
F.deedsIn = deedsIn
function F.propertyCapacity(d)
	local t = F.tierIndex(d.rep)
	return (E.capacity[t] or E.capacity[#E.capacity]) + math.min(E.rebirthMax, math.floor((d.rebirths or 0) / E.rebirthPer))
end
function F.propertiesUsed(d) return #(d.deeds or {}) + #(d.props or {}) end
function F.plotPrice(d, dkey)
	return math.floor(DISTRICT[dkey].cost * E.priceStep ^ deedsIn(d, dkey))
end
-- can this player buy this plot right now? (ok, reason)
function F.canBuyPlot(d, lot)
	local dd = DISTRICT[lot.dkey]
	if lot.owner then return false, "Owned by " .. lot.owner.Name end
	if F.tierIndex(d.rep) < dd.tier then return false, "Needs " .. REP_TIERS[dd.tier].name .. " reputation" end
	if F.propertiesUsed(d) >= F.propertyCapacity(d) then
		return false, "Property limit reached (" .. F.propertiesUsed(d) .. "/" .. F.propertyCapacity(d) .. "). Raise your reputation to own more."
	end
	if deedsIn(d, lot.dkey) >= dd.cap then return false, "You already own " .. dd.cap .. " plot" .. (dd.cap == 1 and "" or "s") .. " in " .. dd.name .. " (the limit per player)" end
	local price = F.plotPrice(d, lot.dkey)
	if d.cash < price then return false, "You need $" .. fmt(price) end
	return true, nil
end
-- how much a business earns extra from its locations around the city
function F.locationMult(d, key)
	local bonus = 0
	for _, dd in ipairs(d.deeds or {}) do
		if dd.biz == key then
			local dist = DISTRICT[dd.district]
			if dist then bonus += (dist.locFor and dist.locFor[key]) or dist.loc or 0 end
		end
	end
	return 1 + math.min(E.maxLocationBonus, bonus)
end
function F.deedById(d, id)
	for i, dd in ipairs(d.deeds or {}) do if dd.id == id then return dd, i end end
	return nil
end
local function lotOfDeed(plr, deed)
	local lot = deed.plot and LOTS[deed.plot]
	if lot and lot.owner == plr and lot.deed == deed then return lot end
	return nil
end
F.lotOfDeed = lotOfDeed
-- v14: the deed (and the placed plot, if any) a business runs on. Used for businesses that only exist on a city
-- plot (the Movie Theater).
function F.siteDeed(d, key)
	for _, dd in ipairs(d and d.deeds or {}) do if dd.biz == key then return dd end end
	return nil
end
function F.siteLot(plr, key)
	local d = plr and data[plr]
	if not d then return nil end
	for _, dd in ipairs(d.deeds or {}) do
		if dd.biz == key then
			local lot = lotOfDeed(plr, dd)
			if lot then return lot end
		end
	end
	return nil
end

-- =====================================================================
-- PLACING DEEDS (on join, and whenever plots free up)
-- =====================================================================
local function place(plr, d, deed, lot)
	lot.owner = plr
	lot.deed = deed
	deed.plot = lot.id
	d.lots[lot.id] = true
	F.buildLot(lot)
end
function F.placeDeeds(plr, d)
	local moved, waiting = 0, 0
	for _, deed in ipairs(d.deeds or {}) do
		if not lotOfDeed(plr, deed) then
			local pref = deed.plot and LOTS[deed.plot]
			local target
			if pref and pref.dkey == deed.district and not pref.owner then target = pref end
			if not target then
				for _, lot in ipairs(LOTS) do
					if lot.dkey == deed.district and not lot.owner then target = lot break end
				end
				if target and deed.plot then moved += 1 end
			end
			if target then place(plr, d, deed, target) else waiting += 1 end
		end
	end
	if moved > 0 then notify(plr, "🏙️ " .. moved .. " of your properties are on a different plot in this server (same district).") end
	if waiting > 0 then notify(plr, "🏙️ " .. waiting .. " of your properties are in a full district in this server. They still count and still earn.") end
end
-- someone left: their plots are free again, so anyone waiting for one gets it
function F.releaseDeeds(plr)
	for _, lot in ipairs(LOTS) do
		if lot.owner == plr then
			lot.owner = nil
			lot.deed = nil
			F.buildLot(lot)
		end
	end
	for p, od in pairs(data) do
		if p ~= plr then pcall(F.placeDeeds, p, od) end
	end
end

-- =====================================================================
-- BUY / CHOOSE BUSINESS / SELL
-- =====================================================================
function F.buyPlot(plr, lot)
	local d = data[plr]
	if not (d and lot) then return nil end
	local ok, why = F.canBuyPlot(d, lot)
	if not ok then
		notify(plr, "🏙️ " .. why)
		return nil
	end
	local dist = DISTRICT[lot.dkey]
	local price = F.plotPrice(d, lot.dkey)
	d.cash -= price
	d.deedSeq = (tonumber(d.deedSeq) or #d.deeds) + 1
	local deed = {id = "d" .. d.deedSeq, district = lot.dkey, plot = lot.id, paid = price, bought = os.time()}
	table.insert(d.deeds, deed)
	place(plr, d, deed, lot)
	F.addRep(plr, 10)
	C.burst(lot.pos + V3(0, 8, 0), dist.color, 100)
	F.buzz(dist.icon, plr.Name .. " bought a plot in " .. dist.name .. "! (" .. F.propertiesUsed(d) .. " properties)", dist.color)
	if F.guideTip then F.guideTip(plr, "claimProperty") end
	R.Menu:FireClient(plr, "chooseBiz", F.plotInfo(plr, lot))
	return deed
end
-- choose (or change) what a plot runs. A business you haven't opened yet is opened here (and paid for).
local changedAt = {}
function F.setDeedBiz(plr, deedId, key)
	local d = data[plr]
	local deed = d and F.deedById(d, deedId)
	local b = BIZ[key]
	if not (deed and b) then return false end
	if deed.biz == key then return true end
	if not F.bizUnlocked(d, key) then
		notify(plr, "🔒 " .. b.name .. " unlocks at " .. REP_TIERS[b.unlock].name .. " reputation.")
		return false
	end
	local now = os.clock()
	if deed.biz and changedAt[deed] and now - changedAt[deed] < E.changeCooldown then
		notify(plr, "🏙️ You just changed this plot. Try again in " .. math.ceil(E.changeCooldown - (now - changedAt[deed])) .. "s.")
		return false
	end
	local opening = (d.levels[key] or 0) <= 0
	if opening then
		local cost = F.upgradeCost(d, key)
		if d.cash < cost then
			notify(plr, "🏙️ Opening a " .. b.name .. " costs $" .. fmt(cost) .. ".")
			return false
		end
		-- (the plot is chosen first, so a business that needs a plot (the Movie Theater) opens right here)
		local was = deed.biz
		deed.biz = key
		F.buyUpgrade(plr, d, key)
		if (d.levels[key] or 0) <= 0 then
			deed.biz = was
			return false
		end
	end
	deed.biz = key
	changedAt[deed] = now
	local lot = lotOfDeed(plr, deed)
	if lot then F.buildLot(lot) end
	if F.refreshDoors then F.refreshDoors(plr) end
	local name = F.bizName and F.bizName(d, key) or b.name
	notify(plr, "🏪 " .. name .. (opening and " is open for business" or " has a new location") .. " in " .. DISTRICT[deed.district].name .. "!")
	if F.guideTip then F.guideTip(plr, "chooseBusiness") end
	return true
end
function F.sellDeed(plr, deedId)
	local d = data[plr]
	if not d then return false end
	local deed, i = F.deedById(d, deedId)   -- (both values: "d and F.deedById(...)" would drop the index)
	if not (deed and i) then return false end
	local lot = lotOfDeed(plr, deed)
	local refund = math.floor((tonumber(deed.paid) or DISTRICT[deed.district].cost) * E.sellBack)
	table.remove(d.deeds, i)
	d.cash += refund
	if lot then
		lot.owner = nil
		lot.deed = nil
		d.lots[lot.id] = nil
		F.buildLot(lot)
	end
	notify(plr, "💼 Sold your " .. DISTRICT[deed.district].name .. " plot for $" .. fmt(refund) .. ".")
	if F.viralMoment then F.viralMoment(plr, "lostKeys", {}) end
	for p, od in pairs(data) do if p ~= plr then pcall(F.placeDeeds, p, od) end end
	return true
end

-- =====================================================================
-- THE PLOT CARD (what a player sees when they look at a plot)
-- =====================================================================
function F.plotInfo(plr, lot)
	local d = data[plr]
	local dist = DISTRICT[lot.dkey]
	local info = {lot = lot.id, district = dist.name, icon = dist.icon, kind = dist.kind, stars = dist.stars, blurb = dist.blurb, color = dist.color,
		boost = dist.boostText, income = dist.income, tierName = REP_TIERS[dist.tier].name}
	if lot.owner then
		local od = data[lot.owner]
		local deed = lot.deed
		info.owner = lot.owner.Name
		info.ownerId = lot.owner.UserId
		info.mine = lot.owner == plr
		info.deed = deed and deed.id
		if deed and deed.biz and od then
			info.biz = deed.biz
			info.bizName = F.bizName and F.bizName(od, deed.biz) or BIZ[deed.biz].name
			info.level = od.levels[deed.biz] or 0
		end
		if info.mine then
			info.sellFor = math.floor((tonumber(deed and deed.paid) or dist.cost) * E.sellBack)
			info.options = F.bizOptions(d)
		end
	elseif d then
		info.price = F.plotPrice(d, lot.dkey)
		local ok, why = F.canBuyPlot(d, lot)
		info.canBuy, info.reason = ok, why
		info.used, info.capacity = F.propertiesUsed(d), F.propertyCapacity(d)
		info.mineHere, info.cap = deedsIn(d, lot.dkey), dist.cap
		local free = 0
		for _, l in ipairs(LOTS) do if l.dkey == lot.dkey and not l.owner then free += 1 end end
		info.free, info.total = free, C.DISTRICT_PLOTS[lot.dkey]
	end
	return info
end
-- the businesses a player can put on a plot (open ones become a new location; new ones cost their opening price)
function F.bizOptions(d)
	local out = {}
	for _, b in ipairs(C.BUSINESSES) do
		local lvl = d.levels[b.key] or 0
		table.insert(out, {key = b.key, name = b.name, icon = b.icon, level = lvl, locked = not F.bizUnlocked(d, b.key), need = REP_TIERS[b.unlock].name,
			cost = lvl <= 0 and F.upgradeCost(d, b.key) or 0, brand = F.bizName and lvl > 0 and F.bizName(d, b.key) or nil})
	end
	return out
end

-- =====================================================================
-- WHAT A PLOT LOOKS LIKE
-- =====================================================================
local function stars(n) return string.rep("★", n) .. string.rep("☆", 5 - n) end
function F.buildLot(lot)
	if lot.folder then
		-- (a plot-only business's building is also its owner's "slot": forget it there)
		local ref = lot.slotRef
		if ref and ref.plot.slots[ref.key] == lot.folder then ref.plot.slots[ref.key] = nil end
		lot.slotRef = nil
		lot.folder:Destroy()
	end
	local dist = DISTRICT[lot.dkey]
	local f = Instance.new("Model")
	f.Name = "Plot" .. lot.id
	f.Parent = FOLDER
	lot.folder = f
	local o = CF(lot.pos) * CFrame.Angles(0, lot.yaw or 0, 0)
	local size = lot.size or PLOT
	local owner = lot.owner and data[lot.owner]
	local base = P(f, V3(size, 2.4, size), o * CF(0, -0.65, 0), owner and owner.plot.color:Lerp(RGB(60, 60, 60), 0.4) or RGB(150, 150, 150), MAT.Concrete, SOLID)
	f.PrimaryPart = base
	P(f, V3(size + 0.4, 0.3, 0.6), o * CF(0, 0.6, size / 2), dist.color, MAT.SmoothPlastic)
	if not owner then
		for _, sx in ipairs({-size / 2 + 0.6, size / 2 - 0.6}) do
			for _, sz in ipairs({-size / 2 + 0.6, size / 2 - 0.6}) do P(f, V3(0.4, 1.5, 0.4), o * CF(sx, 1.2, sz), WHITE) end
		end
		P(f, V3(0.4, 5, 0.4), o * CF(0, 2.5, size / 2 - 3), RGB(110, 80, 50), MAT.Wood)
		local sign = P(f, V3(6, 3.5, 0.3), o * CF(0, 5.5, size / 2 - 3), RGB(245, 245, 245), MAT.SmoothPlastic, {Name = "Sign"})
		billboard(sign, UDim2.fromOffset(230, 104), V3(0, 4.4, 0), {
			{text = "PROPERTY FOR SALE", h = 0.24, color = RGB(255, 90, 90)},
			{text = dist.icon .. " " .. dist.name, h = 0.2, color = dist.color},
			{text = dist.kind .. "  •  " .. stars(dist.stars), h = 0.18, color = RGB(255, 220, 120), font = Enum.Font.GothamBold},
			{text = "From $" .. fmt(dist.cost), h = 0.2, color = RGB(120, 255, 150)},
			{text = "Needs " .. REP_TIERS[dist.tier].name, h = 0.18, font = Enum.Font.GothamBold}}, 110)
		C.prompt(sign, "View Property", dist.name .. " Plot", 14, 0, function(plr)
			if data[plr] then R.Menu:FireClient(plr, "plot", F.plotInfo(plr, lot)) end
		end)
		return
	end
	local deed = lot.deed
	local key = deed and deed.biz
	local top = 6
	if key and (owner.levels[key] or 0) > 0 and C.bizBuilders then
		local b = F.brandedBiz and F.brandedBiz(owner, key) or BIZ[key]
		local stage = C.stageOf(owner.levels[key], owner.chains[key] or 0)
		local accent = F.brandAccent and F.brandAccent(owner, key) or F.accentFor(lot.owner)
		local ok, res = pcall(function()
			if stage == 1 then return C.bizBuilders.stand(f, o, b, accent) end
			return C.bizBuilders.shop(f, o, b, stage, accent)
		end)
		if ok and type(res) == "number" then top = res end
		if BIZ[key].lotOnly then
			-- v14: this plot IS the business (the Movie Theater): it's the owner's slot for it, and its counter runs here
			owner.plot.slots[key] = f
			lot.slotRef = {plot = owner.plot, key = key}
			f:SetAttribute("Top", top)
			local plr = lot.owner
			if C.RECIPES and C.RECIPES[key] then
				local spot = P(f, V3(1, 1, 1), o * CF(3, 3, size / 2 - 3), WHITE, MAT.SmoothPlastic, {Transparency = 1, Name = "Counter"})
				C.prompt(spot, "🍳 Rush orders", BIZ[key].name, 14, 0.2, function(who)
					if who == plr then F.cookStart(plr, key) else notify(who, "🍳 Only the owner runs this counter.") end
				end)
			end
			if key == "theater" then
				local box = P(f, V3(1, 1, 1), o * CF(-3, 3, size / 2 - 3), WHITE, MAT.SmoothPlastic, {Transparency = 1, Name = "BoxOffice"})
				C.prompt(box, "🎬 Programme", BIZ[key].name, 14, 0, function(who)
					if who == plr then
						R.Menu:FireClient(plr, "openTheater")
					else
						local film = F.theaterFilm and F.theaterFilm(owner)
						notify(who, "🎬 Now showing at " .. plr.Name .. "'s theater: " .. (film and (film.icon .. " " .. film.title) or "coming soon") .. ". Step inside!")
					end
				end)
				if F.theaterMarquee then F.theaterMarquee(plr, owner) end
			end
			if owner.problems and owner.problems[key] and F.problemVisual then task.defer(F.problemVisual, plr, key, true) end
		end
	else
		-- owned but vacant: a fenced construction site waiting for a business
		for _, sx in ipairs({-size / 2 + 1, size / 2 - 1}) do P(f, V3(0.3, 2, size - 2), o * CF(sx, 1.4, 0), RGB(240, 150, 40)) end
		P(f, V3(size - 2, 2, 0.3), o * CF(0, 1.4, -size / 2 + 1), RGB(240, 150, 40))
		P(f, V3(3, 3, 3), o * CF(-4, 1.9, -3), RGB(200, 160, 100), MAT.Cardboard)
	end
	local name = key and (F.bizName and F.bizName(owner, key) or BIZ[key].name) or "Vacant plot"
	billboard(base, UDim2.fromOffset(260, 76), V3(0, top + 4, 0), {
		{text = string.upper(name), h = 0.42},
		{text = (key and (BIZ[key].icon .. " Lv " .. (owner.levels[key] or 0) .. "  •  ") or "") .. dist.icon .. " " .. dist.name, h = 0.3, color = dist.color, font = Enum.Font.GothamBold},
		{text = "Owned by " .. lot.owner.Name, h = 0.28, color = RGB(220, 220, 230), font = Enum.Font.GothamBold}}, 220)
	local hub = P(f, V3(1, 1, 1), o * CF(0, 3, size / 2 - 1), WHITE, MAT.SmoothPlastic, {Transparency = 1})
	C.prompt(hub, "View", name, 14, 0, function(plr)
		if data[plr] then R.Menu:FireClient(plr, "plot", F.plotInfo(plr, lot)) end
	end)
	if key then
		C.prompt(hub, "Enter", name, 10, 0.3, function(plr)
			if F.enterInterior then F.enterInterior(plr, lot.owner, key) end
		end)
	end
end

-- =====================================================================
-- STATE (Properties app / computer) + ACTIONS
-- =====================================================================
function F.estateState(plr, d)
	local deeds = {}
	for _, deed in ipairs(d.deeds or {}) do
		local dist = DISTRICT[deed.district]
		local lot = lotOfDeed(plr, deed)
		table.insert(deeds, {id = deed.id, district = dist and dist.name or deed.district, icon = dist and dist.icon or "🏙️", biz = deed.biz,
			bizName = deed.biz and (F.bizName and F.bizName(d, deed.biz) or BIZ[deed.biz].name) or nil, placed = lot ~= nil,
			at = lot and {lot.pos.X, lot.pos.Z} or nil, lot = lot and lot.id or nil})
	end
	local districts = {}
	for _, dist in ipairs(C.DISTRICTS) do
		local free, total = 0, 0
		for _, l in ipairs(LOTS) do
			if l.dkey == dist.key then
				total += 1
				if not l.owner then free += 1 end
			end
		end
		table.insert(districts, {key = dist.key, name = dist.name, icon = dist.icon, color = dist.color, unlocked = F.tierIndex(d.rep) >= dist.tier, tierName = REP_TIERS[dist.tier].name,
			price = F.plotPrice(d, dist.key), income = dist.income, boost = dist.boostText, kind = dist.kind, stars = dist.stars, mine = deedsIn(d, dist.key), cap = dist.cap,
			free = free, total = total, blurb = dist.blurb})
	end
	return {deeds = deeds, districts = districts, used = F.propertiesUsed(d), capacity = F.propertyCapacity(d)}
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.plotView = function(plr, d, a)
	local lot = LOTS[C.int(a, 1, #LOTS) or 0]
	if lot then R.Menu:FireClient(plr, "plot", F.plotInfo(plr, lot)) end
end
C.ACTIONS.plotBuy = function(plr, d, a)
	local lot = LOTS[C.int(a, 1, #LOTS) or 0]
	if lot then F.buyPlot(plr, lot) end
end
C.ACTIONS.plotBiz = function(plr, d, a, b)
	if C.str(a, 12) and C.str(b, 20) then F.setDeedBiz(plr, a, b) end
end
C.ACTIONS.plotSell = function(plr, d, a, b)
	-- selling needs the confirm flag from the client's confirmation dialog
	if C.str(a, 12) and b == true then F.sellDeed(plr, a) end
end
C.ACTIONS.plotGo = function(plr, d, a)
	local deed = C.str(a, 12) and F.deedById(d, a)
	local lot = deed and lotOfDeed(plr, deed)
	local char = plr.Character
	if lot and char then
		F.despawnCar(plr)
		char:PivotTo(CF(lot.pos) * CFrame.Angles(0, lot.yaw or 0, 0) * CF(0, 4, (lot.size or PLOT) / 2 + 6))
	end
end
-- visit another player's business (the owner's visitor setting is checked when you step inside)
C.ACTIONS.visitBiz = function(plr, d, a, b)
	local owner = C.int(a, 1) and Players:GetPlayerByUserId(a)
	if owner and data[owner] and C.str(b, 20) and BIZ[b] and F.enterInterior then F.enterInterior(plr, owner, b) end
end
-- the businesses this player runs on plots, with where (for doors and the map)
function F.plotLocations(plr, d)
	local out = {}
	for _, deed in ipairs(d.deeds or {}) do
		local lot = lotOfDeed(plr, deed)
		if lot and deed.biz then table.insert(out, {lot = lot, key = deed.biz}) end
	end
	return out
end
end
