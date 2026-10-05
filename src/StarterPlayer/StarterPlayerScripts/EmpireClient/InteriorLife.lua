-- INTERIOR LIFE: staff at work and customers living their lives inside the business you're standing in.
--
-- Staff (by business level): a cashier at the register, a cook at the prep area / ovens, a cleaner from level 5,
-- a manager doing rounds (if you hired one, or from level 7). Customers come in, look around, order, sit,
-- eat or check their phone, react to the place (good or bad), and leave. Now and then one takes a selfie,
-- complains dramatically, compliments the interior, brings a friend or says something you'll want to clip.
--
-- All of it is client-side visuals (it never changes anything on the server), only runs while YOU are inside a
-- room, uses small state machines ticking 10 times a second, and is capped (5 staff, 8 customers).
return function(C)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RGB, V3, CF = Color3.fromRGB, Vector3.new, CFrame.new
local plr = C.plr
local A = C.Actors

local IL = {stats = {served = 0, spawned = 0, behaviors = {}, staff = 0, customers = 0, rooms = 0}}
C.InteriorLife = IL
local MAX_CUSTOMERS, MAX_STAFF = 8, 5

-- uniforms and the move each business's staff do at work
local UNI = {
	lemonade = {shirt = RGB(255, 214, 60), pants = RGB(60, 70, 120), work = "stir"},
	icecream = {shirt = RGB(255, 170, 210), pants = RGB(240, 240, 250), work = "stir"},
	bakery = {shirt = RGB(250, 250, 250), pants = RGB(60, 60, 70), work = "cook"},
	coffee = {shirt = RGB(55, 62, 58), pants = RGB(35, 35, 40), work = "cook"},
	pizza = {shirt = RGB(230, 70, 50), pants = RGB(250, 250, 250), work = "cook"},
	arcade = {shirt = RGB(150, 80, 255), pants = RGB(30, 30, 40), work = "wave"},
	tech = {shirt = RGB(40, 44, 58), pants = RGB(60, 70, 120), work = "type"},
	factory = {shirt = RGB(90, 94, 102), pants = RGB(50, 60, 90), work = "lift"},
}
local NAMES = {"Sam", "Riley", "Jordan", "Alex", "Casey", "Morgan", "Taylor", "Jamie", "Quinn", "Avery", "Rowan", "Drew"}
local GOOD = {"Mmm!", "10/10 honestly.", "Okay this slaps.", "Coming back tomorrow.", "Worth it.", "Chef's kiss."}
local DECOR_GOOD = {"Okay... this place actually eats.", "Love the decor!", "The vibes in here!", "Who designed this?! 😍"}
local BAD = {"Took forever...", "Hmm. It's fine I guess.", "Needs... something.", "The line was long."}
local FUNNY = {"This {thing} changed my life.", "I waited 14 minutes. I have aged.", "My mom said we're leaving. I disagree.", "The bathroom deserves its own business.",
	"Too much {thing}. Perfect amount, actually.", "I'm telling the group chat about this."}
local THINGS = {lemonade = "lemonade", icecream = "ice cream", bakery = "croissant", coffee = "coffee", pizza = "pizza", arcade = "arcade", tech = "phone", factory = "factory tour"}
local ORDER_PROP = {lemonade = "cup", icecream = "cup", bakery = "tray", coffee = "cup", pizza = "pizzabox", arcade = nil, tech = "phone", factory = nil}

local room = nil   -- the active room: {model, key, wps, staff = {}, customers = {}, seatsUsed = {}, ...}
local folder = nil

local function wpList(model)
	local out = {}
	for _, p in ipairs(model:GetChildren()) do
		if p.Name == "WP" and p:IsA("BasePart") then
			local k = p:GetAttribute("Kind")
			if k then
				out[k] = out[k] or {}
				table.insert(out[k], p.Position - V3(0, 0.5, 0))
			end
		end
	end
	return out
end
local function anyOf(r, ...)
	for _, k in ipairs({...}) do
		local l = r.wps[k]
		if l and #l > 0 then return l[math.random(#l)] end
	end
	return nil
end
local function bubble(a, text, dur)
	if a and not a.dead and text then A.bubble(a.head.Position + V3(0, 2.6, 0), "", text, dur or 2.6, folder) end
end
local function note(kind) IL.stats.behaviors[kind] = (IL.stats.behaviors[kind] or 0) + 1 end
local function fillThing(r, text) return (string.gsub(text, "{thing}", THINGS[r.key] or "food")) end

