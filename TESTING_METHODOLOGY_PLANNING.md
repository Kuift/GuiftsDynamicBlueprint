# Testing Methodology Planning

Historical test design, not the current launch policy. The headless guidance,
13-scenario count, simulated harvest shortcuts, and log-only stall interpretation
below are superseded. Read [START_HERE.md](START_HERE.md),
[RUNTIME_TESTING.md](RUNTIME_TESTING.md), and [AIB_TEST_AUDIT.md](AIB_TEST_AUDIT.md).
Runtime is paused; when resumed, KAG runs must be visible and follow the active
exact-map priority in [GOAL_HANDOFF.md](GOAL_HANDOFF.md).

## Current Implementation Status

Implemented in this mod:

- Headless test launch script: `Tools/run_aib_tests.ps1`
- Log parser: `Tools/parse_aib_test_log.ps1`
- Test gamemode: `Rules/AIBTest/gamemode.cfg`
- Unique AIBTest mapcycle/team configs to avoid KAG basename collisions.
- Root `Scripts/AIBTest*.as` harness files, because this install reliably resolves gamemode script names from the mod `Scripts` folder.
- Thirteen automated scenarios currently run and pass: delivery to tent, simulated tree/log pipeline plus full-inventory return, selected-tree priority, tent-priority tree choice, red-barrier rejection, right-side knight safety, left-side knight safety, archer safety, knight fear, wall-blocked safety, pathing-obstacle target acquisition, no-home/no-local-drop, and simulated tree-selection toggle/unselect.
- `Rules/AIBTest/gamemode.cfg` sets `sv_canpause = no`, and `Scripts/aib_test_autostart.as` sets `sv_canpause = false`.
- The harness tags fixtures as `aibt test fixture`, removes them by id and tag between scenarios, and logs cleanup counts through `[AIBEVT]`.

Known limitation:

- A fully live headless tree-chop-to-log-to-wood scenario is not stable in the current KAG test process. The server consistently stops advancing around game tick 51, so long-running live chopping tests can hang before timeout logic runs. The automated suite therefore tests selected-tree targeting separately, logs simulated tree/log material generation in the inventory-return scenario, and then exercises the real return/drop-at-tent path.

## Goal

Manual KAG testing is too slow for AI work. The test setup should make common AI builder behaviors repeatable, observable, and mostly automatic:

- Spawn the same terrain, tents, trees, enemies, and AI builders every run.
- Start the same AI actions without relying on hand-clicking UI.
- Produce structured pass/fail lines in KAG logs.
- Keep optional visual/manual scenarios for UI and pathing edge cases.

The first target is the AI builder wood harvesting flow, selected-tree filtering, barrier/safety checks, tent delivery, and pathing recovery.

The test setup should also produce a structured event timeline. Every relevant player command, test harness action, and AI builder state/target change should be logged so failures can be analyzed after the run without watching the game live.

## Recommended Architecture

Use three layers:

1. **Script-driven integration harness**

   A KAG rules script creates test fixtures, starts the AI behavior by sending commands or setting blob state, and watches outcomes. This should be the primary automated test path.

2. **Scenario maps**

   Small deterministic maps define broad terrain shapes: flat ground, walls, cliffs, red-barrier split, unreachable trees, enclosed safe zones, and enemy threat zones. Maps should be minimal and named by behavior under test.

3. **Optional UI/manual harness**

   UI behavior, such as the `X` menu `Select trees` control, should have a manual scenario and a lower-level script test. The automated test should directly set selected tree flags or send the same command that UI sends, because GUI automation in KAG is fragile.

4. **Structured event logging**

   A low-noise event logger records every meaningful command or sequence step performed by players, the test harness, and AI builders. The same logger should be useful during normal manual playtesting and automated tests.

## New Files To Add

Proposed files:

- `Rules/AIBTest/gamemode.cfg`
- `Rules/AIBTest/mapcycle.cfg`
- `Rules/AIBTest/aibtest_mapcycle.cfg`
- `Rules/AIBTest/aibtest_team1.cfg`
- `Rules/AIBTest/aibtest_team2.cfg`
- `Scripts/AIBTestRunner.as`
- `Scripts/AIBTestAssertions.as`
- `Scripts/AIBTestScenarios.as`
- `Scripts/AIBTestEventLog.as`
- `Maps/AIBTest/aib_flat_harvest.png`
- `Maps/AIBTest/aib_tree_selection.png`
- `Maps/AIBTest/aib_barrier_access.png`
- `Maps/AIBTest/aib_safety_enemies.png`
- `Maps/AIBTest/aib_pathing_obstacles.png`
- `Tools/run_aib_tests.ps1`
- `Tools/parse_aib_test_log.ps1`

