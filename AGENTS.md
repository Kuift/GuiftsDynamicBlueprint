# GuiftsDynamicBlueprint_vDev Agent Notes

Read `KAG_ENGINE_QUIRKS.md` before changing runtime, camera, pathing, test-launch, or handoff behavior. Add newly reproduced quirks there with reliable evidence and a workaround so later agents do not repeat the same failed assumption.

The active map-scoped optimization resume point is `GOAL_HANDOFF.md`. Read it before continuing resource, infrastructure, traversal, workshop, or adversarial-survival work.

This is a King Arthur's Gold mod. Files inside this mod directory override matching files in the base game. Do not edit `King Arthur's Gold/Base` directly; add or change files under this mod's `Base`, `Rules`, `Scripts`, `Sprites`, or other mod folders.

Some functions are legacy and KAG/3D documentation is sparse. When in doubt, inspect working mods installed under `King Arthur's Gold/Mods`, especially:

- `Hunter4D`
- `Easy3D`
- `Easy3DExampleMod`
- `EasyUI`

When launching KAG for testing or gameplay debugging, start it in a visible window and keep it visible for the active run. Close KAG immediately after a completed or failed evidence run and verify that the process is gone. Leave it running only while actively iterating with reload/TCPR. Do not use `-WindowStyle Hidden` or short auto-kill launches unless the user explicitly asks for a compile-only check.

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
- `Base/Entities/Special/CTF/CTF_FlagCommon.as` overrides the shared pickup predicate so AI workers cannot accidentally capture CTF flags by collision.

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

The pre-target `find_log` wait and post-target log progress watchdog are separate. Waiting for KAG to create the first log is intentional and remains governed by `AIB_LOG_WAIT`. Once a live log is selected, the watchdog abandons only that log when there has been neither an 8-pixel approach improvement nor a successful hit; progress resets the window, and the abandoned log receives the existing cooldown. A Gloryhill 1200-tick smoke showed that a 90-tick candidate escaped one nominal but motionless `BrainPath` route earlier, but the exact-map three-run 180-second cohort rejected it: the 300-tick control averaged 630 wood versus 546.667 for the candidate, with three failure-flagged runs and zero deaths on both sides. The production value therefore remains 300 ticks. A later physical-recovery cohort kept 300 ticks and averaged 633.333 versus the retained 630 controls while improving failure runs from 3/3 to 0/3; that validates the route changes, not the rejected timeout. Do not present the focused smoke as throughput evidence or shorten `AIB_LOG_WAIT` with this post-target setting.

The AI does not intentionally drop resources in place. If no same-team tent or hall exists, it logs the missing-home condition when debug is enabled, switches to idle, and keeps the resources.

Full inventory only forces `return_wood` when the inventory contains a `mat_*` resource. A carried `mat_*` resource also forces `return_wood`.

Ordinary AI builders retain KAG's `player` tag, so the base CTF collision predicate would otherwise let a resource worker capture an enemy flag accidentally. The mod override of `Base/Entities/Special/CTF/CTF_FlagCommon.as` must continue rejecting `aibuilder` and `autobuilder` in `canPickupFlag`; human players remain unchanged. Resource gym episodes independently restore the exact flag and abort if a worker ever carries one. Never score or retain a contaminated episode.

### Autobuilder director-test orb

The AI workshop can deploy an `autobuilder` orb. It is a blueprint-only director worker: it has no inventory, treats wood and stone requirements as already paid, flies directly through terrain and blobs, and still uses the production blueprint reservation, support, repair, obstruction, workshop, and completion code. Do not replace it with raw `server_SetTile` scheduling.

Each orb places at most one successful blueprint block every 30 ticks. The AI workshop's gold button upgrades team-wide flight speed through 4, 6, 8, and 12 pixels per tick; every level costs 50 gold, resets each round, and never shortens the 30-tick placement interval. The purchase command must remain server-authoritative and same-team because generic Shop callbacks run only after requirements have been consumed.

While a live Autobuilder exists, the planner ignores ordinary-builder approach reachability and current material shortages, but retains intrinsic material/build-time scoring. The director assigns every Autobuilder to blueprint work and does not give director-owned runner builders new construction roles; an in-progress runner blueprint episode hands off at its normal safe boundary. Manually ordered runner builders remain under player control.

