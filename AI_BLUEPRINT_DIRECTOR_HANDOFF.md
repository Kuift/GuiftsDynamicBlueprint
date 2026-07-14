# AI Blueprint Director Handoff

> The deterministic director prototype is implemented, and normal CTF now runs it in autonomous mode by default. Production-heartbeat coverage proves plan selection with no builder, guarded first-worker provisioning, deterministic assignment, task reservation, and physical completion of director-authored work. Strategic quality across representative maps and attacks is still unproven.
>
> Overall progress: **82%**. Treat `AI_BLUEPRINT_DIRECTOR_IMPLEMENTATION_STATUS.md` as the authoritative current checkpoint, evidence record, remaining acceptance gates, and future-agent resume guide. This document remains the design contract.

Updated: 2026-07-13

## 2026-07-10 Consolidated Resume Point

2026-07-13 addendum: the previous 62-file director checkpoint is committed as `3c29ff8`. A subsequent no-popup overflow audit fixed maxed-stack false merge capacity, added exact workshop-spawn refunds and two-cell no-build validation, strengthened the focused verdict to require actual in-crate delivery/conservation, and added `Tools/test_aib_overflow_storage_contract.ps1`. The mirrored corner fixture was also strengthened from a transient three-pixel nudge to two completed 36-tick cycles, latched cooldowns, and one-tile displacement, with `Tools/test_aib_corner_recovery_contract.ps1`. The new contracts and affected static regressions pass; no new KAG runtime evidence exists.

The next no-popup slice replaced the separate narrow `v2` initial and `m1` measurement hashes with a shared `w1` manifest and advanced the wave fixture contract to version 3. `Scripts/AIBWorldFingerprint.as` hashes terrain, tile-level no-build coverage, all live world blobs and inventories, barriers, director modes, blueprint layers, and task state using order-stable folds. Component hashes are included in wave evidence. `Tools/test_aib_world_manifest_contract.ps1` passes, but the new AngelScript include and full-map no-build scan are not runtime-compiled or performance-calibrated.

The following static-only slice extended AIBTest to 60 scenarios. `strategic_damaged_front_reactivates_without_plan_replacement` proves exact damaged-task reactivation while retaining plan identity, and `strategic_autobuilder_physically_completes_selected_plan` sends a production-selected plan through publication, director assignment, the real Autobuilder executor, physical task matching, reservation cleanup, work-layer exhaustion, and completion archival. At that checkpoint the offline regression batch passed 18/18 checks; neither new scenario has been KAG-runtime compiled.

The latest no-popup slice advances public telemetry to schema v3. A bounded numeric rules queue now carries accepted human blueprint edits, director toggles/orders, director-workshop purchases, and production plan publish/archive/task reserve/complete/damage boundaries into the existing coarse base64 transport. Producer ticks are explicit, reservations remain ownership-change-only, large drains split at the batch limit, and queue overflow emits a loss record. The parser remains compatible with v1/v2, the episode summarizer counts accepted player boundaries, and the complete offline batch passes 19/19 checks. Generic hit and pickup/drop producers remain; the v3 AngelScript path is not runtime-compiled.

The next source-only slice closes the known bootstrap siting hole. Provisioning now builds one bounded terrain reachability map from the nearest two-tile standing cell at team home and accepts only locally safe spawn envelopes in that set. This rejects mirrored locally clear but sealed pockets without restoring the old per-candidate world scans. `strategic_bootstrap_rejects_sealed_cave_spawn` advances the registry to 61 scenarios, and `Tools/test_aib_bootstrap_connectivity.ps1` mirrors the production flood-fill offline. The complete offline batch passes 20/20 checks; this AngelScript path and scenario have not been KAG-runtime compiled.

The latest source-only slices add full representative fallback completion for three planner environments. `strategic_no_build_primary_falls_back_and_physically_completes`, `strategic_occupied_primary_falls_back_and_physically_completes`, and `strategic_barrier_primary_falls_back_and_physically_completes` first prove the production primary is valid, introduce one exact no-build sector, protected static crate, or active barrier, require the primary to reject for `no_build`, `building_overlap`, or `barrier`, publish a distinct valid fallback, and drive every task through the real Autobuilder executor. Completion requires physical matches, empty work/reservation state, stable plan identity, a completed archive, and an intact obstacle. The barrier fixture forces collapse pressure and requires every fallback task to remain on the home side. Temporary no-build sectors are owner-tracked and removed before canonical reset.

