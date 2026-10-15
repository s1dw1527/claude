# Corner Empire v18 — "Rags to Billions"

You asked for three things: a more dramatic, clickable name; bigger servers, so the game is more social; and a game people come back to because they're **curious** and **want more**.

> **Not tested in Roblox Studio, and nothing was published.** Every result below comes from the simulated engine (`tests/run.py`).
> The DataStore is still `CornerEmpire_v5`, with no data reset. The save schema stays at 16: the one new save field
> (`collect`) is additive.

---

## 1. The name: **Corner Empire: Rags to Billions**
You picked this one. It keeps your brand and adds a dramatic promise. "Billions" is also one of the big Roblox search words.

**In the game:**
- **Main menu:** "💰 CORNER EMPIRE" in the chunky Fredoka One font, with **"⚡ RAGS TO BILLIONS ⚡"** underneath, big and outlined.
- **The opening movie's title card:** CORNER EMPIRE / **RAGS TO BILLIONS** / "Build Your Fortune. Risk Everything. Leave a Legacy."

**For your Roblox listing** (the title and description are set on the Creator Dashboard, not by the game). Ready to paste:
- **Title** (under Roblox's 50-character limit):
  `💰 Corner Empire: Rags to Billions [12 PLAYERS!]`

  After later updates, swap the tag, e.g. `[🌈 RAINBOW CUSTOMERS]` or `[NEW BAZAAR]`. A changing update tag is a common way popular games signal that something's new.
- **Description:**
  ```
  Start with a lemonade stand. End with a billion-dollar empire. 💰
  🏙️ Build businesses, buy the city, drive your dream car
  🛍️ The City Bazaar restocks every 5 minutes — catch the 🌈 MYTHIC!
  ✨ Lucky customers: GOLDEN, DIAMOND… or the legendary RAINBOW
  📚 Find every ??? in your Collection Book
  👥 12-player servers — visit friends' parks and empires
  🎁 Daily rewards • 🗺️ Empire Roadmap • 🎬 Story mode • 💰 Heists
  New update every Saturday!
  ```
  Only promise a weekly update day if you can keep it. Grow a Garden's fixed weekly update day was a big part of its growth (see the v17 report).

## 2. 12-player servers
You picked 12.

- **Empire Heights:** a new neighbourhood east of the Corner Bank, with **8 new plots** (12 in total):
  - Heights Blvd, with 4 plots on each side facing the street, exactly like the plaza plots face Main St.
  - An "🏙️ EMPIRE HEIGHTS" arch over the boulevard, and street lamps along it.
  - New land (terrain) under it all.
  - A road from the end of Main St around the bank to the boulevard. It's a quiet street, not part of the city's traffic network, so the existing traffic and pedestrians are unchanged.
- **The server takes 12.** `MAX_PLAYERS = 12`, and a 13th player is told the server is full.
- **⚠️ You must also set this on Roblox:** Creator Dashboard → your experience → Places → (the place) → Settings → **Server Size → 12**. The game can't change that setting itself.
- **Legacy Museum:** it has 4 halls, now shared fairly. A player gets a hall when they visit their gallery and keeps it while they play. With more than 4 visitors, the hall that has been shown longest goes to the newest visitor, and a player leaving frees their hall.
- **The 🗺️ map** is wider so Empire Heights fits, at the same scale across and down as before, and it draws the new roads.

### 12 full empires (simulated soak)
All 12 players had a full set of businesses, running for 4 simulated minutes:

| What | Result | Limit |
|---|---|---|
| DataStore writes | **68 per minute** | Roblox allows 180 per minute for 12 players |
| Network | **3.5 events a second per player** | — |
| Instances | **30,966 → 31,163**: nothing piles up | — |
| Errors | None | — |

**The simulator can't measure frame rate on a real phone.** 12 full tycoons means the world holds roughly 31,000 instances. Please check a phone in a busy server (Studio checklist below).

**Recommendation, not done:** Roblox's **StreamingEnabled** loads only the part of the world near each player, which helps phones a lot in big servers. I did **not** turn it on. Client scripts in this game expect the whole city to be there (signs, heist sites, plots), and turning it on without Studio testing could break them. It's worth trying in Studio as a separate step.

## 3. Coming back because you're curious
- **📚 Collection Book** (new phone app):
  - **21 things to find:** the 18 Bazaar-only treasures and the 3 kinds of lucky customer.
  - Found entries show in full. Everything else is a **"❓ ???"** card showing only its rarity color and where to look ("City Bazaar", "a lucky customer at your shops"). You know it exists, but not what it is. The server never sends an unfound item's name or icon, so it can't be peeked at.
  - **Milestones:** 5 found (Collector), 10 (Treasure Hunter), 15 (Curator), all of them (Completionist). Each pays cash and ⭐ reputation once per save.
  - A new find is announced: "📚 New in your collection: 🦄 Rainbow Unicorn Statue (11 / 21)".
  - Once found, always found, even if the item is placed at home or sold. It's kept in the save.
- **🔮 "Coming up next" card:** after 8 minutes of play, once a session, a card in the notification stack shows:
  - tomorrow's daily reward (or that today's is still waiting);
  - the next city event and when it starts;
  - when the Bazaar restocks ("What will it be?");
  - how many treasures are still hidden.

  It never covers the screen, and never appears mid-ride, mid-heist or in a cutscene.

