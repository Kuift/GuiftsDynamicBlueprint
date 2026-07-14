# GuiftsDynamicBlueprint_vDev Agent Notes

Read `KAG_ENGINE_QUIRKS.md` before changing runtime, camera, pathing, test-launch, or handoff behavior. Add newly reproduced quirks there with reliable evidence and a workaround so later agents do not repeat the same failed assumption.

This is a King Arthur's Gold mod. Files inside this mod directory override matching files in the base game. Do not edit `King Arthur's Gold/Base` directly; add or change files under this mod's `Base`, `Rules`, `Scripts`, `Sprites`, or other mod folders.

Some functions are legacy and KAG/3D documentation is sparse. When in doubt, inspect working mods installed under `King Arthur's Gold/Mods`, especially:

- `Hunter4D`
- `Easy3D`
- `Easy3DExampleMod`
- `EasyUI`

When launching KAG for testing or gameplay debugging, start it in a visible window and leave it running. Do not use `-WindowStyle Hidden` or short auto-kill launches unless the user explicitly asks for a compile-only check.

### Test-ready handoff

CTF is the normal manual play-test mode. `AIBTest` and its one-map cycle are temporary automated-test settings only.

Before every final handoff after launching KAG:

- Close any agent-started `AIBTest` instance before restoring startup settings; KAG can rewrite `autoconfig.cfg` when it exits.
- Leave the KAG-root `autoconfig.cfg` with `sv_gamemode = CTF`, a blank `sv_mapcycle`, and `sv_mapcycle_shuffle = true`. A blank cycle lets CTF load `Rules/CTF/mapcycle.cfg`.
- Ensure `Rules/CTF/gamemode.cfg` exists, `Rules/CTF/gamemode.cfg.aibtest-disabled` does not, and the three `aibtest_*scenario` values in `Rules/AIBTest/gamemode.cfg` are blank unless the user explicitly requested a focused test be left selected.
- If KAG should remain open at handoff, launch a visible CTF localhost session after the cleanup and leave that CTF session running.

Never leave CTF paired with `Rules/AIBTest/aibtest_mapcycle.cfg`; CTF's map-vote script recursively reloads that one-map cycle and produces a black/restarting game window.

## Current AI Builder Files

- `Base/Entities/Characters/AIBuilder/AIBuilder.cfg` wires the AI builder blob and scripts.
- `Base/Entities/Characters/AIBuilder/AIBuilder.as` handles the player-facing "Harvest wood" button. AI builders spawn idle; this button sets `"ai builder state"` to `find_tree`.
- `Base/Entities/Characters/AIBuilder/AIBuilderBrain.as` is the server-only behavior state machine.
- `Base/Entities/Characters/AutoBuilder/AutoBuilder.cfg` and `AutoBuilder.as` define the collisionless director-test orb.
- `Base/Entities/Industry/CTFShops/AIBuilderShop/AIBuilderShop.as` deploys AI builders and sets their team to the caller's team.
- `Scripts/AutoBuilderCommon.as` owns the team flight-speed levels, gold cost, and the Autobuilder's fixed placement delay.
- `Scripts/CustomRenderer.as` owns the current overseer tree-selection UI and selected-tree marker rendering.

## Current AI Builder Behavior

The AI builder state enum is:

- `idle`
- `find_tree`
- `chop_tree`
- `find_log`
- `chop_log`
- `find_wood`
- `return_wood`

Normal flow:

1. A same-team player uses the AI builder's "Harvest wood" button.
2. `AIBuilder.as` sets state to `find_tree`.
3. `find_tree` picks a valid tree and switches to `chop_tree`.
4. `chop_tree` paths to the hit position and uses builder hit logic until the tree is felled or gone.
5. `find_log` waits up to `AIB_LOG_WAIT` ticks for logs, then either chops logs, collects loose wood, returns wood, or finds another tree.
6. `chop_log` chops `log` blobs and tracks pending generated wood.
7. `find_wood` picks up loose `mat_wood`.
8. `return_wood` goes to the same-team `tent`, with `hall` fallback, and drops carried/inventory `mat_*` resources there.

