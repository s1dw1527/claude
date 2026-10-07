-- BUSINESS UI (v10): property cards, choosing a business for a plot, naming it, the brand editor, products and
-- supplies. Everything here only ASKS the server; the server checks and applies (GameServer > RealEstate, Brands).
return function(C)
local Workspace = game:GetService("Workspace")
local RGB = Color3.fromRGB
local new, label, button, card, header, bar, clear, corner, stroke = C.new, C.label, C.button, C.card, C.header, C.bar, C.clear, C.corner, C.stroke
local fmt, play, SND, act, gui, U, R = C.fmt, C.play, C.SND, C.act, C.gui, C.U, C.R
local GOLD, GREEN, GRAY, RED, BLUE, PURPLE, WHITE, SUB, CARD = C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE, C.WHITE, C.SUB, C.CARD
local modal = C.makeModal
if not modal then return end
local BUI = {}
C.BusinessUI = BUI
local LOGOS = {"🍋", "⭐", "👑", "🔥", "💎", "🌈", "⚡", "🍀", "🌙", "☀️", "🎯", "🚀", "🍦", "🥐", "☕", "🍕", "🕹️", "💻", "🏭", "🐝"}
local COLORS = {RGB(255, 214, 60), RGB(255, 120, 40), RGB(230, 60, 60), RGB(255, 110, 200), RGB(170, 90, 255), RGB(70, 120, 255),
	RGB(60, 200, 230), RGB(60, 200, 120), RGB(140, 100, 60), RGB(245, 245, 245), RGB(40, 40, 46), RGB(210, 170, 60)}
local THEMES = {"Classic", "Modern", "Retro", "Neon", "Luxury", "Cozy"}
local MENUS = {"Chalkboard", "Neon", "Classic", "Minimal"}
local function stars(n) return string.rep("★", n or 0) .. string.rep("☆", 5 - (n or 0)) end
local function row(parent, h, order, color) return card(parent, h, order, color) end
local function btn(parent, text, pos, size, color, fn)
	local b = button({Position = pos, Size = size, Text = text, TextSize = 13, TextWrapped = true, BackgroundColor3 = color or BLUE}, parent)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		fn(b)
	end)
	return b
end
local function txt(parent, text, pos, size, sizePx, color, bold)
	return label({Position = pos, Size = size, Text = text, TextSize = sizePx or 13, TextColor3 = color or WHITE, TextWrapped = true,
		Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, parent)
end
-- "What's this?" help button for a modal (the text comes from the guide)
local function helpButton(m, topic)
	local b = button({Position = UDim2.new(1, -150, 0, 10), Size = UDim2.fromOffset(96, 32), Text = "❓ What's this?", TextSize = 11, BackgroundColor3 = PURPLE}, m.frame)
	m.help = b   -- (on a phone the window moves it to the top-left corner as a plain ❓)
	b.MouseButton1Click:Connect(function()
		play(SND.click)
		if C.showHelp then C.showHelp(topic) end
	end)
end
BUI.helpButton = helpButton

-- =====================================================================
-- CONFIRMATION DIALOG (shared: selling, admin actions...)
-- =====================================================================
do
	local box = C.panel({AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 170), BackgroundColor3 = RGB(30, 30, 44), Visible = false, ZIndex = 80}, gui)
	stroke(box, GOLD, 2, 0.2)
	local q = label({Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 86), TextSize = 17, TextWrapped = true, Font = Enum.Font.GothamBlack, ZIndex = 81}, box)
	local no = button({Position = UDim2.new(0, 16, 1, -58), Size = UDim2.new(0.5, -24, 0, 44), Text = "Cancel", TextSize = 16, BackgroundColor3 = GRAY, ZIndex = 81}, box)
	local yes = button({Position = UDim2.new(0.5, 8, 1, -58), Size = UDim2.new(0.5, -24, 0, 44), Text = "Confirm", TextSize = 16, BackgroundColor3 = RED, ZIndex = 81}, box)
	local pending
	no.MouseButton1Click:Connect(function() play(SND.click) box.Visible = false pending = nil end)
	yes.MouseButton1Click:Connect(function()
		play(SND.click)
		box.Visible = false
		local fn = pending
		pending = nil
		if fn then fn() end
	end)
	-- dangerous actions never run from a single tap: they always go through this
	box.Name = "ConfirmDialog"
	C.Layout.window("confirm", box, {major = false, z = C.Layout.Z.critical})
	function C.confirm(question, yesText, fn)
		q.Text = question
		yes.Text = yesText or "Confirm"
		pending = fn
		box.Visible = true
	end
	C.confirmBox = box
