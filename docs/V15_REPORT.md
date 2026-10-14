# Corner Empire v15 — Life & Empire: Funland (Studio fixes, Amusement Park, Fun Park, graphics)

**What this is.** After testing v14 in Studio you reported:
- random cars stopped in the middle of the road;
- benches and trees in the street;
- trees blocking the mountain base path;
- nothing in the mountain base opening (job board, computer, planning room);
- no way to buy the movie theater;
- a bland Fun Park.

You asked for a roller coaster, people with cotton candy, an amusement-park business where you build your own rides,
and better graphics and systems. All of it is in **v15** (in-game name "Life & Empire: Funland").

**Data:** same DataStore **`CornerEmpire_v5`**. Save schema **14 → 15**, additive only: it adds one record, `park`
(section 3). Nothing was published. **Install both** `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx`
(section 2).

> **Testing honesty.** Every result in this report comes from this repository's **simulated** Roblox engine
> (`tests/harness.lua`). It runs the real game scripts, but it does not render, has no real physics, no real touch
> input, no real networking and no real DataStores (they live in memory). **Nothing in v15 has been run in Roblox
> Studio or on a phone.** Section 6 is the Studio checklist. Start with the items marked ★: they are the bugs you
> found.

## 1. What changed

### Fixes for what you found in Studio

**Benches, trees and props in the street.** A new test, `layout_test`, checks every solid part the city builds
against two things:
- every road lane;
- every reserved path (a new `C.PATHS` list of the mountain road, the heist driveways, the Funland walks).

It found more than you reported. All of these were fixed:

| what | where it was | fix |
|---|---|---|
| 6 plaza benches | 1 stud into the ring road | moved onto the plaza sidewalk |
| trees and rocks | on the mountain dirt road and the heist driveways (the scatter never knew those paths existed) | paths reserved before the scatter runs; terrain cleared along the mountain road |
| era skyscrapers | could land in the mountain base area | only built on free land |
| race start gantry | a pole in the race entrance road | moved off the road |
| dealership "Trail SUV" | parked across the end of Central Ave | moved into the row |
| Hillside gate | stood on North Rd | moved to the ramp |
| a race barrier, the mountain apron, the heist driveways | overlapped the secret door and the site gates | shortened |

**Cars in strange places.**
- A recycled traffic car was shown before it was moved, so it flashed at its old spot. It is now placed first.
- Main St and Central Ave cross under the Empire Spire. Traffic and the NPC police now drive around the plaza ring
  instead of through the tower.
- A car waiting more than 6 s at a dead end is recycled instead of standing in the road.

**Mountain base: nothing opens.** The code path from prompt to window was intact (your Output showed no errors), so
the stations were made reachable and given a backup:
- Each station's prompt now sits on its own invisible spot 3 studs in front of the counter, at chest height, facing
  you, with a glowing floor mark showing where to stand. Before, the prompts were on the counters, and the crew NPCs
  stood inside the counters.
- The crew stand behind the counters. The quartermaster's crate stack and the stairs were moved out of the way.
- If a station's handler is ever missing or errors, the prompt still opens the right Heists tab.
- New **⛰️ BASE MENU** card while you're inside the base: Jobs / Gear / Computer buttons open the same screens.

**The movie theater can't be bought.** It could only be bought by walking to a "for sale" sign, and the theater
window's button opened the wrong menu (Rental Row).
- The business card now says **🏙️ OPEN ON A CITY PLOT** instead of BUY, and opens a new **plot picker**:
  - **Your plots:** each with "Open it here".
  - **Buy a plot and open it there:** every district, with the total price (plot + business) or the reason you can't
    buy there yet (🔒 reputation, the property limit, no free plot).
- The purchase is one server-checked step: it checks both prices before buying anything, so there's no half
  purchase.
- The plot chooser stays open when the server refuses, so you can see the reason.
- The same picker opens the Amusement Park.

### 🎢 Amusement Park (business #10, unlocks at CITY ICON)

- **Opening.** Like the theater, it opens on a city plot. The plot gets the ticket gate: an arch with chasing lights,
  a turning mini Ferris wheel on the roof, a kiddie carousel, and a 🎢 *Go to the park* prompt. Inside the building
  are guest services and a gift shop.
- **Your site.** The park itself is your own site at the new **Funland Grounds**, west of the Fun Park:
  - 4 sites of 20 × 24 cells (80 × 96 studs) along a lit promenade with an entrance arch.
  - Handed out when your park is open, like home plots, and freed when you leave.
  - Your park stays in your save while you're away.
  - Anyone can walk in, and there's a "Visit" list in the app.
