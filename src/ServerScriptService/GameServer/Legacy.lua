-- LEGACY: hidden places to explore, relics, and (below) the Legacy Museum and Mystery Lots.
return function(C)
local Workspace = game:GetService("Workspace")
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, data, R = C.F, C.data, C.R
local P, ball, cyl, ghost, billboard, surfaceText, smoke, sparkle, burst, spin =
	C.P, C.ball, C.cyl, C.ghost, C.billboard, C.surfaceText, C.smoke, C.sparkle, C.burst, C.spin
local fmt, notify = C.fmt, C.notify
local SOLID = {CanCollide = true}
local WHITE, DARK = RGB(250, 250, 250), RGB(30, 30, 36)

local FOLDER = Instance.new("Folder")
FOLDER.Name = "Secrets"
FOLDER.Parent = C.WORLD

-- ===== HIDDEN SPOTS =====
-- each spot gets a small, easy-to-miss prop; walking close to it "finds" it (once per save)
for _, s in ipairs(C.SECRET_SPOTS) do
	local p = s.pos
	C.reserve(p.X - s.radius, p.Z - s.radius, p.X + s.radius, p.Z + s.radius)
	if s.key == "launchpad" then
		P(FOLDER, V3(26, 1, 26), CF(p + V3(0, 0.5, 0)), RGB(120, 120, 125), MAT.Concrete, SOLID)
		for _, sx in ipairs({-9, 9}) do
			for _, sz in ipairs({-9, 9}) do P(FOLDER, V3(0.8, 0.12, 0.8), CF(p + V3(sx, 1.05, sz)), RGB(255, 200, 40), MAT.Neon) end
		end
		P(FOLDER, V3(3, 30, 3), CF(p + V3(-8, 15.5, 0)), RGB(170, 90, 60), MAT.CorrodedMetal, SOLID)
		for y = 4, 28, 6 do P(FOLDER, V3(7, 0.4, 0.4), CF(p + V3(-5, y, 0)), RGB(170, 90, 60), MAT.CorrodedMetal) end
		cyl(FOLDER, 16, 4, CF(p + V3(0, 9, 0)), RGB(225, 225, 230), MAT.Metal)
		ball(FOLDER, V3(4, 6, 4), CF(p + V3(0, 18, 0)), RGB(220, 60, 50), MAT.Metal)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			P(FOLDER, V3(0.4, 4, 2.4), CF(p + V3(math.cos(a) * 2.4, 2.5, math.sin(a) * 2.4)) * CFrame.Angles(0, -a, 0), RGB(220, 60, 50), MAT.Metal)
		end
		local hatch = cyl(FOLDER, 0.3, 5, CF(p + V3(6, 1.15, 6)), RGB(90, 255, 160), MAT.Neon)
		billboard(hatch, UDim2.fromOffset(60, 40), V3(0, 3, 0), {{text = "???"}}, 45)
	else
		local relic
		if s.key == "goldenlemon" then
			relic = ball(FOLDER, V3(1.6, 1.6, 2), CF(p + V3(0, 0.8, 0)), RGB(255, 210, 50), MAT.Foil)
		elseif s.key == "diamondbean" then
			relic = ball(FOLDER, V3(1, 1.4, 0.8), CF(p + V3(0, 0.7, 0)), RGB(180, 240, 255), MAT.Glass, {Reflectance = 0.5, Transparency = 0.2})
		else
			relic = P(FOLDER, V3(1.6, 0.25, 1.2), CF(p + V3(0, 0.3, 0)) * CFrame.Angles(0, 0.4, 0), RGB(235, 215, 170), MAT.Fabric)
		end
		sparkle(relic, RGB(255, 235, 150), 4)
	end
end
local function findSpots(plr, d, root)
	d.found = d.found or {}
	for _, s in ipairs(C.SECRET_SPOTS) do
		if not d.found[s.key] then
			local dx, dz = root.Position.X - s.pos.X, root.Position.Z - s.pos.Z
			if dx * dx + dz * dz < s.radius * s.radius and math.abs(root.Position.Y - s.pos.Y) < 16 then
				d.found[s.key] = true
				d.cash += s.cash
				d.earned += s.cash
				F.addRep(plr, s.rep)
				R.Splash:FireClient(plr, s.icon .. " SECRET FOUND: " .. string.upper(s.name), s.text .. "  (+$" .. fmt(s.cash) .. ")", RGB(255, 225, 120))
				burst(s.pos + V3(0, 4, 0), RGB(255, 225, 120), 120)
				if s.relic and F.achieve then F.achieve(plr, "relic") end
				F.checkCombos(plr, d)
				if F.refreshMuseum then F.refreshMuseum(plr) end
			end
		end
	end
end

-- one slow loop for exploration checks (4 players x a handful of spots, once a second)
task.spawn(function()
	while true do
		task.wait(1)
		for plr, d in pairs(data) do
			local ch = plr.Character
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			if root then
				local ok, err = pcall(findSpots, plr, d, root)
				if not ok then warn("[CornerEmpire] exploration check failed: " .. tostring(err)) end
			end
		end
	end
end)
end
