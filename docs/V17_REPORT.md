# Corner Empire v17 — "Viral Hooks" (+ graphics pass)

You asked for research into Roblox games that went viral and the advice behind them. This update builds the three hooks you chose from that research:
- **🛍️ City Bazaar:** a global shop that restocks every 5 minutes.
- **✨ Rare sales:** glowing Golden, Diamond and Rainbow customers, with a server shout.
- **⚡ A faster first 90 seconds,** plus Roblox Creator Analytics.

> **Not tested in Roblox Studio, and nothing was published.** Every result below comes from the simulated engine (`tests/run.py`).
> The DataStore is still `CornerEmpire_v5`. No data was reset, and the save schema stays at 16: the new save fields
> (`bazaar`, `rareSales`, `firstPlay`) are additive, and a save without them works as before.

---

## 1. The research: what made these games blow up

| Game | What happened | Lesson |
|---|---|---|
| **Grow a Garden** | Built by a teen in about 3 days. Splitting Point partnered with the creator at roughly 500 concurrent players (Madsen gave IGN 1,000–2,000) and added live ops: weekly updates and "Admin Abuse" events. It reached about 100K concurrent players in two weeks, and a reported peak of 21.6M–22.3M (beating Fortnite's 15.2M record). | A calm, simple core, plus **reasons to check back**: a shop that restocks on a timer, rare "mutations" from lucky rolls, and a fixed weekly update day with limited items that never return. |
| **Dead Rails** | Roblox's own TikTok, Instagram and X accounts boosted it, and it hit the front page in days. GameAnalytics says it worked because it was **familiar** (similar to Build A Boat) **yet novel**. | Players need to understand the game instantly. Short, shareable clips matter. |
| **99 Nights in the Forest** | About 26B visits, and film rights reportedly secured by a Disney-owned studio. | Social, co-op sessions with a clear goal. |
| **Steal a Brainrot** | Built on meme language: short, chaotic sessions, plus stealing from and defending against other players. *(Only low-quality sources were found, so this is the weakest evidence here.)* | Make moments people want to clip and talk about. |

### What Roblox itself says it rewards
These points are from Roblox's discovery documentation and newsroom.
- Recommendations follow **qualified play-through rate**, **first-play bounce**, **playtime per user** and **days played**. Newer signals look at **day 1, days 2–7 and days 8–28**.
- Recommendations are averaged **per user**, so a small game with engaged players isn't held back.
- **Thumbnail personalization** A/B-tests your thumbnails automatically once **two or more** are uploaded.
- Advice from retention guides (third-party, so treat it as opinion): **time-to-fun under 90 seconds**, a **"cascade of small wins"** in the first session, and **measure where players drop off** with Creator Analytics funnels.

### Sources
- [GamesBeat — How Grow a Garden took off (Janzen "Jandel" Madsen interview)](https://gamesbeat.com/janzen-madsen-interview/)
- [Fortune — Grow a Garden viral summer hit](https://fortune.com/2025/07/30/roblox-video-game-grow-a-garden-viral-summer-hit/)
- [Free Malaysia Today / AFP — Grow a Garden explodes](https://fmtv5.freemalaysiatoday.com/category/leisure/2025/06/27/robloxs-grow-a-garden-explodes-online-video-game-numbers)
- [bo3.gg — Grow a Garden Admin Abuse](https://bo3.gg/articles/grow-a-garden-when-does-admin-abuse-start)
- [stealthygaming — Admin Abuse times](https://stealthygaming.com/grow-a-garden-admin-abuse-times/)
- [GameAnalytics — Dead Rails and the Hit Makers formula](https://gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula)
- [AV Club — 99 Nights in the Forest movie](https://www.avclub.com/roblox-99-nights-in-the-forest-movie)
- [Licensing Magazine — Dead Rails licensing](https://www.licensingmagazine.com/2025/10/30/roblox-hit-dead-rails-names-think-influence-as-exclusive-agent/)
- [Roblox Creator Docs — Discovery](https://create.roblox.com/docs/en-us/discovery.md)
- [Roblox Creator Docs — Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails)
- [Roblox Creator Docs — Engagement analytics](https://create.roblox.com/docs/production/analytics/engagement)
- [Roblox Newsroom — Optimizing discovery](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
- [Rowatcher — What Roblox players need in their first week](https://rowatcher.com/news/day-by-day-what-roblox-players-need-in-their-first-week)
- [Rowatcher — Why games bleed players between sessions 2 and 5](https://rowatcher.com/news/why-your-roblox-game-bleeds-players-between-sessions-2-and-5)
- [creation.dev — Roblox player retention](https://www.creation.dev/blog/roblox-player-retention)

Player counts and visit numbers come from press and third-party trackers, and sources disagree on some figures (e.g. Grow a Garden's peak). Treat them as approximate.

---

## 2. What was built

### 🛍️ City Bazaar (`GameServer/Bazaar.lua`, `EmpireClient/BazaarUI.lua`)
This is Grow a Garden's seed-shop hook, in Corner Empire form.
- **It restocks every 5 minutes on the UTC clock.** The 5-minute window number seeds the roll, so **every server shows the same stock at the same moment**. "A Mythic is in the Bazaar right now" is true everywhere, which gives players something to tell each other.
- **6 slots per restock,** rolled by rarity. Measured over 20,000 simulated restocks:

  | Rarity | Configured chance | Measured | Limit per player per restock |
  |---|---|---|---|
  | Common | 55% | 55.05% | 3 |
  | Uncommon | 25% | 25.55% | 2 |
  | Rare | 12% | 11.55% | 1 |
  | Epic | 6% | 5.93% | 1 |
  | Legendary | 1.8% | 1.73% | 1 |
  | 🌈 Mythic | 0.2% | 0.19% | 1 |

  No item appears twice in one restock.
- **18 Bazaar-only furniture pieces** that the normal furniture shop never sells. Examples: 🦩 Neon Flamingo, 🐠 Aquarium Wall, ☄️ Meteor Rock, 💠 Diamond Chandelier, ⛲ Gold Fountain, 🦄 Rainbow Unicorn Statue, 🌌 Pocket Black Hole. They're placed like any other furniture, in any home tier.
- **Price:** the rarity's base price or a few minutes of the buyer's income, whichever is more. That keeps items meaningful from the first hour to a billion-dollar empire.
- **Rules:**
  - In-game cash only, and the client never sends a price.
  - Bazaar items **can't be sold back**, so they can't be farmed.
  - The 120-item furniture storage cap applies.
  - What you bought this restock is **saved in your slot**, so rejoining or hopping servers doesn't reset your limit.
  - A purchase names the restock it was looking at, so it never lands on a different item after a restock.
- **Hype:**
  - A restock with an **Epic or better** is announced to the server. Players riding, mid-heist, in a cutscene or still in the tutorial aren't told.
  - Buying a Legendary or Mythic is announced (low priority).
  - A **stall in the plaza** next to the City Event board shows the best item in stock, with a "Browse the Bazaar" prompt.
  - There's also a new 🛍️ **Bazaar** phone app: rarity-colored cards, green price pills, SOLD OUT, and a live "⏳ RESTOCK IN m:ss".

### ✨ Rare sales (`GameServer/Systems.lua`, `EmpireClient/WorldFX.lua` and `HUD.lua`)
This is the "lucky mutation" moment.
- **Each customer has a small chance to be rare:**

  | Kind | Chance | Pays | Measured over 400,000 rolls |
  |---|---|---|---|
  | ✨ Golden | 1 in 250 | ×10 | 1 in 246 |
  | 💎 Diamond | 1 in 2,500 | ×50 | 1 in 2,597 |
  | 🌈 Rainbow | 1 in 25,000 | ×250 | 11 Rainbows |

- **Everyone in the server sees the customer walk in glowing:** a neon outfit, sparkles, a light, and "✨ GOLDEN CUSTOMER" over their head. Rare customers always show, even with crowds turned off.
- The extra pay is **capped** at 10 minutes of the owner's income, so a Rainbow is a thrill, not an economy breaker.
- **On the seller's screen:** a big "✨ GOLDEN SALE! +$…" pop, with confetti for Diamond and up.
- **Diamond and Rainbow are shouted to the whole server.** A Rainbow also posts to CityBuzz and counts as a viral moment.
- The counts are **saved** and shown on the 🪪 showcase card.
- **Economy effect** (estimated from the odds and multipliers): roughly **+6% on customer-sale income** on average. Customer sales are only part of total income, so the overall effect is smaller. I did not re-run the economy simulator for this.

### ⚡ The first 90 seconds (new saves only)
The same quick-player bot played a brand-new save twice, through the real actions:

| | First sale | Lemonade Lv 3 | Second business | Celebrated wins in the first 2 min |
|---|---|---|---|---|
| **Before (v16.1)** | **14.2 s** | 1.5 s | 2.1 s | 5 |
| **After (v17)** | **1.8 s** | 1.5 s | 2.1 s | 7 |

- **The first customer comes at once.** When a new save opens its first business, a customer walks straight in from the door (about 1.2 s), and the first sale gets a "🎉 FIRST SALE!" moment.
- **Grand opening crowd:** customers come ×2.5 for the first 90 seconds after the first business opens. This applies only to saves created in v17 or later; existing saves are never boosted.
- The rest of the opening was already fast: the starting cash and tutorial rewards carry a quick player to Lv 3 and a second business in seconds.

### 📊 Creator Analytics (`GameServer/Analytics.lua`)
Once published, the Creator Hub dashboards show where new players stop.
- **Onboarding funnel** (`LogOnboardingFunnelStepEvent`). It covers new saves only, sends each step once, and keeps the steps in the save:
  1. New game
  2. First sale
  3. Lemonade Lv 3
  4. Second business
  5. Phone opened
  6. Tutorial done
  7. First car
  8. Five minutes played
- **Economy events** (`LogEconomyEvent`): money spent on upgrades and the Bazaar, and money earned from rewards and rare sales. These are throttled per player. Ordinary sales are **not** logged one by one, to stay inside Roblox's rate limits.
- **Custom events** (`LogCustomEvent`): rare sales, Legendary or Mythic Bazaar buys, and the opening movie watched vs. skipped.
- Every call is wrapped in `pcall`, so analytics can't break the game. To turn it off, set `C.ANALYTICS.enabled = false`.

### 🎨 Graphics pass: compared with popular Roblox games
You said the graphics look bad, so I compared Corner Empire's setup with what popular Roblox games and Roblox's own guidance use.
- **What I measured:** the real world the game builds — 18,515 visible parts — counted by material and color, plus every lighting setting.
- **What I couldn't do:** render the game. I can't take screenshots here, so the final look needs your eyes in Studio (checklist below).

| | Popular Roblox games / Roblox guidance | Corner Empire before | Now |
|---|---|---|---|
| **Lighting technology** | **Future** (real-time shadows from every light, light that bounces) | **Not set.** The place file had no Lighting at all, so the game ran on whatever default Studio picked: usually the flat legacy look. This was the biggest reason it looked bad. | **Future**, written into the place file by the build. Roblox scales it down on weak devices by itself. |
| **Ambient light** | Most light comes from the sun, so shadows give buildings shape | Outdoor ambient 140,140,160: so bright from every side that shadows barely showed, and everything looked flat | 118,120,136, with the sun raised to 3.0. Shadows and shapes read. |
| **Atmosphere** | Light haze for depth, plus a sun glare | Haze 1.4 (milky, washed out), glare 0.2 | Haze 0.6, glare 0.45, a cooler far color |
| **Depth of field** | Used in menus and cutscenes, not to blur gameplay | Blurred everything past ~120 studs, so the whole city looked soft, especially on phones | Only the far horizon (600+ studs) softens |
| **Color grade** | Contrast for punch; colors left natural | +15% saturation on already-strong colors, little contrast | +5% saturation, +14% contrast |
| **Bloom and sun rays** | Subtle | Bloom 0.5 plus pure-white parts made white surfaces glow | Bloom 0.35, sun rays 0.06 |
| **Palette** | Off-whites and soft brights, so nothing blows out | 7.8% of parts pure white (blown out under bloom), 0.2% maximum-saturation brights | 0% and 0%. Pure white becomes a soft off-white; extreme brights lose a little saturation. Hue never changes, and Neon and Glass keep their glow. |
| **Materials** | Textured materials on big surfaces, smooth plastic for stylized props | By area, big surfaces were already textured: concrete 24%, rock 18%, grass 16%, asphalt 15%. Smooth plastic is 44% of parts but only 7% of the area (small props), which suits a stylized game. | Unchanged. This wasn't the problem. |

**Already installed in a place?** The drop-ins replace scripts only, and the place's Lighting isn't one of them. So in Studio, set **Lighting → Technology → Future** once by hand. A fresh `CornerEmpire_v17.rbxlx` already has it.

Sources for the lighting guidance:
- [Roblox DevForum — Improve Lighting (step by step)](https://devforum.roblox.com/t/improve-lighting-step-by-step/1387033)
- [creation.dev — How to make realistic lighting in Roblox Studio](https://www.creation.dev/learn/how-to-make-realistic-lighting-roblox-studio)
- [creation.dev — Lighting plugins / Future lighting](https://www.creation.dev/tools/lighting-plugins)
- [Roblox Creator Docs — PBR textures / SurfaceAppearance](https://create.roblox.com/docs/en-us/art/modeling/surface-appearance)
- [Roblox Newsroom — custom material variants](https://about.roblox.com/newsroom/2022/07/introducing-custom-material-variants-new-enhancements-materials)

These are community and third-party guides, not exact numbers. The values above are starting points chosen to fix what was measured, and they are tunable in `GameServer/Util.lua` (the LIGHTING section).

**Bigger visual upgrades that need your Studio work (not done here):**
- Custom meshes with `SurfaceAppearance`: modelled storefronts, trees and cars instead of blocks.
- Material variants in MaterialService (brick, tile and wood packs).
- Uploaded sky textures.

All of these need uploaded assets, which I can't create or upload from here.

---

## 3. Tests (simulated)

### New suites
- **`bazaar_test` (22 checks):**
  - the same stock everywhere, and the same again when recalculated;
  - restock boundaries;
  - no duplicate items;
  - the rarity odds;
  - prices, limits, refusing a stale restock, server-side price, not enough cash, no sell-back, the full-storage cap;
  - the app and tapping a pill;
  - limits surviving a rejoin and resetting on a restock;
  - the stall;
  - announcements only for Epic and up.
- **`raresale_test` (14 checks):**
  - the odds, ×10 Golden pay, and the cap;
  - the glowing customer sent to every client and drawn on screen, and paid when they reach the counter;
  - the seller's pop;
  - no shout for Golden, a shout for Diamond, and CityBuzz for a Rainbow;
  - the showcase, and the save.
- **`firstplay_test` (18 checks):**
  - the time-to-fun timeline;
  - the first-sale moment;
  - the grand opening crowd ×2.5, and its end;
  - funnel steps in order, once each, and not again after a rejoin;
  - economy events with no per-sale logging;
  - "five minutes played";
  - an existing save gets no boost and no funnel;
  - intro skipped is logged.

### Updated
- `graphics_test`: 5 new "look" checks:
  - daylight from the sun, not flat ambient;
  - a clear atmosphere;
  - no city blur;
  - a contrast-not-saturation grade;
  - no blown-out whites or extreme brights, with Neon and ordinary colors untouched.
- `city_test`: the district-crowd check now counts the people who belong to that district. Under heavy load it used to also count neighbors inside the 160-stud circle (the Industrial Zone reached into Hillside and the Fun Park). Measured: 21 of the 22 Industrial-district people are workers.
- `layout_test` (unchanged) caught the first spot for the Bazaar stall, which was on the South Ring road. The stall moved to the sidewalk strip next to the City Event board.
- `data_test`: version 17.0.0.
- `social_test`: the showcase allowlist now includes the rare-sale counts, which are public by design.
- `tests/harness.lua`: the simulated `AnalyticsService` now records the calls, so tests can check them.

### Full regression
RESULTS_PLACEHOLDER

### Static and build checks
- `tools/check.sh`: only the known `WorldFX.lua(59,4)` false positive.
- `tools/propcheck.py`: 0 problems.
- Build and round trip: see below.

---

## 4. Install
1. Replace **GameServer** with `updates/GameServer.rbxmx` and **EmpireClient** with `updates/EmpireClient.rbxmx`. **Both are needed:** new server modules (Bazaar, Analytics) and new client modules (BazaarUI).
2. Or open `CornerEmpire_v17.rbxlx`.

Your pass IDs and admin list stay as you set them.

## 5. Owner launch checklist (from the research, things only you can do)
1. **Upload 2–4 thumbnails.** Roblox A/B-tests them for you once there are two or more. Show a glowing 🌈 Rainbow customer, the Bazaar stall and a billionaire tower.
2. **Pick a fixed weekly update day** and put it in the game description (e.g. "New update every Saturday"). Grow a Garden's weekly cadence was central to its growth.
3. **Clip the moments:** a Rainbow customer walking in, a Mythic in the Bazaar, a heist escape. Short vertical clips are how Dead Rails got seen.
4. **Watch the funnel** in Creator Hub → Analytics → Onboarding funnel after publishing. The biggest drop between steps is the next thing to fix.
5. **Watch day-1 and day-7 retention.** Roblox's newer recommendation signals look at day 1, days 2–7 and days 8–28.

## 6. Studio checklist (please check before publishing)
1. **The Bazaar stall** in the plaza: it shouldn't overlap anything, the sign should be readable, and the prompt should open the app.
2. **Place a few Bazaar items at home,** e.g. the Gold Fountain (2×2) and the Aquarium Wall, to check they look right.
3. **The new lighting (most important):**
   - Lighting → Technology should read **Future**. In an existing place, set it by hand.
   - Walk the city at noon and at sunset: buildings should have clear shadows and no milky haze, and the distance shouldn't be blurry.
   - On a phone, check the frame rate. If it's too slow, ShadowMap is the lighter option.
4. **A glowing customer:** use `C.RARE_FORCE = "rainbow"` in the command bar for a minute, then set it back to `nil`. Check the neon, the sparkles, the tag over their head, the pop, and the shout to a second player.
5. **A new save:** the first customer walks in at once, and the FIRST SALE splash shows.
6. **After publishing:** Creator Hub → Analytics shows the onboarding funnel steps. This can take a day to appear.
