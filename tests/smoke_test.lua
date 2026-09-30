H.quiet = false
H.main(function()
	H.section("server + client boot")
	T.startServer()
	T.assertClean("server modules load")
	local p = H.addPlayer("Alice", 101)
	H.startClient(p, T.clientScript)
	H.task.wait(2)
	T.assertClean("client modules load")
	local cc = H.clientC
	H.check(cc ~= nil and cc.gui ~= nil, "client UI built")
	T.act(p, "menuNew", 1, 1)
	H.task.wait(5)
	T.assertClean("new game + 5s with client running")
	-- open every modal & phone view with live state
	for _, key in ipairs({"passes", "garage", "staff", "market", "marketing", "archive", "city", "home", "properties", "fun", "rebirth", "settings"}) do
		cc.openModal(key)
		H.task.wait(1.1)
	end
	cc.togglePhone(true)
	for _, v in ipairs({"buzz", "messages", "map", "home"}) do cc.phoneView(v) H.task.wait(0.2) end
	T.assertClean("all menus open with live state")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
