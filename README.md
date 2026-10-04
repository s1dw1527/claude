# Corner Empire

A 1–4 player Roblox business tycoon. **`CornerEmpire_v7.rbxlx` is the current place file**; open it in Roblox Studio.
`CornerEmpire_v6.rbxlx` and `CornerEmpire_v5.rbxlx` are the earlier versions, kept for reference.

## What's new in v7

- **Tutorial step 4 fixed.** "Open your phone" was the only step finished by a one-time message from the client, and the
  server ignored it unless it arrived while already on step 4. Opening the phone a moment early, or having it open when
  the step began, left the tutorial stuck for good. The client now reports whether the phone is open, and the server
  checks that every second like any other step. Step 4 also has an on-card **📱 Open Phone** button, a controller
  button (Y), and a phone button that sits above the mobile jump button. Every step shows live progress, and Studio's
  Output explains why a step is waiting (`[Tutorial] ...`).
- **A harder, earned economy.** All balance settings are in `GameServer > Config > C.ECONOMY`, and prices sit in the
  tables below it. See `tests/results/SUMMARY.md` for how long each milestone takes.
- **Story mode.** Six comedic chapters with **Lil Clipz**, an original streamer-parody rival. Progress follows your
  lifetime business earnings and milestones, never the cash in your pocket. The content is in
  `GameServer > StoryData`, the rules in `GameServer > Story`, and the cutscenes and phone app in `EmpireClient > Story`.

## Layout

- `src/` holds every script from the place, one file per script, mirroring the Explorer:
  - `ServerScriptService/GameServer.server.lua` + `GameServer/*.lua` (server modules)
  - `StarterPlayer/StarterPlayerScripts/EmpireClient.client.lua` + `EmpireClient/*.lua` (client modules)
- `tools/build.py` rebuilds the place file from `src/` (`python3 tools/build.py CornerEmpire_v7.rbxlx`).
- `tools/extract.py` pulls the scripts back out of a place file; `tools/compare.py` compares two place files.
- `tools/check.sh` compiles every script and type-checks it against the Roblox API (needs the Luau tools).
- `tests/` runs the real scripts in a small simulated Roblox engine (`tests/harness.lua`). There's no physics or
  rendering, but the game logic is real, DataStores live in memory and time is simulated.
  - `python3 tests/run.py tests/tutorial_test.lua`: the whole tutorial through the real client, with extra focus on step 4
  - `python3 tests/run.py tests/story_test.lua`: story chapters, rewards paid once, cutscenes, multiplayer, old saves
  - `python3 tests/run.py tests/critical_test.lua`: the earlier audit fixes
  - `python3 tests/run.py tests/features_test.lua`: the v6 systems
  - `python3 tests/run.py tests/perf_test.lua`: a 40-minute, 4-player soak test
  - `SIM_ARGS='profile="casual", hours=12' python3 tests/run.py tests/economy_sim.lua`: a bot plays a fresh save on
    the real server code and prints when it reaches each milestone. Profiles are `casual` and `active`; add
    `passes="x4,vip"` to see paid passes, or `fromSave=true` to continue an existing v6 save. `python3 tools/sim_table.py`
    turns the saved runs in `tests/results/` into `SUMMARY.md`.

The DataStore name is still `CornerEmpire_v5`, so existing saves carry over. Old saves load with their levels, homes and
cars. Story mode marks chapters an old empire has clearly already beaten as done (without paying those rewards) and
starts at the first one it hasn't.

## Still on the owner's side

- Paste Roblox-licensed music IDs into `EmpireClient > Audio`.
- Put the real game pass IDs in `GameServer > Config` (`C.PASSES`). The Rich Start and VIP descriptions changed in v7.
  Update the pass descriptions on the Roblox website to match.
- Publish, turn on **Enable Studio Access to API Services**, and set the place's Max Players to 4.
- In Studio, Settings shows 🧪 test tools: money, reputation, mega events, mystery lots, Spire, viral, and
  **Story: jump to next chapter**. The server refuses them outside Studio.
- To rename the rival, edit `C.STORY_RIVAL` and `C.STORY_CAST.rival` in `GameServer > StoryData`.
