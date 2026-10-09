# Corner Empire v13 — Life & Empire, Phase A: Living City

**What this is.** Your "Life & Empire" plan (written as v11) arrived when the game was already at v12: v11 (mountain
base, heists, police) and v12 (billionaire milestones, Empire Plaza) had shipped. So this update is **v13**, and,
as your plan recommends, it is **Phase A only**: stability, a populated city and things to do on the map. The other
phases (Movie Theater, co-ownership, transfers, NPC police, events) are separate, testable releases. The roadmap at the
end lists what each one needs and which existing systems it builds on.

**Data:** same DataStore **`CornerEmpire_v5`**; save schema 12 → 13 with one additive record (`city`). Nothing was
published. **Install both** `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx` (section 5).

> **Testing honesty.** Every result here comes from this repository's **simulated** Roblox engine. It does not
> render, has no real physics, no real touch input, no real Roblox text filter, no real networking and no real
> DataStores. **Nothing in this update has been run in Roblox Studio or on a phone.** Section 7 is the Studio checklist.

## 1. Your plan vs what the game already has

| Plan area | Already in the game (version) | Done in this update (Phase A) | Later phase |
|---|---|---|---|
| Pedestrians, customers, traffic | 30 walkers + 16 cars on fixed loops; customers walk into your businesses (v6+) | **Rebuilt (CityCrowd):** pooled crowd and traffic around the player on the real road network, district crowds, street scenes | — |
| Deliveries | Customer delivery orders (v6) | Delivery vans in traffic; **courier City Jobs** | — |
| Employees | Staff per business with stars/speed/experience; manager, marketer, engineer; General Manager contracts (v10) | — | **B:** skills, schedules, cleaning/maintenance roles |
| Rival businesses | Temporary "Business Beef" pop-ups, Corner Wars (v9) | — | **B:** persistent AI rivals with market share |
| Secrets, collectibles, side missions, landmarks | Hidden secret spots and relics, Mystery Lots, Legacy Museum (v8) | **30 Golden Corners, 20 places to discover, City Jobs (3 kinds)** | — |
| Distinct districts | District bonuses and looks (v10) | **District crowds:** suits downtown, hard hats in the Industrial Zone, swimmers at the beach, joggers and dog walkers in the suburbs, hikers on Hillside... | **E:** more set pieces per district |
| Movie Theater | A secret "Movie Studio" business exists; no theater | — | **B** |
| Names, products, demand, filtering | Business names (server-filtered with `TextService`), products with names, price, quality, presentation, demand, trends, supplies (v10) | — | **B:** product designs/colors, analytics |
| Unlimited purchases | Plots with per-district caps that grow with reputation (v10) | — | **B:** review the caps against your "no low cap" rule |
| Co-ownership, transfers | — | — | **C** |
| Housing, parties, home computer | House builder, furniture grid, styles, visitor permissions, home computer (v10) | — | **C:** parties, apartments vs mansions |
| Vehicles | 16 original cars in 7 classes (Economy, SUV, Truck, Sports, Luxury, Supercar, Hypercar); cosmetic-only tuning (v10) | — | **D:** off-road/cargo roles, stat tuning |
| Mountain base, robberies, police | Lever, tunnel, volcanic HQ, 8 robbery targets, loot bags, return-to-base cash-out (v11); **police are players on duty** | — | **D:** *your plan says NPC police only, which conflicts with v11's player police: decide before Phase D* |
| Leaderboards, progression | Weekly boards, race records, Hall of Fame + billionaire milestones (v12), rebirths | Golden Corner / explorer / job achievements | **D:** friends boards, exploration and robbery boards |
| Special-occasion events | Mega events and city events (v7, v9) | — | **E** |
| Tutorial | 7-step tutorial + 27 contextual tips (v10–v12) | +3 tips (Explore, Golden Corners, City Jobs), "What's this?" help for Explore | **E:** the staged 10-step first ten minutes |
| Phone app stability (Arcade) | The Arcade glitch was fixed in v11; a lifecycle test covered the Arcade | **Audit of all 23 apps** (section 2) | — |

## 2. Phase A, part 1: stability (the Arcade and every phone app)

