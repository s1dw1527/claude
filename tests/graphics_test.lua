-- v15: the graphics pass. A real sky (sun, moon, stars), a grade that follows the time of day (warm sunrise and
-- sunset, blue night with a bloom that makes neon glow) without touching the weather grade, softer shadows,
-- street trees and bins on the sidewalks (never in a lane or on a path), and chasing lights that only animate near you.
-- Run with: python3 tests/run.py tests/graphics_test.lua
H.main(function()
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	T.newGame(a, 1, 1)
	H.task.wait(1)
	local Lighting = H.service("Lighting")

	H.section("Sky and light")
	local sky = Lighting:FindFirstChildOfClass("Sky")
	H.check(sky and sky.StarCount >= 2000 and sky.CelestialBodiesShown, "a sky with sun, moon and " .. (sky and sky.StarCount or 0) .. " stars (no image assets)")
	local tod, nb = Lighting:FindFirstChild("TimeOfDayGrade"), Lighting:FindFirstChild("NightBloom")
	H.check(tod and tod:IsA("ColorCorrectionEffect") and nb and nb:IsA("BloomEffect"), "a time-of-day grade and a night bloom, separate from the weather grade")
	local function lum(c) return c.R * 0.3 + c.G * 0.59 + c.B * 0.11 end
	local noon = {C.timeOfDayLook(13)}
	local night = {C.timeOfDayLook(23)}
	local dusk = {C.timeOfDayLook(18)}
	H.check(noon[3] == 0 and night[3] > 0.5, string.format("neon glows at night (bloom %.2f) and not at noon (%.2f)", night[3], noon[3]))
	H.check(night[1].B > night[1].R and dusk[1].R > dusk[1].B, "night is blue, sunset is warm")
	H.check(lum(night[4]) < lum(noon[4]), "the outdoor light dims at night")
	local weather = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local wTint = weather and weather.TintColor
	Lighting.ClockTime = 22.5
	H.task.wait(1)
	H.check(nb.Intensity > 0.4 and tod.TintColor.B > tod.TintColor.R, "the day/night loop applies it (22:30: blue, glowing)")
	Lighting.ClockTime = 12
	H.task.wait(1)
	H.check(nb.Intensity < 0.05, "...and turns it off by day")
	H.check(weather == nil or weather == tod or weather.TintColor == wTint, "the weather grade is left alone")

	H.section("Streets")
	local sp = C.STREET_PROPS
	H.check(sp and sp.trees >= 40 and sp.bins >= 40, string.format("%d street trees in planters, %d bins along the sidewalks", sp and sp.trees or 0, sp and sp.bins or 0))
	local trees = H.workspace.City:FindFirstChild("StreetTrees")
	local inFunPark = 0
	for _, p in ipairs(trees and trees:GetChildren() or {}) do
		if p.Position.X < -345 and math.abs(p.Position.Z) < 120 then inFunPark += 1 end
	end
	H.check(inFunPark == 0, "none in the Fun Park (Main St runs through it)")
	local solid = 0
	for _, p in ipairs(trees and trees:GetChildren() or {}) do
		if p.CanCollide and p.Size.X > 2 then solid += 1 end
	end
	H.check(solid == 0, "planters don't block a car cutting across the sidewalk")

	H.section("Chasing lights only near you")
	local cam = H.workspace.CurrentCamera
	local CS = H.service("CollectionService")
	local near, far
	for _, m in ipairs(CS:GetTagged("ChaseLights")) do
		local b = m:FindFirstChildWhichIsA("BasePart")
		if b and b.Position.X < -600 and b.Position.X > -700 and not far then far = b end
	end
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 30, 300), Vector3.new(0, 0, 0))
	H.task.wait(0.5)
	local c1 = far and far.Color
	H.task.wait(1)
	H.check(far and far.Color == c1, "a string of lights 700 studs away isn't animated")
	cam.CFrame = CFrame.lookAt(far.Position + Vector3.new(0, 20, 40), far.Position)
	H.task.wait(0.4)
	local seen = {}
	for _ = 1, 6 do
		seen[tostring(far.Color)] = true
		H.task.wait(0.2)
	end
	local n = 0
	for _ in pairs(seen) do n += 1 end
	H.check(n >= 2, "...and is when you're there")
	local _ = near

	T.assertClean("graphics")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
