-- handles automatic justice interviews and convictions
-- autojustice [enable | disable]

--@enable = true
--@module = true

--================
-- Constants
--================
local GLOBAL_KEY = 'autojustice'
local UNIT_NEW_ACTIVE_DELAY = 100
local CRIME_REFRESH_DELAY = 120

--TODO: map other claim types
local claimType = {
    accuses = 0,
    confessed = 5,
    implicates = 6
}

local punishmentType = {
    none = 0,
    jail = 1,
    beat = 2,
    hammer = 3
}

--================
-- Imports
--================
local json = require('json')
local argparse = require('argparse')
local persist = require('persist-table')
local repeatUtil = require('repeat-util')
local eventful = require('plugins.eventful')

--================
-- Globals
--================
local args = {...}

enabled = enabled or false

punishmentMode = {
    citizen = punishmentType.jail,
    visitor = punishmentType.hammer
}

local lastCrimeCount = 0
local openCrimes = nil
local openCrimesWitnessCount = nil
local undiscoveredCrimes = nil
local confessedCrimes = nil

--================
-- Module
--================
function isEnabled()
    return enabled
end

--================
-- Persistence
--================
function saveState()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({
        enabled = enabled or false,
        citizenPunishment = punishmentMode.citizen,
        visitorPunishment = punishmentMode.visitor
    })
end

function loadState ()
    local data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '{}')

    enabled = data.enabled or false
    punishmentMode.citizen = data.citizenPunishment or punishmentType.jail
    punishmentMode.visitor = data.visitorPunishment or punishmentType.hammer
end

--================
-- Service / Initialization
--================
function serviceToggle ()
    if dfhack_flags.enable_state then
        serviceEnable()
        print('autojustice is running')
    else
        serviceDisable()
        print('autojustice has stopped')
    end
end

function serviceEnable ()
    enabled = true
    saveState()

    initValues()
    registerEvents()
end

function serviceDisable ()
    clearEvents()
    clearValues()

    enabled = false
    saveState()
end

