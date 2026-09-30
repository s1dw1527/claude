--// CORNER EMPIRE v5 — CLIENT. All the code lives in the ModuleScripts inside this LocalScript.
local modules = {"UI", "Audio", "HUD", "WorldFX", "Menus", "Phone", "Driving", "MiniGames", "MainMenu"}
local C = {}
for _, name in ipairs(modules) do
	local ok, err = pcall(function() require(script:WaitForChild(name))(C) end)
	if not ok then warn("[CornerEmpire] client module " .. name .. " failed: " .. tostring(err)) end
end
C.R.State.OnClientEvent:Connect(function(s)
	C.S = s
	for _, fn in ipairs(C.stateHooks) do
		local ok, err = pcall(fn, s)
		if not ok then warn("[CornerEmpire] HUD update error: " .. tostring(err)) end
	end
end)
