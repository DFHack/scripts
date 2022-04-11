local building = reqscript('internal/quickfort/building')
local quickfort_map = reqscript('internal/quickfort/map')
local b = building.unit_test_hooks

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/building') end)
end

function test.get_digit_count()
    expect.eq(1, b.get_digit_count(0))
    expect.eq(1, b.get_digit_count(1))
    expect.eq(1, b.get_digit_count(9))
    expect.eq(2, b.get_digit_count(10))
    expect.eq(2, b.get_digit_count(11))
    expect.eq(2, b.get_digit_count(99))
    expect.eq(3, b.get_digit_count(100))
    expect.eq(3, b.get_digit_count(101))
end

function test.left_pad()
    expect.eq(' 1', b.left_pad(1, 1))
    expect.eq('  1', b.left_pad(1, 2))
    expect.eq(' 10', b.left_pad(10, 2))
    expect.eq('    10', b.left_pad(10, 5))
    expect.eq(' 1000', b.left_pad(1000, 4))
    expect.eq('  1000', b.left_pad(1000, 5))
end

function test.dump_seen_grid()
    local lines = {}
    local print_wrapper = function(line) table.insert(lines, line) end
    mock.patch(
        {{building, 'print', print_wrapper}},
        function()
            b.dump_seen_grid{'empty', {}, 0}
            expect.table_eq({'boundary map (empty):'}, lines)

            lines = {}
            b.dump_seen_grid{'two ids vert',
                             {[20]={[10]=1,[11]=1,[12]=1},
                              [22]={[10]=2,[11]=2,[12]=2}},
                             2}
            expect.table_eq(
                    {'boundary map (two ids vert):',
                     ' 1   2',' 1   2',' 1   2'},
                    lines)

            lines = {}
            b.dump_seen_grid{'two ids horiz',
                             {[20]={[10]=1,[12]=2},
                              [21]={[10]=1,[12]=2},
                              [22]={[10]=1,[12]=2}},
                             2}
            expect.table_eq(
                    {'boundary map (two ids horiz):',
                     ' 1 1 1','      ',' 2 2 2'},
                    lines)

            lines = {}
            b.dump_seen_grid{'ten ids horiz',
                             {[20]={[10]=1,[12]=10},
                              [21]={[10]=1,[12]=10},
                              [22]={[10]=1,[12]=10}},
                             10}
            expect.table_eq(
                    {'boundary map (ten ids horiz):',
                     '  1  1  1','         ',' 10 10 10'},
                    lines)
        end)
end

function test.flood_fill()
    -- a D . . .
    -- e a a . .
    -- d . a c b(1x1)
    -- . . . c b
    -- . . . b b(1x3)
    local grid = {
        [20]={[10]={cell='A1',text='a'},
              [11]={cell='B1',text='D'},
              [12]=nil,[13]=nil,[14]=nil},
        [21]={[10]={cell='A2',text='e'},
              [11]={cell='B2',text='a'},
              [12]={cell='C2',text='a'},
              [13]=nil,[14]=nil},
        [22]={[10]={cell='A3',text='d'},
              [11]=nil,
              [12]={cell='C3',text='a'},
              [13]={cell='D3',text='c'},
              [14]={cell='E3',text='b(1x1)'}},
        [23]={[10]=nil,[11]=nil,[12]=nil,
              [13]={cell='D4',text='c'},
              [14]={cell='E4',text='b'}},
        [24]={[10]=nil,[11]=nil,[12]=nil,
              [13]={cell='D5',text='b'},
              [14]={cell='E5',text='b(1x3)'}},
    }
    local ctx = {transform_fn=function(pos) return pos end}
    local db = {a={}, b={}, c={}, d={}}
    local aliases = {d='a'}

    expect.eq(0, b.flood_fill(ctx, grid, 10, 20, {[10]={[20]=1}}, {}, db,
                              aliases))
    expect.eq(0, b.flood_fill(ctx, grid, 1, 1, {}, {}, db, aliases))
    expect.eq(0, b.flood_fill(ctx, grid, 12, 20, {}, {}, db, aliases))

    local seen_grid = {}
    expect.printerr_match(
        'invalid key sequence',
        function()
            expect.eq(1, b.flood_fill(ctx, grid, 10, 21, seen_grid, {}, db,
                                      aliases))
        end)
    expect.table_eq({[10]={[21]=true}}, seen_grid)

    expect.eq(0, b.flood_fill(ctx, grid, 14, 24, {}, {type='z'}, db, aliases))
    expect.eq(0, b.flood_fill(ctx, grid, 14, 24, {}, {type='b'}, db, aliases))

    local data = {id=1, cells={},
                  x_min=30000, x_max=-30000, y_min=30000, y_max=-30000}
    seen_grid = {}
    expect.eq(0, b.flood_fill(ctx, grid, 14, 24, seen_grid, data, db, aliases))
    expect.table_eq({[14]={[24]=1,[25]=1,[26]=1}}, seen_grid)
    expect.table_eq({id=1, type='b', cells={'E5'},
                     x_min=14, x_max=14, y_min=24, y_max=26},
                    data)

    -- from here on down, seen_grid is cumulative across tests
    data = {id=2, cells={},
            x_min=30000, x_max=-30000, y_min=30000, y_max=-30000}
    expect.eq(0, b.flood_fill(ctx, grid, 13, 24, seen_grid, data, db, aliases))
    expect.table_eq({[13]={[24]=2},
                     [14]={[23]=2,[24]=1,[25]=1,[26]=1}},
                    seen_grid)
    expect.table_eq({id=2, type='b', cells={'D5','E4'},
                     x_min=13, x_max=14, y_min=23, y_max=24},
                    data)

    data = {id=3, cells={},
            x_min=30000, x_max=-30000, y_min=30000, y_max=-30000}
    expect.eq(0, b.flood_fill(ctx, grid, 13, 22, seen_grid, data, db, aliases))
    expect.table_eq({[13]={[22]=3,[23]=3,[24]=2},
                     [14]={[23]=2,[24]=1,[25]=1,[26]=1}},
                    seen_grid)
    expect.table_eq({id=3, type='c', cells={'D3', 'D4'},
                     x_min=13, x_max=13, y_min=22, y_max=23},
                    data)

    data = {id=4, cells={},
            x_min=30000, x_max=-30000, y_min=30000, y_max=-30000}
    expect.printerr_match(
        'invalid key sequence',
        function()
            expect.eq(1, b.flood_fill(ctx, grid, 12, 22, seen_grid, data, db,
                                      aliases))
        end)
    expect.table_eq({[10]={[20]=4,[21]=true,[22]=4},
                     [11]={[20]=4,[21]=4},
                     [12]={[21]=4,[22]=4},
                     [13]={[22]=3,[23]=3,[24]=2},
                     [14]={[23]=2,[24]=1,[25]=1,[26]=1}},
                    seen_grid)
    expect.table_eq({id=4, type='a', cells={'C3','B2','A1','B1','C2','A3'},
                     x_min=10, x_max=12, y_min=20, y_max=22},
                    data)
