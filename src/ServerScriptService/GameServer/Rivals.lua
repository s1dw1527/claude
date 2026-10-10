-- RIVALS (v14): four AI companies compete with your businesses. Each one goes after certain business types:
--   🥤 Gulp & Co. (lemonade, ice cream, coffee) · 🍔 MegaBite Foods (bakery, pizza)
--   👾 Pixel Palace Group (arcade, movie theater) · 🏭 Novatek Industries (tech, factory)
-- How it works (all here on the server, all saved):
--   * PRESSURE (0-100) per business you own: rivals creep in slowly while you play. Your market share is
--     100% - pressure/2 (75% to start: exactly normal sales), and it nudges that business's sales between ×0.96
--     (rivals everywhere) and ×1.04 (you own the street). That's the whole effect:
--     rivals never touch your cash, never act while you're offline, and can never cost more than 4%
--   * fighting back lowers pressure: upgrading, perfect Rush Orders, ad campaigns, hiring, a theater premiere
--   * MOVES: every few minutes a rival makes a move on one of your businesses (a CityBuzz post, +pressure) and
--     throws down a CHALLENGE: serve 5 perfect Rush Orders there, upgrade it, or run an ad, before time runs out.
--     Win: pressure drops a lot, a cash prize (a minute of that business's income), a win on your record.
--     The clock only runs while you're in the game.
return function(C)
local Players = game:GetService("Players")
local RGB = Color3.fromRGB
local F, data, R = C.F, C.data, C.R
local fmt, notify = C.fmt, C.notify
local BIZ = C.BIZ

local RV = {
	tick = 60, drift = 0.6, jitter = 0.5,
	moveMin = 420, moveMax = 720, firstMove = 240, movePressure = 18,
	challengeTime = 480, winDrop = 45, rewardSecs = 60, cookNeed = 5,
	relief = {upgrade = 12, cook = 3, ad = 10, premiere = 10, hire = 6},
	multLo = 0.96, multSpan = 0.08,
}
C.RIVAL_CFG = RV
local RIVALS = {
	{key = "gulp", name = "Gulp & Co.", icon = "🥤", boss = "Gordon Gulp", color = RGB(60, 170, 230), biz = {"lemonade", "icecream", "coffee"},
		moves = {"opened a kiosk right across from", "is handing out free samples next to", "put a giant inflatable cup outside"}},
	{key = "megabite", name = "MegaBite Foods", icon = "🍔", boss = "Mona Bite", color = RGB(230, 120, 40), biz = {"bakery", "pizza"},
		moves = {"opened a drive-thru next to", "is running two-for-one coupons near", "parked a food truck in front of"}},
	{key = "pixel", name = "Pixel Palace Group", icon = "👾", boss = "Rex Pixel", color = RGB(170, 80, 255), biz = {"arcade", "theater"},
		moves = {"opened a mega-screen across from", "launched a loyalty card to steal fans from", "booked a celebrity appearance near"}},
	{key = "novatek", name = "Novatek Industries", icon = "🏭", boss = "Dr. Nova", color = RGB(120, 130, 150), biz = {"tech", "factory"},
		moves = {"announced a cheaper copy of", "is poaching customers from", "built a showroom next to"}},
}
C.RIVALS = RIVALS
local RIVAL_OF = {}
for _, r in ipairs(RIVALS) do for _, k in ipairs(r.biz) do RIVAL_OF[k] = r end end
C.RIVAL_OF = RIVAL_OF

local function rec(d)
	local t = d.rivals
	if type(t) ~= "table" then
		t = {}
		d.rivals = t
	end
	t.p = type(t.p) == "table" and t.p or {}
	t.wins = tonumber(t.wins) or 0
	t.losses = tonumber(t.losses) or 0
	t.moves = tonumber(t.moves) or 0
	if t.ch ~= nil and (type(t.ch) ~= "table" or not BIZ[t.ch.key] or type(t.ch.left) ~= "number") then t.ch = nil end
	return t
end
F.rivalRec = rec
-- (a business nobody has fought over yet sits in the middle: 50 = exactly its normal sales)
local function pressure(t, key) return math.clamp(tonumber(t.p[key]) or 50, 0, 100) end
function F.rivalShare(d, key)
	if not RIVAL_OF[key] then return 100 end
	return math.floor(100 - pressure(rec(d), key) / 2 + 0.5)
end
function F.rivalMult(d, key)
	if not (RIVAL_OF[key] and type(d.rivals) == "table" and type(d.rivals.p) == "table") then return 1 end
	local share = 100 - pressure(d.rivals, key) / 2   -- 50..100 (75 = neutral)
	return RV.multLo + RV.multSpan * (share - 50) / 50
end
local function owned(d)
	local out = {}
	for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 and RIVAL_OF[b.key] then table.insert(out, b.key) end end
	return out
end
local function bizName(d, key) return F.bizName and F.bizName(d, key) or BIZ[key].name end

-- ===== challenges =====
local function canDo(d, kind, key)
	if kind == "cook" then return C.RECIPES and C.RECIPES[key] ~= nil end
	if kind == "upgrade" then return (d.levels[key] or 0) < C.CFG.MAX_LEVEL end
	if kind == "ad" then return F.unlocked(d, "ads") end
	return false
end
local CH_TEXT = {
	cook = function(n, name) return "Serve " .. n .. " perfect 🍳 Rush Orders at your " .. name end,
	upgrade = function(_, name) return "Upgrade your " .. name .. " once" end,
	ad = function() return "Run a 📣 marketing campaign" end,
}
function F.rivalMove(plr, forceKey)
	local d = data[plr]
	if not d then return nil end
	local t = rec(d)
	if t.ch then return nil end
	local list = owned(d)
	if #list == 0 then return nil end
	local key = forceKey or list[math.random(#list)]
	local rv = RIVAL_OF[key]
	if not rv then return nil end
	t.p[key] = math.min(100, pressure(t, key) + RV.movePressure)
	t.moves += 1
	local kinds = {}
	for _, k in ipairs({"cook", "upgrade", "ad"}) do if canDo(d, k, key) then table.insert(kinds, k) end end
	if #kinds == 0 then return nil end
	local kind = kinds[math.random(#kinds)]
	local need = kind == "cook" and RV.cookNeed or 1
	local name = bizName(d, key)
	t.ch = {rival = rv.key, key = key, kind = kind, need = need, got = 0, left = RV.challengeTime, text = CH_TEXT[kind](need, name)}
	local what = rv.moves[math.random(#rv.moves)]
	F.buzz(rv.icon, rv.name .. " " .. what .. " " .. plr.Name .. "'s " .. name .. "!", rv.color, rv.boss)
	notify(plr, "🥊 " .. rv.name .. " is coming for your " .. name .. "! Challenge: " .. t.ch.text .. " (" .. math.floor(RV.challengeTime / 60) .. " min).")
	R.Menu:FireClient(plr, "rivalMove", {rival = rv.name, icon = rv.icon, text = t.ch.text, left = t.ch.left})
	return t.ch
end
local function win(plr, d, t)
	local ch = t.ch
	t.ch = nil
	local rv
	for _, r in ipairs(RIVALS) do if r.key == ch.rival then rv = r end end
	t.p[ch.key] = math.max(0, pressure(t, ch.key) - RV.winDrop)
	t.wins += 1
	local _, per = F.income(d, os.clock())
	local prize = math.max(100, math.floor((per and per[ch.key] or 0) * RV.rewardSecs))
	d.cash += prize
	F.earn(d, prize)
	if F.addRep then F.addRep(plr, 5) end
	local name = bizName(d, ch.key)
	notify(plr, "🏆 You beat " .. (rv and rv.name or "the rival") .. "! Your " .. name .. " wins back its customers (+$" .. fmt(prize) .. ").")
	F.buzz("🏆", plr.Name .. "'s " .. name .. " fought off " .. (rv and rv.name or "a rival") .. "!", RGB(255, 205, 60))
	R.Menu:FireClient(plr, "rivalResult", {won = true, prize = prize})
end
-- something the player did that pushes rivals back (and may complete the challenge)
function F.rivalAct(plr, kind, key)
	local d = data[plr]
	if not d then return end
	local t = rec(d)
	local relief = RV.relief[kind] or 0
	if kind == "ad" then
		for _, k in ipairs(owned(d)) do t.p[k] = math.max(0, pressure(t, k) - relief) end
	elseif key and RIVAL_OF[key] then
		t.p[key] = math.max(0, pressure(t, key) - relief)
	end
	local ch = t.ch
	if ch and ch.kind == kind and (kind == "ad" or ch.key == key) then
		ch.got += 1
		if ch.got >= ch.need then win(plr, d, t) else C.ACTIONS.rivalInfo(plr) end
	end
end

function F.rivalInfo(plr)
	local d = data[plr]
	if not d then return nil end
	local t = rec(d)
	local info = {wins = t.wins, losses = t.losses, moves = t.moves, rivals = {}, biz = {}}
	if t.ch then
		local rv
		for _, r in ipairs(RIVALS) do if r.key == t.ch.rival then rv = r end end
		info.ch = {text = t.ch.text, got = t.ch.got, need = t.ch.need, left = math.ceil(t.ch.left), rival = rv and rv.name, icon = rv and rv.icon, key = t.ch.key}
	end
	for _, r in ipairs(RIVALS) do
		local names = {}
		for _, k in ipairs(r.biz) do table.insert(names, BIZ[k].icon) end
		table.insert(info.rivals, {key = r.key, name = r.name, icon = r.icon, boss = r.boss, targets = table.concat(names, " ")})
	end
	for _, k in ipairs(owned(d)) do
		local rv = RIVAL_OF[k]
		table.insert(info.biz, {key = k, name = bizName(d, k), icon = BIZ[k].icon, share = F.rivalShare(d, k), rival = rv.name, rivalIcon = rv.icon,
			mult = math.floor(F.rivalMult(d, k) * 1000 + 0.5) / 1000})
	end
	return info
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.rivalInfo = function(plr)
	local info = F.rivalInfo(plr)
	if info then R.Menu:FireClient(plr, "rivals", info) end
end

-- ===== the clock (only while you play) =====
local nextMove = {}
task.spawn(function()
	while true do
		task.wait(RV.tick)
		local now = os.clock()
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			if d and (d.tut or 0) == 0 then
				local ok, err = pcall(function()
					local t = rec(d)
					for _, k in ipairs(owned(d)) do t.p[k] = math.min(100, pressure(t, k) + RV.drift + math.random() * RV.jitter) end
					if t.ch then
						t.ch.left -= RV.tick
						if t.ch.left <= 0 then
							local rv = RIVAL_OF[t.ch.key]
							t.losses += 1
							notify(plr, "⏱️ Time's up: " .. (rv and rv.name or "the rival") .. " keeps its new customers for now. There'll be another chance.")
							R.Menu:FireClient(plr, "rivalResult", {won = false})
							t.ch = nil
						end
					end
					if not nextMove[plr] then
						nextMove[plr] = now + RV.firstMove
					elseif now >= nextMove[plr] then
						nextMove[plr] = now + math.random(RV.moveMin, RV.moveMax)
						F.rivalMove(plr)
					end
				end)
				if not ok then warn("[Rivals] " .. tostring(err)) end
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) nextMove[plr] = nil end)
end
