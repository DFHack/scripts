
hfs-pit
=======
Creates a pit to the underworld at the cursor, taking three numbers as
arguments.  Usage:  ``hfs-pit <size> <walls> <stairs>``

The first argument is size of the (square) pit in all directions.  The second
is ``1`` to wall off the sides of the pit on all layers except the underworld,
or anything else to leave them open.  The third parameter is 1 to add stairs.
Stairs are buggy; they will not reveal the bottom until you dig somewhere,
but underworld creatures will path in.

Examples::

    hfs-pit 1 0 0
        A single-tile wide pit with no walls or stairs.
        This is the default if no numbers are given.

    hfs-pit 4 0 1
        A four-across pit with no stairs but adding walls.

    hfs-pit 2 1 0
        A two-across pit with stairs but no walls.

