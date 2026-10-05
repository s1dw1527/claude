--!nocheck
-- A small fake Roblox engine for running Corner Empire's scripts outside Studio.
-- It is NOT a physics or rendering engine: parts are plain tables, time is simulated,
-- DataStores live in memory. It exists to run the real game code and check its logic.
local H = {errors = {}, warnings = {}, prints = {}, studio = true, dsFail = false, dsReadFail = false, quiet = true}

-- =====================================================================
-- SCHEDULER (simulated time; every script thread is a coroutine)
-- =====================================================================
local now = 0
local seq = 0
local queue = {}
H.now = function() return now end
local function schedule(t, co, args)
	seq += 1
	table.insert(queue, {t = t, s = seq, co = co, args = args or {n = 0}})
end
local function report(co, err)
	local msg = tostring(err) .. "\n" .. debug.traceback(co)
	table.insert(H.errors, msg)
	if not H.quiet then print("[thread error] " .. msg) end
end
local function resume(co, ...)
	if coroutine.status(co) ~= "suspended" then return end
	local ok, err = coroutine.resume(co, ...)
	if not ok then report(co, err) end
end
H.resume = resume

local task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	schedule(now, co, table.pack(...))
	return co
end
function task.delay(t, f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	schedule(now + (t or 0), co, table.pack(...))
	return co
end
function task.wait(t)
	t = t or 0.03
	if t < 0.03 then t = 0.03 end
	local co = coroutine.running()
	local start = now
	schedule(now + t, co, nil)
	coroutine.yield()
	return now - start
end
function task.cancel(co)
	for i = #queue, 1, -1 do
		if queue[i].co == co then table.remove(queue, i) end
	end
end
function task.synchronize() end
function task.desynchronize() end
H.task = task

-- run the scheduler until `main` finishes
H.lastHB = 0
function H.main(fn)
	local mainCo
	mainCo = coroutine.create(function()
		local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
		if not ok then
			print("\nTEST CRASHED: " .. err)
			H.failed += 1
		end
	end)
	resume(mainCo)
	local steps = 0
	while coroutine.status(mainCo) ~= "dead" do
		if #queue == 0 then error("scheduler starved: main is waiting but nothing is scheduled") end
		local bi = 1
		for i = 2, #queue do
			local q, b = queue[i], queue[bi]
			if q.t < b.t or (q.t == b.t and q.s < b.s) then bi = i end
		end
		local item = table.remove(queue, bi)
		if item.t > now then
			-- fire heartbeat-style signals every 0.1s of simulated time, however busy the queue is
			local hb = H.heartbeatSignals
			while hb and H.lastHB + 0.1 <= item.t do
				H.lastHB += 0.1
				now = math.max(now, H.lastHB)
				for _, sig in ipairs(hb) do sig:Fire(0.1) end
			end
			now = item.t
		end
		if item.args then resume(item.co, table.unpack(item.args, 1, item.args.n)) else resume(item.co) end
		steps += 1
	end
end

-- =====================================================================
-- SIGNALS
-- =====================================================================
local Signal = {}
Signal.__index = Signal
function Signal.new(name) return setmetatable({handlers = {}, name = name}, Signal) end
function Signal:Connect(fn)
	local h = {fn = fn, connected = true}
	table.insert(self.handlers, h)
	local sig = self
	return {Connected = true, Disconnect = function(c)
		h.connected = false
		c.Connected = false
		local i = table.find(sig.handlers, h)
		if i then table.remove(sig.handlers, i) end
	end}
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:ConnectParallel(fn) return self:Connect(fn) end
function Signal:Wait()
	local co = coroutine.running()
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		schedule(now, co, table.pack(...))
	end)
	return coroutine.yield()
end
function Signal:Fire(...)
	local list = table.clone(self.handlers)
	for _, h in ipairs(list) do
		if h.connected then task.spawn(h.fn, ...) end
	end
end
function Signal:count() return #self.handlers end
H.Signal = Signal

-- =====================================================================
-- DATA TYPES
-- =====================================================================
local TYPE = {}
local function typeofv(v)
	local mt = getmetatable(v)
	if type(v) == "table" and mt and TYPE[mt] then return TYPE[mt] end
	if type(v) == "table" and rawget(v, "__instance") then return "Instance" end
	return type(v)
end

-- ----- Vector3 -----
local V3mt = {}
TYPE[V3mt] = "Vector3"
local function V3(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, V3mt) end
local V3methods = {}
V3mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then return V3(0 / 0, 0 / 0, 0 / 0) end
		return V3(v.X / m, v.Y / m, v.Z / m)
	end
	if k == "x" then return v.X elseif k == "y" then return v.Y elseif k == "z" then return v.Z end
	return V3methods[k]
end
V3mt.__add = function(a, b) return V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return V3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return V3(a.X * b, a.Y * b, a.Z * b) end
	return V3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then return V3(a.X / b, a.Y / b, a.Z / b) end
	return V3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3mt.__unm = function(a) return V3(-a.X, -a.Y, -a.Z) end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__tostring = function(v) return string.format("%g, %g, %g", v.X, v.Y, v.Z) end
function V3methods.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3methods.Cross(a, b) return V3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3methods.Lerp(a, b, t) return a + (b - a) * t end
function V3methods.FuzzyEq(a, b, eps) return (a - b).Magnitude <= (eps or 1e-5) end
function V3methods.Abs(a) return V3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function V3methods.Max(a, b) return V3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function V3methods.Min(a, b) return V3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V3methods.Floor(a) return V3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z)) end
local Vector3 = {new = V3, zero = V3(0, 0, 0), one = V3(1, 1, 1), xAxis = V3(1, 0, 0), yAxis = V3(0, 1, 0), zAxis = V3(0, 0, 1)}

-- ----- Vector2 -----
local V2mt = {}
TYPE[V2mt] = "Vector2"
local function V2(x, y) return setmetatable({X = x or 0, Y = y or 0}, V2mt) end
V2mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y) return V2(v.X / m, v.Y / m) end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y end end
	if k == "Lerp" then return function(a, b, t) return V2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end end
	return nil
end
V2mt.__add = function(a, b) return V2(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) return V2(a.X - b.X, a.Y - b.Y) end
V2mt.__mul = function(a, b)
	if type(a) == "number" then return V2(b.X * a, b.Y * a) end
	if type(b) == "number" then return V2(a.X * b, a.Y * b) end
	return V2(a.X * b.X, a.Y * b.Y)
end
V2mt.__div = function(a, b) return type(b) == "number" and V2(a.X / b, a.Y / b) or V2(a.X / b.X, a.Y / b.Y) end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
local Vector2 = {new = V2, zero = V2(0, 0), one = V2(1, 1)}

-- ----- CFrame (position + 3x3 rotation, row major) -----
local CFmt = {}
TYPE[CFmt] = "CFrame"
local CFmethods = {}
local function CFraw(p, r) return setmetatable({p = p, r = r}, CFmt) end
local IDR = {1, 0, 0, 0, 1, 0, 0, 0, 1}
local function mulR(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function rotV(r, v) return V3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z) end
local function transR(r) return {r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9]} end
local function Rx(a) local c, s = math.cos(a), math.sin(a) return {1, 0, 0, 0, c, -s, 0, s, c} end
local function Ry(a) local c, s = math.cos(a), math.sin(a) return {c, 0, s, 0, 1, 0, -s, 0, c} end
local function Rz(a) local c, s = math.cos(a), math.sin(a) return {c, -s, 0, s, c, 0, 0, 0, 1} end
local function lookAtR(pos, target, up)
	local f = (target - pos)
	if f.Magnitude < 1e-9 then return table.clone(IDR) end
	f = f.Unit
	up = up or V3(0, 1, 0)
	local rt = f:Cross(up)
	if rt.Magnitude < 1e-6 then rt = f:Cross(V3(0, 0, 1)) end
	rt = rt.Unit
	local u = rt:Cross(f)
	-- columns: right, up, back(-forward)
	return {rt.X, u.X, -f.X, rt.Y, u.Y, -f.Y, rt.Z, u.Z, -f.Z}
end
local CFrame = {}
function CFrame.new(a, b, c, ...)
	if a == nil then return CFraw(V3(), table.clone(IDR)) end
	if typeofv(a) == "Vector3" then
		if b and typeofv(b) == "Vector3" then return CFraw(a, lookAtR(a, b)) end
		return CFraw(a, table.clone(IDR))
	end
	local rest = {...}
	if #rest == 9 then return CFraw(V3(a, b, c), rest) end
	if #rest == 4 then
		local qx, qy, qz, qw = rest[1], rest[2], rest[3], rest[4]
		return CFraw(V3(a, b, c), {1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)})
	end
	return CFraw(V3(a, b, c), table.clone(IDR))
