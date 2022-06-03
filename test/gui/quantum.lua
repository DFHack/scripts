local q = reqscript('gui/quantum').unit_test_hooks

local quickfort = reqscript('quickfort')
local quickfort_building = reqscript('internal/quickfort/building')

-- Note: the gui_quantum quickfort ecosystem integration test exercises the
-- QuantumUI functions

function test.is_in_extents()
    -- create an upside-down "T" with tiles down the center and bottom
    local extent_grid = {
        [1]={[5]=true},
        [2]={[5]=true},
        [3]={[1]=true,[2]=true,[3]=true,[4]=true,[5]=true},
        [4]={[5]=true},
        [5]={[5]=true},
    }
    local extents = quickfort_building.make_extents(
            {width=5, height=5, extent_grid=extent_grid})
    dfhack.with_temp_object(extents, function()
        local bld = {x1=10, x2=14, y1=20, room={extents=extents}}
        expect.false_(q.is_in_extents(bld, 10, 20))
        expect.false_(q.is_in_extents(bld, 14, 23))
        expect.true_(q.is_in_extents(bld, 12, 20))
        expect.true_(q.is_in_extents(bld, 14, 24))
    end)
end

function test.is_valid_pos()
    local all_good = {place_designated={value=1}, build_designated={value=1}}
    local all_bad = {place_designated={value=0}, build_designated={value=0}}
    local bad_place = {place_designated={value=0}, build_designated={value=1}}
    local bad_build = {place_designated={value=1}, build_designated={value=0}}

    mock.patch(quickfort, 'apply_blueprint', mock.func(all_good), function()
        expect.true_(q.is_valid_pos()) end)
    mock.patch(quickfort, 'apply_blueprint', mock.func(all_bad), function()
        expect.false_(q.is_valid_pos()) end)
    mock.patch(quickfort, 'apply_blueprint', mock.func(bad_place), function()
        expect.false_(q.is_valid_pos()) end)
    mock.patch(quickfort, 'apply_blueprint', mock.func(bad_build), function()
        expect.false_(q.is_valid_pos()) end)
end

function test.get_feeder_pos()
    local tiles = {[20]={[30]={[40]=true}}}
    expect.table_eq({x=40, y=30, z=20}, q.get_feeder_pos(tiles))
end

function test.get_moves()
    local move_prefix, move_back_prefix = 'mp', 'mbp'
    local increase_token, decrease_token = '+', '-'

    local start_pos, end_pos = 10, 15
    expect.table_eq({'mp{+ 5}', 'mbp{- 5}'},
            {q.get_moves(move_prefix, move_back_prefix, start_pos, end_pos,
                         increase_token, decrease_token)})

    start_pos, end_pos = 15, 10
    expect.table_eq({'mp{- 5}', 'mbp{+ 5}'},
            {q.get_moves(move_prefix, move_back_prefix, start_pos, end_pos,
                         increase_token, decrease_token)})

    start_pos, end_pos = 10, 10
    expect.table_eq({'mp', 'mbp'},
            {q.get_moves(move_prefix, move_back_prefix, start_pos, end_pos,
                         increase_token, decrease_token)})

    start_pos, end_pos = 1, -1
    expect.table_eq({'mp{- 2}', 'mbp{+ 2}'},
            {q.get_moves(move_prefix, move_back_prefix, start_pos, end_pos,
                         increase_token, decrease_token)})
end

function test.get_quantumstop_data()
    local dump_pos   = {x=40, y=30, z=20}
    local feeder_pos = {x=41, y=32, z=23}
    local name = ''
    expect.eq('{quantumstop move="{< 3}{Down 2}{Right 1}" move_back="{> 3}{Up 2}{Left 1}"}',
              q.get_quantumstop_data(dump_pos, feeder_pos, name))

    name = 'foo'
    expect.eq('{quantumstop name="foo quantum" move="{< 3}{Down 2}{Right 1}" move_back="{> 3}{Up 2}{Left 1}"}{givename name="foo dumper"}',
              q.get_quantumstop_data(dump_pos, feeder_pos, name))

    dump_pos   = {x=40, y=32, z=20}
    feeder_pos = {x=40, y=30, z=20}
    name = ''
    expect.eq('{quantumstop move="{Up 2}" move_back="{Down 2}"}',
              q.get_quantumstop_data(dump_pos, feeder_pos, name))
end

function test.get_quantum_data()
    expect.eq('{quantum}', q.get_quantum_data(''))
    expect.eq('{quantum name="foo"}', q.get_quantum_data('foo'))
end

function test.create_quantum()
    local pos, qsp_pos = {x=1, y=2, z=3}, {x=4, y=5, z=6}
    local feeder_tiles = {[0]={[0]={[0]=true}}}
    local all_good = {place_designated={value=1}, build_designated={value=1},
                      query_skipped_tiles={value=0}}
    local bad_place = {place_designated={value=0}, build_designated={value=1},
                       query_skipped_tiles={value=0}}
    local bad_build = {place_designated={value=1}, build_designated={value=0},
                       query_skipped_tiles={value=0}}
    local bad_query = {place_designated={value=1}, build_designated={value=1},
                       query_skipped_tiles={value=1}}

    local function mock_apply_blueprint(ret_for_pos, ret_for_qsp_pos)
        return function(args)
            if same_xyz(args.pos, pos) then return ret_for_pos end
            return ret_for_qsp_pos
        end
    end

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(all_good, all_good), function()
        q.create_quantum(pos, qsp_pos, feeder_tiles, '', 'N')
        -- passes if no error is thrown
    end)

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(all_good, bad_place), function()
        expect.error_match('failed to place quantum stockpile', function()
                q.create_quantum(pos, qsp_pos, feeder_tiles, '', 'N')
        end)
    end)

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(bad_build, all_good), function()
        expect.error_match('failed to build trackstop', function()
                q.create_quantum(pos, qsp_pos, feeder_tiles, '', 'N')
        end)
    end)

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(bad_query, all_good), function()
        expect.error_match('failed to query trackstop', function()
                q.create_quantum(pos, qsp_pos, feeder_tiles, '', 'N')
        end)
    end)

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(all_good, bad_query), function()
        expect.error_match('failed to query quantum stockpile', function()
                q.create_quantum(pos, qsp_pos, feeder_tiles, '', 'N')
        end)
    end)
end
