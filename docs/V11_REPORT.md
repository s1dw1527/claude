# Corner Empire v11 — "Secret Mountain Base & Heists" — Report

**Deliverables**
- `CornerEmpire_v11.rbxlx` — the whole place (same game, same DataStore `CornerEmpire_v5`).
- `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx` — drop-in scripts for your existing place.
- `docs/V11_STUDIO_CHECKLIST.md` — exact install steps and the real-Studio test checklist.
- `default.project.json` — Rojo.

> **Testing honesty.** Every automated result in this report comes from the repository's **simulated** Roblox
> engine (`tests/harness.lua`). It runs the real scripts with Roblox's real class/member rules, in-memory DataStores
> and simulated time — but it has **no physics, no rendering, no real networking, no real text filter, no touch or
> gamepad hardware and no real camera**. **Nothing has been tested in real Roblox Studio.** Section 9 lists what
> still has to be checked there.

---

## 1. The Arcade app bug (fixed first)

**Symptom.** Opening the Arcade app on the phone made the phone UI glitch, every time.

**Reproduced** (new `tests/phoneapp_test.lua`): one tap on the Arcade app produced **30 requests to the server in 5
seconds** (capped only by the rate limiter) and the window kept closing and reopening.

**Root cause — a feedback loop in the shared window code:**
1. The phone opens the Arcade window → the window asks the server for its data (once per opening).
2. The server's reply called `openModal` again, and `openModal` *hid every window, including the one being opened,
   then showed it again*.
3. Hiding it fired the window's "closed" signal, which reset its "already asked" flag → showing it again asked again →
   another reply → …

**Fix (root, not symptom):** `openModal` now closes only the *other* windows and never hides the one it opens (if it's
already open it just refreshes). The Arcade reply handler also only opens the window if it isn't open yet. Because
this was shared code, every window that loads data on open (HQ, garage, furniture, manager, heists…) now has the same
clean lifecycle: **OPEN → one request → ACTIVE → CLOSE → reset**.

**Regression tests (all pass):** Open → Close → Open; opening 7 times doesn't pile up rows; Arcade ↔ Buzz/Map/Messages
switching; phone home screen intact afterwards; every data window opens with a single request; Arcade → start a
2-player game → leave → reopen; inside an Arcade business; at home; phone-sized screen (window scales to fit).

---

## 2. The secret mountain base

- **Where:** north of the race track, centered at (300, −740), at the end of a new dirt road (x = 300) from North Rd.
  The area was verified free before placing anything (no existing build overlaps it).
- **Outside:** 164 rotated rock blocks forming the mountain, a crater with a lava glow and smoke, vents with faint
  orange light, red pin lights, trees, scattered rocks, and a ravine leading to a concrete **"DRAIN 7"** culvert —
  from a distance it's just a drainage opening.
- **The lever door:** a rusty lever by the culvert ("Pull lever"). Sequence: lever swings → mechanism sound → gear
  shakes → a rock-faced slab slides aside over 2.2 s → tunnel lights switch on. Server-owned, so every player sees the
  same door. It stays open while any player or car is in the doorway, re-opens if someone steps in while it's closing,
  opens from inside by itself when you walk or drive up (plus an inside panel), and closes ~10 s after the doorway is
  clear. **Nobody can be trapped.** A second door (back exit, east side) works the same way, with a valve outside.
- **The tunnel:** 26 studs wide, 18 high (the widest car is 7.6 wide, the tallest ~9.2 high), straight sections,
  concrete floor with flush drainage channels, brick walls, pipes, puddles, steam, a maintenance door and some
  graffiti. A test checks that no solid part sits in the driving lane.
- **The chamber:** 184 × 136 studs, 72 high, around a glowing lava core with a column of light. It has a catwalk
  with stairs, big pipes, red warning lights, crates, couches, a meeting table, a banner, and an **Escape Garage**
  with three bays.
- **Stations:** Job Board, the Fence (turn-in), Quartermaster (bags), Planning Room, Secret Computer, Base Upgrades,
  Garage terminal.
- **The crew** (all fictional): **The Blackrock Syndicate**. The Boss, Wheels (driver), Hawk (lookout), Sparks
  (mechanic), Velvet (fence), Glitch (hacker), Crates (quartermaster) and Static (dispatcher), each with short
  original lines. They're drawn on your screen only while you're within 220 studs, with idle moves; purely visual.
