# Corner Empire v10 — "Ownership, HQ, Cars & Lifestyle" — Report

**Deliverables:**
- `CornerEmpire_v10.rbxlx`: the same game and the same DataStore (`CornerEmpire_v5`), upgraded, not rebuilt.
- Drop-in scripts: `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx`.
- Rojo: `default.project.json`.

**How v10 was tested.** Everything below was run in the repository's simulated Roblox engine (`tests/harness.lua`):
- It runs the real server and client scripts with in-memory DataStores and simulated time.
- It rejects any property or method that doesn't exist on a real Roblox class.
- It has **no physics, no rendering, no real touch or gamepad hardware, no real text filter, no real friends
  list and no real network.**

Anything that depends on those is listed in §12, **"Still needs testing in Roblox Studio"**.
**Nothing in this report has been run inside the real Roblox Studio or a live Roblox server.**

---

## 1. What changed (summary)

| Area | What v10 adds | Built on (reused, not duplicated) |
|---|---|---|
| Real estate | 8 districts, ~100 plots, **permanent deeds**, per-district caps, a property limit that grows with reputation, FOR SALE / OWNED BY signs, property card, choose / change / sell | The v5–v9 land lots (kept as the first 16 plots; saved lots become deeds) |
| Businesses | Server-filtered names, brand (logo, sign, accent, exterior, uniform, interior theme, menu style), products (price, quality, presentation, ingredients, popularity, trends), product slots by level, supplies + restocking | The existing 8 businesses, levels, income formula, customers |
| HQ | The Empire Tower becomes a 6-floor walk-in HQ with an elevator, staff and the Empire Wall | v9 interiors (sky rooms, doors, waypoints, staff life) |
| General Manager | Contracts (15–60 min), timed repairs, parallel jobs, prioritizing, advanced problems, expiry, guarded auto-renew | The existing staff "Manager" (its level = its experience) and the problem system |
| Computer | 4 tiers, 11 apps, remote restock, product analytics, remote contracts | Existing state (finances, inventory, messages, events) |
| Houses | 7 tiers (2 new exterior tiers), 34-item furniture shop in 9 categories, grid placement, layouts, ceiling/door/window styles | v8 home interior, wall/floor/light styles and decor spots (still work) |
| Visitors | PUBLIC / FRIENDS / INVITE ONLY / PRIVATE for house, businesses and HQ | The interior entry point (`enterInterior`) |
| Cars | 16 original vehicles (6 new), 7 classes, acceleration/braking/nitro stats, brake lights, signals, dash, steering wheel, mirror; garage; cosmetic customization | v8 driving controller, drift, nitro, race, deliveries (unchanged controls) |
| Fun Zone + arcade | 4 server-authoritative 2-player games, booths, arcade machines at home and in Arcade businesses, tickets, prizes, leaderboard | Furniture system (prizes), interiors (machines) |
| Admin panel | Server-side roles, separate admin DataStore, 12 tabs, confirmation tokens, log | Existing teleports, events, Studio test hooks |
| Tutorial | 18 contextual tips, "❓ What's this?" on every new window, tips on/off, computer Tasks | The 7-step opening tutorial (texts refreshed) |
| Data | Schema 10 migration, v10 repair-never-fail rules | v8 `DataMigration` and save pipeline (unchanged rules) |

---

## 2. Files

**New, server (`ServerScriptService > GameServer`):**
- `RealEstate`: districts, plots, deeds (place / release / relocate), limits, prices, the property card, choose/sell.
- `Brands`: the server text filter wrapper, business names, brand styles, products, supplies, restocking, trends.
- `HQ`: HQ floors and rooms, the elevator, the General Manager (contracts, jobs, expiry, auto-renew).
- `Computer`: computer tiers, sessions (only at a computer you own), the apps' data, remote actions.
- `HomeBuilder`: furniture catalog, grid validation, layouts and styles, building the room, visitor permissions.
- `Garage`: car classes and stats, customization options, equip/favorite/rename/customize/sell.
- `Arcade`: the Fun Zone, stations, the 4 games, rewards and caps, forfeits, prizes, leaderboard.
- `Admin`: roles, the admin DataStore, tools, confirmation tokens, the log.
- `Guide`: tips, help texts, tasks.

**New, client (`StarterPlayerScripts > EmpireClient`):**
`BusinessUI` (property card, choose, name, manage: products/supplies/brand, the shared confirm dialog), `HQUI`,
`ComputerUI`, `BuilderUI` (furniture shop, grid builder, styles, visitors), `GarageUI`, `ArcadeUI`, `AdminPanel`
(+ fly/noclip), `GuideUI`.

