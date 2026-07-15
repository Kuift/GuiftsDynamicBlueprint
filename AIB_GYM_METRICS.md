# KAG Gym metrics

KAG Gym evaluates production AI behavior inside visible KAG on existing CTF maps. Scores are compared only within the same map identity, team side, worker configuration, order, and duration. Initial world fingerprints remain attached to every record for auditing, but are not used to average different maps together or to select an easier mapcycle.

## Resource collection

Implemented schema: `[AIBGYMR]` v4 in `Scripts/AIBGymBenchmark.as`.

- `resource_collection_180s`: exactly 5,400 simulation ticks (180 seconds).
- Supported worker counts: one or four ordinary AI builders.
- Supported orders: `wood`, `stone`, or `mixed` (mixed requires four workers and alternates wood/stone by stable slot).
- `collected_*`: gross material first acquired by the worker. Confirmed delivery reconciles any engine-direct inventory pickup that did not expose a carried-blob transition.
- `delivered_*`: material present when the production return/storage episode confirmed the worker no longer held it. This includes material spent by the production AI to create required storage.
- `stock_delta_*`: final accessible base stock minus initial accessible base stock. This exposes storage/workshop costs and material that never became usable at the base.
- Per-worker `[AIBGYMB]` records retain stable episode slots so a four-builder total cannot hide one idle worker.
- Deaths, passive gym failure flags, idle ticks, travel, map identity, initial terrain hash, and the complete privacy-safe world fingerprint are retained alongside the score.

Manual moderator command:

```text
!aib_gym resources 1 wood
!aib_gym resources 4 mixed
!aib_gym resources 1 wood 30
!aib_gym status
!aib_gym stop
```

The optional duration is 10–180 seconds. Anything other than 180 seconds is labeled `resource_collection_smoke` and cannot enter the three-minute comparator.

Use `Tools/compare_aib_gym_results.ps1` for control/candidate cohorts. It defaults to three runs per variant and refuses to combine different map hashes, dimensions, team sides, worker counts, orders, or durations. A candidate must improve mean gross collection without increasing mean deaths or the number of runs with latched gym failures when `-RequireImprovement` is used.

The aggregate `[AIBGYMR]` row and each `[AIBGYMB]` worker row are emitted to both the KAG console and explicit TCPR at the final boundary. When driving a local episode, pass `--transcript <path>` to `research/tools/tcpr_send.py`; it persists received records incrementally, so a stopped console observation channel does not erase the comparator-grade result. The owned wrapper also requires a TCPR connection to remain live for three seconds before beginning the transaction, because an early startup socket can accept and then reset. The comparator counts unique run ids, collapses identical console/TCPR duplicates, and rejects a reused run id with conflicting content; transport duplication or an aborted socket can never satisfy the minimum physical-run count.

First valid baseline (build 4762, 2026-07-15):

```text
run=gloryhill_control_1b_002
map=8x_Gloryhill (hash 3142477075, 210x66), team 0 left side
builders=1 order=wood duration=5400
collected=850 delivered=850 accessible_stock_delta=650
deaths=0 failure_flags=1 travel_px=6995.92
```

Source evidence: `../../Logs/console-26-07-15-05-37-30.txt`. The 200-material difference between gross delivery and accessible stock is production storage infrastructure cost. The latched flag was a recoverable `motion_stall`; it remains part of the baseline rather than being erased because the worker later recovered.

Earlier schema-v2/v3 records in the same log are diagnostic only. They proved the bootstrap cleanup race, direct-inventory acquisition blind spot, and transient fingerprint variation; the comparator accepts only schema v4.

Focused fallen-log diagnostic (build 4762, 2026-07-15; not a comparator cohort):

```text
control=gloryhill_log_path_trace_001
candidate=gloryhill_log_watchdog_candidate_001
map=8x_Gloryhill (hash 3142477075, 210x66), team 0 left side
builders=1 order=wood duration=1200 (resource_collection_smoke)
control:   collected=190 delivered=190 first_delivery_tick=1200 failure_flags=1
candidate: collected=190 delivered=190 first_delivery_tick=900  failure_flags=0
```

The control log target retained a nominal three-waypoint `BrainPath` route but replanned every 21 ticks with no hit or useful displacement, then exhausted the old 300-tick post-target watchdog. The candidate changes only that watchdog to 90 ticks; it does not shorten the intentional pre-target engine log-spawn wait. Source evidence is `../../Logs/console-26-07-15-06-23-37.txt`, `../../Logs/console-26-07-15-06-28-18.txt`, and the correlated TCPR result records retained by the interrupted Codex session. These smoke episodes validate the defect and mitigation boundary only.

