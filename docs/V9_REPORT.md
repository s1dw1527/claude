# Corner Empire v9 — "Empire Life & Viral Moments" — Report

**Deliverables:**
- `CornerEmpire_v9.rbxlx`: the same game and the same DataStore, upgraded, not rebuilt.
- Drop-in scripts: `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx`.
- Rojo: `default.project.json`.

**How v9 was tested.** Everything below was run in the repository's simulated Roblox engine (`tests/harness.lua`):
- It runs the real server and client scripts with in-memory DataStores and simulated time.
- It rejects any property or method that doesn't exist on a real Roblox class.
- It has **no physics, no rendering, no real touch or gamepad hardware, and no real animation playback.**

Anything that depends on those is listed under **"Still needs testing in Roblox Studio"**.
**Nothing in this report has been run inside the real Roblox Studio.**

---

## 1. What changed (summary)

| Area | What v9 adds | Built on (reused, not duplicated) |
|---|---|---|
| Business interiors | A real layout per business, scaled by level, with your logo and a manager's office | v8 `Interiors` (rooms, doors, decorating, saving) |
| Interior score | 0–100 with tiers EMPTY / BASIC / DECENT / PROFESSIONAL / ELITE / VIRAL, shown on the business card | v8 decor items and styles |
| Staff and customers inside | Cashier, cook, cleaner and manager routines; customer life with rare behaviors | v8 staff roster (names) and satisfaction |
| Cinematics | A reusable controller plus scenes for every interaction in the brief | The story's cutscene actors, now a shared `Actors` kit |
| Eviction | An 8–12 s cartoon eviction (knock, notice, boxes, a bouncing item, door closes) | v6 tenants and eviction rules (unchanged) |
| Grand openings | A signature moment per business, plus an optional crowd joke | v6 business purchase |
| Influencers | Bay Snaps, Jax Cash, Maya Max and Drew Deals: original characters | v8 Messages (Drew's offers), CityBuzz |
| Viral Moments | Scoring, cooldowns, uniqueness, CityBuzz posts, Lil Clipz reactions | v6 CityBuzz feed, v7 story, v6 weekly boards |
| Rare and funny events | THE CROWD, PAPARAZZI, EVERYONE KNOWS YOU, BUSINESS BEEF; inspector, customer army, delivery disaster, rich kid, bad investor | Real customers (`serveCustomer`), reputation |
| VIRAL phone app | Score, moments, sightings, trending, funniest, top posts, weekly boards, Hall of Fame | The phone app kit |
| Weekly Most Viral boards | 7 categories, reset weekly, top-3 finishes kept forever | v6 `Weekly` storage |
| Achievements | Kick Rocks, Landlord Mode, WHO INVITED EVERYONE?, Main Character, Internet Famous, Actually Famous, Bro Got Content, Empire Influencer; first-business renamed "Open for Business" | v6 achievements (keys unchanged) |
| Photo Mode | 📸 during cinematics pauses the scene; a "📸 Capture" button on every viral moment; 5 new reaction poses | v6 Photo Mode |
| Player reactions | celebrate, facepalm, confused, pointing, shocked, laughing, thinking, arms crossed, money, owner pose | `AnimationConfig` (new) |
| Studio tools | 11 new 🧪 buttons (listed in §9) | v8 Studio tools (server refuses them outside Studio) |
| Data | Schema 9 migration, a repair-never-fail rule for v9 data | v8 `DataMigration` and save pipeline (unchanged rules) |

---

## 2. Files changed

**New, server (`ServerScriptService > GameServer`):**
- `Cinematics`: when a scene plays and what is said (all dialogue), plus the anchor points.
- `ViralMoments`: the moment registry, score, cooldowns, CityBuzz, capture, detectors, weekly boards and Viral app state.
- `Influencers`: the four characters, the visit scheduler, talking, rewards, Drew's deals and despawning.
- `CityEvents`: rare viral events, funny random events, Bay Snaps' live challenge and Business Beef.

**New, client (`StarterPlayerScripts > EmpireClient`):**
- `AnimationConfig`: every animation id in one place, with the fallback chain.
- `Actors`: the shared part-built NPC kit (looks, props, procedural moves, bubbles, effects).
- `Cinematics`: **the CinematicController** (stage, camera shots, actors, props, dialogue, Skip and 📸, cleanup) and the scene templates.
- `CityLife`: what everyone sees (influencers, crowds, paparazzi, passers-by), the viral pop-up, the beef tracker and crash detection.
- `InteriorLife`: staff routines and customer life inside the room you're in.
- `ViralApp`: the 📱 VIRAL phone app.

**Changed:**
- **Server:**
  - `Config`: version 9.0.0 / schema 9, notes, 8 achievements, funny review lines.
  - `DataMigration`: the 8 → 9 step, `repairViral`, v9 samples and self-tests.
  - `Players`: save keys, the load-time repair, the setting, debug dispatch, state, catalog cast, hire/fire scenes.
  - `Interiors`: the per-business layouts, waypoints, the 0–100 score and tiers, room info, "Go inside".
  - `Systems`: customer, review, opening, upgrade, investor and war hooks.
  - `Rentals`: eviction counting, scene and moment; property scenes.
  - `Cars`, `Housing`: luxury moments and scenes.
  - `Social`: Drew's message choices.
  - `Weekly`: shared storage and the champion scene.
  - `Util`: 2 new remotes.
  - `GameServer.server.lua`: the module list.
- **Client:**
  - `Story`: now uses the shared actor kit, and waits for cinematics.
  - `Phone`: the Viral app icon.
  - `HUD`: the interior row on the business card.
  - `Menus`: the Cinematics setting and the 🧪 tools.
  - `PhotoMode`: the reaction buttons and a narrow-screen scale.
  - `MainMenu`: stops scenes and city NPCs when you return to the menu.
  - `UI`: the setting default.
  - `EmpireClient.client.lua`: the module list.
- **Tests and tools:**
  - New: `tests/v9_test.lua`, `tests/viral_test.lua`.
  - Updated: `tests/data_test.lua`, `tests/story_test.lua`, `tests/common.lua`, `tools/order.json`.
- **Docs:** `README.md`. The v9 section and the update guide mention schema 9.

---

## 3. New systems

**CinematicController** (`EmpireClient > Cinematics`):
- **Scenes:** the server sends `{kind, at = CFrame, lines, result, mode, react, moment}`. The client runs a template on a *stage*, which provides `shot`, `actor`, `walk`, `say`, `toss`, `swing`, `part` and `wait`.
- **Modes:**
  - FULL takes the camera, with letterbox bars, and hides the HUD.
  - SHORT acts the scene out in the world, with bubbles and no camera change, and draws actors only if you're within 170 studs.
  - OFF shows only the result banner.
- **Skipping:** always possible. Use the Skip button (122×44, top-right), Backspace, or controller Ⓑ. Space or Ⓐ advances a line.
- **Safety:** scenes queue (at most 3, oldest dropped), wait for story cutscenes and Photo Mode, and switch to SHORT while you drive.
- **Cleanup:** always runs, even after an error, a respawn or a return to the main menu.
- **Every v9 scene uses the same controller:**
  - Interactions: eviction, hire, fire, buy property, grand opening, major upgrade, customer complaint, inspection.
  - Big moments: competition win, huge investment, luxury purchase, influencer visit.
  - Events: Lil Clipz reactions, customer army, delivery disaster, rich kid, bad investor.

**ViralMoments:**
- 25 moments. Each has a score, a category, an importance, a cooldown and/or "once" rule, a chance, CityBuzz lines and optional Lil Clipz lines.
- **Feed limits:** a server-wide gap per importance stops spam: low 90 s, normal 40 s, high 15 s, legendary 0 s.
- **Score values:**
  - +50 influencer visit; +100 influencer post.
  - +250 rare events; +500 EVERYONE KNOWS YOU; +1,000 THE FULL SET (all four influencers post about you in one week).
- **Detectors** watch real play:
  - 100 customers in a minute.
  - 25 at one business in 30 s.
  - 1-star reviews (35% chance).
  - A crash into your own business.
  - Mansion plus a tiny lemonade stand.
  - ELITE and VIRAL interiors.
  - Luxury purchases, evictions, grand openings, selling a building.

**Influencers:**
- At most one visit at a time. The first comes 4–7 minutes into a server; visits are then 6–11 minutes apart.
- They target the player who was visited least recently, and they stay 2 minutes.
- Everyone sees them: a 🚨 marker, a toast, and a CityBuzz sighting. Only the target can trigger the visit.
- Bay Snaps can bring THE CROWD (35%) or a live challenge (30%). Jax Cash can bring the paparazzi.
- If nobody comes, they leave with a 💀 post. If the target leaves the game, they leave at once.

**CityEvents:**
- A funny event per player every 7–12 minutes; never during the tutorial.
- Business Beef happens on about 12% of those rolls.
- Rare events are capped and time-limited:
  - THE CROWD: 14 NPCs, 40 s, 25 real customers.
  - PAPARAZZI: 5 photographers, 30 s.
  - EVERYONE KNOWS YOU: 3 minutes, local to you.
  - BUSINESS BEEF: 4 minutes.

---

## 4. New animations

**Player reactions:** `EmpireClient > AnimationConfig.REACTIONS`. You can paste your own ids. The fallback order is:
1. Your animation id, played on the Animator.
2. A built-in Roblox emote.
3. A floating emoji (always works).

| Reaction | Default id (Roblox R15 emote) | Fallback emote | Emoji |
|---|---|---|---|
| celebrate | rbxassetid://507770677 (cheer) | cheer | 🎉 |
| pointing | rbxassetid://507770453 (point) | point | 👉 |
| laughing | rbxassetid://507770818 (laugh) | laugh | 😂 |
| wave | rbxassetid://507770239 (wave) | wave | 👋 |
| dance | rbxassetid://507771019 (dance) | dance | 🕺 |
| money | — (add yours) | dance | 💸 |
| facepalm, confused, shocked, thinking, armsCrossed, ownerPose | — (add yours) | — | 🤦 🤔 😱 🧠 😤 😎 |

- The default ids are Roblox's standard R15 emote animations. **They are not verified in Studio:** they won't play on R6 avatars, where the emote or emoji fallback is used.
- A missing or broken id never stops anything. It is logged once in Studio's Output.

**Actor moves:** 40 procedural moves, used by every scripted NPC. Unknown moves fall back to `idle` and are logged in Studio.
- idle, walk, run, talk, point, laugh, clap, shrug, shock, kneel, hype
- knock, wave, show, flail, carry, throw, gesture, facepalm, crossed, think, money, owner, celebrate
- sit, eat, phone, sitphone, selfie, wipe, cook, type, clipboard, lift, stir, sweep, dramatic, flash, look, entrance

---

## 5. New NPCs

All of these are original designs, built from parts in `Actors`. No real people, faces, names, voices or outfits are used.

**The influencers:**
- **Bay Snaps:** chaotic livestreamer. Teal shirt, orange jacket, yellow beanie, pink shades, selfie stick with a ring light, 🔴 LIVE sign.
- **Jax Cash:** luxury influencer. Navy suit, gold tie, gold shades, car keys.
- **Maya Max:** lifestyle creator. Lavender jacket, mint pants, bucket hat, camera.
- **Drew Deals:** green checked suit, red tie, cap, briefcase.

**City people:**
- tenant, health inspector (fedora, clipboard), photographers, rich kid (gold crown, gold card), investor (briefcase), delivery driver (pizza box)
- crowd members (random, seeded looks)

**Interior staff:**
- cashier, cook, cleaner (mop), manager (tie, clipboard), factory workers
- Each wears its business's uniform. The hired staff member's and the manager's names are shown.

**Customers:** random looks, carrying their order (cup, tray, pizza box, phone).

---

## 6. New interiors

| Business | Layout (grows with level) |
|---|---|
| 🍋 Lemonade | counter, register, lemonade machine (2 tanks), jugs, cup stacks, menu board, lemon crates, 2 small tables |
| 🍦 Ice Cream | ice cream display case with tubs, freezers, toppings bar, menu, tables, employee lockers |
| 🥐 Bakery | display cases with bread and pastries, 2–3 ovens, mixing/prep table, bread shelves, register, seating, office (Lv 5+) |
| ☕ Coffee | 2–3 espresso machines, counter, pastry display, couches with a coffee table, table, menu, employee area, office (Lv 5+) |
| 🍕 Pizza | 2–4 pizza ovens, dough prep tables, counter, menu, tables, delivery pickup with box stack, office (Lv 5+) |
| 🕹️ Arcade (56×38, walkable) | 6–14 cabinets, 2–4 racing machines, prize counter, neon strips on every wall, HIGH SCORES board, benches, office (Lv 5+) |
| 💻 Tech | wall of 12 screens, electronics shelves, repair workbench, customer counter, 1–3 testing stations, office (Lv 5+) |
| 🏭 Factory (80×52) | 2 conveyor belts (goods move), 2–5 machines with pistons, storage racks, loading dock (striped floor, roll-up door, pallets), 3 worker stations, management office |

- Every business room also has your logo on both side walls and on a floor rug, and the owner's name over the door.
- Room part counts measured in the test: 63–129 parts per room.
- Rooms are built only while someone is inside, and removed a minute after they empty.
- **Fixed:** the name sign over the inside of the door faced the wall since v8. It now faces into the room.

**Interior score** = style (walls, floor, lights: up to 40) + decorations (up to 50; a repeated item counts half) + how many spots are filled (up to 10).
- It raises satisfaction by up to +10 and the house stars. **It never changes income.**
- Removing decor is free and refunds nothing, as in v8, so there's no buy/remove loop.

---

## 7. Save migration (schema 8 → 9)

- **DataStore unchanged:** `CornerEmpire_v5`, keys `u<UserId>_s<slot>`, nothing renamed or wiped. Studio still uses `_StudioTest` copies.
- **Step 8 → 9** adds defaults only:
  - `viral = {score = 0, mentions = 0, log = {}, seen = {}, cd = {}, hall = {}, week = 0, weekScore = 0, cats = {}}`
  - `evictions = 0`
  - `openings = {}`
- **New saved fields:** `viral`, `evictions`, `openings`. Inside `viral`, `posted` tracks the influencers' weekly posts.
- **A broken new feature can't block a save.** If the viral record (or `evictions` / `openings`) is damaged:
  - Only that part is reset.
  - The rest of the save loads and saves normally.
  - The damaged original is kept in the save as `viralRecovered`.
  - This runs in `DataMigration.validate`, and again at load time inside a `pcall`.
- **Everything from v8 still applies:**
  - Migration runs on a copy and is validated before use.
  - A failed load or a failed migration means no save for that session; the stored save is untouched.
  - Newer-schema saves are read-only.
  - `UpdateAsync` with a save counter.
  - Unknown fields are carried through.
- **Tested in the sim:**
  - A real v8 save with no v9 fields, through the join flow: every v8 field intact, v9 defaults added, saved back as schema 9.
  - A damaged v9 record: the rest loads, the original is kept.
  - A crashing 8 → 9 step: refused, the v8 save is untouched.
  - The v5–v9 samples: 12/12 self-test checks pass.
  - Leave and rejoin keeps the Viral Score, moments and Hall of Fame.

---

## 8. Performance protections

- **Cinematics:**
  - Only the player involved gets a scene; nothing is broadcast.
  - Actors are anchored, non-colliding parts with no Humanoids or physics, and they're destroyed when the scene ends.
- **City events:**
  - A shared cap of 24 NPCs, +4 for an influencer.
  - Built only within 260 studs of your camera, and animated only within 160 studs.
  - Removed when the event ends.
  - Tested: a crowd across the city builds 0 NPCs. Crowd, paparazzi and passers-by at once peaked at 21 NPCs.
- **Interior life:**
  - Runs only while *you* are inside a room, at most 5 staff and 8 customers.
  - Logic ticks 10×/s; posing happens every frame for those few only.
  - Everything is removed when you leave.
- **Server:**
  - Event checks run every 3 s per player and are cheap.
  - Viral boards refresh one category every 40 s (about 1.5 DataStore reads per minute).
  - Interior and empire "best" values publish every 2 minutes.
  - The perf soak test passes (40 minutes, 4 players, DataStore budget, network size).
- **Server authority:**
  - Every reward and state change is decided and applied on the server; the client only draws.
  - The crash report is the only client-originated signal. The server checks that you are seated in your own car next to your own business, and that the speed is believable. It gives Viral Score only, on a 10-minute cooldown.

---

## 9. Studio-only test tools (Settings → 🧪; the server refuses them outside Studio)

- **New in v9:**
  - eviction cinematic (evicts nobody), grand opening, influencer visit, viral moment
  - rare event (paparazzi), CityBuzz post, customer rush (THE CROWD), inspection
  - funny random event, enter a business interior, cinematic camera
- **From earlier versions:** money, reputation, mega event, mystery lot, Spire, go viral, save, update + data safety test, story jump.

---

## 10. Tests

All results below are simulated, in the strict-API engine.

| Suite | Covers | Result |
|---|---|---|
| `v9_test` (new) | v8 save without v9 fields; damaged v9 record; migration self-test; eviction state vs scene; skip by button, keyboard and controller; FULL/SHORT/OFF; missing animations and unknown scenes; grand openings once per business; hire/fire scenes; **two players evicting at once**; **eviction while another player visits**; **disconnecting during an eviction**; **main menu mid-scene**; Landlord Mode; all 8 interiors (fixtures, waypoints, part counts, office, factory size); score tiers and card; staff routines and customer life; ownership isolation | **75/75** (passed 3 runs in a row) |
| `viral_test` (new) | score, cooldowns, once-only, anti-farming, no cash from score; CityBuzz anti-spam; pop-up and capture (once, expiry, made-up ids); detectors (crowd at one business, 1-star, crash with and without a car, impossible speed, billionaire lemonade); Lil Clipz; **influencer spawn, sighting for everyone, target-only rewards, one talk per visit, despawn, despawn when the target leaves**; Maya; Drew's deals (EV 0.92×); THE CROWD with real customers and cleanup; far-away events cost 0 NPCs; NPC cap; Business Beef win; **business sold mid-beef and mid-crowd**; all 5 funny events; Viral app (all tabs); weekly boards and Hall of Fame; all 8 achievements; save and rejoin | **86/86** (passed 3 runs in a row) |
| `smoke` | boot | 5/5 |
| `critical` | earlier audit fixes | 45/45 |
| `features` | v6 systems | 156/156 |
| `tutorial` | the whole tutorial through the client (no cinematics during the tutorial) | 46/46 |
| `story` | story mode (now on the shared actor kit) | 70/70 |
| `data` | save safety (updated for schema 9) | 26/26 |
| `phone` | Messages, Map, Story app, CityBuzz | 39/39 |
| `business` | business card, improvements, reviews | 24/24 |
| `interior` | v8 interiors, decorating, house ratings | 38/38 |
| `perf` | 40 min, 4 players, with every v9 system running | 11/11 |

- **Total: 621 checks, 0 failing.**
- **Economy sim** (casual bot, 12 h, all v9 events running): progression is unchanged within run-to-run variation.

  | Milestone | v7 | v9 |
  |---|---|---|
  | $1M | 22 min | 24 min |
  | $100M | 2h27m | 2h32m |
  | $1B | 5h37m | 5h54m |
  | All 8 businesses | 7h17m | 8h28m |

  Customers' share of income rose from 3.5% to 4.6% (crowds, customer armies). Viral Score never pays cash, and Drew's deals average 0.92×.
- **Static checks:**
  - `tools/propcheck.py`: 0 unknown property names.
  - `tools/check.sh` (luau-lsp): only the known false positive at `WorldFX.lua:59`.

**Bugs the new tests caught (fixed before shipping):**
- **Removing one NPC destroyed every NPC in its folder.** `Actors.destroy` deleted the shared folder reference stored on each actor. The first customer to leave an interior made every other NPC invisible; city crowds were affected too.
- **Capturing a moment created a new capturable moment**, with its own Capture button.
- **Re-entering an existing room showed stale staff and level info.** The room info is now refreshed on entry and every 15 s.
- **Going back to the main menu mid-cinematic re-enabled the game HUD over the menu.**
- **The inside-door name sign faced the wall** (since v8).

### Still needs testing in Roblox Studio (not covered by the simulation)
- **How everything looks:** interior layouts and lighting, the actors' proportions and poses, props in hands, crowd placement, the eviction slapstick timing (target 8–12 s), the grand-opening effects (mist, steam, spinning pizza, lights, screens, machines).
- **Camera:** cinematic shot framing in real buildings, walls blocking shots, letterbox on different aspect ratios.
- **Animations:** whether the default R15 emote ids play on your avatars, and how R6 avatars fall back.
- **Input on real devices:** the Skip button and 📸 on phones and tablets, controller Ⓑ / Ⓐ / D-pad, gamepad selection of the Capture button, the Photo Mode bar on narrow screens.
- **Physics-based crash detection:** a real car hitting a real building (the server-side check is tested; the impact itself can't be).
- **Live servers:** weekly Viral boards on real OrderedDataStores, CityBuzz sightings across 4 real players, frame rate with a crowd, paparazzi and a full interior on low-end phones.
