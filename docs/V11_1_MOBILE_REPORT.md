# Corner Empire v11.1 — Mobile UI Overhaul — Report

**Deliverables**
- `updates/EmpireClient.rbxmx` — the only file you need to install (client UI).
- `CornerEmpire_v11_1.rbxlx` — the whole place, if you prefer to open that.
- `updates/GameServer.rbxmx` — **unchanged since v11**. No server change was needed, so you don't have to replace it.
- This report (test report, list of changed systems, install steps, Studio checklist).

> **Testing honesty.** Every automated result below ran in this repository's **simulated** Roblox engine. For this
> update the test computes each element's on-screen rectangle itself from Position, Size, AnchorPoint, UIScale,
> UIPadding and the list/grid layouts, at real phone sizes. It **cannot** see real fonts, text that's wider than its
> label, the real notch/safe area, Roblox's real touch controls, or how anything looks. **Nothing has been tested in
> real Roblox Studio or on a real phone.** Mobile testing has **not** "passed" until you run section 6 in Studio.

**Data:** the DataStore is still **`CornerEmpire_v5`**. It was not renamed or replaced, no new store was created, and
the save format is unchanged (schema 11). This update only changes the client UI script, which never touches saves.

---

## 1. The problem (from your screenshot)

On a phone the game showed the desktop UI squeezed onto the screen: a 760-pixel top bar wider than the phone, the
reputation tier ("LEGENDARY DISTRICT") as a big block, the story panel, the CityBuzz ticker, a 300-pixel business
panel and a 290×318 leaderboard all on screen at once, plus oversized phone/settings buttons. Windows were shrunk
as a whole (text down to 45%), and several windows could be open at the same time.

## 2. The new phone layout

The phone layout switches on when the **viewport** (not the device type) is ≤ 700 wide or ≤ 500 tall. 390×700,
393×852, 375×667 and 430×932 portrait and 844×390 landscape are all phone layout. A large touch screen (a tablet) keeps
the classic layout, and so does every desktop.

```
┌──────────────────────────────────────┐   safe area (notch / Roblox top bar) above
│ 💰 $4.50M        +$37.0K/s │ ⭐ LEGENDARY │   row 1 — always visible (tap → 📊 MY EMPIRE)
│                            │  9,859 REP  │
│ 📖 CH 1 · Broke Legend ▬▬  │ 📰 Next 0:30│   row 2 — story chip + event chip
│[🏪]  📣 CityBuzz: … (4 s)                │   top notification stack (between the edge columns)
│Lv10                                       │
│[🏆]                                       │
│ #2              the game world             │
│[🛡]            (centre always clear)       │
│                                    [📸]   │
│      tutorial / tips / problem /   [⚙️]   │   bottom notification stack
│      delivery / achievement cards  [📱]   │   right column, just above the jump button
│ [thumbstick]                     [jump]   │   Roblox's own touch controls (nothing of ours here)
└──────────────────────────────────────┘
```

**Priority levels**
1. **Always visible:** the money row (cash, income, ⭐ tier badge) and the right column (📱 phone, ⚙️ settings, 📸 photo).
2. **Compact, steps aside:** row 2 (story chip, event chip), the left column (🏪 businesses, 🏆 leaderboard, 🛡️ admin)
   and both notification stacks. They hide whenever a big window is open, and row 2 plus the left column also hide
   while you drive.
3. **Only when asked:** every window (business panel, leaderboard, 📊 MY EMPIRE, the phone, all 32 phone/menu windows,
   the Arcade, Heists, the builder...). **Only one at a time**: opening one closes the others.

