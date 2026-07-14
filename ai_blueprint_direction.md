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

- Compact telemetry notice, moderator control, rotation/retention procedure. Source/config/runbook are implemented; visible runtime validation remains.
- Matched-context human/AI task reports.
- Full current suite with final DONE evidence.
- Visible multiplayer CTF acceptance for UI, team isolation, stability, and gameplay quality.

Exit gate: deployment requires no developer-only setup beyond enabling the mod and normal server operations.

## Immediate Work

Do these next, in order. The user currently permits visible KAG testing and interactive keyboard/screenshot control. Prefer short player-facing CTF runs on the same official map, and close KAG as soon as each evidence run ends unless an active reload/TCPR iteration requires it to stay open.

1. On `Maps/Official/CTF/8x_Gloryhill2.png`, preserve the complete team-1 frontline-tower baseline and the player-facing director/manual-ownership acceptance. `../../Logs/console-26-07-14-08-04-46.txt` proves a workshop-chair overseer `Harvest wood` order stays player-owned across automatic heartbeats, Director OFF preserves it, and explicit ON releases the manual latch. Team 0 has no safe ordinary-builder tower site in the bounded local search: `../../Logs/console-26-07-14-07-23-04.txt` rejects x=20/36/44/48 as occupied, x=24 as no-build, and x=28/32/40 as unreachable. Do not weaken those safety gates or broaden the scan indefinitely merely to force symmetry on this map.
2. Preserve the verified construction corrections: generated support work must pass its owning explicit task's phase/reservation gate, use the first legal attachment cell, and never treat the bottom map boundary as support. The frontline tower must retain seven grounded foundation cells, separate shell/roof/closure phases, a home-facing two-tile opening at both the platform and roof levels, and doors deferred until solid adjacency exists. Planner dependency traversal must never use a future phase to support current work. Preserve confirmed queued storage and catalog-scoped neutral-platform identity as well.
3. Keep using this one map for fresh-launch comparisons until both team directions have stable economy and construction; only then repeat on mirrored and uneven official maps. Use `Scripts/aib_ctf_player_autostart.as` for normal player conditions and `Scripts/aib_ctf_autostart.as` only when the explicit developer acceptance scenario is required.
4. Use AIBTest only for short, discriminating compile or deterministic checks. Treat disappearing/misspawned fixtures, stopped simulation, and camera presentation as harness failures, visually verify suspicious results, and change tasks rather than spending an hour stalled in the harness. The overflow fixture now reaches its settled item-specific capacity gate but its latest localhost run stopped at tick 7 before purchase; leave the verdict open and return to player-facing CTF work.
5. Preserve the live-verified schema-v3 telemetry and shared `AIBStrategyWeights.cfg` loader, then runtime-validate fixture/fingerprint identity and the representative wave contract. Collect the first trustworthy 48-trial/24-pair dataset only after those identities are proven in KAG.

