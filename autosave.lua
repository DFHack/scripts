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

-- a save is in flight from when it is requested until the saver finishes;
-- save_progress.substage keeps its final value (Finishing) after completion
local function is_save_in_progress()
    local main = df.global.plotinfo.main
    return main.autosave_request or
        (main.save_progress.substage >= df.save_substage.Initializing and
         main.save_progress.substage < df.save_substage.Finishing)
end

local function save_now()
    dfhack.run_script('quicksave')
end

local function event_loop()
    if not state.enabled then return end

    if dfhack.persistent.getUnsavedSeconds() >= get_interval_minutes() * 60 and
            dfhack.isMapLoaded() and dfhack.world.isFortressMode() and
            not is_save_in_progress() then
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
    print(('autosave interval: %s minute%s'):format(
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
    if is_save_in_progress() then
        qerror('a save is already in progress')
    end
    save_now()
else
    qerror(('unrecognized command: "%s"'):format(command))
end
