-- VIRAL APP (phone): your Viral Score, your moments, the city's trending moments, influencer sightings,
-- the funniest recent events, top CityBuzz posts and the weekly Most Viral leaderboards.
return function(C)
local RGB = Color3.fromRGB
local new, label, button, corner, clear = C.new, C.label, C.button, C.corner, C.clear
local fmt, play, SND = C.fmt, C.play, C.SND
local GOLD, WHITE, SUB, CARD, GRAY = C.GOLD, C.WHITE, C.SUB, C.CARD, C.GRAY
local kit = C.phoneKit
if not kit then return end

local view = kit.makeView("viral")
kit.topBar(view, "🔥 Viral", RGB(255, 90, 60))
-- score header
local head = new("Frame", {Position = UDim2.fromOffset(4, 44), Size = UDim2.new(1, -8, 0, 74), BackgroundColor3 = RGB(60, 20, 30), BorderSizePixel = 0, ZIndex = 22}, view)
corner(head, 12)
label({Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 14), TextSize = 11, TextColor3 = SUB, Text = "YOUR VIRAL SCORE", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23}, head)
local scoreL = label({Position = UDim2.fromOffset(10, 18), Size = UDim2.new(1, -20, 0, 30), TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = RGB(255, 150, 90),
	TextXAlignment = Enum.TextXAlignment.Left, Text = "🔥 0", ZIndex = 23}, head)
local mentionL = label({Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 0, 18), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 23}, head)
-- tabs
local tab = "me"
local tabs = {}
local tabBar = new("Frame", {Position = UDim2.fromOffset(4, 122), Size = UDim2.new(1, -8, 0, 28), BackgroundTransparency = 1, ZIndex = 22}, view)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, tabBar)
local list = kit.scroller(view, 154)
local render
for _, t in ipairs({{"me", "⭐ Me"}, {"city", "🏙️ City"}, {"boards", "🏆 Weekly"}}) do
	local b = button({Size = UDim2.new(1 / 3, -3, 1, 0), Text = t[2], TextSize = 12, BackgroundColor3 = GRAY, ZIndex = 23}, tabBar)
	tabs[t[1]] = b
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		tab = t[1]
		render()
	end)
end
local function ago(t)
	local s = math.max(0, os.time() - (tonumber(t) or os.time()))
	if s < 60 then return "just now" end
	if s < 3600 then return math.floor(s / 60) .. "m ago" end
	if s < 86400 then return math.floor(s / 3600) .. "h ago" end
	return math.floor(s / 86400) .. "d ago"
end
local order = 0
local function section(text)
	order += 1
	label({Size = UDim2.new(1, 0, 0, 20), Text = text, TextSize = 12, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 23}, list)
end
local function row(icon, title, sub, right, color)
	order += 1
	local f = new("Frame", {Size = UDim2.new(1, 0, 0, sub and 46 or 30), BackgroundColor3 = color or CARD, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 22}, list)
	corner(f, 8)
	label({Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0, 26, 1, 0), Text = icon or "🔥", TextSize = 16, ZIndex = 23}, f)
	label({Position = UDim2.fromOffset(32, 3), Size = UDim2.new(1, -96, 0, 16), Text = title, TextSize = 12, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23}, f)
	if sub then
		label({Position = UDim2.fromOffset(32, 19), Size = UDim2.new(1, -40, 0, 26), Text = sub, TextSize = 10, TextColor3 = SUB, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23}, f)
	end
	if right then
		label({AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 3), Size = UDim2.fromOffset(64, 16), Text = right, TextSize = 11, TextColor3 = RGB(255, 150, 90),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23}, f)
	end
	return f
end
local function empty(text) row("💤", text, nil, nil, RGB(30, 32, 46)) end

function render()
	local v = C.S and C.S.viral
	for k, b in pairs(tabs) do b.BackgroundColor3 = k == tab and RGB(255, 90, 60) or GRAY end
	clear(list)
	order = 0
	if not v then
		empty("Loading...")
		return
	end
	scoreL.Text = "🔥 " .. fmt(v.score)
	mentionL.Text = "Your empire has been mentioned " .. v.mentions .. " time" .. (v.mentions == 1 and "" or "s") .. " • this week: 🔥 " .. fmt(v.week)
	if tab == "me" then
		section("📈 YOUR RECENT MOMENTS")
		if #v.mine == 0 then empty("Nothing yet. Go make some noise in the city!") end
		for _, m in ipairs(v.mine) do row(m.icon, m.title, m.text .. "  • " .. ago(m.t), "+" .. m.score) end
		section("🏅 HALL OF FAME (top 3 weekly finishes)")
		if #v.hall == 0 then empty("Finish top 3 on a weekly Viral board to get in here.") end
		for _, h in ipairs(v.hall) do row(({"🥇", "🥈", "🥉"})[h.rank] or "🏅", h.name, "Week " .. tostring(h.week)) end
	elseif tab == "city" then
		section("🚨 INFLUENCER SIGHTINGS")
		if #v.sightings == 0 then empty("No sightings yet. They show up when you least expect it.") end
		for _, s in ipairs(v.sightings) do row(s.icon, s.name .. (s.here and "  • HERE NOW" or ""), "At " .. tostring(s.place) .. "  • " .. ago(s.t), nil, s.here and RGB(90, 30, 60) or nil) end
		section("🔥 TRENDING IN THE CITY")
		if #v.city == 0 then empty("The city is quiet... for now.") end
		for _, m in ipairs(v.city) do row(m.icon, m.who .. ": " .. m.title, m.text .. "  • " .. ago(m.t), m.rare and "RARE" or nil) end
		section("😂 FUNNIEST RECENT EVENTS")
		if #v.funny == 0 then empty("Nobody has done anything funny yet. Suspicious.") end
		for _, m in ipairs(v.funny) do row(m.icon, m.who, m.text .. "  • " .. ago(m.t)) end
		section("📱 TOP CITYBUZZ POSTS")
		for _, p in ipairs(v.top) do row(p.icon, p.author, p.text, "❤️ " .. fmt(p.likes)) end
	else
		section("🏆 THIS WEEK'S MOST VIRAL (resets Monday)")
		for _, b in ipairs(v.boards) do
			section(b.name)
			if #b.list == 0 then empty("Nobody yet. It could be you.") end
			for _, e in ipairs(b.list) do
				local me = e.userId == v.myId
				row(({"🥇", "🥈", "🥉"})[e.rank] or ("#" .. e.rank), e.name .. (me and "  (you)" or ""), nil, fmt(e.value), me and RGB(70, 40, 20) or nil)
			end
		end
	end
end
kit.onOpen("viral", render)
C.onState(function(s)
	if s.viral and view.Visible then render() end
end)
C.viralRender = render
end
