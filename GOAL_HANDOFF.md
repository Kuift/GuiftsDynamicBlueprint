# Active KAG Gym optimization handoff

Updated: 2026-07-20

## Status

The optimization goal is still active; it is not complete or blocked. Protected class-workshop construction, friendly physical access, the stone-door gatehouse treatment, the two-column workshop enemy wall, the 48-trial adversarial survival matrix, the supported-quarry/refined stone-return milestone, and the redesigned recovery-ladder fixture are accepted. The `untitled.png` underground-retarget deadlock is fixed by the bounded continue-or-return policy described below, and the later return-corner routing lock is fixed by centered two-column shaft rejoin plus bounded vertical ownership. This continuation also preserves a live stone-route rejection across same-job delivery, fixes the reproduced unsupported shaft/cross-tunnel handoff loop with directional progress plus a seam-only bound, and fixes a newly isolated stone-return latch/release loop by making progress phase-directional and wall samples topology-stable. On an identical complete Gloryhill fingerprint, the longest completed underground return fell from 2,655 ticks to 115; this is causal routing evidence, not a throughput claim. EventLog confirms that the open `(220,308)` destination is the exact local base `buildershop`; two forced probes reached their selected shop, so a blanket shop-center/siting change is not justified and the original terminal pocket remains an independent open case. The last green complete regression is `../../Logs/console-26-07-18-18-49-07.txt` with `[AIBTEST] DONE passed=65 failed=0`, but the working tree now contains an explicitly unaccepted stone-reentry experiment described immediately below. KAG is closed, no KAG process remains, and startup is CTF with a blank mapcycle and all AIBTest scenario selectors blank.

### 2026-07-20 guide progression and reservation hotfix

- A live `FG_Forelands` CTF session completed `protected_workshops`, then published no new plan during staging and selected legacy `flag_gatehouse`/`archer_perch` work only after play began. Production now uses a hard one-shot Chapter 1 sequence: flag room, frontline tower, protected workshops, home Tunnel, frontline Tunnel, then Quarry/Storage. Legacy gatehouse/perch/access candidates are fixture-only, an invalid early site falls through to the next valid guide stage, a completed plan requests the next heartbeat immediately, and Tunnel/Quarry plans are allowed before stored gold so their shortage can assign a gold-discovering stone miner.
- The guide flag room leaves the full central `ctf_flag` no-build channel clear. Protected workshops now retain the two-cell home entrance and add a separate two-cell reinforced roof hatch with gapped ladders, giving two independent exits without an exposed ground-level enemy door.
- Live CTF also reproduced accessible-blueprint-resource monitor flag `f=128` while builders held reservations during `collect_blueprint_resources`. Reservations now cover active approach/build only, release before material trips or stale/complete targets, and are exclusive across loose/explicit claims. See `KAG_ENGINE_QUIRKS.md` for the causal boundary.
- Only affected cases were run, per user request. Cases 65, 67, 68, 70, and 76 passed individually in `console-26-07-20-08-30-22.txt`; strengthened reservation case 77 passed visible hot run `68d8e2cd8af1` at tick 8. No full 78-scenario pass is claimed, and the unrelated stone-reentry experiment below remains red.

### 2026-07-20 exact-map direct CTF consolidation (paused)

Runtime iteration was stopped at the user's request. Do not launch KAG or AIBTest automatically when resuming. The next validation must be a fresh visible normal-CTF session on official `Ferrezinhre_Totally_Transcendent`, not the AIBTest suite or a custom one-map CTF cycle.

- The original exact-map planning stall was real. `console-26-07-20-09-23-59.txt` shows every candidate for both teams at row `0` with `reason=empty_plan`. This map has a solid top border, so the former first-solid scan mistook its ceiling for ground. `AIBS_FindWalkableSurfaceAt` now requires two open body cells above a solid surface.
- A second exact-map run exposed a distinct vertical error: using the highest walkable terrain put `protected_workshops` at row `51`. Base-scoped protected workshops, home Tunnel, and Quarry/Storage now use `AIBS_GroundBelowPosition` beneath the exact Tent/Hall resource home. Fresh direct CTF runs `console-26-07-20-09-56-34.txt` and `console-26-07-20-09-59-19.txt` generated those base candidates at row `73`, the Tent-level ground, not the shelf.
- The planner no longer validates the entire present/future candidate catalog before choosing anything. Production selection evaluates one Chapter 1 stage at a time and returns the first stage with a legal candidate; collapse keeps a small emergency pool and legacy mode retains its old all-candidate behavior. On both fresh direct runs, tick 30 reached plan publication, one-time provisioning, and assignment. Team 0 published `guide_home_tunnel`; team 1 published `protected_workshops`. This closes the reported planning/assigning freeze, but not the remaining workshop-fit edge below.
- Chapter 1 does call for construction around the flag: `guide_flag_room` is the first ordinary one-shot stage and preserves a task-free channel through the real flag no-build sector. On this exact map the team-0 candidate at `(80,21)` is rejected as `bedrock`, so the hard progression correctly tries later stages instead of waiting forever.
- The protected-workshop template retains two independent exits and evaluates the full player volume: a two-cell vertical home door with an adjacent clear column, plus a two-column/two-row reinforced roof hatch with gapped ladder access. Every route node and phase approach is checked as a 2x2/four-cell body; a 1x2 aperture is invalid.
- A compact protected-workshop variant was added for tight bases. Its 15-cell shell keeps both 5x3 class shops, the two-cell home entrance, the four-cell roof hatch, stone backing, and the two-column enemy wall. It is currently safe but not yet usable at team 0 on this map: `console-26-07-20-09-59-19.txt` rejects anchor `(52,73)` because its optional terrain-leveling home stair reaches flag-base no-build task `(39,78)`. The shell itself remains at Tent row 73. Do not bypass the no-build sector. The next bounded implementation is an adaptive protected-cell-aware home access leg (for example, truncate the stair and use a supported ladder/landing), followed by the existing 2x2 route validator and a fresh direct-map CTF run.
- No full suite was run for this work. The final two launches were fresh normal CTF, and the temporary duplicate used to put the official map first was removed immediately after load. KAG is closed; `autoconfig.cfg` is CTF with a blank cycle and shuffle enabled; the normal CTF rules file is active; the AIBTest selectors are blank; the mapcycle contains its single original `Ferrezinhre_Totally_Transcendent` entry.

