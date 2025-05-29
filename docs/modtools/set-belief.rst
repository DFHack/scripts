modtools/set-belief
===================

.. dfhack-tool::
    :summary: Change the beliefs/values of a unit.
    :tags: unavailable

Changes the beliefs (values) of units.
Requires a belief, modifier, and a target.

Valid beliefs:

:all:
    Apply the edit to all the target's beliefs
:belief <ID>:
    ID of the belief to edit. For example, 0 or LAW.

Valid modifiers:

:set <-50-50>:
    Set belief to given strength.
:tier <1-7>:
    Set belief to within the bounds of a strength tier:

    ===== ========
    Value Strength
    ===== ========
    1     Lowest
    2     Very Low
    3     Low
    4     Neutral
    5     High
    6     Very High
    7     Highest
    ===== ========

:modify <amount>:
    Modify current belief strength by given amount.
    Negative values need a ``\`` before the negative symbol e.g. ``\-1``
:step <amount>:
    Modify current belief tier up/down by given amount.
    Negative values need a ``\`` before the negative symbol e.g. ``\-1``
:random:
    Use the default probabilities to set the belief to a new random value.
:default:
    Belief will be set to cultural default.

Valid targets:

:citizens:
    All (sane) citizens of your fort will be affected. Will do nothing in adventure mode.
:unit <UNIT ID>:
    The given unit will be affected.

If no target is given, the provided unit can't be found, or no unit id is given with the unit
argument, the script will try and default to targeting the currently selected unit.

Other arguments:

:list:
    Prints a list of all beliefs + their IDs.
:noneed:
    By default, unit's needs will be recalculated to reflect new beliefs after every run.
    Use this argument to disable that functionality.
:listunit:
    Prints a list of all a unit's beliefs. Cultural defaults are marked with ``*``.
