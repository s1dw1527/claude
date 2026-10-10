-- PARTNERS (v14): doing business together.
--   GIFTS (secure transfers): A offers B an amount → B accepts → A confirms → the server checks everything again
--     (both still here, the cash is there, today's limit, nobody mid-transfer) → the Ledger moves it (write-ahead,
--     idempotent, recoverable). Offers expire after 60 s; either side can cancel until the last confirm.
--   CO-OWNED BUSINESSES: an owner invites a player into one of their businesses as a
--     🤝 PARTNER (runs the counter, can pay for upgrades, gets a revenue share the owner sets: 0-25%, 50% total) or a
--     🧑‍💼 MANAGER (runs the counter). The invited player accepts (both confirm). The owner can change roles and
--     shares or remove someone; a member can leave. Revenue shares are paid from the owner's cash, out of that
--     business's own income, every 5 minutes while the owner plays, through the Ledger (so offline partners get
--     paid too). Every invite, role change, contribution and payout is in the business's log.
-- The business always stays the owner's (their save, their levels): partners never get to sell, rename or move it.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

local PT = {
	giftMin = 100, giftExpire = 60, giftDayShare = 0.1, giftDayFloor = 25000, giftTier = 2,
	inviteExpire = 120, maxMembers = 3, maxShare = 25, maxShareTotal = 50, payEvery = 300, keepLog = 30,
	roles = {partner = {name = "🤝 Partner", counter = true, contribute = true, share = true}, manager = {name = "🧑‍💼 Manager", counter = true}},
}
C.PARTNERS = PT

local function uidKey(u) return tostring(u) end
local function coop(d)
	local c = d.coop
	if type(c) ~= "table" then
		c = {}
		d.coop = c
	end
	c.biz = type(c.biz) == "table" and c.biz or {}
	c.of = type(c.of) == "table" and c.of or {}
	return c
end
F.coopRec = coop
local function bizRec(d, key)
	local c = coop(d)
	local b = c.biz[key]
	if type(b) ~= "table" then
		b = {}
		c.biz[key] = b
	end
	b.members = type(b.members) == "table" and b.members or {}
	b.log = type(b.log) == "table" and b.log or {}
	return b
end
local function blog(d, key, text)
	local b = bizRec(d, key)
	table.insert(b.log, 1, {t = os.time(), text = text})
	while #b.log > PT.keepLog do table.remove(b.log) end
end
F.coopLog = blog
local function bizName(d, key) return F.bizName and F.bizName(d, key) or BIZ[key].name end
local function here(uid)
	local p = Players:GetPlayerByUserId(tonumber(uid) or 0)
	return (p and data[p]) and p or nil
end
local function member(od, key, uid)
	local b = coop(od).biz[key]
	return b and type(b.members) == "table" and b.members[uidKey(uid)] or nil
end

-- may `actor` do `perm` at `owner`'s business `key`?
function F.coopCan(actor, owner, key, perm)
	if actor == owner then return true end
	local od = owner and data[owner]
	if not (od and actor) then return false end
	local m = member(od, key, actor.UserId)
	local role = m and PT.roles[m.role]
	return role ~= nil and role[perm] == true
end

-- ===================================================================== GIFTS
local offers = {}   -- [id] = {id, from, to, amt, state, expires}
local seq = 0
local function dayKey() return math.floor(os.time() / 86400) end
local function giftLimit(d)
	return math.floor(math.max(PT.giftDayFloor, (tonumber(d.earned) or 0) * PT.giftDayShare))
end
local function sentToday(d)
	local x = F.xferRec(d)
	if type(x.day) ~= "table" or x.day.k ~= dayKey() then x.day = {k = dayKey(), amt = 0} end
	return x.day
