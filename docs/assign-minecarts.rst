
assign-minecarts
================
This script allows you to assign minecarts to hauling routes without having to
use the in-game interface.

Usage::

    assign-minecarts list|all|<route id> [-q|--quiet]

:list: will show you information about your hauling routes, including whether
       they have minecarts assigned to them.
:all: will automatically assign a free minecart to all hauling routes that don't
      have a minecart assigned to them.

If you specifiy a route id, only that route will get a minecart assigned to it
(if it doesn't already have one and there is a free minecart available).

Add ``-q`` or ``--quiet`` to suppress informational output.

Note that a hauling route must have at least one stop defined before a minecart
can be assigned to it.