### Paused experimental stone-reentry work

Runtime work was paused at the user's request on 2026-07-18 so the computer is free. Do not launch KAG automatically when resuming. The current working tree is **not test-ready**: the prior 65/0 baseline predates the experimental re-entry controller and expanded scenario, and the focused route scenario is currently red.

The delayed forced-supply diagnostic `Artifacts/aib_gym/gloryhill_4b_forced_supply_route_late_diag_20260718.tcpr.txt` did not reproduce the original shop destination. Its production shop was `(252,308)` and the forced worker reached it in 102 ticks. Before that probe, builder 62 exposed a different real lock: after a shallow route selected stone `(104,240)`, it retained surface anchor `(108,271)` and route corner `(104,240)`. It surfaced, later fell back into the same shaft near `(101,320)`, emitted `stone_return_reentry source=surface`, and then tried to rejoin the stale corner above its surface anchor until the gym monitor latched a motion stall. This is the current production bug under investigation.

The working candidate in `AIBuilderBrain.as` marks a shaft re-entry as already corner-rejoined and adopts a currently detected canonical outer wall at the re-entry depth. A tag-gated AIBTest post-behavior hook records the otherwise one-tick transition. The expanded `stone_route_prefers_reusable_open_corridor` scenario first preserves its original physical abort/surface proof, then stages an above-anchor stale corner. The candidate reliably emits `stone_return_reentry_fixture_bypass`, so stale-corner pursuit is removed, but it has **not** physically resurfaced in the added leg and is not accepted.

Rejected/diagnostic fixture attempts:

- Cold runs `console-26-07-18-19-21-03.txt` and `console-26-07-18-19-22-08.txt` reached the bypass but lost the file-log observation channel before a verdict; they are inconclusive.
- Persistent hot runs `c82bbd79df8b`, `84fc0b8d5988`, and `70af87518007` reused the just-surfaced actor after only two ticks. The runner failed to climb and later died; this contaminated the production conclusion with prior wall-climb movement state.
- Persistent hot run `20f08130c780` waited 90 ticks but toggled the same physics body static/dynamic. It passed every original route assertion and recorded the re-entry bypass, yet the added actor never surfaced and ended near `(3177,568)`. The static-body reset is also not valid production evidence.

