
source
======
Create an infinite magma or water source or drain on a tile.
For more complex commands, try the `liquids` plugin.

This script registers a map tile as a liquid source, and every 12 game ticks
that tile receives or remove 1 new unit of flow based on the configuration.

Place the game cursor where you want to create the source (must be a
flow-passable tile, and not too high in the sky) and call::

    source add [magma|water] [0-7]

The number argument is the target liquid level (0 = drain, 7 = source).

To add more than 1 unit every time, call the command again on the same spot.

To delete one source, place the cursor over its tile and use ``source delete``.
To remove all existing sources, call ``source clear``.

The ``list`` argument shows all existing sources.

Examples::

    source add water     - water source
    source add magma 7   - magma source
    source add water 0   - water drain

