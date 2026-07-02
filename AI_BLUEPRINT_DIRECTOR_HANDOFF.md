# AI Blueprint Director Handoff

> Implementation is now substantially complete. Current verification state, changed files, known runtime limitations, and exact resume steps are tracked in `AI_BLUEPRINT_DIRECTOR_IMPLEMENTATION_STATUS.md`. Treat that file as the active execution handoff; this document remains the design contract.

Date: 2026-06-20

## User Goal

Add a strategic AI that decides what structures the team needs, chooses suitable locations, publishes blueprints, and coordinates multiple AI builders. Existing AI builders already collect resources, avoid some threats, navigate, and construct manually placed blueprints.

## Repository Instructions And Constraints

- This is a King Arthur's Gold mod. Never edit `King Arthur's Gold/Base`; override or add files inside this mod.
- Useful reference mods are `Hunter4D`, `Easy3D`, `Easy3DExampleMod`, and `EasyUI`.
- KAG documentation is sparse; inspect existing working scripts when an API is uncertain.
- KAG must be launched visibly and left running for gameplay testing unless the user explicitly requests a compile-only check.
- `AIB_DEBUG` in `AIBuilderBrain.as` must remain `false` outside focused testing.
- The current source defines 26 automated AIB scenarios, although older notes still mention 13.

## Relevant Existing Code

- `Scripts/CustomRenderer.as`
  - Owns editor input, rendering, networking, overseer controls, and AI-visible blueprint publication.
  - Team data keys start at lines 19-22.
  - `AIB_ServerApplyBlueprintBlock` is near line 542.
  - `AIB_ServerApplyBlueprintPlacement` is near line 603.
  - `AIB_ServerApplyOverseerOrder` is near line 1970.
- `Base/Entities/Characters/AIBuilder/AIBuilderBrain.as`
  - State enum starts near line 49.
  - Blueprint execution pipeline:
    - `AIB_CollectBlueprintResources`, near line 702.
    - `AIB_FindBlueprintBlock`, near line 744.
    - `AIB_BuildBlueprintBlock`, near line 770.
  - Nearest-tile selection starts near line 2531.
  - Buildability/support logic starts near lines 2600 and 2654.
  - Supported block filter is near line 2985.
  - Current supported blueprint pieces are stone/wood blocks, backwalls, and ladders.
  - Resource collection currently requires both 20 wood and 20 stone even when the remaining plan needs only one material.
- `Scripts/AIBTestScenarios.as`
  - Defines 26 integration scenarios, including material collection, delayed blueprints, construction, shared storage, and team isolation.
- `TODO.md`
  - Already calls for extracting blueprint data/network/render/editor responsibilities.
  - Calls for authoritative AI-visible data, a shared block catalog, placement validation, material summaries, and support/path-risk checks.

## Main Architectural Decision

Implement a server-side utility-based `StrategicBlueprintDirector`. Do not start with a neural network, LLM, reinforcement learning, or a full bot-versus-bot simulator.

The strategic boundary should be:

```text
World state -> candidate structures -> hard validation -> utility scoring
            -> active team plan -> phased tile tasks -> builder job assignment
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

The director controls jobs, not movement:

- Calculate remaining wood and stone shortages.
- Assign enough builders to wood and stone collection.
- Assign the remainder to construction.
- Build foundation/backwalls first, access components second, and the tactical shell last.
- Reserve each task for one builder.
- Cancel only plans that have become invalid or strategically irrelevant.

Expose `off`, `suggest`, and `auto` modes. Develop in `suggest` mode first, rendering the chosen ghost blueprint and its leading score reasons.

## Testing And Simulation Plan

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

The existing live/headless runner has historically stopped advancing near tick 51, so long strategic scenarios should not become a prerequisite until that is solved. Short deterministic tests and an abstract evaluator can progress independently.

## Implementation Milestones

1. Blueprint authority, immutable plan representation, shared catalog, and strategy event logging.
2. Suggestion mode with one gatehouse template and deterministic terrain validation.
3. Doors/platforms, material-aware procurement, task reservations, and construction phases.
4. Autonomous flag defense and emergency barrier behavior.
5. Frontline/chokepoint model with several competing templates.
6. Scripted-wave evaluation and scoring-weight tuning.
7. Optional contextual bandit learning template performance by map/threat context. This should come only after deterministic scoring and outcome metrics work.

## Recommended Immediate Next Step

Implement milestone 1 only:

- Define a `BlueprintPlan`/`BlueprintTask` data model.
- Extract a server-authoritative blueprint API that can publish deltas/snapshots to the existing renderer and builder compatibility grid.
- Preserve human and AI plan layers separately.
- Add plan/version/owner fields and event logging.
- Add tests for AI publication, human-plan preservation, team isolation, and completed-plan history.

Do not add strategic scoring inside `CustomRenderer.as`; that would deepen the coupling already identified in `TODO.md`.

## Previous User-Facing Recommendation

The recommended approach was a utility director rather than neural AI. Its key qualities should be:

- Explainable: show the selected intent and strongest score reasons.
- Responsive: react to pressure, terrain, resources, and match phase.
- Stable: finish useful work instead of replanning constantly.
- Varied: choose among similarly strong plans and support strategic personalities later.
- Counterable: structures have real material/time costs and imperfect tactical value.
- Testable: deterministic candidate tests first, abstract simulation second, real KAG waves third.

No source code was changed during the planning turn. This handoff file is the only created file.
