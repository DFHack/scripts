Door Toggle
===========

``door-toggle`` is a DFHack Lua tool that bulk locks or unlocks doors and
hatches within a rectangular area. It opens a small GUI where you choose a
mode and then select two corners on the map to apply the action to all targets
in that rectangle.

Usage
-----

- ``door-toggle``
  Opens the GUI and waits for the user to pick two corners.
- ``door-toggle lock``
  Opens the GUI with the mode set to lock.
- ``door-toggle open``
  Opens the GUI with the mode set to unlock.

Behavior
--------

- The first click sets the starting corner.
- Moving the mouse shows a live preview of the rectangle to be processed.
- The second click applies the action to any doors or hatches within the
  rectangle on the current z-level.
- Right-click clears the first corner if already set, or closes the tool if
  no corner is active.

Notes
-----

- Locking is implemented by setting the building's ``door_flags.forbidden``
  to ``true``. Unlocking clears that flag.
- The tool keeps selection mode active by default so you can perform multiple
  selections without reopening the UI.