The AI does not intentionally drop resources in place. If no same-team tent or hall exists, it logs the missing-home condition when debug is enabled, switches to idle, and keeps the resources.

Full inventory only forces `return_wood` when the inventory contains a `mat_*` resource. A carried `mat_*` resource also forces `return_wood`.

### Autobuilder director-test orb

The AI workshop can deploy an `autobuilder` orb. It is a blueprint-only director worker: it has no inventory, treats wood and stone requirements as already paid, flies directly through terrain and blobs, and still uses the production blueprint reservation, support, repair, obstruction, workshop, and completion code. Do not replace it with raw `server_SetTile` scheduling.

Each orb places at most one successful blueprint block every 30 ticks. The AI workshop's gold button upgrades team-wide flight speed through 4, 6, 8, and 12 pixels per tick; every level costs 50 gold, resets each round, and never shortens the 30-tick placement interval. The purchase command must remain server-authoritative and same-team because generic Shop callbacks run only after requirements have been consumed.

While a live Autobuilder exists, the planner ignores ordinary-builder approach reachability and current material shortages, but retains intrinsic material/build-time scoring. The director assigns every Autobuilder to blueprint work and does not give director-owned runner builders new construction roles; an in-progress runner blueprint episode hands off at its normal safe boundary. Manually ordered runner builders remain under player control.

Autobuilders are selectable through the overseer rectangle, but accept only `Build blueprint`; wood and stone orders are rejected server-side. Run `Tools/test_autobuilder_contract.ps1` after changing the entity, executor special cases, shop upgrade, director isolation, planner bypass, test cleanup, or wave identity fields.

### Base workshop storage siting

When crate storage needs a builder shop, the AI searches nearby ground on both sides of the team home. A valid site requires a clear 5x3 workshop volume, solid support under all five columns, a grounded side approach, and no conflicts with no-build sectors, the active barrier, important buildings, or blocking blobs. The workshop must have at least six tiles of edge-to-edge clearance from a same-team tent, hall, or flag. The selected site is revalidated before wood is consumed and the shop is spawned; failed searches use a cooldown before retrying.

Resource delivery uses the same terrain-aware principle. Never restore a fixed offset such as `home - 9 tiles, -8 px`: on real CTF maps that point can be inside a slope or void and produce endless jump/repath loops. Search both sides for a clear standing cell with solid ground below, then use the workshop/crate at that grounded point.

Director storage pressure must count only stock an ordinary production builder can retrieve: loose `mat_*` near the selected tent/hall resource home plus same-team unpacked crates near the shared grounded storage point. Do not restore a global scan of tent, hall, workshop, builder, or remote-crate inventories; that can suppress collectors and make an unfunded plan look paid. `Scripts/AIBHomeResourceCommon.as` owns the shared eligibility used by world observation and the executor, while the advanced UI reads the server-synced accessible totals. Run `Tools/test_aib_accessible_stock.ps1` after changing home material radii, storage-point search, crate eligibility, world resource accounting, or the displayed shortage summary.

On maps with multiple tents/halls, director-owned ordinary runners are pinned to the exact resource home selected by world observation, even if another friendly home is closer to the runner. This keeps retrieval/delivery aligned with the stock that funded the plan. Manual orders retain nearest-home behavior; dead, enemy, or non-home pins are rejected, and stopping a director assignment clears the pin. Autobuilders never receive one. Run `Tools/test_aib_resource_home_identity.ps1` after changing world home selection, assignment, home fallback, or assignment cleanup.

### Blueprint support and role handoff

Unsupported foreground blueprint blocks are not automatically invalid. If a matching wood or stone backwall chain can connect them to terrain, the planner and executor must agree that the generated backwall is a legal dependency and the builder must place it before the foreground block.

Director role assignment is atomic at the resource-episode boundary. A builder already chopping a tree must finish the tree, process all logs from that tree, collect the resulting material, and return it before accepting a blueprint or mining role. Equivalent safe boundaries apply to stone and blueprint work. Do not switch jobs merely because one loose material stack was acquired.

