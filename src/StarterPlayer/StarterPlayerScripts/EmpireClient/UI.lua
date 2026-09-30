-- UI: theme, helper functions, sounds, the main ScreenGui. Everything else builds on this.
return function(C)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local plr = Players.LocalPlayer
local RGB = Color3.fromRGB
C.plr = plr

C.R = {}
for _, n in ipairs({"State", "Announce", "Splash", "Customer", "Buzz", "BuzzUpdate", "Msg", "WarResults", "Menu", "Action", "Race"}) do
	C.R[n] = ReplicatedStorage:WaitForChild(n)
end
C.GetCatalog = ReplicatedStorage:WaitForChild("GetCatalog")
C.catalog = C.GetCatalog:InvokeServer("catalog")
function C.act(...) C.R.Action:FireServer(...) end

C.BG, C.CARD = RGB(22, 24, 34), RGB(36, 40, 56)
C.GOLD, C.GREEN, C.GRAY, C.RED, C.BLUE, C.PURPLE = RGB(255, 205, 70), RGB(70, 200, 110), RGB(74, 78, 96), RGB(220, 70, 80), RGB(60, 130, 230), RGB(140, 90, 230)
C.WHITE, C.SUB = Color3.new(1, 1, 1), RGB(175, 182, 205)

function C.fmt(n)
	n = math.floor((n or 0) + 0.5)
	if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e5 then return string.format("%.1fK", n / 1e3) end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end
function C.stars(n)
	n = math.clamp(math.floor(n + 0.5), 0, 5)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end
function C.clock(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end
function C.tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
function C.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local new, tween = C.new, C.tween
function C.corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 10)}, o) end
function C.stroke(o, color, th, tr)
	return new("UIStroke", {Color = color, Thickness = th or 2, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end
function C.gradient(o, a, b, rot) return new("UIGradient", {Color = ColorSequence.new(a, b), Rotation = rot or 90}, o) end
function C.panel(props, parent)
	props.BackgroundColor3 = props.BackgroundColor3 or C.BG
	props.BorderSizePixel = 0
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	local f = new("Frame", props, parent)
	C.corner(f, 12)
	C.stroke(f, C.WHITE, 1.5, 0.85)
	return f
end
function C.label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or C.WHITE
	props.TextSize = props.TextSize or 16
	return new("TextLabel", props, parent)
end
function C.button(props, parent)
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = props.TextColor3 or C.WHITE
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.BackgroundColor3 = props.BackgroundColor3 or C.GREEN
	local b = new("TextButton", props, parent)
	C.corner(b, 8)
	C.gradient(b, C.WHITE, RGB(190, 190, 190))
	local sc = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() tween(sc, 0.12, {Scale = 1.05}) end)
	b.MouseLeave:Connect(function() tween(sc, 0.12, {Scale = 1}) end)
	b.MouseButton1Down:Connect(function() tween(sc, 0.06, {Scale = 0.93}) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.2, {Scale = 1.05}, Enum.EasingStyle.Back) end)
	return b
end
function C.card(parent, h, order, color)
	local c = new("Frame", {Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = color or C.CARD, BorderSizePixel = 0, LayoutOrder = order or 0}, parent)
	C.corner(c, 10)
	return c
end
function C.header(parent, text, order)
	return C.label({Size = UDim2.new(1, -8, 0, 30), Text = text, TextSize = 18, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order or 0}, parent)
end
function C.bar(parent, pos, size, color)
	local bg = new("Frame", {Position = pos, Size = size, BackgroundColor3 = RGB(12, 13, 20), BorderSizePixel = 0}, parent)
	C.corner(bg, 4)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0}, bg)
	C.corner(fill, 4)
	return fill, bg
end
function C.vlist(parent, pad)
	return new("UIListLayout", {Padding = UDim.new(0, pad or 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, parent)
end
function C.autoFrame(parent, order)
	return new("Frame", {Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order or 0}, parent)
end
function C.clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

-- built-in sounds (no uploads needed)
local function sound(id, vol) return new("Sound", {SoundId = id, Volume = vol or 0.5}, SoundService) end
C.SND = {
	buy = sound("rbxasset://sounds/electronicpingshort.wav", 0.5),
	click = sound("rbxasset://sounds/switch.wav", 0.4),
	event = sound("rbxasset://sounds/snap.mp3", 0.6),
	msg = sound("rbxasset://sounds/electronicpingshort.wav", 0.3),
}
C.settings = {music = true, musicVol = 5, sfx = true, crowd = "high", weather = true, units = "MPH", spawnAt = "business"}
function C.play(s)
	if not C.settings.sfx then return end
	pcall(function() SoundService:PlayLocalSound(s) end)
end

C.gui = new("ScreenGui", {Name = "EmpireUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, plr:WaitForChild("PlayerGui"))
C.U = {}
C.S = nil
C.modals = {}
C.stateHooks = {}
function C.onState(fn) table.insert(C.stateHooks, fn) end
function C.locked(feature)
	local s = C.S
	if not s or not s.unlocks then return false end
	return s.unlocks[feature] == false
end
function C.lockText(feature)
	local f = C.catalog.features[feature]
	return f and ("🔒 " .. f.name .. " unlocks at " .. f.tierName .. " reputation") or "🔒 Locked"
end
end
