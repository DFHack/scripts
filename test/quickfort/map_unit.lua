local m = reqscript('internal/quickfort/map')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/map') end)
end

local dims = {x=3, y=4, z=5}
local bounds = m.MapBoundsChecker{dims=dims}

function test.is_on_map()
    expect.false_(bounds:is_on_map({x=10, y=1, z=1}), 'bad x')
    expect.false_(bounds:is_on_map({x=1, y=10, z=1}), 'bad y')
    expect.false_(bounds:is_on_map({x=1, y=1, z=10}), 'bad z')
    expect.true_(bounds:is_on_map({x=1, y=1, z=1}), 'good')
end

function test.is_on_map_x()
    expect.false_(bounds:is_on_map_x(-2))
    expect.false_(bounds:is_on_map_x(-1))
    expect.true_(bounds:is_on_map_x(0))
    expect.true_(bounds:is_on_map_x(1))
    expect.true_(bounds:is_on_map_x(2))
    expect.false_(bounds:is_on_map_x(3))
    expect.false_(bounds:is_on_map_x(4))
end

function test.is_on_map_y()
    expect.false_(bounds:is_on_map_y(-2))
    expect.false_(bounds:is_on_map_y(-1))
    expect.true_(bounds:is_on_map_y(0))
    expect.true_(bounds:is_on_map_y(1))
    expect.true_(bounds:is_on_map_y(2))
    expect.true_(bounds:is_on_map_y(3))
    expect.false_(bounds:is_on_map_y(4))
    expect.false_(bounds:is_on_map_y(5))
end

function test.is_on_map_z()
    expect.false_(bounds:is_on_map_z(-2))
    expect.false_(bounds:is_on_map_z(-1))
    expect.true_(bounds:is_on_map_z(0))
    expect.true_(bounds:is_on_map_z(1))
    expect.true_(bounds:is_on_map_z(2))
    expect.true_(bounds:is_on_map_z(3))
    expect.true_(bounds:is_on_map_z(4))
    expect.false_(bounds:is_on_map_z(5))
    expect.false_(bounds:is_on_map_z(6))
end

function test.is_on_map_edge()
    expect.false_(bounds:is_on_map_edge({x=1, y=1, z=1}), 'not x or y')
    expect.true_(bounds:is_on_map_edge({x=0, y=1, z=1}), 'on x left')
    expect.true_(bounds:is_on_map_edge({x=2, y=1, z=1}), 'on x right')
    expect.true_(bounds:is_on_map_edge({x=1, y=0, z=1}), 'on y top')
    expect.true_(bounds:is_on_map_edge({x=1, y=3, z=1}), 'on y bottom')
    expect.false_(bounds:is_on_map_edge({x=0, y=-1, z=1}), 'on x but bad y')
    expect.false_(bounds:is_on_map_edge({x=-1, y=0, z=1}), 'on y but bad x')
end
