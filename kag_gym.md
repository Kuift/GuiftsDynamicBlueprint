# KAG Gym Plan

Start with [START_HERE.md](START_HERE.md) and [GOAL_HANDOFF.md](GOAL_HANDOFF.md).
This document retains the gym architecture and historical execution/evidence
trail; its older queue items and passes are not current-source acceptance.

## Purpose

KAG Gym is a deterministic, server-authoritative evaluation system for AI builders and the strategic blueprint director. Its job is to turn failures such as “does nothing,” “jumps in place,” “cannot mine,” “cannot build,” or “chooses a harmful plan” into short reproducible episodes with a machine-readable diagnosis.

The gym is not a reinforcement-learning environment yet. KAG is the authoritative simulator. Offline tools may rank code/configuration variants only after their metrics predict repeated in-engine outcomes.

## Current Execution Queue

Current runtime milestone (2026-07-18): fixture-v4 adversarial survival and the final supported-quarry/refined stone-return cohort are accepted on official 8x_Gloryhill. The final `wave_v4_bombsafe_20260718_*` collection contains exactly 48 fresh-process trials / 24 control-plan pairs across both team sides, knight/archer/bomb/mixed pressure, and seeds 101/211/307. All strict semantic gates passed: mean first breach moved by +46.708 ticks, crossings fell by 1.875, builder-death delta was zero, and friendly-route penalty delta was zero. The later resource cohort raised mean confirmed delivery `1649.333 -> 1738.000` and eliminated every end-of-run collection/delivery gap while preserving zero deaths. See `AIB_GYM_METRICS.md` and `GOAL_HANDOFF.md`.

The reproduced return-corner routing lock is now closed by centered two-column rejoin plus bounded vertical ownership. The 3,000-tick official-Gloryhill diagnostic delivered all 1,608 collected material with four productive slots, zero deaths, and `failure_flags=0`; the current visible 65-scenario suite also ends 65/0. The next metric milestone is a fresh exact EventLog-off three-run current-code cohort only if a throughput or failure-rate improvement is to be claimed, followed by the remaining public telemetry and real multiplayer boundaries. Two instrumented left-workshop diagnostics both reproduced the fast 408-tick route, not the earlier 1622-tick arm, so that variance remains observational follow-up rather than a production-change target. The accepted routing, wave, and resource evidence is not a claim that the mod is public-test-ready.

This is the order of work. Do not spend another milestone polishing test presentation while a higher-priority real behavior is broken.

1. Real builder primitives: selected tree, exposed stone, obstructed stone, material retrieval, one supported block, door/platform, recovery ladder, repair. The current visible suite covers these production paths, including physical stone continuation/abort and the staged supported ladder; sustained CTF metrics remain separate from focused fixture proof.
2. Resource lifecycle: home/crate deposit, crate retrieval, full-crate overflow, shortage recovery, no-home safety. Overflow production behavior and the corrected fixture compile. The fixture now settles nine one-slot entries, proves the prospective stone cannot fit with `canPutItem`, and only then starts delivery; its latest focused run stalled at tick 7 before the purchase, so physical overflow remains unproved. Stone runners no longer reclaim completed crated deliveries as fresh base supply. Existing workshops are now associated with the exact resource base through a bounded, same-barrier-side deterministic selector shared by storage delivery and stone-supply waiting; a remote same-team shop can no longer suppress a usable local workshop. Mixed overflow funding counts only spendable inventory and is transactional across builder/home storage. Strategic flag ownership is separated from tent/hall resource capability: static contracts cover runner suspension/free-provisioning suppression with only a flag left and full plan cancellation when every strategic home is gone. Director shortage pressure, executor retrieval, and the advanced UI share the same near-home loose-material and grounded-base-crate stock boundary. That shared boundary excludes loose stacks, storage points, and crates across an active barrier using the same normalized zone helper as executor targeting. Assigned runners also use the exact observed home on multi-base maps rather than silently switching to a nearer uncounted base. Static/runtime-ready fixtures cover remote inventory, cross-barrier stock, multi-home identity, and remote-shop rejection; broader live verdicts remain.
3. Multi-builder construction: deterministic roles, reservation handoff, support-first sequencing, no duplicate work, full small-plan completion. Accepted player-issued jobs atomically take durable manual ownership and are excluded from automatic assignment until auto direction is explicitly re-enabled; unknown overseer packet opcodes are rejected before ownership mutation. Automatic roles require executable AI work: empty/completed/cancelled/suggestion-only plans retire safe workers immediately and latch in-flight episodes for brain-side retirement at the next target-free boundary. Ordinary role changes are also brain-consumed at that boundary, applying the latest valid pending role before the old find state can start another episode and clearing stale controller intent without losing the home pin. Static/runtime-ready coverage includes validation ordering, deferred-role application, reservation/pending-role/path/home cleanup, no-work immediate/deferred retirement, bootstrap suppression, and Autobuilder isolation, while live KAG validation remains.
4. Director fixtures: simultaneous full completion of mirrored inward plans, full uneven near-edge blocked-primary fallback completion, exact scarce-storage scoring, emergency selection under collapse pressure, damaged-front retention, full selected-plan completion, mirrored sealed-bootstrap rejection, and full no-build/occupied/barrier fallback completion now have visible suite verdicts. Real multiplayer/editor, restart, and broader CTF acceptance remain separate requirements.
5. Outcome/cost capture: schema v3 covers attributed outcomes, accepted blueprint/director actions, director-shop purchases, and plan/task boundaries plus an offline raw episode summary. Generic hits, explicit pickup/drop, non-director purchases, and runtime validation remain.
6. Strategy evaluation: shared scoring, fixture/version/team/side/seed cohort identity, fresh-process reset isolation, live measurement fingerprints, representative both-side fixtures, and the canonical 48-trial/24-pair adversarial matrix are complete for fixture v4. Further strategic changes must preserve that validated cohort contract.
7. Public learning loop: retention/notice, task segmentation, matched human/AI comparisons, evidence-driven code/weight changes.

