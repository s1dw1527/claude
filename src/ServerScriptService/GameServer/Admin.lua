-- ADMIN (v10): a developer / admin panel that only authorized people can use.
--
-- WHO IS AN ADMIN (decided here, on the server — never by the client, never from player save data):
--   * OWNERS: the UserIds in C.ADMIN_CONFIG.owners below, the place's creator (user-owned places), or members of
--     C.ADMIN_CONFIG.groupId with at least groupMinRank (group-owned places). Owners can add / remove admins.
--   * ADMINS: UserIds an owner added in the panel. They're kept in their OWN DataStore (C.ADMIN_CONFIG.storeName),
--     separate from player saves, so nothing a player saves can ever make them an admin.
--   * In Roblox Studio (testing only) every player counts as an owner when studioIsOwner is true. Live servers never.
-- Adding an admin by username: the server looks the name up (Players:GetUserIdFromNameAsync) and stores the
-- UserId it gets back; the client never sends a trusted id or role.
--
-- EVERY admin request comes through one action ("adm") that checks the sender's role first. Requests from anyone
-- else are ignored (and counted). Dangerous tools (taking cash or cars away, kicking, removing an admin...) never
-- run from one tap: the server answers with a one-time confirmation token that the panel must send back within
-- 30 seconds. Every tool use is written to the admin log (who, what, target, amount — nothing personal beyond
-- names and UserIds).
return function(C)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local fmt, notify = C.fmt, C.notify

C.ADMIN_CONFIG = {
	owners = {},                 -- ← put your Roblox UserId(s) here, e.g. {12345678}
	includeCreator = true,       -- the place's creator is an owner (user-owned places)
	groupId = 0,                 -- group-owned place: members of this group...
	groupMinRank = 255,          -- ...with this rank or higher are owners
	studioIsOwner = true,        -- Studio test sessions only: every player is an owner
	storeName = "CornerEmpire_Admins_v1",
	confirmSeconds = 30,
	logSize = 300,
}
local CFG = C.ADMIN_CONFIG
local STARTED = os.clock()

-- =====================================================================
-- AUTHORIZATION (server only)
-- =====================================================================
local store
do
	-- (Studio playtests get their own copy, like every other store: see C.storeName)
	local ok, s = pcall(function() return DataStoreService:GetDataStore(C.storeName(CFG.storeName)) end)
	store = ok and s or nil
end
local admins = {}        -- [userId] = {name, by, at}  (loaded from the admin DataStore)
local roles = {}         -- [plr] = "owner" | "admin" | nil
local groupRank = {}     -- [plr] = rank (looked up once on join)
local function isOwnerId(id)
	for _, o in ipairs(CFG.owners) do if o == id then return true end end
	return false
end
local function computeRole(plr)
	if RunService:IsStudio() and CFG.studioIsOwner then return "owner" end
	if isOwnerId(plr.UserId) then return "owner" end
	if CFG.includeCreator and game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and plr.UserId == game.CreatorId then return "owner" end
	if CFG.groupId ~= 0 and (groupRank[plr] or 0) >= CFG.groupMinRank then return "owner" end
	if admins[plr.UserId] then return "admin" end
	return nil
end
function F.adminRole(plr) return roles[plr] end
function F.isAdmin(plr) return roles[plr] ~= nil end
local function hello(plr)
	local role = roles[plr]
	if not role then return end
	R.Menu:FireClient(plr, "adminHello", {role = role})
	-- (again once their game has loaded, in case the panel's script wasn't listening yet)
	task.spawn(function()
		for _ = 1, 120 do
			if data[plr] or not plr.Parent then break end
			task.wait(1)
		end
		if plr.Parent and roles[plr] then R.Menu:FireClient(plr, "adminHello", {role = roles[plr]}) end
	end)
end
function F.adminRefresh(plr)
	local before = roles[plr]
	roles[plr] = computeRole(plr)
	if roles[plr] ~= before then
		if roles[plr] then hello(plr) else R.Menu:FireClient(plr, "adminBye") end
	end