Your plan asked to reproduce the Arcade glitch first. It was fixed in v11 (`phoneapp_test` has covered it since). For
this update the check goes much further:

- **New `lifecycle_test`:** opens and closes **every** app on the phone 8 times, switches apps 48 times, and plays the
  🤖 Arcade Bot three times (start → leave → reopen). After two warm-up opens, it counts every live event connection
  by the line of code that made it, and every UI element by its path. **Result: no app grows per open.** The worst
  case was +4, from CityBuzz showing newly arrived posts, which is bounded content and not a leak. The Arcade round
  trip is flat: connections and UI objects are the same after 1 and 3 games.
- **The test engine itself was fixed:** destroying an instance now disconnects its events, as in Roblox. Before, the
  simulated engine could not see this class of leak at all.
- **Honest result:** no new phone-app leak was found, so there was nothing to fix. The test now guards against future
  ones.

## 3. Phase A, part 2: the living city (EmpireClient → CityCrowd)

| Before (v12) | Now (v13) |
|---|---|
| 30 walkers and 16 cars spread over the whole ~1,300 × 700 map → **~2–5 people near you** | The same kind of budget kept **around you**: **37–44 people within 160 studs and 14–18 cars within 220**, wherever you are (measured in the test at Downtown, Industrial, the beach, the suburbs, Hillside and the center) |
| Fixed rectangles; cars ignore the lights and drive through each other | People walk the real sidewalks, turn corners and **wait for the light** before crossing. Cars drive in the right-hand lane, **stop at red**, follow the yellow rule, keep their distance, turn at junctions and U-turn at dead ends |
| Same crowd everywhere | **District crowds:** suits and coffee cups downtown, hard hats in the Industrial Zone, swimsuits and surfboards at the beach, joggers and dog walkers in the suburbs and on Maple Lane, tourists with shopping bags in the entertainment district, hikers on Hillside, suits and dogs on Millionaire Row |
| — | Sedans, taxis, sports cars, **📦 delivery vans** and **🚌 city buses** |
| — | **Street scenes** (shown when you're near): street musicians, hot-dog carts with a queue, beach umbrellas with sunbathers, beach volleyball |
| All 46 moved every frame, even 600 studs away | Pooled (built once, ~860 parts, never collide or block clicks); far ones update ~10×/s; scenes hidden when far; Settings → Crowds **HIGH 44+18 / LOW 22+9 / OFF** |

Also fixed: the second traffic light at each crossing hung over the east–west road, so north–south traffic had no
signal. Each light now hangs over the road it controls, and lights run on server time, so every player sees the same
colors and the cars obey exactly what you see.

## 4. Phase A, part 3: things to do (GameServer → Explore, 🧭 Explore app)

- **City Jobs:** three offers at a time, one active job.
  - **📦 Courier run:** pick up, then deliver before the clock (which starts at pickup) runs out.
  - **🐶 Lost dog:** find the dog, then walk it home; it trots behind you.
  - **🧹 Street clean-up:** bag 5 litter piles within 150 s of the first.
  - How it works: a guide beam leads to each stop, and a job card sits in the existing top-right notification stack (it counts toward the 3-card limit).
  - Pay: a number of seconds of **your own income** (90 / 75 / 60 s), with a minimum for new players ($250 / $200 / $150).
- **30 Golden Corners** at street corners across 20 districts, neighborhoods and landmarks:
  - The rule: one-time reward each, a bonus for finishing a district's set, and a big bonus for all 30.
  - The Explore app gives a hint for each one you're missing.
  - Only you see the ones you haven't collected (they're drawn by your own client).
- **20 places to discover:** the first visit to every place on the map pays a little; the Places tab tracks them.
- **Server-checked:** the server reads your character's real position once a second. The client only draws and asks to take or drop a job.
  - A **teleport cancels the active job** (no warping to the drop-off).
  - A short cooldown separates jobs; nonsense input is ignored.
- **Tips:** Explore is suggested once the opening tutorial is done; Golden Corners and City Jobs each explain themselves the first time.
- **Achievements:** first Golden Corner, all 30, City Explorer (all places), first job, 25 jobs.

## 5. Install (existing place, keeps all player data)

