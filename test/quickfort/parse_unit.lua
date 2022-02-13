local parse = reqscript('internal/quickfort/parse').unit_test_hooks
local quickfort_reader = reqscript('internal/quickfort/reader')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/parse') end)
end

function test.parse_cell()
    expect.table_eq({nil, {width=1, height=1}}, {parse.parse_cell('')})

    expect.table_eq({'()', {width=1, height=1}}, {parse.parse_cell('()')})
    expect.table_eq({'a()', {width=1, height=1}}, {parse.parse_cell('a()')})
    expect.table_eq({'a(x)', {width=1, height=1}}, {parse.parse_cell('a(x)')})
    expect.table_eq({'a(5)', {width=1, height=1}}, {parse.parse_cell('a(5)')})
    expect.table_eq({'a(5x)', {width=1, height=1}}, {parse.parse_cell('a(5x)')})
    expect.table_eq({'ab(5x6 ', {width=1, height=1}},
                    {parse.parse_cell('ab(5x6 ')})
    expect.table_eq({'a5', {width=1, height=1}}, {parse.parse_cell('a5')})
    expect.table_eq({'a5x', {width=1, height=1}}, {parse.parse_cell('a5x')})
    expect.table_eq({'a5x2', {width=1, height=1}}, {parse.parse_cell('a5x2')})

    expect.table_eq({'a', {width=1, height=1}}, {parse.parse_cell('a')})
    expect.table_eq({'ab', {width=5, height=6, specified=true}},
                    {parse.parse_cell('ab(5x6)')})
    expect.table_eq({'ab', {width=5, height=6, specified=true}},
                    {parse.parse_cell('ab  (  5  x  6  )')})
    expect.table_eq({'ab', {width=1, height=1, specified=true}},
                    {parse.parse_cell('ab(0x0)')})
end

function test.coord2d_lt()
    expect.true_(parse.coord2d_lt({x=0,y=0}, {x=0,y=10}))
    expect.true_(parse.coord2d_lt({x=0,y=10}, {x=1,y=10}))
    expect.true_(parse.coord2d_lt({x=1000,y=0}, {x=0,y=10}))

    expect.false_(parse.coord2d_lt({x=0,y=0}, {x=0,y=0}))
    expect.false_(parse.coord2d_lt({x=0,y=10}, {x=0,y=0}))
    expect.false_(parse.coord2d_lt({x=1,y=10}, {x=0,y=10}))
    expect.false_(parse.coord2d_lt({x=0,y=10}, {x=1000,y=0}))
end

function test.get_ordered_grid_cells()
    local expected = {{y=20, x=10, cell='A1', text='d1'},
                      {y=22, x=10, cell='A3', text='d3'}}
    local grid = {[20]={[10]={cell='A1', text='d1'}},
                  [22]={[10]={cell='A3', text='d3'}}}
    expect.table_eq(expected, parse.get_ordered_grid_cells(grid))

    grid = {[22]={[10]={cell='A3', text='d3'}},
            [20]={[10]={cell='A1', text='d1'}}}
    expect.table_eq(expected, parse.get_ordered_grid_cells(grid))
end

function test.parse_section_name()
    expect.table_eq({nil, nil, nil}, {parse.parse_section_name('')})
    expect.table_eq({' ', nil, ''},  {parse.parse_section_name(' ')})
    expect.table_eq({' ', nil, ''},  {parse.parse_section_name(' /')})
    expect.table_eq({nil, nil, ''},  {parse.parse_section_name('/ ')})
    expect.table_eq({' ', nil, ''},  {parse.parse_section_name(' / ')})

    expect.table_eq({'sheet', 'label', ''},
                    {parse.parse_section_name('sheet/label ')})
    expect.table_eq({' sheet ', 'label', ''},
                    {parse.parse_section_name(' sheet /label ')})
    expect.table_eq({' sheet ', nil, 'badlabel'},
                    {parse.parse_section_name(' sheet / badlabel')})
    expect.table_eq({'sheet', 'label', 'repeat(down  4)'},
                    {parse.parse_section_name('sheet/label repeat(down  4) ')})
