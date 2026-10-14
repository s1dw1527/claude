# Corner Empire v16 — Life & Empire: Rise to Riches

**What this is.** You asked for v16 to make players want to come back every day. It adds:
- a cinematic opening;
- three ways to build an empire;
- daily rewards, missions and weekly challenges;
- rotating city events;
- reasons to play with friends;
- an Empire Roadmap;
- meaningful surprise moments;
- a starting-attitude choice.

All of it is built on the existing systems rather than beside them. The in-game name is "Life & Empire: Rise to Riches".

**Data:**
- Same DataStore, **`CornerEmpire_v5`**. The save schema goes **15 → 16**, additive only (section 3).
- New per-account records live in the account's existing meta key (no new DataStore).
- Nothing was published. **Install both** `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx`.

> **Testing honesty.** Every result here comes from this repository's **simulated** Roblox engine
> (`tests/harness.lua`). It runs the real game scripts, but it does not render and has no real physics, touch
> input, networking or DataStores (they live in memory). **Nothing in v16 has been run in Roblox Studio or on a
> phone.** The cinematic in particular has only been checked for its logic, timing and cleanup, not its look.
> Section 6 is the Studio checklist: please run it before publishing.

## 1. What's new

### The opening: "Get rich or go broke" (`EmpireClient > IntroCinematic`)
A ~20-second scripted camera over the **real** city, with a handful of small temporary props.

| scene | time | what you see | on screen |
|---|---|---|---|
| 1. The struggle | 0–4 s | a rainy night over the skyline, down to a street corner: an empty wallet, a FOR RENT shop | "EVERY EMPIRE STARTS WITH NOTHING." |
| 2. The choice | 4–9.5 s | a lemonade stand and a paying customer; a car pulling up; a fictional briefcase swap in an alley with police lights flashing far away | "BUILD IT LEGIT." · "TAKE BIG RISKS." · "OR RULE BOTH SIDES." |
| 3. The rise | 9.5–15.5 s | the Big Dipper, the Funland Grounds, the mountain, the Empire Spire; animated cash, reputation and empire-value counters climb | "YOUR CITY. YOUR EMPIRE. YOUR RULES." |
| 4. The title | 15.5 s → | a gold / black / navy card that fits a phone | "CORNER EMPIRE — Build Your Fortune. Risk Everything. Leave a Legacy." with **START MY EMPIRE** and **SKIP INTRO** |

- **When it plays:** once per account, before the save slots. The `introSeen` flag is in the account record.
- **Returning players** get a small **Welcome back** card instead: **▶ Continue Empire** (the last save played) and **🎬 Replay intro**.
- **Accounts that already had saves before v16** are never shown it automatically. Anyone can replay it from **Settings → Opening movie**.
- **Skipping:** **SKIP** is on screen from the first frame. Esc and the gamepad's B or Start also skip.
- **"Cinematics: Off"** in Settings goes straight to the title card.
- **One copy only:** a second request while it plays is ignored.
- **Cleanup:** whatever ends it runs **one** cleanup. That covers finishing, skipping, an error in a scene, a respawn, or starting a game. The cleanup:
  - restores the camera, field of view, HUD and character controls;
  - removes every temporary part, the rain, the night grade, the overlay and every connection.
- **Sound:** only the game's own sound effects and jingles. No music asset IDs were invented.
- **Fiction:** the crime scene is a fictional story beat with no real-world instructions.

### Three ways to build an empire (`GameServer > Paths`)
All three use the same economy. There is no new currency and nothing is locked for good.

| path | what earns XP |
|---|---|
| 💼 **Business Mogul** | serving customers, Rush Orders, upgrades, theater shows, building your park |
| 🕶️ **Underworld Operator** | heists that make it back to the mountain base (the existing heist system) |
| 👑 **Empire Legend** | progress on **both** sides on the same day, and mixed contracts |

