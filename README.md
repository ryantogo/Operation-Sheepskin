# Operation Sheepskin: Command Modern Operations Scenarios

Two *Command: Modern Operations* (CMO) scenarios built from the narrative in [`docs/operation-sheepskin-gone-hot-narrative.md`](docs/operation-sheepskin-gone-hot-narrative.md):

| Scenario | Setting | Database | Builder | Briefing |
|---|---|---|---|---|
| **Operation Sheepskin Gone Hot** | Anguilla, 19 March 1969, as the narrative tells it | Cold War (CWDB) | [`build_sheepskin_1969.lua`](scenarios/1969-sheepskin-gone-hot/build_sheepskin_1969.lua) | [`briefing_1969.md`](scenarios/1969-sheepskin-gone-hot/briefing_1969.md) |
| **Operation Shearling** | The same plan re-fought on 19 March 2026 | DB3000 | [`build_shearling_2026.lua`](scenarios/2026-operation-shearling/build_shearling_2026.lua) | [`briefing_2026.md`](scenarios/2026-operation-shearling/briefing_2026.md) |

Both put the player in command of the British task force. The emphasis is naval and air: naval gunfire support, landing craft and helicopter lifts under fire, a torpedo boat and a Trojan in 1969, and in 2026 a Kfir patrol, armed drones, light attack aircraft, missile boats and an Exocet coastal battery. A rifle company of 2 PARA fights the ground battle from Sandy Ground to The Valley.

## Why Lua builders instead of `.scen` files

A `.scen` file is a binary save that can only be written by the game. Each scenario here is a single Lua script that builds the whole scenario inside CMO's Scenario Editor: sides, postures, doctrine, every unit, reference points, AI missions, scoring and the event logic. The same approach makes the order of battle easy to read and to tweak before you build.

## Building a scenario

1. **File > New Scenario.** Choose the **Cold War** database for 1969 or **DB3000** for 2026. The DBIDs are database-specific; the wrong database places the wrong units.
2. **Editor > Lua Script Console.** Paste the whole builder and run it.
3. **Read the console report.** It lists anything that failed to place and every aircraft that was given a placeholder loadout.
4. **Arm the aircraft.** Use *Ready/Arm Aircraft* on each listed aircraft; the briefing file suggests a loadout for each. If you already know the loadout IDs, put them in the `LOADOUTS` table at the top of the builder before running it.
5. **Paste the briefing.** Copy the *Scenario Description* and *United Kingdom Briefing* sections from the briefing file, and enter the scoring thresholds it lists.
6. **File > Save As.** Save before you test-play. The builder resets the Lua key store, so if you test-play and then want a clean start, re-run the builder on a fresh blank scenario.

## What the event logic does

Each builder installs one repeating heartbeat event plus destroyed, damaged and detection events. Together they handle:

- **Lifts.** Landing craft and helicopters carry named platoons. Troops are placed ashore when a loaded craft reaches the beach marker, or a helicopter reaches the LZ at low altitude. Empty craft that return to their parent ship embark the next wave. The police will not embark until the beachhead is secure. A craft lost while loaded loses its troops.
- **Rules of engagement.** The UK starts on Weapons Hold. It is released to Weapons Tight when a British unit is hit or a hostile launch is detected (or after 30 minutes). Killing an enemy before the release is penalised.
- **AI timeline.** Anguillan air and naval missions start inactive and switch on at set times, so the defence unfolds the way the narrative describes rather than all at once.
- **Objectives.** Sandy Ground, Wallblake, The Quarter and The Valley are secured when a British ground unit is inside and the listed defenders are gone.
- **The Quarter.** Once the Valley road technical is destroyed and British troops are on the flank, the defenders hold fire and withdraw toward Island Harbour instead of dying in place, which scores better than annihilating them.
- **Political scoring.** Anguillian militia deaths, civilian buildings and boats, and the airport all cost points.
- **End state.** The scenario ends ten minutes after the police reach The Valley with the town secured.

## Sources and limits

- Every DBID was looked up in the public database listings at [cmano-db.com](https://cmano-db.com/) (Cold War db v.509 and DB3000 db v.511). Where the exact ship is missing (HMS Minerva, Iron Duke, Dauntless, Mounts Bay, Medway), a sister ship's entry is used and renamed; the briefings list each stand-in.
- Lua calls follow the [Command Lua API documentation](https://commandlua.github.io/).
- **Loadout IDs are not published anywhere public**, so aircraft are placed on the configured ID if you supply one, otherwise on a generic fallback, and the console tells you which ones to arm.
- The builders have been tested offline against a mock of the CMO Lua API (below), which checks argument shapes, name references, event wiring and the full scripted sequence. They have **not** yet been run inside CMO itself; if your build reports a failed call, the console message names it.

## Offline test

`tools/cmo_mock.lua` stands in for the game's Lua API and `tools/test_builder.lua` plays a builder end to end: every lift lands, every objective falls, the withdrawal and the end state fire, and the score log is printed.

```sh
lua tools/test_builder.lua scenarios/1969-sheepskin-gone-hot/build_sheepskin_1969.lua
lua tools/test_builder.lua scenarios/2026-operation-shearling/build_shearling_2026.lua
```

Any Lua 5.2 or later interpreter works.
