devel/spawn-unit-helper
=======================

.. dfhack-tool::
    :summary: Prepares the game for spawning creatures by switching to arena.
    :tags: dev

This script initializes game state to allow you to switch to arena mode, spawn
creatures, and then switch back to fortress mode.

Usage
-----

1. Enter the :kbd:`k` menu and change mode using
    ``rb_eval df.gametype = :DWARF_ARENA``
2. Spawn creatures with the normal arena mode UI (:kbd:`c` in-game)
3. Revert to fortress mode using
    ``rb_eval df.gametype = #{df.gametype.inspect}``
4. To convert spawned creatures to livestock, select each one with the :kbd:`v`
    menu, and enter ``rb_eval df.unit_find.civ_id = df.ui.civ_id``