This builds on what v16 and v17 added for coming back: daily rewards with a streak, missions, the weekly challenge, live city events, the Bazaar restocks, lucky customers and the Roadmap.

---

## 4. Tests (simulated)

### New suites
- **`servers_test` (18 checks):**
  - 12 plots, 12 players each on their own plot, and a 13th turned away.
  - The 12-empire soak: DataStore, network and instances.
  - No plots overlap; Heights plots face their boulevard; the road crosses no plot; the arch is there; the ground is solid.
  - A Heights business works: customers come and pay, and the storefront faces the boulevard.
  - The museum halls are shared and freed.
  - The map covers Empire Heights.
- **`collection_test` (18 checks):**
  - Everything starts as "???", and the server sends no names.
  - Finds from the Bazaar and from lucky customers are announced, and stay found.
  - Milestones only pay once reached, and only once.
  - The app shows the "???" cards.
  - The "coming up next" card comes once a session, with the right contents.
  - Everything is saved.

### Updated
- **`layout_test`** now also checks the Empire Heights roads for clutter: 0 solid parts on them.
- **`features_test`**: the museum gallery is looked up by the player's hall.
- **`mobile_test`** includes the 🔮 card. It found its menu subtitle by the old text ("Build a company…"), so it silently stopped checking it after the rename. It now finds it by name, and the new subtitle fits a phone screen.
- **`data_test`**: version 18.0.0.

### Bugs caught and fixed while testing
- The "coming up next" card told the time to the next Bazaar restock using a different clock than the Bazaar itself. In the test it said "13888h"; it now uses the Bazaar's own clock.
- A missing comma in the update notes after adding v18's lines stopped the game config from loading. Every suite caught it at once.

### Full regression
RESULTS_PLACEHOLDER

### Static and build checks
- `tools/check.sh`: only the known `WorldFX.lua(59,4)` false positive.
- `tools/propcheck.py`: 0 problems.
- BUILD_PLACEHOLDER

---

## 5. Install
1. Replace **GameServer** and **EmpireClient** with the drop-ins in `updates/`. Both are needed: new server module Collection, new client module CollectionUI, and world changes.
2. Or open `CornerEmpire_v18.rbxlx`. It already has Lighting → Technology = Future.
3. **Set Server Size to 12** on the Creator Dashboard (see section 2).
4. **Update the listing title and description** (see section 1).

## 6. Studio checklist (please check before publishing)
1. **Drive from the plaza to Empire Heights:** east along Main St, turn off just before the Corner Bank, go around it, and onto Heights Blvd. Check that the road looks right and the arch reads "EMPIRE HEIGHTS".
2. **Start a game on a Heights plot** (play with 5 or more test players in Studio: Test → Clients and Servers → 5+ players). The business, customers, kiosks and tower should all look right, and nothing should clip the bank or the lamps.
3. **Phone frame rate** with several full empires in the server. If it's low, try StreamingEnabled as a separate test, or ShadowMap lighting.
4. **The main menu and opening movie title:** CORNER EMPIRE / RAGS TO BILLIONS, readable on a phone.
5. **📚 Collection app:** the ??? cards, and claiming a milestone.
6. **🔮 card:** play for 8 minutes and it should appear once.
