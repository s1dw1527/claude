# Corner Empire v8 — "The Empire Expansion" — Reports

Place file: `CornerEmpire_v8.rbxlx` (built from `src/`, same place, same DataStore).
Drop-in updates: `updates/GameServer.rbxmx`, `updates/EmpireClient.rbxmx`. Rojo: `default.project.json`.

**How things were tested.** Everything below ran in the repository's simulated Roblox engine (`tests/harness.lua`).
It runs the real server and client scripts, DataStores are in memory, and time is simulated. As of v8 it is
**strict**: reading or writing a member that doesn't exist on a Roblox class is an error, the same as in real Roblox
(the member list is generated from the official API type definitions). The engine has **no physics, rendering,
touch input or gamepad hardware**. Anything that depends on those is marked **⚠️ Needs Studio testing**. Nothing
in this report has been run inside the real Roblox Studio.

---

## 1. BUG REPORT

| # | Bug | Root cause | Fix | Test result |
|---|-----|-----------|-----|-------------|
| 1 | Upgrade tabs too big | The upgrade list was one wide card per business, at a fixed size, that covered the screen on small devices. | The panel is now a row of compact business chips plus one management card for the selected business. A `UIScale` fits it to the viewport. | ✅ Sim: one chip per business; buy/upgrade from the card; scales below 1.0 on a 667×375 screen (`business_test`). ⚠️ Needs Studio testing: real look on phone, tablet and PC, and controller navigation (gamepad selection between chips). |
| 2 | Map broken | **Root cause of bugs 2, 3, 6 and 11:** since v5, `Phone.lua` stored a function on a Frame (`v.refresh = render`). Real Roblox rejects custom fields on Instances, so the error stopped the Phone module before Messages, the Map and the CityBuzz listener were built. The Story module failed the same way. Reproduced by running the committed v7 client in the strict engine. | Refresh functions now live in a Lua table. A new `MapApp` draws districts, roads, your businesses, home, properties, other empires, city places (🔒 locked / unlocked, with what unlocks them), story objectives and events, and you as an arrow. Tapping a place shows info, **📍 Mark** (guide beam) and **🚀 Go**. | ✅ Sim (`phone_test`): markers, locked text, info card, Mark/Unmark, Go teleports. ⚠️ Needs Studio testing: visual layout and scale on different screens. |
| 3 | Messages broken | Same root cause as #2. There was also no unread state, and generated messages could arrive back to back. | New inbox with real senders (staff, customers, tenants, rivals, story, City Hall, events, investors), timestamps, an unread badge counted by the server, open = mark read, ✓ All read, pacing (one non-important message every 200 s or more), and important mail saved with the slot. Each player's inbox is sent only to that player. | ✅ Sim: badge = server count; open marks read; 1–4 messages in 10 minutes; important mail survives rejoin; Bob's message never sent to Alice. |
| 4 | House ratings invisible | Ratings were stored but never shown anywhere. | A sign over every house shows the average ★, the 🛋️ interior score, rating count, visits and likes. Also shown in the Home info panel and the tour list. Visits count once per visitor per day. Server validates stars 1–5 and the visit. You can't rate your own house. One rating per house per week. Rate limit: one like and one rating per 5 s across houses. | ✅ Sim (`interior_test`, `features_test`): sign text, visit counting, self-rating refused, junk ratings refused, rate limit, like + rate on the same house allowed. |
| 5 | Business selector too large | Same as #1. | Compact, scrollable chip row and a management card: level, income, expenses, employees, served customers, rating, reviews, current problem with repair, improvements, reputation and location. The selection is remembered for the session. | ✅ Sim (`business_test`). ⚠️ Needs Studio testing: touch scrolling. |
| 6 | Story app broken | Same root cause as #2. Separately, two cutscene runners could race on the client queue. | The Story app shows the current chapter and objective progress, rewards collected, every chapter (✅ Complete / ▶ In progress / 🔒 Locked) with Intro/Ending replay, and characters with their relationship to you. Replays never pay, advance or duplicate. A "NEW STORY EVENT" pill opens the app. A `pumping` flag fixes the queue race. | ✅ Sim (`phone_test`, `story_test`): replays pay nothing and change no progress; can't replay unfinished endings; the pill opens the app. |
| 7 | Car steering | The upright stabilizer `AlignOrientation` held all three axes, so it fought yaw on every turn. `Driving.lua` also re-set its target CFrame every frame. | It now only aligns the car's up axis (`AlignType.PrimaryAxisParallel`, attachment X axis pointing up), so yaw and turning are free. The per-frame CFrame update was removed. Input still uses the VehicleSeat, which reads keyboard, gamepad and mobile thumbstick. | ✅ Logic/API checked (property names validated, tutorial and race tests drive cars). **⚠️ Needs Studio testing: this is physics.** Check left/right, U-turns, reverse, braking, drift, racing, deliveries, controller, mobile and the camera. |
| 8 | Reviews never change | Reviews were static text. | A bad review names a reason tied to one of 5 improvements (Quality, Speed, Cleanliness, Service, Atmosphere). Buying that improvement doesn't change it. The customer has to come back; on a later visit they may add an **update** ("Much faster this time!", ★★ → ★★★★). The original text is never edited. Improvements raise satisfaction only (max +20), never income. | ✅ Sim (`business_test`): upgrading alone changes nothing; a revisit adds an update; text unchanged; income unchanged; Bob can't improve Alice's business. |
| 9 | No interiors | — | Every business and home has an interior (counter, fixtures and spots per type). It's built on entry and removed 60 s after it's empty. Enter through the door prompt or the Home panel's 🛋️ Inside. | ✅ Sim (`interior_test`). ⚠️ Needs Studio testing: how the rooms look, lighting, the camera inside, and the door prompts on mobile and controller. |
| 10 | No customization | — | Walls, floors, lighting, furniture, decor and business-specific items, with unlocks. Only the owner can decorate, while inside, and every choice is validated by the server. Removing an item is free with no refund (no money loop). The interior score adds up to +10 satisfaction and the house ★ shown, never income. | ✅ Sim: visitors can't change anything; income unchanged after decorating; saved and restored. |
| 11 | "Post to story" broken | Same root cause as #2 (the feed listener was never built). | The CityBuzz composer has text (length limit, validation), attach chips (Business, House, Car, Empire, Photo — cards built by the server from real data), Latest/Trending, likes, views, reactions (one per kind per player, none on your own post), timestamps and a cooldown. Photo Mode has **📤 Post to CityBuzz**. In-game only; it never posts to real social media. | ✅ Sim (`phone_test`). |