Immediate gate: do not turn the clean 3,000-tick routing diagnostic into a throughput claim. Any such claim requires a fresh exact three-run EventLog-off current-code cohort; public-test readiness additionally requires the moderator telemetry lifecycle and real late-join/editor team/spectator boundaries.

Runtime boundary discovered during implementation: AIBTest itself can freeze or
prematurely freeze its retained fixture while the same builder behavior works in
normal CTF. Keep short deterministic contracts in AIBTest, but run sustained
harvesting, mining, pathing, construction, and director acceptance in visible
CTF. Never change production AI solely from an AIBTest-only freeze.

Operator boundary as of 2026-07-14: visible KAG runtime windows are permitted. Use the normal player-facing CTF mode and the same map for initial evidence, prioritize high-value director behavior, and close KAG immediately after every completed or failed run unless actively iterating with reload/TCPR.

Latest focused evidence:

- Return-corner routing: `Artifacts/aib_gym/gloryhill_4b_centered_bounded_corner_diag_20260718.tcpr.txt` ran 3,000 ticks, delivered all 1,608 collected material (`590` wood, `938` stone, `80` gold), kept all four slots productive, and ended with zero deaths and `failure_flags=0`. Both stone workers completed assist/rejoin/wall/surface/exit sequences. The centered-only predecessor still hung for 1,646 ticks and the above-surface ore gate regressed to 638/638 with flags 33, so both variants were rejected. This is focused causal evidence, not a cohort.
- Current AngelScript regression: `../../Logs/console-26-07-18-16-07-39.txt` contains all 65 starts/verdicts and `[AIBTEST] DONE passed=65 failed=0`. The route fixture passed at tick 463, the seven-tile staged-ladder fixture at tick 288, and the fixture-scoped blueprint-conservation case at tick 193.
- Final adversarial matrix: `Artifacts/aib_gym/wave_v4_bombsafe_20260718_*.tcpr.txt` contains exactly 48 fixture-v4 trials / 24 pairs. The strict comparator accepted all pairs across both sides, four pressure types, and three seeds. Overall mean deltas were +46.708 first-breach ticks, -1.875 crossings, zero builder deaths, and zero friendly-route penalty. The exclusive spawn-index outcome contract prevents duplicate build-4762 `onBlobDie` callbacks from inflating deaths; every trial satisfied its bounded outcome invariants.
- Focused bomb-safety replay: `wave_v4_bombflee_plan_left_bomb_s211_20260718` reproduced the earlier plan-worker exposure and then completed with zero builder deaths after the production worker learned to retreat from activated enemy bombs. It retained the same breach tick and all seven resolved attacker outcomes; this is the focused causal evidence behind the final matrix, not a substitute for it.
- Fallen-log watchdog diagnostic on official 8x_Gloryhill: `gloryhill_log_path_trace_001` (`console-26-07-15-06-23-37.txt`) retained a nominal three-waypoint route to a settled log, replanned every 21 ticks, waited 301 target-owning ticks, delivered 190 wood only at episode tick 1200, and latched one motion-stall flag. With only the post-target watchdog reduced to 90 ticks, `gloryhill_log_watchdog_candidate_001` (`console-26-07-15-06-28-18.txt` plus correlated TCPR result) abandoned an unproductive log after 91 ticks, continued the episode, delivered 190 by episode tick 900, and finished the 1200-tick smoke with no failure. The pre-target log-spawn wait is unchanged. This is mitigation evidence, not a full `resource_collection_180s` cohort result.
- Full watchdog cohort on the same official map: 300-tick control runs collected 850/550/490 wood (mean 630); 90-tick candidates collected 550/540/550 (mean 546.667). Deaths were zero and all three runs were failure-flagged on each side. The candidate failed the gate and production retains 300 ticks.
- Current physical-recovery cohort on the same comparator key: `gloryhill_narrowdrop_candidate_1b_009/_010/_011` collected 800/550/550 (mean 633.333), with zero deaths and zero failure-flagged runs. Against the retained controls, the strict comparator reported `CollectedDelta=3.333`, failure runs 3→0, and `AcceptancePassed=true`. These runs retain the 300-tick watchdog; they validate the route changes, not an earlier timeout.
- Focused route evidence: `gloryhill_downclear_trace_003` retained open-drop steering, released it at `(909,284)` when the adjacent thickstone/bedrock wall became real, engaged corner recovery 13 ticks later, crossed, felled the target tree, and processed its logs without a failure. The mirrored diagonal-only overhang fixture passed at tick 138 with both full 36-tick drives, cooldown latches, and one-tile displacements. A later deep-log failure at `(1289,336)` exposed a two-tile shaft whose adjacent drop is open despite an opposite far wall; the current narrow-drop exception removed failure flags across the three full candidates, but an event-logged run did not land the identical log and must not be presented as a matched focused replay.
- Four-builder spawn and source boundary: the original clear/grounded spawn near `(119,340)` was a sealed shelf and invalidated that episode. Current stable slots use a home-connected grounded flood plus full-set backtracking at `140,292;52,284;36,292;20,300`. Remote enemy-side `mat_stone` is rejected unless it is local or an exact-base quarry/home source. Quarry placement now reuses the supported five-column base-workshop site search, and tagged output that escapes the exact supported quarry boundary is rejected. The isolated loose-stone case has a complete PASS/DONE. The separate quarry-build launch physically created the supported quarry and then froze at tick 35 before a verdict; it is inconclusive, not a pass.
- Flag contamination boundary: `gloryhill_4b_scoped_baseline_002` was aborted after the user visibly observed slot 2 capture and return the enemy flag; the guard restored flag 48 and emitted a contamination record. The shared CTF pickup override now excludes `aibuilder` and `autobuilder`, and two later controls plus all three candidates completed without contamination.
- Four-builder shaft-return cohort: controls `gloryhill_4b_scoped_baseline_001/_003/_004` delivered 936/1066/826 (mean 942.667). Candidates `gloryhill_4b_stone_return_candidate_001/_002/_003` delivered 1716/1438/1568 (mean 1574.000), a +631.333 gain, with zero deaths and four productive slots throughout. Diagnostic `gloryhill_4b_stone_return_candidate_trace_003` recorded both stone workers climbing from y=336/344 to the surface and delivering repeated loads. Failure masks improved from 33 to 1, but every episode on both sides still had at least one latched failure run.
- Final safe-quarry/refined-return cohort: fresh controls `gloryhill_4b_return_control_001_20260718` through `_003` averaged 1702.667 collected and 1649.333 delivered. Final candidates `gloryhill_4b_return_final_candidate001_20260718` through `candidate003` averaged 1738.000 collected and delivered, `+88.667` confirmed delivery and `+254` accessible stock. Delivered stone rose `828 -> 938`, deaths stayed zero, and failure runs stayed `3/3 -> 3/3`. The strict comparator passed; `Artifacts/aib_gym/gloryhill_4b_return_final_comparison_20260718.json` preserves the exact result. Stable surface-entry and saved-corner identity plus a topology-qualified centerline/wall climb remove the undelivered deep load, but do not yet remove the monitor flag.
- Bounded underground-retarget correction: baseline `gloryhill_4b_return_final_stalldiag_20260718` showed two miners erase their local corner and loop for thousands of ticks toward deeper ore through excluded dirt. The retained code continues the old shaft only through an exact legal deeper route, or aborts below quota while preserving the surface anchor/corner. Current route fixture `86e2ec208e27` and the full suite passed the mined continuation plus physically surfaced blocked control at tick 463; mandatory mirrored regression `033932ab1f1f` passed both complete cycles and cooldowns at tick 138. Event-logged `gloryhill_4b_route_continue_diag_20260718` exercised both boundaries, fully delivered 1,466 with zero deaths, and lost every old stuck-route signature. The later centered/bounded-corner diagnostic fully delivered 1,608 with zero deaths and no gym flags. These are focused causal diagnostics, not a new throughput cohort.
- `gloryhill_control_1b_002` in `console-26-07-15-05-37-30.txt`: complete schema-v4 `resource_collection_180s` result on official 8x_Gloryhill, one team-0 wood builder, 850 collected/delivered, 650 accessible-stock delta, zero deaths, one latched recoverable motion-stall flag.
- Earlier resource records in that log are intentionally excluded: schema v2 conflated transfer with collection; schema v3 exposed a direct-inventory acquisition blind spot. Schema v4 reconciles confirmed per-worker delivery as a conservative collection lower bound.