`strategic_blocked_bootstrap_cools_down_and_round_reset_recovers_both_sides` closes the corresponding source-only bootstrap lifecycle gap. For team 0 and team 1 it publishes an active plan, places non-overlapping static crates every two tiles so every legal 6-24-tile spawn distance is covered, requires a zero spawn and the exact 300-tick retry deadline, kills the blockers, proves the deadline still suppresses provisioning, then invokes `AIBS_ResetBootstrapForRound`. The reset must preserve the enabled policy while clearing both latch and cooldown; each side must then receive exactly one safe strategy-assigned worker and reject a second attempt. The registry now contains 65 scenarios and the offline batch remains 20/20; this fixture is runtime-uncompiled.

The existing uneven right-edge case is no longer selection-only. Renamed `strategic_uneven_right_edge_fallback_physically_completes`, it first proves the primary gatehouse valid on the original terrain, adds the two-tile castle step, requires `occupied_terrain`, and selects a distinct inward fallback while no Autobuilder exists so ordinary approach and reachability checks stay active. It then publishes the production plan, assigns an Autobuilder, and requires exact physical completion, empty work/reservations, stable identity, completed history, at least two tiles of measured terrain variance, and preservation of both blocking tiles. A fallback may legally reuse one as an already-matching stone task. This stronger path is statically contracted and runtime-uncompiled.

The mirrored representative case is also no longer selection-only. Renamed `strategic_mirrored_sides_physically_complete_safe_inward_plans`, it selects, validates, and publishes both teams' inward plans while `world.autoBuilders == 0`; only after both publications succeed are two team-specific Autobuilders spawned and assigned. Each side independently requires every task to match physically, zero work/reservations, exact counters, an empty human layer, stable plan identity, a completed archive, and observed executor progress. The test deadline scales with the larger plan because both executors run concurrently. This path is statically contracted and runtime-uncompiled.

The next public-readiness slice removes the hard-coded CTF startup policy. `Rules/CommonScripts/AIBDirectorPolicy.cfg` now controls `ctf_default_mode` and `ctf_bootstrap_enabled`; AIBTest remains forced off and non-CTF modes remain suggestion-only. `!aib_bootstrap on|off|status` gives moderators a team-scoped live override without clearing the round grant, retry deadline, or killing an existing worker. `Tools/test_aib_director_policy.ps1` protects config consumption, initialization/reset preservation, authorization, synchronization, and anti-fountain semantics. The complete offline batch is now 21/21; this new AngelScript loader/command path is runtime-uncompiled.

The following public-test slice makes telemetry consent and operations concrete. `AIBTelemetryPolicy.cfg` controls CTF startup capture and the built-in privacy notice. Moderator overrides now survive round restarts; disable drains and flushes the current batch, and enable starts a new episode plus notices connected players who have not seen it. `PUBLIC_SERVER_OPERATIONS.md` explicitly treats whole-console rotation, retention, access, and deletion as host responsibilities because non-`[AIBACT]` lines may contain normal server identity/chat. `Tools/test_aib_telemetry_policy.ps1` protects the lifecycle and runbook, bringing the offline batch to 22/22. This AngelScript notice/transition path is runtime-uncompiled.

The next core-director slice corrects ordinary runner allocation. The former minimum-wood correction made a lone collector choose wood even when the outstanding stone demand was much larger. `AIBS_ComputeRoleDemand` now sends a single slot to the dominant shortage (deterministic wood tie), covers both materials proportionally when more slots exist, and retains a builder for active construction when possible. `AIBS_AssignStableRoles` preserves still-needed current roles before filling remaining slots in network-ID order, reducing safe-boundary handoff churn. `Tools/test_aib_role_allocation.ps1` covers demand matrices, roster conservation, stability, and deterministic fill; the offline batch is now 23/23. This AngelScript path is runtime-uncompiled.

The following replacement-policy audit fixes live safety invalidation for damaged fronts. `AIBS_ActivePlanInvalid` previously accepted a repairable same-team occupant before evaluating a newly active barrier, no-build sector, or protected-building overlap. Those pending repairs now pass all current safety gates before repairability can retain the plan; fully matching work still bypasses them because no action remains. `Tools/test_aib_active_plan_invalidation.ps1` pins this ordering while the existing damaged-front fixture protects safe no-replacement behavior. The offline batch is now 24/24; this source path is runtime-uncompiled.

The user currently permits visible KAG windows, keyboard control, and screenshots. Prefer player-facing CTF on one repeatable official map; close KAG immediately after each completed or failed evidence run unless an active reload/TCPR iteration requires it to remain open. No KAG process is running at this handoff. Root startup is restored to `CTF`, blank `sv_mapcycle`, and shuffle enabled; all three AIBTest scenario selectors are blank; `Rules/CTF/gamemode.cfg` exists and no disabled rename remains.

