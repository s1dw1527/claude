#!/usr/bin/env python3
"""Bundle the fake engine + every script in src/ + a test file into one Luau file and run it.

usage: python3 tests/run.py tests/server_test.lua [src_dir]
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = os.environ.get("LUAU", "/tmp/claude-0/-home-user-claude/8ab8267c-f21d-5159-b6c6-de5701660394/scratchpad/tools/luau")

def longstr(s):
    level = 1
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"

def main():
    test = sys.argv[1]
    src = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "src")
    parts = ["local H = (function()\n", open(os.path.join(ROOT, "tests", "harness.lua")).read(), "\nend)()\n", "local SOURCES = {}\n"]
    for dirpath, _, files in os.walk(src):
        for fn in sorted(files):
            if not fn.endswith(".lua"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, src).replace(os.sep, "/")
            if fn.endswith(".server.lua"): cls, name = "Script", rel[:-len(".server.lua")]
            elif fn.endswith(".client.lua"): cls, name = "LocalScript", rel[:-len(".client.lua")]
            else: cls, name = "ModuleScript", rel[:-len(".lua")]
            parts.append('SOURCES[%s] = {cls = "%s", src = %s}\n' % (repr(name).replace("'", '"'), cls, longstr(open(full, encoding="utf-8").read())))
    # optional settings for a test, e.g. SIM_ARGS='profile="active", hours=8' python3 tests/run.py tests/economy_sim.lua
    parts.append("SIM_ARGS = {" + os.environ.get("SIM_ARGS", "") + "}\n")
    parts.append("\n-- ===== common =====\n")
    parts.append(open(os.path.join(ROOT, "tests", "common.lua"), encoding="utf-8").read())
    parts.append("\n-- ===== test file =====\n")
    parts.append(open(test, encoding="utf-8").read())
    # one bundle per run, so several tests can run at the same time
    bundle = os.path.join(ROOT, "tests", ".bundle_%d.lua" % os.getpid())
    open(bundle, "w", encoding="utf-8").write("".join(parts))
    try:
        r = subprocess.run([LUAU, bundle])
    finally:
        os.remove(bundle)
    sys.exit(r.returncode)

main()
