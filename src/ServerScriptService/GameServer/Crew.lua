-- CREW (v14): employees get a personality and a schedule.
--   * TRAITS: most candidates have one (Night Owl, Early Bird, Charmer, Hustler, Fast Learner, Steady Hands), shown
--     before you hire them. Each changes something real (the shift bonus, customer happiness, training cost, how
--     often things break at that business)
--   * SHIFTS: Flex (the old behavior: their bonus all day), Day or Night. On their shift an employee gives ×1.3 of
--     their bonus, off it ×0.7, so over a full day it evens out: a shift pays off when it matches the trait (a Night
--     Owl on nights) or the business (the theater's night shows)
--   * LEARNING ON THE JOB: an employee who is working gains experience by themselves (a free ★ now and then)
-- Staff hired before v14 keep everything they had: no trait, Flex shift, so their bonus is exactly what it was.
return function(C)
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local F, data, R = C.F, C.data, C.R
local notify = C.notify
local STAFF_ROLES = C.STAFF_ROLES

local CR = {
	onShift = 1.3, offShift = 0.7,
	traitChance = 0.75,
	xpEvery = 60, xpStar = 45, maxExp = 5,
}
C.CREW = CR
local TRAITS = {
	{key = "nightowl", name = "Night Owl", icon = "🦉", text = "+25% bonus at night"},
	{key = "earlybird", name = "Early Bird", icon = "🐦", text = "+25% bonus by day"},
	{key = "charmer", name = "Charmer", icon = "😊", text = "happier customers"},
	{key = "hustler", name = "Hustler", icon = "⚡", text = "+15% bonus, always"},
	{key = "learner", name = "Fast Learner", icon = "📚", text = "training -30%, learns twice as fast"},
	{key = "steady", name = "Steady Hands", icon = "🛠️", text = "half the breakdowns here"},
}
C.TRAITS = TRAITS
local TRAIT = {}
for _, t in ipairs(TRAITS) do TRAIT[t.key] = t end
C.TRAIT = TRAIT
local SHIFTS = {flex = "🔄 Flex", day = "☀️ Day", night = "🌙 Night"}
C.SHIFTS = SHIFTS

function F.isNight()
	local h = Lighting.ClockTime
	return h >= 18 or h < 6
end
local function shiftOf(s) return SHIFTS[s.shift] and s.shift or "flex" end
-- is this employee working right now?
function F.crewOnShift(s)
	local sh = shiftOf(s)
	if sh == "flex" then return true end
	return (sh == "night") == F.isNight()
end
-- how much of their normal bonus this employee gives right now (1 = the old behavior)
function F.crewFactor(s)
	if type(s) ~= "table" then return 1 end
	local f = 1
	local sh = shiftOf(s)
	if sh ~= "flex" then f = F.crewOnShift(s) and CR.onShift or CR.offShift end
	local t = s.trait
	if t == "hustler" then f *= 1.15
	elseif t == "nightowl" and F.isNight() then f *= 1.25
	elseif t == "earlybird" and not F.isNight() then f *= 1.25 end
	return f
end
function F.crewSatisfaction(d, key)
	local s = d.staff and d.staff[key]
	return (s and s.trait == "charmer") and 6 or 0
end
function F.crewSteady(d, key)
	local s = d.staff and d.staff[key]
	return s ~= nil and s.trait == "steady"
end

-- candidates get a trait (once: the list is kept until you hire)
local baseCandidates = F.candidates
function F.candidates(d, slot)
	local list = baseCandidates(d, slot)
	for _, c in ipairs(list) do
		if c.trait == nil then c.trait = math.random() < CR.traitChance and TRAITS[math.random(#TRAITS)].key or false end
	end
	return list
end
local baseTrainCost = F.trainCost
function F.trainCost(slot, s)
	local c = baseTrainCost(slot, s)
	if s and s.trait == "learner" then c = math.floor(c * 0.7) end
	return c
end
function F.crewView(s)
	if type(s) ~= "table" then return nil end
	local t = s.trait and TRAIT[s.trait]
	return {trait = t and t.name or nil, traitIcon = t and t.icon or nil, traitText = t and t.text or nil, shift = shiftOf(s), shiftName = SHIFTS[shiftOf(s)],
		working = F.crewOnShift(s), factor = math.floor(F.crewFactor(s) * 100 + 0.5), xp = tonumber(s.xp) or 0, xpStar = CR.xpStar}
end

function F.crewSetShift(plr, slot, shift)
	local d = data[plr]
	local s = d and type(slot) == "string" and STAFF_ROLES[slot] and d.staff[slot]
	if not (s and type(shift) == "string" and SHIFTS[shift]) then return false end
	s.shift = shift
	notify(plr, "🗓️ " .. s.name .. " now works " .. SHIFTS[shift] .. (shift == "flex" and " (all day, normal bonus)" or " shifts (×1.3 on shift, ×0.7 off)") .. ".")
	return true
end
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.crewShift = function(plr, d, a, b) F.crewSetShift(plr, a, b) end

-- learning on the job
task.spawn(function()
	while true do
		task.wait(CR.xpEvery)
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = data[plr]
			if d and type(d.staff) == "table" then
				for slot, s in pairs(d.staff) do
					if type(s) == "table" and F.crewOnShift(s) and (tonumber(s.exp) or 1) < CR.maxExp then
						s.xp = (tonumber(s.xp) or 0) + (s.trait == "learner" and 2 or 1)
						if s.xp >= CR.xpStar then
							s.xp = 0
							s.exp = (tonumber(s.exp) or 1) + 1
							local role = STAFF_ROLES[slot] and STAFF_ROLES[slot].role or "employee"
							notify(plr, "🎓 " .. s.name .. " (" .. role .. ") learned on the job: Experience " .. s.exp .. "★")
							if F.refreshWorkers then pcall(F.refreshWorkers, plr) end
						end
					end
				end
			end
		end
	end
end)
end
