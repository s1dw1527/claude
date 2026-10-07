# Corner Empire v11.2 — Fixes from your Studio test

**Install BOTH scripts this time**: the server changed (`GameServer.rbxmx`) as well as the client
(`EmpireClient.rbxmx`). See section 3. Nothing was published. Same DataStore **`CornerEmpire_v5`**, same save format
(schema 11), no migration needed.

> **Testing honesty.** Everything below was checked in the repository's **simulated** engine only. The simulated
> engine has **no terrain** (which is exactly why the buried-base bug got past the v11 tests), so the terrain fix is
> checked against the worst case of the game's random hills (section 4). **Please re-test in Studio** with the list
> in section 5.

## 1. What was wrong, and the fix

| You reported | What was actually wrong | Fix |
|---|---|---|
| **Can't get into the secret base — the mountain overlaps it** | The world builder (`World.lua`, since v6) drops random **terrain hills** along the north edge of the map, and one sits right on the base. In real Roblox the hill filled the tunnel and the whole chamber with grass/rock terrain. The tests never saw it: the simulated engine has no terrain. | New `C.clearTerrain` in `World.lua`: it carves the terrain out of a built area and puts the normal ground back. The base now carves out its chamber (with walls and roof), the tunnel, the ravine and the dirt road up to the drain, the back exit and a lane south out of the hills. The rest of the hill stays around the rock, so it still looks like a mountain. |
| **None of the buttons in the base work (Check jobs etc.)** | 1) The stations were buried in that terrain, so you couldn't get near them. 2) The **Planning Room** and **Secret Computer** asked the Heists app for an "intel" tab that doesn't exist, so they opened an **empty window**. | 1) Fixed by the terrain carve. 2) Planning Room → Jobs, Secret Computer → Police scanner. The app also falls back to Jobs if it's ever asked for a tab it doesn't know. |
| (found while fixing the base) | The same hills could also bury **all 8 heist targets** (they're near the map edges). The race track's north bend sits close to the hills too. | Each target's lot and a lane back to the city are cleared; so is the race track's north bend. |
| **Arcade app doesn't work** | Every game needed a **second real player at a Fun Zone booth**. Alone (e.g. testing in Studio), nothing could ever start. | **▶ PLAY** in the Arcade app now starts the game right away against the **🤖 Arcade Bot**, from anywhere. The bot is beatable and plays by the same server rules. Waiting alone at a booth also shows **🤖 Play the Arcade Bot**. **👥 vs player** still shows the way to a booth. Bot games pay fewer tickets (5 for a win, 1 for playing; real matches pay 12 / 3), with the same caps, so they can't be farmed. |
| **Apartments don't give money right** | Rent is paid every 30 s as one lump with **no message**, and it wasn't part of the "+$/s" income shown. **Empty buildings were still charged full upkeep**, so an empty Luxury Tower quietly took **$48,000 every 30 s**. Cash dropped with no explanation. | Upkeep is now charged only for **rented** units, so an empty building costs nothing. Every rent day shows **"🏢 Rent +$X"** by your cash. The top bar shows the rent rate (`🏢 +$85/s rent`), the phone money row includes it, and 📊 MY EMPIRE lists it. |
| **Change the name on the banner when it changes** | Renaming a business only changed the floating label. The **sign on the building** still said the type ("☕ COFFEE", "LEMONADE"). | The storefront sign (shops, the lemonade stand, the tech startup, and the same buildings on city plots) now shows **your business's name** and your chosen logo, and updates when you rename it. |
| **Camera app glitched, half gone on phone** | Photo Mode's bar is 980 px wide. On a phone it was only shrunk to 45%, so it was still **441 px on a 390 px screen** (half off the screen) with ~5 px text. | On phones the bar is the screen's width, text at full size, the two button rows **swipe sideways**, **✖ Exit** comes first, a short hint, and the move pad sits above the bar. Desktop is unchanged. |
| **Messages too big** (on phone) | Speech bubbles, the names over people and the signs over buildings are drawn in screen pixels, so on a phone they cover much more of the view. Toasts could also spill out of their box. | On the phone layout, world labels/bubbles are drawn at **65%**, the Roblox chat window and chat bubbles use smaller text (and the chat window is shorter), and toasts are smaller and shrink their text to fit. Desktop is unchanged. *If you meant something else by "messages", tell me which screen.* |
| **Mobile** | — | All of the above, plus everything from v11.1. |

## 2. Files changed

- **Server (`GameServer`)**: `World` (terrain clearing), `Mountain` (carves, vents moved out of the chamber),
  `Heists` (target lots cleared, station tabs), `Race` (north bend cleared), `Arcade` (🤖 bot), `Rentals` (upkeep,
  rent rate, rent-day message), `Players` (rent rate in the HUD state), `Brands` + `Buildings` (sign shows the name),
  `Config` (version 11.2.0, update notes).
- **Client (`EmpireClient`)**: `ArcadeUI` (▶ PLAY / 👥 vs player / bot button), `HeistUI` (tab fallback), `HUD` (rent
  note, rent rate, smaller toasts), `Menus` (rent in 📊 MY EMPIRE), `PhotoMode` (phone bar), `Layout` (world labels
  and chat on phones).

## 3. Install (existing place, keeps all player data)

1. Open your place in Studio → **File → Save to File As…** → a backup (e.g. `CornerEmpire_before_v11_2.rbxlx`).
2. **Write down** your 7 pass IDs (`GameServer → Config → C.PASSES`) and your `owners = {...}` (`GameServer → Admin`).
3. **ServerScriptService** → delete `GameServer` → right-click → **Insert from File…** → `updates/GameServer.rbxmx`.
4. **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click → **Insert from File…** →
   `updates/EmpireClient.rbxmx`.
5. Put back your pass IDs (`id = 0` → your number) and `owners = {YOUR_USERID}`.
6. Don't touch `DATASTORE = "CornerEmpire_v5"`.

## 4. Tests (SIMULATED — not real Roblox)

Full run on the finished code: **25 suites, 1,289 checks, 0 failed.**

- **`terrain_test` (new, 4 / 4):** takes the **worst case** of the random edge hills (any position jitter, the biggest
  radius) and checks that no solid part the game builds can end up inside one. Exceptions are the mountain's own rock
  and the scenery on its slopes. The base (lever, tunnel mouth, chamber, all 7 stations, back exit) and all 8 heist
  targets must sit in cleared ground, and the dirt road up to the drain must be clear all the way. Before the fix this
  check found the whole base and every target inside possible hills.
- **`v112_test` (new, 30 / 30):**
  - every base station opens the Heists window on the right tab, with content;
  - an empty Walk-Up doesn't lower your cash;
  - with two tenants, one rent day pays about the shown rate × 30 s, and the client is told (the HUD rate and the "🏢 Rent" note);
  - renaming the stand and a shop changes the **sign on the building**;
  - ▶ PLAY starts Button Battle against the 🤖 Arcade Bot, the game plays out to a result and tickets are paid within the bot cap;
  - Reaction Duel, Hoop Duel and Kart Sprint also start against the bot;
  - waiting alone at a booth offers the bot;
  - at 390×700 the Photo Mode bar is 374 px wide at 100% text with ✖ Exit first, and a new speech bubble is drawn at 65% (100% again on desktop).
- **Bug found by the new test:** my first version of the bot code read `plr.bot` on a real Player. In Roblox, reading
  a property an Instance doesn't have **is an error**, so it would have broken every arcade message in Studio. The
  simulated engine is strict about this and caught it; it uses a lookup table now.
- Every earlier suite still passes, including `mobile_test` (157) and `heist_test` (100).
- Static checks: `luau-lsp` clean except the known `WorldFX.lua:59` false positive; the API property/enum check finds 0 problems.


## 5. Please re-test in Studio

- [ ] **Output** has no red errors on start (the terrain carving runs on start)
- [ ] Drive up the dirt road north of the race track → the ravine and **DRAIN 7** are open (no hill in the way)
- [ ] Pull the lever → the door opens → walk **and** drive through the tunnel into the chamber (no terrain inside)
- [ ] All 7 stations: Check jobs, Turn in loot, Bags & gear, Open intel (→ Jobs), Use computer (→ Police), Upgrade base, Get a car
- [ ] Back exit opens and leads out (lane south)
- [ ] Visit each heist target (bank, jeweler, warehouse, electronics, cargo yard, museum, vault, car garage): no terrain inside or in front
- [ ] Race track: the north bend isn't cut into a hill
- [ ] Arcade app → **▶ PLAY** on each game → plays against 🤖; win/lose screen; tickets go up
- [ ] At a Fun Zone booth alone → **🤖 Play the Arcade Bot**
- [ ] Apartments: an empty building no longer lowers your cash; with tenants, **"🏢 Rent +$…"** every 30 s and `🏢 +$…/s rent` in the top bar
- [ ] Rename a business → the **sign on the building** shows the new name
- [ ] Phone size (Test → Device, 390×700): Photo Mode bar fits, rows swipe, ✖ Exit works; bubbles/labels over people are smaller; chat smaller
