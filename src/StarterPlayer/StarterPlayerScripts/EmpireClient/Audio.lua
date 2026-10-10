-- AUDIO (v14): music that follows what you're doing, district and interior ambience, and musical feedback.
--
-- ================================================================
-- 🎵 ADD YOUR SOUNDS HERE (all optional)
-- Roblox only plays audio you own or audio that's licensed for everyone. In Studio: Toolbox → Audio (or the Creator
-- Store), search for tracks/effects published by "Roblox" (free to use), right-click → Copy Asset ID, and paste it
-- as "rbxassetid://123456789" into the list for the right mood or place below.
--   * A mood/place with no IDs uses the built-in generated music (soft music-box chords made from a built-in tone)
--     for music, and stays quiet for ambience.
--   * An ID that fails to load is switched off automatically (with one warning in Output), never an error.
-- ================================================================
local AUDIO = {
	music = {
		city = {},        -- daytime in the city (cheerful)
		night = {},       -- after dark (mellow)
		business = {},    -- inside a business (café / restaurant / shop music)
		home = {},        -- at home (calm lounge)
		chase = {},       -- the police are after you (tense)
	},
	ambience = {
		city = "",        -- traffic + crowd murmur (downtown, midtown, the center)
		beach = "",       -- waves, gulls
		suburbs = "",     -- birds, distant lawnmower
		industrial = "",  -- machinery hum
		hills = "",       -- wind
		business = "",    -- café chatter inside a business
		home = "",        -- quiet room tone at home
	},
	siren = "",           -- police siren loop (PoliceCars)
	tone = "rbxasset://sounds/electronicpingshort.wav",   -- the built-in tone the generated music and jingles are made of
}
return function(C)
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local new = C.new
C.AUDIO = AUDIO
local A = {mood = nil}
C.AudioDirector = A

-- ===== loading checks: a bad ID is switched off, once =====
local bad = {}
local function watch(sound, id)
	task.delay(8, function()
		if sound.Parent and sound.SoundId == id and not sound.IsLoaded and not bad[id] then
			bad[id] = true
			warn("[CornerEmpire] audio: " .. id .. " didn't load (not yours / not licensed for everyone?). Skipping it.")
		end
	end)
end
local function usable(list)
	local out = {}
	for _, id in ipairs(list or {}) do if type(id) == "string" and id ~= "" and not bad[id] then table.insert(out, id) end end
	return out
end

-- ===== the generated music: pitched tones (a tiny sequencer) =====
local tones = {}
for i = 1, 10 do tones[i] = new("Sound", {Name = "Tone" .. i, SoundId = AUDIO.tone, Volume = 0}, SoundService) end
local ti = 0
local function note(semi, vol)
	if not C.settings.music then return end
	ti = ti % #tones + 1
	local s = tones[ti]
	s.PlaybackSpeed = 2 ^ (semi / 12)
	s.Volume = vol * ((C.settings.musicVol or 5) / 10)
	s.TimePosition = 0
	s:Play()
end
A.note = note
-- moods: tempo (seconds per step), the chord progression (root semitones), a scale for the melody, loudness
local MOODS = {
	city = {step = 0.28, chords = {0, 7, 9, 5}, minor = false, vol = 0.10},
	night = {step = 0.42, chords = {9, 5, 0, 7}, minor = false, vol = 0.07},
	business = {step = 0.32, chords = {0, 9, 5, 7}, minor = false, vol = 0.08},
	home = {step = 0.48, chords = {0, 5, 9, 7}, minor = false, vol = 0.06},
	chase = {step = 0.18, chords = {0, 0, 8, 7}, minor = true, vol = 0.10},
}
A.MOODS = MOODS
local MAJOR, MINOR = {0, 4, 7, 12}, {0, 3, 7, 12}
local genOn, genMood = false, nil
task.spawn(function()
	local step = 0
	while true do
		local M = MOODS[genMood or "city"]
		task.wait(M and M.step or 0.3)
		if genOn and M and C.settings.music then
			step += 1
			local bar = math.floor((step - 1) / 8) % #M.chords + 1
			local root = M.chords[bar] - 12
			local shape = M.minor and MINOR or MAJOR
			local pos = (step - 1) % 8
			-- bass on the beat, a broken chord on top, a little melody every other bar
			if pos == 0 or pos == 4 then note(root - 12, M.vol * 0.9) end
			note(root + shape[(pos % 4) + 1], M.vol * (pos % 2 == 0 and 0.8 or 0.55))
			if bar % 2 == 0 and pos == 6 then note(root + 12 + shape[math.random(1, 3)], M.vol * 0.6) end
		end
	end
end)