end

-- =====================================================================
-- PROPERTY CARD
-- =====================================================================
local plotM = modal("plot", "🏙️  PROPERTY", 520, 470)
helpButton(plotM, "property")
local plotInfo
local function renderPlot(info)
	plotInfo = info
	clear(plotM.body)
	if not info then return end
	local c = row(plotM.body, 150, 1, RGB(36, 40, 60))
	stroke(c, info.color or WHITE, 2, 0.3)
	if info.owner then
		txt(c, info.mine and "🔑 YOUR PROPERTY" or ("OWNED BY: " .. info.owner), UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 26), 20, info.mine and GOLD or WHITE, true)
		txt(c, "Business: " .. (info.bizName or "— vacant —") .. (info.level and info.level > 0 and ("  (Lv " .. info.level .. ")") or ""), UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 20), 15)
	else
		txt(c, "PROPERTY FOR SALE", UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, 26), 20, RGB(255, 110, 110), true)
		txt(c, "Price: $" .. fmt(info.price or 0), UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 20), 17, RGB(120, 255, 150), true)
	end
	txt(c, "District: " .. info.icon .. " " .. info.district .. "\nType: " .. info.kind .. "\nPotential: " .. stars(info.stars) .. "   •   +$" .. fmt(info.income) .. "/s", UDim2.fromOffset(14, 66), UDim2.new(1, -28, 0, 60), 13, SUB)
	local d2 = row(plotM.body, 48, 2)
	txt(d2, (info.blurb or "") .. "\nDistrict bonus: " .. tostring(info.boost), UDim2.fromOffset(12, 4), UDim2.new(1, -24, 1, -8), 12, SUB)
	local acts = row(plotM.body, 64, 3, RGB(26, 28, 40))
	if not info.owner then
		local reason = info.canBuy and ("You own " .. info.used .. "/" .. info.capacity .. " properties • " .. info.mineHere .. "/" .. info.cap .. " here • " .. info.free .. "/" .. info.total .. " plots free")
			or tostring(info.reason)
		txt(acts, reason, UDim2.fromOffset(12, 6), UDim2.new(0.6, -12, 1, -12), 11, info.canBuy and SUB or RGB(255, 160, 140))
		btn(acts, "BUY  $" .. fmt(info.price), UDim2.new(0.6, 6, 0, 10), UDim2.new(0.4, -16, 0, 44), info.canBuy and GREEN or GRAY, function()
			act("plotBuy", info.lot)
		end)
	elseif info.mine then
		local w = 1 / 3
		btn(acts, info.biz and "🔄 Change business" or "🏪 Choose business", UDim2.new(0, 8, 0, 10), UDim2.new(w, -12, 0, 44), BLUE, function() BUI.openChooser(info) end)
		btn(acts, "🚪 Enter", UDim2.new(w, 4, 0, 10), UDim2.new(w, -12, 0, 44), info.biz and PURPLE or GRAY, function()
			if info.biz then act("enterBiz", info.biz) plotM.frame.Visible = false end
		end)
		btn(acts, "💼 Sell $" .. fmt(info.sellFor or 0), UDim2.new(2 * w, 0, 0, 10), UDim2.new(w, -8, 0, 44), RED, function()
			C.confirm("Sell your " .. info.district .. " plot for $" .. fmt(info.sellFor or 0) .. "?\n(Half of what you paid.)", "Sell", function()
				act("plotSell", info.deed, true)
				plotM.frame.Visible = false
			end)
		end)
	else
		txt(acts, "You can't buy another player's property. You can visit their business if they allow visitors.", UDim2.fromOffset(12, 6), UDim2.new(0.6, -12, 1, -12), 11, SUB)
		btn(acts, "👀 VIEW / VISIT", UDim2.new(0.6, 6, 0, 10), UDim2.new(0.4, -16, 0, 44), info.biz and PURPLE or GRAY, function()
			if info.biz then act("visitBiz", info.ownerId, info.biz) plotM.frame.Visible = false end
		end)
	end
end