Full exact-map watchdog cohort (three physical episodes per variant):

```text
300-tick control:   850, 550, 490 collected; mean=630.000
90-tick candidate:  550, 540, 550 collected; mean=546.667
delta:              -83.333 (-13.23%)
deaths:             0 versus 0
failure runs:       3 versus 3
acceptance:         failed
```

The control sources are `../../Logs/console-26-07-15-05-37-30.txt`, `Artifacts/aib_gym/gloryhill_logwatch_control_1b_003.tcpr.txt`, and `Artifacts/aib_gym/gloryhill_logwatch_control_1b_004.tcpr.txt`. Candidate sources are the matching `_candidate_1b_002`, `_003`, and `_004` TCPR transcripts. `Tools/compare_aib_gym_results.ps1` reported one exact `map_3142477075_210x66` cohort, six distinct startup fingerprints, and `AcceptancePassed=false`. The 90-tick change is rejected; production retains 300 ticks while the underlying route failure is investigated.

Full current-code path-recovery cohort (same retained 300-tick controls, three new physical candidates):

```text
300-tick control:       850, 550, 490 collected; mean=630.000
path-recovery candidate: 800, 550, 550 collected; mean=633.333
delta:                  +3.333 (+0.53%)
deaths:                 0 versus 0
failure runs:           3 versus 0
acceptance:             passed
```

Candidate sources are `Artifacts/aib_gym/gloryhill_narrowdrop_candidate_1b_009.tcpr.txt`, `_010`, and `_011`. The exact cohort key was `map_3142477075_210x66|1|0|left|3142477075|210|66|resource_collection_180s|1|wood|5400`; six startup fingerprints and three terrain hashes remained attached as audit evidence. The strict comparator reported `CollectedDelta=3.333`, equal zero deaths, failure runs improving from 3 to 0, and `AcceptancePassed=true`.

This is a marginal throughput win and a clear reliability win, not evidence for the rejected 90-tick watchdog. The current production code keeps the 300-tick post-target watchdog and instead adds geometry-bounded ordinary-travel recovery for open downward nodes, wall-assisted upward nodes, one-sided diagonal overhangs, blocked-side release, and narrow drops. Focused event diagnostics proved open descent, blocked-wall release, crossing, tree felling, and log processing; the deep narrow-log landing remains covered by full-run outcomes rather than an identical event-logged replay.

Full four-builder mixed-resource cohort (same official map, three physical episodes per variant):

```text
connected/base-scoped control: 936, 1066, 826 delivered; mean=942.667
shaft-return candidate:        1716, 1438, 1568 delivered; mean=1574.000
delta:                         +631.333 (+66.97%)
accessible-stock mean:         742.667 -> 1167.333 (+424.667)
deaths:                        0 versus 0
failure runs:                  3 versus 3 (aggregate mask 33 -> 1)
acceptance:                    passed
```

The exact cohort key is `map_3142477075_210x66|1|0|left|3142477075|210|66|resource_collection_180s|4|mixed|5400`. Controls are `gloryhill_4b_scoped_baseline_001`, `_003`, and `_004`; candidates are `gloryhill_4b_stone_return_candidate_001`, `_002`, and `_003` under `Artifacts/aib_gym/`. `Tools/compare_aib_gym_results.ps1 -RequireImprovement` reported `DeliveredDelta=631.333`, unchanged zero deaths, no increase in failure-flagged runs, and `AcceptancePassed=true`.

Stable per-slot means expose the source of the result:

| Slot/order | Control mean | Candidate mean | Delta |
|---|---:|---:|---:|
| 0 / wood | 453.333 | 373.333 | -80.000 |
| 1 / stone | 156.000 | 439.333 | +283.333 |
| 2 / wood | 213.333 | 346.667 | +133.334 |
| 3 / stone | 120.000 | 414.667 | +294.667 |

The combined wood mean rose from 666.667 to 720.000, while stone-plus-gold rose from 276.000 to 854.000. The material change is therefore repeated stone delivery: controls handed an underground quota-complete miner back to ordinary navigation, while the candidate retains a per-episode surface entry anchor and holds wall direction plus upward input through the return shaft. Event-logged smoke `gloryhill_4b_stone_return_candidate_trace_003` physically recorded both stone workers exiting y=336/344 to y=281-290 and delivering again.

