-- MESSAGES: the people in your empire text you. Employees, customers, tenants, rivals, story characters,
-- City Hall, event organizers and investors, each based on what's really going on in YOUR empire.
-- At most one everyday message every few minutes per player (important ones can come sooner, never in a burst).
return function(C)
local F, data = C.F, C.data
local fmt = C.fmt
local BIZ, BUSINESSES = C.BIZ, C.BUSINESSES
local RIVAL = C.STORY_RIVAL or {name = "Your rival", icon = "🎙️"}
local MIN_GAP, IMPORTANT_GAP = 200, 20   -- seconds between everyday messages / between any two generated ones
local nextAt, lastAny = {}, {}

local function pick(list) return list[math.random(#list)] end
local function ownedBiz(d)
	local out = {}
	for _, b in ipairs(BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 then table.insert(out, b) end
	end
	return out
end
local function bizName(d, b)
	local lvl = d.levels[b.key] or 0
	return b.tiers[math.max(1, C.stageOf(lvl, d.chains[b.key] or 0))]
end

-- each source returns a message or nil when it has nothing to say right now
local SOURCES = {
	-- employees: about their own business (problems first)
	function(plr, d)
		local staffed = {}
		for key, st in pairs(d.staff) do
			if BIZ[key] and (d.levels[key] or 0) > 0 then table.insert(staffed, {key = key, st = st}) end
		end
		if #staffed == 0 then return nil end
		local e = pick(staffed)
		local b = BIZ[e.key]
		local where = bizName(d, b)
		local lines
		if d.problems[e.key] then
			lines = {"Boss, the " .. where .. " has a problem and customers are noticing. Can you fix it from the business panel?",
				"Uh, boss? Something broke at the " .. where .. ". I put a sign up but it's not a great sign."}
		else
			lines = {"Boss, we're almost out of supplies at the " .. where .. ". Business is good though!",
				"The " .. where .. " was packed today. My feet hurt but the tip jar is happy.",
				"A customer asked if we're hiring. I said 'ask the boss'. You're the boss.",
				"Quick idea: more " .. b.thing .. ". Just... more of it. Think about it.",
				"If we upgraded the kitchen we'd be twice as fast. Just saying. 👀"}
		end
		return {icon = C.STAFF_ROLES[e.key].icon, from = e.st.name .. " (" .. C.STAFF_ROLES[e.key].role .. ")", cat = "staff", text = pick(lines)}
	end,
	-- customers: from your real recent reviews
	function(plr, d)
		local r = d.reviews and d.reviews[1]
		if not r then return nil end
		local good = {"That was the best " .. "%s I've had all week!", "Your %s place is my new favorite spot. Telling all my friends!", "10/10, would visit your %s again."}
		local bad = {"Not gonna lie, my visit to the %s was rough. Fix it and I'll come back.", "The line at the %s was SO long. Hire more people!"}
		local text = string.format(pick(r.stars >= 4 and good or bad), r.biz or "business")
		return {icon = r.stars >= 4 and "😋" or "😤", from = pick(C.NAMES) .. " (customer)", cat = "customer", text = text}
	end,
	-- tenants: from your real buildings
	function(plr, d)
		for _, b in ipairs(d.props) do
			for ui, t in ipairs(b.units) do
				if type(t) == "table" and math.random() < 0.35 then
					local first = string.match(t.name or "Tenant", "^(%S+)") or "Tenant"
					local lines = {"The apartment is getting pretty expensive. Can you upgrade the kitchen?",
						"The hallway light is flickering again. It's giving haunted house.",
						"Love the building! Any chance of a rooftop pool? Asking for me.",
						"My neighbor's " .. pick({"parrot", "drum kit", "llama"}) .. " is very loud. Just letting you know."}
					return {icon = "🏢", from = first .. " (" .. C.RENTAL[b.type].name .. ", Unit " .. C.unitName(ui) .. ")", cat = "tenant", text = pick(lines)}
				end
			end
		end
		return nil
	end,
	-- rival businesses
	function(plr, d)
		local ch = d.story and d.story.ch or 1
		local who, lines
		if ch <= 3 then
			who, lines = "🥤 Knockoff Kevin", {"You really think that new business is better than mine? ...It is. But still.", "I'm opening a stand next to yours. Again. Different color this time."}
		elseif ch == 4 then
			who, lines = "🏷️ Undercut Ulysses", {"Your prices are adorable. Mine are one cent less. Forever.", "I've cut my prices again. My accountant is crying."}
		else
			who, lines = "🎩 Sir Reginald Moneybags IV", {"My great-grandfather owned this street. You own... some of it. Cute.", "Lovely little empire. I'd buy it, but I already have three."}
		end
		return {icon = "😏", from = who, cat = "rival", text = pick(lines)}
	end,
	-- potential investors, when your income makes you interesting
	function(plr, d)
		local inc = F.incomePerSec(d)
		if inc < 200 then return nil end
		return {icon = "💼", from = pick({"Venture Vicky", "Angel Investor Al", "Mr. Stonks"}) .. " (investor)", cat = "investor", important = true,
			text = "I've been watching your empire make $" .. fmt(inc) .. "/s. If you ever list shares on the Stock Market, I'm interested. 📈"}
	end,
	-- event organizers during a mega event
	function(plr, d)
		local m = C.megaState and C.megaState()
		if not m then return nil end
		return {icon = m.icon, from = "City Events Office", cat = "event", text = m.title .. " " .. m.sub}
	end,
}

-- story characters text you when a chapter starts (saved: these are part of your story)
function F.storyMessage(plr, ch)
	local info = C.STORY and C.STORY[ch]
	if not (info and info.dm) then return end
	F.pushMsg(plr, {icon = RIVAL.icon, from = RIVAL.name .. " " .. (RIVAL.handle or ""), cat = "story", important = true, text = info.dm})
end

task.spawn(function()
	while true do
		task.wait(15)
		local now = os.clock()
		for plr, d in pairs(data) do
			if not nextAt[plr] then nextAt[plr] = now + math.random(90, 150) end
			if now >= nextAt[plr] and now - (lastAny[plr] or 0) >= IMPORTANT_GAP and d.tut == 0 then
				-- try a few sources in random order until one has something to say
				local order = {}
				for i = 1, #SOURCES do order[i] = i end
				for i = #order, 2, -1 do
					local j = math.random(i)
					order[i], order[j] = order[j], order[i]
				end
				for _, i in ipairs(order) do
					local ok, msg = pcall(SOURCES[i], plr, d)
					if ok and msg then
						F.pushMsg(plr, msg)
						lastAny[plr] = now
						break
					end
				end
				nextAt[plr] = now + MIN_GAP + math.random(0, 160)
			end
		end
		for plr in pairs(nextAt) do
			if not data[plr] then nextAt[plr], lastAny[plr] = nil, nil end
		end
	end
end)
end
