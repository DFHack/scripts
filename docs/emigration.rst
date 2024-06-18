emigration
==========

.. dfhack-tool::
    :summary: Allow dwarves to emigrate from the fortress when stressed.
    :tags: fort gameplay units

If a dwarf is spiraling downward and is unable to cope in your fort, this tool
will give them the choice to leave the fortress (and the map).

Dwarves will choose to leave in proportion to how badly stressed they are.
Dwarves who can leave in friendly company (e.g. a dwarven merchant caravan) will
choose to do so, but extremely stressed dwarves can choose to leave alone, or
even in the company of a visiting elven bard!

The check is made monthly. A happy dwarf (i.e. with negative stress) will never
emigrate.

Usage
-----

::

    enable emigration
