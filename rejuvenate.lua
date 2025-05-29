--@ module = true

local utils = require('utils')

local DEFAULT_CHILD_AGE = 18
local DEFAULT_OLD_AGE = 160
local ANY_BABY = df.global.world.units.other.ANY_BABY

local function get_caste_misc(unit)
    local craw = dfhack.units.getCasteRaw(unit)
    if not craw then return end
    return craw.misc
end

local function get_adult_age(misc)
    return misc and misc.child_age or DEFAULT_CHILD_AGE
end

local function get_rand_old_age(misc)
    return misc and math.random(misc.maxage_min, misc.maxage_max) or DEFAULT_OLD_AGE
end

-- called by armoks-blessing
function rejuvenate(unit, quiet, force, dry_run, age)
    local name = dfhack.df2console(dfhack.units.getReadableName(unit))
    local misc = get_caste_misc(unit)
    local adult_age = get_adult_age(misc)
    age = age or adult_age
    if age < adult_age then
        dfhack.printerr('cannot set age to child or baby range')
        return
    end
    local current_year = df.global.cur_year
    local new_birth_year = current_year - age
    local new_old_year = unit.old_year < 0 and -1 or math.max(unit.old_year, new_birth_year + get_rand_old_age(misc))
    if unit.birth_year > new_birth_year and not force then
        if not quiet then
            dfhack.printerr(name .. ' is under ' .. age .. ' years old. Use --force to force.')
        end
        return
    end
    if dry_run then
        print('would change: ' .. name)
        return
    end

    local hf = df.historical_figure.find(unit.hist_figure_id)
    unit.birth_year = new_birth_year
    if hf then hf.born_year = new_birth_year end
    unit.old_year = new_old_year
    if hf then hf.old_year = new_old_year end

    if unit.profession == df.profession.BABY or unit.profession == df.profession.CHILD then
        if unit.profession == df.profession.BABY then
            local idx = utils.linear_index(ANY_BABY, unit.id, 'id')
            if idx then
                ANY_BABY:erase(idx)
            end
            unit.flags1.rider = false
            unit.relationship_ids.RiderMount = -1
            unit.mount_type = df.rider_positions_type.STANDARD
            unit.profession2 = df.profession.STANDARD
            unit.idle_area_type = df.unit_station_type.MillBuilding
            unit.mood = -1

            -- let the mom know she isn't carrying anyone anymore
            local mother = df.unit.find(unit.relationship_ids.Mother)
            if mother then mother.flags1.ridden = false end
        end
        unit.profession = df.profession.STANDARD
        unit.profession2 = df.profession.STANDARD
        if hf then hf.profession = df.profession.STANDARD end
    end
    unit.flags4.portrait_must_be_refreshed = true
    unit.flags4.any_texture_must_be_refreshed = true
    if dfhack.world.isFortressMode() then
        dfhack.units.setAutomaticProfessions(unit)
    end
    if not quiet then
        print(name .. ' is now ' .. age .. ' years old and will live a normal lifespan henceforth')
    end
end

local function main(args)
    local units = {} --as:df.unit[]
    if args.all then
        units = dfhack.units.getCitizens()
    else
        table.insert(units, dfhack.gui.getSelectedUnit(true) or qerror("Please select a unit in the UI."))
    end
    for _, u in ipairs(units) do
        rejuvenate(u, false, args.force, args['dry-run'], tonumber(args.age))
    end
end

if dfhack_flags.module then return end

main(utils.processArgs({...}, utils.invert({
    'all',
    'force',
    'dry-run',
    'age'
})))
