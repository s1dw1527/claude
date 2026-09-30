#!/usr/bin/env python3
"""Build a Roblox .rbxlx place file from the src/ tree.

src/<Service>/...                     -> container Item (Workspace, ReplicatedStorage, ...)
src/.../Name.server.lua               -> Script
src/.../Name.client.lua               -> LocalScript
src/.../Name.lua                      -> ModuleScript
src/.../Name/  (next to Name.*.lua)   -> children of that script
Child order comes from tools/order.json when listed, otherwise alphabetical.
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
SERVICES = [("Workspace", "Workspace"), ("ReplicatedStorage", "ReplicatedStorage"),
            ("ServerScriptService", "ServerScriptService"), ("StarterPlayer", "StarterPlayer")]
CONTAINERS = {"StarterPlayerScripts": "StarterPlayerScripts"}
EXT = [(".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")]

order = {}
op = os.path.join(ROOT, "tools", "order.json")
if os.path.exists(op):
    order = json.load(open(op))

ref = [0]
def newref():
    ref[0] += 1
    return "RBX%d" % ref[0]

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def cdata(src):
    return "<![CDATA[" + src.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def classify(fn):
    for ext, cls in EXT:
        if fn.endswith(ext):
            return fn[: -len(ext)], cls
    return None, None

def children(path, key):
    entries = []
    if not os.path.isdir(path):
        return entries
    names = os.listdir(path)
    scripts = {}
    for fn in names:
        full = os.path.join(path, fn)
        if os.path.isfile(full):
            nm, cls = classify(fn)
            if nm:
                scripts[nm] = (cls, full)
    dirs = [fn for fn in names if os.path.isdir(os.path.join(path, fn)) and fn not in scripts]
    want = order.get(key, [])
    keys = sorted(set(scripts) | set(dirs), key=lambda n: (want.index(n) if n in want else len(want), n))
    for nm in keys:
        if nm in scripts:
            cls, full = scripts[nm]
            entries.append(("script", nm, cls, full, os.path.join(path, nm)))
        else:
            entries.append(("folder", nm, CONTAINERS.get(nm, "Folder"), None, os.path.join(path, nm)))
    return entries

def emit(out, kind, nm, cls, full, sub, key):
    out.append('<Item class="%s" referent="%s"><Properties><string name="Name">%s</string>' % (cls, newref(), esc(nm)))
    if kind == "script":
        src = open(full, encoding="utf-8").read()
        out.append('\n<ProtectedString name="Source">' + cdata(src) + '</ProtectedString></Properties>\n')
    else:
        out.append('</Properties>\n')
    for e in children(sub, key + "/" + nm):
        emit(out, *e, key + "/" + nm)
    out.append('</Item>\n')

def build(dest):
    out = ['<roblox version="4">\n']
    for folder, cls in SERVICES:
        emit(out, "folder", folder, cls, None, os.path.join(SRC, folder), "")
    out.append("</roblox>\n")
    open(dest, "w", encoding="utf-8").write("".join(out))
    print("wrote", dest)

if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "CornerEmpire_v6.rbxlx"))