-- ===== staff =====
local function addStaff(r, role, name)
	if #r.staff >= MAX_STAFF then return end
	local u = UNI[r.key] or UNI.lemonade
	local look = {shirt = role == "manager" and RGB(30, 36, 62) or u.shirt, pants = role == "manager" and RGB(30, 36, 62) or u.pants, skin = A.SKIN[(#r.staff % #A.SKIN) + 1],
		apron = (role == "cook" or role == "cashier") and Color3.new(1, 1, 1) or nil, tie = role == "manager" and RGB(200, 40, 50) or nil,
		hat = role == "cook" and Color3.new(1, 1, 1) or (r.key == "factory" and RGB(255, 205, 40) or nil), hatKind = role == "cook" and "beanie" or "cap"}
	local start = anyOf(r, role == "cook" and "prep" or "register", "register", "wander") or r.origin
	local a = A.make(folder, look, {tag = name and (name .. " • " .. role) or nil, prop = role == "manager" and "clipboard" or (role == "cleaner" and "mop" or nil)})
	a.base = A.faceTowards(start, r.origin)
	a.role, a.state, a.wait = role, "go", 0
	table.insert(r.staff, a)
	IL.stats.staff = #r.staff
end
local function staffThink(r, a, now)
	if now < a.wait or a.goal then return end
	local work = (UNI[r.key] or UNI.lemonade).work
	if a.role == "cashier" then
		-- at the register; serves whoever is waiting to order
		local spot = anyOf(r, "register") or r.origin
		if (a.base.Position - spot).Magnitude > 2 then A.walkTo(a, spot, 6) return end
		a.base = A.faceTowards(a.base.Position, anyOf(r, "order") or r.origin)
		for _, c in ipairs(r.customers) do
			if c.state == "ordering" and not c.servedBy then
				c.servedBy = a
				A.play(a, "show", now)
				bubble(a, ({"What can I get you?", "Next!", "Welcome in!", "Coming right up!"})[math.random(4)], 2)
				a.wait = now + 1.6
				return
			end
		end
		A.play(a, math.random() < 0.3 and "look" or "idle", now)
		a.wait = now + 1
	elseif a.role == "cook" then
		if a.state == "go" then
			local spot = anyOf(r, "oven", "prep", "machine", "station") or r.origin
			A.walkTo(a, spot, 6)
			a.state = "cooking"
		elseif a.state == "cooking" then
			A.play(a, work, now)
			a.wait = now + 3 + math.random() * 3
			a.state = "deliver"
		elseif a.state == "deliver" then
			A.setProp(a, r.key == "factory" and "box" or "tray")
			A.walkTo(a, anyOf(r, "register", "display", "loading") or r.origin, 6)
			a.state = "drop"
		else
			A.setProp(a, nil)
			A.play(a, "idle", now)
			a.wait = now + 0.8
			a.state = "go"
		end
	elseif a.role == "cleaner" then
		if a.state == "go" then
			A.walkTo(a, anyOf(r, "seat", "trash", "wander") or r.origin, 4.5)
			a.state = "clean"
		else
			A.play(a, math.random() < 0.5 and "wipe" or "sweep", now)
			a.wait = now + 2 + math.random() * 2
			a.state = "go"
			if math.random() < 0.1 then bubble(a, ({"Who spilled this?!", "Sparkling. ✨", "I see you, crumbs."})[math.random(3)]) end
		end
	elseif a.role == "manager" then
		if a.state == "go" then
			A.walkTo(a, anyOf(r, "office", "prep", "register", "wander") or r.origin, 5)
			a.state = "check"
		else
			A.play(a, "clipboard", now)
			a.wait = now + 2.5 + math.random() * 2
			a.state = "go"
			if math.random() < 0.15 then bubble(a, ({"Numbers look good.", "Who moved my stapler?", "Great work, team!", "Checking the register..."})[math.random(4)]) end
		end
	elseif a.role == "worker" then
		-- factory floor: a station, a machine, the loading dock
		if a.state == "go" then
			A.walkTo(a, anyOf(r, "station", "machine", "loading", "storage") or r.origin, 5)
			a.state = "work"
		else
			A.play(a, math.random() < 0.5 and "lift" or "type", now)
			a.wait = now + 3 + math.random() * 3
			a.state = "go"
		end
	end
end

-- ===== customers =====
local function freeSeat(r)
	local seats = r.wps.seat or {}
	local free = {}
	for i, p in ipairs(seats) do if not r.seatsUsed[i] then table.insert(free, i) end end
	if #free == 0 then return nil end
	local i = free[math.random(#free)]
	return i, seats[i]
end
local function addCustomer(r, now, friendOf)
	if #r.customers >= MAX_CUSTOMERS then return nil end
	local door = anyOf(r, "door") or r.origin
	local a = A.make(folder, A.randomLook(math.random(1, 1e6)))
	a.base = A.faceTowards(door + (friendOf and V3(1.5, 0, 0.5) or V3()), r.origin)
	a.state, a.wait, a.friend = "enter", now + (friendOf and 0.3 or 0), friendOf
	table.insert(r.customers, a)
	IL.stats.spawned += 1
	IL.stats.customers = #r.customers
	-- rare behaviors are decided when they walk in
	local roll = math.random()
	if roll < 0.06 then a.rare = "selfie"
	elseif roll < 0.10 then a.rare = "complain"
	elseif roll < 0.15 then a.rare = "compliment"
	elseif roll < 0.19 and not friendOf then a.rare = "friend"
	elseif roll < 0.25 then a.rare = "review"
	elseif roll < 0.28 then a.rare = "post" end
	if a.rare == "friend" then
		note("friend")
		local f = addCustomer(r, now, a)
		if f then bubble(a, "I brought a friend!") end
	end
	return a
end
local function leave(r, a, now)
	if a.seat then r.seatsUsed[a.seat] = nil a.seat = nil end
	A.setProp(a, nil)
	A.walkTo(a, anyOf(r, "door") or r.origin, 6)
	a.state = "leaving"
end
local function customerThink(r, a, now)
	if now < a.wait then return end
	if a.goal then return end
	local sat = r.model:GetAttribute("Sat") or 70
	local score = r.model:GetAttribute("Score") or 0
	if a.state == "enter" then
		A.walkTo(a, anyOf(r, "wander", "display", "machine") or r.origin, 5)
		a.state = "browse"
	elseif a.state == "browse" then
		A.play(a, "look", now)
		a.wait = now + 1.2 + math.random() * 1.6
		a.state = "toOrder"
	elseif a.state == "toOrder" then
		-- queue up: a small offset per person already waiting
		local spot = anyOf(r, "order") or r.origin
		local waiting = 0
		for _, c in ipairs(r.customers) do if c ~= a and (c.state == "ordering" or c.state == "queue") then waiting += 1 end end
		A.walkTo(a, spot + V3(0, 0, waiting * 2.2), 5)
		a.state = "ordering"
		a.orderedAt = now
	elseif a.state == "ordering" then
		a.base = A.faceTowards(a.base.Position, anyOf(r, "register") or r.origin)
		if a.servedBy or now - (a.orderedAt or now) > 6 then
			IL.stats.served += 1
			note("ordered")
			A.setProp(a, ORDER_PROP[r.key])
			a.state = "got"
			a.wait = now + 1.2
		else
			A.play(a, "idle", now)
			a.wait = now + 0.5
		end
	elseif a.state == "got" then
		if a.rare == "selfie" then
			A.play(a, "selfie", now)
			A.flashAt(folder, a.head.Position + a.base.LookVector * -1.5)
			bubble(a, "For the CityBuzz 📸")
			note("selfie")
			a.rare = nil
			a.wait = now + 2.2
			return
		elseif a.rare == "complain" then
			A.play(a, "dramatic", now)
			bubble(a, fillThing(r, ({"I WAITED 14 MINUTES. I HAVE AGED.", "THIS IS NOT THE {thing} I ORDERED.", "Is this... the small? THE SMALL?!"})[math.random(3)]), 3)
			note("complain")
			a.rare = nil
			a.wait = now + 3
			return
		elseif a.rare == "compliment" or (score >= 61 and math.random() < 0.25) then
			A.play(a, "celebrate", now)
			bubble(a, DECOR_GOOD[math.random(#DECOR_GOOD)])
			note("compliment")
			a.rare = nil
			a.wait = now + 2
		end
		local i, pos = freeSeat(r)
		if i and math.random() < 0.7 then
			r.seatsUsed[i] = true
			a.seat = i
			A.walkTo(a, pos, 5)
			a.state = "sit"
		else
			leave(r, a, now)
		end
	elseif a.state == "sit" then
		local move = r.key == "arcade" and "type" or (math.random() < 0.3 and "sitphone" or (ORDER_PROP[r.key] and "eat" or "sit"))
		A.play(a, move, now)
		note(move)
		a.wait = now + 5 + math.random() * 5
		a.state = "react"
	elseif a.state == "react" then
		local line
		if a.rare == "review" then
			line = fillThing(r, FUNNY[math.random(#FUNNY)])
			note("review")
		elseif a.rare == "post" then
			line = "Posting this 📱 #" .. string.gsub(THINGS[r.key] or "food", " ", "")
			A.play(a, "phone", now)
			note("post")
		elseif sat >= 65 then
			line = math.random() < 0.5 and GOOD[math.random(#GOOD)] or nil
		elseif sat < 40 then
			line = BAD[math.random(#BAD)]
			A.play(a, "shrug", now)
		end
		if line then bubble(a, line, 3) end
		a.wait = now + 1.5
		a.state = "go"
	elseif a.state == "go" then
		leave(r, a, now)
	elseif a.state == "leaving" then
		a.done = true
	end
end

-- ===== the room lifecycle =====
local function stop()
	if folder then folder:Destroy() folder = nil end
	room = nil
	IL.stats.staff, IL.stats.customers = 0, 0
end
IL.stop = stop
local function start(model)
	stop()
	folder = A.folder("InteriorLife")
	local key = model:GetAttribute("Key")
	local origin = model:GetAttribute("Origin")
	if typeof(origin) ~= "Vector3" then origin = model:GetPivot().Position end
	room = {model = model, key = key, origin = origin, wps = wpList(model), staff = {}, customers = {}, seatsUsed = {}, nextCustomer = os.clock() + 1.5}
	IL.stats.rooms += 1
	if key == "home" or not UNI[key] then return end
	local lvl = model:GetAttribute("Level") or 1
	local staffName = model:GetAttribute("Staff")
	local mgr = model:GetAttribute("Manager")
	local seed = tonumber(model:GetAttribute("OwnerId")) or 1
	local function nm(i) return NAMES[(seed + i * 7) % #NAMES + 1] end
	if key == "factory" then
		addStaff(room, "worker", staffName ~= "" and staffName or nil)
		addStaff(room, "worker", nil)
		if lvl >= 3 then addStaff(room, "cook", nil) end   -- the forklift... er, the runner
	else
		addStaff(room, "cashier", staffName ~= "" and staffName or nm(1))
		if lvl >= 3 then addStaff(room, "cook", nm(2)) end
		if lvl >= 5 then addStaff(room, "cleaner", nm(3)) end
	end
	if (mgr and mgr ~= "") or lvl >= 7 then addStaff(room, "manager", (mgr and mgr ~= "") and mgr or nm(4)) end
end
local function findRoom()
	local key = plr:GetAttribute("Interior")
	local owner = plr:GetAttribute("InteriorOwner")
	if not key then return nil end
	local folderI = Workspace:FindFirstChild("Interiors")
	if not folderI then return nil end
	for _, m in ipairs(folderI:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("Key") == key and m:GetAttribute("OwnerId") == owner then return m end
	end
	return nil
end
local function check()
	local m = findRoom()
	if m and (not room or room.model ~= m) then start(m)
	elseif not m and room then stop() end
end
plr:GetAttributeChangedSignal("Interior"):Connect(function() task.delay(0.3, check) end)
task.spawn(function()
	while true do
		task.wait(1.5)
		if plr:GetAttribute("Interior") or room then pcall(check) end
	end
end)
IL.check = check

-- think 10x a second, pose every frame
local acc, last = 0, os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.min(0.1, now - last)
	last = now
	if not room then return end
	if not room.model.Parent then
		-- the room was rebuilt (someone decorated): pick up the new one
		stop()
		task.delay(0.5, check)
		return
	end
	acc += dt
	if acc >= 0.1 then
		acc = 0
		local ok, err = pcall(function()
			local lvl = room.model:GetAttribute("Level") or 1
			local cap = math.clamp(2 + lvl, 3, MAX_CUSTOMERS)
			if room.key ~= "home" and UNI[room.key] and now >= room.nextCustomer and #room.customers < cap then
				room.nextCustomer = now + 4 + math.random() * 3
				addCustomer(room, now)
			end
			for _, a in ipairs(room.staff) do staffThink(room, a, now) end
			for i = #room.customers, 1, -1 do
				local a = room.customers[i]
				customerThink(room, a, now)
				if a.done then
					A.destroy(a)
					table.remove(room.customers, i)
				end
			end
			IL.stats.customers = #room.customers
		end)
		if not ok then warn("[CornerEmpire] interior life: " .. tostring(err)) stop() return end
	end
	for _, a in ipairs(room.staff) do A.step(a, dt, now) end
	for _, a in ipairs(room.customers) do A.step(a, dt, now) end
end)
-- the factory floor moves: goods slide along the belts and the pistons pump (local only, purely visual)
task.spawn(function()
	while true do
		task.wait(0.05)
		if room and room.key == "factory" and room.model.Parent then
			local t = os.clock()
			for _, p in ipairs(room.model:GetChildren()) do
				if p.Name == "Goods" then
					local base = p:GetAttribute("StartX")
					if not base then
						base = p.Position.X
						p:SetAttribute("StartX", base)
					end
					p.CFrame = p.CFrame + V3((base + (t * 3) % 6) - p.Position.X, 0, 0)
				elseif p.Name == "Piston" then
					local y0 = p:GetAttribute("StartY")
					if not y0 then
						y0 = p.Position.Y
						p:SetAttribute("StartY", y0)
					end
					p.CFrame = p.CFrame + V3(0, y0 + math.abs(math.sin(t * 3)) * 1.2 - p.Position.Y, 0)
				end
			end
		end
	end
end)
end