end
function CFrame.Angles(x, y, z) return CFraw(V3(), mulR(mulR(Rx(x or 0), Ry(y or 0)), Rz(z or 0))) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z) return CFraw(V3(), mulR(mulR(Ry(y or 0), Rx(x or 0)), Rz(z or 0))) end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.lookAt(at, target, up) return CFraw(at, lookAtR(at, target, up)) end
function CFrame.fromAxisAngle(axis, a)
	local u = axis.Unit
	local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
	return CFraw(V3(), {t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y,
		t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X,
		t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c})
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return CFraw(pos, {vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z})
end
CFrame.identity = CFraw(V3(), table.clone(IDR))
CFmt.__index = function(cf, k)
	if k == "Position" or k == "p" then return cf.p end
	if k == "X" then return cf.p.X elseif k == "Y" then return cf.p.Y elseif k == "Z" then return cf.p.Z end
	local r = rawget(cf, "r")
	if k == "LookVector" then return V3(-r[3], -r[6], -r[9]) end
	if k == "RightVector" then return V3(r[1], r[4], r[7]) end
	if k == "UpVector" then return V3(r[2], r[5], r[8]) end
	if k == "Rotation" then return CFraw(V3(), table.clone(r)) end
	return CFmethods[k]
end
CFmt.__mul = function(a, b)
	if typeofv(b) == "Vector3" then return rotV(a.r, b) + a.p end
	return CFraw(rotV(a.r, b.p) + a.p, mulR(a.r, b.r))
end
CFmt.__add = function(a, v) return CFraw(a.p + v, table.clone(a.r)) end
CFmt.__sub = function(a, v) return CFraw(a.p - v, table.clone(a.r)) end
CFmt.__eq = function(a, b) return a.p == b.p end
CFmt.__tostring = function(c) return "CFrame(" .. tostring(c.p) .. ")" end
function CFmethods.Inverse(cf)
	local rt = transR(cf.r)
	return CFraw(-rotV(rt, cf.p), rt)
end
function CFmethods.ToObjectSpace(a, b) return a:Inverse() * b end
function CFmethods.ToWorldSpace(a, b) return a * b end
function CFmethods.PointToWorldSpace(a, v) return a * v end
function CFmethods.PointToObjectSpace(a, v) return a:Inverse() * v end
function CFmethods.VectorToWorldSpace(a, v) return rotV(a.r, v) end
function CFmethods.VectorToObjectSpace(a, v) return rotV(transR(a.r), v) end
function CFmethods.ToOrientation(cf)
	local r = cf.r
	local x = math.asin(math.clamp(-r[6], -1, 1))
	local y = math.atan2(r[3], r[9])
	local z = math.atan2(r[4], r[5])
	return x, y, z
end
function CFmethods.ToEulerAnglesYXZ(cf) return cf:ToOrientation() end
function CFmethods.ToEulerAnglesXYZ(cf)
	local r = cf.r
	local y = math.asin(math.clamp(r[3], -1, 1))
	return math.atan2(-r[6], r[9]), y, math.atan2(-r[2], r[1])
end
function CFmethods.Lerp(a, b, t) return CFraw(a.p:Lerp(b.p, t), t < 0.5 and table.clone(a.r) or table.clone(b.r)) end
function CFmethods.GetComponents(cf) local r = cf.r return cf.p.X, cf.p.Y, cf.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end
CFmethods.components = CFmethods.GetComponents
function CFmethods.ToAxisAngle(cf) return V3(0, 1, 0), 0 end

-- ----- Color3 -----
local C3mt = {}
TYPE[C3mt] = "Color3"
local C3methods = {}
C3mt.__index = C3methods
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3mt.__tostring = function(c) return string.format("%g, %g, %g", c.R, c.G, c.B) end   -- like Roblox
local function C3(r, g, b) return setmetatable({R = r or 0, G = g or 0, B = b or 0}, C3mt) end
function C3methods.Lerp(a, b, t) return C3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3methods.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == c.R then h = ((c.G - c.B) / d) % 6 elseif mx == c.G then h = (c.B - c.R) / d + 2 else h = (c.R - c.G) / d + 4 end
		h /= 6
	end
	return h, mx == 0 and 0 or d / mx, mx
end
function C3methods.ToHex(c) return string.format("%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255) end
local Color3 = {new = C3}
function Color3.fromRGB(r, g, b) return C3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v)
	h = (h % 1) * 6
	local i = math.floor(h)
	local f = h - i
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	local r, g, b
	if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
	elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
	return C3(r, g, b)
end
function Color3.fromHex(hex) return C3(0.5, 0.5, 0.5) end

-- ----- UDim / UDim2 -----
local UDmt, UD2mt = {}, {}
TYPE[UDmt], TYPE[UD2mt] = "UDim", "UDim2"
local function UD(s, o) return setmetatable({Scale = s or 0, Offset = o or 0}, UDmt) end
UDmt.__add = function(a, b) return UD(a.Scale + b.Scale, a.Offset + b.Offset) end
local function UD2(xs, xo, ys, yo) return setmetatable({X = UD(xs, xo), Y = UD(ys, yo), Width = UD(xs, xo), Height = UD(ys, yo)}, UD2mt) end
UD2mt.__add = function(a, b) return UD2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
UD2mt.__sub = function(a, b) return UD2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
UD2mt.__index = {Lerp = function(a, b, t) return UD2(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t, a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t) end}
local UDim = {new = UD}
local UDim2 = {new = function(a, b, c, d)
	if typeofv(a) == "UDim" then return UD2(a.Scale, a.Offset, b.Scale, b.Offset) end
	return UD2(a, b, c, d)
end, fromScale = function(x, y) return UD2(x, 0, y, 0) end, fromOffset = function(x, y) return UD2(0, x, 0, y) end}

-- ----- simple value types -----
local function valueType(name, ctor)
	local mt = {}
	TYPE[mt] = name
	mt.__index = function(t, k) return nil end
	return {new = function(...) local o = ctor(...) return setmetatable(o, mt) end}, mt
end
local NumberRange = valueType("NumberRange", function(a, b) return {Min = a, Max = b or a} end)
local NumberSequenceKeypoint = valueType("NumberSequenceKeypoint", function(t, v, e) return {Time = t, Value = v, Envelope = e or 0} end)
local NumberSequence = valueType("NumberSequence", function(a, b) return {Keypoints = type(a) == "table" and a or {{Time = 0, Value = a}, {Time = 1, Value = b or a}}} end)
local ColorSequenceKeypoint = valueType("ColorSequenceKeypoint", function(t, v) return {Time = t, Value = v} end)
local ColorSequence = valueType("ColorSequence", function(a, b) return {Keypoints = typeofv(a) == "Color3" and {{Time = 0, Value = a}, {Time = 1, Value = b or a}} or a} end)
local TweenInfo = valueType("TweenInfo", function(t, style, dir, rep, rev, delay) return {Time = t or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = delay or 0} end)
local PhysicalProperties = valueType("PhysicalProperties", function(d, f, e, fw, ew) return {Density = d, Friction = f, Elasticity = e, FrictionWeight = fw, ElasticityWeight = ew} end)
local Rect = valueType("Rect", function(a, b, c, d) return {Min = V2(a, b), Max = V2(c, d)} end)
local Ray = valueType("Ray", function(o, d) return {Origin = o, Direction = d} end)
local BrickColor = valueType("BrickColor", function(n) return {Name = tostring(n), Color = C3(0.5, 0.5, 0.5)} end)
local Region3mt = {}
TYPE[Region3mt] = "Region3"
Region3mt.__index = {ExpandToGrid = function(r) return r end}
local Region3 = {new = function(a, b) return setmetatable({Min = a, Max = b, CFrame = CFrame.new((a + b) / 2), Size = b - a}, Region3mt) end}
local RaycastParams = {new = function() return {FilterDescendantsInstances = {}, FilterType = nil, IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false, AddToFilter = function() end} end}
local OverlapParams = {new = function() return {FilterDescendantsInstances = {}, FilterType = nil, MaxParts = 0, AddToFilter = function() end} end}

local Randommt = {}
Randommt.__index = {
	NextNumber = function(r, a, b)
		r.s = (r.s * 1103515245 + 12345) % 2147483648
		local f = r.s / 2147483648
		if a then return a + (b - a) * f end
		return f
	end,
	NextInteger = function(r, a, b)
		r.s = (r.s * 1103515245 + 12345) % 2147483648
		return a + math.floor(r.s / 2147483648 * (b - a + 1))
	end,
	Shuffle = function(r, t) end,
	Clone = function(r) return setmetatable({s = r.s}, Randommt) end,
}
local Random = {new = function(seed) return setmetatable({s = math.floor(math.abs(seed or 12345)) % 2147483648}, Randommt) end}

