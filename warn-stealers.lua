-- Script to warn when creatures that may steal food become visible
--[====[
warn-stealers
=============
Will make a zoomable announcement whenever a creature that can eat food, guzzle drinks, or steal items enters the map and moves into a revealed location.
Takes ``start`` or ``stop`` as parameters.
]====]

local persistTable = require("persist-table")
local eventful = require("plugins.eventful")
local repeatUtil = require("repeat-util")

local eventfulKey = "warn-stealers"
local numTicksBetweenChecks = 100

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

local function addToCacheIfStealerAndHidden(unitId)
    local unit = df.unit.find(unitId)
    if not isUnitHidden(unit) then
        return
    end
    local casteFlags = races[unit.race].caste[unit.caste].flags
    if casteFlags.CURIOUS_BEAST_EATER or casteFlags.CURIOUS_BEAST_GUZZLER or casteFlags.CURIOUS_BEAST_ITEM then
        cache[tostring(unitId)] = ""
    end
end

local function announce(unit)
    local caste = races[unit.race].caste[unit.caste]
    local casteFlags = caste.flags
    local desires = {}
    if casteFlags.CURIOUS_BEAST_EATER then
        table.insert(desires, "eat food")
    end
    if casteFlags.CURIOUS_BEAST_GUZZLER then
        table.insert(desires, "guzzle drinks")
    end
    if casteFlags.CURIOUS_BEAST_ITEM then
        table.insert(desires, "steal items")
    end
    local str = table.concat(str, " + ")
    dfhack.gui.showZoomAnnouncement(-1, unit.pos, "A " .. caste.caste_name[0] .. " has appeared, it may " .. str .. ".", COLOR_RED, true)
end

local function onTick()
    for _, unitIdStr in ipairs(cache._children) do
        if cache[unitIdStr] then -- For a bug in persist-table
            local unitId = tonumber(unitIdStr)
            local unit = df.unit.find(unitId)
            if not unit or unit.flags1.inactive then
                cache[unitIdStr] = nil
            elseif not isUnitHidden(unit) then
                announce(unit)
                cache[unitIdStr] = nil -- this isn't stopping it from being iterated over.
            end
        end
    end
end

local function help()
    print("syntax: warn-stealers [start|stop]")
end

local function start()
    eventful.enableEvent(eventful.eventType.UNIT_NEW_ACTIVE, numTicksBetweenChecks)
    eventful.onUnitNewActive[eventfulKey] = addToCacheIfStealerAndHidden
    repeatUtil.scheduleEvery(eventfulKey, numTicksBetweenChecks, "ticks", onTick)
    -- in case any units were missed
    for _, unit in ipairs(df.global.world.units.active) do
        addToCacheIfStealerAndHidden(unit.id)
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
