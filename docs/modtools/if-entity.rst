modtools/if-entity
==================

.. dfhack-tool::
    :summary: Run DFHack commands based on the the civ id of the current fort.
    :tags: dev

Run a command if the current fort entity matches a given ID.

This script can only be called when a fort is loaded. To run it immediately
when a matching fort is loaded, call it from a registered
``dfhack.onStateChange`` `state change handler <lua-core-context>`. See the
`modding-guide` for an example of how to set up a state change handler.

Usage
-----

::

    modtools/if-entity --id <entity id> --cmd [ <command> ]

Options
-------

``--id <entity id>``
    Specify the entity ID to match.
``--cmd [ <command> ]``
    Specify the command to be run when the given id is matched.

Example
-------

``modtools/if-entity --id FOREST --cmd [ lua "print('Dirty hippies.')" ]``
    Print a message if you load an elf fort, but not a dwarf, human, etc. fort.
