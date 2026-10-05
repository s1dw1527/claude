# Corner Empire

A 1–4 player Roblox business tycoon. **`CornerEmpire_v10.rbxlx` is the current place file**; open it in Roblox Studio.
`CornerEmpire_v9.rbxlx` … `CornerEmpire_v5.rbxlx` are earlier versions, kept for reference. The full v10 write-up is
`docs/V10_REPORT.md` (v9: `docs/V9_REPORT.md`).

## What's new in v10 — "Ownership, HQ, Cars & Lifestyle"

- **Real estate you keep.** 8 districts and ~100 plots: Downtown (8), Waterfront (5) and Luxury (4) are small and
  valuable, so each player can own only 1–2 there. Midtown, Northside Suburbs and Expansion have 20 plots each;
  Industrial has big ones; Entertainment surrounds the new Fun Zone. A plot is a **permanent deed**: it's saved, it
  comes back on any server, and if someone else is standing on "your" spot it moves to another plot in the same
  district. How many properties you can own grows with reputation (+1 per 10 rebirths). PROPERTY FOR SALE /
  OWNED BY signs and a property card with View / Buy / Enter / Sell (selling asks to confirm).
- **Your businesses, your brand.** Choose what each plot runs, give every business a name (checked by Roblox's text
  filter on the server), and pick a logo, colours, uniforms, interior theme and menu style. Products have price,
  quality, presentation, ingredients and popularity; more product slots unlock at levels 1/3/5/7/10; a product can
  trend for a while (not farmable). Supplies run down with sales: restock at the business, or remotely from a computer.
- **HQ.** The Empire Tower becomes a 6-floor headquarters you walk into: Reception, Management, Finance, Executive (the
  **Empire Wall** map), Private Office and Rooftop, with an elevator and staff at their desks.
- **General Manager.** Sign a 15–60 minute contract (only counts down while you play). Repairs take 90 s → 45 s by
  level, level 3+ handles several at once, level 4+ prioritizes your best earners, level 5 handles outages and
  theft. Contracts expire (**MANAGER CONTRACT EXPIRED**); auto-renew is optional and only works while you're active.
- **Computer.** A real object at home and in your office: Basic / Gaming PC / Executive Workstation / Empire Command
  Center unlock more apps (overview, finances, inventory, businesses with remote restock, stocks, vehicles, properties,
  messages, tasks, events, product analytics). Computers never pay money.
- **Home builder.** 7 house tiers up to the **Empire Estate**. A 9-category furniture shop; place items on a grid
  inside your home (validated on the server), move, rotate, pick up; room layouts, ceilings, doors and windows.
  Visitors: PUBLIC / FRIENDS / INVITE ONLY / PRIVATE for your house, businesses and HQ.
- **16 original cars** (fictional makes, no real brands or designs) in 7 classes with speed, acceleration,
  handling, braking, grip, drift and nitro. Brake lights, turn signals, a working dash and steering wheel. The garage
  shows **OWNED: x / 16**: equip, favorite, rename, customize (paint, wheels, tint, interior, plate, decals, spoilers,
  bumpers, exhaust; looks only) and sell.
- **Fun Zone + 2-player arcade.** Reaction Duel, Button Battle, Hoop Duel and Kart Sprint against a real player, at
  Fun Zone booths, a friend's Arcade business or an arcade machine at someone's home. The server runs the games,
  caps impossible tap rates, forfeits players who leave, and pays tickets (for furniture, never cash) with
  per-opponent and per-hour caps. Leaderboard at the Fun Zone.
- **Admin panel** for authorized developers only (see below).
- **Tutorial update.** 18 contextual tips appear the first time you reach each new system, and every new window has a
  **❓ What's this?** button. Tips can be switched off in Settings.

### Admins (developers only)

Admin rights are decided **on the server**, never by the client and never from player save data:
- **Owners:** the UserIds in `GameServer > Admin` → `C.ADMIN_CONFIG.owners`, the place's creator, or (group
  places) members of `groupId` with at least `groupMinRank`. Owners can add and remove admins.
- **Admins:** added by an owner in the panel (DEVELOPER tab) by username. The server looks the name up and stores the
  UserId in its own DataStore, `CornerEmpire_Admins_v1` (separate from player saves; Studio playtests use a
  `_StudioTest` copy, so testing never changes the live admin list).
- In Studio every tester is an owner (`studioIsOwner`); live servers never.

Dangerous tools (taking cash or cars away, kicking, removing an admin…) need a server-issued one-time confirmation.
Every tool use is logged (names, UserIds, the action, the amount).

## What was new in v9 — "Empire Life & Viral Moments"

