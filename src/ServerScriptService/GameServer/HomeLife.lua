-- HOME LIFE (v14): three ways to live, and home parties.
--   🏢 CITY LOFT (an apartment in the Skyline Lofts tower downtown): cheap to start ($15K), three sizes (Studio,
--     City Loft, Skyline Penthouse), no lot needed, decorated like any home. Perk "Night Life": guests at your
--     loft parties get 50% bigger party favors. Small parties (6 / 10 / 16 guests).
--   🏠 HOUSE (a lot in a neighborhood, levels 1-4): the home income bonus, parties up to 12.
--   🏰 MANSION (level 5+ or Millionaire Row): the biggest bonus, parties up to 24.
--   You can have a loft and a house at the same time; parties happen in either.
-- PARTIES (4 minutes, then a 20-minute cooldown): everyone in the server is invited (a CityBuzz post and a Join
-- card). Your home gets a dance floor, a DJ booth and balloons. Every guest who walks in earns the host
-- reputation (up to 10 guests) and gets a party favor once an hour (30 s of THEIR OWN income, so it's never a
-- way to farm money). Visit permissions still apply: a private home stays private.
return function(C)
local Players = game:GetService("Players")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local MAT = Enum.Material
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local P, billboard = C.P, C.billboard

local HL = {
	loft = {
		{name = "Studio Loft", cost = 15000, tier = 1, cap = 6},
		{name = "City Loft", cost = 400000, tier = 3, cap = 10},
		{name = "Skyline Penthouse", cost = 12000000, tier = 5, cap = 16},
	},
	houseCap = 12, mansionCap = 24,
	partyTime = 240, cooldown = 1200, guestRep = 2, maxRepGuests = 10,
	favorSecs = 30, favorMin = 50, favorGap = 3600, loftFavor = 1.5,
	lobby = V3(230, 0, 31.4),   -- the Skyline Lofts entrance: the south face of the gold-trimmed downtown tower
}
C.HOMELIFE = HL
local KINDS = {
	{key = "loft", icon = "🏢", name = "City Loft", sub = "an apartment downtown",
		good = {"From $15K, no lot needed", "Right downtown (Skyline Lofts)", "🌃 Night Life: +50% party favors for your guests"},
		bad = {"Parties of 6 / 10 / 16", "No yard, no garage"}},
	{key = "house", icon = "🏠", name = "House", sub = "your own lot in a neighborhood",
		good = {"Home income bonus", "Neighborhood perks", "Parties of up to 12"}, bad = {"A lot to buy, then levels to build"}},
	{key = "mansion", icon = "🏰", name = "Mansion", sub = "level 5+ or Millionaire Row",
		good = {"The biggest home bonus", "Parties of up to 24", "Pool and garden"}, bad = {"Very expensive"}},
}
C.HOME_KINDS = KINDS