The current source defines **65 scenarios**, but there is no full current-suite pass. Keep the old full-44 evidence, focused scenario evidence, normal-CTF evidence, compile evidence, AIBTest stalls, and genuine failures distinct.

### Final no-popup checkpoint for the next agent

This is the deliberate stopping point from the 2026-07-10 session. No KAG process is running, no live test should be started until the user permits visible windows again, and startup is safe for an eventual manual CTF session. The final offline/static regression batch passed **15/15 checks**: advanced gym monitor contract, compact failure parser, compact diagnostic-window parser, 58-scenario registry, canonical fixture reset, representative director fixtures, wave identity/seed contract, 48-trial matrix generator, wave comparator, 68-key shared strategy configuration, abstract simulator, telemetry parser, episode summarizer, matched-context comparator, and `git diff --check`. The line-ending messages from `git diff --check` are warnings, not whitespace errors.

Do not mistake that checkpoint for KAG runtime acceptance. The most recent AngelScript additions still needing one focused visible compile are telemetry schema v3 callbacks/boundary queue, the shared strategy-weight loader, canonical reset/representative planner scenarios, and the expanded gym monitor plus `[AIBGYM]`/`[AIBGYMW]` emission. The compact diagnostic window and action boundaries use numeric arrays plus binary/base64 packing; source contracts pass, but KAG dialect/runtime behavior is unproven.

When runtime windows are allowed, continue in this order and stop on the first compile failure: (1) one short focused AIBTest compile that exercises the gym monitor/window path, (2) the corrected overflow scenario, (3) the known overhang return-route reproduction, (4) the mirrored/shortage/pressure/damaged-front representative range, (5) the uneven-edge and general full selected-plan completion scenarios, (6) the sealed-bootstrap and blocked-site/round-reset scenarios, (7) the no-build/occupied/barrier fallback trio, and (8) only then the full 65-scenario suite and the generated 48-trial paired wave matrix. Keep timeouts proportional to observed scenario duration and use the 25-second stale detector; never spend 120 seconds waiting for a three-second check.

### What this work session focused on

1. Replaced verbose player telemetry with compact binary delta frames, base64 batches, a versioned parser, and privacy bounds.
2. Repaired the real wood pipeline: mature tree fixtures, complete tree/log episodes, delayed role handoff, grounded storage delivery, and no premature “frozen” verdict.
3. Added generated backwall support so unsupported foreground plans can be made buildable rather than rejected.
4. Added unattended normal-CTF smoke coverage with an automatically provisioned team-0 worker.
5. Reduced live lag by rate-limiting repeated rejection events, logging reservations only on new claims, caching bootstrap blocker bounds once per search, and scoping the developer force-worker override to team 0.
6. Added no-progress tree retargeting that resets on either meaningful approach or every successful hit, avoiding both permanent unreachable targets and the earlier “stops a few hits before felling” regression.
7. Implemented overflow-storage production behavior and a focused scenario, but the latest lightweight full-crate fixture has not been rerun.
8. Implemented first-class repair behavior for damaged owned plan tiles/blobs and obtained a complete focused pass.
9. Improved the runner so test-only compile failures before `[AIBTEST] START` are reported immediately instead of consuming the whole behavior timeout.
10. Extended compact player telemetry through schema v3 with attributed outcomes, accepted human blueprint/director actions, director-shop purchases, production plan/task boundaries, explicit queue-loss records, backward-compatible parsing, and deterministic heuristic task-episode summaries.
11. Centralized 68 production/offline scoring and template keys in `Rules/CommonScripts/AIBStrategyWeights.cfg`; production placement scoring and the abstract simulator now consume the same source.
12. Hardened paired-wave identity around fixture/version/team/side/scenario/seed, added canonical and measurement-start fingerprints, made every wave type vary cadence/formation by seed, and enforced three seeds per cohort in the comparator.
13. Added a deterministic NDJSON collection-manifest generator for the exact 48-trial/24-pair matrix. It detects undersampling and marks every trial as requiring a fresh canonical reset; actual reset/run automation remains.
14. Added attribution-aware task summaries and a matched-context baseline/candidate comparator. It requires three episodes per context, exposes raw deltas, and makes scalar quality enforcement opt-in rather than silently treating heuristic cost as truth.
15. Added canonical AIBTest terrain snapshot/restore/hash validation plus live fixture/bootstrap tag, plan-id, and director-mode reset gates so production work cannot contaminate later scenarios. Added production-planner fixtures for mirrored inward plans and uneven blocked-primary fallback; both now require full production-path physical completion. These additions are statically verified only.
16. Added shared stored-resource shortage pressure to candidate scoring and a production-scoring fixture that checks the exact unfunded wood/stone penalty. This prevents nominally valid megaprojects from ranking as though their missing materials were already available.
17. Added a production-planner pressure fixture requiring a collapsing frontline with six reachable enemy knights to select an emergency barrier and expose its urgency score term.
18. Expanded the passive gym monitor from three movement flags to 16-bit intent, state, target, outcome, accessible-resource, reservation, and invalid-build classifiers. Instrumented actual placement failure branches while preserving the observer's no-mutation boundary.
19. Added one-shot public-CTF `[AIBGYM]` failure records and a strict NDJSON parser. The record is numeric/privacy-bounded and emitted only on the first latched failure, avoiding the earlier laggy logging design.
20. Added a compact diagnostic ring buffer and `[AIBGYMW]` parser: up to 30 pre-failure and 12 post-failure samples are packed into one binary/base64 record. AIBTest waits only for that short post tail before reporting the latched failure.

