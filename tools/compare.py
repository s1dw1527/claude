#!/usr/bin/env python3
"""Compare two .rbxlx files by hierarchy, class, name and script source (ignores referents)."""
import sys, xml.etree.ElementTree as ET
def flat(path):
    out = {}
    def walk(it, p):
        props = it.find("Properties")
        name = next((x.text for x in props if x.get("name") == "Name"), None)
        src = next((x.text for x in props if x.get("name") == "Source"), None)
        q = p + "/" + name
        out[q] = (it.get("class"), src)
        for c in it.findall("Item"):
            walk(c, q)
    for it in ET.parse(path).getroot().findall("Item"):
        walk(it, "")
    return out
a, b = flat(sys.argv[1]), flat(sys.argv[2])
same = True
for k in sorted(set(a) | set(b)):
    if a.get(k) != b.get(k):
        same = False
        print("DIFF", k, "only-in-a" if k not in b else ("only-in-b" if k not in a else "content"))
print("IDENTICAL" if same else "DIFFERENT")
