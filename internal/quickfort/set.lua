-- settings management logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_reader = reqscript('internal/quickfort/reader')

local config_file = 'dfhack-config/quickfort/quickfort.txt'

-- keep deprecated settings in the table so we don't break existing configs
local settings = {
    blueprints_dir={default_value='blueprints'},
    buildings_use_blocks={default_value=false, deprecated=true},
    force_interactive_build={default_value=false, deprecated=true},
    force_marker_mode={default_value=false},
    query_unsafe={default_value=false},
    stockpiles_max_barrels={default_value=-1},
    stockpiles_max_bins={default_value=-1},
    stockpiles_max_wheelbarrows={default_value=0},
}

local valid_booleans = {
    ['true']=true,
    ['1']=true,
    ['on']=true,
    ['y']=true,
    ['yes']=true,
    ['false']=false,
    ['0']=false,
    ['off']=false,
    ['n']=false,
    ['no']=false,
}

function get_setting(key)
    local setting = settings[key]
    if not setting then error(string.format('invalid setting: "%s"', key)) end
    return setting.value ~= nil and setting.value or setting.default_value
end

local function set_setting(key, value)
    if settings[key] == nil then
        qerror(string.format('error: invalid setting: "%s"', key))
    end
    if type(settings[key].default_value) == 'boolean' then
        if valid_booleans[value] == nil then
            qerror(string.format('error: invalid boolean: "%s"', value))
        end
        value = valid_booleans[value]
    elseif type(settings[key].default_value) == 'number' then
        local num_val = tonumber(value)
        if not num_val then
            qerror(string.format('error: invalid integer: "%s"', value))
        end
        value = math.floor(num_val)
    end
    settings[key].value = value
end

local function read_settings(reader)
    local line = reader:get_next_row()
    while line do
        local _, _, key, value = string.find(line, '^%s*([%a_]+)%s*=%s*(%S.*)')
        if (key) then
            set_setting(key, value)
        end
        line = reader:get_next_row()
    end
end

local function reset_to_defaults()
    for _,v in pairs(settings) do
        v.value = nil
    end
end

local function reset_settings(get_reader_fn)
    local reader = nil
    local init_reader = function() reader = get_reader_fn() end
    reset_to_defaults()
    local ok, err = pcall(init_reader)
    if ok then
        read_settings(reader)
    else
        print(string.format('%s; using internal defaults', tostring(err)))
    end
end

local function print_settings()
    print('active settings:')
    local width = 1
    local settings_arr = {}
    for k,v in pairs(settings) do
        if not v.deprecated then
            if #k > width then width = #k end
            table.insert(settings_arr, k)
        end
    end
    table.sort(settings_arr)
    for _, k in ipairs(settings_arr) do
        print(string.format('  %-'..width..'s = %s', k, get_setting(k)))
    end
end

function do_set(args)
    if #args == 0 then print_settings() return end
    if #args ~= 2 then
        qerror('error: expected "quickfort set [<key> <value>]"')
    end
    set_setting(args[1], args[2])
    print(string.format('%s now set to "%s"', args[1], get_setting(args[1])))
end

function do_reset()
    print(string.format('reading quickfort configuration from "%s"',
                        config_file))
    local get_reader_fn = function()
        return quickfort_reader.TextReader{filepath=config_file}
    end
    reset_settings(get_reader_fn)
end

if not initialized and not dfhack.internal.IN_TEST then
    -- this is the first time we're initializing the environment
    do_reset()
    initialized = true
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        settings=settings,
        get_setting=get_setting,
        set_setting=set_setting,
        read_settings=read_settings,
        reset_to_defaults=reset_to_defaults,
        reset_settings=reset_settings,
    }
end
