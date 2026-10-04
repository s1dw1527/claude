#!/usr/bin/env python3
"""Turn tests/results/*.txt (economy_sim output) into one markdown table of milestone times."""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "tests", "results")
RUNS = [("v6_casual", "v6 casual"), ("v6_active", "v6 active"), ("v7_casual", "v7 casual"), ("v7_active", "v7 active"),
        ("v7_casual_x2", "v7 casual + 2x Money"), ("v7_casual_x4_vip", "v7 casual + 4x + VIP")]
ROWS = [("firstUpgrade", "First business upgrade"), ("secondBiz", "Second business"), ("firstStaff", "First employee"),
        ("tutorial", "Tutorial complete"), ("firstProp", "First rental property"), ("luxuryCar", "First luxury purchase (Sports Coupe)"),
        ("tier2", "LOCAL FAVORITE"), ("tier3", "HOTSPOT"), ("tier4", "CITY ICON"), ("tier5", "EMPIRE"), ("tier6", "LEGENDARY DISTRICT"),
        ("earned$1M", "Lifetime $1M"), ("earned$100M", "Lifetime $100M"), ("earned$1B", "Lifetime $1B"), ("allBiz", "All 8 businesses"),
        ("era2", "City Era 2"), ("era3", "City Era 3"), ("era4", "City Era 4"), ("era5", "City Era 5"), ("rebirth1", "First rebirth")]
ROWS += [("story%d" % i, "Story Ch %d done" % i) for i in range(1, 7)]

def load(name):
    p = os.path.join(RES, name + ".txt")
    if not os.path.exists(p):
        return None
    m = re.search(r"MILESTONES_JSON (\{.*\})", open(p, encoding="utf-8").read())
    return json.loads(m.group(1)) if m else None

def fmt(t):
    if t is None:
        return "—"
    if t < 60:
        return "%.1f min" % t
    return "%dh%02dm" % (t // 60, t % 60)

data = [(label, load(name)) for name, label in RUNS]
data = [(l, d) for l, d in data if d is not None]
out = ["| Milestone | " + " | ".join(l for l, _ in data) + " |", "|---|" + "---|" * len(data)]
for key, label in ROWS:
    out.append("| " + label + " | " + " | ".join(fmt(d.get(key, {}).get("t")) for _, d in data) + " |")
text = "\n".join(out) + "\n\n— = not reached in the simulated time (12 h for v7 runs, 2 h for v6 runs; story chapters don't exist in v6).\n"
open(os.path.join(RES, "SUMMARY.md"), "w", encoding="utf-8").write("# Economy simulation: time to each milestone\n\n" + text)
print(text)