1. Studio → **File → Save to File As…** → make a backup (e.g. `CornerEmpire_before_v13.rbxlx`).
2. **Write down** your 7 pass IDs (`GameServer → Config → C.PASSES`) and your `owners = {…}` (`GameServer → Admin`).
3. **ServerScriptService** → delete `GameServer` → right-click → **Insert from File…** → `updates/GameServer.rbxmx`.
4. **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click → **Insert from File…** → `updates/EmpireClient.rbxmx`.
5. Put back your pass IDs (`id = 0` → your number) and `owners = {YOUR_USERID}`.
6. Do **not** change `DATASTORE = "CornerEmpire_v5"`.
7. Run the Studio checklist (section 7), then publish yourself.

New place instead: open `CornerEmpire_v13.rbxlx`, set the pass IDs and owner, test, publish.
**Rollback:** reopen the backup. A v13 save still loads in v12, because the extra `city` record is kept untouched.

### Data safety and migration
- Step 12 → 13 adds `city = {corners = {}, places = {}, jobs = 0, jobPay = 0, streak = 0}` only if it's missing.
- Every other field, including unknown future fields, is kept.
- A damaged `city` record is repaired field by field, and the rest of the save still loads.
- If the step crashes, the migration is refused and the stored v12 save stays untouched.
- Tested on a full v12 save: cash, businesses, brand style, all four milestones, heists, cars, home and an unknown field all survive.
- Rewards are paid on the server only. Job and collectible rewards count as earned income, like the existing secret spots.

## 6. Tests — SIMULATED (not Roblox Studio)

Results of the final run on the finished code are in section 9. New suites:

- **`city_test`** (37 checks, passed 4 runs in a row):
  - network built from the server data (14 roads, 96 sidewalk segments, 10 lit crossings)
  - pool sizes for HIGH / LOW / OFF; nothing drawn when OFF; parts never collide or block clicks
  - density and district mix at six places
  - 60 position samples: every person on a sidewalk or crosswalk, every car on its road, no car into the one ahead
  - 100 s at two crossings: 108 cars through on green or clearing on yellow, **0 ran a red**, cars wait at the line, 58 pedestrians crossed and **none started on red**
  - per-frame cost; scenes show near and hide far
- **`explore_test`** (37 checks):
  - all 30 corners on a sidewalk and none inside a lamp post, light pole or building
  - collecting: once only, set bonus, per player, the client stops drawing it
  - place discovery
  - all three job types end to end; teleport cancels; cooldown; bad input ignored; time-out fails with no pay
  - reward scaling; app tabs; the job card is in the notification stack
- **`lifecycle_test`** (11 checks): section 2.
- **`data_test`** (+3 checks): v12 → v13.
- **`mobile_test`**: the new job card is included in the "every notification card" and "all cards at once" checks at four phone sizes.

