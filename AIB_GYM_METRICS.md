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

### Final safe-quarry and refined-return cohort

The later production pass fixed two additional defects without reopening the earlier accepted shaft-return result:

- Quarry output used a fixed offset from storage. On Gloryhill that point could hang over the miner's shaft, so tagged `mat_stone` fell underground and remained eligible as a moving base-source lure. Quarry placement now reuses the clear, supported five-column base-workshop selector; creation revalidates before payment, refunds a failed spawn, and ignores unsupported existing quarries. Tagged output is eligible only at the exact home/storage/supported-quarry boundary.
- Underground ore and gold retargeting could overwrite the original surface-entry identity or clear the mutable mining corner before return. The worker now preserves a stable episode surface anchor plus a separately saved latest cross-tunnel corner. It rejoins the corner inside the anchor/corner span, centers through the two-wide shaft lip, and latches wall-plus-up input only after the topology-qualified handoff.

Fresh exact-key 5,400-tick results:

```text
control collected: 1806, 1764, 1538; mean=1702.667
control delivered: 1726, 1684, 1538; mean=1649.333
candidate collected/delivered: 1698, 1588, 1928; mean=1738.000

gross collection delta:       +35.333 (+2.08%)
confirmed delivery delta:     +88.667 (+5.38%)
delivered-stone mean:         828.000 -> 938.000 (+110.000, +13.29%)
accessible-stock mean:        1234.000 -> 1488.000 (+254.000)
wood mean:                    741.333 -> 713.333 (-28.000)
gold mean:                    80.000 -> 86.667 (+6.667)
mean travel:                  23365.167 -> 24515.500 px (+4.92%)
deaths:                       0 versus 0
failure runs:                 3 versus 3
acceptance:                   passed
```

The controls are `gloryhill_4b_return_control_001_20260718` through `_003`; candidates are `gloryhill_4b_return_final_candidate001_20260718` through `candidate003` under `Artifacts/aib_gym`. The exact comparator output is `Artifacts/aib_gym/gloryhill_4b_return_final_comparison_20260718.json`. Candidate delivery equaled collection in all three runs; control delivery gaps were `80/80/0`. This is the important conservation result even though the comparator's primary gross-collection gate moved only `+2.08%`.

Focused runtime evidence remains distinct from the cohort. `gloryhill_4b_return_stableentry_smoke_20260718` completed 3,000 ticks with `1608` collected/delivered, `938` stone, `80` gold, zero deaths, and no failure flag. `gloryhill_4b_return_finalmechanism_smoke_20260718` recorded the bounded corner-rejoin, wall-hold, surface-exit, and later store sequence on the retained mechanism. The required mirrored-overhang regression passed `1/1` with `DONE` in `../../Logs/console-26-07-18-08-15-49.txt`. `stone_builder_collects_loose_stone_near_quarry_when_tiles_unsafe` also passed with `DONE`; the separate quarry-build fixture physically created the supported quarry but its localhost simulation froze at tick 35, so that launch is runtime-inconclusive rather than a pass or failure.

Two experiments were rejected and removed. Per-fall high-water realignment generated hundreds of repeated events and an approximately 800-tick oscillation. A bounded 12-tick wall retry reduced the comparable 3,000-tick stone result from `938` to `266`. Do not restore either mechanism from the diagnostic artifacts. The retained candidate still has one latched failure flag in every full episode, so the remaining monitor/path signal is follow-up work rather than hidden by the acceptance result.

### Bounded underground-retarget follow-up

The later `untitled.png` failure was a separate outbound route-erasure deadlock: a strict fresh-surface search failed after the miner was underground, the mutable corner became zero, and custom pathing repeatedly targeted deeper ore through dirt that was correctly excluded from off-route mining. Production now continues the retained shaft only when the exact deeper two-wide shaft/two-high tunnel passes every existing terrain, barrier, no-build, bedrock, and castle gate; otherwise it preserves the return identities, clears the target/path, and surfaces below quota.

Event-logged `Artifacts/aib_gym/gloryhill_4b_route_continue_diag_20260718.tcpr.txt` exercised both decisions on official Gloryhill, fully delivered 1,466 material with zero deaths, and contains none of the baseline's `destination=228,396`, `next=216,368`, `next=192,384`, or `tile=224,392` signatures. Fresh EventLog-off candidate `gloryhill_4b_route_continue_candidate_001_20260718` fully delivered 1,660 material with zero deaths and four productive slots. Both retained the known bit-1 recoverable motion-stall signal. The candidate is one fresh sanity episode with a differing fingerprint component, not an exact control/candidate cohort, a statistical improvement claim, or evidence of failure-free navigation.

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

