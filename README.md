# Corner Empire

A 1–12 player Roblox business tycoon (Corner Empire: Rags to Billions). **`CornerEmpire_v19.rbxlx` is the current place file**; open it in Roblox Studio.
`CornerEmpire_v18.rbxlx`, `CornerEmpire_v15.rbxlx`, `CornerEmpire_v14.rbxlx`, `CornerEmpire_v13.rbxlx`, `CornerEmpire_v12.rbxlx`, `CornerEmpire_v11_3.rbxlx`, `CornerEmpire_v11_2.rbxlx` … `CornerEmpire_v5.rbxlx` are earlier versions, kept for reference. The full v11 write-up is
`docs/V11_REPORT.md`; install steps and the real-Studio test list are in `docs/V11_STUDIO_CHECKLIST.md`. The v11.1
mobile UI overhaul (client only) is in `docs/V11_1_MOBILE_REPORT.md`.

## What's new in v19 — The City Rises (server + client)

A world visual overhaul. Visual only: same DataStore, same save schema (16), no save changes.

- **No more empty slabs.**
  - Every unsold plot has a vacant building in its district's style, with "FOR LEASE" on it. Its View Property sign stays at the front corner.
  - **Midtown is now Restaurant Row,** with string lights, 16 city-run restaurants and a park.
  - **The Entertainment District** has neon streets with arcades and clubs.
  - **The Suburbs** have small shops; **Expansion** has buildings under construction.
- **Downtown's skyline is rebuilt:** stepped towers with lit window bands and 4 kinds of crown.
- **New landmarks:**
  - the **Heights Mall**, with a parking lot and working Bazaar and Furniture counters;
  - a **beach boardwalk** with umbrellas, loungers and snack stands;
  - a **lighthouse** on the pier;
  - Industrial pipe racks, docks, trucks and a gantry crane.