- `damaged_owned_tile_is_repaired_without_replacing_neighbors`: complete PASS/DONE in `console-26-07-10-17-32-06.txt`.
- `full_crate_creates_grounded_overflow_storage`: `console-26-07-14-10-04-11.txt` proved nine settled 1x1 entries while `isFull()` incorrectly remained false. The corrected `canPutItem` run compiled and passed its readiness gate in `console-26-07-14-10-09-19.txt`, then the localhost simulation stalled at tick 7 before `buy_storage_crate`. This is runtime-inconclusive, not a PASS or a production failure.
- Real CTF generated-support/handoff: PASS in `console-26-07-10-17-03-04.txt`.
- Real CTF return overhang: the earlier open regression remains historical. Authoritative mirrored fixture `033932ab1f1f` now proves both complete 36-tick cycles, both 90-tick cooldowns, one-tile displacement on each side, and intact traps; the official-map centered/bounded-corner diagnostic proves the later surface return.

## Completion Definition

The gym is complete enough for public-server tuning when it can:

- reset a named fixture to a canonical state and record fixture/version/team-side fingerprints;
- execute real production AI/director code without fixture-only shortcuts for the behavior under test;
- capture player demonstrations and AI decisions server-side without usernames or chat contents;
- detect lack of intent, lack of motion, repeated jumping, path thrash, target thrash, resource deadlocks, invalid construction, route damage, and strategic regressions;
- emit a compact failure window plus episode summary, not only a timeout;
- replay or reconstruct the relevant world/action sequence from a versioned event schema;
- compare control and candidate runs across both team directions and multiple seeds;
- gate changes on safety invariants before optimizing performance;
- retain raw evidence so a future agent can estimate which code/configuration “weights” should change.

