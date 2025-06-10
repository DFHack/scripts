z-adv-path-up-down
==================

Auto-path one Z-level up or down from your current Adventurer position by simulating one-step
movement commands.

Synopsis
--------

::

  z-adv-path-up-down

Usage
-----

Run from the DFHack Lua console while in **Adventurer** mode:

::

  [DFHack]# lua z-adv-path-up-down.lua

1. You’ll be prompted with **Up**, **Down**, or **Cancel**.  
2. Select **Up** to auto-path one level above your current Z; **Down** to auto-path one level below.  
3. A “please do not press any keys” popup displays while the script works.  
4. On success, a confirmation popup shows how many levels you moved; on failure, an error popup appears.

Requirements
------------
- DFHack 0.47.04 or later  
- Modules:
  - :mod:`gui.script`
  - :mod:`dfhack.gui`
- Must be in **Adventurer** mode (i.e. `world.units.adv_unit` exists)  
- A valid viewscreen to accept simulated input

Example
-------

.. code-block:: console

  [DFHack]# lua z-adv-path-up-down.lua
  “Current z = 5. Which direction? (Cancel to exit)”
  (Select “Up”)
  “Auto-path in progress… Please do not press any keys.”
  “Auto-path up 1 levels.”

See Also
--------
- :mod:`gui.script` — synchronous scripting API  
- :mod:`dfhack.gui` — popup announcement utilities  
