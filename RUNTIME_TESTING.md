# Runtime testing policy

Current entry point: [START_HERE.md](START_HERE.md). Runtime remains paused under
[GOAL_HANDOFF.md](GOAL_HANDOFF.md); the commands below are reference instructions,
not authorization to resume. The first resumed validation is fresh visible
normal CTF on official `Ferrezinhre_Totally_Transcendent`. Older references below
to the "current full suite" mean the historical 65-scenario baseline; no complete
78-scenario pass exists for this checkpoint.

AngelScript behavior and compilation are validated inside a visible KAG process. The local TCPR bridge carries compiler diagnostics, authoritative scenario acknowledgements, progress metrics, and final verdicts. Do not recreate source-text/regex “contract tests” as substitutes for loading and exercising the code in KAG.

`AIB_TEST_AUDIT.md` records the claim strength and runtime status of every current scenario. Keep focused passes, source-inspected assertions, and unresolved weak fixtures distinct.

Use the persistent visible loop for focused work:

```powershell
& .\research\tools\Invoke-PersistentAIBTest.ps1 -Action Start -Scenario <name> -TimeoutSeconds 120
& .\research\tools\Invoke-PersistentAIBTest.ps1 -Action Run -Scenario <name> -TimeoutSeconds 120
& .\research\tools\Invoke-PersistentAIBTest.ps1 -Action Stop
```

The first command starts visible KAG. `Run` rebuilds/restarts rules in the same owned process and reports in-game compiler errors through TCPR. Always stop the owned process after the evidence run and restore the required CTF handoff. A failed start/run already performs that cleanup.

A cold `Start` can execute its selected scenario before the later authoritative TCPR hot request. For a terrain-mutating physical case, start the persistent process on a non-terrain-mutating bootstrap such as `strategic_replan_hysteresis`, then use `Run` once for the target case and close the process. Starting directly on the physical case can mutate the map before canonical capture and turn the subsequent hot verdict into a setup hash mismatch.

The AIBTest runner now settles every transition, including initial cold/hot startup, before the next setup. It requires the exact canonical tile hash once captured, no remaining tagged fixture/bootstrap handles (including handles already tagged `dead`), and no temporary no-build sectors; it reissues cleanup at most eight times and then lets the canonical guard fail closed. Test-owned pressure, recent-attack, heat, and previous-frontline history is reset with the synthetic world. Do not replace this with a fixed one-tick delay or weaken the hash. A physical cold preflight can still mutate terrain before the first capture, so the non-mutating bootstrap rule above remains required.

The last complete regression baseline is `../../Logs/console-26-07-18-16-07-39.txt`: that older visible runner selected all 65 then-current scenarios and emitted `[AIBTEST] DONE passed=65 failed=0`. The source now registers 78 scenarios, so this is not a complete-current-source claim. Use `Tools/run_aib_tests.ps1 -TimeoutSeconds 900 -StopAfterRun` when the complete physical suite needs more than the default 180-second wall-clock budget; the independent 25-second stale simulation/log diagnostic remains active.

Chapter 1 evidence is intentionally focused. `console-26-07-20-07-05-25.txt` contains the original individual PASS records for guide cases 65–70, while `console-26-07-20-07-33-30.txt` selected only cases 71–76 and ended with `[AIBTEST] DONE passed=6 failed=0`. The affected workshop-site pair independently ended 2/0 in `console-26-07-20-07-33-14.txt`. After the guide-policy correction, cases 65, 67, 68, 70, and 76 passed individually in `console-26-07-20-08-30-22.txt`; the new reservation-contention case 77 passed through visible TCPR as strengthened hot run `68d8e2cd8af1` at tick 8. The player-volume correction then ran only affected guide-prefab cases: cases 65–67 passed with matching `DONE` records in `console-26-07-20-09-03-40.txt`, case 69 passed in `console-26-07-20-09-04-26.txt`, and the separately flushed case 68 passed in `console-26-07-20-09-05-47.txt`. The strengthened case 67 then passed the production-director `friendly_route` rejection of a boxed 1x2 aperture in `console-26-07-20-09-08-54.txt`. The earlier case-68 process exit after a TCPR verdict but before console flush is not cited. Do not combine these records into a synthetic full-suite verdict. The long harvest regression reached a complete 350-wood base-delivery event with no Gym flags in `console-26-07-20-07-26-01.txt`, but its then-current assertion correctly did not pass because all 350 wood had funded the shop and first crate. Later focused attempts with the revised storage fixture stopped advancing mid-log processing and produced no `DONE`; they are inconclusive engine-run stalls, not passes or AI failures.

