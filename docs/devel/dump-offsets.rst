devel/dump-offsets
==================

.. dfhack-tool::
    :summary: Dump the contents of the table of global addresses.
    :tags: dev

.. warning::

    THIS SCRIPT IS STRICTLY FOR DFHACK DEVELOPERS.

    Running this script on a new DF version will NOT MAKE IT RUN CORRECTLY if
    any data structures changed, thus possibly leading to CRASHES AND/OR
    PERMANENT SAVE CORRUPTION.

This script dumps the contents of the table of global addresses (new in
0.44.01).

Usage
-----

::

    devel/dump-offsets all|<global var>

Passing global names as arguments calls ``setAddress()`` to set those globals'
addresses in-game. Passing "all" does this for all globals.
