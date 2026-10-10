-- THEATER (v14): the Movie Theater. It's too big for the home plot, so it opens on a city plot (RealEstate) and
-- the owner runs its programme:
--   * FILMS: three original films are "in release" at a time (they rotate every few hours, the same in every
--     server). The owner picks what's showing. A new film draws crowds (hype) that fades show by show, horror sells
--     at night, family films by day; a film's first show at your theater is a PREMIERE (a CityBuzz post, a bigger
--     crowd, a little reputation)
--   * SHOWS: a show starts every few minutes while you're in the game. Attendance = seats × how full it is (film
--     hype + screen + sound + district + time of day). The last show's turnout sets the theater's sales
--     multiplier until the next one (×0.8 empty … ×1.6 sold out with full concessions)
--   * UPGRADES: seats (capacity), screen and sound (fuller shows), concessions (more per guest); 5 levels each,
--     bought with cash, all checked here
-- The marquee outside and the big screen inside show the film. Everything is decided on the server; the client
-- only asks for the info and sends "show this film" / "buy this upgrade".
return function(C)
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local V3, RGB = Vector3.new, Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

local TH = {
	session = 180,          -- seconds between shows
	firstShow = 45,         -- the first show after you join / open
	release = 3 * 3600,     -- films in release rotate this often (os.time windows: the same in every server)
	changeCooldown = 60,    -- seconds between film changes
	hype = 0.22, hypeFade = 0.9,          -- a new film's extra fill, ×0.9 per show
	premiere = 0.15, premiereRep = 5,
	base = 0.34, perScreen = 0.05, perSound = 0.04, perStar = 0.02, night = 0.1,
	seats = {60, 90, 130, 180, 240, 320},
	mult = {lo = 0.8, span = 0.5, perSnack = 0.04, perSeat = 0.02, max = 1.6},
	upCost = 0.12, upGrowth = 2.2, maxUp = 5,
	selloutGap = 600,
}
C.THEATER = TH
-- original films (no real titles): appeal = extra fill; night/day = when the genre sells best
local FILMS = {
	{key = "dino", icon = "🦖", title = "The Last Dinosaur", genre = "Family adventure", appeal = 0.06, day = 0.05},
	{key = "moonpirates", icon = "🚀", title = "Moon Pirates", genre = "Space action", appeal = 0.08},
	{key = "echoes", icon = "👻", title = "House of Echoes", genre = "Horror", appeal = 0.04, night = 0.1},
	{key = "rooftop", icon = "💘", title = "Rooftop Romance", genre = "Romance", appeal = 0.05, night = 0.04},
	{key = "noodle", icon = "🕵️", title = "Detective Noodle", genre = "Comedy mystery", appeal = 0.06, day = 0.04},
	{key = "robotsummer", icon = "🤖", title = "Robot Summer", genre = "Sci-fi", appeal = 0.07},
	{key = "turbolane", icon = "🏎️", title = "Turbo Lane", genre = "Racing action", appeal = 0.08, night = 0.03},
	{key = "penguinheist", icon = "🐧", title = "The Penguin Heist", genre = "Family comedy", appeal = 0.07, day = 0.05},
	{key = "concerto", icon = "🎻", title = "The Quiet Concerto", genre = "Drama", appeal = 0.05},
}
C.FILMS = FILMS
local FILM = {}
for _, f in ipairs(FILMS) do FILM[f.key] = f end
local UPS = {
	{key = "seats", name = "Seats", icon = "💺", what = "more guests per show"},
	{key = "screen", name = "Screen", icon = "🖥️", what = "fuller shows (+5% each)"},
	{key = "sound", name = "Sound", icon = "🔊", what = "fuller shows (+4% each)"},
	{key = "snacks", name = "Concessions", icon = "🍿", what = "more per guest (+4% sales each)"},
}
local UP = {}
for _, u in ipairs(UPS) do UP[u.key] = u end
C.THEATER_UPS = UPS

