devel/scan-vtables
==================

.. dfhack-tool::
    :summary: Scan for and print likely vtable addresses.
    :tags: dev

.. warning::

    THIS SCRIPT IS STRICTLY FOR DFHACK DEVELOPERS.

    Running this script on a new DF version will NOT MAKE IT RUN CORRECTLY if
    any data structures changed, thus possibly leading to CRASHES AND/OR
    PERMANENT SAVE CORRUPTION.

This script scans for likely vtables in memory pages mapped to the DF
executable, and prints them in a format ready for inclusion in ``symbols.xml``

Usage
-----

::

    devel/scan-vtables
