# Corner Empire v16.1 — "Bold UI"

A visual restyle based on your four reference images:
- **Refs 1–2:** the cartoony store and the chunky outlined buttons and stats panels.
- **Ref 3:** the shop list with Robux pills and a red X.
- **Ref 4:** the glass HUD with icon tiles and a level bar.

**It's visual only.**
- No gameplay, economy or save changes.
- Same `CornerEmpire_v5` DataStore, same save schema (16), no migration.
- No new products, and no image uploads: everything is built from frames, strokes, gradients and Roblox's built-in fonts.

> **Not tested in Roblox Studio.** All results below come from the simulated engine (`tests/run.py`). It checks
> structure, behavior, contrast and layout math, **not how the UI looks**. Please go through the Studio checklist at the end
> before publishing. Nothing was published.

## What changed

### The style kit (`EmpireClient/UI.lua`)
Every screen builds its UI through these helpers, so the whole game changes at once. 243 buttons across the HUD and 40 windows were checked.

| | Before | After |
|---|---|---|
| Buttons | Flat color, a white→grey gradient, Gotham Black | **Chunky:** a glossy 3-stop gradient (light top, darker "lip"), a **2.5px dark outline**, **Fredoka One** lettering with a dark text outline, corner radius 10. The press squeeze and tap sound are kept. |
| Windows and panels | A faint 1.5px white edge | A **3px dark outline**, radius 14 |
| Cards | Flat | A gradient (lighter top) plus a dark outline, radius 12 |
| Progress bars | Thin and flat | Outlined track, glossy fill |
| Section headers | Gotham Black | Fredoka One with an outline |

**New helpers:**
- `C.closeX`: the red X.
- `C.pill`: price and confirm pills (`buy`, `robux`, `danger`, `off`).
- `C.tabs`: a chunky tab strip.
- `C.titleText`: outlined title lettering.
- `C.statRow`: a "Statistics" row with an icon chip, a name and a value pill.
- `C.STYLE`: the tokens (outline color, font, gloss).

`C.stroke` and `C.gradient` now **reuse** an object's existing outline or gradient instead of stacking a second one. Roblox draws only one, so recoloring an outline (e.g. a gold "selected" edge) now always works.

### Windows
- Every window (`C.makeModal`) has a **colored title banner** in its own color: Store purple, Heists and Rivals red, Park orange, Daily gold, Roadmap and Garage blue, and so on. The title is in outlined Fredoka One.
- A **red X** closes it.
- Phone sizing (`fitModal`) is unchanged.
- The same red X is used for the staff candidates window, the phone, the collapsible HUD panels, the main menu overlay, the interior panel and the map info card.

### 🛒 Store (was "Game Passes")
- **Tabs:** ⭐ All / 💵 Money / 🏎️ Perks.
- Each pass is a glossy card with a big icon chip, its name, what it does, and a **green Robux price pill**.
- Owned passes get a grey **✔ OWNED** pill and a gold rim.
- It's the same 7 passes, the same prices from `C.PASSES`, and the same purchase action.

### Phone
- App icons are **glossy tiles**: the app's color, a dark outline, a shine strip and radius 16.
- App names are outlined.
- Locked apps get a dark glass overlay with 🔒.
- The grid size is unchanged.

### HUD top bar (desktop)
- A **glass** bar: translucent navy with a light rim.
- Bigger outlined cash and tier.
- The reputation bar is now a **level bar** (15px, outlined, with its **%** inside, or MAX at the top tier). It shows the same progress as before, so there's no new XP system.
- The compact phone HUD keeps its layout, with a slightly thicker bar.

### Daily, Roadmap, Settings, My Empire
- **🎁 Daily:** glossy day cards. Today is gold-rimmed, claimed days are dimmed with ✅, and Claim buttons are green pills.
- **🗺️ Roadmap:** go and collect buttons are green pills, and the bars are outlined.
- **⚙️ Settings:** "Statistics" rows (an icon chip plus the name). Values are on chunky buttons: **ON green, OFF red**, everything else blue.
- **📊 My Empire:** the stats are now Statistics rows (🏆 Trophies, ♻️ Rebirths, 👥 Followers, ⭐ Star rating, 🏙️ City owned), each with its value in a gold pill.

