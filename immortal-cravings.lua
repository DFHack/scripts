--@enable = true
--@module = true

local repeatutil = require("repeat-util")

--- utility functions

local verbose = false
---conditional printing of debug messages
---@param message string
local function debug(message)
    if verbose then
        print(message)
    end
end

---3D city metric
---@param p1 df.coord
---@param p2 df.coord
---@return number
function distance(p1, p2)
    return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y)) + math.abs(p1.z - p2.z)
end

---maybe a candidate for utils.lua?
---find best available item in an item vector (according to some metric)
---@generic T : df.item
---@param item_vector T[]
---@param metric fun(item: T): number?
---@return T?
function findBest(item_vector, metric, smallest)
    local best = nil
    local mbest = nil
    for _, item in ipairs(item_vector) do
        mitem = metric(item)
        if mitem and (not best or (smallest and mitem < mbest or mitem > mbest)) then
            best = item
            mbest = mitem
        end
    end
    return best
end

---find closest accessible item in an item vector
---@generic T : df.item
---@param pos df.coord
---@param item_vector T[]
---@param is_good? fun(item: T): boolean
---@return T?
local function findClosest(pos, item_vector, is_good)
    local function metric(item)
        if not is_good or is_good(item) then
            local pitem = xyz2pos(dfhack.items.getPosition(item))
            return dfhack.maps.canWalkBetween(pos, pitem) and distance(pos, pitem) or nil
        end
        return nil
    end
    return findBest(item_vector, metric, true)
end

---find a drink
---@param pos df.coord
---@return df.item_drinkst?
local function get_closest_drink(pos)
    local is_good = function (drink)
        local container = dfhack.items.getContainer(drink)
        return not drink.flags.in_job and container and container:isFoodStorage()
    end
    return findClosest(pos, df.global.world.items.other.DRINK, is_good)
end

---find available meal with highest per-portion value
---@return df.item_foodst?
local function get_best_meal(pos)

    ---@param meal df.item_foodst
    local function portion_value(meal)
        local accessible = dfhack.maps.canWalkBetween(pos,xyz2pos(dfhack.items.getPosition(meal)))
        if meal.flags.in_job or meal.flags.rotten or not accessible then
            return nil
        else
            -- check that meal is either on the ground or in food storage (and not in a backpack)
            local container = dfhack.items.getContainer(meal)
            if not container or container:isFoodStorage() then
                return dfhack.items.getValue(meal) / meal.stack_size
            else
                return nil
            end
        end
    end

    return findBest(df.global.world.items.other.FOOD, portion_value)
end

---create a Drink job for the given unit
---@param unit df.unit
local function goDrink(unit)
    local drink = get_closest_drink(unit.pos)
    if not drink then
        -- print('no accessible drink found')
        return
    end
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.DrinkItem
    job.flags.special = true
    local dx, dy, dz = dfhack.items.getPosition(drink)
    job.pos = xyz2pos(dx, dy, dz)
    if not dfhack.job.attachJobItem(job, drink, df.job_role_type.Other, -1, -1) then
        error('could not attach drink')
        return
    end
    dfhack.job.addWorker(job, unit)
    local name = dfhack.units.getReadableName(unit)
    print(dfhack.df2console('immortal-cravings: %s is getting a drink'):format(name))
end

---create Eat job for the given unit
---@param unit df.unit
local function goEat(unit)
    local meal_stack = get_best_meal(unit.pos)
    if not meal_stack then
        -- print('no accessible meals found')
        return
    end

    ---@type df.item|df.item_foodst
    local meal
    if meal_stack.stack_size > 1 then
        meal = meal_stack:splitStack(1, true)
        meal:categorize(true)
    else
        meal = meal_stack
    end
    dfhack.items.setOwner(meal, unit)

    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.Eat
    job.flags.special = true
    local dx, dy, dz = dfhack.items.getPosition(meal)
    job.pos = xyz2pos(dx, dy, dz)
    if not dfhack.job.attachJobItem(job, meal, df.job_role_type.Other, -1, -1) then
        error('could not attach meal')
        return
    end
    dfhack.job.addWorker(job, unit)
    local name = dfhack.units.getReadableName(unit)
    print(dfhack.df2console('immortal-cravings: %s is getting something to eat'):format(name))
end

--- script logic

local GLOBAL_KEY = 'immortal-cravings'

enabled = enabled or false
function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=enabled,
    })
end

--- Load the saved state of the script
local function load_state()
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = persisted_data.enabled or false
end

DrinkAlcohol = df.need_type.DrinkAlcohol
EatGoodMeal = df.need_type.EatGoodMeal

---@type integer[]
watched = watched or {}

local threshold = -9000

---unit loop: check for idle watched units and create eat/drink jobs for them
local function unit_loop()
    debug(('immortal-cravings: running unit loop (%d watched units)'):format(#watched))
    ---@type integer[]
    local kept = {}
    for _, unit_id in ipairs(watched) do
        local unit = df.unit.find(unit_id)
        if
            not unit or not dfhack.units.isActive(unit) or
            unit.flags1.caged or unit.flags1.chained
        then
            goto next_unit
        end
        if not dfhack.units.isJobAvailable(unit) then
            debug("immortal-cravings: skipping busy"..dfhack.units.getReadableName(unit))
            table.insert(kept, unit.id)
        else
            -- unit is available for jobs; satisfy one of its needs
            for _, need in ipairs(unit.status.current_soul.personality.needs) do
                if need.id == DrinkAlcohol and need.focus_level < threshold then
                    goDrink(unit)
                    break
                elseif need.id == EatGoodMeal and need.focus_level < threshold then
                    goEat(unit)
                    break
                end
            end
        end
        ::next_unit::
    end
    watched = kept
    if #watched == 0 then
        debug('immortal-cravings: no more watched units, cancelling unit loop')
        repeatutil.cancel(GLOBAL_KEY .. '-unit')
    end
end

local function is_active_caste_flag(unit, flag_name)
    return not unit.uwss_remove_caste_flag[flag_name] and
        (unit.uwss_add_caste_flag[flag_name] or dfhack.units.casteFlagSet(unit.race, unit.caste, df.caste_raw_flags[flag_name]))
end

---main loop: look for citizens with personality needs for food/drink but w/o physiological need
local function main_loop()
    debug('immortal-cravings watching:')
    watched = {}
    for _, unit in ipairs(dfhack.units.getCitizens(false, false)) do
        if
            (is_active_caste_flag(unit, 'NO_DRINK') or is_active_caste_flag(unit, 'NO_EAT')) and
            unit.counters2.stomach_content == 0 and
            dfhack.units.getFocusPenalty(unit, DrinkAlcohol, EatGoodMeal) < threshold
        then
            table.insert(watched, unit.id)
            debug('  ' .. dfhack.df2console(dfhack.units.getReadableName(unit)))
        end
    end

    if #watched > 0 then
        repeatutil.scheduleUnlessAlreadyScheduled(GLOBAL_KEY..'-unit', 59, 'ticks', unit_loop)
    end
end

local function start()
    if enabled then
        repeatutil.scheduleUnlessAlreadyScheduled(GLOBAL_KEY..'-main', 4003, 'ticks', main_loop)
    end
end

local function stop()
    repeatutil.cancel(GLOBAL_KEY..'-main')
    repeatutil.cancel(GLOBAL_KEY..'-unit')
end



-- script action

--- Handles automatic loading
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        -- repeat-util will cancel the loops on unload
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    load_state()
    start()
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        enabled = true
        start()
    else
        enabled = false
        stop()
    end
    persist_state()
end
