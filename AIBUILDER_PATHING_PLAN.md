# AI Builder Pathing Plan

## Problem Case

On `8x_Gloryhill`, the leftmost tree sits above the team tent. The useful route is not a direct jump toward the tree: the builder has to move farther left, climb the hill, then approach the tree from the higher ground.

The fragile behavior was in `AIBuilderBrain.as`: when the destination is close and there is no solid tile in the direct ray, the AI switches to direct key movement (`justgo`). For uphill terrain this can be wrong because a clear ray does not mean a runner can jump straight to the target.

## Immediate Fix

`AIB_CanUseDirectShortcut` now suppresses direct movement for close uphill destinations when the builder is not already climbing, on a wall, on a ladder, or in water. Those targets stay on `CBrain.SetPathTo`/`SetSuggestedKeys` so KAG path nodes can choose an initial move that may go away from the tree.

This keeps direct movement for:

- same-level and downhill movement
- normal obstruction recovery where a direct shortcut is still physically plausible
- active climbing states where direct up/down key pressure is useful

## Regression Coverage

The AIBTest suite now includes `8x_gloryhill_leftmost_tree_uses_hill_route`.

Because the current headless KAG test process stops advancing around game tick 51, this is a short regression rather than a full live climb. It builds a Gloryhill-style hill in the large AIBTest arena, selects the elevated left tree, starts harvest, and asserts that the AI targets the tree without enabling the direct shortcut.

The real `8x_Gloryhill.png` map is also copied into `Maps/AIBTest/aib_reference_8x_Gloryhill.png` so future map-specific tests can use the exact terrain once the headless runner can advance long enough for full traversal checks. The unique basename prevents KAG from substituting the test copy when normal CTF asks for the official map.

## Next Improvements

- Add route-intent logging when the pathfinder suggests a first waypoint opposite the final target direction.
- Track progress along path nodes, not just distance to final destination.
- If the builder is stuck below an uphill target, force a repath before allowing another direct movement attempt.
- Add a longer visible/manual scenario on the copied `aib_reference_8x_Gloryhill.png` map: spawn tent, spawn/select the leftmost tree, start harvest, and verify the builder reaches the upper hill approach.
