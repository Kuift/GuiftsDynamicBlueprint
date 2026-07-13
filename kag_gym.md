# KAG Gym Plan

## Purpose

KAG Gym is a deterministic, server-authoritative evaluation system for AI builders and the strategic blueprint director. Its job is to turn failures such as “does nothing,” “jumps in place,” “cannot mine,” “cannot build,” or “chooses a harmful plan” into short reproducible episodes with a machine-readable diagnosis.

The gym is not a reinforcement-learning environment yet. KAG is the authoritative simulator. Offline tools may rank code/configuration variants only after their metrics predict repeated in-engine outcomes.

## Current Execution Queue

This is the order of work. Do not spend another milestone polishing test presentation while a higher-priority real behavior is broken.

1. Real builder primitives: selected tree, exposed stone, obstructed stone, material retrieval, one supported block, door/platform, recovery ladder, repair. Physical repair now has a complete focused pass; mining/pathing still need representative evidence.
2. Resource lifecycle: home/crate deposit, crate retrieval, full-crate overflow, shortage recovery, no-home safety. Overflow production behavior is implemented, but the corrected final fixture is not yet run.
3. Multi-builder construction: deterministic roles, reservation handoff, support-first sequencing, no duplicate work, full small-plan completion.
4. Director fixtures: mirrored inward selection, an uneven near-edge blocked-primary fallback, exact scarce-storage scoring, emergency selection under collapse pressure, damaged-front retention, and full selected-plan completion are defined through production paths but remain runtime-unverified. No-build and occupied representative fixtures remain.
5. Outcome/cost capture: schema v3 covers attributed outcomes, accepted blueprint/director actions, director-shop purchases, and plan/task boundaries plus an offline raw episode summary. Generic hits, explicit pickup/drop, non-director purchases, and runtime validation remain.
6. Strategy evaluation: shared scoring and fixture/version/team/side/seed cohort identity now pass static contracts. Canonical reset automation, live validation of measurement fingerprints, representative both-side fixtures, and 48 paired trials remain.
7. Public learning loop: retention/notice, task segmentation, matched human/AI comparisons, evidence-driven code/weight changes.

Immediate gate: the next behavior milestone is complete only when real production mining and blueprint building fixtures finish end-to-end. A synthetic detector test or a timeout with better logs does not satisfy that gate.

Runtime boundary discovered during implementation: AIBTest itself can freeze or
prematurely freeze its retained fixture while the same builder behavior works in
normal CTF. Keep short deterministic contracts in AIBTest, but run sustained
harvesting, mining, pathing, construction, and director acceptance in visible
CTF. Never change production AI solely from an AIBTest-only freeze.

Operator boundary as of 2026-07-10: do not launch visible KAG while the user is using the computer. Continue static architecture, telemetry, evaluator, and documentation work until the user explicitly permits runtime windows.

Latest focused evidence:

- `damaged_owned_tile_is_repaired_without_replacing_neighbors`: complete PASS/DONE in `console-26-07-10-17-32-06.txt`.
- `full_crate_creates_grounded_overflow_storage`: final fixture unrun. The prior advancing run failed correctly because identical material blobs merged and the crate was not full; do not cite it as a production overflow failure.
- Real CTF generated-support/handoff: PASS in `console-26-07-10-17-03-04.txt`.
- Real CTF return overhang: open regression in `console-26-07-10-17-28-51.txt`; longer exact-geometry recovery compiled but is unverified.

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

Fixture code may create the initial world, but must not directly set a success side effect that production code is supposed to cause. Any unavoidable fixture shortcut must be declared in the episode record.

### 3. Observation layer

Use three synchronized streams:

- Event stream: state/target/reservation/path/build/resource/player-input transitions (`[AIBEVT]`).
- Sample stream: bounded periodic snapshots of position, velocity, aim, held inputs, inventory totals, task state, destination, path state, and nearby hazards.
- Outcome stream: episode summary with completion, elapsed ticks, materials, damage, deaths, route preservation, and failure classification.

In public CTF, the first latched monitor violation per AI builder is also emitted as a compact numeric `[AIBGYM]` v1 line. It records builder/team ids, failure bitset, state, position/target, movement, jump, replan, interaction, target-change, outcome-change, and invalid-build counters. A ring buffer then emits one `[AIBGYMW]` v1 binary/base64 record with up to 30 pre-failure and 12 post-failure samples at five-tick spacing. `Tools/parse_aib_gym_failures.ps1` and `Tools/parse_aib_gym_windows.ps1` export both forms to NDJSON. These are rare first-failure artifacts, not per-tick snapshot strings.

`Scripts/AIBPlayerActionLog.as` is the first public-server demonstration stream. It writes compact binary delta records to an in-memory batch and emits one base64 transport envelope approximately every ten seconds or 2 KiB. There are no per-player/per-frame log strings. KAG console logs are the append-only storage available to scripts; offline tools restore the binary records and export versioned NDJSON. Raw usernames, IPs, chat, and free-form messages are deliberately excluded.