-- ----- Enum (any Enum.X.Y works, identical items compare equal) -----
local enumItems = {}
local EnumItemMt = {__tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end}
TYPE[EnumItemMt] = "EnumItem"
local Enum = setmetatable({}, {__index = function(_, typ)
	enumItems[typ] = enumItems[typ] or {}
	return setmetatable({GetEnumItems = function() return {} end}, {__index = function(_, name)
		local e = enumItems[typ][name]
		if not e then
			local n = 0
			for _ in pairs(enumItems[typ]) do n += 1 end
			e = setmetatable({Name = name, EnumType = typ, Value = n}, EnumItemMt)
			enumItems[typ][name] = e
		end
		return e
	end})
end})

-- =====================================================================
-- INSTANCES
-- =====================================================================
local ISA = {
	Part = "BasePart", WedgePart = "BasePart", SpawnLocation = "Part", VehicleSeat = "BasePart", Seat = "Part", MeshPart = "BasePart", TrussPart = "BasePart", CornerWedgePart = "BasePart",
	BasePart = "PVInstance", Model = "PVInstance", Workspace = "Model", PVInstance = "Instance",
	Frame = "GuiObject", TextLabel = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject", TextBox = "GuiObject",
	ImageLabel = "GuiObject", ScrollingFrame = "GuiObject", ViewportFrame = "GuiObject", CanvasGroup = "GuiObject", GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector", LayerCollector = "GuiBase2d", GuiBase2d = "Instance",
	PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light", Light = "Instance",
	IntValue = "ValueBase", StringValue = "ValueBase", NumberValue = "ValueBase", BoolValue = "ValueBase", ObjectValue = "ValueBase", ValueBase = "Instance",
	LocalScript = "Script", Script = "LuaSourceContainer", ModuleScript = "LuaSourceContainer",
	UICorner = "UIComponent", UIStroke = "UIComponent", UIGradient = "UIComponent", UIListLayout = "UIGridStyleLayout", UIGridLayout = "UIGridStyleLayout",
	UIGridStyleLayout = "UIComponent", UIPadding = "UIComponent", UIScale = "UIComponent", UIAspectRatioConstraint = "UIComponent", UISizeConstraint = "UIComponent", UIComponent = "Instance",
	WeldConstraint = "Instance", AlignOrientation = "Constraint", AlignPosition = "Constraint", Constraint = "Instance",
}
local function isA(cls, name)
	if name == "Instance" then return true end
	local c = cls
	while c do
		if c == name then return true end
		c = ISA[c]
	end
	return false
end
H.isA = isA
local GUI = {Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, ViewportFrame = true, CanvasGroup = true}

local EVENT_SUFFIX = {"Click", "Changed", "Added", "Removed", "Removing", "Began", "Ended", "Finished", "Stepped", "Triggered", "Event", "Completed", "Died", "Touched", "Seated",
	"Enter", "Leave", "Down", "Up", "Lost", "Activated", "Played", "Heartbeat", "Destroying", "Invoke", "Stopped", "Shown", "Hidden", "Fired", "Focused", "Resumed", "Paused", "Looped", "Loaded"}
