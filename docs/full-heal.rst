full-heal
=========

.. dfhack-tool::
    :summary: Fully heal the selected unit.
    :tags: fort armok units

This script attempts to heal the selected unit from anything, optionally
including death.

Usage
-----

``full-heal``
    Completely heal the currently selected unit.
``full-heal --unit <unitId>``
    Completely heal the unit with the given ID.
``full-heal -r [--keep_corpse]``
    Heal the unit, raising from the dead if needed. If ``--keep_corpse`` is
    specified, don't remove their corpse. The unit can be targeted by selecting
    its corpse in the UI.
``full-heal --all [-r] [--keep_corpse]``
    Heal all units on the map, optionally resurrecting them if dead.
``full-heal --all_citizens [-r] [--keep_corpse]``
    Heal all fortress citizens and residents on the map. Does not include pets.
``full-heal --all_civ [-r] [--keep_corpse]``
    Heal all units belonging to your parent civilization, including pets and
    visitors.

Examples
--------

``full-heal``
    Fully heal the selected unit.
``full-heal -r --keep_corpse --unit 23273``
    Fully heal unit 23273. If this unit was dead, it will be resurrected without
    removing the corpse - creepy!

Notes
-----

If you have to repeatedly use `full-heal` on a dwarf only to have that dwarf's
syndrome return seconds later, then it's likely because said dwarf still has a
syndrome-causing residue on their body. To deal with this, either use
``clean units`` to decontaminate the dwarf or let a hospital worker wash the
residue off the dwarf and THEN do a `full-heal`. Syndromes like Beast Sickness
and Demon Sickness can by VERY NASTY, causing maladies like tissue necrosis.
