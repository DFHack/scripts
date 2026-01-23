trackstop
=========

.. dfhack-tool::
    :summary: Overlay to allow changing track stop and related building settings after construction.
    :tags: fort buildings interface

This script provides 3 overlays that are managed by the `overlay` framework.
The script does nothing when executed.

The ``trackstop`` overlay allows the player to change the friction and dump
direction of a selected track stop after it has been constructed.

The ``rollers`` overlay allows the player to change the roller direction and
speed of a selected roller after it has been constructed.

The ``pressureplate`` overlay allows the player to change the trigger settings
of a selected pressure plate after it has been constructed. Manual value entry
of ranges for minecart and creature triggers is provided, allowing greater
precision than the game interface normally permits. Incrementing or decrementing
values always restricts them to the usual intervals.
