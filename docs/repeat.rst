
repeat
======
Repeatedly calls a lua script at the specified interval. This can be used from
init files. Note that any time units other than ``frames`` are unsupported when
a world is not loaded (see ``dfhack.timeout()``).

Usage examples::

    repeat -name jim -time delay -timeUnits units -command [ printArgs 3 1 2 ]
    repeat -time 1 -timeUnits months -command [ multicmd cleanowned scattered x; clean all ] -name clean
    repeat -list

The first example is abstract; the second will regularly remove all contaminants
and worn items from the game.

Arguments:

``-name``
    sets the name for the purposes of cancelling and making sure you
    don't schedule the same repeating event twice.  If not specified,
    it's set to the first argument after ``-command``.
``-time DELAY -timeUnits UNITS``
    DELAY is some positive integer, and UNITS is some valid time
    unit for ``dfhack.timeout`` (default "ticks").  Units can be
    in simulation-time "frames" (raw FPS) or "ticks" (only while
    unpaused), while "days", "months", and "years" are by in-world time.
``-command [ ... ]``
    ``...`` specifies the command to be run
``-cancel NAME``
    cancels the repetition with the name NAME
``-list``
    prints names of scheduled commands
