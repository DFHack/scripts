force
=====

.. dfhack-tool::
    :summary: Trigger in-game events.
    :tags: fort armok gameplay

This tool triggers events like megabeasts, caravans, and migrants. Note that you
can only trigger one caravan per civ at the same time, and that DF may choose to
ignore events that are triggered too frequently.

Usage
-----

::

    force <event> [<civ id>]

The civ id is only used for ``Diplomat`` and ``Caravan`` events, and defaults
to the player civilization if not specified.

The default civ IDs that you are likely to be interested in are:

- ``MOUNTAIN`` (dwarves)
- ``PLAINS`` (humans)
- ``FOREST`` (elves)

But to see IDs for all civilizations in your current game, run this command::

    devel/query --table df.global.world.entities.all --search code --maxdepth 2

Event types
-----------

The recognized event types are:

- ``Caravan``
- ``Migrants``
- ``Diplomat``
- ``Megabeast``
- ``WildlifeCurious``
- ``WildlifeMischievous``
- ``WildlifeFlier``
- ``NightCreature``
