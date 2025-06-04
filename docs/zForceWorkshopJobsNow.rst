zForceWorkshopJobsNow
=====================

A DFHack plugin that force-starts or unforces all jobs in workshops and furnaces across the fortress.

Overview
--------

This plugin provides both an in-game overlay and a command-line interface to control whether queued jobs in workshops and furnaces should be executed immediately (`do_now = true`) or not (`do_now = false`). It is useful for players who want more control over job execution prioritization.

Features
--------

- Force all current jobs in all workshops and furnaces to start immediately.
- Toggle job forcing directly from the workshop task viewscreen using a small overlay panel.
- Simple hotkeys: ``o`` (ON) and ``f`` (OFF).
- Compatible with most standard and custom workshops and furnaces.

Usage
-----

**In-Game Overlay**

Navigate to any workshop or furnace job screen. A small UI will appear with:

::

  Prioritize All:
  ON     OFF

- Press ``ctrl+o`` to prioritize all jobs on all stations.
- Press ``ctrl+i`` to unprioritize all jobs on all stations.

**Console Command**

::

  zForceWorkshopJobsNow [ON|OFF]

- Running with no argument is equivalent to ``ON``.
- ``ON``: Set ``do_now = true`` for all applicable jobs.
- ``OFF``: Set ``do_now = false`` for all applicable jobs.
