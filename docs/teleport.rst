
teleport
========
Teleports a unit to given coordinates.

.. note::

    `gui/teleport` is an in-game UI for this script.

Examples:

* prints ID of unit beneath cursor::

    teleport -showunitid

* prints coordinates beneath cursor::

    teleport -showpos

* teleports unit ``1234`` to ``56,115,26``

    teleport -unit 1234 -x 56 -y 115 -z 26
