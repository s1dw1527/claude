# Corner Empire v11 — Install & Roblox Studio Test Checklist

Nothing below has been done in real Roblox Studio yet. The automated tests (see `V11_REPORT.md`) ran in a
**simulated** engine. Use this list in Studio before publishing.

## 1. Install the update (existing place, keep all player data)

1. Open your existing Corner Empire in Roblox Studio.
2. **File → Save to File As…** → save a backup (e.g. `CornerEmpire_before_v11.rbxlx`).
3. **Before deleting anything**, open the old `GameServer → Config` and `GameServer → Admin` and write down:
   - your 7 Game Pass IDs (`C.PASSES`, the `id = ...` numbers)
   - your `owners = {...}` UserId(s) in `C.ADMIN_CONFIG`
4. Explorer → **ServerScriptService** → delete `GameServer` → right-click ServerScriptService → **Insert from File…** →
   `updates/GameServer.rbxmx`.
5. Explorer → **StarterPlayer → StarterPlayerScripts** → delete `EmpireClient` → right-click StarterPlayerScripts →
   **Insert from File…** → `updates/EmpireClient.rbxmx`.
6. Put your notes back:
   - `GameServer → Config` → `C.PASSES` → replace each `id = 0` with your pass ID (only the number).
   - `GameServer → Admin` → `owners = {}` → `owners = {YOUR_USERID}`.
7. Do NOT touch `DATASTORE = "CornerEmpire_v5"` in Config. Do not create a new DataStore.
8. **Home → Game Settings → Security → Enable Studio Access to API Services** = ON.

Studio notes:
- Studio playtests save to `CornerEmpire_v5_StudioTest` (a test copy). Live saves are never touched from Studio.
- To test an *existing* save upgrading: playtest your OLD version first and build some progress (businesses, a
  plot, a home, a car), then install v11 and playtest again.
- In Studio every tester is an admin unless you set `studioIsOwner = false` in `GameServer → Admin` (do that for the
  "normal player can't use admin" test, then set it back if you like).
- Multiplayer: **Test → Clients and Servers**, 2–4 players.

## 2. Built-in checks (Studio)

- [ ] Output window: no red errors on start
- [ ] Settings → 🧪 **Update + data safety test** → all ✅ (includes the v10 → v11 step)

## 3. Real Studio test checklist

**Phone / Arcade**
- [ ] Phone Arcade opens
- [ ] Phone Arcade closes
- [ ] Phone Arcade reopens
- [ ] Phone Arcade works after playing a 2-player game
- [ ] Switching Arcade ↔ other phone apps several times keeps the phone working
- [ ] No GUI duplication (open/close 10×)

**Mountain**
- [ ] Mountain is visible north of the race track; the dirt road leads to it
- [ ] Secret lever works (prompt "Pull lever" in the ravine by the drain)
- [ ] Secret door animation works (lever swings, clunk, gears shake, slab slides, tunnel lights on)
- [ ] Another player sees the same door
- [ ] Walking through the tunnel works
- [ ] Car drives through the tunnel (try the Monster Truck and the Boulder XL — the biggest)
- [ ] Door stays open while you stand / park in the doorway; closes ~10 s after it's clear
- [ ] From inside, walking up to the door opens it (nobody trapped); the inside panel works
- [ ] Back exit (east side) opens from inside; the outside valve opens it
- [ ] Volcano HQ loads correctly (lava core, catwalk, pipes, garage bays, stations, banner)
- [ ] NPCs appear near the base and say lines
- [ ] "YOU FOUND THE SECRET HQ" shows the first time inside

**Robbery**
- [ ] Job board works (opens the 💰 Heists app)
- [ ] A robbery opportunity appears (or Admin → HEISTS → ▶ Open)
- [ ] Bank robbery starts (terminal at the entrance)
- [ ] Bag appears on the character
- [ ] Security puzzle shows, hides, accepts the right code
- [ ] Vault door opens; lasers blink
- [ ] Loot increases (HUD "BAG: $x / $y")
- [ ] Alarm works
- [ ] Police receive the alert + blue search circle
- [ ] Police can chase (and the [Arrest] prompt shows only for police)
- [ ] Player can escape
- [ ] Player can enter the mountain (on foot and by car)
- [ ] Loot turns into money only after reaching the base
- [ ] Failed robbery (arrest, abandon, leaving) gives no money
- [ ] Multiplayer robbery works (2+ crew, e.g. the Museum)
- [ ] Escape Garage spawns a car inside (after the base's Garage Level)

**Devices**
- [ ] Mobile UI works (phone-sized test device): Heists app, puzzle window, bag HUD
- [ ] Controller UI works (Space / Ⓐ for the timing puzzle; gamepad navigation)

**Regression (old systems)**
- [ ] No console errors after 10 minutes of play
- [ ] Existing businesses still work
- [ ] Existing properties (deeds) still work
- [ ] Existing cars still work
- [ ] Existing houses still work
- [ ] Existing DataStore still loads (old progress present)

**Admin**
- [ ] Your account gets the 🛡️ button; HEISTS tab works
- [ ] A normal account cannot open/use it (set `studioIsOwner = false` for this test)

Only after all of this: **File → Publish to Roblox** onto the existing Corner Empire experience.