-- the films in release right now (3, rotating; the same in every server)
function F.filmsNow(t)
	local w = math.floor((t or os.time()) / TH.release)
	local out = {}
	for k = 0, 2 do table.insert(out, FILMS[(w + k * 3) % #FILMS + 1]) end
	return out
end
local function inRelease(key)
	for _, f in ipairs(F.filmsNow()) do if f.key == key then return true end end
	return false
end

local function rec(d)
	local t = d.theater
	if type(t) ~= "table" then
		t = {}
		d.theater = t
	end
	t.up = type(t.up) == "table" and t.up or {}
	for _, u in ipairs(UPS) do t.up[u.key] = math.clamp(math.floor(tonumber(t.up[u.key]) or 0), 0, TH.maxUp) end
	t.sessions = tonumber(t.sessions) or 0
	t.tickets = tonumber(t.tickets) or 0
	t.best = tonumber(t.best) or 0
	t.filmShows = tonumber(t.filmShows) or 0
	t.premiered = type(t.premiered) == "table" and t.premiered or {}
	if type(t.film) ~= "string" or not FILM[t.film] then t.film = F.filmsNow()[1].key end
	return t
end
F.theaterRec = rec
function F.theaterFilm(d)
	if not d or (d.levels.theater or 0) <= 0 then return nil end
	return FILM[rec(d).film]
end
function F.theaterMult(d, key)
	if key ~= "theater" then return 1 end
	local t = d and d.theater
	return type(t) == "table" and tonumber(t.mult) or 1
end
function F.theaterUpCost(lvl) return math.floor(BIZ.theater.cost * TH.upCost * TH.upGrowth ^ lvl) end
local function capacity(t) return TH.seats[t.up.seats + 1] end
local function isNight()
	local h = Lighting.ClockTime
	return h >= 18 or h < 5
end
-- how full the next show would be, and why (the app shows the parts)
local function fillParts(d, t, premiere)
	local film = FILM[t.film]
	local parts = {}
	local function add(name, v) if v ~= 0 then table.insert(parts, {name, v}) end end
	add("Base", TH.base)
	add(film.icon .. " " .. film.title, film.appeal)
	add("✨ Hype", TH.hype * TH.hypeFade ^ t.filmShows * (inRelease(film.key) and 1 or 0.4))
	if not inRelease(film.key) then add("📼 Out of release", -0.08) end
	add("🖥️ Screen", t.up.screen * TH.perScreen)
	add("🔊 Sound", t.up.sound * TH.perSound)
	local deed = F.siteDeed and F.siteDeed(d, "theater")
	local dist = deed and C.DISTRICT[deed.district]
	if dist then add(dist.icon .. " " .. dist.name, (dist.stars or 0) * TH.perStar) end
	if isNight() then
		add("🌙 Night show", TH.night + (film.night or 0))
	else
		add("☀️ Day show", film.day or 0)
	end
	if premiere then add("🎬 Premiere", TH.premiere) end
	local fill = 0
	for _, p in ipairs(parts) do fill += p[2] end
	return math.clamp(fill, 0.05, 1), parts
end

-- ===== shows =====
local nextShow = {}   -- [plr] = os.clock() of the next show
local lastSellout = {}
local function marquee(plr, d)
	local m = d and d.plot and d.plot.slots and d.plot.slots.theater
	local film = F.theaterFilm(d)
	if not (m and film) then return end
	for _, x in ipairs(m:GetDescendants()) do
		if x.Name == "Marquee" and x:IsA("BasePart") then
			local tl = x:FindFirstChildWhichIsA("SurfaceGui") and x:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel")
			if tl then tl.Text = "NOW SHOWING\n" .. film.icon .. " " .. string.upper(film.title) end
		end
	end
end
F.theaterMarquee = marquee
function F.theaterShow(plr)
	local d = data[plr]
	if not d or (d.levels.theater or 0) <= 0 then return nil end
	local t = rec(d)
	if not (F.siteDeed and F.siteDeed(d, "theater")) then return nil end   -- (between plots: no shows)
	local film = FILM[t.film]
	local premiere = not t.premiered[film.key]
	local fill, parts = fillParts(d, t, premiere)
	local cap = capacity(t)
	local guests = math.floor(cap * fill + 0.5)
	t.sessions += 1
	t.tickets += guests
	t.best = math.max(t.best, guests)
	t.filmShows += 1
	t.mult = math.min(TH.mult.max, TH.mult.lo + fill * TH.mult.span + t.up.snacks * TH.mult.perSnack + t.up.seats * TH.mult.perSeat)
	t.last = {film = film.key, guests = guests, cap = cap, fill = math.floor(fill * 100 + 0.5), t = os.time()}
	local name = F.bizName and F.bizName(d, "theater") or BIZ.theater.name
	if premiere then
		t.premiered[film.key] = true
		F.addRep(plr, TH.premiereRep)
		if F.rivalAct then F.rivalAct(plr, "premiere", "theater") end
		F.buzz("🎬", "PREMIERE NIGHT: " .. film.icon .. " " .. film.title .. " opened at " .. plr.Name .. "'s " .. name .. " (" .. guests .. " guests)!", BIZ.theater.color)
		C.burst((F.slotCF(d.plot, "theater") * CFrame.new(0, 12, 6)).Position, RGB(255, 220, 120), 80)
	end
	if guests >= cap and os.clock() - (lastSellout[plr] or -1e9) > TH.selloutGap then
		lastSellout[plr] = os.clock()
		notify(plr, "🎬 SOLD OUT! Every seat for " .. film.title .. " (" .. guests .. ").")
		F.buzz("🍿", plr.Name .. "'s " .. name .. " sold out " .. film.title .. "!", BIZ.theater.color)
	end
	marquee(plr, d)
	if F.track then F.track(plr, "show") end
	R.Menu:FireClient(plr, "theaterShow", {film = film.title, icon = film.icon, guests = guests, cap = cap, premiere = premiere, mult = t.mult})
	return t.last, parts
end

function F.theaterInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local open = (d.levels.theater or 0) > 0
	local t = rec(d)
	local deed = F.siteDeed and F.siteDeed(d, "theater")
	local info = {open = open, level = d.levels.theater or 0, cost = F.upgradeCost(d, "theater"), unlocked = F.bizUnlocked(d, "theater"),
		hasPlot = deed ~= nil, placed = F.siteLot and F.siteLot(plr, "theater") ~= nil, film = t.film, sessions = t.sessions, tickets = t.tickets,
		best = t.best, last = t.last, mult = F.theaterMult(d, "theater"), capacity = capacity(t), cash = d.cash,
		films = {}, ups = {}, nextShow = nextShow[plr] and math.max(0, math.ceil(nextShow[plr] - os.clock())) or nil}
	if deed and C.DISTRICT[deed.district] then info.district = C.DISTRICT[deed.district].icon .. " " .. C.DISTRICT[deed.district].name end
	local fill, parts = fillParts(d, t, not t.premiered[t.film])
	info.fill = math.floor(fill * 100 + 0.5)
	info.parts = {}
	for _, p in ipairs(parts) do table.insert(info.parts, {p[1], math.floor(p[2] * 100 + 0.5)}) end
	local seen = {}
	for _, f in ipairs(F.filmsNow()) do
		seen[f.key] = true
		table.insert(info.films, {key = f.key, icon = f.icon, title = f.title, genre = f.genre, premiered = t.premiered[f.key] == true, showing = f.key == t.film,
			night = f.night ~= nil, day = f.day ~= nil})
	end
	if not seen[t.film] then
		local f = FILM[t.film]
		table.insert(info.films, {key = f.key, icon = f.icon, title = f.title, genre = f.genre, premiered = true, showing = true, old = true})
	end
	for _, u in ipairs(UPS) do
		local lvl = t.up[u.key]
		table.insert(info.ups, {key = u.key, name = u.name, icon = u.icon, what = u.what, level = lvl, max = TH.maxUp, cost = lvl < TH.maxUp and F.theaterUpCost(lvl) or nil})
	end
	local w = math.floor(os.time() / TH.release)
	info.rotateIn = (w + 1) * TH.release - os.time()
	return info
end

local changedAt = {}
function F.theaterSetFilm(plr, key)
	local d = data[plr]
	if not (d and type(key) == "string" and FILM[key]) then return false end
	if (d.levels.theater or 0) <= 0 then return false end
	local t = rec(d)
	if t.film == key then return true end
	if not inRelease(key) then
		notify(plr, "🎬 That film isn't in release right now.")
		return false
	end
	local now = os.clock()
	if changedAt[plr] and now - changedAt[plr] < TH.changeCooldown then
		notify(plr, "🎬 The projectionist is still changing reels. Try again in " .. math.ceil(TH.changeCooldown - (now - changedAt[plr])) .. " s.")
		return false
	end
	changedAt[plr] = now
	t.film = key
	t.filmShows = 0
	marquee(plr, d)
	notify(plr, "🎬 Now showing: " .. FILM[key].icon .. " " .. FILM[key].title .. (t.premiered[key] and "" or "  (its premiere is the next show!)"))
	return true
end
function F.theaterUpgrade(plr, which)
	local d = data[plr]
	local u = type(which) == "string" and UP[which]
	if not (d and u) then return false end
	if (d.levels.theater or 0) <= 0 then return false end
	local t = rec(d)
	local lvl = t.up[u.key]
	if lvl >= TH.maxUp then return false end
	local cost = F.theaterUpCost(lvl)
	if d.cash < cost then
		notify(plr, "🎬 " .. u.name .. " level " .. (lvl + 1) .. " costs $" .. fmt(cost) .. ".")
		return false
	end
	d.cash -= cost
	t.up[u.key] = lvl + 1
	notify(plr, u.icon .. " " .. u.name .. " upgraded to level " .. (lvl + 1) .. ": " .. u.what .. ".")
	if F.empireFirst then pcall(F.empireFirst, plr, "upgrade") end
	return true
end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.theaterInfo = function(plr)
	local info = F.theaterInfo(plr)
	if info then R.Menu:FireClient(plr, "theater", info) end
end
C.ACTIONS.theaterFilm = function(plr, d, a)
	if F.theaterSetFilm(plr, a) then C.ACTIONS.theaterInfo(plr) end
end
C.ACTIONS.theaterUp = function(plr, d, a)
	if F.theaterUpgrade(plr, a) then C.ACTIONS.theaterInfo(plr) end
end

task.spawn(function()
	while true do
		task.wait(2)
		local now = os.clock()
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			if d and (d.levels.theater or 0) > 0 then
				if not nextShow[plr] then
					nextShow[plr] = now + TH.firstShow
					marquee(plr, d)
				elseif now >= nextShow[plr] then
					nextShow[plr] = now + TH.session
					local ok, err = pcall(F.theaterShow, plr)
					if not ok then warn("[Theater] show failed: " .. tostring(err)) end
				end
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	nextShow[plr], lastSellout[plr], changedAt[plr] = nil, nil, nil
end)
end