**What you see now instead of...**
| Before (phone) | Now (phone) |
|---|---|
| 760 px top bar with every stat | one row: `💰 $4.50M  +$37.0K/s` and a `⭐ LEGENDARY / 9,859 REP` badge. Tap either → **📊 MY EMPIRE** window with all the details (boosts, reputation progress and next unlocks, stats, city event, corner war) |
| "LEGENDARY DISTRICT" block | the ⭐ badge (short names: LEGENDARY, LOCAL FAV, UNKNOWN; the others are already short) |
| story panel `CH 1: BROKE LEGEND` + objective | a chip `📖 CH 1 · Broke Legend` with a thin progress line. Tap → the Story app with the full objective. Hidden during the first tutorial steps, during cutscenes and in legend mode, as before |
| event bar + permanent CityBuzz ticker | an event chip (`📰 Next event 0:30`, `❄️ FROZEN 12s`...) and a **4-second CityBuzz notification** (`📣 CityBuzz: …`). Tap it → the CityBuzz app |
| 290×318 leaderboard | a `🏆 #2` button → the leaderboard as a centred window (≤ 300×330, scrolls, big ✕) |
| 300 px business panel | a `🏪 Lv 10` button (red dot = a problem, green = you can afford an upgrade) → the business panel as a window (≤ 360×620, full-size text, big ✕). The tutorial adds "(Tap 🏪 on the left.)" on phones |
| 74 px phone button + 46 px ⚙️ beside it | one right-edge column above Roblox's jump button: 📸, ⚙️, 📱 (56 px) |
| phone fixed at 330×600 bottom-right | a centred phone, ~82% of the screen wide and ~78% tall (clamped 280–420 × 500–760, never larger than the screen), full text size, a big ✕, the game darkened behind it (tap outside to close). In landscape it scales down as a whole. The home screen scrolls, so all 22 apps are reachable |
| windows shrunk to fit (text as small as 45%) | windows **reflow**: ≤ 92% of the width, ≤ 84% of the height, text never below 80%, centred under the money row; the content gets narrower and scrolls. Titles shrink to fit; the ✕ and ❓ become 44×40 |

## 3. Every UI system changed

All changes are in the client (`EmpireClient`). Desktop keeps the classic layout; the test checks the positions,
sizes, anchors and parents of 12 key elements are identical after switching phone → desktop.

