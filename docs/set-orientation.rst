
set-orientation
===============
Edit a unit's orientation.
Interest levels are 0 for Uninterested, 1 for Romance, 2 for Marry.

:unit <UNIT ID>:
    The given unit will be affected.
    If not found/provided, the script will try defaulting to the currently selected unit.
:male <INTEREST>:
    Set the interest level towards male sexes
:female <INTEREST>:
    Set the interest level towards female sexes
:opposite <INTEREST>:
    Set the interest level towards the opposite sex to the unit
:same <INTEREST>:
    Set the interest level towards the same sex as the unit
:random:
    Randomise the unit's interest towards both sexes, respecting their ORIENTATION token odds.

Other arguments:

:help:
    Shows this help page.
:view:
    Print the unit's orientation values in the console.
