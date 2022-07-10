
full-heal
=========
Attempts to fully heal the selected unit from anything, optionally
including death.  Usage:

:full-heal:
    Completely heal the currently selected unit.
:full-heal -unit [unitId]:
    Apply command to the unit with the given ID, instead of selected unit.
:full-heal -r [-keep_corpse]:
    Heal the unit, raising from the dead if needed.
    Add ``-keep_corpse`` to avoid removing their corpse.
    The unit can be targeted by selecting its corpse on the UI.
:full-heal -all [-r] [-keep_corpse]:
    Heal all units on the map.
:full-heal -all_citizens [-r] [-keep_corpse]:
    Heal all fortress citizens on the map. Does not include pets.
:full-heal -all_civ [-r] [-keep_corpse]:
    Heal all units belonging to your parent civilisation, including pets and visitors.

For example, ``full-heal -r -keep_corpse -unit ID_NUM`` will fully heal
unit ID_NUM.  If this unit was dead, it will be resurrected without deleting
the corpse - creepy!

