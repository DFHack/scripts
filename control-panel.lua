--@module = true

local argparse = require('argparse')
local common = reqscript('internal/control-panel/common')
local registry = reqscript('internal/control-panel/registry')
local utils = require('utils')

local GLOBAL_KEY = 'control-panel'

-- state change hooks

local function apply_system_config()
    local enabled_map = common.get_enabled_map()
    for _, data in ipairs(registry.COMMANDS_BY_IDX) do
        if data.mode == 'system_enable' or data.mode == 'tweak' then
            common.apply_command(data, enabled_map)
        end
    end
    for _, data in ipairs(registry.PREFERENCES_BY_IDX) do
        local value = safe_index(common.config.data.preferences, data.name, 'val')
        if value ~= nil then
            data.set_fn(value)
        end
    end
end

local function apply_autostart_config()
    local enabled_map =common.get_enabled_map()
    for _, data in ipairs(registry.COMMANDS_BY_IDX) do
        if data.mode == 'enable' or data.mode == 'run' or data.mode == 'repeat' then
            common.apply_command(data, enabled_map)
        end
    end
end

local function apply_fort_loaded_config()
    local state = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    if not state.autostart_done then
        apply_autostart_config()
        dfhack.persistent.saveSiteData(GLOBAL_KEY, {autostart_done=true})
    end
    local enabled_map = common.get_enabled_map()
    local enabled_repeats = dfhack.persistent.getSiteData(common.REPEATS_GLOBAL_KEY, {})
    for _, data in ipairs(registry.COMMANDS_BY_IDX) do
        if data.mode == 'repeat' then
            common.apply_command(data, enabled_map, enabled_repeats[data.command])
        end
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_CORE_INITIALIZED then
        apply_system_config()
    elseif sc == SC_MAP_LOADED and dfhack.world.isFortressMode() then
        apply_fort_loaded_config()
    end
end

local function get_command_data(name_or_idx)
    if type(name_or_idx) == 'number' then
        return registry.COMMANDS_BY_IDX[name_or_idx]
    end
    return registry.COMMANDS_BY_NAME[name_or_idx]
end

local function get_autostart_internal(data)
    local default_value = not not data.default
    local current_value = safe_index(common.config.data.commands, data.command, 'autostart')
    if current_value == nil then
        current_value = default_value
    end
    return current_value, default_value
end

-- API

-- returns current, default
function get_autostart(command)
    local data = get_command_data(command)
    if not data then return end
    return get_autostart_internal(data)
end

-- CLI

local function print_header(header)
    print()
    print(header)
    print(('-'):rep(#header))
end

local function list_command_group(group, filter_strs, enabled_map)
    local header = ('Group: %s'):format(group)
    for idx, data in ipairs(registry.COMMANDS_BY_IDX) do
        if not common.command_passes_filters(data, group, filter_strs) then
            goto continue
        end
        if header then
            print_header(header)
            ---@diagnostic disable-next-line: cast-local-type
            header = nil
        end
        local extra = ''
        if data.mode == 'system_enable' or data.mode == 'tweak' then
            extra = ' (global)'
        end
        print(('%d) %s%s'):format(idx, data.command, extra))
        local desc = common.get_description(data)
        if #desc > 0 then
            print(('        %s'):format(desc))
        end
        print(('        autostart enabled: %s (default: %s)'):format(get_autostart_internal(data)))
        if enabled_map[data.command] ~= nil then
            print(('        currently enabled: %s'):format(enabled_map[data.command]))
        end
        print()
        ::continue::
    end
    if not header then
    end
end

local function list_preferences(filter_strs)
    local header = 'Preferences'
    for _, data in ipairs(registry.PREFERENCES_BY_IDX) do
        local search_key = ('%s %s %s'):format(data.name, data.label, data.desc)
        if not utils.search_text(search_key, filter_strs) then goto continue end
        if header then
            print_header(header)
            ---@diagnostic disable-next-line: cast-local-type
            header = nil
        end
        print(('%s) %s'):format(data.name, data.label))
        print(('        %s'):format(data.desc))
        print(('        current: %s (default: %s)'):format(data.get_fn(), data.default))
        if data.min then
            print(('        minimum: %s'):format(data.min))
        end
        print()
        ::continue::
    end
end

local function do_list(filter_strs)
    local enabled_map = common.get_enabled_map()
    list_command_group('automation', filter_strs, enabled_map)
    list_command_group('bugfix', filter_strs, enabled_map)
    list_command_group('gameplay', filter_strs, enabled_map)
    list_preferences(filter_strs)
end

local function do_enable_disable(which, entries)
    local enabled_map =common.get_enabled_map()
    for _, entry in ipairs(entries) do
        local data = get_command_data(entry)
        if data.mode ~= 'system_enable' and not dfhack.world.isFortressMode() then
            qerror('must have a loaded fortress to enable '..data.name)
        end
        if common.apply_command(data, enabled_map, which == 'en') then
            print(('%sabled %s'):format(which, entry))
        end
    end
end

local function do_enable(entries)
    do_enable_disable('en', entries)
end

local function do_disable(entries)
    do_enable_disable('dis', entries)
end

local function do_autostart_noautostart(which, entries)
    for _, entry in ipairs(entries) do
        local data = get_command_data(entry)
        if not data then
            qerror(('autostart command or index not found: "%s"'):format(entry))
        else
            common.set_autostart(data, which == 'en')
            print(('%sabled autostart for: %s'):format(which, entry))
        end
    end
    common.config:write()
end

local function do_autostart(entries)
    do_autostart_noautostart('en', entries)
end

local function do_noautostart(entries)
    do_autostart_noautostart('dis', entries)
end

local function do_set(params)
    local name, value = params[1], params[2]
    local data = registry.PREFERENCES_BY_NAME[name]
    if not data then
        qerror(('preference name not found: "%s"'):format(name))
    end
    common.set_preference(data, value)
    common.config:write()
end

local function do_reset(params)
    local name = params[1]
    local data = registry.PREFERENCES_BY_NAME[name]
    if not data then
        qerror(('preference name not found: "%s"'):format(name))
    end
    common.set_preference(data, data.default)
    common.config:write()
end

local command_switch = {
    list=do_list,
    enable=do_enable,
    disable=do_disable,
    autostart=do_autostart,
    noautostart=do_noautostart,
    set=do_set,
    reset=do_reset,
}

local function main(args)
    local help = false

    local positionals = argparse.processArgsGetopt(args, {
            {'h', 'help', handler=function() help = true end},
        })

    local command = table.remove(positionals, 1)
    if help or not command or not command_switch[command] then
        print(dfhack.script_help())
        return
    end

    command_switch[command](positionals)
end

if not dfhack_flags.module then
    main{...}
end
