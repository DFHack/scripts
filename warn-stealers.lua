-- Script to warn when creatures that may steal food enter the map
--[====[
warn-stealers
============
Will make a zoomable announcement whenever a creature that can eat food, guzzle drinks, or steal items enters the map and moves into a revealed location.
Takes ``start`` or ``stop`` as parameters.
]====]

local persistTable = require("persist-table")
local eventful = require("plugins.eventful")
local repeatUtil = require("repeat-util")
local eventfulKey = "warn-stealers"

if df.global.gamemode ~= df.game_mode.DWARF then
    if df.global.gamemode ~= df.game_mode.NONE then
        -- errors when gamemode is NONE
        persistTable.GlobalTable.warnStealersCache = nil
    end
    return
end

if not persistTable.GlobalTable.warnStealersCache then
    persistTable.GlobalTable.warnStealersCache = {}
end
local cache = persistTable.GlobalTable.warnStealersCache

local function isUnitHidden(unit)
    local block = dfhack.maps.getTileBlock(unit.pos)
    if not block then
        return false
    end
    return block.designation[unit.pos.x%16][unit.pos.y%16].hidden
end

local races = df.global.world.raws.creatures.all

local function addToCacheIfStealer(unitId)
    local unit = df.unit.find(unitId)
    local casteFlags = races[unit.race].caste[unit.caste].flags
    if casteFlags.CURIOUS_BEAST_EATER or casteFlags.CURIOUS_BEAST_GUZZLER or casteFlags.CURIOUS_BEAST_ITEM then
        cache[tostring(unitId)] = true
    end
end

local function announceAndRemoveFromCache(unit)
    local caste = races[unit.race].caste[unit.caste]
    local casteFlags = caste.flags
    local str = ""
    if casteFlags.CURIOUS_BEAST_EATER then
        str = str .. "eat food + "
    end
    if casteFlags.CURIOUS_BEAST_GUZZLER then
        str = str .. "guzzle drinks + "
    end
    if casteFlags.CURIOUS_BEAST_ITEM then
        str = str .. "steal items + "
    end
    str = str:sub(1, -4)
    dfhack.gui.showZoomAnnouncement(-1, unit.pos, "A " .. caste.caste_name[0] .. " has appeared, it may " .. str .. ".", COLOR_RED, true)
    cache[tostring(unit.id)] = nil
end

local function onTick()
    for unitIdStr in pairs(cache) do
        local unitId = tonumber(unitIdStr)
        if unitId then -- sometimes perisst-table special fields
            local unit = df.unit.find(unitId)
            if not unit or unit.flags1.inactive then
                cache[unitId] = nil
            elseif not isUnitHidden(unit) then
                announceAndRemoveFromCache(unit)
            end
        end
    end
end

local function help()
    print("syntax: warn-stealers [start|stop]")
end

local function start()
    eventful.enableEvent(eventful.eventType.NEW_UNIT_ACTIVE, 1)
    eventful.onUnitNewActive[eventfulKey] = addToCacheIfStealer
    repeatUtil.scheduleEvery(eventfulKey, 1, "ticks", onTick)
    -- in case any units were missed
    for _, unit in ipairs(df.global.world.units.active) do
        addToCacheIfStealer(unit.id)
    end
    print("warn-stealers running")
end

local function stop()
    eventful.onUnitNewActive[eventfulKey] = nil
    repeatUtil.cancel(eventfulKey)
    print("warn-stealers stopped")
end

local action_switch = {start = start, stop = stop}
setmetatable(action_switch, {__index = function() return help end})

local args = {...}
action_switch[args[1] or "help"]()