end

function test.parse_preserve_engravings()
    expect.nil_(parse.parse_preserve_engravings(-1))
    expect.nil_(parse.parse_preserve_engravings('None'))
    expect.nil_(parse.parse_preserve_engravings('-1'))

    expect.eq(df.item_quality.Ordinary, parse.parse_preserve_engravings(0))
    expect.eq(df.item_quality.Ordinary,
              parse.parse_preserve_engravings('Ordinary'))
    expect.eq(df.item_quality.Ordinary, parse.parse_preserve_engravings('0'))

    expect.error_match('unknown engraving quality',
                       function() parse.parse_preserve_engravings(nil) end)
    expect.error_match('unknown engraving quality',
                       function() parse.parse_preserve_engravings(-2) end)
    expect.error_match('unknown engraving quality',
                       function() parse.parse_preserve_engravings('blorf') end)
    expect.error_match('parse[.]lua',
                       function() parse.parse_preserve_engravings(-2, true) end)
end

function test.quote_if_has_spaces()
    expect.eq('', parse.quote_if_has_spaces(''))
    expect.eq('abc', parse.quote_if_has_spaces('abc'))
    expect.eq('"a bc"', parse.quote_if_has_spaces('a bc'))
    expect.eq('" "', parse.quote_if_has_spaces(' '))
    expect.error(parse.quote_if_has_spaces)
end

function test.format_command()
    expect.eq('run file.csv -n /somelabel',
              parse.format_command('run', 'file.csv', '/somelabel'))
    expect.eq('"f name.xlsx"', parse.format_command(nil, 'f name.xlsx', nil))
    expect.error(function() parse.format_command(nil, nil, nil) end)
end

function test.get_next_csv_token_single_line()
    local line = '"first token",secondtoken,"blup""blip""boing",#'
    expect.table_eq({'first token', line, 15},
                    {parse.get_next_csv_token(line, 1)})
    expect.table_eq({'secondtoken', line, 27},
                    {parse.get_next_csv_token(line, 15)})
    expect.table_eq({'blup"blip"boing', line, 47},
                    {parse.get_next_csv_token(line, 27)})
    expect.table_eq({'#', line, 48}, {parse.get_next_csv_token(line, 47)})
    expect.error(function() parse.get_next_csv_token(line, nil) end)
    expect.error(function() parse.get_next_csv_token(nil, 1) end)
    expect.error(function() parse.get_next_csv_token(nil, nil) end)
end

function test.get_next_csv_token_multi_line()
    local lines = {'first,"start, ', 'middle,', ' end ",second'}
    local reassembled = 'first,"start, \nmiddle,\n end ",second'
    local i = 1
    local next_line_fn = function() i = i + 1 return lines[i] end

    expect.table_eq({'first', lines[1], 7},
                    {parse.get_next_csv_token(lines[1], 1, next_line_fn)})
    expect.eq(1, i)

    i = 1
    expect.table_eq({'start, \nmiddle,\n end ', reassembled, 31},
                    {parse.get_next_csv_token(lines[1], 7, next_line_fn)})
    expect.eq(3, i)

    i = 1
    expect.table_eq({'second', reassembled, 37},
                    {parse.get_next_csv_token(reassembled, 31, next_line_fn)})
    expect.eq(1, i)

    i = 1
    lines[3] = nil
    expect.printerr_match(
        'unterminated',
        function()
            expect.nil_(parse.get_next_csv_token(lines[1], 7, next_line_fn))
        end)
    expect.eq(3, i)
end