### Planned but not done
- **Drop shadows behind windows.** The game's ScreenGui uses Sibling z-ordering, so a shadow would have to be a separate frame that follows each window's position, size and scale. That adds risk for little gain. The thick dark outline and the darker gradient "lip" carry the chunky look instead.
- **HQ and Park.** They get the new kit automatically, but were not hand-tuned beyond it.

## Tests (simulated)

### A test loophole, fixed first
`ui_test`'s contrast check skipped any text whose object had *any* UIStroke. Once every button has a Border outline, that would have silently excused every button.

The check now has two rules:
- Only a real **text** outline counts: TextStroke, or a Contextual UIStroke that itself contrasts ≥ 3:1 with the letters.
- **Buttons are always measured**, outline or not.

All 1,035 measured texts pass at ≥ 3:1. In a stricter trial run that ignored every outline, all 1,050 texts still passed.

### New `style_test` (19 checks)
- **Buttons:** all 243 visible buttons on the HUD and in 40 windows have the dark outline.
- **Windows:** every window has its banner, an outlined title and exactly one red X, and the X closes it.
- **Store:**
  - The tabs filter correctly.
  - Each of the 7 passes has a Robux pill matching the catalog.
  - An owned pass shows ✔ OWNED.
- **Phone:** 33 tiles with outline and shine, and the 🔒 glass shows exactly when an app is locked.
- **Level bar:** the % equals the real reputation progress (16% at 150 rep, LOCAL FAVORITE), and it reads MAX at the top tier.
- **Settings:** ON is green, OFF is red, and the color flips both ways.
- **My Empire:** the Statistics rows show the real values.

### Full regression
**48 suites, 2,121 checks, 0 failed** (simulated), after one fix:
- The first parallel run had **1 failure**, in `viral_test` ("an impossible speed is ignored"). The check compared the player's *total* viral score, which another detector watching real play bumped under the heavy 4-at-a-time load. The test now checks the car-crash moment itself.
- `viral_test` then passed alone: 86/86.
- No game code was involved.

### Static and build checks
- `tools/check.sh` (luau-lsp): only the known `WorldFX.lua(59,4)` false positive.
- `tools/propcheck.py`: 0 problems.
- `CornerEmpire_v16_1.rbxlx` and both drop-ins built. The round trip (extract → diff against `src`) is identical.

## Install
It's the same as v16:
1. Replace **EmpireClient** with `updates/EmpireClient.rbxmx`. This holds all of the visual changes.
2. Replace **GameServer** with `updates/GameServer.rbxmx`. The only server change is the version string, 16.1.0, and its update note.

Alternatively, open `CornerEmpire_v16_1.rbxlx`. Your pass IDs and admin list stay as you set them (see README).

## Studio checklist (please check before publishing)
1. **Fredoka One** renders on every button and title, and the text fits on the long buttons:
   - Staff (Hire / Fire / shift);
   - Business upgrades;
   - Settings values ("IMPORTANT ONLY");
   - Store pills ("✔ OWNED").

   Fredoka One is a little wider than Gotham, so look for clipped text.
2. **Outline thickness on a real phone:** the 2.5px button outline and the 3px window outline should look chunky, not heavy, at 390×844.
3. **The glass top bar on a bright daytime sky** (desktop): the cash, tier and level bar stay readable.
4. **The Store:** the tabs switch, and Robux prompts still open from the pills (with your real pass IDs).
5. **The phone grid:** tiles, shine strips and lock glass line up, and app names aren't clipped.
6. **Window banners:** the red X sits inside the banner on both desktop and phone, and doesn't cover the ❓ help button.
7. **Daily:** the day strip is readable at phone width.