Autobuilders are selectable through the overseer rectangle, but accept only `Build blueprint`; wood and stone orders are rejected server-side. Validate affected behavior in visible KAG using the focused cases in `RUNTIME_TESTING.md`.

### Base workshop storage siting

When crate storage needs a builder shop, the AI searches nearby ground on both sides of the team home. A valid site requires a clear 5x3 workshop volume, solid support under all five columns, a grounded side approach, and no conflicts with no-build sectors, the active barrier, important buildings, or blocking blobs. The workshop must have at least six tiles of edge-to-edge clearance from a same-team tent, hall, or flag. The selected site is revalidated before wood is consumed and the shop is spawned; failed searches use a cooldown before retrying.

Resource delivery uses the same terrain-aware principle. Never restore a fixed offset such as `home - 9 tiles, -8 px`: on real CTF maps that point can be inside a slope or void and produce endless jump/repath loops. Search both sides for a clear standing cell with solid ground below, then use the workshop/crate at that grounded point.

Existing builder shops are base-scoped, not team-global. Storage delivery and the stone-supply wait point share a deterministic selector that requires the same team, the same active-barrier side, and a shop within the 28-tile production envelope around the exact resource home, then prefers the grounded storage area with a network-ID tie-break. A remote same-team shop must not suppress creation of a usable local workshop or redirect another base's runners. Overflow-crate affordability counts spendable builder inventory rather than a carried stack, pays the builder leg before taking home wood, and refunds that leg if the home withdrawal unexpectedly fails. Validate selection, payment, delivery, and conservation in visible KAG.

Director storage pressure must count only stock an ordinary production builder can retrieve: loose `mat_*` near the selected tent/hall resource home plus same-team unpacked crates near the shared grounded storage point. Do not restore a global scan of tent, hall, workshop, builder, or remote-crate inventories; that can suppress collectors and make an unfunded plan look paid. `Scripts/AIBHomeResourceCommon.as` owns the shared eligibility used by world observation and the executor, while the advanced UI reads the server-synced accessible totals. Validate exact accessible totals and the executor's actual source choice in visible KAG.

On maps with multiple tents/halls, director-owned ordinary runners are pinned to the exact resource home selected by world observation, even if another friendly home is closer to the runner. This keeps retrieval/delivery aligned with the stock that funded the plan. Manual orders retain nearest-home behavior; dead, enemy, or non-home pins are rejected, and stopping a director assignment clears the pin. Autobuilders never receive one. Validate the selected identity and physical retrieval/delivery destination in visible KAG.

### Blueprint support and role handoff

Unsupported foreground blueprint blocks are not automatically invalid. If a matching wood or stone backwall chain can connect them to terrain, the planner and executor must agree that the generated backwall is a legal dependency and the builder must place it before the foreground block.

Director role assignment is atomic at the resource-episode boundary. A builder already chopping a tree must finish the tree, process all logs from that tree, collect the resulting material, and return it before accepting a blueprint or mining role. Equivalent safe boundaries apply to stone and blueprint work. Do not switch jobs merely because one loose material stack was acquired. The director may overwrite the desired pending role while an episode is active; `AIBuilderBrain.as` must apply only the latest valid role at the first target-free boundary before the old find state can acquire another target between 30-tick observations. Role application clears the old reservation, engine/custom paths, specialized stone controller state, targets, and pressed actions while preserving director ownership and the assigned resource-home pin. Validate the complete old episode and first target-free role transition in visible KAG.

The advanced HUD derives wood/stone/blueprint counts from the canonical synced `"ai builder job"` and ignores idle `"ai builder state"`; do not introduce a duplicate resource-role property while those values remain sufficient. All authoritative job/state/active order paths sync immediately, brain initialization force-publishes the trio, and `AIBuilderBrain.as` adds a network-ID-staggered five-second heartbeat so late join or a dropped delta has bounded staleness. Keep the heartbeat coarse and staggered; never turn it into per-tick network traffic. A real mid-match client join is required before claiming runtime validation.