- **Windows light up at night** (switched on each player's device, so no network traffic).
- **Logo:** a gold crown over CORNER EMPIRE with "BUILD • RUN • EXPLORE • RISE", on the menu and the title card.

Install both drop-ins, or open `CornerEmpire_v19.rbxlx`. Details, the changed files, test results, the Studio checklist and rollback: `docs/V19_REPORT.md`. Previews of each district (simulated parts, not screenshots): `docs/v19_previews/`. **Not tested in real Studio.**

## What's new in v18 — Rags to Billions (server + client)

- **New name: "Corner Empire: Rags to Billions"** on the menu and the opening movie's title card. Ready-to-paste listing title and description are in the report.
- **12-player servers:** **Empire Heights**, a new neighbourhood past the Corner Bank with 8 more plots on Heights Blvd. **Also set Server Size = 12** on the Creator Dashboard.
- **📚 Collection Book:** 21 rare things to find, with the unfound ones shown as **❓ ???**, and milestone rewards.
- **🔮 "Coming up next" card,** once a session: tomorrow's reward, the next city event, the next Bazaar restock.

Same DataStore, same save schema (16). Install both drop-ins. Details, test results and the Studio checklist: `docs/V18_REPORT.md`. **Not tested in real Studio.**

## What's new in v17 — Viral Hooks (server + client)

Built from research into Roblox games that went viral (Grow a Garden, Dead Rails, 99 Nights) and from Roblox's discovery documentation.

- **🛍️ City Bazaar:** a shop that restocks every 5 minutes with 18 Bazaar-only furniture pieces, from Common to 🌈 Mythic.
  - Every server has the same stock at the same time.
  - Each player has a limit per restock, which is saved.
  - Paid in in-game cash only.
  - There's a stall in the plaza and a new phone app.
- **✨ Lucky customers:** a glowing ✨ Golden (×10), 💎 Diamond (×50) or 🌈 Rainbow (×250, capped) customer that everyone sees walk in. Diamond and Rainbow are shouted to the server.
- **⚡ A faster first 90 seconds** for new saves:
  - The first customer walks straight in: the first sale comes at 1.8 s, down from 14.2 s.
  - A "FIRST SALE!" moment.
  - A 90-second grand opening crowd.
- **🎨 Graphics pass** (compared with popular Roblox games):
  - **Future lighting** is now set in the place file. It was never set before, which was the main reason the game looked flat. In an existing place, set Lighting → Technology → Future once by hand.
  - Less flat ambient light, so shadows show.
  - A clearer atmosphere, and no blur on the city.
  - The grade adds contrast instead of saturation.
  - No more blown-out pure-white parts.
- **📊 Creator Analytics:**
  - an onboarding funnel (8 steps, new saves only);
  - economy events (throttled);
  - custom events (rare sales, intro watched or skipped).

Same DataStore, same save schema (16): the new fields are additive. Install both drop-ins. Research and sources, test results, the owner launch checklist and the Studio checklist: `docs/V17_REPORT.md`. **Not tested in real Studio.**

## What's new in v16.1 — Bold UI (client; the server only gets the new version number)

- **Chunky cartoon buttons everywhere:** glossy, a thick dark outline, Fredoka One lettering with an outline.
- **Window title banners** in each window's color, with a **red X**.
- **A tabbed 🛒 Store:** All / Money / Perks, with a glossy card and a green Robux pill for each pass. It's the same passes and prices.
- **Phone:** glossy app tiles with a 🔒 glass overlay on locked apps.
- **HUD:** a glass top bar with a big **level bar** showing your %.
- **Settings and My Empire:** "Statistics" rows; ON is green and OFF is red.

It's visual only: same DataStore, same save schema (16). Details, test results and the Studio look-and-feel checklist: `docs/V16_1_UI_REPORT.md`. **Not tested in real Studio.**

## What's new in v16 — Life & Empire: Rise to Riches (server + client)

- **🎬 Opening cinematic.**
  - About 20 s over the real city: "Every empire starts with nothing" → build it legit, take big risks, or rule both sides → "Your city. Your empire. Your rules." → the CORNER EMPIRE title card.
  - It plays once per account and can be skipped from the first frame.
  - Returning players get **Welcome back** (Continue Empire / Replay intro) instead. It can be replayed from Settings.
- **Three paths on one economy:** 💼 Business Mogul, 🕶️ Underworld Operator (the existing heists, fictional) and 👑 Empire Legend (both). Each has levels, titles and contracts. Nothing is locked.
- **🎁 Daily:**
  - A 7-day login strip on UTC days with a forgiving streak (a weekly 🛡️ shield; missed days step back, never reset).
  - 3 daily missions from real gameplay, and a weekly challenge.
  - It's per account, and rewards are written ahead, so they're never doubled or lost.
- **Live city events** on a shared UTC schedule (Restaurant Rush, Funland Night, Rival Takeover, Double Delivery, Underworld Alert, Luxury Showcase, Community Weekend), each with a boost and a goal.
- **Together:** park visit and host rewards, co-op bonuses, and a 🪪 showcase card with the titles and badges you wear.
- **🗺️ Empire Roadmap:** 7 stages from Street Starter to Empire Legend, built from the real unlock rules. A starting-attitude choice picks your first goal.
- **Notifications:** critical alerts are never dropped, small ones are grouped, and non-essential pop-ups can be muted. There's an effects volume and a 🚌 tour bus at good parks.

Same `CornerEmpire_v5` DataStore. Save schema 16 is additive, and the account records live in the existing meta key. Install both drop-ins. Details, migration notes, test results and the Studio checklist: `docs/V16_REPORT.md`. **Not tested in real Studio.**

## What's new in v15 — Life & Empire: Funland (server + client)

- **Fixes from Studio testing**
  - Nothing stands in the street any more: plaza benches, trees and rocks on the mountain road and heist driveways,
    the race gantry pole, a showroom car and the Hillside gate were all moved. A new `layout_test` checks every
    solid part in the city against every lane and reserved path.
  - Traffic and police no longer drive through the Empire Spire. Traffic cars are placed before they appear, and a
    car stuck at a dead end is recycled.
  - Mountain base stations (job board, computer, planning room, gear): each prompt now sits in front of its counter
    where you can reach it, the crew stand behind the counters, and a ⛰️ BASE MENU card opens the same screens while
    you're inside.
  - The 🎬 Movie Theater can be bought from its own menu: a new plot picker lets you open it on a plot you own, or buy
    a plot and open it there in one step.
- **🎢 Amusement Park** (10th business): its ticket gate goes on a city plot, and you build the park itself on your
  own site at the new Funland Grounds (west of the Fun Park).
  - 9 rides, including two roller coasters with a loop, plus food stalls, paths and decorations.
  - A tap-to-place build plan in the 🎢 Park app. The server checks every placement.
  - The park's rating raises its sales (up to ×1.8). Other players pay you a ticket when they ride.
  - Visitors with cotton candy and balloons walk your paths.
- **🎡 Fun Park makeover**
  - New rides: 🎢 the Big Dipper roller coaster (lift hill, drop, loop; you ride in the front car), 🗼 Sky Drop and
    🌀 the Whirl.
  - Food stalls with queues, people with cotton candy and balloons, and string lights.
- **Graphics**
  - A sky with sun, moon and stars.
  - Warm sunrises and sunsets, blue nights, and neon that glows after dark.
  - Street trees and bins along the sidewalks.

Same `CornerEmpire_v5` DataStore; save schema 15 (adds only the park record). Install both drop-ins. Details,
migration notes, test results and the Studio checklist: `docs/V15_REPORT.md`. **Not tested in real Studio.**

## What's new in v14 — Life & Empire: Main Street (server + client)

- **City and feel**
  - NPC police replace player police: they patrol, respond, chase and arrest on the road network.
  - Clearer UI: contrast fixes, short color-coded toasts, a 🔔 Activity log, and a press sound on every button.
  - Music that follows what you do, plus ambience and jingles.
  - 🍳 Rush Orders: cook at your own counter.
- **Phase B**
  - 🎬 Movie Theater on a city plot: films, premieres, shows, upgrades.
  - 🥊 AI rivals with timed challenges.
  - Staff traits, shifts and learning on the job.
  - +1 property capacity from Hotspot up.
- **Phase C**
  - 🤝 Secure gifts through a crash-safe ledger.
  - Co-owned businesses: partner and manager roles, upgrades paid by partners, revenue shares, a log.
  - 🏢 City Lofts and 🎉 home parties.
- **Phase D**
  - Car roles and server-checked tuning.
  - 📊 Leaderboards for this server, global and friends.
  - 🌟 Prestige.
- **Phase E**
  - 📅 Special occasions on the real calendar, with saved rewards and a Weekend Rush.
  - A 10-step 🧭 Next Step guide after the tutorial.

Same `CornerEmpire_v5` DataStore; save schema 14 (additive). Install both drop-ins. Details, migration notes, test
results and the Studio checklist: `docs/V14_REPORT.md`. **Not tested in real Studio.**

## What's new in v13 — Life & Empire, Phase A: Living City (server + client)

The city is busy wherever you are: pooled pedestrians and traffic on the real road network (cars stop at red lights,
keep their distance and turn at junctions; people wait to cross), a different crowd in every district, buses,
delivery vans and street scenes. New 🧭 Explore app: City Jobs (courier runs, lost dogs, street clean-ups), 30 Golden
Corners and 20 places to discover, all checked on the server. Every phone app passed a leak audit. Same
`CornerEmpire_v5` DataStore; save schema 13 (additive). Install both drop-ins. Details, test results, the
Studio checklist and the roadmap for Phases B–E: `docs/V13_REPORT.md`. Not tested in real Studio.

## What's new in v12 — City Takeover & Billionaire Progression (server + client)

Server-verified $1M / $10M / $100M / $1B empire milestones with celebrations, a growing Empire Tower, the Empire Plaza
and Hall of Fame billboards on the beach, storefront makeovers, Grand Re-Openings for new building tiers, an HQ reveal,
first-income / first-upgrade moments and the 👑 Empire app. Same `CornerEmpire_v5` DataStore; save schema 12 (additive
migration). Install both `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx`. Details, install steps, the
simulated-vs-Studio test split and the thumbnail advice: `docs/V12_REPORT.md`. Not tested in real Studio.

## What's new in v11.3 — phone layout rework (client only)

On phones: a 34 px money / income / reputation row, the story chip under it, small evenly spaced 44 px buttons on the
left, 📸 ⚙️ 📱 on the right above the jump button, **one** notification stack in the top-right corner (at most 3
cards, kept out of the middle of the screen, the rest wait), CityBuzz as a small expandable line instead of pop-ups,
the bottom of the screen left free for driving and action buttons, big announcements as small banners. Details,
wireframes and the Studio checklist: `docs/V11_3_LAYOUT_REPORT.md`. Only `EmpireClient` changed.

## What's new in v11.2 — fixes from Studio testing (server + client)

The random terrain hills along the map edge were burying the secret base and could bury the heist targets: built
areas are now cleared of terrain (`C.clearTerrain` in `World`). Base stations open the right Heists tabs. ▶ PLAY in the
Arcade app starts a game against the 🤖 Arcade Bot (real players still play at the booths). Apartments: empty units
cost no upkeep, rent day shows "🏢 Rent +$X", and the top bar shows the rent rate. The building's sign shows your
business's name after a rename. Phones: Photo Mode fits the screen, world labels and chat are smaller. Details and
the Studio re-test list: `docs/V11_2_FIX_REPORT.md`. Version 11.2.0, save schema still 11.

## What's new in v11.1 — Mobile UI overhaul (client only)

On phones (viewport ≤ 700 wide or ≤ 500 tall) the game now uses a real mobile layout instead of the desktop UI
squeezed onto the screen: one compact money row with a ⭐ tier badge, a story chip and an event chip, small 🏪 / 🏆
edge buttons for the business panel and the leaderboard, CityBuzz as a 4-second notification, a centred, phone-sized
phone, windows that reflow to the screen (text never below 80%) with only one open at a time, GAS/BRAKE pedals for
touch driving, a mobile builder layout, and vertical game cards in the Arcade app. Desktop keeps the classic layout.
The layout manager is `EmpireClient > Layout` (also `C.UIManager`). Only `EmpireClient` changed; the server and the
DataStore (`CornerEmpire_v5`) are untouched. Tested in the simulated engine only — see the report for the Studio
mobile checklist.

## What's new in v11 — "Secret Mountain Base & Heists"

Corner Empire now has three loops: **BUILD** (businesses, homes, property), **LIVE** (drive, visit, arcade,
customize) and **RISK** (the secret base and robberies).

- **Phone Arcade app fixed.** Opening it started an endless request → reopen loop (about 30 requests in 5 seconds)
  that made the phone glitch. Root cause: opening any window hid and re-showed it, which reset its "already asked
  the server" flag. `openModal` no longer hides the window it opens, so every phone window now asks once.
- **The secret mountain HQ.** North of the race track, at the end of a dirt road: a mountain with a drain in a
  ravine. Pull the rusty lever and a hidden door slides open (shared by everyone, never traps anyone). Drive through
  the sewer tunnel into a huge chamber around a lava core: the Blackrock Syndicate's hideout, with a crew of 8
  fictional NPCs, a Job Board, the Fence, the Quartermaster, a Planning Room, a secret computer, base upgrades and
  an Escape Garage. A back exit leads out east. There's no map marker: you find it from rumors and clues.
- **Heists.** 8 targets (Corner Bank, Gem & Gold Jewelers, Luxury Warehouse, Volt Electronics Depot, Northside Cargo
  Yard, City History Museum, City Vault, Prestige Car Garage) open a few at a time for about 3 minutes. Start the
  robbery, crack the security panel (a short puzzle), mind the lasers, fill your **bag**, and when the **alarm**
  goes off, get out. The loot is **not money until you reach the mountain**: arrested, gone, dead or too slow, and
  only the loot is lost. Crews of 1–4 share one target's loot. Bags and base levels are upgrades.
- **Police duty.** Go on duty at the police station or in the app. Police get alerts and an approximate,
  updating search area (never your exact position), and hold [Arrest] near a robber carrying loot. The city pays
  them.
- **💰 Heists phone app**, 9 new tips, 3 new "❓ What's this?" topics, and a HEISTS tab in the admin panel for testing.

## What was new in v10 — "Ownership, HQ, Cars & Lifestyle"

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
  (6 → 7 → 8 → 9 → 10 → 11), on a copy, then validates it. If anything fails, the player plays with saving **turned off** for that
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
safety test**. It runs the migration self-test on v5–v11 sample saves (including damaged v9, v10 and v11 records) and the real
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
- `tools/build.py` rebuilds the place file from `src/` (`python3 tools/build.py CornerEmpire_v16.rbxlx`).
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
  - v11: `phoneapp_test` (the Arcade app glitch: open → close → open, switching apps, during/after a game, phone
    size), `heist_test` (mountain, door, tunnel, discovery, crew; every robbery stage, police, arrests, failures,
    crews of 1–4, upgrades, anti-exploit, saving)
  - v11.2: `terrain_test` (nothing built can end up inside the worst case of the random terrain hills), `v112_test`
    (base stations, rent, building sign after a rename, 🤖 Arcade Bot, Photo Mode and labels on a phone)
  - v11.1: `mobile_test` (computes every element's on-screen rectangle at 390×700, 430×932, 393×852, 375×667 and
    844×390: HUD inside the screen and the safe area, no overlaps, ≥ 70% of the screen free, centre clear, every window
    and phone app fits, one window at a time, driving controls clear of the thumbstick / jump button / road, Arcade
    lifecycle on a phone, no per-frame layout work, desktop layout restored exactly)
  - v14: `heist_test` (NPC police), `ui_test` (contrast scan, toasts), `audio_test`, `kitchen_test` (Rush Orders),
    `theater_test`, `rivals_test` (rivals + crew), `partners_test` (ledger failure recovery, gifts, co-ownership),
    `homelife_test` (lofts, parties), `leaders_test` (car roles + tuning, leaderboards, prestige), `journey_test`
    (special occasions, onboarding)
  - v16: `intro_test` (opening cinematic: first-ever vs returning, skip, replay, one at a time, cleanup after an error, a respawn or starting a game, phone size), `daily_test` (claims once per UTC day incl. concurrent and crash-in-the-middle, streak shield, missions and weekly from real events), `roadmap_test` (stages from the real rules, paths, contracts, starting attitude, the Daily app), `events_test` (UTC schedule, boosts, goals once per window, no interruptions), `social_test` (visit + host + co-op rewards and caps, showcase privacy, titles)
  - v15: `layout_test` (nothing solid in a lane or on a reserved path, plaza benches, no traffic through the Spire,
    clear mountain road), `park_test` (Amusement Park: menus, build plan, refusals, rating, rides, riding, visitors,
    sites, save), `funpark_test` (Big Dipper, Sky Drop, Whirl, stalls and crowd), `graphics_test` (sky, time-of-day
    grade, street props, light LOD); `heist_test` (stations reachable, BASE MENU), `theater_test` (buying it through
    the menus)
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
