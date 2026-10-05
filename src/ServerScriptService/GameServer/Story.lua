-- STORY MODE: six comedic chapters that follow each player's REAL progress (lifetime earnings and business
-- milestones, never the cash in their pocket, so buying a car never makes the story think you're broke again).
-- Everything is decided here on the server: objectives are checked against the player's data, rewards are
-- paid once per save, and each player only ever sees their own cutscenes.
return function(C)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local F, data, R = C.F, C.data, C.R
local STORY, ROASTS = C.STORY, C.STORY_ROASTS
local fmt, notify = C.fmt, C.notify
local RGB, V3 = Color3.fromRGB, Vector3.new

local remote = Instance.new("RemoteEvent")
remote.Name = "Story"
remote.Parent = ReplicatedStorage
R.Story = remote

local LEGEND = #STORY + 1          -- chapter number after the last one: "legend mode"
local run = {}                     -- per-session state that isn't saved (challenge timers, roast cooldowns)
local headlineAt = 0               -- Corner Gazette rumors are rate-limited server-wide
local INTERACTIVE = {clapback = true, challenge = true, inspection = true, choice = true, finale = true, fives = true}

local function S(d)
	local s = d.story
	if type(s) ~= "table" then
		s = {}
		d.story = s
	end
	s.ch = math.clamp(math.floor(tonumber(s.ch) or 1), 1, LEGEND)
	for _, k in ipairs({"obj", "done", "paid", "intro", "flags"}) do
		if type(s[k]) ~= "table" then s[k] = {} end
	end
	s.fives = tonumber(s.fives) or 0
	return s
end
local function R_(plr)
	local r = run[plr]
	if not r then
		r = {nextRoast = os.clock() + 120, lastRoast = -1e9, nextStaff = os.clock() + 120}
		run[plr] = r
	end
	return r
end
function F.storyChapter(d) return d.story and S(d).ch or 1 end
local function chapterOf(d) return STORY[S(d).ch] end

-- ===== objectives =====
local function maxLevel(d)
	local m = 0
	for _, b in ipairs(C.BUSINESSES) do m = math.max(m, d.levels[b.key] or 0) end
	return m
end
local function bizCount(d)
	local n = 0
	for _, b in ipairs(C.BUSINESSES) do if (d.levels[b.key] or 0) > 0 then n += 1 end end
	return n
end
local function count(t)
	local n = 0
	for _ in pairs(t or {}) do n += 1 end
	return n
end
local function choiceOf(ch, key)
	for _, c in ipairs(ch.choices or {}) do if c.key == key then return c end end
	return nil
end
local function num(cur, need, money)
	local f = need > 0 and math.clamp(cur / need, 0, 1) or 1
	local txt = money and ("$" .. fmt(math.min(cur, need)) .. " / $" .. fmt(need)) or (fmt(math.min(cur, need)) .. " / " .. fmt(need))
	return cur >= need, txt, f