local function isEventName(k)
	if type(k) ~= "string" or not k:match("^[A-Z]") then return false end
	for _, s in ipairs(EVENT_SUFFIX) do
		if k:sub(-#s) == s then return true end
	end
	return k == "OnServerEvent" or k == "OnClientEvent"
end

local Inst = {}  -- methods
local instmt = {}
local allInstances = setmetatable({}, {__mode = "k"})
H.created = 0

local function defaults(o, k)
	local cls = o.ClassName
	if k == "Name" then return cls end
	if k == "Parent" then return nil end
	if GUI[cls] then
		if k == "Size" or k == "Position" then return UD2(0, 0, 0, 0) end
		if k == "AbsoluteSize" then return V2(200, 50) end
		if k == "AbsolutePosition" then return V2(0, 0) end
		if k == "Visible" then return true end
		if k == "Text" then return "" end
		if k == "Rotation" or k == "BackgroundTransparency" or k == "TextTransparency" or k == "ZIndex" or k == "LayoutOrder" then return 0 end
		if k == "BackgroundColor3" or k == "TextColor3" then return C3(1, 1, 1) end
		if k == "TextBounds" then return V2(100, 20) end
		if k == "AutoButtonColor" then return true end
		if k == "CanvasSize" then return UD2(0, 0, 0, 0) end
		if k == "CanvasPosition" then return V2(0, 0) end
		if k == "AnchorPoint" then return V2(0, 0) end
	end
	if isA(cls, "BasePart") then
		if k == "Size" then return V3(4, 1, 2) end
		if k == "CFrame" then return CFrame.new() end
		if k == "Position" then return (rawget(o, "_p").CFrame or CFrame.new()).p end
		if k == "Orientation" then return V3() end
		if k == "Transparency" or k == "Reflectance" then return 0 end
		if k == "Color" then return C3(0.6, 0.6, 0.6) end
		if k == "Anchored" or k == "Massless" then return false end
		if k == "CanCollide" or k == "CanQuery" or k == "CanTouch" or k == "CastShadow" then return true end
		if k == "AssemblyLinearVelocity" or k == "AssemblyAngularVelocity" or k == "Velocity" then return V3() end
		if k == "AssemblyMass" then return 10 end
		if k == "Occupant" then return nil end
		if k == "ThrottleFloat" or k == "SteerFloat" or k == "Throttle" or k == "Steer" then return 0 end
	end
	if cls == "Model" or cls == "Workspace" then
		if k == "PrimaryPart" then return nil end
		if k == "WorldPivot" then return CFrame.new() end
	end
	if cls == "Humanoid" then
		if k == "WalkSpeed" then return 16 end
		if k == "JumpPower" or k == "JumpHeight" then return 50 end
		if k == "Health" or k == "MaxHealth" then return 100 end
		if k == "SeatPart" then return nil end
		if k == "Sit" then return false end
		if k == "MoveDirection" then return V3() end
		if k == "RootPart" then return o.Parent and o.Parent:FindFirstChild("HumanoidRootPart") end
	end
	if cls == "Camera" then
		if k == "CFrame" then return CFrame.new(0, 50, 50) end
		if k == "ViewportSize" then return V2(1280, 720) end
		if k == "FieldOfView" then return 70 end
		if k == "Focus" then return CFrame.new() end
	end
	if k == "Enabled" or k == "Visible" or k == "Archivable" then return true end
	if k == "Value" then
		if cls == "IntValue" or cls == "NumberValue" then return 0 end
		if cls == "StringValue" then return "" end
		if cls == "BoolValue" then return false end
	end
	if k == "Scale" then return 1 end
	if k == "Volume" then return 0.5 end
	if k == "IsPlaying" then return false end
	if k == "TimePosition" then return 0 end
	if k == "Rate" then return 0 end
	return nil
end

local function newInstance(cls)
	local o = {}
	local p = {ClassName = cls}
	rawset(o, "__instance", true)
	rawset(o, "_p", p)
	rawset(o, "_children", {})
	rawset(o, "_attrs", {})
	rawset(o, "_signals", {})
	rawset(o, "_propsig", {})
	rawset(o, "_attrsig", {})
	setmetatable(o, instmt)
	allInstances[o] = true
	H.created += 1
	return o
end

local function signalOf(o, k)
	local s = rawget(o, "_signals")[k]
	if not s then
		s = Signal.new(k)
		rawget(o, "_signals")[k] = s
	end
	return s
end
H.signalOf = signalOf

-- like real Roblox: reading or writing a member a class doesn't have is an error ("X is not a valid member of Y").
-- (Scripts can't hang their own fields on Instances; that's what attributes or Lua tables are for.)
H.strict = true
local API = ROBLOX_API or {}
local memberSets = {}
local function isMember(cls, k)
	local set = memberSets[cls]
	if not set then
		set = {}
		local c = cls
		while c and API[c] do
			for _, m in ipairs(API[c][2]) do set[m] = true end
			c = API[c][1]
		end
		memberSets[cls] = set
	end
	return set[k] == true
end
local function strictFail(o, k, verb)
	local p = rawget(o, "_p")
	local cls = p.ClassName
	if H.strict and API[cls] and not isMember(cls, k) then
		error(tostring(k) .. " is not a valid member of " .. cls .. ' "' .. tostring(p.Name or cls) .. '"' .. (verb and " (" .. verb .. ")" or ""), 3)
	end
end
instmt.__index = function(o, k)
	local p = rawget(o, "_p")
	local v = p[k]
	if v ~= nil then return v end
	if k == "Position" and isA(p.ClassName, "BasePart") then return (p.CFrame or CFrame.new()).p end
	local m = Inst[k]
	if m ~= nil then return m end
	local d = defaults(o, k)
	if d ~= nil then return d end
	for _, c in ipairs(rawget(o, "_children")) do
		if c.Name == k then return c end
	end
	if isEventName(k) then return signalOf(o, k) end
	local custom = rawget(o, "_custom")
	if custom and custom[k] ~= nil then return custom[k] end
	if type(k) == "string" then strictFail(o, k, "read") end
	return nil
end
instmt.__newindex = function(o, k, v)
	local p = rawget(o, "_p")
	if k == "Parent" then
		if rawget(o, "_destroyed") then error("The Parent property of " .. tostring(p.Name or p.ClassName) .. " is locked", 2) end
		local old = p.Parent
		if old == v then return end
		if old then
			local list = rawget(old, "_children")
			local i = table.find(list, o)
			if i then table.remove(list, i) end
			signalOf(old, "ChildRemoved"):Fire(o)
		end
		p.Parent = v
		if v then
			table.insert(rawget(v, "_children"), o)
			signalOf(v, "ChildAdded"):Fire(o)
			local a = v
			while a do
				local s = rawget(a, "_signals").DescendantAdded
				if s then s:Fire(o) end
				a = rawget(a, "_p").Parent
			end
		end
		signalOf(o, "AncestryChanged"):Fire(o, v)
		return
	end
	if k == "Position" and isA(p.ClassName, "BasePart") then
		local cf = p.CFrame or CFrame.new()
		p.CFrame = CFraw(v, table.clone(cf.r))
		return
	end
	if type(k) == "string" and not rawget(o, "_custom") then strictFail(o, k, "write") end
	if type(v) == "number" and v ~= v and (k == "Value" or k == "Transparency") then
		table.insert(H.warnings, "NaN assigned to " .. tostring(p.ClassName) .. "." .. k)
	end
	local old = p[k]
	p[k] = v
	if old ~= v then
		local s = rawget(o, "_propsig")[k]
		if s then s:Fire() end
		local ch = rawget(o, "_signals").Changed
		if ch then ch:Fire(k) end
	end
end
instmt.__tostring = function(o) return rawget(o, "_p").Name or rawget(o, "_p").ClassName end

function Inst.IsA(o, name) return isA(o.ClassName, name) end
function Inst.GetChildren(o) return table.clone(rawget(o, "_children")) end
function Inst.GetDescendants(o)
	local out = {}
	local function walk(x)
		for _, c in ipairs(rawget(x, "_children")) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(o)
	return out
end
function Inst.FindFirstChild(o, name, recursive)
	for _, c in ipairs(rawget(o, "_children")) do
		if c.Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(rawget(o, "_children")) do
			local f = c:FindFirstChild(name, true)
			if f then return f end
		end
	end
	return nil
end
function Inst.FindFirstChildOfClass(o, cls)
	for _, c in ipairs(rawget(o, "_children")) do
		if c.ClassName == cls then return c end
	end
	return nil
end
function Inst.FindFirstChildWhichIsA(o, cls, recursive)
	for _, c in ipairs(rawget(o, "_children")) do
		if c:IsA(cls) then return c end
	end
	if recursive then
		for _, c in ipairs(rawget(o, "_children")) do
			local f = c:FindFirstChildWhichIsA(cls, true)
			if f then return f end
		end
	end
	return nil
end
function Inst.FindFirstAncestor(o, name)
	local a = o.Parent
	while a do
		if a.Name == name then return a end
		a = a.Parent
	end
end
function Inst.FindFirstAncestorOfClass(o, cls)
	local a = o.Parent
	while a do
		if a.ClassName == cls then return a end
		a = a.Parent
	end
end
function Inst.FindFirstAncestorWhichIsA(o, cls)
	local a = o.Parent
	while a do
		if a:IsA(cls) then return a end
		a = a.Parent
	end
end
function Inst.IsDescendantOf(o, anc)
	local a = o.Parent
	while a do
		if a == anc then return true end
		a = a.Parent
	end
	return false
end
function Inst.IsAncestorOf(o, d) return d:IsDescendantOf(o) end
function Inst.WaitForChild(o, name, timeout)
	local c = o:FindFirstChild(name)
	if c then return c end
	local deadline = now + (timeout or 5)
	while now < deadline do
		task.wait(0.1)
		c = o:FindFirstChild(name)
		if c then return c end
	end
	if not timeout then table.insert(H.warnings, "Infinite yield possible on WaitForChild(" .. tostring(name) .. ") under " .. tostring(o.Name)) end
	return nil
end
function Inst.Destroy(o)
	if rawget(o, "_destroyed") then return end
	local s = rawget(o, "_signals").Destroying
	if s then s:Fire() end
	for _, c in ipairs(o:GetChildren()) do c:Destroy() end
	o.Parent = nil
	rawset(o, "_destroyed", true)
	local cs = H.CollectionService
	if cs then cs:_untagAll(o) end
end
function Inst.ClearAllChildren(o)
	for _, c in ipairs(o:GetChildren()) do c:Destroy() end
end
function Inst.Clone(o)
	local c = newInstance(o.ClassName)
	for k, v in pairs(rawget(o, "_p")) do
		if k ~= "Parent" then rawget(c, "_p")[k] = v end
	end
	for k, v in pairs(rawget(o, "_attrs")) do rawget(c, "_attrs")[k] = v end
	for _, ch in ipairs(rawget(o, "_children")) do
		local cc = ch:Clone()
		cc.Parent = c
	end
	return c
end
function Inst.GetFullName(o)
	local parts = {}
	local a = o
	while a and a.ClassName ~= "DataModel" do
		table.insert(parts, 1, a.Name)
		a = a.Parent
	end
	return table.concat(parts, ".")
end
function Inst.SetAttribute(o, k, v)
	local t = typeofv(v)
	local ok = {number = true, string = true, boolean = true, ["nil"] = true, Vector3 = true, Color3 = true, Vector2 = true, CFrame = true, UDim2 = true, UDim = true, NumberRange = true, ColorSequence = true, NumberSequence = true, BrickColor = true, Rect = true, EnumItem = true}
	if not ok[t] then error("SetAttribute: unsupported type " .. t .. " for " .. tostring(k), 2) end
	local old = rawget(o, "_attrs")[k]
	rawget(o, "_attrs")[k] = v
	if old ~= v then
		local s = rawget(o, "_attrsig")[k]
		if s then s:Fire() end
		local s2 = rawget(o, "_signals").AttributeChanged
		if s2 then s2:Fire(k) end
	end
end
function Inst.GetAttribute(o, k) return rawget(o, "_attrs")[k] end
function Inst.GetAttributes(o) return table.clone(rawget(o, "_attrs")) end
function Inst.GetAttributeChangedSignal(o, k)
	local s = rawget(o, "_attrsig")[k]
	if not s then
		s = Signal.new("Attr:" .. k)
		rawget(o, "_attrsig")[k] = s
	end
	return s
end
function Inst.GetPropertyChangedSignal(o, k)
	local s = rawget(o, "_propsig")[k]
	if not s then
		s = Signal.new("Prop:" .. k)
		rawget(o, "_propsig")[k] = s
	end
	return s
end
function Inst.GetTags(o) return H.CollectionService and H.CollectionService:_tagsOf(o) or {} end
function Inst.AddTag(o, t) H.CollectionService:AddTag(o, t) end
function Inst.RemoveTag(o, t) H.CollectionService:RemoveTag(o, t) end
function Inst.HasTag(o, t) return H.CollectionService:HasTag(o, t) end
-- PVInstance / Model / BasePart
function Inst.GetPivot(o)
	if o:IsA("BasePart") then return o.CFrame end
	local pp = o.PrimaryPart
	if pp then return pp.CFrame end
	for _, d in ipairs(o:GetDescendants()) do
		if d:IsA("BasePart") then return d.CFrame end
	end
	return rawget(o, "_p").WorldPivot or CFrame.new()
end
function Inst.PivotTo(o, cf)
	if o:IsA("BasePart") then o.CFrame = cf return end
	local cur = o:GetPivot()
	local delta = cf * cur:Inverse()
	for _, d in ipairs(o:GetDescendants()) do
		if d:IsA("BasePart") then d.CFrame = delta * d.CFrame end
	end
	rawget(o, "_p").WorldPivot = cf
end
function Inst.SetPrimaryPartCFrame(o, cf) o:PivotTo(cf) end
function Inst.GetPrimaryPartCFrame(o) return o:GetPivot() end
function Inst.MoveTo(o, pos)
	if o.ClassName == "Humanoid" then
		signalOf(o, "MoveToFinished")
		rawset(o, "_moveTarget", pos)
		return
	end
	o:PivotTo(CFrame.new(pos))
end
function Inst.ScaleTo(o, s) rawget(o, "_p").Scale = s end
function Inst.GetScale(o) return rawget(o, "_p").Scale or 1 end
function Inst.GetBoundingBox(o) return o:GetPivot(), V3(10, 10, 10) end
function Inst.GetExtentsSize(o) return V3(10, 10, 10) end
function Inst.SetNetworkOwner(o, plr) rawget(o, "_p")._owner = plr end
function Inst.SetNetworkOwnershipAuto(o) end
function Inst.GetNetworkOwner(o) return rawget(o, "_p")._owner end
function Inst.GetMass(o) return 10 end
function Inst.ApplyImpulse(o) end
function Inst.ApplyAngularImpulse(o) end
function Inst.GetTouchingParts(o) return {} end
function Inst.BreakJoints(o) end
-- effects / sounds / tweens / anims
function Inst.Emit(o, n) end
function Inst.Clear(o) end
function Inst.Play(o)
	if o.ClassName == "Tween" then
		local goals, target = rawget(o, "_goals"), rawget(o, "_target")
		for k, v in pairs(goals) do
			if not rawget(target, "_destroyed") then target[k] = v end
		end
		o.PlaybackState = Enum.PlaybackState.Completed
		local info = rawget(o, "_info")
		local rep = info and info.RepeatCount or 0
		if rep >= 0 then task.delay(info and info.Time or 0, function() signalOf(o, "Completed"):Fire(Enum.PlaybackState.Completed) end) end
		return
	end
	rawget(o, "_p").IsPlaying = true
	rawget(o, "_p").Playing = true
end
function Inst.Stop(o) rawget(o, "_p").IsPlaying = false rawget(o, "_p").Playing = false end
function Inst.Pause(o) rawget(o, "_p").IsPlaying = false end
function Inst.Resume(o) rawget(o, "_p").IsPlaying = true end
function Inst.Cancel(o) end
function Inst.AdjustSpeed(o) end
function Inst.LoadAnimation(o, anim)
	local t = newInstance("AnimationTrack")
	rawget(t, "_p").Animation = anim
	return t
end
-- Humanoid
function Inst.ChangeState(o, s) rawget(o, "_p")._state = s end
function Inst.GetState(o) return rawget(o, "_p")._state or Enum.HumanoidStateType.Running end
function Inst.SetStateEnabled(o) end
function Inst.TakeDamage(o, n) o.Health = o.Health - n end
function Inst.GetAppliedDescription(o) return newInstance("HumanoidDescription") end
function Inst.ApplyDescription(o) end
-- Seats
function Inst.Sit(seat, hum)
	rawset(seat, "_dummy", true)
	seat.Occupant = hum
	rawget(hum, "_p").SeatPart = seat
	rawget(hum, "_p").Sit = true
end
-- GUI
function Inst.CaptureFocus(o) end
function Inst.ReleaseFocus(o) end
function Inst.TweenPosition(o, pos) o.Position = pos return true end
function Inst.TweenSize(o, s) o.Size = s return true end
function Inst.TweenSizeAndPosition(o, s, p) o.Size = s o.Position = p return true end
-- Remotes / bindables
function Inst.FireServer(r, ...)
	if not H.clientPlayer then error("FireServer called outside a client", 2) end
	H.remoteLog[#H.remoteLog + 1] = {dir = "c2s", name = r.Name, args = table.pack(...)}
	signalOf(r, "OnServerEvent"):Fire(H.clientPlayer, H.copyArgs(...))
end
function Inst.FireClient(r, plr, ...)
	if type(plr) ~= "table" or not rawget(plr, "__instance") or plr.ClassName ~= "Player" then error("FireClient: argument 1 must be a Player", 2) end
	if H.remoteHook then H.remoteHook(r.Name, plr, ...) end
	if H.fast then
		if H.clientPlayer == plr then signalOf(r, "OnClientEvent"):Fire(H.copyArgs(...)) end
		return
	end
	H.remoteLog[#H.remoteLog + 1] = {dir = "s2c", name = r.Name, player = plr, args = table.pack(...)}
	H.checkRemoteArgs(r.Name, ...)
	if H.clientPlayer == plr then signalOf(r, "OnClientEvent"):Fire(H.copyArgs(...)) end
end
function Inst.FireAllClients(r, ...)
	if H.fast then
		if H.clientPlayer then signalOf(r, "OnClientEvent"):Fire(H.copyArgs(...)) end
		return
	end
	H.remoteLog[#H.remoteLog + 1] = {dir = "s2all", name = r.Name, args = table.pack(...)}
	H.checkRemoteArgs(r.Name, ...)
	if H.clientPlayer then signalOf(r, "OnClientEvent"):Fire(H.copyArgs(...)) end
end
function Inst.InvokeServer(r, ...)
	local f = rawget(r, "_p").OnServerInvoke
	if not f then error("OnServerInvoke not set for " .. r.Name, 2) end
	return f(H.clientPlayer, ...)
end
function Inst.Fire(b, ...) signalOf(b, "Event"):Fire(...) end
function Inst.Invoke(b, ...) local f = rawget(b, "_p").OnInvoke return f and f(...) end
-- Players
function Inst.Kick(plr, msg)
	rawget(plr, "_p")._kicked = msg or true
	H.removePlayer(plr)
end
function Inst.LoadCharacter(plr)
	local old = plr.Character
	if old then old:Destroy() end
	local char = newInstance("Model")
	char.Name = plr.Name
	local hrp = newInstance("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = V3(2, 2, 1)
	hrp.CFrame = CFrame.new(0, 5, 0)
	hrp.Parent = char
	local head = newInstance("Part")
	head.Name = "Head"
	head.Parent = char
	local hum = newInstance("Humanoid")
	hum.Parent = char
	char.PrimaryPart = hrp
	char.Parent = H.workspace
	plr.Character = char
	signalOf(plr, "CharacterAdded"):Fire(char)
	return char
end
function Inst.GetMouse(plr) return newInstance("Mouse") end
function Inst.GetRankInGroup() return 0 end
function Inst.IsInGroup() return false end
function Inst.GetNetworkPing() return 0.05 end
-- Sound service
function Inst.PlayLocalSound(o, s) end
-- Terrain
function Inst.FillBlock(o) end
function Inst.FillBall(o) end
function Inst.FillCylinder(o) end
function Inst.FillWedge(o) end
function Inst.ReplaceMaterial(o) end
function Inst.SetMaterialColor(o) end
function Inst.GetMaterialColor(o) return C3(0.5, 0.5, 0.5) end
function Inst.WorldToCellPreferSolid(o) return V3() end
-- Camera
function Inst.WorldToViewportPoint(cam, pos) return V3(640, 360, 10), true end
function Inst.WorldToScreenPoint(cam, pos) return V3(640, 360, 10), true end
function Inst.ViewportPointToRay(cam, x, y) return {Origin = cam.CFrame.p, Direction = cam.CFrame.LookVector} end
function Inst.ScreenPointToRay(cam, x, y) return {Origin = cam.CFrame.p, Direction = cam.CFrame.LookVector} end

function H.Instance_new(cls, parent)
	if type(cls) ~= "string" then error("Instance.new expects a class name", 2) end
	local o = newInstance(cls)
	if cls == "Tween" then rawset(o, "_goals", {}) end
	if parent then o.Parent = parent end
	return o
end
H.newInstance = newInstance

-- basic JSON (HttpService) with strict checks like Roblox
local function jsonEncode(v)
	local t = typeofv(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then error("Can't convert to JSON: " .. tostring(v)) end
		return string.format("%.14g", v)
	end
	if t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"' end
	if t == "table" then
		local n = #v
		local isArr = n > 0 or next(v) == nil
		if isArr then
			local parts = {}
			for i = 1, n do parts[i] = jsonEncode(v[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in pairs(v) do table.insert(parts, jsonEncode(tostring(k)) .. ":" .. jsonEncode(x)) end
		table.sort(parts)
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return '"' .. t .. '"'
end
H.jsonEncode = jsonEncode

-- DataStore values must be JSON-like: finite numbers, strings, booleans, and tables that are either
-- arrays (1..n, no holes) or dictionaries with string keys. Anything else fails like Roblox would.
local function checkStorable(v, path, seen)
	local t = typeofv(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return false, path .. " is not a finite number" end
		return true
	end
	if t == "string" or t == "boolean" or t == "nil" then return true end
	if t ~= "table" then return false, path .. " has unsupported type " .. t end
	seen = seen or {}
	if seen[v] then return false, path .. " is a cyclic table" end
	seen[v] = true
	local n, count, numKeys, strKeys = #v, 0, 0, 0
	for k, x in pairs(v) do
		count += 1
		if type(k) == "number" then numKeys += 1 elseif type(k) == "string" then strKeys += 1
		else return false, path .. " has a key of type " .. type(k) end
		local ok, err = checkStorable(x, path .. "." .. tostring(k), seen)
		if not ok then return false, err end
	end
	if numKeys > 0 and strKeys > 0 then return false, path .. " mixes number and string keys" end
	if numKeys > 0 and numKeys ~= n then return false, path .. " is an array with holes or non-sequential number keys" end
	seen[v] = nil
	return true
end
H.checkStorable = checkStorable
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in pairs(v) do o[k] = deepCopy(x) end
	return o
end
H.deepCopy = deepCopy

-- remote arguments are copied like Roblox serializes them: plain tables are copied, datatypes/instances kept
local function remoteCopy(v, depth)
	if type(v) ~= "table" or getmetatable(v) ~= nil or rawget(v, "__instance") or (depth or 0) > 20 then return v end
	local o = {}
	for k, x in pairs(v) do o[remoteCopy(k, (depth or 0) + 1)] = remoteCopy(x, (depth or 0) + 1) end
	return o
end
local function copyArgs(...)
	local a = table.pack(...)
	for i = 1, a.n do a[i] = remoteCopy(a[i]) end
	return table.unpack(a, 1, a.n)
end
H.copyArgs = copyArgs
-- remote arguments: tables sent to clients must be serializable too (no mixed tables, no functions)
function H.checkRemoteArgs(name, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		local v = args[i]
		if type(v) == "function" then table.insert(H.warnings, "remote " .. name .. " sent a function") end
		if type(v) == "table" and not rawget(v, "__instance") and not getmetatable(v) then
			local function scan(t, path, depth)
				if depth > 12 then return end
				local nk, sk = 0, 0
				for k, x in pairs(t) do
					if type(k) == "number" then nk += 1 elseif type(k) == "string" then sk += 1 end
					if type(x) == "function" then table.insert(H.warnings, "remote " .. name .. " sends a function at " .. path .. "." .. tostring(k)) end
					if type(x) == "number" and x ~= x then table.insert(H.warnings, "remote " .. name .. " sends NaN at " .. path .. "." .. tostring(k)) end
					if type(x) == "table" and not rawget(x, "__instance") and not getmetatable(x) then scan(x, path .. "." .. tostring(k), depth + 1) end
				end
				if nk > 0 and sk > 0 then table.insert(H.warnings, "remote " .. name .. " sends a mixed table at " .. path) end
			end
			scan(v, "arg" .. i, 0)
		end
	end
end

-- =====================================================================
-- SERVICES
-- =====================================================================
H.remoteLog = {}
local services = {}
local game = newInstance("DataModel")
rawget(game, "_p").Name = "Game"
H.game = game
local function service(name, cls)
	local s = services[name]
	if s then return s end
	s = newInstance(cls or name)
	rawget(s, "_p").Name = name
	rawget(s, "_p").Parent = game
	table.insert(rawget(game, "_children"), s)
	services[name] = s
	return s
end
function Inst.GetService(g, name)
	local s = services[name]
	if not s then error("mock: unsupported service " .. tostring(name), 2) end
	return s
end
Inst.FindService = Inst.GetService
H.bindToClose = {}
function Inst.BindToClose(g, fn) table.insert(H.bindToClose, fn) end
rawget(game, "_p").PlaceId = 1
rawget(game, "_p").GameId = 1
rawget(game, "_p").JobId = "test-job"
rawget(game, "_p").PlaceVersion = 1
rawget(game, "_p").CreatorId = 1
rawget(game, "_p").CreatorType = Enum.CreatorType.User

local Workspace = service("Workspace")
H.workspace = Workspace
rawget(game, "_p").Workspace = Workspace
local Terrain = newInstance("Terrain")
rawget(Terrain, "_p").Name = "Terrain"
Terrain.Parent = Workspace
rawget(Workspace, "_p").Terrain = Terrain
local Camera = newInstance("Camera")
Camera.Parent = Workspace
rawget(Workspace, "_p").CurrentCamera = Camera
rawget(Workspace, "_p").Gravity = 196.2
function Inst.Raycast(ws, origin, dir, params)
	if dir.Y < 0 and origin.Y >= 0 and origin.Y + dir.Y <= 0 then
		return {Position = V3(origin.X, 0, origin.Z), Normal = V3(0, 1, 0), Instance = Terrain, Material = Enum.Material.Grass, Distance = origin.Y}
	end
	return nil
end
function Inst.GetServerTimeNow() return 1700000000 + now end
function Inst.GetPartBoundsInRadius() return {} end
function Inst.GetPartBoundsInBox() return {} end
function Inst.GetPartsInPart() return {} end
function Inst.Blockcast() return nil end
function Inst.Spherecast() return nil end

service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
service("StarterGui")
service("StarterPack")
local StarterPlayer = service("StarterPlayer")
local SPS = newInstance("StarterPlayerScripts")
rawget(SPS, "_p").Name = "StarterPlayerScripts"
SPS.Parent = StarterPlayer
service("Lighting")
service("SoundService")
service("Debris")
function Inst.AddItem(d, item, t) task.delay(t or 10, function() if not rawget(item, "_destroyed") then item:Destroy() end end) end
local TweenService = service("TweenService")
function Inst.Create(ts, obj, info, goals)
	local t = newInstance("Tween")
	rawset(t, "_target", obj)
	rawset(t, "_goals", goals)
	rawset(t, "_info", info)
	return t
end
function Inst.GetValue(ts, alpha) return alpha end

local RunService = service("RunService")
function Inst.IsStudio() return H.studio end
function Inst.IsServer() return not H.clientPlayer end
function Inst.IsClient() return H.clientPlayer ~= nil end
function Inst.IsRunning() return true end
function Inst.BindToRenderStep() end
function Inst.UnbindFromRenderStep() end
H.heartbeatSignals = {signalOf(RunService, "Heartbeat"), signalOf(RunService, "RenderStepped"), signalOf(RunService, "Stepped"), signalOf(RunService, "PreSimulation"), signalOf(RunService, "PostSimulation")}

local CollectionService = service("CollectionService")
H.CollectionService = CollectionService
local tags = {}
function Inst.AddTag(cs, inst, tag)
	if cs ~= CollectionService then return H.CollectionService:AddTag(cs, inst) end
	tags[tag] = tags[tag] or {}
	if not table.find(tags[tag], inst) then
		table.insert(tags[tag], inst)
		signalOf(cs, "Added:" .. tag):Fire(inst)
	end
end
function Inst.RemoveTag(cs, inst, tag)
	if cs ~= CollectionService then return H.CollectionService:RemoveTag(cs, inst) end
	local l = tags[tag]
	local i = l and table.find(l, inst)
	if i then table.remove(l, i) end
end
function Inst.HasTag(cs, inst, tag)
	if cs ~= CollectionService then return H.CollectionService:HasTag(cs, inst) end
	return tags[tag] ~= nil and table.find(tags[tag], inst) ~= nil
end
function Inst.GetTagged(cs, tag)
	local out = {}
	for _, i in ipairs(tags[tag] or {}) do
		if not rawget(i, "_destroyed") then table.insert(out, i) end
	end
	return out
end
function Inst.GetInstanceAddedSignal(cs, tag) return signalOf(cs, "Added:" .. tag) end
function Inst.GetInstanceRemovedSignal(cs, tag) return signalOf(cs, "Removed:" .. tag) end
function Inst._untagAll(cs, inst)
	for tag, l in pairs(tags) do
		local i = table.find(l, inst)
		if i then
			table.remove(l, i)
			signalOf(cs, "Removed:" .. tag):Fire(inst)
		end
	end
end
function Inst._tagsOf(cs, inst)
	local out = {}
	for tag, l in pairs(tags) do
		if table.find(l, inst) then table.insert(out, tag) end
	end
	return out
end
H.tagCount = function(tag) return #CollectionService:GetTagged(tag) end

-- DataStores
local DataStoreService = service("DataStoreService")
H.stores = {}
H.dsWrites = 0
local function makeStore(name, ordered)
	local st = newInstance(ordered and "OrderedDataStore" or "DataStore")
	rawget(st, "_p").Name = name
	rawset(st, "_data", {})
	return st
end
function Inst.GetDataStore(ds, name, scope)
	local key = name .. "/" .. (scope or "global")
	H.stores[key] = H.stores[key] or makeStore(name, false)
	return H.stores[key]
end
function Inst.GetOrderedDataStore(ds, name, scope)
	local key = "ordered:" .. name .. "/" .. (scope or "global")
	H.stores[key] = H.stores[key] or makeStore(name, true)
	return H.stores[key]
end
function Inst.GetRequestBudgetForRequestType() return 100 end
function Inst.GetAsync(st, key)
	if H.dsFail or H.dsReadFail then error("mock DataStore: GetAsync failed (simulated outage)") end
	task.wait(0.05)
	return deepCopy(rawget(st, "_data")[key])
end
function Inst.SetAsync(st, key, value)
	if H.dsFail then error("mock DataStore: SetAsync failed (simulated outage)") end
	if type(key) ~= "string" or #key > 50 then error("mock DataStore: bad key " .. tostring(key)) end
	local ok, err = checkStorable(value, key)
	if not ok then error("mock DataStore: cannot store value: " .. err) end
	if st.ClassName == "OrderedDataStore" and (type(value) ~= "number" or value ~= math.floor(value)) then error("mock OrderedDataStore: value must be an integer") end
	H.dsWrites += 1
	task.wait(0.05)
	rawget(st, "_data")[key] = deepCopy(value)
end
function Inst.UpdateAsync(st, key, fn)
	if H.dsFail then error("mock DataStore: UpdateAsync failed (simulated outage)") end
	local old = deepCopy(rawget(st, "_data")[key])
	local new = fn(old)
	if new == nil then return old end
	local ok, err = checkStorable(new, key)
	if not ok then error("mock DataStore: cannot store value: " .. err) end
	if st.ClassName == "OrderedDataStore" and (type(new) ~= "number" or new ~= math.floor(new)) then error("mock OrderedDataStore: value must be an integer") end
	H.dsWrites += 1
	task.wait(0.05)
	rawget(st, "_data")[key] = deepCopy(new)
	return deepCopy(new)
end
function Inst.IncrementAsync(st, key, delta)
	return st:UpdateAsync(key, function(old) return (old or 0) + (delta or 1) end)
end
function Inst.RemoveAsync(st, key)
	if H.dsFail then error("mock DataStore: RemoveAsync failed") end
	local old = rawget(st, "_data")[key]
	rawget(st, "_data")[key] = nil
	return old
end
function Inst.GetSortedAsync(st, ascending, pageSize, minValue, maxValue)
	if H.dsFail then error("mock DataStore: GetSortedAsync failed") end
	local list = {}
	for k, v in pairs(rawget(st, "_data")) do
		if (not minValue or v >= minValue) and (not maxValue or v <= maxValue) then table.insert(list, {key = k, value = v}) end
	end
	table.sort(list, function(a, b) if ascending then return a.value < b.value end return a.value > b.value end)
	local page = {}
	for i = 1, math.min(pageSize or 50, #list) do page[i] = list[i] end
	local pages = newInstance("DataStorePages")
	rawget(pages, "_p").IsFinished = true
	rawset(pages, "_page", page)
	return pages
end
function Inst.GetCurrentPage(p) return rawget(p, "_page") end
function Inst.AdvanceToNextPageAsync(p) rawset(p, "_page", {}) end

local MarketplaceService = service("MarketplaceService")
H.ownedPasses = {}
H.passPrompts = {}
function Inst.UserOwnsGamePassAsync(ms, userId, id) return H.ownedPasses[userId .. ":" .. id] == true end
function Inst.PromptGamePassPurchase(ms, plr, id) table.insert(H.passPrompts, {plr = plr, id = id}) end
function Inst.PromptProductPurchase(ms, plr, id) table.insert(H.passPrompts, {plr = plr, id = id, product = true}) end
function Inst.GetProductInfo(ms, id) return {Name = "Pass", PriceInRobux = 99} end

local TextService = service("TextService")
-- like Roblox's filter: blocked words come back as ####; H.filterFail makes the service fail (as it can live)
H.blockedWords = {"badword", "scamlink"}
function Inst.FilterStringAsync(ts, text, uid)
	if H.filterFail then error("TextService unavailable (simulated)") end
	local out = text
	for _, w in ipairs(H.blockedWords) do
		out = string.gsub(out, w, string.rep("#", #w))
	end
	local r = newInstance("TextFilterResult")
	rawset(r, "_text", out)
	return r
end
function Inst.GetNonChatStringForBroadcastAsync(r) return rawget(r, "_text") end
function Inst.GetNonChatStringForUserAsync(r) return rawget(r, "_text") end
function Inst.GetTextSize(ts, text, size) return V2(#text * size * 0.5, size) end

local HttpService = service("HttpService")
function Inst.JSONEncode(hs, v) return jsonEncode(v) end
function Inst.JSONDecode(hs, s)
	local i = 1
	local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
	local value
	local function str()
		i += 1
		local out = {}
		while true do
			local c = s:sub(i, i)
			if c == '"' then i += 1 break end
			if c == "\\" then
				local n = s:sub(i + 1, i + 1)
				if n == "u" then
					local code = tonumber(s:sub(i + 2, i + 5), 16)
					table.insert(out, utf8.char(code))
					i += 6
				else
					table.insert(out, ({n = "\n", t = "\t", r = "\r", b = "\b", f = "\f"})[n] or n)
					i += 2
				end
			elseif c == "" then error("bad json string")
			else
				table.insert(out, c)
				i += 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = s:sub(i, i)
		if c == "{" then
			i += 1
			local t = {}
			ws()
			if s:sub(i, i) == "}" then i += 1 return t end
			while true do
				ws()
				local k = str()
				ws()
				assert(s:sub(i, i) == ":", "json: expected :")
				i += 1
				t[k] = value()
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "}" then return t end
				assert(d == ",", "json: expected ,")
			end
		elseif c == "[" then
			i += 1
			local t = {}
			ws()
			if s:sub(i, i) == "]" then i += 1 return t end
			while true do
				table.insert(t, value())
				ws()
				local d = s:sub(i, i)
				i += 1
				if d == "]" then return t end
				assert(d == ",", "json: expected , in array")
			end
		elseif c == '"' then return str()
		elseif s:sub(i, i + 3) == "true" then i += 4 return true
		elseif s:sub(i, i + 4) == "false" then i += 5 return false
		elseif s:sub(i, i + 3) == "null" then i += 4 return nil
		else
			local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
			assert(num and #num > 0, "json: bad value at " .. i)
			i += #num
			return tonumber(num)
		end
	end
	return value()
end
local guid = 0
function Inst.GenerateGUID(hs, braces) guid += 1 return string.format("%08d-0000-0000-0000-000000000000", guid) end

local MessagingService = service("MessagingService")
function Inst.PublishAsync() end
function Inst.SubscribeAsync() return {Disconnect = function() end} end

service("UserInputService")
local UIS = services.UserInputService
rawget(UIS, "_p").TouchEnabled = false
rawget(UIS, "_p").KeyboardEnabled = true
rawget(UIS, "_p").GamepadEnabled = false
rawget(UIS, "_p").MouseEnabled = true
H.keysDown = {}
function Inst.IsKeyDown(u, key) return H.keysDown[key] == true end
function Inst.IsGamepadButtonDown(u, pad, key) return H.keysDown[key] == true end
function Inst.IsMouseButtonPressed() return false end
function Inst.GetLastInputType() return Enum.UserInputType.Keyboard end
function Inst.GetConnectedGamepads() return {} end
function Inst.GetFocusedTextBox() return nil end
function Inst.GetMouseLocation() return V2(0, 0) end
service("ContextActionService")
H.boundActions = {}
function Inst.BindAction(cas, name, fn, touch, ...) H.boundActions[name] = {fn = fn, touch = touch, inputs = {...}} end
function Inst.BindActionAtPriority(cas, name, fn, touch, prio, ...) H.boundActions[name] = {fn = fn, touch = touch, inputs = {...}} end
function Inst.UnbindAction(cas, name) H.boundActions[name] = nil end
function Inst.GetButton(cas, name) return nil end
function Inst.SetTitle() end
function Inst.SetDescription() end
function Inst.SetImage() end
function Inst.SetPosition() end
service("GuiService")
function Inst.SetCoreGuiEnabled() end
function Inst.SetCore() end
function Inst.GetCore() return nil end
function Inst.GetGuiInset() return V2(0, 36), V2(0, 0) end
service("SocialService")
service("TeleportService")
service("PhysicsService")
function Inst.RegisterCollisionGroup() end
function Inst.CollisionGroupSetCollidable() end
service("PathfindingService")
service("BadgeService")
function Inst.AwardBadge() return true end
function Inst.UserHasBadgeAsync() return false end
service("LocalizationService")
service("AnalyticsService")
function Inst.LogCustomEvent() end
function Inst.LogProgressionEvent() end
function Inst.LogEconomyEvent() end

-- Players
local Players = service("Players")
H.Players = Players
rawget(Players, "_p").CharacterAutoLoads = true
rawget(Players, "_p").MaxPlayers = 4
function Inst.GetPlayers(ps)
	local out = {}
	for _, c in ipairs(rawget(ps, "_children")) do
		if c.ClassName == "Player" then table.insert(out, c) end
	end
	return out
end
function Inst.GetPlayerByUserId(ps, id)
	for _, p in ipairs(ps:GetPlayers()) do
		if p.UserId == id then return p end
	end
	return nil
end
function Inst.GetPlayerFromCharacter(ps, char)
	for _, p in ipairs(ps:GetPlayers()) do
		if p.Character == char then return p end
	end
	return nil
end
function Inst.GetUserThumbnailAsync() return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", true end
-- usernames <-> UserIds: players in the server, plus H.knownUsers[name] = id for accounts that aren't here
H.knownUsers = {}
function Inst.GetNameFromUserIdAsync(ps, id)
	for _, p in ipairs(ps:GetPlayers()) do if p.UserId == id then return p.Name end end
	for name, uid in pairs(H.knownUsers) do if uid == id then return name end end
	return "User" .. id
end
function Inst.GetUserIdFromNameAsync(ps, name)
	for _, p in ipairs(ps:GetPlayers()) do if string.lower(p.Name) == string.lower(name) then return p.UserId end end
	for n, uid in pairs(H.knownUsers) do if string.lower(n) == string.lower(name) then return uid end end
	error("HTTP 400 (Bad Request): user not found")
end
function H.addPlayer(name, userId)
	local p = newInstance("Player")
	rawget(p, "_p").Name = name
	rawget(p, "_p").UserId = userId
	rawget(p, "_p").DisplayName = name
	local gui = newInstance("PlayerGui")
	rawget(gui, "_p").Name = "PlayerGui"
	gui.Parent = p
	local ps = newInstance("PlayerScripts")
	rawget(ps, "_p").Name = "PlayerScripts"
	ps.Parent = p
	p.Parent = Players
	signalOf(Players, "PlayerAdded"):Fire(p)
	return p
end
function H.removePlayer(p)
	if not p.Parent then return end
	signalOf(Players, "PlayerRemoving"):Fire(p)
	task.wait(0.03)
	if p.Character then p.Character:Destroy() end
	p.Parent = nil
end

-- =====================================================================
-- GLOBALS + MODULE LOADING
-- =====================================================================
local G = {}
H.G = G
G.game = game
G.workspace = Workspace
G.Workspace = Workspace
G.Instance = {new = H.Instance_new, fromExisting = function(o) return o:Clone() end}
G.Vector3, G.Vector2, G.CFrame, G.Color3, G.UDim, G.UDim2 = Vector3, Vector2, CFrame, Color3, UDim, UDim2
G.NumberRange, G.NumberSequence, G.NumberSequenceKeypoint = NumberRange, NumberSequence, NumberSequenceKeypoint
G.ColorSequence, G.ColorSequenceKeypoint, G.TweenInfo, G.PhysicalProperties = ColorSequence, ColorSequenceKeypoint, TweenInfo, PhysicalProperties
G.Rect, G.Ray, G.BrickColor, G.Region3, G.RaycastParams, G.OverlapParams, G.Random, G.Enum = Rect, Ray, BrickColor, Region3, RaycastParams, OverlapParams, Random, Enum
G.Font = {new = function(f, w, s) return {Family = f, Weight = w, Style = s} end, fromEnum = function(e) return {Family = tostring(e)} end}
G.DateTime = {now = function() return {UnixTimestamp = 1700000000 + math.floor(now), UnixTimestampMillis = (1700000000 + now) * 1000, FormatUniversalTime = function(self, f) return "2026-09-30" end, ToUniversalTime = function() return {Year = 2026, Month = 9, Day = 30, Hour = 0, Minute = 0, Second = 0} end} end,
	fromUnixTimestamp = function(t) return {UnixTimestamp = t, FormatUniversalTime = function() return "2026" end} end}
G.typeof = typeofv
G.task = task
G.wait = task.wait
G.delay = task.delay
G.spawn = task.spawn
G.tick = function() return 1700000000 + now end
G.time = function() return now end
G.elapsedTime = function() return now end
G.warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	local msg = table.concat(parts, " ")
	table.insert(H.warnings, msg)
	if not H.quiet then print("[warn] " .. msg) end
end
G.print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	table.insert(H.prints, table.concat(parts, " "))
	if not H.quiet then print(table.concat(parts, " ")) end
end
G.os = setmetatable({clock = function() return now end, time = function(t) if t then return os.time(t) end return 1700000000 + math.floor(now) end,
	date = function(f, t) return os.date(f, t or (1700000000 + math.floor(now))) end}, {__index = os})
G.shared = {}
G.utf8 = utf8
G.debug = debug
G.bit32 = bit32
G.buffer = buffer
G.vector = vector
G.math, G.string, G.table, G.coroutine = table.clone(math), string, table, coroutine  -- math is a writable copy so tests can pin math.random
G.pairs, G.ipairs, G.next, G.select, G.type, G.tostring, G.tonumber = pairs, ipairs, next, select, type, tostring, tonumber
G.pcall, G.xpcall, G.error, G.assert, G.setmetatable, G.getmetatable, G.rawget, G.rawset, G.rawequal, G.rawlen, G.unpack =
	pcall, xpcall, error, assert, setmetatable, getmetatable, rawget, rawset, rawequal, rawlen, table.unpack
G.newproxy = newproxy
G.gcinfo = gcinfo
G.settings = function() return {} end
G.UserSettings = function() return {GameSettings = {}} end

local moduleCache = {}
local function makeEnv(scriptInst)
	return setmetatable({script = scriptInst}, {__index = G})
end
function G.require(m)
	if type(m) ~= "table" or not rawget(m, "__instance") or m.ClassName ~= "ModuleScript" then error("require: expected a ModuleScript", 2) end
	if moduleCache[m] ~= nil then return moduleCache[m] end
	local src = rawget(m, "_source")
	local fn, err = loadstring(src, "=" .. m:GetFullName())
	if not fn then error("syntax error in " .. m:GetFullName() .. ": " .. tostring(err), 2) end
	setfenv(fn, makeEnv(m))
	local result = fn()
	if type(result) == "function" then
		-- capture the shared state table each module receives, so tests can inspect it
		local inner = result
		local isServer = m:IsDescendantOf(services.ServerScriptService)
		result = function(C, ...)
			if isServer then H.serverC = C else H.clientC = C end
			return inner(C, ...)
		end
	end
	moduleCache[m] = result
	return result
end
function H.runScript(scriptInst)
	local src = rawget(scriptInst, "_source")
	local fn, err = loadstring(src, "=" .. scriptInst:GetFullName())
	if not fn then error("syntax error in " .. scriptInst:GetFullName() .. ": " .. tostring(err)) end
	setfenv(fn, makeEnv(scriptInst))
	task.spawn(fn)
end
function H.makeScript(cls, name, source, parent)
	local s = newInstance(cls)
	rawget(s, "_p").Name = name
	rawset(s, "_source", source)
	s.Parent = parent
	return s
end
function H.service(name) return services[name] end

-- start a client for `plr`: LocalPlayer is set and client remote events are delivered to this player
function H.startClient(plr, clientScript)
	H.clientPlayer = plr
	rawget(Players, "_p").LocalPlayer = plr
	H.runScript(clientScript)
end

-- tiny assertion helpers
H.passed, H.failed = 0, 0
function H.check(cond, msg)
	if cond then
		H.passed += 1
		print("  PASS  " .. msg)
	else
		H.failed += 1
		print("  FAIL  " .. msg)
	end
	return cond
end
function H.section(name) print("\n== " .. name .. " ==") end
function H.approx(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

return H