Human blueprint edits are server-authoritative. The active command player, team, overseer permission, edit cadence, catalog value, bounds, and prefab version are validated before the human layer changes; repeated same-value tile packets must not advance the human version or emit another action boundary. Display tile deltas and full snapshots use the existing command IDs with the targeted `CRules.SendCommand(..., player)` overload and may go only to that team or spectators. Do not broadcast blueprint contents and rely on enemy clients to ignore them. `BlueprintData.as` remains the AI-visible human/compatibility authority, and the client team filter remains defense in depth. Runtime delivery/non-delivery requires two teams plus a spectator.

Blueprint saving owns a committed local rectangle separate from the shared `mouseSelect` display/gesture rectangle. Tree, stone, or overseer drags must not change a later blueprint save. A save is invalid until the player commits a blueprint selection; inclusive 1x1 and asymmetric selections retain their exact width, height, x/y orientation, and centered placement footprint through runtime memory, PNG, packet serialization, and authoritative prefab placement. Validate with a real save, process exit, KAG restart, reload, and exact footprint comparison.

An accepted proximity-button or overseer wood/stone/blueprint order transfers that builder to durable player control. `Scripts/AIBManualOrderCommon.as` atomically releases director reservations, pending roles, paths/controller state, pressed actions, and the assigned resource-home pin before the manual state is applied. The server must validate the shared worker-order opcode before this ownership transfer; unknown packet opcodes must not mutate or release the worker. Automatic assignment must exclude manual runners and Autobuilders, but they remain live for free-bootstrap suppression and a live manual Autobuilder still isolates ordinary runners from director construction roles. Turning automatic direction on again explicitly releases the team's manual latches. Do not add another command ID for this handoff; the existing order opcode is sufficient. Validate accepted and unknown opcodes plus durable ownership in a real server session.

Ordinary-builder allocation is shortage-proportional with one 250-material collector load per slot and retains one construction worker for an active plan when at least two runners exist. If both materials are short but only one collector slot exists, assign it to the larger shortage (wood wins an exact tie); never restore the old unconditional wood bias. Preserve already-correct director roles before filling open slots in network-ID order so small storage changes do not cause needless cross-role handoffs. Validate the actual synchronized jobs and completed episodes in visible KAG.

Automatic assignment requires an active plan with pending tasks and a non-empty AI work layer. A completed, cancelled, suggestion-only, or absent plan must not reclaim workers as empty blueprint jobs. Autobuilders and runners already at a target-free role boundary retire immediately; a runner inside a wood, stone, or blueprint episode latches retirement and finishes that episode. `AIBuilderBrain.as` consumes the latch at the first safe boundary before a find state can select another target between director heartbeats. New executable work and every manual/stop ownership cleanup clear the latch. Validate immediate and deferred retirement at real episode boundaries in KAG.

Active-plan invalidation may retain an already-matching completed task, but pending repairable damage must pass the current barrier-side, no-build, and protected-building gates before repairability can preserve the plan. A new live restriction must invalidate unsafe repair work rather than being skipped by the same-team damaged occupant. Safe damaged fronts must still retain plan identity. Validate safe retention and every live restriction through focused KAG scenarios.

Generic obstruction recovery stages unsupported ladders in two paid phases. It places and charges only missing support backwalls, returns to simulation, and creates the ladder only after `hasSupportAtPos` recognizes the target on a later tick. Do not collapse this back into same-tick ladder-first creation or charge again for an existing backwall chain. The one-shot ladder path probe records the next low-level node, hypothetical mineable obstruction, and pathfinder acceptance; actual traversal remains the outcome proof. `kag_path_builds_supported_ladder_chain` must require support-before-spawn, a post-placement path probe, crossing the preserved dirt plug, and no partial-side-effect pass. The current fixture does not force ladder creation and must be redesigned before it can provide that evidence.

### Stone mining

Stone miners prefer a reusable, low-dirt route made from a two-wide shaft and cross-tunnel. The route requires a clear surface approach, uses direct shaft movement, and only destroys dirt on the chosen route; bedrock and castle obstructions reject the route. Dedicated tunnel movement suppresses generic obstruction jumps and recovery ladders so it cannot fight the shaft controller. When a route is selected, the miner records its canonical surface entry. A quota-complete miner in `return_wood` must traverse the open cross-tunnel back to that column and hold both wall direction and up until it exits; handing the underground runner directly to ordinary `BrainPath` strands it after one load. Clear the return anchor with normal navigation/ownership cleanup. A miner also discovers line-of-sight gold, mines the visible cluster, then returns it to the assigned base crate immediately after that cluster is exhausted. Mirrored upper-corner recovery drives the miner away from either left or right overhang instead of repeatedly jumping in place. It recognizes both ceiling-plus-diagonal traps and an isolated one-sided upper diagonal only when the opposite upper sample and body-height escape side are open; symmetric headroom is rejected.