Map-scoped optimization episodes run in visible CTF with `Scripts/aib_gym_autostart.as`, which loads the first existing map in the real CTF rotation without generated fixture terrain. Arm them through `!aib_gym resources ...` or the equivalent local TCPR rule properties. A 180-second episode emits `resource_collection_180s`; shorter development runs emit `resource_collection_smoke` and are not comparable. See `AIB_GYM_METRICS.md` for field semantics and the exact per-map cohort key.

Local metric collection should give `research/tools/tcpr_send.py` a unique `--transcript` path. Final `[AIBGYMR]` and `[AIBGYMB]` rows use explicit TCPR as well as `print()`, because KAG's console file can stop growing while the simulation and explicit socket channel continue.

For one owned resource episode, use the wrapper so launch, transcript validation, process shutdown, and post-exit handoff restoration are one transaction:

```powershell
& .\research\tools\Invoke-AIBGymResourceRun.ps1 -RunId <unique-id> -Variant control -BuilderCount 1 -Order wood -DurationTicks 5400
& .\research\tools\Invoke-AIBGymResourceRun.ps1 -RunId <unique-id> -Variant candidate -BuilderCount 4 -Order mixed -DurationTicks 5400
```

It refuses to launch over an existing KAG process and never restores `autoconfig.cfg` until its owned visible process is gone. The wrapper requires the authenticated socket to remain live for three seconds before sending the transaction; an accepted socket during early build-4762 startup can otherwise reset before the first benchmark command. Add `-CompilerForwarding` for the first run after an AngelScript edit; identical print/TCPR rows are safe because the comparator deduplicates by run id.

For path/state diagnosis, use `-Variant diagnostic -EventLog`. The switch is deliberately rejected for `control` and `candidate` runs so formatted event traffic cannot contaminate a comparator cohort. Diagnostic runs may use shorter durations and are always labeled `resource_collection_smoke`; retain their event log, failure/window artifacts, and result row as focused evidence only.

For one owned physical gatehouse or protected-workshop episode, use the infrastructure wrapper:

```powershell
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Team 0 -CompilerForwarding
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Metric workshops -Team 1
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Metric gatehouse_breach -Team 0
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Metric workshops_breach -Team 1
```

The default `gatehouse` metric publishes and executes the normal production plan, then emits `[AIBGYMI]` schema 1 only after checking every physical task, plan counters/archive, reservations/work layer, both team doors, and a real friendly passage.

`-Metric workshops` currently emits schema 3 / fixture version 3. It additionally requires the exact same-team knight and archer shops, exact cover cells and supported home entry, every column of the configured enemy wall, a production `BrainPath` route from the exact resource home, stock class-command use by a real connected player holder, and return through the home entry. Current production uses two three-cell enemy-wall columns; historical one-column fixture-v2 rows remain valid only for that older structure. Its total probe budget is 1,200 ticks; retain the independent home-route, class-use, and return timing fields rather than treating that safety bound as a performance measurement.

The opt-in `gatehouse_breach` (fixture v3) and `workshops_breach` (fixture v4) metrics emit schema 4 only after the corresponding complete friendly postconditions. They transfer a real connected player to the opposing CTF team, bind a real enemy builder, and use the existing client-originated `pickaxe` command. A valid row requires live server-observed commands, contact, damage, and either physical entry/crossing or a still-live command stream with a blocker retained through the 900-tick deadline. Workshop fixture-v4 control rows require the original four blockers; candidate rows require all seven blockers in the accepted two-column treatment. The disclosed `server_static_outer_stance_then_bounded_velocity` controller is a benchmark-only workaround for overwritten keys on player-bound runners; it is not human movement or a production AI controller.

