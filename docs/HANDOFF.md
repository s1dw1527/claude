# Corner Empire: Rags to Billions — handoff for the next Claude chat

Read this first. It covers what the game is, everything already in it, how the code is built and tested, and the rules the owner has set. Current version: **v19.0.0 "The City Rises"**.

---

## 1. What the game is
- A Roblox business tycoon for 1–12 players. Its full name is **"Corner Empire: Rags to Billions"**.
- You start with a lemonade stand and grow into a billionaire empire: businesses, city plots, a house, cars, heists, a story, and social features.
- Logo: a gold crown over "CORNER EMPIRE", with "⚡ RAGS TO BILLIONS ⚡" and "BUILD • RUN • EXPLORE • RISE" underneath.
- Every name in the game is original and fictional: businesses, films, brands and characters.

## 2. Rules the owner set (always follow these)
- **The DataStore name stays exactly `CornerEmpire_v5`, forever.** Never rename it, reset it, or point the game at a new one. Every player's save lives there.
- **Never wipe player data.** Keep save fields the code doesn't recognize. The save schema is **16**. Raise it only together with a new migration step in `DataMigration.lua`. Prefer additive fields (add them to `SAVE_KEYS` in `Players.lua` and repair them on load) over schema changes. Purely visual work needs no save changes at all.
- **The server decides everything:** purchases, rewards, heists, races and progression. The client only asks.
- **Never publish the game,** never publish to a new experience, and never change the production DataStore.
- **No paid or uploaded assets and no invented asset IDs** (audio IDs included). Build everything from parts, terrain, materials, lights, particles and GUI frames.
- **No fake buttons:** every button must do something.
- **Be honest about testing.** Everything is tested in a simulated engine (`tests/run.py`), not in Roblox Studio. Never claim that rendering, physics, phone frame rate, real DataStores or live multiplayer were tested.
- **Git:**
  - Work on branch `claude/corner-empire-v5-wj1yoh` and push with `git push -u origin claude/corner-empire-v5-wj1yoh`.
  - Don't open pull requests unless asked.
  - The owner wants every change committed and pushed.

## 3. Repository layout
- **`src/`** is the source of truth. It mirrors the Roblox tree:
  - `src/ServerScriptService/GameServer.server.lua` is the server entry point. It loads the modules in `GameServer/` in a **fixed order**.
  - `src/ServerScriptService/GameServer/*.lua`: 63 server modules. Each one is `return function(C) ... end`, and they share one table, `C`. `C.F` holds functions, `C.data[plr]` is a player's save, and `C.R` holds the RemoteEvents (`Action`, `Menu`, `Announce`, …).
  - `src/StarterPlayer/StarterPlayerScripts/EmpireClient.client.lua` plus `EmpireClient/*.lua`: 54 client modules, same pattern.
- **Module order is listed in 3 places, which must all match:**
  - the `modules` list in `GameServer.server.lua`;
  - the order list in `EmpireClient.client.lua`;
  - `tools/order.json`.
- **Building:**
  - `python3 tools/build.py CornerEmpire_vXX.rbxlx` builds the place file. It also sets Lighting → Technology = Future.
  - `python3 tools/patch.py` writes the drop-ins `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx`.
  - Round-trip check: `python3 -I tools/extract.py X.rbxlx <dir>`, then `diff -rq <dir> src`. The two must be identical.
- **Tests:**
  - `python3 tests/run.py tests/<name>_test.lua` runs one suite on the simulated engine (`tests/harness.lua`, `tests/common.lua`). There are 54 suites.
  - Arguments are passed with `SIM_ARGS='k=v,...'`.
  - The test environment has no global `Instance` or `game`: use `H.service(name)`, `H.G.*` and `H.workspace`.
  - Use `H.G.os.time()` for simulated time.
- **Static checks:**
  - `bash tools/check.sh`, which uses luau-lsp.
  - `python3 tools/propcheck.py <globalTypes.d.luau>`.
  - Their tools (`luau-compile`, `luau-lsp`, `luau-analyze`, `globalTypes.d.luau`) were in the old session's scratchpad. A new session must download them again, or skip these two checks and say so.
  - Two known false positives: `WorldFX.lua(59,4)` and `Bazaar.lua(108,15)`.
