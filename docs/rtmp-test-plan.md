# Real-Time Multiplayer Test Plan

Both scenarios are built to exercise the real-time multiplayer (RTMP) mode added in CMO v1.10 (6 October 2026). The offline tests in `tools/` prove the scripts' own logic in three modes (single player, co-op, head-to-head) against a stand-in for the game's Lua API. They cannot prove how the live game behaves, so this plan lists what to check in a real session and what the scripts assume.

## What the scripts assume

| Assumption | Why it matters | If it is wrong |
|---|---|---|
| Scripts run once, on the host | The second player joins the host's running instance, so events should fire once | Duplicate pop-ups, double scoring, two copies of each landed platoon |
| `ScenEdit_GetGameIsRTMP()` reports multiplayer | Co-op switches routine news to map notifications | Co-op gets pop-ups for everything, as in single player |
| `ScenEdit_GetSideIsPlayer("Anguilla")` reports a human Anguillan | Head-to-head switches off the AI timeline and the withdrawal | The AI activates missions the human never chose, and the human's Quarter defenders get marched off the map |
| Special messages reach every player on the addressed side, and only them | Co-op players both need the news; head-to-head players must not see each other's | One co-op player misses news, or information leaks between sides |
| Map notifications (barks) do not block | Routine co-op news is sent as barks | Barks may show on the host only |
| `ScenEdit_EndScenario()` ends the session for both players | The scenario ends ten minutes after the police reach The Valley | One client hangs, or the session never ends |

## Checklist

Run each scenario in each mode. The first British pop-up ends with a *Session:* line that shows what the scripts detected.

### 1. Lobby and set-up
- [ ] The scenario appears in the host lobby and the second player can join.
- [ ] Co-op: both players can take the United Kingdom.
- [ ] Head-to-head: one player can take the United Kingdom and the other Anguilla.
- [ ] Anguillan Civilians cannot be chosen.

### 2. Detection (first pop-up)
- [ ] Co-op shows *real-time multiplayer; Anguilla is AI-controlled*.
- [ ] Head-to-head shows *real-time multiplayer; Anguilla is human-controlled*, and the Anguillan player gets their own intro.
- [ ] Both British players see the intro in co-op, and it appears **once** (checks the run-once assumption).

### 3. Messages
- [ ] Co-op: landing a craft at Sandy Ground shows a yellow map notification, not a pop-up. Note whether the client player sees it too.
- [ ] Co-op: securing Sandy Ground shows a pop-up to both players.
- [ ] Head-to-head: the Anguillan player gets *Sandy Ground has fallen* but never sees British pop-ups.

### 4. Rules of engagement
- [ ] The British start on Weapons Hold on every axis.
- [ ] The first Anguillan shot (a hit or a detected launch) releases Weapons Tight with one pop-up. It should not repeat when more missiles come in.
- [ ] Head-to-head: the Anguillan player gets *The British are now free to return fire.*

### 5. Lifts and objectives
- [ ] One platoon appears per craft per wave, not two (checks the run-once assumption again).
- [ ] An empty landing craft back alongside its parent ship embarks the next wave; the police wait for the beachhead.
- [ ] Each objective scores once for the UK and costs Anguilla once.

### 6. AI timeline (co-op) and human control (head-to-head)
- [ ] Co-op: the staged Anguillan missions switch on at their times (see the briefing).
- [ ] Head-to-head: they stay off until the Anguillan player activates them.
- [ ] Co-op: The Quarter's defenders withdraw once the Valley-road technical is dead and two British units are close. Head-to-head: they do not move on their own.

### 7. Scoring
- [ ] Both sides' scores move as the briefings describe; check the score log on each client.
- [ ] Anguilla gains +5 per objective still held at each full hour.

### 8. Ending and performance
- [ ] The scenario ends for **both** players ten minutes after the police reach The Valley.
- [ ] No visible stutter when the heartbeat runs (every 15 to 30 seconds of game time) at high time compression.
- [ ] 2026: no stutter during an Exocet or drone attack (the launch-detection event should fire only once).

## Reporting

Record the CMO build, the mode, which checks failed, and whether the host and the client saw different things. A difference between host and client usually points to the run-once or messaging assumptions above. The Matrix Games forum's CMO section is the place to report engine-side issues.
