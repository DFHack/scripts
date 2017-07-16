-- Spawns stuck invaders/guests
-- Based on "unitretrieval" by RocheLimit:
-- http://www.bay12forums.com/smf/index.php?topic=163671.0
--@ module = true

--[====[

fix/retrieve-units
==================

This script forces some units off the map to enter the map, which can fix issues
such as the following:

- Stuck [SIEGE] tags due to invisible armies (or parts of armies)
- Forgotten beasts that never appear
- Packs of wildlife that are missing from the surface or caverns
- Caravans that are partially or completely missing.

.. note::
    For caravans that are missing entirely, this script may retrieve the
    merchants but not the items. Using `fix/stuck-merchants` followed by `force`
    to create a new caravan may work better.

]====]

function retrieveUnits()
    for _, unit in pairs(df.global.world.units.active) do
        if unit.flags1.dead and unit.flags1.incoming then
            print(("Retrieving from the abyss: %s (%s)"):format(
                dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unit))),
                df.creature_raw.find(unit.race).name[0]
            ))
            unit.flags1.move_state = true
            unit.flags1.dead = false
            unit.flags1.incoming = false
            unit.flags1.can_swap = true
            unit.flags1.hidden_in_ambush = false
        end
    end
end

if not dfhack_flags.module then
    retrieveUnits()
end