- **Walk-in business interiors.** Each of the 8 businesses has its own layout: lemonade machine and cups, ice cream
  case and toppings, ovens and display cases, espresso machines and couches, pizza ovens and a delivery pickup,
  a walkable arcade with cabinets and racing machines, tech screens and a repair bench, and a much bigger factory
  with conveyor belts and a loading dock. They grow with the business level, your logo is on the walls, and there's
  a manager's office from level 5. Enter through the door, or **🚪 Go inside** on the business card.
- **Interior score 0–100**, from EMPTY to VIRAL, shown on the business card ("Coffee House Interior: 89/100 —
  ELITE"). It raises satisfaction and reviews, **never income**.
- **Staff and customers inside.** Cashiers serve, cooks cook, cleaners clean and the manager does rounds.
  Customers browse, order, sit, eat, check their phones and react. Now and then one takes a selfie, complains
  dramatically, brings a friend or leaves a funny review.
- **Cinematics** for evictions (cartoon slapstick, about 10 s), grand openings (with each business's signature
  moment), hires, firings, big upgrades, complaints, inspections, investments, luxury purchases and competition wins.
  You can always skip them: tap Skip, press Backspace, or press Ⓑ. **Settings → 🎬 Cinematics** sets FULL, SHORT or
  OFF. Scenes are presentation only: the change has already happened on the server.
- **Four original influencers**: Bay Snaps, Jax Cash, Maya Max and Drew Deals. They show up rarely, at your
  business, home or car. Everyone sees them; only the player they came for gets the visit.
- **Viral Moments.** The game notices what you actually do: evicting a tenant, crashing your car into your own
  bakery, owning a mansion and a tiny lemonade stand, a 1-star review, 100 customers in a minute. It turns them into
  CityBuzz posts, with cooldowns so the feed isn't spammed. Rare events: THE CROWD, PAPARAZZI MODE, EVERYONE KNOWS
  YOU and BUSINESS BEEF. Funny events: the health inspector, a customer army, a delivery disaster, a rich kid and a
  bad investor. Lil Clipz reacts too.
- **📱 VIRAL app**: your Viral Score, your moments, influencer sightings, trending and funniest moments, top posts,
  and the weekly **Most Viral** boards (top-3 finishes are kept in your Hall of Fame). 8 new achievements.
- **Animations** live in `EmpireClient > AnimationConfig`. Paste your own animation ids there. A missing one falls
  back safely and is logged in Studio; it never breaks a scene.

## What was new in v8 — "The Empire Expansion"

- **Phone apps fixed at the root.** Since v5 the phone stored a function on a Frame (`v.refresh = ...`). Real Roblox
  rejects custom fields on Instances, so the error stopped the Phone module partway through. Messages, the Map and the
  live CityBuzz listener were never built, and the Story module failed the same way. The test engine now enforces
  Roblox's real member list (`tests/roblox_api.lua`), so this kind of bug fails the tests.
- **Steering.** The car's upright stabilizer (AlignOrientation) held all three axes, so it fought every turn. It now
  only keeps the car upright (`PrimaryAxisParallel`), and yaw is free.
- **Map app**, **Messages** (real senders, unread badge, important mail saved), a **Story app** (objective,
  characters, rewards, safe replays), and **CityBuzz posts** with business/house/car/empire/photo cards, reactions,
  views and Trending. CityBuzz is in-game only and never posts to real social media.
- **Business selector + management card**, which scales down on phones.
- **Improvements and reviews you can win back.** Upgrade the weakness a customer complained about. When they come
  back, they may add an update to their review; their original words are never edited.
- **Interiors.** Step inside any business or home and decorate it: walls, floors, lighting, furniture and decor.
  This raises satisfaction and ratings, never income.
- **Visible house ratings**: average stars, rating count, visits and likes on a sign over each house, in the house
  info panel and in the tour list. Ratings are rate limited, server validated, and you can't rate your own house.
- **Data safety**: save schema versions, step-by-step migration, `UpdateAsync` saves, and an update notice. See the
  next section.

## HOW TO UPDATE CORNER EMPIRE WITHOUT LOSING PLAYER DATA

Player progress lives in the DataStore **`CornerEmpire_v5`**, keyed `u<UserId>_s<slot>` (plus `u<UserId>_meta`). That
name and key format are the same in every version since v5 and must never change. Every update keeps reading the
same saves and upgrades them in memory.

**Normal update (every time):**
1. Back up first: in Studio, **File → Save to File As…** (or keep the previous `CornerEmpire_vN.rbxlx`).
2. Put the new scripts into your **existing** place: the drop-in files or Rojo (next section), or open the new
   `.rbxlx` and publish it over the same place.
3. **File → Publish to Roblox** onto the **same place**. Never use *Publish As* to a new experience: a new
   experience has its own empty DataStores, so every player would start over.
4. Restart the old servers: on the Creator Dashboard, open the experience and use **Restart servers** (Roblox's
   "restart servers for updates"). Servers still running the old version see the new version announced: they save
   everyone and show "🆕 NEW UPDATE READY". Shutdown saves again (`BindToClose`).

**Rules that keep saves safe (already built in):**
- Never rename `CFG.DATASTORE` in `GameServer > Config`, and never change the key format.
- Saves carry `SchemaVersion`. On load, `GameServer > DataMigration` upgrades an old save one step at a time
  (6 → 7 → 8 → 9 → 10), on a copy, then validates it. If anything fails, the player plays with saving **turned off** for that
  slot and sees a warning. The stored save is never overwritten with defaults.
- Saves use `UpdateAsync` with a save counter, so an older server can't overwrite a newer save. A save written by a
  **newer** version than the server running it is loaded read-only and never saved over.
- Fields the current version doesn't know are kept and written back unchanged.
- New-feature data is never fatal: if a v9 or v10 record (the viral record, deeds, brands, the home builder...) is damaged, only that part is reset. The
  rest of the save loads, and the damaged original is kept in the save (`viralRecovered`).
- A failed DataStore read never gives a fresh profile that later saves over the real one.

**Major update that changes the save shape:**
1. In `GameServer > Config`, raise `C.VERSION.SCHEMA_VERSION` by one (and bump `VERSION`, `UPDATE_NAME`, `NOTES`).
2. In `GameServer > DataMigration`, add `M.steps[<old schema>] = function(t, log) ... end`. It should only **add**
   or convert fields and never delete progress. Add a sample of the old save to `M.sampleSaves`.
3. If the step adds a saved field, add it to `SAVE_KEYS` in `GameServer > Players`.
4. Run the Studio test below and `tests/data_test.lua` before publishing. Write down what changed (like
   `DATA_MIGRATION_REPORT.md`).

**Testing in Studio never touches live data.** In Studio, every DataStore name gets `_StudioTest` on the end
(`C.storeName`, controlled by `CFG.STUDIO_USES_LIVE_DATA = false`). Playtests read and write a separate test copy,
never your players' saves. Leave that setting `false`. In a Studio playtest, open **Settings → 🧪 Update + data
safety test**. It runs the migration self-test on v5–v10 sample saves (including damaged v9 and v10 records) and the real
save/load code against an in-memory store (fresh save, rejoin, conflicts, newer schema, failed load, failed migration), then prints the
result to the Output.

## Updating the game in Studio (without replacing your place)

The whole game is two scripts: `ServerScriptService > GameServer` and
`StarterPlayer > StarterPlayerScripts > EmpireClient`, each with its modules. Anything you build or change
yourself in Studio stays put, as long as you only swap those two scripts.

**Option A: drop-in files (nothing to install).** `python3 tools/patch.py` writes `updates/GameServer.rbxmx` and
`updates/EmpireClient.rbxmx`. In your place:
1. Delete the old `GameServer` (in ServerScriptService) and the old `EmpireClient` (in StarterPlayerScripts).
2. Right-click **ServerScriptService** → **Insert from File…** → `GameServer.rbxmx`.
3. Right-click **StarterPlayer > StarterPlayerScripts** → **Insert from File…** → `EmpireClient.rbxmx`.
4. If you changed anything in `GameServer > Config` (like game pass IDs), copy it back in. The new file has the
   default Config.

**Option B: live sync with Rojo (best if you update often).** `default.project.json` tells Rojo where each script
lives (`python3 tools/rojo_project.py` regenerates it after adding a module).
1. Install the **Rojo** plugin in Studio (Toolbox → Plugins), and the Rojo program on your computer (the
   "Rojo" extension in VS Code is the easiest way).
2. Download or `git clone` this repository, open the folder, and start Rojo (`rojo serve`, or "Start server" in VS Code).
3. In Studio, open your place, click **Rojo → Connect**. The two scripts now mirror `src/`.
4. To get an update later: pull the latest version of the repository (`git pull`). Studio updates by itself while
   connected. Then **File → Publish to Roblox**.

Rojo only manages those two scripts: your own parts, settings and other scripts aren't touched. Like Option A, it
uses `Config.lua` from the repository, so put your pass IDs in `src/ServerScriptService/GameServer/Config.lua`.

## Layout

- `src/` holds every script from the place, one file per script, mirroring the Explorer:
  - `ServerScriptService/GameServer.server.lua` + `GameServer/*.lua` (server modules)
  - `StarterPlayer/StarterPlayerScripts/EmpireClient.client.lua` + `EmpireClient/*.lua` (client modules)
- `tools/build.py` rebuilds the place file from `src/` (`python3 tools/build.py CornerEmpire_v10.rbxlx`).
- `tools/extract.py` pulls the scripts back out of a place file; `tools/compare.py` compares two place files.
- `tools/propcheck.py <globalTypes.d.luau>` checks every property name the scripts set against the Roblox API.
- `tools/check.sh` compiles every script, type-checks it against the Roblox API and flags unknown globals (needs the Luau tools).
- `tests/` runs the real scripts in a small simulated Roblox engine (`tests/harness.lua`). There's no physics or
  rendering, but the game logic is real, DataStores live in memory and time is simulated.
  - `python3 tests/run.py tests/data_test.lua`: fresh/v6/v7/v8 saves, migration, rejoin, server switch, conflicts,
    failed loads and migrations, and a newer-schema save
  - `python3 tests/run.py tests/phone_test.lua`: Messages, Map, Story app and CityBuzz posts through the real client
  - `python3 tests/run.py tests/business_test.lua`: business selector, improvements and reviews that can be won back
  - `python3 tests/run.py tests/interior_test.lua`: interiors, decorating, house ratings and visits
  - `python3 tests/run.py tests/v9_test.lua`: v8 → v9 saves, the eviction cinematic and its edge cases (skip, leave,
    disconnect, two players, visitors), missing animations, grand openings, staff scenes, interiors, staff and
    customer life
  - `python3 tests/run.py tests/viral_test.lua`: Viral Moments, cooldowns, CityBuzz, capture, influencers, rare and
    funny events, the Viral app, weekly boards, achievements, NPC caps
  - v10: `estate_test` (districts, plots, deeds, limits, names, brands, products, supplies, trends), `hq_test` (HQ,
    elevator, manager contracts, computer), `home_test` (house tiers, furniture, grid, styles, visitors), `car_test`
    (16 cars, details, garage), `arcade_test` (2-player games, anti-farm, forfeits, prizes), `admin_test` (admin
    security and tools), `guide_test` (tips and help), `v10_data_test` (v8/v9 → v10, broken fields, disconnect
    mid-purchase, server switching, simultaneous purchases)
  - `python3 tests/run.py tests/smoke_test.lua`: quick boot check
  - `python3 tests/run.py tests/tutorial_test.lua`: the whole tutorial through the real client, with extra focus on step 4
  - `python3 tests/run.py tests/story_test.lua`: story chapters, rewards paid once, cutscenes, multiplayer, old saves
  - `python3 tests/run.py tests/critical_test.lua`: the earlier audit fixes
  - `python3 tests/run.py tests/features_test.lua`: the v6 systems
  - `python3 tests/run.py tests/perf_test.lua`: a 40-minute, 4-player soak test
  - `SIM_ARGS='profile="casual", hours=12' python3 tests/run.py tests/economy_sim.lua`: a bot plays a fresh save on
    the real server code and prints when it reaches each milestone. Profiles are `casual` and `active`; add
    `passes="x4,vip"` to see paid passes, or `fromSave=true` to continue an existing v6 save. `python3 tools/sim_table.py`
    turns the saved runs in `tests/results/` into `SUMMARY.md`.

The DataStore name is still `CornerEmpire_v5`, so existing saves carry over (see the update section above). Old saves
load with their levels, homes and cars. Story mode marks chapters an old empire has clearly already beaten as done (without paying those rewards) and
starts at the first one it hasn't.

## Still on the owner's side

- Paste Roblox-licensed music IDs into `EmpireClient > Audio`.
- Put the real game pass IDs in `GameServer > Config` (`C.PASSES`). The Rich Start and VIP descriptions changed in v7.
  Update the pass descriptions on the Roblox website to match.
- Publish, turn on **Enable Studio Access to API Services**, and set the place's Max Players to 4.
- In Studio, Settings shows 🧪 test tools: money, reputation, mega events, mystery lots, Spire, viral,
  **Story: jump to next chapter** and **🧪 Update + data safety test**. v9 adds buttons for the eviction cinematic, a
  grand opening, an influencer visit, a viral moment, paparazzi, a CityBuzz post, a customer rush (THE CROWD), an
  inspection, a funny random event, entering a business interior and the cinematic camera. The server refuses them
  outside Studio.
- Animations: paste your own animation ids into `EmpireClient > AnimationConfig` (optional; safe fallbacks are built in).
- To rename the rival, edit `C.STORY_RIVAL` and `C.STORY_CAST.rival` in `GameServer > StoryData`.
- **Admins:** put your own Roblox UserId in `GameServer > Admin` → `C.ADMIN_CONFIG.owners` (or rely on being the
  place's creator). Add other developers from the panel's DEVELOPER tab.
