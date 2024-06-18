modtools/skill-change
=====================

.. dfhack-tool::
    :summary: Modify unit skills.
    :tags: dev

Sets or modifies a skill of a unit.

Usage
-----

::

    modtools/skill-change --unit <id> --skill <skill> --mode <mode> --granularity <granularity> --value <amount> [--loud]

Options
-------

``--unit <id>``
    Id of the target unit.
``--skill <skill>``
    Specify which skill to set.
``--mode <mode>``
    Mode can be ``add`` or ``set``, depending on whether you want to add to the
    existing experience/level or set it.
``--granularity <granularity>``
    Granularity can be ``experience`` or ``level``, depending on whether you
    want to modify/set the experience value or the experience level.
``--value <amount>``
    How much to set/add.
``--loud``
    if present, prints changes to console
