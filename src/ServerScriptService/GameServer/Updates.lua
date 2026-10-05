-- UPDATES: tells players on an older server that a newer version of the game has been published.
-- Every server records its place version in a tiny DataStore key and announces it over MessagingService.
-- When an old server hears about a newer one, it saves everyone and shows a notice; the restart itself is done
-- by Roblox (Creator Dashboard / Studio "Restart servers for updates"), and the game saves again on shutdown.
return function(C)
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local F, data, R = C.F, C.data, C.R
local RGB = Color3.fromRGB
local TOPIC = "CornerEmpireUpdate"
local myPlace = tonumber(game.PlaceVersion) or 0
local noticed = false
C.updateState = {pending = false}

local function newerAvailable(placeVersion, version)
	if noticed or not placeVersion or placeVersion <= myPlace then return end
	noticed = true
	C.updateState.pending = true
	C.updateState.version = version
	-- save everyone now, so nothing is lost whenever the restart happens
	for plr in pairs(data) do pcall(F.save, plr) end
	R.Splash:FireAllClients("🆕 NEW UPDATE READY", "Version " .. tostring(version or "") .. " is out! This server will restart soon. Your progress is saved.", RGB(120, 220, 255))
	C.announceAll("🆕 A new version of Corner Empire is out. This server will restart soon; your progress is being saved.")
	task.spawn(function()
		while true do
			task.wait(180)
			C.announceAll("🆕 Update waiting: this server will restart soon. Your progress is saved automatically.")
		end
	end)
end

-- Studio playtests have no real place version; skip all of this there
if RunService:IsStudio() then return end
task.spawn(function()
	local store
	pcall(function() store = DataStoreService:GetDataStore(C.storeName("CE_Version")) end)
	local function check()
		if not store then return end
		pcall(function()
			store:UpdateAsync("latest", function(old)
				local known = type(old) == "table" and tonumber(old.placeVersion) or 0
				if known > myPlace then
					newerAvailable(known, old.version)
					return nil
				end
				if myPlace > known then return {placeVersion = myPlace, version = C.VERSION.VERSION} end
				return nil
			end)
		end)
	end
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(msg)
			local m = msg and msg.Data
			if type(m) == "table" then newerAvailable(tonumber(m.placeVersion), m.version) end
		end)
	end)
	check()
	pcall(function() MessagingService:PublishAsync(TOPIC, {placeVersion = myPlace, version = C.VERSION.VERSION}) end)
	while true do
		task.wait(300)
		check()
	end
end)
end