**Also fixed while testing:** a store-name bug in test helpers, a home-visit double count, a Messages badge off by
one after reload, and the server calling a client-only star helper. Details are in the commit history.

---

## 2. DATA MIGRATION REPORT

- **DataStore:** `CornerEmpire_v5`, **unchanged**. Keys are unchanged: `u<UserId>_s<slot>`, `u<UserId>_meta`.
  No data was wiped, renamed or reset.
- **Schema:** `C.VERSION.SCHEMA_VERSION = 8`, `MIN_SUPPORTED_SCHEMA = 6`.
- **Detecting the version:** the `SchemaVersion` field. Older saves have none: a save with story data is v7,
  otherwise v6.
- **Steps (on a copy, one at a time, then validated):**
  - **6 → 7:** backfill `tutPaid` (tutorial rewards already paid) so old players aren't paid twice.
  - **7 → 8:** add `mail` (empty), `interiors` (empty), `improve` (empty), `reviewBook` (empty), `homeVisits = 0`.
- **New fields written by v8:** `SchemaVersion`, `gameVersion`, `savedAt`, `saveSeq` (save counter), `mail`,
  `msgSeq`, `interiors`, `improve`, `reviewBook`, `reviewSeq`, `homeVisits`, `homeRatings`.
- **Validation:** hard problems (wrong types for core fields) fail the migration. Soft problems are repaired: negative
  money becomes 0, levels are capped, `tutPaid` is filled in.
- **Failure safety:**
  - A failed **load** or failed **migration** puts the session in no-save mode with a warning. The stored save is untouched.
  - A save from a **newer** schema loads read-only.
  - `UpdateAsync` and `saveSeq` stop an older server or a stale session from overwriting newer progress.
  - Unknown fields are carried through unchanged.
