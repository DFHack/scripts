
--@enable = true
--@module = true

local utils = require 'utils'
local repeatutil = require("repeat-util")

local verbose = false
---conditional printing of debug messages
---@param message string
local function debug(message)
    if verbose then
        print(message)
    end
end

-- From workorder.lua
---------------------------8<-----------------------------

local function isValidAnimal(unit)
    -- this should also check for the absence of misc trait 55 (as of 50.09), but we don't
    -- currently have an enum definition for that value yet
    return  dfhack.units.isOwnCiv(unit)
        and dfhack.units.isAlive(unit)
        and dfhack.units.isAdult(unit)
        and dfhack.units.isActive(unit)
        and dfhack.units.isFortControlled(unit)
        and dfhack.units.isTame(unit)
        and not dfhack.units.isMarkedForSlaughter(unit)
        and not dfhack.units.getMiscTrait(unit, df.misc_trait_type.Migrant, false)
end

-- true/false or nil if no shearable_tissue_layer with length > 0.
local function canShearCreature(unit)
    local stls = df.global.world.raws.creatures
        .all[unit.race]
        .caste[unit.caste]
        .shearable_tissue_layer

    local any
    for _, stl in ipairs(stls) do
        if stl.length > 0 then
            for _, bpi in ipairs(stl.bp_modifiers_idx) do
                any = { unit.appearance.bp_modifiers[bpi], stl.length }
                if unit.appearance.bp_modifiers[bpi] >= stl.length then
                    return true, any
                end
            end
        end
    end

    if any then return false, any end
    -- otherwise: nil
end

---------------------------8<-----------------------------

local function canMilkCreature(u)
    if dfhack.units.isMilkable(u) and not dfhack.units.isPet(u) then
        local mt_milk = dfhack.units.getMiscTrait(u, df.misc_trait_type.MilkCounter, false)
        if not mt_milk then return true else return false end
    else
        return nil
    end
end

---@param p1 df.coord
---@param p2 df.coord
---@return number
function distance(p1, p2)
    return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y)) + 2 * math.abs(p1.z - p2.z)
end

---find appropriate workshop to milk or shear an animal
---@param unit df.unit
---@param collection table<integer,df.building_workshopst>
---@return df.building_workshopst?
local function getAppropriateWorkshop(unit, collection)
    local zone_ref = dfhack.units.getGeneralRef(unit, df.general_ref_type.BUILDING_CIVZONE_ASSIGNED)
    local zone = zone_ref and zone_ref:getBuilding() or nil

    -- if animal is assigned to a zone containing workshops, only use those
    if zone then
        local contains_workshop = false
        local best = nil
        local worst_load = 10
        for _, workshop in pairs(collection[zone.z] or {}) do
            if dfhack.buildings.containsTile(zone, workshop.centerx, workshop.centery) then
                contains_workshop = true
                local workshop_pos = xyz2pos(workshop.centerx, workshop.centery, workshop.z)
                if dfhack.maps.canWalkBetween(unit.pos, workshop_pos) and #workshop.jobs < worst_load then
                    worst_load = #workshop.jobs
                    best = workshop
                end
            end
        end
        if contains_workshop or state.pasture then
            return best
        end
    elseif not state.roaming then
        return nil -- not treating roaming animals
    end
    -- otherwise, use the closest workshop to the animal
    local closest = nil
    local dist = nil
    for _, level in pairs(collection) do
        for _, workshop in pairs(level) do
            local workshop_pos = xyz2pos(workshop.centerx, workshop.centery, workshop.z)
            if dfhack.maps.canWalkBetween(unit.pos, workshop_pos) then
                local d = distance(unit.pos, workshop_pos)
                if not closest or d < dist then
                    closest = workshop
                    dist = d
                end
            end
        end
    end
    return (closest and #closest.jobs < 10) and closest or nil
end

local function shearCreature(unit, workshop)
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.ShearCreature
    dfhack.job.addGeneralRef(job, df.general_ref_type.UNIT_SHEAREE, unit.id)
    dfhack.job.assignToWorkshop(job, workshop)
end

local function milkCreature(unit, workshop)
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.MilkCreature
    dfhack.job.addGeneralRef(job, df.general_ref_type.UNIT_MILKEE, unit.id)
    dfhack.job.assignToWorkshop(job, workshop)
end


-- configuration management

GLOBAL_KEY = 'husbandry'

local function get_default_state()
    return {
        enabled = false,
        milking = true,
        shearing = true,
        roaming = true;
        pasture = false
    }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=state.enabled,
        milking=state.milking,
        shearing=state.shearing,
        roaming=state.roaming,
        pasture=state.pasture,
    })