The next bounded step is fixture-only: preserve the original abort actor's real surface result, retire it, and spawn a **fresh dynamic** AI builder in the same body-clear shaft with `surfaced=true`, anchor `(3140,452)`, stale corner `(3136,416)`, and a two-tick collision settle. Require the production brain to emit the bypass and physically reach the surface; do not accept displacement, intent, or a path as a substitute. If that passes, replay the real delayed Gloryhill return boundary, then run the complete current 78-scenario suite including the mandatory mirrored-overhang cycle. If it fails, revise or revert the experimental production re-entry change before any handoff.

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
- The later final-code safe-quarry/refined-return cohort used fresh controls and three 5,400-tick candidates on the same exact four-builder key. Mean gross collection rose `1702.667 -> 1738.000` (`+35.333`, `+2.08%`), confirmed delivery rose `1649.333 -> 1738.000` (`+88.667`, `+5.38%`), accessible stock rose `1234.000 -> 1488.000` (`+254.000`), and confirmed stone delivery rose `828.000 -> 938.000` (`+13.29%`). Every candidate delivered exactly its full collected total; the controls ended with delivery gaps of `80/80/0`. Deaths remained `0 -> 0` and failure-flagged runs remained `3 -> 3`, so the strict comparator passed but this is still not a failure-free claim. The exact comparator result is `Artifacts/aib_gym/gloryhill_4b_return_final_comparison_20260718.json`.
- Two later current-code cohorts were correctly rejected against those retained controls. The directional-shaft cohort averaged `1254.000` collected/delivered (`-448.667` collected, `-395.333` delivered), and the final handoff-band cohort averaged `1292.667` collected/delivered (`-410.000` collected, `-356.667` delivered). Deaths stayed `0 -> 0` and failure-flagged runs improved `3 -> 1` in both comparisons, but `AcceptancePassed=false`. Retained results are `Artifacts/aib_gym/gloryhill_4b_directional_comparison_20260718.json` and `Artifacts/aib_gym/gloryhill_4b_handoff_comparison_20260718.json`. These cohorts are failure-rate signals only, not throughput evidence.
- The final handoff mechanism does have exact causal diagnostic evidence. `gloryhill_4b_delivery_rejection_diag_20260718` and `gloryhill_4b_handoff_band_diag_20260718` share the complete fingerprint `w1-3142477075-210x66-1570756837-4872-3945193546-1025-53-3684685722-3060991973-2466050567` and both collected/delivered 1,316 (`590` wood, `646` stone, `80` gold). The former latched flags 5 with a target-264,360 path-thrash window at tick 5219. The latter aborted that same unsupported handoff at tick 4817 (`phase=handoff`, `elapsed=40`, `threshold=30`) and ended with flags 0. Treat this as reproduced-live-lock evidence, not as a substitute for the rejected cohort.
- The return-phase correction also has exact causal evidence. `gloryhill_4b_base_supply_route_diag_20260718` and `gloryhill_4b_return_phase_progress_diag_20260718` share complete fingerprint `w1-3142477075-210x66-1570756837-4872-3945193546-1025-53-2347018751-3060991973-2466050567`. Before the fix, builder 62 took 2,655 ticks from `return_wood` at tick 2489 to `stone_return_surface` at 5144 while lateral hold/release motion kept refreshing the old Euclidean progress clock. After phase-directional progress and anchor-relative wall samples, 12 completed underground returns had a maximum of 115 ticks; bounded retry events still surfaced. Both runs delivered every collected material, had zero deaths/flags, and parse to empty monitor failure/window files. Totals changed from 1,456 to 1,314, so do not present the diagnostic as throughput improvement.
- A global tree-approach-rise score was rejected as a throughput optimization. Its exact one-builder candidates collected `790/550/550` (mean `630.000`) versus retained controls `850/550/490` (mean `630.000`), so the strict improvement gate correctly rejected a zero delta. Ordinary and manual tree selection retain the prior score. Only a director-owned wood collector funding a pending `emergency_barrier` receives the approach-rise penalty; the final adversarial matrix below validates that narrow behavior in its intended context.
- Four-worker positions are selected from a deterministic home-connected grounded flood with full-set backtracking. Loose stone is local/exact-base-scoped. AI builders and Autobuilders cannot pick up CTF flags; the gym also aborts and restores the flag if contamination is ever observed.

### Physical flag gatehouse

`Scripts/AIBInfrastructureBenchmark.as` emits `[AIBGYMI]` schema 1 for `flag_gatehouse_physical`. It publishes a production gatehouse plan and lets a production Autobuilder execute it, then requires all physical tasks, completed counters, zero pending work/reservations, completed archival, healthy rear/front team doors, and a brain-disabled friendly builder probe crossing both gates.

Three independent full executions passed on each side:

| Team/side | Runs | Full physical passes | Mean completion tick | Mean ally traversal |
|---|---:|---:|---:|---:|
| 0 / left | 3 | 3 | 1068.000 | 58.333 ticks |
| 1 / right | 3 | 3 | 1075.667 | 48.333 ticks |

Every retained run built `36/36` tasks (`12` foundation, `13` access, `11` shell), emptied the AI work layer, released reservations, archived complete, and crossed both doors. This older schema-1 cohort predates the stone-door treatment and is absolute construction/friendly-passage evidence; the schema-4 treatment cohort below supplies the enemy-breach measurement.

The exact retained transcripts are:

- left: `gloryhill_flag_gatehouse_diagnostic_012`, `gloryhill_flag_gatehouse_left_candidate_001`, `gloryhill_flag_gatehouse_left_candidate_002`;
- right: `gloryhill_flag_gatehouse_right_diagnostic_001`, `gloryhill_flag_gatehouse_right_candidate_001`, `gloryhill_flag_gatehouse_right_candidate_002`.

Use `Tools/summarize_aib_infrastructure_results.ps1 -MinimumRunsPerCohort 3 -RequireAllPassed` to reproduce the aggregate.

### Real-enemy breach and accepted stone-door gatehouse

The opt-in `gatehouse_breach` and `workshops_breach` metrics emit strict `[AIBGYMI]` schema 4. They first require the complete production plan and the existing friendly passage/class-use postconditions. The benchmark then transfers the real connected player through `RulesCore.ChangePlayerTeam`, binds a real enemy builder, and attacks only through the stock client-originated builder `pickaxe` command. It records server-observed command callbacks, contact, damage, blocker loss, entry, and crossing; it has no synthetic hit command.

Build 4762 overwrites scripted runner keys on a player-bound body. The benchmark therefore discloses `server_static_outer_stance_then_bounded_velocity`: it holds the body on the one-tile enemy landing while the outer blocker remains, then applies only low horizontal velocity and lets ordinary collision own the route. This is a bounded measurement workaround, not a production movement change.

The former two wooden gatehouse doors were compared with the production candidate's two stone doors in four separate fixture-v3 cohorts. Every arm passed `3/3`; the parser now includes `variant` in the cohort key so the minimum-run gate cannot pool control and candidate rows.

