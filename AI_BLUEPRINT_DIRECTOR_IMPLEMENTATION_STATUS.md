# AI Blueprint Director Implementation Status

Updated: 2026-07-02

This is the active resume checkpoint for `AI_BLUEPRINT_DIRECTOR_HANDOFF.md`. The deterministic blueprint director implementation is now live-verified against the full AIB test suite. A requirement-by-requirement audit and manual tuning can still be useful, but there is no known failing automated AIB scenario at this checkpoint.

## Implemented

- Server-authoritative human and AI blueprint layers with immutable desired-plan history, team/version metadata, snapshots, and human-wins merge behavior.
- Shared blueprint catalog used by the editor/network path and AI planner, including doors and platforms.
- Prefab dimension/cell-count validation and one-version, one-rebuild batch application for human prefabs.
- Atomic whole-prefab catalog validation before authoritative mutation, plus map-sized client snapshot validation.
- Strategy types, event logging, team world model, five procedural template families, multiple fitted anchors, utility scoring, score reasons, hard validation, hysteresis, and explicit invalidation/emergency replacement rules.
- World observations for homes, frontline, terrain, chokepoints, combat mix, explosive/fire pressure, recent incursions, resources, and builders, with regional terrain refreshes.
- Validation for bounds, protected blobs, support/dependency phases, duplicate plans, friendly routes, and reachable task approaches.
- Construction phases, per-builder reservations, completion/damage history, material-aware procurement, and door/platform construction support.
- `off`, `suggest`, and `auto` modes; suggestion rendering does not assign builders.
- Deterministic AIB scenarios expanded in place (suite remains 42 scenarios).
- Seeded abstract simulator with shared world snapshots, competing-template scoring, hysteresis-driven replans, and regression assertions.
- Scripted in-engine knight/archer/bomb/mixed waves with expanded outcome metrics.
- Strict paired wave-result comparator and synthetic regression test.
- Paired mixed waves derive unit roles and bomb behavior from seed plus spawn index, never runtime network IDs.
- Friendly route slowdown is measured as a local BFS path-length delta against identical terrain without the candidate; blocked routes receive a full penalty and new access receives a negative improvement value.

The optional contextual-bandit milestone was intentionally not implemented. The design document explicitly places it after deterministic scoring and outcome measurement; it is not required for the deterministic director.

## Requirement Evidence Matrix

| Design-contract requirement | Current evidence | State |
| --- | --- | --- |
| Server blueprint authority and publication outside the renderer | `BlueprintData.as`, `BlueprintNetwork.as`; `CustomRenderer.as` calls these APIs | Implemented and live-verified |
| Immutable desired intent plus consumable work | `ai_desired` and `ai_work` layers; archived desired/task arrays; completion/damage refresh | Implemented and covered by scenario 27/38 |
| Human/AI layer separation and human priority | Compatibility merge selects human first; AI publication rejects human overlap | Implemented and covered by scenarios 26/36 |
| Shared editor/planner/validation/cost/render/place catalog | `BlueprintCatalog.as` is consumed by editor selection, renderer labels, planner, data validation, and builder placement | Implemented |
| Doors, platforms, and friendly passage | Catalog/blob placement plus all five templates; gatehouse has paired doors, platforms, and internal ladders | Implemented and live-verified by scenarios 33/34/35 |
| Remaining-plan material procurement | Remaining total/minimum costs and target-specific material collection | Implemented and covered by scenario 16 |
| Reservations and phases | Per-task/loose reservations with expiry; foundation -> access -> shell phase gating | Implemented and covered by scenarios 29/41 |
| Periodic world model | 30-tick observations; static surface/lane-width/wall-height cache plus regional refresh; homes, combat mix, pressure heat, resources, jobs, plan state, explosives/fire | Implemented |
| Procedural competing candidates and anchors | Gatehouse, tower, emergency barrier, directional-cover perch with validated sight line, and access route; home/frontline/choke/high-ground anchors | Implemented and covered by scenario 39 |
| Hard validation | Bounds/catalog, human overlap, bedrock/terrain/buildings, barrier, shared non-ladder no-build enforcement, support, build reach, sight line, route, horizon, duplicate checks | Implemented and covered by scenarios 35/36/40 |
| Explainable utility selection and controlled variety | Named score terms, score reasons, near-best 7% choice, continuity and template cooldown | Implemented |
| Stable cancellation policy | Active plans survive better scores; replacement only for invalidation or frontline-collapse emergency; completed-plan delay | Implemented and covered by scenario 37 |
| Off/suggest/auto and coordinated jobs | Chat modes, ghost-only suggestion, auto work publication, shortage-proportional jobs | Implemented and covered by scenario 32 |
| Three-layer evaluation | 42 deterministic scenarios; seeded lane simulator; seeded real-physics waves and strict pair comparator | Implemented; full KAG suite passed 42/42 on 2026-07-02 |
| Required outcome metrics | Cost/completion, builder travel/idle/deaths, reservation conflicts, breach/crossing/flag approach, damage/lifetime, route path delta, replans | Implemented |

## Important Changed/Added Files