-- =====================================================================
-- CHOOSE YOUR BUSINESS
-- =====================================================================
local chooseM = modal("chooseBiz", "🏪  CHOOSE YOUR BUSINESS", 560, 520)
helpButton(chooseM, "chooseBusiness")
function BUI.openChooser(info)
	plotInfo = info
	C.openModal("chooseBiz", true)
	clear(chooseM.body)
	header(chooseM.body, "What will this " .. info.district .. " plot run?", 0)
	for i, o in ipairs(info.options or {}) do
		local c = row(chooseM.body, 54, i)
		label({Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(44, 54), Text = o.icon, TextSize = 30}, c)
		local status
		if o.locked then status = "🔒 Needs " .. o.need
		elseif o.level > 0 then status = "Open (Lv " .. o.level .. ") → adds a new location of " .. (o.brand or o.name)
		else status = "New business: opens here for $" .. fmt(o.cost) end
		txt(c, o.name, UDim2.fromOffset(58, 6), UDim2.new(1, -200, 0, 20), 16, WHITE, true)
		txt(c, status, UDim2.fromOffset(58, 28), UDim2.new(1, -200, 0, 20), 11, o.locked and RGB(255, 160, 140) or SUB)
		btn(c, info.biz == o.key and "✔ Current" or "Choose", UDim2.new(1, -130, 0.5, -19), UDim2.fromOffset(120, 38), o.locked and GRAY or GREEN, function()
			if o.locked or info.biz == o.key then return end
			act("plotBiz", info.deed, o.key)
			chooseM.frame.Visible = false
		end)
	end
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "plot" and type(a) == "table" then
		C.openModal("plot", true)
		renderPlot(a)
	elseif kind == "chooseBiz" and type(a) == "table" then
		BUI.openChooser(a)
	end
end)

-- =====================================================================
-- NAME YOUR BUSINESS
-- =====================================================================
local nameM = modal("nameBiz", "🏷️  NAME YOUR BUSINESS", 480, 330)
local nameKey
local nameIntro = txt(nameM.body, "", UDim2.new(), UDim2.new(1, -8, 0, 48), 14, SUB)
nameIntro.LayoutOrder = 1
local nameBox = new("TextBox", {Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = RGB(18, 20, 30), TextColor3 = WHITE, PlaceholderText = "Your business name", Text = "",
	Font = Enum.Font.GothamBlack, TextSize = 20, ClearTextOnFocus = false, LayoutOrder = 2}, nameM.body)
corner(nameBox, 8)
local nameMsg = txt(nameM.body, "", UDim2.new(), UDim2.new(1, -8, 0, 30), 12, RGB(255, 170, 150))
nameMsg.LayoutOrder = 3
local nameRow = C.autoFrame(nameM.body, 4)
nameRow.Size = UDim2.new(1, -8, 0, 50)
btn(nameRow, "Keep the default", UDim2.new(0, 0, 0, 4), UDim2.new(0.45, -6, 0, 42), GRAY, function() nameM.frame.Visible = false end)
btn(nameRow, "✔ Save name", UDim2.new(0.45, 6, 0, 4), UDim2.new(0.55, -6, 0, 42), GREEN, function()
	if nameKey then
		nameMsg.Text = "Checking..."
		act("bizName", nameKey, nameBox.Text)
	end
end)
function BUI.askName(info)
	nameKey = info.key
	nameIntro.Text = info.first and (info.icon .. " Your new " .. info.biz .. " needs a name! It shows on the building, the map and CityBuzz.")
		or (info.icon .. " Rename " .. info.biz .. (info.fee and info.fee > 0 and (" (costs $" .. fmt(info.fee) .. ")") or ""))
	nameBox.Text = info.current or info.suggestion or ""
	nameMsg.Text = "3-24 characters. Names are checked by Roblox's text filter."
	C.openModal("nameBiz", true)
end
R.Menu.OnClientEvent:Connect(function(kind, a)
	if kind == "nameBiz" and type(a) == "table" then
		BUI.askName(a)
	elseif kind == "nameResult" and type(a) == "table" and a.key == nameKey then
		if a.ok then
			nameM.frame.Visible = false
			if U.toast then U.toast("🏷️ Say hello to " .. tostring(a.name) .. "!") end
		else
			nameMsg.Text = "❌ " .. tostring(a.why)
		end
	end
end)

