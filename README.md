# CONTROLS :
- To enter blueprint editing mode, press Left control or Right control
- To hide blueprints, simply press 'H'
- When in editing mode, you can left click to add a block, or right click to remove a block
- When playing as a builder, use the usual menu to choose which block to place
- When playing as archer or knight, use the key 'R' and 'U' to naviguate between the different blocks
- You can select a zone by settings selection points using the 'I' and 'P' key. Use 'I' to set the first point and 'P' to set the second point. Then press 'O' to save your selection.
- You can save a blueprint that is inside the two selection points using the 'O' key
- You can load your saved blueprint with using the 'L' key
- You can cycle through rendering window size by pressing 'J', try it if your performance aren't great
- You can cycle through rendering relative to your camera or your cursor by pressing 'K'
##### Thanks to all kag's modder who answered my questions and big thanks to Numan and Monkey_Feats.
##### Thanks to Epsilon for the (not yet implemented) inventory code

# INSTALLATION
add the CustomRenderer.as to your rules.cfg scripts list. Example, to have it added on CTF gamemode, go to King Arthur's Gold\Base\Rules\CTF\gamemode.cfg and edit the file to add CustomRenderer.as in the script section.

## TODO:
- add the possibilities to have multiple blueprint
- integrate save mechanics with a GUI elements
- integrate load mechanics with a GUI elements
- Optimisation : Make the inventory GUI part of a mesh and maybe use only 1 render function.
- Optimisation : Create multiple vertex array as chunk and render only the chunk near the camera.
- Make the data being sent only to the right team
    - make the 48 64 196 205 block index value go to 1 2 4 5 
- remove block once it's placed
- f1 tips
- dynamics notes
- cleanup code, remove most of the global variable
- add multiple page block selection
- support rotation
- veracity : block on flag shouldn't be allowed 
- make blueprint from game blob and block instead of your array
- implement the cursor select when middle click
    - 2 mode
        - if mode 1, you can copy paste selected blueprint into png + place blueprint
        - if mode 2, you can edit and fill things
- support multiple uv size/blob size other than 8x8
    - remove offset from placeentities, put an offset array or do something to make it possible to have different size entities
- add more to the REEE.PNG
    - add the logics entities
- make custom menu less of a pain, have a gui for it
- optimise even more blueprint data sharing
    - getLocalPlayer().getNetworkID() == netID this may not work as you think it does : even when netid != localnetid, code is being executed.
- Make the selector mouseselect[] behave more intuitively
