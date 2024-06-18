instruments
===========

.. dfhack-tool::
    :summary: Show how to craft instruments or create work orders for them.
    :tags: fort inspection workorders

This tool is used to query information about instruments or to create work orders for them.

The ``list`` subcommand provides information on how to craft the instruments
used by the player civilization. For single-piece instruments, it shows the
skill and material needed to craft it. For multi-piece instruments, it displays
the skill used in its assembly as well as information on how to craft the
necessary pieces. It also shows whether the instrument is handheld or placed as
a building.

The ``order`` subcommand is used to create work orders for an instrument and
all of it's parts. The final assemble instrument -order waits for the part
orders to complete before starting.

Usage
-----

::

    instruments [list]
    instruments order <instrument_name> [<quantity>] [<options>]

When ordering, the default is to order one of the specified instrument
(including all of its components).

Examples
--------

``instruments``
    List instruments and their recipes.
``instruments order givel 10``
    If the instrument named ``givel`` in your world has four components, this
    will create a total of 5 work orders: one for assembling 10 givels, and an
    order of 10 for each of the givel's parts. Instruments are randomly
    generated, so your givel components may vary.

``instruments order ilul``
    Creates work orders to assemble one ïlul. Spelling doesn't need to include
    the special ï character.

Options
-------

``-q``, ``--quiet``
    Suppress non-error console output.
