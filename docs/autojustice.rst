autojustice
===========

.. dfhack-tool::
    :summary: Auto-manage justice interviews and convictions.
    :tags: fort auto

This script automate most of the tedious parts of the justice system. It schedules visitors interviews, convict confessed crimes and interview accused units.

Usage
-----
``enable autojustice``
    Enable the script
``disable autojustice``
    Disable the script
``autojustice [<options>]``
    Set conviction options

Options
-------

``-c``, ``--citizen none|jail|beat|hammer``
    Set the maximum punishment allowed for citizens when auto-convicting (default: jail).

``-v``, ``--visitor none|jail|beat|hammer``
    Set the maximum punishment allowed for visitors when auto-convicting (default: hammer).

Examples
--------

``enable autojustice``
    Enables the script.

``autojustice -citizen beat``
    Citizens will be convicted from crimes up to beating punishment.

``autojustice -v jail``
    Visitors will be convicted from crimes up to jail punishment.