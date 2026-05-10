# GuiftsDynamicBlueprint_vDev Agent Notes

This is a King Arthur's Gold mod. Files inside this mod directory override matching files in the base game. Do not edit `King Arthur's Gold/Base` directly; add or change files under this mod's `Base`, `Rules`, `Scripts`, `Sprites`, or other mod folders.

Some functions are legacy and KAG/3D documentation is sparse. When in doubt, inspect working mods installed under `King Arthur's Gold/Mods`, especially:

- `Hunter4D`
- `Easy3D`
- `Easy3DExampleMod`
- `EasyUI`

When launching KAG for testing or gameplay debugging, start it in a visible window and leave it running. Do not use `-WindowStyle Hidden` or short auto-kill launches unless the user explicitly asks for a compile-only check.

## Current AI Builder Files

- `Base/Entities/Characters/AIBuilder/AIBuilder.cfg` wires the AI builder blob and scripts.
- `Base/Entities/Characters/AIBuilder/AIBuilder.as` handles the player-facing "Harvest wood" button. AI builders spawn idle; this button sets `"ai builder state"` to `find_tree`.
- `Base/Entities/Characters/AIBuilder/AIBuilderBrain.as` is the server-only behavior state machine.
- `Base/Entities/Industry/CTFShops/AIBuilderShop/AIBuilderShop.as` deploys AI builders and sets their team to the caller's team.
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

Use `Tools/run_aib_tests.ps1` for automated coverage. The current suite has 13 scenarios and should end with:

```text
AIB tests passed: 13 passed, 0 failed
```

The live headless KAG server currently stops advancing around game tick 51, so long real tree-chopping scenarios are not reliable as automated tests. The suite covers tree selection, resource generation as simulated pipeline events, and real return/drop-at-tent behavior; keep full visual tree chopping as a manual check.

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