- Each path has 8 levels with titles (e.g. Shopkeeper → Business Legend, Lookout → Underworld Legend). Each level gives a little reputation.
- **Contracts** are one at a time per path, bigger than a daily mission, and pay more:
  - The Underworld board opens once the mountain base is found.
  - Day 6 of the login strip adds a bonus contract.

### Coming back every day (`GameServer > Daily`, phone app 🎁 **Daily**)
- **Login rewards:** a 7-day cycle on **UTC calendar days**, one claim per day.

  | day | reward |
  |---|---|
  | 1 | cash |
  | 2 | 🏷️ 25% off your next upgrade |
  | 3 | 🎨 a free car makeover |
  | 4 | 🎓 staff training |
  | 5 | 🏺 a Golden Statue decoration |
  | 6 | 📜 a bonus contract |
  | 7 | 👑 the Week Champion title + a big cash bonus |

  - Cash scales with income, with a floor.
  - **Forgiving streak** (your choice): missing one day is covered by the 🛡️ shield, which recharges every UTC week. More missed days step the cycle back by the days missed, never below day 1.
  - A countdown shows the time to the next UTC midnight. There are no fake timers and no purchase prompts.
- **Daily missions:** 3 a day, picked per account and per day. Only missions your reputation tier can actually do are picked, so new players get starter ones. Examples:
  - serve customers, Rush Orders, upgrades, earn from your businesses;
  - City Jobs, Golden Corners, drive, ride, visit another player's park;
  - races, theater shows, parties, gifts;
  - heists, only once the base is found.