function test.tokenize_next_csv_line()
    local lines = {'first,"start ', 'middle', ' end ",second'}
    local i = 0
    local next_line_fn = function() i = i + 1 return lines[i] end

    i = 0
    expect.table_eq({'first', 'start \nmiddle\n end ', 'second'},
                    parse.tokenize_next_csv_line(next_line_fn, 0))
    expect.eq(3, i)

    i = 0
    expect.table_eq({'first'}, parse.tokenize_next_csv_line(next_line_fn, 1))
    expect.eq(1, i)

    i = 0
    expect.table_eq({'first', 'start \nmiddle\n end '},
                    parse.tokenize_next_csv_line(next_line_fn, 2))
    expect.eq(3, i)

    expect.nil_(parse.tokenize_next_csv_line(function() return nil end, 0))

    i = 0
    expect.error(function() parse.tokenize_next_csv_line(next_line_fn, nil) end)
    expect.error(function() parse.tokenize_next_csv_line(nil, 0) end)

    i = 0
    lines = {'a,"b",c,"d"'}
    expect.table_eq({'a','b','c','d'},
                    parse.tokenize_next_csv_line(next_line_fn, 0))

    i = 0
    lines = {',,a,,"b",,c,,"d",,'}
    expect.table_eq({'','','a','','b','','c','','d',''},
                    parse.tokenize_next_csv_line(next_line_fn, 0))
end

function test.get_marker_body()
    expect.nil_(parse.get_marker_body('#dig', 5, 'm'))
    expect.nil_(parse.get_marker_body('#dig', 5, 'g'))
    expect.nil_(parse.get_marker_body('', 1, 'marker'))
    expect.nil_(parse.get_marker_body('marker', 1, 'marker'))
    expect.nil_(parse.get_marker_body('marker(', 1, 'marker'))
    expect.nil_(parse.get_marker_body('marker)', 1, 'marker'))
    expect.nil_(parse.get_marker_body('markerother()', 1, 'marker'))
    expect.nil_(parse.get_marker_body('othermarker()', 1, 'marker'))

    expect.table_eq({7, 'body'}, {parse.get_marker_body('(body)', 1, '')})

    expect.table_eq({8, 'body'}, {parse.get_marker_body('m(body)', 1, 'm')})
    expect.table_eq({11, 'bdy'}, {parse.get_marker_body(' m ( bdy )', 1, 'm')})
    expect.table_eq({8, 'body'}, {parse.get_marker_body('m(body)else', 1, 'm')})
    expect.table_eq({8, 'body'}, {parse.get_marker_body('m(body)m(b)', 1, 'm')})
    expect.table_eq({9, 'b d'}, {parse.get_marker_body('m( b d )', 1, 'm')})

    expect.error(function() parse.get_marker_body(nil, 5, '') end)
    expect.error(function() parse.get_marker_body('#dig', 5, nil) end)
end

function test.parse_label()
    local fname = 'fname.csv'
    local values = {}

    values = {}
    expect.table_eq({false, 5},
                    {parse.parse_label('#dig notlabel()', 5, fname, values)})
    expect.table_eq({}, values)

    values = {}
    expect.printerr_match(
        'labels must start',
        function()
            expect.table_eq({true, 13},
                            {parse.parse_label('#dig label()', 5,
                                               fname, values)})
        end)
    expect.table_eq({}, values)

    -- prints error message about invalid label
    values = {}
    expect.printerr_match(
        'labels must start',
        function()
            expect.table_eq({true, 16},
                            {parse.parse_label('#dig label(a b)', 5,
                                               fname, values)})
        end)
    expect.table_eq({}, values)

    values = {}
    expect.table_eq({true, 14},
                    {parse.parse_label('#dig label(a)', 5, fname, values)})
    expect.table_eq({label='a'}, values)

    values = {}
    expect.table_eq({true, 16},
                    {parse.parse_label('#dig label(a_b)', 5, fname, values)})
    expect.table_eq({label='a_b'}, values)

    expect.error(
            function() parse.parse_label('#dig label(a)', 5, fname, nil) end)
end

