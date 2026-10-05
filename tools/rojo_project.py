#!/usr/bin/env python3
"""Write default.project.json for Rojo (live-sync src/ into an open Studio place).

The scripts live as src/.../GameServer.server.lua with their modules in src/.../GameServer/, which Rojo
can't read on its own, so this lists every script explicitly. Run it again after adding a module.
Only the two game scripts are managed: everything else in the place (your own builds, settings) is
left alone.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
order = json.load(open(os.path.join(ROOT, "tools", "order.json")))

def script_node(base, name, ext):
    node = {"$path": "%s/%s%s" % (base, name, ext)}
    folder = os.path.join(ROOT, base, name)
    want = order.get("/" + os.path.relpath(folder, os.path.join(ROOT, "src")).replace(os.sep, "/"), [])
    mods = sorted((f[:-4] for f in os.listdir(folder) if f.endswith(".lua")), key=lambda n: (want.index(n) if n in want else len(want), n))
    for m in mods:
        node[m] = {"$path": "%s/%s/%s.lua" % (base, name, m)}
    return node

project = {
    "name": "CornerEmpire",
    "tree": {
        "$className": "DataModel",
        "ServerScriptService": {
            "$className": "ServerScriptService",
            "GameServer": script_node("src/ServerScriptService", "GameServer", ".server.lua"),
        },
        "StarterPlayer": {
            "$className": "StarterPlayer",
            "StarterPlayerScripts": {
                "$className": "StarterPlayerScripts",
                "EmpireClient": script_node("src/StarterPlayer/StarterPlayerScripts", "EmpireClient", ".client.lua"),
            },
        },
    },
}
json.dump(project, open(os.path.join(ROOT, "default.project.json"), "w"), indent=2)
open(os.path.join(ROOT, "default.project.json"), "a").write("\n")
print("wrote default.project.json")
