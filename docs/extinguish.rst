extinguish
==========

.. dfhack-tool::
    :summary: Put out fires.
    :tags: fort armok buildings items map units

With this tool, you can put out fires affecting map tiles, plants, units, items,
and buildings.

To select a target, place the cursor over it before running the script.

If your FPS is unplayably low because of the generated smoke, see `clear-smoke`.

Usage
-----

``extinguish``
    Put out the fire under the cursor.
``extinguish --all``
    Put out all fires on the map.
``extinguish --location [ <x> <y> <z> ]``
    Put out the fire at the specified map coordinates. You can use the
    `position` tool to find out what the coordinates under the cursor are.

Examples
--------

``extinguish --location [ 33 41 128 ]``
    Put out the fire burning on the surface at position x=33, y=41, z=128.