end
local function giftCheck(from, to, amt)
	local d, td = data[from], to and data[to]
	if not (d and td) or from == to or not to.Parent then return "That player isn't here." end
	if F.tierIndex(d.rep) < PT.giftTier then return "Gifts unlock at " .. C.REP_TIERS[PT.giftTier].name .. " reputation." end
	if type(amt) ~= "number" or amt ~= amt or amt < PT.giftMin then return "The smallest gift is $" .. fmt(PT.giftMin) .. "." end
	if d.cash < amt then return "You don't have $" .. fmt(amt) .. "." end
	local day = sentToday(d)
	if day.amt + amt > giftLimit(d) then return "Today's gift limit: $" .. fmt(giftLimit(d)) .. " ($" .. fmt(math.max(0, giftLimit(d) - day.amt)) .. " left)." end
	if F.xferBusy(from) or F.xferBusy(to) then return "A transfer is already in progress." end
	if d.noSave or td.noSave then return "Gifts are off while a save is read-only." end
	return nil
end
local function offerView(o) return {id = o.id, from = o.from.Name, to = o.to.Name, amt = o.amt, state = o.state, left = math.max(0, math.ceil(o.expires - os.clock()))} end
function F.giftOffer(plr, toUid, amt)
	amt = math.floor(tonumber(amt) or 0)
	local to = here(toUid)
	local why = giftCheck(plr, to, amt)
	if why then notify(plr, "💸 " .. why) return nil end
	for _, o in pairs(offers) do
		if o.from == plr then notify(plr, "💸 You already have a gift waiting for an answer.") return nil end
	end
	seq += 1
	local o = {id = tostring(seq), from = plr, to = to, amt = amt, state = "offered", expires = os.clock() + PT.giftExpire}
	offers[o.id] = o
	R.Menu:FireClient(to, "giftOffer", offerView(o))
	R.Menu:FireClient(plr, "giftSent", offerView(o))
	notify(plr, "💸 Offered $" .. fmt(amt) .. " to " .. to.Name .. ". Waiting for them to accept.")
	return o
end
function F.giftAnswer(plr, id, yes)
	local o = type(id) == "string" and offers[id]
	if not (o and o.to == plr and o.state == "offered") then return false end
	if os.clock() > o.expires then offers[id] = nil return false end
	if yes ~= true then
		offers[id] = nil
		notify(o.from, "💸 " .. plr.Name .. " declined your gift.")
		R.Menu:FireClient(o.from, "giftClosed", {id = id})
		return true
	end
	o.state = "accepted"
	o.expires = os.clock() + PT.giftExpire
	R.Menu:FireClient(o.from, "giftConfirm", offerView(o))
	notify(plr, "💸 Accepted. Waiting for " .. o.from.Name .. " to confirm.")
	return true
end
function F.giftConfirm(plr, id, yes)
	local o = type(id) == "string" and offers[id]
	if not (o and o.from == plr and o.state == "accepted") then return false end
	offers[id] = nil
	if yes ~= true then
		notify(o.to, "💸 " .. plr.Name .. " cancelled the gift.")
		R.Menu:FireClient(o.to, "giftClosed", {id = id})
		return false
	end
	if os.clock() > o.expires then notify(plr, "💸 That offer expired.") return false end
	-- everything is checked again at the moment it happens
	local why = giftCheck(plr, o.to, o.amt)
	if why then
		notify(plr, "💸 Not sent: " .. why)
		R.Menu:FireClient(o.to, "giftClosed", {id = id})
		return false
	end
	local ok, txid = F.ledgerSend(plr, o.to.UserId, o.to.Name, o.amt, "gift")
	if not ok then
		notify(plr, "💸 Not sent (" .. tostring(txid) .. "). Nothing left your account.")
		R.Menu:FireClient(o.to, "giftClosed", {id = id})
		return false
	end
	sentToday(data[plr]).amt += o.amt
	if F.track then F.track(plr, "gift") end
	notify(plr, "💸 Sent $" .. fmt(o.amt) .. " to " .. o.to.Name .. ".")
	R.Menu:FireClient(o.to, "giftClosed", {id = id, done = true})
	return true
