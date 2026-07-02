# TODO

This file is the active backlog. Completed historical notes and old investigation logs have been removed; keep only work that still needs to be done.

## AI Builder

- Fix the remaining `kag_path_mines_dirt_plug` timeout.
  - The bot reaches the obstacle/recovery area and can now place a supported recovery backwall chain plus ladder, but it still keeps replanning instead of finishing the route.
  - Add logging around the low-level path node after ladder placement, the next blocked tile chosen by `AIB_GetMineablePathBlock`, and whether the ladder/backwall chain is actually considered walkable by the pathfinder.
  - Add a focused scenario that asserts recovery backwalls are connected to support before any ladder is placed.

- Make crate storage more production-quality.
  - Avoid hard-coded storage/shop offsets when the team home is near map edges, terrain, or enemy-controlled space.
  - Prefer existing same-team builder shops near the base, but do not pick a shop far away from the home storage area.
  - Add a test for full crate overflow: fill one crate, verify the AI buys or uses another crate and stores remaining resources there.
  - Add a test for retrieving blueprint materials from crates after resources have been stored.

- Tighten multiplayer sync for AI state used by HUD and overseer UI.
  - Confirm `"ai builder job"` and `"ai builder state"` stay synced for late joiners.
  - Consider syncing a small explicit `"ai builder resource role"` if future jobs reuse the same state ranges.

## Blueprint Making And Editor UI

The current blueprint/editor code works, but it is too coupled and fragile. Most editor behavior lives in `Scripts/CustomRenderer.as`, mixed with rendering, networking, saving/loading, live editing, overseer selection, tree/stone selection, and AI-visible blueprint publication. This should be split before adding many more editor features.

- Split `CustomRenderer.as` into clearer modules.
  - `BlueprintEditorInput.as`: hotkeys, mouse capture, current tool/mode, selection dragging.
  - `BlueprintData.as`: map-sized blueprint grid, placed prefab grid, rotation/flip helpers, bounds-safe reads/writes.
  - `BlueprintNetwork.as`: commands for add/remove/send/snapshot and team-scoped delivery.
  - `BlueprintSaveLoad.as`: PNG/runtime blueprint save/load and metadata.
  - `BlueprintRender.as`: mesh generation, dirty chunks, selection overlay, ghost preview.
  - Keep `CustomRenderer.as` as a thin coordinator that registers hooks and calls these modules.

- Replace raw global editor state with an explicit editor mode/state object.
  - Current globals such as `toggleBlueprint`, `displayPrefabSelectionMenu`, `displayLoadedBlueprint`, `mouseSelect`, `customMenuTurn`, `flipBlueprint`, and selection-mode bools can conflict.
  - Define modes such as `off`, `paint`, `erase`, `select_area`, `place_prefab_preview`, `tree_select`, and `stone_select`.
  - Make mode transitions explicit so right-click/cancel, menu open/close, and preview placement cannot leave stale state behind.

- Redesign the editor UI into actual tool controls instead of hidden hotkeys.
  - Add a compact top/side toolbar with icons for paint, erase, select, save, load, rotate, flip, visibility, and AI resource selection tools.
  - Show the current block/tool, rotation, selection size, and whether live editing is enabled.
  - Add hover/pressed/disabled states for controls and avoid relying on debug `print()` output.
  - Keep keyboard shortcuts, but make them secondary to visible controls.

- Replace `customMenuTurn` with a real block palette.
  - Define a block/tool catalog with id, display name, icon, tile/blob type, size, rotation rules, and material cost.
  - Include all relevant build targets: stone block, stone backwall, wood block, wood backwall, doors, trap block, ladder, platform, spikes, builder shop, storage/shop items that should be blueprintable.
  - Use the same catalog for rendering, saving, loading, AI material planning, and UI palette entries.

