-- ANALYTICS (v17): tells Roblox's Creator Analytics what new players do, so the Creator Hub dashboards show
-- where they stop playing (Roblox ranks games by first-play bounce, playtime and how many days people come back).
--   * ONBOARDING FUNNEL (AnalyticsService:LogOnboardingFunnelStepEvent): brand-new saves only (d.firstPlay),
--     each step once per save, in order: 1 new game, 2 first sale, 3 Lemonade Lv 3, 4 second business,
--     5 phone opened, 6 tutorial done, 7 first car, 8 five minutes played
--   * ECONOMY (LogEconomyEvent): money spent (upgrades, the Bazaar) and big money in (rewards, rare sales).
--     Ordinary customer sales are NOT logged one by one (there are far too many); throttled per player
--   * CUSTOM (LogCustomEvent): rare sales, rare Bazaar buys, the opening movie watched vs skipped
-- Every call is wrapped in pcall: analytics never breaks the game. Turn it off with C.ANALYTICS.enabled = false.
return function(C)
local Players = game:GetService("Players")
local AS = game:GetService("AnalyticsService")
local F, data = C.F, C.data

C.ANALYTICS = {enabled = true, economyGap = 1}
C.FUNNEL = {"newGame", "firstSale", "standLv3", "secondBiz", "phoneOpened", "tutorialDone", "firstCar", "played5min"}
local STEP = {}
for i, k in ipairs(C.FUNNEL) do STEP[k] = i end

local function call(fn) if C.ANALYTICS.enabled then pcall(fn) end end
-- one funnel step, once per new save (kept in the save, so a rejoin doesn't send it twice)
function F.funnel(plr, name)
	local d = data[plr]
	local i = STEP[name]
	local fp = d and d.firstPlay
	if not (i and type(fp) == "table") then return false end
	fp.steps = type(fp.steps) == "table" and fp.steps or {}
	if fp.steps[name] then return false end
	fp.steps[name] = os.time()
	call(function() AS:LogOnboardingFunnelStepEvent(plr, i, name) end)
	return true
end
local lastEco = {}
local function economy(plr, flow, amount, tx, sku)
	local d = data[plr]
	amount = math.floor(tonumber(amount) or 0)
	if not d or amount <= 0 then return end
	local key = flow.Name .. tx
	local t = os.clock()
	lastEco[plr] = lastEco[plr] or {}
	if lastEco[plr][key] and t - lastEco[plr][key] < C.ANALYTICS.economyGap then return end
	lastEco[plr][key] = t
	call(function() AS:LogEconomyEvent(plr, flow, "Cash", amount, math.floor(d.cash), tx, sku) end)
end
function F.analyticsSink(plr, amount, what, sku)
	economy(plr, Enum.AnalyticsEconomyFlowType.Sink, amount, Enum.AnalyticsEconomyTransactionType.Shop.Name, (what or "") .. ":" .. tostring(sku or ""))
end
function F.analyticsSource(plr, amount, what, sku)
	local tx = what == "Reward" and Enum.AnalyticsEconomyTransactionType.TimedReward.Name or Enum.AnalyticsEconomyTransactionType.Gameplay.Name
	economy(plr, Enum.AnalyticsEconomyFlowType.Source, amount, tx, (what or "") .. ":" .. tostring(sku or ""))
end
function F.analyticsCustom(plr, name, value)
	call(function() AS:LogCustomEvent(plr, name, tonumber(value) or 1) end)
end

-- the funnel watches the player's real state once a second (no hooks needed in every system)
local function bizCount(d)
	local n = 0
	for _, lv in pairs(d.levels or {}) do if (tonumber(lv) or 0) > 0 then n += 1 end end
	return n
end
local CHECKS = {
	{"firstSale", function(d) return (d.served or 0) >= 1 end},
	{"standLv3", function(d) return (d.levels.lemonade or 0) >= 3 end},
	{"secondBiz", function(d) return bizCount(d) >= 2 end},
	{"phoneOpened", function(d) return d.phoneOpenedAt ~= nil end},
	{"tutorialDone", function(d) return (d.tut or 1) == 0 and (d.tutPaid or 0) >= #C.TUTORIAL end},
	{"firstCar", function(d) return type(d.cars) == "table" and next(d.cars) ~= nil end},
	{"played5min", function(d, s) return s and os.clock() - s >= 300 end},
}
local started = {}
task.spawn(function()
	while true do
		task.wait(1)
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			local fp = d and d.firstPlay
			if type(fp) == "table" and not fp.done then
				started[plr] = started[plr] or os.clock()
				F.funnel(plr, "newGame")
				local all = true
				for _, c in ipairs(CHECKS) do
					local ok, yes = pcall(c[2], d, started[plr])
					if ok and yes then F.funnel(plr, c[1]) end
					if not (type(fp.steps) == "table" and fp.steps[c[1]]) then all = false end
				end
				if all then fp.done = true end
			elseif not d then
				started[plr] = nil
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr) lastEco[plr], started[plr] = nil, nil end)
end
