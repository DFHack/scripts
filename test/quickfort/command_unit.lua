local c = reqscript('internal/quickfort/command')

local argparse = require('argparse')
local guidm = require('gui.dwarfmode')
local quickfort_dig = reqscript('internal/quickfort/dig')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_orders = reqscript('internal/quickfort/orders')
local quickfort_parse = reqscript('internal/quickfort/parse')

-- mock external dependencies (state initialized in test_wrapper below)
local mock_cursor
local function mock_guidm_getCursorPos() return mock_cursor end

local mock_dig_do_run, mock_dig_do_orders, mock_dig_do_undo
local mock_orders_create_orders

local mock_section_data
local function mock_parse_process_section(filepath, _, label)
    return mock_section_data[filepath][label]
end

local mock_aliases, mock_bp_data
local function mock_list_get_blueprint_filepath(bp_name)
    return 'bp/' .. bp_name
end
local function mock_list_get_aliases(bp_name)
    return mock_aliases[bp_name]
end
local function mock_list_get_blueprint_mode(bp_name, sec_name)
    local bp_data = mock_section_data[mock_list_get_blueprint_filepath(bp_name)]
    _, label = quickfort_parse.parse_section_name(sec_name)
    return bp_data[label][1].modeline.mode
end
local function mock_list_get_blueprint_by_number(list_num)
    local data = mock_bp_data[list_num]
    return data.bp_name, data.sec_name, data.mode
end

local function test_wrapper(test_fn)
    -- default state (can be overridden by individual tests)
    mock_cursor = {x=1, y=2, z=3}
    mock_dig_do_run, mock_dig_do_orders, mock_dig_do_undo =
            mock.func(), mock.func(), mock.func()
    mock_orders_create_orders = mock.func()
    mock_section_data = {
        ['bp/a.csv']={somelabel={{modeline={mode='dig'}, zlevel=100, grid={}}}},
        ['bp/b.csv']={alabel={{modeline={mode='dig'}, zlevel=101, grid={}}}},
        ['bp/c.csv']={lab={{modeline={mode='dig', message='ima message'},
                            zlevel=102, grid={}}}}}
    mock_aliases = {['a.csv']={imanalias='aliaskeys'}}
    mock_bp_data = {[9]={bp_name='a.csv', sec_name='/somelabel', mode='dig'},
                    [10]={bp_name='b.csv', sec_name='/alabel', mode='dig'},
                    [11]={bp_name='c.csv', sec_name='/lab', mode='dig'}}

    mock.patch({{guidm, 'getCursorPos', mock_guidm_getCursorPos},
                {quickfort_dig, 'do_run', mock_dig_do_run},
                {quickfort_dig, 'do_orders', mock_dig_do_orders},
                {quickfort_dig, 'do_undo', mock_dig_do_undo},
                {quickfort_orders, 'create_orders', mock_orders_create_orders},
                {quickfort_parse, 'process_section',
                 mock_parse_process_section},
                {quickfort_list, 'get_blueprint_filepath',
                 mock_list_get_blueprint_filepath},
                {quickfort_list, 'get_aliases', mock_list_get_aliases},
                {quickfort_list, 'get_blueprint_mode',
                 mock_list_get_blueprint_mode},
                {quickfort_list, 'get_blueprint_by_number',
                 mock_list_get_blueprint_by_number},
               },test_fn)
end
config.wrapper = test_wrapper

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/command') end)
end

function test.do_command_errors()
    expect.error_match('invalid command',
                       function() c.do_command({commands={'runn'}}) end)
    expect.error_match('invalid command',
                       function() c.do_command({commands={'run,orderss'}}) end)
    expect.error_match('expected.*blueprint_name',
                       function() c.do_command({commands={'run'}}) end)
    expect.error_match('unexpected argument',
        function() c.do_command({commands={'run'}, 'a.csv', '/somelabel'}) end)
end

local function get_ctx(mock_do_fn, idx)
    return mock_do_fn.call_args[idx][3]
end

function test.do_command_cursor()
    local argparse_coords = argparse.coords
    mock.patch({{guidm, 'getCursorPos', mock.func()}, -- returns nil
                {argparse, 'coords',
                 function(arg, name) return argparse_coords(arg, name, true) end}},
        function()
            expect.error_match('please position the game cursor',
                function()
                    c.do_command({commands={'run'}, 'a.csv', '-n/somelabel'})
                end)

            expect.eq(0, mock_dig_do_orders.call_count)
            c.do_command({commands={'orders'}, '-q', '10'})
            expect.eq(1, mock_dig_do_orders.call_count)

            expect.eq(0, mock_dig_do_run.call_count)
            -- z=100 here because it's hardcoded in the mock data above
            c.do_command({commands={'run'}, 'a.csv', '-q', '-n/somelabel',
                          '-c4,5,100'})
            expect.table_eq({x=4,y=5,z=100}, get_ctx(mock_dig_do_run, 1).cursor)
        end)
end

function test.do_command_multi_command_multi_list_num()
    c.do_command({commands={'run', 'orders'}, '-q', '9,10'})

    local ctx = get_ctx(mock_dig_do_run, 1)
    expect.eq('run', ctx.command)
    expect.eq('a.csv', ctx.blueprint_name)
    ctx = get_ctx(mock_dig_do_run, 2)
    expect.eq('run', ctx.command)
    expect.eq('b.csv', ctx.blueprint_name)

    ctx = get_ctx(mock_dig_do_orders, 1)
    expect.eq('orders', ctx.command)
    expect.eq('a.csv', ctx.blueprint_name)
    ctx = get_ctx(mock_dig_do_orders, 2)
    expect.eq('orders', ctx.command)
    expect.eq('b.csv', ctx.blueprint_name)

    expect.eq(0, mock_dig_do_undo.call_count)
    expect.eq(2, mock_orders_create_orders.call_count)
end

function test.do_command_message()
    local mock_print = mock.func()
    mock.patch(c, 'print', mock_print, function()
            c.do_command({commands={'run'}, '11'})
            expect.eq(2, mock_print.call_count)
            expect.eq('run c.csv -n /lab successfully completed',
                      mock_print.call_args[1][1])
            expect.eq('* ima message', mock_print.call_args[2][1])
        end)
end

function test.do_command_stats()
    local mock_print = mock.func()
    local mock_dig_do_run =
            function(_, _, ctx) ctx.stats.out_of_bounds.value = 2 end
    mock.patch({{c, 'print', mock_print},
                {quickfort_dig, 'do_run', mock_dig_do_run}}, function()
            c.do_command({commands={'run'}, '9'})
            expect.eq(2, mock_print.call_count)
            expect.eq('run a.csv -n /somelabel successfully completed',
                      mock_print.call_args[1][1])
            expect.eq('  Tiles outside map boundary: 2',
                      mock_print.call_args[2][1])
        end)
end

function test.do_command_raw_errors()
    expect.error_match('invalid mode',
        function() c.do_command_raw('badmode', 0, {}, {}) end)
    expect.error_match('invalid command',
        function() c.do_command_raw('dig', 0, {}, {command='badcomm'}) end)
end
