fix/population-cap
==================

.. dfhack-tool::
    :summary: Ensure the population cap is respected.
    :tags: fort bugfix

Run this if you continue to get migrant wave even after you have exceeded your
set population cap.

The reason this tool is needed is that the game only updates the records of your
current population when a dwarven caravan successfully leaves for the
mountainhomes. If your population was under the cap at that point, you will
continue to get migrant waves. If another caravan never comes (or is never able
to leave), you'll get migrant waves forever.

This tool ensures the population value always reflects the current population of
your fort.

Note that even with this tool, a migration wave can still overshoot the limit by
1-2 dwarves because the last migrant might choose to bring their family.
Likewise, monarch arrival ignores the population cap.

Usage
-----

::

    fix/population-cap
