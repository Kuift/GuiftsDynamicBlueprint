# Active KAG Gym optimization handoff

Updated: 2026-07-15

## Status

The user paused this goal so the computer could be shut down. The optimization goal is still active; it is not complete or blocked. KAG was closed after every evidence run, no KAG process remained at handoff, and startup was restored to CTF with a blank mapcycle and all AIBTest scenario selectors blank.

The objective is to improve production AI behavior on existing CTF maps using visible KAG/TCPR evidence, with no more than eight managed AI actors. The requested metrics are:

- one- and four-builder resource collection;
- correct flag infrastructure with a rear/home-side gate;
- protected, physically accessible class workshops;
- friendly versus enemy traversal through completed structures; and
- adversarial builder/base survival.

Do not optimize the mapcycle or pool different map hashes. Keep diagnostics, smoke runs, full cohorts, and AIBTest verdicts distinct.

## Accepted runtime results

All accepted cohorts below use official `8x_Gloryhill`, map hash `3142477075`, dimensions `210x66`.

### Resource collection

- The proposed post-target fallen-log watchdog reduction from 300 to 90 ticks was rejected. Its exact three-versus-three one-builder cohort reduced mean collection from `630.000` to `546.667`. Production retains 300 ticks; the intentional pre-target `find_log` wait is unchanged.
- Bounded vertical-node, ledge, narrow-drop, and mirrored-overhang recovery passed the current one-builder three-versus-three cohort: mean collection `630.000 -> 633.333`, zero deaths, and failure-flagged runs `3 -> 0`.
- The four-builder mixed-resource shaft-return change passed its exact three-versus-three cohort. Mean confirmed delivery rose `942.667 -> 1574.000` (`+66.97%`), accessible-stock mean rose `742.667 -> 1167.333`, and both sides had zero deaths. Each candidate still latched a recoverable motion-stall bit during slow underground return, so this is not failure-free pathing.
- Four-worker positions are selected from a deterministic home-connected grounded flood with full-set backtracking. Loose stone is local/exact-base-scoped. AI builders and Autobuilders cannot pick up CTF flags; the gym also aborts and restores the flag if contamination is ever observed.

### Physical flag gatehouse

`Scripts/AIBInfrastructureBenchmark.as` emits `[AIBGYMI]` schema 1 for `flag_gatehouse_physical`. It publishes a production gatehouse plan and lets a production Autobuilder execute it, then requires all physical tasks, completed counters, zero pending work/reservations, completed archival, healthy rear/front team doors, and a brain-disabled friendly builder probe crossing both gates.

Three independent full executions passed on each side:

| Team/side | Runs | Full physical passes | Mean completion tick | Mean ally traversal |
|---|---:|---:|---:|---:|
| 0 / left | 3 | 3 | 1068.000 | 58.333 ticks |
| 1 / right | 3 | 3 | 1075.667 | 48.333 ticks |

Every retained run built `36/36` tasks (`12` foundation, `13` access, `11` shell), emptied the AI work layer, released reservations, archived complete, and crossed both doors. This is absolute construction and friendly-passage evidence only. It does not prove enemy delay, breach resistance, workshop protection, or combat survival.

The exact retained transcripts are:

- left: `gloryhill_flag_gatehouse_diagnostic_012`, `gloryhill_flag_gatehouse_left_candidate_001`, `gloryhill_flag_gatehouse_left_candidate_002`;
- right: `gloryhill_flag_gatehouse_right_diagnostic_001`, `gloryhill_flag_gatehouse_right_candidate_001`, `gloryhill_flag_gatehouse_right_candidate_002`.

Use `Tools/summarize_aib_infrastructure_results.ps1 -MinimumRunsPerCohort 3 -RequireAllPassed` to reproduce the aggregate.

## Important implementation findings

- The real CTF flag blob name is `ctf_flag`, not `flag`. The old lookup silently selected the tent as the strategic anchor. Runtime planners, world observation, commands, gym code, and fixtures now consistently use `ctf_flag`.
- A valid Gloryhill gatehouse needs terrain-adaptive foundation cells and a dependency-safe phase split. The generator samples the highest shell/landing surface, pays for missing level foundation cells, places the top backing row in the access phase, and tries bounded flag-relative offsets through 22 tiles. The first legal left-side site was 16 tiles toward the enemy.
- A generic jump in the friendly traversal probe climbed the center ladder and produced a false front-exit failure. The level gate-passage probe intentionally uses horizontal movement only.
- KAG build 4762 rejects some arithmetic on `const Vec2f` locals. Keep vectors mutable where operator overload resolution fails; see `KAG_ENGINE_QUIRKS.md`.

## Resume order

1. Add a map-scoped physical metric for protected class workshops. Require the exact same-team workshop class, bounded cover, a route from the selected tent/hall, and a real friendly probe reaching/using it. Do not substitute the existing storage workshop for a class-access verdict.
2. Extend traversal evidence to a real enemy probe and measure delay/breach, while retaining the friendly crossing requirement. Current `[AIBGYMI]` proves only friendly passage.
3. Collect fresh paired adversarial survival cohorts for knight, archer, bomb, and mixed pressure, never exceeding eight managed AI actors. The existing generated wave attackers can stall in Gloryhill's central pit; redesign or choose a valid same-map fixture boundary before treating wave output as combat evidence.
4. Revisit the remaining four-builder slow-return motion-stall windows only after the higher-priority construction/defense metrics above.
5. Run the full 65-scenario AIBTest suite only after focused cases are stable. There is still no current recorded full-suite pass, and visible `RunLocalhost()` has frozen before `START`/`DONE` in several focused attempts.

## Useful commands

```powershell
# One owned visible infrastructure run; the wrapper closes KAG and restores CTF.
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Team 0 -CompilerForwarding

# Reproduce a three-run infrastructure aggregate.
& .\Tools\summarize_aib_infrastructure_results.ps1 -LogPath <six transcript paths> -MinimumRunsPerCohort 3 -RequireAllPassed -AsJson

# Resource cohort comparator and relevant offline regressions.
& .\Tools\test_compare_aib_gym_results.ps1
& .\Tools\test_summarize_aib_infrastructure_results.ps1
& .\Tools\test_parse_aib_gym_failures.ps1
& .\Tools\test_parse_aib_gym_windows.ps1
```

Read `AGENTS.md`, `KAG_ENGINE_QUIRKS.md`, `RUNTIME_TESTING.md`, `AIB_GYM_METRICS.md`, and `kag_gym.md` before resuming runtime work.
