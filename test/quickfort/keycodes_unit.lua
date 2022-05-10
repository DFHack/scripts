local k = reqscript('internal/quickfort/keycodes').unit_test_hooks
local quickfort_reader = reqscript('internal/quickfort/reader')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/keycodes') end)
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

function test.canonicalize_keyspec()
    expect.eq('somethingrandom', k.canonicalize_keyspec('somethingrandom'))
    expect.eq('[KEY:a]', k.canonicalize_keyspec('[KEY:a]'))
    expect.eq('[KEY:5]', k.canonicalize_keyspec('[KEY:5]'))
    expect.eq('[KEY:5]', k.canonicalize_keyspec('[SYM:0:5]'))
    expect.eq('[SYM:1:5]', k.canonicalize_keyspec('[SYM:1:5]'))
end

function test.reload_and_get_keycodes()
    local reader = quickfort_reader.TextReader{open_fn=mock_open}

    expect.eq(0, k.reload_keycodes(reader), 'empty keycode input')
    expect.nil_(k.get_keycodes())
    expect.nil_(k.get_keycodes('a', {}))

    reader.source:reset(
       {
        '[BIND:A_KEY:IGNORE]',
        '[KEY:a]',
        '[BIND:B_KEY:IGNORE]',
        '[KEY:b]',
        '[KEY:B]',
        '[SYM:0:5]',
        '[BIND:C_KEY:IGNORE]',
        '[KEY:5]',
        '[BIND:D_KEY:IGNORE]',
        '[SYM:1:d]',
        '[BIND:E_KEY:IGNORE]',
        '[SYM:2:d]',
        '[BIND:F_KEY:IGNORE]',
        '[SYM:4:d]',
        '[BIND:G_KEY:IGNORE]',
        '[SYM:6:d]',
       })
    expect.eq(9, k.reload_keycodes(reader), 'full keycode input')
    expect.nil_(k.get_keycodes('A', {}))
    expect.table_eq({'A_KEY'}, k.get_keycodes('a', {}))
    expect.table_eq({'B_KEY'}, k.get_keycodes('b', {}))
    expect.table_eq({'B_KEY'}, k.get_keycodes('B', {}))
    expect.table_eq({'B_KEY', 'C_KEY'}, k.get_keycodes('5', {}))
    expect.table_eq({'D_KEY'}, k.get_keycodes('d', {shift=true}))
    expect.table_eq({'E_KEY'}, k.get_keycodes('d', {ctrl=true}))
    expect.table_eq({'F_KEY'}, k.get_keycodes('d', {alt=true}))
    expect.table_eq({'G_KEY'}, k.get_keycodes('d', {ctrl=true, alt=true}))
end
