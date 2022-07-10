
gui/family-affairs
==================
A user-friendly interface to view romantic relationships,
with the ability to add, remove, or otherwise change them at
your whim - fantastic for depressed dwarves with a dead spouse
(or matchmaking players...).

The target/s must be alive, sane, and in fortress mode.

.. image:: /docs/images/family-affairs.png
   :align: center

``gui/family-affairs [unitID]``
        shows GUI for the selected unit, or the specified unit ID

``gui/family-affairs divorce [unitID]``
        removes all spouse and lover information from the unit
        and it's partner, bypassing almost all checks.

``gui/family-affairs [unitID] [unitID]``
        divorces the two specified units and their partners,
        then arranges for the two units to marry, bypassing
        almost all checks.  Use with caution.