end

function test.flood_fill_transform()
    local ctx = {transform_fn=function(pos) return xy2pos(pos.y, pos.x) end}
    local grid = {[1]={[1]={cell='A1',text='a(2x3)'}}}
    local seen_grid, aliases = {}, {}
    local data = {id=5, cells={},
                  x_min=30000, x_max=-30000, y_min=30000, y_max=-30000}
    local db = {a={transform=function(ctx) return 'b' end},
                b={transform=function(ctx) return 'a' end}}

    expect.eq(0, b.flood_fill(ctx, grid, 1, 1, seen_grid, data, db, aliases))

    -- expect the xy dimensions to be swapped
    local expected_seen_grid = {[1]={[1]=5, [2]=5},
                                [2]={[1]=5, [2]=5},
                                [3]={[1]=5, [2]=5}}
    -- expect the type to be changed to 'b'
    local expected_data = {id=5, cells={'A1'}, type='b',
                           x_min=1, x_max=3, y_min=1, y_max=2}
    expect.table_eq(expected_seen_grid, seen_grid)
    expect.table_eq(expected_data, data)
end

function test.swap_id_and_trim_chunk()
    local seen_grid = {[1]={[10]=4,[11]=true,[13]=4},
                       [2]={[10]=4,[11]=true,[13]=4}}
    local expected_seen_grid = {[1]={[10]=4,[11]=true,[13]=4},
                                [2]={[10]=5,[11]=true,[13]=5}}
    local chunk = {id=5, x_min=2, x_max=3, y_min=9, y_max=14}
    local expected_chunk = {id=5, x_min=2, x_max=2, y_min=10, y_max=13}
    b.swap_id_and_trim_chunk(chunk, seen_grid, 4)
    expect.table_eq(expected_seen_grid, seen_grid)
    expect.table_eq(expected_chunk, chunk)
end

