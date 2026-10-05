-- v10: the admin panel's security (server-side roles, no self-granting, save data never grants admin, confirmation
-- tokens for dangerous tools, username → UserId on the server, logging) and its tools.
-- Run with: python3 tests/run.py tests/admin_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
	local a = H.addPlayer("Alice", 101)    -- the owner (server config)
	local bob = H.addPlayer("Bob", 102)    -- a normal player
	H.startClient(a, T.clientScript)
	H.task.wait(2)
	local d = T.newGame(a, 1, 1)
	local db = T.newGame(bob, 1, 1)
	local cc = H.clientC
	local t0 = H.now()
	while (cc.storyCutscene() or cc.cinematicPlaying()) and H.now() - t0 < 120 do
		if cc.cinematicPlaying() then cc.cinematicSkip() end
		H.task.wait(0.5)
	end
	d.tut, db.tut = 0, 0
	C.G.nextEvent = H.now() + 3600
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.5) end
	local function lastMenu(plr, kind, mark)
		for i = #H.remoteLog, (mark or 0) + 1, -1 do
			local e = H.remoteLog[i]
			if e.name == "Menu" and e.player == plr and e.args[1] == kind then return e.args[2] end
		end
	end
	local function inModal(key, pat)
		for _, x in ipairs(cc.modals[key].frame:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end

	H.section("Who is an admin (server config only)")
	-- a live server: Studio's "everyone is an owner" switch is off; Alice is in the owners list
	C.ADMIN_CONFIG.studioIsOwner = false
	C.ADMIN_CONFIG.owners = {101}
	F.adminRefresh(a)
	F.adminRefresh(bob)
	H.check(F.adminRole(a) == "owner", "Alice (in the server's owner list) is an owner")
	H.check(F.adminRole(bob) == nil, "Bob is a normal player")
	-- nothing in save data can make you an admin
	db.admin, db.isAdmin, db.role, db.admins = true, true, "owner", {102}
	F.adminRefresh(bob)
	H.check(F.adminRole(bob) == nil, "admin-looking fields in Bob's save data change nothing")
	bob:SetAttribute("Admin", true)
	F.adminRefresh(bob)
	H.check(F.adminRole(bob) == nil, "neither do attributes")
	H.task.wait(1)
	H.check(cc.AdminPanel.role == "owner" and cc.AdminPanel.floatButton and cc.AdminPanel.floatButton.Visible, "Alice's client got the panel (the 🛡️ button)")

	H.section("Normal players are refused")
	local cash0 = db.cash
	local mk = #H.remoteLog
	T.act(bob, "adm", "giveCash", {target = bob.UserId, amount = 1e9})
	T.act(bob, "adm", "state")
	T.act(bob, "adm", "addAdmin", {text = "Bob"})
	T.act(bob, "adm", "fly", {on = true})
	T.act(bob, "adm", "confirm", "made-up-token")
	H.check(math.abs(db.cash - cash0) < F.incomePerSec(db) * 3 + 1, "Bob can't give himself cash")
	H.check(F.adminRole(bob) == nil, "Bob can't make himself an admin")
	H.check(bob:GetAttribute("AdminFly") == nil, "Bob can't turn on admin fly")
	H.check(lastMenu(bob, "adminState", mk) == nil and lastMenu(bob, "adminResult", mk) == nil, "Bob gets no admin data back at all")
	local deniedLogged = false
	for _, e in ipairs(C.ADMIN_LOG) do if e.tool == "DENIED" and e.admin == "Bob" then deniedLogged = true end end
	H.check(deniedLogged, "the refused attempt is logged")

	H.section("Admin tools")
	cash0 = db.cash
	T.act(a, "adm", "giveCash", {target = bob.UserId, amount = 5000})
	H.check(db.cash - cash0 >= 5000 and db.cash - cash0 < 5000 + F.incomePerSec(db) * 3 + 1, "give cash")
	local logged = C.ADMIN_LOG[1]
	H.check(logged and logged.admin == "Alice" and logged.tool == "giveCash" and logged.target == "Bob", "logged: Alice → giveCash • Bob")
	T.act(a, "adm", "giveCash", {target = bob.UserId, amount = -5})
	T.act(a, "adm", "giveCash", {target = bob.UserId, amount = 0 / 0})
	T.act(a, "adm", "giveCash", {target = 999999, amount = 5})
	H.check(lastMenu(a, "adminResult").ok == false, "bad amounts and unknown players are refused")
	T.act(a, "adm", "giveCar", {target = bob.UserId, key = "boulder"})
	H.check(db.cars.boulder == true, "give a car")
	T.act(a, "adm", "giveCar", {target = bob.UserId, key = "golden"})
	H.check(not db.cars.golden, "game-pass cars can't be handed out")
	T.act(a, "adm", "giveItem", {target = bob.UserId, key = "sofa", amount = 2})
	H.check(db.furniture.sofa == 2, "give furniture")
	T.act(a, "adm", "giveTickets", {target = bob.UserId, amount = 50})
	H.check(db.arcade.tickets >= 50, "give arcade tickets")
	T.act(a, "adm", "bizLevel", {target = bob.UserId, key = "lemonade", amount = 5})
	H.check(db.levels.lemonade == 5, "set a business level")
	T.act(a, "adm", "hqLevel", {target = bob.UserId, amount = 2})
	H.check(F.hqLevel(db) == 2, "set HQ floors")
	T.act(a, "adm", "freeze", {target = bob.UserId, on = true})
	H.check(bob.Character.HumanoidRootPart.Anchored and bob:GetAttribute("Frozen"), "freeze")
	T.act(a, "adm", "freeze", {target = bob.UserId, on = false})
	H.check(not bob.Character.HumanoidRootPart.Anchored, "unfreeze")
	T.act(a, "adm", "mute", {target = bob.UserId, on = true})
	local feed0 = #C.FEED
	T.act(bob, "post", nil, "hello city")
	H.check(F.isMuted(bob) and #C.FEED == feed0, "muted: Bob's CityBuzz posts are blocked")
	T.act(a, "adm", "mute", {target = bob.UserId, on = false})
	T.act(a, "adm", "warn", {target = bob.UserId, text = "please be nice"})
	H.check(lastMenu(a, "adminResult").ok, "warn")
	T.act(a, "adm", "warn", {target = bob.UserId, text = "badword"})
	H.check(lastMenu(a, "adminResult").ok == false, "admin messages go through the text filter too")
	T.act(a, "adm", "cityEvent", {key = "boom"})
	H.check(C.G.event and C.G.event.key == "boom", "trigger a city event (Economic Boom)")
	T.act(a, "adm", "speed", {amount = 60})
	H.check(a.Character.Humanoid.WalkSpeed == 60, "walk speed")
	T.act(a, "adm", "fly", {on = true})
	H.check(a:GetAttribute("AdminFly") == true, "fly on (set by the server)")
	T.act(a, "adm", "fly", {on = false})
	T.act(a, "adm", "npc")
	H.check(H.workspace:FindFirstChild("AdminNPC") ~= nil, "spawn a test NPC")
	T.act(a, "adm", "clearNpcs")
	T.act(a, "adm", "gotoPlayer", {target = bob.UserId})
	H.check((a.Character.HumanoidRootPart.Position - bob.Character.HumanoidRootPart.Position).Magnitude < 10, "teleport to a player")
	T.act(a, "adm", "place", {key = "funzone"})
	H.check((a.Character.HumanoidRootPart.Position - Vector3.new(-455, 4, -128)).Magnitude < 10, "teleport to a place")
	T.act(a, "adm", "place", {key = "nowhere"})
	H.check((a.Character.HumanoidRootPart.Position - Vector3.new(-455, 4, -128)).Magnitude < 10, "unknown places do nothing")
	db.perms = {house = "private", business = "private", hq = "private"}
	T.act(a, "adm", "enterInterior", {target = bob.UserId, key = "home"})
	H.check(a:GetAttribute("Interior") == "home" and a:GetAttribute("InteriorOwner") == bob.UserId, "moderation: an admin can step into a private home (and it's logged)")
	H.check(C.ADMIN_LOG[1].tool == "enterInterior", "...logged")
	F.leaveInterior(a)
	db.perms.house = "private"
	local carl = T.join("Carl", 103)
	T.newGame(carl, 1, 1)
	F.enterInterior(carl, bob, "home")
	H.check(carl:GetAttribute("Interior") == nil, "after the admin visit, Bob's private home is private again for everyone else")

	H.section("Dangerous tools need a confirmation")
	cash0 = db.cash
	mk = #H.remoteLog
	T.act(a, "adm", "removeCash", {target = bob.UserId, amount = 1000})
	local conf = lastMenu(a, "adminConfirm", mk)
	H.check(conf ~= nil and conf.token and db.cash >= cash0 - 1, "first tap: nothing happens, the server asks to confirm")
	T.act(a, "adm", "confirm", "wrong-token")
	H.check(db.cash >= cash0 - 1, "a wrong token does nothing")
	T.act(a, "adm", "removeCash", {target = bob.UserId, amount = 1000})
	conf = lastMenu(a, "adminConfirm", mk)
	T.act(a, "adm", "confirm", conf.token)
	H.check(db.cash <= cash0 - 999 + F.incomePerSec(db) * 3, "the right token runs it")
	local after = db.cash
	T.act(a, "adm", "confirm", conf.token)
	H.check(db.cash >= after - 1, "a token works only once")
	T.act(a, "adm", "removeCar", {target = bob.UserId, key = "boulder"})
	conf = lastMenu(a, "adminConfirm")
	H.task.wait(C.ADMIN_CONFIG.confirmSeconds + 1)
	T.act(a, "adm", "confirm", conf.token)
	H.check(db.cars.boulder == true, "an expired confirmation does nothing")
	T.act(bob, "adm", "confirm", conf.token)
	H.check(db.cars.boulder == true, "and nobody else can use your token")
	-- through the panel: the dangerous button opens the confirm dialog first
	H.task.wait(3)   -- (let the action rate limit refill after all the requests above)
	cc.openModal("admin")
	H.task.wait(0.8)
	H.check(cc.modals.admin.frame.Visible and inModal("admin", "DEVELOPER") ~= nil and inModal("admin", "MODERATION") ~= nil, "the panel opens with its tabs")
	cc.AdminPanel.target = bob.UserId
	cc.AdminPanel.tab = "VEHICLES"
	cc.AdminPanel.render()
	local kill
	for _, x in ipairs(cc.modals.admin.frame:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "✖ Boulder XL" then kill = x end end
	click(kill)
	H.task.wait(0.5)
	H.check(db.cars.boulder == true and cc.confirmBox.Visible, "tap ✖ Boulder XL: a confirmation dialog, nothing removed yet")
	local yes
	for _, x in ipairs(cc.confirmBox:GetDescendants()) do if x.ClassName == "TextButton" and x.Text == "Yes, do it" then yes = x end end
	click(yes)
	H.task.wait(0.5)
	H.check(db.cars.boulder == nil, "confirm: the car is removed")
	cc.closeModals()

	H.section("Managing admins")
	H.knownUsers.DevDana = 555
	T.act(a, "adm", "addAdmin", {text = "DevDana"})
	H.check(lastMenu(a, "adminResult").ok, "add an admin by username")
	local state = F.adminState(a)
	local found
	for _, e in ipairs(state.admins) do if e.id == 555 then found = e end end
	H.check(found and found.name == "DevDana", "the server resolved DevDana → UserId 555 and stored it")
	T.act(a, "adm", "addAdmin", {text = "NoSuchUser"})
	H.check(lastMenu(a, "adminResult").ok == false, "unknown usernames are refused")
	T.act(a, "adm", "addAdmin", {text = "bad name; drop"})
	H.check(lastMenu(a, "adminResult").ok == false, "invalid usernames are refused")
	T.act(a, "adm", "addAdmin", {text = "Bob"})
	H.task.wait(0.3)
	H.check(F.adminRole(bob) == "admin", "Bob added as an admin (by an owner)")
	cash0 = db.cash
	T.act(bob, "adm", "giveCash", {target = bob.UserId, amount = 10})
	H.check(db.cash >= cash0 + 10, "an admin can use the tools")
	T.act(bob, "adm", "addAdmin", {text = "Carl"})
	H.check(F.adminRole(carl) == nil, "but only owners can add admins")
	T.act(bob, "adm", "kick", {target = a.UserId})
	local bc = lastMenu(bob, "adminConfirm")
	if bc then T.act(bob, "adm", "confirm", bc.token) end
	H.check(a.Parent ~= nil, "owners can't be kicked from the panel")
	T.act(a, "adm", "removeAdmin", {target = bob.UserId})
	conf = lastMenu(a, "adminConfirm")
	T.act(a, "adm", "confirm", conf.token)
	H.task.wait(0.3)
	H.check(F.adminRole(bob) == nil, "removing an admin (confirmed) takes the panel away")
	H.check(db.admins[1] == 102 and d.admins == nil, "the admin list never touches player saves (Bob's fake field is untouched, nothing added)")

	H.section("Kick")
	T.act(a, "adm", "kick", {target = carl.UserId, text = "test kick"})
	conf = lastMenu(a, "adminConfirm")
	T.act(a, "adm", "confirm", conf.token)
	H.task.wait(0.5)
	H.check(carl.Parent == nil, "kick (confirmed): Carl is removed from the server")

	T.assertClean("admin")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
