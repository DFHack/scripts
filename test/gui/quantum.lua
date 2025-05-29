config.target = 'gui/quantum'

local q = reqscript('gui/quantum').unit_test_hooks

local quickfort = reqscript('quickfort')

-- Note: the gui_quantum quickfort ecosystem integration test exercises the
-- QuantumUI functions

function test.is_valid_pos()
    local pos, qsp_pos = {x=1, y=2, z=3}, {x=4, y=5, z=6}
    local all_good = {place_designated={value=1}, build_designated={value=1}}
    local all_bad = {place_designated={value=0}, build_designated={value=0}}
    local bad_place = {place_designated={value=0}, build_designated={value=1}}
    local bad_build = {place_designated={value=1}, build_designated={value=0}}

    mock.patch(quickfort, 'apply_blueprint', mock.func(all_good), function()
        expect.true_(q.is_valid_pos(pos, qsp_pos)) end)
    mock.patch(quickfort, 'apply_blueprint', mock.func(all_bad), function()
        expect.false_(q.is_valid_pos(pos, qsp_pos)) end)
    mock.patch(quickfort, 'apply_blueprint', mock.func(bad_place), function()
        expect.false_(q.is_valid_pos(pos, qsp_pos)) end)
    mock.patch(quickfort, 'apply_blueprint', mock.func(bad_build), function()
        expect.false_(q.is_valid_pos(pos, qsp_pos)) end)
end

--local function create_quantum(pos, qsp_pos, feeder_id, name, trackstop_dir)
function test.create_quantum()
    local pos, qsp_pos = {x=1, y=2, z=3}, {x=4, y=5, z=6}
    local feeder_id = 1900
    local all_good = {place_designated={value=1}, build_designated={value=1}}
    local bad_place = {place_designated={value=0}, build_designated={value=1}}
    local bad_build = {place_designated={value=1}, build_designated={value=0}}

    local function mock_apply_blueprint(ret_for_pos, ret_for_qsp_pos)
        return function(args)
            if same_xyz(args.pos, pos) then return ret_for_pos end
            return ret_for_qsp_pos
        end
    end

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(all_good, all_good), function()
        q.create_quantum(pos, qsp_pos, {{id=feeder_id}}, '', 'N')
        -- passes if no error is thrown
    end)

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(all_good, bad_place), function()
        expect.error_match('failed to place stockpile', function()
                q.create_quantum(pos, qsp_pos, {{id=feeder_id}}, '', 'N')
        end)
    end)

    mock.patch(quickfort, 'apply_blueprint',
               mock_apply_blueprint(bad_build, all_good), function()
        expect.error_match('failed to build trackstop', function()
                q.create_quantum(pos, qsp_pos, {{id=feeder_id}}, '', 'N')
        end)
    end)
end