Completed in the latest slices: overflow conservation and mirrored overhang evidence were hardened; wave arming/measurement now share one broad, order-stable `w1` world manifest; damaged owned fronts now have an exact no-replacement fixture; a planner-selected plan must be physically completed task-for-task by the director-assigned Autobuilder; schema v3 records accepted player/director and production plan/task boundaries without per-event strings or silent queue loss; bootstrap provisioning rejects locally clear sealed pockets using one bounded terrain flood-fill per attempt; and initially valid primary plans blocked by exact no-build, protected-building, active-barrier, or uneven edge-terrain constraints must fall back to a different plan that the Autobuilder physically completes without disturbing the obstacle. The mirrored representative case now selects and publishes ordinary-reachable inward plans for both teams before spawning either Autobuilder, then requires both complete physically with exact layers, counters, reservations, histories, and stable identities. The uneven case uses the same ordering and requires every published task to complete while both step tiles remain intact. The barrier case forces collapse pressure, keeps every selected task on the home side, and preserves the barrier and crossed tile. A mirrored bootstrap lifecycle fixture now occupies every legal spawn distance, requires the exact 300-tick failed-search cooldown, proves clearing blockers does not bypass it, calls the production round-reset policy, and then requires exactly one safe assigned worker for each team direction. Public CTF startup mode and free-bootstrap enablement now come from `AIBDirectorPolicy.cfg`, with a moderator-only team runtime command that preserves the one-per-round latch and cooldown. Public telemetry startup/notice policy is likewise configurable; moderator overrides persist across rounds, disable flushes the batch, enable opens a distinct episode, and `PUBLIC_SERVER_OPERATIONS.md` defines the host-owned retention/rotation gate. Ordinary runner allocation now assigns a lone collector to the dominant wood/stone shortage, covers both materials proportionally with larger rosters, retains active construction capacity, and preserves still-needed roles before deterministic slot filling. Pending damaged-front repairs must now pass current barrier/no-build/protected-building gates before repairability can preserve an active plan, while safe repairs and completed matching work remain stable. Active plans also reconstruct their implicit support dependencies and invalidate when a later no-build sector, barrier, or protected blob makes a generated backwall chain impossible. If an unsafe plan has no valid replacement—or replacement publication fails—the director now archives and cancels it, clears both live AI layers and director task reservations, and stops its assigned workers instead of continuing unsafe work. Round restart now closes unfinished plans and clears every live blueprint/task layer plus registered loose reservations before the next plan, without resetting administrator policy or archived evidence. Human blueprint edits now durably retire overlapping AI tasks, so consuming the human tile cannot reveal an older AI instruction that rebuilds over the player’s choice. Strategic flags and tent/hall resource homes are now distinct: flag-only teams keep their plan and Autobuilders but suspend ordinary runners and free provisioning, while total strategic-home loss archives the plan as `home_lost` and clears director ownership. Director resource pressure now uses the same accessible-stock contract as production retrieval—near-home loose material plus recognized grounded base crates—so remote crates, workshops, builder inventories, and active-barrier-crossed stock cannot suppress collectors or make an unfunded plan look paid; the shared normalized zone helper also drives executor filtering and storage siting. The advanced UI displays the server-synced total. On multi-home maps, assigned ordinary runners use the exact resource-home identity behind that stock instead of independently switching to a nearer tent/hall; manual orders retain nearest-home behavior and invalid pins fall back safely. Player wood/stone/blueprint orders atomically release every director reservation, pending role, movement controller, and home pin, then remain excluded from automatic reassignment until automatic direction is explicitly re-enabled; they still suppress free bootstrap provisioning, and manual Autobuilders retain director isolation. Public job/state/active values now force-publish at creation and receive a coarse staggered resync so late-join HUD staleness is bounded without a duplicate role property. Authoritative human edits now suppress no-op version/history churn, and tile/snapshot payloads are targeted to same-team players and spectators instead of exposing other teams' blueprint contents on the wire. Blueprint saving now uses a committed rectangle independent of tree/stone/overseer gestures, rejects save-before-selection, and preserves inclusive/asymmetric dimensions and orientation through memory, PNG, packet, and authoritative placement paths. The manifest captures terrain, no-build masks, blobs/inventories, barriers, and exact strategic layers/tasks while excluding private or transient identity. All 34 offline contracts pass; KAG compilation, paired runtime records, live two-team/spectator editor validation, and a process-restart PNG round trip remain pending. Earlier completed work includes complete tree/log episode handoff, generated backwall support, grounded storage search, physical repair, compact outcome telemetry, shared scoring weights, and fixture/team/side-aware evaluation infrastructure.

The latest visible real-CTF checkpoint closes the premature generated-support stall, the phase-cycle behind the apparent home-boundary role oscillation, false platform damage, delayed door collapse, and the one-tile ladder-entry trap. Generated dependencies retain their owning task's eligibility, support selection is bounded, and the frontline tower now advances through foundation, access, shell, roof, and closure without a cyclic dependency. Storage success is confirmed three ticks after KAG's queued inventory transfer before delivery crosses its role boundary. Neutral platform matching remains catalog-scoped with separate originating-team ownership. KAG doors are deferred until adjacent solid shell exists, while the platform and roof openings are runner-width and face team home. In `../../Logs/console-26-07-14-07-03-51.txt`, both doors completed at ticks 3133 and 3141, the plan archived as completed, and no task damage appeared through tick 3630. Candidate generation now samples a deduplicated bounded neighborhood around the semantic tower anchor; reachability is evaluated before route preservation so an unreachable plan is not mislabeled as a route regression. `../../Logs/console-26-07-14-07-23-04.txt` proves the expanded team-0 sites are legitimately occupied, no-build, or unreachable, while team 1 still publishes the proven x=177 plan. The real Director AI button completed authoritative OFF and ON round trips in `../../Logs/console-26-07-14-07-27-34.txt`. `../../Logs/console-26-07-14-07-36-38.txt` records `[AIBWEIGHTS] loaded=true version=1` with the resolved mod config, closing the shared-loader runtime gate. Suggestion-mode chat input remains unverified because two external keystroke attempts produced no command event. The complete offline batch passes 42/42 contracts. KAG was closed immediately after each verdict and root startup was verified safe. Equivalent team-0 completion must use a representative map with a valid site rather than weakening this map's gates.

The shared overseer command now validates wood, stone, or blueprint worker opcodes before calling the destructive manual-ownership handoff. Unknown authenticated packet opcodes cannot release a reservation, deferred role, path, or resource-home pin without accepting a real replacement job; `Tools/test_aib_manual_order_ownership.ps1` pins that validation-before-mutation order.

