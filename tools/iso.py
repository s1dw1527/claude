#!/usr/bin/env python3
"""Draws an isometric PREVIEW of part of the world from the ISO lines tests/isodump.lua prints.
It is NOT a screenshot of the real game: no Roblox lighting, no textures, no terrain; wedges and balls are drawn
as boxes. It shows shapes, sizes, colours and layout, so a district's composition can be checked without Studio.
usage: SIM_ARGS='x1=.., z1=.., x2=.., z2=.., night=true' python3 tests/run.py tests/isodump.lua | python3 tools/iso.py out.svg [yaw_degrees] [pitch_degrees]
(yaw 0 looks toward -Z; pitch 89 is straight down, north = -Z at the top)"""
import sys, math, os, shutil, subprocess

out = sys.argv[1]
yaw = math.radians(float(sys.argv[2])) if len(sys.argv) > 2 else math.radians(35)
night = os.environ.get("ISO_NIGHT") == "1"
parts = []
for line in sys.stdin:
    if not line.startswith("ISO|"):
        continue
    f = line.strip().split("|")[1:]
    x, y, z, sx, sy, sz = map(float, f[0:6])
    r = list(map(float, f[6:15]))
    col = tuple(int(v) for v in f[15:18])
    mat, cls, tr = f[18], f[19], float(f[20])
    parts.append((x, y, z, sx, sy, sz, r, col, mat, cls, tr))
if not parts:
    print("no parts"); sys.exit(1)

# camera: looking down at 32 degrees, turned by yaw
pitch = math.radians(float(sys.argv[3])) if len(sys.argv) > 3 else math.radians(32)
fx, fz = math.sin(yaw), math.cos(yaw)                       # horizontal view direction (into the screen)
fwd = (-fx * math.cos(pitch), -math.sin(pitch), -fz * math.cos(pitch))
right = (fz, 0.0, -fx)
up = (right[1] * fwd[2] - right[2] * fwd[1], right[2] * fwd[0] - right[0] * fwd[2], right[0] * fwd[1] - right[1] * fwd[0])
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
light = (0.45, 0.8, 0.35)
ln = math.sqrt(dot(light, light)); light = tuple(v / ln for v in light)

faces = []
for (x, y, z, sx, sy, sz, r, col, mat, cls, tr) in parts:
    ax = (r[0], r[3], r[6]); ay = (r[1], r[4], r[7]); az = (r[2], r[5], r[8])
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    def corner(i, j, k):
        return (x + ax[0] * hx * i + ay[0] * hy * j + az[0] * hz * k,
                y + ax[1] * hx * i + ay[1] * hy * j + az[1] * hz * k,
                z + ax[2] * hx * i + ay[2] * hy * j + az[2] * hz * k)
    quads = [
        (ax, [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]), ((-ax[0], -ax[1], -ax[2]), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
        (ay, [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]), ((-ay[0], -ay[1], -ay[2]), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
        (az, [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]), ((-az[0], -az[1], -az[2]), [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)]),
    ]
    for n, q in quads:
        if dot(n, fwd) >= -1e-6:
            continue                      # facing away from the camera
        pts = [corner(*c) for c in q]
        cx = sum(p[0] for p in pts) / 4; cy = sum(p[1] for p in pts) / 4; cz = sum(p[2] for p in pts) / 4
        # (painter's order by the face's farthest corner: big ground slabs are drawn before what stands on them)
        depth = max(dot(p, fwd) for p in pts)
        shade = 0.55 + 0.45 * max(0.0, dot(n, light))
        if mat == "Neon":
            shade = 1.25 if night else 1.1
        elif night:
            shade *= 0.35
        c = tuple(min(255, int(v * shade)) for v in col)
        op = 0.55 if mat == "Glass" and tr < 0.3 else (1 - tr)
        faces.append((depth, [(dot(p, right), -dot(p, up)) for p in pts], c, op, mat))
faces.sort(key=lambda f: -f[0])
xs = [p[0] for f in faces for p in f[1]]; ys = [p[1] for f in faces for p in f[1]]
minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
W = 1600
scale = W / max(1e-6, (maxx - minx))
H = int((maxy - miny) * scale) + 40
bg = "#0b1020" if night else "#9fc6e8"
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}"><rect width="100%" height="100%" fill="{bg}"/>']
for depth, pts, c, op, mat in faces:
    s = " ".join(f"{(px - minx) * scale:.1f},{(py - miny) * scale + 20:.1f}" for px, py in pts)
    stroke = "" if mat == "Neon" else ' stroke="#00000033" stroke-width="0.4"'
    svg.append(f'<polygon points="{s}" fill="rgb({c[0]},{c[1]},{c[2]})" fill-opacity="{op:.2f}"{stroke}/>')
svg.append(f'<text x="10" y="16" font-family="Arial" font-size="13" fill="#fff">PREVIEW (simulated parts, no Roblox lighting/terrain) — {len(parts)} parts</text></svg>')
open(out, "w").write("\n".join(svg))
print("wrote", out, len(parts), "parts", len(faces), "faces")
chrome = shutil.which("chromium")
root = os.environ.get("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers")
if not chrome and os.path.isdir(root):
    for d in sorted(os.listdir(root)):
        for sub in ("chrome-linux/chrome", "chrome-linux/headless_shell"):
            c = os.path.join(root, d, sub)
            if os.path.exists(c): chrome = c
if chrome:
    png = out.replace(".svg", ".png")
    subprocess.run([chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars", f"--window-size={W},{min(H, 4000)}", f"--screenshot={png}", "file://" + os.path.abspath(out)], capture_output=True, timeout=120)
    print("png", png, os.path.exists(png))