function test.parse_start()
    local fname = 'fname.csv'
    local values = {}

    values = {}
    expect.table_eq({false, 5},
                    {parse.parse_start('#dig notstart()', 5, fname, values)})
    expect.table_eq({}, values)

    -- prints error message about invalid syntax
    values = {}
    expect.printerr_match(
        'start%(%) markers must',
        function()
            expect.table_eq({true, 13},
                            {parse.parse_start('#dig start()', 5,
                                               fname, values)})
        end)
    expect.table_eq({}, values)

    values = {}
    expect.table_eq({true, 20},
                    {parse.parse_start('#dig start(comment)', 5, fname, values)})
    expect.table_eq({start_comment='comment'}, values)

    values = {}
    expect.table_eq({true, 18},
                    {parse.parse_start('#dig start(1 way)', 5, fname, values)})
    expect.table_eq({start_comment='1 way'}, values)

    values = {}
    expect.table_eq({true, 20},
                    {parse.parse_start('#dig start(1 2 way)', 5, fname, values)})
    expect.table_eq({startx='1', starty='2', start_comment='way'}, values)

    values = {}
    expect.table_eq({true, 20},
                    {parse.parse_start('#dig start(1,2 way)', 5, fname, values)})
    expect.table_eq({startx='1', starty='2', start_comment='way'}, values)

    values = {}
    expect.table_eq({true, 16},
                    {parse.parse_start('#dig start(1;2)', 5, fname, values)})
    expect.table_eq({startx='1', starty='2'}, values)

    values = {}
    expect.table_eq({true, 17},
                    {parse.parse_start('#dig start(1,;2)', 5, fname, values)})
    expect.table_eq({start_comment='1,;2'}, values)

    expect.error(
            function() parse.parse_start('#dig start(way)', 5, fname, nil) end)
end

function test.parse_hidden()
    local fname = 'fname.csv'
    local values = {}

    values = {}
    expect.table_eq({false, 5},
                    {parse.parse_hidden('#dig nothidden()', 5, fname, values)})
    expect.table_eq({}, values)

    values = {}
    expect.table_eq({true, 14},
                    {parse.parse_hidden('#dig hidden()', 5, fname, values)})
    expect.table_eq({hidden=true}, values)

    values = {}
    expect.table_eq({true, 18},
                    {parse.parse_hidden('#dig hidden(smth)', 5, fname, values)})
    expect.table_eq({hidden=true}, values)

    expect.error(
            function() parse.parse_hidden('#dig hidden()', 5, fname, nil) end)
end

function test.parse_modeline_markers()
    local f = 'fname.csv'

    expect.table_eq({{}, 5}, {parse.parse_markers('#dig', 5, f,
                                                  parse.modeline_marker_fns)})
    expect.table_eq({{}, 5}, {parse.parse_markers('#dig comment', 5, f,
                                                  parse.modeline_marker_fns)})
    expect.table_eq({{}, 5}, {parse.parse_markers('#dig nomarker()', 5, f,
                                                  parse.modeline_marker_fns)})

    expect.table_eq({{hidden=true}, 14},
                    {parse.parse_markers('#dig hidden()', 5, f,
                                         parse.modeline_marker_fns)})
    expect.table_eq({{hidden=true}, 14},
                    {parse.parse_markers('#dig hidden()a', 5, f,
                                         parse.modeline_marker_fns)})
    expect.table_eq({{hidden=true}, 14},
                    {parse.parse_markers('#dig hidden()hidden()',
                                         5, f, parse.modeline_marker_fns)})
    expect.table_eq({{hidden=true}, 14},
                    {parse.parse_markers('#dig hidden()hidden() message(a)',
                                         5, f, parse.modeline_marker_fns)})
    expect.table_eq({{hidden=true, message='a'}, 25},
                    {parse.parse_markers('#dig hidden()message(a) hidden()',
                                         5, f, parse.modeline_marker_fns)})
    expect.table_eq({{hidden=true, message='a', startx='1', starty='2',
                      start_comment='startcom', label='imalabel'}, 59},
                    {parse.parse_markers(
        '#dig hidden()message(a)start(1 2 startcom)label(imalabel) modecomment',
        5, f, parse.modeline_marker_fns)})
