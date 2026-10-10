-- LEDGER (v14): the one safe way money moves from one player to another (gifts, revenue shares). Each player has
-- an inbox in its own DataStore ("CE_Ledger", key in_<userId>), so a transfer works even if the other player is in
-- another server or offline, and NOTHING can be duplicated or lost, whatever crashes when:
--   SEND   1. the sender's debit and the pending transfer (its id) are SAVED TOGETHER first (write-ahead). If that
--             save fails, nothing happened: the cash is put back and the transfer is refused.
--          2. the transfer is written to the receiver's inbox by its id (UpdateAsync: writing it twice is harmless).
--             If that fails it stays pending in the sender's save and is retried (every 30 s, and on the next join).
--   CLAIM  1. the receiver reads the inbox, credits the cash and records the ids it covered, then SAVES.
--             If that save fails, the credit is undone and the items stay in the inbox for next time.
--          2. only then are those ids removed from the inbox. If that step fails, the ids recorded in the save make
--             sure they are never credited twice.
-- Every transfer is logged on both sides (the last 40). A player's ledger work is locked: one operation at a time.
return function(C)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local F, data = C.F, C.data
local fmt, notify = C.fmt, C.notify

local LG = {retryEvery = 30, keepLog = 40, keepGot = 7 * 86400}
C.LEDGER = LG
local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(C.storeName("CE_Ledger")) end)
	if ok then store = s end
end
local function inKey(uid) return "in_" .. tostring(uid) end

local function rec(d)
	local x = d.xfer
	if type(x) ~= "table" then
		x = {}
		d.xfer = x
	end
	x.out = type(x.out) == "table" and x.out or {}
	x.got = type(x.got) == "table" and x.got or {}
	x.log = type(x.log) == "table" and x.log or {}
	x.seq = tonumber(x.seq) or 0
	return x
end
F.xferRec = rec
local function log(d, e)
	local x = rec(d)
	table.insert(x.log, 1, e)
	while #x.log > LG.keepLog do table.remove(x.log) end
end
F.xferLog = log

local busy = {}   -- [plr] = true while a ledger operation for them runs
function F.xferBusy(plr) return busy[plr] == true end
C.LEDGER_STORE = function() return store end

-- write one pending transfer into the receiver's inbox (idempotent by transfer id)
local function deliver(plr, d, txid, e)
	local ok, err = pcall(function()
		store:UpdateAsync(inKey(e.to), function(old)
			old = type(old) == "table" and old or {}
			old.items = type(old.items) == "table" and old.items or {}
			if old.items[txid] == nil then
				old.items[txid] = {amt = e.amt, from = plr.UserId, fromName = plr.Name, kind = e.kind, note = e.note, key = e.key, t = e.t}
			end
			return old
		end)
	end)
	if not ok then return false, err end
	rec(d).out[txid] = nil
	return true
end

-- send `amount` (0 = a notice only) from plr to a user id. Returns ok, transferId or reason, delivered now?
function F.ledgerSend(plr, toUid, toName, amount, kind, note, key)
	local d = data[plr]
	if not (d and store) then return false, "unavailable" end
	if d.noSave then return false, "readonly" end
	amount = tonumber(amount) or -1
	if amount ~= amount or amount < 0 then return false, "amount" end
	amount = math.floor(amount)
	if d.cash < amount then return false, "cash" end
	if busy[plr] then return false, "busy" end
	busy[plr] = true
	local x = rec(d)
	x.seq += 1
	local txid = tostring(plr.UserId) .. "-" .. os.time() .. "-" .. x.seq
	local e = {to = toUid, toName = toName, amt = amount, kind = kind, note = note, key = key, t = os.time()}
	-- 1. write-ahead
	d.cash -= amount
	x.out[txid] = e
	if not F.save(plr) then
		d.cash += amount
		x.out[txid] = nil
		busy[plr] = nil
		return false, "save"
	end
	-- 2. deliver
	local ok = deliver(plr, d, txid, e)
	busy[plr] = nil
	if amount > 0 then log(d, {dir = "out", who = toName, amt = amount, kind = kind, note = note, t = e.t, id = txid, state = ok and "sent" or "pending"}) end
	if ok then
		local to = Players:GetPlayerByUserId(toUid)
		if to and data[to] then task.spawn(F.ledgerClaim, to) end
	end
	return true, txid, ok