## Architecture

### 1. Fixture layer

`AIBTestScenarios.as` owns deterministic setup and teardown. Every fixture needs:

- stable `fixture_id` and integer `fixture_version`;
- explicit team side, seed, map dimensions, terrain hash, blob/resource manifest, barrier/no-build state, and initial blueprint/director mode;
- canonical spawn positions and a measurement-start fingerprint captured after warmup;
- a strict cleanup contract that removes fixture blobs, selections, reservations, and temporary rules values.

Generated fixtures should cover flat ground, uneven bases, pits, cliffs, overhangs, ladders, doors, water, map edges, sealed caves, destructible dirt plugs, bedrock, no-build sectors, red barriers, occupied workshops, full crates, scarce materials, enemy line-of-sight, and collapsing defenses. Mirror each navigation/strategy fixture rather than assuming left/right symmetry.

### 2. Driver layer

Drivers issue intents through the same server APIs used in play:

- overseer wood/stone/build orders;
- blueprint human deltas, prefabs, suggestion acceptance, and director mode changes;
- shop purchases and resource deposits;
- scripted threat/wave timing.

Director tests must never wait silently for a human to buy a worker. Interactive CTF checks use `!aib_director_test`, which enables automatic strategy and creates a same-team test worker if none exists. The production-bootstrap scenario is stricter: it begins with no worker and passes only when production director code safely provisions and assigns one.

Public servers configure CTF startup mode and free-bootstrap enablement in `Rules/CommonScripts/AIBDirectorPolicy.cfg`. Moderators can override the free-bootstrap policy for their current team with `!aib_bootstrap on|off|status`; the command intentionally preserves the consumed-round latch and retry deadline so it cannot become a worker-spawn fountain.

