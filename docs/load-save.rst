load-save
=========

.. dfhack-tool::
    :summary: Load a savegame.
    :tags: unavailable

When run on the Dwarf Fortress title screen or "load game" screen, this script
will load the save with the given folder name without requiring interaction.
Note that inactive saves (i.e. saves under the "start game" menu that have gone
through world generation but have not had a fort or adventure game started in
them yet) cannot be loaded by this script.

Usage
-----

::

    load-save <save directory name>

Examples
--------

``load-save region1``
    Load the savegame in the ``save/region1`` directory.

Autoloading a game on DF start
------------------------------

It is useful to run this script from the commandline when starting Dwarf
Fortress. For example, on Linux/MacOS you could start Dwarf Fortress with::

    ./dfhack +load-save region1

Similarly, on Windows, you could run::

    "Dwarf Fortress.exe" +load-save region1
