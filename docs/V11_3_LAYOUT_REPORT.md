# Corner Empire v11.3 — Phone layout rework (client only)

**Install only `updates/EmpireClient.rbxmx`** (StarterPlayer → StarterPlayerScripts). `GameServer` is unchanged since
v11.2. Nothing was published. Same DataStore **`CornerEmpire_v5`**, same save format.

> **Testing honesty.** The checks below ran in the repository's **simulated** engine. They compute where every element
> sits on a 390×700 / 430×932 / 393×852 / 375×667 phone screen. They can't see real fonts, text that is wider than its
> label, the real safe area or the real Roblox touch controls. The pictures in `docs/mobile_layout_*.png` are
> **wireframes drawn from those computed positions, not screenshots** of the game. **Not tested in real Studio or on a
> phone** — use the checklist in section 5.

## 1. The layout you asked for

```
┌────────────────────────────────────────┐
│ 💰 $4.50M  +$37K/s │ ⭐ LEGENDARY      │  money, income, reputation: 34 px, one row
│ 📖 CH 1 · Broke Le…│ 📰 Next event     │  story chip (top-left, under the stats) · event chip
│[🏪]        ┌──────────────────────────┐│
│            │ top-right notification   ││  at most 3 cards; a card that doesn't fit waits
│[🏆]        │ stack (cards, newest     ││  and moves up when another is dismissed
│            │ priority first)          ││
│[🛡]        │ 📣 CityBuzz line      ▾  ││  CityBuzz = one small expandable line
│            └──────────────────────────┘│
│                                         │
│        — the middle of the screen —     │  nothing of ours: player, road, businesses
│                                  [📸]  │
│                                  [⚙️]  │
│                                  [📱]  │  phone stays on the right, above the jump button
│ [thumbstick]  (free for driving /  [jump]│  bottom: nothing but Roblox's controls and
│               action buttons)            │  the driving buttons
└────────────────────────────────────────┘
```

| You asked for | What it does now |
|---|---|
| Top: money, income, reputation — smaller and compact | One row, **34 px** (was 40): `💰 $4.50M  +$37K/s` and `⭐ LEGENDARY · 9,859 REP`. Tap → 📊 MY EMPIRE |
| Center completely clear; no giant notification | The notification area is capped at **38% of the screen height** (below the HUD, above the right-hand buttons). The player, the road and the businesses are lower than that. The big full-screen messages (celebration splash, mega-event announcement) are now a small banner under the HUD on phones, with no dimming or screen flash, and shorter |
| Notifications in a top-right area, max 2–3 | **One** stack in the top-right corner (≈ 72% of the width on a portrait phone), **at most 3 cards**, and only as many as fit the height budget. Cards that need an answer come first (tutorial, problem, delivery, police alert, heist, race...). The rest wait their turn (they are not lost) |
| CityBuzz → small expandable feed | A one-line feed at the end of the stack (`📣 🍕 New player opened a corner! ▾`). **Tap it** to see the 3 latest posts and an "Open CityBuzz ›" button; it closes by itself after 12 s. New posts just change the line (and flash it). No more pop-ups |
| Chapter/story bar top-left below the stats | The story chip is in row 2, left |
| Phone on the right, notifications away from it | 📸 ⚙️ 📱 are in the right column just above the jump button; the stack stops above them. (On a short landscape screen the stack moves in beside that column instead of above it) |
| Left buttons smaller and evenly spaced | 🏪 🏆 🛡 are **44 px** (were 56), with equal 10 px gaps |
| Scale to screen width, no overlap or cropped elements | Everything is positioned from the real screen size and safe area; the stack is ~72% of the width (180–300 px); a card narrower than its design shrinks to at most 80% and its **text shrinks to fit** its box instead of spilling |
| Bottom reserved for driving controls / action buttons | The bottom stack is gone. Nothing of ours is in the bottom band; the GAS/BRAKE/🔥/💨 cluster sits next to Roblox's jump button as before. While driving, the speedometer moved to the **top-left** (where the left buttons hide), so it never fights the notification stack |
| Never cover the player, road, businesses, interaction buttons | See the middle and the bottom above. Interaction prompts (Roblox puts them at the bottom centre) stay free |