function runScript ()
    if not dfhack.isMapLoaded() then
        qerror('This script requires a fortress map to be loaded')
        return
    end

    loadState()

    if (#args > 0) then
        loadArgs()
        saveState()
    end


    if enabled then
        serviceEnable()
    end
end

function loadArgs ()
    argparse.processArgsGetopt(args, {
        {'c', 'citizen', hasArg=true, handler=function(arg) punishmentMode.citizen = parsePunishmentArg(punishmentMode.citizen, arg) end},
        {'v', 'visitor', hasArg=true, handler=function(arg) punishmentMode.visitor = parsePunishmentArg(punishmentMode.visitor, arg) end},
    })
end

function parsePunishmentArg (default, arg)
    if arg == 'none' then
        return punishmentType.none
    end

    if arg == 'jail' then
        return punishmentType.jail
    end

    if arg == 'beat' then
        return punishmentType.beat
    end

    if arg == 'hammer' then
        return punishmentType.hammer
    end

    return default
end

function registerEvents ()
    eventful.enableEvent(eventful.eventType.UNIT_NEW_ACTIVE, UNIT_NEW_ACTIVE_DELAY)
    eventful.onUnitNewActive[GLOBAL_KEY] = onUnitNewActive

    repeatUtil.scheduleEvery(GLOBAL_KEY, CRIME_REFRESH_DELAY, 'ticks', onRefresh)
end

function clearEvents ()
    dfhack.onStateChange[GLOBAL_KEY] = nil
    eventful.onUnitNewActive[GLOBAL_KEY] = nil
    repeatUtil.cancel(GLOBAL_KEY)
end

function initValues ()
    lastCrimeCount = #df.global.world.crimes.all

    openCrimes = {}
    openCrimesWitnessCount = {}
    undiscoveredCrimes = {}
    confessedCrimes = {}

    for i, crime in ipairs (df.global.world.crimes.all) do
        addNewCrime(crime)
    end
end

function clearValues ()
    lastCrimeCount = 0

    openCrimes = nil
    openCrimesWitnessCount = nil
    undiscoveredCrimes = nil
    confessedCrimes = nil
end

--================
-- DF Crime Data Query
--================
function convictUnit (crime, unit)
    if crime.flags.sentenced then
        return false
    end

    crime.convicted_hf = unit.hist_figure_id
    crime.convicted_hf_2 = unit.hist_figure_id
    --crime.convicted_hf_3 = unit.hist_figure_id -- this value is not set by the game

    -- TODO: Not sure why the game fill this vector. Need to investigate if the convict and victim is always equal and if it has only one entry
    if #crime.convict_data.unk_v47_vector_1 > 0 then
        local convict = crime.convict_data.unk_v47_vector_1[0]
        crime.victim_data.unk_v47_vector_2:insert(#crime.victim_data.unk_v47_vector_2, convict)
    end

    crime.convict_data.convicted = unit.id
    crime.flags.sentenced = false

    return true
end

function scheduleInterview (crime, unit)
    if isScheduled(crime, unit.hist_figure_id) or not canInterview(unit) then
        return false
    end

    local report = df.crime.T_reports:new()
    report.accused_id = unit.hist_figure_id
    report.accused_id_2 = unit.hist_figure_id

    crime.reports:insert(#crime.reports, report)

    return true
end

function scheduleduleInterviewUnits (crime, units)
    for i, unit in ipairs (units) do
        scheduleInterview(crime, unit)
    end
end

function getUnitPunishmentType (unit, mode)
    --TODO: Not sure how to check long term resident or others that asked to join
    if dfhack.units.isCitizen(unit, true) then
        return mode.citizen
    end

    return mode.visitor
end

function getCrimePunishmentType (crime)
    if crime.punishment.hammerstrikes > 0 then
        return punishmentType.hammer
    end

    if crime.punishment.give_beating > 0 then
        return punishmentType.beat
    end

    if crime.punishment.prison_time > 0 then
        return punishmentType.jail
    end

    return punishmentType.none
end

function skipConviction (crime, unit, mode)
    return getCrimePunishmentType(crime) > getUnitPunishmentType(unit, mode)
end

function isScheduled (crime, hist_figure_id)
    for i, report in ipairs (crime.reports) do
        if report.accused_id == hist_figure_id then
            return true
        end
    end
    return false
end

function didInterview (crime, hist_figure_id)
    for i, report in ipairs (crime.counterintelligence) do
        if report.identified_hf == hist_figure_id then
            return true
        end
    end
    return false
end

function canInterview(unit)
    return dfhack.units.isActive(unit) and
        unit.status.current_soul and
        not dfhack.units.isAnimal(unit)
end

function isOpenCrime (crime, siteId)
    return crime.site == siteId and
        crime.flags.discovered and
        not crime.flags.sentenced
end

function isUndiscoveredCrime (crime, siteId)
    return crime.site == siteId and
        not crime.flags.discovered
end

function getOpenCrimes (crimes, siteId)
    local r = {}

    for i, crime in ipairs (crimes) do
        if isOpenCrime(crime, siteId) then
            table.insert(r, crime)
        end
    end

    return r
end

function getConfessedUnit (crime)
    for i, witness in ipairs (crime.witnesses) do
        if witness.witness_claim == claimType.confessed then
            return df.unit.find(witness.witness_id)
        end
    end
    return nil
end

function getAccusedUnit (crime)
    for i, witness in ipairs (crime.witnesses) do
        if witness.witness_claim == claimType.accuses or
            witness.witness_claim == claimType.implicates then
            return df.unit.find(witness.accused_id)
        end
    end
    return nil
end

function hasConfessed (crime, unit)
    local confessed = getConfessedUnit(crime)
    return confessed ~= nil and confessed.hist_figure_id == unit.hist_figure_id
end

function isAccused (crime, unit)
    local accused = getAccusedUnit(crime)
    return accused ~= nil and accused.hist_figure_id == unit.hist_figure_id
end

function findRelatedCrimes (crimes, unit)
    local r = {}

    for i, crime in ipairs (crimes) do
        if didInterview(crime, unit.hist_figure_id) then
            table.insert(r, crime)
        end
    end

    return r
end

function tryConvictUnit (crime, unit, mode)
    if crime.flags.sentenced or unit == nil then
        return false
    end

    if skipConviction(crime, unit, mode) then
        return true
    end

    return convictUnit(crime, unit)
end

function trySolveCrime (crime, mode)
    if crime.flags.sentenced or #crime.witnesses == 0 then
        return false
    end

    local unit = getConfessedUnit(crime)
    if (unit == nil) then
        return false
    end

    if skipConviction(crime, unit, mode) then
        return true
    end

    return convictUnit(crime, unit)
end

--================
-- Crime Handling
--================
function getSiteId ()
    return df.global.world.world_data.active_site[0].id
end

function getInterviewCrime ()
    return openCrimes[1]    -- Lua starts its index at 1? What?
end

function addNewCrimes ()
    local newCount = #df.global.world.crimes.all
    if lastCrimeCount == newCount then
        return
    end

    for i = lastCrimeCount, newCount - 1 do
        addNewCrime(df.global.world.crimes.all[i])
    end

    lastCrimeCount = newCount
end

function addNewCrime (crime)
    if isOpenCrime(crime, getSiteId()) then
        addOpenCrime(crime)
        return
    end

    if isUndiscoveredCrime(crime, getSiteId()) then
        addUndiscoveredCrime(crime)
        return
    end
end

function addOpenCrime (crime)
    local confessed = getConfessedUnit(crime)
    if confessed ~= nil then
        if not tryConvictUnit(crime, confessed, punishmentMode) then
            table.insert(confessedCrimes, crime)
        end
    else
        table.insert(openCrimes, crime)
        table.insert(openCrimesWitnessCount, 0)
    end
end

function addUndiscoveredCrime (crime, siteId)
    table.insert(undiscoveredCrimes, crime)
end

function updateUndiscoveredCrimes ()
    local siteId = getSiteId()

    for i = #undiscoveredCrimes, 1, -1 do
        local crime = undiscoveredCrimes[i]

        if isOpenCrime(crime, siteId) then
            local confessed = getConfessedUnit(crime)
            if confessed ~= nil then
                if not tryConvictUnit(crime, confessed, punishmentMode) then
                    table.insert(confessedCrimes, crime)
                end
            else
                table.insert(openCrimes, crime)
                table.insert(openCrimesWitnessCount, 0)
            end

            -- This is not an undiscovered crime anymore
            table.remove(undiscoveredCrimes, i)
        end
    end
end

function updateOpenCrimes ()
    --TODO: limit the number of iterations per refresh
    for i = #openCrimes, 1, -1 do
        updateOpenCrime(openCrimes[i], i)
    end
end

function updateOpenCrime (crime, index)
    -- Check if the crime is still open
    if crime.flags.sentenced then
        table.remove(openCrimes, index)
        table.remove(openCrimesWitnessCount, index)
        return
    end

    -- Only recheck if we have new witnesses
    if openCrimesWitnessCount[index] == #crime.witnesses then
        return
    end
    openCrimesWitnessCount[index] = #crime.witnesses

    -- Try to convict confessed or interview accused
    local confessed = getConfessedUnit(crime)
    if confessed ~= nil then
        if not tryConvictUnit(crime, confessed, punishmentMode) then
            table.insert(confessedCrimes, crime)
        end

        -- Someone confessed, this is not an open crime anymore
        table.remove(openCrimes, index)
        table.remove(openCrimesWitnessCount, index)
    else
        local accused = getAccusedUnit(crime)
        if accused ~= nil then
            scheduleInterview(crime, accused)
        end
    end
end

function updateConfessedCrimes ()
    for i = #confessedCrimes, 1, -1 do
        local crime = confessedCrimes[i]
        local confessed = getConfessedUnit(crime)
        if confessed ~= nil and tryConvictUnit(crime, confessed, punishmentMode) then
            table.remove(confessedCrimes, i)
        end
    end
end

function convictConfessed (unit)
    for i = #confessedCrimes, 1, -1 do
        local crime = confessedCrimes[i]
        if hasConfessed(crime, unit) and tryConvictUnit(crime, unit, punishmentMode) then
            table.remove(confessedCrimes, i)
        end
    end
end

function scheduleAccused (unit)
    for i = #openCrimes, 1, -1 do
        local crime = openCrimes[i]
        if isAccused(crime, unit) then
            scheduleInterview(crime, unit)
        end
    end
end

function onUnitNewActive (unitId)
    local unit = df.unit.find(unitId)
    if unit == nil then
        return
    end

    local crime = getInterviewCrime()
    if crime ~= nil then
        if scheduleInterview(crime, unit) then
        end
    end

    convictConfessed(unit)
    scheduleAccused(unit)
end

function onRefresh ()
    addNewCrimes()
    updateUndiscoveredCrimes()
    updateOpenCrimes()
    updateConfessedCrimes()
end

function main ()
    if dfhack_flags.enable then
        serviceToggle()
    else
        runScript()
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    loadState()

    if enabled then
        serviceEnable()
    end
end

if not dfhack_flags.module then
    main()
end