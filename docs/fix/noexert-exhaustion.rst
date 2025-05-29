fix/noexert-exhaustion
======================

.. dfhack-tool::
    :summary: Prevents NOEXERT units from getting tired when training.
    :tags: fort bugfix units

This tool zeroes the "exhaustion" counter of all NOEXERT units (e.g. Vampires, Necromancers, and Intelligent Undead),
fixing any that are stuck 'Tired' from an activity that doesn't respect NOEXERT. This is not a permanent fix -
the issue will reoccur next time they partake in an activity that does not respect the NOEXERT tag.

Running this regularly works around :bug:`8389`, which permanently debuffs NOEXERT units and prevents them from
properly partaking in military training. It should be run if you notice Vampires, Necromancers, or Intelligent
Undead becoming 'Tired'. Enabling this script via `control-panel` or `gui/control-panel` will run it often enough to
prevent NOEXERT units from becoming 'Tired'.

Usage
-----
::

    fix/noexert-exhaustion

Technical details
-----------------

Units with the NOEXERT tag ignore most sources of physical exertion, and have no means to recover from it.
Individual Combat Drill seems to add approximately 50 'Exhaustion' every 9 ticks, ignoring NOEXERT.
Units become Tired at 2000 Exhaustion, and switch from Individual Combat Drill to Individual Combat Drill/Resting at 3000.
Setting the Exhaustion counter of every NOEXERT-tagged unit to 0 every 350 ticks should prevent them from becoming Tired from Individual Combat Drill.