After changing overhang geometry or recovery ownership, run `stone_corner_escape_from_mirrored_upper_overhangs` in visible KAG. It must observe the complete 36-tick cycle and 90-tick cooldown with at least one tile of displacement on both sides; merely seeing an escape event or transient key press is insufficient.

## Resource Filters

Tree, log, and loose wood targets pass through accessibility checks before the AI commits to them. Loose `mat_stone` is eligible only when it is within 12 tiles of the miner or is an exact-base source at the assigned home/storage/quarry boundary. Never restore a map-global loose-stone scan: on Gloryhill it selected enemy-side quarry output and pulled miners through the flag route.

Barrier rule:

- `AIBuilderBrain.as` includes `RedBarrierCommon.as`.
- While `shouldBarrier(rules)` is true, resources must be on the same side of `barrier_x1`/`barrier_x2` as the AI builder.
- Resources inside the barrier strip or across the barrier are ignored.
- The shared accessible-home-stock contract applies the same side test to loose material, grounded storage selection, and base crates. The director must not credit stock across the barrier that its assigned runner cannot retrieve. Validate the exact credited total and the runner's physical source choice in KAG.

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

The ordinary builder uses custom AngelScript `BrainPath` navigation, native
`CBrain` fallback, and specialized direct-key controllers:

- Normal long or obstructed travel uses `Pathing/BrainPathing.as` whenever the
  rules expose a usable `node_map`. `BrainPath` computes the route and writes
  runner keys through `CBlob.setKeyPressed`; native `CBrain` path state normally
  remains `idle`.
- `AIB_GoToFallback` is the only ordinary-travel branch that calls native
  `CBrain.SetPathTo` and `CBrain.SetSuggestedKeys`. It is used only when the
  node map/custom path is unavailable or does not yield a usable route.
- Close visible movement can switch to direct key presses through `AIB_PathTo`,
  and geometry-specific stone/recovery controllers can temporarily own keys.
- After confirmed obstruction, a nominal straight-down `BrainPath` node may use
  a bounded lateral walk-off toward the destination, while a straight-up node
  may use a bounded up-plus-away wall climb. These controllers exclude ladders,
  water, and dedicated stone-route movement and suppress generic obstacle
  scaling only while they own the keys.
- Downward ownership is geometry-qualified. It releases at an adjacent blocked
  side so normal jumping/corner recovery can clear a wall, but a far-side wall
  is permitted when the adjacent runner-width column remains open one tile
  below (a narrow drop). Keep the change-only `path_downward_steer` and
  `path_downward_release` events when modifying this boundary.
- `AIB_DetectBrainPathObstructions` handles custom-path progress;
  `AIB_DetectObstructions` handles native fallback progress.
- `AIB_ScaleObstacles` presses up on ladders, in water, on walls, or when blocked horizontally.

Do not interpret native `CBrain::idle` as proof that a builder has no active
route. See `research/notes/BUILD_4762_BUILDER_PATHING_MAP.md` for the measured
controller map and callback ordering.

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

Repeated resource/candidate rejections and reservation renewals must be change-only or rate-limited. Log a reservation when ownership actually changes, not on each renewal tick. Public player telemetry is binary delta-framed in memory and flushed in coarse base64 batches; never replace it with per-tick formatted strings. Schema v2 record kinds 5-8 cover tile mutation, important-blob creation, death, and changed resource/economy totals. Schema v3 kind 9 adds accepted human blueprint/director actions, director-shop purchases, and production plan publish/archive/task reserve/complete/damage boundaries through a bounded rules queue; kind 10 reports queue loss rather than silently presenting incomplete evidence. Attribution confidence distinguishes explicit engine ownership from active-nearby, passive-nearby, and unattributed inference. `Tools/parse_aib_player_actions.ps1` remains backward compatible with v1/v2; `Tools/summarize_aib_player_episodes.ps1` emits heuristic raw task episodes and counts accepted player boundaries. `console-26-07-14-07-53-21.txt` live-verifies schema-v3 interval batches and a production `plan_publish` boundary; the parser decoded 47 records. Generic hit and pickup/drop boundaries remain.