end

function test.parse_modeline()
    f = 'fname.csv'

    expect.nil_(nil, f, 1)
    expect.nil_(parse.parse_modeline('notamodeline', f, 1))
    expect.nil_(parse.parse_modeline('#notavalidmode', f, 1))

    expect.table_eq({mode='dig', label='1'}, parse.parse_modeline('#dig', f, 1))
    expect.table_eq({mode='dig', label='9'}, parse.parse_modeline('#dig', f, 9))

    expect.table_eq({mode='dig', label='1', hidden=true},
                    parse.parse_modeline('#dig hidden()      ', f, 1))

    expect.table_eq({mode='dig', label='1', hidden=true, comment='com'},
                    parse.parse_modeline('#dig hidden()com', f, 1))
    expect.table_eq({mode='dig', label='1', hidden=true, comment='com'},
                    parse.parse_modeline('#dig hidden()com ', f, 1))
    expect.table_eq({mode='dig', label='1', hidden=true, comment='c  o  m'},
                    parse.parse_modeline('#dig hidden()  c  o  m  ', f, 1))
end

function test.parse_repeat_params()
    local modifiers = {}

    expect.error_match(
        'unknown repeat direction',
        function() parse.parse_repeat_params('', modifiers) end)
    expect.error_match(
        'unknown repeat direction',
        function() parse.parse_repeat_params('sideways 5', modifiers) end)

    parse.parse_repeat_params('up 5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('up5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('up,5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('up, 5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('  up  ,  5  ', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('< 5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('<5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('<,5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)
    parse.parse_repeat_params('<, 5', modifiers)
    expect.table_eq({repeat_zoff=1, repeat_count=5}, modifiers)

    parse.parse_repeat_params('down 50', modifiers)
    expect.table_eq({repeat_zoff=-1, repeat_count=50}, modifiers)
    parse.parse_repeat_params('>50', modifiers)
    expect.table_eq({repeat_zoff=-1, repeat_count=50}, modifiers)

    parse.parse_repeat_params('down', modifiers)
    expect.table_eq({repeat_zoff=-1, repeat_count=1}, modifiers)
    parse.parse_repeat_params('>, ', modifiers)
    expect.table_eq({repeat_zoff=-1, repeat_count=1}, modifiers)
end

function test.parse_repeat()
    local modifiers = {}

    expect.table_eq({false, 4},
                    {parse.parse_repeat('/l notrepeat()', 4, nil, modifiers)})
    expect.table_eq({true, 14},
                    {parse.parse_repeat('/l repeat(>5)', 4, nil, modifiers)})
end

function test.get_modifiers_defaults()
    local modifiers = parse.get_modifiers_defaults()
    modifiers.repeat_count = 10
    expect.eq(1, parse.get_modifiers_defaults().repeat_count)
end

function test.get_meta_modifiers()
    local fname = 'f'

    expect.table_eq({repeat_count=1, repeat_zoff=0},
                    parse.get_meta_modifiers('', fname))
    expect.table_eq({repeat_count=5, repeat_zoff=1},
                    parse.get_meta_modifiers('  repeat  ( up, 5 ) ', fname))

    expect.printerr_match('extra unparsed text',
            function() parse.get_meta_modifiers('garbage', fname) end)
    expect.printerr_match('extra unparsed text',
            function() parse.get_meta_modifiers('repeat(>5)garbage', fname) end)
end

function test.get_col_name()
    expect.eq('A', parse.get_col_name(1))
    expect.eq('B', parse.get_col_name(2))
    expect.eq('Z', parse.get_col_name(26))
    expect.eq('AA', parse.get_col_name(27))
    expect.eq('BA', parse.get_col_name(53))
    expect.eq('BZ', parse.get_col_name(78))

    expect.error(function() parse.get_col_name(nil) end)
end

function test.make_cell_label()
    expect.eq('A1', parse.make_cell_label(1, 1))
    expect.eq('A2', parse.make_cell_label(1, 2))
    expect.eq('B1', parse.make_cell_label(2, 1))
    expect.eq('BA100', parse.make_cell_label(53, 100))

    expect.error(function() parse.make_cell_label(1, nil) end)
end

function test.trim_token()
    expect.eq('', parse.trim_token(''))
    expect.eq('', parse.trim_token(' '))
    expect.eq('', parse.trim_token('        '))
    expect.eq('a', parse.trim_token('a'))
    expect.eq('a', parse.trim_token(' a'))
    expect.eq('a', parse.trim_token('  a'))
    expect.eq('a', parse.trim_token('a '))
    expect.eq('a', parse.trim_token('a  '))
    expect.eq('a', parse.trim_token('  a  '))
    expect.eq('a b', parse.trim_token('a b'))
    expect.eq('a b', parse.trim_token(' a b'))
    expect.eq('a b', parse.trim_token('a b '))
    expect.eq('a b', parse.trim_token(' a b '))
    expect.eq('a  b', parse.trim_token('a  b'))
    expect.error(function() parse.trim_token(nil) end)
end

MockReader = defclass(MockReader, quickfort_reader.Reader)
MockReader.ATTRS{lines={}, i=0,
                 open_fn=function() return {close=function() end} end}
function MockReader:reset(lines) self.lines, self.i = lines, 0 end
function MockReader:get_next_row_raw()
    self.i = self.i + 1
    return self.lines[self.i]
end

function test.process_level()
    local reader = MockReader{}
    local start = {x=10, y=20}

    expect.table_eq({{}, 0}, {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'`'},{'d'}})
    expect.table_eq(
        {{[20]={[10]={cell='A1', text='d'}},
          [22]={[10]={cell='A3', text='d'}}},
         3}, {parse.process_level(reader, 1, start)})

    reader:reset({{' d '},{' ~ '},{'  d  '}})
    expect.table_eq(
        {{[20]={[10]={cell='A1', text='d'}},
          [22]={[10]={cell='A3', text='d'}}},
         3}, {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'`','#','ignoreme'},{'d'}})
    expect.table_eq(
        {{[20]={[10]={cell='A1', text='d'}},
          [22]={[10]={cell='A3', text='d'}}},
         3}, {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'`','#comment','d'},{'d#d'}})
    expect.table_eq(
        {{[20]={[10]={cell='A1', text='d'}},
          [21]={[12]={cell='C2', text='d'}},
          [22]={[10]={cell='A3', text='d#d'}}},
         3}, {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'#<'}})
    expect.table_eq({{[20]={[10]={cell='A1', text='d'}}}, 1, 1},
                    {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'#>'}})
    expect.table_eq({{[20]={[10]={cell='A1', text='d'}}}, 1, -1},
                    {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'#<1'}})
    expect.table_eq({{[20]={[10]={cell='A1', text='d'}}}, 1, 1},
                    {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'#> 8'}})
    expect.table_eq({{[20]={[10]={cell='A1', text='d'}}}, 1, -8},
                    {parse.process_level(reader, 1, start)})

    reader:reset({{'d'},{'#dig'}})
    expect.table_eq({{[20]={[10]={cell='A1', text='d'}}}, 1},
                    {parse.process_level(reader, 1, start)})
