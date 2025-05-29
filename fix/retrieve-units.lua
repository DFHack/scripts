-- Spawns stuck invaders/guests
-- Based on "unitretrieval" by RocheLimit:
-- http://www.bay12forums.com/smf/index.php?topic=163671.0
--@ module = true

local utils = require('utils')

function shouldRetrieve(unit)
    if unit.flags1.incoming then
        return true
    elseif (unit.flags1.merchant or unit.flags1.invades) and not (unit.flags2.killed or unit.flags2.slaughter) then
        -- killed/slaughter check from http://www.bay12games.com/dwarves/mantisbt/view.php?id=10075#c38332
        return true
    else
        return false
    end
end

function retrieveUnits()
    for _, unit in ipairs(df.global.world.units.all) do
        if unit.flags1.inactive and shouldRetrieve(unit) then
            print(("Retrieving from the abyss: %s (%d)"):format(
                dfhack.df2console(dfhack.units.getReadableName(unit)), unit.id))
            unit.flags1.move_state = true
            unit.flags1.inactive = false
            unit.flags1.incoming = false
            unit.flags1.can_swap = true
            unit.flags1.hidden_in_ambush = false
            -- add to active if missing
            if not utils.linear_index(df.global.world.units.active, unit.id, 'id') then
                df.global.world.units.active:insert('#', unit)
            end
        end
    end
end

if not dfhack_flags.module then
    retrieveUnits()
end
