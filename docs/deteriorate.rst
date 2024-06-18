deteriorate
===========

.. dfhack-tool::
    :summary: Cause corpses, clothes, and/or food to rot away over time.
    :tags: unavailable

When enabled, this script will cause the specified item types to slowly rot
away. By default, items disappear after a few months, but you can choose to slow
this down or even make things rot away instantly!

Now all those slightly worn wool shoes that dwarves scatter all over the place
or the toes, teeth, fingers, and limbs from the last undead siege will
deteriorate at a greatly increased rate, and eventually just crumble into
nothing. As warm and fuzzy as a dining room full of used socks makes your
dwarves feel, your FPS does not like it!

Usage
-----

``deteriorate start --types <types> [--freq <frequency>] [--quiet] [--keep-usable]``
    Starts deteriorating the specified item types while you play.
``deteriorate stop --types <types>``
    Stops deteriorating the specified item types.
``deteriorate status``
    Shows the item types that are currently being monitored and their
    deterioration frequencies.
``deteriorate now --types <types> [--quiet] [--keep-usable]``
    Causes all items (of the specified item types) to rot away within a few
    ticks.

You can have different types of items rotting away at different rates by running
``deteriorate start`` multiple times with different options.

Examples
--------

Start deteriorating corpses and body parts, keeping usable parts such as hair, wool::

    deteriorate start --types corpses --keep-usable

Start deteriorating corpses and food and do it at twice the default rate::

    deteriorate start --types corpses,food --freq 0.5,days

Deteriorate corpses quickly but clothes slowly::

    deteriorate start -tcorpses -f0.1
    deteriorate start -tclothes -f3,months

Options
-------

``-f``, ``--freq``, ``--frequency <number>[,<timeunits>]``
    How often to increment the wear counters. ``<timeunits>`` can be one of
    ``days``, ``months``, or ``years`` and defaults to ``days`` if not
    specified. The default frequency of 1 day will result in items disappearing
    after several months. The number does not need to be a whole number. E.g.
    ``--freq=0.5,days`` is perfectly valid.
``-k``, ``--keep-usable``
    Keep usable body parts such as hair, wool, hooves, bones, and skulls.
``-q``, ``--quiet``
    Silence non-error output.
``-t``, ``--types <types>``
    The comma-separated list of item types to affect. This option is required
    for ``start``, ``stop``, and ``now`` commands.

Types
-----

:clothes:  All clothing pieces that have an armor rating of 0 and are lying on
           the ground.
:corpses:  All resident corpses and body parts.
:food:     All food and plants, regardless of whether they are in barrels or
           stockpiles. Seeds are left untouched.
