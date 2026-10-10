-- v14 Phase C: SECURE TRANSFERS (gifts: both confirm, checked again, write-ahead ledger, recovery from failures
-- at every step, no duplicates) and CO-OWNED BUSINESSES (invites, roles, permissions, contributions, revenue
-- shares, logs, removal while away). Run with: python3 tests/run.py tests/partners_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	local cy = H.addPlayer("Cy", 103)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local dc = T.newGame(cy, 1, 1)
	local cc = H.clientC
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	for _, x in ipairs({d, db, dc}) do x.tut = 0 x.rep = 2000 end
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local function lastMenu(kind, since, who)
		for i = #H.remoteLog, (since or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.dir == "s2c" and e.args[1] == kind and e.player == who then return e.args[2] end
		end
	end
	local function find(root, pred)
		for _, x in ipairs(root:GetDescendants()) do if pred(x) then return x end end
	end
	local ledger = C.LEDGER_STORE()
	local function inbox(uid) local v = rawget(ledger, "_data")["in_" .. uid] return v and v.items or {} end
	local function count(t) local n = 0 for _ in pairs(t) do n += 1 end return n end
	-- cash moves with income too: compare against what the gift should do, with a little room for income
	local function near(x, want, plr) return math.abs(x - want) <= F.incomePerSec(T.data(plr)) * 4 + 1 end

	H.section("A gift: offer → accept → confirm")
	d.cash, db.cash = 100000, 1000
	cc.openModal("partners", true)
	H.task.wait(0.8)
	local box = find(a.PlayerGui, function(x) return x.Name == "GiftAmount_102" end)
	H.check(box ~= nil and find(a.PlayerGui, function(x) return x.Name == "Gift_102" end) ~= nil, "the 🤝 Partners app lists the players here with a gift box")
	box.Text = "5,000"
	local mark = #H.remoteLog
	H.signalOf(find(a.PlayerGui, function(x) return x.Name == "Gift_102" end), "MouseButton1Click"):Fire()
	H.task.wait(0.5)
	local offer = lastMenu("giftOffer", mark, bob)
	H.check(offer and offer.amt == 5000 and offer.from == "Alice", "Bob is offered $5,000 by Alice")
	H.check(near(d.cash, 100000, a), "nothing moves on an offer")
	T.act(cy, "giftAnswer", offer.id, true)
	T.act(a, "giftAnswer", offer.id, true)
	H.task.wait(0.3)
	H.check(lastMenu("giftConfirm", mark, a) == nil, "only Bob can answer it")
	T.act(bob, "giftAnswer", offer.id, true)
	H.task.wait(0.5)
	H.check(lastMenu("giftConfirm", mark, a) ~= nil and cc.PartnersUI.dialog.Visible, "Bob accepts: Alice is asked to confirm (dialog)")
	local cashA, cashB = d.cash, db.cash
	H.signalOf(find(a.PlayerGui, function(x) return x.Name == "DialogYes" end), "MouseButton1Click"):Fire()
	H.task.wait(1.5)
	H.check(near(d.cash, cashA - 5000, a) and near(db.cash, cashB + 5000, bob), string.format("Alice confirms: $5,000 moves (Alice $%s, Bob $%s)", C.fmt(d.cash), C.fmt(db.cash)))
	H.check(count(inbox(102)) == 0 and next(F.xferRec(d).out) == nil, "the ledger is clean afterwards (nothing pending)")
	H.check(F.xferRec(d).log[1].dir == "out" and F.xferRec(db).log[1].dir == "in" and F.xferRec(db).log[1].amt == 5000, "logged on both sides")
	cashA, cashB = d.cash, db.cash
	T.act(a, "giftConfirm", offer.id, true)
	H.task.wait(0.8)
	H.check(near(d.cash, cashA, a) and near(db.cash, cashB, bob), "confirming again does nothing")

	H.section("Gifts: the checks")
	mark = #H.remoteLog
	T.act(a, "giftOffer", 102, 50)
	T.act(a, "giftOffer", 101, 5000)
	T.act(a, "giftOffer", 102, 1e9)
	T.act(a, "giftOffer", 999, 500)
	T.act(a, "giftOffer", 102, "lots")
	H.task.wait(0.3)
	H.check(lastMenu("giftOffer", mark, bob) == nil, "too small, to yourself, more than you have, to nobody, not a number: refused")
	-- declined
	T.act(a, "giftOffer", 102, 1000)
	local o2 = lastMenu("giftOffer", mark, bob)
	T.act(bob, "giftAnswer", o2.id, false)
	H.task.wait(0.3)
	H.check(near(d.cash, cashA, a) and near(db.cash, cashB, bob), "Bob says no thanks: nothing moves")
	-- Alice changes her mind at the last step
	mark = #H.remoteLog
	T.act(a, "giftOffer", 102, 1000)
	local o3 = lastMenu("giftOffer", mark, bob)
	T.act(bob, "giftAnswer", o3.id, true)
	H.task.wait(0.4)
	H.signalOf(find(a.PlayerGui, function(x) return x.Name == "DialogNo" end), "MouseButton1Click"):Fire()
	H.task.wait(0.8)
	H.check(near(d.cash, cashA, a) and near(db.cash, cashB, bob) and lastMenu("giftClosed", mark, bob) ~= nil, "Alice cancels at the confirm: nothing moves, Bob is told")
	-- everything is checked again at the moment it happens
	mark = #H.remoteLog
	T.act(a, "giftOffer", 102, 20000)
	local o4 = lastMenu("giftOffer", mark, bob)
	T.act(bob, "giftAnswer", o4.id, true)
	d.cash = 500
	cashB = db.cash
	T.act(a, "giftConfirm", o4.id, true)
	H.task.wait(0.8)
	H.check(d.cash >= 500 and near(db.cash, cashB, bob), "Alice spent her cash before confirming: refused, nothing moves")
	d.cash = 100000
	-- the daily limit
	local left = F.partnersInfo(a).giftLeft
	mark = #H.remoteLog
	T.act(a, "giftOffer", 102, left + 1)
	H.check(lastMenu("giftOffer", mark, bob) == nil, "a daily limit ($" .. C.fmt(left) .. " left today)")
	-- an offer runs out
	T.act(a, "giftOffer", 102, 1000)
	local o5 = lastMenu("giftOffer", mark, bob)
	H.task.wait(C.PARTNERS.giftExpire + 6)
	T.act(bob, "giftAnswer", o5.id, true)
	H.task.wait(0.3)
	H.check(lastMenu("giftConfirm", mark, a) == nil, "offers expire after " .. C.PARTNERS.giftExpire .. " s")

	H.section("Failures at every step lose nothing and copy nothing")
	-- 1. the write-ahead save fails: refused, cash back
	cashA, cashB = d.cash, db.cash
	local slotP = rawget(T.slotStore(), "_p")
	slotP.UpdateAsync = function() error("simulated save outage") end
	local ok, why = F.ledgerSend(a, 102, "Bob", 3000, "gift")
	slotP.UpdateAsync = nil
	H.check(not ok and why == "save" and near(d.cash, cashA, a) and next(F.xferRec(d).out) == nil and count(inbox(102)) == 0, "the sender's save fails: the transfer never starts, the cash is back")
	-- 2. the delivery fails after the debit was saved: it stays pending (saved) and is delivered later, once
	local ledP = rawget(ledger, "_p")
	ledP.UpdateAsync = function() error("simulated ledger outage") end
	local ok2, txid, delivered = F.ledgerSend(a, 102, "Bob", 3000, "gift")
	ledP.UpdateAsync = nil
	local saved = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(ok2 and not delivered and F.xferRec(d).out[txid] ~= nil and saved.xfer.out[txid] ~= nil and near(d.cash, cashA - 3000, a),
		"the inbox write fails: the debit and the pending transfer are already saved together")
	H.check(near(db.cash, cashB, bob), "...Bob hasn't got it yet")
	F.ledgerTick(a)
	H.task.wait(1)
	H.check(F.xferRec(d).out[txid] == nil and near(db.cash, cashB + 3000, bob), "the retry delivers it")
	F.ledgerTick(a)
	F.ledgerClaim(bob)
	H.task.wait(1)
	H.check(near(db.cash, cashB + 3000, bob), "...exactly once")
	-- 3. the receiver's save fails while claiming: the credit is undone, the items wait in the inbox
	cashB = db.cash
	ledP.UpdateAsync = nil
	-- (deliver without claiming: Bob is "elsewhere" for a moment)
	local realClaim = F.ledgerClaim
	F.ledgerClaim = function() return 0 end
	F.ledgerSend(a, 102, "Bob", 2000, "gift")
	F.ledgerClaim = realClaim
	H.task.wait(0.3)
	H.check(count(inbox(102)) == 1, "a transfer is waiting in Bob's inbox")
	local waiting = next(inbox(102))
	slotP.UpdateAsync = function() error("simulated save outage") end
	F.ledgerClaim(bob)
	slotP.UpdateAsync = nil
	H.check(near(db.cash, cashB, bob) and count(inbox(102)) == 1 and F.xferRec(db).got[waiting] == nil, "Bob's save fails: no credit, it stays in the inbox")
	-- 4. the credit is saved but emptying the inbox fails: no second credit later
	local calls = 0
	ledP.UpdateAsync = function() calls += 1 error("simulated ledger outage") end
	F.ledgerClaim(bob)
	ledP.UpdateAsync = nil
	H.check(near(db.cash, cashB + 2000, bob) and count(inbox(102)) == 1 and calls == 1, "credited and saved; the inbox couldn't be emptied")
	F.ledgerClaim(bob)
	H.task.wait(0.3)
	H.check(near(db.cash, cashB + 2000, bob) and count(inbox(102)) == 0, "next time the inbox is emptied without crediting it again")

	H.section("Co-owned business: invite and roles")
	d.levels.pizza = 3
	F.refreshBuilding(a, "pizza", false)
	calm()
	cc.closeModals()
	cc.openModal("partners", true)
	H.task.wait(0.8)
	H.signalOf(find(a.PlayerGui, function(x) return x.Name == "Invite_pizza" end), "MouseButton1Click"):Fire()
	H.task.wait(0.3)
	mark = #H.remoteLog
	H.signalOf(find(a.PlayerGui, function(x) return x.Name == "InvitePartner_pizza_102" end), "MouseButton1Click"):Fire()
	H.task.wait(0.5)
	local inv = lastMenu("coopInvite", mark, bob)
	H.check(inv and inv.owner == "Alice", "Alice invites Bob into her pizzeria as a partner")
	T.act(cy, "coopAnswer", inv.id, true)
	H.check(C.F.coopRec(d).biz.pizza == nil or C.F.coopRec(d).biz.pizza.members["103"] == nil, "someone else can't take Bob's invitation")
	T.act(bob, "coopAnswer", inv.id, true)
	H.task.wait(0.3)
	local mem = F.coopRec(d).biz.pizza.members["102"]
	H.check(mem and mem.role == "partner" and F.coopRec(db).of["101:pizza"] ~= nil, "Bob accepts: he's a 🤝 Partner (on both saves)")
	-- Cy as manager
	mark = #H.remoteLog
	T.act(a, "coopInvite", "pizza", 103, "manager")
	local inv2 = lastMenu("coopInvite", mark, cy)
	T.act(cy, "coopAnswer", inv2.id, true)
	H.task.wait(0.3)
	H.check(F.coopRec(d).biz.pizza.members["103"].role == "manager", "Cy joins as 🧑‍💼 Manager")
	T.act(a, "coopInvite", "pizza", 102, "partner")
	T.act(a, "coopInvite", "lemonade_nope", 102, "partner")
	T.act(a, "coopInvite", "pizza", 102, "boss")
	H.check(count(F.coopRec(d).biz.pizza.members) == 2, "no double members, made-up businesses or roles")

	H.section("Permissions")
	local door = (F.slotCF(d.plot, "pizza") * CFrame.new(0, 0, 9)).Position
	bob.Character:PivotTo(CFrame.new(door + Vector3.new(0, 3, 0)))
	cy.Character:PivotTo(CFrame.new(door + Vector3.new(2, 3, 0)))
	H.task.wait(0.3)
	H.check(F.cookStart(bob, "pizza", a) and F.cookShift(bob).owner == a, "Bob runs Alice's 🍳 counter")
	H.task.wait(1)
	local sh = F.cookShift(bob)
	local seq = {}
	for i, st in ipairs(sh.order.steps) do seq[i] = st.n end
	H.task.wait(C.KITCHEN.minPerStep * #seq + 0.3)
	local bobCash = db.cash
	F.cookDone(bob, sh.order.id, seq)
	H.check(db.cash > bobCash and F.rushMult(d, "pizza") > 1, "his perfect dish: the tip is his, the sales rush is the pizzeria's")
	F.cookEnd(bob)
	H.check(F.cookStart(cy, "pizza", a), "a Manager can run the counter too")
	F.cookEnd(cy)
	F.coopSet(a, "pizza", 103, "manager", 0)
	local outsider = H.addPlayer("Dee", 104)
	H.task.wait(1)
	local dd = T.newGame(outsider, 1, 1)
	dd.tut = 0
	outsider.Character:PivotTo(CFrame.new(door + Vector3.new(-2, 3, 0)))
	H.task.wait(0.3)
	H.check(not F.cookStart(outsider, "pizza", a), "someone who isn't on the team can't")
	-- paying for an upgrade
	local lvl, aCash, bCash = d.levels.pizza, d.cash, db.cash
	local cost = F.upgradeCost(d, "pizza")
	db.cash = cost + 10
	bCash = db.cash
	T.act(cy, "coopContribute", 101, "pizza")
	H.task.wait(0.3)
	H.check(d.levels.pizza == lvl, "a Manager can't pay for upgrades")
	aCash = d.cash
	F.coopContribute(bob, 101, "pizza")
	H.check(d.levels.pizza == lvl + 1 and bCash - db.cash >= cost - 1 and near(d.cash, aCash, a), "a Partner pays for the next level: the pizzeria grows, Alice's cash is untouched"
		.. string.format(" (Alice %s → %s, Bob paid %s of %s)", C.fmt(aCash), C.fmt(d.cash), C.fmt(bCash - db.cash), C.fmt(cost)))
	H.check(F.coopRec(d).biz.pizza.members["102"].contributed == cost, "...and it's on record ($" .. C.fmt(cost) .. ")")
	calm()

	H.section("Revenue shares")
	T.act(a, "coopSet", "pizza", 102, "partner:10")
	H.check(F.coopRec(d).biz.pizza.members["102"].share == 10, "Alice gives Bob a 10% share")
	T.act(a, "coopSet", "pizza", 102, "partner:80")
	H.check(F.coopRec(d).biz.pizza.members["102"].share == 25, "a share is at most 25%")
	T.act(a, "coopSet", "pizza", 103, "partner:25")
	T.act(a, "coopSet", "pizza", 102, "partner:30")
	T.act(a, "coopSet", "pizza", 103, "partner:30")
	H.check(F.coopRec(d).biz.pizza.members["103"].share == 25, "and 50% for everyone together")
	T.act(a, "coopSet", "pizza", 103, "manager:0")
	T.act(a, "coopSet", "pizza", 102, "partner:10")
	local _, per = F.income(d, os.clock())
	local want = math.floor(per.pizza * C.PARTNERS.payEvery * 0.1)
	aCash, bCash = d.cash, db.cash
	local paid = F.coopPayShares(a)
	H.task.wait(1)
	H.check(paid == want and near(db.cash, bCash + want, bob) and near(d.cash, aCash - want, a), "every 5 min Bob gets 10% of the pizzeria's income: $" .. C.fmt(want) .. " (from Alice's cash)")
	H.check(F.coopRec(d).biz.pizza.members["102"].paid == want and F.xferRec(db).log[1].kind == "share", "logged as a share payment")

	H.section("Leaving and being removed while away")
	T.act(cy, "coopLeave", 101, "pizza")
	H.check(F.coopRec(d).biz.pizza.members["103"] == nil and F.coopRec(dc).of["101:pizza"] == nil, "Cy leaves")
	H.removePlayer(bob)
	H.task.wait(1)
	F.coopRemove(a, "pizza", 102)
	H.check(F.coopRec(d).biz.pizza.members["102"] == nil and count(inbox(102)) == 1, "Alice removes Bob while he's away: a notice waits in his inbox")
	local bob2 = T.join("Bob", 102)
	T.act(bob2, "menuPlay", 1)
	H.task.wait(3)
	F.ledgerClaim(bob2)
	H.task.wait(0.5)
	local db2 = T.data(bob2)
	H.check(db2 and F.coopRec(db2).of["101:pizza"] == nil and count(inbox(102)) == 0, "Bob comes back: the partnership is gone from his side too")
	H.check(db2 and F.xferRec(db2).log[1] ~= nil, "his transfer history came back with his save")

	H.section("The log and saving")
	local log = F.coopRec(d).biz.pizza.log
	local all = {}
	for _, l in ipairs(log) do table.insert(all, l.text) end
	local s = table.concat(all, " | ")
	H.check(s:find("joined") and s:find("paid for level") and s:find("Paid Bob") and s:find("removed"), "the pizzeria's log: " .. s:sub(1, 160))
	F.save(a)
	local rec = rawget(T.slotStore(), "_data")["u101_s1"]
	H.check(rec and type(rec.coop) == "table" and type(rec.xfer) == "table" and rec.coop.biz.pizza.log[1] ~= nil, "partnerships and transfer history are saved")

	-- (the two save failures this test caused on purpose are reported in Output, as they should be)
	local expected = 0
	for i = #H.warnings, 1, -1 do
		if H.warnings[i]:find("simulated save outage", 1, true) then table.remove(H.warnings, i) expected += 1 end
	end
	H.check(expected == 2, "the simulated save failures were reported (" .. expected .. ")")
	T.assertClean("partners")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