Automatic role assignment now requires an active pending plan with a non-empty AI work layer. With no executable work, Autobuilders and target-free runners relinquish director ownership immediately; in-flight resource episodes latch retirement, finish normally, and are stopped by the brain at the first safe boundary before another target can be selected between 30-tick director observations. Ordinary role changes now cross that boundary reliably as well: the director records the latest valid desired role, and the brain applies it before the old find state can select a new target, clearing stale reservations and navigation/controller intent while preserving assignment and resource-home identity. The expanded bootstrap guard no longer depends on empty-plan assignment for its stock/home assertions and adds runtime-ready held/applied role plus immediate/deferred retirement checks.

Player-facing manual ownership is now live-verified in normal CTF. A temporary team-0 worker and workshop were fixture setup only; the player used the real workshop chair, overseer rectangle, `Harvest wood` button, and Director toggle. The accepted order at tick 28620 remained manual and unassigned through tick 30380 while auto mode continued observing. OFF at tick 33467 preserved the active player job, and ON at tick 35407 cleared the latch without aborting state 6 of the safe wood-return episode. The help overlay now states that the workshop chair is the required entry to overseer selection.

Recovery-ladder support now crosses a simulation boundary too. The builder pays only for missing backwall cells and places the connected chain first; a later obstruction cycle may create the ladder only after engine support recognition. One post-ladder probe captures BrainPath low/waypoint counts, its next node, ray obstruction, and the diagnostic mineable block without turning that path request into outcome evidence. The strengthened dirt-plug fixture passes only after support-before-spawn, post-placement path acceptance, and real traversal over an unchanged plug; static coverage passes, while KAG compilation remains pending.

Base storage now associates existing workshops with the exact resource home rather than accepting an arbitrary same-team shop nearest the runner. The shared storage/stone-supply selector rejects packed, cross-barrier, and more-than-28-tile-away shops, scores the remaining shops against the grounded storage point, and uses network ID as the deterministic tie-break. The runtime-ready siting fixture leaves a remote shop alive and requires a newly built local shop to win. Mixed overflow-crate funding now counts only inventory wood that `AIB_TakeMaterial` can actually spend, confirms that builder leg first, and refunds it if the home withdrawal fails, preventing partial-payment resource loss. Capacity uses `canPutItem` for the prospective resource rather than `isFull`, and a stone runner's fallback accepts only fresh loose base/quarry supply instead of withdrawing completed crated stone. All static contracts pass and the code compiles; the focused physical verdict remains open because `console-26-07-14-10-09-19.txt` stopped advancing immediately after the corrected fixture activated delivery.

Public builder job/state now has a bounded repair path for late-join HUD consistency. Creation force-publishes the canonical job/state/active trio, every authoritative order/transition retains immediate sync, and the server brain republishes the trio once every five seconds with builders staggered by network ID. The existing three-value job enum remains the single resource-role source for the HUD rather than adding a divergent property. `Tools/test_aib_public_state_sync.ps1` pins the source paths and coarse cadence; a real client joining active builders is still required for runtime evidence.

Live human blueprint deltas now stay within their intended visibility boundary. The server already owned permission, version, catalog, bounds, rate, human-priority, compatibility-layer, and action-boundary decisions; it now sends tile and snapshot payloads only to same-team players or spectators through targeted rules commands instead of broadcasting contents for enemy clients to discard. Same-value tile packets return before layer, version, priority, display, or telemetry mutation, preventing held-paint retransmits from creating false edit history. `Tools/test_aib_editor_delta_authority.ps1` pins these source contracts; real two-team/spectator transport and AI consumption remain runtime acceptance work.

Blueprint save selection now has durable local ownership distinct from the shared gesture rectangle. A committed blueprint selection is normalized and cached; later tree, stone, or overseer drags cannot alter it, while restart/team change or beginning a replacement drag invalidates it. A one-tile selection and reversed/asymmetric drags preserve their exact inclusive dimensions, x/y orientation, serialized ordering, and centered authoritative footprint through runtime memory and PNG paths. `Tools/test_aib_blueprint_selection_roundtrip.ps1` pins the full source chain; a real disk save followed by a KAG process restart and reload remains runtime acceptance work.

Passive gym calibration now treats real displacement as state progress even when a direct controller leaves no sampled key or destination intent. In player-facing CTF log `../../Logs/console-26-07-14-09-20-52.txt`, the miner was falsely labeled `state_stall` after moving 25px, then continued to mine and deliver 216 and 252 stone before physically placing blueprint blocks. State stall now requires displacement below the existing stall threshold in addition to no intent, interaction, target change, or outcome; monitor and parser contracts pass, while a fresh live negative calibration remains optional rather than a blocker.

## Evidence Discipline

- A focused PASS proves only its named behavior.
- PASS without matching DONE is partial evidence.
- A synthetic classifier contract proves detector math, not builder competence.
- Camera logs do not prove the displayed view.
- A path object/request does not prove motion or reachability.
- Do not raise completion percentage because documentation or instrumentation exists; raise it only when a required behavior is implemented and verified.