-- =====================================================================
-- MANAGE: brand, products, supplies (one window, three tabs)
-- =====================================================================
local manM = modal("bizManage", "🏪  MANAGE BUSINESS", 640, 580)
helpButton(manM, "products")
local manKey, manTab = nil, "products"
local tabs = {}
local tabBar = new("Frame", {Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1}, manM.frame)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)}, tabBar)
manM.body.Position = UDim2.fromOffset(12, 90)
manM.body.Size = UDim2.new(1, -24, 1, -102)
local renderManage
for _, t in ipairs({{"products", "🧪 Products"}, {"supplies", "📦 Supplies"}, {"brand", "🏷️ Brand"}}) do
	local b = button({Size = UDim2.new(1 / 3, -4, 1, 0), Text = t[2], TextSize = 14, BackgroundColor3 = GRAY}, tabBar)
	tabs[t[1]] = b
	b.MouseButton1Click:Connect(function() play(SND.click) manTab = t[1] renderManage() end)
end
local function bizEntry(key)
	for _, b in ipairs(C.S and C.S.biz or {}) do if b.key == key then return b end end
end
local function swatches(parent, order, title, field, current)
	local c = row(parent, 74, order)
	txt(c, title, UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 18), 12, SUB, true)
	for i, col in ipairs(COLORS) do
		local s = button({Position = UDim2.fromOffset(10 + (i - 1) * 46, 26), Size = UDim2.fromOffset(40, 40), Text = current == i and "✔" or "", TextSize = 18, BackgroundColor3 = col}, c)
		s.MouseButton1Click:Connect(function() play(SND.click) act("brand", manKey, field, i) end)
	end
