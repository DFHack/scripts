
load-save
=========

When run on the title screen or "load game" screen, loads the save with the
given folder name without requiring interaction. Note that inactive saves (i.e.
saves under the "start game" menu) are currently not supported.

Example::

    load-save region1

This can also be run when starting DFHack from the command line. For example,
on Linux/macOS::

    ./dfhack +load-save region1