function test.chunk_extents()
    -- 1 1 2 2 2 2
    -- . 2 2 2 2 .
    local data_tables = {
        {id=1, type='a', cells={}, x_min=1, x_max=2, y_min=1, y_max=1},
        {id=2, type='a', cells={}, x_min=2, x_max=6, y_min=1, y_max=2},
    }
    local seen_grid = {
        [1]={[1]=1},
        [2]={[1]=1,[2]=2},
        [3]={[1]=2,[2]=2},
        [4]={[1]=2,[2]=2},
        [5]={[1]=2,[2]=2},
        [6]={[1]=2},
    }
    local db = {a={label='typea', max_width=2, max_height=1}}
    local invert = {x=false, y=false}

    -- 1 1 4 4 2 2
    -- . 3 3 5 5 .
    local expected = {
        {id=1, type='a', cells={}, x_min=1, x_max=2, y_min=1, y_max=1},
        {id=3, type='a', cells={}, x_min=2, x_max=3, y_min=2, y_max=2},
        {id=4, type='a', cells={}, x_min=3, x_max=4, y_min=1, y_max=1},
        {id=5, type='a', cells={}, x_min=4, x_max=5, y_min=2, y_max=2},
        {id=2, type='a', cells={}, x_min=5, x_max=6, y_min=1, y_max=1},
    }
    local expected_seen_grid = {
        [1]={[1]=1},
        [2]={[1]=1,[2]=3},
        [3]={[1]=4,[2]=3},
        [4]={[1]=4,[2]=5},
        [5]={[1]=2,[2]=5},
        [6]={[1]=2},
    }
    expect.table_eq(expected,
                    b.chunk_extents(data_tables, seen_grid, db, invert))
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.chunk_extents_invert_x()
    -- 2 2 2 2 1 1
    -- . 2 2 2 2 .
    local data_tables = {
        {id=1, type='a', cells={}, x_min=5, x_max=6, y_min=1, y_max=1},
        {id=2, type='a', cells={}, x_min=1, x_max=5, y_min=1, y_max=2},
    }
    local seen_grid = {
        [1]={[1]=2},
        [2]={[1]=2,[2]=2},
        [3]={[1]=2,[2]=2},
        [4]={[1]=2,[2]=2},
        [5]={[1]=1,[2]=2},
        [6]={[1]=1},
    }
    local db = {a={label='typea', max_width=2, max_height=1}}
    local invert = {x=true, y=false}

    -- 2 2 4 4 1 1
    -- . 5 5 3 3 .
    local expected = {
        {id=1, type='a', cells={}, x_min=5, x_max=6, y_min=1, y_max=1},
        {id=3, type='a', cells={}, x_min=4, x_max=5, y_min=2, y_max=2},
        {id=4, type='a', cells={}, x_min=3, x_max=4, y_min=1, y_max=1},
        {id=5, type='a', cells={}, x_min=2, x_max=3, y_min=2, y_max=2},
        {id=2, type='a', cells={}, x_min=1, x_max=2, y_min=1, y_max=1},
    }
    local expected_seen_grid = {
        [1]={[1]=2},
        [2]={[1]=2,[2]=5},
        [3]={[1]=4,[2]=5},
        [4]={[1]=4,[2]=3},
        [5]={[1]=1,[2]=3},
        [6]={[1]=1},
    }
    expect.table_eq(expected,
                    b.chunk_extents(data_tables, seen_grid, db, invert))
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.chunk_extents_invert_y()
    -- . 2 2 2 2 .
    -- 1 1 2 2 2 2
    local data_tables = {
        {id=1, type='a', cells={}, x_min=1, x_max=2, y_min=2, y_max=2},
        {id=2, type='a', cells={}, x_min=2, x_max=6, y_min=1, y_max=2},
    }
    local seen_grid = {
        [1]={[2]=1},
        [2]={[2]=1,[1]=2},
        [3]={[2]=2,[1]=2},
        [4]={[2]=2,[1]=2},
        [5]={[2]=2,[1]=2},
        [6]={[2]=2},
    }
    local db = {a={label='typea', max_width=2, max_height=1}}
    local invert = {x=false, y=true}

    -- . 3 3 5 5 .
    -- 1 1 4 4 2 2
    local expected = {
        {id=1, type='a', cells={}, x_min=1, x_max=2, y_min=2, y_max=2},
        {id=3, type='a', cells={}, x_min=2, x_max=3, y_min=1, y_max=1},
        {id=4, type='a', cells={}, x_min=3, x_max=4, y_min=2, y_max=2},
        {id=5, type='a', cells={}, x_min=4, x_max=5, y_min=1, y_max=1},
        {id=2, type='a', cells={}, x_min=5, x_max=6, y_min=2, y_max=2},
    }
    local expected_seen_grid = {
        [1]={[2]=1},
        [2]={[2]=1,[1]=3},
        [3]={[2]=4,[1]=3},
        [4]={[2]=4,[1]=5},
        [5]={[2]=2,[1]=5},
        [6]={[2]=2},
    }
    expect.table_eq(expected,
                    b.chunk_extents(data_tables, seen_grid, db, invert))
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.chunk_extents_invert_xy()
    -- . 2 2 2 2 .
    -- 2 2 2 2 1 1
    local data_tables = {
        {id=1, type='a', cells={}, x_min=5, x_max=6, y_min=2, y_max=2},
        {id=2, type='a', cells={}, x_min=1, x_max=5, y_min=1, y_max=2},
    }
    local seen_grid = {
        [1]={[2]=2},
        [2]={[2]=2,[1]=2},
        [3]={[2]=2,[1]=2},
        [4]={[2]=2,[1]=2},
        [5]={[2]=1,[1]=2},
        [6]={[2]=1},
    }
    local db = {a={label='typea', max_width=2, max_height=1}}
    local invert = {x=true, y=false}

    -- . 5 5 3 3 .
    -- 2 2 4 4 1 1
    local expected = {
        {id=1, type='a', cells={}, x_min=5, x_max=6, y_min=2, y_max=2},
        {id=3, type='a', cells={}, x_min=4, x_max=5, y_min=1, y_max=1},
        {id=4, type='a', cells={}, x_min=3, x_max=4, y_min=2, y_max=2},
        {id=5, type='a', cells={}, x_min=2, x_max=3, y_min=1, y_max=1},
        {id=2, type='a', cells={}, x_min=1, x_max=2, y_min=2, y_max=2},
    }
    local expected_seen_grid = {
        [1]={[2]=2},
        [2]={[2]=2,[1]=5},
        [3]={[2]=4,[1]=5},
        [4]={[2]=4,[1]=3},
        [5]={[2]=1,[1]=3},
        [6]={[2]=1},
    }
    expect.table_eq(expected,
                    b.chunk_extents(data_tables, seen_grid, db, invert))
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.expand_buildings()
    -- ~ 1 ~ ~ ~ ~
    -- . . 2 ~ 3 ~
    -- . . . ~ ~ ~
    local data_tables = {
        {id=1, type='a', cells={}, x_min=2, x_max=2, y_min=1, y_max=1},
        {id=2, type='b', cells={}, x_min=3, x_max=3, y_min=2, y_max=2},
        {id=3, type='c', cells={}, x_min=5, x_max=5, y_min=2, y_max=2},
    }
    local seen_grid = {
        [2]={[1]=1},
        [3]={[2]=2},
        [5]={[2]=3},
    }
    local db = {
        a={label='typea', min_width=2, min_height=1},
        b={label='typeb', min_width=1, min_height=2},
        c={label='typec', min_width=3, min_height=3},
    }
    local invert = {x=false, y=false}

    -- 1 1 2 3 3 3
    -- . . 2 3 3 3
    -- . . . 3 3 3
    local expected = {
        {id=1, type='a', cells={}, x_min=1, x_max=2, y_min=1, y_max=1},
        {id=2, type='b', cells={}, x_min=3, x_max=3, y_min=1, y_max=2},
        {id=3, type='c', cells={}, x_min=4, x_max=6, y_min=1, y_max=3},
    }
    local expected_seen_grid = {
        [1]={[1]=1},
        [2]={[1]=1},
        [3]={[1]=2,[2]=2},
        [4]={[1]=3,[2]=3,[3]=3},
        [5]={[1]=3,[2]=3,[3]=3},
        [6]={[1]=3,[2]=3,[3]=3},
    }
    b.expand_buildings(data_tables, seen_grid, db, invert)
    expect.table_eq(expected, data_tables)
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.expand_buildings_invert_x()
    -- ~ ~ ~ ~ 1 ~
    -- ~ 3 ~ 2 . .
    -- ~ ~ ~ . . .
    local data_tables = {
        {id=1, type='a', cells={}, x_min=5, x_max=5, y_min=1, y_max=1},
        {id=2, type='b', cells={}, x_min=4, x_max=4, y_min=2, y_max=2},
        {id=3, type='c', cells={}, x_min=2, x_max=2, y_min=2, y_max=2},
    }
    local seen_grid = {
        [2]={[2]=3},
        [4]={[2]=2},
        [5]={[1]=1},
    }
    local db = {
        a={label='typea', min_width=2, min_height=1},
        b={label='typeb', min_width=1, min_height=2},
        c={label='typec', min_width=3, min_height=3},
    }
    local invert = {x=true, y=false}

    -- 3 3 3 2 1 1
    -- 3 3 3 2 . .
    -- 3 3 3 . . .
    local expected = {
        {id=1, type='a', cells={}, x_min=5, x_max=6, y_min=1, y_max=1},
        {id=2, type='b', cells={}, x_min=4, x_max=4, y_min=1, y_max=2},
        {id=3, type='c', cells={}, x_min=1, x_max=3, y_min=1, y_max=3},
    }
    local expected_seen_grid = {
        [6]={[1]=1},
        [5]={[1]=1},
        [4]={[1]=2,[2]=2},
        [3]={[1]=3,[2]=3,[3]=3},
        [2]={[1]=3,[2]=3,[3]=3},
        [1]={[1]=3,[2]=3,[3]=3},
    }
    b.expand_buildings(data_tables, seen_grid, db, invert)
    expect.table_eq(expected, data_tables)
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.expand_buildings_invert_y()
    -- . . . ~ ~ ~
    -- . . 2 ~ 3 ~
    -- ~ 1 ~ ~ ~ ~
    local data_tables = {
        {id=1, type='a', cells={}, x_min=2, x_max=2, y_min=3, y_max=3},
        {id=2, type='b', cells={}, x_min=3, x_max=3, y_min=2, y_max=2},
        {id=3, type='c', cells={}, x_min=5, x_max=5, y_min=2, y_max=2},
    }
    local seen_grid = {
        [2]={[3]=1},
        [3]={[2]=2},
        [5]={[2]=3},
    }
    local db = {
        a={label='typea', min_width=2, min_height=1},
        b={label='typeb', min_width=1, min_height=2},
        c={label='typec', min_width=3, min_height=3},
    }
    local invert = {x=false, y=true}

    -- . . . 3 3 3
    -- . . 2 3 3 3
    -- 1 1 2 3 3 3
    local expected = {
        {id=1, type='a', cells={}, x_min=1, x_max=2, y_min=3, y_max=3},
        {id=2, type='b', cells={}, x_min=3, x_max=3, y_min=2, y_max=3},
        {id=3, type='c', cells={}, x_min=4, x_max=6, y_min=1, y_max=3},
    }
    local expected_seen_grid = {
        [1]={[3]=1},
        [2]={[3]=1},
        [3]={[2]=2,[3]=2},
        [4]={[1]=3,[2]=3,[3]=3},
        [5]={[1]=3,[2]=3,[3]=3},
        [6]={[1]=3,[2]=3,[3]=3},
    }
    b.expand_buildings(data_tables, seen_grid, db, invert)
    expect.table_eq(expected, data_tables)
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.expand_buildings_invert_xy()
    -- ~ ~ ~ . . .
    -- ~ 3 ~ 2 . .
    -- ~ ~ ~ ~ 1 ~
    local data_tables = {
        {id=1, type='a', cells={}, x_min=5, x_max=5, y_min=3, y_max=3},
        {id=2, type='b', cells={}, x_min=4, x_max=4, y_min=2, y_max=2},
        {id=3, type='c', cells={}, x_min=2, x_max=2, y_min=2, y_max=2},
    }
    local seen_grid = {
        [2]={[2]=3},
        [4]={[2]=2},
        [5]={[3]=1},
    }
    local db = {
        a={label='typea', min_width=2, min_height=1},
        b={label='typeb', min_width=1, min_height=2},
        c={label='typec', min_width=3, min_height=3},
    }
    local invert = {x=true, y=true}

    -- 3 3 3 . . .
    -- 3 3 3 2 . .
    -- 3 3 3 2 1 1
    local expected = {
        {id=1, type='a', cells={}, x_min=5, x_max=6, y_min=3, y_max=3},
        {id=2, type='b', cells={}, x_min=4, x_max=4, y_min=2, y_max=3},
        {id=3, type='c', cells={}, x_min=1, x_max=3, y_min=1, y_max=3},
    }
    local expected_seen_grid = {
        [6]={[3]=1},
        [5]={[3]=1},
        [4]={[3]=2,[2]=2},
        [3]={[1]=3,[2]=3,[3]=3},
        [2]={[1]=3,[2]=3,[3]=3},
        [1]={[1]=3,[2]=3,[3]=3},
    }
    b.expand_buildings(data_tables, seen_grid, db, invert)
    expect.table_eq(expected, data_tables)
    expect.table_eq(expected_seen_grid, seen_grid)