Fixture code may create the initial world, but must not directly set a success side effect that production code is supposed to cause. Any unavoidable fixture shortcut must be declared in the episode record.

### 3. Observation layer

Use three synchronized streams:

- Event stream: state/target/reservation/path/build/resource/player-input transitions (`[AIBEVT]`).
- Sample stream: bounded periodic snapshots of position, velocity, aim, held inputs, inventory totals, task state, destination, path state, and nearby hazards.
- Outcome stream: episode summary with completion, elapsed ticks, materials, damage, deaths, route preservation, and failure classification.

In public CTF, the first latched monitor violation per AI builder is also emitted as a compact numeric `[AIBGYM]` v1 line. It records builder/team ids, failure bitset, state, position/tile target, movement, jump, replan, interaction, target-change, outcome-change, and invalid-build counters. New records also append the current movement destination and target-blob id/position; the parser keeps those fields nullable so older v1 logs remain readable. A ring buffer then emits one `[AIBGYMW]` v1 binary/base64 record with up to 30 pre-failure and 12 post-failure samples at five-tick spacing. `Tools/parse_aib_gym_failures.ps1` and `Tools/parse_aib_gym_windows.ps1` export both forms to NDJSON. These are rare first-failure artifacts, not per-tick snapshot strings.

`Scripts/AIBPlayerActionLog.as` is the first public-server demonstration stream. It writes compact binary delta records to an in-memory batch and emits one base64 transport envelope approximately every ten seconds or 2 KiB. There are no per-player/per-frame log strings. KAG console logs are the append-only storage available to scripts; offline tools restore the binary records and export versioned NDJSON. Raw usernames, IPs, chat, and free-form messages are deliberately excluded.

Schema v3 retains the v1 lifecycle/input/aim/equipment/motion records and v2 outcome records:

- kind 5: tile mutation with actor, attribution confidence, tile coordinate, old tile, and new tile;
- kind 6: important blob creation with actor, confidence, blob/team/category, hashed name, and position;
- kind 7: death with victim, killer, blob/team/category, hashed name, and position;
- kind 8: changed-only wood, stone, gold, arrows, explosives, and coin totals behind a field mask.
- kind 9: accepted human blueprint/director action, director-shop purchase, or production plan/task boundary with exact producer tick, actor kind/id, subject, team, tile, detail, and value;
- kind 10: explicit count of boundaries dropped by the bounded queue.

Attribution confidence is numeric and explicit: 3 is engine damage-owner attribution, 2 is a nearby player actively pressing an action, 1 is a nearby passive player, and 0 is unattributed. Do not silently treat proximity inference as ground truth. `Tools/parse_aib_player_actions.ps1` decodes v1-v3. `Tools/summarize_aib_player_episodes.ps1` segments actor-local activity using spawn/leave/death and a 150-tick idle gap, then emits raw build/mine/harvest/combat/planning/director/traverse episode components, accepted-boundary counts, attribution-weighted outcomes, low-confidence counts, a privacy-safe coarse context key, and a versioned estimated cost. Raw fields remain authoritative; the task label, idle estimate, context bucket, attribution weight, and scalar cost are heuristics.

The v3 AngelScript hooks are now KAG-runtime compiled. `console-26-07-14-07-53-21.txt` contains two interval batches; the parser decoded 47 schema-v3 records including episode, join, spawn, inventory, motion, blob creation, and a production `plan_publish` boundary. Generic hit/pickup/drop producers and moderator transition/notice UX remain acceptance work. The parser, v1-v3 fixtures, boundary contract, and episode summarizer also pass deterministic PowerShell regressions.

### 4. Assertions and online monitors

Assertions should distinguish these layers:

- Intent: job exists, state is compatible, target/destination is valid, reservation belongs to the builder.
- Motion: displacement and distance-to-goal improve within a state-specific window.
- Interaction: hits, pickups, deposits, placements, or purchases occur when in range.
- Outcome: resource delivered, tile/blob built, plan progressed, threat delayed, or route preserved.

Online monitors maintain rolling windows rather than waiting for one global timeout:

- `no_intent`: idle/no job after a valid command and grace period;
- `state_stall`: unchanged state with no relevant side effect;
- `motion_stall`: commanded movement with negligible displacement;
- `jump_loop`: excessive up-key/jump edges without vertical or horizontal progress;
- `path_thrash`: repeated replans or direct/path mode changes with no distance improvement;
- `target_thrash`: target changes exceed a limit without interaction;
- `resource_deadlock`: required material exists accessibly but shortage/state does not improve;
- `reservation_deadlock`: expired/dead-owner reservation blocks work;
- `invalid_build`: repeated placement attempts at permanently invalid support/occupancy;
- `route_regression`: protected friendly route becomes materially worse;
- `unsafe_work`: builder/resource is repeatedly exposed to reachable enemy pressure.

