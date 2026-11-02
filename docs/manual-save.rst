manual-save
===========

.. dfhack-tool::
    :summary: Create named save snapshots that persist across autosaves.
    :tags: fort dfhack

Creates a persistent, named save snapshot that will not be overwritten by
future autosaves. When invoked, the game triggers a native autosave and
then duplicates the resulting save folder into a timestamped directory.

This is useful for creating milestone saves before embarking on
mega-projects, protecting against save corruption from mods, or setting
up a rolling manual-save schedule with the `repeat` command.

Usage
-----

::

    manual-save [<name>] [<options>]

If no ``<name>`` is given, the save is named after your fortress and the
current real-world timestamp (e.g.
``Floorroasts-Manual-2026-04-25_09-19-22``).

Examples
--------

``manual-save``
    Create a snapshot named after your fortress and the current time.
``manual-save MyProject``
    Create a snapshot named ``MyProject``.
``manual-save --cleanup 5``
    Create a snapshot, then prune old manual saves so that only the
    5 most recent remain.
``repeat -name rolling-saves -time 1 -timeUnits months -command [ manual-save --cleanup 10 ]``
    Automatically create a rolling manual save every in-game month,
    keeping only the 10 most recent snapshots.

Options
-------

``-c``, ``--cleanup <num>``
    After saving, delete the oldest manual-save snapshots so that only
    ``<num>`` remain. Only folders whose names contain ``-Manual-`` are
    considered; native autosave slots and region folders are never
    touched.
