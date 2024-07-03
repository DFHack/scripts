bodyswap
========

.. dfhack-tool::
    :summary: Take direct control of any visible unit.
    :tags: adventure armok units

This script allows the player to take direct control of any unit present in
adventure mode whilst giving up control of their current player character.

Usage
-----

::

    bodyswap [unit <id>]
    bodyswap linger

If no specific unit id is specified, the target unit is the one selected in the
user interface, such as by opening the unit's status screen or viewing its
description. Otherwise, a valid list of units to bodyswap into will be shown.
If bodyswapping into an entity that has no historical figure, a new historical figure is created for it.
If said unit has no name, a new name is randomly generated for it, based on the unit's race.
If no valid language is found for that race, it will use the DIVINE language.

If you run bodyswap linger, the killer is identified by examining the historical event generated
when the adventurer died. If this is unsuccessful, the killer is assumed to be the last unit to have
attacked the adventurer prior to their death.

This will fail if the unit in question is no longer present on the local map or is also dead.

Examples
--------

``bodyswap``
    Takes control of the selected unit, or brings up a list of swappable units if no unit is selected.
``bodyswap unit 42``
    Takes control of unit with id 42.
``bodyswap linger``
    Takes control of your killer when you die