end

-- things that arrive in the inbox (notices are amount 0: e.g. "you were removed as a partner")
local KIND_TEXT = {gift = "💸 %s sent you $%s", share = "🤝 Your partner share from %s: $%s"}
function F.ledgerClaim(plr)
	local d = data[plr]
	if not (d and store) or d.noSave then return 0 end
	if busy[plr] then return 0 end
	busy[plr] = true
	local ok, cur = pcall(function() return store:GetAsync(inKey(plr.UserId)) end)
	if not ok or type(cur) ~= "table" or type(cur.items) ~= "table" or next(cur.items) == nil then
		busy[plr] = nil
		return 0
	end
	local x = rec(d)
	local total, fresh = 0, {}
	for txid, it in pairs(cur.items) do
		if type(it) == "table" and not x.got[txid] then
			local amt = math.max(0, math.floor(tonumber(it.amt) or 0))
			x.got[txid] = os.time()
			d.cash += amt
			total += amt
			table.insert(fresh, {id = txid, it = it, amt = amt})
		end
	end
	-- 1. the credit is saved first
	if #fresh > 0 and not F.save(plr) then
		for _, f in ipairs(fresh) do x.got[f.id] = nil end
		d.cash -= total
		busy[plr] = nil
		return 0
	end
	-- 2. then the inbox is emptied of what was credited (or was already credited before)
	pcall(function()
		store:UpdateAsync(inKey(plr.UserId), function(old)
			if type(old) ~= "table" or type(old.items) ~= "table" then return nil end
			for txid in pairs(old.items) do if x.got[txid] then old.items[txid] = nil end end
			return old
		end)
	end)
	busy[plr] = nil
	for _, f in ipairs(fresh) do
		local it = f.it
		if f.amt > 0 then
			log(d, {dir = "in", who = tostring(it.fromName or "?"), amt = f.amt, kind = it.kind, note = it.note, t = tonumber(it.t) or os.time(), id = f.id, state = "received"})
			local fmtStr = KIND_TEXT[it.kind] or "💸 %s sent you $%s"
			notify(plr, string.format(fmtStr, tostring(it.fromName or "Someone"), fmt(f.amt)))
		end
		if F.ledgerNotice then pcall(F.ledgerNotice, plr, d, it) end
	end
	return total
end

-- retry pending sends; pick up what arrived (from this server or another one)
local function tidy(d)
	local x = rec(d)
	local now = os.time()
	for id, t in pairs(x.got) do if type(t) ~= "number" or now - t > LG.keepGot then x.got[id] = nil end end
end
function F.ledgerTick(plr)
	local d = data[plr]
	if not (d and store) or d.noSave or busy[plr] then return end
	local x = rec(d)
	for txid, e in pairs(x.out) do
		if type(e) == "table" and e.to then
			busy[plr] = true
			local ok = deliver(plr, d, txid, e)
			busy[plr] = nil
			if ok then
				for _, l in ipairs(x.log) do if l.id == txid then l.state = "sent" end end
				local to = Players:GetPlayerByUserId(e.to)
				if to and data[to] then task.spawn(F.ledgerClaim, to) end
			end
		else
			x.out[txid] = nil
		end
	end
	tidy(d)
	F.ledgerClaim(plr)
end
task.spawn(function()
	while true do
		task.wait(LG.retryEvery)
		for _, plr in ipairs(Players:GetPlayers()) do
			if data[plr] then pcall(F.ledgerTick, plr) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) busy[plr] = nil end)
end
