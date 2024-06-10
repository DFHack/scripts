exterminate
===========

.. dfhack-tool::
    :summary: Kill things.
    :tags: fort armok units

Kills any unit, or all undead, or all units of a given race. You can target any
unit on a revealed tile of the map, including hidden ambushers, but caged or
chained creatures cannot be killed with this tool.

Usage
-----

::

    exterminate
    exterminate this [<options>]
    exterminate undead [<options>]
    exterminate <race>[:<caste>] [<options>]

Race and caste names are case insensitive.

Examples
--------

``exterminate this``
    Kill the selected unit.
``exterminate``
    List the targets on your map.
``exterminate BIRD_RAVEN:MALE``
    Kill the ravens flying around the map (but only the male ones).
``exterminate goblin --method magma --only-visible``
    Kill all visible, hostile goblins on the map by boiling them in magma.

Options
-------

``-m``, ``--method <method>``
    Specifies the "method" of killing units. See below for details.
``-o``, ``--only-visible``
    Specifies the tool should only kill units visible to the player.
    on the map.
``-f``, ``--include-friendly``
    Specifies the tool should also kill units friendly to the player.

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
    more useful for pets than armed enemies.

Technical details
-----------------

This tool kills by setting a unit's ``blood_count`` to 0, which means
immediate death at the next game tick. For creatures where this is not enough,
such as vampires, it also sets ``animal.vanish_countdown``, allowing the unit
to vanish in a puff of smoke if the blood loss doesn't kill them.

If the method of choice involves liquids, the tile is filled with a liquid
level of 7 every tick. If the target unit moves, the liquid moves along with
it, leaving the vacated tiles clean.
