# Corner Empire v12 — City Takeover & Billionaire Progression

**An update, not a rebuild.** Same game, same DataStore **`CornerEmpire_v5`**, save schema 11 → 12 with a safe,
additive migration. Nothing was published to Roblox. Install **both** `updates/GameServer.rbxmx` and
`updates/EmpireClient.rbxmx` (section 5), or open `CornerEmpire_v12.rbxlx`.

> **Testing honesty.** Everything in section 6 ran in this repository's **simulated** Roblox engine. **None of it ran in
> Roblox Studio or on a phone.** The simulated engine has no terrain, no real rendering, no real fonts, no real
> DataStore service and no real touch input, so the pictures of the plaza, tower crown, storefronts, fireworks and
> cinematics are **unverified until you look at them in Studio**. Section 7 is the checklist of what needs a real test.

## 1. What you get

| # | You asked for | What it is |
|---|---|---|
| 1 | Living City progression | The Empire Tower grows **3 extra floors per milestone** and a crown: gold band + helipad ($1M), glowing spire ($10M), a gold sky beam ($100M), a turning Billionaire crown with fireworks ($1B). Every open business gets planters once you are a millionaire; Luxury Gold and Billionaire storefronts unlock with the milestones. |
| 2 | Billionaire milestones | **$1M, $10M, $100M, $1B** of *empire value*. Claimed **once per save**, **verified on the server**, rewarded on the server (section 3). Celebration: fireworks and shockwave over your tower, a splash banner, a camera-friendly cinematic, a CityBuzz post (`F.viralMoment`), a server-wide splash for a billionaire. |
| 3 | Empire Showcase / Hall of Fame | **Empire Plaza** on the beach (map marker 👑, teleport `plaza`, 📱 Empire app). Two billboards list the richest empires with business name, value and verified milestone badges. The **Empire Hall** window shows the top 10 with **🚶 Visit** buttons. Rankings are shared across servers (section 4). |
| 4 | Business makeovers | New brand field **storefront style**: Classic, Modern, Neon Nights, Retro Diner (free), Luxury Gold ($10M), Billionaire ($1B). Works with the existing sign colour, accent, exterior colour, logo and name. Picked in the Empire Hall → 🎨 Makeovers. |
| 5 | Grand Opening events | The first time a business reaches a **new building tier** it plays a *Grand Re-Opening*: NPC customers rush the door, confetti, burst and shockwave, a camera shot, a CityBuzz post. Once per business and tier, never repeated. |
| 6 | First Business tutorial | Steps 1–2 reworded shorter ("Open your first business…", "Customers are paying you!…"). Added a **💵 FIRST INCOME!** moment (burst over the stand) and a **⭐ FIRST UPGRADE!** moment. Veterans get neither (the migration marks them done). |
| 7 | Thumbnail moments, as real gameplay | (a) the plaza: a tiny "🍋 DAY ONE $0" stand beside a giant golden tower labelled $1,000,000,000; (b) the **HQ reveal** cinematic when you build an HQ floor; (c) the **billionaire celebration** (tower crown, beam, fireworks, cinematic). All happen in normal play; the admin panel can replay them for testing. |
| 8 | Mobile UI | No layout change. The Empire Hall is an ordinary modal (same window system as every other menu). The notification stack, CityBuzz feed and phone layout are unchanged; `mobile_test` still passes (section 6). |

## 2. Empire value and the milestones

`F.empireValue(d)` = cash + business upgrade spend + chain costs + deeds paid + rental building value + owned car prices
+ home + built HQ floors. Counted at what was **paid**, so spending money on things never lowers it and the number can't
be inflated by clicking.

| Milestone | Value | Reward (once) | Visible perk |
|---|---|---|---|
| 💵 MILLIONAIRE | $1M | $10K, 50 rep, 200 followers | crown band + helipad, +3 floors |
| 💰 MULTI-MILLIONAIRE | $10M | $100K, 150 rep, 800 followers | spire, Luxury Gold storefront |
| 💎 HUNDRED-MILLIONAIRE | $100M | $1M, 400 rep, 3,000 followers | gold sky beam |
| 👑 BILLIONAIRE | $1B | $10M, 1,000 rep, 10,000 followers | turning crown, fireworks, Billionaire storefront |

## 3. Why it can't be cheated (all checks are server-side)

- The client never sends a value or a claim. The only empire actions are `empInfo` (read), `empVisit` (a user id, validated) and `brand … style` (a style name, validated against the tier).
- A milestone needs **empire value ≥ target and lifetime earned income ≥ 20% of the target**, so admin-granted cash or one lucky payout can't buy a milestone.
- Claimed once per save (`empire.ms[key]` = time). The record is repaired on every read.
- Rewards are paid by the same code that claims. A rebirth resets businesses but not the claimed-milestone record, so nothing is paid twice.
- Locked storefront styles are refused on the server.
- The admin "test celebration" plays the show and **claims and pays nothing**.

