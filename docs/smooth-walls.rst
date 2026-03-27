smooth-walls
============

.. dfhack-tool::
    :summary: Designate all natural wall tiles on the current z-level for smoothing.
    :tags: fort design map

This script scans the currently viewed z-level and designates only wall tiles
for smoothing. It skips floors, ramps, stairs, already smoothed tiles, and any
tiles with existing dig/smoothing/track designations. Use ``undo`` to clear
existing smoothing designations on wall tiles.

Usage
-----

``smooth-walls``
    Designate eligible wall tiles for smoothing on the current z-level.
``smooth-walls smooth``
    Same as the default behavior.
``smooth-walls undo``
    Clear smoothing designations on wall tiles for the current z-level and
    remove any existing smooth wall jobs on those tiles.