The test gamemode should include only the scripts needed to run a local deterministic test. Avoid full CTF voting, map vote, scoreboard, AFK, and unrelated scripts unless they are required for the tested behavior.

## Test Gamemode

`Rules/AIBTest/gamemode.cfg` should load:

- Basic KAG/game scripts needed for blobs, map, teams, and rules.
- `RedBarrier.as` if barrier behavior is under test.
- `CustomRenderer.as` only in UI/manual scenarios.
- `AIBTestRunner.as` last, so it can observe all created objects.

Keep settings deterministic:

```ini
gamemode_name = AIBTest
daycycle_speed = 0
daycycle_start = 0.5
autoassign_teams = no
auto_bots = no
playerrespawn_seconds = 1.0
restartmap_onlastplayer_disconnect = no
mirrormap = no
```

The mapcycle should contain only AIB test maps, one per run unless the runner advances scenarios itself. Use unique filenames such as `aibtest_mapcycle.cfg`, `aibtest_team1.cfg`, and `aibtest_team2.cfg` for automated launches; KAG can collide on common basenames like `mapcycle.cfg`, `team1.cfg`, and `team2.cfg` when a mod contains multiple rule folders.

The engine still requires `Rules/<gamemode>/gamemode.cfg`, so `Tools/run_aib_tests.ps1` temporarily disables the mod's CTF `gamemode.cfg` while the headless AIBTest process runs, then restores it in a `finally` block. This avoids the test gamemode being resolved as the mod's CTF override without touching any base-game file.

## Scenario Map Strategy

Use small maps and script-created blobs. Do not encode every entity in pixels if a script can create it more clearly.

Map responsibilities:

- Terrain topology.
- Solid barriers, cliffs, pits, and walls.
- Enough ground to let KAG pathing behave naturally.

Script fixture responsibilities:

- Spawn `tent`, `aibuilder`, `tree_pine` or current tree blobs, `log`, `mat_wood`, `knight`, `archer`.
- Set teams.
- Set positions.
- Mark selected trees.
- Start harvesting.
- Check assertions.

This split makes maps stable and easy to inspect while keeping entity setup readable in script code.

Suggested maps:

- `aib_flat_harvest.png`: flat ground, team tent, several nearby trees.
- `aib_tree_selection.png`: flat ground, one selected tree near tent, one unselected tree closer to builder, one selected tree farther away.
- `aib_barrier_access.png`: flat ground split by red barrier area, trees on both sides.
- `aib_safety_enemies.png`: tree near enemy with direct line, tree behind a 10-block vertical wall, tree in open safe area.
- `aib_pathing_obstacles.png`: trees behind low walls, ladders, narrow tunnels, ledges, and partial obstructions.

## Script-Driven Player Sequence

The user-facing sequence is:

1. build AI workshop
2. buy AI workshop
3. buy AI builder
4. drop AI builder to the ground
5. launch harvest wood
6. select some trees
7. check selected-tree impact

For automation, do not start with GUI clicks. Model this sequence through equivalent game state:

- Spawn a same-team `tent`.
- Spawn an `aibuilder` at a known location.
- Optionally spawn `aibuildershop` for workshop tests, but skip it for AI behavior tests.
- Trigger harvest by sending the AI builder's `"ai harvest wood"` command or setting the same state fields that command sets:
  - `"ai builder state" = find_tree`
  - `"ai builder target" = 0`
  - `"ai builder destination" = Vec2f_zero`
- Trigger selected trees by either:
  - sending `CustomRenderer.as` command `"aibuilderToggleTreeSelection"` with a rectangle, or
  - directly setting tree bool/tag `"aibuilder selected tree"` in the test fixture.

Keep separate tests for the shop/workshop purchase flow. AI harvesting should not fail just because shop UI changed.

## Test Runner Design

`AIBTestRunner.as` should be a rules script with a small state machine:

- `setup`
- `start`
- `wait`
- `assert`
- `cleanup`
- `done`

Each scenario should implement:

```angelscript
void SetupScenario(CRules@ rules);
void StartScenario(CRules@ rules);
bool PollScenario(CRules@ rules);
bool AssertScenario(CRules@ rules, string &out failure);
void CleanupScenario(CRules@ rules);
```

The runner should print structured lines:

```text
[AIBTEST] START flat_harvest
[AIBTEST] PASS flat_harvest ticks=812 wood_at_tent=120
[AIBTEST] FAIL tree_selection reason=builder targeted unselected tree id=42
[AIBTEST] DONE passed=7 failed=1
```

The parser script should treat any `[AIBTEST] FAIL` as failed and return nonzero.

## Structured Event Logging

Add a shared event logging helper, either in `Rules/AIBTest/Scripts/AIBTestEventLog.as` for tests or in a reusable script if it becomes useful outside the test gamemode.

The event logger should print single-line, machine-parseable records:

```text
[AIBEVT] t=1234 seq=17 source=test action=start_harvest actor=aibuilder:88 state=find_tree pos=56,192 target=none note=flat_harvest
[AIBEVT] t=1290 seq=18 source=ai action=state actor=aibuilder:88 from=find_tree to=chop_tree target=tree:104 reason=tree target acquired
[AIBEVT] t=1442 seq=19 source=player action=command actor=player:7 command=select_trees rect=20,22,30,28
```

Recommended fields:

- `t`: `getGameTime()`
- `seq`: monotonically increasing event id stored on `CRules`
- `scenario`: current test scenario name, if any
- `source`: `test`, `player`, `ai`, `ui`, `shop`, or `rules`
- `action`: short verb such as `spawn`, `command`, `state`, `target`, `pickup`, `drop`, `select_tree`, `reject_resource`, `path_recover`
- `actor`: blob/player type and netid
- `team`: actor team when applicable
- `pos`: tile or world position, consistently formatted
- `state`: current AI builder state when applicable
- `target`: target blob type and netid when applicable
- `reason`: state transition or rejection reason

Keep event lines compact. They are meant for post-run analysis, not human prose.

### What To Log

Player or UI commands:

- Player presses/uses AI builder `Harvest wood`.
- Player opens tree selection mode.
- Player confirms tree selection mode.
- Player sends/toggles selected tree rectangle.
- Player buys AI builder from shop.
- Player builds or places AI workshop if that flow is under test.

Test harness commands:

- Scenario start/end.
- Every fixture spawn with blob name, team, netid, and position.
- Direct state manipulation, such as forcing `find_tree` or `return_wood`.
- Direct selected-tree setup.
- Enemy spawn/move actions used to trigger safety or fear behavior.
- Resource injection into AI inventory.

AI builder events:

- State transitions.
- Target acquisition and target loss.
- Resource rejection due to barrier zone, unsafe enemy zone, or overseer selection.
- Path recovery decisions: repath, direct movement fallback, obstruction threshold timeout.
- Tree/log hit events at a throttled rate or only when target changes.
- Resource pickup.
- Resource delivery/drop near tent.
- No-home fallback.
- Knight flee start, continued flee, and end condition if implemented later.

Shop/workshop events:

- Shop item requested.
- `aibuilder` blob created.
- Team assignment and final spawn/drop position.

### Event Logging Controls

Do not make high-volume logging unconditional in production CTF. Add separate constants:

```angelscript
const bool AIB_TEST_EVENT_LOG = true;   // enabled in AIBTest gamemode
const bool AIB_RUNTIME_EVENT_LOG = false; // default false in normal gameplay
```

In the test gamemode, event logging should be on by default. In normal gameplay, it should be disabled unless the developer explicitly enables it for a debugging run.

For noisy actions, log only meaningful changes:

- State changes, not every tick.
- Target changes, not every path update.
- Resource rejection once per candidate/short interval, not every frame forever.
- Path obstruction when threshold crosses a boundary, not every obstructed tick.

### Replay/Diagnosis Use

The event log should let a future agent answer:

- What sequence did the test harness or player execute?
- Which tree did the AI choose, and why?
- Did selected-tree filtering apply?
- Did the AI reject a resource because of barrier/safety/selection?
- Did it get stuck in pathing, or did the state machine stop advancing?
- Did resources reach the tent or stay carried/in inventory?

The parser can later reconstruct per-AI timelines by grouping `[AIBEVT]` lines by `actor=aibuilder:<id>`.

## Assertions To Implement