end

function test.build_extent_grid()
    -- 1 . 1
    -- 2 1 .
    -- 2 2 2
    -- . 1 .
    local seen_grid = {
        [10]={[20]=1,[21]=2,[22]=2},
        [11]={       [21]=1,[22]=2,[23]=1},
        [12]={[20]=1,       [22]=2},
    }
    expect.table_eq({nil, false},
                    {b.build_extent_grid(seen_grid,
                            {id=3, x_min=10, x_max=12, y_min=20, y_max=22})})
    expect.table_eq({nil, false},
                    {b.build_extent_grid(seen_grid,
                            {id=1, x_min=11, x_max=11, y_min=20, y_max=20})})
    expect.table_eq({nil, false},
                    {b.build_extent_grid(seen_grid,
                            {id=1, x_min=10, x_max=10, y_min=21, y_max=21})})

    expect.table_eq({{[1]={[1]=true},[2]={[2]=true,[4]=true},[3]={[1]=true}},
                     false},
                    {b.build_extent_grid(seen_grid,
                            {id=1, x_min=10, x_max=12, y_min=20, y_max=23})})

    expect.table_eq({{[1]={[1]=true},[2]={},[3]={[1]=true}},
                     false},
                    {b.build_extent_grid(seen_grid,
                            {id=1, x_min=10, x_max=12, y_min=20, y_max=20})})

    expect.table_eq({{[1]={[1]=true,[3]=true}}, false},
                    {b.build_extent_grid(seen_grid,
                            {id=1, x_min=11, x_max=11, y_min=21, y_max=23})})

    expect.table_eq({{[1]={[1]=true}}, true},
                    {b.build_extent_grid(seen_grid,
                            {id=1, x_min=10, x_max=10, y_min=20, y_max=20})})