Schema v3 retains the v1 lifecycle/input/aim/equipment/motion records and v2 outcome records:

- kind 5: tile mutation with actor, attribution confidence, tile coordinate, old tile, and new tile;
- kind 6: important blob creation with actor, confidence, blob/team/category, hashed name, and position;
- kind 7: death with victim, killer, blob/team/category, hashed name, and position;
- kind 8: changed-only wood, stone, gold, arrows, explosives, and coin totals behind a field mask.
- kind 9: accepted human blueprint/director action, director-shop purchase, or production plan/task boundary with exact producer tick, actor kind/id, subject, team, tile, detail, and value;
- kind 10: explicit count of boundaries dropped by the bounded queue.

Attribution confidence is numeric and explicit: 3 is engine damage-owner attribution, 2 is a nearby player actively pressing an action, 1 is a nearby passive player, and 0 is unattributed. Do not silently treat proximity inference as ground truth. `Tools/parse_aib_player_actions.ps1` decodes v1-v3. `Tools/summarize_aib_player_episodes.ps1` segments actor-local activity using spawn/leave/death and a 150-tick idle gap, then emits raw build/mine/harvest/combat/planning/director/traverse episode components, accepted-boundary counts, attribution-weighted outcomes, low-confidence counts, a privacy-safe coarse context key, and a versioned estimated cost. Raw fields remain authoritative; the task label, idle estimate, context bucket, attribution weight, and scalar cost are heuristics.

The v3 AngelScript hooks are not yet KAG-runtime compiled because visible windows are currently prohibited. The parser, v1-v3 fixtures, boundary contract, and episode summarizer pass deterministic PowerShell regressions.

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

Do not collect usernames, IP addresses, chat, or raw client files. Publish a short server notice before public deployment, define retention/rotation outside the mod, and let moderators disable capture with `!aib_telemetry off`. Network IDs are episode-local actor identifiers, not durable player profiles.

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
- first-worker provisioning guard, safe spawn, one-per-round latch, round reset.

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
- [ ] PARTIAL — authoritative outcome hooks: tile/blob/death/resource outcomes, accepted blueprint/director actions, director-shop purchases, and plan/task boundaries are implemented and statically tested; generic hit, pickup/drop, and non-director purchase producers remain, and v3 still needs a KAG runtime compile.
- [ ] PARTIAL — versioned episodes: the offline `aib_task_episode_v1`/`estimated_cost_v1` summarizer deterministically counts accepted player boundaries, but AI motion/material joins and the full AI-equivalent cost vector remain.

### Phase B — failure monitors

- [ ] Reusable rolling observation buffer per builder.
- [x] Passive motion-stall, jump-loop, and path-thrash window monitors with first-failure latching.
- [ ] PARTIAL — active-job/no-intent, state-side-effect stall, and target-thrash monitors are implemented and statically contracted; KAG runtime calibration remains.
- [ ] PARTIAL — accessible-resource, stale/dead-reservation, and invalid-build-retry monitors are implemented and statically contracted; KAG runtime calibration remains.
- [ ] PARTIAL — compact 30-sample pre/12-sample post diagnostic windows and strict parsing are implemented; classifier-specific runtime assertions and KAG calibration remain.

### Phase C — scenario depth

- [ ] Resolve `kag_path_mines_dirt_plug` with supported-chain and post-placement walkability evidence.
- [ ] Add crate overflow, crate retrieval, editor delta, and selection save/load coverage.
- [ ] PARTIAL — mirrored left/right and uneven blocked-primary fallback planner fixtures are defined; asymmetric pressure, scarce-resource, damaged-front, and full physical completion remain.
- [ ] Complete and reproduce the entire current suite with final `DONE` evidence.

### Phase D — strategic evaluation

- [ ] PARTIAL — canonical pre-warm-up and measurement-start fingerprints are emitted from the same order-stable `w1` world manifest, covering terrain, no-build masks, blobs/inventories, barriers, blueprint layers, and plan/tasks. AIBTest restores/validates terrain, tagged fixture/bootstrap blobs, plan ids, and director modes between scenarios. Live KAG validation and automatic fresh-trial reset remain.
- [x] Fixture/version/team/side-aware comparator with exactly-one-variant pairing and a default three-seed minimum per cohort.
- [x] Deterministic 48-trial/24-pair NDJSON collection manifest with explicit fresh-reset requirements.
- [ ] Live 48-trial paired dataset and semantic gates.
- [x] Central scoring configuration shared by production and offline tools (`Rules/CommonScripts/AIBStrategyWeights.cfg`), with a 68-key static contract, stored-resource shortage pressure, and deterministic simulator regression. KAG runtime loading remains unverified.

### Phase E — public learning loop

- [ ] Server notice, retention/rotation, moderator control, and privacy review.
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
