deathcause
==========

.. dfhack-tool::
    :summary: Find out the cause of death for a creature.
    :tags: fort inspection units

Select a corpse or body part on the ground, and ``deathcause`` will detail the
cause of death of the creature.

Usage
-----

::

    deathcause

API
---

The ``deathcause`` script can be called programmatically by other scripts, either via the
commandline interface with ``dfhack.run_script()`` or via the API functions
defined in :source-scripts:`deathcause.lua`, available from the return value of
``reqscript('deathcause')``:

* ``getDeathCause(unit or historical_figure)``

Returns a string with the unit or historical figure's cause of death. Note that using a historical
figure will sometimes provide more information than using a unit.


 API usage example::

   local dc = reqscript('deathcause')

   -- Note: this is an arguably bad example because this is the same as running deathcause
   -- from the launcher, but this would theoretically still work.
   local deathReason = dc.getDeathCauseFromUnit(dfhack.gui.getSelectedUnit())
   print(deathReason)
