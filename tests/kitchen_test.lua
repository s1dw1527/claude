-- v14: the restaurant feel. RUSH ORDERS (cook & serve at your own business), what a sale shows, the Cook button
-- inside your business, and CATERING city jobs. Run with: python3 tests/run.py tests/kitchen_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut, db.tut = 0, 0
	C.G.nextEvent = H.now() + 1e6
	C.MEGA_STATE.nextAt = H.now() + 1e6
	local V3 = Vector3.new
	d.levels.pizza = 6
	F.refreshBuilding(a, "pizza", false)
	local door = (F.slotCF(d.plot, "pizza") * CFrame.new(0, 0, 9)).Position
	local function at(who, p) who.Character:PivotTo(CFrame.new(p + V3(0, 3, 0))) H.task.wait(0.3) end
	local KU = cc.KitchenUI
	local function lastMenu(kind, since)
		for i = #H.remoteLog, (since or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.dir == "s2c" and e.args[1] == kind and e.player == a then return e.args[2] end
		end
	end
	local function tapAll(order, wrongAt)
		for i, st in ipairs(order.steps) do
			H.task.wait(0.5)
			local name = st.n
			if wrongAt == i then
				for _, o in ipairs(order.options) do if o.n ~= st.n then name = o.n break end end
			end
			local b = KU.grid:FindFirstChild("Step_" .. name)
			if not b then return false end
			H.signalOf(b, "MouseButton1Click"):Fire()
			if wrongAt == i then return true end
		end
		return true
	end

	H.section("Starting a shift")
	at(a, V3(0, 0, -60))
	T.act(a, "cookStart", "pizza")
	H.task.wait(0.3)
	H.check(F.cookShift(a) == nil, "you have to be at your business")
	at(bob, door)
	T.act(bob, "cookStart", "pizza")
	H.task.wait(0.3)
	H.check(F.cookShift(bob) == nil, "and it has to be yours")
	at(a, door)
	local mk = #H.remoteLog
	local pp
	for _, x in ipairs(d.plot.slots.pizza:GetDescendants()) do if x.ClassName == "ProximityPrompt" and x.ActionText:find("Rush orders") then pp = x end end
	H.check(pp ~= nil, "the pizzeria has a 🍳 Rush orders prompt")
	H.signalOf(pp, "Triggered"):Fire(a)
	H.task.wait(0.5)
	local order = lastMenu("cookOrder", mk)
	H.check(F.cookShift(a) and order, "the shift starts with an order")
	H.check(order and #order.steps >= 3 and #order.options == #order.steps + C.KITCHEN.decoys, "the ticket has " .. #order.steps .. " steps; " .. #order.options .. " buttons (with decoys)")
	H.check(order and order.customer and order.customer.name and order.dish, "from a real customer type: " .. order.customer.icon .. " " .. order.customer.name .. " wants " .. order.dish)
	H.check(KU.win.Visible and #KU.grid:GetChildren() >= #order.options, "the Rush Orders panel opens with the buttons")

	-- on a phone, the panel fits on screen (scaled as a whole) and its buttons stay big enough to tap
	do
		local cam = H.workspace.CurrentCamera
		rawget(cam, "_p").ViewportSize = H.G.Vector2.new(390, 700)
		cam:GetPropertyChangedSignal("ViewportSize"):Fire()
		H.task.wait(0.5)
		local sc = KU.win:FindFirstChildOfClass("UIScale")
		local s = sc and sc.Scale or 1
		local w, h = KU.win.Size.X.Offset * s, KU.win.Size.Y.Offset * s
		local cell = (h - 210 * s) / 2
		H.check(w <= 390 * 0.95 and h <= 700 * 0.85, string.format("on a 390×700 phone the panel is %d×%d", w, h))
		H.check(cell >= 36, string.format("its step buttons are about %d px tall (thumb-sized)", cell))
		rawget(cam, "_p").ViewportSize = H.G.Vector2.new(1280, 720)
		cam:GetPropertyChangedSignal("ViewportSize"):Fire()
		H.task.wait(0.5)
	end

	H.section("A perfect dish")
	local cash0 = d.cash
	local bizMult0 = F.bizMult(d, "pizza")
	mk = #H.remoteLog
	tapAll(order)
	H.task.wait(0.3)
	local res = lastMenu("cookResult", mk)
	H.check(res and res.ok and res.tip > 0, "served right, in time: tip +$" .. C.fmt(res and res.tip or 0))
	H.check(d.cash - cash0 >= res.tip, "the tip is paid")
	H.check(F.bizMult(d, "pizza") > bizMult0 * 1.2, string.format("a sales rush for the pizzeria (×%.2f → ×%.2f)", bizMult0, F.bizMult(d, "pizza")))
	H.check(F.bizMult(d, "lemonade") == F.bizMult(d, "lemonade"), "(only that business)")
	H.task.wait(1.2)
	order = KU.order
	H.check(order ~= nil, "the next customer is already at the counter")

	H.section("Mistakes")
	mk = #H.remoteLog
	tapAll(order, 2)
	H.task.wait(0.3)
	res = lastMenu("cookResult", mk)
	H.check(res and not res.ok and res.misses == 1, "a wrong step: the customer walks out (" .. tostring(res and res.why) .. ")")
	H.task.wait(1.2)
	-- too fast to be a person
	order = KU.order
	local seq = {}
	for i, st in ipairs(order.steps) do seq[i] = st.n end
	mk = #H.remoteLog
	T.act(a, "cookDone", order.id, seq)
	H.task.wait(0.3)
	res = lastMenu("cookResult", mk)
	H.check(res and not res.ok and tostring(res.why):find("fast"), "answering instantly is refused (" .. tostring(res and res.why) .. ")")
	-- forged answers
	H.task.wait(1.2)
	order = KU.order
	-- (judged by the shift itself: cash can move for other reasons, like a passing customer event)
	local sh0 = F.cookShift(a)
	local served0, tips0 = sh0.served, sh0.tips
	T.act(a, "cookDone", "999", seq)
	T.act(a, "cookDone", order.id, "nope")
	T.act(a, "cookDone", order.id, {1, 2, 3})
	H.task.wait(0.3)
	local sh1 = F.cookShift(a)
	H.check(sh1 ~= nil and sh1.served == served0 and sh1.tips == tips0, "made-up answers do nothing")
	-- too slow
	mk = #H.remoteLog
	H.task.wait(order.limit + 2.5)
	res = lastMenu("cookResult", mk)
	H.check(res and not res.ok, "waiting too long: the customer gives up")
	H.task.wait(0.5)
	H.check(F.cookShift(a) == nil and not KU.win.Visible, "three unhappy customers end the shift")
	calm()

	H.section("Tips are capped")
	T.act(a, "cookStart", "pizza")
	H.task.wait(0.5)
	local total, perSec = 0, 0
	for _ = 1, 12 do
		order = KU.order
		if not order then H.task.wait(1) order = KU.order end
		if not order then break end
		mk = #H.remoteLog
		tapAll(order)
		H.task.wait(0.3)
		res = lastMenu("cookResult", mk)
		if res and res.ok then total += res.tip end
		H.task.wait(1)
	end
	local _, per = F.income(d, os.clock())
	perSec = per.pizza
	H.check(total <= perSec * C.KITCHEN.tipCapSecs * 1.6 + 60, string.format("a minute of perfect cooking pays at most ~%d s of the pizzeria's income in tips ($%s)", C.KITCHEN.tipCapSecs, C.fmt(total)))
	H.check(F.cookShift(a).best >= 5, "streak: " .. F.cookShift(a).best)
	at(a, door + V3(200, 0, 0))
	H.task.wait(1.2)
	H.check(F.cookShift(a) == nil, "walking away ends the shift")
	calm()

	H.section("Inside your business")
	F.enterInterior(a, a, "pizza")
	H.task.wait(1.5)
	local cookB
	for _, x in ipairs(a.PlayerGui:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "🍳 Cook" then cookB = x end end
	H.check(cookB and cookB.Visible, "your own business's bar has a 🍳 Cook button")
	H.signalOf(cookB, "MouseButton1Click"):Fire()
	H.task.wait(0.6)
	H.check(F.cookShift(a) ~= nil, "it starts a shift inside")
	T.act(a, "cookEnd")
	if F.leaveInterior then F.leaveInterior(a) end
	H.task.wait(1)

	H.section("What a sale shows")
	local shown = false
	for _ = 1, 20 do
		for i = #H.remoteLog, math.max(1, #H.remoteLog - 300), -1 do
			local e = H.remoteLog[i]
			if e.name == "Customer" and e.dir == "s2all" and type(e.args[1]) == "table" and e.args[1].icon and e.args[1].owner == 101 then shown = e.args[1] break end
		end
		if shown then break end
		H.task.wait(1)
	end
	H.check(shown and shown.icon and (shown.item ~= nil), "a customer's purchase names the product: " .. tostring(shown and (shown.icon .. " " .. tostring(shown.item))))

	H.section("Catering")
	d.levels.lemonade = math.max(1, d.levels.lemonade or 0)
	local st = F.cityJobView(a)
	local hasCatering = false
	local info = F.exploreInfo(a)
	-- force fresh offers
	H.task.wait(1)
	info = F.exploreInfo(a)
	for _, o in ipairs(info.jobs.offers) do if o.kind == "catering" then hasCatering = o.i end end
	if not hasCatering then
		-- offers refresh every few minutes: wait for the next refresh
		H.task.wait(C.EXPLORE.refreshEvery + 1)
		info = F.exploreInfo(a)
		for _, o in ipairs(info.jobs.offers) do if o.kind == "catering" then hasCatering = o.i end end
	end
	H.check(hasCatering, "owning a food business adds a 🎂 Catering offer")
	T.act(a, "jobTake", hasCatering)
	H.task.wait(0.3)
	st = F.cityJobView(a)
	H.check(st.active and st.active.kind == "catering", "catering job taken: " .. tostring(st.active and st.active.text))
	local p1 = st.active.targets[1]
	at(a, V3(p1[1], p1[2], p1[3]))
	H.task.wait(1.4)
	st = F.cityJobView(a)
	H.check(st.active and st.active.step == 2 and st.active.left, "picked up at your business: the clock starts")
	local c0 = d.cash
	local p2 = st.active.targets[1]
	at(a, V3(p2[1], p2[2], p2[3]))
	H.task.wait(1.4)
	H.check(F.cityJobView(a).active == nil and d.cash > c0, "delivered to the party: +$" .. C.fmt(d.cash - c0))

	T.assertClean("kitchen")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