| Side / variant | Runs | Mean completion | Mean friendly traversal | Initial blocker health | Mean pickaxe commands | Mean enemy crossing |
|---|---:|---:|---:|---:|---:|---:|
| left / wooden control | 3 | 1068.667 | 43.667 | 7 | 9.000 | 136.000 |
| left / stone candidate | 3 | 1072.333 | 44.333 | 10 | 11.000 | 160.000 |
| right / wooden control | 3 | 1073.333 | 78.333 | 7 | 8.333 | 110.000 |
| right / stone candidate | 3 | 1070.667 | 78.333 | 10 | 10.333 | 134.000 |

Across mirrored sides, mean crossing increased `123 -> 147` ticks (`+24`, `+19.51%`) and commands increased `8.667 -> 10.667`, while friendly traversal was effectively flat at `61.000 -> 61.333` and completion at `1071.000 -> 1071.500`. The resource tradeoff is two 50-stone doors instead of two 30-wood doors: `+40` total material and a shift from 60 wood to 100 stone. Production retains the stone doors in `AIBS_GatehouseDoorBlock()` because the delay improvement repeated on both sides without a measured construction or friendly-access regression.

The twelve retained transcripts are the `gate_v3_{control,candidate}_{left,right}[_2|_3]_20260717.tcpr.txt` files under `Artifacts/aib_gym`. Use the strict parser with its default three-run minimum and `-RequireAllPassed`.

The former one-column workshop enemy wall was compared with a second paid three-block stone column in four separate fixture-v4 cohorts. Every arm passed `3/3`; each run first completed and archived the exact production plan, exercised the full friendly home/shop/class-use/return route, then physically breached every enemy-side blocker.

| Side / variant | Runs | Tasks | Mean completion | Mean friendly traversal | Mean pickaxe commands | Mean enemy crossing |
|---|---:|---:|---:|---:|---:|---:|
| left / one-column control | 3 | 69 | 2096.333 | 562.000 | 26.000 | 364.000 |
| left / two-column candidate | 3 | 72 | 2186.333 | 1217.333 | 48.000 | 616.000 |
| right / one-column control | 3 | 69 | 2095.667 | 794.667 | 22.000 | 298.000 |
| right / two-column candidate | 3 | 72 | 2185.333 | 393.333 | 44.333 | 562.000 |

Across mirrored sides, mean enemy crossing increased `331 -> 589` ticks (`+258`, `+77.95%`) and commands increased `24.000 -> 46.167`. Mean plan completion moved `2096.000 -> 2185.833` (`+89.833` ticks), exactly the expected three extra Autobuilder placement intervals apart from small scheduling variation. The resource cost is `+30` stone. Friendly traversal remained valid in all six candidate runs but was noisy: its mirrored mean increased `678.334 -> 805.333` (`+126.999`, `+18.72%`) because left-side candidate runs alternated between `408` and `1622` ticks; right improved from `794.667` to `393.333`. Production retains the second wall column because the repeated mirrored breach gain is large, the home-side geometry is unchanged, and no friendly route failed, but the left-side traversal variance remains a follow-up signal rather than being hidden by the aggregate.

The twelve admitted transcripts are `workshop_v4_control_left_20260717`, control left `_2`/`_3`, candidate left `_2`/`_3`/`_4`, and the base plus `_2`/`_3` files for both right-side arms under `Artifacts/aib_gym`. `workshop_v4_candidate_left_20260717` is an excluded pre-fix diagnostic: it built `72/72` but hit the benchmark's stale four-cover expectation before the friendly route, so it is not part of the cohort.

Two fresh instrumented replays, `workshop_v4_left_route_diag_20260718` and `workshop_v4_left_route_diag2_20260718`, both completed `72/72`, validated class use and return, breached all seven enemy-side blockers, and recorded the fast `408`-tick friendly route. Their bounded `AIBGYMI|PATH` samples repeated the same surprising native `BrainPath` detour from about `(128,286)` left to `(64,208)` and back to the `(140,228)` landing. The earlier `1622`-tick arm therefore was not reproducible in these runs. Retain the benchmark-only path sampling and exhausted-route retry diagnostics, but do not infer a production path or structure change from two fast diagnostics.

### Protected class workshops

`Scripts/AIBInfrastructureBenchmark.as` currently emits `[AIBGYMI]` schema 3 / fixture version 3 for `protected_class_workshops_physical`. It publishes a production `protected_workshops` plan and lets a production Autobuilder execute it. Acceptance requires the exact same-team `knightshop` and `archershop`, every physical task, completed counters and archive, zero pending work/reservations, a `10/10` roof, `28/28` shop backing cells, the supported home door/upper cover, and every cell in the configured enemy wall. The retained Gloryhill cohort used the former 72-task, single-exit geometry with two three-cell enemy columns; the prior one-column production had 69 tasks and fixture version 2. It remains historical construction/breach evidence and must not be cited as physical validation of the 2026-07-20 roof hatch.

The traversal probe binds its synthetic control lineage to a real connected player holder. It uses production `BrainPath` from the exact tent to the home landing, crosses the workshop corridor, invokes the existing stock class-change command at each exact shop, becomes knight and then archer, and returns through the home door. It does not use raw tile scheduling or a test-only class mutation.

