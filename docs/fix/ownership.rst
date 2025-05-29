fix/ownership
=============

.. dfhack-tool::
    :summary: Fixes ownership links.
    :tags: fort bugfix items units

Due to a bug, a unit can believe they own an item when they actually do not.
Additionally, a room can remember that it is owned by a unit, but the unit can
forget that they own the room.

Invalid item ownership links result in units getting stuck in a "Store owned
item" job. Missing room ownership links result in rooms becoming unused by the
nominal owner and unclaimable by any other unit. In particular, nobles and
administrators will not recognize that their room requirements are met.

When enabled in `gui/control-panel`, `fix/ownership` will run once a day to
validate and fix ownership links for items and rooms.

Usage
-----

::

    fix/ownership

Links
-----

Among other issues, this tool fixes :bug:`6578`.