| System (module) | What changed |
|---|---|
| **Layout (new)** — also `C.UIManager` | breakpoints from the viewport; safe area from Roblox's `CoreUISafeInsets` (plus an 8 px margin, fallback: the top-bar inset); Roblox touch-control zones; the compact containers (row 2, left/right columns, two bounded notification stacks); `slot` / `window` / `major` helpers; one-big-window rule; `OpenModal / CloseModal / IsOpen / CloseAll / Current`; z-order table; one UIScale per frame |
| HUD | compact money row + ⭐ badge; event chip; CityBuzz notification; toast sized and placed for phones; business panel and leaderboard as windows behind 🏪 / 🏆 edge buttons; problem, delivery, tutorial, mega-event, achievement and house-tour cards in the stacks; war results fitted; the "+$" float rises from the money row on phones; house-tour buttons use fractions of the row so they fit narrower cards |
| Menus (all modal windows) | phone sizing (reflow, ≥ 80% text), title fits, bigger ✕ / ❓; every window is a "big window" (one at a time); new **📊 MY EMPIRE** window; staff candidates window fitted |
| Phone | centred responsive phone, dim backdrop, ✕, scrolling home screen, right-column buttons, CityBuzz notification hook |
| Story | story chip in row 2; rival speech bubble and "NEW STORY EVENT" pill in the stacks; cutscene dialogue box re-laid out for phones; chapter-complete card fitted |
| ArcadeUI | the Arcade app's games are now **vertical cards** (`icon NAME / 👥 2 players / description / ▶ PLAY`), which scroll on a phone. ▶ PLAY shows a purple route to that game's Fun Zone booth (the games need two players at a booth); the route clears when you arrive. The duel window is fitted to the screen and is a big window |
| MiniGames | game window fitted to the screen, one big window at a time |
| Driving | on touch screens / phones: new **GAS** and **BRAKE** pedals (they override the thumbstick's forward/back; the thumbstick still steers). Phones: speedometer at half size top-right; 🔥/💨 at half size above the pedals; everything just left of the jump button, clear of the thumbstick and the centre of the road. While driving, row 2 and the left column hide. Race panel in the top stack. Keyboard/gamepad desktop: unchanged (no pedals) |
| BuilderUI | phones: the floor plan fills the window's width (18–30 px cells), storage / the selected item goes **under** the plan with 46 px buttons (Rotate, Move, Pick up, Done, Cancel); tabs share the width; style and visitor buttons wrap; the shop's category tabs grow instead of overflowing; the interior bar's Build button resizes through the layout manager |
| InteriorUI | decorate panel = a **bottom sheet** on phones (the room stays visible above); interior bar on two lines in the top stack |
| ComputerUI | phones: the app bar becomes a scrolling strip across the top, the app gets the full width |
| HeistUI | bag HUD and police alert in the top stack; the security puzzle fitted as a whole (keypad keeps its shape) and is a big window |
| GuideUI | tip card in the bottom stack |
| CityLife | viral-moment pop-up and beef pill in the top stack (the pop-in animation no longer adds a second UIScale) |
| AdminPanel | 🛡️ button in the left column (admins only, as before) |
| PhotoMode | 📸 button in the right column |
| MainMenu | phones: save slots and starter homes become swipeable carousels at full size; texts sized to the screen; the delete dialog's buttons fit |
| Cinematics | result banner never wider than the screen; its title shrinks to fit |
| BusinessUI | the confirmation dialog is fitted and always on top; the ❓ help button moves to the top-left corner on phones |
| WorldFX | **bug fix:** the guide beam list didn't include `heist`, so the v11 "route back to the mountain" beam never showed. Added, plus `arcade` for ▶ PLAY |

**Display order (top-level ZIndex):** gameplay controls (6) < compact HUD (5–6) < notification stacks (30) < phone dim
(33) < phone (34) < windows (40) < game windows: Arcade / mini-games / staff candidates (45) < heist puzzle (50) <
toasts (55) < splash and confetti (60–70) < confirmation dialog (80). Toasts sit above windows on purpose ("not enough
cash" must be readable while a shop is open). Before this update the phone (20) sat above windows (10) and several HUD
pills (30–45) could sit above an open window.

**Performance:** layout runs once per viewport or safe-area change (the test checks 0 passes in 10 s of normal play
and exactly 1 per resize) and when a window opens or closes. Nothing runs every frame; the money counter now also stops
updating once it has reached the target.

## 4. Tests

### 4a. SIMULATED TESTS (run here — not real Roblox)

Run: `python3 tests/run.py tests/<name>.lua`. Final full run on the finished code: **23 suites, 1,255 checks, 0 failed.**

**New: `mobile_test` — 157 / 157.** The test computes every element's rectangle on screen and checks, at
**390×700, 430×932, 393×852 and 375×667** (portrait):
- the phone layout switches on from the viewport size; the desktop bar, business panel and leaderboard are off the screen;
- the compact HUD has all its pieces (💰 row, ⭐ badge, story chip, event chip, 🏪, 🏆, 📱, ⚙️), every piece is inside the
  screen **and** the safe area, and no two overlap;
- **81–87% of the screen is free** for the game world (target ≥ 70%; measured with a CityBuzz notification showing), the centre is clear, and nothing sits where
  Roblox's thumbstick and jump button go;
- each of the 16 notification cards (tutorial, tips, problem, delivery, achievement, rival bubble, house tour, CityBuzz,
  story pill, beef pill, mega event, heist bag, police alert, race, interior bar, viral moment) stays in its stack,
  out of the centre, off the HUD, text ≥ 80%; a toast fits under the top row;
- 🏆 and 🏪 open as windows (≤ 92% × 85%), only one at a time, with a big ✕ inside, and the HUD steps aside and comes back;
- the phone is 82% × 78% of the screen, the game dims, all 22 apps fit its width, and Buzz / Messages / Map / Story /
  Viral fit inside it; tapping outside closes it;
- **all 32 windows** fit (≤ 92% wide, ≤ 85% tall, text ≥ 80%, ✕ inside), nothing inside any of them sticks out
  sideways, and opening any of them leaves exactly one big window open;
- the Arcade app shows 4 game cards in one column, each with ▶ PLAY inside it.

Plus: **landscape 844×390** (HUD on screen, phone and windows fit); the **main menu**, story dialogue, chapter card and
cinematic banner fit a 390-wide screen; **driving** at 390×700 (speedometer, GAS/BRAKE, 🔥/💨 on screen and clear of the 📱
button, the jump button, the thumbstick and the middle of the road; only the money row and 📱 column stay while
driving); the **Arcade lifecycle on a phone** (open → Button Battle with two players → the game window replaces the
Arcade window and fits → Leave → "Leave the game?" fits → close → reopen: exactly one Arcade window, one game window,
one request, the phone still works); **performance** (0 layout passes in 10 s of normal play, exactly 1 per resize);
and **back to desktop**: the positions, sizes, anchors, parents and z-order of 12 key elements are identical to the
original desktop layout.

| Suite | Result | | Suite | Result |
|---|---|---|---|---|
| mobile_test (**new**) | 157 / 157 | | heist_test | 100 / 100 |
| phoneapp_test | 17 / 17 | | home_test | 64 / 64 |
| admin_test | 55 / 55 | | hq_test | 56 / 56 |
| arcade_test | 38 / 38 | | interior_test | 38 / 38 |
| business_test | 24 / 24 | | perf_test | 11 / 11 |
| car_test | 36 / 36 | | phone_test | 39 / 39 |
| critical_test | 45 / 45 | | smoke_test | 5 / 5 |
| data_test | 26 / 26 | | story_test | 70 / 70 |
| estate_test | 79 / 79 | | tutorial_test | 46 / 46 |
| features_test | 156 / 156 | | v10_data_test | 15 / 15 |
| guide_test | 17 / 17 | | v9_test | 75 / 75 |
| | | | viral_test | 86 / 86 |

**Static checks:** `luau-lsp` type check clean except the known false positive at `WorldFX.lua:59` (unchanged since
v9); the property/enum check against Roblox's API dump finds 0 unknown properties or classes. The place file was
rebuilt and extracted again with no differences from the sources. `updates/GameServer.rbxmx` is byte-for-byte the v11
file.

**Test changes (not game changes):**
- `phoneapp_test`'s phone-size check used to expect a window shrunk below 100%; on phones windows now reflow instead,
  so it checks the window fits the screen with text ≥ 80%.
- `v9_test` (grand openings) failed now and then: random city events, influencer visits and funny moments share the
  feed gap and the viral score with the post the test waits for, and the client and the simulated server share one
  random-number stream, so any client change reshuffles them. The section now pauses those random schedulers first,
  like `viral_test` already does (5 / 5 runs green afterwards). Game code unchanged.


### 4b. REQUIRED ROBLOX STUDIO TESTS — not done, see section 6

## 5. Install (existing place, keeps all player data)

1. Open your Corner Empire place in Roblox Studio. **File → Save to File As…** → a backup (e.g. `CornerEmpire_before_v11_1.rbxlx`).
2. Explorer → **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click **StarterPlayerScripts**
   → **Insert from File…** → `updates/EmpireClient.rbxmx`.
3. That's it. **Don't** replace `GameServer` (it didn't change), so your Game Pass IDs in `GameServer → Config` and your
   admin `owners` in `GameServer → Admin` stay as they are.
4. Don't touch `DATASTORE = "CornerEmpire_v5"`.
5. (If you use the whole-place file `CornerEmpire_v11_1.rbxlx` instead: it has `id = 0` passes and no admin owners —
   put yours back exactly as in the v11 instructions.)

## 6. REQUIRED ROBLOX STUDIO TESTS (real mobile testing)

Studio: **Test → Device** (the device emulator, top of the viewport) → pick or add custom devices
**390 × 700**, **393 × 852**, **430 × 932** (portrait) and one landscape phone. Press **Play**. Take a screenshot of
each major screen on each size (the "📸 shot" items below).

**Layout**
- [ ] 📸 shot: the normal HUD — one money row + ⭐ badge, story chip + event chip, 🏪 🏆 on the left, 📸 ⚙️ 📱 on the right, the middle of the screen free
- [ ] Nothing is under the notch / Roblox's top-bar buttons / the home indicator
- [ ] Text is readable everywhere (nothing overlapping or cut off mid-word); report any label that's too long
- [ ] 📸 shot: ⭐ badge tapped → 📊 MY EMPIRE
- [ ] 📸 shot: 🏆 → leaderboard window (scrolls, ✕ works)
- [ ] 📸 shot: 🏪 → business window (buy/upgrade, problems, improvements, reviews all reachable; ✕ works)
- [ ] 📸 shot: the story chip → the Story app shows the objective
- [ ] A CityBuzz post shows a short notification that disappears after ~4 s; tapping it opens CityBuzz
- [ ] Only one big window at a time (open 🏪, then 📱 — the business window closes)

**Phone**
- [ ] 📸 shot: 📱 → the phone is centred, the game darkens, the HUD steps aside
- [ ] Scroll the home screen; every app opens inside the phone: Buzz, Messages, Map, Story, Viral
- [ ] Windows opened from the phone fit: Home, Garage, Staff, Properties, Stocks, Marketing, Fun & Race, Rebirth, City, Archive, Store, Weekly, HQ, Arcade, Heists, Settings
- [ ] Close with ✕ and by tapping outside; the HUD comes back

**Arcade**
- [ ] 📸 shot: 🕹️ Arcade → vertical game cards with ▶ PLAY; scrolls
- [ ] Open → close → reopen (no second window, no glitch)
- [ ] ▶ PLAY → purple beam to the booth; with a second player (Test → Clients and Servers, 2 players, both on phone size) play Button Battle → leave → reopen the Arcade
- [ ] Inside an Arcade business and at home

**Driving**
- [ ] 📸 shot: in a car — GAS/BRAKE bottom-right, 🔥/💨 above them, small speedometer top-right, thumbstick steers, nothing over the road
- [ ] GAS / BRAKE / thumbstick together feel right; the jump button still gets you out; the 📱 button still works while driving

**Building**
- [ ] 📸 shot: 🔨 Build in your home — plan on top, storage under it, Rotate / Place / Done buttons easy to tap
- [ ] Decorate a business interior: the panel is a bottom sheet and the room is visible above it

**Other**
- [ ] 📸 shot: main menu — save slots swipe sideways; New Game → starter homes swipe sideways
- [ ] 📸 shot: a story cutscene dialogue and the chapter-complete card
- [ ] Heists: bag HUD, police alert, security keypad fit and work
- [ ] Settings window scrolls and every toggle works
- [ ] Rotate the device emulator to landscape: nothing goes off screen
- [ ] Desktop (Device: none): the classic layout is exactly as before
- [ ] No red errors in Output

Only after all of this: **File → Publish to Roblox**.

## 7. Known limitations

- The safe area comes from Roblox's `CoreUISafeInsets`; the jump-button and thumbstick areas are Roblox's documented
  sizes for small screens, not measured — check them on a real phone.
- Landscape phones get the same compact layout (wider rows, the phone scaled down); there are no special two-column
  windows yet.
- Windows reflow by getting narrower; a few dense windows (Admin, Stocks, Properties) are usable but busy on a 375-wide
  screen.
- The in-game version text still says 11.0.0, because the version lives in `GameServer → Config` and the server was not
  changed.
