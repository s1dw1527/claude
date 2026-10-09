-- EMPIRE PLAZA (v12): a monument on the beach where a tiny starter lemonade stand sits next to a giant golden tower,
-- with two Hall of Fame billboards that show the richest empires. Built once at start; the billboard text is
-- refreshed by Empire.lua through C.updateHallBoard(list). Anybody can walk up and open the Empire Hall.
return function(C)
local V3, CF, RGB, MAT = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local F, R = C.F, C.R
local P, cyl, ball, surfaceText = C.P, C.cyl, C.ball, C.surfaceText
local SOLID = {CanCollide = true}

local AT = V3(0, 0, 395)     -- the beach strip z 350-440, x +-120 is the one free site in the city
C.PLAZA_AT = AT
C.reserve(AT.X - 70, AT.Z - 42, AT.X + 70, AT.Z + 42)
local GOLD, STONE = RGB(255, 205, 60), RGB(226, 222, 212)

local plaza = Instance.new("Model")
plaza.Name = "EmpirePlaza"
plaza.Parent = C.WORLD

-- the paved square, with a gold ring
P(plaza, V3(130, 0.8, 76), CF(AT + V3(0, 0.4, 0)), STONE, MAT.Marble, SOLID)
P(plaza, V3(124, 0.2, 70), CF(AT + V3(0, 0.85, 0)), RGB(205, 200, 190), MAT.Slate, {CanCollide = false})
cyl(plaza, 0.3, 46, CF(AT + V3(0, 0.95, 4)), GOLD, MAT.Metal, {CanCollide = false})

-- the title arch
for _, sx in ipairs({-17, 17}) do P(plaza, V3(3, 18, 3), CF(AT + V3(sx, 9, -33)), RGB(40, 40, 52), MAT.Metal, SOLID) end
local arch = P(plaza, V3(40, 6, 2), CF(AT + V3(0, 19, -33)), RGB(18, 18, 28), MAT.SmoothPlastic, SOLID)
for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do surfaceText(arch, face, "👑 EMPIRE PLAZA", GOLD) end

-- THE THUMBNAIL MOMENT: a tiny starter stand on the left, a gigantic golden tower on the right
do
	local s = AT + V3(-26, 0, 6)
	P(plaza, V3(7, 0.5, 6), CF(s + V3(0, 1.1, 0)), RGB(190, 150, 100), MAT.Wood, SOLID)
	P(plaza, V3(6, 3, 0.6), CF(s + V3(0, 2.8, -2.6)), RGB(255, 235, 120), MAT.SmoothPlastic, SOLID)
	P(plaza, V3(7.4, 0.6, 6.4), CF(s + V3(0, 4.7, 0)), RGB(255, 235, 60), MAT.Fabric, SOLID)
	local sign = P(plaza, V3(5, 1.4, 0.3), CF(s + V3(0, 5.6, 2.9)), RGB(255, 255, 255), MAT.SmoothPlastic, {CanCollide = false})
	surfaceText(sign, Enum.NormalId.Front, "🍋 DAY ONE", RGB(220, 150, 20))
	ball(plaza, V3(1.3, 1.3, 1.3), CF(s + V3(2.2, 2.2, 1.4)), RGB(255, 235, 60), MAT.SmoothPlastic)
	local tag = P(plaza, V3(7, 1.6, 0.4), CF(s + V3(0, 0.9, 7)), RGB(40, 40, 52), MAT.SmoothPlastic, {CanCollide = false})
	surfaceText(tag, Enum.NormalId.Front, "$0", RGB(120, 230, 150))

	local t = AT + V3(22, 0, 6)
	P(plaza, V3(22, 2, 22), CF(t + V3(0, 1, 0)), RGB(60, 60, 72), MAT.Granite, SOLID)
	local h = 0
	for i, w in ipairs({18, 16, 14, 12, 10, 8, 6}) do
		local fh = 14
		P(plaza, V3(w, fh, w), CF(t + V3(0, 2 + h + fh / 2, 0)), i % 2 == 0 and RGB(235, 205, 90) or RGB(250, 220, 110), MAT.Metal, SOLID)
		P(plaza, V3(w + 0.4, 1, w + 0.4), CF(t + V3(0, 2 + h + fh, 0)), GOLD, MAT.Metal, SOLID)
		h += fh
	end
	P(plaza, V3(0.6, 14, 0.6), CF(t + V3(0, 2 + h + 7, 0)), GOLD, MAT.Metal, SOLID)
	local top = ball(plaza, V3(5, 5, 5), CF(t + V3(0, 2 + h + 16, 0)), RGB(255, 245, 160), MAT.Neon)
	local L = Instance.new("PointLight") L.Range = 90 L.Brightness = 3 L.Color = GOLD L.Parent = top
	local tag2 = P(plaza, V3(14, 3, 0.4), CF(t + V3(0, 6, -11.3)), RGB(18, 18, 28), MAT.SmoothPlastic, {CanCollide = false})
	surfaceText(tag2, Enum.NormalId.Back, "$1,000,000,000", GOLD)
	-- the lights stay on at night
	for i = 1, 4 do
		local a = i * math.pi / 2
		P(plaza, V3(1, 2, 1), CF(t + V3(math.cos(a) * 13, 2.8, math.sin(a) * 13)), GOLD, MAT.Neon, {CanCollide = false})
	end
