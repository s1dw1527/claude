# Corner Empire v14 — Life & Empire: Main Street (NPC police, design & feel, Phases B–E)

**What this is.** Your request was: replace player police with NPC police, then build Phase B and all other phases,
together with the "Improving Corner Empire's Design and Feel" list (UI clarity, a living environment, music and sound,
and the restaurant / retail experience). All of it is in this one update, **v14** (in-game name "Life & Empire: Main
Street"). It was built in checkpoints, each one pushed with its own test suite.

**Data:** same DataStore **`CornerEmpire_v5`**. Save schema **13 → 14**, additive only (section 3). Nothing was
published. **Install both** `updates/GameServer.rbxmx` and `updates/EmpireClient.rbxmx` (section 2).

> **Testing honesty.** Every result in this report comes from this repository's **simulated** Roblox engine
> (`tests/harness.lua`). It runs the real game scripts, but it does not render, has no real physics, no real touch
> input, no real Roblox text filter, no real networking, no real sound playback and no real DataStores (they live in
> memory). **Nothing in v14 has been run in Roblox Studio or on a phone.** Section 6 is the Studio and device checklist.

## 1. What's in v14

### NPC police (replaces player police)
- Police are now the city's own officers (`GameServer → Police`). Units patrol, respond to alarms, search and pursue
  robbers, then arrest them. They use the real road network (Dijkstra routes), with states patrol / respond / search /
  pursue / arrest.
- The robber's position is only reported approximately. Units must get close, and you can lose them.
- An arrest takes the loot and a capped fine (at most 2% of cash or 25% of the loot), then jail and a "lie low"
  cooldown. Nothing else you own is touched.
- Client: police cars with sirens, a chase banner, and a police scanner tab in the Heists app.
- Player police duty is switched off and explains why. Saved police stats are kept.

### Design and feel
- **UI clarity**
  - Theme tokens with 2–3 signature colors. A WCAG contrast scan of 852 texts in 34 windows passes 3:1.
  - Every button plays a press sound.
  - Toasts stay 2–4.5 s, are color-coded by category, merge repeats (×N) and queue at most 3.
  - Overflow goes to a new 🔔 Activity log app with an unread badge.
- **Music and sound**
  - The music follows what you're doing: city, night, business, home, police chase, and party (v14 Phase C).
  - When no tracks are configured, a generated music-box score plays. Configured tracks stream; a track that doesn't
    load is skipped.
  - Ambience slots per district and inside buildings.
  - Jingles for sales, upgrades, milestones, coins and failures.
- **Restaurant / retail**
  - 🍳 RUSH ORDERS: cook at your own counter.
    - Recipes for every business, including the theater.
    - Real customer types; the server judges each order.
    - Tips are capped per minute, and a perfect order gives a sales rush.
  - A Cook button inside your business.
  - Sales show the product that was bought.
  - 🎂 Catering City Jobs.
- **Living environment:** the v13 crowds, traffic and lights, plus v14 party music, plaza decorations for special
  occasions, the theater marquee and searchlights, and the Skyline Lofts entrance.

### Phase B
- **🎬 Movie Theater**, the 9th business. It is too big for the home plot, so it opens on a city plot (Properties →
  a plot → 🎬).
  - **Films:** 3 original films are in release at a time. They rotate every 3 h, the same in every server. A film's
    first show at your theater is a premiere (CityBuzz, rep, a bigger crowd). Hype fades show by show.
  - **Shows:** a show runs every 3 minutes while you play. Turnout comes from the film, screen, sound, district and
    time of day (horror sells at night), and it sets the theater's sales: ×0.8 for an empty house up to ×1.6 sold
    out with full concessions.
  - **Upgrades:** seats, screen, sound and concessions, 5 levels each.
  - **Looks:** a lit marquee shows the current film. Inside are rows of seats, the screen, a projection booth, the
    ticket desk and concessions.
  - 🍿 Theater app. One theater per empire; it can move plots.
- **🥊 AI rivals:** Gulp & Co., MegaBite Foods, Pixel Palace Group and Novatek Industries.
  - Market pressure per business changes its sales by ×0.96 to ×1.04. Untouched businesses sit at exactly ×1.00.
  - Rivals never take cash and never act while you're offline.
  - Every few minutes a rival makes a move with a timed challenge: serve 5 perfect Rush Orders, upgrade, or run an ad.
    Winning gives a prize and pushes the rival back.
  - 🥊 Rivals app and a challenge card.
- **👥 Crew:**
  - Candidates show a trait (Night Owl, Early Bird, Charmer, Hustler, Fast Learner, Steady Hands), each with a real
    effect.
  - Shifts: Flex (exactly the old bonus), Day or Night (×1.3 on shift, ×0.7 off).
  - Employees earn free experience stars on the job.
  - New 🎞️ Projectionist slot.
  - Staff hired before v14 keep exactly their old bonus.
- **Plot cap review:** property capacity is +1 from HOTSPOT up (1, 2, **5, 7, 10, 13**). Opening the theater never
  forces you to sell a rental or a location.

### Phase C
- **Secure transfers (the Ledger).** A gift needs three steps: offer, accept, confirm. At confirm the server checks
  everything again (both present, cash, daily limit, nobody mid-transfer). The money then moves through a ledger that
  can't duplicate or lose it:
  - **Sending:** the debit and the pending transfer are saved together first (write-ahead). If that save fails,
    nothing happened.
  - **Delivery:** the transfer goes into the receiver's inbox by id. Writing it twice is harmless, and a failed write
    is retried.
  - **Claiming:** the receiver's credit and the ids it covered are saved before the inbox is emptied.
  - Every transfer is logged on both sides.
- **Co-owned businesses.** Invite players as 🤝 Partner or 🧑‍💼 Manager; they accept, so both sides confirm.
  - Partners and managers can run the 🍳 counter: the tip is theirs and the sales rush is the owner's.
  - Partners can pay for upgrades. The owner's cash is untouched and the contribution is logged.
  - The owner sets revenue shares: up to 25% each, 50% in total. Shares are paid from the owner's cash every
    5 minutes through the ledger, so offline partners get paid too.
  - Remove and leave work even when the other side is offline (an inbox notice).
  - Each business keeps a log. 🤝 Partners app.
- **Home life**
  - **🏢 City Lofts** in the downtown Skyline Lofts tower: Studio, City Loft and Skyline Penthouse, from $15K, with
    no lot needed.
  - Lofts vs 🏠 houses vs 🏰 mansions, each with clear pros and cons.
  - **🎉 Parties**
    - Running a party:
      - A party is announced to the whole server and lasts 4 minutes, with a 20-minute cooldown.
      - Your home gets a light-up dance floor, a DJ booth and balloons, and party music plays.
      - Capacity: loft 6/10/16, house 12, mansion 24.
      - Visit permissions still apply.
    - Rewards:
      - The host gets rep per guest.
      - Guests get a once-an-hour favor worth 30 s of their own income (+50% at a loft).
    - 🎉 Home & Party app.

### Phase D
- **Vehicle roles** by class. Each role works only while you drive that car:
  - 🛵 Commuter: tuning costs half.
  - 🚚 Hauler: +25% City Job pay.
  - 🕶️ Getaway: police fines halved.
  - 🏁 Racer: +15% race prizes.
  - 🎩 VIP: +10% reputation.
- **Tuning:** Engine, Turbo, Suspension and Brakes, 5 levels each, up to +10% top speed. Purchases are checked on the
  server, and the server writes the tuned numbers on the car seat when the car spawns. Paint and parts stay looks-only.
- **📊 Leaderboards:** Net Worth, Revenue, Popularity, Properties, Fastest Lap, Heists, Explorer and Prestige. Each has
  three views: this server, global (OrderedDataStores written only by the server, every 5 minutes and on leave) and
  friends.
- **🌟 Prestige:** 10 long-term goals. Each is a permanent ⭐ worth +1% all income, with titles from Bronze to Diamond.
  Goals an existing save already meets are recognized on the first check.

### Phase E
- **📅 Special occasions** on the real calendar (UTC):
  - 🎃 Spooky Season (Oct 10 – Nov 1; **on right now**)
  - ❄️ Winter Lights (Dec 10 – Jan 2)
  - 💘 Sweetheart Week (Feb 7–15)
  - 🌸 Spring Fair (Apr 1–14)
  - ☀️ Summer Beach Fest (Jul 1–21)
  - 🎂 City Birthday (the 1st–3rd of every month)
  - Each has 3 tracked tasks and a claimable reward (cash, rep, a keepsake).
  - Progress and claims are saved per instance (e.g. `spooky2026`) and can't be claimed twice. Late claims are
    accepted for 3 days.
  - The Empire Plaza is decorated while an occasion runs.
  - **🔥 Weekend Rush:** Rush Orders tips ×1.5 on Saturdays and Sundays (the cap still applies).
- **🧭 Staged onboarding:** after the tutorial, a Next Step card shows ten steps, one at a time, each with
  "Show me" and a small reward. A locked step can wait ("Later"). Veterans' completed steps are recognized without
  paying them again.
- **Polish and devices:**
  - Every new window and stack card is included in the phone-layout and leak tests. The windows are also in the
    lifecycle tests.
  - New stack cards have priorities, so they never cover tutorials or problems.
  - New phone apps: 🍿 Theater, 🥊 Rivals, 🤝 Partners, 🎉 Party, 📊 Leaders, 📅 Events. The grid scrolls.

## 2. Install (existing place, keeps all player data)

1. Studio → **File → Save to File As…** → make a backup (e.g. `CornerEmpire_before_v14.rbxlx`).
2. **Write down** your 7 pass IDs (`GameServer → Config → C.PASSES`) and your `owners = {…}` (`GameServer → Admin`).
3. **ServerScriptService** → delete `GameServer` → right-click → **Insert from File…** → `updates/GameServer.rbxmx`.
4. **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click → **Insert from File…** → `updates/EmpireClient.rbxmx`.
5. Put back your pass IDs (`id = 0` → your number) and `owners = {YOUR_USERID}`.
6. Do **not** change `DATASTORE = "CornerEmpire_v5"`.
7. Game Settings → Security → **Enable Studio Access to API Services**. It is needed to test saving, the ledger and
   the global leaderboards; Studio uses separate `_StudioTest` stores.
8. Run the Studio checklist (section 6), then publish yourself.

For a new place instead, open `CornerEmpire_v14.rbxlx`, set the pass IDs and owner, test, then publish.

**Rollback:** reopen the backup. A v14 save still loads in v13 because the new records are kept untouched, but
anything bought with v14 features (theater levels, tuning) does nothing there.

## 3. Data migration notes

Migration step 13 → 14 (`DataMigration.steps[13]`, `M.v14Defaults()`) adds these records only if they are missing:

| field | default | what it holds |
|---|---|---|
| `theater` | `{up = {}, sessions = 0, tickets = 0, best = 0, filmShows = 0, premiered = {}}` | Movie Theater programme, upgrades, record |
| `rivals` | `{p = {}, wins = 0, losses = 0, moves = 0}` | market pressure per business, rivalry record |
| `xfer` | `{out = {}, got = {}, log = {}, seq = 0}` | ledger: pending sends, credited ids, history |
| `coop` | `{biz = {}, of = {}}` | co-owned businesses (members of mine / partnerships I'm in) |
| `loft` | `{level = 0}` | City Loft |
| `party` | `{hosted = 0, guests = 0, best = 0, lastAt = 0, favorAt = 0}` | home parties |
| `tune` | `{}` | car tuning levels |
| `prestige` | `{stars = {}}` | prestige goals reached |
| `events` | `{inst = {}, keep = {}}` | special occasions progress, claims, keepsakes |
| `onboard` | `{done = {}, skip = {}, c = {}}` | the 10 next steps |

- Every other field, including unknown future fields, is kept.
- A damaged new record is repaired field by field, and the rest of the save still loads (tested).
- If the step crashes, the migration is refused and the stored v13 save stays untouched (tested).
- `levels.theater` simply starts missing (0).
- Staff records gain `trait`, `shift` and `xp` only when someone is hired. Old staff have none, so their bonus is
  unchanged.
- **New DataStores**, all written only by server code:
  - `CE_Ledger`: one inbox per user (`in_<userId>`).
  - `CE_LB_<board>`: 8 OrderedDataStores.
  - `CE_LB_Names`: display names for the global boards.
  - In Studio, `C.storeName` adds `_StudioTest` to each.
- **Interior rooms:** the home's room moved from row 9 to row 20 (the theater uses row 9), and the loft uses row 21.
  Rooms are rebuilt on demand, so nothing saved changes.

## 4. Tests — SIMULATED (not Roblox Studio)

<<RESULTS>>

## 5. Known limitations

- **Not Studio-tested.** Physics, rendering, touch input, sound, real DataStores, MessagingService and the text filter
  are all simulated or absent in the test engine.
- **Music and ambience:** no audio IDs are included (licensing). The generated music plays until you add tracks in
  `EmpireClient → Audio → AUDIO`.
- **Global leaderboards** refresh every 5 minutes per player and are cached for 60 s. Friends on the global boards use
  `Player:IsFriendsWith`, which is a web call and may be slow the first time.
- **Gifts** need both players in the same server, because accept and confirm are live. Ledger deliveries and revenue
  shares do work across servers and while offline. Gifts have a daily limit (the larger of $25K and 10% of lifetime
  earnings).
- **Co-ownership:** the business always stays in the owner's save. Partners can only cook or contribute while the
  owner is in the same server. Revenue shares are paid only while the owner plays.
- **Theater shows** run only while the owner is in the game, like all income in Corner Empire.
- **Rivals** are per player (your rivalry record), not a shared server-wide market.
- **City Lofts** are interiors entered from the Skyline Lofts door downtown. There is no exterior unit per player.
- **Occasion dates** are fixed in `GameServer → Occasions` (UTC). Change them there.
- **Onboarding** step 1 (a perfect Rush Order) is counted from v14 on. It can't know about dishes served before.

## 6. Needs real Roblox Studio / phone testing

- [ ] Data:
  - [ ] Join with an existing v13 save. Cash, businesses, plots, cars, home, heists and city progress are intact, and
        the v14 records are added.
  - [ ] Leave and rejoin; everything is saved.
- [ ] NPC police:
  - [ ] Start a heist; units respond along the roads, sirens play, the chase banner shows.
  - [ ] Get arrested: the fine is applied and the cooldown starts.
  - [ ] Escape by distance.
- [ ] Theater:
  - [ ] Buy a plot and choose 🎬 on it. The pop-up screen appears on the plot, nothing appears on the home plot, and
        customers walk to it.
  - [ ] Upgrade to level 4: the marquee shows the film.
  - [ ] Wait for a show: there is a premiere post and the sales change.
  - [ ] Go inside: the screen title, seats and booth are there, and Rush Orders works at the counter.
- [ ] Rivals:
  - [ ] Wait about 4 minutes for a move; the challenge card appears.
  - [ ] Complete it with Rush Orders.
- [ ] Crew:
  - [ ] Hire someone with a trait.
  - [ ] Switch their shift in the Staff app at night and by day.
- [ ] Partners (2 accounts):
  - [ ] Gift offer → accept → confirm; check both cash amounts and histories.
  - [ ] Invite as partner: the partner runs your counter and pays for an upgrade.
  - [ ] Set a 10% share and wait 5 minutes.
  - [ ] Remove the partner while they're offline, then they rejoin.
- [ ] Ledger failure check (Studio): with API access on, send a gift, then stop the server mid-way (hard to time).
      At minimum, check the 📒 History shows ⏳ pending → sent.
- [ ] Party (2 accounts):
  - [ ] Throw a party at a loft; the guest taps the Join card.
  - [ ] Dance floor lights cycle, party music plays, the favor is paid, the host gets rep.
  - [ ] Set the home to private and check the guest is shown out.
- [ ] Cars:
  - [ ] Tune the engine to 5 and drive: higher top speed.
  - [ ] Drive a van to finish a City Job: +25% pay.
- [ ] Leaders:
  - [ ] Global boards fill after 5 minutes. Check the friends view with a friend account.
  - [ ] The prestige tab lists the 10 goals.
- [ ] Events: the 🎃 Spooky Season plaza arch is there. Do the three tasks, then claim.
- [ ] Onboarding: on a fresh save, after the tutorial, the Next Step card appears. "Show me" opens the right app and
      "Later" skips.
- [ ] Phones:
  - [ ] Open every new app (🍿 🥊 🤝 🎉 📊 📅) on a small phone. Text is readable and buttons are big enough to tap.
  - [ ] Stack cards don't cover the joystick or jump button.
  - [ ] The party and gift dialogs fit.
- [ ] Performance:
  - [ ] Party dance floor plus traffic at the plaza on a low-end phone.
  - [ ] The theater interior with 6 rows of seats.

## 7. Configuration (all in code, all server-checked)

`C.THEATER`, `C.FILMS` (Theater) · `C.RIVAL_CFG`, `C.RIVALS` (Rivals) · `C.CREW`, `C.TRAITS` (Crew) ·
`C.PARTNERS` (Partners) · `C.LEDGER` (Ledger) · `C.HOMELIFE` (HomeLife) · `C.VEHICLES` (Vehicles) · `C.LEADERS`,
`C.PRESTIGE_GOALS`, `C.BOARDS` (Leaders) · `C.OCCASIONS` (Occasions) · `C.ONBOARD_STEPS` (Onboarding) ·
`C.KITCHEN`, `C.RECIPES` (Kitchen) · `AUDIO` (EmpireClient → Audio).
