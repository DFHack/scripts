
uniform-unstick
===============

Prompt units to reevaluate their uniform, by removing/dropping potentially conflicting worn items.

Unlike a "replace clothing" designation, it won't remove additional clothing
if it's coexisting with a uniform item already on that body part.
It also won't remove clothing (e.g. shoes, trousers) if the unit has yet to claim an
armor item for that bodypart. (e.g. if you're still manufacturing them.)

By default it simply prints info about the currently selected unit,
to actually drop items, you need to provide it the -drop option.

The default algorithm assumes that there's only one armor item assigned per body part,
which means that it may miss cases where one piece of armor is blocked but the other
is present. The -multi option can possibly get around this, but at the cost of ignoring
left/right distinctions when dropping items.

In some cases, an assigned armor item can't be put on because someone else is wearing/holding it.
The -free option will cause the assigned item to be removed from the container/dwarven inventory
and placed onto the ground, ready for pickup.

In no cases should the command cause a uniform item that is being properly worn to be removed/dropped.

Targets:

:(no target): Force the selected dwarf to put on their uniform.
:-all:        Force the uniform on all military dwarves.

Options:

:(none):      Simply show identified issues (dry-run).
:-drop:       Cause offending worn items to be placed on ground under unit.
:-free:       Remove to-equip items from containers or other's inventories, and place on ground.
:-multi:      Be more agressive in removing items, best for when uniforms have muliple items per body part.
