# CONTROLS :

## Blueprint toolbar
- The blueprint toolbar is visible for players who can use blueprint controls.
- Paint: click the Paint tool, then left-click tiles to add the currently selected blueprint block.
- Erase: click the Erase tool, then left-click blueprint tiles to remove them.
- Select: click the Select tool, then drag a rectangle to define the save/selection area.
- Save: saves the current selected tile rectangle as a blueprint.
- Load: opens or closes the blueprint browser.
- Rotate: rotates the active block or placement preview.
- Flip: flips the loaded blueprint preview before placement.
- Hide/Show: toggles blueprint rendering.

## Legacy blueprint shortcuts
- Hold Left Control or Right Control to use the older live-edit cursor.
- While holding Control, left-click adds a block and right-click removes a block.
- Press H to hide or show blueprints.
- Press I and P to set the two selection corners, then press O to save that rectangle.
- Press the mouse-wheel button and drag to set the selection rectangle.
- Press L or hold X to open the blueprint browser.
- When playing as a builder, use the usual build menu to choose the block to place.
- When playing as archer or knight, press R and U to cycle through blueprint blocks.
- Press J to cycle the render window size.
- Press K to cycle rendering relative to camera or cursor.

## Overseer view
- Press E at a same-team AI Builder Workshop and click **Become overseer**. The workshop only seats one overseer at a time.
- Your character remains seated and locked into the workshop while using overseer view. Press E again to leave the chair and exit the view.
- In overseer view, the camera is detached from the player and is not clamped to the map bounds.
- Move the overseer camera with W, A, S, and D.
- Hold Shift while moving to pan faster.
- Drag with left-click to select same-team AI builders. A short click near one AI builder selects that builder.
- Right-click or Cancel clears the current AI builder selection.
- After selecting AI builders, use the order buttons:
    - Harvest wood
    - Mine stone
    - Build blueprint
- Orders are validated on the server. A player can only order same-team AI builders unless they are a spectator/admin team player.

## Moderator commands
- As a moderator, enable or disable live blueprint editing using the "!bp_edit_toggle" command.
- As a moderator, enable or disable overseer restrictions using the "!bp_overseer_toggle" command.
    - When overseer restrictions are enabled and at least one overseer is assigned, only selected overseers can place/edit blueprints and use overseer orders.
    - Use "!bp_overseer_set Username" to assign an overseer.
    - Use "!bp_overseer_none" to remove all assigned overseers.

## Strategic AI blueprint director

- The server-side director observes each team's home, frontline, terrain, combat mix, recent pressure, stored resources, and AI builders.
- It evaluates procedural gatehouse, tower, emergency barrier, archer perch, and access-route candidates. Invalid candidates are rejected before publication.
- Human blueprints and AI blueprints use separate layers. Human tiles always win merge conflicts and autonomous replanning never edits the human layer.
- AI plans retain an immutable desired layer and task history after builders consume the live work grid.
- Construction is phased: foundation/backwalls, access pieces, then shell. Tasks are reserved per builder so two builders do not select the same tile.
- Doors and platforms are supported build targets and material collection follows the actual remaining plan cost.

Team members can select a director mode with `!aib_strategy off`, `!aib_strategy suggest`, or `!aib_strategy auto`. CTF defaults to `suggest`; the deterministic AIB test mode defaults to `off`.

Suggestion mode renders the proposed plan and its score reasons without assigning builders. Auto mode publishes the work layer and assigns wood, stone, and construction jobs according to current shortages.

For paired in-engine pressure trials on a fresh map, moderators can run `!aib_wave <seed> control [knight|archer|bomb|mixed]` and `!aib_wave <seed> plan [knight|archer|bomb|mixed]`. Use the same seed and scenario on separately restarted maps. Strategy event logging records breach timing, crossings, deaths, flag approaches, completion and damage timing, structure lifetime, builder travel/idle time, reservation conflicts, replans, route preservation, and estimated absorbed cost.

After collecting both variants, compare the result logs with `Tools/compare_aib_wave_results.ps1 -LogPath <log paths>`. It strictly pairs control/plan records by seed and scenario and covers knight, archer, bomb, and mixed scenarios by default. Its regression check is `Tools/test_compare_aib_wave_results.ps1`.

The lightweight seeded evaluator is available at `Tools/aib_strategy_abstract_sim.ps1`; its regression check is `Tools/test_aib_strategy_abstract_sim.ps1`.
##### Thanks to all kag's modder who answered my questions and big thanks to Numan and Monkey_Feats.
##### Thanks to Epsilon for the inventory code

# INSTALLATION FOR HOST
Enable this mod and add `CustomRenderer.as` to the applicable gamemode script list through this mod's override under `Rules`. Do not edit `King Arthur's Gold/Base`; files in this mod override matching base-game files.

## TODO:
### Live editor todo:
* make selection actually select the right area
* make it possible to rotate 2d sprite larger than 8x8
* make blob stop attacking when in edit mode
* make spectator camera stop moving with mouse when editing
* make editing mode toggleable instead of having to hold
* fix rotation bug : get the direction of held object directly.
* add saw
* add trampoline
* add catapult
* add ballista
* add custom shop
* ability to place all the relevant block at the blueprint location

### CTF improvement todo:
- f1 tips
- remove block once it's placed
    - also add a command to disable that
- Make the data being sent only to the right team
- make a voting system on blueprints
- make chat command to clear all blueprints
- configurable delay between the placement of blueprint to prevent spam

### Overall improvement todo:
- cleanup code, remove the global variable, make the project oop based
    - make a new inventory system and put all the blocks in there.
    - make a make object, make it so that you can easily iterate through it
- Optimisation : Make the inventory GUI part of a mesh and maybe use only 1 render function.
- Optimisation : Create multiple vertex array as chunk and render only the chunk near the camera.
- make a way organize all your blueprint in menu/improve menu
    - a config image that tell you which blueprint number is in which menu
- dynamics notes/implement the ping mod
- veracity : block on flag shouldn't be allowed 
- optimise even more blueprint data sharing
    - getLocalPlayer().getNetworkID() == netID this may not work as you think it does : even when netid != localnetid, code is being executed.
- Wait for engine fix for your save system to completely work -> remind the engine devs about it

### Blueprint promotion todo:
- Overseer idea
    - an addon to existing gamemode that add a 30 to 60 seconds delay before the beginning of a match to plan blueprints building
    - an gamemode in which there is one overseer and the other ppl have to build what the overseer want otherwise they lose
    - kind of an addon/gamemode where there's one overseer per team that tell the team what to do

## Code structure