Bugs the new tests caught and that are fixed:
- a Golden Corner placed where there's no sidewalk (the dealership forecourt), and one inside a traffic-light pole
- cars braking too late for a red at high speed (switched to a real stopping-distance curve)
- cars committing on yellow then crossing after it turned red (now: go only if you'll clear the line in time)
- two ring roads whose end junction was treated as a dead end (cars queued for a U-turn into each other)

## 7. Needs real Roblox Studio / phone testing

**Rendering and feel**
- [ ] Walk and drive through Downtown, the Industrial Zone, the beach, Maple suburbs, Hillside and the center: people on the sidewalks, cars in the right lane, no one walking through walls or standing in a building's doorway
- [ ] Traffic lights: cars stop on red where the light hangs; north–south lights now hang over the north–south road
- [ ] Buses, vans, taxis and sports cars look right; the 📦 DELIVERY and CITY LOOP signs are readable
- [ ] Street musician, hot-dog cart, beach umbrellas, volleyball: placed on the sidewalk or sand, not in a road
- [ ] Golden Corners: visible, spinning, not inside anything; disappear once collected

**Performance (the important one)**
- [ ] On a low-end phone, Settings → Crowds HIGH, LOW and OFF: frame rate in Downtown at each setting (the simulated engine times Lua only, not rendering)
- [ ] MicroProfiler / Developer Console on desktop: CityCrowd's RenderStepped stays small

**Mobile**
- [ ] 390×700: the 🧭 Explore app, its tabs and Take/Drop buttons are tappable; the job card sits in the top-right stack (max 3 cards) and never covers the middle
- [ ] The guide beam to a job stop is visible while driving

**Gameplay and networking**
- [ ] Each City Job end to end, on foot and in a car; a phone-map teleport cancels the job
- [ ] Two players in one server: each sees only their own uncollected corners and their own job props; rewards are separate
- [ ] Rejoin: collected corners, discovered places and the job count are kept
- [ ] An existing v12 save loads into v13 with everything intact (back it up first)

## 8. Roadmap: Phases B–E

- **B — Business depth:**
  - **Movie Theater**: walk-in interior, sessions with original film titles, tickets and concessions, seating and screen upgrades, attendance stats (the existing business, interior and product systems carry most of it)
  - product designs and colors
  - employee skills, schedules and roles
  - persistent **AI rivals** with understandable market-share rules
  - review the plot caps against your "no arbitrary low cap" rule
- **C — Social life:** co-owned businesses (invitations, roles, permissions, a contribution and transaction log); **secure transfers** (both sides confirm, server revalidation, a pending-transfer state with recovery so nothing can be duplicated); home parties; apartments vs mansions.
- **D — Risk and progression:**
  - **decide on police first:** your plan says NPC police only; v11 shipped player police. Options: replace them, keep both, or keep players as optional. NPC police would need patrol/alert/search/pursuit/arrest states built on the existing approximate-search system.
  - vehicle roles (off-road, cargo) with server-validated tuning
  - friends leaderboards plus exploration and robbery boards
- **E — Polish:** scheduled special-occasion events with saved rewards; the staged 10-step first ten minutes; more district set pieces; a device and performance pass.

## 9. Final results (SIMULATED engine, not Roblox Studio)

Final run on the finished code: **29 suites, 1,482 checks, 0 failed.**

| Suite | Result | | Suite | Result |
|---|---|---|---|---|
| admin | 55 / 55 |  interior | 38 / 38 |
| arcade | 38 / 38 |  **lifecycle (new)** | 11 / 11 |
| business | 24 / 24 |  mobile | 201 / 201 |
| car | 36 / 36 |  perf | 11 / 11 |
| **city (new)** | 37 / 37 |  phone | 39 / 39 |
| critical | 45 / 45 |  phoneapp | 17 / 17 |
| data | 26 / 26 |  smoke | 5 / 5 |
| empire | 64 / 64 |  story | 70 / 70 |
| estate | 79 / 79 |  terrain | 4 / 4 |
| **explore (new)** | 37 / 37 |  tutorial | 46 / 46 |
| features | 156 / 156 |  v10_data | 15 / 15 |
| guide | 17 / 17 |  v112 | 30 / 30 |
| heist | 100 / 100 |  v9 | 75 / 75 |
| home | 64 / 64 |  viral | 86 / 86 |
| hq | 56 / 56 |  | |

About `lifecycle_test`. In the full run it failed once: CityBuzz posts arriving mid-test added rows. That is bounded
content (the feed shows at most 25 posts), not a leak. Two changes followed:
- the test now fills the feed to its cap before measuring;
- anything that grows is re-measured over 6 more opens, and only growth that repeats counts as a leak.

Results after the changes:
- 9 runs in a row passed;
- a **deliberately planted leak** (one extra connection per open of the 👑 Empire app) was caught and reported as
  `👑 Empire: +18 live connections from EmpireUI:138`; the planted line was then removed.

Static checks: `luau-lsp` clean except the known `WorldFX.lua:59` false positive; API property check 0 problems.
Build: `CornerEmpire_v13.rbxlx` extracts back to all 77 source scripts byte-for-byte. The drop-ins contain the new
modules (`Explore`, `CityCrowd`, `ExploreUI`), `VERSION = "13.0.0"` and `DATASTORE = "CornerEmpire_v5"`.

**Not run anywhere real:** Roblox Studio, a phone, real DataStores, real text filtering, real rendering or physics.
See section 7.
