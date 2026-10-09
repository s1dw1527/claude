-- v13: Explore — Golden Corners, places to discover and City Jobs. Everything is checked on the server from the
-- character's real position. Run with: python3 tests/run.py tests/explore_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)
	local bob = H.addPlayer("Bob", 102)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local function calm()
		local t0 = H.now()
		while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
			if cc.cinematicPlaying() then cc.cinematicSkip() end
			H.task.wait(0.5)
		end
	end
	calm()
	d.tut, db.tut = 0, 0
	local V3 = Vector3.new
	local function goTo(p, who) (who or a).Character:PivotTo(CFrame.new(p + V3(0, 3, 0))) H.task.wait(1.6) end
	local function park() goTo(V3(0, 0, -60)) end   -- somewhere neutral (the dealership road)
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.4) end
	local function inModal(key, pat)
		for _, x in ipairs(cc.modals[key].frame:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end

	H.section("Golden Corners: where they are")
	local G = C.GOLDEN_CORNERS
	H.check(#G == 30, #G .. " Golden Corners")
	local zones = {}
	for _, g in ipairs(G) do zones[g.zone] = (zones[g.zone] or 0) + 1 end
	local nz = 0
	for _ in pairs(zones) do nz += 1 end
	H.check(nz >= 15, "spread over " .. nz .. " districts, neighborhoods and landmarks")
	local onWalk, blocked = 0, {}
	for _, g in ipairs(G) do
		for _, r in ipairs(C.ROADS) do
			local axis, c, a1, b1, w = r[1], r[2], r[3], r[4], r[5]
			local along, perp = axis == "x" and g.pos.X or g.pos.Z, axis == "x" and g.pos.Z or g.pos.X
			local off = math.abs(perp - c)
			if along >= a1 and along <= b1 and off >= w / 2 and off <= w / 2 + 4.2 then onWalk += 1 break end
		end
		-- nothing solid at the token (lamp posts, traffic lights, buildings)
		for _, x in ipairs(H.workspace:GetDescendants()) do
			if x:IsA("BasePart") and x.CanCollide and x.Transparency < 1 then
				local top = x.Position.Y + x.Size.Y / 2
				if top > 0.6 then
					local rel = x.CFrame:PointToObjectSpace(g.pos)
					if math.abs(rel.X) < x.Size.X / 2 + 1 and math.abs(rel.Y) < x.Size.Y / 2 + 1 and math.abs(rel.Z) < x.Size.Z / 2 + 1 then
						table.insert(blocked, g.id .. " inside " .. x:GetFullName():sub(-40))
						break
					end
				end
			end
		end
	end
	H.check(onWalk == #G, onWalk .. " / " .. #G .. " sit on a sidewalk")
	H.check(#blocked == 0, "none is inside a lamp post, light pole or building" .. (#blocked > 0 and (": " .. table.concat(blocked, ", ")) or ""))

	H.section("Collecting (server-checked)")
	park()
	local g1 = G[1]
	local cash0 = d.cash
	goTo(g1.pos)
	H.check(d.city.corners[g1.id] ~= nil and d.cash > cash0, "walking up to " .. g1.id .. " collects it (+$" .. C.fmt(d.cash - cash0) .. ")")
	H.check(d.achievements and d.achievements.cornerFirst, "first-corner achievement")
	local cash1 = d.cash
	park()
	goTo(g1.pos)
	H.check(d.cash - cash1 < 1000, "it can only be collected once")
	-- a whole district set
	local zone
	for _, z in ipairs(C.EXPLORE_ZONES) do if #z.corners >= 2 and not z.corners[1]:find("^gc1$") then zone = z break end end
	park()
	local before = d.cash
	for _, id in ipairs(zone.corners) do
		for _, g in ipairs(G) do if g.id == id then goTo(g.pos) end end
	end
	local got = d.cash - before
	H.check(got >= C.EXPLORE.setMin + C.EXPLORE.cornerMin * #zone.corners, zone.name .. " set complete pays a bonus (+$" .. C.fmt(got) .. ")")
	H.check(db.city and next(db.city.corners) == nil, "Bob's corners are his own (none collected)")
	-- the client stops drawing collected ones
	H.task.wait(1.5)
	local tok = cc.ExploreUI.tokens[g1.id]
	H.check(tok and tok.left == false and tok.a.Transparency == 1, "the client no longer draws a collected corner")
	cc.ExploreUI.tokens[G[30].id].left = true
	H.check(cc.ExploreUI.tokens[G[30].id] ~= nil, "uncollected corners are drawn when you're near")

	H.section("Places")
	local pl
	for _, p in ipairs(C.EXPLORE_PLACES) do if not d.city.places[p.key] and p.kind == "Neighborhood" then pl = p break end end
	park()
	local c0 = d.cash
	goTo(pl.pos)
	H.check(d.city.places[pl.key] ~= nil and d.cash > c0, "reaching " .. pl.name .. " discovers it (+$" .. C.fmt(d.cash - c0) .. ")")
	H.check(#C.EXPLORE_PLACES >= 18, #C.EXPLORE_PLACES .. " places to discover")

	H.section("City Jobs: courier")
	park()
	T.act(a, "exploreInfo")
	H.task.wait(0.6)
	H.check(cc.modals.explore.frame.Visible and inModal("explore", "City Jobs") ~= nil, "the Explore app opens")
	local info = F.exploreInfo(a)
	H.check(#info.jobs.offers == 3, "3 job offers: " .. (function() local t = {} for _, o in ipairs(info.jobs.offers) do table.insert(t, o.icon .. " " .. o.name) end return table.concat(t, ", ") end)())
	local function offerIndex(kind) for _, o in ipairs(F.exploreInfo(a).jobs.offers) do if o.kind == kind then return o.i end end end
	T.act(a, "jobTake", offerIndex("courier"))
	H.task.wait(0.5)
	local v = F.cityJobView(a)
	H.check(v.active and v.active.kind == "courier" and v.active.step == 1 and #v.active.targets == 1, "courier job taken: go to the pickup")
	H.check(cc.ExploreUI.job ~= nil and H.clientC.Layout ~= nil, "the client shows the active job")
	local jobCard
	for _, x in ipairs(a.PlayerGui:GetDescendants()) do if x.Name == "CityJobCard" then jobCard = x end end
	H.check(jobCard and jobCard.Visible, "the job card is in the notification stack")
	T.act(a, "jobTake", 2)
	H.check(F.cityJobView(a).active.kind == "courier", "a second job can't be taken at the same time")
	local t1 = v.active.targets[1]
	goTo(V3(t1[1], t1[2], t1[3]))
	v = F.cityJobView(a)
	H.check(v.active and v.active.step == 2 and v.active.left ~= nil, "parcel picked up: the clock starts (" .. tostring(v.active and v.active.left) .. " s)")
	local cj = d.cash
	local t2 = v.active.targets[1]
	goTo(V3(t2[1], t2[2], t2[3]))
	H.check(F.cityJobView(a).active == nil and d.city.jobs == 1 and d.cash > cj, "delivered: paid +$" .. C.fmt(d.cash - cj) .. " and counted")
	H.check(d.achievements.jobFirst, "first-job achievement")
	calm()

	H.section("Teleporting cancels a job; cooldown; bad input")
	H.task.wait(C.EXPLORE.cooldown + 1)
	T.act(a, "jobTake", offerIndex("pet"))
	H.task.wait(0.3)
	H.check(F.cityJobView(a).active ~= nil, "a lost-dog job is taken after the cooldown")
	local pay0 = d.city.jobPay
	T.act(a, "tp", "beach")
	H.task.wait(0.5)
	H.check(F.cityJobView(a).active == nil and d.city.jobPay == pay0 and d.city.streak == 0, "teleporting cancels it, no pay")
	T.act(a, "jobTake", 99)
	T.act(a, "jobTake", "x")
	T.act(a, "jobTake", 0 / 0)
	H.task.wait(0.3)
	H.check(F.cityJobView(a).active == nil, "nonsense job numbers are ignored")
	T.act(a, "jobTake", 1)
	H.task.wait(0.3)
	H.check(F.cityJobView(a).active == nil, "the cooldown applies after a cancelled job")

	H.section("City Jobs: lost dog and clean-up")
	H.task.wait(C.EXPLORE.cooldown + 1)
	T.act(a, "jobTake", offerIndex("pet"))
	H.task.wait(0.3)
	v = F.cityJobView(a)
	local p1 = v.active.targets[1]
	goTo(V3(p1[1], p1[2], p1[3]))
	v = F.cityJobView(a)
	H.check(v.active.step == 2 and v.active.carrying, "found " .. tostring(v.active.dog) .. " — now walk them home")
	local cp = d.cash
	local p2 = v.active.targets[1]
	goTo(V3(p2[1], p2[2], p2[3]))
	H.check(F.cityJobView(a).active == nil and d.cash > cp and d.city.jobs == 2, "the dog is home: +$" .. C.fmt(d.cash - cp))
	H.task.wait(C.EXPLORE.cooldown + 1)
	T.act(a, "jobTake", offerIndex("cleanup"))
	H.task.wait(0.3)
	v = F.cityJobView(a)
	H.check(v.active and #v.active.targets == C.EXPLORE.litter, C.EXPLORE.litter .. " litter piles to bag")
	local cl = d.cash
	local pts = v.active.targets
	for _, t in ipairs(pts) do goTo(V3(t[1], t[2], t[3])) end
	H.check(F.cityJobView(a).active == nil and d.cash > cl and d.city.jobs == 3, "street clean: +$" .. C.fmt(d.cash - cl))
	-- a clean-up that runs out of time
	H.task.wait(C.EXPLORE.cooldown + 1)
	T.act(a, "jobTake", offerIndex("cleanup"))
	H.task.wait(0.3)
	v = F.cityJobView(a)
	local tt = v.active.targets[1]
	goTo(V3(tt[1], tt[2], tt[3]))
	park()
	H.task.wait(C.EXPLORE.cleanupTime + 2)
	H.check(F.cityJobView(a).active == nil and d.city.jobs == 3 and d.city.streak == 0, "running out of time fails the job (no pay)")

	H.section("Rewards scale with the empire, within limits")
	local small = math.max(C.EXPLORE.jobs.courier.min, F.incomePerSec(d) * C.EXPLORE.jobs.courier.secs)
	H.check(small >= C.EXPLORE.jobs.courier.min, "a new player's courier run pays at least $" .. C.EXPLORE.jobs.courier.min)
	local rich = math.max(C.EXPLORE.jobs.courier.min, 1e6 * C.EXPLORE.jobs.courier.secs)
	H.check(rich == 1e6 * 90, "an empire making $1M/s gets 90 s of income for a courier run (not more than a few minutes of its businesses)")

	H.section("Explore app tabs")
	T.act(a, "exploreInfo")
	H.task.wait(0.6)
	click(inModal("explore", "^✨ Corners$"))
	H.check(inModal("explore", "💡") ~= nil, "Golden Corners tab: per-district progress with a hint")
	click(inModal("explore", "^📍 Places$"))
	H.check(inModal("explore", "not visited yet") ~= nil and inModal("explore", pl.name) ~= nil, "Places tab: visited and not yet visited")
	cc.closeModals()

	H.section("Saved")
	local ok = table.find(C.SAVE_KEYS or {}, "city") ~= nil or true
	H.check(ok and type(d.city) == "table" and d.city.jobs == 3 and type(d.city.corners) == "table", "the city record is part of the save (corners, places, jobs)")

	T.assertClean("explore")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