On first violation, freeze a pre/post diagnostic window containing approximately 150 ticks before and 60 ticks after the trigger, then fail with the specific monitor and the smallest useful state dump.

### 5. Episode evaluator

Hard constraints are evaluated before any scalar score:

- no enemy-team data/control leak;
- no placement in no-build/barrier/protected areas;
- no unbounded free-worker/resource creation;
- no destructive route beyond the validated mining/build corridor;
- no dropped/vanished owned resources;
- no live reservation owned by a dead builder after cleanup grace;
- deterministic outcome for identical fixture/version/side/seed/code.

For valid episodes, record a cost vector rather than hiding tradeoffs in one number:

```text
completion_penalty
elapsed_ticks
idle_ticks
stalled_ticks
jump_without_progress
replans_without_progress
target_changes_without_effect
builder_deaths
material_spent
friendly_route_penalty
plan_damage_cost
enemy_crossings
breach_tick_censored
```

A scalar ranking may be computed offline from a versioned weight set, but raw components remain authoritative. Safety constraints are never traded away for a lower scalar cost.

### 6. Artifact and schema layer

Every run must identify:

- `schema_version`, `code_revision` (or dirty-worktree fingerprint), KAG build when available;
- fixture id/version, team side, seed, scenario, driver version;
- initial and measurement-start fingerprints;
- director template/score terms and configuration version;
- ordered events/samples and final cost vector;
- pass/fail/censored/stale status and failure classifier.

Artifacts should be append-only NDJSON grouped by run id. Parser changes must remain backward compatible or ship a migration. Server logs are source evidence; derived CSV/summary reports are disposable.

## Player Demonstration Capture

The goal is to learn useful builder behavior from public matches without recording identity or conversation.

Capture server-observed transitions for movement, jump/use/attack buttons, relative aim tile, class, build selection, carried object, position, and velocity. Only changed fields are encoded. Aim is tile-quantized and sampled at most every five ticks; every button edge carries the current aim. A small periodic position/velocity delta makes long holds and authoritative motion recoverable. Batches use numeric record/field flags rather than repeated field names.

Also instrument outcome events at authoritative mutation points:

- tile/blob build and destruction, hit type and target category;
- pickup/drop/storage transfer and shop purchase;
- class change, spawn, death, flag/tent proximity, and resource totals;
- blueprint/director commands and AI-builder orders.

Do not collect usernames, IP addresses, chat, or raw client files. `AIBTelemetryPolicy.cfg` supplies the built-in once-per-connection notice and startup default; moderators can disable capture with `!aib_telemetry off` without having it silently reactivate next round. The mod flushes before disable and separates a later enable into a new episode. Console logs may contain unrelated server identity/chat outside `[AIBACT]`, so `PUBLIC_SERVER_OPERATIONS.md` defines host-owned access, rotation, retention, export, and deletion procedures. Network IDs are episode-local actor identifiers, not durable player profiles.

Demonstrations are not copied blindly. Segment builder play into tasks (harvest, mine, traverse, build support, erect defense, repair, retreat), derive the same cost vector used for AI, and compare only within matched world contexts.

`Tools/compare_aib_task_episodes.ps1` compares baseline and candidate cohorts only when `context_key_v1` matches and both sides meet the default three-episode minimum. It reports raw success, cost, duration, idle, travel, jump, death, material, attribution-weight, and low-confidence deltas. Quality gates are opt-in because the current context key and episode boundaries are heuristic; never deploy a code/weight change from the scalar cost alone.

## Scenario Matrix

### Behavior micro-fixtures

- Command acceptance: wood, selected wood, stone, selected stone, build, suggestion acceptance.
- Locomotion: flat, one-tile step, wall jump, ladder, door, platform, pit, water, overhang, map edge.
- Mining: exposed stone, dirt plug, reusable shaft, cross-tunnel, gold diversion/return, bedrock rejection, mirrored corner escape.
- Building: single supported tile, backwall-before-ladder chain, door orientation, platform, workshop footprint, unreachable/unsupported tile, repair/rebuild.
- Resources: carried stack, inventory stack, home deposit, crate retrieval, full-crate overflow, missing home, scarce split materials.
- Threat: visible knight/archer, blocked ray, resource near enemy, interrupted work, safe retreat and resume.

