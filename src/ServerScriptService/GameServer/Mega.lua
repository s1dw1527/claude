-- MEGA: server-wide mega events (UFO invasion, tornado, billionaire, festival, robbery wave...) and City Era visuals.
-- Everything that pays out is decided here on the server; clients only draw the big announcement.
return function(C)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R, G = C.F, C.data, C.R, C.G
local P, ball, cyl, ghost, billboard, surfaceText, smoke, sparkle, burst, shockwave, spin, tag =
	C.P, C.ball, C.cyl, C.ghost, C.billboard, C.surfaceText, C.smoke, C.sparkle, C.burst, C.shockwave, C.spin, C.tag
local CFG, BUSINESSES, BIZ, fmt, notify, announceAll = C.CFG, C.BUSINESSES, C.BIZ, C.fmt, C.notify, C.announceAll
local MEGA_EVENTS, MEGA = C.MEGA_EVENTS, C.MEGA
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 250), RGB(30, 30, 36)

-- places around the city where probes, tokens and cash can appear (all on roads, plazas or paths)
local SPOTS = {
	V3(-14, 0.3, 14), V3(128, 0.3, 0), V3(-128, 0.3, 0), V3(0, 0.3, 128), V3(0, 0.3, -128),
	V3(230, 0.3, -18), V3(-230, 0.3, -18), V3(0, 0.3, 398), V3(212, 0.3, -222), V3(40, 0.3, -143),
	V3(-470, 0.3, 18), V3(415, 0.3, 18), V3(-330, 0.3, 128), V3(330, 0.3, 128), V3(-330, 0.3, -128),
	V3(330, 0.3, -128), V3(250, 0.3, 160), V3(-150, 0.3, 225), V3(-400, 0.3, 225), V3(100, 0.3, 300),
	V3(-60, 0.3, 335), V3(470, 0.3, 335), V3(-470, 0.3, -300), V3(230, 0.3, 128),
}
local STAGE_AT = V3(230, 0, 96)      -- Downtown concert stage
C.reserve(STAGE_AT.X - 22, STAGE_AT.Z - 16, STAGE_AT.X + 22, STAGE_AT.Z + 20)

local M = {active = nil, nextAt = os.clock() + MEGA.first}
C.MEGA_STATE = M

-- ===== helpers =====
local function playing()
	local out = {}
	for plr, d in pairs(data) do
		if plr.Parent then table.insert(out, {plr = plr, d = d}) end
	end
	return out
end
local function rootOf(plr)
	local ch = plr.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end
-- rewards scale with each player's own income, with a floor so new players still get something
local function reward(d, seconds, floor) return math.floor(math.max(floor * C.ECONOMY.eventFloorScale, F.incomePerSec(d) * seconds)) end
local function pay(plr, amount, rep, why)
	local d = data[plr]
	if not d or amount <= 0 then return end
	d.cash += amount
	F.earn(d, amount)
	if rep and rep ~= 0 then F.addRep(plr, rep) end
	if why then notify(plr, why .. "  +$" .. fmt(amount)) end
