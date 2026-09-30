# Corner Empire

A 1–4 player Roblox business tycoon. **`CornerEmpire_v6.rbxlx` is the current place file**; open it in Roblox Studio.
`CornerEmpire_v5.rbxlx` is the version before the audit fixes, kept for reference.

## Layout

- `src/` holds every script from the place, one file per script, mirroring the Explorer:
  - `ServerScriptService/GameServer.server.lua` + `GameServer/*.lua` (server modules)
  - `StarterPlayer/StarterPlayerScripts/EmpireClient.client.lua` + `EmpireClient/*.lua` (client modules)
- `tools/build.py` rebuilds the place file from `src/` (`python3 tools/build.py CornerEmpire_v6.rbxlx`).
- `tools/extract.py` pulls the scripts back out of a place file; `tools/compare.py` compares two place files.
- `tools/check.sh` compiles every script and type-checks it against the Roblox API (needs the Luau tools).
- `tests/` runs the real scripts in a small simulated Roblox engine (`tests/harness.lua`): no physics or
  rendering, but real game logic, DataStores in memory and simulated time.
  - `python3 tests/run.py tests/critical_test.lua` checks the audit fixes
  - `python3 tests/run.py tests/features_test.lua` checks the new systems
  - `python3 tests/run.py tests/perf_test.lua` runs a 40-minute, 4-player soak test

The DataStore name is still `CornerEmpire_v5`, so existing saves carry over.

## Still on the owner's side

- Paste Roblox-licensed music IDs into `EmpireClient > Audio`.
- Put the real game pass IDs in `GameServer > Config` (`C.PASSES`).
- Publish, turn on **Enable Studio Access to API Services**, and set the place's Max Players to 4.
- In Studio, Settings shows 🧪 test tools (money, reputation, mega events, mystery lots, Spire, viral).
  They're refused by the server outside Studio.
