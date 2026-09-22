devel/jobwatch
==============

.. dfhack-tool::
    :summary: Report unit job transitions as they happen.
    :tags: dev

Aids script development and reverse engineering by observing job churn that is
otherwise invisible: the game's assignment pass runs inside the tick, so only
its effects on ``unit.job.current_job`` can be seen from Lua. This tool polls
all active units once per tick and prints a line whenever a unit gains, loses,
or switches jobs -- including switches between two jobs of the same type, which
is how claim races appear.

Usage
-----

::

    enable devel/jobwatch
    devel/jobwatch unit <id>|all
    devel/jobwatch verbose
    disable devel/jobwatch

``unit`` restricts output to a single unit id. ``verbose`` additionally prints
each job's id, posting index, and ``do_now``/``special`` flags.