end
local function shuffled(list, n)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	local out = {}
	for i = 1, math.min(n, #copy) do out[i] = copy[i] end
	return out
end
local function send(payload) R.Mega:FireAllClients(payload) end
local function progress(ev, text)
	ev.progressText = text
	send({kind = "progress", key = ev.def.key, text = text, left = math.max(0, math.ceil(ev.endsAt - os.clock()))})
end

-- a glowing thing with a prompt; the first player to use it claims it
local function target(ev, pos, look, action, onHit)
	local m = Instance.new("Model")
	m.Name = "MegaTarget"
	m.Parent = ev.folder
	local base = look(m, pos)
	local handle = {model = m, alive = true}
	C.prompt(base, action, ev.def.title, 14, 0, function(plr)
		if not handle.alive or not data[plr] or not ev.running then return end
		handle.alive = false
		burst(base.Position + V3(0, 2, 0), ev.def.color, 60)
		m:Destroy()
		onHit(plr)
	end)
	table.insert(ev.targets, handle)
	return handle
end
-- a pickup: anyone who walks or drives within 8 studs grabs it (checked by the server loop)
local function pickup(ev, pos, look, onGet)
	local m = Instance.new("Model")
	m.Name = "MegaPickup"
	m.Parent = ev.folder
	look(m, pos)
	local item = {model = m, pos = pos, alive = true, onGet = onGet}
	table.insert(ev.pickups, item)
	return item
end
local function checkPickups(ev)
	if #ev.pickups == 0 then return end
	local roots = {}
	for _, e in ipairs(playing()) do
		local r = rootOf(e.plr)
		if r then table.insert(roots, {plr = e.plr, pos = r.Position}) end
	end
	for i = #ev.pickups, 1, -1 do
		local item = ev.pickups[i]
		if not item.alive or not item.model.Parent then
			table.remove(ev.pickups, i)
		else
			for _, r in ipairs(roots) do
				local dx, dz = r.pos.X - item.pos.X, r.pos.Z - item.pos.Z
				if dx * dx + dz * dz < 64 and math.abs(r.pos.Y - item.pos.Y) < 14 then
					item.alive = false
					burst(item.pos + V3(0, 3, 0), ev.def.color, 40)
					item.model:Destroy()
					table.remove(ev.pickups, i)
					item.onGet(r.plr)
					break
				end
			end
		end
	end
end

-- ===== look builders =====
local function probeLook(m, pos)
	local base = cyl(m, 0.4, 3, CF(pos + V3(0, 0.2, 0)), RGB(60, 60, 70), MAT.Metal, SOLID)
	local orb = ball(m, V3(2.2, 2.2, 2.2), CF(pos + V3(0, 2.2, 0)), RGB(120, 255, 140), MAT.Neon)
	P(m, V3(0.2, 2, 0.2), CF(pos + V3(0, 4, 0)), RGB(200, 200, 210), MAT.Metal)
	ball(m, V3(0.6, 0.6, 0.6), CF(pos + V3(0, 5.1, 0)), RGB(255, 60, 60), MAT.Neon)
	sparkle(orb, RGB(120, 255, 140), 8)
	billboard(orb, UDim2.fromOffset(60, 40), V3(0, 3.4, 0), {{text = "👽"}}, 260)
	return orb
end
local function cashLook(m, pos)
	local p = P(m, V3(2.2, 1.2, 1.4), CF(pos + V3(0, 1.6, 0)) * CFrame.Angles(0, math.random() * 6, 0), RGB(90, 200, 100), MAT.SmoothPlastic)
	P(m, V3(0.3, 1.25, 1.45), p.CFrame, RGB(240, 240, 220))
	sparkle(p, RGB(120, 255, 150), 6)
	billboard(p, UDim2.fromOffset(40, 34), V3(0, 2, 0), {{text = "💵"}}, 160)
	return p
end
local function tokenLook(m, pos)
	local p = cyl(m, 0.4, 2.6, CF(pos + V3(0, 2.2, 0)) * CFrame.Angles(math.rad(90), 0, 0), RGB(255, 200, 60), MAT.Neon)
	spin(p, 2)
	sparkle(p, RGB(255, 220, 120), 10)
	billboard(p, UDim2.fromOffset(44, 40), V3(0, 2.4, 0), {{text = "🎟️"}}, 220)
	return p
end
local function icePopLook(m, pos)
	local p = P(m, V3(1, 2.2, 0.5), CF(pos + V3(0, 2.2, 0)), Color3.fromHSV(math.random(), 0.6, 1), MAT.Neon)
	P(m, V3(0.25, 1, 0.25), CF(pos + V3(0, 0.8, 0)), RGB(220, 190, 140), MAT.Wood)
	sparkle(p, RGB(200, 240, 255), 6)
	billboard(p, UDim2.fromOffset(40, 34), V3(0, 2, 0), {{text = "🧊"}}, 200)
	return p
end
local function snowmanLook(m, pos)
	ball(m, V3(4, 4, 4), CF(pos + V3(0, 2, 0)), WHITE, MAT.Snow)
	ball(m, V3(3, 3, 3), CF(pos + V3(0, 5, 0)), WHITE, MAT.Snow)
	local head = ball(m, V3(2.2, 2.2, 2.2), CF(pos + V3(0, 7.2, 0)), WHITE, MAT.Snow)
	P(m, V3(0.3, 0.3, 1.2), CF(pos + V3(0, 7.2, -1.3)), RGB(255, 140, 40))
	cyl(m, 1.2, 1.8, CF(pos + V3(0, 8.6, 0)), DARK)
	billboard(head, UDim2.fromOffset(44, 40), V3(0, 2.6, 0), {{text = "☃️"}}, 220)
	return head
end
local function robberLook(m, pos)
	local body = P(m, V3(2, 2, 1), CF(pos + V3(0, 3, 0)), RGB(30, 30, 36))
	ball(m, V3(1.3, 1.3, 1.3), CF(pos + V3(0, 4.65, 0)), RGB(20, 20, 24))
	P(m, V3(1.35, 0.3, 1.35), CF(pos + V3(0, 4.8, -0.05)), RGB(240, 240, 240))
	for _, sx in ipairs({-0.5, 0.5}) do P(m, V3(0.95, 2, 0.95), CF(pos + V3(sx, 1, 0)), RGB(40, 40, 60)) end
	local sack = ball(m, V3(1.8, 1.8, 1.8), CF(pos + V3(1.6, 3, 0.5)), RGB(160, 130, 80), MAT.Fabric)
	billboard(sack, UDim2.fromOffset(60, 40), V3(0, 2.6, 0), {{text = "💰🚨"}}, 220)
	return body
end

-- ===== the events =====
local DEFS = {}

local function ufo(ev, pos, scale)
	local m = Instance.new("Model")
	m.Name = "UFO"
	m.Parent = ev.folder
	local disc = cyl(m, 3 * scale, 26 * scale, CF(pos), RGB(170, 175, 190), MAT.Metal)
	ball(m, V3(12, 7, 12) * scale, CF(pos + V3(0, 2.5 * scale, 0)), RGB(150, 230, 255), MAT.Glass, {Transparency = 0.3})
	local rim = cyl(m, 1 * scale, 28 * scale, CF(pos + V3(0, -0.6 * scale, 0)), RGB(120, 255, 140), MAT.Neon)
	spin(rim, 1.5)
	spin(disc, 0.6)
	local beam = cyl(m, pos.Y, 9 * scale, CF(pos.X, pos.Y / 2, pos.Z), RGB(140, 255, 160), MAT.Neon, {Transparency = 0.75, CastShadow = false})
	beam.CastShadow = false
	local pl = Instance.new("PointLight")
	pl.Color = RGB(140, 255, 160)
	pl.Range = 60
	pl.Brightness = 3
	pl.Parent = disc
end
local function invasion(ev, ufos, probes, perProbe)
	for i, pos in ipairs(ufos) do ufo(ev, pos, i == 1 and 1.2 or 1) end
	ev.goal, ev.done = probes, 0
	for _, pos in ipairs(shuffled(SPOTS, probes)) do
		target(ev, pos, probeLook, "Zap probe ⚡", function(plr)
			ev.done += 1
			pay(plr, reward(data[plr], perProbe, 500), 3, "⚡ Probe zapped!")
			progress(ev, "⚡ Probes zapped: " .. ev.done .. "/" .. ev.goal)
			if ev.done >= ev.goal then
				ev.success = true
				ev.endsAt = os.clock()
			end
		end)
	end
	progress(ev, "⚡ Probes zapped: 0/" .. probes)
end
local function invasionEnd(ev, buff, lossSeconds)
	if ev.success then
		for _, e in ipairs(playing()) do
			e.d.megaBuffUntil, e.d.megaBuffMult = os.clock() + 180, 1 + buff
		end
		return "🎉 CITY SAVED!", "Every probe was zapped. Everyone earns +" .. math.floor(buff * 100) .. "% income for 3 minutes!"
	end
	for _, e in ipairs(playing()) do
		local loss = math.floor(math.min(e.d.cash * 0.03, F.incomePerSec(e.d) * lossSeconds))
		e.d.cash -= loss
		if loss > 0 then notify(e.plr, "🛸 The UFO abducted $" .. fmt(loss) .. " from your vault!") end
	end
	return "🛸 THE ALIENS ESCAPED", ev.done .. "/" .. ev.goal .. " probes zapped. They took a little cash with them..."
end
DEFS.ufo = {
	start = function(ev) invasion(ev, {V3(0, 105, 0)}, 8, 20) end,
	finish = function(ev) return invasionEnd(ev, 0.1, 30) end,
}
DEFS.aliens = {
	start = function(ev) invasion(ev, {V3(0, 115, 0), V3(-230, 95, 0), V3(230, 95, 0)}, 14, 25) end,
	finish = function(ev) return invasionEnd(ev, 0.2, 45) end,
}

-- tornado: a funnel crosses the city (clients animate it), dropping cash and damaging businesses it passes
DEFS.tornado = {
	start = function(ev)
		local paths = {{V3(-620, 0, -60), V3(620, 0, 40)}, {V3(40, 0, -560), V3(-40, 0, 380)}, {V3(-520, 0, 300), V3(520, 0, -300)}}
		local path = paths[math.random(#paths)]
		ev.from, ev.to = path[1], path[2]
		local m = Instance.new("Model")
		m.Name = "Tornado"
		for k = 0, 7 do
			local r = 6 + k * 3.2
			local p = cyl(m, 7, r, CF(ev.from + V3(0, 3.5 + k * 6.5, 0)), RGB(150 - k * 6, 155 - k * 6, 170 - k * 6), MAT.SmoothPlastic, {Transparency = 0.35 + k * 0.03, CastShadow = false})
			spin(p, 3 - k * 0.2)
			if k % 2 == 0 then smoke(p, true, 10) end
		end
		for k = 1, 6 do ball(m, V3(1.5, 1.5, 1.5), CF(ev.from + V3(math.cos(k) * 10, 8 + k * 5, math.sin(k) * 10)), RGB(110, 90, 70), MAT.Wood) end
		m:SetAttribute("From", ev.from)
		m:SetAttribute("To", ev.to)
		m:SetAttribute("T0", Workspace:GetServerTimeNow())
		m:SetAttribute("Dur", ev.def.dur)
		m.Parent = ev.folder
		tag(m, "MegaMover")
		ev.hitPlots, ev.dropT, ev.grabbed = {}, 0, 0
		progress(ev, "💵 Cash grabbed: 0")
	end,
	tick = function(ev, dt)
		local a = math.clamp((os.clock() - ev.startedAt) / ev.def.dur, 0, 1)
		local pos = ev.from:Lerp(ev.to, a)
		ev.dropT -= dt
		if ev.dropT <= 0 then
			ev.dropT = 2.5
			for _ = 1, 2 do
				local p = pos + V3(math.random(-28, 28), 0.3, math.random(-28, 28))
				pickup(ev, p, cashLook, function(plr)
					ev.grabbed += 1
					pay(plr, reward(data[plr], 12, 300), 1, "💵 Grabbed flying cash!")
					progress(ev, "💵 Cash grabbed: " .. ev.grabbed)
				end)
			end
		end
		-- damage: each empire the funnel passes gets one business knocked out (the Engineer saves it half the time)
		for _, e in ipairs(playing()) do
			local c = e.d.plot.center
			if not ev.hitPlots[e.plr] and (V3(c.X, 0, c.Z) - V3(pos.X, 0, pos.Z)).Magnitude < 60 then
				ev.hitPlots[e.plr] = true
				if e.d.staff.engineer and math.random() < 0.5 then
					notify(e.plr, "🌪️ The tornado hit your empire... but your Engineer bolted everything down!")
				elseif F.forceProblem then
					F.forceProblem(e.plr, e.d, "🌪️ The tornado hit your empire!")
				end
			end
		end
	end,
	finish = function(ev) return "🌪️ THE TORNADO HAS PASSED", ev.grabbed .. " bundles of cash were grabbed from the wind." end,
}

-- billionaire: pitch once each; the biggest empire among the pitchers lands the deal
DEFS.investor = {
	start = function(ev)
		local at = V3(22, 0.3, 26)
		local limoSpec = table.clone(C.CAR.golden)
		limoSpec.L, limoSpec.cab = 22, 10
		local limo = C.buildCar(limoSpec, CF(at) * CFrame.Angles(0, math.rad(90), 0), "RICH")
		for _, p in ipairs(limo:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		limo.Parent = ev.folder
		local man = Instance.new("Model")
		man.Parent = ev.folder
		local body = P(man, V3(2, 2, 1), CF(at + V3(-2, 3, -8)), RGB(25, 25, 30))
		ball(man, V3(1.3, 1.3, 1.3), CF(at + V3(-2, 4.65, -8)), RGB(255, 220, 180))
		cyl(man, 1.4, 1.2, CF(at + V3(-2, 5.8, -8)), RGB(20, 20, 24))
		for _, sx in ipairs({-0.5, 0.5}) do P(man, V3(0.95, 2, 0.95), CF(at + V3(-2 + sx, 1, -8)), RGB(25, 25, 30)) end
		sparkle(body, RGB(255, 215, 90), 10)
		billboard(body, UDim2.fromOffset(240, 60), V3(0, 4.5, 0), {{text = "💰 THE BILLIONAIRE", h = 0.55, color = RGB(255, 215, 90)}, {text = "Pitch your empire!", h = 0.45}}, 400)
		ev.pitches = {}
		C.prompt(body, "Pitch your empire 💼", "Billionaire", 16, 0.8, function(plr)
			local d = data[plr]
			if not d or not ev.running or ev.pitches[plr] then return end
			ev.pitches[plr] = F.empireScore(d)
			pay(plr, reward(d, 30, 1000), 5, "💼 The billionaire liked your pitch!")
			local n = 0
			for _ in pairs(ev.pitches) do n += 1 end
			progress(ev, "💼 Pitches: " .. n)
		end)
		progress(ev, "💼 Pitches: 0  •  go to the Spire plaza!")
	end,
	finish = function(ev)
		local best, bestScore = nil, -1
		for plr, score in pairs(ev.pitches) do
			if data[plr] and score > bestScore then best, bestScore = plr, score end
		end
		if not best then return "💰 THE BILLIONAIRE LEFT", "Nobody pitched. Maybe next time!" end
		local d = data[best]
		local jackpot = reward(d, 240, 20000)
		pay(best, jackpot, 25, "💰 YOU LANDED THE BILLIONAIRE DEAL!")
		F.buzz("💰", best.Name .. " landed a $" .. fmt(jackpot) .. " deal with a visiting billionaire!", RGB(255, 215, 90))
		return "💰 DEAL CLOSED!", best.Name .. " won the billionaire's investment: $" .. fmt(jackpot) .. "!"
	end,
}

local function tokenHunt(ev, n, look, perItem, rep, label)
	ev.found, ev.goal = 0, n
	for _, pos in ipairs(shuffled(SPOTS, n)) do
		pickup(ev, pos, look, function(plr)
			ev.found += 1
			pay(plr, reward(data[plr], perItem, 300), rep, label .. " found!")
			progress(ev, label .. " found: " .. ev.found .. "/" .. ev.goal)
		end)
	end
	progress(ev, label .. " found: 0/" .. n)
end
DEFS.festival = {
	start = function(ev)
		G.megaCustomers = 1.5
		Workspace:SetAttribute("Weather", "confetti")
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local p = V3(math.cos(a) * 30, 0, math.sin(a) * 30)
			P(ev.folder, V3(0.1, 14, 0.1), CF(p + V3(0, 7, 0)), RGB(230, 230, 230))
			ball(ev.folder, V3(3, 3.6, 3), CF(p + V3(0, 15, 0)), Color3.fromHSV(k / 12, 0.7, 1))
		end
		tokenHunt(ev, 10, tokenLook, 10, 4, "🎟️ Festival tokens")
	end,
	finish = function(ev)
		G.megaCustomers = nil
		C.resetLook()
		return "🎉 WHAT A FESTIVAL!", ev.found .. "/" .. ev.goal .. " festival tokens were found."
	end,
}
DEFS.tourists = {
	start = function(ev)
		G.megaCustomers, G.megaSatisfaction = 3, 12
		for _, e in ipairs(playing()) do
			local spec = table.clone(C.CAR.van)
			spec.color = RGB(255, 200, 60)
			spec.L, spec.cab = 22, 17
			local bus = C.buildCar(spec, CF(e.d.plot.at(-30, 1.2, 40)) * CFrame.Angles(0, math.rad(90), 0), "TOURS")
			for _, p in ipairs(bus:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true end
			end
			bus.Parent = ev.folder
		end
		progress(ev, "🧳 Tour buses are unloading at every empire!")
	end,
	finish = function(ev)
		G.megaCustomers, G.megaSatisfaction = nil, nil
		return "🧳 THE TOURISTS WENT HOME", "Hope you sold a lot of souvenirs!"
	end,
}
-- robbery wave: robbers appear at random businesses; anyone can stop them in time
DEFS.robbery = {
	start = function(ev)
		ev.spawnT, ev.stopped, ev.escaped, ev.robbers = 2, 0, 0, {}
		progress(ev, "🦸 Robbers stopped: 0")
	end,
	tick = function(ev, dt)
		ev.spawnT -= dt
		local now = os.clock()
		for i = #ev.robbers, 1, -1 do
			local rb = ev.robbers[i]
			if not rb.handle.alive then
				table.remove(ev.robbers, i)
			elseif now > rb.escapeAt then
				rb.handle.alive = false
				rb.handle.model:Destroy()
				table.remove(ev.robbers, i)
				ev.escaped += 1
				local d = data[rb.owner]
				if d then
					local loss = math.floor(math.min(d.cash * 0.04, F.incomePerSec(d) * 40))
					d.cash -= loss
					notify(rb.owner, "🦹 A robber escaped from your " .. BIZ[rb.key].name .. " with $" .. fmt(loss) .. "!")
					if F.forceProblem then F.forceProblem(rb.owner, d, nil, rb.key, 9) end
				end
			end
		end
		if ev.spawnT > 0 then return end
		ev.spawnT = 7
		local choices = {}
		for _, e in ipairs(playing()) do
			local busy = false
			for _, rb in ipairs(ev.robbers) do if rb.owner == e.plr then busy = true end end
			if not busy then
				for _, b in ipairs(BUSINESSES) do
					if (e.d.levels[b.key] or 0) > 0 then table.insert(choices, {plr = e.plr, d = e.d, key = b.key}) end
				end
			end
		end
		if #choices == 0 then return end
		local c = choices[math.random(#choices)]
		local pos = (F.slotCF(c.d.plot, c.key) * CF(3, 0.3, 9)).Position
		local rb = {owner = c.plr, key = c.key, escapeAt = now + 14}
		rb.handle = target(ev, pos, robberLook, "Stop the robber! 🦸", function(hero)
			ev.stopped += 1
			pay(hero, reward(data[hero], 25, 800), 6, "🦸 You stopped a robber!")
			if hero ~= c.plr then
				F.addRep(c.plr, 2)
				notify(c.plr, "🦸 " .. hero.Name .. " stopped a robber at your " .. BIZ[c.key].name .. "!")
				F.buzz("🦸", hero.Name .. " stopped a robbery at " .. c.plr.Name .. "'s " .. BIZ[c.key].name .. "!", RGB(120, 200, 255))
			end
			progress(ev, "🦸 Robbers stopped: " .. ev.stopped .. "  •  escaped: " .. ev.escaped)
		end)
		table.insert(ev.robbers, rb)
		notify(c.plr, "🚨 A robber is hitting your " .. BIZ[c.key].name .. "! Stop them in 14 seconds!")
	end,
	finish = function(ev) return "🚓 THE CRIME WAVE IS OVER", ev.stopped .. " robbers stopped, " .. ev.escaped .. " got away." end,
}
DEFS.heatwave = {
	start = function(ev)
		G.megaBiz = {lemonade = 3, icecream = 3, factory = 0.8}
		Workspace:SetAttribute("Weather", "heat")
		tokenHunt(ev, 12, icePopLook, 8, 2, "🧊 Ice pops")
	end,
	finish = function(ev)
		G.megaBiz = nil
		C.resetLook()
		return "🔥 THE HEAT BROKE", ev.found .. " ice pops were grabbed."
	end,
}
DEFS.blizzard = {
	start = function(ev)
		G.megaBiz = {coffee = 3, lemonade = 0.3, icecream = 0.3}
		Workspace:SetAttribute("Weather", "snow")
		ev.goal, ev.done = 10, 0
		for _, pos in ipairs(shuffled(SPOTS, 10)) do
			target(ev, pos, snowmanLook, "Smash snowman ☃️", function(plr)
				ev.done += 1
				pay(plr, reward(data[plr], 15, 400), 2, "☃️ Snowman smashed!")
				progress(ev, "☃️ Snowmen smashed: " .. ev.done .. "/" .. ev.goal)
			end)
		end
		progress(ev, "☃️ Snowmen smashed: 0/10")
	end,
	finish = function(ev)
		G.megaBiz = nil
		C.resetLook()
		return "❄️ THE BLIZZARD IS OVER", ev.done .. "/10 snowmen smashed."
	end,
}
-- concert: stand near the Downtown stage to become a fan (+15% income for 3 min, and rep while you stay)
DEFS.concert = {
	start = function(ev)
		G.megaBiz = {pizza = 1.5, arcade = 1.5}
		local s = STAGE_AT
		P(ev.folder, V3(30, 3, 16), CF(s + V3(0, 1.5, -6)), DARK, MAT.DiamondPlate, SOLID)
		P(ev.folder, V3(30, 16, 1), CF(s + V3(0, 8, -14)), RGB(20, 20, 26), MAT.SmoothPlastic, SOLID)
		P(ev.folder, V3(32, 1, 18), CF(s + V3(0, 17, -6)), RGB(40, 40, 50), MAT.Metal)
		for k = 0, 5 do
			local l = ball(ev.folder, V3(1.4, 1.4, 1.4), CF(s + V3(-12.5 + k * 5, 16, 1)), Color3.fromHSV(k / 6, 0.8, 1), MAT.Neon)
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Front
			sl.Range, sl.Angle, sl.Brightness, sl.Color = 60, 50, 5, l.Color
			sl.Parent = l
		end
		for _, sx in ipairs({-17, 17}) do P(ev.folder, V3(5, 10, 4), CF(s + V3(sx, 5, -4)), RGB(25, 25, 30), MAT.SmoothPlastic, SOLID) end
		local sign = P(ev.folder, V3(26, 4, 0.5), CF(s + V3(0, 13, -13.3)), RGB(255, 90, 220), MAT.Neon)
		surfaceText(sign, Enum.NormalId.Front, "🎤 LIVE IN DOWNTOWN", WHITE)
		surfaceText(sign, Enum.NormalId.Back, "🎤 LIVE IN DOWNTOWN", WHITE)
		ev.fans, ev.repT = {}, 0
		progress(ev, "🎤 Fans at the stage: 0  •  Map → Downtown")
	end,
	tick = function(ev, dt)
		ev.repT -= dt
		local count = 0
		for _, e in ipairs(playing()) do
			local r = rootOf(e.plr)
			if r and (V3(r.Position.X, 0, r.Position.Z) - V3(STAGE_AT.X, 0, STAGE_AT.Z)).Magnitude < 45 then
				count += 1
				if not ev.fans[e.plr] then
					ev.fans[e.plr] = true
					e.d.megaBuffUntil, e.d.megaBuffMult = os.clock() + 180, 1.15
					notify(e.plr, "🎸 You're at the concert! +15% income for 3 minutes.")
				end
				if ev.repT <= 0 then F.addRep(e.plr, 2) end
			end
		end
		if ev.repT <= 0 then ev.repT = 10 end
		if count ~= ev.lastCount then
			ev.lastCount = count
			progress(ev, "🎤 Fans at the stage: " .. count .. "  •  Map → Downtown")
		end
	end,
	finish = function(ev)
		G.megaBiz = nil
		local n = 0
		for _ in pairs(ev.fans) do n += 1 end
		return "🎤 WHAT A SHOW!", n .. " player(s) rocked out in Downtown."
	end,
}

-- ===== lifecycle =====
local function eligible()
	local list = {}
	for _, def in ipairs(MEGA_EVENTS) do
		if DEFS[def.key] and (not def.era or G.spire.era >= def.era) then table.insert(list, def) end
	end
	return list
end
function F.startMega(key)
	if M.active then F.endMega() end
	local def
	for _, d in ipairs(eligible()) do
		if d.key == key then def = d end
	end
	if not def then
		local list = eligible()
		def = list[math.random(#list)]
	end
	-- small city events pause while a mega event runs (they would fight over the weather and bonuses)
	if G.event then F.endEvent() end
	G.megaActive = true
	local folder = Instance.new("Folder")
	folder.Name = "MegaEvent"
	folder.Parent = Workspace
	local ev = {def = def, folder = folder, targets = {}, pickups = {}, running = true, startedAt = os.clock(), endsAt = os.clock() + def.dur}
	M.active = ev
	local ok, err = pcall(DEFS[def.key].start, ev)
	if not ok then warn("[CornerEmpire] mega event " .. def.key .. " failed to start: " .. tostring(err)) end
	send({kind = "start", key = def.key, icon = def.icon, title = def.title, sub = def.sub, dur = def.dur, color = def.color, text = ev.progressText})
	announceAll(def.icon .. " " .. def.title .. " " .. def.sub)
	F.buzz(def.icon, "BREAKING: " .. def.title .. " " .. def.sub, def.color)
	for _, e in ipairs(playing()) do e.d.seen.events["mega_" .. def.key] = true end
	return ev
end
function F.endMega()
	local ev = M.active
	if not ev then return end
	ev.running = false
	M.active = nil
	local ok, title, sub = pcall(DEFS[ev.def.key].finish, ev)
	if not ok then
		warn("[CornerEmpire] mega event " .. ev.def.key .. " failed to finish: " .. tostring(title))
		title, sub = ev.def.title, ""
	end
	-- every temporary multiplier this event could have set is cleared here, whatever happened above
	G.megaBiz, G.megaCustomers, G.megaSatisfaction = nil, nil, nil
	G.megaActive = false
	if Workspace:GetAttribute("Weather") ~= "none" and not G.event then C.resetLook() end
	ev.folder:Destroy()
	send({kind = "end", key = ev.def.key, title = title or ev.def.title, sub = sub or "", color = ev.def.color})
	M.nextAt = os.clock() + math.random(MEGA.gapMin, MEGA.gapMax)
	G.nextEvent = math.max(G.nextEvent, os.clock() + 20)
end
-- force a problem at a business (tornado / robbery); optional fixed business key and problem type
function F.forceProblem(plr, d, why, key, typeIndex)
	if d.rebirths >= 50 then return end
	local owned = {}
	for _, b in ipairs(BUSINESSES) do
		if (d.levels[b.key] or 0) > 0 and not d.problems[b.key] and (d.immune[b.key] or 0) < os.clock() then table.insert(owned, b.key) end
	end
	if key then owned = (not d.problems[key]) and {key} or {} end
	if #owned == 0 then return end
	local k = owned[math.random(#owned)]
	local _, per = F.income(d, os.clock())
	local repair = math.max(C.ECONOMY.repairFloor, math.floor((per[k] or 0) * C.ECONOMY.repairSeconds))
	d.problems[k] = {type = typeIndex or math.random(C.PROBLEM_RANDOM), repair = repair, replace = repair * 4, state = "new"}
	F.problemVisual(plr, k, true)
	F.refreshWorkers(plr)
	if why then notify(plr, why .. " Your " .. BIZ[k].name .. " needs a repair.") end
end
C.megaState = function()
	local ev = M.active
	if not ev then return nil end
	return {key = ev.def.key, icon = ev.def.icon, title = ev.def.title, sub = ev.def.sub, left = math.max(0, math.ceil(ev.endsAt - os.clock())), text = ev.progressText, color = ev.def.color}
end

task.spawn(function()
	while true do
		local dt = task.wait(0.25)
		local now = os.clock()
		local ev = M.active
		if ev then
			local ok, err = pcall(function()
				checkPickups(ev)
				local tick = DEFS[ev.def.key].tick
				if tick then tick(ev, dt) end
			end)
			if not ok then warn("[CornerEmpire] mega tick error: " .. tostring(err)) end
			if now >= ev.endsAt then F.endMega() end
		elseif now >= M.nextAt then
			if next(data) ~= nil then
				F.startMega()
			else
				M.nextAt = now + 30
			end
		end
	end
end)

-- =====================================================================
-- CITY ERAS: what the city looks like in each era (cumulative)
-- =====================================================================
local ERA_SPOTS = {
	cranes = {V3(175, 0, 105), V3(-175, 0, -105), V3(285, 0, -105), V3(-285, 0, 105)},
	towers = {V3(310, 0, 70), V3(310, 0, -70), V3(-310, 0, 70), V3(-310, 0, -70), V3(150, 0, -95), V3(-150, 0, 95)},
}
for _, list in pairs(ERA_SPOTS) do
	for _, p in ipairs(list) do C.reserve(p.X - 9, p.Z - 9, p.X + 9, p.Z + 9) end
end
local eraFolder
function F.buildEraDecor(era)
	if eraFolder then eraFolder:Destroy() end
	eraFolder = Instance.new("Folder")
	eraFolder.Name = "EraDecor"
	eraFolder.Parent = C.WORLD
	Workspace:SetAttribute("Era", era)
	Workspace:SetAttribute("EraName", C.eraName(era))
	if era >= 2 then
		-- Growing City: construction cranes and new towers
		for _, p in ipairs(ERA_SPOTS.cranes) do
			P(eraFolder, V3(2, 44, 2), CF(p + V3(0, 22, 0)), RGB(255, 190, 40), MAT.Metal, SOLID)
			P(eraFolder, V3(34, 1.6, 1.6), CF(p + V3(10, 44, 0)), RGB(255, 190, 40), MAT.Metal)
			P(eraFolder, V3(0.3, 16, 0.3), CF(p + V3(24, 36, 0)), DARK, MAT.Metal)
			P(eraFolder, V3(4, 3, 4), CF(p + V3(24, 27, 0)), RGB(120, 120, 130), MAT.Concrete)
		end
		for i, p in ipairs(ERA_SPOTS.towers) do
			C.skyscraper(eraFolder, p.X, p.Z, 14, 14, 36 + (i % 3) * 10, Color3.fromHSV(0.58, 0.35, 0.65 + (i % 2) * 0.1), RGB(235, 235, 240))
		end
	end
	if era >= 3 then
		-- Mega City: a giant skyline on the horizon + rooftop billboards
		for k = 0, 13 do
			local x = -620 + k * 95
			local h = 110 + ((k * 37) % 5) * 30
			C.skyscraper(eraFolder, x, -700 - (k % 2) * 30, 34, 30, h, Color3.fromHSV(0.6, 0.3, 0.45 + (k % 3) * 0.08), RGB(200, 210, 230))
		end
		for _, x in ipairs({-200, 200}) do
			local bb = P(eraFolder, V3(30, 12, 1), CF(x, 30, -14), RGB(20, 20, 30), MAT.SmoothPlastic)
			surfaceText(bb, Enum.NormalId.Back, "🌆 MEGA CITY", RGB(255, 200, 80))
			surfaceText(bb, Enum.NormalId.Front, "🌆 MEGA CITY", RGB(255, 200, 80))
			P(eraFolder, V3(1, 24, 1), CF(x, 12, -14), DARK, MAT.Metal, SOLID)
		end
	end
	if era >= 4 then
		-- Future City: floating holo-rings over the core (flying cars are drawn by clients)
		for k = 1, 4 do
			local ring = cyl(eraFolder, 0.6, 40 + k * 22, CF(0, 90 + k * 14, 0), Color3.fromHSV(0.5 + k * 0.05, 0.8, 1), MAT.Neon, {Transparency = 0.3, CastShadow = false})
			spin(ring, 0.3 * (k % 2 == 0 and 1 or -1))
		end
	end
	if era >= 5 then
		-- Cyber City: neon light beams at the plaza and neon-lined main streets
		for _, p in ipairs({V3(-20, 0, -20), V3(20, 0, -20), V3(-20, 0, 20), V3(20, 0, 20)}) do
			local beam = cyl(eraFolder, 400, 2, CF(p + V3(0, 200, 0)), Color3.fromHSV(0.8, 0.8, 1), MAT.Neon, {Transparency = 0.5, CastShadow = false})
			beam.CastShadow = false
		end
		for _, z in ipairs({-7.5, 7.5}) do P(eraFolder, V3(1280, 0.1, 0.4), CF(0, 0.26, z), RGB(255, 60, 220), MAT.Neon) end
		for _, x in ipairs({-6.5, 6.5}) do P(eraFolder, V3(0.4, 0.1, 470), CF(x, 0.26, 97), RGB(60, 220, 255), MAT.Neon) end
	end
end
F.buildEraDecor(1)
end
