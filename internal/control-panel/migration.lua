-- migrate configuration from 50.11-r4 and prior to new format
--@module = true

-- read old files, add converted data to config_data, overwrite old files with
-- a message that says they are deprecated and can be deleted with the proper
-- procedure. we can't delete them outright since steam may just restore them due to
-- Steam Cloud. We *could* delete them, though, if we know that we've been started
-- from Steam as DFHack and not as DF

local argparse = require('argparse')
local registry = reqscript('internal/control-panel/registry')

-- init files
local SYSTEM_INIT_FILE = 'dfhack-config/init/dfhack.control-panel-system.init'
local AUTOSTART_FILE = 'dfhack-config/init/onMapLoad.control-panel-new-fort.init'
local REPEATS_FILE = 'dfhack-config/init/onMapLoad.control-panel-repeats.init'
local PREFERENCES_INIT_FILE = 'dfhack-config/init/dfhack.control-panel-preferences.init'

local function save_tombstone_file(path)
    local ok, f = pcall(io.open, path, 'w')
    if not ok or not f then
        dialogs.showMessage('Error',
            ('Cannot open file for writing: "%s"'):format(path))
        return
    end
    f:write('# This file was once used by gui/control-panel\n')
    f:write('# If you are on Steam, you can delete this file manually\n')
    f:write('# by starting DFHack in the Steam client, then deleting\n')
    f:write('# this file while DF is running. Otherwise Steam Cloud will\n')
    f:write('# restore the file when you next run DFHack.\n')
    f:write('#\n')
    f:write('# If you\'re not on Steam, you can delete this file at any time.\n')
    f:close()
end

local function add_autostart(config_data, name)
    if not registry.COMMANDS_BY_NAME[name].default then
        config_data.commands[name] = {autostart=true}
    end
end

local function add_preference(config_data, name, val)
    local data = registry.PREFERENCES_BY_NAME[name]
    if type(data.default) == 'boolean' then
        ok, val = pcall(argparse.boolean, val)
        if not ok then return end
    elseif type(data.default) == 'number' then
        val = tonumber(val)
        if not val then return end
    end
    if data.default ~= val then
        config_data.preferences[name] = {val=val}
    end
end

local function parse_lines(fname, line_fn)
    local ok, f = pcall(io.open, fname)
    if not ok or not f then return end
    for line in f:lines() do
        line = line:trim()
        if #line > 0 and not line:startswith('#') then
            line_fn(line)
        end
    end
end

local function migrate_system(config_data)
    parse_lines(SYSTEM_INIT_FILE, function(line)
        local service = line:match('^enable ([%S]+)$')
        if not service then return end
        local data = registry.COMMANDS_BY_NAME[service]
        if data and (data.mode == 'system_enable' or data.command == 'work-now') then
            add_autostart(config_data, service)
        end
    end)
    save_tombstone_file(SYSTEM_INIT_FILE)
end

local function migrate_autostart(config_data)
    parse_lines(AUTOSTART_FILE, function(line)
        local service = line:match('^on%-new%-fortress enable ([%S]+)$')
            or line:match('^on%-new%-fortress (.+)')
        if not service then return end
        local data = registry.COMMANDS_BY_NAME[service]
        if data and (data.mode == 'enable' or data.mode == 'run') then
            add_autostart(config_data, service)
        end
    end)
    save_tombstone_file(AUTOSTART_FILE)
end

local REPEAT_MAP = {
    autoMilkCreature='automilk',
    autoShearCreature='autoshear',
    ['dead-units-burrow']='fix/dead-units',
    ['empty-wheelbarrows']='fix/empty-wheelbarrows',
    ['general-strike']='fix/general-strike',
    ['stuck-instruments']='fix/stuck-instruments',
}

local function migrate_repeats(config_data)
    parse_lines(REPEATS_FILE, function(line)
        local service = line:match('^repeat %-%-name ([%S]+)')
        if not service then return end
        service = REPEAT_MAP[service] or service
        local data = registry.COMMANDS_BY_NAME[service]
        if data and data.mode == 'repeat' then
            add_autostart(config_data, service)
        end
    end)
    save_tombstone_file(REPEATS_FILE)
end

local function migrate_preferences(config_data)
    parse_lines(PREFERENCES_INIT_FILE, function(line)
        local name, val = line:match('^:lua .+%.([^=]+)=(.+)')
        if not name or not val then return end
        local data = registry.PREFERENCES_BY_NAME[name]
        if data then
            add_preference(config_data, name, val)
        end
    end)
    save_tombstone_file(PREFERENCES_INIT_FILE)
end

function migrate(config_data)
    migrate_system(config_data)
    migrate_autostart(config_data)
    migrate_repeats(config_data)
    migrate_preferences(config_data)
end
