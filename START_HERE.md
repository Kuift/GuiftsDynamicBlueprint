# Start here: AI builder mod handoff

Consolidated 2026-09-13 from the repository notes and the paused 2026-07-20 work.
This is a **development checkpoint, not a finished or fully validated release**.
No KAG session was launched for this packaging task.

## What this project is

GuiftsDynamicBlueprint adds an RTS-style blueprint editor, an overseer view,
resource workers, and an autonomous construction director to King Arthur's Gold
(KAG). It is written mainly in KAG's AngelScript dialect, with PowerShell and
Python tools for collecting and comparing in-game evidence. There is no separate
standalone AI service to start or model to train.

An ordinary `aibuilder` walks, harvests wood, mines stone/gold, delivers materials,
retrieves supplies, and builds blueprints using real inventory and physics.
An `autobuilder` is a flying, inventory-free construction orb for isolating
planning/execution from runner navigation. It still uses production reservations,
support, placement, and completion rules, with one placement per 30 ticks.
An orb completing a plan does not prove an ordinary worker can fund or reach it.

CTF normally starts the director in automatic mode. Each team can receive one
guarded free bootstrap worker per round when a valid home and executable plan
exist. Players can also order workers manually. The production Chapter 1 sequence
is flag room, frontline tower, protected class workshops, home Tunnel, frontline
Tunnel, then Quarry/Storage; an invalid site falls through to the next valid stage.
Emergency defense may interrupt that progression.

## Read these in order

1. [AGENTS.md](AGENTS.md): mandatory repository rules and behavior invariants.
2. [GOAL_HANDOFF.md](GOAL_HANDOFF.md): authoritative active resume order, exact
   reproductions, accepted/rejected experiments, and evidence filenames.
3. [KAG_ENGINE_QUIRKS.md](KAG_ENGINE_QUIRKS.md): reproduced engine traps. Read before
   runtime, camera, pathing, launch, or handoff changes.
4. [RUNTIME_TESTING.md](RUNTIME_TESTING.md) and
   [AIB_TEST_AUDIT.md](AIB_TEST_AUDIT.md): how to test and what each verdict proves.
5. Read the area-specific reference below when needed.

This file is the onboarding map; `GOAL_HANDOFF.md` owns the active work queue.
Older dated checkpoints are historical evidence, not fresh instructions to run
their old queue. In particular, old headless-launch advice, source-contract test
counts, and claims that no wave dataset exists have been superseded. A later
record does not retroactively validate a different source revision or fixture.

| Reference | Use it for |
| --- | --- |
| [ai_blueprint_direction.md](ai_blueprint_direction.md) | Product mission, ownership boundaries, long-term completion criteria |
| [BUILDER_GUIDE_CHAPTER1_IMPLEMENTATION.md](BUILDER_GUIDE_CHAPTER1_IMPLEMENTATION.md) | Current construction progression, costs, geometry, and guide acceptance gaps |
| [AIB_GYM_METRICS.md](AIB_GYM_METRICS.md) | Resource, infrastructure, and wave score semantics |
| [kag_gym.md](kag_gym.md) | Evaluation architecture and historical experiment trail |
| [research/notes/BUILD_4762_BUILDER_PATHING_MAP.md](research/notes/BUILD_4762_BUILDER_PATHING_MAP.md) | Measured movement-controller ownership and callback ordering |
| [research/README.md](research/README.md) | Persistent TCPR tooling, local research layout, evidence limitations |
| [PUBLIC_SERVER_OPERATIONS.md](PUBLIC_SERVER_OPERATIONS.md) | Telemetry notice, moderator lifecycle, log retention |
| [README.md](README.md) | Player controls and feature overview |
| [TODO.md](TODO.md) | Secondary editor/refactor backlog; older runtime items need reconciliation |
| [AI_BLUEPRINT_DIRECTOR_HANDOFF.md](AI_BLUEPRINT_DIRECTOR_HANDOFF.md), [implementation status](AI_BLUEPRINT_DIRECTOR_IMPLEMENTATION_STATUS.md), [TESTING_METHODOLOGY_PLANNING.md](TESTING_METHODOLOGY_PLANNING.md), [AIBUILDER_PATHING_PLAN.md](AIBUILDER_PATHING_PLAN.md), [MANUAL_HUMAN_TEST_REPORT.md](MANUAL_HUMAN_TEST_REPORT.md) | Historical design, checklists, and reported observations; do not use as the current resume queue |

## Get the checkout ready

The handoff branch is `handoff/astra-2026-09-13` in
`git@github.com:Kuift/GuiftsDynamicBlueprint.git`. It includes the 53 previously
unpublished commits following `905d404`, plus the paused source, tools, notes, and
retained gym artifacts that were still uncommitted after `1f6bd3c`.
It deliberately retains the unaccepted stone experiment described below.
The source/evidence snapshot is commit `af1f6cd`; the following documentation
commit adds this guide and reconciles entry points without changing runtime code.

On a new Windows machine, install KAG separately, then clone into the exact mod
folder name. From the game's `Mods` directory, with no existing destination:

```powershell
git clone --branch handoff/astra-2026-09-13 git@github.com:Kuift/GuiftsDynamicBlueprint.git GuiftsDynamicBlueprint_vDev
Set-Location GuiftsDynamicBlueprint_vDev
git status --short
```

For an existing checkout, inspect its changes before fetching/switching branches;
do not overwrite somebody else's work. Several launchers and runtime paths embed
`GuiftsDynamicBlueprint_vDev`, so keep that directory name even though the remote
repository is named `GuiftsDynamicBlueprint`.

Enable `GuiftsDynamicBlueprint_vDev` as a line in the **KAG-root** `mods.cfg`,
preserving the host's other entries. This checkout already supplies
`Rules/CTF/gamemode.cfg` and its script wiring. All game overrides belong inside
this mod; never edit the installed game's `Base` directory.

The measured engine baseline is Windows KAG build 4762. A different installed
build requires renewed compatibility checks. Use PowerShell 7 (`pwsh`) for the
tooling; some scripts use syntax unavailable in Windows PowerShell 5.1. Python 3
is needed for the TCPR helper. The game executable, official maps, generated
`Manual/interface` API documentation, and Steam installation are supplied by KAG,
not this repository. Local TCPR credentials must be configured on the new host;
do not copy or commit another host's `autoconfig.cfg` or credentials. Inspect
[Tools/CODEX_TCPR_BRIDGE.md](Tools/CODEX_TCPR_BRIDGE.md) for TCPR configuration;
its optional in-game Codex job bridge is not required to develop the mod.

References under `../../Logs/`, `research/private/`, and `E:/Tools/KAGResearch`
are original-machine evidence or tooling, not clone dependencies. Retained
`Artifacts/aib_gym/` files travel with this checkpoint, including rejected and
inconclusive runs. Use exact run lists from `GOAL_HANDOFF.md`, not a wildcard over
every artifact. The optional untracked `Tools/ScriptedMapEditor` folder/archive
and root scratch file `sss` are excluded from the handoff. `Untitled.png` is kept
because the handoff cites it as a mining-deadlock baseline.

## Where the code lives

The main flow is world observation -> plan selection -> blueprint authority ->
worker assignment -> worker state machine -> physical outcome -> passive metrics.

| Area | Main files/folders |
| --- | --- |
| Worker entity and behavior | `Base/Entities/Characters/AIBuilder/AIBuilder.cfg`, `AIBuilder.as`, `AIBuilderBrain.as` |
| Flying construction worker | `Base/Entities/Characters/AutoBuilder/`, `Scripts/AutoBuilderCommon.as` |
| Player deployment/overseer chair | `Base/Entities/Industry/CTFShops/AIBuilderShop/AIBuilderShop.as` |
| World facts and accessible stock | `Scripts/AIBWorldModel.as`, `AIBHomeResourceCommon.as` |
| Director and candidate geometry | `Scripts/AIBStrategicDirector.as`, `AIBPlacementPlanner.as`, `AIBBlueprintTemplates.as`, `AIBStrategicTypes.as` |
| Roles, bootstrap, manual ownership | `Scripts/AIBStrategicJobs.as`, `AIBDirectorPolicy.as`, `AIBManualOrderCommon.as` |
| Plan/task authority, catalog, support | `Scripts/BlueprintData.as`, `BlueprintCatalog.as`, `BlueprintCommon.as` |
| Chapter 1 economy and resupply | `Scripts/AIBBuilderGuideCommon.as`, `AIBBuilderGuideResupply.as` |
| Movement | `Pathing/`, `Scripts/AIBStoneRouteCommon.as`, controller functions in `AIBuilderBrain.as` |
| Editor, selection, HUD, camera | `Scripts/CustomRenderer.as` and related blueprint scripts |
| Server configuration and commands | `Rules/CommonScripts/AIBDirectorPolicy.cfg`, `AIBStrategyWeights.cfg`, `AIBTelemetryPolicy.cfg`, `ChatCommands.as` |
| Runtime tests and passive monitor | `Rules/AIBTest/`, `Scripts/AIBTest*.as`, `AIBGymMonitor.as` |
| CTF measurement harnesses | `Scripts/AIBGymBenchmark.as`, `AIBInfrastructureBenchmark.as`, `AIBStrategyWaveHarness.as`, `AIBWaveFixtureCommon.as` |
| Launchers and offline analysis | `Tools/`, `research/tools/`; retained results in `Artifacts/` |

Ordinary travel primarily uses custom AngelScript `BrainPath`, with native
`CBrain` as a fallback and direct-key shaft/recovery controllers where needed.
Native brain `idle` is not proof that there is no path. Keep observation,
assignment, movement, and interaction ownership separate.

## The next work, in priority order

**Runtime is paused. Do not launch KAG merely because this handoff was opened.**
The previous user stopped game iteration to free the computer. This packaging
request does not resume it. Code inspection and preparation can proceed; wait
for an explicit runtime-resume instruction from the person operating that host.

