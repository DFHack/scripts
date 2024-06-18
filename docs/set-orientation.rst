set-orientation
===============

.. dfhack-tool::
    :summary: Alter a unit's romantic inclinations.
    :tags: fort armok units

This tool lets you tinker with the interest levels your dwarves have towards
dwarves of the same/different sex.

Usage
-----

``set-orientation [--unit <id>] --view``
    See the unit's current orientation values.
``set-orientation [--unit <id>] <interest options>``
    Set the orientation values for the unit.

If a unit id is not specified or is not found, the default is to target the
currently selected unit.

Examples
--------

``set-orientation --male 0 --female 0``
    Make a dwarf romantically inaccessible
``set-orientation --random``
    Re-randomize the orientation values for this dwarf.

Interest options
----------------

Interest levels are 0 for Uninterested, 1 for Romance, and 2 for Marry.

``--male <INTEREST>``
    Set the interest level towards males.
``--female <INTEREST>``
    Set the interest level towards females.
``--opposite <INTEREST>``
    Set the interest level towards the opposite sex to the unit.
``--same <INTEREST>``
    Set the interest level towards the same sex as the unit.
``--random``
    Randomise the unit's interest towards both sexes, respecting their
    ORIENTATION token odds.
