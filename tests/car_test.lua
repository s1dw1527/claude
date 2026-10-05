-- v10: 16 original vehicles, classes and stats, car details, the garage (equip, favorite, rename, customize, sell).
-- Run with: python3 tests/run.py tests/car_test.lua
H.main(function()
	local C = T.startServer()
	local F = C.F
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
	d.cash, d.rep = 1e9, 500
	local function click(b) H.signalOf(b, "MouseButton1Click"):Fire() H.task.wait(0.5) end
	local function inModal(key, pat)
		for _, x in ipairs(cc.modals[key].frame:GetDescendants()) do
			if (x.ClassName == "TextLabel" or x.ClassName == "TextButton") and tostring(x.Text):find(pat) then return x end
		end
	end

	H.section("The lineup")
	H.check(#C.CARS >= 15, #C.CARS .. " vehicles")
	local REAL = {"ferrari", "lamborghini", "porsche", "bmw", "audi", "mercedes", "tesla", "ford", "chevrolet", "chevy", "toyota", "honda", "nissan", "bugatti", "mclaren",
		"koenigsegg", "pagani", "rolls", "bentley", "jeep", "dodge", "mustang", "corvette", "camaro", "civic", "aston", "maserati", "jaguar", "lexus", "hummer", "cybertruck", "gt-r", "911"}
	local bad = {}
	for _, c in ipairs(C.CARS) do
		for _, r in ipairs(REAL) do if string.lower(c.name):find(r, 1, true) then table.insert(bad, c.name) end end
	end
	H.check(#bad == 0, "no real manufacturer or model names" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
	local classes = {}
	local okClass, okStats = true, true
	for _, c in ipairs(C.CARS) do
		local known = false
		for _, k in ipairs(C.CAR_CLASSES) do if k == c.class then known = true end end
		okClass = okClass and known
		classes[c.class or "?"] = true
		okStats = okStats and c.speed > 0 and c.accel and c.brake and c.turn and c.grip and c.drift and c.nitro and true
	end
	local nc = 0
	for _ in pairs(classes) do nc += 1 end
	H.check(okClass and nc == 7, "every car has a class; all 7 classes are used")
	H.check(okStats, "every car has speed, acceleration, handling, braking, grip, drift and nitro")
	local hyper, eco = F.carStats(C.CAR.hyper), F.carStats(C.CAR.hatch)
	H.check(hyper.speed > eco.speed and hyper.accel > eco.accel and hyper.braking > eco.braking, "a hypercar out-stats an economy hatch")
	local missing = {}
	for _, c in ipairs(C.CARS) do
		if c.style ~= "moped" then
			local m = C.buildCar(c, CFrame.new(0, 500, 0), "TEST")
			local n = {BrakeLight = 0, SignalL = 0, SignalR = 0, Headlight = 0, Dash = 0, SteeringWheel = 0, Exhaust = 0}
			for _, p in ipairs(m:GetDescendants()) do if n[p.Name] then n[p.Name] += 1 end end
			for k, v in pairs(n) do if v == 0 then table.insert(missing, c.key .. ":" .. k) end end
			m:Destroy()
		end
	end
	H.check(#missing == 0, "every car has brake lights, signals, headlights, a dash, a steering wheel, an exhaust" .. (#missing > 0 and (" (" .. table.concat(missing, ", ") .. ")") or ""))
	local stands = 0
	for _, x in ipairs(H.workspace:FindFirstChild("City"):FindFirstChild("CornerMotors"):GetDescendants()) do
		if x.ClassName == "ProximityPrompt" and x.ActionText == "Buy / Drive" then stands += 1 end
	end
	H.check(stands == #C.CARS, "Corner Motors shows all " .. stands .. " cars")

	H.section("Driving stats")
	T.act(a, "carDrive", "coupe")
	H.check(F.activeCar(a) == nil and not d.cars.coupe, "you can't drive a car you don't own")
	F.buyOrDrive(a, "coupe")
	H.task.wait(1)
	local car = F.activeCar(a)
	H.check(car ~= nil and d.cars.coupe, "bought the Sports Coupe")
	H.check(car and car.seat:GetAttribute("Accel") == C.CAR.coupe.accel and car.seat:GetAttribute("Brake") == C.CAR.coupe.brake and car.seat:GetAttribute("NitroPower") == C.CAR.coupe.nitro,
		"the driver seat carries acceleration, braking and nitro power")
	local weld
	for _, p in ipairs(car.model:GetDescendants()) do if p.Name == "SteerWeld" then weld = p end end
	H.check(weld ~= nil and weld.ClassName == "Weld", "the steering wheel hangs on a Weld the driver's screen can turn")
	H.task.wait(1.5)
	local det = cc.carDetails and cc.carDetails[car.model]
	H.check(det ~= nil and #det.brake == 2 and #det.left == 2 and #det.right == 2, "the client found the brake lights and signals")

	H.section("Garage")
	F.buyOrDrive(a, "hatch")
	F.buyOrDrive(a, "pixie")
	H.task.wait(0.5)
	cc.openModal("garage")
	H.task.wait(0.8)
	H.check(cc.modals.garage.frame.Visible and inModal("garage", "OWNED: 3 / " .. #C.CARS) ~= nil, "\"OWNED: 3 / " .. #C.CARS .. "\"")
	H.check(inModal("garage", "Hypercar") ~= nil and inModal("garage", "Handling") ~= nil, "cards show the class and stat bars")
	T.act(a, "carEquip", "hatch")
	H.check(d.garage.equipped == "hatch", "equip: the City Hatch is the main ride")
	T.act(a, "carEquip", "hyper")
	H.check(d.garage.equipped == "hatch", "you can't equip a car you don't own")
	T.act(a, "carFav", "pixie")
	H.task.wait(0.5)
	local info = F.garageInfo(a)
	H.check(d.garage.fav.pixie and info.cars[1].key == "pixie", "favorites sort to the top")
	T.act(a, "carName", "pixie", "Lil Zap")
	H.check(F.carName(d, "pixie") == "Lil Zap", "renamed: \"Lil Zap\"")
	T.act(a, "carName", "pixie", "badword car")
	H.check(F.carName(d, "pixie") == "Lil Zap", "filtered names are refused")
	T.act(a, "carName", "hyper", "Mine")
	H.check(F.carName(d, "hyper") == C.CAR.hyper.name, "you can't rename a car you don't own")
	T.act(a, "carName", "pixie", "")
	H.check(F.carName(d, "pixie") == "Pixie EV", "an empty name resets it")

	H.section("Customizing")
	local cash0 = d.cash
	T.act(a, "carMod", "coupe", "paint", "red")
	H.check(d.carMods.coupe and d.carMods.coupe.paint == "red" and d.cash < cash0, "red paint (paid)")
	F.spawnCar(a, "coupe")
	H.task.wait(0.5)
	car = F.activeCar(a)
	local red = false
	for _, p in ipairs(car.model:GetDescendants()) do if p:IsA("BasePart") and p.Color == Color3.fromRGB(210, 30, 40) then red = true end end
	H.check(red, "the parked coupe is rebuilt in red")
	T.act(a, "carMod", "coupe", "spoiler", "gt")
	T.act(a, "carMod", "coupe", "wheels", "gold")
	T.act(a, "carMod", "coupe", "tint", "limo")
	T.act(a, "carMod", "coupe", "exhaust", "quad")
	T.act(a, "carMod", "coupe", "decal", "flames")
	T.act(a, "carMod", "coupe", "interior", "tan")
	T.act(a, "carMod", "coupe", "bumper", "sport")
	local mm = d.carMods.coupe
	H.check(mm.spoiler == "gt" and mm.wheels == "gold" and mm.tint == "limo" and mm.exhaust == "quad" and mm.decal == "flames" and mm.interior == "tan" and mm.bumper == "sport",
		"spoiler, wheels, tint, exhaust, decals, interior, bumpers")
	T.act(a, "carMod", "coupe", "plate", "CORNER1")
	H.check(mm.plate == "CORNER1", "custom plate")
	T.act(a, "carMod", "coupe", "plate", "badword")
	H.check(mm.plate == "CORNER1", "plates go through the text filter")
	T.act(a, "carMod", "coupe", "engine", "v12")
	T.act(a, "carMod", "coupe", "paint", "rainbow")
	T.act(a, "carMod", "hyper", "paint", "red")
	H.check(mm.paint == "red" and mm.engine == nil and d.carMods.hyper == nil, "unknown parts, unknown options and cars you don't own are refused")
	local ac = F.activeCar(a)
	H.check(ac and ac.key == "coupe" and math.abs(ac.seat:GetAttribute("MaxSpeed") - C.CAR.coupe.speed * (1 + math.min(0.3, d.rebirths * 0.005))) < 0.01, "customizing never changes speed (" .. tostring(ac and ac.key) .. ")")
	T.act(a, "carMod", "coupe", "paint", "stock")
	H.check(mm.paint == nil, "back to stock")
	F.despawnCar(a)
	cc.closeModals()
	H.task.wait(0.3)
	local G = cc.GarageUI
	G.customize({key = "coupe", name = "Sports Coupe"})
	H.task.wait(0.5)
	H.check(cc.modals.carCustom.frame.Visible and inModal("carCustom", "GT Wing") ~= nil, "the customize window lists the parts")
	cc.closeModals()

	H.section("Selling")
	cash0 = d.cash
	T.act(a, "carSell", "hatch")
	H.check(d.cars.hatch == true, "selling needs the confirmation")
	T.act(a, "carSell", "hatch", true)
	H.check(d.cars.hatch == nil and d.garage.equipped == nil and d.cash - cash0 >= C.CAR.hatch.price * 0.5 - F.incomePerSec(d) * 2 - 1
		and d.cash - cash0 <= C.CAR.hatch.price * 0.5 + F.incomePerSec(d) * 2 + 1, "sold the hatch for half its price")
	local cash1 = d.cash
	d.passes.goldcar = true
	T.act(a, "carSell", "golden", true)
	T.act(a, "carSell", "legend", true)
	H.check(d.passes.goldcar == true and d.cash <= cash1 + F.incomePerSec(d) * 2 + 1, "pass and rebirth cars can't be sold")
	T.act(a, "carDrive")
	H.check(F.activeCar(a) == nil, "no main ride after selling it: the Drive shortcut does nothing")
	T.act(a, "carDrive", "pixie")
	H.check(F.activeCar(a) ~= nil and F.activeCar(a).key == "pixie", "drive any owned car from the garage")

	T.assertClean("cars + garage")
	print("\n" .. H.passed .. " passed, " .. H.failed .. " failed")
end)
