local q = reqscript('quickfort')
local quickfort_api = reqscript('internal/quickfort/api')
local quickfort_command = reqscript('internal/quickfort/command')
local c = quickfort_command.unit_test_hooks
local quickfort_common = reqscript('internal/quickfort/common')

local utils = require('utils')

local mock_do_command_raw
local verbose_snapshot

local function verbose_snapshotter(...)
    verbose_snapshot = quickfort_common.verbose
    return mock_do_command_raw(...)
end

local function test_wrapper(test_fn)
    mock_do_command_raw = mock.func()
    verbose_snapshot = nil
    mock.patch(quickfort_command, 'do_command_raw', verbose_snapshotter,
               test_fn)
end
config.wrapper = test_wrapper

function test.apply_blueprint_minimal()
    local data = {[0]={[0]={[0]='d'}}}
    local expected_ctx = quickfort_api.init_api_ctx({}, {x=0, y=0, z=0})
    q.apply_blueprint{mode='dig', data=data}

    expect.eq(1, mock_do_command_raw.call_count)
    local args = mock_do_command_raw.call_args[1]
    expect.eq(args[1], 'dig')
    expect.eq(args[2], 0)
    expect.table_eq(args[3], {[0]={[0]={cell='0,0,0', text='d'}}})
    expect.table_eq(args[4], expected_ctx)

    expect.false_(verbose_snapshot)
    expect.false_(quickfort_common.verbose)
end

function test.apply_blueprint_all_ctx_params()
    local data = {[2]={[20]={[8]='somekeys'}},
                  [3]={[9]={[20]='somealias'}}}
    local expected_ctx = utils.assign(
            c.make_ctx_base(),
            {command='undo', blueprint_name='API', cursor={x=10, y=10, z=1},
             aliases={somealias='ab{analias}'}, dry_run=true, quiet=false,
             preserve_engravings=df.item_quality.Masterful})

    q.apply_blueprint{mode='query', data=data, command='undo',
                      pos={x=2, y=1, z=-1}, aliases={somealias='ab{analias}'},
                      dry_run=true, verbose=true}

    expect.eq(2, mock_do_command_raw.call_count)
    local args = mock_do_command_raw.call_args[1]
    expect.eq(args[1], 'query')
    expect.eq(args[2], 1)
    expect.table_eq(args[3], {[21]={[10]={cell='8,20,2', text='somekeys'}}})
    expect.table_eq(args[4], expected_ctx)

    args = mock_do_command_raw.call_args[2]
    expect.eq(args[1], 'query')
    expect.eq(args[2], 2)
    expect.table_eq(args[3], {[10]={[22]={cell='20,9,3', text='somealias'}}})
    expect.table_eq(args[4], expected_ctx)

    expect.true_(verbose_snapshot)
    expect.false_(quickfort_common.verbose)
end
