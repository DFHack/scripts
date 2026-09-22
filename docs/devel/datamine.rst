devel/datamine
==============

.. dfhack-tool::
    :summary: Watch live values and diff structure snapshots.
    :tags: dev

Aids script development and reverse engineering by observing live game state.
Lua expressions are evaluated with the normal script environment, so ``df``,
``dfhack``, and friends are all available.

Usage
-----

::

    devel/datamine watch [-n name] [-i frames] <lua expression>
    devel/datamine unwatch <name>|all
    devel/datamine watches
    devel/datamine snap <name> <lua expression>
    devel/datamine diff <name>
    devel/datamine find <lua expression> <substring>

``watch`` polls the expression every ``frames`` frames (default 1) and prints a
line to the DFHack console whenever its value changes. Watches are cleared when
the world is unloaded; use ``unwatch`` to stop earlier.

``snap`` records the current value of every field reachable from the
expression's result (bounded depth and vector length), and ``diff`` prints the
paths whose values changed since the snapshot -- e.g. "perform action X, then
see which fields changed". ``find`` prints the paths of all fields whose name
or value contains the given substring.

Examples
--------

::

    devel/datamine watch -n cursor df.global.cursor.x
    devel/datamine snap site df.global.world.world_data.active_site[0]
    devel/datamine diff site
    devel/datamine find df.global.world.units.all[0] stress
