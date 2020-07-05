# CONTROLS :
- To enter blueprint editing mode, press Left control or Right control
- To hide blueprints, simply press 'H'
- When in editing mode, you can left click to add a block, or right click to remove a block
- When playing as a builder, use the usual menu to choose which block to place
- When playing as archer or knight, use the key 'R' and 'U' to naviguate between the different blocks
- You can select a zone by settings selection points using the 'I' and 'P' key. Use 'I' to set the first point and 'P' to set the second point. Then press 'O' to save your selection. You can also use the mouse-wheel click button.
- You can save a blueprint that is inside the two selection points using the 'O' key
- You can load your saved blueprints by using the 'L' key or using the 'X' key
- You can cycle through rendering window size by pressing 'J', try it if your performance aren't great
- You can cycle through rendering relative to your camera or your cursor by pressing 'K'
- As a moderator, you can enable or disable live blueprint editing using the !bp_edit_toggle command
##### Thanks to all kag's modder who answered my questions and big thanks to Numan and Monkey_Feats.
##### Thanks to Epsilon for the inventory code

# INSTALLATION FOR HOST
add the CustomRenderer.as to your rules.cfg scripts list. Example, to have it added on CTF gamemode, go to King Arthur's Gold\Base\Rules\CTF\gamemode.cfg and edit the file to add CustomRenderer.as in the script section.

## TODO:
### Live editor todo:
* make if possible to rotate 3d object larger than 8x8
* make blob stop attacking when in edit mode
* make spectator camera stop moving with mouse when editing
* make editing mode toggleable instead of having to hold
* fix rotation bug : get the direction of held object directly.

### CTF improvement todo:
- f1 tips
- remove block once it's placed
    - also add a command to disable that
- Make the data being sent only to the right team
- make a voting system on blueprints
- make chat command to clear all blueprints
- configurable delay between the placement of blueprint to prevent spam

### Overall improvement todo:
- Optimisation : Make the inventory GUI part of a mesh and maybe use only 1 render function.
- Optimisation : Create multiple vertex array as chunk and render only the chunk near the camera.
- make a way organize all your blueprint in menu/improve menu
    - a config image that tell you which blueprint number is in which menu
- dynamics notes/implement the ping mod
- cleanup code, remove the global variable
- veracity : block on flag shouldn't be allowed 
- optimise even more blueprint data sharing
    - getLocalPlayer().getNetworkID() == netID this may not work as you think it does : even when netid != localnetid, code is being executed.
- Wait for engine fix for your save system to completely work -> remind the engine devs about it

### Blueprint promotion todo:
- overseer idea
    - an addon to existing gamemode that add a 30 to 60 seconds delay before the beginning of a match to plan blueprints building
    - an gamemode in which there is one overseer and the other ppl have to build what the overseer want otherwise they lose
    - kind of an addon/gamemode where there's one overseer per team that tell the team what to do

## Code structure
