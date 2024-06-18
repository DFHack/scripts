combat-harden
=============

.. dfhack-tool::
    :summary: Set the combat-hardened value on a unit.
    :tags: fort armok units

This tool can make a unit care more/less about seeing corpses.

Usage
-----

::

    combat-harden [<unit option>] [<hardness option>]

Examples
--------

``combat-harden``
    Make the currently selected unit fully combat hardened
``combat-harden --citizens --tier 2``
    Make all fort citizens moderately combat hardened.

Unit options
------------

``--all``
    All active units will be affected.
``--citizens``
    All citizens and residents of your fort will be affected. Will do nothing
    in adventure mode.
``--unit <id>``
    The given unit will be affected.

If no option is given or the indicated unit can't be found, the script will use
the currently selected unit.

Hardness options
----------------

``--value <num>``
    A percent value (0 to 100, inclusive) to set combat hardened to.
``--tier <num>``
    Choose a tier of hardenedness to set it to.
    - 1 = No hardenedness.
    - 2 = "is getting used to tragedy"
    - 3 = "is a hardened individual"
    - 4 = "doesn't really care about anything anymore" (max)

If no option is given, the script defaults to using a value of 100.
