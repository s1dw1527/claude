-- MOUNTAIN LIFE (v11): the Blackrock Syndicate crew inside the hideout — The Boss, Wheels, Hawk, Sparks, Velvet,
-- Glitch, Crates and Static (all fictional). The server lists them on the Mountain folder; this draws them on your
-- screen only while you're near the base (built once when you arrive, removed when you leave), with idle moves and
-- a short line now and then. Purely visual.
return function(C)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local plr = C.plr
local A = C.Actors
if not A then return end
local ML = {active = false, actors = {}}
C.MountainLife = ML
local LOOK = {
	boss = {shirt = RGB(30, 30, 34), jacket = RGB(20, 20, 24), pants = RGB(20, 20, 24), skin = A.SKIN[3], hat = RGB(20, 20, 24), hatKind = "fedora"},
	driver = {shirt = RGB(200, 60, 40), pants = RGB(40, 40, 50), skin = A.SKIN[1], hat = RGB(30, 30, 30), hatKind = "cap"},
	lookout = {shirt = RGB(60, 70, 60), jacket = RGB(70, 80, 60), pants = RGB(50, 50, 40), skin = A.SKIN[4]},
	mechanic = {shirt = RGB(70, 90, 140), pants = RGB(60, 70, 110), skin = A.SKIN[2], hat = RGB(255, 200, 40), hatKind = "cap"},
	fence = {shirt = RGB(120, 40, 80), jacket = RGB(90, 30, 60), pants = RGB(30, 30, 34), skin = A.SKIN[5] or A.SKIN[1]},
	hacker = {shirt = RGB(40, 40, 44), pants = RGB(40, 40, 60), skin = A.SKIN[2], hat = RGB(40, 200, 120), hatKind = "beanie"},
	quartermaster = {shirt = RGB(110, 90, 60), pants = RGB(60, 50, 40), skin = A.SKIN[3]},
	dispatcher = {shirt = RGB(60, 60, 90), pants = RGB(40, 40, 50), skin = A.SKIN[1], hat = RGB(20, 20, 24), hatKind = "beanie"},
}
local folder
local function parse(text)
	local out = {}
	for line in string.gmatch(text, "[^\n]+") do
		local role, name, x, z, move, lines = string.match(line, "^([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);(.*)$")
		if role then
			local said = {}
			for l in string.gmatch(lines, "[^|]+") do table.insert(said, l) end
			table.insert(out, {role = role, name = name, x = tonumber(x), z = tonumber(z), move = move, lines = said})
		end
	end
	return out
end
local function start(mtn)
	folder = A.folder("MountainLife")
	local core = mtn:GetAttribute("Core")
	for i, n in ipairs(parse(mtn:GetAttribute("Crew") or "")) do
		if n.x and n.z then
			local a = A.make(folder, LOOK[n.role] or A.randomLook(i), {tag = n.name, prop = n.role == "boss" and "clipboard" or nil})
			local pos = V3(n.x, 3, n.z)
			a.base = A.faceTowards(pos, typeof(core) == "Vector3" and V3(core.X, 3, core.Z) or pos + V3(0, 0, 1))
			a.move, a.lines, a.next, a.talkAt = n.move, n.lines, 0, os.clock() + 3 + i * 2.5
			table.insert(ML.actors, a)
		end
	end
	ML.active = true
end
local function stop()
	if folder then folder:Destroy() folder = nil end
	ML.actors = {}
	ML.active = false
end
ML.stop = stop
-- near the base? (checked twice a second; the crew only exists on your screen while you're close)
task.spawn(function()
	local mtn
	while true do
		task.wait(0.5)
		if not (mtn and mtn.Parent) then
			local city = Workspace:FindFirstChild("City")
			mtn = city and city:FindFirstChild("Mountain")
		end
		local core = mtn and mtn:GetAttribute("Core")
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local close = root and typeof(core) == "Vector3" and (root.Position - core).Magnitude < 220
		if close and not ML.active then pcall(start, mtn) elseif not close and ML.active then stop() end
	end
end)
RunService.Heartbeat:Connect(function(dt)
	if not ML.active then return end
	local now = os.clock()
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	for _, a in ipairs(ML.actors) do
		if now >= a.next then
			A.play(a, a.move, now)
			a.next = now + 2.5 + math.random() * 2
		end
		if now >= a.talkAt and #a.lines > 0 and root and (root.Position - a.base.Position).Magnitude < 40 then
			A.bubble(a.head.Position + V3(0, 2.6, 0), "", a.lines[math.random(#a.lines)], 3, folder)
			a.talkAt = now + 9 + math.random() * 8
		end
		A.step(a, dt, now)
	end
end)
end
