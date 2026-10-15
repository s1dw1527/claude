-- A PREVIEW DUMP (not a test): builds the world on the simulated engine and prints every visible part inside a box
-- as one "ISO|..." line, for tools/iso.py to draw as an isometric picture. Not a render of the real game
-- (no lighting, no textures, wedges and balls drawn as boxes): it shows shapes, sizes, colours and layout.
--   SIM_ARGS='x1=350, z1=60, x2=680, z2=350, night=false' python3 tests/run.py tests/isodump.lua | python3 tools/iso.py out.svg
H.main(function()
	H.quiet = true
	local A = SIM_ARGS or {}
	local C = T.startServer()
	local a = H.addPlayer("Alice", 101)
	H.task.wait(2)
	T.newGame(a, 1, 1)
	H.task.wait(2)
	if A.plots then
		local d = T.data(a)
		d.cash, d.rep = 1e12, 9500
		for _, b in ipairs(C.BUSINESSES) do if not b.lotOnly then for _ = 1, A.plots do T.act(a, "buy", b.key) end end end
		H.task.wait(2)
	end
	local x1, z1, x2, z2 = A.x1 or -100, A.z1 or -100, A.x2 or 100, A.z2 or 100
	local function emit(p)
		local pos, s = p.Position, p.Size
		if pos.X < x1 or pos.X > x2 or pos.Z < z1 or pos.Z > z2 then return end
		if p.Transparency >= 0.95 or s.Magnitude > 2500 then return end
		local _, _, _, r1, r2, r3, r4, r5, r6, r7, r8, r9 = p.CFrame:GetComponents()
		local c = p.Color
		local mat = tostring(p.Material):gsub("Enum.Material.", "")
		if A.night and p:GetAttribute("NightTag") then mat = "Neon" end
		print(string.format("ISO|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%d|%d|%d|%s|%s|%.2f",
			pos.X, pos.Y, pos.Z, s.X, s.Y, s.Z, r1, r2, r3, r4, r5, r6, r7, r8, r9,
			math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), mat, p.ClassName, p.Transparency))
	end
	if A.night then
		for _, p in ipairs(H.service("CollectionService"):GetTagged("NightWindow")) do p:SetAttribute("NightTag", true) end
	end
	for _, p in ipairs(H.workspace:GetDescendants()) do
		if p:IsA("BasePart") and p.ClassName ~= "Terrain" then emit(p) end
	end
	print("ISODONE")
end)
