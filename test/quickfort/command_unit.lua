local quickfort_command = reqscript('internal/quickfort/command')
local c = quickfort_command.unit_test_hooks

local argparse = require('argparse')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local quickfort_dig = reqscript('internal/quickfort/dig')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_orders = reqscript('internal/quickfort/orders')
local quickfort_parse = reqscript('internal/quickfort/parse')

-- mock external dependencies (state initialized in test_wrapper below)
local mock_cursor
local function mock_guidm_getCursorPos() return copyall(mock_cursor) end

local mock_dig_do_run, mock_dig_do_orders, mock_dig_do_undo
local mock_orders_create_orders

local mock_section_data
local function mock_parse_process_section(filepath, _, label, cursor)
    local section_data_list = {}
    for _,section_data in ipairs(mock_section_data[filepath][label]) do
        local data = copyall(section_data)
        data.zlevel = cursor.z
        table.insert(section_data_list, data)
    end
    return section_data_list
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
    mock_cursor = {x=1, y=2, z=100}
    mock_dig_do_run, mock_dig_do_orders, mock_dig_do_undo =
            mock.func(), mock.func(), mock.func()
    mock_orders_create_orders = mock.func()
    mock_section_data = {
        ['bp/a.csv']={somelabel={{modeline={mode='dig'}, zlevel=100, grid={}}}},
        ['bp/b.csv']={alabel={{modeline={mode='dig'}, zlevel=100, grid={}}}},
        ['bp/c.csv']={lab={{modeline={mode='dig', message='ima message'},
                            zlevel=100, grid={}}}}}
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

function test.init_ctx()
    expect.error_match('invalid command',
        function() c.init_ctx{command='badcomm'} end)
    expect.error_match('must specify blueprint_name',
        function() c.init_ctx{command='run'} end)
    expect.error_match('must specify cursor',
        function() c.init_ctx{command='run', blueprint_name='bp.csv'} end)

    local expected_ctx = utils.assign(
            c.make_ctx_base(),
            {command='run', blueprint_name='bp.csv', cursor={x=0, y=0, z=0},
             aliases={}, preserve_engravings=df.item_quality.Masterful})
    expect.table_eq(expected_ctx,
                    c.init_ctx{command='run', blueprint_name='bp.csv',
                               cursor={x=0, y=0, z=0}})
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

function test.do_command_preserve_engravings()
    c.do_command({commands={'run'}, '-q', '--preserve-engravings=Exceptional',
                  '10'})
    expect.eq(1, mock_dig_do_run.call_count)
    expect.eq(df.item_quality.Exceptional,
              get_ctx(mock_dig_do_run, 1).preserve_engravings)
end

function test.do_command_repeat_down()
    c.do_command({commands={'run'}, '-q', '-r>5', '10'})
    expect.eq(5, mock_dig_do_run.call_count)
    expect.eq(100, get_ctx(mock_dig_do_run, 5).zmax)
    expect.eq(96, get_ctx(mock_dig_do_run, 5).zmin)
end

function test.do_command_repeat_up()
    c.do_command({commands={'run'}, '-q', '-r<5', '10'})
    expect.eq(5, mock_dig_do_run.call_count)
    expect.eq(104, get_ctx(mock_dig_do_run, 5).zmax)
    expect.eq(100, get_ctx(mock_dig_do_run, 5).zmin)
end

function test.do_command_no_shift_no_transform()
    c.do_command({commands={'run'}, '-q', '10'})
    local transform_fn = get_ctx(mock_dig_do_run, 1).transform_fn
    expect.table_eq({x=1, y=2}, transform_fn({x=1, y=2}))
end

function test.do_command_shift_x()
    c.do_command({commands={'run'}, '-q', '-s5', '10'})
    local transform_fn = get_ctx(mock_dig_do_run, 1).transform_fn
    expect.table_eq({x=6, y=2}, transform_fn({x=1, y=2}))
end

function test.do_command_shift_y()
    c.do_command({commands={'run'}, '-q', '-s0,5', '10'})
    local transform_fn = get_ctx(mock_dig_do_run, 1).transform_fn
    expect.table_eq({x=1, y=7}, transform_fn({x=1, y=2}))
end

function test.do_command_transform_cw()
    c.do_command({commands={'run'}, '-q', '-tcw', '10'})
    local transform_fn = get_ctx(mock_dig_do_run, 1).transform_fn
    -- rotates around x=1, y=2
    expect.table_eq({x=2, y=2}, transform_fn({x=1, y=1}))
end

function test.do_command_transform_ccw()
    c.do_command({commands={'run'}, '-q', '-tccw', '10'})
    local transform_fn = get_ctx(mock_dig_do_run, 1).transform_fn
    -- rotates around x=1, y=2
    expect.table_eq({x=1, y=1}, transform_fn({x=2, y=2}))
end

function test.do_command_transform_combined()
    c.do_command({commands={'run'}, '-q', '-tcw,flipv,ccw', '10'})
    local transform_fn = get_ctx(mock_dig_do_run, 1).transform_fn
    -- rotates around x=1, y=2
    expect.table_eq({x=0, y=2}, transform_fn({x=2, y=2}))
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
    mock.patch(quickfort_command, 'print', mock_print, function()
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
    mock.patch({{quickfort_command, 'print', mock_print},
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
end