end

--- Load the saved state of the script
local function load_state()
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, get_default_state())
    state.enabled = persisted_data.enabled
    state.milking = persisted_data.milking
    state.shearing = persisted_data.shearing
    state.roaming = persisted_data.roaming
    state.pasture = persisted_data.pasture
    return state
end

-- main script action

local function action()
    debug('husbandry: running loop')

    -- organize workshops by allowed labors and z-level
    ---@type table<integer,df.building_workshopst[]>
    local farmer_shearing = {}
    ---@type table<integer,df.building_workshopst[]>
    local farmer_milking = {}
    for _, workshop in ipairs(df.global.world.buildings.other.WORKSHOP_FARMER) do
        if not workshop.profile.blocked_labors[df.unit_labor.SHEARER] then
            table.insert(ensure_key(farmer_shearing, workshop.z), workshop)
        end
        if not workshop.profile.blocked_labors[df.unit_labor.MILK] then
            table.insert(ensure_key(farmer_milking, workshop.z), workshop)
        end
    end

    -- gather units that are already being milked or sheared
    ---@type table<integer,boolean>
    local unit_milking = {}
    ---@type table<integer,boolean>
    local unit_shearing = {}

    -- go over all workshops to to catch player-initiated jobs
    for _, workshop in ipairs(df.global.world.buildings.other.WORKSHOP_FARMER) do
        for _, job in ipairs(workshop.jobs) do
            if state.milking and job.job_type == df.job_type.MilkCreature then
                local milkee = dfhack.job.getGeneralRef(job, df.general_ref_type.UNIT_MILKEE)
                if milkee then
                    unit_milking[milkee.unit_id] = true
                end
            elseif state.shearing and job.job_type == df.job_type.ShearCreature then
                local shearee  = dfhack.job.getGeneralRef(job, df.general_ref_type.UNIT_SHEAREE)
                if shearee then
                    unit_shearing[shearee.unit_id] = true
                end
            end
        end
    end

    -- look for units that can be milked/sheared and for which there is no active job
    for _, unit in ipairs(df.global.world.units.active) do
        if not isValidAnimal(unit) then goto skip end

        if state.shearing and canShearCreature(unit) and not unit_shearing[unit.id] then
            local workshop = getAppropriateWorkshop(unit, farmer_shearing)
            if workshop then
                shearCreature(unit, workshop)
            end
        end

        if state.milking and canMilkCreature(unit) and not unit_milking[unit.id] then
            local workshop = getAppropriateWorkshop(unit, farmer_milking)
            if workshop then
                milkCreature(unit, workshop)
            end
        end

        ::skip::
    end
end

-- enable management

local function start()
    if state.enabled then
        repeatutil.scheduleUnlessAlreadyScheduled(GLOBAL_KEY, 1000, 'ticks', action)
    end
end

local function stop()
    repeatutil.cancel(GLOBAL_KEY)
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        state.enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    load_state()
    start()
end

if dfhack_flags.module then
    return
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        state.enabled = true
        start()
    else
        state.enabled = false
        stop()
    end
    persist_state()
    return
end

-- command-line interface

local argparse = require('argparse')
local positionals = argparse.processArgsGetopt({ ... }, {})

local state_vars = utils.invert({ "milking", "shearing", "roaming", "pasture" })

local function setFlags(positionals, value)
    for i = 2, #positionals do
        local flag = positionals[i]
        if state_vars[flag] then
            debug(("setting %s = %s"):format(flag, value))
            state[flag] = value
        end
    end
end

load_state()
if not positionals[1] or positionals[1] == 'status' then
    print(("husbandry is %s"):format(state.enabled and "enabled" or "not enabled"))
    print(("currently %smilking%s%sshearing animals"):format(
        state.milking and "" or "not ",
        state.milking == state.shearing and " and " or " but ",
        state.shearing and "" or "not "))
    print(("%s roaming animals"):format(state.roaming and "including" or "ignoring"))
    if state.pasture then
        print("not milking/shearing animals inside pastures without workshops")
    end
elseif positionals[1] == "set" then
    if positionals[2] == "default" then
        state = get_default_state()
    else
        setFlags(positionals, true)
    end
elseif positionals[1] == "unset" then
    setFlags(positionals, false)
elseif positionals[1] == "now" then
    action()
else
    qerror("unrecognized option")
end
persist_state()
