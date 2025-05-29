bodyswap
========

.. dfhack-tool::
    :summary: Take direct control of any visible unit.
    :tags: adventure armok units

This script allows the player to take direct control of any unit present in
adventure mode whilst giving up control of their current player character.

Usage
-----

::

    bodyswap [--unit <id>]

If no specific unit id is specified, the target unit is the one selected in the
user interface, such as by opening the unit's status screen or viewing its
description.

Examples
--------

``bodyswap``
    Takes control of the selected unit.
``bodyswap --unit 42``
    Takes control of unit with id 42.
