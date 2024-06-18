list-waves
==========

.. dfhack-tool::
    :summary: Show migration wave information.
    :tags: fort inspection units

This script displays information about migration waves or identifies which wave
a particular dwarf came from.

Usage
-----

::

    list-waves --all [--showarrival] [--granularity <value>]
    list-waves --unit [--granularity <value>]

Examples
--------

``list-waves --all``
    Show how many dwarves came in each migration wave.
``list-waves --all --showarrival``
    Show how many dwarves came in each migration wave and when that migration
    wave arrived.
``list-waves --unit``
    Show which migration wave the selected dwarf arrived with.

Options
-------

``--unit``
    Displays the highlighted unit's arrival wave information.
``--all``
    Displays information about each arrival wave.
``--granularity <value>``
    Specifies the granularity of wave enumeration: ``years``, ``seasons``,
    ``months``, or ``days``. If omitted, the default granularity is ``seasons``,
    the same as Dwarf Therapist.
``--showarrival``:
    Shows the arrival date for each wave.
