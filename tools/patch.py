#!/usr/bin/env python3
"""Make drop-in update files for Studio (no Rojo needed): updates/GameServer.rbxmx and updates/EmpireClient.rbxmx.

Each holds one game script with all of its modules. In Studio: delete the old script, then right-click
ServerScriptService (or StarterPlayer > StarterPlayerScripts) > Insert from File... and pick the file.
Everything else in your place stays as it is.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build

OUT = os.path.join(build.ROOT, "updates")
TARGETS = [("GameServer", "ServerScriptService", "/ServerScriptService"),
           ("EmpireClient", "StarterPlayer/StarterPlayerScripts", "/StarterPlayer/StarterPlayerScripts")]

os.makedirs(OUT, exist_ok=True)
for name, rel, key in TARGETS:
    folder = os.path.join(build.SRC, rel)
    for e in build.children(folder, key):
        if e[1] == name:
            out = ['<roblox version="4">\n']
            build.emit(out, *e, key)
            out.append("</roblox>\n")
            dest = os.path.join(OUT, name + ".rbxmx")
            open(dest, "w", encoding="utf-8").write("".join(out))
            print("wrote", os.path.relpath(dest, build.ROOT))
