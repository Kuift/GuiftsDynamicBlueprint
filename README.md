# CONTROLS :

Project direction: `ai_blueprint_direction.md`. Detailed deterministic gym architecture and current execution queue: `kag_gym.md`.

## Blueprint toolbar
- The blueprint toolbar is visible for players who can use blueprint controls.
- Paint: click the Paint tool, then left-click tiles to add the currently selected blueprint block.
- Erase: click the Erase tool, then left-click blueprint tiles to remove them.
- Select: click the Select tool, then drag a rectangle to define the save/selection area.
- Save: saves the current selected tile rectangle as a blueprint.
- Load: opens or closes the blueprint browser.
- Rotate: rotates the active block or placement preview.
- Flip: flips the loaded blueprint preview before placement.
- Hide/Show: toggles blueprint rendering.

## Legacy blueprint shortcuts
- Hold Left Control or Right Control to use the older live-edit cursor.
- While holding Control, left-click adds a block and right-click removes a block.
- Press H to hide or show blueprints.
- Press I and P to set the two selection corners, then press O to save that rectangle.
- Press the mouse-wheel button and drag to set the selection rectangle.
- Press L or hold X to open the blueprint browser.
- When playing as a builder, use the usual build menu to choose the block to place.
- When playing as archer or knight, press R and U to cycle through blueprint blocks.
- Press J to cycle the render window size.
- Press K to cycle rendering relative to camera or cursor.

## Overseer view
- Press E at a same-team AI Builder Workshop and click **Become overseer**. The workshop only seats one overseer at a time.
- Your character remains seated and locked into the workshop while using overseer view. Press E again to leave the chair and exit the view.
- In overseer view, the camera is detached from the player and is not clamped to the map bounds.
- Move the overseer camera with W, A, S, and D.
- Hold Shift while moving to pan faster.
- Drag with left-click to select same-team AI builders or Autobuilder orbs. A short click near one worker selects it.
- Right-click or Cancel clears the current AI builder selection.
- After selecting AI builders, use the order buttons:
    - Harvest wood
    - Mine stone
    - Build blueprint
- Orders are validated on the server. A player can only order same-team AI builders unless they are a spectator/admin team player.
- Autobuilder orbs accept only **Build blueprint**; wood and stone orders remain runner-builder jobs.

## Moderator commands
- As a moderator, enable or disable live blueprint editing using the "!bp_edit_toggle" command.
- As a moderator, enable or disable overseer restrictions using the "!bp_overseer_toggle" command.
    - When overseer restrictions are enabled and at least one overseer is assigned, only selected overseers can place/edit blueprints and use overseer orders.
    - Use "!bp_overseer_set Username" to assign an overseer.
    - Use "!bp_overseer_none" to remove all assigned overseers.

## AI builder storage and mining

- Base storage workshops are placed only after a nearby search on both sides of the home finds a clear 5x3 volume, full five-column ground support, a grounded approach, and clearance from no-build sectors, barriers, buildings, and blocking blobs. Same-team homes and flags receive at least six tiles of edge clearance. The AI revalidates before spawning and cools down after a failed search.
- Stone miners prefer a reusable low-dirt, two-wide shaft/cross route with a clear surface approach and direct shaft movement. They do not dig off-route dirt, and reject bedrock or castle-blocked routes.
- A stone miner mines a line-of-sight gold cluster and returns the gold to its base crate immediately when that visible cluster is exhausted. Mirrored corner recovery handles both upper-left and upper-right overhang traps.

## Autobuilder strategy-test orb

- The AI Builder Workshop can deploy a free Autobuilder orb. It flies directly through walls and blobs, has infinite blueprint wood/stone, and remains blueprint-only.
- It uses the same support generation, reservations, repairs, obstruction clearing, workshops, and completion accounting as the normal AI builder; it does not bypass the director with raw tile writes.
- Each orb places at most one successful blueprint block per second. The workshop's gold button upgrades team-wide flight speed for 50 gold per level (4, 6, 8, then 12 pixels per tick); upgrades reset each round and never increase placement cadence.
- While an orb is active, director planning ignores runner-only approach checks and current material shortages. Director-owned runner builders receive no new construction role, keeping strategy execution isolated from ordinary pathing.

## Strategic AI blueprint director

- The server-side director observes each team's home, frontline, terrain, combat mix, recent pressure, stored resources, and AI builders.
- It evaluates procedural gatehouse, tower, emergency barrier, archer perch, and access-route candidates. Invalid candidates are rejected before publication.
- Human blueprints and AI blueprints use separate layers. Human tiles always win merge conflicts and autonomous replanning never edits the human layer.
- AI plans retain an immutable desired layer and task history after builders consume the live work grid.
- Construction is phased: foundation/backwalls, access pieces, then shell. Tasks are reserved per builder so two builders do not select the same tile.
- Doors and platforms are supported build targets and material collection follows the actual remaining plan cost.