Summarize only exact same-schema/map/fixture/team-side/**variant** cohorts with `Tools/summarize_aib_infrastructure_results.ps1`. Use `-MinimumRunsPerCohort 3 -RequireAllPassed` for acceptance. The parser deduplicates repeated print/TCPR copies by run id and fails closed on missing schema-specific physical fields. Schema 1/3 rows remain construction and friendly-access evidence only; never infer enemy breach or combat survival from them. Schema 4 proves only the named builder-pickaxe route, not knight/archer/bomb survival.

For one owned strategy-wave trial, use the visible wave wrapper:

```powershell
& .\research\tools\Invoke-AIBWaveRun.ps1 -RunId <unique-id> -Variant control -Team 0 -Scenario knight -Seed 101
& .\research\tools\Invoke-AIBWaveRun.ps1 -RunId <unique-id> -Variant plan -Team 1 -Scenario bomb -Seed 211 -CompilerForwarding
```

For the canonical 48-trial collection, generate/use the NDJSON manifest and run bounded ordinal chunks. The matrix wrapper launches a fresh visible KAG process for every trial, refuses to overlap another KAG process, validates one unique result, closes its owned process, and restores CTF before advancing:

```powershell
& .\Tools\new_aib_wave_matrix.ps1 -FixtureId map_3142477075_210x66 -OutputPath .\Artifacts\aib_gym\wave_v4_matrix.ndjson
& .\research\tools\Invoke-AIBWaveMatrixRun.ps1 -ManifestPath .\Artifacts\aib_gym\wave_v4_matrix.ndjson -RunPrefix <unique-prefix> -StartOrdinal 1 -EndOrdinal 8
& .\Tools\compare_aib_wave_results.ps1 -LogPath <exact cohort transcript paths> -RequireAcceptanceGates -AsJson
```

Current fixture-v4 driver `grounded_candidate_corridor_v4_exclusive_spawn_outcomes` uses one production worker plus seven attackers at most. It requires deterministic knight/archer/bomb/mixed composition, real arrows and server-created stock bombs, local pressure/attack contact, and a control breach. Plan measurements remain pinned to the exact physical task set captured at wave start even if production publishes a successor plan; plan-id changes increment `replans` only.

Attacker crossing and death are mutually exclusive terminal outcomes keyed by the seven spawn indices. Duplicate `onBlobDie` callbacks, deaths after crossing, and duplicate bomb callbacks are diagnostics, not extra outcomes. The comparator rejects a v4 row unless `crossings + enemy_deaths == outcomes_resolved <= spawned`, bomb detonations do not exceed throws, composition is valid, and all required pressure fields are live. Driver-v3 rows predate this correction and must never be mixed with driver-v4 rows in one cohort.

The final retained collection is `Artifacts/aib_gym/wave_v4_bombsafe_20260718_*.tcpr.txt`: 48 fresh trials / 24 exact pairs, all semantic gates passed. The rejected pre-bomb-retreat left cohort and focused smokes remain diagnostic artifacts only.

Four-worker provisioning is part of the evidence contract. A clear body volume with solid ground is insufficient on real maps: candidates must belong to the resource home's conservative grounded-reachability flood, and the complete separated spawn set is selected by deterministic backtracking. Keep the emitted `SPAWN_SET` line with the result and reject an episode if any stable slot is absent or unproductive because of fixture placement.

Resource episodes are also fail-closed against CTF contamination. Production AI builders cannot pick up flags through the shared collision predicate. The gym independently detects any carried `ctf_flag`, restores that exact flag to its matching base, emits `AIBGYM|CONTAMINATION`, and aborts without a comparable result. Never include an episode in which a resource worker captured or returned a flag.

The reusable-route AIBTest fixture proves route choice, bounded destruction, physical mining, a legal retained-shaft continuation after a strict underground fresh-route rejection, and a physically surfaced abort when continuation is blocked. Its policy-only entry discriminator is removed only after `stone_route_continue`, and the spawn corridor supplies the same non-overlapping body volume as the normal arena. The uniquely tagged castle-blocked abort actor is paused for two complete ticks after its terrain/spawn writes, then resumed; production still owns the actual abort and surface retreat. Earlier same-callback and row-59-solid versions could kill or eject the actor and were fixture failures, not route evidence. Authoritative hot run `86e2ec208e27` and the current full suite both passed the corrected fixture at tick 463 with the abort settle pause/resume, retained continuation, deeper excavation and acquisition, bounded destruction, preserved controls, and physical surfacing. It does not by itself prove sustained CTF throughput or quota-complete deep-shaft delivery. Use a sustained visible CTF diagnostic with EventLog for route/return boundaries and later confirmed delivery, then use three EventLog-off 5,400-tick episodes for any throughput-acceptance claim.

The final retained 2026-07-18 return mechanism keeps the original surface-entry anchor stable while separately updating the last valid underground cross-tunnel corner. That corner is a canonical left-tile origin, so a deep return rejoins the true two-column body center at `anchor.x + tileSize / 2`, not `corner.x`. Explicit `up` ownership applies only below the lower-body band and within 1.5 tiles horizontally; a far rejoin stays horizontal. The worker then centers through the shaft lip, latches wall-plus-up at the topology-qualified handoff, emits `stone_return_exit`, and later stores the carried load. `Artifacts/aib_gym/gloryhill_4b_centered_bounded_corner_diag_20260718.tcpr.txt` ran 3,000 ticks, delivered all 1,608 collected material, kept all four slots productive, and ended with zero deaths and `failure_flags=0`; both stone workers show complete assist/rejoin/wall/surface/exit sequences. The centered-only predecessor still hung for 1,646 ticks, and an above-surface ore gate regressed to 638/638 with flags 33, so neither remains. The diagnostic proves the reproduced routing boundary, not a throughput cohort. Any improvement claim still requires three exact EventLog-off 5,400-tick episodes.

Return progress must also be phase-directional. Before corner rejoin, only reduced distance to the canonical two-column rejoin point resets the watchdog; after rejoin, only reduced vertical error to the saved surface anchor does. Canonical outer-wall samples derive from that anchor instead of the jittering body x coordinate. Exact-fingerprint diagnostics `gloryhill_4b_base_supply_route_diag_20260718` and `gloryhill_4b_return_phase_progress_diag_20260718` reduced the longest completed underground return from 2,655 ticks to 115 while both delivered every collected material and emitted zero monitor flags. Their totals were 1,456 and 1,314, so this proves the controller-lock boundary only. Focused `console-26-07-18-18-41-45.txt` and full-suite `console-26-07-18-18-49-07.txt` passed the static/runtime route assertions; use the latter as the current `65/0` plus `DONE` baseline.

The underground-retarget correction is narrower. The current route fixture evidence is hot run `86e2ec208e27` plus the full-suite tick-463 pass described above, and `033932ab1f1f` passed the mandatory mirrored-corner regression at tick 138 with both complete 36-tick cycles and 90-tick cooldowns. `Artifacts/aib_gym/gloryhill_4b_route_continue_diag_20260718.tcpr.txt` contains real `stone_route_continue`/`stone_route_abort` boundaries, full 1,466-material delivery, zero deaths, and none of the old stuck route signatures. This is outbound-deadlock evidence, not a throughput cohort.

The blueprint home-material fixture must scope conservation to fixture-owned storage and the builder, including its carried attachment. A map-global material total can include unrelated stacks created by earlier fixtures and make an otherwise correct withdrawal/build episode fail. Hot run `59ecbe077a10` and the current full suite passed at tick 193 with both physical blocks, both withdrawals, and exact 70 wood/70 stone conservation.

For quarry changes, require a clear five-by-three volume plus support under all five columns and verify that emitted stone remains on the exact home/storage/supported-quarry boundary. A newly created quarry must also receive its reserved 100-wood fuel batch before the no-tree nursery fallback can spend it. Production now maintains only an already-existing valid local quarry in that branch; it does not create one there. Compile-checked run `5ea361bcd98a` and the final complete suite both passed `wood_builder_builds_and_feeds_quarry_when_stone_unsafe` at tick 27 with `quarry_built=true`, `quarry_fueled=true`, and `fuel=100`; `stone_builder_collects_loose_stone_near_quarry_when_tiles_unsafe` also passed in the full suite.

## What a scenario name may claim

- Target selection or a non-zero destination is intent, not pathing success.
- A few pixels of displacement proves only initial movement. A route test must reach its named boundary or target.
- Stationary chopping, mining, building, and engine wait states are legitimate progress. Observe successful interactions, target health/world mutation, or explicit wait state instead of demanding movement.
- A tree episode is not complete until the tree falls, logs appear, logs are processed, wood is acquired, and the claimed delivery occurs.
- A recovery test must prove the recovery branch occurred and caused the required crossing. Merely reaching the far side by another route is not a pass.
- A delivery test must observe material inside the named destination and conservation where costs are involved. Returning toward the base is not yet delivery.
- A physical-completion test must verify every world object/tile, task state, reservation, work-layer, and archive condition named by the fixture.
- Timeouts must not fail an actor that is still making goal-directed progress. The gym monitor should catch genuine bounded stalls; scenario deadlines are a final safety bound.

## Evidence classes

1. **KAG runtime:** authoritative in-game compile plus a focused physical/state outcome. This is the normal evidence for AngelScript.
2. **Manual/multiplayer runtime:** real process restart, client join, visibility, camera, UI, and team/spectator transport checks that a localhost fixture cannot prove.
3. **Offline tool test:** executes a parser, comparator, generator, or abstract simulator against controlled data. It validates only that offline tool, never KAG behavior.

The retained `Tools/test_*.ps1` files are class 3 tests. Source-inspection contracts were removed on 2026-07-15 because a green regex/source-order check could be mistaken for compiled or behavioral evidence.

## High-value focused runtime cases

| Area | Focused scenario/evidence |
|---|---|
| Full tree episode | `gym_tree_order_harvests_and_delivers_selected_tree` |
| Stone route selection, underground continuation, blocked abort, and physical mining/surface retreat | `stone_route_prefers_reusable_open_corridor` |
| Exposed stone delivery | `stone_order_mines_exposed_stone_and_delivers` |
| Supported recovery ladder | `kag_path_builds_supported_ladder_chain` (`eb3a6c62b0d8` and the current full suite passed the seven-tile fixture at tick 288 with support-before-ladder, chain 3, tile `349,68`, 84 wood, accepted probe, unchanged plug, and physical crossing) |
| Mirrored corner recovery | `stone_corner_escape_from_mirrored_upper_overhangs` |
| Generated blueprint support | `blueprint_builds_generated_backwall_support` |
| Physical repair | `damaged_owned_tile_is_repaired_without_replacing_neighbors` |
| Overflow storage | `full_crate_creates_grounded_overflow_storage` |
| Representative director execution | scenarios 54–64 in `Scripts/AIBTestScenarios.as` |
| Late-join state sync | real mid-match client join; no single-process fixture is sufficient |
| Editor visibility/authority | two teams plus spectator in a real multiplayer session |
| Blueprint disk round trip | save, terminate KAG, restart, reload, and compare the exact footprint |
| Wave identity/fingerprint | fresh canonical control/plan pairs, then `Tools/compare_aib_wave_results.ps1` |

## Paused exact-map continuation

The current 2026-07-20 continuation is intentionally not an AIBTest run. When
the user resumes it, launch a fresh visible normal CTF session on official
`Ferrezinhre_Totally_Transcendent` and inspect the compact protected-workshop
candidate directly. Do not use a custom one-map CTF cycle; temporarily placing
the official map first in the normal full `Rules/CTF/mapcycle.cfg` is acceptable
only if the duplicate is removed immediately after the map loads. Close KAG
after the evidence run and restore the standard handoff configuration.

The retained direct-map baseline is
`../../Logs/console-26-07-20-09-59-19.txt`: planning, provisioning, and
assignment occur at tick 30 and base candidates are on Tent-ground row 73. The
remaining safe rejection is `protected_workshops_compact anchor=52,73` at
flag-base no-build task `39,78`. A future pass must preserve that no-build cell,
both independent 2x2 exits, and both class shops. Do not cite a post-hot-reload
session if `canNodesConnect` null-neighbor exceptions appear; use a fresh
process after strategic/template changes.