end
function F.giftCancel(plr, id)
	local o = type(id) == "string" and offers[id]
	if not (o and (o.from == plr or o.to == plr)) then return false end
	offers[id] = nil
	local other = o.from == plr and o.to or o.from
	notify(other, "💸 " .. plr.Name .. " cancelled the gift.")
	R.Menu:FireClient(other, "giftClosed", {id = id})
	return true
end

-- ===================================================================== CO-OWNERSHIP
local invites = {}
function F.coopInvite(owner, key, targetUid, role)
	local od = data[owner]
	local target = here(targetUid)
	if not (od and BIZ[key] and PT.roles[role]) then return nil end
	if not target or target == owner then notify(owner, "🤝 That player isn't here.") return nil end
	if (od.levels[key] or 0) <= 0 then notify(owner, "🤝 Open the business first.") return nil end
	local b = bizRec(od, key)
	if b.members[uidKey(target.UserId)] then notify(owner, "🤝 " .. target.Name .. " is already in it.") return nil end
	local n = 0
	for _ in pairs(b.members) do n += 1 end
	if n >= PT.maxMembers then notify(owner, "🤝 A business can have up to " .. PT.maxMembers .. " partners and managers.") return nil end
	seq += 1
	local inv = {id = tostring(seq), owner = owner, target = target, key = key, role = role, expires = os.clock() + PT.inviteExpire}
	invites[inv.id] = inv
	R.Menu:FireClient(target, "coopInvite", {id = inv.id, owner = owner.Name, biz = bizName(od, key), icon = BIZ[key].icon, role = PT.roles[role].name})
	notify(owner, "🤝 Invited " .. target.Name .. " to your " .. bizName(od, key) .. " as " .. PT.roles[role].name .. ".")
	return inv
end
function F.coopAnswer(plr, id, yes)
	local inv = type(id) == "string" and invites[id]
	if not (inv and inv.target == plr) then return false end
	invites[id] = nil
	local owner, key = inv.owner, inv.key
	local od, d = data[owner], data[plr]
	if not (od and d) or os.clock() > inv.expires or (od.levels[key] or 0) <= 0 then notify(plr, "🤝 That invitation isn't valid any more.") return false end
	if yes ~= true then notify(owner, "🤝 " .. plr.Name .. " said no thanks.") return true end
	local b = bizRec(od, key)
	local n = 0
	for _ in pairs(b.members) do n += 1 end
	if n >= PT.maxMembers then notify(plr, "🤝 That business is full.") return false end
	b.members[uidKey(plr.UserId)] = {name = plr.Name, role = inv.role, share = 0, since = os.time(), contributed = 0, paid = 0}
	coop(d).of[uidKey(owner.UserId) .. ":" .. key] = {owner = owner.UserId, ownerName = owner.Name, key = key, role = inv.role, since = os.time()}
	blog(od, key, plr.Name .. " joined as " .. PT.roles[inv.role].name)
	notify(owner, "🤝 " .. plr.Name .. " joined your " .. bizName(od, key) .. "!")
	notify(plr, "🤝 You're now " .. PT.roles[inv.role].name .. " of " .. owner.Name .. "'s " .. bizName(od, key) .. ".")
	if F.track then F.track(owner, "partner") F.track(plr, "partner") end
	F.buzz("🤝", owner.Name .. " and " .. plr.Name .. " now run " .. owner.Name .. "'s " .. bizName(od, key) .. " together!", RGB(120, 200, 160))
	return true
end
local function shareTotal(b, except)
	local t = 0
	for u, m in pairs(b.members) do if u ~= except then t += tonumber(m.share) or 0 end end
	return t
