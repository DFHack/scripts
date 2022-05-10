local quickfort_reader = reqscript('internal/quickfort/reader')
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
    expect.eq('blueprints', s.get_setting('blueprints_dir'))
    s.set_setting('blueprints_dir', '/tmp')
    expect.eq('/tmp', s.get_setting('blueprints_dir'))

    s.reset_to_defaults()
    expect.false_(s.get_setting('query_unsafe'))
    s.set_setting('query_unsafe', 'true')
    expect.true_(s.get_setting('query_unsafe'))

    expect.error_match('invalid setting',
                       function() s.get_setting('unknown_setting') end)
end

function test.set_setting()
    expect.error_match('invalid setting',
                       function() s.set_setting('unknown_setting', '-') end)

    expect.error_match('invalid boolean',
                       function() s.set_setting('query_unsafe', '-') end)
    s.set_setting('query_unsafe', 'true')
    expect.true_(s.get_setting('query_unsafe'))
    s.set_setting('query_unsafe', 'false')
    expect.false_(s.get_setting('query_unsafe'))

    expect.error_match('invalid integer',
                       function() s.set_setting('stockpiles_max_bins', '-') end)
    s.set_setting('stockpiles_max_bins', '10')
    expect.eq(10, s.get_setting('stockpiles_max_bins'))
    s.set_setting('stockpiles_max_bins', '11.999')
    expect.eq(11, s.get_setting('stockpiles_max_bins'))

    s.set_setting('blueprints_dir', '.')
    expect.eq('.', s.get_setting('blueprints_dir'))
    s.set_setting('blueprints_dir', '/tmp')
    expect.eq('/tmp', s.get_setting('blueprints_dir'))
end

MockFile = defclass(MockFile, nil)
MockFile.ATTRS{i=0, lines={}}
function MockFile:close() end
function MockFile:reset(lines) self.lines, self.i = lines, 0 end
function MockFile:read()
    self.i = self.i + 1
    return self.lines[self.i]
end

local function mock_open()
    return MockFile{}
end

function test.read_settings()
    local mock_reader =
            quickfort_reader.TextReader{filepath='f', open_fn=mock_open}
    local mock_file = mock_reader.source

    local mock_print = mock.func()
    mock.patch(quickfort_set, 'print', mock_print,
        function()
            s.reset_to_defaults()
            mock_file:reset{'#comment',
                            'query_unsafe=true',
                            'blueprints_dir = a dir'}
            s.read_settings(mock_reader)
            expect.true_(s.get_setting('query_unsafe'))
            expect.eq('a dir', s.get_setting('blueprints_dir'))
        end)

    mock.patch(quickfort_set, 'print', mock_print,
        function()
            mock_file:reset{'bad_var=something'}
            expect.error_match('invalid setting',
                               function() s.read_settings(mock_reader) end)
        end)
end

function test.reset_to_defaults()
    s.set_setting('stockpiles_max_bins', '10')
    expect.eq(10, s.get_setting('stockpiles_max_bins'))
    s.reset_to_defaults()
    expect.eq(-1, s.get_setting('stockpiles_max_bins'))
end

function test.reset_settings()
    local mock_reader =
            quickfort_reader.TextReader{filepath='f', open_fn=mock_open}
    local mock_file = mock_reader.source

    local mock_print = mock.func()
    mock.patch(quickfort_set, 'print', mock_print,
        function()
            mock_file:reset{'query_unsafe=true'}
            s.reset_to_defaults()
            expect.false_(s.get_setting('query_unsafe'))
            s.set_setting('blueprints_dir', '.')
            s.reset_settings(function() return mock_reader end)
            expect.true_(s.get_setting('query_unsafe'))
            expect.eq('blueprints', s.get_setting('blueprints_dir'))
        end)

    mock_print = mock.func()
    mock.patch(quickfort_set, 'print', mock_print,
        function()
            s.reset_settings(function() qerror('err') end)
            expect.eq(1, mock_print.call_count)
            expect.eq('err; using internal defaults',
                      mock_print.call_args[1][1])
        end)
end