- **Weekly challenge:** one bigger goal per UTC week (Monday to Sunday). The reward is cash, reputation and a badge.
- **Progress comes only from real server events** (the game's event bus, `F.track`). Missions can't be completed by opening menus, and the client can't move them. Driving distance is sampled by the server, only while you sit in your own car, and teleports don't count.
- A small **🎁 card** in the notification stack appears once per session when something is waiting. It is never full-screen.

### Live city events (`GameServer > LiveEvents`)
- One city event at a time, on fixed **4-hour UTC windows**, worked out from the clock alone. Every server runs the same event at the same time.
- **Weekdays** rotate:

  | event | boost |
  |---|---|
  | 🍽️ Restaurant Rush | customers +25% |
  | 🎡 Funland Night | twice the park visitors, tickets ×1.5 |
  | 🥊 Rival Takeover | rival prizes ×2 |
  | 📦 Double Delivery Day | City Jobs ×2 |
  | 🚨 Underworld Alert | heists +30%, optional |
  | 🏎️ Luxury Showcase | customize your car |

- **Saturdays and Sundays (UTC)** are 🤝 **Community Weekend** (visitor rewards ×2).
- Each event has an optional goal. Its reward is claimed **once per window per account**.
- Events only ever add: nothing is taken away when one ends.
- A board in the plaza shows the current event.
- Players hear about a new event once, and **not** while riding, mid-heist, running Rush Orders or in a cutscene.
- Definitions are data (`C.LIVE_EVENTS`).

### Playing together (`GameServer > Showcase`)
- **Park visits:**
  - Your first real ride at each other player's park each day pays you a small reward (3 parks a day at most).
  - The host gets a "friend dropped by" bonus once per visitor per day, on top of their capped ride tickets.
  - The 🎢 Park app now lists every park in the server, with rating, visitor count, the star ride, **Visit** and 🪪. It is visible even before you own a park.
- **Co-op:** partners who pay for each other's upgrades both get a co-op bonus, once per pair per day.
- **🪪 Showcase card:**
  - Shows empire stage, business count, a **net-worth tier** (never exact cash), park rating, prestige stars, path levels, and the title and badge you choose to wear.
  - Nothing private is included.
  - You can only wear titles and badges you have earned.

### Empire Roadmap (`GameServer > Roadmap`, phone app 🗺️ **Roadmap**)

| stage | what it needs |
|---|---|
| 🛒 Street Starter | — |
| 🏪 Local Owner | LOCAL FAVORITE reputation |
| 🏗️ Business Builder | + 4 businesses |
| 🏙️ City Player | HOTSPOT reputation |
| 🏢 Property Mogul | + 2 city plots |
| 🌆 City Icon | CITY ICON reputation |
| 👑 Empire Legend | EMPIRE reputation + a $1B empire value |

- Requirements and "opens" lists come from the game's own tables (`C.REP_TIERS` and the rules), so the map can't contradict the game.
- Each stage shows progress bars and the next reward.
- Reaching a stage is celebrated **once**, with confetti and a small gift.
- A save that was already past some stages is placed on the map **without** replaying or paying them.
- The app also shows your paths, your contracts (Collect), **🪪 My showcase** and **Change starting attitude**.

### Starting attitude
After the tutorial in a new game, a card asks how you'll start. It waits until no window is open.

| choice | first suggested step |
|---|---|
| 💼 **Play It Smart** | a Rush Order |
| 🎲 **Take a Risk** | a City Job, with a hint about the mountain |
| 🧭 **Explore the City** | Golden Corners (opens Explore) |

- It only reorders the first suggested step (the existing Next Step card). It pays nothing and locks nothing.
- It can be changed any time from the Roadmap. It never pops up again by itself.

### Notifications and surprise moments
- **Priorities** (`C.notify(plr, msg, {pri, cat, key})`):
  - **Critical** messages (purchases, claims, arrests, save problems, mission results) are never dropped. They jump the queue.
  - **Low**-priority repeats are grouped (×3).
  - Still at most 3 waiting, and everything is in the 🔔 Activity log.
- **Settings:**
  - **Pop-up alerts: All / Important only.** Warnings and critical messages still pop up; the rest go to the log.
  - **🔉 Effects volume.**
- **Moments with a reason:** a 🚌 tour bus at a well-rated park really adds visitors and makes it busier for 2 minutes. The existing moments (influencer visits, reviews, rival challenges, staff learning milestones, Golden Corners) are unchanged, and the event board now announces events.

## 2. Install (existing place, keeps all player data)

1. Studio → **File → Save to File As…** → make a backup (e.g. `CornerEmpire_before_v16.rbxlx`).
2. **Write down** your pass IDs (`GameServer → Config → C.PASSES`) and your `owners = {…}` (`GameServer → Admin`).
3. **ServerScriptService** → delete `GameServer` → right-click → **Insert from File…** → `updates/GameServer.rbxmx`.
4. **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click → **Insert from File…** → `updates/EmpireClient.rbxmx`.
5. Put back your pass IDs and `owners = {YOUR_USERID}`.
6. Do **not** change `DATASTORE = "CornerEmpire_v5"`.
7. Keep `Lighting.Technology` as you set it for v15 (ShadowMap or Future).
8. Game Settings → Security → **Enable Studio Access to API Services** to test saving (Studio uses the separate `_StudioTest` stores).
9. Run the Studio checklist (section 6), then publish yourself.

For a new place instead, open `CornerEmpire_v16.rbxlx`, set the pass IDs and owner, test, then publish.

**Rollback:** reopen the backup. v16 saves still load in v15:
- The new slot fields (`path`, `roadmap`, `grantsGot`, `tokens`) and the meta key's `acct` record are kept untouched as unknown fields.
- Rewards that were claimed but not yet paid wait in the account record and are paid when v16 is back.

## 3. Data migration notes

**Slot saves, step 15 → 16** (`DataMigration.steps[15]`, `M.v16Defaults()`) adds these fields only if missing:

| field | default | what it holds |
|---|---|---|
| `path` | `{xp = {mogul = 0, under = 0, legend = 0}, contracts = {}, done = 0}` | path XP, current contracts, contracts done, starting attitude |
| `roadmap` | `{stage = 0}` | the last Roadmap stage celebrated |
| `grantsGot` | `{}` | account rewards already paid into this slot (the 40 newest ids) |
| `tokens` | `{upgrade = 0, carmod = 0}` | the 🏷️ / 🎨 reward tokens |

- Every other field, including unknown future fields, is kept. This is tested with a full v15 save (park, theater, staff, prestige, ledger, an unknown field).
- A damaged v16 record is repaired field by field and the rest of the save loads (tested).
- If the step crashes, the migration is refused and the stored v15 save stays untouched (tested).

**The account record.** Daily, missions, weekly, wardrobe and pending rewards belong to the account (your choice). They live in the account's **existing** meta key, `u<userId>_meta`, as a new field `acct`, next to `slots` and `settings`.

| field | holds |
|---|---|
| `introSeen` | whether the opening has played |
| `daily` | `claimed` (UTC day), `cycle`, `streak`, `best`, `shield`, `shieldWeek` |
| `missions` | `day`, `picks`, `p`, `done`, `t` |
| `weekly` | `week`, `key`, `p`, `claimed`, `t` |
| `wardrobe` | `titles`, `badges`, the worn title and badge |
| `grants` | pending payouts |
| `seq` | the grant counter |
| `events` | live-event windows already rewarded (about a week kept) |
| `coop` | today's visit and co-op keys |

- The meta key has no schema version. `M.repairAcct` repairs every field on its own each time it's read: a bad field goes back to its default, and anything else stored there is kept.
- `M.mergeAcct` combines what's stored with what this server holds. A claim made anywhere is never un-claimed, progress never goes backwards, and paid grants are dropped. Both functions have self-tests.
- Only small, bounded records are kept: no login history or notification history.

**No duplicate or lost rewards: write-ahead grants** (the same idea as the v14 Ledger).
1. Every account reward (login, mission, weekly, live event, visit, co-op) is decided **inside** the meta key's `UpdateAsync`, against what's actually stored. Two clicks, two claims at once, or a retry can't both win.
2. The decision records a **grant** for the slot being played.
3. Only after that write succeeds is the grant paid into the slot. The slot notes the grant id in `grantsGot`, then saves.
4. The grant leaves the account record only after a slot save that contains it has succeeded.
5. If the server dies between steps 1 and 3, the grant is paid the next time that slot loads, exactly once (tested).

Also:
- A session whose save didn't load can't claim anything.
- Path XP, contracts and the Roadmap stage live in the slot itself, so they are saved together with the cash they pay.

## 4. Tests — SIMULATED (not Roblox Studio)

**Final run: TBD**

| suite | checks |
|---|---|
| `daily_test` (new) | one claim per UTC day; double, concurrent and forged claims; a crash between the claim and the payment → paid once on the next load, never twice; slot switching (shared streak, can't claim twice, pays the right slot); shield; step back (never below day 1); the 7-day wrap; missions only from real events (client fakes do nothing, stop at the goal, no farming); starter missions for a brand-new account; weekly progress stored with the account and surviving a reconnect, badge, once; no claims when the save didn't load; the 🏷️ token taking 25% off |
| `roadmap_test` (new) | stage requirements = the game's tier reputation and unlock lists; stages in order; placed on the map without replay; celebrated once with a gift and a title; the Roadmap app (7 stages, next stage, paths); path XP only from real events, level titles; contracts (Underworld board opens with the base, no early or forged collection, collected through the app, a new one appears, mixed contracts need both sides, Legend XP once a day); starting attitude (reorders the Next Step, pays nothing, unknown choice ignored, changed from the Roadmap); the 🎁 Daily app through the real client (card, strip, Claim, missions, weekly) |
| `events_test` (new) | same event for the same time; window boundaries; weekends; all events in a week; boosts only during their window (customers ×1.25, jobs ×2, heists ×1.3); goal only from real events, client fakes ignored, claimed once per window, fresh in the next; nothing taken back; plaza board; no announcement while riding, announced once afterwards; the tour bus really adds visitors |
| `social_test` (new) | no visitor reward without a real ride or from the client; visitor + host rewards once per day; the 3-parks cap; co-op once per pair per day; the showcase only contains public, derived fields; can't wear unowned titles; wearing through the card; the park list (visitors, star ride, Visit, 🪪) for players without a park |
| `intro_test` (new) | first-ever account: plays before the slots, SKIP from frame 1, scenes 1–4 in order, START → no leftovers, introSeen saved; returning account: Welcome back (Continue / Replay); pre-v16 account never forced; replay; second request ignored; skip on the first frame restores the field of view; gamepad B skips; an error mid-scene, starting a game mid-intro, and a respawn during a replay all clean up (HUD, controls, InCinematic flag); Settings replay row; the title card, START and SKIP fit and are tappable at 390×700 |
| `data_test` + self-tests (+) | schema 16, v15 → v16, broken v16, crashing step 15, account repair + merge |
| `park_test`, `leaders_test`, `mobile_test`, `lifecycle_test`, … (+) | every earlier suite still passes with v16 (see the run above) |

## 5. Known limitations

- **Live-event goal progress** is kept for the session (a 4-hour window). Rejoining in the same window restarts the goal's counter; the reward itself can still only be claimed once per window.
- **The intro's look** (lighting, rain density, cuts) and its feel on a phone can only be judged in Studio and on a device. The props are deliberately simple client parts.
- **Park visitors and coaster trains** are drawn by each client (as in v15).
- **Daily rewards with saving unavailable** (Studio without API access): claims work for that session only and aren't kept.
- **The start-choice card** appears after the tutorial, not straight after the intro, so it doesn't fight the tutorial's first steps.

## 6. Needs real Roblox Studio / phone testing

1. **Intro:**
   - On a fresh account, does it look right: night, rain, cuts, text readable, counters, the title card?
   - Skip with the button (touch and mouse), Esc and a gamepad.
   - After it: the menu camera and slots, then a new game with normal camera and controls.
   - Replay it from Settings in a game, then reset your character mid-intro: is everything back?
2. **Returning account:** no intro; Welcome back → Continue Empire loads the right slot.
3. **Daily:**
   - Claim day 1, rejoin: still claimed, countdown right.
   - Switch slots: still claimed.
   - With API access on, check the meta key in the `_StudioTest` store has `acct`.
4. **Missions:** do one of each kind you get; check they move only from real play.
5. **Live event:** the board text in the plaza; the announcement timing; a goal claim.
6. **Park visits** with two players (Studio's 2-player local test): visitor + host rewards once per day.
7. **Roadmap:** stage celebration once; contract Collect; showcase card; wear a title.
8. **Phone:** the 🎁 Daily app, 🗺️ Roadmap, 🪪 Showcase, the start-choice card and the intro title card at a phone size; the 🎁 card in the stack.
9. **Save migration:** load a real v15 save (test store) and confirm the park, theater, staff, partners and prestige are all intact.
10. **Settings:** "Pop-up alerts: important only" and the effects volume.

## 7. Configuration (all in code, all server-checked)

| table | where | what it sets |
|---|---|---|
| `C.DAILY_REWARDS`, `C.MISSION_POOL`, `C.WEEKLY_POOL`, `C.DAILY` | GameServer > Daily | rewards, missions, the weekly challenge, mission pay |
| `C.PATHS_DEF`, `C.PATH_XP`, `C.PATH_GAIN`, `C.CONTRACTS`, `C.PATH_CFG`, `C.START_CHOICES` | GameServer > Paths | paths, levels, XP, contracts, starting choices |
| `C.LIVE_EVENTS`, `C.LIVE_WINDOW`, `C.MOMENTS` | GameServer > LiveEvents | events, window length, moments |
| `C.ROADMAP`, `C.ROADMAP_REWARD` | GameServer > Roadmap | stages and their gift |
| `C.SOCIAL` | GameServer > Showcase | visit, host and co-op rewards and caps |
| `SHOTS` | EmpireClient > IntroCinematic | the camera path, text and timing of each shot |
