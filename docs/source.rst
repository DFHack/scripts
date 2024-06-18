source
======

.. dfhack-tool::
    :summary: Create an infinite magma or water source.
    :tags: fort armok map

This tool can create an infinite magma or water source or drain on a tile. For
more complex liquid placement, try `liquids` or `gui/liquids`.

Map tiles registered with this tool as a liquid source will be set to have the
configured amount of liquid every 12 game ticks. A standard liquid source sets
the level to ``7``, and a standard drain sets the level to ``0``, but you can
set the target anywhere in between as well.

Usage
-----

``source add water|magma [0-7]``
    Add a source or drain at the selected tile position. If the target level is
    not specified, it defaults to ``7``. The cursor must be over a flow-passable
    tile (e.g. empty space, floor, staircase, etc.) and not too high in the sky.
``source [list]``
    List all currently registered source tiles.
``source delete``
    Remove the source under the cursor.
``source clear``
    Remove all liquid sources that have been added with ``source``.

Examples
--------

``source add water``
    Create an infinite water source under the cursor.
``source add water 3``
    Create an infinite water source under the cursor, but equalize the water
    depth at 3/7. This is useful when creating a swimming pool for your dwarves.
``source add water 0``
    Create a water drain under the cursor.
``source add magma``
    Create an infinite magma source under the cursor.