- **Visual preview (no Studio needed):**
  - `SIM_ARGS='x1=..,z1=..,x2=..,z2=..,night=true' python3 tests/run.py tests/isodump.lua 2>/dev/null | ISO_NIGHT=1 python3 tools/iso.py out.svg [yaw] [pitch]` draws an isometric PNG of the parts, using headless Chromium.
  - It has no lighting or terrain. pitch 89 = top-down.
- **Docs and builds:**
  - `docs/V8_REPORT.md` … `docs/V19_REPORT.md` contain each version's changes, tests, install steps, rollback and Studio checklist.
  - `docs/v19_previews/` holds the district previews.
  - Every version's place file is kept (`CornerEmpire_v5.rbxlx` … `CornerEmpire_v19.rbxlx`).

## 4. The world (built by server scripts at startup; nothing is hand-placed)
- **City Center:** the plaza, with 4 player home plots around it on Main St, the Corner Bank and the City Bazaar stall.
- **Empire Heights (v18):** 8 more player plots on Heights Blvd past the Corner Bank, with an arch. There are **12 player plots** in total.
- **Roads:**
  - `C.ROADS` is the traffic graph. It has traffic lights, crosswalks, lamps, benches and trees.
  - `C.HEIGHTS_ROADS` are quiet roads outside the traffic network.
  - `C.PATHS` are reserved paths: the mountain dirt road and the heist driveways.
  - `C.reserve(x1, z1, x2, z2)` and `C.isFree(x, z, pad)` keep new things off occupied land.
  - `C.clearTerrain` flattens hills.
  - `layout_test` fails if anything solid stands on a road or path; `terrain_test` fails if anything is buried in a hill.
- **City plots (`RealEstate.lua`):** about 100 plots that players buy as deeds and put a business on. An unsold plot shows a district-styled vacant building ("FOR LEASE") and a FOR SALE sign with a **View Property** prompt at its front corner.
  - **Midtown = Restaurant Row:** 20 plots, string lights over the streets, 16 city-run restaurants and Midtown Green.
  - **Entertainment District:** 15 plots, neon streets, 10 arcades and clubs, and the Fun Zone pavilion (2-player arcade games).
  - **Northside Suburbs:** 20 plots, little shops and a green.
  - **Expansion District:** 20 plots, late-game, with buildings under construction.
  - **Extra plots** in Downtown, Industrial and the Waterfront.
- **Downtown:** stepped skyscrapers (`C.skyscraper`) with night window bands and crowns, the Grand Hotel and City Lofts.
- **Heights Mall (v19):** a parking lot and the mall, with City Bazaar and Furniture Store counters.
- **Beachfront:** palms, the pier with a lighthouse, a boardwalk with umbrellas and loungers, snack stands, a stage, and the **Empire Plaza** monument (a tiny stand next to a giant tower).
- **Industrial:** warehouses, tanks, pipe racks, docks with trucks, and a gantry crane.
- **Other landmarks:**
  - Luxury Hills;
  - the Hillside plateau;
  - the **Fun Park** (giant rideable roller coaster, Ferris wheel, drop tower, swings, cotton candy);
  - the **Funland Grounds**, where you build your own amusement park;
  - the **Raceway** (gantry, grandstand, races);
  - the **Mountain** up north (secret lever, tunnel, base with stations; the heist hideout);
  - the **Empire Spire**;
  - the **Legacy Museum**, with 4 halls shared between players.
- **The living city (client):**
  - `CityCrowd`: pooled pedestrians and traffic that stop at red lights, plus buses, delivery vans, street musicians and beach life.
  - NPC police cars.
  - Workers at businesses.
  - Day/night lighting (`Util.lua`), weather, and windows that light up at night (`WorldFX`, tag `NightWindow`).
- **Architecture kit (`Architecture.lua`):**
  - `C.ARCH_STYLES` holds 7 data-driven building styles: restaurant, neon, shop, glass, construction, shed and beach.
  - Builders: `C.archBuild`, `C.archStreet`, `C.archPark`.
  - A new style is one table entry.