Ordinary-builder allocation is shortage-proportional with one 250-material collector load per slot and retains one construction worker for an active plan when at least two runners exist. If both materials are short but only one collector slot exists, assign it to the larger shortage (wood wins an exact tie); never restore the old unconditional wood bias. Preserve already-correct director roles before filling open slots in network-ID order so small storage changes do not cause needless cross-role handoffs. Run `Tools/test_aib_role_allocation.ps1` after changing demand math, role stability, or assignment ordering.

Active-plan invalidation may retain an already-matching completed task, but pending repairable damage must pass the current barrier-side, no-build, and protected-building gates before repairability can preserve the plan. A new live restriction must invalidate unsafe repair work rather than being skipped by the same-team damaged occupant. Safe damaged fronts must still retain plan identity. Run `Tools/test_aib_active_plan_invalidation.ps1` after changing this ordering or replacement reasons.

### Stone mining

Stone miners prefer a reusable, low-dirt route made from a two-wide shaft and cross-tunnel. The route requires a clear surface approach, uses direct shaft movement, and only destroys dirt on the chosen route; bedrock and castle obstructions reject the route. Dedicated tunnel movement suppresses generic obstruction jumps and recovery ladders so it cannot fight the shaft controller. A miner also discovers line-of-sight gold, mines the visible cluster, then returns it to the assigned base crate immediately after that cluster is exhausted. Mirrored upper-corner recovery drives the miner away from either left or right overhang instead of repeatedly jumping in place.

Run `Tools/test_aib_corner_recovery_contract.ps1` after changing overhang geometry detection, direct escape ownership, cooldown behavior, or the mirrored recovery fixture. The fixture must observe the complete 36-tick cycle and 90-tick cooldown with at least one tile of displacement on both sides; merely seeing an escape event or transient key press is insufficient.

## Resource Filters

Tree, log, and loose wood targets pass through accessibility checks before the AI commits to them.

Barrier rule:

- `AIBuilderBrain.as` includes `RedBarrierCommon.as`.
- While `shouldBarrier(rules)` is true, resources must be on the same side of `barrier_x1`/`barrier_x2` as the AI builder.
- Resources inside the barrier strip or across the barrier are ignored.

Safety rule:

- Resources are unsafe if an enemy `knight` or `archer` is within 10 tiles and there is a solid-free ray from the resource to that enemy.
- If terrain blocks the ray, such as a tall wall between enemy and resource, the resource remains valid.

Tree priority:

- Tree selection prefers trees close to the AI builder's team home (`tent`, then `hall`).
- Builder distance is included as a small tie-breaker, currently `homeDistance + builderDistance * 0.20`.
- A selected tree is temporarily abandoned only after 300 advancing ticks with neither an 8-pixel distance improvement nor any tree-health reduction. Every successful hit resets the watchdog, so it must never stop a slowly chopped tree a few hits before it falls. Abandoned trees cool down for 900 ticks so another target can be tried.

Overseer selection:

- Every player is currently treated as an overseer.
- Pressing `X` opens the existing blueprint menu with a custom-rendered `Select trees` control.
- The control is not implemented with KAG button helpers. It uses Inventory/EasyUI-style tick-side hover/press/release state and simple `GUI::DrawRectangle`/`GUI::DrawTextCentered` rendering.
- In tree selection mode, click-dragging a rectangle toggles trees in that tile area.
- Selected trees store synced bool `"aibuilder selected tree"` and a local tag `"aibuilder selected tree"`.
- Selected trees get a marker from `RenderSelectedTreeMarkers`.
- If at least one tree is selected, AI builders only consider selected trees. If no trees are selected, normal tree selection is used.
- `Confirm trees selection` exits selection mode. Right-click/cancel also exits.

## Movement And Threat Response

The builder uses a hybrid of base KAG pathing and direct key movement:

