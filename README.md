# Starbound WEdit
WEdit is a tech mod that allows you to edit the world around you on a larger scale through various functions and features not present in the game.

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Using a different tech](#using-a-different-tech)
- [Features](#features)
- [Planned](#planned)
- [Potential Issues](#potential-issues)
- [Contributing](#contributing)
- [Licenses](#licenses)

## Installation
* [Download](https://github.com/Silverfeelin/Starbound-WEdit/releases) the release for the current version of Starbound.
* Place the `WEdit.modpak` file in your mods folder (eg. `D:\Steam\steamapps\common\Starbound\mods\`). Overwrite the existing file if necessary.
* Activate the `dash` tech on your character.
 * In singleplayer, use `/enabletech dash` and `/spawnitem techconsole` with your cursor pointed near your character. Place the tech console down and activate the tech from the tech console.

## Usage
*It is recommended to have `/debug` on at all times while using WEdit. Although WEdit will function fine without enabling the debug mode, vital information can only be seen with this mode enabled.*

To use any of the features WEdit offers, you must first obtain all WEdit Tools. You can obtain them by running the below command in singleplayer, and then using the item given to you. The command will spawn the item at the position of your cursor.
Note that this will add 13 items to your tools/etc. tab in your inventory. If there's not enough space in your inventory, the items will be dropped on the ground at the position of your character.
```
/spawnitem silverore 1 '{"itemTags":[], "radioMessagesOnPickup":[], "learnBlueprintsOnPickup":[], "twoHanded":true, "shortdescription":"WE_ItemBox", "category":"^orange;WEdit: Item Box", "description":"^yellow;^yellow;Primary Fire: Spawn Tools.^reset;", "inventoryIcon":"/objects/floran/chestfloran1/chestfloran1icon.png"}'
```
By holding one of these tools, you can access the corresponding feature. The usage of each feature is described in the below section [Features](#features). Generally, the left and right mouse buttons (primary fire and alt fire) are used to activate the items.

You can toggle the built-in noclip mode by pressing your second tech action key (`G` by default).

## Using a different tech
* Unpack `WEdit.modpak`.
* Remove `/tech/dash/dash.lua` from the unpacked mod.
* Copy a different tech script from unpacked assets for the current version of the game.
* Place the copied tech script in the unpacked WEdit folder. Make sure the file name and directories match up with those of the game assets (eg. `\assets\tech\jump\multijump.lua` to `\unpackedWEdit\tech\jump\multijump.lua`).
* Open the new tech script in a text editor of your choice.
* Start a new line following the line `function init()`, and place the code below on this new line.
```
require "/scripts/weditController.lua"
```
* Save the file.
* Repack the unpacked mod. Make sure you first delete the original packed mod.
* (Optional) Enable the new tech using `/enabletech <techname>` in singleplayer. Activate the tech through a tech console, obtainable by using the command `/spawnitem techconsole`.

## Features
**TODO**

## Planned
**TODO**

## Potential Issues
**TODO**

## Contributing
**TODO**

## Licenses
Most of the icons used for the tools are courtesy of [Yusuke Kamiyamane](http://p.yusukekamiyamane.com/about/), and can be found in his [Fugue Icons](http://p.yusukekamiyamane.com/) pack. Some have been modified slightly to fit better into the game.
The icon pack mentioned above falls under the [Creative Commons 3.0 license](http://creativecommons.org/licenses/by/3.0/).