### Strongest new evidence

- `../../Logs/console-26-07-10-17-03-04.txt`: real CTF worker 22 completed every log from one tree, returned/stored wood, accepted the deferred blueprint role, retrieved stone, built generated castle backwall then foreground, and emitted `[AIBDEV] PASS ... remaining_stone=138`.
- `../../Logs/console-26-07-10-17-07-43.txt`: developer force-worker scoping live-compiled and produced exactly one team-0 developer provision plus a generated-support PASS.
- `../../Logs/console-26-07-10-17-13-46.txt`: successful hits did not trigger the no-progress watchdog; the worker felled the tree, processed all five logs, stored wood, and accepted blueprint work before the localhost simulation stopped advancing.
- `../../Logs/console-26-07-10-17-32-06.txt`: complete `[AIBTEST] DONE` for `damaged_owned_tile_is_repaired_without_replacing_neighbors`; owned wood was repaired, the adjacent stone tile was preserved, the task completed, and exactly 10 wood was spent.
- `Artifacts/aib_ctf_generated_backwall_pass.png`: verified real KAG screenshot. The visible suggestion bubble is stale; server tile/resource/state deltas are the authoritative completion evidence.

### Latest code that is not yet behavior-verified

- Full-crate overflow now revalidates formerly-full crates, searches grounded/distinct two-sided crate sites, can fund the 150-wood crate from builder plus base storage, and does not charge wood when engine blob creation fails. It live-compiled in CTF.
- `full_crate_creates_grounded_overflow_storage` first froze because same-tick `isFull()` lag queued 18 items; the next run advanced but proved nine wood blobs merge and therefore did not make a full crate. The fixture now uses one 250-wood stack plus eight distinct non-stackable fillers. **That final fixture has not been run.**
- Exact overhang recovery ownership increased from 12 to 36 ticks with a 90-tick cooldown. It compiled during the successful repair AIBTest launch, but the previously failing CTF return geometry has not been reproduced after this change.
- Candidate setup failures now always receive a non-empty rejection reason. This compiled in CTF but has no dedicated assertion.
- Telemetry schema v3 and the shared AngelScript strategy-weight loader pass offline/static regressions, but neither has been compiled inside KAG because the user prohibited disruptive runtime windows. Installed Base/mod sources confirm the exact `onSetTile` signature, `getDamageOwnerPlayer`, `getPlayerOfRecentDamage`, `CPlayer.getCoins`, `CFileMatcher`, `ConfigFile.loadFile`, and class field-initializer patterns. Remaining risk is integration/runtime callback delivery, cross-script rules-array queue behavior, and config resolution in this rules stack; do not claim live validation.
- Wave identity/fingerprinting and seed variation also pass static source/parser contracts only. No `wave_start`, `wave_result`, or `wave_abort` runtime evidence exists yet, so the new record contract and 48-trial matrix remain unproven in KAG.

### Where time was lost and what should have been done earlier

- Too much time went into AIBTest presentation, retained-fixture behavior, and camera control even after human observation showed that visible `RunLocalhost()` can freeze independently of AI. Sustained behavior should have moved to normal CTF earlier.
- Several apparent builder freezes were test verdict freezes, seedling fixtures, or whole-simulation stalls. Blob/game-time deltas should always have been checked before touching production AI.
- The first telemetry implementation formatted too many per-tick strings and caused visible lag. Binary changed-field batching should have been the starting design.
- Shared function signature changes were only CTF-compiled, leaving a stale AIBTest-only call. Every shared API change should be followed by a whole-repo symbol search and one focused AIBTest compile.
- The overflow fixture relied on synchronous `CInventory.isFull()` and identical materials. KAG queues inventory changes and merges materials; fixtures must use configured slot counts and genuinely non-stackable occupants.
- The next agent should prioritize production mechanisms and short discriminating checks. Do not add immobilization/classifier-only tests unless they directly protect a production fix.

