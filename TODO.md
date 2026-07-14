# TODO

This file is the active backlog. Completed historical notes and old investigation logs have been removed; keep only work that still needs to be done.

## AI Builder

- Runtime-validate the remaining dirt-plug recovery route (registered as `kag_path_builds_supported_ladder_chain`).
  - Production now pays for and places only missing support backwalls, returns to simulation, and creates the ladder only after the engine recognizes support on a later tick.
  - A bounded one-shot probe records the post-ladder low-level node, hypothetical `AIB_GetMineablePathBlock` result, ray obstruction, and pathfinder acceptance.
  - The focused scenario now requires the connected support tick to precede ladder creation, then requires a post-placement path and actual crossing while every dirt-plug tile remains intact. `Tools/test_aib_recovery_ladder_contract.ps1` pins the source ordering, but visible KAG evidence remains required.

- Runtime-validate the production crate-storage lifecycle.
  - Grounded two-sided storage/workshop search, no-build/barrier/building rejection, and bounded same-base existing-workshop selection are implemented. The workshop fixture now keeps an unrelated remote same-team shop alive and requires the production selector to reject it in favor of a local shop.
  - Overflow funding now counts only spendable builder inventory, confirms the builder payment leg before home storage, and refunds it if the home leg unexpectedly fails. `Tools/test_aib_overflow_storage_contract.ps1` pins this ordering and the exact conservation verdict.
  - Run `full_crate_creates_grounded_overflow_storage` and require the corrected lightweight full-crate fixture to create/use distinct grounded secondary storage without material loss.
  - Rerun `blueprint_collects_home_materials` after the storage-selector change and require actual wood/stone withdrawal, both production placements, and exact material conservation.

- Runtime-validate multiplayer AI state used by HUD and overseer UI.
  - Authoritative job/state/active mutations sync immediately, creation force-publishes the trio, and the server brain republishes it on a network-ID-staggered five-second heartbeat. `Tools/test_aib_public_state_sync.ps1` pins those paths without claiming a real late join occurred.
  - Join an active multiplayer match after builders have entered different wood/stone/blueprint states and verify the resource counters converge within five seconds without requiring another job transition.
  - Keep the canonical `"ai builder job"` enum as the resource role while its three values remain unambiguous; add a separate synced role only if future job semantics can no longer represent the HUD categories.

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

- Runtime-validate and finish authoritative live editing and AI-visible blueprint publication.
  - The server owns accepted add/remove/prefab/clear mutations, validates the active command player and overseer permission, rate-limits edits, updates the human/compatibility layers, and emits authoritative action boundaries. Same-value single-tile packets are now no-ops rather than version/telemetry churn.
  - Tile deltas and full display snapshots use targeted rules commands for same-team players and spectators; enemy clients no longer receive another team's blueprint contents and merely discard them locally. `Tools/test_aib_editor_delta_authority.ps1` pins recipient, authority, rate, version, and HUD-defense paths.
  - Blueprint saves use a committed rectangle independent of tree/stone/overseer gestures, reject save-before-selection, and retain inclusive 1x1/asymmetric dimensions through memory, PNG, packet, and authoritative-placement paths. `Tools/test_aib_blueprint_selection_roundtrip.ps1` pins the source contract.
  - Live-test two teams plus a spectator: same-team and spectator clients must receive add/remove/prefab/clear updates, the enemy must not, and the AI-visible compatibility grid must match after every mutation and after AI consumption.
  - Runtime-save an asymmetric selection, restart KAG, reload its PNG, and verify the exact dimensions, orientation, rotation, preview footprint, and authoritative placement.
  - Add a physical fixture for a live ghost blueprint block being accepted and completed by an AI builder.

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

- Keep the 65-scenario registry and expected final result synchronized when blueprint-editor scenarios are added.
- Keep `Tools/run_aib_tests.ps1` as the main regression path, but split long pathing scenarios into a separate slower suite if they keep masking unrelated regressions.
- The focused selection rectangle save/load dimensions contract is implemented; keep runtime disk/process evidence distinct from the in-memory/static proof.
- Runtime-validate the existing authoritative editor-delta contract with two teams and a spectator; static recipient/source checks cannot prove actual network delivery or non-delivery.
- Runtime-run the existing focused contracts for supported recovery, crate overflow/second-crate purchase, and blueprint material retrieval; their source/static coverage is not a substitute for a visible KAG verdict.

## Manual Coverage

- Keep real visual tree-chopping and log-to-wood collection as a manual gameplay check until headless runs can cover a fully live tree pipeline reliably.
- Manually verify the editor UI in multiplayer with at least two clients:
  - same-team blueprint visibility
  - enemy-team blueprint isolation
  - overseer-only edit permissions
  - saving/loading a blueprint created during the same match