Core helpers:

- Find nearest same-team `tent`.
- Count `mat_*` resources near tent.
- Count resources carried by AI or in AI inventory.
- Read AI state name from `"ai builder state"`.
- Read target blob from `"ai builder target"`.
- Check whether target tree has `"aibuilder selected tree"`.
- Check max distance from expected path region.
- Check if AI has been stuck in the same state too long.
- Check if a resource was ignored because barrier/safety should reject it.

Use tick timeouts for every scenario. A hanging AI should fail quickly with useful state:

```text
[AIBTEST] FAIL flat_harvest reason=timeout state=chop_log target=log target_dist=18 obstruction=21 carried=none inv_wood=0
```

## Initial Test Scenarios

### 1. Flat Harvest Delivers To Tent

Fixture:

- Team 0 tent at `x=40, y=ground`.
- AI builder at `x=56`.
- Two trees at `x=90` and `x=130`.

Action:

- Start harvest.

Pass:

- AI reaches `return_wood`.
- At least one `mat_wood` stack appears within 3 tiles of tent.
- AI transitions back to `find_tree` after delivery.
- AI does not drop `mat_wood` away from tent.

### 2. Full Inventory Returns To Tent

Fixture:

- Team 0 tent.
- AI builder with inventory containing `mat_wood`.
- Optional non-resource item to prove unrelated inventory does not drive the loop.

Action:

- Start from any non-return state.

Pass:

- AI switches to `return_wood`.
- All `mat_*` resources are dropped near tent.
- AI does not repeatedly enter `return_wood` after resources are gone.

### 3. Selected Trees Override Distance

Fixture:

- Tent.
- AI builder.
- Unselected tree close to builder.
- Selected tree farther away.

Action:

- Set selected bool/tag on farther tree.
- Start harvest.

Pass:

- AI target is selected tree.
- Close unselected tree is not chopped while any selected tree exists.

### 4. No Selected Trees Means Normal Priority

Fixture:

- Tent.
- Multiple unselected trees.

Action:

- Start harvest.

Pass:

- AI chooses the best tree by current score: close to tent, with builder distance as tie-breaker.

### 5. Barrier Rejects Inaccessible Tree

Fixture:

- Barrier active through `RedBarrier.as`.
- AI and tent on one side.
- One tree on AI side.
- One tree across barrier.

Action:

- Start harvest.

Pass:

- AI never targets the across-barrier tree while barrier is active.
- AI targets and harvests the same-side tree.

### 6. Enemy Safety Rejects Open Threat

Fixture:

- Tree A within 10 tiles of enemy knight with clear ray.
- Tree B within 10 tiles of enemy knight but behind a 10-block vertical wall.
- Tree C outside enemy radius.

Action:

- Start harvest.

Pass:

- Tree A is ignored.
- Tree B may be selected because wall blocks direct path.
- Tree C may be selected.

### 7. Knight Fear Interrupts Work

Fixture:

- AI chopping or walking toward a tree.
- Enemy knight placed within 10 tiles with clear ray.

Action:

- Spawn/move knight into range after harvest starts.

Pass:

- AI clears target/path or visibly changes movement away from knight.
- AI does not keep walking toward the knight while the direct path exists.

### 8. Wall Blocks Knight Fear

Fixture:

- AI and enemy knight within 10 tiles.
- Solid 10-block vertical wall between them.

Action:

- Start harvest.

Pass:

- AI does not trigger flee behavior.
- AI continues harvesting an accessible safe resource.

### 9. Pathing Obstacle Recovery

Fixture:

- AI, tent, and tree separated by low obstacle or ledge.

Action:

- Start harvest.

Pass:

- AI reaches tree within timeout.
- Obstruction threshold does not stay high forever.
- AI eventually delivers wood to tent.

### 10. No Home Does Not Drop Locally

Fixture:

- AI builder with `mat_wood`.
- No same-team `tent` or `hall`.

Action:

- Force `return_wood`.

Pass:

- No `mat_*` resource appears at AI position due to local drop.
- AI enters idle with resources retained.
- Debug mode logs `no team home found; cannot drop resources`.

## UI Test Scope

The custom `Select trees` button should have two levels of tests.

Automated script-level test:

- Send the same rectangle command that UI sends.
- Assert trees inside the rectangle toggle selected bool/tag.
- Send the same rectangle again.
- Assert those trees are unselected.

