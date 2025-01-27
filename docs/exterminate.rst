exterminate
===========

.. dfhack-tool::
    :summary: Kill things.
    :tags: fort armok units

Kills any individual unit, or all undead, or all units of a given race. Caged
and chained creatures are ignored.

Usage
-----

::

    exterminate [list]
    exterminate this [<options>]
    exterminate undead [<options>]
    exterminate all[:<caste>] [<options>]
    exterminate <race>[:<caste>] [<options>]

Race and caste names are case insensitive.

Examples
--------

``exterminate``
    List the targets on your map.
``exterminate this``
    Kill the selected unit.
``exterminate BIRD_RAVEN:MALE``
    Kill the ravens flying around the map (but only the male ones).
``exterminate goblin --method magma --only-visible``
    Kill all visible, hostile goblins on the map by boiling them in magma.
``exterminate all``
    Kill all non-friendly creatures.
``exterminate all:MALE``
    Kill all non-friendly male creatures.

Options
-------

``-m``, ``--method <method>``
    Specifies the "method" of killing units. See below for details.
``-o``, ``--only-visible``
    Specifies the tool should only kill units visible to the player
    on the map.
``-f``, ``--include-friendly``
    Specifies the tool should also kill units friendly to the player.
``-l``, ``--limit <num>``
    Set the maximum number of units to exterminate.

Methods
-------

`exterminate` can kill units using any of the following methods:

:instant: Kill by blood loss, and if this is ineffective, then kill by
    vaporization (default).
:vaporize: Make the unit disappear in a puff of smoke. Note that units killed
    this way will not leave a corpse behind, but any items they were carrying
    will still drop.
:disintegrate: Vaporize the unit and destroy any items they were carrying.
:drown: Drown the unit in water.
:magma: Boil the unit in magma (not recommended for magma-safe creatures).
:butcher: Will mark the units for butchering instead of killing them. This is
    useful for pets and not useful for armed enemies.
:knockout: Will put units into an unconscious state for 30k ticks (about a
    month in fort mode).
:traumatize: Traumatizes units, forcing them to stare off into space (catatonic
    state).

Technical details
-----------------

For the ``instant`` method, this tool kills by setting a unit's ``blood_count``
to 0, which means immediate death at the next game tick. For creatures where
this is not enough, such as vampires, it also sets ``animal.vanish_countdown``,
allowing the unit to vanish in a puff of smoke if the blood loss doesn't kill
them.

If the method of choice involves liquids, the tile is filled with a liquid
level of 7 every tick. If the target unit moves, the liquid moves along with
it, leaving the vacated tiles clean (though possibly scorched).
