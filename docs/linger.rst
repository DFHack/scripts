linger
======

.. dfhack-tool::
    :summary: Take control of your adventurer's killer.
    :tags: unavailable

Run this script after being presented with the "You are deceased." message to
abandon your dead adventurer and take control of your adventurer's killer.

The killer is identified by examining the historical event generated when the
adventurer died. If this is unsuccessful, the killer is assumed to be the last
unit to have attacked the adventurer prior to their death.

This will fail if the unit in question is no longer present on the local map.

Usage
-----

::

    linger
