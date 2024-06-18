set-timeskip-duration
=====================

.. dfhack-tool::
    :summary: Modify the duration of the pre-game world update.
    :tags: adventure embark fort armok

Starting a new fortress/adventurer session is preceded by an "Updating World"
process which is normally 2 weeks long. This script allows you to modify the
duration of this timeskip, enabling you to jump into the game earlier or later
than usual.

You can use this tool at any point before the timeskip begins (for example,
while still at the "Start Playing" menu).

It is also possible to run the script while the world is updating, which can be
useful if you decide to end the process earlier or later than initially planned.

Note that the change in timeskip duration will persist until either:

- the game is closed
- the ``--clear`` argument is used (see below)
- the timeskip duration is overwritten by setting a new duration

Usage
-----

::

    set-timeskip-duration --clear
    set-timeskip-duration <duration options>

Examples
--------

``set-timeskip-duration --ticks 851249``
    Sets the end of the timeskip to 2 years, 1 month, 9 days, 8 hours,
    58 minutes, and 48 seconds from the current date.
``set-timeskip-duration --years 2 --months 1 --days 9 --hours 8 --ticks 49``
    Does the same thing as the previous example.

Options
-------

The ``<num>`` values passed to any option below must be positive integers (or
0).

``--clear``
    Reset the timeskip duration to its default value. Note that this won't
    affect timeskips which have already begun.
``--ticks <num>``
    Adds the specified number of ticks to the timeskip duration The following
    conversions may help you calculate this::

        1 tick = 72 seconds = 1 minute 12 seconds
        50 ticks = 60 minutes = 1 hour
        1200 ticks = 24 hours = 1 day
        8400 ticks = 7 days = 1 week
        33600 ticks = 4 weeks = 1 month
        403200 ticks = 12 months = 1 year

``--years <num>``, ``--months <num>``, ``--days <num>``, ``--hours <num>``
    Adds the appropriate number ticks to the timeskip duration
