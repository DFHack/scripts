fix/loyaltycascade
==================

.. dfhack-tool::
    :summary: Halts loyalty cascades where dwarves are fighting dwarves.
    :tags: fort bugfix units

This tool neutralizes loyalty cascades by fixing units who consider their own
civilization to be the enemy. It will also halt all fighting on the map that
involves your citizens, though "real" enemies will re-engage in combat after a
short delay.

Usage
-----

::

    fix/loyaltycascade