- Long or obstructed movement uses `CBrain.SetPathTo`, `SetSuggestedKeys`, and path states.
- Close visible movement can switch to direct key presses through `AIB_PathTo`.
- `AIB_DetectObstructions` watches low movement and alternates between repathing and direct movement if stuck.
- `AIB_ScaleObstacles` presses up on ladders, in water, on walls, or when blocked horizontally.

Enemy knights interrupt work:

- If an enemy `knight` is within 10 tiles and has a solid-free ray to the builder, the AI clears its target/path and runs away for that tick.
- Terrain between the knight and builder suppresses this fear response.

## Debug Logging

`AIBuilderBrain.as` has:

```angelscript
const bool AIB_DEBUG = false;
const u32 AIB_DEBUG_SNAPSHOT_RATE = 150;
```

Set `AIB_DEBUG` to `true` only while testing. It uses `print()`, so leave it `false` for deployed builds.

When enabled, search KAG logs for `[AIBuilder]`. Messages include:

- state transitions and reasons
- target netid and target name
- pending wood
- wood/resource possession
- direct movement mode
- periodic brain/path snapshots
- ignored resources due to barrier or unsafe enemy zone
- knight flee events
- missing team home during resource delivery

Useful signs:

- `state find_log -> return_wood`: logs are gone and harvested wood exists.
- `state return_wood -> find_tree reason=wood delivered`: resource delivery completed.
- `brain=stuck` or high `obstruction`: navigation is likely the issue.
- `outside current barrier zone`: resource was across or inside the red barrier while active.
- `unsafe enemy zone`: enemy knight/archer had direct access to the resource.
- `fleeing enemy knight`: harvesting was interrupted by nearby reachable knight threat.
- `no team home found; cannot drop resources`: no same-team tent or hall was found.

`[AIBEVT]` event logging is controlled at runtime by:

```angelscript
rules.get_bool("aib event log enabled")
```

`Scripts/AIBTestEventLog.as` enables it for the AIBTest gamemode and resets `aib event log seq`. Normal deployed gameplay should leave it disabled unless explicitly debugging. Event records are compact, machine-readable lines for test actions, player-equivalent commands, UI selection rectangles, AI state/target changes, resource rejection, no-home handling, and cleanup.

Repeated resource/candidate rejections and reservation renewals must be change-only or rate-limited. Log a reservation when ownership actually changes, not on each renewal tick. Public player telemetry is binary delta-framed in memory and flushed in coarse base64 batches; never replace it with per-tick formatted strings. Schema v2 record kinds 5-8 cover tile mutation, important-blob creation, death, and changed resource/economy totals. Schema v3 kind 9 adds accepted human blueprint/director actions, director-shop purchases, and production plan publish/archive/task reserve/complete/damage boundaries through a bounded rules queue; kind 10 reports queue loss rather than silently presenting incomplete evidence. Attribution confidence distinguishes explicit engine ownership from active-nearby, passive-nearby, and unattributed inference. `Tools/parse_aib_player_actions.ps1` remains backward compatible with v1/v2; `Tools/summarize_aib_player_episodes.ps1` emits heuristic raw task episodes and counts accepted player boundaries. These v3 AngelScript hooks pass offline parser tests but have not yet been KAG-runtime compiled. Generic hit and pickup/drop boundaries remain.

`Rules/CommonScripts/AIBTelemetryPolicy.cfg` owns the CTF capture default and built-in player notice. A moderator `!aib_telemetry on|off|status` override must survive round restarts. Disabling capture must flush the current batch; re-enabling starts a distinct episode and notifies connected players who have not yet received the notice. Never move the default assignment back into per-round episode reset. `PUBLIC_SERVER_OPERATIONS.md` owns the external console-log rotation/retention procedure. Run `Tools/test_aib_telemetry_policy.ps1` after changing this lifecycle, notice delivery, moderator status, or the runbook.