### Strategy wave schema and accepted survival matrix

Strategy waves emit `[AIBEVT] source=strategy action=wave_result` records from `Scripts/AIBStrategyWaveHarness.as`. Fixture version 4 / driver `grounded_candidate_corridor_v4_exclusive_spawn_outcomes` requires:

- one production worker plus seven attackers at most (`ai_actor_cap=8`);
- a fresh official-map process, canonical pre-intervention fingerprint, and separate measurement-start fingerprint;
- deterministic knight, archer, bomb, or mixed composition for seed `101`, `211`, or `307`;
- real production archer shots and stock server-created bombs where applicable;
- local approach and attack contact, plus a physical control crossing;
- exact measured-plan task coordinates retained across later replans;
- spawn-indexed, mutually exclusive attacker crossing/death outcomes; and
- friendly route and builder-death gates in addition to censor-aware breach timing and crossings.

The engine may call rules `onBlobDie` repeatedly for one blob. `duplicate_death_callbacks`, `post_cross_deaths`, and `duplicate_bomb_callbacks` expose that behavior, while `outcomes_resolved` counts only the first mutually exclusive outcome for each spawn index. `Tools/compare_aib_wave_results.ps1` rejects any v4 row unless `crossings + enemy_deaths == outcomes_resolved <= spawned`; it also rejects invalid pressure, composition, arrow/bomb, route, and fixture contracts. Driver-v3 rows use the older overlapping callback semantics and cannot share a cohort with driver v4.

Final build-4762 collection (2026-07-18): `Artifacts/aib_gym/wave_v4_bombsafe_20260718_*.tcpr.txt`, exactly 48 trials / 24 pairs on official 8x_Gloryhill. All strict acceptance gates passed.

```text
overall mean first-breach delta:  +46.708 ticks
overall mean crossing delta:       -1.875
overall builder-death delta:        0.000
overall friendly-route penalty:     0.000
accepted pairs:                    24 / 24
```

The left-side scenario deltas were knight `+15.667/0`, archer `+15.000/0`, bomb `+15.667/-1.000`, and mixed `+13.667/-2.000` for first breach/crossings. The right-side deltas were knight `+148.333/-4.333`, archer `+15.000/0`, bomb `+135.333/-4.667`, and mixed `+15.000/-3.000`. Every value is a three-seed mean and every scenario had zero builder-death increase.

An earlier final-driver left cohort is intentionally rejected: bomb seed 211 killed the worker while it was still finishing a 7/9 emergency barrier. The production worker now retreats from activated enemy bombs within 128 pixels while preserving its job. The exact focused rerun and all 12 final bomb/mixed plan trials had zero builder deaths. This is evidence for the named seven-attacker local corridor, not every possible player siege.

Current metric status:

| Metric | Required authoritative outcome | Current foundation |
|---|---|---|
| Four-builder resource throughput | Same v4 resource record with four per-worker slots | Accepted initial shaft-return cohort: 942.667 -> 1574.000 mean delivery; final safe-quarry/refined-return cohort: 1649.333 -> 1738.000, zero deaths |
| Correct infrastructure near flag | Physical matching blocks near the flag plus traversable rear/home-side and front gates | Accepted Gloryhill schema-v1 cohort: 3/3 full physical passes on each team side |
| Protected accessible workshops | Same-team class workshop within a bounded tent/hall/tunnel route, with measured cover and real friendly traversal | Accepted 3/3 schema-4 passes per side for the pre-2026-07-20 72-task single-exit structure; the new roof-hatch geometry has a focused template/runtime pass but no refreshed physical cohort yet |
| Ally versus enemy traversal | Timed physical probes through the completed structure in both directions | Accepted friendly class-use/return plus gatehouse and workshop builder-pickaxe breach cohorts |
| Builder/base survival | Time-to-death/breach under knight, archer, bomb, and mixed attackers | Accepted 48-trial/24-pair fixture-v4 wave matrix; all semantic gates passed |
| Adversarial progression | Defender and attacker variants improve in alternating, map-matched rounds | Not implemented yet |

Every gym-owned resource episode is capped at eight total managed AI actors. The final 48-trial wave matrix runtime-verified the corresponding one-worker/seven-attacker cap on both sides and all four pressure types.

## Map comparison contract

The cohort key is:

```text
fixture_id + fixture_version + map_hash + dimensions + team + side
+ metric + builder_count + order + duration
```

This is deliberately map-scoped. The initial terrain hash and world fingerprint are retained as audit/stratification fields because KAG can mutate transient terrain and blobs during normal map startup; requiring byte-identical delayed snapshots would reject repeated trials of the same official map. Never pool scores across different map hashes or let a candidate choose its mapcycle.
