fix/exploding-trees
===================

.. dfhack-tool::
    :summary: Removes "phantom" trees before they can explode.
    :tags: fort bugfix

By default, this script runs once a month by the Control Panel's Bug Fixes tab.

This script mitigates a longstanding Dwarf Fortress bug.

Once a year, trees check if they should grow.  The exact day and time of this
growth is different for every tree.

Occasionally, when a tree is cut down or otherwise removed from the game, the
game engine doesn't remove the tree's data from the list of plants.  The exact
details of this are not currently understood.

For some reason, these "phantom" trees will sometimes collapse during this
growth.  This can stun, injure, or kill units which happen to be near this
collapse.

This script finds those trees and sets their dead flag, preventing them from
growing and collapsing.

Usage
-----

::

    fix/exploding-trees
