# Spyro: A hero's Tail - Object Viewer Lua Script for BizHawk

This is a Lua script for CasualPokePlayer's Dolphin branch of BizHawk, you can get it here: https://tasvideos.org/Forum/Topics/23347.
<br>This was made for the GameCube NTSC version of Spyro: A Hero's Tail.

Special thanks to FranklyGD (https://github.com/FranklyGD) for helping me with the screenspace code.

### Setup

To run the script, open BizHawk's Lua console and open 'SpyroAHT_objlist'. Make sure 'SpyroAHT_objlist_geoDef.lua' and 'SpyroAHT_objlist_itemDef.lua' are in the same folder.

This script will push messages to the screen with BizHawk's messages system. I recommend setting the message location to one of the right corners in BizHawk's settings so it doesn't cover up the other text.

### Usage

Note: Controls can be edited in the main script itself, they're listed at the top.

This script will print a list of objects on the left side of the screen, along with various information about them.<br>
The object types that are listed will depend on what mode you have selected. Currently the only fleshed out mode is Items, with the Triggers mode having some limited functionality.

There is also the option to render points to the screen that match the in-game screenspace, to better see where the objects lie within the world. This can be toggled with the Render tickbox, or the R key.

You can print the current item list to the Lua console using the E key.

You can teleport items with the dedicated buttons in the settings box. You can choose to warp items within a certain range directly to the player, or type in a specific class of item to teleport. Keep in mind some items' positions are updated every frame. You can tick 'Constant' to have the specified class teleported to the player every frame.<br>
The range of teleporting to the player can be changed in the 'Items (Close to Player)' mode using the arrow keys.<br>
You can click on an item in the list to quickly copy its class name to the textbox.<br>
Ticking 'Only Specific' will only render the on-screen points that correspond with the specified item class.

The player item is marked blue, and camera items are marked yellow.

The mode can be changed using the drop-down menu.

### Modes

#### Items (Full List):
Displays all currently loaded items. Since this list can be fairly long, you're able to scroll through it using the mouse wheel.

#### Items (Close to Player):
Displays all items within a certain range of the player. This range can be changed using the arrow keys.

#### Items (Only On-Screen):
Renders no items in the list on the left, only the on-screen points. Mostly for performance reasons.

#### Triggers:
Shows a list and positions of triggers, and the geofile hash (a reference to an .edb file, mostly used by loadmap triggers), if it exists.<br>
You have to update the trigger list manually using the button in the settings box.<br>
Beware that this part is still very experimental!

### Limitations
This script is very demanding to run, especially in areas with lots of objects on-screen. You can toggle the 'Update Items' tickbox to speed things up a bit if you don't need the positions being updated in real-time.<br>
Camera objects store their rotation values in a weird way, so only the Yaw angle shown is correct.<br>
The trigger list doesn't always update for some reason.
