starvingdead
============

.. dfhack-tool::
    :summary: Prevent infinite accumulation of roaming undead.
    :tags: fort fps gameplay units

With this tool running, all undead that have been on the map for one month
gradually decay, losing strength, speed, and toughness. After six months,
they collapse upon themselves, never to be reanimated.

Strength lost is proportional to the time until death, all units will have
roughly 10% of each of their attributes' values when close to being removed.

In any game, this can be a welcome gameplay feature, but it is especially
useful in preventing undead cascades in the caverns in reanimating biomes,
where constant combat can lead to hundreds of undead roaming the caverns and
destroying your FPS.

Usage
-----

::

    enable starvingdead
    starvingdead [<options>]

Examples
--------

``enable starvingdead``
    Start starving the dead with default settings.
``starvingdead --decay-rate 28``
    Undead will lose strength roughly once a month.
``starvingdead --decay-rate 1 --death-threshold 1``
    Undead will lose strength each day and die after they have spent a month
    on the map.

Options
-------

``--decay-rate <days>``
    Specify how often, in days, undead should lose strength.
``--death-threshold <months>``
    How many months should undead lose strength for before being removed.