This cohort also tightened the benchmark boundary. Four-worker spawns now come from a deterministic home-connected grounded-cell flood plus full-set backtracking; the invalid earlier shelf spawn near `(119,340)` is excluded. Loose `mat_stone` selection is local or exact-base-scoped, so enemy-side quarry output cannot attract a miner across the flag. `gloryhill_4b_scoped_baseline_002` is excluded because its wood worker physically captured the enemy flag; the fail-closed guard restored that flag and aborted instead of emitting a result. Production `aibuilder`/`autobuilder` collisions now decline CTF flag pickup, and all retained post-fix runs were uncontaminated.

All candidates still contain at least one recoverable 40-tick motion-stall window, usually during a slow deep cross-tunnel return. The accepted result is a throughput improvement and removal of the false mining state-stall bit, not a claim of failure-free four-worker navigation.

## Construction and defense metrics

Implemented infrastructure schema: `[AIBGYMI]` v1 in `Scripts/AIBInfrastructureBenchmark.as` for `flag_gatehouse_physical`.

The benchmark finds the real `ctf_flag`, generates and publishes a production gatehouse plan, and assigns a production Autobuilder. A result passes only when every planned task matches the world, plan counters show complete with zero pending work, reservations and the AI work layer are empty, the completed plan is archived, both rear/home-side and front/enemy-side team doors are healthy, and a brain-disabled same-team builder physically enters the rear and exits the front. The run never substitutes raw tile scheduling for production execution.

Run it with `research/tools/Invoke-AIBGymInfrastructureRun.ps1`; aggregate exact fixture/version/team/side/map/metric/template cohorts with `Tools/summarize_aib_infrastructure_results.ps1`. Identical console/TCPR copies are deduplicated and conflicting reused run ids are rejected.

Official Gloryhill physical cohort (build 4762, 2026-07-15):

| Team/side | Runs | Physical passes | Tasks per run | Mean completion tick | Mean ally traversal ticks |
|---|---:|---:|---:|---:|---:|
| 0 / left | 3 | 3 | 36/36 | 1068.000 | 58.333 |
| 1 / right | 3 | 3 | 36/36 | 1075.667 | 48.333 |

Every run also reported `pending=0`, `reservations=0`, `work_tiles=0`, completed archival, and healthy rear/front gates. Left evidence is `gloryhill_flag_gatehouse_diagnostic_012` plus `left_candidate_001/_002`; right evidence is `right_diagnostic_001` plus `right_candidate_001/_002` under `Artifacts/aib_gym/`. This is an accepted absolute construction/friendly-passage milestone. It is not a control/candidate combat comparison and does not establish enemy delay, breach resistance, or survival.

The remaining metrics are still required:

| Metric | Required authoritative outcome | Current foundation |
|---|---|---|
| Four-builder resource throughput | Same v4 resource record with four per-worker slots | Accepted Gloryhill 3x3 cohort: 942.667 -> 1574.000 mean delivery, zero deaths |
| Correct infrastructure near flag | Physical matching blocks near the flag plus traversable rear/home-side and front gates | Accepted Gloryhill schema-v1 cohort: 3/3 full physical passes on each team side |
| Protected accessible workshops | Same-team class workshop within a bounded tent/hall/tunnel route, with measured cover and real friendly traversal | Storage siting exists; player-class/access benchmark pending |
| Ally versus enemy traversal | Timed physical probes through the completed structure in both directions | Real ally probe passes both sides; equivalent enemy delay/breach probe pending |
| Builder/base survival | Time-to-death/breach under knight, archer, bomb, and mixed attackers | Wave harness exists; paired runtime dataset pending |
| Adversarial progression | Defender and attacker variants improve in alternating, map-matched rounds | Not implemented yet |

Every gym-owned resource episode is capped at eight total managed AI actors. The strategy-wave source now derives its attacker budget from live construction workers and compiled successfully in visible KAG, so its intended defender-plus-attacker cap is also eight; a real wave run is still required before claiming that cap as runtime-verified.

## Map comparison contract

The cohort key is:

```text
fixture_id + fixture_version + map_hash + dimensions + team + side
+ metric + builder_count + order + duration
```

This is deliberately map-scoped. The initial terrain hash and world fingerprint are retained as audit/stratification fields because KAG can mutate transient terrain and blobs during normal map startup; requiring byte-identical delayed snapshots would reject repeated trials of the same official map. Never pool scores across different map hashes or let a candidate choose its mapcycle.