end
local function chooser(parent, order, title, field, list, current)
	local c = row(parent, 58, order)
	txt(c, title, UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 18), 12, SUB, true)
	for i, v in ipairs(list) do
		btn(c, v, UDim2.new((i - 1) / #list, 6, 0, 22), UDim2.new(1 / #list, -10, 0, 30), current == v and GREEN or GRAY, function() act("brand", manKey, field, v) end)
	end
end
function renderManage()
	local b = manKey and bizEntry(manKey)
	local v = b and b.v10
	for k, t in pairs(tabs) do t.BackgroundColor3 = k == manTab and BLUE or GRAY end
	clear(manM.body)
	if not v then
		header(manM.body, "Open this business first.", 1)
		return
	end
	header(manM.body, (v.brand.logo or b.icon) .. "  " .. v.brand.name .. "   •   Lv " .. b.level .. (v.trending and ("   🔥 " .. v.trending .. " is TRENDING") or ""), 0)
	if manTab == "products" then
		local info = row(manM.body, 40, 1, RGB(30, 34, 50))
		txt(info, "Products: " .. #v.products .. "/" .. v.slots .. " slots (more at Lv 3, 5, 7, 10)   •   Product effect on income: " .. v.productMult .. "%   •   Locations: +" .. v.locations .. "%",
			UDim2.fromOffset(10, 4), UDim2.new(1, -20, 1, -8), 12, SUB)
		for i, p in ipairs(v.products) do
			local c = row(manM.body, 128, 1 + i)
			label({Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(40, 40), Text = p.icon, TextSize = 28}, c)
			txt(c, p.name, UDim2.fromOffset(50, 6), UDim2.new(1, -260, 0, 20), 16, WHITE, true)
			txt(c, p.desc .. "\nSold " .. fmt(p.sold or 0) .. "  •  Popularity " .. p.pop .. "  •  Trend " .. p.trend .. "  •  Demand " .. p.demand .. "%", UDim2.fromOffset(50, 28), UDim2.new(1, -260, 0, 36), 11, SUB)
			-- price
			txt(c, "Price $" .. p.dollars .. "  (" .. math.floor(p.price * 100 + 0.5) .. "% of fair)", UDim2.new(1, -206, 0, 8), UDim2.fromOffset(200, 18), 12, GOLD, true)
			btn(c, "−", UDim2.new(1, -206, 0, 30), UDim2.fromOffset(40, 30), GRAY, function() act("product", manKey, {"price", p.id, p.price - 0.1}) end)
			btn(c, "+", UDim2.new(1, -160, 0, 30), UDim2.fromOffset(40, 30), GRAY, function() act("product", manKey, {"price", p.id, p.price + 0.1}) end)
			btn(c, "✏️", UDim2.new(1, -114, 0, 30), UDim2.fromOffset(40, 30), GRAY, function()
				BUI.askProductName(manKey, p.id, p.name)
			end)
			btn(c, "🗑", UDim2.new(1, -68, 0, 30), UDim2.fromOffset(40, 30), RED, function()
				C.confirm("Remove " .. p.name .. " from the menu?", "Remove", function() act("product", manKey, {"remove", p.id}) end)
			end)
			-- upgrades
			btn(c, "⭐ Quality " .. p.q .. "/5" .. (p.qCost >= 0 and ("  $" .. fmt(p.qCost)) or "  MAX"), UDim2.new(0, 8, 1, -54), UDim2.new(1 / 3, -12, 0, 44), p.qCost >= 0 and BLUE or GRAY, function()
				act("product", manKey, {"q", p.id})
			end)
			btn(c, "🎁 Presentation " .. p.pres .. "/3" .. (p.presCost >= 0 and ("  $" .. fmt(p.presCost)) or "  MAX"), UDim2.new(1 / 3, 4, 1, -54), UDim2.new(1 / 3, -12, 0, 44), p.presCost >= 0 and BLUE or GRAY, function()
				act("product", manKey, {"pres", p.id})
			end)
			local nextIng = ({std = "prem", prem = "art", art = "std"})[p.ing] or "std"
			btn(c, "🧂 Ingredients: " .. ({std = "Standard", prem = "Premium", art = "Artisan"})[p.ing or "std"], UDim2.new(2 / 3, 0, 1, -54), UDim2.new(1 / 3, -8, 0, 44), PURPLE, function()
				act("product", manKey, {"ing", p.id, nextIng})
			end)
		end
		if #v.products < v.slots then
			header(manM.body, "🆕 CREATE A PRODUCT ($" .. fmt(v.newCost) .. ")", 50)
			for i, t in ipairs(v.templates) do
				local c = row(manM.body, 48, 50 + i)
				label({Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(40, 40), Text = t.icon, TextSize = 26}, c)
				txt(c, t.name .. "\n" .. t.desc, UDim2.fromOffset(50, 4), UDim2.new(1, -190, 1, -8), 12)
				btn(c, "Create", UDim2.new(1, -130, 0.5, -18), UDim2.fromOffset(120, 36), GREEN, function()
					BUI.askProductName(manKey, nil, t.name, t.k)
				end)
			end
		end
	elseif manTab == "supplies" then
		for i, s in ipairs(v.stock) do
			local c = row(manM.body, 50, i)
			txt(c, s.name .. ":  " .. s.v .. "%", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 18), 15, s.v < 20 and RGB(255, 140, 120) or WHITE, true)
			local fill = bar(c, UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 12), s.v < 20 and RED or GREEN)
			fill.Size = UDim2.fromScale(s.v / 100, 1)
		end
		local c = row(manM.body, 120, 10, RGB(30, 34, 50))
		txt(c, "Customers use up supplies. Below 20% sales drop (to half at 0%).\nRestock at the business, remotely with an Executive Workstation computer (+10%), or let your General Manager do it.",
			UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 56), 12, SUB)
		btn(c, "📦 Restock here  $" .. fmt(v.restock), UDim2.new(0, 10, 1, -50), UDim2.new(0.5, -15, 0, 42), v.restock > 0 and GREEN or GRAY, function() act("restock", manKey) end)
		btn(c, "💻 Restock remotely  $" .. fmt(v.restockRemote), UDim2.new(0.5, 5, 1, -50), UDim2.new(0.5, -15, 0, 42), v.restockRemote > 0 and BLUE or GRAY, function() act("restock", manKey, "remote") end)
	else
		local br = v.brand
		local c = row(manM.body, 60, 1)
		txt(c, "Name: " .. br.name .. (br.named and "" or "  (default)"), UDim2.fromOffset(12, 6), UDim2.new(1, -170, 0, 22), 16, WHITE, true)
		txt(c, br.renameIn > 0 and ("Rename again in " .. math.ceil(br.renameIn / 60) .. " min") or (br.renameFee > 0 and ("Rename fee $" .. fmt(br.renameFee)) or "First name is free"),
			UDim2.fromOffset(12, 32), UDim2.new(1, -170, 0, 18), 11, SUB)
		btn(c, "✏️ Rename", UDim2.new(1, -150, 0.5, -20), UDim2.fromOffset(140, 40), BLUE, function()
			local b2 = bizEntry(manKey)
			BUI.askName({key = manKey, icon = b2.icon, biz = b2.brand or b2.name, current = br.name, fee = br.renameFee})
		end)
		local lc = row(manM.body, 112, 2)
		txt(lc, "Logo", UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 18), 12, SUB, true)
		for i, lg in ipairs(LOGOS) do
			local col, r2 = (i - 1) % 10, math.floor((i - 1) / 10)
			local s = button({Position = UDim2.fromOffset(10 + col * 58, 24 + r2 * 44), Size = UDim2.fromOffset(52, 40), Text = lg, TextSize = 22, BackgroundColor3 = br.logo == lg and GREEN or GRAY}, lc)
			s.MouseButton1Click:Connect(function() play(SND.click) act("brand", manKey, "logo", lg) end)
		end
		swatches(manM.body, 3, "Sign color", "sign", br.sign)
		swatches(manM.body, 4, "Accent color (awning, trim, interior logo)", "accent", br.accent)
		swatches(manM.body, 5, "Exterior color", "exterior", br.exterior)
		swatches(manM.body, 6, "Employee uniforms", "uniform", br.uniform)
		chooser(manM.body, 7, "Interior theme", "theme", THEMES, br.theme)
		chooser(manM.body, 8, "Menu board style", "menu", MENUS, br.menu)
	end