`AIBGymMonitor.as` is a passive observer and uses 16-bit failure flags. It covers motion stall, jump loop, path thrash, active-job/no-intent, state stall, target thrash without outcomes, accessible blueprint-resource deadlock, stale/dead reservations, and repeated invalid-build attempts. It must never press keys, change state/path, hit, or place tiles. Reservation expiry has a five-tick renewal grace because the observer runs before behavior. Inventory/plan outcome scans are staggered every five ticks across builder netids; do not move full inventory traversal back to every tick. Public CTF emits one compact numeric `[AIBGYM]` line on the first latched failure and one `[AIBGYMW]` binary window with up to 30 pre/12 post samples. Parse them with `Tools/parse_aib_gym_failures.ps1` and `Tools/parse_aib_gym_windows.ps1`. These are intentionally one-shot, not per-tick logging. AIBTest delays its failure verdict just long enough to collect the post tail. Run the monitor and both parser regressions after changing the schema or retry paths. The advanced classifiers are statically verified but need runtime false-positive calibration.

Episode summaries retain attribution-weighted outcomes and low-confidence counts; do not credit inferred proximity as explicit ownership. `Tools/compare_aib_task_episodes.ps1` compares only identical coarse `context_key_v1` cohorts, defaults to three episodes per side, and leaves quality gates opt-in. Run `Tools/test_compare_aib_task_episodes.ps1` after changing episode fields or matching logic. Context keys and scalar costs are heuristics, not proof that an AI change is good.

Production director placement weights and offline abstract-template metadata share `Rules/CommonScripts/AIBStrategyWeights.cfg`. `Scripts/AIBStrategyWeights.as` loads it for `AIBPlacementPlanner.as`; `Tools/aib_strategy_abstract_sim.ps1` consumes the same file. Run `Tools/test_aib_strategy_weights.ps1` after changing keys or consumers. The current static contract covers 68 keys, including extra wood/stone penalties for the portion of a plan not covered by current storage. This discourages dead-on-arrival large plans without hard-rejecting work that future harvesting can fund. The AngelScript loader still needs its first visible KAG compile when runtime testing is permitted.

Strategy wave records use fixture id/version, team, left/right side, scenario, seed, canonical pre-warm-up fingerprint, and measurement-start fingerprint. `Tools/compare_aib_wave_results.ps1` groups on fixture/version/team/side before scenario/seed, requires exactly one control and one plan, and defaults to three distinct seeds per cohort. Do not weaken this to global seed/scenario pairing. All wave types use the seed for deterministic spawn cadence and formation. Run both `Tools/test_aib_wave_contract.ps1` and `Tools/test_compare_aib_wave_results.ps1` after changing the harness or record schema. These AngelScript additions are statically verified but not yet KAG-runtime compiled.

Wave fixture version 3 uses `Scripts/AIBWorldFingerprint.as` for both initial and measurement boundaries. Run `Tools/test_aib_world_manifest_contract.ps1` after changing fingerprint inputs or consumers. Keep its blob fold order-stable and privacy-safe: never add usernames, network ids, or absolute game time. Full-map no-build scanning happens only at the two wave boundaries and still needs runtime performance calibration.

`Tools/new_aib_wave_matrix.ps1` generates the canonical 48-trial/24-pair NDJSON collection manifest for two sides, four scenarios, and three seeds. Each trial is marked `requires_fresh_canonical_reset`; the tool schedules evidence but deliberately does not claim to reset or drive KAG. Its regression is `Tools/test_new_aib_wave_matrix.ps1`.

Use `Tools/run_aib_tests.ps1` for automated coverage. The current suite has 65 scenarios and a complete successful run should end with:

```text
AIB tests passed: 65 passed, 0 failed
```

The game log must also contain the matching `[AIBTEST] DONE` marker. The launcher waits for it; matching START/PASS counts alone are not completion. Intermediate fixtures receive a short visual hold and cleanup. The final selected fixture emits `DONE` immediately after its verdict and is intentionally retained for inspection until the AIBTest process is closed.

Use `-Scenario <name>` for one scenario, or the inclusive `-StartScenario <name> -EndScenario <name>` range. By default the runner opens a visible `RunLocalhost` AIBTest session and leaves KAG running. Fast verdicts retain their fixture for 15 ticks so the client can show them. Use `-StopAfterRun` only when an explicit stop is wanted. If neither the log nor simulation advances for 25 seconds, the runner reports a distinct stale simulation/log diagnostic rather than a normal completion timeout.