Three independent full fixture-v2 executions passed on each side before the second enemy-wall column was added:

| Team/side | Runs | Full physical passes | Mean completion tick | Mean home/shop/return traversal |
|---|---:|---:|---:|---:|
| 0 / left | 3 | 3 | 2091.000 | 407.333 ticks |
| 1 / right | 3 | 3 | 2090.333 | 566.000 ticks |

The strict parser accepted all six transcripts. Final-code post-planner smokes also passed independently on both sides: `gloryhill_protected_workshops_postplanner_left_002` (`2091`, `407`) and `gloryhill_protected_workshops_postplanner_right_002` (`2092`, `566`). The retained cohort transcripts are `gloryhill_protected_workshops_left_001` through `_003` and `gloryhill_protected_workshops_right_001` through `_003` under `Artifacts/aib_gym`.

That historical cohort proves the original exact construction, cover, friendly reachability, stock class use, and return. The schema-4 candidate cohort above supersedes it for current production: all six runs completed `72/72`, archived cleanly, validated the same full friendly route, and then measured real enemy-builder breach. It still proves only the named builder-pickaxe route, not knight, archer, bomb, or mixed combat survival.

### Adversarial survival and emergency barrier

The production CTF wave harness now uses fixture version 4 and driver `grounded_candidate_corridor_v4_exclusive_spawn_outcomes`. It preserves the official Gloryhill world, creates a local grounded corridor at the exact selected emergency-barrier site, permits at most one production worker plus seven real attackers, and drives knight, archer, bomb, and mixed pressure with deterministic seed-dependent cadence. Plan variants begin with zero stock and no worker; production director code must provision the ordinary worker, harvest through its normal episode, publish the nine-task/119-material `emergency_barrier`, and physically build it. Control variants leave the director off. Every trial receives a fresh visible KAG process and a 1,200-tick warm-up before the bounded 1,200-tick wave.

Wave measurements are pinned to the exact physical task coordinates captured at measurement start. Later production replans increment `replans` but cannot switch `plan_pending`, `plan_damaged`, completion, damage, or lifetime metrics to a successor plan. Attacker outcomes are also pinned to the seven spawn indices: crossing and death are mutually exclusive, duplicate rules `onBlobDie` callbacks are diagnosed separately, and the comparator rejects any row where `crossings + enemy_deaths != outcomes_resolved` or resolved outcomes exceed the spawn count.

The first corrected-outcome left-side cohort exposed one real failure: bomb seed 211 killed the still-building worker. The trace showed the worker entered pressure with 7/9 tasks and remained near the blast face while bombs were thrown outside the ordinary knight-fear radius. Production now retreats from an activated enemy bomb within 128 pixels (twice the stock 64-pixel actor-damage radius), releases its current path/target for that tick, preserves the job, and logs at most one `flee_bomb` event per bomb. The exact focused rerun preserved the same `first_breach=66` and seven attacker outcomes while changing builder deaths `1 -> 0`; physical movement increased from `408.799` to `694.761` pixels and the worker retreated from about x=430 to x=328.

The final-code collection is the 48 transcripts matching `Artifacts/aib_gym/wave_v4_bombsafe_20260718_*.tcpr.txt`: two sides × four scenarios × three seeds (`101/211/307`) × control/plan. `Tools/compare_aib_wave_results.ps1 -RequireAcceptanceGates` accepted all 24 exact pairs.

| Side | Scenario | Pairs | Mean first-breach delta | Mean crossing delta | Mean builder-death delta |
|---|---|---:|---:|---:|---:|
| left | knight | 3 | +15.667 | 0.000 | 0.000 |
| left | archer | 3 | +15.000 | 0.000 | 0.000 |
| left | bomb | 3 | +15.667 | -1.000 | 0.000 |
| left | mixed | 3 | +13.667 | -2.000 | 0.000 |
| right | knight | 3 | +148.333 | -4.333 | 0.000 |
| right | archer | 3 | +15.000 | 0.000 | 0.000 |
| right | bomb | 3 | +135.333 | -4.667 | 0.000 |
| right | mixed | 3 | +15.000 | -3.000 | 0.000 |

Across all 24 pairs, mean first breach moved `+46.708` ticks, crossings moved `-1.875`, builder-death delta was `0`, and friendly-route penalty delta was `0`. All composition, real arrow/bomb, control-breach, non-worsening crossing, censor-aware breach, friendly-route, and builder-survival gates passed. This proves the named local seven-attacker corridor and production emergency response; it does not turn one deterministic fixture into a claim about every live-player siege pattern.

## Important implementation findings

