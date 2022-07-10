
devel/sc
========
Size Check: scans structures for invalid vectors, misaligned structures,
and unidentified enum values.

.. note::

    This script can take a very long time to complete, and DF may be
    unresponsive while it is running. You can use `kill-lua` to interrupt
    this script.

Examples:

* scan world::

    devel/sc

* scan all globals::

    devel/sc -all

* scan result of expression::

    devel/sc [expr]