Manual visual test:

- Load `aib_tree_selection.png`.
- Press `X`.
- Click `Select trees`.
- Drag over a tree cluster.
- Confirm markers appear.
- Click `Confirm trees selection`.
- Start AI harvest and verify the selected tree is chosen.

Avoid full mouse automation unless absolutely necessary. KAG GUI input is not stable enough to be the first line of automated coverage.

## Running Tests

`Tools/run_aib_tests.ps1` should:

1. Locate KAG root from the current mod path.
2. Clear or record current newest log filename.
3. Launch KAG with the `AIBTest` gamemode and a chosen test map.
4. Wait until `[AIBTEST] DONE` appears in the newest console log.
5. Run `Tools/parse_aib_test_log.ps1`.
6. Exit nonzero on failure.

The user explicitly approved non-visible automated test runs. `Tools/run_aib_tests.ps1` launches KAG through the test autostart and stops the process after `[AIBTEST] DONE` or after timeout. Use visible launches only for manual gameplay debugging.

Possible command shape to research and verify:

```powershell
Start-Process -FilePath "$KagRoot\KAG.exe" -WorkingDirectory $KagRoot -ArgumentList @(
  "autostart",
  "Scripts/aib_test_autostart.as"
)
```

The exact KAG startup arguments should be verified against local `localhost.as`, `autostart.as`, and KAGTools behavior before implementing the runner.

## Log Parsing

`parse_aib_test_log.ps1` should extract:

- all `[AIBTEST] START`
- all `[AIBTEST] PASS`
- all `[AIBTEST] FAIL`
- final `[AIBTEST] DONE`
- all `[AIBEVT]` lines for failed scenarios
- AngelScript compile errors from mod paths
- runtime null exceptions from mod paths

Failure rules:

- Any `[AIBTEST] FAIL` fails.
- Missing `[AIBTEST] DONE` fails.
- Any `ERROR ../Mods/GuiftsDynamicBlueprint_vDev` fails.
- Any `Null pointer access` involving mod scripts fails.

Output should be concise:

```text
AIB tests failed: 1 failed, 6 passed
- tree_selection: builder targeted unselected tree id=42
Recent event timeline:
  [AIBEVT] t=1201 seq=42 source=test action=select_tree actor=tree:104 selected=true
  [AIBEVT] t=1260 seq=44 source=ai action=target actor=aibuilder:88 target=tree:101 reason=tree target acquired
Fresh log: Logs/console-26-05-10-04-20-11.txt
```

## Implementation Order

1. Add `Rules/AIBTest` with a minimal gamemode and runner script.
2. Implement script-only scenarios on an existing simple map first.
3. Add `[AIBTEST]` structured pass/fail logging.
4. Add `[AIBEVT]` event logging for harness actions, player-equivalent commands, and AI builder state/target changes.
5. Add the log parser with failed-scenario timeline extraction.
6. Add flat harvest and selected-tree scenarios.
7. Add barrier and safety scenarios.
8. Add pathing maps and obstacle scenarios.
9. Add manual UI scenario.
10. Add a single command or script that runs the full suite.

This order gets immediate value from compile/run/assert automation before spending time on custom maps and UI automation.

## Risks And Mitigations

- **KAG startup arguments may be inconsistent.**
  Verify with the local install and document the exact command in this file after implementation.

- **Map PNG color/entity encoding is easy to get wrong.**
  Prefer simple terrain maps plus script-spawned blobs. Only encode terrain in PNG.

- **AI timing can vary between machines.**
  Assert eventual state and positions with generous tick timeouts, not exact tick counts.

- **UI automation is brittle.**
  Test UI commands at script level first. Keep manual visual checks for marker rendering and menu feel.

- **Debug logging can affect performance.**
  Keep `AIB_DEBUG` false by default. The test harness should print its own minimal `[AIBTEST]` lines.

- **Tests may accidentally modify production CTF behavior.**
  Keep test scripts under `Rules/AIBTest` and only include them in the AIB test gamemode.

## Success Criteria

The testing setup is useful when a developer can run one command, wait for KAG to finish the scenario suite, and get:

- a pass/fail summary
- exact failing scenario name
- AI state, target, position, inventory/resource counts, and timeout reason on failure
- a fresh log path for deeper debugging

At that point, manual testing should only be needed for visual UI polish and exploratory pathing cases, not for every AI behavior regression.
