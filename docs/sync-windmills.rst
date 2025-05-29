sync-windmills
==============

.. dfhack-tool::
    :summary: Synchronize or randomize windmill movement.
    :tags: fort buildings

Windmills cycle between two graphical states to simulate movement. This is the
polarity of the appearance. Each windmill also has a timer that controls when
the windmill switches polarity. Each windmill's timer starts from zero at the
instant that it is built, so two different windmills will rarely have exactly
the same state. This tool can adjust the alignment of polarity and timers
across your active windmills to your preference.

Note that this tool will not affect windmills that have just been activated and
are still rotating to adjust to the regional wind direction.

Usage
-----

::

    sync-windmills [<options>]

Examples
--------

``sync-windmills``
    Synchronize movement of all active windmills.
``sync-windmills -r``
    Randomize the movement of all active windmills.

Options
-------

``-q``, ``--quiet``
    Suppress non-error console output.
``-r``, ``--randomize``
    Randomize the polarity and timer value for all windmills.
``-t``, ``--timing-only``
    Randomize windmill polarity, but synchronize windmill timers.
