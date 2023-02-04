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

``-j true|false``, ``--jailcitizen true|false``
    Convict citizen when there is at least a jail punishment (default: true).

``-b true|false``, ``--beatcitizen true|false``
    Convict citizen when there is at least a beating punishment (default: false).

``-h true|false``, ``--hammercitizen true|false``
    Convict citizen when there is at least a hammerstrike punishment (default: false).

``-J true|false``, ``--jailvisitor true|false``
    Convict visitor when there is at least a jail punishment (default: true).

``-B true|false``, ``--beatvisitor true|false``
    Convict visitor when there is at least a beating punishment (default: true).

``-H true|false``, ``--hammervisitor true|false``
    Convict visitor when there is at least a hammerstrike punishment (default: true).

Examples
--------

``enable autojustice``
    Enables the script.

``autojustice -beatcitizen true``
    Citizens will be convicted from crimes that have a beating punishment.

``autojustice -J true``
    Visitors will be convicted when their punishment has a jail time.