`Rules/CommonScripts/AIBTelemetryPolicy.cfg` owns the CTF capture default and built-in player notice. A moderator `!aib_telemetry on|off|status` override must survive round restarts. Disabling capture must flush the current batch; re-enabling starts a distinct episode and notifies connected players who have not yet received the notice. Never move the default assignment back into per-round episode reset. `PUBLIC_SERVER_OPERATIONS.md` owns the external console-log rotation/retention procedure. Validate this lifecycle in a visible CTF server with a real moderator and connected player.

`AIBGymMonitor.as` is a passive observer and uses 16-bit failure flags. It covers motion stall, jump loop, path thrash, active-job/no-intent, state stall, target thrash without outcomes, accessible blueprint-resource deadlock, stale/dead reservations, and repeated invalid-build attempts. It must never press keys, change state/path, hit, or place tiles. Reservation expiry has a five-tick renewal grace because the observer runs before behavior. Inventory/plan outcome scans are staggered every five ticks across builder netids; do not move full inventory traversal back to every tick. Public CTF emits one compact numeric `[AIBGYM]` line on the first latched failure and one `[AIBGYMW]` binary window with up to 30 pre/12 post samples. Parse them with `Tools/parse_aib_gym_failures.ps1` and `Tools/parse_aib_gym_windows.ps1`. These are intentionally one-shot, not per-tick logging. AIBTest delays its failure verdict just long enough to collect the post tail. Run the parser regressions after schema changes and calibrate monitor classifiers in visible KAG. Stationary successful interactions count as progress; never classify chopping, mining, building, or an explicit engine wait as a motion stall merely because position is unchanged.

Episode summaries retain attribution-weighted outcomes and low-confidence counts; do not credit inferred proximity as explicit ownership. `Tools/compare_aib_task_episodes.ps1` compares only identical coarse `context_key_v1` cohorts, defaults to three episodes per side, and leaves quality gates opt-in. Run `Tools/test_compare_aib_task_episodes.ps1` after changing episode fields or matching logic. Context keys and scalar costs are heuristics, not proof that an AI change is good.

Production director placement weights and offline abstract-template metadata share `Rules/CommonScripts/AIBStrategyWeights.cfg`. `Scripts/AIBStrategyWeights.as` loads it for `AIBPlacementPlanner.as`; `Tools/aib_strategy_abstract_sim.ps1` consumes the same file. After changing weights or consumers, load them in visible KAG and run the relevant selection fixture; run `Tools/test_aib_strategy_abstract_sim.ps1` only for the offline simulator itself. The 68 keys include extra wood/stone penalties for the portion of a plan not covered by current storage.

Strategy wave records use fixture id/version, team, left/right side, scenario, seed, canonical pre-warm-up fingerprint, and measurement-start fingerprint. `Tools/compare_aib_wave_results.ps1` groups on fixture/version/team/side before scenario/seed, requires exactly one control and one plan, and defaults to three distinct seeds per cohort. Do not weaken this to global seed/scenario pairing. All wave types use the seed for deterministic spawn cadence and formation. Validate the harness by collecting fresh KAG pairs; `Tools/test_compare_aib_wave_results.ps1` tests only the offline comparator.

Wave fixture version 3 uses `Scripts/AIBWorldFingerprint.as` for both initial and measurement boundaries. Keep its blob fold order-stable and privacy-safe: never add usernames, network ids, or absolute game time. Validate changed inputs through fresh paired KAG records. Full-map no-build scanning happens only at the two wave boundaries and still needs runtime performance calibration.

`Tools/new_aib_wave_matrix.ps1` generates the canonical 48-trial/24-pair NDJSON collection manifest for two sides, four scenarios, and three seeds. Each trial is marked `requires_fresh_canonical_reset`; the tool schedules evidence but deliberately does not claim to reset or drive KAG. Its regression is `Tools/test_new_aib_wave_matrix.ps1`.

AngelScript compilation and behavior must be validated in visible KAG through the TCPR runtime loop described in `RUNTIME_TESTING.md`. Source-text/regex contract scripts were removed because they did not compile or execute production AngelScript. Do not recreate them or cite offline source matching as KAG evidence. The remaining `Tools/test_*.ps1` files execute offline parsers, comparators, generators, or the abstract simulator and prove only those tools.

