
devel/find-offsets
==================

.. warning::

    THIS SCRIPT IS STRICTLY FOR DFHACK DEVELOPERS.

    Running this script on a new DF version will NOT
    MAKE IT RUN CORRECTLY if any data structures
    changed, thus possibly leading to CRASHES AND/OR
    PERMANENT SAVE CORRUPTION.

Finding the first few globals requires this script to be
started immediately after loading the game, WITHOUT
first loading a world. The rest expect a loaded save,
not a fresh embark. Finding current_weather requires
a special save previously processed with `devel/prepare-save`
on a DF version with working dfhack.

The script expects vanilla game configuration, without
any custom tilesets or init file changes. Never unpause
the game unless instructed. When done, quit the game
without saving using 'die'.

Arguments:

* global names to force finding them
* ``all`` to force all globals
* ``nofeed`` to block automated fake input searches
* ``nozoom`` to disable neighboring object heuristics
