"""Draws docs/mobile_layout_<WxH>.svg (and .png if headless Chromium is available) from the WIRE lines that
tests/mobile_test.lua prints. It is a WIREFRAME of the computed layout, not a screenshot of the real game.
usage: python3 tests/run.py tests/mobile_test.lua | python3 tools/wireframe.py 390x700 [out_dir]"""
import sys, re, subprocess, shutil, os
size = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else "docs"
W, H = map(int, size.split("x"))
rects = []
for line in sys.stdin:
    if line.startswith("WIRE " + size + "|"):
        _, name, x, y, w, h = line.strip().split("|")
        rects.append((name, float(x), float(y), float(w), float(h)))
COL = {"CashPill": "#6b5a1c", "TierBadge": "#7a4e12", "EventChip": "#2d4a78", "StoryTracker": "#6a2a78", "BizButton": "#37415f", "BoardButton": "#37415f",
       "AdminButton": "#4b3470", "PhoneButton": "#37415f", "SettingsButton": "#4a4e63", "CameraButton": "#4a4e63", "BuzzFeed": "#6e1c4c"}
LABEL = {"CashPill": "💰 $4.50M   +$37K/s", "TierBadge": "⭐ LEGENDARY · 9,859 REP", "EventChip": "📰 Next event", "StoryTracker": "📖 CH 1 · Broke Legend",
         "BizButton": "🏪", "BoardButton": "🏆", "AdminButton": "🛡", "PhoneButton": "📱", "SettingsButton": "⚙", "CameraButton": "📸"}
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*2+70}" height="{H+80}" font-family="Arial, sans-serif">',
       '<rect width="100%" height="100%" fill="#14161f"/>',
       f'<text x="20" y="28" fill="#fff" font-size="18" font-weight="bold">Phone layout {W}×{H} — wireframe of the computed positions (not a screenshot)</text>']
def panel(ox, title, with_ui):
    svg.append(f'<g transform="translate({ox},50)">')
    svg.append(f'<text x="0" y="-6" fill="#aab" font-size="13">{title}</text>')
    svg.append(f'<rect width="{W}" height="{H}" fill="#7fa86a" stroke="#fff" stroke-width="2"/>')
    # a hint of "the world": road + player + building in the middle
    svg.append(f'<rect x="0" y="{H*0.55}" width="{W}" height="{H*0.12}" fill="#4a4d55"/>')
    svg.append(f'<circle cx="{W/2}" cy="{H*0.50}" r="14" fill="#f2c14e"/><rect x="{W/2-8}" y="{H*0.50+12}" width="16" height="30" fill="#d9663a"/>')
    svg.append(f'<rect x="{W*0.62}" y="{H*0.36}" width="{W*0.3}" height="{H*0.17}" fill="#c9b79c"/>')
    # Roblox's own touch controls
    svg.append(f'<circle cx="{W*0.17}" cy="{H-70}" r="48" fill="none" stroke="#fff" stroke-dasharray="5 4" opacity=".7"/>')
    svg.append(f'<text x="{W*0.17-30}" y="{H-66}" fill="#fff" font-size="11" opacity=".8">thumbstick</text>')
    svg.append(f'<circle cx="{W-48}" cy="{H-52}" r="32" fill="none" stroke="#fff" stroke-dasharray="5 4" opacity=".7"/>')
    svg.append(f'<text x="{W-62}" y="{H-48}" fill="#fff" font-size="11" opacity=".8">jump</text>')
    svg.append(f'<text x="{W/2-62}" y="{H-16}" fill="#fff" font-size="11" opacity=".8">driving / action buttons</text>')
    if with_ui:
        for name, x, y, w, h in rects:
            key = name.split("/")[-1]
            fill = COL.get(key, "#1e4f8a")
            svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" fill-opacity=".92" stroke="#fff" stroke-opacity=".5"/>')
            svg.append(f'<text x="{x+6}" y="{y+min(h-6, 18)}" fill="#fff" font-size="11">{LABEL.get(key, key)}</text>')
    svg.append('</g>')
panel(20, "without the UI: the view you want to see", False)
panel(50 + W, "with the UI (busiest state: tutorial + 2 cards, top-right stack)", True)
svg.append('</svg>')
os.makedirs(out, exist_ok=True)
path = os.path.join(out, f"mobile_layout_{size}.svg")
open(path, "w").write("\n".join(svg))
print("wrote", path, len(rects), "pieces")
chrome = shutil.which("chromium") or shutil.which("chromium-browser") or shutil.which("google-chrome")
if not chrome:
    for root in (os.environ.get("PLAYWRIGHT_BROWSERS_PATH", "/opt/pw-browsers"),):
        for d in sorted(os.listdir(root)) if os.path.isdir(root) else []:
            for sub in ("chrome-linux/chrome", "chrome-linux/headless_shell"):
                c = os.path.join(root, d, sub)
                if os.path.exists(c): chrome = c
if chrome:
    png = path.replace(".svg", ".png")
    r = subprocess.run([chrome, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars", f"--window-size={W*2+70},{H+80}", f"--screenshot={png}", "file://" + os.path.abspath(path)], capture_output=True, timeout=60)
    print("png", png, os.path.exists(png))
