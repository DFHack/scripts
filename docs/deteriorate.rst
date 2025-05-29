deteriorate
===========

.. dfhack-tool::
    :summary: Cause corpses, clothes, and/or food to rot away over time.
    :tags: fort fps gameplay items

When enabled, this script will cause the specified item types to slowly rot
away. As they deteriorate, they will acquire the normal ``x``, ``X``, and
``XX`` markings. By default, items disappear after a few months, but you can
choose to slow this down or even make things rot away instantly!

Now all those slightly worn wool shoes that dwarves scatter all over the place
or the toes, teeth, fingers, and limbs from the last undead siege will
deteriorate at a greatly increased rate, and eventually just crumble into
nothing. As warm and fuzzy as a dining room full of used socks makes your
dwarves feel, your FPS does not like it!

By default (if you run ``enable deteriorate`` without changing any settings),
only non-entombed corpses and non-usable body parts will be affected.

You can set other common options for new forts on the Gameplay / Autostart tab
of the DFHack control panel.

Usage
-----

::

    enable deteriorate
    deteriorate [status]
    deteriorate (enable|disable) <categories>
    deteriorate frequency <days> <categories>
    deteriorate now <categories>

Where ``<categories>`` is a comma-separated list of item types to affect. The
following categories are available:

:clothes:         All non-armor clothing pieces that are lying on the ground
                  that already have some damage.
:food:            All food and plants. Milk is included, but seeds are left
                  untouched.
:corpses:         All vermin remains and non-entombed corpses. This includes
                  former members of your fort, so if this category is enabled,
                  dwarves that have fallen down your well will rot away with
                  time.
:usable-parts:    Non-entombed body parts that can be used for manufacturing,
                  crafting, or suturing (e.g. hair, wool, skulls, horns, etc.).
:unusable-parts:  Non-entombed body parts that can't be used for manufacturing
                  or crafting.
:parts:           Shorthand for the combination of the above two categories.
:all:             Shorthand for all of the above categories.

When setting a frequency, the number indicates the number of days between
adjustments of the deterioration counter. The default frequency of 1 day will
result in items disappearing after several months. The number does not need to
be a whole number. E.g. ``deteriorate frequency 0.5 all`` is perfectly valid.

Examples
--------

``enable deteriorate``
    Start deteriorating items with current settings.
``deteriorate status``
    Show the current settings.
``deteriorate enable corpses,parts``
    Deteriorate corpses and body parts. This includes potentially useful parts
    such as hair or wool, so use them quickly or lose them!
``deteriorate frequency 0.5 all``
    Deteriorate items of the enabled categories at twice the default rate.
``deteriorate frequency 14 clothes``
    Deteriorate clothes very slowly.
``deteriorate now corpses,unusable-parts``
    Deteriorate corpses and unusable body parts immediately. This is useful for
    cleaning up after a siege or ambush (maybe after you have buried your own
    casualties).
``deteriorate now food``
    Deteriorate all food items immediately. Instant famine!
