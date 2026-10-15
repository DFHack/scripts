local quickfort_set = reqscript('internal/quickfort/set')
local s = quickfort_set.unit_test_hooks

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/set') end)
end

function test.settings_have_defaults()
    for _,v in pairs(s.settings) do
        expect.ne(v.default_value, nil)
    end
end

function test.get_setting()
    expect.eq('dfhack-config/blueprints', s.get_setting('blueprints_user_dir'))
    s.set_setting('blueprints_user_dir', '/tmp')
    expect.eq('/tmp', s.get_setting('blueprints_user_dir'))

    s.reset_to_defaults()
    expect.false_(s.get_setting('force_marker_mode'))
    s.set_setting('force_marker_mode', 'true')
    expect.true_(s.get_setting('force_marker_mode'))

    expect.error_match('invalid setting',
                       function() s.get_setting('unknown_setting') end)
end

function test.set_setting()
    expect.error_match('invalid setting',
                       function() s.set_setting('unknown_setting', '-') end)

    expect.error_match('invalid boolean',
                       function() s.set_setting('force_marker_mode', '-') end)
    s.set_setting('force_marker_mode', 'true')
    expect.true_(s.get_setting('force_marker_mode'))
    s.set_setting('force_marker_mode', 'false')
    expect.false_(s.get_setting('force_marker_mode'))

    expect.error_match('invalid integer',
                       function() s.set_setting('stockpiles_max_bins', '-') end)
    s.set_setting('stockpiles_max_bins', '10')
    expect.eq(10, s.get_setting('stockpiles_max_bins'))
    s.set_setting('stockpiles_max_bins', '11.999')
    expect.eq(11, s.get_setting('stockpiles_max_bins'))

    s.set_setting('blueprints_user_dir', '.')
    expect.eq('.', s.get_setting('blueprints_user_dir'))
    s.set_setting('blueprints_user_dir', '/tmp')
    expect.eq('/tmp', s.get_setting('blueprints_user_dir'))
end

function test.reset_to_defaults()
    s.set_setting('stockpiles_max_bins', '10')
    expect.eq(10, s.get_setting('stockpiles_max_bins'))
    s.reset_to_defaults()
    expect.eq(-1, s.get_setting('stockpiles_max_bins'))
end