## 5. Gameplay systems (server module → what it does)
- **Businesses (`Systems`, `Buildings`, `Brands`, `Reviews`, `Kitchen`, `Interiors`):**
  - Stand → shop → towers in stages.
  - Customers, staff and upgrades; products with stock and trends; brand names, colors and storefront styles.
  - Interiors, reviews, Rush Orders cooking, and grand openings.
- **Rare customers:** ✨ Golden ×10 (1/250), 💎 Diamond ×50 (1/2,500) and 🌈 Rainbow ×250 (1/25,000). The extra pay is capped. Diamond and Rainbow are announced to the whole server.
- **Real estate (`RealEstate`, `Rentals`, `Housing`):** deeds, property capacity by reputation tier, a location bonus, apartments with rent, property upgrades and tenants.
- **Lot-only businesses:** the **Movie Theater** (`Theater`: films, premieres, upgrades) and the **Amusement Park** (`Park`, `FunPark`).
- **Home (`HomeBuilder`, `HomeLife`):** 7 house tiers, grid furniture, house ratings, visit permissions, home parties and house tours.
- **HQ, Computer, Crew and Ledger:** HQ floors with an empire wall, managers, staff traits and shifts, and the books.
- **Cars (`Cars`, `Garage`, `Vehicles`, `Race`):** 15 original vehicles with drift and Nitro, customization, roles and tuning, and races.
- **Crime (`Heists`, `Mountain`, `Police`):** rob the Corner Bank and 7 other targets, get the loot back to the mountain base, and get chased by NPC police (fines and arrests).
- **Story (`Story`, `StoryData`, `Cinematics`, `Messages`):** 6 chapters with a parody rival streamer, plus cinematics.
- **Social and viral:**
  - `Social` and `Partners`: co-owned businesses and safe gifts.
  - `Showcase`: the 🪪 player card.
  - `Influencers` and `ViralMoments`: CityBuzz feed and viral moments.
  - `Leaders`: leaderboards for net worth, revenue, exploration, robbery and friends.
  - `Legacy` and `Weekly`: the museum and weekly competitions.
  - `Rivals`: AI rival businesses.
- **Empire (`Empire`, `EmpirePlaza`, `Mega`):** billionaire milestones at $1M, $10M, $100M and $1B, with verified billionaires, a tower crown and the Empire Hall of Fame. City Eras and mega events.
- **Coming back:**
  - `Daily`: a 7-day login streak with a shield, 3 daily missions and a weekly challenge.
  - `Paths` and `Roadmap`: Mogul, Underworld and Legend paths, with titles and contracts.
  - `LiveEvents`, `CityEvents` and `Occasions`: a city event every few hours, and scheduled events.
  - `Collection`: the 📚 Collection Book, 21 ❓ ??? finds with milestones.
  - A "coming up next" card.
- **City Bazaar (`Bazaar`):**
  - Restocks every 5 minutes, with the same stock in every server.
  - Rarities run from Common to 🌈 Mythic, with 18 Bazaar-only furniture items.
  - Per-player limits are saved in the save, in `d.bazaar`.
- **Onboarding and help:**
  - `Onboarding`: a 10-step tutorial with rewards.
  - The first 90 seconds are boosted: the first customer comes at once, and there's a grand opening crowd.
  - `Guide`: 18 contextual tips and "What's this?".
  - `Explore` and `Activities`: City Jobs, 30 Golden Corners and discoveries.
- **`Analytics`:** AnalyticsService onboarding funnel, economy events and custom events.
- **`Admin`:** a secure admin panel.
- **`Updates`:** an update notice with patch notes (`C.VERSION.NOTES` in `Config.lua`).
- **Server size:** 12 players (`MAX_PLAYERS`). The owner must also set Server Size to 12 on the Creator Dashboard.