Team members can select a director mode with `!aib_strategy off`, `!aib_strategy suggest`, or `!aib_strategy auto`. CTF defaults to `auto`, so a team plan is selected and activated without a player drawing it or entering a command. The deterministic AIB test mode defaults to `off` and opts in only in director-specific scenarios.

The director can publish a plan before the team owns an AI builder. In CTF auto mode, a team with a home, an active non-empty plan, and no existing builder can receive one free bootstrap worker per round. The server searches both sides of the home for a grounded, clear, barrier-safe spawn connected to the home by a bounded terrain route, so a locally valid sealed cave cannot win. It retries later when none is safe, assigns builders deterministically, and does not respawn the bootstrap worker after death. This is a guarded server spawn, not a workshop purchase, so its economy balance and new connectivity filter still need live CTF acceptance.

Suggestion mode renders the proposed plan and its score reasons without assigning builders. Auto mode publishes the work layer and assigns wood, stone, and construction jobs according to current shortages.

For paired in-engine pressure trials on a fresh map, moderators can run `!aib_wave <seed> control [knight|archer|bomb|mixed]` and `!aib_wave <seed> plan [knight|archer|bomb|mixed]`. Use the same seed and scenario on separately restarted maps. Strategy event logging records breach timing, crossings, deaths, flag approaches, completion and damage timing, structure lifetime, builder travel/idle time, reservation conflicts, replans, route preservation, and estimated absorbed cost.

After collecting both variants, compare the result logs with `Tools/compare_aib_wave_results.ps1 -LogPath <log paths>`. Records identify fixture id/version, team, left/right side, scenario, seed, canonical pre-warm-up fingerprint, and post-warm-up measurement fingerprint. Fixture version 3 uses one shared `w1` world manifest at both boundaries, including terrain, no-build coverage, blobs/inventories, barriers, blueprint layers, and task state. Pairing occurs only inside that complete fixture/team identity, requires exactly one control and one plan, and defaults to at least three distinct seeds per cohort. All wave types vary deterministic spawn cadence and formation with the seed. No live paired dataset is currently recorded, and the new AngelScript identity/fingerprint hooks still need a KAG runtime compile. Regression checks are `Tools/test_compare_aib_wave_results.ps1`, `Tools/test_aib_wave_contract.ps1`, and `Tools/test_aib_world_manifest_contract.ps1`.

Generate the required two-side, four-scenario, three-seed control/plan collection manifest with `Tools/new_aib_wave_matrix.ps1 -FixtureId <id> -OutputPath <matrix.ndjson>`. The default is exactly 48 ordered trials / 24 pairs, and every record requires a fresh canonical reset. This manifest prevents omissions and duplicate sampling; it does not perform the KAG reset or run the trial itself. Its regression is `Tools/test_new_aib_wave_matrix.ps1`.

The lightweight seeded evaluator is available at `Tools/aib_strategy_abstract_sim.ps1`; its regression check is `Tools/test_aib_strategy_abstract_sim.ps1`.

## AI builder tests

Public CTF runs include server-side, privacy-bounded player action telemetry for later matched-context AI evaluation. It records binary delta frames in memory and flushes compact base64 `[AIBACT]` batches about every ten seconds or 2 KiB; it does not print per-player frames or record usernames, IP addresses, or chat. Schema v3 retains v1/v2 decoding and adds accepted human blueprint/director actions, director-workshop purchases, and production plan/task boundaries through a bounded numeric queue. Queue overflow emits an explicit loss record. Moderators can use `!aib_telemetry on|off|status`. Export batches with `Tools/parse_aib_player_actions.ps1 -LogPath <console logs> -OutputPath <actions.ndjson>`, then derive raw task episodes with `Tools/summarize_aib_player_episodes.ps1 -InputPath <actions.ndjson> -OutputPath <episodes.ndjson>`. Summaries preserve explicit versus inferred attribution, accepted player-boundary counts, raw cost components, and a privacy-safe context key. Compare baseline human/AI cohorts with `Tools/compare_aib_task_episodes.ps1`; it requires three episodes per matched context by default and only enforces success/cost/death gates with `-RequireQualityGates`. The v3 hooks still require a KAG runtime compile/behavior check; generic hit and pickup/drop boundaries remain. See `kag_gym.md` for the evaluation architecture and `KAG_ENGINE_QUIRKS.md` before diagnosing engine behavior.

