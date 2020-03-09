-- make the selected dwarf 20 years old
-- by vjek
--@ module = true
--[====[

rejuvenate
==========
Decreases the age of the selected dwarf to 20 years. Useful if valuable citizens
are getting old.

Arguments:

- ``-all``: applies to all citizens
- ``-force``: also applies to units under 20 years old. Useful if there are too many babies around...
- ``-dry-run``: only list units that would be changed; don't actually change ages

]====]

local utils = require('utils')

function rejuvenate(unit, force, dry_run)
    local current_year = df.global.cur_year
    local new_birth_year = current_year - 20
    local name = dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unit)))
    if unit.birth_year > new_birth_year and not force then
        print(name .. ' is under 20 years old. Use -force to force.')
        return
    end
    if dry_run then
        print('would change: ' .. name)
        return
    end
    unit.birth_year = new_birth_year
    if unit.old_year < current_year + 100 then
        unit.old_year = current_year + 100
    end
    if unit.profession == df.profession.BABY or unit.profession == df.profession.CHILD then
        unit.profession = df.profession.STANDARD
    end
    print(name .. ' is now 20 years old and will live at least 100 years')
end

function main(args)
    local current_year, newbirthyear
    local units = {} --as:df.unit[]
    if args.all then
        for _, u in ipairs(df.global.world.units.all) do
            if dfhack.units.isCitizen(u) then
                table.insert(units, u)
            end
        end
    else
        table.insert(units, dfhack.gui.getSelectedUnit(true) or qerror("No unit under cursor! Aborting."))
    end
    for _, u in ipairs(units) do
        rejuvenate(u, args.force, args['dry-run'])
    end
end

if dfhack_flags.module then return end

main(utils.processArgs({...}, utils.invert({
    'all',
    'force',
    'dry-run',
})))