local function loftRec(d)
	if type(d.loft) ~= "table" then d.loft = {level = 0} end
	d.loft.level = math.clamp(math.floor(tonumber(d.loft.level) or 0), 0, #HL.loft)
	return d.loft
end
local function partyRec(d)
	if type(d.party) ~= "table" then d.party = {} end
	local p = d.party
	p.hosted = tonumber(p.hosted) or 0
	p.guests = tonumber(p.guests) or 0
	p.best = tonumber(p.best) or 0
	p.lastAt = tonumber(p.lastAt) or 0
	p.favorAt = tonumber(p.favorAt) or 0
	return p
end
function F.homeKind(d)
	local lvl = d.home and tonumber(d.home.level) or 0
	if lvl <= 0 then return nil end
	if lvl >= 5 or (F.homeHood and F.homeHood(d) == "rich") then return "mansion" end
	return "house"
end
local function venueCap(d, venue)
	if venue == "loft" then
		local l = HL.loft[loftRec(d).level]
		return l and l.cap or 0
	end
	return F.homeKind(d) == "mansion" and HL.mansionCap or HL.houseCap
end
local function venueName(d, venue)
	if venue == "loft" then
		local l = HL.loft[loftRec(d).level]
		return l and l.name or "loft"
	end
	return F.homeKind(d) == "mansion" and "Mansion" or "House"
end
local function owns(d, venue)
	if venue == "loft" then return loftRec(d).level > 0 end
	if venue == "home" then return F.homeKind(d) ~= nil end
	return false
end

-- ===== the loft =====
function F.loftBuy(plr)
	local d = data[plr]
	if not d then return false end
	local lr = loftRec(d)
	local nxt = HL.loft[lr.level + 1]
	if not nxt then return false end
	if F.tierIndex(d.rep) < nxt.tier then notify(plr, "🔒 The " .. nxt.name .. " needs " .. C.REP_TIERS[nxt.tier].name .. " reputation.") return false end
	if d.cash < nxt.cost then notify(plr, "🏢 The " .. nxt.name .. " costs $" .. fmt(nxt.cost) .. ".") return false end
	d.cash -= nxt.cost
	lr.level += 1
	lr.since = lr.since or os.time()
	notify(plr, "🏢 " .. (lr.level == 1 and "Welcome to your " or "Moved up to the ") .. nxt.name .. " in the Skyline Lofts! Parties of up to " .. nxt.cap .. ".")
	if lr.level == 1 then F.buzz("🏢", plr.Name .. " moved into the Skyline Lofts downtown!", RGB(255, 205, 80)) end
	if F.interiorOf and F.interiorOf(plr) and plr:GetAttribute("Interior") == "loft" and F.rebuildInteriorOf then F.rebuildInteriorOf(plr) end
	return true
end
-- the lobby: a lit entrance with a canopy, a sign and the door
do
	local f = Instance.new("Model")
	f.Name = "SkylineLofts"
	f.Parent = C.WORLD
	local o = CF(HL.lobby)
	P(f, V3(8, 0.4, 5), o * CF(0, 7.2, -1.8), RGB(30, 30, 36), MAT.Metal)
	for _, sx in ipairs({-3.6, 3.6}) do P(f, V3(0.3, 7, 0.3), o * CF(sx, 3.5, -4), RGB(255, 205, 80), MAT.Metal) end
	local door = P(f, V3(4, 6.4, 0.3), o * CF(0, 3.2, 0.2), RGB(180, 210, 240), MAT.Glass, {Transparency = 0.3, Name = "LobbyDoor"})
	local sign = P(f, V3(7, 1.2, 0.3), o * CF(0, 8.2, 0), RGB(25, 25, 30), MAT.SmoothPlastic)
	C.surfaceText(sign, Enum.NormalId.Front, "🏢 SKYLINE LOFTS", RGB(255, 205, 80))
	billboard(sign, UDim2.fromOffset(200, 50), V3(0, 3, 0), {{text = "🏢 SKYLINE LOFTS", h = 0.55, color = RGB(255, 205, 80)}, {text = "Apartments from $15K", h = 0.45, font = Enum.Font.GothamBold}}, 90)
	C.prompt(door, "Enter", "Skyline Lofts", 12, 0.3, function(plr)
		local d = data[plr]
		if not d then return end
		if loftRec(d).level > 0 then F.enterInterior(plr, plr, "loft")
		else R.Menu:FireClient(plr, "openParty") notify(plr, "🏢 Lease a loft from the 🎉 Home & Party app.") end
	end)
	C.reserve(HL.lobby.X - 5, HL.lobby.Z - 6, HL.lobby.X + 5, HL.lobby.Z + 1)
end

-- ===== parties =====
local parties = {}   -- [host] = {venue, endsAt, guests = {[uid] = true}, n, rep}
C.PARTIES = parties
local function hereCount(host, venue)
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= host and p:GetAttribute("Interior") == venue and p:GetAttribute("InteriorOwner") == host.UserId then n += 1 end
	end
	return n
end
local function propsOf(host, venue)
	local m = F.interiorModel and F.interiorModel(host, venue)
	return m and m:FindFirstChild("PartyProps")
end
-- decorate the room (called by Interiors whenever the room is built while a party is on)
function F.partyDress(owner, key, m, o, L)
	local pt = parties[owner]
	if not (pt and pt.venue == key) then return end
	local props = Instance.new("Model")
	props.Name = "PartyProps"
	props.Parent = m
	local floor = Instance.new("Model")
	floor.Name = "DanceFloor"
	floor.Parent = props
	for i = -2, 2 do
		for j = -2, 2 do P(floor, V3(3.8, 0.2, 3.8), o * CF(i * 4, 0.62, j * 4 + 2), RGB(255, 230, 120), MAT.Neon) end
	end
	if C.tag then C.tag(floor, "ChaseLights") end
	P(props, V3(6, 3.2, 2.4), o * CF(0, 1.9, -L.d / 2 + 4), RGB(30, 30, 40), MAT.SmoothPlastic, {CanCollide = true})
	local dj = P(props, V3(5, 1.2, 0.3), o * CF(0, 4.4, -L.d / 2 + 3), RGB(255, 60, 200), MAT.Neon)
	C.surfaceText(dj, Enum.NormalId.Back, "🎧 DJ", RGB(255, 255, 255))
	for _, c in ipairs({{-L.w / 2 + 3, -L.d / 2 + 3}, {L.w / 2 - 3, -L.d / 2 + 3}, {-L.w / 2 + 3, L.d / 2 - 3}, {L.w / 2 - 3, L.d / 2 - 3}}) do
		for k = 0, 2 do
			local b = C.ball(props, V3(1.6, 1.9, 1.6), o * CF(c[1] + k * 0.9 - 0.9, 7 + k * 0.6, c[2]), Color3.fromHSV((k * 0.3 + c[1] * 0.01) % 1, 0.7, 1))
			b.Material = MAT.SmoothPlastic
		end
	end
	local banner = P(props, V3(14, 2, 0.3), o * CF(0, 9, -L.d / 2 + 1), RGB(255, 205, 80), MAT.SmoothPlastic)
	C.surfaceText(banner, Enum.NormalId.Back, "🎉 " .. string.upper(owner.Name) .. "'S PARTY 🎉", RGB(60, 20, 60))
end
local function redress(host, venue)
	-- if the room is built right now, put the decorations in (or take them out)
	local m = F.interiorModel and F.interiorModel(host, venue)
	if not m then return end
	local old = m:FindFirstChild("PartyProps")
	if old then old:Destroy() end
	local room = F.interiorOf and F.interiorOf(host)
	if parties[host] and parties[host].venue == venue and F.rebuildInteriorOf and room and room.key == venue and room.owner == host then
		F.rebuildInteriorOf(host)
	end
end
function F.partyStart(host, venue)
	local d = data[host]
	if not d or (venue ~= "home" and venue ~= "loft") then return false end
	if not owns(d, venue) then notify(host, venue == "loft" and "🎉 Lease a loft first." or "🎉 Build your house first.") return false end
	if parties[host] then notify(host, "🎉 Your party is already on!") return false end
	local pr = partyRec(d)
	local wait = pr.lastAt + HL.cooldown - os.time()
	if wait > 0 then notify(host, "🎉 You need a rest! Next party in " .. math.ceil(wait / 60) .. " min.") return false end
	local name = venueName(d, venue)
	parties[host] = {venue = venue, endsAt = os.clock() + HL.partyTime, guests = {}, n = 0, rep = 0, cap = venueCap(d, venue)}
	F.buzz("🎉", host.Name .. " is throwing a party at their " .. name .. "! Phone → 🎉 Home & Party → Join", RGB(255, 90, 200))
	R.Menu:FireAllClients("partyOn", {uid = host.UserId, host = host.Name, venue = venue, place = name, left = HL.partyTime, cap = parties[host].cap})
	F.enterInterior(host, host, venue)
	redress(host, venue)
	if F.track then F.track(host, "party") end
	return true
end
function F.partyJoin(guest, hostUid)
	local host = Players:GetPlayerByUserId(tonumber(hostUid) or 0)
	local pt = host and parties[host]
	if not (pt and data[guest]) or guest == host then return false end
	if hereCount(host, pt.venue) >= pt.cap then notify(guest, "🎉 " .. host.Name .. "'s party is full (" .. pt.cap .. " guests)!") return false end
	F.enterInterior(guest, host, pt.venue)
	return guest:GetAttribute("InteriorOwner") == host.UserId
end
-- someone walked into a room (Interiors calls this): a guest arriving at a party
function F.partyArrive(plr, owner, key)
	local pt = parties[owner]
	if not pt or pt.venue ~= key or plr == owner then return end
	local uid = tostring(plr.UserId)
	if pt.guests[uid] then return end
	pt.guests[uid] = true
	pt.n += 1
	if F.track then F.track(plr, "party") end
	local od, d = data[owner], data[plr]
	if pt.n <= HL.maxRepGuests and od then
		F.addRep(owner, HL.guestRep)
		pt.rep += HL.guestRep
	end
	notify(owner, "🎉 " .. plr.Name .. " arrived at your party! (" .. pt.n .. " guest" .. (pt.n == 1 and "" or "s") .. ")")
	local pr = d and partyRec(d)
	if pr and os.time() - pr.favorAt >= HL.favorGap then
		pr.favorAt = os.time()
		local total = F.incomePerSec(d)
		local amt = math.floor(math.max(HL.favorMin, total * HL.favorSecs) * (key == "loft" and HL.loftFavor or 1))
		d.cash += amt
		F.earn(d, amt)
		notify(plr, "🎁 Party favor from " .. owner.Name .. ": +$" .. fmt(amt) .. (key == "loft" and " (🌃 Night Life bonus)" or ""))
	end
end
local function partyEnd(host, why)
	local pt = parties[host]
	if not pt then return end
	parties[host] = nil
	local d = data[host]
	if d then
		local pr = partyRec(d)
		pr.hosted += 1
		pr.guests += pt.n
		pr.best = math.max(pr.best, pt.n)
		pr.lastAt = os.time()
		R.Splash:FireClient(host, "🎉 PARTY OVER", pt.n .. " guest" .. (pt.n == 1 and "" or "s") .. "  •  +" .. pt.rep .. " reputation" .. (why and ("  •  " .. why) or ""), RGB(255, 90, 200))
		if pt.n >= 3 then F.buzz("🎉", host.Name .. "'s party had " .. pt.n .. " guests!", RGB(255, 90, 200)) end
	end
	R.Menu:FireAllClients("partyOff", {uid = host.UserId})
	if host.Parent then redress(host, pt.venue) end
end
F.partyEnd = partyEnd

function F.homeLifeInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local lr, pr = loftRec(d), partyRec(d)
	local info = {loft = lr.level, loftName = HL.loft[lr.level] and HL.loft[lr.level].name or nil, kind = F.homeKind(d), kinds = KINDS,
		hosted = pr.hosted, guests = pr.guests, best = pr.best, cooldown = math.max(0, pr.lastAt + HL.cooldown - os.time()), cash = d.cash, parties = {}}
	local nxt = HL.loft[lr.level + 1]
	if nxt then info.loftNext = {name = nxt.name, cost = nxt.cost, cap = nxt.cap, locked = F.tierIndex(d.rep) < nxt.tier, need = C.REP_TIERS[nxt.tier].name} end
	info.venues = {}
	for _, v in ipairs({"home", "loft"}) do
		if owns(d, v) then table.insert(info.venues, {key = v, name = venueName(d, v), cap = venueCap(d, v)}) end
	end
	local mine = parties[plr]
	if mine then info.mine = {venue = mine.venue, n = mine.n, left = math.max(0, math.ceil(mine.endsAt - os.clock())), rep = mine.rep, cap = mine.cap} end
	for host, pt in pairs(parties) do
		if host ~= plr and host.Parent then
			table.insert(info.parties, {uid = host.UserId, host = host.Name, place = venueName(data[host] or {}, pt.venue), here = hereCount(host, pt.venue), cap = pt.cap,
				left = math.max(0, math.ceil(pt.endsAt - os.clock()))})
		end
	end
	return info
end
C.ACTIONS = C.ACTIONS or {}
local function refresh(plr) local i = F.homeLifeInfo(plr) if i then R.Menu:FireClient(plr, "homeLife", i) end end
C.ACTIONS.homeLifeInfo = function(plr) refresh(plr) end
C.ACTIONS.loftBuy = function(plr) if F.loftBuy(plr) then refresh(plr) end end
C.ACTIONS.loftEnter = function(plr, d) if loftRec(d).level > 0 then F.enterInterior(plr, plr, "loft") end end
C.ACTIONS.partyStart = function(plr, d, a) if F.partyStart(plr, a) then refresh(plr) end end
C.ACTIONS.partyJoin = function(plr, d, a) F.partyJoin(plr, a) end
C.ACTIONS.partyEnd = function(plr) if parties[plr] then partyEnd(plr, "ended early") refresh(plr) end end

task.spawn(function()
	while true do
		task.wait(2)
		local now = os.clock()
		for host, pt in pairs(parties) do
			if not host.Parent or not data[host] then
				parties[host] = nil
				R.Menu:FireAllClients("partyOff", {uid = host.UserId})
			elseif now >= pt.endsAt then
				partyEnd(host)
			end
		end
	end
end)
end
