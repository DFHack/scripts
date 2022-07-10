
clear-webs
==========
This script removes all webs that are currently on the map,
and also frees any creatures who have been caught in one.

Note that it does not affect sprayed webs until
they settle on the ground.

Usable in both fortress and adventurer mode.

Web removal and unit release happen together by default.
The following may be used to isolate one of these actions:

Arguments::

    -unitsOnly
        Include this if you want to free all units from webs
        without removing any webs

    -websOnly
        Include this if you want to remove all webs
        without freeing any units

See also `fix/drop-webs`.

