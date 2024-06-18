modtools/force
==============

.. dfhack-tool::
    :summary: Trigger game events.
    :tags: dev

This tool triggers events like megabeasts, caravans, and migrants.

Usage
-----

::

    -eventType event
        specify the type of the event to trigger
        examples:
            Megabeast
            Migrants
            Caravan
            Diplomat
            WildlifeCurious
            WildlifeMischievous
            WildlifeFlier
            NightCreature
    -civ entity
        specify the civ of the event, if applicable
        examples:
            player
            MOUNTAIN
            EVIL
            28