- **Discovery:** no map marker. The clues are CityBuzz rumors (only while someone hasn't found it), the vents and
  lights, the drain, the lever, and a tip when you get close. The first time inside you see "YOU FOUND THE SECRET HQ"
  and it's saved (`heist.discovered`). Jobs require it.
- **Not copied:** original layout, names, art and text; no assets from any other game.

## 3. Heists

| Target | Where | Puzzle | Panels | Lasers | Crew | Alert | Base loot pool |
|---|---|---|---|---|---|---|---|
| 🏦 Corner Bank | east end of Main St | keypad (5) | 1 | yes | 1–4 | HIGH | 15,000 |
| 💎 Gem & Gold Jewelers | west end of Main St | symbols (4) | 1 | yes | 1–3 | MEDIUM | 9,000 |
| 📦 Luxury Warehouse | west end of North Rd | wires (4) | 1 | no | 1–4 | MEDIUM | 12,000 |
| 🔌 Volt Electronics Depot | east end of North Rd | timing (3 hits) | 1 | no | 1–3 | LOW | 8,000 |
| 🚢 Northside Cargo Yard | north-west | timing | 1 | no | 1–4 | MEDIUM | 14,000 |
| 🏛️ City History Museum | north | symbols | 2 | yes | **2–4** | HIGH | 20,000 |
| 🔐 City Vault | east shore | keypad | 2 | yes | 1–4 | EXTREME | 30,000 |
| 🏎️ Prestige Car Garage | north-east | wires | 1 | yes | 1–4 | HIGH | 16,000 |

**Flow:**
1. **Opportunity:** a random target opens for 3 minutes, every 2½–4½ minutes, at most 2 at a time. It's announced
   only to players who found the base, or who are police.
2. **Start** at the entrance terminal. A crew forms: others join at the entrance, or by invite from the app.
3. **Security:** a short puzzle, generated and checked on the server. Keypad/symbols/wires show a sequence briefly,
   then you repeat it; timing needs 3 hits, timed by the server.
4. **Vault:** the door swings open and lasers blink on and off. Standing in a live laser makes noise.
5. **Loot:** hold [Grab loot] at stations; your bag fills (`BAG: $x / $y`).
6. **Alarm:** sounds when 40% of the loot is taken, your bag is full, there's too much noise, or you leave. Police get
   an alert.
7. **Escape → RETURN TO MOUNTAIN HQ:** a route marker points home.
8. **Turn-in:** entering the base pays out through the Fence. The bag is cleared before you're paid, so a double
   turn-in pays nothing.

**Values:** loot is in base units × your reputation-tier multiplier (1, 2, 15, 60, 220, 700). Heists unlock at
HOTSPOT. With a Basic Bag at HOTSPOT the bank pays about $75K; at the top tier with the Elite Bag and the Vault, up to
~$24M. That's high active income, but long cooldowns (5 min per target per player, 6–15 min per target) and the risk
keep businesses the main source of wealth.

**Bags:** Basic $5K capacity (free), Reinforced $10K ($25K), Heavy Duty $20K ($500K), Elite $35K ($10M); capacities
are base units × tier. **Base levels:**
1. Hideout
2. Garage Level ($100K): Escape Garage
3. Command Center ($1M): planning room shows the police count
4. Storage Vaults ($10M): +10% bag
5. Luxury Lair ($100M): Fence +5%
6. Underground Empire ($1B): Fence +10% and a gold bag

These are per-player perks; the base itself is shared.

**Crews:** a target's loot pool is fixed, so more people never means more money in total. Each robber banks what they
carried, at their own tier.

## 4. Police

- Go on duty at the new **police station** (west of the core, at (−140, −240)) or in the app. There's a 60 s switch
  cooldown, you can't go on duty mid-job, and police can't join robberies.
- Alerts: "BANK ROBBERY IN PROGRESS" plus a blue search circle (a local marker only police see). While suspects
  escape, updates every 15 s give an **approximate** spot (±60 studs, 90-stud circle) and escalating text ("Suspect
  last seen around Midtown", "Suspect approaching the mountain district"). Never the exact position.
- Arrest: hold [Arrest] (1.2 s) within 12 studs of a robber with loot. The prompt is on every such robber and shown
  only to police. The robber loses the loot (nothing else) and spends 20 s in a cell. The officer is paid 30% of the
  loot's value **by the city**. CityBuzz reports it.
- Police can't dominate: there's no scripted catch, there are several routes (roads, off-road, the back exit), and
  the information is approximate.

## 5. Failure states (all tested)

Arrested · left the server · died · abandoned · loot held too long (10 min after the alarm: "too hot") · the window
closed before any loot (the job falls apart) · a duplicate turn-in · another crew on the target (only one crew per
target; others join it) · server shutdown. **Loot is never saved**, so none of these can create money. Cash never goes
negative, and nothing else a player owns is touched.

## 6. Anti-exploit

The client can only ask (`hsApp`, `hsSolve`, `hsAbandon`, `hsInvite`, `hsPolice`, `hsBag`, `hsBase`, `hsState`) or
trigger prompts. The server checks the robbery state and stage, the player's role (police/robber), crew membership,
**distance** to the entrance, panel or station, the station's remaining loot, bag capacity, cooldowns, being inside
the mountain for a turn-in, and the officer's distance to the suspect. Puzzles are generated and timed server-side.
Reward amounts, loot amounts, completion state, location and robbery status are **never** read from the client.
Tested: made-up amounts and actions do nothing.

## 7. Save data — schema 11

- One new record: `heist = {discovered, done, failed, earned, best, bag, base, arrests, policeEarned}`. Migration step
  10 → 11 adds it. Loot is session-only and never saved.
- Same DataStore (`CornerEmpire_v5`), same keys, unknown fields kept, `UpdateAsync` with the save counter, newer
  saves read-only. A damaged `heist` record is repaired on its own (the original kept as `heistRecovered`).
- Self-test additions: v10 save → v11 keeps deeds, brand, HQ, garage, furniture; damaged v11 record repaired; a
  crashing v11 step is refused and the stored v10 save is untouched.

## 8. Tests

### 8a. SIMULATED TESTS (run here, in `tests/harness.lua` — not real Roblox)

Run: `python3 tests/run.py tests/<name>.lua`. Final full run: **1098 checks, 0 failed.**

| Suite | Result | What it covers |
|---|---|---|
| phoneapp_test (**new**) | 17 / 17 | Arcade bug: open→close→open, 7× reopen with no duplicate rows, app switching, 1 request per opening, after a 2-player game, in an Arcade business, at home, phone-sized screen |
| heist_test (**new**) | 100 / 100 | mountain shell/tunnel/chamber size, tunnel lane clear for cars, lever + door sync, doorway keeps door open, inside auto-open, back door, discovery; bank job end-to-end (puzzle via client pad, grabs, capacity, alarm, escape, turn-in only at base, double turn-in pays 0, cooldown); fake client requests ignored; police (alerts approximate, only police can arrest, range check, city pays the cop, jail + release, switch cooldown); fail states (disconnect, death, abandon, hot loot, window collapse); crews of 1/2/4, pool cap, crew limit; bags, base levels, Escape Garage; heist record saved, loot not saved |
| data_test / v10_data_test | 26 / 15 | schema 11, v10→v11 migration, damaged v11 record repaired, crashing step refused with stored save untouched |
| guide_test | 17 / 17 | 27 tips incl. 9 new heist tips; help topics heists/police/mountain |
| admin_test | 55 / 55 | incl. new HEISTS tools, server-side only |
| arcade_test, business_test, car_test, critical_test, estate_test, features_test, home_test, hq_test, interior_test, perf_test, phone_test, smoke_test, story_test, tutorial_test, v9_test, viral_test | all pass | every v5–v10 system (regression) |

**Performance (simulated, 40 min):** world parts 26,907 → 27,551 → 27,621 (stable, no leak); 15.0 DataStore
writes/min (within limits). Heist/door/police logic runs on 0.5–2 s loops, no per-frame scans.

**Static checks:** `luau-lsp` type check — clean except one known false positive (`WorldFX.lua:59`, unchanged since
v9); property check against Roblox's API dump — 0 unknown properties/classes.

**Bugs found and fixed during testing:**
- Arcade loop (root cause in `openModal`, see §1).
- `soundAlarm` overwrote the alarm time on repeat triggers, resetting the "too hot" timer → only set once now.
- The inside door panel stuck into the tunnel driving lane → moved flush to the wall.
- Ravine wall overlapped the lever → ravine widened, lever moved.
- `viral_test` was flaky (random background events landing in its time window) → the test now pauses those
  schedulers; 5/5 consecutive runs green. Game code behavior unchanged.

### 8b. REQUIRED ROBLOX STUDIO TESTS (not done — must be done by you)

**No test has been run in real Roblox Studio.** Physics, rendering, real networking, real devices and real
DataStores are not covered above. Use the full checklist in `docs/V11_STUDIO_CHECKLIST.md` §3 before publishing.

### 8c. Migration notes

- DataStore name unchanged: `CornerEmpire_v5`. No new DataStore.
- Schema 10 → 11 adds only `heist = {discovered=false, done=0, failed=0, earned=0, best=0, bag=1, base=1, arrests=0,
  policeEarned=0}`. Nothing else changes; unknown fields are preserved.
- Players who join on v11 are migrated on load automatically. A save written by v11 opened by an older server is
  read-only there (existing v10 protection).

## 9. Still needs testing in real Roblox Studio

See `docs/V11_STUDIO_CHECKLIST.md`. In short:
- **Physics:** cars through the tunnel and into the chamber (especially the Monster Truck), the door sliding against
  players, laser positions vs. real characters, arrests during real car chases.
- **Rendering:** the mountain silhouette and rock blocks on real terrain, lighting inside the chamber, NPC look and
  bubbles, the police search circle, the bag on R6 and R15 avatars, the door sound ids (placeholders from Roblox's
  built-in sounds, configurable in `C.MOUNTAIN.sounds`).
- **Real networking:** 2–4 real players (door sync, crew joins, police alerts), latency on the timing puzzle.
- **Devices:** the Heists app, puzzle window and bag HUD on phones and tablets; controller input.
- **The original Arcade glitch on a real phone:** the logic loop is fixed and tested; confirm the visuals on device.

## 10. Known limitations

- Robbery buildings are compact (lobby + vault). There are no multi-room obstacle courses beyond the panels and lasers.
- Base upgrades are per-player perks; the shared base looks the same for everyone.
- Police are players only; with no police online, robberies are only limited by time and cooldowns.
- No map marker for the base (by design). The Heists app explains how to find it.
- The game doesn't dismount players from cars on arrest beyond despawning the car. Check this in Studio.
