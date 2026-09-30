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
	return T.C
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
function T.newGame(plr, slot, starter)
	T.act(plr, "menuNew", slot or 1, starter or 1)
	H.task.wait(1)
	return T.data(plr)
end
function T.state(plr)
	local e = T.lastRemote("State", plr)
	return e and e.args[1]
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
