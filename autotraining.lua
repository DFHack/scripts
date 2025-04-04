-- Based on the original code by RNGStrategist (who also got some help from Uncle Danny)
--@ enable = true
--@ module = true

local repeatUtil = require('repeat-util')
local utils=require('utils')

validArgs = utils.invert({
    't'
})

local args = utils.processArgs({...}, validArgs)
local GLOBAL_KEY  = "autotraining"
local need_id = df.need_type['MartialTraining']
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
    -- the state changed, is a map loaded and is that map in fort mode?
    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        -- no its isnt, so bail
        return
    end
    -- yes it was, so:

    -- retrieve state saved in game. merge with default state so config
    -- saved from previous versions can pick up newer defaults.
    load_state()
    if ( state.enabled ) then
        start()
    else
        stop()
    end
    -- start can change the enabled state if the squad cant be found
    if state.enabled then
        dfhack.print(GLOBAL_KEY .." was persisted with the following data:\nThreshold: ".. state.threshold .. '\n')
    end
    persist_state()
end


--######
--Functions
--######
function getTrainingCandidates()
    local ret = {}
    local citizen = dfhack.units.getCitizens(true)
    ignore_count = 0
    for _, unit in ipairs(citizen) do
        if dfhack.units.isAdult(unit) then
            local noblePos = dfhack.units.getNoblePositions(unit)
            local isIgnNoble = false
            if ( not state.ignored[unit.id] ) then
                if noblePos ~=nil then
                    for _, position in ipairs(noblePos) do
                        if state.ignored_nobles[position.position.code] then
                            isIgnNoble = true
                            break
                        end
                    end
                end
                if not isIgnNoble then
                    table.insert(ret, unit)
                else
                    removeTraining(unit)
                    ignore_count = ignore_count +1
                end
            else
                removeTraining(unit)
                ignore_count = ignore_count +1
            end
        end
    end
    return ret
end

function getTrainingSquads()
    local squads = {}
    for squad_id, _ in pairs(state.training_squads) do
        local squad = df.squad.find(squad_id)
        if squad then
            table.insert(squads, squad)
        else
            -- setting to nil during iteration is permitted by lua
            state.training_squads[squad_id] = nil
        end
    end
    return squads
end

function findNeed(unit)
    local needs =  unit.status.current_soul.personality.needs
    for _, need in ipairs(needs) do
        if need.id == need_id then
            return need
        end
    end
    return nil
end

--######
--Main
--######

function getByID(id)
    for _, unit in ipairs(getTrainingCandidates()) do
        if (unit.hist_figure_id == id) then
            return unit
        end
    end

    return nil
end

-- Find all training squads
-- Abort if no squads found
function checkSquads()
    local squads = {}
    for _, squad in ipairs(getTrainingSquads()) do
        if squad.entity_id == df.global.plotinfo.group_id then
            local leader = squad.positions[0].occupant
            if ( leader ~= -1) then
                table.insert(squads,squad)
            end
        end
    end

    if (#squads == 0) then
        return nil
    end

    return squads
end

function addTraining(unit)
    if (unit.military.squad_id ~= -1) then
        for _, squad in ipairs(getTrainingSquads()) do
            if unit.military.squad_id == squad.id then
                return true
            end
        end
        return false
    end
    for _, squad in ipairs(getTrainingSquads()) do
        for i=1,9,1   do
            if ( squad.positions[i].occupant  == -1 ) then
                dfhack.military.addToSquad(unit.id,squad.id,i)
                -- squad.positions[i].occupant = unit.hist_figure_id
                -- unit.military.squad_id = squad.id
                -- unit.military.squad_position = i
                return true
            end
        end
    end

    return false
end

function removeTraining(unit)
    for _, squad in ipairs(getTrainingSquads()) do
        for i=1,9,1   do
            if ( unit.hist_figure_id  == squad.positions[i].occupant ) then
                dfhack.military.removeFromSquad(unit.id)
                -- unit.military.squad_id = -1
                -- unit.military.squad_position = -1
                -- squad.positions[i].occupant = -1
                return true
            end
        end
    end
    return false
end

function removeAll()
    if ( state.training_squads == nil) then return end
    for _, squad in ipairs(getTrainingSquads()) do
        for i=1,9,1 do
            local dwarf = getByID(squad.positions[i].occupant)
            if (dwarf ~= nil) then
                removeTraining(dwarf)
            end
        end
    end
end


function check()
    local squads = checkSquads()
    local intraining_count = 0
    local inque_count = 0
    if ( squads == nil) then return end
    for _, unit in ipairs(getTrainingCandidates()) do
        local need = findNeed(unit)
        if ( need  ~= nil ) then
            if ( need.focus_level  < state.threshold ) then
                local bol = addTraining(unit)
                if ( bol ) then
                    intraining_count = intraining_count +1
                else
                    inque_count = inque_count +1
                end
            else
                removeTraining(unit)
            end
        end
    end

    dfhack.println(GLOBAL_KEY  .. " | IGN: " .. ignore_count .. " TRAIN: " .. intraining_count .. " QUE: " ..inque_count )
end

function start()
    dfhack.println(GLOBAL_KEY  .. " | START")

    if (args.t) then
        state.threshold = 0-tonumber(args.t)
    end
    repeatUtil.scheduleEvery(GLOBAL_KEY, 1, 'days', check) -- 997 is the closest prime to 1000
end

function stop()
    repeatUtil.cancel(GLOBAL_KEY)
    dfhack.println(GLOBAL_KEY  .. " | STOP")
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        state.enabled = true
    else
        state.enabled = false
    end
    persist_state()
end

if dfhack_flags.module then
    return
end

if ( state.enabled ) then
    start()
    dfhack.println(GLOBAL_KEY  .." | Enabled")
else
    stop()
    dfhack.println(GLOBAL_KEY  .." | Disabled")
end
persist_state()
