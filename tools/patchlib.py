"""Tiny exact-match patch helper used while editing src/ (fails loudly if the target text isn't found exactly)."""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVER = os.path.join(ROOT, "src", "ServerScriptService", "GameServer")
CLIENT = os.path.join(ROOT, "src", "StarterPlayer", "StarterPlayerScripts", "EmpireClient")

def path(p):
    if os.path.isabs(p):
        return p
    head, _, rest = p.partition("/")
    base = {"server": SERVER, "client": CLIENT}.get(head)
    return os.path.join(base, rest) if base else os.path.join(ROOT, p)

def patch(p, old, new, count=1):
    p = path(p)
    s = open(p, encoding="utf-8").read()
    n = s.count(old)
    assert n == count, "%s: expected %d match(es), found %d for:\n%s" % (p, count, n, old[:300])
    open(p, "w", encoding="utf-8").write(s.replace(old, new))
