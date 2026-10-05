#!/usr/bin/env python3
"""Check property names used when creating Roblox instances against the real Roblox API definitions.

Real Roblox throws an error when a script sets a property that doesn't exist (the test harness can't know
that), and an error while a client module loads takes that module's UI down with it. This checks every
new("Class", {...}) and label/button/panel/card({...}) table in src/ against the class's real properties.

usage: python3 tools/propcheck.py path/to/globalTypes.d.luau
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
defs = open(sys.argv[1], encoding="utf-8").read()
classes = {}
for m in re.finditer(r"^declare extern type (\w+) extends (\w+) with\n(.*?)^end$", defs, re.S | re.M):
    name, parent, body = m.group(1), m.group(2), m.group(3)
    props = set(re.findall(r"^\s+(\w+)\s*:", body, re.M))
    classes[name] = (parent, props)
def props_of(cls):
    out = set()
    while cls in classes:
        parent, p = classes[cls]
        out |= p
        cls = parent
    return out

HELPERS = {"label": "TextLabel", "button": "TextButton", "panel": "Frame", "C.label": "TextLabel", "C.button": "TextButton", "C.panel": "Frame"}
def table_keys(src, i):
    # i points at "{": return the keys at depth 1 and the end index
    depth, j, keys, start = 0, i, [], i
    while j < len(src):
        ch = src[j]
        if ch in "{([":
            depth += 1
        elif ch in "})]":
            depth -= 1
            if depth == 0:
                break
        elif ch == '"':
            j += 1
            while src[j] != '"':
                j += 2 if src[j] == "\\" else 1
        elif depth == 1:
            m = re.match(r"(?:,|\{|\n)\s*([A-Za-z_]\w*)\s*=[^=]", src[j - 1:j + 60]) if j > start else None
        j += 1
    body = src[i + 1:j]
    # strip nested brackets and strings, then read top-level "Key =" pairs
    flat, d, k = [], 0, 0
    while k < len(body):
        ch = body[k]
        if ch == '"':
            k += 1
            while k < len(body) and body[k] != '"':
                k += 2 if body[k] == "\\" else 1
            flat.append('""')
        elif ch in "{([":
            d += 1
        elif ch in "})]":
            d -= 1
        elif d == 0:
            flat.append(ch)
        k += 1
    for m in re.finditer(r"(?:^|,)\s*([A-Za-z_]\w*)\s*=(?!=)", "".join(flat)):
        keys.append(m.group(1))
    return keys

bad = 0
for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
    for fn in files:
        if not fn.endswith(".lua"):
            continue
        path = os.path.join(dirpath, fn)
        src = open(path, encoding="utf-8").read()
        for m in re.finditer(r'\bnew\("(\w+)",\s*\{|\b((?:C\.)?(?:label|button|panel))\(\s*\{', src):
            cls = m.group(1) or HELPERS[m.group(2)]
            if cls not in classes:
                print("%s: unknown class %s" % (os.path.relpath(path, ROOT), cls))
                bad += 1
                continue
            valid = props_of(cls)
            for key in table_keys(src, m.end() - 1):
                if key not in valid:
                    line = src[:m.start()].count("\n") + 1
                    print("%s:%d: %s has no property '%s'" % (os.path.relpath(path, ROOT), line, cls, key))
                    bad += 1
print("%d problems" % bad)
sys.exit(1 if bad else 0)
