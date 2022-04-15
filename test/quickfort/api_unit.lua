local a = reqscript('internal/quickfort/api')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/api') end)
end

function test.normalize_data()
    local data = {[0]={[0]={[0]='d(10x10)'}}}
    local expected_data = {[0]={[0]={[0]={cell='0,0,0', text='d(10x10)'}}}}
    local expected_min = {x=0, y=0, z=0}
    expect.table_eq({expected_data, expected_min}, {a.normalize_data(data)})

    -- test a string instead of a coordinate map
    data = 'd(10x10)'
    expected_data = {[0]={[0]={[0]={cell='0,0,0', text='d(10x10)'}}}}
    expected_min = {x=0, y=0, z=0}
    expect.table_eq({expected_data, expected_min}, {a.normalize_data(data)})

    -- offset with a pos param
    expected_data = {[10]={[11]={[12]={cell='0,0,0', text='d(10x10)'}}}}
    expected_min = {x=12, y=11, z=10}
    expect.table_eq({expected_data, expected_min},
                    {a.normalize_data(data, {x=12, y=11, z=10})})

    -- test negative starting coords
    data = {[-1]={[-2]={[-3]='d(10x10)'}}}
    expected_data = {[1]={[1]={[1]={cell='-3,-2,-1', text='d(10x10)'}}}}
    expected_min = {x=1, y=1, z=1}
    expect.table_eq({expected_data, expected_min},
                    {a.normalize_data(data, {x=4, y=3, z=2})})

    data = {[0]={[0]={[0]='d1',
                      [5]='d2'},
                 [3]={[4]='d3'}},
            [10]={[1]={[2]='d4'}}}
    expected_data = {[0]={[10]={[5]={cell='0,0,0', text='d1'},
                                [10]={cell='5,0,0', text='d2'}},
                          [13]={[9]={cell='4,3,0', text='d3'}}},
                     [10]={[11]={[7]={cell='2,1,10', text='d4'}}}}
    expected_min = {x=5, y=10, z=0}
    expect.table_eq({expected_data, expected_min},
                    {a.normalize_data(data, {x=5, y=10})})
end

function test.clean_stats()
    local stats = {name1={label='label1', value=5},
                   name2={label='label2', value=50, always=true}}
    local expected_stats = {name1={label='label1', value=5},
                            name2={label='label2', value=50}}
    expect.table_eq(expected_stats, a.clean_stats(stats))
end
