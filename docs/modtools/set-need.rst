modtools/set-need
=================

.. dfhack-tool::
    :summary: Change the needs of a unit.
    :tags: unavailable

Sets and edits unit needs.

Valid commands:

:add:
    Add a new need to the unit.
    Requires a -need argument, and target.
    -focus and -level can be used to set starting values, otherwise they'll fall back to defaults.
:remove:
    Remove an existing need from the unit.
    Requires a need target, and target.
:edit:
    Change an existing need in some way.
    Requires a need target, at least one effect, and a target.
:revert:
    Revert a unit's needs list back to its original selection and need strengths.
    Focus levels are preserved if the unit has a need before and after.
    Requires a target.

Valid need targets:

:need <ID>:
    ID of the need to target. For example 0 or DrinkAlcohol.
    If the need is PrayOrMedidate, a -deity argument is also required.
:deity <HISTFIG ID>:
    Required when using PrayOrMedidate needs. This value should be the historical figure ID of the deity in question.
:all:
    All of the target's needs will be affected.

Valid effects:

:focus <NUMBER>:
    Set the focus level of the targeted need. 400 is the value used when a need has just been satisfied.
:level <NUMBER>:
    Set the need level of the targeted need. Default game values are:
    1 (Slight need), 2 (Moderate need), 5 (Strong need), 10 (Intense need)

Valid targets:

:citizens:
    All (sane) citizens of your fort will be affected. Will do nothing in adventure mode.
:unit <UNIT ID>:
    The given unit will be affected.

If no target is given, the provided unit can't be found, or no unit id is given with the unit
argument, the script will try and default to targeting the currently selected unit.

Other arguments:

:help:
    Shows this help page.
:list:
    Prints a list of all needs + their IDs.
:listunit:
    Prints a list of all a unit's needs, their strengths, and their current focus.

Usage example - Satisfy all citizen's needs::

    modtools/set-need -edit -all -focus 400 -citizens