### Recommended next sequence

The user permits visible KAG windows and interactive keyboard/screenshot control. Prefer the actual player CTF gamemode, use the same official map for repeatability until it is stable, and close KAG immediately after each evidence run unless actively iterating through reload/TCPR.

1. Continue player-facing CTF on `Maps/Official/CTF/8x_Gloryhill2.png` by fixing team 1's home-boundary wood/blueprint role oscillation. `../../Logs/console-26-07-14-04-57-37.txt` records the deferred wood handoff at tick 3870, `store_resources` at tick 3969, then alternating blueprint/wood assignments every 30 ticks while retained wood repeatedly forces `return_wood`.
2. Preserve the verified generated-support fix from that log: the runner completes the same seven foundation tasks at ticks 3820-3868, every target is an explicit phase-0 coordinate, and the former `(1404,396)` target never appears. Generated dependencies must remain gated by their owning task's active phase/reservation, choose the first legal attachment, and reject the bottom map boundary as support. Preserve the earlier zero-crate, neutral-boundary, funded-crate, later-stone, and team-0 archer-perch baselines as well.
3. Keep AIBTest runs short and discriminating. Its fixtures can disappear, misspawn, freeze, or present the wrong camera; do not spend an hour stalled there and do not treat the harness display as authoritative.
4. Preserve the corrected overflow fixture as a bounded follow-up, then runtime-validate schema v3 and the shared strategy loader before collecting paired-wave data.
5. Expand to mirrored and uneven official maps only after the same-map economy and construction loop is reliable. Do not claim public readiness until the full current suite, representative both-side maps, and the 48-trial paired matrix are evidenced.

## User Goal

Add a strategic AI that decides what structures the team needs, chooses suitable locations, publishes blueprints, and coordinates multiple AI builders. Existing AI builders already collect resources, avoid some threats, navigate, and construct manually placed blueprints.

## Repository Instructions And Constraints

