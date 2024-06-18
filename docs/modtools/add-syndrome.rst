modtools/add-syndrome
=====================

.. dfhack-tool::
    :summary: Add and remove syndromes from units.
    :tags: dev

This allows adding and removing syndromes from units.

Usage
-----

::

    modtools/add-syndrome --target <id> --syndrome <name>|<id> [<options>]
    modtools/add-syndrome --target <id> --eraseClass <class>

Examples
--------

``modtools/add-syndrome --target 2391 --syndrome "gila monster bite" --eraseAll``
    Remove all instances of the "gila monster bite" syndrome from the specified
    unit.
``modtools/add-syndrome --target 1231 --syndrome 14 --resetPolicy DoNothing``
    Adds syndrome 14 to the specified unit, but only if that unit doesn't
    already have the syndrome.

Options
-------

``--target <id>``
    The unit id of the target unit.
``--syndrome <name>|<id>``
    The syndrome to work with.
``--resetPolicy <policy>``
    Specify a policy of what to do if the unit already has an
    instance of the syndrome, one of: ``NewInstance``, ``DoNothing``,
    ``ResetDuration``, or ``AddDuration``. By default, it will create a new
    instance of the syndrome, even if one already exists for the unit.
``--erase``
    Instead of adding an instance of the syndrome, erase one.
``--eraseAll``
    Erase every instance of the syndrome.
``--eraseClass <class id>``
    Erase every instance of every syndrome with the given SYN_CLASS (an integer
    id).
``--skipImmunities``
    Add the syndrome to the target even if it is immune to the syndrome.
