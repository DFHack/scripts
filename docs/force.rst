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
    force Wildlife [all]

The civ id is only used for ``Diplomat`` and ``Caravan`` events, and defaults
to the player civilization if not specified.

The default civ IDs that you are likely to be interested in are:

- ``MOUNTAIN`` (dwarves)
- ``PLAINS`` (humans)
- ``FOREST`` (elves)

But to see IDs for all civilizations in your current game, run this command::

    :lua ids={} for _,en in ipairs(world.entities.all) do ids[en.entity_raw.code] = true end for id in pairs(ids) do print(id) end

Examples
--------

``force Caravan``
    Spawn a caravan from your parent civilization.
``force Diplomat FOREST``
    Spawn an elven diplomat.
``force Megabeast``
    Call in a megabeast to attack your fort. The megabeast will enter the map
    on the surface.
``force Wildlife``
    Allow additional wildlife to enter the map. Only affects areas that you can
    see, so if you haven't opened the caverns, cavern wildlife won't be
    affected.
``force Wildlife all``
    Allow additional wildlife to enter the map, even in areas you haven't
    explored yet.

Event types
-----------

The supported event types are:

- ``Caravan``
- ``Migrants``
- ``Diplomat``
- ``Megabeast``
- ``Wildlife``

Most events happen on the next tick. The ``Wildlife`` event may take up to 100
ticks to take effect.