## 6. Client UI
- **Phone apps:** Map, Messages, Story, Viral/CityBuzz, Explore, Heists, Arcade, Daily, Roadmap, Bazaar, Collection, Leaders, Partners, Garage, Theater, Park, Settings, and more.
- **Screens:** a Main Menu with 3 save slots and a starter home; an intro cinematic with START and SKIP; the HUD with an XP bar; a notification stack (top-right, at most 3) and the 🔔 Activity log; Photo mode.
- **Style:**
  - The "Bold UI" kit lives in `UI.lua` (`C.STYLE`, `C.button`, `C.panel`, `C.titleText`, `C.crownLogo`): chunky outlined buttons and glossy gradients.
  - `ui_test` and `style_test` enforce it.
- **Mobile:**
  - `Layout.lua` handles breakpoints, the safe area and a modal manager.
  - Phones get carousels.
  - `mobile_test` checks phone sizes 390×700, 430×932 and 844×390, plus desktop.

## 7. Version history (one line each)
- **v5–v6:** base game.
- **v7:** economy rebalance and Story mode.
- **v8:** data safety (versioning, migrations, UpdateAsync), car steering fix, and the Business Selector.
- **v9:** animation and cinematics, richer interiors, influencers and viral moments.
- **v10:** real estate, brands, HQ, the house builder, 15 cars, the Fun Zone arcade and the admin panel.
- **v11.x:** the mobile layout overhaul, mountain fixes, the base stations and the notification stack.
- **v12:** billionaire milestones, Empire Plaza and the Hall of Fame.
- **v13:** the living city (crowds and traffic) and City Jobs and collectibles.
- **v14:** NPC police, the UI clarity pass, audio, Rush Orders, the Movie Theater, partners, leaderboards and events.
- **v15:** street-clutter fixes, the Amusement Park business and the Fun Park makeover.
- **v16:** Daily, Paths and the Roadmap, live events, the intro cinematic. **v16.1:** Bold UI.
- **v17:** City Bazaar, rare customers, the first 90 seconds and analytics.
- **v18:** the Rags to Billions name, 12-player servers with Empire Heights, and the Collection Book.
- **v19:** the world overhaul (district buildings, skyline, mall, beach, industry, night windows) and the crown logo.

## 8. Current state and numbers (v19)
- **Tests (simulated):** 54 suites. The full run had 2,248 checks with 0 failed; the total is now 2,252 with the newest checks.
- **Parts:** about 21,700 visible parts with one player (v18 had about 18,700). The budget is 25,000.
- **Builds:** `CornerEmpire_v19.rbxlx` and the drop-ins are built, and the round trip is identical.
- **Rollback:** the v18 commit is `18a460c`, or open `CornerEmpire_v18.rbxlx`.

## 9. Not done yet, or needing the owner in Studio
- **Nothing has been tested in real Roblox Studio.** The owner should go through the Studio checklist in `docs/V19_REPORT.md` section 6 before publishing:
  - lighting and night windows;
  - unsold plots and their prompts;
  - the mall counters;
  - the boardwalk;
  - phone frame rate;
  - the logo on a phone.
- **Phone frame rate is unmeasured.** **StreamingEnabled is off.** It's recommended as a separate Studio test, because client scripts currently expect the whole city to be loaded.
- **Owner-only settings:** Server Size = 12 on the Creator Dashboard, plus the listing title and description (suggestions are in `docs/V18_REPORT.md`).
- **Ideas not built:** a Downtown fountain plaza (no free land in the center).

## 10. How to work on it (the habits that kept it stable)
1. Inspect first. Say what exists and which script builds it before changing anything.
2. Make the change in `src/`. Keep new world geometry off roads (use `C.reserve` and `C.isFree`), and add new modules to all 3 order lists.
3. Run the affected suites, then the full regression (all `tests/*_test.lua`, 4 in parallel). Add a test for anything new.
4. Bump `C.VERSION.VERSION` and its notes in `Config.lua`, and update `tests/data_test.lua` to the new version.
5. Build the place file and drop-ins and run the round trip. Write `docs/VXX_REPORT.md` covering changes, the file list, exact simulated test counts, install, rollback and a Studio checklist. Update the README.
6. Commit with a clear message, then push.
