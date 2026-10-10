-- v14: audio. The music follows what you're doing (city day / night / business / home / police chase), the
-- generated music plays when no tracks are configured, configured tracks are streamed, a track that doesn't load
-- falls back, district/interior ambience, jingles for what happens, and the settings switch it all off.
-- Run with: python3 tests/run.py tests/audio_test.lua
H.main(function()
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut = 0
	local AD = cc.AudioDirector
	local Lighting = H.service("Lighting")
	local cam = H.workspace.CurrentCamera
	local function plays(name, since)
		local n, speeds = 0, {}
		for _, e in ipairs(H.soundLog or {}) do
			if e.t >= since and e.name:find(name) then n += 1 speeds[e.speed] = true end
		end
		local k = 0
		for _ in pairs(speeds) do k += 1 end
		return n, k
	end

	H.section("Mood follows what you're doing")
	Lighting.ClockTime = 13
	cc.setSetting("music", true)
	H.task.wait(2)
	H.check(AD.moodNow() == "city", "daytime in the city: " .. AD.moodNow())
	Lighting.ClockTime = 22
	H.check(AD.moodNow() == "night", "after dark: " .. AD.moodNow())
	Lighting.ClockTime = 13
	a:SetAttribute("Interior", "pizza")
	H.check(AD.moodNow() == "business", "inside a business: " .. AD.moodNow())
	a:SetAttribute("Interior", "home")
	H.check(AD.moodNow() == "home", "at home: " .. AD.moodNow())
	a:SetAttribute("Interior", nil)
	cc.HeistUI.chasing = true
	H.check(AD.moodNow() == "chase", "the police are chasing you: " .. AD.moodNow())
	cc.HeistUI.chasing = false

	H.section("Generated music (no tracks configured)")
	local s0 = H.now()
	H.task.wait(6)
	local n, pitches = plays("Tone", s0)
	H.check(n >= 12 and pitches >= 4, "the built-in music plays: " .. n .. " notes at " .. pitches .. " different pitches in 6 s")
	-- tempo changes with the mood: a chase is faster than home
	cc.HeistUI.chasing = true
	AD.apply()
	s0 = H.now()
	H.task.wait(4)
	local fast = plays("Tone", s0)
	cc.HeistUI.chasing = false
	a:SetAttribute("Interior", "home")
	AD.apply()
	s0 = H.now()
	H.task.wait(4)
	local slow = plays("Tone", s0)
	a:SetAttribute("Interior", nil)
	H.check(fast > slow * 1.5, "chase music is faster than home music (" .. fast .. " vs " .. slow .. " notes in 4 s)")
	cc.setSetting("music", false)
	H.task.wait(0.5)
	s0 = H.now()
	H.task.wait(3)
	local off = plays("Tone", s0)
	H.check(off == 0, "Settings → Music off: silence (" .. off .. " notes)")
	cc.setSetting("music", true)

	H.section("Configured tracks")
	cc.AUDIO.music.city = {"rbxassetid://1111"}
	AD.apply()
	H.task.wait(0.5)
	local mus = H.service("SoundService"):FindFirstChild("EmpireMusic")
	H.check(mus and mus.SoundId == "rbxassetid://1111" and mus.IsPlaying, "a track added for the city mood is streamed instead of the generated music")
	-- in the test engine nothing "loads", exactly like an ID you don't have the rights to: it's switched off
	H.task.wait(9)
	cc.AudioDirector.apply()
	AD.apply()
	H.task.wait(0.5)
	s0 = H.now()
	H.task.wait(3)
	local back = plays("Tone", s0)
	H.check(back > 0, "a track that doesn't load is skipped and the generated music comes back (" .. back .. " notes)")
	cc.AUDIO.music.city = {}

	H.section("Ambience")
	cam.CFrame = CFrame.new(150, 20, 340)
	AD.apply()
	H.check(AD.zone == "beach", "at the beach: " .. tostring(AD.zone))
	cam.CFrame = CFrame.new(-230, 20, 0)
	AD.apply()
	H.check(AD.zone == "industrial", "in the Industrial Zone: " .. tostring(AD.zone))
	a:SetAttribute("Interior", "pizza")
	AD.apply()
	H.check(AD.zone == "business", "inside a business: " .. tostring(AD.zone))
	a:SetAttribute("Interior", nil)
	cc.AUDIO.ambience.city = "rbxassetid://2222"
	cam.CFrame = CFrame.new(0, 20, 0)
	AD.apply()
	H.task.wait(1)
	local amb = H.service("SoundService"):FindFirstChild("EmpireAmbience")
	H.check(amb and amb.SoundId == "rbxassetid://2222" and amb.IsPlaying, "a configured ambience loop plays for its district")
	cc.AUDIO.ambience.city = ""

	H.section("Jingles")
	cc.setSetting("music", false)
	H.task.wait(0.5)
	s0 = H.now()
	cc.jingle("upgrade")
	H.task.wait(0.5)
	local j = plays("Tone", s0)
	H.check(j == 4, "an upgrade plays a 4-note rising jingle (" .. j .. ")")
	s0 = H.now()
	cc.jingle("sale")
	cc.jingle("sale")
	cc.jingle("sale")
	H.task.wait(0.3)
	j = plays("Tone", s0)
	H.check(j == 2, "sales right after each other don't pile up (" .. j .. " notes for 3 sales)")
	cc.setSetting("sfx", false)
	s0 = H.now()
	cc.jingle("milestone")
	H.task.wait(1)
	H.check(plays("Tone", s0) == 0, "Settings → Sound effects off: no jingles")
	cc.setSetting("sfx", true)
	cc.setSetting("music", true)
	-- a real milestone splash plays the fanfare
	s0 = H.now()
	C.R.Splash:FireClient(a, "👑 BILLIONAIRE!", "test", Color3.new(1, 1, 1))
	H.task.wait(1.2)
	H.check(plays("Tone", s0) >= 7, "a milestone celebration plays the fanfare")

	-- (the one warning we caused on purpose: the unusable test ID)
	local expected = 0
	for i = #H.warnings, 1, -1 do
		if H.warnings[i]:find("rbxassetid://1111", 1, true) then table.remove(H.warnings, i) expected += 1 end
	end
	H.check(expected == 1, "the unusable ID is reported once in Output (" .. expected .. ")")
	T.assertClean("audio")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
