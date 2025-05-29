--@module = true

local argparse = require('argparse')
local exterminate = reqscript('exterminate')
local guidm = require('gui.dwarfmode')

local GLOBAL_KEY = 'fix/wildlife'

DEBUG = DEBUG or false

stuck_creatures = stuck_creatures or {}

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if (sc == SC_MAP_UNLOADED or sc == SC_MAP_LOADED) and
        dfhack.world.isFortressMode()
    then
        stuck_creatures = {}
    end
end

local function print_summary(opts, unstuck)
    if not next(unstuck) then
        if not opts.quiet then
            print('No stuck wildlife found')
            return
        end
    end
    local prefix = opts.week and (GLOBAL_KEY .. ': ') or ''
    local msg_txt = opts.dry_run and '' or 'no longer '
    for _,entry in pairs(unstuck) do
        if entry.count == 1 then
            print(('%s%d %s is %sblocking new waves of wildlife'):format(
                prefix,
                entry.count,
                entry.known and dfhack.units.getRaceReadableNameById(entry.race) or 'hidden creature',
                msg_txt))
        else
            print(('%s%d %s are %sblocking new waves of wildlife'):format(
                prefix,
                entry.count,
                entry.known and dfhack.units.getRaceNamePluralById(entry.race) or 'hidden creatures',
                msg_txt))
        end
    end
end

local function refund_population(entry)
    local epop = entry.pop
    for _,population in ipairs(df.global.world.populations.all) do
        local wpop = population.population
        if population.quantity < 10000001 and
            wpop.region_x == epop.region_x and
            wpop.region_y == epop.region_y and
            wpop.feature_idx == epop.feature_idx and
            wpop.cave_id == epop.cave_id and
            wpop.site_id == epop.site_id and
            wpop.population_idx == epop.population_idx
        then
            population.quantity = math.min(population.quantity + entry.count, population.quantity_max)
            break
        end
    end
end

-- refund unit to population and ensure it doesn't get picked up by unstick_wildlife in the future
local function detach_unit(unit)
    unit.flags2.roaming_wilderness_population_source = false
    unit.flags2.roaming_wilderness_population_source_not_a_map_feature = false
    refund_population{race=unit.race, pop=unit.animal.population, known=true, count=1}
end

local TICKS_PER_DAY = 1200
local TICKS_PER_WEEK = TICKS_PER_DAY * 7
local TICKS_PER_MONTH = 28 * TICKS_PER_DAY
local TICKS_PER_SEASON = 3 * TICKS_PER_MONTH
local TICKS_PER_YEAR = 4 * TICKS_PER_SEASON

-- time checks near year turnover is wishy-washy until we have a datetime API available
local WEEK_BEFORE_EOY_TICKS = TICKS_PER_YEAR - TICKS_PER_WEEK

-- update stuck_creatures records and check timeout
-- we only enter this function if the unit's leave_countdown has already expired
-- returns true if the unit has timed out
local function check_timeout(opts, unit, week_ago_ticks)
    if not opts.week then return true end
    if not stuck_creatures[unit.id] then
        stuck_creatures[unit.id] = df.global.cur_year_tick
        return false
    end
    local timestamp = stuck_creatures[unit.id]
    return timestamp < week_ago_ticks or
        (timestamp > df.global.cur_year_tick and timestamp > WEEK_BEFORE_EOY_TICKS)
end

local function to_key(pop)
    return ('%d:%d:%d:%d:%d:%d'):format(
        pop.region_x, pop.region_y, pop.feature_idx, pop.cave_id, pop.site_id, pop.population_idx)
end

local function is_active_wildlife(unit)
    return not dfhack.units.isDead(unit) and
        dfhack.units.isActive(unit) and
        dfhack.units.isWildlife(unit) and
        unit.flags2.roaming_wilderness_population_source
end

-- called by force for the "Wildlife" event
function free_all_wildlife(include_hidden)
    for _,unit in ipairs(df.global.world.units.active) do
        if is_active_wildlife(unit) and
            (include_hidden or not dfhack.units.isHidden(unit))
        then
            detach_unit(unit)
        end
    end
end

local function is_onscreen(unit, viewport)
    viewport = viewport or guidm.Viewport.get()
    return viewport:isVisible(xyz2pos(dfhack.units.getPosition(unit))), viewport
end

local function unstick_wildlife(opts)
    local unstuck = {}
    local week_ago_ticks = math.max(0, df.global.cur_year_tick - TICKS_PER_WEEK)
    local viewport
    for _,unit in ipairs(df.global.world.units.active) do
        if not is_active_wildlife(unit) or unit.animal.leave_countdown > 0 then
            goto skip
        end
        if unit.flags1.caged or unit.flags1.chained then
            goto skip
        end
        if not check_timeout(opts, unit, week_ago_ticks) then
            goto skip
        end
        local pop = unit.animal.population
        local unstuck_entry = ensure_key(unstuck, to_key(pop), {race=unit.race, pop=pop, known=false, count=0})
        unstuck_entry.known = unstuck_entry.known or not dfhack.units.isHidden(unit)
        unstuck_entry.count = unstuck_entry.count + 1
        if not opts.dry_run then
            stuck_creatures[unit.id] = nil
            local unit_is_visible
            unit_is_visible, viewport = is_onscreen(unit, viewport)
            exterminate.killUnit(unit, not unit_is_visible and exterminate.killMethod.DISINTEGRATE or nil)
        end
        ::skip::
    end
    for _,entry in pairs(unstuck) do
        refund_population(entry)
    end
    print_summary(opts, unstuck)
end

if dfhack_flags.module then
    return
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('needs a loaded fortress map to work')
end

local opts = {
    dry_run=false,
    help=false,
    quiet=false,
    week=false,
}

local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler = function() opts.help = true end},
    {'n', 'dry-run', handler = function() opts.dry_run = true end},
    {'w', 'week', handler = function() opts.week = true end},
    {'q', 'quiet', handler = function() opts.quiet = true end},
})

if positionals[1] == 'help' or opts.help then
    print(dfhack.script_help())
    return
end

if positionals[1] == 'ignore' then
    local unit
    local unit_id = positionals[2] and argparse.nonnegativeInt(positionals[2], 'unit_id')
    if unit_id then
        unit = df.unit.find(unit_id)
    else
        unit = dfhack.gui.getSelectedUnit(true)
    end
    if not unit then
        qerror('please select a unit or pass a unit ID on the commandline')
    end
    if not is_active_wildlife(unit) then
        qerror('selected unit is not blocking new waves of wildlife; nothing to do')
    end
    detach_unit(unit)
    if not opts.quiet then
        print(('%s will now be ignored by fix/wildlife'):format(dfhack.units.getReadableName(unit)))
    end
else
    unstick_wildlife(opts)
end
