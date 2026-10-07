-- ARCADE + FUN ZONE (v10): 2-player mini-games, played against another real player.
--
--   ⚡ Reaction Duel  — wait for GO, tap first (best of 3; tapping early is a false start)
--   👆 Button Battle — tap as fast as you can for 10 seconds
--   🏀 Hoop Duel     — 5 shots each at a moving target, closest to the centre scores
--   🏎️ Kart Sprint   — alternate LEFT / RIGHT to race your kart to the finish
--
-- Where: the Fun Zone pavilion in the Entertainment District (a booth per game), and any Arcade Machine — the
-- ones in a friend's Arcade business and the ones people put in their homes. Two players join the same booth or
-- machine and the match starts.
--
-- Everything is decided HERE on the server: the clients only send "I tapped" / "I shot" and the server times them,
-- caps impossible rates, decides who won, and hands out tickets. Leaving, walking away or disconnecting forfeits.
-- Tickets buy cosmetic prizes (furniture), never cash, and rewards are capped per opponent and per hour, so two
-- friends can't farm each other.
return function(C)
local Players = game:GetService("Players")
local F, data, R = C.F, C.data, C.R
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local P, billboard, surfaceText = C.P, C.billboard, C.surfaceText
local fmt, notify = C.fmt, C.notify
local SOLID = {CanCollide = true}

