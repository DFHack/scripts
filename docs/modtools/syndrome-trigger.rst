modtools/syndrome-trigger
=========================

.. dfhack-tool::
    :summary: Trigger DFHack commands when units acquire syndromes.
    :tags: unavailable

This script helps you set up commands that trigger when syndromes are applied to
units.

Usage
-----

::

    modutils/syndrome-trigger --clear
    modutils/syndrome-trigger --syndrome <name> --command [ <command> ]
    modutils/syndrome-trigger --synclass <class> --command [ <command> ]

Options
-------

``--clear``
    Clear any previously registered syndrome triggers.
``--syndrome <name>``
    Specify a syndrome by its name. Enclose the name in quotation marks if it
    includes spaces (e.g. ``--syndrome "gila monster bite"``).
``--synclass <class>``
    Any syndrome with the specified SYN_CLASS will act as a trigger. Enclose in
    quotation marks if it includes spaces.
``--command [ <command> ]``
    Specify the command to be executed after infection. Remember to include a
    space before and after the square brackets! The following tokens may be
    added to appropriate commands where relevant:
    :``\\UNIT_ID``: Inserts the ID of the infected unit.
    :``\\LOCATION``: Inserts the x, y, z coordinates of the infected unit.
    :``\\SYNDROME_ID``: Inserts the ID of the syndrome.

Examples
--------

::

    modutils/syndrome-trigger --synclass VAMPCURSE --command [ modtools/spawn-flow -flowType Dragonfire -location [ \\LOCATION ] ]