- The real CTF flag blob name is `ctf_flag`, not `flag`. The old lookup silently selected the tent as the strategic anchor. Runtime planners, world observation, commands, gym code, and fixtures now consistently use `ctf_flag`.
- A valid Gloryhill gatehouse needs terrain-adaptive foundation cells and a dependency-safe phase split. The generator samples the highest shell/landing surface, pays for missing level foundation cells, places the top backing row in the access phase, and tries bounded flag-relative offsets through 22 tiles. The first legal left-side site was 16 tiles toward the enemy.
- A generic jump in the friendly traversal probe climbed the center ladder and produced a false front-exit failure. The level gate-passage probe intentionally uses horizontal movement only.
- Player-bound scripted runner keys were overwritten in both client- and server-key attempts. The schema-4 benchmark keeps the stock client pickaxe command but uses an explicitly disclosed, bounded server stance/velocity controller for position; all accepted rows require real entry/crossing or live resistance evidence.
- Infrastructure cohorts are now split by `variant`. Pooling control and candidate rows could otherwise satisfy the minimum sample gate while hiding an under-collected treatment arm.
- KAG build 4762 rejects some arithmetic on `const Vec2f` locals. Keep vectors mutable where operator overload resolution fails; see `KAG_ENGINE_QUIRKS.md`.
- Planner reachability now evaluates each construction phase against a candidate view containing completed prerequisite phases, seeded from the exact resource home as well as legal boundary approaches. This keeps planner and production execution aligned for terrain-adaptive support chains.
- Director prefab traversal uses a full 2x2 runner volume at every route and
  phase-approach node. A single 1x2 door column is not itself a passage; it is
  valid through a one-course wall only when an adjacent clear column completes
  the four-cell body volume. The flag room's two-course roof therefore uses a
  two-column-by-two-row reinforced hatch. Production selection retains this
  friendly-route gate even when an Autobuilder lets it skip physical task
  approach checks.