`AIBTestCamera.as` is intended to own the test camera, but its current logs do not represent the displayed view reliably. Human observation is authoritative. Known symptoms include sticking upper-left, recentering to the map middle, jitter between competing positions, losing scene follow, and blocking manual movement. Do not cite `CAMERA_TARGET`/`CAMERA_VIEW` records as proof that camera following works.

Visible `RunLocalhost()` can also stop advancing, so long free-form behavior should receive a manual visual check. The current source has no recorded full 65-scenario pass: keep focused results distinct from full-suite evidence.

AIBTest captures the originally loaded map tile array once, restores every changed terrain tile and owner-tracked temporary no-build sector during cleanup, and validates dimensions/hash, live fixture/bootstrap tags, temporary-sector tracking, plan ids, and director modes before the next setup. Do not replace this with generated flat terrain: the canonical snapshot must preserve the real `aib_suite.png` pathing geometry. Run `Tools/test_aib_canonical_fixture_contract.ps1` after changing scenario lifecycle code. The newest production-planner fixtures cover simultaneous full completion of safe inward plans for both team directions, full production-path fallback completion after a blocked primary on uneven near-edge terrain, exact shortage-pressure scoring, emergency selection under collapsing frontline pressure, damaged-front reactivation without plan replacement, full physical completion of a selected plan by the production Autobuilder executor, rejection of mirrored locally clear sealed bootstrap pockets, full fallback completion after exact no-build, protected-building, or active-barrier rejection, and mirrored blocked-site cooldown/round-reset provisioning. The mirrored and uneven fixtures select and publish without Autobuilders so ordinary reachability remains enforced, then spawn production Autobuilders and require exact task/layer/reservation/archive completion. The uneven case also preserves both obstruction tiles (compatible reuse as an already-matching stone task is legal). The bootstrap fixture occupies every legal 6-24-tile spawn distance on both sides, requires the exact retry cooldown, clears the blockers, proves cooldown still holds, then uses the production round reset to provision exactly one safe assigned worker per team. Run `Tools/test_aib_representative_director_contract.ps1` after changing planner fixtures and `Tools/test_aib_bootstrap_connectivity.ps1` after changing provisioning reachability or lifecycle. `Tools/test_aib_scenario_registry.ps1` ensures all 65 unique names have exactly one setup and evaluation case. These new fixtures are statically contracted but not yet KAG-runtime verified.

Current operator constraint (2026-07-10): the user needs the computer and KAG pop-up windows are disruptive. Do not launch KAG until the user explicitly permits visible runtime testing again. Static checks and documentation work may continue.

The newest scenarios are `strategic_damaged_front_reactivates_without_plan_replacement`, `strategic_autobuilder_physically_completes_selected_plan`, `strategic_bootstrap_rejects_sealed_cave_spawn`, `strategic_no_build_primary_falls_back_and_physically_completes`, and `strategic_occupied_primary_falls_back_and_physically_completes`; all still need their first visible KAG compile and verdict. The earlier repair scenario has a complete focused pass in `console-26-07-10-17-32-06.txt`. Overflow production code compiles, but the final lightweight fixture (one wood stack plus eight distinct fillers) has not been run; earlier attempts either froze during an oversized same-tick inventory fixture or correctly showed that identical material blobs merged and did not fill the crate.

Run `Tools/test_aib_overflow_storage_contract.ps1` after changing base crate/workshop payment, crate-site validation, merge-capacity checks, or the overflow fixture. A slot-full crate is mergeable only when a matching stored stack is below `maxQuantity`; a positive material count alone does not prove capacity. The focused verdict must prove the delivered material is inside base crates as well as globally conserved.

## Strategic Director Bootstrap

