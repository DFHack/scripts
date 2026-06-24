machine-toggle
==============

.. dfhack-tool::
    :summary: Overlay to modify pressure plates and gear assemblies after construction.
    :tags: fort armok buildings interface

This script provides 2 overlays that are managed by the `overlay` framework.
The script does nothing when executed.
Track stops and rollers are handled by `trackstop`.

The ``pressureplate`` overlay allows the player to change the trigger settings
of a selected pressure plate after it has been constructed. Manual value entry
of ranges for minecart and creature triggers is provided, allowing greater
precision than the game interface normally permits. Incrementing or decrementing
values always restricts them to the usual intervals.

The ``gearassembly`` overlay allows the player to toggle the state of a selected
gear assembly without linking it to a lever first. This is useful for dwarfputing
and other applications where it may be desirable to default to the disengaged
state until triggered.