- Protected-blob overlap now uses strict expanded blob bounds after the broad radius query. A tangential radius hit at 40 pixels no longer rejects a legal workshop, while a real eight-pixel overlap remains invalid.
- During a genuine frontline collapse, the selector chooses from legal emergency barriers when at least one exists; an unsafe emergency candidate still falls back to the normal legal pool.
- KAG rules `onBlobDie` can run more than once for the same attacker. A focused seven-attacker bomb run recorded five unique deaths, two crossings, and five duplicate callbacks. Use rules-side spawn-index callback/outcome masks; never use raw callback totals as unique deaths or as the wave completion condition.
- Wave plan metrics must retain the exact measured task set across production replans. Plan-id changes are a separate diagnostic, not permission to start measuring a successor defense.
- Live enemy bombs are an immediate worker threat even while their carrier remains outside the knight-fear radius. The production worker now retreats from activated enemy bombs within 128 pixels while preserving its durable job.
- A quarry cannot use a fixed storage offset on real CTF terrain. On Gloryhill the old point placed quarry output over the mined shaft, where tagged loose stone fell underground and became a permanent lure. Quarry creation now reuses the supported five-column base-workshop site search, revalidates before charging, refunds a failed spawn, rejects unsupported existing quarries, and treats tagged output as base stock only while it remains at the exact home/storage/supported-quarry boundary.
- When the last harvestable tree is gone immediately after a quarry is created, the wood state machine must maintain that existing valid local quarry before starting a nursery quest. Otherwise the nursery consumes the reserved 100-wood fuel batch and leaves the new quarry empty. Production now checks only an already-existing valid base quarry in this no-tree branch; quarry creation, siting, costs, and normal tree priority remain unchanged. Compile-checked run `5ea361bcd98a` and the final 65-case suite both passed with `quarry_built=true`, `quarry_fueled=true`, and `fuel=100` at tick 27.
- A stone episode now keeps two identities: the measured surface-entry anchor and the latest valid underground cross-tunnel corner. Underground ore/gold retargeting may update the corner but cannot invent a new surface entry. The saved route corner is the canonical left-tile origin, so return rejoin targets the true two-column runner center at `anchor.x + tileSize / 2`, not the corner x coordinate itself. Explicit corner-climb `up` ownership is limited to a worker below the lower-body band and within 1.5 tiles horizontally; a far corner rejoin remains horizontal and uses only geometry-qualified ordinary obstacle scaling. Return then centers through the two-wide shaft lip and latches wall-plus-up input until the surface handoff band. The return progress clock is reset at the outbound/return boundary so mining time cannot cause an immediate false retry.
- Return progress is now phase-directional. Before rejoining the cross-tunnel corner, only reduced distance to the physical two-column rejoin point counts; afterward, only reduced vertical error to the saved surface anchor counts. The phase transition resets its own sample/tick. Wall detection samples canonical outer shaft cells derived from the anchor instead of `currentX +/- radius`, so a two-pixel body jitter cannot change the sampled map column and sustain a false wall-release cycle.
- Root `untitled.png` captures the now-fixed outbound mining deadlock baseline, not merely a noisy monitor window. The exact visible baseline is `Artifacts/aib_gym/gloryhill_4b_return_final_stalldiag_20260718.tcpr.txt`: miners `60` and `62` had a valid retained surface anchor `180,288` and local corner `192,376` while mining target `224,376` at ticks `2890/2891`; the deeper nearby retarget to `224,392` at ticks `2926/2927` erased the mutable corner, then both workers repeatedly rebuilt a direct `BrainPath` to `228,396` from the pocket around `200,368`. From tick `3005` through the retained end at `5527`, the trace alternates `stone_route_obstruction` against nodes `216,368`/`192,384`, identical path sets, and corner escapes, with no dirt hit, ore outcome, quota return, or surface retreat. Keep this transcript and screenshot unchanged as the regression baseline.
- The bounded continue-or-return policy is implemented in `AIB_RetargetExistingStoneRoute` and as an `AIB_TunnelToStone` safety net. It preserves and extends the last valid shaft x only when the exact two-wide shaft/two-high cross-tunnel passes the existing traversable, barrier, no-build, bedrock, and castle gates; otherwise it clears the ore target/path, preserves the measured surface anchor and last valid corner, and switches to `return_wood`. Change-only `stone_route_continue`/`stone_route_abort` events expose the choice, and generic dirt mining was not broadened. The route fixture now pauses its uniquely tagged abort actor for two full ticks after terrain/spawn writes, then requires the production abort state, physical surfacing, and preserved block/ore. Focused log `console-26-07-18-18-41-45.txt` and the full suite in `console-26-07-18-18-49-07.txt` passed the case at tick 463. That full log also passed `stone_corner_escape_from_mirrored_upper_overhangs` with both opposite-direction events, both complete 36-tick cycles, both 90-tick cooldown latches, at least one tile of displacement on each side, and intact traps.
- Official-Gloryhill diagnostic `Artifacts/aib_gym/gloryhill_4b_centered_bounded_corner_diag_20260718.tcpr.txt` ran 3,000 ticks, collected and delivered all `1,608` material (`590` wood, `938` stone, `80` gold), kept four workers productive, and ended with zero deaths and `failure_flags=0`. Worker `60` entered corner assist at tick 2424, rejoined at 2432, held the wall at 2435, surfaced at 2444, and exited at 2462; worker `62` assisted at 2502, rejoined at 2524, and surfaced/exited at 2536. The centered-only predecessor still left worker `60` without a relevant outcome for 1,646 ticks, proving that centering alone was insufficient. An above-surface target gate was also rejected after falling to `638/638` with failure flags `33`; elevated Gloryhill ore is legitimate. This diagnostic closes the reproduced corner-return lock but is not an exact three-run throughput cohort.
- Successful stone delivery now calls `AIBM_ClearDeliveredResourceEpisodeIntent`: it preserves only an unexpired rejected-route cluster for the same stone job, while manual ownership and real role cleanup still clear it. Pre-fix `console-26-07-18-17-08-35.txt` retried target `96,344` at tick 3406 despite the same builder's `retry=4184` boundary at tick 3284. Post-fix `console-26-07-18-17-20-17.txt` recorded one abort at tick 4337 with `retry=5237` and no immediate repeat. The stone-route fixture asserts both delivery preservation and ownership cleanup.
- Outbound shaft progress is vertical-error reduction toward the cross-tunnel row, not arbitrary two-dimensional displacement; a successful route hit also resets it. Ordinary shaft travel retains the 120-tick bound. First entry into the one-tile target-row handoff band is observed before direct ownership releases and starts a separate 30-tick seam clock. Do not restore the rejected global 30-tick shaft variant: `console-26-07-18-17-55-50.txt` aborted valid approach/supported motion, fell to 1,240 delivered, and introduced a return motion stall.
- A remaining open base-supply route appears in `console-26-07-18-18-09-10.txt`: builder 60 latched motion stall at tick 3264 in target-free `find_stone`, position `(104,319)`, destination `(220,308)`, and then repeated the x=79..104 pocket cycle. Parsed evidence is `Artifacts/aib_gym/gloryhill_4b_handoff_candidates_20260718.{failures.ndjson,windows.ndjson}`. EventLog replay `gloryhill_4b_base_supply_route_diag_20260718` created the exact local `buildershop` at `(220,308)` and emitted subsequent worker paths there, closing the source-identity question. That replay instead exposed the 2,655-tick upstream return lock, and the fixed identical-fingerprint replay selected reachable ore before a terminal shop approach could recur. Reproduce the independent current-code approach stall before changing siting; likely checks are pinned home identity, home-facing grounded approach, and low-level path nodes.
- Two earlier aggressive return experiments remain rejected. Per-fall high-water realignment produced hundreds of repeated events and an approximately 800-tick oscillation; a bounded 12-tick wall retry reduced the 3,000-tick diagnostic stone result from `938` to `266`. Neither mechanism remains in production.
- The supported-recovery fixture now uses a seven-tile uphill dirt plug and a forced unsupported rung at tile `349,68`. It withholds its 100 wood until the runner physically reaches the obstruction face, then pulses the obstruction threshold only while production's exact uphill-node, low-motion, peak, and face predicates hold. Production still owns validation, payment, staged support, ladder creation, the later path probe, and traversal. It fails on any pre-ladder crossing and requires a nonzero paid support chain, support before the ladder, a later accepted `BrainPath` probe, exact post-ladder wood cost, an unchanged two-column plug, and physical crossing. Authoritative hot run `eb3a6c62b0d8` and the current full suite both passed at tick 288 with a three-cell chain, ladder tile `349,68`, and 84 wood remaining. Required mirrored-corner regression `033932ab1f1f` also passed both complete 36-tick cycles, both 90-tick cooldown latches, one-tile displacement, and trap preservation.
- The blueprint-material fixture now scopes conservation to its owned crate and builder inventory, including a carried attachment, so unrelated map-global material cannot corrupt the verdict. Authoritative hot run `59ecbe077a10` and the current full suite passed at tick 193 after both physical blocks, both withdrawals, and exact `70` wood/`70` stone conservation.
- Focused runtime passes after the planner changes cover director heartbeat/bootstrap, replan hysteresis, collapse selection, no-build/occupied/barrier physical fallback, uneven-edge physical fallback, mirrored physical completion, and the no-safe-stone wait. Exact references are recorded in `AIB_TEST_AUDIT.md` and `KAG_ENGINE_QUIRKS.md`.
- AIBTest transitions now wait for the exact canonical tile hash, actual disappearance of tagged fixture/bootstrap handles (a `dead` tag is not enough), and removal of temporary no-build sectors before starting the next fixture. Initial cold/hot startup uses the same bounded gate. Test-owned pressure, recent-attack, heat, and previous-frontline history is also reset between synthetic worlds. This keeps the canonical guard fail-closed while preventing same-callback deaths, tile writes, and stale strategic history from contaminating the next scenario.