- `CustomRenderer.as` always shows the local team's `Director AI: ON/OFF` status and a server-authoritative `Turn on`/`Turn off` button. The button toggles between `auto` and `off`; suggestion mode remains available through the strategy command and is displayed as automatic orders being off.
- A manual `Build blueprint` order in suggestion mode explicitly activates the visible suggested plan for that builder without enabling autonomous role assignment. Blueprint wait bubbles distinguish paused suggestions, reservations, and physically blocked work.
- `Rules/CommonScripts/AIBDirectorPolicy.cfg` owns the public CTF startup policy. It defaults CTF to autonomous strategy with guarded first-worker provisioning; AIBTest remains off and other modes remain suggestion-only. Administrators can change `ctf_default_mode` or `ctf_bootstrap_enabled` and restart/reload rules.
- Provisioning requires a same-team resource home (`tent`, then `hall`), an active non-empty auto plan, and zero live team AI builders. A surviving flag remains a strategic planning anchor but is not a valid resource-delivery or free-runner spawn anchor.
- It searches both sides of the resource home for a grounded, clear, barrier-safe spawn that belongs to a bounded terrain route flood-filled from the nearest standing cell at that home; locally clear sealed caves are rejected. The reachability map and blocker bounds are each built once per spawn attempt, and failed searches cool down before retrying.
- At most one free bootstrap worker is granted per team per round. Its death does not trigger another free worker.
- A moderator on a playing team can use `!aib_bootstrap on|off|status` to change that team's free-bootstrap policy at runtime. Toggling policy must never clear the round grant or retry deadline, and disabling it must not kill an existing worker.
- Builders are assigned deterministically by network ID, and AI-builder death immediately releases its task reservation.
- If a flag survives but every tent/hall is lost, the active plan remains available and inventory-free Autobuilders may continue, while ordinary director-owned runners release reservations and stop until a resource home returns. If every flag/tent/hall is gone, the active plan is archived as `home_lost`, its live AI layers are cleared, and all director assignments stop. Manual player orders are not affected.
- This is a free server spawn rather than a workshop purchase; economy balance and representative-map safety are still acceptance work.
- Run `Tools/test_aib_director_policy.ps1` after changing startup defaults, policy loading, bootstrap initialization/reset, or the moderator command.
- Developer CTF autostart may force one team-0 worker without an active plan so an unattended smoke test can run. The override is team-scoped to avoid spawning an unnecessary enemy worker and doubling AI load. This is developer-only; public CTF provisioning remains plan-gated.
- `AIBCTFDevScenario.as` is the unattended real-CTF acceptance path. It waits for a worker, lets an active harvest episode finish, then requests blueprint work and verifies a generated backwall plus foreground block with exact material accounting.
- Bootstrap spawn search snapshots relevant blob bounds once per attempt. Do not put `getBlobs()` back inside the candidate loop; the old form could perform roughly 950 full-world scans in one director heartbeat.

## Zombies_Reborn AI Takeaways

`Zombies_Reborn` was used as a reference for how KAG mods build practical AI.

Main pattern:

- Zombies use `generic_brain`, but most ground movement is direct key pressing rather than engine pathfinding.
- Brains decide intent: target, destination, aim, and pressed keys.
- Movement physics are separated into movement scripts with per-creature constants.
- Attack effects are separated into blob scripts.
- Expensive decisions are throttled with randomized brain delays, and old keys are reused between decision ticks.
- Obstruction recovery is explicit: jump, climb, attack obstructions, or reset target/destination.

Contrast with base KAG:

- Base KAG character bots lean on `BrainCommon.as`, `CBrain.SetPathTo`, `SetSuggestedKeys`, and class-specific strategy states.
- Base KAG is better for player-like precision. Zombies_Reborn's direct movement is better for hordes and simple destructive enemies.

Practical guidance for future AI work in this mod:

- Use a shared rules-level target cache only when many entities need the same target set.
- Keep AI intent in the brain, but keep physics/attack side effects outside the brain when behavior grows.
- Use direct movement for close, visible, simple goals; use `SetPathTo`/`SetSuggestedKeys` when navigation precision matters.
- Always include stuck recovery and debug logs that can be disabled with one constant.
- Avoid KAG UI button helpers for custom overlay controls in this mod; prefer Inventory/EasyUI-style manual input state and simple GUI rendering.