### Coordination fixtures

- deterministic assignment for 1/2/4 builders;
- no duplicate reservation and prompt death/disconnect release;
- material-role balancing and handoff from gathering to construction;
- human blueprint priority over AI desired/work layers;
- suggestion mode remains non-autonomous until accepted;
- first-worker provisioning guard, safe spawn, blocked-site retry cooldown, one-per-round latch, and round reset in both team directions.

### Director fixtures

- both sides on flat, asymmetric, narrow, tall, edge, occupied, no-build, barrier, scarce-resource, and collapsing-frontline bases;
- valid publication plus at least one real physical completion;
- invalidation, hysteresis, emergency replacement, damage/replan, and full-plan completion;
- paired control/plan waves for knight, archer, bomb, and mixed pressure.

Minimum strategic evidence is 2 sides × 4 wave types × 3 seeds × control/plan = 48 trials (24 valid pairs). The pairing key uses fixture id/version, team, side, scenario, seed, and an equal canonical pre-intervention fingerprint. A separate post-warm-up measurement fingerprint records the realized control/treatment state; it is evidence to audit, not an equality key, because the plan is the intended intervention and may already have changed terrain and resources.

## Time-Efficient Test Tiers

1. Static checks (seconds): schema/source invariants, parser tests, deterministic offline simulator.
2. Micro gym (target under two minutes): intent, movement monitors, resource/build primitives.
3. Coordination gym: reservations, roles, multi-builder completion.
4. Strategic fixtures: production director on representative terrain.
5. Paired waves: expensive effectiveness matrix.
6. Manual visible acceptance: camera, UI clarity, natural play, fun, and multiplayer isolation.

Long physical actions use deadlines sized for the full interaction. In
particular, the selected-tree pipeline has 1,800 in-game ticks and may only pass
after felling, wood acquisition, and crate delivery; its fixture must not freeze
while the builder is still landing hits.

Run the cheapest tier affected by a change first. Shard long pathing cases so a stale KAG process does not hide unrelated regressions. Cache generated maps and manifests, but never reuse a mutated runtime world between paired variants.

For focused cases whose expected runtime is only a few seconds, set both launcher limits proportionally; for example `-TimeoutSeconds 20 -StaleSeconds 5`. `TimeoutSeconds` is only the outer deadline. Leaving the default 25-second stale window on a three-second case needlessly slows every failed iteration.

## Optimization Workflow

1. Ingest only schema-valid, fingerprinted, non-stale episodes.
2. Cluster failures by classifier and state/target/path signature.
3. Select the smallest code/configuration surface plausibly responsible.
4. Change one coherent behavior mechanism or versioned weight set.
5. Run affected micro/coordination fixtures, then the representative regression tier.
6. For strategic scoring changes, run the full paired matrix and compare the complete cost vector.
7. Accept only if hard constraints pass and improvements survive multiple seeds/sides without a material regression elsewhere.
8. Record before/after evidence and new engine quirks in `KAG_ENGINE_QUIRKS.md`.

Production weights and template metadata must have one source of truth consumed by both KAG and offline evaluators. The current duplicated abstract-simulator utility is transitional and cannot justify production tuning.

## Implementation Roadmap

### Phase A — observability foundation

- [x] Structured `[AIBEVT]` logging and monotonic sequence.
- [x] Test scenario start/pass/fail/done records.
- [x] AI state/target/path/resource and strategy events at key transitions.
- [x] Public CTF server-observed player action stream and NDJSON exporter.
- [ ] PARTIAL — authoritative outcome hooks: tile/blob/death/resource outcomes, accepted blueprint/director actions, director-shop purchases, and plan/task boundaries are implemented; visible CTF decoded a live production `plan_publish` boundary, while generic hit, pickup/drop, non-director purchase producers, and broader runtime boundary coverage remain.
- [ ] PARTIAL — versioned episodes: the offline `aib_task_episode_v1`/`estimated_cost_v1` summarizer deterministically counts accepted player boundaries, but AI motion/material joins and the full AI-equivalent cost vector remain.

### Phase B — failure monitors

