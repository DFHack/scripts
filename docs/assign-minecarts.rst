assign-minecarts
================

.. dfhack-tool::
    :summary: Assign minecarts to hauling routes.
    :tags: fort productivity

This script allows you to quickly assign minecarts to hauling routes without
having to go through the in-game interface.

Note that a hauling route must have at least one stop defined before a minecart
can be assigned to it.

Usage
-----

``assign-minecarts list``
    Print information about your hauling routes, including whether they
    currently have minecarts assigned to them.
``assign-minecarts all|<route id> [-q|--quiet]``
    Find and assign a free minecart to all hauling routes (or the specified
    hauling route). Hauling routes that already have a minecart assigned to them
    are skipped.

Add ``-q`` or ``--quiet`` to suppress extra informational output.

Example
-------

::

    assign-minecarts all
