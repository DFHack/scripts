list-waves
==========

.. dfhack-tool::
    :summary: Show migration wave membership and history.
    :tags: fort inspection units

This script displays information about past migration waves: when they arrived
and which dwarves arrived in them. If you have a citizen selected in the UI or
if you have passed the ``--unit`` option with a unit id, that citizen's name
and wave will be highlighted in the output.

Residents that became citizens via petitions will be grouped with any other
dwarves that immigrated/joined at the same time.

Usage
-----

::

    list-waves [<wave num> ...] [<options>]

You can show only information about specific waves by specifying the wave
numbers on the commandline. Otherwise, all waves are shown. The first migration
wave that normally arrives in a fort's second season is wave number 1. The
founding dwarves arrive in wave 0.

Examples
--------

``list-waves``
    Show how many of your current dwarves came in each migration wave, when
    the waves arrived, and the names of the dwarves in each wave.
``list-waves --no-names``
    Only show how many dwarves came in each seasonal migration wave and when
    the waves arrived. Don't show the list of dwarves that came in each wave.
``list-waves 0``
    Identify your founding dwarves.

Options
-------

``-d``, ``--no-dead``
    Exclude residents and citizens who have died.
``-g``, ``--granularity <value>``
    Specifies the granularity of wave enumeration: ``years``, ``seasons``,
    ``months``, or ``days``. If omitted, the default granularity is ``seasons``,
    the same as Dwarf Therapist.
``-n``, ``--no-names``
    Don't output the names of the members of each migration wave.
``-p``, ``--no-petitioners``
    Exclude citizens who joined via petition. That is, only show dwarves who
    came in an actual migration wave.
``-u``, ``--unit <id>``
    Highlight the specified unit's arrival wave information.
