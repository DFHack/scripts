empty-bin
=========

.. dfhack-tool::
    :summary: Empty the contents of containers onto the floor.
    :tags: fort productivity items

This tool can quickly empty the contents of the selected container (bin,
barrel, pot, wineskin, quiver, etc.) onto the floor, allowing you to access
individual items that might otherwise be hard to get to.

Note that if there are liquids in the container, they will empty onto the floor
and become unusable.

If you instead select a stockpile or building, running `empty-bin` will empty
*all* containers in the stockpile or building. Likewise, if you select a tile
that has many items and the UI is showing the list of items, all containers on
the tile will be dumped.

Usage
-----

::

    empty-bin
