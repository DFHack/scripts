autofish
========

.. dfhack-tool::
    :summary: Auto-manage fishing labors to control your stock of fish.
    :tags: fort auto labors

This script makes managing how much fish you keep around automatic. It tries to
maintain a configured stock level of raw and/or prepared fish, partially to keep
item quantities from ballooning out of control, and partly to try and prevent
collecting too many rotten fish.

Usage
-----

``enable autofish``
    Enable the script
``disable autofish``
    Disable the script
``autofish status``
    Show the current status of the script, your configured values, and whether
    or not fishing is currently enabled.
``autofish <max> [min] [<options>]``
    Change autofish settings.

Positional Parameters
---------------------

``max``
    (default: 100) controls the maximum amount of fish you want to keep on hand
    in your fortress. Fishing will be disabled when the amount of fish goes
    above this value.

``min``
    (default: 75) controls the minimum fish you want before restarting fishing.

Options
-------

``r``, ``--raw (true | false)``
    (default: ``true``) Set whether or not raw fish should be counted in the running
    total of fish in your fortress.

Examples
--------

``enable autofish``
    Enables the script.
``autofish 150 -r true``
    Sets your maximum fish to 150, and enables counting raw fish.
``autofish 300 250``
    Sets your maximum fish to 300 and minimum to 250.
