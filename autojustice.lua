-- Auto Justice

--@enable = true
--@module = true

local GLOBAL_KEY = 'autojustice'
local UNIT_NEW_ACTIVE_DELAY = 100
local CRIME_REFRESH_DELAY = 120

local json = require('json')
local persist = require('persist-table')
local repeatUtil = require('repeat-util')
local eventful = require('plugins.eventful')
local justice = reqscript('autojustice/justicetools')

enabled = enabled or false

local lastCrimeCount = 0
local openCrimes = nil
local openCrimesWitnessCount = nil
local undiscoveredCrimes = nil
local confessedCrimes = nil

function isEnabled()
    return enabled
end

function saveState()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({
        enabled = enabled or false
    })
end

function loadState ()
    local data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '{}')
    enabled = data.enabled or false
end

function serviceToggle ()
    if dfhack_flags.enable_state then
        serviceEnable()
    else
        serviceDisable()
    end
end

function serviceEnable ()
    saveState()
    initValues()
    registerEvents()

    print('autojustice is running')
end

function serviceDisable ()
    clearEvents()
    clearValues()

    print('autojustice has stopped')
end

function runScript ()
    if not dfhack.isMapLoaded() then
        qerror('This script requires a fortress map to be loaded')
        return
    end

    -- TODO: Set possible variables here
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
    if justice.isOpenCrime(crime, getSiteId()) then
        addOpenCrime(crime)
        return
    end

    if justice.isUndiscoveredCrime(crime, getSiteId()) then
        addUndiscoveredCrime(crime)
        return
    end
end

function addOpenCrime (crime)
    local confessed = justice.getConfessedUnit(crime)
    if confessed ~= nil then
        if not justice.tryConvictUnit(crime, confessed) then
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

        if justice.isOpenCrime(crime, siteId) then
            local confessed = justice.getConfessedUnit(crime)
            if confessed ~= nil then
                if not justice.tryConvictUnit(crime, confessed) then
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
    local confessed = justice.getConfessedUnit(crime)
    if confessed ~= nil then
        if not justice.tryConvictUnit(crime, confessed) then
            table.insert(confessedCrimes, crime)
        end

        -- Someone confessed, this is not an open crime anymore
        table.remove(openCrimes, index)
        table.remove(openCrimesWitnessCount, index)
    else
        local accused = justice.getAccusedUnit(crime)
        if accused ~= nil then
            justice.scheduleInterview(crime, accused)
        end
    end
end

function updateConfessedCrimes ()
    for i = #confessedCrimes, 1, -1 do
        local crime = confessedCrimes[i]
        local confessed = justice.getConfessedUnit(crime)
        if confessed ~= nil and justice.tryConvictUnit(crime, confessed) then
            table.remove(confessedCrimes, i)
        end
    end
end

function convictConfessed (unit)
    for i = #confessedCrimes, 1, -1 do
        local crime = confessedCrimes[i]
        if justice.hasConfessed(crime, unit) and justice.tryConvictUnit(crime, unit) then
            table.remove(confessedCrimes, i)
        end
    end
end

function scheduleAccused (unit)
    for i = #openCrimes, 1, -1 do
        local crime = openCrimes[i]
        if justice.isAccused(crime, unit) then
            justice.scheduleInterview(crime, unit)
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
        if justice.scheduleInterview(crime, unit) then
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
    --TODO: make it run here
end

main()