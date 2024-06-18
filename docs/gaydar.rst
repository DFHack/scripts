gaydar
======

.. dfhack-tool::
    :summary: Shows the sexual orientation of units.
    :tags: fort inspection animals units

``gaydar`` is useful for social engineering or checking the viability of
livestock breeding programs.

Usage
-----

::

    gaydar [<target>] [<filter>]

Examples
--------

``gaydar``
    Show sexual orientation of the selected unit.
``gaydar --citizens --asexual``
    Identify asexual citizens and residents.

Target options
--------------

``--all``
    Selects every creature on the map.
``--citizens``
    Selects fort citizens and residents.
``--named``
    Selects all named units on the map.

Filter options
--------------

``--notStraight``
    Only creatures who are not strictly straight.
``--gayOnly``
    Only creatures who are strictly gay.
``--biOnly``
    Only creatures who can get into romances with both sexes.
``--straightOnly``
    Only creatures who are strictly straight.
``--asexualOnly``
    Only creatures who are strictly asexual.
