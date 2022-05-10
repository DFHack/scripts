-- Cause selected item types to quickly rot away
--[====[

deteriorate
===========

Causes the selected item types to rot away. By default, items disappear after a
few months, but you can choose to slow this down or even make things rot away
instantly!

Now all those slightly worn wool shoes that dwarves scatter all over the place
or the toes, teeth, fingers, and limbs from the last undead siege will
deteriorate at a greatly increased rate, and eventually just crumble into
nothing. As warm and fuzzy as a dining room full of used socks makes your
dwarves feel, your FPS does not like it.

To always have this script running in your forts, add a line like this to your
``onMapLoad.init`` file (use your preferred options, of course)::

    deteriorate start --types=corpses

Usage::

    deteriorate <command> [<options>]

**<command>** is one of:

:start:   Starts deteriorating items while you play.
:stop:    Stops running.
:status:  Shows the item types that are currently being monitored and their
          deterioration frequencies.
:here:    Causes the items (of the specified item types) under the cursor to
          instantly rot away.

You can control which item types are being monitored and their rotting rates by
running the command multiple times with different options.

**<options>** can be zero or more of:

``-f``, ``--freq``, ``--frequency <number>[,<timeunits>]``
    How often to increment the wear counters. ``<timeunits>`` can be one of
    ``ticks``, ``days``, ``months``, or ``years`` and defaults to ``days`` if
    not specified. The default frequency of 1 day will result in items
    disappearing after several months.
``-t``, ``--types <types>``
    The item types to affect. See below for options.

**<types>** is any of:

:clothes:  All clothing types that have an armor rating of 0.
:corpses:  All non-dwarf corpses and body parts. This includes potentially
           useful remains such as hair, wool, hooves, bones, and skulls.
:food:     All food and plants, regardles of whether they are in barrels or
           stockpiles. Seeds are left untouched.

You can specify multiple types by separating them with commas, e.g.
``deteriorate clothes,food``.

Examples:

* Deteriorate corpses at twice the default rate::

    deteriorate start --types=corpses --freq=0.5,days

* Deteriorate corpses quickly but food slowly::

    deteriorate start -tcorpses -f0.1
    deteriorate start -tfood -f3,months
]====]
