adv-path-up-down
==================

Auto-path one Z-level up or down from your current Adventurer position by simulating one-step
movement commands.

Synopsis
--------

::

  adv-path-up-down

Usage
-----

Run from the DFHack Lua console while in **Adventurer** mode:

::

  [DFHack]# lua adv-path-up-down.lua

1. You’ll be prompted with **Up**, **Down**, or **Cancel**.
2. Select **Up** to auto-path to the highest level above your current Z; **Down** to auto-path to the lowest level.
3. A “please do not press any keys” popup displays while the script works.
4. On success, a confirmation popup shows how many levels you moved; on failure, an error popup appears.