- `Scripts/BlueprintCommon.as`
- `Scripts/BlueprintCatalog.as`
- `Scripts/BlueprintData.as`
- `Scripts/BlueprintNetwork.as`
- `Scripts/AIBStrategicTypes.as`
- `Scripts/AIBWorldModel.as`
- `Scripts/AIBBlueprintTemplates.as`
- `Scripts/AIBPlacementPlanner.as`
- `Scripts/AIBStrategicDirector.as`
- `Scripts/AIBStrategyEventLog.as`
- `Scripts/AIBStrategyWaveHarness.as`
- `Scripts/CustomRenderer.as`
- `Base/Entities/Characters/AIBuilder/AIBuilderBrain.as`
- `Tools/aib_strategy_abstract_sim.ps1`
- `Tools/test_aib_strategy_abstract_sim.ps1`
- `Tools/compare_aib_wave_results.ps1`
- `Tools/test_compare_aib_wave_results.ps1`

## Verification Already Completed

- `Tools/test_aib_strategy_abstract_sim.ps1`: pass on 2026-07-02.
- `Tools/test_compare_aib_wave_results.ps1`: pass on 2026-07-02.
- Visible KAG AIBTest run: `../../Logs/console-26-07-02-05-47-07.txt`.
- Live result: 42 scenarios started, 42 passed, 0 failed.
- The final live scenario `human_blueprint_reservation_exclusive` passed after switching the reservation-only duplicate-owner check to synthetic net IDs.
- The temporary `Rules/CTF/gamemode.cfg.aibtest-disabled` rename was restored; `Rules/CTF/gamemode.cfg` is present.

## Remaining Verification

1. Review `git status`/`git diff` and keep commits split by coherent feature area.
2. Perform a final checklist against every non-optional requirement in `AI_BLUEPRINT_DIRECTOR_HANDOFF.md`.
3. Manual gameplay tuning remains useful for long real tree-chopping/building flows that the headless-style suite intentionally simulates or shortens.

## Exact Resume Commands

From the mod root in PowerShell:

```powershell
& .\Tools\test_aib_strategy_abstract_sim.ps1
& .\Tools\test_compare_aib_wave_results.ps1
rg -n "const bool AIB_DEBUG|ERROR|ERR|Script Error" Base Scripts
git status --short
```

For KAG, use a visible `Start-Process` launch; do not use `-WindowStyle Hidden` and do not auto-kill it. The AIBTest/CTF configs have a duplicate gamemode-name collision, so the established test procedure temporarily renames `Rules/CTF/gamemode.cfg`, starts KAG, then restores that file after the run. Verify both paths before and after the rename.

## Last Known Runtime State

- Last observed live log: `../../Logs/console-26-07-02-05-47-07.txt`.
- That run passed all 42 AIB scenarios with 0 failures.
- KAG exited after the last pass line; no KAG process remained when the CTF config was restored.
- `AIB_DEBUG` remains `false`.
- No temporary `.aibtest-disabled` config remains at the checkpoint.

## Latest Verified Fixes

- Planner task reachability now uses the builder's actual 32 px/four-tile placement reach instead of requiring every roof/wall task to have an immediately adjacent traversable cell.
- Door/platform fixtures were moved outside the tent's no-build sector; production placement continues to respect no-build sectors.
- The material collection scenario now requests and builds one wood and one stone tile, so it genuinely exercises both material pipelines.
- The shared-crate scenario now prevents the first builder from immediately withdrawing its deposit before the second builder stores resources.
- Strategic scenario failures report individual predicate values for precise follow-up.
- Mixed-wave decisions now use seed plus spawn index, and accumulated damage cost survives repair.
- Friendly slowdown reports a candidate-versus-baseline BFS path-length delta rather than a binary proxy.
- Terrain snapshots now cache surface, lane width, and wall height; archer perches require a directional sight line.
- All non-ladder blueprint pieces consistently respect no-build sectors, including manually published work.
- Static caches and pressure state are reset on match restart; wave/debug state is also reset and event logging is disabled after a wave.
- Empty/unloaded map guards prevent terrain feature lookups from indexing empty arrays.
- AIB barrier checks now use `AIBBarrierCommon.as`, allowing tests to force logical barrier rejection without putting KAG into real WARMUP/build-mode red-wall state.
- Test cleanup resets both game state and logical barrier keys.
- Quarry/base stone output accepted near a same-team quarry or home remains tagged as a valid base stone source, so unsafe tile scans do not reject already-produced stone.
- The final human loose-reservation exclusivity test uses synthetic reservation owner IDs instead of spawning a second live AI builder.

## Latest Non-KAG Checks

- `Tools/test_aib_strategy_abstract_sim.ps1`: pass.
- `Tools/test_compare_aib_wave_results.ps1`: pass.
- `AIB_DEBUG`: false.
- No KAG process and no temporary CTF config rename remain after the successful live run.

## Design Constraints To Preserve

- Never edit `King Arthur's Gold/Base`; all overrides stay in this mod.
- Human blueprint tiles override AI tiles, and autonomous replanning must never mutate the human layer.
- Keep strategic scoring out of `CustomRenderer.as`.
- Keep deployed `AIB_DEBUG` false.
- Prefer deterministic scoring/tests over adaptive learning until the wave metrics provide sufficient tuning data.