end

function test.init_buildings()
    local ctx = {transform_fn=function(pos) return pos end}
    local zlevel = 5

    -- one building completely covering another in the flood fill stage
    local grid = {
        [20]={[10]={cell='A1',text='a(2x1)'},
              [11]={cell='B1',text='a'}}
    }
    local db = {a={label='a',min_width=1,max_width=2,min_height=1,max_height=2}}
    local buildings = {}
    local expected = {
        type='a',
        cells={'A1'},
        pos={x=10, y=20, z=5},
        width=2, height=1,
        extent_grid={[1]={[1]=true},[2]={[1]=true}}
    }
    expect.eq(0, b.init_buildings(ctx, zlevel, grid, buildings, db))
    expect.table_eq({expected}, buildings)

    -- one building preventing another from expanding
    grid = {
        [20]={[10]={cell='A1',text='a'},
              [11]={cell='B1',text='b'}}
    }
    db = {a={label='a',min_width=1,max_width=1,min_height=1,max_height=1},
          b={label='b',min_width=3,max_width=3,min_height=3,max_height=3}}
    buildings = {}
    expected = {
        type='a',
        cells={'A1'},
        pos={x=10, y=20, z=5},
        width=1, height=1,
        extent_grid={[1]={[1]=true}}
    }
    expect.printerr_match(
        'taken by adjacent structures',
        function()
            expect.eq(0, b.init_buildings(ctx, zlevel, grid, buildings, db))
        end)

    expect.table_eq({expected}, buildings)
end

function test.count_extent_tiles()
    expect.eq(0, b.count_extent_tiles({}, 0, 0))
    expect.eq(0, b.count_extent_tiles({[1]={}}, 1, 1))
    expect.eq(0, b.count_extent_tiles({[1]={},[2]={},[3]={}}, 3, 1))

    expect.eq(7, b.count_extent_tiles({[1]={[1]=true,[2]=true,[3]=true},
                                       [2]={[1]=true},
                                       [3]={[1]=true,[2]=true,[3]=true}}, 3, 3))

    expect.eq(7, b.count_extent_tiles({[1]={[1]=true,[2]=true,[3]=true},
                                       [2]={[3]=true},
                                       [3]={[1]=true,[2]=true,[3]=true}}, 3, 3))
end

function test.trim_empty_cols()
    local bld = {width=1, height=1, pos={x=0,y=0,z=0},
                 extent_grid={[1]={[1]=true}}}
    b.trim_empty_cols(bld)
    expect.table_eq({width=1, height=1, pos={x=0,y=0,z=0},
                     extent_grid={[1]={[1]=true}}},
                    bld, 'no trim, single tile')

    bld = {width=3, height=3, pos={x=0,y=0,z=0},
           extent_grid={[1]={[1]=true,[3]=true},
                        [2]={},
                        [3]={[1]=true,[3]=true}}}
    b.trim_empty_cols(bld)
    expect.table_eq({width=3, height=3, pos={x=0,y=0,z=0},
                     extent_grid={[1]={[1]=true,[3]=true},
                                  [2]={},
                                  [3]={[1]=true,[3]=true}}},
                    bld, 'no trim, hollow center cross')

    bld = {width=3, height=3, pos={x=0,y=0,z=0},
           extent_grid={[1]={},
                        [2]={[2]=true},
                        [3]={}}}
    b.trim_empty_cols(bld)
    expect.table_eq({width=1, height=3, pos={x=1,y=0,z=0},
                     extent_grid={[1]={[2]=true}}},
                    bld, 'trim 1 left, 1 right')

    bld = {width=5, height=5, pos={x=0,y=0,z=0},
           extent_grid={[1]={},
                        [2]={},
                        [3]={[3]=true},
                        [4]={},
                        [5]={}}}
    b.trim_empty_cols(bld)
    expect.table_eq({width=1, height=5, pos={x=2,y=0,z=0},
                     extent_grid={[1]={[3]=true}}},
                    bld, 'trim 2 left, 2 right')
end

function test.trim_empty_rows()
    local bld = {width=1, height=1, pos={x=0,y=0,z=0},
                 extent_grid={[1]={[1]=true}}}
    b.trim_empty_rows(bld)
    expect.table_eq({width=1, height=1, pos={x=0,y=0,z=0},
                     extent_grid={[1]={[1]=true}}},
                    bld, 'no trim, single tile')

    bld = {width=3, height=3, pos={x=0,y=0,z=0},
           extent_grid={[1]={[1]=true,[3]=true},
                        [2]={},
                        [3]={[1]=true,[3]=true}}}
    b.trim_empty_rows(bld)
    expect.table_eq({width=3, height=3, pos={x=0,y=0,z=0},
                     extent_grid={[1]={[1]=true,[3]=true},
                                  [2]={},
                                  [3]={[1]=true,[3]=true}}},
                    bld, 'no trim, hollow center cross')

    bld = {width=3, height=3, pos={x=0,y=0,z=0},
           extent_grid={[1]={},
                        [2]={[2]=true},
                        [3]={}}}
    b.trim_empty_rows(bld)
    expect.table_eq({width=3, height=1, pos={x=0,y=1,z=0},
                     extent_grid={[1]={},
                                  [2]={[1]=true},
                                  [3]={}}},
                    bld, 'trim 1 top, 1 bottom')

    bld = {width=5, height=5, pos={x=0,y=0,z=0},
           extent_grid={[1]={},
                        [2]={},
                        [3]={[3]=true},
                        [4]={},
                        [5]={}}}
    b.trim_empty_rows(bld)
    expect.table_eq({width=5, height=1, pos={x=0,y=2,z=0},
                     extent_grid={[1]={},
                                  [2]={},
                                  [3]={[1]=true},
                                  [4]={},
                                  [5]={}}},
                    bld, 'trim 2 top, 2 bottom')
end