-- ===== jingles: short musical feedback for what just happened =====
local JINGLES = {
	sale = {{12, 0.07}, {19, 0.09}},                       -- "ka-ching"
	upgrade = {{0, 0}, {4, 0.06}, {7, 0.06}, {12, 0.12}},
	milestone = {{0, 0}, {4, 0.08}, {7, 0.08}, {12, 0.1}, {7, 0.1}, {12, 0.1}, {16, 0.22}},
	success = {{7, 0}, {12, 0.1}},
	fail = {{4, 0}, {0, 0.14}, {-5, 0.16}},
	coin = {{19, 0}, {24, 0.06}},
}
A.JINGLES = JINGLES
local lastJingle = {}
function C.jingle(name, vol)
	local j = JINGLES[name]
	if not (j and C.settings.sfx) then return end
	local now = os.clock()
	if lastJingle[name] and now - lastJingle[name] < 0.35 then return end
	lastJingle[name] = now
	task.spawn(function()
		for _, n in ipairs(j) do
			if n[2] > 0 then task.wait(n[2]) end
			ti = ti % #tones + 1
			local s = tones[ti]
			s.PlaybackSpeed = 2 ^ (n[1] / 12)
			s.Volume = (vol or 0.35)
			s.TimePosition = 0
			s:Play()
		end
	end)
end

-- ===== streamed music (when the owner added IDs for a mood) =====
local music = new("Sound", {Name = "EmpireMusic", Volume = 0, Looped = false}, SoundService)
local streamMood, streamIndex = nil, 0
local function musicVolume() return (C.settings.musicVol or 5) / 10 * 0.5 end
local function playStream(mood)
	local list = usable(AUDIO.music[mood])
	if #list == 0 then return false end
	streamIndex = streamIndex % #list + 1
	music.SoundId = list[streamIndex]
	watch(music, music.SoundId)
	music.Volume = 0
	music:Play()
	C.tween(music, 1.5, {Volume = musicVolume()})
	streamMood = mood
	return true
end
music.Ended:Connect(function() if streamMood and C.settings.music then playStream(streamMood) end end)
C.musicAvailable = true    -- (there is always music now: streamed tracks or the generated chimes)

-- ===== ambience =====
local amb = new("Sound", {Name = "EmpireAmbience", Volume = 0, Looped = true}, SoundService)
local ambZone
local function setAmbience(zone)
	if zone == ambZone then return end
	ambZone = zone
	local id = AUDIO.ambience[zone]
	if type(id) ~= "string" or id == "" or bad[id] then
		C.tween(amb, 1, {Volume = 0})
		return
	end
	C.tween(amb, 0.8, {Volume = 0})
	task.delay(0.8, function()
		if ambZone ~= zone then return end
		amb.SoundId = id
		watch(amb, id)
		amb:Play()
		C.tween(amb, 1.5, {Volume = C.settings.sfx and 0.3 or 0})
	end)
end

-- ===== the director: what mood are we in? =====
local function zoneKey(z)
	if not z then return "city" end
	if z == "beach" or z == "hood_ocean" then return "beach" end
	if z == "industrial" or z == "expansion" then return "industrial" end
	if z == "hood_hills" then return "hills" end
	if z:find("^hood_") or z == "suburbs" then return "suburbs" end
	return "city"
end
function A.moodNow()
	local plr = C.plr
	if C.HeistUI and C.HeistUI.chasing then return "chase" end
	local interior = plr:GetAttribute("Interior")
	if interior == "home" then return "home" end
	if interior then return "business" end
	local t = Lighting.ClockTime
	if t >= 19.5 or t < 6 then return "night" end
	return "city"
end
local function apply()
	local mood = A.moodNow()
	A.mood = mood
	if not C.settings.music then
		genOn = false
		music:Pause()
	elseif mood ~= streamMood or not music.IsPlaying or bad[music.SoundId] then
		-- (a track that turned out not to load counts as "not playing": pick again or go back to the generated music)
		if bad[music.SoundId] then music:Stop() end
		if playStream(mood) then
			genOn = false
		else
			if music.IsPlaying then C.tween(music, 1, {Volume = 0}) task.delay(1, function() music:Stop() end) end
			streamMood = nil
			genOn, genMood = true, mood
		end
	end
	-- ambience: inside → the interior's, outside → the district's
	local interior = C.plr:GetAttribute("Interior")
	local zone = interior == "home" and "home" or (interior and "business")
	if not zone then
		local cam = Workspace.CurrentCamera.CFrame.Position
		zone = zoneKey(C.CityCrowd and C.CityCrowd.zoneAt and C.CityCrowd.zoneAt(cam) or nil)
	end
	setAmbience(zone)
	A.zone = zone
end
A.apply = apply
task.spawn(function()
	while true do
		task.wait(1.5)
		pcall(apply)
	end
end)

function C.applySettings()
	local s = C.settings
	music.Volume = s.music and musicVolume() or 0
	amb.Volume = s.sfx and (amb.IsPlaying and 0.3 or 0) or 0
	pcall(apply)
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
local _ = RunService
end