1. **Compact protected-workshop access on official
   `Ferrezinhre_Totally_Transcendent`.** Planning/provisioning now reaches tick 30
   and base structures anchor at the Tent-level ground, row 73. Team 0's compact
   workshop at tile `(52,73)` is safely rejected because an optional leveling
   stair reaches flag-base no-build tile `(39,78)`. Adapt that home access leg
   around protected cells, such as a truncated stair plus supported landing or
   ladder. Preserve both 5x3 class shops, both independent exits, and a full
   2x2 player volume at every route node. Do not bypass no-build restrictions.
   Work starts in `AIBBlueprintTemplates.as` and `AIBPlacementPlanner.as`.
   Once runtime resumes, the next validation is a **fresh visible normal CTF**
   session on that official map, not AIBTest or a custom one-map CTF cycle.

2. **Resolve the unaccepted stone shaft-reentry experiment.** The current
   `AIBuilderBrain.as` candidate skips a stale above-surface corner after a
   miner falls back into its old shaft. The expanded
   `stone_route_prefers_reusable_open_corridor` fixture observes the bypass but
   has not proved physical resurfacing. Earlier attempts reused or statically
   toggled an actor and contaminated the result. Preserve the original actor's
   successful abort/surface proof, then use a fresh dynamic actor with a two-tick
   collision settle for the added leg. Exact anchor/corner coordinates and run
   IDs are in `GOAL_HANDOFF.md`. Validate actual resurfacing, replay the delayed
   Gloryhill boundary, and either accept with evidence or revert the experiment.
   AIBTest work remains deferred until the operator resumes that test path.

3. **Reproduce the separate base-supply approach pocket.** A target-free miner
   near `(104,319)` once stalled en route to the exact local shop `(220,308)`.
   Later forced probes reached their shops, so a blanket shop-center or siting
   change is unsupported. Capture the pinned home, shop identity, approach side,
   and low-level path nodes if it recurs. Do not weaken monitor thresholds.

4. **Close release acceptance gaps.** After resolving the focused failures and
   resuming the appropriate runtime path, obtain a complete current suite and
   relevant exact-map cohorts. Verify real late joins, two-team/spectator
   blueprint delivery, blueprint save/exit/restart/reload, and moderator telemetry
   lifecycle. Then reassess representative-map safety and public operation.

## What is and is not validated

- Last complete historical suite: **65 passed / 0 failed**,
  `console-26-07-18-18-49-07.txt`. It predates the unaccepted reentry experiment.
- Current registry: **78 scenarios; no complete current-suite pass**. Chapter 1
  and reservation fixes have focused evidence; see the audit for exact limits.
- A retained **48-trial / 24-pair** Gloryhill wave matrix passed its strict gates.
  It proves the named local seven-attacker fixture, not all maps or human sieges.
- Earlier workshop cohorts validate earlier geometry, not the new compact shell
  or two-exit roof hatch. Earlier resource wins do not validate later candidates;
  some later cohorts explicitly failed their throughput gates.
- Offline parser/comparator tests validate those tools only. Source inspection,
  log intent, a camera target, or a nonempty path is not a physical success.

Packaging checks on 2026-09-13: all ten `Tools/test_*.ps1` offline regressions
passed, as did `git diff --check` and local Markdown link checks. Re-parsing the
48 retained wave transcripts reproduced 24 pairs with all acceptance gates
passing; this rechecks historical records, not current runtime behavior.
KAG was not launched. The local startup check
found CTF, a blank mapcycle, shuffle enabled, blank AIBTest selectors, active CTF
rules, and no running KAG process. These checks are not AngelScript validation.

After runtime work, close the owned KAG process **before** restoring startup
settings because KAG rewrites its configuration on exit. Required handoff:
KAG-root `sv_gamemode = CTF`, blank `sv_mapcycle`, shuffle `true`; active mod
`Rules/CTF/gamemode.cfg`, no `.aibtest-disabled` rename; all three
`aibtest_*scenario` selectors blank. Keep normal CTF's full mapcycle. Leave KAG
open only when requested or while actively iterating visibly. Keep `AIB_DEBUG`
false and detailed event logging off outside diagnostics.

## Prompt to give the next agent

```text
Continue this KAG AI builder mod from branch handoff/astra-2026-09-13.
Read START_HERE.md, AGENTS.md, GOAL_HANDOFF.md, KAG_ENGINE_QUIRKS.md,
RUNTIME_TESTING.md, and AIB_TEST_AUDIT.md before changing behavior.
Inspect git status and preserve existing work. This is a development checkpoint:
the current 78-scenario source is not globally green and contains an unaccepted
stone-reentry experiment. Follow GOAL_HANDOFF.md's active priority order.
Start with the compact protected-workshop access rejection on official
Ferrezinhre_Totally_Transcendent: preserve the flag no-build cells, Tent-level
ground, both class shops, and both full 2x2 exits. Explain the proposed fix from
the current code and prepare it. Runtime remains paused until I explicitly
resume it; the first resumed test must be fresh visible normal CTF on that map.
Keep production changes bounded, use actual physical outcomes as evidence,
update the handoff with exact results, and never claim the mod complete from
offline checks or historical passes.
```