end
-- returns done, progress text, progress fraction (0-1)
local function progressOf(plr, d, ch, o)
	local s = S(d)
	local k = o.kind
	if k == "served" then return num(d.served or 0, o.n)
	elseif k == "earned" then
		-- business earnings before any Money pass boost (see F.earn), so the story is earned the same way by everyone
		local done, txt, f = num(d.storyEarned or d.earned or 0, o.n, true)
		if F.passMult(d) > 1 then txt ..= " (before pass boosts)" end
		return done, txt, f
	elseif k == "deliveries" then return num(d.deliveries or 0, o.n)
	elseif k == "contributed" then return num(d.contributed or 0, o.n, true)
	elseif k == "followers" then return num(d.followers or 0, o.n)
	elseif k == "level" then return num(maxLevel(d), o.n)
	elseif k == "biz" then return num(bizCount(d), o.n)
	elseif k == "staff" then return num(count(d.staff), o.n)
	elseif k == "combo" then return num(count(d.combos), o.n)
	elseif k == "score" then return num(F.empireScore(d), o.n)
	elseif k == "tier" then
		local t = F.tierIndex(d.rep)
		local need = C.REP_TIERS[o.n].rep
		return t >= o.n, fmt(math.min(d.rep, need)) .. " / " .. fmt(need) .. " rep", math.clamp(d.rep / need, 0, 1)
	elseif k == "viral" then return d.wentViral == true, d.wentViral and "Done" or "Not yet", d.wentViral and 1 or 0
	elseif k == "luxury" then
		local hood = F.homeHood(d)
		local ok = (d.cars and d.cars.hyper == true) or hood == "hills" or hood == "rich"
		return ok, ok and "Flexed" or "Hyper Car $" .. fmt(C.CAR.hyper.price) .. " or a Hillside home $" .. fmt(C.HOOD.hills.price), ok and 1 or 0
	elseif k == "fives" then return num(s.fives, o.n)
	elseif k == "inspection" then
		if s.flags.inspected then return true, "Passed ✅", 1 end
		if s.inspect and d.problems[s.inspect] then return false, "🧑‍⚖️ The inspector is at your " .. C.BIZ[s.inspect].name .. ": fix it!", 0.5 end
		return false, "The inspector is on the way...", 0
	elseif k == "choice" then
		local c = choiceOf(ch, s.choice)
		if not c then return false, "Pick one in the Story app", 0 end
		if c.kind == "level" then
			local done, txt, f = num(maxLevel(d), c.n)
			return done, c.label .. ": " .. txt, f
		elseif c.kind == "role" then
			return d.staff[c.role] ~= nil, c.label .. ": " .. (d.staff[c.role] and "hired" or "not hired yet"), d.staff[c.role] and 1 or 0
		else
			local ok = bizCount(d) >= 5 or F.countLots(d) >= 1
			return ok, c.label .. ": " .. bizCount(d) .. " / 5 businesses, " .. F.countLots(d) .. " lots", ok and 1 or bizCount(d) / 5
		end
	elseif k == "challenge" then
		if s.flags.copycat then return true, "Kevin is out of business ✅", 1 end
		local r = R_(plr)
		local cg = r.challenge
		if cg then
			local made = d.earned - cg.base
			return false, "$" .. fmt(made) .. " / $" .. fmt(cg.target) .. " • " .. math.max(0, math.ceil(cg.ends - os.clock())) .. "s left", math.clamp(made / cg.target, 0, 1)
		end
		return false, "Start the showdown in the Story app", 0
	elseif k == "clapback" then return s.flags.clapback ~= nil, s.flags.clapback and "Roasted 🔥" or "Pick your comeback", s.flags.clapback and 1 or 0
	elseif k == "finale" then return s.flags.finale == true, s.flags.finale and "Done" or "He's waiting...", s.flags.finale and 1 or 0
	end
	return false, "", 0
end
local function othersDone(d, ch, skip)
	local s = S(d)
	for i, o in ipairs(ch.objectives) do
		if i ~= skip and not o.after and not s.obj["c" .. s.ch .. "o" .. i] then return false end
	end
	return true
end

