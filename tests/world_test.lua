-- v19: the world overhaul. Every district has buildings (no empty slabs), an unsold plot's vacant building leaves its
-- View Property sign reachable at the front, buying a plot replaces the vacant building, windows light up at night
-- and go dark by day (on the client, no network), the mall's counters work, the beach has its boardwalk and
-- lighthouse, the logo is on the menu and title card, and the part budget holds.
-- Run with: python3 tests/run.py tests/world_test.lua
-- (Simulated engine: it checks what is built and how it behaves, not how it looks under Roblox lighting.)
H.main(function()
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	T.newGame(a, 1, 1)
	H.task.wait(2)
	local d = T.data(a)
	local CS = H.service("CollectionService")
	local Lighting = H.service("Lighting")
	local city = H.workspace:FindFirstChild("City")
	local RE = city:FindFirstChild("RealEstate")
	local function count(root, fn)
		local n = 0
		for _, x in ipairs(root:GetDescendants()) do if fn(x) then n += 1 end end
		return n
	end
	local function signText(root, pat)
		for _, x in ipairs(root:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and x.Text:find(pat) then return x end
		end
	end

	H.section("Every district has buildings")
	local function arch(x) return x:IsA("BasePart") and x.Name == "ArchSign" end
	for _, name in ipairs({"Midtown", "Entertainment", "Suburbs", "Expansion"}) do
		local f = RE:FindFirstChild(name)
		local n = f and count(f, arch) or 0
		H.check(n >= 10, name .. ": the city's own buildings line its streets (" .. n .. ")")
	end
	local styled, built = 0, 0
	for _, lot in ipairs(C.LOTS) do
		if not lot.owner and C.VACANT_STYLE[lot.dkey] then
			styled += 1
			if lot.folder and count(lot.folder, arch) > 0 then built += 1 end
		end
	end
	H.check(styled > 0 and built == styled, "every unsold plot has a vacant building in its district's style (" .. built .. "/" .. styled .. ")")
	local towers = C.WORLD:FindFirstChild("Downtown") or C.WORLD
	H.check(count(towers, function(x) return x:IsA("BasePart") and CS:HasTag(x, "NightWindow") end) > 50, "Downtown towers have lit window bands")
	H.check(signText(RE, "RESTAURANT ROW") ~= nil, "Midtown's gate reads RESTAURANT ROW")
	local rowNames = 0
	for _, n in ipairs(C.ROW_NAMES) do if signText(RE:FindFirstChild("Midtown"), n) then rowNames += 1 end end
	H.check(rowNames >= 12, "Restaurant Row's restaurants have their names up (" .. rowNames .. " of " .. #C.ROW_NAMES .. ")")
	local neon = 0
	for _, n in ipairs(C.NEON_NAMES) do if signText(RE:FindFirstChild("Entertainment"), n) then neon += 1 end end
	H.check(neon == #C.NEON_NAMES, "the Entertainment District's arcades and clubs have their names up (" .. neon .. ")")

	H.section("Unsold plots: the View Property sign stays reachable")
	local bad, checked = {}, 0
	for _, lot in ipairs(C.LOTS) do
		if not lot.owner and lot.folder then
			checked += 1
			local sign = lot.folder:FindFirstChild("Sign")
			local pp = sign and sign:FindFirstChildOfClass("ProximityPrompt")
			local o = CFrame.new(lot.pos) * CFrame.Angles(0, lot.yaw or 0, 0)
			local size = lot.size or 22
			-- where a player walks up: on the sidewalk just in front of the plot, in front of the sign
			local ls = sign and o:PointToObjectSpace(sign.Position)
			local stand = ls and o:PointToWorldSpace(Vector3.new(ls.X, 3, size / 2 + 1.5))
			local ok = pp ~= nil and pp.ActionText == "View Property" and pp.Enabled ~= false
			ok = ok and ls.Z > size / 2 - 4 and math.abs(ls.X) < size / 2
			ok = ok and (sign.Position - stand).Magnitude <= pp.MaxActivationDistance
			-- and no part of the vacant building stands between the sidewalk and the sign
			if ok then
				for _, p in ipairs(lot.folder:GetDescendants()) do
					if p:IsA("BasePart") and p ~= sign and p.CanCollide and p ~= lot.folder.PrimaryPart and p.Size.Y > 1 then
						local lp = o:PointToObjectSpace(p.Position)
						if lp.Z > ls.Z + 0.5 and math.abs(lp.X - ls.X) < p.Size.X / 2 + 1 and lp.Y - p.Size.Y / 2 < 4 then ok = false end
					end
				end
			end
			if not ok then table.insert(bad, lot.id) end
		end
	end
	H.check(checked > 50 and #bad == 0, "all " .. checked .. " unsold plots: a View Property prompt at the front corner, reachable from the sidewalk, nothing in the way"
		.. (#bad > 0 and (" (bad: " .. table.concat(bad, ",", 1, math.min(#bad, 8)) .. ")") or ""))
	-- buying a plot replaces the vacant building with the owner's business, exactly as before
	d.cash, d.rep = 1e7, 50
	local lot
	for _, l in ipairs(C.LOTS) do if not l.owner and l.dkey == "suburbs" then lot = l break end end
	T.act(a, "plotBuy", lot.id)
	H.task.wait(0.5)
	H.check(lot.owner == a and lot.folder and count(lot.folder, arch) == 0 and not lot.folder:FindFirstChild("Sign"),
		"buying a plot clears its vacant building and FOR SALE sign")
	T.act(a, "plotBiz", d.deeds[1].id, "lemonade")
	H.task.wait(0.5)
	H.check(d.deeds[1].biz == "lemonade" and count(lot.folder, function(x) return x:IsA("BasePart") end) > 10, "...and the owner's business is built there")

	H.section("Night windows (client only)")
	local tagged = CS:GetTagged("NightWindow")
	H.check(#tagged > 300, "the world tags its windows and street lights for the night (" .. #tagged .. ")")
	Lighting.ClockTime = 22
	H.task.wait(0.5)
	local lit = 0
	for _, p in ipairs(tagged) do if p.Material == Enum.Material.Neon then lit += 1 end end
	H.check(lit > #tagged * 0.5 and lit < #tagged, string.format("at 22:00 most windows glow and some stay dark (%d of %d lit)", lit, #tagged))
	local bulbsOn = true
	for _, p in ipairs(tagged) do if p.Name == "BulbString" and p.Material ~= Enum.Material.Neon then bulbsOn = false end end
	H.check(bulbsOn, "every string of street bulbs is on at night")
	Lighting.ClockTime = 12
	H.task.wait(0.5)
	lit = 0
	local restored = true
	for _, p in ipairs(tagged) do
		if p.Material == Enum.Material.Neon then lit += 1 end
		if p:GetAttribute("DayColor") and p.Color ~= p:GetAttribute("DayColor") then restored = false end
	end
	H.check(lit == 0 and restored, "at noon they are dark again, with their daytime colour and material back")

	H.section("Landmarks: the mall, the beach, industry")
	local mall = C.MALL
	H.check(mall and mall:FindFirstChild("MallSign") ~= nil, "the Heights Mall stands at the end of Heights Blvd")
	local counters = {}
	for _, x in ipairs(mall:GetDescendants()) do
		if x.Name == "MallCounter" and x:FindFirstChildOfClass("ProximityPrompt") then table.insert(counters, x:FindFirstChildOfClass("ProximityPrompt")) end
	end
	H.check(#counters >= 2, "the mall has its counters, each with a prompt (" .. #counters .. ")")
	local opened = {}
	for _, pp in ipairs(counters) do
		local mark = #H.remoteLog
		H.signalOf(pp, "Triggered"):Fire(a)
		H.task.wait(0.3)
		for _, e in ipairs(T.remotesSince(mark, "Menu", a)) do opened[tostring(e.args[1]) .. ":" .. tostring(e.args[2])] = true end
	end
	H.check(opened["openBazaar:nil"] and opened["open:furniture"], "the counters open the City Bazaar and the Furniture Store")
	local dest = false
	for _, x in ipairs(C.DESTS) do if x.name == "Heights Mall" then dest = true end end
	H.check(dest, "the mall is a map destination")
	local bw = C.WORLD:FindFirstChild("Boardwalk", true)
	local planks = bw and count(bw, function(x) return x:IsA("BasePart") and x.Material == Enum.Material.WoodPlanks end) or 0
	H.check(planks >= 8, "the beach has its boardwalk (" .. planks .. " plank sections)")
	local lh = C.WORLD:FindFirstChild("Lighthouse", true)
	H.check(lh and lh:FindFirstChildWhichIsA("SpotLight", true) ~= nil, "the pier has its lighthouse, with a beam")
	H.check(C.WORLD:FindFirstChild("Industrial") and count(C.WORLD.Industrial, function(x) return x:IsA("BasePart") and x.Size.X > 100 end) >= 2,
		"Industrial has its pipe racks")

	H.section("The logo")
	local mm = a.PlayerGui:FindFirstChild("MainMenu")
	H.check(mm and mm:FindFirstChild("Crown") and #mm.Crown:GetChildren() >= 7, "the main menu has the crown, built from frames (no image asset)")
	H.check(mm and mm:FindFirstChild("Motto") and mm.Motto.Text == "BUILD • RUN • EXPLORE • RISE", "...and BUILD • RUN • EXPLORE • RISE")
	-- the logo block (crown, name, promise, motto) stays above the save cards on phones and desktop
	local cam = H.workspace.CurrentCamera
	local function vspan(o, vpY)
		local sc = 1
		for _, ch in ipairs(o:GetChildren()) do if ch.ClassName == "UIScale" then sc = ch.Scale end end
		local h = (o.Size.Y.Scale * vpY + o.Size.Y.Offset) * sc
		local top = o.Position.Y.Scale * vpY + o.Position.Y.Offset - o.AnchorPoint.Y * h
		return top, top + h
	end
	for _, vp in ipairs({{390, 700}, {430, 932}, {844, 390}, {1280, 720}}) do
		rawget(cam, "_p").ViewportSize = H.G.Vector2.new(vp[1], vp[2])
		cam:GetPropertyChangedSignal("ViewportSize"):Fire()
		H.task.wait(0.3)
		local slotsTop = vspan(mm:FindFirstChild("SaveSlots", true), vp[2])
		local lowest, top = -1e9, 1e9
		for _, n in ipairs({"Crown", "Title", "Subtitle", "Motto", "Status"}) do
			local o = mm:FindFirstChild(n)
			if o and o.Visible then
				local t, b = vspan(o, vp[2])
				lowest, top = math.max(lowest, b), math.min(top, t)
			end
		end
		H.check(top >= 0 and lowest <= slotsTop, string.format("%d×%d: the logo (%.0f–%.0f px) stays above the save cards (from %.0f px)", vp[1], vp[2], top, lowest, slotsTop))
	end

	H.section("Part budget")
	local visible, all = 0, 0
	for _, p in ipairs(H.workspace:GetDescendants()) do
		if p:IsA("BasePart") and p.ClassName ~= "Terrain" then
			all += 1
			if p.Transparency < 0.99 then visible += 1 end
		end
	end
	print(string.format("    BUDGET visible=%d all=%d arch=%d", visible, all, C.ARCH_COUNT or 0))
	H.check(visible < 25000, string.format("visible parts in the world with one player: %d (budget 25,000)", visible))

	T.assertClean("world")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
