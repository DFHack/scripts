-- Automatically save the game on a real-time schedule.
--@module = true
--@enable = true

local argparse = require('argparse')
local json = require('json')
local utils = require('utils')

local GLOBAL_KEY = 'autosave' -- used for state change hooks and persistence
local CONFIG_FILE_PATH = 'dfhack-config/autosave.json'

local DEFAULT_INTERVAL_MINUTES = 30

-- how often (in rendered frames) to check whether a save is due. rendered
-- frames keep ticking while the game is paused, so the interval stays in
-- real time
local POLL_FRAMES = 100

-- if a requested save hasn't completed within this long, assume it failed
-- and allow another attempt
local SAVE_TIMEOUT_MS = 10 * 60 * 1000

local function get_default_state()
    return {
        enabled=false,
    }
end

state = state or get_default_state()
config = config or json.open(CONFIG_FILE_PATH)

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

local function get_interval_minutes()
    return config.data.interval_minutes or DEFAULT_INTERVAL_MINUTES
end

local function save_now()
    save_requested_ms = dfhack.getTickCount()
    dfhack.run_script('quicksave')
end

local function event_loop()
    if not state.enabled then return end

    local interval_sec = get_interval_minutes() * 60
    local unsaved_sec = dfhack.persistent.getUnsavedSeconds()

    if save_requested_ms then
        -- the unsaved counter resets when the save completes; if it never
        -- does (e.g. the save failed), eventually give up and try again
        if unsaved_sec < interval_sec or
                dfhack.getTickCount() - save_requested_ms > SAVE_TIMEOUT_MS then
            save_requested_ms = nil
        end
    elseif unsaved_sec >= interval_sec and
            dfhack.isMapLoaded() and dfhack.world.isFortressMode() then
        save_now()
    end

    timeout_id = dfhack.timeout(POLL_FRAMES, 'frames', event_loop)
end

local function do_enable()
    if state.enabled then return end
    state.enabled = true
    event_loop()
end

local function do_disable()
    if not state.enabled then return end
    state.enabled = false
    if timeout_id then
        dfhack.timeout_active(timeout_id, nil) -- cancel callback
        timeout_id = nil
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        do_disable()
        return
    end

    if sc ~= SC_MAP_LOADED then
        return
    end

    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))
    event_loop()
end

local function status()
    print(('autosave is %s'):format(state.enabled and 'enabled' or 'disabled'))
    local interval = get_interval_minutes()
    print(('autosave interval: %d minute%s'):format(
        interval, interval == 1 and '' or 's'))
    if dfhack.isMapLoaded() then
        local unsaved_min = dfhack.persistent.getUnsavedSeconds() // 60
        print(('time since last save: %d minute%s'):format(
            unsaved_min, unsaved_min == 1 and '' or 's'))
    end
end

if dfhack_flags.module then
    return
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        do_enable()
    else
        do_disable()
    end
    persist_state()
end

local help = false
local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() help = true end},
})

local command = table.remove(positionals, 1)
if help or command == 'help' then
    print(dfhack.script_help())
    return
end

if not command or command == 'status' then
    status()
elseif command == 'set' then
    local minutes = tonumber(positionals[1])
    if not minutes or minutes <= 0 then
        qerror('interval must be a positive number of minutes')
    end
    config.data.interval_minutes = minutes
    config:write()
    print(('autosave interval set to %s minute%s'):format(
        minutes, minutes == 1 and '' or 's'))
elseif command == 'now' then
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('a fortress must be loaded to save')
    end
    save_now()
else
    qerror(('unrecognized command: "%s"'):format(command))
end