-- ===== the rival's commentary =====
local function pick(list) return list[math.random(#list)] end
-- event roasts wait at least 45s after the last one; idle ones only come every few minutes
local function roast(plr, pool, force)
	local d = data[plr]
	if not d then return end
	local r = R_(plr)
	local now = os.clock()
	if not force and now - r.lastRoast < 45 then return end
	local line
	if math.random() < 0.04 then line = pick(ROASTS.rare) else line = pick(pool) end
	r.lastRoast = now
	r.nextRoast = now + math.random(240, 360)
	remote:FireClient(plr, {kind = "roast", text = line, who = "rival"})
end
function F.storyEvent(plr, kind, a, b)
	local d = data[plr]
	if not d then return end
	local s = S(d)
	if kind == "problemResolved" then
		if s.inspect == a and not s.flags.inspected then
			if b == "ignore" then
				s.inspect = nil
				R_(plr).inspectAt = os.clock() + 90
				remote:FireClient(plr, {kind = "roast", who = "rival", text = "You IGNORED the INSPECTOR?! He left a sad-face sticker. He'll be back. 💀"})
			else
				s.flags.inspected = true
				s.inspect = nil
				notify(plr, "🧑‍⚖️ Inspection PASSED! The inspector gave you a gold star sticker. ⭐")
			end
		elseif b == "ignore" then
			roast(plr, ROASTS.problemIgnored)
		end
	elseif kind == "review" then
		if s.ch == 4 and a == 5 then s.fives += 1 end
	elseif kind == "newBusiness" then
		if s.ch <= 3 then roast(plr, ROASTS.newBusiness) end
	elseif kind == "viral" then roast(plr, ROASTS.viral, true)
	elseif kind == "luxury" then roast(plr, ROASTS.luxury)
	elseif kind == "rebirth" then roast(plr, ROASTS.rebirth, true)
	end
end

-- ===== cutscenes =====
local function stageFor(plr, d)
	local plot = d.plot
	local focus = F.slotCF(plot, "lemonade").Position
	return {
		at = plot.at(6, 0.2, 14),                 -- where the rival stands
		focus = V3(focus.X, 1, focus.Z),           -- what he points at (your first stand)
		cam = plot.at(-10, 11, 46),                -- camera spot (street side)
		street = plot.at(60, 0.2, 48),             -- where vehicles drive in from
		curb = plot.at(14, 0.2, 40),
	}
end
local function cutscene(plr, d, part, lines, chIndex)
	local ch = STORY[chIndex]
	remote:FireClient(plr, {kind = "cutscene", part = part, ch = chIndex, title = ch and ch.title or "LEGEND MODE", icon = ch and ch.icon or "👑",
		stage = (part == "finale" or part == "outro") and "plot" or (ch and ch.stage or "plot"), copycat = ch and ch.copycat and part == "intro",
		lines = lines, where = stageFor(plr, d)})
end
local function sendIntro(plr, d)
	local s = S(d)
	local ch = STORY[s.ch]
	if not ch or s.intro["c" .. s.ch] then return end
	s.intro["c" .. s.ch] = true
	cutscene(plr, d, "intro", ch.intro, s.ch)
	if F.storyMessage then F.storyMessage(plr, s.ch) end
	if s.ch >= 2 and C.STORY_HEADLINES[s.ch] then
		F.buzz("📰", string.format(pick(C.STORY_HEADLINES[s.ch]), plr.Name), RGB(230, 230, 230), "Corner Gazette")
	end
end

-- ===== chapter completion (the reward is paid once per save, ever) =====
local function complete(plr, d)
	local s = S(d)
	local i = s.ch
	local ch = STORY[i]
	if not ch or s.done["c" .. i] then return end
	s.done["c" .. i] = true
	local rw = ch.reward or {}
	local rewardText = ""
	if not s.paid["c" .. i] then
		s.paid["c" .. i] = true
		local cash = math.floor(math.max(rw.floor or 0, F.incomePerSec(d) * (rw.seconds or 0)))
		if cash > 0 then
			d.cash += cash   -- a gift, like tutorial rewards: it doesn't count as "earned" (so it can't push the story ahead)
			rewardText = "+$" .. fmt(cash)
		end
		if rw.rep then F.addRep(plr, rw.rep) rewardText ..= "  +" .. rw.rep .. " rep" end
		if rw.trophies then d.trophies += rw.trophies rewardText ..= "  +" .. rw.trophies .. " 🏆" end
		if rw.title then s.title = rw.title rewardText ..= "  Title: \"" .. rw.title .. "\"" end
	end
	-- the cutscene: your comeback / the finale first, then the chapter's ending
	local lines = {}
	if ch.clapbacks and s.flags.clapback then table.insert(lines, {"you", ch.clapbacks[s.flags.clapback] or ch.clapbacks[1]}) end
	if ch.finale and s.flags.finale then
		for _, l in ipairs(ch.finale) do table.insert(lines, l) end
	end
	for _, l in ipairs(ch.outro) do table.insert(lines, l) end
	cutscene(plr, d, ch.finale and "finale" or "outro", lines, i)
	remote:FireClient(plr, {kind = "chapterDone", ch = i, title = ch.title, icon = ch.icon, reward = rewardText})
	F.buzz(ch.icon, plr.Name .. " finished Story Chapter " .. i .. ": " .. ch.title .. "!", RGB(255, 120, 200))
	s.ch = i + 1
	R_(plr).challenge = nil
	if s.ch <= #STORY then
		sendIntro(plr, d)
	else
		-- legend mode: the story is done, the game keeps going
		cutscene(plr, d, "epilogue", {{"rival", "LEGEND MODE unlocked. I'll be around. Watching. Clipping. Forever. 👀", "point"}}, LEGEND)
		if F.achieve then F.achieve(plr, "storyLegend") end
	end
end

-- ===== every couple of seconds for each player =====
function F.storyTick(plr, d, now)
	local s = S(d)
	local r = R_(plr)
	local ch = STORY[s.ch]
	if ch then
		-- objectives: once met they stay met (spending money or losing reputation never undoes them)
		local all = true
		for i, o in ipairs(ch.objectives) do
			local key = "c" .. s.ch .. "o" .. i
			if not s.obj[key] then
				local open = not o.after or othersDone(d, ch, i)
				local done = open and progressOf(plr, d, ch, o)
				if done then
					s.obj[key] = true
					notify(plr, "📖 Story: " .. o.text .. " ✅")
				else
					all = false
				end
			end
		end
		if all then
			complete(plr, d)
			return
		end
		-- chapter 3: Kevin's copycat showdown
		local cg = r.challenge
		if cg then
			if d.earned - cg.base >= cg.target then
				s.flags.copycat = true
				r.challenge = nil
				notify(plr, "🥤 You out-sold Knockoff Kevin! His stand is closing.")
			elseif now >= cg.ends then
				r.challenge = nil
				r.challengeRetry = now + 20
				roast(plr, ROASTS.challengeFail, true)
				notify(plr, "🥤 Kevin's copycat stand survived... Try again from the Story app!")
			end
		end
		-- chapter 4: the surprise inspection shows up a little after the chapter starts
		if ch.inspection and not s.flags.inspected then
			if d.rebirths >= 50 then
				s.flags.inspected = true   -- Mogul crews auto-fix problems, so the inspector just nods
			elseif s.inspect and not d.problems[s.inspect] then
				-- the problem went away some other way (a rebirth, a mega event): send the inspector again later
				s.inspect = nil
				r.inspectAt = now + 60
			elseif not s.inspect then
				r.inspectAt = r.inspectAt or now + 40
				if now >= r.inspectAt then
					r.inspectAt = now + 30
					local options = {}
					for _, b in ipairs(C.BUSINESSES) do
						if (d.levels[b.key] or 0) > 0 and not d.problems[b.key] then table.insert(options, b.key) end
					end
					if #options > 0 then
						local key = pick(options)
						F.forceProblem(plr, d, "🧑‍⚖️ SURPRISE INSPECTION!", key, C.INSPECTION_PROBLEM)
						if d.problems[key] then
							s.inspect = key
							remote:FireClient(plr, {kind = "roast", who = "rival", text = "THE INSPECTOR IS HERE. Chat, they look nervous. Fix your " .. C.BIZ[key].name .. "!! 🧑‍⚖️"})
						end
					end
				end
			end
		end
	end
	-- the rival chimes in now and then (never more than every few minutes when nothing is happening)
	if s.ch <= 2 and d.cash < 20 and now - r.lastRoast > 120 then
		roast(plr, ROASTS.broke)
	elseif now >= r.nextRoast then
		roast(plr, ROASTS.idle[math.min(s.ch, LEGEND)] or ROASTS.idle[1])
	end
	-- employees chat at work, and the Gazette gossips about you
	if s.ch >= 3 and now >= r.nextStaff then
		r.nextStaff = now + math.random(150, 260)
		local staffed = {}
		for key in pairs(d.staff) do if C.BIZ[key] and (d.levels[key] or 0) > 0 then table.insert(staffed, key) end end
		local lines = C.STORY_STAFF_LINES[math.min(s.ch, LEGEND)]
		if #staffed > 0 and lines then
			local key = pick(staffed)
			local door = (F.slotCF(d.plot, key) * CFrame.new(0, 0, 9)).Position
			remote:FireClient(plr, {kind = "bubble", pos = door + V3(0, 7, 0), who = d.staff[key].name, text = pick(lines)})
		end
	end
	if s.ch >= 3 and now >= headlineAt and C.STORY_HEADLINES[math.min(s.ch, #STORY)] and math.random() < 0.02 then
		headlineAt = now + 600
		F.buzz("📰", string.format(pick(C.STORY_HEADLINES[math.min(s.ch, #STORY)]), plr.Name), RGB(230, 230, 230), "Corner Gazette")
	end
end

-- fans recognize you from chapter 3 on
function F.storyShout(plr, d)
	local ch = d.story and S(d).ch or 1
	local list = C.STORY_SHOUTS[math.min(ch, LEGEND)]
	if ch >= 3 and list and math.random() < 0.08 then return pick(list) end
	return nil
end

-- ===== joining: new saves start at chapter 1; saves from before story mode skip what they've already done =====
function F.storyStart(plr, d, isNew)
	run[plr] = nil
	local fresh = type(d.story) ~= "table"
	local s = S(d)
	if fresh and not isNew and (d.earned or 0) > 0 then
		-- an existing empire: chapters it has clearly already beaten are marked done (no cash: rewards are for
		-- playing a chapter), and the story picks up at the first one that isn't
		s.legacy = true
		local skipped = 0
		for i, ch in ipairs(STORY) do
			local all = true
			for _, o in ipairs(ch.objectives) do
				if not INTERACTIVE[o.kind] and not progressOf(plr, d, ch, o) then all = false end
			end
			if not all then break end
			s.done["c" .. i] = true
			s.paid["c" .. i] = true
			s.intro["c" .. i] = true
			if ch.reward and ch.reward.title then s.title = ch.reward.title end
			skipped = i
		end
		s.ch = skipped + 1
		if skipped > 0 then
			F.pushMsg(plr, {icon = "📖", from = "Story Mode", important = true, text = "STORY MODE is here! Your empire already beat " .. (skipped == 1 and "Chapter 1" or ("Chapters 1-" .. skipped)) ..
				". " .. (s.ch <= #STORY and ("Picking up at Chapter " .. s.ch .. ": " .. STORY[s.ch].title .. ".") or "You're a LEGEND already.") .. " Open Phone → Story."})
		end
	end
	-- the current chapter's intro plays once (a moment after spawning)
	task.delay(isNew and 3 or 5, function()
		if data[plr] == d then sendIntro(plr, d) end
	end)
end
function F.storyLeave(plr) run[plr] = nil end

-- ===== what the Story app and tracker show =====
function F.storyState(plr, d)
	local s = S(d)
	local ch = STORY[s.ch]
	local out = {ch = s.ch, total = #STORY, title = s.title, legacy = s.legacy == true, done = {}}
	for i = 1, #STORY do out.done[i] = s.done["c" .. i] == true end
	if not ch then return out end
	out.name, out.icon = ch.title, ch.icon
	out.obj = {}
	for i, o in ipairs(ch.objectives) do
		local done = s.obj["c" .. s.ch .. "o" .. i] == true
		local locked = o.after and not done and not othersDone(d, ch, i)
		local _, txt, f = progressOf(plr, d, ch, o)
		local entry = {t = o.text, done = done, p = done and "✅" or (locked and "🔒 Finish the others first" or txt), f = done and 1 or (locked and 0 or f)}
		if not done and not locked then
			if o.kind == "clapback" then entry.act, entry.options = "clapback", ch.clapbacks
			elseif o.kind == "finale" then entry.act = "finale"
			elseif o.kind == "challenge" and not R_(plr).challenge and os.clock() >= (R_(plr).challengeRetry or 0) then entry.act = "challenge"
			elseif o.kind == "choice" and not s.choice then
				entry.act = "choice"
				entry.options = {}
				for _, c in ipairs(ch.choices) do table.insert(entry.options, {key = c.key, label = c.label, text = c.text}) end
			end
		end
		table.insert(out.obj, entry)
	end
	local rw = ch.reward or {}
	out.reward = "$" .. fmt(math.max(rw.floor or 0, F.incomePerSec(d) * (rw.seconds or 0))) .. (rw.title and ("  •  title \"" .. rw.title .. "\"") or "") ..
		(rw.trophies and "  •  🏆" or "") .. (rw.rep and ("  •  +" .. rw.rep .. " rep") or "")
	out.paid = s.paid["c" .. s.ch] == true
	-- chapter 3: while Kevin's showdown runs, the client puts his copycat stand across the street
	if ch.copycat and R_(plr).challenge then
		out.copycat = true
		out.where = stageFor(plr, d)
	end
	return out
end
function C.storyCatalog()
	local out = {rival = C.STORY_RIVAL, cast = C.STORY_CAST, chapters = {}}
	for i, ch in ipairs(STORY) do out.chapters[i] = {title = ch.title, icon = ch.icon, blurb = ch.blurb} end
	return out
end

-- ===== buttons from the Story app =====
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.story = function(plr, d, a, b)
	local s = S(d)
	local ch = STORY[s.ch]
	local function objIndex(kind)
		if not ch then return nil end
		for i, o in ipairs(ch.objectives) do if o.kind == kind then return i end end
		return nil
	end
	if a == "clapback" then
		local i = objIndex("clapback")
		local pickN = C.int(b, 1, 3)
		if i and pickN and ch.clapbacks[pickN] and othersDone(d, ch, i) and not s.flags.clapback then s.flags.clapback = pickN end
	elseif a == "finale" then
		local i = objIndex("finale")
		if i and othersDone(d, ch, i) then s.flags.finale = true end
	elseif a == "challenge" then
		local i = objIndex("challenge")
		local r = R_(plr)
		if i and othersDone(d, ch, i) and not s.flags.copycat and not r.challenge and os.clock() >= (r.challengeRetry or 0) then
			local cfg = ch.challenge
			local target = math.floor(math.max(cfg.floor, F.incomePerSec(d) * cfg.incomeSeconds))
			r.challenge = {ends = os.clock() + cfg.seconds, base = d.earned, target = target}
			remote:FireClient(plr, {kind = "roast", who = "kevin", text = "Lemon-AID is OPEN! Bet you can't make $" .. fmt(target) .. " in " .. math.floor(cfg.seconds / 60) .. " minutes! 🥤"})
		end
	elseif a == "choice" then
		if ch and ch.choices and type(b) == "string" and choiceOf(ch, b) and not s.choice then
			s.choice = b
			notify(plr, "📖 Big move: " .. choiceOf(ch, b).label .. " — " .. choiceOf(ch, b).text)
		end
	elseif a == "replay" then
		-- watch a chapter's intro again (only ones you've reached)
		local i = C.int(b, 1, #STORY)
		if i and i <= s.ch then cutscene(plr, d, "intro", STORY[i].intro, i) end
	end
end

-- Studio test tools: jump the story to a chapter (never available in a live game)
function F.storyDebugJump(plr, d, chapter)
	if not RunService:IsStudio() then return end
	local s = S(d)
	s.ch = math.clamp(chapter, 1, LEGEND)
	for i = 1, s.ch - 1 do s.done["c" .. i] = true end
	s.intro["c" .. s.ch] = nil
	sendIntro(plr, d)
end
end