- **Build.** The 🎢 Park app has a Build tab: a top-down plan of your site. Pick from the shop, tap a cell, and it's
  built. Tap something to ✋ Move it, 🔄 Turn it, or 💵 Sell it (half back, after a confirmation). The catalog:

  | kind | items |
  |---|---|
  | rides | 🎠 Carousel, ☕ Teacups, 🎡 Ferris Wheel, 🚗 Bumper Cars, 🌀 Swing Ride, 🏴‍☠️ Pirate Ship, 🐛 Junior Coaster, 🗼 Drop Tower, 🎢 Loop Coaster |
  | food stalls | 🍭 Cotton Candy, 🍿 Popcorn, 🎈 Balloons, 🍦 Ice Cream |
  | decorations | 🌷 flowers, 🪑 bench, 💡 lamp, 🌳 tree, ⛲ fountain |
  | paths | 🟫 Path |

  Bigger rides unlock with the park's level. The piece cap grows from 24 to 84.
- **The server checks every placement:**
  - it's your own open park, inside the grid, and not over another piece;
  - the gate stays clear (paths are fine there);
  - the ride is unlocked, you're under the cap, and you have the cash;
  - only whole numbers, rotations 0–3, and known kinds are accepted.
- **Rating → sales.** The rating (0–100) adds up:
  - exciting rides (a second copy of the same ride counts less than something new);
  - variety;
  - food stalls to go with the rides;
  - decorations and paths.

  It raises the park's sales from ×1 to **×1.8** (capped), sets how many visitors walk around, and shows on your gate
  sign.