end
local function refreshAll() for _, p in ipairs(Players:GetPlayers()) do F.adminRefresh(p) end end
local function loadAdmins()
	if not store then return end
	local ok, res = pcall(function() return store:GetAsync("admins") end)
	if ok and type(res) == "table" then
		local list = {}
		for id, e in pairs(res) do
			local uid = tonumber(id)
			if uid and type(e) == "table" then list[uid] = {name = tostring(e.name or ""), by = tostring(e.by or ""), at = tonumber(e.at) or 0} end
		end
		admins = list
	end
end
task.spawn(function()
	loadAdmins()
	refreshAll()
	-- other servers may add or remove admins: re-read the list now and then
	while true do
		task.wait(60)
		loadAdmins()
		refreshAll()
	end
end)
Players.PlayerAdded:Connect(function(plr)
	if CFG.groupId ~= 0 then
		local ok, rank = pcall(function() return plr:GetRankInGroup(CFG.groupId) end)
		groupRank[plr] = ok and rank or 0
	end
	F.adminRefresh(plr)
end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(F.adminRefresh, p) end

-- =====================================================================
-- LOG
-- =====================================================================
local LOG = {}
C.ADMIN_LOG = LOG
local function log(admin, tool, target, detail)
	local e = {t = os.time(), admin = admin and admin.Name or "?", adminId = admin and admin.UserId or 0, tool = tool,
		target = target and (typeof(target) == "Instance" and target.Name or tostring(target)) or nil, detail = detail and string.sub(tostring(detail), 1, 60) or nil}
	table.insert(LOG, 1, e)
	while #LOG > CFG.logSize do table.remove(LOG) end
	print("[CornerEmpire][admin] " .. e.admin .. " → " .. tool .. (e.target and (" • " .. e.target) or "") .. (e.detail and (" • " .. e.detail) or ""))
end
local denied = {}   -- [userId] = {count, lastLog}
local function deny(plr, tool)
	local e = denied[plr.UserId] or {count = 0, last = -1e9}
	denied[plr.UserId] = e
	e.count += 1
	if os.clock() - e.last > 60 then
		e.last = os.clock()
		log(plr, "DENIED", nil, "not an admin (" .. e.count .. " tries)")
	end
end

-- =====================================================================
-- TOOLS
-- =====================================================================
local int, str = C.int, C.str
local function target(args)
	local id = type(args) == "table" and int(args.target, 1)
	local p = id and Players:GetPlayerByUserId(id)
	return p, p and data[p]
end
local function root(p) return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function hum(p) return p and p.Character and p.Character:FindFirstChildOfClass("Humanoid") end
local muted = {}
function F.isMuted(plr) return muted[plr] == true end
local npcs = {}

-- each tool: {danger = true/false, owner = true (owners only), run = function(admin, args) -> ok, message}
local TOOLS = {}
C.ADMIN_TOOLS = TOOLS
-- ----- players -----
TOOLS.giveCash = {run = function(admin, a)
	local p, d = target(a)
	local n = int(a.amount, 1, 1e15)
	if not (d and n) then return false, "Pick a player and an amount." end
	d.cash += n
	notify(p, "🎁 An admin gave you $" .. fmt(n) .. ".")
	return true, "+$" .. fmt(n), p, n
end}
TOOLS.removeCash = {danger = true, run = function(admin, a)
	local p, d = target(a)
	local n = int(a.amount, 1, 1e15)
	if not (d and n) then return false, "Pick a player and an amount." end
	n = math.min(n, math.max(0, math.floor(d.cash)))
	d.cash -= n
	return true, "-$" .. fmt(n), p, n
end}
TOOLS.giveRep = {run = function(admin, a)
	local p, d = target(a)
	local n = int(a.amount, 1, 100000)
	if not (d and n) then return false, "Pick a player and an amount." end
	F.addRep(p, n)
	return true, "+" .. n .. " rep", p, n
end}
TOOLS.heal = {run = function(admin, a)
	local p = target(a)
	local h = hum(p)
	if not h then return false, "No character." end
	h.Health = h.MaxHealth
	return true, "healed", p
end}
TOOLS.respawn = {run = function(admin, a)
	local p = target(a)
	if not p then return false, "Pick a player." end
	F.despawnCar(p)
	if F.leaveInterior then F.leaveInterior(p) end
	pcall(function() p:LoadCharacter() end)
	return true, "respawned", p
end}
TOOLS.freeze = {run = function(admin, a)
	local p = target(a)
	local r, h = root(p), hum(p)
	if not (r and h) then return false, "No character." end
	local on = a.on == true
	r.Anchored = on
	h.WalkSpeed = on and 0 or 16
	p:SetAttribute("Frozen", on or nil)
	notify(p, on and "🧊 An admin froze you." or "🧊 You can move again.")
	return true, on and "frozen" or "unfrozen", p
end}
TOOLS.kick = {danger = true, run = function(admin, a)
	local p = target(a)
	if not p then return false, "Pick a player." end
	if roles[p] == "owner" then return false, "Owners can't be kicked from the panel." end
	local why = str(a.text, 100) or "Removed by an admin."
	task.defer(function() pcall(function() p:Kick(why) end) end)
	return true, "kicked", p, why
end}
TOOLS.warn = {run = function(admin, a)
	local p = target(a)
	local text = p and C.filterText(admin, tostring(a.text or ""), 1, 140)
	if not (p and text) then return false, "Pick a player and write a (clean) message." end
	R.Splash:FireClient(p, "⚠️ WARNING FROM AN ADMIN", text, RGB(255, 170, 60))
	return true, "warned", p
end}
TOOLS.mute = {run = function(admin, a)
	local p = target(a)
	if not p then return false, "Pick a player." end
	muted[p] = a.on == true or nil
	p:SetAttribute("Muted", muted[p])
	notify(p, muted[p] and "🔇 An admin muted your CityBuzz posts for this server." or "🔊 You can post again.")
	return true, muted[p] and "muted" or "unmuted", p
end}
TOOLS.inspect = {run = function(admin, a)
	local p, d = target(a)
	if not d then return false, "Pick a player." end
	local biz = {}
	for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then table.insert(biz, b.icon .. b.key .. " " .. d.levels[b.key]) end end
	local cars = 0
	for _, c in ipairs(C.CARS) do if F.ownsCar(p, c) then cars += 1 end end
	return true, string.format("$%s • %s/s • rep %s • rebirths %d • %d deeds • HQ %d • %d cars • %s", fmt(d.cash), fmt(F.incomePerSec(d)), fmt(d.rep), d.rebirths, #(d.deeds or {}),
		F.hqLevel and F.hqLevel(d) or 0, cars, table.concat(biz, ", ")), p, nil, true
end}
-- ----- items / vehicles / businesses / properties -----
TOOLS.giveItem = {run = function(admin, a)
	local p, d = target(a)
	local it = str(a.key, 24) and C.FURNITURE_BY and C.FURNITURE_BY[a.key]
	local n = int(a.amount, 1, 20) or 1
	if not (d and it) then return false, "Pick a player and an item." end
	d.furniture = type(d.furniture) == "table" and d.furniture or {}
	d.furniture[it.key] = (tonumber(d.furniture[it.key]) or 0) + n
	notify(p, "🎁 An admin gave you " .. it.icon .. " " .. it.name .. (n > 1 and (" ×" .. n) or "") .. ".")
	return true, it.key .. " ×" .. n, p, n
end}
TOOLS.removeItem = {danger = true, run = function(admin, a)
	local p, d = target(a)
	local key = str(a.key, 24)
	if not (d and key and type(d.furniture) == "table" and d.furniture[key]) then return false, "They don't have that in storage." end
	d.furniture[key] = nil
	return true, "removed " .. key, p
end}
TOOLS.giveTickets = {run = function(admin, a)
	local p, d = target(a)
	local n = int(a.amount, 1, 100000)
	if not (d and n and F.arcadeData) then return false, "Pick a player and an amount." end
	F.arcadeData(d).tickets += n
	return true, "+" .. n .. " tickets", p, n
end}
TOOLS.giveCar = {run = function(admin, a)
	local p, d = target(a)
	local spec = str(a.key, 16) and C.CAR[a.key]
	if not (d and spec) or spec.pass or spec.rebirths then return false, "Pick a player and a (buyable) car." end
	d.cars[spec.key] = true
	notify(p, "🎁 An admin gave you a " .. spec.name .. "!")
	return true, spec.key, p
end}
TOOLS.removeCar = {danger = true, run = function(admin, a)
	local p, d = target(a)
	local key = str(a.key, 16)
	if not (d and key and d.cars[key]) then return false, "They don't own that car." end
	local active = F.activeCar(p)
	if active and active.key == key then F.despawnCar(p) end
	d.cars[key] = nil
	return true, "removed " .. key, p
end}
TOOLS.bizLevel = {run = function(admin, a)
	local p, d = target(a)
	local key = str(a.key, 20) and C.BIZ[a.key] and a.key
	local lvl = int(a.amount, 0, C.CFG.MAX_LEVEL)
	if not (d and key and lvl) then return false, "Pick a player, a business and a level." end
	if lvl < (d.levels[key] or 0) then return false, "Use a higher level (lowering businesses isn't supported)." end
	d.levels[key] = lvl
	if F.refreshBuilding then pcall(F.refreshBuilding, p, key) end
	if F.refreshWorkers then pcall(F.refreshWorkers, p) end
	return true, key .. " → " .. lvl, p, lvl
end}
TOOLS.fixAll = {run = function(admin, a)
	local p, d = target(a)
	if not d then return false, "Pick a player." end
	for key in pairs(d.problems) do
		d.problems[key] = nil
		pcall(F.problemVisual, p, key, false)
	end
	if F.stockOf then
		for _, b in ipairs(C.BUSINESSES) do
			if (d.levels[b.key] or 0) > 0 then
				local s = F.stockOf(d, b.key)
				s[1], s[2], s[3] = 100, 100, 100
			end
		end
	end
	pcall(F.refreshWorkers, p)
	return true, "fixed problems + restocked", p
end}
TOOLS.hqLevel = {run = function(admin, a)
	local p, d = target(a)
	local lvl = int(a.amount, 0, #(C.HQ_FLOORS or {}))
	if not (d and lvl) then return false, "Pick a player and 0-6." end
	d.hq = type(d.hq) == "table" and d.hq or {}
	d.hq.level = lvl
	return true, "HQ " .. lvl, p, lvl
end}
TOOLS.homeLevel = {run = function(admin, a)
	local p, d = target(a)
	local lvl = int(a.amount, 1, #C.HOME_LEVELS)
	if not (d and lvl and d.home and d.home.lot) then return false, "They need a home lot first." end
	d.home.level = lvl
	local lot = F.homeLot(d)
	if lot then F.buildHome(lot) end
	return true, "home " .. lvl, p, lvl
end}
-- ----- events -----
TOOLS.cityEvent = {run = function(admin, a)
	local key = str(a.key, 20)
	if not key then return false, "Pick an event." end
	local found = false
	for _, e in ipairs(C.EVENTS) do if e.key == key then found = true end end
	if not found then return false, "Unknown event." end
	F.startEvent(os.clock(), key)
	return true, key
end}
TOOLS.megaEvent = {run = function(admin, a)
	local key = str(a.key, 20)
	F.startMega(key)
	return true, tostring(key)
end}
TOOLS.rush = {run = function(admin) if C.DEBUG and C.DEBUG.rush then C.DEBUG.rush(admin, data[admin]) end return true, "rush" end}
TOOLS.influencer = {run = function(admin, a)
	if F.startInfluencer then F.startInfluencer(str(a.key, 20), nil, nil) end
	return true, tostring(a.key or "random")
end}
TOOLS.rareEvent = {run = function(admin, a)
	if C.DEBUG and C.DEBUG.rareEvent then C.DEBUG.rareEvent(admin, data[admin], str(a.key, 20)) end
	return true, tostring(a.key or "random")
end}
TOOLS.funny = {run = function(admin, a)
	if F.funnyEvent then F.funnyEvent(admin, str(a.key, 20)) end
	return true, tostring(a.key or "random")
end}
TOOLS.cinematic = {run = function(admin, a)
	local which = str(a.key, 20) or "opening"
	if which == "evict" and C.DEBUG.cineEvict then C.DEBUG.cineEvict(admin, data[admin])
	elseif C.DEBUG.cineOpening then C.DEBUG.cineOpening(admin, data[admin], nil) end
	return true, which
end}
TOOLS.buzz = {run = function(admin, a)
	local text = C.filterText(admin, tostring(a.text or ""), 1, 120)
	if not text then return false, "Write a (clean) post." end
	F.buzz("📢", text, RGB(255, 210, 60), "Corner Empire")
	return true, "CityBuzz post"
end}
TOOLS.announce = {run = function(admin, a)
	local text = C.filterText(admin, tostring(a.text or ""), 1, 140)
	if not text then return false, "Write a (clean) message." end
	for _, p in ipairs(Players:GetPlayers()) do R.Splash:FireClient(p, "📢 ANNOUNCEMENT", text, RGB(255, 210, 60)) end
	return true, "announcement"
end}
TOOLS.time = {run = function(admin, a)
	local h = tonumber(a.amount)
	if not (C.finite(h) and h >= 0 and h <= 24) then return false, "0-24" end
	Lighting.ClockTime = h
	return true, "time " .. h
end}
-- ----- teleport / interiors -----
TOOLS.gotoPlayer = {run = function(admin, a)
	local p = target(a)
	local r, me = root(p), root(admin)
	if not (r and me) then return false, "No character." end
	F.despawnCar(admin)
	admin.Character:PivotTo(r.CFrame * CF(0, 0, 5))
	return true, "went to", p
end}
TOOLS.bring = {run = function(admin, a)
	local p = target(a)
	local r, me = root(p), root(admin)
	if not (r and me) then return false, "No character." end
	F.despawnCar(p)
	if F.leaveInterior then F.leaveInterior(p) end
	p.Character:PivotTo(me.CFrame * CF(0, 0, -5))
	return true, "brought", p
end}
TOOLS.place = {run = function(admin, a)
	local key = str(a.key, 20)
	if not key then return false, "Pick a place." end
	if not C.teleport then return false, "Teleport isn't ready." end
	C.teleport(admin, data[admin], key)
	return true, key
end}
TOOLS.enterInterior = {run = function(admin, a)
	-- moderation: step into any player's home / business / HQ (bypasses their visitor setting, and is logged)
	local p, d = target(a)
	local key = str(a.key, 12)
	if not (d and key) then return false, "Pick a player and a place." end
	local saved = F.canVisit
	F.canVisit = function() return true end
	local ok = pcall(F.enterInterior, admin, p, key)
	F.canVisit = saved
	return ok, "entered " .. key, p
end}
-- ----- self (fun tools: admins only) -----
TOOLS.fly = {run = function(admin, a) admin:SetAttribute("AdminFly", a.on == true or nil) return true, a.on and "fly on" or "fly off" end}
TOOLS.noclip = {run = function(admin, a) admin:SetAttribute("AdminNoclip", a.on == true or nil) return true, a.on and "noclip on" or "noclip off" end}
TOOLS.speed = {run = function(admin, a)
	local h = hum(admin)
	local n = int(a.amount, 8, 250)
	if not (h and n) then return false, "8-250" end
	h.WalkSpeed = n
	return true, "speed " .. n
end}
TOOLS.jump = {run = function(admin, a)
	local h = hum(admin)
	local n = int(a.amount, 20, 300)
	if not (h and n) then return false, "20-300" end
	h.UseJumpPower = true
	h.JumpPower = n
	return true, "jump " .. n
end}
TOOLS.invisible = {run = function(admin, a)
	local on = a.on == true
	if not admin.Character then return false, "No character." end
	for _, p in ipairs(admin.Character:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Transparency = on and 1 or 0
		elseif p:IsA("Decal") then p.Transparency = on and 1 or 0 end
	end
	admin:SetAttribute("AdminInvisible", on or nil)
	return true, on and "invisible" or "visible"
end}
TOOLS.npc = {run = function(admin)
	local me = root(admin)
	if not me then return false, "No character." end
	for i = #npcs, 1, -1 do if not npcs[i].Parent then table.remove(npcs, i) end end
	if #npcs >= 10 then return false, "10 test NPCs at most." end
	local m = Instance.new("Model")
	m.Name = "AdminNPC"
	local torso = C.P(m, V3(2, 2, 1), me.CFrame * CF(0, 0, -6), RGB(90, 140, 230), Enum.Material.SmoothPlastic, {CanCollide = true, Name = "HumanoidRootPart"})
	torso.Anchored = true
	C.P(m, V3(1.2, 1.2, 1.2), me.CFrame * CF(0, 1.6, -6), RGB(255, 220, 180), Enum.Material.SmoothPlastic, {Name = "Head"})
	for _, x in ipairs({-0.5, 0.5}) do C.P(m, V3(0.9, 2, 0.9), me.CFrame * CF(x, -2, -6), RGB(40, 50, 90)) end
	local h = Instance.new("Humanoid")
	h.DisplayName = "Test NPC"
	h.Parent = m
	m.PrimaryPart = torso
	m.Parent = workspace
	table.insert(npcs, m)
	task.delay(120, function() if m.Parent then m:Destroy() end end)
	return true, "spawned an NPC"
end}
TOOLS.clearNpcs = {run = function()
	for _, m in ipairs(npcs) do if m.Parent then m:Destroy() end end
	npcs = {}
	return true, "cleared NPCs"
end}
-- ----- developer: admins (owners only) -----
TOOLS.addAdmin = {owner = true, run = function(admin, a)
	local name = str(a.text, 20)
	if not (name and name:match("^[%w_]+$")) then return false, "Type a valid Roblox username." end
	-- the SERVER resolves the username to a UserId (never trust an id or name sent by the client)
	local ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
	if not ok or type(uid) ~= "number" or uid <= 0 then return false, "No Roblox user called \"" .. name .. "\"." end
	local ok2, realName = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
	realName = ok2 and realName or name
	if isOwnerId(uid) then return false, realName .. " is already an owner." end
	if not store then return false, "The admin DataStore isn't available (enable Studio API access)." end
	local saved = pcall(function()
		store:UpdateAsync("admins", function(old)
			old = type(old) == "table" and old or {}
			old[tostring(uid)] = {name = realName, by = admin.Name, at = os.time()}
			return old
		end)
	end)
	if not saved then return false, "Couldn't save the admin list. Try again." end
	admins[uid] = {name = realName, by = admin.Name, at = os.time()}
	local p = Players:GetPlayerByUserId(uid)
	if p then F.adminRefresh(p) end
	return true, "added admin " .. realName .. " (" .. uid .. ")", realName
end}
TOOLS.removeAdmin = {owner = true, danger = true, run = function(admin, a)
	local uid = int(a.target, 1)
	if not (uid and admins[uid]) then return false, "That user isn't an admin." end
	if not store then return false, "The admin DataStore isn't available." end
	local saved = pcall(function()
		store:UpdateAsync("admins", function(old)
			old = type(old) == "table" and old or {}
			old[tostring(uid)] = nil
			return old
		end)
	end)
	if not saved then return false, "Couldn't save the admin list. Try again." end
	local name = admins[uid].name
	admins[uid] = nil
	local p = Players:GetPlayerByUserId(uid)
	if p then F.adminRefresh(p) end
	return true, "removed admin " .. name .. " (" .. uid .. ")", name
end}

-- =====================================================================
-- THE PANEL'S DATA
-- =====================================================================
function F.adminState(admin)
	local players = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = data[p]
		table.insert(players, {id = p.UserId, name = p.Name, cash = d and d.cash or 0, income = d and F.incomePerSec(d) or 0, rep = d and d.rep or 0,
			role = roles[p], muted = muted[p] == true, frozen = p:GetAttribute("Frozen") == true, loaded = d ~= nil})
	end
	local list = {}
	for uid, e in pairs(admins) do table.insert(list, {id = uid, name = e.name, by = e.by, at = e.at}) end
	table.sort(list, function(x, y) return x.name < y.name end)
	local events, megas, cars, items, places = {}, {}, {}, {}, {}
	for _, e in ipairs(C.EVENTS) do table.insert(events, {key = e.key, text = e.text}) end
	for _, e in ipairs(C.MEGA_EVENTS or {}) do table.insert(megas, {key = e.key, text = (e.icon or "") .. " " .. (e.title or e.key)}) end
	for _, c in ipairs(C.CARS) do if not c.pass and not c.rebirths then table.insert(cars, {key = c.key, name = c.name}) end end
	for _, it in ipairs(C.FURNITURE or {}) do table.insert(items, {key = it.key, name = it.icon .. " " .. it.name}) end
	for _, k in ipairs({"dealer", "spire", "downtown", "midtown", "industrial", "entertainment", "funzone", "beach", "luxury", "northside", "expansion", "funpark", "race", "rental", "oldtown", "ocean", "rich"}) do
		table.insert(places, k)
	end
	local denies = 0
	for _, e in pairs(denied) do denies += e.count end
	return {role = roles[admin], players = players, admins = list, log = {table.unpack(LOG, 1, math.min(#LOG, 60))}, events = events, megas = megas, cars = cars, items = items, places = places,
		server = {players = #Players:GetPlayers(), uptime = math.floor(os.clock() - STARTED), version = C.VERSION.VERSION, schema = C.VERSION.SCHEMA_VERSION,
			studio = RunService:IsStudio(), denied = denies, place = game.PlaceId, jobId = string.sub(game.JobId, 1, 8)}}
end
local function sendState(admin) R.Menu:FireClient(admin, "adminState", F.adminState(admin)) end

-- =====================================================================
-- THE ONE ENTRY POINT
-- =====================================================================
local pending = {}  -- [admin] = {token, tool, args, exp}
local function run(admin, name, args)
	-- a tool returns: ok, message, target, amount, private (private = don't log, e.g. just looking)
	local pok, ok, msg, tgt, amount, private = pcall(TOOLS[name].run, admin, args)
	if not pok then
		warn("[CornerEmpire][admin] " .. name .. ": " .. tostring(ok))
		R.Menu:FireClient(admin, "adminResult", {ok = false, tool = name, text = "That didn't work (error logged)."})
		return
	end
	R.Menu:FireClient(admin, "adminResult", {ok = ok == true, tool = name, text = tostring(msg or "")})
	if ok == true and not private then log(admin, name, tgt, amount ~= nil and amount or msg) end
	sendState(admin)
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.adm = function(plr, d, a, b)
	-- 1) who's asking? (decided on the server; nothing the client sends counts)
	local role = roles[plr]
	if not role then deny(plr, a) return end
	if a == "state" then sendState(plr) return end
	if a == "confirm" then
		local p = pending[plr]
		pending[plr] = nil
		if not (p and type(b) == "string" and b == p.token and os.clock() <= p.exp) then
			R.Menu:FireClient(plr, "adminResult", {ok = false, tool = "confirm", text = "That confirmation expired. Try again."})
			return
		end
		if TOOLS[p.tool].owner and roles[plr] ~= "owner" then return end
		run(plr, p.tool, p.args)
		return
	end
	-- 2) is it a real tool, and may this role use it?
	local tool = str(a, 20) and TOOLS[a]
	if not tool then return end
	if tool.owner and role ~= "owner" then
		R.Menu:FireClient(plr, "adminResult", {ok = false, tool = a, text = "Only owners can manage admins."})
		log(plr, "DENIED", nil, a .. " (owners only)")
		return
	end
	local args = type(b) == "table" and b or {}
	-- 3) dangerous tools wait for a confirmation round-trip (never one tap)
	if tool.danger then
		local token = HttpService:GenerateGUID(false)
		pending[plr] = {token = token, tool = a, args = args, exp = os.clock() + CFG.confirmSeconds}
		local who = args.target and Players:GetPlayerByUserId(tonumber(args.target) or 0)
		R.Menu:FireClient(plr, "adminConfirm", {token = token, tool = a, text = a .. (who and (" → " .. who.Name) or "") .. (args.amount and (" (" .. tostring(args.amount) .. ")") or "") .. (args.key and (" [" .. tostring(args.key) .. "]") or "")})
		return
	end
	run(plr, a, args)
end
Players.PlayerRemoving:Connect(function(plr)
	roles[plr], groupRank[plr], pending[plr], muted[plr] = nil, nil, nil, nil
end)
end