end

-- HALL OF FAME billboards (front and back of each board show the same list)
local boards = {}
local function board(x, yaw)
	local b = P(plaza, V3(30, 22, 1.5), CF(AT + V3(x, 15, -20)) * CFrame.Angles(0, yaw, 0), RGB(14, 16, 28), MAT.SmoothPlastic, SOLID)
	P(plaza, V3(2, 6, 2), CF(AT + V3(x, 3, -20)), RGB(40, 40, 52), MAT.Metal, SOLID)
	local face = surfaceText(b, Enum.NormalId.Front, "🏆 HALL OF FAME", GOLD)
	face.Font = Enum.Font.GothamBold
	face.TextXAlignment = Enum.TextXAlignment.Left
	face.TextScaled = false
	face.TextSize = 22
	face.TextWrapped = true
	table.insert(boards, face)
	return b
end
board(-40, 0)
board(40, 0)

local function fmtMoney(v)
	v = tonumber(v) or 0
	if v >= 1e9 then return string.format("$%.2fB", v / 1e9) end
	if v >= 1e6 then return string.format("$%.1fM", v / 1e6) end
	if v >= 1e3 then return string.format("$%.0fK", v / 1e3) end
	return "$" .. math.floor(v)
end
C.fmtEmpire = fmtMoney
function C.updateHallBoard(list)
	local lines = {"🏆 HALL OF FAME — richest empires"}
	for i, row in ipairs(list or {}) do
		if i > 8 then break end
		local tags = (type(row.tags) == "string" and row.tags ~= "") and (" " .. row.tags) or ""
		table.insert(lines, string.format("%d. %s  %s  — %s%s", row.rank, row.icon or "🏪", row.biz or "Empire", fmtMoney(row.value), tags))
		table.insert(lines, "     by " .. tostring(row.name))
	end
	if #lines == 1 then table.insert(lines, "Be the first on the board!") end
	local text = table.concat(lines, "\n")
	for _, l in ipairs(boards) do l.Text = text end
end
C.updateHallBoard({})

-- walk up to the plinth to open the Empire Hall (rankings, milestones, visit buttons)
local plinth = P(plaza, V3(6, 3, 6), CF(AT + V3(0, 1.5, -8)), RGB(50, 50, 64), MAT.Marble, SOLID)
surfaceText(plinth, Enum.NormalId.Front, "EMPIRE HALL", GOLD)
C.prompt(plinth, "Open the Empire Hall 👑", "Empire Hall", 14, 0.2, function(plr)
	if C.ACTIONS.empInfo then C.ACTIONS.empInfo(plr) end
end)
end
