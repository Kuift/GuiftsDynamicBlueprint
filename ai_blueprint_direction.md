# AI Blueprint Direction

## Mission

Build a public-test-ready RTS-style builder system in which a strategic director observes the KAG world, publishes safe and useful construction plans, provisions and coordinates AI builders, and improves from deterministic gym evidence plus privacy-bounded public player demonstrations.

This document is the execution direction. `kag_gym.md` is the detailed evaluation architecture. `AI_BLUEPRINT_DIRECTOR_HANDOFF.md` remains the original design contract, and `AI_BLUEPRINT_DIRECTOR_IMPLEMENTATION_STATUS.md` is the evidence ledger.

## Non-Negotiable Outcome

The project is not complete when planning APIs exist or tests merely identify failures. Completion requires:

- a same-team player can order wood, stone, or building and the AI physically completes the job;
- autonomous CTF direction safely creates/assigns workers and materially completes useful plans;
- builders traverse ordinary terrain without silent idle, jump loops, controller conflicts, or destructive pathing;
- resources move through mining/harvesting, inventory, crates/home storage, retrieval, spending, and overflow without loss;
- construction respects support, approach, doors/platform orientation, no-build areas, barriers, human plans, and friendly routes;
- representative mirrored fixtures and paired waves show strategic value rather than only mechanical validity;
- public telemetry is compact, server-side, privacy-bounded, versioned, and sufficient to compare matched human and AI task episodes;
- current tests, manual multiplayer acceptance, operational defaults, and documentation all agree with the shipped behavior.

## Architecture And Ownership

The system is a closed evidence loop:

```text
KAG world
  -> WorldModel (facts, no policy)
  -> StrategicDirector (intent/template/utility)
  -> BlueprintData (authoritative desired/work/task layers)
  -> StrategicJobs (roles, assignments, reservations, bootstrap)
  -> AIBuilderBrain (task state machine)
  -> Navigation + Interaction executors (movement, mining, pickup, placement)
  -> KAG world outcomes
  -> Gym observers + compact telemetry
  -> Episode cost vector / matched human comparison
  -> code or versioned scoring-weight change
```

Ownership rules:

- `AIBWorldModel.as` observes; it never issues jobs.
- `AIBStrategicDirector.as` selects strategic intent; it never presses builder keys.
- `BlueprintData.as` owns plan/task authority, versions, reservations, and completion state.
- `AIBStrategicJobs.as` owns worker roles and assignment lifecycle.
- `AIBuilderBrain.as` owns one builder's task state and target intent.
- navigation code owns movement for one declared mode at a time; generic recovery must not compete with a dedicated shaft/tunnel controller.
- interaction functions own authoritative side effects such as hits, pickup, deposit, spending, and placement.
- `AIBGymMonitor.as` and the test harness observe and classify; they do not make a broken behavior pass.
- `AIBPlayerActionLog.as` captures compact demonstration deltas; it does not contain AI policy.
- offline evaluators rank evidence; hard safety constraints remain in production validation and cannot be traded for score.
- placement scoring separates nominal material cost from the portion not covered by current storage, discouraging dead-on-arrival large plans without hard-rejecting work that harvesting can eventually fund.

State transitions form a lifecycle boundary. When the builder changes state, movement paths, direct-mode flags, obstruction recovery, and pressed movement/action keys from the old controller are cleared. Task targets are preserved only when the transition explicitly hands them to the next state.

## Builder Competence Curriculum

