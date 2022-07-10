
autonick
========
Gives dwarves unique nicknames chosen randomly from ``dfhack-config/autonick.txt``.

One nickname per line.
Empty lines, lines beginning with ``#`` and repeat entries are discarded.

Dwarves with manually set nicknames are ignored.

If there are fewer available nicknames than dwarves, the remaining
dwarves will go un-nicknamed.

You may wish to use this script with the "repeat" command, e.g:
``repeat -name autonick -time 3 -timeUnits months -command [ autonick all ]``

Usage:

    autonick all [<options>]
    autonick help

Options:

:``-h``, ``--help``:
    Show this text.
:``-q``, ``--quiet``:
    Do not report how many dwarves were given nicknames.