end
function BUI.openManage(key, tab)
	manKey = key
	manTab = tab or manTab
	C.openModal("bizManage", true)
	renderManage()
end
manM.update = function() if manM.frame.Visible then renderManage() end end
-- product naming (create or rename)
local pM = modal("productName", "🧪  NAME YOUR PRODUCT", 460, 280)
local pBox = new("TextBox", {Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = RGB(18, 20, 30), TextColor3 = WHITE, Text = "", Font = Enum.Font.GothamBlack, TextSize = 18,
	ClearTextOnFocus = false, LayoutOrder = 1}, pM.body)
corner(pBox, 8)
local pHint = txt(pM.body, "3-28 characters. Checked by Roblox's text filter.", UDim2.new(), UDim2.new(1, -8, 0, 30), 12, SUB)
pHint.LayoutOrder = 2
local pRow = C.autoFrame(pM.body, 3)
pRow.Size = UDim2.new(1, -8, 0, 50)
local pending = {}
btn(pRow, "Cancel", UDim2.new(0, 0, 0, 4), UDim2.new(0.4, -6, 0, 42), GRAY, function() pM.frame.Visible = false end)
btn(pRow, "✔ Save", UDim2.new(0.4, 6, 0, 4), UDim2.new(0.6, -6, 0, 42), GREEN, function()
	if pending.template then act("product", pending.key, {"new", pending.template, pBox.Text})
	else act("product", pending.key, {"rename", pending.id, pBox.Text}) end
	pM.frame.Visible = false
	task.delay(0.6, function() BUI.openManage(pending.key, "products") end)
end)
function BUI.askProductName(key, id, current, template)
	pending = {key = key, id = id, template = template}
	pBox.Text = current or ""
	C.openModal("productName", true)
end

-- =====================================================================
-- THE BUSINESS CARD (HUD) gets Products / Supplies / Brand buttons
-- =====================================================================
function C.bizManageButtons(parent, getKey)
	local rowF = new("Frame", {Size = UDim2.new(1, -6, 0, 30), BackgroundTransparency = 1, LayoutOrder = 6}, parent)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, rowF)
	for _, t in ipairs({{"🧪 Products", "products"}, {"📦 Supplies", "supplies"}, {"🏷️ Brand", "brand"}}) do
		local b = button({Size = UDim2.new(1 / 3, -3, 1, 0), Text = t[1], TextSize = 11, BackgroundColor3 = RGB(80, 70, 140)}, rowF)
		b.MouseButton1Click:Connect(function()
			play(SND.click)
			local k = getKey()
			if k then BUI.openManage(k, t[2]) end
		end)
	end
	return rowF
end
if C.bizCardFrame and C.bizCardCurrent then C.bizManageButtons(C.bizCardFrame, C.bizCardCurrent) end
end
