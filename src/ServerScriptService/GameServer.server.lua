--// CORNER EMPIRE v10 — SERVER. All the code lives in the ModuleScripts inside this Script.
--// Edit "Config" to change prices, names, game pass IDs, cars, neighborhoods and more.
local modules = {"Config", "DataMigration", "StoryData", "Util", "World", "Buildings", "Housing", "Rentals", "RealEstate", "Brands", "Cars", "Garage", "Race", "Activities", "Social", "Reviews", "Systems", "Mega", "Legacy", "Weekly", "Story", "Messages", "MapData", "Interiors", "HQ", "Computer", "HomeBuilder", "Arcade", "Admin", "Guide", "Mountain", "Heists", "Police", "Cinematics", "ViralMoments", "Influencers", "CityEvents", "Empire", "EmpirePlaza", "Explore", "Updates", "Players"}
local C = {F = {}, data = {}, plots = {}}
for _, name in ipairs(modules) do
	local ok, err = pcall(function() require(script:WaitForChild(name))(C) end)
	if not ok then warn("[CornerEmpire] server module " .. name .. " failed: " .. tostring(err)) end
end
print("[CornerEmpire] v10 server ready")