## 4. Hall of Fame storage

- `OrderedDataStore` `CE_EmpireValue` (rank) + `DataStore` `CE_Empires` (name, tags, flagship business). Both go through `C.storeName`, so Studio test sessions use separate `_StudioTest` copies and never touch live data.
- Published when you pass a milestone, every ~150 s if your value moved ≥ 5%, and when you leave. Refreshed every 120 s. Players in the current server are merged in live. Without DataStore access it falls back to the players in the server.
- Only the server writes to it. The player's own `CornerEmpire_v5` save is never read or changed by the board.
- **Visiting is same-server only** (you can walk into the business of someone who is in your server and has it open to visitors). A Roblox server holds at most 4 players here, so a cross-server visit would need teleporting; that was **not** built.

## 5. Install (existing place, keeps all player data)

1. Studio → **File → Save to File As…** → make a backup (e.g. `CornerEmpire_before_v12.rbxlx`).
2. **Write down** your 7 pass IDs (`GameServer → Config → C.PASSES`) and your `owners = {…}` (`GameServer → Admin`).
3. **ServerScriptService** → delete `GameServer` → right-click → **Insert from File…** → `updates/GameServer.rbxmx`.
4. **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click → **Insert from File…** → `updates/EmpireClient.rbxmx`.
5. Put back your pass IDs (`id = 0` → your number) and `owners = {YOUR_USERID}`.
6. Do **not** touch `DATASTORE = "CornerEmpire_v5"`.
7. Test in Studio first (section 7), then publish yourself. Server size 4.

New place instead? Open `CornerEmpire_v12.rbxlx`, set the pass IDs and owner, publish.

**Rollback:** reopen the backup from step 1. A v12 save is still readable by v11 code (new fields are extra, unknown fields are kept) but milestone progress would be ignored until v12 is back.

## 6. Tests — SIMULATED (not Roblox Studio)

Results are filled in at the end of this file (section 9) from the final run.

New `tests/empire_test.lua` covers: value rules and NaN safety; milestone verification (no real earnings = no claim,
real earnings = claim, no double pay, client can't claim or send a value, a huge jump claims all); damaged milestone
record repair; the tower crown; storefront style rules (free styles, locked styles refused, unknown style refused,
every style builds); the plaza and board text; hall ranking, visit flags and bad visit input; tier opening once only;
first-income / first-upgrade once only; short tutorial text; the Empire Hall window tabs; the admin test tool.
`tests/data_test.lua` covers the v11 → v12 migration (cash, levels, brand, heists and unknown fields kept, original
untouched, damaged record repaired, a crashing step refused). `tests/mobile_test.lua` was made timing-robust (it now
waits for a state packet before measuring the notification stack — the failures were test timing, not a layout bug).

## 7. Needs a real Roblox Studio / phone test

- [ ] Output shows no red errors on start; the plaza appears on the beach (south of the city, below the Beach district) with two billboards, the arch, the tiny stand and the giant tower
- [ ] Map → 👑 Empire Plaza → Visit teleports you there
- [ ] 📱 Empire app opens the Empire Hall on a phone (390×700) and desktop; tabs, Visit buttons and style Apply buttons are tappable
- [ ] Admin panel → Heists tab → 👑 Test $1M / $1B celebration plays fireworks, a splash, the cinematic and a CityBuzz post — and your cash and tier do **not** change
- [ ] On a test save, give yourself income + cash past $1M (admin): the claim happens within ~5 s, paid once; the tower grows floors and a crown; restart the server and confirm it is still claimed and not paid twice
- [ ] Each storefront style looks right on a stand and a shop (Neon, Retro, Luxury, Billionaire); sign text still readable; renaming still updates the sign
- [ ] Upgrade a business to a new building tier → Grand Re-Opening with crowd, once
- [ ] Build an HQ floor → HQ reveal cinematic
- [ ] New save: first five minutes (open stand → name → first income → upgrade to level 3), tutorial card text fits on a phone
- [ ] Notification stack still max 3 and the middle of the screen free while the celebration plays
- [ ] Hall of Fame in two live servers: values appear in both (needs Studio API access to DataStores enabled, in a published place)

## 8. Thumbnail test (your marketing question)

Test **B: "$0 → $1 BILLION"** first. It is the one the game can now literally show: the plaza's tiny stand beside the giant
tower is the picture. Compare against A "BUILD YOUR EMPIRE!" and C "OWN THE CITY!" with Roblox's thumbnail A/B test; judge by
**click-through rate with enough impressions** and also **retention** (a thumbnail that gets clicks but players leave in
the first minutes isn't winning). Take the screenshots from the plaza with Photo Mode.

## 9. Final results

(see the end of this file — filled in by the last test run)
