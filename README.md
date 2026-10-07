# Operation Sheepskin: Command Modern Operations Scenarios

Two *Command: Modern Operations* (CMO) scenarios built from the narrative in [`docs/operation-sheepskin-gone-hot-narrative.md`](docs/operation-sheepskin-gone-hot-narrative.md):

| Scenario | Setting | Database | Builder | Briefing |
|---|---|---|---|---|
| **Operation Sheepskin Gone Hot** | Anguilla, 19 March 1969, as the narrative tells it | Cold War (CWDB) | [`build_sheepskin_1969.lua`](scenarios/1969-sheepskin-gone-hot/build_sheepskin_1969.lua) | [`briefing_1969.md`](scenarios/1969-sheepskin-gone-hot/briefing_1969.md) |
| **Operation Shearling** | The same plan re-fought on 19 March 2026 | DB3000 | [`build_shearling_2026.lua`](scenarios/2026-operation-shearling/build_shearling_2026.lua) | [`briefing_2026.md`](scenarios/2026-operation-shearling/briefing_2026.md) |

Both are built to test the **real-time multiplayer** mode added in CMO v1.10 (October 2026): play them solo as the United Kingdom, co-op with both players on the United Kingdom, or head-to-head with one player per side. Single players command the British task force. The emphasis is naval and air: naval gunfire support, landing craft and helicopter lifts under fire, a torpedo boat and a Trojan in 1969, and in 2026 a Kfir patrol, armed drones, light attack aircraft, missile boats and an Exocet coastal battery. A rifle company of 2 PARA fights the ground battle from Sandy Ground to The Valley.

## Why Lua builders instead of `.scen` files

A `.scen` file is a binary save that can only be written by the game. Each scenario here is a single Lua script that builds the whole scenario inside CMO's Scenario Editor: sides, postures, doctrine, every unit, reference points, AI missions, scoring and the event logic. The same approach makes the order of battle easy to read and to tweak before you build.

## Building a scenario

1. **File > New Scenario.** Choose the **Cold War** database for 1969 or **DB3000** for 2026. The DBIDs are database-specific; the wrong database places the wrong units.
2. **Editor > Lua Script Console.** Paste the whole builder and run it.
3. **Read the console report.** It lists anything that failed to place and every aircraft that was given a placeholder loadout.
4. **Arm the aircraft.** Use *Ready/Arm Aircraft* on each listed aircraft; the briefing file suggests a loadout for each. If you already know the loadout IDs, put them in the `LOADOUTS` table at the top of the builder before running it.
5. **Paste the briefing.** Copy the *Scenario Description*, *United Kingdom Briefing* and *Anguilla Briefing* sections from the briefing file into the scenario and side briefings, and enter the scoring thresholds for both sides.
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

## Real-time multiplayer

| Mode | Sides | What changes |
|---|---|---|
| Single player | You: United Kingdom; AI: Anguilla | Everything as described above |
| Co-op | Both players: United Kingdom; AI: Anguilla | Routine news becomes map notifications instead of pop-ups, so one player's pop-up does not interrupt the other |
| Head-to-head | One player per side | The scripted AI timeline and the withdrawal at The Quarter switch off; the Anguillan player gets their own briefing, messages and score |

The scripts detect the mode at the first heartbeat with the v1.10 calls `ScenEdit_GetGameIsRTMP` and `ScenEdit_GetSideIsPlayer`, and show the result in the first British pop-up. On older builds they fall back to single-player behaviour. To keep the Lua load light (WarfareSims warns that heavy scripting can disturb multiplayer), the heartbeat reads British positions once per run, and the hit and launch-detection events that only exist to release the ROE fire once.

Anguilla scores whenever the British lose something, hit by hit and unit by unit, plus +5 per objective it still holds at each full hour and +20 if the British fire first. It loses points for every objective and unit it loses. Civilian losses cost both sides. Each briefing has the Anguillan side briefing and scoring thresholds.

[`docs/rtmp-test-plan.md`](docs/rtmp-test-plan.md) lists what to check in a live session, starting with the assumptions the offline tests cannot prove.

## Sources and limits

- Every DBID was looked up in the public database listings at [cmano-db.com](https://cmano-db.com/) (Cold War db v.509 and DB3000 db v.511). Where the exact ship is missing (HMS Minerva, Iron Duke, Dauntless, Mounts Bay, Medway), a sister ship's entry is used and renamed; the briefings list each stand-in.
- Lua calls follow the [Command Lua API documentation](https://commandlua.github.io/).
- **Loadout IDs are not published anywhere public**, so aircraft are placed on the configured ID if you supply one, otherwise on a generic fallback, and the console tells you which ones to arm.
- The builders have been tested offline against a mock of the CMO Lua API (below), which checks argument shapes, name references, event wiring and the full scripted sequence in single-player, co-op and head-to-head modes. They have **not** yet been run inside CMO itself, in single player or multiplayer; if your build reports a failed call, the console message names it.

## Offline test

`tools/cmo_mock.lua` stands in for the game's Lua API and `tools/test_builder.lua` plays a builder end to end three times (single player, co-op, head-to-head): every lift lands, every objective falls, the withdrawal and the end state fire, and both sides' score logs are printed.

```sh
lua tools/test_builder.lua scenarios/1969-sheepskin-gone-hot/build_sheepskin_1969.lua
lua tools/test_builder.lua scenarios/2026-operation-shearling/build_shearling_2026.lua
```

Any Lua 5.2 or later interpreter works.