end

function test.process_levels()
    local reader = MockReader{}
    local start = {x=10, y=20, z=30}

    -- label not found (no data)
    expect.error_match('no data found',
                       function() parse.process_levels(reader, nil, start) end)

    -- label not found (mismatch)
    reader:reset({{'#build'},{'Tl'}})
    expect.error_match('not found',
                       function() parse.process_levels(reader, '2', start) end)

    -- implicit #dig modeline
    reader:reset({{'d'}})
    expect.table_eq({{modeline={mode='dig',label='1'},
                      zlevel=30,
                      grid={[20]={[10]={cell='A1', text='d'}}}}},
                    parse.process_levels(reader, '1', start))

    -- scan to target label
    reader:reset({{'#dig'},{'d'},{'#>'},{'d'},{'#zone'},{'a(3x3)'}})
    expect.table_eq({{modeline={mode='zone',label='2'},
                      zlevel=30,
                      grid={[20]={[10]={cell='A6', text='a(3x3)'}}}}},
                    parse.process_levels(reader, '2', start))

    -- scan to target label with interim ignored sections
    reader:reset({{'#dig'},{'d'},{'#ignore'},{'#aliases'},{'#zone'},{'a(3x3)'}})
    expect.table_eq({{modeline={mode='zone',label='2'},
                      zlevel=30,
                      grid={[20]={[10]={cell='A6', text='a(3x3)'}}}}},
                    parse.process_levels(reader, '2', start))

    -- multiple levels
    reader:reset({{'#dig'},{'d'},{'#>'},{'d'},{'#>'},{'d'}})
    expect.table_eq({{modeline={mode='dig',label='1'},
                      zlevel=30,
                      grid={[20]={[10]={cell='A2', text='d'}}}},
                     {modeline={mode='dig',label='1'},
                      zlevel=29,
                      grid={[20]={[10]={cell='A4', text='d'}}}},
                     {modeline={mode='dig',label='1'},
                      zlevel=28,
                      grid={[20]={[10]={cell='A6', text='d'}}}},},
                    parse.process_levels(reader, '1', start))
