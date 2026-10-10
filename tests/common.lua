-- shared test setup: build the place from SOURCES, helpers to join/act/inspect
CFrame, Vector3, Color3, Enum, UDim2 = H.G.CFrame, H.G.Vector3, H.G.Color3, H.G.Enum, H.G.UDim2
local Players = H.Players
local RS = H.service("ReplicatedStorage")
local SSS = H.service("ServerScriptService")
local SPS = H.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local function buildTree(prefix, parent)
	-- scripts whose path is exactly prefix/Name, then their children at prefix/Name/Child
	local made = {}
	for path, e in pairs(SOURCES) do
		local rest = path:sub(#prefix + 2)
		if path:sub(1, #prefix + 1) == prefix .. "/" and not rest:find("/") then
			made[rest] = H.makeScript(e.cls, rest, e.src, parent)
		end
	end
	for name, inst in pairs(made) do buildTree(prefix .. "/" .. name, inst) end
	return made
end
local server = buildTree("ServerScriptService", SSS)
local client = buildTree("StarterPlayer/StarterPlayerScripts", SPS)

T = {}
function T.startServer()
	H.runScript(server.GameServer)
	H.task.wait(1)
	T.C = H.serverC
	T.R = T.C.R
	T.F = T.C.F
	-- (v14: AI rivals make their own moves after a few minutes of play, which puts a challenge card in the
	-- notification stack in the middle of unrelated tests. Tests start with them quiet; rivals_test makes moves itself.)
	if T.C.RIVAL_CFG then T.C.RIVAL_CFG.firstMove, T.C.RIVAL_CFG.moveMin, T.C.RIVAL_CFG.moveMax = 1e7, 1e7, 1e7 + 1 end
	return T.C
end
-- the slot DataStore the server really uses (in "Studio" that's the _StudioTest copy of the live store)
function T.slotStore()
	return H.stores[T.C.storeName(T.C.CFG.DATASTORE) .. "/global"]
end
function T.join(name, id)
	local p = H.addPlayer(name, id)
	H.task.wait(1.5)
	return p
end
function T.act(plr, ...)
	H.signalOf(T.R.Action, "OnServerEvent"):Fire(plr, ...)
	H.task.wait(0.1)
end
function T.data(plr) return T.C.data[plr] end
function T.lastRemote(name, plr)
	for i = #H.remoteLog, 1, -1 do
		local e = H.remoteLog[i]
		if e.name == name and (plr == nil or e.player == plr or e.dir == "s2all") then return e end
	end
end
function T.remotesSince(mark, name, plr)
	local out = {}
	for i = mark + 1, #H.remoteLog do
		local e = H.remoteLog[i]
		if e.name == name and (plr == nil or e.player == plr or e.dir == "s2all") then table.insert(out, e) end
	end
	return out
end
function T.announcesSince(mark, plr)
	local out = {}
	for _, e in ipairs(T.remotesSince(mark, "Announce", plr)) do table.insert(out, e.args[1]) end
	return out
end
-- (v14: the 10-step onboarding pays small rewards on its own a few seconds after a step is done, which would land in
-- the middle of other tests' cash checks. Test games start with it finished; journey_test turns it back on.)
function T.quietOnboarding(d)
	if not (d and T.C.ONBOARD_STEPS) then return end
	local done = {}
	for _, s in ipairs(T.C.ONBOARD_STEPS) do done[s.key] = 1 end
	d.onboard = {seeded = true, finished = true, done = done, skip = {}, c = {}}
end
function T.newGame(plr, slot, starter)
	T.act(plr, "menuNew", slot or 1, starter or 1)
	H.task.wait(1)
	T.quietOnboarding(T.data(plr))
	return T.data(plr)
end
-- the latest state as the client sees it: heavy sections are only sent when they change, so those are
-- taken from the newest packet that had them (exactly what EmpireClient does)
local HEAVY = {"archive", "homeInfo", "props", "districts", "market", "staff", "reviews", "tours", "shareable", "standings", "passes", "cars", "showcase", "biz", "warLeaders",
	"rebirth", "unlocks", "fees", "spire", "map", "viral", "estate", "explore"}
function T.state(plr)
	local latest
	local out = {}
	local need = {}
	for _, k in ipairs(HEAVY) do need[k] = true end
	for i = #H.remoteLog, 1, -1 do
		local e = H.remoteLog[i]
		if e.name == "State" and e.player == plr then
			local st = e.args[1]
			if not latest then
				latest = st
				for k, v in pairs(st) do out[k] = v end
			end
			for k in pairs(need) do
				if st[k] ~= nil then
					if out[k] == nil then out[k] = st[k] end
					need[k] = nil
				end
			end
			if next(need) == nil then break end
		end
	end
	return latest and out or nil
end
function T.errorsAndWarnings()
	local bad = {}
	for _, e in ipairs(H.errors) do table.insert(bad, "ERROR: " .. e) end
	for _, w in ipairs(H.warnings) do
		if not w:find("terrain calibrated") then table.insert(bad, "WARN: " .. w) end
	end
	return bad
end
function T.assertClean(label)
	local bad = T.errorsAndWarnings()
	H.check(#bad == 0, label .. " (no script errors or warnings)")
	for i = 1, math.min(#bad, 8) do print("      " .. bad[i]:sub(1, 900)) end
	H.errors, H.warnings = {}, {}
end
T.clientScript = client.EmpireClient
