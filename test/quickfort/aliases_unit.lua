local a = reqscript('internal/quickfort/aliases').unit_test_hooks
local quickfort_reader = reqscript('internal/quickfort/reader')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/aliases') end)
end

function test.push_pop()
    local alias_ctx = a.init_alias_ctx_base()

    expect.table_eq({'a','a'}, a.expand_aliases(alias_ctx, 'aa'))
    a.push_aliases(alias_ctx, {aa='zz'})
    expect.table_eq({'z','z'}, a.expand_aliases(alias_ctx, 'aa'))
    expect.table_eq({'b','b'}, a.expand_aliases(alias_ctx, 'bb'))
    a.push_aliases(alias_ctx, {aa='yy', bb='ww'})
    expect.table_eq({'y','y'}, a.expand_aliases(alias_ctx, 'aa'))
    expect.table_eq({'w','w'}, a.expand_aliases(alias_ctx, 'bb'))
    expect.table_eq({'c','c'}, a.expand_aliases(alias_ctx, 'cc'))
    a.pop_aliases(alias_ctx)
    expect.table_eq({'z','z'}, a.expand_aliases(alias_ctx, 'aa'))
    expect.table_eq({'b','b'}, a.expand_aliases(alias_ctx, 'bb'))
    a.push_aliases(alias_ctx, {cc='xx'})
    expect.table_eq({'x','x'}, a.expand_aliases(alias_ctx, 'cc'))
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

function test.push_aliases_reader()
    local mock_reader =
            quickfort_reader.TextReader{filepath='f', open_fn=mock_open}
    local mock_file = mock_reader.source
    local alias_ctx = a.init_alias_ctx_base()

    expect.eq(0, a.push_aliases_reader(alias_ctx, mock_reader))

    mock_file:reset({'# comment', '#comment: withcolon', 'aa: zz'})
    expect.eq(1, a.push_aliases_reader(alias_ctx, mock_reader))
    expect.table_eq({'z','z'}, a.expand_aliases(alias_ctx, 'aa'))
end

function test.process_text()
    local alias_ctx = a.init_alias_ctx_base()

    expect.error(function() a.process_text(alias_ctx, 'text', {}, 51) end)

    a.push_aliases(alias_ctx, {aa='{bb}',bb='{aa}'})
    expect.error_match(
            'recursion',
            function() a.process_text(alias_ctx, '{aa}', {}) end)

    alias_ctx = a.init_alias_ctx_base()
    a.push_aliases(alias_ctx, {aa='{bb}', bb='x{cc}x', cc='o'})

    local tokens = {}
    a.process_text(alias_ctx, 'send!&', tokens)
    expect.table_eq({'s','e','n','d','Ctrl','Enter'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, '!n@', tokens)
    expect.table_eq({'Ctrl','n','Shift','Enter'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, '{Enter 3}{ExitMenu}', tokens)
    expect.table_eq({'Enter','Enter','Enter','ESC'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, '{q 3}{cc 2}{za 2}', tokens)
    expect.table_eq({'q','q','q','o','o','za','za'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, 'i{aa 3}', tokens)
    expect.table_eq({'i','x','o','x','x','o','x','x','o','x'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, '{aa bb=q 3}', tokens)
    expect.table_eq({'q','q','q'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, '{aa cc=q 3}', tokens)
    expect.table_eq({'x','q','x','x','q','x','x','q','x'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, '{aa bb=q}{aa cc=u}', tokens)
    expect.table_eq({'q','x','u','x'}, tokens)

    tokens = {}
    a.process_text(alias_ctx, '{aa cc={dd} dd=v}', tokens)
    expect.table_eq({'x','v','x'}, tokens)
end

function test.expand_aliases()
    local alias_ctx = a.init_alias_ctx_base()

    expect.table_eq({'r','+','Enter'}, a.expand_aliases(alias_ctx, 'r+'))
    expect.table_eq({'r','+','Enter'}, a.expand_aliases(alias_ctx, '{r+}'))

    a.push_aliases(alias_ctx, {aa='{bb}', bb='x{cc}x', cc='o'})
    expect.table_eq({'o'}, a.expand_aliases(alias_ctx, 'cc'))
    expect.table_eq({'x','o','x'}, a.expand_aliases(alias_ctx, 'aa'))

    expect.table_eq({'l','i','t'}, a.expand_aliases(alias_ctx, 'lit'))
end
