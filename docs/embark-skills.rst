embark-skills
=============

.. dfhack-tool::
    :summary: Adjust dwarves' skills when embarking.
    :tags: embark armok units

When selecting starting skills for your dwarves on the embark screen, this tool
can manipulate the skill values or adjust the number of points you have
available to distribute.

Note that already-used skill points are not taken into account or reset.

Usage
-----

``embark-skills points <N> [all]``
    Sets the skill points remaining of the selected dwarf (or all dwarves) to
    ``N``.
``embark-skills max [all]``
    Sets all skills of the selected dwarf (or all dwarves) to "Proficient".
``embark-skills legendary [all]``
    Sets all skills of the selected dwarf (or all dwarves) to "Legendary".

Examples
--------

``embark-skills points 10``
    After using all points for the selected dwarf, this will give you an extra
    10 to assign to that dwarf.
``embark-skills legendary all``
    Make all your starting dwarves incredibly skilled.
