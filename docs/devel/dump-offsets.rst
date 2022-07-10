
devel/dump-offsets
==================

.. warning::

    THIS SCRIPT IS STRICTLY FOR DFHACK DEVELOPERS.

    Running this script on a new DF version will NOT
    MAKE IT RUN CORRECTLY if any data structures
    changed, thus possibly leading to CRASHES AND/OR
    PERMANENT SAVE CORRUPTION.

This dumps the contents of the table of global addresses (new in 0.44.01).

Passing global names as arguments calls setAddress() to set those globals'
addresses in-game. Passing "all" does this for all globals.