- This is a King Arthur's Gold mod. Never edit `King Arthur's Gold/Base`; override or add files inside this mod.
- Useful reference mods are `Hunter4D`, `Easy3D`, `Easy3DExampleMod`, and `EasyUI`.
- KAG documentation is sparse; inspect existing working scripts when an API is uncertain.
- KAG must be launched visibly and left running for gameplay testing unless the user explicitly requests a compile-only check.
- `AIB_DEBUG` in `AIBuilderBrain.as` must remain `false` outside focused testing.
- The current source defines 63 automated AIB scenarios. The live KAG process may stall before every scenario runs in one process, so retain per-scenario evidence and do not infer a full-suite pass from a focused or partial log.

## Relevant Existing Code

- `Scripts/CustomRenderer.as`
  - Owns editor input/rendering and overseer controls, but delegates authoritative blueprint data/network mutations to shared APIs.
- `Scripts/BlueprintData.as`, `Scripts/BlueprintNetwork.as`, and `Scripts/BlueprintCatalog.as`
  - Own team-scoped human/AI layers, publication, history, task/reservation state, networking, validation, costing, and the shared block catalog.
- `Scripts/AIBStrategicDirector.as` and `Scripts/AIBStrategicJobs.as`
  - Own the real observation heartbeat, mode transitions, planning/publication trigger, guarded CTF first-worker provisioning, deterministic builder allocation, and reservation cleanup on builder death.
- `Scripts/AIBWorldModel.as`, `Scripts/AIBBlueprintTemplates.as`, and `Scripts/AIBPlacementPlanner.as`
  - Observe the world, generate procedural candidates, hard-validate them, score them, and create stable plans.
- `Base/Entities/Characters/AIBuilder/AIBuilderBrain.as`
  - Executes assigned collection/construction work, reserves current-phase tasks, retrieves only required materials, navigates, clears valid obstructions, and places supported catalog tiles/blobs including doors and platforms.
  - Also owns safe storage-workshop construction, low-dirt stone execution, direct shaft movement, mirrored corner recovery, and line-of-sight gold collection/return.
- `Scripts/AIBStoneRouteCommon.as`
  - Shares exact route membership, dirt scoring, protected-tile rejection, clear surface-approach checks, and blocked-route recomputation policy between production and tests.
- `Scripts/AIBTestScenarios.as`
  - Defines 65 integration scenarios, including the real-heartbeat autonomous director/bootstrap pipeline, material collection, construction, storage/overflow, physical repair, safety, team isolation, deterministic strategic invariants, representative plan selection and completion, damaged-front retention, full selected-plan execution, workshop siting, corner recovery, line-of-sight gold delivery, low-dirt stone routing, and gym progress diagnostics.
- `TODO.md`
  - Already calls for extracting blueprint data/network/render/editor responsibilities.
  - Calls for authoritative AI-visible data, a shared block catalog, placement validation, material summaries, and support/path-risk checks.

## Current Verification Checkpoint

- Earlier uninterrupted full-suite evidence belongs to the then-44-scenario source: `44 passed, 0 failed` with `[AIBTEST] DONE` in `../../Logs/console-26-07-09-19-57-48.txt`.
- Targeted visible localhost evidence covers scenarios 42-46: all five passed with `[AIBTEST] DONE passed=5 failed=0` in `../../Logs/console-26-07-09-22-06-03.txt`. Its camera logs are not visual evidence; the user observed incorrect camera behavior.
- A later exact route run, `../../Logs/console-26-07-09-22-33-34.txt`, passed in 133 ticks with one destroyed dirt tile after widening the movement-only direct-shaft handoff across the final validated two-tile approach. The operator closed that client before `DONE`, so retain it only as supporting per-scenario evidence.
- `../../Logs/console-26-07-09-23-00-07.txt` records the production bootstrap heartbeat passing at 156 ticks: one safe worker, one deterministic build assignment, a task claim, and three completed director tasks. The runner reported `1 passed, 0 failed`; KAG stalled after the verdict, before `DONE`.
- `../../Logs/console-26-07-09-23-03-31.txt` records `strategic_bootstrap_respects_mode_and_existing_worker` passing at 65 ticks. The following death/reservation case started but the simulation stalled at game time 65 before its first director heartbeat; it is unverified, not failed.
- A post-run audit then fixed the `pending`/`reserved` assertion mismatch, latched transient claims, stored the original bootstrap spawn, split 600-unit fixture grants into legal stacks, strengthened suggest/no-home and same-plan death-release assertions, and made matching already-working builders acquire director ownership.
- The revised source live-compiled in `../../Logs/console-26-07-09-23-14-01.txt`. The exact death/reservation scenario reached tick 30, published plan 1, provisioned worker 10 at `2036,572`, and assigned blueprint job/state `2/12`; KAG then stalled before the runner could reserve/kill it. This proves compilation and the production path through assignment, but not death cleanup.
- Those five scenarios verify:
  - legal workshop placement away from tent/hall footprints, including obstructed-site search and full-foundation checks;
  - mirrored upper-left/upper-right corner escape with real displacement;
  - line-of-sight gold-cluster mining and immediate return, while occluded/no-build controls remain protected;
  - a reusable low-dirt stone route, one planned dirt tile destroyed, direct shaft movement, and preserved off-route dirt/bedrock/castle.
- This is not a recorded full pass of the current 65-scenario suite. Keep full-44, focused-five, focused-heartbeat, focused-guard, focused-repair, and focused-gym evidence distinct.
- `Tools/run_aib_tests.ps1` supports `-Scenario`, `-StartScenario`/`-EndScenario`, configurable stale detection, and optional `-StopAfterRun`. It requires `[AIBTEST] DONE` for completion. `RunLocalhost()` supplies a visible client and verdict fixtures remain for a 15-tick hold. `AIBTestCamera.as` is the intended camera owner, but displayed follow/manual control are unresolved; never treat `CAMERA_TARGET`/`CAMERA_VIEW` logs as proof of the actual screen.

## Main Architectural Decision

Implement a server-side utility-based `StrategicBlueprintDirector`. Do not start with a neural network, LLM, reinforcement learning, or a full bot-versus-bot simulator.

The strategic boundary should be:

```text
World state -> candidate structures -> hard validation -> utility scoring
            -> active team plan -> guarded first-worker provisioning
            -> phased tile tasks -> deterministic builder job assignment