end
function F.coopSet(owner, key, uid, role, share)
	local od = data[owner]
	local m = od and BIZ[key] and member(od, key, uid)
	if not m or not PT.roles[role] then return false end
	share = math.floor(tonumber(share) or 0)
	if share ~= share or share < 0 then return false end
	if not PT.roles[role].share then share = 0 end
	share = math.min(share, PT.maxShare)
	local b = bizRec(od, key)
	if shareTotal(b, uidKey(uid)) + share > PT.maxShareTotal then
		notify(owner, "🤝 All the shares together can be at most " .. PT.maxShareTotal .. "%.")
		return false
	end
	local changed = m.role ~= role or (tonumber(m.share) or 0) ~= share
	m.role, m.share = role, share
	if changed then blog(od, key, m.name .. ": " .. PT.roles[role].name .. (share > 0 and (", " .. share .. "% share") or "")) end
	local p = here(uid)
	if p then
		local of = coop(data[p]).of[uidKey(owner.UserId) .. ":" .. key]
		if of then of.role = role end
		if changed then notify(p, "🤝 " .. owner.Name .. " set you to " .. PT.roles[role].name .. (share > 0 and (" with a " .. share .. "% share") or "") .. " at their " .. bizName(od, key) .. ".") end
	end
	return true
end
local function dropOf(uid, ownerUid, key)
	local p = here(uid)
	if p then
		coop(data[p]).of[uidKey(ownerUid) .. ":" .. key] = nil
		return true
	end
	return false
end
function F.coopRemove(owner, key, uid)
	local od = data[owner]
	local m = od and BIZ[key] and member(od, key, uid)
	if not m then return false end
	bizRec(od, key).members[uidKey(uid)] = nil
	blog(od, key, m.name .. " was removed")
	if not dropOf(uid, owner.UserId, key) then
		-- they're not here: a notice in their inbox does it when they're back
		F.ledgerSend(owner, tonumber(uid), m.name, 0, "coopRemoved", nil, key)
	else
		notify(here(uid), "🤝 " .. owner.Name .. " ended your partnership in their " .. bizName(od, key) .. ".")
	end
	notify(owner, "🤝 " .. m.name .. " is no longer part of your " .. bizName(od, key) .. ".")
	return true
end
function F.coopLeave(plr, ownerUid, key)
	local d = data[plr]
	local k = uidKey(ownerUid) .. ":" .. tostring(key)
	local of = d and coop(d).of[k]
	if not of then return false end
	coop(d).of[k] = nil
	local owner = here(ownerUid)
	if owner then
		local od = data[owner]
		local m = member(od, key, plr.UserId)
		if m then
			bizRec(od, key).members[uidKey(plr.UserId)] = nil
			blog(od, key, plr.Name .. " left")
			notify(owner, "🤝 " .. plr.Name .. " left your " .. bizName(od, key) .. ".")
		end
	else
		F.ledgerSend(plr, tonumber(ownerUid), of.ownerName, 0, "coopLeft", nil, key)
	end
	notify(plr, "🤝 You left " .. tostring(of.ownerName) .. "'s business.")
	return true