**Changed:**
- `Config`: version 10.0.0 / schema 10, 8 districts, 7 house tiers, 16 cars with classes and stats, tutorial texts.
- `DataMigration`: the 9 → 10 step (lots → deeds), `v10Defaults`, `repairV10` (two levels deep), samples, self-tests.
- `Players`: v10 save keys, deed placement on join/leave, state, the catalog, mute check on posts, district teleports.
- `Systems`: deeds in income and land counts, product/location/supply multipliers, forced city events (admin), manager hook.
- `Buildings`: branded storefronts, the HQ door. `Interiors`: HQ floors, brand menus/uniforms, the home builder's
  layout and furniture, the Arcade duel cabinet, the permission check. `Housing`: tiers 6–7. `Cars`: customization,
  detail parts, the 16-car showroom. `Mega`, `ViralMoments`: manager hook, trending products.
- Client: `Driving` (per-car acceleration/braking/nitro, car details), `InteriorLife` (HQ crew, brand uniforms, menu
  lines), `HUD`, `Menus` (City map with all districts, home tools, 7 house pips; the old garage moved to `GarageUI`),
  `Phone` (HQ and Arcade apps), `InteriorUI`.
- Tests and tools: `harness` (text-filter mock, username lookups, `CreatorType`), `check.sh` (unknown-global lint),
  `economy_sim` (buys plots, restocks).

---

## 3. Real estate

| District | Plots | Per-player cap | Unlocks at | Notes |
|---|---|---|---|---|
| Downtown | 8 | 2 | LOCAL FAVORITE | Prime, limited |
| Waterfront | 5 | 1 | CITY ICON | Prime, limited |
| Luxury | 4 | 1 | EMPIRE | Prime, limited |
| Industrial | 8 | 2 | HOTSPOT | Large plots |
| Entertainment | 15 | 3 | HOTSPOT | Around the Fun Zone |
| Midtown | 20 | 5 | LOCAL FAVORITE | Plenty |
| Northside Suburbs | 20 | 5 | UNKNOWN CORNER | Cheap starter plots |
| Expansion | 20 | 5 | EMPIRE | Late-game land |

- **Fairness in a 1–4 player server:** every district's cap × 4 players fits in its plot count (tested), so one player
  can never lock everyone else out. Prices rise ×1.25 per plot you already own in that district.
- **Total properties you can own:** 1 / 2 / 4 / 6 / 9 / 12 by reputation tier, +1 per 10 rebirths (max +4).
- **Deeds are permanent.** They're saved with the player. On join each deed goes back on its plot, or on another free
  plot in the same district if someone else took it while you were away. A deed that can't be placed still counts and
  still earns.
- You can't buy another player's property (the card shows OWNED BY and a View/Visit button). Selling asks to confirm
  and returns 50%.

## 4. Businesses, products and supplies

- **Names:** 3–24 characters, filtered by `TextService` on the server; a failed or masked filter result is refused.
  First rename free, then a 10-minute cooldown and a fee.
- **Brand:** logo, sign, accent and exterior colours, uniform, interior theme, menu style. Cosmetic.
- **Products:** slots at levels 1/3/5/7/10. Demand = f(price, quality, presentation, popularity, ingredients), clamped;
  income multiplier 0.6–1.35 (defaults give exactly 1.0, so existing saves earn the same). Trends are temporary and
  rate-limited (no farming).
- **Supplies:** 0.08% per customer; below 20% sales drop (to 75% at empty). Restock at the business, through the
  manager, or remotely from an Executive Workstation (+10% delivery).

## 5. HQ, manager, computer

- Floors: Reception $250K · Management $2M · Finance $15M · Executive $100M · Private Office $600M · Rooftop $3B
  (unlocks at HOTSPOT). Each floor is built on demand like other interiors and removed when empty.
- Manager contracts cost ~8% of what you'd earn during the contract (min $2,000), only count down while you play, and
  stop at 0 with "MANAGER CONTRACT EXPIRED". Auto-renew is off by default; when on, it renews at most twice in a row
  and only if you did something in the last 10 minutes — so it isn't AFK income. Repairs and restocks cost the
  normal price.
- Computers: Basic $5K · Gaming PC $250K · Executive Workstation $5M · Empire Command Center $100M. The server only
  answers while you stand at a computer you own (home, or the HQ office / Empire Wall).

## 6. Houses and visitors

- Tiers: Starter Home → Expanded Home → Luxury Home → Modern Estate → Mansion → **Mega Mansion** (third floor, a
  second wing, a lit driveway) → **Empire Estate** (gold trim, a grand gate, statues, a searchlight).
- Grid: 14 × 10 cells of 4 studs. Checked on the server: inside the room, not across a wall, not in the doorway or on
  a built-in fixture, no overlaps (rugs can go under), and at most 10 + 8 × tier items. Picking up returns the item
  to storage; selling from storage refunds 40% (no money loop).
- Layouts: Classic rooms (now with real doorways), Open Loft, Split Level, Master Suite. Changing the layout returns
  anything that no longer fits to storage.
- Visitors: house PUBLIC, businesses PUBLIC, HQ FRIENDS by default. Invites are for players in the server.
  Switching to a stricter mode shows current visitors out. Friend checks are cached for 5 minutes.

## 7. Cars