The [KAG Builder Guide](https://deynarde.github.io/kag-builder-guide/) is treated as a competency source, not as a blueprint to copy blindly.

### Tier 1 — reliable worker primitives

Required real fixtures:

1. Reach a selected tree, fell it, process logs, collect wood, and store it.
2. Reach exposed stone, mine a quota, collect material, and store it.
3. Reach stone behind a dirt plug using a bounded reusable route; never mine bedrock/castle/off-route dirt.
4. Retrieve wood/stone from home or a crate and build one supported block.
5. Build backwall/support before ladder, door, platform, workshop, or dependent block.
6. Repair a damaged owned plan tile without replacing healthy tiles.
7. Recover from a full crate by choosing or creating valid secondary storage.

Every fixture asserts intent, motion, interaction, outcome, material conservation, and terrain/route invariants. A monitor diagnosis is a failure that drives a production fix.

### Tier 2 — competent defensive builder

The guide emphasizes supported stone walls, careful door use, protected shops, repair, resource management, platforms, and base expansion. Translate that into:

- support-aware wall/tower construction and repair priority;
- enough team doors for access without expensive door spam;
- stone backwall behind critical stone/door structures;
- shops away from exposed/bottom/front positions and with grounded access;
- platforms oriented for friendly movement and defensive value;
- routes that let teammates leave/return and do not trap spawns or flags;
- threat-aware retreat, resume, and damage triage.

### Tier 3 — progressive builder/director

The guide's progressive play centers on maintaining mid control, protected tunnels/shops, material preparation, upkeep, and choosing lower-effort/safer routes. Translate that into:

- director intents for home defense, frontline expansion, mid outpost, access route, and repair/rebuild;
- material budgets before publication and role assignment;
- safe secondary-base siting with approach and retreat routes;
- upkeep/replan based on damage, frontline pressure, and friendly travel cost;
- tunneling that starts away from protected home/flag areas and minimizes destructive dirt work;
- no tunnel/offensive expansion until Tier 1 and defensive invariants are reliable.

### Tier 4 — offensive builder

Quick walls/ledges, enemy-tower analysis, scaling with blocks/ladders/platforms, door support, and demolition are later work. They require enemy-aware risk models and should not displace reliable economy, construction, and defense work. Knight AI remains out of scope unless a builder fixture needs a deterministic escort/threat actor.

## Gym Contract

For each order, the gym measures four separate layers:

- Intent: command accepted, correct job/state, target/reservation valid.
- Motion: distance-to-goal trend, displacement, jump attempts, path/direct-mode changes.
- Interaction: mining/hit/pickup/deposit/spend/place/repair event occurred legally.
- Outcome: requested material delivered or requested structure completed and usable.

The passive rolling monitor now classifies motion stall, jump loop, path thrash, active-job/no-intent, state-without-side-effect, target thrash, accessible-resource deadlock, stale/dead reservation ownership, and repeated invalid-build attempts. It observes target/inventory/plan deltas and explicit build failures without pressing keys or changing state. A compact ring retains up to 30 pre-failure and 12 post-failure samples and emits one binary trajectory. These additions are statically verified but not KAG-runtime compiled. Friendly-route regression and classifier-specific runtime calibration remain.

Final selected fixtures remain visible with an explicit `RUNNING`, `PASS - FROZEN`, or `FAIL - FROZEN` label. Focused runs use proportional limits such as `-TimeoutSeconds 20 -StaleSeconds 5`; stale timing begins only after scenario `START`.

## Player Demonstration And Optimization Loop

Player action capture uses binary changed-field records batched into occasional base64 log envelopes because KAG scripts do not expose a safe persistent binary writer. It excludes usernames, IPs, and chat. Schema v3 retains compact tile/blob/death/resource outcomes with explicit attribution confidence and adds authoritative accepted blueprint/director actions, director-workshop purchases, and production plan/task boundaries. A bounded queue reports loss explicitly. The offline summarizer segments these records into raw task episodes; its task label and idle estimate remain heuristics, not authoritative truth.

Episode summaries keep attribution-weighted outcomes, low-confidence counts, and a coarse privacy-safe context key. The offline matched-context comparator requires three baseline/candidate episodes by default and reports raw deltas before any optional quality gate. Its scalar cost is a proposal-ranking aid, never a replacement for KAG behavior and safety evidence.

The learning unit is a task episode, not a player identity:

- context: map/terrain neighborhood, team side, class, resources, threat, intended task;
- actions: button/aim/equipment deltas and authoritative outcomes;
- result: completion, elapsed/idle/stall ticks, material and route cost, damage/death;
- comparison: AI and human episodes only within compatible contexts;
- change: a small code mechanism or shared versioned weight set;
- acceptance: affected primitives first, then representative regression and paired strategy trials.

Raw cost components remain stored. A scalar cost may rank candidates, but safety gates cannot be optimized away.

## Ordered Delivery Plan

### Milestone 1 — builder primitives green

- Real wood pipeline.
- Real exposed and obstructed stone pipelines.
- Real crate retrieval/overflow.
- Real supported single-tile, door, platform, ladder, workshop, and repair pipelines.
- No silent timeout: every failure is classified at intent/motion/interaction/outcome.

Exit gate: all primitive fixtures pass through production code with material conservation and no safety violation.

### Milestone 2 — coordinated small blueprint completion

- Two and four builders with deterministic roles.
- Support/approach phases and exclusive reservations.
- Death/disconnect/expired reservation recovery.
- Full completion of small defensive plans on mirrored uneven fixtures.

Exit gate: complete plan, no duplicate work, bounded idle/travel, usable friendly route.

### Milestone 3 — representative autonomous director

- Both team directions across flat, uneven, edge, barrier, no-build, occupied, scarce-resource, and damaged-front fixtures.
- Safe automatic worker provisioning and assignment.
- Full-plan completion, repair, invalidation, hysteresis, and emergency replacement.

Exit gate: every fixture publishes safely and materially completes a useful plan without human setup.

### Milestone 4 — trustworthy evaluation

- Canonical fixture/version/side/measurement fingerprints.
- Authoritative outcome deltas and episode cost vector.
- Shared production scoring configuration.
- Minimum 48 control/plan trials: two sides, four wave types, three seeds, two variants.

Exit gate: paired metrics show useful defense with bounded route penalty and builder loss.

### Milestone 5 — public test readiness

- Compact telemetry notice, moderator control, rotation/retention procedure.
- Matched-context human/AI task reports.
- Full current suite with final DONE evidence.
- Visible multiplayer CTF acceptance for UI, team isolation, stability, and gameplay quality.

Exit gate: deployment requires no developer-only setup beyond enabling the mod and normal server operations.

## Immediate Work

Do these next, in order. The current user has asked for no disruptive KAG pop-ups, so steps marked runtime wait until explicit permission.

1. Runtime (waiting for explicit permission): run only `full_crate_creates_grounded_overflow_storage` with a 15-second cap and 5-second stale detector. Its fixture/payment/placement conservation audit is complete and protected by `Tools/test_aib_overflow_storage_contract.ps1`.
2. Runtime (waiting for explicit permission): reproduce the real CTF return route from roughly `239,368` to `132,316`; require delivery, not just an escape event. The longer mirrored recovery static audit is complete and protected by `Tools/test_aib_corner_recovery_contract.ps1`.
3. Runtime-compile and validate telemetry schema v3. Accepted blueprint/director actions, director-workshop purchases, and plan/task boundaries are now implemented with a bounded loss-reporting queue; add the still-missing generic direct-hit and pickup/drop hooks only after this combined path compiles.
4. Runtime-compile and validate the shared `AIBStrategyWeights.cfg` loader; both production placement scoring and the offline abstract simulator now consume it and static contracts pass.
5. Runtime-compile the completed fixture/version/team/side identity, canonical/measurement fingerprint, deterministic seed-variation, and three-seed comparator contract.
6. Runtime-compile the canonical terrain/world reset, shared `w1` world manifest, and the 63-scenario suite's mirrored/uneven/scarcity/pressure/damaged-front/full-completion/sealed-bootstrap/no-build/occupied production fixtures. Broader non-fixture manifest hashing, representative fallback completion, and bounded home-connected bootstrap spawn filtering are now implemented and statically contracted. Then collect the first real 48-trial/24-pair dataset.

Completed in the latest slices: overflow conservation and mirrored overhang evidence were hardened; wave arming/measurement now share one broad, order-stable `w1` world manifest; damaged owned fronts now have an exact no-replacement fixture; a planner-selected plan must be physically completed task-for-task by the director-assigned Autobuilder; schema v3 records accepted player/director and production plan/task boundaries without per-event strings or silent queue loss; bootstrap provisioning rejects locally clear sealed pockets using one bounded terrain flood-fill per attempt; and initially valid primary plans blocked by exact no-build or protected-building constraints must fall back to a different plan that the Autobuilder physically completes without disturbing the obstacle. The manifest captures terrain, no-build masks, blobs/inventories, barriers, and exact strategic layers/tasks while excluding private or transient identity. All 20 offline contracts pass; KAG compilation and paired runtime records remain pending. Earlier completed work includes complete tree/log episode handoff, generated backwall support, grounded storage search, physical repair, compact outcome telemetry, shared scoring weights, and fixture/team/side-aware evaluation infrastructure.

## Evidence Discipline

- A focused PASS proves only its named behavior.
- PASS without matching DONE is partial evidence.
- A synthetic classifier contract proves detector math, not builder competence.
- Camera logs do not prove the displayed view.
- A path object/request does not prove motion or reachability.
- Do not raise completion percentage because documentation or instrumentation exists; raise it only when a required behavior is implemented and verified.