Desktop is unchanged (checked: positions, sizes, anchors and parents of 12 key elements match after switching back).

## 2. What changed (all in `EmpireClient`)

`Layout` (the notification stack, the 3-card cap and height budget, card priority, text-fit, the new zones), `HUD`
(34 px money row, CityBuzz feed, tutorial card, splash and mega-event banners, smaller 44 px edge buttons),
`Phone` / `PhotoMode` / `AdminPanel` (button sizes), `Driving` (speedometer top-left), `Story`, `GuideUI` (cards moved
from the bottom stack to the one stack).

## 3. Install

1. Open your place in Studio → **File → Save to File As…** → a backup.
2. **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click → **Insert from File…** →
   `updates/EmpireClient.rbxmx`.
3. Leave `GameServer` alone (your pass IDs and admin owner stay).

## 4. Tests (SIMULATED — not real Roblox)

Full run on the finished code: **25 suites, 1,358 checks, 0 failed.** Static checks: `luau-lsp` clean except the known
`WorldFX.lua:59` false positive; API property check 0 problems. `GameServer.rbxmx` is byte-identical to v11.2.

**`mobile_test` — 193 / 193** (was 157), rewritten for the new layout. At 390×700, 430×932, 393×852 and 375×667:
- the compact HUD pieces (money row, ⭐ badge, story chip, event chip, 🏪, 🏆, 📱, ⚙️, CityBuzz feed) are inside the screen
  and the safe area, none overlap, the money row is ≤ 34 px;
- the 🏪 🏆 🛡 buttons are ≤ 44 px with **equal gaps**;
- **81–87% of the screen is free**, and nothing is in the middle (30–70% across, 38–72% down) or in the bottom band;
- each of the 15 notification cards, shown alone, lands in the top-right stack against the right edge, out of the
  middle, off the HUD and off the right-hand buttons; with **all of them showing at once**, at most 3 are in the stack,
  inside the height budget, none on top of another, and dismissing one brings the next waiting one in;
- text in the tutorial / tip / problem / delivery cards is set to shrink to fit;
- the CityBuzz feed is one line when closed, opens to the latest posts (staying in the top half) and closes by itself;
- toasts stay in the top band; windows, the phone, all 32 menus, Arcade, driving (speedometer top-left, clear of
  the phone button, jump button, thumbstick and the middle), the Arcade lifecycle, landscape 844×390, and the return
  to the unchanged desktop layout all still pass.

Wireframes drawn from those computed positions: `docs/mobile_layout_390x700.png`, `_430x932.png`, `_375x667.png`
(made by `tools/wireframe.py`). They are **not screenshots**.


## 5. Please test in Studio (Test → Device → 390×700, 393×852, 430×932, and a landscape phone)

- [ ] The top is two small rows; the middle of the screen is free; the bottom is free
- [ ] Walk and drive around: nothing of ours covers the road, your character or a business
- [ ] Trigger several notifications at once (tutorial, a tip, a business problem, a delivery): at most 3 show, in the top-right, and the others appear as you dismiss them
- [ ] CityBuzz line: tap to open, tap again to close; "Open CityBuzz ›" opens the phone app
- [ ] A big event (mega event / "YOU FOUND THE SECRET HQ"): a small banner at the top, not full screen
- [ ] 📱 ⚙️ 📸 stay on the right above the jump button; the stack never touches them
- [ ] 🏪 🏆 🛡 are small and evenly spaced; tap targets still feel fine with a thumb
- [ ] Driving: speedometer top-left, GAS/BRAKE/🔥/💨 by the jump button, the notification stack doesn't hide the road
- [ ] Text in the stack cards is readable (report any card whose text is too small or cut off)
- [ ] Desktop (Device: none): the classic layout is exactly as before
