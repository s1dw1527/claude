-- AUDIO: background music playlist + applying settings.
-- ================================================================
-- 🎵 ADD YOUR MUSIC HERE
-- Roblox only plays audio you own or audio that's licensed for everyone.
-- In Studio: View > Toolbox > Audio (or the Creator Store) and search for music
-- published by "Roblox" (free to use). Right-click a track > Copy Asset ID and paste it below, e.g.
--   "rbxassetid://1234567890",
-- ================================================================
local MUSIC_IDS = {
}
return function(C)
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local new = C.new

local music = new("Sound", {Name = "EmpireMusic", Volume = 0, Looped = false}, SoundService)
C.musicAvailable = #MUSIC_IDS > 0
local index = math.random(1, math.max(1, #MUSIC_IDS))
local function nextTrack()
	if #MUSIC_IDS == 0 then return end
	index = index % #MUSIC_IDS + 1
	music.SoundId = MUSIC_IDS[index]
	if C.settings.music then music:Play() end
end
music.Ended:Connect(nextTrack)
if #MUSIC_IDS > 0 then music.SoundId = MUSIC_IDS[index] end

function C.applySettings()
	local s = C.settings
	music.Volume = (s.musicVol or 5) / 10 * 0.5
	if s.music and #MUSIC_IDS > 0 then
		if not music.IsPlaying then music:Play() end
	else
		music:Pause()
	end
	if C.U.applyCrowd then C.U.applyCrowd() end
	if C.U.applyWeather then C.U.applyWeather() end
end
function C.setSetting(k, v)
	C.settings[k] = v
	C.applySettings()
	C.act("settings", {[k] = v})
end
Workspace:GetAttributeChangedSignal("Weather"):Connect(function()
	if C.U.applyWeather then C.U.applyWeather() end
end)
end