Use `Tools/run_aib_tests.ps1` for automated coverage. The current suite has 65 scenarios and a complete successful run should end with:

```text
AIB tests passed: 65 passed, 0 failed
```

The game log must also contain the matching `[AIBTEST] DONE` marker. The launcher waits for it; matching START/PASS counts alone are not completion. Intermediate fixtures receive a short visual hold and cleanup. The final selected fixture emits `DONE` immediately after its verdict and is intentionally retained for inspection until the AIBTest process is closed.

Use `-Scenario <name>` for one scenario, or the inclusive `-StartScenario <name> -EndScenario <name>` range. By default the runner opens a visible `RunLocalhost` AIBTest session and leaves KAG running. Fast verdicts retain their fixture for 15 ticks so the client can show them. Use `-StopAfterRun` only when an explicit stop is wanted. If neither the log nor simulation advances for 25 seconds, the runner reports a distinct stale simulation/log diagnostic rather than a normal completion timeout.

`AIBTestCamera.as` is intended to own the test camera, but its current logs do not represent the displayed view reliably. Human observation is authoritative. Known symptoms include sticking upper-left, recentering to the map middle, jitter between competing positions, losing scene follow, and blocking manual movement. Do not cite `CAMERA_TARGET`/`CAMERA_VIEW` records as proof that camera following works.

Visible `RunLocalhost()` can also stop advancing, so long free-form behavior should receive a manual visual check. The current source has no recorded full 65-scenario pass: keep focused results distinct from full-suite evidence.

AIBTest captures the originally loaded map tile array once, restores every changed terrain tile and owner-tracked temporary no-build sector during cleanup, and validates dimensions/hash, live fixture/bootstrap tags, temporary-sector tracking, plan ids, and director modes before the next setup. Do not replace this with generated flat terrain: the canonical snapshot must preserve the real `aib_suite.png` pathing geometry. Validate cleanup by running terrain-mutating fixtures sequentially in the same visible KAG process and requiring the canonical guard to remain clean. The newest production-planner fixtures cover simultaneous full completion of safe inward plans for both team directions, full production-path fallback completion after a blocked primary on uneven near-edge terrain, exact shortage-pressure scoring, emergency selection under collapsing frontline pressure, damaged-front reactivation without plan replacement, full physical completion of a selected plan by the production Autobuilder executor, rejection of mirrored locally clear sealed bootstrap pockets, full fallback completion after exact no-build, protected-building, or active-barrier rejection, and mirrored blocked-site cooldown/round-reset provisioning. The mirrored and uneven fixtures select and publish without Autobuilders so ordinary reachability remains enforced, then spawn production Autobuilders and require exact task/layer/reservation/archive completion. The uneven case also preserves both obstruction tiles (compatible reuse as an already-matching stone task is legal). The bootstrap fixture occupies every legal 6-24-tile spawn distance on both sides, requires the exact retry cooldown, clears the blockers, proves cooldown still holds, then uses the production round reset to provision exactly one safe assigned worker per team. These claims require focused KAG verdicts; a registry/source scan is not evidence.

Current operator constraint (2026-07-14): the user permits visible KAG runtime testing and keyboard/screenshot control. Close every agent-started KAG process immediately after a completed or failed evidence run and verify it is gone. Leave KAG open only during an explicitly active reload/TCPR iteration, and say so.

### Map-scoped KAG Gym benchmarks

`Scripts/AIBGymBenchmark.as` owns `[AIBGYMR]` schema v4 resource episodes on existing CTF maps. The canonical metric is `resource_collection_180s` (5,400 ticks) with one or four builders; shorter runs are `resource_collection_smoke` and must never be compared as the three-minute score. Keep gross `collected_*`, confirmed `delivered_*`, and accessible `stock_delta_*` separate. Storage construction can consume correctly collected material, so none of those fields substitutes for the others.

Compare only the same map hash/dimensions, team side, builder count, order, and duration with `Tools/compare_aib_gym_results.ps1`. Retain initial terrain/world fingerprints as audit evidence, but do not require byte-identical delayed fingerprints: normal map startup can mutate transient terrain/blobs between trials of the same official map. Never pool different map hashes or optimize the mapcycle. A full cohort defaults to three control and three candidate episodes.