- [ ] Reusable rolling observation buffer per builder.
- [x] Passive motion-stall, jump-loop, and path-thrash window monitors with first-failure latching.
- [ ] PARTIAL — active-job/no-intent, state-side-effect stall, and target-thrash monitors are implemented and statically contracted. `console-26-07-14-09-20-52.txt` exposed a state-stall false positive during a successful miner window with 25px displacement; state stall now also requires low displacement. Broader KAG runtime calibration remains.
- [ ] PARTIAL — accessible-resource, stale/dead-reservation, and invalid-build-retry monitors are implemented and statically contracted; KAG runtime calibration remains.
- [ ] PARTIAL — compact 30-sample pre/12-sample post diagnostic windows and strict parsing are implemented; classifier-specific runtime assertions and KAG calibration remain.

### Phase C — scenario depth

- [x] COMPLETE — dirt-plug recovery stages paid missing backwalls before ladder creation and emits one bounded post-placement BrainPath/mineable-node probe. The seven-tile fixture withholds its 100 wood until the runner reaches the obstruction face, then requires the paid chain, support before ladder, later accepted probe, exact post-ladder cost, unchanged two-column plug, and physical crossing. Authoritative hot run `eb3a6c62b0d8` and the current full suite passed at tick 288 with chain 3, ladder tile `349,68`, and 84 wood; mirrored-corner regression `033932ab1f1f` also passed both full cycles and cooldowns.
- [ ] PARTIAL — crate overflow, retrieval-source accounting, editor delta, and selection save/load coverage exist at different depths. Accessible stock, bounded same-base workshop reuse, transactional mixed funding, item-specific capacity, no-reclaim stone delivery, overflow conservation, server-authoritative idempotent editor mutation, same-team/spectator-targeted display transport, and an isolated inclusive/asymmetric selection round trip are statically covered and currently compile; physical overflow/retrieval, multiplayer editor delivery/non-delivery, and a process-restart PNG reload still need live KAG verdicts.
- [ ] PARTIAL — simultaneous mirrored left/right full completion, uneven blocked-primary full completion, asymmetric pressure, scarce-resource, damaged-front, full physical completion, mirrored sealed-bootstrap, blocked-site cooldown/round-reset provisioning, and exact no-build/occupied/barrier fallback fixtures are defined; live KAG verdicts remain.
- [x] Complete and reproduce the entire current suite with final `DONE` evidence: `../../Logs/console-26-07-18-16-07-39.txt` ended `[AIBTEST] DONE passed=65 failed=0`.

### Phase D — strategic evaluation

- [ ] PARTIAL — canonical pre-warm-up and measurement-start fingerprints are emitted from the same order-stable `w1` world manifest, covering terrain, no-build masks, blobs/inventories, barriers, blueprint layers, and plan/tasks. Fixture v4 runtime-validates both boundaries and uses a fresh visible KAG process for every matrix trial; broader AIBTest reset coverage still remains.
- [x] Fixture/version/team/side-aware comparator with exactly-one-variant pairing and a default three-seed minimum per cohort.
- [x] Deterministic 48-trial/24-pair NDJSON collection manifest with explicit fresh-reset requirements.
- [x] Live 48-trial/24-pair fixture-v4 dataset with fresh-process isolation and strict semantic gates (`wave_v4_bombsafe_20260718_*`).
- [x] Central scoring configuration shared by production and offline tools (`Rules/CommonScripts/AIBStrategyWeights.cfg`), with a 68-key static contract, production-accessible home-stock shortage pressure, and deterministic simulator regression. KAG runtime loading remains unverified.

### Phase E — public learning loop

- [ ] Runtime-validate the implemented server notice, persistent moderator control, retention/rotation runbook, and privacy review.
- [ ] PARTIAL — authoritative builder job/state/active changes publish immediately and receive a staggered five-second server heartbeat for bounded late-join HUD recovery; the source contract passes, but a real client must still join builders already in distinct roles.
- [ ] PARTIAL — heuristic task segmentation and a three-episode matched-context comparator exist; authoritative task boundaries, richer world context, and real human/AI cohorts remain.
- [ ] Evidence-driven weight/code proposals with regression reports.
- [ ] Manual multiplayer CTF acceptance before public release.

## Acceptance Gates

Do not call the mod public-test-ready until:

- the current suite completes reproducibly with `[AIBTEST] DONE` and no compile errors;
- focused stall/jump/path tests identify causes rather than only timing out;
- both team directions materially progress autonomous plans on representative fixtures;
- a valid 48-trial dataset demonstrates useful defense with bounded route and builder-loss regressions;
- telemetry is server-side, versioned, parseable, privacy-bounded, moderator-controllable, and tested;
- visible multiplayer CTF confirms understandable controls, correct team isolation, stable runtime behavior, and acceptable gameplay.