The passive AI monitor emits at most one compact numeric `[AIBGYM]` record per builder when it first latches a failure in public CTF. It then emits one binary/base64 `[AIBGYMW]` diagnostic window containing up to 30 pre-failure and 12 post-failure samples at five-tick spacing. Neither format contains player identity or free-form text. Export them with `Tools/parse_aib_gym_failures.ps1 -LogPath <console logs> -OutputPath <failures.ndjson>` and `Tools/parse_aib_gym_windows.ps1 -LogPath <console logs> -OutputPath <windows.ndjson>`. This preserves the first causal movement/intent/target/resource/reservation/build-retry failure and its trajectory without per-tick log strings.

For an interactive director check, a moderator on a playing team can use `!aib_director_test`. It switches that team to automatic strategy and automatically creates one same-team AI builder at the moderator only when none exists. Automated coverage should use `strategic_auto_director_heartbeat_end_to_end`, which starts without a worker and verifies that production bootstrap provisioning creates and assigns one safely.

The AIBTest suite contains 63 scenarios. A complete successful run reports:

```text
AIB tests passed: 63 passed, 0 failed
```

The game log must also contain the matching `[AIBTEST] DONE` marker; the launcher no longer accepts matching START/PASS counts alone. Run the full suite with `Tools/run_aib_tests.ps1`, one case with `-Scenario <name>`, or an inclusive range with `-StartScenario <name> -EndScenario <name>`. The default opens a visible `RunLocalhost` session and leaves KAG running; add `-StopAfterRun` only when desired. Intermediate fixtures remain visible for 15 ticks before cleanup, while the final selected fixture is retained indefinitely after `DONE` for human inspection. A lack of post-START log/simulation progress produces a distinct stale-run diagnostic. `AIBTestCamera.as` intends to follow the active fixture, but displayed follow and manual movement are currently unreliable; `CAMERA_TARGET`/`CAMERA_VIEW` logs must not be treated as proof of what the player sees.

KAG can still stop advancing during visible localhost runs. The targeted log `console-26-07-09-22-06-03.txt` passed scenarios 42-46 with `DONE`; `console-26-07-10-17-32-06.txt` passed the physical repair scenario with `DONE`. These are focused results, not a full 63-scenario pass, and camera records are not visual verification. The newest canonical-reset, representative planner, damaged-front, full selected-plan completion, sealed-bootstrap-pocket, no-build fallback, and occupied-base fallback fixtures are statically contracted but have not been run.
##### Thanks to all kag's modder who answered my questions and big thanks to Numan and Monkey_Feats.
##### Thanks to Epsilon for the inventory code

# INSTALLATION FOR HOST
Enable this mod and add `CustomRenderer.as` to the applicable gamemode script list through this mod's override under `Rules`. Do not edit `King Arthur's Gold/Base`; files in this mod override matching base-game files.

## TODO:
### Live editor todo:
* make selection actually select the right area
* make it possible to rotate 2d sprite larger than 8x8
* make blob stop attacking when in edit mode
* make spectator camera stop moving with mouse when editing
* make editing mode toggleable instead of having to hold
* fix rotation bug : get the direction of held object directly.
* add saw
* add trampoline
* add catapult
* add ballista
* add custom shop
* ability to place all the relevant block at the blueprint location

### CTF improvement todo:
- f1 tips
- remove block once it's placed
    - also add a command to disable that
- Make the data being sent only to the right team
- make a voting system on blueprints
- make chat command to clear all blueprints
- configurable delay between the placement of blueprint to prevent spam

### Overall improvement todo:
- cleanup code, remove the global variable, make the project oop based
    - make a new inventory system and put all the blocks in there.
    - make a make object, make it so that you can easily iterate through it
- Optimisation : Make the inventory GUI part of a mesh and maybe use only 1 render function.
- Optimisation : Create multiple vertex array as chunk and render only the chunk near the camera.
- make a way organize all your blueprint in menu/improve menu
    - a config image that tell you which blueprint number is in which menu
- dynamics notes/implement the ping mod
- veracity : block on flag shouldn't be allowed 
- optimise even more blueprint data sharing
    - getLocalPlayer().getNetworkID() == netID this may not work as you think it does : even when netid != localnetid, code is being executed.
- Wait for engine fix for your save system to completely work -> remind the engine devs about it

### Blueprint promotion todo:
- Overseer idea
    - an addon to existing gamemode that add a 30 to 60 seconds delay before the beginning of a match to plan blueprints building
    - an gamemode in which there is one overseer and the other ppl have to build what the overseer want otherwise they lose
    - kind of an addon/gamemode where there's one overseer per team that tell the team what to do

## Code structure
