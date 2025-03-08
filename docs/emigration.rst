emigration
==========

.. dfhack-tool::
    :summary: Allow dwarves to emigrate from the fortress when stressed.
    :tags: fort gameplay units

If a dwarf is spiraling downward and is unable to cope in your fort, this tool
will give them the choice to leave the fortress (and the map).

Dwarves will choose to leave in proportion to how badly stressed they are.
Dwarves who can leave in friendly company (e.g. a dwarven merchant caravan) will
choose to do so, but extremely stressed dwarves can choose to leave alone, or
even in the company of a visiting elven bard!

The check is made monthly. A happy dwarf (i.e. with negative stress) will never
emigrate.

The tool also supports ``nobles``, a manually-invoked command that makes nobles
emigrate to their rightful land of rule. No more freeloaders making inane demands!
Nobles assigned to squads or to fort administrator positions will not be emigrated.
Remove their assignments before retrying. Nobles holding elected positions
(i.e. mayors) may be emigrated, but will be marked with a ``*`` icon when listed.

Usage
-----

::

    enable emigration
    emigration nobles [--list]
    emigration nobles [<target>]

Examples
--------

``emigration nobles``
    Emigrate the selected noble if it does not rule your fortress.
    If no unit is selected, list all nobles that do not rule your fortress.
``emigration nobles --list``
    List all nobles that do not rule your fortress. Nobles that cannot be emigrated
    (see above) will have a ``!`` indicator while nobles holding elected positions
    will have a ``*`` indicator.
``emigration nobles --all``
    Emigrate all nobles that do not rule your fortress.
``emigration nobles --unit 34534``
    Emigrate a noble matching the specified unit ID that does not rule your fortress.

Options
-------

These options are exclusive to the ``emigration nobles`` command.

``-l``, ``--list``
    List all nobles that do not rule your fortress
``-a``, ``--all``
    Emigrate all nobles do not rule your fortress
``-u``, ``--unit <id>``
    Emigrate noble matching specified unit ID that does not rule your fortress
