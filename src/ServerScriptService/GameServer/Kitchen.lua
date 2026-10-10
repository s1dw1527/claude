-- KITCHEN (v14): RUSH ORDERS. Run your own counter for a while: customers (the city's real customer types: students
-- love pizza, office workers want coffee...) order one of YOUR products, the ticket shows its recipe, and you tap the
-- steps in order before they lose patience (dough → sauce → cheese → bake).
--   * a perfect dish: a tip (seconds of that business's own income, more with a streak), and a SALES RUSH for that
--     business (+25% per dish for 20 s, up to +100%) — the street outside gets busier while you cook
--   * a wrong step or a late dish: the customer leaves unhappy, the streak resets; three misses end the shift
-- Everything is decided here: the order (steps, decoys, time limit) is made on the server, the client only sends
-- the steps it tapped. Too fast to be human is refused; tips are capped per minute; one order at a time; walk away
-- and the shift ends. Passive income keeps running either way: this is a boost, never a requirement.
return function(C)
local Players = game:GetService("Players")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

local K = {
	baseTime = 3, perStep = 1.7,        -- seconds a customer waits: baseTime + perStep × steps
	minPerStep = 0.3,                   -- faster than this per step isn't a person tapping
	decoys = 2, tipSecs = 6, streakBonus = 0.15, streakMax = 2,
	rushPer = 0.25, rushMax = 1.0, rushTime = 20,
	tipCapSecs = 60,                    -- tips in any minute: at most 60 s of that business's income
	misses = 3, walkAway = 45, gap = 0.8,
}
C.KITCHEN = K

-- ===== recipes: ordered steps (icon, label) and a pool of wrong-but-plausible extras =====
local S = function(icon, name) return {i = icon, n = name} end
local RECIPES = {
	lemonade = {steps = {S("🍋", "Squeeze"), S("🍬", "Sugar"), S("💧", "Water"), S("🧊", "Ice"), S("🌿", "Mint")}, extra = {S("🧂", "Salt"), S("🌶️", "Chili"), S("☕", "Coffee")}},
	icecream = {steps = {S("🥣", "Cup"), S("🍦", "Scoop"), S("🍫", "Fudge"), S("🍓", "Berries"), S("🍒", "Cherry")}, extra = {S("🧂", "Salt"), S("🔥", "Toast"), S("🥒", "Pickle")}},
	bakery = {steps = {S("🌾", "Flour"), S("🥚", "Eggs"), S("🧈", "Butter"), S("🔥", "Bake"), S("🍰", "Frost")}, extra = {S("🧊", "Freeze"), S("🐟", "Fish"), S("🌶️", "Chili")}},
	coffee = {steps = {S("⚙️", "Grind"), S("💧", "Brew"), S("🥛", "Steam milk"), S("🎨", "Latte art"), S("🍯", "Syrup")}, extra = {S("🧂", "Salt"), S("🧊", "Ice cubes"), S("🍋", "Lemon")}},
	pizza = {steps = {S("🫓", "Dough"), S("🍅", "Sauce"), S("🧀", "Cheese"), S("🍄", "Toppings"), S("🔥", "Bake")}, extra = {S("🍫", "Chocolate"), S("🍦", "Ice cream"), S("🥒", "Pickles")}},
	arcade = {steps = {S("🪙", "Tokens"), S("🕹️", "Start game"), S("🏆", "High score"), S("🎟️", "Tickets"), S("🧸", "Prize")}, extra = {S("🔌", "Unplug"), S("💤", "Nap"), S("🧹", "Sweep")}},
	tech = {steps = {S("💡", "Idea"), S("💻", "Code"), S("🧪", "Test"), S("🐛", "Fix bug"), S("🚀", "Ship")}, extra = {S("☕", "Coffee break"), S("🔥", "Delete it"), S("📠", "Fax")}},
	factory = {steps = {S("📦", "Parts"), S("🔧", "Assemble"), S("🔍", "Inspect"), S("🏷️", "Label"), S("🚚", "Load truck")}, extra = {S("🧁", "Cupcake"), S("🎈", "Balloon"), S("💤", "Nap")}},
}
C.RECIPES = RECIPES

-- ===== runtime state (nothing here is saved) =====
local shifts = {}       -- [plr] = {key, order, streak, best, served, tips, misses, tipWindow = {{t, amount}}}
local rush = setmetatable({}, {__mode = "k"})   -- [d] = {[key] = {mult, untilT}}
-- the sales rush multiplier for a business (Systems.bizMult)
function F.rushMult(d, key)
	local r = rush[d] and rush[d][key]
	if not r then return 1 end
	if os.clock() > r.untilT then rush[d][key] = nil return 1 end
	return 1 + r.mult
end
local function rootOf(p) return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function doorOf(d, key)
	if not (d and d.plot and F.slotCF) then return nil end
	return (F.slotCF(d.plot, key) * CF(0, 0, 9)).Position
end
local function atBusiness(plr, d, key)
	if plr:GetAttribute("Interior") == key and plr:GetAttribute("InteriorOwner") == plr.UserId then return true end
	local root, door = rootOf(plr), doorOf(d, key)
	return root and door and (V3(root.Position.X, 0, root.Position.Z) - V3(door.X, 0, door.Z)).Magnitude <= K.walkAway or false
end
local function shuffled(t)
	local out = table.clone(t)
	for i = #out, 2, -1 do
		local j = math.random(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end
-- which customer orders: weighted by how much each customer type likes this business
local function pickCustomer(key)
	local total, pool = 0, {}
	for _, t in ipairs(C.NPC_TYPES) do
		local w = (t.likes and t.likes[key]) or 0.3
		total += w
		table.insert(pool, {t = t, w = w})
	end
	local r = math.random() * total
	for _, e in ipairs(pool) do
		r -= e.w
		if r <= 0 then return e.t end
	end
	return pool[1].t
end
local CUSTOMER_NAMES = {office = "Office worker", family = "Family", student = "Student", gym = "Gym fan", builder = "Builder", rich = "Rich regular", tourist = "Tourist", kid = "Kid"}

local function newOrder(plr, sh)
	local d = data[plr]
	local key = sh.key
	local rec = RECIPES[key]
	local lvl = d.levels[key] or 1
	local n = math.clamp(3 + math.floor(lvl / 4), 3, #rec.steps)
	local steps = {}
	for i = 1, n do steps[i] = rec.steps[i] end
	-- the dish is one of the player's own products (named by them), or the business's classic
	local list = F.productsOf and F.productsOf(d, key) or {}
	local p = #list > 0 and list[math.random(#list)] or nil
	local cust = pickCustomer(key)
	local options = {}
	for _, st in ipairs(steps) do table.insert(options, st) end
	for _, x in ipairs(shuffled(rec.extra)) do
		if #options >= n + K.decoys then break end
		table.insert(options, x)
	end
	local o = {id = tostring(math.random(1e6, 9e6)), steps = steps, sentAt = os.clock(), limit = K.baseTime + K.perStep * n,
		dish = p and p.name or BIZ[key].name, cust = cust}
	sh.order = o
	local view = {}
	for _, st in ipairs(steps) do table.insert(view, {i = st.i, n = st.n}) end
	local opts = {}
	for _, st in ipairs(shuffled(options)) do table.insert(opts, {i = st.i, n = st.n}) end
	R.Menu:FireClient(plr, "cookOrder", {id = o.id, key = key, icon = BIZ[key].icon, dish = o.dish, steps = view, options = opts, limit = o.limit,
		customer = {icon = cust.icon, name = CUSTOMER_NAMES[cust.key] or "Customer"}, streak = sh.streak, served = sh.served, tips = sh.tips,
		rush = F.rushMult(d, key) - 1, bizName = F.bizName and F.bizName(d, key) or BIZ[key].name})
end
local function endShift(plr, why)
	local sh = shifts[plr]
	if not sh then return end
	shifts[plr] = nil
	R.Menu:FireClient(plr, "cookEnd", {served = sh.served, tips = sh.tips, best = sh.best, why = why})
	if sh.served > 0 then
		R.Splash:FireClient(plr, "🍳 SHIFT OVER", sh.served .. " served  •  $" .. fmt(sh.tips) .. " in tips  •  best streak " .. sh.best, RGB(255, 200, 90))
	elseif why then
		notify(plr, "🍳 " .. why)
	end
end
F.cookEnd = endShift
function F.cookStart(plr, key)
	local d = data[plr]
	if not (d and BIZ[key] and RECIPES[key]) then return false end
	if (d.levels[key] or 0) <= 0 then notify(plr, "🍳 You don't own a " .. BIZ[key].name .. " yet.") return false end
	if not atBusiness(plr, d, key) then notify(plr, "🍳 Go to your " .. BIZ[key].name .. " first.") return false end
	if shifts[plr] then endShift(plr) end
	shifts[plr] = {key = key, streak = 0, best = 0, served = 0, tips = 0, misses = 0, tipWindow = {}}
	newOrder(plr, shifts[plr])
	if F.guideTip then F.guideTip(plr, "rushOrders") end
	return true
end
local function miss(plr, sh, why)
	sh.misses += 1
	sh.streak = 0
	R.Menu:FireClient(plr, "cookResult", {ok = false, why = why, misses = sh.misses, limit = K.misses})
	if sh.misses >= K.misses then
		endShift(plr, "Three unhappy customers in a row: the shift is over.")
		return
	end
	sh.order = nil
	task.delay(K.gap, function() if shifts[plr] == sh then newOrder(plr, sh) end end)
end
function F.cookDone(plr, id, seq)
	local sh = shifts[plr]
	local d = data[plr]
	local o = sh and sh.order
	if not (o and d) or o.id ~= id or type(seq) ~= "table" or #seq > 10 then return false end
	local now = os.clock()
	local elapsed = now - o.sentAt
	sh.order = nil   -- one answer per order, whatever happens next
	local right = #seq == #o.steps
	for i, st in ipairs(o.steps) do if seq[i] ~= st.n then right = false end end
	if elapsed < K.minPerStep * #o.steps then
		miss(plr, sh, "Too fast to be real: the customer is suspicious.")
		return false
	end
	if not right then miss(plr, sh, "Wrong order! The customer walks out.") return false end
	if elapsed > o.limit + 0.6 then miss(plr, sh, "Too slow: the customer gave up.") return false end
	-- a perfect dish
	sh.streak += 1
	sh.best = math.max(sh.best, sh.streak)
	sh.served += 1
	local _, per = F.income(d, now)
	local perSec = math.max(0.5, per[sh.key] or 0)
	local mult = math.min(K.streakMax, 1 + K.streakBonus * (sh.streak - 1))
	local tip = math.max(5, perSec * K.tipSecs * mult)
	-- cap: in any minute, tips add up to at most tipCapSecs of this business's income
	local window = 0
	for i = #sh.tipWindow, 1, -1 do
		if now - sh.tipWindow[i].t > 60 then table.remove(sh.tipWindow, i) else window += sh.tipWindow[i].a end
	end
	tip = math.floor(math.max(0, math.min(tip, math.max(5, perSec * K.tipCapSecs) - window)))
	table.insert(sh.tipWindow, {t = now, a = tip})
	if tip > 0 then
		d.cash += tip
		F.earn(d, tip)
	end
	sh.tips += tip
	rush[d] = rush[d] or {}
	local r = rush[d][sh.key]
	local cur = (r and now < r.untilT) and r.mult or 0
	rush[d][sh.key] = {mult = math.min(K.rushMax, cur + K.rushPer), untilT = now + K.rushTime}
	if sh.served % 3 == 0 and F.addRep then F.addRep(plr, 1) end
	R.Menu:FireClient(plr, "cookResult", {ok = true, tip = tip, streak = sh.streak, rush = rush[d][sh.key].mult, served = sh.served})
	-- the customer walks out happy, in the world
	local door = doorOf(d, sh.key)
	if door then C.burst(door + V3(0, 4, 0), BIZ[sh.key].color, 12) end
	task.delay(K.gap, function() if shifts[plr] == sh then newOrder(plr, sh) end end)
	return true
end
-- late orders and walking away (checked twice a second)
task.spawn(function()
	while true do
		task.wait(0.5)
		for plr, sh in pairs(shifts) do
			local d = data[plr]
			if not (d and plr.Parent) then
				shifts[plr] = nil
			elseif not atBusiness(plr, d, sh.key) then
				endShift(plr, "You walked away from the counter.")
			elseif sh.order and os.clock() - sh.order.sentAt > sh.order.limit + 1.5 then
				sh.order = nil
				miss(plr, sh, "Too slow: the customer gave up.")
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) shifts[plr] = nil end)
F.cookShift = function(plr) return shifts[plr] end

C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.cookStart = function(plr, d, a) if C.str(a, 20) then F.cookStart(plr, a) end end
C.ACTIONS.cookDone = function(plr, d, a, b)
	if not C.str(a, 12) or type(b) ~= "table" then return end
	local seq = {}
	for i = 1, math.min(#b, 10) do
		local v = b[i]
		if not C.str(v, 20) then return end
		seq[i] = v
	end
	F.cookDone(plr, a, seq)
end
C.ACTIONS.cookEnd = function(plr) endShift(plr, "Shift ended.") end
end