| Class | Cars |
|---|---|
| Economy | Zippa Moped, City Hatch, Pixie EV (new), Sedan LX |
| SUV | Trail SUV, Boulder XL (new) |
| Truck | Delivery Van, Monster Truck |
| Luxury | Velmora Grand (new), Halcyon GT (new) |
| Sports | Sports Coupe, Vortex R (new) |
| Supercar | Nightfang (new) |
| Hypercar | Hyper Car, Golden Supercar (pass), Legend Hypercar (100 rebirths) |

- All names and designs are fictional (the test checks the names against a list of real makes and models).
- Car keys are unchanged, so owned cars carry over. The driving controller is the same (keyboard, controller, touch,
  drift, nitro, reverse); acceleration, braking and nitro now come from each car.
- Details: brake lights and turn signals are worked out on every client from how each nearby car moves (no network
  traffic); the driver's own car uses real input, and its dash shows the speed and its steering wheel turns.
- Customization is cosmetic only (tested: speed is unchanged).

## 8. Fun Zone and arcade

- Games: Reaction Duel (best of 3, false starts), Button Battle (10 s, ≤ 14 taps/s counted), Hoop Duel (5 shots,
  target timed by the server), Kart Sprint (≤ 12 steps/s).
- Rewards: win 12 tickets, play 3; a match shorter than 6 s pays nothing; 5 rewarded games per opponent per
  10 minutes, 30 per hour. Leaving the booth (40 studs), the room (machines) or the server forfeits.
- Prizes are furniture, never cash.

## 9. Admin panel

- **Authorization is server-only.** Owners come from `C.ADMIN_CONFIG.owners`, the place creator, or a group rank;
  admins from the `CornerEmpire_Admins_v1` DataStore (its own store, `_StudioTest` copy in Studio). Player save data
  is never consulted (tested: admin-looking fields and attributes change nothing).
- Adding an admin: the server resolves the typed username with `GetUserIdFromNameAsync` and stores the UserId. Only
  owners can add or remove admins; owners can't be kicked from the panel.
- Every request goes through one action that checks the role first. Non-admin requests get no response and are
  logged (rate-limited).
- **Dangerous tools** (remove cash / item / car, kick, remove admin) return a one-time token; the panel shows a
  confirmation dialog and sends it back. Tokens expire after 30 s, work once, and only for the admin they were issued to.
- Tabs: OVERVIEW, PLAYERS, ECONOMY, ITEMS, BUSINESSES, PROPERTIES, VEHICLES, EVENTS, TELEPORT, MODERATION, SERVER,
  DEVELOPER. Fun tools (fly, noclip, invisible, speed, jump, test NPCs) are switched on by the server, for admins only.
- The log keeps names, UserIds, the tool, the target and amounts (no message contents beyond 60 characters).

## 10. Save data (schema 10)

New saved fields: `deeds`, `deedSeq`, `brands`, `products`, `stock`, `hq`, `mgr`, `computer`, `homeBuild`,
`furniture`, `carMods`, `garage`, `arcade`, `perms`, `invites`, `guide`.

- **9 → 10:** v5–v9 land lots (ids 1–16) become deeds in their district; every new field gets a default.
- **Repair, never fail:** a damaged v10 field (wrong type, NaN or negative numbers, a bad sub-field such as
  `homeBuild.items = "x"`) is reset alone; the original is kept as `<field>Recovered`; the rest of the save loads.
- Unchanged rules: same DataStore and keys, `UpdateAsync` with a save counter, newer-schema saves load read-only,
  unknown fields are kept.

__TESTS__

## 12. Known limitations

- Remote restocking and contracts need the player to stand at their computer; there's no "phone" shortcut by design.
- Admin mutes cover CityBuzz posts in that server only (Roblox chat is not filtered by the panel). Kicks are not bans.
- The admin list is re-read every 60 s, so an admin added on another server gets the panel within a minute.
- Plots can't be traded between players.
- The arcade games are UI games (on-screen), not physical 3D courts.
- The Fun Zone and new districts aren't on the v8 Map app's landmark list yet (they are on the City map and teleports).

## 13. Still needs testing in Roblox Studio (not covered by the simulation)

- **Looks:** the new district slabs and plot spacing in the real terrain, branded storefronts, HQ rooms and the
  Empire Wall map, tiers 6–7 houses, every furniture model, the 6 new cars and every customization part, the Fun Zone.
- **Physics:** driving each new car (acceleration/braking feel, the Boulder XL's height, the Vortex R's wing), the
  steering-wheel Weld under real physics, fly/noclip, frozen players.
- **Real services:** the text filter on names, plates and admin messages; `IsFriendsWith`; `GetUserIdFromNameAsync`;
  the admin DataStore with API access; group ranks.
- **Input:** the grid builder and arcade buttons on phones and with a controller; the admin panel on small screens.
- **Multiplayer:** two real players in an arcade match (latency on Reaction Duel and Hoop Duel), visitor permissions
  with real friends, deeds relocating across real server switches.
- **Performance:** frame rate with ~100 plot signs, the Fun Zone and several HQ floors on low-end phones.