Gym-owned workers use stable per-episode slots and production player-order commands. The harness disables director state, removes only tagged production-bootstrap workers, waits a tick for deferred blob death, and rejects any remaining AI contamination. Every gym/wave episode may manage at most eight AI actors in total. The first valid baseline is `gloryhill_control_1b_002` in `console-26-07-15-05-37-30.txt`: 850 wood collected/delivered, 650 accessible stock after infrastructure cost, zero deaths, and one latched recoverable motion-stall flag.

Four-worker resource spawns must be home-connected, not merely clear and grounded. The harness builds a conservative grounded-cell flood from the exact resource home, forms deterministic per-slot candidates, and backtracks the complete separated set. The retained Gloryhill positions are `140,292;52,284;36,292;20,300`; the earlier shelf spawn near `(119,340)` was sealed and invalid. The accepted mixed four-builder shaft-return cohort delivered 936/1066/826 for controls (mean 942.667) and 1716/1438/1568 for candidates (mean 1574.000), with zero deaths. Candidate failure masks are still 1 in all three runs, so preserve the open slow-return diagnosis rather than claiming failure-free pathing.

`Scripts/AIBInfrastructureBenchmark.as` owns `[AIBGYMI]` schema v1 `flag_gatehouse_physical` episodes. It must use a production-published plan and production Autobuilder execution, then require exact physical task matches, completed plan counters/archive, zero work tiles/reservations, healthy rear/front team doors, and a real friendly builder crossing both doors. Group only by fixture/version/team/side/map/metric/template with `Tools/summarize_aib_infrastructure_results.ps1`; a full cohort defaults to three physical runs. On official Gloryhill, three team-0/left and three team-1/right executions all passed. Mean completion/traversal ticks were 1068.000/58.333 on the left and 1075.667/48.333 on the right. This proves construction and friendly passage, not enemy delay or combat defense.

The actual KAG CTF flag blob name is `ctf_flag`. Never restore a `getBlobsByName("flag")` lookup or spawn a fixture blob named `flag`: it silently moves the strategic anchor to the tent fallback and invalidates flag-distance claims.

The newest scenarios are `strategic_damaged_front_reactivates_without_plan_replacement`, `strategic_autobuilder_physically_completes_selected_plan`, `strategic_bootstrap_rejects_sealed_cave_spawn`, `strategic_no_build_primary_falls_back_and_physically_completes`, and `strategic_occupied_primary_falls_back_and_physically_completes`; they still need focused verdicts. The earlier repair scenario has a complete focused pass in `console-26-07-10-17-32-06.txt`. `console-26-07-14-10-04-11.txt` proves nine settled 1x1 entries do not make `CInventory.isFull()` reliable. The earlier `canPutItem` selector run stopped before validating delivery; a completed 2026-07-15 run proved that preflighting with material still inside the builder inventory can reject an eligible empty crate. The transactional selector then passed both `stone_order_mines_exposed_stone_and_delivers` and `full_crate_creates_grounded_overflow_storage` in visible KAG.

After changing base crate/workshop selection or payment, run `stone_order_mines_exposed_stone_and_delivers` and `full_crate_creates_grounded_overflow_storage` in visible KAG. Neither `isFull()` nor a positive material count answers whether a resource fits, and `canPutItem` is not a valid selector gate while the candidate remains inside another inventory. Remove the exact item, attempt destination `server_PutInInventory`, restore it on failure, and give rejected crates a bounded retry so later player withdrawals are noticed. Stone runners must not withdraw completed crated deliveries as fresh base supply. The focused verdict must prove the delivered material is inside base crates as well as globally conserved.

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
- After changing startup defaults, policy loading, bootstrap initialization/reset, or the moderator command, validate the real lifecycle in visible KAG through TCPR and a moderator CTF session.
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
- Use direct movement for close, visible, simple goals. For ordinary-builder
  navigation, preserve the current custom `BrainPath` route; native
  `SetPathTo`/`SetSuggestedKeys` is its isolated fallback, not the production
  default.
- Always include stuck recovery and debug logs that can be disabled with one constant.
- Avoid KAG UI button helpers for custom overlay controls in this mod; prefer Inventory/EasyUI-style manual input state and simple GUI rendering.
