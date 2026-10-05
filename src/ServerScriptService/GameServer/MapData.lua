-- MAP DATA: everything the phone's Map app shows, built from the game's own data (plots, district lots,
-- home lots, rental lots, attractions). Nothing here is a second copy of the world: positions come from
-- the tables the world was built from.
return function(C)
local F, data, plots = C.F, C.data, C.plots
local V3 = Vector3.new

local function centroid(list)
	local sum, n = V3(0, 0, 0), 0
	for _, p in ipairs(list) do sum += p n += 1 end
	return n > 0 and sum / n or nil
end
local function xz(v) return {math.floor(v.X + 0.5), math.floor(v.Z + 0.5)} end

-- static places (sent once in the catalog). need = reputation tier, feature = an unlockable feature key
function C.mapCatalog()
	local places = {}
	local function add(p) table.insert(places, p) end
	local REP = C.REP_TIERS
	add({key = "spire", name = "Empire Spire", icon = "🏙️", kind = "Landmark", at = xz(V3(0, 0, 0)), tp = "spire", desc = "The whole city builds it together. Every finished Spire moves the city into a new era."})
	add({key = "dealer", name = "Corner Motors", icon = "🚗", kind = "Car dealership", at = xz(V3(0, 0, -160)), tp = "dealer", feature = "cars", desc = "Buy and spawn cars."})
	add({key = "race", name = "Race Track", icon = "🏁", kind = "Race track", at = xz(V3(0, 0, -360)), tp = "race", feature = "race", desc = "Time trials, drift zone and the track record board."})
	add({key = "funpark", name = "Fun Park", icon = "🎡", kind = "Attraction", at = xz(V3(-470, 0, 12)), tp = "funpark", feature = "funpark", desc = "Mini-games, the Ferris wheel and fireworks."})
	if C.MUSEUM_AT then add({key = "museum", name = "Legacy Museum", icon = "🏛️", kind = "Museum", at = xz(C.MUSEUM_AT), tp = "museum", desc = "Your relics, records and the weekly boards."}) end
	local rent = {}
	for _, l in ipairs(C.RENT_LOTS or {}) do table.insert(rent, l.pos) end
	if #rent > 0 then add({key = "rental", name = "Rental Row", icon = "🏢", kind = "Property district", at = xz(centroid(rent)), tp = "rental", feature = "properties", desc = "Build apartments and manage tenants."}) end
	for _, dd in ipairs(C.DISTRICTS) do
		local pts = {}
		for _, lot in ipairs(C.LOTS) do if lot.dkey == dd.key then table.insert(pts, lot.pos) end end
		if #pts > 0 then
			add({key = dd.key, name = dd.name, icon = dd.icon, kind = "Business district", at = xz(centroid(pts)), tp = dd.key, need = dd.tier,
				desc = "Land: $" .. C.fmt(dd.cost) .. " per lot, +$" .. C.fmt(dd.income) .. "/s each. " .. dd.boostText .. "."})
		end
	end
	for _, h in ipairs(C.HOODS) do
		local pts = {}
		for _, lot in ipairs(C.HOME_LOTS or {}) do if lot.hood == h.key then table.insert(pts, lot.pos) end end
		if #pts > 0 then
			add({key = h.key, name = h.name, icon = h.icon, kind = "Neighborhood", at = xz(centroid(pts)), tp = h.key, need = h.tier,
				desc = "Homes from $" .. C.fmt(h.price) .. ". " .. h.perk})
		end
	end
	local roads = {}
	for _, r in ipairs(C.ROADS or {}) do table.insert(roads, {r[1], r[2], r[3], r[4], r[5]}) end
	return {places = places, roads = roads, bounds = {-660, -560, 660, 500}}
end

-- live part of the map for one player (in the state packet)
function F.mapState(plr, d)
	local out = {mine = xz(d.plot.center), plots = {}, props = {}, lots = {}}
	for _, p in ipairs(plots) do
		if p.owner and p.owner ~= plr then table.insert(out.plots, {at = xz(p.center), name = p.owner.Name}) end
	end
	local home = F.homeLot(d)
	if home then out.home = xz(home.pos) end
	for _, b in ipairs(d.props) do
		local lot = C.RENT_LOTS[b.lot]
		if lot then table.insert(out.props, {at = xz(lot.pos), name = C.RENTAL[b.type].name}) end
	end
	for id in pairs(d.lots) do
		local lot = C.LOTS[id]
		if lot then table.insert(out.lots, {at = xz(lot.pos), name = C.DISTRICT[lot.dkey].name}) end
	end
	local site = C.mysterySite and C.mysterySite()
	if site then out.mystery = xz(site) end
	if d.delivery and d.delivery.state == "active" then
		local dest = C.DESTS[d.delivery.dest]
		if dest then out.delivery = {at = xz(dest.pos), name = dest.name} end
	end
	-- the tutorial / story points somewhere: show it too
	local target = F.tutorialTarget and F.tutorialTarget(d)
	if target then out.objective = {at = xz(target), name = "Tutorial objective"} end
	return out
end
end