## Resume order

1. Resume the exact-map compact-workshop access edge described above first. Do not run AIBTest unless the user changes direction. Preserve flag-base no-build cells, the Tent-level row, both independent 2x2 exits, and both shops; validate only through a fresh visible normal-CTF launch on `Ferrezinhre_Totally_Transcendent`.
2. Treat the paused experimental stone-reentry section as the next independent resume point. Do not cite the current source as globally green. Replace the contaminated reused/static re-entry leg with the one fresh-dynamic-actor fixture, then either validate the candidate through the focused physical outcome or revert it.
3. Use `../../Logs/console-26-07-18-18-49-07.txt` only as the last pre-experiment AngelScript regression baseline: it contains all 65 starts/verdicts and `[AIBTEST] DONE passed=65 failed=0`. It also contains the mandatory mirrored-overhang proof at ticks 3338-3375 and both return-route assertions in the tick-463 reusable-route verdict. No current full-suite claim exists.
4. Resume the independent target-free `find_stone` approach only after the re-entry experiment is resolved. The early forced probe reached the exact `(220,308)` shop in 114 ticks; the delayed probe reached its different `(252,308)` shop in 102 ticks. Neither reproduced the original `(220,308)` terminal pocket, so do not change workshop siting or source selection from those probes. Record the pinned resource home, grounded approach side, custom low-level node sequence, and actual shop identity if it recurs. Do not weaken `AIBGymMonitor`.
5. Keep the handoff diagnostic and the production cohort conclusions separate. The identical-fingerprint 1,316/1,316 replay closes the reproduced unsupported-cross path-thrash mechanism, but `gloryhill_4b_handoff_comparison_20260718.json` rejects a throughput claim. A future throughput claim needs a newly accepted exact cohort.
6. Do not restore per-fall high-water realignment, the bounded wall retry, the centered-only variant, the above-surface ore gate, the global supported-cross rejection, or the all-shaft 30-tick watchdog. Each was rejected by direct runtime evidence.
7. Revisit the left workshop `408/1622` variance only after a slow route is reproduced with the retained bounded path diagnostics; do not change production from the two fast replays.
8. Runtime-validate the public telemetry moderator lifecycle and real late-join/editor team/spectator boundaries before calling the mod public-test-ready.

## Useful commands

```powershell
# One owned visible infrastructure run; the wrapper closes KAG and restores CTF.
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Team 0 -CompilerForwarding
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Metric workshops -Team 1
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Metric gatehouse_breach -Team 0
& .\research\tools\Invoke-AIBGymInfrastructureRun.ps1 -RunId <unique-id> -Variant candidate -Metric workshops_breach -Team 1

# Reproduce a three-run infrastructure aggregate.
& .\Tools\summarize_aib_infrastructure_results.ps1 -LogPath <variant-separated transcript paths> -MinimumRunsPerCohort 3 -RequireAllPassed -AsJson

# Resource cohort comparator and relevant offline regressions.
& .\Tools\test_compare_aib_gym_results.ps1
& .\Tools\test_summarize_aib_infrastructure_results.ps1
& .\Tools\test_parse_aib_gym_failures.ps1
& .\Tools\test_parse_aib_gym_windows.ps1

# One wave trial, a bounded matrix range, and the strict final comparator.
& .\research\tools\Invoke-AIBWaveRun.ps1 -RunId <unique-id> -Variant plan -Team 0 -Scenario bomb -Seed 211 -CompilerForwarding
& .\research\tools\Invoke-AIBWaveMatrixRun.ps1 -ManifestPath .\Artifacts\aib_gym\wave_v4_matrix_20260718.ndjson -RunPrefix <unique-prefix> -StartOrdinal 1 -EndOrdinal 8
& .\Tools\compare_aib_wave_results.ps1 -LogPath <exact 48 final-code transcript paths> -RequireAcceptanceGates -AsJson
& .\Tools\test_compare_aib_wave_results.ps1
& .\Tools\test_new_aib_wave_matrix.ps1
```

Read `AGENTS.md`, `KAG_ENGINE_QUIRKS.md`, `RUNTIME_TESTING.md`, `AIB_GYM_METRICS.md`, and `kag_gym.md` before resuming runtime work.
