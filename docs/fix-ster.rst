fix-ster
========

.. dfhack-tool::
    :summary: Toggle infertility for units.
    :tags: unavailable

Now you can restore fertility to infertile creatures or inflict infertility on
creatures that you do not want to breed.

Usage
-----

::

    fix-ster fert|ster [all|animals|only:<race>]

Specify ``fert`` or ``ster`` to indicate whether you want to make the target
fertile or sterile, respectively.

If no additional options are given, the command affects only the currently
selected unit.

Options
-------

``all``
    Apply to all units on the map.
``animals``
    Apply to all non-dwarf creatures.
``only:<race>``
    Apply to creatures of the specified race.

Examples
--------

``fix-ster fert``
    Make the selected unit fertile.
``fix-ster fert all``
    Ensure all units across the entire fort are fertile.
``fix-ster ster only:DWARF``
    Halt dwarven population growth.
