-- set age of selected unit
-- by vjek
--@ module = true

local utils = require('utils')

function rejuvenate(unit, force, dry_run, age)
    local current_year = df.global.cur_year
    if not age then
        age = 20
    end
    local new_birth_year = current_year - age
    local name = dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unit)))
    if unit.birth_year > new_birth_year and not force then
        print(name .. ' is under ' .. age .. ' years old. Use --force to force.')
        return
    end
    if dry_run then
        print('would change: ' .. name)
        return
    end
    unit.birth_year = new_birth_year
    if unit.old_year < new_birth_year + 160 then
        unit.old_year = new_birth_year + 160
    end
    if unit.profession == df.profession.BABY or unit.profession == df.profession.CHILD then
        if unit.profession == df.profession.BABY then
            local leftoverUnits = {}
            local shiftedLeftoverUnits = {}
            -- create a copy
            local babyUnits = df.global.world.units.other.ANY_BABY
            -- create a new table with the units that aren't being removed in this iteration
            for _, v in ipairs(babyUnits) do
                if not v.id == unit.id then
                    table.insert(leftoverUnits, v)
                end
            end
            -- create a shifted table of the leftover units to make up for lua tables starting with index 1 and the game starting with index 0
            for i = 0, #leftoverUnits - 1, 1 do
                local x = i+1
                shiftedLeftoverUnits[i] = leftoverUnits[x]
            end
            -- copy the leftover units back to the game table
            df.global.world.units.other.ANY_BABY = shiftedLeftoverUnits
            -- set extra flags to defaults
            unit.flags1.rider = false
            unit.relationship_ids.RiderMount = -1
            unit.mount_type = 0
            unit.profession2 = df.profession.STANDARD
            unit.idle_area_type = 26
            unit.mood = -1
            -- let the mom know she isn't carrying anyone anymore
            local motherUnitId = unit.relationship_ids.Mother
            df.unit.find(motherUnitId).flags1.ridden = false
        end
        unit.profession = df.profession.STANDARD
    end
    print(name .. ' is now ' .. age .. ' years old and will live to at least 160')
end

function main(args)
    local units = {} --as:df.unit[]
    if args.all then
        units = dfhack.units.getCitizens()
    else
        table.insert(units, dfhack.gui.getSelectedUnit(true) or qerror("Please select a unit in the UI."))
    end
    for _, u in ipairs(units) do
        rejuvenate(u, args.force, args['dry-run'], args.age)
    end
end

if dfhack_flags.module then return end

main(utils.processArgs({...}, utils.invert({
    'all',
    'force',
    'dry-run',
    'age'
})))
