gui/keybinds
============

.. dfhack-tool::
   :summary: Manage your dfhack keybinds visually.
   :tags: dfhack

This tool allows you to create, edit, save, and delete custom keybinds that
run dfhack commands.

Usage
-----

::

    gui/keybinds

Focus Strings
-------------

Keybinds may have a focus filter applied, enabling or disabling the keybind
based on the current open menu or gamemode. More information on the percise
format can be found in `keybinding`.

Saved Keybinds
--------------

If saved, all currently active keybinds are stored in a dfhack init script at
``dfhack-config/init/dfhack.auto.keybinds.init``. The save does not remove any
keybinds set in other init scripts, nor created in-game.
