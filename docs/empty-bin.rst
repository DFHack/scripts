empty-bin
=========

.. dfhack-tool::
    :summary: Empty the contents of containers onto the floor.
    :tags: fort productivity items

This tool can quickly empty the contents of the selected container (bin,
barrel, pot, wineskin, quiver, etc.) onto the floor, allowing you to access
individual items that might otherwise be hard to get to.

If you instead select a stockpile or building, running `empty-bin` will empty
*all* containers in the stockpile or building. Likewise, if you select a tile
that has many items and the UI is showing the list of items, all containers on
the tile will be dumped.

Usage
-----

::

    empty-bin [<options>]

Examples
--------

``empty-bin``
   Empty the contents of selected containers or all containers in the selected stockpile or building, except containers with liquids or powders, onto the floor.

``empty-bin --force``
   Empty the contents of selected containers or all containers in the selected stockpile or building, including containers with liquids or powders, onto the floor.

``empty-bin --recursive --force``
   Empty the contents of selected containers or all containers in the selected stockpile or building, including containers with liquids/powders and containers contents that are containers, such as a bags of seeds or filled waterskins, onto the floor.


Options
-------

``-r``, ``--recursive``
   Recursively empty containers.

``-f``, ``--force``
   Move contained liquid and powders (DRINK, LIQUID_MISC and POWDER_MISC) to the floor, making them unusable.
