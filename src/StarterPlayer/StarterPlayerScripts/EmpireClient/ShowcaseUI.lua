-- SHOWCASE UI (v16): the 🪪 profile card. Anyone's (from the park visit list) or your own (from the Roadmap),
-- with what the server lets everyone see: empire stage, businesses, net-worth tier, park rating, prestige,
-- paths, and the title + badge being worn. On your own card you choose which title and badge to wear.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, card, clear, stroke = C.new, C.label, C.button, C.card, C.clear, C.stroke
local play, SND, act, R = C.play, C.SND, C.act, C.R
local GOLD, GREEN, GRAY, BLUE, WHITE, SUB = C.GOLD, C.GREEN, C.GRAY, C.BLUE, C.WHITE, C.SUB
local modal = C.makeModal
if not modal then return end
local SU = {info = nil}
C.ShowcaseUI = SU
local NAVY = RGB(18, 24, 48)

local function txt(parent, text, pos, size, px, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = px or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
local function btn(parent, text, size, color, fn, name, order)
	local b = button({Size = size, Text = text, TextSize = 12, TextWrapped = true, BackgroundColor3 = color or BLUE, LayoutOrder = order}, parent)
	if name then b.Name = name end
	b.MouseButton1Click:Connect(function() play(SND.click) fn(b) end)
	return b
end

local m = modal("showcase", "🪪  SHOWCASE", 520, 600)
local function render()
	local s = SU.info
	clear(m.body)
	if type(s) ~= "table" then return end
	local top = card(m.body, 150, 1, NAVY)
	stroke(top, GOLD, 2, 0.2)
	txt(top, string.upper(s.name), UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 26), 20, GOLD, true)
	txt(top, (s.title or "No title worn") .. (s.badge and ("   •   " .. s.badge) or ""), UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 20), 13, WHITE, true)
	local lines = {"🗺️ " .. s.stageName .. " (stage " .. s.stage .. "/7)", "🏪 " .. s.businesses .. " businesses   •   " .. s.worth,
		"🌟 " .. s.prestige .. " prestige stars" .. (s.park and ("   •   🎢 park ⭐ " .. s.park) or "")}
	txt(top, table.concat(lines, "\n"), UDim2.fromOffset(14, 64), UDim2.new(1, -28, 0, 80), 12, SUB)
	local pc = card(m.body, 30 + #s.paths * 22, 2)
	local pl = {}
	for _, p in ipairs(s.paths) do table.insert(pl, p.icon .. " " .. p.name .. ": Lv " .. p.level .. " " .. p.title) end
	txt(pc, table.concat(pl, "\n"), UDim2.fromOffset(14, 10), UDim2.new(1, -28, 1, -16), 12, WHITE)
	local w = s.wardrobe
	if type(w) == "table" then
		for k, kind in ipairs({"title", "badge"}) do
			local list = kind == "title" and w.titles or w.badges
			local h = card(m.body, 30, 10 + k * 10, RGB(26, 28, 40))
			txt(h, kind == "title" and "👑 WEAR A TITLE" or "🏅 WEAR A BADGE", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 20), 13, GOLD, true)
			local row = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 11 + k * 10}, m.body)
			new("UIGridLayout", {CellSize = UDim2.fromOffset(160, 36), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, row)
			if #list == 0 then
				txt(row, kind == "title" and "Earn titles from paths, Roadmap stages and the 7-day streak." or "Earn badges from weekly challenges.", UDim2.new(), UDim2.fromOffset(320, 36), 11, SUB)
			end
			for i, it in ipairs(list) do
				local on = w[kind] == it.key
				btn(row, (on and "✅ " or "") .. it.name, UDim2.fromOffset(160, 36), on and GREEN or BLUE, function() act("wear", kind, on and "" or it.key) end, "Wear_" .. kind .. "_" .. it.key, i)
			end
		end
	end
end
SU.render = render
m.update = function() end
function C.openShowcase(userId)
	SU.info = nil
	C.openModal("showcase", true)
	act("showcase", userId)
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "showcase" and type(a) == "table" then
		SU.info = a
		if m.frame.Visible then render() end
	end
end)
end
