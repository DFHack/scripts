-- Based on the original code by RNGStrategist (who also got some help from Uncle Danny)
--@ enable = true
--@ module = true

local repeatUtil = require('repeat-util')
local utils=require('utils')

local GLOBAL_KEY  = "autotraining"
local MartialTraining = df.need_type['MartialTraining']
local ignore_count = 0

local function get_default_state()
    return {
        enabled=false,
        threshold=-5000,
        ignored={},
        ignored_nobles={},
        training_squads = {},
    }
end

state = state or get_default_state()

function isEnabled()
    return state.enabled
end

-- persisting a table with numeric keys results in a json array with a huge number of null entries
-- therefore, we convert the keys to strings for persistence
local function to_persist(persistable)
    local persistable_ignored = {}
    for k, v in pairs(persistable) do
        persistable_ignored[tostring(k)] = v
    end
    return persistable_ignored
end

-- loads both from the older array format and the new string table format
local function from_persist(persistable)
    if not persistable then
        return
    end
    local ret = {}
    for k, v in pairs(persistable) do
        ret[tonumber(k)] = v
    end
    return ret
end

function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=state.enabled,
        threshold=state.threshold,
        ignored=to_persist(state.ignored),
        ignored_nobles=state.ignored_nobles,
        training_squads=to_persist(state.training_squads)
    })
end

--- Load the saved state of the script
local function load_state()
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    state.enabled = persisted_data.enabled or state.enabled
    state.threshold = persisted_data.threshold or state.threshold
    state.ignored = from_persist(persisted_data.ignored) or state.ignored
    state.ignored_nobles = persisted_data.ignored_nobles or state.ignored_nobles
    state.training_squads = from_persist(persisted_data.training_squads) or state.training_squads
    return state
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        state.enabled = false
        return
    end
    -- the state changed, is a map loaded and is that map in fort mode?
    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        -- no its isnt, so bail
        return
    end
    -- yes it was, so:

    -- retrieve state saved in game. merge with default state so config
    -- saved from previous versions can pick up newer defaults.
    load_state()
    if state.enabled then
        start()
    end
    persist_state()
end


--######
--Functions
--######
local function isIgnoredNoble(unit)
    local noblePos = dfhack.units.getNoblePositions(unit)
    if noblePos ~= nil then
        for _, position in ipairs(noblePos) do
            if state.ignored_nobles[position.position.code] then
                return true
            end
        end
    end
    return false
end

---@return table<integer, { ['unit']: df.unit, ['need']: integer }>
function getTrainingCandidates()
    local ret = {}
    ignore_count = 0
    for _, unit in ipairs(dfhack.units.getCitizens(true)) do
        if not dfhack.units.isAdult(unit) then
            goto next_unit
        end
        local need = getTrainingNeed(unit)
        if not need or need.focus_level >= state.threshold  then
            goto next_unit
        end
        -- ignored units are those that would like to train but are forbidden from doing so
        if state.ignored[unit.id] then
            ignore_count = ignore_count + 1
            goto next_unit
        end
        if isIgnoredNoble(unit) then
            ignore_count = ignore_count + 1
            goto next_unit
        end
        if unit.military.squad_id ~= -1 then
            goto next_unit
        end
        table.insert(ret, { unit = unit, need = need.focus_level })
        ::next_unit::
    end
    table.sort(ret, function (a, b) return a.need < b.need end)
    return ret
end

function getTrainingSquads()
    local squads = {}
    for squad_id, active in pairs(state.training_squads) do
        local squad = df.squad.find(squad_id)
        if active and squad then
            table.insert(squads, squad)
        else
            -- setting to nil during iteration is permitted by lua
            state.training_squads[squad_id] = nil
        end
    end
    return squads
end

function getTrainingNeed(unit)
    if unit == nil then return nil end
    local needs =  unit.status.current_soul.personality.needs
    for _, need in ipairs(needs) do
        if need.id == MartialTraining then
            return need
        end
    end
    return nil
end

--######
--Main
--######

-- Find all training squads
-- Abort if no squads found
function checkSquads()
    local squads = {}
    for _, squad in ipairs(getTrainingSquads()) do
        if squad.entity_id == df.global.plotinfo.group_id then
            local leader = squad.positions[0].occupant
            if leader ~= -1 then
                table.insert(squads,squad)
            end
        end
    end

    if #squads == 0 then
        return nil
    end

    return squads
end

function addTraining(unit,good_squads)
    if unit.military.squad_id ~= -1 then
        for _, squad in ipairs(good_squads) do
            if unit.military.squad_id == squad.id then
                return true
            end
        end
        return false
    end
    for _, squad in ipairs(good_squads) do
        for i=1,9,1   do
            if squad.positions[i].occupant  == -1 then
                return dfhack.military.addToSquad(unit.id,squad.id,i)
            end
        end
    end

    return false
end

function removeAll()
    if state.training_squads == nil then return end
    for _, squad in ipairs(getTrainingSquads()) do
        for i=1,9,1 do
            local hf = df.historical_figure.find(squad.positions[i].occupant)
            if hf ~= nil then
                dfhack.military.removeFromSquad(hf.unit_id)
            end
        end
    end
end


function check()
    local squads = checkSquads()
    local intraining_count = 0
    local inque_count = 0
    if squads == nil then return end
    for _,squad in ipairs(squads) do
        for i=1,9,1   do
            if squad.positions[i].occupant  ~= -1 then
                local hf = df.historical_figure.find(squad.positions[i].occupant)
                if hf ~= nil then
                    local unit = df.unit.find(hf.unit_id)
                    local training_need = getTrainingNeed(unit)
                    if not training_need or training_need.focus_level >= state.threshold then
                        dfhack.military.removeFromSquad(unit.id)
                    end
                end
            end
        end
    end
    for _, p in ipairs(getTrainingCandidates()) do
        local added = addTraining(p.unit, squads)
        if added then
            intraining_count = intraining_count +1
        else
            inque_count = inque_count +1
        end
    end
    print(("%s: %d training, %d waiting, and %d excluded units with training needs"):
        format(GLOBAL_KEY, intraining_count, inque_count, ignore_count))
end

function start()
    repeatUtil.scheduleEvery(GLOBAL_KEY, 1, 'days', check)
end

function stop()
    repeatUtil.cancel(GLOBAL_KEY)
end

function enable()
    state.enabled = true
    persist_state()
    start()
end

function disable()
    state.enabled = false
    persist_state()
    stop()
    removeAll()
end

if dfhack_flags.module then
    return
end

validArgs = utils.invert({
    't'
})

local args = utils.processArgs({...}, validArgs)

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        enable()
    else
        disable()
    end
else
    -- called on the command-line
    if args.t then
        state.threshold = 0-tonumber(args.t)
    end
    print(("autotraining is %s"):format(state.enabled and "enabled" or "disabled"))
end