- **Tested (sim):** fresh, v6, v7 and v8 saves through the real join flow; leaving and rejoining; server switch
  conflict; newer schema; corrupt save; failed load; failed migration; new game over a slot; deleting a slot. Result:
  26/26 checks, plus the 17-check in-game self-test.
- **⚠️ Needs Studio/live testing:** real `UpdateAsync` timing and throttling on live servers. Test with **Studio
  playtests only**: they use `_StudioTest` stores, never the live ones.

---

## 3. UPDATE GUIDE

The full guide is in `README.md`, section **"HOW TO UPDATE CORNER EMPIRE WITHOUT LOSING PLAYER DATA"**. Short version:

1. Back up the current place (File → Save to File As…).
2. Swap in the two scripts: Insert from File with `updates/GameServer.rbxmx` + `updates/EmpireClient.rbxmx`, or
   use Rojo. Copy your pass IDs back into `GameServer > Config`.
3. In a Studio playtest, run Settings → **🧪 Update + data safety test** and check the Output says 0 failed. Studio
   uses `_StudioTest` stores and never touches live saves.
4. **File → Publish to Roblox** onto the **same place**. Never use *Publish As* to a new experience.
5. Restart servers from the Creator Dashboard. Old servers save everyone and show "🆕 NEW UPDATE READY".
6. For a future change to the save shape: raise `SCHEMA_VERSION`, add one `DataMigration.steps[n]`, and add any
   new saved field to `SAVE_KEYS`. Never rename the DataStore.

---

## 4. TEST REPORT

All suites below are simulated (strict API engine). **460 checks passed, 0 failed.**

| Suite | Covers | Result |
|-------|--------|--------|
| `smoke_test` | Server and client boot | 5/5 |
| `critical_test` | Earlier audit fixes (passes, NaN, stocks, load failure…) | 45/45 |
| `features_test` | v6 systems: staff, drift, property, mega events, eras, secrets, Buzz, photo, house tours, weekly, legacy | 156/156 |
| `tutorial_test` | Whole tutorial through the real client | 46/46 |
| `story_test` | Chapters, rewards paid once, cutscenes, replays, multiplayer, old saves | 70/70 |
| `data_test` | Fresh/v6/v7/v8 saves, migration, rejoin, server switch, newer schema, failed load/migration | 26/26 |
| `phone_test` | Messages, Map, Story app, CityBuzz posts, inbox isolation | 39/39 |
| `business_test` | Business selector, card, phone scaling, improvements, reviews won back, isolation | 24/24 |
| `interior_test` | Interiors, decorating, house signs, visits, ratings, rate limits, isolation, saving | 38/38 |
| `perf_test` | 40 minutes of 4-player play: memory, NPC cap, network, DataStore budget | 11/11 |

**Static checks:**
- `tools/propcheck.py`: 0 unknown property names.
- `tools/check.sh` (luau-lsp type check): only the known false positive at `WorldFX.lua:59`.

**Economy sim:** unchanged from v7. Improvements and decor cost money and add no income. For a casual player: 4
businesses at about 16 min, $1M at about 21 min, all 8 businesses at about 9h24m.

**Multiplayer isolation (sim):** another player can't read your messages, rate your house as you, rate their own
house, improve your business, decorate your interior, change your story, or touch your save.

### ⚠️ Requires testing in real Roblox Studio (not covered by the simulation)
- **Car steering and feel:** left/right, U-turns, reverse, braking, drift, racing and deliveries, on keyboard,
  controller and mobile thumbstick, plus the driving camera.
- **UI on real devices:** chip and card scaling on phone, tablet, PC and console; touch scrolling; controller
  selection in the business panel, the phone apps and the decorate panel.
- **Visuals:** the map layout, how the interior rooms look and are lit, the camera inside them, and the house rating
  signs at a distance.
- **Live-only services:** the MessagingService update notice between servers (it is skipped in Studio), and
  `UpdateAsync` on real servers. Test the first with two published servers, not in Studio.