function test.has_area()
    expect.true_(b.has_area{width=1, height=1})
    expect.true_(b.has_area{width=10, height=1})
    expect.true_(b.has_area{width=1, height=10})
    expect.true_(b.has_area{width=10, height=10})
    expect.false_(b.has_area{width=0, height=1})
    expect.false_(b.has_area{width=1, height=0})
    expect.false_(b.has_area{width=0, height=0})
    expect.false_(b.has_area{width=1, height=-1})
    expect.false_(b.has_area{width=-1, height=1})
end

function test.clear_building()
    local bld = {width=5, height=1, pos={x=0,y=2,z=0}, extent_grid={[1]={}},
                 canary='bird'}
    b.clear_building(bld)
    expect.table_eq({width=0, height=0, extent_grid={}, canary='bird'}, bld)
end

function test.crop_to_bounds()
    local ctx = {bounds=quickfort_map.MapBoundsChecker{dims={x=3,y=3,z=1}}}
    local db = {a={min_width=1, min_height=1},
                b={min_width=3, min_height=3}}

    -- assumes input bitmap represents a 3x3 building
    local function get_buildings(type, bitmap, x, y, z)
        local extent_grid = {}
        for y=1,3 do for x = 1,3 do
            if bitmap[y][x] ~= '' then
                if not extent_grid[x] then extent_grid[x] = {} end
                extent_grid[x][y] = true
            end
        end end
        return {
            {type=type, cells={'A1'}, width=3, height=3, pos={x=x, y=y, z=z},
                extent_grid=extent_grid}
        }
    end

    local function do_crop_to_bounds_tests(type, bitmap, tests)
        for _,t in ipairs(tests) do
            local buildings = get_buildings(
                type, bitmap, t.xmod or 0, t.ymod or 0, t.zmod or 0)
            expect.eq(t.expected_cropped,
                      b.crop_to_bounds(ctx, buildings, db),
                      t.name)

            local expected_building = copyall(t.expected_building or {})
            expected_building.type = type
            expected_building.cells = {'A1'}
            if not expected_building.pos then
                expected_building.width = 0
                expected_building.height = 0
                expected_building.extent_grid = {}
            end
            expect.table_eq({expected_building}, buildings, t.name)
        end
    end

    local bitmap = {
        {'a','a','a'},
        {'a','' ,'a'},
        {'a','' ,'a'},
    }
    do_crop_to_bounds_tests('a', bitmap, {
        {name='a1_no_crop', expected_cropped=0,
         expected_building={width=3, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                                         [2]={[1]=true},
                                         [3]={[1]=true,[2]=true,[3]=true}}}},
        {name='a1_shift_above', zmod=-1, expected_cropped=7},
        {name='a1_shift_up', ymod=-1, expected_cropped=3,
         expected_building={width=3, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={},
                                         [3]={[1]=true,[2]=true}}}},
        {name='a1_shift_down', ymod=1, expected_cropped=2,
         expected_building={width=3, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[1]=true},
                                         [3]={[1]=true,[2]=true}}}},
        {name='a1_shift_left', xmod=-1, expected_cropped=3,
         expected_building={width=2, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true,[2]=true,[3]=true}}}},
        {name='a1_shift_right', xmod=1, expected_cropped=3,
         expected_building={width=2, height=3, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                                         [2]={[1]=true}}}},
        {name='a1_shift_up_left', xmod=-1, ymod=-1, expected_cropped=5,
         expected_building={width=1, height=2, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true}}}},
        {name='a1_shift_up_right', xmod=1, ymod=-1, expected_cropped=5,
         expected_building={width=1, height=2, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true}}}},
        {name='a1_shift_down_left', xmod=-1, ymod=1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true,[2]=true}}}},
        {name='a1_shift_down_right', xmod=1, ymod=1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=1, y=1, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[1]=true}}}},
        {name='a1_shift_out_up', ymod=-10, expected_cropped=7},
        {name='a1_shift_out_down', ymod=10, expected_cropped=7},
        {name='a1_shift_out_left', xmod=-10, expected_cropped=7},
        {name='a1_shift_out_right', xmod=10, expected_cropped=7},
    })

    bitmap = {
        {'a','' ,'a'},
        {'a','' ,'a'},
        {'a','a','a'},
    }
    do_crop_to_bounds_tests('a', bitmap, {
        {name='a2_no_crop', expected_cropped=0,
         expected_building={width=3, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                                         [2]={[3]=true},
                                         [3]={[1]=true,[2]=true,[3]=true}}}},
        {name='a2_shift_above', zmod=-1, expected_cropped=7},
        {name='a2_shift_up', ymod=-1, expected_cropped=2,
         expected_building={width=3, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[2]=true},
                                         [3]={[1]=true,[2]=true}}}},
        {name='a2_shift_down', ymod=1, expected_cropped=3,
         expected_building={width=3, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={},
                                         [3]={[1]=true,[2]=true}}}},
        {name='a2_shift_left', xmod=-1, expected_cropped=3,
         expected_building={width=2, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[3]=true},
                                         [2]={[1]=true,[2]=true,[3]=true}}}},
        {name='a2_shift_right', xmod=1, expected_cropped=3,
         expected_building={width=2, height=3, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                                         [2]={[3]=true}}}},
        {name='a2_shift_up_left', xmod=-1, ymod=-1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[1]=true,[2]=true}}}},
        {name='a2_shift_up_right', xmod=1, ymod=-1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[2]=true}}}},
        {name='a2_shift_down_left', xmod=-1, ymod=1, expected_cropped=5,
         expected_building={width=1, height=2, pos={x=1, y=1, z=0},
                            extent_grid={[1]={[1]=true,[2]=true}}}},
        {name='a2_shift_down_right', xmod=1, ymod=1, expected_cropped=5,
         expected_building={width=1, height=2, pos={x=1, y=1, z=0},
                            extent_grid={[1]={[1]=true,[2]=true}}}},
        {name='a2_shift_out_up', ymod=-10, expected_cropped=7},
        {name='a2_shift_out_down', ymod=10, expected_cropped=7},
        {name='a2_shift_out_left', xmod=-10, expected_cropped=7},
        {name='a2_shift_out_right', xmod=10, expected_cropped=7},
    })

    bitmap = {
        {'a','a','a'},
        {'a','' ,'' },
        {'a','a','a'},
    }
    do_crop_to_bounds_tests('a', bitmap, {
        {name='a3_no_crop', expected_cropped=0,
         expected_building={width=3, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                                         [2]={[1]=true,[3]=true},
                                         [3]={[1]=true,[3]=true}}}},
        {name='a3_shift_above', zmod=-1, expected_cropped=7},
        {name='a3_shift_up', ymod=-1, expected_cropped=3,
         expected_building={width=3, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[2]=true},
                                         [3]={[2]=true}}}},
        {name='a3_shift_down', ymod=1, expected_cropped=3,
         expected_building={width=3, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[1]=true},
                                         [3]={[1]=true}}}},
        {name='a3_shift_left', xmod=-1, expected_cropped=3,
         expected_building={width=2, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[3]=true},
                                         [2]={[1]=true,[3]=true}}}},
        {name='a3_shift_right', xmod=1, expected_cropped=2,
         expected_building={width=2, height=3, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                                         [2]={[1]=true,[3]=true}}}},
        {name='a3_shift_up_left', xmod=-1, ymod=-1, expected_cropped=5,
         expected_building={width=2, height=1, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true}}}},
        {name='a3_shift_up_right', xmod=1, ymod=-1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[2]=true}}}},
        {name='a3_shift_down_left', xmod=-1, ymod=1, expected_cropped=5,
         expected_building={width=2, height=1, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true}}}},
        {name='a3_shift_down_right', xmod=1, ymod=1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=1, y=1, z=0},
                            extent_grid={[1]={[1]=true,[2]=true},
                                         [2]={[1]=true}}}},
        {name='a3_shift_out_up', ymod=-10, expected_cropped=7},
        {name='a3_shift_out_down', ymod=10, expected_cropped=7},
        {name='a3_shift_out_left', xmod=-10, expected_cropped=7},
        {name='a3_shift_out_right', xmod=10, expected_cropped=7},
    })

    bitmap = {
        {'a','a','a'},
        {'' ,'' ,'a'},
        {'a','a','a'},
    }
    do_crop_to_bounds_tests('a', bitmap, {
        {name='a4_no_crop', expected_cropped=0,
         expected_building={width=3, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[3]=true},
                                         [2]={[1]=true,[3]=true},
                                         [3]={[1]=true,[2]=true,[3]=true}}}},
        {name='a4_shift_above', zmod=-1, expected_cropped=7},
        {name='a4_shift_up', ymod=-1, expected_cropped=3,
         expected_building={width=3, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[2]=true},
                                         [3]={[1]=true,[2]=true}}}},
        {name='a4_shift_down', ymod=1, expected_cropped=3,
         expected_building={width=3, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true},
                                         [3]={[1]=true,[2]=true}}}},
        {name='a4_shift_left', xmod=-1, expected_cropped=2,
         expected_building={width=2, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[3]=true},
                                         [2]={[1]=true,[2]=true,[3]=true}}}},
        {name='a4_shift_right', xmod=1, expected_cropped=3,
         expected_building={width=2, height=3, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true,[3]=true},
                                         [2]={[1]=true,[3]=true}}}},
        {name='a4_shift_up_left', xmod=-1, ymod=-1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[1]=true,[2]=true}}}},
        {name='a4_shift_up_right', xmod=1, ymod=-1, expected_cropped=5,
         expected_building={width=2, height=1, pos={x=1, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true}}}},
        {name='a4_shift_down_left', xmod=-1, ymod=1, expected_cropped=4,
         expected_building={width=2, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true,[2]=true}}}},
        {name='a4_shift_down_right', xmod=1, ymod=1, expected_cropped=5,
         expected_building={width=2, height=1, pos={x=1, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[1]=true}}}},
        {name='a4_shift_out_up', ymod=-10, expected_cropped=7},
        {name='a4_shift_out_down', ymod=10, expected_cropped=7},
        {name='a4_shift_out_left', xmod=-10, expected_cropped=7},
        {name='a4_shift_out_right', xmod=10, expected_cropped=7},
    })

    bitmap = {
        {'' ,'a','' },
        {'a','' ,'a'},
        {'' ,'a','' },
    }
    do_crop_to_bounds_tests('a', bitmap, {
        {name='a5_no_crop', expected_cropped=0,
         expected_building={width=3, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[1]=true,[3]=true},
                                         [3]={[2]=true}}}},
        {name='a5_shift_above', zmod=-1, expected_cropped=4},
        {name='a5_shift_up', ymod=-1, expected_cropped=1,
         expected_building={width=3, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[2]=true},
                                         [3]={[1]=true}}}},
        {name='a5_shift_down', ymod=1, expected_cropped=1,
         expected_building={width=3, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[1]=true},
                                         [3]={[2]=true}}}},
        {name='a5_shift_left', xmod=-1, expected_cropped=1,
         expected_building={width=2, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[3]=true},
                                         [2]={[2]=true}}}},
        {name='a5_shift_right', xmod=1, expected_cropped=1,
         expected_building={width=2, height=3, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[1]=true,[3]=true}}}},
        {name='a5_shift_up_left', xmod=-1, ymod=-1, expected_cropped=2,
         expected_building={width=2, height=2, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[1]=true}}}},
        {name='a5_shift_up_right', xmod=1, ymod=-1, expected_cropped=2,
         expected_building={width=2, height=2, pos={x=1, y=0, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[2]=true}}}},
        {name='a5_shift_down_left', xmod=-1, ymod=1, expected_cropped=2,
         expected_building={width=2, height=2, pos={x=0, y=1, z=0},
                            extent_grid={[1]={[1]=true},
                                         [2]={[2]=true}}}},
        {name='a5_shift_down_right', xmod=1, ymod=1, expected_cropped=2,
         expected_building={width=2, height=2, pos={x=1, y=1, z=0},
                            extent_grid={[1]={[2]=true},
                                         [2]={[1]=true}}}},
        {name='a5_shift_out_up', ymod=-10, expected_cropped=4},
        {name='a5_shift_out_down', ymod=10, expected_cropped=4},
        {name='a5_shift_out_left', xmod=-10, expected_cropped=4},
        {name='a5_shift_out_right', xmod=10, expected_cropped=4},
    })

    bitmap = {
        {'b','b','b'},
        {'b','b','b'},
        {'b','b','b'},
    }
    do_crop_to_bounds_tests('b', bitmap, {
        {name='b_no_crop', expected_cropped=0,
         expected_building={width=3, height=3, pos={x=0, y=0, z=0},
                            extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                                         [2]={[1]=true,[2]=true,[3]=true},
                                         [3]={[1]=true,[2]=true,[3]=true}}}},
        {name='b_shift_above', zmod=-1, expected_cropped=9},
        {name='b_shift_up', ymod=-1, expected_cropped=9},
        {name='b_shift_down', ymod=1, expected_cropped=9},
        {name='b_shift_left', xmod=-1, expected_cropped=9},
        {name='b_shift_right', xmod=1, expected_cropped=9},
        {name='b_shift_up_left', xmod=-1, ymod=-1, expected_cropped=9},
        {name='b_shift_up_right', xmod=1, ymod=-1, expected_cropped=9},
        {name='b_shift_down_left', xmod=-1, ymod=1, expected_cropped=9},
        {name='b_shift_down_right', xmod=1, ymod=1, expected_cropped=9},
        {name='b_shift_out_up', ymod=-10, expected_cropped=9},
        {name='b_shift_out_down', ymod=10, expected_cropped=9},
        {name='b_shift_out_left', xmod=-10, expected_cropped=9},
        {name='b_shift_out_right', xmod=10, expected_cropped=9},
    })
