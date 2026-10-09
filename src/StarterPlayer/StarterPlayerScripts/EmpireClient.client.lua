--// CORNER EMPIRE v11.1 — CLIENT. All the code lives in the ModuleScripts inside this LocalScript.
local modules = {"UI", "Layout", "Audio", "AnimationConfig", "Actors", "HUD", "WorldFX", "Workers", "Menus", "BusinessUI", "HQUI", "EmpireUI", "ComputerUI", "GarageUI", "ArcadeUI", "AdminPanel", "GuideUI", "HeistUI", "Phone", "Driving", "MiniGames", "PhotoMode", "Story", "Cinematics",
	"MapApp", "InteriorUI", "InteriorLife", "BuilderUI", "MountainLife", "CityLife", "ViralApp", "MainMenu"}
local C = {}
for _, name in ipairs(modules) do
	local ok, err = pcall(function() require(script:WaitForChild(name))(C) end)
	if not ok then warn("[CornerEmpire] client module " .. name .. " failed: " .. tostring(err)) end
end
-- the server leaves out big sections that didn't change; keep our last copy of those (same list as HEAVY in GameServer > Players)
local HEAVY = {"archive", "homeInfo", "props", "districts", "market", "staff", "reviews", "tours", "shareable", "standings", "passes", "cars", "showcase", "biz", "warLeaders",
	"rebirth", "unlocks", "fees", "spire", "map", "viral", "estate"}
local asked = 0
C.R.State.OnClientEvent:Connect(function(s)
	local prev = C.S
	local missing = false
	for _, k in ipairs(HEAVY) do
		if s[k] == nil then
			if prev and prev[k] ~= nil then s[k] = prev[k] else missing = true end
		end
	end
	if missing and os.clock() - asked > 3 then
		asked = os.clock()
		C.R.Menu:FireServer("resync")
	end
	if missing then return end   -- wait for the full packet the server sends after a resync
	C.S = s
	for _, fn in ipairs(C.stateHooks) do
		local ok, err = pcall(fn, s)
		if not ok then warn("[CornerEmpire] HUD update error: " .. tostring(err)) end
	end
end)