```

The director decides intent, blueprint type, and placement. Existing builder brains continue handling material collection, movement, threat avoidance, and construction.

## Required Foundation

1. Extract authoritative blueprint storage/publication from `CustomRenderer.as` into shared server-side APIs.
2. Keep an immutable desired plan separate from the consumable blueprint grid. Builders currently erase grid cells after placement, so the grid cannot preserve completed-plan intent.
3. Separate human and AI blueprint layers. Human plans take priority and must not be overwritten by autonomous replanning.
4. Create a shared blueprint block catalog used by editor, planner, validation, costing, rendering, and placement.
5. Add doors and platforms before autonomous defense. The current supported set can easily produce walls that trap the friendly team.
6. Replace fixed minimum wood/stone collection with remaining-plan material requirements.
7. Add task reservations and dependency phases so multiple builders do not select the same nearest tile.

Suggested modules:

- `Scripts/BlueprintCommon.as`
- `Scripts/BlueprintData.as`
- `Scripts/BlueprintNetwork.as`
- `Scripts/AIBStrategicTypes.as`
- `Scripts/AIBWorldModel.as`
- `Scripts/AIBBlueprintCatalog.as`
- `Scripts/AIBBlueprintTemplates.as`
- `Scripts/AIBPlacementPlanner.as`
- `Scripts/AIBStrategicDirector.as`
- `Scripts/AIBStrategyEventLog.as`

Names are provisional; match repository conventions during implementation.

## World Model

Observe cheaply about once per second and replan every 5-10 seconds or after important events.

Track:

- Friendly/enemy flags, tents, halls, and direction to the enemy base.
- Static terrain surface, high ground, narrow passages, walls, and plausible lanes.
- Friendly/enemy knights, archers, builders, and AI builders.
- Recent deaths/attacks as a rolling pressure heatmap.
- A frontline estimate and whether it is advancing or collapsing.
- Team wood/stone, active builder jobs, pending construction, and finished/damaged plans.
- Enemy composition and later fire/explosive pressure.

Precompute static terrain once and incrementally rescan active-plan/frontline regions.

## Candidate Templates

Use procedural templates fitted to terrain rather than fixed PNGs:

- Flag gatehouse with a friendly passage.
- Frontline tower with internal access.
- Cheap emergency barrier behind a collapsing frontline.
- Archer cover/perch with useful sight lines.
- Ladder/access route over steep friendly terrain.
- Later: forward storage, siege position, repair/reinforcement, and breach response.

Generate anchors near the flag, behind the frontline, at detected chokepoints, and on useful high ground.

Hard-reject candidates that:

- Block every friendly route.
- Overlap flags, bedrock, incompatible buildings, or human plans.
- Violate the red barrier.
- Cannot be supported or approached by builders.
- Are unaffordable within a reasonable planning horizon.
- Duplicate an existing structure.

Example utility model:

```text
score = defensive_gain
      + route_or_access_gain
      + height_or_chokepoint_value
      + threat_fit
      + urgency
      + plan_continuity
      - material_cost
      - estimated_build_time
      - builder_travel_and_exposure
      - friendly_route_penalty
      - redundancy
      - unsupported_or_risky_tiles