end

function test.check_tiles_and_extents()
    local ctx = {}
    expect.eq(0, b.check_tiles_and_extents(ctx, {}, {}), 'no buildings')
    expect.eq(0, b.check_tiles_and_extents(ctx, {{'no pos'}},{}),
                                           'invalid building')

    local valid_tiles = {}
    local function is_valid_tile(pos)
        return valid_tiles[pos.z] and valid_tiles[pos.z][pos.x]
            and valid_tiles[pos.z][pos.x][pos.y]
    end

    local db = {a={is_valid_tile_fn=is_valid_tile,
                   is_valid_extent_fn=function(bld) return true end},
                b={is_valid_tile_fn=is_valid_tile,
                   is_valid_extent_fn=function(bld) return false end}}

    local bld = {type='a', pos={x=0, y=0, z=0}, width=1, height=1,
                 extent_grid={[1]={[1]=true}}}
    valid_tiles[0] = {[0]={[0]=true}}
    expect.eq(0, b.check_tiles_and_extents(ctx, {bld}, db), 'one valid tile')
    expect.table_eq({[1]={[1]=true}}, bld.extent_grid)

    bld = {type='a', pos={x=0, y=0, z=0}, width=1, height=1,
           extent_grid={[1]={[1]=true}}}
    valid_tiles = {}
    expect.eq(1, b.check_tiles_and_extents(ctx, {bld}, db), 'one invalid tile')
    expect.table_eq({[1]={[1]=false}}, bld.extent_grid)

    bld = {type='a', pos={x=1, y=1, z=1}, width=3, height=3,
           extent_grid={[1]={[2]=true},
                        [2]={},
                        [3]={[1]=true,[3]=true}}}
    valid_tiles[1] = {[1]={[2]=true},
                      [2]={},
                      [3]={[1]=true,[3]=true}}
    expect.eq(0, b.check_tiles_and_extents(ctx, {bld}, db),
              'valid tiles, non-contiguous extent')
    expect.table_eq({[1]={[2]=true},
                     [2]={},
                     [3]={[1]=true,[3]=true}}, bld.extent_grid)

    bld = {type='a', pos={x=1, y=1, z=1}, width=3, height=3,
           extent_grid={[1]={[2]=true},
                        [2]={},
                        [3]={[1]=true,[3]=true}}}
    valid_tiles = {}
    expect.eq(3, b.check_tiles_and_extents(ctx, {bld}, db),
              'invalid tiles, non-contiguous extent')
    expect.table_eq({[1]={[2]=false},
                     [2]={},
                     [3]={[1]=false,[3]=false}}, bld.extent_grid)

    bld = {type='b', pos={x=1, y=1, z=1}, width=3, height=3,
           extent_grid={[1]={[1]=true,[2]=true,[3]=true},
                        [2]={[1]=true,[2]=true,[3]=true},
                        [3]={[1]=true,[2]=true,[3]=true}}}
    valid_tiles[1] = {[1]={[1]=true,[2]=true, [3]=true},
                      [2]={[1]=true,[2]=false,[3]=true},
                      [3]={[1]=true,[2]=true, [3]=true}}
    expect.eq(1, b.check_tiles_and_extents(ctx, {bld}, db), 'invalid extent')
    expect.table_eq({}, bld.extent_grid)
end

function test.make_extents()
    local bld = {width=1, height=1, extent_grid={[1]={[1]=true}}}
    expect.table_eq({nil, 1}, {b.make_extents(bld, true)}, 'one tile')

    bld = {width=3, height=3, extent_grid={[1]={[2]=true},
                                           [2]={},
                                           [3]={[1]=true,[3]=true}}}
    expect.table_eq({nil, 3}, {b.make_extents(bld, true)}, 'non-contig tiles')

    bld = {width=3, height=3, extent_grid={[1]={[2]=true},
                                           [2]={},
                                           [3]={[1]=true,[3]=true}}}
    local extents, num_tiles = nil, 0
    dfhack.with_finalize(
        function() df.delete(extents) end,
        function()
            extents, num_tiles = b.make_extents(bld, false)
            expect.eq(3, num_tiles, 'allocated tiles')
            expect.eq(0, extents[0])
            expect.eq(0, extents[1])
            expect.eq(1, extents[2])
            expect.eq(1, extents[3])
            expect.eq(0, extents[4])
            expect.eq(0, extents[5])
            expect.eq(0, extents[6])
            expect.eq(0, extents[7])
            expect.eq(1, extents[8])
        end)
end