end

function test.parse_alias_separate()
    expect.false_(parse.parse_alias_separate('a', 'aa', {}))
    expect.false_(parse.parse_alias_separate('::', 'aa', {}))
    expect.false_(parse.parse_alias_separate('  ', 'aa', {}))

    expect.false_(parse.parse_alias_separate(nil, 'a', {}))
    expect.false_(parse.parse_alias_separate('', 'a', {}))
    expect.false_(parse.parse_alias_separate('aa', nil, {}))
    expect.false_(parse.parse_alias_separate('aa', '', {}))
    expect.error(function() parse.parse_alias_separate('aa', 'a', nil) end)

    local aliases = {}
    expect.true_(parse.parse_alias_separate('aa', 'a', aliases))
    expect.table_eq({aa='a'}, aliases)

    aliases = {}
    expect.true_(parse.parse_alias_separate('aA_a-', 'a a', aliases))
    expect.table_eq({['aA_a-']='a a'}, aliases)
end

function test.parse_alias_combined()
    expect.false_(parse.parse_alias_combined('', {}))
    expect.false_(parse.parse_alias_combined(nil, {}))
    expect.false_(parse.parse_alias_combined(':aa:a', {}))
    expect.false_(parse.parse_alias_combined('a:a:a', {}))
    expect.error(function() parse.parse_alias_combined('aa:a', nil) end)

    local aliases = {}
    expect.true_(parse.parse_alias_combined('aa:a', aliases))
    expect.table_eq({aa='a'}, aliases)

    aliases = {}
    expect.true_(parse.parse_alias_combined('aa:     a', aliases))
    expect.table_eq({aa='a'}, aliases)
end

function test.get_sheet_metadata()
    local reader = MockReader{}

    expect.table_eq({{},{}}, {parse.get_sheet_metadata(reader)})

    -- implicit dig modeline
    reader:reset({{'d'},{'#ignore'},{'note'},{'#aliases'},{'aa:a'}})
    expect.table_eq({{{mode='dig',label='1'}},{aa='a'}},
                    {parse.get_sheet_metadata(reader)})

    -- mixed alias syntax
    reader:reset({{'#aliases'},{'aa: a'},{'ab','b'}})
    expect.table_eq({{},{aa='a',ab='b'}}, {parse.get_sheet_metadata(reader)})

    reader:reset({{'#aliases'},{'aa: a'},{'badalias'},{'ab','b'}})
    expect.printerr_match(
        {'invalid alias'},
        function()
            expect.table_eq({{},{aa='a',ab='b'}},
                            {parse.get_sheet_metadata(reader)})
        end)

    -- comment in alias section
    reader:reset({{'#aliases'},{'aa: a'},{'# comment'},{'ab','b'}})
    expect.table_eq({{},{aa='a',ab='b'}}, {parse.get_sheet_metadata(reader)})