- **Riding.** Every ride has a 🎢 *Ride* prompt:
  - The camera rides the car, horse, gondola or swing for the ride's length (one lap for a coaster), then comes back.
  - The server checks you're next to the ride, one ride at a time, with a short cooldown.
  - When another player rides, the owner gets a ticket (a few seconds of the park's income) and a little reputation,
    up to 30 an hour.
- **Rides that move:**
  - The carousel, teacups, Ferris wheel, swings and bumper cars turn.
  - The pirate ship swings, and the drop tower climbs slowly, then drops.
  - The coaster trains follow their track: slow up the lift hill, fast down the drops, upside down through the loop.
  - All of it runs on each client from the server clock, so every player sees the same thing.
- **Visitors.** People walk your paths, some with cotton candy or a balloon. How many depends on your rating. They're
  pooled and only appear near you. With no paths yet, they wait inside the gate.
- **Hooks:**
  - a 🎢 *Thrill builder* prestige goal (a park rated 80+);
  - Summer Beach Fest asks for 5 rides;
  - the rival Pixel Palace also goes after parks;
  - new staff role "Ride Operator", products (Day Pass, Cotton Candy, Fast Pass…), a Rush Orders recipe, an opening
    cinematic (ribbon cut, balloons) and its update notes.

### 🎡 The Fun Park makeover

- **🎢 The Big Dipper**: a big roller coaster round the south side of the park.
  - A 32-stud lift hill, a big drop, camelbacks and a full loop, with a 4-car train.
  - A station with a roof, a lit sign and a 🎢 *Ride* prompt: you ride in the front car for one lap. It costs the same
    as the Ferris wheel.
- **🗼 Sky Drop** (drop tower) and **🌀 The Whirl** (swing ride), each with a Ride prompt.
- **Stalls and people:**
  - Food stalls: 3 cotton candy, popcorn, ice cream, balloons.
  - Each stall has a vendor and a queue of people holding cotton candy or a balloon.
  - Groups of friends with cotton candy and balloons stand along the walkway.
- **Decoration:** strings of chasing lights over the walkway, and a fountain.
- Note: Main St runs through the Fun Park. The layout test caught that and keeps every new prop and person off it.

### Graphics and feel

- **Sky:** a real sky with sun, moon and 3,000 stars (the default skybox, no image assets), and softer shadows.
- **Time of day:** a grade that follows the clock:
  - warm sunrise and sunset;
  - cool blue nights, where a night bloom makes neon signs, lamps, ride lights and marquees glow.

  The weather and event grades are separate and untouched.
- **Streets:** trees in round planters and bins along the city sidewalks. They're never near a crossing, a bus stop or
  a reserved path, and the planters don't block a car cutting across.
- **Performance:** chasing-light strings only animate within 320 studs of the camera, and coaster trains within 450.

## 2. Install (existing place, keeps all player data)

1. Studio → **File → Save to File As…** → make a backup (e.g. `CornerEmpire_before_v15.rbxlx`).
2. **Write down** your pass IDs (`GameServer → Config → C.PASSES`) and your `owners = {…}` (`GameServer → Admin`).
3. **ServerScriptService** → delete `GameServer` → right-click → **Insert from File…** → `updates/GameServer.rbxmx`.
4. **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click → **Insert from File…** → `updates/EmpireClient.rbxmx`.
5. Put back your pass IDs and `owners = {YOUR_USERID}`.
6. Do **not** change `DATASTORE = "CornerEmpire_v5"`.
7. **Lighting → Technology → ShadowMap** (or Future, if your players' devices can take it). Scripts can't set this.
   The v15 sky and night glow work with any setting, but shadows look best with ShadowMap.
8. Game Settings → Security → **Enable Studio Access to API Services** to test saving (Studio uses the separate
   `_StudioTest` stores).
9. Run the Studio checklist (section 6), then publish yourself.

For a new place instead, open `CornerEmpire_v15.rbxlx`, set the pass IDs and owner, set Lighting.Technology, test,
then publish.

**Rollback:** reopen the backup. A v15 save still loads in v14, because the `park` record is kept untouched as an
unknown field. A v14 server would see `levels.park` as an unknown business and ignore it.

## 3. Data migration notes

Migration step 14 → 15 (`DataMigration.steps[14]`, `M.v15Defaults()`) adds this record only if it is missing:

| field | default | what it holds |
|---|---|---|
| `park` | `{items = {}, stats = {}, visitors = 0, rides = 0, guestRides = 0, best = 0}` | the rides you built (`{id, k, x, z, r}`), visitor and ride counts |

- Every other field, including unknown future fields, is kept.
- `levels.park` simply starts missing (0).
- A damaged park record is repaired field by field. Pieces that don't fit (unknown kinds, off the grid, overlapping)
  are kept aside in `park.lost` instead of thrown away, and the rest of the save loads (tested).
- If the step crashes, the migration is refused and the stored v14 save stays untouched (tested).
- In-game self-test samples were added: a full v14 save (theater, rivals, loft, prestige, unknown fields), a broken
  v15 save, and a crashing v15 step.
- No new DataStores.
- Interior rooms: the park uses row 10, which was free.

## 4. Tests — SIMULATED (not Roblox Studio)

**Final run, on the final code: 42 suites, 1,945 checks, 0 failed** (simulated engine, all suites in parallel, 4 at a
time, including the 40-minute 4-player soak test `perf_test`). Earlier full runs during development turned up:
- 2 real problems, both fixed:
  - the layout test caught new Fun Park props on Main St, which runs through the park;
  - `city_test`'s crowd part budget was exceeded by the new Fun Park scenes. They are now built only the first time
    you come near.
- 3 timing problems in new test checks: a city cinematic taking the camera as a ride ended, random cash events
  during a purchase check, and a mismatched confirm button. Each was confirmed (e.g. 6 parallel runs with a debug
  print) and the checks were made tolerant.

New and extended suites:

| suite | what it checks |
|---|---|
| `layout_test` (new) | every solid part vs every lane and reserved path; plaza benches; no traffic through the Spire (server and client); a clear car-wide mountain road |
| `park_test` (new) | opening through the real menus; site handed out; the Park app and build plan; 10 kinds of refused placement (overlap, gate, edge, locked, made-up kind, half cells, bad rotation, huge numbers, bad shapes, no cash, no park, piece cap); move/turn/sell through the UI with confirmation; rating parts, variety, the ×1.8 cap; spinning rides, the drop tower and the coaster train moving in sync with the server clock (upside down in the loop, lift hill); riding (camera, banner, held in place, back after); guest tickets and reputation, range and one-at-a-time checks; visitors on the paths with cotton candy; a second player's site, visiting, freeing a site on leave; closing and reopening; the save; a damaged record |
| `funpark_test` (new) | Big Dipper size, supports, position (off the booths and the road), train moving, loop, lift speed vs drop speed, 4 cars; riding (locked before the Fun Park unlocks, fee, camera in the car, one at a time, camera back after a lap); Sky Drop and the Whirl moving and rideable; stalls built and the client's queues at the same places; people with cotton candy; nobody on Main St; string lights; the occasion task |
| `graphics_test` (new) | sky, time-of-day grade (night blue + glowing, sunset warm, day off), applied by the day/night loop; street trees and bins (count, none in the Fun Park, non-blocking); chasing lights animate only near you |
| `heist_test` (+) | each station's prompt spot reachable (nothing solid between you and it), opens the right tab through the real client, the safety net with no handler, no crew inside counters, the BASE MENU card |
| `theater_test` (+) | buying the theater through the real UI: card button → plot picker → locked district refused (even forged) → no half purchase without the cash → Buy & open → the price shown is the price paid → no second plot |
| `data_test`, migration self-tests (+) | schema 15, v14 → v15 keeps everything, a broken v15 save is repaired, a crashing step is refused |
| `v9_test`, `leaders_test`, `mobile_test` (+) | the park's interior, 11 prestige goals, new cards and windows at 4 phone sizes |

Static checks: `tools/check.sh` (luau-lsp with the Roblox definitions) reports only the known false positive in
`WorldFX.lua(59,4)`, and `tools/propcheck.py` reports 0 problems. The place file round-trips: extracting
`CornerEmpire_v15.rbxlx` gives back exactly `src/`.

## 5. Known limitations

- **Lighting.Technology** can't be set from a script. Set it in Studio (section 2, step 7).
- The mountain base fix makes the prompts reachable and adds the BASE MENU backup. The simulated engine can't show
  why a prompt didn't appear for you in Studio, so please check it there (★ below).
- While you ride, other players see you standing at the ride's entrance: only your camera rides.
- Coaster trains, spinning rides and visitors are drawn by each client. Other players see the same positions because
  everything follows the server clock, but nobody collides with them.
- Park visitors walk from path cell to path cell. Without paths they wait inside the gate.
- Up to 4 parks per server, one per player (the server holds 4 players).
- A rebirth closes the park (its level goes back to 0) and frees the site. The rides stay in the save and come back
  when the park is reopened.

## 6. Needs real Roblox Studio / phone testing

★ = what you reported.

1. ★ **Streets:** drive Main St, Central Ave, the ring roads and North Rd. No benches, trees, rocks, poles, parked
   cars or gates should be in the lanes.
2. ★ **Traffic:** watch the plaza crossing. Cars go around the Spire, not through it. Watch dead ends for a few
   minutes: no car should stay stuck in the road.
3. ★ **Mountain road:** walk and drive from North Rd up to the tunnel. No trees in the way.
4. ★ **Mountain base:** stand on each glowing floor mark (job board, gear, computer, planning room, fence, garage) and
   check the prompt appears and opens the right tab. Also try the ⛰️ BASE MENU card. If a prompt still doesn't
   appear, note which one and whether anything in Output mentions `[Base]`.
5. ★ **Theater:** with a HOTSPOT save, use the business card's 🏙️ OPEN ON A CITY PLOT button. Buy & open in a
   district, and check the theater appears on that plot.
6. **Amusement Park:**
   - With a CITY ICON save, open it the same way. Use 🎢 Go to the park.
   - Build a few rides, stalls and paths. Move, turn and sell something.
   - Ride a coaster: is the camera smooth? Is the loop readable?
   - With a second player: ride their park and check the owner's ticket.
7. **Fun Park:**
   - Ride the Big Dipper, the Sky Drop and the Whirl.
   - Check the stall queues and cotton candy people, the string lights at night, and that cars on Main St pass
     through cleanly.
8. **Graphics:**
   - Set the time with the admin panel to 6, 12, 18 and 22: sunrise warm, noon neutral, sunset warm, night blue with
     glowing neon.
   - Check the sky's sun, moon and stars.
9. **Phone:**
   - Open the 🎢 Park app and the plot picker on a phone. The build plan's cells should be tappable (≥ 18 px).
   - Frame rate at the Fun Park and the Funland Grounds with the crowd on High.
10. **Saves:** load a real v14 save (Studio test store). Everything should be kept, and the Park app should say
    "not open yet".

## 7. Configuration (all in code, all server-checked)

- `C.PARK` (GameServer > Park): grid size, piece caps, ride cooldown and range, ticket size, guest reputation per
  hour, sales cap.
- `C.PARK_ITEMS`: every ride, stall and decoration (size, cost, excitement, unlock level).
- `C.BUSINESSES` (Config): the park's cost, income and unlock tier.
- `C.FUNPARK_STALLS` (GameServer > FunPark) and `CC.FUNPARK_STALLS` (EmpireClient > CityCrowd): the Fun Park stalls.
  Keep the two lists the same; `funpark_test` checks it.
- Time-of-day looks: the `KEYS` table in GameServer > Util.
