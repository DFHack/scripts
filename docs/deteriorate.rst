
deteriorate
===========

Causes the selected item types to rot away. By default, items disappear after a
few months, but you can choose to slow this down or even make things rot away
instantly!

Now all those slightly worn wool shoes that dwarves scatter all over the place
or the toes, teeth, fingers, and limbs from the last undead siege will
deteriorate at a greatly increased rate, and eventually just crumble into
nothing. As warm and fuzzy as a dining room full of used socks makes your
dwarves feel, your FPS does not like it!

To always have deteriorate running in your forts, add a line like this to your
``onMapLoad.init`` file (use your preferred options, of course)::

    deteriorate start --types=corpses

Usage::

    deteriorate <command> [<options>]

**<command>** is one of:

:start:   Starts deteriorating items while you play.
:stop:    Stops running.
:status:  Shows the item types that are currently being monitored and their
          deterioration frequencies.
:now:     Causes all items (of the specified item types) to rot away within a
          few ticks.

You can control which item types are being monitored and their rotting rates by
running the command multiple times with different options.

**<options>** are:

``-f``, ``--freq``, ``--frequency <number>[,<timeunits>]``
    How often to increment the wear counters. ``<timeunits>`` can be one of
    ``days``, ``months``, or ``years`` and defaults to ``days`` if not
    specified. The default frequency of 1 day will result in items disappearing
    after several months. The number does not need to be a whole number. E.g.
    ``--freq=0.5,days`` is perfectly valid.
``-q``, ``--quiet``
    Silence non-error output.
``-t``, ``--types <types>``
    The item types to affect. This option is required for ``start``, ``stop``,
    and ``now`` commands. See below for valid types.

**<types>** is any of:

:clothes:  All clothing types that have an armor rating of 0, are on the ground,
           and are already starting to show signs of wear.
:corpses:  All non-dwarf corpses and body parts. This includes potentially
           useful remains such as hair, wool, hooves, bones, and skulls. Use
           them before you lose them!
:food:     All food and plants, regardles of whether they are in barrels or
           stockpiles. Seeds are left untouched.

You can specify multiple types by separating them with commas, e.g.
``deteriorate start --types=clothes,food``.

Examples:

* Deteriorate corpses at twice the default rate::

    deteriorate start --types=corpses --freq=0.5,days

* Deteriorate corpses quickly but food slowly::

    deteriorate start -tcorpses -f0.1
    deteriorate start -tfood -f3,months
