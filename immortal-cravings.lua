--@enable = true
--@module = true

local idle = reqscript('idle-crafting')
local repeatutil = require("repeat-util")
--- utility functions

---3D city metric
---@param p1 df.coord
---@param p2 df.coord
---@return number
function distance(p1, p2)
    return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y)) + math.abs(p1.z - p2.z)
end

---find closest accessible item in an item vector
---@generic T : df.item
---@param pos df.coord
---@param item_vector T[]
---@param is_good? fun(item: T): boolean
---@return T?
local function findClosest(pos, item_vector, is_good)
    local closest = nil
    local dclosest = -1
    for _,item in ipairs(item_vector) do
        if not item.flags.in_job and (not is_good or is_good(item)) then
            local pitem = xyz2pos(dfhack.items.getPosition(item))
            local ditem = distance(pos, pitem)
            if dfhack.maps.canWalkBetween(pos, pitem) and (not closest or ditem < dclosest) then
                closest = item
                dclosest = ditem
            end
        end
    end
    return closest
end

---find a drink
---@param pos df.coord
---@return df.item_drinkst?
local function get_closest_drink(pos)
    local is_good = function (drink)
        local container = dfhack.items.getContainer(drink)
        return container and container:isFoodStorage()
    end
    return findClosest(pos, df.global.world.items.other.DRINK, is_good)
end

---find some prepared meal
---@return df.item_foodst?
local function get_closest_meal(pos)
    ---@param meal df.item_foodst
    local function is_good(meal)
        if meal.flags.rotten then
            return false
        else
            local container = dfhack.items.getContainer(meal)
            return not container or container:isFoodStorage()
        end
    end
    return findClosest(pos, df.global.world.items.other.FOOD, is_good)
end

---create a Drink job for the given unit
---@param unit df.unit
local function goDrink(unit)
    local drink = get_closest_drink(unit.pos)
    if not drink then
        -- print('no accessible drink found')
        return
    end
    local job = idle.make_job()
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
    local meal = get_closest_meal(unit.pos)
    if not meal then
        -- print('no accessible meals found')
        return
    end
    local job = idle.make_job()
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
    -- print(('immortal-cravings: running unit loop (%d watched units)'):format(#watched))
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
        if not idle.unitIsAvailable(unit) then
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
        -- print('immortal-cravings: no more watched units, cancelling unit loop')
        repeatutil.cancel(GLOBAL_KEY .. '-unit')
    end
end

local function is_active_caste_flag(unit, flag_name)
    return not unit.uwss_remove_caste_flag[flag_name] and
        (unit.uwss_add_caste_flag[flag_name] or dfhack.units.casteFlagSet(unit.race, unit.caste, df.caste_raw_flags[flag_name]))
end

---main loop: look for citizens with personality needs for food/drink but w/o physiological need
local function main_loop()
    -- print('immortal-cravings watching:')
    watched = {}
    for _, unit in ipairs(dfhack.units.getCitizens()) do
        if not is_active_caste_flag(unit, 'NO_DRINK') and not is_active_caste_flag(unit, 'NO_EAT') then
            goto next_unit
        end
        for _, need in ipairs(unit.status.current_soul.personality.needs) do
            if need.id == DrinkAlcohol and need.focus_level < threshold or
                need.id == EatGoodMeal and need.focus_level < threshold
            then
                table.insert(watched, unit.id)
                -- print('  '..dfhack.df2console(dfhack.units.getReadableName(unit)))
                goto next_unit
            end
        end
        ::next_unit::
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