end
-- notices from the Ledger (the other side wasn't here when it happened)
function F.ledgerNotice(plr, d, it)
	if it.kind == "coopRemoved" and it.key then
		if coop(d).of[uidKey(it.from) .. ":" .. it.key] then
			coop(d).of[uidKey(it.from) .. ":" .. it.key] = nil
			notify(plr, "🤝 " .. tostring(it.fromName) .. " ended your partnership while you were away.")
		end
	elseif it.kind == "coopLeft" and it.key and BIZ[it.key] then
		local b = coop(d).biz[it.key]
		if b and type(b.members) == "table" and b.members[uidKey(it.from)] then
			b.members[uidKey(it.from)] = nil
			blog(d, it.key, tostring(it.fromName) .. " left")
			notify(plr, "🤝 " .. tostring(it.fromName) .. " left your " .. bizName(d, it.key) .. " while you were away.")
		end
	end
end
-- a partner pays for the next upgrade of the owner's business (the owner must be here: their business is live)
function F.coopContribute(plr, ownerUid, key)
	local owner = here(ownerUid)
	local d = data[plr]
	if not (d and owner and BIZ[key]) then notify(plr, "🤝 The owner has to be in this server.") return false end
	if not F.coopCan(plr, owner, key, "contribute") then return false end
	local od = data[owner]
	local lvl = od.levels[key] or 0
	if lvl <= 0 or lvl >= C.CFG.MAX_LEVEL then return false end
	local cost = F.upgradeCost(od, key)
	if d.cash < cost then notify(plr, "🤝 The next upgrade costs $" .. fmt(cost) .. ".") return false end
	-- the payer's cash goes in, the owner's business upgrades, the owner's own cash is untouched
	d.cash -= cost
	od.cash += cost
	F.buyUpgrade(owner, od, key)
	if (od.levels[key] or 0) <= lvl then
		od.cash -= cost
		d.cash += cost
		return false
	end
	local m = member(od, key, plr.UserId)
	m.contributed = (tonumber(m.contributed) or 0) + cost
	blog(od, key, plr.Name .. " paid for level " .. (lvl + 1) .. " ($" .. fmt(cost) .. ")")
	notify(owner, "🤝 " .. plr.Name .. " paid for your " .. bizName(od, key) .. "'s level " .. (lvl + 1) .. " upgrade!")
	notify(plr, "🤝 You paid $" .. fmt(cost) .. " for " .. owner.Name .. "'s " .. bizName(od, key) .. " (level " .. (lvl + 1) .. ").")
	return true
end
-- revenue shares: out of the business's own income, while the owner plays
function F.coopPayShares(owner)
	local od = data[owner]
	if not od then return 0 end
	local _, per = F.income(od, os.clock())
	local paid = 0
	for key, b in pairs(coop(od).biz) do
		if BIZ[key] and type(b.members) == "table" then
			for uid, m in pairs(b.members) do
				local share = tonumber(m.share) or 0
				if share > 0 and PT.roles[m.role] and PT.roles[m.role].share then
					local amt = math.floor((per[key] or 0) * PT.payEvery * share / 100)
					if amt > 0 and od.cash >= amt then
						local ok, txid = F.ledgerSend(owner, tonumber(uid), m.name, amt, "share", bizName(od, key), key)
						if ok then
							m.paid = (tonumber(m.paid) or 0) + amt
							paid += amt
							blog(od, key, "Paid " .. m.name .. " $" .. fmt(amt) .. " (" .. share .. "% share)")
						else
							warn("[Partners] share not sent: " .. tostring(txid))
						end
					end
				end
			end
		end
	end
	return paid
end

-- ===================================================================== INFO
function F.partnersInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local info = {players = {}, mine = {}, of = {}, offers = {}, log = {}, giftLeft = math.max(0, giftLimit(d) - sentToday(d).amt), giftMin = PT.giftMin,
		giftsOn = F.tierIndex(d.rep) >= PT.giftTier, maxShare = PT.maxShare}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= plr and data[p] then table.insert(info.players, {uid = p.UserId, name = p.Name}) end
	end
	for _, b in ipairs(C.BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 then
			local br = coop(d).biz[b.key]
			local members = {}
			if br and type(br.members) == "table" then
				for uid, m in pairs(br.members) do
					table.insert(members, {uid = tonumber(uid), name = m.name, role = m.role, roleName = PT.roles[m.role] and PT.roles[m.role].name or m.role,
						share = tonumber(m.share) or 0, contributed = tonumber(m.contributed) or 0, paid = tonumber(m.paid) or 0, here = here(uid) ~= nil})
				end
			end
			local log = {}
			for i = 1, math.min(5, br and #br.log or 0) do table.insert(log, br.log[i].text) end
			table.insert(info.mine, {key = b.key, name = bizName(d, b.key), icon = b.icon, members = members, log = log})
		end
	end
	for k, of in pairs(coop(d).of) do
		if type(of) == "table" and BIZ[of.key] then
			local owner = here(of.owner)
			local e = {id = k, owner = of.owner, ownerName = of.ownerName, key = of.key, icon = BIZ[of.key].icon, role = of.role,
				roleName = PT.roles[of.role] and PT.roles[of.role].name or of.role, ownerHere = owner ~= nil}
			if owner then
				local od = data[owner]
				local m = member(od, of.key, plr.UserId)
				e.biz = bizName(od, of.key)
				e.level = od.levels[of.key] or 0
				e.share = m and m.share or 0
				e.canContribute = m ~= nil and PT.roles[m.role] and PT.roles[m.role].contribute == true and e.level < C.CFG.MAX_LEVEL
				e.cost = e.canContribute and F.upgradeCost(od, of.key) or nil
				e.log = {}
				local br = coop(od).biz[of.key]
				for i = 1, math.min(5, br and #br.log or 0) do table.insert(e.log, br.log[i].text) end
			end
			table.insert(info.of, e)
		end
	end
	for _, o in pairs(offers) do
		if o.from == plr or o.to == plr then table.insert(info.offers, offerView(o)) end
	end
	for i, l in ipairs(F.xferRec(d).log) do
		if i > 10 then break end
		table.insert(info.log, {dir = l.dir, who = l.who, amt = l.amt, kind = l.kind, state = l.state, t = l.t})
	end
	return info
end

C.ACTIONS = C.ACTIONS or {}
local function refresh(plr) local i = F.partnersInfo(plr) if i then R.Menu:FireClient(plr, "partners", i) end end
F.partnersRefresh = refresh
C.ACTIONS.partnersInfo = function(plr) refresh(plr) end
C.ACTIONS.giftOffer = function(plr, d, a, b) if F.giftOffer(plr, a, b) then refresh(plr) end end
C.ACTIONS.giftAnswer = function(plr, d, a, b) F.giftAnswer(plr, a, b) end
C.ACTIONS.giftConfirm = function(plr, d, a, b) F.giftConfirm(plr, a, b) refresh(plr) end
C.ACTIONS.giftCancel = function(plr, d, a) F.giftCancel(plr, a) end
C.ACTIONS.coopInvite = function(plr, d, a, b, c) F.coopInvite(plr, a, b, c) end
C.ACTIONS.coopAnswer = function(plr, d, a, b) if F.coopAnswer(plr, a, b) then refresh(plr) end end
C.ACTIONS.coopSet = function(plr, d, a, b, c)
	-- (role and share come together as "role:share")
	if type(c) ~= "string" then return end
	local role, share = c:match("^(%a+):(%d+)$")
	if role and F.coopSet(plr, a, b, role, tonumber(share)) then refresh(plr) end
end
C.ACTIONS.coopRemove = function(plr, d, a, b) if F.coopRemove(plr, a, b) then refresh(plr) end end
C.ACTIONS.coopLeave = function(plr, d, a, b) if F.coopLeave(plr, a, b) then refresh(plr) end end
C.ACTIONS.coopContribute = function(plr, d, a, b) if F.coopContribute(plr, a, b) then refresh(plr) end end

task.spawn(function()
	local last = {}
	while true do
		task.wait(5)
		local now = os.clock()
		for id, o in pairs(offers) do
			if now > o.expires or not o.from.Parent or not o.to.Parent then
				offers[id] = nil
				if o.from.Parent then R.Menu:FireClient(o.from, "giftClosed", {id = id}) end
				if o.to.Parent then R.Menu:FireClient(o.to, "giftClosed", {id = id}) end
			end
		end
		for id, inv in pairs(invites) do if now > inv.expires then invites[id] = nil end end
		for _, plr in ipairs(Players:GetPlayers()) do
			if data[plr] then
				if not last[plr] then last[plr] = now
				elseif now - last[plr] >= PT.payEvery then
					last[plr] = now
					pcall(F.coopPayShares, plr)
				end
			end
		end
		for p in pairs(last) do if not p.Parent then last[p] = nil end end
	end
end)
end