C.ARCADE_GAMES = {
	reaction = {key = "reaction", name = "Reaction Duel", icon = "⚡", color = RGB(255, 210, 60), desc = "Wait for GO, then tap first. Best of 3."},
	buttons = {key = "buttons", name = "Button Battle", icon = "👆", color = RGB(255, 90, 160), desc = "Tap as fast as you can for 10 seconds.", seconds = 10, maxRate = 14},
	hoops = {key = "hoops", name = "Hoop Duel", icon = "🏀", color = RGB(255, 130, 40), desc = "5 shots each. Hit the moving target.", shots = 5},
	sprint = {key = "sprint", name = "Kart Sprint", icon = "🏎️", color = RGB(80, 200, 255), desc = "Alternate LEFT and RIGHT to race to the finish.", goal = 60, maxRate = 12},
}
C.ARCADE_ORDER = {"reaction", "buttons", "hoops", "sprint"}
C.ARCADE_RULES = {
	winTickets = 12, playTickets = 3,
	botWinTickets = 5, botPlayTickets = 1,  -- v11.2: against the 🤖 Arcade Bot (so it can't out-earn real matches)
	pairCap = 5, pairWindow = 600,        -- rewarded games against the same opponent per 10 minutes
	hourCap = 30,                         -- rewarded games per hour
	minSeconds = 6,                       -- a match shorter than this (e.g. an instant forfeit) pays nothing
	leaveDistance = 40,                   -- walking this far from a Fun Zone booth forfeits
}
local RULES = C.ARCADE_RULES
C.ARCADE_PRIZES = {
	{key = "beanbag", tickets = 40}, {key = "pottedplant", tickets = 25}, {key = "neonbar", tickets = 120},
	{key = "gamingsetup", tickets = 400}, {key = "arcademachine", tickets = 900}, {key = "pooltable", tickets = 600},
}

local function arc(d)
	d.arcade = type(d.arcade) == "table" and d.arcade or {}
	local a = d.arcade
	a.tickets = math.max(0, math.floor(tonumber(a.tickets) or 0))
	a.wins = math.max(0, math.floor(tonumber(a.wins) or 0))
	a.played = math.max(0, math.floor(tonumber(a.played) or 0))
	return a
end
F.arcadeData = arc

-- =====================================================================
-- STATIONS: Fun Zone booths + arcade machines
-- =====================================================================
local stations = {}   -- id -> {id, game, where = Vector3 or nil, waiting = plr, match = m}
local inStation = {}  -- plr -> station id
local function station(id, game, pos)
	local s = stations[id]
	if not s then
		s = {id = id, game = game, pos = pos}
		stations[id] = s
	end
	if game then s.game = game end
	if pos then s.pos = pos end
	return s
end

local matches = {}    -- plr -> match
-- (the 🤖 Arcade Bot is a plain table standing in for the second player: nothing is ever sent to it, it has no save
-- data, and it's never in `matches`)
-- (never write plr.bot on a real Player: reading a property an Instance doesn't have is an error in Roblox)
local BOTS = setmetatable({}, {__mode = "k"})
local function isBot(p) return BOTS[p] == true end
local function send(plr, payload) if not isBot(plr) and plr.Parent then R.Menu:FireClient(plr, "arcade", payload) end end
local function other(m, plr) return m.p[1] == plr and m.p[2] or m.p[1] end
local function both(m, payload) for _, p in ipairs(m.p) do send(p, payload) end end

-- rewards with anti-farm caps
local history = {}    -- plr -> {times = {}, pairs = {[otherId] = {t...}}}
local function rewardable(plr, opp, now)
	local h = history[plr] or {times = {}, pairs = {}}
	history[plr] = h
	local recent = {}
	for _, t in ipairs(h.times) do if now - t < 3600 then table.insert(recent, t) end end
	h.times = recent
	local pr = {}
	for _, t in ipairs(h.pairs[opp.UserId] or {}) do if now - t < RULES.pairWindow then table.insert(pr, t) end end
	h.pairs[opp.UserId] = pr
	if #recent >= RULES.hourCap or #pr >= RULES.pairCap then return false end
	table.insert(h.times, now)
	table.insert(pr, now)
	return true
end
local board = {}      -- userId -> {name, wins}
local function finish(m, winner, why)
	if m.over then return end
	m.over = true
	local now = os.clock()
	local long = now - m.t0 >= RULES.minSeconds
	for _, p in ipairs(m.p) do
		matches[p] = nil
		local d = data[p]
		if d and p.Parent then
			local a = arc(d)
			local won = p == winner
			local tickets = 0
			if long and rewardable(p, other(m, p), now) then
				if m.bot then
					tickets = won and RULES.botWinTickets or (why == "forfeit" and 0 or RULES.botPlayTickets)
				else
					tickets = won and RULES.winTickets or (why == "forfeit" and 0 or RULES.playTickets)
				end
			end
			a.tickets += tickets
			a.played += 1
			if won then
				a.wins += 1
				board[p.UserId] = {name = p.Name, wins = a.wins}
			end
			send(p, {state = "end", game = m.game, won = won, draw = winner == nil, why = why, tickets = tickets, total = a.tickets, score = m.score[p], opp = m.score[other(m, p)],
				capped = long and tickets == 0 and why ~= "forfeit"})
		end
	end
	local g = C.ARCADE_GAMES[m.game]
	if winner and not m.bot and F.buzz and math.random() < 0.25 then F.buzz(g.icon, winner.Name .. " just won " .. g.name .. " against " .. other(m, winner).Name .. "!", g.color) end
	if m.station then m.station.match = nil end
end
F.arcadeFinish = finish

-- =====================================================================
-- THE GAMES (server-side rules)
-- =====================================================================
local RUN = {}
local READY, GO, BETWEEN = 1, 2, 3   -- reaction duel round phases
RUN.reaction = function(m)
	m.round, m.wins = 0, {[m.p[1]] = 0, [m.p[2]] = 0}
	m.score = m.wins
	local function round()
		if m.over then return end
		m.round += 1
		m.goAt, m.roundWinner = nil, nil
		m.early = {}
		m.phase = READY   -- READY (tapping now is a false start) → GO → BETWEEN (taps ignored)
		both(m, {state = "round", game = "reaction", round = m.round, wins = {m.wins[m.p[1]], m.wins[m.p[2]]}, names = {m.p[1].Name, m.p[2].Name}})
		local wait = 2 + math.random() * 3
		local thisRound = m.round   -- (timers from an earlier round must never fire into this one)
		task.delay(wait, function()
			if m.over or m.round ~= thisRound or m.phase ~= READY then return end
			m.goAt = os.clock()
			m.phase = GO
			both(m, {state = "go", game = "reaction"})
			-- nobody tapped within 3 s: a draw round
			task.delay(3, function()
				if m.over or m.round ~= thisRound or m.roundWinner or m.phase ~= GO then return end
				m.goAt = nil
				m.phase = BETWEEN
				task.delay(1, round)
			end)
		end)
	end
	m.press = function(plr)
		if m.over or m.phase == BETWEEN then return end
		if m.phase == READY then
			-- tapped before GO: false start, the other player takes the round
			if m.early[plr] then return end
			m.early[plr] = true
			local o = other(m, plr)
			m.wins[o] += 1
			m.roundWinner = o
			both(m, {state = "roundEnd", game = "reaction", winner = o.Name, why = plr.Name .. " jumped the gun!", wins = {m.wins[m.p[1]], m.wins[m.p[2]]}})
		elseif m.phase == GO and not m.roundWinner then
			m.roundWinner = plr
			m.wins[plr] += 1
			local ms = math.floor((os.clock() - m.goAt) * 1000)
			both(m, {state = "roundEnd", game = "reaction", winner = plr.Name, why = ms .. " ms", wins = {m.wins[m.p[1]], m.wins[m.p[2]]}})
		else
			return
		end
		m.goAt = nil
		m.phase = BETWEEN
		if m.wins[plr] >= 2 or m.wins[other(m, plr)] >= 2 then
			task.delay(1.5, function() finish(m, m.wins[m.p[1]] >= 2 and m.p[1] or m.p[2], "won") end)
		else
			task.delay(1.8, round)
		end
	end
	round()
end
RUN.buttons = function(m)
	local g = C.ARCADE_GAMES.buttons
	m.score = {[m.p[1]] = 0, [m.p[2]] = 0}
	both(m, {state = "start", game = "buttons", seconds = g.seconds, names = {m.p[1].Name, m.p[2].Name}})
	m.start = os.clock()
	m.tap = function(plr, n)
		if m.over then return end
		local el = os.clock() - m.start
		if el > g.seconds + 0.5 then return end
		-- a person can't tap faster than ~14 times a second: anything above that is ignored
		local allowed = math.floor(g.maxRate * el) + 3
		m.score[plr] = math.min(allowed, m.score[plr] + n)
		both(m, {state = "update", game = "buttons", scores = {m.score[m.p[1]], m.score[m.p[2]]}})
	end
	task.delay(g.seconds + 0.6, function()
		if m.over then return end
		local a, b = m.score[m.p[1]], m.score[m.p[2]]
		finish(m, a > b and m.p[1] or (b > a and m.p[2] or nil), a == b and "draw" or "won")
	end)
end
RUN.hoops = function(m)
	local g = C.ARCADE_GAMES.hoops
	m.score = {[m.p[1]] = 0, [m.p[2]] = 0}
	m.shots = {[m.p[1]] = 0, [m.p[2]] = 0}
	-- the target moves on a schedule only the server knows exactly; the client draws it from the same numbers
	m.speed = 1.6 + math.random() * 0.6
	m.center = 0.25 + math.random() * 0.5
	m.start = os.clock()
	both(m, {state = "start", game = "hoops", speed = m.speed, center = m.center, shots = g.shots, names = {m.p[1].Name, m.p[2].Name}})
	m.shoot = function(plr)
		if m.over or m.shots[plr] >= g.shots then return end
		local now = os.clock()
		if m.lastShot and m.lastShot[plr] and now - m.lastShot[plr] < 0.6 then return end   -- one shot at a time
		m.lastShot = m.lastShot or {}
		m.lastShot[plr] = now
		m.shots[plr] += 1
		local v = (math.sin((now - m.start) * m.speed * 2) + 1) / 2
		local off = math.abs(v - m.center)
		local pts = off < 0.06 and 2 or (off < 0.13 and 1 or 0)
		m.score[plr] += pts
		send(plr, {state = "shot", game = "hoops", pts = pts, left = g.shots - m.shots[plr]})
		both(m, {state = "update", game = "hoops", scores = {m.score[m.p[1]], m.score[m.p[2]]}, shotsLeft = {g.shots - m.shots[m.p[1]], g.shots - m.shots[m.p[2]]}})
		if m.shots[m.p[1]] >= g.shots and m.shots[m.p[2]] >= g.shots then
			local a, b = m.score[m.p[1]], m.score[m.p[2]]
			task.delay(1, function() finish(m, a > b and m.p[1] or (b > a and m.p[2] or nil), a == b and "draw" or "won") end)
		end
	end
	-- shots not taken within 40 s are misses
	task.delay(40, function()
		if m.over then return end
		local a, b = m.score[m.p[1]], m.score[m.p[2]]
		finish(m, a > b and m.p[1] or (b > a and m.p[2] or nil), a == b and "draw" or "won")
	end)
end
RUN.sprint = function(m)
	local g = C.ARCADE_GAMES.sprint
	m.score = {[m.p[1]] = 0, [m.p[2]] = 0}
	m.start = os.clock()
	both(m, {state = "start", game = "sprint", goal = g.goal, names = {m.p[1].Name, m.p[2].Name}})
	m.step = function(plr, n)
		if m.over then return end
		local el = os.clock() - m.start
		local allowed = math.floor(g.maxRate * el) + 2
		m.score[plr] = math.min(allowed, m.score[plr] + n, g.goal)
		both(m, {state = "update", game = "sprint", scores = {m.score[m.p[1]], m.score[m.p[2]]}})
		if m.score[plr] >= g.goal then finish(m, plr, "won") end
	end
	task.delay(45, function()
		if m.over then return end
		local a, b = m.score[m.p[1]], m.score[m.p[2]]
		finish(m, a > b and m.p[1] or (b > a and m.p[2] or nil), a == b and "draw" or "won")
	end)
end

-- =====================================================================
-- JOINING / LEAVING
-- =====================================================================
local function leaveStation(plr)
	local id = inStation[plr]
	inStation[plr] = nil
	local s = id and stations[id]
	if s and s.waiting == plr then s.waiting = nil end
end
function F.arcadeForfeit(plr, why)
	local m = matches[plr]
	if m and not m.over then
		local o = other(m, plr)
		send(plr, {state = "forfeit", why = why})
		finish(m, o, "forfeit")
		if not isBot(o) then notify(o, "🕹️ " .. plr.Name .. " left the game. You win!") end
	end
	leaveStation(plr)
end
function F.arcadeJoin(plr, id, game)
	local d = data[plr]
	local s = stations[id]
	if not (d and s) then return false end
	game = s.game or game
	if not C.ARCADE_GAMES[game] then return false end
	if matches[plr] then notify(plr, "🕹️ Finish your current game first.") return false end
	if s.match then notify(plr, "🕹️ This one is busy — wait for the next game.") return false end
	if s.waiting == plr then return false end
	leaveStation(plr)
	if s.waiting and s.waiting.Parent and data[s.waiting] and not matches[s.waiting] then
		local opp = s.waiting
		s.waiting = nil
		inStation[opp] = nil
		local m = {game = game, p = {opp, plr}, t0 = os.clock(), station = s, score = {}}
		s.match = m
		matches[opp], matches[plr] = m, m
		both(m, {state = "matched", game = game, names = {opp.Name, plr.Name}})
		task.delay(1.5, function()
			if not m.over then RUN[game](m) end
		end)
		F.markActive(plr)
		return true
	end
	s.waiting = plr
	inStation[plr] = id
	send(plr, {state = "waiting", game = game, station = id})
	return true
end
-- =====================================================================
-- THE 🤖 ARCADE BOT (v11.2): play right away when nobody else is around
-- =====================================================================
-- A fair, beatable opponent. It "plays" through the same rules as a person (the same rate caps, the same timing),
-- so the server still decides everything.
local function botPlay(m, bot)
	local g = m.game
	task.spawn(function()
		if g == "reaction" then
			local lastRound, delay = nil, 0
			while not m.over do
				task.wait(0.05)
				if m.round ~= lastRound then
					lastRound = m.round
					delay = 0.28 + math.random() * 0.32      -- 280-600 ms
				end
				if m.phase == GO and not m.roundWinner and m.goAt and os.clock() - m.goAt >= delay and m.press then m.press(bot) end
			end
		elseif g == "buttons" then
			while not m.over do
				task.wait(0.25)
				if m.tap then m.tap(bot, math.random(1, 3)) end     -- ~8 taps a second
			end
		elseif g == "hoops" then
			for _ = 1, C.ARCADE_GAMES.hoops.shots do
				task.wait(2 + math.random() * 2.5)
				if m.over then return end
				if m.shoot then m.shoot(bot) end
			end
		elseif g == "sprint" then
			while not m.over do
				task.wait(0.25)
				if m.step then m.step(bot, math.random(1, 2)) end     -- ~6 steps a second
			end
		end
	end)
end
function F.arcadeBot(plr, game)
	local d = data[plr]
	if not d then return false end
	if matches[plr] then notify(plr, "🕹️ Finish your current game first.") return false end
	-- waiting at a booth? play that booth's game against the bot instead
	local id = inStation[plr]
	local s = id and stations[id]
	if s and s.game then game = s.game end
	if not C.ARCADE_GAMES[game] then return false end
	leaveStation(plr)
	local bot = {Name = "🤖 Arcade Bot", UserId = -1}
	BOTS[bot] = true
	local m = {game = game, p = {plr, bot}, t0 = os.clock(), score = {}, bot = bot}
	matches[plr] = m
	send(plr, {state = "matched", game = game, names = {plr.Name, bot.Name}, bot = true})
	task.delay(1.5, function()
		if m.over then return end
		RUN[game](m)
		botPlay(m, bot)
	end)
	F.markActive(plr)
	return true
end

-- a machine somewhere (home, Arcade business): its own station, game picked by the first player
function F.arcadeMachine(plr, owner, where)
	if not (owner and data[owner]) then return end
	local id = "machine:" .. owner.UserId .. ":" .. tostring(where)
	local s = station(id, nil, nil)
	s.room = {owner.UserId, where}
	if s.waiting and s.waiting ~= plr then
		F.arcadeJoin(plr, id)
	else
		R.Menu:FireClient(plr, "arcadePick", {station = id, games = C.ARCADE_ORDER})
	end
end

-- walking away from a booth, or a machine's room, forfeits
task.spawn(function()
	while true do
		task.wait(1)
		for plr, m in pairs(matches) do
			if not m.over then
				local s = m.station
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if not plr.Parent or not root then
					F.arcadeForfeit(plr, "left")
				elseif s and s.pos and (root.Position - s.pos).Magnitude > RULES.leaveDistance then
					F.arcadeForfeit(plr, "walked away")
				elseif s and s.room and (plr:GetAttribute("InteriorOwner") ~= s.room[1] or plr:GetAttribute("Interior") ~= s.room[2]) then
					F.arcadeForfeit(plr, "walked away")
				end
			end
		end
		for plr, id in pairs(inStation) do
			local s = stations[id]
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			local gone = s and s.room and (plr:GetAttribute("InteriorOwner") ~= s.room[1] or plr:GetAttribute("Interior") ~= s.room[2])
			if not plr.Parent or not s or gone or (s.pos and root and (root.Position - s.pos).Magnitude > RULES.leaveDistance) then
				leaveStation(plr)
				if plr.Parent then send(plr, {state = "left"}) end
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	F.arcadeForfeit(plr, "disconnected")
	history[plr] = nil
end)

-- =====================================================================
-- PRIZES + LEADERBOARD
-- =====================================================================
function F.arcadePrize(plr, key)
	local d = data[plr]
	if not d then return false end
	local prize
	for _, p in ipairs(C.ARCADE_PRIZES) do if p.key == key then prize = p end end
	if not prize then return false end
	local a = arc(d)
	if a.tickets < prize.tickets then notify(plr, "🎟️ You need " .. prize.tickets .. " tickets.") return false end
	a.tickets -= prize.tickets
	d.furniture = type(d.furniture) == "table" and d.furniture or {}
	d.furniture[key] = (tonumber(d.furniture[key]) or 0) + 1
	local it = C.FURNITURE_BY and C.FURNITURE_BY[key]
	notify(plr, "🎟️ Traded " .. prize.tickets .. " tickets for a " .. (it and (it.icon .. " " .. it.name) or key) .. " (in your furniture storage).")
	return true
end
function F.arcadeBoard()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local d = data[plr]
		if d then board[plr.UserId] = {name = plr.Name, wins = arc(d).wins} end
	end
	for _, e in pairs(board) do table.insert(list, e) end
	table.sort(list, function(x, y) return x.wins > y.wins end)
	local top = {}
	for i = 1, math.min(5, #list) do top[i] = list[i] end
	return top
end
function F.arcadeInfo(plr)
	local d = data[plr]
	local a = arc(d)
	local prizes = {}
	for _, p in ipairs(C.ARCADE_PRIZES) do
		local it = C.FURNITURE_BY and C.FURNITURE_BY[p.key]
		table.insert(prizes, {key = p.key, tickets = p.tickets, name = it and it.name or p.key, icon = it and it.icon or "🎁"})
	end
	local games = {}
	for _, k in ipairs(C.ARCADE_ORDER) do local g = C.ARCADE_GAMES[k] table.insert(games, {key = k, name = g.name, icon = g.icon, desc = g.desc}) end
	return {tickets = a.tickets, wins = a.wins, played = a.played, prizes = prizes, board = F.arcadeBoard(), games = games}
end

-- =====================================================================
-- THE FUN ZONE PAVILION
-- =====================================================================
local boardLabel
do
	local at = C.FUN_ZONE_AT and C.FUN_ZONE_AT.Position or V3(-455, 0, -215)
	local f = Instance.new("Folder")
	f.Name = "FunZone"
	f.Parent = C.WORLD
	P(f, V3(48, 0.4, 148), CF(at + V3(0, 0.2, 0)), RGB(60, 50, 80), MAT.Concrete, SOLID)
	for i = 0, 14 do P(f, V3(48, 0.05, 0.4), CF(at + V3(0, 0.43, -72 + i * 10.3)), Color3.fromHSV(i / 15, 0.7, 1), MAT.Neon) end
	local arch = P(f, V3(30, 4, 2), CF(at + V3(0, 14, 74)), RGB(40, 30, 70), MAT.SmoothPlastic)
	surfaceText(arch, Enum.NormalId.Front, "🕹️ FUN ZONE • 2-PLAYER GAMES", RGB(255, 220, 90))
	for _, sx in ipairs({-14, 14}) do P(f, V3(2, 14, 2), CF(at + V3(sx, 7, 74)), RGB(255, 90, 160), MAT.Neon) end
	local slots = {-58, -30, 30, 58}
	for i, key in ipairs(C.ARCADE_ORDER) do
		local g = C.ARCADE_GAMES[key]
		local base = at + V3(0, 0, slots[i])
		P(f, V3(20, 0.6, 18), CF(base + V3(0, 0.6, 0)), RGB(30, 26, 44), MAT.SmoothPlastic, SOLID)
		local screen = P(f, V3(10, 6, 0.6), CF(base + V3(0, 5, -7)), RGB(14, 14, 22), MAT.SmoothPlastic, SOLID)
		surfaceText(screen, Enum.NormalId.Front, g.icon .. " " .. string.upper(g.name), g.color)
		P(f, V3(10.6, 0.4, 0.8), CF(base + V3(0, 8.2, -7)), g.color, MAT.Neon)
		local id = "booth:" .. key
		station(id, key, base)
		for _, sx in ipairs({-5, 5}) do
			P(f, V3(5, 0.3, 5), CF(base + V3(sx, 1, 1)), g.color, MAT.Neon, {Transparency = 0.3})
			local cab = P(f, V3(3, 4.5, 2), CF(base + V3(sx, 3, -3.5)), RGB(50, 40, 90), MAT.SmoothPlastic, SOLID)
			C.prompt(cab, "Play " .. g.name, "2-player game", 10, 0.2, function(plr) F.arcadeJoin(plr, id, key) end)
		end
		billboard(screen, UDim2.fromOffset(220, 40), V3(0, 5, 0), {{text = g.desc, h = 1, font = Enum.Font.GothamBold, color = RGB(230, 230, 240)}}, 80)
	end
	-- prize counter + leaderboard in the middle
	local counter = P(f, V3(14, 3.4, 3), CF(at + V3(-10, 1.9, 0)), RGB(255, 210, 60), MAT.SmoothPlastic, SOLID)
	surfaceText(counter, Enum.NormalId.Right, "🎟️ PRIZES", RGB(40, 30, 10))
	C.prompt(counter, "Prize Counter", "Trade tickets", 10, 0, function(plr)
		if data[plr] then R.Menu:FireClient(plr, "arcadeInfo", F.arcadeInfo(plr)) end
	end)
	local lb = P(f, V3(0.6, 9, 14), CF(at + V3(12, 5.5, 0)), RGB(14, 14, 22), MAT.SmoothPlastic, SOLID)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Left
	sg.CanvasSize = Vector2.new(420, 270)
	sg.LightInfluence = 0
	sg.Parent = lb
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = RGB(255, 220, 90)
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBlack
	tl.Text = "🏆 TOP PLAYERS\n—"
	tl.Parent = sg
	boardLabel = tl
	C.FUN_ZONE = f
end
task.spawn(function()
	while true do
		task.wait(20)
		if boardLabel then
			local lines = {"🏆 ARCADE CHAMPIONS"}
			for i, e in ipairs(F.arcadeBoard()) do table.insert(lines, i .. ". " .. e.name .. " — " .. e.wins .. " wins") end
			boardLabel.Text = table.concat(lines, "\n")
		end
	end
end)

-- an Arcade business gets a 2-player duel cabinet (Interiors calls this while building the room)
function C.arcadeRoom(m, o, L, owner)
	local x, z = L.w / 2 - 14, L.d / 2 - 7
	local cab = P(m, V3(5, 6.4, 3), o * CF(x, 3.7, z), RGB(60, 30, 120), MAT.SmoothPlastic, SOLID)
	P(m, V3(4.2, 2.2, 0.2), o * CF(x, 4.8, z - 1.55), RGB(255, 210, 60), MAT.Neon)
	surfaceText(P(m, V3(4.6, 0.9, 0.2), o * CF(x, 7.4, z - 1.55), RGB(20, 20, 26)), Enum.NormalId.Front, "2P DUEL", RGB(255, 210, 60))
	C.prompt(cab, "Play 2P", "Duel Cabinet", 10, 0, function(plr) F.arcadeMachine(plr, owner, "arcade") end)
end

-- =====================================================================
-- ACTIONS
-- =====================================================================
C.ACTIONS = C.ACTIONS or {}
C.ACTIONS.arcInfo = function(plr) R.Menu:FireClient(plr, "arcadeInfo", F.arcadeInfo(plr)) end
C.ACTIONS.arcLeave = function(plr) F.arcadeForfeit(plr, "left") end
C.ACTIONS.arcBot = function(plr, d, a) if a == nil or (C.str(a, 12) and C.ARCADE_GAMES[a]) then F.arcadeBot(plr, a) end end
C.ACTIONS.arcPick = function(plr, d, a, b)
	-- a = station id (a machine), b = game key
	if C.str(a, 60) and stations[a] and C.str(b, 12) and C.ARCADE_GAMES[b] and string.sub(a, 1, 8) == "machine:" then
		local s = stations[a]
		if not s.waiting and not s.match then s.game = b end
		F.arcadeJoin(plr, a, b)
	end
end
C.ACTIONS.arcPress = function(plr)
	local m = matches[plr]
	if m and m.press then m.press(plr) end
end
C.ACTIONS.arcTap = function(plr, d, a)
	local n = C.int(a, 1, 8)
	local m = matches[plr]
	if n and m and m.tap then m.tap(plr, n) end
end
C.ACTIONS.arcShoot = function(plr)
	local m = matches[plr]
	if m and m.shoot then m.shoot(plr) end
end
C.ACTIONS.arcStep = function(plr, d, a)
	local n = C.int(a, 1, 6)
	local m = matches[plr]
	if n and m and m.step then m.step(plr, n) end
end
C.ACTIONS.arcPrize = function(plr, d, a)
	if C.str(a, 24) then F.arcadePrize(plr, a) end
	R.Menu:FireClient(plr, "arcadeInfo", F.arcadeInfo(plr))
end
end