end

function test.get_extended_token()
    expect.error(function() parse.get_extended_token('', 1) end)
    expect.error(function() parse.get_extended_token('hello', 1) end)
    expect.error(function() parse.get_extended_token('{', 1) end)
    expect.error(function() parse.get_extended_token('{}', 1) end)
    expect.error(function() parse.get_extended_token('}', 1) end)
    expect.error(function() parse.get_extended_token('{hello', 1) end)

    expect.eq('{hello }', parse.get_extended_token('aa{hello }aa', 3))
    expect.eq('{{}', parse.get_extended_token('aa{{}aa', 3))
    expect.eq('{}}', parse.get_extended_token('aa{}}aa', 3))
    expect.eq('{hello param={aa} }',
              parse.get_extended_token('aa{hello param={aa} }aa', 3))
end

function test.get_token()
    expect.table_eq({'hello', 7}, {parse.get_token('{hello}')})
    expect.table_eq({'hello', 8}, {parse.get_token('{hello 5}')})
    expect.table_eq({'Numpad 5', 10}, {parse.get_token('{Numpad 5}')})
    expect.table_eq({'Numpad 5', 12}, {parse.get_token('{Numpad 5  param=hi}')})
    expect.error(function() parse.get_token('{Numpad param=hello}') end)
end

function test.get_next_param()
    expect.table_eq({}, {parse.get_next_param('{hello 5}', 8)})
    expect.table_eq({'param', 14}, {parse.get_next_param('{hello param=}', 8)})
    expect.table_eq({'var', 12}, {parse.get_next_param('{hello var=aa}', 8)})
end

function test.get_params()
    expect.table_eq({{var='hi'}, 14}, {parse.get_params('{hello var=hi}', 8)})
    expect.table_eq({{var='hi'}, 16}, {parse.get_params('{hello var="hi"}', 8)})
    expect.table_eq({{var='{hi}'}, 16},
                    {parse.get_params('{hello var={hi}}', 8)})

    expect.table_eq({{var1='{hi1}{hi2}', var2='{alias}', var3='a  b'}, 51},
                    {parse.get_params(
                        '{hello var1="{hi1}{hi2}" var2={alias} var3="a  b" 5}',
                        8)})

    expect.error(function() parse.get_params('{hello bad_empty= }', 8) end)
    expect.printerr_match(
        {'unterminated'},
        function()
            expect.error(
                function() parse.get_params('{hello unterm_param="}', 8) end)
        end)
end

function test.get_repetitions()
    expect.table_eq({1, 7}, {parse.get_repetitions('{hello}', 7)})
    expect.table_eq({1, 7}, {parse.get_repetitions('{hello   }', 7)})
    expect.table_eq({5, 9}, {parse.get_repetitions('{hello 5}', 7)})
    expect.table_eq({5, 12}, {parse.get_repetitions('{hello 5   }', 7)})
end

function test.parse_extended_token()
    expect.table_eq({'hello', {p1='val', p2='val{other}', p3='with spaces',
                               p4='with {other} spaces',
                               p5='val{other param=val}', p6='{o1}{o2}',
                               p7='{other pp7={other2} 5}',
                               p8='{other pp8="with spaces"}'}, 15, 173},
                    {parse.parse_extended_token(
        '{hello p1=val p2=val{other} p3="with spaces"' ..
        ' p4="with {other} spaces" p5="val{other param=val}" p6="{o1}{o2}"' ..
        ' p7={other pp7={other2} 5} p8="{other pp8=""with spaces""}" 15}', 1)})
    expect.error(function() parse.parse_extended_token('{other param=}', 1) end)
end