```

Use commitment/hysteresis to prevent constant plan changes. For controlled variety, select among candidates within roughly 5-10% of the best score and apply template cooldowns.

## Builder Coordination

The director controls plans and jobs, not movement:

- Calculate remaining wood and stone shortages.
- Assign enough builders to wood and stone collection.
- Assign the remainder to construction.
- Build foundation/backwalls first, access components second, and the tactical shell last.
- Reserve each task for one builder.
- Cancel only plans that have become invalid or strategically irrelevant.

Expose `off`, `suggest`, and `auto` modes. Suggest mode renders a ghost and score reasons; auto publishes work and assigns builders. CTF now defaults to auto because autonomous publication is the user-facing objective. AIBTest defaults to off and opts in per scenario.

## Testing And Simulation Plan

The detailed, current gym architecture and implementation roadmap are in `kag_gym.md`. Engine-specific evidence traps and workarounds are maintained in `KAG_ENGINE_QUIRKS.md`; consult that ledger before interpreting stalls, camera logs, path requests, or live compile behavior.

Do not initially use full KAG bot matches as the main evaluator. Base knight/archer brains chase nearby players but do not provide dependable strategic CTF behavior.

Use three layers:

1. Deterministic planner tests
   - Fixture terrain and world-state snapshots.
   - Assert intent, anchor, footprint validity, team isolation, cost, route preservation, and replanning hysteresis.
2. Lightweight abstract simulator
   - Convert terrain into lanes/traversal nodes.
   - Model knights as breach pressure, archers as line-of-sight pressure, builders as construction/repair capacity, and structures as traversal/cover modifiers.
   - Run many seeded trials outside KAG to tune scoring weights.
3. In-engine scripted waves
   - Knight rush, archer harassment, bomb pressure, and mixed waves moving toward the team flag.
   - Compare identical seeds with and without the selected plan using real KAG physics and destruction.

Measure:

- Build completion time and resource cost.
- Builder travel, idle time, duplicated targets, and deaths.
- Enemy crossing/breach time and flag approaches.
- Damage absorbed and structure lifetime.
- Friendly route slowdown.
- Plan cancellation/replanning frequency.

Long live simulations can stop advancing, so they should not be the only acceptance mechanism. The visible localhost runner now supports exact/range selection, detects stale log/heartbeat progress, restores temporary configuration changes, and leaves KAG visible by default unless `-StopAfterRun` is supplied. Short deterministic scenarios, focused visible runs, and offline evaluation should progress together.

## Implementation Milestones

1. Blueprint authority, immutable plan representation, shared catalog, and strategy event logging.
2. Suggestion mode with one gatehouse template and deterministic terrain validation.
3. Doors/platforms, material-aware procurement, task reservations, and construction phases.
4. Autonomous flag defense and emergency barrier behavior.
5. Frontline/chokepoint model with several competing templates.
6. Scripted-wave evaluation and scoring-weight tuning.
7. Optional contextual bandit learning template performance by map/threat context. This should come only after deterministic scoring and outcome metrics work.

## Recommended Immediate Next Steps

Milestones 1-5 are implemented as a deterministic prototype. The next work is acceptance and tuning, not another planner rewrite:

1. Run `strategic_bootstrap_is_one_time_and_releases_reservation` alone. No KAG process is currently running. It is the only new bootstrap case without executed assertions; the previous range stalled before its director heartbeat.
2. Runtime-compile the new damaged-front retention, uneven-edge and general full selected-plan completion, sealed-bootstrap, blocked-bootstrap/round-reset, and occupied/no-build/barrier fallback fixtures.
3. Preserve the production bootstrap contract: CTF-only default, active non-empty auto plan, team home, zero existing builders, safe grounded both-side search, one free worker per round, cooldown on failure, and immediate reservation release on death.
4. Runtime-validate bootstrap spawn safety. Blocker bounds and the bounded home-surface reachability map are each computed once per attempt; source fixtures now reject clear sealed pockets and exercise blocked sites, exact cooldown, reset, and reprovisioning for both team directions. Verify compilation and then extend the same acceptance to uneven live homes in visible KAG.
5. Build pristine automatically reset paired wave fixtures around the implemented canonical/measurement fingerprints, fixture/version/team-side identity, seed variation, and three-seed cohort gate. Collect 2 sides × 4 waves × 3 seeds × 2 variants = 48 trials / 24 pairs.
6. Empty-plan rejection, archer ammunition/fire pulses, censored breach handling, fingerprint rejection, and semantic gates already exist. Validate them with live wave records rather than reimplementing them; current logs contain no `wave_start`, `wave_result`, or `wave_abort` data.
7. Centralize production scoring weights and template metadata, then tune only from the paired KAG dataset.

Do not add strategic scoring inside `CustomRenderer.as`; keep it in the server planner. Do not start RL training against the current disconnected abstract simulator.

Runtime handoff: visible KAG PID `26132` was initially left running after stale detection and later exited on its own; no KAG process remains. `Rules/CTF/gamemode.cfg` is restored, no disabled rename remains, and all AIBTest scenario selectors are blank. Camera behavior is still visually wrong despite internally consistent camera logs; do not spend more director time treating those logs as authoritative.

## Gym Decision

A trainable King Arthur's Gold gym is premature. The current PowerShell simulator is a deterministic surrogate with duplicated template properties and a separate utility equation; optimizing it would optimize its assumptions rather than demonstrated KAG outcomes.

Build a replayable evaluation layer first:

- reset pristine deterministic fixtures and export real world snapshots, candidate scores/rejections, selected plans, team side, fixture/version, measurement-start fingerprint, and paired wave outcomes;
- share one scoring-weight/template configuration between production and offline evaluation;
- validate predictions against the 48-trial / 24-pair KAG control/plan matrix;
- only then consider weight search, Bayesian optimization, or a contextual bandit.

Full reinforcement learning is optional and should be attempted only if deterministic utility scoring plateaus after trustworthy evaluation.

## Design Rationale

The recommended approach was a utility director rather than neural AI. Its key qualities should be:

- Explainable: show the selected intent and strongest score reasons.
- Responsive: react to pressure, terrain, resources, and match phase.
- Stable: finish useful work instead of replanning constantly.
- Varied: choose among similarly strong plans and support strategic personalities later.
- Counterable: structures have real material/time costs and imperfect tactical value.
- Testable: deterministic candidate tests first, abstract simulation second, real KAG waves third.

Current implementation/evidence details deliberately live in the status file so this design contract can remain stable.
