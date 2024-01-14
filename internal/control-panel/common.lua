--@module = true

local helpdb = require('helpdb')
local json = require('json')
local migration = reqscript('internal/control-panel/migration')
local registry = reqscript('internal/control-panel/registry')
local repeatUtil = require('repeat-util')
local utils = require('utils')

local CONFIG_FILE = 'dfhack-config/control-panel.json'

REPEATS_GLOBAL_KEY = 'control-panel-repeats'

local function get_config()
    local f = json.open(CONFIG_FILE)
    local updated = false
    -- ensure proper structure
    ensure_key(f.data, 'commands')
    ensure_key(f.data, 'preferences')
    if f.exists then
        -- remove unknown or out of date entries from the loaded config
        for k in pairs(f.data) do
            if k ~= 'commands' and k ~= 'preferences' then
                updated = true
                f.data[k] = nil
            end
        end
        for name, config_command_data in pairs(f.data.commands) do
            local data = registry.COMMANDS_BY_NAME[name]
            if not data or config_command_data.version ~= data.version then
                updated = true
                f.data.commands[name] = nil
            end
        end
        for name, config_pref_data in pairs(f.data.preferences) do
            local data = registry.PREFERENCES_BY_NAME[name]
            if not data or config_pref_data.version ~= data.version then
                updated = true
                f.data.preferences[name] = nil
            end
        end
    else
        -- migrate any data from old configs
        migration.migrate(f.data)
        updated = next(f.data.commands) or next(f.data.preferences)
    end
    if updated then
        f:write()
    end
    return f
end

config = config or get_config()

local function unmunge_repeat_name(munged_name)
    if munged_name:startswith('control-panel/') then
        return munged_name:sub(15)
    end
end

function get_enabled_map()
    local enabled_map = {}
    local output = dfhack.run_command_silent('enable'):split('\n+')
    for _,line in ipairs(output) do
        local _,_,command,enabled_str = line:find('%s*(%S+):%s+(%S+)')
        if enabled_str then
            enabled_map[command] = enabled_str == 'on'
        end
    end
    -- repeat entries override tool names for control-panel
    for munged_name in pairs(repeatUtil.repeating) do
        local name = unmunge_repeat_name(munged_name)
        if name then
            enabled_map[name] = true
        end
    end
    return enabled_map
end

function get_first_word(str)
    local word = str:trim():split(' +')[1]
    if word:startswith(':') then word = word:sub(2) end
    return word
end

function command_passes_filters(data, target_group, filter_strs)
    if data.group ~= target_group then
        return false
    end
    filter_strs = filter_strs or {}
    local first_word = get_first_word(data.command)
    if dfhack.getHideArmokTools() and helpdb.is_entry(first_word)
        and helpdb.get_entry_tags(first_word).armok
    then
        return false
    end
    if not utils.search_text(data.command, filter_strs) then
        return false
    end
    return true
end

function get_description(data)
    if data.desc then
        return data.desc
    end
    local first_word = get_first_word(data.command)
    return helpdb.is_entry(first_word) and helpdb.get_entry_short_help(first_word) or ''
end

local function persist_enabled_repeats()
    local cp_repeats = {}
    for munged_name in pairs(repeatUtil.repeating) do
        local name = unmunge_repeat_name(munged_name)
        if name then
            cp_repeats[name] = true
        end
    end
    dfhack.persistent.saveSiteData(REPEATS_GLOBAL_KEY, cp_repeats)
end

function apply_command(data, enabled_map, enabled)
    enabled_map = enabled_map or {}
    if enabled == nil then
        enabled = safe_index(config.data.commands, data.command, 'autostart')
        enabled = enabled or (enabled == nil and data.default)
        if not enabled then return end
    end
    if data.mode == 'enable' or data.mode == 'system_enable' then
        if enabled_map[data.command] == nil then
            dfhack.printerr(('tool not enableable: "%s"'):format(data.command))
            return false
        else
            dfhack.run_command({enabled and 'enable' or 'disable', data.command})
        end
    elseif data.mode == 'repeat' then
        local munged_name = 'control-panel/' .. data.command
        if enabled then
            local command_str = ('repeat --name %s %s\n'):
                    format(munged_name, table.concat(data.params, ' '))
            dfhack.run_command(command_str)
        else
            repeatUtil.cancel(munged_name)
        end
        persist_enabled_repeats()
    elseif data.mode == 'run' then
        if enabled then
            dfhack.run_command(data.command)
        end
    else
        dfhack.printerr(('unhandled command: "%s"'):format(data.command))
        return false
    end
    return true
end

function set_preference(data, in_value)
    local expected_type = type(data.default)
    local value = in_value
    if expected_type == 'boolean' and type(value) ~= 'boolean' then
        value = argparse.boolean(value)
    end
    local actual_type = type(value)
    if actual_type ~= expected_type then
        qerror(('"%s" has an unexpected value type: got: %s; expected: %s'):format(
            in_value, actual_type, expected_type))
    end
    if data.min and data.min > value then
        qerror(('value too small: got: %s; minimum: %s'):format(value, data.min))
    end
    data.set_fn(value)
    if data.default ~= value then
        config.data.preferences[data.name] = {
            val=value,
            version=data.version,
        }
    else
        config.data.preferences[data.name] = nil
    end
end

function set_autostart(data, enabled)
    if enabled ~= not not data.default then
        config.data.commands[data.command] = {
            autostart=enabled,
            version=data.version,
        }
    else
        config.data.commands[data.command] = nil
    end
end
