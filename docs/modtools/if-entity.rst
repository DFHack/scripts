modtools/if-entity
==================

Run a command if the current entity matches a given ID.

To use this script effectively it needs to be called from "raw/onload.init".
Calling this from the main dfhack.init file will do nothing, as no world has
been loaded yet.

Usage:

- ``id``:
    Specify the entity ID to match
- ``cmd [ commandStrs ]``:
    Specify the command to be run if the current entity matches the entity
    given via -id

All arguments are required.

Example:

- Print a message if you load an elf fort, but not a dwarf, human, etc. fort::

    if-entity -id "FOREST" -cmd [ lua "print('Dirty hippies.')" ]
