-- ANIMATION CONFIG: every animation the game uses, in one place, with a safe fallback for each.
--
-- ✏️  TO USE YOUR OWN ANIMATIONS: upload them to Roblox (Animation Editor → Publish), copy the asset id and paste
--     it into `id` below, e.g. id = "rbxassetid://1234567890". Leave id = nil to use the fallback.
--
-- How a player reaction plays (C.AnimationConfig.react(name)):
--   1. `id` (your uploaded animation) on the avatar's Animator, if set and it loads
--   2. otherwise `emote`: one of Roblox's built-in avatar emotes (wave, point, dance, cheer, laugh)
--   3. otherwise a floating emoji reaction over the avatar's head (always works)
-- A missing or broken animation never stops a cinematic or errors; in Studio it is logged once in Output.
--
-- Cinematic actors (the part-built NPCs in EmpireClient > Actors) use procedural moves by name. An unknown move
-- name falls back to `ACTOR_FALLBACK` (also logged once in Studio).
return function(C)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local new, label, tween = C.new, C.label, C.tween
local plr = Players.LocalPlayer

local AC = {}
C.AnimationConfig = AC

-- Roblox's default R15 emote animations (from the default Animate script). Your own uploads go in `id`.
AC.REACTIONS = {
	celebrate   = {id = "rbxassetid://507770677", emote = "cheer", emoji = "🎉", actor = "celebrate"},
	facepalm    = {id = nil, emote = nil, emoji = "🤦", actor = "facepalm"},
	confused    = {id = nil, emote = nil, emoji = "🤔", actor = "shrug"},
	pointing    = {id = "rbxassetid://507770453", emote = "point", emoji = "👉", actor = "point"},
	shocked     = {id = nil, emote = nil, emoji = "😱", actor = "shock"},
	laughing    = {id = "rbxassetid://507770818", emote = "laugh", emoji = "😂", actor = "laugh"},
	thinking    = {id = nil, emote = nil, emoji = "🧠", actor = "think"},
	armsCrossed = {id = nil, emote = nil, emoji = "😤", actor = "crossed"},
	money       = {id = nil, emote = "dance", emoji = "💸", actor = "money"},
	ownerPose   = {id = nil, emote = nil, emoji = "😎", actor = "owner"},
	wave        = {id = "rbxassetid://507770239", emote = "wave", emoji = "👋", actor = "wave"},
	dance       = {id = "rbxassetid://507771019", emote = "dance", emoji = "🕺", actor = "hype"},
}
AC.ACTOR_FALLBACK = "idle"

-- ===== Studio-only logging (once per missing thing) =====
local logged = {}
local isStudio = RunService:IsStudio()
local function logOnce(key, text)
	if logged[key] then return end
	logged[key] = true
	if isStudio then print("[CornerEmpire][AnimationConfig] " .. text) end
end
AC.logged = logged

-- a cinematic actor move: known name, or the configured fallback
function AC.actorFallback(name)
	logOnce("actor:" .. tostring(name), "actor move \"" .. tostring(name) .. "\" doesn't exist; using \"" .. AC.ACTOR_FALLBACK .. "\"")
	return AC.ACTOR_FALLBACK
end
-- the actor move for a reaction (so cinematics show the same reaction on the "you" actor)
function AC.actorMove(reaction)
	local r = AC.REACTIONS[reaction]
	return r and r.actor or AC.actorFallback(reaction)
end

-- ===== the emoji fallback: always available =====
local function emojiPop(char, emoji)
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not head then return end
	local bb = new("BillboardGui", {Size = UDim2.fromOffset(70, 70), StudsOffset = Vector3.new(0, 2.6, 0), AlwaysOnTop = true, MaxDistance = 120, Name = "Reaction"}, head)
	local l = label({Size = UDim2.fromScale(1, 1), Text = emoji or "❗", TextScaled = true}, bb)
	tween(bb, 1.8, {StudsOffset = Vector3.new(0, 4.4, 0)})
	tween(l, 1.8, {TextTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.delay(1.9, function() bb:Destroy() end)
end

-- tracks that failed to load are remembered so they aren't retried every time
local broken = {}
local function animator(hum)
	local an = hum:FindFirstChildOfClass("Animator")
	if not an then
		an = Instance.new("Animator")
		an.Parent = hum
	end
	return an
end
-- returns how it played: "id", "emote", "emoji" or nil (no character)
function AC.react(name, who)
	local r = AC.REACTIONS[name]
	if not r then
		logOnce("reaction:" .. tostring(name), "unknown reaction \"" .. tostring(name) .. "\"; showing a wave instead")
		r = AC.REACTIONS.wave
	end
	local char = (who or plr).Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	if r.id and not broken[r.id] then
		local ok = pcall(function()
			local anim = Instance.new("Animation")
			anim.AnimationId = r.id
			local track = animator(hum):LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.15)
			task.delay(3, function() pcall(function() track:Stop(0.3) end) end)
		end)
		if ok then
			emojiPop(char, r.emoji)
			return "id"
		end
		broken[r.id] = true
		logOnce("id:" .. r.id, "animation " .. r.id .. " for \"" .. name .. "\" didn't load; using the fallback")
	elseif not r.id then
		logOnce("noid:" .. name, "no animation id set for \"" .. name .. "\" (fallback: " .. (r.emote and ("emote " .. r.emote) or ("emoji " .. r.emoji)) .. ")")
	end
	if r.emote then
		local ok, played = pcall(function() return hum:PlayEmote(r.emote) end)
		if ok and played then
			emojiPop(char, r.emoji)
			return "emote"
		end
	end
	emojiPop(char, r.emoji)
	return "emoji"
end
end
