-- v17: the 🛍️ CITY BAZAAR. The same stock on every server for the same 5-minute window (worked out from the clock),
-- clean restock boundaries, rarity odds as configured, per-player limits per restock that survive a rejoin, cash
-- only (the client never sends a price), wrong-restock and not-enough-cash refusals, the storage cap, no selling
-- back, the stall in the plaza, restock announcements only for Epic or better, and the phone app.
-- Run with: python3 tests/run.py tests/bazaar_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	d.tut = 0
	d.frozenUntil = H.now() + 1e7   -- (no income ticking in the middle of exact cash checks)
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local W = C.BAZAAR.window
	local clock = 1750000000
	C.bazaarClock = function() return clock end
	local RIDX = {}
	for i, r in ipairs(C.BAZAAR_RARITY) do RIDX[r.key] = i end

	H.section("The same stock everywhere")
	local w = F.bazaarWindow(clock)
	local s1, s2 = F.bazaarStock(w), F.bazaarStock(w)
	local same = #s1 == C.BAZAAR.slots
	for i = 1, #s1 do if s1[i].key ~= s2[i].key or s1[i].rarity ~= s2[i].rarity then same = false end end
	H.check(same, "the same 5-minute window always gives the same " .. C.BAZAAR.slots .. " items (every server works it out from the clock alone)")
	-- a far-away window computed twice (no cache) still matches
	local far = w + 99991
	local f1 = {}
	for i, s in ipairs(F.bazaarStock(far)) do f1[i] = s.key end
	for k = 1, 6 do F.bazaarStock(far + 10 + k) end   -- (pushes it out of the small cache)
	local again = true
	for i, s in ipairs(F.bazaarStock(far)) do if f1[i] ~= s.key then again = false end end
	H.check(again, "worked out again from scratch: identical")
	local wa, ea = F.bazaarWindow(w * W + W - 1)
	local wb = F.bazaarWindow(w * W + W)
	H.check(wa == w and wb == w + 1 and ea == (w + 1) * W, "restocks exactly every " .. W .. " s (the last second still belongs to the old stock)")
	local dupFree = true
	local seen = {}
	for _, s in ipairs(s1) do if seen[s.key] then dupFree = false end seen[s.key] = true end
	H.check(dupFree, "no item twice in one restock")

	H.section("Rarity odds")
	local count, slots = {}, 0
	for k = 1, 20000 do
		for _, s in ipairs(F.bazaarStock(w + 200000 + k)) do
			count[s.rarity] = (count[s.rarity] or 0) + 1
			slots += 1
		end
	end
	local ok, desc = true, {}
	for _, r in ipairs(C.BAZAAR_RARITY) do
		local got = (count[r.key] or 0) / slots
		table.insert(desc, string.format("%s %.2f%%", r.key, got * 100))
		if math.abs(got - r.chance) > math.max(0.01, r.chance * 0.35) then ok = false end
	end
	H.check(ok and (count.mythic or 0) > 0, "over 20,000 restocks the odds match the config: " .. table.concat(desc, ", "))

	H.section("Buying")
	-- a window with a common item in slot 1
	local cw
	for k = 0, 500 do
		if F.bazaarStock(w + k)[1].rarity == "common" then cw = w + k break end
	end
	clock = cw * W + 10
	local info = F.bazaarInfo(a)
	local sl = info.slots[1]
	H.check(info.win == cw and #info.slots == 6 and sl.left == sl.qty and sl.price >= C.BAZAAR_RARITY[1].base and info.endsIn == W - 10, "the app gets 6 slots, prices, limits and the countdown (" .. info.endsIn .. " s)")
	d.cash = 1e6
	local before = d.cash
	local n0 = tonumber(d.furniture[sl.key]) or 0
	T.act(a, "bazaarBuy", 1, cw)
	H.task.wait(0.5)
	H.check(d.cash == before - sl.price and (tonumber(d.furniture[sl.key]) or 0) == n0 + 1, "bought: -$" .. sl.price .. ", a " .. sl.name .. " in furniture storage")
	for _ = 2, sl.qty + 1 do
		T.act(a, "bazaarBuy", 1, cw)
		H.task.wait(0.5)
	end
	H.check((tonumber(d.furniture[sl.key]) or 0) == n0 + sl.qty and F.bazaarInfo(a).slots[1].left == 0, "the limit is " .. sl.qty .. " per restock: the next buy is refused")
	-- an old restock id: refused
	local c1 = d.cash
	T.act(a, "bazaarBuy", 2, cw - 1)
	H.task.wait(0.5)
	H.check(d.cash == c1, "buying from a restock that's gone is refused (the client said which one it saw)")
	-- the client can't send a price
	T.act(a, "bazaarBuy", 2, cw, 1)
	H.task.wait(0.5)
	local s2p = F.bazaarInfo(a).slots[2].price
	H.check(d.cash == c1 - s2p, "the server's price is what's paid ($" .. s2p .. "), whatever the client sends")
	-- not enough cash
	d.cash = 10
	T.act(a, "bazaarBuy", 3, cw)
	H.task.wait(0.5)
	H.check(d.cash == 10, "not enough cash: nothing happens")
	-- bazaar items can't be sold back (no farming)
	d.cash = 0
	H.check(not F.sellFurniture(a, sl.key) and d.cash == 0, "Bazaar items can't be sold back for cash")
	-- a full storage
	d.cash = 1e9
	local saved = d.furniture
	d.furniture = {sofa = 120}
	H.check(not F.bazaarBuy(a, 3, cw) and d.furniture.sofa == 120, "a full storage (120) refuses the buy")
	d.furniture = saved
	-- prices scale with income
	H.check(F.bazaarPrice(d, "common") >= C.BAZAAR_RARITY[1].base and F.bazaarPrice(d, "mythic") >= C.BAZAAR_RARITY[6].base, "the price is never below the rarity's base")

	H.section("The phone app")
	local cc = H.clientC
	cc.closeModals()
	cc.openModal("bazaar", true)
	H.task.wait(1.5)
	local m = cc.modals.bazaar
	local function f(n) for _, x in ipairs(m.frame:GetDescendants()) do if x.Name == n then return x end end end
	H.check(m.frame.Visible and f("Slot6") and f("Buy1") and f("BazaarTimer") and f("BazaarTimer").Text:find("RESTOCK IN", 1, true), "🛍️ Bazaar: 6 cards with price pills and the restock countdown")
	d.cash = 1e9
	local k3 = F.bazaarStock(cw)[3].key
	local before2 = tonumber(d.furniture[k3]) or 0
	H.signalOf(f("Buy3"), "MouseButton1Click"):Fire()
	H.task.wait(1)
	H.check((tonumber(d.furniture[k3]) or 0) == before2 + 1, "tapping a price pill buys it")
	cc.closeModals()

	H.section("Limits survive a rejoin, reset on a restock")
	H.task.wait(1)
	H.removePlayer(a)
	H.task.wait(3)
	local a2 = H.addPlayer("Alice", 101)
	H.task.wait(2)
	T.act(a2, "menuPlay", 1)
	H.task.wait(3)
	local d2 = T.data(a2)
	H.check(d2 and F.bazaarInfo(a2).slots[1].left == 0, "after leaving and rejoining: still bought out (it's in the save)")
	clock = (cw + 1) * W + 5
	H.check(F.bazaarInfo(a2).slots[1].left == F.bazaarInfo(a2).slots[1].qty, "the next restock: fresh limits")

	H.section("The stall and announcements")
	H.task.wait(3)
	local sign = C.WORLD:FindFirstChild("BazaarSign")
	local sg = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
	local tl = sg and sg:FindFirstChildWhichIsA("TextLabel")
	H.check(tl and tl.Text:find("CITY BAZAAR", 1, true) and C.WORLD:FindFirstChild("BazaarCounter"):FindFirstChildOfClass("ProximityPrompt") ~= nil,
		"a stall in the plaza: the best item in stock on the sign and a prompt to browse")
	d2.tut = 0
	local epicW, plainW
	for k = 2, 3000 do
		local best = F.bazaarBest(cw + k)
		if not epicW and RIDX[best.rarity] >= RIDX.epic then epicW = cw + k end
		if not plainW and RIDX[best.rarity] <= RIDX.rare then plainW = cw + k end
		if epicW and plainW then break end
	end
	clock = plainW * W + 1
	local mark = #H.remoteLog
	H.task.wait(4)
	local heard = false
	for _, msg in ipairs(T.announcesSince(mark, a2)) do if tostring(msg):find("RESTOCK", 1, true) then heard = true end end
	H.check(not heard, "an ordinary restock isn't announced")
	clock = epicW * W + 1
	mark = #H.remoteLog
	H.task.wait(4)
	heard = false
	for _, msg in ipairs(T.announcesSince(mark, a2)) do if tostring(msg):find("RESTOCK", 1, true) then heard = true end end
	H.check(heard, "a restock with an Epic or better is announced (" .. F.bazaarBest(epicW).rarity .. ")")

	T.assertClean("bazaar")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
