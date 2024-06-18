modtools/transform-unit
=======================

.. dfhack-tool::
    :summary: Transform a unit into another unit type.
    :tags: unavailable

This tool transforms a unit into another unit type, either temporarily or
permanently.

Warning: this will crash arena mode if you view the unit on the
same tick that it transforms. If you wait until later, it will be fine.

Usage
-----

::

    modtools/transform-unit --unit <id> --race <race> --caste <caste> [--duration <ticks>] [--keepInventory] [--setPrevRace]
    modtools/transform-unit --unit <id> --untransform
    modtools/transform-unit --clear

Options
-------

``--unit <id>``
    Set the target unit.
``--race <race>``
    Set the target race.
``--caste <caste>``
    Set the target caste.
``--duration <ticks>``
    Set how long the transformation should last, or "forever". If not specified,
    then the transformation is permanent.
``--keepInventory``
    Move items back into inventory after transformation
``--setPrevRace``
    Remember the previous race so that you can change the unit back with
    ``--untransform``
``--untransform``
    Turn the unit back into what it was before (assuming you used the
    ``--setPrevRace`` option when transforming the first time).
``--clear``
    Clear records of "previous" races used by the ``--untransform`` option.