- Fix selection and save/load correctness.
  - Normalize rectangle bounds in one helper and use it everywhere; current selection logic repeats min/max and has width/height `+1` inconsistencies.
  - Save exactly the selected inclusive tile rectangle, including the final row/column, without fallbacking to `Vec2f(1,1)` and `Vec2f(5,5)` on invalid selection.
  - Add explicit validation feedback when selection is empty or outside map bounds.
  - Store blueprint dimensions consistently; avoid off-by-one differences between `CFileImage(width, height)` and `RuntimeBlueprint(width + 1, height + 1)`.
  - Stop relying on fragile cache path substring logic such as `imagePath.substr(23)`.

- Improve blueprint persistence format.
  - PNG color packing is useful for compatibility, but add a metadata sidecar or embedded convention for name, author, dimensions, version, allowed teams, and catalog version.
  - Store full `u16` block ids and rotation in a documented format so future ids are not constrained by color-channel hacks.
  - Add migration handling for older saved PNG-only blueprints.

- Make live editing and AI-visible blueprint data authoritative.
  - Decide whether the server or an overseer client owns blueprint edits.
  - Publish blueprint deltas from the authority, not every local client.
  - Team-scope blueprint data so one team's plans are not sent to the other team unless intended.
  - Keep the AI-visible rules snapshot in sync after add/remove/send/save/load and after an AI places a tile.
  - Add tests for live ghost blueprint blocks being built by AI builders.

- Improve network efficiency.
  - Replace full-map `getAllBlocks` / `giveAllBlocks` transfers with chunked snapshots or sparse deltas.
  - Version the blueprint grid and ignore stale commands.
  - Add rate limits for live editing commands to prevent edit spam.
  - Add a clear-all command with team scope and permission checks.

- Improve rendering performance and correctness.
  - Chunk the blueprint mesh by map region and rebuild only dirty chunks.
  - Keep separate meshes for blueprint tiles, selection overlays, and AI target markers.
  - Avoid rebuilding the full mesh every frame when `blueprintMeshDirty` is false.
  - Add a visible warning or clipped rendering behavior when the mesh quad limit is reached.

- Improve prefab/blueprint browser usability.
  - Show actual blueprint thumbnails instead of `Bp0`, `Bp1`, etc.
  - Add names, search/filter, delete/rename, and folders/categories.
  - Keep menu layout stable as blueprints are added.
  - Add confirmation before overwriting or deleting saved blueprints.

- Make editor input safer during gameplay.
  - Prevent normal attack/build actions while the editor consumes mouse input.
  - Prevent spectator camera mouse movement from fighting editor selection.
  - Make edit mode toggleable, with a clear on-screen active state, instead of requiring held control.
  - Ensure right-click cancel does not also perform gameplay actions.

- Improve blueprint planning rules.
  - The editor should preview invalid placements before AI builders try to build them.
  - Highlight unsupported blocks, blocked flag areas, no-build zones, red-barrier violations, and enemy-unsafe areas.
  - Add an auto-support option that can insert backwalls/ladders/platforms needed to make a blueprint buildable.
  - Add a validation summary: required wood/stone, missing support count, blocked tiles, and estimated AI build path risk.

## Automated Coverage

- Update the AIB suite target count and expected final result after crate-storage and blueprint-editor tests are added.
- Keep `Tools/run_aib_tests.ps1` as the main regression path, but split long pathing scenarios into a separate slower suite if they keep masking unrelated regressions.
- Add focused tests for:
  - supported recovery backwall chain before ladder placement
  - crate overflow and second-crate purchase
  - blueprint material retrieval from crates
  - live editor delta publication to AI-visible blueprint data
  - selection rectangle save/load dimensions

## Manual Coverage

- Keep real visual tree-chopping and log-to-wood collection as a manual gameplay check until headless runs can cover a fully live tree pipeline reliably.
- Manually verify the editor UI in multiplayer with at least two clients:
  - same-team blueprint visibility
  - enemy-team blueprint isolation
  - overseer-only edit permissions
  - saving/loading a blueprint created during the same match
