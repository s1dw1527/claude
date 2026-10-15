# Corner Empire v19: "The City Rises" (world visual overhaul)

You asked for the actual 3D world to match the reference map: every district built up and recognizable, lit at night, with no empty slabs. You also asked to keep everything that works, keep saves safe, and stay honest about testing.

> **Not tested in Roblox Studio, and nothing was published.**
> - Every result below comes from the simulated engine (`tests/run.py`).
> - The pictures in `docs/v19_previews/` are **part previews** drawn from the simulated world (`tools/iso.py`). They show shapes, sizes, colors and layout. They have **no Roblox lighting, shadows, textures or terrain**, and they are not screenshots of the game.
> - **Not tested:** visual rendering, physics, frame rate on phones, real DataStores and live multiplayer.
>
> **Saves are untouched.** The DataStore is still `CornerEmpire_v5`, and the save schema stays at 16. This update changes visuals only: no save fields were added, renamed or removed, and nothing is reset.

The inspection and plan came first, in `docs/V19_WORLD_PLAN.md`.

---

## 1. What changed, district by district

The whole map is built by server scripts at startup; there is no hand-placed map. So every change below is code you can review, and rolling back means restoring the previous scripts.

| District | Before (v18) | Now (v19) |
|---|---|---|
| **Unsold plots everywhere** (100 plots) | A flat gray slab with a small FOR SALE post | A **vacant building in the district's style**, with "FOR LEASE" on its sign ("COMING SOON" in Expansion). The FOR SALE sign and its **View Property** prompt stand at the plot's front corner, reachable from the sidewalk. Buying the plot clears the vacant building and builds your business, exactly as before. |
| **Downtown** | 6 identical glass boxes | Towers rebuilt with a podium and lit lobby, 2–3 stepped tiers, corner columns, window bands that light up at night, a blinking beacon, and one of 4 crowns (spire, stepped pyramid, helipad, antenna mast). Unsold Downtown plots get glass office buildings. |
| **Midtown → Restaurant Row** | Bare slab between 20 plots | The gate reads **"MIDTOWN • RESTAURANT ROW"**. Both streets have sidewalks, curbs, trees and **strings of lights**. 16 city-run restaurants with original names (Nonna's Kitchen, Golden Wok, Taco Corner…) fill the gaps, with outdoor seating, umbrellas and menu boards. There's a small park with a fountain (Midtown Green). It's the same district, not a duplicate. |
| **Entertainment District** | Bare purple slab | 3 **neon-lit streets** in front of the plots. 10 city-run arcades and clubs (Pixel Palace, Starlight Lanes, Galaxy Bowl…) between the plots, with dark walls, neon trim and marquee signs. The Fun Zone stays in the middle. |
| **Northside Suburbs** | Bare grass slab | Streets with sidewalks and trees, 16 small painted shops with gable roofs and awnings (Corner Deli, Book Nook…), and a green in the middle. |
| **Expansion District** | Bare asphalt slab | The district is "going up": streets, half-built buildings with scaffolding, an occasional crane, and "UNDER CONSTRUCTION" banners. |
| **Shopping (Heights Mall)** | None | **New landmark** at the end of Heights Blvd: a parking lot with parked cars and light poles, then the mall with a glass dome, lit storefronts, a canopy and planters. Two **working counters**: 🛍️ City Bazaar and 🛋️ Furniture Store, which open the same windows as the phone apps. It's a map destination. |
| **Beachfront** | Palms, pier, stage | A **boardwalk** along the beach (plank sections, rails, lamps, benches), umbrellas with loungers, two snack stands (🍦 Shake Shack, 🥤 Coco Cabana), and a **lighthouse** at the end of the pier, with a rotating beam. |
| **Industrial** | 2 warehouses, 4 tanks | Pipe racks between the buildings, loading docks with box trucks at both warehouses, and a yellow gantry crane. |
| **Theater, Fun Park, Raceway, Mountain base** | Already have their set pieces (v14 and v15) | **Checked and left unchanged.** The theater already has its marquee, red carpet and searchlights, and the Fun Park its coaster, Ferris wheel and drop tower. |
| **Night** | Only neon glowed | ~950 windows and bulb strings are tagged. Each player's game switches them to a warm glow after 18:24 and back at 06:18. About a quarter stay dark ("nobody home"), always the same ones. The switching happens on each player's own device, so it adds no network traffic. |
| **Logo** | "💰 CORNER EMPIRE" text | A **gold crown** built from frames (3 points with gems, a jewelled band; no image asset) over **CORNER EMPIRE**, then "⚡ RAGS TO BILLIONS ⚡", then **"BUILD • RUN • EXPLORE • RISE"**. It's on the main menu and the opening movie's title card. On a short landscape phone the menu hides the crown so the save cards keep their room. |

**Not added:** a fountain plaza in Downtown. The city center has no free land left (every 30×30 area inside the ring is a road, plot or reserved path). Midtown Green and the Suburbs green have the fountains instead.

### Preview pictures
`docs/v19_previews/` contains part previews of each district: Downtown, Restaurant Row (day, and night with the windows on), the Entertainment District at night, Suburbs, Expansion, the Heights Mall, the beach and Industrial. As noted at the top, they show layout only.

## 2. Files changed

**New**
- `src/ServerScriptService/GameServer/Architecture.lua`: the building kit.
  - One table, `C.ARCH_STYLES`, holds 7 styles: restaurant, neon, shop, glass, construction, shed and beach.
  - Each style sets the walls, materials, roof, storefront, awnings, neon trim and extras (seating, menu boards, scaffolding, docks, umbrellas).
  - It also builds the streets (`C.archStreet`) and parks (`C.archPark`).
  - Everything is config-driven, so a new district style is one table entry.
- `tests/world_test.lua`: the new test suite (section 3).
- `tests/isodump.lua` and `tools/iso.py`: the preview tool. They aren't part of the game.
- `docs/V19_WORLD_PLAN.md`, `docs/V19_REPORT.md` and `docs/v19_previews/`.

**Edited**
- `GameServer/World.lua`: the Downtown skyscrapers (`C.skyscraper`), the Heights Mall, the beach boardwalk and lighthouse, and the Industrial detail.
- `GameServer/RealEstate.lua`:
  - vacant buildings on unsold plots (`C.VACANT_STYLE`, `C.VACANT_SIZE`);
  - Restaurant Row, the Entertainment, Suburbs and Expansion streets and buildings (`C.dressGrid`);
  - the Midtown gate name.
- `GameServer/Config.lua`: version 19.0.0 "The City Rises", plus two update notes.
- `GameServer.server.lua` and `tools/order.json`: `Architecture` added to the module order, after Util.
- `EmpireClient/WorldFX.lua`: the night-window switch.
- `EmpireClient/UI.lua`: `C.crownLogo`.
- `EmpireClient/MainMenu.lua` and `EmpireClient/IntroCinematic.lua`: the logo.
- `tests/data_test.lua`: the version check.

**Not changed:** saves and DataMigration, the economy, purchases, heists, races, the theater, the park builder, the mountain, and every server-side check.

## 3. Tests (simulated)

### New: `world_test` (31 checks)
- **Districts:** each of Midtown, Entertainment, Suburbs and Expansion has its city buildings, and all 96 unsold plots in styled districts have a vacant building.
- **Downtown:** the towers have lit window bands.
- **Signs:** the gate reads RESTAURANT ROW, and all 16 restaurant names and all 10 Entertainment names are up.
- **Unsold plots:** all 100 have a View Property prompt at the front corner, within reach from the sidewalk in front of the plot, with no part of the building in the way.
- **Buying:** buying a plot clears its vacant building and FOR SALE sign, and the chosen business is built there.
- **Night windows** (944 tagged):
  - at 22:00, 720 are lit and the rest stay dark;
  - every bulb string is on;
  - at noon, all of them are dark again, with their daytime color and material back.
- **Mall:** it stands, and both counters have prompts. Triggering them opens the Bazaar and the Furniture Store, and the mall is a map destination.
- **Beach and Industrial:** the boardwalk (50 plank sections), the lighthouse with its beam, and the pipe racks.
- **Logo:** the menu has the frame-built crown and "BUILD • RUN • EXPLORE • RISE", and the whole logo block stays above the save cards at 4 screen sizes (two portrait phones, a landscape phone, desktop).
- **Part budget:** see below.

### Part budget (one player, fresh game, simulated)
| | Visible parts |
|---|---|
| v18 | **18,747** |
| v19 | **21,743** (+2,996, +16%) |
| Budget | 25,000 |

Window bands are capped at 8 per tower tier, and the tall era towers have a band cap, so a billionaire's skyline doesn't add thousands of parts.

**A real phone's frame rate can't be measured here.** Please check it (Studio checklist, step 5).

### Existing suites that also guard the world
- `layout_test`: nothing solid on any road lane or reserved path, including the new streets, mall, boardwalk and docks.
- `terrain_test`: nothing buried in hills; the mall land is cleared.
- `estate_test`: every plot has its FOR SALE sign, and the buy flow works.
- `mobile_test`: on a 390×700 phone, the menu's subtitle and save slots still fit with the logo above them.
- `intro_test`: on the same phone, the title card (with the crown) fits, and START and SKIP stay big enough to tap.

### Full regression
**54 suites, 2,248 checks, 0 failed** (simulated, full parallel run). How that count was reached:
- The full run started before the last change: a fix to the menu layout on landscape phones, plus 4 new layout checks in `world_test`. In that run `world_test` had 27 checks.
- After the change, `world_test` (31 of 31), `mobile_test` (201 of 201), `intro_test` (32 of 32) and `data_test` (26 of 26) were re-run on their own and passed.
- With the 4 new checks, the suite total is now **2,252**.

**The landscape-phone fix:** the new layout check found that on a landscape phone (844×390), the menu's name and subtitle reached down into the save cards. The v18 menu already did this. On short screens the name and promise now move up and shrink, and the crown and motto are left out. The check now passes at 390×700, 430×932, 844×390 and 1280×720.

### Static and build checks
- `tools/check.sh` reports two lint notes, both known false positives in unchanged code:
  - `WorldFX.lua(59,4)`;
  - `Bazaar.lua(108,15)`, a loop that starts at 0 on purpose: it counts a distance, not an array index.
- `tools/propcheck.py`: 0 problems.
- `CornerEmpire_v19.rbxlx` (Lighting → Technology = Future) and both drop-ins in `updates/` are built.
- The round trip (extract the place, then diff against `src`) is identical.

### Bugs caught while building v19
- The mall used a helper before it was defined, which stopped the World script from loading. `smoke_test` caught it.
- The Suburbs' small shops came out as towers. Fixed with a height cap per style and a cap on gable roofs.
- The Expansion district looked repetitive. Fixed with gray roofs, and cranes only on some buildings.
- The Entertainment District's buildings all had bright magenta roofs, which looked loud from above. They're dark now, with the neon kept on the trim.

---

## 4. Install
1. Back up first. Your current place is fine as is, and `CornerEmpire_v18.rbxlx` stays in the repo.
2. Then **either**:
   - replace **GameServer** (ServerScriptService) and **EmpireClient** (StarterPlayerScripts) with the drop-ins in `updates/`. Both are needed: there's a new server module (Architecture) and client changes (night windows, logo).
   - **or** open `CornerEmpire_v19.rbxlx`. It already has Lighting → Technology = Future.
3. If you use the drop-ins in your own place, set **Lighting → Technology → Future** by hand. Without it, the lit windows still glow but cast less light.
4. Keep **Server Size = 12** (from v18).

## 5. Rollback
Nothing in the save data changed, so a rollback is safe at any time and loses no player progress.
- **Option A:** reinstall the v18 drop-ins (`git show 18a460c:updates/GameServer.rbxmx > GameServer.rbxmx`, and the same for `EmpireClient.rbxmx`).
- **Option B:** open `CornerEmpire_v18.rbxlx`.

## 6. Studio checklist (please check before publishing)
1. **Lighting:** Lighting → Technology is **Future**. Play at noon, at sunset (about 18:00) and at night (set `ClockTime` to 22 in the Lighting properties while playing). Windows should glow warm after dusk, a quarter of them dark, and Restaurant Row's bulb strings should be on.
2. **Unsold plots:** walk up to a few in each district. The vacant building should look right, and the **View Property** prompt should appear at the sign on the front corner. Buy one: the vacant building should disappear and your business should be built.
3. **Heights Mall:** drive to the end of Heights Blvd. Check that the parked cars aren't clipping, then use both counters (Bazaar and Furniture).
4. **Beach:** walk the boardwalk end to end (no invisible walls, no snagging on lamps or benches), and go to the end of the pier at night to see the lighthouse beam turning.
5. **Phone frame rate:** test on a real phone, or the Studio device emulator plus the MicroProfiler, in Downtown and on Restaurant Row at night. If it's low, try reducing window bands first (`C.skyscraper` band cap), or test StreamingEnabled as a separate step.
6. **Logo:** the main menu and the opening movie's title card on a phone (portrait and landscape). The crown should sit above CORNER EMPIRE without overlapping the save cards.
7. **Driving:** drive through the new streets in Midtown, Entertainment, Suburbs and Expansion. They're decoration, not part of the traffic network, so check that nothing blocks the way to the plots.

## 7. Performance checklist
- Visible parts (simulated): 18,747 → 21,743. The budget is 25,000.
- No new per-frame work on the server. The night switch runs on each player's own device, once at dusk and once at dawn (an event on ClockTime, not a loop).
- The lighthouse beam is a single looped tween.
- The street lights are only the existing lamps plus one PointLight per boardwalk lamp. The bulb strings glow (Neon) without casting light, so there are no extra light sources.
- The new buildings are anchored, with no scripts and no physics.
- Still recommended, not done: try **StreamingEnabled** in Studio as a separate test (see the v18 report for why it isn't on by default).
